Dev.DisplayColliders = false
local DEBUG_AMBIENCES = false
local DEBUG_ITEMS = false

local SPAWN_POSITION = Number3(254, 80, 181) --315, 81, 138 --spawn point placed in world editor
local SPAWN_ROTATION = Number3(0, math.pi * 0.08, 0)
local TITLE_SCREEN_CAMERA_POSITION_IN_BLOCK = Number3(40, 20, 30)
local ROTATING_CAMERA_MAX_OFFSET_Y_IN_BLOCK = 2.0
local MAP_SCALE = 6.0 -- var because could be overriden when loading map
local GLIDER_BACKPACK = {
	SCALE = 0.75,
	ITEM_NAME = "voxels.glider_backpack",
}

local TIME_CYCLE_DURATION = 30 -- 480 -- 8 minutes
local DAWN_DURATION = 0.05 -- percentages
local DAY_DURATION = 0.5
local DUSK_DURATION = 0.05
local NIGHT_DURATION = 0.4

local TIME_TO_MID_DAY = DAWN_DURATION + DAY_DURATION * 0.5
local HOUR_HAND_OFFSET = -0.5 + 2 * TIME_TO_MID_DAY

-- local MAP_COLLISION_GROUPS = { 1 }
-- local MAP_COLLIDES_WITH_GROUPS = {}

local PLAYER_COLLISION_GROUPS = { 2 }
local PLAYER_COLLIDES_WITH_GROUPS = { 1, 3, 4 } -- map + items + buildings

-- local ITEM_COLLISION_GROUPS = { 3 }
-- local ITEM_COLLIDES_WITH_GROUPS = { 1, 3, 4 } -- map + items + buildings

local BUILDING_COLLISION_GROUPS = { 4 }
local BUILDING_COLLIDES_WITH_GROUPS = {}

local CAMERA_COLLIDES_WITH_GROUPS = { 1, 4 } -- map + buildings

local DRAFT_COLLISION_GROUPS = { 5 }

local _animatedElements = {}

Client.OnStart = function()
	multi = require("multi")
	textbubbles = require("textbubbles")
	skills = require("object_skills")
	controls = require("controls")
	ambience = require("ambience")
	collectible = require("collectible")
	-- SFX & VFX
	particles = require("particles")
	walkSFX = require("walk_sfx")
	sfx = require("sfx")
	wingTrail = require("wingtrail")

	-- HUD
	textbubbles.displayPlayerChatBubbles = true
	controls:setButtonIcon("action1", "⬆️")

	-- AMBIENCE
	Clouds.Altitude = 50 * MAP_SCALE

	if not DEBUG_AMBIENCES then
		ambienceCycle = ambience:startCycle({
			{
				config = dawn,
				duration = TIME_CYCLE_DURATION * DAWN_DURATION,
			},
			{
				config = day,
				duration = TIME_CYCLE_DURATION * DAY_DURATION,
			},
			{
				config = dusk,
				duration = TIME_CYCLE_DURATION * DUSK_DURATION,
			},
			{
				config = night,
				duration = TIME_CYCLE_DURATION * NIGHT_DURATION,
			},
		}, {
			internalTick = false,
		})
	end

	-- CONTROLS
	-- Disabling controls until user is authenticated
	Client.DirectionalPad = nil
	Client.Action1 = nil
	Client.Action1Release = nil
	Pointer.Drag = nil

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

		initPlayer(Player)
		dropPlayer(Player)

		addCollectibles()
		addTimers()

		print(Player.Username .. " joined!")
	end)

	mapEffects()

	-- SYNCED ACTIONS
	multi:onAction("swingRight", function(sender)
		sender:SwingRight()
	end)

	multi:onAction("equipGlider", function(sender)
		local s = bundle.Shape(GLIDER_BACKPACK.ITEM_NAME)
		s.Scale = GLIDER_BACKPACK.SCALE
		sender:EquipBackpack(s)
	end)

	-- called when receiving information for distant object that are not linked
	multi.linkRequest = function(name)
		if _helpers.stringStartsWith(name, "p_") then
			local playerID = math.floor(tonumber(_helpers.stringRemovePrefix(name, "p_")))
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
		elseif _helpers.stringStartsWith(name, "g_") then -- glider
			local playerID = math.floor(tonumber(_helpers.stringRemovePrefix(name, "g_")))
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

