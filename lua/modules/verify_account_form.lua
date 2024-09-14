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
		text = "Ready to pick a username?",
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

	local text = ui:createText(config.text, Color.White, "default")
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
			LocalEvent:Send("username_set")
			local modal = content:getModalIfContentIsActive()
			if modal ~= nil then
				modal:close()
			end
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

--[[
-- Prompts the user for a phone number
	steps.createPhoneNumberStep = function()
		local checkDelay = 0.5
		local checkTimer
		local checkReq

		local skipOnFirstEnter = System.HasUnverifiedPhoneNumber
		local step = flow:createStep({
			onEnter = function()
				config.phoneNumberStep()

				showBackButton()

				-- DRAWER
				if drawer ~= nil then
					drawer:clear()
				else
					drawer = drawerModule:create({ ui = ui })
				end

				local okBtn = ui:buttonPositive({
					content = "Confirm",
					textSize = "big",
					unfocuses = false,
					padding = 10,
				})
				okBtn:setParent(drawer)

				local loading = require("ui_loading_animation"):create({ ui = ui })
				loading:setParent(drawer)

				local selectedPrefix = "1"

				local textStr = "✨ Final step! What's your Phone Number?"
				if System.IsUserUnder13 == true then
					textStr = "✨ Final step! Enter a Parent or Guardian Phone Number:"
				end

				local text = ui:createText(textStr, {
					color = Color.White,
				})
				text:setParent(drawer)

				local status = ui:createText("", {
					color = Color.White,
				})
				status:setParent(drawer)

				local setStatus = function(str)
					status.Text = str
					local parent = status.parent
					status.pos = {
						parent.Width * 0.5 - status.Width * 0.5,
						text.pos.Y + text.Height * 0.5 - status.Height * 0.5,
					}
				end

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
				countryInput:setParent(drawer)

				local phoneInput = ui:createTextInput("", str:upperFirstChar(loc("phone number")), {
					textSize = "big",
					keyboardType = "phone",
					suggestions = false,
					bottomMargin = okBtn.Height + padding * 2,
				})
				phoneInput:setParent(drawer)

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
						signupFlow:push(steps.createVerifyPhoneNumberStep())
					end)
				end

				local layoutPhoneInput = function()
					phoneInput.Width = drawer.Width - theme.paddingBig * 2 - countryInput.Width - theme.padding
					phoneInput.pos = {
						countryInput.pos.X + countryInput.Width + theme.padding,
						countryInput.pos.Y,
					}
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

				local secondaryText =
					ui:createText("Needed to secure accounts and fight against cheaters. Kept private. 🔒", {
						color = Color(200, 200, 200),
						size = "small",
					})
				secondaryText:setParent(drawer)

				drawer:updateConfig({
					layoutContent = function(self)
						-- here, self.Height can be reduced, but not increased
						-- TODO: enforce this within drawer module

						local padding = theme.paddingBig
						local smallPadding = theme.padding

						local maxWidth = math.min(300, self.Width - padding * 2)
						text.object.MaxWidth = maxWidth
						secondaryText.object.MaxWidth = maxWidth
						status.object.MaxWidth = maxWidth

						local w = math.min(self.Width, math.max(text.Width, okBtn.Width, 300) + padding * 2)

						local availableWidth = w - padding * 2
						countryInput.Height = phoneInput.Height
						phoneInput.Width = availableWidth - countryInput.Width - smallPadding

						self.Width = w
						self.Height = Screen.SafeArea.Bottom
							+ okBtn.Height
							+ text.Height
							+ secondaryText.Height
							+ phoneInput.Height
							+ padding * 5

						secondaryText.pos = {
							self.Width * 0.5 - secondaryText.Width * 0.5,
							Screen.SafeArea.Bottom + padding,
						}
						okBtn.pos = {
							self.Width * 0.5 - okBtn.Width * 0.5,
							secondaryText.pos.Y + secondaryText.Height + padding,
						}
						countryInput.pos = {
							padding,
							okBtn.pos.Y + okBtn.Height + padding,
						}
						phoneInput.pos = {
							countryInput.pos.X + countryInput.Width + smallPadding,
							countryInput.pos.Y,
						}

						loading.pos = {
							self.Width * 0.5 - loading.Width * 0.5,
							text.pos.Y + text.Height * 0.5 - loading.Height * 0.5,
						}

						status.pos = {
							self.Width * 0.5 - status.Width * 0.5,
							text.pos.Y + text.Height * 0.5 - status.Height * 0.5,
						}

						text.pos = {
							self.Width * 0.5 - text.Width * 0.5,
							countryInput.pos.Y + countryInput.Height + padding,
						}

						LocalEvent:Send("signup_drawer_height_update", self.Height)
					end,
				})

				drawer:show()

				if skipOnFirstEnter then
					skipOnFirstEnter = false
					signupFlow:push(steps.createVerifyPhoneNumberStep())
				end
			end,
			onExit = function() end,
			onRemove = function() end,
		})

		return step
	end


	-- Prompts the user for a phone number verif code
	steps.createVerifyPhoneNumberStep = function()
		local checkParentApprovalDelay = 10 -- seconds
		local checkParentApprovalRequest
		local checkParentApprovalTimer
		local verifyPhoneNumberRequest

		local step = flow:createStep({
			onEnter = function()
				config.verifyPhoneNumberStep()

				showBackButton()

				-- DRAWER
				if drawer ~= nil then
					drawer:clear()
				else
					drawer = drawerModule:create({ ui = ui })
				end

				local under13 = System.IsUserUnder13 == true

				local textStr = "✉️ What code did you receive?"
				local secondaryTextStr =
					"You should receive it shortly! If not, please verify your phone number, or try later."

				if under13 then
					textStr = "✉️ A Link has been sent to your Parent or Guardian."
					secondaryTextStr =
						"You can wait here or come back later when you know the account's been approved! 🙂"
				end

				local text = ui:createText(textStr, {
					color = Color.White,
				})
				text:setParent(drawer)

				local okBtn = ui:buttonPositive({
					content = "Confirm",
					textSize = "big",
					unfocuses = false,
					padding = 10,
				})
				okBtn:setParent(drawer)

				local codeInput = ui:createTextInput("", str:upperFirstChar(loc("000000")), {
					textSize = "big",
					keyboardType = "oneTimeDigicode",
					bottomMargin = okBtn.Height + padding * 2,
					suggestions = false,
				})
				codeInput:setParent(drawer)

				local loading = require("ui_loading_animation"):create({ ui = ui })
				loading:setParent(drawer)
				loading:hide()

				local refreshText = nil

				if under13 then
					okBtn:hide()
					codeInput:hide()
					loading:show()

					refreshText = ui:createText("", {
						color = Color(255, 255, 255, 0.5),
						size = "small",
					})
					refreshText:setParent(drawer)

					-- refreshBtn = ui:buttonNeutral({
					-- 	content = "🔁",
					-- 	textSize = "small",
					-- })
					-- refreshBtn:setParent(drawer)

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
							System.HasDOB = userInfo.hasDOB == true
							System.HasEstimatedDOB = userInfo.hasEstimatedDOB == true
							System.HasVerifiedPhoneNumber = userInfo.hasVerifiedPhoneNumber == true

							if Client.LoggedIn then
								callLoginSuccess()
							else
								scheduler.checkParentApproval()
							end
						end, {
							"isParentApproved",
							"hasDOB",
							"hasEstimatedDOB",
							"hasVerifiedPhoneNumber",
						})
					end
					scheduler.updateText = function(newText)
						-- update refreshText
						refreshText.Text = newText
						refreshText.pos.X = (drawer.Width - refreshText.Width) * 0.5
						-- refreshText.pos.X = (drawer.Width - refreshText.Width - refreshBtn.Width - padding) * 0.5
						-- refreshBtn.pos = {
						-- 	refreshText.pos.X + refreshText.Width + padding,
						-- 	refreshText.pos.Y + (refreshText.Height - refreshBtn.Height) * 0.5,
						-- }
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

							-- refreshBtn.onRelease = function()
							-- 	refreshBtn:disable()
							-- 	scheduler.timer:Cancel()
							-- 	scheduler.timer = nil
							-- 	scheduler.updateText("Refreshing now!")
							-- 	scheduler.apiCall()
							-- end

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

							-- flush signup flow and restart credential checks (should go through now)
							signupFlow:flush()
							signupFlow:push(steps.createCheckAppVersionAndCredentialsStep({ onlyCheckUserInfo = true }))
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
				secondaryText:setParent(drawer)

				drawer:updateConfig({
					layoutContent = function(self)
						local padding = theme.paddingBig

						local maxWidth = math.min(300, self.Width - padding * 2)
						text.object.MaxWidth = maxWidth
						secondaryText.object.MaxWidth = maxWidth

						local w = math.min(self.Width, math.max(text.Width, okBtn.Width, 300) + padding * 2)

						local availableWidth = w - padding * 2
						codeInput.Width = availableWidth

						self.Width = w
						if refreshText ~= nil then
							self.Height = Screen.SafeArea.Bottom
								+ text.Height
								+ secondaryText.Height
								+ refreshText.Height
								+ loading.Height
								+ padding * 5
						else
							self.Height = Screen.SafeArea.Bottom
								+ text.Height
								+ secondaryText.Height
								+ codeInput.Height
								+ padding * 4
						end

						if okBtn:isVisible() then
							self.Height = self.Height + okBtn.Height + padding
						end

						secondaryText.pos = {
							self.Width * 0.5 - secondaryText.Width * 0.5,
							Screen.SafeArea.Bottom + padding,
						}

						if okBtn:isVisible() then
							okBtn.pos = {
								self.Width * 0.5 - okBtn.Width * 0.5,
								secondaryText.pos.Y + secondaryText.Height + padding,
							}
							codeInput.pos = {
								self.Width * 0.5 - codeInput.Width * 0.5,
								okBtn.pos.Y + okBtn.Height + padding,
							}
						else
							codeInput.pos = {
								self.Width * 0.5 - codeInput.Width * 0.5,
								secondaryText.pos.Y + secondaryText.Height + padding,
							}
						end

						if refreshText ~= nil then
							-- refresh text is present
							refreshText.pos = {
								(drawer.Width - refreshText.Width) * 0.5,
								secondaryText.pos.Y + secondaryText.Height + padding,
							}

							-- refreshText.pos = {
							-- 	(self.Width - refreshText.Width - refreshBtn.Width - padding) * 0.5,
							-- 	secondaryText.pos.Y + secondaryText.Height + padding,
							-- }

							-- refreshBtn.pos = {
							-- 	refreshText.pos.X + refreshText.Width + padding,
							-- 	refreshText.pos.Y + (refreshText.Height - refreshBtn.Height) * 0.5,
							-- }

							loading.pos = {
								self.Width * 0.5 - loading.Width * 0.5,
								refreshText.pos.Y + refreshText.Height + padding,
							}

							text.pos = {
								self.Width * 0.5 - text.Width * 0.5,
								loading.pos.Y + loading.Height + padding,
							}
						else
							-- refresh text is not present
							text.pos = {
								self.Width * 0.5 - text.Width * 0.5,
								codeInput.pos.Y + codeInput.Height + padding,
							}
						end

						LocalEvent:Send("signup_drawer_height_update", self.Height)
					end,
				})

				drawer:show()

				-- autofocus text input
				if codeInput:isVisible() then
					Timer(0.2, function()
						codeInput:focus()
					end)
				end
			end,
			onExit = function()
				drawer:updateConfig({
					layoutContent = function(_) end,
				})
				drawer:hide()
				if checkParentApprovalTimer ~= nil then
					checkParentApprovalTimer:Cancel()
					checkParentApprovalTimer = nil
				end
				if checkParentApprovalRequest ~= nil then
					checkParentApprovalRequest:Remove()
					checkParentApprovalRequest = nil
				end
				if verifyPhoneNumberRequest ~= nil then
					verifyPhoneNumberRequest:Remove()
					verifyPhoneNumberRequest = nil
				end
			end,
			onRemove = function()
				removeBackButton()
				if drawer ~= nil then
					drawer:remove()
					drawer = nil
				end
				if config.onCancel ~= nil then
					config.onCancel() -- TODO: can't stay here (step also removed when completing flow)
				end
			end,
		})

		return step
	end
]]
