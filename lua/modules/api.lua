--[[
API module

//!\\ Still a work in progress. Your scripts may break in the future if you use it now. 
]]--

local mod = {
	kApiAddr = "https://api.cu.bzh",
	-- kApiAddr = "http://192.168.1.88:10083",
	time = require("time"),
}

local errorMT = {
	__tostring = function(t) return t.message or "" end
}

mod.error = function(self, statusCode, message)
	local err = {statusCode = statusCode, message = message}
	setmetatable(err, errorMT)
	return err
end


-- postSecret ...
-- callback(ok, errMsg)
mod.postSecret = function(self, secret, callback)
	if type(secret) ~= "string" then
		callback(false, "1st arg must be a string")
		return
	end
	if type(callback) ~= "function" then
		callback(false, "2nd arg must be a function")
		return
	end
	local url = mod.kApiAddr .. "/secret"
	local body = {
		secret = secret,
	}
	local req = HTTP:Post(url, body, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, "http status not 200")
			return
		end
		local response, err = JSON:Decode(resp.Body)
		callback(true, response.message) -- success
	end)
	return req
end

-- search Users by username substring
-- callback(ok, users, errMsg)
-- ok: boolean
-- users: []User
-- errMsg: string
mod.searchUser = function(self, searchText, callback)
	-- validate arguments
	if type(searchText) ~= "string" then
		error("api:getFriends(searchText, callback) - searchText must be a string", 2)
		return
	end
	if type(callback) ~= "function" then
		error("api:getFriends(searchText, callback) - callback must be a function", 2)
		return
	end
	local req = HTTP:Get(mod.kApiAddr .. "/user-search-others/" .. searchText, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, nil, "http status not 200")
			return
		end
		local users, err = JSON:Decode(resp.Body)
		if err ~= nil then
			callback(false, nil, "json decode error:" .. err)
			return
		end
		callback(true, users, nil) -- success
	end)
	return req
end

-- getFriends ...
-- callback(ok, friends, errMsg)
mod.getFriends = function(self, callback)
	if type(callback) ~= "function" then
		error("api:getFriends(callback) - callback must be a function", 2)
		return
	end
	local req = HTTP:Get(mod.kApiAddr .. "/friend-relations", function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, nil, "http status not 200: " .. resp.StatusCode)
			return
		end
		local friends, err = JSON:Decode(resp.Body)
		if err ~= nil then
			callback(false, nil, "json decode error:" .. err)
			return
		end
		callback(true, friends, nil) -- success
	end)
	return req
end

-- getFriendCount ...
-- callback(ok, count, errMsg)
mod.getFriendCount = function(self, callback)
	if type(callback) ~= "function" then
		error("api:getFriendCount(callback) - callback must be a function", 2)
		return
	end
	local req = self:getFriends(function(ok, friends)
		local count = 0
		if friends ~= nil then
			count = #friends
		end
		callback(ok, count, nil)
	end)
	return req
end

-- sendFriendRequest ...
-- callback(ok, errMsg)
mod.sendFriendRequest = function(self, userID, callback)
	if type(userID) ~= "string" then
		callback(false, "1st arg must be a string")
		error("api:sendFriendRequest(userID, callback) - userID must be a string", 2)
		return
	end
	if type(callback) ~= "function" then
		error("api:sendFriendRequest(userID, callback) - callback must be a function", 2)
		return
	end
	local url = mod.kApiAddr .. "/friend-request"
	local body = {
		senderID = Player.UserID,
		recipientID = userID,
	}
	local req = HTTP:Post(url, body, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, "http status not 200")
			return
		end
		callback(true, nil) -- success
	end)
	return req
end

-- cancelFriendRequest ...
-- callback(ok, errMsg)
mod.cancelFriendRequest = function(self, recipientID, callback)
	if type(recipientID) ~= "string" then
		callback(false, "1st arg must be a string")
		return
	end
	if type(callback) ~= "function" then
		callback(false, "2nd arg must be a function")
		return
	end
	local url = mod.kApiAddr .. "/friend-request-cancel"
	local body = {
		senderID = Player.UserID,
		recipientID = recipientID,
	}
	local req = HTTP:Post(url, body, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, "http status not 200")
			return
		end
		callback(true, nil) -- success
	end)
	return req
