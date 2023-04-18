--[[
UI module used to implement default user interfaces in Cubzh. 

//!\\ Still a work in progress. Your scripts may break in the future if you use it now. 

]]--

local ui = {
	-- CONSTANTS
	kUILayer = 2,
	kUIFar = 1000,
	kLayerStep = -0.1, -- children offset
	kUICollisionGroup = 7,
	kShapeScale = 5,

	kPadding = 4,
	kButtonPadding = 4,
	kButtonBorder = 3,

	State = {
		Idle = 0,
		Pressed = 1,
		Focused = 2,
		Disabled = 3,
		Selected = 4,
	},

	-- Note: NodeType will be removed
	NodeType = {
		None = 0,
		Frame = 1,
		Button = 2,
	},

	------------
	-- VARS
	------------

	-- Top level object, containing all UI nodes
	rootFrame = nil,

	--
	_rootChildren = {},

	-- A list of Shapes with onPress callback set
	-- Meaning we want to know if the pointer event ray
	-- touches them with block precision.
	-- indexed by node._id
	-- NOTE: shapes with onRelease callbacks are also stored here
	-- because onPress event needs to be considered first.
	_onPressShapes = {},

	-- Orthographic camera, to render UI
	_camera = nil,

	-- Node with focus (not all nodes are focusable)
	_focused = nil,

	 -- Node that's currently being pressed
	_pressed = nil,
	_pressedIsPrecise = false,

	-- keeping a reference on all text items,
	-- to update fontsize when needed
	_texts = {},

	-- keeping current font size (based on screen size & density)
	_currentFontSize = Text.FontSizeDefault,
	_currentFontSizeBig = Text.FontSizeBig,
	_currentFontSizeSmall = Text.FontSizeSmall,

	-- each Text gets a unique ID
	_nodeID = 1,

	--
	_initialized = false,

	--
	_cleanup = require("cleanup"),
	_hierarchyActions = require("hierarchyactions"),
	_sfx = require("sfx"),
}

-- install listeners to adapt ui considering
-- virtual keyboard presence.
ui.keyboardShownListener = LocalEvent:Listen(LocalEvent.Name.VirtualKeyboardShown,
												function(keyboardHeight)
													if ui._focused ~= nil then
														local theme = require("uitheme").current
														local rootPos = ui._focused.pos
														local parent = ui._focused.parent
														while parent ~= nil do
															rootPos = rootPos + parent.pos
															parent = parent.parent
														end
														if rootPos.Y - theme.paddingBig < keyboardHeight then
															local diff = keyboardHeight - (rootPos.Y - theme.paddingBig)

															local ease = require("ease")
															ease:cancel(ui.rootFrame)
															ease:inOutSine(ui.rootFrame,0.2).LocalPosition = {
																-Screen.Width * 0.5,
																diff - Screen.Height * 0.5,
																ui.kUIFar
															}
														end
													end
												end)

ui.keyboardHiddenListener = LocalEvent:Listen(LocalEvent.Name.VirtualKeyboardHidden,
												function()
													if ui._focused ~= nil then
														if ui._focused._unfocus ~= nil then
															ui._focused:_unfocus()
														end
														ui._focused = nil
													end
													local ease = require("ease")
													ease:cancel(ui.rootFrame)
													ease:inOutSine(ui.rootFrame,0.2).LocalPosition = {
														-Screen.Width * 0.5,
														-Screen.Height * 0.5,
														ui.kUIFar
													}
												end)

ui.fitScreen = function(self)

	if self._camera == nil then return end
	self._camera.Width = Screen.Width
	self._camera.Height = Screen.Height
	if self.rootFrame ~= nil then
		self.rootFrame.LocalPosition = { -Screen.Width * 0.5, -Screen.Height * 0.5, self.kUIFar }
	end

	if self._currentFontSize ~= Text.FontSizeDefault or 
		self._currentFontSizeBig ~= Text.FontSizeBig or
		self._currentFontSizeSmall ~= Text.FontSizeSmall then

		self._currentFontSize = Text.FontSizeDefault
		self._currentFontSizeBig = Text.FontSizeBig
		self._currentFontSizeSmall = Text.FontSizeSmall

		for _, node in pairs(self._texts) do
			
			if node.object and node.object.FontSize then
				if node.fontsize == nil or node.fontsize == "default" then
					node.object.FontSize = self._currentFontSize
				elseif node.fontsize == "big" then
					node.object.FontSize = self._currentFontSizeBig
				elseif node.fontsize == "small" then
					node.object.FontSize = self._currentFontSizeSmall
				end
			end

			if node.parent.contentDidResizeWrapper ~= nil then node.parent:contentDidResizeWrapper() end
		end
	end

	for nodeID, child in pairs(self._rootChildren) do
		if child.parentDidResize ~= nil then
			child:parentDidResize()
		end
	end
end

ui.init = function(self)
	if self._initialized then return end
	self._initialized = true

	Pointer:Show()
	UI.Crosshair = false

	local camera = Camera()
	camera:SetParent(World)
	camera.On = true
	camera.Far = self.kUIFar
	camera.Layers = self.kUILayer
	camera.Projection = ProjectionMode.Orthographic
	camera.Width = Screen.Width
	camera.Height = Screen.Height
	self._camera = camera

	self.rootFrame = Object()
	self.rootFrame:SetParent(camera)
	self.rootFrame.LocalPosition = { -Screen.Width * 0.5, -Screen.Height * 0.5, self.kUIFar }
end

-- returns true if the UI catches the event, false otherwise
ui.pointerDown = function(self, pointerEvent)
	local origin = Number3((pointerEvent.X - 0.5) * Screen.Width, (pointerEvent.Y - 0.5) * Screen.Height, 0)
	local direction = { 0, 0, 1 }

	if self._focused ~= nil then
		if self._focused._unfocus ~= nil then
			self._focused:_unfocus()
		end
		self._focused = nil
	end

	for _,node in pairs(self._onPressShapes) do
		local impact = Ray(origin, direction):Cast(node.shape)
		if impact ~= nil and impact.Block ~= nil then
			if node._onPressPrecise or node._onReleasePrecise then
				self._pressed = node
				self._pressedIsPrecise = true
				if node._onPressPrecise then
					node:_onPressPrecise(node.shape, impact.Block)
				end
				return true
			end
		end
	end

	local impact = Ray(origin, direction):Cast({ self.kUICollisionGroup })
	if impact.Shape._node._onPress or impact.Shape._node._onRelease then
		self._pressed = impact.Shape._node
		self._pressedIsPrecise = false
		if impact.Shape._node._onPress then
			impact.Shape._node:_onPress()
		end
		if self._pressed.config.sound and self._pressed.config.sound ~= "" then
			self._sfx(self._pressed.config.sound, {Spatialized = false})
		end
		return true
	end

	return false
