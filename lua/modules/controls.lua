--- This module implements virtual controllers for touch screens.
--- By default controls are structured this way:
--- - A directional pad (8 possible directions)
--- - Up to 3 action buttons (depending on Client.Action1, Action2 & Action3)
--- - An analog pad that's in fact invisible, listening to Pointer.Drag events
--- Game can also request custom pads and layouts. (like left right directions distributed on 2 buttons on each side of the screen, or a centered directional pad)

-- NOTES ON PLACEMENT AND SIZE CONSTRAINTS: 

-- If X position is positive, button's left border placed from left side of the screen.
-- If X position is negative, button's right border placed from right side of the screen.
-- If Y position is positive, button's bottom border placed from bottom side of the screen.
-- Y position can't be negative.

-- Buttons automatically grouped by side (left/right)
-- If buttons cross half of the screen (vertically),
-- the whole group is downsized to make them fit.

-- NOTES ON POINTER VISIBILITY

-- Available functions when Pointer.IsHidden: 
-- 	- Client.DirectionalPad
--	- Client.AnalogPad
-- 	- Client.Action1 & Action1Release
-- 	- Client.Action2 & Action2Release
-- 	- Client.Action3 & Action3Release

-- Available functions when Pointer.IsHidden == false:
-- 	- Client.DirectionalPad
-- 	- Client.Action1 & Action1Release
-- 	- Pointer.Up
--	- Pointer.Down
-- 	- Pointer.Drag
-- 	- Pointer.Drag2
--	- Pointer.Zoom
--  - Pointer.Cancel

-- TODO: release all actions when HomeMenu is shown

local ACTION_BTN_SCREEN_PADDING = 8
local DIR_PAD_SCREEN_PADDING = 8
local ACTION_1_BTN_SIZE = 18
local ACTION_2_BTN_SIZE = 16
local ACTION_3_BTN_SIZE = 16
local SPACE_BETWEEN_BTNS = 2

local TOUCH_INDICATOR_SIZE = 13
local TOUCH_INDICATOR_SCALE = Number3(0.5,0.5,0.5)
local SCALE_ZERO = Number3(0,0,0)
local TOUCH_INDICATOR_LONG_PRESS_SCALE = 1.0

local POINTER_INDEX_TOUCH_1 = 1
local POINTER_INDEX_TOUCH_2 = 2
local POINTER_INDEX_TOUCH_3 = 3
local POINTER_INDEX_MOUSE_LEFT = 4
local POINTER_INDEX_MOUSE_RIGHT = 5
local POINTER_INDEX_MOUSE_WHEEL = 6
local POINTER_INDEX_MOUSE = 7 -- mouse with no specific button
local POINTER_INDEX_TOUCH = 8 -- any touch

local DIR_PAD_MIN_RADIUS = 0.2
local DIR_PAD_MAJOR_DIR_ANGLE = 50 * math.pi / 180.0
local DIR_PAD_MINOR_DIR_ANGLE = 40 * math.pi / 180.0

local DIR_PAD_STEP_1 = DIR_PAD_MAJOR_DIR_ANGLE * 0.5
local DIR_PAD_STEP_2 = DIR_PAD_STEP_1 + DIR_PAD_MINOR_DIR_ANGLE
local DIR_PAD_STEP_3 = DIR_PAD_STEP_2 + DIR_PAD_MAJOR_DIR_ANGLE
local DIR_PAD_STEP_4 = DIR_PAD_STEP_3 + DIR_PAD_MINOR_DIR_ANGLE
local DIR_PAD_STEP_5 = DIR_PAD_STEP_4 + DIR_PAD_MAJOR_DIR_ANGLE
local DIR_PAD_STEP_6 = DIR_PAD_STEP_5 + DIR_PAD_MINOR_DIR_ANGLE
local DIR_PAD_STEP_7 = DIR_PAD_STEP_6 + DIR_PAD_MAJOR_DIR_ANGLE
local DIR_PAD_STEP_8 = DIR_PAD_STEP_7 + DIR_PAD_MINOR_DIR_ANGLE

-- Reduce for faster zoom, increase for slower
local TOUCH_ZOOM_ANGLE = 60 * math.pi / 180.0
local TAN_TOUCH_ZOOM_ANGLE = math.tan(TOUCH_ZOOM_ANGLE)

-- moving more than that distance diffuses click
local CLICK_MOVE_SQR_EPSILON = 4

-- moving more than that distance diffuses long press timer
local LONG_PRESS_MOVE_SQR_EPSILON = 4
-- long press visual effect start after LONG_PRESS_DELAY_1 (in seconds)
local LONG_PRESS_DELAY_1 = 0.2 
-- long press visual effect lasts LONG_PRESS_DELAY_2 (in seconds)
-- before Pointer.LongPress is actually triggered
local LONG_PRESS_DELAY_2 = 0.2 

local controls = {
	config = {
		pressScale = 0.95,
		iconOnColor = Color(255,255,255),
		iconOffColor = Color(160,160,160),
		frameColor = Color(200,200,200, 180),
		fillColor = Color(255,255,255,180),
		layout = {
			indicator = {
				size = TOUCH_INDICATOR_SIZE,
			},
			dirpad = {
				size = 23,
				pos = {DIR_PAD_SCREEN_PADDING, DIR_PAD_SCREEN_PADDING}
			},
			analogpad = {
				mode = "drag" -- pad,drag
			},
			action1 = {
				size = ACTION_1_BTN_SIZE,
				pos = {-ACTION_BTN_SCREEN_PADDING, ACTION_BTN_SCREEN_PADDING}
			},
			action2 = {
				size = 16,
				pos = {
						- ACTION_BTN_SCREEN_PADDING - ACTION_1_BTN_SIZE - SPACE_BETWEEN_BTNS,
						ACTION_BTN_SCREEN_PADDING + ACTION_1_BTN_SIZE - ACTION_2_BTN_SIZE + SPACE_BETWEEN_BTNS
					}
			},
			action3 = {
				size = 16,
				pos = {
						- ACTION_BTN_SCREEN_PADDING - ACTION_1_BTN_SIZE + ACTION_3_BTN_SIZE - SPACE_BETWEEN_BTNS,
						ACTION_BTN_SCREEN_PADDING + ACTION_1_BTN_SIZE + SPACE_BETWEEN_BTNS
					},
			}
		},
	},
}

local ui = require("uikit")
local codes = require("inputcodes")
local ease = require("ease")
local theme = require("uitheme")

local _isMobile = Client.IsMobile
local _isPC = Client.IsPC

local _pointerIndexWithin = function(index, ...)
	local indexes = {...}
	for _, i in ipairs(indexes) do
		if i == index then return true end
	end
	return false
end

