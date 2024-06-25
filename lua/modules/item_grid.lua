--[[
	known categories: "null", "hair", "jacket", "pants", "boots"
]]
--

local itemGrid = {}

-- MODULES
local api = require("api")
local theme = require("uitheme").current
local bundle = require("bundle")
local conf = require("config")

-- CONSTANTS
local MIN_CELL_SIZE = 140
local MAX_CELL_SIZE = 200
local MIN_CELLS_PER_ROW = 2 -- prority over MIN_CELL_SIZE

itemGrid.create = function(_, config)
	-- load config (overriding defaults)
	local _config = {
		-- shows search bar when true
		searchBar = true,
		--
		search = "",
		-- shows advanced filters button when true
		advancedFilters = false,
		-- used to filter categories when not nil
		categories = nil, -- {"null", "hair" ,"jacket", "pants", "boots"},
		-- grid gets items by default, unless this is set to "worlds"
		type = "items",
		-- filter on particular repo
		repo = nil,
		-- mode
		minBlocks = 5,
		-- filters for new or featured
		worldsFilter = nil,
		--
		ignoreCategoryOnSearch = false,
		--
		uikit = require("uikit"),
		--
		backgroundColor = Color(40, 40, 40),
		--
		sort = "likes:desc",
		--
		cellPadding = theme.padding,
		--
		onOpen = function(cell) end,
	}

	local ok, err = pcall(function()
		config = conf:merge(_config, config, {
			acceptTypes = {
				repo = { "string" },
				categories = { "table" },
				worldsFilter = { "string" },
			},
		})
	end)
	if not ok then
		error("item_grid:create(config) - config error: " .. err, 2)
	end

	local ui = config.uikit
	local sortBy = config.sort

	local grid = ui:createFrame(Color(40, 40, 40)) -- Color(255,0,0)
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

	local cellContentRequests = {}
	local function addCellContentRequest(req)
		table.insert(cellContentRequests, req)
	end
	local function cancelCellContentRequest()
		for _, r in pairs(cellContentRequests) do
			r:Cancel()
		end
		cellContentRequests = {}
	end

	local function addTimer(timer)
		table.insert(timers, timer)
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

	grid.setCategories = function(self, categories, type)
		if type ~= nil then
			config.type = type
		end
		config.categories = categories
		cancelRequestsAndTimers()
		self:getItems()
	end

	grid.setWorldsFilter = function(self, filter)
		if filter == nil or type(filter) ~= Type.string then
			error("item_grid:setWorldsFilter(filter): filter should be a string", 2)
		end

		config.worldsFilter = filter
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

		sortBtn = ui:buttonNeutral({ content = "♥️ Likes", textSize = "small", textColor = Color.Black })
		sortBtn:setParent(grid)
		sortBtn.onRelease = function()
			if sortBy == "likes:desc" then
				sortBtn.Text = "✨ Recent"
				sortBy = "updatedAt:desc"
			elseif sortBy == "updatedAt:desc" then
				sortBtn.Text = "♥️ Likes"
				sortBy = "likes:desc"
			end
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
		backgroundColor = Color(0, 0, 0, 0),
		direction = "down",
		cellPadding = config.cellPadding,
		loadCell = function(index)
			if index <= rows then
				local row = table.remove(rowPool)
				if row == nil then
					row = ui:createFrame(Color(0, 0, 0, 0))
					row.cells = {}
				end
				row.Width = scroll.Width
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
							-- cell.Color = theme.gridCellColorPressed
						end

						cell.onRelease = function()
							if config.onOpen then
								config.onOpen(cell)
							else
								cellSelector:setParent(nil)
							end
						end

						cell.onCancel = function()
							cellSelector:setParent(nil)
						end

						local titleFrame = ui:frame({ color = Color(0, 0, 0, 0) })
						titleFrame:setParent(cell)
						titleFrame.LocalPosition.Z = config.uikit.kForegroundDepth

						local title = ui:createText("…", Color.White, "small")
						title:setParent(titleFrame)

						title.pos = { theme.padding, theme.padding }

						cell.titleFrame = titleFrame
						cell.title = title

						local likesFrame = ui:frame({ color = Color(0, 0, 0, 0) })
						likesFrame:setParent(cell)
						likesFrame.LocalPosition.Z = config.uikit.kForegroundDepth

						local likes = ui:createText("❤️ …", Color.White, "small")
						likes:setParent(likesFrame)

						likes.pos = { theme.padding, theme.padding }

						cell.likesFrame = likesFrame
						cell.likesLabel = likes

						local priceFrame = ui:frame({ color = Color(0, 0, 0, 0) })
						priceFrame:setParent(cell)
						priceFrame.LocalPosition.Z = config.uikit.kForegroundDepth

						local price = ui:createText("❤️ …", Color.White, "small")
						price:setParent(priceFrame)

						price.pos = { theme.padding, theme.padding }

						cell.priceFrame = priceFrame
						cell.priceLabel = price

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

							self.titleFrame.Width = self.Width
							self.title.object.MaxWidth = self.titleFrame.Width - theme.padding * 2
							self.title.Text = improveNameFormat(entry.name)
							self.titleFrame.Height = self.title.Height + theme.padding * 2

							self.likesLabel.object.MaxWidth = self.Width - theme.padding * 2
							self.likesLabel.Text = "❤️ " .. self.likes
							self.likesFrame.Height = self.likesLabel.Height + theme.padding * 2
							self.likesFrame.Width = self.likesLabel.Width + theme.padding * 2
							self.likesFrame.pos =
								{ self.Width - self.likesFrame.Width, self.Height - self.likesFrame.Height }

							self.priceLabel.object.MaxWidth = self.Width - theme.padding * 2
							self.priceLabel.Text = "💰 0" -- 🪙
							self.priceFrame.Height = self.priceLabel.Height + theme.padding * 2
							self.priceFrame.Width = self.priceLabel.Width + theme.padding * 2
							self.priceFrame.pos = { 0, self.Height - self.likesFrame.Height }

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
		local w = scroll.Width + config.cellPadding
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
			y = y - searchBar.Height
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

	-- grid._createCell = function(grid, size)
	-- 	local idleColor = theme.gridCellColor
	-- 	local cell = ui:createFrame(idleColor)
	-- 	cell:setParent(grid)

	-- 	cell.onPress = function()
	-- 		-- don't update the color if there's a thumbnail
	-- 		if cell.thumbnail ~= nil then
	-- 			return
	-- 		end
	-- 		cell.Color = theme.gridCellColorPressed
	-- 	end

	-- 	cell.onRelease = function()
	-- 		if cell.loaded and grid.onOpen then
	-- 			grid:onOpen(cell)
	-- 		end
	-- 		if cell.thumbnail ~= nil then
	-- 			return
	-- 		end
	-- 		cell.Color = idleColor
	-- 	end

	-- 	cell.onCancel = function()
	-- 		if cell.thumbnail ~= nil then
	-- 			return
	-- 		end
	-- 		cell.Color = idleColor
	-- 	end

	-- 	local likesBtn = ui:createButton("", { shadow = false, textSize = "small", borders = false })
	-- 	likesBtn:setColor(theme.gridCellFrameColor)
	-- 	likesBtn:setParent(cell)
	-- 	likesBtn.pos.X = 0

	-- 	local onReleaseBackup
	-- 	likesBtn.onRelease = function(self)
	-- 		onReleaseBackup = self.onRelease
	-- 		self.onRelease = nil
	-- 		cell.liked = not cell.liked
	-- 		cell.likes = cell.likes + (cell.liked and 1 or -1)
	-- 		cell:setNbLikes(cell.likes)
	-- 		local req = require("system_api", System):likeItem(cell.id, cell.liked, function(_)
	-- 			self.onRelease = onReleaseBackup
	-- 		end)
	-- 		addSentRequest(req)
	-- 		addCellContentRequest(req)
	-- 	end

	-- 	cell.layoutLikes = function(self)
	-- 		if likesBtn:isVisible() == false then
	-- 			return
	-- 		end
	-- 		likesBtn.pos.Y = self.Height - likesBtn.Height
	-- 	end

	-- 	cell.setNbLikes = function(self, n)
	-- 		if n > 0 then
	-- 			likesBtn.Text = "❤️ " .. math.floor(n)
	-- 		else
	-- 			likesBtn.Text = "❤️"
	-- 		end
	-- 		likesBtn:show()
	-- 		-- likesAndViewsFrame:show()
	-- 		self:layoutLikes()
	-- 	end

	-- 	cell.hideLikes = function(_)
	-- 		likesBtn:hide()
	-- 	end

	-- 	local textFrame = ui:createFrame(theme.gridCellFrameColor)
	-- 	textFrame:setParent(cell)
	-- 	textFrame.LocalPosition.Z = config.uikit.kForegroundDepth

	-- 	local tName = ui:createText("", Color.White, "small")
	-- 	tName:setParent(textFrame)

	-- 	tName.pos = { theme.padding, theme.padding }

	-- 	cell.tName = tName

	-- 	local loadingCube

	-- 	cell.getOrCreateLoadingCube = function(_)
	-- 		if loadingCube == nil then
	-- 			loadingCube = ui:createFrame(Color.White)
	-- 			loadingCube:setParent(cell)
	-- 			loadingCube.Width = 10
	-- 			loadingCube.Height = 10
	-- 		end
	-- 		loadingCube.pos = { cell.Width * 0.5, cell.Height * 0.5, 0 }
	-- 		return loadingCube
	-- 	end

	-- 	cell.getLoadingCube = function(_)
	-- 		return loadingCube
	-- 	end

	-- 	cell.layoutContent = function(self)
	-- 		textFrame.Width = cell.Width
	-- 		textFrame.Height = tName.Height + theme.padding * 2
	-- 		self:layoutLikes()
	-- 	end

	-- 	cell.setSize = function(self, size)
	-- 		self.Width = size
	-- 		self.Height = size
	-- 		self:layoutContent()
	-- 	end

	-- 	cell:setSize(size)

	-- 	return cell
	-- end

	-- grid._generateCells = function(self)
	-- 	local padding = theme.padding
	-- 	local sizeWithPadding = self.cellSize + padding
	-- 	if self.cells == nil then
	-- 		self.cells = {}
	-- 	end
	-- 	local cells = self.cells
	-- 	local cell

	-- 	-- self.nbCells == number of displayed cells
	-- 	for i = 1, self.nbCells do
	-- 		cell = cells[i]
	-- 		if cell == nil or cell.show == nil then
	-- 			cell = self:_createCell(self.cellSize)
	-- 			cells[i] = cell
	-- 		end
	-- 		cell:show()

	-- 		local row = 1 + math.floor((i - 1) / self.columns)
	-- 		if row > self.rows then
	-- 			break
	-- 		end
	-- 		local column = (i - 1) % self.columns

	-- 		local x = column * sizeWithPadding
	-- 		local y = (self.rows - row) * (self.cellSize + padding)

	-- 		cell.LocalPosition = Number3(x, y, 0)
	-- 	end

	-- 	for i = self.nbCells + 1, #cells do
	-- 		cells[i]:hide()
	-- 	end
	-- end

	-- grid._setEntry = function(grid, cell, entry)
	-- 	cell.type = entry.type

	-- 	if cell.type == "item" then
	-- 		cell.id = entry.id
	-- 		cell.repo = entry.repo
	-- 		cell.name = entry.name
	-- 		cell.category = entry.category
	-- 		cell.description = entry.description
	-- 		cell.created = entry.created
	-- 		cell.updated = entry.updated
	-- 		cell.likes = entry.likes
	-- 		cell.liked = entry.liked

	-- 		local itemName = cell.repo .. "." .. cell.name
	-- 		cell.loadedItemName = itemName
	-- 		cell.itemFullName = itemName

	-- 		if not cell.tName then
	-- 			return
	-- 		end
	-- 		cell:getOrCreateLoadingCube():show()

	-- 		cell:setNbLikes(cell.likes)
	-- 		cell:setSize(grid.cellSize)

	-- 		local function transform_string(str)
	-- 			local new_str = string.gsub(str, "_%a", string.upper)
	-- 			new_str = string.gsub(new_str, "_", " ")
	-- 			new_str = string.gsub(new_str, "^%l", string.upper)
	-- 			return new_str
	-- 		end

	-- 		if cell.tName then
	-- 			cell.tName.object.MaxWidth = (grid.cellSize or MIN_CELL_SIZE) - 2 * theme.padding
	-- 			local betterName = transform_string(cell.name)
	-- 			cell.tName.Text = betterName
	-- 			cell:layoutContent()
	-- 		end

	-- 		local req = Object:Load(itemName, function(obj)
	-- 			if not cell.tName then
	-- 				return
	-- 			end
	-- 			if cell.loadedItemName == nil or cell.loadedItemName ~= itemName then
	-- 				return
	-- 			end

	-- 			if obj == nil then
	-- 				-- silent error, no print, just removing loading animation
	-- 				local loadingCube = cell:getLoadingCube()
	-- 				if loadingCube then
	-- 					loadingCube:hide()
	-- 				end
	-- 				return
	-- 			end

	-- 			if cell.item then
	-- 				cell.item:remove()
	-- 				cell.item = nil
	-- 			end

	-- 			local loadingCube = cell:getLoadingCube()
	-- 			if loadingCube then
	-- 				loadingCube:hide()
	-- 			end

	-- 			local item = ui:createShape(obj, { spherized = true })
	-- 			cell.item = item
	-- 			item:setParent(cell)

	-- 			item.pivot.LocalRotation = { -0.1, 0, -0.2 }

	-- 			-- setting Width sets Height & Depth as well when spherized
	-- 			item.Width = grid.cellSize or MIN_CELL_SIZE
	-- 			cell.loaded = true
	-- 		end)

	-- 		addSentRequest(req)
	-- 		addCellContentRequest(req)
	-- 	elseif cell.type == "world" then
	-- 		local loadingCube = cell:getLoadingCube()
	-- 		if loadingCube then
	-- 			loadingCube:hide()
	-- 		end

	-- 		if entry.thumbnail == nil and cell.item == nil then
	-- 			-- no thumbnail, display default world icon
	-- 			local shape = bundle:Shape("shapes/world_icon")
	-- 			local item = ui:createShape(shape, { spherized = true })
	-- 			cell.item = item
	-- 			item:setParent(cell)
	-- 			item.pivot.LocalRotation = { -0.1, 0, -0.2 }
	-- 			-- setting Width sets Height & Depth as well when spherized
	-- 			item.Width = grid.cellSize
	-- 		end

	-- 		cell.title = entry.title
	-- 		cell.description = entry.description
	-- 		cell.thumbnail = entry.thumbnail

	-- 		cell.likes = entry.likes
	-- 		cell.views = entry.views

	-- 		cell.id = entry.id

	-- 		cell.created = entry.created
	-- 		cell.updated = entry.updated

	-- 		if cell.tName then
	-- 			cell.tName.object.MaxWidth = grid.cellSize - 2 * theme.padding
	-- 			if cell.title:len() > api.maxWorldTitleLength then
	-- 				local str = cell.title
	-- 				str = str:sub(1, api.maxWorldTitleLength - 1)
	-- 				str = str .. "…"
	-- 				cell.tName.Text = str
	-- 			else
	-- 				cell.tName.Text = cell.title
	-- 			end
	-- 		end

	-- 		cell:setNbLikes(cell.likes)
	-- 		cell:setSize(grid.cellSize)

	-- 		cell:layoutContent()

	-- 		cell.loaded = true
	-- 	end
	-- end

	-- update the content of the cells based on grid.entries
	-- grid._updateCells = function(self)
	-- 	cancelTimers()
	-- 	cancelCellContentRequest()

	-- 	self:_emptyCells()
	-- 	local cells = self.cells
	-- 	local nbCells = self.nbCells
	-- 	local k = (self.page - 1) * nbCells
	-- 	local req

	-- 	for i = 1, nbCells do
	-- 		local cell = cells[i]
	-- 		local entry = self.entries[k + i]
	-- 		cell.IsHidden = entry == nil
	-- 		cell.loaded = false

	-- 		if entry ~= nil then
	-- 			local timer = Timer((i - 1) * 0.02, function()
	-- 				if self._setEntry then
	-- 					self:_setEntry(cell, entry)
	-- 				end

	-- 				if config.type ~= "worlds" or entry.id == nil then
	-- 					return -- no need to get the thumbnail
	-- 				end
	-- 				req = api:getWorldThumbnail(entry.id, function(err, img)
	-- 					if err ~= nil or cell.setImage == nil then
	-- 						return
	-- 					end
	-- 					entry.thumbnail = img

	-- 					if cell.item ~= nil then
	-- 						cell.item:remove()
	-- 						cell.item = nil
	-- 					end

	-- 					cell.thumbnail = img
	-- 					cell:setImage(img)

	-- 					if type(entry.onThumbnailUpdate) == "function" then
	-- 						entry.onThumbnailUpdate(img)
	-- 					end
	-- 				end)
	-- 				addSentRequest(req)
	-- 				addCellContentRequest(req)
	-- 			end)
	-- 			addTimer(timer)
	-- 		end
	-- 	end

	-- 	collectgarbage("collect")
	-- end

	-- remove items in cells, keep cells
	-- grid._emptyCells = function(grid)
	-- 	local cells = grid.cells
	-- 	if cells == nil then
	-- 		return
	-- 	end
	-- 	for _, c in ipairs(cells) do
	-- 		c:hideLikes()
	-- 		c.tName.Text = ""
	-- 		c:setImage(nil)
	-- 		if c.item ~= nil and c.item.remove then
	-- 			c.item:remove()
	-- 		end
	-- 		c.item = nil
	-- 	end
	-- end

	-- grid.refresh = function(self)
	-- 	cancelCellContentRequest()

	-- 	if self ~= grid then
	-- 		error("item_grid:refresh(): use `:`", 2)
	-- 	end

	-- 	if self.Width < MIN_GRID_SIZE or self.Height < MIN_GRID_SIZE then
	-- 		return
	-- 	end

	-- 	local padding = theme.padding

	-- 	if
	-- 		self.cellSize == nil
	-- 		or (self.savedSize and (self.savedSize.width ~= self.Width or self.savedSize.height ~= self.Height))
	-- 	then
	-- 		local widthPlusMargin = self.Width + padding

	-- 		-- height available for cells
	-- 		-- minus filter components depending on config)
	-- 		local heightPlusMargin = self.Height + padding
	-- 		if self.searchBar ~= nil then
	-- 			heightPlusMargin = heightPlusMargin - self.searchBar.Height - padding
	-- 		end

	-- 		local columns = math.floor(widthPlusMargin / MIN_CELL_SIZE)
	-- 		if columns > MAX_COLUMNS then
	-- 			columns = MAX_COLUMNS
	-- 		end
	-- 		if columns < MIN_COLUMNS then
	-- 			columns = MIN_COLUMNS
	-- 		end

	-- 		self.columns = columns
	-- 		self.cellSize = math.floor(widthPlusMargin / columns) - padding

	-- 		self.rows = math.floor(heightPlusMargin / (self.cellSize + padding))

	-- 		if self.rows < MIN_ROWS then
	-- 			self.rows = MIN_ROWS
	-- 			self.cellSize = math.floor(heightPlusMargin / self.rows) - padding
	-- 			self.columns = math.floor(widthPlusMargin / (self.cellSize + padding))
	-- 		end

	-- 		self.nbCells = self.rows * self.columns

	-- 		-- reduce size
	-- 		self.Width = self.columns * (self.cellSize + padding) - padding

	-- 		local totalHeight = self.rows * (self.cellSize + padding) - padding
	-- 		if self.searchBar ~= nil then
	-- 			totalHeight = totalHeight + self.searchBar.Height + padding
	-- 		end

	-- 		self.Height = totalHeight

	-- 		self.savedSize = {
	-- 			width = self.Width,
	-- 			height = self.Height,
	-- 		}
	-- 	end

	-- 	if self:isVisible() then
	-- 		self:_generateCells() -- generated missing cells if needed

	-- 		if self.entries ~= nil then
	-- 			self.nbPages = math.ceil(#self.entries / self.nbCells)
	-- 			self.page = math.floor((self.firstPageCell - 1) / self.nbCells) + 1
	-- 		end

	-- 		self:_updateCells()
	-- 		--- self:_paginationDidChange()

	-- 		local offset = 0

	-- 		if self.searchButton ~= nil then
	-- 			self.searchButton.Height = self.searchBar.Height
	-- 			self.searchButton.Width = self.searchButton.Height
	-- 			self.sortButton.Height = self.searchBar.Height
	-- 			self.searchBar.Width = self.Width - self.searchButton.Width - self.sortButton.Width
	-- 			self.searchBar.pos = { 0, self.Height - self.searchBar.Height - offset, 0 }
	-- 			self.searchButton.pos = self.searchBar.pos + { self.searchBar.Width, 0, 0 }
	-- 			self.sortButton.pos = self.searchButton.pos + { self.searchButton.Width, 0, 0 }
	-- 		end
	-- 	end
	-- end

	-- triggers request to obtain items
	grid.getItems = function(self)
		cancelRequestsAndTimers()

		-- empty list
		if self.setGridEntries ~= nil then
			self:setGridEntries({})
		end

		if config.type == "items" then
			local req = api:getItems({
				minBlock = config.minBlocks,
				repo = config.repo,
				category = config.categories,
				page = 1,
				perPage = 25,
				search = search,
				sortBy = sortBy,
			}, function(err, items)
				if err then
					print("Error: " .. err)
					return
				end
				for _, itm in ipairs(items) do
					itm.type = "item"
				end
				if self.setGridEntries ~= nil and config.type == "items" then
					self:setGridEntries(items)
				end
			end)
			addSentRequest(req)
		elseif config.type == "worlds" then
			local apiCallback = function(err, worlds)
				if err then
					print("Error: " .. err)
					return
				end
				for _, w in ipairs(worlds) do
					w.type = "world"
				end
				if self.setGridEntries ~= nil and config.type == "worlds" then
					self:setGridEntries(worlds)
				end
			end

			-- world filter (nil, featured, recent)
			local worldsFilter = config.worldsFilter
			local ignoreCategoryOnSearch = config.ignoreCategoryOnSearch
			-- used to filter on the author's name, for "my creations"
			local repoFilter = config.repo

			-- unpublished worlds (world drafts)
			if repoFilter ~= nil then
				local categories = config.categories
				if ignoreCategoryOnSearch == true and search ~= nil and #search > 0 then
					categories = ""
				end
				local reqConfig =
					{ repo = config.repo, category = categories, page = 1, perPage = 250, search = search }
				local req = api:getWorlds(reqConfig, apiCallback)
				addSentRequest(req)
			else -- published worlds
				if ignoreCategoryOnSearch == true and search ~= nil and #search > 0 then
					worldsFilter = nil
				end
				local req = api:getPublishedWorlds(
					{ search = search, list = worldsFilter, perPage = 100, page = 1, sortBy = sortBy },
					apiCallback
				)
				addSentRequest(req)
			end
		end
	end

	grid.setGridEntries = function(self, _entries)
		-- print("setGridEntries - nb entries:", #_entries)
		if self ~= grid then
			error("item_grid:setGridEntries(entries): use `:`", 2)
		end
		entries = _entries or {}
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
