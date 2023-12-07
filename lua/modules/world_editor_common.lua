local common = {}

common.MAP_SCALE_DEFAULT = 5

common.maps = {
	"aduermael.hills",
	"aduermael.base_250x40x250",
	"claire.harbour",
	"buche.chess_board",
	"claire.apocalyptic_city",
	"aduermael.unicorn_land",
	"boumety.building_challenge",
	"claire.museum",
	"claire.summer_beach",
	"claire.voxowl_hq",
}

common.events = {
	P_END_PREPARING = "pep",
	END_PREPARING = "ep",
	P_PLACE_OBJECT = "ppo",
	PLACE_OBJECT = "po",
	P_EDIT_OBJECT = "peo",
	EDIT_OBJECT = "eo",
	P_REMOVE_OBJECT = "pro",
	REMOVE_OBJECT = "ro",
	P_PLACE_BLOCK = "ppb",
	PLACE_BLOCK = "pb",
	P_REMOVE_BLOCK = "prb",
	REMOVE_BLOCK = "rb",
	P_START_EDIT_OBJECT = "pseo",
	START_EDIT_OBJECT = "seo",
	P_END_EDIT_OBJECT = "peeo",
	END_EDIT_OBJECT = "eeo",
	SYNC = "s",
	MASTER = "m",
	PLAYER_ACTIVITY = "pa",
	P_SET_AMBIENCE = "psa",
	SET_AMBIENCE = "sa",
	P_LOAD_WORLD = "plw",
	LOAD_WORLD = "lw",
	P_SET_MAP_SCALE = "psms",
	SET_MAP_SCALE = "sms",
	P_RESET_ALL = "pra",
	RESET_ALL = "ra",
	P_SAVE_WORLD = "psw",
	SAVE_WORLD = "sw",
}

local SERIALIZED_CHUNKS_ID = {
	MAP = 0,
	AMBIENCE = 1,
	OBJECTS = 2,
	BLOCKS = 3,
}

local ambienceFields = { -- key, serialize and deserialize functions
	["sky.skyColor"] = {
		"ssc",
		function(d, v)
			if type(v) == "Color" then
				d:WriteColor(v)
			else
				d:WriteColor(Color(math.floor(v[1]), math.floor(v[2]), math.floor(v[3])))
			end
		end,
		function(d)
			return d:ReadColor()
		end,
	},
	["sky.horizonColor"] = {
		"shc",
		function(d, v)
			if type(v) == "Color" then
				d:WriteColor(v)
			else
				d:WriteColor(Color(math.floor(v[1]), math.floor(v[2]), math.floor(v[3])))
			end
		end,
		function(d)
			return d:ReadColor()
		end,
	},
	["sky.abyssColor"] = {
		"sac",
		function(d, v)
			if type(v) == "Color" then
				d:WriteColor(v)
			else
				d:WriteColor(Color(math.floor(v[1]), math.floor(v[2]), math.floor(v[3])))
			end
		end,
		function(d)
			return d:ReadColor()
		end,
	},
	["sky.lightColor"] = {
		"slc",
		function(d, v)
			if type(v) == "Color" then
				d:WriteColor(v)
			else
				d:WriteColor(Color(math.floor(v[1]), math.floor(v[2]), math.floor(v[3])))
			end
		end,
		function(d)
			return d:ReadColor()
		end,
	},
	["sky.lightIntensity"] = {
		"sli",
		function(d, v)
			d:WriteFloat(v)
		end,
		function(d)
			return d:ReadFloat()
		end,
	},
	["fog.color"] = {
		"foc",
		function(d, v)
			if type(v) == "Color" then
				d:WriteColor(v)
			else
				d:WriteColor(Color(math.floor(v[1]), math.floor(v[2]), math.floor(v[3])))
			end
		end,
		function(d)
			return d:ReadColor()
		end,
	},
	["fog.near"] = {
		"fon",
		function(d, v)
			d:WriteFloat(v)
		end,
		function(d)
			return d:ReadFloat()
		end,
	},
	["fog.far"] = {
		"fof",
		function(d, v)
			d:WriteFloat(v)
		end,
		function(d)
			return d:ReadFloat()
		end,
	},
	["fog.lightAbsorbtion"] = {
		"foa",
		function(d, v)
			d:WriteFloat(v)
		end,
		function(d)
			return d:ReadFloat()
		end,
	},
	["sun.color"] = {
		"suc",
		function(d, v)
			if type(v) == "Color" then
				d:WriteColor(v)
			else
				d:WriteColor(Color(math.floor(v[1]), math.floor(v[2]), math.floor(v[3])))
			end
		end,
		function(d)
			return d:ReadColor()
		end,
	},
	["sun.intensity"] = {
		"sui",
		function(d, v)
			d:WriteFloat(v)
		end,
		function(d)
			return d:ReadFloat()
		end,
	},
	["sun.rotation"] = {
		"sur",
		function(d, v)
			d:WriteFloat(v[1])
			d:WriteFloat(v[2])
		end,
		function(d)
			return Number2(d:ReadFloat(), d:ReadFloat())
		end,
	},
	["ambient.skyLightFactor"] = {
		"asl",
		function(d, v)
			d:WriteFloat(v)
		end,
		function(d)
			return d:ReadFloat()
		end,
	},
	["ambient.dirLightFactor"] = {
		"adl",
		function(d, v)
			d:WriteFloat(v)
		end,
		function(d)
			return d:ReadFloat()
		end,
	},
}

