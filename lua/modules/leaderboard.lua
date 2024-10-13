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
local time = require("time")
local url = require("url")

local API_ADDR = "https://api.cu.bzh"

local privateFields = setmetatable({}, { __mode = "k" })

-- leaderboard:get({
-- 	friends = true,
--  mode = "neighbors", -- options: "best", "neighbors"
-- 	limit = 20,
--  callback = function(scores, err)
-- })
-- scores:
-- [{"userID":"4d558bc1-5700-4a0d-8c68-f05e0b97f3fd","score":72046,"value":"BgVtaWxlcwGS7+nqOXnePw==","updated":"2024-10-12T17:17:02.385Z"}]
-- scores.user (if not nil) is a reference to local user's score.
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
		-- userID: can be nil, "self" or a user ID
		-- nil by default, ignores other configuration fields when set and returns only one score.
		userID = nil,
		callback = nil,
	}

	local ok, err = pcall(function()
		config = conf:merge(defaultConfig, config, {
			acceptTypes = {
				userID = { "string" },
				callback = { "function" },
			},
		})
	end)
	if not ok then
		error("leaderboard:get(config) - config error: " .. err, 2)
	end

	local u

	if config.userID ~= nil then
		u = url:parse(API_ADDR .. "/leaderboards/" .. System.WorldID .. "/" .. leaderboard.name .. "/" .. config.userID)
	else
		u = url:parse(API_ADDR .. "/leaderboards/" .. System.WorldID .. "/" .. leaderboard.name)
		u:addQueryParameter("mode", config.mode)
		u:addQueryParameter("limit", math.floor(config.limit))
		u:addQueryParameter("friends", config.friends and "true" or "false")
	end

	local req = System:HttpGet(u:toString(), function(res)
		if res.StatusCode ~= 200 then
			if config.callback then
				config.callback(nil, "status code: " .. res.StatusCode)
			end
			return
		end
		if config.callback then
			-- print("RES:", res.Body:ToString())

			if config.userID ~= nil then -- one score
				local score = JSON:Decode(res.Body)
				if err ~= nil then
					if config.callback then
						config.callback(nil, "internal server error")
					end
					return
				end
				if config.callback then
					if score.value ~= nil then
						score.value = Data(score.value, { format = "base64" }):Decode()
					end
					if score.updated then
						score.updated = time.iso8601_to_os_time(score.updated)
					end
					config.callback(score)
				end
			else -- array of scores
				local scores, err = JSON:Decode(res.Body)
				if err ~= nil then
					if config.callback then
						config.callback(nil, "internal server error")
					end
					return
				end

				if config.callback then
					table.sort(scores, function(a, b)
						return a.score > b.score -- descending order
					end)
					for _, s in ipairs(scores) do
						if s.userID == Player.UserID then
							scores.user = s
						end
						if s.value ~= nil then
							s.value = Data(s.value, { format = "base64" }):Decode()
						end
						if s.updated then
							s.updated = time.iso8601_to_os_time(s.updated)
						end
					end
					config.callback(scores)
				end
			end
		end
	end)

	return req
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

	local valueB64 = nil
	if config.value ~= nil then
		local valueData = Data(config.value)
		valueB64 = valueData:ToString({ format = "base64" })
	end

	local body
	ok, err = pcall(function()
		body = JSON:Encode({
			score = config.score,
			value = valueB64,
			override = config.override,
		})
	end)
	if not ok then
		error("leaderboard:set(config) - could not encode score: " .. err, 2)
	end

	local u = url:parse(API_ADDR .. "/leaderboards/" .. System.WorldID .. "/" .. leaderboard.name)

	local req = System:HttpPost(u:toString(), body, function(res)
		-- print("STATUS:", res.StatusCode)
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

return mod
