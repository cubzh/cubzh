local worldEditor = {}

local sfx = require("sfx")
local ease = require("ease")
local ui = require("uikit")
local ambience = require("ambience")

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
local uuidv4 = worldEditorCommon.uuidv4

local loadWorld = worldEditorCommon.loadWorld
local maps = worldEditorCommon.maps
local events = worldEditorCommon.events

local theme = require("uitheme").current
local padding = theme.padding

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

local trail

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
	require("hierarchyactions"):applyToDescendants(obj, { includeRoot = true }, function(o)
		if o.Physics == nil then
			return
		end
		-- If disabled, keep trigger to allow raycast
		if physicsMode == PhysicsMode.Disabled then
			o.Physics = PhysicsMode.Trigger
		else
			o.Physics = physicsMode
		end
	end)

	worldEditorCommon.updateObject({
		uuid = obj.uuid,
		physics = physicsMode,
	})
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
	pressedObject = nil
	setState(states.OBJECT_SELECTED, obj)
end

local setObjectAlpha = function(obj, alpha)
	require("hierarchyactions"):applyToDescendants(obj, { includeRoot = true }, function(o)
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
	end)
end

local freezeObject = function(obj)
	if not obj then
		return
	end
	require("hierarchyactions"):applyToDescendants(obj, { includeRoot = true }, function(o)
		if type(o) == "Object" then
			return
		end
		o.CollisionGroups = { 6 }
		o.CollidesWithGroups = {}
	end)
end

local unfreezeObject = function(obj)
	if not obj then
		return
	end
	require("hierarchyactions"):applyToDescendants(obj, { includeRoot = true }, function(o)
		if type(o) == "Object" then
			return
		end
		o.CollisionGroups = OBJECTS_COLLISION_GROUP
		o.CollidesWithGroups = Map.CollisionGroups + Player.CollisionGroups + OBJECTS_COLLISION_GROUP
	end)
end

