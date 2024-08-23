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

-- This script will handle the actual lap counting for the lap timer system
-- Author: Allen Arceneaux
-- Date: 2024

chdir("/SCRIPTS/TOOLS/LapTimer")

local c = loadScript("Common")()
local log = loadScript("Log")(c.app_name, c.script_folder)
local dateLib = loadScript("Date")(log)
local config = loadScript("Config")(log, c)

-- Audio
local BeepFrequency = 200 -- Hz
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
local ANNOUNCE_1ST_LAP = SoundFilesPath..'1stlap.wav'
local ANNOUNCE_SECONDS = SoundFilesPath..'seconds.wav'
local ANNOUNCE_GO = SoundFilesPath..'go.wav'
local ANNOUNCE_LASTLAP = SoundFilesPath..'lastlap.wav'
local ANNOUNCE_RACEOVER = SoundFilesPath..'raceovr.wav'

local POINT = SoundFilesPath..'point.wav'

local data_folder = c.script_folder.."/DATA"

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
local MaxSpeed = 0
local LapTime = 0
local LapTimeList = {tick = 0.0, dateTime = getDateTime()}
LapTimeList[#LapTimeList+1] = {tick = 0.0, dateTime = getDateTime()}
local countDownTimer = 0

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

  if config.SpeakAnnouncements == true and #LapTimeList == 2 then
    playFile(ANNOUNCE_1ST_LAP)
  end

  if config.SpeakLapNumber == true and #LapTimeList > 2 then
    if config.SpeakLapNumber == true then
      playFile(ANNOUNCE_LAP)
      playNumber(#LapTimeList-2, 0)

      if config.NumberOfLaps > 0 and #LapTimeList-1 == config.NumberOfLaps then
        playFile(ANNOUNCE_LASTLAP)
      end

      if config.NumberOfLaps > 0 and #LapTimeList-1 > config.NumberOfLaps then
        playFile(ANNOUNCE_RACEOVER)
      end
    end

    if config.SpeakLapTime == true then
      local sec, fsec = math.modf(LapTime/1000)
      playNumber(sec, 0)
      playFile(POINT)
      playNumber(fsec*100, 0)
    end
  end

	if #LapTimeList > 3 and config.SpeakFasterSlower == true then
    if LapTimeList[#LapTimeList].tick < LapTimeList[#LapTimeList - 2].tick then
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

  setTelemetryValue(0x51AA, 0, 1, 0, 0, 0, "Laps")
  setTelemetryValue(0x51AB, 0, 1, 0, 0, 3, "LpTm")
  setTelemetryValue(0x51AC, 0, 1, 0, 8, 3, "Spd")

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
  LapTimeList = {tick = 0.0, dateTime = getDateTime()}
  LapTimeList[#LapTimeList+1] = {tick = 0.0, dateTime = getDateTime()}
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
  LapTimeList[#LapTimeList+1] = {tick = LapTime, dateTime = getDateTime()}

  handleLapSounds()
end

-- --------------------------------------------------------------
-- display timer screen
-- --------------------------------------------------------------
local function displayTimerScreen()
  lcd.clear()
  lcd.drawText(0, 0,  "LAP TIMER", TextSize + INVERS)
  lcd.drawText(45, 0, getMinutesSecondsHundrethsAsString(ElapsedTimeMilliseconds), TextSize)
  lcd.drawText(82, 0, "On Lap", TextSize + INVERS)
  lcd.drawText(112, 0, iif(#LapTimeList> 1, #LapTimeList-1, 0), TextSize)

  local rowHeight = math.floor(TextHeight + 2)
  local rows = math.floor(LCD_H/rowHeight)
  local rowsMod = rows*rowHeight
  local x = 15
  local y = rowHeight
  local c = 1

  lcd.drawText(x, y, " ")

  -- i = 2 first entry is always 0:00.00 also 1st lap is not accurate since was triggered by timer switch so skipping it
  for i = #LapTimeList, 3, -1 do
    if y % (rowsMod or 60) == 0 then
      c = c + 1 -- next column
      x = (LCD_W/2)*(c-1)
      y = rowHeight
    end
    if (c > 1) and x > LCD_W - x/(c-1) then
    else
      lcd.drawText(x, y, string.format("%02d %s", i-2, getMinutesSecondsHundrethsAsString(LapTimeList[i].tick)), TextSize)
    end
    y = y + rowHeight
  end

  if config.CountDownFrom > 0 and countDownTimer > 0 and #LapTimeList == 1 and StartTimeMilliseconds ~= -1 then
    lcd.drawText(45, 14, countDownTimer, XXLSIZE)
  end
end

-- --------------------------------------------------------------
-- calculate stats
-- --------------------------------------------------------------
local function calculateStats()
  local stats = {}
	stats.lapCount = #LapTimeList - 2
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
  local fn =  data_folder.."/"..dateLib.makeFileName(model.getInfo().name, LapTimeList[1].dateTime)     
  log.info("Saving laps to "..fn)

	local f = io.open(fn, 'w')
	for i = 3, #LapTimeList do
		io.write(f, dateLib.formatDateTime(LapTimeList[i].dateTime), ',', 	
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
-- RND rounding function
-- --------------------------------------------------------------
local function rnd(v,d)
	if d then
		return math.floor((v*10^d)+0.5)/(10^d)
	else
		return math.floor(v+0.5)
	end
end

-- --------------------------------------------------------------
-- PlayFile Once function
-- --------------------------------------------------------------
local played = false
local lastTimePlayed = 0
local function playOnce(n, f)
  if not played then
    if n >  -1 then
      playNumber(n, 0)
    end
    if f ~= -1 then
      playFile(f)
    end
    played = true
    lastTimePlayed = getTimeMilliseconds()
  end
  if getTimeMilliseconds() - lastTimePlayed > 999 then
    played = false
  end
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
          if config.CountDownFrom > 0 and #LapTimeList == 1 then
            playNumber(config.CountDownFrom, 0)
            playFile(ANNOUNCE_SECONDS)
          end
      end
    else
      if not resumePlayed and config.SpeakAnnouncements == true and StartTimeMilliseconds ~= -1 then
        playFile(ANNOUNCE_RESUMED)
        resumePlayed = true
      end
    end
    startTimer()
    if config.CountDownFrom > 0 then
      countDownTimer = config.CountDownFrom-rnd(ElapsedTimeMilliseconds/1000,0)
    end

    -- Countdown announcement
    if config.SpeakAnnouncements == true and config.CountDownFrom > 0 and #LapTimeList == 1 then
      if countDownTimer == 0 then
        playOnce(-1, ANNOUNCE_GO)
      end
      if countDownTimer < 11 and countDownTimer > 0 then
        playOnce(countDownTimer, -1)
      end
      if countDownTimer == 15 then
        playOnce(countDownTimer, ANNOUNCE_SECONDS)
      end
    end

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

  setTelemetryValue(0x51AA, 0, 1, iif(#LapTimeList> 2, #LapTimeList-1, 1)-1, 0, 0, "Laps")
  setTelemetryValue(0x51AB, 0, 1, LapTime, 0, 3, "LpTm")

  local field = getFieldInfo("GSpd") -- GPS ground speed m/s
  if field then
    local gpsSpeed = getValue(field.id)*1000 * 0.6213711922  -- knots to KP/H = 1.852,1 * KNOTS   MPH = 1.15077945 * KNOTS    MPH = 0.6213711922 kmh
    if gpsSpeed >= 0 and gpsSpeed < 100 then -- filter out bad data
      setTelemetryValue(0x51AC, 0, 1, gpsSpeed, 8, 3, "Spd")
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
