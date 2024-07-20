coins = {}

-- Creates modal content to present user coins.
-- (should be used to create or pushed within modal)
coins.createModalContent = function(_, config)
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
	content.icon = "💰"

	local node = ui:createFrame()
	content.node = node

	local balanceFrame = ui:createFrame(theme.gridCellColor)
	balanceFrame:setParent(node)
	local balanceText = ui:createText("Balance", Color.White)
	balanceText:setParent(balanceFrame)

	local shape = bundle:Shape("shapes/pezh_coin_2")
	shape.Pivot = shape.Size * 0.5
	shape.Tick = function(o, dt)
		o.LocalRotation.Y = o.LocalRotation.Y + dt * 2
	end

	local coinShape = ui:createShape(shape, { spherized = true })
	coinShape:setParent(balanceFrame)

	local amountText = ui:createText("0", Color.White, "big")
	amountText:setParent(balanceFrame)

	local historyFrame = ui:createFrame(theme.gridCellColor)
	historyFrame:setParent(node)
	local historyText = ui:createText("History", Color.White)
	historyText:setParent(historyFrame)

	local entries = {}

	local historyShowMoreBtn = ui:createButton("Show more >", { textSize = "small" })
	historyShowMoreBtn:setParent(historyFrame)
	historyShowMoreBtn:disable()

	content.idealReducedContentSize = function(_, width, _)
		width = math.min(width, 500)

		local balanceFrameHeight = balanceText.Height * 5
		balanceFrame.Width = width
		balanceFrame.Height = balanceFrameHeight

		coinShape.Width = balanceFrameHeight * 0.7
		coinShape.Height = balanceFrameHeight * 0.7
		coinShape.pos = { balanceFrame.Width / 2 - coinShape.Width, balanceFrame.Height / 2 - coinShape.Height / 2, 0 }
		amountText.pos = coinShape.pos
			+ { coinShape.Width + theme.padding * 2, coinShape.Height / 2 - amountText.Height / 2, 0 }

		balanceText.pos = { theme.padding, balanceFrameHeight - theme.padding - balanceText.Height, 0 }

		historyFrame.Width = width
		local historyFrameHeight = 100
		if entries[1] then
			historyFrameHeight = historyText.Height
				+ entries[1].Height * 5
				+ historyShowMoreBtn.Height
				+ theme.padding * 3
		end
		historyFrame.Height = historyFrameHeight
		historyText.pos = { theme.padding, historyFrameHeight - theme.padding - historyText.Height, 0 }

		for k, entry in ipairs(entries) do
			entry.pos = Number3(
				theme.padding,
				historyText.pos.Y - historyText.Height - theme.padding - (k - 1) * entry.Height,
				0
			)
		end
		historyShowMoreBtn.pos.X = width - historyShowMoreBtn.Width

		historyFrame.pos = { 0, theme.padding, 0 }
		balanceFrame.pos = { 0, historyFrame.pos.Y + historyFrame.Height + theme.padding, 0 }

		return Number2(width, balanceFrame.pos.Y + balanceFrame.Height)
	end

	api.getBalance(function(err, balance)
		if not amountText.Text then
			return
		end
		if err then
			amountText.Text = "0"
			return
		end
		amountText.Text = "" .. math.floor(balance.total)
	end)

	return content
end

return coins
