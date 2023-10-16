--[[
palette is implemented as a uikit node.
Therefore it requires uikit module to work.

Usage:
uikit = require("uikit")
palette = require("palette")

local p = palette:create(uikit)
p:setParent(ui.root)
p.LocalPosition = {0, 50, 0}

-- Called when palette layout's been updated.
p.didRefresh = function(self)
	-- ...
end

-- Called when selection just changed.
p.didChangeSelection = function(self, color)
	-- print("didChangeSelection: ", color.R, color.G, color.B)
end

-- Called when the palettes requires edit for color at index.
-- This signal can be used to show a color picker.
p.requiresEdit = function(self, index, color)
	-- print("requiresEdit:", index, color.R, color.G, color.B)
end

-- Sets all palette colors to match those of the  given Shape or Palette.
p:setColors(Map.Palette)

-- Adds colors from the given Shape or Palette,
-- avoiding duplicates.
local s = Shape(Items.official.head)
p:mergeColors(s.Palette)

-- Adds one single color
p:addColor(Color(255,0,0))
--]]

local palette = {}

theme = require("uitheme").current

palette.create = function(_, uikit, btnColor)
	local node = uikit:createNode()

	-- config
	node.nbColumns = 6
	node.maxSquareSize = 40
	node.maxHeight = 200 -- max total height for component
	node.padding = theme.padding
	node._selectedIndex = 0
	node._squareSize = 0
	node._maxScreenWidthFactor = 0.5

	-- callbacks
	node.didRefresh = nil -- function(self)
	node.didAdd = nil -- function(self, color)
	node.didChangeSelection = nil -- function(self, color)
	node.requiresEdit = nil -- function(self, index, color)

	local bg = uikit:createFrame(Color(50, 50, 50, 200))
	bg.Width = 200
	bg.Height = 200
	bg:setParent(node)
	node.background = bg

	node._width = function(self)
		return self.background.Width
	end

	node._height = function(self)
		return self.background.Height
	end

	local editBtn = uikit:createButton("✏️")
	if btnColor then
		editBtn:setColor(btnColor)
	end
	editBtn:setParent(node)
	node.editBtn = editBtn
	editBtn.onRelease = function()
		if node.requiresEdit ~= nil then
			node:requiresEdit(node._selectedIndex, node:_colorFromIndex(node._selectedIndex))
		end
	end

	local addBtn = uikit:createButton("➕")
	if btnColor then
		addBtn:setColor(btnColor)
	end
	addBtn:setParent(node)
	node.addBtn = addBtn
	addBtn.onRelease = function()
		local c = Color(255, 255, 255, 255)
		local step = 1
		-- Avoid adding white if white is already in shape
		while node:_paletteHasColor(c) do
			c = Color(255 - step, 255 - step, 255 - step, 255)
			step = step + 1
		end
		node:addColor(c)
		if node.didAdd then
			node:didAdd(c)
		end
	end

	local deleteBtn = uikit:createButton("➖")
	if btnColor then
		deleteBtn:setColor(btnColor)
	end
	deleteBtn:setParent(node)
	node.deleteBtn = deleteBtn
	deleteBtn.onRelease = function()
		node:_removeIndex(node._selectedIndex)
		node:_refresh()
	end

	-- SELECTION FRAME

	local selectionFrameShape = MutableShape(false)
	selectionFrameShape.CollisionGroups = {}
	local size = 10
	for y = 0, size - 1 do
		for x = 0, size - 1 do
			if y == 0 or x == 0 or y == size - 1 or x == size - 1 then
				selectionFrameShape:AddBlock(Color.White, x, y, 0)
			end
			if y == 1 or x == 1 or y == size - 2 or x == size - 2 then
				selectionFrameShape:AddBlock(Color.Black, x, y, 0)
			end
		end
	end

	local selectionFrame = uikit:createShape(selectionFrameShape, { doNotFlip = true })
	selectionFrame:setParent(node)
	selectionFrame.Width = 40
	selectionFrame.Height = 40
	node.selectionFrame = selectionFrame

	-- COLORS

	node._paletteHasColor = function(self, color)
		local palette = self.colorsShape.Palette
		for i = 1, #palette do
			if palette[i].Color == color then
				return true
			end
		end
		return false
	end

	node._resetColorsShape = function(self)
		if self.colors ~= nil then
			self.colors:remove()
		end

		local colorsShape = MutableShape()
		colorsShape.CollisionGroups = {}
		local colors = uikit:createShape(colorsShape, { doNotFlip = true })
		colors:setParent(self)

		self.colors = colors
		self.colorsShape = colorsShape

		colors.onPress = function(self, _, block)
			local index = self.parent:_indexFromBlock(block)
			self.parent:_selectIndex(index)
		end
	end

	node:_resetColorsShape()

	node._indexFromBlock = function(self, block)
		local column = block.Coords.X + 1
		local row = -block.Coords.Y - 1
		local index = row * self.nbColumns + column
		return index
	end

	node._blockFromIndex = function(self, index)
		local x = (index - 1) % self.nbColumns
		local y = -1 - math.floor((index - 1) / self.nbColumns)
		return self.colorsShape:GetBlock(x, y, 0)
	end

	node._colorFromIndex = function(self, index)
		-- ⚠️ block.Properties doesn't work
		-- ⚠️ block.Color could return blocks Color
		-- return node:_blockFromIndex(index).Properties.Color
		return self.colorsShape.Palette[self:_blockFromIndex(index).PaletteIndex].Color
	end

	node._selectIndex = function(self, index)
		self._selectedIndex = index
		self:_refreshSelectionFrame()
		if self.didChangeSelection ~= nil then -- function(self, color)
			self:didChangeSelection(self:getCurrentColor())
		end
	end

	node._removeIndex = function(self, index)
		local color = self:_colorFromIndex(index)
		if color == nil then
			return
		end
		local b = self:_blockFromIndex(index)
		if b == nil then
			return
		end

		local count = self.colorsShape.BlocksCount
		if count == 1 then
			return
		end -- do not remove last color

		local paletteIndexToRemove = b.PaletteIndex

		local b2
		for i = index, count do
			b2 = self:_blockFromIndex(i)
			b:Replace(b2)
			b = b2
		end

		b:Remove()

		self.colorsShape.Palette:RemoveColor(paletteIndexToRemove)

		if index > count - 1 then
			if count - 1 == 0 then
				self:_selectIndex(0)
			else
				self:_selectIndex(1)
			end
		else
			self:_selectIndex(index)
		end
	end

	node._refreshSelectionFrame = function(self)
		if self._selectedIndex == 0 then
			self.selectionFrame:hide()
			return
		else
			self.selectionFrame:show()
		end

		local b = self:_blockFromIndex(self._selectedIndex)
		if b == nil then
			self.selectionFrame:hide()
			return
		end

		self.selectionFrame.Width = self._squareSize
		self.selectionFrame.Height = self._squareSize

		self.selectionFrame.LocalPosition.X = self.colors.pos.X + b.Coords.X * self._squareSize
		self.selectionFrame.LocalPosition.Y = self.colors.pos.Y + self.colors.Height + b.Coords.Y * self._squareSize
	end

	node._refresh = function(self)
		local controls = { self.deleteBtn, self.editBtn, self.addBtn }

		local controlsWidth = self.padding
		for _, element in ipairs(controls) do
			controlsWidth = controlsWidth + element.Width + self.padding
		end
		local controlsWidthWithoutPadding = controlsWidth - self.padding * 2

		local heightWithoutColors = self.padding * 3 + self.editBtn.Height
		local availableHeight = self.maxHeight - heightWithoutColors

		local columns = self.colorsShape.Width
		local rows = self.colorsShape.Height

		-- commented this part to use the Height of buttons instead

		self._squareSize = self.addBtn.Height
		local colorsHeight = self._squareSize * rows
		if colorsHeight > availableHeight then
			colorsHeight = availableHeight
			self._squareSize = availableHeight / rows
		end

		local colorsWidth = self._squareSize * columns

		if colorsWidth > Screen.Width * self._maxScreenWidthFactor then
			colorsWidth = Screen.Width * self._maxScreenWidthFactor
			self._squareSize = colorsWidth / columns
			colorsHeight = self._squareSize * rows
		end

		-- force beyond availableHeight if colorsWidth
		-- is less than controlsWidthWithoutPadding
		if colorsWidth < controlsWidthWithoutPadding then
			colorsWidth = controlsWidthWithoutPadding
			self._squareSize = colorsWidth / columns
			colorsHeight = self._squareSize * rows
		end

		if self._squareSize > self.maxSquareSize then
			self._squareSize = self.maxSquareSize
			colorsWidth = self._squareSize * columns
			colorsHeight = self._squareSize * rows
		end

		self.colors:refresh()

		self.colors.Width = colorsWidth
		self.colors.Height = colorsHeight

		self.colors.pos = { self.padding, self.deleteBtn.LocalPosition.Y + self.deleteBtn.Height + self.padding, 0 }

		colorsWidth = colorsWidth + self.padding * 2
		local width = controlsWidth > colorsWidth and controlsWidth or colorsWidth

		self.background.Height = heightWithoutColors + self.colors.Height
		self.background.Width = width

		self.addBtn.LocalPosition = { width - self.padding - self.addBtn.Width, self.padding, 0 }
		self.editBtn.LocalPosition =
			{ self.addBtn.LocalPosition.X - self.editBtn.Width - self.padding, self.padding, 0 }
		self.deleteBtn.LocalPosition =
			{ self.editBtn.LocalPosition.X - self.deleteBtn.Width - self.padding, self.padding, 0 }

		self:_refreshSelectionFrame()

		if self.didRefresh ~= nil then
			self:didRefresh()
		end
	end

	node.parentDidResize = function(self)
		self:_refresh()
	end

	node.getCurrentColor = function(self)
		return self:_colorFromIndex(self._selectedIndex)
	end

	-- returns true if added
	node.selectOrAddColorIfMissing = function(self, color)
		local index = self.colorsShape.Palette:GetIndex(color)
		if index ~= nil then
			node:_selectIndex(index)
			return false
		end
		self:addColor(color)
		return true
	end

	node.addColorOrCloseOneIfFound = function(self, color)
		local tries = 0
		local maxTries = 50

		local direction = 1
		if color.R > 127 and color.G > 127 and color.B > 127 then
			direction = -1
		end

		while self.colorsShape.Palette:GetIndex(color) ~= nil do
			if direction < 0 then
				if color.R > 0 then
					color.R = color.R + direction
				end
				if color.G > 0 then
					color.G = color.G + direction
				end
				if color.B > 0 then
					color.B = color.B + direction
				end
			else
				if color.R < 255 then
					color.R = color.R + direction
				end
				if color.G < 255 then
					color.G = color.G + direction
				end
				if color.B < 255 then
					color.B = color.B + direction
				end
			end
			tries = tries + 1
			if tries == maxTries then
				return false
			end
		end

		self:addColor(color)
		return true
	end

	node.addColor = function(self, color, skipRefreshAndSelect)
		local nBlocks = self.colorsShape.BlocksCount

		local x = nBlocks % self.nbColumns
		local y = -(math.floor(nBlocks / self.nbColumns)) - 1
		self.colorsShape:AddBlock(color, x, y, 0)
		nBlocks = nBlocks + 1

		if skipRefreshAndSelect ~= true then
			node:_refresh()
			node:_selectIndex(nBlocks)
		end
	end

	node.setColors = function(self, container)
		local palette

		if type(container) == "Palette" then
			palette = container
		elseif type(container) == "Shape" or type(container) == "MutableShape" then
			palette = container.Palette
		else
			error("palette can only get colors from a Palette or a Shape")
		end

		node:_resetColorsShape()

		for i = 1, #palette do
			self:addColor(palette[i].Color, true)
		end

		self.colorsShape:RefreshModel()

		if #palette == 0 then
			self:_selectIndex(0)
		else
			self:_selectIndex(1)
		end

		node:_refresh()
	end

	node.setSelectedColor = function(self, color)
		self.colorsShape.Palette[self:_blockFromIndex(self._selectedIndex).PaletteIndex].Color = color
	end

	node.mergeColors = function(self, container)
		local palette

		if type(container) == "Palette" then
			palette = container
		elseif type(container) == "Shape" or type(container) == "MutableShape" then
			palette = container.Palette
		else
			error("palette can only get colors from a Palette or a Shape")
		end

		for i = 1, #palette do
			self:selectOrAddColorIfMissing(palette[i].Color)
		end

		if #palette == 0 then
			self:_selectIndex(0)
		else
			self:_selectIndex(1)
		end

		node:_refresh()
	end

	-- DEFAULT COLORS
	node:addColor(Color(86, 51, 23))
	node:addColor(Color(129, 88, 54))
	node:addColor(Color(234, 159, 98))
	node:addColor(Color(255, 220, 191))
	node:addColor(Color(0, 0, 0))
	node:addColor(Color(84, 84, 84))
	node:addColor(Color(168, 168, 168))
	node:addColor(Color(255, 255, 255))
	node:addColor(Color(0, 47, 142))
	node:addColor(Color(0, 81, 173))
	node:addColor(Color(0, 120, 255))
	node:addColor(Color(158, 189, 255))
	node:addColor(Color(0, 81, 123))
	node:addColor(Color(17, 139, 174))
	node:addColor(Color(76, 215, 255))
	node:addColor(Color(164, 250, 255))
	node:addColor(Color(2, 83, 0))
	node:addColor(Color(20, 160, 17))
	node:addColor(Color(6, 238, 0))
	node:addColor(Color(132, 255, 32))
	node:addColor(Color(255, 191, 0))
	node:addColor(Color(255, 224, 58))
	node:addColor(Color(255, 221, 120))
	node:addColor(Color(255, 253, 211))
	node:addColor(Color(127, 65, 50))
	node:addColor(Color(188, 75, 0))
	node:addColor(Color(253, 110, 14))
	node:addColor(Color(253, 174, 78))
	node:addColor(Color(184, 13, 0))
	node:addColor(Color(255, 18, 0))
	node:addColor(Color(255, 117, 156))
	node:addColor(Color(255, 175, 198))
	node:addColor(Color(178, 0, 113))
	node:addColor(Color(255, 0, 120))
	node:addColor(Color(255, 157, 219))
	node:addColor(Color(248, 203, 231))
	node:addColor(Color(61, 0, 85))
	node:addColor(Color(136, 0, 252))
	node:addColor(Color(182, 122, 233))
	node:addColor(Color(237, 215, 255))

	return node
end

return palette
