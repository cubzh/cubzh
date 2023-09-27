local playerModule = {}

-- CONSTANTS

local PLAYER_BOUNCINESS = 0
local PLAYER_FRICTION = 0
local PLAYER_MASS = 1.0
local MAP_DEFAULT_COLLISION_GROUP = 1
local PLAYER_DEFAULT_COLLISION_GROUP = 2
local OBJECT_DEFAULT_COLLISION_GROUP = 3

-- MODULES

local hierarchyactions = require("hierarchyactions")

local blockUnderneath = function(player)
    local ray = Ray(player.Position + Number3(0,0,0), Number3.Down)
    local impact = ray:Cast(nil, Player)
    return impact and impact.Distance <= 0.5 and impact.Block
end

local CastRay =  function(player, filterIn)
    if player == nil or type(player) ~= "Player" then
        error("Player:CastRay should be called with `:`", 2)
    end

    -- The origin of the ray should be the point
    -- above Player's head (not Camera.Position).
    -- To avoid collisions when items are present
    -- between Player and Camera.
    -- These 2 lines are used to obtain this point:
    -- (using a vector-plane intersection formula)
    local normal = Player.Up:Cross(Camera.Right)
    local origin = Camera.Position + Camera.Forward * ((Player.Position - Camera.Position):Dot(normal) / Camera.Forward:Dot(normal))

    local ray = Ray(origin, Camera.Forward)

    local impact = ray:Cast(filterIn, Player) -- Player always filtered out

    return impact
end

local EquipBackpack = function(player, shape)
    -- always unequip the item currently equipped
    if player.__backpackItem ~= nil and player.__backpackItem:GetParent() == player.Body then
        player.__backpackItem:RemoveFromParent()
        -- restore its physics attributes
        player.__backpackItem.Physics = player.__backpackItem.__savePhysics
        player.__backpackItem.CollisionGroups = player.__backpackItem.__saveCollisionGroups
        player.__backpackItem.CollidesWithGroups = player.__backpackItem.__saveCollidesWithGroups
        -- lose reference on it
        player.__backpackItem = nil
    end
    if shape == nil then return end
    -- reset shape Pivot to center
    shape.Pivot = Number3(shape.Width * 0.5, shape.Height * 0.5, shape.Depth * 0.5)
    -- disable Physics
    shape.__savePhysics = shape.Physics
    shape.__saveCollisionGroups = shape.CollisionGroups
    shape.__saveCollidesWithGroups = shape.CollidesWithGroups
    shape.Physics = false
    shape.CollisionGroups = {}
    shape.CollidesWithGroups = {}
    player.__backpackItem = shape
    -- Notes about lua Point:
    -- `poi.Coords` is a simple getter and returns the value as it was stored
    -- `poi.LocalPosition` performs a block to local transformation w/ associated shape
    -- item local position and rotation
    local poi = shape:GetPoint("ModelPoint_Backpack")
    local poiPos = nil
    local poiRot = nil
    if poi ~= nil then
        poiRot = poi.Rotation
        -- Item Editor saved POI position in model space (block coordinates), convert into head local space
        local localPoint = poi.LocalPosition
        local localBodyPoint = localPoint:Copy()
        localBodyPoint = -localBodyPoint -- relative to body point instead of item pivot
        localBodyPoint:Rotate(poiRot)
        localBodyPoint = localBodyPoint * shape.LocalScale
        poiPos = localBodyPoint
    else
        poi = shape:GetPoint("Backpack")
        poiRot = poi.Rotation
        -- backward-compatibility: Item Editor saved POI position in local space and item hasn't been edited since
        -- Note: engine cannot update POI in local space when the item is resized
        poiPos = poi.Coords -- get stored value as is
    end
    if poiPos == nil then poiPos = Number3(0, 0, 0) end
    if poiRot == nil then poiRot = Number3(0, 0, 0) end
    -- body local point
    local bodyPoint = player.Body:GetPoint("ModelPoint_Backpack").LocalPosition
    if bodyPoint == nil then
        bodyPoint = Number3(0.5, 2.5, -1.5) -- default value
    end
    -- add shape to body
    player.Body:AddChild(shape)
    shape.LocalRotation = poiRot
    shape.LocalPosition = poiPos + bodyPoint
