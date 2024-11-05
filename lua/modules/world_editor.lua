local worldEditor = {}

local sfx = require("sfx")
local ease = require("ease")

function requireSkybox()
	local skybox = {}
	skybox.load = function(config, func)
		local defaultConfig = {
			scale = 1000,
			url = "https://e7.pngegg.com/pngimages/57/621/png-clipart-skybox-texture-mapping-panorama-others-texture-atmosphere.png",
		}

		local url = config.url or defaultConfig.url
		local scale = config.scale or defaultConfig.scale
		if func == nil then
			func = function(obj)
				obj:SetParent(Camera)
				obj.Tick = function(self)
					self.Rotation = Rotation(0, 0, 0)
					self.Position = Camera.Position - Number3(self.Scale.X, self.Scale.Y, -self.Scale.Z) / 2
				end
			end
		end

		HTTP:Get(url, function(data)
			if data.StatusCode ~= 200 then
				error("Error: " .. data.StatusCode)
			end

			local image = data.Body
			local object = Object()

			object.Scale = scale

			local back = Quad()
			back.Image = image
			back.Size = Number2(1, 1)
			back.Tiling = Number2(0.25, 0.3335)
			back.Offset = Number2(0, 0.3335)
			back:SetParent(object)
			back.IsUnlit = true

			local left = Quad()
			left.Image = image
			left.Size = Number2(1, 1)
			left.Tiling = Number2(0.25, 0.3335)
			left.Offset = Number2(0.25, 0.3335)
			left.Position = back.Position + Number3(1, 0, 0)
			left.Rotation.Y = math.pi / 2
			left:SetParent(object)
			left.IsUnlit = true

			local front = Quad()
			front.Image = image
			front.Size = Number2(1, 1)
			front.Tiling = Number2(0.25, 0.3335)
			front.Offset = Number2(0.5, 0.3335)
			front.Position = back.Position + Number3(1, 0, -1)
			front.Rotation.Y = math.pi
			front:SetParent(object)
			front.IsUnlit = true

			local right = Quad()
			right.Image = image
			right.Size = Number2(1, 1)
			right.Tiling = Number2(0.25, 0.3335)
			right.Offset = Number2(0.75, 0.3335)
			right.Position = back.Position + Number3(0, 0, -1)
			right.Rotation.Y = -math.pi / 2
			right:SetParent(object)
			right.IsUnlit = true

			local down = Quad()
			down.Image = image
			down.Size = Number2(1, 1 * 1.001)
			down.Tiling = Number2(0.25, 0.3335)
			down.Offset = Number2(0.25, 0.6668)
			down.Position = back.Position + Number3(-1 * 0.001, 1 * 0.002, 0)
			down.Rotation = Rotation(math.pi / 2, math.pi / 2, 0)
			down:SetParent(object)
			down.IsUnlit = true

			local up = Quad()
			up.Image = image
			up.Size = Number2(1, 1)
			up.Tiling = Number2(0.25, 0.3335)
			up.Offset = Number2(0.25, 0)
			up.Position = back.Position + Number3(1, 1, 0)
			up.Rotation = Rotation(-math.pi / 2, math.pi / 2, 0)
			up:SetParent(object)
			up.IsUnlit = true

			object:SetParent(Camera)
			object.Tick = function(self)
				self.Rotation:Set(0, 0, 0)
				self.Position = Camera.Position - Number3(self.Scale.X, self.Scale.Y, -self.Scale.Z) / 2
			end

			func(object)
		end)
	end
	return skybox
end

local skybox = requireSkybox()

local server = require("world_editor_server")
local sendToServer = require("world_editor_server").sendToServer

local worldEditorCommon = require("world_editor_common")
local MAP_SCALE_DEFAULT = worldEditorCommon.MAP_SCALE_DEFAULT

local loadWorld = worldEditorCommon.loadWorld
local maps = worldEditorCommon.maps
local events = worldEditorCommon.events

local theme = require("uitheme").current
local padding = theme.padding

local ambience = require("ambience")

local worldTitle
local worldID

local objects = {}
local map
local mapIndex = 1
local mapName
local mapGhost = false

local CameraMode = {
	THIRD_PERSON = 0,
	FIRST_PERSON = 1,
}
local cameraMode = CameraMode.THIRD_PERSON

-- BUTTONS
local settingsBtn
-- local saveBtn
local ambienceBtn
local ambiencePanel
local cameraBtn
local addObjectBtn
local transformGizmo

local TRAIL_COLOR = Color.White
local OBJECTS_COLLISION_GROUP = CollisionGroups(7)

local function setCameraMode(mode)
	cameraMode = mode
	if mode == CameraMode.THIRD_PERSON then
		Camera:SetModeThirdPerson()
	else
		return require("camera_modes"):setFirstPerson({
			offset = Number3(0, 3, 0),
			camera = Camera,
			target = Player,
			showPointer = true,
		})
	end
end

local function getObjectInfoTable(obj)
	return {
		uuid = obj.uuid,
		fullname = obj.fullname,
		Position = obj.Position or Number3.Zero,
		Rotation = obj.Rotation or Number3.Zero,
		Scale = obj.Scale or Number3.One,
		Name = obj.Name or obj.fullname,
		Physics = obj.realPhysicsMode or PhysicsMode.StaticPerBlock,
	}
end

-- STATE

local pressedObject
local selectedObject
local waitingForUUIDObj

local states = {
	LOADING = 1,
	PICK_WORLD = 2,
	PICK_MAP = 3,
	DEFAULT = 4,
	GALLERY = 5,
	SPAWNING_OBJECT = 6,
	PLACING_OBJECT = 7,
	OBJECT_SELECTED = 8,
	DUPLICATE_OBJECT = 9,
	DESTROY_OBJECT = 10,
	EDIT_MAP = 11,
	MAP_OFFSET = 12,
}

local setState
local state

local function clearWorld()
	Player:RemoveFromParent()
	if map then
		map:RemoveFromParent()
		map = nil
	end
	for _, o in pairs(objects) do
		o:RemoveFromParent()
	end
	objects = {}
	mapName = nil
	ambience:set(ambience.noon)
end

local function setObjectPhysicsMode(obj, physicsMode)
	if not obj then
		print("⚠️ can't set physics mode on nil object")
		return
	end
	obj.realPhysicsMode = physicsMode
	obj:Recurse(function(o)
		if o.Physics == nil then
			return
		end
		-- If disabled, keep trigger to allow raycast
		if physicsMode == PhysicsMode.Disabled then
			o.Physics = PhysicsMode.Trigger
		else
			o.Physics = physicsMode
		end
	end, { includeRoot = true })
end

function objectHitTest(pe)
	local impact = pe:CastRay(OBJECTS_COLLISION_GROUP)
	local obj = impact.Object
	-- obj can be a sub-Shape of an object,
	-- find first parent node that's editable:
	while obj and not obj.isEditable do
		obj = obj:GetParent()
	end
	return obj
end

local didTryPickObject = false
local pickObjectCameraState = {}
function tryPickObjectDown(pe)
	didTryPickObject = true
	-- saving camera state, to avoid picking object after
	-- a rotation or position change between down and up
	pickObjectCameraState.pos = Camera.Position:Copy()
	pickObjectCameraState.rot = Camera.Rotation:Copy()
	local obj = objectHitTest(pe)
	pressedObject = obj
end

