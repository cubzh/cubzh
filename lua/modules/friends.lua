--[[
Friends module handles friend relations.
//!\\ Still a work in progress. Your scripts may break in the future if you use it now.	]]
--

local friendsWindow = {}

local mt = {
	__index = {},
	__newindex = function()
		error("friends module is read-only", 2)
	end,
	__metatable = false,
}
setmetatable(friendsWindow, mt)

local uiAvatar = require("ui_avatar")
local theme = require("uitheme").current
local padding = theme.padding
local modal = require("modal")
local api = require("system_api", System)

-- uikit: optional, allows to provide specific instance of uikit
mt.__index.create = function(_, maxWidth, maxHeight, position, uikit)
	local ui = uikit or require("uikit")
	local scroll

	-- list of friends, requests (sent or received) or search
	local lists = {
		received = {},
		sent = {},
		friends = {},
		search = {}
	}

	local requests = {}
	local cancelRequests = function()
		for _, r in ipairs(requests) do
			r:Cancel()
		end
		requests = {}
	end

	local idealReducedContentSize = function(content, width, height)
		width = math.max(width, 500)
		height = math.max(height - 100, 500)

		return Number2(width, height)
	end

	local node = ui:createFrame(Color(0, 0, 0, 0))

	node.onRemove = function()
		cancelRequests()
		node.screenDidResizeListener:Remove()
		node.screenDidResizeListener = nil
	end

	local retrieveFriendsLists = function(searchText)
		lists = {}

		local function newListResponse(name, list)
			lists[name] = list or {}
			if lists.friends and lists.received and lists.sent and lists.search then
				node:resetList()
			end
		end

		local function requestList(methodName, listName, searchText)
			local list = {}
			local nbIterations = 0
			if listName == "search" then
				if searchText == nil or searchText == "" then
					newListResponse("search", list)
					return
				end
				local req = api:searchUser(searchText, function(ok, users, _)
					print(searchText, "res", #users)
					for _, usr in ipairs(users) do
						if usr and usr.username ~= "" then
							table.insert(list, usr)
						end
						nbIterations = nbIterations + 1
						if nbIterations == #users then
							table.sort(list, function(a, b)
								return a.username < b.username
							end)
							newListResponse(listName, list)
						end
						table.insert(requests, req2)
					end
				end)
				table.insert(requests, req)
				return
			end 

			-- TODO: backend must handle search field in when retrieving friends, pending and sent
			local req = api[methodName](api, function(ok, users, _)
				for _, usrID in ipairs(users) do
					local req2 = api:getUserInfo(usrID, function(_, usr)
						if usr.username ~= "" then
							table.insert(list, usr)
						end
						nbIterations = nbIterations + 1
						if nbIterations == #users then
							table.sort(list, function(a, b)
								return a.username < b.username
							end)
							newListResponse(listName, list)
						end
					end)
					table.insert(requests, req2)
				end
			end)
			table.insert(requests, req)
		end

		requestList("getFriends", "friends", searchText)
		requestList("getReceivedFriendRequests", "received", searchText)
		requestList("getSentFriendRequests", "sent", searchText)
		requestList("searchUser", "search", searchText)
	end

	local getSearchBar = function()
		local textInput = ui:createTextInput("", "🔎 search...")
		textInput.Width = 200
		node.searchTimer = nil

		textInput.onTextChange = function(_)
			if node.searchTimer then
				node.searchTimer:Cancel()
			end

			node.searchTimer = Timer(0.2, function()
				cancelRequests()
				node.searchTimer = nil
				retrieveFriendsLists(textInput.Text)
			end)
		end
		return textInput
	end

	local searchBar = getSearchBar()
	searchBar:setParent(node)

	node.parentDidResize = function(_)
		searchBar.Width = node.Width
		searchBar.pos = { 0, node.Height - searchBar.Height }

		if node.scroll then
			node.scroll.Width = node.Width
			node.scroll.Height = node.Height - searchBar.Height
			node.scroll.pos = { 0, 0 }
		end
	end

	local computeCellSize = function()
		local btnJoin = ui:createButton("Join 🌎")
		local btnMessage = ui:createButton("💬 Send")
		local size = btnJoin.Width + btnMessage.Width + padding * 4
		return size, size
	end

	local cellWidth, cellHeight = computeCellSize()
	node.screenDidResizeListener = LocalEvent:Listen(LocalEvent.Name.ScreenDidResize, function()
		cellWidth, cellHeight = computeCellSize()
	end, { topPriority = true } )

	local createFriendCell = function(config)
		local forceWidth = config.width
		local forceHeight = config.height

		local cell = ui:createFrame()
		local textBg = ui:createFrame(Color(0,0,0,0.5))
		textBg:setParent(cell)
		local textName = ui:createText("", Color.White)
		textName:setParent(textBg)
		local textStatus = ui:createText("", Color.White)
		textStatus:setParent(textBg)

		local btnLeft = ui:createButton("💬 Send")
		btnLeft:setParent(textBg)
		btnLeft.onRelease = function(_)
			require("menu"):ShowAlert({ message = "Coming soon!" }, System)
		end
		local btnRight = ui:createButton("Join 🌎")
		btnRight:setParent(textBg)
		btnRight.onRelease = function(_)
			require("menu"):ShowAlert({ message = "Coming soon!" }, System)
		end
		cell:hide()

		local avatar
		cell.setUsername = function(_, username)
			if not username then return end
			avatar = uiAvatar:get(username, cell.Height - textBg.Height)
			avatar:setParent(cell)
			textName.Text = username
			textStatus.Text = math.random(3) > 1 and "Online" or "Offline"
			cell:parentDidResize()
			cell:show()
		end

		cell.parentDidResize = function()
			cell.Height = forceHeight or cellHeight
			cell.Width = forceWidth or cell.Height

			textBg.Width = cell.Width
			textBg.Height = textName.Height + padding * 2 + btnLeft.Height
			textBg.pos = { 0, 0 }

			if avatar then
				avatar.pos = { cell.Width * 0.5 - avatar.Width * 0.5, textBg.Height }
			end

			textName.pos = { padding, btnLeft.Height + padding }
			textStatus.pos = { cell.Width - textStatus.Width - padding, btnLeft.Height + padding }

			btnRight.pos = { cell.Width - btnRight.Width, 0 }
		end

		cell.setType = function(_, type)
			if type == "received" then
				btnLeft.Text = "Accept"
				btnLeft:setColor(theme.colorPositive)
				btnRight.Text = "Refuse"
				btnRight:setColor(theme.colorNegative)
			elseif type == "sent" then
				btnLeft.Text = "Sent"
				btnLeft:setColorDisabled(Color(0,0,0,0), Color.White)
				btnLeft:disable()
				btnRight.Text = "Cancel"
				btnRight:setColor(theme.colorNegative)
			end
			cell:parentDidResize()
		end

		cell:setType("friends")

		return cell
	end

	local getUsersInLine = function(index, nbCellsPerLine)
		local list

		if #lists.search == 0 then
			list = lists.received
			if list then
				-- compute nb lines (add empty spaces)
				local nbLines = math.ceil(#list / nbCellsPerLine)
				local totalCells = nbLines * nbCellsPerLine
				if index <= totalCells then
					return list[index], "received"
				end
				index = index - totalCells
			end

			list = lists.sent
			if list then
				-- compute nb lines (add empty spaces)
				local nbLines = math.ceil(#list / nbCellsPerLine)
				local totalCells = nbLines * nbCellsPerLine
				if index <= totalCells then
					return list[index], "sent"
				end
				index = index - totalCells
			end

			list = lists.friends
			if list then
				-- compute nb lines (add empty spaces)
				local nbLines = math.ceil(#list / nbCellsPerLine)
				local totalCells = nbLines * nbCellsPerLine
				if index <= totalCells then
					return list[index], "friends"
				end
			end
		else
			list = lists.search
			if list then
				-- compute nb lines (add empty spaces)
				local nbLines = math.ceil(#list / nbCellsPerLine)
				local totalCells = nbLines * nbCellsPerLine
				if index <= totalCells then
					return list[index], "search"
				end
			end
		end
	end

	local loadLine = function(cellId)
		local width = node.Width
		local nbCells = math.floor(width / cellWidth)

		local firstCellUser = getUsersInLine((cellId - 1) * nbCells + 1, nbCells)
		if not firstCellUser then return end

		local line = require("ui_container"):createHorizontalContainer()
		line.Width = width
		line.Height = cellHeight

		local realCellWidth = (width - 2 * padding - (nbCells - 1) * padding) / nbCells
		for i=1,nbCells do
			local cell = createFriendCell({ width = realCellWidth, height = cellHeight})
			line:pushElement(cell)
			if i < nbCells then line:pushGap() end

			local user, type = getUsersInLine((cellId - 1) * nbCells + i, nbCells)
			if user then
				cell:setUsername(user.username)
				cell:setType(type)
			end
		end

		return line
	end

	local unloadLine = function(cell)
		cell:remove()
	end

	local config = {
		cellPadding = 5,
		loadCell = loadLine,
		unloadCell = unloadLine,
	}

	scroll = ui:createScrollArea(Color(0,0,0,0.8), config)
	scroll:setParent(node)
	node.scroll = scroll

	node.resetList = function()
		scroll:flush()
		scroll:setScrollPosition(0)
	end

	retrieveFriendsLists()

	local content = modal:createContent()
	content.node = node
	content.idealReducedContentSize = idealReducedContentSize

	local _modal = require("modal"):create(content, maxWidth, maxHeight, position, require("uikit"))
	return _modal
end

return friendsWindow
