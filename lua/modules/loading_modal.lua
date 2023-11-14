loading = {}

loading.create = function(_, text, config)
	local modal = require("modal")
	local theme = require("uitheme").current
	local ease = require("ease")

	-- default config
	local _config = {
		uikit = require("uikit"), -- allows to provide specific instance of uikit
	}

	if config then
		for k, v in pairs(_config) do
			if type(config[k]) == type(v) then
				_config[k] = config[k]
			end
		end
	end

	local ui = _config.uikit

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

	local position = function(modal, forceBounce)
		local p = Number3(Screen.Width * 0.5 - modal.Width * 0.5, Screen.Height * 0.5 - modal.Height * 0.5, 0)

		if not modal.updatedPosition or forceBounce then
			modal.LocalPosition = p - { 0, 100, 0 }
			modal.updatedPosition = true
			ease:outElastic(modal, 0.3).LocalPosition = p
		else
			ease:cancel(modal)
			modal.LocalPosition = p
		end
	end

	local node = ui:createFrame(Color(0, 0, 0, 0))
	content.node = node

	local popup = modal:create(content, maxWidth, maxHeight, position, ui)

	local label = ui:createText(text, Color.White)
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

	popup.bounce = function(_)
		position(popup, true)
	end

	popup.setText = function(self, text)
		label.Text = text
		self:refreshContent()
		node:refresh()
	end

	node:refresh()

	return popup
end

return loading
