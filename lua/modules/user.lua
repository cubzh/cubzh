mod = {}

setmetatable(mod, {
	__newindex = function()
		error("user is read-only", 2)
	end,
	__index = function(_, k)
		if k == "NotificationCount" then
			return System.NotificationCount
		end
	end,
	__metatatable = false,
})

return mod
