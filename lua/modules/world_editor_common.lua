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
	"claire.voxowl_hq"
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

local writeChunkMap = function(d, name, scale)
	if name == nil or scale == nil then print("Error: can't serialize map") return false end
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

local writeChunkBase64 = function(d, chunkId, chunkTable)
	if chunkTable == nil then print("Error: can't serialize chunk", chunkId) return false end
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

local SERIALIZE_VERSION = 1
-- Content: versionId, chunkMap that can be read from cpp, then 3 table serialized as base64 chunks

local serializeWorldBase64 = function(world)
	if not world.mapName then print("Can't serialize without mapName") return end
	local d = Data()
	d:WriteByte(SERIALIZE_VERSION) -- version
	writeChunkMap(d, world.mapName, world.mapScale or 5)
	writeChunkBase64(d, SERIALIZED_CHUNKS_ID.AMBIENCE, world.ambience or require("ambience").noon)
	writeChunkBase64(d, SERIALIZED_CHUNKS_ID.OBJECTS, world.objects or {})
	writeChunkBase64(d, SERIALIZED_CHUNKS_ID.BLOCKS, world.blocks or {})
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
	local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
	return string.gsub(template, '[xy]', function (c)
		local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
		return string.format('%x', v)
	end)
end

local loadObject = function(objInfo, didLoad)
    Object:Load(
        objInfo.fullname,
        function(obj)
            obj:SetParent(World)
            local k = Box()
            k:Fit(obj, true)
            obj.Pivot = Number3(obj.Width / 2, k.Min.Y + obj.Pivot.Y, obj.Depth / 2)
            require("hierarchyactions"):applyToDescendants(
                obj,
                {includeRoot = true},
                function(l)
                    l.Physics = objInfo.Physics or PhysicsMode.StaticPerBlock
                end
            )
            obj.Position = objInfo.Position or Number3(0, 0, 0)
            obj.Rotation = objInfo.Rotation or Rotation(0, 0, 0)
            obj.Scale = objInfo.Scale or 0.5
            obj.CollidesWithGroups = Map.CollisionGroups + Player.CollisionGroups
            obj.Name = objInfo.Name or objInfo.fullname
            if didLoad then didLoad(obj) end
        end
    )
end

local loadMap = function(d, n, didLoad)
    Object:Load(
        d,
        function(j)
            map = MutableShape(j, {includeChildren = true})
            map.Scale = n or 5
            require("hierarchyactions"):applyToDescendants(map, { includeRoot = true },
                function(o)
                    o.CollisionGroups = Map.CollisionGroups
                    o.CollidesWithGroups = Map.CollidesWithGroups
                    o.Physics = PhysicsMode.StaticPerBlock
                end
            )
            map:SetParent(World)
            map.Position = {0, 0, 0}
            map.Pivot = {0, 0, 0}
            if didLoad then
                didLoad()
            end
        end
    )
end

common.loadWorld = function(mapBase64, config)
    if #mapBase64 == 0 then
        return
    end
    local world = common.deserializeWorld(mapBase64)
    local loadObjectsBlocksAndAmbience = function()
        if config.skipMap then
            Map.Scale = world.mapScale
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
                if w then w:Remove() end
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
        if ambience then require("ui_ai_ambience"):setFromAIConfig(ambience, true) end
    end
    if not config.skipMap then
        loadMap(world.mapName, world.mapScale, loadObjectsBlocksAndAmbience)
    else
        loadObjectsBlocksAndAmbience()
    end
end

return common