local _state = {
	on = true, -- controls can be turned on / off
	isHomeMenuOpened = Client.IsHomeMenuOpened,

	-- remember what key is down, to avoid considering repeated down events
	keysDown = {},

	pointersDown = {},
	nbPointersDown = 0,
	-- Touch pointer responsible for Pointer.Drag calls.
	-- When non-nil, touchDragPointer is of this form:
	-- {index = <pointer index>, pos = <last known position (Number2)>}
	touchDragPointer = nil,
	-- touchZoomAndDrag2Pointers is nil or contains 2 entries (pointer indexes)
	-- When defined, Zoom & Drag2 LocalEvents are emitted based on
	-- both register pointers, whenever one of them moves.
	-- each entry is like this: {index = <pointer index>, pos = <last known position (Number2)>}
	-- Only POINTER_INDEX_TOUCH_1, POINTER_INDEX_TOUCH_2 and POINTER_INDEX_TOUCH_3 are accepted for this.
	touchZoomAndDrag2Pointers = nil,
	dragStarted = false,
	drag2Started = false,

	--
	previousDistanceBetweenTouches = nil,

	-- shapes nil by default, created on demand
	dirpad = nil, 
	action1 = nil,
	action2 = nil,
	action3 = nil,

	-- pointer assigned to each pad / button.
	inputPointers = {
		dirpad = nil,
		action1 = nil,
		action2 = nil,
		action3 = nil,
	},

	dirpadInput = Number2(0,0),
	dirpadPreviousInput = nil,

	indicators = {}, -- indexed by pointer indexes
	pcLongPressIndicator = nil,
	anim = {
		dirPadRot = Number3(0,0,0),	
	},

	longPressTimer = nil,
	longPressStartPosition = nil,

	clickPointerIndex = nil,
	clickPointerStartPosition = nil,

	chatUnsubmittedCache = "",
	commandCache = {},
	chatInput = nil,
}

local _isActive = function()
	return _state.on and _state.isHomeMenuOpened == false and _state.chatInput == nil
end

local _diffuseLongPressTimer = function()
	if _state.longPressTimer ~= nil then
		_state.longPressTimer:Cancel()
		_state.longPressTimer = nil
		_state.longPressStartPosition = nil
	end
end

local _isChatInputDisplayed = function() return _state.chatInput ~= nil end

local _closeChatInput = function()
	if _state.chatInput == nil then return end
	local input = _state.chatInput

	input:_unfocus()
end

local _submitChatMessage = function()
	if _state.chatInput == nil then return end
	local input = _state.chatInput

	if input.Text ~= "" then 
		local str = input.Text
		local isCommand = false
		if string.sub(str, 1, 1) == "/" then
			isCommand = true
			str = string.sub(str, 2)
		end

		if isCommand then
			table.insert(_state.commandCache, input.Text)
			if Dev.CanRunCommands then
				dostring(str)
			else
				print("⚠️ not authorized to run commands")
			end
		else
			if Client.OnChat ~= nil then Client.OnChat(str) end
		end

		_state.chatUnsubmittedCache = ""
		input.Text = ""
	end

	_closeChatInput()
end

local _displayChatInput = function(isCommand)
	if _state.chatInput ~= nil then return end

	local cache = _state.chatUnsubmittedCache

	local input = ui:createTextInput(cache, "What's on your mind?")
	_state.chatInput = input
	input.parentDidResize = function()
		input.Width = math.min(800, Screen.Width - math.max(Screen.SafeArea.Right,Screen.SafeArea.Left) * 2 - theme.paddingBig * 2)
		input.pos = {Screen.Width * 0.5 - input.Width * 0.5, theme.paddingBig, 0}
	end
	input:parentDidResize()

	input.onSubmit = function()
		_submitChatMessage()
	end
	input.onFocusLost = function()
		_state.chatUnsubmittedCache = input.Text
		input:remove()
		_state.chatInput = nil
		controls.refresh()
	end

	input:focus()
	controls.refresh()
end

local _createDirpad = function()
	local dirpadShape = MutableShape()
	dirpadShape.InnerTransparentFaces = false
	local layout = controls.config.layout.dirpad
	local size = layout.size
	local sizeMinusOne = size - 1
	local framePaletteIndex = dirpadShape.Palette:AddColor(controls.config.frameColor)
	local fillPaletteIndex = dirpadShape.Palette:AddColor(controls.config.fillColor)

	for x = 0, sizeMinusOne do
		for y = 0, sizeMinusOne do
			if x == 0 or x == sizeMinusOne or y == 0 or y == sizeMinusOne then
				dirpadShape:AddBlock(framePaletteIndex, x, y, 0)
			else
				dirpadShape:AddBlock(fillPaletteIndex, x, y, 0)
			end
		end
	end

	dirpadShape:GetBlock(0,0,0):Remove()
	dirpadShape:GetBlock(0,sizeMinusOne,0):Remove()
	dirpadShape:GetBlock(sizeMinusOne,0,0):Remove()
	dirpadShape:GetBlock(sizeMinusOne,sizeMinusOne,0):Remove()

	dirpadShape:GetBlock(1,1,0):Replace(framePaletteIndex)
	dirpadShape:GetBlock(1,sizeMinusOne-1,0):Replace(framePaletteIndex)
	dirpadShape:GetBlock(sizeMinusOne-1,1,0):Replace(framePaletteIndex)
	dirpadShape:GetBlock(sizeMinusOne-1,sizeMinusOne-1,0):Replace(framePaletteIndex)

	local arrow = MutableShape()
	local colorIndex = arrow.Palette:AddColor(controls.config.iconOffColor)
	arrow:AddBlock(colorIndex, 0, 0, 0)
	arrow:AddBlock(colorIndex, 1, 0, 0)
	arrow:AddBlock(colorIndex, 2, 0, 0)
	arrow:AddBlock(colorIndex, 1, 1, 0)
	arrow.Pivot = {1.5, 0, 0}

	local arrowUp = Shape(arrow)
	dirpadShape:AddChild(arrowUp)
	arrowUp.LocalPosition = {dirpadShape.Width * 0.5, dirpadShape.Height - 4, -1}

	local arrowDown = Shape(arrow)
	dirpadShape:AddChild(arrowDown)
	arrowDown.LocalRotation = {0, 0, math.pi}
	arrowDown.LocalPosition = {dirpadShape.Width * 0.5, 4, -1}

	local arrowRight = Shape(arrow)
	dirpadShape:AddChild(arrowRight)
	arrowRight.LocalRotation = {0, 0, math.pi * 1.5}
	arrowRight.LocalPosition = {dirpadShape.Width - 4, dirpadShape.Height * 0.5, -1}

	local arrowLeft = Shape(arrow)
	dirpadShape:AddChild(arrowLeft)
	arrowLeft.LocalRotation = {0, 0, math.pi * 0.5}
	arrowLeft.LocalPosition = {4, dirpadShape.Height * 0.5, -1}

	_state.dirpad = ui:createShape(dirpadShape, {doNotFlip = true})

	_state.dirpad.arrowUp = arrowUp
	_state.dirpad.arrowDown = arrowDown
	_state.dirpad.arrowRight = arrowRight
	_state.dirpad.arrowLeft = arrowLeft
end

