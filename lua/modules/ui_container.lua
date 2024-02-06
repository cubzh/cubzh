local SEPARATOR_INSET = require("uitheme").current.paddingTiny
local PADDING = require("uitheme").current.padding
local uikit = require("uikit")

local pushElement = function(self, node)
	node:setParent(self)
	node.elementType = "node"
	table.insert(self.list, node)
	self:refresh()
end

local pushGap = function(self)
	local gap = {}
	gap.elementType = "gap"
	table.insert(self.list, gap)
	self:refresh()
end

local pushSeparator = function(self)
	local separator = require("uikit"):createFrame(Color.Grey)
	separator.elementType = "separator"
	separator.Width = 1
	table.insert(self.list, separator)
	self:refresh()
end

local horizontalContainerRefresh = function(self)
	local width = 0
	local height = 0

	for _, elem in ipairs(self.list) do
		if elem.elementType == "node" then
			height = math.max(elem.Height, height)
		end
	end

	for _, elem in ipairs(self.list) do
		if elem.elementType == "node" then
			elem.pos.X = width
			elem.pos.Y = height * 0.5 - elem.Height * 0.5
			width = width + elem.Width
		elseif elem.elementType == "separator" then
			elem.pos.X = width + PADDING
			elem.Width = 1
			elem.Height = height - SEPARATOR_INSET * 2
			elem.pos.Y = SEPARATOR_INSET
			width = width + elem.Width + PADDING * 2
		elseif elem.elementType == "gap" then
			width = width + PADDING
		end
	end

	self.Width = width
	self.Height = height
end

local createHorizontalContainer = function(_, color)
	local container = uikit:createFrame(color or Color(0, 0, 0, 0))
	container.list = {}

	container.pushElement = pushElement
	container.pushSeparator = pushSeparator
	container.pushGap = pushGap
	container.refresh = horizontalContainerRefresh

	container.parentDidResizeSystem = function(self)
		horizontalContainerRefresh(self)
	end

	return container
end

local verticalContainerRefresh = function(self)
	local width = 0
	local height = 0

	for _, elem in ipairs(self.list) do
		if elem.elementType == "node" then
			width = math.max(elem.Width, width)
			height = height + elem.Height
		elseif elem.elementType == "separator" then
			width = height + 1 + PADDING * 2
		elseif elem.elementType == "gap" then
			height = height + PADDING
		end
	end

	local cursorY = height

	for _, elem in ipairs(self.list) do
		if elem.elementType == "node" then
			cursorY = cursorY - elem.Height
			elem.pos.X = width * 0.5 - elem.Width * 0.5
			elem.pos.Y = cursorY
		elseif elem.elementType == "separator" then
			cursorY = cursorY - 1 - PADDING
			elem.pos.Y = cursorY
			cursorY = cursorY - PADDING
			elem.pos.X = SEPARATOR_INSET
			elem.Width = width - SEPARATOR_INSET * 2
			elem.Height = 1
		elseif elem.elementType == "gap" then
			cursorY = cursorY - PADDING
		end
	end

	self.Width = width
	self.Height = height
end

local createVerticalContainer = function(_, color)
	local container = uikit:createFrame(color or Color(0, 0, 0, 0))
	container.list = {}

	container.pushElement = pushElement
	container.pushSeparator = pushSeparator
	container.pushGap = pushGap
	container.refresh = verticalContainerRefresh

	container.parentDidResizeSystem = function(self)
		verticalContainerRefresh(self)
	end

	return container
end

return {
	createHorizontalContainer = createHorizontalContainer,
	createVerticalContainer = createVerticalContainer,
}
