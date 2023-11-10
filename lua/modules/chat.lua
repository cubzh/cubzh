local MAX_MESSAGES = 50
local MAX_MESSAGES_IN_CONSOLE = 50

ui = require("uikit")
theme = require("uitheme").current
modal = require("modal")

-- Preload heads of current players
require("ui_avatar"):preloadHeads(Players)

-- used to get the size of a space character
-- when assembling chat message components
space = ui:createText(" ", Color.White, "small")
space:setParent(nil)

local getCurrentDate = function()
	return os.date("%m-%d-%YT%H:%M:%SZ", os.time())
end

local chat = {}
local index = {}
local chatMetatable = {
	__index = index,
}
setmetatable(chat, chatMetatable)

local messages = {}
local lastCommandIndex = nil

local defaultConfig = {
	uikit = ui, -- allows to provide specific instance of uikit
	input = true,
	maxMessages = MAX_MESSAGES_IN_CONSOLE,
	time = true,
	heads = true,
	onSubmitEmpty = function() end,
	onFocus = function() end,
	onFocusLost = function() end,
	inputText = "",
}

local function getLastXElements(array, x)
	local result, length = {}, #array
	for i = length, math.max(length - x + 1, 1), -1 do
		table.insert(result, array[i])
	end
	return result
end

function trim(s)
	if type(s) ~= "string" then
		return ""
	end
	return s:gsub("^%s*(.-)%s*$", "%1")
end

Timer(10, true, function()
	if #messages < 60 then
		return
	end
	messages = getLastXElements(messages, 40)
end)

local channels = {
	Info = 1,
	Local = 2,
	Global = 3,
	Private = 4,
	Warning = 5,
	Error = 6,
}
chat.Channels = channels

local commandsToChannel = {
	a = 3,
	l = 2,
	w = 4,
}

-- TODO: move colors in theme module
local channelsColors = { -- same order as channels to be able to do channelsColors[channels.Info]
	Color(30, 215, 96), -- Info
	Color.White, -- Local
	Color.LightGrey, -- Global
	Color(17, 169, 255), -- Private
	Color.White, -- Warning
	Color.White, -- Error
}

local pushFormattedMessage = function(msgInfo)
	table.insert(messages, msgInfo)
	while #messages > MAX_MESSAGES do
		table.remove(messages, 1) -- pop front
	end
	LocalEvent:Send(LocalEvent.Name.ChatMessage, msgInfo)
end

