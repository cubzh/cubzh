--[[
Pezh Model to check balance and latest transactions
]]--

local pezhModal = {}

pezhModal.create = function(self, maxWidth, maxHeight, position)
	local parent = ui.rootFrame
	local theme = require("uitheme").current
	local modal = require("modal")
	local ui = require("uikit")
	local api = require("api")
	local time = require("time")
	local uigetmorepezh = require("uigetmorepezh")

	local maxEntries = 5

	local content = modal:createContent()
	content.closeButton = true
	content.title = "Pezh"
	content.icon = "💰"

	local _modal = modal:create(content, maxWidth, maxHeight, position)

	local pezh = ui:createFrame()
	pezh.parentDidResize = function()
		pezh.Width = pezh.parent.Width
		pezh.Height = pezh.parent.Height
	end
	content.node = pezh

	local balanceFrame = ui:createFrame(theme.gridCellColor)
	balanceFrame:setParent(pezh)
	local balanceText = ui:createText("Balance", Color.White)
	balanceText:setParent(balanceFrame)

	local shape = Shape(Items.aduermael.coin)
	shape.Tick = function(o, dt)
		o.LocalRotation.Y = o.LocalRotation.Y + dt * 2
	end
	local coinShape = ui:createShape(shape, { spherized = true })
	coinShape:setParent(balanceFrame)
	local amountText = ui:createText("0", Color.White, "big")
	amountText:setParent(balanceFrame)

	local historyFrame = ui:createFrame(theme.gridCellColor)
	historyFrame:setParent(pezh)
	local historyText = ui:createText("History", Color.White)
	historyText:setParent(historyFrame)

	local function transform_string(str)
		local new_str = string.gsub(str, "_%a", string.upper)
		new_str = string.gsub(new_str, "_", " ")
		new_str = string.gsub(new_str, "^%l", string.upper)
		return new_str
	end

	local entries = {}

	local historyShowMoreBtn = ui:createButton("Show more >", { textSize = "small" })
	historyShowMoreBtn:setParent(historyFrame)
	historyShowMoreBtn:disable()

	-- local getMorePezhBtn = ui:createButton("💰 Get More Pezh")
	-- getMorePezhBtn:setParent(pezh)
	-- getMorePezhBtn:setColor(theme.colorPositive, theme.textColor)

	-- getMorePezhBtn.onRelease = function()
	-- 	local content = modal:createContent()
	-- 	content.closeButton = true
	-- 	content.title = "Get More Pezh"
	-- 	content.icon = "💰"
	-- 	content.node = uigetmorepezh:create()
	-- 	content.idealReducedContentSize = function(s, width, height)
	-- 		return Number2(content.node.Width, content.node.Height)
	-- 	end
	-- 	_modal:push(content)
	-- end

	content.idealReducedContentSize = function(content, width, height)
		local balanceFrameHeight = balanceText.Height * 5
		balanceFrame.Width = width
		balanceFrame.Height = balanceFrameHeight

		coinShape.Width = balanceFrameHeight * 0.7
		coinShape.Height = balanceFrameHeight * 0.7
		coinShape.pos = { balanceFrame.Width / 2 - coinShape.Width, balanceFrame.Height / 2 - coinShape.Height / 2, 0 }
		amountText.pos = coinShape.pos + { coinShape.Width + theme.padding * 2, coinShape.Height / 2 - amountText.Height / 2, 0 }

		balanceText.pos = { theme.padding, balanceFrameHeight - theme.padding - balanceText.Height, 0 }

		historyFrame.Width = width
		local historyFrameHeight = 100
		if entries[1] then
			historyFrameHeight = historyText.Height + entries[1].Height * 5 + historyShowMoreBtn.Height + theme.padding * 3
		end
		historyFrame.Height = historyFrameHeight
		historyText.pos = { theme.padding, historyFrameHeight - theme.padding - historyText.Height, 0 }

		for k,entry in ipairs(entries) do
			entry.pos = Number3(theme.padding, historyText.pos.Y - historyText.Height - theme.padding - (k-1) * entry.Height, 0)
		end	
		historyShowMoreBtn.pos.X = width - historyShowMoreBtn.Width

		-- getMorePezhBtn.pos = { width / 2 - getMorePezhBtn.Width / 2, 0, 0 }
		-- historyFrame.pos = { 0, getMorePezhBtn.pos.Y + getMorePezhBtn.Height + theme.padding, 0 }
		historyFrame.pos = { 0, theme.padding, 0 }
		balanceFrame.pos = { 0, historyFrame.pos.Y + historyFrame.Height + theme.padding, 0 }

		return Number2(width, balanceFrame.pos.Y + balanceFrame.Height)
	end

	api.getBalance(function(err, balance)
		if err then
			amountText.Text = "0"
			return
		end
		amountText.Text = "" .. math.floor(balance.total)
	end)

	api.getTransactions(function(err,list)
		if err then print(err) return end

		for k,t in ipairs(list) do
			if k > maxEntries then break end
			local date = time.iso8601_to_os_time(t.date)
			local n,unitType = time.ago(date)
			if n == 1 then
				unitType = unitType:sub(1,#unitType - 1)
			end
			local dateAgo = n .. " " .. unitType .. " ago"
	
			local amount = t.amount
			local action = t.action
			local itemName = transform_string(t.item.slug)
			local positive = false
			if action == "buy" then
				if t.to.name == Player.Username then
					action = "Sold"
					positive = true
				else
					action = "Purchased"
				end
			else
				action = "Mint"
			end

			local frame = ui:createFrame()
			frame:setParent(historyFrame)

			local tDateAgo = ui:createText(dateAgo, Color.Grey, "small")
			frame.tDateAgo = tDateAgo
			tDateAgo:setParent(frame)
			local tAction = ui:createText(action.." "..itemName, Color.White, "small")
			frame.tAction = tAction
			tAction:setParent(frame)
			local amountText = ui:createText((positive and "+" or "-")..amount.." 💰", positive and Color.Green or Color.Red, "small")
			amountText:setParent(frame)
			frame.parentDidResize = function()
				frame.Width = frame.parent.Width
				frame.Height = tAction.Height + theme.padding
				tDateAgo.pos = Number3(2,2,0)
				local maxWidthDate = 0
				for _,e in ipairs(entries) do
					if e.tDateAgo.Width > maxWidthDate then
						maxWidthDate = e.tDateAgo.Width
					end
				end
				tAction.pos = tDateAgo.pos + { maxWidthDate + theme.padding * 2, 0, 0 }
				--TODO: might want to crop text if wider than width
				amountText.pos = { frame.Width - theme.padding - amountText.Width, tDateAgo.pos.Y, 0 }
			end
			frame:parentDidResize()
			table.insert(entries, frame)
		end
	end)

	return _modal
end

return pezhModal
