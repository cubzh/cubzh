--[[

API module

]]
--

local time = require("time")
local url = require("url")

-- TODO create url type

local mod = {
	kApiAddr = "https://api.cu.bzh", -- prod server
	-- kApiAddr = "http://192.168.1.16:10083", -- dev server
	maxWorldTitleLength = 32,
}

local errorMT = {
	__tostring = function(t)
		return t.message or ""
	end,
}

mod.error = function(_, statusCode, message)
	local err = { statusCode = statusCode, message = message }
	setmetatable(err, errorMT)
	return err
end

local function urlGetFields(url, fields)
	if fields == nil then
		return url
	end
	local firstParams = string.find(url, "?") == nil
	for i, field in ipairs(fields) do
		if i == 1 and firstParams then
			url = url .. "?f=" .. field
		else
			url = url .. "&f=" .. field
		end
	end
	return url
end

function urlAddQueryParams(url, params) -- params is an array of {key = "key", value = "value"} entries
	local s = url .. "?"
	for i, param in ipairs(params) do
		if i > 1 then
			s = s .. "&" .. param.key .. "=" .. param.value
		else
			s = s .. param.key .. "=" .. param.value
		end
	end
	return s
end

-- search Users by username substring
-- callback(ok, users, errMsg)
-- ok: boolean
-- users: []User
-- errMsg: string
mod.searchUser = function(_, searchText, callback)
	-- validate arguments
	if type(searchText) ~= "string" then
		error("api:searchUser(searchText, callback) - searchText must be a string", 2)
	end
	if type(callback) ~= "function" then
		error("api:searchUser(searchText, callback) - callback must be a function", 2)
	end

	local req = HTTP:Get(mod.kApiAddr .. "/user-search-others/" .. searchText, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, nil, "could not search users (" .. resp.StatusCode .. ")")
			return
		end
		local users, err = JSON:Decode(resp.Body)
		if err ~= nil then
			callback(false, nil, "search users decode error: " .. err)
			return
		end
		callback(true, users, nil) -- success
	end)
	return req
end

-- getFriends ...
-- callback(ok, friends, errMsg)
mod.getFriends = function(_, callback, fields, config)
	if type(callback) ~= "function" then
		error("api:getFriends(callback, [fields, config]) - callback must be a function", 2)
	end
	if fields ~= nil and type(fields) ~= "table" then
		error("api:getFriends(callback, [fields, config]) - fields must be a table or nil", 2)
	end
	if config ~= nil and type(config) ~= "table" then
		error("api:getFriends(callback, [fields, config]) - config must be a table or nil", 2)
	end

	local defaultConfig = {
		userID = "self",
	}

	config = require("config"):merge(defaultConfig, config)

	local url = mod.kApiAddr .. "/users/" .. config.userID .. "/friends"

	url = urlGetFields(url, fields)

	local req = HTTP:Get(url, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, nil, "could not get friends (" .. resp.StatusCode .. ")")
			return
		end
		local friends, err = JSON:Decode(resp.Body)
		if err ~= nil then
			callback(false, nil, "get friends decode error: " .. err)
			return
		end
		callback(true, friends, nil) -- success
	end)
	return req
end

-- getFriendCount ...
-- callback(ok, count, errMsg)
mod.getFriendCount = function(self, callback, config)
	if type(callback) ~= "function" then
		error("api:getFriendCount(callback) - callback must be a function", 2)
	end

	local req = self:getFriends(function(ok, friends, err)
		local count = 0
		if friends ~= nil then
			count = #friends
		end
		callback(ok, count, err)
	end, { "username" }, config)
	return req
end

