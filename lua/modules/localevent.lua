--[[
LocalEvent code. (https://docs.cu.bzh/reference/localevent)

A listener callback can return true to capture an event, 
and avoid triggering following ones on the same even name.
]]--

local localevent = {
	-- indexed by event name,
	-- each entry contains listeners in insertion order
	listeners = {},
}

local mt = {
	__tostring = function() return "[LocalEvent]" end,
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
	OpenChat = 17, -- sent when user requires chat input to be opened
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
	CloseChat = 32,
	OnPlayerJoin = 33,
	OnPlayerLeave = 34,
	DidReceiveEvent = 35,
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
limited[localevent.name.PointerDragBegin] = true
limited[localevent.name.PointerDrag] = true
limited[localevent.name.PointerDragEnd] = true
limited[localevent.name.HomeMenuOpened] = true
limited[localevent.name.HomeMenuClosed] = true
limited[localevent.name.OpenChat] = true
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
limited[localevent.name.CloseChat] = true
limited[localevent.name.OnPlayerJoin] = true
limited[localevent.name.OnPlayerLeave] = true
limited[localevent.name.DidReceiveEvent] = true
-- limited[localevent.name.InfoMessage] = true
-- limited[localevent.name.WarningMessage] = true
-- limited[localevent.name.ErrorMessage] = true

mt = {
	__tostring = function() return "[LocalEventName]" end,
	__type = "LocalEventName",
}
setmetatable(localevent.name, mt)

localevent.Send = function(self, name, ...)
	if self ~= localevent then error("LocalEvent:Send should be called with `:`", 2) end

	local listeners = self.listeners[name]
	if listeners == nil then return end

	local args = {...}
	local captured
	local listener
	local err = nil
	local listenersToRemove = {}
	for i = 1,#listeners do
		listener = listeners[i]
		if not listener.paused then
			if listener.callback then

				if limited[name] then

					err, captured = Dev:ExecutionLimiter(function()
						-- return 1,2,3 -- limiterStart returns nil, 1, 2, 3
						return listener.callback(table.unpack(args))
					end)

					if err then
						-- remove listener + display error
						-- ⚠️ flag for removal, but remove after loop
						print("❌", err, "(function disabled)")
						table.insert(listenersToRemove, listener)
						goto continue -- continue for loop
					end

				else
					captured = listener.callback(table.unpack(args))
				end

				if captured == true then break end -- event captured, exit!

				::continue::
			else
				-- TODO: remove listeners with nil callbacks
			end
		end
	end

	-- remove listeners that have been flagged
	for _, listener in ipairs(listenersToRemove) do
		listener:Remove()
	end

end
localevent.send = localevent.Send

local listenerMT = {
	__tostring = function(t) return "[LocalEventListener]" end,
	__type = "LocalEventListener",
	__index = {
		Remove = function(self) 
			local listeners = localevent.listeners[self.name]
			if listeners ~= nil then
				for i, listener in ipairs(listeners) do 
					if listener == self then	
						table.remove(listeners, i)
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

-- config is optional
-- config.topPriority can be used to insert listener in front of others
-- (can't prevent other top priority listeners to be added in front afterwards)
-- LocalEvent:Listen("eventName", callback, { topPriority = true })
localevent.Listen = function(self, name, callback, config)
	if self ~= localevent then error("LocalEvent:Listen should be called with `:`", 2) end
	if type(callback) ~= "function" then error("LocalEvent:Listen - callback should be a function", 2) end

	local listener = {name = name, callback = callback}
	setmetatable(listener, listenerMT)

	if self.listeners[name] == nil then
		self.listeners[name] = {}
	end

	if config.topPriority == true then
		table.insert(self.listeners[name], 1, listener)
	else
		table.insert(self.listeners[name], listener)
	end

	return listener
end
localevent.listen = localevent.Listen

return localevent