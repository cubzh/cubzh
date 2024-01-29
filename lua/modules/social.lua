local social = {}

social.enablePlayerClickMenu = function()
	LocalEvent:Listen(LocalEvent.Name.PointerUp, function(pe)
		local impacts = Ray(pe.Position, pe.Direction):Cast(nil, nil, false)
		local player
		for _, impact in ipairs(impacts) do
			if impact.Object and type(impact.Object) == "Player" then
				player = impact.Object
				break
			end
		end
		if player and player ~= Player then
			local radialMenuConfig = {
				target = player,
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
							require("radialmenu").remove()
						end,
					},
					{
						type = "button",
						text = "❌",
						angle = -90,
						radius = 30,
						onRelease = function()
							require("radialmenu").remove()
						end,
					},
				},
			}
			require("radialmenu"):create(radialMenuConfig)
		end
	end)
end

return social
