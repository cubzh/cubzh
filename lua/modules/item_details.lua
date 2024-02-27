itemDetails = {}

itemDetails.createModalContent = function(_, config)
	local api = require("system_api", System)
	local time = require("time")
	local theme = require("uitheme").current

	local defaultConfig = {
		title = "Item",
		mode = "explore", -- "explore" / "create"
		uikit = require("uikit"),
	}

	config = require("config"):merge(defaultConfig, config)

	local ui = config.uikit

	local itemDetails = ui:createNode()

	local createMode = config.mode == "create"
	local authorID

	-- becomes true when itemDetails is removed
	-- callbacks may capture this as upvalue to early return.
	local requests = {}
	local refreshTimer
	local listeners = {}

	local cancelRequestsTimersAndListeners = function()
		for _, req in ipairs(requests) do
			req:Cancel()
		end
		requests = {}

		for _, listener in ipairs(listeners) do
			listener:Remove()
		end
		listeners = {}

		if refreshTimer ~= nil then
			refreshTimer:Cancel()
			refreshTimer = nil
		end
	end

	itemDetails.onRemove = function(_)
		cancelRequestsTimersAndListeners()
	end

	local content = require("modal"):createContent()
	content.title = config.title
	content.icon = "⚔️"
	content.node = itemDetails

	local nameArea = ui:createFrame(Color(0, 0, 0))
	nameArea:setParent(itemDetails)
	itemDetails.nameArea = nameArea

	local name = ui:createText("name", Color.White)
	name:setParent(nameArea)
	itemDetails.name = name
	name.LocalPosition = { theme.padding, theme.padding, 0 }

	local infoArea = ui:createFrame(Color(0, 0, 0))
	infoArea:setParent(itemDetails)
	itemDetails.infoArea = infoArea

	local publishDate = ui:createText("🌎 2 days ago (v1)", Color.White, "small")
	publishDate:setParent(infoArea)
	itemDetails.publishDate = publishDate
	publishDate.LocalPosition = { theme.padding, theme.padding, 0 }

	local by
	if createMode then
		by = ui:createText("by", Color.White, "small")
	else
		by = ui:createButton("by...", { textSize = "small" })
	end
	by:setParent(infoArea)
	itemDetails.by = by
	by.LocalPosition = publishDate.LocalPosition + { 0, publishDate.Height + theme.padding, 0 }

	local author
	if createMode then
		local str = " @" .. Player.Username
		author = ui:createText(str, Color.Green)
		author:setParent(infoArea)
		itemDetails.author = author
		author.LocalPosition = by.LocalPosition + { by.Width, 0, 0 }
	end

	local descriptionArea = ui:createFrame(Color(0, 0, 0))
	descriptionArea.IsMask = true
	descriptionArea:setParent(itemDetails)
	itemDetails.descriptionArea = descriptionArea

	local description = ui:createText("description", Color.White, "small")
	description:setParent(descriptionArea)
	itemDetails.description = description
	description.LocalPosition.X = theme.padding

	local shapeArea = ui:createFrame(Color(0, 0, 0))
	shapeArea:setParent(itemDetails)
	itemDetails.shapeArea = shapeArea

	local commentsBtn = ui:createButton("💬 0")
	commentsBtn:disable()
	commentsBtn:setParent(itemDetails)
	commentsBtn.onRelease = function() end

	local copyNameBtn = ui:createButton("📑 Copy Name", { textSize = "small" })
	copyNameBtn:setParent(itemDetails)
	copyNameBtn.onRelease = function()
		Dev:CopyToClipboard(copyNameBtn.itemFullName or "")
		local prevWidth = copyNameBtn.Width
		copyNameBtn.Text = "📑 Copied!"
		if copyNameBtn.Width < prevWidth then
			copyNameBtn.Width = prevWidth
		end
		Timer(1, function()
			if copyNameBtn == nil then
				return
			end
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
		signalBtn:disable()
		signalBtn:setParent(itemDetails)

		likeBtn = ui:createButton("❤️ …")
		likeBtn:setParent(itemDetails)
		itemDetails.likeBtn = likeBtn

		itemDetails.liked = false
		itemDetails.originalLiked = false
	elseif config.mode == "create" then
		likes = ui:createText("❤️ …", theme.textColor)
		likes:setParent(itemDetails)
		itemDetails.likes = likes

		editDescriptionBtn = ui:createButton("✏️")
		editDescriptionBtn:setParent(descriptionArea)
		editDescriptionBtn.onRelease = function()
			if System.MultilineInput ~= nil and itemDetails.description then
				local description = itemDetails.description
				if description.empty == true then
					description = ""
				end
				System.MultilineInput(
					description.Text,
					"Description",
					"How would you describe that Item?",
					"", -- regex
					10000, -- max chars
					function(text) -- done
						ui:turnOn()
						local description = itemDetails.description
						if text == "" then
							description.empty = true
							description.Text = "Items are easier to find with a description!"
							description.Color = theme.textColorSecondary
						else
							description.empty = false
							description.Text = text
							description.Color = theme.textColor
						end
						description.pos.Y = descriptionArea.Height - description.Height - theme.padding
						local req = api:patchItem(itemDetails.id, { description = text }, function(_, _)
							-- not handling response yet
						end)
						table.insert(requests, req)
					end,
					function() -- cancel
						ui:turnOn()
					end
				)
				ui:turnOff()
			end
		end
	end

	itemDetails.shape = nil

	itemDetails.reloadShape = function(self)
		if self.cell.itemFullName == nil then
			return
		end
		local req = Object:Load(self.cell.itemFullName, function(obj)
			if obj == nil then
				return
			end
			if self.cell == nil then
				return
			end

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

			self.shape = ui:createShape(obj, { spherized = true })
			self.shape.Width = w
			self.shape.Height = h
			self.shape.pivot.LocalRotation = { -0.1, 0, -0.2 }

			self.shape:setParent(self)
			self.shape.pos = { x, y, 0 }
		end)
		table.insert(requests, req)
	end

	content.loadCell = function(_, cell)
		local self = itemDetails

		if self.shape then
			self.shape:remove()
			self.shape = nil
		end

		self.cell = cell
		self.id = cell.id

		if createMode then
			self.author.Text = " @" .. cell.repo
		end

		-- Retrieve item info. We need its number of likes.
		-- (cell.id is Item UUID)
		local req = api:getItem(cell.id, function(err, item)
			if err ~= nil then
				-- don't do anything on failure
				-- api module should implement retry strategy
				return
			end

			local likes = item.likes or 0

			if self.likes then
				self.likes.Text = "❤️ " .. math.floor(likes) -- force integer format
			elseif self.likeBtn then
				local likeBtn = self.likeBtn
				likeBtn.Text = "❤️ " .. math.floor(likes) -- force integer format
				self.liked = item.liked
				self.originalLiked = item.liked or false
				self.originalLikes = item.likes or 0
				if item.liked == true and likeBtn.setColor then
					likeBtn:setColor(theme.colorPositive)
				end
			end

			if self.description then
				local description = item.description or ""
				self.description.Text = description
			end

			if createMode == false then
				by.Text = "by @" .. cell.repo
				authorID = item["author-id"]

				by.onRelease = function(_)
					local profileContent = require("profile"):create({
						isLocal = false,
						username = cell.repo,
						userID = authorID,
						uikit = ui,
					})
					content:push(profileContent)
				end
			end

			self:refresh() -- refresh layout
		end)
		table.insert(requests, req)

		self.name.Text = cell.name

		if config.mode == "create" then
			if cell.description == nil or cell.description == "" then
				self.description.empty = true
				self.description.Text = "Items are easier to find with a description!"
				self.description.Color = theme.textColorSecondary
			else
				self.description.Text = ""
				self.description.Color = theme.textColor
			end
		else
			self.description.Text = ""
			self.description.Color = theme.textColor
		end

		if self.likes then
			self.likes.Text = "❤️ " .. (cell.likes and math.floor(cell.likes) or "…")
		elseif self.likeBtn then
			self.likeBtn.Text = "❤️ " .. (cell.likes and math.floor(cell.likes) or "…")
			self.likeBtn.onRelease = function()
				self.liked = not self.liked
				local req = api:likeItem(cell.id, self.liked, function(_) end)
				table.insert(requests, req)

				if self.liked then
					likeBtn:setColor(theme.colorPositive)
				else
					likeBtn:setColor(theme.buttonColor)
				end

				local nbLikes = self.originalLikes or 0
				if self.liked ~= self.originalLiked then
					if self.liked then
						nbLikes = nbLikes + 1
					else
						nbLikes = nbLikes - 1
					end
				end
				if nbLikes < 0 then
					nbLikes = 0
				end
				likeBtn.Text = "❤️ " .. math.floor(nbLikes)

				self:refresh() -- refresh layout
			end
		end

		self.created = cell.created
		print("CREATED:", self.created) -- timezone_test1 | created | 1709046283
		if self.created then
			local n, unitType = time.ago(self.created)
			-- if n == 1 then
			-- 	unitType = unitType:sub(1, #unitType - 1)
			-- end
			self.publishDate.Text = "🌎 " .. n .. " " .. unitType .. " ago"
		end

		copyNameBtn.itemFullName = cell.itemFullName

		local shapeAsyncLoad = false
		local shape
		if cell.item.shape then
			shape = Shape(cell.item.shape, { includeChildren = true })
		else
			shapeAsyncLoad = true
			shape = MutableShape()
			shape:AddBlock(Color(255, 255, 255, 50), 0, 0, 0)
		end

		self.shape = ui:createShape(shape, { spherized = true })
		self.shape.Width = 350
		self.shape.Height = 350

		self.shape.pivot.LocalRotation = { -0.1, 0, -0.2 }

		local t = 0
		local listener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
			t = t + dt
			if self.shape ~= nil then
				self.shape.pivot.LocalRotation.Y = t
			end
		end)
		table.insert(listeners, listener)

		self.shape:setParent(self)

		self:refresh()

		if shapeAsyncLoad then
			self:reloadShape()
		end
	end

	itemDetails._w = 400
	itemDetails._h = 400

	itemDetails._scheduleRefresh = function(self)
		if refreshTimer ~= nil then
			return
		end
		refreshTimer = Timer(0.01, function()
			if self == nil or self.refresh == nil then
				return
			end
			refreshTimer = nil
			self:refresh()
		end)
	end

	itemDetails._width = function(_)
		return itemDetails._w
	end

	itemDetails._height = function(_)
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
		if self.shape == nil then
			return
		end

		local portraitMode = self.Width < self.Height

		if portraitMode then
			-- min width to display details, buttons, etc.
			-- remaining height can be used for the preview
			local detailsMinHeight = 200 -- not including signal & like buttons
			local detailsHeightRatio = 0.50

			local availableWidth = self.Width - theme.padding * 2
			local availableHeight = self.Height - copyNameBtn.Height - theme.padding * 2

			local h = math.max(likeBtn and likeBtn.Height or 0, likes and likes.Height or 0, commentsBtn.Height)
			availableHeight = availableHeight - h - theme.padding

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

			local w = (likes and likes.Width + theme.padding or 0)
				+ (likeBtn and likeBtn.Width + theme.padding or 0)
				+ (signalBtn and signalBtn.Width + theme.padding or 0)
				+ (commentsBtn and commentsBtn.Width + theme.padding or 0)
				- theme.padding

			local startX = availableWidth * 0.5 - w * 0.5

			if signalBtn then
				signalBtn.pos.X = startX
				startX = startX + signalBtn.Width + theme.padding
				signalBtn.pos.Y = self.shape.pos.Y - signalBtn.Height - theme.padding
			end

			if commentsBtn then
				commentsBtn.pos.X = startX
				startX = startX + commentsBtn.Width + theme.padding
				commentsBtn.pos.Y = self.shape.pos.Y - commentsBtn.Height - theme.padding
			end

			if likes then
				likes.pos.X = startX
				startX = startX + likes.Width + theme.padding
				likes.pos.Y = self.shape.pos.Y - h + (h - likes.Height) * 0.5 - theme.padding
			end

			if likeBtn then
				likeBtn.pos.X = startX
				-- startX = startX + likeBtn.Width + theme.padding
				likeBtn.pos.Y = self.shape.pos.Y - h + (h - likeBtn.Height) * 0.5 - theme.padding
			end

			self.nameArea.Height = self.name.Height + theme.padding * 2
			self.nameArea.Width = self.Width

			self.nameArea.pos = { 0, self.shape.pos.Y - h - self.nameArea.Height - theme.padding * 2 }

			self.infoArea.Height = self.by.Height + self.publishDate.Height + theme.padding * 3
			self.infoArea.Width = self.nameArea.Width
			self.infoArea.LocalPosition = self.nameArea.LocalPosition - { 0, self.infoArea.Height + theme.padding, 0 }

			self.descriptionArea.Height = detailsHeight
				- self.nameArea.Height
				- self.infoArea.Height
				- theme.padding * 2
			self.descriptionArea.Width = self.nameArea.Width
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

			copyNameBtn.pos.Y = self.descriptionArea.pos.Y - copyNameBtn.Height - theme.padding
		else -- landscape
			-- min width to display details, buttons, etc.
			-- remaining width can be used for the preview

			local detailsWidthRatio = 0.66
			local detailsWidth = (self.Width - theme.padding) * detailsWidthRatio
			local previewWidth = self.Width - theme.padding - detailsWidth

			-- total width needed for 1st line of buttons under the preview
			local w = (likes and likes.Width + theme.padding or 0)
				+ (likeBtn and likeBtn.Width + theme.padding or 0)
				+ (signalBtn and signalBtn.Width + theme.padding or 0)
				+ (commentsBtn and commentsBtn.Width + theme.padding or 0)
				- theme.padding

			-- height of the 1st line of buttons under the preview
			local h = math.max(likeBtn and likeBtn.Height or 0, likes and likes.Height or 0, commentsBtn.Height)

			-- Decide whether the comments button will be on its own line.
			local commentsBtnOnSeparateLine = w > previewWidth

			local availableHeight = self.Height
			local availableHeightForPreview = availableHeight - copyNameBtn.Height - theme.padding
			availableHeightForPreview = availableHeightForPreview - h - theme.padding

			if commentsBtn ~= nil and commentsBtnOnSeparateLine == true then
				availableHeightForPreview = availableHeightForPreview - commentsBtn.Height - theme.padding
			end

			if previewWidth > availableHeightForPreview then
				previewWidth = availableHeightForPreview
				detailsWidth = self.Width - theme.padding - previewWidth
			end

			self.shape.Width = previewWidth

			self.shape.LocalPosition.X = self.Width - self.shape.Width
			self.shape.LocalPosition.Y = self.Height - self.shape.Height

			self.shapeArea.Width = self.shape.Width
			self.shapeArea.Height = self.shape.Height
			self.shapeArea.LocalPosition = self.shape.LocalPosition

			if likeBtn then
				likeBtn.pos.X = self.shape.pos.X + self.shape.Width - likeBtn.Width
				likeBtn.pos.Y = self.shape.pos.Y - h + (h - likeBtn.Height) * 0.5 - theme.padding
				copyNameBtn.pos.Y = likeBtn.pos.Y - copyNameBtn.Height - theme.padding
			end

			if likes then
				likes.pos.X = self.shape.pos.X + self.shape.Width - likes.Width
				likes.pos.Y = self.shape.pos.Y - h + (h - likes.Height) * 0.5 - theme.padding
				copyNameBtn.pos.Y = likes.pos.Y - copyNameBtn.Height - theme.padding
			end

			if commentsBtn then
				if w <= self.shape.Width then
					if likeBtn then
						commentsBtn.pos.X = likeBtn.pos.X - commentsBtn.Width - theme.padding
					elseif likes then
						commentsBtn.pos.X = likes.pos.X - commentsBtn.Width - theme.padding
					else
						commentsBtn.pos.X = self.shape.pos.X + self.shape.Width - commentsBtn.Width
					end
					commentsBtn.pos.Y = self.shape.pos.Y - commentsBtn.Height - theme.padding
				else
					commentsBtn.pos.X = self.shape.pos.X + self.shape.Width - commentsBtn.Width

					if likeBtn then
						commentsBtn.pos.Y = likeBtn.pos.Y - copyNameBtn.Height - theme.padding
					elseif likes then
						commentsBtn.pos.Y = likes.pos.Y - copyNameBtn.Height - theme.padding
					else
						commentsBtn.pos.Y = self.shape.pos.Y - commentsBtn.Height - theme.padding
					end
				end

				copyNameBtn.pos.Y = commentsBtn.pos.Y - copyNameBtn.Height - theme.padding
			end

			if signalBtn then
				signalBtn.LocalPosition.X = self.shape.LocalPosition.X
				signalBtn.LocalPosition.Y = self.shape.LocalPosition.Y - signalBtn.Height - theme.padding
			end

			self.nameArea.Height = self.name.Height + theme.padding * 2
			self.nameArea.Width = detailsWidth
			self.nameArea.LocalPosition = { 0, self.Height - self.nameArea.Height, 0 }

			self.infoArea.Height = self.by.Height + self.publishDate.Height + theme.padding * 3
			self.infoArea.Width = detailsWidth
			self.infoArea.LocalPosition = self.nameArea.LocalPosition - { 0, self.infoArea.Height + theme.padding, 0 }

			self.descriptionArea.Height = availableHeight
				- self.nameArea.Height
				- self.infoArea.Height
				- theme.padding * 2
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

		copyNameBtn.pos.X = self.Width - copyNameBtn.Width
	end

	return content
end

itemDetails.createModal = function(_, config)
	local cell = config.cell
	if not cell then
		error("Can't make item details modal without cell in config")
		return
	end

	local modal = require("modal")
	local ui = config.ui or require("uikit")
	local ease = require("ease")
	local theme = require("uitheme").current
	local MODAL_MARGIN = theme.paddingBig -- space around modals

	-- TODO: handle this correctly
	local topBarHeight = 50

	local content = modal:createContent()

	local itemDetailsContent = itemDetails:createModalContent({ uikit = ui })
	itemDetailsContent:loadCell(cell)

	itemDetailsContent.idealReducedContentSize = function(content, width, height)
		content.Width = width * 0.8
		content.Height = height * 0.8
		return Number2(content.Width, content.Height)
	end

	function maxModalWidth()
		local computed = Screen.Width - Screen.SafeArea.Left - Screen.SafeArea.Right - MODAL_MARGIN * 2
		local max = 1400
		local w = math.min(max, computed)
		return w
	end

	function maxModalHeight()
		return Screen.Height - Screen.SafeArea.Bottom - topBarHeight - MODAL_MARGIN * 2
	end

	function updateModalPosition(modal, forceBounce)
		local vMin = Screen.SafeArea.Bottom + MODAL_MARGIN
		local vMax = Screen.Height - topBarHeight - MODAL_MARGIN

		local vCenter = vMin + (vMax - vMin) * 0.5

		local p = Number3(Screen.Width * 0.5 - modal.Width * 0.5, vCenter - modal.Height * 0.5, 0)

		if not modal.updatedPosition or forceBounce then
			modal.LocalPosition = p - { 0, 100, 0 }
			modal.updatedPosition = true
			ease:cancel(modal) -- cancel modal ease animations if any
			ease:outBack(modal, 0.22).LocalPosition = p
		else
			modal.LocalPosition = p
		end
	end

	local currentModal = modal:create(content, maxModalWidth, maxModalHeight, updateModalPosition, ui)

	content:pushAndRemoveSelf(itemDetailsContent)

	return currentModal
end

return itemDetails