function tryPickObjectUp(pe)
	if didTryPickObject == false then
		return
	end
	if math.abs(Camera.Rotation:Angle(pickObjectCameraState.rot)) > 0 then
		return
	end

	didTryPickObject = false

	if pressedObject == nil then
		setState(states.DEFAULT)
		return
	end
	local obj = objectHitTest(pe)
	if obj ~= pressedObject then
		setState(states.DEFAULT)
		return
	end
	if obj.editedBy == Player then
		-- already editing object
		return
	end
	if obj.editedBy ~= nil then
		-- object is being edited by someone else
		return
	end
	pressedObject = nil
	setState(states.OBJECT_SELECTED, obj)
end

local setObjectAlpha = function(obj, alpha)
	obj:Recurse(function(o)
		if not o.Palette then
			return
		end
		if not o.savedAlpha then
			o.savedAlpha = {}
			for k = 1, #o.Palette do
				local c = o.Palette[k]
				o.savedAlpha[k] = c.Color.Alpha / 255
			end
		end
		for k = 1, #o.Palette do
			local c = o.Palette[k]
			c.Color.Alpha = o.savedAlpha[k] * alpha
		end
		o:RefreshModel()
	end, { includeRoot = true })
end

local freezeObject = function(obj)
	if not obj then
		return
	end
	obj:Recurse(function(o)
		if typeof(o) == "Object" then
			return
		end
		o.CollisionGroups = { 6 }
		o.CollidesWithGroups = {}
	end, { includeRoot = true })
end

local unfreezeObject = function(obj)
	if not obj then
		return
	end
	obj:Recurse(function(o)
		if typeof(o) == "Object" then
			return
		end
		o.CollisionGroups = OBJECTS_COLLISION_GROUP
		o.CollidesWithGroups = Map.CollisionGroups + Player.CollisionGroups + OBJECTS_COLLISION_GROUP
	end, { includeRoot = true })
end

local spawnObject = function(data, onDone)
	if data.obj then -- Loaded with loadWorld, already created, no need to place it
		local obj = data.obj
		obj.isEditable = true
		local physicsMode = data.Physics or PhysicsMode.StaticPerBlock
		setObjectPhysicsMode(obj, physicsMode)
		obj:Recurse(function(o)
			if typeof(o) == "Object" then
				return
			end
			o.CollisionGroups = CollisionGroups(3) + OBJECTS_COLLISION_GROUP
			o.CollidesWithGroups = Map.CollisionGroups + Player.CollisionGroups + OBJECTS_COLLISION_GROUP
			o:ResetCollisionBox()
		end, { includeRoot = true })
		if obj.uuid ~= -1 then
			objects[obj.uuid] = obj
		end
		if onDone then
			onDone(obj)
		end
		return
	end
	local fullname = data.fullname
	Object:Load(fullname, function(obj)
		if not obj then
			print("Can't load", fullname)
			return
		end
		local uuid = data.uuid
		local fullname = data.fullname
		local name = data.Name
		local position = data.Position or Number3(0, 0, 0)
		local rotation = data.Rotation or Rotation(0, 0, 0)
		local scale = data.Scale or 0.5
		local physicsMode = data.Physics or PhysicsMode.StaticPerBlock

		obj:SetParent(World)

		-- Handle multishape (world space, change position after)
		local box = Box()
		box:Fit(obj, true)
		obj.Pivot = Number3(obj.Width / 2, box.Min.Y + obj.Pivot.Y, obj.Depth / 2)

		setObjectPhysicsMode(obj, physicsMode)

		obj.uuid = uuid
		obj.Position = position
		obj.Rotation = rotation
		obj.Scale = scale

		obj:Recurse(function(o)
			if typeof(o) == "Object" then
				return
			end
			o.CollisionGroups = CollisionGroups(3) + OBJECTS_COLLISION_GROUP
			o.CollidesWithGroups = Map.CollisionGroups + Player.CollisionGroups + OBJECTS_COLLISION_GROUP
			o:ResetCollisionBox()
		end, { includeRoot = true })

		obj.isEditable = true
		obj.fullname = fullname
		obj.Name = name or fullname

		if obj.uuid ~= -1 then
			objects[obj.uuid] = obj
		end
		if onDone then
			onDone(obj)
		end
	end)
end

local editObject = function(objInfo)
	local obj = objects[objInfo.uuid]
	if not obj then
		print("Error: can't edit object")
		return
	end

	for field, value in pairs(objInfo) do
		obj[field] = value
	end

	if objInfo.Physics then
		setObjectPhysicsMode(obj, objInfo.Physics)
	end

	local alpha = objInfo.alpha
	if alpha ~= nil then
		setObjectAlpha(obj, alpha)
	end
end

local removeObject = function(objInfo)
	objects[objInfo.uuid]:RemoveFromParent()
	objects[objInfo.uuid] = nil
end

toggleMapGhost = function(activate)
	if mapGhost == activate then
		return
	end
	if activate == nil then
		mapGhost = not mapGhost
	else
		mapGhost = activate
	end

	if mapGhost then
		setObjectAlpha(map, 0.4)
		map.CollisionGroups = {}
	else
		setObjectAlpha(map, 1)
		map.CollisionGroups = Map.CollisionGroups
	end
end

local firstPersonPlacingObject = function(obj)
	local impact = Camera:CastRay(nil, Player)
	if impact then
		obj.Position = Camera.Position + Camera.Forward * impact.Distance
	end
	obj.Rotation.Y = worldEditor.rotationShift
end

-- States

