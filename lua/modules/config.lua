config = {}

defaultOptions = {
	acceptIntegersAndNumbersDefault = true,
	acceptIntegersAndNumbers = {}, -- map field name : boolean
	acceptNil = {}, -- map field name : boolean
}

config.merge = function(self, defaults, overrides, options)
	if self ~= config then
		error("config:merge should be called with `:`", 2)
	end

	if type(defaults) ~= "table" then
		error("config:merge(defaults, overrides, option) - defaults should be a table", 2)
	end

	if overrides ~= nil and type(overrides) ~= "table" then
		error("config:merge(defaults, overrides, option) - overrides should be nil or a table", 2)
	end

	if options ~= nil and type(options) ~= "table" then
		error("config:merge(defaults, overrides, option) - options should be nil or a table", 2)
	end

	local opts = type(options) == "table" and options or defaultOptions

	local conf = {}
	for k, v in pairs(defaults) do
		if type(k) ~= "string" then
			error("config:merge(defaults, overrides, option) - all keys in defaults should be strings", 2)
		end
		conf[k] = v
	end

	local overriden
	for k, v in pairs(overrides) do
		overriden = false
		if conf[k] ~= nil then
			if type(v) == type(conf[k]) then
				conf[k] = v
				overriden = true
			else
				if
					(opts.acceptIntegersAndNumbersDefault or opts.acceptIntegersAndNumbers[k] == true)
					and (type(conf[k]) == "number" or type(conf[k]) == "integer")
					and (type(v) == "number" or type(v) == "integer")
				then
					conf[k] = v
					overriden = true
				elseif v == nil and opts.acceptNil[k] == true then
					conf[k] = v
					overriden = true
				end
			end
			if overriden == false then
				print("⚠️ config:merge - overrides key ignored: " .. k)
			end
		end
	end

	return conf
end

return config
