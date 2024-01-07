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

-- This script will display setup options for the lap timer system
-- Author: Allen Arceneaux
-- Date: 2024

local c = loadScript("common")()
local m_log = loadScript("lib_log")(c.app_name, c.script_folder)
local sw = loadScript("switches")(m_log)

local CONFIG_FILENAME = c.data_folder..'/'..c.app_name..'.cfg'

-- --------------------------------------------------------------
-- Configuration Variables
-- --------------------------------------------------------------

local ConfigThrottleChannelNumber = 2  --   3 for AETR,   1 for TAER  zero based
local ConfigLapSwitch = 22             -- sh on Radiomaster TX16S, se on Taranis X9 Lite
local ConfigSpeakGoodBad = false
local ConfigSpeakLapNumber = false
local ConfigBeepOnMidLap = false

-- Navigation variables
local page = 0
local dirty = true
local edit = false
local field = 0

local switchesList =  sw.new()
local swIndexes = switchesList.itemIdxs()

-- --------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
    print(fmt,...)
end

local function iif(cond, T, F)
	if cond then return T else return F end
end

-- --------------------------------------------------------------
-- Read Config file
-- --------------------------------------------------------------

local function config_read()
    log("Reading config file")

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
	ConfigLapSwitch = tonumber(c[2])
	ConfigSpeakGoodBad = (c[3] == 'true')
	ConfigSpeakLapNumber = (c[4] == 'true')
	ConfigBeepOnMidLap = (c[5] == 'true')

	return true
end
if config_read() == false then
    log("No config file found, using defaults")
end

-- --------------------------------------------------------------
-- Save config file
-- --------------------------------------------------------------

local function config_write()
    log("Saving config file")
	local f = io.open(CONFIG_FILENAME, 'w')
	io.write(f, ConfigThrottleChannelNumber)
	io.write(f, ',' .. ConfigLapSwitch)
	io.write(f, ',' .. iif(ConfigSpeakGoodBad, 'true', 'false'))
	io.write(f, ',' .. iif(ConfigSpeakLapNumber, 'true', 'false'))
	io.write(f, ',' .. iif(ConfigBeepOnMidLap, 'true', 'false'))
	io.close(f)
end

-- --------------------------------------------------------------
-- Common functions
-- --------------------------------------------------------------
-- local function dumpValues()
--     log("ConfigThrottleChannelNumber: "..ConfigThrottleChannelNumber)
--     log(ConfigLapSwitch)
--     log("ConfigLapSwitch: "..ConfigLapSwitch)   
--     log("ConfigSpeakGoodBad: "..iif(ConfigSpeakGoodBad, 'true', 'false'))
--     log("ConfigSpeakLapNumber: "..iif(ConfigSpeakGoodBad, 'true', 'false'))
--     log("ConfigBeepOnMidLap: "..iif(ConfigSpeakGoodBad, 'true', 'false'))
-- end
-- dumpValues()

local lastBlink = 0
local function blinkChanged()
    local time = getTime() % 128
    local blink = (time - time % 64) / 64
    if blink ~= lastBlink then
        lastBlink = blink
        return true
    else
        return false
    end
end

local function fieldIncDec(event, value, max, force)
    if edit or force==true then
        if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
            value = (value + max)
            dirty = true
        elseif event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
            value = (value + max + 2)
            dirty = true
        end
        value = (value % (max+1))
    end

    if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT or
        event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
        -- log("fieldIncDec: "..value.." Max: "..max)
        -- dumpValues()
    end

    return value
end

local function valueIncDec(event, value, min, max)
    if edit then
        if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
            if value < max then
                value = (value + 1)
                dirty = true
            end
        elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
            if value > min then
                value = (value - 1)
                dirty = true
            end
        end
    end

    if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT or
        event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
        -- log("valueIncDec: "..value.." Min: "..min.." Max: "..max)
        -- dumpValues()
    end

    return value
end

