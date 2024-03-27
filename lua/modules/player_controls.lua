mod = {}

defaultConfig = {
	firstPerson = false, -- third person by default
	rotatePlayerWithCamera = false,
	faceMotionDirection = true,
	rotationSpeed = math.rad(180), -- 180° per second
	showPointer = true, -- shows pointer on PC
	target = nil, -- targets Player by default
}

local currentConfig = nil

local dragListener

mod.set = function(self, config)
	if self ~= mod then
		error("player_controls:set(config) should be called with `:`", 2)
	end

	local conf = require("config")
	currentConfig = conf:merge(defaultConfig, config)

	dragListener = LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pointerEvent) end)
end

mod.unset = function(self)
	if self ~= mod then
		error("player_controls:unset() should be called with `:`", 2)
	end
end

mod.aim = function(self) end

return mod
