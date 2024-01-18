vfx = {}
vfxQueue = {}

conf = require("config")
ease = require("ease")

LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
	local i = #vfxQueue

	while i > 0 do
		if vfxQueue[i](dt) then
			table.remove(vfxQueue, i)
		end
		i = i - 1
	end
end)

vfx.shake = function(shape, config)
	local defaultConfig = {
		axis = "Z",
		duration = 0.3,
		range = 0.5,
		intensity = 100,
	}
	local _config = conf:merge(defaultConfig, config)

	local initiaAxisPos = shape.Position[_config.axis]
	local t = 0

	local vfxTick = function(dt)
		t = t + dt * _config.intensity
		shape.Position[_config.axis] = shape.Position[_config.axis] + (math.sin(t) * _config.range)
		if t > _config.duration * _config.intensity then
			shape.Position[_config.axis] = initiaAxisPos
			return true
		end
		return false
	end

	table.insert(vfxQueue, vfxTick)
end

vfx.scaleBounce = function(shape, config)
	local defaultConfig = {
		duration = 0.2,
		range = 0.25,
	}
	local _config = conf:merge(defaultConfig, config)

	local initialScale = shape.Scale:Copy()
	ease:outElastic(shape, _config.duration * 0.5, {
		onDone = function()
			ease:outElastic(shape, _config.duration).Scale = initialScale
		end,
	}).Scale = initialScale
		* (1 + _config.range)
end

return vfx
