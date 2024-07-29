--- This module helps building correct URLs.

mod = {}

urlMetatable = {
	__tostring = function(t)
		local params = ""
		for i, param in ipairs(t.queryParameters) do
			if i == 1 then
				params = params .. "?" .. param.key .. "=" .. param.value
			else
				params = params .. "&" .. param.key .. "=" .. param.value
			end
		end
		local str = t.scheme .. "://" .. t.host .. t.path .. params
		if t.fragment ~= "" then
			str = str .. "#" .. t.fragment
		end
		return str
	end,
	__metatable = false,
}

urlMetatable.__index = {
	toString = function(self)
		return urlMetatable.__tostring(self)
	end,
	addQueryParameter = function(self, key, value)
		if type(key) ~= "string" then
			error("url:addQueryParameter(key, value) - key should be a string", 2)
		end
		if value == nil or value == "" then
			-- no need to set empty value, silent return
			return
		end
		table.insert(self.queryParameters, { key = key, value = value })
	end,
}

mod.parse = function(_, urlString)
	local url = {
		scheme = "",
		host = "",
		path = "",
		queryParameters = {}, -- each parameter is a table of this form: { key = "some key", value = "some value"}
		fragment = "",
	}
	setmetatable(url, urlMetatable)

	local scheme, remainder = urlString:match("^(%w+)://(.*)")
	if scheme then
		url.scheme = scheme
	else
		remainder = urlString
	end

	local host, pathAndQuery = remainder:match("^([^/?#]+)(.*)")
	if host then
		url.host = host
	end

	local path, queryStringAndFragment = pathAndQuery:match("^([^?#]*)(.*)")
	if path then
		url.path = path
	end

	local queryString, fragment = queryStringAndFragment:match("^%?([^#]*)(#?.*)")
	if queryString then
		for key, value in queryString:gmatch("([^&=]+)=([^&=]*)&*") do
			table.insert(url.queryParameters, { key = key, value = value })
		end
	end

	if fragment then
		fragment = fragment:match("#(.*)")
		if fragment then
			url.fragment = fragment
		end
	end

	return url
end

return mod
