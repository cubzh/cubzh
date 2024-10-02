mod = {}

mod.createBadge = function(_, config)
	local theme = require("uitheme").current
	local defaultConfig = {
		count = 42,
		ui = require("uikit"),
	}

	ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config)
	end)
	if not ok then
		error("notifications:createBadge(config) - config error: " .. err, 2)
	end

	local ui = config.ui

	local badge = ui:frameNotificationBadge()
	local badgeLabel = ui:createText("", { font = Font.Noto, size = "small", color = Color.White })
	badgeLabel:setParent(badge)
	badge.parentDidResize = function(self)
		local parent = self.parent
		if parent == nil then
			return
		end
		self.Width = badgeLabel.Width + theme.paddingTiny * 2
		self.Height = badgeLabel.Height
		badgeLabel.pos = {
			theme.paddingTiny,
			1,
		}
		badge.pos.X = -self.Width * 0.5
		badge.pos.Y = parent.Height * 0.8 - badge.Height * 0.5
		badge.LocalPosition.Z = -900
	end

	badge.setCount = function(self, count)
		config.count = count
		badgeLabel.Text = "" .. count
		if count == 0 then
			self:hide()
		else
			self:show()
			self:parentDidResize()
		end
	end

	badge:setCount(config.count)

	return badge
end

