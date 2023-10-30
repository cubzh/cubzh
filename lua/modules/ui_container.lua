
local uiHorizontalIndex = {}

uiHorizontalIndex.pushElement = function(self, node)
	node:setParent(self.bg)
	table.insert(self.list, node)
	self:refresh()
end

uiHorizontalIndex.pushSeparator = function(self)
	self:pushGap()
	local separator = require("uikit"):createFrame(Color.Grey)
	separator.Width = 1
	separator.Height = self.Height
	separator:setParent(self.bg)
	table.insert(self.list, separator)
	self:pushGap()
	self:refresh()
end

uiHorizontalIndex.pushGap = function(self)
	local gap = require("uikit"):createFrame()
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
	local width, height = 0, 0
	for _,elem in ipairs(self.list) do
		elem.pos.X = width
		width = width + elem.Width
		if height < elem.Height then height = elem.Height end
	end

	for _,elem in ipairs(self.list) do
		elem.Height = height
	end
	self.Width = width
	self.Height = height
end

local createUiHorizontal = function()
	local elem = {}
	elem.bg = require("uikit"):createFrame()
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

	local metatable = { __metatable = false, __index = index, __newindex = newindex }
	setmetatable(elem, metatable)

	return elem
end

return {
	createHorizontalContainer = createUiHorizontal
}