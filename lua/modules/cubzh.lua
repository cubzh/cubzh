--[[

Welcome to the cubzh hub script!

Want to create something like this?
Go to https://docs.cu.bzh/

]]
--

Config = {
	Items = {},
}

-- local WATER_ALPHA = 220
local MAP_SCALE = 5.5

directionalPad = Client.DirectionalPad
action1 = function()
	if Player.IsOnGround then
		Player.Velocity.Y = 100
	end
end

Client.DirectionalPad = nil
Client.Action1 = nil

Client.Action2 = function() end

Client.OnStart = function()
	multi = require("multi")
	require("textbubbles").displayPlayerChatBubbles = true

	local ambience = require("ambience")
	ambience:set(ambience.noon)

	controls = require("controls")
	controls:setButtonIcon("action1", "⬆️")

	-- IMPORT MODULES
	bundle = require("bundle")
	ui = require("uikit")
	objectSkills = require("object_skills")

	-- MAP

	function setChunkPos(chunk, x, y, z)
		chunk.Position = Number3(x, y, z) * MAP_SCALE
	end

	function setWaterTransparency(_) -- chunk
		-- local i = chunk.Palette:GetIndex(Color(48, 192, 204, 255))
		-- if i ~= nil then
		-- 	chunk.Palette[i].Color.A = WATER_ALPHA
		-- end
		-- i = chunk.Palette:GetIndex(Color(252, 252, 252, 255))
		-- if i ~= nil then
		-- 	chunk.Palette[i].Color.A = WATER_ALPHA
		-- end
	end

	function setLights(_) -- chunk
		-- local i = chunk.Palette:GetIndex(Color(252, 240, 176, 255))
		-- if i ~= nil then
		-- 	chunk.Palette[i].Color.A = 230
		-- 	chunk.Palette[i].Light = true
		-- end
	end

	collosseumChunk = bundle.Shape("hub_collosseum_chunk")
	collosseumChunk.InnerTransparentFaces = false
	collosseumChunk.Physics = PhysicsMode.StaticPerBlock
	collosseumChunk.CollisionGroups = Map.CollisionGroups
	collosseumChunk.Scale = MAP_SCALE
	collosseumChunk.Pivot = { 0, 0, 0 }
	collosseumChunk.Friction = Map.Friction
	collosseumChunk.Bounciness = Map.Bounciness
	World:AddChild(collosseumChunk)
	collosseumChunk.Position = { 0, 0, 0 }
	setWaterTransparency(collosseumChunk)
	setLights(collosseumChunk)

	scifiChunk = bundle.Shape("hub_scifi_chunk")
	scifiChunk.InnerTransparentFaces = false
	scifiChunk.Physics = PhysicsMode.StaticPerBlock
	scifiChunk.CollisionGroups = Map.CollisionGroups
	scifiChunk.Scale = MAP_SCALE
	scifiChunk.Pivot = { 0, 0, 0 }
	scifiChunk.Friction = Map.Friction
	scifiChunk.Bounciness = Map.Bounciness
	World:AddChild(scifiChunk)
	setChunkPos(scifiChunk, 8, 20, -100)
	setWaterTransparency(scifiChunk)
	setLights(scifiChunk)

	medievalChunk = bundle.Shape("hub_medieval_chunk")
	medievalChunk.InnerTransparentFaces = false
	medievalChunk.Physics = PhysicsMode.StaticPerBlock
	medievalChunk.CollisionGroups = Map.CollisionGroups
	medievalChunk.Scale = MAP_SCALE
	medievalChunk.Pivot = { 0, 0, 0 }
	medievalChunk.Friction = Map.Friction
	medievalChunk.Bounciness = Map.Bounciness
	World:AddChild(medievalChunk)
	setChunkPos(medievalChunk, -10, -6, 92)
	setWaterTransparency(medievalChunk)
	setLights(medievalChunk)

	floatingIslandsChunks = bundle.Shape("hub_floating_islands_chunk")
	floatingIslandsChunks.InnerTransparentFaces = false
	floatingIslandsChunks.Physics = PhysicsMode.StaticPerBlock
	floatingIslandsChunks.CollisionGroups = Map.CollisionGroups
	floatingIslandsChunks.Scale = MAP_SCALE
	floatingIslandsChunks.Pivot = { 0, 0, 0 }
	floatingIslandsChunks.Friction = Map.Friction
	floatingIslandsChunks.Bounciness = Map.Bounciness
	World:AddChild(floatingIslandsChunks)
	setChunkPos(floatingIslandsChunks, 141, -4, 0)
	setWaterTransparency(floatingIslandsChunks)
	setLights(floatingIslandsChunks)

	volcanoChunk = bundle.Shape("hub_volcano_chunk")
	volcanoChunk.Physics = PhysicsMode.StaticPerBlock
	volcanoChunk.CollisionGroups = Map.CollisionGroups
	volcanoChunk.Scale = MAP_SCALE
	volcanoChunk.Pivot = { 0, 0, 0 }
	volcanoChunk.Friction = Map.Friction
	volcanoChunk.Bounciness = Map.Bounciness
	World:AddChild(volcanoChunk)
	volcanoChunk.Position = { 800, 18, -500 }
	setChunkPos(volcanoChunk, 116, 13, -76)
	setWaterTransparency(volcanoChunk)
	setLights(volcanoChunk)

	function dropPlayer(p)
		World:AddChild(p)
		p.Position = Number3(139, 75, 68) * MAP_SCALE
		p.Rotation = { 0.06, math.pi * -0.75, 0 }
		p.Velocity = { 0, 0, 0 }
		p.Physics = true
	end

	moveDT = 0.0
	kCameraPositionY = 90

	kCameraPositionRotating = Number3(139, kCameraPositionY, 68) * MAP_SCALE

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
		Camera.Position.Y = (kCameraPositionY + math.sin(moveDT) * 5.0) * MAP_SCALE

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
