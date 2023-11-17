local menu = {}

ui = require("uikit").systemUI(System)
uiAvatar = require("ui_avatar")
avatarModule = require("avatar")
modal = require("modal")
theme = require("uitheme").current
ease = require("ease")
friends = require("friends")
settings = require("settings")
worlds = require("worlds")
creations = require("creations")
api = require("system_api", System)
alert = require("alert")
sys_notifications = require("system_notifications", System)
codes = require("inputcodes")

---------------------------
-- CONSTANTS
---------------------------

MODAL_MARGIN = theme.paddingBig -- space around modals
BACKGROUND_COLOR_ON = Color(0, 0, 0, 200)
BACKGROUND_COLOR_OFF = Color(0, 0, 0, 0)
ALERT_BACKGROUND_COLOR_ON = Color(0, 0, 0, 200)
ALERT_BACKGROUND_COLOR_OFF = Color(0, 0, 0, 0)
CHAT_SCREEN_WIDTH_RATIO = 0.3
CHAT_MAX_WIDTH = 600
CHAT_MIN_WIDTH = 250
CHAT_SCREEN_HEIGHT_RATIO = 0.25
CHAT_MIN_HEIGHT = 160
CHAT_MAX_HEIGHT = 400

---------------------------
-- VARS
---------------------------

-- NOTE: this may not be necessary, as we can access information through System table
accountInfo = nil -- stores account information
wasActive = false
modalWasShown = false
alertWasShown = false
cppMenuIsActive = false
chatDisplayed = false -- when false, only a mini chat console is displayed in the top bar

---------------------------
-- MODALS
---------------------------

activeModal = nil
activeModalKey = nil

didBecomeActiveCallbacks = {}
didResignActiveCallbacks = {}

MODAL_KEYS = {
	PROFILE = 1,
	CHAT = 2,
	FRIENDS = 3,
	SETTINGS = 4,
	COINS = 5,
	WORLDS = 6,
	BUILD = 7,
	MARKETPLACE = 8,
	CUBZH_MENU = 9,
}

function maxModalWidth()
	local computed = Screen.Width - Screen.SafeArea.Left - Screen.SafeArea.Right - MODAL_MARGIN * 2
	local max = 1400
	local w = math.min(max, computed)
	return w
end

function maxModalHeight()
	return Screen.Height - Screen.SafeArea.Bottom - topBar.Height - MODAL_MARGIN * 2
end

function updateModalPosition(modal, forceBounce)
	local vMin = Screen.SafeArea.Bottom + MODAL_MARGIN
	local vMax = Screen.Height - topBar.Height - MODAL_MARGIN

	local vCenter = vMin + (vMax - vMin) * 0.5

	local p = Number3(Screen.Width * 0.5 - modal.Width * 0.5, vCenter - modal.Height * 0.5, 0)

	if not modal.updatedPosition or forceBounce then
		modal.LocalPosition = p - { 0, 100, 0 }
		modal.updatedPosition = true
		ease:cancel(modal) -- cancel modal ease animations if any
		ease:outBack(modal, 0.22).LocalPosition = p
	else
		modal.LocalPosition = p
	end
end

function closeModal()
	if activeModal ~= nil then
		activeModal:close()
		activeModal = nil
	end
end

-- pops active modal content
-- closing modal when reaching root content
function popModal()
	if activeModal == nil then
		return
	end
	if #activeModal.contentStack > 1 then
		activeModal:pop()
	else
		closeModal()
	end
end

function showModal(key)
	if not key then
		return
	end

	if key == activeModalKey then
		updateModalPosition(activeModal, true) -- make it bounce
		return
	end

	if activeModal ~= nil then
		activeModal:close()
		activeModal = nil
		activeModalKey = nil
	end

	if key == MODAL_KEYS.PROFILE then
		local content = require("profile"):create({ uikit = ui })
		activeModal = modal:create(content, maxModalWidth, maxModalHeight, updateModalPosition, ui)
	elseif key == MODAL_KEYS.CHAT then
		local inputText = ""
		if console then
			inputText = console:getText()
		end

		local content = require("chat"):createModalContent({ uikit = ui, inputText = inputText })
		activeModal = modal:create(content, maxModalWidth, maxModalHeight, updateModalPosition, ui)
	elseif key == MODAL_KEYS.FRIENDS then
		activeModal = friends:create(maxModalWidth, maxModalHeight, updateModalPosition, ui)
	elseif key == MODAL_KEYS.MARKETPLACE then
		local content = require("gallery"):createModalContent({ uikit = ui })
		activeModal = modal:create(content, maxModalWidth, maxModalHeight, updateModalPosition, ui)
	elseif key == MODAL_KEYS.CUBZH_MENU then
		local content = getCubzhMenuModalContent()
		activeModal = modal:create(content, maxModalWidth, maxModalHeight, updateModalPosition, ui)
	end

	if activeModal ~= nil then
		ui.unfocus() -- unfocuses node currently focused

		activeModal:setParent(background)

		System.PointerForceShown = true
		activeModalKey = key

		activeModal.didClose = function()
			activeModal = nil
			activeModalKey = nil
			System.PointerForceShown = false
			refreshChat()
			triggerCallbacks()
		end
	end

	refreshChat()
	triggerCallbacks()
end

function showAlert(config)
	if alertModal ~= nil then
		alertModal:bounce()
		return
	end

	alertModal = alert:create(config.message or "", { uikit = ui })
	alertModal:setParent(alertBackground)

	if config.positiveCallback then
		alertModal:setPositiveCallback(config.positiveLabel or "OK", config.positiveCallback)
	end
	if config.negativeCallback then
		alertModal:setNegativeCallback(config.negativeLabel or "No", config.negativeCallback)
	end
	if config.neutralCallback then
		alertModal:setNeutralCallback(config.neutralLabel or "...", config.neutralCallback)
	end

	alertModal.didClose = function()
		alertModal = nil
		triggerCallbacks()
	end

	triggerCallbacks()