mod.createModalContent = function(_, config)
	local requests = {}
	local function cancelRequests()
		for _, r in ipairs(requests) do
			r:Cancel()
		end
		requests = {}
	end

	local theme = require("uitheme").current
	local modal = require("modal")
	local conf = require("config")
	local api = require("api") -- NOTE: use system api?

	-- default config
	local defaultConfig = {
		uikit = require("uikit"), -- allows to provide specific instance of uikit
	}

	config = conf:merge(defaultConfig, config)

	local ui = config.uikit

	local content = modal:createContent()
	content.closeButton = true
	content.title = "Notifications"
	content.icon = "❗"

	local node = ui:createFrame()
	content.node = node

	local frame = ui:frameTextBackground()
	frame:setParent(node)

	local loadedTransactions = {}
	local nbLoadedTransactions = 0
	local recycledCells = {}

	local function transactionCellParentDidResize(self)
		self.Width = self.parent.Width
		self.description.object.MaxWidth = self.parent.Width - self.op.Width - theme.paddingBig * 3
		-- self.Height = math.max(self.description.Height, self.op.Height) + theme.padding * 2

		self.op.pos = {
			theme.paddingBig,
			self.Height * 0.5 - self.op.Height * 0.5,
		}
		self.description.pos = {
			self.Width - self.description.Width - theme.paddingBig,
			self.Height * 0.5 - self.description.Height * 0.5,
		}
	end

	local function getTransactionCell(transaction)
		local c = table.remove(recycledCells)
		if c == nil then
			c = ui:frameScrollCell()
			c.op = ui:createText("", { color = Color.White, size = "small" })
			c.op:setParent(c)
			c.description = ui:createText("", { color = Color(150, 150, 150), size = "small" })
			c.description:setParent(c)
			c.parentDidResize = transactionCellParentDidResize
		end
		if transaction.amount > 0 then
			c.op.Color = theme.colorPositive
			c.op.Text = string.format("🇵 ⬅️ %d", transaction.amount)
		else
			c.op.Color = theme.colorNegative
			c.op.Text = string.format("🇵 ➡️ %d", -transaction.amount)
		end
		c.description.Text = transaction.info.reason or ""
		c.Height = 50
		return c
	end

	local function recycleTransactionCell(cell)
		cell:setParent(nil)
		table.insert(recycledCells, cell)
	end

	local scroll = ui:scroll({
		padding = {
			top = theme.padding,
			bottom = theme.padding,
			left = 0,
			right = 0,
		},
		cellPadding = theme.padding,
		loadCell = function(index)
			if index <= nbLoadedTransactions then
				local c = getTransactionCell(loadedTransactions[index])
				return c
			end
		end,
		unloadCell = function(_, cell)
			recycleTransactionCell(cell)
		end,
	})
	scroll:setParent(frame)

	local okBtn

	local functions = {}

	functions.layout = function(width, height)
		width = width or frame.parent.Width
		height = height or frame.parent.Height

		frame.Width = width
		local frameHeight = height

		if okBtn ~= nil then
			okBtn.Width = width - theme.padding * 2
			frameHeight = frameHeight - okBtn.Height - theme.padding - theme.paddingTiny
			okBtn.pos.X = width * 0.5 - okBtn.Width * 0.5
			okBtn.pos.Y = theme.paddingTiny
		end

		frame.Height = frameHeight

		frame.pos = { 0, height - frameHeight, 0 }

		scroll.Height = frame.Height
		scroll.Width = frame.Width - theme.padding * 2
		scroll.pos = { theme.padding, 0 }
	end

	functions.createOpenSettingsBtn = function()
		local padding = theme.padding
		local buttonContent = ui:frame()
		local line1 = ui:createText("⚙️ Open Settings", { font = Font.Pixel, size = "default" })
		line1:setParent(buttonContent)
		local line2 = ui:createText("➡️ Turn ON Notifications", { font = Font.Pixel, size = "default" })
		line2:setParent(buttonContent)
		buttonContent.parentDidResize = function(self)
			line1.object.MaxWidth = self.parent.Width - padding * 2
			line2.object.MaxWidth = self.parent.Width - padding * 2
			self.Width = math.max(line1.Width, line2.Width)
			self.Height = line1.Height + padding + line2.Height
			line2.pos = {
				self.Width * 0.5 - line2.Width * 0.5,
				0,
			}
			line1.pos = {
				self.Width * 0.5 - line1.Width * 0.5,
				line2.pos.Y + line2.Height + padding,
			}
		end

		local btn = ui:buttonNeutral({
			content = buttonContent,
			padding = 10,
		})

		btn.onRelease = function()
			System:DebugEvent("User presses OPEN SETTINGS button", { context = "notifications menu" })
			System:OpenAppSettings()
		end

		return btn
	end

	functions.createTurnOnPushNotificationsBtn = function()
		local padding = theme.padding
		local buttonContent = ui:frame()
		local line1 = ui:createText("Turn ON Push Notifications", { font = Font.Pixel, size = "default" })
		line1:setParent(buttonContent)
		local line2 = ui:createText("+100 🇵 reward!", { font = Font.Pixel, size = "default" })
		line2:setParent(buttonContent)
		buttonContent.parentDidResize = function(self)
			line1.object.MaxWidth = self.parent.Width - padding * 2
			line2.object.MaxWidth = self.parent.Width - padding * 2
			self.Width = math.max(line1.Width, line2.Width)
			self.Height = line1.Height + padding + line2.Height
			line2.pos = {
				self.Width * 0.5 - line2.Width * 0.5,
				0,
			}
			line1.pos = {
				self.Width * 0.5 - line1.Width * 0.5,
				line2.pos.Y + line2.Height + padding,
			}
		end

		local btn = ui:buttonPositive({
			content = buttonContent,
			padding = 10,
		})

		btn.onRelease = function()
			System:DebugEvent("User presses TURN ON notifications button", { context = "notifications menu" })
			System:NotificationRequestAuthorization(function(response)
				System:DebugEvent(
					"App receives notification authorization response",
					{ response = response, context = "notifications menu" }
				)
				functions.refreshNotificationBtn()
			end)
		end

		return btn
	end

	local previousNotificationStatus
	functions.refreshNotificationBtn = function()
		System:NotificationGetStatus(function(status)
			-- DEBUG:
			-- local statuses = { "underdetermined", "postponed", "denied", "authorized" }
			-- notificationStatus = statuses[math.random(1, #statuses)]

			if status == previousNotificationStatus then
				return
			end

			previousNotificationStatus = status
			if okBtn then
				okBtn:remove()
				okBtn = nil
			end

			if status == "underdetermined" or status == "postponed" then
				okBtn = functions.createTurnOnPushNotificationsBtn()
				okBtn:setParent(node)
			elseif status == "denied" then
				okBtn = functions.createOpenSettingsBtn()
				okBtn:setParent(node)
			end

			functions.layout()
		end)
	end
	functions.refreshNotificationBtn()

	content.idealReducedContentSize = function(_, width, height)
		width = math.min(width, 500)
		functions.layout(width, height)
		return Number2(width, height)
	end

	local appDidBecomeActiveListener
	content.willResignActive = function()
		if appDidBecomeActiveListener then
			appDidBecomeActiveListener:Remove()
			appDidBecomeActiveListener = nil
		end
		cancelRequests()
	end

	content.didBecomeActive = function()
		if appDidBecomeActiveListener == nil then
			appDidBecomeActiveListener = LocalEvent:Listen(LocalEvent.Name.AppDidBecomeActive, function()
				functions.refreshNotificationBtn()
			end)
		end

		req = api:getTransactions({ -- TODO: notifications
			callback = function(transactions, err)
				if err then
					print("ERROR:", err)
					return
				end
				loadedTransactions = transactions
				nbLoadedTransactions = #loadedTransactions
				scroll:flush()
				scroll:refresh()
			end,
		})
		table.insert(requests, req)
	end

	return content
end

return mod