Pointer.Click = function(pe)
	Player:SwingRight()
	multi:action("swingRight")

	if _animatedElements.solo_computer.interactionAvailable then
		-- ambienceCycle:next()
	elseif _animatedElements.change_room.interactionAvailable then
		Menu:ShowProfile()
	elseif _animatedElements.fountain.interactionAvailable then
		Menu:ShowFriends()
	elseif _animatedElements.portal.interactionAvailable then
		Menu:ShowWorlds()
	end

	if DEBUG_ITEMS then
		local impact = pe:CastRay()
		if impact ~= nil then
			if impact.Object.Name then
				print(impact.Object.Name)
			end
		end
	end
end

local SAVE_INTERVAL = 0.1
local SAVE_AMOUNT = 10
local savedPositions, savedRotations = {}, {}
local moveDT = 0

local unixMilli
local currentTime
Client.Tick = function(dt)
	if not localPlayerShown then
		moveDT = moveDT + dt * 0.2
		while moveDT > math.pi do
			moveDT = moveDT - math.pi * 2
		end
		Camera.Position.Y = (
			TITLE_SCREEN_CAMERA_POSITION_IN_BLOCK.Y + math.sin(moveDT) * ROTATING_CAMERA_MAX_OFFSET_Y_IN_BLOCK
		) * MAP_SCALE
		Camera:RotateWorld({ 0, 0.1 * dt, 0 })
		return
	end

	if Player.Position.Y < -200 then
		dropPlayer(Player)
	end

	unixMilli = Time.UnixMilli() / 1000.0
	currentTime = unixMilli % TIME_CYCLE_DURATION

	if townhallHourHand ~= nil then
		-- rotation 0 -> 9, -math.pi * 0.5 -> 12
		-- mid-day -> 35% of TIME_CYCLE_DURATION
		-- 0% of TIME_CYCLE_DURATION = -70% of 12h
		-- Rotation(math.pi * (-0.5 + 2 * 0.7 - 2 * 2 * currentTime / TIME_CYCLE_DURATION), 0, 0)
		townhallHourHand.LocalRotation =
			Rotation(math.pi * (HOUR_HAND_OFFSET - 4 * currentTime / TIME_CYCLE_DURATION), 0, 0)
	end

	if townhallMinuteHand ~= nil then
		-- rotation 0 -> 12
		-- Rotation(math.pi * (2 * 0.7 - 2 * 2 * 12 currentTime / TIME_CYCLE_DURATION), 0, 0)
		townhallMinuteHand.LocalRotation = Rotation(math.pi * (-48 * currentTime / TIME_CYCLE_DURATION), 0, 0)
	end

	if not DEBUG_AMBIENCES then
		ambienceCycle:setTime(currentTime)
	end
end

Client.OnPlayerJoin = function(p)
	if p == Player then
		updateSync() -- Syncing for other players
		return
	end
	initPlayer(p)
	dropPlayer(p)
	print(p.Username .. " joined!")
end

Client.OnPlayerLeave = function(p)
	multi:unlink("g_" .. p.ID)
	multi:unlink("ph_" .. p.ID)
	multi:unlink("p_" .. p.ID)

	if p ~= Player then
		print(p.Username .. " just left!")
		skills.removeStepClimbing(p)
		walkSFX:unregister(p)
		p:RemoveFromParent()
	end
end

function setupBuilding(obj)
	obj.CollisionGroups = BUILDING_COLLISION_GROUPS
	obj.CollidesWithGroups = BUILDING_COLLIDES_WITH_GROUPS
	obj.InnerTransparentFaces = false
end

