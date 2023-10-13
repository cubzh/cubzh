settings = {}

--- Creates modal content for app settings
--- config(table): contents "cache" and "logout" keys, set either of these to true to display associated buttons
--- returns: modal
settings.createModalContent = function(_, config)
	-- MODULES
	local modal = require("modal")
	local theme = require("uitheme")

	-- CONSTANTS
	local SENSITIVITY_STEP = 0.1
	local MIN_SENSITIVITY = 0.1
	local MAX_SENSITIVITY = 3.0
	local VOLUME_STEP = 0.05
	local MIN_VOLUME = 0.0
	local MAX_VOLUME = 1.0

	if config ~= nil and type(config) ~= "table" then
		error("setting:create(<config>): config should be a table", 2)
	end

	-- default config
	local _config = {
		clearCache = false,
		logout = false,
		uikit = require("uikit"),
	}

	if config then
		for k, v in pairs(_config) do
			if type(config[k]) == type(v) then
				_config[k] = config[k]
			end
		end
	end

	config = _config

	local ui = config.uikit

	local settingsNode = ui:createFrame()

	local content = modal:createContent()
	content.title = "Settings"
	content.icon = "⚙️"
	content.node = settingsNode

	local rows = {}

	-- VOLUME

	local volumeLabel = ui:createText("", Color.White)
	local function refreshVolumeLabel()
		volumeLabel.Text = string.format("Volume: %.2f ", System.MasterVolume)
	end
	refreshVolumeLabel()

	local volumeMinus = ui:createButton("➖")
	volumeMinus.label = volumeLabel
	volumeMinus.onRelease = function(_)
		System.MasterVolume = math.max(System.MasterVolume - VOLUME_STEP, MIN_VOLUME)
		refreshVolumeLabel()
	end

	local volumePlus = ui:createButton("➕")
	volumePlus.label = volumeLabel
	volumePlus.onRelease = function(_)
		System.MasterVolume = math.min(System.MasterVolume + VOLUME_STEP, MAX_VOLUME)
		refreshVolumeLabel()
	end

	table.insert(rows, { volumeLabel, volumeMinus, volumePlus })

	-- SENSITIVITY

	local sensitivityLabel = ui:createText("", Color.White)
	local function refreshSensitivityLabel()
		sensitivityLabel.Text = string.format("Sensitivity: %.1f ", System.Sensitivity)
	end
	refreshSensitivityLabel()

	local sensitivityMinus = ui:createButton("➖")
	sensitivityMinus.label = sensitivityLabel
	sensitivityMinus.onRelease = function(_)
		System.Sensitivity = math.max(System.Sensitivity - SENSITIVITY_STEP, MIN_SENSITIVITY)
		refreshSensitivityLabel()
	end

	local sensitivityPlus = ui:createButton("➕")
	sensitivityPlus.label = sensitivityLabel
	sensitivityPlus.onRelease = function(_)
		System.Sensitivity = math.min(System.Sensitivity + SENSITIVITY_STEP, MAX_SENSITIVITY)
		refreshSensitivityLabel()
	end

	table.insert(rows, { sensitivityLabel, sensitivityMinus, sensitivityPlus })

	-- ZOOM SENSITIVITY

	local zoomSensitivityLabel = ui:createText("", Color.White)
	local function refreshZoomSensitivityLabel()
		zoomSensitivityLabel.Text = string.format("Zoom sensitivity: %.1f ", System.ZoomSensitivity)
	end
	refreshZoomSensitivityLabel()

	local zoomSensitivityMinus = ui:createButton("➖")
	zoomSensitivityMinus.label = zoomSensitivityLabel
	zoomSensitivityMinus.onRelease = function(_)
		System.ZoomSensitivity = math.max(System.ZoomSensitivity - SENSITIVITY_STEP, MIN_SENSITIVITY)
		refreshZoomSensitivityLabel()
	end

	local zoomSensitivityPlus = ui:createButton("➕")
	zoomSensitivityPlus.label = zoomSensitivityLabel
	zoomSensitivityPlus.onRelease = function(_)
		System.ZoomSensitivity = math.min(System.ZoomSensitivity + SENSITIVITY_STEP, MAX_SENSITIVITY)
		refreshZoomSensitivityLabel()
	end

	table.insert(rows, { zoomSensitivityLabel, zoomSensitivityMinus, zoomSensitivityPlus })

	-- RENDER QUALITY

	local renderQualityLabel = ui:createText("", Color.White)
	local function refreshRenderQualityLabel()
		renderQualityLabel.Text =
			string.format("Render Quality: %d/%d ", System.RenderQualityTier, System.MaxRenderQualityTier)

		local modal = content:getModalIfContentIsActive()
		if modal then
			modal:refreshContent()
		end
	end
	refreshRenderQualityLabel()

	local rqMinus = ui:createButton("➖")
	rqMinus.label = sensitivityLabel
	rqMinus.onRelease = function(_)
		System.RenderQualityTier = math.max(System.RenderQualityTier - 1, System.MinRenderQualityTier)
		refreshRenderQualityLabel()
	end

	local rqPlus = ui:createButton("➕")
	rqPlus.label = sensitivityLabel
	rqPlus.onRelease = function(_)
		System.RenderQualityTier = math.min(System.RenderQualityTier + 1, System.MaxRenderQualityTier)
		refreshRenderQualityLabel()
	end

	if System.RenderQualityTiersAvailable == false then
		rqMinus:disable()
		rqPlus:disable()
	end

	table.insert(rows, { renderQualityLabel, rqMinus, rqPlus })

	-- HAPTIC FEEDBACK
	local hapticFeedbackToggle
	if Client.IsMobile then
		local hapticFeedbackLabel = ui:createText("Haptic Feedback:", Color.White)

		hapticFeedbackToggle = ui:createButton("ON")
		if System.HapticFeedbackEnabled then
			hapticFeedbackToggle.Text = "ON"
			hapticFeedbackToggle:setColor(theme.colorPositive)
		else
			hapticFeedbackToggle.Text = "OFF"
			hapticFeedbackToggle:setColor(theme.colorNegative)
		end

		hapticFeedbackToggle.onRelease = function(_)
			System.HapticFeedbackEnabled = not System.HapticFeedbackEnabled

			if System.HapticFeedbackEnabled then
				hapticFeedbackToggle.Text = "ON"
				hapticFeedbackToggle:setColor(theme.colorPositive)
			else
				hapticFeedbackToggle.Text = "OFF"
				hapticFeedbackToggle:setColor(theme.colorNegative)
			end
		end

		table.insert(rows, { hapticFeedbackLabel, hapticFeedbackToggle })
	end

	-- FULLSCREEN
	local fullscreenToggle
	if Client.OSName == "Windows" then
		local fullscreenLabel = ui:createText("Fullscreen:", Color.White)

		fullscreenToggle = ui:createButton("ON")
		if System.Fullscreen then
			fullscreenToggle.Text = "ON"
			fullscreenToggle:setColor(theme.colorPositive)
		else
			fullscreenToggle.Text = "OFF"
			fullscreenToggle:setColor(theme.colorNegative)
		end

		fullscreenToggle.onRelease = function(_)
			System.Fullscreen = not System.Fullscreen

			if System.Fullscreen then
				fullscreenToggle.Text = "ON"
				fullscreenToggle:setColor(theme.colorPositive)
			else
				fullscreenToggle.Text = "OFF"
				fullscreenToggle:setColor(theme.colorNegative)
			end
		end

		table.insert(rows, { fullscreenLabel, fullscreenToggle })
	end

	-- CACHE

	cacheAndLogoutRow = {}

	if _config.clearCache == true then
		local cacheButton = ui:createButton("Clear cache", { textSize = "small" })
		cacheButton.onRelease = function(_)
			local clearCacheContent = modal:createContent()
			clearCacheContent.title = "Settings"
			clearCacheContent.icon = "⚙️"

			local node = ui:createFrame()
			clearCacheContent.node = node

			local text = ui:createText(
				"⚠️ Clearing all cached data from visited experiences, are you sure about this?",
				Color.White
			)
			text.pos.X = theme.padding
			text.pos.Y = theme.padding
			text:setParent(node)

			text.object.MaxWidth = 300

			clearCacheContent.idealReducedContentSize = function(_, _, _)
				local w, h = text.Width + theme.padding * 2, text.Height + theme.padding * 2
				return Number2(w, h)
			end

			local yes = ui:createButton("Yes, delete cache! 💀")
			yes.onRelease = function()
				System.ClearCache()
				local done = ui:createText("✅ Done!", Color.White)
				clearCacheContent.bottomCenter = { done }
			end
			clearCacheContent.bottomCenter = { yes }

			content:push(clearCacheContent)
		end
		table.insert(cacheAndLogoutRow, cacheButton)
	end

	-- LOGOUT

	if _config.logout == true then
		local logoutButton = ui:createButton("Logout", { textSize = "small" })
		logoutButton:setColor(theme.colorNegative)

		logoutButton.onRelease = function(_)
			local logoutContent = modal:createContent()
			logoutContent.title = "Settings"
			logoutContent.icon = "⚙️"

			local node = ui:createFrame()
			logoutContent.node = node

			local text = ui:createText("Are you sure you want to logout now?", Color.White)
			text.pos.X = theme.padding
			text.pos.Y = theme.padding
			text:setParent(node)

			text.object.MaxWidth = 300

			logoutContent.idealReducedContentSize = function(_, _, _)
				local w, h = text.Width + theme.padding * 2, text.Height + theme.padding * 2
				return Number2(w, h)
			end

			local yes = ui:createButton("Yes! 🙂")
			yes.onRelease = function()
				local modal = logoutContent:getModalIfContentIsActive()
				if modal then
					modal:close()
				end
				System:LogoutAndExit()
			end
			logoutContent.bottomCenter = { yes }

			content:push(logoutContent)
		end
		table.insert(cacheAndLogoutRow, logoutButton)
	end

	if #cacheAndLogoutRow > 0 then
		table.insert(rows, cacheAndLogoutRow)
	end

	-- UI setup

	for _, row in ipairs(rows) do
		for _, element in ipairs(row) do
			element:setParent(settingsNode)
		end
	end

	local refresh = function()
		-- button only used as a min width reference for some buttons
		local btn = ui:createButton("OFF")
		local toggleWidth = btn.Width + theme.padding * 2
		btn.Text = "➕"
		local oneEmojiWidth = btn.Width + theme.padding
		btn:remove()

		if hapticFeedbackToggle ~= nil then
			hapticFeedbackToggle.Width = toggleWidth
		end
		if fullscreenToggle ~= nil then
			fullscreenToggle.Width = toggleWidth
		end
		sensitivityMinus.Width = oneEmojiWidth
		sensitivityPlus.Width = oneEmojiWidth
		zoomSensitivityMinus.Width = oneEmojiWidth
		zoomSensitivityPlus.Width = oneEmojiWidth
		rqMinus.Width = oneEmojiWidth
		rqPlus.Width = oneEmojiWidth

		local totalHeight = 0
		local totalWidth = 0
		local rowHeight
		local rowWidth

		for i, row in ipairs(rows) do
			if row.hidden == true then
				for _, element in ipairs(row) do
					element:hide()
				end
			else
				rowHeight = 0
				rowWidth = 0

				for j, element in ipairs(row) do
					element:show()
					rowHeight = math.max(rowHeight, element.Height)
					rowWidth = rowWidth + element.Width + (j > 1 and theme.padding or 0)
				end

				totalHeight = totalHeight + rowHeight + (i > 1 and theme.padding or 0)
				totalWidth = math.max(totalWidth, rowWidth)

				row.height = rowHeight
				row.width = rowWidth
			end
		end

		totalWidth = totalWidth + theme.padding * 2
		totalHeight = totalHeight + theme.padding * 2

		local vCursor = totalHeight - theme.padding
		local hCursor

		for _, row in ipairs(rows) do
			if not row.hidden then
				hCursor = (totalWidth - row.width) * 0.5
				for _, element in ipairs(row) do
					element.pos.X = hCursor
					element.pos.Y = vCursor - row.height * 0.5 - element.Height * 0.5
					hCursor = hCursor + element.Width + theme.padding
				end
				vCursor = vCursor - row.height - theme.padding
			end
		end

		return totalWidth, totalHeight
	end

	content.idealReducedContentSize = function(_, _, _)
		local w, h = refresh()
		return Number2(w, h)
	end

	return content
end

return settings
