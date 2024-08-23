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

-- This script will handles all the date formmating
-- Author: Allen Arceneaux
-- Date: 2024

local log  = ...

DATE = {
    model = "",
    year = 0,
    mon = 0,
    day = 0,
    hour = 0,
    min = 0,
    sec = 0,
}
function DATE.parseFileName(fn)
    DATE.model, DATE.year, DATE.mon, DATE.day, DATE.hour, DATE.min, DATE.sec = string.match(fn, "(%a+).(%d%d%d%d)(%d%d)(%d%d)(%d%d)(%d%d)(%d%d).csv")
    return DATE
end

function DATE.makeFileName(model, dateTime) 
    DATE = dateTime
    return string.format("%s.%04d%02d%02d%02d%02d%02d.csv", model, dateTime.year, dateTime.mon, dateTime.day, dateTime.hour, dateTime.min, dateTime.sec)
end

function DATE.getFileName(dateTime) 
    DATE = dateTime
    return string.format("%s.%04d%02d%02d%02d%02d%02d.csv", dateTime.model, dateTime.year, dateTime.mon, dateTime.day, dateTime.hour, dateTime.min, dateTime.sec)
end

function DATE.parseDateTime(date, time) -- from string values
    DATE.model, DATE.year, DATE.mon, DATE.day = string.match(date, "(%a+) (%d+)-(%d+)-(%d+)")
    DATE.model, DATE.hour, DATE.min, DATE.sec = string.match(time, "(%a+) (%d+):(%d+):(%d+)")
    return DATE
end

function DATE.getNameDate()
    return string.format("%s %04d-%02d-%02d", DATE.model, DATE.year, DATE.mon, DATE.day)
end

function DATE.getNameTime()
    return string.format("%s %02d:%02d:%02d", DATE.model, DATE.hour, DATE.min, DATE.sec)
end

function DATE.getDate()
    return string.format("%04d-%02d-%02d", DATE.year, DATE.mon, DATE.day)
end

function DATE.getTime()
    return string.format("%02d:%02d:%02d", DATE.hour, DATE.min, DATE.sec)
end

function DATE.formatDateTime(dateTime)
    DATE = dateTime
    return string.format('%04d-%02d-%02d %02d:%02d:%02d', dateTime.year, dateTime.mon, dateTime.day,dateTime.hour,dateTime.min,dateTime.sec)
end

function DATE.getDateTime()
    return string.format("%04d-%02d-%02d %02d:%02d:%02d", DATE.year, DATE.mon, DATE.day, DATE.hour, DATE.min, DATE.sec)
end

function DATE.dump()
    log.info("DATE: %s %04d-%02d-%02d %02d:%02d:%02d", DATE.model, DATE.year, DATE.mon, DATE.day, DATE.hour, DATE.min, DATE.sec)
end

return DATE