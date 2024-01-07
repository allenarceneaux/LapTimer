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

-- This script does simple table handling since it's not supported on BW screens
-- Author: Allen Arceneaux
-- Date: 2023

local m_log = ...

local lib = {}
function lib.newTbl()
    local tbl = {
        arr = {}
    }

    local function log(fmt, ...)
        m_log.info(fmt, ...)
    end

    function tbl.items()
        return tbl.arr
    end

    function tbl.size()
        return #tbl.arr
    end

    function tbl.insert(val)
        tbl.arr[#tbl.arr+1] = val
    end

    function tbl.find (val)
        for _, k in ipairs(tbl.arr) do
            if (k == val) then
                    return k
                end
        end
        return nil
    end

    function tbl.exists(val)
        for _, k in ipairs(tbl.arr) do
            if (k == val) then
                return true
            end
        end
        return false
        
    end

    function tbl.dedupe()
        local temp = {}
        function exists(val)
            for _, k in ipairs(temp) do
                if (k == val) then
                    return true
                end
            end
            return false
        end
        for _, k in ipairs(tbl.arr) do
            if exists(k) ~= true then
                temp[#temp+1] = k
            end
        end
        tbl.arr = temp
    end

    function tbl.dump()
       log("tbl dump")
        for _, k in ipairs(tbl.arr) do
            print(k)
            log(k)
        end
    end

    return tbl
end

return lib
