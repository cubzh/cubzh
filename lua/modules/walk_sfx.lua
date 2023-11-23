--- This can be used to play walk sound effect for any Object with Motion.

walkSFX = {}

sfx = require("sfx")

DEFAULT_CONFIG = {
	colors = {
		wood = Color.Brown,
		concrete = Color.Grey,
		sand = Color(221, 209, 83),
		grass = Color(64, 155, 69),
	},
	stepDelay = 0.3,
	volume = 0.3,
}

objects = {} -- configs, indexed by object ref

local motion = Number3.Zero
LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
	for object, config in pairs(objects) do
		motion:Set(object.Motion.X, 0, object.Motion.Z)
		if object.Motion.SquaredLength > 0 and object.IsOnGround then
			config.t = config.t + dt
			if config.t > config.stepDelay then
				config.t = config.t % config.stepDelay

				local impact = Ray(Player.Position + { 0, 0.1, 0 }, { 0, -1, 0 }):Cast(object.CollidesWithGroups)
				local block = impact.Block

				if block == nil then
					return
				end

				local color = block.Color
				local colorN3 = Number3(color.R, color.G, color.B)
				colorN3:Normalize()

				local surfaceName = "grass"

				local dot = -1

				local d
				for surface, vector in pairs(config.colorsN3) do
					d = colorN3:Dot(vector)
					if d > dot then
						surfaceName = surface
						dot = d
					end
				end

				local fileNum = math.random(5)
				sfx("walk_" .. surfaceName .. "_" .. fileNum, { Position = object.Position, Volume = config.volume })
			end
		elseif config.t > 0 then
			config.t = config.stepDelay -- to play step as soon as walk resumes
		end
	end
end)

walkSFX.register = function(_, object, config)
	if object.Motion == nil then
		error("walkSFX: only Objects with Motion can be registered")
	end

	local conf = require("config")

	config = conf:merge(DEFAULT_CONFIG, config)

	config.colorsN3 = {}
	for name, color in pairs(config.colors) do
		config.colorsN3[name] = Number3(color.R, color.G, color.B):Normalize()
	end

	config.t = 0.0

	objects[object] = config
end

walkSFX.unregister = function(_, object)
	objects[object] = nil
end

return walkSFX
