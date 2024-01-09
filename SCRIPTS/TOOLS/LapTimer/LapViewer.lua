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

-- This script will display the list of captured lap times
-- Author: Allen Arceneaux
-- Date: 2024

local c = loadScript("common")()
local log = loadScript("lib_log")(c.app_name, c.script_folder)
local tbl = loadScript("lib_tbl")(log)
local page = loadScript("scroller")()

local fnames = {}

-- state machine
local STATE = {
    EXIT = {page = 0, of = 0},
    DATE_LIST = {page = 2, of = 4},
    TIME_LIST = {page = 3, of = 4},
    LAP_TIMES = {page = 4, of = 4},
}
local state = STATE.DATE_LIST

local dateScroller = nil 
local timesScroller = nil 
local lapScroller = nil

-- Instantiate a new GUI object
local datePage = page.newPage()
local timePage = page.newPage()
local lapTimePage = page.newPage()

local date_list_active = false
local time_list_active = false
local lap_times_active = false

--------------------------------------------------------------
local function drawCenterText(y, text, flags)
    local sz =5 * #text
    lcd.drawText(LCD_W/2-sz/2, y, text, flags)
end

-- --------------------------------------------------------------
-- Load and Show list of dates
-- --------------------------------------------------------------
local function state_DATE_LIST(event, touchState)
    if date_list_active == false then
        date_list_active = true

        -- read Lap time file list
        drawCenterText(LCD_H/2, "Loading...", SMLSIZE)

        -- filter to just csv files
        local dates = tbl.newTbl()
        fnames = {}
        for fname in dir(c.data_folder) do
            if string.match(fname, ".csv") then
                date = string.sub(fname, 10, 28)
                fnames[date]=fname
                dates.insert(string.sub(date, 1, 10))
            end
        end

        dates.dedupe()

        if dates.size() == 0 then
            dates.insert("No Lap files found")
        end

        dateScroller = datePage.scroller(2, 10, LCD_W-3, 58, dates.items(), true, function (obj, selection)
            if selection == EVT_VIRTUAL_EXIT then
                state = STATE.EXIT
            else
                log.info("state_DATE_LIST --> selected date: %s", selection)
                if selection == "No Lap files found" then
                    log.warn("state_DATE_LIST_refresh: trying to go to next page, but no Lap files available, ignoring.")
                    date_list_active = false
                    datePage = page.newPage()
                    return 0
                end
                time_list_active = false
                state = STATE.TIME_LIST
            end
        end)
    end
    if dateScroller ~= nil then
        dateScroller.run(event, touchState)
    end
    return 0
end


-- --------------------------------------------------------------
-- Show list of times
-- --------------------------------------------------------------
local function state_TIME_LIST(event, touchState)
    if time_list_active == false then
        time_list_active = true

        -- read Lap time file list
        drawCenterText(LCD_H/2, "Loading...", SMLSIZE)

        -- filter times from selected date
        local selected_date = dateScroller.items[dateScroller.selected]     
        local times = tbl.newTbl()

        for k,v in pairs(fnames) do
            if string.sub(k, 1, 10) == selected_date then
                times.insert(string.sub(k, 12, 19))
            end
        end

        timesScroller = timePage.scroller(2, 10, LCD_W-3, 58, times.items(), true, function (obj, selection)
            if selection == EVT_VIRTUAL_EXIT then
                date_list_active = false
                state = STATE.DATE_LIST
            else
                log.info("state_TIME_LIST --> selected time: %s", selection)
                lap_times_active = false
                state = STATE.LAP_TIMES
            end
        end)
    end

    if timesScroller ~= nil then
        timesScroller.run(event, touchState)
    end
    return 0
end

-- --------------------------------------------------------------
-- Show lap times
-- --------------------------------------------------------------
local function findFile(date)
    for k,v in pairs(fnames) do
        if string.sub(k, 1, 19) == date then
            return v
        end
    end
    return nil
end 

local function loadFile(filename)
    local lapTimes = tbl.newTbl()

    log.info("opening filename: %s", filename)

    local info = fstat(filename)
    local lFile = io.open(filename, "r")
    if lFile == nil then
        log.error(filename.." Not found")
        return nil
    end

    local fileData = io.read(lFile, info.size)
    for s in string.gmatch(fileData,"[^\r\n]+") do
-- 2024-01-09 12:19:45,3,0:01.51

        local year, month, day, hour, min, sec, lap, lapTime = string.match(s, 
            "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+),(%d+),(%d:%d+%.?%d*)")

        -- local lap = {
        --     date = year.."-"..month.."-"..day.."".. hour..":"..min..":"..sec,
        --     lap = lap,
        --     lapTime = lapTime,
        -- }
        -- lapTimes.insert(lap)   

        lapTimes.insert(lap.." - "..lapTime)    
    end
    io.close(lFile)
    return lapTimes
    
end

local function state_LAP_TIMES(event, touchState)
    if lap_times_active == false then
        lap_times_active = true

        -- read Lap time file list
        drawCenterText(LCD_H/2, "Loading...", SMLSIZE)

        local date = dateScroller.items[dateScroller.selected]
        local time = timesScroller.items[timesScroller.selected]
        local filename = c.data_folder.."/"..findFile(date.." "..time)

        local lapTimes = loadFile(filename)
        if lapTimes == nil then
            lapTimes = tbl.newTbl()
            lapTimes.insert(filename.." Not found")
        end
    
        lapScroller = lapTimePage.scroller(2, 10, LCD_W-3, 58, lapTimes.items(), false, function (obj, selection)
            if selection == EVT_VIRTUAL_EXIT then
                time_list_active = false
                state = STATE.TIME_LIST
            end
        end)
    end

    if lapScroller ~= nil then
        lapScroller.run(event, touchState)
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

    -- log.info("run() ---------------------------")
    -- log.info("event: %s", event)

    lcd.clear()
    lcd.drawScreenTitle("LAP TIMER VIEWER", state.page, state.of)

    if state == STATE.DATE_LIST then
        return state_DATE_LIST(event, touchState)
    elseif state == STATE.TIME_LIST then
        return state_TIME_LIST(event, touchState)
    elseif state == STATE.LAP_TIMES then
        return state_LAP_TIMES(event, touchState)
    elseif state == STATE.EXIT then
        return "MainMenu"
    end

    --impossible state
    error("Something went wrong with the script!")
    return 2
end

return { init=init, run=run }
