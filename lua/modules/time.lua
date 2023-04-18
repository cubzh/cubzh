local time = {}

-- `iso8601` argument is a string
time.iso8601_to_os_time = function(iso8601)
	-- print("iso8601>>", iso8601) -- 2023-01-31T13:03:01.681Z

	-- Parse time which is in string format
	local year, month, day, hour, minute, seconds, offsetsign, offsethour, offsetmin = iso8601:match("(%d+)%-(%d+)%-(%d+)%a(%d+)%:(%d+)%:([%d%.]+)([Z%+%- ])(%d?%d?)%:?(%d?%d?)")

	-- shifted 1 day to avoid dates before UNIX epoch (generates an error on Windows)
	local epochShifted = os.time{year=1970, month=1, day=2, hour=0}

	local shift = 24 * 3600 -- # seconds in 24 hours

	local timeParsed = os.time{year = year, month = month, day = day, hour = hour, min = minute, sec = math.floor(seconds)}
	
	-- shifted 1 day to avoid dates before UNIX epoch (generates an error on Windows)
	local timeShifted = timeParsed + shift

	local timestamp = timeShifted - epochShifted

	-- apply timezone offset if there is any
	local offsetMinutes = 0
	if offsetsign ~= 'Z' then
		offsetMinutes = tonumber(offsethour) * 60 + tonumber(offsetmin)
		if offsetsign == "-" then 
			offsetMinutes = -offsetMinutes
		end
	end

	return timestamp - (offsetMinutes * 60)
end

-- returns number and unit type ("seconds", "minutes", "hours", "days", "months", "years") (string)
time.ago = function(t)
	if t == nil then error("time.ago - time parameter can't be nil", 2) end

	local now = os.time(os.date("!*t")) -- GMT
	local seconds = now - t
	local r

	if seconds < 0 then
		return 0, "seconds"
	elseif seconds > 31536000 then -- years
		r = math.floor((seconds / 31536000) * 10) / 10
		return r, "years"
	elseif seconds > 2628288 then -- months
		r = math.floor(seconds / 2628288)
		return r, "months"
	elseif seconds > 86400 then -- days
		r = math.floor(seconds / 86400)
		return r, "days"
	elseif seconds > 3600 then -- hours
		r = math.floor(seconds / 3600)
		return r, "hours"
	elseif seconds > 60 then -- minutes
		r = math.floor(seconds / 60)
		return r, "minutes"
	else
		return seconds, "seconds"
	end
end

return time