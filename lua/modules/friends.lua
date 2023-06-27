--[[
Friends module handles friend relations.
//!\\ Still a work in progress. Your scripts may break in the future if you use it now. 
]]--

local friendsWindow = {}

local mt = {
    __index = {},
    __newindex = function(t,k,v) error("friends module is read-only", 2) end,
    __metatable = false,
}
setmetatable(friendsWindow, mt)

local uikit = require("uikit")
local uiAvatar = require("ui_avatar")
local theme = require("uitheme").current
local modal = require("modal")

local lists = { friends = 0, sent = 1, received = 2, search = 3 }

mt.__index.create = function(self, maxWidth, maxHeight, position)

	local displayedList = lists.friends
	local displayedCells = 0
	local responses = {} -- list of friends, requests (sent or received), or search
	local requests = {}
	local countRequests = {}

	local cancelRequests = function()
		for _, r in ipairs(requests) do 
			r:Cancel()
		end
		requests = {}
	end

	local cancelCountRequests = function()
		for _, r in ipairs(countRequests) do r:Cancel() end
		countRequests = {}
	end

	local idealReducedContentSize = function(content, width, height)
		width = math.min(width, 500)
		height = math.min(height, 500)

		local cellHeight, maxLines = content.getCellHeightAndMaxLines(height)
		return Number2(width, (cellHeight + theme.padding) * maxLines - theme.padding)
	end

	local content = modal:createContent()

	local node = uikit:createFrame(Color(0,0,0,0))

	local pages = require("pages"):create()
	pages:setPageDidChange(function(page) 
		node:refreshList((page - 1) * node.displayedCells + 1)
	end)

	node.pages = pages
	content.bottomLeft = {node.pages}

	content.node = node
	content.idealReducedContentSize = idealReducedContentSize
	
	local updateFriends = function(callback) -- callback(bool success)
		cancelRequests() responses = {} node:flushLines()

		requests[#requests + 1] = api:getFriends(function(ok, friends, errMsg)
			if not ok then
				if callback ~= nil then callback(false) end return
			end
			if #friends == 0 then
				if callback ~= nil then callback(true) end
			else
				for i, usrID in ipairs(friends) do
					requests[#requests + 1] = api:getUserInfo(usrID, function(ok, usr)
						table.insert(responses, usr)
						if #responses == #friends then
							if callback ~= nil then callback(true) end
						end
					end)
				end
			end
		end)
	end

	local refreshSentFriendRequests = function(callback) -- callback(bool success)
		cancelRequests() responses = {} node:flushLines()

		requests[#requests + 1] = api:getSentFriendRequests(function(ok, sentReqs, errMsg)
			if not ok then
				if callback ~= nil then callback(false) end return
			end
			if #sentReqs == 0 then
				if callback ~= nil then callback(true) end
			else
				for i, usrID in ipairs(sentReqs) do
					requests[#requests + 1] = api:getUserInfo(usrID, function(ok, usr)
						table.insert(responses, usr)
						if #responses == #sentReqs then
							if callback ~= nil then callback(true) end
						end
					end)
				end
			end
		end)
	end

	local refreshReceivedFriendRequests = function(callback) -- callback(bool success)
		cancelRequests() responses = {} node:flushLines()

		requests[#requests + 1] = api:getReceivedFriendRequests(function(ok, receivedReqs, errMsg)
			if not ok then
				if callback ~= nil then callback(false) end return
			end
			if #receivedReqs == 0 then
				if callback ~= nil then callback(true) end
			else
				for i, usrID in ipairs(receivedReqs) do
					requests[#requests + 1] = api:getUserInfo(usrID, function(ok, usr)
						table.insert(responses, usr)
						if #responses == #receivedReqs then
							if callback ~= nil then callback(true) end
						end
					end)
				end
			end
		end)
	end

	local searchFriends = function(searchText, callback)
		cancelRequests()
		responses = {}
		node:flushLines()

		requests[#requests + 1] = api:searchUser(searchText, function(ok, users, errMsg)
			if not ok then
				if callback ~= nil then callback(false) end return
			end
			responses = users
			if callback ~= nil then callback(true) end
		end)
	end

	local refreshSentAndReceivedCounts = function()
		cancelCountRequests()

		countRequests[#countRequests + 1] = api:getSentFriendRequests(function(ok, sentReqs, errMsg)
			if not ok then return end
			local count = #sentReqs
			node.sentBtn.Text = "Sent" .. (count > 0 and " (" .. count .. ")" or "")
		end)

		countRequests[#countRequests + 1] = api:getReceivedFriendRequests(function(ok, receivedReqs, errMsg)
			if not ok then return end
			local count = #receivedReqs
			node.receivedBtn.Text = "Received" .. (count > 0 and " (" .. count .. ")" or "")
		end)
	end

	-- Lines
	node.lines = {}
	node.flushLines = function(self)
		for i, v in ipairs(node.lines) do v:remove() end
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
			cancelRequests()
			responses = {}
			node:flushLines()

			local text = node.textInput.Text

			if text == "" then
				node:refreshList()
			else
				searchFriends(text, function(ok)
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

		local head = nil
		local name = ""
		if uname then 
			name = uname 
			head = uiAvatar:getHead(uname, cellHeight - theme.padding * 2)
			head:setParent(cell)
		else
			name = "⚠️ <guest>" 
		end

		local username = ui:createText(name, Color(20,20,20))
		username:setParent(cell)

		if head then
			head.pos.X = theme.padding * 2
			head.pos.Y = vPos - head.Height * 0.5

			username.pos.X = head.pos.X + head.Width + theme.padding * 2
			username.pos.Y = vPos - username.Height * 0.5
		else
			username.pos.X = theme.padding * 2
			username.pos.Y = vPos - username.Height * 0.5
		end

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

		local top = self.Height
		if self.textInput:isVisible() then
			self.textInput.pos.Y = self.Height - self.textInput.Height
			self.textInput.Width = self.Width
			top = self.textInput.pos.Y - theme.padding
		end

		local cellHeight, maxLines = self:flushContentGetCellHeightAndMaxLines()
		if maxLines <= 0 then return end

		self.displayedCells = maxLines -- update number of displayed cells

		local total = #responses
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

		local usr, cell
		local line = 0
		for i=from,total do
			line = line + 1
			if line > maxLines then break end
			local p = i - from
			usr = responses[i]

			if displayedList == lists.friends then
				local joinBtn, chatBtn
				cell, joinBtn, chatBtn = self:createCellWithUsernameAndButtons(cellHeight, usr.username, "🌎", "💬")
				joinBtn:disable()
				chatBtn:disable()
			elseif displayedList == lists.sent then
				local removeBtn
				cell, removeBtn = self:createCellWithUsernameAndButtons(cellHeight, usr.username, "❌")
				removeBtn.userID = usr.id
				removeBtn.onRelease = function(self)
					requests[#requests + 1] = api:cancelFriendRequest(self.userID, function(ok, errMsg)
						if not ok then return end
						refreshSentAndReceivedCounts()
						node.sentBtn:onRelease()
					end)
				end
			elseif displayedList == lists.received then
				local removeBtn, btnAccept
				cell, removeBtn, btnAccept = self:createCellWithUsernameAndButtons(cellHeight, usr.username, "❌", "✅")

				removeBtn.userID = usr.id
				btnAccept.userID = usr.id

				btnAccept.onRelease = function(self)
					requests[#requests + 1] = api:replyToFriendRequest(self.userID, true, function(ok, errMsg)
						if not ok then return end
						refreshSentAndReceivedCounts()
						refreshReceivedFriendRequests(function(ok)
							if not ok then return  end
							node:refreshList()
						end)
					end)
				end

				removeBtn.onRelease = function(self)
					requests[#requests + 1] = api:replyToFriendRequest(self.userID, false, function(ok, errMsg)
						if not ok then return end
						refreshSentAndReceivedCounts()
						refreshReceivedFriendRequests(function(ok)
							if not ok then return end
							node:refreshList()
						end)
					end)
				end
			elseif displayedList == lists.search then
				local btnAdd
				cell, btnAdd = self:createCellWithUsernameAndButtons(cellHeight, usr.username, "➕")

				btnAdd.userID = usr.id
				btnAdd.sending = false
				btnAdd.onRelease = function(self)
					if btnAdd.sending then return end
					btnAdd.sending = true
					requests[#requests + 1] = api:sendFriendRequest(self.userID, function(ok)
						if not ok then 
							btnAdd.sending = false return 
						end
						refreshSentAndReceivedCounts()
						btnAdd.Text = "✅"
					end)
				end
			else 
				break
			end
		
			cell.pos.Y = top - (p + 1) * cell.Height - p * theme.padding
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


			displayedList = lists.search
			
			cancelRequests()
			responses = {}
			node:flushLines()
			node:refreshList()

		end

		displayedList = lists.friends

		updateFriends(function(ok)
			if not ok then return end
			if displayedList == lists.friends then
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

		displayedList = lists.sent

		refreshSentFriendRequests(function(ok)
			if not ok then return end
			if displayedList == lists.sent then
				node:refreshList()
			end
		end)
	end

	node.receivedBtn = uikit:createButton("Received")
	node.receivedBtn.onRelease = function(self)

		node.friendsBtn:unselect()
		node.sentBtn:unselect()
		node.receivedBtn:select()
		node.textInput:hide()

		content.bottomRight = {}

		displayedList = lists.received

		refreshReceivedFriendRequests(function(ok)
			if not ok then return end
			if displayedList == lists.received then
				node:refreshList()
			end
		end)
	end

	content.topLeft = {node.friendsBtn, node.sentBtn, node.receivedBtn}

	node.onClose = function(self)
		cancelCountRequests()
		cancelRequests()
	end

	node.friendsBtn:onRelease()
	refreshSentAndReceivedCounts()

	local _modal = modal:create(content, maxWidth, maxHeight, position)
	return _modal
end

return friendsWindow
