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

local cachedAvatars = {}

local uiAvatar = require("ui_avatar")
local theme = require("uitheme").current
local padding = theme.padding
local modal = require("modal")
local api = require("system_api", System)

-- list IDs
local LIST = {
	RECEIVED = 1,
	SENT = 2,
	FRIENDS = 3,
	SEARCH = 4,
}

local TITLES = {
	"Received (%d)",
	"Sent (%d)",
	"Friends (%d)",
	"Search (%d)",
}

-- uikit: optional, allows to provide specific instance of uikit
mt.__index.create = function(_, maxWidth, maxHeight, position, uikit)
	local ui = uikit or require("uikit")
	local content = modal:createContent()
	content.title = "Friends"
	content.icon = "😛"

	local scroll
	local searchText
	local loading = true

	-- list of friends, requests (sent or received) or search
	local lists = {
		received = {},
		sent = {},
		friends = {},
		search = {},
	}

	local searchTimer
	local requests = {}

	local cancelRequests = function()
		for _, r in ipairs(requests) do
			r:Cancel()
		end
		requests = {}
	end

	local cancelRequestsAndTimers = function()
		if searchTimer ~= nil then
			searchTimer:Cancel()
			searchTimer = nil
		end
		cancelRequests()
	end

	local idealReducedContentSize = function(_, width, height, minWidth)
		width = math.min(width, 500)
		width = math.max(minWidth, width)
		return Number2(width, height)
	end

	local node = ui:createFrame(Color(0, 0, 0, 0))

	node.onRemove = function()
		cancelRequestsAndTimers()
		-- this is necessary for lines to be unloaded
		--  and cells to cancel their requests
		scroll:flush()
		node.screenDidResizeListener:Remove()
		node.screenDidResizeListener = nil
		if helpPointer then
			helpPointer:remove()
			helpPointer = nil
		end
	end

	local retrieveFriendsLists = function(searchStr, keepScrollPosition)
		cancelRequestsAndTimers()

		searchText = searchStr
		loading = true
		local nbLists = 4
		local nbListsRetrieved = 0

		lists = {}
		lists[LIST.RECEIVED] = {}
		lists[LIST.SENT] = {}
		lists[LIST.FRIENDS] = {}
		lists[LIST.SEARCH] = {}

		listsN = {}
		listsN[LIST.RECEIVED] = 0
		listsN[LIST.SENT] = 0
		listsN[LIST.FRIENDS] = 0
		listsN[LIST.SEARCH] = 0

		node:resetList()
		keepScrollPosition = keepScrollPosition or false

		local function newListResponse(listID, list)
			lists[listID] = list or {}
			nbListsRetrieved = nbListsRetrieved + 1
			if nbListsRetrieved < nbLists then
				return
			end

			if searchText and #searchText > 0 then
				-- filter out search list
				-- remove this part once backend handles that
				for k = #lists[LIST.SEARCH], 1, -1 do
					local user = lists[LIST.SEARCH][k]
					local idFound = false
					for _, v in ipairs(lists[LIST.FRIENDS]) do
						if v.id == user.id then
							idFound = true
						end
					end
					for _, v in ipairs(lists[LIST.RECEIVED]) do
						if v.id == user.id then
							idFound = true
						end
					end
					for _, v in ipairs(lists[LIST.SENT]) do
						if v.id == user.id then
							idFound = true
						end
					end
					if idFound then
						table.remove(lists[LIST.SEARCH], k)
					end
				end
			end

			listsN[LIST.RECEIVED] = #lists[LIST.RECEIVED]
			listsN[LIST.SENT] = #lists[LIST.SENT]
			listsN[LIST.FRIENDS] = #lists[LIST.FRIENDS]
			listsN[LIST.SEARCH] = #lists[LIST.SEARCH]

			loading = false

			node:resetList(keepScrollPosition)
		end

		local function requestList(methodName, listID, searchText)
			local list = {}
			local nbIterations = 0
			if listID == LIST.SEARCH then
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
							newListResponse(listID, list)
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
					newListResponse(listID, {})
					return
				end
				for _, usrID in ipairs(users) do
					local req2 = api:getUserInfo(usrID, function(success, usr)
						if success == false then
							-- TODO: handle errors
							-- insert ERROR CELL
							return
						end
						if usr.username ~= "" then
							-- if search, match the username
							if not searchText or string.find(usr.username, searchText) then
								table.insert(list, usr)
							end
						end
						nbIterations = nbIterations + 1
						if nbIterations == #users then
							-- table.sort(list, function(a, b)
							-- 	return a.username < b.username -- ERROR: compare 2 nil values
							-- end)
							newListResponse(listID, list)
						end
					end)
					table.insert(requests, req2)
				end
			end)
			table.insert(requests, req)
		end

		requestList("getFriends", LIST.FRIENDS, searchText)
		requestList("getReceivedFriendRequests", LIST.RECEIVED, searchText)
		requestList("getSentFriendRequests", LIST.SENT, searchText)
		requestList("searchUser", LIST.SEARCH, searchText)
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

		textInput.onTextChange = function(_)
			cancelRequestsAndTimers()
			searchTimer = Timer(0.3, function()
				cancelRequests()
				searchTimer = nil
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
		cell.requests = {}

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
					cell:setColor(Color(63, 63, 63))
					local profileContent = require("profile"):create({
						isLocal = false,
						username = user.username,
						userID = user.id,
						uikit = ui,
					})
					content:push(profileContent)
				end
				cell.onPress = function()
					cell:setColor(Color(35, 35, 35))
				end
				cell.onCancel = function()
					cell:setColor(Color(63, 63, 63))
				end

				cell.IsMask = true
				cell.username = user.username
				cell.userID = user.id
				textBg.LocalPosition.Z = -600
				avatar = cachedAvatars[user.username]
				if avatar == nil then
					local requests
					avatar, requests = uiAvatar:get(user.username, cell.Height * 0.9, nil, ui)
					for _, r in ipairs(requests) do
						table.insert(cell.requests, r)
					end
				end
				avatar:setParent(cell)
				avatar.didLoad = function()
					avatar.body.pivot.LocalRotation = Rotation(-math.pi / 8, 0, 0) * Rotation(0, math.rad(145), 0)
					cachedAvatars[user.username] = avatar
				end
				cell.avatar = avatar
				local r = Object:Load("buche.lobby_grassland", function(obj)
					if obj == nil then
						return
					end
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
				table.insert(cell.requests, r)
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
			if cellType == LIST.RECEIVED then
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
			elseif cellType == LIST.SENT then
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
			elseif cellType == LIST.FRIENDS then
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
			elseif cellType == LIST.SEARCH then
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

	local loadLine = function(cellId)
		if loading == true then
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

		local nbResults = 0
		for _, n in ipairs(listsN) do
			nbResults = nbResults + n
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
		-- nb cells per line
		local nbCellsPerLine = math.floor(width / cellWidth)

		local getContentForLine = function(lineNumber, nbCellsPerLine)
			nbCellsPerLine = math.floor(nbCellsPerLine)
			local l = 1
			while l <= #lists do
				if listsN[l] == 0 then
					l = l + 1 -- nothing in that list, look in next one
				elseif lineNumber == 1 then
					return lists[l], l, true -- first line : title
				else
					local nbLinesForList = math.floor(listsN[l] / nbCellsPerLine)
						+ (listsN[l] % nbCellsPerLine > 0 and 1 or 0)

					if lineNumber - 1 <= nbLinesForList then
						local start = (lineNumber - 2) * nbCellsPerLine + 1
						local stop = math.min(start + nbCellsPerLine - 1, listsN[l])
						return lists[l], l, nil, { start, stop }
					else
						l = l + 1
						lineNumber = lineNumber - 1 - nbLinesForList
					end
				end
			end
		end

		local list, listID, title, range = getContentForLine(cellId, nbCellsPerLine)

		-- print("listID:", listID, "title:", title, "range:", range[1], range[2])

		if title then
			local titleStr = TITLES[listID]
			return ui:createText(string.format(titleStr, listsN[listID]), Color.White)
		end

		if list and range then
			local line = require("ui_container"):createHorizontalContainer()
			line.cells = {}
			line.onRemove = function()
				for _, cell in ipairs(line.cells) do
					if cell.avatar then
						cell.avatar:setParent(nil)
						cell.avatar = nil
					end
					for _, r in ipairs(cell.requests) do
						r:Cancel()
					end
					cell.requests = {}
					if cell.waitScrollStopTimer then
						cell.waitScrollStopTimer:Cancel()
						cell.waitScrollStopTimer = nil
					end
				end
			end

			local start = range[1]
			for i = start, range[2] do
				local cell = createFriendCell({ width = cellWidth, height = cellHeight })
				if i > start then
					line:pushGap()
				end
				line:pushElement(cell)

				table.insert(line.cells, cell)

				cell:setUser(list[i])
				cell:setType(listID)
			end

			return line
		end
	end

	local unloadLine = function(lineOrVerticalContainer)
		local line = lineOrVerticalContainer
		if lineOrVerticalContainer.line then
			line = lineOrVerticalContainer.line
		end
		if line == nil then
			return
		end
		lineOrVerticalContainer:remove()
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
