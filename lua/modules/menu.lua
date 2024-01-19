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
sfx = require("sfx")
logo = require("logo")
uiPointer = require("ui_pointer")

-- CONSTANTS

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
CONNECTION_RETRY_DELAY = 5.0 -- in seconds
PADDING = theme.padding
PADDING_BIG = 9
TOP_BAR_HEIGHT = 40

CUBZH_MENU_MAIN_BUTTON_HEIGHT = 60
CUBZH_MENU_SECONDARY_BUTTON_HEIGHT = 40

-- VARS

wasActive = nil
modalWasShown = false
alertWasShown = false
cppMenuIsActive = false
chatDisplayed = false -- when false, only a mini chat console is displayed in the top bar
_DEBUG = false
_DebugColor = function()
	return Color(math.random(150, 255), math.random(150, 255), math.random(150, 255))
end
pointer = nil

-- MODALS

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
	ITEMS = 7,
	BUILD = 8,
	MARKETPLACE = 9,
	CUBZH_MENU = 10,
}

function connect()
	if Players.Max <= 1 then
		return -- no need to connect when max players not > 1
	end
	if Client.Connected then
		return -- already connected
	end
	if connectionIndicator:isVisible() then
		return -- already trying to connect
	end

	if connectionRetryTimer ~= nil then
		connectionRetryTimer:Cancel()
		connectionRetryTimer = nil
	end

	connBtn:show()
	connectionIndicator:show()
	noConnectionIndicator:hide()

	connectionIndicatorStartAnimation()

	System:ConnectToServer()
end

function startConnectTimer()
	if connectionRetryTimer ~= nil then
		connectionRetryTimer:Cancel()
	end
	connectionRetryTimer = Timer(CONNECTION_RETRY_DELAY, function()
		connect()
	end)

	connShape.Tick = nil
	connectionIndicator:hide()
	noConnectionIndicator:show()
end

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

	ease:cancel(modal) -- cancel modal ease animations if any

	if not modal.updatedPosition or forceBounce then
		modal.LocalPosition = p - { 0, 100, 0 }
		modal.updatedPosition = true
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
	elseif key == MODAL_KEYS.WORLDS then
		local content = worlds:createModalContent({ uikit = ui })
		activeModal = modal:create(content, maxModalWidth, maxModalHeight, updateModalPosition, ui)
	elseif key == MODAL_KEYS.ITEMS then
		local content = require("gallery"):createModalContent({ uikit = ui })
		activeModal = modal:create(content, maxModalWidth, maxModalHeight, updateModalPosition, ui)
	end

	if activeModal ~= nil then
		menu:RemoveHighlight()

		ui.unfocus() -- unfocuses node currently focused

		activeModal:setParent(background)

		activeModalKey = key

		activeModal.didClose = function()
			activeModal = nil
			activeModalKey = nil
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
			System.PointerForceShown = true
			removeBadge()
		else
			unblockEvents()
			System.PointerForceShown = false
			if System.HasEmail == false then
				showBadge("!")
			end
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

		chatBtn:hide()
		friendsBtn:hide()

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

		chatBtn:show()
		friendsBtn:show()

		profileFrame:show()
		if signupElements ~= nil then
			for _, e in ipairs(signupElements) do
				e:show()
			end
		end
	end
end

-- BACKGROUND

background = ui:createFrame(BACKGROUND_COLOR_OFF)

background.parentDidResize = function(_)
	background.Width = Screen.Width
	background.Height = Screen.Height
end
background:parentDidResize()

alertBackground = ui:createFrame(ALERT_BACKGROUND_COLOR_OFF)
alertBackground.pos.Z = ui.kAlertDepth

alertBackground.parentDidResize = function(_)
	alertBackground.Width = Screen.Width
	alertBackground.Height = Screen.Height
end
alertBackground:parentDidResize()

-- ACTION COLUMN

actionColumn = ui:createFrame(Color.transparent)
actionColumn:setParent(background)
actionColumn:hide()

-- SETTINGS BTN

settingsBtn = ui:createFrame(_DEBUG and _DebugColor() or Color.transparent)
settingsBtn:setParent(actionColumn)

settingsBtn.onRelease = function()
	if activeModal ~= nil then
		activeModal:push(settings:createModalContent({ clearCache = true, logout = true, uikit = ui }))
	end
end

settingsIcon = ui:createText("⚙️", Color.White, "big")
settingsIcon:setParent(settingsBtn)

settingsBtn.getMinSize = function(_)
	return Number2(settingsIcon.Width, settingsIcon.Height)
end

settingsIcon.parentDidResize = function(_)
	local parent = settingsIcon.parent
	settingsIcon.pos =
		{ parent.Width * 0.5 - settingsIcon.Width * 0.5, parent.Height * 0.5 - settingsIcon.Height * 0.5 }
end

-- SHARE BTN

shareBtn = ui:createFrame(_DEBUG and _DebugColor() or Color.transparent)
shareBtn:setParent(actionColumn)

shareBtn.onRelease = function()
	-- if btnLinkTimer then
	-- 	btnLinkTimer:Cancel()
	-- end
	Dev:CopyToClipboard(Dev.ServerURL)

	if shareBtnConfirmation ~= nil then
		if shareBtnConfirmationTimer ~= nil then
			shareBtnConfirmationTimer:Cancel()
			shareBtnConfirmationTimer = nil
		end
		ease:cancel(shareBtnConfirmation.pos)
		shareBtnConfirmation:remove()
	end

	shareBtnConfirmation = ui:createText("📋 Link copied!", Color.White, "small")
	shareBtnConfirmation:setParent(shareBtn)

	shareBtnConfirmation.pos =
		{ -shareBtnConfirmation.Width - PADDING, shareBtn.Height * 0.5 - shareBtnConfirmation.Height * 0.5 }

	local backup = shareBtnConfirmation.pos.X
	shareBtnConfirmation.pos.X = backup + 50
	ease:outBack(shareBtnConfirmation.pos, 0.22 * 1.2).X = backup

	shareBtnConfirmationTimer = Timer(1.5, function()
		shareBtnConfirmation:remove()
		shareBtnConfirmation = nil
		shareBtnConfirmationTimer = nil
	end)
