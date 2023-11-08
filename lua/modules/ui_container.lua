local padding = require("uitheme").current.padding

local uiHorizontalIndex = {}

uiHorizontalIndex.pushElement = function(self, node)
	node:setParent(self.bg)
	node.elementType = "node"
	table.insert(self.list, node)
	self:refresh()
end

uiHorizontalIndex.pushSeparator = function(self)
	self:pushGap()
	local separator = require("uikit"):createFrame(Color.Grey)
	separator.elementType = "separator"
	separator.Width = 1
	separator.Height = self.Height
	separator:setParent(self.bg)
	table.insert(self.list, separator)
	self:pushGap()
	self:refresh()
end

uiHorizontalIndex.pushGap = function(self)
	local gap = require("uikit"):createFrame()
	gap.elementType = "gap"
	gap.Width = require("uitheme").current.padding
	gap.Height = self.Height
	gap:setParent(self.bg)
	table.insert(self.list, gap)
	self:refresh()
end

uiHorizontalIndex.setParent = function(self, node)
	self.bg:setParent(node)
end

uiHorizontalIndex.refresh = function(self)
	local width, height = padding, 0
	for _,elem in ipairs(self.list) do
		elem.pos.X = width
		elem.pos.Y = padding
		width = width + elem.Width
		if elem.elementType == "node" and height < elem.Height then height = elem.Height end
	end

	for _,elem in ipairs(self.list) do
		elem.Height = height
	end
	width, height = width + padding, height + padding * 2
	self.Width = width
	self.Height = height
end

local createHorizontalContainer = function(_, color)
	local elem = {}
	elem.bg = require("uikit"):createFrame(color)
	local list = {}

	local index = function(_,k)
		if k == "list" then return list end
		return uiHorizontalIndex[k] or elem.bg[k]
	end
	local newindex = function(_,k,v)
		if k == "list" then
			list = v
			return
		end
		elem.bg[k] = v
	end

	elem.bg.parentDidResize = function()
		elem:refresh()
	end

	local metatable = { __metatable = false, __index = index, __newindex = newindex }
	setmetatable(elem, metatable)

	return elem
end

local uiVerticalIndex = {}

uiVerticalIndex.pushElement = function(self, node)
	node:setParent(self.bg)
	node.elementType = "node"
	table.insert(self.list, node)
	self:refresh()
end

uiVerticalIndex.pushSeparator = function(self)
	self:pushGap()
	local separator = require("uikit"):createFrame(Color.Grey)
	separator.elementType = "separator"
	separator.Width = self.Width
	separator.Height = 1
	separator:setParent(self.bg)
	table.insert(self.list, separator)
	self:pushGap()
	self:refresh()
end

uiVerticalIndex.pushGap = function(self)
	local gap = require("uikit"):createFrame()
	gap.elementType = "gap"
	gap.Width = self.Width
	gap.Height = require("uitheme").current.padding
	gap:setParent(self.bg)
	table.insert(self.list, gap)
	self:refresh()
end

uiVerticalIndex.setParent = function(self, node)
	self.bg:setParent(node)
end

uiVerticalIndex.refresh = function(self)
	local width, height = 0, 0

	for _,elem in ipairs(self.list) do
		height = height + elem.Height
	end
	self.Height = height + 2 * padding

	height = self.Height - padding
	for _,elem in ipairs(self.list) do
		elem.pos.X = padding
		elem.pos.Y = height - elem.Height
		height = height - elem.Height
		if width < elem.Width then width = elem.Width end
	end

	for _,elem in ipairs(self.list) do
		elem.Width = width
	end
	self.Width = width + 2 * padding
end

local createVerticalContainer = function(_, color)
	local elem = {}
	elem.bg = require("uikit"):createFrame(color)
	local list = {}

	local index = function(_,k)
		if k == "list" then return list end
		return uiVerticalIndex[k] or elem.bg[k]
	end
	local newindex = function(_,k,v)
		if k == "list" then
			list = v
			return
		end
		elem.bg[k] = v
	end

	elem.bg.parentDidResize = function()
		elem:refresh()
	end

	local metatable = { __metatable = false, __index = index, __newindex = newindex }
	setmetatable(elem, metatable)

	return elem
end

return {
	createHorizontalContainer = createHorizontalContainer,
	createVerticalContainer = createVerticalContainer
}