end

-- getSentFriendRequests ...
-- callback(ok, reqs, errMsg)
mod.getSentFriendRequests = function(self, callback)
	if type(callback) ~= "function" then
		callback(false, nil, "1st arg must be a function")
		return
	end
	local url = mod.kApiAddr .. "/friend-requests-sent"
	local req = HTTP:Get(url, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, nil, "http status not 200")
			return
		end
		local requests, err = JSON:Decode(resp.Body)
		if err ~= nil then
			callback(false, nil, "json decode error:" .. err)
			return
		end
		-- success
		callback(true, requests, nil)
	end)
	return req
end

-- getReceivedFriendRequests ...
-- callback(ok, reqs, errMsg)
mod.getReceivedFriendRequests = function(self, callback)
	if type(callback) ~= "function" then
		callback(false, nil, "1st arg must be a function")
		return
	end
	local url = mod.kApiAddr .. "/friend-requests-received"
	local req = HTTP:Get(url, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, nil, "http status not 200")
			return
		end
		local requests, err = JSON:Decode(resp.Body)
		if err ~= nil then
			callback(false, nil, "json decode error:" .. err)
			return
		end
		callback(true, requests, nil) -- success
	end)
	return req
end

-- getUserInfo gets a user by its ID
-- callback(ok, user, errMsg)
mod.getUserInfo = function(self, id, callback)
	-- validate arguments
	if type(id) ~= "string" then
		callback(false, nil, "1st arg must be a string")
		return
	end
	if type(callback) ~= "function" then
		callback(false, nil, "2nd arg must be a function")
		return
	end
	local url = mod.kApiAddr .. "/users/" .. id
	local req = HTTP:Get(url, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, nil, "http status not 200")
			return
		end
		local usr, err = JSON:Decode(resp.Body)
		if err ~= nil then
			callback(false, nil, "json decode error:" .. err)
			return
		end
		callback(true, usr, nil) -- success
	end)
	return req
end

-- getMinAppVersion gets minimum app version
-- callback(error string or nil, minVersion string)
mod.getMinAppVersion = function(self, callback)
	if type(callback) ~= "function" then
		callback("1st arg must be a function", nil)
		return
	end
	local url = mod.kApiAddr .. "/min-version"
	local req = HTTP:Get(url, function(resp)
		if resp.StatusCode ~= 200 then
			callback("http status not 200", nil)
			return
		end
		local r, err = JSON:Decode(resp.Body)
		if err ~= nil then
			callback("decode error:" .. err, nil)
			return
		end
		if not r.version or type(r.version) ~= "string" then
			callback("version field missing", nil)
			return
		end
		callback(nil, r.version) -- success
	end)
	return req
end

-- replyToFriendRequest accepts or rejects a received friend request
-- callback(ok, errMsg)
mod.replyToFriendRequest = function(self, usrID, accept, callback)
	-- validate arguments
	if type(usrID) ~= "string" then
		callback(false, "1st arg must be a string")
		return
	end
	if type(accept) ~= "boolean" then
		callback(false, "2nd arg must be a boolean")
		return
	end
	if type(callback) ~= "function" then
		callback(false, "3rd arg must be a function")
		return
	end
	local url = mod.kApiAddr .. "/friend-request-reply"
	local body = {
		senderID = usrID,
		accept = accept,
	}
	local req = HTTP:Post(url, body, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, "http status not 200")
			return
		end
		callback(true, nil) -- success
	end)
	return req
end

-- --------------------------------------------------
-- BLUEPRINTS
-- --------------------------------------------------

