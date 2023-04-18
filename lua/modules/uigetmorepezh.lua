local uigetmorepezh = {}

uigetmorepezh.create = function(self)
    local theme = require("uitheme").current
	local ui = require("uikit")

    local pezh = ui:createFrame()
    pezh.parentDidResize = function()
        pezh.Width = pezh.parent.Width
        pezh.Height = pezh.parent.Height
    end

    local earnFrame = ui:createFrame(theme.gridCellColor)
	earnFrame:setParent(pezh)
	local earnText = ui:createText("Earn Pezh", Color.White)
	earnText:setParent(earnFrame)
	local comingSoonText = ui:createText("Coming soon...", Color.White)
	comingSoonText:setParent(earnFrame)

    local buyFrame = ui:createFrame(theme.gridCellColor)
	buyFrame:setParent(pezh)
	local buyText = ui:createText("Buy Pezh", Color.White)
	buyText:setParent(buyFrame)

    local buyOptions = {
        {
            text = "Watch an ad",
            amountStr = "+5 💰",
            priceStr = "▶️ Free",
            onRelease = function()
                print("Pub!")
            end
        },
        {
            text = "Buy a pack",
            amountStr = "+100 💰",
            priceStr = "$1.99",
            onRelease = function()
                print("WIP")
            end
        },
        {
            text = "Buy a pack",
            amountStr = "+1000 💰",
            priceStr = "$15.99",
            onRelease = function()
                print("WIP")
            end
        }
    }
    local buyOptionsFrames = {} 
    for k,buyOption in ipairs(buyOptions) do
        local f = ui:createFrame()
        f:setParent(buyFrame)
        local t = ui:createText(buyOption.text, Color.White, "small")
        t:setParent(f)
        local amount = ui:createText(buyOption.amountStr, Color.White)
        amount:setParent(f)
        local price = ui:createButton(buyOption.priceStr)
        price.onRelease = buyOption.onRelease
        price:setParent(f)
        f.parentDidResize = function(self)
            local p = self.parent
            f.Width = p.Width / #buyOptions
            f.Height = t.Height + amount.Height + price.Height + theme.padding * 2
            price.pos = { f.Width / 2 - price.Width / 2, theme.padding, 0 }
            amount.pos = { f.Width / 2 - amount.Width / 2, price.pos.Y + amount.Height + theme.padding * 4, 0 }
            t.pos = { f.Width / 2 - t.Width / 2, amount.pos.Y + t.Height + theme.padding * 4, 0 }
            local posX = (k - 1) * f.Width
            f.pos = { posX, (p.Height - buyText.Height - theme.padding) / 2 - f.Height / 2, 0 }
        end
        table.insert(buyOptionsFrames, f)
    end

    pezh.parentDidResize = function(self)
        local width = self.parent.Width - theme.padding * 2
        earnFrame.Width = width
        earnFrame.Height = comingSoonText.Height * 4
        earnText.pos = { theme.padding, earnFrame.Height - theme.padding - earnText.Height, 0 }
        comingSoonText.pos = { earnFrame.Width / 2 - comingSoonText.Width / 2, earnFrame.Height / 2 - comingSoonText.Height / 2, 0 }

        buyFrame.pos = { 0, earnFrame.Height + theme.padding, 0 }
        buyFrame.Width = width
        buyFrame.Height = (buyOptionsFrames[1].Height + theme.padding + buyText.Height) * 2
        buyText.pos = { theme.padding, buyFrame.Height - theme.padding - buyText.Height, 0 }        

        self.Width = width
        self.Height = earnFrame.Height + theme.padding + buyFrame.Height
    end

    return pezh
end

return uigetmorepezh