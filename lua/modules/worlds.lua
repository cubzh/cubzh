
worlds = {}

worlds.createModalContent = function(_, config)

	local itemGrid = require("item_grid")
	local worldDetails = require("world_details")
	local pages = require("pages")
	local theme = require("uitheme").current
	local modal = require("modal")

	-- default config
	local _config = {
		uikit = require("uikit"), -- allows to provide specific instance of uikit
	}

	if config then
		for k, v in pairs(_config) do
			if type(config[k]) == type(v) then _config[k] = config[k] end
		end
	end

	local ui = _config.uikit

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

	pages = pages:create(ui)
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
		if grid.refresh then grid:refresh() end
		return Number2(grid.Width, grid.Height)
	end

	exploreContent.willResignActive = function(_)
		grid:cancelRequestsAndTimers()
	end

	exploreContent.didBecomeActive = function(_)
		if grid.refresh then grid:refresh() end
	end

	grid.onOpen = function(_, cell)
		if cell.type ~= "world" then return end

		local worldDetailsContent = worldDetails:create({mode = "explore", title = cell.title, uikit = ui})
		worldDetailsContent:loadCell(cell)

		local btnLaunch = ui:createButton("Launch", {textSize = "big"})
		btnLaunch:setColor(theme.colorPositive)
		btnLaunch.onRelease = function()
			URL:Open("https://app.cu.bzh?worldID=" .. cell.id)
		end

		local btnServers = ui:createButton("Servers", {textSize = "big"})
		btnServers:setColor(theme.colorNeutral)
		btnServers.onRelease = function()
			local config = { worldID = cell.id, title = cell.title, uikit = ui }
			local list = require("server_list"):create(config)
			worldDetailsContent:push(list)
		end

		worldDetailsContent.bottomCenter = {btnServers, btnLaunch}

		worldDetailsContent.idealReducedContentSize = function(content, width, height)
			content.Width = width
			content.Height = height
			return Number2(content.Width, content.Height)
		end

		exploreContent:push(worldDetailsContent)
	end

	return exploreContent
end

return worlds
