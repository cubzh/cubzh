mod = {}

local function createCodeVerifContent(ui)
	local modal = require("modal")
	local theme = require("uitheme")
	local api = require("system_api", System)
	local bigPadding = theme.paddingBig
	local padding = theme.padding

	local checkParentApprovalDelay = 10 -- seconds
	local checkParentApprovalRequest
	local checkParentApprovalTimer
	local verifyPhoneNumberRequest
	local under13 = System.IsUserUnder13 == true

	local function cancelTimersAndRequests()
		if checkParentApprovalRequest ~= nil then
			checkParentApprovalRequest:Cancel()
			checkParentApprovalRequest = nil
		end
		if verifyPhoneNumberRequest ~= nil then
			verifyPhoneNumberRequest:Cancel()
			verifyPhoneNumberRequest = nil
		end
		if checkParentApprovalTimer ~= nil then
			checkParentApprovalTimer:Cancel()
			checkParentApprovalTimer = nil
		end
	end

	local node = ui:createFrame()

	local content = modal:createContent()
	content.title = "Verify Account"
	content.icon = "🇻"
	content.node = node

	local textStr = "✉️ What code did you receive?"
	local secondaryTextStr = "You should receive it shortly! If not, please verify your phone number, or try later."

	if under13 then
		textStr = "✉️ A Link has been sent to your Parent or Guardian."
		secondaryTextStr = "You can wait here or come back later when you know the account's been approved! 🙂"
	end

	local text = ui:createText(textStr, {
		color = Color.White,
	})
	text:setParent(node)

	local okBtn = ui:buttonPositive({
		content = "Confirm",
		textSize = "big",
		unfocuses = false,
		padding = 10,
	})
	okBtn:setParent(node)

	local codeInput = ui:createTextInput("", "000000", {
		textSize = "big",
		keyboardType = "oneTimeDigicode",
		bottomMargin = okBtn.Height + padding * 2,
		suggestions = false,
	})
	codeInput:setParent(node)

	local loading = require("ui_loading_animation"):create({ ui = ui })
	loading:setParent(node)
	loading:hide()

	if under13 then
		okBtn:hide()
		codeInput:hide()
		loading:show()

		refreshText = ui:createText("", {
			color = Color(255, 255, 255, 0.5),
			size = "small",
		})
		refreshText:setParent(node)

		local scheduler = {
			counter = checkParentApprovalDelay,
			timer = nil,
		}
		scheduler.apiCall = function()
			checkParentApprovalRequest = api:getUserInfo(System.UserID, function(userInfo, err)
				checkParentApprovalRequest = nil
				if err ~= nil then
					scheduler.checkParentApproval()
					return
				end

				-- Update local user information
				System.IsParentApproved = userInfo.isParentApproved == true
				System.HasVerifiedPhoneNumber = userInfo.hasVerifiedPhoneNumber == true

				if System.IsParentApproved then
					-- TODO
					print("CLOSE MODAL + REFRESH HOME")
				else
					scheduler.checkParentApproval()
				end
			end, {
				"isParentApproved",
				"hasVerifiedPhoneNumber",
			})
		end

		scheduler.updateText = function(newText)
			refreshText.Text = newText
			refreshText.pos.X = (node.Width - refreshText.Width) * 0.5
		end

		scheduler.checkParentApproval = function()
			-- reset time counter
			scheduler.counter = checkParentApprovalDelay
			--  start loop timer
			if scheduler.timer ~= nil then
				scheduler.timer:Cancel()
				scheduler.timer = nil
			end
			scheduler.timer = Timer(1, true, function()
				-- refreshBtn:enable()

				scheduler.counter = scheduler.counter - 1

				-- update text
				scheduler.updateText("Refreshing in " .. scheduler.counter .. " …")

				if scheduler.counter < 1 then
					-- time's up
					scheduler.updateText("Refreshing now!")
					scheduler.timer:Cancel()
					scheduler.timer = nil
					scheduler.apiCall()
				end
			end)
		end
		scheduler.checkParentApproval()
	else
		-- TODO: enable when code is 6 digits
		-- okBtn:disable()

		okBtn.onRelease = function()
			okBtn:disable()

			System:DebugEvent("User presses OK to submit verification code", { code = codeInput.Text })

			local verifCode = codeInput.Text

			local data = {}
			if System.IsUserUnder13 == true then
				data.parentPhoneVerifCode = verifCode
			else
				data.phoneVerifCode = verifCode
			end

			verifyPhoneNumberRequest = api:patchUserInfo(data, function(err)
				verifyPhoneNumberRequest = nil
				if err ~= nil then
					System:DebugEvent("Request to verify phone number fails", { code = codeInput.Text })
					okBtn:enable()
					return
				end
				System:DebugEvent("Request to verify phone number succeeds", { code = codeInput.Text })

				local modal = content:getModalIfContentIsActive()
				if modal then
					-- TODO refresh home (remove verified icons)
					modal:close()
				end
			end)
		end

		local didStartTyping = false
		codeInput.onTextChange = function(self)
			local backup = self.onTextChange
			self.onTextChange = nil
			-- TODO: format?
			self.onTextChange = backup

			if not didStartTyping and self.Text ~= "" then
				didStartTyping = true
				System:DebugEvent("User starts editing code input", { code = self.Text })
			end
		end
	end

	local secondaryText = ui:createText(secondaryTextStr, {
		color = Color(200, 200, 200),
		size = "small",
	})
	secondaryText:setParent(node)

	local function refresh()
		text.object.MaxWidth = node.Width - padding * 2
		secondaryText.object.MaxWidth = node.Width - padding * 2

		secondaryText.pos = {
			node.Width * 0.5 - secondaryText.Width * 0.5,
			padding,
		}

		okBtn.pos = {
			node.Width * 0.5 - okBtn.Width * 0.5,
			secondaryText.pos.Y + secondaryText.Height + padding,
		}

		codeInput.Width = node.Width - padding * 2
		codeInput.pos = {
			node.Width * 0.5 - codeInput.Width * 0.5,
			okBtn.pos.Y + okBtn.Height + bigPadding,
		}

		loading.pos = {
			node.Width * 0.5 - loading.Width * 0.5,
			codeInput.pos.Y + codeInput.Height * 0.5 - loading.Height * 0.5,
		}

		text.pos = {
			node.Width * 0.5 - text.Width * 0.5,
			codeInput.pos.Y + codeInput.Height + bigPadding,
		}
	end

	content.idealReducedContentSize = function(_, width, height)
		node.Width = width
		refresh()
		local h = math.min(
			height,
			okBtn.Height + codeInput.Height + text.Height + secondaryText.Height + padding * 2 + bigPadding * 2
		)
		return Number2(width, h)
	end

	content.willResignActive = function()
		cancelTimersAndRequests()
	end

	return content
