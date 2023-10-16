cameraModes = {}

-- each entry is a table with:
--[[
{
	config = { camera, target, targetIsPlayer, ... },
	listeners = {},
}
--]]
cameras = {}

function clearListeners(entry)
	if type(entry.listeners) ~= "table" then
		error("camera_modes - internal error (1)")
	end
	for _, listener in ipairs(entry.listeners) do
		listener:Remove()
	end
	entry.listeners = {}
end

function remove(entry)
	clearListeners(entry)
	cameras[entry.config.camera] = nil
end

function insert(config)
	local camera = config.camera
	if type(camera) ~= "Camera" then
		error("camera_modes - internal error (2)")
	end

	local c = cameras[camera]
	if c then
		remove(c)
	end

	camera.Tick = nil

	local entry = {
		config = config,
		listeners = {},
	}
	cameras[camera] = entry

	return entry
end

loadedAvatars = {}
LocalEvent:Listen(LocalEvent.Name.AvatarLoaded, function(p)
	loadedAvatars[p] = true
end)

function showAvatar(entry)
	if not entry.config.targetIsPlayer then
		return
	end

	local player = entry.config.target

	player.Head.IsHidden = false
	player.Head.IsHiddenSelf = false
	player.Body.IsHiddenSelf = false
	player.RightArm.IsHidden = false
	player.LeftArm.IsHidden = false
	player.RightLeg.IsHidden = false
	player.LeftLeg.IsHidden = false
	if player.equipments then
		for _, v in pairs(player.equipments) do
			v.IsHiddenSelf = false
			if v.attachedParts then
				for _, v2 in ipairs(v.attachedParts) do
					v2.IsHiddenSelf = false
				end
			end
		end
	end
end

function hideAvatar(entry)
	if not entry.config.targetIsPlayer then
		return
	end

	local player = entry.config.target

	player.Head.IsHidden = false
	player.Head.IsHiddenSelf = true
	player.Body.IsHiddenSelf = true
	player.RightArm.IsHidden = true
	player.LeftArm.IsHidden = true
	player.RightLeg.IsHidden = true
	player.LeftLeg.IsHidden = true
	if loadedAvatars[player] == true and player.equipments then
		for _, v in pairs(player.equipments) do
			v.IsHiddenSelf = true
			if v.attachedParts then
				for _, v2 in ipairs(v.attachedParts) do
					v2.IsHiddenSelf = true
				end
			end
		end
		return
	end

	local avatarLoadedListener
	avatarLoadedListener = LocalEvent:Listen(LocalEvent.Name.AvatarLoaded, function(p)
		if p ~= player then
			return
		end
		for _, v in pairs(player.equipments) do
			v.IsHiddenSelf = true
			if v.attachedParts then
				for _, v2 in ipairs(v.attachedParts) do
					v2.IsHiddenSelf = true
				end
			end
		end
		avatarLoadedListener:Remove()
	end)
end

function turnOffPhysics(camera)
	camera.Physics = PhysicsMode.Disabled
	camera.CollisionGroups = {}
	camera.CollidesWithGroups = {}
end

cameraModes.setFree = function(self, config)
	if self ~= cameraModes then
		error("camera_modes:setFree(config) should be called with `:`", 2)
	end
	if type(config) ~= "table" then
		error("camera_modes:setFree(config) - config should be a table", 2)
	end

	config = { camera = config.camera or Camera }
	local camera = config.camera

	insert(config)

	turnOffPhysics(config.camera)

	-- `true` parameter allows to maintain the World position
	camera:SetParent(World, true)
end

cameraModes.setSatellite = function(self, config)
	if self ~= cameraModes then
		error("camera_modes:setSatellite(config) should be called with `:`", 2)
	end
	if type(config) ~= "table" then
		error("camera_modes:setSatellite(config) - config should be a table", 2)
	end
	local _config = { -- default config
		camera = Camera, -- main Camera by default
		target = nil, -- must be set
		distance = 30,
	}

	if config then
		local _type
		for k, v in pairs(_config) do
			_type = type(config[k])
			if _type == "number" or _type == "integer" then
				if type(v) == "number" or type(v) == "integer" then
					_config[k] = config[k]
				end
			elseif _type == type(v) then
				_config[k] = config[k]
			end
		end
		_config.target = config.target
	end

	if _config.target == nil then
		error("camera_modes:setSatellite(config) - config.target can't be nil", 2)
	end

	if
		type(_config.target) == "table"
		and type(_config.target[1]) == "number"
		and type(_config.target[2]) == "number"
		and type(_config.target[3]) == "number"
	then
		_config.target = Number3(_config.target)
	end

	config = _config

	local entry = insert(config)

	local camera = config.camera

	turnOffPhysics(camera)
	camera:SetParent(World, true)

	local refresh = function()
		local target = config.target.Position or config.target
		camera.Position = target - camera.Forward * config.distance
	end

	listener = LocalEvent:Listen(LocalEvent.Name.Tick, function()
		refresh()
	end)
	table.insert(entry.listeners, listener)
	refresh()
