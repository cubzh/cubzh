
local ambience = {}

local default = {
	sky = {
		skyColor = Color(0,168,255),
		horizonColor = Color(137,222,229),
		abyssColor = Color(76,144,255),
		lightColor = Color(142,180,204),
		lightIntensity = 0.600000,
	},
	fog = {
		color = Color(19,159,204),
		near = 300,
		far = 700,
		lightAbsorbtion = 0.400000,
	},
	sun = {
		color = Color(255,247,204),
		intensity = 1.000000,
		rotation = Number3(1.061161, 3.089219, 0.000000),
	},
	ambient = {
		color = nil,
		skyLightFactor = 0.100000,
		dirLightFactor = 0.200000,
	}
}

local configMT = {
	__newindex = function(_, k)
		error("key not supported in ambience config: " .. k, 2)
	end,
	__index = function() return nil end,
}

local skyMT = {
	__index = function(_, k) return default.sky[k] end,
}

local fogMT = {
	__index = function(_, k) return default.fog[k] end,
}

local sunMT = {
	__index = function(_, k) return default.sun[k] end,
}

local ambientMT = {
	__index = function(_, k) return default.ambient[k] end,
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
				}
			}
			_checkAndInstallMetatables(c)
			return c
		end
	end
end

ambience.dawn = {
	sky = {
		skyColor = Color(255,110,76),
		horizonColor = Color(255,174,102),
		abyssColor = Color(24,113,255),
		lightColor = Color(229,183,209),
		lightIntensity = 0.600000,
	},
	fog = {
		color = Color(229,129,90),
		near = 300,
		far = 700,
		lightAbsorbtion = 0.400000,
	},
	sun = {
		color = Color(255,163,127),
		intensity = 1.000000,
		rotation = Number3(0.624828, 2.111841, 0.000000),
	},
	ambient = {
		skyLightFactor = 0.100000,
		dirLightFactor = 0.210000,
	}
}
_checkAndInstallMetatables(ambience.dawn)

ambience.noon = {
	sky = {
		skyColor = Color(0,168,255),
		horizonColor = Color(137,222,229),
		abyssColor = Color(76,144,255),
		lightColor = Color(142,180,204),
		lightIntensity = 0.600000,
	},
	fog = {
		color = Color(19,159,204),
		near = 300,
		far = 700,
		lightAbsorbtion = 0.400000,
	},
	sun = {
		color = Color(255,247,204),
		intensity = 1.000000,
		rotation = Number3(1.061161, 3.089219, 0.000000),
	},
	ambient = {
		skyLightFactor = 0.100000,
		dirLightFactor = 0.200000,
	}
}
_checkAndInstallMetatables(ambience.noon)

ambience.dusk = {
	sky = {
		skyColor = Color(159,76,255),
		horizonColor = Color(255,115,102),
		abyssColor = Color(255,167,49),
		lightColor = Color(178,107,151),
		lightIntensity = 0.600000,
	},
	fog = {
		color = Color(113,61,153),
		near = 300,
		far = 700,
		lightAbsorbtion = 0.400000,
	},
	sun = {
		color = Color(211,127,255),
		intensity = 1.000000,
		rotation = Number3(0.624827, 4.188794, 0.000000),
	},
	ambient = {
		skyLightFactor = 0.100000,
		dirLightFactor = 0.200000,
	}
}
_checkAndInstallMetatables(ambience.dusk)

ambience.midnight = {
	sky = {
		skyColor = Color(0,8,51),
		horizonColor = Color(48,22,76),
		abyssColor = Color(0,8,102),
		lightColor = Color(10,17,51),
		lightIntensity = 0.600000,
	},
	fog = {
		color = Color(31,22,76),
		near = 300,
		far = 700,
		lightAbsorbtion = 0.400000,
	},
	sun = {
		color = Color(27,7,76),
		intensity = 1.000000,
		rotation = Number3(0.816814, 4.712389, 0.000000),
	},
	ambient = {
		skyLightFactor = 0.100000,
		dirLightFactor = 0.200000,
	}
}
_checkAndInstallMetatables(ambience.midnight)

local sun = Light()
sun.CastsShadows = true
sun.On = true
sun.Type = LightType.Directional
World:AddChild(sun)
ambience.sun = sun

ambience.set = function(_, config)
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

ambience:set(ambience.noon)

return ambience