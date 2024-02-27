---@type time

local time = {}

-- `iso8601` argument is a string
time.iso8601_to_os_time = function(iso8601)
	-- Parse time which is in string format
	local year, month, day, hour, minute, seconds, offsetsign, offsethour, offsetmin =
		iso8601:match("(%d+)%-(%d+)%-(%d+)%a(%d+)%:(%d+)%:([%d%.]+)([Z%+%- ])(%d?%d?)%:?(%d?%d?)")

	-- print(">>> offset hour:", offsethour)
	-- print(">>> offset min:", offsetmin)
	-- print(">>> offset sign:", offsetsign)

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

	print(">>> iso8601>>", iso8601) -- 2023-01-31T13:03:01.681Z
	print(">>> timestampO:", timestamp)

	local r = timestamp - (offsetMinutes * 60)

	print(">>> timestampF:", r)

	return r
end

-- returns number and unit type ("seconds", "minutes", "hours", "days", "months", "years") (string)
time.ago = function(t)
	if t == nil then
		error("time.ago - time parameter can't be nil", 2)
	end

	-- local now1 = os.date("!*t")
	-- local now = os.time(now1) -- GMT
	local now = os.time() -- GMT
	local seconds = now - t
	local r

	if seconds < 0 then
		print("🔥 WARNING TIME IS IN FUTURE")
		-- print("  - now:", now1)
		print("  - now:", now)
		print("  - now:", os.time())
		print("  - t  :", t)
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
