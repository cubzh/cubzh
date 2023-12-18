
local massLoading = {}

local cachedObjects = {}
local awaitingObjects = {}
local loadingObjects = {}

local DEFAULT_BATCH_SIZE = 50
local DEFAULT_DELAY_BETWEEN_BATCH = 0.1 -- seconds
massLoading.load = function(_, list, config, index)
	if not massLoading.onLoad then
		error("you must define massLoading.onLoad before calling load")
		return
	end
    config = config or {}
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
			massLoading.onLoad(Shape(cachedObjects[fullname], { includeChildren = true }), data)

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
				massLoading.onLoad(Shape(obj, { includeChildren = true }), data)

				-- load objects awaiting
				if awaitingObjects[fullname] then
					for _,awaitingData in ipairs(awaitingObjects[fullname]) do
						massLoading.onLoad(Shape(obj, { includeChildren = true }), awaitingData)
					end
				end
			end)
		end
	end

	if index + config.batchSize > #list then return end

	return Timer(config.delayBetweenBatch, function()
		massLoading:load(list, config, index + config.batchSize)
	end)
end

return massLoading