end

ui.pointerUp = function(self, pointerEvent)
	local pressed = self._pressed
	if pressed then
		local origin = Number3((pointerEvent.X - 0.5) * Screen.Width, (pointerEvent.Y - 0.5) * Screen.Height, 0)
		local direction = { 0, 0, 1 }

		local releasedOnTarget = false

		if self._pressedIsPrecise then
			local impact = Ray(origin, direction):Cast(pressed.shape)
			if impact ~= nil and impact.Block ~= nil then
				if pressed._onReleasePrecise then
					pressed:_onReleasePrecise(pressed.shape, impact.Block)
					self._pressed = nil
					return true
				end
			end
		else
			local impact = Ray(origin, direction):Cast({ self.kUICollisionGroup })
			if impact.Shape._node == pressed and impact.Shape._node._onRelease then
				-- print("_onRelease")
				pressed:_onRelease()
				self._pressed = nil
				return true
			end
		end

		if pressed._onCancel then
			-- print("_onCancel")
			pressed:_onCancel()
		end
		self._pressed = nil
		return true
	end
	self._pressed = nil
	return false
end

ui.pointerDrag = function(self, pointerEvent)
	local pressed = self._pressed
	if pressed._onDrag then
		pressed:_onDrag(pointerEvent)
	end
end

ui._setupUIShape = function(self, shape, collides)
	self._hierarchyActions:applyToDescendants(shape,  { includeRoot = true }, function(s)
		s.Layers = ui.kUILayer
		s.IsUnlit = true

		s.CollidesWithGroups = {}
		s.CollisionGroups = {}
		s.Physics = PhysicsMode.Disabled
	end)

	if collides then
		shape.Physics = PhysicsMode.Trigger
		shape.CollisionGroups = {self.kUICollisionGroup}
		shape.CollisionBox = Box({ 0, 0, 0 }, { shape.Width, shape.Height, 1 })
	end
end

ui.createNode = function(self)
	local node = self:_nodeCreate()
	node.object = Object()
	node.object.LocalPosition = {0, 0, 0}

	node:setParent(self.rootFrame)
	return node
end

ui.createFrame = function(self, color)
	if color ~= nil and type(color) ~= "Color" then
		error("ui:createFrame(color) expects a color parameter", 2)
	end

	color = color or Color(0,0,0,0) -- default transparent frame
	local node = self:_nodeCreate()
	node.type = self.NodeType.Frame
	node.object = Object()

	local background = MutableShape()
	background:AddBlock(color,0,0,0)
	self:_setupUIShape(background)
	node.object:AddChild(background)
	background._node = node
	node.background = background

	node._color = function(self)
		return self.background.Palette[1].Color
	end
	
	node._setColor = function(self, color)
		self.background.Palette[1].Color = color
	end

	node._width = function(self) return self.background.LocalScale.X end
	node._height = function(self) return self.background.LocalScale.Y end
	node._depth = function(self) return self.background.LocalScale.Z end

	node._setWidth = function(self, v) self.background.LocalScale.X = v end
	node._setHeight = function(self, v) self.background.LocalScale.Y = v end

	node.object.LocalPosition = {0, 0, 0}

	node:setParent(ui.rootFrame)
	return node
end

ui._refreshShapeNode = function(node)

	if node.shape == nil then return end

	if node.shape.Width == 0 then 
		if node.shape:GetParent() ~= nil then
			node._aabb = nil
			node._aabbWidth = 0
			node._aabbHeight = 0
			node._aabbDepth = 0
			node._diameter = 0
			node.shape:RemoveFromParent()
			return
		end
	else
		if node.shape:GetParent() == nil then
			node.pivot:AddChild(node.shape)
			node.shape.LocalPosition = {0,0,0}
		end
	end

	local backupScale = node.object.LocalScale:Copy()
	node.object.LocalScale = 1
	node.shape.LocalPosition = {0,0,0}
	node.pivot.LocalPosition = {0,0,0}

	if not node._config.doNotFlip then 
		node.pivot.LocalRotation = {0, math.pi, 0} -- shape's front facing camera
	else
		node.pivot.LocalRotation = {0, 0, 0} -- shape's back facing camera
	end

	-- shape.LocalScale = self.kShapeScale
	-- the shape scale is always 1
	-- in the context of a shape node, we always apply scale to the parent object
	node.shape.LocalScale = 1

	-- NOTE: Using AABB in pivot space to infer size & placement.
	-- We may also need AABB in object space in some cases.
	node._aabb = ui._computeDescendantsBoundingBox(node.pivot)

	node._aabbWidth = node._aabb.Max.X - node._aabb.Min.X
	node._aabbHeight = node._aabb.Max.Y - node._aabb.Min.Y
	node._aabbDepth = node._aabb.Max.Z - node._aabb.Min.Z
	
	if node._config.spherized then
		node._diameter = math.sqrt(node._aabbWidth ^ 2 + node._aabbHeight ^ 2 + node._aabbDepth ^ 2)
	end

	-- center Shape within pivot
	-- considering Shape's pivot but not modifying it
	-- It could be important for shape's children placement.

	node.shape.LocalPosition = -node._aabb.Center

	if node._config.spherized then
		local radius = node.Width * 0.5
		node.pivot.LocalPosition = {radius, radius, radius}
	else
		node.pivot.LocalPosition = Number3(node.Width * 0.5, node.Height * 0.5, node.Depth * 0.5)
	end

	node.object.LocalScale = backupScale
end

