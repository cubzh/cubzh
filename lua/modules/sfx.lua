local sfx = {}

local pool = {}
local defaultConfig = {
	Position = Number3.Zero,
	Volume = 1,
	Radius = 600,
	MinRadius = 200,
	Spatialized = false,
	Pitch = 1.0,
}

local function recycleASAfterDelay(delay, poolName, as)
	Timer(delay, function()
		table.insert(pool[poolName], as)
	end)
end

local as
local recycled

local mt = {
	__call = function(_, name, config)
		if pool[name] == nil then
			pool[name] = {}
		else
			recycled = table.remove(pool[name])
		end

		if recycled ~= nil then
			recycled.Position = config.Position or defaultConfig.Position
			recycled.Volume = config.Volume or defaultConfig.Volume
			recycled.Radius = config.Radius or defaultConfig.Radius
			recycled.MinRadius = config.MinRadius or defaultConfig.MinRadius
			if config.Spatialized ~= nil then
				recycled.Spatialized = config.Spatialized
			else
				recycled.Spatialized = defaultConfig.Spatialized
			end
			recycled.Pitch = config.Pitch or defaultConfig.Pitch
			recycled:Play()
			recycleASAfterDelay(recycled.Length + 0.1, name, recycled)
			return
		end

		as = AudioSource()
		as.Sound = name
		as.Position = config.Position or defaultConfig.Position
		as.Volume = config.Volume or defaultConfig.Volume
		as.Radius = config.Radius or defaultConfig.Radius
		as.MinRadius = config.MinRadius or defaultConfig.MinRadius
		if config.Spatialized ~= nil then
			as.Spatialized = config.Spatialized
		else
			as.Spatialized = defaultConfig.Spatialized
		end
		as.Pitch = config.Pitch or defaultConfig.Pitch
		as:SetParent(World)
		as:Play()

		recycleASAfterDelay(as.Length + 0.1, name, as)
	end,
}

setmetatable(sfx, mt)

if AudioListener.GetParent ~= nil and AudioListener:GetParent() == nil then
	AudioListener:SetParent(Camera)
end

return sfx
