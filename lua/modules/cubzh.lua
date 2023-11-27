--[[

Welcome to the cubzh hub script!

Want to create something like this?
Go to https://docs.cu.bzh/

]]
--

-- Dev.DisplayFPS = true

-- CONSTANTS

local MINIMUM_ITEM_SIZE_FOR_SHADOWS = 40
local MINIMUM_ITEM_SIZE_FOR_SHADOWS_SQR = MINIMUM_ITEM_SIZE_FOR_SHADOWS * MINIMUM_ITEM_SIZE_FOR_SHADOWS
local SPAWN_IN_BLOCK = Number3(107, 14, 73)
local TITLE_SCREEN_CAMERA_POSITION_IN_BLOCK = Number3(107, 20, 73)
local ROTATING_CAMERA_MAX_OFFSET_Y_IN_BLOCk = 2.0
local REQUEST_FAIL_RETRY_DELAY = 5.0

local JUMP_VELOCITY = 82
local MAX_AIR_JUMP_VELOCITY = 85

-- VARIABLES

local MAP_SCALE = 6.0 -- var because could be overriden when loading map
local DEBUG = true

Client.OnStart = function()
	-- REQUIRE MODULES
	conf = require("config")
	particles = require("particles")
	walkSFX = require("walk_sfx")
	sfx = require("sfx")
	multi = require("multi")
	require("textbubbles").displayPlayerChatBubbles = true
	objectSkills = require("object_skills")

	-- SET MAP / AMBIANCE
	loadMap()
	setAmbiance()

	addCollectibles()

	-- CONTROLS
	-- Disabling controls until user is authenticated
	directionalPad = Client.DirectionalPad -- default dir pad function backup
	Client.DirectionalPad = nil
	Client.Action1 = nil

	-- set icon for action1 button (for touch screens)
	local controls = require("controls")
	controls:setButtonIcon("action1", "⬆️")

	-- PARTICLES
	jumpParticles = particles:newEmitter({
		life = function()
			return 0.3
		end,
		velocity = function()
			local v = Number3(15 + math.random() * 10, 0, 0)
			v:Rotate(0, math.random() * math.pi * 2, 0)
			return v
		end,
		acceleration = function()
			return -Config.ConstantAcceleration
		end,
	})

	-- CAMERA
	-- Set camera for pre-authentication state (rotating while title screen is shown)
	Camera:SetModeFree()
	Camera.Position = TITLE_SCREEN_CAMERA_POSITION_IN_BLOCK * MAP_SCALE

	Menu:OnAuthComplete(function()
		Client.DirectionalPad = directionalPad
		Client.Action1 = jump

		showLocalPlayer()
		print(Player.Username .. " joined!")
	end)

	-- LOCAL PLAYER PROPERTIES

	local spawnJumpParticles = function(o)
		jumpParticles.Position = o.Position
		jumpParticles:spawn(10)
		sfx("walk_concrete_2", { Position = o.Position, Volume = 0.2 })
	end

	objectSkills.addStepClimbing(Player, { mapScale = MAP_SCALE })
	objectSkills.addJump(Player, {
		maxGroundDistance = 1.0,
		airJumps = 1,
		jumpVelocity = JUMP_VELOCITY,
		maxAirJumpVelocity = MAX_AIR_JUMP_VELOCITY,
		onJump = spawnJumpParticles,
		onAirJump = spawnJumpParticles,
	})
	walkSFX:register(Player)

	-- SYNCED ACTIONS
	multi:onAction("swingRight", function(sender)
		sender:SwingRight()
	end)
end

Client.OnPlayerJoin = function(p)
	if p == Player then
		return
	end

	objectSkills.addStepClimbing(p, { mapScale = MAP_SCALE })
	walkSFX:register(p)
	dropPlayer(p)
	print(p.Username .. " joined!")
end

Client.OnPlayerLeave = function(p)
	if p ~= Player then
		objectSkills.removeStepClimbing(p)
		objectSkills.removeJump(p)
		walkSFX:unregister(p)
	end
end