end

shareLabel = ui:createText("Share", Color.White, "small")
shareLabel:setParent(shareBtn)

shareIcon = ui:createText("↗", Color.White, "big")
shareIcon:setParent(shareBtn)

shareBtn.getMinSize = function(_)
	return Number2(math.max(shareLabel.Width, shareIcon.Width), shareLabel.Height + shareIcon.Height)
end

shareLabel.parentDidResize = function(_)
	local parent = shareLabel.parent
	local contentHeight = shareLabel.Height + shareIcon.Height
	shareLabel.pos = { parent.Width * 0.5 - shareLabel.Width * 0.5, parent.Height * 0.5 - contentHeight * 0.5 }
	shareIcon.pos = {
		parent.Width * 0.5 - shareIcon.Width * 0.5,
		parent.Height * 0.5 + contentHeight * 0.5 - shareIcon.Height,
	}
end

-- LIKE BTN

nbLikes = nil
liked = false

likeBtn = ui:createFrame(_DEBUG and _DebugColor() or Color.transparent)
likeBtn:setParent(actionColumn)
likeWorldReq = nil

likeBtn.onRelease = function()
	if Environment.worldId == nil then
		return
	end
	liked = not liked

	if nbLikes == nil then
		nbLikes = liked and 1 or nil
	else
		if liked then
			nbLikes = nbLikes + 1
		else
			nbLikes = nbLikes - 1
		end
	end

	actionColumnUpdateContent()

	if likeWorldReq ~= nil then
		likeWorldReq:Cancel()
	end
	if getWorldInfoReq ~= nil then
		getWorldInfoReq:Cancel()
		getWorldInfoReq = nil
	end

	likeWorldReq = api:likeWorld(Environment.worldId, liked, function(_)
		likeWorldReq = nil
		getWorldInfo()
	end)
end

likeLabel = ui:createText(nbLikes ~= nil and string.format("%d", nbLikes) or "…", Color.White, "small")
likeLabel:setParent(likeBtn)

likeIcon = ui:createText("🤍", Color.White, "big")
likeIcon:setParent(likeBtn)

likeBtn.getMinSize = function(_)
	return Number2(math.max(likeLabel.Width, likeIcon.Width), likeLabel.Height + likeIcon.Height)
end

likeLabel.parentDidResize = function(_)
	local parent = likeLabel.parent
	local contentHeight = likeLabel.Height + likeIcon.Height
	likeLabel.pos = { parent.Width * 0.5 - likeLabel.Width * 0.5, parent.Height * 0.5 - contentHeight * 0.5 }
	likeIcon.pos = {
		parent.Width * 0.5 - likeIcon.Width * 0.5,
		parent.Height * 0.5 + contentHeight * 0.5 - likeIcon.Height,
	}
end

-- COMMENTS BTN

commentsBtn = ui:createFrame(_DEBUG and _DebugColor() or Color.transparent)
commentsBtn:setParent(actionColumn)

commentsBtn.onRelease = function()
	showAlert({ message = "Coming soon!" })
end

-- commentsLabel = ui:createText("3", Color.White, "small")
-- commentsLabel:setParent(commentsBtn)

commentsIcon = ui:createText("💬", Color.White, "big")
commentsIcon:setParent(commentsBtn)

commentsBtn.getMinSize = function(_)
	-- return Number2(math.max(commentsLabel.Width, commentsIcon.Width), commentsLabel.Height + commentsIcon.Height)
	return Number2(commentsIcon.Width, commentsIcon.Height)
end

commentsIcon.parentDidResize = function(_)
	local parent = commentsIcon.parent
	commentsIcon.pos = {
		parent.Width * 0.5 - commentsIcon.Width * 0.5,
		parent.Height * 0.5 - commentsIcon.Height * 0.5,
	}
end

-- ACTION COLUMN LAYOUT

function actionColumnUpdateContent()
	likeLabel.Text = nbLikes ~= nil and string.format("%d", nbLikes) or "…"
	if liked then
		likeIcon.Text = "❤️"
	else
		likeIcon.Text = "🤍"
	end
	likeLabel:parentDidResize()
end

function showActionColumn()
	if actionColumn:isVisible() then
		return
	end

	actionColumn:parentDidResize() -- force layout

	local backup = likeBtn.pos.Y
	likeBtn.pos.Y = likeBtn.pos.Y - 100 * 1.2
	ease:outBack(likeBtn.pos, 0.22 * 1.2).Y = backup

	backup = commentsBtn.pos.Y
	commentsBtn.pos.Y = commentsBtn.pos.Y - 100 * 1.1
	ease:outBack(commentsBtn.pos, 0.22 * 1.1).Y = backup

	backup = shareBtn.pos.Y
	shareBtn.pos.Y = shareBtn.pos.Y - 100
	ease:outBack(shareBtn.pos, 0.22).Y = backup

	backup = settingsBtn.pos.Y
	settingsBtn.pos.Y = settingsBtn.pos.Y + 100
	ease:outBack(settingsBtn.pos, 0.22).Y = backup

	actionColumn:show()
end

-- function hideActionColumn() end

