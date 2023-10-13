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

-- local SKIN_1_PALETTE_INDEX = 1
-- local SKIN_2_PALETTE_INDEX = 2
local EYES_PALETTE_INDEX = 6
local EYES_DARK_PALETTE_INDEX = 8
local NOSE_PALETTE_INDEX = 7
local MOUTH_PALETTE_INDEX = 4

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

			local cachedHead = headCache[usernameOrId]

			if config.ignoreCache == true then
				cachedHead = nil
			end

			local node = ui:createFrame(Color(0, 0, 0, 0))

			if cachedHead then
				local uiHead = ui:createShape(Shape(cachedHead, { includeChildren = true }), { spherized = true })
				uiHead:setParent(node)
				node.head = uiHead
				node.head.Width = defaultSize
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
			avatar:setSkinColor(node, color1, color2, nose, mouth)

			self:setNoseColor(node, nose, true)
			self:setMouthColor(node, mouth, true)

			-- apply colors to in-game avatar
			avatar:setSkinColor(Player, color1, color2, nose, mouth)
		end,

		setEyesColor = function(_, node, color)
			local palette = node.Head.Palette
			palette[EYES_PALETTE_INDEX].Color = color
			palette[EYES_DARK_PALETTE_INDEX].Color = color
			palette[EYES_DARK_PALETTE_INDEX].Color:ApplyBrightnessDiff(-0.15)

			avatar:setEyesColor(node, color)
		end,

		setNoseColor = function(_, node, color, ignorePlayer)
			local palette = node.Head.Palette
			palette[NOSE_PALETTE_INDEX].Color = color

			if not ignorePlayer then
				avatar:setNoseColor(Player, color)
			end
		end,

		setMouthColor = function(_, node, color, ignorePlayer)
			local palette = node.Head.Palette
			palette[MOUTH_PALETTE_INDEX].Color = color

			if not ignorePlayer then
				avatar:setMouthColor(Player, color)
			end
		end,

		-- returns uikit node + sent requests (table, can be nil)
		-- /!\ return table of requests does not contain all requests right away
		-- reference should be kept, not copying entries right after function call.
		-- uikit: optional, allows to provide specific instance of uikit
		get = function(_, usernameOrId, size, config, uikit)
			local body
			local requests

			local ui = uikit or ui

			local defaultSize = size or DEFAULT_SIZE
			local localPlayer = false
			if config and config.localPlayer then
				localPlayer = true
			end

			local node = ui:createFrame(Color(0, 0, 0, 0))

			if localPlayer then
				local uiBody = ui:createShape(Shape(Player.Avatar, { includeChildren = true }), { spherized = true })
				uiBody:setParent(node)
				uiBody.Head.LocalRotation = { 0, 0, 0 }
				node.body = uiBody
				node.body.Width = node._w

				local center = Number3(uiBody.shape.Width, uiBody.shape.Height, uiBody.shape.Depth)
				uiBody.shape.Pivot = uiBody.shape:BlockToLocal(center)

				node.refresh = function(self)
					local previousParent = self.body.parent
					local previousPosition = self.body.pos
					local previousRotation = self.body.shape.LocalRotation:Copy()
					local previousWidth = self.body.Width
					self.body:setParent(nil)

					-- [gaetan] maybe we could avoid a full copy all over again here
					self.body = ui:createShape(Shape(Player.Avatar, { includeChildren = true }), { spherized = true })
					self.body:setParent(previousParent)
					self.body.Head.LocalRotation = { 0, 0, 0 }
					self.body.pos = previousPosition
					self.body.shape.LocalRotation = previousRotation
					self.body.Width = previousWidth

					local center = Number3(self.body.shape.Width, self.body.shape.Height, self.body.shape.Depth)
					self.body.shape.Pivot = self.body.shape:BlockToLocal(center)
				end
			else
				body, requests = avatar:get(usernameOrId)
				body.didLoad = function(err, avatarBody)
					if err == true then
						error(err, 2)
						return
					end
					local uiBody = ui:createShape(Shape(avatarBody, { includeChildren = true }), { spherized = true })
					uiBody:setParent(node)
					uiBody.Head.LocalRotation = { 0, 0, 0 }
					node.body = uiBody
					node.body.Width = node._w

					local center = Number3(uiBody.shape.Width, uiBody.shape.Height, uiBody.shape.Depth)
					uiBody.shape.Pivot = uiBody.shape:BlockToLocal(center)
				end

				node.onRemove = function()
					for _, r in ipairs(requests) do
						r:Cancel()
					end
				end
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