-- NOTES (needs proper documentation)
-- When the shapeNode needs to be rotated, prefer node.size accessor
-- Otherwise and when it's required to rely on precize (sharp edge) width & height, use node.width * node.height
-- But the item can't be rotated when doing to. 
-- It could be improved at some point, computing onscreen bounding box when rotating the item.
--[[ 
-- Returns a UI node displaying a regular Shape or MutableShape.
-- @param shape {Shape,MutableShape} -
-- @param config {table} - 
]]
ui.createShape = function(self, shape, config)

	if shape == nil or (type(shape) ~= "Shape" and type(shape) ~= "MutableShape") then 
		error("ui:createShape(shape) expects a non-nil Shape or MutableShape", 2)
	end

	local node = ui:_nodeCreate()

	node._config = {
		spherized = false,
		doNotFlip = false,
	}

	if config ~= nil then
		if type(config) == "boolean" then
			-- legacy, `config` paramameter used to be `doNotFlip`
			node._config.doNotFlip = config
		else
			if config.spherized ~= nil then node._config.spherized = config.spherized end
			if config.doNotFlip ~= nil then node._config.doNotFlip = config.doNotFlip end
		end
	end

	node.object = Object()
	node.object.LocalScale = ui.kShapeScale

	node.pivot = Object()

	node.object:AddChild(node.pivot)

	node.refresh = ui._refreshShapeNode

	-- getters

	node._width = function(self)
		if node._config.spherized then
			return self._diameter * self.object.LocalScale.X
		else
			return self._aabbWidth * self.object.LocalScale.X
		end
	end

	node._height = function(self)
		if node._config.spherized then
			return self._diameter * self.object.LocalScale.X
		else
			return self._aabbHeight * self.object.LocalScale.Y
		end
	end

	node._depth = function(self)
		if node._config.spherized then
			return self._diameter * self.object.LocalScale.X
		else
			return self._aabbDepth * self.object.LocalScale.Z
		end
	end

	-- setters

	node._setWidth = function(self, newWidth)
		if node._config.spherized then
			if self._diameter == 0 then return end
			self.object.LocalScale = newWidth / self._diameter
		else
			if self._aabbWidth == 0 then return end
			self.object.LocalScale.X = newWidth / self._aabbWidth
		end
	end

	node._setHeight = function(self, newHeight)
		if node._config.spherized then
			if self._diameter == 0 then return end
			self.object.LocalScale = newHeight / self._diameter
		else
			if self._aabbHeight == 0 then return end
			self.object.LocalScale.Y = newHeight / self._aabbHeight
		end
	end

	node._setDepth = function(self, newDepth)
		if node._config.spherized then
			if self._diameter == 0 then return end
			self.object.LocalScale = newDepth / self._diameter
		else
			if self._aabbDepth == 0 then return end
			self.object.LocalScale.Z = newDepth / self._aabbDepth
		end
	end

	node.setShape = function(self, shape, doNotRefresh)
		local w = nil
		local h = nil

		if self.shape ~= nil then
			w = self.Width
			h = self.Height
			self.shape:RemoveFromParent()
			self.shape._node = nil
			self.shape = nil
		end

		ui:_setupUIShape(shape)
		self.shape = shape
		shape._node = self

		if not doNotrefresh == true then
			self:refresh()
			if w ~= nil then self.Width = w end
			if h ~= nil then self.Height = h end
		end
	end	

	node:setShape(shape, true)

	node:refresh()

	node:setParent(self.rootFrame)
	return node
end

ui.createText = function(self, str, color, size) -- "default" (default), "small", "big"

	if str == nil then
		error("ui:createText(string, <color>, <align>) expects a non-nil string", 2)
	end

	local node = ui:_nodeCreate()
	self._texts[node._id] = node

	node.fontsize = size

	node._text = function(self)
		return self.object.Text
	end

	node._setText = function(self, str)
		if self.object then
			self.object.Text = str
		end
	end

	node._color = function(self)
		return self.object.Color
	end

	node._setColor = function(self, color)
		self.object.Color = color
	end

	local t = Text()
	t.Anchor = {0,0}
	-- Using Screen text always displays it on top of everything
	-- it's not good, but sizes aren't right in World.
	-- Let's fix this when we get time.
	t.Type = TextType.Screen
	t.Layers = self.kUILayer
	t.Text = str
	t.Padding = 0
	t.Color = color or Color(0,0,0,255)
	t.BackgroundColor = Color(0,0,0,0)
	t.MaxDistance = self._camera.Far + 100

	if node.fontsize == nil or node.fontsize == "default" then
		t.FontSize = self._currentFontSize
	elseif node.fontsize == "big" then
		t.FontSize = self._currentFontSizeBig
	elseif node.fontsize == "small" then 
		t.FontSize = self._currentFontSizeSmall
	end

	t.IsUnlit = true
	t.Physics = PhysicsMode.Disabled
	t.CollisionGroups = {}
	t.CollidesWithGroups = {}
	t.LocalPosition = {0, 0, 0}

	node.object = t

	node:setParent(self.rootFrame)
	return node
end