actionColumn.parentDidResize = function(_)
	ease:cancel(settingsBtn.pos)
	ease:cancel(likeBtn.pos)
	ease:cancel(commentsBtn.pos)
	ease:cancel(shareBtn.pos)

	local height = Screen.Height - Screen.SafeArea.Top

	local settingsBtnMinSize = settingsBtn:getMinSize()
	local shareBtnMinSize = shareBtn:getMinSize()
	local likeBtnMinSize = likeBtn:getMinSize()
	local commentsBtnMinSize = commentsBtn:getMinSize()

	local contentWidth = math.max(
		shareBtnMinSize.Width,
		likeBtnMinSize.Width,
		commentsBtnMinSize.Width,
		settingsBtnMinSize.Width
	) + PADDING * 2
	local width = contentWidth + Screen.SafeArea.Right

	actionColumn.Height = height
	actionColumn.Width = width

	actionColumn.pos.X = Screen.Width - actionColumn.Width

	settingsBtn.Width = contentWidth
	settingsBtn.Height = settingsBtnMinSize.Height + PADDING_BIG * 2
	settingsBtn.pos = { 0, actionColumn.Height - settingsBtn.Height }

	shareBtn.Width = contentWidth
	shareBtn.Height = shareBtnMinSize.Height + PADDING_BIG * 2
	shareBtn.pos = { 0, Screen.SafeArea.Bottom + PADDING }

	commentsBtn.Width = contentWidth
	commentsBtn.Height = commentsBtnMinSize.Height + PADDING_BIG * 2
	commentsBtn.pos = { 0, shareBtn.pos.Y + shareBtn.Height }

	likeBtn.Width = contentWidth
	likeBtn.Height = likeBtnMinSize.Height + PADDING_BIG * 2
	likeBtn.pos = { 0, commentsBtn.pos.Y + commentsBtn.Height }
end
actionColumn:parentDidResize()

-- TOP BAR

topBar = ui:createFrame(Color(0, 0, 0, 0.7))
topBar:setParent(background)

btnContentParentDidResize = function(self)
	local padding = PADDING_BIG
	if self == cubzhBtnShape or self == avatar then
		padding = PADDING
	end
	local parent = self.parent
	self.Width = parent.Width - PADDING * 2
	self.Height = parent.Height - padding * 2
	self.pos = { PADDING, padding }
end

-- MAIN MENU BTN

cubzhBtn = ui:createFrame(_DEBUG and _DebugColor() or Color.transparent)
cubzhBtn:setParent(topBar)

uiBadge = require("ui_badge")

cubhBtnBadge = nil

function showBadge(str)
	removeBadge()
	cubhBtnBadge = uiBadge:create({ text = str, ui = ui })
	cubhBtnBadge.internalParentDidResize = cubhBtnBadge.parentDidResize
	cubhBtnBadge.parentDidResize = function(self)
		self.pos.X = self.parent.Width * 0.5
		self.pos.Y = 0
		self:internalParentDidResize()
	end
	cubhBtnBadge:setParent(cubzhBtn)
end

function removeBadge()
	if cubhBtnBadge ~= nil then
		cubhBtnBadge:remove()
		cubhBtnBadge = nil
	end
end

cubzhLogo = logo:createShape()
cubzhBtnShape = ui:createShape(cubzhLogo, { doNotFlip = true })
cubzhBtnShape:setParent(cubzhBtn)
cubzhBtnShape.parentDidResize = btnContentParentDidResize
cubzhBtnShape:parentDidResize()

-- CONNECTIVITY BTN

connBtn = ui:createFrame(_DEBUG and _DebugColor() or Color.transparent)
connBtn:setParent(topBar)
connBtn:hide()
connBtn.onRelease = connect

connShape = System.ShapeFromBundle("aduermael.connection_indicator")
connectionIndicator = ui:createShape(connShape, { doNotFlip = true })
connectionIndicator:setParent(connBtn)
connectionIndicator:hide()
connectionIndicator.parentDidResize = function(self)
	local parent = self.parent
	self.Height = parent.Height * 0.4
	self.Width = self.Height
	self.pos = { parent.Width - self.Width - PADDING, parent.Height * 0.5 - self.Height * 0.5 }
end

noConnShape = System.ShapeFromBundle("aduermael.no_conn_indicator")
noConnectionIndicator = ui:createShape(noConnShape)
noConnectionIndicator:setParent(connBtn)
noConnectionIndicator:hide()
noConnectionIndicator.parentDidResize = function(self)
	local parent = self.parent
	self.Height = parent.Height * 0.4
	self.Width = self.Height
	self.pos = { parent.Width - self.Width - PADDING, parent.Height * 0.5 - self.Height * 0.5 }
end

function connectionIndicatorValid()
	Client:HapticFeedback()
	connShape.Tick = nil
	local palette = connShape.Palette
	palette[1].Color = theme.colorPositive
	palette[2].Color = theme.colorPositive
	palette[3].Color = theme.colorPositive
	palette[4].Color = theme.colorPositive
	sfx("metal_clanging_2", { Volume = 0.2, Pitch = 5.0, Spatialized = false })
end

function connectionIndicatorStartAnimation()
	local animTime = 0.7
	local animTimePortion = animTime / 4.0
	local t = 0.0

	local palette = connShape.Palette
	local darkGrayLevel = 100
	local darkGray = Color(darkGrayLevel, darkGrayLevel, darkGrayLevel)
	local white = Color.White

	palette[1].Color = darkGray
	palette[2].Color = darkGray
	palette[3].Color = darkGray
	palette[4].Color = darkGray

	local v
	connShape.Tick = function(_, dt)
		t = t + dt
		local palette = connShape.Palette

		t = math.min(animTime, t)

		if t < animTime * 0.25 then
			v = t / animTimePortion
			palette[1].Color:Lerp(darkGray, white, v)
			palette[2].Color = darkGray
			palette[3].Color = darkGray
			palette[4].Color = darkGray
		elseif t < animTime * 0.5 then
			v = (t - animTimePortion) / animTimePortion
			palette[1].Color = white
			palette[2].Color:Lerp(darkGray, white, v)
			palette[3].Color = darkGray
			palette[4].Color = darkGray
		elseif t < animTime * 0.75 then
			v = (t - animTimePortion * 2) / animTimePortion
			palette[1].Color = white
			palette[2].Color = white
			palette[3].Color:Lerp(darkGray, white, v)
			palette[4].Color = darkGray
		else
			v = (t - animTimePortion * 3) / animTimePortion
			palette[1].Color = white
			palette[2].Color = white
			palette[3].Color = white
			palette[4].Color:Lerp(darkGray, white, v)
		end

		if t >= animTime then
			t = 0.0
		end
	end
