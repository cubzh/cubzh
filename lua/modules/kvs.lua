--[[

Key-Value store module

]]
--

local mod = {}

local get = function(self, ...)
	local args = { ... }
	local argCount = #args

	local keys = { table.unpack(args, 1, argCount - 1) }
	local callback = args[argCount]

	-- check all keys are strings
	for _, v in ipairs(keys) do
		if type(v) ~= "string" then
			error("keys should be strings")
		end
	end

	-- check callback is a function
	if type(callback) ~= "function" then
		error("callback should be a function")
	end

	return System:KvsGet(self.name, keys, callback)
end

local set = function(self, ...)
	local args = { ... }
	local argCount = #args

	local keyValueList = { table.unpack(args, 1, argCount - 1) }
	local callback = args[argCount]

	-- validation
	if (argCount - 1) % 2 > 0 then
		error("a key or value might be missing")
	end
	-- check callback is a function
	if type(callback) ~= "function" then
		error("callback should be a function")
	end
	keyValueMap = {}
	for i, v in ipairs(keyValueList) do
		if i % 2 > 0 then
			if type(v) ~= "string" then
				error("keys should be strings")
			end
		else
			keyValueMap[keyValueList[i - 1]] = v
		end
	end

	return System:KvsSet(self.name, keyValueMap, callback)
end

-- kvs:remove("myKey", "myKey2", function(ok) end)
local remove = function(self, ...)
	local args = { ... }
	local argCount = #args

	local keys = { table.unpack(args, 1, argCount - 1) }
	local callback = args[argCount]

	-- check all keys are strings
	for _, v in ipairs(keys) do
		if type(v) ~= "string" then
			error("keys should be strings")
		end
	end

	-- check callback is a function
	if type(callback) ~= "function" then
		error("callback should be a function")
	end

	return System:KvsRemove(self.name, keys, callback)
end

-- Define a metatable with __call metamethod
local metatable = {
	__tostring = function(_)
		return "[KeyValueStore (class)]"
	end,
	__type = 60,
	__call = function(_, storeName)
		if type(storeName) ~= "string" then
			error("store name should be a string", 2)
		end
		-- return a store object
		local newStore = {
			name = storeName,
			get = get, -- signature: (self, key1, key2, ..., callback)
			set = set, -- signature: (self, key1, val1, key2, val2, ..., callback)
			remove = remove, -- signature: (self, key1, key2, ..., callback)
			-- legacy functions:
			Get = get,
			Set = set,
		}
		setmetatable(newStore, {
			__tostring = function(self)
				return "[KeyValueStore " .. self.name .. "]"
			end,
			__type = 61,
		})
		return newStore
	end,
}

setmetatable(mod, metatable)

return mod
