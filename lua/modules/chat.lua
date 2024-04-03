local MAX_MESSAGES = 50
local MAX_MESSAGES_IN_CONSOLE = 50

-- NOTE: engine (or server for chat messages) should provide the timestamps
local getCurrentDate = function()
	return os.date("%m-%d-%YT%H:%M:%SZ", os.time())
end

local chat = {}
local index = {}
local chatMetatable = {
	__index = index,
}
setmetatable(chat, chatMetatable)

local logs = {}
local lastCommandIndex = nil

function getDefaultConfig()
	if defaultConfig then
		return defaultConfig
	end
	defaultConfig = {
		uikit = require("uikit"), -- allows to provide specific instance of uikit
		input = true,
		maxMessages = MAX_MESSAGES_IN_CONSOLE,
		time = true,
		heads = true,
		onSubmitEmpty = function() end,
		onFocus = function() end,
		onFocusLost = function() end,
		inputText = "",
		theme = require("uitheme").current,
	}
	return defaultConfig
end

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
	if #logs < 60 then
		return
	end
	logs = getLastXElements(logs, 40)
end)

local logTypes = {
	Info = 1,
	Warning = 2,
	Error = 3,
	ChatMessage = 4,
	PrivateChatMessage = 5, -- whispering something to someone
}

-- TODO: move colors in theme module
-- same order as logLevels to be able to do logLevelColors[logLevels.Info]
local logTypeColors = {
	Color(30, 215, 96), -- Info
	Color.White, -- Warning
	Color.White, -- Error
	Color.White, -- ChatMessage
	Color(17, 169, 255), -- PrivateChatMessage (whispering)
}

local pushFormattedLog = function(msg)
	table.insert(logs, msg)
	while #logs > MAX_MESSAGES do
		table.remove(logs, 1) -- pop front
	end
	LocalEvent:Send(LocalEvent.Name.Log, msg)
end

local playerSendMessage = function(message)
	local recipients = OtherPlayers

	-- set to nil to reset commands history index
	lastCommandIndex = nil

	-- check if command
	local channelCommand = string.sub(message, 1, 3)
	local channelCommandDev = string.sub(message, 1, 4)
	if not Dev.CanRunCommands and (channelCommand == "/w ") or Dev.CanRunCommands and (channelCommandDev == "//w ") then
		local mode = Dev.CanRunCommands and string.sub(message, 3, 3) or string.sub(message, 2, 2)
		message = Dev.CanRunCommands and string.sub(message, 5, #message) or string.sub(message, 4, #message)

		if mode == "w" then -- whisper
			local receiver = { username = string.gmatch(message, "%S+")() }
			-- find player to send message only to this client
			recipients = {}
			for _, p in pairs(Players) do
				if p.Username == receiver.username then
					if p == Player then
						LocalEvent:Send(LocalEvent.Name.WarningMessage, "You are trying to send a message to yourself.")
						return
					end
					table.insert(recipients, p)
					receiver.id = p.ID
					receiver.userID = p.UserID
				end
			end
			if #recipients == 0 then
				LocalEvent:Send(LocalEvent.Name.InfoMessage, receiver.username .. " is not connected.")
				return
			end
			-- remove receiver's name from message
			message = string.sub(message, 2 + #receiver.username, #message)
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

	if message ~= payload.message then
		-- message has been modified within OnChat, do not send it on behalf of user
		return
	end

	System:SendChatMessage(message, recipients)
end

-- creates uikit node containing chat console and input
local createChat = function(_, config)
	config = require("config"):merge(getDefaultConfig(), config)

	local ui = config.uikit
	local theme = config.theme

	local space = ui:createText(" ", Color.White, "small")
	space:setParent(nil)

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

	local createUIChatMessage = function(log, ui)
		local node = ui:createFrame(Color(0, 0, 0, 0))
		local message = log.message
		local color = logTypeColors[log.type]

		node.message = message

		-- Time: [10:00]
		-- Prefix: empty by default, can be "to"/"from"
		-- Head: empty by default, shape of the head of the player
		-- Firstline: message, if too wide, cut the end
		local uiTextTime = ui:createText("", color, "small")

		if config.time then
			uiTextTime.Text = "[" .. string.sub(log.date, 12, 16) .. "] " -- get HH:MM
		end

		local uiTextMessageFirstLine = ui:createText("", color, "small")

		if log.senderUsername then
			message = log.senderUsername .. ": " .. message
		end

		local uiHead
		if config.heads then
			if log.senderUserID or log.senderUsername then
				uiHead = require("ui_avatar"):getHead(
					log.senderUserID or log.senderUsername,
					nil,
					ui,
					{ spherized = true } -- TODO: use false, but ui_avatar needs to be fixed
				)
			end
		end

		uiTextMessageFirstLine.Text = message

		local uiElements = {
			uiTextTime = uiTextTime,
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

			if uiHead then
				uiHead.pos.Y = uiTextTime.pos.Y + uiTextTime.Height * 0.5 - uiHead.Height * 0.5
			end
			uiTextMessageFirstLine.pos.Y = node.Height - uiTextMessageFirstLine.Height
		end
		node:parentDidResize()

		if hasInput then
			node.onRelease = function()
				local username = (log.receiver and log.receiver.username or log.sender.username)
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
	for _, msgInfo in ipairs(logs) do
		pushMessage(msgInfo)
	end

	local messageListener = LocalEvent:Listen(LocalEvent.Name.Log, function(msgInfo)
		pushMessage(msgInfo)
	end)

	node.onRemove = function(_)
		messageListener:Remove()
	end

	return node
end

local createModalContent = function(_, config)
	local modal = require("modal")

	config = require("config"):merge(getDefaultConfig(), config)

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

LocalEvent:Listen(LocalEvent.Name.OnPlayerJoin, function(p)
	require("ui_avatar"):preloadHeads(p)
end)

LocalEvent:Listen(
	LocalEvent.Name.ChatMessage,
	function(msg, senderID, senderUserID, senderUsername, status, uuid, localUUID)
		if not msg then
			return
		end
		pushFormattedLog({
			type = logTypes.ChatMessage,
			message = msg,
			date = getCurrentDate(),
			senderID = senderID, -- connection ID, not reliable if player comes and goes
			senderUserID = senderUserID,
			senderUsername = senderUsername,
			status = status,
			uuid = uuid,
			localUUID = localUUID,
		})
	end
)

LocalEvent:Listen(LocalEvent.Name.InfoMessage, function(msg)
	if not msg then
		return
	end
	-- System:Log(msg)
	-- NOTE: engine should provide the timestamp
	pushFormattedLog({ type = logTypes.Info, message = msg, date = getCurrentDate() })
end)

LocalEvent:Listen(LocalEvent.Name.WarningMessage, function(msg)
	if not msg then
		return
	end
	-- System:Log("⚠️ " .. msg)
	-- NOTE: engine should provide the timestamp
	pushFormattedLog({ type = logTypes.Warning, message = "⚠️ " .. msg, date = getCurrentDate() })
end)

LocalEvent:Listen(LocalEvent.Name.ErrorMessage, function(msg)
	if not msg then
		return
	end
	-- System:Log("❌ " .. msg)
	-- NOTE: engine should provide the timestamp
	pushFormattedLog({ type = logTypes.Error, message = "❌ " .. msg, date = getCurrentDate() })
end)

-- expose functions
chat.createModalContent = createModalContent
chat.create = createChat

return chat