local _getOrCreateIndicator = function(index)
	local indicator = _state.indicators[index]
	if indicator ~= nil then
		indicator:show()
		return indicator
	end

	local indicatorShape = MutableShape()

	local layout = controls.config.layout.indicator
	local size = layout.size
	local sizeMinusOne = size - 1

	local c1 = controls.config.frameColor c1.Alpha = 200
	local c2 = controls.config.fillColor c2.Alpha = 200

	local framePaletteIndex = indicatorShape.Palette:AddColor(c1)
	local fillPaletteIndex = indicatorShape.Palette:AddColor(c2)

	for x = 0, sizeMinusOne do
		for y = 0, sizeMinusOne do
			if x == 0 or x == sizeMinusOne or y == 0 or y == sizeMinusOne then
				indicatorShape:AddBlock(framePaletteIndex, x, y, 0)
			else
				indicatorShape:AddBlock(fillPaletteIndex, x, y, 0)
			end
		end
	end

	indicatorShape:GetBlock(0,0,0):Remove()
	indicatorShape:GetBlock(0,sizeMinusOne,0):Remove()
	indicatorShape:GetBlock(sizeMinusOne,0,0):Remove()
	indicatorShape:GetBlock(sizeMinusOne,sizeMinusOne,0):Remove()

	indicatorShape:GetBlock(1,1,0):Replace(framePaletteIndex)
	indicatorShape:GetBlock(1,sizeMinusOne-1,0):Replace(framePaletteIndex)
	indicatorShape:GetBlock(sizeMinusOne-1,1,0):Replace(framePaletteIndex)
	indicatorShape:GetBlock(sizeMinusOne-1,sizeMinusOne-1,0):Replace(framePaletteIndex)
	
	indicator = ui:createShape(indicatorShape, {doNotFlip = true})

	indicatorShape.Physics = PhysicsMode.Disabled
	_state.indicators[index] = indicator

	indicator._hide = function(self)
		ease:cancel(indicator.pivot)
		indicator.pivot.Scale = TOUCH_INDICATOR_SCALE
		self:hide()
	end

	return indicator
end

local _getPCLongPressIndicator = function(createIfNeeded)
	local indicator = _state.pcLongPressIndicator
	if indicator ~= nil then 
		indicator:show()
		return indicator
	end

	local indicatorShape = MutableShape()

	local layout = controls.config.layout.indicator
	local size = layout.size
	local sizeMinusOne = size - 1

	local c1 = controls.config.frameColor c1.Alpha = 200
	local c2 = controls.config.fillColor c2.Alpha = 200

	local framePaletteIndex = indicatorShape.Palette:AddColor(c1)

	for x = 0, sizeMinusOne do
		for y = 0, sizeMinusOne do
			if x == 0 or x == sizeMinusOne or y == 0 or y == sizeMinusOne then
				indicatorShape:AddBlock(framePaletteIndex, x, y, 0)
			end
		end
	end

	indicatorShape:GetBlock(0,0,0):Remove()
	indicatorShape:GetBlock(0,sizeMinusOne,0):Remove()
	indicatorShape:GetBlock(sizeMinusOne,0,0):Remove()
	indicatorShape:GetBlock(sizeMinusOne,sizeMinusOne,0):Remove()

	indicatorShape:AddBlock(framePaletteIndex,1,1,0)
	indicatorShape:AddBlock(framePaletteIndex,1,sizeMinusOne-1,0)
	indicatorShape:AddBlock(framePaletteIndex,sizeMinusOne-1,1,0)
	indicatorShape:AddBlock(framePaletteIndex,sizeMinusOne-1,sizeMinusOne-1,0)
	
	indicator = ui:createShape(indicatorShape, {doNotFlip = true})

	indicatorShape.Physics = PhysicsMode.Disabled
	_state.pcLongPressIndicator = indicator

	indicator._hide = function(self)
		ease:cancel(indicator.pivot)
		indicator.pivot.Scale = TOUCH_INDICATOR_SCALE
		self:hide()
	end

	return indicator
end

local _createActionBtn = function(number)
	local btnShape = MutableShape()
	local n = math.floor(number)
	if n < 1 or n > 3 then error("button number should from 1 to 3") end
	local layout = controls.config.layout["action" .. n]

	local size = layout.size
	local sizeMinusOne = size - 1
	local framePaletteIndex = btnShape.Palette:AddColor(controls.config.frameColor)
	local fillPaletteIndex = btnShape.Palette:AddColor(controls.config.fillColor)

	for x = 0, sizeMinusOne do
		for y = 0, sizeMinusOne do
			if x == 0 or x == sizeMinusOne or y == 0 or y == sizeMinusOne then
				btnShape:AddBlock(framePaletteIndex, x, y, 0)
			else
				btnShape:AddBlock(fillPaletteIndex, x, y, 0)
			end
		end
	end

	btnShape:GetBlock(0,0,0):Remove()
	btnShape:GetBlock(0,sizeMinusOne,0):Remove()
	btnShape:GetBlock(sizeMinusOne,0,0):Remove()
	btnShape:GetBlock(sizeMinusOne,sizeMinusOne,0):Remove()

	btnShape:GetBlock(1,1,0):Replace(framePaletteIndex)
	btnShape:GetBlock(1,sizeMinusOne-1,0):Replace(framePaletteIndex)
	btnShape:GetBlock(sizeMinusOne-1,1,0):Replace(framePaletteIndex)
	btnShape:GetBlock(sizeMinusOne-1,sizeMinusOne-1,0):Replace(framePaletteIndex)

	local icon = MutableShape()
	local colorIndex = icon.Palette:AddColor(controls.config.iconOffColor)
	local offset = 0
	for i = 1,n do
		for y = 0, 3 do
			icon:AddBlock(colorIndex, offset, y, 0)
		end
		offset = offset + 2
	end

	icon.Pivot = {icon.Width * 0.5, icon.Height * 0.5, icon.Depth * 0.5}
	btnShape:AddChild(icon)
	icon.LocalPosition = {btnShape.Width * 0.5, btnShape.Height * 0.5, 0}
	
	local btn = ui:createShape(btnShape, {doNotFlip = true})

	btn.icon = icon
	
	_state["action" .. n] = btn
end

local _pointerIsDown = function(pointerIndex) return _state.pointersDown[pointerIndex] == true end
local _pointerIsUp = function(pointerIndex) return not _pointerIsDown(pointerIndex) end

-- Sets pointer as being in "down" state.
-- Returns true when the operation is successful.
local _setPointerDown = function(pointerIndex)
	if _pointerIsDown(pointerIndex) then return end
	_diffuseLongPressTimer()
	_state.pointersDown[pointerIndex] = true
	_state.nbPointersDown = _state.nbPointersDown + 1
	return true
end

-- Sets pointer as being in "up" state.
-- Returns true when the operation is successful.
local _setPointerUp = function(pointerIndex, pointerEvent)
	if _pointerIsUp(pointerIndex) then return end
	_diffuseLongPressTimer()

	_state.pointersDown[pointerIndex] = false

	if _state.touchZoomAndDrag2Pointers ~= nil then
		if _state.touchZoomAndDrag2Pointers[1].index == pointerIndex then
			_state.touchDragPointer = _state.touchZoomAndDrag2Pointers[2]
		else
			_state.touchDragPointer = _state.touchZoomAndDrag2Pointers[1]
		end
		_state.touchZoomAndDrag2Pointers = nil
		if _state.drag2Started then
			if Pointer.IsHidden == false then
				if Pointer.Drag2End ~= nil then Pointer.Drag2End(POINTER_INDEX_TOUCH) end
			end
			_state.drag2Started = false
		end
	end

	if _state.touchDragPointer ~= nil and _state.touchDragPointer.index == pointerIndex then
		_state.touchDragPointer = nil
		if _state.dragStarted then
			if Pointer.IsHidden == false then
				if Pointer.DragEnd ~= nil then Pointer.DragEnd(pointerEvent) end -- pointerEvent can be nil
			end
			_state.dragStarted = false
		end
	end

	if _isPC then
		if pointerIndex == POINTER_INDEX_MOUSE_LEFT then
			if _state.dragStarted then
				if Pointer.IsHidden == false then
					if Pointer.DragEnd ~= nil then Pointer.DragEnd(pointerEvent) end -- pointerEvent can be nil
				end
				_state.dragStarted = false
			end
		elseif pointerIndex == POINTER_INDEX_MOUSE_RIGHT then
			if _state.drag2Started then
				if Pointer.IsHidden == false then
					if Pointer.Drag2End ~= nil then Pointer.Drag2End(POINTER_INDEX_MOUSE) end
				end
				_state.drag2Started = false
			end
		end
	end

	_state.nbPointersDown = _state.nbPointersDown - 1
	return true
