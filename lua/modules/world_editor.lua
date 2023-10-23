local worldEditor = {}

local index = {}
local metatable = { __index = index, __metatable = false }
setmetatable(worldEditor, metatable)

local initDefaultMode

local objects = {}

local TRAILS_COLORS = { Color.Blue, Color.Red, Color.Green, Color.Yellow, Color.Grey, Color.Purple, Color.Beige, Color.Yellow, Color.Brown, Color.Pink }
local OBJECTS_COLLISION_GROUP = 7
local ALPHA_ON_DRAG = 0.6

local random = math.random
local function uuidv4()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

local getObjectInfoTable = function(obj)
	local physics = "SPB"
	if obj.Physics == PhysicsMode.StaticPerBlock then physics = "SPB" end
	if obj.Physics == PhysicsMode.Dynamic then physics = "D" end

	return {
		uuid = obj.uuid,
		fullname = obj.fullname,
		Position = { obj.Position.X, obj.Position.Y, obj.Position.Z },
		Rotation = { obj.Rotation.X, obj.Rotation.Y, obj.Rotation.Z },
		Scale = { obj.Scale.X, obj.Scale.Y, obj.Scale.Z },
		Name = obj.Name,
		itemDetailsCell = obj.itemDetailsCell,
		Physics = physics
	}
end

-- multiplayer

local events = {
	P_END_PREPARING = "pep",
	END_PREPARING = "ep",
	P_PLACE_OBJECT = "ppo",
	PLACE_OBJECT = "po",
	P_EDIT_OBJECT = "peo",
	EDIT_OBJECT = "eo",
	P_REMOVE_OBJECT = "pro",
	REMOVE_OBJECT = "ro",
	P_PLACE_BLOCK = "ppb",
	PLACE_BLOCK = "pb",
	P_REMOVE_BLOCK = "prb",
	REMOVE_BLOCK = "rb",
	P_START_EDIT_OBJECT = "pseo",
	START_EDIT_OBJECT = "seo",
	P_END_EDIT_OBJECT = "peeo",
	END_EDIT_OBJECT = "eeo",
	SYNC = "s",
	MASTER = "m"
}

local sendToServer = function(event, data)
	local e = Event()
	e.a = event
	e.data = JSON:Encode(data)
	e:SendTo(Server)
end

local states = {
	PREPARING = 1,
	DEFAULT = 2,
	GALLERY = 3,
	SPAWNING_OBJECT = 4,
	PLACING_OBJECT = 5,
	UPDATING_OBJECT = 6,
	DUPLICATE_OBJECT = 7,
	DESTROY_OBJECT = 8,
	EDIT_MAP = 9,
}

-- Substates

local subStates = {
	[states.UPDATING_OBJECT] = {
		DEFAULT = 1,
		GIZMO_MOVE = 2,
		GIZMO_ROTATE = 3,
		GIZMO_SCALE = 4,
	}
}

local setState
local setSubState

local state = states.PREPARING
local activeSubState = {}

local tryPickObject = function(pe)
	local impact = pe:CastRay()
	if not impact then return end

	local obj = impact.Object
	while obj and not obj.isEditable do
		obj = obj:GetParent()
	end
	if not obj then setState(states.DEFAULT) return end

	if obj.currentlyEditedBy then
		print("Someone else is editing this object, please wait")
		return
	end
	setState(states.UPDATING_OBJECT, obj)
end

local setObjectAlpha = function(obj, alpha)
	require("hierarchyactions"):applyToDescendants(obj, { includeRoot = true }, function(o)
		if not o.savedAlpha then
			o.savedAlpha = {}
			for k=1,#o.Palette do
				local c = o.Palette[k]
				o.savedAlpha[k] = c.Color.Alpha / 255
			end
		end
		for k=1,#o.Palette do
			local c = o.Palette[k]
			c.Color.Alpha = o.savedAlpha[k] * alpha
		end
		o:RefreshModel()
	end)
end

local freezeObject = function(obj)
	obj.savedPhysicsState = obj.Physics
	if obj.Physics == PhysicsMode.StaticPerBlock then return end
	require("hierarchyactions"):applyToDescendants(obj, { includeRoot = true }, function(o)
		o.Physics = PhysicsMode.StaticPerBlock
	end)
end