local statesSettings = {
	[states.LOADING] = {
		onStateBegin = function()
			initPickMap()
			initPickWorld()
			initDefaultMode()
			worldEditor.uiPickMap:hide()
			worldEditor.editUI:hide()
			worldEditor.defaultStateUI:hide()
			ambience:set(ambience.noon)
			require("object_skills").addStepClimbing(Player)

			setState(states.PICK_WORLD)
			require("controls"):turnOff()
			Player.Motion = { 0, 0, 0 }
		end,
	},
	[states.PICK_WORLD] = {
		onStateBegin = function()
			worldEditor.uiPickWorld:show()
			require("controls"):turnOff()
			Player.Motion = { 0, 0, 0 }
		end,
		onStateEnd = function()
			if worldEditor.uiPickWorld then
				worldEditor.uiPickWorld:close()
				worldEditor.uiPickWorld = nil
			end
		end,
	},
	[states.PICK_MAP] = {
		onStateBegin = function()
			worldEditor.uiPickMap:show()
			Camera:SetModeFree()
			worldEditor.mapPivot = Object()
			worldEditor.mapPivot.Tick = function(pvt, dt)
				pvt.Rotation.Y = pvt.Rotation.Y + dt * 0.06
			end
			worldEditor.mapPivot:SetParent(World)
			Camera:SetParent(worldEditor.mapPivot)
			Camera.Far = 10000
			loadMap(maps[1])
			require("controls"):turnOff()
			Player.Motion = { 0, 0, 0 }
		end,
		onStateEnd = function()
			worldEditor.uiPickMap:hide()
			startDefaultMode()
		end,
	},
	[states.DEFAULT] = {
		onStateBegin = function()
			require("controls"):turnOn()
			worldEditor.editUI:show()
			worldEditor.defaultStateUI:show()
		end,
		onStateEnd = function()
			worldEditor.defaultStateUI:hide()
		end,
		pointerDown = function(pe)
			tryPickObjectDown(pe)
		end,
		pointerUp = function(pe)
			tryPickObjectUp(pe)
		end,
	},
	[states.GALLERY] = {
		onStateBegin = function()
			worldEditor.gallery:show()
			require("controls"):turnOff()
			Player.Motion = { 0, 0, 0 }
		end,
		onStateEnd = function()
			worldEditor.gallery:hide()
			require("controls"):turnOn()
		end,
	},
	[states.SPAWNING_OBJECT] = {
		onStateBegin = function(data)
			worldEditor.rotationShift = data.rotationShift or 0
			data.uuid = -1
			spawnObject(data, function(obj)
				waitingForUUIDObj = obj
				setState(states.PLACING_OBJECT, obj)
			end)
		end,
	},
	[states.PLACING_OBJECT] = { -- NOTE(aduermael): maybe we can remove this state
		onStateBegin = function(obj)
			worldEditor.placingCancelBtn:show()
			worldEditor.placingObj = obj
			freezeObject(obj)
			if worldEditor.rotationShift == nil then
				worldEditor.rotationShift = 0
			end
			if cameraMode == CameraMode.FIRST_PERSON or Client.IsMobile then
				worldEditor.placingValidateBtn:show()
				return
			end
		end,
		tick = function()
			if cameraMode == CameraMode.FIRST_PERSON or Client.IsMobile then -- even third person on mobile uses this placing mode
				firstPersonPlacingObject(worldEditor.placingObj)
			end
		end,
		onStateEnd = function()
			worldEditor.placingValidateBtn:hide()
			worldEditor.placingCancelBtn:hide()
		end,
		pointerMove = function(pe)
			if cameraMode == CameraMode.FIRST_PERSON then
				return
			end
			local placingObj = worldEditor.placingObj

			-- place and rotate object
			local impact = pe:CastRay(Map.CollisionGroups + OBJECTS_COLLISION_GROUP, placingObj)
			if not impact then
				return
			end
			local pos = pe.Position + pe.Direction * impact.Distance
			placingObj.Position = pos
			placingObj.Rotation.Y = worldEditor.rotationShift
		end,
		pointerDrag = function(_) end,
		pointerUp = function(pe)
			if cameraMode == CameraMode.FIRST_PERSON then
				return
			end
			if pe.Index ~= 4 then
				return
			end

			local placingObj = worldEditor.placingObj

			-- drop object
			worldEditor.placingObj = nil

			unfreezeObject(placingObj)

			if not objects[placingObj.uuid] then
				objects[placingObj.uuid] = placingObj
				sendToServer(events.P_PLACE_OBJECT, getObjectInfoTable(placingObj))
			else
				sendToServer(events.P_EDIT_OBJECT, {
					uuid = placingObj.uuid,
					Position = placingObj.Position,
					Rotation = placingObj.Rotation,
				})
			end
			placingObj.editedBy = Player
			setState(states.OBJECT_SELECTED, placingObj)
		end,
		pointerWheelPriority = function(delta)
			worldEditor.rotationShift = worldEditor.rotationShift + math.pi * 0.0625 * (delta > 0 and 1 or -1)
			worldEditor.placingObj.Rotation.Y = worldEditor.rotationShift
			return true
		end,
	},
	[states.OBJECT_SELECTED] = {
		onStateBegin = function(obj)
			if obj.uuid ~= -1 then
				sendToServer(events.P_START_EDIT_OBJECT, { uuid = obj.uuid })
			end
			obj.editedBy = Player
			selectedObject = obj
			require("box_gizmo"):toggle(obj, Color.White)
			worldEditor.nameInput.Text = obj.Name
			worldEditor.nameInput.onTextChange = function(o)
				selectedObject.Name = o.Text
				sendToServer(events.P_EDIT_OBJECT, { uuid = selectedObject.uuid, Name = o.Text })
			end
			worldEditor.updateObjectUI:show()

			settingsBtn:show()
			worldEditor.menuBar:hide()

			local physicsModeIcon
			if obj.realPhysicsMode == PhysicsMode.StaticPerBlock then
				physicsModeIcon = "⚅"
			elseif obj.realPhysicsMode == PhysicsMode.Static then
				physicsModeIcon = "⚀"
			elseif obj.realPhysicsMode == PhysicsMode.Trigger then
				physicsModeIcon = "►"
			elseif obj.realPhysicsMode == PhysicsMode.Disabled then
				physicsModeIcon = "❌"
			else
				error("Physics mode not handled")
			end
			worldEditor.physicsBtn.Text = physicsModeIcon
			Timer(0.1, function()
				freezeObject(selectedObject)
			end)

			local currentScale = obj.Scale:Copy()
			ease:inOutQuad(obj, 0.15).Scale = currentScale * 1.1
			Timer(0.15, function()
				ease:inOutQuad(obj, 0.15).Scale = currentScale
			end)
			sfx("waterdrop_3", { Spatialized = false, Pitch = 1 + math.random() * 0.1 })
			obj.trail = require("trail"):create(Player, obj, TRAIL_COLOR, 0.5)

			transformGizmo = require("transformgizmo"):create({
				target = selectedObject,
				onChange = function(target)
					sendToServer(events.P_EDIT_OBJECT, {
						uuid = target.uuid,
						Position = target.Position,
						Rotation = target.Rotation,
						Scale = target.Scale,
					})
				end,
				onDone = function(target) end,
			})
		end,
		tick = function() end,
		pointerDown = function(pe)
			tryPickObjectDown(pe)
		end,
		pointerUp = function(pe)
			tryPickObjectUp(pe)
		end,
		onStateEnd = function()
			if transformGizmo then
				transformGizmo:remove()
				transformGizmo = nil
			end

			if selectedObject then
				unfreezeObject(selectedObject)
			end

			require("box_gizmo"):toggle(nil)
			worldEditor.updateObjectUI:hide()
			sendToServer(events.P_END_EDIT_OBJECT, { uuid = selectedObject.uuid })
			selectedObject = nil
		end,
		pointerWheelPriority = function(delta)
			selectedObject:RotateWorld(Number3(0, 1, 0), math.pi * 0.0625 * (delta > 0 and 1 or -1))
			selectedObject.Rotation = selectedObject.Rotation -- trigger OnSetCallback
			sendToServer(events.P_EDIT_OBJECT, { uuid = selectedObject.uuid, Rotation = selectedObject.Rotation })
			return true
		end,
	},
	[states.DUPLICATE_OBJECT] = {
		onStateBegin = function(uuid)
			local obj = objects[uuid]
			if not obj then
				print("Error: can't duplicate this object")
				setState(states.DEFAULT)
				return
			end
			local data = getObjectInfoTable(obj)
			data.uuid = nil
			data.rotationShift = worldEditor.rotationShift or 0
			data.uuid = -1
			local previousObj = obj
			spawnObject(data, function(obj)
				waitingForUUIDObj = obj
				obj.Position = previousObj.Position + Number3(5, 0, 5)
				obj.Rotation = previousObj.Rotation
				sendToServer(events.P_PLACE_OBJECT, getObjectInfoTable(obj))
				obj.editedBy = Player
				setState(states.OBJECT_SELECTED, obj)
			end)
		end,
		onStateEnd = function()
			worldEditor.updateObjectUI:hide()
		end,
	},
	[states.DESTROY_OBJECT] = {
		onStateBegin = function(uuid)
			local obj = objects[uuid]
			if not obj then
				print("Error: can't remove this object")
				setState(states.DEFAULT)
				return
			end
			sendToServer(events.P_REMOVE_OBJECT, { uuid = uuid })
			setState(states.DEFAULT)
		end,
		onStateEnd = function()
			worldEditor.updateObjectUI:hide()
		end,
	},
	[states.EDIT_MAP] = {
		onStateBegin = function()
			worldEditor.selectedColor = Color.Grey
			local block = MutableShape()
			worldEditor.handBlock = block
			block:AddBlock(worldEditor.selectedColor, 0, 0, 0)
			Player:EquipRightHand(block)
			block.Scale = 5
			block.LocalPosition = { 1.5, 1.5, 1.5 }
			worldEditor.editMapValidateBtn:show()
			worldEditor.colorPicker:show()
		end,
		onStateEnd = function()
			Player:EquipRightHand(nil)
			worldEditor.editMapValidateBtn:hide()
			worldEditor.colorPicker:hide()
		end,
		pointerUp = function(pe)
			local impact = pe:CastRay(nil, Player)
			if not impact or not impact.Block or impact.Object ~= map then
				return
			end
			if pe.Index == 4 then
				local pos = impact.Block.Coords
				sendToServer(events.P_REMOVE_BLOCK, { pos = pos })
				impact.Block:Remove()
			elseif pe.Index == 5 then
				impact.Block:AddNeighbor(worldEditor.selectedColor, impact.FaceTouched)
				local pos = impact.Block.Coords:Copy()
				if impact.FaceTouched == Face.Front then
					pos.Z = pos.Z + 1
				elseif impact.FaceTouched == Face.Back then
					pos.Z = pos.Z - 1
				elseif impact.FaceTouched == Face.Top then
					pos.Y = pos.Y + 1
				elseif impact.FaceTouched == Face.Bottom then
					pos.Y = pos.Y - 1
				elseif impact.FaceTouched == Face.Right then
					pos.X = pos.X + 1
				elseif impact.FaceTouched == Face.Left then
					pos.X = pos.X - 1
				end
				local color = worldEditor.selectedColor
				sendToServer(events.P_PLACE_BLOCK, {
					pos = pos,
					color = color,
				})
			end
		end,
	},
	[states.MAP_OFFSET] = {
		onStateBegin = function()
			-- close settings menu
			worldEditor.settingsBtn:show()
			worldEditor.menuBar:hide()

			local mapPosition = map.Position:Copy()

			-- Offset buttons
			local ui = require("uikit")
			local mainContainer = require("ui_container"):createVerticalContainer()
			worldEditor.offsetMainContainer = mainContainer

			local axisList = { "X", "Y", "Z" }
			for _, axis in ipairs(axisList) do
				local btnMinus5 = ui:createButton("-5")
				btnMinus5.onRelease = function()
					local value = map.Position:Copy()
					value[axis] = value[axis] - 5 * map.Scale[axis]
					map.Position = value
				end
				local btnMinus = ui:createButton("-1")
				btnMinus.onRelease = function()
					local value = map.Position:Copy()
					value[axis] = value[axis] - map.Scale[axis]
					map.Position = value
				end
				local mapPositionAxis = ui:createButton(axis .. ": 0")
				mapPositionAxis.Width = 100
				map.Position:AddOnSetCallback(function()
					mapPositionAxis.Text = string.format("%s: %d", axis, map.Position[axis] / map.Scale[axis])
				end)
				local btnPlus = ui:createButton("+1")
				btnPlus.onRelease = function()
					local value = map.Position:Copy()
					value[axis] = value[axis] + map.Scale[axis]
					map.Position = value
				end
				local btnPlus5 = ui:createButton("+5")
				btnPlus5.onRelease = function()
					local value = map.Position:Copy()
					value[axis] = value[axis] + 5 * map.Scale[axis]
					map.Position = value
				end
				local container = require("ui_container"):createHorizontalContainer()
				container:pushElement(btnMinus5)
				container:pushElement(btnMinus)
				container:pushGap()
				container:pushElement(mapPositionAxis)
				container:pushGap()
				container:pushElement(btnPlus)
				container:pushElement(btnPlus5)
				mainContainer:pushElement(container)
				mainContainer:pushGap()
			end

			local validateMapOffsetBtn = require("uikit"):createButton("✅")
			worldEditor.validateMapOffsetBtn = validateMapOffsetBtn
			validateMapOffsetBtn.pos =
				{ Screen.Width * 0.5 - validateMapOffsetBtn.Width * 0.5, validateMapOffsetBtn.Height }
			validateMapOffsetBtn.onRelease = function()
				local offset = mapPosition - map.Position
				sendToServer(events.P_SET_MAP_OFFSET, { offset = offset })
				map.Position = mapPosition
				setState(states.DEFAULT)
			end
		end,
		onStateEnd = function()
			require("controls"):turnOn()
			worldEditor.offsetMainContainer:remove()
			worldEditor.offsetMainContainer = nil
			setCameraMode(cameraMode)
			worldEditor.validateMapOffsetBtn:remove()
			worldEditor.validateMapOffsetBtn = nil
			worldEditor.gizmo:setObject(nil)
		end,
	},
}

