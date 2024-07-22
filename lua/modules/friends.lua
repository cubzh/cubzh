--- This module creates a modal that allows to manage friend relationships.

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
local api = require("api", System)
local systemApi = require("system_api", System)
local CELL_PADDING = padding

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
	local showSent = false

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

			if listID == LIST.SEARCH then
				if searchText == nil or searchText == "" then
					newListResponse(listID, list)
					return
				end
				local req = api:searchUser(searchText, function(ok, users, err)
					if not ok then
						newListResponse(listID, list) -- set empty list
						error("request failed: " .. err)
					end
					if #users == 0 then
						newListResponse("search", {})
					end
					for _, usr in ipairs(users) do
						if usr and usr.username ~= "" then
							table.insert(list, usr)
						end
					end
					table.sort(list, function(a, b)
						return a.username < b.username
					end)
					newListResponse(listID, list)
				end)
				table.insert(requests, req)
				return
			end

			local req = api[methodName](api, { fields = { "id", "username", "lastSeen" } }, function(users, err)
				if err ~= nil then
					newListResponse(listID, list) -- set empty list
					error("request failed: " .. err.message)
				end
				if #users == 0 then
					newListResponse(listID, {})
					return
				end
				for _, usr in ipairs(users) do
					if usr.username ~= "" then
						-- if search, match the username
						if not searchText or string.find(usr.username, searchText) then
							table.insert(list, usr)
						end
					end
				end
				newListResponse(listID, list)

				local function sortByLastSeen(a, b)
					if a.lastSeen ~= nil and b.lastSeen ~= nil then
						return a.lastSeen > b.lastSeen
					end
					return a.id > b.id
				end

				table.sort(list, sortByLastSeen)
			end, { "username", "id" })
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

	local btnConfig = {
		borders = false,
		shadow = false,
		textSize = "small",
		color = Color(0, 0, 0, 0.7),
	}

	local computeCellSize = function()
		local w = 170
		local h = 100
		-- 2 buttons + 1 label stacked vertically
		local btn = ui:createButton("foo", btnConfig)
		local label = ui:createText("username1234567", Color.White, "small") -- usernames are 15 chars max
		-- 3 paddings between buttons & label +  padding around label within frame
		h = math.max(h, btn.Height * 2 + label.Height + padding * 5)
		w = math.max(w, label.Width + padding * 2)

		btn:remove()
		label:remove()
		return w, h
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
		textName.pos = { padding, padding }
		local textStatus = ui:createText("", Color.White, "small")
		textStatus:setParent(textBg)
		textBg:hide()

		local btnPrimary = ui:createButton("", btnConfig)
		btnPrimary:setParent(cell)
		btnPrimary.pos = { padding, padding }
		local btnSecondary = ui:createButton("", btnConfig)
		btnSecondary:setParent(cell)

		local avatar
		cell.parentDidResize = function()
			cell.Height = forceHeight or cellHeight
			cell.Width = forceWidth or cell.Height

			textBg.Width = textName.Width + padding * 2
			textBg.Height = textName.Height + padding * 2
			textBg.pos.Y = cell.Height - textBg.Height

			if avatar then
				avatar.Height = cell.Height -- avatars are spherized, so there's enough margin already
				avatar.pos = { cell.Width * 0.666 - avatar.Width * 0.5, cell.Height * 0.5 - avatar.Height * 0.5 }
			end

			btnPrimary.pos = { padding, padding }
			btnSecondary.pos = { btnPrimary.pos.X, btnPrimary.pos.Y + btnPrimary.Height + padding }

			-- display in front of shape
			textBg.LocalPosition.Z = -600
			btnPrimary.LocalPosition.Z = -600
			btnSecondary.LocalPosition.Z = -600
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

				cell.username = user.username
				cell.userID = user.id
				textBg.LocalPosition.Z = -600
				avatar = cachedAvatars[user.username]
				if avatar == nil then
					local requests
					avatar, requests =
						uiAvatar:get({ usernameOrId = user.username, size = cell.Height * 0.95, ui = ui })
					for _, r in ipairs(requests) do
						table.insert(cell.requests, r)
					end
				end
				avatar:setParent(cell)
				avatar.didLoad = function()
					avatar.body.pivot.LocalRotation = Rotation(math.rad(-22), 0, 0) * Rotation(0, math.rad(145), 0)
					cachedAvatars[user.username] = avatar
				end
				cell.avatar = avatar
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
				btnPrimary.Text = "✅ Accept"
				btnPrimary:show()
				btnPrimary.onRelease = function()
					local req = systemApi:replyToFriendRequest(cell.userID, true, function(ok, _)
						if not ok then
							return
						end
						retrieveFriendsLists(nil, true)
					end)
					table.insert(requests, req)
				end
				btnSecondary.Text = "❌"
				btnSecondary:show()
				btnSecondary.onRelease = function()
					local req = systemApi:replyToFriendRequest(cell.userID, false, function(ok, _)
						if not ok then
							return
						end
						retrieveFriendsLists(nil, true)
					end)
					table.insert(requests, req)
				end
			elseif cellType == LIST.SENT then
				btnPrimary.Text = "❌ Cancel"
				btnPrimary:show()
				btnPrimary.onRelease = function()
					local req = systemApi:cancelFriendRequest(cell.userID, function(ok, _)
						if not ok then
							return
						end
						retrieveFriendsLists(nil, true)
					end)
					table.insert(requests, req)
				end
				btnSecondary.Text = ""
				btnSecondary:hide()
				btnSecondary.onRelease = nil
			elseif cellType == LIST.FRIENDS then
				btnPrimary.Text = "🌎 Join"
				btnPrimary:show()
				btnPrimary.onRelease = function()
					require("menu"):ShowAlert({ message = "Coming soon!" }, System)
				end
				btnSecondary.Text = "💬"
				btnSecondary:show()
				btnSecondary.onRelease = function()
					require("menu"):ShowAlert({ message = "Coming soon!" }, System)
				end
			elseif cellType == LIST.SEARCH then
				btnPrimary.Text = "➕ Add friend"
				btnPrimary:show()
				btnPrimary.onRelease = function()
					local req = systemApi:sendFriendRequest(cell.userID, function(ok, _)
						if not ok then
							return
						end
						retrieveFriendsLists(searchText, true)
					end)
					table.insert(requests, req)
				end
				btnSecondary.Text = ""
				btnSecondary:hide()
				btnSecondary.onRelease = nil
			end
			cell:parentDidResize()
		end

		return cell
	end

	-- local loadLine = function(cellId)
	-- 	if loading == true then
	-- 		if cellId == 1 then
	-- 			local container = ui:createFrame()
	-- 			local text = ui:createText("Loading...", Color.White)
	-- 			text:setParent(container)
	-- 			container.Width = node.Width
	-- 			container.Height = math.floor(cellHeight)
	-- 			text.pos = { container.Width * 0.5 - text.Width * 0.5, container.Height * 0.5 - text.Height * 0.5 }
	-- 			return container
	-- 		end
	-- 		return
	-- 	end

	-- 	local nbResults = 0
	-- 	for _, n in ipairs(listsN) do
	-- 		nbResults = nbResults + n
	-- 	end

	-- 	if nbResults == 0 then
	-- 		if cellId == 1 then
	-- 			local container = ui:createFrame()
	-- 			local isSearch = searchText and #searchText > 0
	-- 			if not isSearch and searchBar then
	-- 				helpPointer = helpPointer or require("ui_pointer"):create({ uikit = ui })
	-- 				helpPointer:pointAt({ target = searchBar, from = "below" })
	-- 			end
	-- 			local str = isSearch and "No result found." or "Invite your friends!"
	-- 			local text = ui:createText(str, Color.White)
	-- 			text:setParent(container)
	-- 			container.Width = node.Width
	-- 			container.Height = math.floor(cellHeight * 1.5)
	-- 			text.pos = { container.Width * 0.5 - text.Width * 0.5, container.Height * 0.5 - text.Height * 0.5 }
	-- 			return container
	-- 		end
	-- 		return
	-- 	end

	-- 	local width = node.Width
	-- 	-- nb cells per line
	-- 	local nbCellsPerLine = math.floor(width / cellWidth)

	-- 	local adaptedCellWidth = (width - (CELL_PADDING * (nbCellsPerLine - 1))) / nbCellsPerLine

	-- 	local getContentForLine = function(lineNumber, nbCellsPerLine)
	-- 		nbCellsPerLine = math.floor(nbCellsPerLine)
	-- 		local l = 1
	-- 		while l <= #lists do
	-- 			if listsN[l] == 0 then
	-- 				l = l + 1 -- nothing in that list, look in next one
	-- 			elseif showSent == false and l == LIST.SENT and lineNumber > 1 then
	-- 				lineNumber = lineNumber - 1
	-- 				l = l + 1
	-- 			elseif lineNumber == 1 then
	-- 				return lists[l], l, true -- first line : title
	-- 			else
	-- 				local nbLinesForList = math.floor(listsN[l] / nbCellsPerLine)
	-- 					+ (listsN[l] % nbCellsPerLine > 0 and 1 or 0)

	-- 				if lineNumber - 1 <= nbLinesForList then
	-- 					local start = (lineNumber - 2) * nbCellsPerLine + 1
	-- 					local stop = math.min(start + nbCellsPerLine - 1, listsN[l])
	-- 					return lists[l], l, nil, { start, stop }
	-- 				else
	-- 					l = l + 1
	-- 					lineNumber = lineNumber - 1 - nbLinesForList
	-- 				end
	-- 			end
	-- 		end
	-- 	end

	-- 	local list, listID, title, range = getContentForLine(cellId, nbCellsPerLine)

	-- 	if title then
	-- 		local titleStr = TITLES[listID]
	-- 		local frame = ui:createFrame(Color(0, 0, 0, 0.5))
	-- 		local text = ui:createText(string.format(titleStr, listsN[listID]), Color.White)
	-- 		text:setParent(frame)
	-- 		text.pos = { padding, padding }
	-- 		frame.Width = width
	-- 		frame.Height = text.Height + padding * 2

	-- 		if listID == LIST.SENT then
	-- 			if showSent then
	-- 				local arrow = ui:createText("⬆️", Color.White)
	-- 				arrow:setParent(frame)
	-- 				arrow.pos = { frame.Width - arrow.Width - padding, padding }
	-- 			else
	-- 				local arrow = ui:createText("⬇️", Color.White)
	-- 				arrow:setParent(frame)
	-- 				arrow.pos = { frame.Width - arrow.Width - padding, padding }
	-- 			end

	-- 			frame.onPress = function(_)
	-- 				frame.Color = Color(50, 50, 50, 0.5)
	-- 			end

	-- 			frame.onRelease = function(_)
	-- 				frame.Color = Color(0, 0, 0, 0.5)
	-- 				showSent = not showSent
	-- 				node:resetList(true)
	-- 			end
	-- 		end

	-- 		return frame
	-- 	end

	-- 	if list and range then
	-- 		local line = require("ui_container"):createHorizontalContainer({ gapSize = CELL_PADDING })
	-- 		line.cells = {}
	-- 		line.onRemove = function()
	-- 			for _, cell in ipairs(line.cells) do
	-- 				if cell.avatar then
	-- 					cell.avatar:setParent(nil)
	-- 					cell.avatar = nil
	-- 				end
	-- 				for _, r in ipairs(cell.requests) do
	-- 					r:Cancel()
	-- 				end
	-- 				cell.requests = {}
	-- 				if cell.waitScrollStopTimer then
	-- 					cell.waitScrollStopTimer:Cancel()
	-- 					cell.waitScrollStopTimer = nil
	-- 				end
	-- 			end
	-- 		end

	-- 		local start = range[1]
	-- 		for i = start, range[2] do
	-- 			local cell = createFriendCell({ width = adaptedCellWidth, height = cellHeight })
	-- 			if i > start then
	-- 				line:pushGap()
	-- 			end
	-- 			line:pushElement(cell)

	-- 			table.insert(line.cells, cell)

	-- 			cell:setUser(list[i])
	-- 			cell:setType(listID)
	-- 		end

	-- 		return line
	-- 	end
	-- end

	local config = {
		cellPadding = CELL_PADDING,
		loadCell = function(index) end,
		unloadCell = function(index, cell)
			-- local line = lineOrVerticalContainer
			-- if lineOrVerticalContainer.line then
			-- 	line = lineOrVerticalContainer.line
			-- end
			-- if line == nil then
			-- 	return
			-- end
			-- lineOrVerticalContainer:remove()
		end,
	}

	scroll = ui:createScroll(config)

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