local function navigate(event, fieldMax, prevPage, nextPage)
    if event == EVT_VIRTUAL_ENTER then
        edit = not edit
        dirty = true
    elseif edit then
        if event == EVT_VIRTUAL_EXIT then
            edit = false
            dirty = true
        elseif not dirty then
            dirty = blinkChanged()
        end
    else
        if event == EVT_VIRTUAL_NEXT_PAGE then
            page = nextPage
            field = 0
            dirty = true
        elseif event == EVT_VIRTUAL_PREV_PAGE then
            page = prevPage
            field = 0
            killEvents(event);
            dirty = true
        else
            field = fieldIncDec(event, field, fieldMax, true)

            if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT or
                event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
                -- log("field: "..field.." fieldMax: "..fieldMax)
                -- dumpValues()
            end
        end
    end
end

local function getFieldFlags(position)
    flags = 0
    if field == position then
        flags = INVERS
        if edit then
            flags = INVERS + BLINK
        end
    end
    return flags
end

local function channelIncDec(event, value)
  if not edit and event==EVT_VIRTUAL_MENU then
        dirty = true
  else
        value = valueIncDec(event, value, 0, 15)
  end
  return value
end

local function switchIncDec(event, value)
    local max=swIndexes[#swIndexes]
    local min=swIndexes[1]

    local function inc(value)
        while value < max do
            value = (value + 1)
            if getSwitchName(value) ~= nil then
                dirty = true
                break
            end
        end
        return value
    end

    local function dec(value)
        while value > min do
            value = (value - 1)
            if getSwitchName(value) ~= nil then
                dirty = true
                break
            end
        end
        return value
    end

    if edit then
        if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
            value = inc(value)
        elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
            value = dec(value)
        end
    end

    if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT or
        event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
        -- log("switchIncDec: "..value.." Min: "..min.." Max: "..max)
        -- dumpValues()
    end
    return value
  end
  
  local function valueToggle(event, value)
    if edit then
        if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT or
            event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
            value = not value
            dirty = true
        end
    end

    if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT or
        event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
        -- log("valueIncDec: "..(value and "true" or "false"))
        -- dumpValues()
    end

    return value
end

local function getYN(tf)
    if tf then
        return "Yes"
    else
        return "No"
    end
  end

  -- --------------------------------------------------------------
-- draw config page
-- --------------------------------------------------------------
local function drawScreen(event, touchState)
    if dirty then
        dirty = false
        lcd.clear()
        lcd.drawScreenTitle("LAP TIMER SETUP", 2, 2)
    
        lcd.drawText(1, 12, "Throttle Channel:");
        lcd.drawSource(98, 12, MIXSRC_CH1+ConfigThrottleChannelNumber, getFieldFlags(0))
    
        lcd.drawText(1, 22, "Lap Switch:");
        lcd.drawSwitch(65, 22, ConfigLapSwitch, getFieldFlags(1))
    
        lcd.drawText(1, 32, "Better/Worse:")
        lcd.drawText(95, 30, getYN(ConfigSpeakGoodBad), getFieldFlags(2))
    
        lcd.drawText(1, 42, "Lap Number:")
        lcd.drawText(95, 40, getYN(ConfigSpeakLapNumber), getFieldFlags(3))
    
        lcd.drawText(1, 52, "Beep Half Lap:")
        lcd.drawText(95, 50, getYN(ConfigBeepOnMidLap), getFieldFlags(4))
    end

    navigate(event, 4, page, page+1)

    if field==0 then
        ConfigThrottleChannelNumber = channelIncDec(event, ConfigThrottleChannelNumber)
    elseif field==1 then
        ConfigLapSwitch = switchIncDec(event, ConfigLapSwitch)
    elseif field==2 then
        ConfigSpeakGoodBad = valueToggle(event, ConfigSpeakGoodBad)
    elseif field==3 then
        ConfigSpeakLapNumber = valueToggle(event, ConfigSpeakLapNumber)
    elseif field==4 then
        ConfigBeepOnMidLap = valueToggle(event, ConfigBeepOnMidLap)
    end

    if not edit and event == EVT_VIRTUAL_EXIT then
        config_write()
    end

    return 0
end

function init()
end

function run(event, touchState)
    if event == nil then
        error("Cannot be run as a model script!")
        return 2
    end

    if not edit and event == EVT_VIRTUAL_EXIT then
        return "MainMenu"
    end

    return drawScreen(event, touchState)

end

return { init=init, run=run }
