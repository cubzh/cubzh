local social = {}

social.enablePlayerClickMenu = function()
	LocalEvent:Listen(LocalEvent.Name.PointerClick, function(pe)
		local impacts = Ray(pe.Position, pe.Direction):Cast(nil, nil, false)
		local player
		for _, impact in ipairs(impacts) do
			if impact.Object and type(impact.Object) == "Player" then
				player = impact.Object
				break
			end
		end
		if player then -- and player ~= Player then
			local handleWasShown = false
			if player.IsHandleShown then
				handleWasShown = true
				player:HideHandle()
			end

			local removeMenu = function()
				if handleWasShown then
					player:ShowHandle()
				end
				require("radialmenu").remove()
			end

			local radialMenuConfig = {
				target = player.Head,
				offset = { 0, 10, 0 },
				nodes = {
					{
						type = "button",
						text = "👤 Profile",
						angle = 90,
						radius = 30,
						onRelease = function()
							require("profile"):create({
								username = player.Username,
								userID = player.UserID,
								uikit = require("uikit"),
								minimizedModal = true,
							})
							removeMenu()
						end,
					},
					{
						type = "button",
						text = "❌",
						angle = -90,
						radius = 30,
						onRelease = function()
							removeMenu()
						end,
					},
				},
			}
			require("radialmenu"):create(radialMenuConfig)
			return true -- capture click
		end
	end)
end

return social