local unfreezeObject = function(obj)
	local physics = obj.savedPhysicsState
	if physics == PhysicsMode.StaticPerBlock then
		require("hierarchyactions"):applyToDescendants(obj, { includeRoot = true }, function(o)
			o.Physics = PhysicsMode.StaticPerBlock
		end)
		sendToServer(events.P_EDIT_OBJECT, {
			uuid = obj.uuid,
			Physics = "SPB"
		})
	else
		obj.Physics = PhysicsMode.Dynamic
		require("hierarchyactions"):applyToDescendants(obj, { includeRoot = false }, function(o)
			o.Physics = PhysicsMode.Disabled
		end)
		sendToServer(events.P_EDIT_OBJECT, {
			uuid = obj.uuid,
			Physics = "D"
		})
	end
end

local spawnObject = function(data, onDone)
	local uuid = data.uuid
	local fullname = data.fullname
	local name = data.Name
	local position = data.Position or Number3(0,0,0)
	local rotation = data.Rotation or Rotation(0,0,0)
	local scale = data.Scale or 0.5
	local itemDetailsCell = data.itemDetailsCell
	if data.Physics == "SPB" then data.Physics = PhysicsMode.StaticPerBlock end
	if data.Physics == "D" then data.Physics = PhysicsMode.Dynamic end
	local physics = data.Physics or PhysicsMode.StaticPerBlock

	Object:Load(fullname, function(obj)
		obj:SetParent(World)
		if physics == PhysicsMode.StaticPerBlock then
			require("hierarchyactions"):applyToDescendants(obj, { includeRoot = true }, function(o)
				o.Physics = PhysicsMode.StaticPerBlock
			end)
		else
			obj.Physics = PhysicsMode.Dynamic
			require("hierarchyactions"):applyToDescendants(obj, { includeRoot = false }, function(o)
				o.Physics = PhysicsMode.Disabled
			end)
		end
		obj.uuid = uuid
		obj.Position = position
		obj.Rotation = rotation
		obj.Scale = scale
		obj.Pivot = Number3(obj.Width / 2, 0, obj.Depth / 2)
		obj.CollisionGroups = { 3, OBJECTS_COLLISION_GROUP }

		obj.isEditable = true
		obj.fullname = fullname
		obj.Name = name or fullname
		obj.itemDetailsCell = itemDetailsCell

		objects[obj.uuid] = obj
		if onDone then onDone(obj) end
	end)
end

local editObject = function(objInfo)
	local obj = objects[objInfo.uuid]
	if not obj then print("Missing an object") return end
	for field,value in pairs(objInfo) do
		if field == "Physics" then
			if value == "D" then obj.Physics = PhysicsMode.Dynamic end
			if value == "SPB" then obj.Physics = PhysicsMode.StaticPerBlock end
		else
			obj[field] = value
		end
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

