--[[
UI module used to implement default user interfaces in Cubzh.

//!\\ Still a work in progress. Your scripts may break in the future if you use it now.

]]
--

----------------------
-- CONSTANTS
----------------------

UI_FAR = 1000
UI_LAYER = 12
UI_LAYER_SYSTEM = 13
UI_COLLISION_GROUP = 12
UI_COLLISION_GROUP_SYSTEM = 13
UI_SHAPE_SCALE = 5
LAYER_STEP = -0.1 -- children offset
UI_FOREGROUND_DEPTH = -945
UI_ALERT_DEPTH = -950
BUTTON_PADDING = 4
BUTTON_BORDER = 3
BUTTON_UNDERLINE = 1
COMBO_BOX_SELECTOR_SPEED = 400

----------------------
-- ENUMS
----------------------

local State = {
	Idle = 0,
	Pressed = 1,
	Focused = 2,
	Disabled = 3,
	Selected = 4,
}

local NodeType = {
	None = 0,
	Frame = 1,
	Button = 2,
}

----------------------
-- MODULES
----------------------

codes = require("inputcodes")
cleanup = require("cleanup")
hierarchyActions = require("hierarchyactions")
sfx = require("sfx")
theme = require("uitheme").current
ease = require("ease")
conf = require("config")

sharedUI = nil
sharedUIRootFrame = nil

systemUI = nil
systemUIRootFrame = nil

keyboardToolbar = nil

-- Using global to keep reference on focused node because
-- local within createUI conflicts between both uikit instances.
-- We could not find a better solution yet.
focused = nil

-- focused combo box
comboBoxSelector = nil

function focus(node)
	if focused ~= nil then
		if focused == node then
			return false -- already focused
		end
		if focused._unfocus ~= nil then
			focused:_unfocus()
		end
		focused = nil
	end
	focused = node

	if comboBoxSelector ~= nil then
		if comboBoxSelector.close ~= nil then
			comboBoxSelector:close()
			comboBoxSelector = nil
		end
	end

	applyVirtualKeyboardOffset()
	return true
end

function unfocus()
	focus(nil)
end

