coins = {}

-- Creates modal content to present user coins.
-- (should be used to create or pushed within modal)
coins.createModalContent = function(_, config)
	local theme = require("uitheme").current
	local modal = require("modal")
	local conf = require("config")
	-- local api = require("api")

	-- default config
	local defaultConfig = {
		uikit = require("uikit"), -- allows to provide specific instance of uikit
	}

	config = conf:merge(defaultConfig, config)

	local ui = config.uikit

	local content = modal:createContent()
	content.closeButton = true
	content.title = "Notifications"
	content.icon = "❗"

	local node = ui:createFrame()
	content.node = node

	local frame = ui:createFrame(theme.buttonTextColor)
	frame:setParent(node)
	local text = ui:createText("(WORK IN PROGRESS)", Color.White)
	text:setParent(frame)

	local entries = {}

	content.idealReducedContentSize = function(_, width, height)
		width = math.min(width, 500)

		frame.Width = width
		local frameHeight = height
		if entries[1] then
			frameHeight = text.Height + entries[1].Height * 5 + theme.padding * 2
		end
		frame.Height = frameHeight
		text.pos = { theme.padding, frameHeight - theme.padding - text.Height, 0 }

		for k, entry in ipairs(entries) do
			entry.pos = Number3(theme.padding, text.pos.Y - text.Height - theme.padding - (k - 1) * entry.Height, 0)
		end

		frame.pos = { 0, theme.padding, 0 }

		return Number2(width, frameHeight)
	end

	return content
end

return coins
