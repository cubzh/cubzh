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
local ROTATING_CAMERA_MAX_OFFSET_Y_IN_BLOCK = 2.0
local REQUEST_FAIL_RETRY_DELAY = 5.0
local HOLDING_TIME = 0.6 -- time to trigger action when holding button pressed

local JUMP_VELOCITY = 82
local MAX_AIR_JUMP_VELOCITY = 85
local DRAFT_COLLISION_GROUPS = { 7 }

local GLIDER_BACKPACK = {
	SCALE = 0.75,
	ITEM_NAME = "voxels.glider_backpack",
}

-- VARIABLES

local MAP_SCALE = 6.0 -- var because could be overriden when loading map

-- Toasts
local globalToast = nil
local backpackTransparentToast = nil

propellers = {}
fireflies = {}
friendIcons = {}

Client.OnStart = function()
	-- REQUIRE MODULES
	collectible = require("collectible")
	ease = require("ease")
	conf = require("config")
	particles = require("particles")
	walkSFX = require("walk_sfx")
	wingTrail = require("wingtrail")
	avatar = require("avatar")
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

	createDraft({ 674, 57, 846 }, 32, 32, 100, 4000)

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
		color = function()
			return Color.White
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
		color = function()
			return Color.White
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

	Camera:SetModeFree()
	Camera.Position = TITLE_SCREEN_CAMERA_POSITION_IN_BLOCK * MAP_SCALE

	Menu:OnAuthComplete(function()
		Client.DirectionalPad = playerControls.directionalPad
		Pointer.Drag = playerControls.pointerDrag
		Client.Action1 = action1
		Client.Action1Release = action1Release

		showLocalPlayer()

		addCollectibles()

		print(Player.Username .. " joined!")
	end)

	-- LOCAL PLAYER PROPERTIES

	local spawnJumpParticles = function(o)
		jumpParticles.Position = o.Position
		jumpParticles:spawn(10)
		sfx("walk_concrete_2", { Position = o.Position, Volume = 0.2 })
	end

	objectSkills.addStepClimbing(Player, { mapScale = MAP_SCALE, collisionGroups = Map.CollisionGroups })
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
		local s = bundle.Shape(GLIDER_BACKPACK.ITEM_NAME)
		s.Scale = GLIDER_BACKPACK.SCALE
		sender:EquipBackpack(s)
	end)

	addPlayerAnimations(Player)
	-- setTriggerPlates()

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

	if Client.Connected then
		local playerControlID = playerControls:getPlayerID(p)
		local vehicle = playerControls.vehicles[playerControlID]
		if vehicle then
			if vehicle.type == "glider" then
				-- sync vehicleRoll child object,
				-- it contains all needed information
				multi:sync(vehicle.roll, "g_" .. pID, {
					keys = { "Velocity", "Position", "Rotation" },
					triggers = { "LocalRotation", "Velocity" },
				})
			end
		else
			multi:sync(p, "p_" .. pID, {
				keys = { "Motion", "Velocity", "Position", "Rotation.Y" },
				triggers = { "LocalRotation", "Rotation", "Motion", "Position", "Velocity" },
			})
			multi:sync(
				p.Head,
				"ph_" .. pID,
				{ keys = { "LocalRotation.X" }, triggers = { "LocalRotation", "Rotation" } }
			)
		end
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
	multi:unlink("g_" .. p.ID)
	multi:unlink("ph_" .. p.ID)
	multi:unlink("p_" .. p.ID)

	if p ~= Player then
		print(p.Username .. " just left!")
		playerControls:exitVehicle(p)
		objectSkills.removeStepClimbing(p)
		objectSkills.removeJump(p)
		walkSFX:unregister(p)
		p:RemoveFromParent()
	end
end

local moveDT = 0.0
local tickT = 0.0
local yPos
local ySlowRotation = Object()
local yFastRotation = Object()
Client.Tick = function(dt)
	tickT = tickT + dt
	ySlowRotation:RotateLocal(0, dt, 0)
	yFastRotation:RotateLocal(0, dt * 5, 0)

	if localPlayerShown then
		-- Detect if player is under the map and respawn it
		if Player.Position.Y < -500 then
			dropPlayer(Player)
		end
	else -- local player not shown yet
		-- Camera movement before player is shown
		moveDT = moveDT + dt * 0.2
		-- keep moveDT between -pi & pi
		while moveDT > math.pi do
			moveDT = moveDT - math.pi * 2
		end
		Camera.Position.Y = (
			TITLE_SCREEN_CAMERA_POSITION_IN_BLOCK.Y + math.sin(moveDT) * ROTATING_CAMERA_MAX_OFFSET_Y_IN_BLOCK
		) * MAP_SCALE.Y
		Camera:RotateWorld({ 0, 0.1 * dt, 0 })
	end

	for _, propeller in ipairs(propellers) do
		propeller.LocalRotation:Set(yFastRotation.LocalRotation)
	end

	for _, firefly in ipairs(fireflies) do
		firefly.timer = firefly.timer + dt * firefly.animation_speed
		firefly.LocalPosition.Y = firefly.initialPosY + math.sin(firefly.timer) * firefly.range
	end

	yPos = math.sin(tickT)
	for _, friendIcon in ipairs(friendIcons) do
		friendIcon.LocalPosition.Y = yPos + friendIcon.initialY
		friendIcon.LocalRotation:Set(ySlowRotation.LocalRotation)
	end
end

Pointer.Click = function(_) -- pe
	Player:SwingRight()
	multi:action("swingRight")

	-- local impact = pe:CastRay()
	-- if impact ~= nil then
	-- 	if impact.Object.ItemName ~= nil then
	-- 		if string.find(impact.Object.ItemName, "door_scifi") then
	-- 			doorCallback(doorJetpack, true)
	-- 			doorCallback(doorNerf, true)
	-- 		end
	-- 		Dev:CopyToClipboard(impact.Object.ItemName)
	-- 		print(impact.Object.ItemName, impact.Object.CollisionGroups)
	-- 	end
	-- end

	-- resetKVS()
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