-- getSentFriendRequests ...
-- callback(ok, reqs, errMsg)
mod.getSentFriendRequests = function(_, callback, fields)
	if type(callback) ~= "function" then
		error("api:getSentFriendRequests(callback, [fields]) - callback must be a function", 2)
		return
	end
	if fields ~= nil and type(fields) ~= "table" then
		error("api:getSentFriendRequests(callback, [fields]) - fields must be a table or nil", 2)
	end

	local url = mod.kApiAddr .. "/users/self/friend-requests?status=sent"

	url = urlGetFields(url, fields)

	local req = HTTP:Get(url, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, nil, "could not get sent requests (" .. resp.StatusCode .. ")")
			return
		end
		local requests, err = JSON:Decode(resp.Body)
		if err ~= nil then
			callback(false, nil, "get sent requests decode error: " .. err)
			return
		end
		-- success
		callback(true, requests, nil)
	end)
	return req
end

-- getReceivedFriendRequests ...
-- callback(ok, reqs, errMsg)
mod.getReceivedFriendRequests = function(_, callback, fields)
	if type(callback) ~= "function" then
		error("api:getReceivedFriendRequests(callback, [fields]) - callback must be a function", 2)
	end
	if fields ~= nil and type(fields) ~= "table" then
		error("api:getReceivedFriendRequests(callback, [fields]) - fields must be a table or nil", 2)
	end

	local url = mod.kApiAddr .. "/users/self/friend-requests?status=received"

	url = urlGetFields(url, fields)

	local req = HTTP:Get(url, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, nil, "could not get received requests (" .. resp.StatusCode .. ")")
			return
		end
		local requests, err = JSON:Decode(resp.Body)
		if err ~= nil then
			callback(false, nil, "get received requests decode error: " .. err)
			return
		end
		callback(true, requests, nil) -- success
	end)
	return req
end

-- getUserInfo gets a user by its ID
-- callback(userInfo, err)
-- success: err == nil
-- fields parameter is optional, it can be a table-- containing extra expected user fields:
-- {"created", "nbFriends"}
-- TODO: caller should have a way to check error code -> 401 means bad credentials for signup.lua (removing installed credentials)
mod.getUserInfo = function(_, id, callback, fields)
	if type(id) ~= "string" then
		error("api:getUserInfo(userID, callback, [fields]) - userID must be a string", 2)
	end
	if type(callback) ~= "function" then
		error("api:getUserInfo(userID, callback, [fields]) - callback must be a function", 2)
	end
	if fields ~= nil and type(fields) ~= "table" then
		error("api:getUserInfo(callback, [fields]) - fields must be a table or nil", 2)
	end

	local url = mod.kApiAddr .. "/users/" .. id

	url = urlGetFields(url, fields)

	local req = HTTP:Get(url, function(resp)
		if resp.StatusCode ~= 200 then
			callback(nil, mod:error(resp.StatusCode, "could not get user info (" .. resp.StatusCode .. ")"))
			return
		end
		local usr, err = JSON:Decode(resp.Body)
		if err ~= nil then
			callback(nil, mod:error(resp.StatusCode, "getUserInfo JSON decode error: " .. err))
			return
		end
		if usr.nbFriends ~= nil then
			usr.nbFriends = math.floor(usr.nbFriends)
		end
		callback(usr, nil) -- success
	end)
	return req
end

-- getMinAppVersion gets minimum app version
-- callback(error string or nil, minVersion string)
mod.getMinAppVersion = function(_, callback)
	if type(callback) ~= "function" then
		error("api:getMinAppVersion(callback) - callback must be a function", 2)
	end

	local url = mod.kApiAddr .. "/min-version"

	local req = HTTP:Get(url, function(resp)
		if resp.StatusCode ~= 200 then
			callback("could not get min app version (" .. resp.StatusCode .. ")", nil)
			return
		end
		local r, err = JSON:Decode(resp.Body)
		if err ~= nil then
			callback("get min app version decode error: " .. err, nil)
			return
		end
		if not r.version or type(r.version) ~= "string" then
			callback("get min app version error: version field missing", nil)
			return
		end
		callback(nil, r.version) -- success
	end)
	return req
end

-- --------------------------------------------------
-- BLUEPRINTS
-- --------------------------------------------------