local playerSendMessage = function(message)
	local channelType = channels.Local
	local recipients = OtherPlayers
	local msgInfo = {
		sender = { userID = Player.UserID, id = Player.ID, username = Player.Username },
		date = getCurrentDate(),
	}

	-- set to nil to reset commands history index
	lastCommandIndex = nil

	-- check if command
	local channelCommand = string.sub(message, 1, 3)
	local channelCommandDev = string.sub(message, 1, 4)
	if
		not Dev.CanRunCommands and (channelCommand == "/a " or channelCommand == "/l " or channelCommand == "/w ")
		or Dev.CanRunCommands
			and (channelCommandDev == "//a " or channelCommandDev == "//l " or channelCommandDev == "//w ")
	then
		local channel = Dev.CanRunCommands and string.sub(message, 3, 3) or string.sub(message, 2, 2)
		channelType = commandsToChannel[channel]
		message = Dev.CanRunCommands and string.sub(message, 5, #message) or string.sub(message, 4, #message)

		if channelType == channels.Private then
			msgInfo.receiver = { username = string.gmatch(message, "%S+")() }
			-- find player to send message only to this client
			recipients = {}
			for _, p in pairs(Players) do
				if p.Username == msgInfo.receiver.username then
					if p == Player then
						LocalEvent:Send(LocalEvent.Name.WarningMessage, "You are trying to send a message to yourself.")
						return
					end
					table.insert(recipients, p)
					msgInfo.receiver.id = p.ID
					msgInfo.receiver.userID = p.UserID
				end
			end
			if #recipients == 0 then
				LocalEvent:Send(
					LocalEvent.Name.InfoMessage,
					msgInfo.receiver.username .. " is not currently in your game."
				)
				return
			end
			message = string.sub(message, 2 + #msgInfo.receiver.username, #message)
		end
	elseif string.sub(message, 1, 1) == "/" then
		System:AddCommandInHistory(message)
		if not Dev.CanRunCommands then
			print("⚠️ not authorized to run commands")
			return
		end
		local command = string.sub(message, 2, #message)
		System:ExecCommand(command)
		return
	end

	msgInfo.type = channelType
	msgInfo.message = message

	local payload = {}
	local metatablePayload = {}
	metatablePayload.__index = {
		message = message,
	}
	metatablePayload.__metatable = false
	metatablePayload.__newindex = function(_, k, v)
		if k ~= "message" then
			error("payload." .. k .. " can't be set.", 2)
			return
		end
		if type(v) ~= Type.string then
			error("payload.message can only be a string")
			return
		end
		metatablePayload.__index.message = v
	end
	setmetatable(payload, metatablePayload)

	local catched = LocalEvent:Send(LocalEvent.name.OnChat, payload)
	if catched then
		return
	end

	msgInfo.message = payload.message
	if msgInfo.message == nil then
		return
	end

	local e = Event()
	e.action = "chatMsg"
	e.content = JSON:Encode(msgInfo)
	e:SendTo(recipients)
	pushFormattedMessage(msgInfo)
end

-- creates uikit node containing chat console and input
local createChat = function(_, config)
	config = require("config"):merge(defaultConfig, config)

	local ui = config.uikit

	local nodeMessages = {}

	local node = ui:createFrame(Color(0.0, 0.0, 0.0, 0.0))

	local messagesNode = ui:createFrame(Color(0, 0, 0, 0))
	messagesNode:setParent(node)

	local hasInput = config.input
	local inputNode

	if hasInput then
		inputNode = ui:createTextInput("", "say something…", { textSize = "small" })
		inputNode:setParent(node)
		inputNode:setColor(Color(0, 0, 0, 0.1), Color.White, Color(255, 255, 255, 0.7))
		inputNode:setColorPressed(Color(0, 0, 0, 0.4), Color.White, Color(255, 255, 255, 0.5))
		inputNode:setColorFocused(Color(0, 0, 0, 0.4), Color.White, Color(255, 255, 255, 0.5))

		inputNode.Text = config.inputText

		inputNode.onSubmit = function()
			local text = trim(inputNode.Text)
			if text == "" then
				config.onSubmitEmpty()
				return
			end
			inputNode.Text = ""
			playerSendMessage(text)
		end

		node.focus = function()
			inputNode:focus()
		end

		node.unfocus = function()
			inputNode:unfocus()
		end

		node.setText = function(_, text)
			if type(text) == "string" then
				inputNode.Text = text
			end
		end

		node.getText = function(_)
			return inputNode.Text or ""
		end

		node.hasFocus = function()
			return inputNode:hasFocus()
		end

		inputNode.onTextChange = function()
			if lastCommandIndex ~= nil then
				if inputNode.Text ~= System:GetCommandFromHistory(lastCommandIndex) then
					lastCommandIndex = nil
				end
			end
		end

		inputNode.onUp = function(self)
			if System.NbCommandsInHistory == 0 then
				return
			end
			lastCommandIndex = lastCommandIndex == nil and 1
				or math.min(System.NbCommandsInHistory, lastCommandIndex + 1)
			if lastCommandIndex > 0 then
				self.Text = System:GetCommandFromHistory(lastCommandIndex)
			end
		end

		inputNode.onDown = function(self)
			if lastCommandIndex == nil then
				return
			end
			lastCommandIndex = lastCommandIndex - 1
			if lastCommandIndex < 1 then
				lastCommandIndex = nil
				self.Text = ""
				return
			end
			self.Text = System:GetCommandFromHistory(lastCommandIndex)
		end

		inputNode.onFocus = function()
			config.onFocus()
		end

		inputNode.onFocusLost = function()
			config.onFocusLost()
		end
	end

	local createUIChatMessage = function(data, ui)
		local node = ui:createFrame(Color(0, 0, 0, 0))
		local message = data.message
		local color = channelsColors[data.type]

		node.message = message

		-- Time: [10:00]
		-- Prefix: empty by default, can be "to"/"from"
		-- Head: empty by default, shape of the head of the player
		-- Firstline: message, if too wide, cut the end
		local uiTextTime = ui:createText("", color, "small")

		if config.time then
			uiTextTime.Text = "[" .. string.sub(data.date, 12, 16) .. "] " -- get HH:MM
		end

		local uiTextPrefix
		local uiTextMessageFirstLine = ui:createText("", color, "small")

		-- format msg and add prefix if needed
		if data.receiver then
			if data.sender.id == Player.ID then
				uiTextPrefix = ui:createText("to", color, "small")
				message = data.receiver.username .. ": " .. message
			elseif data.receiver.id == Player.ID then
				uiTextPrefix = ui:createText("from", color, "small")
				message = data.sender.username .. ": " .. message
			end
		elseif data.sender then
			message = data.sender.username .. ": " .. message
		end

		local uiHead
		if config.heads then
			local playerInfo = data.receiver or data.sender
			if playerInfo then
				if data.receiver.id == Player.ID then
					playerInfo = data.sender
				end
				uiHead = require("ui_avatar"):getHead(
					playerInfo.userID or playerInfo.username,
					nil,
					ui,
					{ spherized = true } -- TODO: use false, but ui_avatar needs to be fixed
				)
			end
		end

		uiTextMessageFirstLine.Text = message

		local uiElements = {
			uiTextTime = uiTextTime,
			uiTextPrefix = uiTextPrefix,
			uiHead = uiHead,
			uiTextMessageFirstLine = uiTextMessageFirstLine,
		}
		for _, elem in pairs(uiElements) do
			elem:setParent(node)
		end

		node.parentDidResize = function(node)
			if not node.parent then
				return
			end

			node.Width = node.parent.Width

			local x = 0

			uiTextTime.pos.X = x
			x = x + uiTextTime.Width

			if uiTextPrefix then
				uiTextPrefix.pos.X = x
				x = x + uiTextPrefix.Width
			end
			if uiHead then
				uiHead.Width = space.Width * 2 -- size of an emoji
				uiHead.pos.X = x
				x = x + uiHead.Width + space.Width
			end
			uiTextMessageFirstLine.pos.X = x

			uiTextMessageFirstLine.Width = node.Width - x
			uiTextMessageFirstLine.object.MaxWidth = node.Width - x

			node.Height = uiTextMessageFirstLine.Height

			uiTextTime.pos.Y = node.Height - uiTextTime.Height
			if uiTextPrefix then
				uiTextPrefix.pos.Y = node.Height - uiTextPrefix.Height
			end
			if uiHead then
				uiHead.pos.Y = uiTextTime.pos.Y + uiTextTime.Height * 0.5 - uiHead.Height * 0.5
			end
			uiTextMessageFirstLine.pos.Y = node.Height - uiTextMessageFirstLine.Height
		end
		node:parentDidResize()

		if hasInput then
			node.onRelease = function()
				local username = (data.receiver and data.receiver.username or data.sender.username)
				if not username then
					return
				end
				if inputNode.Text then
					inputNode.Text = "/w " .. username .. " "
					-- inputNode:focus()
				end
			end
		end

		return node
	end

	messagesNode.parentDidResize = function()
		if hasInput then
			inputNode.Width = node.Width
			inputNode.pos = { 0, 0 }

			messagesNode.Width = node.Width - theme.paddingTiny * 2
			messagesNode.Height = node.Height - inputNode.Height - theme.padding
			messagesNode.pos = { theme.paddingTiny, inputNode.Height + theme.padding }
		else
			messagesNode.Width = node.Width
			messagesNode.Height = node.Height
			messagesNode.pos = { 0, 0 }
		end

		local shift = 0
		for i = #nodeMessages, 1, -1 do
			local msg = nodeMessages[i]
			msg.pos.Y = shift
			if shift + msg.Height > messagesNode.Height then
				msg:hide()
			else
				msg:show()
			end
			shift = shift + msg.Height
		end
	end

	-- Add message in UI
	local pushMessage = function(messageInfo)
		local message = createUIChatMessage(messageInfo, ui)
		message:setParent(messagesNode)
		local height = message.Height
		for _, m in ipairs(nodeMessages) do
			m.pos.Y = m.pos.Y + height
			if m.pos.Y + m.Height > messagesNode.Height then
				m:hide()
			else
				m:show()
			end
		end
		table.insert(nodeMessages, message)
		while #nodeMessages > config.maxMessages do
			local m = table.remove(nodeMessages, 1) -- pop front
			if m ~= nil then
				m:remove()
			end
		end
	end

	-- Push latest messages
	for _, msgInfo in ipairs(messages) do
		pushMessage(msgInfo)
	end

	local messageListener = LocalEvent:Listen(LocalEvent.Name.ChatMessage, function(msgInfo)
		pushMessage(msgInfo)
	end)

	node.onRemove = function(_)
		messageListener:Remove()
	end

	return node
end

local createModalContent = function(_, config)
	config = require("config"):merge(defaultConfig, config)

	local ui = config.uikit

	local content = modal:createContent()
	content.messages = {}
	content.closeButton = true

	content.idealReducedContentSize = function(_, width, height)
		return Number2(width, height)
	end

	content.node = createChat(nil, config)
	content.title = "Chat"
	content.icon = "💬"

	return content
end

LocalEvent:Listen(LocalEvent.Name.DidReceiveEvent, function(e)
	if e.action ~= "chatMsg" then
		return false
	end
	local msgInfo = JSON:Decode(e.content)
	pushFormattedMessage(msgInfo)
	return true
end)

LocalEvent:Listen(LocalEvent.Name.OnPlayerJoin, function(p)
	require("ui_avatar"):preloadHeads(p)
end)

LocalEvent:Listen(LocalEvent.Name.InfoMessage, function(msg)
	if not msg then
		return
	end
	pushFormattedMessage({ type = channels.Info, message = msg, date = getCurrentDate() })
end)

LocalEvent:Listen(LocalEvent.Name.WarningMessage, function(msg)
	if not msg then
		return
	end
	pushFormattedMessage({ type = channels.Warning, message = "⚠️ " .. msg, date = getCurrentDate() })
end)

LocalEvent:Listen(LocalEvent.Name.ErrorMessage, function(msg)
	if not msg then
		return
	end
	pushFormattedMessage({ type = channels.Error, message = "❌ " .. msg, date = getCurrentDate() })
end)

-- expose functions
chat.createModalContent = createModalContent
chat.create = createChat

return chat
