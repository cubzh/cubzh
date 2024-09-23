-- This module is used to store any kind of values for future retrieval.
-- When storing a value, an integer index is returned as well as a random access key.
-- Both index and key must be provided to access stored value.
-- Using simple, not cryptographically secure keys.
-- This is meant to be used as an ephemeral local store, to simplify patterns where asynchronicity is involved.

local module = {}

local store = {}
local keyLength = 8
local nextIndex = 1

local function generateRandomKey()
	local key = ""
	for _ = 1, keyLength do
		key = key .. string.char(math.random(65, 90)) -- alpha chars
	end
	return key
end

module.set = function(self, v)
	if self ~= module then
		error("safeStore:set(v) must be called with `:`", 2)
	end
	if v == nil then
		error("safeStore:set(v) - v can't be nil", 2)
	end
	local index = nextIndex
	local key = generateRandomKey()
	nextIndex = nextIndex + 1

	store[index] = { value = v, key = key }

	return index, key
end

module.get = function(self, index, key)
	if self ~= module then
		error("safeStore:get(v) must be called with `:`", 2)
	end

	local entry = store[index]
	if entry == nil then
		return nil
	end

	if entry.key ~= key then
		return nil
	end

	return entry.value
end

module.remove = function(self, index, key)
	if self ~= module then
		error("safeStore:remove(v) must be called with `:`", 2)
	end

	local entry = store[index]
	if entry == nil then
		return
	end

	if entry.key ~= key then
		return
	end

	store[index] = nil
end

return module