-- Lists items using filter.
--
-- filter = {
--   category = "hat",
--   repo = "caillef",
-- }
--
-- callback(error string or nil, items []Item or nil)
--
mod.getItems = function(self, filter, callback)
	-- /itemdrafts?search=banana,gdevillele&page=1&perPage=100

	-- validate arguments
	if type(filter) ~= "table" then
		callback("1st arg must be a table", nil)
		return
	end
	if type(callback) ~= "function" then
		callback("2nd arg must be a function", nil)
		return
	end

	local filterIsValid = function (k, v)
		if type(k) == "string" then
			if k == "search" and type(v) == "string" and v ~= "" then
				return true
			end
			if k == "category" and (type(v) == "string" or (type(v) == "table" and #v > 0)) then
				return true
			end
			if k == "page" or k == "perpage" then
				return true
			end
			if k == "category" then
				return true
			end
			if k == "repo" then
				return true
			end
			if k == "minBlock" then
				return true
			end
		end
		return false
	end

	-- parse filters
	local queryParams = {}
	for k, v in pairs(filter) do
		if filterIsValid(k, v) then
			if type(v) == "table" then
				for _, entry in ipairs(v) do
					table.insert(queryParams, {key = k, value = tostring(entry)})	
				end
			else
				table.insert(queryParams, {key = k, value = tostring(v)})
			end
		end
	end

	-- build URL
	local url = mod.kApiAddr .. "/itemdrafts"
	for i, param in ipairs(queryParams) do
		if i == 1 then
			url = url .. "?"
		else
			url = url .. "&"
		end
		url = url .. param.key .. "=" .. param.value
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

		for k, v in ipairs(items.results) do
			v.created = mod.time.iso8601_to_os_time(v.created)
			v.updated = mod.time.iso8601_to_os_time(v.updated)
		end

		if err ~= nil then
			callback("json decode error:" .. err, nil) -- failure
			return
		end
		callback(nil, items.results) -- success
	end)
	return req
end

-- Lists world drafts using filter.
--
-- filter = {
--   repo = "caillef",
--   category = "fps",
-- }
-- NOTE: categories are not in place yet, but they would be useful,
-- keeping filter in place client side, waiting for backend to support it.
-- callback(error string or nil, items []World or nil)
mod.getWorlds = function(self, filter, callback)
	-- GET /worlddrafts?search=banana,gdevillele&page=1&perPage=100

	-- validate arguments
	if type(filter) ~= "table" then
		callback("1st arg must be a table", nil)
		return
	end
	if type(callback) ~= "function" then
		callback("2nd arg must be a function", nil)
		return
	end

	local filterIsValid = function (k, v)
		if type(k) == "string" then
			if k == "search" and type(v) == "string" and v ~= "" then
				return true
			end
			if k == "category" and (type(v) == "string" or (type(v) == "table" and #v > 0)) then
				return true
			end
			if k == "page" or k == "perpage" then
				return true
			end
			if k == "category" then
				return true
			end
			if k == "repo" then
				return true
			end
		end
		return false
	end

	-- parse filters
	local queryParams = {}
	for k, v in pairs(filter) do
		if filterIsValid(k, v) then
			if type(v) == "table" then
				for _, entry in ipairs(v) do
					table.insert(queryParams, {key = k, value = tostring(entry)})	
				end
			else
				table.insert(queryParams, {key = k, value = tostring(v)})
			end
		end
	end

	-- build URL
	local url = mod.kApiAddr .. "/worlddrafts"
	for i, param in ipairs(queryParams) do
		if i == 1 then
			url = url .. "?"
		else
			url = url .. "&"
		end
		url = url .. param.key .. "=" .. param.value
	end

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
			callback("json decode error:" .. err, nil) -- failure
			return
		end

		for k, v in ipairs(data.worlds) do
			if v.created then v.created = mod.time.iso8601_to_os_time(v.created) end
			if v.updated then v.updated = mod.time.iso8601_to_os_time(v.updated) end
			if v.likes ~= nil then v.likes = math.floor(v.likes) else v.likes = 0 end
			if v.views ~= nil then v.views = math.floor(v.views) else v.views = 0 end
		end
		
		callback(nil, data.worlds) -- success
	end)
	return req
end

--- returns the published worlds in the specified category
--- config: table
--- 	list: string ("recent", "featured"...)
--- 	search: string
--- callback: function(err, worlds)
---		err: string
---		worlds: []worlds
mod.getPublishedWorlds = function(self, config, callback)
	if self ~= mod then error("api:getPublishedWorlds(config, callback): use `:`", 2) end
	if type(config) ~= Type.table then error("api:getPublishedWorlds(config, callback): config should be a table", 2) end
	if type(callback) ~= "function" then error("api:getPublishedWorlds(config, callback): callback should be a function", 2) end

	if config.list ~= nil and type(config.list) == Type.string and config.list ~= "featured" and config.list ~= "recent" then
		error("api:getPublishedWorlds(config, callback): config.list should be \"featured\" or \"recent\"", 2)
	end

    -- construct query params string
    local queryParams = ""

	local category = "recent"
	if config.list ~= nil and type(config.list) == Type.string then
		category = config.list
	end
    queryParams = queryParams .. "category=" .. category

	if config.search ~= nil and type(config.search) == Type.string and #config.search > 0 then
        -- if this isn't the 1st query param, we need to use a '&' separator
        if #queryParams > 0 then
            queryParams = queryParams .. "&"
        end
        queryParams = queryParams .. "search=" .. config.search
	end

    -- url example : https://api.cu.bzh/worlds?category=featured&search=monster
	local url = mod.kApiAddr .. "/worlds?" .. queryParams
	local req = HTTP:Get(url, function(res)
		if res.StatusCode ~= 200 then
			callback("http status not 200", nil)
			return
		end
		
		-- decode body
		local data, err = JSON:Decode(res.Body)
		if err ~= nil then
			callback("json decode error:" .. err, nil) -- failure
			return
		end

		for k, v in ipairs(data.worlds) do
			if v.created then v.created = mod.time.iso8601_to_os_time(v.created) end
			if v.updated then v.updated = mod.time.iso8601_to_os_time(v.updated) end
			if v.likes ~= nil then v.likes = math.floor(v.likes) else v.likes = 0 end
			if v.views ~= nil then v.views = math.floor(v.views) else v.views = 0 end
		end
	
		callback(nil, data.worlds)
	end)
	return req
end

-- callback(error string or nil, World or nil)
mod.getWorld = function(self, worldID, callback)
	if type(callback) ~= "function" then
		callback("2nd arg must be a function", nil)
		return
	end

	local url = mod.kApiAddr .. "/worlds/" .. worldID

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
			callback("json decode error:" .. err, nil) -- failure
			return
		end

		local world = data.world

		if world.created then world.created = mod.time.iso8601_to_os_time(world.created) end
		if world.updated then world.updated = mod.time.iso8601_to_os_time(world.updated) end
		if world.likes ~= nil then world.likes = math.floor(world.likes) else world.likes = 0 end
		if world.views ~= nil then world.views = math.floor(world.views) else world.views = 0 end
		-- `liked` field is omitted if value is false
		if world.liked == nil then world.liked = false end

		callback(nil, world) -- success
	end)
	return req
end

mod.getWorldThumbnail = function(self, worldID, callback)
	if self ~= mod then error("api:getWorldThumbnail(worldID, callback): use `:`", 2) end
	if type(worldID) ~= Type.string then error("api:getWorldThumbnail(worldID, callback): worldID should be a string", 2) end
	if type(callback) ~= "function" then error("api:getWorldThumbnail(worldID, callback): callback should be a function", 2) end

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

-- api:createWorld({title = "banana", category = nil, original = nil}, function(err, world))
mod.createWorld = function(self, data, callback) 
	local url = self.kApiAddr .. "/worlddrafts"
	local req = HTTP:Post(url, data, function(res)
		if res.StatusCode ~= 200 then
			callback(self:error(res.StatusCode, "could not create world"), nil)
			return
		end

		local world, err = JSON:Decode(res.Body)
		if err ~= nil then
			callback(self:error(res.StatusCode, "could not decode response"), nil)
			return
		end

		if world.created then world.created = mod.time.iso8601_to_os_time(world.created) end
		if world.updated then world.updated = mod.time.iso8601_to_os_time(world.updated) end
		if world.likes ~= nil then world.likes = math.floor(world.likes) else world.likes = 0 end
		if world.views ~= nil then world.views = math.floor(world.views) else world.views = 0 end

		callback(nil, world)
	end)
	return req
end

-- api:patchWorld("world-id", {title = "something", description = "banana"}, function(err, world))
mod.patchWorld = function(self, worldID, data, callback) 
	local url = self.kApiAddr .. "/worlddrafts/" .. worldID
	local req = HTTP:Patch(url, data, function(res)
		if res.StatusCode ~= 200 then
			callback(self:error(res.StatusCode, "could not modify world"), nil)
			return
		end

		local world, err = JSON:Decode(res.Body)
		if err ~= nil then
			callback(self:error(res.StatusCode, "could not decode response"), nil)
			return
		end

		if world.created then world.created = mod.time.iso8601_to_os_time(world.created) end
		if world.updated then world.updated = mod.time.iso8601_to_os_time(world.updated) end
		if world.likes ~= nil then world.likes = math.floor(world.likes) else world.likes = 0 end
		if world.views ~= nil then world.views = math.floor(world.views) else world.views = 0 end

		callback(nil, world)
	end)
	return req
end

mod.likeWorld = function(self, worldID, addLike, callback)
	local url = self.kApiAddr .. "/worlds/" .. worldID .. "/likes"
	local t = {value = addLike}
	local body = JSON:Encode(t)
	local req = HTTP:Patch(url, body, function(res)
		if res.StatusCode ~= 200 then
			callback(self.error(statusCode, "could not modify world's likes"), nil)
			return
		end
		callback(nil, nil)
	end)
	return req
end

mod.getServers = function(self, worldID, callback)
	local url = self.kApiAddr .. "/servers?worldID=" .. worldID .. "&tag=" .. Private.ServerTag

	local req = HTTP:Get(url, function(res)
		if res.StatusCode ~= 200 then
			callback(self.error(statusCode, "could not get servers"), nil)
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
			for k, v in pairs(s) do
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
			if not hasPlayers then s.players = 0 end
			if not hasMaxPlayers then s["max-players"] = 0 end
			if not hasDevMode then s["dev-mode"] = 0 end
		end
		callback(nil, t.servers)
	end)
	return req
end

-- api:createItem({name = "banana", category = nil, original = nil}, function(err, item))
mod.createItem = function(self, data, callback) 
	local url = self.kApiAddr .. "/itemdrafts"
	local req = HTTP:Post(url, data, function(res)
		if res.StatusCode ~= 200 then
			callback(self:error(res.StatusCode, "could not create item"), nil)
			return
		end

		local item, err = JSON:Decode(res.Body)
		if err ~= nil then
			callback(self:error(res.StatusCode, "could not decode response"), nil)
			return
		end

		if item.created then item.created = mod.time.iso8601_to_os_time(item.created) end
		if item.updated then item.updated = mod.time.iso8601_to_os_time(item.updated) end
		if item.likes ~= nil then item.likes = math.floor(item.likes) else item.likes = 0 end
		if item.views ~= nil then item.views = math.floor(item.views) else item.views = 0 end

		callback(nil, item)
	end)
	return req
end

-- api:patchItem("item-id", {description = "banana"}, function(err, item))
mod.patchItem = function(self, itemID, data, callback) 
	local url = self.kApiAddr .. "/itemdrafts/" .. itemID
	local req = HTTP:Patch(url, data, function(res)
		if res.StatusCode ~= 200 then
			callback(self:error(res.StatusCode, "could not modify item"), nil)
			return
		end

		local item, err = JSON:Decode(res.Body)
		if err ~= nil then
			callback(self:error(res.StatusCode, "could not decode response"), nil)
			return
		end

		if item.created then item.created = mod.time.iso8601_to_os_time(item.created) end
		if item.updated then item.updated = mod.time.iso8601_to_os_time(item.updated) end
		if item.likes ~= nil then item.likes = math.floor(item.likes) else item.likes = 0 end
		if item.views ~= nil then item.views = math.floor(item.views) else item.views = 0 end

		callback(nil, item)
	end)
	return req
end

mod.updateAvatar = function(data, cb) -- data = { jacket="caillef.jacket", eyescolor={r=255, g=0, b=30} }
	local url = mod.kApiAddr .. "/users/self/avatar"
	local req = HTTP:Patch(url, {}, data, function(res)
		if res.StatusCode ~= 200 then
			cb("Error (" .. res.StatusCode .. "): can't update avatar.", false)
			return
		end
		cb(nil, true)
	end)
	return req
end

mod.getUserId = function(username, cb)
	if not username then
		return cb("Error: first parameter of getUserId must be a username.")
	end
	local url = mod.kApiAddr.."/users?username="..username
	local req = HTTP:Get(url, function(res)
		if res.StatusCode ~= 200 then
			return cb("Error (" .. res.StatusCode .. "): can't find user "..username..".")
		end
		cb(nil, JSON:Decode(res.Body).id)
	end)
	return req
end

mod.getAvatar = function(usernameOrId, cb)
	local callAvatarEndpoint = function(id)
		local url = mod.kApiAddr .. "/users/"..id.."/avatar"
		HTTP:Get(url, function(res)
			if res.StatusCode ~= 200 then
				cb("Error (" .. res.StatusCode .. "): can't get avatar.")
				return
			end
			local data = JSON:Decode(res.Body)
			data.hair = #data.hair > 0 and data.hair or "official.hair"
			data.jacket = #data.jacket > 0 and data.jacket or "official.jacket"
			data.pants = #data.pants > 0 and data.pants or "official.pants"
			data.boots = #data.boots > 0 and data.boots or "official.boots"
			cb(nil, data)
		end)
	end

	local isUsername = #usernameOrId < 36 -- UserID UUID is 36 characters
	if isUsername then
		mod.getUserId(usernameOrId, function(err, id)
			if err then
				return cb(err)
			end
			callAvatarEndpoint(id)
		end)
	else
		callAvatarEndpoint(usernameOrId)
	end
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
		local url = mod.kApiAddr .. "/users/"..id.."/balance"
		HTTP:Get(url, function(res)
			if res.StatusCode ~= 200 then
				cb("Error (" .. res.StatusCode .. "): can't get balance.")
				return
			end
			cb(nil, JSON:Decode(res.Body))
		end)
	end)
