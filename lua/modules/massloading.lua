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
local onListLoaded = function(list)
    print(string.format("Successfully loaded %d items", #list))
end
local config = {
    onLoad = onLoad, -- called when a shape is loaded, first parameter is the object, second is the element of the list
    onListLoaded = onListLoaded, -- called when all the items are loaded
    fullnameItemKey = "fullname", -- the key representing the fullname of the shape
}
massLoading:load(list, config)
--]]

local massLoading = {}

local cachedObjects = {}
local awaitingObjects = {}
local loadingObjects = {}

massLoading.getObject = function(_, name)
    return cachedObjects[name]
end

massLoading.load = function(_, list, config)
    local defaultConfig = {
		onLoad = nil,
		onListLoaded = nil,
		fullnameItemKey = "fullname",
	}
    config = require("config"):merge(defaultConfig, config, {
        acceptTypes = { onLoad = { "function" }, onListLoaded = { "function" } }
    })
	if not config.onLoad then
		error("you must define config.onLoad")
		return
	end

    local nbObjectsLoaded = 0
    local function loadedNextObject()
        nbObjectsLoaded = nbObjectsLoaded + 1
        if nbObjectsLoaded >= #list then
            awaitingObjects = {}
            loadingObjects = {}
            config.onListLoaded(list)
        end
    end

    local function loadObject(template, data)
        config.onLoad(Shape(template, { includeChildren = true }), data)
        loadedNextObject()
    end

	for _,data in ipairs(list) do
		local fullname = data[config.fullnameItemKey]

		-- 1) in cache
		if cachedObjects[fullname] then
            loadObject(cachedObjects[fullname], data)

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
                loadObject(obj, data)

				-- load objects awaiting
				if awaitingObjects[fullname] then
					for _,awaitingData in ipairs(awaitingObjects[fullname]) do
                        loadObject(obj, awaitingData)
					end
                    awaitingObjects[fullname] = {}
				end
			end)
		end
	end
end

massLoading.clearCache = function()
    cachedObjects = {}
end

return massLoading