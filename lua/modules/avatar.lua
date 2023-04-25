--- This module allows you to change the colors of an avatar.
---@code avatar = require("avatar")
--- local newEyesColor = Color(200, 0, 0)
---
--- -- changes the eyes' color to red
--- avatar:setEyesColor(Player, newEyesColor)
---
--- -- other colors are available:
--- local c = avatar.eyesColors[1]
---
--- -- sets of color are also available:
--- local set = skinColors[1]
--- avatar:setSkinColor(Player, set.skin1, set.skin2, set.nose, set.mouth)

---@type avatar

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

        ---@function setEyesColor Modifies the player's eye color.
        ---@param player Player
        ---@param c Color
        ---@code local newEyesColor = Color(200, 0, 0)
        --- avatar:setEyesColor(Player, newEyesColor)
        setEyesColor = function(self, player, c)
            if self ~= avatar then
                error("avatar:setEyesColor(player, c): use `:`", 2)
            end
            if type(player) ~= Type.Player then
                error("avatar:setEyesColor(player, c): player should be a Player", 2)
            end
            if type(c) ~= Type.Color then
                error("avatar:setEyesColor(player, c): c should be a Color", 2)
            end

            local head = player.Head
            head.Palette[6].Color = c
            head.Palette[8].Color = c
            head.Palette[8].Color:ApplyBrightnessDiff(-0.15)
        end,

        ---@function getEyesColor Returns the current eyes' color.
        ---@param player Player
        ---@return Color
        getEyesColor = function(self, player)
            if self ~= avatar then
                error("avatar:getEyesColor(player, c): use `:`", 2)
            end
            if type(player) ~= Type.Player then
                error("avatar:getEyesColor(player, c): player should be a Player", 2)
            end

        	return player.Head.Palette[6].Color
        end,

        ---@function setSkinColor Modifies the skin, nose and mouth colors.
        ---@param player Player
        ---@param skin1 Color
        ---@param skin2 Color
        ---@param nose Color
        ---@param mouth Color
        ---@code local newColor = Color(200, 0, 0)
        --- avatar:setSkinColor(Player, newColor, newColor, newColor, newColor)
        setSkinColor = function(self, player, skin1, skin2, nose, mouth)
            if self ~= avatar then
                error("avatar:setSkinColor(player, skin1, skin2, nose, mouth): use `:`", 2)
            end
            if type(player) ~= Type.Player then
                error("avatar:setSkinColor(player, skin1, skin2, nose, mouth): player should be a Player", 2)
            end
            if type(skin1) ~= Type.Color then
                error("avatar:setSkinColor(player, skin1, skin2, nose, mouth): skin1 should be a Color", 2)
            end
            if type(skin2) ~= Type.Color then
                error("avatar:setSkinColor(player, skin1, skin2, nose, mouth): skin2 should be a Color", 2)
            end
            if type(nose) ~= Type.Color then
                error("avatar:setSkinColor(player, skin1, skin2, nose, mouth): nose should be a Color", 2)
            end
            if type(mouth) ~= Type.Color then
                error("avatar:setSkinColor(player, skin1, skin2, nose, mouth): mouth should be a Color", 2)
            end

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

        ---@function getNoseColor Returns the players's nose color.
        ---@param player Player
        ---@return Color
        getNoseColor = function(self, player)
            if self ~= avatar then
                error("avatar:getNoseColor(player): use `:`", 2)
            end
            if type(player) ~= Type.Player then
                error("avatar:getNoseColor(player): player should be a Player", 2)
            end

        	return player.Head.Palette[7].Color
        end,

        ---@function setNoseColor Modifies the player's nose color.
        ---@param player Player
        ---@param color Color
        ---@code local newNoseColor = Color(0, 200, 0)
        --- avatar:setNoseColor(Player, newNoseColor)
        setNoseColor = function(self, player, color)
            if self ~= avatar then
                error("avatar:setNoseColor(player, color): use `:`", 2)
            end
            if type(player) ~= Type.Player then
                error("avatar:setNoseColor(player, color): player should be a Player", 2)
            end
            if type(color) ~= Type.Color then
                error("avatar:setNoseColor(player, color): color should be a Color", 2)
            end
            
            player.Head.Palette[7].Color = color
        end,

        ---@function getMouthColor Returns the players's mouth color.
        ---@param player Player
        ---@return Color
        getMouthColor = function(self, player)
            if self ~= avatar then
                error("avatar:getMouthColor(player): use `:`", 2)
            end
            if type(player) ~= Type.Player then
                error("avatar:getMouthColor(player): player should be a Player", 2)
            end

        	return player.Head.Palette[4].Color
        end,

        ---@function setMouthColor Modifies the player's mouth color.
        ---@param player Player
        ---@param color Color
        ---@code local newMouthColor = Color(0, 0, 200)
        --- avatar:setMouthColor(Player, newMouthColor)
        setMouthColor = function(self, player, color)
            if self ~= avatar then
                error("avatar:setMouthColor(player, color): use `:`", 2)
            end
            if type(player) ~= Type.Player then
                error("avatar:setMouthColor(player, color): player should be a Player", 2)
            end
            if type(color) ~= Type.Color then
                error("avatar:setMouthColor(player, color): color should be a Color", 2)
            end
            
            player.Head.Palette[4].Color = color
        end
    }
}
setmetatable(avatar, avatarMetatable)

return avatar