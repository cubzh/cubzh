
local settings = {}

-- MODULES
local modal = require("modal")
local uikit = require("uikit")
local theme = require("uitheme")

-- CONSTANTS
local SENSITIVITY_STEP = 0.1
local MIN_SENSITIVITY = 0.1
local MAX_SENSITIVITY = 3.0

--- Creates a settings modal
--- positionCallback(function): position of the popup
--- config(table): contents "cache" and "logout" keys, set either of these to true to display associated buttons
--- returns: modal
settings.create = function(self, positionCallback, config)

	if type(positionCallback) ~= "function" then
		error("setting:create(positionCallback, <config>): positionCallback should be a function", 2)
	end
	if config ~= nil and type(config) ~= "table" then
		error("setting:create(positionCallback, <config>): config should be a table", 2)
	end

	-- default config
	local _config = {
		clearCache = false,
		logout = false,
	}

	if config then
		if type(config.clearCache) == "boolean" then _config.clearCache = config.clearCache end
		if type(config.logout) == "boolean" then _config.logout = config.logout end
	end

	local settingsNode = uikit:createFrame()

	local content = modal:createContent()
	content.title = "Settings"
	content.icon = "⚙️"
	content.node = settingsNode

	local rows = {}
	
	-- SENSITIVITY

	local sensitivityLabel = uikit:createText("", Color.White)
	local function refreshSensitivityLabel()
		sensitivityLabel.Text = string.format("Sensitivity: %.1f ", getSensitivity())
	end
	refreshSensitivityLabel()

	local sensitivityMinus = uikit:createButton("➖")
	sensitivityMinus.label = sensitivityLabel
	sensitivityMinus.onRelease = function(self)
		local sensitivity = math.max(getSensitivity() - SENSITIVITY_STEP, MIN_SENSITIVITY)
        setSensitivity(sensitivity)
		refreshSensitivityLabel()
	end

	local sensitivityPlus = uikit:createButton("➕")
	sensitivityPlus.label = sensitivityLabel
	sensitivityPlus.onRelease = function(self)
        local sensitivity = math.min(getSensitivity() + SENSITIVITY_STEP, MAX_SENSITIVITY)
        setSensitivity(sensitivity)
		refreshSensitivityLabel()
	end

	table.insert(rows, {sensitivityLabel, sensitivityMinus, sensitivityPlus})

	-- RENDER QUALITY

	local restartLabel = uikit:createText("⚠️ App restart required! ⚠️", Color.Yellow)
	local renderQualityRestartRow = {restartLabel}
	renderQualityRestartRow.hidden = true

	local renderQualityLabel = uikit:createText("", Color.White)
	local function refreshRenderQualityLabel()
		renderQualityLabel.Text = string.format("Render Quality: %d/%d ", requestedRenderQualityTier(), maxRenderQualityTier())

		if requestedRenderQualityTier() ~= currentRenderQualityTier() then
			renderQualityRestartRow.hidden = false
		else 
			renderQualityRestartRow.hidden = true
		end

		local modal = content:getModalIfContentIsActive()
		if modal then
			modal:refreshContent()
		end
	end
	refreshRenderQualityLabel()

	local rqMinus = uikit:createButton("➖")
	rqMinus.label = sensitivityLabel
	rqMinus.onRelease = function(self)
		local rq = math.max(requestedRenderQualityTier() - 1, 1)
        setRenderQualityTier(rq)
		refreshRenderQualityLabel()
	end

	local rqPlus = uikit:createButton("➕")
	rqPlus.label = sensitivityLabel
	rqPlus.onRelease = function(self)
        local rq = math.min(requestedRenderQualityTier() + 1, maxRenderQualityTier())
        setRenderQualityTier(rq)
		refreshRenderQualityLabel()
	end

	if areRenderQualityTiersAvailable() == false then
		rqMinus:disable()
		rqPlus:disable()
	end

	table.insert(rows, {renderQualityLabel, rqMinus, rqPlus})

	table.insert(rows, renderQualityRestartRow)

	-- HAPTIC FEEDBACK
	local hapticFeedbackToggle
	if Client.IsMobile then
		local hapticFeedbackLabel = uikit:createText("Haptic Feedback:", Color.White)

		hapticFeedbackToggle = uikit:createButton("ON")
		if isHapticFeedbackOn() then
			hapticFeedbackToggle.Text = "ON"
			hapticFeedbackToggle:setColor(theme.colorPositive)
		else
			hapticFeedbackToggle.Text = "OFF"
			hapticFeedbackToggle:setColor(theme.colorNegative)
		end

		hapticFeedbackToggle.onRelease = function(self)
			toggleHapticFeedback()

			if isHapticFeedbackOn() then
				hapticFeedbackToggle.Text = "ON"
				hapticFeedbackToggle:setColor(theme.colorPositive)
			else
				hapticFeedbackToggle.Text = "OFF"
				hapticFeedbackToggle:setColor(theme.colorNegative)
			end
		end

		table.insert(rows, {hapticFeedbackLabel, hapticFeedbackToggle})
	end

	-- FULLSCREEN
	local fullscreenToggle
	if Client.OSName == "Windows" then
		local fullscreenLabel = uikit:createText("Fullscreen:", Color.White)

		fullscreenToggle = uikit:createButton("ON")
		if isFullscreenOn() then
			fullscreenToggle.Text = "ON"
			fullscreenToggle:setColor(theme.colorPositive)
		else
			fullscreenToggle.Text = "OFF"
			fullscreenToggle:setColor(theme.colorNegative)
		end

		fullscreenToggle.onRelease = function(self)
			toggleFullscreen()

			if isFullscreenOn() then
				fullscreenToggle.Text = "ON"
				fullscreenToggle:setColor(theme.colorPositive)
			else
				fullscreenToggle.Text = "OFF"
				fullscreenToggle:setColor(theme.colorNegative)
			end
		end

		table.insert(rows, {fullscreenLabel, fullscreenToggle})
	end

	-- CACHE

	if _config.clearCache == true then
		local cacheButton = uikit:createButton("Clear cache")
		cacheButton.onRelease = function(self)
			local clearCacheContent = modal:createContent()
			clearCacheContent.title = "Settings"
			clearCacheContent.icon = "⚙️"
			
			local node = uikit:createFrame()
			clearCacheContent.node = node

			local text = uikit:createText("⚠️ Clearing all cached data from visited experiences, are you sure about this?", Color.White)
			text.pos.X = theme.padding
			text.pos.Y = theme.padding
			text:setParent(node)

			text.object.MaxWidth = 300

			clearCacheContent.idealReducedContentSize  = function(content, width, height)
				local w, h = text.Width + theme.padding * 2, text.Height + theme.padding * 2
				return Number2(w, h)
			end

			local yes = uikit:createButton("Yes, delete cache! 💀")
			yes.onRelease = function()
				clearCache()
				local done = uikit:createText("✅ Done!", Color.White)
				clearCacheContent.bottomCenter = {done}
			end
			clearCacheContent.bottomCenter = {yes}

			content:push(clearCacheContent)
		end
	    table.insert(rows, {cacheButton})
	end

	-- LOGOUT

	if _config.logout == true then
		local logoutButton = uikit:createButton("Logout")
		logoutButton:setColor(theme.colorNegative)

		logoutButton.onRelease = function(self)
			local logoutContent = modal:createContent()
			logoutContent.title = "Settings"
			logoutContent.icon = "⚙️"
			
			local node = uikit:createFrame()
			logoutContent.node = node

			local text = uikit:createText("Are you sure you want to logout now?", Color.White)
			text.pos.X = theme.padding
			text.pos.Y = theme.padding
			text:setParent(node)

			text.object.MaxWidth = 300

			logoutContent.idealReducedContentSize  = function(content, width, height)
				local w, h = text.Width + theme.padding * 2, text.Height + theme.padding * 2
				return Number2(w, h)
			end

			local yes = uikit:createButton("Yes! 🙂")
			yes.onRelease = function()
				local modal = logoutContent:getModalIfContentIsActive()
				if modal then modal:close() end
				logout()
			end
			logoutContent.bottomCenter = {yes}

			content:push(logoutContent)
		end
	    table.insert(rows, {logoutButton})
	end

	-- UI setup

	for _, row in ipairs(rows) do
		for _, element in ipairs(row) do
			element:setParent(settingsNode)
		end
	end

	local refresh = function()

		-- button only used as a min width reference for some buttons
		local btn = uikit:createButton("OFF")
		local toggleWidth = btn.Width + theme.padding * 2
		btn.Text = "➕"
		local oneEmojiWidth = btn.Width + theme.padding
		btn:remove()

		if hapticFeedbackToggle ~= nil then hapticFeedbackToggle.Width = toggleWidth end
		if fullscreenToggle ~= nil then fullscreenToggle.Width = toggleWidth end
		sensitivityMinus.Width = oneEmojiWidth
		sensitivityPlus.Width = oneEmojiWidth
		rqMinus.Width = oneEmojiWidth
		rqPlus.Width = oneEmojiWidth
		
		local totalHeight = 0
		local totalWidth = 0
		local rowHeight = 0
		local rowWidth = 0

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
		local hCursor = 0

		for i, row in ipairs(rows) do
			if not row.hidden then	
				hCursor = (totalWidth - row.width) * 0.5
				for j, element in ipairs(row) do
					element.pos.X = hCursor
					element.pos.Y = vCursor - row.height * 0.5 - element.Height * 0.5
					hCursor = hCursor + element.Width + theme.padding
				end
				vCursor = vCursor - row.height - theme.padding
			end
		end

		return totalWidth, totalHeight
	end

	local maxWidth = function()
		return Screen.Width * 0.5
	end

	local maxHeight = function()
		return Screen.Height * 0.5
	end

	content.idealReducedContentSize  = function(content, width, height)
		local w, h = refresh()
		return Number2(w, h)
	end

	local settingsModal = modal:create(content, maxWidth, maxHeight, positionCallback)

	settings.modal = settingsModal

	return settingsModal
end

return settings