end

-- Sets pointer as responsible for Pointer.Drag calls.
-- Return true when the operation is successful (only works for touch events)
local _setTouchDragPointer = function(pointerEvent)
	local pointerIndex = pointerEvent.Index
	if _state.touchDragPointer ~= nil then return false end -- there can be only one touchDragPointer
	if _state.touchZoomAndDrag2Pointers ~= nil then return false end -- no drag pointer if zoomAndDrag2 pointer is set
	if _pointerIndexWithin(pointerIndex, POINTER_INDEX_TOUCH_1, POINTER_INDEX_TOUCH_2, POINTER_INDEX_TOUCH_3) == false then 
		return false -- index not valid
	end
	_state.touchDragPointer = {index = pointerIndex, pos = Number2(pointerEvent.X * Screen.Width, pointerEvent.Y * Screen.Height)}
	_state.dragStarted = false
	return true
end

local _setTouchZoomAndDrag2Pointer = function(pointerEvent)
	local pointerIndex = pointerEvent.Index
	if _state.touchDragPointer == nil then return end -- touchDragPointer needs to be set
	if pointerIndex == _state.touchDragPointer.index then return end
	if _pointerIndexWithin(pointerIndex, POINTER_INDEX_TOUCH_1, POINTER_INDEX_TOUCH_2, POINTER_INDEX_TOUCH_3) == false then 
		return false -- index not valid
	end
	-- touchDragPointer becomes nil at this point, no need to check anything else.
	-- touchDragPointer is going to be redefined when releasing one touch.

	_state.touchZoomAndDrag2Pointers = {
		_state.touchDragPointer,
		{index = pointerIndex, pos = Number2(pointerEvent.X * Screen.Width, pointerEvent.Y * Screen.Height)}
	}

	local dx = _state.touchZoomAndDrag2Pointers[1].pos.X - _state.touchZoomAndDrag2Pointers[2].pos.X
	local dy = _state.touchZoomAndDrag2Pointers[1].pos.Y - _state.touchZoomAndDrag2Pointers[2].pos.Y 

	_state.previousDistanceBetweenTouches = math.sqrt(dx * dx + dy * dy)

	_state.touchDragPointer = nil
	_state.drag2Started = false
	return true
end

local _activateDirPad = function(x, y, pointerEventIndex, eventType)
	if not _isActive() then return end
	if not _state.dirpad or _state.dirpad:isVisible() == false then return end

	local checkIfWithinRadius = false

	if eventType == "down" then
		if _state.inputPointers.dirpad ~= nil then return false end
		checkIfWithinRadius = true
	elseif eventType == "drag" or eventType == "up" then
		if _state.inputPointers.dirpad ~= pointerEventIndex then return false end
		if eventType == "up" then
			_state.inputPointers.dirpad = nil
			if Client.DirectionalPad ~= nil then Client.DirectionalPad(0, 0) end

			ease:cancel(_state.anim)
			ease:outBack(_state.anim, 0.22, {
				onUpdate = function(o)
					_state.dirpad.pivot.LocalRotation = o.dirPadRot
				end
			}).dirPadRot = {0,0,0}

			_state.dirpad.arrowLeft.Palette[1].Color = controls.config.iconOffColor
			_state.dirpad.arrowRight.Palette[1].Color = controls.config.iconOffColor
			_state.dirpad.arrowDown.Palette[1].Color = controls.config.iconOffColor
			_state.dirpad.arrowUp.Palette[1].Color = controls.config.iconOffColor

			return true -- capture
		end
	end

	local dirpad = _state.dirpad
	local center = Number2(dirpad.pos.X + dirpad.Width * 0.5, dirpad.pos.Y + dirpad.Height * 0.5)
	local dirPadHalfWidth = dirpad.Width * 0.5
	local sqrRadius = dirPadHalfWidth ^ 2 + dirPadHalfWidth ^ 2
	local sqrPointerDistance = (x - center.X) ^ 2 + (y - center.Y) ^ 2

	local r = dirPadHalfWidth * DIR_PAD_MIN_RADIUS
	local minSqrRadius = r ^ 2 + r ^ 2

	if not checkIfWithinRadius or sqrPointerDistance < sqrRadius then
		local radius = math.sqrt(sqrRadius)

		local dirpadInput = Number2(0,0)
		local rot = Number3(0,0,0)

		if sqrPointerDistance <= minSqrRadius then
			-- Too close from pad center to define direction,
			-- keep current _state.dirpadInput.
			if eventType == "down" then
				_state.inputPointers.dirpad = pointerEventIndex
			end
			_state.dirpadPreviousInput = dirpadInput
			return true
		else

			local a = math.atan(y - center.Y, x - center.X) + math.pi
			if a <= DIR_PAD_STEP_1 then 
				dirpadInput.X = -1.0
				dirpadInput.Y = 0
			elseif a <= DIR_PAD_STEP_2 then 
				dirpadInput.X = -1.0
				dirpadInput.Y = -1.0
			elseif a <= DIR_PAD_STEP_3 then 
				dirpadInput.X = 0
				dirpadInput.Y = -1.0
			elseif a <= DIR_PAD_STEP_4 then 
				dirpadInput.X = 1.0
				dirpadInput.Y = -1.0
			elseif a <= DIR_PAD_STEP_5 then 
				dirpadInput.X = 1.0
				dirpadInput.Y = 0
			elseif a <= DIR_PAD_STEP_6 then 
				dirpadInput.X = 1.0
				dirpadInput.Y = 1.0
			elseif a <= DIR_PAD_STEP_7 then 
				dirpadInput.X = 0
				dirpadInput.Y = 1.0
			elseif a <= DIR_PAD_STEP_8 then 
				dirpadInput.X = -1.0
				dirpadInput.Y = 1.0
			else
				dirpadInput.X = -1.0
				dirpadInput.Y = 0
			end
		end

		rot.Y = -dirpadInput.X
		rot.X = dirpadInput.Y

		dirpadInput:Normalize()
		rot:Normalize()

		Client.DirectionalPad(dirpadInput.X, dirpadInput.Y)
		
		ease:cancel(_state.anim)
		ease:outBack(_state.anim, 0.22, {
			onUpdate = function(o)
				dirpad.pivot.LocalRotation = o.dirPadRot
			end
		}).dirPadRot = rot * 0.4

		local dirChanged = false

		if eventType == "down" then
			_state.inputPointers.dirpad = pointerEventIndex
			if dirpadInput.SquaredLength > 0 then
				dirChanged = true
			end
		elseif eventType == "drag" and dirpadInput.SquaredLength > 0 and dirpadInput ~= _state.dirpadPreviousInput then
			dirChanged = true
		end

		if dirChanged then
			Client:HapticFeedback()

			if dirpadInput.X < 0 then
				dirpad.arrowLeft.Palette[1].Color = controls.config.iconOnColor
				dirpad.arrowRight.Palette[1].Color = controls.config.iconOffColor
			elseif dirpadInput.X > 0 then
				dirpad.arrowLeft.Palette[1].Color = controls.config.iconOffColor
				dirpad.arrowRight.Palette[1].Color = controls.config.iconOnColor
			else
				dirpad.arrowLeft.Palette[1].Color = controls.config.iconOffColor
				dirpad.arrowRight.Palette[1].Color = controls.config.iconOffColor
			end

			if dirpadInput.Y < 0 then
				dirpad.arrowDown.Palette[1].Color = controls.config.iconOnColor
				dirpad.arrowUp.Palette[1].Color = controls.config.iconOffColor
			elseif dirpadInput.Y > 0 then
				dirpad.arrowDown.Palette[1].Color = controls.config.iconOffColor
				dirpad.arrowUp.Palette[1].Color = controls.config.iconOnColor
			else
				dirpad.arrowDown.Palette[1].Color = controls.config.iconOffColor
				dirpad.arrowUp.Palette[1].Color = controls.config.iconOffColor
			end
		end

		_state.dirpadPreviousInput = dirpadInput
		return true
	end
