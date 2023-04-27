--[[
Friends module handles friend relations.
//!\\ Still a work in progress. Your scripts may break in the future if you use it now. 
]]--

local friendsWindow = {
	eList = {
		friends = 0,
		sent = 1,
		received = 2,
		search = 3,
	},

	-- Constants
	kNotifFriendsUpdated = "friends_friends_updated",
	kNotifSentUpdated = "friends_sent_updated",
	kNotifReceivedUpdated = "friends_received_updated",
}

friendsWindow.create = function(self, maxWidth, maxHeight, position)

	local uikit = require("uikit")
	local theme = require("uitheme").current
	local modal = require("modal")

	local idealReducedContentSize = function(content, width, height)
		width = math.min(width, 500)
		height = math.min(height, 500)

		local cellHeight, maxLines = content.getCellHeightAndMaxLines(height)
		return Number2(width, (cellHeight + theme.padding) * maxLines - theme.padding)
	end

	local content = modal:createContent()

	local node = uikit:createFrame(Color(0,0,0,0))

	node.getDisplayedList = function(self)
		if self.displayedList == friendsWindow.eList.friends then
			return self.data.friends
		elseif self.displayedList == friendsWindow.eList.sent then
			return  self.data.sent
		elseif self.displayedList == friendsWindow.eList.received then
			return self.data.received
		elseif self.displayedList == friendsWindow.eList.search then
			return self.data.search
		end
	end

	local pages = require("pages"):create()
	pages:setPageDidChange(function(page) 
		node:refreshList((page - 1) * node.displayedCells + 1)
	end)

	node.pages = pages
	content.bottomLeft = {node.pages}

	content.node = node
	content.idealReducedContentSize = idealReducedContentSize

	node.displayedCells = 0
	node.displayedList = friendsWindow.eList.friends

	-- Data
	node.data = {}
	
	node.data.friends = {} -- friends collection
	node.data.friendsRequestFlying = false
	node.data.updateFriends = function(self, callback) -- callback(bool success)
		-- Prevent multiple "search friends" requests 
		if self.friendsRequestFlying == true then return end
		self.friendsRequestFlying = true-------9
		-- request friends
		api:getFriends(function(ok, frRelations, errMsg)
			if not ok then -- API request failed
				if callback ~= nil then callback(false) end
				self.friendsRequestFlying = false
				return
			end
			self.friends = {}
			if #frRelations == 0 then
				if callback ~= nil then callback(true) end
				messenger:send(friendsWindow.kNotifFriendsUpdated, self.friends)
				self.friendsRequestFlying = false
			else
				for i, usrID in ipairs(frRelations) do
					api:getUserInfo(usrID, function(ok, usr)
						table.insert(self.friends, usr)
						if #self.friends == #frRelations then
							if callback ~= nil then callback(true) end
							messenger:send(friendsWindow.kNotifFriendsUpdated, self.friends)
							self.friendsRequestFlying = false
						end
					end)
				end
			end
		end)
	end

	node.data.sent = {} -- sent collection
	node.data.sentRequestFlying = false
	node.data.refreshSentFriendRequests = function(self, callback) -- callback(bool success)
		-- Prevent multiple "sent requests" requests 
		if self.sentRequestFlying == true then return end
		self.sentRequestFlying = true
		-- request sent friend requests
		api:getSentFriendRequests(function(ok, sentReqs, errMsg)
			if not ok then -- API request failed
				if callback ~= nil then callback(false) end
				self.sentRequestFlying = false
				return
			end
			self.sent = {}
			if #sentReqs == 0 then
				if callback ~= nil then callback(true) end
				messenger:send(friendsWindow.kNotifSentUpdated)
				self.sentRequestFlying = false
			else
				for i, usrID in ipairs(sentReqs) do
					api:getUserInfo(usrID, function(ok, usr)
						table.insert(self.sent, usr)
						if #self.sent == #sentReqs then
							if callback ~= nil then callback(true) end
							messenger:send(friendsWindow.kNotifSentUpdated)
							self.sentRequestFlying = false
						end
					end)
				end
			end
		end)
	end

	node.data.received = {} -- received collection
	node.data.receivedRequestFlying = false
	node.data.refreshReceivedFriendRequests = function(self, callback) -- callback(bool success)
		-- Prevent multiple "sent requests" requests 
		if self.receivedRequestFlying == true then return end
		self.receivedRequestFlying = true
		-- request received friend requests
		api:getReceivedFriendRequests(function(ok, receivedReqs, errMsg)
			if not ok then -- API request failed
				if callback ~= nil then callback(false) end
				self.receivedRequestFlying = false
				return
			end
			self.received = {}
			if #receivedReqs == 0 then
				if callback ~= nil then callback(true) end
				messenger:send(friendsWindow.kNotifReceivedUpdated)
				self.receivedRequestFlying = false
			else
				for i, usrID in ipairs(receivedReqs) do
					api:getUserInfo(usrID, function(ok, usr)
						table.insert(self.received, usr)
						if #self.received == #receivedReqs then
							if callback ~= nil then callback(true) end
							messenger:send(friendsWindow.kNotifReceivedUpdated)
							self.receivedRequestFlying = false
						end
					end)
				end
			end
		end)
	end

	node.data.search = {} -- search request
	node.data.searchRequestFlying = false
	node.data.searchFriends = function(self, searchText, callback)
		-- Prevent multiple "search friends" requests 
		if self.searchRequestFlying == true then return end
		self.searchRequestFlying = true
		-- request friends
		api:searchUser(searchText, function(ok, users, errMsg)
			if not ok then -- API request failed
				if callback ~= nil then callback(false) end
				self.searchRequestFlying = false
				return
			end
			self.search = users
			if callback ~= nil then callback(true) end
			self.searchRequestFlying = false
		end)
	end

	-- Lines
	node.lines = {}
	node.flushLines = function(self)
		for i, v in ipairs(node.lines) do
			v:remove()
		end
		node.lines = {}
	end

	node.textInput = ui:createTextInput("", "🔎 search...")
	node.textInput.Width = 200
	node.textInput:setParent(node)
	node.textInput:hide()
	node.searchTimer = nil

	node.textInput.onTextChange = function(self)
		if node.searchTimer ~= nil then
			node.searchTimer:Cancel()
		end

		node.searchTimer = Timer(0.3, function()
			local text = node.textInput.Text

			if text == "" then
				node.data.search = {}
				node:refreshList()
			else
				node.data:searchFriends(text, function(ok)
					if not ok then return end
					node:refreshList()
				end)
			end
			node.searchTimer = nil
		end)
	end

	-- Refresh list UI

	node.getCellHeightAndMaxLines = function(height)
		local t = ui:createText("A")
		local b = ui:createButton("💬")
		local cellHeight = math.max(t.Height, b.Height) + theme.padding * 3
		b:remove()
		t:remove()

		local h = cellHeight + theme.padding
		local maxLines = math.floor(height / h)

		if (maxLines + 1) * (cellHeight + theme.padding) - theme.padding <= height then
			maxLines = maxLines + 1
		end

		return cellHeight, maxLines
	end

	node.flushContentGetCellHeightAndMaxLines = function(self)
		self:flushLines()
		local top = self.Height
		if self.textInput:isVisible() then
			top = self.textInput.pos.Y - theme.padding
		end
		return self.getCellHeightAndMaxLines(top)
	end

	-- returns cell + buttons
	node.createCellWithUsernameAndButtons = function(self, cellHeight, uname, ...)

		local cell = ui:createFrame(Color(255,255,255,200))
		cell.Height = cellHeight
		cell:setParent(self)
		table.insert(self.lines, cell)
		cell.Width = self.Width

		local vPos = cell.Height * 0.5

		local name = ""
		if uname then name = "🙂 " .. uname else name = "⚠️ <guest>" end

		local username = ui:createText(name, Color(20,20,20))
		username:setParent(cell)
		username.pos.X = theme.padding * 2
		username.pos.Y = vPos - username.Height * 0.5

		local ret = {cell}

		local args = {...}

		local previous
		for _, btnLabel in ipairs(args) do
			local btn = ui:createButton(btnLabel)
			btn:setParent(cell)
			btn.pos.Y = vPos - btn.Height * 0.5
			if previous == nil then
				btn.pos.X = cell.Width - btn.Width - theme.padding * 2
			else
				btn.pos.X = previous.pos.X - btn.Width - theme.padding
			end
			previous = btn
			table.insert(ret, btn)
		end

		return table.unpack(ret)
	end

	node.refreshList = function(self, from)
		local list = self:getDisplayedList()
		if list == nil then return end

		local top = self.Height
		if self.textInput:isVisible() then
			self.textInput.pos.Y = self.Height - self.textInput.Height
			self.textInput.Width = self.Width
			top = self.textInput.pos.Y - theme.padding
		end

		local cellHeight, maxLines = self:flushContentGetCellHeightAndMaxLines()
		if maxLines <= 0 then return end

		self.displayedCells = maxLines -- update number of displayed cells

		local total = #list
		local from = from or 1

		if maxLines > 1 and (from % maxLines ~= 1 or from > total) then
			-- go back to first page
			from = 1
		end

		local page = math.floor(from / maxLines) + 1
		local totalPages = math.floor(total / maxLines) + 1
		if node.pages ~= nil then
			node.pages:setNbPages(totalPages)
			node.pages:setPage(page)
		end

		self.cells = {}

		local usr, cell, removeBtn, joinBtn, chatBtn, btnAccept, btnAdd
		local line = 0
		for i=from,total do
			line = line + 1
			if line > maxLines then break end
			local p = i - from
			usr = list[i]
			self.cells[i] = {}

			if list == self.data.friends then
				self.cells[i].cell, self.cells[i].removeBtn, self.cells[i].joinBtn, self.cells[i].chatBtn = self:createCellWithUsernameAndButtons(cellHeight, usr.username, "❌", "🌎", "💬")
			elseif list == self.data.sent then
				self.cells[i].cell, self.cells[i].removeBtn = self:createCellWithUsernameAndButtons(cellHeight, usr.username, "❌")

				self.cells[i].removeBtn.userID = usr.id
				self.cells[i].removeBtn.onRelease = function(btn)
					-- 1st arg is recipient
					api:cancelFriendRequest(btn.userID, function(ok, errMsg)
						if ok == false then return end
						-- trigger click on "Sent" tab
						node.sentBtn:onRelease()
					end)
				end
			elseif list == self.data.received then
				self.cells[i].cell, self.cells[i].removeBtn, self.cells[i].btnAccept = self:createCellWithUsernameAndButtons(cellHeight, usr.username, "❌", "✅")

				self.cells[i].removeBtn.userID = usr.id
				self.cells[i].btnAccept.userID = usr.id

				self.cells[i].btnAccept.onRelease = function(btn)
					api:replyToFriendRequest(btn.userID, true, function(ok, errMsg)
						if not ok then return end
						node.data:refreshReceivedFriendRequests(function(ok)
							if not ok then return  end
							-- node.data.received has been updated
							node:refreshList()
						end)
					end)
				end

				self.cells[i].removeBtn.onRelease = function(btn)
					api:replyToFriendRequest(btn.userID, false, function(ok, errMsg)
						if not ok then return end
						node.data:refreshReceivedFriendRequests(function(ok)
							if not ok then return end
							-- node.data.received has been updated
							node:refreshList()
						end)
					end)
				end
			elseif list == self.data.search then
				self.cells[i].cell, self.cells[i].btnAdd = self:createCellWithUsernameAndButtons(cellHeight, usr.username, "➕")

				self.cells[i].btnAdd.userID = usr.id
				self.cells[i].btnAdd.sending = false
				self.cells[i].btnAdd.onRelease = function(btn)
					if btn.sending then return end
					btn.sending = true
					api:sendFriendRequest(btn.userID, function(ok)
						if not ok then 
							btn.sending = false
							return 
						end
						btn.Text = "✅"
					end)
				end
			else 
				break
			end
		
			self.cells[i].cell.pos.Y = top - (p + 1) * self.cells[i].cell.Height - p * theme.padding
		end
	end

	node.parentDidResize = function(self)
		node:refreshList()
	end

	-- buttons
	node.friendsBtn = uikit:createButton("Friends")
	node.friendsBtn.onRelease = function(self)
		
		node.friendsBtn:select()
		node.sentBtn:unselect()
		node.receivedBtn:unselect()
		node.textInput:hide()
		
		-- "add friend" button
		local addFriendBtn = ui:createButton("🔎 Add friend ")
		addFriendBtn:setColor(theme.colorPositive)
		content.bottomRight = {addFriendBtn}
		addFriendBtn.onRelease = function(self)
			node.textInput:show()
			node.textInput:focus()

			node.displayedList = friendsWindow.eList.search
			node:refreshList()
		end

		node.displayedList = friendsWindow.eList.friends
		node:refreshList()

		node.data:updateFriends(function(ok)
			if not ok then return end
			-- node.data.friends has been updated !
			if node.displayedList == friendsWindow.eList.friends then
				node:refreshList()
			end
		end)
	end

	node.sentBtn = uikit:createButton("Sent")
	node.sentBtn.onRelease = function(self)

		node.friendsBtn:unselect()
		node.sentBtn:select()
		node.receivedBtn:unselect()
		node.textInput:hide()

		content.bottomRight = {}

		node.displayedList = friendsWindow.eList.sent
		node:refreshList()

		node.data:refreshSentFriendRequests(function(ok)
			if not ok then return end
			-- node.data.sent has been updated !
			if node.displayedList == friendsWindow.eList.sent then
				node:refreshList()
			end
		end)
	end
	
	messenger:addRecipient(node.sentBtn, friendsWindow.kNotifSentUpdated, function(recipient, name, data)
		local count = #node.data.sent
		recipient.Text = "Sent"
		if count > 0 then
			recipient.Text = recipient.Text .. "(" .. count .. ")"
		end
	end)

	node.receivedBtn = uikit:createButton("Received")
	node.receivedBtn.onRelease = function(self)

		node.friendsBtn:unselect()
		node.sentBtn:unselect()
		node.receivedBtn:select()
		node.textInput:hide()

		content.bottomRight = {}

		node.displayedList = friendsWindow.eList.received
		node:refreshList()

		node.data:refreshReceivedFriendRequests(function(ok)
			if not ok then return end
			-- node.data.received has been updated
			if node.displayedList == friendsWindow.eList.received then
				node:refreshList()
			end
		end)
	end

	content.topLeft = {node.friendsBtn, node.sentBtn, node.receivedBtn}

	messenger:addRecipient(node.receivedBtn, friendsWindow.kNotifReceivedUpdated, function(recipient, name, data)
		local count = #node.data.received
		recipient.Text = "Received"
		if count > 0 then
			recipient.Text = recipient.Text .. "(" .. count .. ")"
		end
	end)

	node.onClose = function(self)
		-- remove messenger recipients
		messenger:removeRecipient(node.sentBtn)
		messenger:removeRecipient(node.receivedBtn)
	end

	-- trigger click on "Friends" tab
	node.friendsBtn:onRelease()

	node.data:refreshSentFriendRequests(nil)
	node.data:refreshReceivedFriendRequests(nil)

	local _modal = modal:create(content, maxWidth, maxHeight, position)
	return _modal
end

return friendsWindow
