local signin = {}

signin.createModal = function(self)
		
	local ui = require("uikit")
	local modal = require("modal")
	local theme = require("uitheme").current
	local ease = require("ease")

	local function idealReducedContentSize(content, width, height)
		if content.refresh then content:refresh() end
		-- print("-- 1 -", content.Width,content.Height)
		-- Timer(1.0, function() content:refresh() print("-- 2 -", content.Width,content.Height) end)
		return Number2(content.Width,content.Height)
	end

	-- initial content, asking for year of birth
	local content = modal:createContent()
	content.idealReducedContentSize = idealReducedContentSize

	local node = ui:createFrame(Color(0,0,0,0))
	content.node = node

	content.title = "Who are you?"
	content.icon = "🙂"

	local usernameLabel = ui:createText("Username or e-mail", Color(200,200,200,255), "small")
	usernameLabel:setParent(node)

	local usernameInfo = ui:createText("", Color(251,206,0,255), "small")
	usernameInfo:setParent(node)

	local usernameInput = ui:createTextInput("", "username or email")
	usernameInput:setParent(node)

	local signUpButton = ui:createButton("Sign In", { textSize = "big" })
	signUpButton:setColor(theme.colorPositive)
	signUpButton.contentDidResize = function()
		signUpButton.Width = nil
		signUpButton.Width = signUpButton.Width * 1.5
		content:refreshModal()
	end
	signUpButton:contentDidResize()

	content.bottomCenter = {signUpButton}

	-- local tickListener
	-- content.didBecomeActive = function()
	-- 	tickListener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
	-- 		if usernameInfoDT then
	-- 			usernameInfoDT = usernameInfoDT + dt
	-- 			usernameInfoDT = usernameInfoDT % 0.4
				
	-- 			local currentFrame = math.floor(usernameInfoDT / 0.1)

	-- 			if currentFrame ~= usernameInfoFrame then
	-- 				usernameInfoFrame = currentFrame
	-- 				if usernameInfoFrame == 0 then usernameInfo.Text = "checking   "
	-- 				elseif usernameInfoFrame == 1 then usernameInfo.Text = "checking.  "
	-- 				elseif usernameInfoFrame == 2 then usernameInfo.Text = "checking.. "
	-- 				else usernameInfo.Text = "checking..."
	-- 				end
	-- 			end
	-- 		end
	-- 	end)
	-- end

	local maxWidth = function()
		return Screen.Width - theme.modalMargin * 2
	end

	local maxHeight = function()
		return Screen.Height - 100
	end

	local position = function(modal, forceBounce)

		local p = Number3(Screen.Width * 0.5 - modal.Width * 0.5, Screen.Height * 0.5 - modal.Height * 0.5, 0)

		if not modal.updatedPosition or forceBounce then
			modal.LocalPosition = p - {0,100,0}
			modal.updatedPosition = true
			ease:outElastic(modal, 0.3).LocalPosition = p
		else
			modal.LocalPosition = p
		end

	end

	local popup = modal:create(content, maxWidth, maxHeight, position)

	popup.onDone = function(y,m,d) 
	end

	popup.bounce = function(self)
		position(popup, true)
	end

	node.refresh = function(self)

		self.Width = math.min(400, Screen.Width - Screen.SafeArea.Right - Screen.SafeArea.Left - theme.paddingBig * 2)
		self.Height = usernameLabel.Height + theme.paddingTiny
					+ usernameInput.Height + theme.padding

		-- birthdayLabel.pos.Y = self.Height - birthdayLabel.Height

		usernameLabel.pos.Y = self.Height - usernameLabel.Height

		usernameInfo.pos.Y = usernameLabel.pos.Y
		usernameInfo.pos.X = self.Width - usernameInfo.Width

		usernameInput.Width = self.Width
		usernameInput.pos.Y = usernameLabel.pos.Y - theme.paddingTiny - usernameInput.Height
	end

	return popup
end

return signin