Client.OnWorldObjectLoad = function(obj)
	ease = require("ease")
	hierarchyactions = require("hierarchyactions")
	toast = require("ui_toast")
	bundle = require("bundle")
	avatar = require("avatar")
	ui = require("uikit")

	if obj.Name == "voxels.windmill" then
		setupBuilding(obj)
		obj.Wheel.Physics = PhysicsMode.Disabled
		obj.Wheel.Tick = function(self, dt)
			self:RotateLocal(-dt * 0.25, 0, 0)
		end
		_animatedElements.windmill = obj
	elseif obj.Name == "voxels.home_1" then
		setupBuilding(obj)
	elseif obj.Name == "voxels.city_lamp" then
		obj.Shadow = true
	elseif obj.Name == "voxels.simple_lighthouse" then
		setupBuilding(obj)

		obj.lh_light = obj:GetChild(1)
		obj.lh_light.IsUnlit = true
		obj.lh_light.t = 0
		obj.lh_light.Tick = function(self, dt)
			self.t = self.t + dt * 2
			self.Scale = 1 + math.sin(self.t) * 0.05
		end
		-- obj.source = Light()
		-- obj.source.Color = Color(199, 195, 73)
		-- obj.source.Intensity = 2
		-- obj.source.LocalPosition = { 0, 1, 0 }
		-- obj.source.Radius = 150
		-- obj.source:SetParent(obj.lh_light)

		_animatedElements.lighthouse = obj
	elseif obj.Name == "voxels.townhall" then
		setupBuilding(obj)

		townhallHourHand = obj.Hour
		townhallHourHand.Pivot = { 0.5, 0.5, 0.5 }

		townhallMinuteHand = obj.Minute
		townhallMinuteHand.Pivot = { 0.5, 0.5, 0.5 }

		_animatedElements.townhall = obj
	elseif obj.Name == "voxels.water_fountain" then
		local w = obj:GetChild(1) --water
		w.Physics = PhysicsMode.Disabled
		w.InnerTransparentFaces = false
		w.t = 0
		w.Tick = function(self, dt)
			self.t = self.t + dt
			self.Scale.Y = 1 + (math.sin(self.t) * 0.05)
		end
		local c = obj:GetChild(2) --floating cube
		c.t = 0
		c.dirX, c.dirY, c.dirZ = 0.1, 0.1, 0.1
		c.LocalPosition.Y = c.LocalPosition.Y + 5
		c.LocalRotation = { 0, 0, 0 }
		c.rot = math.pi / 10
		c.Tick = function(self, dt)
			self.t = self.t + dt
			self.rot = self.rot + dt * 0.1
			self.LocalPosition.Y = self.LocalPosition.Y + (math.sin(self.t) * 0.01)
			self:RotateLocal(0, dt * self.dirY, dt * self.dirZ)
			if self.rot > math.pi / 4 then
				self.dirZ = -self.dirZ
				self.rot = 0
			end
		end
		obj.trigger = _helpers.addTriggerArea(obj)
		obj.trigger.OnCollisionBegin = function(self, other)
			if other ~= Player then
				return
			end
			self.toast = toast:create({
				message = "Interact with the fountain to add Friends!",
				center = false,
				iconShape = bundle.Shape("voxels.friend_icon"),
				duration = -1, -- negative duration means infinite
			})
			obj.interactionAvailable = true
		end
		obj.trigger.OnCollisionEnd = function(self, other)
			if other ~= Player then
				return
			end
			self.toast:remove()
			self.toast = nil
			obj.interactionAvailable = false
		end
		_animatedElements.fountain = obj
	elseif obj.Name == "customavatar" then
		obj = _helpers.replaceWithAvatar(obj, "claire")
		obj.OnCollisionBegin = function(self, other)
			_helpers.lookAt(self.avatarContainer, other)
			if other ~= Player then
				return
			end
			_helpers.displayBubble(
				self.avatar,
				"Hey! You can edit your avatar in the Profile Menu. You can also step in the changing room! 👕👖🥾"
			)
		end
		obj.OnCollisionEnd = function(self, other)
			_helpers.lookAt(self.avatarContainer, nil)
			if other ~= Player then
				return
			end
			_helpers.displayBubble(self.avatar, nil)
		end
	elseif obj.Name == "friend1" then
		hierarchyactions:applyToDescendants(obj, { includeRoot = true }, function(o)
			o.Shadow = true
		end)
		obj = _helpers.replaceWithAvatar(obj, "aduermael")
		obj.OnCollisionBegin = function(self, other)
			_helpers.lookAt(self.avatarContainer, other)
		end
		obj.OnCollisionEnd = function(self, _)
			_helpers.lookAt(self.avatarContainer, nil)
		end
	elseif obj.Name == "friend2" then
		hierarchyactions:applyToDescendants(obj, { includeRoot = true }, function(o)
			o.Shadow = true
		end)
		obj = _helpers.replaceWithAvatar(obj, "gdevillele")
		obj.OnCollisionBegin = function(self, other)
			_helpers.lookAt(self.avatarContainer, other)
			if other ~= Player then
				return
			end
			_helpers.displayBubble(
				self.avatar,
				"Want to be friends? You can connect with us by opening the Friends menu!"
			)
		end
		obj.OnCollisionEnd = function(self, other)
			_helpers.lookAt(self.avatarContainer, nil)
			if other ~= Player then
				return
			end
			_helpers.displayBubble(self.avatar, nil)
		end
	elseif obj.Name == "voxels.change_room" then
		obj.trigger = Object()
		obj.trigger:SetParent(obj)
		obj.trigger.LocalPosition = { -obj.Width * 0.5, 0, -obj.Depth * 0.5 }
		obj.trigger.Physics = PhysicsMode.Trigger
		obj.trigger.CollisionBox = obj.BoundingBox
		obj.trigger.CollidesWithGroups = { 2 }
		obj.trigger.CollisionGroups = {}
		obj.trigger.OnCollisionBegin = function(self, other)
			if other ~= Player then
				return
			end
			self.toast = toast:create({
				message = "Interact with the changing room to pick an outfit!",
				center = false,
				iconShape = bundle.Shape("voxels.change_room"),
				duration = -1, -- negative duration means infinite
			})
			obj.interactionAvailable = true
		end
		obj.trigger.OnCollisionEnd = function(self, other)
			if other ~= Player then
				return
			end
			self.toast:remove()
			self.toast = nil
			obj.interactionAvailable = false
		end
		_animatedElements.change_room = obj
	elseif obj.Name == "voxels.portal" then
		obj.trigger = _helpers.addTriggerArea(obj)
		obj.trigger.OnCollisionBegin = function(self, other)
			if other ~= Player then
				return
			end
			self.toast = toast:create({
				message = "Interact with the portal to explore a myriad of worlds!",
				center = false,
				iconShape = bundle.Shape("voxels.portal"),
				duration = -1, -- negative duration means infinite
			})
			obj.interactionAvailable = true
		end
		obj.trigger.OnCollisionEnd = function(self, other)
			if other ~= Player then
				return
			end
			self.toast:remove()
			self.toast = nil
			obj.interactionAvailable = false
		end
		local animatePortal = function(portal)
			local kANIMATION_SPEED = 1
			local kOFFSET_Y = 16

			local ringsParent = portal:GetChild(2)
			hierarchyactions:applyToDescendants(ringsParent, { includeRoot = true }, function(o)
				o.Physics = PhysicsMode.Trigger
				o.IsUnlit = true
			end)

			ringsParent.OnCollisionBegin = function(_, other)
				if other.CollisionGroups == Player.CollisionGroups then
					kANIMATION_SPEED = 5
				end
			end
			ringsParent.OnCollisionEnd = function(_, other)
				if other.CollisionGroups == Player.CollisionGroups then
					kANIMATION_SPEED = 1
				end
			end
			local rings, start, range, speed, timer = {}, {}, {}, {}, {}

			for i = 1, ringsParent.ChildrenCount do
				rings[i] = ringsParent:GetChild(i)
				rings[i].Scale = rings[i].Scale * (1 - 0.01 * i) --Clipping OTP
				start[i] = math.random(-4, 4)
				range[i] = math.random(4, 8)
				speed[i] = math.random(1, 2) * 0.5
				timer[i] = math.random(1, 5)
				rings[i].Tick = function(self, dt)
					timer[i] = timer[i] + speed[i] * dt * kANIMATION_SPEED
					self.LocalPosition.Y = kOFFSET_Y + start[i] + math.sin(timer[i]) * range[i]
				end
			end
		end
		animatePortal(obj)
		_animatedElements.portal = obj
	elseif obj.Name == "voxels.solo_computer" then
		obj.trigger = _helpers.addTriggerArea(obj, nil, { -obj.Width * 0.5, 0, -obj.Depth })
		obj.trigger.OnCollisionBegin = function(self, other)
			if other ~= Player then
				return
			end
			self.toast = toast:create({
				message = "Interact with the computer to change the time",
				center = false,
				iconShape = bundle.Shape("voxels.solo_computer"),
				duration = -1, -- negative duration means infinite
			})
			obj.interactionAvailable = true
		end
		obj.trigger.OnCollisionEnd = function(self, other)
			if other ~= Player then
				return
			end
			self.toast:remove()
			self.toast = nil
			obj.interactionAvailable = false
		end
		_animatedElements.solo_computer = obj
	end

	if obj.fullname ~= nil then
		if
			string.find(obj.fullname, "hedge")
			or string.find(obj.fullname, "fence_gate")
			or string.find(obj.fullname, "white_fence")
			or string.find(obj.fullname, "rustic_fence")
			or string.find(obj.fullname, "hay_bail")
			or string.find(obj.fullname, "palm_tree")
			or string.find(obj.fullname, "apple_tree")
			or string.find(obj.fullname, "carrot_1")
			or string.find(obj.fullname, "turnip")
			or string.find(obj.fullname, "training_dummy")
			or string.find(obj.fullname, "farmhat")
			or string.find(obj.fullname, "broken_bridge_side_1")
			or string.find(obj.fullname, "clothes_rack")
			or string.find(obj.fullname, "city_lamp")
			or string.find(obj.fullname, "solo_computer")
		then
			hierarchyactions:applyToDescendants(obj, { includeRoot = true }, function(o)
				o.Physics = PhysicsMode.Static
			end)
		elseif string.find(obj.fullname, "beach_barrier") then
			hierarchyactions:applyToDescendants(obj, { includeRoot = true }, function(o)
				o.Physics = PhysicsMode.Static
			end)
			-- fix beach barries alignments (for better collisions)
			obj.CollisionBox.Max = Number3(obj.CollisionBox.Max.X, 14, obj.CollisionBox.Max.Z)
			obj.Position.X = math.floor(obj.Position.X * 10) / 10
			obj.Position.Y = math.floor(obj.Position.Y + 0.5)
			obj.Position.Z = math.floor(obj.Position.Z * 10) / 10
		end
	end
