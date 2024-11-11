config = {}

defaultOptions = {
	acceptIntegersAndNumbersDefault = true,
	acceptIntegersAndNumbers = {}, -- map field name : boolean
	acceptTypes = {}, -- { fieldName : { "Number3", "Object" }}
}

config.merge = function(self, defaults, overrides, options, showIgnoring)
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

	local opts
	if options ~= nil then
		opts = config:merge(defaultOptions, options)
	else
		opts = defaultOptions
	end

	local conf = {}
	for k, v in pairs(defaults) do
		if type(k) ~= "string" then
			error("config:merge(defaults, overrides, option) - all keys in defaults should be strings", 2)
		end
		conf[k] = v
	end

	local overriden
	local types
	local vType
	if overrides then
		for k, v in pairs(overrides) do
			vType = type(v)
			overriden = false
			if vType == type(conf[k]) then
				conf[k] = v
				overriden = true
			else
				if
					(opts.acceptIntegersAndNumbersDefault or opts.acceptIntegersAndNumbers[k] == true)
					and (type(conf[k]) == "number" or type(conf[k]) == "integer")
					and (vType == "number" or vType == "integer")
				then
					conf[k] = v
					overriden = true
				elseif opts.acceptTypes[k] ~= nil then
					types = opts.acceptTypes[k]
					for _, t in ipairs(types) do
						if vType == t or t == "*" then
							conf[k] = v
							overriden = true
							break
						end
					end
				end
			end
			if overriden == false and showIgnoring then
				print("⚠️ config:merge - overrides key ignored: " .. k)
			end
		end
	end

	return conf
end

return config