end

mod.createModalContent = function(_, config)
	local checkDelay = 0.5
	local checkTimer
	local checkReq
	local selectedPrefix = "1"

	local modal = require("modal")
	local theme = require("uitheme")
	local loc = require("localize")
	local str = require("str")
	local api = require("system_api", System)
	local phonenumbers = require("phonenumbers")
	local padding = theme.paddingBig
	local smallPadding = theme.padding

	local function cancelTimersAndRequests()
		if checkTimer ~= nil then
			checkTimer:Cancel()
			checkTimer = nil
		end
		if checkReq ~= nil then
			checkReq:Cancel()
			checkReq = nil
		end
	end

	local defaultConfig = {
		uikit = require("uikit"),
		text = System.IsUserUnder13 == true and "Username setup requires a verified parent or guardian phone number."
			or "Username setup requires a verified phone number.",
	}

	ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config)
	end)

	if not ok then
		error("verifyAccountForm:createModalContent(config) - config error: " .. err, 2)
	end

	local ui = config.uikit

	local node = ui:createFrame()

	local content = modal:createContent()
	content.title = "Verify Account"
	content.icon = "🇻"
	content.node = node

	local text = ui:createText(config.text, Color.White, "default")
	text:setParent(node)

	local instructions =
		ui:createText("Needed to secure accounts and fight against cheaters and bots. Information kept private. 🔒", {
			color = Color(69, 180, 255),
			size = "small",
		})
	instructions:setParent(node)

	local statusMessage = ui:createText("...", {
		color = Color.White,
		size = "small",
	})
	statusMessage:setParent(nil)

	local loading = require("ui_loading_animation"):create({ ui = ui })
	loading:setParent(node)

	local okBtn = ui:buttonPositive({
		content = "Confirm",
		textSize = "big",
		unfocuses = false,
		padding = 10,
	})
	okBtn:setParent(node)
	okBtn:disable()

	local proposedCountries = {
		"US",
		"CA",
		"GB",
		"DE",
		"FR",
		"IT",
		"ES",
		"NL",
		"RU",
		"CN",
		"IN",
		"JP",
		"KR",
		"AU",
		"BR",
		"MX",
		"AR",
		"ZA",
		"SA",
		"TR",
		"ID",
		"VN",
		"TH",
		"MY",
		"PH",
		"SG",
		"AE",
		"IL",
		"UA",
	}

	local countryLabels = {}
	local c
	for _, countryCode in ipairs(proposedCountries) do
		c = phonenumbers.countryCodes[countryCode]
		if c ~= nil then
			table.insert(countryLabels, c.code .. " +" .. c.prefix)
		end
	end

	local countryInput = ui:createComboBox("US +1", countryLabels)
	countryInput:setParent(node)

	local phoneInput = ui:createTextInput("", str:upperFirstChar(loc("phone number")), {
		textSize = "big",
		keyboardType = "phone",
		suggestions = false,
		bottomMargin = okBtn.Height + padding * 2,
	})
	phoneInput:setParent(node)

	local status = ui:createText("", {
		color = Color.White,
	})
	status:setParent(node)

	local setStatus = function(str)
		status.Text = str
		local parent = status.parent
		status.pos = {
			parent.Width * 0.5 - status.Width * 0.5,
			text.pos.Y + text.Height * 0.5 - status.Height * 0.5,
		}
	end

	local function checkPhoneNumber()
		if checkReq ~= nil then
			checkReq:Cancel()
			checkReq = nil
		end
		if phoneInput.Text == "" then
			if checkTimer then
				checkTimer:Cancel()
				checkTimer = nil
			end
			text:show()
			loading:hide()
			status:hide()
			okBtn:disable()
			return
		end

		loading:show()
		text:hide()
		status:hide()
		okBtn:disable()

		if checkTimer == nil then
			checkTimer = Timer(checkDelay, function()
				checkTimer = nil

				local phoneNumber = "+" .. selectedPrefix .. phonenumbers:sanitize(phoneInput.Text)

				checkReq = api:checkPhoneNumber(phoneNumber, function(resp, err)
					status:show()
					loading:hide()
					okBtn:disable()

					if err ~= nil then
						setStatus(err.message)
						return
					end

					if resp.isValid == true then
						setStatus("All good! ✅")
						okBtn:enable()
					else
						setStatus("Number invalid. ❌")
					end
				end)
			end)
		else
			checkTimer:Reset()
		end
	end

	checkPhoneNumber()

	local layoutPhoneInput = function()
		phoneInput.Width = node.Width - theme.paddingBig * 2 - countryInput.Width - theme.padding
		phoneInput.pos = {
			countryInput.pos.X + countryInput.Width + theme.padding,
			countryInput.pos.Y,
		}
	end

	local function refresh()
		text.object.MaxWidth = node.Width - theme.padding * 4
		instructions.object.MaxWidth = node.Width - theme.padding * 4
		statusMessage.object.MaxWidth = node.Width - theme.padding * 4

		instructions.pos = {
			node.Width * 0.5 - instructions.Width * 0.5,
			theme.padding,
		}

		okBtn.pos = {
			node.Width * 0.5 - okBtn.Width * 0.5,
			instructions.pos.Y + instructions.Height + theme.padding,
		}

		layoutPhoneInput()

		countryInput.Height = phoneInput.Height

		countryInput.pos = {
			padding,
			okBtn.pos.Y + okBtn.Height + padding,
		}

		phoneInput.pos = {
			countryInput.pos.X + countryInput.Width + smallPadding,
			countryInput.pos.Y,
		}

		text.pos = {
			node.Width * 0.5 - text.Width * 0.5,
			countryInput.pos.Y + countryInput.Height + padding,
		}

		loading.pos = {
			node.Width * 0.5 - loading.Width * 0.5,
			text.pos.Y + text.Height * 0.5 - loading.Height * 0.5,
		}

		status.pos = {
			node.Width * 0.5 - status.Width * 0.5,
			text.pos.Y + text.Height * 0.5 - status.Height * 0.5,
		}
	end

	okBtn.onRelease = function()
		countryInput:disable()
		phoneInput:disable()
		okBtn:disable()

		loading:show()
		text:hide()
		status:hide()

		System:DebugEvent(
			"User presses OK button to submit phone number",
			{ countryInput = countryInput.Text, phoneInput = phoneInput.Text }
		)

		local phoneNumber = "+" .. selectedPrefix .. phonenumbers:sanitize(phoneInput.Text)

		-- construct user patch data
		local data = { phone = phoneNumber }
		if System.IsUserUnder13 == true then
			data = { parentPhone = phoneNumber }
		end

		api:patchUserInfo(data, function(err)
			countryInput:enable()
			phoneInput:enable()

			status:show()
			loading:hide()

			if err ~= nil then
				System:DebugEvent("Request to submit phone number fails")
				okBtn:enable()
				return
			end

			-- TODO: push verify phone number form
			content:push(createCodeVerifContent(ui))
			-- signupFlow:push(steps.createVerifyPhoneNumberStep())
		end)
	end

	countryInput.onSelect = function(self, index)
		self.Text = countryLabels[index] -- "FR +33"
		-- find the position of the + char
		local plusPos = string.find(self.Text, "+") -- 4
		-- get the substring after the + char
		local prefix = string.sub(self.Text, plusPos + 1) -- "33"
		selectedPrefix = prefix

		System:DebugEvent(
			"User picks country for phone number",
			{ countryInput = countryInput.Text, phoneInput = phoneInput.Text }
		)

		layoutPhoneInput()
		checkPhoneNumber()
	end

	local didStartTyping = false
	phoneInput.onTextChange = function(self)
		-- disable onTextChange
		local backup = self.onTextChange
		self.onTextChange = nil

		local text = phonenumbers:sanitize(self.Text)

		local res = phonenumbers:extractCountryCode(text)
		if res.countryCode ~= nil then
			text = res.remainingNumber
			countryInput.Text = res.countryCode .. " +" .. res.countryPrefix
			selectedPrefix = res.countryPrefix
			layoutPhoneInput()
		end

		-- TODO: maintain cursor position (passing cursor to phonenumbers:sanitize)
		self.Text = text

		if not didStartTyping and self.Text ~= "" then
			didStartTyping = true
			System:DebugEvent(
				"User starts editing phone number",
				{ countryInput = countryInput.Text, phoneInput = phoneInput.Text }
			)
		end

		-- re-enable onTextChange
		self.onTextChange = backup

		checkPhoneNumber()
	end

	content.idealReducedContentSize = function(_, width, height)
		node.Width = width
		refresh()
		local h = math.min(height, okBtn.Height + phoneInput.Height + text.Height + instructions.Height + padding * 3)
		return Number2(width, h)
	end

	content.willResignActive = function()
		cancelTimersAndRequests()
	end

	content.didBecomeActive = function()
		checkPhoneNumber()
	end

	return content
end

return mod
