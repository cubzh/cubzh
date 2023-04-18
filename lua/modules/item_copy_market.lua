--[[
	...
]]--

local itemCopyMarket = {}

itemCopyMarket.create = function(self)

	local ui = require("uikit")
	local time = require("time")
	local theme = require("uitheme").current

	local itemCopyMarket = ui:createFrame()

	local primaryMarketArea = ui:createFrame()
	primaryMarketArea:setParent(itemCopyMarket)
	itemCopyMarket.primaryMarketArea = primaryMarketArea

	local primaryName = ui:createText("Buy New", Color.White)
	primaryName:setParent(primaryMarketArea)

	local secondaryMarketArea = ui:createFrame()
	secondaryMarketArea:setParent(itemCopyMarket)
	itemCopyMarket.secondaryMarketArea = secondaryMarketArea

	local secondaryName = ui:createText("Secondary Market", Color.White)
	secondaryName:setParent(secondaryMarketArea)

	local function createListingBlock(parent)
		local background = ui:createFrame(Color.Black)
		background:setParent(parent)

		local shape = MutableShape()
		shape:AddBlock(Color.Blue,0,0,0)
		
		local sItem = ui:createShape(shape)
		sItem:setParent(background)
		background.sItem = sItem
		local tName = ui:createText("", Color.White, "small")
		tName:setParent(background)
		local tTokenId = ui:createText("", Color.White, "small")
		tTokenId:setParent(background)
		local tByLabel = ui:createText("Created by", Color.White, "small")
		tByLabel:setParent(background)
		local tByName = ui:createText("", Color(127,127,255), "small")
		tByName:setParent(background)
		local buyBtn = ui:createButton("")
		buyBtn:setParent(background)
		buyBtn:setColor(theme.colorPositive, theme.textColor)
		background.buyBtn = buyBtn
		buyBtn.onRelease = function()
			print("Buy")
		end

		background.fillData = function(self, name, tokenId, byLabel, byName, price)
			self.sItem:remove()
			self.sItem = nil
			if self.templateShape then
				local shape = Shape(self.templateShape)
				self.sItem = ui:createShape(shape, { spherized = true })
				shape.LocalRotation = Number3(math.pi / 8, - math.pi / 4, 0)
				self.sItem:setParent(self)
				self:parentDidResize()		
			else
				Object:Load(itemCopyMarket.copyInfo.repo.."."..itemCopyMarket.copyInfo.name, function(shape)
					if not self.parentDidResize then return end
					self.templateShape = shape
					self.sItem = ui:createShape(shape, { spherized = true })
					shape.LocalRotation = Number3(math.pi / 8, - math.pi / 4, 0)
					self.sItem:setParent(self)
					self:parentDidResize()		
				end)
			end
			tName.Text = name
			tTokenId.Text = tokenId
			tByLabel.Text = byLabel.." by"
			tByName.Text = "@"..byName
			buyBtn.Text = price.." 💰"
			self.empty = false
		end

		background.parentDidResize = function(self)
			self.Width = self.parent.Width
			self.Height = buyBtn.Height + theme.padding * 2
			
			local sItem = self.sItem
			if not sItem then
				return
			end
			sItem.Height = self.Height - theme.padding
			sItem.Width = sItem.Height
			sItem.pos = Number3(theme.padding, theme.padding / 2, 0)

			if #tName.Text > 0 then
				tName.pos = sItem.pos + Number3(sItem.Width + theme.padding, self.Height / 2, 0)
				tTokenId.pos = sItem.pos + Number3(sItem.Width + theme.padding, self.Height / 2 - theme.padding * 0.66 - tTokenId.Height, 0)
			else
				tTokenId.pos = sItem.pos + Number3(sItem.Width + theme.padding / 2, self.Height / 2 - tTokenId.Height * 0.66, 0)
			end

			tByLabel.pos = Number3(self.Width / 2 + theme.padding / 2, self.Height / 2, 0)
			tByName.pos = Number3(self.Width / 2 + theme.padding / 2, self.Height / 2 - theme.padding / 2 - tByName.Height, 0)

			buyBtn.pos = { self.Width - theme.padding / 2 - buyBtn.Width, self.Height / 2 - buyBtn.Height / 2, 0 }
		end
		background:parentDidResize()
		return background
	end

	local primaryMarketListing = createListingBlock(primaryMarketArea)
	local secondaryMarketListings = {}

	local nbPages = 1

	itemCopyMarket.setPage = function(self,page)
		if not itemCopyMarket.listings then return end
		for k,block in ipairs(secondaryMarketListings) do
			block.empty = true
			block:hide()
			local data = itemCopyMarket.listings[(k - 1) + (page - 1) * self.nbResultsPerPage + 1]
			if data then
				block:fillData("","✨#"..data.copyId, "Owned", data.owner.name, data.listingPrice)
				block:show()
			end
		end

    	if self.onPaginationChange ~= nil then
    		self.onPaginationChange(page, nbPages)
    	end
	end

	itemCopyMarket.setItem = function(self, repo, name, itemId)
		if self.templateShape then
			self.templateShape = nil
		end
		self.copyInfo = { repo = repo, name = name, itemId=itemId }
		itemCopyMarket.listings = {}
		api.getItem(itemId, function(err, data)
			if err then
				print(err)
				return
			end
			if data.maxSupply == 0 then
				print("Error: This item is not for sale yet.")
			end
			primaryMarketListing:fillData(name, data.currentSupply.."/"..data.maxSupply, "Created", repo, data.listingPrice)
			api.getCopies(itemId, { listed = true }, function(err, listings)
				if err then
					self:refresh()
					print(err)
					return
				end
				itemCopyMarket.listings = listings
				self:refresh()
			end)
		end)
	end

	itemCopyMarket.refresh = function(self)
		if not self.copyInfo then return end
		primaryMarketArea.Width = self.Width
		primaryMarketArea.Height = primaryName.Height + theme.padding * 3 + primaryMarketListing.Height
		primaryMarketArea.LocalPosition = { 0, self.Height - primaryMarketArea.Height, 0 }
		primaryName.LocalPosition = { self.Width / 2 - primaryName.Width / 2, primaryMarketArea.Height - primaryName.Height, 0 }

		primaryMarketListing.LocalPosition = Number3(0, primaryName.LocalPosition.Y - theme.padding - primaryMarketListing.Height, 0)

		secondaryMarketArea.Width = self.Width
		secondaryMarketArea.Height = self.Height - primaryMarketArea.Height
		secondaryName.LocalPosition = { self.Width / 2 - secondaryName.Width / 2, secondaryMarketArea.Height - secondaryName.Height, 0 }

		for k,v in ipairs(secondaryMarketListings) do
			v:remove()
		end
		
		secondaryMarketListings = {}
		local tmpBlock = createListingBlock(secondaryMarketArea)
		local spaceLeft = secondaryMarketArea.Height - (secondaryName.Height + theme.padding * 2)
		local blockHeight = tmpBlock.Height
		local nbResultsPerPage = math.min(#itemCopyMarket.listings, math.floor(spaceLeft / blockHeight))
		self.nbResultsPerPage = nbResultsPerPage
		tmpBlock:remove()

		for i=1,nbResultsPerPage do
			local block = createListingBlock(secondaryMarketArea)
			table.insert(secondaryMarketListings, block)
			block:hide()
			block.empty = true
		end

		nbPages = math.floor((#itemCopyMarket.listings - 1) / nbResultsPerPage) + 1
		itemCopyMarket:setPage(1)

		local widthBuyBtn = 0
		for k,block in ipairs(secondaryMarketListings) do
			if not block.empty then
				block.LocalPosition = Number3(0, secondaryName.LocalPosition.Y - theme.padding - block.Height - (k-1) * (theme.padding / 2 + block.Height), 0)
				if block.buyBtn.Width > widthBuyBtn then
					widthBuyBtn = block.buyBtn.Width
				end
				block:show()
			else
				block:hide()
			end
		end
		for k,block in ipairs(secondaryMarketListings) do
			if not block.empty then
				block.buyBtn.Width = widthBuyBtn
				block:parentDidResize()
			end
		end
	end

	itemCopyMarket.parentDidResize = function(self)
		self:refresh()
	end

	itemCopyMarket:parentDidResize()
	return itemCopyMarket
end

return itemCopyMarket