-- ui:createTextInput(<string>, <placeholder>, <size>)
ui.createTextInput = function(self, str, placeholder, size) -- "default" (default), "small", "big"

	local theme = require("uitheme").current

	local node = self:_nodeCreate()

	node.onTextChange = function(self) end

	node.onEnter = function(self) end

	node.disabled = false

	node._refresh = self._textInputRefresh

	node.state = self.State.Idle
	node.object = Object()

	node.border = self:createFrame()
	node.border:setParent(node)

	node.background = self:createFrame()
	node.background:setParent(node)
	node.background.pos = {theme.textInputBorderSize, theme.textInputBorderSize, 0}

	node.placeholder = ui:createText(placeholder or "", Color.White, size) -- color replaced later on
	node.placeholder:setParent(node)

	node.string = ui:createText(str or "", Color.White, size) -- color replaced later on
	node.string:setParent(node)

	node.cursor = self:createFrame(Color.White)
	node.cursor.Width = theme.textInputCursorWidth
	node.cursor:setParent(node)

	node._width = function(self) return self.border.Width end
	node._height = function(self) return self.border.Height end
	node._depth = function(self) return self.border.Depth end

	node._setWidth = function(self, newWidth)
		self.border.Width = newWidth
		self.background.Width = newWidth - theme.textInputBorderSize * 2
	end

	node.Width = theme.textInputDefaultWidth

	node._setHeight = function(self, newHeight)
		-- self.border.Height = newHeight
		-- self.background.Height = newHeight - theme.textInputBorderSize * 2
	end

	node._text = function(self)
		return self.string.Text
	end

	node._setText = function(self, str)
		self.string.Text = str
		if self.onTextChange then
			self:onTextChange()
		end
	end

	node._color = function(self)
		return self.colors[1]
	end

	node._setOnRelease = function(self, callback)
		local activeArea = self.border
		if callback == nil and self._onPress == nil then
			activeArea.Physics = PhysicsMode.Disabled
			activeArea.CollisionGroups = {}
			self._onRelease = nil
		elseif v ~= nil then
			activeArea.Physics = PhysicsMode.Trigger
			activeArea.CollisionGroups = {ui.kUICollisionGroup}
			activeArea.CollisionBox = Box({ 0, 0, 0 }, { activeArea.Width, activeArea.Height, 1 })
			self._onRelease = function()
				if v ~= nil then v() end
			end
		end
	end

	node.enable = function(self)
		if self.disabled == false then return end
		self.disabled = false
		ui:_textInputRefreshColor(self)
	end

	node.disable = function(self)
		if self.disabled then return end
		self.disabled = true
		ui:_textInputRefreshColor(self)
	end

	node.Width = 200

	node.setColor = function(self, background, text, placeholder, doNotrefresh)
		if background ~= nil then
			node.colors = { Color(background), Color(background)}
			node.colors[2]:ApplyBrightnessDiff(theme.textInputBorderBrightnessDiff)
		end
		if text ~= nil then
			node.textColor = Color(text)
		end
		if placeholder ~= nil then
			node.placeholderColor = Color(placeholder)
		end
		if not doNotrefresh then ui:_textInputRefreshColor(self) end
	end

	node.setColorPressed = function(self, background, text, placeholder, doNotrefresh)
		if background ~= nil then
			node.colorsPressed = { Color(background), Color(background) }
			node.colorsPressed[2]:ApplyBrightnessDiff(theme.textInputBorderBrightnessDiff)
		end
		if text ~= nil then
			node.textColorPressed = Color(text)
		end
		if placeholder ~= nil then
			node.placeholderColorPressed = Color(placeholder)
		end
		if not doNotrefresh then ui:_textInputRefreshColor(self) end
	end

	node.setColorFocused = function(self, background, text, placeholder, doNotrefresh)
		if background ~= nil then
			node.colorsFocused = { Color(background), Color(background) }
			node.colorsFocused[2]:ApplyBrightnessDiff(theme.textInputBorderBrightnessDiff)
		end
		if text ~= nil then
			node.textColorFocused = Color(text)
		end
		if placeholder ~= nil then
			node.placeholderColorFocused = Color(placeholder)
		end
		if not doNotrefresh then ui:_textInputRefreshColor(self) end
	end

	node.setColorDisabled = function(self, background, text, placeholder, doNotrefresh)
		if background ~= nil then
			node.colorsDisabled = { Color(background), Color(background) }
			node.colorsDisabled[2]:ApplyBrightnessDiff(theme.textInputBorderBrightnessDiff)
		end
		if text ~= nil then
			node.textColorDisabled = Color(text)
		end
		if placeholder ~= nil then
			node.placeholderColorDisabled = Color(placeholder)
		end
		if not doNotrefresh then ui:_textInputRefreshColor(self) end
	end

	node:setColor(
					theme.textInputBackgroundColor,
					theme.textInputTextColor,
					theme.textInputPlaceholderColor,
					true
				)
	node:setColorPressed(
							theme.textInputBackgroundColorPressed,
							theme.textInputTextColorPressed,
							theme.textInputPlaceholderColorPressed,
							true
						)
	node:setColorFocused(
							theme.textInputBackgroundColorFocused,
							theme.textInputTextColorFocused,
							theme.textInputPlaceholderColorFocused,
							true
						)
	node:setColorDisabled(
							theme.textInputBackgroundColorDisabled,
							theme.textInputTextColorDisabled,
							theme.textInputPlaceholderColorDisabled,
							true
						)

	node:_refresh()
	ui:_textInputRefreshColor(node) -- apply initial colors

	node.contentDidResizeSystem = function(self)
		if self._refresh then self:_refresh() end
	end

	node.border.onPress = function()
		if node.disabled == true then return end
		node.state = self.State.Pressed
		ui:_textInputRefreshColor(node)
	end

	node.border.onCancel = function()
		if node.disabled == true then return end
		node.state = self.State.Idle
		ui:_textInputRefreshColor(node)
	end

	node.border.onRelease = function() 
		if node.disabled == true then return end
		node:focus()
	end

	node.onFocus = nil
	node.onFocusLost = nil

	-- function to delete last UTF8 char
	local deleteLastCharacter = function(str)
		return(str:gsub("[%z\1-\127\194-\244][\128-\191]*$", ""))
	end

	node.focus = function(self)
		if self.state == ui.State.Focused then return end
		self.state = ui.State.Focused
		ui._focused = self
		
		ui:_textInputRefreshColor(self)
		self:_refresh()

		Client:ShowVirtualKeyboard()
		self.keyboardListener = LocalEvent:Listen(
												LocalEvent.Name.KeyboardInput,
												function(char, keycode, modifiers, down)
													if down == false then return end
													-- print("char:", char, "key:", keycode, "mod:", modifiers)
													-- we need an enum for key codes (value could change)
													if keycode == 5 then
														local str = self.string.Text
														if #str > 0 then
															str = deleteLastCharacter(str)
															self.string.Text = str
														end
													elseif char ~= "" then
														self.string.Text = self.string.Text .. char
													end
													self:_refresh()

													ui._sfx("keydown_" .. math.random(1,4), {Spatialized = false})

													if self.onTextChange then 
														self:onTextChange()
													end

													return true -- capture event
												end,
												{ topPriority = true })

		self.dt = 0
		self.cursor.shown = true
		self.object.Tick = function(o, dt)
			self.dt = self.dt + dt
			if self.dt >= theme.textInputCursorBlinkTime then
				self.dt = self.dt % 0.3
				self.cursor.shown = not self.cursor.shown
				local backup = self.contentDidResizeSystem
				self.contentDidResizeSystem = nil
				self.cursor.Width = self.cursor.shown and theme.textInputCursorWidth or 0
				self.contentDidResizeSystem = backup
			end
		end

		if self.onFocus ~= nil then
			self:onFocus()
		end
	end

	node._unfocus = function(self)
		if self.state ~= ui.State.Focused then return end
		self.state = ui.State.Idle

		if self.keyboardListener ~= nil then
			Client:HideVirtualKeyboard()
			self.keyboardListener:Remove() 
			self.keyboardListener = nil
		end
		ui:_textInputRefreshColor(self)
		self:_refresh()

		if self.onFocusLost ~= nil then
			self:onFocusLost()
		end
	end

	node:setParent(self.rootFrame)
	return node
end

ui._textInputRefreshColor = function(self, node)
	local state = node.state
	local colors
	local textColor
	local placeholderColor

	if state == self.State.Pressed then 
		colors = node.colorsPressed
		textColor = node.textColorPressed
		placeholderColor = node.placeholderColorPressed
	else
		if node.disabled then
			colors = node.colorsDisabled
			textColor = node.textColorDisabled
			placeholderColor = node.placeholderColorDisabled
		elseif state == self.State.Focused then
			colors = node.colorsFocused
			textColor = node.textColorFocused
			placeholderColor = node.placeholderColorFocused
		else
			colors = node.colors
			textColor = node.textColor
			placeholderColor = node.placeholderColor
		end
	end

	node.background.Color = colors[1]
	node.border.Color = colors[2]
	node.string.Color = textColor
	node.placeholder.Color = placeholderColor

end

