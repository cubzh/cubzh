mod = {}

controls = require("controls")

defaultConfig = {
	firstPerson = false, -- third person by default
	rotatePlayerWithCamera = false,
	faceMotionDirection = true,
	rotationSpeed = math.rad(180), -- 180° per second
	showPointer = true, -- shows pointer on PC
	target = nil, -- targets Player by default
	targetSpeed = 50,
	targetAlignYawWithCameraWhenMotionIsSet = true,
	offset = nil, -- offset from target, added to target to define real target position
	-- moving away from target position if possible, considering collisions
	-- applied before moving backward to get final camera position
	dynamicOffset = nil,
	camera = Camera,
	cameraRigidity = 0.5,
	cameraRotation = nil,
	cameraMinDistance = 20,
	cameraMaxDistance = 75,
	cameraDistance = 40,
	cameraColliders = CollisionGroups(1),
	cameraSoftColliders = nil,
	cameraOnSoftCollisionBegin = nil,
	cameraOnSoftCollisionEnd = nil,
	cameraRotationSensitivity = 1.0,
}

cameraWorldObject = Object() -- object in World used to compute camera position and orientation
cameraWorldObject:SetParent(World)

local currentConfig = nil

dragListener = nil
tickListener = nil
dirpadListener = nil
pointerWheelListener = nil

function removeListeners()
	if dragListener ~= nil then
		dragListener:Remove()
		dragListener = nil
	end
	if tickListener ~= nil then
		tickListener:Remove()
		tickListener = nil
	end
	if dirpadListener ~= nil then
		dirpadListener:Remove()
		dirpadListener = nil
	end
	if pointerWheelListener ~= nil then
		pointerWheelListener:Remove()
		pointerWheelListener = nil
	end
end

mod.set = function(self, config)
	if self ~= mod then
		error("ccc:set(config) should be called with `:`", 2)
	end

	local ok, err = pcall(function()
		currentConfig = require("config"):merge(defaultConfig, config, {
			acceptTypes = {
				target = { "Object", "Shape", "MutableShape", "Number3", "Player" },
				offset = { "Number3" },
				dynamicOffset = { "Number3" },
				cameraRotation = { "Rotation", "Number3", "table" },
				cameraColliders = { "CollisionGroups", "table" },
				cameraSoftColliders = { "CollisionGroups", "table" },
				cameraOnSoftCollisionBegin = { "function" },
				cameraOnSoftCollisionEnd = { "function" },
			},
		})
	end)

	if not ok then
		error(err, 2)
	end

	removeListeners()

	if currentConfig.cameraRotation then
		if not pcall(function()
			cameraWorldObject.Rotation:Set(config.cameraRotation)
		end) then
			error("can't set camera rotation", 2)
		end
	end

	local offset = currentConfig.offset or Number3.Zero
	local target = currentConfig.target

	local targetIsPlayer = type(target) == "Player"
	-- local targetHasRotation = type(target) == "Object" or type(target) == "Shape" or type(target) == "MutableShape"

	if type(target) == "Number3" then
		target = { Position = target }
	end

	local camera = currentConfig.camera
	local thirdPerson = currentConfig.firstPerson == false

	local colliders = currentConfig.cameraColliders

	local boxHalfSize = Number3(1, 1, 1)
	local box = Box()

	local rigidityFactor = currentConfig.cameraRigidity * 60.0

	local camDistance = currentConfig.cameraDistance

	local impact
	local distance
	local dpad

	camera:SetParent(World)

	pointerWheelListener = LocalEvent:Listen(LocalEvent.Name.PointerWheel, function(delta)
		camDistance = camDistance + delta * 0.1
		camDistance = math.max(currentConfig.cameraMinDistance, camDistance)
		camDistance = math.min(currentConfig.cameraMaxDistance, camDistance)
	end)

	dragListener = LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pe)
		cameraWorldObject.Rotation.Y = cameraWorldObject.Rotation.Y + pe.DX * 0.01
		cameraWorldObject.Rotation.X = cameraWorldObject.Rotation.X - pe.DY * 0.01

		if target.Motion.SquaredLength > 0 then -- if target has motion
			dpad = controls.DirectionalPadValues

			-- target.Rotation:Set(0, cameraWorldObject.Rotation.Y, 0)
			-- target.Motion = (target.Forward * dpad.Y + target.Right * dpad.X) * currentConfig.targetSpeed

			local v = Number2(dpad.X, dpad.Y)
			if v.SquaredLength > 0 then
				local yDelta = math.atan(dpad.X, dpad.Y)
				target.Rotation:Set(0, cameraWorldObject.Rotation.Y + yDelta, 0)
				target.Motion:Set(target.Forward * v.Length * currentConfig.targetSpeed)
			end
		end
	end)

	dirpadListener = LocalEvent:Listen(LocalEvent.Name.DirPad, function(x, y)
		pcall(function()
			-- TODO: make this "strafe" mode
			-- if Number2(x, y).SquaredLength > 0 then
			-- 	if currentConfig.targetAlignYawWithCameraWhenMotionIsSet then
			-- 		target.Rotation:Set(0, cameraWorldObject.Rotation.Y, 0)
			-- 	end
			-- end
			-- target.Motion = (target.Forward * y + target.Right * x) * currentConfig.targetSpeed

			local v = Number2(x, y)
			if v.SquaredLength > 0 then
				local yDelta = math.atan(x, y)
				target.Rotation:Set(0, cameraWorldObject.Rotation.Y + yDelta, 0)
				target.Motion:Set(target.Forward * v.Length * currentConfig.targetSpeed)
			else
				target.Motion:Set(Number3.Zero)
			end
		end)
	end)

	tickListener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
		if thirdPerson then
			cameraWorldObject.Position:Set(target.Position + offset)

			if targetIsPlayer then
				cameraWorldObject.Position.Y = cameraWorldObject.Position.Y + target.CollisionBox.Max.Y * target.Scale.Y
			end

			box.Min = cameraWorldObject.Position - boxHalfSize -- box.Min:Set doesn't work
			box.Max = cameraWorldObject.Position + boxHalfSize -- box.Max:Set doesn't work

			-- dynamic offset

			impact = box:Cast(Number3.Up, 3, colliders)

			distance = 3
			if impact and impact.Distance < distance then
				distance = impact.Distance
			end

			cameraWorldObject.Position = cameraWorldObject.Position + Number3.Up * distance

			box.Min = cameraWorldObject.Position - boxHalfSize -- box.Min:Set doesn't work
			box.Max = cameraWorldObject.Position + boxHalfSize -- box.Max:Set doesn't work

			impact = box:Cast(camera.Backward, camDistance, colliders)

			distance = camDistance
			if impact and impact.Distance < distance then
				distance = impact.Distance * 0.95
			end

			lerpFactor = math.min(rigidityFactor * dt, 1.0)
			camera.Position:Lerp(
				camera.Position,
				cameraWorldObject.Position + cameraWorldObject.Backward * distance,
				lerpFactor
			)
			camera.Rotation:Slerp(camera.Rotation, cameraWorldObject.Rotation, lerpFactor)
		end
	end)
end

mod.unset = function(self)
	if self ~= mod then
		error("ccc:unset() should be called with `:`", 2)
	end

	removeListeners()
end

mod.aim = function(self) end

return mod
