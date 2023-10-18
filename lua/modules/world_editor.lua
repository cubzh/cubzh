local worldEditor = {}

local index = {}
local metatable = { __index = index, __metatable = false }
setmetatable(worldEditor, metatable)

local states = {
	DEFAULT = 1,
	GALLERY = 2,
	SPAWNING_OBJECT = 3,
	PLACING_OBJECT = 4,
	UPDATING_OBJECT = 5,
	DUPLICATE_OBJECT = 6,
	DESTROY_OBJECT = 7,
	AMBIENCE_EDITOR = 8,
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

local state = states.DEFAULT
local activeSubState = {}

local tryPickObject = function(pe)
	local impact = pe:CastRay()
	if not impact then return end

	local obj = impact.Object
	while obj and not obj.isEditable do
		obj = obj:GetParent()
	end
	if not obj then return end
	setState(states.UPDATING_OBJECT, obj)
end

local subStatesSettingsUpdatingObject = {
	-- DEFAULT
	{},
	-- GIZMO_MOVE
	{
		onStateChange = function()
			worldEditor.gizmo:setObject(worldEditor.object)
			worldEditor.gizmo:setMode(require("gizmo").Mode.Move)
		end,
		onStateEnd = function()
			worldEditor.gizmo:setObject(nil)
		end,
	},
	-- GIZMO_ROTATE
	{
		onStateChange = function()
			worldEditor.gizmo:setObject(worldEditor.object)
			worldEditor.gizmo:setMode(require("gizmo").Mode.Rotate)
		end,
		onStateEnd = function()
			worldEditor.gizmo:setObject(nil)
		end,
		pointerUp = function(pe)
			if worldEditor.dragging then return end
			tryPickObject(pe)
		end
	},
	-- GIZMO_SCALE
	{
		onStateChange = function()
			print("scale not available yet")
			return
		end,
		onStateEnd = function()
			worldEditor.gizmo:setObject(nil)
		end,
		pointerUp = function(pe)
			if worldEditor.dragging then return end
			tryPickObject(pe)
		end
	},
}

-- States

local statesSettings = {
	-- DEFAULT
	{
		onStateChange = function()
			worldEditor.addBtn:show()
		end,
		onStateEnd = function()
			worldEditor.addBtn:hide()
		end,
		pointerUp = function(pe)
			if worldEditor.dragging then return end
			tryPickObject(pe)
		end
	},
	-- GALLERY
	{
		onStateChange = function()
			worldEditor.gallery:show()
		end,
		onStateEnd = function()
			worldEditor.gallery:hide()
		end
	},
	-- SPAWNING_OBJECT
	{
		onStateChange = function(fullname)
			Object:Load(fullname, function(obj)
				obj:SetParent(World)
				obj.isEditable = true
				obj.root = true
				obj.fullname = fullname
				obj.Scale = 0.5
				obj.Pivot = Number3(obj.Width / 2, 0, obj.Depth / 2)
				obj.CollisionGroups = 7
				setState(states.PLACING_OBJECT, obj)
			end)
		end
	},
	-- PLACING_OBJECT
	{
		onStateChange = function(obj)
			worldEditor.rotationShift = 0
			worldEditor.placingObj = obj
		end,
		pointerMove = function(pe)
			local placingObj = worldEditor.placingObj

			-- place and rotate object
			local impact = pe:CastRay(Map.CollisionGroups + { 7 }, placingObj)
			if not impact then return end
			local pos = pe.Position + pe.Direction * impact.Distance
			placingObj.Position = pos
			placingObj.Rotation.Y = Player.Rotation.Y + worldEditor.rotationShift
		end,
		pointerDrag = function(pe)
			local placingObj = worldEditor.placingObj

			-- place and rotate object
			local impact = pe:CastRay(Map.CollisionGroups + { 7 }, placingObj)
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
				setState(states.UPDATING_OBJECT, placingObj)
			-- right click, place another one
			elseif pe.Index == 5 then
				setState(states.SPAWNING_OBJECT, placingObj.fullname)
			end
		end,
		pointerWheel = function(delta)
			worldEditor.rotationShift = worldEditor.rotationShift + delta * 0.005
			worldEditor.placingObj.Rotation.Y = Player.Rotation.Y + worldEditor.rotationShift
			return true
		end
	},
	-- UPDATING_OBJECT
	{
		onStateChange = function(obj)
			worldEditor.object = obj
			worldEditor.updateObjectUI:show()

			local currentScale = obj.Scale:Copy()
			require("ease"):inOutQuad(obj, 0.15).Scale = currentScale * 1.1
			Timer(0.15, function()
				require("ease"):inOutQuad(obj, 0.15).Scale = currentScale
			end)
			require("sfx")("waterdrop_3", { Spatialized = false, Pitch = 1 + math.random() * 0.1 })
		end,
		onStateEnd = function(nextState)
			worldEditor.updateObjectUI:hide()
			if nextState == states.DUPLICATE_OBJECT or nextState == states.DESTROY_OBJECT then
				return
			end
			worldEditor.object = nil
		end,
		subStatesSettings = subStatesSettingsUpdatingObject,
		pointerUp = function(pe)
			if worldEditor.dragging then return end
			tryPickObject(pe)
		end,
		pointerWheel = function(delta)
			worldEditor.object.Rotation.Y = worldEditor.object.Rotation.Y + delta * 0.005
			return true
		end
	},
	-- DUPLICATE_OBJECT
	{
		onStateChange = function()
			setState(states.SPAWNING_OBJECT, worldEditor.object.fullname)
		end,
		onStateEnd = function()
			worldEditor.object = nil
			worldEditor.updateObjectUI:hide()
		end
	},
	-- DESTROY_OBJECT
	{
		onStateChange = function()
			worldEditor.object:RemoveFromParent()
			worldEditor.object = nil
			worldEditor.updateObjectUI:hide()
			setState(states.DEFAULT)
		end
	},
}

setState = function(newState, data)
	local onStateEnd = statesSettings[state].onStateEnd
	if onStateEnd then onStateEnd(newState, data) end

	local subState = activeSubState[state]
	if subState then
		onStateEnd = statesSettings[state].subStatesSettings[subState].onStateEnd
		if onStateEnd then onStateEnd(newState, data) end
	end

	local oldState = state
	state = newState

	local onStateChange = statesSettings[state].onStateChange
	if onStateChange then onStateChange(data) end

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
	local subStatesSettings = statesSettings[state].subStatesSettings
	if not subStatesSettings then
		error("Current state has no subStates.", 2)
		return
	end

	local subStateSetting = subStatesSettings[activeSubState[state]]
	if subStateSetting then
		local onSubStateEnd = subStateSetting.onStateEnd
		if onSubStateEnd then
			onSubStateEnd(newSubState, data)
		end
	end

	subStateSetting = subStatesSettings[newSubState]
	if not subStateSetting then
		error("Can't currently switch to this subState, change the state before.", 2)
		return
	end

	activeSubState[state] = newSubState

	local onSubStateChange = subStateSetting.onStateChange
	if onSubStateChange then onSubStateChange(data) end
end

-- Listeners

local listeners = {
	Tick = "tick",
	PointerDown = "pointerDown",
	PointerMove = "pointerMove",
	PointerDrag = "pointerDrag",
	PointerUp = "pointerUp",
	PointerWheel = "pointerWheel",
}

for localEventName,listenerName in pairs(listeners) do
	LocalEvent:Listen(LocalEvent.Name[localEventName], function(pe)
		local stateSettings = statesSettings[state]
		local callback

        callback = stateSettings[listenerName]
		if callback then
			if callback(pe) then return true end
		end

		if stateSettings.subStatesSettings then
			local subState = activeSubState[state]
			callback = stateSettings.subStatesSettings[subState][listenerName]
			if callback then
				if callback(pe) then return true end
			end
		end
	end, { topPriority = true })
end

LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pe)
	if pe.Index ~= 4 then return end -- if not left click, return
	worldEditor.dragging = true