setState = function(newState, data)
	if state then
		local onStateEnd = statesSettings[state].onStateEnd
		if onStateEnd then
			onStateEnd(newState, data)
		end
	end

	state = newState

	local onStateBegin = statesSettings[state].onStateBegin
	if onStateBegin then
		onStateBegin(data)
	end
end

-- Listeners

local listeners = {
	Tick = "tick",
	PointerDown = "pointerDown",
	PointerMove = "pointerMove",
	PointerDrag = "pointerDrag",
	PointerDragBegin = "pointerDragBegin",
	PointerDragEnd = "pointerDragEnd",
	PointerUp = "pointerUp",
	PointerWheel = "pointerWheel",
	PointerLongPress = "pointerLongPress",
}

local function handleLocalEventListener(listenerName, pe)
	local stateSettings = statesSettings[state]
	local callback

	callback = stateSettings[listenerName]
	if callback then
		if callback(pe) then
			return true
		end
	end
end

for localEventName, listenerName in pairs(listeners) do
	LocalEvent:Listen(LocalEvent.Name[localEventName], function(pe)
		return handleLocalEventListener(listenerName .. "Priority", pe)
	end, { topPriority = true })
	LocalEvent:Listen(LocalEvent.Name[localEventName], function(pe)
		return handleLocalEventListener(listenerName, pe)
	end, { topPriority = false })
end

initPickWorld = function()
	local ui = require("uikit")

	local uiPickWorld
	local content
	uiPickWorld, content = require("creations"):createModal({
		uikit = ui,
		onOpen = function(_, cell)
			worldTitle = cell.title
			worldID = cell.id
			require("api"):getWorld(worldID, { "mapBase64" }, function(data, err)
				if err then
					print(err)
					return
				end
				local mapBase64 = data.mapBase64
				if not mapBase64 or #mapBase64 == 0 then
					setState(states.PICK_MAP)
					return
				end
				sendToServer(events.P_LOAD_WORLD, { mapBase64 = mapBase64 })
				uiPickWorld:close()
				worldEditor.uiPickWorld = nil

				Clouds.On = false
				-- local textureURL = "https://i.ibb.co/hgRhk0t/Standard-Cube-Map.png"
				-- local textureURL = "https://files.cu.bzh/skyboxes/green-mushrooms.png"
				-- skybox.load({ url = textureURL }, function(obj) end)
			end)
		end,
	})
	content.tabs[3].selected = true
	content.tabs[3].action()
	worldEditor.uiPickWorld = uiPickWorld
end

