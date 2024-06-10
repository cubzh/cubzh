-- TODO: use private fields like in `avatar` module for avatar node instance

--- This module allows you to create UI element from player avatars
---@code -- A few examples:
---
--- -- Place the head of "playerUsername" randomly on the screen with a size of 100
--- local uiavatar = require("ui_avatar")
--- local uiHead = uiavatar:getHead("playerUsername" or Player.UserID, 100) -- 100 is the sized
--- uiHead.pos = { 100 + math.random() * (Screen.Width - 400), 100 + math.random() * (Screen.Height - 400), 0 } -- place the head randomly
--- uiHead.Width = math.random(100,200) -- to set a random size to the head. Height and Width are the same here because the head is spherized
--- -- Place a body in the UI
--- local uiBody = require("ui_avatar"):get("caillef")
--- uiBody.Width = 500
--- uiBody.pos = {10, 10, 0}

local uiavatar = {}

-- GLOBALS

ui = require("uikit")
avatar = require("avatar")

defaultSize = 30

function emptyFunc() end

function setupNodeAvatar(node, avatar, ui)
	local rotation = Rotation(0, math.rad(180), 0)

	if node.body ~= nil then
		rotation:Set(node.body.pivot.LocalRotation)
		node.body:remove()
		node.body = nil
	end

	local uiAvatar = ui:createShape(avatar, { spherized = true })

	uiAvatar:setParent(node)
	uiAvatar.Head.LocalRotation:Set(Number3.Zero)
	node.body = uiAvatar
	node.body.Width = node.Width
	node.body.pivot.LocalRotation:Set(rotation)

	node.load = function(self, config)
		avatar:load(config)
	end
	node.loadEquipment = function(self, config)
		avatar:loadEquipment(config)
	end
	node.setColors = function(self, config)
		avatar:setColors(config)
	end
	node.setEyes = function(self, config)
		avatar:setEyes(config)
	end
	node.setNose = function(self, config)
		avatar:setNose(config)
	end
end

-- EXPOSED FUNCTIONS

-- returns uikit node + sent requests (table, can be nil)
-- /!\ return table of requests does not contain all requests right away
-- reference should be kept, not copying entries right after function call.
-- uikit: optional, allows to provide specific instance of uikit
uiavatar.get = function(self, config)
	if self ~= uiavatar then
		error("ui_avatar:get(config) should be called with `:`", 2)
	end

	local defaultConfig = {
		usernameOrId = "", -- loading "empty" avatar from bundle when empty
		size = defaultSize,
		didLoad = emptyFunc, -- can be multiple times when changing body parts
		ui = ui, -- can only be used by System to override UI instance
		eyeBlinks = true,
	}

	ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config)
	end)
	if not ok then
		error("ui_avatar:get(config) - config error: " .. err, 2)
	end

	local requests

	local ui = config.ui
	local node = ui:createFrame(Color(0, 0, 0, 0))

	local w = 0
	local h = 0

	local function didLoad(err)
		if err ~= nil then
			error(err, 2)
		end

		if config.didLoad then
			config:didLoad()
		end
	end

	node.onRemove = function()
		node:loadEquipment({ type = "jacket", item = "" })
		node:loadEquipment({ type = "hair", item = "" })
		node:loadEquipment({ type = "pants", item = "" })
		node:loadEquipment({ type = "boots", item = "" })

		for _, r in ipairs(requests) do
			r:Cancel()
		end
	end

	node._width = function(_)
		return w
	end
	node._height = function(_)
		return h
	end

	local setWidth = node._setWidth
	local setHeight = node._setHeight

	node._setWidth = function(self, v)
		w = v
		h = v -- spherized
		if self.body then
			self.body.Width = v
		end
		setWidth(self, v) -- spherized
		setHeight(self, v) -- spherized
	end

	node._setHeight = function(self, v)
		w = v
		h = v -- spherized
		if self.body then
			self.body.Height = v
		end
		setWidth(self, v) -- spherized
		setHeight(self, v) -- spherized
	end

	node.Width = config.size

	local avatarObject
	avatarObject, requests =
		avatar:get({ usernameOrId = config.usernameOrId, didLoad = didLoad, eyeBlinks = config.eyeBlinks })
	setupNodeAvatar(node, avatarObject, config.ui)

	return node, requests
end

