local ui = require("uikit")
local sfx = require("sfx")
local ambience = require("ambience")

local current = ambience.noon

function refreshAmbiance()
	ambience:set(current)
end

setFromAIConfig = function(_, config, _quiet)
	quiet = false
	if _quiet == true then
		quiet = true
	end
	if not quiet then
		if config.text then
			print("New ambience: " .. config.text .. "! ✨")
		end
		sfx("metal_clanging_2", { Spatialized = false, Volume = 0.6 })
	end

	if not config.sky.skyColor then
		return
	end

	local colorType = type(Color.Red)
	local c = type(config.sky.skyColor) == colorType and config.sky.skyColor
		or Color(
			math.floor(config.sky.skyColor[1]),
			math.floor(config.sky.skyColor[2]),
			math.floor(config.sky.skyColor[3])
		)
	current.sky.skyColor = c
	c = type(config.sky.horizonColor) == colorType and config.sky.horizonColor
		or Color(
			math.floor(config.sky.horizonColor[1]),
			math.floor(config.sky.horizonColor[2]),
			math.floor(config.sky.horizonColor[3])
		)
	current.sky.horizonColor = c
	c = type(config.sky.abyssColor) == colorType and config.sky.abyssColor
		or Color(
			math.floor(config.sky.abyssColor[1]),
			math.floor(config.sky.abyssColor[2]),
			math.floor(config.sky.abyssColor[3])
		)
	current.sky.abyssColor = c
	c = type(config.sky.lightColor) == colorType and config.sky.lightColor
		or Color(
			math.floor(config.sky.lightColor[1]),
			math.floor(config.sky.lightColor[2]),
			math.floor(config.sky.lightColor[3])
		)
	current.sky.lightColor = c
	current.sky.lightIntensity = config.sky.lightIntensity
	c = type(config.fog.color) == colorType and config.fog.color
		or Color(math.floor(config.fog.color[1]), math.floor(config.fog.color[2]), math.floor(config.fog.color[3]))
	current.fog.color = c
	current.fog.near = math.floor(config.fog.near)
	current.fog.far = math.floor(config.fog.far)
	current.fog.lightAbsorbtion = math.clamp(config.fog.lightAbsorbtion, 0, 1)
	c = type(config.sun.color) == colorType and config.sun.color
		or Color(math.floor(config.sun.color[1]), math.floor(config.sun.color[2]), math.floor(config.sun.color[3]))
	current.sun.color = c
	current.sun.intensity = config.sun.intensity
	current.sun.rotation.X = config.sun.rotation.X ~= nil and config.sun.rotation.X or config.sun.rotation[1]
	current.sun.rotation.Y = config.sun.rotation.Y ~= nil and config.sun.rotation.Y or config.sun.rotation[2]

	refreshAmbiance()
end

