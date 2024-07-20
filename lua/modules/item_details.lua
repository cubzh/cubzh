mod = {}

mod.createModalContent = function(_, config)
	local systemApi = require("system_api", System)
	local api = require("api")
	local time = require("time")
	local theme = require("uitheme").current

	local defaultConfig = {
		item = {
			id = "",
			repo = "",
			name = "",
			title = "…",
			description = "",
			likes = nil,
			liked = nil,
		},
		mode = "explore", -- "explore" / "create"
		uikit = require("uikit"),
	}

	local ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config, {
			acceptTypes = {
				-- TODO: config module should allow checking deeper levels
				-- item = {
				-- 	id = { "string" },
				-- 	repo = { "string" },
				-- 	name = { "string" },
				-- },
			},
		})
	end)
	if not ok then
		error("itemDetails:createModalContent(config) - config error: " .. err, 2)
	end

	local ui = config.uikit

	local item = config.item

	local createMode = config.mode == "create"

	local itemDetails = ui:createNode()

	local requests = {}
	local likeRequest
	local refreshTimer
	local listeners = {}

	local privateFields = {}

	local authorID

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
	content.title = config.item.name
	content.icon = "⚔️"
	content.node = itemDetails

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

	local cell = ui:frame() -- { color = Color(100, 100, 100) }
	cell.Height = 100
	cell:setParent(nil)

	local name
	local by
	local authorBtn
	local likeBtn
	local likes
	local description
	local creationDate
	local updateDate

	local secondaryTextColor = Color(150, 150, 150)

	creationDate = ui:createText("🌎 published … ago", secondaryTextColor, "small")
	creationDate:setParent(cell)

	updateDate = ui:createText("✨ updated … ago", secondaryTextColor, "small")
	updateDate:setParent(cell)

	by = ui:createText("🛠️ created by", secondaryTextColor, "small")
	by:setParent(cell)

	authorBtn = ui:buttonLink({ content = "@…", textSize = "small" })
	authorBtn:setParent(cell)

	description = ui:createText("description", Color.White, "small")
	description:setParent(cell)

	if createMode then
		-- TODO
	else -- explore mode
		likeBtn = ui:buttonNeutral({ content = "❤️ …", textSize = "small" })
		likeBtn:setParent(cell)
	end

	local scroll = ui:createScroll({
		-- backgroundColor = Color(255, 0, 0),
		backgroundColor = theme.buttonTextColor,
		-- backgroundColor = Color(0, 255, 0, 0.3),
		-- gradientColor = Color(37, 23, 59), -- Color(155, 97, 250),
		padding = {
			top = theme.padding,
			bottom = theme.padding,
			left = theme.padding,
			right = theme.padding,
		},
		cellPadding = theme.padding,
		loadCell = function(index)
			if index == 1 then
				return cell
			end
		end,
		unloadCell = function(_, _) end,
	})
	scroll:setParent(itemDetails)

	-- refreshes UI with what's in local config.item / item
	privateFields.refreshItem = function()
		if name ~= nil then
			name.Text = item.name or ""
		end

		if createMode then
			if item.description == nil or item.description == "" then
				description.empty = true
				description.Text = "Worlds are easier to find with a description!"
				description.Color = theme.textColorSecondary
			else
				description.Text = item.description
				description.Color = theme.textColor
			end
		else
			description.Text = item.description or ""
			description.Color = theme.textColor
		end

		if likes then
			likes.Text = "❤️ " .. (item.likes and math.floor(item.likes) or 0)
		elseif likeBtn then
			likeBtn.Text = "❤️ " .. (item.likes and math.floor(item.likes) or 0)

			likeBtn.onRelease = function()
				item.liked = not item.liked

				if item.liked == true then
					item.likes = item.likes ~= nil and item.likes + 1 or 1
				else
					item.likes = item.likes ~= nil and item.likes - 1 or 0
				end

				if likeRequest then
					likeRequest:Cancel()
				end
				likeRequest = systemApi:likeItem(item.id, item.liked, function(_)
					-- TODO: this request should return the refreshed number of likes
				end)
				table.insert(requests, likeRequest)

				if item.liked then
					likeBtn:setColor(theme.colorPositive)
				else
					likeBtn:setColor(theme.buttonColor)
				end

				local nbLikes = (item.likes and math.floor(item.likes) or 0)
				likeBtn.Text = "❤️ " .. nbLikes

				privateFields.alignViewsAndLikes()
			end
		end

		if item.created then
			local n, unitType = time.ago(item.created)
			if n == 1 then
				unitType = unitType:sub(1, #unitType - 1)
			end
			if math.floor(n) == n then
				creationDate.Text = string.format("🌎 published %d %s ago", math.floor(n), unitType)
			else
				creationDate.Text = string.format("🌎 published %.1f %s ago", n, unitType)
			end
		end

		if item.updated then
			local n, unitType = time.ago(item.updated)
			if n == 1 then
				unitType = unitType:sub(1, #unitType - 1)
			end
			if math.floor(n) == n then
				updateDate.Text = string.format("✨ updated %d %s ago", math.floor(n), unitType)
			else
				updateDate.Text = string.format("✨ updated %.1f %s ago", n, unitType)
			end
		end

		-- update author text/button

		if authorBtn and item.authorName then
			authorBtn.Text = "@" .. item.authorName
			authorBtn.onRelease = function(_)
				local profileConfig = {
					isLocal = false,
					username = item.authorName,
					userID = item.authorId,
					uikit = ui,
				}
				local profileContent = require("profile"):create(profileConfig)
				content:push(profileContent)
			end
		end

		content.title = item.name or "…"

		-- update description text
		if description ~= nil then
			description.Text = item.description or ""
		end

		-- update like button
		if item.liked ~= nil then
			if likeBtn ~= nil and likeBtn.setColor ~= nil then
				if item.liked then
					likeBtn:setColor(theme.colorPositive)
				else
					likeBtn:setColor(theme.buttonColor)
				end
			end
		end

		local modal = content:getModalIfContentIsActive()
		if modal ~= nil then
			modal:refreshContent()
		end

		itemDetails:refresh()
	end

	privateFields.loadItem = function()
		print("LOAD ITEM:", item.id)

		local req = api:getItem(item.id, {
			"repo",
			"name",
			"authorName",
			"authorId",
			"description",
			"liked",
			"likes",
			-- "views",
			"title",
			"created",
			"updated",
		}, function(itemInfo, err)
			if err ~= nil then
				-- TODO: handle error (retry button?)
				return
			end

			print("repo:", itemInfo.repo)
			print("name:", itemInfo.name)
			print("authorName:", itemInfo.authorName)
			print("authorId:", itemInfo.authorId)
			print("created:", itemInfo.created)
			print("updated:", itemInfo.updated)

			item.authorName = itemInfo.authorName
			item.authorId = itemInfo.authorId
			item.description = itemInfo.description
			item.title = itemInfo.title
			item.liked = itemInfo.liked
			item.likes = itemInfo.likes
			-- item.views = itemInfo.views
			item.created = itemInfo.created
			item.updated = itemInfo.updated

			privateFields:refreshItem()
		end)
		table.insert(requests, req)

		-- if world.thumbnail == nil then
		-- 	local req = api:getWorldThumbnail(world.id, function(thumbnail, err)
		-- 		if err ~= nil then
		-- 			return
		-- 		end
		-- 		world.thumbnail = thumbnail

		-- 		privateFields:refreshWorld()
		-- 	end)
		-- 	table.insert(requests, req)
		-- end
	end

	local w = 400
	local h = 400

	privateFields.scheduleRefresh = function()
		if refreshTimer ~= nil then
			return
		end
		refreshTimer = Timer(0.01, function()
			refreshTimer = nil
			itemDetails:refresh()
		end)
	end

	privateFields.alignViewsAndLikes = function()
		local likes = likes or likeBtn
		local parent = likes.parent
		if parent == nil then
			return
		end

		local viewAndLikesWidth = likes.Width
		likes.pos.X = parent.Width * 0.5 - viewAndLikesWidth * 0.5

		-- local viewAndLikesWidth = views.Width + theme.padding + likes.Width
		-- views.pos.X = parent.Width * 0.5 - viewAndLikesWidth * 0.5
		-- likes.pos.X = views.pos.X + views.Width + theme.padding
	end

	itemDetails._width = function(_)
		return w
	end

	itemDetails._height = function(_)
		return h
	end

	itemDetails._setWidth = function(_, v)
		w = v
		privateFields:scheduleRefresh()
	end

	itemDetails._setHeight = function(_, v)
		h = v
		privateFields:scheduleRefresh()
	end

	itemDetails.refresh = function(self)
		local padding = theme.padding
		local width = self.Width - padding * 2

		description.object.MaxWidth = width

		local likes = likes or likeBtn

		local author = author or authorBtn
		local singleLineHeight = math.max(by.Height, author.Height)

		local contentHeight = likes.Height -- views and likes
			+ theme.paddingBig
			+ singleLineHeight -- author
			+ padding
			+ singleLineHeight -- publication date
			+ padding
			+ singleLineHeight -- update date
			+ theme.paddingBig
			+ description.Height

		cell.Height = contentHeight
		cell.Width = width

		local y = contentHeight - likes.Height

		-- view and likes
		likes.pos.Y = y
		privateFields.alignViewsAndLikes()

		-- author
		y = y - theme.paddingBig - singleLineHeight * 0.5
		by.pos = { 0, y - by.Height * 0.5 }
		authorBtn.pos = { by.pos.X + by.Width + padding, y - author.Height * 0.5 }
		y = y - singleLineHeight * 0.5

		y = y - padding - singleLineHeight * 0.5
		creationDate.pos = { 0, y - creationDate.Height * 0.5 }
		y = y - singleLineHeight * 0.5

		y = y - padding - singleLineHeight * 0.5
		updateDate.pos = { 0, y - updateDate.Height * 0.5 }
		y = y - singleLineHeight * 0.5

		y = y - theme.paddingBig - description.Height
		description.pos = { 0, y }

		scroll.Width = self.Width
		scroll.Height = self.Height -- - btnLaunch.Height - padding * 2

		-- local bottomButtonsWidth = btnServers.Width + padding + btnLaunch.Width

		-- btnServers.pos = {
		-- 	width * 0.5 - bottomButtonsWidth * 0.5,
		-- 	padding + btnLaunch.Height * 0.5 - btnServers.Height * 0.5,
		-- }
		-- btnLaunch.pos = { btnServers.pos.X + btnServers.Width + padding, padding }
		-- scroll.pos.Y = btnLaunch.pos.Y + btnLaunch.Height + padding

		scroll:flush()
		scroll:refresh()
	end

	privateFields:refreshItem()
	privateFields:loadItem()

	-- local nameArea = ui:createFrame(Color(0, 0, 0))
	-- nameArea:setParent(itemDetails)
	-- itemDetails.nameArea = nameArea

	-- local name = ui:createText("name", Color.White)
	-- name:setParent(nameArea)
	-- itemDetails.name = name
	-- name.LocalPosition = { theme.padding, theme.padding, 0 }

	-- local infoArea = ui:createFrame(Color(0, 0, 0))
	-- infoArea:setParent(itemDetails)
	-- itemDetails.infoArea = infoArea

	-- local publishDate = ui:createText("🌎 2 days ago (v1)", Color.White, "small")
	-- publishDate:setParent(infoArea)
	-- itemDetails.publishDate = publishDate
	-- publishDate.LocalPosition = { theme.padding, theme.padding, 0 }

	-- local by
	-- if createMode then
	-- 	by = ui:createText("by", Color.White, "small")
	-- else
	-- 	by = ui:createButton("by...", { textSize = "small" })
	-- end
	-- by:setParent(infoArea)
	-- itemDetails.by = by
	-- by.LocalPosition = publishDate.LocalPosition + { 0, publishDate.Height + theme.padding, 0 }

	-- local author
	-- if createMode then
	-- 	local str = " @" .. Player.Username
	-- 	author = ui:createText(str, Color.Green)
	-- 	author:setParent(infoArea)
	-- 	itemDetails.author = author
	-- 	author.LocalPosition = by.LocalPosition + { by.Width, 0, 0 }
	-- end

	-- local descriptionArea = ui:createFrame(Color(0, 0, 0))
	-- descriptionArea.IsMask = true
	-- descriptionArea:setParent(itemDetails)
	-- itemDetails.descriptionArea = descriptionArea

	-- local description = ui:createText("description", Color.White, "small")
	-- description:setParent(descriptionArea)
	-- itemDetails.description = description
	-- description.LocalPosition.X = theme.padding

	-- local shapeArea = ui:createFrame(Color(0, 0, 0))
	-- shapeArea:setParent(itemDetails)
	-- itemDetails.shapeArea = shapeArea

	-- local commentsBtn = ui:createButton("💬 0")
	-- commentsBtn:disable()
	-- commentsBtn:setParent(itemDetails)
	-- commentsBtn.onRelease = function() end

	-- local copyNameBtn = ui:createButton("📑 Copy Name", { textSize = "small" })
	-- copyNameBtn:setParent(itemDetails)
	-- copyNameBtn.onRelease = function()
	-- 	Dev:CopyToClipboard(copyNameBtn.itemFullName or "")
	-- 	local prevWidth = copyNameBtn.Width
	-- 	copyNameBtn.Text = "📑 Copied!"
	-- 	if copyNameBtn.Width < prevWidth then
	-- 		copyNameBtn.Width = prevWidth
	-- 	end
	-- 	Timer(1, function()
	-- 		if copyNameBtn == nil then
	-- 			return
	-- 		end
	-- 		copyNameBtn.Width = nil
	-- 		copyNameBtn.Text = "📑 Copy Name"
	-- 	end)
	-- end

	-- TODO: implement create mode
	-- if createMode then
	-- 	likes = ui:createText("❤️ …", theme.textColor)
	-- 	likes:setParent(itemDetails)
	-- 	itemDetails.likes = likes

	-- 	editDescriptionBtn = ui:createButton("✏️")
	-- 	editDescriptionBtn:setParent(descriptionArea)
	-- 	editDescriptionBtn.onRelease = function()
	-- 		if System.MultilineInput ~= nil and itemDetails.description then
	-- 			local description = itemDetails.description
	-- 			if description.empty == true then
	-- 				description = ""
	-- 			end
	-- 			System.MultilineInput(
	-- 				description.Text,
	-- 				"Description",
	-- 				"How would you describe that Item?",
	-- 				"", -- regex
	-- 				10000, -- max chars
	-- 				function(text) -- done
	-- 					ui:turnOn()
	-- 					local description = itemDetails.description
	-- 					if text == "" then
	-- 						description.empty = true
	-- 						description.Text = "Items are easier to find with a description!"
	-- 						description.Color = theme.textColorSecondary
	-- 					else
	-- 						description.empty = false
	-- 						description.Text = text
	-- 						description.Color = theme.textColor
	-- 					end
	-- 					description.pos.Y = descriptionArea.Height - description.Height - theme.padding
	-- 					local req = systemApi:patchItem(itemDetails.id, { description = text }, function(_, _)
	-- 						-- not handling response yet
	-- 					end)
	-- 					table.insert(requests, req)
	-- 				end,
	-- 				function() -- cancel
	-- 					ui:turnOn()
	-- 				end
	-- 			)
	-- 			ui:turnOff()
	-- 		end
	-- 	end
	-- end

	-- itemDetails.shape = nil

	-- itemDetails.reloadShape = function(self)
	-- 	if self.cell.itemFullName == nil then
	-- 		return
	-- 	end
	-- 	local req = Object:Load(self.cell.itemFullName, function(obj)
	-- 		if obj == nil then
	-- 			return
	-- 		end
	-- 		if self.cell == nil then
	-- 			return
	-- 		end

	-- 		local w = 350
	-- 		local h = 350
	-- 		local x = 0
	-- 		local y = 0

	-- 		if self.shape then
	-- 			w = self.shape.Width
	-- 			h = self.shape.Height
	-- 			x = self.shape.LocalPosition.X
	-- 			y = self.shape.LocalPosition.Y

	-- 			self.shape:remove()
	-- 			self.shape = nil
	-- 		end

	-- 		self.shape = ui:createShape(obj, { spherized = true })
	-- 		self.shape.Width = w
	-- 		self.shape.Height = h
	-- 		self.shape.pivot.LocalRotation = { -0.1, 0, -0.2 }

	-- 		self.shape:setParent(self)
	-- 		self.shape.pos = { x, y, 0 }
	-- 	end)
	-- 	table.insert(requests, req)
	-- end

	-- content.loadCell = function(_, cell)
	-- 	local self = itemDetails

	-- 	if self.shape then
	-- 		self.shape:remove()
	-- 		self.shape = nil
	-- 	end

	-- 	self.cell = cell
	-- 	self.id = cell.id

	-- 	if createMode then
	-- 		self.author.Text = " @" .. cell.repo
	-- 	end

	-- 	-- Retrieve item info. We need its number of likes.
	-- 	-- (cell.id is Item UUID)
	-- 	local req = api:getItem(cell.id, function(err, item)
	-- 		if err ~= nil then
	-- 			-- don't do anything on failure
	-- 			-- api module should implement retry strategy
	-- 			return
	-- 		end

	-- 		local likes = item.likes or 0

	-- 		if self.likes then
	-- 			self.likes.Text = "❤️ " .. math.floor(likes) -- force integer format
	-- 		elseif self.likeBtn then
	-- 			local likeBtn = self.likeBtn
	-- 			likeBtn.Text = "❤️ " .. math.floor(likes) -- force integer format
	-- 			self.liked = item.liked
	-- 			self.originalLiked = item.liked or false
	-- 			self.originalLikes = item.likes or 0
	-- 			if item.liked == true and likeBtn.setColor then
	-- 				likeBtn:setColor(theme.colorPositive)
	-- 			end
	-- 		end

	-- 		if self.description then
	-- 			local description = item.description or ""
	-- 			self.description.Text = description
	-- 		end

	-- 		if createMode == false then
	-- 			by.Text = "by @" .. cell.repo
	-- 			authorID = item["author-id"]

	-- 			by.onRelease = function(_)
	-- 				local profileContent = require("profile"):create({
	-- 					isLocal = false,
	-- 					username = cell.repo,
	-- 					userID = authorID,
	-- 					uikit = ui,
	-- 				})
	-- 				content:push(profileContent)
	-- 			end
	-- 		end

	-- 		self:refresh() -- refresh layout
	-- 	end)
	-- 	table.insert(requests, req)

	-- 	self.name.Text = cell.name

	-- 	if config.mode == "create" then
	-- 		if cell.description == nil or cell.description == "" then
	-- 			self.description.empty = true
	-- 			self.description.Text = "Items are easier to find with a description!"
	-- 			self.description.Color = theme.textColorSecondary
	-- 		else
	-- 			self.description.Text = ""
	-- 			self.description.Color = theme.textColor
	-- 		end
	-- 	else
	-- 		self.description.Text = ""
	-- 		self.description.Color = theme.textColor
	-- 	end

	-- 	if self.likes then
	-- 		self.likes.Text = "❤️ " .. (cell.likes and math.floor(cell.likes) or "…")
	-- 	elseif self.likeBtn then
	-- 		self.likeBtn.Text = "❤️ " .. (cell.likes and math.floor(cell.likes) or "…")
	-- 		self.likeBtn.onRelease = function()
	-- 			self.liked = not self.liked
	-- 			local req = systemApi:likeItem(cell.id, self.liked, function(_) end)
	-- 			table.insert(requests, req)

	-- 			if self.liked then
	-- 				likeBtn:setColor(theme.colorPositive)
	-- 			else
	-- 				likeBtn:setColor(theme.buttonColor)
	-- 			end

	-- 			local nbLikes = self.originalLikes or 0
	-- 			if self.liked ~= self.originalLiked then
	-- 				if self.liked then
	-- 					nbLikes = nbLikes + 1
	-- 				else
	-- 					nbLikes = nbLikes - 1
	-- 				end
	-- 			end
	-- 			if nbLikes < 0 then
	-- 				nbLikes = 0
	-- 			end
	-- 			likeBtn.Text = "❤️ " .. math.floor(nbLikes)

	-- 			self:refresh() -- refresh layout
	-- 		end
	-- 	end

	-- 	self.created = cell.created
	-- 	if self.created then
	-- 		local n, unitType = time.ago(self.created)
	-- 		if n == 1 then
	-- 			unitType = unitType:sub(1, #unitType - 1)
	-- 		end
	-- 		self.publishDate.Text = "🌎 " .. n .. " " .. unitType .. " ago"
	-- 	end

	-- 	copyNameBtn.itemFullName = cell.itemFullName

	-- 	local shapeAsyncLoad = false
	-- 	local shape
	-- 	if cell.item.shape then
	-- 		shape = Shape(cell.item.shape, { includeChildren = true })
	-- 	else
	-- 		shapeAsyncLoad = true
	-- 		shape = MutableShape()
	-- 		shape:AddBlock(Color(255, 255, 255, 50), 0, 0, 0)
	-- 	end

	-- 	self.shape = ui:createShape(shape, { spherized = true })
	-- 	self.shape.Width = 350
	-- 	self.shape.Height = 350

	-- 	self.shape.pivot.LocalRotation = { -0.1, 0, -0.2 }

	-- 	local t = 0
	-- 	local listener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
	-- 		t = t + dt
	-- 		if self.shape ~= nil then
	-- 			self.shape.pivot.LocalRotation.Y = t
	-- 		end
	-- 	end)
	-- 	table.insert(listeners, listener)

	-- 	self.shape:setParent(self)

	-- 	self:refresh()

	-- 	if shapeAsyncLoad then
	-- 		self:reloadShape()
	-- 	end
	-- end

	-- itemDetails._w = 400
	-- itemDetails._h = 400

	-- itemDetails._scheduleRefresh = function(self)
	-- 	if refreshTimer ~= nil then
	-- 		return
	-- 	end
	-- 	refreshTimer = Timer(0.01, function()
	-- 		if self == nil or self.refresh == nil then
	-- 			return
	-- 		end
	-- 		refreshTimer = nil
	-- 		self:refresh()
	-- 	end)
	-- end

	-- itemDetails._width = function(_)
	-- 	return itemDetails._w
	-- end

	-- itemDetails._height = function(_)
	-- 	return itemDetails._h
	-- end

	-- itemDetails._setWidth = function(self, v)
	-- 	itemDetails._w = v
	-- 	self:_scheduleRefresh()
	-- end

	-- itemDetails._setHeight = function(self, v)
	-- 	itemDetails._h = v
	-- 	self:_scheduleRefresh()
	-- end

	-- itemDetails.refresh = function(self)
	-- 	if self.shape == nil then
	-- 		return
	-- 	end

	-- 	-- min width to display details, buttons, etc.
	-- 	-- remaining height can be used for the preview
	-- 	local detailsMinHeight = 200 -- not including signal & like buttons
	-- 	local detailsHeightRatio = 0.50

	-- 	local availableWidth = self.Width - theme.padding * 2
	-- 	local availableHeight = self.Height - copyNameBtn.Height - theme.padding * 2

	-- 	local h = math.max(likeBtn and likeBtn.Height or 0, likes and likes.Height or 0, commentsBtn.Height)
	-- 	availableHeight = availableHeight - h - theme.padding

	-- 	local detailsHeight = availableHeight * detailsHeightRatio
	-- 	if detailsHeight < detailsMinHeight then
	-- 		detailsHeight = detailsMinHeight
	-- 	end

	-- 	local previewSize = math.min(availableHeight - detailsHeight, availableWidth)

	-- 	self.shape.Width = previewSize

	-- 	self.shape.LocalPosition.X = self.Width * 0.5 - self.shape.Width * 0.5
	-- 	self.shape.LocalPosition.Y = self.Height - self.shape.Height

	-- 	self.shapeArea.Width = self.shape.Width
	-- 	self.shapeArea.Height = self.shape.Height
	-- 	self.shapeArea.LocalPosition = self.shape.LocalPosition

	-- 	local w = (likes and likes.Width + theme.padding or 0)
	-- 		+ (likeBtn and likeBtn.Width + theme.padding or 0)
	-- 		+ (signalBtn and signalBtn.Width + theme.padding or 0)
	-- 		+ (commentsBtn and commentsBtn.Width + theme.padding or 0)
	-- 		- theme.padding

	-- 	local startX = availableWidth * 0.5 - w * 0.5

	-- 	if signalBtn then
	-- 		signalBtn.pos.X = startX
	-- 		startX = startX + signalBtn.Width + theme.padding
	-- 		signalBtn.pos.Y = self.shape.pos.Y - signalBtn.Height - theme.padding
	-- 	end

	-- 	if commentsBtn then
	-- 		commentsBtn.pos.X = startX
	-- 		startX = startX + commentsBtn.Width + theme.padding
	-- 		commentsBtn.pos.Y = self.shape.pos.Y - commentsBtn.Height - theme.padding
	-- 	end

	-- 	if likes then
	-- 		likes.pos.X = startX
	-- 		startX = startX + likes.Width + theme.padding
	-- 		likes.pos.Y = self.shape.pos.Y - h + (h - likes.Height) * 0.5 - theme.padding
	-- 	end

	-- 	if likeBtn then
	-- 		likeBtn.pos.X = startX
	-- 		-- startX = startX + likeBtn.Width + theme.padding
	-- 		likeBtn.pos.Y = self.shape.pos.Y - h + (h - likeBtn.Height) * 0.5 - theme.padding
	-- 	end

	-- 	self.nameArea.Height = self.name.Height + theme.padding * 2
	-- 	self.nameArea.Width = self.Width

	-- 	self.nameArea.pos = { 0, self.shape.pos.Y - h - self.nameArea.Height - theme.padding * 2 }

	-- 	self.infoArea.Height = self.by.Height + self.publishDate.Height + theme.padding * 3
	-- 	self.infoArea.Width = self.nameArea.Width
	-- 	self.infoArea.LocalPosition = self.nameArea.LocalPosition - { 0, self.infoArea.Height + theme.padding, 0 }

	-- 	self.descriptionArea.Height = detailsHeight - self.nameArea.Height - self.infoArea.Height - theme.padding * 2
	-- 	self.descriptionArea.Width = self.nameArea.Width
	-- 	self.descriptionArea.LocalPosition = self.infoArea.LocalPosition
	-- 		- { 0, self.descriptionArea.Height + theme.padding, 0 }

	-- 	if editDescriptionBtn ~= nil then
	-- 		editDescriptionBtn.pos = {
	-- 			self.descriptionArea.Width - editDescriptionBtn.Width - theme.padding,
	-- 			self.descriptionArea.Height - editDescriptionBtn.Height - theme.padding,
	-- 			0,
	-- 		}

	-- 		self.description.object.MaxWidth = self.descriptionArea.Width - editDescriptionBtn.Width - theme.padding * 3
	-- 	else
	-- 		self.description.object.MaxWidth = self.descriptionArea.Width - theme.padding * 2
	-- 	end

	-- 	self.description.LocalPosition.Y = self.descriptionArea.Height - self.description.Height - theme.padding

	-- 	copyNameBtn.pos.Y = self.descriptionArea.pos.Y - copyNameBtn.Height - theme.padding

	-- 	copyNameBtn.pos.X = self.Width - copyNameBtn.Width
	-- end

	return content
end

mod.createModal = function(_, config)
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

	local itemDetailsContent = mod:createModalContent({ uikit = ui })
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

return mod
