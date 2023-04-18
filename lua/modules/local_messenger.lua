--[[
How to use:

messenger = require("local_messenger")

local someTable = {}

local callback = function(recipient, name, data)

messenger:addRecipient(someTable, "message_name", callback)

messenger:send("message_name", {foo = "bar"})

]]--

local messenger = {
	listenersForMessageNames = {}, -- indexed by message name
	listeners = {}, -- indexed by listener ref, contains all name listened
}

messenger.send = function(self, name, data)
	if self.listenersForMessageNames[name] == nil then return end

	for listener, callback in pairs(self.listenersForMessageNames[name]) do
		callback(listener, name, data)
	end
end

messenger.addRecipient = function(self, listener, name, callback)
	if self.listeners[listener] == nil then
		self.listeners[listener] = {}
	end
	self.listeners[listener][name] = true

	if self.listenersForMessageNames[name] == nil then
		self.listenersForMessageNames[name] = {}
	end

	self.listenersForMessageNames[name][listener] = callback
end

messenger.removeRecipient = function(self, listener)
	if self.listeners[listener] == nil then return end

	for name, _ in pairs(self.listeners[listener]) do
		self.listenersForMessageNames[name][listener] = nil
	end

	self.listeners[listener] = nil
end

return messenger