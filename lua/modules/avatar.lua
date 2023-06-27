local avatar = {}
local avatarMetatable = {
    __index = {
        _bodyParts = {},
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
        setEyesColor = function(self, playerOrHead, c)
            local head = playerOrHead
            if type(playerOrHead) == "Player" then
                head = playerOrHead.Head
            end
            head.Palette[6].Color = c
            head.Palette[8].Color = c
            head.Palette[8].Color:ApplyBrightnessDiff(-0.15)
        end,
        getEyesColor = function(self, playerOrHead)
            local head = playerOrHead
            if type(playerOrHead) == "Player" then
                head = playerOrHead.Head
            end
            return head.Palette[6].Color
        end,
        setBodyPartColor = function(self, name, shape, skin1, skin2)
            local skin1key = 1
            if name == "LeftHand" or name == "Body" or name == "RightArm" then skin1key = 2 end
            if shape.Palette[skin1key] then
                shape.Palette[skin1key].Color = skin1
            end

            if name ~= "Body" then
                local skin2key = 2
                if name == "LeftHand" or name == "RightArm" then skin2key = 1 end
                if shape.Palette[skin2key] then
                    shape.Palette[skin2key].Color = skin2
                end
            end
        end,
        setSkinColor = function(self, player, skin1, skin2, nose, mouth)
            local bodyParts = { "Head", "Body", "RightArm", "RightHand", "LeftArm", "LeftHand", "RightLeg", "LeftLeg", "RightFoot", "LeftFoot" }
            for _,name in ipairs(bodyParts) do
                self:setBodyPartColor(name, player[name], skin1, skin2)
            end
            self:setNoseColor(player, nose)
            self:setMouthColor(player, mouth)
        end,
        getNoseColor = function(self, playerOrHead)
            local head = playerOrHead
            if type(playerOrHead) == "Player" then
                head = playerOrHead.Head
            end
            return head.Palette[7].Color
        end,
        setNoseColor = function(self, playerOrHead, color)
            if not color or type(color) ~= "Color" then
                print("Error: setNoseColor second argument must be of type Color.")
                return
            end

            local head = playerOrHead
            if type(playerOrHead) == "Player" then
                head = playerOrHead.Head
            end
            head.Palette[7].Color = color
        end,
        getMouthColor = function(self, playerOrHead)
            local head = playerOrHead
            if type(playerOrHead) == "Player" then
                head = playerOrHead.Head
            end
            return head.Palette[4].Color
        end,
        setMouthColor = function(self, playerOrHead, color)
            if not color or type(color) ~= "Color" then
                print("Error: setMouthColor second argument must be of type Color.")
                return
            end

            local head = playerOrHead
            if type(playerOrHead) == "Player" then
                head = playerOrHead.Head
            end
            head.Palette[4].Color = color
        end,
        _tableToColor = function(self, table)
            return Color(math.floor(table.r),math.floor(table.g),math.floor(table.b))
        end,
        prepareHead = function(self, head, usernameOrId, callback)
            local api = require("api")
            api.getAvatar(usernameOrId, function(err, data)
                if err then callback(err) return end
                if data.skinColor then
                    local skinColor = self:_tableToColor(data.skinColor)
                    local skinColor2 = self:_tableToColor(data.skinColor2)
                    self:setBodyPartColor("Head", head, skinColor, skinColor2)
                end
                if data.eyesColor then
                    self:setEyesColor(head, self:_tableToColor(data.eyesColor))
                end
                if data.noseColor then
                    self:setNoseColor(head, self:_tableToColor(data.noseColor))
                end
                if data.mouthColor then
                    self:setMouthColor(head, self:_tableToColor(data.mouthColor))
                end

                Object:Load(data.hair, function(shape)
                    if shape == nil then return callback("Error: can't find hair '"..data.hair.."'.") end
                    require("equipments"):attachEquipmentToBodyPart(shape, head)
                    callback(nil, head)
                end)
            end)
        end,
        getPlayerHead = function(self, usernameOrId, callback)
            -- Save the head in cache to make it faster to load next heads
            if not self._bodyParts.head then
                Object:Load("aduermael.head_skin2_v2", function(head)
                    self._bodyParts.head = head
                    self:getPlayerHead(usernameOrId, callback)
                end)
                return
            end
            local head = MutableShape(self._bodyParts.head)
            self:prepareHead(head, usernameOrId, callback)
        end
    }
}
setmetatable(avatar, avatarMetatable)

return avatar