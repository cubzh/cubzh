--- This module is just an entity_grid wrapper, to create modal or modal content.

local gallery = {}

gallery.createModalContent = function(_, config)
	local modal = require("modal")
	local itemGrid = require("item_grid")

	local grid

	local ok, err = pcall(function()
		grid = itemGrid:create(config)
	end)
	if not ok then
		error("gallery:create(config) - config error: " .. err, 2)
	end

	local ui = config.uikit

	local gridContent = modal:createContent()

	local title = "Unkown entities"
	local icon = "❌"

	if config.type == "items" then
		title = "Items"
		icon = "⚔️"
	elseif config.type == "worlds" then
		title = "Worlds"
		icon = "🌎"
	end

	gridContent.title = title
	gridContent.icon = icon
	gridContent.node = grid
	gridContent.node = grid

	-- called when a grid cell has been clicked
	grid.onOpen = function(entity)
		if config.onOpen then
			return config.onOpen(entity)
		end

		local modalObj = gridContent:getModalIfContentIsActive()
		if modalObj == nil then
			return
		end

		if config.type == "items" then
			local content = require("item_details"):createModalContent({ uikit = ui, item = entity })
			modalObj:push(content)
		elseif config.type == "worlds" then
			local content = require("world_details"):createModalContent({ uikit = ui, world = entity })
			modalObj:push(content)
		end
	end

	return gridContent
end

gallery.create = function(self, maxWidth, maxHeight, position, config)
	local content = self:createModalContent(config)
	return require("modal"):create(content, maxWidth, maxHeight, position)
end

return gallery
