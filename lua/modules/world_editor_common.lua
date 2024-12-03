local common = {}

common.MAP_SCALE_DEFAULT = 5

local loaded = {
	b64 = nil,
	map = nil,
	world = nil,
	title = nil,
	worldID = nil,
	ambience = nil,
}

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
	P_SET_MAP_SCALE = "psms",
	SET_MAP_SCALE = "sms",
	P_RESET_ALL = "pra",
	RESET_ALL = "ra",
	P_SAVE_WORLD = "psw",
	SAVE_WORLD = "sw",
	P_SET_MAP_OFFSET = "psmo",
	SET_MAP_OFFSET = "smo",
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
			d:WriteFloat(v.X)
			d:WriteFloat(v.Y)
		end,
		function(d)
			local x = d:ReadFloat()
			local y = d:ReadFloat()
			return Rotation(x, y, 0)
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
	local cursorLengthField = d.Cursor
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
		d:WriteString(value[1]) -- no need to write size because all keys are 3 letters
		local serializeFunction = value[3]
		serializeFunction(d, value[2])
	end

	local size = d.Cursor - cursorLengthField
	d.Cursor = cursorLengthField
	d:WriteUInt16(size)
	d.Cursor = d.Length

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

-- grouping objects by fullname
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
	local cursorLengthField = d.Cursor
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
			local cursorNbFields = d.Cursor
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
			if object.Physics ~= nil then
				d:WriteString("pm")
				d:WritePhysicsMode(object.Physics)
				nbFields = nbFields + 1
			end

			-- jump back to set nbFields value
			d.Cursor = cursorNbFields
			d:WriteUInt8(nbFields)
			d.Cursor = d.Length
		end
	end

	local size = d.Cursor - cursorLengthField
	d.Cursor = cursorLengthField
	d:WriteUInt32(size)
	d.Cursor = d.Length

	return true
end

local readChunkObjectsV2 = function(d)
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

local readChunkBlocks = function(d)
	local blocks = {}
	d:ReadUInt16()
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
	return d:ToString({ format = "base64" })
end

local deserializeWorldBase64 = function(str)
	local d = Data(str, { format = "base64" })
	local version = d:ReadByte()
	local world = {}
	if version == 2 or version == 3 then
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

common.uuidv4 = function()
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	return string.gsub(template, "[xy]", function(c)
		local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
		return string.format("%x", v)
	end)
end

local loadObject = function(obj, objInfo, config)
	obj:SetParent(World)
	local k = Box()
	k:Fit(obj, true)
	obj.Pivot = Number3(obj.Width / 2, k.Min.Y + obj.Pivot.Y, obj.Depth / 2)

	local scale = objInfo.Scale or 0.5
	local boxSize = k.Size * scale
	local turnOnShadows = config.optimisations.minimum_item_size_for_shadows_sqr
		and boxSize.SquaredLength >= config.optimisations.minimum_item_size_for_shadows_sqr
	turnOnShadows = true

	require("hierarchyactions"):applyToDescendants(obj, { includeRoot = true }, function(l)
		l.Physics = objInfo.Physics or PhysicsMode.StaticPerBlock
		l.Shadow = turnOnShadows
	end)
	obj.Position = objInfo.Position or Number3(0, 0, 0)
	obj.Rotation = objInfo.Rotation or Rotation(0, 0, 0)
	obj.Scale = scale
	obj.uuid = objInfo.uuid
	obj.CollidesWithGroups = Map.CollisionGroups + Player.CollisionGroups
	obj.Name = objInfo.Name or objInfo.fullname
	obj.fullname = objInfo.fullname
end

