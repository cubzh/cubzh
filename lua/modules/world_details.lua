worldDetailsMod = {}

worldDetailsMod.create = function(_, config)
	local _config = {
		title = "",
		mode = "explore", -- "explore" / "create"
		uikit = require("uikit"),
	}

	if config then
		for k, v in pairs(_config) do
			if type(config[k]) == type(v) then
				_config[k] = config[k]
			end
		end
	end

	config = _config

	local time = require("time")
	local theme = require("uitheme").current
	local ui = config.uikit
	local api = require("system_api", System)

	local createMode = config.mode == "create"

	local worldDetails = ui:createNode()

	-- becomes true when itemDetails is removed
	-- callbacks may capture this as upvalue to early return.
	local removed = false
	local requests = {}
	local listeners = {}

	worldDetails.onRemove = function(_)
		removed = true

		for _, req in ipairs(requests) do
			req:Cancel()
		end
		requests = {}

		for _, listener in ipairs(listeners) do
			listener:Remove()
		end
		listeners = {}
	end

	local content = require("modal"):createContent()
	content.title = config.title
	content.icon = "🌎"
	content.node = worldDetails

	content.didBecomeActive = function()
		for _, listener in ipairs(listeners) do
			listener:Resume()
		end
	end

	content.willResignActive = function()
		for _, listener in ipairs(listeners) do
			listener:Pause()
		end
	end

	local name
	local editNameBtn
	if createMode then
		local nameArea = ui:createFrame(Color(0, 0, 0))
		nameArea:setParent(worldDetails)
		worldDetails.nameArea = nameArea

		name = ui:createTextInput("", "World Name?")
		name:setParent(nameArea)
		name.pos = { 0, 0, 0 }

		editNameBtn = ui:createButton("✏️")
		editNameBtn:setParent(nameArea)
		worldDetails.editNameBtn = editNameBtn

		local function focus()
			name:focus()
		end

		local function submit()
			local sanitized, err = api.checkWorldName(name.Text)
			if err == nil then
				local req = api:patchWorld(worldDetails.id, { title = sanitized }, function(err, world)
					if removed then
						return
					end
					-- print("PATCHED", err, world.id, world.title, world.description)
					if err == nil then
						-- World update succeeded.
						-- Notify that the content has changed.
						if content.onContentUpdate then
							content.onContentUpdate(world)
						end
					end
				end)
				table.insert(requests, req)
			end

			editNameBtn.Text = "✏️"
			editNameBtn.onRelease = focus
		end

		editNameBtn.onRelease = focus

		name.onFocus = function(_)
			editNameBtn.Text = "✅"
			editNameBtn.onRelease = submit
		end

		name.onTextChange = function(self)
			local _, err = api.checkWorldName(self.Text)
			if err ~= nil then
				editNameBtn:disable()
			else
				editNameBtn:enable()
			end
		end
		worldDetails.name = name
	end

	local infoArea = ui:createFrame(Color(0, 0, 0))
	infoArea:setParent(worldDetails)
	worldDetails.infoArea = infoArea

	local publishDate = ui:createText("🌎 . ... ago (v1)", Color.White, "small")
	publishDate:setParent(infoArea)
	worldDetails.publishDate = publishDate
	publishDate.LocalPosition = { theme.padding, theme.padding, 0 }

	local byBtn = nil

	if createMode then
		local by = ui:createText("by", Color.White)
		by:setParent(infoArea)
		worldDetails.by = by
		by.LocalPosition = publishDate.LocalPosition + { 0, publishDate.Height + theme.padding, 0 }

		local author = ui:createText(" @repo", Color.Green)
		author:setParent(infoArea)
		worldDetails.author = author
		author.LocalPosition = by.LocalPosition + { by.Width, 0, 0 }
	else
		byBtn = ui:createButton("by @…")
		byBtn:setParent(infoArea)
		byBtn.pos = publishDate.LocalPosition + { 0, publishDate.Height + theme.padding, 0 }
	end

	local descriptionArea = ui:createFrame(Color(0, 0, 0))
	descriptionArea.IsMask = true
	descriptionArea:setParent(worldDetails)
	worldDetails.descriptionArea = descriptionArea

	local description = ui:createText("description", Color.White, "small")
	description:setParent(descriptionArea)
	worldDetails.description = description
	worldDetails.description.LocalPosition.X = theme.padding

	local shapeArea = ui:createFrame(Color(0, 0, 0))
	shapeArea:setParent(worldDetails)
	worldDetails.shapeArea = shapeArea

	local signalBtn
	local likeBtn
	local likes
	local editDescriptionBtn

	local views = ui:createText("👁 …")
	views.Color = theme.textColor
	views:setParent(worldDetails)

	if config.mode == "explore" then
		signalBtn = ui:createButton("⚠️")
		signalBtn:disable()
		signalBtn:setParent(worldDetails)

		likeBtn = ui:createButton("❤️ …")
		likeBtn:setParent(worldDetails)
	elseif config.mode == "create" then
		likes = ui:createText("❤️ …", theme.textColor)
		likes:setParent(worldDetails)

		editDescriptionBtn = ui:createButton("✏️")
		editDescriptionBtn:setParent(descriptionArea)
		editDescriptionBtn.onRelease = function()
			if System.MultilineInput ~= nil and worldDetails.description then
				local description = worldDetails.description
				if description.empty == true then
					description = ""
				end
				System.MultilineInput(
					description.Text,
					"Description",
					"How would you describe that World?",
					"", -- regex
					10000, -- max chars
					function(text) -- done
						ui:turnOn()
						local description = worldDetails.description
						if text == "" then
							description.empty = true
							description.Text = "Worlds are easier to find with a description!"
							description.Color = theme.textColorSecondary
							description.pos.Y = descriptionArea.Height - description.Height - theme.padding
							local req = api:patchWorld(worldDetails.id, { description = "" }, function(_, _)
								if removed then
									return
								end
								-- not handling response yet
							end)
							table.insert(requests, req)
						else
							description.empty = false
							description.Text = text
							description.Color = theme.textColor
							description.pos.Y = descriptionArea.Height - description.Height - theme.padding
							local req = api:patchWorld(worldDetails.id, { description = text }, function(_, _)
								if removed then
									return
								end
								-- not handling response yet
							end)
							table.insert(requests, req)
						end
					end,
					function() -- cancel
						ui:turnOn()
					end
				)
				ui:turnOff()
			end
		end
	end

	worldDetails.shape = nil

	content.loadCell = function(_, cell)
		worldDetails:loadCell(cell)
	end

	worldDetails.loadCell = function(self, cell)
		if self.shape then
			self.shape:remove()
		end
		self.cell = cell

		if cell.entry then
			cell.entry.onThumbnailUpdate = function(img)
				if img == nil then
					return
				end
				if self.shape ~= nil then
					self.shape:remove()
					self.shape = nil
				end
				if self.shapeArea and self.shapeArea.setImage then
					self.shapeArea:setImage(img)
				end
			end
		end

		self.id = cell.id

		if cell.thumbnail ~= nil then
			self.shapeArea:setImage(cell.thumbnail)
		elseif cell.item.shape ~= nil then
			local shape = Shape(cell.item.shape, { includeChildren = true })
			self.shape = ui:createShape(shape, { spherized = true })

			self.shape.Width = 350
			self.shape.Height = 350
		end

		local req = api:getWorld(cell.id, { "authorName", "authorId", "description", "liked" }, function(err, world)
			if removed then
				return
			end

			local authorName = world.authorName
			local authorId = world.authorId

			if err == nil and world ~= nil then
				-- update author text/button
				if self.author ~= nil then
					self.author.Text = " @" .. (authorName or "…")
				elseif byBtn and authorName then
					byBtn.Text = "by @" .. authorName
					byBtn.onRelease = function(_)
						local profileConfig = { isLocal = false, username = authorName, userID = authorId, uikit = ui }
						local profileContent = require("profile"):create(profileConfig)
						content:push(profileContent)
					end
				end
				-- update description text
				if self.description ~= nil then
					self.description.Text = world.description or ""
					-- refresh view
					self:_scheduleRefresh()
				end
			end

			local liked = world.liked
			self.liked = liked
			self.originalLike = liked
			if self.liked and likeBtn and likeBtn.setColor then
				likeBtn:setColor(theme.colorPositive)
			end
		end)
		table.insert(requests, req)

		if self.name then
			self.name.Text = cell.title
		end

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

			likeBtn.onRelease = function()
				self.liked = not self.liked
				local req = api:likeWorld(cell.id, self.liked, function(_)
					if removed then
						return
					end
				end)
				table.insert(requests, req)

				if self.liked then
					likeBtn:setColor(theme.colorPositive)
				else
					likeBtn:setColor(theme.buttonColor)
				end

				local nbLikes = (cell.likes and math.floor(cell.likes) or 0)
				if self.liked ~= self.originalLike then
					if self.liked then
						nbLikes = nbLikes + 1
					else
						nbLikes = nbLikes - 1
					end
				end
				if nbLikes < 0 then
					nbLikes = 0
				end
				likeBtn.Text = "❤️ " .. nbLikes

				-- update positions
				local portraitMode = self.Width < self.Height
				if portraitMode then
					likeBtn.pos.X = self.Width - likeBtn.Width - theme.padding
					views.pos.X = self.Width - views.Width - likeBtn.Width - theme.padding * 2.0
				else
					likeBtn.pos.X = self.shapeArea.pos.X + self.shapeArea.Width - likeBtn.Width
					views.pos.X = self.shapeArea.pos.X
						+ self.shapeArea.Width
						- likeBtn.Width
						- views.Width
						- theme.padding
				end
			end
		end
		views.Text = "👁 " .. (cell.views and math.floor(cell.views) or 0)

		if cell.created then
			local n, unitType = time.ago(cell.created)
			if n == 1 then
				unitType = unitType:sub(1, #unitType - 1)
			end
			self.publishDate.Text = "🌎 " .. n .. " " .. unitType .. " ago"
		end

		local t = 0
		local listener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
			t = t + dt
			if self.shape ~= nil then
				self.shape.pivot.LocalRotation.Y = t
			end
		end)
		table.insert(listeners, listener)

		if self.shape ~= nil then
			self.shape.pivot.Rotation = Number3(-0.1, -math.pi * 0.2, -0.2)
			self.shape:setParent(self)
		end

		self:refresh()
	end

	worldDetails._w = 400
	worldDetails._h = 400

	worldDetails._refreshTimer = nil
	worldDetails._scheduleRefresh = function(self)
		if self._refreshTimer ~= nil then
			return
		end
		self._refreshTimer = Timer(0.01, function()
			if self == nil or self.refresh == nil then
				return
			end
			self._refreshTimer = nil
			self:refresh()
		end)
	end

	worldDetails._width = function(_)
		return worldDetails._w
	end

	worldDetails._height = function(_)
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
		if self.shape == nil and self.cell.thumbnail == nil then
			return
		end

		if self.cell.thumbnail ~= nil then
			if self.shape ~= nil then
				self.shape:remove()
				self.shape = nil
			end

			self.shapeArea:setImage(self.cell.thumbnail)
		end

		local portraitMode = self.Width < self.Height
		local createMode = config.mode == "create"

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

			self.shapeArea.Width = previewSize
			self.shapeArea.Height = previewSize

			self.shapeArea.LocalPosition.X = self.Width * 0.5 - self.shapeArea.Width * 0.5
			self.shapeArea.LocalPosition.Y = self.Height - self.shapeArea.Height

			if self.shape ~= nil then
				self.shape.Width = self.shapeArea.Width
				self.shape.Height = self.shapeArea.Height
				self.shape.pos = self.shapeArea.pos
			end

			if likes then
				likes.pos.X = self.Width - likes.Width - theme.padding
				likes.pos.Y = self.shapeArea.pos.Y - likes.Height - theme.padding
				views.pos.X = self.Width - views.Width - likes.Width - theme.padding * 2.0
				views.pos.Y = likes.pos.Y + likes.Height * 0.5 - views.Height * 0.5
			end

			if likeBtn then
				likeBtn.pos.X = self.Width - likeBtn.Width - theme.padding
				likeBtn.pos.Y = self.shapeArea.pos.Y - likeBtn.Height - theme.padding
				views.pos.X = self.Width - views.Width - likeBtn.Width - theme.padding * 2.0
				views.pos.Y = likeBtn.pos.Y + likeBtn.Height * 0.5 - views.Height * 0.5
			end

			if signalBtn then
				signalBtn.pos.X = theme.padding
				signalBtn.pos.Y = self.shapeArea.pos.Y - signalBtn.Height - theme.padding
			end

			if createMode then
				self.nameArea.Width = self.Width
				self.nameArea.Height = self.name.Height

				self.editNameBtn.Width = self.name.Height
				self.editNameBtn.Height = self.name.Height

				self.name.Width = self.nameArea.Width - self.editNameBtn.Width
				self.editNameBtn.pos.X = self.nameArea.Width - self.editNameBtn.Width

				if signalBtn then
					self.nameArea.pos = { 0, signalBtn.LocalPosition.Y - self.nameArea.Height - theme.padding, 0 }
				elseif likes then
					self.nameArea.pos = { 0, likes.LocalPosition.Y - self.nameArea.Height - theme.padding, 0 }
				end

				self.infoArea.Height = self.by.Height + self.publishDate.Height + theme.padding * 3
				self.infoArea.Width = self.Width

				self.infoArea.pos = self.nameArea.pos - { 0, self.infoArea.Height + theme.padding, 0 }
				self.descriptionArea.Height = detailsHeight
					- self.nameArea.Height
					- self.infoArea.Height
					- theme.padding * 2
			else
				self.infoArea.Height = byBtn.Height + self.publishDate.Height + theme.padding * 3
				self.infoArea.Width = self.Width

				self.infoArea.pos = { 0, signalBtn.pos.Y - self.infoArea.Height - theme.padding, 0 }
				self.descriptionArea.Height = detailsHeight - self.infoArea.Height - theme.padding * 2
			end

			self.descriptionArea.Width = self.Width
			self.descriptionArea.LocalPosition = self.infoArea.LocalPosition
				- { 0, self.descriptionArea.Height + theme.padding, 0 }

			if editDescriptionBtn ~= nil then
				editDescriptionBtn.pos = {
					self.descriptionArea.Width - editDescriptionBtn.Width - theme.padding,
					self.descriptionArea.Height - editDescriptionBtn.Height - theme.padding,
					0,
				}

				self.description.object.MaxWidth = self.descriptionArea.Width
					- editDescriptionBtn.Width
					- theme.padding * 3
			else
				self.description.object.MaxWidth = self.descriptionArea.Width - theme.padding * 2
			end

			self.description.LocalPosition.Y = self.descriptionArea.Height - self.description.Height - theme.padding
		else -- landscape
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
				detailsWidth = detailsMinWidth
			end

			local infoWidth = 0.0
			if likes ~= nil then
				infoWidth = views.Width + likes.Width + theme.padding * 3.0
			elseif likeBtn ~= nil then
				infoWidth = signalBtn.Width + views.Width + likeBtn.Width + theme.padding * 4.0
			end

			if detailsWidth + theme.padding + infoWidth > self.Width then
				detailsWidth = self.Width - theme.padding - infoWidth
			end

			local previewSize = self.Width - theme.padding - detailsWidth
			if previewSize > availableHeightForPreview then
				previewSize = availableHeightForPreview
				detailsWidth = self.Width - theme.padding - previewSize
			end

			self.shapeArea.Width = previewSize
			self.shapeArea.Height = previewSize

			self.shapeArea.LocalPosition.X = self.Width - self.shapeArea.Width
			self.shapeArea.LocalPosition.Y = self.Height - self.shapeArea.Height

			if self.shape ~= nil then
				self.shape.Width = self.shapeArea.Width
				self.shape.Height = self.shapeArea.Height
				self.shape.LocalPosition = self.shapeArea.LocalPosition
			end

			if likeBtn then
				likeBtn.LocalPosition.X = self.shapeArea.LocalPosition.X + self.shapeArea.Width - likeBtn.Width
				likeBtn.LocalPosition.Y = self.shapeArea.LocalPosition.Y - likeBtn.Height - theme.padding
				views.LocalPosition.X = self.shapeArea.LocalPosition.X
					+ self.shapeArea.Width
					- likeBtn.Width
					- views.Width
					- theme.padding
				views.LocalPosition.Y = likeBtn.LocalPosition.Y + likeBtn.Height * 0.5 - views.Height * 0.5
			end

			if likes then
				likes.LocalPosition.X = self.shapeArea.LocalPosition.X + self.shapeArea.Width - likes.Width
				likes.LocalPosition.Y = self.shapeArea.LocalPosition.Y - likes.Height - theme.padding
				views.LocalPosition.X = self.shapeArea.LocalPosition.X
					+ self.shapeArea.Width
					- likes.Width
					- views.Width
					- theme.padding
				views.LocalPosition.Y = likes.LocalPosition.Y + likes.Height * 0.5 - views.Height * 0.5
			end

			if signalBtn then
				signalBtn.LocalPosition.X = self.shapeArea.LocalPosition.X
				signalBtn.LocalPosition.Y = self.shapeArea.LocalPosition.Y - signalBtn.Height - theme.padding
			end

			if createMode then
				self.nameArea.Width = detailsWidth
				self.nameArea.Height = self.name.Height

				self.editNameBtn.Width = self.name.Height
				self.editNameBtn.Height = self.name.Height

				self.name.Width = self.nameArea.Width - self.editNameBtn.Width
				self.editNameBtn.pos.X = self.nameArea.Width - self.editNameBtn.Width

				self.nameArea.LocalPosition = { 0, self.Height - self.nameArea.Height, 0 }

				self.infoArea.Height = self.by.Height + self.publishDate.Height + theme.padding * 3
			else
				self.infoArea.Height = byBtn.Height + self.publishDate.Height + theme.padding * 3
			end
			self.infoArea.Width = detailsWidth

			if createMode then
				self.infoArea.LocalPosition = self.nameArea.LocalPosition
					- { 0, self.infoArea.Height + theme.padding, 0 }
				self.descriptionArea.Height = availableHeight
					- self.nameArea.Height
					- self.infoArea.Height
					- theme.padding * 2
			else
				self.infoArea.LocalPosition = { 0, self.Height - self.infoArea.Height, 0 }
				self.descriptionArea.Height = availableHeight - self.infoArea.Height - theme.padding * 2
			end

			self.descriptionArea.Width = detailsWidth
			self.descriptionArea.LocalPosition = self.infoArea.LocalPosition
				- { 0, self.descriptionArea.Height + theme.padding, 0 }

			if editDescriptionBtn ~= nil then
				editDescriptionBtn.pos = {
					self.descriptionArea.Width - editDescriptionBtn.Width - theme.padding,
					self.descriptionArea.Height - editDescriptionBtn.Height - theme.padding,
					0,
				}

				self.description.object.MaxWidth = self.descriptionArea.Width
					- editDescriptionBtn.Width
					- theme.padding * 3
			else
				self.description.object.MaxWidth = self.descriptionArea.Width - theme.padding * 2
			end

			self.description.LocalPosition.Y = self.descriptionArea.Height - self.description.Height - theme.padding
		end
	end

	return content
end

return worldDetailsMod
