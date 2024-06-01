--- This module implements jump and fly for the player.
--- To enable and disable the fly mode, double tap on Space
--- TODO: handle mobile Action1

local jumpfly = {
	TIME_BETWEEN_JUMP = 300,
}

local latestJump = 0
local flying = false
local holdingSpace = false

LocalEvent:Listen(LocalEvent.Name.Tick, function()
	if flying then
		Player.Animations.Walk:Stop()
		Player.Animations.Idle:Play()
		Player.Velocity.Y = 3.8 * (holdingSpace and 10 or 1)
	end
end)

local codes = require("inputcodes")
LocalEvent:Listen(LocalEvent.Name.KeyboardInput, function(_, keycode, _, down)
	if not down and keycode == codes.SPACE then
		holdingSpace = false
		return
	end

	if down and keycode == codes.SPACE then
		holdingSpace = true
		if not flying then
			latestJump = Time.UnixMilli()
			-- if Player.IsOnGround then
			Player.Velocity.Y = 100
			-- elseif latestJump > Time.UnixMilli() - jumpfly.TIME_BETWEEN_JUMP then
			-- activate
			--TODO: handle multiplayer
			-- flying = true
			-- end
		else
			if latestJump > Time.UnixMilli() - jumpfly.TIME_BETWEEN_JUMP then
				-- deactivate
				flying = false
			end
			latestJump = Time.UnixMilli()
		end
	end
end)

if Client.IsMobile then
	Client.Action1 = function()
		Player.Velocity.Y = 100
	end
end

return jumpfly