local loadMap = function(d, n, didLoad)
	Object:Load(d, function(j)
		local map = MutableShape(j, { includeChildren = true })
		loaded.map = map

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

common.addObject = function(obj)
	if loaded == nil then
		return
	end
	if obj.uuid == nil then
		return
	end

	table.insert(loaded.world.objects, obj)
	loaded.objectsByUUID[obj.uuid] = obj
end

defaultUpdateConfig = {
	uuid = nil,
	position = nil,
	rotation = nil,
	scale = nil,
	name = nil,
	physics = nil,
}

common.updateObject = function(config)
	local ok, err = pcall(function()
		config = require("config"):merge(defaultUpdateConfig, config, {
			acceptTypes = {
				uuid = { "string" },
				position = { "Number3" },
				rotation = { "Rotation" },
				scale = { "Number3", "number", "integer" },
				name = { "string" },
				physics = { "PhysicsMode" },
			},
		})
	end)
	if not ok then
		error("world_loader:updateObject(config) - config error: " .. err, 2)
	end
	if config.uuid == nil then
		-- uuid can't be nil
		return
	end
	local objectsByUUID = loaded.objectsByUUID
	if objectsByUUID == nil then
		-- can't find objects
		return
	end
	local object = objectsByUUID[config.uuid]
	if object == nil then
		-- can't find object for uuid
		return
	end
	if config.position ~= nil then
		object.Position = config.position:Copy()
	end
	if config.rotation ~= nil then
		object.Rotation = config.rotation:Copy()
	end
	if config.scale ~= nil then
		if type(config.scale) == "Number3" then
			object.Scale = config.scale:Copy()
		else
			object.Scale = config.scale
		end
	end
	if config.physics ~= nil then
		object.Physics = config.physics
	end
	if config.name ~= nil then
		object.Name = config.name
	end
end

common.removeObject = function(uuid)
	local objectsByUUID = loaded.objectsByUUID
	local objects = loaded.world.objects
	if objectsByUUID == nil then
		-- can't find objects
		return
	end
	local obj = objectsByUUID[uuid]
	if obj == nil then
		return
	end
	objectsByUUID[uuid] = nil
	for i, o in ipairs(objects) do
		if o.uuid == uuid then
			table.remove(objects, i)
			break
		end
	end
end

common.updateAmbience = function(ambience)
	if loaded.world == nil then
		return
	end
	loaded.world.ambience = ambience
end

common.getAmbience = function()
	return loaded.world.ambience
end

local defaultLoadWorldConfig = {
	skipMap = false,
	onLoad = nil,
	onDone = nil,
	fullnameItemKey = "fullname",
	optimisations = {
		minimum_item_size_for_shadows = 1,
	},
	b64 = "",
	title = nil,
	worldID = nil,
}

common.loadWorld = function(config)
	local ok, err = pcall(function()
		config = require("config"):merge(defaultLoadWorldConfig, config, {
			acceptTypes = {
				b64 = { "string" },
				title = { "string" },
				worldID = { "string" },
				onLoad = { "function" },
				onDone = { "function" },
			},
		})
	end)
	if not ok then
		error("world_editor_common:loadWorld(config) - config error: " .. err, 2)
	end

	if #config.b64 == 0 then
		return
	end

	local world = common.deserializeWorld(config.b64)
	loaded = {
		b64 = config.b64,
		title = config.title,
		worldID = config.worldID,
		map = nil,
		world = world,
		objectsByUUID = {},
	}

	local loadObjectsBlocksAndAmbience = function()
		if config.skipMap then
			Map.Scale = world.mapScale or 5
			loaded.map = Map
		else
			if config.onLoad then
				config.onLoad(loaded.map, "Map")
			end
		end
		local map = loaded.map
		local blocks = world.blocks -- deprecated
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
		if objects then
			for i, o in ipairs(objects) do
				if o.uuid then
					loaded.objectsByUUID[o.uuid] = o
				end
			end

			local minimum_item_size_for_shadows = config.optimisations.minimum_item_size_for_shadows
			if minimum_item_size_for_shadows ~= nil then
				config.optimisations.minimum_item_size_for_shadows_sqr = minimum_item_size_for_shadows
					* minimum_item_size_for_shadows
			end
			local massLoading = require("massloading")
			local onLoad = function(obj, data)
				loadObject(obj, data, config)
				config.onLoad(obj, data)
			end
			local massLoadingConfig = {
				onDone = config.onDone,
				onLoad = onLoad,
				fullnameItemKey = "fullname",
			}
			massLoading:load(objects, massLoadingConfig)
		end
		if ambience then
			require("ai_ambience"):loadGeneration(ambience)
		end
		if not objects then
			config.onDone()
		end
	end
	if not config.skipMap then
		loadMap(world.mapName, world.mapScale, loadObjectsBlocksAndAmbience)
	else
		loadObjectsBlocksAndAmbience()
	end
end

common.saveWorld = function()
	if loaded.world == nil then
		return
	end
	local b64 = serializeWorldBase64(loaded.world)
	if b64 ~= loaded.b64 then
		loaded.b64 = b64
		print("SAVING...")
		require("system_api", System):patchWorld(loaded.worldID, { mapBase64 = b64 }, function(err, world)
			if world and world.mapBase64 == b64 then
				print(loaded.title .. " SAVED")
			else
				if err then
					print("Error while saving world: ", JSON:Encode(err))
				else
					print("Error while saving world")
				end
			end
		end)
	else
		print("NO CHANGES")
	end
end

return common
