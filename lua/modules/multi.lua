-- WORLK IN PROGRESS
-- This module helps implementing efficient
-- multiplayer sync depending on use cases.

-- So far, only synchronizes players.

-- all times in ms
local multi = {
	-- CONSTANTS
	kSyncDelay = 100, -- sync every 100ms
	kSyncDelayForced = 500, -- force sync even if nothing moved
	kSmoothTime = 80, 

	KEY = {
		MULTI = "mt", -- key to identify events from this module
		ACTION = "a",
		POSITION = "p",
		ROTATION = "r",
		MOTION = "m",
		VELOCITY = "v",
		PLAYER_ACTION = "pa",
		PLAYER_ACTION_USERDATA = "pu",
	},

	ACTION = {
		SYNC = 1,
		PLAYER_ACTION = 2,
	},

	-- VARIABLES
	syncDT = 0,
	playerActionCallbacks = {},
	teleportTriggerDistance = 0,
}

-- syncs local Player information
multi.sync = function(self, force)

	if not force and
		Player.sentMotion ~= nil and Player.sentMotion == Player.Motion and
		Player.sentRotation ~= nil and bRot == Player.Rotation then
		return false
	end

	local e = Event()
	e[self.KEY.MULTI] = 1
	e[self.KEY.ACTION] = self.ACTION.SYNC
	e[self.KEY.POSITION] = Player.Position
	e[self.KEY.ROTATION] = Player.Rotation
	e[self.KEY.MOTION] = Player.Motion
	e[self.KEY.VELOCITY] = Player.Velocity
	e:SendTo(OtherPlayers)

	Player.sentMotion = Player.Motion:Copy()
	Player.sentRotation = Player.Rotation:Copy()

	return true
end

-- calback receives sender + metadata (optional)
multi.registerPlayerAction = function(self, name, callback)
	self.playerActionCallbacks[name] = callback
end

multi.playerAction = function(self, name, data)
	local e = Event()
	e[self.KEY.MULTI] = 1
	e[self.KEY.ACTION] = self.ACTION.PLAYER_ACTION
	e[self.KEY.PLAYER_ACTION] = name
	if data ~= nil then
	   e[self.KEY.PLAYER_ACTION_USERDATA] = JSON:Encode(data)
	end
	e:SendTo(OtherPlayers)
end

multi.initPlayer = function(self, player)
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

multi.removePlayer = function(self, player)
	if player == Player then return end

	if player.parentBox ~= nil then
		player.parentBox:RemoveFromParent()
	end
end

multi.receive = function(self, e)

	if e[self.KEY.MULTI] ~= 1 then return end -- event not handled by module


	if e[self.KEY.ACTION] == self.ACTION.SYNC then

		if e.Sender.multi == nil then e.Sender.multi = {} end
		if e.Sender.parentBox == nil then 
			return
		end

		local newPos = e[self.KEY.POSITION]

		e.Sender.multi.delta = e.Sender.Position:Copy() - newPos:Copy()
		e.Sender.multi.dt = 0

		e.Sender.multi.rotStart = e.Sender.Rotation:Copy()
		e.Sender.multi.rotDelta = e[self.KEY.ROTATION] - e.Sender.Rotation

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
		e.Sender.parentBox.Motion = e[self.KEY.MOTION]
		e.Sender.parentBox.Velocity = e[self.KEY.VELOCITY]
		e.Sender.parentBox.Rotation.Y = e[self.KEY.ROTATION].Y

		if self.teleportTriggerDistance > 0 and e.Sender.multi.delta.SquaredLength >= self.teleportTriggerDistance * self.teleportTriggerDistance then
			e.Sender.Position = newPos
			e.Sender.multi.delta = nil
		else
			e.Sender.Position = e.Sender.parentBox.Position + e.Sender.multi.delta
		end

		e.Sender.Motion = e[self.KEY.MOTION]

	elseif e[self.KEY.ACTION] == self.ACTION.PLAYER_ACTION then

		local callback = self.playerActionCallbacks[e[self.KEY.PLAYER_ACTION]]
		if callback ~= nil then
            local data = e[self.KEY.PLAYER_ACTION_USERDATA]
            if data ~= nil then
                data = JSON:Decode(data)
            end
			callback(e.Sender, data)
		end
	end
end

multi.tick = function(self, dt)
	
	local msDT = math.floor(dt * 1000)
	self.syncDT = self.syncDT + msDT
	if self.syncDT >= self.kSyncDelay then
		if self:sync(self.syncDT >= self.kSyncDelayForced) then
			self.syncDT = self.syncDT % self.kSyncDelay
		end
	end

	-- apply smoothing deltas
	for _, p in pairs(Players) do
		if p == Player then goto continue end

		if p.multi.dt ~= nil and p.multi.dt < self.kSmoothTime then
			p.multi.dt = p.multi.dt + msDT
			if p.multi.dt > self.kSmoothTime then p.multi.dt = self.kSmoothTime end
			
			if p.multi.delta then
				p.Position = p.parentBox.Position + p.multi.delta * (1.0 - (p.multi.dt / self.kSmoothTime))
			end

			p.Rotation = p.multi.rotStart + p.multi.rotDelta * (p.multi.dt / self.kSmoothTime)
		end
		::continue::
	end
end

return multi