end

chatBtn = ui:createFrame(_DEBUG and _DebugColor() or Color.transparent)
chatBtn:setParent(topBar)

textBubbleShape = ui:createShape(System.ShapeFromBundle("aduermael.textbubble"))
textBubbleShape:setParent(chatBtn)
textBubbleShape.parentDidResize = function(self)
	local parent = self.parent
	self.Height = parent.Height - PADDING_BIG * 2
	self.Width = self.Height
	self.pos = { PADDING, PADDING_BIG }
end

friendsBtn = ui:createFrame(_DEBUG and _DebugColor() or Color.transparent)
friendsBtn:setParent(topBar)

friendsShape = ui:createShape(System.ShapeFromBundle("aduermael.friends_icon"))
friendsShape:setParent(friendsBtn)
friendsShape.parentDidResize = btnContentParentDidResize

cubzhBtn.onRelease = function()
	showModal(MODAL_KEYS.CUBZH_MENU)
end

chatBtn.onRelease = function()
	if isChatAvailable() == false then
		return
	end
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

profileFrame = ui:createFrame(_DEBUG and _DebugColor() or Color.transparent)
profileFrame:setParent(topBar)
profileFrame.onRelease = function(_)
	showModal(MODAL_KEYS.PROFILE)
end

avatar = ui:createFrame(Color.transparent)
avatar:setParent(profileFrame)
avatar.parentDidResize = btnContentParentDidResize

-- CHAT

function createTopBarChat()
	if topBarChat ~= nil then
		return -- already created
	end
	topBarChat = require("chat"):create({ uikit = ui, input = false, time = false, heads = false, maxMessages = 4 })
	topBarChat:setParent(chatBtn)
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
		if isChatAvailable() then
			showModal(MODAL_KEYS.CHAT)
		end
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
	if isChatAvailable() == false then
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

-- CUBZH MENU CONTENT