ui._textInputRefresh = function(self)
	-- to avoid refresh triggering a call to itself
	local backup = self._refresh
	self._refresh = nil

	local theme = require("uitheme").current

	local paddingAndBorder = theme.padding + theme.textInputBorderSize

	local placeholder = self.placeholder
	local str = self.string
	local cursor = self.cursor

	if #str.Text > 0 then 
		placeholder:hide()
	else
		placeholder:show()
	end

	local h
	h = str.Height + paddingAndBorder * 2
	self.border.Height = h
	self.background.Height = h - theme.textInputBorderSize * 2

	placeholder.LocalPosition = {paddingAndBorder, self.Height * 0.5 - placeholder.Height * 0.5, 0}
	str.LocalPosition = {paddingAndBorder, self.Height * 0.5 - str.Height * 0.5, 0}

	if self.state == ui.State.Focused then
		cursor:show()
		cursor.Height = str.Height
		cursor.pos = str.pos + {str.Width, 0, 0}
	else
		cursor:hide()
	end

	self._refresh = backup
end

ui._buttonRefreshColor = function(self, node)
	local state = node.state
	local colors
	local textColor

	if state == self.State.Pressed then 
		colors = node.colorsPressed
		textColor = node.textColorPressed
	else
		if node.selected then
			colors = node.colorsSelected
			textColor = node.textColorSelected
		elseif node.disabled then
			colors = node.colorsDisabled
			textColor = node.textColorDisabled
		else
			colors = node.colors
			textColor = node.textColor
		end
	end

	node.background.Palette[1].Color = colors[1]
	if #node.borders > 0 then
		node.borders[1].Palette[1].Color = colors[2]
		node.borders[2].Palette[1].Color = colors[2]
		node.borders[3].Palette[1].Color = colors[3]
		node.borders[4].Palette[1].Color = colors[3]
	end
	node.content.Color = textColor -- doesn't seem to be working
end

ui._buttonOnPress = function(self, callback)
	if self.disabled == true then return end

	-- print("_buttonOnPress")
	self.state = ui.State.Pressed
	ui:_buttonRefreshColor(self)
	if callback ~= nil then
		callback(self)
	end

	Client:HapticFeedback()
end

ui._buttonOnRelease = function(self, callback)
	if self.disabled == true then return end

	-- print("_buttonOnRelease")
	self.state = ui.State.Idle
	ui:_buttonRefreshColor(self)
	if callback ~= nil then
		callback(self)
	end
end

ui._buttonOnCancel = function(self, callback)
	if self.disabled == true then return end

	self.state = ui.State.Idle
	ui:_buttonRefreshColor(self)
	if callback ~= nil then
		callback(self)
	end
end

ui._buttonRefresh = function(self)
	if self.content == nil then return end

	local paddingAndBorder = ui.kButtonPadding + ui.kButtonBorder

	local content = self.content

	local paddingLeft = paddingAndBorder
	local paddingBottom = paddingAndBorder
	local totalWidth
	local totalHeight

	if self.fixedWidth ~= nil then
		totalWidth = self.fixedWidth
		paddingLeft = (totalWidth - content.Width) * 0.5
	else
		totalWidth = content.Width + paddingAndBorder * 2
	end

	if self.fixedHeight ~= nil then
		totalHeight = self.fixedHeight
		paddingBottom = (totalHeight - content.Height) * 0.5
	else
		totalHeight = content.Height + paddingAndBorder * 2
	end

	local background = self.background if background == nil then return end

	background.Scale.X = totalWidth
	background.Scale.Y = totalHeight
	
	background.LocalPosition = {ui.kButtonBorder, ui.kButtonBorder, 0}

	content.LocalPosition = {paddingLeft * 1.5, paddingBottom * 1.5, 0}

	if #self.borders > 0 then
		content.LocalPosition = {paddingLeft, paddingBottom, 0}
		background.Scale.X = totalWidth - ui.kButtonBorder * 2
		background.Scale.Y = totalHeight - ui.kButtonBorder * 2
		local top = self.borders[1] local right = self.borders[2]
		local bottom = self.borders[3] local left = self.borders[4]

		top.Scale.X = totalWidth
		top.Scale.Y = ui.kButtonBorder
		top.LocalPosition = {0, totalHeight - ui.kButtonBorder, 0}

		right.Scale.X = ui.kButtonBorder
		right.Scale.Y = totalHeight - ui.kButtonBorder * 2
		right.LocalPosition = {totalWidth - ui.kButtonBorder, ui.kButtonBorder, 0}

		bottom.Scale.X = totalWidth
		bottom.Scale.Y = ui.kButtonBorder
		bottom.LocalPosition = {0, 0, 0}

		left.Scale.X = ui.kButtonBorder
		left.Scale.Y = totalHeight - ui.kButtonBorder * 2
		left.LocalPosition = {0, ui.kButtonBorder, 0}
	end

	if self.shadow then
		self.shadow.Scale.X = totalWidth - ui.kButtonBorder * 2
		self.shadow.Scale.Y = ui.kButtonBorder
		self.shadow.LocalPosition = {ui.kButtonBorder, -ui.kButtonBorder, 0}
	end
end
	
