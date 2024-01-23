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

local DEFAULT_SIZE = 30

ui = require("uikit")
avatar = require("avatar")

local headCache = {}

local uiavatarMetatable = {
	__index = {
		clearCache = function(_)
			headCache = {}
		end,

		preloadHeads = function(self, playersTable)
			if type(playersTable) ~= "table" then
				playersTable = { playersTable }
			end
			for _, p in pairs(playersTable) do
				local username
				if type(p) == "string" then
					username = p
				elseif type(p) == "Player" then
					username = p.Username
				end
				if self._headCache[username] then
					return
				end -- Do not reload the head if already in cache
				avatar:getPlayerHead(username, function(err, head)
					if err then
						return
					end
					headCache[username] = head
				end)
			end
		end,

		-- returns uikit node + sent requests (table, can be nil)
		-- /!\ return table of requests does not contain all requests right away
		-- reference should be kept, not copying entries right after function call.
		-- uikit: optional, allows to provide specific instance of uikit
		getHead = function(_, usernameOrId, size, uikit, config)
			local requests

			local ui = uikit or ui

			local defaultSize = size or DEFAULT_SIZE

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
				requests = avatar:getPlayerHead(usernameOrId, function(err, head)
					if err then
						print(err)
						return
					end
					-- Optimized cache: If ID, try to get the username from the Players list. Cache keys can be username or ids
					if type(usernameOrId) ~= "string" then
						for _, p in pairs(Players) do
							if p.UserID == usernameOrId then
								usernameOrId = p.Username
							end
						end
					end
					headCache[usernameOrId] = head
					local uiHead = ui:createShape(Shape(head, { includeChildren = true }), { spherized = true })
					uiHead:setParent(node)
					node.head = uiHead
					node.head.Width = node.Width

					local center = Number3(node.head.shape.Width, node.head.shape.Height, node.head.shape.Depth)
					node.head.shape.Pivot = node.head.shape:BlockToLocal(center)
				end)

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
		end,

		-- changes only local Player
		setSkinColor = function(self, node, color1, color2, nose, mouth)
			if node.body ~= nil then
				avatar:setSkinColor(node.body, color1, color2, nose, mouth)
			end

			self:setNoseColor(node, nose, true)
			self:setMouthColor(node, mouth, true)
		end,

		setEyesColor = function(_, avatarNode, color)
			if avatarNode.body ~= nil then
				avatar:setEyesColor(avatarNode.body, color)
			end
		end,

		setNoseColor = function(_, avatarNode, color)
			if avatarNode.body ~= nil then
				avatar:setNoseColor(avatarNode.body, color)
			end
		end,

		setMouthColor = function(_, avatarNode, color)
			if avatarNode.body ~= nil then
				avatar:setMouthColor(avatarNode.body, color)
			end
		end,

		-- returns uikit node + sent requests (table, can be nil)
		-- /!\ return table of requests does not contain all requests right away
		-- reference should be kept, not copying entries right after function call.
		-- uikit: optional, allows to provide specific instance of uikit
		getHeadAndShoulders = function(_, usernameOrId, size, _, uikit)
			local requests

			local ui = uikit or ui
			local defaultSize = size or DEFAULT_SIZE

			local node = ui:createFrame(Color(255, 255, 255, 0))
			node.IsMask = true
			node._w = 0
			node._h = 0

			local bodyDidLoad = function(err, avatarBody)
				if err ~= nil then
					error(err, 2)
					return
				end

				local rotation = Rotation(0, math.rad(180), 0)

				if node.body ~= nil then
					rotation:Set(node.body.pivot.LocalRotation)
					node.body:remove()
					node.body = nil
				end

				-- local shape = Shape(avatarBody, { includeChildren = true })
				local shape = avatarBody
				shape.LocalPosition = Number3.Zero

				-- -12 -> centered (body position set in animation cycle)
				-- -14 -> from below shoulders
				local uiBody = ui:createShape(shape, { spherized = false, offset = Number3(0, -18, 0) })
				uiBody:setParent(node)
				uiBody.Head.LocalRotation = { 0, 0, 0 }
				node.body = uiBody
				uiBody.ratio = uiBody.Width / uiBody.Height

				-- NOTE: this needs to be improved, to programatically crop
				-- perfectly around the head, considering hair / headsets, etc.
				-- [gdevillele] _w field can be nil, I don't understand why
				node.body.Width = (node._w or 0) * 1.1
				node.body.Height = node.body.Width / uiBody.ratio

				node.body.pivot.LocalRotation = rotation

				node.body.pos = { 0, 0 }
			end

			_, requests = avatar:get(usernameOrId, nil, bodyDidLoad)

			node.onRemove = function()
				for _, r in ipairs(requests) do
					r:Cancel()
				end
			end

			node.refresh = function(_)
				_, requests = avatar:get(usernameOrId, nil, bodyDidLoad)
			end

			node._width = function(self)
				return self._w
			end
			node._height = function(self)
				return self._h
			end

			local setWidth = node._setWidth
			local setHeight = node._setHeight

			node._setWidth = function(self, v)
				self._w = v
				self._h = v -- spherized
				if self.body then
					self.body.Width = v * 2
					self.body.pos.X = -self.body.Width * 0.25
					self.body.pos.Y = -self.body.Height * 0.5
				end
				setWidth(self, v) -- spherized
				setHeight(self, v) -- spherized
			end

			node._setHeight = function(self, v)
				self._w = v
				self._h = v -- spherized
				if self.body then
					self.body.Width = v * 2
					self.body.pos.X = -self.body.Width * 0.25
					self.body.pos.Y = -self.body.Height * 0.5
				end
				setWidth(self, v) -- spherized
				setHeight(self, v) -- spherized
			end

			node.Width = defaultSize

			return node, requests
		end,

		-- returns uikit node + sent requests (table, can be nil)
		-- /!\ return table of requests does not contain all requests right away
		-- reference should be kept, not copying entries right after function call.
		-- uikit: optional, allows to provide specific instance of uikit
		get = function(_, usernameOrId, size, _, uikit)
			local requests

			local ui = uikit or ui

			local defaultSize = size or DEFAULT_SIZE

			local node = ui:createFrame(Color(0, 0, 0, 0))

			local bodyDidLoad = function(err, avatarBody)
				if err ~= nil then
					error(err, 2)
					return
				end

				local rotation = Rotation(0, math.rad(180), 0)

				if node.body ~= nil then
					rotation:Set(node.body.pivot.LocalRotation)
					node.body:remove()
					node.body = nil
				end

				local uiBody = ui:createShape(Shape(avatarBody, { includeChildren = true }), { spherized = true })
				uiBody:setParent(node)
				uiBody.Head.LocalRotation = { 0, 0, 0 }
				node.body = uiBody
				node.body.Width = node._w
				node.body.pivot.LocalRotation = rotation

				local center = Number3(uiBody.shape.Width, uiBody.shape.Height, uiBody.shape.Depth)
				uiBody.shape.Pivot = uiBody.shape:BlockToLocal(center)

				if node.didLoad then
					node:didLoad()
				end
			end

			_, requests = avatar:get(usernameOrId, nil, bodyDidLoad)

			node.onRemove = function()
				for _, r in ipairs(requests) do
					r:Cancel()
				end
			end

			node.refresh = function(_)
				_, requests = avatar:get(usernameOrId, nil, bodyDidLoad)
			end

			node._w = defaultSize
			node._h = defaultSize
			node._width = function(self)
				return self._w
			end
			node._height = function(self)
				return self._h
			end

			local setWidth = node._setWidth
			local setHeight = node._setHeight

			node._setWidth = function(self, v)
				self._w = v
				self._h = v -- spherized
				if self.body then
					self.body.Width = v
				end
				setWidth(self, v) -- spherized
				setHeight(self, v) -- spherized
			end

			node._setHeight = function(self, v)
				self._w = v
				self._h = v -- spherized
				if self.body then
					self.body.Height = v
				end
				setWidth(self, v) -- spherized
				setHeight(self, v) -- spherized
			end

			return node, requests
		end,
	},
}
setmetatable(uiavatar, uiavatarMetatable)

return uiavatar