end

function showLoading(text)
	if loadingModal ~= nil then
		loadingModal:setText(text)
		return
	end

	loadingModal = require("loading_modal"):create(text, { uikit = ui })
	loadingModal:setParent(alertBackground)

	loadingModal.didClose = function()
		loadingModal = nil
		triggerCallbacks()
	end

	triggerCallbacks()
end

function hideLoading()
	if loadingModal == nil then
		return
	end
	loadingModal:close()
	loadingModal = nil
	triggerCallbacks()
end

function parseVersion(versionStr)
	local maj, min, patch = versionStr:match("(%d+)%.(%d+)%.(%d+)")
	maj = math.floor(tonumber(maj))
	min = math.floor(tonumber(min))
	patch = math.floor(tonumber(patch))
	return maj, min, patch
end

blockedEvents = {}

function blockEvent(name)
	local listener = LocalEvent:Listen(name, function()
		return true
	end, { topPriority = true, system = System })
	table.insert(blockedEvents, listener)
end

function blockEvents()
	blockEvent(LocalEvent.Name.DirPad)
	blockEvent(LocalEvent.Name.AnalogPad)
end

function unblockEvents()
	for _, listener in ipairs(blockedEvents) do
		listener:Remove()
	end
	blockedEvents = {}
end

function triggerCallbacks()
	local isActive = menu:IsActive()

	if isActive ~= wasActive then
		wasActive = isActive
		if isActive then
			for _, callback in pairs(didBecomeActiveCallbacks) do
				callback()
			end
		else
			for _, callback in pairs(didResignActiveCallbacks) do
				callback()
			end
		end

		if isActive then
			blockEvents()
		else
			unblockEvents()
		end
	end

	local modalIsShown = activeModal ~= nil and not cppMenuIsActive

	if modalIsShown ~= modalWasShown then
		modalWasShown = modalIsShown
		ease:cancel(background)
		if modalIsShown then
			background.onPress = function() end -- blocker
			background.onRelease = function() end -- blocker
			ease:linear(background, 0.22).Color = BACKGROUND_COLOR_ON
		else
			background.onPress = nil
			background.onRelease = nil
			ease:linear(background, 0.22).Color = BACKGROUND_COLOR_OFF
		end
	end

	local alertIsSHown = (alertModal ~= nil or loadingModal ~= nil) and not cppMenuIsActive

	if alertIsSHown ~= alertWasShown then
		alertWasShown = alertIsSHown
		ease:cancel(alertBackground)
		if alertIsSHown then
			alertBackground.onPress = function() end -- blocker
			alertBackground.onRelease = function() end -- blocker
			ease:linear(alertBackground, 0.22).Color = ALERT_BACKGROUND_COLOR_ON
		else
			alertBackground.onPress = nil
			alertBackground.onRelease = nil
			ease:linear(alertBackground, 0.22).Color = ALERT_BACKGROUND_COLOR_OFF
		end
	end
end

function refreshDisplay()
	if cppMenuIsActive then
		if activeModal then
			activeModal:hide()
		end
		if loadingModal then
			loadingModal:hide()
		end
		if alertModal then
			alertModal:hide()
		end
		cubzhBtn:disable()
		chatBtn:disable()
		friendsBtn:disable()
		profileFrame:hide()
		if signupElements ~= nil then
			for _, e in ipairs(signupElements) do
				e:hide()
			end
		end
	else
		if activeModal then
			activeModal:show()
		end
		if loadingModal then
			loadingModal:show()
		end
		if alertModal then
			alertModal:show()
		end
		cubzhBtn:enable()
		chatBtn:enable()
		friendsBtn:enable()
		profileFrame:show()
		if signupElements ~= nil then
			for _, e in ipairs(signupElements) do
				e:show()
			end
		end
	end
end

---------------------------
-- BACKGROUND
---------------------------

background = ui:createFrame(BACKGROUND_COLOR_OFF)

background.parentDidResize = function(_)
	background.Width = Screen.Width
	background.Height = Screen.Height
end
background:parentDidResize()

alertBackground = ui:createFrame(ALERT_BACKGROUND_COLOR_OFF)
alertBackground.pos.Z = -950

alertBackground.parentDidResize = function(_)
	alertBackground.Width = Screen.Width
	alertBackground.Height = Screen.Height
end
alertBackground:parentDidResize()

---------------------------
-- TOP BAR
---------------------------

topBar = ui:createFrame(Color(0, 0, 0, 0.7))
topBar:setParent(background)

cubzhBtn = ui:createButton("⎔")
cubzhBtn:setColor(nil, Color(255, 255, 255, 254))
cubzhBtn:setColorPressed(nil, Color(255, 255, 255, 254))
cubzhBtn:setParent(topBar)
cubzhBtn.pos.Y = theme.paddingTiny

chatBtn = ui:createButton("💬", { shadow = false, borders = false })
-- chatBtn = ui:createButton("💬", {shadow = false})
-- chatBtn = ui:createButton("💬")
chatBtn:setColor(Color(0, 0, 0, 0))
chatBtn:setColorPressed(Color(0, 0, 0, 0))
chatBtn:setColorSelected(Color(0, 0, 0, 0))
chatBtn:setParent(topBar)

friendsBtn = ui:createButton("💛", { shadow = false, borders = false })
friendsBtn:setColor(Color(0, 0, 0, 0))
friendsBtn:setColorPressed(Color(0, 0, 0, 0))
friendsBtn:setColorSelected(Color(0, 0, 0, 0))
friendsBtn:setParent(topBar)