local hierarchyactions = require("hierarchyactions")
Client.OnWorldObjectLoad = function(obj)
	if string.find(obj.fullname, "vines")
		or string.find(obj.fullname, "grass")
		or string.find(obj.fullname, "rail")
		or string.find(obj.fullname, "lily")
		or string.find(obj.fullname, "cubzh_logo")
		or string.find(obj.fullname, "stool")
		or string.find(obj.fullname, "glider")
		or string.find(obj.fullname, "paint")
		or string.find(obj.fullname, "toolbox")
		or string.find(obj.fullname, "cutout_frame")
		or string.find(obj.fullname, "ducky")
		or string.find(obj.fullname, "arrow_up")
		or string.find(obj.fullname, "moss")
		or string.find(obj.fullname, "traffic_barricade")
		or string.find(obj.fullname, "candle")
		or string.find(obj.fullname, "open_letter")
		or string.find(obj.fullname, "leaf_pile")
		or string.find(obj.fullname, "leaf_blower")
		or string.find(obj.fullname, "stop_sign")
		or string.find(obj.fullname, "wood_steps")
		or string.find(obj.fullname, "cubzh_coin")
		or string.find(obj.fullname, "shelf")
		or string.find(obj.fullname, "backpack")
		or string.find(obj.fullname, "gramophone")
		or string.find(obj.fullname, "green_2")
		or string.find(obj.fullname, "indicator_light")
		or string.find(obj.fullname, "spaceship")
		or string.find(obj.fullname, "jetpack")
		or string.find(obj.fullname, "wall_countdown")
		or string.find(obj.fullname, "bush")
		or string.find(obj.fullname, "cactus")
		or string.find(obj.fullname, "telephone_pole")
		or string.find(obj.fullname, "campfire")
		or string.find(obj.fullname, "tavern_mug")
		or string.find(obj.fullname, "fishing_rod")
		or string.find(obj.fullname, "tumbleweed")
		or string.find(obj.fullname, "sun_hat")
		or string.find(obj.fullname, "pistol")
		or string.find(obj.fullname, "nerf_ammo")
	then
		hierarchyactions:applyToDescendants(obj, { includeRoot = true }, function(o)
			o.Physics = PhysicsMode.Disabled
		end)
	elseif
		string.find(obj.fullname, "stone_pedestal")
		or string.find(obj.fullname, "clothes_rack")
		or string.find(obj.fullname, "globe")
		or string.find(obj.fullname, "drafting_table")
		or string.find(obj.fullname, "easel")
		or string.find(obj.fullname, "blank_canvas")
		-- or string.find(obj.fullname, "floor_propeller")
		or string.find(obj.fullname, "broken_bridge_side_1")
		or string.find(obj.fullname, "broken_bridge_side_2")
		or string.find(obj.fullname, "bouncing_mushroom_3")
		or string.find(obj.fullname, "fence")
		or string.find(obj.fullname, "signboard")
		or string.find(obj.fullname, "crate")
		or string.find(obj.fullname, "tree_trunk")
		or string.find(obj.fullname, "concrete_barrier")
		or string.find(obj.fullname, "lantern")
		or string.find(obj.fullname, "apple") -- apple and apple_tree
		or string.find(obj.fullname, "barrel")
		or string.find(obj.fullname, "lc_pipe_corner")
		or string.find(obj.fullname, "shrine")
		or string.find(obj.fullname, "wood_table")
		or string.find(obj.fullname, "street_barrier")
		or string.find(obj.fullname, "tree_leaves")
		or string.find(obj.fullname, "pink_treetop_1")
		or string.find(obj.fullname, "pink_treetop_2")
		or string.find(obj.fullname, "orange_treetop_2")
		or string.find(obj.fullname, "orange_treetop_1")
		or string.find(obj.fullname, "tree_leaves")
		or string.find(obj.fullname, "log_pile")
		or string.find(obj.fullname, "stone")
		or string.find(obj.fullname, "blackboard")
		or string.find(obj.fullname, "arcade_cabinet")
		or string.find(obj.fullname, "dustzh_arcade")
		or string.find(obj.fullname, "money_bag")
		or string.find(obj.fullname, "vending_machine")
		or string.find(obj.fullname, "capsule_toy_machine")
		or string.find(obj.fullname, "locker")
		or string.find(obj.fullname, "snake_plant")
		or string.find(obj.fullname, "couch")
		or string.find(obj.fullname, "table")
		-- or string.find(obj.fullname, "interaction_button")
		or string.find(obj.fullname, "carpet")
		or string.find(obj.fullname, "palm_tree")
		or string.find(obj.fullname, "bamboo")
		or string.find(obj.fullname, "rock")
		or string.find(obj.fullname, "chest")
		or string.find(obj.fullname, "shovel")
		or string.find(obj.fullname, "car")
		or string.find(obj.fullname, "dumpster")
		or string.find(obj.fullname, "engine_lift")
		or string.find(obj.fullname, "beach_chair")
		or string.find(obj.fullname, "beach_umbrella")
		or string.find(obj.fullname, "baseball_bat")
		or string.find(obj.fullname, "beach_ball")
		or string.find(obj.fullname, "skateboard")
		or string.find(obj.fullname, "tire_swing")
		or string.find(obj.fullname, "small_rope_bridge")
		or string.find(obj.fullname, "pug")
		or string.find(obj.fullname, "floor_countdown")
		-- or string.find(obj.fullname, "door_scifi")
	then
		hierarchyactions:applyToDescendants(obj, { includeRoot = true }, function(o)
			o.Physics = PhysicsMode.Disabled
		end)
		obj.Physics = PhysicsMode.Static
	end

	if obj.fullname == "cta_addfriends"
		or obj.fullname == "cta_exploreworlds"
		or obj.fullname == "cta_createitems" then
		obj:RemoveFromParent()
	end


	if string.find(obj.fullname, "lily") or string.find(obj.fullname, "ducky") then
		-- table.insert(onWater, obj)
	elseif
		string.find(obj.fullname, "scifi_stairs")
		or string.find(obj.fullname, "pipe_tank")
		or string.find(obj.fullname, "world_generator")
		or string.find(obj.fullname, "world_computer")
		or string.find(obj.fullname, "small_water_pipe")
		or string.find(obj.fullname, "laptop")
		or string.find(obj.fullname, "catwalk_stage")
		or string.find(obj.fullname, "change_room")
		or string.find(obj.fullname, "steel_folding_chairtop")
		or string.find(obj.fullname, "steel_folding_chair")
		or string.find(obj.fullname, "smartphone")
		or string.find(obj.fullname, "portal")
		or string.find(obj.fullname, "obstacle_blue")
		or string.find(obj.fullname, "onstacle_red")
		or string.find(obj.fullname, "obstacle_red")
		or string.find(obj.fullname, "reload_station")
		or string.find(obj.fullname, "recharge_station")
		or string.find(obj.fullname, "ladder_metal")
		or string.find(obj.fullname, "metal_panel")
		or string.find(obj.fullname, "solo_computer")
		or string.find(obj.fullname, "orange_pipe")
		or (obj.Name ~= nil and string.find(obj.Name, "plate_jetpack"))
		or (obj.Name ~= nil and string.find(obj.Name, "exit_jetpack"))
		or (obj.Name ~= nil and string.find(obj.Name, "plate_nerf"))
		or (obj.Name ~= nil and string.find(obj.Name, "exit_nerf"))
		or (obj.Name ~= nil and string.find(obj.Name, "friend_jetpack"))
		or (obj.Name ~= nil and string.find(obj.Name, "friend_nerf"))
	then
		obj:RemoveFromParent()
	elseif string.find(obj.fullname, "floor_propeller") then
		obj.Physics = PhysicsMode.Static
		hierarchyactions:applyToDescendants(obj, { includeRoot = false }, function(o)
			o.Physics = PhysicsMode.Disabled
		end)
		table.insert(propellers, obj:GetChild(1))
	elseif string.find(obj.fullname, "firefly") then
		obj.IsUnlit = true
		hierarchyactions:applyToDescendants(obj, { includeRoot = true }, function(o)
			o.Physics = PhysicsMode.Disabled
		end)
		obj.animation_speed = math.random(1, 2)
		obj.timer = math.random(1, 5)
		obj.range = math.random(2, 3) * 0.4
		obj.initialPosY = obj.LocalPosition.Y + obj.range
		table.insert(fireflies, obj)
	elseif string.find(obj.fullname, "friend_icon") then
		local kOFFSET_Y = { 0, 2, 0 }

		obj.Physics = PhysicsMode.Trigger
		obj.CollidesWithGroups = { 2 }
		obj.CollisionGroups = nil

		obj.PrivateDrawMode = 1
		obj.IsUnlit = true
		obj.LocalPosition = obj.LocalPosition + kOFFSET_Y
		obj.initialY = obj.LocalPosition.Y
		obj.timer = math.random(1, 5)

		obj.OnCollisionBegin = friendIconOnCollisionBegin
		obj.OnCollisionEnd = friendIconOnCollisionEnd

		table.insert(friendIcons, obj)
	end
