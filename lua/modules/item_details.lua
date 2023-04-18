--[[
	...
]]--

local itemDetails = {}

itemDetails.create = function(self, config)

	local _config = {
		mode = "explore" -- "explore" / "create"
	}
	if config ~= nil then
		if config.mode ~= nil and type(config.mode) == "string" then _config.mode = config.mode end
	end
	local config = _config

	local time = require("time")
	local theme = require("uitheme").current
	local itemCopyMarketModule = require("item_copy_market")

	local itemDetails = ui:createNode()

	local nameArea = ui:createFrame(Color(0,0,0))
	nameArea:setParent(itemDetails)
	itemDetails.nameArea = nameArea

	local name = ui:createText("name", Color.White)
	name:setParent(nameArea)
	itemDetails.name = name
	name.LocalPosition = {theme.padding, theme.padding, 0}

	local infoArea = ui:createFrame(Color(0,0,0))
	infoArea:setParent(itemDetails)
	itemDetails.infoArea = infoArea

	local publishDate = ui:createText("🌎 2 days ago (v1)", Color.White, "small")
	publishDate:setParent(infoArea)
	itemDetails.publishDate = publishDate
	publishDate.LocalPosition = {theme.padding, theme.padding, 0}

	local by = ui:createText("by", Color.White)
	by:setParent(infoArea)
	itemDetails.by = by
	by.LocalPosition = publishDate.LocalPosition + {0, publishDate.Height + theme.padding, 0}

	local author = ui:createText(" @repo", Color.Green)
	author:setParent(infoArea)
	itemDetails.author = author
	author.LocalPosition = by.LocalPosition + {by.Width, 0, 0}

	local descriptionArea = ui:createFrame(Color(0,0,0))
	descriptionArea:setParent(itemDetails)
	itemDetails.descriptionArea = descriptionArea

	local description = ui:createText("description", Color.White, "small")
	description:setParent(descriptionArea)
	itemDetails.description = description
	description.LocalPosition.X = theme.padding

	local shapeArea = ui:createFrame(Color(0,0,0))
	shapeArea:setParent(itemDetails)
	itemDetails.shapeArea = shapeArea

	-- local versionsBtn = ui:createButton("💾 Versions")
	-- versionsBtn:setParent(itemDetails)

	local copyNameBtn = ui:createButton("📑 Copy Name")
	copyNameBtn:setParent(itemDetails)
	copyNameBtn.onRelease = function()
		Dev:CopyToClipboard(copyNameBtn.itemFullName or "")
		local prevWidth = copyNameBtn.Width
		copyNameBtn.Text = "📑 Copied!"
		if copyNameBtn.Width < prevWidth then
			copyNameBtn.Width = prevWidth
		end
		Timer(1, function()
			copyNameBtn.Width = nil
			copyNameBtn.Text = "📑 Copy Name"
		end)
	end

	local signalBtn
	local likeBtn
	local likes
	local editDescriptionBtn

	if config.mode == "explore" then
		signalBtn = ui:createButton("⚠️")
		signalBtn:setParent(itemDetails)

		likeBtn = ui:createButton("❤️ ...")
		likeBtn:setParent(itemDetails)
	elseif config.mode == "create" then
		likes = ui:createText("❤️ ...", theme.textColor)
		likes:setParent(itemDetails)

		editDescriptionBtn = ui:createButton("✏️")
		editDescriptionBtn:setParent(descriptionArea)
		editDescriptionBtn.onRelease = function()
			if multilineInput and itemDetails.description then
				local description = itemDetails.description
				if description.empty == true then description = "" end
				-- multilineInput is globally exposed by the engine
				-- for the main menu script, not available within other worlds.
				-- Will be replaced by Lua multiline input once it's available!
				multilineInput(	description.Text,
								"Description",
								"How would you describe that Item?",
								"", -- regex
								10000, -- max chars
								function(text) -- done
									local description = itemDetails.description
									if text == "" then 
										description.empty = true
										description.Text = "Items are easier to find with a description!"
										description.Color = theme.textColorSecondary
										api:patchItem(itemDetails.id, {description = ""}, function(err, item)
											-- not handling response yet
										end)
									else
										description.empty = false
										description.Text = text
										description.Color = theme.textColor
										api:patchItem(itemDetails.id, {description = text}, function(err, item)
											-- not handling response yet
										end)
									end
								end,
								nil -- cancel
								)
			end
		end
	end

	itemDetails.shape = nil

	itemDetails.reloadInfo = function(self)
		if self.created then
			local n, unitType = time.ago(self.created)
			if n == 1 then
				unitType = unitType:sub(1,#unitType - 1)
			end
			self.publishDate.Text = "🌎 " .. n .. " " .. unitType .. " ago"
		end
	end

	itemDetails.reloadShape = function(self)
		if self.cell.itemFullName == nil then return end
		Object:Load(self.cell.itemFullName, function(obj)
			if obj == nil then return end
			if self.cell == nil then return end

			local w = 350
			local h = 350
			local x = 0
			local y = 0

			if self.shape then
				w = self.shape.Width
				h = self.shape.Height
				x = self.shape.LocalPosition.X
				y = self.shape.LocalPosition.Y

				self.shape:remove()
				self.shape = nil
			end

			self.shape = ui:createShape(obj, {spherized = true})
			self.shape.Width = w
			self.shape.Height = h
			self.shape.pivot.LocalRotation = {-0.1,0,-0.2}

			self.shape:setParent(self)
			self.shape.pos = {x, y, 0}
		end)
	end

	itemDetails.loadCell = function(self, cell)
		if self.shape then self.shape:remove() self.shape = nil end
		self.cell = cell

		self.id = cell.id
		self.author.Text = " @" .. cell.repo
		self.name.Text = cell.name

		if config.mode == "create" then
			if cell.description == nil or cell.description == "" then
				self.description.empty = true
				self.description.Text = "Items are easier to find with a description!"
				self.description.Color = theme.textColorSecondary
			else
				self.description.Text = cell.description
				self.description.Color = theme.textColor
			end
		else
			self.description.Text = cell.description or ""
			self.description.Color = theme.textColor
		end
		

		self.created = cell.created
		if self.created then
			local n, unitType = time.ago(self.created)
			if n == 1 then
				unitType = unitType:sub(1,#unitType - 1)
			end
			self.publishDate.Text = "🌎 " .. n .. " " .. unitType .. " ago"
		end

		copyNameBtn.itemFullName = cell.itemFullName

		local shapeAsyncLoad = false
		local shape
		if cell.item.shape then
			shape = Shape(cell.item.shape, {includeChildren = true})
		else
			shapeAsyncLoad = true
			shape = MutableShape()
			shape:AddBlock(Color(255,255,255,50),0,0,0)
		end

		self.shape = ui:createShape(shape, {spherized = true})
		self.shape.Width = 350
		self.shape.Height = 350

		self.shape.pivot.LocalRotation = {-0.1,0,-0.2}

		self.object.dt = 0
		self.object.Tick = function(o, dt)
			o.dt = o.dt + dt
			if self.shape ~= nil then
				self.shape.pivot.LocalRotation.Y = o.dt
			end
		end

		self.shape:setParent(self)

		self:refresh()

		if shapeAsyncLoad then
			self:reloadShape()
		end
	end

	itemDetails._w = 400
	itemDetails._h = 400

	itemDetails._refreshTimer = nil
	itemDetails._scheduleRefresh = function(self)
		if self._refreshTimer ~= nil then return end
		self._refreshTimer = Timer(0.01, function()
			self._refreshTimer = nil
			self:refresh()
		end)
	end

	itemDetails._width = function(self)
		return itemDetails._w
	end

	itemDetails._height = function(self)
		return itemDetails._h
	end

	itemDetails._setWidth = function(self, v)
		itemDetails._w = v
		self:_scheduleRefresh()
	end

	itemDetails._setHeight = function(self, v)
		itemDetails._h = v
		self:_scheduleRefresh()
	end

	itemDetails.refresh = function(self)

		if self.shape == nil then return end

		local portraitMode = self.Width < self.Height

		if portraitMode then
			-- min width to display details, buttons, etc.
			-- remaining height can be used for the preview
			local detailsMinHeight = 200 -- not including signal & like buttons
			local detailsHeightRatio = 0.50

			local availableWidth = self.Width - theme.padding * 2
			local availableHeight = self.Height - copyNameBtn.Height - theme.padding * 2
			if likeBtn ~= nil then
				availableHeight = availableHeight - likeBtn.Height - theme.padding
			end
			if likes ~= nil then
				availableHeight = availableHeight - likes.Height - theme.padding
			end

			local detailsHeight = availableHeight * detailsHeightRatio
			if detailsHeight < detailsMinHeight then
				detailsHeight = detailsMinHeight
			end

			local previewSize = math.min(availableHeight - detailsHeight, availableWidth)

			self.shape.Width = previewSize

			self.shape.LocalPosition.X = self.Width * 0.5 - self.shape.Width * 0.5
			self.shape.LocalPosition.Y = self.Height - self.shape.Height

			self.shapeArea.Width = self.shape.Width
			self.shapeArea.Height = self.shape.Height
			self.shapeArea.LocalPosition = self.shape.LocalPosition

			if likes then
				likes.LocalPosition.X = self.shape.LocalPosition.X + self.shape.Width - likes.Width
				likes.LocalPosition.Y = self.shape.LocalPosition.Y - likes.Height - theme.padding
			end

			if likeBtn then
				likeBtn.LocalPosition.X = self.shape.LocalPosition.X + self.shape.Width - likeBtn.Width
				likeBtn.LocalPosition.Y = self.shape.LocalPosition.Y - likeBtn.Height - theme.padding
			end

			if signalBtn then
				signalBtn.LocalPosition.X = self.shape.LocalPosition.X
				signalBtn.LocalPosition.Y = self.shape.LocalPosition.Y - signalBtn.Height - theme.padding
			end

			self.nameArea.Height = self.name.Height + theme.padding * 2
			self.nameArea.Width = self.Width

			if signalBtn then
				self.nameArea.LocalPosition = {0, signalBtn.LocalPosition.Y - self.nameArea.Height - theme.padding, 0}
			elseif likes then
				self.nameArea.LocalPosition = {0, likes.LocalPosition.Y - self.nameArea.Height - theme.padding, 0}
			end

			self.infoArea.Height = self.by.Height + self.publishDate.Height + theme.padding * 3
			self.infoArea.Width = self.nameArea.Width
			self.infoArea.LocalPosition = self.nameArea.LocalPosition - {0, self.infoArea.Height + theme.padding, 0}

			self.descriptionArea.Height = detailsHeight - self.nameArea.Height - self.infoArea.Height - theme.padding * 2
			self.descriptionArea.Width = self.nameArea.Width
			self.descriptionArea.LocalPosition = self.infoArea.LocalPosition - {0, self.descriptionArea.Height + theme.padding, 0}

			if editDescriptionBtn ~= nil then 
				editDescriptionBtn.pos = {self.descriptionArea.Width - editDescriptionBtn.Width - theme.padding,
										self.descriptionArea.Height - editDescriptionBtn.Height - theme.padding,0}

				self.description.object.MaxWidth = self.descriptionArea.Width - editDescriptionBtn.Width - theme.padding * 3

			else
				self.description.object.MaxWidth = self.descriptionArea.Width - theme.padding * 2
			end

			self.description.LocalPosition.Y = self.descriptionArea.Height - self.description.Height - theme.padding

			copyNameBtn.LocalPosition.Y = self.descriptionArea.LocalPosition.Y - copyNameBtn.Height - theme.padding

		else
			-- min width to display details, buttons, etc.
			-- remaining width can be used for the preview
			local detailsMinWidth = 200
			local detailsWidthRatio = 0.66

			local availableHeight = self.Height
			local availableHeightForPreview = availableHeight - copyNameBtn.Height - theme.padding * 2
			if likeBtn then
				availableHeightForPreview = availableHeightForPreview - likeBtn.Height
			elseif likes then
				availableHeightForPreview = availableHeightForPreview - likes.Height
			end

			local detailsWidth = (self.Width - theme.padding) * detailsWidthRatio

			if detailsWidth < detailsMinWidth then 
				detailsMinWidth = detailsMinWidth
			end

			local previewSize = self.Width - theme.padding - detailsWidth
			local previewHeight = previewWidth
			if previewSize > availableHeightForPreview then
				previewSize = availableHeightForPreview
				detailsWidth = self.Width - theme.padding - previewSize
			end

			self.shape.Width = previewSize

			self.shape.LocalPosition.X = self.Width - self.shape.Width
			self.shape.LocalPosition.Y = self.Height - self.shape.Height

			self.shapeArea.Width = self.shape.Width
			self.shapeArea.Height = self.shape.Height
			self.shapeArea.LocalPosition = self.shape.LocalPosition

			if likeBtn then
				likeBtn.LocalPosition.X = self.shape.LocalPosition.X + self.shape.Width - likeBtn.Width
				likeBtn.LocalPosition.Y = self.shape.LocalPosition.Y - likeBtn.Height - theme.padding
				copyNameBtn.LocalPosition.Y = likeBtn.LocalPosition.Y - copyNameBtn.Height - theme.padding
			end

			if likes then
				likes.LocalPosition.X = self.shape.LocalPosition.X + self.shape.Width - likes.Width
				likes.LocalPosition.Y = self.shape.LocalPosition.Y - likes.Height - theme.padding
				copyNameBtn.LocalPosition.Y = likes.LocalPosition.Y - copyNameBtn.Height - theme.padding
			end

			if signalBtn then
				signalBtn.LocalPosition.X = self.shape.LocalPosition.X
				signalBtn.LocalPosition.Y = self.shape.LocalPosition.Y - signalBtn.Height - theme.padding
			end

			self.nameArea.Height = self.name.Height + theme.padding * 2
			self.nameArea.Width = detailsWidth
			self.nameArea.LocalPosition = {0, self.Height - self.nameArea.Height, 0}

			self.infoArea.Height = self.by.Height + self.publishDate.Height + theme.padding * 3
			self.infoArea.Width = detailsWidth
			self.infoArea.LocalPosition = self.nameArea.LocalPosition - {0, self.infoArea.Height + theme.padding, 0}

			self.descriptionArea.Height = availableHeight - self.nameArea.Height - self.infoArea.Height - theme.padding * 2
			self.descriptionArea.Width = detailsWidth
			
			self.descriptionArea.LocalPosition = self.infoArea.LocalPosition - {0, self.descriptionArea.Height + theme.padding, 0}

			if editDescriptionBtn ~= nil then 
				editDescriptionBtn.pos = {self.descriptionArea.Width - editDescriptionBtn.Width - theme.padding,
										self.descriptionArea.Height - editDescriptionBtn.Height - theme.padding,0}

				self.description.object.MaxWidth = self.descriptionArea.Width - editDescriptionBtn.Width - theme.padding * 3

			else
				self.description.object.MaxWidth = self.descriptionArea.Width - theme.padding * 2
			end

			self.description.LocalPosition.Y = self.descriptionArea.Height - self.description.Height - theme.padding
		end

		copyNameBtn.LocalPosition.X = self.Width - copyNameBtn.Width
		-- versionsBtn.LocalPosition.X = copyNameBtn.LocalPosition.X - versionsBtn.Width - theme.padding
	end

	return itemDetails
end

return itemDetails
