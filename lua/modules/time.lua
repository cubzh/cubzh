---@type time

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
time.ago = function(t, config)
	if t == nil then error("time.ago(t, config) - time parameter can't be nil", 2) end
	if config == nil then config = {} end
	if type(config) ~= "table" then error("time.ago(t, config) - config should be an table", 2) end

	local _config = {
		lang = "en" --variants: en, ru, ua
	}	

	for key, value in pairs(_config) do
		if config[key] == nil then
			config[key] = value
		end
	end

	if config.lang ~= "en" and config.lang ~= "ru" and config.lang ~= "ua" then
		error("time.ago(t, config) - key \"lang\" in config have invalid value \""..config.lang.."\"")
	end

	local names = {
		en = {seconds = "seconds", minutes = "minutes", hours = "hours", days = "days", months = "months", years = "years"},
		ru = {seconds = "секунд", minutes = "минут", hours = "часов", days = "дней", months = "месяцев", years = "лет"},
		ua = {seconds = "секунд", minutes = "хвилин", hours = "годин", days = "днів", months = "місяців", years = "років"}
	}

	local now = os.time(os.date("!*t")) -- GMT
	local seconds = now - t
	local r

	if seconds < 0 then
		return 0, names[config.lang][seconds]
	elseif seconds > 31536000 then -- years
		r = math.floor((seconds / 31536000) * 10) / 10
		return r, names[config.lang][years]
	elseif seconds > 2628288 then -- months
		r = math.floor(seconds / 2628288)
		return r, names[config.lang][months]
	elseif seconds > 86400 then -- days
		r = math.floor(seconds / 86400)
		return r, names[config.lang][days]
	elseif seconds > 3600 then -- hours
		r = math.floor(seconds / 3600)
		return r, names[config.lang][hours]
	elseif seconds > 60 then -- minutes
		r = math.floor(seconds / 60)
		return r, names[config.lang][minutes]
	else
		return seconds, names[config.lang][seconds]
	end
end

---@function monthToString Converts an integer into its string representation
---@param self time
---@param month integer
---@param config table
---@return string
time.monthToString = function(self, month, config)
	if config == nil then config = {} end

	if self ~= time then error("time:monthToString(month, config): use `:`", 2) end
	if type(month) ~= Type.integer then error("time:monthToString(month, config): month should be an integer", 2) end
	if type(config) ~= "table" then error("time:monthTostring(month, config): config should be an table", 2) end

	local _config = {
		lang = "en" --variants: en, ru, ua
	}	

	for key, value in pairs(_config) do
		if config[key] == nil then
			config[key] = value
		end
	end

	if config.lang == "en" then
		local months = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
	elseif config.lang == "ru"
		local months = {"Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"}
	elseif config.lang == "ua"
		local months = {"Січень", "Лютий", "Березень", "Квітень", "Травень", "Червень", "Липень", "Серпень", "Вересень", "Жовтень", "Листопад", "Грудень"}
	else
		error("time:monthToString(month, config): key \"lang\" in config have invalid value \""..config.lang.."\"", 2)
	end
	
	return months[month]
end


---@function iso8601ToTable Converts iso8601 time into a table with year, month and other fields
---@param self time
---@param isoTime string
---@return table
time.iso8601ToTable = function(self, isoTime)
	if self ~= time then error("time:iso8601ToTable(isoTime): use `:`", 2) end
	if type(isoTime) ~= Type.string then error("time:iso8601ToTable(isoTime): isoTime should be an string", 2) end

	-- Parse time which is in string format
	local year, month, day, hour, minute, seconds = isoTime:match("(%d+)%-(%d+)%-(%d+)%a(%d+)%:(%d+)%:([%d%.]+)([Z%+%- ])(%d?%d?)%:?(%d?%d?)")

	local table = {year = year, month = month, day = day, hour = hour, minute = minute, second = math.floor(seconds)}
	return table
end

return time