--- Lists items using filter.
---
--- Config ---
--- search: string (not empty)
--- category: string
--- repo: string
--- sortBy: string? (nil, "", "updatedAt:desc", "likes:desc", "views:desc", ...)
---
--- Callback ---
---
--- error: string (can be nil)
--- items: []Item (can be nil)
---

mod.getItems = function(self, config, callback)
	-- /itemdrafts?search=banana,gdevillele&page=1&perPage=100

	if self ~= mod then
		error("api:getItems(config, callback): use `:`", 2)
	end
	if type(config) ~= "table" then
		error("api:getItems(config, callback): config must be a table", 2)
	end
	if type(callback) ~= "function" then
		error("api:getItems(config, callback): callback must be a function", 2)
	end

	local filterIsValid = function(k, v)
		if type(k) == "string" then
			if k == "search" and type(v) == "string" and v ~= "" then
				return true
			end
			if k == "sortBy" and (type(v) == "string" or type(v) == "nil") then
				return true
			end
			if k == "category" and (type(v) == "string" or (type(v) == "table" and #v > 0)) then
				return true
			end
			if k == "page" and (type(v) == "number" or type(v) == "integer") then
				return true
			end
			if k == "perPage" and (type(v) == "number" or type(v) == "integer") then
				return true
			end
			if k == "category" then
				return true
			end
			if k == "repo" then
				return true
			end
			if k == "minBlock" and (type(v) == "number" or type(v) == "integer") then
				return true
			end
		end
		return false
	end

	-- parse filters
	local queryParams = {}
	for k, v in pairs(config) do
		if filterIsValid(k, v) then
			if type(v) == "table" then
				for _, entry in ipairs(v) do
					table.insert(queryParams, { key = k, value = tostring(entry) })
				end
			else
				table.insert(queryParams, { key = k, value = tostring(v) })
			end
		end
	end

	-- build URL
	local url = mod.kApiAddr .. "/itemdrafts"
	for i, param in ipairs(queryParams) do
		if param.value ~= "" then
			if i == 1 then
				url = url .. "?"
			else
				url = url .. "&"
			end
			url = url .. param.key .. "=" .. param.value
		end
	end

	-- send request
	local req = HTTP:Get(url, function(resp)
		-- check status code
		if resp.StatusCode ~= 200 then
			callback("http status not 200", nil)
			return
		end

		-- decode body
		local items, err = JSON:Decode(resp.Body)

		for _, v in ipairs(items.results) do
			v.created = time.iso8601_to_os_time(v.created)
			v.updated = time.iso8601_to_os_time(v.updated)
			if v.likes == nil then
				v.likes = 0
			end
		end

		if err ~= nil then
			callback("json decode error:" .. err, nil) -- failure
			return
		end
		callback(nil, items.results) -- success
	end)
	return req
end

--- returns worlds considering provided filters
-- TODO: add filter for user world drafts
mod.getWorlds = function(self, config, callback)
	if self ~= mod then
		error("api:getWorlds(config, callback): use `:`", 2)
	end
	if type(config) ~= Type.table then
		error("api:getWorlds(config, callback): config should be a table", 2)
	end
	if type(callback) ~= "function" then
		error("api:getWorlds(config, callback): callback should be a function", 2)
	end

	local defaultConfig = {
		category = "featured",
		search = "",
		sortBy = "updatedAt:desc",
		-- tags = {}, -- not implemented yet
		page = 1,
		perPage = 50,
		fields = { "title", "created", "updated", "views", "likes" },
	}

	ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config)
	end)

	if not ok then
		error("api:getWorlds(config, callback): config error (" .. err .. ")", 2)
	end

	local u = url:parse(mod.kApiAddr .. "/worlds")

	u:addQueryParameter("category", config.category)
	u:addQueryParameter("search", config.search)
	u:addQueryParameter("sortBy", config.sortBy)
	u:addQueryParameter("perPage", math.floor(config.perPage))
	u:addQueryParameter("page", math.floor(config.page))

	for _, field in ipairs(config.fields) do
		u:addQueryParameter("f", field)
	end

	local url = u:toString() -- e.g. https://api.cu.bzh/worlds?category=featured&search=monster

	local req = HTTP:Get(url, function(res)
		if res.StatusCode ~= 200 then
			callback(mod:error(res.StatusCode, "status code:" .. res.StatusCode), nil)
			return
		end
		-- decode body
		local data, err = JSON:Decode(res.Body)
		if err ~= nil then
			callback(nil, mod:error(res.StatusCode, "getWorlds JSON decode error: " .. err))

			callback("json decode error:" .. err, nil) -- failure
			return
		end

		for _, v in ipairs(data.results) do
			if v.created then
				v.created = time.iso8601_to_os_time(v.created)
			end
			if v.updated then
				v.updated = time.iso8601_to_os_time(v.updated)
			end
			if v.likes ~= nil then
				v.likes = math.floor(v.likes)
			else
				v.likes = 0
			end
			if v.views ~= nil then
				v.views = math.floor(v.views)
			else
				v.views = 0
			end
		end
		callback(nil, data.results)
	end)
	return req