local subStatesSettingsUpdatingObject = {
	-- DEFAULT
	{
		pointerUp = function(pe)
			if worldEditor.dragging then return end
			tryPickObject(pe)
		end
	},
	-- GIZMO_MOVE
	{
		onStateBegin = function()
			worldEditor.gizmo:setObject(worldEditor.object)
			worldEditor.gizmo:setMode(require("gizmo").Mode.Move)
			worldEditor.gizmo:setOnMoveBegin(function()
				setObjectAlpha(worldEditor.object, ALPHA_ON_DRAG)
				sendToServer(events.P_EDIT_OBJECT, { uuid = worldEditor.object.uuid, alpha = ALPHA_ON_DRAG })
			end)
			worldEditor.gizmo:setOnMoveEnd(function()
				setObjectAlpha(worldEditor.object, 1)
				sendToServer(events.P_EDIT_OBJECT, { uuid = worldEditor.object.uuid, alpha = 1 })
			end)
			worldEditor.gizmo:setOnMove(function()
				sendToServer(events.P_EDIT_OBJECT, {
					uuid = worldEditor.object.uuid,
					Position = { worldEditor.object.Position.X, worldEditor.object.Position.Y, worldEditor.object.Position.Z }
				})
			end)
			freezeObject(worldEditor.object)
		end,
		onStateEnd = function()
			worldEditor.gizmo:setObject(nil)
			unfreezeObject(worldEditor.object)
		end,
		pointerUp = function(pe)
			if worldEditor.dragging then return end
			tryPickObject(pe)
		end
	},
	-- GIZMO_ROTATE
	{
		onStateBegin = function()
			worldEditor.gizmo:setObject(worldEditor.object)
			worldEditor.gizmo:setMode(require("gizmo").Mode.Rotate)
			worldEditor.gizmo:setOnRotateBegin(function()
				setObjectAlpha(worldEditor.object, ALPHA_ON_DRAG)
				sendToServer(events.P_EDIT_OBJECT, { uuid = worldEditor.object.uuid, alpha = ALPHA_ON_DRAG })
			end)
			worldEditor.gizmo:setOnRotateEnd(function()
				setObjectAlpha(worldEditor.object, 1)
				sendToServer(events.P_EDIT_OBJECT, { uuid = worldEditor.object.uuid, alpha = 1 })
			end)
			worldEditor.gizmo:setOnRotate(function()
				sendToServer(events.P_EDIT_OBJECT, {
					uuid = worldEditor.object.uuid,
					Rotation = { worldEditor.object.Rotation.X, worldEditor.object.Rotation.Y, worldEditor.object.Rotation.Z }
				})
			end)
			freezeObject(worldEditor.object)
		end,
		onStateEnd = function()
			worldEditor.gizmo:setObject(nil)
			unfreezeObject(worldEditor.object)
		end,
		pointerUp = function(pe)
			if worldEditor.dragging then return end
			tryPickObject(pe)
		end
	},
	-- GIZMO_SCALE
	{
		onStateBegin = function()
			worldEditor.gizmo:setObject(worldEditor.object)
			worldEditor.gizmo:setMode(require("gizmo").Mode.Scale)
			worldEditor.gizmo:setOnScaleBegin(function()
				setObjectAlpha(worldEditor.object, ALPHA_ON_DRAG)
				sendToServer(events.P_EDIT_OBJECT, { uuid = worldEditor.object.uuid, alpha = ALPHA_ON_DRAG })
			end)
			worldEditor.gizmo:setOnScaleEnd(function()
				setObjectAlpha(worldEditor.object, 1)
				sendToServer(events.P_EDIT_OBJECT, { uuid = worldEditor.object.uuid, alpha = 1 })
			end)
			worldEditor.gizmo:setOnScale(function()
				sendToServer(events.P_EDIT_OBJECT, {
					uuid = worldEditor.object.uuid,
					Scale = { worldEditor.object.Scale.X, worldEditor.object.Scale.Y, worldEditor.object.Scale.Z }
				})
			end)
			freezeObject(worldEditor.object)
		end,
		onStateEnd = function()
			worldEditor.gizmo:setObject(nil)
			unfreezeObject(worldEditor.object)
		end,
		pointerUp = function(pe)
			if worldEditor.dragging then return end
			tryPickObject(pe)
		end
	},
}

-- States

