worlds = {}

worlds.createModalContent = function(_, config)
	local itemGrid = require("item_grid")
	local worldDetails = require("world_details")
	local theme = require("uitheme").current
	local modal = require("modal")
	local conf = require("config")
	local emptyFn = function() end

	-- default config
	local defaultConfig = {
		uikit = require("uikit"), -- allows to provide specific instance of uikit
	}

	config = conf:merge(defaultConfig, config)

	local ui = config.uikit

	local exploreContent = modal:createContent()
	exploreContent.title = "Worlds"
	exploreContent.icon = "🗺"

	local grid = itemGrid:create({
		repo = nil,
		type = "worlds",
		worldsFilter = "featured",
		ignoreCategoryOnSearch = true,
		uikit = ui,
	})

	local pages = require("pages"):create(ui)
	exploreContent.bottomCenter = { pages }

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
		},
	}

	local onPaginationChange = function(page, nbPages)
		pages:setNbPages(nbPages)
		pages:setPage(page)
	end
	grid.onPaginationChange = emptyFn

	local pageDidChange = function(page)
		grid:setPage(page)
	end
	pages:setPageDidChange(emptyFn)

	exploreContent.node = grid

	exploreContent.idealReducedContentSize = function(content, width, height)
		local grid = content
		grid.Width = width
		grid.Height = height
		grid:refresh()
		return Number2(grid.Width, grid.Height)
	end

	local onOpen = function(cell)
		if cell.type ~= "world" then
			return
		end

		local worldDetailsContent = worldDetails:create({ mode = "explore", title = cell.title, uikit = ui })
		worldDetailsContent:loadCell(cell)

		local btnLaunch = ui:createButton("Launch", { textSize = "big" })
		btnLaunch:setColor(theme.colorPositive)
		btnLaunch.onRelease = function()
			URL:Open("https://app.cu.bzh?worldID=" .. cell.id)
		end

		local btnServers = ui:createButton("Servers", { textSize = "big" })
		btnServers:setColor(theme.colorNeutral)
		btnServers.onRelease = function()
			local config = { worldID = cell.id, title = cell.title, uikit = ui }
			local list = require("server_list"):create(config)
			worldDetailsContent:push(list)
		end

		worldDetailsContent.bottomCenter = { btnServers, btnLaunch }

		worldDetailsContent.idealReducedContentSize = function(content, width, height)
			content.Width = width
			content.Height = height
			return Number2(content.Width, content.Height)
		end

		exploreContent:push(worldDetailsContent)
	end
	grid.onOpen = emptyFn

	exploreContent.willResignActive = function(_)
		grid:cancelRequestsAndTimers()
		grid.onPaginationChange = emptyFn
		grid.onOpen = emptyFn
		pages:setPageDidChange(emptyFn)
	end

	exploreContent.didBecomeActive = function(_)
		grid.onPaginationChange = onPaginationChange
		pages:setPageDidChange(pageDidChange)
		grid.onOpen = onOpen
		grid:refresh()
	end

	return exploreContent
end

return worlds
