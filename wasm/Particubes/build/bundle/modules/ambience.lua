local ambience = {}

cycleTickListener = nil

local default = {
	sky = {
		skyColor = Color(0, 168, 255),
		horizonColor = Color(137, 222, 229),
		abyssColor = Color(76, 144, 255),
		lightColor = Color(142, 180, 204),
		lightIntensity = 0.600000,
	},
	fog = {
		color = Color(19, 159, 204),
		near = 300,
		far = 700,
		lightAbsorbtion = 0.400000,
	},
	sun = {
		color = Color(255, 247, 204),
		intensity = 1.000000,
		rotation = Rotation(1.061161, 3.089219, 0.000000),
	},
	ambient = {
		color = nil,
		skyLightFactor = 0.100000,
		dirLightFactor = 0.200000,
	},
}

local configMT = {
	__newindex = function(_, k)
		error("key not supported in ambience config: " .. k, 2)
	end,
	__index = function()
		return nil
	end,
}

local skyMT = {
	__index = function(_, k)
		return default.sky[k]
	end,
}

local fogMT = {
	__index = function(_, k)
		return default.fog[k]
	end,
}

local sunMT = {
	__index = function(_, k)
		return default.sun[k]
	end,
}

local ambientMT = {
	__index = function(_, k)
		return default.ambient[k]
	end,
}

local function _checkAndInstallMetatables(config)
	setmetatable(config, configMT)
	setmetatable(config.sky, skyMT)
	setmetatable(config.fog, fogMT)
	setmetatable(config.sun, sunMT)
	setmetatable(config.ambient, ambientMT)
end

configMT.__index = function(_, k)
	if k == "copy" then
		return function(self)
			local c = {
				sky = {
					skyColor = Color(self.sky.skyColor),
					horizonColor = Color(self.sky.horizonColor),
					abyssColor = Color(self.sky.abyssColor),
					lightColor = Color(self.sky.lightColor),
					lightIntensity = self.sky.lightIntensity,
				},
				fog = {
					color = Color(self.fog.color),
					near = self.fog.near,
					far = self.fog.far,
					lightAbsorbtion = self.fog.lightAbsorbtion,
				},
				sun = {
					color = Color(self.sun.color),
					intensity = self.sun.intensity,
					rotation = self.sun.rotation:Copy(),
				},
				ambient = {
					color = Color(self.ambient.color),
					skyLightFactor = self.ambient.skyLightFactor,
					dirLightFactor = self.ambient.dirLightFactor,
				},
			}
			_checkAndInstallMetatables(c)
			return c
		end
	end
end

ambience.dawn = {
	sky = {
		skyColor = Color(255, 110, 76),
		horizonColor = Color(255, 174, 102),
		abyssColor = Color(24, 113, 255),
		lightColor = Color(229, 183, 209),
		lightIntensity = 0.600000,
	},
	fog = {
		color = Color(229, 129, 90),
		near = 300,
		far = 700,
		lightAbsorbtion = 0.400000,
	},
	sun = {
		color = Color(255, 163, 127),
		intensity = 1.000000,
		rotation = Rotation(0.624828, 2.111841, 0.000000),
	},
	ambient = {
		skyLightFactor = 0.100000,
		dirLightFactor = 0.210000,
	},
}
_checkAndInstallMetatables(ambience.dawn)

ambience.noon = {
	sky = {
		skyColor = Color(0, 168, 255),
		horizonColor = Color(137, 222, 229),
		abyssColor = Color(76, 144, 255),
		lightColor = Color(142, 180, 204),
		lightIntensity = 0.600000,
	},
	fog = {
		color = Color(19, 159, 204),
		near = 300,
		far = 700,
		lightAbsorbtion = 0.400000,
	},
	sun = {
		color = Color(255, 247, 204),
		intensity = 1.000000,
		rotation = Rotation(1.061161, 3.089219, 0.000000),
	},
	ambient = {
		skyLightFactor = 0.100000,
		dirLightFactor = 0.200000,
	},
}
_checkAndInstallMetatables(ambience.noon)

ambience.dusk = {
	sky = {
		skyColor = Color(159, 76, 255),
		horizonColor = Color(255, 115, 102),
		abyssColor = Color(255, 167, 49),
		lightColor = Color(178, 107, 151),
		lightIntensity = 0.600000,
	},
	fog = {
		color = Color(113, 61, 153),
		near = 300,
		far = 700,
		lightAbsorbtion = 0.400000,
	},
	sun = {
		color = Color(211, 127, 255),
		intensity = 1.000000,
		rotation = Rotation(0.624827, 4.188794, 0.000000),
	},
	ambient = {
		skyLightFactor = 0.100000,
		dirLightFactor = 0.200000,
	},
}
_checkAndInstallMetatables(ambience.dusk)

