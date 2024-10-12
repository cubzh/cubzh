--- A module to access World leaderboards.
--- Each leaderboard can only contain one score per player.
--- A World can have several leaderboards.
--- Content from "default" leaderboard will be shown on World description screen.
---@code
--- leaderboard = require("leaderboard")
--- local scores = leaderboard("default")
--- -- `value` can be anything that can be serialized (string, number, boolean, table, Data, etc.)
--- scores:set({ score = 12345, value = value, })
--- local req = scores:get({ friends = true })
--- local req = scores:get({ friends = true, limit = 5, mode = "best" })
--- local req = scores:get({ limit = 10 })

local mod = {}

local conf = require("config")

local privateFields = setmetatable({}, { __mode = "k" })

local get = function(leaderboard, config)
	local fields = privateFields[leaderboard]
	if fields == nil then
		error("leaderboard:get(config) should be called with `:`", 2)
		return
	end

	local defaultConfig = {
		mode = "best", -- "best", "neighbors"
		limit = 20,
		friends = false,
		callback = nil,
	}

	local ok, err = pcall(function()
		config = conf:merge(defaultConfig, config, {
			acceptTypes = {
				callback = { "function" },
			},
		})
	end)
	if not ok then
		error("leaderboard:get(config) - config error: " .. err, 2)
	end

	-- HTTP REQUEST
end

-- leaderboard:set({
--	score = 123,
--	value = { stat1 = 42.0 },
-- 	callback = function(success)
--		print("success:", success)
-- 	end,
-- })
local set = function(leaderboard, config)
	local fields = privateFields[leaderboard]
	if fields == nil then
		error("leaderboard:get(config) should be called with `:`", 2)
		return
	end

	local defaultConfig = {
		score = nil,
		value = nil,
		override = false,
		callback = nil,
	}

	local ok, err = pcall(function()
		config = conf:merge(defaultConfig, config, {
			acceptTypes = {
				score = { "number", "integer" },
				value = { "*" },
				callback = { "function" },
			},
		})
	end)
	if not ok then
		error("leaderboard:set(config) - config error: " .. err, 2)
	end

	if config.score == nil then
		error("leaderboard:set(config) - config.score can't be nil: " .. err, 2)
	end
	config.score = math.floor(config.score)

	local body
	ok, err = pcall(function()
		body = JSON:Encode({
			score = config.score,
			value = config.value,
			override = config.override,
		})
	end)
	if not ok then
		error("leaderboard:set(config) - could not encode score: " .. err, 2)
	end

	local url = "/leaderboards/" .. System.WorldID .. "/" .. leaderboard.name .. "/" .. Player.UserID

	local req = System:HttpPost(url, body, function(res)
		if res.StatusCode ~= 200 then
			if config.callback then
				config.callback(false)
			end
			return
		end
		if config.callback then
			config.callback(true)
		end
	end)

	return req
end

local remove = function(leaderboard)
	local fields = privateFields[leaderboard]
	if fields == nil then
		error("leaderboard:get(config) should be called with `:`", 2)
		return
	end

	-- HTTP REQUEST
end

local metatable = {
	__tostring = function(_)
		return "[Leaderboard (module)]"
	end,
	__call = function(_, leaderboardName)
		if type(leaderboardName) ~= "string" then
			error("leaderboard(name) - name should be a string", 2)
		end
		-- return a store object
		local leaderboard = {
			name = leaderboardName,
			get = get,
			set = set,
			remove = remove,
		}
		setmetatable(leaderboard, {
			__tostring = function(self)
				return "[Leaderboard: " .. self.name .. "]"
			end,
		})
		privateFields[leaderboard] = {}
		return leaderboard
	end,
}

setmetatable(mod, metatable)

mod.Debug = function(self, obj)
	return System:Debug(obj)
end

return mod
