--
-- Lap Timer by Jeremy Cowgar <jeremy@cowgar.com>
--
-- https://github.com/jcowgar/opentx-laptimer
--

--
-- User Configuration
--

local SOUND_PATH = '/SOUNDS/LAPTIME/'
local SOUND_GOOD_LAP = SOUND_PATH..'better.wav'
local SOUND_BAD_LAP = SOUND_PATH..'worse.wav'
local SOUND_RACE_SAVE = SOUND_PATH..'rsaved.wav'
local SOUND_RACE_DISCARD = SOUND_PATH..'rdiscard.wav'

--
-- User Configuration Done
--
-- Do not alter below unless you know what you're doing!
--

--
-- Constants
--

local OFF_MS = -924
local MID_MS_MIN = -100
local MID_MS_MAX = 100
local ON_MS  = 924

local SCREEN_RACE_SETUP = 1
local SCREEN_CONFIGURATION = 2
local SCREEN_TIMER = 3
local SCREEN_POST_RACE = 4

local SWITCH_NAMES = { 'sa', 'sb', 'sc', 'sd', 'se', 'sf', 'sg', 'sh' }

local CONFIG_FILENAME = '/LAPTIME.cfg'
local CSV_FILENAME = '/LAPTIME.csv'

local ROW_HEIGHT = 0
if LCD_W == 128 then ROW_HEIGHT = 12 else ROW_HEIGHT = 24 end

local MAX_LAP_COUNT = 11

--
-- Configuration Variables
--

local ConfigThrottleChannelNumber = 3  --   3 for AETR,   1 for TAER
local ConfigThrottleChannel = 'ch3'    -- ch3 for AETR, ch1 for TAER
local ConfigLapSwitch = 'sh'           -- sh on Radiomaster TX16S, se on Taranis X9 Lite
local ConfigSpeakGoodBad = true
local ConfigSpeakLapNumber = true
local ConfigBeepOnMidLap = true

--
-- State Variables
--

local currentScreen = SCREEN_RACE_SETUP

-- Setup Related

local lapCount = 3

-- Timer Related

local isTiming = false
local lastLapSw = -2048
local spokeGoodBad = false

local laps = {}
local lapNumber = 0
local lapStartDateTime = {}
local lapStartTicks = 0
local lapThrottles = {}
local lapSpokeMid = false

-----------------------------------------------------------------------
--
-- Helper Methods (Generic)
--
-----------------------------------------------------------------------

local function iif(cond, T, F)
	if cond then return T else return F end
end

-----------------------------------------------------------------------
--
-- Configuration
--
-----------------------------------------------------------------------

local CONFIG_FIELD_THROTTLE = 1
local CONFIG_FIELD_CONFIG_LAP_SWITCH = 2
local CONFIG_FIELD_SPEAK_BETTER_WORSE = 3
local CONFIG_FIELD_SPEAK_LAP = 4
local CONFIG_FIELD_BEEP_AT_HALF = 5

local CONFIG_OPTIONS = {
	{ 1, 2, 3, 4 },
	SWITCH_NAMES,
	{ 'Yes', 'No' },
	{ 'Yes', 'No' },
	{ 'Yes', 'No' }
}

local ConfigCurrentField = CONFIG_FIELD_THROTTLE
local ConfigEditing = false

