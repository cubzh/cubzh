profile = {}

-- GENERAL MODULE CONFIG

-- Position of the avatar preview in the layout.
-- If true, avatar is on the right or the bottom.
-- If false, avatar is at the left or top.
avatarLandscapeRight = true
avatarPortraitTop = true

-- MODULES
api = require("system_api", System)
avatar = require("avatar")
equipments = require("equipments")
itemgrid = require("item_grid")
modal = require("modal")
theme = require("uitheme")
ui = require("uikit")
uiAvatar = require("ui_avatar")
pages = require("pages")
colorpicker = require("colorpicker")

-- CONSTANTS

-- Each menu has content + avatar
-- Here are a few constraint for responsive layout:

local EDIT_INFO_CONTENT_MAX_WIDTH = 400
local EDIT_FACE_CONTENT_MAX_WIDTH = 400

local AVATAR_MAX_SIZE = 300
local AVATAR_MIN_SIZE = 150

local CONTENT_MAX_WIDTH = 400

local DEBUG = false
local DEBUG_FRAME_COLOR = Color(255, 255, 0, 200)

local ACTIVE_NODE_MARGIN = theme.paddingBig

--- Creates a profile modal content
--- positionCallback(function): position of the popup
--- config(table): isLocal, id, username
--- returns: modal content
profile.create = function(_, config)
	if config ~= nil and type(config) ~= Type.table then
		error("profile:create(config): config should be a table", 2)
	end

	-- default config
	local _config = {
		isLocal = true,
		userID = "",
		username = "",
		uikit = ui, -- allows to provide specific instance of uikit
	}

	if config then
		for k, v in pairs(_config) do
			if type(config[k]) == type(v) then
				_config[k] = config[k]
			end
		end
	end

	local ui = _config.uikit

	if not _config.isLocal and (_config.userID == "" or _config.username == "") then
		error("profile:create(config): config.userID should be a valid userID", 2)
	end

	-- nodes beside avatar
	local activeNode = nil
	local infoNode

	local preferredLayout = "landscape"

	local functions = {}

	local profileNode = ui:createFrame()
	profileNode.Width = 200
	profileNode.Height = 200

	local content = modal:createContent()
	content.title = "Profile"
	content.icon = "😛"
	content.node = profileNode

	local requests = {}

	profileNode.onRemove = function()
		for _, req in ipairs(requests) do
			req:Cancel()
		end
		requests = {}
	end

	local username
	local userID
	local isLocal = _config.isLocal
	if isLocal then
		username = Player.Username
		userID = Player.UserID
	else
		username = _config.username
		userID = _config.userID
	end

	if userID == nil then
		error("profile.create called without a userID", 2)
	end

	-- avatarNode
	local avatarNode = uiAvatar:get(username, nil, nil, ui)
	if DEBUG then
		avatarNode.color = DEBUG_FRAME_COLOR
	end
	avatarNode:setParent(profileNode)

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

	local createColorpickerNode = function(config)
		local node = ui:createFrame(Color(0, 0, 0, 0))
		if DEBUG then
			node.Color = DEBUG_FRAME_COLOR
		end

		local targetLabel = ui:createText(config.title, theme.textColor)
		targetLabel:setParent(node)

		local picker =
			colorpicker:create({ closeBtnIcon = "✅", uikit = ui, transparency = false, colorPreview = false })
		picker:setColor(config.color or Color(255, 0, 0))
		picker:setParent(node)

		picker.didClose = function(self)
			if config.onDone then
				config.onDone(self:getColor())
			end
		end

		picker.didPickColor = function(_, color)
			if config.onPick then
				config.onPick(color)
			end
		end

		node.refresh = function(self)
			local padding = theme.padding

			self.Width = math.min(EDIT_FACE_CONTENT_MAX_WIDTH, self.Width)

			local heigthWithoutPicker = targetLabel.Height + padding
			local heightAvailableForPicker = self.Height - heigthWithoutPicker

			local pickerMaxSize = math.min(self.Width, heightAvailableForPicker)
			picker:setMaxSize(pickerMaxSize, pickerMaxSize)

			self.Height = heigthWithoutPicker + picker.Height

			self.Width = math.max(picker.Width, targetLabel.Width)

			targetLabel.pos.X = self.Width * 0.5 - targetLabel.Width * 0.5
			targetLabel.pos.Y = self.Height - targetLabel.Height

			picker.pos.X = self.Width * 0.5 - picker.Width * 0.5
			picker.pos.Y = 0
		end

		return node
	end

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

		local node = ui:createFrame(Color(0, 0, 0, 0))
		if DEBUG then
			node.Color = DEBUG_FRAME_COLOR
		end

		local usernameText = ui:createText(username, Color.White, "big")
		usernameText:setParent(node)

		local bioText = ui:createText(userInfo.bio, Color.White, "small")
		bioText:setParent(node)

		local socialBtns = {}
		for _, config in ipairs(socialBtnsConfig) do
			local btn = ui:createButton("", { textSize = "small" })
			btn:setParent(node)
			btn:hide()
			socialBtns[config.key] = btn
		end

		local reputation = ui:createText("🏆 0", Color.White)
		reputation:setParent(node)

		local friends = ui:createText("🙂 0", Color.White)
		friends:setParent(node)

		local created = ui:createText("📰 ", Color.White)
		created:setParent(node)

		node.parentDidResize = function(self)
			self:refresh()
		end

		node.refresh = function(self)
			local padding = theme.padding
			local totalHeight
			local totalWidth = math.min(CONTENT_MAX_WIDTH, self.Width)

			self.Width = math.min(CONTENT_MAX_WIDTH, self.Width)

			local listVisibleSocialButtons = {}
			for _, v in pairs(socialBtns) do
				if v:isVisible() then
					table.insert(listVisibleSocialButtons, v)
				end
			end

			totalHeight = usernameText.Height + padding + reputation.Height

			if bioText.Text ~= "" then
				totalHeight = totalHeight + bioText.Height + padding
				bioText.object.MaxWidth = self.Width
			end

			if #listVisibleSocialButtons > 0 then
				local btnListHeight = math.ceil(#listVisibleSocialButtons / 2) * (socialBtns.tiktok.Height + padding)
				totalHeight = totalHeight + btnListHeight + padding
			end

			self.Height = totalHeight

			local cursorY = self.Height

			-- Place top block (username + bio)
			usernameText.pos = { self.Width * 0.5 - usernameText.Width * 0.5, cursorY - usernameText.Height }
			cursorY = usernameText.pos.Y
			totalWidth = math.max(totalWidth, usernameText.Width)

			if bioText.Text ~= "" then
				bioText.pos = { self.Width * 0.5 - bioText.Width * 0.5, cursorY - bioText.Height - padding }
				cursorY = bioText.pos.Y
				totalWidth = math.max(totalWidth, bioText.Width)
			end

			-- Place middle block (socials)
			if #listVisibleSocialButtons > 0 then
				for i = 1, #listVisibleSocialButtons, 2 do -- iterate 2 by 2 to place 2 buttons on the same line
					local btn1 = listVisibleSocialButtons[i]
					local btn2 = listVisibleSocialButtons[i + 1]

					cursorY = cursorY - btn1.Height - padding

					if not btn2 then
						btn1.pos = { self.Width * 0.5 - btn1.Width * 0.5, cursorY }
						totalWidth = math.max(totalWidth, btn1.Width)
					else
						local fullwidth = btn1.Width + btn2.Width + padding
						btn1.pos = { self.Width * 0.5 - fullwidth * 0.5, cursorY }
						btn2.pos = { self.Width * 0.5 + fullwidth * 0.5 - btn2.Width, cursorY }
						totalWidth = math.max(totalWidth, fullwidth)
					end
				end
			end

			-- Place bottom block (stats)
			cursorY = cursorY - reputation.Height - padding
			local bottomLineWidth = reputation.Width + padding * 3 + friends.Width + padding * 3 + created.Width
			totalWidth = math.max(totalWidth, bottomLineWidth)

			reputation.pos = { self.Width * 0.5 - bottomLineWidth * 0.5, cursorY }
			friends.pos = { reputation.pos.X + reputation.Width + padding * 3, cursorY }
			created.pos = { friends.pos.X + friends.Width + padding * 3, cursorY }

			self.Width = totalWidth
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

			bioText.Text = userInfo.bio or ""

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
		end

		return node
	end

	local createEditInfoNode = function()
		local node = ui:createFrame(Color(0, 0, 0, 0))
		node.type = "EditInfoNode"
		if DEBUG then
			node.Color = DEBUG_FRAME_COLOR
		end

		local bioTitle = ui:createText("✏️ Bio", theme.textColor)
		bioTitle:setParent(node)

		-- temporary button
		local bioBtn = ui:createButton("Edit Bio")
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
			api:patchUserInfo({ discord = userInfo.discord }, function(err)
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
			api:patchUserInfo({ tiktok = userInfo.tiktok }, function(err)
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
			api:patchUserInfo({ x = userInfo.x }, function(err)
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
			api:patchUserInfo({ github = userInfo.github }, function(err)
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

			self.Width = math.min(EDIT_INFO_CONTENT_MAX_WIDTH, self.Width)

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

	local createEditFaceNode = function()
		local node = ui:createFrame(Color(0, 0, 0, 0))
		if DEBUG then
			node.Color = DEBUG_FRAME_COLOR
		end

		local noseShapeButton = ui:createButton("shape")
		local nosePickerButton = ui:createButton("🎨")
		nosePickerButton:setColor(avatar:getNoseColor(Player))

		local mouthShapeButton = ui:createButton("shape")
		local mouthPickerButton = ui:createButton("🎨")
		mouthPickerButton:setColor(avatar:getMouthColor(Player))

		local skinLabel = ui:createText("👤 Skin", theme.textColor)
		skinLabel:setParent(node)

		local skinButtons = {}
		for _, colors in ipairs(avatar.skinColors) do
			local btn = ui:createButton("")
			btn:setParent(node)
			btn:setColor(colors.skin1)
			btn.onRelease = function()
				local data = {}
				data.skinColor = { r = colors.skin1.R, g = colors.skin1.G, b = colors.skin1.B }
				data.skinColor2 = { r = colors.skin2.R, g = colors.skin2.G, b = colors.skin2.B }
				data.noseColor = { r = colors.nose.R, g = colors.nose.G, b = colors.nose.B }
				data.mouthColor = { r = colors.mouth.R, g = colors.mouth.G, b = colors.mouth.B }
				api:updateAvatar(data, function(err, _)
					if err then
						print("❌", err)
					end
				end)
				-- background request, not updating profile UI
				-- table.insert(requests, req)

				-- apply colors to in-game avatar
				avatar:setSkinColor(Player, colors.skin1, colors.skin2, colors.nose, colors.mouth)

				-- apply colors to avatar preview
				uiAvatar:setSkinColor(avatarNode, colors.skin1, colors.skin2, colors.nose, colors.mouth)

				-- update buttons' color
				nosePickerButton:setColor(colors.nose)
				mouthPickerButton:setColor(colors.mouth)

				LocalEvent:Send(LocalEvent.Name.LocalAvatarUpdate, System, { skinColors = colors })
			end
			table.insert(skinButtons, btn)
		end

		local eyesLabel = ui:createText("👁️ Eyes", theme.textColor)
		eyesLabel:setParent(node)

		local eyesPickerButton = ui:createButton("🎨")
		eyesPickerButton:setColor(avatar:getEyesColor(Player))

		local saveEyesColorTimer
		local _saveEyesColor = function(color)
			local data = {}
			data.eyesColor = { r = color.R, g = color.G, b = color.B }
			api:updateAvatar(data, function(err, _)
				if err then
					print("❌", err)
				end
			end)
			-- background request, not updating profile UI
			-- table.insert(requests, req)
		end

		local saveEyesColor = function(color, config)
			LocalEvent:Send(LocalEvent.Name.LocalAvatarUpdate, System, { eyesColor = color })

			if saveEyesColorTimer ~= nil then
				saveEyesColorTimer:Cancel()
				saveEyesColorTimer = nil
			end
			if config.delay ~= nil then
				saveEyesColorTimer = Timer(1.0, function()
					_saveEyesColor(color)
				end)
			else
				_saveEyesColor(color)
			end
		end

		local eyesButtons = {}
		for _, color in ipairs(avatar.eyesColors) do
			local btn = ui:createButton("")
			btn:setParent(node)
			btn:setColor(color)
			btn.onRelease = function()
				uiAvatar:setEyesColor(avatarNode, color)
				avatar:setEyesColor(Player, color)
				saveEyesColor(color)

				-- TODO: apply colors to small head icon (screen top left corner)

				-- update buttons' color
				eyesPickerButton:setColor(color)
			end
			table.insert(eyesButtons, btn)
		end

		eyesPickerButton:setParent(node)
		eyesPickerButton:setColor(avatar:getEyesColor(Player))
		eyesPickerButton.onRelease = function(_)
			functions.setActiveNode(createColorpickerNode({
				color = avatar:getEyesColor(Player),
				title = "👁️ Eyes",
				onDone = function(color)
					saveEyesColor(color)
					functions.setActiveNode(functions.createEditFaceNode())
				end,
				onPick = function(color)
					uiAvatar:setEyesColor(avatarNode, color)
					avatar:setEyesColor(Player, color)
					saveEyesColor(color, { delay = 1.0 })
				end,
			}))
		end

		local noseLabel = ui:createText("👃 Nose", theme.textColor)
		noseLabel:setParent(node)

		noseShapeButton:setParent(node)
		noseShapeButton:disable()

		local saveNoseColorTimer
		local _saveNoseColor = function(color)
			local data = {}
			data.noseColor = { r = color.R, g = color.G, b = color.B }
			api:updateAvatar(data, function(err, _)
				if err then
					print("❌", err)
				end
			end)
			-- background request, not updating profile UI
			-- table.insert(requests, req)
		end

		local saveNoseColor = function(color, config)
			LocalEvent:Send(LocalEvent.Name.LocalAvatarUpdate, System, { noseColor = color })

			if saveNoseColorTimer ~= nil then
				saveNoseColorTimer:Cancel()
				saveNoseColorTimer = nil
			end
			if config.delay ~= nil then
				saveNoseColorTimer = Timer(1.0, function()
					_saveNoseColor(color)
				end)
			else
				_saveNoseColor(color)
			end
		end

		nosePickerButton:setParent(node)
		nosePickerButton:setColor(avatar:getNoseColor(Player))
		nosePickerButton.onRelease = function(_)
			functions.setActiveNode(createColorpickerNode({
				color = avatar:getNoseColor(Player),
				title = "👃 Nose",
				onDone = function(color)
					saveNoseColor(color)
					functions.setActiveNode(functions.createEditFaceNode())
				end,
				onPick = function(color)
					uiAvatar:setNoseColor(avatarNode, color)
					avatar:setNoseColor(Player, color)
					saveNoseColor(color, { delay = 1.0 })
				end,
			}))
		end

		local mouthLabel = ui:createText("👄 Mouth", theme.textColor)
		mouthLabel:setParent(node)

		mouthShapeButton:setParent(node)
		mouthShapeButton:disable()

		local saveMouthColorTimer
		local _saveMouthColor = function(color)
			local data = {}
			data.mouthColor = { r = color.R, g = color.G, b = color.B }
			api:updateAvatar(data, function(err, _)
				if err then
					print("❌", err)
				end
			end)
			-- background request, not updating profile UI
			-- table.insert(requests, req)
		end

		local saveMouthColor = function(color, config)
			LocalEvent:Send(LocalEvent.Name.LocalAvatarUpdate, System, { mouthColor = color })

			if saveMouthColorTimer ~= nil then
				saveMouthColorTimer:Cancel()
				saveMouthColorTimer = nil
			end
			if config.delay ~= nil then
				saveMouthColorTimer = Timer(1.0, function()
					_saveMouthColor(color)
				end)
			else
				_saveMouthColor(color)
			end
		end

		mouthPickerButton:setParent(node)
		mouthPickerButton:setColor(avatar:getMouthColor(Player))
		mouthPickerButton.onRelease = function(_)
			functions.setActiveNode(createColorpickerNode({
				color = avatar:getMouthColor(Player),
				title = "👄 Mouth",
				onDone = function(color)
					saveMouthColor(color)
					functions.setActiveNode(functions.createEditFaceNode())
				end,
				onPick = function(color)
					uiAvatar:setMouthColor(avatarNode, color)
					avatar:setMouthColor(Player, color)
					saveMouthColor(color, { delay = 1.0 })
				end,
			}))
		end

		node.refresh = function(self)
			local padding = theme.padding

			self.Width = math.min(EDIT_FACE_CONTENT_MAX_WIDTH, self.Width)

			local lineHeight = skinButtons[1].Height
			self.Height = (lineHeight + padding) * 4 - padding

			mouthLabel.pos = { 0, lineHeight * 0.5 - mouthLabel.Height * 0.5 }
			noseLabel.pos = { 0, (lineHeight + padding) * 1 + lineHeight * 0.5 - noseLabel.Height * 0.5 }
			eyesLabel.pos = { 0, (lineHeight + padding) * 2 + lineHeight * 0.5 - noseLabel.Height * 0.5 }
			skinLabel.pos = { 0, (lineHeight + padding) * 3 + lineHeight * 0.5 - noseLabel.Height * 0.5 }

			-- Skin

			local largestLabelWidth = math.max(mouthLabel.Width, noseLabel.Width, eyesLabel.Width, skinLabel.Width)
			local availableWidth = self.Width
			local widthWithoutLabels = availableWidth - largestLabelWidth
			local skinBtnWidth = (widthWithoutLabels / #skinButtons) - padding

			for i, btn in ipairs(skinButtons) do
				btn.Width = skinBtnWidth
				btn.pos = {
					largestLabelWidth + padding + (skinBtnWidth + padding) * (i - 1),
					(lineHeight + padding) * 3,
				}
			end

			-- Eye

			local widthWithoutLabelsAndBtn = widthWithoutLabels - padding - eyesPickerButton.Width
			local eyeBtnWidth = widthWithoutLabelsAndBtn / #eyesButtons - padding

			for i, btn in ipairs(eyesButtons) do
				btn.Width = eyeBtnWidth
				btn.pos = {
					largestLabelWidth + padding + (eyeBtnWidth + padding) * (i - 1),
					(lineHeight + padding) * 2,
				}
			end

			eyesPickerButton.pos = {
				largestLabelWidth + padding + (eyeBtnWidth + padding) * #eyesButtons,
				(lineHeight + padding) * 2,
			}

			-- Nose

			noseShapeButton.Width = widthWithoutLabels - theme.padding * 2 - nosePickerButton.Width
			noseShapeButton.pos = { largestLabelWidth + theme.padding, (lineHeight + theme.padding) * 1, 0 }

			nosePickerButton.pos = noseShapeButton.pos + { noseShapeButton.Width + theme.padding, 0, 0 }

			-- Mouth

			mouthShapeButton.Width = widthWithoutLabels - theme.padding * 2 - mouthPickerButton.Width
			mouthShapeButton.pos = { largestLabelWidth + theme.padding, 0, 0 }

			mouthPickerButton.pos = mouthShapeButton.pos + { mouthShapeButton.Width + theme.padding, 0, 0 }
		end

		return node
	end
	functions.createEditFaceNode = createEditFaceNode

	local createEditOutfitNode = function()
		local node = ui:createFrame(Color(0, 0, 0, 0))
		if DEBUG then
			node.Color = DEBUG_FRAME_COLOR
		end

		local selectedCategory = "hair"

		local grid = itemgrid:create({ uikit = ui, searchbar = true, categories = { selectedCategory } })
		grid:setParent(node)

		local tabs = {
			{
				label = "🙂 Hair",
				short = "🙂",
				action = function()
					selectedCategory = "hair"
					grid:setCategories({ selectedCategory })
				end,
			},
			{
				label = "👕 Jacket",
				short = "👕",
				action = function()
					selectedCategory = "jacket"
					grid:setCategories({ selectedCategory })
				end,
			},
			{
				label = "👖 Pants",
				short = "👖",
				action = function()
					selectedCategory = "pants"
					grid:setCategories({ selectedCategory })
				end,
			},
			{
				label = "👞 Boots",
				short = "👞",
				action = function()
					selectedCategory = "boots"
					grid:setCategories({ selectedCategory })
				end,
			},
		}

		content.tabs = tabs

		local wearableRequest
		grid.onOpen = function(_, cell)
			if not cell.repo or not cell.name then
				return
			end
			local category = selectedCategory
			local fullname = cell.repo .. "." .. cell.name

			if wearableRequest ~= nil then
				wearableRequest:Cancel()
				wearableRequest = nil
			end
			wearableRequest = equipments.load(category, fullname, Player, false, false, function(eq)
				wearableRequest = nil
				if eq == nil then
					print("Error: invalid item.")
					return
				end

				-- update avatar preview
				if avatarNode.refresh then
					avatarNode:refresh()
				end

				-- send API request to update user avatar
				local data = {}
				data[category] = fullname
				api:updateAvatar(data, function(err, _)
					if err then
						print("❌", err)
					else
						if category == "hair" then
							LocalEvent:Send(LocalEvent.Name.LocalAvatarUpdate, System, { outfit = true })
						end
					end
				end)
				-- background request, not updating profile UI
				-- table.insert(requests, req)
			end)
			if wearableRequest ~= nil then
				table.insert(requests, wearableRequest)
			end
		end

		local pages = pages:create(ui)
		pages:setParent(node)

		grid.onPaginationChange = function(page, nbPages)
			pages:setNbPages(nbPages)
			pages:setPage(page)
		end

		pages:setPageDidChange(function(page)
			grid:setPage(page)
		end)

		node.refresh = function(self)
			local padding = theme.padding

			self.Width = math.min(800, self.Width)

			grid.Width = self.Width
			grid.Height = self.Height - pages.Height - padding

			grid:refresh()

			self.Width = grid.Width
			self.Height = grid.Height + pages.Height + padding

			grid.pos.Y = self.Height - grid.Height
			grid.pos.X = 0

			pages.pos.Y = 0
			pages.pos.X = self.Width * 0.5 - pages.Width * 0.5
		end

		return node
	end

	-- 2 areas within node, one to display the avatar and the other for the rest
	-- (text info, wearable gallery in editor mode, etc.)

	infoNode = createInfoNode()
	infoNode:setParent(profileNode)
	infoNode:hide()

	local editBtn = nil
	local editInfoBtn = nil
	local editFaceBtn = nil
	local editOutfitBtn = nil

	local toggleEditOptions = function(btn)
		if btn.Text == nil or editInfoBtn.show == nil or editFaceBtn.show == nil or editOutfitBtn.show == nil then
			return
		end

		if btn.Text == "✅ Done" then
			btn.Text = "✏️ Edit"

			editInfoBtn:hide()
			editInfoBtn:disable()
			editInfoBtn:unselect()

			editFaceBtn:hide()
			editFaceBtn:disable()
			editFaceBtn:unselect()

			editOutfitBtn:hide()
			editOutfitBtn:disable()
			editOutfitBtn:unselect()

			infoNode:setUserInfo()

			content.tabs = nil
			functions.setActiveNode(infoNode)
		else
			btn.Text = "✅ Done"

			editInfoBtn:show()
			editInfoBtn:enable()

			editFaceBtn:show()
			editFaceBtn:enable()

			editOutfitBtn:show()
			editOutfitBtn:enable()

			-- trigger press on editInfoBtn
			editInfoBtnOnReleaseCallback()
		end
	end

	editInfoBtnOnReleaseCallback = function(_)
		content.tabs = nil
		functions.setActiveNode(createEditInfoNode())
		editInfoBtn:select()
		editFaceBtn:unselect()
		editOutfitBtn:unselect()
	end

	editFaceBtnOnReleaseCallback = function(_)
		content.tabs = nil
		functions.setActiveNode(createEditFaceNode())
		editInfoBtn:unselect()
		editFaceBtn:select()
		editOutfitBtn:unselect()
	end

	editOutfitBtnOnReleaseCallback = function(_)
		functions.setActiveNode(createEditOutfitNode())
		editInfoBtn:unselect()
		editFaceBtn:unselect()
		editOutfitBtn:select()
	end

	-- --------------------------------------------------
	-- pictureBtn
	-- --------------------------------------------------

	-- local pictureBtn = ui:createButton("📸")
	-- pictureBtn:setParent(profileNode)

	-- pictureBtn.onRelease = function()
	-- 	local as = AudioSource()
	-- 	as.Sound = "gun_reload_1"
	-- 	as:SetParent(World)
	-- 	as.Volume = 0.5
	-- 	as.Pitch = 1
	-- 	as.Spatialized = false
	-- 	as:Play()

	-- 	Timer(1, function()
	-- 		as:RemoveFromParent() as=nil
	-- 	end)

	-- 	local whiteBg = ui:createFrame(Color.White)
	-- 	whiteBg.Width = Screen.Width
	-- 	whiteBg.Height = Screen.Height

	-- 	Timer(0.05, function()
	-- 		whiteBg:remove()
	-- 		whiteBg = nil
	-- 		ui:hide()
	-- 		Timer(0.2, function()
	-- 			print("avatarNode.body.shape:", avatarNode.body.shape)
	-- 			ui:show()
	-- 		end)
	-- 	end)
	-- end

	local avatarRot = Number3(0, math.pi, 0)
	local dragListener = nil
	local avatarLoadedListener = nil

	if isLocal then
		editBtn = ui:createButton("✏️ Edit")
		editBtn:disable()

		editInfoBtn = ui:createButton("✏️")
		editInfoBtn:disable()
		editInfoBtn:hide()
		editInfoBtn.onRelease = editInfoBtnOnReleaseCallback

		editFaceBtn = ui:createButton("🙂")
		editFaceBtn:disable()
		editFaceBtn:hide()
		editFaceBtn.onRelease = editFaceBtnOnReleaseCallback

		editOutfitBtn = ui:createButton("👤")
		editOutfitBtn:disable()
		editOutfitBtn:hide()
		editOutfitBtn.onRelease = editOutfitBtnOnReleaseCallback

		local coinsBtn = ui:createButton("💰 …", { sound = "coin_1" })
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
		content.bottomLeft = { editBtn, editInfoBtn, editFaceBtn, editOutfitBtn }
	else
		local showCreationsBtn = ui:createButton("✨ Show Creations")
		showCreationsBtn.onRelease = function()
			require("menu"):ShowAlert({ message = "Coming soon!" }, System)
		end

		if Player.Username == "guest" then
			-- this case won't happen anymore when all players will have a username
			content.bottomCenter = { showCreationsBtn }
		else
			local addFriendBtn = ui:createButton("...")
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
			local req = api:getFriends(function(ok, friends, _)
				if not ok then
					return
				end

				alreadyFriends = false
				for _, friendID in pairs(friends) do
					if friendID == userID then
						alreadyFriends = true
						break
					end
				end
				updateFriendButton()
			end)
			table.insert(requests, req)

			-- check if a request was already sent
			req = api:getSentFriendRequests(function(ok, requests, _)
				if not ok then
					return
				end

				requestSent = false
				for _, uID in pairs(requests) do
					if uID == userID then
						requestSent = true
						break
					end
				end
				updateFriendButton()
			end)
			table.insert(requests, req)
		end
	end

	functions.refresh = function()
		if activeNode == nil then
			return
		end

		local landscape = Screen.Width > Screen.Height

		local totalWidth = profileNode.Width
		local totalHeight = profileNode.Height

		-- compute minimum room for
		local roomForAvatar

		if landscape then
			roomForAvatar = math.min(AVATAR_MAX_SIZE, totalWidth * 0.25)
			roomForAvatar = math.max(roomForAvatar, AVATAR_MIN_SIZE)
			activeNode.Width = totalWidth - roomForAvatar - ACTIVE_NODE_MARGIN * 2
			activeNode.Height = totalHeight - ACTIVE_NODE_MARGIN * 2
		else
			roomForAvatar = math.min(AVATAR_MAX_SIZE, totalHeight * 0.25)
			roomForAvatar = math.max(roomForAvatar, AVATAR_MIN_SIZE)
			activeNode.Width = totalWidth - ACTIVE_NODE_MARGIN * 2
			activeNode.Height = totalHeight - roomForAvatar - ACTIVE_NODE_MARGIN * 2
		end

		if activeNode.refresh then
			activeNode:refresh()
		end -- refresh may shrink content

		local activeNodeWidthWithMargin = activeNode.Width + ACTIVE_NODE_MARGIN * 2
		local activeNodeHeightWithMargin = activeNode.Height + ACTIVE_NODE_MARGIN * 2

		local avatarSizeInLandscape =
			math.min(profileNode.Width - activeNodeWidthWithMargin, profileNode.Height, AVATAR_MAX_SIZE)
		local avatarSizeInPortrait =
			math.min(profileNode.Height - activeNodeHeightWithMargin, profileNode.Width, AVATAR_MAX_SIZE)

		-- no matter what real orientation is, pick the layout giving
		-- that's allowing more space for the avatar.
		if avatarSizeInLandscape >= avatarSizeInPortrait then -- go landscape
			avatarNode.Width = avatarSizeInLandscape
			totalHeight = math.max(activeNodeHeightWithMargin, avatarNode.Height)
			totalWidth = activeNodeWidthWithMargin + avatarNode.Width

			preferredLayout = "landscape"
		else
			avatarNode.Width = avatarSizeInPortrait
			totalHeight = activeNodeHeightWithMargin + avatarNode.Height
			totalWidth = math.max(activeNodeWidthWithMargin, avatarNode.Width)

			preferredLayout = "portrait"
		end

		-- pictureBtn is in the bottom-right corner of avatar preview
		-- pictureBtn.pos = { avatarNode.pos.X + avatarNode.Width - pictureBtn.Width, 0 }

		return totalWidth, totalHeight
	end

	profileNode.parentDidResize = function(self)
		if activeNode == nil or avatarNode == nil then
			return
		end

		if preferredLayout == "landscape" then
			if avatarLandscapeRight then
				activeNode.pos = { ACTIVE_NODE_MARGIN, self.Height * 0.5 - activeNode.Height * 0.5 }
				avatarNode.pos = { self.Width - avatarNode.Width, self.Height * 0.5 - avatarNode.Height * 0.5 }
			else
				activeNode.pos =
					{ self.Width - activeNode.Width - ACTIVE_NODE_MARGIN, self.Height * 0.5 - activeNode.Height * 0.5 }
				avatarNode.pos = { 0, self.Height * 0.5 - activeNode.Height * 0.5 }
			end
		else
			if avatarPortraitTop then
				avatarNode.pos = { self.Width * 0.5 - avatarNode.Width * 0.5, self.Height - avatarNode.Height }
				activeNode.pos = { self.Width * 0.5 - activeNode.Width * 0.5, ACTIVE_NODE_MARGIN }
			else
				avatarNode.pos = { self.Width * 0.5 - avatarNode.Width * 0.5, 0 }
				activeNode.pos =
					{ self.Width * 0.5 - activeNode.Width * 0.5, self.Height - activeNode.Height - ACTIVE_NODE_MARGIN }
			end
		end
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
		activeNode:setParent(profileNode)
		activeNode:show()

		-- force layout refresh
		functions.refresh()

		content:refreshModal()
	end

	-- width is current modal width, before eventual resize
	content.idealReducedContentSize = function(content, width, height)
		content.Width = width
		content.Height = height
		local w, h = functions.refresh()
		return Number2(w, h)
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
			end
		end)

		local fillUserInfo = function(ok, usr, _)
			if not ok then
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
