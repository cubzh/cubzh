local worldEditorCommon = require("world_editor_common")
local MAP_SCALE_DEFAULT = worldEditorCommon.MAP_SCALE_DEFAULT
local events = worldEditorCommon.events
local serializeWorld = worldEditorCommon.serializeWorld

local serverObjects = {}
local blocks = {}
local mapName
local mapScale = MAP_SCALE_DEFAULT

local master

local getObjects = function()
	local t = {}
	for _, v in pairs(serverObjects) do
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
		objects = getObjects(),
	}
end

local sendSaveWorld = function(sender)
	LocalEvent:Send(
		LocalEvent.Name.DidReceiveEvent,
		{ a = events.SAVE_WORLD, data = { mapBase64 = serializeWorld(getWorldState()) }, pID = Player.ID }
	)
end

local funcs = {
	[events.P_END_PREPARING] = function(sender, data)
		if sender ~= master then
			print("You can't do that")
			return
		end
		mapName = data.mapName
		return data
	end,
	[events.P_SET_MAP_SCALE] = function(sender, data)
		local ratio = data.mapScale / mapScale
		for _, o in pairs(serverObjects) do
			o.Scale = o.Scale * ratio
			o.Position = o.Position * ratio
		end
		mapScale = data.mapScale
		sendSaveWorld(sender)
		return data
	end,
	[events.P_SET_MAP_OFFSET] = function(sender, data)
		local offset = data.offset
		-- shift all objects
		for _, o in pairs(serverObjects) do
			o.Position = o.Position + offset
		end
		sendSaveWorld(sender)
		return data
	end,
	[events.P_RESET_ALL] = function(_, data)
		mapName = nil
		mapScale = MAP_SCALE_DEFAULT
		serverObjects = {}
		blocks = {}
		return data
	end,
}

local server = {}

serverObjects = {}
blocks = {}
mapName = nil
mapScale = MAP_SCALE_DEFAULT

master = Player
server.sendToServer = function(event, data)
	local func = funcs[event]
	local targets = Players
	if func then
		data, targets = func(Player, data)
	end

	if targets == -1 then
		return
	end
	LocalEvent:Send(LocalEvent.Name.DidReceiveEvent, { a = string.sub(event, 2, #event), data = data, pID = Player.ID })
end

return server
