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

local c = loadScript("Common")()
local log = loadScript("Log")(c.app_name, c.script_folder)
local config = loadScript("Config")(log, c)

-- Audio
local BeepFrequency = 200 -- Hzd
local BeepLengthMilliseconds = 200

local SoundFilesPath = c.script_folder.."/SOUNDS/"
local ANNOUNCE_LAP = SoundFilesPath.."lap.wav"
local ANNOUNCE_START = SoundFilesPath.."started.wav"
local ANNOUNCE_STOP = SoundFilesPath.."stopped.wav"
local ANNOUNCE_PAUSE = SoundFilesPath.."paused.wav"
local ANNOUNCE_RESUMED = SoundFilesPath.."resumed.wav"
local ANNOUNCE_RESET = SoundFilesPath..'reset.wav'
local ANNOUNCE_SAVE = SoundFilesPath..'save.wav'
local ANNOUNCE_DISCARD = SoundFilesPath..'discard.wav'
local ANNOUNCE_FASTER = SoundFilesPath..'faster.wav'
local ANNOUNCE_SLOWER = SoundFilesPath..'slower.wav'
local POINT = SoundFilesPath..'point.wav'

local SAVE_CSV_FILENAME = c.script_folder..'/DATA/LAPTIMES.%s.csv'

-- --------------------------------------------------------------
-- If inline
-- --------------------------------------------------------------
local function iif(cond, T, F)
	if cond then return T else return F end
end
-- --------------------------------------------------------------

