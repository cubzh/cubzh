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

-- creates an error
-- statusCode: integer
-- message: string
mod.error = function(self, statusCode, message)
	if self ~= mod then
		error("api:error(statusCode, message): use `:`", 2)
	end
	if type(statusCode) ~= Type.integer then
		error("api:error(statusCode, message): statusCode should be an integer", 2)
	end
	if type(message) ~= Type.string then
		error("api:error(statusCode, message): message should be a string", 2)
	end

	local err = {statusCode = statusCode, message = message}
	setmetatable(err, errorMT)
	return err
end


-- posts secret to the /secret path
-- secret: string
-- callback: function(boolean: ok, string: msg)
-- 		ok: boolean
--		msg: string
mod.postSecret = function(self, secret, callback)
	if self ~= mod then
		error("api:postSecret(secret, callback): use `:`", 2)
	end
	if type(secret) ~= type.string then
		error("api:postSecret(secret, callback): secret should be a string", 2)
	end
	if type(callback) ~= "function" then
		error("api:postSecret(secret, callback): callback should be a function (boolean, string)", 2)
	end

	local url = mod.kApiAddr .. "/secret"
	local body = {
		secret = secret,
	}
	HTTP:Post(url, body, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, "http status not 200")
			return
		end
		local response, err = JSON:Decode(resp.Body)
		callback(true, response.message) -- success
	end)
end

-- search Users by username substring
-- searchText: string
-- callback: function(ok, users, errMsg)
-- 		ok: boolean
-- 		users: []User or nil
-- 		errMsg: string or nil
mod.searchUser = function(self, searchText, callback)
	if self ~= mod then
		error("api:searchUser(searchText, callback): use `:`", 2)
	end
	if type(searchText) ~= type.string then
		error("api:searchUser(searchText, callback): searchText should be a string", 2)
	end
	if type(callback) ~= "function" then
		error("api:searchUser(searchText, callback): callback should be a function (boolean, []User, string)", 2)
	end

	HTTP:Get(mod.kApiAddr .. "/user-search-others/" .. searchText, function(resp)
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
end

-- gets User's friends
-- callback: function(ok, friends, errMsg)
-- 		ok: boolean
-- 		friends: []User or nil
-- 		errMsg: string or nil
mod.getFriends = function(self, callback)
	if self ~= mod then
		error("api:getFriends(callback): use `:`", 2)
	end
	if type(callback) ~= "function" then
		error("api:getFriends(callback): callback should be a function (boolean, []User, string)", 2)
	end

	HTTP:Get(mod.kApiAddr .. "/friend-relations", function(resp)
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
end

-- returns how manu friends the local User has
-- callback: function(ok, count, errMsg)
--		ok: boolean
--		count: integer
--		errMsg: string or nil
mod.getFriendCount = function(self, callback)
	if self ~= mod then
		error("api:getFriendCount(callback): use `:`", 2)
	end
	if type(callback) ~= "function" then
		error("api:getFriendCount(callback): callback should be a function (boolean, integer, string)", 2)
	end

	self:getFriends(function(ok, friends, errMsg)
		local count = 0
		if friends ~= nil then
			count = #friends
		end
		callback(ok, count, errMsg)
	end)
end

-- sends a friend request to the specified user
-- userID: string
-- callback: function(ok, errMsg)
--		ok: boolean
--		errMsg: string or nil
mod.sendFriendRequest = function(self, userID, callback)
	if self ~= mod then
		error("api:sendFriendRequest(userID, callback): use `:`", 2)
	end
	if type(userID) ~= Type.string then
		error("api:sendFriendRequest(userID, callback): userID should be a string", 2)
	end
	if type(callback) ~= "function" then
		error("api:sendFriendRequest(userID, callback): callback should be a function (boolean, string)", 2)
	end

	local url = mod.kApiAddr .. "/friend-request"
	local body = {
		senderID = Player.UserID,
		recipientID = userID,
	}
	HTTP:Post(url, body, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, "http status not 200")
			return
		end
		callback(true, nil) -- success
	end)
end

-- cancels the friend request to the specified user
-- recipientID: string
-- callback: function(ok, errMsg)
--		ok: boolean
--		errMsg: string or nil
mod.cancelFriendRequest = function(self, recipientID, callback)
	if self ~= mod then
		error("api:cancelFriendRequest(recipientID, callback): use `:`", 2)
	end
	if type(recipientID) ~= Type.string then
		error("api:cancelFriendRequest(recipientID, callback): recipientID should be a string", 2)
	end
	if type(callback) ~= "function" then
		error("api:cancelFriendRequest(recipientID, callback): callback should be a function (boolean, string)", 2)
	end

	local url = mod.kApiAddr .. "/friend-request-cancel"
	local body = {
		senderID = Player.UserID,
		recipientID = recipientID,
	}
	HTTP:Post(url, body, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, "http status not 200")
			return
		end
		callback(true, nil) -- success
	end)
end