end

local JUMP_VELOCITY = 82
local MAX_AIR_JUMP_VELOCITY = 85
initPlayer = function(p)
	if p == Player then -- Player properties for local simulation
		require("camera_modes"):setThirdPerson({
			rigidity = 0.4,
			target = p,
			collidesWithGroups = CAMERA_COLLIDES_WITH_GROUPS,
		})

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
		local spawnJumpParticles = function(o)
			jumpParticles.Position = o.Position
			jumpParticles:spawn(10)
			sfx("walk_concrete_2", { Position = o.Position, Volume = 0.2 })
		end
		skills.addStepClimbing(Player, { mapScale = MAP_SCALE, collisionGroups = Map.CollisionGroups })
		skills.addJump(Player, {
			maxGroundDistance = 1.0,
			airJumps = 1,
			jumpVelocity = JUMP_VELOCITY,
			maxAirJumpVelocity = MAX_AIR_JUMP_VELOCITY,
			onJump = spawnJumpParticles,
			onAirJump = spawnJumpParticles,
		})
		localPlayerShown = true

		-- Timer to save recent on ground positions
		local saveIdx = 1
		Timer(SAVE_INTERVAL, true, function()
			if Player.IsOnGround then
				savedPositions[saveIdx] = Player.Position:Copy() + { 0, MAP_SCALE, 0 } -- adding a one block Y offset on the respawn
				savedRotations[saveIdx] = Player.Rotation:Copy()
				saveIdx = saveIdx + 1
				if saveIdx > SAVE_AMOUNT then
					saveIdx = 1
				end
			end
		end)
	end

	World:AddChild(p) -- Adding the player to the world
	p.Head:AddChild(AudioListener) -- Adding an audio listener to the player
	p.Physics = PhysicsMode.Dynamic
	p.CollisionGroups = PLAYER_COLLISION_GROUPS
	p.CollidesWithGroups = PLAYER_COLLIDES_WITH_GROUPS
	addPlayerAnimations(p) -- Adding animations
	walkSFX:register(p) -- Adding step sounds
	playerControls:walk(p) -- Setting the default control to walk
