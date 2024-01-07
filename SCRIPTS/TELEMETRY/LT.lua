-- Description

-- Displays time elapsed in minutes, seconds and milliseconds.
-- Timer activated by a physical or logical switch.
-- Lap recorded by a second physical or logical switch.
-- Reset to zero by Timer switch being set to off and Lap switch set on.
-- Default Timer switch is "ls1" (logical switch one).
-- OpenTX "ls1" set to a>x, THR, -100
-- Default Lap switch is "sh", a momentary switch.

-- Change as desired
-- sa to sh, ls1 to ls32
-- If you want the timer to start and stop when the throttle is up and down
-- create a logical switch that changes state based on throttle position.
local TimerSwitch = "ls1"
-- Position U (up/away from you), D (down/towards), M (middle)
-- When using logical switches use "U" for true, "D" for false
local TimerSwitchOnPosition = "U"
local LapSwitch = "sh"
local LapSwitchRecordPosition = "U"

-- Audio
local SpeakLapTime = false
local SpeakLapNumber = false
local SpeakLapTimeHours = 0 -- 1 hours, minutes, seconds else minutes, seconds

local BeepOnLap = true
local BeepFrequency = 200 -- Hz
local BeepLengthMilliseconds = 200

-- File Paths
-- location you placed the accompanying sound files
local SoundFilesPath = "/SCRIPTS/SOUNDS/LapTmr/"

-- ----------------------------------------------------------------------------------------
-- ----------------------------------------------------------------------------------------

-- Time Tracking
local StartTimeMilliseconds = -1
local ElapsedTimeMilliseconds = 0
local PreviousElapsedTimeMilliseconds = 0
local LapTime = 0
local LapTimeList = {ElapsedTimeMilliseconds}
local LapTimeRecorded = false

-- Display
local TextSize = SMLSIZE
local TextHeight = 6

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

local lastLapSwitchValue = -1
local function getSwitchPosition(switchID)
  -- Returns switch position as one of U, D, M
  -- Passed a switch identifier sa to sf, ls1 to ls32
  local switchValue = getValue(switchID)

  -- Debounce the LapSwitch
  if switchID == LapSwitch then
    if switchValue == lastLapSwitchValue then
      return " "
    end
    lastLapSwitchValue = switchValue  
  end

  -- typical Tx switch middle value is
  if switchValue < -100 then
    return "D"
  elseif switchValue < 100 then
    return "M"
  else
    return "U"
  end
end


local function handleSounds()
  if BeepOnLap == true then
    playTone(BeepFrequency, BeepLengthMilliseconds, 0)
  end

  if SpeakLapNumber == true then
    if (#LapTimeList-1) <= 16 then
      local filePathName = SoundFilesPath..tostring(#LapTimeList-1)..".wav"
      playFile(filePathName)
    end
  end

  if SpeakLapTime == true then
    local LapTimeInt = math.floor((LapTime/1000)+0.5)
    playDuration(LapTimeInt, SpeakLapTimeHours)
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

local function bg_func()
  
  local timerSwitchValue = getSwitchPosition(TimerSwitch)
  local lapSwitchValue = getSwitchPosition(LapSwitch)


  -- Start recording time
  if timerSwitchValue == TimerSwitchOnPosition then
    -- Start reference time
    if StartTimeMilliseconds == -1 then
      StartTimeMilliseconds = getTimeMilliseconds()
    end

    -- Time difference
    ElapsedTimeMilliseconds = getTimeMilliseconds() - StartTimeMilliseconds
    -- TimerSwitch and LapSwitch On so record the lap time
    if lapSwitchValue == LapSwitchRecordPosition then
      if LapTimeRecorded == false then
        LapTime = ElapsedTimeMilliseconds - PreviousElapsedTimeMilliseconds
        PreviousElapsedTimeMilliseconds = ElapsedTimeMilliseconds
        LapTimeList[#LapTimeList+1] = getMinutesSecondsHundrethsAsString(LapTime)
        LapTimeRecorded = true

        handleSounds()
      end
    else
      LapTimeRecorded = false
    end
  else
    -- TimerSwitch Off and LapSwitch On so reset time
    if lapSwitchValue == LapSwitchRecordPosition then
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