ui.createButton = function(self,stringOrShape,config)
	
	local _config = {
		-- toggle borders
		borders = true,
		-- toggle shadow
		shadow = true,
		textSize = "default",
		sound = "button_1",
	}

	if config then
		if config.borders ~= nil then _config.borders = config.borders end
		if config.shadow ~= nil then _config.shadow = config.shadow end
		if config.textSize ~= nil then _config.textSize = config.textSize end
		if config.sound ~= nil then _config.sound = config.sound end
	end
	config = _config

	local theme = require("uitheme").current

	if stringOrShape == nil then 
		error("ui:createButton(stringOrShape, config) expects a non-nil string or Shape", 2)
	end

	local node = self:_nodeCreate()

	node.config = config

	node.contentDidResizeSystem = function(self)
		self:_refresh()
	end

	node.selected = false
	node.disabled = false

	node.type = self.NodeType.Button
	node._onCancel = self._buttonOnCancel
	node._refresh = self._buttonRefresh
	node.state = self.State.Idle
	node.object = Object()

	node.fixedWidth = nil
	node.fixedHeight = nil

	node._setWidth = function(self, newWidth)
		self.fixedWidth = newWidth
		self:_refresh()
	end

	node._setHeight = function(self, newHeight)
		self.fixedHeight = newHeight
		self:_refresh()
	end

	node._text = function(self)
		return self.content.Text
	end

	node._setText = function(self, str)
		self.content.Text = str
		self:contentDidResizeWrapper()
	end

	node.setColor = function(self, background, text, doNotrefresh)
		if background ~= nil then
			node.colors = { Color(background), Color(background), Color(background) }
			node.colors[2]:ApplyBrightnessDiff(theme.buttonTopBorderBrightnessDiff)
			node.colors[3]:ApplyBrightnessDiff(theme.buttonBottomBorderBrightnessDiff)
		end
		if text ~= nil then
			node.textColor = Color(text)
		end
		if not doNotrefresh then ui:_buttonRefreshColor(self) end
	end

	node.setColorPressed = function(self, background, text, doNotrefresh)
		if background ~= nil then
			node.colorsPressed = { Color(background), Color(background), Color(background) }
			node.colorsPressed[2]:ApplyBrightnessDiff(theme.buttonTopBorderBrightnessDiff)
			node.colorsPressed[3]:ApplyBrightnessDiff(theme.buttonBottomBorderBrightnessDiff)
		end
		if text ~= nil then
			node.textColorPressed = Color(text)
		end
		if not doNotrefresh then ui:_buttonRefreshColor(self) end
	end

	node.setColorSelected = function(self, background, text, doNotrefresh)
		if background ~= nil then
			node.colorsSelected = { Color(background), Color(background), Color(background) }
			node.colorsSelected[2]:ApplyBrightnessDiff(theme.buttonTopBorderBrightnessDiff)
			node.colorsSelected[3]:ApplyBrightnessDiff(theme.buttonBottomBorderBrightnessDiff)
		end
		if text ~= nil then
			node.textColorSelected = Color(text)
		end
		if not doNotrefresh then ui:_buttonRefreshColor(self) end
	end

	node.setColorDisabled = function(self, background, text, doNotrefresh)
		if background ~= nil then
			node.colorsDisabled = { Color(background), Color(background), Color(background) }
			node.colorsDisabled[2]:ApplyBrightnessDiff(theme.buttonTopBorderBrightnessDiff)
			node.colorsDisabled[3]:ApplyBrightnessDiff(theme.buttonBottomBorderBrightnessDiff)
		end
		if text ~= nil then
			node.textColorDisabled = Color(text)
		end
		if not doNotrefresh then ui:_buttonRefreshColor(self) end
	end

	node:setColor(theme.buttonColor, theme.buttonTextColor, true)
	node:setColorPressed(theme.buttonColorPressed, theme.buttonTextColorPressed, true)
	node:setColorSelected(theme.buttonColorSelected, theme.buttonTextColorSelected, true)
	node:setColorDisabled(theme.buttonColorDisabled, theme.buttonTextColorDisabled, true)

	local background = MutableShape()
	background:AddBlock(node.colors[1],0,0,0)
	self:_setupUIShape(background, true)
	node.object:AddChild(background)
	background._node = node

	node.background = background
	node.borders = {}

	if config.borders then
		local borderTop = MutableShape()
		borderTop:AddBlock(node.colors[2],0,0,0)
		self:_setupUIShape(borderTop)
		borderTop.CollisionGroups = {} borderTop.CollidesWithGroups = {}
		node.object:AddChild(borderTop)
		table.insert(node.borders, borderTop)

		local borderRight = MutableShape()
		borderRight:AddBlock(node.colors[2],0,0,0)
		self:_setupUIShape(borderRight)
		borderRight.CollisionGroups = {} borderRight.CollidesWithGroups = {}
		node.object:AddChild(borderRight)
		table.insert(node.borders, borderRight)

		local borderBottom = MutableShape()
		borderBottom:AddBlock(node.colors[3],0,0,0)
		self:_setupUIShape(borderBottom)
		borderBottom.CollisionGroups = {} borderBottom.CollidesWithGroups = {}
		node.object:AddChild(borderBottom)
		table.insert(node.borders, borderBottom)

		local borderLeft = MutableShape()
		borderLeft:AddBlock(node.colors[3],0,0,0)
		self:_setupUIShape(borderLeft)
		borderLeft.CollisionGroups = {} borderLeft.CollidesWithGroups = {}
		node.object:AddChild(borderLeft)
		table.insert(node.borders, borderLeft)
	end

	if config.shadow then
		local shadow = MutableShape()
		shadow:AddBlock(Color(0,0,0,20),0,0,0)
		self:_setupUIShape(shadow)
		shadow.CollisionGroups = {} shadow.CollidesWithGroups = {}
		node.object:AddChild(shadow)
		node.shadow = shadow
	end

	local paddingAndBorder = self.kButtonPadding
	if config.borders then
		paddingAndBorder = paddingAndBorder + self.kButtonBorder
	end

	-- TODO: test stringOrShape type

	local t = ui:createText(stringOrShape, nil, type(stringOrShape) == "string" and config.textSize or size) -- color is nil here
	t:setParent(node)
	node.content = t

	node:_refresh()
	ui:_buttonRefreshColor(node) -- apply initial colors

	node.onPress = function(self) end
	node.onRelease = function(self) end

	node.select = function(self)
		if self.selected then return end
		self.selected = true
		ui:_buttonRefreshColor(self)
	end

	node.unselect = function(self)
		if self.selected == false then return end
		self.selected = false
		ui:_buttonRefreshColor(self)
	end

	node.enable = function(self)
		if self.disabled == false then return end
		self.disabled = false
		ui:_buttonRefreshColor(self)
	end

	node.disable = function(self)
		if self.disabled then return end
		self.disabled = true
		ui:_buttonRefreshColor(self)
	end

	node:setParent(self.rootFrame)
	return node

end -- createButton

ui._nodeCreate = function(self)
	local node = {}
	local m = {
		attr = {
			-- can be a Shape, Text, Object...
			-- depending on node type
			object = nil,
			color = nil,
			parent = nil,
			type = self.NodeType.None,
			children = {},
			parentDidResize = nil,
			contentDidResize = nil, -- user defined
			contentDidResizeSystem = nil,
			contentDidResizeWrapper = function(self)
				if self.contentDidResizeSystem ~= nil then self:contentDidResizeSystem() end
				if self.contentDidResize ~= nil then self:contentDidResize() end
			end,
			setParent = self._nodeSetParent,
			hasParent = self._nodeHasParent,
			remove = self._nodeRemove,
			show = function(self)
				if not self.object then return end
				if self.parent.object then
					self.object:SetParent(self.parent.object)
				else
					self.object:SetParent(ui.rootFrame)
					-- self:setParent(ui.rootFrame)
				end
				self.object.IsHidden = false
			end,
			hide = function(self)
				if not self.object then return end
				self.object:RemoveFromParent()
				self.object.IsHidden = true
			end,
			toggle = function(self, show)
				if show == nil then show = self:isVisible() == false end
				if show then self:show()
				else self:hide() end
			end,
			isVisible = function(self)
				return self.object.IsHidden == false
			end,
			-- returned when requesting Width if defined
			-- can be a number or function(self) that returns a number
			width = nil, 
			-- returned when requesting Height if defined
			-- can be a number or function(self) that returns a number
			height = nil,
			-- returned when requesting text/Text if defined
			-- can be a string or function(self) that returns a string
			_text = nil, 
			-- called when setting text/Text if defined
			-- function(self,string)
			_setText = nil, 
			-- returned when requesting color/Color if defined
			-- can be a string or function(self) that returns a string
			_color = nil, 
			-- called when setting color/Color if defined
			-- function(self,color)
			_setColor = nil, 
		},
		__index = self._nodeIndex,
		__newindex = self._nodeNewindex
	}
	setmetatable(node, m)

	node._id = self._nodeID
	self._nodeID = self._nodeID + 1

	return node
