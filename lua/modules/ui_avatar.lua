--- This module allows you to create UI element from player avatars
---@code -- A few examples:
---  
--- -- Place the head of "playerUsername" randomly on the screen with a size of 100
--- local uiavatar = require("uiavatar")
--- local uiHead = uiavatar:getHead("playerUsername" or Player.UserID, 100) -- 100 is the sized
--- uiHead.pos = { 100 + math.random() * (Screen.Width - 400), 100 + math.random() * (Screen.Height - 400), 0 } -- place the head randomly on the screen
--- uiHead.Width = math.random(100,200) -- to set a random size to the head. Height and Width are the same here because the head is spherized

local uiavatar = {}

local DEFAULT_SIZE = 30

local ui = require("uikit")
local headCache = {}

local uiavatarMetatable = {
	__index = {
		clearCache = function(self)
			headCache = {}
		end,
		preloadHeads = function(self, playersTable)
			if type(playersTable) ~= "table" then playersTable = { playersTable } end
			for _,p in pairs(playersTable) do
				local username
				if type(p) == "string" then
					username = p
				elseif type(p) == "Player" then
					username = p.Username
				end
				require("avatar"):getPlayerHead(username, function(err, head)
					if err then return end
					headCache[username] = head
				end)
			end
		end,
		getHead = function(self, usernameOrId, size)
			
			local defaultSize = size or DEFAULT_SIZE
			
			local cachedHead = headCache[usernameOrId]
			local node = ui:createFrame(Color(0,0,0,0))

			if cachedHead then
				local uiHead = ui:createShape(Shape(cachedHead, {includeChildren = true}), { spherized = true })
				uiHead:setParent(node)
				node.head = uiHead
				node.head.Width = defaultSize
			else
				require("avatar"):getPlayerHead(usernameOrId, function(err, head)
					if err then print(err) return end
					headCache[usernameOrId] = head
					local uiHead = ui:createShape(Shape(head, {includeChildren = true}), { spherized = true })
					uiHead:setParent(node)
					node.head = uiHead
					node.head.Width = node.Width
				end)
			end

			node._w = defaultSize
			node._h = defaultSize
			node._width = function(self) return self._w end
			node._height = function(self) return self._h end
			node._setWidth = function(self, v)
				self._w = v self._h = v -- spherized
				if self.head then self.head.Width = v end
			end
			node._setHeight = function(self, v)
				self._w = v self._h = v -- spherized
				if self.head then self.head.Height = v end
			end

			return node
		end,
	}
}
setmetatable(uiavatar, uiavatarMetatable)

return uiavatar