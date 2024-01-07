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

-- This script gets a list of available radio switches
-- Author: Allen Arceneaux
-- Date: 2024
local m_log  = ...

-- --------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
    print(fmt,...)
end
-- --------------------------------------------------------------

local switchList = {}
function switchList.new()
    local tbl = {
        list = {}
    }

    for i, s in switches() do
        if i ~= 0 then 
            local new_idx = #tbl.list+1
            tbl.list[new_idx] = {idx = i, name = s}
        end
    end

    function tbl.items()
        return tbl.list
    end

    function tbl.size()
        return #tbl.list
    end

    function tbl.insert(idx, name)
        tbl.list[#tbl.list+1] = {idx = idx, name = name}
    end

    function tbl.itemNames()
        local names = {}
        for _, k in ipairs(tbl.list) do
            names[#names+1] = k.name
        end
        return names
    end

    function tbl.itemIdxs()
        local idxs = {}
        for _, k in ipairs(tbl.list) do
            idxs[#idxs+1] = k.idx
        end
        return idxs
    end

    function tbl.middle()
        return #tbl.list/2
    end
    function tbl.dump()
        log("switch dump")
         for _, k in ipairs(tbl.list) do
            print(k.idx.." - "..k.name)
            log(k.idx.." - "..k.name)
         end
     end
 
     return tbl
end

return switchList