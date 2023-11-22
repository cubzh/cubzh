--[[

Welcome to the cubzh hub script!

Want to create something like this?
Go to https://docs.cu.bzh/

]]
--

Config = {
	Items = {},
}

Dev.DisplayFPS = true

local MINIMUM_ITEM_SIZE_FOR_SHADOWS = 40
local MINIMUM_ITEM_SIZE_FOR_SHADOWS_SQR = MINIMUM_ITEM_SIZE_FOR_SHADOWS * MINIMUM_ITEM_SIZE_FOR_SHADOWS
local MAP_SCALE = 5.5

local SPAWN_IN_BLOCK = Number3(105, 15, 58)

directionalPad = Client.DirectionalPad
action1 = function()
	-- if Player.IsOnGround then
	Player.Velocity.Y = 100
	-- print(Player.Position / map.Scale)
	-- end
end

Client.DirectionalPad = nil
Client.Action1 = nil

Client.Action2 = function() end

Client.OnStart = function()
	require("multi")
	require("textbubbles").displayPlayerChatBubbles = true
	hierarchyactions = require("hierarchyactions")
	bundle = require("bundle")
	worldEditorCommon = require("world_editor_common")

	objectSkills = require("object_skills")

	-- LOAD MAP
	local mapdata = bundle.Data("misc/hubmap.b64")

	world = worldEditorCommon.deserializeWorld(mapdata:ToString())

	MAP_SCALE = world.mapScale or 5

	map = bundle.Shape(world.mapName)
	map.Scale = MAP_SCALE
	hierarchyactions:applyToDescendants(map, { includeRoot = true }, function(o)
		o.CollisionGroups = Map.CollisionGroups
		o.CollidesWithGroups = Map.CollidesWithGroups
		o.Physics = PhysicsMode.StaticPerBlock
	end)
	map:SetParent(World)
	map.Position = { 0, 0, 0 }
	map.Pivot = { 0, 0, 0 }

	local loadedObjects = {}
	local o
	if world.objects then
		for _, objInfo in ipairs(world.objects) do
			if loadedObjects[objInfo.fullname] == nil then
				ok = pcall(function()
					o = bundle.Shape(objInfo.fullname)
				end)
				if ok then
					loadedObjects[objInfo.fullname] = o
				else
					loadedObjects[objInfo.fullname] = "ERROR"
					print("could not load " .. objInfo.fullname)
				end
			end
		end
	end

	local obj
	local scale
	local boxSize
	local turnOffShadows
	local k
	if world.objects then
		for _, objInfo in ipairs(world.objects) do
			o = loadedObjects[objInfo.fullname]
			if o ~= nil and o ~= "ERROR" then
				obj = Shape(o, { includeChildren = true })
				obj:SetParent(World)
				k = Box()
				k:Fit(obj, true)

				scale = objInfo.Scale or 0.5
				boxSize = k.Size * scale
				turnOffShadows = false

				if boxSize.SquaredLength < MINIMUM_ITEM_SIZE_FOR_SHADOWS_SQR then
					turnOffShadows = true
				end

				obj.Pivot = Number3(obj.Width / 2, k.Min.Y + obj.Pivot.Y, obj.Depth / 2)
				hierarchyactions:applyToDescendants(obj, { includeRoot = true }, function(l)
					l.Physics = objInfo.Physics or PhysicsMode.StaticPerBlock
					if turnOffShadows then
						l.Shadow = false
					end
				end)
				obj.Position = objInfo.Position or Number3(0, 0, 0)
				obj.Rotation = objInfo.Rotation or Rotation(0, 0, 0)
				obj.Scale = scale
				obj.CollidesWithGroups = Map.CollisionGroups + Player.CollisionGroups
				obj.Name = objInfo.Name or objInfo.fullname
			end
		end
	end

	local ambience = require("ambience")
	ambience:set(ambience.noon)

	controls = require("controls")
	controls:setButtonIcon("action1", "⬆️")

	function dropPlayer(p)
		World:AddChild(p)
		p.Position = SPAWN_IN_BLOCK * map.Scale
		p.Rotation = { 0.06, math.pi * -0.75, 0 }
		p.Velocity = { 0, 0, 0 }
		p.Physics = true
	end

	moveDT = 0.0

	kCameraPositionRotating = Number3(105, 18, 58) * map.Scale
	kCameraPositionY = kCameraPositionRotating.Y

	Camera:SetModeFree()
	Camera.Position = kCameraPositionRotating
	Pointer:Show()

	Menu:OnAuthComplete(function()
		Client.DirectionalPad = directionalPad
		Client.Action1 = action1

		showLocalPlayer()
		print(Player.Username .. " joined!")
	end)

	objectSkills.addStepClimbing(Player)
end

Client.OnPlayerJoin = function(p)
	if p == Player then
		return
	end
	objectSkills.addStepClimbing(p)
	dropPlayer(p)
	print(p.Username .. " joined!")
end

Client.OnPlayerLeave = function(p)
	if p ~= Player then
		objectSkills.removeStepClimbing(p)
	end
end

Client.Tick = function(dt)
	if localPlayerShown then
		if Player.Position.Y < -500 then
			dropPlayer(Player)
		end
	else
		-- Camera movement before player is shown
		moveDT = moveDT + dt * 0.2
		-- keep moveDT between -pi & pi
		while moveDT > math.pi do
			moveDT = moveDT - math.pi * 2
		end
		Camera.Position.Y = kCameraPositionY + (math.sin(moveDT) * 5.0 * MAP_SCALE)

		Camera:RotateWorld({ 0, 0.1 * dt, 0 })
	end
end

Pointer.Click = function()
	Player:SwingRight()
end

localPlayerShown = false
function showLocalPlayer()
	localPlayerShown = true
	Camera:SetModeThirdPerson()
	dropPlayer(Player)
end