local moveDT = 0.0
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
		Camera.Position.Y = (
			TITLE_SCREEN_CAMERA_POSITION_IN_BLOCK.Y + math.sin(moveDT) * ROTATING_CAMERA_MAX_OFFSET_Y_IN_BLOCk
		) * MAP_SCALE
		Camera:RotateWorld({ 0, 0.1 * dt, 0 })
	end
end

Pointer.Click = function()
	Player:SwingRight()
	multi:action("swingRight")
end

localPlayerShown = false
function showLocalPlayer()
	if localPlayerShown then
		return
	end
	localPlayerShown = true

	dropPlayer(Player)
	Player.Position = Camera.Position
	Player.Rotation = Camera.Rotation
	Camera:SetModeThirdPerson()
end

-- UTILITY FUNCTIONS

function setAmbiance()
	local ambience = require("ambience")
	ambience:set(ambience.noon)

	Fog.Near = 300
	Fog.Far = 1000
end

function loadMap()
	local hierarchyactions = require("hierarchyactions")
	local bundle = require("bundle")
	local worldEditorCommon = require("world_editor_common")

	local mapdata = bundle.Data("misc/hubmap.b64")

	local world = worldEditorCommon.deserializeWorld(mapdata:ToString())

	MAP_SCALE = world.mapScale or 5

	map = bundle.Shape(world.mapName)
	map.Scale = MAP_SCALE

	map.CollisionGroups = Map.CollisionGroups
	map.CollidesWithGroups = Map.CollidesWithGroups
	map.Physics = PhysicsMode.StaticPerBlock

	hierarchyactions:applyToDescendants(map, { includeRoot = false }, function(o)
		-- apparently, children == water so far in this map
		o.CollisionGroups = {}
		o.CollidesWithGroups = {}
		o.Physics = PhysicsMode.Disabled
	end)

	map:SetParent(World)
	map.Position = { 0, 0, 0 }
	map.Pivot = { 0, 0, 0 }
	map.Shadow = true

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
					-- print("could not load " .. objInfo.fullname)
				end
			end
		end
	end

	local obj
	local scale
	local boxSize
	local turnOnShadows
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
				turnOnShadows = false

				if boxSize.SquaredLength >= MINIMUM_ITEM_SIZE_FOR_SHADOWS_SQR then
					turnOnShadows = true
				end

				obj.Pivot = Number3(obj.Width / 2, k.Min.Y + obj.Pivot.Y, obj.Depth / 2)
				hierarchyactions:applyToDescendants(obj, { includeRoot = true }, function(l)
					l.Physics = objInfo.Physics or PhysicsMode.StaticPerBlock
					if turnOnShadows then
						l.Shadow = true
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
end

function jump()
	objectSkills.jump(Player)
end

function dropPlayer(p)
	World:AddChild(p)
	p.Position = SPAWN_IN_BLOCK * map.Scale
	p.Rotation = { 0.06, math.pi * -0.75, 0 }
	p.Velocity = { 0, 0, 0 }
	p.Physics = true
end

function contains(t, v)
	for _, value in ipairs(t) do
		if value == v then
			return true
		end
	end
	return false
end

-- collected part IDs (arrays)
collectedGliderParts = {} -- {1, 3, 5}
collectedJetpackParts = {}

function addCollectibles()
	local function spawnCollectibles()
		-- local jetpackPartsPositions = {
		-- 	Number3(850, 96, 350),
		-- 	Number3(810, 96, 350),
		-- 	Number3(770, 96, 350),
		-- }

		local gliderParts = {
			{ ID = 1, Position = Number3(418, 128, 566) },
			{ ID = 2, Position = Number3(387, 242, 625) },
			{ ID = 3, Position = Number3(62, 248, 470) },
			{ ID = 4, Position = Number3(336, 260, 403) },
			{ ID = 5, Position = Number3(194, 230, 202) },
			{ ID = 6, Position = Number3(363, 212, 149) },
			{ ID = 7, Position = Number3(155, 266, 673) },
			{ ID = 8, Position = Number3(100, 350, 523) },
			{ ID = 9, Position = Number3(240, 404, 249) },
			{ ID = 10, Position = Number3(453, 472, 156) },
		}

		if #collectedGliderParts >= #gliderParts then
			-- baseControls.enableGlider(Player, true)
			print("GLIDER AVAILABLE!")
		else
			local gliderPartConfig = {
				scale = 0.2,
				rotation = { math.pi / 6, 0, math.pi / 6 },
				position = Number3.Zero,
				ID = -1,
				callback = function(o)
					if contains(collectedGliderParts, o.collectibleID) then
						return
					end

					table.insert(collectedGliderParts, o.collectibleID)

					local retry = {}
					retry.fn = function()
						local store = KeyValueStore(Player.UserID)
						store:set("collectedGliderParts", collectedGliderParts, function(ok)
							if not ok then
								Timer(REQUEST_FAIL_RETRY_DELAY, retry.fn)
							end
						end)
					end
					retry.fn()

					if DEBUG then
						print("Glider parts collected: " .. #collectedGliderParts .. "/" .. #gliderParts)
					end

					if #collectedGliderParts >= #gliderParts then
						print("GLIDER AVAILABLE!")
						-- 	baseControls.enableGlider(Player, true)
						-- 	baseControls.selectBackpack(Player, "glider")
						-- 	if printDebug then
						-- 		print("Glider Unlocked!")
						-- 	end
					end
				end,
			}
			for _, v in ipairs(gliderParts) do
				if not contains(collectedGliderParts, v.ID) then
					local config = conf:merge(gliderPartConfig, { position = v.Position, ID = v.ID })
					collectible:create("voxels.hang_glider", config)
				end
			end
		end
	end

	local t = {}
	t.get = function()
		local store = KeyValueStore(Player.UserID)
		store:get("collectedGliderParts", "collectedJetpackParts", function(ok, results)
			if ok then
				if results.collectedGliderParts ~= nil then
					collectedGliderParts = results.collectedGliderParts
				end
				if results.collectedJetpackParts ~= nil then
					collectedJetpackParts = results.collectedJetpackParts
				end
				spawnCollectibles()
			else
				Timer(REQUEST_FAIL_RETRY_DELAY, t.get)
			end
		end)
	end
	t.get()
end

-- COLLECTIBLES

collectible = {
	pool = {},
	tickListener = nil,
	toggleTick = function(self)
		if #self.pool > 0 and self.tickListener == nil then
			local pool = self.pool
			self.tickListener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
				for _, c in ipairs(pool) do
					c:RotateLocal(0, dt, 0)
				end
			end)
		elseif #self.pool == 0 and self.tickListener ~= nil then
			self.tickListener:Remove()
			self.tickListener = nil
		end
	end,
}

collectible.onCollision = function(self, other)
	if other ~= Player then
		return
	end

	if self.callback ~= nil then
		self:callback()
	end

	-- self.emitter:spawn(20)
	self:RemoveFromParent()

	-- remove from pool
	local index = nil
	for i, v in ipairs(collectible.pool) do
		if v == self then
			index = i
			break
		end
	end

	if index ~= nil then
		table.remove(collectible.pool, index)
	end

	collectible:toggleTick()
end

collectible.create = function(self, itemName, config)
	local bundle = require("bundle")
	local hierarchyactions = require("hierarchyactions")

	local s = bundle.Shape(itemName)
	s:SetParent(World)

	hierarchyactions:applyToDescendants(s, { includeRoot = true }, function(o)
		o.Physics = PhysicsMode.Trigger
		-- o.IsUnlit = true
		o.PrivateDrawMode = 2
	end)

	s.collectibleID = config.ID

	s.Pivot = { s.Width * 0.5, 0, s.Depth * 0.5 }

	s.Scale = config.scale
	s.Position = config.position
	s.Rotation = config.rotation
	s.callback = config.callback

	s.OnCollisionBegin = self.onCollision

	table.insert(self.pool, s)
	self:toggleTick()
	return s
end
