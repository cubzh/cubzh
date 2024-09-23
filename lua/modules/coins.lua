coins = {}

-- Creates modal content to present user coins.
-- (should be used to create or pushed within modal)
coins.createModalContent = function(_, config)
	local requests = {}
	local function cancelRequests()
		for _, r in ipairs(requests) do
			r:Cancel()
		end
		requests = {}
	end

	local theme = require("uitheme").current
	local modal = require("modal")
	local bundle = require("bundle")
	local api = require("api")

	-- default config
	local _config = {
		uikit = require("uikit"), -- allows to provide specific instance of uikit
	}

	if config then
		for k, v in pairs(_config) do
			if type(config[k]) == type(v) then
				_config[k] = config[k]
			end
		end
	end

	local ui = _config.uikit

	local content = modal:createContent()
	content.closeButton = true
	content.title = "Bank Account"
	content.icon = "🇵"

	local node = ui:createFrame()
	content.node = node

	local balanceFrame = ui:frameTextBackground()
	balanceFrame:setParent(node)
	local balanceText = ui:createText("Balance", { color = Color.White, size = "small" })
	balanceText:setParent(balanceFrame)

	local shape = bundle:Shape("shapes/pezh_coin_2")
	shape.Pivot = shape.Size * 0.5
	shape.Tick = function(o, dt)
		o.LocalRotation.Y = o.LocalRotation.Y + dt * 2
	end

	local coinShape = ui:createShape(shape, { spherized = true })
	coinShape:setParent(balanceFrame)

	local amountText = ui:createText("-", { color = Color(253, 222, 44), size = "big", font = Font.Pixel })
	amountText:setParent(balanceFrame)

	local grantedText = ui:createText(string.format("grants: -"), { color = Color(252, 167, 27), size = "small" })
	grantedText:setParent(balanceFrame)

	local purchasedText = ui:createText(string.format("purchased: -"), { color = Color(252, 167, 27), size = "small" })
	purchasedText:setParent(balanceFrame)

	local earnedText = ui:createText(string.format("earned: -"), { color = Color(252, 167, 27), size = "small" })
	earnedText:setParent(balanceFrame)

	local historyFrame = ui:frameTextBackground()
	historyFrame:setParent(node)
	local historyText = ui:createText("History", { color = Color.White, size = "small" })
	historyText:setParent(historyFrame)

	local loadedTransactions = {}
	local nbLoadedTransactions = 0

	local recycledCells = {}

	local function transactionCellParentDidResize(self)
		self.Width = self.parent.Width
		self.op.pos = {
			theme.padding,
			self.Height - self.op.Height - theme.padding,
		}
		self.description.pos = {
			theme.padding,
			self.op.pos.Y - self.description.Height - theme.padding,
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
		c.op.Text = string.format("%d", transaction.amount)
		c.description.Text = transaction.info.reason or ""
		c.Height = 50
		return c
	end

	-- [{"user_id":"4d558bc1-5700-4a0d-8c68-f05e0b97f3fd","transaction_id":"907180a0-7990-11ef-b23f-02420a0001a1","created_at":"2024-09-23T09:45:27.732Z","amount":5000000,"info":"{\"reason\":\"test\"}"},{"user_id":"4d558bc1-5700-4a0d-8c68-f05e0b97f3fd","transaction_id":"86cb412e-7990-11ef-b23f-02420a0001a1","created_at":"2024-09-23T09:45:11.543Z","amount":2000000,"info":"{\"reason\":\"test\"}"}]

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
	scroll:setParent(historyFrame)

	content.idealReducedContentSize = function(_, width, height)
		width = math.min(width, 500)
		height = math.min(height, 800)

		local coinSize = 100

		local balanceFrameHeight = balanceText.Height
			+ coinSize
			+ grantedText.Height
			+ purchasedText.Height
			+ earnedText.Height
			+ theme.padding * 4

		balanceFrame.Width = width
		balanceFrame.Height = balanceFrameHeight

		balanceText.pos = { theme.padding, balanceFrameHeight - theme.padding - balanceText.Height }

		coinShape.Width = coinSize
		coinShape.Height = coinSize
		local w = coinSize + theme.padding + amountText.Width
		coinShape.pos = {
			balanceFrame.Width * 0.5 - w * 0.5,
			balanceText.pos.Y - coinSize - theme.padding,
		}
		amountText.pos = {
			coinShape.pos.X + coinShape.Width + theme.padding,
			coinShape.pos.Y + coinShape.Height * 0.5 - amountText.Height * 0.5,
		}

		grantedText.pos = {
			theme.padding,
			coinShape.pos.Y - grantedText.Height - theme.padding,
		}

		purchasedText.pos = {
			theme.padding,
			grantedText.pos.Y - purchasedText.Height,
		}

		earnedText.pos = {
			theme.padding,
			purchasedText.pos.Y - earnedText.Height,
		}

		historyFrame.Width = width
		historyFrame.Height = height - balanceFrame.Height - theme.padding

		-- detailText.pos = { theme.padding, theme.padding }

		historyText.pos = { theme.padding, historyFrame.Height - theme.padding - historyText.Height }

		balanceFrame.pos = { 0, height - balanceFrame.Height }
		historyFrame.pos = { 0, balanceFrame.pos.Y - historyFrame.Height - theme.padding }

		scroll.Height = historyFrame.Height - historyText.Height - theme.padding * 2
		scroll.Width = historyFrame.Width - theme.padding * 2
		scroll.pos = { theme.padding, 0 }

		return Number2(width, height)
	end

	content.willResignActive = function()
		cancelRequests()
	end

	content.didBecomeActive = function()
		local req = api:getBalance(function(err, balance)
			if err then
				amountText.Text = "-"
				grantedText.Text = "grants: -"
				purchasedText.Text = "purchased: -"
				earnedText.Text = "earned: -"
				return
			end
			amountText.Text = string.format("%d", balance.totalCoins)
			grantedText.Text = string.format("grants: %d", balance.grantedCoins)
			purchasedText.Text = string.format("purchased: %d", balance.purchasedCoins)
			earnedText.Text = string.format("earned: %d", balance.earnedCoins)
		end)
		table.insert(requests, req)

		req = api:getTransactions({
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

return coins