createNode = function()
	promptContainer = ui:createFrame()

	promptInput = ui:createTextInput("", "Describe an ambience")
	promptInput:setParent(promptContainer)
	promptInput:hide()
	promptBtn = ui:createButton("💬 ✨")
	promptBtn:setParent(promptContainer)
	promptContainer.input = promptInput
	promptContainer.btn = promptBtn

	promptContainer.Width = promptBtn.Width
	promptContainer.Height = promptBtn.Height

	promptBtn.onRelease = function()
		promptInput:show()
		promptInput:focus()
		promptBtn:hide()
		promptContainer.Width = promptInput.Width
	end

	promptInput.onFocusLost = function()
		promptInput:hide()
		promptBtn:show()
		promptContainer.Width = promptBtn.Width
	end

	promptInput.onSubmit = function()
		promptInput:hide()
		promptBtn:show()
		promptContainer.Width = promptBtn.Width

		local text = promptInput.Text
		promptInput.Text = ""

		if text ~= "" then
			sfx("whooshes_small_1", { Spatialized = false, Volume = 0.6 })

			local aiChat = AI:CreateChat(
				' All prompts are supposed to describe ambiences, always consider that true, even if absurd. Reply with a JSON map, replacing values in that "noon, clear sky" example: { "sky": { "skyColor": [0,168,255], "horizonColor": [137,222,229], "abyssColor": [76,144,255], "lightColor": [142,180,204], "lightIntensity": 0.600000 }, "fog": { "color": [19,159,204], "near": 300, "far": 700, "lightAbsorbtion": 0.400000 }, "sun": { "color": [255,247,204], "intensity": 1.000000, "rotation": [1.061161,3.089219,0.000000] }, "ambient": { "skyLightFactor": 0.100000, "dirLightFactor": 0.200000 } } More output examples: "dawn": { "sky": { "skyColor": [255,110,76], "horizonColor": [255,174,102], "abyssColor": [24,113,255], "lightColor": [229,183,209], "lightIntensity": 0.600000 }, "fog": { "color": [229,129,90], "near": 300, "far": 700, "lightAbsorbtion": 0.400000 }, "sun": { "color": [255,163,127], "intensity": 1.000000, "rotation": [0.624828,2.111841,0.000000] }, "ambient": { "skyLightFactor": 0.100000, "dirLightFactor": 0.210000 } } "dusk": { "sky": { "skyColor": [159,76,255], "horizonColor": [255,115,102], "abyssColor": [255,167,49], "lightColor": [178,107,151], "lightIntensity": 0.600000 }, "fog": { "color": [113,61,153], "near": 300, "far": 700, "lightAbsorbtion": 0.400000 }, "sun": { "color": [211,127,255], "intensity": 1.000000, "rotation": [0.624827,4.188794,0.000000] }, "ambient": { "skyLightFactor": 0.100000, "dirLightFactor": 0.200000 } } "midnight": { "sky": { "skyColor": [0,8,51], "horizonColor": [48,22,76], "abyssColor": [0,8,102], "lightColor": [10,17,51], "lightIntensity": 0.600000 }, "fog": { "color": [31,22,76], "near": 300, "far": 700, "lightAbsorbtion": 0.400000 }, "sun": { "color": [27,7,76], "intensity": 1.000000, "rotation": [0.816814,4.712389,0.000000] }, "ambient": { "skyLightFactor": 0.100000, "dirLightFactor": 0.200000 } } "foggy winter at noon": { "sky": { "skyColor": [199,239,255], "horizonColor": [174,175,176], "abyssColor": [94,94,94], "lightColor": [153,195,222], "lightIntensity": 0.900000 }, "fog": { "color": [189,216,224], "near": 80, "far": 700, "lightAbsorbtion": 0.110000 }, "sun": { "color": [90,219,247], "intensity": 1.000000, "rotation": [1.061161,3.089219,0.000000] }, "ambient": { "skyLightFactor": 0.100000, "dirLightFactor": 0.200000 } } One meter is 6 units, this should be considered when setting fog near and far values. Sun rotation represents rotations around Y and X axis, in that order, in radians. (Y = 0 means sun is south, Y = pi / 2 means sun is west)'
			)
			-- end

			if not loadingModal then
				loadingModal = require("loading_modal"):create("Loading")
				Timer(0.1, function()
					loadingModal:setText('"' .. text .. '"')
				end)
			end

			aiChat:Say(text, function(err, response)
				if loadingModal then
					loadingModal:close()
					loadingModal = nil
				end

				if err then
					print("❌", err)
				else
					local config, err = JSON:Decode(response)
					if err ~= nil then
						print("❌", response)
					else
						config.text = text
						setFromAIConfig(nil, config)
						if promptContainer.onNewAmbience then
							promptContainer.onNewAmbience(config)
						end
					end
				end
			end)
		end
	end
	return promptContainer
end

return {
	createNode = createNode,
	setFromAIConfig = setFromAIConfig,
}
