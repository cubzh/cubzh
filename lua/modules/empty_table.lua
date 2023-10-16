-- This module allows to create empty tables that are displaying custom messages
-- when accessed for the first time.	-- This is very useful to replace deprecated tables that will not instantly raise errors when used.
-- Displayed messages are warnings by default, prefixed by ⚠️.	-- But other message types are supported: "log", "warning", "error"
-- Giving a messageType parameter is optional when calling emptyTable:create. (default to "warning")
-- t = emptyTable:create("my message") t = emptyTable:create("my message", "log")
-- When the message type is "error", the table raises an error when accessed.

local emptyTable = {}

local function printMessageOnFirstAccess(t)
	if t.__accessed == false then
		if t.__messageType == "log" then
			print(t.__message)
		elseif t.__messageType == "error" then
			error(t.__message, 2)
		else
			print("⚠️ " .. t.__message)
		end
		t.__accessed = true
	end
end

local mt = {
	-- __index returns empty table to avoid errors to happen down the road:
	-- print(emptyTable.foo) -- message displayed, but no error
	-- emptyTable.foo = "coucou" -- message displayed, but would raise an error on set
	-- if foo was not returned as am empty table itself.
	__index = function(t)
		printMessageOnFirstAccess(t)
		return t
	end,
	__newindex = function(t)
		printMessageOnFirstAccess(t)
	end,
	__call = function(t)
		printMessageOnFirstAccess(t)
	end,
	__add = function(t)
		printMessageOnFirstAccess(t)
		return t
	end,
	__sub = function(t)
		printMessageOnFirstAccess(t)
		return t
	end,
	__unm = function(t)
		printMessageOnFirstAccess(t)
		return t
	end,
	__mul = function(t)
		printMessageOnFirstAccess(t)
		return t
	end,
	__div = function(t)
		printMessageOnFirstAccess(t)
		return t
	end,
	__idiv = function(t)
		printMessageOnFirstAccess(t)
		return t
	end,
	__pow = function(t)
		printMessageOnFirstAccess(t)
		return t
	end,
	__eq = function(t)
		printMessageOnFirstAccess(t)
		return false
	end,
	__pairs = function(t)
		printMessageOnFirstAccess(t)
	end,
	__tostring = function(t)
		printMessageOnFirstAccess(t)
		return ""
	end,
	__metatable = function()
		return false
	end,
}

emptyTable.create = function(_, message, _)
	local t = { __accessed = false, __message = message, __messageType = "warning" }
	setmetatable(t, mt)
	return t
end

return emptyTable