end

cameraModes.setFirstPerson = function(self, config)
	if self ~= cameraModes then
		error("camera_modes:setFirstPerson(config) should be called with `:`", 2)
	end
	if type(config) ~= "table" then
		error("camera_modes:setFirstPerson(config) - config should be a table", 2)
	end

	local _config = { -- default config
		showPointer = false,
		camera = Camera, -- main Camera by default
		target = nil, -- must be set
	}

	if config then
		for k, v in pairs(_config) do
			if type(config[k]) == type(v) then
				_config[k] = config[k]
			end
		end
		_config.target = config.target
	end

	if _config.target == nil then
		error("camera_modes:setFirstPerson(config) - config.target can't be nil", 2)
	end

	_config.targetIsPlayer = type(_config.target) == "Player"

	config = _config
	local camera = config.camera

	local entry = insert(config)

	turnOffPhysics(camera)

	if config.targetIsPlayer then
		camera:SetParent(config.target.Head)
	else
		camera:SetParent(config.target)
	end

	camera.LocalPosition:Set(0, 0, 0)
	camera.LocalRotation:Set(0, 0, 0)

	if config.showPointer then
		Pointer:Show()
	else
		Pointer:Hide()
	end

	hideAvatar(entry)
end

cameraModes.setThirdPerson = function(self, config)
	if self ~= cameraModes then
		error("camera_modes:setThirdPerson(config) should be called with `:`", 2)
	end

	local _config = { -- default config
		showPointer = true,
		minZoomDistance = 0,
		maxZoomDistance = 75,
		camera = Camera, -- main Camera by default
		target = nil, -- must be set
	}

	if config then
		for k, v in pairs(_config) do
			if type(config[k]) == type(v) then
				_config[k] = config[k]
			end
		end
		_config.target = config.target
	end

	if _config.target == nil then
		error("camera_modes:setThirdPerson(config) - config.target can't be nil", 2)
	end

	_config.targetIsPlayer = type(_config.target) == "Player"

	config = _config

	local entry = insert(config)

	turnOffPhysics(config.camera)

	local camera = config.camera
	local showPointer = config.showPointer
	local minZoomDistance = config.minZoomDistance
	local maxZoomDistance = config.maxZoomDistance
	local target = config.target
	local targetIsPlayer = type(target) == "Player"

	camera:SetParent(World)

	if showPointer then
		Pointer:Show()
	else
		Pointer:Hide()
	end

	local camDistance = 40
	local listener

	listener = LocalEvent:Listen(LocalEvent.Name.PointerWheel, function(delta)
		camDistance = camDistance + delta * 0.1
		if camDistance > maxZoomDistance then
			camDistance = maxZoomDistance
		end
		if camDistance <= minZoomDistance then
			camDistance = minZoomDistance
		end
	end)
	table.insert(entry.listeners, listener)

	listener = LocalEvent:Listen(LocalEvent.Name.Tick, function()
		local currentTarget = target

		local startPosition = currentTarget.Position:Copy()

		if targetIsPlayer then
			camera.Rotation = currentTarget.Head.Rotation
		end

		if targetIsPlayer then
			startPosition.Y = startPosition.Y + currentTarget.CollisionBox.Max.Y * currentTarget.Scale.Y
		end

		local ray = Ray(startPosition, Number3.Up)
		local impact = ray:Cast(Map.CollisionGroups)

		local distance = 3
		if impact.Distance and impact.Distance < distance then
			distance = impact.Distance
		end

		startPosition = startPosition + Number3.Up * distance

		camera.Position = startPosition

		ray = Ray(startPosition, camera.Backward)
		impact = ray:Cast(Map.CollisionGroups)

		if camDistance < 4 then -- in Head, make it invisible
			if targetIsPlayer then
				hideAvatar(entry)
				if target.equipments.hair then
					target.equipments.hair.IsHiddenSelf = true
				end
			end
		else
			if targetIsPlayer then
				showAvatar(entry)
				if target.equipments.hair then
					target.equipments.hair.IsHiddenSelf = false
				end
			end
		end

		distance = camDistance
		if impact and impact.Distance < distance then
			distance = impact.Distance * 0.95
		end

		camera.Position = startPosition + camera.Backward * distance
	end)
	table.insert(entry.listeners, listener)
end

return cameraModes