cubzhBtn.onRelease = function()
	showModal(MODAL_KEYS.CUBZH_MENU)
end

chatBtn.onRelease = function()
	if activeModal then
		showModal(MODAL_KEYS.CHAT)
	else
		chatDisplayed = not chatDisplayed
		refreshChat()
	end
end

friendsBtn.onRelease = function()
	showModal(MODAL_KEYS.FRIENDS)
end

profileFrame = ui:createFrame(Color.transparent)
profileFrame:setParent(topBar)

profileFrame.onRelease = function(_)
	showModal(MODAL_KEYS.PROFILE)
end

avatar = ui:createFrame(Color.transparent)
avatar:setParent(profileFrame)
avatar.pos.Y = theme.paddingTiny

username = ui:createText("", Color.White, "small")
username:setParent(profileFrame)

xp = nil
coins = nil

info = ui:createText(
	string.format("🏆 %s 💰 %s", xp and "" .. xp or "…", coins and "" .. coins or "…"),
	Color.White,
	"small"
)
info:setParent(profileFrame)

---------
-- CHAT
---------

function createTopBarChat()
	if topBarChat ~= nil then
		return -- already created
	end
	topBarChat = require("chat"):create({ uikit = ui, input = false, time = false, heads = false, maxMessages = 4 })
	topBarChat:setParent(topBar)
	if topBar.parentDidResize then
		topBar:parentDidResize()
	end
end

function removeTopBarChat()
	if topBarChat == nil then
		return -- nothing to remove
	end
	topBarChat:remove()
	topBarChat = nil
end

function createChat()
	if chat ~= nil then
		return -- chat already created
	end
	chat = ui:createFrame(Color(0, 0, 0, 0.3))
	chat:setParent(background)

	local btnChatFullscreen = ui:createButton("⇱", { textSize = "small", unfocuses = false })
	btnChatFullscreen.onRelease = function()
		showModal(MODAL_KEYS.CHAT)
	end
	btnChatFullscreen:setColor(Color(0, 0, 0, 0.5))
	btnChatFullscreen:hide()

	console = require("chat"):create({
		uikit = ui,
		time = false,
		onSubmitEmpty = function()
			hideChat()
		end,
		onFocus = function()
			chat.Color = Color(0, 0, 0, 0.5)
			btnChatFullscreen:show()
		end,
		onFocusLost = function()
			chat.Color = Color(0, 0, 0, 0.3)
			btnChatFullscreen:hide()
		end,
	})
	console.Width = 200
	console.Height = 500
	console:setParent(chat)
	btnChatFullscreen:setParent(chat)

	chat.parentDidResize = function()
		local w = Screen.Width * CHAT_SCREEN_WIDTH_RATIO
		w = math.min(w, CHAT_MAX_WIDTH)
		w = math.max(w, CHAT_MIN_WIDTH)
		chat.Width = w

		local h = Screen.Height * CHAT_SCREEN_HEIGHT_RATIO
		h = math.min(h, CHAT_MAX_HEIGHT)
		h = math.max(h, CHAT_MIN_HEIGHT)
		chat.Height = h

		console.Width = chat.Width - theme.paddingTiny * 2
		console.Height = chat.Height - theme.paddingTiny * 2

		console.pos = { theme.paddingTiny, theme.paddingTiny }
		chat.pos = { theme.padding, Screen.Height - Screen.SafeArea.Top - chat.Height - theme.padding }

		btnChatFullscreen.pos = { chat.Width + theme.paddingTiny, chat.Height - btnChatFullscreen.Height }
	end
	chat:parentDidResize()
end

function removeChat()
	if chat == nil then
		return -- nothing to remove
	end
	chat:remove()
	chat = nil
	console = nil
end

-- displayes chat as expected based on state
function refreshChat()
	if chatDisplayed and cppMenuIsActive == false then
		if activeModal then
			removeChat()
		else
			createChat()
		end
		removeTopBarChat()
	else
		removeChat()
		createTopBarChat()
	end
end

function showChat(input)
	if System.Authenticated == false then
		return
	end
	chatDisplayed = true
	refreshChat()
	if console then
		console:focus()
		if input ~= nil then
			console:setText(input)
		end
	end
end

function hideChat()
	chatDisplayed = false
	refreshChat()
end

refreshChat()

----------------------
-- CUBZH MENU CONTENT
----------------------