local spawnObject = function(data, onDone)
	if data.obj then -- Loaded with loadWorld, already created, no need to place it
		local obj = data.obj
		obj.isEditable = true
		local physicsMode = data.Physics or PhysicsMode.StaticPerBlock
		setObjectPhysicsMode(obj, physicsMode)
		require("hierarchyactions"):applyToDescendants(obj, { includeRoot = true }, function(o)
			if type(o) == "Object" then
				return
			end
			o.CollisionGroups = CollisionGroups(3) + OBJECTS_COLLISION_GROUP
			o.CollidesWithGroups = Map.CollisionGroups + Player.CollisionGroups + OBJECTS_COLLISION_GROUP
			o:ResetCollisionBox()
		end)
		objects[obj.uuid] = obj
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

		local uuid = uuidv4()
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

		require("hierarchyactions"):applyToDescendants(obj, { includeRoot = true }, function(o)
			if type(o) == "Object" then
				return
			end
			o.CollisionGroups = CollisionGroups(3) + OBJECTS_COLLISION_GROUP
			o.CollidesWithGroups = Map.CollisionGroups + Player.CollisionGroups + OBJECTS_COLLISION_GROUP
			o:ResetCollisionBox()
		end)

		obj.isEditable = true
		obj.fullname = fullname
		obj.Name = name or fullname

		objects[obj.uuid] = obj
		worldEditorCommon.addObject(obj)

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
			worldEditor.uiPickMap:hide()
			ambience:set(ambience.noon)
			require("object_skills").addStepClimbing(Player)
			setState(states.PICK_WORLD)
			require("controls"):turnOff()
			Player.Motion:Set(Number3.Zero)
		end,
	},
	[states.PICK_WORLD] = {
		onStateBegin = function()
			uiShowWorldPicker()
			require("controls"):turnOff()
			Player.Motion:Set(Number3.Zero)
		end,
		onStateEnd = function()
			uiRemoveWorldPicker()
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
			uiShowDefaultMenu()
		end,
		onStateEnd = function()
			uiHideDefaultMenu()
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
			spawnObject(data, function(obj)
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
			else
				worldEditorCommon.updateObject({
					uuid = placingObj.uuid,
					position = placingObj.Position,
					rotation = placingObj.Rotation,
				})
			end
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
			selectedObject = obj
			require("box_gizmo"):toggle(obj, Color.White)
			worldEditor.nameInput.Text = obj.Name
			worldEditor.nameInput.onTextChange = function(o)
				selectedObject.Name = o.Text
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

			if trail ~= nil then
				trail:remove()
			end
			trail = require("trail"):create(Player, obj, TRAIL_COLOR, 0.5)

			transformGizmo = require("transformgizmo"):create({
				target = selectedObject,
				onChange = function(target) end,
				onDone = function(target)
					worldEditorCommon.updateObject({
						uuid = target.uuid,
						position = target.Position,
						rotation = target.Rotation,
						scale = target.Scale,
					})
				end,
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

			if trail ~= nil then
				trail:remove()
			end

			require("box_gizmo"):toggle(nil)
			worldEditor.updateObjectUI:hide()
			saveWorld()
			selectedObject = nil
		end,
		pointerWheelPriority = function(delta)
			selectedObject:RotateWorld(Number3(0, 1, 0), math.pi * 0.0625 * (delta > 0 and 1 or -1))
			selectedObject.Rotation = selectedObject.Rotation -- trigger OnSetCallback
			worldEditorCommon.updateObject({
				uuid = selectedObject.uuid,
				rotation = target.Rotation,
			})
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
			data.uuid = uuidv4()
			data.rotationShift = worldEditor.rotationShift or 0
			local previousObj = obj
			spawnObject(data, function(obj)
				obj.Position = previousObj.Position + Number3(5, 0, 5)
				obj.Rotation = previousObj.Rotation
				setState(states.OBJECT_SELECTED, obj)
			end)
		end,
		onStateEnd = function()
			worldEditor.updateObjectUI:hide()
		end,
	},
	[states.DESTROY_OBJECT] = {
		onStateBegin = function(uuid)
			worldEditor.updateObjectUI:hide()
			local obj = objects[uuid]
			if not obj then
				print("Error: can't remove this object")
				setState(states.DEFAULT)
				return
			end
			obj:RemoveFromParent()
			objects[uuid] = nil
			worldEditorCommon.removeObject(uuid)
			setState(states.DEFAULT)
		end,
		onStateEnd = function()
			saveWorld()
		end,
	},
	[states.MAP_OFFSET] = {
		onStateBegin = function()
			-- close settings menu
			worldEditor.settingsBtn:show()
			worldEditor.menuBar:hide()

			local mapPosition = map.Position:Copy()

			-- Offset buttons
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

			local validateMapOffsetBtn = ui:createButton("✅")
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

local worldPicker
function uiShowWorldPicker()
	if worldPicker ~= nil then
		return
	end
	local content
	worldPicker, content = require("creations"):createModal({
		uikit = ui,
		categories = { "worlds" },
		title = "Open World...",
		onOpen = function(_, cell)
			require("api"):getWorld(cell.id, { "mapBase64" }, function(data, err)
				if err then
					print(err)
					return
				end
				local mapBase64 = data.mapBase64
				if not mapBase64 or #mapBase64 == 0 then
					setState(states.PICK_MAP)
					return
				end

				loadWorld({
					b64 = mapBase64,
					title = cell.title,
					worldID = cell.id,
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
						data.obj = obj
						spawnObject(data)
					end,
				})

				Clouds.On = false

				-- local textureURL = "https://i.ibb.co/hgRhk0t/Standard-Cube-Map.png"
				-- local textureURL = "https://files.cu.bzh/skyboxes/green-mushrooms512.png"
				-- local textureURL = "https://files.cu.bzh/skyboxes/skybox_2.png"
				-- skybox.load({ url = textureURL }, function(obj) end)
			end)
		end,
	})
	-- content.tabs[3].selected = true
	-- content.tabs[3].action()
	-- worldEditor.uiPickWorld = uiPickWorld
end

function uiRemoveWorldPicker()
	if worldPicker == nil then
		return
	end
	worldPicker:remove()
	worldPicker = nil
end

initPickMap = function()
	local uiPickMap = ui:frame()
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
				-- sendToServer(events.P_END_PREPARING, { mapName = fullname })
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
		-- sendToServer(events.P_END_PREPARING, { mapName = mapName })
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
		require("hierarchyactions"):applyToDescendants(map, { includeRoot = true }, function(o)
			o.CollisionGroups = Map.CollisionGroups
			o.CollidesWithGroups = Map.CollidesWithGroups
			o.Physics = PhysicsMode.StaticPerBlock
		end)
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

local uiDefaultMenu
function uiShowDefaultMenu()
	if uiDefaultMenu ~= nil then
		uiDefaultMenu:show()
		return
	end
	uiDefaultMenu = ui:createNode()

	addObjectBtn = ui:buttonSecondary({ content = "➕ Object", padding = padding })
	addObjectBtn.parentDidResize = function(self)
		self.pos = { Screen.Width * 0.5 - self.Width * 0.5, Screen.SafeArea.Bottom + padding }
	end
	addObjectBtn.onRelease = function()
		setState(states.GALLERY)
	end
	addObjectBtn:setParent(uiDefaultMenu)

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
			text = "📑 Save",
			callback = function()
				saveWorld()
			end,
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

	-- Ambience editor
	ambienceBtn = ui:buttonSecondary({ content = "☀️ Ambience", textSize = "small" })
	ambienceBtn.onRelease = function(self)
		ambienceBtn:hide()
		cameraBtn:hide()
		ambiencePanel = ui:frameGenericContainer()

		local title = ui:createText(self.Text, Color.White, "small")
		title:setParent(ambiencePanel)

		local btnClose = ui:buttonNegative({ content = "close", textSize = "small", padding = padding })
		btnClose:setParent(ambiencePanel)

		local aiInput = ui:createTextInput("", "Morning light, dawn…", { textSize = "small" })
		aiInput:setParent(ambiencePanel)

		local aiBtn = ui:buttonNeutral({ content = "✨", textSize = "small", padding = padding })
		aiBtn:setParent(ambiencePanel)

		local skyboxLabel = ui:createText("Include skybox:", Color(150, 150, 150), "small")
		skyboxLabel:setParent(ambiencePanel)

		local includeSkybox = true
		local skyboxBtn = ui:buttonSecondary({
			textFont = Font.Pixel,
			content = "✅",
			textSize = "default",
			padding = 2,
		})
		skyboxBtn.onRelease = function(self)
			includeSkybox = not includeSkybox
			if includeSkybox then
				self.Text = "✅"
			else
				self.Text = "  "
			end
		end
		skyboxBtn:setParent(ambiencePanel)

		local loading = require("ui_loading_animation"):create({ ui = ui })
		loading:setParent(ambiencePanel)
		loading:hide()

		local cell = ui:frame()

		local sunLabel = ui:createText("☀️ Sun", { size = "small", color = Color.White })
		sunLabel:setParent(cell)

		local sunRotationYLabel = ui:createText("0  ", { font = Font.Pixel, size = "default", color = Color.White })
		sunRotationYLabel:setParent(cell)

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
				local ambience = worldEditorCommon.getAmbience()
				if ambience.sun.rotation then
					-- print("ambience.sun.rotation:", type(ambience.sun.rotation))
					ambience.sun.rotation.Y = math.rad(v)
					worldEditorCommon.updateAmbience(ambience)
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
				local ambience = worldEditorCommon.getAmbience()
				if ambience.sun.rotation then
					ambience.sun.rotation.X = math.rad(v)
					worldEditorCommon.updateAmbience(ambience)
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

			local prompt = aiInput.Text

			require("ai_ambience"):generate({
				prompt = aiInput.Text,
				loadWhenDone = false,
				onDone = function(generation, loadedAmbiance)
					-- sfx("metal_clanging_2", { Spatialized = false, Volume = 0.6 })
					-- worldEditorCommon.updateAmbience(loadedAmbiance)
					-- sunRotationSlider:setValue(math.floor(math.deg(loadedAmbiance.sun.rotation.Y)))
					-- sunRotationXSlider:setValue(math.floor(math.deg(loadedAmbiance.sun.rotation.X)))
					-- aiInput:show()
					-- aiBtn:show()
					-- loading:hide()
					-- saveWorld()

					print("prompt:", prompt)

					prompt = "SYSTEM: Generate a skybox in pixel art style. Do NOT include ground details, just empty sky volume, include skyline details only if specified.\n\nPROMPT: "
						.. prompt

					local body = {}
					body.prompt = prompt
					print("prompt:", body.prompt)

					local headers = {}
					headers["Content-Type"] = "application/json"

					HTTP:Post("http://localhost", headers, body, function(res)
						print("skybox generation:", res.StatusCode)
						if res.StatusCode == 200 then
							loadedAmbiance = require("ai_ambience"):loadGeneration(generation)

							local body = JSON:Decode(res.Body:ToString())
							print("body.url:", body.url)
							local textureURL = "http://localhost" .. body.url
							skybox.load({ url = textureURL }, function(obj)
								sfx("metal_clanging_2", { Spatialized = false, Volume = 0.6 })
								worldEditorCommon.updateAmbience(loadedAmbiance)
								sunRotationSlider:setValue(math.floor(math.deg(loadedAmbiance.sun.rotation.Y)))
								sunRotationXSlider:setValue(math.floor(math.deg(loadedAmbiance.sun.rotation.X)))
								aiInput:show()
								aiBtn:show()
								loading:hide()
								saveWorld()
							end)
						end
					end)

					-- local textureURL = "https://files.cu.bzh/skyboxes/skybox_2.png"
					-- skybox.load({ url = textureURL }, function(obj) end)
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
			self.Width = 200

			if addObjectBtn ~= nil then
				self.Height = math.min(
					500,
					Screen.Height - Screen.SafeArea.Bottom - Screen.SafeArea.Top - addObjectBtn.Height - padding * 3
				)
			else
				self.Height = math.min(500, Screen.Height - Screen.SafeArea.Bottom - Screen.SafeArea.Top - padding * 2)
			end

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

			skyboxBtn.pos = {
				aiBtn.pos.X + aiBtn.Width - skyboxBtn.Width,
				aiInput.pos.Y - skyboxBtn.Height - padding,
			}

			skyboxLabel.pos = {
				skyboxBtn.pos.X - skyboxLabel.Width - padding,
				skyboxBtn.pos.Y + skyboxBtn.Height * 0.5 - skyboxLabel.Height * 0.5,
			}

			btnClose.pos = {
				self.Width * 0.5 - btnClose.Width * 0.5,
				padding,
			}

			scroll.pos.Y = btnClose.pos.Y + btnClose.Height + padding
			scroll.pos.X = padding
			scroll.Height = aiInput.pos.Y - skyboxBtn.Height - padding * 2 - scroll.pos.Y
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
end

function uiHideDefaultMenu()
	if uiDefaultMenu ~= nil then
		uiDefaultMenu:hide()
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
	end
end)

local autoSaveTimer = nil
function saveWorld()
	if autoSaveTimer ~= nil then
		autoSaveTimer:Cancel()
	end
	if state >= states.DEFAULT then
		worldEditorCommon.saveWorld()
	end
	autoSaveTimer = Timer(30, saveWorld)
end
autoSaveTimer = Timer(30, saveWorld)

setState(states.LOADING)

return worldEditor
