mod = {}

systemApi = require("system_api", System)

setmetatable(mod, {
	__newindex = function()
		error("user is read-only", 2)
	end,
	__index = {
		getUnreadNotificationCount = function(self, config)
			if self ~= mod then
				error("user:getNotificationCount() should be called with `:`", 2)
			end
			local defaultConfig = {
				callback = nil, -- function(count)
				category = nil, -- string
			}

			local ok, err = pcall(function()
				config = require("config"):merge(defaultConfig, config, {
					acceptTypes = {
						category = { "string" },
						callback = { "function" },
					},
				})
			end)

			if not ok then
				error("user:getUnreadNotificationCount(config): config error (" .. err .. ")", 2)
			end

			local req = systemApi:getNotifications(
				{ category = config.category, returnCount = true, read = false },
				function(count, err)
					if config.callback ~= nil then
						config.callback(count, err)
					end
				end
			)
			return req
		end,
	},
	__metatatable = false,
})

return mod