end

local _activateActionBtn = function(number, x, y, pointerEventIndex, eventType)
	local n = math.floor(number)
	if n < 1 or n > 3 then error("activateActionBtn: button number should from 1 to 3") end
	local btn = _state["action" .. n]
	if btn == nil then return end
	if btn:isVisible() == false then return end

	if eventType == "down" then
		if _state.inputPointers["action" .. n] ~= nil then 
			return false -- button already pressed
		end

		if x >= btn.pos.X and x <= btn.pos.X + btn.Width
			and y >= btn.pos.Y and y <= btn.pos.Y + btn.Height then

			_state.inputPointers["action" .. n] = pointerEventIndex
			btn.pivot.Scale = controls.config.pressScale

			if btn.icon ~= nil then
				if btn.icon.Color then
					btn.icon.Color = controls.config.iconOnColor
				else
					btn.icon.Palette[1].Color = controls.config.iconOnColor
				end
			end

			Client:HapticFeedback()

			local callback = Client["Action" .. n]
			if callback then callback() end

			return true -- capture
		else
			return false
		end

	elseif eventType == "up" then
		if _state.inputPointers["action" .. n] ~= pointerEventIndex then 
			return false
		end
		
		_state.inputPointers["action" .. n] = nil
		
		btn.pivot.Scale = 1.0

		if btn.icon ~= nil then
			if btn.icon.Color then
				btn.icon.Color = controls.config.iconOffColor
			else
				btn.icon.Palette[1].Color = controls.config.iconOffColor
			end
		end

		local callback = Client["Action" .. n .. "Release"]
		if callback then callback() end

		return true -- capture
	end
end

local _activate = function(x,y,pointerEventIndex, eventType)
	if not _isActive() then return end

	if _activateDirPad(x,y,pointerEventIndex,eventType) then return true
	elseif _activateActionBtn(1, x,y,pointerEventIndex,eventType) then return true
	elseif _activateActionBtn(2, x,y,pointerEventIndex,eventType) then return true
	elseif _activateActionBtn(3, x,y,pointerEventIndex,eventType) then return true end
end

_state.downListener = LocalEvent:Listen(LocalEvent.Name.PointerDown,
function(pointerEvent)
	if not _isActive() then return end
	if _setPointerDown(pointerEvent.Index) == false then return end

	if Pointer.IsHidden == false then -- Pointer shown

		if _isPC then
			if pointerEvent.Index == POINTER_INDEX_MOUSE_LEFT then
				if Pointer.Down ~= nil then Pointer.Down(pointerEvent) end
				if Pointer.Click ~= nil then 
					local x, y = pointerEvent.X * Screen.Width, pointerEvent.Y * Screen.Height
					_state.clickPointerIndex = pointerEvent.Index
					_state.clickPointerStartPosition = Number2(x,y)
				end

				if Pointer.LongPress ~= nil then
					local px, py = pointerEvent.X, pointerEvent.Y
					local x, y = px * Screen.Width, py * Screen.Height
					_state.longPressStartPosition = Number2(x,y)
					_state.longPressTimer = Timer(LONG_PRESS_DELAY_1, function()
						local indicator = _getPCLongPressIndicator(true)
						indicator.pos = {x - indicator.Width * 0.5, y - indicator.Height * 0.5, 0}
						indicator.pivot.Scale = TOUCH_INDICATOR_LONG_PRESS_SCALE
						ease:inBack(indicator.pivot,LONG_PRESS_DELAY_2).Scale = SCALE_ZERO
						_state.longPressTimer = Timer(LONG_PRESS_DELAY_2, function()
							_state.longPressTimer = nil
							_state.longPressStartPosition = nil
							if Pointer.LongPress ~= nil then
								_state.clickPointerIndex = nil -- diffuse click
								Client:HapticFeedback()
								indicator:_hide()
								local pe = PointerEvent(px, py, 0.0, 0.0, true, POINTER_INDEX_MOUSE_LEFT)
								Pointer.LongPress(pe)
							end
						end)
					end)
				end
			end
		elseif _isMobile then
			local x, y = pointerEvent.X * Screen.Width, pointerEvent.Y * Screen.Height
			
			local indicator = _getOrCreateIndicator(pointerEvent.Index)
			indicator.pos = {x - indicator.Width * 0.5, y - indicator.Height * 0.5, 0}

			-- only Action1 is supposed to be displayed when Pointer is shown
			if _activate(x, y, pointerEvent.Index, "down") == true then
				return true -- capture event
			else			
				if _setTouchDragPointer(pointerEvent) == true then
					if Pointer.Down ~= nil then Pointer.Down(pointerEvent) end

					if Pointer.Click ~= nil then 
						_state.clickPointerIndex = pointerEvent.Index
						_state.clickPointerStartPosition = Number2(x,y)
					end

					if Pointer.LongPress ~= nil then
						_state.longPressStartPosition = Number2(x,y)
						_state.longPressTimer = Timer(LONG_PRESS_DELAY_1, function()
							local indicator = _getOrCreateIndicator(pointerEvent.Index)
							indicator.pivot.Scale = TOUCH_INDICATOR_LONG_PRESS_SCALE
							ease:inBack(indicator.pivot,LONG_PRESS_DELAY_2).Scale = TOUCH_INDICATOR_SCALE
							_state.longPressTimer = Timer(LONG_PRESS_DELAY_2, function()
								_state.longPressTimer = nil
								_state.longPressStartPosition = nil
								if _state.touchDragPointer ~= nil then
									if Pointer.LongPress ~= nil then
										_state.clickPointerIndex = nil -- diffuse click
										Client:HapticFeedback()
										local pe = PointerEvent(_state.touchDragPointer.pos.X / Screen.Width,
																_state.touchDragPointer.pos.Y / Screen.Height,
																0.0, 0.0, true,
																_state.touchDragPointer.index)
										Pointer.LongPress(pe)
									end
								end
							end)
						end)
					end

				elseif _setTouchZoomAndDrag2Pointer(pointerEvent) == true then
					-- drag2 and/or zoom about to start, but nothing to do here
				end
			end
		end

	else -- Pointer hidden

		if _isPC then
			if pointerEvent.Index == POINTER_INDEX_MOUSE_LEFT and Client.Action2 ~= nil then
				Client.Action2()
				return true -- capture event
			elseif pointerEvent.Index == POINTER_INDEX_MOUSE_RIGHT and Client.Action3 ~= nil then
				Client.Action3()
				return true -- capture event
			end
		elseif _isMobile then
			local x, y = pointerEvent.X * Screen.Width, pointerEvent.Y * Screen.Height

			local indicator = _getOrCreateIndicator(pointerEvent.Index)
			indicator.pos = {x - indicator.Width * 0.5, y - indicator.Height * 0.5, 0}

			if _activate(x, y, pointerEvent.Index, "down") == true then
				return true -- capture event
			end
		end
	end
end)