function getCubzhMenuModalContent()
	local content = modal:createContent()
	content.closeButton = true
	content.title = "Cubzh"
	content.icon = "⎔"

	local node = ui:createFrame()
	content.node = node

	-- local btnHome = ui:createButton("🏠 Home")
	-- btnHome:setParent(node)

	-- btnHome.onRelease = function()
	-- 	System.GoHome()
	-- end

	local btnWorlds = ui:createButton("🌎 Worlds", { textSize = "big" })
	btnWorlds:setColor(theme.colorExplore)
	btnWorlds:setParent(node)
	btnWorlds.Height = CUBZH_MENU_MAIN_BUTTON_HEIGHT

	btnWorlds.onRelease = function()
		local modal = content:getModalIfContentIsActive()
		if modal ~= nil then
			modal:push(worlds:createModalContent({ uikit = ui }))
		end
	end

	local btnItems = ui:createButton("⚔️ Items", { textSize = "default" })
	btnItems:setParent(node)
	btnItems.Height = CUBZH_MENU_SECONDARY_BUTTON_HEIGHT

	btnItems.onRelease = function()
		local modal = content:getModalIfContentIsActive()
		if modal ~= nil then
			modal:push(require("gallery"):createModalContent({ uikit = ui }))
		end
	end

	local btnMyCreations = ui:createButton("🏗️ My Creations", { textSize = "default" })
	-- btnMyCreations:setColor(theme.colorCreate)
	btnMyCreations:setParent(node)
	btnMyCreations.Height = CUBZH_MENU_SECONDARY_BUTTON_HEIGHT

	btnMyCreations.onRelease = function()
		local modal = content:getModalIfContentIsActive()
		if modal ~= nil then
			local content = creations:createModalContent({ uikit = ui })
			content.tabs[1].selected = true
			content.tabs[1].action()
			modal:push(content)
		end
	end

	local buttons

	-- Secure account form

	local emailForm

	local function addEmailForm(hasEmail, emailTemporary, refreshModal)
		if hasEmail then
			return
		end

		emailForm = ui:createFrame(Color(95, 93, 201))
		emailForm.dynamicHeight = true
		emailForm:setParent(node)
		emailForm.Width = 100
		emailForm.Height = 100
		emailForm.badge = nil

		local msg

		if System.IsUserUnder13 then
			msg = "✉️ Add Parent's Email to secure your account."
		else
			msg = "✉️ Add an Email to secure your account."
		end

		local secureAccountFormText = ui:createText(msg, Color.White, "small")
		secureAccountFormText:hide()
		secureAccountFormText:setParent(emailForm)

		local secureAccountFormInput = ui:createTextInput("", "name@domain.com", {
			textSize = "small",
		})
		secureAccountFormInput:setParent(emailForm)

		local secureAccountFormBtn = ui:createButton("✅", { textSize = "small" })
		secureAccountFormBtn:setParent(emailForm)

		-- secureAccountFeedback has to be global to cancel animation
		local secureAccountFeedback = ui:createText("Sending…", Color(255, 255, 255, 254), "small")
		secureAccountFeedback:setParent(emailForm)
		secureAccountFeedback:hide()

		local secureAccountFeedbackAnim = {}
		secureAccountFeedbackAnim.start = function()
			ease:inOutSine(secureAccountFeedback, 0.3, {
				onDone = function()
					ease:inOutSine(secureAccountFeedback, 0.3, {
						onDone = function()
							secureAccountFeedbackAnim.start()
						end,
					}).Color =
						Color(255, 255, 255, 0)
				end,
			}).Color =
				Color(255, 255, 255, 254)
		end

		local secureAccountRefreshBtn = ui:createButton("Refresh", { textSize = "small" })
		local secureAccountCancelBtn = ui:createButton("❌", { textSize = "small" })

		secureAccountRefreshBtn:setParent(emailForm)
		secureAccountRefreshBtn:hide()

		secureAccountRefreshBtn.onRelease = function()
			secureAccountFormInput:hide()
			secureAccountFormBtn:hide()
			secureAccountRefreshBtn:hide()
			secureAccountCancelBtn:hide()
			secureAccountFeedback:show()
			secureAccountFeedback.Text = "Refreshing…"

			secureAccountFeedbackAnim.start()

			if activeModal then
				activeModal:refreshContent()
			end

			api:getUserInfo(Player.UserID, function(ok, userInfo, _)
				if not ok then
					return
				end

				if userInfo.hasEmail then
					System.HasEmail = true -- user is supposed to have an email now
					secureAccountFormInput:hide()
					secureAccountFormBtn:hide()
					secureAccountRefreshBtn:hide()
					secureAccountCancelBtn:hide()
					secureAccountFeedback:hide()
					ease:cancel(secureAccountFeedback)
					if emailForm.badge ~= nil then
						emailForm.badge:remove()
						emailForm.badge = nil
					end
					if System.IsUserUnder13 then
						secureAccountFormText.Text = "✅ Parent's Email verified!"
					else
						secureAccountFormText.Text = "✅ Email verified!"
					end
				else
					secureAccountFormInput:hide()
					secureAccountFormBtn:hide()
					secureAccountRefreshBtn:show()
					secureAccountCancelBtn:show()
					secureAccountFeedback:hide()
					ease:cancel(secureAccountFeedback)
				end

				if activeModal then
					activeModal:refreshContent()
				end
			end, { "hasEmail", "emailTemporary" })
		end

		secureAccountCancelBtn:setParent(emailForm)
		secureAccountCancelBtn:hide()

		secureAccountCancelBtn.onRelease = function()
			secureAccountFormInput:show()
			secureAccountFormBtn:show()

			secureAccountRefreshBtn:hide()
			secureAccountCancelBtn:hide()
			secureAccountFeedback:hide()

			secureAccountFormText.Text = msg
			if activeModal then
				activeModal:refreshContent()
			end
		end

		local secureAccountBadgeSetPosition = function()
			if emailForm.badge ~= nil then
				emailForm.badge.pos = {
					-theme.padding * 2,
					emailForm.Height * 0.5,
				}
			end
		end

		emailForm.didBecomeActive = function(self)
			if self.badge == nil and System.HasEmail == false then
				self.badge = uiBadge:create({ text = "!", ui = ui })
				self.badge:setParent(emailForm)
				secureAccountBadgeSetPosition()
			end
		end

		emailForm.willResignActive = function(self)
			if self.badge ~= nil then
				if secureAccountFeedback then
					ease:cancel(secureAccountFeedback)
				end
				self.badge:remove()
				self.badge = nil
			end
		end

		local function displayEmailSent(email)
			secureAccountFormInput:hide()
			secureAccountFormBtn:hide()

			secureAccountRefreshBtn:show()
			secureAccountCancelBtn:show()

			if System.IsUserUnder13 then
				secureAccountFormText.Text = "✉️ Link sent to " .. email .. ", ask Parent to click on it to verify!"
			else
				secureAccountFormText.Text = "✉️ Link sent to " .. email .. ", click on it to verify!"
			end
			if activeModal then
				activeModal:refreshContent()
			end
		end

		secureAccountFormBtn.onRelease = function()
			local email = secureAccountFormInput.Text

			if email == "" then
				secureAccountFormText.Text = "❌ Email can't be empty!"
				if activeModal then
					activeModal:refreshContent()
				end
				return
			end

			if not email:match("^[A-Za-z0-9.!#$%%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+%.[A-Za-z0-9-]*") then
				secureAccountFormText.Text = "❌ Doesn't look like a valid email!"
				if activeModal then
					activeModal:refreshContent()
				end
				return
			end

			secureAccountFormInput:hide()
			secureAccountFormBtn:hide()
			secureAccountFeedback:show()
			secureAccountFeedback.Text = "Sending…"
			secureAccountFeedbackAnim.start()

			local fields = {}
			if System.IsUserUnder13 then
				fields.parentEmail = email
			else
				fields.email = email
			end

			api:patchUserInfo(fields, function(err)
				secureAccountFeedback:hide()

				if err ~= nil then
					secureAccountFormBtn:show()
					secureAccountFormInput:show()
					secureAccountFormText.Text = "❌ Sorry, something went wrong. Please try again."
					if activeModal then
						activeModal:refreshContent()
					end
					return
				end

				displayEmailSent(email)
			end)
		end

		emailForm.parentDidResize = function(self)
			-- show when setting MaxWidth to avoid glitch
			-- (long single line of text displayed for a frame)
			secureAccountFormText:show()
			secureAccountFormText.object.MaxWidth = self.Width - theme.padding * 2
			secureAccountFormInput.Width = self.Width - secureAccountFormBtn.Width - theme.padding * 3
			secureAccountFormBtn.Width = secureAccountFormInput.Height

			secureAccountFormBtn.Height = secureAccountFormInput.Height
			secureAccountRefreshBtn.Height = secureAccountFormInput.Height
			secureAccountCancelBtn.Height = secureAccountFormInput.Height

			self.Height = secureAccountFormText.Height + theme.padding * 2

			if
				secureAccountFormInput:isVisible()
				or secureAccountRefreshBtn:isVisible()
				or secureAccountFeedback:isVisible()
			then
				self.Height = self.Height + secureAccountFormInput.Height + theme.padding
			end

			secureAccountFormText.pos = { theme.padding, self.Height - theme.padding - secureAccountFormText.Height }

			secureAccountFormInput.pos = { theme.padding, theme.padding }

			secureAccountFormBtn.pos = { self.Width - theme.padding - secureAccountFormBtn.Width, theme.padding }

			local w = secureAccountRefreshBtn.Width + theme.padding + secureAccountCancelBtn.Width
			local x = self.Width * 0.5 - w * 0.5
			secureAccountCancelBtn.pos = { x, theme.padding }
			x = x + secureAccountCancelBtn.Width + theme.padding
			secureAccountRefreshBtn.pos = { x, theme.padding }

			secureAccountFeedback.pos = {
				self.Width * 0.5 - secureAccountFeedback.Width * 0.5,
				secureAccountFormInput.pos.Y + secureAccountFormInput.Height * 0.5 - secureAccountFeedback.Height * 0.5,
			}

			secureAccountBadgeSetPosition()
		end

		if emailTemporary ~= "" then
			displayEmailSent(emailTemporary)
		end

		table.insert(buttons, { emailForm })

		if refreshModal then
			if activeModal then
				activeModal:refreshContent()
			end
		end

		if content:isActive() then
			emailForm.badge = uiBadge:create({ text = "!", ui = ui })
			emailForm.badge:setParent(emailForm)
			secureAccountBadgeSetPosition()
		end
	end

	if System.HasEmail == false then
		api:getUserInfo(Player.UserID, function(ok, userInfo, _)
			if not ok then
				return
			end
			if userInfo.hasEmail == true then -- could have been verified while menu was closed
				System.HasEmail = true
				return
			end
			addEmailForm(userInfo.hasEmail, userInfo.emailTemporary or userInfo.parentEmailTemporary or "", true)
		end, { "hasEmail", "emailTemporary", "parentEmailTemporary" })
	end

	local dev = System.LocalUserIsAuthor and System.ServerIsInDevMode
	local btnCode = ui:createButton(
		dev and "🤓 Edit Code" or "🤓 Read Code",
		{ textSize = "small", borders = false, underline = false, padding = true, shadow = false }
	)
	btnCode:setParent(node)

	btnCode.onRelease = function()
		if dev then
			System.EditCode()
		else
			System.ReadCode()
		end
		closeModal()
	end

	local btnHelp = ui:createButton(
		"👾 Help!",
		{ textSize = "small", borders = false, underline = false, padding = true, shadow = false }
	)
	btnHelp:setParent(node)

	btnHelp.onRelease = function()
		URL:Open("https://discord.gg/cubzh")
	end

	buttons = {
		{ btnWorlds },
		{ btnItems },
		{ btnMyCreations },
	}

	-- local osName = Client.OSName
	-- if osName == "Windows" or osName == "macOS" then
	-- 	local btnTerminate = ui:createButton("Exit Cubzh", { textSize = "small" })
	-- 	btnTerminate:setColor(theme.colorNegative)
	-- 	-- btnTerminate:setParent(node)
	-- 	btnTerminate.onRelease = function()
	-- 		System:Terminate()
	-- 	end
	-- 	-- table.insert(buttons, btnTerminate)
	-- 	content.bottomCenter = { btnTerminate, btnHelp }
	-- else
	-- 	content.bottomCenter = { btnHelp }
	-- end

	content.bottomCenter = { btnCode, btnHelp }

	content.idealReducedContentSize = function(_, width, _, minWidth)
		local height = 0
		local maxRowWidth = 0
		local widthBackup
		local ok

		for i, row in ipairs(buttons) do
			local w = 0
			for _, btn in ipairs(row) do
				widthBackup = btn.Width
				ok = pcall(function()
					btn.Width = nil
				end)
				if ok == false then
					btn.Width = 100 -- default width
				end
				w = w + btn.Width + (i > 1 and theme.padding or 0)
				if ok then
					btn.Width = widthBackup
				end
			end
			maxRowWidth = math.max(maxRowWidth, w)
		end

		width = math.max(math.min(width, maxRowWidth), minWidth)

		local h
		for i, row in ipairs(buttons) do
			h = 0
			for _, btn in ipairs(row) do
				if btn.dynamicHeight then
					btn.Width = width
					btn:parentDidResize()
				end
				h = math.max(h, btn.Height)
			end
			row.height = h
			height = height + h + (i > 1 and theme.padding or 0)
		end

		return Number2(width, height)
	end

	btnMyCreations.parentDidResize = function(_)
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
		btnMyCreations:parentDidResize()
		showActionColumn()
		if emailForm ~= nil then
			emailForm:didBecomeActive()
		end
	end

	content.willResignActive = function()
		actionColumn:hide()
		if emailForm ~= nil then
			emailForm:willResignActive()
		end
	end

	return content
