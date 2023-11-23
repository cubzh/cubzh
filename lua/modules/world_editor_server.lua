local FAKE_SERVER = true

local worldEditorCommon = require("world_editor_common")
local MAP_SCALE_DEFAULT = worldEditorCommon.MAP_SCALE_DEFAULT
local events = worldEditorCommon.events
local serializeWorld = worldEditorCommon.serializeWorld
local deserializeWorld = worldEditorCommon.deserializeWorld
local posToStr = worldEditorCommon.posToStr
local uuidv4 = worldEditorCommon.uuidv4

local serverObjects = {}
local blocks = {}
local playerActivity = {}
local ambience = nil
local mapName
local mapScale = MAP_SCALE_DEFAULT

local master

local getBlocksChanges = function()
	local t = {}
	for k,v in pairs(blocks) do
		if v ~= nil then
			table.insert(t, { k, v })
		end
	end
	return t
end

local getObjects = function()
	local t = {}
	for _,v in pairs(serverObjects) do
		if v ~= nil then
			table.insert(t, v)
		end
	end
	return t
end

local getWorldState = function()
	return {
		mapName = mapName,
		mapScale = mapScale,
		blocks = getBlocksChanges(),
		objects = getObjects(),
		ambience = ambience
	}
end

local funcs = {
	[events.P_END_PREPARING] = function(sender, data)
		if sender ~= master then print("You can't do that") return end
		mapName = data.mapName
		return data
	end,
	[events.P_PLACE_OBJECT] = function(_, data)
		data.uuid = uuidv4()
		serverObjects[data.uuid] = data
		return data
	end,
	[events.P_EDIT_OBJECT] = function(_, data)
		local obj = serverObjects[data.uuid]
		if not obj then return end
		for field,value in pairs(data) do
			obj[field] = value
		end
		return data
	end,
	[events.P_REMOVE_OBJECT] = function(_, data)
		serverObjects[data.uuid] = nil
		return data
	end,
	[events.P_PLACE_BLOCK] = function(_, data)
		blocks[posToStr(data.pos)] = data.color
		return data
	end,
	[events.P_REMOVE_BLOCK] = function(_, data)
		if blocks[posToStr(data.pos)] then
			blocks[posToStr(data.pos)] = nil
		else
			blocks[posToStr(data.pos)] = -1
		end
		return data
	end,
	[events.P_START_EDIT_OBJECT] = function(sender, data)
		if data.uuid == -1 then return data end
		playerActivity[tostring(sender.ID) .. sender.UserID] = {
			editing = data.uuid
		}
		return data
	end,
	[events.P_END_EDIT_OBJECT] = function(sender, data)
		playerActivity[tostring(sender.ID) .. sender.UserID] = {
			editing = nil
		}
		return data
	end,
	[events.P_SET_AMBIENCE] = function(_, data)
		ambience = data
		return data
	end,
	[events.P_LOAD_WORLD] = function(_, data)
		local t = deserializeWorld(data.mapBase64)
		mapName = t.mapName
		mapScale = t.mapScale or MAP_SCALE_DEFAULT
		ambience = t.ambience
		if t.objects then
			for _,o in ipairs(t.objects) do
				serverObjects[o.uuid] = o
			end
		end
		if t.blocks then
			for _,v in ipairs(t.blocks) do
				blocks[v[1]] = v[2]
			end
		end
		if FAKE_SERVER then
			LocalEvent:Send(LocalEvent.Name.DidReceiveEvent, { a = events.SYNC, data = { mapBase64 = serializeWorld(getWorldState()) }, pID = Player.ID })
		else
			local e = Event()
			e.a = events.SYNC
			e.data = { mapBase64 = serializeWorld(getWorldState()) }
			e:SendTo(Players)
		end
	end,
	[events.P_SET_MAP_SCALE] = function(_, data)
		mapScale = data.mapScale
		return data
	end,
	[events.P_RESET_ALL] = function(_, data)
		mapName = nil
		mapScale = MAP_SCALE_DEFAULT
		serverObjects = {}
        ambience = nil
		blocks = {}
		playerActivity = {}
		return data
	end,
	[events.P_SAVE_WORLD] = function(sender)
		return { mapBase64 = serializeWorld(getWorldState()) }, sender
	end,
}

local server = {}

if FAKE_SERVER then -- local server for singleplayer
    math.randomseed(Time.UnixMilli() % 10000)

    serverObjects = {}
    blocks = {}
    ambience = nil
    mapName = nil
    mapScale = MAP_SCALE_DEFAULT

    master = Player
    server.sendToServer = function(event, data)
        local func = funcs[event]
        local targets = Players
        if func then data,targets = func(Player, data) end

        if targets == -1 then return end
        LocalEvent:Send(LocalEvent.Name.DidReceiveEvent, { a = string.sub(event,2,#event), data = data, pID = Player.ID })
    end

    LocalEvent:Listen(LocalEvent.Name.OnPlayerJoin, function(p)
        if p ~= Player then return end
        LocalEvent:Send(LocalEvent.Name.DidReceiveEvent, { a = events.MASTER, data = JSON:Encode({ id=Player.ID, username=Player.Username }) })
    end)
else
    --TODO: use LocalEvents (OnPlayerJoin, DidReceiveEvent are never sent)
    --TODO: Server.OnStart in the game require world_editor_server with FAKE_SERVER=false
    Server.OnStart = function()
        math.randomseed(Time.UnixMilli() % 10000)

        Timer(3, true, function()
            local e = Event()
            e.a = events.PLAYER_ACTIVITY
            e.data = {
                activity = playerActivity
            }
            e:SendTo(Players)
        end)
    end

    Server.OnPlayerJoin = function(p)
        if not master then master = p end
        local e = Event()
        e.a = events.MASTER
        e.data = JSON:Encode({ id=master.ID, username=master.Username })
        e:SendTo(p)

        if mapName then
            local e = Event()
            e.a = events.SYNC
            e.data = { mapBase64 = serializeWorld(getWorldState()) }
            e:SendTo(p)
        end
    end

    Server.OnPlayerLeave = function(p)
        playerActivity[p.ID] = nil
        if p == master then
            print("Master player left")
            for k,p in pairs(Players) do
                print("New master is ", p.name)
                master = p
                return
            end
        end
    end

    Server.DidReceiveEvent = function(e)
        local func = funcs[e.a]
        local data = e.data
        local targets = Players
        if func then data,targets = func(e.Sender, data) end

        if targets == -1 then return end
        targets = targets or Players
        local e2 = Event()
        e2.a = string.sub(e.a,2,#e.a)
        e2.data = data
        e2.pID = e.Sender.ID
        e2:SendTo(targets)
    end

    server.sendToServer = function(event, data)
        local e = Event()
        e.a = event
        e.data = data
        e:SendTo(Server)
    end
end

return server