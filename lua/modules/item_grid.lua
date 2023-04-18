--[[
	known categories: "null", hair","jacket", "pants", "boots"
]]--

local itemGrid = {
	minCellSize = 140,
	maxColumns = 7,
	minRows = 2,
	minColumns = 2,
	minGridSize = 50,
}

itemGrid.create = function(self, config)

	-- load config (overriding defaults)
	local _config = {
		-- shows search bar when true
		searchBar = true,
		-- shows advanced filters button when true
		advancedFilters = false,
		-- used to filter categories when not nil
		categories = nil, -- {"null", hair","jacket", "pants", "boots"},
		-- grid gets items by default, unless this is set to "worlds"
		type = "items", 
		-- filter on particular repo
		repo = nil,
		-- mode
		minBlocks = 5,
	}
	if config ~= nil then
		if config.searchBar ~= nil then _config.searchBar = config.searchBar end
		if config.advancedFilters ~= nil then _config.advancedFilters = config.advancedFilters end
		if config.categories ~= nil then _config.categories = config.categories end
		if config.repo ~= nil then _config.repo = config.repo end
		if config.minBlocks ~= nil then _config.minBlocks = config.minBlocks end
	end
	config = _config

	local api = require("api")
	local theme = require("uitheme").current
	local ui = require("uikit")

	local grid = ui:createFrame() -- Color(255,0,0)
	grid.search = ""
	grid.config = config

	grid.setCategories = function(self, categories, type)
		if self.config == nil or self.getItems == nil then return end
		if type ~= nil then
			self.config.type = type
		end
		self.config.categories = categories
		self:getItems()
	end

	if config.searchBar then
		grid.searchBar = ui:createTextInput("", "search")
		grid.searchBar:setParent(grid)

		grid.searchBar.onTextChange = function(self)
			if grid.searchTimer ~= nil then
				grid.searchTimer:Cancel()
			end

			grid.searchTimer = Timer(0.3, function()

				local text = grid.searchBar.Text
				text = text:gsub(" ", "+")

				grid.search = text
				grid:getItems()
			end)

			if grid.searchBar.Text ~= "" then
				grid.searchButton.Text = "X"
				grid.searchButton.onRelease = function()
					grid.searchBar.Text = ""
				end
			else
				grid.searchButton.Text = "🔎"
				grid.searchButton.onRelease = function()
					grid.searchBar:focus()
				end
			end
		end

		-- 🔎 button that becomes "X" (to clear search)
		grid.searchButton = ui:createButton("🔎")
		grid.searchButton:setParent(grid)
		grid.searchButton:setColor(grid.searchBar.Color)

		grid.searchButton.onRelease = function()
			grid.searchBar:focus()
		end

	end

	grid.onPaginationChange = nil -- function(page, nbPages)

	-- first page cell when page is set
	-- using as reference cell to define new page number
	-- when grid resizes. 
	-- (doesn't mean cell remains at first position, put somewhere on page)
	grid.firstPageCell = 1

	grid.page = 1
	grid.nbPages = 1
	grid.cellSize = nil
	grid.nbCells = 1 -- cells per page
    grid.entries = {}

    grid.needsToRefreshEntries = false

    grid._paginationDidChange = function(self)
    	if self.onPaginationChange ~= nil then
    		self.onPaginationChange(self.page, self.nbPages)
    	end
	end

	grid.setPage = function(self, page)
		self.page = page
		if self.page < 1 then
			self.page = 1
		elseif self.page > self.nbPages then
			self.page = self.nbPages
		end
		self.firstPageCell = (self.page - 1) * self.nbCells + 1
		self:refresh()
	end

	grid._createCell = function(grid, size)
		local idleColor = theme.gridCellColor
		local cell = ui:createFrame(idleColor)
		cell:setParent(grid)
		cell.Width = size
		cell.Height = size

		cell.onPress = function()
			cell.Color = theme.gridCellColorPressed
		end

		cell.onRelease = function()
			cell.Color = idleColor
			if cell.loaded then
				if grid.onOpen then grid:onOpen(cell) end
			end
		end

		cell.onCancel = function()
			cell.Color = idleColor
		end

		local textFrame = ui:createFrame(Color(0,0,0,0.8))
		textFrame:setParent(cell)
		textFrame.Position.Z = 5 -- above shape

		local tName = ui:createText("", Color.White, "small")
		tName:setParent(textFrame)

		tName.LocalPosition = Number3(theme.padding, theme.padding, 0)
		textFrame.Width = cell.Width
		textFrame.Height = tName.Height + theme.padding * 2

		tName.LocalPosition = Number3(theme.padding, theme.padding, 0)
		cell.tName = tName

		local loadingCube = ui:createFrame(Color.White)
		cell.loadingCube = loadingCube
		loadingCube:setParent(cell)
		loadingCube.Width = 10
		loadingCube.Height = 10
		loadingCube.LocalPosition = Number3(cell.Width / 2, cell.Height / 2, 0)
		loadingCube.t = 0
		local obj = loadingCube.object
		obj.Tick = function(o, dt)
			if not loadingCube.LocalPosition then
				obj.Tick = nil
				return
			end
			if not loadingCube.IsHidden then
				loadingCube.t = loadingCube.t + dt * 4
				loadingCube.LocalPosition = Number3(cell.Width / 2 + math.cos(loadingCube.t) * 20, cell.Height / 2 - math.sin(loadingCube.t) * 20, 0)
				return
			end
		end

		return cell
	end

	grid._generateCells = function(self)
		local padding = theme.padding
		local sizeWithPadding = self.cellSize + padding
		local cells = {}
		for k=1,self.nbCells do
			local cell = self:_createCell(self.cellSize)
			local row = 1 + math.floor((k-1) / self.columns)
			if row > self.rows then break end
			local column = (k-1) % self.columns
			local x = column * sizeWithPadding
			local y = self.Height - row * self.cellSize - padding * (row - 1)
			
			local y = (self.rows - row) * (self.cellSize + padding)

			cell.LocalPosition = Number3(x,y,0)
			table.insert(cells, cell)
		end
		self.cells = cells
	end

	grid._setEntry = function(grid, cell, entry)

		cell.loaded = false
		cell.type = entry.type

		if cell.type == "item" then
			local id = entry.id
			local repo = entry.repo
			local name = entry.name
			local category = entry.category
			local description = entry.description
			local created = entry.created
			local updated = entry.updated
			local itemName = repo.."."..name

			if not cell.tName then return end
			cell.loadingCube:show()

			Object:Load(itemName, function(obj)
				if not cell.tName then return end
				if obj == nil then
					-- silent error, no print, just removing loading animation
					cell.loadingCube:hide()
					return
				end
				if cell.item then
					cell.item:remove()
					cell.item = nil
				end

				if cell.loadingCube then
					cell.loadingCube:hide()
				end

				local item = ui:createShape(obj, {spherized = true})
				cell.item = item
				item:setParent(cell)

				item.pivot.LocalRotation = {-0.1,0,-0.2}
				cell.t = 0
				cell.item.object.Tick = function(o, dt)
					if cell.t ~= nil then
						cell.t = cell.t + dt
						cell.item.pivot.LocalRotation= {-0.1,cell.t,-0.2}
					end
				end

				cell.id = id
				cell.name = name
				cell.repo = repo
				cell.itemFullName = itemName
				cell.category = category

				cell.description = description

				cell.created = created
				cell.updated = updated

				local function transform_string(str)
					local new_str = string.gsub(str, "_%a", string.upper)
					new_str = string.gsub(new_str, "_", " ")
					new_str = string.gsub(new_str, "^%l", string.upper)
					return new_str
				end

				if cell.tName then
					cell.tName.object.MaxWidth = grid.cellSize - 2 * theme.padding
					local betterName = transform_string(name)
					cell.tName.Text = betterName
				end

				-- setting Width sets Height & Depth as well when spherized
				item.Width = grid.cellSize 

				cell.loaded = true
			end)

		elseif cell.type == "world" then
			if cell.item then
				cell.item:remove()
				cell.item = nil
			end

			if cell.loadingCube then
				cell.loadingCube:hide()
			end

			local shape = Shape(Items.world_icon)
			local item = ui:createShape(shape, {spherized = true})
			cell.item = item
			item:setParent(cell)

			item.pivot.LocalRotation = {-0.1,0,-0.2}
			cell.t = 0
			cell.item.object.Tick = function(o, dt)
				if cell.t ~= nil then
					cell.t = cell.t + dt
					cell.item.pivot.LocalRotation= {-0.1,cell.t,-0.2}
				end
			end

			cell.title = entry.title
			cell.description = entry.description

			cell.likes = entry.likes
			cell.views = entry.views

			cell.id = entry.id

			cell.created = entry.created
			cell.updated = entry.updated

			if cell.tName then
				cell.tName.object.MaxWidth = grid.cellSize - 2 * theme.padding
				cell.tName.Text = cell.title
			end

			-- setting Width sets Height & Depth as well when spherized
			item.Width = grid.cellSize

			cell.loaded = true
		end
	end

    -- update the content of the cells based on grid.entries
	grid._updateCells = function(self)
		self:_emptyCells()
		local cells = self.cells
		local nbCells = self.nbCells
		local k = (self.page - 1) * nbCells
		for i=1, nbCells do
			local cell = cells[i]
			local entry = self.entries[k + i]
			cell.IsHidden = entry == nil
			if entry then
				cell.loadingCube.t = math.random() -- start loading randomly
				Timer((i-1) * 0.05, function()
					if self._setEntry then
						self:_setEntry(cell, entry)
					end
				end)
			end
		end
		collectgarbage("collect")
	end

    -- remove all items and destroy each cell (resizing screen)
	grid._removeCells = function(grid)
		grid:_emptyCells()
		for k,cell in ipairs(grid.cells) do
			if cell.tName ~= nil then
				cell.tName:remove()
				cell.tName = nil
			end
			if cell.remove then cell:remove() end
            grid.cells[k] = nil
		end
        grid.cells = nil
	end

    -- remove items in cells, keep cells
	grid._emptyCells = function(grid)
		local cells = grid.cells
		if cells ~= nil then
			for _,c in ipairs(cells) do
				if c.tName ~= nil then
					c.tName.Text = ""
					if c.item then
						c.item:remove()
						c.item = nil
					end
				end
			end
		end
	end

	grid.refresh = function(self)
		if self.needsToRefreshEntries then
			self.needsToRefreshEntries = false
			self:getItems()
			return
		end

		if self.Width < itemGrid.minGridSize or self.Height < itemGrid.minGridSize then return end

		local padding = theme.padding

		if self.cellSize == nil or (self.savedSize and (self.savedSize.width ~= self.Width or self.savedSize.height ~= self.Height)) then

			local widthPlusMargin = self.Width + padding

			-- height available for cells
			-- minus filter components depending on config)
			local heightPlusMargin = self.Height + padding
			if self.searchBar ~= nil then
				heightPlusMargin = heightPlusMargin - self.searchBar.Height - padding
			end

			local columns = math.floor(widthPlusMargin / itemGrid.minCellSize)
			if columns > itemGrid.maxColumns then columns = itemGrid.maxColumns end
			if columns < itemGrid.minColumns then
				columns = itemGrid.minColumns
			end

			self.columns = columns
			self.cellSize = math.floor(widthPlusMargin / columns) - padding

			self.rows = math.floor(heightPlusMargin / (self.cellSize + padding))

			if self.rows < itemGrid.minRows then
				self.rows = itemGrid.minRows
				self.cellSize = math.floor(heightPlusMargin / self.rows) - padding
				self.columns = math.floor(widthPlusMargin / (self.cellSize + padding))
			end

			self.nbCells = self.rows * self.columns

			-- reduce size 
			self.Width = self.columns * (self.cellSize + padding) - padding

			local totalHeight = self.rows * (self.cellSize + padding) - padding
			if self.searchBar ~= nil then
				totalHeight = totalHeight + self.searchBar.Height + padding
			end

			self.Height = totalHeight

			self.savedSize = {
				width = self.Width,
				height = self.Height
			}
		end

		if self:isVisible() then
			if self.cells then self:_removeCells() end
			self:_generateCells()

			if self.entries ~= nil then
				self.nbPages = math.ceil(#self.entries / self.nbCells)
				self.page = math.floor((self.firstPageCell - 1) / self.nbCells) + 1
			end

			self:_updateCells()
			self:_paginationDidChange()

			local offset = 0

			if self.searchButton ~= nil then
				self.searchButton.Height = self.searchBar.Height
				self.searchButton.Width = self.searchButton.Height
				self.searchBar.Width = self.Width - self.searchButton.Width
				self.searchBar.pos = {0, self.Height - self.searchBar.Height - offset, 0}
				self.searchButton.pos = self.searchBar.pos + {self.searchBar.Width, 0, 0}
			end
		end
	end

	grid.getItems = function(self)
		if self.setGridEntries ~= nil then self:setGridEntries({}) end -- empty list		

		if grid.config.type == "items" then
			api:getItems({ minBlock=self.config.minBlocks, repo=self.config.repo, category=grid.config.categories , page=1, perpage=250, search=self.search }, function(err,items)
				if err then
					print("Error: "..err)
					return
				end
				for _, i in ipairs(items) do i.type = "item" end
				if self.setGridEntries ~= nil and grid.config.type == "items" then self:setGridEntries(items) end			
			end)

		elseif grid.config.type == "worlds" then
			api:getWorlds({ repo=self.config.repo, category=grid.config.categories , page=1, perpage=250, search=self.search }, function(err,worlds)
				if err then
					print("Error: "..err)
					return
				end
				for _, w in ipairs(worlds) do w.type = "world" end
				if self.setGridEntries ~= nil and grid.config.type == "worlds" then self:setGridEntries(worlds) end			
			end)
		end
	end

	grid.setGridEntries = function(self, entries)
		self.firstPageCell = 1
		self.page = 1
		self.entries = entries or {}
		self:refresh()
		self.nbPages = math.ceil(#self.entries / self.nbCells)
		self:_paginationDidChange()
	end

	grid:getItems()

	return grid
end

return itemGrid
