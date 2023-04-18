--[[
	...
]]--

local worldDetails = {}

worldDetails.create = function(self, config)

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

	local worldDetails = ui:createNode()

	local nameArea = ui:createFrame(Color(0,0,0))
	nameArea:setParent(worldDetails)
	worldDetails.nameArea = nameArea

	local name
	local editNameBtn
	if config.mode == "create" then
		name = ui:createTextInput("", "World Name?")
		name:setParent(nameArea)
		name.pos = {0,0,0}

		editNameBtn = ui:createButton("✏️")
		editNameBtn:setParent(nameArea)
		worldDetails.editNameBtn = editNameBtn

		local function focus()
			name:focus()
		end

		local function submit()
			local sanitized, err = api.checkWorldName(name.Text)
			if err == nil then
				api:patchWorld(worldDetails.id, {title = sanitized}, function(err, world)
					-- not handling response yet
				end)
			end

			editNameBtn.Text = "✏️"
			editNameBtn.onRelease = focus
		end

		editNameBtn.onRelease = focus

		name.onFocus = function(self)
			editNameBtn.Text = "✅"
			editNameBtn.onRelease = submit
		end

		name.onTextChange = function(self)
			local sanitized, err = api.checkWorldName(self.Text)
			if err ~= nil then
				editNameBtn:disable()
			else
				editNameBtn:enable()
			end
		end
	else
		name = ui:createText("name", Color.White)
		name:setParent(nameArea)
		name.pos = {theme.padding, theme.padding, 0}
	end

	worldDetails.name = name

	local infoArea = ui:createFrame(Color(0,0,0))
	infoArea:setParent(worldDetails)
	worldDetails.infoArea = infoArea

	local publishDate = ui:createText("🌎 . ... ago (v1)", Color.White, "small")
	publishDate:setParent(infoArea)
	worldDetails.publishDate = publishDate
	publishDate.LocalPosition = {theme.padding, theme.padding, 0}

	local by = ui:createText("by", Color.White)
	by:setParent(infoArea)
	worldDetails.by = by
	by.LocalPosition = publishDate.LocalPosition + {0, publishDate.Height + theme.padding, 0}

	local author = ui:createText(" @repo", Color.Green)
	author:setParent(infoArea)
	worldDetails.author = author
	author.LocalPosition = by.LocalPosition + {by.Width, 0, 0}

	local descriptionArea = ui:createFrame(Color(0,0,0))
	descriptionArea:setParent(worldDetails)
	worldDetails.descriptionArea = descriptionArea

	local description = ui:createText("description", Color.White, "small")
	description:setParent(descriptionArea)
	worldDetails.description = description
	description.LocalPosition.X = theme.padding

	local shapeArea = ui:createFrame(Color(0,0,0))
	shapeArea:setParent(worldDetails)
	worldDetails.shapeArea = shapeArea

	local signalBtn
	local likeBtn
	local likes
	local editDescriptionBtn

	if config.mode == "explore" then
		signalBtn = ui:createButton("⚠️")
		signalBtn:setParent(worldDetails)

		likeBtn = ui:createButton("❤️ ...")
		likeBtn:setParent(worldDetails)
	elseif config.mode == "create" then
		likes = ui:createText("❤️ ...", theme.textColor)
		likes:setParent(worldDetails)

		editDescriptionBtn = ui:createButton("✏️")
		editDescriptionBtn:setParent(descriptionArea)
		editDescriptionBtn.onRelease = function()
			if multilineInput and worldDetails.description then
				local description = worldDetails.description
				if description.empty == true then description = "" end
				-- multilineInput is globally exposed by the engine
				-- for the main menu script, not available within other worlds.
				-- Will be replaced by Lua multiline input once it's available!
				multilineInput(	description.Text,
								"Description",
								"How would you describe that World?",
								"", -- regex
								10000, -- max chars
								function(text) -- done
									local description = worldDetails.description
									if text == "" then 
										description.empty = true
										description.Text = "Worlds are easier to find with a description!"
										description.Color = theme.textColorSecondary
										api:patchWorld(worldDetails.id, {description = ""}, function(err, world)
											-- not handling response yet
										end)
									else
										description.empty = false
										description.Text = text
										description.Color = theme.textColor
										api:patchWorld(worldDetails.id, {description = text}, function(err, world)
											-- not handling response yet
										end)
									end
								end,
								nil -- cancel
								)
			end
		end
	end

	worldDetails.shape = nil

	worldDetails.loadCell = function(self, cell)
		if self.shape then self.shape:remove() end
		self.cell = cell

		self.id = cell.id

		local shape = Shape(cell.item.shape, {includeChildren = true})
		self.shape = ui:createShape(shape, {spherized = true})

		self.shape.Width = 350
		self.shape.Height = 350

		self.author.Text = " @..." -- .. cell.repo

		require("api"):getWorld(cell.id, function(err, world)
			if err == nil and world ~= nil then
				if self.author ~= nil then
					self.author.Text = " @" .. (world["author-name"] or "...")
				end
			end
		end)

		self.name.Text = cell.title

		if config.mode == "create" then
			if cell.description == nil or cell.description == "" then
				self.description.empty = true
				self.description.Text = "Worlds are easier to find with a description!"
				self.description.Color = theme.textColorSecondary
			else
				self.description.Text = cell.description
				self.description.Color = theme.textColor
			end
		else
			self.description.Text = cell.description or ""
			self.description.Color = theme.textColor
		end

		if likes then 
			likes.Text = "❤️ " .. (cell.likes and math.floor(cell.likes) or 0)
		elseif likeBtn then
			likeBtn.Text = "❤️ " .. (cell.likes and math.floor(cell.likes) or 0)
		end

		if cell.created then
			local n, unitType = time.ago(cell.created)
			if n == 1 then
				unitType = unitType:sub(1,#unitType - 1)
			end
			self.publishDate.Text = "🌎 " .. n .. " " .. unitType .. " ago"
		end

		self.shape.pivot.Rotation = Number3(-0.1,-math.pi * 0.2,-0.2)

		self.object.dt = 0
		self.object.Tick = function(o, dt)
			o.dt = o.dt + dt
			if self.shape ~= nil then
				self.shape.pivot.LocalRotation.Y = o.dt
			end
		end

		self.shape:setParent(self)

		self:refresh()
	end

	worldDetails._w = 400
	worldDetails._h = 400

	worldDetails._refreshTimer = nil
	worldDetails._scheduleRefresh = function(self)
		if self._refreshTimer ~= nil then return end
		self._refreshTimer = Timer(0.01, function()
			self._refreshTimer = nil
			self:refresh()
		end)
	end

	worldDetails._width = function(self)
		return worldDetails._w
	end

	worldDetails._height = function(self)
		return worldDetails._h
	end

	worldDetails._setWidth = function(self, v)
		worldDetails._w = v
		self:_scheduleRefresh()
	end

	worldDetails._setHeight = function(self, v)
		worldDetails._h = v
		self:_scheduleRefresh()
	end

	worldDetails.refresh = function(self)

		if self.shape == nil then return end

		local portraitMode = self.Width < self.Height

		if portraitMode then
			-- min width to display details, buttons, etc.
			-- remaining height can be used for the preview
			local detailsMinHeight = 200 -- not including signal & like buttons
			local detailsHeightRatio = 0.50

			local availableWidth = self.Width - theme.padding * 2
			local availableHeight = self.Height - theme.padding
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
			self.shapeArea.pos = self.shape.pos

			if likes then
				likes.pos.X = self.shape.pos.X + self.shape.Width - likes.Width
				likes.pos.Y = self.shape.pos.Y - likes.Height - theme.padding
			end

			if likeBtn then
				likeBtn.pos.X = self.shape.pos.X + self.shape.Width - likeBtn.Width
				likeBtn.pos.Y = self.shape.pos.Y - likeBtn.Height - theme.padding
			end

			if signalBtn then
				signalBtn.pos.X = self.shape.pos.X
				signalBtn.pos.Y = self.shape.pos.Y - signalBtn.Height - theme.padding
			end

			self.nameArea.Width = self.Width
			if config.mode == "create" then
				self.nameArea.Height = self.name.Height

				self.editNameBtn.Width = self.name.Height
				self.editNameBtn.Height = self.name.Height

				self.name.Width = self.nameArea.Width - self.editNameBtn.Width
				self.editNameBtn.pos.X = self.nameArea.Width - self.editNameBtn.Width
			else
				self.nameArea.Height = self.name.Height + theme.padding * 2
			end
			
			if signalBtn then
				self.nameArea.pos = {0, signalBtn.LocalPosition.Y - self.nameArea.Height - theme.padding, 0}
			elseif likes then
				self.nameArea.pos = {0, likes.LocalPosition.Y - self.nameArea.Height - theme.padding, 0}
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
		else
			-- min width to display details, buttons, etc.
			-- remaining width can be used for the preview
			local detailsMinWidth = 200
			local detailsWidthRatio = 0.66

			local availableHeight = self.Height
			local availableHeightForPreview = availableHeight - theme.padding

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
			end

			if likes then
				likes.LocalPosition.X = self.shape.LocalPosition.X + self.shape.Width - likes.Width
				likes.LocalPosition.Y = self.shape.LocalPosition.Y - likes.Height - theme.padding
			end

			if signalBtn then
				signalBtn.LocalPosition.X = self.shape.LocalPosition.X
				signalBtn.LocalPosition.Y = self.shape.LocalPosition.Y - signalBtn.Height - theme.padding
			end

			self.nameArea.Width = detailsWidth
			if config.mode == "create" then
				self.nameArea.Height = self.name.Height

				self.editNameBtn.Width = self.name.Height
				self.editNameBtn.Height = self.name.Height

				self.name.Width = self.nameArea.Width - self.editNameBtn.Width
				self.editNameBtn.pos.X = self.nameArea.Width - self.editNameBtn.Width
			else
				self.nameArea.Height = self.name.Height + theme.padding * 2
			end
			
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
	end

	return worldDetails
end

return worldDetails
