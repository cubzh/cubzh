local modalLoadingContent = {}

modalLoadingContent.create = function(self)

	local modal = require("modal")

	local loadingContent = modal:createContent()
	loadingContent.title = "Loading"
	loadingContent.icon = "🔎"
	loadingContent.closeButton = false

	local node = ui:createNode()
	local label = ui:createText("...", theme.textColor)
	label:setParent(node)

	node._w = 300
	node._h = 300
	node._width = function(self) return self._w end
	node._height = function(self) return self._h end

	node._setWidth = function(self, v) self._w = v end
	node._setHeight = function(self, v) self._h = v end

	loadingContent.node = node

	node.refresh = function(self)
		label.pos = {self.Width * 0.5 - label.Width * 0.5, self.Height * 0.5 - label.Height * 0.5, 0}
	end

	loadingContent.idealReducedContentSize = function(content, width, height)
		width = math.min(width, 300)
		height = math.min(height, 100)
		content.Width = width
		content.Height = height
		content:refresh()
		return Number2(content.Width, content.Height)
	end

	return loadingContent
end

return modalLoadingContent