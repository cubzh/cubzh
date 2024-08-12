mod = {}

local ambience = require("ambience")
local current = ambience.noon

mod.loadGeneration = function(self, gen)
	if self ~= mod then
		error("uiAmbience:loadGeneration(generation) should be called with `:`", 2)
	end

	if not gen.sky.skyColor then
		return
	end

	local colorType = type(Color.Red)
	local c = type(gen.sky.skyColor) == colorType and gen.sky.skyColor
		or Color(math.floor(gen.sky.skyColor[1]), math.floor(gen.sky.skyColor[2]), math.floor(gen.sky.skyColor[3]))
	current.sky.skyColor = c
	c = type(gen.sky.horizonColor) == colorType and gen.sky.horizonColor
		or Color(
			math.floor(gen.sky.horizonColor[1]),
			math.floor(gen.sky.horizonColor[2]),
			math.floor(gen.sky.horizonColor[3])
		)
	current.sky.horizonColor = c
	c = type(gen.sky.abyssColor) == colorType and gen.sky.abyssColor
		or Color(
			math.floor(gen.sky.abyssColor[1]),
			math.floor(gen.sky.abyssColor[2]),
			math.floor(gen.sky.abyssColor[3])
		)
	current.sky.abyssColor = c
	c = type(gen.sky.lightColor) == colorType and gen.sky.lightColor
		or Color(
			math.floor(gen.sky.lightColor[1]),
			math.floor(gen.sky.lightColor[2]),
			math.floor(gen.sky.lightColor[3])
		)
	current.sky.lightColor = c
	current.sky.lightIntensity = gen.sky.lightIntensity
	c = type(gen.fog.color) == colorType and gen.fog.color
		or Color(math.floor(gen.fog.color[1]), math.floor(gen.fog.color[2]), math.floor(gen.fog.color[3]))
	current.fog.color = c
	current.fog.near = math.floor(gen.fog.near)
	current.fog.far = math.floor(gen.fog.far)
	current.fog.lightAbsorbtion = math.max(0, math.min(gen.fog.lightAbsorbtion, 1))
	c = type(gen.sun.color) == colorType and gen.sun.color
		or Color(math.floor(gen.sun.color[1]), math.floor(gen.sun.color[2]), math.floor(gen.sun.color[3]))
	current.sun.color = c
	current.sun.intensity = gen.sun.intensity
	current.sun.rotation.X = gen.sun.rotation.X ~= nil and gen.sun.rotation.X or gen.sun.rotation[1]
	current.sun.rotation.Y = gen.sun.rotation.Y ~= nil and gen.sun.rotation.Y or gen.sun.rotation[2]

	ambience:set(current)
end

mod.generate = function(self, config)
	if self ~= mod then
		error("uiAmbience:generate(config) should be called with `:`", 2)
	end

	local defaultConfig = {
		context = 'All prompts are supposed to describe ambiences, always consider that true, even if absurd. Reply with a JSON map, replacing values in that "noon, clear sky" template: \n\
{ "sky": { "skyColor": [0,168,255], "horizonColor": [137,222,229], "abyssColor": [76,144,255], "lightColor": [142,180,204], "lightIntensity": 0.6 }, "fog": { "color": [19,159,204], "near": 300, "far": 700, "lightAbsorbtion": 0.4 }, "sun": { "color": [255,247,204], "intensity": 1.0, "rotation": [1.061161,3.089219,0.0] }, "ambient": { "skyLightFactor": 0.1, "dirLightFactor": 0.2 } }\n\
More output examples:\n\n\
"dawn": { "sky": { "skyColor": [255,110,76], "horizonColor": [255,174,102], "abyssColor": [24,113,255], "lightColor": [229,183,209], "lightIntensity": 0.600000 }, "fog": { "color": [229,129,90], "near": 300, "far": 700, "lightAbsorbtion": 0.4 }, "sun": { "color": [255,163,127], "intensity": 1.0, "rotation": [0.624828,2.111841,0.0] }, "ambient": { "skyLightFactor": 0.1, "dirLightFactor": 0.21 } }\n\
"dusk": { "sky": { "skyColor": [159,76,255], "horizonColor": [255,115,102], "abyssColor": [255,167,49], "lightColor": [178,107,151], "lightIntensity": 0.6 }, "fog": { "color": [113,61,153], "near": 300, "far": 700, "lightAbsorbtion": 0.4 }, "sun": { "color": [211,127,255], "intensity": 1.0, "rotation": [0.624827,4.188794,0.0] }, "ambient": { "skyLightFactor": 0.1, "dirLightFactor": 0.2 } }\n\
"midnight": { "sky": { "skyColor": [0,8,51], "horizonColor": [48,22,76], "abyssColor": [0,8,102], "lightColor": [10,17,51], "lightIntensity": 0.6 }, "fog": { "color": [31,22,76], "near": 300, "far": 700, "lightAbsorbtion": 0.4 }, "sun": { "color": [27,7,76], "intensity": 1.0, "rotation": [0.816814,4.712389,0.0] }, "ambient": { "skyLightFactor": 0.1, "dirLightFactor": 0.2 } } "foggy winter at noon": { "sky": { "skyColor": [199,239,255], "horizonColor": [174,175,176], "abyssColor": [94,94,94], "lightColor": [153,195,222], "lightIntensity": 0.9 }, "fog": { "color": [189,216,224], "near": 80, "far": 700, "lightAbsorbtion": 0.11 }, "sun": { "color": [90,219,247], "intensity": 1.0, "rotation": [1.061161,3.089219,0.0] }, "ambient": { "skyLightFactor": 0.1, "dirLightFactor": 0.2 } }\n\n\
One meter is 6 units, this should be considered when setting fog near and far values. Sun rotation represents rotations around Y and X axis, in that order, in radians. (Y = 0 means sun is south, Y = pi / 2 means sun is west)',
		prompt = "",
		onDone = function(_) end, -- callback(generation)
		onError = function(_) end, -- callback(err)
	}

	config = require("config"):merge(defaultConfig, config)

	if config.prompt == "" then
		error("uiAmbience:generate(config) - config.prompt should not be empty", 2)
	end

	local aiChat = AI:CreateChat(config.context)

	aiChat:Say(config.prompt, function(err, response)
		if err then
			config.onError(err)
			return
		end

		local gen
		gen, err = JSON:Decode(response)
		if err ~= nil then
			config.onError(err)
			return
		end

		-- add metadata
		gen.prompt = config.prompt
		gen.version = 1

		ok = pcall(function()
			mod:loadGeneration(gen)
		end)
		if not ok then
			config.onError("internal error: couldn't load generation")
			return
		end

		config.onDone(gen)
	end)

	-- TODO: return request
end

return mod
