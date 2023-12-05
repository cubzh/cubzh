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

	-- JUMPERS

	for jumper, config in pairs(jumpers) do
		if config.airJumped and isOnGround(jumper, config) then
			config.airJumpsAvailable = config.airJumps
			config.airJumped = false
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
			config.airJumped = true
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

COLLISION_BOX_REDUCE_OFFSET = Number3(1, 0, 1)

local isOnGroundBox = Box()
local pts = {}
local minN3 = Number3.Zero
local maxN3 = Number3.Zero
local bMax
local bMin
function isOnGround(object, config)
	if object.CollisionBox == nil then
		return false
	end

	bMax = object.CollisionBox.Max
	bMin = object.CollisionBox.Min

	-- TMP, waiting for object:BoxLocalToWorld
	pts[1] = object:PositionLocalToWorld(bMin)
	pts[2] = object:PositionLocalToWorld({ bMax.X, bMin.Y, bMin.Z })
	pts[3] = object:PositionLocalToWorld({ bMin.X, bMax.Y, bMin.Z })
	pts[4] = object:PositionLocalToWorld({ bMin.X, bMin.Y, bMax.Z })
	pts[5] = object:PositionLocalToWorld({ bMax.X, bMax.Y, bMin.Z })
	pts[6] = object:PositionLocalToWorld({ bMax.X, bMin.Y, bMax.Z })
	pts[7] = object:PositionLocalToWorld({ bMin.X, bMax.Y, bMax.Z })
	pts[8] = object:PositionLocalToWorld(bMax)

	minN3:Set(pts[1])
	minN3.X = math.min(minN3.X, pts[2].X, pts[3].X, pts[4].X, pts[5].X, pts[6].X, pts[7].X, pts[8].X)
	minN3.Y = math.min(minN3.Y, pts[2].Y, pts[3].Y, pts[4].Y, pts[5].Y, pts[6].Y, pts[7].Y, pts[8].Y)
	minN3.Z = math.min(minN3.Z, pts[2].Z, pts[3].Z, pts[4].Z, pts[5].Z, pts[6].Z, pts[7].Z, pts[8].Z)
	maxN3:Set(pts[1])
	maxN3.X = math.max(maxN3.X, pts[2].X, pts[3].X, pts[4].X, pts[5].X, pts[6].X, pts[7].X, pts[8].X)
	maxN3.Y = math.max(maxN3.Y, pts[2].Y, pts[3].Y, pts[4].Y, pts[5].Y, pts[6].Y, pts[7].Y, pts[8].Y)
	maxN3.Z = math.max(maxN3.Z, pts[2].Z, pts[3].Z, pts[4].Z, pts[5].Z, pts[6].Z, pts[7].Z, pts[8].Z)

	isOnGroundBox.Min = minN3 + COLLISION_BOX_REDUCE_OFFSET
	isOnGroundBox.Max = maxN3 - COLLISION_BOX_REDUCE_OFFSET

	local impact = isOnGroundBox:Cast(Number3.Down, config.maxGroundDistance, object.CollidesWithGroups)
	return (impact ~= nil and impact.FaceTouched == Face.Top)
end

return skills
