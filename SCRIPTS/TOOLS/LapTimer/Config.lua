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

-- This script handles the config file for the lap timer system
-- Author: Allen Arceneaux
-- Date: 2024

local log, const  = ...

-- --------------------------------------------------------------
local config = {
    TimerSwitch = getSwitchIndex("L01"),
    LapSwitch = getSwitchIndex("SC"..CHAR_DOWN),
    SpeakLapNumber = true,
    SpeakLapTime = true,
	SpeakAnnouncements = true,
    BeepOnLap = true,
	SpeakFasterSlower = true,
	CountDownFrom = 30,
	NumberOfLaps = 6
}

local CONFIG_FILENAME = const.script_folder..'/DATA/'..const.app_name..'.cfg'

-- --------------------------------------------------------------
local function iif(cond, T, F)
	if cond then return T else return F end
end

-- --------------------------------------------------------------
-- Read Config file
-- --------------------------------------------------------------

function config.read()
    log.info("Reading config file")

    local f = io.open(CONFIG_FILENAME, 'a')
	if f ~= nil then
		io.close(f)
	end

	f = io.open(CONFIG_FILENAME, 'r')
	if f == nil then
        log.info("No config file found, using defaults to create a new one")
		-- defaults will be used
		config.write()
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

	config.TimerSwitch = iif(c[1]==nil, config.TimerSwitch, tonumber(c[1]))
	config.LapSwitch = iif(c[2]==nil, config.LapSwitch, tonumber(c[2]))
	config.SpeakLapNumber = iif(c[3]==nil, config.SpeakLapNumber, (c[3] == 'true'))
	config.SpeakLapTime = iif(c[4]==nil, config.SpeakLapTime, (c[4] == 'true'))
	config.SpeakAnnouncements = iif(c[5]==nil, config.SpeakAnnouncements, (c[5] == 'true'))
	config.BeepOnLap = iif(c[6]==nil, config.BeepOnLap, (c[6] == 'true'))
	config.SpeakFasterSlower = iif(c[7]==nil, config.SpeakFasterSlower, (c[7] == 'true'))
	config.CountDownFrom = iif(c[8]==nil, config.CountDownFrom, tonumber(c[8]))
	config.NumberOfLaps = iif(c[9]==nil, config.NumberOfLaps, tonumber(c[9]))

	return true
end

-- --------------------------------------------------------------
-- Save config file
-- --------------------------------------------------------------

function config.write()
    log.info("Saving config file")
	local f = io.open(CONFIG_FILENAME, 'w')

	io.write(f, config.TimerSwitch)
	io.write(f, ',' .. config.LapSwitch)
	io.write(f, ',' .. iif(config.SpeakLapNumber, 'true', 'false'))
	io.write(f, ',' .. iif(config.SpeakLapTime, 'true', 'false'))
	io.write(f, ',' .. iif(config.SpeakAnnouncements, 'true', 'false'))
	io.write(f, ',' .. iif(config.BeepOnLap, 'true', 'false'))
	io.write(f, ',' .. iif(config.SpeakFasterSlower, 'true', 'false'))
	io.write(f, ',' .. config.CountDownFrom)
	io.write(f, ',' .. config.NumberOfLaps)
	io.close(f)
	log.info("Config file saved")
end

-- --------------------------------------------------------------
-- Common functions
-- --------------------------------------------------------------
function config.dump()
    log.info("TimerSwitch: "..config.TimerSwitch)
    log.info("LapSwitch: "..config.LapSwitch)   
    log.info("SpeakLapNumber: "..iif(config.SpeakGoodBad, 'true', 'false'))
    log.info("SpeakLapTime: "..iif(config.SpeakLapTime, 'true', 'false'))
	log.info("SpeakAnnouncements: "..iif(config.SpeakAnnouncements, 'true', 'false'))
    log.info("BeepOnLap: "..iif(config.BeepOnLap, 'true', 'false'))
	log.info("SpeakBetterWorse: "..iif(config.SpeakFasterSlower, 'true', 'false'))
    log.info("CountDownFrom: "..config.CountDownFrom)   
    log.info("CountDownFrom: "..config.NumberOfLaps)   
end

-- --------------------------------------------------------------
-- ok to do initial read.
-- --------------------------------------------------------------
if config.read() == false then
    log.info("No config file found, using defaults")
end

config.dump()

return config