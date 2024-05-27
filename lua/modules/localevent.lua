--[[
LocalEvent code. (https://docs.cu.bzh/reference/localevent)

A listener callback can return true to capture an event,
and avoid triggering following ones on the same even name.
]]
--

-- indexed by event name,
-- each entry contains listeners in insertion order
listeners = {}

-- indexed by event name,
-- each entry contains listeners in insertion order
topPrioritySystemListeners = {}

localevent = {}

mt = {
	__tostring = function()
		return "[LocalEvent]"
	end,
	__type = "LocalEvent",
}
setmetatable(localevent, mt)

-- A list of reserved platform event names.
-- Event names can be anything (any variable, of any type)
localevent.name = {
	Tick = 1,
	AvatarLoaded = 2,
	KeyboardInput = 3, -- callback: function(char, keyCode, modifiers, down)
	VirtualKeyboardShown = 4, -- callback: function(keyboardHeight)
	VirtualKeyboardHidden = 5, -- callback: function()
	ScreenDidResize = 6, -- callback: function(width, height)
	ClientFieldSet = 7, -- callback: function(fieldName)
	PointerShown = 8, -- callback: function()
	PointerHidden = 9, -- callback: function()
	PointerDown = 10,
	PointerUp = 11,
	PointerDragBegin = 12,
	PointerDrag = 13,
	PointerDragEnd = 14,
	HomeMenuOpened = 15,
	HomeMenuClosed = 16,
	PointerClick = 17, -- down then up without moving
	PointerWheel = 18, -- callback function: function(delta)
	PointerCancel = 19, -- happens when pointer leaves the screen without proper release event
	PointerLongPress = 20,
	PointerMove = 21, -- happens only with a mouse
	Action1Set = 22, -- called when Client.Action1 is set, callback: function(fn) (fn can be nil)
	Action2Set = 23, -- called when Client.Action2 is set, callback: function(fn) (fn can be nil)
	Action3Set = 24, -- called when Client.Action3 is set, callback: function(fn) (fn can be nil)
	Action1ReleaseSet = 25, -- called when Client.Action1Release is set, callback: function(fn) (fn can be nil)
	Action2ReleaseSet = 26, -- called when Client.Action2Release is set, callback: function(fn) (fn can be nil)
	Action3ReleaseSet = 27, -- called when Client.Action3Release is set, callback: function(fn) (fn can be nil)
	DirPadSet = 28,
	AnalogPadSet = 29,
	AnalogPad = 30, -- callback function: function(dx,dy)
	DirPad = 31, -- callback function: function(x,y) x & y between -1 & 1
	-- CloseChat = 32, -- REMOVED AFTER 0.0.53
	OnPlayerJoin = 33,
	OnPlayerLeave = 34,
	DidReceiveEvent = 35,
	InfoMessage = 36,
	WarningMessage = 37,
	ErrorMessage = 38,
	SensitivityUpdated = 39,
	OnChat = 40, -- triggered when a chat message is submitted by the local user
	-- SetChatTextInput = 41, -- REMOVED AFTER 0.0.53
	CppMenuStateChanged = 42, -- needed while Cubzh still uses a few C++ menus (code editor & multiline inputs)
	LocalAvatarUpdate = 43,
	ReceivedEnvironmentToLaunch = 44,
	-- ChatMessage can only be sent by system.
	-- callback: function(message, sender, status, uuid, localUUID) -- status: "pending", "error", "ok", "reported"
	ChatMessage = 45,
	FailedToLoadWorld = 46, -- callback: function(msgInfo)
	ServerConnectionSuccess = 47,
	ServerConnectionLost = 48,
	ServerConnectionFailed = 49,
	ServerConnectionStart = 50, -- called when starting to establish connection
	OnWorldObjectLoad = 51,
	Log = 52, -- callback({type = info(1)|warning(2)|error(3), message = "...", date = "%m-%d-%YT%H:%M:%SZ"})
	ChatMessageACK = 53, -- callback: function(uuid, localUUID, status) -- status: "error", "ok", "reported"
	ActiveTextInputUpdate = 54, -- callback: function(string, cursorStart, cursorEnd)
	ActiveTextInputClose = 55, -- callback: function()
	ActiveTextInputDone = 56, -- callback: function()
	ActiveTextInputNext = 57, -- callback: function()
}
localevent.Name = localevent.name

local limited = {}
limited[localevent.name.Tick] = true
limited[localevent.name.AvatarLoaded] = true
limited[localevent.name.KeyboardInput] = true
limited[localevent.name.VirtualKeyboardShown] = true
limited[localevent.name.VirtualKeyboardHidden] = true
limited[localevent.name.ScreenDidResize] = true
limited[localevent.name.ClientFieldSet] = true
limited[localevent.name.PointerShown] = true
limited[localevent.name.PointerHidden] = true
limited[localevent.name.PointerDown] = true
limited[localevent.name.PointerUp] = true
limited[localevent.name.PointerClick] = true
limited[localevent.name.PointerDragBegin] = true
limited[localevent.name.PointerDrag] = true
limited[localevent.name.PointerDragEnd] = true
limited[localevent.name.HomeMenuOpened] = true
limited[localevent.name.HomeMenuClosed] = true
limited[localevent.name.PointerWheel] = true
limited[localevent.name.PointerCancel] = true
limited[localevent.name.PointerLongPress] = true
limited[localevent.name.PointerMove] = true
limited[localevent.name.Action1Set] = true
limited[localevent.name.Action2Set] = true
limited[localevent.name.Action3Set] = true
limited[localevent.name.Action1ReleaseSet] = true
limited[localevent.name.Action2ReleaseSet] = true
limited[localevent.name.Action3ReleaseSet] = true
limited[localevent.name.DirPadSet] = true
limited[localevent.name.AnalogPadSet] = true
limited[localevent.name.AnalogPad] = true
limited[localevent.name.DirPad] = true
limited[localevent.name.OnPlayerJoin] = true
limited[localevent.name.OnPlayerLeave] = true
limited[localevent.name.DidReceiveEvent] = true
limited[localevent.name.InfoMessage] = true
limited[localevent.name.WarningMessage] = true
limited[localevent.name.ErrorMessage] = true
limited[localevent.name.OnChat] = true
limited[localevent.name.CppMenuStateChanged] = true
limited[localevent.name.LocalAvatarUpdate] = true
limited[localevent.name.OnWorldObjectLoad] = true

reservedToSystem = {}
reservedToSystem[localevent.name.KeyboardInput] = true
reservedToSystem[localevent.name.LocalAvatarUpdate] = true
reservedToSystem[localevent.name.ServerConnectionSuccess] = true
reservedToSystem[localevent.name.ServerConnectionLost] = true
reservedToSystem[localevent.name.ServerConnectionFailed] = true
reservedToSystem[localevent.name.ServerConnectionStart] = true
reservedToSystem[localevent.name.ChatMessage] = true
reservedToSystem[localevent.name.ChatMessageACK] = true

mt = {
	__tostring = function()
		return "[LocalEventName]"
	end,
	__type = "LocalEventName",
}
setmetatable(localevent.name, mt)

-- returns true if event has been consumed, false otherwise
local sendEventToListeners = function(self, listenersArray, name, ...)
	if self ~= localevent then
		error("LocalEvent.sendEventToListeners must receive module as 1st argument")
	end

	local listeners = listenersArray[name]
	if listeners == nil then
		-- Not a single listener for this event name,
		-- so the event could not have been consumed.
		return false
	end

	local args = { ... }
	local captured = false
	local listener
	local err
	local listenersToRemove = {}
	local isSystemProvided = false

	-- extract `System` from `args` if present
	if args[1] == System then
		isSystemProvided = true
		local newArgs = {}
		for i, v in ipairs(args) do
			if i > 1 then
				table.insert(newArgs, v)
			end
		end
		args = newArgs
	end

	-- check if System is required to notify listeners
	if reservedToSystem[name] == true and isSystemProvided == false then
		error("not allowed to send this localevent without access to System", 3)
	end

	for i = 1, #listeners do -- why not using ipairs?
		listener = listeners[i]
		if not listener.paused then
			if listener.callback ~= nil then
				if limited[name] then
					err, captured = Dev:ExecutionLimiter(function()
						-- return 1,2,3 -- limiterStart returns nil, 1, 2, 3
						return listener.callback(table.unpack(args))
					end)

					if err then
						if listener.system == true then
							-- only display error if system listener, do not remove
							print("❌", err)
						else
							-- remove listener + display error
							table.insert(listenersToRemove, listener)
							print("❌", err, "(function disabled)")
						end
						goto continue -- continue for loop
					end
				else
					captured = listener.callback(table.unpack(args))
				end

				if captured == true then
					break
				end -- event captured, exit!

				::continue::

				-- else
				-- TODO: remove listeners with nil callbacks
			end
		end
	end

	-- remove listeners that have been flagged
	for _, listener in ipairs(listenersToRemove) do
		listener:Remove()
	end

	return captured
end

--
localevent.Send = function(self, name, ...)
	if self ~= localevent then
		error("LocalEvent:Send should be called with `:`", 2)
	end

	local args = { ... }

	-- dispatch event to SYSTEM listeners
	local captured = sendEventToListeners(self, topPrioritySystemListeners, name, table.unpack(args))
	if captured == true then
		return captured
	end

	-- dispatch event to REGULAR listeners
	captured = sendEventToListeners(self, listeners, name, table.unpack(args))

	return captured
end
localevent.send = localevent.Send

-- ------------------------------
-- (REGULAR) LISTENER
-- ------------------------------

local listenerMT = {
	__tostring = function()
		return "[LocalEventListener]"
	end,
	__type = "LocalEventListener",
	__index = {
		Remove = function(self)
			local matchingListeners = listeners[self.name]
			if matchingListeners ~= nil then
				for i, listener in ipairs(matchingListeners) do
					if listener == self then
						table.remove(matchingListeners, i)
						break
					end
				end
			end
		end,
		Pause = function(self)
			self.paused = true
		end,
		Resume = function(self)
			self.paused = false
		end,
	},
}
listenerMT.__index.remove = listenerMT.__index.Remove
listenerMT.__index.pause = listenerMT.__index.Pause
listenerMT.__index.resume = listenerMT.__index.Resume

-- metatable for top priority System listeners
local topPrioritySystemListenerMT = {
	__tostring = function()
		return "[LocalEventSystemListener]"
	end,
	__type = "LocalEventSystemListener",
	__index = {
		Remove = function(self)
			local matchingListeners = topPrioritySystemListeners[self.name]
			if matchingListeners ~= nil then
				for i, listener in ipairs(matchingListeners) do
					if listener == self then
						table.remove(matchingListeners, i)
						break
					end
				end
			end
		end,
		Pause = function(self)
			self.paused = true
		end,
		Resume = function(self)
			self.paused = false
		end,
	},
}
topPrioritySystemListenerMT.__index.remove = topPrioritySystemListenerMT.__index.Remove
topPrioritySystemListenerMT.__index.pause = topPrioritySystemListenerMT.__index.Pause
topPrioritySystemListenerMT.__index.resume = topPrioritySystemListenerMT.__index.Resume

-- config is optional
-- config.topPriority can be used to insert listener in front of others
-- (can't prevent other top priority listeners to be added in front afterwards)
-- LocalEvent:Listen("eventName", callback, { topPriority = true })
-- config.system can be set to System table to register listener as "system listener".
localevent.Listen = function(self, name, callback, config)
	if self ~= localevent then
		error("LocalEvent:Listen should be called with `:`", 2)
	end
	if type(callback) ~= "function" then
		error("LocalEvent:Listen - callback should be a function", 2)
	end

	local listener = { name = name, callback = callback, system = config.system == System }

	-- top priority System listeners
	if listener.system == true and config.topPriority == true then
		setmetatable(listener, topPrioritySystemListenerMT)

		if topPrioritySystemListeners[name] == nil then
			topPrioritySystemListeners[name] = {}
		end

		-- always insert top priority system listeners in front
		table.insert(topPrioritySystemListeners[name], 1, listener)
	else
		setmetatable(listener, listenerMT)

		if listeners[name] == nil then
			listeners[name] = {}
		end

		if config.topPriority == true then
			table.insert(listeners[name], 1, listener)
		else
			table.insert(listeners[name], listener)
		end
	end

	return listener
end
localevent.listen = localevent.Listen

return localevent
