local signup = {}

signup.startFlow = function(self, config)
	if self ~= signup then
		error("signup:startFlow(config) should be called with `:`", 2)
	end

	local conf = require("config")

	local defaultConfig = {
		ui = require("uikit"),
		onCancel = function() end,
		checkAppVersionAndCredentialsStep = function() end,
		signUpOrLoginStep = function() end,
		avatarPreviewStep = function() end,
		avatarEditorStep = function() end,
		loginStep = function() end,
		loginSuccess = function() end,
		dobStep = function() end,
		phoneNumberStep = function() end,
		verifyPhoneNumberStep = function() end,
	}

	local ok, err = pcall(function()
		config = conf:merge(defaultConfig, config)
	end)
	if not ok then
		error("signup:startFlow(config) - config error: " .. err, 2)
	end

	local flowConfig = config

	local api = require("system_api", System)
	local ui = config.ui
	local flow = require("flow")
	local drawerModule = require("drawer")
	local ease = require("ease")
	local loc = require("localize")
	local phonenumbers = require("phonenumbers")
	local str = require("str")
	local bundle = require("bundle")

	local theme = require("uitheme").current
	local padding = theme.padding

	local signupFlow = flow:create()

	local animationTime = 0.3

	-- local backFrame
	local backButton
	local coinsButton
	local drawer
	local loginBtn

	local cache = {
		dob = {
			month = nil,
			day = nil,
			year = nil,
			monthIndex = nil,
			dayIndex = nil,
			yearIndex = nil,
		},
		phoneNumber = nil,
		nbAvatarPartsChanged = 0,
	}

	local function showCoinsButton()
		if coinsButton == nil then
			local balanceContainer = ui:createFrame(Color(0, 0, 0, 0))
			local coinShape = bundle:Shape("shapes/pezh_coin_2")
			local coin = ui:createShape(coinShape, { spherized = false, doNotFlip = true })
			coin:setParent(balanceContainer)

			local l = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
				coin.pivot.Rotation = coin.pivot.Rotation * Rotation(0, dt, 0)
			end)
			coin.onRemove = function()
				l:Remove()
			end

			local balance = ui:createText("100", { color = Color(252, 220, 44), size = "default" })
			balance:setParent(balanceContainer)
			balanceContainer.parentDidResize = function(self)
				local ratio = coin.Width / coin.Height
				coin.Height = balance.Height
				coin.Width = coin.Height * ratio
				self.Width = coin.Width + balance.Width + theme.padding
				self.Height = coin.Height

				coin.pos = { 0, self.Height * 0.5 - coin.Height * 0.5 }
				balance.pos = { coin.Width + theme.padding, self.Height * 0.5 - balance.Height * 0.5 }
			end
			balanceContainer:parentDidResize()

			coinsButton = ui:buttonMoney({ content = balanceContainer, textSize = "default" })
			-- coinsButton = ui:createButton(balanceContainer, { textSize = "default", borders = false })
			-- coinsButton:setColor(Color(0, 0, 0, 0.4))
			coinsButton.parentDidResize = function(self)
				ease:cancel(self)
				self.pos = {
					Screen.Width - Screen.SafeArea.Right - self.Width - padding,
					Screen.Height - Screen.SafeArea.Top - self.Height - padding,
				}
			end
			coinsButton.onRelease = function(_)
				-- display info bubble
			end
			coinsButton.pos = { Screen.Width, Screen.Height - Screen.SafeArea.Top - coinsButton.Height - padding }
			ease:outSine(coinsButton, animationTime).pos = Number3(
				Screen.Width - Screen.SafeArea.Right - coinsButton.Width - padding,
				Screen.Height - Screen.SafeArea.Top - coinsButton.Height - padding,
				0
			)
		end
	end

	local function removeCoinsButton()
		if coinsButton ~= nil then
			coinsButton:remove()
			coinsButton = nil
		end
	end

	local internalLoginSuccess = function()
		-- Hide the coins balance button (top right corner)
		-- The button is shown during the signup process,
		-- but it should be hidden once the user is logged in,
		-- because the top bar already displays the user's balance.
		removeCoinsButton()

		flowConfig.loginSuccess()
	end

	local function showBackButton()
		if backButton == nil then
			backButton = ui:buttonNegative({ content = "⬅️", textSize = "default" })
			-- backButton = ui:createButton("⬅️", { textSize = "default" })
			-- backButton:setColor(theme.colorNegative)
			backButton.parentDidResize = function(self)
				ease:cancel(self)
				self.pos = {
					padding,
					Screen.Height - Screen.SafeArea.Top - self.Height - padding,
				}
			end
			backButton.onRelease = function(_)
				signupFlow:back()
			end
			backButton.pos = { -backButton.Width, Screen.Height - Screen.SafeArea.Top - backButton.Height - padding }
			ease:outSine(backButton, animationTime).pos =
				Number3(padding, Screen.Height - Screen.SafeArea.Top - backButton.Height - padding, 0)
		end
	end

	local function removeBackButton()
		if backButton ~= nil then
			backButton:remove()
			backButton = nil
		end
	end

	local createMagicKeyInputStep = function(config)
		local defaultConfig = {
			usernameOrEmail = "",
		}
		config = conf:merge(defaultConfig, config)

		local requests = {}
		local frame
		local step = flow:createStep({
			onEnter = function()
				frame = ui:frameGenericContainer()

				local title = ui:createText(str:upperFirstChar(loc("magic key", "title")) .. " 🔑", Color.White)
				title:setParent(frame)

				local loadingLabel = ui:createText(str:upperFirstChar(loc("loading...")), Color.White)
				loadingLabel:setParent(frame)
				loadingLabel:hide()

				local magicKeyLabelText = "✉️ What code did you get?"
				local magicKeyLabel = ui:createText(magicKeyLabelText, Color.White, "default")
				magicKeyLabel:setParent(frame)

				local magicKeyInput =
					ui:createTextInput("", str:upperFirstChar(loc("000000")), { textSize = "default" })
				magicKeyInput:setParent(frame)

				local magicKeyButton = ui:buttonNeutral({ content = "✅" })
				magicKeyButton:setParent(frame)

				local resendCodeButton = ui:buttonNeutral({
					content = "Send me a new code",
					textSize = "small",
				})
				resendCodeButton:setParent(frame)

				local function showLoading()
					loadingLabel:show()
					magicKeyLabel:hide()
					magicKeyInput:hide()
					magicKeyButton:hide()
					resendCodeButton:hide()
				end

				local function hideLoading()
					loadingLabel:hide()
					magicKeyLabel:show()
					magicKeyInput:show()
					magicKeyButton:show()
					resendCodeButton:show()
				end

				magicKeyButton.onRelease = function()
					showLoading()
					if magicKeyInput.Text ~= "" then
						local req = api:login(
							{ usernameOrEmail = config.usernameOrEmail, magickey = magicKeyInput.Text },
							function(err, accountInfo)
								if err == nil then
									local userID = accountInfo.credentials["user-id"]
									local username = accountInfo.username
									local token = accountInfo.credentials.token

									Player.UserID = userID
									Player.Username = username
									System:StoreCredentials(userID, token)

									System.AskedForMagicKey = false
									internalLoginSuccess()
								else
									magicKeyLabel.Text = "❌ " .. err
									hideLoading()
								end
							end
						)
						table.insert(requests, req)
					else
						-- text input is empty
						magicKeyLabel.Text = "❌ Please enter a magic key"
						hideLoading()
					end
				end

				resendCodeButton.onRelease = function(_)
					-- ask the API server to send a new magic key to the user (via email or SMS)
					showLoading()
					local req = api:getMagicKey(config.usernameOrEmail, function(err, _)
						hideLoading()
						if err ~= nil then
							magicKeyLabel.Text = "❌ Sorry, failed to send magic key"
						end
					end)
					table.insert(requests, req)
				end

				frame.parentDidResize = function(self)
					self.Width = math.min(
						400,
						Screen.Width - Screen.SafeArea.Right - Screen.SafeArea.Left - theme.paddingBig * 2
					)
					self.Height = title.Height
						+ theme.padding
						+ magicKeyLabel.Height
						+ theme.paddingTiny
						+ magicKeyInput.Height
						+ theme.padding
						+ resendCodeButton.Height
						+ theme.paddingBig * 2

					title.pos = {
						self.Width * 0.5 - title.Width * 0.5,
						self.Height - theme.paddingBig - title.Height,
					}

					magicKeyButton.Height = magicKeyInput.Height

					magicKeyLabel.pos.X = theme.paddingBig
					magicKeyLabel.pos.Y = title.pos.Y - theme.padding - magicKeyLabel.Height

					magicKeyInput.Width = self.Width - theme.paddingBig * 2 - magicKeyButton.Width - theme.paddingTiny
					magicKeyInput.pos.X = theme.paddingBig
					magicKeyInput.pos.Y = magicKeyLabel.pos.Y - theme.paddingTiny - magicKeyInput.Height

					magicKeyButton.pos.X = magicKeyInput.pos.X + magicKeyInput.Width + theme.paddingTiny
					magicKeyButton.pos.Y = magicKeyInput.pos.Y

					resendCodeButton.pos.X = self.Width * 0.5 - resendCodeButton.Width * 0.5
					resendCodeButton.pos.Y = magicKeyInput.pos.Y - theme.padding - resendCodeButton.Height

					loadingLabel.pos = {
						self.Width * 0.5 - loadingLabel.Width * 0.5,
						self.Height * 0.5 - loadingLabel.Height * 0.5,
					}
					self.pos = { Screen.Width * 0.5 - self.Width * 0.5, Screen.Height * 0.5 - self.Height * 0.5 }
				end

				frame:parentDidResize()
				targetPos = frame.pos:Copy()
				frame.pos.Y = frame.pos.Y - 50
				ease:outBack(frame, animationTime).pos = targetPos
			end,
			onExit = function()
				for _, req in ipairs(requests) do
					req:Cancel()
				end
				frame:remove()
				frame = nil
			end,
			onRemove = function() end,
		})
		return step
	end

	-- Prompts the user for a phone number verif code
	local createVerifyPhoneNumberStep = function()
		local step = flow:createStep({
			onEnter = function()
				config.verifyPhoneNumberStep()

				showBackButton()
				showCoinsButton()

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
				-- okBtn:disable()

				local textStr = "What code did you receive?"
				if System.IsUserUnder13 == true then
					textStr = "What code did your parent receive?"
				end

				local text = ui:createText(textStr, {
					color = Color.White,
				})
				text:setParent(drawer)

				local codeInput = ui:createTextInput("", str:upperFirstChar(loc("000000")), {
					textSize = "big",
					keyboardType = "oneTimeDigicode",
					bottomMargin = okBtn.Height + padding * 2,
					suggestions = false,
				})
				codeInput:setParent(drawer)

				okBtn.onRelease = function()
					okBtn:disable()

					local phoneVerifCode = codeInput.Text

					api:patchUserInfo({ phoneVerifCode = phoneVerifCode }, function(err)
						if err ~= nil then
							print("ERR:", err)
							okBtn:enable()
							return
						end
						internalLoginSuccess()
					end)
				end

				codeInput.onTextChange = function(self)
					local backup = self.onTextChange
					self.onTextChange = nil
					-- TODO: format?
					-- TODO: debug event
					self.onTextChange = backup
				end

				local secondaryTextStr =
					"You should receive it shortly! If not, please verify your phone number, or try later."
				if System.IsUserUnder13 == true then
					secondaryTextStr =
						"Your parent should receive it shortly! If not, please verify the phone number, or try later."
				end

				local secondaryText = ui:createText(secondaryTextStr, {
					color = Color(200, 200, 200),
					size = "small",
				})
				secondaryText:setParent(drawer)

				drawer:updateConfig({
					layoutContent = function(self)
						-- here, self.Height can be reduced, but not increased
						-- TODO: enforce this within drawer module

						local padding = theme.paddingBig

						local maxWidth = math.min(300, self.Width - padding * 2)
						text.object.MaxWidth = maxWidth
						secondaryText.object.MaxWidth = maxWidth

						local w = math.min(self.Width, math.max(text.Width, okBtn.Width, 300) + padding * 2)

						local availableWidth = w - padding * 2
						codeInput.Width = availableWidth

						self.Width = w
						self.Height = Screen.SafeArea.Bottom
							+ okBtn.Height
							+ text.Height
							+ secondaryText.Height
							+ codeInput.Height
							+ padding * 5

						secondaryText.pos = {
							self.Width * 0.5 - secondaryText.Width * 0.5,
							Screen.SafeArea.Bottom + padding,
						}
						okBtn.pos = {
							self.Width * 0.5 - okBtn.Width * 0.5,
							secondaryText.pos.Y + secondaryText.Height + padding,
						}
						codeInput.pos = {
							self.Width * 0.5 - codeInput.Width * 0.5,
							okBtn.pos.Y + okBtn.Height + padding,
						}
						text.pos = {
							self.Width * 0.5 - text.Width * 0.5,
							codeInput.pos.Y + codeInput.Height + padding,
						}

						LocalEvent:Send("signup_drawer_height_update", self.Height)
					end,
				})

				drawer:show()
				Timer(0.2, function()
					codeInput:focus()
				end)
			end,
			onExit = function()
				drawer:updateConfig({
					layoutContent = function(_) end,
				})
				drawer:hide()
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

	-- Prompts the user for a phone number
	local createPhoneNumberStep = function()
		local step = flow:createStep({
			onEnter = function()
				config.phoneNumberStep()

				showBackButton()
				showCoinsButton()

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
				-- okBtn:disable()

				local selectedPrefix = "1"

				local textStr = "Final step! What's your phone number?"
				if System.IsUserUnder13 == true then
					textStr = "Final step! What's your parent's phone number?"
				end

				local text = ui:createText(textStr, {
					color = Color.White,
				})
				text:setParent(drawer)

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

				okBtn.onRelease = function()
					okBtn:disable()
					-- signupFlow:push(createAvatarEditorStep())
					local phoneNumber = "+" .. selectedPrefix .. phonenumbers:sanitize(phoneInput.Text)

					-- construct user patch data
					local data = { phone = phoneNumber }
					if System.IsUserUnder13 == true then
						data = { parentPhone = phoneNumber }
					end

					api:patchUserInfo(data, function(err)
						if err ~= nil then
							print("ERR:", err)
							okBtn:enable()
							return
						end
						signupFlow:push(createVerifyPhoneNumberStep())
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
					System:DebugEvent("User did pick country for phone number")
					self.Text = countryLabels[index] -- "FR +33"
					-- find the position of the + char
					local plusPos = string.find(self.Text, "+") -- 4
					-- get the substring after the + char
					local prefix = string.sub(self.Text, plusPos + 1) -- "33"
					selectedPrefix = prefix
					layoutPhoneInput()
				end

				phoneInput.onTextChange = function(self)
					local backup = self.onTextChange
					self.onTextChange = nil

					local res = phonenumbers:extractCountryCode(self.Text)
					if res.countryCode ~= nil then
						self.Text = res.remainingNumber
						countryInput.Text = res.countryCode .. " +" .. res.countryPrefix
						selectedPrefix = res.countryPrefix
						layoutPhoneInput()
					end

					self.onTextChange = backup
				end

				local secondaryText = ui:createText(
					"Cubzh asks for phone numbers to secure accounts and fight against cheaters. Information kept private. 🔑",
					{
						color = Color(200, 200, 200),
						size = "small",
					}
				)
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
						text.pos = {
							self.Width * 0.5 - text.Width * 0.5,
							countryInput.pos.Y + countryInput.Height + padding,
						}

						LocalEvent:Send("signup_drawer_height_update", self.Height)
					end,
				})

				drawer:show()
				Timer(0.2, function()
					phoneInput:focus()
				end)
			end,
			onExit = function() end,
			onRemove = function() end,
		})

		return step
	end

	-- Prompts the user for a username
	local createUsernameInputStep = function(config)
		local defaultConfig = {
			username = "",
		}
		config = conf:merge(defaultConfig, config)

		local requests = {}
		local step = flow:createStep({
			onEnter = function()
				showBackButton()
				showCoinsButton()

				-- DRAWER
				if drawer ~= nil then
					drawer:clear()
				else
					drawer = drawerModule:create({ ui = ui })
				end

				local DEFAULT_LABEL = "How should we call you?"

				local title = ui:createText(str:upperFirstChar(loc("username", "title")) .. " 🙂", Color.White)
				title:setParent(drawer)

				local loadingLabel = ui:createText(str:upperFirstChar(loc("loading...")), Color.White)
				loadingLabel:setParent(drawer)
				loadingLabel:hide()

				local usernameLabel = ui:createText(DEFAULT_LABEL, Color.White, "default")
				usernameLabel:setParent(drawer)

				local usernameInput = ui:createTextInput(
					"",
					str:upperFirstChar(loc("don't use your real name!")),
					{ textSize = "default" }
				)
				usernameInput:setParent(drawer)

				local secondaryText = ui:createText(
					"Username must start with a letter (a-z) and can include letters (a-z) and numbers (0-9). ⚠️ Choose carefully, usernames can't be changed after account creation!",
					{
						color = Color(200, 200, 200),
						size = "small",
					}
				)
				secondaryText:setParent(drawer)

				local confirmButton = ui:buttonPositive({
					content = "This is it!",
					padding = 10,
				})
				confirmButton:setParent(drawer)

				local function showLoading()
					loadingLabel:show()
					usernameLabel:hide()
					usernameInput:hide()
					confirmButton:hide()
					secondaryText:hide()
				end

				local function hideLoading()
					loadingLabel:hide()
					usernameLabel:show()
					usernameInput:show()
					confirmButton:show()
					secondaryText:show()
				end

				local userCheckTimer = nil
				local usernameCheckRequest = nil
				local username = nil
				local usernameKey = nil

				usernameInput.onTextChange = function(self)
					-- disable onTextChange while we normalize the text
					local backup = self.onTextChange
					self.onTextChange = nil

					local s = str:normalize(self.Text)
					s = str:lower(s)
					self.Text = s

					-- re-enable onTextChange
					self.onTextChange = backup

					-- use timer to avoid spamming the API

					usernameLabel.Text = "⚙️ checking..."
					-- TODO: re-layout drawer content following the change in usernameLabel.Text

					-- Cancel previous request if any
					if usernameCheckRequest ~= nil then
						usernameCheckRequest:Cancel()
						usernameCheckRequest = nil
					end

					if userCheckTimer ~= nil then
						-- timer already exists, cancel it
						userCheckTimer:Cancel()
						userCheckTimer = nil
					end

					userCheckTimer = Timer(1.0, function()
						-- check username
						if s == "" then
							usernameLabel.Text = DEFAULT_LABEL
						else
							usernameCheckRequest = api:checkUsername(s, function(ok, response)
								if ok == false or response == nil then
									usernameLabel.Text = "❌ failed to validate username"
								else
									if response.format == false then
										usernameLabel.Text = "❌ invalid format"
									elseif response.available == false then
										usernameLabel.Text = "❌ username already taken"
									elseif response.appropriate == false then
										usernameLabel.Text = "❌ username is inappropriate"
									else
										usernameLabel.Text = "✅ username is available"
										username = s
										usernameKey = response.key
									end
								end
								-- re-layout drawer content following the change in usernameLabel.Text
								-- TODO: drawer:parentDidResize() -- doesn't work
							end)
						end
					end)

					-- if didStartTyping == false and self.Text ~= "" then
					-- 	didStartTyping = true
					-- 	System:DebugEvent("LOGIN_STARTED_TYPING_USERNAME")
					-- end
				end

				confirmButton.onRelease = function()
					showLoading()
					if usernameInput.Text ~= "" then
						local req = api:patchUserInfo({ username = username, usernameKey = usernameKey }, function(err)
							if err == nil then
								-- success
								Player.Username = username
								System.AskedForMagicKey = false
								signupFlow:push(createPhoneNumberStep())
							else
								-- failure
								usernameLabel.Text = "❌ " .. err
								hideLoading()
							end
						end)
						table.insert(requests, req)
					else
						-- text input is empty
						usernameLabel.Text = "❌ Please enter a magic key"
						hideLoading()
					end
				end

				drawer:updateConfig({
					layoutContent = function(self)
						-- here, self.Height can be reduced, but not increased
						-- TODO: enforce this within drawer module

						local padding = theme.paddingBig

						-- local maxWidth = math.min(300, self.Width - padding * 2)
						-- text.object.MaxWidth = maxWidth
						-- secondaryText.object.MaxWidth = maxWidth

						-- local w = math.min(self.Width, math.max(text.Width, confirmButton.Width, 300) + padding * 2)
						local w = 300 + (padding * 2)

						secondaryText.object.MaxWidth = w - padding * 2

						local availableWidth = w - padding * 2
						usernameInput.Width = availableWidth

						self.Width = w
						self.Height = Screen.SafeArea.Bottom
							+ title.Height
							+ usernameLabel.Height
							+ usernameInput.Height
							+ secondaryText.Height
							+ confirmButton.Height
							+ padding * 6

						confirmButton.pos = {
							self.Width * 0.5 - confirmButton.Width * 0.5,
							Screen.SafeArea.Bottom + padding,
						}

						secondaryText.pos = {
							self.Width * 0.5 - secondaryText.Width * 0.5,
							confirmButton.pos.Y + confirmButton.Height + padding,
						}

						usernameInput.pos = {
							self.Width * 0.5 - usernameInput.Width * 0.5,
							secondaryText.pos.Y + secondaryText.Height + padding,
						}

						usernameLabel.pos = {
							self.Width * 0.5 - usernameLabel.Width * 0.5,
							usernameInput.pos.Y + usernameInput.Height + padding,
						}

						title.pos = {
							self.Width * 0.5 - title.Width * 0.5,
							usernameLabel.pos.Y + usernameLabel.Height + padding,
						}

						loadingLabel.pos = {
							self.Width * 0.5 - loadingLabel.Width * 0.5,
							self.Height * 0.5 - loadingLabel.Height * 0.5,
						}

						LocalEvent:Send("signup_drawer_height_update", self.Height)
					end,
				})

				drawer:show()
				Timer(0.2, function()
					usernameInput:focus()
				end)
			end,
			onExit = function()
				drawer:updateConfig({
					layoutContent = function(_) end,
				})
				drawer:hide()
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

	local createLoginOptionsStep = function(config)
		local defaultConfig = {
			username = "",
			password = false,
			magickey = false,
		}
		config = conf:merge(defaultConfig, config)

		local requests = {}
		local frame
		local step = flow:createStep({
			onEnter = function()
				frame = ui:frameGenericContainer()

				local title = ui:createText(str:upperFirstChar(loc("authentication", "title")) .. " 🔑", Color.White)
				title:setParent(frame)

				local errorLabel = ui:createText("", Color.White)
				errorLabel:setParent(frame)
				errorLabel:hide()

				local loadingLabel = ui:createText(str:upperFirstChar(loc("loading...")), Color.White)
				loadingLabel:setParent(frame)
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

				if config.password then
					passwordLabel = ui:createText("🔑 " .. str:upperFirstChar(loc("password")), Color.White, "small")
					passwordLabel:setParent(frame)

					passwordInput = ui:createTextInput(
						"",
						str:upperFirstChar(loc("password")),
						{ textSize = "default", password = true }
					)
					passwordInput:setParent(frame)

					passwordButton = ui:buttonNeutral({ content = "✅" })
					passwordButton:setParent(frame)
				end

				if config.magickey then
					magicKeyLabel =
						ui:createText(config.password and "or, send me a:" or "send me a:", Color.White, "default")
					magicKeyLabel:setParent(frame)

					magicKeyButton = ui:buttonPositive({ content = str:upperFirstChar(loc("✨ magic key ✨")) })
					magicKeyButton:setParent(frame)

					magicKeyButton.onRelease = function()
						showLoading()
						local req = api:getMagicKey(config.username, function(err, _)
							hideLoading()
							if err == nil then
								System.AskedForMagicKey = true
								local step = createMagicKeyInputStep({ usernameOrEmail = config.username })
								signupFlow:push(step)
							else
								errorLabel.Text = "❌ Sorry, failed to send magic key"
							end
						end)
						table.insert(requests, req)
					end
				end

				frame.parentDidResize = function(self)
					self.Width = math.min(
						400,
						Screen.Width - Screen.SafeArea.Right - Screen.SafeArea.Left - theme.paddingBig * 2
					)
					self.Height = title.Height + theme.paddingBig * 2

					if config.password then
						self.Height = self.Height + passwordLabel.Height + theme.paddingTiny + passwordInput.Height
					end
					if config.magickey then
						self.Height = self.Height + magicKeyLabel.Height + theme.paddingTiny + magicKeyButton.Height
					end
					if config.password and config.magickey then
						self.Height = self.Height + theme.padding
					end

					title.pos = {
						self.Width * 0.5 - title.Width * 0.5,
						self.Height - theme.paddingBig - title.Height,
					}

					local y = title.pos.Y

					if config.password then
						passwordButton.Height = passwordInput.Height

						passwordLabel.pos.Y = y - passwordLabel.Height
						passwordLabel.pos.X = theme.paddingBig

						passwordInput.Width = self.Width
							- passwordButton.Width
							- theme.paddingTiny
							- theme.paddingBig * 2

						passwordInput.pos.X = theme.paddingBig
						passwordInput.pos.Y = passwordLabel.pos.Y - theme.paddingTiny - passwordInput.Height

						passwordButton.pos.X = passwordInput.pos.X + passwordInput.Width + theme.paddingTiny
						passwordButton.pos.Y = passwordInput.pos.Y

						y = passwordButton.pos.Y - theme.paddingTiny
					end

					if config.magickey then
						magicKeyLabel.pos.X = self.Width * 0.5 - magicKeyLabel.Width * 0.5
						magicKeyLabel.pos.Y = y - magicKeyLabel.Height

						magicKeyButton.Width = self.Width - theme.paddingBig * 2
						magicKeyButton.pos.X = theme.paddingBig
						magicKeyButton.pos.Y = magicKeyLabel.pos.Y - theme.paddingTiny - magicKeyButton.Height
					end

					loadingLabel.pos = {
						self.Width * 0.5 - loadingLabel.Width * 0.5,
						self.Height * 0.5 - loadingLabel.Height * 0.5,
					}
					self.pos = { Screen.Width * 0.5 - self.Width * 0.5, Screen.Height * 0.5 - self.Height * 0.5 }
				end
				frame:parentDidResize()
				targetPos = frame.pos:Copy()
				frame.pos.Y = frame.pos.Y - 50
				ease:outBack(frame, animationTime).pos = targetPos
			end,
			onExit = function()
				for _, req in ipairs(requests) do
					req:Cancel()
				end
				frame:remove()
				frame = nil
			end,
			onRemove = function() end,
		})

		return step
	end

	local createLoginStep = function()
		local requests = {}
		local frame

		local step = flow:createStep({
			onEnter = function()
				config.loginStep()

				-- BACK BUTTON
				showBackButton()

				frame = ui:frameGenericContainer()

				local title = ui:createText(str:upperFirstChar(loc("who are you?")) .. " 🙂", Color.White)
				title:setParent(frame)

				local errorLabel = ui:createText("", Color.Black)
				errorLabel:setParent(frame)
				errorLabel:hide()

				local loadingLabel = ui:createText(str:upperFirstChar(loc("loading...")), Color.White)
				loadingLabel:setParent(frame)
				loadingLabel:hide()

				local usernameInput = ui:createTextInput("", str:upperFirstChar(loc("username or email")))
				usernameInput:setParent(frame)

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

				local loginButton = ui:buttonPositive({
					content = "✨ " .. str:upperFirstChar(loc("login", "button")) .. " ✨",
					padding = 10,
				})
				loginButton:setParent(frame)

				frame.parentDidResize = function(self)
					self.Height = title.Height
						+ usernameInput.Height
						+ loginButton.Height
						+ theme.padding * 2
						+ theme.paddingBig * 2

					if errorLabel.Text ~= "" then
						self.Height = self.Height + errorLabel.Height + theme.padding
					end

					self.Width = math.min(
						400,
						Screen.Width - Screen.SafeArea.Right - Screen.SafeArea.Left - theme.paddingBig * 2
					)

					title.pos = {
						self.Width * 0.5 - title.Width * 0.5,
						self.Height - theme.paddingBig - title.Height,
					}

					local y = title.pos.Y
					if errorLabel.Text ~= "" then
						errorLabel:show()
						errorLabel.pos = {
							theme.paddingBig,
							y - theme.padding - errorLabel.Height,
						}
						y = errorLabel.pos.Y
					else
						errorLabel:hide()
					end

					usernameInput.Width = self.Width - theme.paddingBig * 2
					usernameInput.pos = {
						theme.paddingBig,
						y - theme.padding - usernameInput.Height,
					}

					loginButton.Width = self.Width - theme.paddingBig * 2
					loginButton.pos = { theme.paddingBig, theme.paddingBig }

					loadingLabel.pos = {
						self.Width * 0.5 - loadingLabel.Width * 0.5,
						self.Height * 0.5 - loadingLabel.Height * 0.5,
					}

					self.pos = { Screen.Width * 0.5 - self.Width * 0.5, Screen.Height * 0.5 - self.Height * 0.5 }
				end
				frame:parentDidResize()
				targetPos = frame.pos:Copy()
				frame.pos.Y = frame.pos.Y - 50
				ease:outBack(frame, animationTime).pos = targetPos

				local function showLoading()
					loadingLabel:show()
					usernameInput:hide()
					loginButton:hide()
				end

				local function hideLoading()
					loadingLabel:hide()
					usernameInput:show()
					loginButton:show()
					frame:parentDidResize()
				end

				loginButton.onRelease = function()
					-- save in case user comes back with magic key after closing app
					System.SavedUsernameOrEmail = usernameInput.Text

					-- if user asked for magic key in the past, this is the best time to forget about it.
					-- if System.AskedForMagicKey == false then
					-- 	print("[STATEMENT NOT NEEDED] System.AskedForMagicKey = false")
					-- end
					System.AskedForMagicKey = false

					errorLabel.Text = ""
					showLoading()
					local req = api:getLoginOptions(usernameInput.Text, function(err, res)
						-- res.username, res.password, res.magickey
						if err == nil then
							-- NOTE: res.username is sanitized
							local step = createLoginOptionsStep({
								username = res.username,
								password = res.password,
								magickey = res.magickey,
							})
							signupFlow:push(step)
						else
							errorLabel.Text = "❌ " .. err
							hideLoading()
						end
					end)
					table.insert(requests, req)
				end
			end, -- onEnter
			onExit = function()
				for _, req in ipairs(requests) do
					req:Cancel()
				end
				frame:remove()
				frame = nil
			end,
			onRemove = function()
				removeBackButton()
			end,
		})
		return step
	end

	local createDOBStep = function()
		local requests = {}
		local step = flow:createStep({
			onEnter = function()
				config.dobStep()

				showBackButton()
				showCoinsButton()

				-- DRAWER
				if drawer ~= nil then
					drawer:clear()
				else
					drawer = drawerModule:create({ ui = ui })
				end

				local okBtn = ui:buttonPositive({ content = "Confirm", textSize = "big", padding = 10 })
				okBtn:setParent(drawer)
				okBtn:disable()

				local text = ui:createText("Looking good! Now, what's your date of birth, in real life? 🎂", {
					color = Color.White,
				})
				text:setParent(drawer)

				local secondaryText = ui:createText(
					"Cubzh is an online social universe. We have to ask this to protect the young ones and will keep that information private. 🔑",
					{
						color = Color(200, 200, 200),
						size = "small",
					}
				)
				secondaryText:setParent(drawer)

				local monthNames = {
					str:upperFirstChar(loc("january")),
					str:upperFirstChar(loc("february")),
					str:upperFirstChar(loc("march")),
					str:upperFirstChar(loc("april")),
					str:upperFirstChar(loc("may")),
					str:upperFirstChar(loc("june")),
					str:upperFirstChar(loc("july")),
					str:upperFirstChar(loc("august")),
					str:upperFirstChar(loc("september")),
					str:upperFirstChar(loc("october")),
					str:upperFirstChar(loc("november")),
					str:upperFirstChar(loc("december")),
				}
				local dayNumbers = {}
				for i = 1, 31 do
					table.insert(dayNumbers, "" .. i)
				end

				local years = {}
				local yearStrings = {}
				local currentYear = math.floor(tonumber(os.date("%Y")))
				local currentMonth = math.floor(tonumber(os.date("%m")))
				local currentDay = math.floor(tonumber(os.date("%d")))

				for i = currentYear, currentYear - 100, -1 do
					table.insert(years, i)
					table.insert(yearStrings, "" .. i)
				end

				local function isLeapYear(year)
					if year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then
						return true
					else
						return false
					end
				end

				local function nbDays(m)
					if m == 2 then
						if isLeapYear(m) then
							return 29
						else
							return 28
						end
					else
						local days = { 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
						return days[m]
					end
				end

				local monthInput = ui:createComboBox(str:upperFirstChar(loc("month")), monthNames)
				monthInput:setParent(drawer)

				local dayInput = ui:createComboBox(str:upperFirstChar(loc("day")), dayNumbers)
				dayInput:setParent(drawer)

				local yearInput = ui:createComboBox(str:upperFirstChar(loc("year")), yearStrings)
				yearInput:setParent(drawer)

				local checkDOB = function()
					local r = true
					local daysInMonth = nbDays(cache.dob.month)

					if cache.dob.year == nil or cache.dob.month == nil or cache.dob.day == nil then
						-- if config and config.errorIfIncomplete == true then
						-- birthdayInfo.Text = "❌ " .. loc("required")
						-- birthdayInfo.Color = theme.errorTextColor
						r = false
						-- else
						-- 	birthdayInfo.Text = ""
						-- end
					elseif cache.dob.day < 0 or cache.dob.day > daysInMonth then
						-- birthdayInfo.Text = "❌ invalid date"
						-- birthdayInfo.Color = theme.errorTextColor
						r = false
					elseif
						cache.dob.year > currentYear
						or (cache.dob.year == currentYear and cache.dob.month > currentMonth)
						or (
							cache.dob.year == currentYear
							and cache.dob.month == currentMonth
							and cache.dob.day > currentDay
						)
					then
						-- birthdayInfo.Text = "❌ users from the future not allowed"
						-- birthdayInfo.Color = theme.errorTextColor
						r = false
						-- else
						-- 	birthdayInfo.Text = ""
					end

					-- birthdayInfo.pos.X = node.Width - birthdayInfo.Width
					return r
				end

				monthInput.onSelect = function(self, index)
					System:DebugEvent("User did select DOB month")
					cache.dob.monthIndex = index
					cache.dob.month = index
					self.Text = monthNames[index]
					if checkDOB() then
						okBtn:enable()
					end
				end

				dayInput.onSelect = function(self, index)
					System:DebugEvent("User did select DOB day")
					cache.dob.dayIndex = index
					cache.dob.day = index
					self.Text = dayNumbers[index]
					if checkDOB() then
						okBtn:enable()
					end
				end

				yearInput.onSelect = function(self, index)
					System:DebugEvent("User did select DOB year")
					cache.dob.yearIndex = index
					cache.dob.year = years[index]
					self.Text = yearStrings[index]
					if checkDOB() then
						okBtn:enable()
					end
				end

				if cache.dob.monthIndex ~= nil then
					monthInput.selectedRow = cache.dob.monthIndex
					monthInput.Text = monthNames[cache.dob.monthIndex]
				end
				if cache.dob.dayIndex ~= nil then
					dayInput.selectedRow = cache.dob.dayIndex
					dayInput.Text = dayNumbers[cache.dob.dayIndex]
				end
				if cache.dob.yearIndex ~= nil then
					yearInput.selectedRow = cache.dob.yearIndex
					yearInput.Text = years[cache.dob.yearIndex]
				end

				if checkDOB() then
					okBtn:enable()
				end

				okBtn.onRelease = function()
					-- TODO: showLoading()

					-- construct date of birth string (mm-dd-yyyy)
					local dobStr = string.format("%02d-%02d-%04d", cache.dob.month, cache.dob.day, cache.dob.year)

					-- send API request to update user's date of birth
					local req = api:patchUserInfo({ dob = dobStr }, function(err)
						if err == nil then
							-- success
							-- Store information about user being <13yo
							System.IsUserUnder13 = cache.dob.year > currentYear - 13
							-- Go to next step
							signupFlow:push(createUsernameInputStep())
						else
							-- failure
							-- TODO: hideLoading()
							-- TODO: error message?
						end
					end)
					table.insert(requests, req)
				end

				drawer:updateConfig({
					layoutContent = function(self)
						-- here, self.Height can be reduced, but not increased
						-- TODO: enforce this within drawer module

						local padding = theme.paddingBig
						local smallPadding = theme.padding

						local maxWidth = math.min(300, self.Width - padding * 2)
						text.object.MaxWidth = maxWidth
						secondaryText.object.MaxWidth = maxWidth

						local w = math.min(self.Width, math.max(text.Width, okBtn.Width, 300) + padding * 2)

						local availableWidthForInputs = w - padding * 2 - smallPadding * 2

						monthInput.Width = availableWidthForInputs * 0.5
						dayInput.Width = availableWidthForInputs * 0.2
						yearInput.Width = availableWidthForInputs * 0.3

						self.Width = w
						self.Height = Screen.SafeArea.Bottom
							+ okBtn.Height
							+ monthInput.Height
							+ text.Height
							+ secondaryText.Height
							+ padding * 5

						okBtn.pos = { self.Width * 0.5 - okBtn.Width * 0.5, Screen.SafeArea.Bottom + padding }
						secondaryText.pos = {
							self.Width * 0.5 - secondaryText.Width * 0.5,
							okBtn.pos.Y + okBtn.Height + padding,
						}
						monthInput.pos = {
							padding,
							secondaryText.pos.Y + secondaryText.Height + padding,
						}
						dayInput.pos = {
							monthInput.pos.X + monthInput.Width + smallPadding,
							secondaryText.pos.Y + secondaryText.Height + padding,
						}
						yearInput.pos = {
							dayInput.pos.X + dayInput.Width + smallPadding,
							secondaryText.pos.Y + secondaryText.Height + padding,
						}
						text.pos =
							{ self.Width * 0.5 - text.Width * 0.5, monthInput.pos.Y + monthInput.Height + padding }

						LocalEvent:Send("signup_drawer_height_update", self.Height)
					end,
				})

				drawer:show()
			end,
			onExit = function()
				for _, req in ipairs(requests) do
					req:Cancel()
				end
			end,
			onRemove = function() end,
		})

		return step
	end

	local createAvatarEditorStep = function()
		local avatarEditor
		local okBtn
		local infoFrame
		local info
		local avatarUpdateListener
		-- local nbPartsToChange = 3
		local nbPartsToChange = 1
		local partsChanged = {}

		local step = flow:createStep({
			onEnter = function()
				config.avatarEditorStep()

				showBackButton()
				showCoinsButton()

				infoFrame = ui:frameTextBackground()

				local s = "Change at least %d things to continue!"
				if nbPartsToChange == 1 then
					s = "Change at least %d thing to continue!"
				end

				info = ui:createText(string.format(s, nbPartsToChange), {
					color = Color.White,
				})
				info:setParent(infoFrame)
				info.pos = { padding, padding }

				okBtn = ui:buttonPositive({ content = "Done!", textSize = "big", padding = 10 })
				okBtn.onRelease = function(_)
					-- go to next step
					signupFlow:push(createDOBStep())
				end
				okBtn:disable()

				local function layoutInfoFrame()
					local parent = infoFrame.parent
					if not parent then
						return
					end
					info.object.MaxWidth = parent.Width - okBtn.Width - padding * 5
					infoFrame.Width = info.Width + padding * 2
					infoFrame.Height = info.Height + padding * 2
					infoFrame.pos = {
						okBtn.pos.X - infoFrame.Width - padding,
						infoFrame.Height > okBtn.Height and okBtn.pos.Y
							or okBtn.pos.Y + okBtn.Height * 0.5 - infoFrame.Height * 0.5,
					}
				end

				local function updateProgress()
					local remaining = math.max(0, nbPartsToChange - cache.nbAvatarPartsChanged)
					if remaining == 0 then
						info.text = "You're good to go!"
						okBtn:enable()
					else
						local s = "Change %d more things to continue!"
						if remaining == 1 then
							s = "Change %d more thing to continue!"
						end

						info.text = string.format(s, remaining)
					end
				end

				avatarUpdateListener = LocalEvent:Listen("avatar_editor_update", function(config)
					if config.skinColorIndex then
						if not partsChanged["skin"] then
							cache.nbAvatarPartsChanged = cache.nbAvatarPartsChanged + 1
							partsChanged["skin"] = true
						end
					end
					if config.eyesIndex then
						if not partsChanged["eyes"] then
							cache.nbAvatarPartsChanged = cache.nbAvatarPartsChanged + 1
							partsChanged["eyes"] = true
						end
					end
					if config.eyesColorIndex then
						if not partsChanged["eyes"] then
							cache.nbAvatarPartsChanged = cache.nbAvatarPartsChanged + 1
							partsChanged["eyes"] = true
						end
					end
					if config.noseIndex then
						if not partsChanged["nose"] then
							cache.nbAvatarPartsChanged = cache.nbAvatarPartsChanged + 1
							partsChanged["nose"] = true
						end
					end
					if config.jacket then
						if not partsChanged["jacket"] then
							cache.nbAvatarPartsChanged = cache.nbAvatarPartsChanged + 1
							partsChanged["jacket"] = true
						end
					end
					if config.hair then
						if not partsChanged["hair"] then
							cache.nbAvatarPartsChanged = cache.nbAvatarPartsChanged + 1
							partsChanged["hair"] = true
						end
					end
					if config.pants then
						if not partsChanged["pants"] then
							cache.nbAvatarPartsChanged = cache.nbAvatarPartsChanged + 1
							partsChanged["pants"] = true
						end
					end
					if config.boots then
						if not partsChanged["boots"] then
							cache.nbAvatarPartsChanged = cache.nbAvatarPartsChanged + 1
							partsChanged["boots"] = true
						end
					end

					updateProgress()
					layoutInfoFrame()
				end)

				updateProgress()

				-- DRAWER
				if drawer ~= nil then
					drawer:clear()
				else
					drawer = drawerModule:create({ ui = ui })
				end

				okBtn:setParent(drawer)
				infoFrame:setParent(drawer)

				avatarEditor = require("ui_avatar_editor"):create({
					saveOnChangeIfLocalPlayer = true,
					ui = ui,
					requestHeightCallback = function(height)
						drawer:updateConfig({
							layoutContent = function(self)
								local drawerHeight = height + padding * 2 + Screen.SafeArea.Bottom
								drawerHeight = math.floor(math.min(Screen.Height * 0.6, drawerHeight))

								self.Height = drawerHeight

								if avatarEditor then
									avatarEditor.Width = self.Width - padding * 2
									avatarEditor.Height = drawerHeight - Screen.SafeArea.Bottom - padding * 2
									avatarEditor.pos = { padding, Screen.SafeArea.Bottom + padding }
								end

								okBtn.pos = {
									self.Width - okBtn.Width - padding,
									self.Height + padding,
								}

								layoutInfoFrame()

								LocalEvent:Send("signup_drawer_height_update", drawerHeight)
							end,
						})
						drawer:bump()
					end,
				})

				avatarEditor:setParent(drawer)

				drawer:updateConfig({
					layoutContent = function(self)
						avatarEditor.Width = self.Width - padding * 2
						avatarEditor.Height = self.Height - padding * 2 - Screen.SafeArea.Bottom

						avatarEditor.pos = { padding, Screen.SafeArea.Bottom + padding }

						okBtn.pos = {
							drawer.Width - okBtn.Width - padding,
							drawer.Height + padding,
						}

						LocalEvent:Send("signup_drawer_height_update", self.Height)
					end,
				})

				drawer:show()
			end,
			onExit = function()
				drawer:hide()
				okBtn:remove()
				if avatarUpdateListener then
					avatarUpdateListener:Remove()
				end
			end,
			onRemove = function() end,
		})

		return step
	end

	local createAvatarPreviewStep = function()
		local step = flow:createStep({
			onEnter = function()
				config.avatarPreviewStep()

				showBackButton()
				removeCoinsButton()

				-- DRAWER
				if drawer ~= nil then
					drawer:clear()
				else
					drawer = drawerModule:create({ ui = ui })
				end

				local okBtn = ui:buttonPositive({ content = "Ok, let's do this!", textSize = "big", padding = 10 })
				okBtn:setParent(drawer)
				okBtn.onRelease = function()
					signupFlow:push(createAvatarEditorStep())
				end

				local text = ui:createText("You need an AVATAR to visit Cubzh worlds! Let's create one now ok? 🙂", {
					color = Color.White,
				})
				text:setParent(drawer)

				drawer:updateConfig({
					layoutContent = function(self)
						-- here, self.Height can be reduced, but not increased
						-- TODO: enforce this within drawer module

						text.object.MaxWidth = math.min(350, self.Width - theme.paddingBig * 2)

						self.Width = math.min(self.Width, math.max(text.Width, okBtn.Width) + theme.paddingBig * 2)
						self.Height = Screen.SafeArea.Bottom + okBtn.Height + text.Height + theme.paddingBig * 3

						okBtn.pos = { self.Width * 0.5 - okBtn.Width * 0.5, Screen.SafeArea.Bottom + theme.paddingBig }
						text.pos =
							{ self.Width * 0.5 - text.Width * 0.5, okBtn.pos.Y + okBtn.Height + theme.paddingBig }

						LocalEvent:Send("signup_drawer_height_update", self.Height)
					end,
				})

				drawer:show()
			end,
			onExit = function()
				drawer:updateConfig({
					layoutContent = function(_) end,
				})
				drawer:hide()
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

	local createSignUpOrLoginStep = function()
		local startBtn
		local step = flow:createStep({
			onEnter = function()
				System:DebugEvent("App starts signup or login step")

				config.signUpOrLoginStep()

				if loginBtn == nil then
					loginBtn = ui:buttonSecondary({ content = "Login", textSize = "small" })
					-- loginBtn = ui:createButton("Login", { textSize = "small", borders = false })
					-- loginBtn:setColor(Color(0, 0, 0, 0.4), Color(255, 255, 255))
					loginBtn.parentDidResize = function(self)
						ease:cancel(self)
						self.pos = {
							Screen.Width - Screen.SafeArea.Right - self.Width - padding,
							Screen.Height - Screen.SafeArea.Top - self.Height - padding,
						}
					end

					loginBtn.onRelease = function()
						signupFlow:push(createLoginStep())
					end
				end
				loginBtn:parentDidResize()
				local targetPos = loginBtn.pos:Copy()
				loginBtn.pos.X = Screen.Width
				ease:outSine(loginBtn, animationTime).pos = targetPos

				startBtn = ui:buttonPositive({ content = "Start", textSize = "big", padding = 10 })
				startBtn.parentDidResize = function(self)
					ease:cancel(self)
					self.Width = 120
					self.Height = 60
					self.pos = {
						Screen.Width * 0.5 - self.Width * 0.5,
						Screen.Height / 5.0 - self.Height * 0.5,
					}
				end
				startBtn:parentDidResize()
				targetPos = startBtn.pos:Copy()
				startBtn.pos.Y = startBtn.pos.Y - 50
				ease:outBack(startBtn, animationTime).pos = targetPos

				startBtn.onRelease = function()
					signupFlow:push(createAvatarPreviewStep())
				end
			end,
			onExit = function()
				startBtn:remove()
				startBtn = nil
				loginBtn:remove()
				loginBtn = nil
			end,
			onRemove = function() end,
		})
		return step
	end

	local createCheckAppVersionAndCredentialsStep = function()
		local loadingFrame
		local step = flow:createStep({
			onEnter = function()
				if loadingFrame == nil then
					loadingFrame = ui:frameTextBackground()

					local text =
						ui:createText("You need an AVATAR to visit Cubzh worlds! Let's create one now ok? 🙂", {
							color = Color.White,
						})
					text:setParent(loadingFrame)
					text.pos = { theme.padding, theme.padding }

					loadingFrame.parentDidResize = function(self)
						ease:cancel(self)

						loadingFrame.Width = text.Width + theme.padding * 2
						loadingFrame.Height = text.Height + theme.padding * 2

						self.pos = {
							Screen.Width * 0.5 - self.Width * 0.5,
							Screen.Height / 5.0 - self.Height * 0.5,
						}
					end
					loadingFrame:parentDidResize()

					local function parseVersion(versionStr)
						local maj, min, patch = versionStr:match("(%d+)%.(%d+)%.(%d+)")
						maj = math.floor(tonumber(maj))
						min = math.floor(tonumber(min))
						patch = math.floor(tonumber(patch))
						return maj, min, patch
					end

					text.Text = "Checking app version..."
					loadingFrame:parentDidResize()

					local checks = {}

					--
					--                                    minAppVersion()
					--                                        |        \
					--                                     Ok |         \
					--                                        |        error("app needs updating")
					--                                        |
					--                               userAccountExists()?
					--                                     /      \
					--                                Yes /        \ No
					--                                   /          \
					--                                  /            \
					--                       askedMagicKey()?      createAccount()
					--                          /      \               /       \
					--                     Yes /        \ No          / Ok      \ Error
					--                        /          \           /           \
					--                       /            \         /             \
					--     displayMagicKeyPrompt()  checkUserAccountComplete()   error("account creation failed")
					--        (can be cancelled)          /        \
					--         TODO: next step           /          \
					--                |                 /            \
					--              ?????           No /              \ Yes
					--                                /                \
					--                               /                  \
					--            pushStep("SignUpOrLoginStep")     goToMainHomeScreen()
					--

					checks.error = function(optionalErrorMsg)
						text.Text = ""
						loadingFrame:hide()

						local msgStr = "Sorry, something went wrong. 😕"
						if type(optionalErrorMsg) == "string" and optionalErrorMsg ~= "" then
							msgStr = optionalErrorMsg
						end

						-- Show error message with retry button
						-- Click on button should call checks.minAppVersion()

						local errorBox = ui:frameTextBackground()
						local errorText = ui:createText(msgStr, { color = Color.White, size = "default" })
						errorText:setParent(errorBox)
						local retryBtn = ui:buttonNeutral({ content = "Retry", padding = theme.padding })
						retryBtn:setParent(errorBox)

						errorBox.parentDidResize = function(self)
							ease:cancel(self)
							self.Width = math.max(errorText.Width, retryBtn.Width) + theme.paddingBig * 2
							self.Height = errorText.Height + theme.padding + retryBtn.Height + theme.paddingBig * 2

							retryBtn.pos = {
								self.Width * 0.5 - retryBtn.Width * 0.5,
								theme.paddingBig,
							}

							errorText.pos = {
								self.Width * 0.5 - errorText.Width * 0.5,
								retryBtn.pos.Y + retryBtn.Height + padding,
							}

							self.pos = {
								Screen.Width * 0.5 - self.Width * 0.5,
								Screen.Height / 5.0 - self.Height * 0.5,
							}
						end

						errorBox:parentDidResize()

						retryBtn.onRelease = function()
							-- hide the error box
							errorBox:remove()
							-- call the first sub-step again
							checks.minAppVersion()
						end

						local targetPos = errorBox.pos:Copy()
						errorBox.pos.Y = errorBox.pos.Y - 50
						ease:outBack(errorBox, animationTime).pos = targetPos
					end

					checks.minAppVersion = function()
						System:DebugEvent("App performs initial checks")
						api:getMinAppVersion(function(error, minVersion)
							if error ~= nil then
								System:DebugEvent("Request to get min app version failed", { error = error })
								checks.error() -- Show error message with retry button
								return
							end

							local major, minor, patch = parseVersion(Client.AppVersion)
							local minMajor, minMinor, minPatch = parseVersion(minVersion)
							local appIsUpToDate = (major > minMajor)
								or (major == minMajor and minor > minMinor)
								or (major == minMajor and minor == minMinor and patch >= minPatch)

							if appIsUpToDate then
								-- call next sub-step
								checks.userAccountExists()
							else
								-- App is not up-to-date
								checks.error("Cubzh app needs to be updated!")
							end
						end)
					end

					-- Checks whether a user account exists locally.
					checks.userAccountExists = function()
						-- Update loading message
						text.Text = "Looking for user account..."
						loadingFrame:parentDidResize()

						if System.HasCredentials == false then
							-- Not user account is present locally
							-- Cleanup, just to be sure
							System.AskedForMagicKey = false
							-- Next sub-step: create new empty account
							checks.createAccount()
						else
							-- User account is present
							-- Next sub-step: check if a magic key has been asked
							checks.askedMagicKey()
						end
					end

					checks.createAccount = function()
						System:DebugEvent("App creates new empty user account")

						-- Update loading message
						text.Text = "Creating user account..."
						loadingFrame:parentDidResize()

						api:signUp(nil, nil, nil, function(err, credentials)
							if err ~= nil then
								checks.error("Account creation failed")
							else
								System:StoreCredentials(credentials["user-id"], credentials.token)
								System:DebugEvent("ACCOUNT_CREATED")
								-- Next sub-step: check if user account is complete
								checks.checkUserAccountComplete()
							end
						end)
					end

					-- Checks whether a magic key has been requested.
					checks.askedMagicKey = function()
						System:DebugEvent("App checks if magic key has been requested")

						text.Text = "Checking magic key..."
						loadingFrame:parentDidResize()

						-- Cleanup: remove `AskedForMagicKey` flag if it's still set while we have valid credentials
						if System.HasCredentials and System.Authenticated and System.AskedForMagicKey then
							System.AskedForMagicKey = false
						end

						if System.AskedForMagicKey then
							-- Magic key has been requested by user in a previous session
							System:DebugEvent("App shows magic key prompt")

							-- retrieve username or email that has been stored
							local usernameOrEmail = System.SavedUsernameOrEmail
							if type(usernameOrEmail) == "string" and usernameOrEmail ~= "" then
								-- show magic key prompt
								local step = createMagicKeyInputStep({ usernameOrEmail = usernameOrEmail })
								signupFlow:push(step)
							else
								checks.error("failed to resume login with magic key")
							end
						else
							-- No magic key has been asked
							-- Next sub-step: check if user account is complete
							checks.checkUserAccountComplete()
						end
					end

					checks.checkUserAccountComplete = function()
						text.Text = "Checking user info..."
						loadingFrame:parentDidResize()

						-- System.HasCredentials should always be true here because
						-- an empty user account is automatically created if none is found
						if System.HasCredentials == false then
							checks.error("No credentials found, this should not happen.")
							return
						end

						-- Request user account info
						api:getUserInfo(System.UserID, function(userInfo, err)
							if err ~= nil then
								System:DebugEvent(
									"Request to obtain user info with credentials failed",
									{ statusCode = err.statusCode, error = err.message }
								)

								-- if unauthorized, it means credentials aren't valid,
								-- removing them to start fresh with account creation or login
								if err.statusCode == 401 then
									System:RemoveCredentials()
									checks.minAppVersion() -- restart from beginning now without credentials
									return
								end

								checks.error() -- Show error message with retry button
								return
							end

							-- No error. Meaning credentials are valid.
							System.Authenticated = true -- [gaetan] not sure this field is useful...

							-- Update values in System
							System.Username = userInfo.username or ""
							System.HasEmail = userInfo.hasEmail or false
							System.HasDOB = userInfo.hasDOB
							System.IsUserUnder13 = userInfo.isUnder13
							-- System.HasPhoneNumber = userInfo.hasPhoneNumber or false

							if Client.LoggedIn then
								internalLoginSuccess()
							else
								-- show signup
								-- TODO: should we provide a config here? (hasBOB, didCustomizeAvatar, hasPhoneNumber)
								signupFlow:push(createSignUpOrLoginStep())
							end
						end, {
							"username",
							"hasEmail",
							"hasPassword",
							"hasDOB",
							"isUnder13",
							"didCustomizeAvatar",
							"hasPhoneNumber",
						})
					end

					-- Start with the first sub-step
					checks.minAppVersion()
				end
				loadingFrame:parentDidResize()
			end,
			onExit = function()
				loadingFrame:remove()
				loadingFrame = nil
			end,
			onRemove = function() end,
		})
		return step
	end

	signupFlow:push(createCheckAppVersionAndCredentialsStep())

	return signupFlow
end

return signup
