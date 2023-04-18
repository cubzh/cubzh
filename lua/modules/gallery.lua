--[[
Generic gallery serving multiple purposes:
- explore games
- explore items
- explore user creations (by category)
]]--

local gallery = {
	mode = {
		items = 1, -- browse all items
		create = 2, -- user items & worlds
		explore = 3, -- explore worlds
	}
}

gallery.create = function(self, maxWidth, maxHeight, position, config)

	local itemGrid = require("item_grid")
	local itemDetails = require("item_details")
	local pagesModule = require("pages")
	local theme = require("uitheme").current
	local modal = require("modal")
	local ui = require("uikit")
	local parent = ui.rootFrame
	local api = require("api")

	-- load config (overriding defaults)
	local _config = {
		-- can be used to display specific items
		-- if only one item in the array, displays it, not the grid
		items = nil,
		-- can be used to display specific worlds
		-- if only one world in the array, displays it, not the grid
		worlds = nil,
		-- function triggered when opening cell
		onOpen = nil,
		-- ignored when items or worlds is set
		mode = gallery.mode.items
	}
	if config ~= nil then
		-- if type(config) == "boolean" then
		-- 	-- legacy, `config` paramameter used to be `doNotFlip`
		-- 	_config.doNotFlip = config
		-- else
		-- 	if config.spherized ~= nil then _config.spherized = config.spherized end
		-- 	if config.doNotFlip ~= nil then _config.doNotFlip = config.doNotFlip end
		-- end
	end
	config = _config

	local gridContent = modal:createContent()
	gridContent.title = "Gallery"
	gridContent.icon = "🗺️"

	local grid = itemGrid:create({categories = {"null"}})
	gridContent.node = grid

	local pages = pagesModule:create()
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

	grid.onOpen = function(self, cell)
		local itemDetailsContent = modal:createContent()
		itemDetailsContent.title = "Item"
		itemDetailsContent.icon = "⚔️"

		-- local marketBtn = ui:createButton("💰 Buy")
		-- marketBtn:setColor(theme.colorPositive, theme.textColor)
		-- marketBtn.onRelease = function()
		-- 	local itemMarketContent = modal:createContent()
		-- 	itemMarketContent.title = "Market"
		-- 	itemMarketContent.icon = "✨"

		-- 	local pages = pagesModule:create()
		-- 	itemMarketContent.bottomCenter = {pages}

		-- 	local copyMarket = require("item_copy_market"):create()
		-- 	itemMarketContent.node = copyMarket

		-- 	copyMarket.onPaginationChange = function(page, nbPages)
		-- 		pages:setNbPages(nbPages)
		-- 		pages:setPage(page)
		-- 	end

		-- 	pages:setPageDidChange(function(page)
		-- 		copyMarket:setPage(page)
		-- 	end)

		-- 	itemMarketContent.idealReducedContentSize = function(content, width, height)
		-- 		copyMarket.Width = width
		-- 		copyMarket.Height = height
		-- 		return Number2(width, height)
		-- 	end

		-- 	itemDetailsContent.modal:push(itemMarketContent)
		-- 	copyMarket:setItem(cell.repo, cell.name)
		-- end

		-- itemDetailsContent.bottomCenter = {marketBtn}

		local itemDetails = itemDetails:create()
		itemDetails:loadCell(cell)
		itemDetailsContent.node = itemDetails

		itemDetailsContent.idealReducedContentSize = function(content, width, height)
			content.Width = width
			content.Height = height
			return Number2(content.Width, content.Height)
		end

		gridContent.modal:push(itemDetailsContent)
	end

	local _modal = modal:create(gridContent, maxWidth, maxHeight, position)
	return _modal
end

return gallery
