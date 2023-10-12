
ui = require("uikit")
theme = require("uitheme").current
modal = require("modal")

-- Preload heads of current players
require("ui_avatar"):preloadHeads(Players)

local getCurrentDate = function()
	return os.date("%m-%d-%YT%H:%M:%SZ", os.time())
end

local chat = {}
local index = {}
local chatMetatable = {
	__index = index
}
setmetatable(chat, chatMetatable)

local messages = {}
local lastCommandIndex = nil

local function getLastXElements(array, x) local result, length = {}, #array for i = length, math.max(length - x + 1, 1), -1 do table.insert(result, array[i]) end return result end

Timer(10, true, function()
	if #messages < 60 then return end
	messages = getLastXElements(messages,40)
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
	Color.White,        -- Local
	Color.LightGrey,    -- Global
	Color(17,169,255),  -- Private
	Color.White,        -- Warning
	Color.White,        -- Error
}

local pushFormattedMessage = function(msgInfo)
	table.insert(messages, msgInfo)
	LocalEvent:Send("did_receive_chat_message", msgInfo)
end

local createModalContent = function(_, config)

	-- default config
	local _config = {
		uikit = ui, -- allows to provide specific instance of uikit
	}

	if config then
		for k, v in pairs(_config) do
			if type(config[k]) == type(v) then _config[k] = config[k] end
		end
	end

	local ui = _config.uikit

	local node = ui:createFrame(Color(0.0,0.0,0.0,0.0))

	local content = modal:createContent()
	content.messages = {}
	content.closeButton = true

	content.idealReducedContentSize = function(_, width, height)
		return Number2(width, height)
	end

	content.node = node
	content.title = "Chat"
	content.icon = "💬"

	local messagesNode = ui:createFrame(Color(0,0,0,0))
	messagesNode:setParent(node)

	local inputNode = ui:createTextInput("", "type message")
	inputNode:setParent(node)
	inputNode:focus()

	local sendButton = ui:createButton("💬")
	sendButton:setParent(node)
	sendButton:setColor(Color.Blue)

	local createUIChatMessage = function(data, ui)

		local node = ui:createFrame(Color(0,0,0,0))
		local message = data.message
		local color = channelsColors[data.type]

		node.message = message

		-- Time: [10:00]
		-- Prefix: empty by default, can be "to"/"from"
		-- Head: empty by default, shape of the head of the player
		-- Firstline: message, if too wide, cut the end
		local uiTextTime = ui:createText("[00:00]", color)
		local uiTextPrefix
		local uiTextMessageFirstLine = ui:createText("", color)

		uiTextTime.Text = "[" .. string.sub(data.date, 12, 16) .. "]" -- get HH:MM

		-- format msg and add prefix if needed
		if data.receiver then
			if data.sender.id == Player.UserID then
				uiTextPrefix = ui:createText("to", color)
				message = data.receiver.username .. ": " .. message
			elseif data.receiver.id == Player.UserID then
				uiTextPrefix = ui:createText("from", color)
				message = data.sender.username .. ": " .. message
			end
		elseif data.sender then
			message = data.sender.username .. ": " .. message
		end

		local uiHead
		local playerInfo = data.receiver or data.sender
		if playerInfo then
			if data.receiver.id == Player.UserID then
				playerInfo = data.sender
			end
			uiHead = require("ui_avatar"):getHead(playerInfo.id or playerInfo.username, nil, ui)
		end

		uiTextMessageFirstLine.Text = message

		local uiElements = {
			uiTextTime = uiTextTime,
			uiTextPrefix = uiTextPrefix,
			uiHead = uiHead,
			uiTextMessageFirstLine = uiTextMessageFirstLine
		}
		for _,elem in pairs(uiElements) do
			elem:setParent(node)
		end

		node.parentDidResize = function(node)
			if not node.parent then return end
			node.Width = node.parent.Width

			local x = theme.padding -- shift X

			uiTextTime.LocalPosition.X = x
			x = x + uiTextTime.Width + theme.padding

			if uiTextPrefix then
				uiTextPrefix.LocalPosition.X = x
				x = x + uiTextPrefix.Width + theme.padding
			end
			if uiHead then
				uiHead.Width = uiTextTime.Height * 1.7
				uiHead.LocalPosition.X = x
				uiHead.LocalPosition.Z = -20 -- fix layering
				x = x + uiHead.Width + theme.padding
			end
			uiTextMessageFirstLine.LocalPosition.X = x

			uiTextMessageFirstLine.Width = node.Width - x
			uiTextMessageFirstLine.object.MaxWidth = node.Width - x

			node.Height = uiTextMessageFirstLine.Height

			uiTextTime.LocalPosition.Y = node.Height - uiTextTime.Height
			if uiHead then
				uiHead.LocalPosition.Y = uiTextTime.LocalPosition.Y - 5 - (uiTextTime.Height - 8) / 8
			end
		end
		node:parentDidResize()

		node.onRelease = function()
			local username = (data.receiver and data.receiver.username or data.sender.username)
			if not username then return end
			if inputNode.Text then
				inputNode.Text = "/w "..username.." "
				inputNode:focus()
			end
		end

		return node
	end

	local playerSendMessage = function(message)
		local channelType = channels.Local
		local recipients = OtherPlayers
		local msgInfo = {
			sender = { id = Player.UserID, username = Player.Username },
			date = getCurrentDate()
		}

		-- set to nil to reset commands history index
		lastCommandIndex = nil

		-- check if command
		local channelCommand = string.sub(message,1,3)
		if channelCommand == "/a " or channelCommand == "/l " or channelCommand == "/w " then
			local channel = string.sub(message, 2, 2)
			channelType = commandsToChannel[channel]
			message = string.sub(message, 4, #message)

			if channelType == channels.Private then
				msgInfo.receiver = { username = string.gmatch(message, "%S+")() }
				-- find player to send message only to this client
				recipients = {}
				for _,p in pairs(Players) do
					if p.Username == msgInfo.receiver.username then
						if p == Player then
							LocalEvent:Send(LocalEvent.Name.WarningMessage, "You are trying to send a message to yourself.")
							return
						end
						table.insert(recipients, p)
						msgInfo.receiver.id = p.UserID
					end
				end
				if #recipients == 0 then
					LocalEvent:Send(LocalEvent.Name.InfoMessage, msgInfo.receiver.username .. " is not currently in your game.")
					return
				end
				message = string.sub(message, 2 + #msgInfo.receiver.username, #message)
			end
		elseif string.sub(message,1,1) == "/" then
			local str = string.sub(message,2,#message)
			System:AddCommandInHistory(message)
			if Dev.CanRunCommands then
				System:ExecCommand(str)
			else
				print("⚠️ not authorized to run commands")
			end
			return
		end

		msgInfo.type = channelType
		msgInfo.message = message

		local payload = {}
		local metatablePayload = {}
		metatablePayload.__index = {
			message = message
		}
		metatablePayload.__metatable = false
		metatablePayload.__newindex = function(_,k,v)
			if k ~= "message" then error("payload."..k.." can't be set.", 2) return end
			if type(v) ~= Type.string then error("payload.message can only be a string") return end
			metatablePayload.__index.message = v
		end
		setmetatable(payload, metatablePayload)

		local catched = LocalEvent:Send(LocalEvent.name.OnChat, payload)
		if catched then return end

		msgInfo.message = payload.message
		if msgInfo.message == nil then return end

		local e = Event()
		e.action = "chatMsg"
		e.content = JSON:Encode(msgInfo)
		e:SendTo(recipients)
		pushFormattedMessage(msgInfo)
	end

	local funcSendMessage = function()
		if #inputNode.Text < 1 then			local modal = content:getModalIfContentIsActive()
			if modal then modal:close() end
			return		end
		local text = inputNode.Text
		inputNode.Text = ""
		playerSendMessage(text)
		node:parentDidResize()
	end
	inputNode.onSubmit = funcSendMessage
	inputNode.onTextChange = function()
		if lastCommandIndex ~= nil then
			if inputNode.Text ~= System:GetCommandFromHistory(lastCommandIndex) then
				lastCommandIndex = nil
			end
		end
	end
	inputNode.onUp = function(self)
		if System.NbCommandsInHistory == 0 then return end
		lastCommandIndex = lastCommandIndex == nil and 1 or math.min(System.NbCommandsInHistory, lastCommandIndex + 1)
		if lastCommandIndex > 0 then
			self.Text = System:GetCommandFromHistory(lastCommandIndex)
		end
	end
	inputNode.onDown = function(self)
		if lastCommandIndex == nil then return end
		lastCommandIndex = lastCommandIndex - 1
		if lastCommandIndex < 1 then
			lastCommandIndex = nil
			self.Text = ""
			return
		end
		self.Text = System:GetCommandFromHistory(lastCommandIndex)
	end

	sendButton.onRelease = funcSendMessage

	node.parentDidResize = function(node)
		sendButton.pos = { node.Width - sendButton.Width - theme.padding, theme.padding, 0 }
		inputNode.Width = node.Width - sendButton.Width - theme.padding * 3
		inputNode.pos = { theme.padding, theme.padding, 0 }

		messagesNode.Width = node.Width
		messagesNode.Height = node.Height - inputNode.Height - theme.padding * 2
		messagesNode.pos = { 0, inputNode.Height + theme.padding * 2 , 0 }
		local shift = 0
		for i=#content.messages,1,-1 do
			local msg = content.messages[i]
			msg.pos.Y = shift
			if shift + msg.Height > messagesNode.Height then msg:hide() else msg:show() end
			shift = shift + msg.Height
		end
	end

	-- Add message in UI
	local pushMessage = function(messageInfo)
		local message = createUIChatMessage(messageInfo, ui)
		message:setParent(messagesNode)
		local height = message.Height
		for _,m in ipairs(content.messages) do
			m.LocalPosition.Y = m.LocalPosition.Y + height
			if m.LocalPosition.Y + m.Height > messagesNode.Height then m:hide() else m:show() end
		end
		table.insert(content.messages, message)
	end

	-- Push latest messages
	for _, msgInfo in ipairs(messages) do
		pushMessage(msgInfo)
	end

	local listener

	content.didBecomeActive = function(_)
		listener = LocalEvent:Listen("did_receive_chat_message", function(msgInfo)
			pushMessage(msgInfo)
		end)
	end

	content.willResignActive = function(_)
		if listener then listener:Remove() end
	end

	LocalEvent:Listen(LocalEvent.Name.SetChatTextInput, function(text)
		inputNode.Text = text
	end)

	return content
end

LocalEvent:Listen(LocalEvent.Name.DidReceiveEvent, function(e)
	if e.action ~= "chatMsg" then return false end
	local msgInfo = JSON:Decode(e.content)
	pushFormattedMessage(msgInfo)
	return true
end)

LocalEvent:Listen(LocalEvent.Name.OnPlayerJoin, function(p)
	require("ui_avatar"):preloadHeads(p)
end)

LocalEvent:Listen(LocalEvent.Name.InfoMessage, function(msg)
	if not msg then return end
	pushFormattedMessage({ type = channels.Info, message = msg, date = getCurrentDate() })
end)

LocalEvent:Listen(LocalEvent.Name.WarningMessage, function(msg)
	if not msg then return end
	pushFormattedMessage({ type = channels.Warning, message = "⚠️ " .. msg, date = getCurrentDate() })
end)

LocalEvent:Listen(LocalEvent.Name.ErrorMessage, function(msg)
	if not msg then return end
	pushFormattedMessage({ type = channels.Error, message = "❌ " .. msg, date = getCurrentDate() })
end)

chat.createModalContent = createModalContent

return chat