end

-- callback(error string or nil, World or nil)
-- field=authorName
mod.getWorld = function(_, worldID, fields, callback)
	if type(fields) ~= "table" then
		error("api:getWorld(worldID, fields, callback) - fields must be a table", 2)
	end

	if #fields < 1 then
		error("api:getWorld(worldID, fields, callback) - fields must contain at least one entry", 2)
	end

	if type(callback) ~= "function" then
		error("api:getWorld(worldID, fields, callback) - callback must be a function", 2)
	end

	local url = mod.kApiAddr .. "/worlds/" .. worldID

	url = urlGetFields(url, fields)

	-- send request
	local req = HTTP:Get(url, function(resp)
		-- check status code
		if resp.StatusCode ~= 200 then
			callback("http status not 200", nil)
			return
		end

		-- decode body
		local data, err = JSON:Decode(resp.Body)
		if err ~= nil then
			callback("json JSON decode error:" .. err, nil) -- failure
			return
		end

		local world = data

		if world.created then
			world.created = time.iso8601_to_os_time(world.created)
		end
		if world.updated then
			world.updated = time.iso8601_to_os_time(world.updated)
		end
		if world.likes ~= nil then
			world.likes = math.floor(world.likes)
		else
			world.likes = 0
		end
		if world.views ~= nil then
			world.views = math.floor(world.views)
		else
			world.views = 0
		end
		-- `liked` field is omitted if value is false
		if world.liked == nil then
			world.liked = false
		end

		callback(nil, world) -- success
	end)
	return req
end

mod.getWorldThumbnail = function(self, worldID, callback)
	if self ~= mod then
		error("api:getWorldThumbnail(worldID, callback): use `:`", 2)
	end
	if type(worldID) ~= Type.string then
		error("api:getWorldThumbnail(worldID, callback): worldID should be a string", 2)
	end
	if type(callback) ~= "function" then
		error("api:getWorldThumbnail(worldID, callback): callback should be a function", 2)
	end

	local url = mod.kApiAddr .. "/world-thumbnail/" .. worldID

	local req = HTTP:Get(url, function(res)
		if res.StatusCode == 200 then
			callback(nil, res.Body)
		elseif res.StatusCode == 400 then
			callback("This world has no thumnail", nil)
		else
			callback("Error " .. res.StatusCode .. ": " .. res.Body:ToString(), nil)
		end
	end)

	return req
end