end

topBar.parentDidResize = function(self)
	local height = TOP_BAR_HEIGHT

	cubzhBtn.Height = height
	cubzhBtn.Width = cubzhBtn.Height

	connBtn.Height = height
	connBtn.Width = connBtn.Height

	self.Width = Screen.Width
	self.Height = System.SafeAreaTop + height
	self.pos.Y = Screen.Height - self.Height

	cubzhBtn.pos.X = self.Width - Screen.SafeArea.Right - cubzhBtn.Width
	connBtn.pos.X = cubzhBtn.pos.X - connBtn.Width

	-- PROFILE BUTTON

	profileFrame.Height = height
	profileFrame.Width = profileFrame.Height

	-- FRIENDS BUTTON

	friendsBtn.Height = height
	friendsBtn.Width = friendsBtn.Height - (PADDING_BIG - PADDING) * 2
	friendsBtn.pos.X = profileFrame.pos.X + profileFrame.Width

	-- CHAT BUTTON

	chatBtn.Height = height
	chatBtn.pos.X = friendsBtn.pos.X + friendsBtn.Width
	chatBtn.Width = connBtn.pos.X - chatBtn.pos.X

	-- CHAT MESSAGES

	if topBarChat then
		local topBarHeight = self.Height - System.SafeAreaTop
		topBarChat.Height = topBarHeight - PADDING
		if textBubbleShape:isVisible() then
			topBarChat.Width = chatBtn.Width - PADDING * 3 - textBubbleShape.Width
			topBarChat.pos.X = textBubbleShape.Width + PADDING * 2
		else
			topBarChat.Width = chatBtn.Width - PADDING * 2
			topBarChat.pos.X = PADDING
		end
		topBarChat.pos.Y = PADDING
	end
