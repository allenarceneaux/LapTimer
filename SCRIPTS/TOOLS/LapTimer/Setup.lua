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
local log = loadScript("lib_log")(c.app_name, c.script_folder)
local sw = loadScript("switches")(log)
local config = loadScript("Config")(log, c)

-- Navigation variables
local dirty = true
local edit = false
local field = 0

-- state machine
-- local PAGE = {
--     ONE = {},
--     TWO = {},
--   }
-- local page = PAGE.ONE
local PAGE_ONE = 0  
local PAGE_TWO = 1
local page = PAGE_ONE

  
local swIndexes = sw.itemIdxs()

-- --------------------------------------------------------------
-- Blink the cursor
-- --------------------------------------------------------------
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

-- --------------------------------------------------------------
-- Increment or decrement a fields
-- --------------------------------------------------------------
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

    return value
end

-- --------------------------------------------------------------
-- Navigate the menu
-- --------------------------------------------------------------
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
        end
    end
end

-- --------------------------------------------------------------
-- Get the field flags
-- --------------------------------------------------------------
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

-- --------------------------------------------------------------
-- Increment or decrement a switch
-- --------------------------------------------------------------
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

    return value
  end
  
-- --------------------------------------------------------------
-- Toggle a value
-- --------------------------------------------------------------
local function valueToggle(event, value)
    if edit then
        if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT or
            event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
            value = not value
            dirty = true
        end
    end

    return value
end

-- --------------------------------------------------------------
-- If condition

local function iif(cond, T, F)
	if cond then return T else return F end
end

-- --------------------------------------------------------------
-- Show Yes or No
-- --------------------------------------------------------------
local function showYN(tf)
    return iif(tf, "Yes", "No")
end

-- --------------------------------------------------------------
-- draw setup page One
-- --------------------------------------------------------------
local function drawPageOne(event, touchState)
    if dirty then
        dirty = false
        lcd.clear()
        lcd.drawScreenTitle("LAP TIMER SETUP", 2, 3)
    
        lcd.drawText(4, 12, "Timer Switch:");
        lcd.drawSwitch(95, 12, config.TimerSwitch, getFieldFlags(0))
    
        lcd.drawText(4, 22, "Lap Switch:");
        lcd.drawSwitch(95, 22, config.LapSwitch, getFieldFlags(1))

        lcd.drawText(4, 32, "Beep on Lap:")
        lcd.drawText(95, 30, showYN(config.BeepOnLap), getFieldFlags(2))

        lcd.drawText(4, 42, "Say Lap Number:")
        lcd.drawText(95, 40, showYN(config.SpeakLapNumber), getFieldFlags(3))
    
        lcd.drawText(4, 52, "Say Lap Time:")
        lcd.drawText(95, 50, showYN(config.SpeakLapTime), getFieldFlags(4))
    
    end

    navigate(event, 4, page, page+1)

    if field==0 then
        config.TimerSwitch = switchIncDec(event, config.TimerSwitch)
    elseif field==1 then
        config.LapSwitch = switchIncDec(event, config.LapSwitch)
    elseif field==2 then
        config.BeepOnLap = valueToggle(event, config.BeepOnLap)
    elseif field==3 then
        config.SpeakLapNumber = valueToggle(event, config.SpeakLapNumber)
    elseif field==4 then
        config.SpeakLapTime = valueToggle(event, config.SpeakLapTime)
    end
    return 0
end


-- --------------------------------------------------------------
-- draw setup page Two
-- --------------------------------------------------------------
local function drawPageTwo(event, touchState)
    if dirty then

print("drawPageTwo")
        dirty = false
        lcd.clear()
        lcd.drawScreenTitle("LAP TIMER SETUP", 3, 3)
    
        lcd.drawText(1, 12, "Say Announcements:")
        lcd.drawText(106, 12, showYN(config.SpeakAnnouncements), getFieldFlags(0))
    
    end

    navigate(event, 0, page-1, page)

    if field==0 then
        config.SpeakAnnouncements = valueToggle(event, config.SpeakAnnouncements)
    end
    return 0
end

-- --------------------------------------------------------------
-- Init
-- --------------------------------------------------------------
function init()
end

-- --------------------------------------------------------------
-- Run
-- --------------------------------------------------------------
function run(event, touchState)
    if event == nil then
        error("Cannot be run as a model script!")
        return 2
    end

    if not edit and event == EVT_VIRTUAL_EXIT then
        config.write()
        return "MainMenu"
    end

    if page == PAGE_ONE then
        return drawPageOne(event, touchState)
    elseif page == PAGE_TWO then
        return drawPageTwo(event, touchState)
    end

end

return { init=init, run=run }
