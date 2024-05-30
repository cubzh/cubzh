localize = {}

bundle = require("bundle")

prefLanguages = nil
loadedLanguages = {}

function loadLanguage(l)
	if loadedLanguages[l] ~= nil then
		return
	end

	local data = bundle:Data("i18n/" .. l .. ".json")
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
	local v = loadedLanguages[l][key]

	if v == nil then
		return nil
	end

	if type(context) == "string" then
		if type(v) ~= "table" then
			print("v is not a table")
			return
		end
		v = v[context]
		if type(v) == "string" then
			return v
		else
			return nil
		end
	end

	-- no context
	if type(v) == "string" then
		return v
	end

	if type(v) ~= "table" then
		v = v[1] -- get array's first entry
		if type(v) == "string" then
			return v
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