ambience.midnight = {
	sky = {
		skyColor = Color(0, 8, 51),
		horizonColor = Color(48, 22, 76),
		abyssColor = Color(0, 8, 102),
		lightColor = Color(10, 17, 51),
		lightIntensity = 0.600000,
	},
	fog = {
		color = Color(31, 22, 76),
		near = 300,
		far = 700,
		lightAbsorbtion = 0.400000,
	},
	sun = {
		color = Color(27, 7, 76),
		intensity = 1.000000,
		rotation = Rotation(0.816814, 4.712389, 0.000000),
	},
	ambient = {
		skyLightFactor = 0.100000,
		dirLightFactor = 0.200000,
	},
}
_checkAndInstallMetatables(ambience.midnight)

local sun = Light()
sun.CastsShadows = true
sun.On = true
sun.Type = LightType.Directional
World:AddChild(sun)
ambience.sun = sun

function applyConfig(config)
	-- SKY
	Sky.LightColor = config.sky.lightColor or default.sky.lightColor
	Sky.SkyColor = config.sky.skyColor or default.sky.skyColor
	Sky.HorizonColor = config.sky.horizonColor or default.sky.horizonColor
	Sky.AbyssColor = config.sky.abyssColor or default.sky.abyssColor

	-- FOG
	Fog.Color = config.fog.color or default.fog.color
	Fog.Near = config.fog.near or default.fog.near
	Fog.Far = config.fog.far or default.fog.far

	-- SUN
	sun.Color = config.sun.color or default.sun.color
	sun.Intensity = config.sun.intensity or default.sun.intensity
	sun.Rotation = config.sun.rotation or default.sun.rotation

	Light.Ambient.SkyLightFactor = config.ambient.skyLightFactor or default.ambient.skyLightFactor
	Light.Ambient.DirectionalLightFactor = config.ambient.dirLightFactor or default.ambient.dirLightFactor
end

function lerp(a, b, t)
	return a * (1 - t) + b * t
end

function lerpConfigs(config1, config2, v)
	-- SKY

	local c = Color(0, 0, 0)

	c:Lerp(config1.sky.lightColor or default.sky.lightColor, config2.sky.lightColor or default.sky.lightColor, v)
	Sky.LightColor = c

	c:Lerp(config1.sky.skyColor or default.sky.skyColor, config2.sky.skyColor or default.sky.skyColor, v)
	Sky.SkyColor = c
	-- Sky.SkyColor:Lerp(config1.sky.skyColor or default.sky.skyColor, config2.sky.skyColor or default.sky.skyColor, v)

	c:Lerp(
		config1.sky.horizonColor or default.sky.horizonColor,
		config2.sky.horizonColor or default.sky.horizonColor,
		v
	)
	Sky.HorizonColor = c

	c:Lerp(config1.sky.abyssColor or default.sky.abyssColor, config2.sky.abyssColor or default.sky.abyssColor, v)
	Sky.AbyssColor = c

	-- FOG
	c:Lerp(config1.fog.color or default.fog.color, config2.fog.color or default.fog.color, v)
	Fog.Color = c
	Fog.Near = lerp(config1.fog.near or default.fog.near, config2.fog.near or default.fog.near, v)
	Fog.Far = lerp(config1.fog.far or default.fog.far, config2.fog.far or default.fog.far, v)

	-- SUN
	c:Lerp(config1.sun.color or default.sun.color, config2.sun.color or default.sun.color, v)
	sun.Color = c
	sun.Intensity =
		lerp(config1.sun.intensity or default.sun.intensity, config2.sun.intensity or default.sun.intensity, v)

	sun.Rotation:Lerp(config1.sun.rotation or default.sun.rotation, config2.sun.rotation or default.sun.rotation, v)

	Light.Ambient.SkyLightFactor = lerp(
		config1.ambient.skyLightFactor or default.ambient.skyLightFactor,
		config2.ambient.skyLightFactor or default.ambient.skyLightFactor,
		v
	)
	Light.Ambient.DirectionalLightFactor = lerp(
		config1.ambient.dirLightFactor or default.ambient.dirLightFactor,
		config2.ambient.dirLightFactor or default.ambient.dirLightFactor,
		v
	)
