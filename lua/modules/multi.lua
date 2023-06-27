-- WORLK IN PROGRESS
-- This module helps implementing efficient
-- multiplayer sync depending on use cases.

-- So far, only synchronizes players.

---------------
-- CONSTANTS --
---------------

local SYNC_DELAY = 100 -- sync every 100ms
local SYNC_DELAY_FORCED = 500 -- force sync even if nothing moved
local SMOOTH_TIME = 80

-- event keys
local KEY_MULTI = "mt" -- key to identify events from this module
local KEY_ACTION = "a"
local KEY_POSITION = "p"
local KEY_ROTATION = "r"
local KEY_MOTION = "m"
local KEY_VELOCITY = "v"
local KEY_PLAYER_ACTION = "pa"
local KEY_PLAYER_ACTION_USERDATA = "pu"

local ACTION = {
	SYNC = 1,
	PLAYER_ACTION = 2,
}

---------------
-- VARIABLES --
---------------

local syncDT = 0
local playerActionCallbacks = {}
local teleportTriggerDistance = 0
local sqrTeleportTriggerDistance = teleportTriggerDistance * teleportTriggerDistance

local multi = {}

-- syncs local Player information
multi.sync = function(self, force)

	if not force and
		Player.sentMotion ~= nil and Player.sentMotion == Player.Motion and
		Player.sentRotation ~= nil and bRot == Player.Rotation then
		return false
	end

	local e = Event()
	e[KEY_MULTI] = 1
	e[KEY_ACTION] = ACTION.SYNC
	e[KEY_POSITION] = Player.Position
	e[KEY_ROTATION] = Player.Rotation
	e[KEY_MOTION] = Player.Motion
	e[KEY_VELOCITY] = Player.Velocity
	e:SendTo(OtherPlayers)

	Player.sentMotion = Player.Motion:Copy()
	Player.sentRotation = Player.Rotation:Copy()

	return true
end

-- calback receives sender + metadata (optional)
multi.onAction = function(self, name, callback)
	playerActionCallbacks[name] = callback
end
multi.registerPlayerAction = multi.onAction

multi.action = function(self, name, data)
	local e = Event()
	e[KEY_MULTI] = 1
	e[KEY_ACTION] = ACTION.PLAYER_ACTION
	e[KEY_PLAYER_ACTION] = name
	if data ~= nil then
	   e[KEY_PLAYER_ACTION_USERDATA] = JSON:Encode(data)
	end
	e:SendTo(OtherPlayers)
end
multi.playerAction = multi.action -- legacy name

local initPlayer = function(player)
	if player == Player then return end

	local o = Object()
	local box = player.CollisionBox:Copy()
	box.Max = box.Max * player.Scale.X
	box.Min = box.Min * player.Scale.X

	local center = box.Center:Copy()
	center.Y = 0
	box.Min = box.Min - center
	box.Max = box.Max - center

	o.CollisionBox = box

	World:AddChild(o)
	o.Physics = true
	o.CollisionGroups = player.CollisionGroups
	o.CollidesWithGroups = player.CollidesWithGroups
	o.Bounciness = player.Bounciness
	o.Friction = player.Friction

	player.Physics = false
	player.CollisionGroups = {}
	player.CollidesWithGroups = {}

	o:AddChild(player)
	player.parentBox = o
end

local removePlayer = function(player)
	if player == Player then return end
	if player.parentBox ~= nil then
		player.parentBox:RemoveFromParent()
	end
end

local receive = function(e)

	if e[KEY_MULTI] ~= 1 then return end -- event not handled by module


	if e[KEY_ACTION] == ACTION.SYNC then

		if e.Sender.multi == nil then e.Sender.multi = {} end
		if e.Sender.parentBox == nil then 
			return
		end

		local newPos = e[KEY_POSITION]

		e.Sender.multi.delta = e.Sender.Position:Copy() - newPos:Copy()
		e.Sender.multi.dt = 0

		e.Sender.multi.rotStart = e.Sender.Rotation:Copy()
		e.Sender.multi.rotDelta = e[KEY_ROTATION] - e.Sender.Rotation

		while e.Sender.multi.rotDelta.X > math.pi do
			e.Sender.multi.rotDelta.X = e.Sender.multi.rotDelta.X - math.pi * 2
		end
		while e.Sender.multi.rotDelta.X < -math.pi do
			e.Sender.multi.rotDelta.X = e.Sender.multi.rotDelta.X + math.pi * 2
		end
		while e.Sender.multi.rotDelta.Y > math.pi do
			e.Sender.multi.rotDelta.Y = e.Sender.multi.rotDelta.Y - math.pi * 2
		end
		while e.Sender.multi.rotDelta.Y < -math.pi do
			e.Sender.multi.rotDelta.Y = e.Sender.multi.rotDelta.Y + math.pi * 2
		end

		e.Sender.parentBox.Position = newPos -- go there right away
		e.Sender.parentBox.Motion = e[KEY_MOTION]
		e.Sender.parentBox.Velocity = e[KEY_VELOCITY]
		e.Sender.parentBox.Rotation.Y = e[KEY_ROTATION].Y

		if teleportTriggerDistance > 0 and e.Sender.multi.delta.SquaredLength >= sqrTeleportTriggerDistance then
			e.Sender.Position = newPos
			e.Sender.multi.delta = nil
		else
			e.Sender.Position = e.Sender.parentBox.Position + e.Sender.multi.delta
		end

		e.Sender.Motion = e[KEY_MOTION]

	elseif e[KEY_ACTION] == ACTION.PLAYER_ACTION then

		local callback = playerActionCallbacks[e[KEY_PLAYER_ACTION]]
		if callback ~= nil then
            local data = e[KEY_PLAYER_ACTION_USERDATA]
            if data ~= nil then
                data = JSON:Decode(data)
            end
			callback(e.Sender, data)
		end
	end
end

local tick = function(dt)
	local msDT = math.floor(dt * 1000)
	syncDT = syncDT + msDT
	if syncDT >= SYNC_DELAY then
		if multi:sync(syncDT >= SYNC_DELAY_FORCED) then
			syncDT = syncDT % SYNC_DELAY
		end
	end

	-- apply smoothing deltas
	for _, p in pairs(Players) do
		if p == Player then goto continue end

		if p.multi.dt ~= nil and p.multi.dt < SMOOTH_TIME then
			p.multi.dt = p.multi.dt + msDT
			if p.multi.dt > SMOOTH_TIME then p.multi.dt = SMOOTH_TIME end
			
			if p.multi.delta then
				p.Position = p.parentBox.Position + p.multi.delta * (1.0 - (p.multi.dt / SMOOTH_TIME))
			end

			p.Rotation = p.multi.rotStart + p.multi.rotDelta * (p.multi.dt / SMOOTH_TIME)
		end
		::continue::
	end
end

LocalEvent:Listen(LocalEvent.Name.Tick, function(dt) tick(dt) end)
LocalEvent:Listen(LocalEvent.Name.OnPlayerJoin, function(p) initPlayer(p) end)
LocalEvent:Listen(LocalEvent.Name.OnPlayerLeave, function(p) removePlayer(p) end)
LocalEvent:Listen(LocalEvent.Name.DidReceiveEvent, function(e) receive(e) end)

----------------
-- DEPRECATED --
----------------

local function deprecateFunction(name)
	local displayed = false
	multi[name] = function()
		if not displayed then
			print("⚠️ multi." .. name .. " is deprecated, no need to call it anymore!")
			displayed = true
		end
	end
end

deprecateFunction("initPlayer")
deprecateFunction("removePlayer")
deprecateFunction("receive")
deprecateFunction("tick")

return multi