_state.dragListener = LocalEvent:Listen(LocalEvent.Name.PointerDrag,
function(pointerEvent)
	if not _isActive() then return end
	if not _pointerIsDown(pointerEvent.Index) then return end

	local x, y = pointerEvent.X * Screen.Width, pointerEvent.Y * Screen.Height

	if Pointer.IsHidden == false then -- Pointer shown

		if _isPC then

			if _pointerIndexWithin(pointerEvent.Index, POINTER_INDEX_MOUSE_LEFT, POINTER_INDEX_MOUSE_RIGHT) then

				if _state.longPressTimer ~= nil then
					local diff = Number2(x,y) - _state.longPressStartPosition
					if diff.SquaredLength > LONG_PRESS_MOVE_SQR_EPSILON then
						_diffuseLongPressTimer()
						local indicator = _getPCLongPressIndicator()
						if indicator then indicator:_hide() end
					end
				end

				if _state.clickPointerIndex ~= nil then
					local diff = Number2(x,y) - _state.clickPointerStartPosition
					if diff.SquaredLength > CLICK_MOVE_SQR_EPSILON then
						_state.clickPointerIndex = nil
					end
				end

				if pointerEvent.Index == POINTER_INDEX_MOUSE_LEFT then

					if _state.dragStarted == false then
						_state.dragStarted = true
						if Pointer.DragBegin ~= nil then
							Pointer.DragBegin(PointerEvent( x / Screen.Width,
							 								y / Screen.Height,
							 								x - pointerEvent.DX, 
							 								y - pointerEvent.DY,
							 								true,
							 								pointerEvent.Index )) 
						end
					end

					if Pointer.Drag ~= nil then Pointer.Drag(pointerEvent) end

					if Camera.OnPointerDrag ~= nil then Camera:OnPointerDrag(pointerEvent) end

				elseif pointerEvent.Index == POINTER_INDEX_MOUSE_RIGHT then

					if _state.drag2Started == false then
						_state.drag2Started = true
						if Pointer.Drag2Begin ~= nil then
							Pointer.Drag2Begin(PointerEvent( x / Screen.Width,
							 								y / Screen.Height,
							 								x - pointerEvent.DX, 
							 								y - pointerEvent.DY,
							 								true,
							 								pointerEvent.Index )) 
						end
					end
					if Pointer.Drag2 ~= nil then Pointer.Drag2(pointerEvent) end

				end

			end

		elseif _isMobile then
			local indicator = _getOrCreateIndicator(pointerEvent.Index)
			indicator.pos = {x - indicator.Width * 0.5, y - indicator.Height * 0.5, 0}

			if _activateDirPad(x, y, pointerEvent.Index, "drag") == true then
				return true
			elseif _state.touchDragPointer ~= nil and _state.touchDragPointer.index == pointerEvent.Index then 

				if _state.dragStarted == false then
					_state.dragStarted = true
					if Pointer.DragBegin ~= nil then
						Pointer.DragBegin(PointerEvent( _state.touchDragPointer.pos.X,
						 								_state.touchDragPointer.pos.Y,
						 								x - _state.touchDragPointer.pos.X, 
						 								y - _state.touchDragPointer.pos.Y,
						 								true,
						 								pointerEvent.Index )) 
					end
				end

				if _state.longPressTimer ~= nil then
					local diff = Number2(x,y) - _state.longPressStartPosition
					if diff.SquaredLength > LONG_PRESS_MOVE_SQR_EPSILON then
						_diffuseLongPressTimer()
						ease:cancel(indicator.pivot)
						indicator.pivot.Scale = TOUCH_INDICATOR_SCALE
					end
				end

				if _state.clickPointerIndex ~= nil then
					local diff = Number2(x,y) - _state.clickPointerStartPosition
					if diff.SquaredLength > CLICK_MOVE_SQR_EPSILON then
						_state.clickPointerIndex = nil
					end
				end

				_state.touchDragPointer.pos.X = x _state.touchDragPointer.pos.Y = y

				if Pointer.Drag ~= nil then Pointer.Drag(pointerEvent) end

				-- TODO: OnPointerDrag callbacks should not be handled here
				-- IDEA: add AnalogPad event, notify here
				-- Client.AnalogPad would register to it, same for Camera.
				if Camera.OnPointerDrag ~= nil then
					Camera:OnPointerDrag(pointerEvent)
				end
			elseif _state.touchZoomAndDrag2Pointers ~= nil then
				if pointerEvent.Index == _state.touchZoomAndDrag2Pointers[1].index or pointerEvent.Index == _state.touchZoomAndDrag2Pointers[2].index then
					local prevX
					local prevY
					local x2
					local y2

					if pointerEvent.Index == _state.touchZoomAndDrag2Pointers[1].index then
						prevX = _state.touchZoomAndDrag2Pointers[1].pos.X
						prevY = _state.touchZoomAndDrag2Pointers[1].pos.Y
						x2 = _state.touchZoomAndDrag2Pointers[2].pos.X
						y2 = _state.touchZoomAndDrag2Pointers[2].pos.Y

						_state.touchZoomAndDrag2Pointers[1].pos.X = x _state.touchZoomAndDrag2Pointers[1].pos.Y = y
					elseif pointerEvent.Index == _state.touchZoomAndDrag2Pointers[2].index then
						prevX = _state.touchZoomAndDrag2Pointers[2].pos.X
						prevY = _state.touchZoomAndDrag2Pointers[2].pos.Y
						x2 = _state.touchZoomAndDrag2Pointers[1].pos.X
						y2 = _state.touchZoomAndDrag2Pointers[1].pos.Y

						_state.touchZoomAndDrag2Pointers[2].pos.X = x _state.touchZoomAndDrag2Pointers[2].pos.Y = y
					end

					if _state.drag2Started == false then
						_state.drag2Started = true
						if Pointer.Drag2Begin ~= nil then

							local midXBefore = (prevX + x2) * 0.5
							local midYBefore = (prevY + y2) * 0.5

							local midXAfter = (x + x2) * 0.5
							local midYAfter = (y + y2) * 0.5

							local dx = midXAfter - midXBefore
							local dy = midYAfter - midYBefore

							Pointer.Drag2Begin(PointerEvent( midXAfter / Screen.Width,
							 								 midYAfter / Screen.Width,
							 								 dx, 
							 								 dy,
							 								 true,
							 								 POINTER_INDEX_TOUCH )) 
						end
					end

					if Pointer.Drag2 ~= nil then

						local midXBefore = (prevX + x2) * 0.5
						local midYBefore = (prevY + y2) * 0.5

						local midXAfter = (x + x2) * 0.5
						local midYAfter = (y + y2) * 0.5

						local dx = midXAfter - midXBefore
						local dy = midYAfter - midYBefore

						Pointer.Drag2(PointerEvent(	midXAfter / Screen.Width,
													midYAfter / Screen.Height,
													dx,
													dy,
													true,
													POINTER_INDEX_TOUCH ))
					end

					if Pointer.Zoom ~= nil then
						local dx = x - x2
						local dy = y - y2

						local distanceBetweenTouches = math.sqrt(dx * dx + dy * dy)

						local previousDistanceFromApex = (_state.previousDistanceBetweenTouches * 0.5) / TAN_TOUCH_ZOOM_ANGLE
						local distanceFromApex = (distanceBetweenTouches * 0.5) / TAN_TOUCH_ZOOM_ANGLE
						_state.previousDistanceBetweenTouches = distanceBetweenTouches

						Pointer.Zoom(previousDistanceFromApex - distanceFromApex)
					end
				end
			end
		end

	else -- Pointer hidden

		if _isMobile then
			local indicator = _getOrCreateIndicator(pointerEvent.Index)
			indicator.pos = {x - indicator.Width * 0.5, y - indicator.Height * 0.5, 0}

			if _activateDirPad(x, y, pointerEvent.Index, "drag") == true then
				return true
			end
		end

		if Client.AnalogPad ~= nil then
			Client.AnalogPad(pointerEvent.DX, pointerEvent.DY)
		end
	end
end)