-- by default, require("uikit") returns one ui instance,
-- calling this function.
-- but it's also possible for System modules to request
-- a "System" instance that's always rendered on top of everything.
function createUI(system)
	local ui = {}

	-- exposing some constants used by other modules
	ui.kShapeScale = UI_SHAPE_SCALE
	ui.kButtonPadding = BUTTON_PADDING
	ui.kButtonBorder = BUTTON_BORDER
	ui.kForegroundDepth = UI_FOREGROUND_DEPTH
	ui.kAlertDepth = UI_ALERT_DEPTH

	----------------------
	-- VARS
	----------------------

	local rootChildren = {}

	-- The pointer index that's currently being used to interract with the UI.
	-- UI won't accept other pointer down events while this is not nil.
	local pointerIndex = nil

	-- Node that's currently being pressed
	local pressed = nil

	-- keeping a reference on all text items,
	-- to update fontsize when needed
	local texts = {}

	-- each Text gets a unique ID
	local nodeID = 1

	-- keeping current font size (based on screen size & density)
	local currentFontSize = Text.FontSizeDefault
	local currentFontSizeBig = Text.FontSizeBig
	local currentFontSizeSmall = Text.FontSizeSmall

	local pointerDownListener
	local pointerUpListener

	local privateFunctions = {}

	local function _setLayers(object)
		if system == true then
			System:SetLayersElevated(object, UI_LAYER_SYSTEM)
		else
			System:SetLayersElevated(object, UI_LAYER)
		end
	end

	local function _setCollisionGroups(object)
		if system == true then
			System:SetCollisionGroupsElevated(object, UI_COLLISION_GROUP_SYSTEM)
		else
			System:SetCollisionGroupsElevated(object, UI_COLLISION_GROUP)
		end
	end

	local _groups
	local function _getCollisionGroups()
		if _groups == nil then
			if system == true then
				_groups = System:GetGroupsElevated({ UI_COLLISION_GROUP_SYSTEM })
			else
				_groups = System:GetGroupsElevated({ UI_COLLISION_GROUP })
			end
		end
		return _groups
	end

	----------------------
	-- INIT
	----------------------

	Pointer:Show()

	-- Orthographic camera, to render UI
	local camera = Camera()
	camera:SetParent(World)
	camera.On = true
	camera.Far = UI_FAR
	_setLayers(camera)
	camera.Projection = ProjectionMode.Orthographic
	camera.Width = Screen.Width
	camera.Height = Screen.Height

	-- Top level object, containing all UI nodes
	local rootFrame = Object()
	if system == true then
		systemUIRootFrame = rootFrame
	else
		sharedUIRootFrame = rootFrame
	end

	rootFrame:SetParent(World)
	rootFrame.LocalPosition = { -Screen.Width * 0.5, -Screen.Height * 0.5, UI_FAR }

	-----------------------------
	-- PRIVATE FUNCTIONS
	-----------------------------

	local function _setupUIObject(object, collides)
		hierarchyActions:applyToDescendants(object, { includeRoot = true }, function(o)
			if type(o) == "Object" then
				return
			end
			_setLayers(o)
			o.IsUnlit = true

			o.CollidesWithGroups = {}
			o.CollisionGroups = {}
			o.Physics = PhysicsMode.Disabled
		end)

		if collides and object.Width ~= nil and object.Height ~= nil then
			object.Physics = PhysicsMode.Trigger
			_setCollisionGroups(object)
			object.CollisionBox = Box({ 0, 0, 0 }, { object.Width, object.Height, 0.1 })
		end
	end

	local function _nodeSetParent(self, parent)
		local attr = getmetatable(self).attr

		-- setting same parent, nothing to do
		if parent ~= nil then
			if parent.object ~= nil and attr.parent == parent then
				return
			end
		end

		-- remove from current parent
		if attr.object ~= nil then
			attr.object:SetParent(nil)
		end
		if attr.parent.children ~= nil then
			attr.parent.children[self._id] = nil
		end
		-- in case node parent was root
		rootChildren[self._id] = nil
		attr.parent = nil

		if parent == nil then
			return
		end

		local parentObject

		if parent.object ~= nil then
			attr.parent = parent
			parent.children[self._id] = self
			parentObject = parent.object
		else
			if parent == rootFrame then
				rootChildren[self._id] = self
			end
			parentObject = parent
		end

		attr.object:SetParent(parentObject)

		if self.shape == nil then
			attr.object.LocalPosition.Z = (parentObject.ChildrenCount + 1) * LAYER_STEP
		else
			-- use custom step for shapes, to make sure above their parent,
			-- could be improved considering Pivot, bounding box, scale...
			-- local s = self.shape
			-- local max = math.max(math.max(s.Width * s.Scale.X, s.Depth * s.Scale.Z), s.Height * s.Scale.Y)
			-- local max = math.max(math.max(self.Width, self.Height), self.Depth)
			-- attr.object.LocalPosition.Z = (parentObject.ChildrenCount + 1) * LAYER_STEP - max

			-- displaying shapes at mid camera far distance
			-- to decrease chances of clipping. This is not ideal...
			-- 0.45 instead of 0.5 to let room for alerts in front
			-- (quick fix for shapes clipping with alert background)
			attr.object.LocalPosition.Z = -UI_FAR * 0.45
		end

		if self.parentDidResize then
			self:parentDidResize()
		end
	end

	local function _nodeHasParent(self)
		return self.object:GetParent() ~= nil
	end

	-- using public wrapper to limit to 1 parameter
	-- (it should not be possible to override the `toClean` table)
	privateFunctions._nodeRemovePublicWrapper = function(t)
		privateFunctions._nodeRemove(t)
	end

	privateFunctions._nodeRemove = function(t, toClean)
		local cleanupWhenDone = false

		if toClean == nil then
			cleanupWhenDone = true
			toClean = {}
		end

		if type(t.onRemove) == "function" then
			t:onRemove()
		end

		t:setParent(nil)

		-- in case node is a Text
		texts[t._id] = nil

		if pressed == t then
			pressed = nil
		end

		if focused == t then
			focus(nil)
		end

		if t.object then
			t.object:RemoveFromParent()
			t.object = nil
		end

		for _, child in pairs(t.children) do
			if child.remove ~= nil then
				privateFunctions._nodeRemove(child, toClean)
			end
		end

		table.insert(toClean, t)

		if cleanupWhenDone then
			for _, node in ipairs(toClean) do
				cleanup(node)
			end
		end
	end

	local function _buttonRefreshColor(node)
		local state = node.state
		local colors
		local textColor

		if state == State.Pressed then
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

		node.background.Color = colors[1]
		if #node.borders > 0 then
			node.borders[1].Color = colors[2]
			node.borders[2].Color = colors[2]
			node.borders[3].Color = colors[3]
			node.borders[4].Color = colors[3]
		end

		if node.underline ~= nil then
			node.underline.Color = textColor
		end

		node.content.Color = textColor -- doesn't seem to be working
	end

	local function _buttonRefresh(self)
		if self.content == nil then
			return
		end

		local padding = BUTTON_PADDING
		local border = BUTTON_BORDER
		local underlinePadding = 0

		if self.config.padding == false then
			padding = 0
		end

		if self.config.borders == false then
			border = 0
			padding = 2 * padding
		end

		if self.config.underline then
			underlinePadding = BUTTON_UNDERLINE * 2
		end

		local paddingAndBorder = padding + border

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
			totalHeight = content.Height + paddingAndBorder * 2 + underlinePadding
		end

		local background = self.background
		if background == nil then
			return
		end

		background.Scale.X = totalWidth
		background.Scale.Y = totalHeight

		background.LocalPosition = { 0, 0, 0 }

		content.LocalPosition = { totalWidth * 0.5 - content.Width * 0.5, totalHeight * 0.5 - content.Height * 0.5 }

		if #self.borders > 0 then
			content.LocalPosition = { paddingLeft, paddingBottom, 0 }
			local top = self.borders[1]
			local right = self.borders[2]
			local bottom = self.borders[3]
			local left = self.borders[4]

			top.Scale.X = totalWidth
			top.Scale.Y = BUTTON_BORDER
			top.LocalPosition = { 0, totalHeight - BUTTON_BORDER, LAYER_STEP }

			right.Scale.X = BUTTON_BORDER
			right.Scale.Y = totalHeight - BUTTON_BORDER * 2
			right.LocalPosition = { totalWidth - BUTTON_BORDER, BUTTON_BORDER, LAYER_STEP }

			bottom.Scale.X = totalWidth
			bottom.Scale.Y = BUTTON_BORDER
			bottom.LocalPosition = { 0, 0, LAYER_STEP }

			left.Scale.X = BUTTON_BORDER
			left.Scale.Y = totalHeight - BUTTON_BORDER * 2
			left.LocalPosition = { 0, BUTTON_BORDER, LAYER_STEP }
		end

		if self.underline ~= nil then
			self.underline.Scale.X = totalWidth
			self.underline.Scale.Y = BUTTON_UNDERLINE
			self.underline.LocalPosition = { 0, 0, LAYER_STEP }
		end

		if self.shadow then
			self.shadow.Scale.X = totalWidth - BUTTON_BORDER * 2
			self.shadow.Scale.Y = BUTTON_BORDER
			self.shadow.LocalPosition = { BUTTON_BORDER, -BUTTON_BORDER, 0 }
		end
	end

	local function _buttonOnPress(self, callback, obj, block, pe)
		if self.disabled == true then
			return
		end

		self.state = State.Pressed
		_buttonRefreshColor(self)
		if callback ~= nil then
			callback(self, obj, block, pe)
		end

		Client:HapticFeedback()
	end

	local function _buttonOnRelease(self, callback)
		if self.disabled == true then
			return
		end

		self.state = State.Idle
		_buttonRefreshColor(self)
		if callback ~= nil then
			callback(self)
		end
	end

	local function _buttonOnCancel(self, callback)
		if self.disabled == true then
			return
		end

		self.state = State.Idle
		_buttonRefreshColor(self)
		if callback ~= nil then
			callback(self)
		end
	end

	local function _nodeIndex(t, k)
		local m = getmetatable(t)

		if k == "Width" then
			if t._width ~= nil then
				if type(t._width) == "function" then
					return t:_width()
				else
					return t._width
				end
			else
				return 0
			end
		elseif k == "Height" then
			if t._height ~= nil then
				if type(t._height) == "function" then
					return t:_height()
				else
					return t._height
				end
			else
				return 0
			end
		elseif k == "Depth" then
			if t._depth ~= nil then
				if type(t._depth) == "function" then
					return t:_depth()
				else
					return t._depth
				end
			else
				return 0
			end
		elseif k == "pos" or k == "position" or k == "Position" or k == "LocalPosition" then
			return t.object.LocalPosition
		elseif k == "size" or k == "Size" then
			return Number2(t.Width, t.Height)
		elseif k == "text" or k == "Text" then
			if t._text ~= nil then
				if type(t._text) == "function" then
					return t:_text()
				else
					return t._text
				end
			end
		elseif k == "color" or k == "Color" then
			if t._color ~= nil then
				if type(t._color) == "function" then
					return t:_color()
				else
					return t._color
				end
			else
				return nil
			end
		elseif k == "onRelease" then
			return t._onRelease
		elseif k == "onPress" then
			return t._onPress
		elseif k == "onCancel" then
			return t._onCancel
		elseif k == "onDrag" then
			return t._onDrag
		end

		local v = m.attr[k]
		if v ~= nil then
			return v
		end

		return m.attr.object[k]
	end

	local function _nodeNewindex(t, k, v)
		local m = getmetatable(t)
		local attr = m.attr

		if k == "onPressPrecise" then
			k = "onPress"
			print("⚠️ onPressPrecise is deprecated, use onPress")
		elseif k == "onReleasePrecise" then
			k = "onRelease"
			print("⚠️ onReleasePrecise is deprecated, use onRelease")
		end

		if k == "color" or k == "Color" then
			attr.color = v
			if t._setColor ~= nil then
				t:_setColor(v)
			end
		elseif k == "onPress" then
			if t.type == NodeType.Button then
				t._onPress = function(self, object, block, pe)
					_buttonOnPress(self, v, object, block, pe)
				end
			elseif t.type == NodeType.Frame then
				local background = t.background
				if v == nil then
					t._onPress = nil
					if t._onRelease == nil then
						background.Physics = PhysicsMode.Disabled
						background.CollisionGroups = {}
					end
				elseif v ~= nil then
					background.Physics = PhysicsMode.Trigger
					_setCollisionGroups(background)
					background.CollisionBox = Box({ 0, 0, 0 }, { background.Width, background.Height, 0.1 })
					t._onPress = function()
						if v ~= nil then
							v()
						end
					end
				end
			else
				if t._setCollider then
					t:_setCollider(v ~= nil)
				end
				t._onPress = function(self, object, block, pe)
					if v ~= nil then
						v(self, object, block, pe)
					end
				end
			end
		elseif k == "onRelease" then
			if t.type == NodeType.Button then
				t._onRelease = function(self)
					_buttonOnRelease(self, v)
				end
			elseif t.type == NodeType.Frame then
				local background = t.background
				if v == nil then
					t._onRelease = nil
					if t._onPress == nil then
						background.Physics = PhysicsMode.Disabled
						background.CollisionGroups = {}
					end
				elseif v ~= nil then
					background.Physics = PhysicsMode.Trigger
					_setCollisionGroups(background)
					background.CollisionBox = Box({ 0, 0, 0 }, { background.Width, background.Height, 0.1 })
					t._onRelease = function()
						if v ~= nil then
							v()
						end
					end
				end
			else
				if t._setCollider then
					t:_setCollider(v ~= nil)
				end
				t._onRelease = function(self, object, block)
					if v ~= nil then
						v(self, object, block)
					end
				end
			end
		elseif k == "onCancel" then
			if t.type == NodeType.Button then
				t._onCancel = function(self)
					_buttonOnCancel(self, v)
				end
			else
				t._onCancel = function(self)
					if v ~= nil then
						v(self)
					end
				end
			end
		elseif k == "onDrag" then
			t._onDrag = function(self, x, y)
				if v ~= nil then
					v(self, x, y)
				end
			end
		elseif k == "Pivot" then
			if t.background ~= nil and t.background.Pivot ~= nil then
				t.background.Pivot = v
			elseif t.object.Pivot ~= nil then
				t.object.Pivot = v
			elseif t.object.Anchor ~= nil then
				if type(v) == "table" then
					t.object.Anchor = Number2(v[1], v[2])
				elseif type(v) == "Number3" then
					t.object.Anchor = Number2(v.X, v.Y)
				end
			end
			-- TODO: node could use a separate internal object when it needs a pivot, to be type-agnostic
		elseif k == "pos" or k == "position" or k == "Position" or k == "LocalPosition" then
			local isNumber = function(val)
				return type(val) == "number" or type(val) == "integer"
			end

			if type(v) ~= "table" and type(v) ~= "Number2" and type(v) ~= "Number3" then
				error("uikit: node." .. k .. " must be a Number2", 2)
			end
			if type(v) == "table" then
				if #v < 2 then
					error("uikit: node." .. k .. " must be a Number2", 2)
				end
				if isNumber(v[1]) == false or isNumber(v[2]) == false then
					error("uikit: node." .. k .. " subvalues must be numbers", 2)
				end
			end

			local obj = t.object
			local z = obj.LocalPosition.Z
			-- convert to Number3
			if type(v) == "Number2" then
				v = Number3(v.X, v.Y, 0)
			elseif type(v) == "table" and #v == 2 then
				v = Number3(v[1], v[2], 0)
			end
			obj.LocalPosition = v -- v is a Number3
			obj.LocalPosition.Z = z -- restore Z (layer)
		elseif k == "size" or k == "Size" then
			if type(v) == "number" or type(v) == "integer" then
				v = Number2(v, v)
			end
			if type(v) == "table" and v[1] ~= nil and v[2] ~= nil then
				v = Number2(v[1], v[2])
			end
			if type(v) ~= "Number2" then
				error(k .. " must be a Number2", 2)
			end
			if not pcall(function()
				t.Width = v.X
				t.Height = v.Y
			end) then
				error(k .. " can't be set", 2)
			end
		elseif k == "rot" or k == "rotation" or k == "Rotation" or k == "LocalRotation" then
			t.object.LocalRotation = v
		elseif k == "IsHidden" then
			t.object.IsHidden = v
		elseif k == "IsMask" then
			if t._setIsMask ~= nil then
				t:_setIsMask(v)
			end
		elseif k == "Width" then
			if t.Width == v then
				return
			end -- don't do anything if setting same Width

			if t._setWidth ~= nil then
				t:_setWidth(v)

				for _, child in pairs(t.children) do
					if child.parentDidResize ~= nil then
						child:parentDidResize()
					end
				end

				if t.parent ~= nil then
					t.parent:contentDidResizeWrapper()
				end
			end
		elseif k == "Height" then
			if t.Height == v then
				return
			end -- don't do anything if setting same Height

			if t._setHeight ~= nil then
				t:_setHeight(v)

				for _, child in pairs(t.children) do
					if child.parentDidResize ~= nil then
						child:parentDidResize()
					end
				end

				if t.parent ~= nil then
					t.parent:contentDidResizeWrapper()
				end
			end
		elseif k == "text" or k == "Text" then
			if t._setText ~= nil then
				if type(t._setText) == "function" then
					local r = t:_setText(v)
					t:contentDidResizeWrapper()
					return r
				end
			else
				attr[k] = v
			end
		else
			-- TMP, to help fixing script
			if k == "width" then
				error("width -> _width", 2)
			end
			if k == "height" then
				error("height -> _height", 2)
			end
			attr[k] = v
		end
	end

	local function _AABBToOBB(aabb)
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

	local function _OBBToAABB(obb)
		local point = obb[1]
		local min = Number3(point.X, point.Y, point.Z)
		local max = min:Copy()

		for i = 2, 8 do
			point = obb[i]
			if point.X < min.X then
				min.X = point.X
			end
			if point.Y < min.Y then
				min.Y = point.Y
			end
			if point.Z < min.Z then
				min.Z = point.Z
			end
			if point.X > max.X then
				max.X = point.X
			end
			if point.Y > max.Y then
				max.Y = point.Y
			end
			if point.Z > max.Z then
				max.Z = point.Z
			end
		end

		return Box(min, max)
	end

	local function _OBBLocalToLocal(obb, src, dst)
		local point
		for i = 1, 8 do
			point = obb[i]
			point = src:PositionLocalToWorld(point)
			obb[i] = dst:PositionWorldToLocal(point)
		end
	end

	local function _AABBJoin(aabb1, aabb2)
		-- using local variables + recreating the box
		-- as a workaround because box.Max/Min.X/Y/Z
		-- can't be set directly (needs to be fixed in Cubzh engine)
		local maxX, maxY, maxZ = aabb1.Max.X, aabb1.Max.Y, aabb1.Max.Z
		local minX, minY, minZ = aabb1.Min.X, aabb1.Min.Y, aabb1.Min.Z

		if aabb2.Max.X > maxX then
			maxX = aabb2.Max.X
		end
		if aabb2.Max.Y > maxY then
			maxY = aabb2.Max.Y
		end
		if aabb2.Max.Z > maxZ then
			maxZ = aabb2.Max.Z
		end

		if aabb2.Min.X < minX then
			minX = aabb2.Min.X
		end
		if aabb2.Min.Y < minY then
			minY = aabb2.Min.Y
		end
		if aabb2.Min.Z < minZ then
			minZ = aabb2.Min.Z
		end

		return Box({ minX, minY, minZ }, { maxX, maxY, maxZ })
	end

	local function _computeDescendantsBoundingBox(root)
		local boundingBox
		local aabb
		local obb

		hierarchyActions:applyToDescendants(root, { includeRoot = false }, function(s)
			if s.ComputeLocalBoundingBox ~= nil then
				aabb = s:ComputeLocalBoundingBox()
				obb = _AABBToOBB(aabb)
				_OBBLocalToLocal(obb, s:GetParent(), root)
				aabb = _OBBToAABB(obb)
				if boundingBox == nil then
					boundingBox = aabb:Copy()
				else
					boundingBox = _AABBJoin(boundingBox, aabb)
				end
			end
		end)

		if boundingBox == nil then
			boundingBox = Box({ 0, 0, 0 }, { 0, 0, 0 })
		end

		return boundingBox
	end

	local function _nodeCreate()
		local node = {}
		local m = {
			attr = {
				-- can be a Shape, Text, Object...
				-- depending on node type
				object = nil,
				color = nil,
				parent = nil,
				type = NodeType.None,
				children = {},
				parentDidResize = nil,
				contentDidResize = nil, -- user defined
				contentDidResizeSystem = nil,
				contentDidResizeWrapper = function(self)
					if self.contentDidResizeSystem ~= nil then
						self:contentDidResizeSystem()
					end
					if self.contentDidResize ~= nil then
						self:contentDidResize()
					end
				end,
				setParent = _nodeSetParent,
				hasParent = _nodeHasParent,
				remove = privateFunctions._nodeRemovePublicWrapper,
				show = function(self)
					if not self.object then
						return
					end
					if self.parent.object then
						self.object:SetParent(self.parent.object)
					else
						self.object:SetParent(rootFrame)
					end
					self.object.IsHidden = false
				end,
				hide = function(self)
					if not self.object then
						return
					end
					self.object:RemoveFromParent()
					self.object.IsHidden = true
				end,
				toggle = function(self, show)
					if show == nil then
						show = self:isVisible() == false
					end
					if show then
						self:show()
					else
						self:hide()
					end
				end,
				isVisible = function(self)
					return self.object.IsHidden == false
				end,
				hasFocus = function(self)
					return focused == self
				end,
				-- returned when requesting Width if defined
				-- can be a number or function(self) that returns a number
				_width = nil,
				-- returned when requesting Height if defined
				-- can be a number or function(self) that returns a number
				_height = nil,
				-- returned when requesting text/Text if defined
				-- can be a string or function(self) that returns a string
				_text = nil,
				-- called when setting text/Text if defined
				-- function(self,string)
				_setText = nil,
				-- returned when requesting color/Color if defined
				-- can be a Color or function(self) that returns a string
				_color = nil,
				-- called when setting color/Color if defined
				-- function(self,color)
				_setColor = nil,
			},
			__index = _nodeIndex,
			__newindex = _nodeNewindex,
		}
		setmetatable(node, m)

		node._id = nodeID
		nodeID = nodeID + 1

		return node
	end

	local function _refreshShapeNode(node)
		if node.shape == nil then
			return
		end

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
				node.shapeContainer:AddChild(node.shape)
				node.shape.LocalPosition = Number3.Zero
			end
		end

		local backupScale = node.object.LocalScale:Copy()
		node.object.LocalScale = 1
		node.pivot.LocalPosition = Number3.Zero
		node.shapeContainer.LocalPosition = Number3.Zero

		if not node._config.doNotFlip then
			node.pivot.LocalRotation = { 0, math.pi, 0 } -- shape's front facing camera
		else
			node.pivot.LocalRotation = Rotation(0, 0, 0) -- shape's back facing camera
		end

		-- shape.LocalScale = UI_SHAPE_SCALE
		-- the shape scale is always 1
		-- in the context of a shape node, we always apply scale to the parent object
		node.shape.LocalScale = 1

		-- NOTE: Using AABB in pivot space to infer size & placement.
		-- We may also need AABB in object space in some cases.
		node._aabb = _computeDescendantsBoundingBox(node.pivot)

		node._aabbWidth = node._aabb.Max.X - node._aabb.Min.X
		node._aabbHeight = node._aabb.Max.Y - node._aabb.Min.Y
		node._aabbDepth = node._aabb.Max.Z - node._aabb.Min.Z

		if node._config.spherized then
			node._diameter = math.sqrt(node._aabbWidth ^ 2 + node._aabbHeight ^ 2 + node._aabbDepth ^ 2)
		end

		-- center Shape within pivot
		-- considering Shape's pivot but not modifying it
		-- It could be important for shape's children placement.

		if node._config.spherized then
			local radius = node.Width * 0.5
			node.pivot.LocalPosition = { radius, radius, radius }
		else
			node.pivot.LocalPosition = Number3(node.Width * 0.5, node.Height * 0.5, node.Depth * 0.5)
		end

		node.shapeContainer.LocalPosition = -node._aabb.Center + node._config.offset
		node.object.LocalScale = backupScale
	end

	local function _textInputRefreshColor(node)
		local state = node.state
		local colors
		local textColor
		local placeholderColor

		if state == State.Pressed then
			colors = node.colorsPressed
			textColor = node.textColorPressed
			placeholderColor = node.placeholderColorPressed
		else
			if node.disabled then
				colors = node.colorsDisabled
				textColor = node.textColorDisabled
				placeholderColor = node.placeholderColorDisabled
			elseif state == State.Focused then
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

	local function _textInputRefresh(node)
		-- to avoid refresh triggering a call to itself
		local backup = node._refresh
		node._refresh = nil

		local theme = require("uitheme").current

		local padding = theme.padding
		local border = theme.textInputBorderSize

		local paddingAndBorder = padding + border

		local textContainer = node.textContainer
		local placeholder = node.placeholder
		local str = node.string

		local hiddenStr
		if node.hiddenString then
			hiddenStr = node.hiddenString
		end

		local cursor = node.cursor

		if #str.Text > 0 then
			placeholder:hide()
		else
			placeholder:show()
		end

		local h
		h = str.Height + paddingAndBorder * 2
		node.border.Height = h
		node.background.Height = h - theme.textInputBorderSize * 2

		textContainer.Width = node.Width - border * 2
		textContainer.Height = node.Height - border * 2

		textContainer.pos = { border, border, 0 }

		placeholder.pos = { padding, textContainer.Height * 0.5 - placeholder.Height * 0.5, 0 }
		str.pos = { padding, textContainer.Height * 0.5 - str.Height * 0.5, 0 }
		if hiddenStr ~= nil then
			hiddenStr.pos = str.pos
		end

		if node.state == State.Focused then
			if str.Width > textContainer.Width - padding * 2 then
				str.pos.X = padding - str.Width + (textContainer.Width - padding * 2)
			end

			if hiddenStr ~= nil and hiddenStr.Width > textContainer.Width - padding * 2 then
				hiddenStr.pos.X = padding - hiddenStr.Width + (textContainer.Width - padding * 2)
			end

			cursor:show()
			cursor.Height = str.Height

			if hiddenStr ~= nil and hiddenStr:isVisible() then
				cursor.pos = hiddenStr.pos + { hiddenStr.Width, 0, 0 }
			else
				cursor.pos = str.pos + { str.Width, 0, 0 }
			end
		else
			cursor:hide()
		end

		node._refresh = backup
	end

	----------------------
	-- PUBLIC FUNCTIONS
	----------------------

	ui.isShown = function(_)
		return rootFrame:GetParent() ~= nil
	end

	ui.hide = function(_)
		rootFrame:SetParent(nil)
	end

	ui.show = function(_)
		rootFrame:SetParent(World)
	end

	ui.turnOff = function(_)
		pointerDownListener:Pause()
		pointerUpListener:Pause()
	end

	ui.turnOn = function(_)
		pointerDownListener:Resume()
		pointerUpListener:Resume()
	end

	ui.createNode = function(_)
		local node = _nodeCreate()
		node.object = Object()
		node.object.LocalPosition = { 0, 0, 0 }

		node:setParent(rootFrame)

		return node
	end

	---@function createImage Creates a frame
	---@param color? color
	---@param config? uikitNodeConfig
	---@code -- nodes can have an image if provided image Data (PNG or JPEG)
	--- local url = "https://cu.bzh/img/pen.png"
	--- HTTP:Get(url, function(response)
	---		local f = uikit:createFrame(Color.Black, {image = response.Data})
	---		f:setParent(uikit.rootFrame)
	---		f.LocalPosition = {50, 50, 0}
	--- end)
	ui.createFrame = function(self, color, config)
		if self ~= ui then
			error("ui:createFrame(color, config): use `:`", 2)
		end
		if color ~= nil and type(color) ~= Type.Color then
			error("ui:createFrame(color, config): color should be a Color or nil", 2)
		end
		if config ~= nil and type(config) ~= Type.table then
			error("ui:createFrame(color, config): config should be a table", 2)
		end

		local _config = {
			unfocuses = false, -- unfocused focused node when true
			image = nil,
		}

		local image
		if config ~= nil and config.image ~= nil then
			if type(config.image) ~= Type.Data then
				error("ui:createFrame(color, config): config.image should be a Data instance", 2)
			end
			print("image taken into account")
			_config.image = config.image
			image = config.image
		end

		if type(config.unfocuses) == "boolean" then
			_config.unfocuses = config.unfocuses
		end

		color = color or Color(0, 0, 0, 0) -- default transparent frame
		local node = _nodeCreate()
		node.type = NodeType.Frame

		node.config = _config

		local background = Quad()
		if image == nil then
			background.Color = color
			background.IsDoubleSided = false
		else
			background.Image = image
			background.IsDoubleSided = true
		end

		_setupUIObject(background)

		node.object = background

		background._node = node
		node.background = background

		node._setIsMask = function(_, b)
			background.IsMask = b
		end

		node._color = function(self)
			return self.background.Color
		end

		node._setColor = function(self, color)
			self.background.Color = color
		end

		node.setColor = function(self, color)
			if self ~= node then
				error("frame:setColor(color): use `:`", 2)
			end
			if type(color) ~= Type.Color then
				error("frame:setColor(color): color should be a Color", 2)
			end
			self:_setColor(color)
		end

		node.setImage = function(self, image)
			if self ~= node then
				error("frame:setImage(image): use `:`", 2)
			end
			if image ~= nil and type(image) ~= Type.Data then
				error("frame:setImage(image): image should be a Data instance", 2)
			end

			self.background.Image = image
			if image ~= nil then
				self.background.Color = Color.White
				self.background.IsDoubleSided = true
			else
				background.Color = color
				background.IsDoubleSided = false
			end
		end

		node._width = function(self)
			return self.background.Width
		end
		node._height = function(self)
			return self.background.Height
		end
		node._depth = function(_)
			return 0
		end

		node._setWidth = function(self, v)
			self.background.Width = v
			self.background.CollisionBox = Box({ 0, 0, 0 }, { background.Width, background.Height, 0.1 })
		end

		node._setHeight = function(self, v)
			self.background.Height = v
			self.background.CollisionBox = Box({ 0, 0, 0 }, { background.Width, background.Height, 0.1 })
		end

		node.object.LocalPosition = { 0, 0, 0 }

		node:setParent(rootFrame)

		return node
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
	ui.createShape = function(_, shape, config)
		if shape == nil or (type(shape) ~= "Shape" and type(shape) ~= "MutableShape") then
			error("ui:createShape(shape) expects a non-nil Shape or MutableShape", 2)
		end

		local node = _nodeCreate()

		local defaultConfig = {
			spherized = false,
			doNotFlip = false,
			offset = Number3.Zero,
			perBlockCollisions = false,
		}

		config = conf:merge(defaultConfig, config)
		node._config = config

		node.object = Object()
		node.object.LocalScale = UI_SHAPE_SCALE

		node.pivot = Object()
		node.shapeContainer = Object()

		node.object:AddChild(node.pivot)
		node.pivot:AddChild(node.shapeContainer)

		node.refresh = _refreshShapeNode

		-- getters

		node._width = function(self)
			if config.spherized then
				return self._diameter * self.object.LocalScale.X
			else
				return self._aabbWidth * self.object.LocalScale.X
			end
		end

		node._height = function(self)
			if config.spherized then
				return self._diameter * self.object.LocalScale.X
			else
				return self._aabbHeight * self.object.LocalScale.Y
			end
		end

		node._depth = function(self)
			if config.spherized then
				return self._diameter * self.object.LocalScale.X
			else
				return self._aabbDepth * self.object.LocalScale.Z
			end
		end

		-- setters

		node._setCollider = function(self, b)
			if self.shape == nil then
				return
			end
			if b then
				if config.perBlockCollisions then
					self.shape.Physics = PhysicsMode.TriggerPerBlock
				else
					self.shape.Physics = PhysicsMode.Trigger
				end
				_setCollisionGroups(self.shape)
			else
				self.shape.Physics = PhysicsMode.Disabled
				self.shape.CollisionGroups = {}
			end
		end

		node._setWidth = function(self, newWidth)
			if newWidth == nil then
				return
			end
			if config.spherized then
				if self._diameter == 0 then
					return
				end
				self.object.LocalScale = newWidth / self._diameter
			else
				if self._aabbWidth == 0 then
					return
				end
				self.object.LocalScale.X = newWidth / self._aabbWidth
			end
		end

		node._setHeight = function(self, newHeight)
			if newHeight == nil then
				return
			end
			if config.spherized then
				if self._diameter == 0 then
					return
				end
				self.object.LocalScale = newHeight / self._diameter
			else
				if self._aabbHeight == 0 then
					return
				end
				self.object.LocalScale.Y = newHeight / self._aabbHeight
			end
		end

		node._setDepth = function(self, newDepth)
			if config.spherized then
				if self._diameter == 0 then
					return
				end
				self.object.LocalScale = newDepth / self._diameter
			else
				if self._aabbDepth == 0 then
					return
				end
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

			shape:RemoveFromParent()
			_setupUIObject(shape)
			self.shape = shape
			shape._node = self

			node.shapeContainer:AddChild(shape)
			shape.LocalPosition = Number3.Zero

			if doNotRefresh ~= true then
				self:refresh()
				if w ~= nil then
					self.Width = w
				end
				if h ~= nil then
					self.Height = h
				end
			end
		end

		node:setShape(shape, true)

		node:refresh()

		node:setParent(rootFrame)

		return node
	end

	ui.createText = function(_, str, color, size) -- "default" (default), "small", "big"
		if str == nil then
			error("ui:createText(string, <color>, <size>) str must be a string", 2)
		end
		if color and type(color) ~= Type.Color then
			error("ui:createText(string, <color>, <size>) color must be a Color", 2)
		end
		if size and type(size) ~= Type.string then
			error('ui:createText(string, <color>, <size>) size must be a string ("default", "small" or "big")', 2)
		end

		local node = _nodeCreate()
		texts[node._id] = node

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

		node._width = function(self)
			return self.object.Width * self.object.LocalScale.X
		end

		node._height = function(self)
			return self.object.Height * self.object.LocalScale.Y
		end

		local t = Text()
		t.Anchor = { 0, 0 }
		t.Type = TextType.World
		_setLayers(t)
		t.Text = str
		t.Padding = 0
		t.Color = color or Color(0, 0, 0, 255)
		t.BackgroundColor = Color(0, 0, 0, 0)
		t.MaxDistance = camera.Far + 100

		if node.fontsize == nil or node.fontsize == "default" then
			t.FontSize = currentFontSize
		elseif node.fontsize == "big" then
			t.FontSize = currentFontSizeBig
		elseif node.fontsize == "small" then
			t.FontSize = currentFontSizeSmall
		end

		t.IsUnlit = true
		t.Physics = PhysicsMode.Disabled
		t.CollisionGroups = {}
		t.CollidesWithGroups = {}
		t.LocalPosition = { 0, 0, 0 }

		node.object = t

		node:setParent(rootFrame)

		return node
	end

	function _textInputTextDidChange(textInput)
		if textInput.hiddenString then
			textInput.hiddenString.Text = string.rep("*", #textInput.Text)
		end

		if textInput.onTextChange then
			textInput:onTextChange()
		end
		textInput:_refresh()
	end

	-- ui:createTextInput(<string>, <placeholder>, <size>)
	ui.createTextInput = function(self, str, placeholder, configOrSize) -- "default" (default), "small", "big"
		local _config = {
			password = false,
			textSize = "default",
		}

		local config = {}

		if type(configOrSize) == "string" then
			config.textSize = configOrSize
		elseif type(configOrSize) == "table" then
			for k, _ in pairs(_config) do
				if configOrSize[k] ~= nil and type(configOrSize[k]) == type(_config[k]) then
					config[k] = configOrSize[k]
				else
					config[k] = _config[k]
				end
			end
		end

		local size = config.textSize

		local theme = require("uitheme").current

		local node = _nodeCreate()

		node.onTextChange = function(_) end

		node.disabled = false

		node._refresh = _textInputRefresh

		node.state = State.Idle
		node.object = Object()

		node.border = self:createFrame()
		node.border:setParent(node)

		node.background = self:createFrame()
		node.background:setParent(node)
		node.background.pos = { theme.textInputBorderSize, theme.textInputBorderSize, 0 }

		local textContainer = ui:createFrame(Color.transparent)
		textContainer:setParent(node)
		textContainer.IsMask = true
		node.textContainer = textContainer

		textContainer.contentDidResize = function(_)
			if node._refresh then
				node:_refresh()
			end
		end

		node.contentDidResizeSystem = function(self)
			if self._refresh then
				self:_refresh()
			end
		end

		node.placeholder = ui:createText(placeholder or "", Color.White, size) -- color replaced later on
		node.placeholder:setParent(textContainer)

		node.string = ui:createText(str or "", Color.White, size) -- color replaced later on
		node.string:setParent(textContainer)

		if config.password then
			node.hiddenString = ui:createText("", Color.White, size)
			node.hiddenString:setParent(textContainer)
			node.hiddenString.Text = string.rep("*", #node.string.Text)
			node.string:hide()
		end

		node.isTextHidden = function(self)
			return self.string:isVisible() == false
		end

		node.showText = function(self)
			self.string:show()
			if self.hiddenString ~= nil then
				self.hiddenString:hide()
			end
		end

		node.hideText = function(self)
			self.string:hide()
			if self.hiddenString ~= nil then
				self.hiddenString:show()
			end
		end

		node.cursor = self:createFrame(Color.White)
		node.cursor.Width = theme.textInputCursorWidth
		node.cursor:setParent(textContainer)

		node._width = function(self)
			return self.border.Width
		end
		node._height = function(self)
			return self.border.Height
		end
		node._depth = function(self)
			return self.border.Depth
		end

		node._setWidth = function(self, newWidth)
			self.border.Width = newWidth
			self.background.Width = newWidth - theme.textInputBorderSize * 2
		end

		node.Width = theme.textInputDefaultWidth

		node._setHeight = function(_, _)
			-- self.border.Height = newHeight
			-- self.background.Height = newHeight - theme.textInputBorderSize * 2
		end

		node._text = function(self)
			return self.string.Text
		end

		node._setText = function(self, str)
			self.string.Text = str
			_textInputTextDidChange(self)
		end

		node._color = function(self)
			return self.colors[1]
		end

		node.enable = function(self)
			if self.disabled == false then
				return
			end
			self.disabled = false
			_textInputRefreshColor(self)
		end

		node.disable = function(self)
			if self.disabled then
				return
			end
			self.disabled = true
			_textInputRefreshColor(self)
		end

		node.Width = 200

		node.setColor = function(self, background, text, placeholder, doNotrefresh)
			if background ~= nil then
				node.colors = { Color(background), Color(background) }
				node.colors[2]:ApplyBrightnessDiff(theme.textInputBorderBrightnessDiff)
			end
			if text ~= nil then
				node.textColor = Color(text)
			end
			if placeholder ~= nil then
				node.placeholderColor = Color(placeholder)
			end
			if not doNotrefresh then
				_textInputRefreshColor(self)
			end
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
			if not doNotrefresh then
				_textInputRefreshColor(self)
			end
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
			if not doNotrefresh then
				_textInputRefreshColor(self)
			end
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
			if not doNotrefresh then
				_textInputRefreshColor(self)
			end
		end

		node:setColor(theme.textInputBackgroundColor, theme.textInputTextColor, theme.textInputPlaceholderColor, true)
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
		_textInputRefreshColor(node) -- apply initial colors

		node.border.onPress = function()
			if node.disabled == true then
				return
			end
			node.state = State.Pressed
			_textInputRefreshColor(node)
		end

		node.border.onCancel = function()
			if node.disabled == true then
				return
			end
			node.state = State.Idle
			_textInputRefreshColor(node)
		end

		node.border.onRelease = function()
			if node.disabled == true then
				return
			end
			node:focus()
		end

		node.onFocus = nil
		node.onFocusLost = nil
		node.onSubmit = function()
			node:_unfocus() -- onfocus by default on submit
		end
		node.onUp = nil
		node.onDown = nil

		-- function to delete last UTF8 char
		local deleteLastCharacter = function(str)
			return (str:gsub("[%z\1-\127\194-\244][\128-\191]*$", ""))
		end

		node.focus = function(self)
			if self.state == State.Focused then
				return
			end
			self.state = State.Focused

			_textInputRefreshColor(self)
			self:_refresh()

			if focus(self) == false then
				-- can't take focus, maybe it already had it
				return
			end

			Client:ShowVirtualKeyboard()

			local keysDown = {}

			if self.keyboardListener == nil then -- better be safe, do not listen if already listening
				self.keyboardListener = LocalEvent:Listen(
					LocalEvent.Name.KeyboardInput,
					function(char, keycode, modifiers, down)
						if keycode == codes.ESCAPE then
							-- do not consider / capture ESC key inputs
							return
						end
						if self.string == nil then
							return
						end

						if down then
							if not keysDown[keycode] then
								keysDown[keycode] = true
							end
						else
							if keysDown[keycode] then
								keysDown[keycode] = nil
								return true -- catch
							else
								return -- return without catching
							end
						end

						-- print("char:", char, "key:", keycode, "mod:", modifiers)
						-- we need an enum for key codes (value could change)

						local cmd = (modifiers & codes.modifiers.Cmd) > 0
						local ctrl = (modifiers & codes.modifiers.Ctrl) > 0
						local option = (modifiers & codes.modifiers.Option) > 0 -- option is alt
						-- local shift = (modifiers & codes.modifiers.Shift) > 0

						local textDidChange = false
						if (cmd or ctrl) and not option then
							if keycode == codes.KEY_C then
								Dev:CopyToClipboard(self.string.Text)
							elseif keycode == codes.KEY_V then
								local s = System:GetFromClipboard()
								if s ~= "" then
									self.string.Text = self.string.Text .. s
									textDidChange = true
								end

							-- sfx("keydown_" .. math.random(1,4), {Spatialized = false})
							elseif keycode == codes.KEY_X then
								if self.string.Text ~= "" then
									Dev:CopyToClipboard(self.string.Text)
									self.string.Text = ""
									textDidChange = true
								end
							end
						else
							if keycode == codes.UP then
								if self.onUp then
									self:onUp()
									return true
								end
							elseif keycode == codes.DOWN then
								if self.onDown then
									self:onDown()
									return true
								end
							elseif keycode == codes.BACKSPACE then
								local str = self.string.Text
								if #str > 0 then
									str = deleteLastCharacter(str)
									self.string.Text = str
									textDidChange = true
								end
							elseif keycode == codes.RETURN or keycode == codes.NUMPAD_RETURN then
								if self.onSubmit then
									self:onSubmit()
									return true
								end
							elseif char ~= "" then
								self.string.Text = self.string.Text .. char
								textDidChange = true
							end
						end

						if textDidChange then
							_textInputTextDidChange(self)
						end

						return true -- capture event
					end,
					{
						topPriority = true,
						system = System,
					}
				)
			end

			self.dt = 0
			self.cursor.shown = true
			if self.object.Tick == nil then
				self.object.Tick = function(_, dt)
					if not self.dt then
						return
					end
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
			end

			if self.onFocus ~= nil then
				self:onFocus()
			end
		end

		node._unfocus = function(self)
			if self.state ~= State.Focused then
				return
			end

			self.state = State.Idle
			self.object.Tick = nil

			if self.keyboardListener ~= nil then
				Client:HideVirtualKeyboard()
				self.keyboardListener:Remove()
				self.keyboardListener = nil
			end
			_textInputRefreshColor(self)
			self:_refresh()

			unfocus()
			if self.onFocusLost ~= nil then
				self:onFocusLost()
			end
		end

		node.unfocus = function(self)
			if self:hasFocus() then
				focus(nil)
			end
		end

		node:setParent(rootFrame)

		return node
	end

	ui.createScrollArea = function(_, color, config)
		local ui = config.uikit or require("uikit")
		local node = ui:createFrame(color)
		node.isScrollArea = true

		local cellPadding = config.cellPadding or 0
		local direction = config.direction or "down"

		local listeners = {}
		local l
		local hovering = false
		local activated = false
		local dragging = false
		local dragPointerIndex = nil -- pointerIndex used to drag

		local container = ui:createFrame()
		container:setParent(node)
		container.IsMask = true
		node.container = container

		local cells = {}
		local cachedCellsHeight = {}

		node.nbCells = 0

		local maxY = 0
		node.scrollPosition = 0

		local scrollHandle = ui:createFrame(Color(0, 0, 0, 0)) -- TODO: work on handle
		scrollHandle:setParent(node)

		node.refresh = function()
			local y
			if direction == "down" then
				y = container.Height + node.scrollPosition
			else
				y = node.scrollPosition
			end
			maxY = 0
			local indexesToUnload = {}
			local indexesToLoad = {}
			for k = 1, node.nbCells do
				local v = cells[k]
				local height = cachedCellsHeight[k]

				-- place cell
				if direction == "down" then
					y = y - height
					if v then
						v.pos = { 0, y }
					end
					y = y - cellPadding
				else
					if v then
						v.pos = { 0, y }
					end
					y = y + height
					y = y + cellPadding
				end

				-- unload if out of area
				if v then
					if y > node.Height * 2 or y < -node.Height * 1.5 then
						table.insert(indexesToUnload, k)
					end
				-- load if back in area
				elseif y <= node.Height * 2 and y >= -node.Height then
					indexesToLoad[k] = true
				end

				-- compute maxY
				if maxY == 0 then
					maxY = height
				elseif k < node.nbCells then
					maxY = maxY + height + cellPadding
				end
			end

			if direction == "up" then
				maxY = -maxY - cellPadding + node.Height - (cachedCellsHeight[#cachedCellsHeight] or 0)
			elseif maxY > node.Height then
				maxY = maxY - node.Height + cachedCellsHeight[node.nbCells] + cellPadding
			else -- no scroll, content is not high enough
				maxY = 0
			end

			-- load up to one page
			if direction == "down" then
				if y >= -node.Height then
					indexesToLoad[node.nbCells + 1] = true
				end
			elseif direction == "up" then
				if y <= 2 * node.Height then
					indexesToLoad[node.nbCells + 1] = true
				end
			end

			local loadedCells = false
			for k, _ in pairs(indexesToLoad) do
				local newCell = config.loadCell(k)
				if newCell == nil then
					break
				end
				node:pushCell(newCell, k, false) -- no refresh yet
				loadedCells = true
			end

			for _, k in ipairs(indexesToUnload) do
				if cells[k] then
					-- unload if too far from screen
					config.unloadCell(cells[k])
					cells[k] = nil
				end
			end

			if loadedCells then
				node:refresh() -- refresh the whole list with loaded cells
			end

			-- refresh scrollHandle
			if (direction == "up" and maxY < 0) or (direction == "down" and maxY >= node.Height) then
				scrollHandle:show()
				scrollHandle.Width = 30
				scrollHandle.Height = math.min(node.Height, math.max(25, 100 / math.abs(maxY) * node.Height))
				local posY
				if direction == "down" then
					posY = node.Height - scrollHandle.Height - node.Height * math.abs(node.scrollPosition / maxY)
				elseif direction == "up" then
					posY = (node.Height - scrollHandle.Height) * math.abs(node.scrollPosition / maxY)
				end
				scrollHandle.pos = {
					node.Width - scrollHandle.Width,
					posY,
				}
			else
				scrollHandle:hide()
			end
		end

		-- set scroll position
		node.setScrollPosition = function(_, newPosition)
			if direction == "down" then
				node.scrollPosition = math.min(maxY, math.max(0, newPosition))
			elseif direction == "up" then
				node.scrollPosition = math.min(0, math.max(maxY, newPosition))
			end
			node:refresh()
		end

		node.pushFront = function(_, cell)
			for i = node.nbCells + 1, 2, -1 do
				cells[i] = cells[i - 1]
				cachedCellsHeight[i] = cachedCellsHeight[i - 1]
			end
			node.nbCells = node.nbCells + 1
			node:pushCell(cell, 1)
		end

		node.flush = function(_)
			for i = 1, node.nbCells do
				if cells[i] then
					config.unloadCell(cells[i])
				end
			end
			node.nbCells = 0
			cells = {}
			cachedCellsHeight = {}
		end

		-- add cell at index, called automatically after onLoad callback
		node.pushCell = function(_, cell, index, needRefresh)
			needRefresh = needRefresh == nil and true or needRefresh
			if cell == nil then
				return
			end
			if index == nil then
				index = node.nbCells + 1
			end
			cells[index] = cell
			cell:setParent(container)
			cachedCellsHeight[index] = cell.Height
			if index > node.nbCells then
				node.nbCells = index
			end
			if needRefresh then
				node:refresh()
			end
		end

		container.parentDidResize = function()
			container.Width = node.Width
			container.Height = node.Height
			node:setScrollPosition(0)
		end

		local scrollFrame = ui:createFrame()
		scrollFrame:setParent(node)
		scrollFrame.parentDidResize = function()
			scrollFrame.Width = node.Width
			scrollFrame.Height = node.Height
		end

		node.dragging = function()
			return dragging
		end

		node.containsPointer = function(self, pe)
			local x
			local y

			local ok = pcall(function()
				x = pe.X * Screen.Width
				y = pe.Y * Screen.Height
			end)

			if not ok then
				return false
			end

			-- compute absolute screen coordinates
			local bottomY = self.pos.Y
			local topY = bottomY + self.Height
			local leftX = self.pos.X
			local rightX = leftX + self.Width

			local parent = self.parent

			while parent do
				bottomY = bottomY + parent.pos.Y
				topY = topY + parent.pos.Y
				leftX = leftX + parent.pos.X
				rightX = rightX + parent.pos.X
				parent = parent.parent
			end

			return (x >= leftX and x <= rightX and y >= bottomY and y <= topY)
		end

		l = LocalEvent:Listen(LocalEvent.Name.PointerDown, function(pe)
			if node:containsPointer(pe) then
				dragPointerIndex = pe.Index
				activated = true
				unfocus()
			end
		end, { system = system == true and System or nil, topPriority = true })
		table.insert(listeners, l)

		l = LocalEvent:Listen(LocalEvent.Name.PointerUp, function(pe)
			if pe.Index ~= dragPointerIndex then
				return
			end
			dragPointerIndex = nil
			activated = false
			dragging = false
		end, { system = system == true and System or nil, topPriority = false })
		table.insert(listeners, l)

		l = LocalEvent:Listen(LocalEvent.Name.PointerCancel, function(pe)
			if pe.Index ~= dragPointerIndex then
				return
			end
			dragPointerIndex = nil
			activated = false
			dragging = false
		end, { system = system == true and System or nil, topPriority = false })
		table.insert(listeners, l)

		l = LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pe)
			if pe.Index ~= dragPointerIndex then
				return
			end
			if activated and dragging == false then
				dragging = true
			end
			if dragging then
				node:setScrollPosition(node.scrollPosition + pe.DY)
			end
		end, { system = system == true and System or nil, topPriority = true })
		table.insert(listeners, l)

		if Client.IsMobile == false then
			l = LocalEvent:Listen(LocalEvent.Name.PointerMove, function(pe)
				hovering = node:containsPointer(pe)
			end, { system = system == true and System or nil, topPriority = true })
			table.insert(listeners, l)

			l = LocalEvent:Listen(LocalEvent.Name.PointerWheel, function(delta)
				if not hovering then
					return false
				end
				node:setScrollPosition(node.scrollPosition + delta)
				return true
			end, { system = system == true and System or nil, topPriority = true })
			table.insert(listeners, l)
		end

		node.onRemove = function()
			for _, l in ipairs(listeners) do
				l:Remove()
			end
			listeners = {}
		end

		return node
	end

	ui.createButton = function(_, stringOrShape, config)
		local defaultConfig = {
			borders = true,
			underline = false,
			padding = true,
			shadow = true,
			textSize = "default",
			sound = "button_1",
			unfocuses = true, -- unfocused focused node when true
		}

		config = conf:merge(defaultConfig, config)

		local theme = require("uitheme").current

		if stringOrShape == nil then
			error("ui:createButton(stringOrShape, config) expects a non-nil string or Shape", 2)
		end

		if type(stringOrShape) ~= "string" then
			error("ui:createButton(stringOrShape, config) - stringOrShape can only be a string for now", 2)
		end

		local node = _nodeCreate()

		node.config = config

		node.contentDidResizeSystem = function(self)
			self:_refresh()
		end

		node.selected = false
		node.disabled = false

		node.type = NodeType.Button
		node._onCancel = _buttonOnCancel
		node._refresh = _buttonRefresh
		node.state = State.Idle
		node.object = Object()

		node.fixedWidth = nil
		node.fixedHeight = nil

		node._width = function(self)
			return self.background.LocalScale.X
		end

		node._setWidth = function(self, newWidth)
			self.fixedWidth = newWidth
			self:_refresh()
		end

		node._height = function(self)
			return self.background.LocalScale.Y
		end

		node._setHeight = function(self, newHeight)
			self.fixedHeight = newHeight
			self:_refresh()
		end

		node._depth = function(self)
			return self.background.LocalScale.Z
		end

		node._text = function(self)
			return self.content.Text
		end

		node._setText = function(self, str)
			self.content.Text = str
		end

		node.setColor = function(self, background, text, doNotrefresh)
			if background ~= nil then
				if type(background) ~= "Color" then
					error("setColor - first parameter (background color) should be a Color", 2)
				end
				node.colors = { Color(background), Color(background), Color(background) }
				node.colors[2]:ApplyBrightnessDiff(theme.buttonTopBorderBrightnessDiff)
				node.colors[3]:ApplyBrightnessDiff(theme.buttonBottomBorderBrightnessDiff)
			end
			if text ~= nil then
				if type(text) ~= "Color" then
					error("setColor - second parameter (text color) should be a Color", 2)
				end
				node.textColor = Color(text)
			end
			if not doNotrefresh then
				_buttonRefreshColor(self)
			end
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
			if not doNotrefresh then
				_buttonRefreshColor(self)
			end
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
			if not doNotrefresh then
				_buttonRefreshColor(self)
			end
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
			if not doNotrefresh then
				_buttonRefreshColor(self)
			end
		end

		node:setColor(theme.buttonColor, theme.buttonTextColor, true)
		node:setColorPressed(theme.buttonColorPressed, theme.buttonTextColorPressed, true)
		node:setColorSelected(theme.buttonColorSelected, theme.buttonTextColorSelected, true)
		node:setColorDisabled(theme.buttonColorDisabled, theme.buttonTextColorDisabled, true)

		local background = Quad()
		background.Color = node.colors[1]
		background.IsDoubleSided = false
		_setupUIObject(background, true)
		node.object:AddChild(background)
		background._node = node

		node.background = background
		node.borders = {}

		if config.borders then
			local borderTop = Quad()
			borderTop.Color = node.colors[2]
			borderTop.IsDoubleSided = false
			_setupUIObject(borderTop)
			node.object:AddChild(borderTop)
			table.insert(node.borders, borderTop)

			local borderRight = Quad()
			borderRight.Color = node.colors[2]
			borderRight.IsDoubleSided = false
			_setupUIObject(borderRight)
			node.object:AddChild(borderRight)
			table.insert(node.borders, borderRight)

			local borderBottom = Quad()
			borderBottom.Color = node.colors[3]
			borderBottom.IsDoubleSided = false
			_setupUIObject(borderBottom)
			node.object:AddChild(borderBottom)
			table.insert(node.borders, borderBottom)

			local borderLeft = Quad()
			borderLeft.Color = node.colors[3]
			borderLeft.IsDoubleSided = false
			_setupUIObject(borderLeft)
			node.object:AddChild(borderLeft)
			table.insert(node.borders, borderLeft)
		end

		if config.underline and not config.borders then
			local underline = Quad()
			underline.Color = node.textColor
			underline.IsDoubleSided = false
			_setupUIObject(underline)
			node.object:AddChild(underline)
			node.underline = underline
		end

		if config.shadow then
			local shadow = Quad()
			shadow.Color = Color(0, 0, 0, 20)
			shadow.IsDoubleSided = false
			_setupUIObject(shadow)
			node.object:AddChild(shadow)
			node.shadow = shadow
		end

		-- TODO: test stringOrShape type

		local t = ui:createText(stringOrShape, nil, config.textSize) -- color is nil here
		t:setParent(node)
		node.content = t

		node:_refresh()
		_buttonRefreshColor(node) -- apply initial colors

		node.onPress = function(_) end
		node.onRelease = function(_) end

		node.select = function(self)
			if self.selected then
				return
			end
			self.selected = true
			_buttonRefreshColor(self)
		end

		node.unselect = function(self)
			if self.selected == false then
				return
			end
			self.selected = false
			_buttonRefreshColor(self)
		end

		node.enable = function(self)
			if self.disabled == false then
				return
			end
			self.disabled = false
			_buttonRefreshColor(self)
		end

		node.disable = function(self)
			if self.disabled then
				return
			end
			self.disabled = true
			_buttonRefreshColor(self)
		end

		node:setParent(rootFrame)

		return node
	end -- createButton

	ui.createComboBox = function(self, stringOrShape, choices, config)
		if choices == nil then
			return
		end

		local btn = self:createButton(stringOrShape, config)

		btn.onSelect = function(_, _) end

		btn.onRelease = function(_)
			btn:disable()

			local selector = ui:createFrame(Color(0, 0, 0, 100))
			selector:setParent(btn.parent)

			focus(nil)
			comboBoxSelector = selector

			local frame = ui:createFrame(Color(255, 255, 255))
			frame:setParent(selector)
			frame.IsMask = true
			frame.pos = { theme.paddingTiny, theme.paddingTiny }
			frame.Width = btn.Width + theme.padding * 2

			local choiceButtons = {}

			local container = ui:createFrame(Color.transparent)
			container:setParent(frame)

			local showBelow = false
			local showAbove = false

			local down = ui:createButton("⬇️", { borders = true, shadow = false, unfocuses = false })
			-- NOTE: setting parent after hiding creates issues with collisions, it should not...
			down:setParent(frame)
			down.pos.Z = -20
			down:hide()
			down:disable()

			local up = ui:createButton("⬆️", { borders = true, shadow = false, unfocuses = false })
			up:setParent(frame)
			up.pos.Z = -20
			up:hide()
			up:disable()

			local dragged = false
			local selectedBtn = nil
			local totaldragY = 0

			local function onDrag(_, pe)
				totaldragY = totaldragY + pe.DY
				if dragged == false and math.abs(totaldragY) > 5 then
					dragged = true
				end

				if selectedBtn ~= nil then
					selectedBtn:unselect()
					selectedBtn = nil
				end

				container.pos.Y = container.pos.Y + pe.DY
				if container.pos.Y >= 0 then
					container.pos.Y = 0
					if down:isVisible() then
						down:hide()
						down:disable()
					end
				end

				if container.pos.Y + container.Height <= frame.Height then
					container.pos.Y = frame.Height - container.Height
					if up:isVisible() then
						up:hide()
						up:disable()
					end
				end

				if down:isVisible() == false and container.pos.Y < 0 then
					down:show()
					down:enable()
				end
				if up:isVisible() == false and container.pos.Y + container.Height > frame.Height then
					up:show()
					up:enable()
				end
			end

			local function onRelease(self)
				if dragged == false then
					btn.selectedRow = self._choiceIndex
					if btn.onSelect ~= nil then
						btn:onSelect(self._choiceIndex)
					end
					if selector.close then
						selector:close()
					end
				end
				dragged = false
			end

			local function onPress(self)
				dragged = false
				totaldragY = 0
				if selectedBtn ~= nil then
					selectedBtn:unselect()
				end
				selectedBtn = self
				self:select()
			end

			for i, choice in ipairs(choices) do
				local c = ui:createButton(choice, { borders = false, shadow = false, unfocuses = false })
				c:setParent(container)

				c._onDrag = onDrag
				c._choiceIndex = i

				if selectedBtn == nil and btn.selectedRow ~= nil and i == btn.selectedRow then
					c:select()
					selectedBtn = c
				end

				c.onRelease = onRelease
				c.onPress = onPress

				table.insert(choiceButtons, c)
			end

			down.onPress = function()
				showBelow = true
			end
			down.onRelease = function()
				showBelow = false
			end
			down.onCancel = function()
				showBelow = false
			end

			up.onPress = function()
				showAbove = true
			end
			up.onRelease = function()
				showAbove = false
			end
			up.onCancel = function()
				showAbove = false
			end

			local comboTickListener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
				if down:isVisible() == false and container.pos.Y < 0 then
					down:show()
					down:enable()
				end
				if up:isVisible() == false and container.pos.Y + container.Height > frame.Height then
					up:show()
					up:enable()
				end

				if showBelow then
					container.pos.Y = container.pos.Y + dt * COMBO_BOX_SELECTOR_SPEED
					if container.pos.Y >= 0 then
						container.pos.Y = 0
						down:onRelease()
						down:hide()
						down:disable()
					end
				end

				if showAbove then
					container.pos.Y = container.pos.Y - dt * COMBO_BOX_SELECTOR_SPEED
					if container.pos.Y + container.Height <= frame.Height then
						container.pos.Y = frame.Height - container.Height
						up:onRelease()
						up:hide()
						up:disable()
					end
				end
			end)

			-- refresh

			local absY = btn.pos.Y + btn.Height
			local parent = btn.parent

			while parent do
				absY = absY + parent.pos.Y
				parent = parent.parent
			end

			local contentHeight = 0

			for _, c in ipairs(choiceButtons) do
				contentHeight = contentHeight + c.Height
			end

			-- frame.Height = math.min(absY - Screen.SafeArea.Bottom, contentHeight)
			frame.Height = math.min(
				Screen.Height - Screen.SafeArea.Top - Screen.SafeArea.Bottom - theme.paddingBig * 2,
				contentHeight
			)

			frame.pos.Z = -10 -- render on front

			selector.Height = frame.Height + theme.paddingTiny * 2
			selector.Width = frame.Width + theme.paddingTiny * 2

			local p = Number3(btn.pos.X - theme.padding, btn.pos.Y + btn.Height - frame.Height + theme.padding, 0)

			parent = btn.parent
			absPy = p.Y
			while parent do
				absPy = absPy + parent.pos.Y
				parent = parent.parent
			end

			local offset = 0
			if absPy < Screen.SafeArea.Bottom + theme.paddingBig then
				offset = Screen.SafeArea.Bottom + theme.paddingBig - absPy
			end
			p.Y = p.Y + offset

			selector.pos.X = p.X
			selector.pos.Y = p.Y - 50

			ease:outBack(selector, 0.22).pos = p

			selector.pos.Z = -10 -- render on front

			container.Height = contentHeight
			container.Width = frame.Width

			local cursorY = container.Height
			for _, c in ipairs(choiceButtons) do
				c.Width = container.Width
				c.pos.Y = cursorY - c.Height
				cursorY = cursorY - c.Height
			end

			local selectionVisibilityOffset = 0
			if selectedBtn ~= nil then
				local visibleY = container.Height - frame.Height
				if selectedBtn.pos.Y < visibleY then -- place button at center if not visible by default
					selectionVisibilityOffset = visibleY
						- selectedBtn.pos.Y
						+ frame.Height * 0.5
						- selectedBtn.Height * 0.5
				end
			end

			container.pos.Y = frame.Height - container.Height + selectionVisibilityOffset
			if container.pos.Y >= 0 then
				container.pos.Y = 0
			end
			if container.pos.Y + container.Height <= frame.Height then
				container.pos.Y = frame.Height - container.Height
			end

			up.pos = { 0, frame.Height - up.Height }
			up.Width = frame.Width

			down.pos = { 0, 0 }
			down.Width = frame.Width

			selector.close = function(_)
				if comboBoxSelector == selector then
					comboBoxSelector = nil
				end
				ease:cancel(selector)
				comboTickListener:Remove()
				selector:remove()
				if btn.enable then
					btn:enable()
				end
			end
		end

		return btn
	end

	----------------------
	-- LISTENERS
	----------------------

	LocalEvent:Listen(LocalEvent.Name.ScreenDidResize, function(_, _)
		camera.Width = Screen.Width
		camera.Height = Screen.Height

		rootFrame.LocalPosition = { -Screen.Width * 0.5, -Screen.Height * 0.5, UI_FAR }

		if
			currentFontSize ~= Text.FontSizeDefault
			or currentFontSizeBig ~= Text.FontSizeBig
			or currentFontSizeSmall ~= Text.FontSizeSmall
		then
			currentFontSize = Text.FontSizeDefault
			currentFontSizeBig = Text.FontSizeBig
			currentFontSizeSmall = Text.FontSizeSmall

			for _, node in pairs(texts) do
				if node.object and node.object.FontSize then
					if node.fontsize == nil or node.fontsize == "default" then
						node.object.FontSize = currentFontSize
					elseif node.fontsize == "big" then
						node.object.FontSize = currentFontSizeBig
					elseif node.fontsize == "small" then
						node.object.FontSize = currentFontSizeSmall
					end
				end

				if node.parent.contentDidResizeWrapper ~= nil then
					node.parent:contentDidResizeWrapper()
				end
			end
		end

		for _, child in pairs(rootChildren) do
			if child.parentDidResize ~= nil then
				child:parentDidResize()
			end
		end
	end, { system = system == true and System or nil, topPriority = true })

	pointerDownListener = LocalEvent:Listen(LocalEvent.Name.PointerDown, function(pointerEvent)
		if pointerIndex ~= nil then
			return
		end
		-- TODO: only accept some indexed (no right mouse for example)

		local origin = Number3((pointerEvent.X - 0.5) * Screen.Width, (pointerEvent.Y - 0.5) * Screen.Height, 0)
		local direction = { 0, 0, 1 }

		local impacts
		local hitObject
		local parent
		local skip

		impacts = Ray(origin, direction):Cast(_getCollisionGroups(), nil, false)

		table.sort(impacts, function(a, b)
			return a.Distance < b.Distance
		end)

		for _, impact in ipairs(impacts) do
			skip = false

			hitObject = impact.Shape or impact.Object

			-- try to find parent ui object (when impact a child of a mutable shape)
			while hitObject and not hitObject._node do
				hitObject = hitObject:GetParent()
			end

			if hitObject and hitObject._node._onPress or hitObject._node._onRelease then
				-- check if hitObject is within a scroll
				parent = hitObject._node.parent
				while parent ~= nil do
					if parent.isScrollArea == true and parent:containsPointer(pointerEvent) == false then
						skip = true
						break
					end
					parent = parent.parent
				end

				if skip == false then
					pressed = hitObject._node

					-- unfocus focused node, unless hit node.config.unfocused == false
					if pressed ~= focused and pressed.config.unfocuses ~= false then
						focus(nil)
					end

					if hitObject._node._onPress then
						hitObject._node:_onPress(hitObject, impact.Block, pointerEvent)
					end
					if pressed.config.sound and pressed.config.sound ~= "" then
						sfx(pressed.config.sound, { Spatialized = false })
					end

					pointerIndex = pointerEvent.Index
					return true -- capture event, other listeners won't get it
				end
			end
		end

		-- did not touch anything, unfocus if focused node
		focus(nil)
	end, { system = system == true and System or nil, topPriority = true })

	pointerUpListener = LocalEvent:Listen(LocalEvent.Name.PointerUp, function(pointerEvent)
		if pointerIndex == nil or pointerIndex ~= pointerEvent.Index then
			return
		end
		pointerIndex = nil

		if pressed ~= nil then
			local origin = Number3((pointerEvent.X - 0.5) * Screen.Width, (pointerEvent.Y - 0.5) * Screen.Height, 0)
			local direction = { 0, 0, 1 }

			local impacts = Ray(origin, direction):Cast(_getCollisionGroups(), nil, false)

			table.sort(impacts, function(a, b)
				return a.Distance < b.Distance
			end)

			local parent
			local skip

			for _, impact in ipairs(impacts) do
				skip = false

				local hitObject = impact.Shape or impact.Object
				-- try to find parent ui object (when impact a child of a mutable shape)
				while hitObject and not hitObject._node do
					hitObject = hitObject:GetParent()
				end

				parent = hitObject._node.parent
				while parent ~= nil do
					if
						parent.isScrollArea == true
						and (parent:dragging() or parent:containsPointer(pointerEvent) == false)
					then
						skip = true
						break
					end
					parent = parent.parent
				end

				if skip == false and hitObject._node == pressed then
					if hitObject._node._onRelease then
						pressed:_onRelease(hitObject, impact.Block, pointerEvent)
					elseif pressed._onCancel then
						pressed:_onCancel()
					end
					pressed = nil
					-- pressed element captures event onRelease event
					-- even if onRelease and onCancel are nil
					return true
				end
			end
		end

		-- no matter what, pressed is now nil
		-- but not capturing event
		pressed = nil
	end, { system = system == true and System or nil, topPriority = true })

	LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pointerEvent)
		if pointerIndex == nil or pointerIndex ~= pointerEvent.Index then
			return
		end

		local pressed = pressed
		if pressed then
			if pressed._onDrag then
				pressed:_onDrag(pointerEvent)
				return true -- capture only if onDrag is set on the node
			end
		end
	end, { system = system == true and System or nil, topPriority = true })

	-- TODO: PointerCancel
	-- TODO: PointerMove

	----------------------
	-- DEPRECATED
	----------------------

	local fitScreenWarningDisplayed = false
	ui.fitScreen = function(_)
		if not fitScreenWarningDisplayed then
			print("⚠️ uikit.fitScreen is deprecated, no need to call it anymore!")
			fitScreenWarningDisplayed = true
		end
	end

	local pointerDownWarningDisplayed = false
	ui.pointerDown = function(_, _)
		if not pointerDownWarningDisplayed then
			print("⚠️ uikit.pointerDown is deprecated, no need to call it anymore!")
			pointerDownWarningDisplayed = true
		end
	end

	local pointerUpWarningDisplayed = false
	ui.pointerUp = function(_, _)
		if not pointerUpWarningDisplayed then
			print("⚠️ uikit.pointerUp is deprecated, no need to call it anymore!")
			pointerUpWarningDisplayed = true
		end
	end

	return ui
