mod = {}

mod.createModalContent = function(_, config)
	local modal = require("modal")
	local theme = require("uitheme")
	local loc = require("localize")
	local str = require("str")
	local api = require("system_api", System)

	local usernameSetRequest
	local usernameCheckRequest
	local userCheckTimer

	local function cancelTimersAndRequests()
		if usernameCheckRequest ~= nil then
			usernameCheckRequest:Cancel()
			usernameCheckRequest = nil
		end

		if userCheckTimer ~= nil then
			userCheckTimer:Cancel()
			userCheckTimer = nil
		end
		if usernameSetRequest then
			usernameSetRequest:Cancel()
			usernameSetRequest = nil
		end
	end

	local username
	local usernameKey

	local defaultConfig = {
		uikit = require("uikit"),
	}

	ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config)
	end)

	if not ok then
		error("usernameForm:createModalContent(config) - config error: " .. err, 2)
	end

	local ui = config.uikit

	local node = ui:createFrame()

	local content = modal:createContent()
	content.title = ""
	content.icon = "🙂"
	content.node = node

	local text = ui:createText("Ready to pick a username?", Color.White, "default")
	text:setParent(node)

	local instructions =
		ui:createText("It must start with a letter (a-z) and can include letters (a-z) and numbers (0-9).", {
			color = Color(200, 200, 200),
			size = "small",
		})
	instructions:setParent(node)

	local statusMessage = ui:createText("...", {
		color = Color.White,
		size = "small",
	})
	statusMessage:setParent(nil)

	local loading = require("ui_loading_animation"):create({ ui = ui })
	loading:setParent(nil)

	local function showStatusMessage(str)
		statusMessage.Text = str
		statusMessage.pos = {
			instructions.pos.X + instructions.Width * 0.5 - statusMessage.Width * 0.5,
			instructions.pos.Y + instructions.Height * 0.5 - statusMessage.Height * 0.5,
		}
		instructions:setParent(nil)
		loading:setParent(nil)
		statusMessage:setParent(node)
	end

	local function showLoading()
		instructions:setParent(nil)
		loading:setParent(node)
		statusMessage:setParent(nil)
	end

	local function showInstructions()
		instructions:setParent(node)
		loading:setParent(nil)
		statusMessage:setParent(nil)
	end

	local warning = ui:createText("⚠️ Choose carefully, this username can't be changed afterwards.", {
		color = Color(251, 206, 0),
		size = "small",
	})
	warning:setParent(node)

	local confirmButton = ui:buttonPositive({
		content = "This is it!",
		padding = 10,
	})
	confirmButton:setParent(node)
	confirmButton:disable()

	local usernameInput = ui:createTextInput(
		"",
		str:upperFirstChar(loc("don't use your real name!")),
		{ textSize = "default", bottomMargin = confirmButton.Height + theme.padding * 2 }
	)
	usernameInput:setParent(node)

	local function refresh()
		text.object.MaxWidth = node.Width - theme.padding * 4
		instructions.object.MaxWidth = node.Width - theme.padding * 4
		warning.object.MaxWidth = node.Width - theme.padding * 4
		statusMessage.object.MaxWidth = node.Width - theme.padding * 4

		confirmButton.pos = {
			node.Width * 0.5 - confirmButton.Width * 0.5,
			theme.padding,
		}

		usernameInput.Width = node.Width - theme.padding * 2
		usernameInput.pos = {
			node.Width * 0.5 - usernameInput.Width * 0.5,
			confirmButton.pos.Y + confirmButton.Height + theme.padding,
		}

		instructions.pos = {
			node.Width * 0.5 - instructions.Width * 0.5,
			usernameInput.pos.Y + usernameInput.Height + theme.padding,
		}

		warning.pos = {
			node.Width * 0.5 - warning.Width * 0.5,
			instructions.pos.Y + instructions.Height + theme.padding,
		}

		text.pos = {
			node.Width * 0.5 - text.Width * 0.5,
			warning.pos.Y + warning.Height + theme.padding,
		}

		statusMessage.pos = {
			instructions.pos.X + instructions.Width * 0.5 - statusMessage.Width * 0.5,
			instructions.pos.Y + instructions.Height * 0.5 - statusMessage.Height * 0.5,
		}

		loading.pos = {
			instructions.pos.X + instructions.Width * 0.5 - loading.Width * 0.5,
			instructions.pos.Y + instructions.Height * 0.5 - loading.Height * 0.5,
		}
	end

	usernameInput.onTextChange = function(self)
		confirmButton:disable()

		-- disable onTextChange while we normalize the text
		local backup = self.onTextChange
		self.onTextChange = nil

		local s = str:normalize(self.Text)
		s = str:lower(s)
		self.Text = s

		-- re-enable onTextChange
		self.onTextChange = backup

		showLoading()
		cancelTimersAndRequests()

		if s == "" then
			showInstructions()
		else
			-- use timer to avoid spamming the API
			userCheckTimer = Timer(1.0, function()
				-- check username
				usernameCheckRequest = api:checkUsername(s, function(ok, response)
					statusMessage:setParent(node)
					loading:setParent(nil)

					if ok == false or response == nil then
						showStatusMessage("❌ failed to validate username")
					else
						if response.format == false then
							showStatusMessage("❌ invalid format")
						elseif response.available == false then
							showStatusMessage("❌ username already taken")
						elseif response.appropriate == false then
							showStatusMessage("❌ username is inappropriate")
						else
							showStatusMessage("✅ username is available")
							username = s
							usernameKey = response.key
							confirmButton:enable()
						end
					end
				end)
			end)
		end

		-- System:DebugEvent("User edits username in text input", { username = self.Text })
	end

	confirmButton.onRelease = function()
		cancelTimersAndRequests()
		showLoading()
		usernameInput:disable()

		System:DebugEvent("User presses OK button to submit username", { username = usernameInput.Text })

		usernameSetRequest = api:patchUserInfo({ username = username, usernameKey = usernameKey }, function(err)
			if err ~= nil then
				System:DebugEvent("Request to set username fails")
				showStatusMessage("❌ " .. err)
				usernameInput:enable()
				return
			end
			-- success
			System.Username = username
		end)
	end

	content.idealReducedContentSize = function(_, width, height)
		node.Width = width
		refresh()

		local h = math.min(
			height,
			confirmButton.Height
				+ usernameInput.Height
				+ text.Height
				+ instructions.Height
				+ warning.Height
				+ theme.padding * 4
		)
		return Number2(width, h)
	end

	return content
end

return mod
