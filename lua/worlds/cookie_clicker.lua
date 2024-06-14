Config = {
	Map = nil,
	Items = {"aduermael.cookie_no_chips", "aduermael.cookie_chip"}
}

Client.OnStart = function()

    local ui = require("uikit")

    local UI_PADDING = 15

    -- TODO: restore purple ambience

    userStore = KeyValueStore(Player.UserID)
    globalStore = KeyValueStore("global")

	container = Object()
	World:AddChild(container)

    chips = {}

    cookie = MutableShape(Items.aduermael.cookie_no_chips)
	container:AddChild(cookie)

    bubbleHooks = {}
	nextBubbleHook = 1
	for _ = 1, 10 do
		local bubbleHook = Object()
		bubbleHook.Physics = true
		bubbleHook.CollidesWithMask = 0
		bubbleHook.CollisionGroupsMask = 0
		bubbleHook.Acceleration = -Config.ConstantAcceleration
		bubbleHook.Motion.Y = 10
		World:AddChild(bubbleHook)
		table.insert(bubbleHooks, bubbleHook)
	end

	function displayBubble(pos, msg)
		bubbleHooks[nextBubbleHook].Position = pos
		bubbleHooks[nextBubbleHook]:TextBubble(msg, 5, 0)

		nextBubbleHook = nextBubbleHook + 1
		if nextBubbleHook > #bubbleHooks then
			nextBubbleHook = 1
		end
	end

	local max = cookie.BoundingBox.Max
	local margin = 2
	local marginTwice = margin * 2

	for _ = 1, 6 do
		local chip = MutableShape(Items.aduermael.cookie_chip)
		container:AddChild(chip)
		chip.Pivot = {0.5, 0.5, 0.5}
		chip.Position = {(0.5 - math.random()) * (max.X - marginTwice),
						max.Y * 0.5 - 0.5 + math.random() * 0.5,
						(0.5 - math.random()) * (max.Z - marginTwice)}
		chip.Scale = 1.5 + math.random() * 0.5
		chip.Rotation = {math.random() * math.pi * 2.0, math.random() * math.pi * 2.0, 0.0}
		table.insert(chips, chip)
	end

	Camera:SetModeSatellite(container.Position, 20)
	cameraBaseRotation = Number3(0.8, 0, 0)
	Camera.Rotation = cameraBaseRotation

	Pointer:Show()

	UI.Crosshair = false

	totalDT = 0.0

	count = 0

	-- UI
	-- countLabel = Label("" .. math.floor(count), Anchor.Top, Anchor.HCenter)
    countLabel = ui:createText("" .. math.floor(count), Color.White)
    countLabel.parentDidResize = function(self)
        self.pos = {
            Screen.Width * 0.5 - self.Width * 0.5,
            Screen.Height - (UI_PADDING * 3) - self.Height,
        }
    end

	bestCount = 0
	-- bestLabel = Label("Best: 0 ()", Anchor.Bottom, Anchor.Right)
    bestLabel = ui:createText("Best: 0 ()", Color.White)
    bestLabel.parentDidResize = function(self)
        self.pos = {
            UI_PADDING,
            UI_PADDING,
        }
    end

    userStore:get("count", function (ok, res)
        if ok then
            if res.count ~= nil then
                count = res.count
                countLabel.Text = "" .. math.floor(count)
            end
        else
            -- TODO: display error?
        end
    end)

    globalStore:get("bestCount", "bestUsername", function(ok, res)
        if ok then
            if res.bestCount ~= nil then
                bestCount = res.bestCount
                bestLabel.Text = "Best: " .. math.floor(bestCount) .. " (".. res.bestUsername ..")"
            end
        else
            -- TODO: display error?
        end
    end)

end

Pointer.Down = function(e)

	 -- this can also be done using a Ray object:
    local ray = Ray(e.Position, e.Direction)

	local impacts = {}

	local impact = ray:Cast(cookie)
	if impact ~= nil then
		table.insert(impacts, {impact = impact, object = cookie, isChip = false})
	end

	for _, chip in ipairs(chips) do
		local impact = ray:Cast(chip)
		if impact ~= nil then
			-- print("chip")
			table.insert(impacts, {impact = impact, object = chip, isChip = true})
		end
	end

	local closestImpact = nil

	for _, impact in ipairs(impacts) do
		if closestImpact == nil then
			closestImpact = impact
		else
			if impact.impact.Distance < closestImpact.impact.Distance then
				closestImpact = impact
			end
		end
	end

    if closestImpact ~= nil then

		local pos = e.Position + e.Direction * closestImpact.impact.Distance

        local add = 0

		if closestImpact.isChip then
			closestImpact.object.Physics = true
			closestImpact.object.Velocity = {(0.5 - math.random()) * 40,
											50,
											(0.5 - math.random()) * 40}
			closestImpact.object.CollidesWithGroups = {}
			closestImpact.object.CollisionGroups = {}

			add = 2
		else
			add = 1
		end

		displayBubble(pos, "+" .. add)

		count = count + add
		countLabel.Text = "" .. math.floor(count)

        -- TODO: add a timer to throttle KVS set operations
        userStore:set("count", count, function (_) end)

		if bestCount ~= nil and count > bestCount then
			bestCount = count
			bestLabel.Text = "Best: " .. math.floor(count) .. " (" .. Player.Username .. ")"

            -- TODO: add a timer to throttle KVS set operations
            globalStore:set("bestCount", bestCount, "bestUsername", Player.Username, function (ok)
                -- print("SET BEST:", ok)
            end)
		end

    end

end

Client.Tick = function(dt)
    totalDT = totalDT + dt
	container.Rotation = Number3(math.sin(totalDT), math.sin(totalDT * 1.3), 0) * 0.2
end

Client.DirectionalPad = nil