end

local EquipHat = function(player, shape)
    if player == nil or type(player) ~= "Player" then
        error("Player:EquipHat should be called with `:`", 2)
    end
    -- always unequip the item currently equipped
    if player.__hatItem ~= nil and player.__hatItem:GetParent() == player.Head then
        player.__hatItem:RemoveFromParent()
        -- restore its physics attributes
        player.__hatItem.Physics = player.__hatItem.__savePhysics
        player.__hatItem.CollisionGroups = player.__hatItem.__saveCollisionGroups
        player.__hatItem.CollidesWithGroups = player.__hatItem.__saveCollidesWithGroups
        -- lose reference on it
        player.__hatItem = nil
    end
    if shape == nil then return end
    -- reset shape Pivot to center
    shape.Pivot = Number3(shape.Width * 0.5, shape.Height * 0.5, shape.Depth * 0.5)
    -- disable Physics
    shape.__savePhysics = shape.Physics
    shape.__saveCollisionGroups = shape.CollisionGroups
    shape.__saveCollidesWithGroups = shape.CollidesWithGroups
    shape.Physics = false
    shape.CollisionGroups = {}
    shape.CollidesWithGroups = {}
    player.__hatItem = shape
    -- Notes about lua Point:
    -- `poi.Coords` is a simple getter and returns the value as it was stored
    -- `poi.LocalPosition` performs a block to local transformation w/ associated shape
    -- item local position and rotation
    local poi = shape:GetPoint("ModelPoint_Hat")
    local poiPos = nil
    local poiRot = nil
    if poi ~= nil then
        poiRot = poi.Rotation
        -- Item Editor saved POI position in model space (block coordinates), convert into head local space
        local localPoint = poi.LocalPosition
        local localHeadPoint = localPoint:Copy()
        localHeadPoint = -localHeadPoint -- relative to head point instead of item pivot
        localHeadPoint:Rotate(poiRot)
        localHeadPoint = localHeadPoint * shape.LocalScale
        poiPos = localHeadPoint
    else
        poi = shape:GetPoint("Hat")
        poiRot = poi.Rotation
        -- backward-compatibility: Item Editor saved POI position in local space and item hasn't been edited since
        -- Note: engine cannot update POI in local space when the item is resized
        poiPos = poi.Coords -- get stored value as is
    end
    if poiPos == nil then poiPos = Number3(0, 0, 0) end
    if poiRot == nil then poiRot = Number3(0, 0, 0) end
    -- head local point
    local headPoint = player.Head:GetPoint("ModelPoint_Hat").LocalPosition
    if headPoint == nil then
        headPoint = Number3(-0.5, 8.5, -0.5) -- default value
    end
    -- add shape to head
    player.Head:AddChild(shape)
    shape.LocalRotation = poiRot
    shape.LocalPosition = poiPos + headPoint
end

