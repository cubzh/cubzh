--[[

Welcome to the cubzh hub script!

Want to create something like this?
Go to https://docs.cu.bzh/

]]
--

-- Dev.DisplayFPS = true
-- Dev.DisplayColliders = true
-- Dev.DisplayBoxes = true

-- CONSTANTS

local MINIMUM_ITEM_SIZE_FOR_SHADOWS = 40
local MINIMUM_ITEM_SIZE_FOR_SHADOWS_SQR = MINIMUM_ITEM_SIZE_FOR_SHADOWS * MINIMUM_ITEM_SIZE_FOR_SHADOWS
local SPAWN_IN_BLOCK = Number3(107, 14, 73)
local TITLE_SCREEN_CAMERA_POSITION_IN_BLOCK = Number3(107, 20, 73)
local ROTATING_CAMERA_MAX_OFFSET_Y_IN_BLOCk = 2.0
local REQUEST_FAIL_RETRY_DELAY = 5.0
local HOLDING_TIME = 0.6 -- time to trigger action when holding button pressed

local JUMP_VELOCITY = 82
local MAX_AIR_JUMP_VELOCITY = 85

-- VARIABLES

local MAP_SCALE = 6.0 -- var because could be overriden when loading map
local DEBUG = true

local globalToast = nil

Client.OnStart = function()
	-- REQUIRE MODULES
	collectible = require("collectible")
	ease = require("ease")
	conf = require("config")
	particles = require("particles")
	walkSFX = require("walk_sfx")
	wingTrail = require("wingtrail")
	sfx = require("sfx")

	multi = require("multi")
	-- not doing it automatically in that script has we need
	-- to deal with special situations, like vehicles
	multi:doNotHandlePlayers()

	bundle = require("bundle")
	require("textbubbles").displayPlayerChatBubbles = true
	objectSkills = require("object_skills")

	-- SET MAP / AMBIANCE
	loadMap()
	setAmbiance()

	addCollectibles()

	-- createDraft((SPAWN_IN_BLOCK + { 0, 2, 0 }) * MAP_SCALE, 50, 50, 200, 600)
	-- createDraft(Number3(107, 36, 0) * MAP_SCALE, 50, 50, 200, 600)

	-- CONTROLS
	-- Disabling controls until user is authenticated
	Client.DirectionalPad = nil
	Client.Action1 = nil
	Client.Action1Release = nil
	Pointer.Drag = nil

	-- set icon for action1 button (for touch screens)
	local controls = require("controls")
	controls:setButtonIcon("action1", "⬆️")

	playerControls:walk(Player)

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
		collidesWithGroups = function()
			return {}
		end,
	})

	collectParticles = particles:newEmitter({
		life = function()
			return 1.0
		end,
		velocity = function()
			local v = Number3(20 + math.random() * 10, 0, 0)
			v:Rotate(0, math.random() * math.pi * 2, 0)
			v.Y = 30 + math.random() * 20
			return v
		end,
		scale = function()
			return 0.5
		end,
		collidesWithGroups = function()
			return {}
		end,
	})

	-- CAMERA
	-- Set camera for pre-authentication state (rotating while title screen is shown)

	cameraDefaultFOV = Camera.FOV
	print(cameraDefaultFOV)

	Camera:SetModeFree()
	Camera.Position = TITLE_SCREEN_CAMERA_POSITION_IN_BLOCK * MAP_SCALE

	Menu:OnAuthComplete(function()
		Client.DirectionalPad = playerControls.directionalPad
		Pointer.Drag = playerControls.pointerDrag
		Client.Action1 = action1
		Client.Action1Release = action1Release

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
	multi:onAction("equipGlider", function(sender)
		sender:EquipBackpack(bundle.Shape("voxels.glider_backpack"))
	end)

	addPlayerAnimations(Player)

	-- called when receiving information for distant object that isn't link
	multi.linkRequest = function(name)
		if stringStartsWith(name, "p_") then
			local playerID = math.floor(tonumber(stringRemovePrefix(name, "p_")))
			local p = Players[playerID]
			if p ~= nil then
				multi:unlink("g_" .. p.ID)

				playerControls:walk(p)

				multi:link(p, "p_" .. p.ID)
				multi:link(p.Head, "ph_" .. p.ID)
				if p.Parent == nil then
					p:SetParent(World)
				end
			end
		elseif stringStartsWith(name, "ph_") then
			-- local playerID = math.floor(tonumber(stringRemovePrefix(name, "ph_")))
			-- local p = Players[playerID]
			-- if p ~= nil then
			-- 	multi:link(p.Head, "ph_" .. p.ID)
			-- end
		elseif stringStartsWith(name, "g_") then -- glider
			local playerID = math.floor(tonumber(stringRemovePrefix(name, "g_")))
			local p = Players[playerID]
			if p ~= nil then
				multi:unlink("p_" .. p.ID)
				multi:unlink("ph_" .. p.ID)

				local glider = playerControls:glide(p)

				multi:link(glider, "g_" .. p.ID)
			end
		end
	end
end

-- update what local player is syncing
function updateSync()
	local p = Player
	local pID = p.ID

	multi:unlink("g_" .. pID)
	multi:unlink("p_" .. pID)
	multi:unlink("ph_" .. pID)

	local vehicle = playerControls.vehicles[pID]
	if vehicle then
		if vehicle.type == "glider" then
			-- sync vehicleRoll child object,
			-- it contains all needed information
			multi:sync(vehicle.roll, "g_" .. pID, {
				-- velocity stored under "v"
				keys = { "Velocity", "Position", "Rotation" },
				triggers = { "LocalRotation", "Velocity" },
			})
		end
	else
		multi:sync(p, "p_" .. pID, {
			keys = { "Motion", "Velocity", "Position", "Rotation.Y" },
			triggers = { "LocalRotation", "Rotation", "Motion", "Position", "Velocity" },
		})
		multi:sync(p.Head, "ph_" .. pID, { keys = { "LocalRotation.X" }, triggers = { "LocalRotation", "Rotation" } })
	end
end

Client.OnPlayerJoin = function(p)
	if p == Player then
		updateSync()
		-- that's it, other things are already initialized for local player
		return
	end

	objectSkills.addStepClimbing(p, { mapScale = MAP_SCALE })
	walkSFX:register(p)
	addPlayerAnimations(p)

	print(p.Username .. " joined!")

	-- inform newcomer that glider has been equipped
	-- TODO: send event to newcomer only
	if equipment == "glider" then
		multi:action("equipGlider")
	end
end

Client.OnPlayerLeave = function(p)
	if p ~= Player then
		playerControls:exitVehicle(p)

		multi:unlink("g_" .. p.ID)
		multi:unlink("ph_" .. p.ID)
		multi:unlink("p_" .. p.ID)

		objectSkills.removeStepClimbing(p)
		objectSkills.removeJump(p)
		walkSFX:unregister(p)
		p:RemoveFromParent()
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
		o.InnerTransparentFaces = false
		o:RefreshModel()
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
					-- print("loaded " .. objInfo.fullname)
					o.Physics = objInfo.Physics or PhysicsMode.StaticPerBlock
					if string.find(objInfo.fullname, "vines") or string.find(objInfo.fullname, "grass") then
						o.Physics = PhysicsMode.Disabled
					end
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
					l.Physics = o.Physics
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

holdTimer = nil

function action1()
	if globalToast then
		globalToast:remove()
		globalToast = nil
	end

	playerControls:walk(Player)

	objectSkills.jump(Player)
	-- Dev:CopyToClipboard("" .. Player.Position.X .. ", " .. Player.Position.Y .. ", " .. Player.Position.Z)

	holdTimer = Timer(HOLDING_TIME, function()
		holdTimer = nil
		if equipment == "" then
			return
		end
		if equipment == "glider" then
			playerControls:glide(Player)
		end
	end)
end

function action1Release()
	if holdTimer ~= nil then
		holdTimer:Cancel()
	end
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
-- collectedJetpackParts = {}

gliderBackpackCollectibles = {}
gliderUnlocked = false

equipment = nil

function unlockGlider()
	gliderUnlocked = true
	for _, backpack in ipairs(gliderBackpackCollectibles) do
		backpack.object.PrivateDrawMode = 0
	end

	require("ui_toast"):create({
		message = "Glider unlocked!",
		center = false,
		iconShape = bundle.Shape("voxels.glider_backpack"),
	})
end

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

		local defaultBackpackConfig = {
			scale = 0.75,
			rotation = Number3.Zero, -- { math.pi / 6, 0, math.pi / 6 },
			position = Number3.Zero,
			itemName = "voxels.glider_backpack",
			onCollisionBegin = function(c)
				-- globalToast = require("ui_toast"):create({
				-- 	message = "Maintain jump key to start gliding!",
				-- 	maxWidth = 200,
				-- 	center = false,
				-- 	iconShape = bundle.Shape("voxels.glider"),
				-- 	duration = -1, -- negative duration means infinite
				-- })

				if gliderUnlocked then
					collectParticles.Position = c.object.Position
					collectParticles:spawn(20)
					sfx("wood_impact_3", { Position = c.object.Position, Volume = 0.6, Pitch = 1.3 })
					Client:HapticFeedback()
					collectible:remove(c)

					Player:EquipBackpack(c.object)

					equipment = "glider"
					multi:action("equipGlider")

					require("ui_toast"):create({
						message = "Maintain jump key to start gliding!",
						center = false,
						iconShape = bundle.Shape("voxels.glider"),
					})
				else
					require("ui_toast"):create({
						message = #collectedGliderParts .. "/" .. #gliderParts .. " collected",
						center = true,
						iconShape = bundle.Shape("voxels.glider_parts"),
					})
				end
			end,
		}

		local gliderBackpackConfigs = {
			{ position = Number3(451, 102, 510) },
		}

		for _, backpackConfig in ipairs(gliderBackpackConfigs) do
			local config = conf:merge(defaultBackpackConfig, backpackConfig)
			local c = collectible:create(config)
			c.object.PrivateDrawMode = 1
			table.insert(gliderBackpackCollectibles, c)
		end

		if #collectedGliderParts >= #gliderParts then -- or true then
			unlockGlider()
		else
			local gliderPartConfig = {
				scale = 0.5,
				rotation = Number3.Zero, -- { math.pi / 6, 0, math.pi / 6 },
				position = Number3.Zero,
				itemName = "voxels.glider_parts",
				userdata = {
					ID = -1,
				},
				onCollisionBegin = function(c)
					collectParticles.Position = c.object.Position
					collectParticles:spawn(20)
					sfx("wood_impact_3", { Position = c.object.Position, Volume = 0.6, Pitch = 1.3 })
					Client:HapticFeedback()

					collectible:remove(c)

					if contains(collectedGliderParts, c.userdata.ID) then
						return
					end

					table.insert(collectedGliderParts, c.userdata.ID)

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
						unlockGlider()
					end

					-- if #collectedGliderParts == 1 then
					-- 	unlockGlider()
					-- end
				end,
			}
			for _, v in ipairs(gliderParts) do
				if not contains(collectedGliderParts, v.ID) then
					local config = conf:merge(gliderPartConfig, { position = v.Position, userdata = { ID = v.ID } })
					collectible:create(config)
				end
			end
		end
	end

	local t = {}
	t.get = function()
		local store = KeyValueStore(Player.UserID)
		-- store:get("collectedGliderParts", "collectedJetpackParts", function(ok, results)
		store:get("collectedGliderParts", function(ok, results)
			if ok then
				if results.collectedGliderParts ~= nil then
					collectedGliderParts = results.collectedGliderParts
				end
				-- if results.collectedJetpackParts ~= nil then
				-- 	collectedJetpackParts = results.collectedJetpackParts
				-- end
				spawnCollectibles()
			else
				Timer(REQUEST_FAIL_RETRY_DELAY, t.get)
			end
		end)
	end
	t.get()
end

playerControls = {
	shapeCache = {},
	vehicles = {}, -- vehicles, indexed by player ID
	current = {}, -- control names, indexed by player ID
	onDrag = nil,
	dirPad = nil,
}

playerControls.pointerDrag = function(pe)
	if playerControls.onDrag ~= nil then
		playerControls.onDrag(pe)
	end
end

playerControls.directionalPad = function(x, y)
	if playerControls.dirPad ~= nil then
		playerControls.dirPad(x, y)
	end
end

playerControls.getShape = function(self, shapeName)
	if self.shapeCache[shapeName] == nil then
		self.shapeCache[shapeName] = bundle.Shape(shapeName)
	end
	return Shape(self.shapeCache[shapeName], { includeChildren = true })
end

playerControls.exitVehicle = function(self, player)
	local vehicle = self.vehicles[player.ID]

	if vehicle == nil then
		return
	end

	if player.Animations.LiftArms then
		player.Animations.LiftArms:Stop()
	end

	vehicle.Tick = nil

	if vehicle.wingTrails then
		for _, t in ipairs(vehicle.wingTrails) do
			wingTrail:remove(t)
		end
		vehicle.wingTrails = nil
	end

	player:SetParent(World, true)
	player.Rotation = { 0, vehicle.Rotation.Y, 0 }
	player.Position = vehicle.Position

	player.Head.LocalRotation = { 0, 0, 0 }
	player.Physics = PhysicsMode.Dynamic
	player.Scale = 0.5
	player.Velocity = Number3.Zero

	if player == Player then
		Camera:SetModeThirdPerson(player)
		Camera.FOV = cameraDefaultFOV
	end

	vehicle:RemoveFromParent()
	self.vehicles[player.ID] = nil
end

playerControls.walk = function(self, player)
	if self.current[player.ID] == "walk" then
		return -- already walking
	end
	self.current[player.ID] = "walk"

	self:exitVehicle(player)

	if player == Player then
		self.onDrag = function(pe)
			Player.LocalRotation = Rotation(0, pe.DX * 0.01, 0) * Player.LocalRotation
			Player.Head.LocalRotation = Rotation(-pe.DY * 0.01, 0, 0) * Player.Head.LocalRotation
			local dpad = require("controls").DirectionalPadValues
			Player.Motion = (Player.Forward * dpad.Y + Player.Right * dpad.X) * 50
		end
		self.dirPad = function(x, y)
			Player.Motion = (Player.Forward * y + Player.Right * x) * 50
		end
		updateSync()
	end
end

local GLIDER_MAX_SPEED_FOR_EFFECTS = 80 -- speed can be above that, but used for visual effects
local GLIDER_MAX_SPEED = 200
local GLIDER_WING_LENGTH = 24
local GLIDER_MAX_START_SPEED = 50
local GLIDER_DRAG_DOWN = Number3(0, -5, 0)

playerControls.glide = function(self, player)
	if self.current[player.ID] == "glide" then
		return -- already gliding
	end
	self.current[player.ID] = "glide"

	self:exitVehicle(player)

	local vehicle = Object()
	vehicle.Scale = 0.5
	vehicle:SetParent(World)
	vehicle.type = "glider"

	self.vehicles[player.ID] = vehicle

	local glider = self:getShape("voxels.glider")
	glider.Physics = PhysicsMode.Disabled

	vehicle.Position = player:PositionLocalToWorld({ 0, player.BoundingBox.Max.Y - 2, 0 })

	glider.Scale = 0
	ease:cancel(glider)
	ease:outElastic(glider, 0.3).Scale = Number3(1, 1, 1)

	if player.Animations.LiftArms then
		player.Animations.LiftArms:Play()
	end

	vehicle.Physics = PhysicsMode.Dynamic
	vehicle.Acceleration = -Config.ConstantAcceleration
	vehicle.Motion:Set(GLIDER_DRAG_DOWN) -- constantly going down

	local rightTrail = wingTrail:create({ scale = 0.5 })
	rightTrail.LocalPosition = { GLIDER_WING_LENGTH, 8, 0 }

	local leftTrail = wingTrail:create({ scale = 0.5 })
	leftTrail.LocalPosition = { -GLIDER_WING_LENGTH, 8, 0 }

	vehicle.wingTrails = {}
	table.insert(vehicle.wingTrails, rightTrail)
	table.insert(vehicle.wingTrails, leftTrail)

	local rightWingTip
	local leftWingTip
	local diffY
	local maxDiff
	local p
	local leftLift
	local rightLift
	local down
	local up
	local speedOverMax
	local f

	vehicle.Rotation:Set(0, player.Rotation.Y, 0)
	vehicle.Velocity = player.Motion + player.Velocity * 0.1 -- initial velocity
	local l = vehicle.Velocity.Length
	vehicle.Velocity.Length = math.min(l, GLIDER_MAX_START_SPEED)

	player.Head.LocalRotation = { 0, 0, 0 }

	player.Motion:Set(0, 0, 0)
	player.Velocity:Set(0, 0, 0)
	player.Physics = PhysicsMode.Disabled
	player.Scale = 1.0

	if player == Player then -- local simulation
		local yaw = Rotation(0, 0, 0)
		local yawDelta = Rotation(0, 0, 0)

		local tilt = Rotation(0, 0, 0)
		local tiltDelta = Rotation(0, 0, 0)

		local roll = Rotation(0, 0, 0)
		local rollDelta = Rotation(0, 0, 1)

		local vehicleRoll = Object()
		vehicleRoll.Velocity = Number3.Zero
		vehicleRoll.Physics = PhysicsMode.Disabled
		vehicleRoll:SetParent(vehicle)
		glider:SetParent(vehicleRoll)
		glider.LocalRotation = { 0, math.rad(180), 0 }

		vehicle.roll = vehicleRoll -- used for sync

		yaw:Set(0, player.Rotation.Y, 0)

		player:SetParent(vehicleRoll, true)
		player.LocalRotation:Set(Number3.Zero)
		player.LocalPosition:Set(0, -27, 0)

		rightTrail:SetParent(vehicleRoll)
		leftTrail:SetParent(vehicleRoll)

		vehicleRoll.Velocity:Set(vehicle.Velocity) -- copying for sync (physics disabled on vehicleRoll)

		vehicle.Tick = function(o, dt)
			rightWingTip = vehicleRoll:PositionLocalToWorld(GLIDER_WING_LENGTH, 0, 0)
			leftWingTip = vehicleRoll:PositionLocalToWorld(-GLIDER_WING_LENGTH, 0, 0)

			diffY = leftWingTip.Y - rightWingTip.Y

			maxDiff = GLIDER_WING_LENGTH * 2
			p = math.abs(diffY / maxDiff)

			if diffY < 0 then
				leftLift = 0.5 + p * 0.5
				rightLift = 1.0 - leftLift
			else
				rightLift = 0.5 + p * 0.5
				leftLift = 1.0 - rightLift
			end

			l = o.Velocity.Length

			yawDelta.Y = diffY * dt * 0.001 * 70
			yaw = yawDelta * yaw

			o.Rotation = yaw * tilt

			down = math.max(0, o.Forward:Dot(Number3.Down)) -- 0 -> 1
			up = math.max(0, o.Forward:Dot(Number3.Up))

			-- accelerate when facing down / lose more velocity when going up
			l = l + down * 50.0 * dt - (8.0 + up * 8.0) * dt

			l = math.max(l, 0) -- speed can't be below 0
			l = math.min(l, GLIDER_MAX_SPEED) -- can't go faster than GLIDER_MAX_SPEED

			o.Velocity:Set(o.Forward * l)
			vehicleRoll.Velocity:Set(o.Velocity) -- copying for sync (physics disabled on vehicleRoll)

			-- EFFECTS
			speedOverMax = math.min(1.0, l / GLIDER_MAX_SPEED_FOR_EFFECTS)
			Camera.FOV = cameraDefaultFOV + 20 * speedOverMax

			f = 0.2 * speedOverMax
			rightTrail:setColor(Color(255, 255, 255, rightLift * f))
			leftTrail:setColor(Color(255, 255, 255, leftLift * f))
		end

		require("camera_modes"):setThirdPerson({ target = vehicle, rotationOffset = Rotation(math.rad(20), 0, 0) })

		self.onDrag = function(pe)
			rollDelta.Z = -pe.DX * 0.01
			tiltDelta.X = -pe.DY * 0.01

			roll = rollDelta * roll
			tilt = tiltDelta * tilt

			vehicle.Rotation = yaw * tilt
			vehicleRoll.LocalRotation = roll -- triggers sync
		end
		self.dirPad = function(_, _)
			-- nothing to do, just turning off walk controls
		end
		updateSync()
	else -- distant player
		glider:SetParent(vehicle)
		glider.LocalRotation = { 0, math.rad(180), 0 }

		player:SetParent(vehicle, true)
		player.LocalRotation:Set(Number3.Zero)
		player.LocalPosition:Set(0, -27, 0)

		rightTrail:SetParent(vehicle)
		leftTrail:SetParent(vehicle)

		vehicle.Tick = function(o, dt)
			rightWingTip = vehicle:PositionLocalToWorld(GLIDER_WING_LENGTH, 0, 0)
			leftWingTip = vehicle:PositionLocalToWorld(-GLIDER_WING_LENGTH, 0, 0)

			diffY = leftWingTip.Y - rightWingTip.Y

			maxDiff = GLIDER_WING_LENGTH * 2
			p = math.abs(diffY / maxDiff)

			if diffY < 0 then
				leftLift = 0.5 + p * 0.5
				rightLift = 1.0 - leftLift
			else
				rightLift = 0.5 + p * 0.5
				leftLift = 1.0 - rightLift
			end

			l = o.Velocity.Length

			down = math.max(0, vehicle.Forward:Dot(Number3.Down)) -- 0 -> 1
			up = math.max(0, vehicle.Forward:Dot(Number3.Up))

			-- accelerate when facing down / lose more velocity when going up
			l = l + down * 50.0 * dt - (8.0 + up * 8.0) * dt

			l = math.max(l, 0) -- speed can't be below 0
			l = math.min(l, GLIDER_MAX_SPEED) -- can't go faster than GLIDER_MAX_SPEED

			vehicle.Velocity:Set(o.Forward * l)

			-- EFFECTS
			speedOverMax = math.min(1.0, l / GLIDER_MAX_SPEED_FOR_EFFECTS)
			Camera.FOV = cameraDefaultFOV + 20 * speedOverMax

			f = 0.2 * speedOverMax
			rightTrail:setColor(Color(255, 255, 255, rightLift * f))
			leftTrail:setColor(Color(255, 255, 255, leftLift * f))
		end
	end

	return vehicle
end

function createDraft(pos, width, depth, height, strength)
	local o = Object()
	o:SetParent(World)
	o.Physics = PhysicsMode.Trigger
	o.CollisionGroups = { 4 }

	o.emitter = particles:newEmitter({
		life = function()
			return 0.6
		end,
		position = function()
			return Number3(math.random(0, width), 0, math.random(0, depth))
		end,
		color = function()
			return Color(255, 255, 255, 80)
		end,
		physics = function()
			return true
		end,
		velocity = function()
			return Number3(0, math.random(300, 400), 0)
		end,
		collidesWithGroups = function()
			return {}
		end,
	})

	o.emitter:SetParent(o)

	o.as = AudioSource("wind_wind_child_1")
	o.as:SetParent(o)
	o.as.Volume = 0.8
	o.as.Pitch = 1.2
	o.as.Loop = true

	o.Tick = function(self, _)
		self.emitter:spawn(1)
	end

	o.LocalPosition = pos
	o.CollisionBox = Box({ 0, 0, 0 }, { width, height, depth })
	o.CollidesWithGroups = Player.CollisionGroups

	-- o.OnCollisionBegin = function(self, other)
	-- 	if other == Player and Player.isUsingGlider then
	-- 		self.as:Play()
	-- 	end
	-- end

	-- o.OnCollision = function(self, other)
	-- 	if other == Player and Player.isUsingGlider then
	-- 		Player.draftVelocity = strength
	-- 	end
	-- end

	-- o.OnCollisionEnd = function(self, other)
	-- 	if other == Player then
	-- 		Player.draftVelocity = 0
	-- 		Timer(1, function()
	-- 			self.as:Stop()
	-- 		end)
	-- 	end
	-- end

	return o
end

-- UTILS

function stringStartsWith(str, prefix)
	return string.sub(str, 1, string.len(prefix)) == prefix
end

function stringRemovePrefix(str, prefix)
	if string.sub(str, 1, string.len(prefix)) == prefix then
		return string.sub(str, string.len(prefix) + 1)
	else
		return str
	end
end

function addPlayerAnimations(player)
	local animLiftArms = Animation("LiftArms", { speed = 5, loops = 1, removeWhenDone = false, priority = 255 })
	local liftRightArm = {
		{ time = 0.0, rotation = { 0, 0, -1.0472 } },
		{ time = 1.0, rotation = { 0, 0, math.rad(30) } },
	}
	local liftRightHand = {
		{ time = 0.0, rotation = { 0, -0.392699, 0 } },
		{ time = 1.0, rotation = { math.rad(-180), 0, math.rad(-30) } },
	}
	local liftLeftArm = {
		{ time = 0.0, rotation = { 0, 0, 1.0472 } },
		{ time = 1.0, rotation = { 0, 0, math.rad(-30) } },
	}
	local liftLeftHand = {
		{ time = 0.0, rotation = { 0, -0.392699, 0 } },
		{ time = 1.0, rotation = { math.rad(-180), 0, math.rad(30) } },
	}
	local animLiftRightConfig = {
		RightArm = liftRightArm,
		RightHand = liftRightHand,
		LeftArm = liftLeftArm,
		LeftHand = liftLeftHand,
	}
	for name, v in pairs(animLiftRightConfig) do
		for _, frame in ipairs(v) do
			animLiftArms:AddFrameInGroup(name, frame.time, { position = frame.position, rotation = frame.rotation })
			animLiftArms:Bind(
				name,
				(name == "Body" and not player.Avatar[name]) and player.Avatar or player.Avatar[name]
			)
		end
	end
	player.Animations.LiftArms = animLiftArms
end