-- returns uikit node + sent requests (table, can be nil)
-- /!\ return table of requests does not contain all requests right away
-- reference should be kept, not copying entries right after function call.
-- uikit: optional, allows to provide specific instance of uikit
uiavatar.getHead = function(_, usernameOrId, size, uikit, config)
	local requests

	local ui = uikit or ui

	local defaultSize = size or defaultSize

	local defaultConfig = {
		ignoreCache = false,
		spherized = true,
	}

	config = require("config"):merge(defaultConfig, config)

	local cachedHead = headCache[usernameOrId]

	if config.ignoreCache == true then
		cachedHead = nil
	end

	local node = ui:createFrame(Color(0, 0, 0, 0))
	node._w = defaultSize
	node._h = defaultSize
	node._width = function(self)
		return self._w
	end
	node._height = function(self)
		return self._h
	end

	if cachedHead ~= nil then
		local uiHead = ui:createShape(Shape(cachedHead, { includeChildren = true }), { spherized = true })
		uiHead:setParent(node)
		node.head = uiHead
		node.head.Width = node.Width

		local center = Number3(node.head.shape.Width, node.head.shape.Height, node.head.shape.Depth)
		node.head.shape.Pivot = node.head.shape:BlockToLocal(center)
	else
		local head
		head, requests = avatar:getPlayerHead({ usernameOrId = usernameOrId })

		local uiHead = ui:createShape(Shape(head, { includeChildren = true }), { spherized = false })
		uiHead:setParent(node)
		node.head = uiHead
		local ratio = node.head.Width / node.head.Height

		local center = Number3(node.head.shape.Width, node.head.shape.Height, node.head.shape.Depth)
		node.head.shape.Pivot = node.head.shape:BlockToLocal(center)

		node.head.parentDidResize = function(self)
			self.Width = node.Width
			self.Height = node.head.Width / ratio
		end
		node.head:parentDidResize()

		-- , function(err, head)
		-- 			if err then
		-- 				print(err)
		-- 				return
		-- 			end
		-- 			-- Optimized cache: If ID, try to get the username from the Players list. Cache keys can be username or ids
		-- 			if type(usernameOrId) ~= "string" then
		-- 				for _, p in pairs(Players) do
		-- 					if p.UserID == usernameOrId then
		-- 						usernameOrId = p.Username
		-- 					end
		-- 				end
		-- 			end
		-- 			headCache[usernameOrId] = head
		-- 			local uiHead = ui:createShape(Shape(head, { includeChildren = true }), { spherized = true })
		-- 			uiHead:setParent(node)
		-- 			node.head = uiHead
		-- 			node.head.Width = node.Width

		-- 			local center = Number3(node.head.shape.Width, node.head.shape.Height, node.head.shape.Depth)
		-- 			node.head.shape.Pivot = node.head.shape:BlockToLocal(center)
		-- 		end)

		node.onRemove = function()
			for _, r in ipairs(requests) do
				r:Cancel()
			end
		end
	end

	local setWidth = node._setWidth
	local setHeight = node._setHeight

	node._setWidth = function(self, v)
		self._w = v
		self._h = v -- spherized
		if self.head then
			self.head.Width = v
		end
		setWidth(self, v) -- spherized
		setHeight(self, v) -- spherized
	end
	node._setHeight = function(self, v)
		self._w = v
		self._h = v -- spherized
		if self.head then
			self.head.Height = v
		end
		setWidth(self, v) -- spherized
		setHeight(self, v) -- spherized
	end

	return node, requests
end

