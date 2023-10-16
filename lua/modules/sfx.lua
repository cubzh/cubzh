local sfx = {
	pool = {},
	defaultConfig = {
		Position = Number3(0, 0, 0),
		Volume = 1,
		Radius = 600,
		Spatialized = true,
		Pitch = 1.0,
	},
}

local mt = {
	__call = function(self, name, config)
		local sfxPool = self.pool

		local recycled
		local pool = sfxPool[name]
		if pool == nil then
			sfxPool[name] = {}
		else
			recycled = table.remove(pool)
		end

		if recycled ~= nil then
			recycled.Position = config.Position or self.defaultConfig.Position
			recycled.Volume = config.Volume or self.defaultConfig.Volume
			recycled.Radius = config.Radius or self.defaultConfig.Radius
			if config.Spatialized ~= nil then
				recycled.Spatialized = config.Spatialized
			else
				recycled.Spatialized = self.defaultConfig.Spatialized
			end
			recycled.Pitch = config.Pitch or self.defaultConfig.Pitch
			recycled:Play()
			Timer(recycled.Length + 0.1, function()
				table.insert(sfxPool[name], recycled)
			end)
			return
		end

		local as = AudioSource()
		as.Sound = name
		as.Position = config.Position or self.defaultConfig.Position
		as.Volume = config.Volume or self.defaultConfig.Volume
		as.Radius = config.Radius or self.defaultConfig.Radius
		if config.Spatialized ~= nil then
			as.Spatialized = config.Spatialized
		else
			as.Spatialized = self.defaultConfig.Spatialized
		end
		as.Pitch = config.Pitch or self.defaultConfig.Pitch
		as:SetParent(World)
		as:Play()

		Timer(as.Length + 0.1, function()
			table.insert(sfxPool[name], as)
		end)
	end,
}

setmetatable(sfx, mt)

if AudioListener.GetParent ~= nil and AudioListener:GetParent() == nil then
	AudioListener:SetParent(Camera)
end

return sfx