-- Time Tracking
local StartTimeMilliseconds = -1
local ElapsedTimeMilliseconds = 0
local PreviousElapsedTimeMilliseconds = 0
local LapTime = 0
local LapTimeList = {tick = 0.0, time = getDateTime()}
LapTimeList[#LapTimeList+1] = {tick = 0.0, time = getDateTime()}

-- Display
local TextSize = SMLSIZE
local TextHeight = 6

-- state machine
local STATE = {
  TIMER = {},
  SAVE = {},
}
local state = STATE.TIMER

--------------------------------------------------------------
-- Return Minutes, Seconds, Hundreths as a string
-- --------------------------------------------------------------
local function getMinutesSecondsHundrethsAsString(milliseconds)
  local seconds = milliseconds/1000
  local minutes = math.floor(seconds/60) -- seconds/60 gives minutes
  seconds = seconds % 60 -- seconds % 60 gives seconds
  return (string.format("%01d:%05.2f", minutes, seconds))
end

-- --------------------------------------------------------------
-- handle Lap sounds
-- --------------------------------------------------------------
local function handleLapSounds()
  if config.BeepOnLap == true then
    playTone(BeepFrequency, BeepLengthMilliseconds, 0)
  end

  if config.SpeakLapNumber == true then
    playFile(ANNOUNCE_LAP)
    playNumber(#LapTimeList-1, 0)
  end

  if config.SpeakLapTime == true then
    local sec, fsec = math.modf(LapTime/1000)
    playNumber(sec, 0)
    playFile(POINT)
    playNumber(fsec*100, 0)
  end

	if #LapTimeList > 2 and config.SpeakFasterSlower == true then
    if LapTimeList[#LapTimeList].tick < LapTimeList[#LapTimeList - 1].tick then
      playFile(ANNOUNCE_FASTER)
    else
      playFile(ANNOUNCE_SLOWER)
    end
	end

end

-- --------------------------------------------------------------
-- init timer
-- --------------------------------------------------------------
local function init_func()
  StartTimeMilliseconds = -1
  ElapsedTimeMilliseconds = 0
end

-- --------------------------------------------------------------
-- reset timer
-- --------------------------------------------------------------
local function resetTimer()
  print("Resetting")
  StartTimeMilliseconds = -1
  ElapsedTimeMilliseconds = 0
  PreviousElapsedTimeMilliseconds = 0
  LapTime = 0
  LapTimeList = {tick = 0.0, time = getDateTime()}
  LapTimeList[#LapTimeList+1] = {tick = 0.0, time = getDateTime()}
  if config.SpeakAnnouncements == true then
    playFile(ANNOUNCE_RESET)
  end

end

-- --------------------------------------------------------------
-- get time in 1/100th of a second
-- --------------------------------------------------------------
local function getTimeMilliseconds()
  return getTime() * 10
end

-- --------------------------------------------------------------
-- start timer
-- --------------------------------------------------------------
local function startTimer()
  -- Start time
  if StartTimeMilliseconds == -1 then
    StartTimeMilliseconds = getTimeMilliseconds()
  end

  -- Time difference
  ElapsedTimeMilliseconds = getTimeMilliseconds() - StartTimeMilliseconds

end

-- --------------------------------------------------------------
-- record lap time
-- --------------------------------------------------------------
local function recordLap()
  LapTime = ElapsedTimeMilliseconds - PreviousElapsedTimeMilliseconds
  PreviousElapsedTimeMilliseconds = ElapsedTimeMilliseconds
  LapTimeList[#LapTimeList+1] = {tick = LapTime, time = getDateTime()}

  handleLapSounds()
end

-- --------------------------------------------------------------
-- display timer screen
-- --------------------------------------------------------------
local function displayTimerScreen()
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
      lcd.drawText(x, y, string.format("%02d %s", i-1, getMinutesSecondsHundrethsAsString(LapTimeList[i].tick)), TextSize)
    end
    y = y + rowHeight
  end
end

-- --------------------------------------------------------------
-- calculate stats
-- --------------------------------------------------------------
local function calculateStats()
  local stats = {}
	stats.lapCount = #LapTimeList - 1
	stats.averageLap = 0.0
	stats.bestLap = 0.0
	stats.totalTime = 0.0
  for i = 1, #LapTimeList do
    local seconds = LapTimeList[i].tick/1000
		if stats.bestLap == 0.0 or seconds < stats.bestLap then
			stats.bestLap = seconds
		end
		stats.totalTime = stats.totalTime + seconds
	end

	stats.averageLap = stats.totalTime / stats.lapCount
	return stats
end

-- --------------------------------------------------------------
-- save laps
-- --------------------------------------------------------------
local function saveLaps()

  local function formatTime(t)
    return string.format('%02d-%02d-%02d %02d:%02d:%02d', t.year, t.mon, t.day,t.hour,t.min,t.sec)
  end

  local fn = string.format(SAVE_CSV_FILENAME,formatTime(LapTimeList[1].time))
  log.info("Saving laps to "..fn)

	local f = io.open(fn, 'a')
	for i = 2, #LapTimeList do
		io.write(f, formatTime(LapTimeList[i].time), ',', i-1, ',',	
             getMinutesSecondsHundrethsAsString(LapTimeList[i].tick), "\r\n")
	end
	io.close(f)	
  
end

-- --------------------------------------------------------------
-- display and handle save screen
-- --------------------------------------------------------------
local saveState = true
local function displaySaveScreen(event)
  local stats = calculateStats()
  if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT or
       event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
    saveState = not saveState
	end

  if event == EVT_VIRTUAL_ENTER then
		if saveState then
			saveLaps()
      if config.SpeakAnnouncements == true then
        playFile(ANNOUNCE_SAVE)
      end
		else
      if config.SpeakAnnouncements == true then
        playFile(ANNOUNCE_DISCARD)
      end
		end
    resetTimer()
    state = STATE.TIMER
	end

  lcd.clear()
  lcd.drawText(0, 0,  "LAP TIMER", TextSize + INVERS)
  lcd.drawText(10, 14, 'Total Laps:')
  lcd.drawText(80, 14, stats.lapCount)
  lcd.drawText(10, 26, 'Average Lap:')
  lcd.drawText(80, 26, getMinutesSecondsHundrethsAsString(stats.averageLap*1000))
  lcd.drawText(10, 38, 'Total Time:')
  lcd.drawText(80, 38, getMinutesSecondsHundrethsAsString(stats.totalTime*1000))

  lcd.drawText(2, 55, ' Save ', iif(saveState, TextSize + INVERS, TextSize))
  lcd.drawText(35, 55, ' Discard ', iif(not saveState, TextSize + INVERS, TextSize))
end

-- --------------------------------------------------------------
-- called periodically
-- --------------------------------------------------------------
local lastLapSwitchValue = false
local lastTimerSwitchValue = false
local pausePlayed = false
local resumePlayed = true
local function bg_func()
  
  local timerSwitchValue = getSwitchValue(config.TimerSwitch)
  local timerSwitchChanged = lastTimerSwitchValue ~= timerSwitchValue   -- handle debouncing the switches
  local lapSwitchValue = getSwitchValue(config.LapSwitch)
  local lapSwitchChanged = lastLapSwitchValue ~= lapSwitchValue   -- handle debouncing the switch
  if timerSwitchChanged then
    lastTimerSwitchValue = timerSwitchValue
  end
  if lapSwitchChanged then
    lastLapSwitchValue = lapSwitchValue
  end

  -- Start recording time
  if timerSwitchValue then
    state = STATE.TIMER
    pausePlayed = false
    if timerSwitchChanged and StartTimeMilliseconds == -1 then
      if config.SpeakAnnouncements == true then
        playFile(ANNOUNCE_START)
      end
    else
      if not resumePlayed and config.SpeakAnnouncements == true and StartTimeMilliseconds ~= -1 then
        playFile(ANNOUNCE_RESUMED)
        resumePlayed = true
      end
    end
    startTimer()

    -- TimerSwitch and LapSwitch On so record the lap time
    if lapSwitchChanged and lapSwitchValue then
      recordLap()
    end
  else
    if lapSwitchChanged and lapSwitchValue and StartTimeMilliseconds ~= -1 then
      if config.SpeakAnnouncements == true then
        playFile(ANNOUNCE_STOP)
      end
      resumePlayed = true
      if #LapTimeList > 1 then
        state = STATE.SAVE
      else
        resetTimer()
      end
    else
      if not pausePlayed and StartTimeMilliseconds ~= -1 then
        if config.SpeakAnnouncements == true then
          pausePlayed = true
          resumePlayed = false
          playFile(ANNOUNCE_PAUSE)
        end
      end
    end
  end
end

-- --------------------------------------------------------------
-- Called When screen is displayed
-- --------------------------------------------------------------
local function run_func(event)
  bg_func() -- a good way to reduce repitition

  if state == STATE.TIMER then
    displayTimerScreen()
  elseif state == STATE.SAVE then
    displaySaveScreen(event)
  end

  return 0
end

return { run=run_func, background=bg_func, init=init_func }