-- returns the userIDs for which the local user sent a friend request
-- callback: function(ok, reqs, errMsg)
--		ok: boolean
--		reqs: []string (userIDs) or nil
--		errMsg: string or nil
mod.getSentFriendRequests = function(self, callback)
	if self ~= mod then
		error("api:getSentFriendRequests(callback): use `:`", 2)
	end
	if type(callback) ~= "function" then
		error("api:getSentFriendRequests(callback): callback should be a function (boolean, []string, string)", 2)
	end

	local url = mod.kApiAddr .. "/friend-requests-sent"
	HTTP:Get(url, function(resp)
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
end

-- returns the userIDs of users that sent a friend request to the local user 
-- callback: function(ok, reqs, errMsg)
--		ok: boolean
--		reqs: []string (userIDs) or nil
--		errMsg: string or nil
mod.getReceivedFriendRequests = function(self, callback)
	if self ~= mod then
		error("api:getReceivedFriendRequests(callback): use `:`", 2)
	end
	if type(callback) ~= "function" then
		error("api:getReceivedFriendRequests(callback): callback should be a function (boolean, []string, string)", 2)
	end

	local url = mod.kApiAddr .. "/friend-requests-received"
	HTTP:Get(url, function(resp)
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
end

-- getUserInfo gets a user by its ID
-- id: string
-- callback: function(ok, user, errMsg)
--		ok: boolean
--		user: table or nil
--		errMsg: string or nil
mod.getUserInfo = function(self, id, callback)
	-- validate arguments
	if self ~= mod then
		error("api:getUserInfo(id, callback): use `:`", 2)
	end
	if type(id) ~= Type.string then
		error("api:getUserInfo(id, callback): id should be a string", 2)
	end
	if type(callback) ~= "function" then
		error("api:getUserInfo(id, callback): callback should be a function (boolean, table, string)", 2)
	end
	
	local url = mod.kApiAddr .. "/user/" .. id
	HTTP:Get(url, function(resp)
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
end

-- replyToFriendRequest accepts or rejects a received friend request
-- usrID: string
-- accept: boolean
-- callback: function(ok, errMsg)
--		ok: boolean
--		errMsg: string or nil
mod.replyToFriendRequest = function(self, usrID, accept, callback)
	-- validate arguments
	if self ~= mod then
		error("api:replyToFriendRequest(id, usrID, accept, callback): use `:`", 2)
	end
	if type(usrID) ~= Type.string then
		error("api:replyToFriendRequest(id, usrID, accept, callback): usrID should be a string", 2)
	end
	if type(accept) ~= Type.boolean then
		error("api:replyToFriendRequest(id, usrID, accept, callback): accept should be a boolean", 2)
	end
	if type(callback) ~= "function" then
		error("api:replyToFriendRequest(id, usrID, accept, callback): callback should be a function (boolean, string)", 2)
	end

	local url = mod.kApiAddr .. "/friend-request-reply"
	local body = {
		senderID = usrID,
		accept = accept,
	}
	HTTP:Post(url, body, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, "http status not 200")
			return
		end
		callback(true, nil) -- success
	end)
end

-- --------------------------------------------------
-- BLUEPRINTS
-- --------------------------------------------------

-- Lists items using filter.
-- filer: table
-- example:
-- filter = {
--   category = "hat",
--   repo = "caillef",
-- }
--
-- callback: function(error, items)
--		error: string or nil
--		items: []Item or nil
mod.getItems = function(self, filter, callback)
	-- /itemdrafts?search=banana,gdevillele&page=1&perPage=100
	
	-- validate arguments
	if self ~= mod then
		error("api:getItems(filter, callback): use `:`", 2)
	end
	if type(filter) ~= "table" then
		error("api:getItems(filter, callback): filter should be a table", 2)
	end
	if type(callback) ~= "function" then
		error("api:getItems(filter, callback): callback should be a function (string, []Item)", 2)
	end

	local filterIsValid = function (k, v)
		if type(k) ~= "string" then
			return false
		end

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
	HTTP:Get(url, function(resp)
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
end

-- Lists world drafts using filter.
-- filer: table
-- example:
-- filter = {
--   repo = "caillef",
--   category = "fps",
-- }
-- NOTE: categories are not in place yet, but they would be useful,
-- keeping filter in place client side, waiting for backend to support it.
--
-- callback:function(error, items)
--		error: string or nil
--		items: []World or nil
mod.getWorlds = function(self, filter, callback)
	-- GET /worlddrafts?search=banana,gdevillele&page=1&perPage=100

	-- validate arguments
	if self ~= mod then
		error("api:getWorlds(filter, callback): use `:`", 2)
	end
	if type(filter) ~= Type.table then
		error("api:getWorlds(filter, callback): filter should be a table", 2)
	end
	if type(callback) ~= "function" then
		error("api:getWorlds(filter, callback): callback should be a function (string, []World)", 2)
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
	HTTP:Get(url, function(resp)
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
end

-- returns World associated with the provided worldID
-- worldID: string
-- callback: function(error, world)
--		error: string or nil
--		world: World or nil
mod.getWorld = function(self, worldID, callback)
	if self ~= mod then
		error("api:getWorld(worldID, callback): use `:`", 2)
	end
	if type(worldID) ~= Type.string then
		error("api:getWorld(worldID, callback): worldID should be a string", 2)
	end
	if type(callback) ~= "function" then
		error("api:getWorld(worldID, callback): callback should be a function (string, World)", 2)
	end

	local url = mod.kApiAddr .. "/worlds/" .. worldID

	-- send request
	HTTP:Get(url, function(resp)
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
		
		callback(nil, world) -- success
	end)
end

-- creates a World with the provided data, example:
-- api:createWorld({title = "banana", category = nil, original = nil}, function(err, world))
-- data: table
-- callback: function(err, world)
--		err: api.error instance
--		world: World
mod.createWorld = function(self, data, callback)
	if self ~= mod then
		error("api:createWorld(data, callback): use `:`", 2)
	end
	if type(data) ~= Type.table then
		error("api:createWorld(data, callback): data should be a table", 2)
	end
	if type(callback) ~= "function" then
		error("api:createWorld(data, callback): callback should be a function (api.error, world)", 2)
	end

	local url = self.kApiAddr .. "/worlddrafts"
	HTTP:Post(url, data, function(res)
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
end

-- modifies the world with given worldID with provided data, example:
-- api:patchWorld("world-id", {title = "something", description = "banana"}, function(err, world))
-- worldID: string
-- data: table
-- callback: function(err, world)
--		err: api.error instance
--		world: World
mod.patchWorld = function(self, worldID, data, callback)
	if self ~= mod then
		error("api:patchWorld(worldID, data, callback): use `:`", 2)
	end
	if type(worldID) ~= Type.string then
		error("api:patchWorld(worldID, data, callback): worldID should be a string", 2)
	end
	if type(data) ~= Type.table then
		error("api:patchWorld(worldID, data, callback): data should be a table", 2)
	end
	if type(callback) ~= "function" then
		error("api:patchWorld(worldID, data, callback): callback should be a function (api.error, world)", 2)
	end

	local url = self.kApiAddr .. "/worlddrafts/" .. worldID
	HTTP:Patch(url, data, function(res)
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
end

-- creates an Item with the provided data, example:
-- api:createItem({name = "banana", category = nil, original = nil}, function(err, item))
-- data: table
-- callback: function(err, item)
--		err: api.error instance
--		item: Item
-- api:createItem({name = "banana", category = nil, original = nil}, function(err, item))
mod.createItem = function(self, data, callback)
	if self ~= mod then
		error("api:createItem(data, callback): use `:`", 2)
	end
	if type(data) ~= Type.table then
		error("api:createItem(data, callback): data should be a table", 2)
	end
	if type(callback) ~= "function" then
		error("api:createItem(data, callback): callback should be a function (api.error, item)", 2)
	end

	local url = self.kApiAddr .. "/itemdrafts"
	HTTP:Post(url, data, function(res)
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
end

-- modifies the Item with given worldID with provided data, example:
-- api:patchItem("item-id", {description = "banana"}, function(err, item))
-- itemID: string
-- data: table
-- callback: function(err, item)
--		err: api.error instance
--		item: Item
mod.patchItem = function(self, itemID, data, callback)
	if self ~= mod then
		error("api:patchItem(worldID, data, callback): use `:`", 2)
	end
	if type(worldID) ~= Type.string then
		error("api:patchItem(worldID, data, callback): worldID should be a string", 2)
	end
	if type(data) ~= Type.table then
		error("api:patchItem(worldID, data, callback): data should be a table", 2)
	end
	if type(callback) ~= "function" then
		error("api:patchItem(worldID, data, callback): callback should be a function (api.error, item)", 2)
	end

	local url = self.kApiAddr .. "/itemdrafts/" .. itemID
	HTTP:Patch(url, data, function(res)
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
end

mod.updateAvatar = function(data, cb) -- data = { jacket="caillef.jacket", eyescolor={r=255, g=0, b=30} }
	local url = mod.kApiAddr .. "/users/self/avatar"
	HTTP:Patch(url, {}, data, function(res)
		if res.StatusCode ~= 200 then
			cb("Error (" .. res.StatusCode .. "): can't update avatar.", false)
			return
		end
		cb(nil, true)
	end)
end

mod.getUserId = function(username, cb)
	if not username then
		return cb("Error: first parameter of getUserId must be a username.")
	end
	local url = mod.kApiAddr.."/users?username="..username
	HTTP:Get(url, function(res)
		if res.StatusCode ~= 200 then
			return cb("Error (" .. res.StatusCode .. "): can't find user "..username..".")
		end
		cb(nil, JSON:Decode(res.Body).id)
	end)
end

mod.getAvatar = function(username, cb)
	mod.getUserId(username, function(err, id)
		if err then
			return cb(err)
		end
		local url = mod.kApiAddr .. "/users/"..id.."/avatar"
		HTTP:Get(url, function(res)
			if res.StatusCode ~= 200 then
				cb("Error (" .. res.StatusCode .. "): can't get avatar.")
				return
			end
			cb(nil, JSON:Decode(res.Body))
		end)
	end)
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

return mod
