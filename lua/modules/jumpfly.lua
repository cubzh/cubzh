--- This module implements jump and fly for the player.
--- To enable and disable the fly mode, double tap on Space

local jumpfly = {}

local config = {
	jumpVelocity = 100,
	holdTimeToFly = 0.5,
	exitFlyDoubleTapDelay = 0.5,
	airJumps = -1, -- -1 for infinite
}

local flying = false
local holdTimer = nil
local exitFlyDoubleTapTimer = nil
local jumps = 0

-- local backpack = Object:Load("backpack")

Client.Action1 = function()
	if flying then
		if exitFlyDoubleTapTimer ~= nil then
			exitFlyDoubleTapTimer:Cancel()
			exitFlyDoubleTapTimer = nil
			flying = false
			Player.Acceleration:Set(0, 0, 0)
		else
			exitFlyDoubleTapTimer = Timer(config.exitFlyDoubleTapDelay, function()
				exitFlyDoubleTapTimer = nil
			end)
		end
	else
		if config.airJumps < 0 then -- infinite air jumps
			Player.Velocity.Y = config.jumpVelocity
		else
			if Player.IsOnGround then
				jumps = 1
				Player.Velocity.Y = config.jumpVelocity
			else
				if jumps < config.airJumps + 1 then
					jumps += 1
					Player.Velocity.Y = config.jumpVelocity
				end
			end
		end

		holdTimer = Timer(config.holdTimeToFly, function()
			flying = true
			Player.Velocity.Y = 0
			Player.Acceleration = -Config.ConstantAcceleration
			holdTimer = nil
		end)
	end
end

Client.Action1Release = function()
	if holdTimer then
		holdTimer:Cancel()
		holdTimer = nil
	end
end

return jumpfly