_state.moveListener = LocalEvent:Listen(LocalEvent.Name.PointerMove,
function(pointerEvent)
	if not _isActive() then return end
	if Pointer.IsHidden == false then -- Pointer shown

	else
		if Client.AnalogPad ~= nil then
			Client.AnalogPad(pointerEvent.DX, pointerEvent.DY)
		end
	end
end)

_state.moveListener = LocalEvent:Listen(LocalEvent.Name.PointerWheel,
function(delta)
	if not _isActive() then return end
	if Pointer.IsHidden == false then -- Pointer shown
		if Pointer.Zoom ~= nil then Pointer.Zoom(delta) end
	end
end)

_state.upListener = LocalEvent:Listen(LocalEvent.Name.PointerUp,
function(pointerEvent)
	if not _isActive() then return end
	if not _pointerIsDown(pointerEvent.Index) then return end
	local touchDragPointer = _state.touchDragPointer.index
	_setPointerUp(pointerEvent.Index, pointerEvent)

	if Pointer.IsHidden == false then -- Pointer shown

		if _isPC then

			if pointerEvent.Index == POINTER_INDEX_MOUSE_LEFT and Pointer.Up ~= nil then Pointer.Up(pointerEvent) end

		elseif _isMobile then

			local indicator = _getOrCreateIndicator(pointerEvent.Index)
			indicator:_hide()

			if pointerEvent.Index == touchDragPointer and Pointer.Up ~= nil then
				Pointer.Up(pointerEvent)

			elseif _activate(x, y, pointerEvent.Index, "up") == true then
				return true
			end
		end 

		if _state.clickPointerIndex ~= nil and pointerEvent.Index == _state.clickPointerIndex then
			if Pointer.Click ~= nil then Pointer.Click(pointerEvent) end
			_state.clickPointerIndex = nil
		end

	else -- Pointer hidden

		if _isPC then

			if pointerEvent.Index == POINTER_INDEX_MOUSE_LEFT and Client.Action2Release ~= nil then
				Client.Action2Release()
				return true
			elseif pointerEvent.Index == POINTER_INDEX_MOUSE_RIGHT and Client.Action3Release ~= nil then
				Client.Action3Release()
				return true
			end

		elseif _isMobile then

			local indicator = _getOrCreateIndicator(pointerEvent.Index)
			indicator:_hide()

			if _activate(x, y, pointerEvent.Index, "up") == true then
				return true
			end
		end 
	end
end)

_state.cancelListener = LocalEvent:Listen(LocalEvent.Name.PointerCancel,
function(pointerIndex)
	if not _isActive() then return end
	if not _pointerIsDown(pointerEvent.Index) then return end
	_setPointerUp(pointerIndex, nil) -- Cancel doesn't communicate a pointer event, only a pointer index

	if _isMobile then
		local indicator = _getOrCreateIndicator(pointerIndex)
		indicator:_hide()
	
		if _activateDirPad(x, y, pointerIndex, "up") == true then
			return true
		end
	end
end)

_state.openChatListener = LocalEvent:Listen(LocalEvent.Name.OpenChat,
function()
	if _isChatInputDisplayed() then
		_closeChatInput()
	else
		_displayChatInput(false)
	end
end)

_state.keyboardListener = LocalEvent:Listen(LocalEvent.Name.KeyboardInput,
function(char, keyCode, modifiers, down)
	if not _isActive() then return end
	if down then
		if _state.keysDown[keyCode] then 
			return
		else
			_state.keysDown[keyCode] = true
		end
	else
		_state.keysDown[keyCode] = nil
	end

	local updateDirPad = false
	local dirpadInput = _state.dirpadInput

	if keyCode == codes.SPACE then
		if down then
			if Client.Action1 ~= nil then Client.Action1() end
		else
			if Client.Action1Release ~= nil then Client.Action1Release() end
		end

	elseif keyCode == codes.RETURN or keyCode == codes.NUMPAD_RETURN then
		if down then
			_displayChatInput(false)
		end

	elseif keyCode == codes.SLASH then
		if down then
			_displayChatInput(true)
		end

	elseif keyCode == codes.KEY_W or keyCode == codes.UP then
		if down then
			if dirpadInput.Y <= 0 then dirpadInput.Y = 1.0 updateDirPad = true end
		else 
			if dirpadInput.Y > 0 then dirpadInput.Y = 0 updateDirPad = true end
		end
	elseif keyCode == codes.KEY_S or keyCode == codes.DOWN then
		if down then
			if dirpadInput.Y >= 0 then dirpadInput.Y = -1.0 updateDirPad = true end
		else 
			if dirpadInput.Y < 0 then dirpadInput.Y = 0 updateDirPad = true end
		end
	elseif keyCode == codes.KEY_D or keyCode == codes.RIGHT then
		if down then
			if dirpadInput.X <= 0 then dirpadInput.X = 1.0 updateDirPad = true end
		else 
			if dirpadInput.X > 0 then dirpadInput.X = 0 updateDirPad = true end
		end
	elseif keyCode == codes.KEY_A or keyCode == codes.LEFT then
		if down then
			if dirpadInput.X >= 0 then dirpadInput.X = -1.0 updateDirPad = true end
		else 
			if dirpadInput.X < 0 then dirpadInput.X = 0 updateDirPad = true end
		end
	end

	if updateDirPad and Client.DirectionalPad ~= nil then
		dirpadInput:Normalize()
		Client.DirectionalPad(dirpadInput.X, dirpadInput.Y)
	end
end)

