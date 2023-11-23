skills = {}

conf = require("config")

stepClimbers = {} -- all objects with step climbing ability

STEP_CLIMBING_DEFAULT_CONFIG = {
	collisionGroups = Map.CollisionGroups,
	mapScale = Map.Scale.Y,
	velocityImpulse = 30,
}

EMPTY_CALLBACK = function() end

STEP_CLIMBING_BASE_OFFSET = Number3(0, 0.1, 0)
STEP_CLIMBING_BOX_HALF_BASE = Number3(0.5, 0, 0.5)

skills.addStepClimbing = function(object, config)
	if object.CollisionBox == nil then
		print("⚠️ can't add step climbing skill if object has no CollisionBox")
		return
	end

	config = conf:merge(STEP_CLIMBING_DEFAULT_CONFIG, config)

	local box = object.CollisionBox
	local min = box.Min
	min.Y = 0
	local max = box.Max
	max.Y = 0

	config.radius = (max - min).Length * 0.5
	config.stepDistance = config.radius + config.mapScale * 0.5 -- object collider radius + half map block
	config.maxDistance = config.stepDistance * 3 -- for ray cast
	config.stepAndAHalf = Number3(0, config.mapScale * 1.5, 0)

	stepClimbers[object] = config or STEP_CLIMBING_DEFAULT_CONFIG
end

skills.removeStepClimbing = function(object)
	stepClimbers[object] = nil
end

LocalEvent:Listen(LocalEvent.Name.Tick, function()
	-- STEP CLIMBERS

	local d
	local impact
	local dist
	local box = Box({ 0, 0, 0 }, { 1, 1, 1 })

	for stepClimber, config in pairs(stepClimbers) do
		d = stepClimber.Motion + stepClimber.Velocity
		d.Y = 0

		box.Min = stepClimber.Position - STEP_CLIMBING_BOX_HALF_BASE + STEP_CLIMBING_BASE_OFFSET
		box.Max = stepClimber.Position + STEP_CLIMBING_BOX_HALF_BASE - STEP_CLIMBING_BASE_OFFSET + config.stepAndAHalf

		impact = box:Cast(d, config.maxDistance, config.collisionGroups)

		dist = config.stepDistance
		if impact and impact.Distance < dist then
			impact = Ray(stepClimber.Position + config.stepAndAHalf, d):Cast(config.collisionGroups)
			if not impact or impact.Distance > dist then
				stepClimber.Velocity.Y = config.velocityImpulse
			end
		end
	end
end)

-- JUMPS

jumpers = {}

skills.jump = function(object)
	local config = jumpers[object]
	if config == nil then
		print("can't jump, no config")
		return
	end
	if object.Velocity.Y <= 0 and isOnGround(object, config) then
		config.airJumpsAvailable = config.airJumps
		object.Velocity.Y = config.jumpVelocity
		config.onJump(object)
	else
		if config.airJumpsAvailable > 0 then
			config.airJumpsAvailable = config.airJumpsAvailable - 1
			local v = math.max(0, object.Velocity.Y)
			v = math.min(config.maxAirJumpVelocity, v + config.jumpVelocity)
			object.Velocity.Y = v
			config.onAirJump(object)
		end
	end
end

skills.addJump = function(object, config)
	local defaultConfig = {
		airJumps = 0, -- no air jumps by default
		maxGroundDistance = 1.0,
		jumpVelocity = 100,
		maxAirJumpVelocity = 150,
		onJump = EMPTY_CALLBACK,
		onAirJump = EMPTY_CALLBACK,
	}
	config = conf:merge(defaultConfig, config)
	config.airJumpsAvailable = config.airJumps
	jumpers[object] = config
end

skills.removeJump = function(object)
	jumpers[object] = nil
end

function isOnGround(object, config)
	if object.CollisionBox == nil then
		return false
	end
	local box = object.CollisionBox:Copy()
	box.Min = object:PositionLocalToWorld(box.Min)
	box.Max = object:PositionLocalToWorld(box.Max)
	local impact = box:Cast(Number3.Down, config.maxGroundDistance, object.CollidesWithGroups)
	return impact ~= nil
end

return skills
