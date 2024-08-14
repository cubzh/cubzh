mod = {}

local function prettifyItemName(str)
	local s = string.gsub(str, "_%a", string.upper)
	s = string.gsub(s, "_", " ")
	s = string.gsub(s, "^%l", string.upper)
	return s
end

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
	content.title = prettifyItemName(config.item.name)
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

	local itemArea
	local itemShape
	local itemAreaRatio = 16 / 9
	local by
	local authorBtn
	local likeBtn
	local editDescriptionBtn
	local description
	local creationDate
	local updateDate
	local identifier
	local btnCopyIdentifier

	local secondaryTextColor = Color(150, 150, 150)

	itemArea = ui:frame({ color = Color(20, 20, 22) })
	itemArea:setParent(cell)

	creationDate = ui:createText("🌎 published … ago", secondaryTextColor, "small")
	creationDate:setParent(cell)

	updateDate = ui:createText("✨ updated … ago", secondaryTextColor, "small")
	updateDate:setParent(cell)

	identifier = ui:createText("🔗 identifier:", secondaryTextColor, "small")
	identifier:setParent(cell)

	btnCopyIdentifier = ui:buttonSecondary({ content = "📑", textSize = "small" })
	btnCopyIdentifier:setParent(cell)

	btnCopyIdentifier.onRelease = function()
		Dev:CopyToClipboard(item.repo .. "." .. item.name)
	end

	by = ui:createText("🛠️ created by", secondaryTextColor, "small")
	by:setParent(cell)

	authorBtn = ui:buttonLink({ content = "@…", textSize = "small" })
	authorBtn:setParent(cell)

	description = ui:createText("description", Color.White, "small")
	description:setParent(cell)

	likeBtn = ui:buttonNeutral({ content = "🤍 …", textSize = "small" })
	likeBtn:setParent(cell)

	if createMode then
		editDescriptionBtn = ui:buttonSecondary({ content = "✏️ Edit description", textSize = "small" })
		editDescriptionBtn:setParent(cell)
		editDescriptionBtn.onRelease = function()
			if System.MultilineInput ~= nil then
				if description.empty == true then
					description.Text = ""
				end
				System.MultilineInput(
					description.Text,
					"Description",
					"How would you describe that Item?",
					"", -- regex
					10000, -- max chars
					function(text) -- done
						ui:turnOn()
						if text == "" then
							description.empty = true
							description.Text = "Worlds are easier to find with a description!"
							description.Color = theme.textColorSecondary
							local req = systemApi:patchItem(item.id, { description = "" }, function(_, _)
								-- not handling response yet
							end)
							table.insert(requests, req)
						else
							description.empty = false
							description.Text = text
							description.Color = theme.textColor
							local req = systemApi:patchItem(item.id, { description = text }, function(_, _)
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

	local scroll = ui:scroll({
		-- backgroundColor = Color(255, 0, 0),
		backgroundColor = theme.buttonTextColor,
		-- backgroundColor = Color(0, 255, 0, 0.3),
		-- gradientColor = Color(37, 23, 59), -- Color(155, 97, 250),
		padding = {
			top = theme.scrollPadding,
			bottom = theme.scrollPadding,
			left = theme.scrollPadding,
			right = theme.scrollPadding,
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
		if createMode then
			if item.description == nil or item.description == "" then
				description.empty = true
				description.Text = "Items are easier to find with a description!"
				description.Color = theme.textColorSecondary
			else
				description.empty = false
				description.Text = item.description
				description.Color = theme.textColor
			end
		else
			description.Text = item.description or ""
			description.Color = theme.textColor
		end

		if likeBtn then
			likeBtn.Text = (item.liked == true and "❤️ " or "🤍 ") .. (item.likes and math.floor(item.likes) or 0)

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
				likeBtn.Text = (item.liked == true and "❤️ " or "🤍 ") .. nbLikes

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

		if item.repo ~= "" and item.name ~= "" then
			identifier.Text = string.format("🔗 identifier: %s.%s", item.repo, item.name)
		end

		-- update author text/button

		if authorBtn and item.authorName then
			authorBtn.Text = "@" .. item.authorName
			authorBtn.onRelease = function(_)
				local profileConfig = {
					username = item.authorName,
					userID = item.authorId,
					uikit = ui,
				}
				local profileContent = require("profile"):create(profileConfig)
				content:push(profileContent)
			end
		end

		content.title = prettifyItemName(item.name) or "…"

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

	local itemShapeReq
	privateFields.loadItemShape = function()
		if item.repo == "" or item.name == "" then
			return
		end
		if itemShape ~= nil or itemShapeReq ~= nil then
			-- item already loaded, or loading
			return
		end

		itemShapeReq = Object:Load(item.repo .. "." .. item.name, function(obj)
			if obj == nil then
				-- TODO: handle error
				return
			end

			itemShape = ui:createShape(obj, { spherized = true })
			itemShape.parentDidResize = function(self)
				local parent = self.parent
				itemShape.Height = parent.Height
				itemShape.pos =
					{ parent.Width * 0.5 - itemShape.Width * 0.5, parent.Height * 0.5 - itemShape.Height * 0.5 }
			end
			itemShape:setParent(itemArea)

			local t = math.pi

			local function setItemRotation(t)
				itemShape.pivot.LocalRotation:Set(-0.1, t, -0.2)
			end

			local listener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
				t = t + dt
				setItemRotation(t)
			end)
			table.insert(listeners, listener)
		end)
		table.insert(requests, itemShapeReq)
	end

	privateFields.loadItem = function()
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
			privateFields.loadItemShape()
		end)
		table.insert(requests, req)

		privateFields.loadItemShape()
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
		local parent = likeBtn.parent
		if parent == nil then
			return
		end

		local viewAndLikesWidth = likeBtn.Width
		likeBtn.pos.X = parent.Width * 0.5 - viewAndLikesWidth * 0.5
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

		local itemAreaHeight = self.Height * 0.3
		local itemAreaWidth = itemAreaHeight * itemAreaRatio
		if itemAreaWidth > width then
			itemAreaWidth = width
			itemAreaHeight = itemAreaWidth * 1.0 / itemAreaRatio
		end

		itemArea.Width = itemAreaWidth
		itemArea.Height = itemAreaHeight

		description.object.MaxWidth = width - padding * 2

		local author = authorBtn
		local singleLineHeight = math.max(by.Height, author.Height)

		local contentHeight = itemArea.Height
			+ padding
			+ likeBtn.Height -- views and likes
			+ theme.paddingBig
			+ singleLineHeight -- author
			+ padding
			+ singleLineHeight -- publication date
			+ padding
			+ singleLineHeight -- update date
			+ theme.paddingBig
			+ description.Height

		if editDescriptionBtn then
			contentHeight = contentHeight + editDescriptionBtn.Height + padding
		end

		cell.Height = contentHeight
		cell.Width = width

		local y = contentHeight - itemArea.Height

		itemArea.pos.X = width * 0.5 - itemArea.Width * 0.5
		itemArea.pos.Y = y

		-- view and likes
		y = y - padding - likeBtn.Height
		likeBtn.pos.Y = y
		privateFields.alignViewsAndLikes()

		-- author
		y = y - theme.paddingBig - singleLineHeight * 0.5
		by.pos = { padding, y - by.Height * 0.5 }
		authorBtn.pos = { by.pos.X + by.Width + padding, y - author.Height * 0.5 }
		y = y - singleLineHeight * 0.5

		y = y - padding - singleLineHeight * 0.5
		creationDate.pos = { padding, y - creationDate.Height * 0.5 }
		y = y - singleLineHeight * 0.5

		y = y - padding - singleLineHeight * 0.5
		updateDate.pos = { padding, y - updateDate.Height * 0.5 }
		y = y - singleLineHeight * 0.5

		y = y - padding - singleLineHeight * 0.5
		identifier.pos = { padding, y - identifier.Height * 0.5 }
		y = y - singleLineHeight * 0.5

		btnCopyIdentifier.pos = {
			identifier.pos.X + identifier.Width + padding,
			identifier.pos.Y + identifier.Height * 0.5 - identifier.Height * 0.5,
		}

		y = y - theme.paddingBig - description.Height
		description.pos = { padding, y }

		if editDescriptionBtn ~= nil then
			y = y - padding - editDescriptionBtn.Height
			editDescriptionBtn.pos = { width * 0.5 - editDescriptionBtn.Width * 0.5, y }
		end

		scroll.Width = self.Width
		scroll.Height = self.Height -- - btnLaunch.Height - padding * 2

		scroll:flush()
		scroll:refresh()
	end

	privateFields:refreshItem()
	privateFields:loadItem()

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