end

function dropPlayer(p)
	playerControls:walk(p)
	p.Velocity, p.Motion = { 0, 0, 0 }, { 0, 0, 0 }

	if p == Player then
		-- cycling through saved positions to find a valid one
		for k, v in ipairs(savedPositions) do
			local ray = Ray(v, Number3.Down)
			if ray:Cast(Map) ~= nil then
				p.Position = v
				p.Rotation = savedRotations[k]
				return
			end
		end
	end

	p.Position = SPAWN_POSITION + Number3(math.random(-6, 6), 0, math.random(-6, 6))
	p.Rotation = SPAWN_ROTATION + Number3(0, math.random(-1, 1) * math.pi * 0.08, 0)
end

local HOLDING_TIME = 0.6 -- time to trigger action when holding button pressed
local holdTimer = nil
function action1()
	playerControls:walk(Player)
	skills.jump(Player)

	holdTimer = Timer(HOLDING_TIME, function()
		holdTimer = nil
		if backEquipment == "" then
			return
		end
		if backEquipment == "glider" then
			if gliderUsageToast ~= nil then
				gliderUsageToast:remove()
				gliderUsageToast = nil
			end
			playerControls:glide(Player)
		end
	end)

	if DEBUG_AMBIENCES then
		if ambiences == nil then
			ambiences = { dawn, day, dusk, night }
			nextAmbience = 1
		end
		local a = ambiences[nextAmbience]
		ambience:set(a)

		nextAmbience = nextAmbience + 1
		if nextAmbience > #ambiences then
			nextAmbience = 1
		end
	end
end

function action1Release()
	if holdTimer ~= nil then
		holdTimer:Cancel()
	end
end

function mapEffects()
	local sea = Map:GetChild(1)
	sea.Physics = PhysicsMode.Disabled -- let the player go through
	sea.InnerTransparentFaces = false -- no inner surfaces for the renderer
	sea.LocalPosition = { 0, 1, 0 } -- placement
	local t = 0
	sea.Tick = function(self, dt)
		t = t + dt
		self.Scale.Y = 1 + (math.sin(t) * 0.05)
	end

	local grass = Map:GetChild(2)
	grass.Physics = PhysicsMode.StaticPerBlock
	grass.CollisionGroups = { 1 }
	grass.Scale = 0.999
	grass.LocalPosition = { 5, 12.15, 27 }