local EquipLeftHand = function(player, shape)
    if player == nil or type(player) ~= "Player" then
        error("Player:EquipLeftHand should be called with `:`", 2)
    end
    -- always unequip the item currently equipped
    if player.__leftHandItem ~= nil and player.__leftHandItem:GetParent() == player.LeftHand then
        player.__leftHandItem:RemoveFromParent()
        -- restore its physics attributes
        player.__leftHandItem.Physics = player.__leftHandItem.__savePhysics
        player.__leftHandItem.CollisionGroups = player.__leftHandItem.__saveCollisionGroups
        player.__leftHandItem.CollidesWithGroups = player.__leftHandItem.__saveCollidesWithGroups
        -- lose reference on it
        player.__leftHandItem = nil
    end
    if shape == nil then return end
    -- reset shape Pivot to center
    shape.Pivot = Number3(shape.Width * 0.5, shape.Height * 0.5, shape.Depth * 0.5)
    -- disable Physics
    shape.__savePhysics = shape.Physics
    shape.__saveCollisionGroups = shape.CollisionGroups
    shape.__saveCollidesWithGroups = shape.CollidesWithGroups
    shape.Physics = PhysicsMode.Disabled
    shape.CollisionGroups = {}
    shape.CollidesWithGroups = {}
    player.__leftHandItem = shape
    -- Notes about lua Point:
    -- `poi.Coords` is a simple getter and returns the value as it was stored
    -- `poi.LocalPosition` performs a block to local transformation w/ associated shape
    -- get POI rotation
    local poiRot = shape:GetPoint("ModelPoint_Hand_v2").Rotation
    local compatRotation = false -- V1 & legacy POIs conversion
    if poiRot == nil then
        poiRot = shape:GetPoint("ModelPoint_Hand").Rotation
        if poiRot == nil then
            poiRot = shape:GetPoint("Hand").Rotation
        end
        if poiRot ~= nil then
            compatRotation = true
        else
            -- default value
            poiRot = Number3(0,0,0)
        end
    end
    -- get POI position
    local poiPos = shape:GetPoint("ModelPoint_Hand_v2").LocalPosition
    if poiPos == nil then
        poiPos = shape:GetPoint("ModelPoint_Hand").LocalPosition
        if poiPos == nil then
            -- backward-compatibility: Item Editor saved POI position in local space and item hasn't been edited since
            -- Note: engine cannot update POI in local space when the item is resized
            poiPos = shape:GetPoint("Hand").Coords -- get stored value as is
            if poiPos ~= nil then
                poiPos = -1.0 * poiPos
            else
                poiPos = Number3(0,0,0)
            end
        end
    end
    -- Item Editor saves POI position in model space (block coordinates), in order to ignore resize offset ;
    -- convert into hand local space
    local localHandPoint = poiPos:Copy()
    localHandPoint = -localHandPoint -- relative to hand point instead of item pivot
    localHandPoint:Rotate(poiRot)
    if compatRotation then
        localHandPoint:Rotate(Number3(0, 0, math.pi * 0.5))
    end
    localHandPoint = localHandPoint * shape.LocalScale
    poiPos = localHandPoint
    shape:SetParent(player.LeftHand)
    shape.LocalRotation = poiRot
    shape.LocalPosition = poiPos + player.LeftHand:GetPoint("palm").LocalPosition
    if compatRotation then
        shape:RotateLocal(Number3(0, 0, 1), math.pi * 0.5)
    end
end