end)
LocalEvent:Listen(LocalEvent.Name.PointerUp, function(pe)
	if pe.Index ~= 4 then return end -- if not left click, return
	worldEditor.dragging = false
end)

-- init

local init = function()
    local ui = require("uikit")

	-- Gizmo
	Camera.Layers = { 1, 4 }
	require("gizmo"):setLayer(4)
	worldEditor.gizmo = require("gizmo"):create({ orientationMode =  require("gizmo").Mode.Local, moveSnap = 0.5 })

	-- Default ui, add btn
	local addBtn = ui:createButton("➕")
	addBtn.parentDidResize = function()
		addBtn.pos = { Screen.Width * 0.5 - addBtn.Width * 0.5, addBtn.Height * 2 }
	end
	addBtn.Height = addBtn.Height * 1.5
	addBtn.Width = addBtn.Height
	addBtn:parentDidResize()
	addBtn.onRelease = function()
		setState(states.GALLERY)
	end
	index.addBtn = addBtn

	-- Gallery
	local galleryOnOpen = function(_, cell)
		local fullname = cell.repo.."."..cell.name
		setState(states.SPAWNING_OBJECT, fullname)
	end
	worldEditor.gallery = require("gallery"):create(function() return Screen.Width end, function() return Screen.Height * 0.4 end, function(m) m.pos = { Screen.Width / 2 - m.Width / 2, 0 } end, { onOpen = galleryOnOpen })
	worldEditor.gallery:hide()

	-- Update object UI
	local updateObjectUI = ui:createFrame(Color(78, 78, 78))

	local nameTextBg = ui:createFrame(Color.Black)
	nameTextBg:setParent(updateObjectUI)
	local nameText = ui:createText("Item Name", Color.Grey, "small")
	nameText:setParent(updateObjectUI)
	local nameEditBtn = ui:createButton("✏️")
	nameEditBtn:setParent(updateObjectUI)

	local bar = require("ui_container").horizontalContainerNew()
	bar:setParent(updateObjectUI)

	local barInfo = {
		{ type="button", text="⇢", subState=subStates[states.UPDATING_OBJECT].GIZMO_MOVE },
		{ type="button", text="↻", subState=subStates[states.UPDATING_OBJECT].GIZMO_ROTATE },
		{ type="button", text="⇱", subState=subStates[states.UPDATING_OBJECT].GIZMO_SCALE },
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
			btn.onRelease = function()
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
		local padding = require("uitheme").current.padding
		local bg = updateObjectUI
		bg.Width = bar.Width + padding * 2
		bg.Height = (bar.Height + padding) * 2
		nameTextBg.Width = bg.Width
		nameTextBg.Height = bar.Height
		nameTextBg.pos = { 0, bg.Height - nameTextBg.Height }
		nameText.pos = { bg.Width * 0.5 - nameText.Width * 0.5, bar.Height + padding * 2 + bar.Height * 0.5 - nameText.Height * 0.5 }
		nameEditBtn.Width = bar.Height
		nameEditBtn.Height = bar.Height
		nameEditBtn.pos = { bg.Width - nameEditBtn.Width, bg.Height - nameEditBtn.Height }
		bar.pos = { padding, padding }
		bg.pos = { Screen.Width * 0.5 - bg.Width * 0.5, 100 }
		bg:hide()
	end
	updateObjectUI:parentDidResize()
	worldEditor.updateObjectUI = updateObjectUI
end

init()

return worldEditor