end
topBar:parentDidResize()

-- BOTTOM BAR

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
	return titleScreen ~= nil
		or activeModal ~= nil
		or alertModal ~= nil
		or loadingModal ~= nil
		or cppMenuIsActive
		or signupElements ~= nil
end

function menuSectionCanBeShown()
	if System.Authenticated == false then
		return false
	end
	if topBar:isVisible() == false then
		return false
	end
	if menu:IsActive() then
		return false
	end
	return true
end

---@function Show Shows Cubzh menu if possible. (if user is authenticated, and menu not already active)
--- Returns true on success, false otherwise.
---@code local menu = require("menu")
--- menu:Show() -- shows Cubzh menu
---@return boolean
menu.Show = function(_)
	if menuSectionCanBeShown() == false then
		return false
	end
	cubzhBtn:onRelease()
	return true
end

---@function Highlight Highlights Cubzh menu button in the top bar if possible. (if user is authenticated, and menu not already active)
--- Returns true on success, false otherwise.
---@code local menu = require("menu")
--- menu:Highlight()
---@return boolean
menu.Highlight = function(_)
	if menuSectionCanBeShown() == false then
		return false
	end
	if pointer == nil then
		pointer = uiPointer:create({ uikit = ui })
	end
	pointer:pointAt({ target = cubzhBtn, from = "below" })
	return true
end

---@function RemoveHighlight Stops highlighting elements in the menu.
---@code local menu = require("menu")
--- menu:RemoveHighlight()
menu.RemoveHighlight = function(_)
	if pointer ~= nil then
		pointer:remove()
		pointer = nil
	end
end

---@function ShowFriends Shows friends menu if possible. (if user is authenticated, and menu not already active)
--- Returns true on success, false otherwise.
---@code local menu = require("menu")
--- menu:ShowFriends() -- shows friends menu
---@return boolean
menu.ShowFriends = function(_)
	if menuSectionCanBeShown() == false then
		return false
	end
	friendsBtn:onRelease()
	return true
end

---@function HighlightFriends Highlights friends button in the top bar if possible. (if user is authenticated, and menu not already active)
--- Returns true on success, false otherwise.
---@code local menu = require("menu")
--- menu:HighlightFriends()
---@return boolean
menu.HighlightFriends = function(_)
	if menuSectionCanBeShown() == false then
		return false
	end
	if pointer == nil then
		pointer = uiPointer:create({ uikit = ui })
	end
	pointer:pointAt({ target = friendsBtn, from = "below" })

	return true
end

---@function ShowProfile Shows local user profile menu if possible. (if user is authenticated, and menu not already active)
--- Returns true on success, false otherwise.
---@code local menu = require("menu")
--- menu:ShowProfile() -- shows local user profile menu
---@return boolean
menu.ShowProfile = function(_)
	if menuSectionCanBeShown() == false then
		return false
	end
	profileFrame:onRelease()
	return true
end

---@function HighlightProfile Highlights local user profile button in the top bar if possible. (if user is authenticated, and menu not already active)
--- Returns true on success, false otherwise.
---@code local menu = require("menu")
--- menu:HighlightProfile()
---@return boolean
menu.HighlightProfile = function(_)
	if menuSectionCanBeShown() == false then
		return false
	end
	if pointer == nil then
		pointer = uiPointer:create({ uikit = ui })
	end
	pointer:pointAt({ target = profileFrame, from = "below" })
	return true
end

---@function ShowWorlds Shows the world gallery if possible. (if user is authenticated, and menu not already active)
--- Returns true on success, false otherwise.
---@code local menu = require("menu")
--- menu:ShowWorlds() -- shows worlds gallery
---@return boolean
menu.ShowWorlds = function(_)
	if menuSectionCanBeShown() == false then
		return false
	end
	showModal(MODAL_KEYS.WORLDS)
	return true
end

---@function ShowItems Shows the item gallery if possible. (if user is authenticated, and menu not already active)
--- Returns true on success, false otherwise.
---@code local menu = require("menu")
--- menu:ShowItems() -- shows items gallery
---@return boolean
menu.ShowItems = function(_)
	if menuSectionCanBeShown() == false then
		return false
	end
	showModal(MODAL_KEYS.ITEMS)
	return true
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

	if cppMenuIsActive then
		ui:turnOff()
	else
		ui:turnOn()
	end

	refreshDisplay()
	triggerCallbacks()
	refreshChat()
end)

LocalEvent:Listen(LocalEvent.Name.ServerConnectionSuccess, function()
	connectionIndicatorValid()
	if Client.ServerConnectionSuccess then
		Client.ServerConnectionSuccess()
	end
end)

LocalEvent:Listen(LocalEvent.Name.ServerConnectionFailed, function()
	if Client.ServerConnectionFailed then
		Client.ServerConnectionFailed()
	end
	startConnectTimer()
end)

LocalEvent:Listen(LocalEvent.Name.ServerConnectionLost, function()
	if Client.ServerConnectionLost then
		Client.ServerConnectionLost()
	end
	startConnectTimer()
end)

LocalEvent:Listen(LocalEvent.Name.ServerConnectionStart, function()
	if Client.ConnectingToServer then
		Client.ConnectingToServer()
	end
end)

