
skills = {}

stepClimbers = {} -- all objects with step climbing ability

STEP_CLIMBING_DEFAULT_CONFIG = {
	collisionGroups = Map.CollisionGroups,
	mapScale = Map.Scale.Y,
	velocityImpulse = 30,
}

STEP_CLIMBING_BASE_OFFSET = Number3(0,0.1,0)
STEP_CLIMBING_BOX_HALF_BASE = Number3(0.5, 0, 0.5)

skills.addStepClimbing = function(object, config)

	if object.CollisionBox == nil then
		print("⚠️ can't add step climbing skill if object has no CollisionBox")
		return
	end

	local config = config or {}
	
	for name, value in pairs(STEP_CLIMBING_DEFAULT_CONFIG) do
		if config[name] == nil then config[name] = STEP_CLIMBING_DEFAULT_CONFIG[name] end
	end

	local box = object.CollisionBox
	local min = box.Min
	min.Y = 0
	local max = box.Max
	max.Y = 0

	config.radius = (max - min).Length * 0.5
	config.stepDistance = config.radius + config.mapScale * 0.5 -- object collider radius + half map block
	config.maxDistance = config.stepDistance * 3 -- for ray cast
	config.stepAndAHalf = Number3(0,config.mapScale * 1.5,0)

	stepClimbers[object] = config or STEP_CLIMBING_DEFAULT_CONFIG
end

skills.removeStepClimbing = function(object)
	stepClimbers[object] = nil
end

LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)

	-- STEP CLIMBERS

	local d
	local impact
	local dist
	local box = Box({0,0,0}, {1,1,1})

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

return skills