end

addTimers = function()
	local timeToAvatarCTA = 10
	local timeToFriendsCTA = 20

	local createToastPointer = function(toast)
		local tutoPointer = ui:createText("☝️", Color.White, "big")
		tutoPointer.position.Z = -999
		tutoPointer.t = 0
		tutoPointer.basePos = Number3(tutoPointer.Width, -tutoPointer.Height, 0)
		tutoPointer.object.Tick = function(_, dt)
			tutoPointer.t = tutoPointer.t + dt * 5
			tutoPointer.position = tutoPointer.basePos + Number3(0, math.sin(tutoPointer.t) * 10, 0)
			tutoPointer.color.A = tutoPointer.t * 255
		end
		tutoPointer:setParent(toast.frame)
		return tutoPointer
	end

	local createToastButton = function(toast)
		local toastBtn = ui:createButton("")
		toastBtn:setColor(Color(0, 0, 0, 0))
		toastBtn:setColorPressed(Color(0, 0, 0, 0))
		toastBtn:setColorSelected(Color(0, 0, 0, 0))

		toastBtn.Width = toast.frame.Width
		toastBtn.Height = toast.frame.Height
		toastBtn:setParent(toast.frame)

		return toastBtn
	end

	Timer(timeToAvatarCTA, function()
		local toast = toast:create({
			message = "You can change outfits anytime you like! ",
			center = false,
			iconShape = bundle.Shape("voxels.change_room"),
			duration = -1,
		})
		local ptr = createToastPointer(toast)
		local btn = createToastButton(toast)
		btn.onRelease = function(_)
			Menu:ShowProfile()
			ptr.object.Tick = nil
			toast:remove()
			toast = nil
		end
	end)

	Timer(timeToFriendsCTA, function()
		local toast = toast:create({
			message = "The more the merrier, add friends and play together!",
			center = false,
			iconShape = bundle.Shape("voxels.friend_icon"),
			duration = -1,
		})
		local ptr = createToastPointer(toast)
		local btn = createToastButton(toast)
		btn.onRelease = function(_)
			Menu:ShowFriends()
			ptr.object.Tick = nil
			toast:remove()
			toast = nil
		end
	end)
end

-- HELPERS

_helpers = {}
_helpers.stringStartsWith = function(str, prefix)
	return string.sub(str, 1, string.len(prefix)) == prefix
end

_helpers.stringRemovePrefix = function(str, prefix)
	if string.sub(str, 1, string.len(prefix)) == prefix then
		return string.sub(str, string.len(prefix) + 1)
	else
		return str
	end
end

_helpers.replaceWithAvatar = function(obj, name)
	local o = Object()
	o:SetParent(World)
	o.Position = obj.Position
	o.Scale = obj.Scale
	o.Physics = PhysicsMode.Trigger
	o.CollisionBox = Box({ -30, 0, -30 }, { 30, 25, 30 })
	o.CollidesWithGroups = { 2 }
	o.CollisionGroups = {}

	local container = Object()
	container.Rotation = obj.Rotation
	container.initialRotation = obj.Rotation:Copy()
	container:SetParent(o)
	o.avatarContainer = container

	local newObj = avatar:get(name)
	o.avatar = newObj
	newObj:SetParent(o.avatarContainer)

	obj:RemoveFromParent()
	return o
end

_helpers.lookAt = function(obj, target)
	if not target then
		obj.Tick = nil
		ease:linear(obj, 0.3).Rotation = obj.initialRotation
		return
	end
	obj.Tick = function(self, _)
		_helpers.lookAtHorizontal(self, target)
	end
end

_helpers.lookAtHorizontal = function(o1, o2)
	local n3_1 = Number3.Zero
	local n3_2 = Number3.Zero
	n3_1:Set(o1.Position.X, 0, o1.Position.Z)
	n3_2:Set(o2.Position.X, 0, o2.Position.Z)
	ease:linear(o1, 0.3).Forward = n3_2 - n3_1
end

_helpers.displayBubble = function(obj, msg)
	if not msg then
		obj:ClearTextBubble()
		return
	end
	obj:TextBubble(msg, -1, Number3(0, 24, 0), true)
end

