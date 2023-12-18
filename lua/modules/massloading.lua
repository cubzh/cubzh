--[[
This module optimizes the loading of hundreds of shapes when loading a world for example.

It reduces the amount of HTTP request and readFile calls.

All the shapes are kept in a cache object.

-- Example
local list = {
    { fullname = "caillef.shop", pos = { 10, 24, 0 }, rotation = { 0, math.pi * 0.5, 0 }},
    { fullname = "caillef.shop", pos = { 10, 24, 1 }, rotation = { 0, math.pi * 0.5, 0 }},
    { fullname = "caillef.shop", pos = { 10, 24, 2 }, rotation = { 0, math.pi * 0.5, 0 }},
    { fullname = "caillef.shop", pos = { 10, 24, 3 }, rotation = { 0, math.pi * 0.5, 0 }},
    { fullname = "caillef.shop2", pos = { 10, 24, 4 }, rotation = { 0, math.pi * 0.5, 0 }},
    { fullname = "caillef.shop2", pos = { 10, 24, 5 }, rotation = { 0, math.pi * 0.5, 0 }},
    { fullname = "caillef.shop2", pos = { 10, 24, 6 }, rotation = { 0, math.pi * 0.5, 0 }},
    { fullname = "caillef.shop", pos = { 10, 24, 7 }, rotation = { 0, math.pi * 0.5, 0 }},
}

local massLoading = require("massLoading")
local onLoad = function(obj, data)
    -- here SetParent/use data to set position/rotation etc.
    print(obj, data.fullname, data.pos[3])
end
local config = {
    onLoad = onLoad, -- callback called when a shape is loaded, first parameter is the object, second is the element of the list
    key = "fullname", -- the key representing the fullname of the shape
    batchSize = 50, -- call to Shape constructor or Object:Load per batch
    delayBetweenBatch = 0.1 -- seconds
}
massLoading:load(list, config)
--]]

local massLoading = {}

local cachedObjects = {}
local awaitingObjects = {}
local loadingObjects = {}

local DEFAULT_BATCH_SIZE = 50
local DEFAULT_DELAY_BETWEEN_BATCH = 0.1 -- seconds
massLoading.load = function(_, list, config, index)
    config = config or {}
	if not config.onLoad then
		error("you must define config.onLoad")
		return
	end
	config.key = config.key or "fullname"
	config.batchSize = config.batchSize or DEFAULT_BATCH_SIZE
	config.delayBetweenBatch = config.delayBetweenBatch or DEFAULT_DELAY_BETWEEN_BATCH

	index = index or 1
    local maxIndex = math.min(#list, index + config.batchSize - 1) -- avoid overflow
	for i=index, maxIndex do
		local data = list[i]
		local fullname = data[config.key]

		-- 1) in cache
		if cachedObjects[fullname] then
			config.onLoad(Shape(cachedObjects[fullname], { includeChildren = true }), data)

		-- 2) already loading
		elseif loadingObjects[fullname] then
			if not awaitingObjects[fullname] then
				awaitingObjects[fullname] = {}
			end
			table.insert(awaitingObjects[fullname], data)

		-- 3) need to load
		else
			loadingObjects[fullname] = true
			Object:Load(fullname, function(obj)
				-- add object in cache
				cachedObjects[fullname] = obj

				-- load object
				loadingObjects[fullname] = false
				config.onLoad(Shape(obj, { includeChildren = true }), data)

				-- load objects awaiting
				if awaitingObjects[fullname] then
					for _,awaitingData in ipairs(awaitingObjects[fullname]) do
						config.onLoad(Shape(obj, { includeChildren = true }), awaitingData)
					end
				end
			end)
		end
	end

	if index + config.batchSize > #list then
        return
    end

	return Timer(config.delayBetweenBatch, function()
		massLoading:load(list, config, index + config.batchSize)
	end)
end

return massLoading