end

ambience.set = function(_, config)
	ambience:stopCycle()
	applyConfig(config)
end

local defaultCycleAmbiences = {
	{
		config = ambience.noon,
		duration = 10.0, -- in seconds
		-- cross-fade with next ambience (total time == fadeOut + next ambience's fadeIn)
		fadeOut = 5.0, -- optional, duration * 0.5 by default
		fadeIn = 5.0, -- optional, duration * 0.5 by default
	},
	{
		config = ambience.dusk,
		duration = 3.0,
	},
	{
		config = ambience.midnight,
		duration = 4.0,
	},
	{
		config = ambience.dawn,
		duration = 3.0,
	},
}

local defaultCycleConfig = {
	internalTick = true,
}

ambience.startCycle = function(_, ambiences, config)
	ambience:stopCycle()

	conf = require("config")
	config = conf:merge(defaultCycleConfig, config)

	if ambiences == nil then
		ambiences = defaultCycleAmbiences
	end

	local totalTime = 0.0

	for _, ambience in ipairs(ambiences) do
		if ambience.fadeIn == nil or ambience.fadeOut == nil then
			ambience.fadeIn = ambience.duration * 0.5
			ambience.fadeOut = ambience.duration * 0.5
		end
		totalTime = totalTime + ambience.duration
	end

	local nbAmbiences = #ambiences
	local currentAmbience
	local previousAmbience
	local nextAmbience
	local t = 0.0
	local subT = 0.0 -- t, in current ambience
	local cursor = 0.0 -- t, in current ambience
	local fadeDuration
	local v

	local cycle = {}

	cycle.addTime = function(self, dt)
		t = t + dt
		self:setTime(t)
	end

	cycle.setTime = function(_, newT)
		t = newT % totalTime

		cursor = 0.0
		for i, ambience in ipairs(ambiences) do
			if t > cursor + ambience.duration then
				cursor = cursor + ambience.duration
			else
				subT = t - cursor
				currentAmbience = ambiences[i]
				if i > 1 then
					previousAmbience = ambiences[i - 1]
				else
					previousAmbience = ambiences[nbAmbiences]
				end
				if i < nbAmbiences then
					nextAmbience = ambiences[i + 1]
				else
					nextAmbience = ambiences[1]
				end
				break
			end
		end

		-- while t > currentAmbience.duration do
		-- 	t = t - currentAmbience.duration
		-- 	currentAmbienceIndex = currentAmbienceIndex + 1
		-- 	if currentAmbienceIndex > nbAmbiences then
		-- 		currentAmbienceIndex = 1
		-- 	end
		-- 	currentAmbience = ambiences[currentAmbienceIndex]
		-- 	i = currentAmbienceIndex + 1
		-- 	if i > nbAmbiences then
		-- 		i = 1
		-- 	end
		-- 	nextAmbience = ambiences[i]
		-- 	i = currentAmbienceIndex - 1
		-- 	if i < 1 then
		-- 		i = nbAmbiences
		-- 	end
		-- 	previousAmbience = ambiences[i]
		-- end

		if subT < currentAmbience.fadeIn then
			fadeDuration = previousAmbience.fadeOut + currentAmbience.fadeIn
			v = (previousAmbience.fadeOut + subT) / fadeDuration
			lerpConfigs(previousAmbience.config, currentAmbience.config, v)
		elseif subT > currentAmbience.duration - currentAmbience.fadeOut then
			fadeDuration = currentAmbience.fadeOut + nextAmbience.fadeIn
			v = (subT - (currentAmbience.duration - currentAmbience.fadeOut)) / fadeDuration
			lerpConfigs(currentAmbience.config, nextAmbience.config, v)
		else
			applyConfig(currentAmbience.config)
		end
	end

	if config.internalTick then
		cycleTickListener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
			cycle:addTime(dt)
		end)
	end

	return cycle
end

ambience.stopCycle = function()
	if cycleTickListener ~= nil then
		cycleTickListener:Remove()
		cycleTickListener = nil
	end
end

ambience.pauseCycle = function()
	if cycleTickListener ~= nil then
		cycleTickListener:Pause()
	end
end

ambience.resumeCycle = function()
	if cycleTickListener ~= nil then
		cycleTickListener:Resume()
	end
end

ambience:set(ambience.noon)

return ambience