initPickMap = function()
	local ui = require("uikit")

	local uiPickMap = ui:createFrame()
	local previousBtn = ui:createButton("<")
	previousBtn:setParent(uiPickMap)
	previousBtn.onRelease = function()
		mapIndex = mapIndex - 1
		if mapIndex <= 0 then
			mapIndex = #maps
		end
		loadMap(maps[mapIndex])
	end
	local nextBtn = ui:createButton(">")
	nextBtn:setParent(uiPickMap)
	nextBtn.onRelease = function()
		mapIndex = mapIndex + 1
		if mapIndex > #maps then
			mapIndex = 1
		end
		loadMap(maps[mapIndex])
	end

	local galleryMapBtn = ui:createButton("or Pick an item as Map")
	galleryMapBtn:setParent(uiPickMap)
	galleryMapBtn.onRelease = function()
		previousBtn:hide()
		nextBtn:hide()
		-- Gallery to pick a map
		local gallery
		gallery = require("gallery"):create(function()
			return Screen.Width - theme.padding * 2
		end, function()
			return Screen.Height * 0.8
		end, function(m)
			m.pos = { Screen.Width * 0.5 - m.Width * 0.5, Screen.Height * 0.2 }
		end, {
			onOpen = function(cell)
				local fullname = cell.repo .. "." .. cell.name
				sendToServer(events.P_END_PREPARING, { mapName = fullname })
				gallery:remove()
			end,
		})
		gallery.didClose = function()
			previousBtn:show()
			nextBtn:show()
		end
	end

	local validateBtn = ui:createButton("Start editing this map")
	validateBtn:setParent(uiPickMap)
	validateBtn.onRelease = function()
		sendToServer(events.P_END_PREPARING, { mapName = mapName })
	end

	uiPickMap.parentDidResize = function()
		uiPickMap.Width = Screen.Width
		previousBtn.pos = { 50, Screen.Height * 0.5 - previousBtn.Height * 0.5 }
		nextBtn.pos = { Screen.Width - 50 - nextBtn.Width, Screen.Height * 0.5 - nextBtn.Height * 0.5 }
		galleryMapBtn.pos = { Screen.Width * 0.5 - galleryMapBtn.Width * 0.5, padding }
		validateBtn.pos =
			{ Screen.Width * 0.5 - validateBtn.Width * 0.5, galleryMapBtn.pos.Y + galleryMapBtn.Height + padding }
	end
	uiPickMap:parentDidResize()

	worldEditor.uiPickMap = uiPickMap

	uiPickMap:parentDidResize()
end

loadMap = function(fullname, scale, onDone)
	mapName = fullname
	Object:Load(fullname, function(obj)
		if map then
			map:RemoveFromParent()
		end
		map = MutableShape(obj, { includeChildren = true })
		map.Scale = scale or 5
		obj:Recurse(function(o)
			o.CollisionGroups = Map.CollisionGroups
			o.CollidesWithGroups = Map.CollidesWithGroups
			o.Physics = PhysicsMode.StaticPerBlock
		end, { includeRoot = true })
		map:SetParent(World)
		map.Position = { 0, 0, 0 }
		map.Pivot = { 0, 0, 0 }

		if state == states.PICK_MAP then
			Fog.On = false
			Camera.Rotation.Y = math.pi / 2
			Camera.Rotation.X = math.pi / 4

			local longestValue = math.max(map.Width, math.max(map.Height, map.Depth))
			worldEditor.mapPivot.Position = Number3(map.Width * 0.5, longestValue, map.Depth * 0.5) * map.Scale
			Camera.Position = worldEditor.mapPivot.Position + { -longestValue * 4, 0, 0 }
		end
		if onDone then
			onDone()
		end
	end)
end

startDefaultMode = function()
	Fog.On = true
	dropPlayer = function()
		if not map then
			return
		end
		Player.Position = Number3(map.Width * 0.5, map.Height + 10, map.Depth * 0.5) * map.Scale
		Player.Rotation = { 0, 0, 0 }
		Player.Velocity = { 0, 0, 0 }
	end
	-- require("multi")
	Player:SetParent(World)
	if Client.IsMobile then
		setCameraMode(CameraMode.FIRST_PERSON)
	else
		setCameraMode(CameraMode.THIRD_PERSON)
	end
	dropPlayer()

	require("jumpfly")

	Client.Tick = function()
		if Player.Position.Y < -500 then
			dropPlayer()
			Player:TextBubble("💀 Oops!", true)
		end
	end
end

