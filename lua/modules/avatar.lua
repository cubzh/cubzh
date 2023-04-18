local avatar = {}
local avatarMetatable = {
    __index = {
        eyesColors = { Color(166, 142, 163), Color(68, 172,229), Color(61, 204,141), Color(127, 80,51), Color(51, 38,29), Color(229, 114,189) },
        skinColors = {
        	{skin1=Color(246, 227, 208), skin2=Color(246, 216, 186), nose=Color(246, 210, 175), mouth=Color(220, 188, 157)},
        	{skin1=Color(252, 202, 156), skin2=Color(252, 186, 129), nose=Color(249, 167, 117), mouth=Color(216, 162, 116)},
			{skin1=Color(255, 194, 173), skin2=Color(255, 178, 152), nose=Color(255, 162, 133), mouth=Color(217, 159, 140)},
			{skin1=Color(182, 129, 108), skin2=Color(183, 117, 94), nose=Color(189, 114, 80), mouth=Color(153, 102, 79)},
			{skin1=Color(156, 92, 88), skin2=Color(136, 76, 76), nose=Color(135, 64, 68), mouth=Color(109, 63, 61)},
			{skin1=Color(140, 96, 64), skin2=Color(124, 82, 52), nose=Color(119, 76, 45), mouth=Color(104, 68, 43)},
			{skin1=Color(59, 46, 37), skin2=Color(53, 41, 33), nose=Color(47, 33, 25), mouth=Color(47, 36, 29)}
        },
        setEyesColor = function(self, player, c)
            local head = player.Head
            head.Palette[6].Color = c
            head.Palette[8].Color = c
            head.Palette[8].Color:ApplyBrightnessDiff(-0.15)
        end,
        getEyesColor = function(self, player)
        	return player.Head.Palette[6].Color
        end,
        setSkinColor = function(self, player, skin1, skin2, nose, mouth)
            local bodyParts = { "Head", "Body", "RightArm", "RightHand", "LeftArm", "LeftHand", "RightLeg", "LeftLeg", "RightFoot", "LeftFoot" }
            for _,name in ipairs(bodyParts) do
                local skin1key = 1
                if name == "LeftHand" or name == "Body" or name == "RightArm" then skin1key = 2 end
                if player[name].Palette[skin1key] then
                    player[name].Palette[skin1key].Color = skin1
                end
        
                if name ~= "Body" then
                    local skin2key = 2
                    if name == "LeftHand" or name == "RightArm" then skin2key = 1 end
                    if player[name].Palette[skin2key] then
                        player[name].Palette[skin2key].Color = skin2
                    end
                end
            end
            self:setNoseColor(player, nose)
            self:setMouthColor(player, mouth)
        end,
        getNoseColor = function(self, player)
        	return player.Head.Palette[7].Color
        end,
        setNoseColor = function(self, player, color)
            if not color or type(color) ~= "Color" then
                print("Error: setNoseColor second argument must be of type Color.")
                return
            end
            player.Head.Palette[7].Color = color
        end,
        getMouthColor = function(self, player)
        	return player.Head.Palette[4].Color
        end,
        setMouthColor = function(self, player, color)
            if not color or type(color) ~= "Color" then
                print("Error: setMouthColor second argument must be of type Color.")
                return
            end
            player.Head.Palette[4].Color = color
        end
    }
}
setmetatable(avatar, avatarMetatable)

return avatar