---- #########################################################################
---- #                                                                       #
---- # License GPLv3: https://www.gnu.org/licenses/gpl-3.0.html              #
---- #                                                                       #
---- # This program is free software; you can redistribute it and/or modify  #
---- # it under the terms of the GNU General Public License version 2 as     #
---- # published by the Free Software Foundation.                            #
---- #                                                                       #
---- # This program is distributed in the hope that it will be useful        #
---- # but WITHOUT ANY WARRANTY; without even the implied warranty of        #
---- # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
---- # GNU General Public License for more details.                          #
---- #                                                                       #
---- #########################################################################

-- This script will handle the actuall lap counting for the lap timer system
-- Author: Allen Arceneaux
-- Date: 2024

chdir("/SCRIPTS/TOOLS/LapTimer")

local c = loadScript("common")()
local log = loadScript("lib_log")(c.app_name, c.script_folder)
local config = loadScript("Config")(log, c)

-- Audio
local BeepFrequency = 200 -- Hz
local BeepLengthMilliseconds = 200

local SoundFilesPath = c.script_folder.."/SOUNDS/"

-- --------------------------------------------------------------
local function iif(cond, T, F)
	if cond then return T else return F end
end
-- ----------------------------------------------------------------------------------------

-- Time Tracking
local StartTimeMilliseconds = -1
local ElapsedTimeMilliseconds = 0
local PreviousElapsedTimeMilliseconds = 0
local LapTime = 0
local LapTimeList = {ElapsedTimeMilliseconds}

-- Display
local TextSize = SMLSIZE
local TextHeight = 6

--------------------------------------------------------------

local function getTimeMilliseconds()
  local now = getTime() * 10
  return now
end

local function getMinutesSecondsHundrethsAsString(milliseconds)
  local seconds = milliseconds/1000
  local minutes = math.floor(seconds/60) -- seconds/60 gives minutes
  seconds = seconds % 60 -- seconds % 60 gives seconds
  return (string.format("%01d:%05.2f", minutes, seconds))
end

local function handleSounds()
  if config.BeepOnLap == true then
    playTone(BeepFrequency, BeepLengthMilliseconds, 0)
  end

  if config.SpeakLapNumber == true then
    if (#LapTimeList-1) <= 16 then
      local filePathName = SoundFilesPath..tostring(#LapTimeList-1)..".wav"
      playFile(filePathName)
    end
  end

  if config.SpeakLapTime == true then
    local LapTimeInt = math.floor((LapTime/1000)+0.5)
    playDuration(LapTimeInt, 0)
  end

end

local function init_func()
  StartTimeMilliseconds = -1
  ElapsedTimeMilliseconds = 0
end

local function reset()
  print("Resetting")
  StartTimeMilliseconds = -1
  ElapsedTimeMilliseconds = 0
  PreviousElapsedTimeMilliseconds = 0
  LapTime = 0
  LapTimeList = {0}
end

local function startTimer()
  -- Start time
  if StartTimeMilliseconds == -1 then
    StartTimeMilliseconds = getTimeMilliseconds()
  end

  -- Time difference
  ElapsedTimeMilliseconds = getTimeMilliseconds() - StartTimeMilliseconds
end

local function recordLap()
  LapTime = ElapsedTimeMilliseconds - PreviousElapsedTimeMilliseconds
  PreviousElapsedTimeMilliseconds = ElapsedTimeMilliseconds
  LapTimeList[#LapTimeList+1] = getMinutesSecondsHundrethsAsString(LapTime)
  -- LapTimeRecorded = true

  handleSounds()
end

local lastLapSwitchValue = false
local function bg_func()
  
  local timerSwitchValue = getSwitchValue(config.TimerSwitch)
  local lapSwitchValue = getSwitchValue(config.LapSwitch)
  local lapSwitchChanged = lastLapSwitchValue ~= lapSwitchValue   -- handle debouncing the switch
  if lapSwitchChanged then
    lastLapSwitchValue = lapSwitchValue
  end

  -- Start recording time
  if timerSwitchValue then
    startTimer()

    -- TimerSwitch and LapSwitch On so record the lap time
    if lapSwitchChanged and lapSwitchValue then
      recordLap()
    end
  else
    if lapSwitchChanged and lapSwitchValue then
      reset()
    end
  end
end

local function run_func(event)
  bg_func() -- a good way to reduce repitition

  -- LCD / Display code
  lcd.clear()
  lcd.drawText(0, 0,  "LAP TIMER", TextSize + INVERS)
  lcd.drawText(45, 0, getMinutesSecondsHundrethsAsString(ElapsedTimeMilliseconds), TextSize)
  lcd.drawText(94, 0, "Lap", TextSize + INVERS)
  lcd.drawText(112, 0, #LapTimeList-1, TextSize)

  local rowHeight = math.floor(TextHeight + 2)
  local rows = math.floor(LCD_H/rowHeight)
  local rowsMod = rows*rowHeight
  local x = 15
  local y = rowHeight
  local c = 1

  lcd.drawText(x, y, " ")

  -- i = 2 first entry is always 0:00.00 so skipping it
  for i = #LapTimeList, 2, -1 do
    if y % (rowsMod or 60) == 0 then
      c = c + 1 -- next column
      x = (LCD_W/2)*(c-1)
      y = rowHeight
    end
    if (c > 1) and x > LCD_W - x/(c-1) then
    else
      lcd.drawText(x, y, string.format("%02d %s", i-1, LapTimeList[i]), TextSize)
    end
    y = y + rowHeight
  end
  return 0
end

return { run=run_func, background=bg_func, init=init_func }
