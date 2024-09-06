---@type time

local time = {}

local conf = require("config")

-- `iso8601` argument is a string
time.iso8601_to_os_time = function(iso8601)
	-- print("iso8601>>", iso8601) -- 2023-01-31T13:03:01.681Z

	-- Parse time which is in string format
	local year, month, day, hour, minute, seconds, offsetsign, offsethour, offsetmin =
		iso8601:match("(%d+)%-(%d+)%-(%d+)%a(%d+)%:(%d+)%:([%d%.]+)([Z%+%- ])(%d?%d?)%:?(%d?%d?)")

	-- shifted 1 day to avoid dates before UNIX epoch (generates an error on Windows)
	local epochShifted = os.time({ year = 1970, month = 1, day = 2, hour = 0 })

	local shift = 24 * 3600 -- # seconds in 24 hours

	local timeParsed =
		os.time({ year = year, month = month, day = day, hour = hour, min = minute, sec = math.floor(seconds) })

	-- shifted 1 day to avoid dates before UNIX epoch (generates an error on Windows)
	local timeShifted = timeParsed + shift

	local timestamp = timeShifted - epochShifted

	-- apply timezone offset if there is any
	local offsetMinutes = 0
	if offsetsign ~= "Z" then
		offsetMinutes = tonumber(offsethour) * 60 + tonumber(offsetmin)
		if offsetsign == "-" then
			offsetMinutes = -offsetMinutes
		end
	end

	return timestamp - (offsetMinutes * 60)
end

local agoDefaultConfig = {
	seconds = true,
	minutes = true,
	hours = true,
	days = true,
	months = true,
	years = true,
	seconds_label = "seconds",
	minutes_label = "minutes",
	hours_label = "hours",
	days_label = "days",
	months_label = "months",
	years_label = "years",
}

-- returns number and unit type ("seconds", "minutes", "hours", "days", "months", "years") (string)
time.ago = function(t, config)
	if t == nil then
		error("time.ago - time parameter can't be nil", 2)
	end

	config = conf:merge(agoDefaultConfig, config)

	local now = os.time(os.date("!*t")) -- GMT
	local seconds = now - t
	local r

	if seconds < 0 then
		return 0, config.seconds_label
	elseif seconds > 31536000 and config.years == true then -- years
		r = math.floor((seconds / 31536000) * 10) / 10
		return r, config.years_label
	elseif seconds > 2628288 and config.months == true then -- months
		r = math.floor(seconds / 2628288)
		return r, config.months_label
	elseif seconds > 86400 and config.days == true then -- days
		r = math.floor(seconds / 86400)
		return r, config.days_label
	elseif seconds > 3600 and config.hours == true then -- hours
		r = math.floor(seconds / 3600)
		return r, config.hours_label
	elseif seconds > 60 and config.minutes == true then -- minutes
		r = math.floor(seconds / 60)
		return r, config.minutes_label
	else
		return seconds, config.seconds_label
	end
end

---@function monthToString Converts an integer into its string representation
---@param self time
---@param month integer
---@return string
time.monthToString = function(self, month)
	if self ~= time then
		error("time:monthToString(month): use `:`", 2)
	end
	if type(month) ~= Type.integer then
		error("time:monthToString(month): month should be an integer", 2)
	end

	local months = {
		"January",
		"February",
		"March",
		"April",
		"May",
		"June",
		"July",
		"August",
		"September",
		"October",
		"November",
		"December",
	}
	return months[month]
end

---@function iso8601ToTable Converts iso8601 time into a table with year, month and other fields
---@param self time
---@param isoTime string
---@return table
time.iso8601ToTable = function(self, isoTime)
	if self ~= time then
		error("time:iso8601ToTable(isoTime): use `:`", 2)
	end
	if type(isoTime) ~= Type.string then
		error("time:iso8601ToTable(isoTime): isoTime should be an string", 2)
	end

	-- Parse time which is in string format
	local year, month, day, hour, minute, seconds =
		isoTime:match("(%d+)%-(%d+)%-(%d+)%a(%d+)%:(%d+)%:([%d%.]+)([Z%+%- ])(%d?%d?)%:?(%d?%d?)")

	local table = { year = year, month = month, day = day, hour = hour, minute = minute, second = math.floor(seconds) }
	return table
end

return time
