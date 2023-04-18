
local colorPicker = {}

colorPicker.create = function(self, config)

	local uikit = require("uikit")
	local theme = require("uitheme").current

	local _config = { -- default config
		closeBtnColor = nil,
		closeBtnIcon = "❌",
		previewColorInCloseBtn = false,
		transparency = true,
		colorPreview = true,
		colorCode = true,
		-- number or function returning number
		maxWidth = 500,
		maxHeight = 300,
		extraPadding = false, -- adds padding all around components
	}
	if config ~= nil then
		if config.closeBtnColor ~= nil then _config.closeBtnColor = config.closeBtnColor end
		if config.closeBtnIcon ~= nil then _config.closeBtnIcon = config.closeBtnIcon end
		if config.previewColorInCloseBtn ~= nil then _config.previewColorInCloseBtn = config.previewColorInCloseBtn end
		if config.transparency ~= nil then _config.transparency = config.transparency end
		if config.colorPreview ~= nil then _config.colorPreview = config.colorPreview end
		if config.colorCode ~= nil then _config.colorCode = config.colorCode end
		if config.maxWidth ~= nil then _config.maxWidth = config.maxWidth end
		if config.maxHeight ~= nil then _config.maxHeight = config.maxHeight end
		if config.extraPadding ~= nil then _config.extraPadding = config.extraPadding end
	end
	config = _config

	local node = uikit:createNode()
	node.config = config

	local cursorModel = MutableShape()

	cursorModel:AddBlock(Color.Black,0,0,0)
	cursorModel:AddBlock(Color.Black,0,1,0)
	cursorModel:AddBlock(Color.Black,0,2,0)

	cursorModel:AddBlock(Color.Black,1,0,0)
	cursorModel:AddBlock(Color.White,1,1,0)
	cursorModel:AddBlock(Color.Black,1,2,0)

	cursorModel:AddBlock(Color.Black,2,1,0)

	local _hueSliderCursor = Shape(cursorModel)
	_hueSliderCursor.CollisionGroups = {}

	cursorModel:AddBlock(Color.Black,2,0,0)
	cursorModel:AddBlock(Color.Black,2,2,0)
	local _hsvCursor = Shape(cursorModel)
	_hsvCursor.CollisionGroups = {}	

	local hueSliderCursor = uikit:createShape(_hueSliderCursor, true)
	hueSliderCursor:setParent(node)
	hueSliderCursor.LocalPosition.Z = -550 -- remove this once uikit better manages layers

	local alphaSliderCursor
	if config.transparency then
		local _alphaSliderCursor = Shape(_hueSliderCursor)
		_alphaSliderCursor.CollisionGroups = {}

		alphaSliderCursor = uikit:createShape(_alphaSliderCursor, true)
		alphaSliderCursor:setParent(node)
		alphaSliderCursor.LocalPosition.Z = -550 -- remove this once uikit better manages layers
	end

	local hsvCursor = uikit:createShape(_hsvCursor, true)
	hsvCursor:setParent(node)
	hsvCursor.LocalPosition.Z = -550 -- remove this once uikit better manages layers

	node.currentAlpha = 255
	node.previousColor = nil
	node.currentColor = nil

	node.nbAlphaSteps = 6.0

	node.setMaxSize = function(self, w, h)
		self.config.maxWidth = w
		self.config.maxHeight = h
		self:_refresh()
	end

	-- callbacks
	node.didPickColor = nil -- function(self, color)
	node.didClose = nil

	node.close = function(self)
		self:setParent(nil)
		if self.didClose ~= nil then
			self:didClose()
		end
	end

	local bg = uikit:createFrame(Color(50,50,50,200))
	bg:setParent(node)
	node.background = bg
	
	local closeBtn = uikit:createButton(config.closeBtnIcon)
	if config.closeBtnColor then closeBtn:setColor(config.closeBtnColor, Color.White) end
	closeBtn:setParent(node)
	node.closeBtn = closeBtn
	closeBtn.onRelease = function(self)
		if node.onClose ~= nil then
			node.onClose()
		else
			node:close()
		end
	end

	local hexCodeBtn = uikit:createButton("#FFFFFF")
	if config.closeBtnColor then hexCodeBtn:setColor(config.closeBtnColor, Color.White) end
	-- hexCodeBtn:setParent(node) -- TODO: turn this back on / implement feature
	hexCodeBtn:hide()
	hexCodeBtn.onRelease = function(self)
		-- node:close()
	end

	node.width = function(self)
		return self.background.Width
	end

	node.height = function(self)
		return self.background.Height
	end

	local paletteShape = MutableShape()
	paletteShape.CollisionGroups = {}

	local h = 160 -- degrees
	node.paletteShapeSize = 11

	local c = Color(0,0,0)
	for s=0,(node.paletteShapeSize-1) do
		for v=0,(node.paletteShapeSize-1) do
			c.H = h
			c.S = s / 10.0
			c.V = v / 10.0
			local i = paletteShape.Palette:AddColor(c)
			paletteShape:AddBlock(c, s, v, 0)
			local b = paletteShape:GetBlock(s,v,0)
			b.PaletteIndex = i
		end
	end

	local uiPaletteShape = uikit:createShape(paletteShape, true)
	uiPaletteShape:setParent(node)
	uiPaletteShape.onReleasePrecise = function(_, shape, block)
		node:_setColor(block.Color)
		node:_refreshColor()
		node:_didPickColor()
	end

	local hueShape = MutableShape()
	hueShape.CollisionGroups = {}

	local c = Color(0,0,0)
	local nbHueSteps = 64 -- can't be more than 128
	for h=0,nbHueSteps-1 do
		c.H = h * (360.0 / (nbHueSteps-1))
		c.S = 1.0
		c.V = 1.0
		hueShape:AddBlock(c, 0, h, 0)
	end

	local uiHueShape = uikit:createShape(hueShape, true)
	uiHueShape:setParent(node)
	uiHueShape.onReleasePrecise = function(_, shape, block)
		local c = Color(block.Color)
		node.currentColor.Hue = c.Hue
		node:_refreshColor()
		node:_didPickColor()
	end

	local uiFinalShape
	if config.colorPreview then
		local finalShape = MutableShape()
		finalShape.CollisionGroups = {}
		for i=0,7 do
			for j=0,7 do
				finalShape:AddBlock((i+j) % 2 == 0 and Color.White or Color.Grey, i, j, 0)
			end
		end

		node.finalShape = finalShape
		uiFinalShape = uikit:createShape(finalShape, true)
		uiFinalShape:setParent(node)
	end

	local colorCode
	if config.colorCode then
		colorCode = uikit:createText("(255,255,255)", Color(255,255,255,200), "small")
		colorCode:setParent(node)
		node.colorCode = colorCode
	end

	local bgAlpha
	local bgAlphaColor
	local alpha
	if config.transparency then
		local nbAlphaSteps = node.nbAlphaSteps

		bgAlpha = uikit:createFrame(Color.White)
		bgAlpha:setParent(node)

		local bgAlphaShape = MutableShape()
		for i=0,63 do
			bgAlphaShape:AddBlock((math.floor(i / 4) + i) % 2 == 0 and Color.White or Color.Grey, i % 4, math.floor(i / 4), 0)
		end

		bgAlphaColor = uikit:createShape(bgAlphaShape, true)
		bgAlphaColor:setParent(bgAlpha)
		bgAlphaShape.CollisionGroups = {}

		local shapeAlpha = MutableShape()
		for i=1,nbAlphaSteps do
			local value = i / nbAlphaSteps
			local c = Color(1.0,1.0,1.0,value)
			shapeAlpha:AddBlock(c, 0, i-1, 0)
		end

		alpha = uikit:createShape(shapeAlpha, true)
		alpha:setParent(bgAlpha)
		alpha.onPressPrecise = function(_, shape, block)
			node.currentAlpha = shape.Palette[block.PaletteIndex].Color.A
			node:_refreshColor()
			node:_didPickColor()
		end

		bgAlphaColor.LocalPosition = Number3(theme.padding, theme.padding, 0)
		bgAlphaColor.LocalPosition.Z = -1

		alpha.LocalPosition = Number3(theme.padding, theme.padding, 0)
		alpha.LocalPosition.Z = bgAlphaColor.LocalPosition.Z - 1
	end

    node._setColor = function(self,color)
    	if color == nil then return end
    	local c = Color(color) -- temporary, to access HSV

		if self.currentColor == nil then self.currentColor = Color(255,255,255,255) end

		self.currentColor.Hue = c.Hue
		self.currentColor.Saturation = c.Saturation
		self.currentColor.Value = c.Value
	end

	node._refresh = function(self)

		local maxHeight
		if type(self.config.maxHeight) == "function" then
			maxHeight = self.config.maxHeight()
		else
			maxHeight = self.config.maxHeight
		end

		local maxWidth
		if type(self.config.maxWidth) == "function" then
			maxWidth = self.config.maxWidth()
		else
			maxWidth = self.config.maxWidth
		end

		local padding = theme.padding

		closeBtn.Width = nil
		local columnWidth = closeBtn.Width
		local bottomBarHeight = closeBtn.Height

		local minWidth = hexCodeBtn.Width + columnWidth + padding
		if config.extraPadding then
			minWidth = minWidth + padding * 2
		end
		if config.transparency then
			minWidth = minWidth + columnWidth + padding
		end

		if maxWidth < minWidth then maxWidth = minWidth end

		local minHeight = hexCodeBtn.Height + hexCodeBtn.Width + padding
		if config.extraPadding then
			minHeight = minHeight + padding * 2
		end
		local height = maxHeight
		if height < minHeight then height = minHeight end

		-- color area is a square
		local colorAreaSize = height - bottomBarHeight - padding
		if config.extraPadding then
			colorAreaSize = colorAreaSize - padding * 2
		end

		local width = colorAreaSize + columnWidth + padding
		if config.extraPadding then
			width = width + padding * 2
		end
		if config.transparency then
			width = width + columnWidth + padding
		end

		-- width too big, compute using that limit
		if width > maxWidth then 
			width = maxWidth
			colorAreaSize = width - columnWidth - padding
			if config.extraPadding then
				colorAreaSize = colorAreaSize - padding * 2
			end
			if config.transparency then
				colorAreaSize = colorAreaSize - columnWidth - padding
			end
			height = hexCodeBtn.Height + colorAreaSize + padding
			if config.extraPadding then
				height = height + padding * 2
			end
		end

		bg.Width = width
		bg.Height = height

		if config.colorPreview then
			closeBtn.pos = Number3(bg.Width - columnWidth, 0, 0)
			if config.extraPadding then
				closeBtn.pos = closeBtn.pos + {-padding, padding, 0}
			end
		else
			closeBtn.pos = Number3(0, 0, 0)
			closeBtn.Width = width
			if config.extraPadding then
				closeBtn.pos = closeBtn.pos + {padding, padding, 0}
				closeBtn.Width = closeBtn.Width - padding * 2
			end
		end

		if config.colorPreview then
			uiFinalShape.Width = bg.Width - closeBtn.Width - padding
			if config.extraPadding then
				uiFinalShape.Width = uiFinalShape.Width - padding * 2
			end
			uiFinalShape.Height = bottomBarHeight
			uiFinalShape.LocalPosition = Number3(padding, padding, 0)
		end

		if colorCode then
			colorCode.LocalPosition = {padding * 2, padding * 2, 0}
		end

		hexCodeBtn.LocalPosition = {padding, padding, 0}

		uiPaletteShape.pos = Number3(0, bg.Height - colorAreaSize, 0)
		if config.extraPadding then
			uiPaletteShape.pos = uiPaletteShape.pos + {padding, -padding, 0}
		end

		uiPaletteShape.Width = colorAreaSize
		uiPaletteShape.Height = colorAreaSize

		uiHueShape.Width = columnWidth
		uiHueShape.Height = colorAreaSize
		uiHueShape.pos = Number3(colorAreaSize + padding,
								bottomBarHeight + padding,
									0)
		if config.extraPadding then
			uiHueShape.pos = uiHueShape.pos + {padding, padding, 0}
		end

		local hue = 0.0 -- 0 to 360
		if self.currentColor ~= nil then
			hue = self.currentColor.Hue
		end

		hueSliderCursor.pos = uiHueShape.pos - {0, hueSliderCursor.Height * 0.5 , 0} + {0, uiHueShape.Height * hue / 360.0, 0}

		local hue = 0.0 -- 0 to 360
		local saturation = 0.0 -- 0 to 1
		local value = 0.0 -- 0 to 1
		if self.currentColor ~= nil then 
			hue = self.currentColor.Hue
			saturation = self.currentColor.Saturation
			value = self.currentColor.Value
		end
		local sStep = math.floor(saturation * self.paletteShapeSize) if sStep >= self.paletteShapeSize then sStep = self.paletteShapeSize - 1 end
		local vStep = math.floor(value * self.paletteShapeSize) if vStep >= self.paletteShapeSize then vStep = self.paletteShapeSize - 1 end
		local svStepSize = uiPaletteShape.Width / self.paletteShapeSize
		hueSliderCursor.pos = uiHueShape.pos - {0, hueSliderCursor.Height * 0.5 , 0} + {0, uiHueShape.Height * hue / 360.0, 0}
		hsvCursor.pos = uiPaletteShape.pos - {hsvCursor.Width * 0.5, hsvCursor.Height * 0.5 , 0} + 
		{svStepSize * (sStep + 0.5), svStepSize * (vStep + 0.5), 0}

		if config.transparency then
			bgAlpha.Width = columnWidth
			bgAlpha.Height = colorAreaSize
			bgAlpha.LocalPosition = Number3(colorAreaSize + columnWidth + padding,
											bottomBarHeight + padding * 2, 0)

			if config.extraPadding then
				bgAlpha.LocalPosition.X = bgAlpha.LocalPosition.X + padding * 2
			end

			local r = self.currentAlpha / 255
			local step = math.ceil(r * self.nbAlphaSteps) - 1
			local stepHeight = bgAlpha.Height / self.nbAlphaSteps
			alphaSliderCursor.LocalPosition = bgAlpha.LocalPosition - {0, alphaSliderCursor.Height * 0.5 , 0} + {0, stepHeight * (step + 0.5), 0}

			bgAlphaColor.Width = bgAlpha.Width - 2 * padding
			bgAlphaColor.Height = bgAlpha.Height - 2 * padding
			
			alpha.Width = bgAlphaColor.Width
			alpha.Height = bgAlphaColor.Height		
		end

		if self.didRefresh ~= nil then
			self:didRefresh()
		end
	end	

	node._refreshColor = function(self)

		local refreshHue = false

		if self.currentColor ~= nil then
			if self.previousColor == nil then
				refreshHue = true
				self.previousColor = Color(255,255,255,255)
			elseif self.previousColor.Hue ~= self.currentColor.Hue then
				refreshHue = true
			end
		end

		if refreshHue then
			local c = Color(0,0,0)
			local i = 1
			for s=0,(self.paletteShapeSize-1) do
				for v=0,(self.paletteShapeSize-1) do
					c.H = self.currentColor.H
					c.S = s / 10.0
					c.V = v / 10.0
					paletteShape.Palette[i].Color = c
					i = i + 1
				end
			end
			self.previousColor.Hue = self.currentColor.Hue
			self.previousColor.Saturation = self.currentColor.Saturation
			self.previousColor.Value = self.currentColor.Value
		end

		local alpha = self.currentAlpha / 255
		local iAlpha = 1.0 - alpha

		local c1 = Color(Color.White)

		c1.R = math.floor((c1.R * iAlpha) + (self.currentColor.R * alpha))
		c1.G = math.floor((c1.G * iAlpha) + (self.currentColor.G * alpha))
		c1.B = math.floor((c1.B * iAlpha) + (self.currentColor.B * alpha))

		local c2 = Color(Color.Grey)
		c2.R = math.floor(c2.R * iAlpha + self.currentColor.R * alpha)
		c2.G = math.floor(c2.G * iAlpha + self.currentColor.G * alpha)
		c2.B = math.floor(c2.B * iAlpha + self.currentColor.B * alpha)

		if self.finalShape then
			self.finalShape.Palette[1].Color = c1
			self.finalShape.Palette[2].Color = c2
		end

		if self.config.previewColorInCloseBtn then
			self.closeBtn:setColor(c1)
		end

		if self.colorCode then
			self.colorCode.Text = "(" .. math.floor(self.currentColor.R) .. "," .. math.floor(self.currentColor.H) .. "," .. math.floor(self.currentColor.B) .. ")"
		end

		if alphaSliderCursor then
			local r = self.currentAlpha / 255
			local step = math.ceil(r * self.nbAlphaSteps) - 1
			local stepHeight = bgAlpha.Height / self.nbAlphaSteps
			alphaSliderCursor.LocalPosition = bgAlpha.LocalPosition - {0, alphaSliderCursor.Height * 0.5 , 0} + {0, stepHeight * (step + 0.5), 0}
		end

		local hue = 0.0 -- 0 to 360
		local saturation = 0.0 -- 0 to 1
		local value = 0.0 -- 0 to 1
		if self.currentColor ~= nil then 
			hue = self.currentColor.Hue
			saturation = self.currentColor.Saturation
			value = self.currentColor.Value
		end
		local sStep = math.floor(saturation * self.paletteShapeSize) if sStep >= self.paletteShapeSize then sStep = self.paletteShapeSize - 1 end
		local vStep = math.floor(value * self.paletteShapeSize) if vStep >= self.paletteShapeSize then vStep = self.paletteShapeSize - 1 end
		local svStepSize = uiPaletteShape.Width / self.paletteShapeSize
		hueSliderCursor.LocalPosition = uiHueShape.LocalPosition - {0, hueSliderCursor.Height * 0.5 , 0} + {0, uiHueShape.Height * hue / 360.0, 0}
		hsvCursor.LocalPosition = uiPaletteShape.LocalPosition - {hsvCursor.Width * 0.5, hsvCursor.Height * 0.5 , 0} + 
		{svStepSize * (sStep + 0.5), svStepSize * (vStep + 0.5), 0}
	end

	node._didPickColor = function(self)
		if node.didPickColor then
			local c = Color(self.currentColor)
			c.Alpha = self.currentAlpha
			node:didPickColor(c)
		end
	end

	node.setColor = function(self, color)
		self:_setColor(color)
		self:_refreshColor()
	end

	node:_refresh()
	
	return node
end

return colorPicker