local statesSettings = {
	-- PREPARING
	{
		onStateEnd = function()
			worldEditor.uiPrepareState:remove()
			worldEditor.uiPrepareState = nil
			initDefaultMode()
		end
	},
	-- DEFAULT
	{
		onStateBegin = function()
			worldEditor.addBtn:show()
			worldEditor.editMapBtn:show()
		end,
		onStateEnd = function()
			worldEditor.addBtn:hide()
			worldEditor.editMapBtn:hide()
		end,
		pointerUp = function(pe)
			if worldEditor.dragging then return end
			tryPickObject(pe)
		end
	},
	-- GALLERY
	{
		onStateBegin = function()
			worldEditor.gallery:show()
		end,
		onStateEnd = function()
			worldEditor.gallery:hide()
		end
	},
	-- SPAWNING_OBJECT
	{
		onStateBegin = function(data)
			data.uuid = uuidv4()
			spawnObject(data, function(obj)
				setState(states.PLACING_OBJECT, obj)
			end)
		end
	},
	-- PLACING_OBJECT
	{
		onStateBegin = function(obj)
			worldEditor.rotationShift = 0
			worldEditor.placingObj = obj
		end,
		pointerMove = function(pe)
			local placingObj = worldEditor.placingObj

			-- place and rotate object
			local impact = pe:CastRay(Map.CollisionGroups + { OBJECTS_COLLISION_GROUP }, placingObj)
			if not impact then return end
			local pos = pe.Position + pe.Direction * impact.Distance
			placingObj.Position = pos
			placingObj.Rotation.Y = Player.Rotation.Y + worldEditor.rotationShift
		end,
		pointerDrag = function(pe)
			local placingObj = worldEditor.placingObj

			-- place and rotate object
			local impact = pe:CastRay(Map.CollisionGroups + { OBJECTS_COLLISION_GROUP }, placingObj)
			if not impact then return end
			local pos = pe.Position + pe.Direction * impact.Distance
			placingObj.Position = pos
			placingObj.Rotation.Y = Player.Rotation.Y + worldEditor.rotationShift
		end,
		pointerUp = function(pe)
			if worldEditor.dragging then return end
			local placingObj = worldEditor.placingObj

			-- drop object
			worldEditor.placingObj = nil

			-- smooth bump
			local currentScale = placingObj.Scale:Copy()
			require("ease"):inOutQuad(placingObj, 0.15).Scale = currentScale * 1.1
			Timer(0.15, function()
				require("ease"):inOutQuad(placingObj, 0.15).Scale = currentScale
			end)
			require("sfx")("waterdrop_3", { Spatialized = false, Pitch = 1 + math.random() * 0.1 })

			-- left click, back to default
			if pe.Index == 4 then
				objects[placingObj.uuid] = placingObj
				setState(states.UPDATING_OBJECT, placingObj)
				sendToServer(events.P_PLACE_OBJECT, getObjectInfoTable(placingObj))
			end
		end,
		pointerWheelPriority = function(delta)
			worldEditor.rotationShift = worldEditor.rotationShift + delta * 0.005
			worldEditor.placingObj.Rotation.Y = Player.Rotation.Y + worldEditor.rotationShift
			return true
		end
	},
	-- UPDATING_OBJECT
	{
		onStateBegin = function(obj)
			worldEditor.object = obj
			obj.currentlyEditedBy = Player
			worldEditor.physicsBtn.Text = obj.Physics == PhysicsMode.Dynamic and "Dynamic" or "Static "
			worldEditor.nameInput.Text = obj.Name
			worldEditor.nameInput.onTextChange = function(o)
				worldEditor.object.Name = o.Text
				sendToServer(events.P_EDIT_OBJECT, { uuid = worldEditor.object.uuid, Name = o.Text })
			end
			worldEditor.infoBtn.onRelease = function()
				local cell = worldEditor.object.itemDetailsCell
				require("item_details"):createModal({ cell=cell })
			end
			worldEditor.updateObjectUI:show()

			local currentScale = obj.Scale:Copy()
			require("ease"):inOutQuad(obj, 0.15).Scale = currentScale * 1.1
			Timer(0.15, function()
				require("ease"):inOutQuad(obj, 0.15).Scale = currentScale
			end)
			require("sfx")("waterdrop_3", { Spatialized = false, Pitch = 1 + math.random() * 0.1 })

			sendToServer(events.P_START_EDIT_OBJECT, { uuid = obj.uuid })
			worldEditor.object.trail = require("trail"):create(Player, obj, TRAILS_COLORS[Player.ID], 0.5)
		end,
		onStateEnd = function(nextState)
			worldEditor.updateObjectUI:hide()
			sendToServer(events.P_END_EDIT_OBJECT, { uuid = worldEditor.object.uuid })
			worldEditor.object.trail:remove()
			if nextState == states.DUPLICATE_OBJECT or nextState == states.DESTROY_OBJECT then
				return
			end
			worldEditor.object = nil
		end,
		subStatesSettings = subStatesSettingsUpdatingObject,
		pointerWheelPriority = function(delta)
			worldEditor.object.Rotation.Y = worldEditor.object.Rotation.Y + delta * 0.005
			return true
		end
	},
	-- DUPLICATE_OBJECT
	{
		onStateBegin = function()
			local obj = worldEditor.object
			local data = getObjectInfoTable(obj)
			data.uuid = nil
			setState(states.SPAWNING_OBJECT, data)
		end,
		onStateEnd = function()
			worldEditor.object = nil
			worldEditor.updateObjectUI:hide()
		end
	},
	-- DESTROY_OBJECT
	{
		onStateBegin = function()
			sendToServer(events.P_REMOVE_OBJECT, { uuid = worldEditor.object.uuid })
			worldEditor.object = nil
			worldEditor.updateObjectUI:hide()
			setState(states.DEFAULT)
		end
	},
	-- EDIT_MAP
	{
		onStateBegin = function()
			worldEditor.selectedColor = Color.Grey
			local block = MutableShape()
			worldEditor.handBlock = block
			block:AddBlock(worldEditor.selectedColor, 0, 0, 0)
			Player:EquipRightHand(block)
			block.Scale = 5
			block.LocalPosition = { 1.5,1.5,1.5 }
			worldEditor.editMapBar:show()
			worldEditor.colorPicker:show()
			worldEditor.colorPicker.parentDidResize = function()
				worldEditor.colorPicker.pos = { Screen.Width - worldEditor.colorPicker.Width, -20 }
			end
			worldEditor.colorPicker:parentDidResize()
		end,
		onStateEnd = function()
			Player:EquipRightHand(nil)
			worldEditor.editMapBar:hide()
			worldEditor.colorPicker:hide()
		end,
		pointerUp = function(pe)
			if worldEditor.dragging then return end
			local impact = pe:CastRay(nil, Player)
			if not impact or not impact.Object == Map then return end
			if pe.Index == 4 then
				local pos = impact.Block.Coords
				sendToServer(events.P_REMOVE_BLOCK, { pos = { pos.X, pos.Y, pos.Z } })
				impact.Block:Remove()
			elseif pe.Index == 5 then
				impact.Block:AddNeighbor(worldEditor.selectedColor, impact.FaceTouched)
				local pos = impact.Block.Coords:Copy()
				if impact.FaceTouched == Face.Front then pos.Z = pos.Z + 1
				elseif impact.FaceTouched == Face.Back then pos.Z = pos.Z - 1
				elseif impact.FaceTouched == Face.Top then pos.Y = pos.Y + 1
				elseif impact.FaceTouched == Face.Bottom then pos.Y = pos.Y - 1
				elseif impact.FaceTouched == Face.Right then pos.X = pos.X + 1
				elseif impact.FaceTouched == Face.Left then pos.X = pos.X - 1 end
				sendToServer(events.P_PLACE_BLOCK, {
					pos = { pos.X, pos.Y, pos.Z },
					color = { worldEditor.selectedColor.R, worldEditor.selectedColor.G, worldEditor.selectedColor.B }
				})
			end
		end
	}
}