controls.pointerShownListener = LocalEvent:Listen(LocalEvent.Name.PointerShown,
function()
	controls.refresh()
end)

controls.pointerHiddenListener = LocalEvent:Listen(LocalEvent.Name.PointerHidden,
function()
	controls.refresh()
end)

controls.refresh = function()

	if not _state.dirpad then _createDirpad() end
	if not _state.action1 then _createActionBtn(1) end
	if not _state.action2 then _createActionBtn(2) end
	if not _state.action3 then _createActionBtn(3) end

	_state.dirpad:hide()
	_state.action1:hide()
	_state.action2:hide()
	_state.action3:hide()
	
	if _state.on then
		if _isMobile and _state.chatInput == nil then
			if Client.DirectionalPad ~= nil then _state.dirpad:show() end
			if Client.Action1 ~= nil or Client.Action1Release ~= nil then _state.action1:show() end
			if Pointer.IsHidden and (Client.Action2 ~= nil or Client.Action2Release_ ~= nil) then _state.action2:show() end
			if Pointer.IsHidden and (Client.Action3 ~= nil or Client.Action3Release ~= nil) then _state.action3:show() end
		end
	end

	local left = {}
	local right = {}

	local elementNames = {"dirpad", "action1", "action2", "action3"}

	for _, elementName in ipairs(elementNames) do

		local btn = _state[elementName]
		if btn == nil then goto continue end

		local layout = controls.config.layout[elementName]
		if layout == nil then goto continue end

		if layout.pos[1] < 0 then 
			table.insert(right, {element = btn, layout = layout})
		else
			table.insert(left, {element = btn, layout = layout})
		end

		::continue::
	end

	local halfScreenHeight = Screen.Height * 0.5
	local maxWidthOccupancy = Screen.Width * 0.4

	local scale = 1.0
	::placeLeft::
	local bottom = nil
	local top = nil
	local leftEdge = nil
	local rightEdge = nil
	for _, entry in ipairs(left) do
		entry.element.object.Scale = scale * ui.kShapeScale
		entry.element.pos.X = Screen.SafeArea.Left + entry.layout.pos[1] * ui.kShapeScale * scale
		entry.element.pos.Y = Screen.SafeArea.Bottom + entry.layout.pos[2] * ui.kShapeScale * scale
		
		if scale == 1.0 then
			if bottom == nil or bottom > entry.element.pos.Y then bottom = entry.element.pos.Y end
			if top == nil or top < entry.element.pos.Y + entry.element.Height then top = entry.element.pos.Y + entry.element.Height end
			if leftEdge == nil or leftEdge > entry.element.pos.X then leftEdge = entry.element.pos.X end
			if rightEdge == nil or rightEdge < entry.element.pos.X + entry.element.Width then rightEdge = entry.element.pos.X + entry.element.Width end
		end
	end

	if (top ~= nil and top > halfScreenHeight) or (rightEdge ~= nil and rightEdge > maxWidthOccupancy) then
		local scaleV = (halfScreenHeight - bottom) / (top - bottom)
		local scaleH = (maxWidthOccupancy - leftEdge) / (rightEdge - leftEdge)
		scale = math.min(scaleV, scaleH)
		goto placeLeft
	end

	scale = 1.0
	::placeRight::
	bottom = nil
	top = nil
	leftEdge = nil
	rightEdge = nil
	for _, entry in ipairs(right) do
		entry.element.object.Scale = scale * ui.kShapeScale
		entry.element.pos.X = Screen.Width - Screen.SafeArea.Right - entry.element.Width + entry.layout.pos[1] * ui.kShapeScale * scale
		entry.element.pos.Y = Screen.SafeArea.Bottom + entry.layout.pos[2] * ui.kShapeScale * scale

		if scale == 1.0 then
			if bottom == nil or bottom > entry.element.pos.Y then bottom = entry.element.pos.Y end
			if top == nil or top < entry.element.pos.Y + entry.element.Height then top = entry.element.pos.Y + entry.element.Height end
			if leftEdge == nil or leftEdge > entry.element.pos.X then leftEdge = entry.element.pos.X end
			if rightEdge == nil or rightEdge < entry.element.pos.X + entry.element.Width then rightEdge = entry.element.pos.X + entry.element.Width end
		end
	end

	if (top ~= nil and top > halfScreenHeight) or (leftEdge ~= nil and leftEdge < Screen.Width - maxWidthOccupancy) then
		local scaleV = (halfScreenHeight - bottom) / (top - bottom)
		local scaleH = (maxWidthOccupancy - (Screen.Width - rightEdge)) / (rightEdge - leftEdge)
		scale = math.min(scaleV, scaleH)
		goto placeRight
	end
end

controls.screenDidResizeListener = LocalEvent:Listen(LocalEvent.Name.ScreenDidResize, controls.refresh)
controls.action1Listener = LocalEvent:Listen(LocalEvent.Name.DirPadSet, controls.refresh)
controls.action2Listener = LocalEvent:Listen(LocalEvent.Name.Action1Set, controls.refresh)
controls.action3Listener = LocalEvent:Listen(LocalEvent.Name.Action2Set, controls.refresh)
controls.dirPadListener = LocalEvent:Listen(LocalEvent.Name.Action3Set, controls.refresh)
controls.homeMenuOpenedListener = LocalEvent:Listen(LocalEvent.Name.HomeMenuOpened, function()
	_state.isHomeMenuOpened = true
	controls.refresh()
end)
controls.homeMenuClosedListener = LocalEvent:Listen(LocalEvent.Name.HomeMenuClosed, function()
	_state.isHomeMenuOpened = false
	controls.refresh()
end)

controls.turnOn = function(self)
	if self ~= controls then error("controls:turnOn should be called with `:`", 2) end
	if _state.on == true then return end -- already on
	_state.on = true
	self:refresh()
end

controls.turnOff = function(self)
	if self ~= controls then error("controls:turnOff should be called with `:`", 2) end
	if _state.on == false then return end -- already off
	_state.on = false
	self:refresh()
end

controls.setButtonIcon = function(self, buttonName, shapeOrString)
	buttonName = string.lower(buttonName)

	local btn = _state[buttonName]
	if btn == nil then return end

	btn.shape:RemoveChildren()

	local icon
	if type(shapeOrString) == "string" then
		icon = Text()
		icon.Text = shapeOrString
		icon.Color = self.config.iconOffColor
		icon.BackgroundColor = Color(0,0,0,0) 
		icon.IsUnlit = true
		icon.Layers = btn.shape.Layers
		icon.Scale = 3
		btn.shape:AddChild(icon)
		icon.LocalPosition = {btn.shape.Width * 0.5, btn.shape.Height * 0.5, -50}
	end

	btn.icon = icon
end

controls:refresh()

return controls
