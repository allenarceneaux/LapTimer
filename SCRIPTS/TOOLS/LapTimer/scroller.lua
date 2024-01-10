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

local lib = { }

local lineHeight = 12

-- Return true if the first arg matches any of the following args
local function match(x, ...)
    for i, y in ipairs({...}) do
        if x == y then
            return true
        end
    end
    return false
end

lib.match = match

-- Create a new GUI object with interactive screen elements
function lib.newPage()

    local gui = {
        x = 0,
        y = 0
    }

    -- The default callBack
    local function doNothing()
    end

    -- Adjust text according to horizontal alignment
    local function align(x, w, flags)
        if bit32.band(flags, RIGHT) == RIGHT then
            return x + w
        elseif bit32.band(flags, CENTER) == CENTER then
            return x + w / 2
        else
            return x
        end
    end -- align(...)

    function gui.scroller(x, y, w, h, items, showSelection, callBack, flags)

        local self = {
            items = items or { "No items!" },
            flags = bit32.bor(flags or 0x00, LEFT),
            selected = 1
        }

        local selected = 1
        local firstVisible = 1
        local moving = 0
        local lh = lineHeight
        local visibleCount = math.floor(h / lh)
        local killEvt

        callBack = callBack or doNothing

        local function setFirstVisible(v)
            firstVisible = v
            firstVisible = math.max(1, firstVisible)
            firstVisible = math.min(#self.items - visibleCount + 1, firstVisible)
        end

        local function adjustScroll()
            if selected >= firstVisible + visibleCount then
                firstVisible = selected - visibleCount + 1
            elseif selected < firstVisible then
                firstVisible = selected
            end
        end

        function self.run(event, touchState)
            self.draw()
            self.onEvent(event, touchState)
        end -- run(...)
    
        function self.draw()
            local flags = self.flags
            local visibleCount = math.min(visibleCount, #self.items)

            for i = 0, visibleCount - 1 do
                local j = firstVisible + i
                local y = y + i * lh

                local function drawScrollArrows(flags)
                    if visibleCount < #self.items then
                        if firstVisible > 1 and i == 0 then
                            lcd.drawText(x + w - 8, y + lh / 2, CHAR_UP, flags)
                        elseif i == visibleCount - 1 and firstVisible+visibleCount-1 < #self.items then
                            lcd.drawText(x + w - 8, y + lh / 2, CHAR_DOWN, flags)
                        end
                    end
                end

                if j == selected and showSelection then
                    lcd.drawFilledRectangle(x-1, y + (lh / 2) - 1, w, lh - 3, INVERS)
                    lcd.drawText(align(x, w, flags), y + lh / 2, self.items[j], bit32.bor(INVERS, flags))
                    drawScrollArrows(INVERS)
                else
                    lcd.drawText(align(x, w, flags), y + lh / 2, self.items[j], flags)
                    drawScrollArrows()
                end

            end

        end -- draw()

        function self.onEvent(event, touchState)
            local visibleCount = math.min(visibleCount, #self.items)

            if moving ~= 0 then
                if match(event, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
                    moving = 0
                    event = 0
                else
                    setFirstVisible(firstVisible + moving)
                end
            end

            if event ~= 0 then
                -- This hack is needed because killEvents does not seem to work
                if killEvt then
                    killEvt = false
                    if event == EVT_VIRTUAL_ENTER then
                    event = 0
                    end
                end

                if match(event, EVT_VIRTUAL_NEXT, EVT_VIRTUAL_PREV) then
                    if event == EVT_VIRTUAL_NEXT then
                        selected = math.min(#self.items, selected + 1)
                        if not showSelection then
                            selected = firstVisible + visibleCount
                            if selected > #self.items then
                                selected = #self.items
                            end
                        end
                    elseif event == EVT_VIRTUAL_PREV then
                        selected = math.max(1, selected - 1)
                        if not showSelection then
                            selected = firstVisible - 1
                            if selected < 1 then
                                selected = 1
                            end
                        end
                    end
                    adjustScroll()
                    elseif event == EVT_VIRTUAL_ENTER then
                        self.selected = selected
                        callBack(self, self.items[selected])
                elseif event == EVT_VIRTUAL_EXIT then
                    callBack(self, EVT_VIRTUAL_EXIT)
                end
            end
        end -- onEvent(...)

        return self
    end -- scroller(...)

    return gui
end

return lib
