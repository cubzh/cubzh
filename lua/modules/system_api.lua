--[[

[System] API module

]]
--

local time = require("time")
local api = require("api")

local mod = {
	kApiAddr = api.kApiAddr,
}

-- define the metatable of the module table
local moduleMT = {}
setmetatable(mod, moduleMT)

moduleMT.__tostring = function(_)
	return "system api module"
end

moduleMT.__index = function(_, key)
	-- try to find the key in `api` module first, and then in `system_api`
	return api[key] or moduleMT[key]
end

mod.checkUsername = function(_, username, callback)
	if type(username) ~= "string" then
		callback(false, "1st arg must be a string")
		return
	end
	if type(callback) ~= "function" then
		callback(false, "2nd arg must be a function")
		return
	end
	local url = mod.kApiAddr .. "/checks/username"
	local body = {
		username = username,
	}
	local req = System:HttpPost(url, body, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, "http status not 200")
			return
		end
		local response, err = JSON:Decode(resp.Body)
		if err ~= nil then
			callback(false, "json decode error:" .. err)
			return
		end
		-- response: {format = true, appropriate = true, available = true, key = "hash"}
		callback(true, response) -- success
	end)
	return req
end

-- callback(err, credentials)
mod.signUp = function(_, username, key, dob, password, callback)
	if type(username) ~= "string" then
		callback("1st arg must be a string")
		return
	end
	if type(key) ~= "string" then
		callback("2nd arg must be a string")
		return
	end
	if type(dob) ~= "string" then
		callback("3rd arg must be a string")
		return
	end
	if type(password) ~= "string" then
		callback("4th arg must be a string")
		return
	end
	if type(callback) ~= "function" then
		callback("5th arg must be a function")
		return
	end

	local url = mod.kApiAddr .. "/users"
	local body = {
		username = username,
		key = key,
		dob = dob,
		password = password,
	}

	local req = System:HttpPost(url, body, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, "http status not 200")
			return
		end
		local res, err = JSON:Decode(resp.Body)
		if err ~= nil then
			callback(false, "json decode error:" .. err)
			return
		end

		callback(nil, res.credentials) -- success
	end)

	return req
end

-- postSecret ...
-- callback(ok, errMsg)
moduleMT.postSecret = function(_, secret, callback)
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
	local req = System:HttpPost(url, body, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, "http status not 200")
			return
		end
		local response, _ = JSON:Decode(resp.Body)
		callback(true, response.message) -- success
	end)
	return req
end