setState = function(newState, data)
	local subState = activeSubState[state]
	if subState then
		onStateEnd = statesSettings[state].subStatesSettings[subState].onStateEnd
		if onStateEnd then onStateEnd(newState, data) end
	end

	local onStateEnd = statesSettings[state].onStateEnd
	if onStateEnd then onStateEnd(newState, data) end

	local oldState = state
	state = newState

	local onStateBegin = statesSettings[state].onStateBegin
	if onStateBegin then onStateBegin(data) end

	if statesSettings[state].subStatesSettings then
		-- if changing state, then going back to default
		if oldState ~= state then
			setSubState(subStates[state].DEFAULT)
		-- else keep the current subState
		else
			setSubState(activeSubState[state])
		end
	end
end

setSubState = function(newSubState, data)
	local subStatesSettings
	local subStateSetting

	-- handle onStateEnd for subState
	subStatesSettings = statesSettings[state].subStatesSettings
	if subStatesSettings then
		subStateSetting = subStatesSettings[activeSubState[state]]
		if subStateSetting then
			local onSubStateEnd = subStateSetting.onStateEnd
			if onSubStateEnd then
				onSubStateEnd(newSubState, data)
			end
		end
	end

	-- handle onStateBegin for subState
	subStatesSettings = statesSettings[state].subStatesSettings
	if not subStatesSettings then
		error("Current state has no subStates.", 2)
		return
	end

	subStateSetting = subStatesSettings[newSubState]
	if not subStateSetting then
		error("Can't currently switch to this subState, change the state before.", 2)
		return
	end

	activeSubState[state] = newSubState

	local onSubStateBegin = subStateSetting.onStateBegin
	if onSubStateBegin then onSubStateBegin(data) end
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
}

local function handleLocalEventListener(listenerName, pe)
	local stateSettings = statesSettings[state]
	local callback

	if stateSettings.subStatesSettings then
		local subState = activeSubState[state]
		callback = stateSettings.subStatesSettings[subState][listenerName]
		if callback then
			if callback(pe) then return true end
		end
	end

	callback = stateSettings[listenerName]
	if callback then
		if callback(pe) then return true end
	end
end

for localEventName,listenerName in pairs(listeners) do
	LocalEvent:Listen(LocalEvent.Name[localEventName], function(pe)
		return handleLocalEventListener(listenerName .. "Priority", pe)
	end, { topPriority = true })
	LocalEvent:Listen(LocalEvent.Name[localEventName], function(pe)
		return handleLocalEventListener(listenerName, pe)
	end, { topPriority = false })
end

LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pe)
	if pe.Index ~= 4 then return end -- if not left click, return
	worldEditor.draggingCount = (worldEditor.draggingCount or 0) + 1
	if worldEditor.draggingCount > 4 then worldEditor.dragging = true end
end)
LocalEvent:Listen(LocalEvent.Name.PointerUp, function(pe)
	if pe.Index ~= 4 then return end -- if not left click, return
	worldEditor.draggingCount = 0
	worldEditor.dragging = false
end)

-- init

local map
local maps = {
	"aduermael.hills",
	"aduermael.base_250x40x250",
	"claire.harbour",
	"buche.chess_board",
	"claire.apocalyptic_city",
	"aduermael.unicorn_land",
	"boumety.building_challenge",
	"claire.museum",
	"claire.summer_beach",
	"claire.voxowl_hq"
}

