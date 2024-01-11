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

-- This script will display the main menu for the LapTimer system
-- Author: Allen Arceneaux
-- Date: 2024

local c = loadScript("Common")()

local menuItem = 0
local VIEWER = 0
local SETUP = 1

-- --------------------------------------------------------------
-- Common functions
-- --------------------------------------------------------------
local function fieldIncDec(event, value, max)
    if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
        value = (value - 1)
    elseif event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
        value = (value + max + 3)
    end
    value = (value % (max+2))
    return value
end

-- --------------------------------------------------------------
-- Draw Menu
-- --------------------------------------------------------------
local function drawMenu()
    lcd.clear()

    lcd.drawText( 20, 30, "View Laps")
    lcd.drawText( 78, 30, "Setup")
    lcd.drawText(50, 1, c.version, BOLD)
    if menuItem == VIEWER then
      lcd.drawScreenTitle("LAP TIMER", 1, 4)
      lcd.drawFilledRectangle(59*(menuItem%2)+12, 23, 60, 22)
    else
      lcd.drawScreenTitle("LAP TIMER", 1, 2)
      lcd.drawFilledRectangle(59*(menuItem%2)+12, 23, 42, 22)
    end
end

-- --------------------------------------------------------------
-- Handle Menu
-- --------------------------------------------------------------
local function handleMenu(event)
    drawMenu()
  if event == EVT_VIRTUAL_ENTER then
    if menuItem == VIEWER then
      return "LapViewer.lua"
    elseif menuItem == SETUP then
      return "Setup.lua"
    end
  else
    menuItem = fieldIncDec(event, menuItem, 0)
  end
  return 0
end

function run(event)
    if event == nil then
        error("Cannot be run as a model script!")
        return 2
    end

    if event == EVT_VIRTUAL_EXIT then
        return 2
    end
       
    return handleMenu(event)
    
end
  
return { run=run }