mod.getServers = function(self, worldID, callback)
	local url = self.kApiAddr .. "/servers?worldID=" .. worldID .. "&tag=" .. Private.ServerTag

	local req = HTTP:Get(url, function(res)
		if res.StatusCode ~= 200 then
			callback(self.error(res.StatusCode, "could not get servers"), nil)
			return
		end

		local t = JSON:Decode(res.Body)
		if t.servers == nil then
			t = {}
			callback(nil, t)
			return
		end
		-- take care of omitempty fields
		local hasPlayers
		local hasMaxPlayers
		local hasDevMode
		for _, s in pairs(t.servers) do
			hasPlayers = false
			hasMaxPlayers = false
			hasDevMode = false
			for k, _ in pairs(s) do
				if k == "players" then
					hasPlayers = true
				end
				if k == "max-players" then
					hasMaxPlayers = true
				end
				if k == "dev-mode" then
					hasDevMode = true
				end
			end
			if not hasPlayers then
				s.players = 0
			end
			if not hasMaxPlayers then
				s["max-players"] = 0
			end
			if not hasDevMode then
				s["dev-mode"] = 0
			end
		end
		callback(nil, t.servers)
	end)
	return req
end

mod.getUserId = function(username, cb)
	if not username then
		return cb("Error: first parameter of getUserId must be a username.")
	end
	local url = mod.kApiAddr .. "/users?username=" .. username
	local req = HTTP:Get(url, function(res)
		if res.StatusCode ~= 200 then
			return cb("Error (" .. res.StatusCode .. "): can't find user " .. username .. ".")
		end
		cb(nil, JSON:Decode(res.Body).id)
	end)
	return req
end

mod.getAvatar = function(usernameOrId, cb)
	if type(usernameOrId) ~= "string" then
		error("getAvatar(usernameOrId) - usernameOrId should be a string", 2)
	end
	local url = mod.kApiAddr .. "/users/" .. usernameOrId .. "/avatar"
	local req = HTTP:Get(url, function(res)
		if res.StatusCode ~= 200 then
			cb("Error (" .. res.StatusCode .. "): can't get avatar.")
			return
		end
		local data = JSON:Decode(res.Body)
		data.hair = #data.hair > 0 and data.hair or nil
		data.jacket = #data.jacket > 0 and data.jacket or "official.jacket"
		data.pants = #data.pants > 0 and data.pants or "official.pants"
		data.boots = #data.boots > 0 and data.boots or "official.boots"
		cb(nil, data)
	end)
	return req
end

mod.getBalance = function(usernameOrCb, cb)
	if type(usernameOrCb) == "function" then -- if self
		cb = usernameOrCb
		local url = mod.kApiAddr .. "/users/self/balance"
		HTTP:Get(url, function(res)
			if res.StatusCode ~= 200 then
				cb("Error (" .. res.StatusCode .. "): can't get balance.")
				return
			end
			cb(nil, JSON:Decode(res.Body))
		end)
		return
	end
	local username = usernameOrCb
	mod.getUserId(username, function(err, id)
		if err then
			return cb(err)
		end
		local url = mod.kApiAddr .. "/users/" .. id .. "/balance"
		HTTP:Get(url, function(res)
			if res.StatusCode ~= 200 then
				cb("Error (" .. res.StatusCode .. "): can't get balance.")
				return
			end
			cb(nil, JSON:Decode(res.Body))
		end)
	end)
end

mod.getItem = function(self, itemId, cb)
	local url = self.kApiAddr .. "/items/" .. itemId
	local req = HTTP:Get(url, function(resp)
		if resp.StatusCode ~= 200 then
			cb(self.error(resp.StatusCode, "could not get item info"), nil)
			return
		end
		-- parse response
		local itmResp, err = JSON:Decode(resp.Body)
		if err ~= nil then
			cb("json decode failed", nil)
			return
		end
		--		if itmResp.item.likes == nil then itmResp.item.likes = 0 end
		if itmResp.item.liked == nil then
			itmResp.item.liked = false
		end
		cb(nil, itmResp.item)
	end)
	return req
end

mod.getQuests = function() -- self
	-- nothing for now
end