local loadMap

init = function()
	math.randomseed(Player.ID + Time.UnixMilli())

	require("object_skills").addStepClimbing(Player)
	Camera:SetModeFree()
	local pivot = Object()
	pivot.Tick = function(pvt, dt)
		pvt.Rotation.Y = pvt.Rotation.Y + dt * 0.06
	end
	pivot:SetParent(World)
	Camera:SetParent(pivot)
	Camera.Far = 10000

	local mapIndex = 1

	local ui = require("uikit")
	local padding = require("uitheme").current.padding

	uiPrepareState = ui:createFrame()

	previousBtn = ui:createButton("<")
	previousBtn:setParent(uiPrepareState)
	previousBtn.pos = { 50, Screen.Height * 0.5 - previousBtn.Height * 0.5}
	previousBtn.onRelease = function()
		mapIndex = mapIndex - 1
		if mapIndex <= 0 then mapIndex = #maps end
		loadMap(maps[mapIndex])
	end
	nextBtn = ui:createButton(">")
	nextBtn:setParent(uiPrepareState)
	nextBtn.pos = { Screen.Width - 50 - nextBtn.Width, Screen.Height * 0.5 - nextBtn.Height * 0.5}
	nextBtn.onRelease = function()
		mapIndex = mapIndex + 1
		if mapIndex > #maps then mapIndex = 1 end
		loadMap(maps[mapIndex])
	end
	validateBtn = ui:createButton("Start editing this map")
	validateBtn:setParent(uiPrepareState)
	validateBtn.pos = { Screen.Width * 0.5 - validateBtn.Width * 0.5, padding }
	validateBtn.onRelease = function()
		sendToServer(events.P_END_PREPARING, { mapIndex = mapIndex })
	end

	worldEditor.uiPrepareState = uiPrepareState

	loadMap = function(fullname, onDone)
		Object:Load(fullname, function(obj)
			if map then map:RemoveFromParent() end
			map = MutableShape(obj)
			map.Scale = 5
			map.CollisionGroups = Map.CollisionGroups
			map.CollidesWithGroups = Map.CollidesWithGroups
			map.Physics = PhysicsMode.StaticPerBlock
			map:SetParent(World)
			map.Position = { 0, 0, 0 }
			map.Pivot = { 0, 0, 0 }

			Fog.On = false
			Camera.Rotation.Y = math.pi / 2
			Camera.Rotation.X = math.pi / 4

			local longestValue =  math.max(map.Width, math.max(map.Height,map.Depth))
			pivot.Position = Number3(map.Width * 0.5, longestValue, map.Depth * 0.5) * map.Scale
			Camera.Position = pivot.Position + { -longestValue * 4, 0, 0 }
			if onDone then onDone() end
		end)
	end

	loadMap(maps[1])
end