end

-- SHARED LISTENERS (for both shared an system UIs)

currentKeyboardHeight = nil

function applyVirtualKeyboardOffset()
	if currentKeyboardHeight == nil then
		return
	end
	if focused ~= nil then
		local ui = sharedUI.systemUI(System)

		-- rootPos: absolute position of focused component
		local rootPos = focused.pos
		local parent = focused.parent

		while parent ~= nil do
			rootPos = rootPos + parent.pos
			parent = parent.parent
		end

		local toolbarHeight

		if keyboardToolbar == nil then
			keyboardToolbar = ui:createFrame(theme.modalTopBarColor)
			keyboardToolbar.onPress = function() end -- blocker

			local cutBtn = ui:createButton("✂️", { unfocuses = false })
			cutBtn:setParent(keyboardToolbar)
			cutBtn.onRelease = function()
				if focused.Text ~= nil then
					Dev:CopyToClipboard(focused.Text)
					focused.Text = ""
				end
			end

			local copyBtn = ui:createButton("📑", { unfocuses = false })
			copyBtn:setParent(keyboardToolbar)
			copyBtn.onRelease = function()
				if focused.Text ~= nil then
					Dev:CopyToClipboard(focused.Text)
				end
			end

			local pasteBtn = ui:createButton("📋", { unfocuses = false })
			pasteBtn:setParent(keyboardToolbar)
			pasteBtn.onRelease = function()
				local s = System:GetFromClipboard()
				if s ~= "" and focused.Text ~= nil then
					focused.Text = focused.Text .. s
				end
			end

			-- local undoBtn = ui:createButton("↪️", { unfocuses = false })
			-- undoBtn:setParent(keyboardToolbar)

			-- local redoBtn = ui:createButton("↩️", { unfocuses = false })
			-- redoBtn:setParent(keyboardToolbar)

			local closeBtn = ui:createButton("⬇️", { unfocuses = false })
			closeBtn:setParent(keyboardToolbar)
			closeBtn.onRelease = function()
				focus(nil)
			end

			keyboardToolbar.cutBtn = cutBtn
			keyboardToolbar.copyBtn = copyBtn
			keyboardToolbar.pasteBtn = pasteBtn
			-- keyboardToolbar.undoBtn = undoBtn
			-- keyboardToolbar.redoBtn = redoBtn
			keyboardToolbar.closeBtn = closeBtn
		end

		keyboardToolbar.Width = Screen.Width
		keyboardToolbar.Height = keyboardToolbar.cutBtn.Height + theme.paddingTiny * 2
		toolbarHeight = keyboardToolbar.Height

		local diff = 0

		local bottomLine = currentKeyboardHeight + toolbarHeight + theme.paddingBig

		if rootPos.Y < bottomLine then
			diff = bottomLine - rootPos.Y

			if systemUIRootFrame then
				ease:cancel(systemUIRootFrame)
				ease:inOutSine(systemUIRootFrame, 0.2).LocalPosition = {
					-Screen.Width * 0.5,
					-Screen.Height * 0.5 + diff,
					UI_FAR,
				}
			end

			if sharedUIRootFrame then
				ease:cancel(sharedUIRootFrame)
				ease:inOutSine(sharedUIRootFrame, 0.2).LocalPosition = {
					-Screen.Width * 0.5,
					-Screen.Height * 0.5 + diff,
					UI_FAR,
				}
			end
		end

		if keyboardToolbar ~= nil then
			keyboardToolbar.cutBtn.pos.X = Screen.SafeArea.Left + theme.padding
			keyboardToolbar.cutBtn.pos.Y = theme.paddingTiny

			keyboardToolbar.copyBtn.pos.X = keyboardToolbar.cutBtn.pos.X
				+ keyboardToolbar.cutBtn.Width
				+ theme.paddingTiny
			keyboardToolbar.copyBtn.pos.Y = theme.paddingTiny

			keyboardToolbar.pasteBtn.pos.X = keyboardToolbar.copyBtn.pos.X
				+ keyboardToolbar.copyBtn.Width
				+ theme.paddingTiny
			keyboardToolbar.pasteBtn.pos.Y = theme.paddingTiny

			-- keyboardToolbar.undoBtn.pos.X = keyboardToolbar.pasteBtn.pos.X
			-- 	+ keyboardToolbar.pasteBtn.Width
			-- 	+ theme.padding
			-- keyboardToolbar.undoBtn.pos.Y = theme.paddingTiny

			-- keyboardToolbar.redoBtn.pos.X = keyboardToolbar.undoBtn.pos.X
			-- 	+ keyboardToolbar.undoBtn.Width
			-- 	+ theme.paddingTiny
			-- keyboardToolbar.redoBtn.pos.Y = theme.paddingTiny

			keyboardToolbar.closeBtn.pos.X = Screen.Width
				- Screen.SafeArea.Right
				- keyboardToolbar.closeBtn.Width
				- theme.padding
			keyboardToolbar.closeBtn.pos.Y = theme.paddingTiny

			keyboardToolbar.pos.Z = -UI_FAR + 2
			keyboardToolbar.pos.Y = currentKeyboardHeight - diff
		end
	end
