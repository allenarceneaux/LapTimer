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
local log  = ...

-- --------------------------------------------------------------

local switchList = {
    list = {}
}
for i, s in switches() do
    if i ~= 0 then 
        local new_idx = #switchList.list+1
        switchList.list[new_idx] = {idx = i, name = s}
    end
end

function switchList.items()
    return switchList.list
end

function switchList.size()
    return #switchList.list
end

function switchList.insert(idx, name)
    switchList.list[#tbl.list+1] = {idx = idx, name = name}
end

function switchList.itemNames()
    local names = {}
    for _, k in ipairs(switchList.list) do
        names[#names+1] = k.name
    end
    return names
end

function switchList.itemIdxs()
    local idxs = {}
    for _, k in ipairs(switchList.list) do
        idxs[#idxs+1] = k.idx
    end
    return idxs
end

function switchList.middle()
    return #switchList.list/2
end

function switchList.dump()
    log.info("switch dump")
    for _, k in ipairs(switchList.list) do
        log.info(k.idx.." - "..k.name)
    end
end

return switchList