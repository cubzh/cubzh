local explore_menu = {}

explore_menu.create = function(self, maxWidth, maxHeight, position, config)

	local itemGrid = require("item_grid")
	local worldDetails = require("world_details")
	local pages = require("pages")
	local theme = require("uitheme").current
	local modal = require("modal")
	local ui = require("uikit")
	local parent = ui.rootFrame

	local createExploreContent = function()
		local exploreContent = modal:createContent()
		exploreContent.title = "Explore"
		exploreContent.icon = "🗺"

		local grid = itemGrid:create({repo = "", type = "worlds", worldsFilter = "featured"})

		local pages = pages:create()
		exploreContent.bottomCenter = {pages}

		exploreContent.tabs = {
			{
				label = "🏆 Featured",
				short = "🏆",
				action = function()
					grid:setWorldsFilter("featured")
				end,
			},
			{
				label = "✨ New",
				short = "✨",
				action = function()
					grid:setWorldsFilter("recent")
				end,
			}
		}

		grid.onPaginationChange = function(page, nbPages)
			pages:setNbPages(nbPages)
			pages:setPage(page)
		end

		pages:setPageDidChange(function(page)
			grid:setPage(page)
		end)

		exploreContent.node = grid

		exploreContent.idealReducedContentSize = function(content, width, height)
			local grid = content
			grid.Width = width
			grid.Height = height 
			grid:refresh()
			return Number2(grid.Width, grid.Height)
		end

		grid.onOpen = function(self, cell)
			if cell.type ~= "world" then
				return
			end

			local worldDetailsContent = modal:createContent()
			worldDetailsContent.title = cell.title
			worldDetailsContent.icon = "🌎"

			local worldDetails = worldDetails:create({mode = "explore"})
			worldDetails:loadCell(cell)
			worldDetailsContent.node = worldDetails

			worldDetails.onClose = function(wd)
				local grid = self
				grid.needsToRefreshEntries = true
				grid:refresh()
			end

			local btnLaunch = ui:createButton("Launch", {textSize = "big"})
			btnLaunch:setColor(theme.colorPositive)
			btnLaunch.onRelease = function()
				hideUI()

				joinWorld(cell.id) -- global function exposed by engine
			end

			local btnServers = ui:createButton("Servers", {textSize = "big"})
			btnServers:setColor(theme.colorNeutral)
			btnServers.onRelease = function(b)
				local config = { worldID = cell.id, parentModal = self.parentModal, title = cell.title }
				local list = require("server_list"):create(maxWidth, maxHeight, position, config)
				self.parentModal.object.IsHidden = true
			end

			worldDetailsContent.bottomCenter = {btnServers, btnLaunch}

			worldDetailsContent.idealReducedContentSize = function(content, width, height)
				content.Width = width
				content.Height = height
				return Number2(content.Width, content.Height)
			end

			exploreContent.modal:push(worldDetailsContent)
		end

		return exploreContent
	end

	local exploreContent = createExploreContent()
	local _modal = modal:create(exploreContent, maxWidth, maxHeight, position)
	exploreContent.node.parentModal = _modal
	return _modal
end

return explore_menu