-- search Users by username substring
-- callback(ok, users, errMsg)
-- ok: boolean
-- users: []User
-- errMsg: string
moduleMT.searchUser = function(_, searchText, callback)
	-- validate arguments
	if type(searchText) ~= "string" then
		api:error("api:getFriends(searchText, callback) - searchText must be a string", 2)
		return
	end
	if type(callback) ~= "function" then
		api:error("api:getFriends(searchText, callback) - callback must be a function", 2)
		return
	end
	local req = System:HttpGet(mod.kApiAddr .. "/user-search-others/" .. searchText, function(resp)
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
moduleMT.getFriends = function(_, callback)
	if type(callback) ~= "function" then
		api:error("api:getFriends(callback) - callback must be a function", 2)
		return
	end
	local req = System:HttpGet(mod.kApiAddr .. "/friend-relations", function(resp)
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
moduleMT.getFriendCount = function(self, callback)
	if type(callback) ~= "function" then
		api:error("api:getFriendCount(callback) - callback must be a function", 2)
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
moduleMT.sendFriendRequest = function(_, userID, callback)
	if type(userID) ~= "string" then
		callback(false, "1st arg must be a string")
		api:error("api:sendFriendRequest(userID, callback) - userID must be a string", 2)
		return
	end
	if type(callback) ~= "function" then
		api:error("api:sendFriendRequest(userID, callback) - callback must be a function", 2)
		return
	end
	local url = mod.kApiAddr .. "/friend-request"
	local body = {
		senderID = Player.UserID,
		recipientID = userID,
	}
	local req = System:HttpPost(url, body, function(resp)
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
moduleMT.cancelFriendRequest = function(_, recipientID, callback)
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
	local req = System:HttpPost(url, body, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, "http status not 200")
			return
		end
		callback(true, nil) -- success
	end)
	return req
end

-- replyToFriendRequest accepts or rejects a received friend request
-- callback(ok, errMsg)
moduleMT.replyToFriendRequest = function(_, usrID, accept, callback)
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
	local req = System:HttpPost(url, body, function(resp)
		if resp.StatusCode ~= 200 then
			callback(false, "http status not 200")
			return
		end
		callback(true, nil) -- success
	end)
	return req
end

-- api:createWorld({title = "banana", category = nil, original = nil}, function(err, world))
moduleMT.createWorld = function(self, data, callback)
	local url = self.kApiAddr .. "/worlddrafts"
	local req = System:HttpPost(url, data, function(res)
		if res.StatusCode ~= 200 then
			callback(api:error(res.StatusCode, "could not create world"), nil)
			return
		end

		local world, err = JSON:Decode(res.Body)
		if err ~= nil then
			callback(api:error(res.StatusCode, "could not decode response"), nil)
			return
		end

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

		callback(nil, world)
	end)
	return req
end

-- api:patchWorld("world-id", {title = "something", description = "banana"}, function(err, world))
moduleMT.patchWorld = function(self, worldID, data, callback)
	local url = self.kApiAddr .. "/worlddrafts/" .. worldID
	local req = System:HttpPatch(url, data, function(res)
		if res.StatusCode ~= 200 then
			callback(api:error(res.StatusCode, "could not modify world"), nil)
			return
		end

		local world, err = JSON:Decode(res.Body)
		if err ~= nil then
			callback(api:error(res.StatusCode, "could not decode response"), nil)
			return
		end

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

		callback(nil, world)
	end)
	return req
end

moduleMT.likeWorld = function(self, worldID, addLike, callback)
	local url = self.kApiAddr .. "/worlds/" .. worldID .. "/likes"
	local t = { value = addLike }
	local body = JSON:Encode(t)
	local req = System:HttpPatch(url, body, function(res)
		if res.StatusCode ~= 200 then
			callback(api:error(res.StatusCode, "could not modify world's likes"), nil)
			return
		end
		callback(nil, nil)
	end)
	return req
end

moduleMT.likeItem = function(self, itemID, addLike, callback)
	local url = self.kApiAddr .. "/items/" .. itemID .. "/likes"
	local t = { value = addLike }
	local body = JSON:Encode(t)
	local req = System:HttpPatch(url, body, function(res)
		if res.StatusCode ~= 200 then
			callback(api:error(res.StatusCode, "could not modify item's likes"))
			return
		end
		callback(nil) -- success
	end)
	return req
end

-- api:createItem({name = "banana", category = nil, original = nil}, function(err, item))
moduleMT.createItem = function(self, data, callback)
	local url = self.kApiAddr .. "/itemdrafts"
	local req = System:HttpPost(url, data, function(res)
		if res.StatusCode ~= 200 then
			callback(api:error(res.StatusCode, "could not create item"), nil)
			return
		end

		local item, err = JSON:Decode(res.Body)
		if err ~= nil then
			callback(api:error(res.StatusCode, "could not decode response"), nil)
			return
		end

		if item.created then
			item.created = time.iso8601_to_os_time(item.created)
		end
		if item.updated then
			item.updated = time.iso8601_to_os_time(item.updated)
		end
		if item.likes ~= nil then
			item.likes = math.floor(item.likes)
		else
			item.likes = 0
		end
		if item.views ~= nil then
			item.views = math.floor(item.views)
		else
			item.views = 0
		end

		callback(nil, item)
	end)
	return req
end

-- api:patchItem("item-id", {description = "banana"}, function(err, item))
moduleMT.patchItem = function(self, itemID, data, callback)
	local url = self.kApiAddr .. "/itemdrafts/" .. itemID
	local req = System:HttpPatch(url, data, function(res)
		if res.StatusCode ~= 200 then
			callback(api:error(res.StatusCode, "could not modify item"), nil)
			return
		end

		local item, err = JSON:Decode(res.Body)
		if err ~= nil then
			callback(api:error(res.StatusCode, "could not decode response"), nil)
			return
		end

		if item.created then
			item.created = time.iso8601_to_os_time(item.created)
		end
		if item.updated then
			item.updated = time.iso8601_to_os_time(item.updated)
		end
		if item.likes ~= nil then
			item.likes = math.floor(item.likes)
		else
			item.likes = 0
		end
		if item.views ~= nil then
			item.views = math.floor(item.views)
		else
			item.views = 0
		end

		callback(nil, item)
	end)
	return req
end

moduleMT.updateAvatar = function(_, data, cb) -- data = { jacket="caillef.jacket", eyescolor={r=255, g=0, b=30} }
	local url = mod.kApiAddr .. "/users/self/avatar"
	local req = System:HttpPatch(url, {}, data, function(res)
		if res.StatusCode ~= 200 then
			cb("Error (" .. res.StatusCode .. "): can't update avatar.", false)
			return
		end
		cb(nil, true)
	end)
	return req
end

-- info: table ({bio = "...", ...})
-- callback: function(err)
moduleMT.patchUserInfo = function(_, info, callback)
	local url = mod.kApiAddr .. "/users/self"

	if type(info) ~= Type.table then
		api:error("system_api:patchUserInfo(info, callback): info should be a table", 2)
	end
	if type(callback) ~= "function" then
		api:error("system_api:patchUserInfo(info, callback): callback should be a function", 2)
	end

	local filterIsValid = function(k, v)
		if type(k) ~= Type.string or type(v) ~= Type.string then
			return false
		end
		return k == "bio" or k == "discord" or k == "x" or k == "tiktok" or k == "website"
	end

	for k, v in pairs(info) do
		if not filterIsValid(k, v) then
			api:error("system_api:patchUserInfo(info, callback): key or value is not valid: " .. k .. " " .. v, 2)
		end
	end

	local req = System:HttpPatch(url, info, function(res)
		if res.StatusCode ~= 200 then
			callback("Error (" .. res.StatusCode .. "): can't update user info")
			return
		end
		callback(nil)
	end)
	return req
end

-- moduleMT.getTransactions = function(usernameOrCb, cb) -- or self if nil
-- usernameOrCb(nil, {
-- { id="09c5cd9e-9c3a-4dc5-8083-06b77e1095e3", from={id="209809842",name="caillef"}, to={id="20980242",name="gdevillele"}, amount=283, action="buy", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.coffee" }, copyId=123, date="2023-03-20T17:01:14.625402882Z" },
-- { id="09c5cd9e-9c3a-4dc5-8083-06b77e1095f3", from={id="20980242",name="gdevillele"}, to={id="209809842",name="caillef"}, amount=200, action="buy", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.coffee" }, copyId=123, date="2023-02-01T15:00:14.625402882Z" },
-- { id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d3", from={id="0",name="treasure"}, to={id="209809842",name="caillef"}, amount=100, action="mint", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.coffee" }, copyId=120, date="2022-08-10T16:00:14.625402882Z" },
-- { id="09c5cd9e-9c3a-4dc5-8083-06b77e1095e3", from={id="209809842",name="caillef"}, to={id="20980242",name="gdevillele"}, amount=283, action="buy", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copyId=123, date="2020-07-12T17:01:14.625402882Z" },
-- { id="09c5cd9e-9c3a-4dc5-8083-06b77e1095f3", from={id="20980242",name="gdevillele"}, to={id="209809842",name="caillef"}, amount=200, action="buy", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copyId=123, date="2020-07-10T15:00:14.625402882Z" },
-- { id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d3", from={id="0",name="treasure"}, to={id="209809842",name="caillef"}, amount=100, action="mint", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copyId=120, date="2020-06-10T16:00:14.625402882Z" }
-- })
-- end

-- moduleMT.listItem = function(price, maxSupply, cb)
-- local body = { price=price, maxSupply=maxSupply }
-- cb(nil, { result={
-- 	id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d3",
-- 	itemId="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5",
-- 	itemSlug="caillef.shop",
-- 	owner={ id="209809842", name="caillef" },
-- 	latestTransactions = { -- 5 latest transactions
-- 		{ id="b9c5cd9e-9c3a-4dc5-8083-06b77e109500", from={id="0",name="treasure"}, to={id="209809842",name="caillef"}, amount=100, action="mint", item="caillef.shop", copy=68, date="2020-07-10 20:00:00.000" }
-- 	},
-- 	copyId=68,
-- 	createdAt="2020-06-10 15:00:00.000"
-- }})
-- end

-- moduleMT.mintCopy = function(itemId)
-- cb(nil, {
-- 	id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d3",
-- 	item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" },
-- 	copyId=68,
-- 	owner={id="209809842", name="caillef"},
-- 	createdAt="2020-06-10 15:00:00.000"
-- })
-- end

-- moduleMT.getCopies = function(itemId, filtersOrCb, cb)
-- 	cb(nil, {
-- 		{
-- 			id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d3",
-- 			item = { id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" },
-- 			copyId=68,
-- 			listingPrice=80,
-- 			owner={id="209809848", name="gdevillele"},
-- 			createdAt="2020-06-10 15:00:00.000"
-- 		},
-- 		{
-- 			id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d4",
-- 			item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" },
-- 			copyId=97,
-- 			listingPrice=81,
-- 			owner={id="20989842", name="aduermael"},
-- 			createdAt="2020-06-10 15:00:00.000"
-- 		},
-- 		{
-- 			id="09c5cd9e-9c3a-4dc5-8083-06b77e1095e6",
-- 			item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" },
-- 			copyId=120,
-- 			listingPrice=100,
-- 			owner={id="209809842", name="caillef"},
-- 			createdAt="2020-06-10 15:00:00.000"
-- 		}
-- 	})
-- end

-- moduleMT.listCopy = function(itemId, price, duration, cb)
-- 	cb(nil, {
-- 		id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d3",
-- 		item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" },
-- 		copyId=68,
-- 		listingPrice=80,
-- 		endListing="2020-06-10 15:00:00.000",
-- 		owner={ id="209809848", name="gdevillele" },
-- 		createdAt="2020-06-10 15:00:00.000"
-- 	})
-- end

-- moduleMT.getCopyTransactions = function(copyId, cb)
-- 	cb(nil, {
-- 		{ id="b9c5cd9e-9c3a-4dc5-8083-06b77e109500", from={id="209809843",name="gdevillele"}, to={id="209809842",name="caillef"}, amount=140, action="buy", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copy=68, date="2020-07-10 22:00:00.000" },
-- 		{ id="b9c5cd9e-9c3a-4dc5-8083-06b77e109501", from={id="209809842",name="caillef"}, to={id="209809843",name="gdevillele"}, amount=120, action="buy", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copy=68, date="2020-07-10 21:00:00.000" },
-- 		{ id="b9c5cd9e-9c3a-4dc5-8083-06b77e109502", from={id="0",name="treasure"}, to={id="209809842",name="caillef"}, amount=100, action="mint", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copy=68, date="2020-07-10 20:00:00.000" }
-- 	})
-- end

-- moduleMT.buyCopy = function(copyId,cb)
-- 	cb(nil, {
-- 		id="09c5cd9e-9c3a-4dc5-8083-06b77e1095d3",
-- 		item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" },
-- 		copyId=68,
-- 		latestTransactions={
-- 			{ id="b9c5cd9e-9c3a-4dc5-8083-06b77e109501", from={id="209809842",name="caillef"}, to={id="209809843",name="gdevillele"}, amount=120, action="buy", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copy=68, date="2020-07-10 21:00:00.000" },
-- 			{ id="b9c5cd9e-9c3a-4dc5-8083-06b77e109502", from={id="0",name="treasure"}, to={id="209809842",name="caillef"}, amount=100, action="mint", item={ id="09b5cd9f-9c3a-4dc5-8083-06b77e1099e5", slug="caillef.shop" }, copy=68, date="2020-07-10 20:00:00.000" },
-- 		},
-- 		owner={id="209809848",name="gdevillele"},
-- 		createdAt="2020-06-10 15:00:00.000"
-- 	})
-- end

return mod