-- returns uikit node + sent requests (table, can be nil)
-- /!\ return table of requests does not contain all requests right away
-- reference should be kept, not copying entries right after function call.
-- uikit: optional, allows to provide specific instance of uikit
uiavatar.getHeadAndShoulders = function(self, config)
	if self ~= uiavatar then
		error("ui_avatar:getHeadAndShoulders(config) should be called with `:`", 2)
	end

	local defaultConfig = {
		usernameOrId = "", -- loading "empty" avatar from bundle when empty
		size = defaultSize,
		didLoad = emptyFunc, -- can be multiple times when changing body parts
		ui = ui, -- can only be used by System to override UI instance
		eyeBlinks = true,
	}

	ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config)
	end)
	if not ok then
		error("ui_avatar:getHeadAndShoulders(config) - config error: " .. err, 2)
	end

	local requests

	local ui = config.ui
	local node = ui:createFrame(Color(0, 0, 0, 0))

	node.IsMask = true
	local w = 0
	local h = 0

	local function didLoad(err)
		if err ~= nil then
			error(err, 2)
		end

		if config.didLoad then
			config:didLoad()
		end
	end

	node.onRemove = function()
		node:loadEquipment({ type = "jacket", item = "" })
		node:loadEquipment({ type = "hair", item = "" })
		node:loadEquipment({ type = "pants", item = "" })
		node:loadEquipment({ type = "boots", item = "" })

		for _, r in ipairs(requests) do
			r:Cancel()
		end
	end

	node._width = function(_)
		return w
	end
	node._height = function(_)
		return h
	end

	local setWidth = node._setWidth
	local setHeight = node._setHeight

	node._setWidth = function(self, v)
		w = v
		h = v -- spherized
		if self.body then
			self.body.Width = v
		end
		setWidth(self, v) -- spherized
		setHeight(self, v) -- spherized
	end

	node._setHeight = function(self, v)
		w = v
		h = v -- spherized
		if self.body then
			self.body.Height = v
		end
		setWidth(self, v) -- spherized
		setHeight(self, v) -- spherized
	end

	node.Width = config.size

	local avatarObject
	avatarObject, requests =
		avatar:get({ usernameOrId = config.usernameOrId, didLoad = didLoad, eyeBlinks = config.eyeBlinks })
	setupNodeAvatar(node, avatarObject, config.ui)

	return node, requests

	-- local bodyDidLoad = function(err, avatarBody)
	-- 	if err ~= nil then
	-- 		error(err, 2)
	-- 		return
	-- 	end

	-- 	local rotation = Rotation(0, math.rad(180), 0)

	-- 	if node.body ~= nil then
	-- 		rotation:Set(node.body.pivot.LocalRotation)
	-- 		node.body:remove()
	-- 		node.body = nil
	-- 	end

	-- 	-- local shape = Shape(avatarBody, { includeChildren = true })
	-- 	local shape = avatarBody
	-- 	shape.LocalPosition = Number3.Zero

	-- 	-- -12 -> centered (body position set in animation cycle)
	-- 	-- -14 -> from below shoulders
	-- 	local uiBody = ui:createShape(shape, { spherized = false, offset = Number3(0, -18, 0) })
	-- 	uiBody:setParent(node)
	-- 	uiBody.Head.LocalRotation = { 0, 0, 0 }
	-- 	node.body = uiBody
	-- 	uiBody.ratio = uiBody.Width / uiBody.Height

	-- 	-- NOTE: this needs to be improved, to programatically crop
	-- 	-- perfectly around the head, considering hair / headsets, etc.
	-- 	-- [gdevillele] _w field can be nil, I don't understand why
	-- 	node.body.Width = (node._w or 0) * 1.1
	-- 	node.body.Height = node.body.Width / uiBody.ratio

	-- 	node.body.pivot.LocalRotation = rotation

	-- 	node.body.pos = { 0, 0 }
	-- end

	-- _, requests = avatar:get(usernameOrId, nil, bodyDidLoad)

	-- node.onRemove = function()
	-- 	for _, r in ipairs(requests) do
	-- 		r:Cancel()
	-- 	end
	-- end

	-- node._width = function(self)
	-- 	return self._w
	-- end
	-- node._height = function(self)
	-- 	return self._h
	-- end

	-- local setWidth = node._setWidth
	-- local setHeight = node._setHeight

	-- node._setWidth = function(self, v)
	-- 	self._w = v
	-- 	self._h = v -- spherized
	-- 	if self.body then
	-- 		self.body.Width = v * 2
	-- 		self.body.pos.X = -self.body.Width * 0.25
	-- 		self.body.pos.Y = -self.body.Height * 0.5
	-- 	end
	-- 	setWidth(self, v) -- spherized
	-- 	setHeight(self, v) -- spherized
	-- end

	-- node._setHeight = function(self, v)
	-- 	self._w = v
	-- 	self._h = v -- spherized
	-- 	if self.body then
	-- 		self.body.Width = v * 2
	-- 		self.body.pos.X = -self.body.Width * 0.25
	-- 		self.body.pos.Y = -self.body.Height * 0.5
	-- 	end
	-- 	setWidth(self, v) -- spherized
	-- 	setHeight(self, v) -- spherized
	-- end

	-- node.Width = defaultSize

	-- return node, requests
end

return uiavatar