end

function loadMap()
	map = Map
	MAP_SCALE = map.Scale
	map.Shadow = true

	waterShapes = {}
	table.insert(waterShapes, map:GetChild(1))
	table.insert(waterShapes, map:GetChild(2))

	map:GetChild(3).LocalPosition = Number3(84.5, 14.25, 51.5)
	map:GetChild(3).Physics = PhysicsMode.StaticPerBlock
	map:GetChild(3).CollisionGroups = Map.CollisionGroups
	map:GetChild(3).Scale = 1.001

	-- water
	for i, waterShape in ipairs(waterShapes) do
		i = i + 1
		waterShape.CollisionGroups = Map.CollisionGroups
		waterShape.CollidesWithGroups = Map.CollidesWithGroups
		waterShape.Physics = PhysicsMode.StaticPerBlock
		waterShape.InnerTransparentFaces = false
		if i == 2 then
			waterShape.LocalPosition.Y = waterShape.LocalPosition.Y + 0.25
		elseif i == 1 then
			waterShape.LocalPosition.Y = waterShape.LocalPosition.Y - 0.25
		end
		waterShape.originY = waterShape.LocalPosition.Y
		waterShape:RefreshModel()
	end

	-- Timer(0.1, function()
	-- 	for _, o in ipairs(onWater) do
	-- 		o.Pivot.Y = 0
	-- 		local p = o.Position + Number3.Up * map.Scale
	-- 		local ray = Ray(p, Number3.Down)
	-- 		local impact = ray:Cast(map.CollisionGroups)
	-- 		if impact ~= nil then
	-- 			o.Position = p + Number3.Down * impact.Distance
	-- 		end
	-- 	end
	-- 	-- disabling water physics
	-- 	for _, w in ipairs(waterShapes) do
	-- 		pcall(function()
	-- 			w.Physics = PhysicsMode.Disabled
	-- 			o.CollisionGroups = {}
	-- 			o.CollidesWithGroups = {}
	-- 			o.Physics = PhysicsMode.Disabled
	-- 		end)
	-- 	end
	-- end)

	local n3_1 = Number3.Zero
	local n3_2 = Number3.Zero
	local function lookAtHorizontal(o1, o2)
		n3_1:Set(o1.Position.X, 0, o1.Position.Z)
		n3_2:Set(o2.Position.X, 0, o2.Position.Z)
		o1.Rotation:SetLookRotation(n3_2 - n3_1)
	end

	-- Timer(0.1, function()
	-- 	local avatars = World:FindObjectsByName("cta_customavatar")
	-- 	for i, a in ipairs(avatars) do
	-- 		if i == 2 then
	-- 			local defaultScale = Number3(0.5, 0.5, 0.5)
	-- 			local o = Object()
	-- 			local o2 = Object()
	-- 			o2:SetParent(o)
	-- 			local _avatar = avatar:get("claire")
	-- 			o.Physics = PhysicsMode.Trigger
	-- 			o.CollisionBox = Box({ -40, 0, -40 }, { 40, 25, 40 })
	-- 			o.CollidesWithGroups = Player.CollisionGroups
	-- 			o.CollisionGroups = {}
	-- 			o2.Scale = Player.Scale
	-- 			o2.LocalRotation = Rotation(0, math.rad(-140), 0)
	-- 			_avatar:SetParent(o2)
	-- 			World:AddChild(o)
	-- 			o.Position = a.Position
	-- 			o.OnCollisionBegin = function(_, player)
	-- 				if player ~= Player then
	-- 					return
	-- 				end
	-- 				o2:TextBubble(
	-- 					"Hey! You can edit your avatar in the Profile Menu. 👕👖🥾",
	-- 					-1,
	-- 					Number3(0, 40, 0),
	-- 					true
	-- 				)
	-- 				-- Menu:showProfileButton()

	-- 				ease:cancel(o2)
	-- 				ease:linear(o2, 0.1, {
	-- 					onDone = function(o2)
	-- 						ease:linear(o2, 0.1, {}).Scale = defaultScale
	-- 					end,
	-- 				}).Scale = (
	-- 					defaultScale * 1.1
	-- 				)

	-- 				o2.Tick = function(o, _)
	-- 					lookAtHorizontal(o, player)
	-- 				end
	-- 			end
	-- 			o.OnCollisionEnd = function(_, _)
	-- 				-- cancel animation and reset NPC scale
	-- 				ease:cancel(o2)
	-- 				o2.Scale = defaultScale

	-- 				o2:ClearTextBubble()
	-- 				o2.Tick = nil
	-- 			end
	-- 		end
	-- 		a:RemoveFromParent()
	-- 	end
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
			if gliderUsageToast ~= nil then
				gliderUsageToast:remove()
				gliderUsageToast = nil
			end
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
	playerControls:walk(p)
	p.Position = SPAWN_IN_BLOCK * map.Scale
	p.Rotation = { 0, 0.2, 0 } -- to have NPC in field of view
	p.Head.LocalRotation.X = 0.06
	p.Velocity = { 0, 0, 0 }
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
end

function resetKVS()
	-- if debug then
	local retry = {}
	retry.fn = function()
		local store = KeyValueStore(Player.UserID)
		store:set("collectedGliderParts", {}, "collectedJetpackParts", {}, "CollectedNerfParts", {}, function(ok)
			if not ok then
				Timer(REQUEST_FAIL_RETRY_DELAY, retry.fn)
			end
		end)
	end
	retry.fn()
	addCollectibles()
	-- end
end

function addCollectibles()
	local GLIDER_PARTS = 10
	local JETPACK_PARTS = 2
	local NERF_PARTS = 0

	collectedGliderParts = {}
	collectedJetpackParts = {}
	collectedNerfParts = {}

	gliderParts = {}
	jetpackParts = {}
	nerfParts = {}

	gliderUnlocked = false
	jetpackUnlocked = false
	nerfUnlocked = false

	gliderBackpackCollectibles = {}
	jetpackBackpackCollectibles = {}

	equipment = nil

	local function unlockGlider()
		gliderUnlocked = true
		for _, backpack in ipairs(gliderBackpackCollectibles) do
			backpack.object.PrivateDrawMode = 0
		end
	end

	local function unlockJetpack()
		jetpackUnlocked = true
		for _, backpack in ipairs(jetpackBackpackCollectibles) do
			backpack.object.PrivateDrawMode = 0
		end
	end

	local function unlockNerf()
		nerfUnlocked = true
	end

	local function spawnBackpacks()
		-- Glider backpack (blue)
		local defaultBackpackConfig = {
			scale = GLIDER_BACKPACK.SCALE,
			rotation = Number3.Zero,
			position = Number3.Zero,
			itemName = GLIDER_BACKPACK.ITEM_NAME,
			onCollisionBegin = function(c)
				if gliderUnlocked then
					collectParticles.Position = c.object.Position
					collectParticles:spawn(20)
					sfx("wood_impact_3", { Position = c.object.Position, Volume = 0.6, Pitch = 1.3 })
					Client:HapticFeedback()
					collectible:remove(c)

					Player:EquipBackpack(c.object)

					equipment = "glider"
					multi:action("equipGlider")

					gliderUsageToast = require("ui_toast"):create({
						message = "Maintain jump key to start gliding!",
						center = false,
						iconShape = bundle.Shape("voxels.glider"),
						duration = -1, -- negative duration means infinite
					})
				else
					backpackTransparentToast = require("ui_toast"):create({
						message = #collectedGliderParts .. "/" .. #gliderParts .. " collected",
						center = true,
						duration = -1, -- negative duration means infinite
						iconShape = bundle.Shape("voxels.glider_parts"),
					})
				end
			end,
			onCollisionEnd = function(_)
				if backpackTransparentToast then
					backpackTransparentToast:remove()
					backpackTransparentToast = nil
				end
			end,
		}

		local gliderBackpackConfigs = {
			{ position = Number3(451, 102, 510) },
			{ position = Number3(878, 396, 271) }, -- tower top
			{ position = Number3(653, 318, 655) }, -- pink tree
			{ position = Number3(481, 470, 155) }, -- wook plank
		}

		for _, backpackConfig in ipairs(gliderBackpackConfigs) do
			local config = conf:merge(defaultBackpackConfig, backpackConfig)
			local c = collectible:create(config)
			c.object.PrivateDrawMode = 1
			table.insert(gliderBackpackCollectibles, c)
		end

		-- Jetpack backpack (red)
	end

	local function spawnCollectibles()
		spawnBackpacks()

		for i = 1, GLIDER_PARTS do
			table.insert(gliderParts, World:FindObjectByName("voxels.glider_parts_" .. i))
		end

		for i = 1, JETPACK_PARTS do
			table.insert(jetpackParts, World:FindObjectByName("voxels.jetpack_scrap_pile_" .. i))
		end

		for i = 1, NERF_PARTS do
			table.insert(nerfParts, World:FindObjectByName("nerf_" .. i))
		end

		local gliderPartConfig = {
			scale = 0.5,
			itemName = "voxels.glider_parts",
			position = Number3.Zero,
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

				if #collectedGliderParts >= #gliderParts then
					-- the last glider part has been collected
					require("ui_toast"):create({
						message = "Glider unlocked!",
						center = false,
						iconShape = bundle.Shape(GLIDER_BACKPACK.ITEM_NAME),
						duration = 2,
					})
					unlockGlider()
				else
					-- a glider part has been collected
					require("ui_toast"):create({
						message = #collectedGliderParts .. "/" .. #gliderParts .. " collected",
						iconShape = bundle.Shape("voxels.glider_parts"),
						keepInStack = false,
					})
				end
			end,
		}

		local jetpackPartConfig = {
			scale = 0.5,
			itemName = "voxels.jetpack_scrap_pile",
			position = Number3.Zero,
			userdata = {
				ID = -1,
			},
			onCollisionBegin = function(c)
				collectParticles.Position = c.object.Position
				collectParticles:spawn(20)
				sfx("wood_impact_3", { Position = c.object.Position, Volume = 0.6, Pitch = 1.3 })
				Client:HapticFeedback()
				collectible:remove(c)
				if contains(collectedJetpackParts, c.userdata.ID) then
					return
				end

				table.insert(collectedJetpackParts, c.userdata.ID)
				local retry = {}
				retry.fn = function()
					local store = KeyValueStore(Player.UserID)
					store:set("collectedJetpackParts", collectedJetpackParts, function(ok)
						if not ok then
							Timer(REQUEST_FAIL_RETRY_DELAY, retry.fn)
						end
					end)
				end
				retry.fn()

				if #collectedJetpackParts >= #jetpackParts then
					-- the last jetpack part has been collected
					require("ui_toast"):create({
						message = "Jetpack unlocked!",
						center = false,
						iconShape = bundle.Shape("voxels.jetpack"), -- @aduermael to replace with :: bundle.Shape("voxels.jetpack"),
						duration = 2,
					})
					unlockJetpack()
				else
					-- a jetpack part has been collected
					require("ui_toast"):create({
						message = #collectedJetpackParts .. "/" .. #jetpackParts .. " collected",
						iconShape = bundle.Shape("voxels.jetpack_scrap_pile"),
						keepInStack = false,
					})
				end
			end,
		}

		local nerfPartConfig = {
			scale = 0.5,
			itemName = "voxels.pistol",
			position = Number3.Zero,
			userdata = {
				ID = -1,
			},
			onCollisionBegin = function(c)
				collectParticles.Position = c.object.Position
				collectParticles:spawn(20)
				sfx("wood_impact_3", { Position = c.object.Position, Volume = 0.6, Pitch = 1.3 })
				Client:HapticFeedback()
				collectible:remove(c)
				if contains(collectedNerfParts, c.userdata.ID) then
					return
				end

				table.insert(collectedNerfParts, c.userdata.ID)
				local retry = {}
				retry.fn = function()
					local store = KeyValueStore(Player.UserID)
					store:set("collectedNerfParts", collectedNerfParts, function(ok)
						if not ok then
							Timer(REQUEST_FAIL_RETRY_DELAY, retry.fn)
						end
					end)
				end
				retry.fn()

				if #collectedNerfParts >= #nerfParts then
					-- the last foam gun part has been collected
					require("ui_toast"):create({
						message = "Nerf unlocked!",
						center = false,
						iconShape = bundle.Shape("voxels.pistol"),
						duration = 2,
					})
					unlockNerf()
				else
					-- a foam gun part has been collected
					require("ui_toast"):create({
						message = #collectedNerfParts .. "/" .. #nerfParts .. " collected",
						iconShape = bundle.Shape("voxels.pistol"),
						keepInStack = false,
					})
				end
			end,
		}

		if #collectedGliderParts >= #gliderParts then -- or true then
			unlockGlider()
			for _, v in pairs(gliderParts) do
				v:RemoveFromParent()
			end -- @Buche :: clear placed collectibles from world editor
		else
			for k, v in ipairs(gliderParts) do
				if not contains(collectedGliderParts, k) then
					local config = conf:merge(gliderPartConfig, { position = v.Position, userdata = { ID = k } })
					collectible:create(config)
				end
				v:RemoveFromParent() -- @Buche :: clear placed collectibles if already collected
			end
		end

		if #collectedJetpackParts >= #jetpackParts then
			unlockJetpack()
			for _, v in pairs(jetpackParts) do
				v:RemoveFromParent()
			end
		else
			for k, v in ipairs(jetpackParts) do
				if not contains(collectedJetpackParts, k) then
					local config = conf:merge(jetpackPartConfig, { position = v.Position, userdata = { ID = k } })
					collectible:create(config)
				end
				v:RemoveFromParent() -- @Buche :: clear placed collectibles if already collected
			end
		end

		if #collectedNerfParts >= #nerfParts then
			unlockNerf()
			for _, v in pairs(nerfParts) do
				v:RemoveFromParent()
			end
		else
			for k, v in ipairs(nerfParts) do
				if not contains(collectedJetpackParts, k) then
					local config = conf:merge(nerfPartConfig, { position = v.Position, userdata = { ID = k } })
					collectible:create(config)
				end
				v:RemoveFromParent() -- @Buche :: clear placed collectibles if already collected
			end
		end
	end

	local t = {}
	t.get = function()
		local store = KeyValueStore(Player.UserID)
		store:get("collectedGliderParts", "collectedJetpackParts", "collectedNerfParts", function(ok, results)
			if type(ok) ~= "boolean" then
				error("KeyValueStore:get() unexpected type of 'ok'", 2)
			end
			if type(results) ~= "table" and type(results) ~= "nil" then
				error("KeyValueStore:get() unexpected type of 'results'", 2)
			end
			if ok == true then
				if results.collectedGliderParts ~= nil then
					collectedGliderParts = results.collectedGliderParts
				end
				if results.collectedJetpackParts ~= nil then
					collectedJetpackParts = results.collectedJetpackParts
				end
				if results.collectedNerfParts ~= nil then
					collectedNerfParts = results.collectedNerfParts
				end
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

playerControls.getPlayerID = function(_, player)
	if player == Player then
		-- using "local" because the local player ID may change while still maintaining active controls
		return "local"
	else
		return player.ID
	end
end

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
	local pID = self:getPlayerID(player)

	local vehicle = self.vehicles[pID]

	if vehicle == nil then
		return
	end

	if player.Animations.LiftArms then
		player.Animations.LiftArms:Stop()
	end

	vehicle.Tick = nil

	-- NOTE: each vehicle should implement an onExit
	-- callback instead of harcoding everything here.

	if vehicle.wingTrails then
		for _, t in ipairs(vehicle.wingTrails) do
			wingTrail:remove(t)
		end
		vehicle.wingTrails = nil
	end

	player:SetParent(World, true)
	player.Rotation = { 0, vehicle.Rotation.Y, 0 }
	player.Position = vehicle.Position + { 0, -27, 0 }

	player.Head.LocalRotation = { 0, 0, 0 }
	player.Physics = PhysicsMode.Dynamic
	player.Scale = 0.5
	player.Velocity = Number3.Zero

	if player == Player then
		Camera:SetModeThirdPerson(player)
		Camera.FOV = cameraDefaultFOV
	end

	vehicle.Physics = PhysicsMode.Disabled

	if vehicle.model ~= nil then
		vehicle.model.Physics = PhysicsMode.Disabled
		vehicle.model:SetParent(player, true)
		vehicle:RemoveFromParent()
		ease:linear(vehicle.model, 0.3, {
			onDone = function(o)
				o:RemoveFromParent()
			end,
		}).Scale =
			Number3.Zero
	else
		vehicle:SetParent(World, true)
		ease:linear(vehicle, 0.3, {
			onDone = function(o)
				o:RemoveFromParent()
			end,
		}).Scale = Number3.Zero
	end

	self.vehicles[pID] = nil
end

playerControls.walk = function(self, player)
	local pID = self:getPlayerID(player)

	if self.current[pID] == "walk" then
		return -- already walking
	end
	self.current[pID] = "walk"

	self:exitVehicle(player)

	player:SetParent(World, true)

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
local GLIDER_DRAG_DOWN = -400

playerControls.glide = function(self, player)
	local pID = self:getPlayerID(player)

	if self.current[pID] == "glide" then
		return -- already gliding
	end
	self.current[pID] = "glide"

	self:exitVehicle(player)

	local vehicle = Object()
	vehicle.Scale = 0.5
	vehicle:SetParent(World)
	vehicle.type = "glider"

	self.vehicles[pID] = vehicle

	local glider = self:getShape("voxels.glider")
	glider.Shadow = true
	glider.Physics = PhysicsMode.Disabled
	vehicle.model = glider

	vehicle.Position = player:PositionLocalToWorld({ 0, player.BoundingBox.Max.Y - 2, 0 })

	glider.Scale = 0
	ease:cancel(glider)
	ease:outElastic(glider, 0.3).Scale = Number3(1, 1, 1)

	if player.Animations.LiftArms then
		player.Animations.LiftArms:Play()
	end

	vehicle.Physics = PhysicsMode.Dynamic
	-- vehicle.Tick resets velocity every frame, it means we have to emulate each individual part ourself
	-- instead of letting velocity compound (from forces, other objects, collision responses etc.), it also
	-- means that vehicle.Acceleration does nothing for us
	vehicle.gliderSpd = 0
	vehicle.gliderPull = Number3(0, GLIDER_DRAG_DOWN, 0)

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
	local dot

	vehicle.Rotation:Set(0, player.Rotation.Y, 0)
	local initSpd = (player.Motion + player.Velocity * 0.1).Length
	vehicle.gliderSpd = math.min(initSpd, GLIDER_MAX_START_SPEED)

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

		vehicle.CollisionBox = Box({ -10, -30, -10 }, { 10, 14, 10 })
		vehicle.CollidesWithGroups = Map.CollisionGroups + vehicle.CollisionGroups + DRAFT_COLLISION_GROUPS
		vehicle.CollisionGroups = {}

		vehicle.OnCollisionBegin = function(_, other)
			if other.CollisionGroups == DRAFT_COLLISION_GROUPS then
				return
			end
			playerControls:walk(player)
		end

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

			yawDelta.Y = diffY * dt * 0.001 * 70
			yaw = yawDelta * yaw

			o.Rotation = yaw * tilt

			dot = o.Forward:Dot(Number3.Down)
			down = math.max(0, dot) -- 0 -> 1
			up = math.max(0, -dot)

			-- accelerate when facing down / lose more velocity when going up
			o.gliderSpd = o.gliderSpd + down * 80.0 * dt - (8.0 + up * 30.0) * dt
			o.gliderSpd = math.max(o.gliderSpd, 0)
			o.gliderSpd = math.min(GLIDER_MAX_SPEED, o.gliderSpd)

			o.Velocity:Set(o.Forward * o.gliderSpd + o.gliderPull * dt)
			vehicleRoll.Velocity:Set(o.Velocity) -- copying for sync (physics disabled on vehicleRoll)

			-- EFFECTS
			speedOverMax = math.min(1.0, o.gliderSpd / GLIDER_MAX_SPEED_FOR_EFFECTS)
			Camera.FOV = cameraDefaultFOV + 20 * speedOverMax

			f = 0.2 * speedOverMax
			rightTrail:setColor(Color(255, 255, 255, rightLift * f))
			leftTrail:setColor(Color(255, 255, 255, leftLift * f))
		end

		require("camera_modes"):setThirdPerson({
			rigidity = 0.3,
			target = vehicle,
			rotationOffset = Rotation(math.rad(20), 0, 0),
		})

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

		vehicle.Tick = function(o, _)
			-- only update wing trail colors
			-- no local simulation (for now?), looks good enough so far

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

			-- down = math.max(0, vehicle.Forward:Dot(Number3.Down)) -- 0 -> 1
			-- up = math.max(0, vehicle.Forward:Dot(Number3.Up))
			-- -- accelerate when facing down / lose more velocity when going up
			-- l = l + down * 50.0 * dt - (8.0 + up * 8.0) * dt
			-- l = math.max(l, 0) -- speed can't be below 0
			-- l = math.min(l, GLIDER_MAX_SPEED) -- can't go faster than GLIDER_MAX_SPEED
			-- vehicle.Velocity:Set(o.Forward * l)

			-- EFFECTS
			speedOverMax = math.min(1.0, l / GLIDER_MAX_SPEED_FOR_EFFECTS)

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
	o.CollisionGroups = DRAFT_COLLISION_GROUPS
	o.CollidesWithGroups = 2
	o.CollisionBox = Box({ 0, 0, 0 }, { width, height, depth })
	o.LocalPosition = pos
	o.strength = strength

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
	o.as:Play()

	o.Tick = function(self, _)
		self.emitter:spawn(1)
	end

	o.OnCollisionBegin = function(_, other)
		if other.gliderPull then
			ease:cancel(other.gliderPull)
			ease:inOutSine(other.gliderPull, 0.3).Y = strength
		end
	end

	o.OnCollisionEnd = function(_, other)
		if other.gliderPull then
			ease:cancel(other.gliderPull)
			ease:inOutSine(other.gliderPull, 0.3).Y = GLIDER_DRAG_DOWN
		end
	end

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

friendIconOnCollisionBegin = function(icon, other)
	-- self.IsHidden = true
	if other ~= Player then
		return
	end
	other.toastTimer = Timer(1, function()
		local toastMsg = "You can add friends in the Friends Menu!"
		if icon.Name == "friend_jetpack" then
			toastMsg = "Find a friend to help you open this door!"
		elseif icon.Name == "friend_nerf" then
			toastMsg = "Find 3 friends to help you open this secret door!"
		end

		other.addFriendsToast = require("ui_toast"):create({
			message = toastMsg,
			center = true,
			duration = -1, -- negative duration means infinite
			iconShape = bundle.Shape("voxels.friend_icon"),
		})
	end)
end

friendIconOnCollisionEnd = function(_, other)
	-- self.IsHidden = false
	if other ~= Player then
		return
	end
	if other.toastTimer then
		other.toastTimer:Cancel()
		other.toastTimer = nil
	end
	if other.addFriendsToast then
		other.addFriendsToast:remove()
		other.addFriendsToast = nil
	end
end

-- MODULES

-- setTriggerPlates = function()
-- 	local hierarchyactions = require("hierarchyactions")
-- 	-- MODULE TRIGGERS --

-- 	newTriggerInstance = function(config)
-- 		local instance = {}
-- 		instance.triggers = {}
-- 		instance.isActive = false

-- 		local _config = {} --TODO:: Config merge
-- 		_config.triggers = config.triggers
-- 		_config.triggerCallback = config.triggerCallback or nil
-- 		_config.triggerDelay = config.triggerDelay or 0.5
-- 		_config.target = config.target
-- 		_config.targetCallback = config.targetCallback or nil
-- 		_config.targetDelay = config.targetDelay or 0.5
-- 		_config.forcedMulti = config.forcedMulti or false

-- 		for k, _ in pairs(_config.triggers) do
-- 			instance.triggers[k] = addTrigger(instance, k, _config)
-- 		end

-- 		return instance
-- 	end

-- 	local triggerOnCollisionBegin = function(self, other)
-- 		if type(other) == Type.Object then
-- 			return
-- 		end --multi.lua again
-- 		local config = self.config
-- 		if config == nil then
-- 			return
-- 		end
-- 		local instance = self.instance
-- 		if instance == nil then
-- 			return
-- 		end
-- 		local k = self.k
-- 		if k == nil then
-- 			return
-- 		end
-- 		if self.currentDelay then
-- 			self.currentDelay:Cancel()
-- 		end --cancel ongoing delay if any
-- 		if config.forcedMulti then
-- 			freeTriggers(instance, other.ID, config)
-- 		end -- a player can't be holding several triggers if forcedMulti is set to true
-- 		if not isTriggerActive(self) then
-- 			config.triggerCallback(config.triggers[k], true)
-- 		end -- activate trigger if not already activated
-- 		activateTrigger(self, other.ID, true) -- player now holds the trigger
-- 		Timer(0.5, function() -- after the target delay, check to start the target callback
-- 			if not areAllTriggersActivated(instance) then
-- 				return
-- 			end
-- 			if not isInstanceActive(instance) then
-- 				config.targetCallback(config.target, true)
-- 				activateInstance(instance, true)
-- 			end
-- 		end)
-- 	end

-- 	local triggerOnCollisionEnd = function(self, other)
-- 		if type(other) == Type.Object then
-- 			return
-- 		end --multi.lua again
-- 		local config = self.config
-- 		if config == nil then
-- 			return
-- 		end
-- 		local instance = self.instance
-- 		if instance == nil then
-- 			return
-- 		end
-- 		local k = self.k
-- 		if k == nil then
-- 			return
-- 		end
-- 		self.currentDelay = Timer(config.triggerDelay, function() -- After the target delay
-- 			activateTrigger(self, other.ID, false) -- player no longer holds the trigger
-- 			if not isTriggerActive(self) then
-- 				config.triggerCallback(config.triggers[k], false)
-- 			end -- deactivate if no one else holds it
-- 			if isInstanceActive(instance) then -- deactivate door if not already deactivated
-- 				Timer(config.targetDelay, function()
-- 					config.targetCallback(config.target, false)
-- 					activateInstance(instance, false)
-- 				end)
-- 			end
-- 		end)
-- 	end

-- 	addTrigger = function(instance, k, config)
-- 		-- create a trigger area around the object and ignore collisions
-- 		local triggerArea = createTriggerArea(config.triggers[k])
-- 		triggerArea.config = config
-- 		triggerArea.instance = instance
-- 		triggerArea.k = k
-- 		triggerArea.holding = {} -- table to store anyone holding the trigger
-- 		triggerArea.OnCollisionBegin = triggerOnCollisionBegin
-- 		triggerArea.OnCollisionEnd = triggerOnCollisionEnd
-- 		return triggerArea
-- 	end

-- 	createTriggerArea = function(parentObject)
-- 		local area = Object()
-- 		area:SetParent(parentObject)
-- 		area.Physics = PhysicsMode.Trigger
-- 		area.CollisionBox = Box(
-- 			{ parentObject.Width * 0.2, 0, parentObject.Depth * 0.2 },
-- 			{ parentObject.Width * 0.8, parentObject.Height * 8, parentObject.Depth * 0.8 }
-- 		)
-- 		area.LocalPosition = -parentObject.Pivot
-- 		hierarchyactions:applyToDescendants(
-- 			parentObject,
-- 			{ includeRoot = true },
-- 			function(o) -- also applies to the new object created
-- 				o.CollisionGroups = Map.CollisionGroups -- make them climbable
-- 				o.CollidesWithGroups = nil
-- 			end
-- 		)
-- 		area.CollisionGroups = nil
-- 		area.CollidesWithGroups = Player.CollisionGroups
-- 		return area
-- 	end

-- 	areAllTriggersActivated = function(instance)
-- 		for _, v in pairs(instance.triggers) do
-- 			if not isTriggerActive(v) then
-- 				return false
-- 			end
-- 		end
-- 		return true
-- 	end

-- 	isInstanceActive = function(instance)
-- 		return instance.isActive
-- 	end

-- 	isTriggerActive = function(trigger)
-- 		for _, v in pairs(trigger.holding) do
-- 			if v == true then
-- 				return true
-- 			end
-- 		end
-- 		return false
-- 	end

-- 	isHolding = function(trigger, playerId)
-- 		return trigger.holding[playerId]
-- 	end

-- 	activateTrigger = function(trigger, playerId, bool)
-- 		trigger.holding[playerId] = bool
-- 	end

-- 	activateInstance = function(instance, bool)
-- 		instance.isActive = bool
-- 	end

-- 	freeTriggers = function(instance, playerId, config)
-- 		for k, v in pairs(instance.triggers) do
-- 			if isHolding(v, playerId) then
-- 				activateTrigger(v, playerId, false)
-- 			end
-- 			if not isTriggerActive(v) then
-- 				config.triggerCallback(config.triggers[k], false)
-- 			end
-- 		end
-- 	end
-- 	---------------------

-- 	-- LOCAL CODE --
-- 	local DOOR_ANIM = 0.8
-- 	local DOOR_SCALE = { 1, 1, 1 }
-- 	local DOOR_SCALEDOWN = { 0.99, 0.99, 0.99 }

-- 	local PLATE_ANIM = 0.5
-- 	local PLATE_PRIMARY = Color(107, 168, 96)
-- 	local PLATE_SECONDARY = Color(79, 148, 67)
-- 	local BULB_PRIMARY = Color(107, 168, 96)
-- 	local BULB_SECONDARY = Color(79, 148, 67)

-- 	local doorCallback = function(target, bool)
-- 		-- Expliciting which parts to animate and their initial positions
-- 		if not target.isInit then
-- 			hierarchyactions:applyToDescendants(target, { includeRoot = true }, function(o)
-- 				o.CollidesWithGroups = { 2 }
-- 				o.CollisionGroups = nil
-- 			end)
-- 			target.leftDoor = target:GetChild(1)
-- 			target.initialLeftPosition = target.leftDoor.LocalPosition.X
-- 			target.rightDoor = target:GetChild(2)
-- 			target.initialRightPosition = target.rightDoor.LocalPosition.X

-- 			if target.indicator then
-- 				target.bulb = target.indicator:GetChild(target.indicatorIdx)
-- 				target.bulb.initialPrimaryColor = Color(
-- 					target.bulb.Palette[1].Color.R,
-- 					target.bulb.Palette[1].Color.G,
-- 					target.bulb.Palette[1].Color.B
-- 				)
-- 				target.bulb.initialSecondaryColor = Color(
-- 					target.bulb.Palette[2].Color.R,
-- 					target.bulb.Palette[2].Color.G,
-- 					target.bulb.Palette[2].Color.B
-- 				)
-- 			end

-- 			target.isInit = true
-- 		end

-- 		-- Handling animation
-- 		if bool then
-- 			ease:inSine(target.leftDoor, DOOR_ANIM).Scale = DOOR_SCALEDOWN
-- 			ease:inSine(target.leftDoor.LocalPosition, DOOR_ANIM).X = target.Width * 0.8
-- 			ease:inSine(target.rightDoor, DOOR_ANIM).Scale = DOOR_SCALEDOWN
-- 			ease:inSine(target.rightDoor.LocalPosition, DOOR_ANIM).X = -target.Width * 0.8
-- 			if target.indicator then
-- 				target.bulb.Palette[1].Color = BULB_PRIMARY
-- 				target.bulb.Palette[2].Color = BULB_SECONDARY
-- 				target.bulb.IsUnlit = true
-- 			end
-- 		else
-- 			ease:inSine(target.leftDoor.LocalPosition, DOOR_ANIM).X = target.initialLeftPosition
-- 			ease:inSine(target.leftDoor, DOOR_ANIM).Scale = DOOR_SCALE
-- 			ease:inSine(target.rightDoor.LocalPosition, DOOR_ANIM).X = target.initialRightPosition
-- 			ease:inSine(target.rightDoor, DOOR_ANIM).Scale = DOOR_SCALE
-- 			if target.indicator then
-- 				target.bulb.Palette[1].Color = target.bulb.initialPrimaryColor
-- 				target.bulb.Palette[2].Color = target.bulb.initialSecondaryColor
-- 				target.bulb.IsUnlit = false
-- 			end
-- 		end
-- 		sfx("automaticdoor_1", { Position = target.Position, Volume = 0.7 })
-- 	end

-- 	local plateCallback = function(trigger, bool)
-- 		-- Expliciting which parts to animate and their initial positions
-- 		if not trigger.isInit then
-- 			trigger.button = trigger:GetChild(1)
-- 			trigger.button.initialPrimaryColor = Color(
-- 				trigger.button.Palette[2].Color.R,
-- 				trigger.button.Palette[2].Color.G,
-- 				trigger.button.Palette[2].Color.B
-- 			)
-- 			trigger.button.initialSecondaryColor = Color(
-- 				trigger.button.Palette[3].Color.R,
-- 				trigger.button.Palette[3].Color.G,
-- 				trigger.button.Palette[3].Color.B
-- 			)

-- 			if trigger.light ~= nil then
-- 				trigger.bulb = trigger.light:GetChild(trigger.lightIdx)
-- 				trigger.bulb.initialPrimaryColor = Color(
-- 					trigger.bulb.Palette[1].Color.R,
-- 					trigger.bulb.Palette[1].Color.G,
-- 					trigger.bulb.Palette[1].Color.B
-- 				)
-- 				trigger.bulb.initialSecondaryColor = Color(
-- 					trigger.bulb.Palette[2].Color.R,
-- 					trigger.bulb.Palette[2].Color.G,
-- 					trigger.bulb.Palette[2].Color.B
-- 				)
-- 			end

-- 			trigger.isInit = true
-- 		end

-- 		-- Handling animation
-- 		if trigger.anim then
-- 			trigger.anim:Cancel()
-- 		end -- reset anim if any
-- 		if bool then
-- 			ease:inSine(trigger.button.LocalPosition, PLATE_ANIM).Y = -3
-- 			trigger.anim = Timer(PLATE_ANIM, function()
-- 				trigger.button.Palette[2].Color = PLATE_PRIMARY
-- 				trigger.button.Palette[3].Color = PLATE_SECONDARY
-- 				trigger.button.IsUnlit = true
-- 				if trigger.light then
-- 					trigger.bulb.Palette[1].Color = BULB_PRIMARY
-- 					trigger.bulb.Palette[2].Color = BULB_SECONDARY
-- 					trigger.bulb.IsUnlit = true
-- 				end
-- 				sfx("button_1", { Position = trigger.Position, Volume = 0.7 })
-- 			end)
-- 		else
-- 			ease:inSine(trigger.button.LocalPosition, PLATE_ANIM).Y = 0
-- 			trigger.button.Palette[2].Color = trigger.button.initialPrimaryColor
-- 			trigger.button.Palette[3].Color = trigger.button.initialSecondaryColor
-- 			trigger.button.IsUnlit = false
-- 			if trigger.light then
-- 				trigger.bulb.Palette[1].Color = trigger.bulb.initialPrimaryColor
-- 				trigger.bulb.Palette[2].Color = trigger.bulb.initialSecondaryColor
-- 				trigger.bulb.IsUnlit = false
-- 			end
-- 			trigger.anim = Timer(PLATE_ANIM, function()
-- 				sfx("button_1", { Position = trigger.Position, Volume = 0.7 })
-- 			end)
-- 		end
-- 	end

-- 	-- Jetpack Door
-- 	local doorJetpack = World:FindObjectByName("door_jetpack")
-- 	local platesJetpackA = World:FindObjectsByName("plate_jetpack") -- 2 plates to open
-- 	local plateJetpackB = World:FindObjectByName("exit_jetpack") -- 1 plate to exit
-- 	local lightsJetpack = World:FindObjectsByName("light_jetpack") -- 2 lights
-- 	for k, v in pairs(platesJetpackA) do
-- 		v.light = lightsJetpack[k]
-- 		v.lightIdx = 1
-- 	end

-- 	local configJetpackA = {
-- 		target = doorJetpack,
-- 		triggers = platesJetpackA,
-- 		triggerCallback = plateCallback,
-- 		triggerDelay = 0.5,
-- 		targetCallback = doorCallback,
-- 		targetDelay = 5,
-- 		forcedMulti = true,
-- 	}
-- 	newTriggerInstance(configJetpackA)

-- 	local configJetpackB = {
-- 		target = doorJetpack,
-- 		triggers = { plateJetpackB },
-- 		triggerCallback = plateCallback,
-- 		triggerDelay = 0.5,
-- 		targetCallback = doorCallback,
-- 		targetDelay = 3,
-- 	}
-- 	newTriggerInstance(configJetpackB)

-- 	-- Nerf Door
-- 	doorNerf = World:FindObjectByName("door_nerf")
-- 	platesNerfA = World:FindObjectsByName("plate_nerf") -- 4 plates to open
-- 	plateNerfB = World:FindObjectByName("exit_nerf") -- 1 plate to exit
-- 	lightsNerf = World:FindObjectByName("light_nerf") -- 4 lights + indicator
-- 	for k, v in pairs(platesNerfA) do
-- 		v.light = lightsNerf
-- 		v.lightIdx = k + 1
-- 	end
-- 	doorNerf.indicator = lightsNerf
-- 	doorNerf.indicatorIdx = 6

-- 	local configNerfA = {
-- 		target = doorNerf,
-- 		triggers = platesNerfA,
-- 		triggerCallback = plateCallback,
-- 		triggerDelay = 0.5,
-- 		targetCallback = doorCallback,
-- 		targetDelay = 60,
-- 	}
-- 	newTriggerInstance(configNerfA)

-- 	local configNerfB = {
-- 		target = doorNerf,
-- 		triggers = { plateNerfB },
-- 		triggerCallback = plateCallback,
-- 		triggerDelay = 0.5,
-- 		targetCallback = doorCallback,
-- 		targetDelay = 3,
-- 	}
-- 	newTriggerInstance(configNerfB)
-- end