initDefaultMode = function()
	Fog.On = true
    dropPlayer = function()
        Player.Position = Number3(map.Width * 0.5, map.Height + 10, map.Depth * 0.5) * map.Scale
        Player.Rotation = { 0, 0, 0 }
        Player.Velocity = { 0, 0, 0 }
    end
    Player:SetParent(World)
	Camera:SetModeThirdPerson()
    dropPlayer()

	require("jumpfly")

	Client.Tick = function()
		if Player.Position.Y < -500 then
			dropPlayer()
			Player:TextBubble("💀 Oops!", true)
		end
	end

    local ui = require("uikit")
	local padding = require("uitheme").current.padding

	-- Gizmo
	Camera.Layers = { 1, 4 }
	require("gizmo"):setLayer(4)
	worldEditor.gizmo = require("gizmo"):create({ orientationMode =  require("gizmo").Mode.Local, moveSnap = 0.5 })

	-- Default ui, add btn
	local addBtn = ui:createButton("➕ Object")
	addBtn.parentDidResize = function()
		addBtn.pos = { Screen.Width * 0.5 - addBtn.Width - padding * 0.5, padding }
	end
	addBtn.Height = addBtn.Height * 1.5
	addBtn:parentDidResize()
	addBtn.onRelease = function()
		setState(states.GALLERY)
	end
	index.addBtn = addBtn

	-- editMap btn
	local editMapBtn = ui:createButton("🖌 Map")
	editMapBtn.parentDidResize = function()
		editMapBtn.pos = { Screen.Width * 0.5 + padding * 0.5, padding }
	end
	editMapBtn.Height = editMapBtn.Height * 1.5
	editMapBtn:parentDidResize()
	editMapBtn.onRelease = function()
		setState(states.EDIT_MAP)
	end
	index.editMapBtn = editMapBtn

	-- Gallery
	local galleryOnOpen = function(_, cell)
		local fullname = cell.repo.."."..cell.name
		setState(states.SPAWNING_OBJECT, { fullname = fullname, itemDetailsCell = cell })
	end
	local initGallery
	initGallery = function()
		worldEditor.gallery = require("gallery"):create(function() return Screen.Width end, function() return Screen.Height * 0.4 end, function(m) m.pos = { Screen.Width / 2 - m.Width / 2, 0 } end, { onOpen = galleryOnOpen })
		worldEditor.gallery.didClose = function()
			setState(states.DEFAULT)
			initGallery()
		end
		worldEditor.gallery:hide()
	end
	initGallery()

	-- Update object UI
	local updateObjectUI = ui:createFrame(Color(78, 78, 78))

	local nameInput = ui:createTextInput("", "Item Name")
	nameInput:setParent(updateObjectUI)
	worldEditor.nameInput = nameInput

	local infoBtn = ui:createButton("👁")
	infoBtn:setParent(updateObjectUI)
	worldEditor.infoBtn = infoBtn

	local bar = require("ui_container").createHorizontalContainer()
	bar:setParent(updateObjectUI)

	local barInfo = {
		{ type="button", text="⇢", subState=subStates[states.UPDATING_OBJECT].GIZMO_MOVE },
		{ type="button", text="↻", subState=subStates[states.UPDATING_OBJECT].GIZMO_ROTATE },
		{ type="button", text="⇱", subState=subStates[states.UPDATING_OBJECT].GIZMO_SCALE },
		{ type="separator" },
		{ type="button", text="Static ", callback=function(btn)
			local obj = worldEditor.object

			if btn.Text == "Static " then
				btn.Text = "Dynamic"
				if activeSubState[state] == subStates[state].DEFAULT then
					obj.Physics = PhysicsMode.Dynamic
					require("hierarchyactions"):applyToDescendants(obj, { includeRoot = false }, function(o)
						o.Physics = PhysicsMode.Disabled
					end)

					sendToServer(events.P_EDIT_OBJECT, {
						uuid = obj.uuid,
						Physics = "D"
					})
				else
					-- if using gizmo, do not apply physics yet
					obj.savedPhysicsState = PhysicsMode.Dynamic
				end
			else
				btn.Text = "Static "
				if activeSubState[state] == subStates[state].DEFAULT then
					require("hierarchyactions"):applyToDescendants(obj, { includeRoot = true }, function(o)
						o.Physics = PhysicsMode.StaticPerBlock
					end)

					sendToServer(events.P_EDIT_OBJECT, {
						uuid = obj.uuid,
						Physics = "SPB"
					})
				else
					-- if using gizmo, do not apply physics yet
					obj.savedPhysicsState = PhysicsMode.StaticPerBlock
				end
			end
		end },
		{ type="separator" },
		{ type="button", text="📑", state=states.DUPLICATE_OBJECT },
		{ type="gap" },
		{ type="button", text="💀", state=states.DESTROY_OBJECT },
		{ type="gap" },
		{ type="button", text="✅", state=states.DEFAULT },
	}

	for _,elem in ipairs(barInfo) do
		if elem.type == "button" then
			local btn = ui:createButton(elem.text)
			if worldEditor.physicsBtn == nil and elem.text == "Static " then
				worldEditor.physicsBtn = btn
			end
			btn.onRelease = function()
				if elem.callback then
					elem.callback(btn)
					return
				end
				if elem.state then
					setState(elem.state)
				end
				if elem.subState then
					if activeSubState[state] == elem.subState then
						setSubState(subStates[state].DEFAULT)
					else
						setSubState(elem.subState)
					end
				end
			end
			bar:pushElement(btn)
		elseif elem.type == "separator" then
			bar:pushSeparator()
		elseif elem.type == "gap" then
			bar:pushGap()
		end
	end

	updateObjectUI.parentDidResize = function()
		local bg = updateObjectUI
		bg.Width = bar.Width + padding * 2
		bg.Height = (bar.Height + padding) * 2
		infoBtn.Height = bar.Height
		infoBtn.Width = bar.Height
		nameInput.Width = bg.Width - infoBtn.Width
		nameInput.Height = bar.Height
		nameInput.pos = { 0, bg.Height - nameInput.Height }
		infoBtn.pos = { nameInput.Width, bg.Height - nameInput.Height }
		bar.pos = { padding, padding }
		bg.pos = { Screen.Width * 0.5 - bg.Width * 0.5, padding }
		bg:hide()
	end
	updateObjectUI:hide()
	updateObjectUI:parentDidResize()
	worldEditor.updateObjectUI = updateObjectUI

	-- Ambience editor
	local aiAmbienceButton = require("ui_ai_ambience")
	aiAmbienceButton.parentDidResize = function()
		aiAmbienceButton.pos = { padding, Screen.Height - 90 }
	end
	aiAmbienceButton:parentDidResize()

	-- Edit Map
	local editMapBar = require("ui_container").createHorizontalContainer()

	local editMapBarInfo = {
		{ type="button", text="✅", state=states.DEFAULT },
	}

	for _,elem in ipairs(editMapBarInfo) do
		if elem.type == "button" then
			local btn = ui:createButton(elem.text)
			btn.onRelease = function()
				if elem.callback then
					elem.callback(btn)
					return
				end
				if elem.state then
					setState(elem.state)
				end
				if elem.subState then
					if activeSubState[state] == elem.subState then
						setSubState(subStates[state].DEFAULT)
					else
						setSubState(elem.subState)
					end
				end
			end
			editMapBar:pushElement(btn)
		elseif elem.type == "separator" then
			editMapBar:pushSeparator()
		elseif elem.type == "gap" then
			editMapBar:pushGap()
		end
	end

	editMapBar.parentDidResize = function()
		editMapBar.pos = { Screen.Width * 0.5 - editMapBar.Width * 0.5, padding }
	end
	editMapBar:parentDidResize()
	editMapBar:hide()
	worldEditor.editMapBar = editMapBar

	local picker = require("colorpicker"):create({ closeBtnIcon = "", uikit = ui, transparency = false, colorPreview = false })
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