local function config_read()
	--
	-- OpenTX Lua throws an error if you attempt to open a file that does not exist:
	--
	-- f_open(/Users/jeremy/Documents/RC/Taranis-X9E-SD/LAPTIME.cfg) = INVALID_NAME
	-- f_close(0x1439291e05400000) (FIL:0x114392828)
	-- PANIC: unprotected error in call to Lua API ((null))
	--
	-- Thus, let's open it in append mode, which should create a blank file if it does
	-- not yet exist.
	--

	local f = io.open(CONFIG_FILENAME, 'a')
	if f ~= nil then
		io.close(f)
	end

	f = io.open(CONFIG_FILENAME, 'r')
	if f == nil then
		-- defaults will be used
		return false
	end

	local content = io.read(f, 1024)
	io.close(f)

	if content == '' then
		-- defaults will be used
		return false
	end

	local c = {}

	for value in string.gmatch(content, '([^,]+)') do
		c[#c + 1] = value
	end

	ConfigThrottleChannelNumber = tonumber(c[1])
	ConfigThrottleChannel = 'ch' .. c[1]
	ConfigLapSwitch = c[2]
	ConfigSpeakGoodBad = (c[3] == 'true')
	ConfigSpeakLapNumber = (c[4] == 'true')
	ConfigBeepOnMidLap = (c[5] == 'true')

	return true
end

local function config_write()
	local f = io.open(CONFIG_FILENAME, 'w')
	io.write(f, ConfigThrottleChannelNumber)
	io.write(f, ',' .. ConfigLapSwitch)
	io.write(f, ',' .. iif(ConfigSpeakGoodBad, 'true', 'false'))
	io.write(f, ',' .. iif(ConfigSpeakLapNumber, 'true', 'false'))
	io.write(f, ',' .. iif(ConfigBeepOnMidLap, 'true', 'false'))
	io.close(f)
end

local function config_cycle_editing_value(keyEvent)
	local values = CONFIG_OPTIONS[ConfigCurrentField]
	local value

	if ConfigCurrentField == CONFIG_FIELD_THROTTLE then
		value = ConfigThrottleChannelNumber
	elseif ConfigCurrentField == CONFIG_FIELD_CONFIG_LAP_SWITCH then
		value = ConfigLapSwitch
	elseif ConfigCurrentField == CONFIG_FIELD_SPEAK_BETTER_WORSE then
		value = iif(ConfigSpeakGoodBad, 'Yes', 'No')
	elseif ConfigCurrentField == CONFIG_FIELD_SPEAK_LAP then
		value = iif(ConfigSpeakLapNumber, 'Yes', 'No')
	elseif ConfigCurrentField == CONFIG_FIELD_BEEP_AT_HALF then
		value = iif(ConfigBeepOnMidLap, 'Yes', 'No')
	end

	local idx = 1

	for i = 1, #values do
		if values[i] == value then
			idx = i
		end
	end

	if keyEvent == EVT_VIRTUAL_DEC or keyEvent == EVT_VIRTUAL_DEC_REPT then
		idx = idx - 1
	else
		idx = idx + 1
	end

	if idx < 1 then
		idx = #values
	elseif idx > #values then
		idx = 1
	end

	value = values[idx]

	if ConfigCurrentField == CONFIG_FIELD_THROTTLE then
		ConfigThrottleChannelNumber = idx
		ConfigThrottleChannel = 'ch' .. string.format('%d', idx)
	elseif ConfigCurrentField == CONFIG_FIELD_CONFIG_LAP_SWITCH then
		ConfigLapSwitch = value
	elseif ConfigCurrentField == CONFIG_FIELD_SPEAK_BETTER_WORSE then
		ConfigSpeakGoodBad = (value == 'Yes')
	elseif ConfigCurrentField == CONFIG_FIELD_SPEAK_LAP then
		ConfigSpeakLapNumber = (value == 'Yes')
	elseif ConfigCurrentField == CONFIG_FIELD_BEEP_AT_HALF then
		ConfigBeepOnMidLap = (value == 'Yes')
	end
end

local function configuration_func(keyEvent)
	if keyEvent == EVT_VIRTUAL_ENTER then
		if ConfigEditing then
			ConfigEditing = false
		else
			ConfigEditing = true
		end

	elseif ConfigEditing and 
		(
			keyEvent == EVT_VIRTUAL_DEC or keyEvent == EVT_VIRTUAL_DEC_REPT or
			keyEvent == EVT_VIRTUAL_INC or keyEvent == EVT_VIRTUAL_INC_REPT
		)
	then
		config_cycle_editing_value(keyEvent)

	elseif keyEvent == EVT_VIRTUAL_PREVIOUS or keyEvent == EVT_VIRTUAL_PREV_REPT then
		ConfigCurrentField = ConfigCurrentField - 1

		if ConfigCurrentField < CONFIG_FIELD_THROTTLE then
			ConfigCurrentField = CONFIG_FIELD_BEEP_AT_HALF
		end

	elseif keyEvent == EVT_VIRTUAL_NEXT or keyEvent == EVT_VIRTUAL_NEXT_REPT then
		ConfigCurrentField = ConfigCurrentField + 1

		if ConfigCurrentField > CONFIG_FIELD_BEEP_AT_HALF then
			ConfigCurrentField = CONFIG_FIELD_THROTTLE
		end

	elseif keyEvent == EVT_VIRTUAL_ENTER_LONG then
		config_write()

		currentScreen = SCREEN_RACE_SETUP

		return
	end

	if LCD_W == 480 then
		lcd.drawText(1, 1, 'Configuration', INVERS)

		lcd.drawText(12, ROW_HEIGHT*1, 'Throttle Channel:')
		lcd.drawText(LCD_W/2 + 2, ROW_HEIGHT*1, ConfigThrottleChannelNumber, 
			iif(ConfigCurrentField == CONFIG_FIELD_THROTTLE, 
				iif(ConfigEditing, INVERS+BLINK, INVERS), 0))

		lcd.drawText(12, ROW_HEIGHT*2, 'Lap Switch:')
		lcd.drawText(LCD_W/2 + 2, ROW_HEIGHT*2, ConfigLapSwitch,
			iif(ConfigCurrentField == CONFIG_FIELD_CONFIG_LAP_SWITCH,
				iif(ConfigEditing, INVERS+BLINK, INVERS), 0))

		lcd.drawText(12, ROW_HEIGHT*3, 'Speak Better/Worse:')
		lcd.drawText(LCD_W/2 + 2, ROW_HEIGHT*3, iif(ConfigSpeakGoodBad, 'Yes', 'No'),
			iif(ConfigCurrentField == CONFIG_FIELD_SPEAK_BETTER_WORSE,
				iif(ConfigEditing, INVERS+BLINK, INVERS), 0))

		lcd.drawText(12, ROW_HEIGHT*4, 'Speak Lap Number:')
		lcd.drawText(LCD_W/2 + 2, ROW_HEIGHT*4, iif(ConfigSpeakLapNumber, 'Yes', 'No'),
			iif(ConfigCurrentField == CONFIG_FIELD_SPEAK_LAP,
				iif(ConfigEditing, INVERS+BLINK, INVERS), 0))

		lcd.drawText(12, ROW_HEIGHT*5, 'Beep At Half Lap:')
		lcd.drawText(LCD_W/2 + 2, ROW_HEIGHT*5, iif(ConfigBeepOnMidLap, 'Yes', 'No'),
			iif(ConfigCurrentField == CONFIG_FIELD_BEEP_AT_HALF,
				iif(ConfigEditing, INVERS+BLINK, INVERS), 0))
	elseif LCD_W == 212 then
		lcd.drawScreenTitle('Configuration', 1, 1)

		lcd.drawText(23, 12, 'Throttle Channel:')
		lcd.drawText(lcd.getLastPos() + 2, 12, ConfigThrottleChannelNumber, 
			iif(ConfigCurrentField == CONFIG_FIELD_THROTTLE, 
				iif(ConfigEditing, INVERS+BLINK, INVERS), 0))

		lcd.drawText(58, 22, 'Lap Switch:')
		lcd.drawText(lcd.getLastPos() + 2, 22, ConfigLapSwitch,
			iif(ConfigCurrentField == CONFIG_FIELD_CONFIG_LAP_SWITCH,
				iif(ConfigEditing, INVERS+BLINK, INVERS), 0))

		lcd.drawText(8, 32, 'Speak Better/Worse:')
		lcd.drawText(lcd.getLastPos() + 2, 32, iif(ConfigSpeakGoodBad, 'Yes', 'No'),
			iif(ConfigCurrentField == CONFIG_FIELD_SPEAK_BETTER_WORSE,
				iif(ConfigEditing, INVERS+BLINK, INVERS), 0))

		lcd.drawText(24, 42, 'Speak Lap Number:')
		lcd.drawText(lcd.getLastPos() + 2, 42, iif(ConfigSpeakLapNumber, 'Yes', 'No'),
			iif(ConfigCurrentField == CONFIG_FIELD_SPEAK_LAP,
				iif(ConfigEditing, INVERS+BLINK, INVERS), 0))

		lcd.drawText(28, 52, 'Beep At Half Lap:')
		lcd.drawText(lcd.getLastPos() + 2, 52, iif(ConfigBeepOnMidLap, 'Yes', 'No'),
			iif(ConfigCurrentField == CONFIG_FIELD_BEEP_AT_HALF,
				iif(ConfigEditing, INVERS+BLINK, INVERS), 0))
	else
		lcd.drawScreenTitle('LapTm Configuration', 1, 1)

		lcd.drawText(16, 12, 'Throttle Channel:')
		lcd.drawText(lcd.getLastPos() + 2, 12, ConfigThrottleChannelNumber, 
			iif(ConfigCurrentField == CONFIG_FIELD_THROTTLE, 
				iif(ConfigEditing, INVERS+BLINK, INVERS), 0))

		lcd.drawText(51, 22, 'Lap Switch:')
		lcd.drawText(lcd.getLastPos() + 2, 22, ConfigLapSwitch,
			iif(ConfigCurrentField == CONFIG_FIELD_CONFIG_LAP_SWITCH,
				iif(ConfigEditing, INVERS+BLINK, INVERS), 0))

		lcd.drawText(1, 32, 'Speak Better/Worse:')
		lcd.drawText(lcd.getLastPos() + 2, 32, iif(ConfigSpeakGoodBad, 'Yes', 'No'),
			iif(ConfigCurrentField == CONFIG_FIELD_SPEAK_BETTER_WORSE,
				iif(ConfigEditing, INVERS+BLINK, INVERS), 0))

		lcd.drawText(17, 42, 'Speak Lap Number:')
		lcd.drawText(lcd.getLastPos() + 2, 42, iif(ConfigSpeakLapNumber, 'Yes', 'No'),
			iif(ConfigCurrentField == CONFIG_FIELD_SPEAK_LAP,
				iif(ConfigEditing, INVERS+BLINK, INVERS), 0))

		lcd.drawText(21, 52, 'Beep At Half Lap:')
		lcd.drawText(lcd.getLastPos() + 2, 52, iif(ConfigBeepOnMidLap, 'Yes', 'No'),
			iif(ConfigCurrentField == CONFIG_FIELD_BEEP_AT_HALF,
				iif(ConfigEditing, INVERS+BLINK, INVERS), 0))
	end
end

-----------------------------------------------------------------------
--
-- ???
--
-----------------------------------------------------------------------

local function laps_compute_stats()
	local stats = {}
	local lc = #laps

	stats.raceLapCount = lapCount
	stats.lapCount = lc
	stats.averageLap = 0.0
	stats.bestLap = 0.0
	stats.totalTime = 0.0

	for i = 1, lc do
		if stats.bestLap == 0.0 or laps[i][2] < stats.bestLap then
			stats.bestLap = laps[i][2]
		end
		stats.totalTime = stats.totalTime + laps[i][2]
	end

	stats.averageLap = stats.totalTime / stats.lapCount

	return stats
end

local function laps_show()
	local lc = #laps
	local lastLapTime = 0
	local thisLapTime = 0

	if lc == 0 then
		return
	end

	local lcEnd = math.max(lc - 6 - 1, 1)

	for i = lc, lcEnd, -1 do
		local lap = laps[i]

		if LCD_W == 480 then
			lcd.drawText(LCD_W/2 + 12, ((lc - i) * ROW_HEIGHT) + 12,
				string.format('%d', i) .. ': ' ..
				string.format('%0.2f', lap[2] / 100.0))
		elseif LCD_W == 212 then
			lcd.drawText(170, ((lc - i) * 10) + 3,
				string.format('%d', i) .. ': ' ..
				string.format('%0.2f', lap[2] / 100.0))
		else
			lcd.drawText(LCD_W/2 + 12, ((lc - i) * 10) + 3,
				string.format('%d', i) .. ': ' ..
				string.format('%0.2f', lap[2] / 100.0))
		end
	end
end

-----------------------------------------------------------------------
--
-- Setup Portion of the program
--
-----------------------------------------------------------------------

local function race_setup_draw()
	if LCD_W == 480 then
		lcd.drawText(1, 1, 'Configuration', INVERS)
		--lcd.drawBitmap('/BMP/LAPTIME/S_SWHAND.bmp', 190, 110)
		--lcd.drawBitmap('/BMP/LAPTIME/S_TITLE.bmp', 19, 11)

		lcd.drawText(12, ROW_HEIGHT*1, 'Lap Count:')
		lcd.drawText(LCD_W/2, ROW_HEIGHT*1, ' ' .. lapCount .. ' ', INVERS)
	else
		lcd.drawScreenTitle('Configuration', 1, 1)
		lcd.drawPixmap(135, 11, '/BMP/LAPTIME/S_SWHAND.bmp')
		lcd.drawPixmap(2, 14, '/BMP/LAPTIME/S_TITLE.bmp')

		lcd.drawText(6, 48, 'Lap Count:')
		lcd.drawText(63, 48, ' ' .. lapCount .. ' ', INVERS)
	end
end

local function race_setup_func(keyEvent)
	if keyEvent == EVT_VIRTUAL_INC or keyEvent == EVT_VIRTUAL_INC_REPT then
		lapCount = (lapCount + 1) % MAX_LAP_COUNT

	elseif keyEvent == EVT_VIRTUAL_DEC or keyEvent == EVT_VIRTUAL_DEC_REPT then
		lapCount = (lapCount - 1) % MAX_LAP_COUNT

	elseif keyEvent == EVT_VIRTUAL_EXIT then
		currentScreen = SCREEN_CONFIGURATION
		setup_did_initial_draw = false
		return

	elseif keyEvent == EVT_VIRTUAL_ENTER_LONG then
		currentScreen = SCREEN_TIMER
		setup_did_initial_draw = false
		return
	end

	if lapCount < 1 then
		lapCount = 1
	end

	race_setup_draw()
end

-----------------------------------------------------------------------
--
-- Timer Portion of the program
--
-----------------------------------------------------------------------

local function timer_reset()
	isTiming = false
	lapStartTicks = 0
	lapStartDateTime = {}
	lapSpokeMid = false
end

local function timer_start()
	isTiming = true
	lapStartTicks = getTime()
	lapStartDateTime = getDateTime()
	lapSpokeMid = false
	spokeGoodBad = false
end

local function timer_draw()
	local tickNow = getTime()
	local tickDiff = tickNow - lapStartTicks

	if LCD_W == 480 then
		lcd.drawNumber(6, 2, tickDiff, PREC2 + DBLSIZE)
	elseif LCD_W == 212 then
		lcd.drawNumber(65, 3, tickDiff, PREC2 + DBLSIZE)
	else
		lcd.drawNumber(6, 3, tickDiff, PREC2 + SMLSIZE)
	end

	if ConfigBeepOnMidLap and lapSpokeMid == false then
		local lastIndex = #laps

		if lastIndex > 0 then
			local mid = laps[lastIndex][2] / 2
			if mid < tickDiff then
				playTone(700, 300, 5, PLAY_BACKGROUND, 1000)
				lapSpokeMid = true
			end
		end
	end
end

local function laps_reset()
	laps = {}
	lapNumber = 0

	timer_reset()
end

local function laps_save()
	local f = io.open(CSV_FILENAME, 'a')
	for i = 1, #laps do
		local lap = laps[i]
		local dt = lap[1]

		io.write(f, 
			string.format('%02d', dt.year), '-', 
			string.format('%02d', dt.mon), '-',
			string.format('%02d', dt.day), ' ',
			string.format('%02d', dt.hour), ':',
			string.format('%02d', dt.min), ':',
			string.format('%02d', dt.sec), ',',
			i, ',', lapCount, ',',
			lap[2] / 100.0, ',',
			0, -- Average throttle not yet tracked
			"\r\n")
	end
	io.close(f)	

	laps_reset()
end

local function laps_speak_progress()
	if #laps > 0 then
		if ConfigSpeakLapNumber then
			local pathLapNumber = SOUND_PATH..tostring(lapNumber)..".wav"
			playFile(pathLapNumber)
			local thisLapTimeInt = math.floor((laps[#laps][2]/100)+0.5)
			playDuration(thisLapTimeInt, 0) -- 1 hours, minutes, seconds else minutes, seconds
		end
	end

	if #laps > 1 then
		local lastLapTime = laps[#laps - 1][2]
		local thisLapTime = laps[#laps][2]

		if ConfigSpeakGoodBad and spokeGoodBad == false then
			spokeGoodBad = true

			if thisLapTime < lastLapTime then
				playFile(SOUND_GOOD_LAP)
			else
				playFile(SOUND_BAD_LAP)
			end
		end
	end
end

local function timer_func(keyEvent)
	local showTiming = isTiming

	if keyEvent == EVT_VIRTUAL_EXIT then
		currentScreen = SCREEN_POST_RACE
		return
	end

	if isTiming then
		-- Average and best
		local avg = 0.0
		local best = 0.0
		local diff = 0.0

		if #laps > 0 then
			local sum = 0
			for i = 1, #laps do
				if best == 0.0 or laps[i][2] < best then
					best = laps[i][2]
				end
				sum = sum + laps[i][2]
			end

			avg = sum / #laps
		end

		if #laps > 1 then
			local lastLapTime = laps[#laps - 1][2]
			local thisLapTime = laps[#laps][2]

			diff = thisLapTime - lastLapTime
		end

		if LCD_W == 480 then
			lcd.drawFilledRectangle(0, LCD_H/4 - ROW_HEIGHT, LCD_W/2, ROW_HEIGHT, BLACK)
			lcd.drawFilledRectangle(0, LCD_H/2 - ROW_HEIGHT, LCD_W/2, ROW_HEIGHT, BLACK)
			lcd.drawFilledRectangle(0, 3*LCD_H/4 - ROW_HEIGHT, LCD_W/2, ROW_HEIGHT, BLACK)

			lcd.drawLine(LCD_W/4, 0, LCD_W/4, 3*LCD_H/4, 0, 0)
			lcd.drawLine(LCD_W/2, 0, LCD_W/2, 3*LCD_H/4, 0, 0)

			-- Column 1
			lcd.drawText(6, LCD_H/4 - ROW_HEIGHT + 2, 'Curr', INVERS)

			lcd.drawNumber(6, LCD_H/4+2, avg, PREC2 + DBLSIZE)
			lcd.drawText(6, LCD_H/2 - ROW_HEIGHT + 2, 'Avg', INVERS)

			lcd.drawNumber(6, LCD_H/2+2, best, PREC2 + DBLSIZE)
			lcd.drawText(6, 3*LCD_H/4 - ROW_HEIGHT + 2, 'Best', INVERS)

			-- Column 2
			lcd.drawNumber(LCD_W/4, 2, diff, PREC2 + DBLSIZE)
			lcd.drawText(LCD_W/4, LCD_H/4 - ROW_HEIGHT + 2, 'Diff', INVERS)

			lcd.drawText(LCD_W/4, LCD_H/4+2, string.format("%d/%d", lapNumber, lapCount), DBLSIZE)			
			lcd.drawText(LCD_W/4, LCD_H/2 - ROW_HEIGHT + 2, 'Lap', INVERS)

			lcd.drawText(LCD_W/4, 3*LCD_H/4 - ROW_HEIGHT + 2, 'Test', INVERS)

			-- Outline
			lcd.drawRectangle(0, 0, LCD_W, LCD_H, SOLID) -- 480*272
		elseif LCD_W == 212 then
			-- Column 1
			lcd.drawFilledRectangle(0, 22, 70, 11, BLACK)	
			lcd.drawText(30, 24, 'Curr', INVERS)

			lcd.drawFilledRectangle(0, 53, 70, 11, BLACK)	
			lcd.drawNumber(65, 35, avg, PREC2 + DBLSIZE)
			lcd.drawText(30, 55, 'Avg', INVERS)

			-- Column 2
			lcd.drawFilledRectangle(70, 22, 70, 11, BLACK)
			lcd.drawNumber(135, 3, diff, PREC2 + DBLSIZE)
			lcd.drawText(98, 25, 'Diff', INVERS)

			lcd.drawFilledRectangle(70, 53, 70, 11, BLACK)
			lcd.drawText(100, 55, 'Lap', INVERS)

			lcd.drawLine(70, 0, 70, 63, SOLID, FORCE)
			lcd.drawLine(140, 0, 140, 63, SOLID, FORCE)

			lcd.drawNumber(98, 35, lapNumber, DBLSIZE)
			lcd.drawNumber(135, 35, lapCount, DBLSIZE)
			lcd.drawText(102, 42, 'of')

			-- Outline
			lcd.drawRectangle(0, 0, LCD_W, LCD_H, SOLID) -- 212*64
		else
			-- Column 1
			lcd.drawFilledRectangle(0, 22, 35, 11, BLACK)	
			lcd.drawText(6, 24, 'Curr', INVERS)

			lcd.drawFilledRectangle(0, 53, 35, 11, BLACK)	
			lcd.drawNumber(6, 35, avg, PREC2 + SMLSIZE)
			lcd.drawText(6, 55, 'Avg', INVERS)

			-- Column 2
			lcd.drawFilledRectangle(35, 22, 35, 11, BLACK)
			lcd.drawNumber(38, 3, diff, PREC2 + SMLSIZE)
			lcd.drawText(38, 24, 'Diff', INVERS)

			lcd.drawFilledRectangle(35, 53, 35, 11, BLACK)
			lcd.drawText(38, 55, 'Lap', INVERS)

			lcd.drawLine(35, 0, 35, 63, SOLID, FORCE)
			lcd.drawLine(70, 0, 70, 63, SOLID, FORCE)

			lcd.drawNumber(38, 36, lapNumber, SMLSIZE)
			lcd.drawNumber(60, 36, lapCount, SMLSIZE)
			lcd.drawText(47, 35, 'of')

			-- Outline
			lcd.drawRectangle(0, 0, LCD_W, LCD_H, SOLID) -- 128*64
		end
	else
		if LCD_W == 480 then
			lcd.drawText(150, 80, 'Waiting for', DBLSIZE)
			lcd.drawText(152, 130, 'Race Start', DBLSIZE)
		elseif LCD_W == 212 then
			lcd.drawText(55, 15, 'Waiting for', DBLSIZE)
			lcd.drawText(55, 35, 'Race Start', DBLSIZE)
		else
			lcd.drawText(12, 15, 'Waiting for', DBLSIZE)
			lcd.drawText(12, 35, 'Race Start', DBLSIZE)
		end
	end

	--
	-- Check to see if we should do anything with the lap switch
	--

	local lapSwVal = getValue(ConfigLapSwitch)
	local lapSwChanged = (lastLapSw ~= lapSwVal)

	--
	-- Trick our system into thinking it should start the
	-- timer if our throttle goes high
	--

	if isTiming == false and getValue(ConfigThrottleChannel) >= OFF_MS then
		lapSwChanged = true
		lapSwVal = ON_MS
	end

	--
	-- Start a new lap
	--

	if lapSwChanged and lapSwVal >= ON_MS then
		if isTiming then
			--
			-- We already have a lap going, save the timer data
			--

			local lapTicks = (getTime() - lapStartTicks)

			laps[lapNumber] = { lapStartDateTime, lapTicks }
		end

		laps_speak_progress()

		lapNumber = lapNumber + 1

		if lapNumber > lapCount then
			timer_reset()

			lapNumber = 0

			currentScreen = SCREEN_POST_RACE
		else
			timer_start()
		end
	end

	lastLapSw = lapSwVal

	if showTiming then
		timer_draw()
		laps_show()
	end
end

-----------------------------------------------------------------------
--
-- Post Race Portion of the program
--
-----------------------------------------------------------------------

local PR_SAVE = 1
local PR_DISCARD = 2

local post_race_option = PR_SAVE

local function post_race_func(keyEvent)
	local stats = laps_compute_stats()

	if keyEvent == EVT_VIRTUAL_PREVIOUS or keyEvent == EVT_VIRTUAL_PREV_REPT or
	   keyEvent == EVT_VIRTUAL_NEXT or keyEvent == EVT_VIRTUAL_NEXT_REPT
	then
		if post_race_option == PR_SAVE then
			post_race_option = PR_DISCARD
		elseif post_race_option == PR_DISCARD then
			post_race_option = PR_SAVE
		end
	end

	local saveFlag = 0
	local discardFlag = 0

	if post_race_option == PR_SAVE then
		saveFlag = INVERS
	elseif post_race_option == PR_DISCARD then
		discardFlag = INVERS
	end

	if LCD_W == 480 then
		lcd.drawText(12, 4, 'Post Race Stats', MIDSIZE)
		lcd.drawText(12, ROW_HEIGHT*5 + 8, ' Save ', saveFlag)
		lcd.drawText(72, ROW_HEIGHT*5 + 8, ' Discard ', discardFlag)

		laps_show()

		lcd.drawText(12, ROW_HEIGHT*1 + 8, 'Finished ' .. stats.lapCount .. ' of ' .. stats.raceLapCount .. ' laps')
		lcd.drawText(12, ROW_HEIGHT*2 + 8, 'Average Lap: ' .. string.format('%0.2f', stats.averageLap / 100.0) .. ' seconds')
		lcd.drawText(12, ROW_HEIGHT*3 + 8, 'Best Lap: ' .. string.format('%0.2f', stats.bestLap / 100.0) .. ' seconds')
		lcd.drawText(12, ROW_HEIGHT*4 + 8, 'Total Time: ' .. string.format('%0.2f', stats.totalTime / 100.0) .. ' seconds')
	elseif LCD_W == 212 then
		lcd.drawText(2, 2, 'Post Race Stats', MIDSIZE)
		lcd.drawText(2, 55, ' Save ', saveFlag)
		lcd.drawText(35, 55, ' Discard ', discardFlag)

		laps_show()

		lcd.drawText(12, 18, 'Finished ' .. stats.lapCount .. ' of ' .. stats.raceLapCount .. ' laps')
		lcd.drawText(12, 28, 'Average Lap ' .. string.format('%0.2f', stats.averageLap / 100.0) .. ' seconds')
		lcd.drawText(12, 38, 'Total Time ' .. string.format('%0.2f', stats.totalTime / 100.0) .. ' seconds')
	else
		lcd.drawText(2, 2, 'Post Race Stats', MIDSIZE)
		lcd.drawText(2, 55, ' Save ', saveFlag)
		lcd.drawText(35, 55, ' Discard ', discardFlag)

		lcd.drawText(2, 18, 'Finished ' .. stats.lapCount .. ' of ' .. stats.raceLapCount .. ' laps')
		lcd.drawText(2, 28, 'Average Lap ' .. string.format('%0.2f', stats.averageLap / 100.0) .. ' seconds')
		lcd.drawText(2, 38, 'Total Time ' .. string.format('%0.2f', stats.totalTime / 100.0) .. ' seconds')
	end

	if keyEvent == EVT_VIRTUAL_ENTER then
		if post_race_option == PR_SAVE then
			laps_save()

			playFile(SOUND_RACE_SAVE)

			currentScreen = SCREEN_CONFIGURATION
		elseif post_race_option == PR_DISCARD then
			laps_reset()

			playFile(SOUND_RACE_DISCARD)

			currentScreen = SCREEN_CONFIGURATION
		end
	end
end

-----------------------------------------------------------------------
--
-- OpenTx Entry Points
--
-----------------------------------------------------------------------

local function init_func()
	if config_read() == false then
		--
		-- A configuration file did not exist, so let's drop the user off a the lap timer
		-- configuration screen. Let them setup some basic preferences for all races.
		--

		currentScreen = SCREEN_CONFIGURATION
	end
end

local function bg_func()
	if isTiming then
		timer_func(EVT_VIRTUAL_NONE)
	end
end

local function run_func(keyEvent)
	lcd.clear()

	if currentScreen == SCREEN_CONFIGURATION then
		configuration_func(keyEvent)
	elseif currentScreen == SCREEN_RACE_SETUP then
		race_setup_func(keyEvent)
	elseif currentScreen == SCREEN_TIMER then
		timer_func(keyEvent)
	elseif currentScreen == SCREEN_POST_RACE then
		post_race_func(keyEvent)
	end

	return 0
end

return { init=init_func, background=bg_func, run=run_func }
