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
	KeyboardInput = 3, -- callback: function(char, keyCode, modifiers, state)
	VirtualKeyboardShown = 4, -- callback: function(keyboardHeight)
	VirtualKeyboardHidden = 5, -- callback: function()
}
localevent.Name = localevent.name

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
	local r
	for _, listener in ipairs(listeners) do
		if not listener.paused then
			r = listener.callback(table.unpack(args))
			if r == true then break end -- event captured, exit!
		end
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