_helpers.addTriggerArea = function(obj, size, offset)
	local o = Object()
	o:SetParent(obj)
	o.Physics = PhysicsMode.Trigger
	o.CollidesWithGroups = { 2 }
	o.CollisionGroups = {}
	o.CollisionBox = size ~= nil and size or obj.BoundingBox
	o.LocalPosition = offset ~= nil and offset or { -obj.Width * 0.5, 0, -obj.Depth * 0.5 }
	return o
end

_helpers.contains = function(t, v)
	for _, value in ipairs(t) do
		if value == v then
			return true
		end
	end
	return false
end

-- MODULE : DAY NIGHT CYCLE

dawn = {
	sky = {
		skyColor = Color(217, 40, 40),
		horizonColor = Color(219, 166, 99),
		abyssColor = Color(37, 100, 176),
		lightColor = Color(137, 95, 45),
		lightIntensity = 0.600000,
	},
	fog = {
		color = Color(199, 120, 110),
		near = 300,
		far = 700,
		lightAbsorbtion = 0.400000,
	},
	sun = {
		color = Color(224, 82, 82),
		intensity = 0.200000,
		rotation = Rotation(math.rad(30), math.rad(-60), 0),
	},
	ambient = {
		skyLightFactor = 0.100000,
		dirLightFactor = 0.150000,
	},
}

day = {
	sky = {
		skyColor = Color(0, 103, 255),
		horizonColor = Color(0, 248, 248),
		abyssColor = Color(202, 255, 245),
		lightColor = Color(199, 174, 148),
		lightIntensity = 0.600000,
	},
	fog = {
		color = Color(20, 159, 204),
		near = 300,
		far = 700,
		lightAbsorbtion = 0.400000,
	},
	sun = {
		color = Color(199, 195, 73),
		intensity = 1.000000,
		rotation = Rotation(math.rad(50), math.rad(-30), 0),
	},
	ambient = {
		skyLightFactor = 0.100000,
		dirLightFactor = 0.200000,
	},
}

dusk = {
	sky = {
		skyColor = Color(96, 4, 205),
		horizonColor = Color(233, 102, 102),
		abyssColor = Color(242, 156, 56),
		lightColor = Color(194, 113, 163),
		lightIntensity = 0.600000,
	},
	fog = {
		color = Color(20, 159, 204),
		near = 300,
		far = 700,
		lightAbsorbtion = 0.400000,
	},
	sun = {
		color = Color(190, 98, 219),
		intensity = 0.200000,
		rotation = Rotation(math.rad(30), math.rad(60), 0),
	},
	ambient = {
		skyLightFactor = 0.100000,
		dirLightFactor = 0.150000,
	},
}

night = {
	sky = {
		skyColor = Color(2, 2, 52),
		horizonColor = Color(124, 43, 133),
		abyssColor = Color(32, 29, 97),
		lightColor = Color(31, 20, 74),
		lightIntensity = 0.600000,
	},
	fog = {
		color = Color(20, 159, 204),
		near = 300,
		far = 700,
		lightAbsorbtion = 0.400000,
	},
	sun = {
		color = Color(36, 44, 195),
		intensity = 0.000000,
		rotation = Rotation(math.rad(0), math.rad(0), 0),
	},
	ambient = {
		skyLightFactor = 0.100000,
		dirLightFactor = 0.000000,
	},
}

-- MODULE : PLAYER CONTROLS

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
		require("camera_modes"):setThirdPerson({
			rigidity = 0.4,
			target = player,
			collidesWithGroups = CAMERA_COLLIDES_WITH_GROUPS,
		})
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
			collidesWithGroups = CAMERA_COLLIDES_WITH_GROUPS,
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

			-- EFFECTS
			speedOverMax = math.min(1.0, l / GLIDER_MAX_SPEED_FOR_EFFECTS)

			f = 0.2 * speedOverMax
			rightTrail:setColor(Color(255, 255, 255, rightLift * f))
			leftTrail:setColor(Color(255, 255, 255, leftLift * f))
		end
	end

	return vehicle
end

-- MODULE : COLLECTIBLES

collectedGliderParts, collectedJetpackParts = {}, {}
gliderBackpackCollectibles, jetpackBackpackCollectibles = {}, {}
gliderUnlocked = false
jetpackUnlocked = false

local REQUEST_FAIL_RETRY_DELAY = 5.0
-- local GLIDER_PARTS = 10
-- local JETPACK_PARTS = 2

backEquipment = nil

-- function resetKVS()
-- 	-- if debug then
-- 	local retry = {}
-- 	retry.fn = function()
-- 		local store = KeyValueStore(Player.UserID)
-- 		store:set("collectedGliderParts", {}, "collectedJetpackParts", {}, "CollectedNerfParts", {}, function(ok)
-- 			if not ok then
-- 				Timer(REQUEST_FAIL_RETRY_DELAY, retry.fn)
-- 			end
-- 		end)
-- 	end
-- 	retry.fn()
-- 	addCollectibles()
-- 	-- end
-- end

