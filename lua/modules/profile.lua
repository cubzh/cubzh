profile = {}

-- MODULES
api = require("api", System)
systemApi = require("system_api", System)
modal = require("modal")
theme = require("uitheme").current
uiAvatar = require("ui_avatar")
str = require("str")

-- CONSTANTS

local AVATAR_MAX_SIZE = 300
local AVATAR_MIN_SIZE = 200
local ACTIVE_NODE_MARGIN = theme.paddingBig

local AVATAR_NODE_RATIO = 1

--- Creates a profile modal content
--- positionCallback(function): position of the popup
--- config(table): isLocal, id, username
--- returns: modal content
profile.create = function(_, config)
	local defaultConfig = {
		userID = "",
		username = "",
		uikit = require("uikit"), -- allows to provide specific instance of uikit
	}

	local ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config)
	end)
	if not ok then
		error("profile:create(config) - config error: " .. err, 2)
	end

	local username
	local userID
	local isLocal = config.userID == Player.UserID

	if isLocal then
		username = Player.Username
		userID = Player.UserID
	else
		username = config.username
		userID = config.userID
	end

	if userID == nil then
		error("profile.create called without a userID", 2)
	end

	local ui = config.uikit

	-- nodes beside avatar
	local activeNode = nil
	local infoNode

	local functions = {}

	local profileNode = ui:createFrame()
	profileNode.Width = 200
	profileNode.Height = 200

	local content = modal:createContent()
	content.title = username
	content.icon = "😛"
	content.node = profileNode

	local cell = ui:frame() -- { color = Color(100, 100, 100) }
	cell.Height = 100
	cell:setParent(nil)

	local scroll = ui:createScroll({
		-- backgroundColor = Color(255, 0, 0),
		backgroundColor = theme.buttonTextColor,
		-- backgroundColor = Color(0, 255, 0, 0.3),
		-- gradientColor = Color(37, 23, 59), -- Color(155, 97, 250),
		padding = {
			top = theme.padding,
			bottom = theme.padding,
			left = theme.padding,
			right = theme.padding,
		},
		cellPadding = theme.padding,
		loadCell = function(index)
			if index == 1 then
				return cell
			end
		end,
		unloadCell = function(_, _) end,
	})
	scroll:setParent(profileNode)

	local requests = {}

	profileNode.onRemove = function()
		for _, req in ipairs(requests) do
			req:Cancel()
		end
		requests = {}
	end

	local editBtn

	local avatarNode = uiAvatar:get({ usernameOrId = username, ui = ui })
	-- avatarNode:setColor(Color(255, 0, 0))
	avatarNode:setParent(cell)

	local editAvatarBtn = ui:buttonNeutral({ content = "✏️ Edit avatar" })
	editAvatarBtn:setParent(isLocal and profileNode or nil)

	editAvatarBtn.onRelease = function()
		-- editAvatarBtnOnReleaseCallback()
	end

	local userInfo = {
		bio = "",
		discord = "",
		tiktok = "",
		x = "",
		github = "",
		nbFriends = 0,
		created = nil,
	}

	-- functions to create each node

	local createInfoNode = function()
		local socialBtnsConfig = {
			{
				key = "discord",
				icon = "👾",
				action = function(str)
					Dev:CopyToClipboard(str)
				end,
				prefix = "@",
			},
			{
				key = "tiktok",
				icon = "🇹",
				action = function(str)
					URL:Open("https://www.tiktok.com/@" .. str)
				end,
				prefix = "@",
			},
			{
				key = "x",
				icon = "🇽",
				action = function(str)
					URL:Open("https://x.com/" .. str)
				end,
				prefix = "@",
			},
			{
				key = "github",
				icon = "🇬",
				action = function(str)
					URL:Open("https://github.com/" .. str)
				end,
				prefix = "",
			},
		}

		local node = ui:frame()

		-- local usernameText = ui:createText(username, Color.White, "big")
		-- usernameText:setParent(node)

		local reputation = ui:createText("🏆 0", Color.White)
		reputation:setParent(cell)

		local friends = ui:createText("🙂 0", Color.White)
		friends:setParent(cell)

		local created = ui:createText("📰 ", Color.White)
		created:setParent(cell)

		local bioText = ui:createText(userInfo.bio, { color = Color.White, size = "small" })
		bioText:setParent(cell)

		local socialBtns = {}
		for _, config in ipairs(socialBtnsConfig) do
			local btn = ui:buttonSecondary({ content = "", textSize = "small", textColor = theme.urlColor })
			btn:setParent(cell)
			btn:hide()
			socialBtns[config.key] = btn
		end

		node.parentDidResize = function(self)
			self:refresh()
		end

		node.refresh = function(self)
			local parent = self.parent
			local padding = theme.padding

			self.Width = parent.Width

			local totalHeight = reputation.Height

			local listVisibleSocialButtons = {}
			for _, v in pairs(socialBtns) do
				if v:isVisible() then
					table.insert(listVisibleSocialButtons, v)
				end
			end

			if bioText.Text ~= "" then
				bioText.object.MaxWidth = self.Width
				totalHeight = totalHeight + bioText.Height + padding
			end

			if #listVisibleSocialButtons > 0 then
				local btnListHeight = math.ceil(#listVisibleSocialButtons / 2) * (socialBtns.tiktok.Height + padding)
				totalHeight = totalHeight + btnListHeight + padding
			end

			self.Height = totalHeight

			local cursorY = self.Height

			-- stats
			cursorY = cursorY - reputation.Height - padding
			local bottomLineWidth = reputation.Width + padding + friends.Width + padding + created.Width

			reputation.pos = { self.Width * 0.5 - bottomLineWidth * 0.5, cursorY }
			friends.pos = { reputation.pos.X + reputation.Width + padding, cursorY }
			created.pos = { friends.pos.X + friends.Width + padding, cursorY }

			if bioText.Text ~= "" then
				bioText.pos = { self.Width * 0.5 - bioText.Width * 0.5, cursorY - bioText.Height - padding }
				cursorY = bioText.pos.Y
			end

			-- Place middle block (socials)
			if #listVisibleSocialButtons > 0 then
				for i = 1, #listVisibleSocialButtons, 2 do -- iterate 2 by 2 to place 2 buttons on the same line
					local btn1 = listVisibleSocialButtons[i]
					local btn2 = listVisibleSocialButtons[i + 1]

					cursorY = cursorY - btn1.Height - padding

					if not btn2 then
						btn1.pos = { self.Width * 0.5 - btn1.Width * 0.5, cursorY }
					else
						local fullwidth = btn1.Width + btn2.Width + padding
						btn1.pos = { self.Width * 0.5 - fullwidth * 0.5, cursorY }
						btn2.pos = { self.Width * 0.5 + fullwidth * 0.5 - btn2.Width, cursorY }
					end
				end
			end
		end

		node.setUserInfo = function(_)
			if friends.Text == nil then
				return
			end

			friends.Text = "🙂 " .. tostring(userInfo.nbFriends)

			if userInfo.created ~= nil then
				local creationDateIso = userInfo.created
				local creationDateTable = require("time"):iso8601ToTable(creationDateIso)
				local creationYear = creationDateTable.year
				local creationMonth = require("time"):monthToString(math.tointeger(creationDateTable.month))
				local createdStr = creationMonth .. " " .. creationYear

				created.Text = "📰 " .. createdStr
			else
				created.Text = "📰"
			end

			bioText.Text = str:trimSpaces(userInfo.bio or "")

			local charWidth
			local emojiWidth
			do
				local aChar = ui:createText("a", nil, "small")
				charWidth = aChar.Width
				aChar:remove()

				local anEmoji = ui:createText("👾", nil, "small")
				emojiWidth = anEmoji.Width
				anEmoji:remove()
			end

			local availableWidth = activeNode.Width / 2
				- ACTIVE_NODE_MARGIN * 2
				- theme.padding * 2
				- emojiWidth
				- charWidth * 2
			local nbMaxChars = availableWidth // charWidth

			-- Loop through the config list and apply the logic
			local btn
			local displayStr
			for _, config in pairs(socialBtnsConfig) do
				local value = userInfo[config.key]
				btn = socialBtns[config.key]
				if value ~= nil and value ~= "" then
					if string.len(value) > nbMaxChars then
						displayStr = config.icon
							.. " "
							.. config.prefix
							.. string.sub(value, 1, nbMaxChars - 1)
							.. "…"
					else
						displayStr = config.icon .. " " .. config.prefix .. value
					end
					btn.Text = displayStr
					btn:show()
					btn.onRelease = function()
						config.action(value)
					end
				else
					btn.Text = config.icon
					btn:hide()
				end
			end

			node:refresh()
			scroll:parentDidResize()
		end

		return node
	end

	local createEditInfoNode = function()
		local node = ui:createFrame(Color(0, 0, 0, 0))
		node.type = "EditInfoNode"

		local bioTitle = ui:createText("✏️ Bio", theme.textColor)
		bioTitle:setParent(node)

		-- temporary button
		local bioBtn = ui:buttonNeutral({ content = "Edit Bio" })
		bioBtn:setParent(node)
		bioBtn.onRelease = function()
			System.MultilineInput(
				userInfo.bio,
				"Your bio",
				"Describe yourself with 140 characters",
				"",
				140,
				function(text) -- done
					userInfo.bio = text
					local data = { bio = userInfo.bio }
					-- TODO: we could use `api` instead of `require("system_api", System)`
					require("system_api", System):patchUserInfo(data, function(err)
						if err then
							print("❌", err)
						end
					end)
					ui:turnOn()
				end,
				function() -- cancel
					ui:turnOn()
				end
			)
			ui:turnOff()
		end

		local removeURL = function(value)
			local slashIndex = 0
			for i = 1, #value do
				if string.sub(value, i, i) == "/" then
					slashIndex = i
				end
			end
			if slashIndex ~= 0 then
				value = string.sub(value, slashIndex + 1, #value)
			end

			return value
		end

		local trimPrefix = function(str, prefix)
			if str:sub(1, #prefix) == prefix then
				-- Trim the prefix
				local trimmedStr = str:sub(#prefix + 1)
				return trimmedStr
			end
			return str -- return the string, unchanged
		end

		local socialLinksTitle = ui:createText("✏️ Social links", theme.textColor)
		socialLinksTitle:setParent(node)

		local discordLogo = ui:createFrame()
		discordLogo:setParent(node)
		local discordEmoji = ui:createText("👾")
		discordEmoji:setParent(discordLogo)
		local discordLink = ui:createTextInput(userInfo.discord or "", "Discord username")
		discordLink:setParent(node)
		discordLink.onFocusLost = function(self)
			local previous = userInfo.discord
			userInfo.discord = self.text
			-- send API request to update user info
			systemApi:patchUserInfo({ discord = userInfo.discord }, function(err)
				if err then
					print("❌", err)
					userInfo.discord = previous
				end
			end)
			-- background request, not updating profile UI
			-- table.insert(requests, req)
		end

		local tiktokLogo = ui:createFrame()
		tiktokLogo:setParent(node)
		local tiktokEmoji = ui:createText("🇹")
		tiktokEmoji:setParent(tiktokLogo)
		local tiktokLink = ui:createTextInput(userInfo.tiktok or "", "TikTok username")
		tiktokLink:setParent(node)
		tiktokLink.onFocusLost = function(self)
			local previous = userInfo.tiktok
			userInfo.tiktok = self.text
			userInfo.tiktok = removeURL(userInfo.tiktok)
			userInfo.tiktok = trimPrefix(userInfo.tiktok, "@")
			-- send API request to update user info
			systemApi:patchUserInfo({ tiktok = userInfo.tiktok }, function(err)
				if err then
					print("❌", err)
					userInfo.tiktok = previous
				end
			end)
			-- background request, not updating profile UI
			-- table.insert(requests, req)
		end

		local xLogo = ui:createFrame()
		xLogo:setParent(node)
		local xEmoji = ui:createText("🇽")
		xEmoji:setParent(xLogo)
		local xLink = ui:createTextInput(userInfo.x or "", "X username")
		xLink.onTextChange = function()
			if xLink.Text ~= "" then
				if xLink.Text == "@" then
					xLink.Text = ""
				elseif xLink.Text:sub(1, 1) ~= "@" then
					xLink.Text = "@" .. xLink.Text
				end
			end
		end
		xLink:onTextChange()
		xLink:setParent(node)
		xLink.onFocusLost = function(self)
			local value = self.text
			-- trim "@" prefix if found
			if value:sub(1, 1) == "@" then
				value = value:sub(2)
			end
			value = removeURL(value)
			local previous = userInfo.x
			userInfo.x = value
			-- send API request to update user info
			systemApi:patchUserInfo({ x = userInfo.x }, function(err)
				if err then
					print("❌", err)
					userInfo.x = previous
				end
			end)
			-- background request, not updating UI
			-- table.insert(requests, req)
		end

		local githubLogo = ui:createFrame()
		githubLogo:setParent(node)
		local githubEmoji = ui:createText("🇬")
		githubEmoji:setParent(githubLogo)
		local githubUsername = ui:createTextInput(userInfo.github or "", "GitHub username")
		githubUsername:setParent(node)
		githubUsername.onFocusLost = function(self)
			local previous = userInfo.github
			userInfo.github = self.text
			userInfo.github = removeURL(userInfo.github)
			-- send API request to update user info
			systemApi:patchUserInfo({ github = userInfo.github }, function(err)
				if err then
					print("❌", err)
					userInfo.github = previous
				end
			end)
			-- background request, not updating UI
			-- table.insert(requests, req)
		end

		node.refresh = function(self)
			local padding = theme.padding
			local textInputHeight = discordLink.Height

			self.Height = bioTitle.Height
				+ padding
				+ bioBtn.Height
				+ padding
				+ socialLinksTitle.Height
				+ padding
				+ textInputHeight
				+ padding -- discord
				+ textInputHeight
				+ padding -- tiktok
				+ textInputHeight
				+ padding -- X
				+ textInputHeight -- Github

			bioTitle.pos.X = 0
			bioTitle.pos.Y = self.Height - bioTitle.Height

			bioBtn.pos.X = 0
			bioBtn.pos.Y = bioTitle.pos.Y - bioBtn.Height - padding
			bioBtn.Width = self.Width

			socialLinksTitle.pos.X = 0
			socialLinksTitle.pos.Y = bioBtn.pos.Y - socialLinksTitle.Height - padding

			discordLogo.pos.X = 0
			discordLogo.pos.Y = socialLinksTitle.pos.Y - textInputHeight - padding
			discordLogo.Width = discordEmoji.Width
			discordLogo.Height = textInputHeight
			discordLink.pos.X = discordLogo.Width + padding
			discordLink.pos.Y = discordLogo.pos.Y
			discordLink.Width = self.Width - discordLogo.Width - padding
			discordEmoji.pos = { 0, (discordLogo.Height - discordEmoji.Height) * 0.5 }

			tiktokLogo.pos.X = 0
			tiktokLogo.pos.Y = discordLogo.pos.Y - textInputHeight - padding
			tiktokLogo.Width = tiktokEmoji.Width
			tiktokLogo.Height = textInputHeight
			tiktokLink.pos.X = tiktokLogo.Width + padding
			tiktokLink.pos.Y = tiktokLogo.pos.Y
			tiktokLink.Width = self.Width - tiktokLogo.Width - padding
			tiktokEmoji.pos = { 0, (tiktokLogo.Height - tiktokEmoji.Height) * 0.5 }

			xLogo.pos.X = 0
			xLogo.pos.Y = tiktokLogo.pos.Y - textInputHeight - padding
			xLogo.Width = xEmoji.Width
			xLogo.Height = textInputHeight
			xLink.pos.X = xLogo.Width + padding
			xLink.pos.Y = xLogo.pos.Y
			xLink.Width = self.Width - xLogo.Width - padding
			xEmoji.pos = { 0, (xLogo.Height - xEmoji.Height) * 0.5 }

			githubLogo.pos.X = 0
			githubLogo.pos.Y = xLogo.pos.Y - textInputHeight - theme.padding
			githubLogo.Width = githubEmoji.Width
			githubLogo.Height = textInputHeight
			githubUsername.pos.X = githubLogo.Width + padding
			githubUsername.pos.Y = githubLogo.pos.Y
			githubUsername.Width = self.Width - githubLogo.Width - padding
			githubEmoji.pos = { 0, (githubLogo.Height - githubEmoji.Height) * 0.5 }
		end

		return node
	end

	infoNode = createInfoNode()
	infoNode:setParent(nil)

	local toggleEditOptions = function(btn)
		if btn.Text == nil then
			return
		end

		editAvatarBtn:unselect()
		if btn.Text == "✏️ Edit" then
			btn.Text = "✅ Done"

			editInfoBtnOnReleaseCallback()
		else
			btn.Text = "✏️ Edit"

			content.tabs = nil
			functions.setActiveNode(infoNode)

			infoNode:setUserInfo()
		end
	end

	editInfoBtnOnReleaseCallback = function(_)
		content.tabs = nil
		editAvatarBtn:unselect()
		functions.setActiveNode(createEditInfoNode())
	end

	local avatarRot = Number3(0, math.pi, 0)
	local dragListener = nil
	local avatarLoadedListener = nil

	if isLocal then
		editBtn = ui:buttonNeutral({ content = "✏️ Edit" })
		editBtn:disable()

		local coinsBtn = ui:buttonNeutral({ content = "💰 …", sound = "coin_1" })
		coinsBtn.onRelease = function(_)
			content:getModalIfContentIsActive():push(require("coins"):createModalContent({ uikit = ui }))
		end

		api.getBalance(function(err, balance)
			if not coinsBtn.Text then
				return
			end
			if err then
				coinsBtn.Text = "💰 0"
				return
			end
			coinsBtn.Text = "💰 " .. math.floor(balance.total)
		end)

		content.bottomRight = { coinsBtn }
		content.bottomLeft = { editBtn }
	else
		local showCreationsBtn = ui:buttonNeutral({ content = "✨ Show Creations", textSize = "small" })
		showCreationsBtn.onRelease = function()
			require("menu"):ShowAlert({ message = "Coming soon!" }, System)
		end

		local addFriendBtn = ui:buttonNeutral({ content = "…", textSize = "small" })
		content.bottomCenter = { addFriendBtn, showCreationsBtn }

		local alreadyFriends = nil
		local requestSent = nil

		local updateFriendButton = function()
			if addFriendBtn.Text == nil then
				return
			end

			-- wait for both responses
			if alreadyFriends == nil or requestSent == nil then
				return
			end

			if alreadyFriends then
				addFriendBtn.Text = "Friends ❤️"
			elseif requestSent then
				addFriendBtn.Text = "Request sent!"
			else
				addFriendBtn.Text = "Add as Friend ➕"

				addFriendBtn.onRelease = function(btn)
					btn:disable()
					btn.text = "..."
					require("system_api", System):sendFriendRequest(userID, function(ok, err)
						if ok == true and err == nil then
							btn.text = "Request sent!"
							btn.onRelease = nil
							btn:enable()
						else
							btn.Text = "Add as Friend ➕"
							btn:enable()
						end
					end)
				end
			end
		end

		-- check if the User is already a friend
		local req = api:getFriends({ fields = { "id" } }, function(friends, err)
			if err ~= nil then
				return
			end

			alreadyFriends = false
			for _, friend in pairs(friends) do
				if friend.id == userID then
					alreadyFriends = true
					break
				end
			end
			updateFriendButton()
		end)
		table.insert(requests, req)

		-- check if a request was already sent
		req = api:getSentFriendRequests(function(requests, err)
			if err ~= nil then
				return
			end

			requestSent = false
			for _, req in pairs(requests) do
				if req.id == userID then
					requestSent = true
					break
				end
			end
			updateFriendButton()
		end, { "id" })
		table.insert(requests, req)
	end

	functions.refresh = function()
		if activeNode == nil then
			return
		end

		local totalWidth = profileNode.Width
		local totalHeight = profileNode.Height

		activeNode.Width = totalWidth - ACTIVE_NODE_MARGIN * 2
		activeNode.Height = totalHeight - ACTIVE_NODE_MARGIN * 2

		if activeNode.refresh then
			activeNode:refresh()
		end -- refresh may shrink content

		local activeNodeWidthWithMargin = activeNode.Width + ACTIVE_NODE_MARGIN * 2
		local activeNodeHeightWithMargin = activeNode.Height + ACTIVE_NODE_MARGIN * 2

		totalHeight = activeNodeHeightWithMargin + (isLocal and editAvatarBtn.Height or 0)
		totalWidth = math.max(activeNodeWidthWithMargin)

		return totalWidth, totalHeight
	end

	-- profileNode.parentDidResize = function(self)
	-- 	if activeNode == nil or avatarNode == nil then
	-- 		return
	-- 	end

	-- 	if isLocal then
	-- 		editAvatarBtn.pos = {
	-- 			self.Width * 0.5 - editAvatarBtn.Width * 0.5,
	-- 			avatarNode.pos.Y - editAvatarBtn.Height,
	-- 		}
	-- 	end

	-- 	activeNode.pos = { self.Width * 0.5 - activeNode.Width * 0.5, ACTIVE_NODE_MARGIN }
	-- end

	scroll.parentDidResize = function(self)
		local parent = self.parent
		local padding = theme.padding

		cell.Width = parent.Width - padding * 2

		scroll.Height = parent.Height
		scroll.Width = parent.Width
		scroll.pos = { 0, 0 }

		local width = self.Width - padding * 2

		local avatarNodeHeight = math.min(AVATAR_MAX_SIZE, math.max(self.Height * 0.3, AVATAR_MIN_SIZE))
		local avatarNodeWidth = avatarNodeHeight * AVATAR_NODE_RATIO
		if avatarNodeWidth > width then
			avatarNodeWidth = width
			avatarNodeHeight = avatarNodeWidth * 1.0 / AVATAR_NODE_RATIO
		end

		avatarNode.Width = avatarNodeWidth
		avatarNode.Height = avatarNodeHeight

		local cellContentHeight = avatarNodeHeight

		if infoNode.parent ~= nil then
			cellContentHeight = cellContentHeight + infoNode.Height + padding
		end

		cell.Height = cellContentHeight

		local y = cellContentHeight

		y = y - avatarNode.Height
		avatarNode.pos = {
			self.Width * 0.5 - avatarNode.Width * 0.5,
			y,
		}

		if infoNode.parent ~= nil then
			y = y - infoNode.Height - padding
			infoNode.pos = {
				self.Width * 0.5 - infoNode.Width * 0.5,
				y,
			}
		end

		scroll:flush()
		scroll:refresh()
	end

	functions.setActiveNode = function(newNode)
		if newNode == nil then
			print("active mode can't be nil")
			return
		end

		-- remove previous node if any
		if activeNode ~= nil then
			if activeNode == infoNode then
				activeNode:hide()
			else
				activeNode:remove()
			end
		end

		activeNode = newNode
		activeNode:setParent(cell)

		-- force layout refresh
		functions.refresh()

		content:refreshModal()
	end

	content.didBecomeActive = function()
		dragListener = LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pointerEvent)
			if avatarNode.body.pivot ~= nil then
				avatarRot.Y = avatarRot.Y - pointerEvent.DX * 0.02
				avatarRot.X = avatarRot.X + pointerEvent.DY * 0.02

				if avatarRot.X > math.pi * 0.4 then
					avatarRot.X = math.pi * 0.4
				end
				if avatarRot.X < -math.pi * 0.4 then
					avatarRot.X = -math.pi * 0.4
				end

				avatarNode.body.pivot.LocalRotation = Rotation(avatarRot.X, 0, 0) * Rotation(0, avatarRot.Y, 0)
				return true
			end
		end, { topPriority = true })

		local fillUserInfo = function(usr, err)
			if err ~= nil then
				return
			end

			-- store user info
			userInfo.bio = usr.bio or ""
			userInfo.discord = usr.discord or ""
			userInfo.tiktok = usr.tiktok or ""
			userInfo.x = usr.x or ""
			userInfo.github = usr.github or ""
			userInfo.nbFriends = usr.nbFriends or 0
			userInfo.created = usr.created

			-- update info node with user info we just received
			if infoNode.setUserInfo ~= nil then
				infoNode:setUserInfo()
			end

			if editBtn ~= nil and editBtn.enable ~= nil then
				editBtn:enable()
				editBtn.onRelease = function(btn)
					toggleEditOptions(btn)
				end
			end

			content:refreshModal()
		end

		local req = api:getUserInfo(userID, fillUserInfo, {
			"created",
			"nbFriends",
			"bio",
			"discord",
			"x",
			"tiktok",
			"github",
		})
		table.insert(requests, req)

		-- listen for avatar load
		avatarLoadedListener = LocalEvent:Listen(LocalEvent.Name.AvatarLoaded, function(player)
			-- avatar of local player is loaded, let's refresh the avatarNode
			if player == Player then
				if avatarNode.refresh then
					avatarNode:refresh()
				end
			end
		end)
	end

	content.willResignActive = function()
		-- stop listening for PointerDrag events
		if dragListener ~= nil then
			dragListener:Remove()
			dragListener = nil
		end

		-- stop listening for AvatarLoaded events
		if avatarLoadedListener then
			avatarLoadedListener:Remove()
			avatarLoadedListener = nil
		end
	end

	functions.setActiveNode(infoNode)

	return content
end

return profile