function getCubzhMenuModalContent()
	local content = modal:createContent()
	content.closeButton = true
	content.title = "Cubzh"
	content.icon = "⎔"

	local node = ui:createFrame()
	content.node = node

	local btnHome = ui:createButton("🏠 Home")
	btnHome:setParent(node)

	btnHome.onRelease = function()
		System.GoHome()
	end

	local btnLink = ui:createButton("📑 Server Link")
	btnLink:setParent(node)

	local btnLinkTimer

	btnLink.onRelease = function()
		if btnLinkTimer then
			btnLinkTimer:Cancel()
		end
		Dev:CopyToClipboard(Dev.ServerURL)
		btnLink.Text = "📋 Copied!"
		btnLinkTimer = Timer(1.5, function()
			if btnLink.Text then
				btnLink.Text = "📋 Server Link"
			end
			btnLinkTimer = nil
		end)
	end

	local btnWorlds = ui:createButton("🌎 Worlds", { textSize = "big" })
	btnWorlds:setColor(theme.colorExplore)
	btnWorlds:setParent(node)

	btnWorlds.onRelease = function()
		local modal = content:getModalIfContentIsActive()
		if modal ~= nil then
			modal:push(worlds:createModalContent({ uikit = ui }))
		end
	end

	local btnGallery = ui:createButton("🏗️ Gallery", { textSize = "default" })
	btnGallery:setParent(node)

	btnGallery.onRelease = function()
		local modal = content:getModalIfContentIsActive()
		if modal ~= nil then
			modal:push(require("gallery"):createModalContent({ uikit = ui }))
		end
	end

	local btnInventory = ui:createButton("🎒 Inventory", { textSize = "default" })
	btnInventory:setParent(node)

	btnInventory.onRelease = function()
		showAlert({ message = "Coming soon!" })
	end

	local btnMyItems = ui:createButton("⚔️ My Items", { textSize = "default" })
	btnMyItems:setParent(node)

	btnMyItems.onRelease = function()
		local modal = content:getModalIfContentIsActive()
		if modal ~= nil then
			local content = creations:createModalContent({ uikit = ui })
			content.tabs[1].selected = true
			content.tabs[1].action()
			modal:push(content)
		end
	end

	local btnMyWorlds = ui:createButton("🌎 My Worlds", { textSize = "default" })
	btnMyWorlds:setParent(node)

	btnMyWorlds.onRelease = function()
		local modal = content:getModalIfContentIsActive()
		if modal ~= nil then
			local content = creations:createModalContent({ uikit = ui })
			content.tabs[3].selected = true
			content.tabs[3].action()
			modal:push(content)
		end
	end

	local btnFriends = ui:createButton("💛 Friends")
	btnFriends:setParent(node)

	btnFriends.onRelease = function()
		showModal(MODAL_KEYS.FRIENDS)
	end

	local dev = System.LocalUserIsAuthor and System.ServerIsInDevMode
	local btnCode = ui:createButton(dev and "🤓 Edit Code" or "🤓 Read Code")
	btnCode:setParent(node)

	btnCode.onRelease = function()
		if dev then
			System.EditCode()
		else
			System.ReadCode()
		end
		closeModal()
	end

	local btnSettings = ui:createButton("⚙️ Settings")
	content.bottomRight = { btnSettings }

	btnSettings.onRelease = function()
		content
			:getModalIfContentIsActive()
			:push(settings:createModalContent({ clearCache = true, logout = true, uikit = ui }))
	end

	local btnHelp = ui:createButton("👾 Help!", { textSize = "small" })
	btnHelp:setParent(node)

	btnHelp.onRelease = function()
		URL:Open("https://discord.gg/cubzh")
	end

	local buttons = {
		{ btnHome, btnFriends },
		{ btnWorlds },
		{ btnGallery, btnInventory },
		{ btnMyItems, btnMyWorlds },
		{
			btnCode,
			btnLink,
		},
	}

	-- tmp hack: no link for this URL
	if Dev.ServerURL == "https://app.cu.bzh/?worldID=cubzh" then
		btnLink:disable()
	end

	local osName = Client.OSName
	if osName == "Windows" or osName == "macOS" then
		local btnTerminate = ui:createButton("Exit Cubzh", { textSize = "small" })
		btnTerminate:setColor(theme.colorNegative)
		-- btnTerminate:setParent(node)
		btnTerminate.onRelease = function()
			System:Terminate()
		end
		-- table.insert(buttons, btnTerminate)
		content.bottomLeft = { btnTerminate, btnHelp }
	else
		content.bottomLeft = { btnHelp }
	end

	content.idealReducedContentSize = function(_, width, _)
		local height = 0

		for i, row in ipairs(buttons) do
			local h = 0
			for _, btn in ipairs(row) do
				h = math.max(h, btn.Height)
			end
			row.height = h
			height = height + h + (i > 1 and theme.padding or 0)
		end

		local maxRowWidth = 0
		local widthBackup
		for i, row in ipairs(buttons) do
			local w = 0
			for _, btn in ipairs(row) do
				widthBackup = btn.Width
				btn.Width = nil
				w = w + btn.Width + (i > 1 and theme.padding or 0)
				btn.Width = widthBackup
			end
			maxRowWidth = math.max(maxRowWidth, w)
		end

		width = math.min(width, maxRowWidth)

		return Number2(width, height)
	end

	btnMyWorlds.parentDidResize = function(_)
		local width = node.Width

		for _, row in ipairs(buttons) do
			local h = 0
			for _, btn in ipairs(row) do
				h = math.max(h, btn.Height)
			end
			row.height = h
		end

		for _, row in ipairs(buttons) do
			local w = (width - theme.padding * (#row - 1)) / #row
			for _, btn in ipairs(row) do
				btn.Width = w
			end
		end

		local row
		local cursorY = 0
		local cursorX = 0
		for i = #buttons, 1, -1 do
			row = buttons[i]

			for _, btn in ipairs(row) do
				btn.pos = { cursorX, cursorY, 0 }
				cursorX = cursorX + btn.Width + theme.padding
			end

			cursorY = cursorY + row.height + theme.padding
			cursorX = 0
		end
	end

	content.didBecomeActive = function()
		btnMyWorlds:parentDidResize()
	end

	return content
end

topBar.parentDidResize = function(self)
	local padding = theme.paddingTiny

	-- Compute height of top bar
	local height = math.max(cubzhBtn.Height, username.Height + padding + info.Height)

	-- Adjust Cubzh button's height if the top bar height is larger
	cubzhBtn.Height = math.max(cubzhBtn.Height, height)
	-- Cubzh button must remain square
	cubzhBtn.Width = math.max(cubzhBtn.Height, cubzhBtn.Width)

	self.Width = Screen.Width
	self.Height = System.SafeAreaTop + padding * 2 + height
	self.pos.Y = Screen.Height - self.Height

	local topBarHeight = self.Height - System.SafeAreaTop

	cubzhBtn.pos.X = self.Width - Screen.SafeArea.Right - cubzhBtn.Width - padding

	-- PROFILE BUTTON

	avatar.Height = height

	profileFrame.Width = math.max(avatar.Width + padding + username.Width, avatar.Width + padding + info.Width)
	profileFrame.Height = height

	profileFrame.pos.X = Screen.SafeArea.Left + padding
	profileFrame.pos.Y = topBarHeight * 0.5 - profileFrame.Height * 0.5

	avatar.pos.X = 0
	avatar.pos.Y = 0

	username.pos.X = avatar.pos.X + avatar.Width + padding
	username.pos.Y = profileFrame.Height * 0.5 + padding * 0.5

	info.pos.X = avatar.pos.X + avatar.Width + padding
	info.pos.Y = profileFrame.Height * 0.5 - info.Height - padding * 0.5

	-- FRIENDS BUTTON

	friendsBtn.pos.X = profileFrame.pos.X + profileFrame.Width + padding
	friendsBtn.pos.Y = topBarHeight * 0.5 - friendsBtn.Height * 0.5

	-- CHAT BUTTON

	chatBtn.pos.X = friendsBtn.pos.X + friendsBtn.Width + padding
	chatBtn.pos.Y = topBarHeight * 0.5 - chatBtn.Height * 0.5

	-- CHAT MESSAGES

	if topBarChat then
		topBarChat.Height = topBarHeight - padding * 2
		topBarChat.pos.X = chatBtn.pos.X + chatBtn.Width + padding
		topBarChat.Width = (cubzhBtn.pos.X - topBarChat.pos.X) - padding * 2
		topBarChat.pos.Y = topBarHeight * 0.5 - topBarChat.Height * 0.5
	end
end
topBar:parentDidResize()

---------------------------
-- BOTTOM BAR
---------------------------

bottomBar = ui:createFrame(Color(255, 255, 255, 0.4))
bottomBar:setParent(background)

appVersion = ui:createText("CUBZH - " .. Client.AppVersion .. " (alpha) #" .. Client.BuildNumber, Color.Black, "small")
appVersion:setParent(bottomBar)

copyright = ui:createText("© Voxowl, Inc.", Color.Black, "small")
copyright:setParent(bottomBar)

bottomBar.parentDidResize = function(self)
	local padding = theme.padding

	self.Width = Screen.Width
	self.Height = Screen.SafeArea.Bottom + appVersion.Height + padding * 2

	appVersion.pos = { Screen.SafeArea.Left + padding, Screen.SafeArea.Bottom + padding, 0 }
	copyright.pos =
		{ Screen.Width - Screen.SafeArea.Right - copyright.Width - padding, Screen.SafeArea.Bottom + padding, 0 }
end
bottomBar:parentDidResize()

menu.AddDidBecomeActiveCallback = function(self, callback)
	if self ~= menu then
		error("Menu:AddDidBecomeActiveCallback should be called with `:`", 2)
	end
	if type(callback) ~= "function" then
		return
	end
	didBecomeActiveCallbacks[callback] = callback
end

menu.RemoveDidBecomeActiveCallback = function(self, callback)
	if self ~= menu then
		error("Menu:RemoveDidBecomeActiveCallback should be called with `:`", 2)
	end
	if type(callback) ~= "function" then
		return
	end
	didBecomeActiveCallbacks[callback] = nil
end

menu.AddDidResignActiveCallback = function(self, callback)
	if self ~= menu then
		error("Menu:AddWillResignActiveCallback should be called with `:`", 2)
	end
	if type(callback) ~= "function" then
		return
	end
	didResignActiveCallbacks[callback] = callback
end

menu.RemoveDidResignActiveCallback = function(self, callback)
	if self ~= menu then
		error("Menu:RemoveWillResignActiveCallback should be called with `:`", 2)
	end
	if type(callback) ~= "function" then
		return
	end
	didResignActiveCallbacks[callback] = nil
end

menu.IsActive = function(_)
	return activeModal ~= nil or alertModal ~= nil or loadingModal ~= nil or cppMenuIsActive
end

menu.Show = function(_)
	if System.Authenticated == false then
		return
	end

	if topBar:isVisible() == false then
		showTopBar()
	end

	cubzhBtn:onRelease()
end

authCompleteCallbacks = {}

function authCompleted()
	for _, callback in ipairs(authCompleteCallbacks) do
		callback()
	end
end

menu.OnAuthComplete = function(self, callback)
	if self ~= menu then
		return
	end
	if type(callback) ~= "function" then
		return
	end
	if System.Authenticated then
		-- already authenticated, trigger callback now!
		callback()
	else
		table.insert(authCompleteCallbacks, callback)
	end
end

-- system reserved exposed functions

menu.openURLWarning = function(_, url, system)
	if system ~= System then
		error("menu.openURLWarning requires System privileges")
	end
	local config = {
		message = "Taking you to " .. url .. ". Are you sure you want to go there?",
		positiveCallback = function()
			system:OpenURL(url)
		end,
		negativeCallback = function() end,
	}
	showAlert(config)
end

menu.loading = function(_, message, system)
	if system ~= System then
		error("menu:loading requires System privileges")
	end
	if type(message) ~= "string" then
		error("menu:loading(message, system) expects message to be a string")
	end
	showLoading(message)
end

menu.ShowAlert = function(_, config, system)
	if system ~= System then
		error("menu:ShowAlert requires System privileges")
	end
	showAlert(config)
end

local mt = {
	__index = function(_, k)
		if k == "Height" then
			return topBar.Height
		end
	end,
	__newindex = function()
		error("Menu is read-only", 2)
	end,
	__metatable = false,
	__tostring = function()
		return "[Menu]"
	end,
	__type = "Menu",
}

setmetatable(menu, mt)

LocalEvent:Listen(LocalEvent.Name.FailedToLoadWorld, function()
	hideLoading()
	-- TODO: display alert, could receive world info to retry
end)

local keysDown = {} -- captured keys

LocalEvent:Listen(LocalEvent.Name.KeyboardInput, function(_, keyCode, _, down)
	if titleScreen ~= nil and down then
		skipTitleScreen()
		keysDown[keyCode] = true
		return true
	end

	if not down then
		if keysDown[keyCode] then
			keysDown[keyCode] = nil
			return true -- capture
		else
			return -- return without catching
		end
	end

	-- key is down from here

	if
		keyCode ~= codes.ESCAPE
		and keyCode ~= codes.RETURN
		and keyCode ~= codes.NUMPAD_RETURN
		and keyCode ~= codes.SLASH
	then
		-- key not handled by menu
		return
	end

	if not keysDown[keyCode] then
		keysDown[keyCode] = true
	else
		return -- key already down, not considering repeated inputs
	end

	if down then
		if keyCode == codes.ESCAPE then
			if activeModal ~= nil then
				popModal()
			elseif console ~= nil and console:hasFocus() == true then
				console:unfocus()
			else
				menu:Show()
			end
		elseif keyCode == codes.RETURN or keyCode == codes.NUMPAD_RETURN then
			showChat("")
		elseif keyCode == codes.SLASH then
			showChat("/")
		end
	end

	return true -- capture
end, { topPriority = true, system = System })

LocalEvent:Listen(LocalEvent.Name.CppMenuStateChanged, function(_)
	cppMenuIsActive = System.IsCppMenuActive

	refreshDisplay()
	triggerCallbacks()
	refreshChat()
end)

LocalEvent:Listen(LocalEvent.Name.ServerConnectionSuccess, function()
	print("connection success")
end)

LocalEvent:Listen(LocalEvent.Name.ServerConnectionFailed, function()
	print("connection failed")
end)

LocalEvent:Listen(LocalEvent.Name.ServerConnectionLost, function()
	print("connection lost")
end)

LocalEvent:Listen(LocalEvent.Name.ServerConnectionStart, function()
	print("connecting...")
end)

LocalEvent:Listen(LocalEvent.Name.LocalAvatarUpdate, function(updates)
	if updates.skinColors then
		if avatar.head.shape then
			avatarModule:setHeadColors(
				avatar.head.shape,
				updates.skinColors.skin1,
				updates.skinColors.skin2,
				updates.skinColors.nose,
				updates.skinColors.mouth
			)
		end
	end

	if updates.eyesColor then
		if avatar.head.shape then
			avatarModule:setEyesColor(avatar.head.shape, updates.eyesColor)
		end
	end

	if updates.noseColor then
		if avatar.head.shape then
			avatarModule:setNoseColor(avatar.head.shape, updates.noseColor)
		end
	end

	if updates.mouthColor then
		if avatar.head.shape then
			avatarModule:setMouthColor(avatar.head.shape, updates.mouthColor)
		end
	end

	if updates.outfit == true then
		avatar:remove()
		avatar = uiAvatar:getHead(Player.Username, cubzhBtn.Height, ui, { ignoreCache = true })
		avatar:setParent(profileFrame)
		topBar:parentDidResize()
	end
end)

function hideTitleScreen()
	if titleScreen == nil then
		return
	end

	titleScreenTickListener:Remove()
	titleScreen:remove()
	titleScreen = nil
end

function versionCheck(callbacks)
	api:getMinAppVersion(function(error, minVersion)
		if error ~= nil then
			if callbacks.networkError then
				callbacks.networkError()
			end
			return
		end

		local major, minor, patch = parseVersion(Client.AppVersion)
		local minMajor, minMinor, minPatch = parseVersion(minVersion)

		-- minPatch = 51 -- force trigger, for tests
		if major < minMajor or (major == minMajor and minor < minMinor) or (minor == minMinor and patch < minPatch) then
			if callbacks.updateRequired then
				local minVersion = string.format("%d.%d.%d", minMajor, minMinor, minPatch)
				local currentVersion = string.format("%d.%d.%d", major, minor, patch)
				callbacks.updateRequired(minVersion, currentVersion)
			end
		else
			if callbacks.success then
				callbacks.success()
			end
		end
	end)
end

function magicKeyCheck(success, err)
	if System.HasCredentials == false and System.AskedForMagicKey then
		-- TODO
		-- checkMagicKey(
		-- 	function(error, info)
		-- 		if error ~= nil then
		-- 			-- displayTitleScreen()
		-- 		else
		-- 			accountInfo = info
		-- 			done()
		-- 		end
		-- 	end,
		-- 	function(keyIsValid)
		-- 		if keyIsValid then
		-- 			closeModals()
		-- 		else
		-- 			checkUserInfo()
		-- 		end
		-- 	end
		-- )
		print("MAGIC KEY CHECK NOT IMPLEMENTED")
		if err ~= nil then
			err()
		end
	else
		if success ~= nil then
			success()
		end
	end
end

-- callbacks: success, loggedOut, error
function accountCheck(callbacks)
	showLoading("Checking user info")

	if System.HasCredentials == false then
		if callbacks.loggedOut then
			callbacks.loggedOut()
		end
		return
	end

	-- Fetch account info
	-- it's ok to continue if err == nil
	-- (info updated at the engine level)
	System.GetAccountInfo(function(err, res)
		if err ~= nil then
			if callbacks.error then
				callbacks.error()
			end
			return
		end

		accountInfo = res

		if accountInfo.hasDOB == false or accountInfo.hasUsername == false then
			if callbacks.accountIncomplete then
				callbacks.accountIncomplete()
			end
			return
		end

		-- NOTE: accountInfo.hasPassword could be false here
		-- for some accounts created pre-0.0.52.
		-- (mandatory after that)

		if callbacks.success then
			callbacks.success()
		end
	end)
end

signupElements = nil

-- callbacks: success, cancel, error
function showSignUp(callbacks)
	local helpBtn = ui:createButton("👾 Need help?", { textSize = "small" })
	helpBtn:setColor(theme.colorDiscord, Color.White)
	helpBtn.onRelease = function()
		URL:Open("https://cu.bzh/discord")
	end
	helpBtn.parentDidResize = function(self)
		self.pos = {
			Screen.Width - self.Width - theme.padding - Screen.SafeArea.Right,
			Screen.Height - self.Height - theme.padding - System.SafeAreaTop,
			0,
		}
	end
	helpBtn:parentDidResize()

	local loginBtn = ui:createButton("🙂 Login", { textSize = "small" })
	loginBtn.parentDidResize = function(self)
		self.pos = {
			Screen.SafeArea.Left + theme.padding,
			Screen.Height - self.Height - theme.padding - System.SafeAreaTop,
			0,
		}
	end

	local signupModal = require("signup"):createModal({ uikit = ui })

	signupElements = { signupModal, helpBtn, loginBtn, signupModal.terms }

	loginBtn.onRelease = function()
		ui:turnOff()
		System.Login(function(success, info)
			ui:turnOn()
			if success then
				accountInfo = info
				helpBtn:remove()
				loginBtn:remove()
				signupElements = nil

				signupModal.didClose = nil
				signupModal:close()
				signupModal = nil

				if callbacks.success ~= nil then
					callbacks.success()
				end
			end
		end)
	end
	loginBtn:parentDidResize()

	signupModal.onSubmit = function(username, key, dob, password)
		System:DebugEvent("SIGNUP_SUBMIT")

		loginBtn:remove()
		helpBtn:remove()
		signupElements = nil

		signupModal.didClose = nil
		signupModal:close()
		signupModal = nil

		local function _createAccount(onError)
			showLoading("Creating account")

			api:signUp(username, key, dob, password, function(err, credentials)
				if err ~= nil then
					if onError ~= nil then
						onError(onError)
					end
					return
				else
					System:StoreCredentials(credentials["user-id"], credentials.token)
					System:DebugEvent("ACCOUNT_CREATED")
					if callbacks.success ~= nil then
						callbacks.success()
					end
				end
			end)
		end

		local function onError(onError)
			showAlert({
				message = "❌ Sorry, something went wrong.",
				positiveCallback = function()
					_createAccount(onError)
				end,
				positiveLabel = "Retry",
				neutralCallback = function()
					if callbacks.error ~= nil then
						callbacks.error()
					end
				end,
				neutralLabel = "Cancel",
			})
		end

		_createAccount(onError)
	end

	signupModal.didClose = function()
		loginBtn:remove()
		helpBtn:remove()
		signupElements = nil
		signupModal = nil
		if callbacks.cancel ~= nil then
			callbacks.cancel()
		end
	end
end

function skipTitleScreen()
	if titleScreen == nil then
		return
	end

	hideTitleScreen()
	hideBottomBar()

	showLoading("Checking app version")

	versionCheck(
		{
			success = function()
				magicKeyCheck(
					function()
						accountCheck({
							success = function()
								hideLoading()
								showTopBar()
								hideBottomBar()
								authCompleted()
							end,
							loggedOut = function()
								System:DebugEvent("SKIP_SPLASHSCREEN_WITH_NO_ACCOUNT")
								hideLoading()
								showSignUp({
									success = function()
										accountCheck({
											success = function()
												hideLoading()
												showTopBar()
												hideBottomBar()
												authCompleted()
											end,
											-- not supposed to happen after successful signup
											loggedOut = function()
												showTitleScreen()
											end,
											error = function()
												showTitleScreen()
											end,
										})
									end,
									error = function()
										showTitleScreen()
									end,
									cancel = function()
										showTitleScreen()
									end,
								}) -- signup
							end,
							error = function()
								hideLoading()
								showAlert({
									message = "❌ Sorry, something went wrong.",
									positiveCallback = function()
										showTitleScreen()
									end,
									positiveLabel = "OK",
								})
							end,
							accountIncomplete = function()
								hideLoading()
								showAlert({
									message = "⚠️ Anonymous account detected ⚠️\nAnonymous accounts aren't allowed anymore on Cubzh.",
									positiveCallback = function()
										System:Logout()
										showTitleScreen()
										skipTitleScreen()
									end,
									positiveLabel = "Create a new account",
								})
							end,
						})
					end, -- magicKeyCheck success (magic key verified or no magic key to verify)
					function() end -- magicKeyCheck err
				)
			end,
			networkError = function()
				hideLoading()
				showAlert({
					message = "❌ Network error ❌",
					positiveCallback = function()
						showTitleScreen()
					end,
					positiveLabel = "OK",
				})
			end,
			updateRequired = function(minVersion, currentVersion)
				hideLoading()
				showAlert({
					message = "Cubzh needs to be updated!\nMinimum version: "
						.. minVersion
						.. "\nCurrent version: "
						.. currentVersion,
					positiveCallback = function()
						showTitleScreen()
					end,
					positiveLabel = "OK",
				})
			end,
		}, -- versionCheck success
		function() end -- versionCheck err
	)
end

function showTitleScreen()
	if titleScreen ~= nil then
		return
	end

	showBottomBar()
	hideTopBar()

	titleScreen = ui:createFrame()

	local logoShape = System.ShapeFromBundle("official.cubzh")
	local alphaShape = System.ShapeFromBundle("official.alpha")

	logo = ui:createShape(logoShape)
	logo:setParent(titleScreen)
	alpha = ui:createShape(alphaShape)
	alpha:setParent(titleScreen)

	alpha.pos.Z = -700

	pressAnywhere = ui:createText("Press Anywhere", Color.White)
	pressAnywhere:setParent(titleScreen)

	logoNativeWidth = logo.Width
	logoNativeHeight = logo.Height

	titleScreen.parentDidResize = function()
		titleScreen.Width = Screen.Width
		titleScreen.Height = Screen.Height

		local maxWidth = math.min(600, Screen.Width * 0.8)
		local maxHeight = math.min(216, Screen.Height * 0.3)

		local ratio = math.min(maxWidth / logoNativeWidth, maxHeight / logoNativeHeight)

		logo.Width = logoNativeWidth * ratio
		logo.Height = logoNativeHeight * ratio
		logo.pos = {
			Screen.Width * 0.5 - logo.Width * 0.5,
			Screen.Height * 0.5 - logo.Height * 0.5 + (pressAnywhere.Height + theme.padding) * 0.5,
			0,
		}

		alpha.Height = logo.Height * 3 / 9
		alpha.Width = alpha.Height * 33 / 12

		alpha.pos = logo.pos + { logo.Width * 24.5 / 25 - alpha.Width, logo.Height * 3.5 / 9 - alpha.Height, 0 }

		pressAnywhere.pos = {
			Screen.Width * 0.5 - pressAnywhere.Width * 0.5,
			logo.pos.Y - pressAnywhere.Height - theme.padding,
			0,
		}
	end
	titleScreen:parentDidResize()

	local t = 0
	titleScreenTickListener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
		t = t + dt * 4.0
		pressAnywhere.Color = Color(255, 255, 255, (math.sin(t) + 1.0) * 0.5)
		alpha.shape:RotateWorld({ 0, dt, 0 })
	end)

	titleScreen.onRelease = function()
		skipTitleScreen()
	end

	if System.HasEnvironmentToLaunch then
		skipTitleScreen()
	end

	-- controls:turnOn()
	-- ui:turnOn()
end

----------------------------
-- sign up / sign in flow
----------------------------
-- if System.HasCredentials == false then

function hideTopBar()
	topBar:hide()
end

function showTopBar()
	topBar:show()
end

function hideBottomBar()
	bottomBar:hide()
end

function showBottomBar()
	bottomBar:show()
end

if System.Authenticated then
	showTopBar()
	hideBottomBar()
else
	showTitleScreen()
end

Timer(0.1, function()
	menu:OnAuthComplete(function()
		System:UpdateAuthStatus()

		-- connects client to server if it makes sense (maxPlayers > 1)
		System:ConnectToServer()

		username.Text = Player.Username

		api.getBalance(function(err, balance)
			if err then
				return
			end
			coins = balance.total
			info.Text = string.format(
				"🏆 %s 💰 %s",
				xp and "" .. math.floor(xp) or "…",
				coins and "" .. math.floor(coins) or "…"
			)
			topBar:parentDidResize()
		end)

		xp = 0
		info.Text = string.format(
			"🏆 %s 💰 %s",
			xp and "" .. math.floor(xp) or "…",
			coins and "" .. math.floor(coins) or "…"
		)
		topBar:parentDidResize()

		avatar:remove()
		avatar = uiAvatar:getHead(Player.Username, cubzhBtn.Height, ui)
		avatar:setParent(profileFrame)
		topBar:parentDidResize()
		if chat then
			chat:parentDidResize()
		end

		Timer(10.0, function()
			-- request permission for remote notifications
			local showInfoPopupFunc = function(yesCallback, laterCallback)
				showAlert({
					message = "Enable notifications to receive messages from your friends, and know when your creations are liked.",
					positiveLabel = "Yes",
					neutralLabel = "Later",
					positiveCallback = function()
						yesCallback()
					end,
					neutralCallback = function()
						laterCallback()
					end,
				})
			end
			sys_notifications:request(showInfoPopupFunc)
		end)

		-- check if there's an environment to launch, otherwise, listen for event
		if System.HasEnvironmentToLaunch then
			System:LaunchEnvironment()
		else
			LocalEvent:Listen(LocalEvent.Name.ReceivedEnvironmentToLaunch, function()
				if System.HasEnvironmentToLaunch then
					System:LaunchEnvironment()
				end
			end)
		end

		-- api.getXP(function(err, xp)
		-- 	if err then return end
		-- 	xp = xp
		-- 	info.Text = string.format("🏆 %s 💰 %s", xp and "" .. math.floor(xp) or "…", coins and "" .. math.floor(coins) or "…")
		-- 	topBar:parentDidResize()
		-- end)
	end)
end)

return menu

-- CODE PREVIOUSLY USED TO EASTER EGG PROMPT:
-- if secretCount == nil then
-- 	secretCount = 1
-- else
-- 	secretCount = secretCount + 1
-- 	if secretCount == 9 then
-- 		closeModals()
-- 		secretModal = require("input_modal"):create("Oh, it seems like you have something to say? 🤨")
-- 		secretModal:setPositiveCallback("Oh yeah!", function(text)
-- 			if text ~= "" then
-- 				api:postSecret(text, function(success, message)
-- 					if success then
-- 						if message ~= nil and message ~= "" then
-- 							self:showAlert({message = message})
-- 						else
-- 							self:showAlert({message = "✅"})
-- 						end
-- 						api.getBalance(function(err, balance)
-- 							if err then return end
-- 							menu.coinsBtn.Text = "" .. math.floor(balance.total) .. " 💰"
-- 							menu:refresh()
-- 						end)
-- 					else
-- 						self:showAlert({message = "❌ Error"})
-- 					end
-- 				end)
-- 			end
-- 		end)
-- 		secretModal:setNegativeCallback("Hmm, no.", function() end)
-- 		secretModal.didClose = function()
-- 			secretModal = nil
-- 			refreshMenuDisplayMode()
-- 		end
-- 		refreshMenuDisplayMode()
-- 		return
-- 	end
-- end
