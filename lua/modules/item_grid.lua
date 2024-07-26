--- This module creates a uikit node that displayes a grid of items.

local itemGrid = {}

-- MODULES
local api = require("api")
local theme = require("uitheme").current

-- CONSTANTS
local MIN_CELL_SIZE = 140
local MAX_CELL_SIZE = 200
local MIN_CELLS_PER_ROW = 3 -- prority over MIN_CELL_SIZE

itemGrid.create = function(_, config)
	-- load config (overriding defaults)
	local defaultConfig = {
		-- shows search bar when true
		searchBar = true,
		--
		search = "",
		-- shows advanced filters button when true
		advancedFilters = false,
		-- used to filter categories when not nil
		categories = nil, -- {"null", hair" ,"jacket", "pants", "boots"},
		-- filter on particular repo
		repo = nil,
		-- mode
		minBlocks = 5,
		--
		ignoreCategoryOnSearch = false,
		--
		uikit = require("uikit"),
		--
		backgroundColor = theme.buttonTextColor,
		--
		sort = "likes:desc",
		--
		cellPadding = theme.cellPadding,
		--
		scrollPadding = theme.scrollPadding,
		--
		padding = 0,
		--
		displayPrice = false,
		--
		displayLikes = false,
		--
		onOpen = function(_) end,
		--
		filterDidChange = function(_, _) end, -- (search, sort)
	}

	local ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config, {
			acceptTypes = {
				repo = { "string" },
				categories = { "table" },
				sort = { "string" },
			},
		})
	end)
	if not ok then
		error("item_grid:create(config) - config error: " .. err, 2)
	end

	local ui = config.uikit
	local sortBy = config.sort

	local grid = ui:createFrame(Color(40, 40, 40)) -- Color(255,0,0)

	grid.onOpen = config.onOpen

	local search = config.search

	local timers = {}
	local sentRequests = {}
	local function addSentRequest(req)
		table.insert(sentRequests, req)
	end
	local function cancelSentRequest()
		for _, r in pairs(sentRequests) do
			r:Cancel()
		end
		sentRequests = {}
	end

	local function cancelTimers()
		for _, t in pairs(timers) do
			t:Cancel()
		end
		timers = {}
		if grid.searchTimer ~= nil then
			grid.searchTimer:Cancel()
		end
	end

	local function cancelRequestsAndTimers()
		cancelSentRequest()
		cancelTimers()
	end

	-- exposed to the outside, can be called as an optimization
	-- when hiding the grid without removing it for example.
	grid.cancelRequestsAndTimers = function()
		cancelRequestsAndTimers()
	end

	grid.setCategories = function(self, categories)
		config.categories = categories
		cancelRequestsAndTimers()
		self:getItems()
	end

	local searchBar
	local sortBtn
	local scroll

	local function layoutSearchBar()
		if searchBar ~= nil then
			local parent = searchBar.parent
			if parent == nil then
				return
			end
			searchBar.pos = { 0, parent.Height - searchBar.Height }
			if sortBtn ~= nil then
				searchBar.Width = parent.Width - sortBtn.Width - theme.padding
				sortBtn.Height = searchBar.Height
				sortBtn.pos = searchBar.pos + { searchBar.Width + theme.padding, 0 }
			else
				searchBar.Width = parent.Width
			end
		end
	end

	if config.searchBar then
		searchBar = ui:createTextInput(search, "search", { textSize = "small" })
		searchBar:setParent(grid)

		local s = "♥️ Likes"
		if sortBy == "updatedAt:desc" then
			s = "✨ Recent"
		end

		sortBtn = ui:buttonNeutral({ content = s, textSize = "small", textColor = Color.Black })
		sortBtn:setParent(grid)
		sortBtn.onRelease = function()
			if sortBy == "likes:desc" then
				sortBtn.Text = "✨ Recent"
				sortBy = "updatedAt:desc"
			elseif sortBy == "updatedAt:desc" then
				sortBtn.Text = "♥️ Likes"
				sortBy = "likes:desc"
			end
			config.filterDidChange(search, sortBy)
			layoutSearchBar()
			grid:getItems()
		end

		searchBar.onTextChange = function(_)
			if grid.searchTimer ~= nil then
				grid.searchTimer:Cancel()
			end

			grid.searchTimer = Timer(0.3, function()
				local text = searchBar.Text
				text = text:gsub(" ", "+")

				search = text
				config.filterDidChange(search, sortBy)
				grid:getItems()
			end)
		end
	end

	local entries = {}
	local nbEntries = 0
	local entriesPerRow = 0
	local rows = 0
	local cellSize = MIN_CELL_SIZE

	local rowPool = {}
	local cellPool = {}
	local activeCells = {}

	local function improveNameFormat(str)
		local s = string.gsub(str, "_%a", string.upper)
		s = string.gsub(s, "_", " ")
		s = string.gsub(s, "^%l", string.upper)
		return s
	end

	local cellSelector = ui:frameScrollCellSelector()
	cellSelector:setParent(nil)

	scroll = ui:createScroll({
		direction = "down",
		backgroundColor = config.backgroundColor or Color(0, 0, 0, 0),
		cellPadding = config.cellPadding,
		padding = config.scrollPadding,
		loadCell = function(index)
			if index <= rows then
				local row = table.remove(rowPool)
				if row == nil then
					row = ui:createFrame(Color(0, 0, 0, 0))
					row.cells = {}
				end
				row.Width = scroll.Width - config.padding * 2
				row.Height = cellSize

				for i = 1, entriesPerRow do
					local entryIndex = (index - 1) * entriesPerRow + i
					if entryIndex > nbEntries then
						break
					end

					local cell = table.remove(cellPool)
					if cell == nil then
						cell = ui:frameScrollCell()

						cell.onPress = function()
							cellSelector:setParent(cell)
							cellSelector.Width = cell.Width
							cellSelector.Height = cell.Height
						end

						cell.onRelease = function()
							if grid.onOpen then
								local entity = {
									type = "item",
									id = cell.id,
									repo = cell.repo,
									name = cell.name,
									likes = cell.likes,
									liked = cell.liked,
									category = cell.category,
								}
								grid:onOpen(entity)
							else
								cellSelector:setParent(nil)
							end
						end

						cell.onCancel = function()
							cellSelector:setParent(nil)
						end

						local titleFrame = ui:frameTextBackground()
						titleFrame:setParent(cell)
						titleFrame.pos = { theme.paddingTiny, theme.paddingTiny }
						titleFrame.LocalPosition.Z = config.uikit.kForegroundDepth

						local title = ui:createText("…", Color.White, "small")
						title:setParent(titleFrame)

						title.pos = { theme.paddingTiny, theme.paddingTiny }

						cell.titleFrame = titleFrame
						cell.title = title

						if config.displayLikes then
							local likesFrame = ui:frame({ color = Color(0, 0, 0, 0) })
							likesFrame:setParent(cell)
							likesFrame.LocalPosition.Z = config.uikit.kForegroundDepth

							local likes = ui:createText("❤️ …", Color.White, "small")
							likes:setParent(likesFrame)

							likes.pos = { theme.padding, theme.padding }

							cell.likesFrame = likesFrame
							cell.likesLabel = likes
						end

						if config.displayPrice then
							local priceFrame = ui:frame({ color = Color(0, 0, 0, 0) })
							priceFrame:setParent(cell)
							priceFrame.LocalPosition.Z = config.uikit.kForegroundDepth

							local price = ui:createText("❤️ …", Color.White, "small")
							price:setParent(priceFrame)

							price.pos = { theme.padding, theme.padding }

							cell.priceFrame = priceFrame
							cell.priceLabel = price
						end

						cell.requests = {}
						cell.item = nil

						cell.loadEntry = function(self, entry)
							self.id = entry.id
							self.repo = entry.repo
							self.name = entry.name
							self.fullName = self.repo .. "." .. self.name
							self.category = entry.category
							self.description = entry.description
							self.created = entry.created
							self.updated = entry.updated
							self.likes = entry.likes
							self.liked = entry.liked

							if self.item then
								self.item:remove()
								self.item = nil
							end

							self.title.object.MaxWidth = self.Width - theme.paddingTiny * 4
							self.title.Text = improveNameFormat(entry.name)
							self.titleFrame.Height = self.title.Height + theme.paddingTiny * 2
							self.titleFrame.Width = self.title.Width + theme.paddingTiny * 2

							if self.likesFrame ~= nil then
								self.likesLabel.object.MaxWidth = self.Width - theme.padding * 2
								self.likesLabel.Text = "❤️ " .. self.likes
								self.likesFrame.Height = self.likesLabel.Height + theme.padding * 2
								self.likesFrame.Width = self.likesLabel.Width + theme.padding * 2
								self.likesFrame.pos = {
									self.Width - self.likesFrame.Width,
									self.Height - self.likesFrame.Height,
								}
							end

							if self.priceFrame ~= nil then
								self.priceLabel.object.MaxWidth = self.Width - theme.padding * 2
								self.priceLabel.Text = "🇵 0" -- 🪙
								self.priceFrame.Height = self.priceLabel.Height + theme.padding * 2
								self.priceFrame.Width = self.priceLabel.Width + theme.padding * 2
								self.priceFrame.pos = { 0, self.Height - self.likesFrame.Height }
							end

							local req = Object:Load(self.fullName, function(obj)
								if obj == nil then
									-- silent error, no print, just removing loading animation
									-- local loadingCube = cell:getLoadingCube()
									-- if loadingCube then
									-- 	loadingCube:hide()
									-- end
									return
								end

								-- local loadingCube = cell:getLoadingCube()
								-- if loadingCube then
								-- 	loadingCube:hide()
								-- end

								local item = ui:createShape(obj, { spherized = true })
								cell.item = item
								item:setParent(cell) -- possible error here, cell destroyed?

								item.pivot.LocalRotation = { -0.1, 0, -0.2 }

								-- setting Width sets Height & Depth as well when spherized
								item.Width = cell.Width
							end)

							table.insert(self.requests, req)
						end
					end

					cell.type = "item"

					table.insert(row.cells, cell)

					cell:setParent(row)
					cell.entryIndex = entryIndex
					cell.Width = cellSize
					cell.Height = cellSize
					cell.pos = { (i - 1) * (cellSize + config.cellPadding), 0 }
					cell:loadEntry(entries[entryIndex])
					activeCells[entryIndex] = cell
				end

				return row
			end
			return nil
		end,
		unloadCell = function(_, row)
			for _, cell in ipairs(row.cells) do
				for _, req in ipairs(cell.requests) do
					req:Cancel()
				end
				if cell.item then
					cell.item:remove()
					cell.item = nil
				end
				cell:setParent(nil)
				cell.requests = {}
				activeCells[cell.entryIndex] = nil
				table.insert(cellPool, cell)
			end
			row.cells = {}
			row:setParent(nil)
			table.insert(rowPool, row)
		end,
	})

	local function refreshEntries()
		nbEntries = #entries
		local w = scroll.Width - config.scrollPadding * 2 + config.cellPadding
		entriesPerRow = math.floor(w / MIN_CELL_SIZE)
		entriesPerRow = math.max(MIN_CELLS_PER_ROW, entriesPerRow)
		cellSize = w / entriesPerRow
		cellSize = math.min(MAX_CELL_SIZE, cellSize)
		cellSize = cellSize - config.cellPadding

		if nbEntries == 0 then
			rows = 0
		else
			rows = math.floor(nbEntries / entriesPerRow)
			if nbEntries % entriesPerRow ~= 0 then
				rows = rows + 1
			end
		end
		scroll:flush()
		scroll:refresh()
	end

	scroll.parentDidResize = function(self)
		local parent = self.parent
		local y = parent.Height
		if searchBar ~= nil then
			layoutSearchBar()
			y = y - searchBar.Height - 4
		end
		scroll.Width = parent.Width
		scroll.Height = y
		scroll.pos = { 0, 0 }
		refreshEntries()
	end

	scroll:setParent(grid)

	grid.onRemove = function(_)
		cancelRequestsAndTimers()
		grid.tickListener:Remove()
		grid.tickListener = nil
	end

	-- triggers request to obtain items
	grid.getItems = function(self)
		cancelRequestsAndTimers()

		-- empty list
		if self.setGridEntries ~= nil then
			self:setGridEntries({})
		end

		local req = api:getItems({
			minBlock = config.minBlocks,
			repo = config.repo,
			category = config.categories,
			page = 1,
			perPage = 25,
			search = search,
			sortBy = sortBy,
		}, function(items, err)
			if err then
				print("Error: " .. err.message)
				return
			end
			if self.setGridEntries ~= nil then
				self:setGridEntries(items)
			end
		end)
		addSentRequest(req)
	end

	grid.setGridEntries = function(self, newEntries)
		-- print("setGridEntries - nb entries:", #_entries)
		if self ~= grid then
			error("item_grid:setGridEntries(entries): use `:`", 2)
		end
		entries = newEntries or {}
		refreshEntries()
	end

	local dt1 = 0.0
	local dt4 = 0.0
	grid.tickListener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
		dt1 = dt1 + dt
		dt4 = dt4 + dt * 4

		for _, cell in pairs(activeCells) do
			if cell.item ~= nil and cell.item.pivot ~= nil then
				cell.item.pivot.LocalRotation:Set(-0.1, dt1, -0.2)
			end
		end

		-- local loadingCube
		-- local center = grid.cellSize * 0.5
		-- local loadingCubePos = { center + math.cos(dt4) * 20, center - math.sin(dt4) * 20, 0 }
		-- for _, c in ipairs(cells) do
		-- 	if c.getLoadingCube == nil then
		-- 		return
		-- 	end
		-- 	loadingCube = c:getLoadingCube()
		-- 	if loadingCube ~= nil and loadingCube:isVisible() then
		-- 		loadingCube.pos = loadingCubePos
		-- 	end

		-- 	if c.item ~= nil and c.item.pivot ~= nil then
		-- 		c.item.pivot.LocalRotation = { -0.1, dt1, -0.2 }
		-- 	end
		-- end
	end)

	grid:getItems()
	return grid
end

return itemGrid