end

-- listeners to adapt ui considering virtual keyboard presence.
LocalEvent:Listen(LocalEvent.Name.VirtualKeyboardShown, function(keyboardHeight)
	currentKeyboardHeight = keyboardHeight
	applyVirtualKeyboardOffset()
end, { system = System })

LocalEvent:Listen(LocalEvent.Name.VirtualKeyboardHidden, function()
	focus(nil)
	currentKeyboardHeight = nil

	if systemUIRootFrame then
		ease:cancel(systemUIRootFrame)
		ease:inOutSine(systemUIRootFrame, 0.2).LocalPosition = {
			-Screen.Width * 0.5,
			-Screen.Height * 0.5,
			UI_FAR,
		}
	end

	if sharedUIRootFrame then
		ease:cancel(sharedUIRootFrame)
		ease:inOutSine(sharedUIRootFrame, 0.2).LocalPosition = {
			-Screen.Width * 0.5,
			-Screen.Height * 0.5,
			UI_FAR,
		}
	end

	if keyboardToolbar ~= nil then
		keyboardToolbar:remove()
		keyboardToolbar = nil
	end
end, { system = System })

-- INIT

sharedUI = createUI()

sharedUI.systemUI = function(system)
	if system ~= System then
		error("can't access system UI", 2)
	end

	if systemUI == nil then
		systemUI = createUI(true)
		systemUI.unfocus = unfocus
	end

	return systemUI
end

return sharedUI
