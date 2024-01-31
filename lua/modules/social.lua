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
		if player and player ~= Player then
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
				offset = { 0, 5, 0 },
				nodes = {
					{
						type = "button",
						text = "🔎",
						angle = 130,
						radius = 45,
						onRelease = function()
							Menu:ShowProfile(player)
							removeMenu()
						end,
					},
					{
						type = "button",
						text = "👕",
						angle = 50,
						radius = 45,
						onRelease = function()
							Menu:ShowOutfits(player)
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
