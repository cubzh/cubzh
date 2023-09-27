--[[
Generic gallery serving multiple purposes:
- explore games
- explore items
- explore user creations (by category)
]]--

local gallery = {}

gallery.createModalContent = function(self, config)
	
	local modal = require("modal")
	local itemGrid = require("item_grid")
	local itemDetails = require("item_details")
	local pagesModule = require("pages")
	
	-- load config (overriding defaults)
	local _config = {
		-- function triggered when opening cell
		onOpen = nil,
		--
		uikit = require("uikit"),
	}

	if config then
		for k, v in pairs(_config) do
			if type(config[k]) == type(v) then _config[k] = config[k] end
		end
		_config.onOpen = config.onOpen
	end

	config = _config

	local ui = config.uikit

	local gridContent = modal:createContent()
	gridContent.title = "Gallery"
	gridContent.icon = "🗺️"

	local grid = itemGrid:create({categories = {"null"}, uikit = ui})
	gridContent.node = grid

	local pages = pagesModule:create(ui)
	gridContent.bottomCenter = {pages}

	gridContent.idealReducedContentSize = function(content, width, height)
		local grid = content
		grid.Width = width
		grid.Height = height -- - content.pages.Height - theme.padding
		grid:refresh() -- affects width and height (possibly reducing it)
		return Number2(grid.Width, grid.Height)
	end

	grid.onPaginationChange = function(page, nbPages)
		pages:setNbPages(nbPages)
		pages:setPage(page)
	end

	pages:setPageDidChange(function(page)
		grid:setPage(page)
	end)

	-- called when a grid cell has been clicked
	grid.onOpen = function(self, cell)
		if config.onOpen then return _config.onOpen(self, cell) end

		local modalObj = gridContent:getModalIfContentIsActive()
		if modalObj == nil then
			return
		end

		local itemDetailsContent = itemDetails:createModalContent({uikit = ui})
		itemDetailsContent:loadCell(cell)

		itemDetailsContent.idealReducedContentSize = function(content, width, height)
			content.Width = width
			content.Height = height
			return Number2(content.Width, content.Height)
		end
		
		modalObj:push(itemDetailsContent)
	end

	return gridContent
end

gallery.create = function(self, maxWidth, maxHeight, position, config)

	local content = self:createModalContent(config)

	local modal = require("modal")

	local _modal = modal:create(content, maxWidth, maxHeight, position)
	return _modal
end

return gallery