-- Receives "natural" name, returns slug and string error (nil if there's none)
-- No request is sent, this is local validation.
mod.checkItemName = function(itemName, username)
	if type(itemName) ~= "string" then
		return nil, "Item name must be a string."
	elseif itemName == "" then
		return nil, "Item name can't be empty."
	elseif itemName:match("^[a-zA-Z].*$") == nil then
		return nil, "Item must start with a letter (A-Z)."
	elseif itemName:match("^[a-zA-Z][a-zA-Z0-9_ ]*$") == nil then
		return nil, "Item name must contain only letters (A-Z), numbers, spaces and underscores."
	elseif #itemName > 20 then
		return nil, "Item name must be 20 characters or shorter."
	end

	local lowered = string.lower(itemName)
	local slug = lowered:gsub(" ", "_")

	if username ~= nil then
		slug = username .. "." .. slug
	end

	return slug, nil
end

mod.checkWorldName = function(worldName)
	if type(worldName) ~= "string" then
		return nil, "World name must be a string."
	elseif worldName == "" then
		return nil, "World name can't be empty."
	elseif #worldName > mod.maxWorldTitleLength then
		local str = "Item name must be " .. mod.maxWorldTitleLength .. " characters or shorter."
		return nil, str
	end

	local sanitized = worldName

	return sanitized, nil
end

mod.aiChatCompletions = function(messages, temperatureOrCb, cb)
	if not messages then
		cb("Error: api.aiChatCompletions takes messages as a first parameter.")
		return
	end
	if type(temperatureOrCb) == "function" then
		cb = temperatureOrCb
	end
	local temperature = type(temperatureOrCb) == "number" and temperatureOrCb or 0.7

	local url = mod.kApiAddr .. "/ai/chatcompletions"
	local headers = {}
	headers["Content-Type"] = "application/json"

	local body = {}
	body.model = "gpt-3.5-turbo-0613"
	body.messages = messages
	body.temperature = temperature
	HTTP:Post(url, headers, body, function(res)
		if res.StatusCode ~= 200 then
			return cb("Error (" .. tostring(res.StatusCode) .. "): " .. res.Body:ToString())
		end
		local body = JSON:Decode(res.Body:ToString())
		if body.error.type then
			return cb("Error (" .. body.error.type .. ")")
		end
		local message = body.choices[1].message
		cb(nil, message)
	end)
end

mod.aiImageGenerations = function(prompt, optionsOrCallback, callback)
	local options = type(optionsOrCallback) == "table" and optionsOrCallback or {}
	local cb = type(optionsOrCallback) == "function" and optionsOrCallback or callback

	local url = mod.kApiAddr .. "/ai/imagegenerations"
	local headers = {}
	headers["Content-Type"] = "application/json"

	local body = {
		prompt = prompt,
		size = options.size or 256,
		output = options.output or "Quad",
		pixelart = options.pixelart or false,
		asURL = options.asURL or false,
	}
	if body.output ~= "Shape" and body.output ~= "Quad" then
		return cb('Error: output can only be "Shape" or "Quad".')
	end
	local req = HTTP:Post(url, headers, body, function(res)
		if res.StatusCode ~= 200 then
			return cb("Error (" .. tostring(res.StatusCode) .. "): " .. res.Body:ToString())
		end
		local outputObj
		if body.output == "Quad" and not body.asURL then
			outputObj = Quad()
			outputObj.Width = 50
			outputObj.Height = 50
			outputObj.Image = res.Body
		elseif body.output == "Shape" and not body.asURL then
			outputObj = Shape(res.Body)
			local collisionBoxMin = outputObj.CollisionBox.Min
			local center = outputObj.CollisionBox.Center:Copy()
			center.Y = outputObj.CollisionBox.Min.Y
			outputObj.Pivot = { outputObj.Width * 0.5, collisionBoxMin.Y, outputObj.Depth * 0.5 }
			outputObj.CollisionBox = Box(center - { 0.5, 0, 0.5 }, center + { 0.5, 1, 0.5 })
		elseif body.asURL then
			outputObj = JSON:Decode(res.Body).url
		end
		cb(nil, outputObj)
	end)
	return req
end

return mod