local EquipRightHand = function(player, shape)
    if player == nil or type(player) ~= "Player" then
        error("Player:EquipRightHand should be called with `:`", 2)
    end
    if player.__rightHandItem ~= nil and player.__rightHandItem:GetParent() == player.RightHand then
        player.__rightHandItem:RemoveFromParent()
        -- restore its physics attributes
        player.__rightHandItem.Physics = player.__rightHandItem.__savePhysics
        player.__rightHandItem.CollisionGroups = player.__rightHandItem.__saveCollisionGroups
        player.__rightHandItem.CollidesWithGroups = player.__rightHandItem.__saveCollidesWithGroups
        -- lose reference on it
        player.__rightHandItem = nil
    end
    if shape == nil then return end
    -- reset shape Pivot to center
    shape.Pivot = Number3(shape.Width * 0.5, shape.Height * 0.5, shape.Depth * 0.5)
    -- disable Physics
    shape.__savePhysics = shape.Physics
    shape.__saveCollisionGroups = shape.CollisionGroups
    shape.__saveCollidesWithGroups = shape.CollidesWithGroups
    shape.Physics = PhysicsMode.Disabled
    shape.CollisionGroups = {}
    shape.CollidesWithGroups = {}
    player.__rightHandItem = shape
    -- Notes about lua Point:
    -- `poi.Coords` is a simple getter and returns the value as it was stored
    -- `poi.LocalPosition` performs a block to local transformation w/ associated shape
    -- get POI rotation
    local poiRot = shape:GetPoint("ModelPoint_Hand_v2").Rotation
    local compatRotation = false -- V1 & legacy POIs conversion
    if poiRot == nil then
        poiRot = shape:GetPoint("ModelPoint_Hand").Rotation
        if poiRot == nil then
            poiRot = shape:GetPoint("Hand").Rotation
        end
        if poiRot ~= nil then
            compatRotation = true
        else
            -- default value
            poiRot = Number3(0,0,0)
        end
    end
    -- get POI position
    local poiPos = shape:GetPoint("ModelPoint_Hand_v2").LocalPosition
    if poiPos == nil then
        poiPos = shape:GetPoint("ModelPoint_Hand").LocalPosition
        if poiPos == nil then
            -- backward-compatibility: Item Editor saved POI position in local space and item hasn't been edited since
            -- Note: engine cannot update POI in local space when the item is resized
            poiPos = shape:GetPoint("Hand").Coords -- get stored value as is
            if poiPos ~= nil then
                poiPos = -1.0 * poiPos
            else
                poiPos = Number3(0,0,0)
            end
        end
    end
    -- Item Editor saves POI position in model space (block coordinates), in order to ignore resize offset ;
    -- convert into hand local space
    local localHandPoint = poiPos:Copy()
    localHandPoint = -localHandPoint -- relative to hand point instead of item pivot
    localHandPoint:Rotate(poiRot)
    if compatRotation then
        localHandPoint:Rotate(Number3(0, 0, math.pi * 0.5))
    end
    localHandPoint = localHandPoint * shape.LocalScale
    poiPos = localHandPoint
    shape:SetParent(player.RightHand)
    shape.LocalRotation = poiRot
    shape.LocalPosition = poiPos + player.RightHand:GetPoint("palm").LocalPosition
    if compatRotation then
        shape:RotateLocal(Number3(0, 0, 1), math.pi * 0.5)
    end
end

local SwapHands = function(player)
    if player == nil or type(player) ~= "Player" then
        error("Player:SwapHands should be called with `:`", 2)
    end

    local right = player.__rightHandItem
    local left = player.__leftHandItem
    player:EquipRightHand(left)
    player:EquipLeftHand(right)
end

local SwingRight = function(player)
    if not player.Animations.SwingRight then return end
    player.Animations.Walk:Toggle("RightHand", false)
    player.Animations.Walk:Toggle("RightArm", false)
    player.Animations.Idle:Toggle("RightHand", false)
    player.Animations.Idle:Toggle("RightArm", false)
    player.Animations.stanceDirty = true
    player.Animations.SwingRight:Play()
end

local SwingLeft = function(player)
    if not player.Animations.SwingLeft then return end
    player.Animations.Walk:Toggle("LeftHand", false)
    player.Animations.Walk:Toggle("LeftArm", false)
    player.Animations.Idle:Toggle("LeftHand", false)
    player.Animations.Idle:Toggle("LeftArm", false)
    player.Animations.stanceDirty = true
    player.Animations.SwingLeft:Play()
end