function addCollectibles()
	conf = require("config")

	gliderParts, jetpackParts = {}, {}

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

	local function spawnBackpacks()
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

					backEquipment = "glider"
					multi:action("equipGlider")

					gliderUsageToast = toast:create({
						message = "Maintain jump key to start gliding!",
						center = false,
						iconShape = bundle.Shape("voxels.glider"),
						duration = -1, -- negative duration means infinite
					})
				else
					backpackTransparentToast = toast:create({
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

		-- To replace by segment below when world editor is fixed
		local gliderBackpackConfigs = {
			{ position = Number3(75, 186, 262) },
			{ position = Number3(330, 80, 160) },
		}

		for _, bpConfig in pairs(gliderBackpackConfigs) do
			local config = conf:merge(defaultBackpackConfig, bpConfig)
			local c = collectible:create(config)
			c.object.PrivateDrawMode = 1
			table.insert(gliderBackpackCollectibles, c)
		end

		-- segment
		--[[
        local bp = World:FindObjectsByName("voxels.glider_backpack")

        for _, v in pairs(bp) do
            local config = {position = v.Position}
            config = conf:merge(defaultBackpackConfig, config)
            local c = collectible:create(config)
			c.object.PrivateDrawMode = 1
			table.insert(gliderBackpackCollectibles, c)
        end
        ]]
	end

	local function spawnCollectibles()
		-- To replace with segment below when World Editor is fixed
		tempPos = {
			Number3(264, 80, 504),
			Number3(144, 164, 408),
			Number3(75, 186, 300),
		}

		for k, v in ipairs(tempPos) do
			local s = bundle.Shape("voxels.glider_parts")
			s.Name = "voxels.glider_parts_" .. k
			s.Position = v
			table.insert(gliderParts, s)
		end

		-- segment
		--[[
		for i = 1, GLIDER_PARTS do
			table.insert(gliderParts, World:FindObjectByName("voxels.glider_parts_" .. i))
		end

		for i = 1, JETPACK_PARTS do
			table.insert(jetpackParts, World:FindObjectByName("voxels.jetpack_scrap_pile_" .. i))
		end
        ]]

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
				if _helpers.contains(collectedGliderParts, c.userdata.ID) then
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
					toast:create({
						message = "Glider unlocked!",
						center = false,
						iconShape = bundle.Shape(GLIDER_BACKPACK.ITEM_NAME),
						duration = 2,
					})
					unlockGlider()
				else
					-- a glider part has been collected
					toast:create({
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
				if _helpers.contains(collectedJetpackParts, c.userdata.ID) then
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
					toast:create({
						message = "Jetpack unlocked!",
						center = false,
						iconShape = bundle.Shape("voxels.jetpack"), -- @aduermael to replace with :: bundle.Shape("voxels.jetpack"),
						duration = 2,
					})
					unlockJetpack()
				else
					-- a jetpack part has been collected
					toast:create({
						message = #collectedJetpackParts .. "/" .. #jetpackParts .. " collected",
						iconShape = bundle.Shape("voxels.jetpack_scrap_pile"),
						keepInStack = false,
					})
				end
			end,
		}

		if #collectedGliderParts >= #gliderParts then
			unlockGlider()
			for _, v in pairs(gliderParts) do
				v:RemoveFromParent()
			end
		else
			for k, v in ipairs(gliderParts) do
				if not _helpers.contains(collectedGliderParts, k) then
					local config = conf:merge(gliderPartConfig, { position = v.Position, userdata = { ID = k } })
					collectible:create(config)
				end
				v:RemoveFromParent()
			end
		end

		if #collectedJetpackParts >= #jetpackParts then
			unlockJetpack()
			for _, v in pairs(jetpackParts) do
				v:RemoveFromParent()
			end
		else
			for k, v in ipairs(jetpackParts) do
				if not _helpers.contains(collectedJetpackParts, k) then
					local config = conf:merge(jetpackPartConfig, { position = v.Position, userdata = { ID = k } })
					collectible:create(config)
				end
				v:RemoveFromParent() -- @Buche :: clear placed collectibles if already collected
			end
		end
	end

	local t = {}
	t.get = function()
		local store = KeyValueStore(Player.UserID)
		store:get("collectedGliderParts", "collectedJetpackParts", function(ok, results)
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
				spawnBackpacks()
				spawnCollectibles()
			else
				Timer(REQUEST_FAIL_RETRY_DELAY, t.get)
			end
		end)
	end
	t.get()
end