end

mod.getTransactions = function(usernameOrCb, cb) -- or self if nil
	usernameOrCb(nil, {
		-- { id="09c5cd9e-9c3a-4dc5-8083-06b77e1095e3", from={id="209809842",name="caillef"}, to={id="20980242",name="gdevillele"}, amount=283, action="buy", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.coffee" }, copyId=123, date="2023-03-20T17:01:14.625402882Z" },
		-- { id="09c5cd9e-9c3a-4dc5-8083-06b77e1095f3", from={id="20980242",name="gdevillele"}, to={id="209809842",name="caillef"}, amount=200, action="buy", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.coffee" }, copyId=123, date="2023-02-01T15:00:14.625402882Z" },
		-- { id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d3", from={id="0",name="treasure"}, to={id="209809842",name="caillef"}, amount=100, action="mint", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.coffee" }, copyId=120, date="2022-08-10T16:00:14.625402882Z" },
		-- { id="09c5cd9e-9c3a-4dc5-8083-06b77e1095e3", from={id="209809842",name="caillef"}, to={id="20980242",name="gdevillele"}, amount=283, action="buy", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copyId=123, date="2020-07-12T17:01:14.625402882Z" },
		-- { id="09c5cd9e-9c3a-4dc5-8083-06b77e1095f3", from={id="20980242",name="gdevillele"}, to={id="209809842",name="caillef"}, amount=200, action="buy", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copyId=123, date="2020-07-10T15:00:14.625402882Z" },
		-- { id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d3", from={id="0",name="treasure"}, to={id="209809842",name="caillef"}, amount=100, action="mint", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copyId=120, date="2020-06-10T16:00:14.625402882Z" }
	})
end

mod.listItem = function(price, maxSupply, cb)
	local body = { price=price, maxSupply=maxSupply }
	cb(nil, { result={
		id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d3",
		itemId="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5",
		itemSlug="caillef.shop",
		owner={ id="209809842", name="caillef" },
		latestTransactions = { -- 5 latest transactions
			{ id="b9c5cd9e-9c3a-4dc5-8083-06b77e109500", from={id="0",name="treasure"}, to={id="209809842",name="caillef"}, amount=100, action="mint", item="caillef.shop", copy=68, date="2020-07-10 20:00:00.000" }
		},
		copyId=68,
		createdAt="2020-06-10 15:00:00.000"
	}})
end

mod.getItem = function(itemId, cb)
	cb(nil, {
		id="09b5cd9f-9c3a-4dc5-8083-06b77e1095e3",
		slug="caillef.shop",
		maxSupply=10000,
		currentSupply=2952,
		listingPrice=82
	})
end

mod.mintCopy = function(itemId)
	cb(nil, {
		id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d3",
		item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" },
		copyId=68,
		owner={id="209809842", name="caillef"},
		createdAt="2020-06-10 15:00:00.000"
	})
end

mod.getCopies = function(itemId, filtersOrCb, cb)
	cb(nil, {
		{
			id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d3",
			item = { id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" },
			copyId=68,
			listingPrice=80,
			owner={id="209809848", name="gdevillele"},
			createdAt="2020-06-10 15:00:00.000"
		},
		{
			id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d4",
			item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" },
			copyId=97,
			listingPrice=81,
			owner={id="20989842", name="aduermael"},
			createdAt="2020-06-10 15:00:00.000"
		},
		{
			id="09c5cd9e-9c3a-4dc5-8083-06b77e1095e6",
			item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" },
			copyId=120,
			listingPrice=100,
			owner={id="209809842", name="caillef"},
			createdAt="2020-06-10 15:00:00.000"
		}
	})
end

mod.listCopy = function(itemId, price, duration, cb)
	cb(nil, {
		id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d3",
		item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" },
		copyId=68,
		listingPrice=80,
		endListing="2020-06-10 15:00:00.000",
		owner={ id="209809848", name="gdevillele" },
		createdAt="2020-06-10 15:00:00.000"
	})
end

mod.getCopyTransactions = function(copyId, cb)
	cb(nil, {
		{ id="b9c5cd9e-9c3a-4dc5-8083-06b77e109500", from={id="209809843",name="gdevillele"}, to={id="209809842",name="caillef"}, amount=140, action="buy", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copy=68, date="2020-07-10 22:00:00.000" },
		{ id="b9c5cd9e-9c3a-4dc5-8083-06b77e109501", from={id="209809842",name="caillef"}, to={id="209809843",name="gdevillele"}, amount=120, action="buy", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copy=68, date="2020-07-10 21:00:00.000" },
		{ id="b9c5cd9e-9c3a-4dc5-8083-06b77e109502", from={id="0",name="treasure"}, to={id="209809842",name="caillef"}, amount=100, action="mint", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copy=68, date="2020-07-10 20:00:00.000" }
	})
end

mod.buyCopy = function(copyId,cb)
	cb(nil, {
		id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d3",
		item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" },
		copyId=68,
		latestTransactions={
			{ id="b9c5cd9e-9c3a-4dc5-8083-06b77e109501", from={id="209809842",name="caillef"}, to={id="209809843",name="gdevillele"}, amount=120, action="buy", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copy=68, date="2020-07-10 21:00:00.000" },
			{ id="b9c5cd9e-9c3a-4dc5-8083-06b77e109502", from={id="0",name="treasure"}, to={id="209809842",name="caillef"}, amount=100, action="mint", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copy=68, date="2020-07-10 20:00:00.000" },
		},
		owner={id="209809848",name="gdevillele"},
		createdAt="2020-06-10 15:00:00.000"
	})
end

mod.getQuests = function() -- self

end

-- Receives "natural" name, returns slug and string error (nil if there's none)
-- No request is sent, this is local validation.
mod.checkItemName = function(itemName, username)

	if type(itemName) ~= "string" then
		return nil, "Item name must be a string."
	elseif itemName == "" then
		return nil, "Item name can't be empty."
	elseif itemName:match('^[a-zA-Z].*$') == nil then
		return nil, "Item must start with a letter (A-Z)."
	elseif itemName:match('^[a-zA-Z][a-zA-Z0-9_ ]*$') == nil then
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
	elseif #worldName > 32 then
		return nil, "Item name must be 32 characters or shorter."
	end

	local sanitized = worldName

	return sanitized, nil
end

mod.aiChatCompletions = function(messages, temperatureOrCb, cb)
	if not messages then cb("Error: api.aiChatCompletions takes messages as a first parameter.") return end
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
		asURL = options.asURL or false
	}
	if body.output ~= "Shape" and body.output ~= "Quad" then
		return cb("Error: output can only be \"Shape\" or \"Quad\".")
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
			outputObj.Pivot = { outputObj.Width * 0.5,
								collisionBoxMin.Y,
								outputObj.Depth * 0.5}
			outputObj.CollisionBox = Box(center - {0.5, 0, 0.5}, center + {0.5, 1, 0.5})
		elseif body.asURL then
			outputObj = JSON:Decode(res.Body).url
		end
        cb(nil, outputObj)
    end)
    return req
end

return mod