init()

LocalEvent:Listen(LocalEvent.Name.DidReceiveEvent, function(e)
	local data = e.data and JSON:Decode(e.data) or nil
	local sender = Players[e.pID]
	local isLocalPlayer = e.pID == Player.ID

	if e.a == events.END_PREPARING then
		local mapIndex = data.mapIndex
		loadMap(maps[mapIndex], function()
			setState(states.DEFAULT)
		end)
	elseif e.a == events.SYNC then
		if state == states.PREPARING then -- joining
			local mapIndex = data.mapIndex
			loadMap(maps[mapIndex], function()
				setState(states.DEFAULT)
				if data.blocks then
					local blocks = data.blocks
					for _,d in ipairs(blocks) do
						local k = d[1]
						local v = d[2]
						local x = math.floor(k % 1000)
						local y = math.floor((k / 1000) % 1000)
						local z = math.floor(k / 1000000)
						if v == -1 then
							local b = map:GetBlock(x,y,z)
							if b then b:Remove() end
						else
							local c = Color(math.floor(v[1]),math.floor(v[2]),math.floor(v[3]))
							local b = map:GetBlock(x,y,z)
							if b then b:Remove() end
							map:AddBlock(c, x, y, z)
						end
					end
				end
				if data.objects then
					for _,objInfo in ipairs(data.objects) do
						spawnObject(objInfo)
					end
				end
			end)
		end
	elseif e.a == events.PLACE_OBJECT and not isLocalPlayer then
		spawnObject(data)
	elseif e.a == events.EDIT_OBJECT and not isLocalPlayer then
		editObject(data)
	elseif e.a == events.REMOVE_OBJECT then
		removeObject(data)
	elseif e.a == events.START_EDIT_OBJECT and not isLocalPlayer then
		Timer(0.5, function()
			local obj = objects[data.uuid]
			if not obj then return end
			obj.currentlyEditedBy = sender
			obj.trail = require("trail"):create(sender, obj, TRAILS_COLORS[sender.ID], 0.5)
		end)
	elseif e.a == events.END_EDIT_OBJECT then
		local obj = objects[data.uuid]
		obj.trail:remove()
		obj.currentlyEditedBy = nil
		obj.trail = nil
	elseif e.a == events.PLACE_BLOCK and not isLocalPlayer then
		local color = Color(math.floor(data.color[1]),math.floor(data.color[2]),math.floor(data.color[3]))
		map:AddBlock(color, data.pos[1], data.pos[2], data.pos[3])
	elseif e.a == events.REMOVE_BLOCK and not isLocalPlayer then
		local b = map:GetBlock(data.pos[1], data.pos[2], data.pos[3])
		if b then b:Remove() end
	end
end)

return worldEditor