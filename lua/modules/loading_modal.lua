loading = {}

loading.create = function(_, text, config)
	local modal = require("modal")
	local theme = require("uitheme").current

	-- default config
	local defaultConfig = {
		uikit = require("uikit"), -- allows to provide specific instance of uikit
	}

	local ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config)
	end)
	if not ok then
		error("loading:create(config) - config error: " .. err, 2)
	end

	local ui = config.uikit

	local minWidth = 200
	local animationHeight = 20
	local animationCubeOffset = 16

	local content = modal:createContent()
	content.closeButton = false

	content.idealReducedContentSize = function(content, _, _)
		content:refresh()
		return Number2(content.Width, content.Height)
	end

	local maxWidth = function()
		return Screen.Width - theme.modalMargin * 2
	end

	local maxHeight = function()
		return Screen.Height - 100
	end

	local position = function(modal)
		modal.pos = { Screen.Width * 0.5 - modal.Width * 0.5, Screen.Height * 0.5 - modal.Height * 0.5 }
	end

	local node = ui:frame()
	content.node = node

	local label = ui:createText("", Color.White)
	label:setParent(node)
	node.label = label

	local cube = MutableShape()
	cube:AddBlock(Color.White, 0, 0, 0)
	cube.Pivot = { 0.5, 0.5, 0.5 }

	local c1 = ui:createShape(Shape(cube))
	c1:setParent(node)

	local c2 = ui:createShape(Shape(cube))
	c2:setParent(node)

	local c3 = ui:createShape(Shape(cube))
	c3:setParent(node)

	local speed = 6
	local tDiff = 0.5
	local tc1 = 1.5
	c1.shape.Tick = function(o, dt)
		tc1 = tc1 + dt * speed
		o.Scale = 1.0 + math.sin(tc1) * 0.5
	end

	local tc2 = tc1 - tDiff
	c2.shape.Tick = function(o, dt)
		tc2 = tc2 + dt * speed
		o.Scale = 1.0 + math.sin(tc2) * 0.5
	end

	local tc3 = tc2 - tDiff
	c3.shape.Tick = function(o, dt)
		tc3 = tc3 + dt * speed
		o.Scale = 1.0 + math.sin(tc3) * 0.5
	end

	node._width = function(self)
		local w = self.label.Width + theme.padding * 2
		if w < minWidth then
			w = minWidth
		end

		return w
	end

	node._height = function(self)
		return self.label.Height + animationHeight + theme.padding * 3
	end

	node.refresh = function(self)
		self.label.object.MaxWidth = Screen.Width * 0.7
		self.label.pos =
			{ self.Width * 0.5 - self.label.Width * 0.5, self.Height - self.label.Height - theme.padding, 0 }

		c1.pos = {
			self.Width * 0.5 - c1.Width * 0.5 - animationCubeOffset,
			theme.padding + animationHeight * 0.5 - c1.Height * 0.5,
			0,
		}
		c2.pos = { self.Width * 0.5 - c1.Width * 0.5, theme.padding + animationHeight * 0.5 - c1.Height * 0.5, 0 }
		c3.pos = {
			self.Width * 0.5 - c1.Width * 0.5 + animationCubeOffset,
			theme.padding + animationHeight * 0.5 - c1.Height * 0.5,
			0,
		}

		c1.object.Position.Z = 20
		c2.object.Position.Z = 20
		c3.object.Position.Z = 20
	end

	local popup = modal:create(content, maxWidth, maxHeight, position, ui)

	popup.setText = function(self, text)
		label.Text = text
		self:refreshContent()
		node:refresh()
	end

	popup:setText(text)

	return popup
end

return loading