local playerCall = function(self, playerID, username, userID, isLocal)

	local player = Object()

	player.CollisionGroups = {2}
	player.CollidesWithGroups = {1,3}
	
	local mt = System.GetMetatable(player)

	mt.Avatar = nil

	mt.ID = playerID or 252
	mt.Username = username or "..."
	mt.UserID = userID or "..."
	mt.IsLocal = isLocal
	mt.BoundingBox = Box()
	mt.Shadow = true
    mt.Layers = 0
    mt.CastRay = CastRay
    mt.EquipBackpack = EquipBackpack
    mt.EquipHat = EquipHat
    mt.EquipLeftHand = EquipLeftHand
    mt.EquipRightHand = EquipRightHand
    mt.SwapHands = SwapHands
    mt.SwingLeft = SwingLeft
    mt.SwingRight = SwingRight

    mt.__type = 2 -- ITEM_TYPE_PLAYER in engine

    local objectIndex = mt.__index
	mt.__index = function(t, k)

		if k == "ID" or k == "Avatar" or k == "Username" or k == "UserID" or k == "IsLocal"
			or k == "BoundingBox" or k == "Shadow" or k == "Layers" or k == "EquipBackpack" or k == "EquipHat"
			or k == "EquipLeftHand" or k == "EquipRightHand" or k == "SwapHands" or k == "SwingLeft" or k == "SwingRight" then
			return mt[k]
		end

		if k == "BlockUnderneath" then return blockUnderneath(t) end
		if k == "Equipments" then return t.Avatar.equipments end
		if k == "equipments" then return t.Avatar.equipments end
		if k == "Animations" then return t.Avatar.Animations end
		if k == "Head" then return t.Avatar.Head end

		local v = objectIndex(t, k)
		return objectIndex(t, k)
	end

	local objectNewIndex = mt.__newindex
	mt.__newindex = function(t, k, v)
		if k == "ID" or k == "Username" or k == "UserID" or k == "BoundingBox" then
			mt[k] = v
			return
		end
		if k == "Avatar" then
			if v == nil then return end -- can't set nil avatar
			local previousHead = player.Head
			mt[k] = v
			local newHead = player.Head

			local angleBefore = player.Head.Forward:Angle(player.Down)

			if previousHead == nil then

				local bypassHeadLocalRotationCallback = false
				local capHeadRotation = function(rotation)
					if bypassHeadLocalRotationCallback == false then

						local angleAfter = player.Head.Forward:Angle(player.Down)
						
						local dot = player.Head.Forward:Dot(player.Forward)

						local upLimit = 5
						local downLimit = 5

						bypassHeadLocalRotationCallback = true
						if dot < 0 then
							if angleBefore < math.rad(90) then
								player.Head.LocalRotation:Set(math.rad(85), 0, 0)
							else
								player.Head.LocalRotation:Set(math.rad(-85), 0, 0)
							end
							angleBefore = player.Head.Forward:Angle(player.Down)
						elseif angleAfter < math.rad(downLimit) + 0.001 then
							player.Head.LocalRotation:Set(math.rad(90 - downLimit), 0, 0)
							angleBefore = player.Head.Forward:Angle(player.Down)
						elseif angleAfter > math.rad(180 - upLimit) then
							player.Head.LocalRotation:Set(math.rad(-90 + upLimit), 0, 0)
							angleBefore = player.Head.Forward:Angle(player.Down)
						else 
							angleBefore = angleAfter
						end
						bypassHeadLocalRotationCallback = false
					end
				end

				player.Head.LocalRotation:AddOnSetCallback(capHeadRotation)
				player.Head.Rotation:AddOnSetCallback(capHeadRotation)

			elseif newHead ~= previousHead then

				local headRotationOnSetCallBacks = previousHead.Rotation.OnSetCallbacks
			    local headLocalRotationOnSetCallBacks = previousHead.LocalRotation.OnSetCallbacks

			    if headRotationOnSetCallBacks ~= nil then
			       for _, callback in ipairs(headRotationOnSetCallBacks) do
			           newHead.Rotation:AddOnSetCallback(callback)
			       end
			    end

			    if headLocalRotationOnSetCallBacks ~= nil then
			       for _, callback in ipairs(headLocalRotationOnSetCallBacks) do
			           newHead.LocalRotation:AddOnSetCallback(callback)
			       end
			    end
			end

			return
		end

		if k == "Shadow" then
			hierarchyactions:applyToDescendants(t, { includeRoot = false }, function(o)
				if o.Shadow == nil then return end
				o.Shadow = v
			end)
			mt.Shadow = v
			return
		end
        if k == "Layers" then
            hierarchyactions:applyToDescendants(t, { includeRoot = false }, function(o)
                if o.Layers == nil then return end
                o.Layers = v
            end)
            mt.Layers = v
            return
        end
        if k == "Rotation" then
            if v == nil then return end
            -- Y field works for both Number3 and Rotation
            if type(v.Y) == "number" then
            	t.Rotation:Set(0, v.Y, 0)
            end
            -- check second number in table: {0, Y, 0}
            if type(v[2]) == "number" then
            	t.Rotation:Set(0, v[2], 0)
            end
            return
        end
       	if k == "LocalRotation" then
            if v == nil then return end
            -- Y field works for both Number3 and Rotation
            if type(v.Y) == "number" then
            	t.Rotation:Set(0, v.Y, 0)
            end
            -- check second number in table: {0, Y, 0}
            if type(v[2]) == "number" then
            	t.Rotation:Set(0, v[2], 0)
            end
            return
        end
		objectNewIndex(t, k, v)
	end

    local byPassRotationCallback = false

	player.Rotation:AddOnSetCallback(function(rotation)
		if byPassRotationCallback then
			byPassRotationCallback = false
		else
			-- enforce X == 0 and Z == 0
			if rotation.X ~= 0 or rotation.Z ~= 0 then
				byPassRotationCallback = true
				-- triggers rotation callback once again, but will be bypassed
				player.Rotation:Set(0, rotation.Y, 0)
			end
		end
	end)

	local byPassLocalRotationCallback = false
	player.LocalRotation:AddOnSetCallback(function(rotation)
		if byPassLocalRotationCallback then
			byPassLocalRotationCallback = false
		else
			-- enforce X == 0 and Z == 0
			if rotation.X ~= 0 or rotation.Z ~= 0 then
				byPassLocalRotationCallback = true
				-- triggers rotation callback once again, but will be bypassed
				player.LocalRotation:Set(0, rotation.Y, 0)
			end
		end
	end)

    player.Scale = 0.5
    player.Mass = PLAYER_MASS
    player.Friction = PLAYER_FRICTION
    player.Bounciness = PLAYER_BOUNCINESS
    player.Physics = PhysicsMode.Dynamic
    player.CollidesWithGroups = { MAP_DEFAULT_COLLISION_GROUP, OBJECT_DEFAULT_COLLISION_GROUP }
    player.CollisionGroups = { PLAYER_DEFAULT_COLLISION_GROUP }
    player.CollisionBox = Box(Number3(-4.5,0,-4.5), Number3(4.5,29,4.5))
    player.BoundingBox = player.CollisionBox
    player.Shadow = true
    player.ShadowCookie = 4
    player.Layers = 1 -- Camera Layers 0

    player.Motion:AddOnSetCallback(function()
        if not player.Avatar then return end -- Avatar not loaded yet
        local anims = player.Animations

        if player.Motion == Number3(0,0,0) then
            if anims.Idle.IsPlaying == false then
                if anims.Walk.IsPlaying then anims.Walk:Stop() end
                anims.Idle:Play()
            end
        else
            if anims.Walk.IsPlaying == false then
                if anims.Idle.IsPlaying then anims.Idle:Stop() end
                anims.Walk:Play()
            end
        end
    end)

    Client.__loadAvatar(player)
    if isLocal == true then
        require("camera_modes"):setThirdPerson({ camera = Camera, target = player })
    end

    return player
end

local playerMetatable = {
    __newindex = function(t, k, v) error("Player is read-only.", 2) end,
    __metatable = false,
    __call = playerCall
}
setmetatable(playerModule, playerMetatable)

return playerModule
