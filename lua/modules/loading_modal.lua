local loading = {}

loading.create = function(self, text)
		
	local uikit = require("uikit")
	local modal = require("modal")
	local theme = require("uitheme").current
	local ease = require("ease")

	local minWidth = 200
	local animationHeight = 20
	local animationCubeOffset = 16

	local content = modal:createContent()
	content.closeButton = false

	content.idealReducedContentSize = function(content, width, height)
		content:refresh()
		return Number2(content.Width,content.Height)
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
			modal.LocalPosition = p - {0,100,0}
			modal.updatedPosition = true
			ease:outElastic(modal, 0.3).LocalPosition = p
		else
			modal.LocalPosition = p
		end
	end

	local node = uikit:createFrame(Color(0,0,0,0))
	content.node = node

	local popup = modal:create(content, maxWidth, maxHeight, position)

	local label = uikit:createText(text, Color.White)
	label:setParent(node)
	node.label = label

	local cube = MutableShape()
	cube:AddBlock(Color.White,0,0,0)
	cube.Pivot = {0.5, 0.5, 0.5}

	local c1 = uikit:createShape(Shape(cube))
	c1:setParent(node)

	local c2 = uikit:createShape(Shape(cube))
	c2:setParent(node)

	local c3 = uikit:createShape(Shape(cube))
	c3:setParent(node)

	local speed = 6
	local tDiff = 0.5
	local t = 1.5
	c1.shape.Tick = function(o, dt)
		t = t + dt * speed
		o.Scale = 1.0 + math.sin(t) * 0.5
	end

	local t = t - tDiff
	c2.shape.Tick = function(o, dt)
		t = t + dt * speed
		o.Scale = 1.0 + math.sin(t) * 0.5
	end

	local t = t - tDiff
	c3.shape.Tick = function(o, dt)
		t = t + dt * speed
		o.Scale = 1.0 + math.sin(t) * 0.5
	end


	node._width = function(self)
		local w = self.label.Width + theme.padding * 2
		if w < minWidth then w = minWidth end

		return w
	end

	node._height = function(self)
		return self.label.Height + animationHeight + theme.padding * 3
	end

	node.refresh = function(self)
		self.label.object.MaxWidth = Screen.Width * 0.7
		self.label.pos = { self.Width * 0.5 - self.label.Width * 0.5, self.Height - self.label.Height - theme.padding, 0 }

		c1.pos = { self.Width * 0.5 - c1.Width * 0.5 - animationCubeOffset, theme.padding + animationHeight * 0.5 - c1.Height * 0.5, 0 }
		c2.pos = { self.Width * 0.5 - c1.Width * 0.5, theme.padding + animationHeight * 0.5 - c1.Height * 0.5, 0 }
		c3.pos = { self.Width * 0.5 - c1.Width * 0.5 + animationCubeOffset, theme.padding + animationHeight * 0.5 - c1.Height * 0.5, 0 }
	end

	popup.bounce = function(self)
		position(popup, true)
	end

	popup.setText = function(self, text)
		label.Text = text
		node:refresh()
		self:refresh()
		position(popup, false)
	end

	return popup
end

return loading
