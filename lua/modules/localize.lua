localize = {}

bundle = require("bundle")

prefLanguages = nil
loadedLanguages = {}

function loadLanguage(l)
	if loadedLanguages[l] ~= nil then
		return
	end

	local data = Data:FromBundle("i18n/" .. l .. ".json")
	if data == nil then
		loadedLanguages[l] = {}
		return
	end

	loadedLanguages[l] = JSON:Decode(data)
end

function getLanguageWithoutRegion(languageCode)
	local languagePart = string.match(languageCode, "([^%-]+)")
	return languagePart
end

function _localize(l, key, context)
	loadLanguage(l)
	local val = loadedLanguages[l][key]

	if val == nil then
		return nil
	end

	if type(context) == "string" then
		if type(val) == "table" then
			val = val[context]
			if type(val) == "string" then
				return val
			else
				return nil
			end
		else
			-- Fallback to the rest of the function
			-- (`val` can be a string)
			--
			-- Debug log:
			-- print("val is not a table", type(v), key)
		end
	end

	-- no context
	if type(val) == "string" then
		return val
	end

	if type(val) ~= "table" then
		val = val[1] -- get array's first entry
		if type(val) == "string" then
			return val
		else
			return nil
		end
	end
end

local mt = {
	__call = function(_, str, context)
		if prefLanguages == nil then
			-- hack to test languages:
			-- prefLanguages = { "pl" } -- ua
			prefLanguages = Client.PreferredLanguages
		end

		local v
		local l2
		for _, l in ipairs(prefLanguages) do
			-- do not translate to english for now, english always considered to be the source
			if l == "en" then
				return str
			end
			v = _localize(l, str, context)
			if v == nil then
				l2 = getLanguageWithoutRegion(l)
				if l2 == "en" then
					return str
				end
				if l2 ~= "" and l2 ~= l then
					v = _localize(l2, str, context)
				end
			end
			if v ~= nil then
				return v
			end
		end
		return v or str
	end,
	__metatable = false,
}
setmetatable(localize, mt)

return localize