end

ui._AABBToOBB = function(aabb)
	local obb = {}
	local min = aabb.Min
	local max = aabb.Max

	obb[1] = Number3(min.X, min.Y, min.Z)
	obb[2] = Number3(max.X, min.Y, min.Z)
	obb[3] = Number3(max.X, min.Y, max.Z)
	obb[4] = Number3(min.X, min.Y, max.Z)
	obb[5] = Number3(min.X, max.Y, min.Z)
	obb[6] = Number3(max.X, max.Y, min.Z)
	obb[7] = Number3(max.X, max.Y, max.Z)
	obb[8] = Number3(min.X, max.Y, max.Z)

	return obb
end

ui._OBBToAABB = function(obb)
	local point = obb[1]
	local min = Number3(point.X, point.Y, point.Z)
	local max = min:Copy()
	
	for i = 2,8 do
		point = obb[i]
		if point.X < min.X then min.X = point.X end
		if point.Y < min.Y then min.Y = point.Y end
		if point.Z < min.Z then min.Z = point.Z end
		if point.X > max.X then max.X = point.X end
		if point.Y > max.Y then max.Y = point.Y end
		if point.Z > max.Z then max.Z = point.Z end
	end

	return Box(min, max)
end

ui._OBBLocalToLocal = function(obb, src, dst)
	local point
	for i = 1,8 do
		point = obb[i]
		point = src:PositionLocalToWorld(point)
		obb[i] = dst:PositionWorldToLocal(point)
	end
end

ui._AABBJoin = function(aabb1, aabb2)
	-- using local variables + recreating the box 
	-- as a workaround because box.Max/Min.X/Y/Z
	-- can't be set directly (needs to be fixed in Cubzh engine)
	local maxX, maxY, maxZ = aabb1.Max.X, aabb1.Max.Y, aabb1.Max.Z
	local minX, minY, minZ = aabb1.Min.X, aabb1.Min.Y, aabb1.Min.Z

	if aabb2.Max.X > maxX then maxX = aabb2.Max.X end
	if aabb2.Max.Y > maxY then maxY = aabb2.Max.Y end
	if aabb2.Max.Z > maxZ then maxZ = aabb2.Max.Z end

	if aabb2.Min.X < minX then minX = aabb2.Min.X end
	if aabb2.Min.Y < minY then minY = aabb2.Min.Y end
	if aabb2.Min.Z < minZ then minZ = aabb2.Min.Z end
	
	return Box({minX, minY, minZ}, {maxX, maxY, maxZ})
end

ui._computeDescendantsBoundingBox = function(root)

	local boundingBox
	local aabb
	local obb

	ui._hierarchyActions:applyToDescendants(root,  { includeRoot = false }, function(s)

		if s.ComputeLocalBoundingBox ~= nil then
			aabb = s:ComputeLocalBoundingBox()
			obb = ui._AABBToOBB(aabb)
			ui._OBBLocalToLocal(obb, s:GetParent(), root)
			aabb = ui._OBBToAABB(obb)
			if boundingBox == nil then
				boundingBox = aabb:Copy()
			else
				boundingBox = ui._AABBJoin(boundingBox, aabb)
			end
		end
	end)

	if boundingBox == nil then
		boundingBox = Box({0, 0, 0}, {0, 0, 0})
	end

	return boundingBox
end

ui._nodeRemove = function(t)

	t:setParent(nil)

	-- in case node is a Text
	ui._texts[t._id] = nil

	if ui._pressed == t then ui._pressed = nil end

	if t.object then
		t.object:RemoveFromParent()
		t.object = nil
	end

	if t.onPressPrecise then
		t.onPressPrecise = nil
		ui._onPressShapes[t._id] = nil
	end
	
	for nodeID, child in pairs(t.children) do
		if child.remove ~= nil then
			child:remove()
		end
	end

	ui._cleanup(t)
end

ui._nodeSetParent = function(self, parent)
	local attr = getmetatable(self).attr

	-- setting same parent, nothing to do
	if parent ~= nil then
		if parent.object ~= nil and attr.parent == parent then return end
	end

	-- remove from current parent
	if attr.object ~= nil then attr.object:SetParent(nil) end
	if attr.parent.children ~= nil then
		attr.parent.children[self._id] = nil
	end
	-- in case node parent was root
	ui._rootChildren[self._id] = nil
	attr.parent = nil

	if parent == nil then return end

	local parentObject

	if parent.object ~= nil then
		attr.parent = parent
		parent.children[self._id] = self
		parentObject = parent.object
	else
		if parent == ui.rootFrame then
			ui._rootChildren[self._id] = self
		end
		parentObject = parent
	end

	attr.object:SetParent(parentObject)

	if self.shape == nil then
		attr.object.LocalPosition.Z = (parentObject.ChildrenCount + 1) * ui.kLayerStep
	else
		-- use custom step for shapes, to make sure above their parent,
		-- could be improved considering Pivot, bounding box, scale...
		-- local s = self.shape
		-- local max = math.max(math.max(s.Width * s.Scale.X, s.Depth * s.Scale.Z), s.Height * s.Scale.Y)
		-- local max = math.max(math.max(self.Width, self.Height), self.Depth)
		-- attr.object.LocalPosition.Z = (parentObject.ChildrenCount + 1) * ui.kLayerStep - max

		-- displaying shapes at mid camera far distance
		-- to decrease chances of clipping. This is not ideal...
		attr.object.LocalPosition.Z = -ui.kUIFar * 0.5
	end

	if self.parentDidResize then
		self:parentDidResize()
	end
end

ui._nodeHasParent = function(self) 
	return self.object:GetParent() ~= nil
end