LocalEvent:Listen(LocalEvent.Name.LocalAvatarUpdate, function(updates)
	if updates.skinColors ~= nil and avatar ~= nil then
		avatarModule:setHeadColors(
			avatar,
			updates.skinColors.skin1,
			updates.skinColors.skin2,
			updates.skinColors.nose,
			updates.skinColors.mouth
		)
	end

	if type(updates.eyesColor) == Type.Color and avatar ~= nil then
		avatarModule:setEyesColor(avatar, updates.eyesColor)
	end

	if type(updates.noseColor) == Type.Color and avatar ~= nil then
		avatarModule:setNoseColor(avatar, updates.noseColor)
	end

	if type(updates.mouthColor) == Type.Color and avatar ~= nil then
		avatarModule:setMouthColor(avatar, updates.mouthColor)
	end

	if updates.outfit == true then
		avatar:remove()
		avatar = uiAvatar:getHeadAndShoulders(Player.Username, cubzhBtn.Height, nil, ui)
		avatar.parentDidResize = btnContentParentDidResize
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

function magicKeyCheck(callbacks)
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
		System:RemoveAskedForMagicKey()
		if callbacks.err ~= nil then
			callbacks.err()
		end
	else
		if callbacks.success ~= nil then
			callbacks.success()
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

		local accountInfo = res

		if accountInfo.hasDOB == false or accountInfo.hasUsername == false then
			if callbacks.accountIncomplete then
				callbacks.accountIncomplete()
			end
			return
		end

		if System.Under13DisclaimerNeedsApproval then
			if callbacks.under13DisclaimerNeedsApproval then
				callbacks.under13DisclaimerNeedsApproval()
				return
			end
		end

		-- NOTE: accountInfo.hasPassword could be false here
		-- for some accounts created pre-0.0.52.
		-- (mandatory after that)

		if callbacks.success then
			callbacks.success()
		end
	end)
end

-- temporary measure, while we implement parental contral
function isChatAvailable()
	if System.IsUserUnder13 and Client.IsMobile then
		return false
	end
	return true
end

signupElements = nil

-- callbacks: success, cancel, error
function showSignUp(callbacks)
	local helpBtn = ui:createButton("👾 Need help?", { textSize = "small", borders = false })
	helpBtn:setColor(Color(0, 0, 0, 0.4), Color(255, 255, 255))
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

	local loginBtn = ui:createButton("Login", { textSize = "small", borders = false })
	loginBtn:setColor(Color(0, 0, 0, 0.4), Color(255, 255, 255))
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
		System.Login(function(success, _)
			if success then
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

	signupModal.onSubmit = function(username, key, dob)
		System:DebugEvent("SIGNUP_SUBMIT")

		loginBtn:remove()
		helpBtn:remove()
		signupElements = nil

		signupModal.didClose = nil
		signupModal:close()
		signupModal = nil

		local function _createAccount(onError)
			showLoading("Creating account")
			api:signUp(username, key, dob, function(err, credentials)
				if err ~= nil then
					if onError ~= nil then
						hideLoading()
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

	Client:HapticFeedback()

	hideTitleScreen()
	hideBottomBar()

	local flow = {}

	flow.restartSignUp = function()
		showTitleScreen()
		skipTitleScreen()
	end

	flow.startPlaying = function()
		hideLoading()
		showTopBar()
		hideBottomBar()
		authCompleted()
	end

	flow.versionCheck = function()
		showLoading("Checking app version")
		versionCheck({
			success = flow.magicKeyCheck,
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
		})
	end

	flow.magicKeyCheck = function()
		magicKeyCheck({
			success = flow.accountCheck,
			err = flow.restartSignUp,
		})
	end

	flow.accountCheck = function()
		accountCheck({
			success = flow.startPlaying,
			loggedOut = flow.showSignUp, -- not supposed to happen after successful signup
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
						flow.restartSignUp()
					end,
					positiveLabel = "Create a new account",
				})
			end,
			under13DisclaimerNeedsApproval = function()
				hideLoading()
				showAlert({
					message = "⚠️ Be safe online! ⚠️\n\nDo NOT share personal details, watch out for phishing, scams and always think about who you're talking to.\n\nIf anything goes wrong, talk to someone you trust. 🙂",
					positiveLabel = "Yes sure!",
					positiveCallback = function()
						System.ApproveUnder13Disclaimer()
						flow.startPlaying()
					end,
					neutralLabel = "I'm not ready.",
					neutralCallback = function()
						showTitleScreen()
					end,
				})
			end,
		})
	end

	flow.showSignUp = function()
		System:DebugEvent("SKIP_SPLASHSCREEN_WITH_NO_ACCOUNT")
		hideLoading()
		showSignUp({
			success = flow.accountCheck,
			error = showTitleScreen,
			cancel = showTitleScreen,
		})
	end

	flow.versionCheck() -- start with version check
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

	triggerCallbacks()
end

-- sign up / sign in flow

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

getWorldInfoReq = nil
function getWorldInfo()
	if getWorldInfoReq ~= nil then
		getWorldInfoReq:Cancel()
		getWorldInfoReq = nil
	end
	if Environment.worldId ~= nil then
		getWorldInfoReq = api:getWorld(Environment.worldId, { "likes", "liked" }, function(err, world)
			if err ~= nil then
				return
			end
			nbLikes = world.likes
			liked = world.liked
			actionColumnUpdateContent()
		end)
	end
end

Timer(0.1, function()
	menu:OnAuthComplete(function()
		System:UpdateAuthStatus()

		if System.IsUserUnder13 then
			local under13BadgeShape = System.ShapeFromBundle("aduermael.under13_badge")
			under13Badge = ui:createShape(under13BadgeShape)
			under13Badge:setParent(profileFrame)
			local ratio = under13Badge.Width / under13Badge.Height
			under13Badge.Height = 10
			under13Badge.Width = under13Badge.Height * ratio
			under13Badge.parentDidResize = function(self)
				local parent = self.parent
				self.pos = { parent.Width - self.Width - PADDING * 0.5, PADDING * 0.5 }
				under13BadgeShape.LocalPosition.Z = 50
			end
			under13Badge:parentDidResize()
		end

		if System.HasEmail == false then
			showBadge("!")
		end

		if isChatAvailable() == false then
			textBubbleShape:hide()
		end

		getWorldInfo()

		-- connects client to server if it makes sense (maxPlayers > 1)
		connect()

		avatar:remove()
		avatar = uiAvatar:getHeadAndShoulders(Player.Username, cubzhBtn.Height, nil, ui)
		avatar.parentDidResize = btnContentParentDidResize
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
	end)
end)

return menu