local writeChunkMap = function(d, name, scale)
	if name == nil or scale == nil then
		error("can't serialize map", 2)
		return false
	end
	-- Map
	-- CHUNK_ID 1
	-- SCALE 8
	-- NAME LEN 4 (len)
	-- NAME len
	d:WriteByte(SERIALIZED_CHUNKS_ID.MAP)
	d:WriteDouble(scale)
	d:WriteUInt32(#name)
	d:WriteString(name)
	return true
end

local readChunkMap = function(d)
	local scale = d:ReadDouble()
	local len = d:ReadUInt32()
	local name = d:ReadString(len)
	return name, scale
end

local writeChunkAmbience = function(d, ambience)
	if ambience == nil then
		error("can't serialize ambience chunk", 2)
		return false
	end
	d:WriteByte(SERIALIZED_CHUNKS_ID.AMBIENCE)
	local cursorLength = d.Length
	d:WriteUInt16(0) -- temporary write size
	-- chunk
	-- CHUNK_ID 1
	-- CHUNK_LEN UINT16
	-- NB_FIELDS UINT8
	-- 1 -> NB_FIELDS
	--   KEY string len 2
	--   VALUE color or float based on key

	local fieldsList = {}

	for k1, v1 in pairs(ambience) do
		if type(v1) == "string" then
			table.insert(fieldsList, {
				"txt",
				v1,
				function(d, name)
					d:WriteUInt8(#name)
					d:WriteString(name)
				end,
			})
		elseif type(v1) == "table" then
			for k2, v2 in pairs(v1) do
				local ambienceField = ambienceFields[k1 .. "." .. k2]
				local key = ambienceField[1] -- get key
				local serializeFunction = ambienceField[2]
				table.insert(fieldsList, { key, v2, serializeFunction })
			end
		end
	end
	local nbFields = #fieldsList
	d:WriteUInt8(nbFields)
	for _, value in ipairs(fieldsList) do
		d:WriteString(value[1])
		local serializeFunction = value[3]
		serializeFunction(d, value[2])
	end

	local finalLength = d.Length
	local size = d.Length - cursorLength
	d.Length = cursorLength
	d:WriteUInt16(size)
	d.Length = finalLength

	return true
end

local readChunkAmbience = function(d)
	local ambience = {}
	d:ReadUInt16() -- read size
	local nbFields = d:ReadUInt8()
	for _ = 1, nbFields do
		local key = d:ReadString(3)
		local found = false
		for fullFieldName, v in pairs(ambienceFields) do
			if v[1] == key then
				local value = v[3](d) -- read value
				local category, name = fullFieldName:gsub("%.(.*)", ""), fullFieldName:match("%.(.*)")
				ambience[category] = ambience[category] or {}
				ambience[category][name] = value
				found = true
				break
			end
		end
		if not found then
			if key == "txt" then
				local length = d:ReadUInt8()
				ambience.text = d:ReadString(length)
			else
				error("unknown key " .. key, 2)
			end
		end
	end
	return ambience
end

local groupObjects = function(objects)
	local t = {}
	local nbGroups = 0
	for _, v in ipairs(objects) do
		if not t[v.fullname] then
			t[v.fullname] = {}
			nbGroups = nbGroups + 1
		end
		table.insert(t[v.fullname], v)
	end
	return t, nbGroups
end

local writeChunkObjects = function(d, objects)
	if objects == nil then
		error("can't serialize objects chunk", 2)
		return false
	end
	d:WriteByte(SERIALIZED_CHUNKS_ID.OBJECTS)
	local cursorLength = d.Length
	d:WriteUInt32(0) -- temporary write size
	-- chunk
	-- CHUNK_ID 1
	-- CHUNK_LEN UINT32
	-- NB_OBJECTS UINT16
	-- 1 -> NB_OBJECTS
	--   OBJECT FULLNAME_SIZE UINT16
	--   OBJECT FULLNAME string
	--   NB_INSTANCES uint16
	--     1 -> NB_INSTANCES
	--       NB_FIELDS uint8
	--       X FIELDS

	local objectsGrouped = groupObjects(objects)

	local nbObjects = #objects
	d:WriteUInt16(nbObjects)
	for fullname, group in pairs(objectsGrouped) do
		d:WriteUInt16(#fullname)
		d:WriteString(fullname)

		d:WriteUInt16(#group)

		for _, object in ipairs(group) do
			local cursorNbFields = d.Length
			local nbFields = 0
			d:WriteUInt8(0) -- temporary nbFields

			if object.uuid then
				d:WriteString("id")
				d:WriteUInt8(#object.uuid)
				d:WriteString(object.uuid)
				nbFields = nbFields + 1
			end
			if object.Position and object.Position ~= Number3(0, 0, 0) then
				d:WriteString("po")
				d:WriteNumber3(object.Position)
				nbFields = nbFields + 1
			end
			if object.Rotation and object.Rotation ~= Rotation(0, 0, 0) then
				d:WriteString("ro")
				d:WriteRotation(object.Rotation)
				nbFields = nbFields + 1
			end
			if object.Scale and object.Scale ~= Number3(1, 1, 1) then
				d:WriteString("sc")
				if type(object.Scale) == "number" then
					object.Scale = object.Scale * Number3(1, 1, 1)
				end
				d:WriteNumber3(object.Scale)
				nbFields = nbFields + 1
			end
			if object.Name and object.Name ~= object.fullname then
				d:WriteString("na")
				d:WriteUInt8(#object.Name)
				d:WriteString(object.Name)
				nbFields = nbFields + 1
			end
			if object.Physics and object.Physics ~= PhysicsMode.StaticPerBlock then
				d:WriteString("pm")
				d:WritePhysicsMode(object.Physics)
				nbFields = nbFields + 1
			end

			-- jump back to set nbFields value
			local endCursor = d.Length
			d.Length = cursorNbFields
			d:WriteUInt8(nbFields)
			d.Length = endCursor
		end
	end

	local finalLength = d.Length
	local size = d.Length - cursorLength
	d.Length = cursorLength
	d:WriteUInt32(size)
	d.Length = finalLength

	return true
end

local readChunkObjectsV2 = function(d)
	local objects = {}
	d:ReadUInt16() -- read size
	local nbObjects = d:ReadUInt16()
	local fetchedObjects = 0
	while fetchedObjects < nbObjects do
		local fullnameSize = d:ReadUInt16()
		local fullname = d:ReadString(fullnameSize)
		local nbInstances = d:ReadUInt16()
		for _ = 1, nbInstances do
			local instance = {
				fullname = fullname,
			}
			local nbFields = d:ReadUInt8()
			for _ = 1, nbFields do
				local key = d:ReadString(2)
				if key == "po" then
					instance.Position = d:ReadNumber3()
				elseif key == "ro" then
					instance.Rotation = d:ReadRotation()
				elseif key == "sc" then
					instance.Scale = d:ReadNumber3()
				elseif key == "na" then
					local nameLength = d:ReadUInt8()
					instance.Name = d:ReadString(nameLength)
				elseif key == "id" then
					local idLength = d:ReadUInt8()
					instance.uuid = d:ReadString(idLength)
				elseif key == "de" then
					local length = d:ReadUInt16()
					instance.itemDetailsCell = Data(d:ReadString(length), { format = "base64" }):ToTable()
				elseif key == "pm" then
					instance.Physics = d:ReadPhysicsMode()
				else
					error("Wrong format while deserializing", 2)
					return false
				end
			end
			table.insert(objects, instance)
			fetchedObjects = fetchedObjects + 1
		end
	end
	return objects
end

local readChunkObjects = function(d)
	local objects = {}
	d:ReadUInt32() -- read size
	local nbObjects = d:ReadUInt16()
	local fetchedObjects = 0
	while fetchedObjects < nbObjects do
		local fullnameSize = d:ReadUInt16()
		local fullname = d:ReadString(fullnameSize)
		local nbInstances = d:ReadUInt16()
		for _ = 1, nbInstances do
			local instance = {
				fullname = fullname,
			}
			local nbFields = d:ReadUInt8()
			for _ = 1, nbFields do
				local key = d:ReadString(2)
				if key == "po" then
					instance.Position = d:ReadNumber3()
				elseif key == "ro" then
					instance.Rotation = d:ReadRotation()
				elseif key == "sc" then
					instance.Scale = d:ReadNumber3()
				elseif key == "na" then
					local nameLength = d:ReadUInt8()
					instance.Name = d:ReadString(nameLength)
				elseif key == "id" then
					local idLength = d:ReadUInt8()
					instance.uuid = d:ReadString(idLength)
				elseif key == "pm" then
					instance.Physics = d:ReadPhysicsMode()
				else
					error("Wrong format while deserializing", 2)
					return false
				end
			end
			table.insert(objects, instance)
			fetchedObjects = fetchedObjects + 1
		end
	end
	return objects
end

local writeChunkBlocks = function(d, blocks)
	if blocks == nil then
		error("can't serialize blocks chunk", 2)
		return false
	end
	d:WriteByte(SERIALIZED_CHUNKS_ID.BLOCKS)
	local cursorLength = d.Length
	d:WriteUInt16(0) -- temporary write size
	-- chunk
	-- CHUNK_ID 1
	-- CHUNK_SIZE UInt16
	-- NB_BLOCKS UInt16
	d:WriteUInt16(0) -- temporary write size
	local nbBlocks = 0
	for _, v in ipairs(blocks) do
		local key, color = v[1], v[2]
		d:WriteUInt16(#key) -- key size
		d:WriteString(key) -- key
		if type(color) == "number" and color == -1 then
			d:WriteUInt8(0) -- block removed
			nbBlocks = nbBlocks + 1
		elseif type(color) == "Color" then
			d:WriteUInt8(1) -- block added
			d:WriteColor(color)
			nbBlocks = nbBlocks + 1
		end
	end

	local finalLength = d.Length
	local size = d.Length - cursorLength
	d.Length = cursorLength
	d:WriteUInt16(size)
	d:WriteUInt16(nbBlocks)
	d.Length = finalLength

	return true
end

local readChunkBlocks = function(d)
	local blocks = {}
	d:ReadUInt16() -- skip length
	local nbBlocks = d:ReadUInt16()
	for _ = 1, nbBlocks do
		local keyLength = d:ReadUInt16()
		local key = d:ReadString(keyLength)
		local blockAction = d:ReadUInt8()
		if blockAction == 0 then -- remove
			table.insert(blocks, { key, -1 })
		elseif blockAction == 1 then -- add
			local color = d:ReadColor()
			table.insert(blocks, { key, color })
		end
	end
	return blocks
end

local writeChunkBase64 = function(d, chunkId, chunkTable)
	if chunkTable == nil then
		error("can't serialize chunk " .. tostring(chunkId), 2)
		return false
	end
	d:WriteByte(chunkId)
	-- chunk
	-- CHUNK_ID 1
	-- CHUNK_LEN 4 (len)
	-- BASE64 len
	local data = Data(chunkTable)
	local dataBase64 = data:ToString({ format = "base64" })
	d:WriteUInt32(#dataBase64)
	d:WriteString(dataBase64)
	return true
end

local readChunkBase64 = function(d)
	local len = d:ReadUInt32()
	local base64 = d:ReadString(len)
	local d2 = Data(base64, { format = "base64" })
	return d2:ToTable()
end

-- v0: lua table serialized
-- v1: versionId, map chunk that can be read from cpp to load map, then 3 table serialized as base64 chunks
-- v2: versionId, map chunk that can be read from cpp to load map, ambience fields, objects, blocks
--     ambience, objects and blocks might not be serialized if the value is nil or length is 0
-- v3: same as v2 but removed itemDetailsCell and Objects chunk length is now uint32 and not uint16

local SERIALIZE_VERSION = 3

local serializeWorldBase64 = function(world)
	if not world.mapName then
		error("can't serialize without mapName", 2)
		return
	end
	local d = Data()
	d:WriteByte(SERIALIZE_VERSION) -- version
	writeChunkMap(d, world.mapName, world.mapScale or 5)
	if world.ambience then
		writeChunkAmbience(d, world.ambience)
	end
	if world.objects and #world.objects > 0 then
		writeChunkObjects(d, world.objects)
	end
	if world.blocks and #world.blocks > 0 then
		writeChunkBlocks(d, world.blocks)
	end
	return d:ToString({ format = "base64" })
end

local deserializeWorldBase64 = function(str)
	local d = Data(str, { format = "base64" })
	local version = d:ReadByte()
	local world = {}
	if version == 1 then
		d:ReadByte() -- skip chunk byte
		world.mapName, world.mapScale = readChunkMap(d)
		d:ReadByte() -- skip chunk byte
		world.ambience = readChunkBase64(d)
		d:ReadByte() -- skip chunk byte
		world.objects = readChunkBase64(d)
		d:ReadByte() -- skip chunk byte
		world.blocks = readChunkBase64(d)
	elseif version == 2 or version == 3 then
		while d.Cursor < d.Length do
			local chunk = d:ReadByte()
			if chunk == SERIALIZED_CHUNKS_ID.MAP then
				world.mapName, world.mapScale = readChunkMap(d)
			elseif chunk == SERIALIZED_CHUNKS_ID.AMBIENCE then
				world.ambience = readChunkAmbience(d)
			elseif chunk == SERIALIZED_CHUNKS_ID.OBJECTS then
				if version == 2 then
					world.objects = readChunkObjectsV2(d)
				else
					world.objects = readChunkObjects(d)
				end
			elseif chunk == SERIALIZED_CHUNKS_ID.BLOCKS then
				world.blocks = readChunkBlocks(d)
			end
		end
	else -- just a table
		d.Cursor = 0
		world = d:ToTable()
	end
	return world
end

common.serializeWorld = function(world)
	return serializeWorldBase64(world)
end

common.deserializeWorld = function(str)
	return deserializeWorldBase64(str)
end

common.posToStr = function(pos)
	return tostring(math.floor(pos.X + pos.Y * 1000 + pos.Z * 1000000))
end

common.uuidv4 = function()
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	return string.gsub(template, "[xy]", function(c)
		local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
		return string.format("%x", v)
	end)
end

local loadObject = function(objInfo, didLoad)
	Object:Load(objInfo.fullname, function(obj)
		obj:SetParent(World)
		local k = Box()
		k:Fit(obj, true)
		obj.Pivot = Number3(obj.Width / 2, k.Min.Y + obj.Pivot.Y, obj.Depth / 2)
		require("hierarchyactions"):applyToDescendants(obj, { includeRoot = true }, function(l)
			l.Physics = objInfo.Physics or PhysicsMode.StaticPerBlock
		end)
		obj.Position = objInfo.Position or Number3(0, 0, 0)
		obj.Rotation = objInfo.Rotation or Rotation(0, 0, 0)
		obj.Scale = objInfo.Scale or 0.5
		obj.CollidesWithGroups = Map.CollisionGroups + Player.CollisionGroups
		obj.Name = objInfo.Name or objInfo.fullname
		if didLoad then
			didLoad(obj)
		end
	end)
end

local loadMap = function(d, n, didLoad)
	Object:Load(d, function(j)
		map = MutableShape(j, { includeChildren = true })
		map.Scale = n or 5
		require("hierarchyactions"):applyToDescendants(map, { includeRoot = true }, function(o)
			o.CollisionGroups = Map.CollisionGroups
			o.CollidesWithGroups = Map.CollidesWithGroups
			o.Physics = PhysicsMode.StaticPerBlock
		end)
		map:SetParent(World)
		map.Position = { 0, 0, 0 }
		map.Pivot = { 0, 0, 0 }
		if didLoad then
			didLoad()
		end
	end)
end

common.loadWorld = function(mapBase64, config)
	if #mapBase64 == 0 then
		return
	end
	local world = common.deserializeWorld(mapBase64)
	local loadObjectsBlocksAndAmbience = function()
		if config.skipMap then
			Map.Scale = world.mapScale or 5
			map = Map
		end
		local blocks = world.blocks
		local objects = world.objects
		local ambience = world.ambience
		if blocks then
			for _, data in ipairs(blocks) do
				local pos = data[1]
				local color = data[2]
				local x = math.floor(pos % 1000)
				local y = math.floor(pos / 1000 % 1000)
				local z = math.floor(pos / 1000000)
				local w = map:GetBlock(x, y, z)
				if w then
					w:Remove()
				end
				if color ~= nil and color ~= -1 then
					map:AddBlock(color, x, y, z)
				end
			end
			map:RefreshModel()
		end
		nbObjectsLoaded = 0
		function loadedOneMore()
			nbObjectsLoaded = nbObjectsLoaded + 1
			if nbObjectsLoaded == #objects and config.didLoad then
				config.didLoad()
			end
		end
		if objects then
			for _, objInfo in ipairs(objects) do
				objInfo.currentlyEditedBy = nil
				loadObject(objInfo, loadedOneMore)
			end
		end
		if ambience then
			require("ui_ai_ambience"):setFromAIConfig(ambience, true)
		end
	end
	if not config.skipMap then
		loadMap(world.mapName, world.mapScale, loadObjectsBlocksAndAmbience)
	else
		loadObjectsBlocksAndAmbience()
	end
end

return common