ui._nodeIndex = function(t, k)
	local m = getmetatable(t)

	if k == "Width" then

		if t._width ~= nil then
			if type(t._width) == "function" then return t:_width()
			else return t._width end
		elseif t.width ~= nil then
			-- TODO: keeping this to avoid breaking scripts, but right name should be _width
			if type(t.width) == "function" then return t:width()
			else return t.width end
		elseif t.type == ui.NodeType.Button then
			return t.background.LocalScale.X + (#t.borders > 0 and t.borders[2].LocalScale.X * 2 or 0)
		else
			return m.attr.object.Width * m.attr.object.LocalScale.X
		end

	elseif k == "Height" then

		if t._height ~= nil then
			if type(t._height) == "function" then return t:_height()
			else return t._height end
		elseif t.height ~= nil then
			-- TODO: keeping this to avoid breaking scripts, but right name should be _height
			if type(t.height) == "function" then return t:height()
			else return t.height end
		elseif t.type == ui.NodeType.Button then
			return t.background.LocalScale.Y + (#t.borders > 0 and t.borders[1].LocalScale.Y * 2 or 0)
		else
			return m.attr.object.Height * m.attr.object.LocalScale.Y
		end

	elseif k == "Depth" then

		if t._depth ~= nil then
			if type(t._depth) == "function" then return t:_depth()
			else return t._depth end
		elseif t.type == ui.NodeType.Button then
			return t.background.LocalScale.Z
		else
			return m.attr.object.Depth * m.attr.object.LocalScale.Z
		end

	elseif k == "pos" or k == "position" or k == "LocalPosition" then

		return t.object.LocalPosition

	elseif k == "text" or k == "Text" then
		if t._text ~= nil then
			if type(t._text) == "function" then return t:_text()
			else return t._text end
		end
	elseif k == "color" or k == "Color" then
		if t._color ~= nil then
			if type(t._color) == "function" then return t:_color()
			else return t._color end
		else
			return nil
		end
	elseif k == "onRelease" then
		return t._onRelease
	elseif k == "onPress" then 
		return t._onPress
	elseif k == "onCancel" then 
		return t._onCancel
	end

	local v = m.attr[k]
	if v ~= nil then return v end

    return m.attr.object[k]
end

ui._nodeNewindex = function(t, k, v)
	local m = getmetatable(t)
	local attr = m.attr

	if k == "color" or k == "Color" then
		attr.color = v
		if t._setColor ~= nil then
			t:_setColor(v)
		end
	elseif k == "onPress" then
		if t.type == ui.NodeType.Button then
			t._onPress = function(self)
				ui._buttonOnPress(self, v)
			end
		elseif t.type == ui.NodeType.Frame then
			local background = t.background
			if v == nil and t._onRelease == nil then
				background.Physics = PhysicsMode.Disabled
				background.CollisionGroups = {}
				t._onPress = nil
			elseif v ~= nil then
				background.Physics = PhysicsMode.Trigger
				background.CollisionGroups = {ui.kUICollisionGroup}
				background.CollisionBox = Box({ 0, 0, 0 }, { background.Width, background.Height, 1 })
				t._onPress = function()
					if v ~= nil then v() end
				end	
			end
		else
			t._onPress = function()
				if v ~= nil then v() end
			end
		end
	elseif k == "onRelease" then
		if t.type == ui.NodeType.Button then
			t._onRelease = function(self)
				ui._buttonOnRelease(self, v)
			end
		elseif t.type == ui.NodeType.Frame then
			local background = t.background
			if v == nil and t._onPress == nil then
				background.Physics = PhysicsMode.Disabled
				background.CollisionGroups = {}
				t._onRelease = nil
			elseif v ~= nil then
				background.Physics = PhysicsMode.Trigger
				background.CollisionGroups = {ui.kUICollisionGroup}
				background.CollisionBox = Box({ 0, 0, 0 }, { background.Width, background.Height, 1 })
				t._onRelease = function()
					if v ~= nil then v() end
				end	
			end
		else
			t._onRelease = function()
				if v ~= nil then v() end
			end
		end
	elseif k == "onCancel" then 
		if t.type == ui.NodeType.Button then
			t._onCancel = function(self)
				ui._buttonOnCancel(self, v)
			end
		else
			t._onCancel = function()
				if v ~= nil then v() end
			end
		end
	elseif k == "onPressPrecise" then
		if t.object == nil then return end

		if v == nil then -- remove from list
			for k,o in ipairs(ui._onPressShapes) do
				if o == t then
					t._onPressPrecise = nil
					if t._onReleasePrecise == nil then ui._onPressShapes[t._id] = nil end
					return
				end
			end
		else -- add to list
			ui._onPressShapes[t._id] = t
			t._onPressPrecise = v
		end
	elseif k == "onReleasePrecise" then
		if t.object == nil then return end

		if v == nil then -- remove from list
			for k,o in ipairs(ui._onPressShapes) do
				if o == t then
					t._onReleasePrecise = nil
					if t._onPressPrecise == nil then ui._onPressShapes[t._id] = nil end
					return
				end
			end
		else -- add to list
			ui._onPressShapes[t._id] = t
			t._onReleasePrecise = v
		end
	elseif k == "Pivot" then
		if t.background ~= nil then
			t.background.Pivot = v
		else
			if type(t.object) == "Text" then
				-- TODO ? 
			else
				t.object.Pivot = v
			end
		end			
	elseif k == "pos" or k == "position" or k == "LocalPosition" then
		local obj = t.object
		local z = obj.LocalPosition.Z
		obj.LocalPosition = v
		obj.LocalPosition.Z = z -- restore Z (layer)

	elseif k == "rot" or k == "rotation" or k == "LocalRotation" then
		t.object.LocalRotation = v

	elseif k == "IsHidden" then
		t.object.IsHidden = v

	elseif k == "Width" then
		if t.Width == v then return end -- don't do anything if setting same Width

		if t._setWidth ~= nil then
			t:_setWidth(v)

			for nodeID, child in pairs(t.children) do
				if child.parentDidResize ~= nil then
					child:parentDidResize()
				end
			end

			if t.parent ~= nil then t.parent:contentDidResizeWrapper() end
		end
	elseif k == "Height" then
		if t.Height == v then return end -- don't do anything if setting same Height

		if t._setHeight ~= nil then
			t:_setHeight(v)

			for nodeID, child in pairs(t.children) do
				if child.parentDidResize ~= nil then
					child:parentDidResize()
				end
			end

			if t.parent ~= nil then t.parent:contentDidResizeWrapper() end
		end
	elseif k == "text" or k == "Text" then
		if t._setText ~= nil then
			if type(t._setText) == "function" then return t:_setText(v) end
		else
			attr[k] = v	
		end
	else
		attr[k] = v	
	end
end

ui:init()

return ui