initDefaultMode = function()
	local ui = require("uikit")

	-- Edit UI, always visible after picking a map
	local editUI = ui:createFrame()
	worldEditor.editUI = editUI
	editUI.parentDidResize = function()
		editUI.Width = Screen.Width
		editUI.Height = Screen.Height
	end
	editUI:parentDidResize()

	-- Default UI, add btn
	local defaultStateUI = ui:createFrame()
	worldEditor.defaultStateUI = defaultStateUI
	defaultStateUI.parentDidResize = function()
		defaultStateUI.Width = Screen.Width
		defaultStateUI.Height = Screen.Height
	end
	defaultStateUI:parentDidResize()

	addObjectBtn = ui:buttonSecondary({ content = "➕ Object", padding = padding })
	addObjectBtn.parentDidResize = function(self)
		self.pos = { Screen.Width * 0.5 - self.Width * 0.5, Screen.SafeArea.Bottom + padding }
	end
	addObjectBtn.onRelease = function()
		setState(states.GALLERY)
	end
	addObjectBtn:setParent(worldEditor.defaultStateUI)

	-- Settings menu
	local menuBar = require("ui_container"):createVerticalContainer(Color.DarkGrey)
	worldEditor.menuBar = menuBar

	settingsBtn = ui:buttonSecondary({ content = "Settings ⚙️", textSize = "small" })
	settingsBtn.onRelease = function()
		settingsBtn:hide()
		menuBar:show()
	end
	settingsBtn.parentDidResize = function()
		settingsBtn.pos = {
			Screen.Width - padding - settingsBtn.Width,
			Screen.Height - settingsBtn.Height - Screen.SafeArea.Top - padding,
		}
	end
	settingsBtn:parentDidResize()

	-- Map Scale frame
	local frame = ui:createFrame()
	local text = ui:createText("Map Scale", Color.White)
	text:setParent(frame)
	local scale = map.Scale.X or MAP_SCALE_DEFAULT
	if math.floor(scale) == scale then
		scale = math.floor(scale)
	end
	local input = ui:createTextInput(scale)
	input.onSubmit = function()
		local value = tonumber(input.Text)
		if value <= 0 then
			print("Error: Map scale must be positive")
			return
		end
		sendToServer(events.P_SET_MAP_SCALE, { mapScale = value })
	end
	input:setParent(frame)
	frame.parentDidResize = function(self)
		local parent = self.parent
		if not parent then
			return
		end
		self.Width = parent.Width
		text.pos.Y = input.Height * 0.5 - text.Height * 0.5
		input.Width = frame.Width - text.Width - padding
		input.pos.X = text.pos.X + text.Width + padding
	end
	frame.Height = input.Height
	frame:parentDidResize()
	local mapScaleFrame = frame

	local menuSettingsConfig = {
		{
			type = "button",
			text = "❌ Close",
			callback = function()
				settingsBtn:show()
				menuBar:hide()
			end,
		},
		{ type = "gap" },
		{
			type = "button",
			text = "📑 Save World",
			serverEvent = events.P_SAVE_WORLD,
			name = "saveWorldBtn",
		},
		{ type = "gap" },
		{
			type = "node",
			node = mapScaleFrame,
		},
		{ type = "gap" },
		{
			type = "button",
			text = "Map Ghost",
			callback = toggleMapGhost,
		},
		{ type = "gap" },
		{
			type = "button",
			text = "Map Offset",
			callback = function()
				setState(states.MAP_OFFSET)
			end,
		},
		{ type = "gap" },
		{
			type = "button",
			text = "Reset all",
			callback = function()
				alertModal =
					require("alert"):create("Confirm that you want to remove all modifications and start from scratch.")
				alertModal:setPositiveCallback("Reset and pick a new map", function()
					menuBar:hide()
					settingsBtn:show()
					sendToServer(events.P_RESET_ALL)
				end)
				alertModal:setNegativeCallback("Cancel, I want to continue", function()
					alertModal:close()
				end)
				alertModal.didClose = function()
					alertModal = nil
				end
			end,
			color = require("uitheme").current.colorNegative,
			name = "resetBtn",
		},
	}
	for _, info in ipairs(menuSettingsConfig) do
		if info.type == "gap" then
			menuBar:pushGap()
		elseif info.type == "node" then
			menuBar:pushElement(info.node)
		elseif info.type == "button" then
			local btn = ui:createButton(info.text)
			if info.color then
				btn:setColor(info.color)
			end
			btn.onRelease = function()
				if info.serverEvent then
					sendToServer(info.serverEvent)
					return
				end
				if info.callback then
					info.callback()
				end
			end
			if info.name then
				worldEditor[info.name] = btn
			end
			menuBar:pushElement(btn)
		end
	end

	menuBar:hide()
	menuBar.parentDidResize = function()
		menuBar:refresh()
		menuBar.pos =
			{ Screen.Width - padding - menuBar.Width, Screen.Height - menuBar.Height - Screen.SafeArea.Top - padding }
	end
	menuBar:parentDidResize()

	-- Gallery
	local galleryOnOpen = function(cell)
		local fullname = cell.repo .. "." .. cell.name
		setState(states.SPAWNING_OBJECT, { fullname = fullname })
	end
	local initGallery
	initGallery = function()
		worldEditor.gallery = require("gallery"):create(function() -- maxWidth
			return Screen.Width - Screen.SafeArea.Right - Screen.SafeArea.Left - theme.padding * 2
		end, function() -- maxHeight
			return Screen.Height - Screen.SafeArea.Top - Screen.SafeArea.Bottom - theme.padding * 2
		end, function(m) -- position
			m.pos = {
				Screen.Width * 0.5 - m.Width * 0.5,
				Screen.SafeArea.Bottom
					+ (Screen.Height - Screen.SafeArea.Top - Screen.SafeArea.Bottom) * 0.5
					- m.Height * 0.5,
			}
		end, { onOpen = galleryOnOpen, type = "items" })
		worldEditor.gallery.didClose = function()
			setState(states.DEFAULT)
			initGallery()
		end
		worldEditor.gallery:hide()
	end
	initGallery()

	-- Placing
	local placingCancelBtn = ui:createButton("❌")
	placingCancelBtn.onRelease = function()
		setState(states.DEFAULT)
		worldEditor.placingObj:RemoveFromParent()
		worldEditor.placingObj = nil
	end
	placingCancelBtn.parentDidResize = function()
		placingCancelBtn.pos = { Screen.Width * 0.5 - placingCancelBtn.Width * 0.5, placingCancelBtn.Height * 2 }
	end
	placingCancelBtn:parentDidResize()
	placingCancelBtn:hide()
	worldEditor.placingCancelBtn = placingCancelBtn

	local placingValidateBtn = ui:createButton("✅")
	placingValidateBtn.onRelease = function()
		local placingObj = worldEditor.placingObj
		worldEditor.placingObj = nil

		unfreezeObject(placingObj)

		objects[placingObj.uuid] = placingObj
		sendToServer(events.P_PLACE_OBJECT, getObjectInfoTable(placingObj))
		placingObj.editedBy = Player
		setState(states.OBJECT_SELECTED, placingObj)
	end
	placingValidateBtn.parentDidResize = function()
		placingValidateBtn.Width = placingCancelBtn.Width * 1.4
		placingValidateBtn.Height = placingValidateBtn.Width
		placingValidateBtn.pos = placingCancelBtn.pos
			+ { placingCancelBtn.Width + padding, placingCancelBtn.Height * 0.5 - placingValidateBtn.Height * 0.5, 0 }
	end
	placingValidateBtn:parentDidResize()
	placingValidateBtn:hide()
	worldEditor.placingValidateBtn = placingValidateBtn

	-- Update object UI
	local updateObjectUI = ui:frameGenericContainer()

	local bar = require("ui_container"):createHorizontalContainer(Color(0, 0, 0, 0))
	bar:setParent(updateObjectUI)

	local nameInput = ui:createTextInput("", "Item Name")
	worldEditor.nameInput = nameInput
	bar:pushElement(nameInput)

	bar:pushGap()

	local barInfoConfig = {
		{
			type = "button",
			text = "⚅",
			name = "physicsBtn",
			callback = function(btn)
				local obj = selectedObject
				if btn.Text == "⚅" then
					obj:TextBubble("CollisionMode: Static")
					setObjectPhysicsMode(obj, PhysicsMode.Static)
					btn.Text = "⚀"
				elseif btn.Text == "⚀" then
					obj:TextBubble("CollisionMode: Trigger")
					setObjectPhysicsMode(obj, PhysicsMode.Trigger)
					btn.Text = "►"
				elseif btn.Text == "►" then
					obj:TextBubble("CollisionMode: Disabled")
					setObjectPhysicsMode(obj, PhysicsMode.Disabled)
					btn.Text = "❌"
				else
					obj:TextBubble("CollisionMode: StaticPerBlock")
					setObjectPhysicsMode(obj, PhysicsMode.StaticPerBlock)
					btn.Text = "⚅"
				end
			end,
		},
		{ type = "gap" },
		{
			type = "button",
			text = "📑",
			callback = function()
				setState(states.DUPLICATE_OBJECT, selectedObject.uuid)
			end,
		},
		{ type = "gap" },
		{
			type = "button",
			text = "🗑️",
			callback = function()
				setState(states.DESTROY_OBJECT, selectedObject.uuid)
			end,
		},
		{ type = "gap" },
		{
			type = "button",
			text = "✅",
			callback = function()
				setState(states.DEFAULT, selectedObject.uuid)
			end,
		},
	}

	for _, info in ipairs(barInfoConfig) do
		if info.type == "button" then
			local btn = ui:buttonSecondary({ content = info.text })
			if info.name then
				worldEditor[info.name] = btn
			end
			btn.onRelease = info.callback
			bar:pushElement(btn)
		elseif info.type == "gap" then
			bar:pushGap()
		end
	end

	updateObjectUI.parentDidResize = function()
		nameInput.Width = 150
		bar:refresh()
		updateObjectUI.Width = bar.Width + padding * 2
		updateObjectUI.Height = bar.Height + padding * 2
		bar.pos = { padding, padding }
		updateObjectUI.pos = { Screen.Width * 0.5 - updateObjectUI.Width * 0.5, padding }
	end
	updateObjectUI:hide()
	updateObjectUI:parentDidResize()
	worldEditor.updateObjectUI = updateObjectUI

	-- Top bar
	local topBar = require("ui_container"):createHorizontalContainer()
	worldEditor.topBar = topBar
	topBar.parentDidResize = function()
		topBar.pos = { padding, Screen.Height - Screen.SafeArea.Top - topBar.Height - padding }
	end
	topBar:setParent(worldEditor.editUI)

	-- Ambience editor
	ambienceBtn = ui:buttonSecondary({ content = "☀️ Ambience", textSize = "small" })
	ambienceBtn.onRelease = function(self)
		ambienceBtn:hide()
		cameraBtn:hide()
		ambiencePanel = ui:frameGenericContainer()
		ambiencePanel.Width = 200
		ambiencePanel.Height = 300

		local title = ui:createText(self.Text, Color.White, "small")
		title:setParent(ambiencePanel)

		local btnClose = ui:buttonNegative({ content = "close", textSize = "small", padding = padding })
		btnClose:setParent(ambiencePanel)

		local aiInput = ui:createTextInput("", "Morning light, dawn…", { textSize = "small" })
		aiInput:setParent(ambiencePanel)

		local aiBtn = ui:buttonNeutral({ content = "✨", textSize = "small", padding = padding })
		aiBtn:setParent(ambiencePanel)

		local loading = require("ui_loading_animation"):create({ ui = ui })
		loading:setParent(ambiencePanel)
		loading:hide()

		local cell = ui:frame()

		local sunLabel = ui:createText("☀️ Sun", { size = "small", color = Color.White })
		sunLabel:setParent(cell)

		local sunRotationYLabel = ui:createText("0  ", { font = Font.Pixel, size = "default", color = Color.White })
		sunRotationYLabel:setParent(cell)

		-- local ambience = server.getAmbience()

		local sliderHandleSize = 30

		local sliderButton = ui:buttonNeutral({ content = "" })
		sliderButton.Height = sliderHandleSize
		sliderButton.Width = sliderHandleSize

		local sunRotationSlider = ui:slider({
			defaultValue = 180, -- TODO: fix ambience first then get current value
			min = 0,
			max = 360,
			step = 1,
			button = sliderButton,
			onValueChange = function(v)
				sunRotationYLabel.Text = "" .. v
				local ambience = server.getAmbience()
				if ambience.sun.rotation then
					-- print("ambience.sun.rotation:", type(ambience.sun.rotation))
					ambience.sun.rotation.Y = math.rad(v)
					sendToServer(events.P_SET_AMBIENCE, ambience)
					require("ai_ambience"):loadGeneration(ambience)
				end
			end,
		})
		sunRotationSlider:setParent(cell)

		local sunRotationXLabel = ui:createText("0  ", { font = Font.Pixel, size = "default", color = Color.White })
		sunRotationXLabel:setParent(cell)

		local sliderButton = ui:buttonNeutral({ content = "" })
		sliderButton.Height = sliderHandleSize
		sliderButton.Width = sliderHandleSize

		local sunRotationXSlider = ui:slider({
			defaultValue = 0, -- TODO: fix ambience first then get current value
			min = -90,
			max = 90,
			step = 1,
			button = sliderButton,
			onValueChange = function(v)
				sunRotationXLabel.Text = "" .. v
				local ambience = server.getAmbience()
				if ambience.sun.rotation then
					ambience.sun.rotation.X = math.rad(v)
					sendToServer(events.P_SET_AMBIENCE, ambience)
					require("ai_ambience"):loadGeneration(ambience)
				end
			end,
		})
		sunRotationXSlider:setParent(cell)

		local fogLabel = ui:createText("☁️ Fog (near/far)", { size = "small", color = Color.White })
		fogLabel:setParent(cell)

		local sliderButton = ui:buttonNeutral({ content = "" })
		sliderButton.Height = sliderHandleSize
		sliderButton.Width = sliderHandleSize

		local fogNearSlider = ui:slider({
			defaultValue = 0, -- TODO: fix ambience first then get current value
			min = -90,
			max = 90,
			step = 1,
			button = sliderButton,
			onValueChange = function(v) end,
		})
		fogNearSlider:setParent(cell)

		local sliderButton = ui:buttonNeutral({ content = "" })
		sliderButton.Height = sliderHandleSize
		sliderButton.Width = sliderHandleSize

		local fogFarSlider = ui:slider({
			defaultValue = 0, -- TODO: fix ambience first then get current value
			min = -90,
			max = 90,
			step = 1,
			button = sliderButton,
			onValueChange = function(v) end,
		})
		fogFarSlider:setParent(cell)

		cell.Height = sunLabel.Height
			+ theme.paddingTiny
			+ sliderHandleSize
			+ theme.paddingTiny
			+ sliderHandleSize
			+ theme.paddingTiny
			+ fogLabel.Height
			+ theme.paddingTiny
			+ sliderHandleSize
			+ theme.paddingTiny
			+ sliderHandleSize

		cell.parentDidResize = function(self)
			local parent = self.parent
			self.Width = parent.Width

			local y = self.Height - sunLabel.Height
			sunLabel.pos = { 0, y }
			y = y - theme.paddingTiny - sliderHandleSize

			sunRotationSlider.Width = self.Width - sunRotationYLabel.Width - theme.padding
			sunRotationSlider.pos = { 0, y }

			sunRotationYLabel.pos = {
				sunRotationSlider.pos.X + sunRotationSlider.Width + theme.padding,
				sunRotationSlider.pos.Y + sliderHandleSize * 0.5 - sunRotationYLabel.Height * 0.5,
			}
			y = y - theme.paddingTiny - sliderHandleSize

			sunRotationXSlider.Width = self.Width - sunRotationYLabel.Width - theme.padding
			sunRotationXSlider.pos = { 0, y }

			sunRotationXLabel.pos = {
				sunRotationXSlider.pos.X + sunRotationXSlider.Width + theme.padding,
				sunRotationXSlider.pos.Y + sliderHandleSize * 0.5 - sunRotationXLabel.Height * 0.5,
			}
			y = y - theme.paddingTiny - fogLabel.Height

			fogLabel.pos = { 0, y }

			y = y - theme.paddingTiny - sliderHandleSize
			fogNearSlider.Width = self.Width - sunRotationYLabel.Width - theme.padding
			fogNearSlider.pos = { 0, y }

			y = y - theme.paddingTiny - sliderHandleSize
			fogFarSlider.Width = self.Width - sunRotationYLabel.Width - theme.padding
			fogFarSlider.pos = { 0, y }
		end

		cell:setParent(nil)

		local function generate()
			aiInput:hide()
			aiBtn:hide()
			loading:show()

			require("ai_ambience"):generate({
				prompt = aiInput.Text,
				onDone = function(generation)
					sfx("metal_clanging_2", { Spatialized = false, Volume = 0.6 })
					sendToServer(events.P_SET_AMBIENCE, generation)
					sunRotationSlider:setValue(math.floor(math.deg(generation.sun.rotation[2])))
					aiInput:show()
					aiBtn:show()
					loading:hide()
				end,
				onError = function(err)
					print("❌", err)
					aiInput:show()
					aiBtn:show()
					loading:hide()
				end,
			})
		end

		aiInput.onSubmit = generate
		aiBtn.onRelease = generate

		btnClose.onRelease = function()
			ambiencePanel:remove()
			ambiencePanel = nil
			ambienceBtn:show()
			cameraBtn:show()
		end

		local scroll = ui:createScroll({
			backgroundColor = theme.buttonTextColor,
			loadCell = function(index, _) -- index, userdata
				if index == 1 then
					return cell
				end
			end,
			unloadCell = function(_, cell, _) -- index, cell, userdata
				cell:setParent(nil)
				return nil
			end,
			cellPadding = padding,
			padding = padding,
		})
		scroll:setParent(ambiencePanel)

		ambiencePanel.parentDidResize = function(self)
			self.pos = {
				Screen.SafeArea.Left + padding,
				Screen.Height - self.Height - Screen.SafeArea.Top - padding,
			}

			title.pos = {
				self.Width * 0.5 - title.Width * 0.5,
				self.Height - title.Height - padding,
			}

			aiInput.Width = self.Width - aiBtn.Width - padding * 3
			local h = math.max(aiInput.Height, aiBtn.Height)
			aiInput.Height = h
			aiBtn.Height = h

			aiInput.pos = {
				padding,
				title.pos.Y - h - padding,
			}

			aiBtn.pos = {
				aiInput.pos.X + aiInput.Width + padding,
				aiInput.pos.Y,
			}

			loading.pos = {
				self.Width * 0.5 - loading.Width * 0.5,
				aiInput.pos.Y + aiBtn.Height * 0.5 - loading.Height * 0.5,
			}

			btnClose.pos = {
				self.Width * 0.5 - btnClose.Width * 0.5,
				padding,
			}

			scroll.pos.Y = btnClose.pos.Y + btnClose.Height + padding
			scroll.pos.X = padding
			scroll.Height = aiInput.pos.Y - padding - scroll.pos.Y
			scroll.Width = self.Width - padding * 2
		end
		ambiencePanel:parentDidResize()
	end

	-- Camera
	cameraBtn = ui:buttonSecondary({ content = "🎥", textSize = "small" })
	cameraBtn.onRelease = function()
		if cameraMode == CameraMode.THIRD_PERSON then
			setCameraMode(CameraMode.FIRST_PERSON)
		else
			setCameraMode(CameraMode.THIRD_PERSON)
		end
	end
	cameraBtn.parentDidResize = function()
		ambienceBtn.pos = {
			Screen.SafeArea.Left + padding,
			Screen.Height - ambienceBtn.Height - Screen.SafeArea.Top - padding,
		}

		cameraBtn.pos = {
			ambienceBtn.pos.X,
			ambienceBtn.pos.Y - cameraBtn.Height - padding,
		}
	end
	cameraBtn:parentDidResize()

	-- Edit Map
	local editMapValidateBtn = ui:createButton("✅")
	editMapValidateBtn.onRelease = function()
		setState(states.DEFAULT)
	end
	editMapValidateBtn.parentDidResize = function()
		editMapValidateBtn.pos = { Screen.Width * 0.5 - editMapValidateBtn.Width * 0.5, placingCancelBtn.Height * 2 }
	end
	editMapValidateBtn:parentDidResize()
	editMapValidateBtn:hide()
	worldEditor.editMapValidateBtn = editMapValidateBtn

	local picker = require("colorpicker"):create({
		closeBtnIcon = "",
		uikit = ui,
		transparency = false,
		colorPreview = false,
		maxWidth = function()
			if Client.IsMobile and Screen.Height > Screen.Width then -- portrait mode
				return Screen.Width * 0.4
			end
			return Screen.Width * 0.5
		end,
	})
	picker.parentDidResize = function()
		if not Client.IsMobile then
			picker.pos = { Screen.Width - picker.Width, -20 }
		else
			local actionButton1 = require("controls"):getActionButton(1)
			if not actionButton1 then
				error("Action1 button does not exist", 2)
				return
			end
			picker.pos = { Screen.Width - picker.Width - padding, actionButton1.pos.Y + actionButton1.Height + padding }
		end
	end
	picker:parentDidResize()
	picker.closeBtn:remove()
	picker.closeBtn = nil
	picker:setColor(Color.Grey)
	picker:hide()
	worldEditor.colorPicker = picker

	picker.didPickColor = function(_, color)
		worldEditor.selectedColor = color
		worldEditor.handBlock.Palette[1].Color = color
	end
