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
	local content = modal:createContent()
	content.title = "Friends"
	content.icon = "😛"

	local scroll
	local searchText
	local nbResults = -1 -- -1 loading..., 0 no result

	-- list of friends, requests (sent or received) or search
	local lists = {
		received = {},
		sent = {},
		friends = {},
		search = {},
	}

	local requests = {}
	local cancelRequests = function()
		for _, r in ipairs(requests) do
			r:Cancel()
		end
		requests = {}
	end

	local idealReducedContentSize = function(_, width, height, minWidth)
		width = math.min(width, 500)
		width = math.max(minWidth, width)
		return Number2(width, height)
	end

	local node = ui:createFrame(Color(0, 0, 0, 0))

	node.onRemove = function()
		cancelRequests()
		node.screenDidResizeListener:Remove()
		node.screenDidResizeListener = nil
		if helpPointer then
			helpPointer:remove()
			helpPointer = nil
		end
	end

	local retrieveFriendsLists = function(_searchText, keepScrollPosition)
		searchText = _searchText
		nbResults = -1
		local nbLists = 4
		local nbListsRetrieved = 0
		lists = {
			received = {},
			sent = {},
			friends = {},
			search = {},
		}
		node:resetList()
		keepScrollPosition = keepScrollPosition or false

		local function newListResponse(name, list)
			lists[name] = list or {}
			nbListsRetrieved = nbListsRetrieved + 1
			if nbListsRetrieved < nbLists then
				return
			end
			if searchText and #searchText > 0 then
				-- filter out search list
				-- remove this part once backend handles that
				for k = #lists.search, 1, -1 do
					local user = lists.search[k]
					local idFound = false
					for _, v in ipairs(lists.friends) do
						if v.id == user.id then
							idFound = true
						end
					end
					for _, v in ipairs(lists.received) do
						if v.id == user.id then
							idFound = true
						end
					end
					for _, v in ipairs(lists.sent) do
						if v.id == user.id then
							idFound = true
						end
					end
					if idFound then
						table.remove(lists.search, k)
					end
				end
				nbResults = #lists.friends + #lists.received + #lists.sent + #lists.search
			else
				nbResults = #lists.friends + #lists.received
			end
			node:resetList(keepScrollPosition)
		end

		local function requestList(methodName, listName, searchText)
			local list = {}
			local nbIterations = 0
			if listName == "search" then
				if searchText == nil or searchText == "" then
					newListResponse("search", {})
					return
				end
				local req = api:searchUser(searchText, function(ok, users, _)
					if not ok then
						error("Can't find users", 2)
					end
					if #users == 0 then
						newListResponse("search", {})
					end
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
				if not ok then
					error("Can't find users", 2)
				end
				if #users == 0 then
					newListResponse(listName, {})
					return
				end
				for _, usrID in ipairs(users) do
					local req2 = api:getUserInfo(usrID, function(_, usr)
						if usr.username ~= "" then
							-- if search, match the username
							if not searchText or string.find(usr.username, searchText) then
								table.insert(list, usr)
							end
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
		local searchBarContainer = ui:createFrame()
		local textInput = ui:createTextInput("", "🔎 search...")
		textInput:setParent(searchBarContainer)
		local cancelSearch = ui:createButton("X")
		cancelSearch:setParent(searchBarContainer)
		cancelSearch.onRelease = function()
			textInput.Text = ""
			retrieveFriendsLists(textInput.Text, false)
		end

		searchBarContainer.parentDidResize = function()
			searchBarContainer.Width = searchBarContainer.parent.Width
			searchBarContainer.Height = textInput.Height
			cancelSearch.Height = textInput.Height
			cancelSearch.Width = cancelSearch.Height
			cancelSearch.pos = { searchBarContainer.Width - cancelSearch.Width, 0 }
			textInput.Width = searchBarContainer.Width - cancelSearch.Width
		end

		node.searchTimer = nil

		textInput.onTextChange = function(_)
			if node.searchTimer then
				node.searchTimer:Cancel()
			end

			node.searchTimer = Timer(0.3, function()
				cancelRequests()
				node.searchTimer = nil
				retrieveFriendsLists(textInput.Text, false)
			end)
		end
		return searchBarContainer
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
	end, { topPriority = true })

	local createFriendCell = function(config)
		local forceWidth = config.width
		local forceHeight = config.height

		local cell = ui:createFrame(Color(63, 63, 63))

		local textBg = ui:createFrame(Color(0, 0, 0, 0.5))
		textBg:setParent(cell)
		local textName = ui:createText("", Color.White, "small")
		textName:setParent(textBg)
		local textStatus = ui:createText("", Color.White, "small")
		textStatus:setParent(textBg)
		textBg:hide()

		local btnConfig = {
			borders = false,
			shadow = false,
			textSize = "small",
		}
		local btnLeft = ui:createButton("", btnConfig)
		btnLeft:setParent(textBg)
		local btnRight = ui:createButton("", btnConfig)
		btnRight:setParent(textBg)

		local avatar
		cell.parentDidResize = function()
			cell.Height = math.floor(forceHeight or cellHeight)
			cell.Width = math.floor(forceWidth or cell.Height)

			textBg.Width = math.floor(cell.Width)
			textBg.Height = math.floor(textName.Height + padding * 2 + btnLeft.Height)

			if avatar then
				avatar.pos = { cell.Width * 0.5 - avatar.Width * 0.5, cell.Height - avatar.Height }
			end

			if avatarLand and avatarLand.Width then
				avatarLand.pos = { cell.Width * 0.5 - avatarLand.Width * 0.5, 10 }
			end

			textName.pos = { padding, btnLeft.Height + padding }
			textStatus.pos = { cell.Width - textStatus.Width - padding, btnLeft.Height + padding }

			btnRight.pos = { cell.Width - btnRight.Width, 0 }
		end

		cell.setUser = function(_, user)
			if not user or not user.username then
				cell:hide()
				return
			end

			cell.waitScrollStopTimer = Timer(0.5, function()
				cell.waitScrollStopTimer = nil
				textBg:show()

				cell.onRelease = function()
					local profileContent = require("profile"):create({
						isLocal = false,
						username = user.username,
						userID = user.id,
						uikit = ui,
					})
					content:push(profileContent)
				end

				cell.IsMask = true
				cell.username = user.username
				cell.userID = user.id
				textBg.LocalPosition.Z = -600
				avatar = uiAvatar:get(user.username, cell.Height * 0.9, nil, ui)
				avatar:setParent(cell)
				avatar.didLoad = function()
					avatar.body.pivot.LocalRotation = Rotation(-math.pi / 8, 0, 0) * Rotation(0, math.rad(145), 0)
				end
				Object:Load("buche.lobby_grassland", function(obj)
					avatarLand = ui:createShape(obj)
					avatarLand:setParent(cell)
					obj.Rotation.Y = math.pi / 4
					obj:RotateWorld(Number3(1, 0, 0), math.pi / -6)
					obj.Scale = 3
					avatarLand.LocalPosition.Z = -50
					if cell.parentDidResize then
						cell:parentDidResize()
					end
				end)
				textName.Text = user.username
				-- TODO: handle status
				textStatus.Text = ""
				if cell.parentDidResize then
					cell:parentDidResize()
				end
				cell:show()
			end)
		end

		cell.setType = function(_, cellType)
			if cellType == "received" then
				btnLeft.Text = "✅ Accept"
				btnLeft:show()
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
				btnRight:show()
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
				btnLeft:show()
				btnLeft.onRelease = nil
				btnRight.Text = "❌"
				btnRight:show()
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
				btnLeft:show()
				btnLeft.onRelease = function()
					require("menu"):ShowAlert({ message = "Coming soon!" }, System)
				end
				btnRight.Text = "💬"
				btnRight:show()
				btnRight.onRelease = function()
					require("menu"):ShowAlert({ message = "Coming soon!" }, System)
				end
			elseif cellType == "search" then
				btnLeft.Text = "➕ Add friend"
				btnLeft:show()
				btnLeft.onRelease = function()
					local req = api:sendFriendRequest(cell.userID, function(ok, _)
						if not ok then
							return
						end
						retrieveFriendsLists(searchText, true)
					end)
					table.insert(requests, req)
				end
				btnRight.Text = ""
				btnRight:hide()
				btnRight.onRelease = nil
			end
			cell:parentDidResize()
		end

		return cell
	end

	local getUserAtIndex = function(index, nbCellsPerLine)
		-- default list
		local listOrder = { "received", "friends" }
		if #lists.search > 0 then
			-- search list
			listOrder = { "friends", "received", "sent", "search" }
		end

		for _, name in ipairs(listOrder) do
			local list = lists[name]
			if list then
				-- compute nb lines (add empty spaces)
				local nbLines = math.ceil(#list / nbCellsPerLine)
				local totalCells = nbLines * nbCellsPerLine
				if index <= totalCells then
					return list[index], name
				end
				index = index - totalCells
			end
		end
	end

	local loadLine = function(cellId)
		if nbResults == -1 then
			if cellId == 1 then
				local container = ui:createFrame()
				local text = ui:createText("Loading...", Color.White)
				text:setParent(container)
				container.Width = node.Width
				container.Height = math.floor(cellHeight)
				text.pos = { container.Width * 0.5 - text.Width * 0.5, container.Height * 0.5 - text.Height * 0.5 }
				return container
			end
			return
		end
		if nbResults == 0 then
			if cellId == 1 then
				local container = ui:createFrame()
				local isSearch = searchText and #searchText > 0
				if not isSearch and searchBar then
					helpPointer = helpPointer or require("ui_pointer"):create({ uikit = ui })
					helpPointer:pointAt({ target = searchBar, from = "below" })
				end
				local str = isSearch and "No result found." or "Invite your friends!"
				local text = ui:createText(str, Color.White)
				text:setParent(container)
				container.Width = node.Width
				container.Height = math.floor(cellHeight * 1.5)
				text.pos = { container.Width * 0.5 - text.Width * 0.5, container.Height * 0.5 - text.Height * 0.5 }
				return container
			end
			return
		end

		local width = node.Width
		local nbCells = math.min(Client.IsMobile and 4 or 2, math.floor(width / cellWidth))

		local firstUserCell, firstCellType = getUserAtIndex((cellId - 1) * nbCells + 1, nbCells)
		if not firstUserCell then
			return
		end

		local prevFirstCellUserType
		if cellId > 1 then
			_, prevFirstCellUserType = getUserAtIndex((cellId - 2) * nbCells + 1, nbCells)
		end

		local verticalContainer
		local line = require("ui_container"):createHorizontalContainer()
		line.Width = math.floor(width)
		line.Height = math.floor(cellHeight)
		line.cells = {}
		line.onRemove = function()
			for _, cell in ipairs(line.cells) do
				if cell.waitScrollStopTimer then
					cell.waitScrollStopTimer:Cancel()
				end
			end
		end
		-- Need to make a vertical container to add the title
		if prevFirstCellUserType == nil or firstCellType ~= prevFirstCellUserType then
			local titles = {
				friends = "Friends (%d)",
				received = "Pending Requests (%d)",
				sent = "Sent Requests (%d)",
				search = "Search (%d)",
			}
			local titleStr = titles[firstCellType]
			if titleStr then
				verticalContainer = require("ui_container"):createVerticalContainer()
				local title = ui:createText(string.format(titleStr, #lists[firstCellType]), Color.White)
				verticalContainer:pushElement(title)
				verticalContainer:pushElement(line)
			else
				line:pushGap()
			end
		else
			line:pushGap()
		end

		-- Stretch width to fit the full length
		local realCellWidth = math.floor((width - 2 * padding - (nbCells - 1) * 3 * padding) / nbCells)
		for i = 1, nbCells do
			local cell = createFriendCell({ width = realCellWidth, height = cellHeight })
			line:pushElement(cell)
			if i < nbCells then
				line:pushGap()
				line:pushGap()
				line:pushGap()
			end
			table.insert(line.cells, cell)

			local user, cellType = getUserAtIndex((cellId - 1) * nbCells + i, nbCells)
			if user then
				cell:setUser(user)
				cell:setType(cellType)
			elseif getUserAtIndex(1, nbCells) ~= nil then
				cell:hide()
			end
		end

		return verticalContainer or line
	end

	local unloadLine = function(line)
		line:remove()
	end

	local config = {
		cellPadding = 5,
		loadCell = loadLine,
		unloadCell = unloadLine,
		uikit = uikit or require("uikit"),
	}

	scroll = ui:createScrollArea(Color(20, 20, 20), config)
	scroll:setParent(node)
	node.scroll = scroll

	node.resetList = function(keepScrollPosition)
		local scrollPosition = keepScrollPosition and scroll.scrollPosition or 0
		scroll:flush()
		if helpPointer then
			helpPointer:remove()
			helpPointer = nil
		end
		scroll:setScrollPosition(scrollPosition)
	end

	node:resetList()
	retrieveFriendsLists()

	content.node = node
	content.idealReducedContentSize = idealReducedContentSize

	local _modal = require("modal"):create(content, maxWidth, maxHeight, position, ui)
	return _modal
end

return friendsWindow
