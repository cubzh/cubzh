local mod = {}

mod.createModal = function(_, config)
	local loc = require("localize")
	local str = require("str")
	local ui = require("uikit")
	local modal = require("modal")
	local theme = require("uitheme").current
	local ease = require("ease")
	local api = require("system_api", System)
	local conf = require("config")

	local defaultConfig = {
		uikit = ui,
	}

	config = conf:merge(defaultConfig, config)

	ui = config.uikit

	local function idealReducedContentSize(content, _, _)
		if content.refresh then
			content:refresh()
		end
		return Number2(content.Width, content.Height)
	end

	local getMagicKeyInputContent = function(usernameOrEmail)
		local content = modal:createContent({ uikit = ui })
		content.idealReducedContentSize = idealReducedContentSize

		local requests = {}

		local node = ui:createFrame(Color(0, 0, 0, 0))
		content.node = node

		content.title = str:upperFirstChar(loc("magic key", "title"))
		content.icon = "🔑"

		local loadingLabel = ui:createText(str:upperFirstChar(loc("loading...")), Color.White)
		loadingLabel:setParent(node)
		loadingLabel:hide()

		local magicKeyLabelText = "✉️ What code did you get?"
		local magicKeyLabel = ui:createText(magicKeyLabelText, Color.White, "default")
		magicKeyLabel:setParent(node)

		local magicKeyInput = ui:createTextInput("", str:upperFirstChar(loc("000000")), { textSize = "default" })
		magicKeyInput:setParent(node)

		local magicKeyButton = ui:createButton(" ✅ ")
		magicKeyButton:setParent(node)

		local function showLoading()
			loadingLabel:show()
			magicKeyLabel:hide()
			magicKeyInput:hide()
			magicKeyButton:hide()
		end

		local function hideLoading()
			loadingLabel:hide()
			magicKeyLabel:show()
			magicKeyInput:show()
			magicKeyButton:show()
		end

		content.willResignActive = function()
			for _, req in ipairs(requests) do
				req:Cancel()
			end
		end

		content.didBecomeActive = function()
			for _, req in ipairs(requests) do
				req:Cancel()
			end
			hideLoading()
			magicKeyLabel.Text = magicKeyLabelText
		end

		magicKeyButton.onRelease = function()
			showLoading()
			local req = api:login(
				{ usernameOrEmail = usernameOrEmail, magickey = magicKeyInput.Text },
				function(err, credentials)
					-- res.username, res.password, res.magickey
					if err == nil then
						System:StoreCredentials(credentials["user-id"], credentials.token)
						-- onLoginSuccess
						local modal = content:getModalIfContentIsActive()
						if modal and modal.onLoginSuccess then
							modal.onLoginSuccess()
						end
					else
						magicKeyLabel.Text = "❌ " .. err
						hideLoading()
					end
				end
			)
			table.insert(requests, req)
		end

		node.refresh = function(self)
			self.Width =
				math.min(400, Screen.Width - Screen.SafeArea.Right - Screen.SafeArea.Left - theme.paddingBig * 2)
			self.Height = magicKeyLabel.Height + theme.paddingTiny + magicKeyInput.Height

			magicKeyButton.Height = magicKeyInput.Height

			magicKeyLabel.pos.Y = self.Height - magicKeyLabel.Height

			magicKeyInput.Width = self.Width - magicKeyButton.Width - theme.paddingTiny
			magicKeyInput.pos.Y = magicKeyLabel.pos.Y - theme.paddingTiny - magicKeyInput.Height

			magicKeyButton.pos.X = magicKeyInput.pos.X + magicKeyInput.Width + theme.paddingTiny
			magicKeyButton.pos.Y = magicKeyInput.pos.Y

			loadingLabel.pos.X = self.Width * 0.5 - loadingLabel.Width * 0.5
			loadingLabel.pos.Y = self.Height * 0.5 - loadingLabel.Height * 0.5
		end

		return content
	end

	local getLoginContent = function(usernameOrEmail, config)
		local defaultConfig = {
			password = false,
			magickey = false,
		}
		config = conf:merge(defaultConfig, config)

		local content = modal:createContent({ uikit = ui })
		content.idealReducedContentSize = idealReducedContentSize

		local requests = {}

		local node = ui:createFrame(Color(0, 0, 0, 0))
		content.node = node

		content.title = str:upperFirstChar(loc("authentication", "title"))
		content.icon = "🔑"

		local loadingLabel = ui:createText(str:upperFirstChar(loc("loading...")), Color.White)
		loadingLabel:setParent(node)
		loadingLabel:hide()

		local passwordLabel
		local passwordInput
		local passwordButton
		local magicKeyLabel
		local magicKeyButton

		local function showLoading()
			loadingLabel:show()
			if config.password then
				passwordLabel:hide()
				passwordInput:hide()
				passwordButton:hide()
			end
			if config.magickey then
				magicKeyLabel:hide()
				magicKeyButton:hide()
			end
		end

		local function hideLoading()
			loadingLabel:hide()
			if config.password then
				passwordLabel:show()
				passwordInput:show()
				passwordButton:show()
			end
			if config.magickey then
				magicKeyLabel:show()
				magicKeyButton:show()
			end
		end

		content.willResignActive = function()
			for _, req in ipairs(requests) do
				req:Cancel()
			end
		end

		content.didBecomeActive = function()
			for _, req in ipairs(requests) do
				req:Cancel()
			end
			hideLoading()
			-- TODO: remove error
		end

		if config.password then
			passwordLabel =
				ui:createText("🔑 " .. str:upperFirstChar(loc("password")), Color(200, 200, 200, 255), "small")
			passwordLabel:setParent(node)

			passwordInput =
				ui:createTextInput("", str:upperFirstChar(loc("password")), { textSize = "default", password = true })
			passwordInput:setParent(node)

			passwordButton = ui:createButton(" ✅ ")
			passwordButton:setParent(node)
		end

		if config.magickey then
			magicKeyLabel = ui:createText(config.password and "or, send me a:" or "send me a:", Color.White, "default")
			magicKeyLabel:setParent(node)

			magicKeyButton = ui:createButton(str:upperFirstChar(loc("✨ magic key ✨")))
			magicKeyButton:setColor(Color(0, 161, 169), Color.White)
			magicKeyButton:setParent(node)

			magicKeyButton.onRelease = function()
				showLoading()
				local req = api:getMagicKey(usernameOrEmail, function(err, res)
					-- res.username, res.password, res.magickey
					if err == nil then
						-- TODO: store that magic key's been sent
						-- opening Cubzh again after this should bring up magic key input directly then
						local c = getMagicKeyInputContent(usernameOrEmail)
						content:push(c)
					else
						-- TODO: display error
						hideLoading()
					end
				end)
				table.insert(requests, req)
			end
		end

		node.refresh = function(self)
			self.Width =
				math.min(400, Screen.Width - Screen.SafeArea.Right - Screen.SafeArea.Left - theme.paddingBig * 2)
			self.Height = (
				config.password
					and (passwordLabel.Height + theme.paddingTiny + passwordInput.Height + theme.paddingTiny)
				or 0
			) + (config.magickey and (magicKeyLabel.Height + theme.paddingTiny + magicKeyButton.Height) or 0)

			local y = self.Height

			if config.password then
				passwordButton.Height = passwordInput.Height

				passwordLabel.pos.Y = y - passwordLabel.Height

				passwordInput.Width = self.Width - passwordButton.Width - theme.paddingTiny
				passwordInput.pos.Y = passwordLabel.pos.Y - theme.paddingTiny - passwordInput.Height

				passwordButton.pos.X = passwordInput.pos.X + passwordInput.Width + theme.paddingTiny
				passwordButton.pos.Y = passwordInput.pos.Y

				y = passwordButton.pos.Y - theme.paddingTiny
			end

			if config.magickey then
				magicKeyLabel.pos.X = self.Width * 0.5 - magicKeyLabel.Width * 0.5
				magicKeyLabel.pos.Y = y - magicKeyLabel.Height

				magicKeyButton.Width = self.Width
				magicKeyButton.pos.Y = magicKeyLabel.pos.Y - theme.paddingTiny - magicKeyButton.Height
			end

			loadingLabel.pos.X = self.Width * 0.5 - loadingLabel.Width * 0.5
			loadingLabel.pos.Y = self.Height * 0.5 - loadingLabel.Height * 0.5
		end

		return content
	end

	-- initial content, asking for year of birth
	local content = modal:createContent({ uikit = ui })
	content.idealReducedContentSize = idealReducedContentSize

	local requests = {}

	local node = ui:createFrame(Color(0, 0, 0, 0))
	content.node = node

	content.title = str:upperFirstChar(loc("who are you?", "title"))
	content.icon = "🙂"

	local loadingLabel = ui:createText(str:upperFirstChar(loc("loading...")), Color.White)
	loadingLabel:setParent(node)
	loadingLabel:hide()

	local usernameLabelText = "👤 " .. str:upperFirstChar(loc("username"))
	local usernameLabel = ui:createText(usernameLabelText, Color(200, 200, 200, 255), "small")
	usernameLabel:setParent(node)

	local usernameInput = ui:createTextInput("", str:upperFirstChar(loc("username or email")))
	usernameInput:setParent(node)

	local didStartTyping = false
	usernameInput.onTextChange = function(self)
		local backup = self.onTextChange
		self.onTextChange = nil

		local s = str:normalize(self.Text)
		s = str:lower(s)

		self.Text = s
		self.onTextChange = backup

		if didStartTyping == false and self.Text ~= "" then
			didStartTyping = true
			System:DebugEvent("LOGIN_STARTED_TYPING_USERNAME")
		end
	end

	local loginButton = ui:createButton(" ✨ " .. str:upperFirstChar(loc("login", "button")) .. " ✨ ") -- , { textSize = "big" })
	loginButton:setParent(node)
	loginButton:setColor(Color(150, 200, 61), Color(240, 255, 240))

	local function showLoading()
		loadingLabel:show()
		usernameLabel:hide()
		usernameInput:hide()
		loginButton:hide()
	end

	local function hideLoading()
		loadingLabel:hide()
		usernameLabel:show()
		usernameInput:show()
		loginButton:show()
	end

	content.willResignActive = function()
		for _, req in ipairs(requests) do
			req:Cancel()
		end
	end

	content.didBecomeActive = function()
		for _, req in ipairs(requests) do
			req:Cancel()
		end
		hideLoading()
		usernameLabel.Text = usernameLabelText
	end

	loginButton.onRelease = function()
		showLoading()
		local req = api:getLoginOptions(usernameInput.Text, function(err, res)
			-- res.username, res.password, res.magickey
			if err == nil then
				-- NOTE: res.username is sanitized
				local loginContent = getLoginContent(res.username, { password = res.password, magickey = res.magickey })
				content:push(loginContent)
			else
				usernameLabel.Text = "❌ " .. err
				hideLoading()
			end
		end)
		table.insert(requests, req)
	end

	local maxWidth = function()
		return Screen.Width - theme.modalMargin * 2
	end

	local maxHeight = function()
		return Screen.Height - 100
	end

	local position = function(modal, forceBounce)
		local p = Number3(Screen.Width * 0.5 - modal.Width * 0.5, Screen.Height * 0.5 - modal.Height * 0.5, 0)

		if not modal.updatedPosition or forceBounce then
			modal.LocalPosition = p - { 0, 100, 0 }
			modal.updatedPosition = true
			ease:outElastic(modal, 0.3).LocalPosition = p
		else
			modal.LocalPosition = p
		end
	end

	local popup = modal:create(content, maxWidth, maxHeight, position, ui)

	popup.onSuccess = function() end

	popup.bounce = function(_)
		position(popup, true)
	end

	node.refresh = function(self)
		self.Width = math.min(400, Screen.Width - Screen.SafeArea.Right - Screen.SafeArea.Left - theme.paddingBig * 2)
		self.Height = usernameLabel.Height
			+ theme.paddingTiny
			+ usernameInput.Height
			+ theme.paddingBig
			+ loginButton.Height

		usernameLabel.pos.Y = self.Height - usernameLabel.Height

		usernameInput.Width = self.Width
		usernameInput.pos.Y = usernameLabel.pos.Y - theme.paddingTiny - usernameInput.Height

		loginButton.pos.X = self.Width * 0.5 - loginButton.Width * 0.5

		loadingLabel.pos.X = self.Width * 0.5 - loadingLabel.Width * 0.5
		loadingLabel.pos.Y = self.Height * 0.5 - loadingLabel.Height * 0.5
	end

	return popup
end

return mod