end

LocalEvent:Listen(LocalEvent.Name.DidReceiveEvent, function(e)
	local data = e.data
	local sender = Players[e.pID]
	local isLocalPlayer = e.pID == Player.ID

	if e.a == events.END_PREPARING then
		loadMap(data.mapName, data.mapScale or MAP_SCALE_DEFAULT, function()
			setState(states.DEFAULT)
		end)
	elseif e.a == events.SYNC then
		if state == states.PICK_WORLD then -- joining
			loadWorld(data.mapBase64, {
				onDone = function()
					setState(states.DEFAULT)
					startDefaultMode()
				end,
				onLoad = function(obj, data)
					if data == "Map" then
						if map then
							map:RemoveFromParent()
						end
						map = obj
						return
					end
					obj.editedBy = nil
					data.obj = obj
					spawnObject(data)
				end,
			})
		end
	elseif e.a == events.PLACE_OBJECT then
		if isLocalPlayer then
			waitingForUUIDObj.uuid = e.data.uuid
			objects[waitingForUUIDObj.uuid] = waitingForUUIDObj
			objects[-1] = nil
			sendToServer(events.P_START_EDIT_OBJECT, { uuid = e.data.uuid })
			waitingForUUIDObj = nil
		else
			spawnObject(data, function()
				local obj = objects[data.uuid]
				obj.editedBy = sender
				if obj.trail then
					obj.trail:remove()
				end
				obj.trail = require("trail"):create(sender, obj, TRAIL_COLOR, 0.5)
			end)
		end
	elseif e.a == events.EDIT_OBJECT and not isLocalPlayer then
		editObject(data)
	elseif e.a == events.REMOVE_OBJECT then
		removeObject(data)
	elseif e.a == events.START_EDIT_OBJECT then
		local obj = objects[data.uuid]
		if not obj or isLocalPlayer then
			return
		end
		freezeObject(obj)
		obj.editedBy = sender
		if obj.trail then
			obj.trail:remove()
		end
		obj.trail = require("trail"):create(sender, obj, TRAIL_COLOR, 0.5)
	elseif e.a == events.END_EDIT_OBJECT then
		local obj = objects[data.uuid]
		if not obj then
			print("can't end edit object")
			return
		end
		unfreezeObject(obj)
		if obj.trail then
			obj.trail:remove()
			obj.trail = nil
		end
		obj.editedBy = nil
	elseif e.a == events.PLACE_BLOCK and not isLocalPlayer then
		local color = data.color
		map:AddBlock(color, data.pos.X, data.pos.Y, data.pos.Z)
		map:RefreshModel()
	elseif e.a == events.REMOVE_BLOCK and not isLocalPlayer then
		local b = map:GetBlock(data.pos.X, data.pos.Y, data.pos.Z)
		if b then
			b:Remove()
		end
	elseif e.a == events.PLAYER_ACTIVITY then
		for pIDUserID, t in pairs(data.activity) do
			if t and t.editing then
				local pID = tonumber(string.sub(pIDUserID, 1, 1))
				local obj = objects[t.editing]
				local player = Players[pID]
				if not obj or obj.editedBy == player then
					return
				end
				obj.editedBy = player
				if obj.trail then
					obj.trail:remove()
				end
				obj.trail = require("trail"):create(player, obj, TRAIL_COLOR, 0.5)
			end
		end
	elseif e.a == events.SET_AMBIENCE and not isLocalPlayer then
		require("ai_ambience"):loadGeneration(data)
	elseif e.a == events.SET_MAP_SCALE then
		local prevScale = map.Scale
		local ratio = data.mapScale / prevScale
		map.Scale = data.mapScale
		for _, o in pairs(objects) do
			o.Scale = o.Scale * ratio
			o.Position = o.Position * ratio
		end
		dropPlayer()
	elseif e.a == events.SET_MAP_OFFSET then
		local offset = data.offset
		for _, o in pairs(objects) do
			o.Position = o.Position + offset
		end
		Player.Position = Player.Position + offset
	elseif e.a == events.RESET_ALL then
		setState(states.DEFAULT)
		clearWorld()
		setState(states.PICK_MAP)
	elseif e.a == events.SAVE_WORLD then
		local mapBase64 = data.mapBase64
		if mapBase64 == nil then
			print("Received nil from server")
			return
		end
		-- could be move to world_editor_server, not sure System works on the server (must enable the file in require.cpp)
		require("system_api", System):patchWorld(worldID, { mapBase64 = mapBase64 }, function(err, world)
			if world and world.mapBase64 == mapBase64 then
				print("World '" .. worldTitle .. "' saved")
			else
				if err then
					print("Error while saving world: ", JSON:Encode(err))
				else
					print("Error while saving world")
				end
			end
		end)
	end
end)

Timer(30, true, function()
	if state < states.DEFAULT then
		return
	end
	-- ask for auto save every 30 seconds, if no changes since last save, server does not answer
	sendToServer(events.P_SAVE_WORLD)
end)

setState(states.LOADING)

return worldEditor
