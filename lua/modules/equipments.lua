local equipments = {

	equipmentNames = {
		"hair",
		"jacket",
		"pants",
		"boots",
	},
	equipmentParent = function(player, partName)
		if partName == "hair" then
			return player.Head
		elseif partName == "jacket" then
			return { player.Body or player, player.RightArm, player.LeftArm }
		elseif partName == "pants" then
			return { player.RightLeg, player.LeftLeg }
		elseif partName == "boots" then
			return { player.RightFoot, player.LeftFoot }
		end
	end,
}

equipments.partExists = function(name)
	for _, value in ipairs(equipments.equipmentNames) do
		if value == name then
			return true
		end
	end
	return false
end

equipments.unloadAll = function(player)
	if player == nil then
		player = Player
	end
	if player.equipments == nil then
		return
	end

	for name, shape in pairs(player.equipments) do
		if shape.attachedParts then
			for _, subshape in ipairs(shape.attachedParts) do
				subshape:RemoveFromParent()
				shape.attachedParts = nil
			end
		end
		shape:RemoveFromParent()
		player.equipments[name] = nil
	end
end

equipments.load = function(equipmentName, itemRepoName, player, mutable, abortIfSet, callback)
	if equipmentName == nil then
		callback(nil)
		return
	end

	if itemRepoName == nil or type(itemRepoName) ~= "string" or itemRepoName == "" then
		-- if nil, load official equipments
		return equipments.load(equipmentName, "official." .. equipmentName, player, mutable, abortIfSet, callback)
	end

	if player == nil then
		player = Player
	end
	if player.equipments == nil then
		player.equipments = {}
	end

	if equipments.partExists(equipmentName) == false then
		print("unknown equipment name (" .. equipmentName .. ")")
		if callback ~= nil then
			callback(nil)
		end
		return
	end

	local req = Object:Load(itemRepoName, function(shape)
		if abortIfSet and player.equipments[equipmentName] ~= nil then
			return
		end

		-- remove previous equipment no matter what
		if player.equipments[equipmentName] ~= nil then
			player.equipments[equipmentName]:RemoveFromParent()
			if player.equipments[equipmentName].attachedParts then
				for _, v in ipairs(player.equipments[equipmentName].attachedParts) do
					v:RemoveFromParent()
				end
			end
		end

		if shape == nil then
			-- if nil, load official equipments
			if string.sub(itemRepoName, 1, 9) ~= "official." then -- fallback on official equipments
				return equipments.load(
					equipmentName,
					"official." .. equipmentName,
					player,
					mutable,
					abortIfSet,
					callback
				)
			end
			if callback ~= nil then
				callback(nil)
			end
			return
		end

		if mutable then
			shape = MutableShape(shape)
		end

		shape.equipmentName = equipmentName
		player.equipments[equipmentName] = shape

		equipments:place(player, shape)

		if callback ~= nil then
			callback(shape)
		end
	end)

	return req
end

equipments.attachEquipmentToBodyPart = function(_, equipment, bodyPart, options)
	if equipment == nil then
		return
	end
	local layer = options.layer or 1
	local isPant = options.isPant or false

	equipment.Physics = PhysicsMode.Disabled
	equipment:SetParent(bodyPart)
	equipment.IsUnlit = bodyPart.IsUnlit
	equipment.Layers = layer
	equipment.LocalRotation = { 0, 0, 0 }
	local coords = bodyPart:GetPoint("origin").Coords
	if coords == nil then
		print("can't get parent coords for equipment")
		return
	end
	local localPos = bodyPart:BlockToLocal(coords)
	local origin = Number3(0, 0, 0)
	local point = equipment:GetPoint("origin")
	if point ~= nil then
		origin = point.Coords
	end
	equipment.Pivot = origin
	equipment.LocalPosition = localPos
	equipment.Scale = 1
	if isPant then
		equipment.Scale = 1.05
	end
end

equipments.place = function(self, player, shape)
	if shape == nil then
		return
	end

	local parent = self.equipmentParent(player, shape.equipmentName)
	if parent == nil then
		print("can't find parent for equipment")
		return
	end

	local options = {
		layer = player.Layers,
		isPant = shape.equipmentName == "pants" or shape.equipmentName == "lpant" or shape.equipmentName == "rpant",
	}
	if type(parent) == "table" then -- multiple shape equipment
		self:attachEquipmentToBodyPart(shape, parent[1], options)

		local shape2 = shape:GetChild(1)
		shape.attachedParts = { shape2 }
		self:attachEquipmentToBodyPart(shape2, parent[2], options)

		local shape3 = shape2:GetChild(1)
		if shape3 then
			shape.attachedParts = { shape2, shape3 }
			self:attachEquipmentToBodyPart(shape3, parent[3], options)
		end
	else
		self:attachEquipmentToBodyPart(shape, parent, options)
	end
end

equipments.initEquipment = function(player, shape, itemCategory)
	shape.equipmentName = itemCategory
	if shape:GetPoint("origin") then
		return
	end

	local parent = equipments.equipmentParent(player, itemCategory)
	if parent == nil then
		print("can't find parent for equipment")
		return
	end
	local coords = parent:GetPoint("origin").Coords
	if coords == nil then
		print("can't get parent coords for equipment")
		return
	end
	local origin = coords
	if itemCategory ~= "rpant" and itemCategory ~= "lpant" and itemCategory ~= "shirt" then
		origin = origin + Number3(0.5, 0.5, 0.5)
	end
	shape:AddPoint("origin", origin, Number3(0, 0, 0))
	return shape
end

return equipments
