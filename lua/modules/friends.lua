--[[
Friends module handles friend relations.
//!\\ Still a work in progress. Your scripts may break in the future if you use it now.	]]
--

--TODO
-- [ ] Input bloqué quand je focus
-- [ ] remove sent in list
-- [ ] add numbers of cell next to title
-- [ ] search add Friends - Sent - Received - Search

-- [ ] Animations idle
-- [ ] Scroll un peu plus smooth
-- [ ] add platform under player

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
		if not Client.IsMobile then
			width = 500
		end
		return Number2(width, height)
	end

	local node = ui:createFrame(Color(0, 0, 0, 0))

	node.onRemove = function()
		cancelRequests()
		node.screenDidResizeListener:Remove()
		node.screenDidResizeListener = nil
	end

	local retrieveFriendsLists = function(searchText, keepScrollPosition)
		lists = {}
		keepScrollPosition = keepScrollPosition or false

		local function newListResponse(name, list)
			lists[name] = list or {}
			if lists.friends and lists.received and lists.sent and lists.search then
				node:resetList(keepScrollPosition)
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
				retrieveFriendsLists(textInput.Text, false)
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
		end
	end

	local computeCellSize = function()
		local btnJoin = ui:createButton("🌎 Join", { textSize = "small" })
		local btnMessage = ui:createButton("💬", { textSize = "small" })
		local size = btnJoin.Width + btnMessage.Width + padding * 4
		btnJoin:remove()
		btnMessage:remove()
		return math.floor(size), math.floor(size) -- width, height
	end

	local cellWidth, cellHeight = computeCellSize()
	node.screenDidResizeListener = LocalEvent:Listen(LocalEvent.Name.ScreenDidResize, function()
		cellWidth, cellHeight = computeCellSize()
		node:resetList()
	end, { topPriority = true } )

	local createFriendCell = function(config)
		local forceWidth = config.width
		local forceHeight = config.height

		local cell = ui:createFrame(Color(40,40,40))
		local textBg = ui:createFrame(Color(0,0,0,0.2))
		textBg:setParent(cell)
		local textName = ui:createText("", Color.White)
		textName:setParent(textBg)
		local textStatus = ui:createText("", Color.White)
		textStatus:setParent(textBg)

		local btnLeft = ui:createButton("💬", {
			borders = false,
			shadow = false,
			textSize = "small"
		})
		btnLeft:setParent(textBg)
		btnLeft:setColor(Color(0,0,0,0))
		local btnRight = ui:createButton("🌎 Join", {
			borders = false,
			shadow = false,
			textSize = "small"
		})
		btnRight:setParent(textBg)
		btnRight:setColor(Color(0,0,0,0))
		cell:hide()

		local avatar
		cell.setUser = function(_, user)
			if not user or not user.username then return end
			cell.username = user.username
			cell.userID = user.id
			avatar = uiAvatar:get(user.username, cell.Height - textBg.Height, nil, ui)
			avatar:setParent(cell)
			avatar.didLoad = function()
				avatar.body.pivot.LocalRotation = Rotation(-math.pi / 8, 0, 0) * Rotation(0, math.rad(145), 0)
			end
			textName.Text = user.username
			textStatus.Text = ""--math.random(3) > 1 and "Online" or "Offline"
			cell:parentDidResize()
			cell:show()
		end

		cell.parentDidResize = function()
			cell.Height = math.floor(forceHeight or cellHeight)
			cell.Width = math.floor(forceWidth or cell.Height)

			textBg.Width = math.floor(cell.Width)
			textBg.Height = math.floor(textName.Height + padding * 2 + btnLeft.Height)

			if avatar then
				avatar.pos = { cell.Width * 0.5 - avatar.Width * 0.5, textBg.Height }
			end

			textName.pos = { padding, btnLeft.Height + padding }
			textStatus.pos = { cell.Width - textStatus.Width - padding, btnLeft.Height + padding }

			btnRight.pos = { cell.Width - btnRight.Width, 0 }
		end

		cell.setType = function(_, cellType)
			if cellType == "received" then
				btnLeft.Text = "➕ Accept"
				btnLeft.onRelease = function()
					local req = api:replyToFriendRequest(cell.userID, true, function(ok, _)
						if not ok then
							return
						end
						retrieveFriendsLists(nil, true)
					end)
					table.insert(requests, req)
				end
				btnRight.Text = "❌"
				btnRight.onRelease = function()
					local req = api:replyToFriendRequest(cell.userID, false, function(ok, _)
						if not ok then
							return
						end
						retrieveFriendsLists(nil, true)
					end)
					table.insert(requests, req)
				end
			elseif cellType == "sent" then
				btnLeft.Text = "Sent"
				btnLeft.onRelease = nil
				btnRight.Text = "❌"
				btnRight.onRelease = function()
					local req = api:cancelFriendRequest(cell.userID, function(ok, _)
						if not ok then
							return
						end
						retrieveFriendsLists(nil, true)
					end)
					table.insert(requests, req)
				end
			elseif cellType == "friends" then
				btnLeft.Text = "🌎 Join"
				btnLeft.onRelease = function()
					require("menu"):ShowAlert({ message = "Coming soon!" }, System)
				end
				btnRight.Text = "💬"
				btnRight.onRelease = function()
					require("menu"):ShowAlert({ message = "Coming soon!" }, System)
				end
			end
			cell:parentDidResize()
		end

		cell:setType("friends")

		return cell
	end

	local getUserAtIndex = function(index, nbCellsPerLine)
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
		local nbCells = math.min(2,math.floor(width / cellWidth))

		local firstCellUser, firstCellType = getUserAtIndex((cellId - 1) * nbCells + 1, nbCells)
		if not firstCellUser then return end

		local prevFirstCellUserType
		if cellId > 1 then
			_, prevFirstCellUserType = getUserAtIndex((cellId - 2) * nbCells + 1, nbCells)
		end

		local verticalContainer
		local line = require("ui_container"):createHorizontalContainer()
		line.Width = math.floor(width)
		line.Height = math.floor(cellHeight)

		-- Need to make a vertical container to add the title
		if prevFirstCellUserType == nil or firstCellType ~= prevFirstCellUserType then
			verticalContainer = require("ui_container"):createVerticalContainer()
			local titleStr = "Friends"
			if firstCellType == "received" then
				titleStr = "Pending requests"
			end
			if firstCellType == "sent" then
				titleStr = "Sent requests"
			end
			local title = ui:createText(titleStr, Color.White, "big")
			verticalContainer:pushElement(title)
			verticalContainer:pushElement(line)
		else
			line:pushGap()
		end

		local realCellWidth = math.floor((width - 2 * padding - (nbCells - 1) * padding) / nbCells)
		for i=1,nbCells do
			local cell = createFriendCell({ width = realCellWidth, height = cellHeight})
			line:pushElement(cell)
			if i < nbCells then line:pushGap() end

			local user, cellType = getUserAtIndex((cellId - 1) * nbCells + i, nbCells)
			if user then
				cell:setUser(user)
				cell:setType(cellType)
			end
		end

		return verticalContainer or line
	end

	local unloadLine = function(cell)
		cell:remove()
	end

	local config = {
		cellPadding = 5,
		loadCell = loadLine,
		unloadCell = unloadLine,
		uikit = uikit or require("uikit")
	}

	scroll = ui:createScrollArea(Color(20,20,20), config)
	scroll:setParent(node)
	node.scroll = scroll

	node.resetList = function(keepScrollPosition)
		local scrollPosition = keepScrollPosition and scroll.scrollPosition or 0
		scroll:flush()
		scroll:setScrollPosition(scrollPosition)
	end

	retrieveFriendsLists()

	local content = modal:createContent()
	content.node = node
	content.idealReducedContentSize = idealReducedContentSize

	local _modal = require("modal"):create(content, maxWidth, maxHeight, position, ui)
	return _modal
end

return friendsWindow
