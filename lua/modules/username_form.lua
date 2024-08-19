mod = {}

mod.createModalContent = function(_, config)
	local modal = require("modal")
	local theme = require("uitheme")

	local defaultConfig = {
		uikit = require("uikit"),
	}

	ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config)
	end)

	if not ok then
		error("usernameForm:createModalContent(config) - config error: " .. err, 2)
	end

	local ui = config.uikit

	local node = ui:createFrame()

	local content = modal:createContent()
	content.title = "Username"
	content.icon = "🙂"
	content.node = node

	-- deleteButton:setParent(node)

	-- content.idealReducedContentSize = function(_, _, _)
	-- 	local w, h = refresh()
	-- 	return Number2(w, h)
	-- end

	return content
end

return mod
