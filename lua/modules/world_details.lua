worldDetailsMod = {}

worldDetailsMod.createModalContent = function(_, config)
	local time = require("time")
	local theme = require("uitheme").current
	local ui = config.uikit
	local systemApi = require("system_api", System)
	local api = require("api")

	local defaultConfig = {
		world = {
			id = "13693497-03fd-4492-9b36-9776bb11d958",
			title = "…",
			description = "",
			thumbnail = nil,
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
				-- world = {
				-- 	thumbnail = { "Data" },
				-- 	likes = { "integer" },
				-- 	liked = { "boolean" },
				-- },
			},
		})
	end)
	if not ok then
		error("worldDetailsMod:createModalContent(config) - config error: " .. err, 2)
	end

	local world = config.world

	local createMode = config.mode == "create"

	local worldDetails = ui:createNode()

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

	worldDetails.onRemove = function(_)
		cancelRequestsTimersAndListeners()
	end

	local content = require("modal"):createContent()

	content.title = config.world.title
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

	local cell = ui:frame({ color = Color(100, 100, 100) })
	cell.Height = 100
	cell:setParent(nil)

	local name
	local editNameBtn
	local by
	local authorBtn
	local author
	local signalBtn
	local likeBtn
	local likes
	local editDescriptionBtn
	local nameArea
	local shape

	local thumbnailArea = ui:frame()
	thumbnailArea:setParent(cell)

	if createMode then
		nameArea = ui:frame()
		nameArea:setParent(worldDetails)

		name = ui:createTextInput("", "World Name?")
		name:setParent(nameArea)
		name.pos = { 0, 0 }

		editNameBtn = ui:buttonNeutral({ content = "✏️" })
		editNameBtn:setParent(nameArea)

		local function focus()
			name:focus()
		end

		local function submit()
			local sanitized, err = api.checkWorldName(name.Text)
			if err == nil then
				local req = systemApi:patchWorld(worldDetails.id, { title = sanitized }, function(err, world)
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
	end

	local creationDate = ui:createText("🌎 published … ago", Color.White, "small")
	creationDate:setParent(cell)

	local updateDate = ui:createText("✨ updated … ago", Color.White, "small")
	updateDate:setParent(cell)

	by = ui:createText("🛠️ created by", Color.White, "small")
	by:setParent(cell)

	if createMode then
		local str = " @" .. Player.Username
		author = ui:createText(str, Color.Green, "small")
		author:setParent(cell)
	else
		authorBtn = ui:buttonNeutral({ content = "@…", textSize = "small" })
		authorBtn:setParent(cell)
	end

	local views = ui:createText("👁 …", Color.White, "small")
	views:setParent(cell)

	local description = ui:createText("description", Color.White, "small")
	description:setParent(cell)

	if config.mode == "explore" then
		signalBtn = ui:buttonSecondary({ content = "⚠️" })
		signalBtn:disable()
		signalBtn:setParent(cell)

		likeBtn = ui:buttonNeutral({ content = "❤️ …", textSize = "small" })
		likeBtn:setParent(cell)
	elseif config.mode == "create" then
		likes = ui:createText("❤️ …", theme.textColor)
		likes:setParent(cell)

		editDescriptionBtn = ui:createButton("✏️")
		editDescriptionBtn:setParent(cell)
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
						if text == "" then
							description.empty = true
							description.Text = "Worlds are easier to find with a description!"
							description.Color = theme.textColorSecondary
							local req = systemApi:patchWorld(world.id, { description = "" }, function(_, _)
								-- not handling response yet
							end)
							table.insert(requests, req)
						else
							description.empty = false
							description.Text = text
							description.Color = theme.textColor
							local req = systemApi:patchWorld(world.id, { description = text }, function(_, _)
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

	local scroll = ui:createScroll({
		backgroundColor = Color(255, 0, 0),
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
	scroll:setParent(worldDetails)

	-- refreshes UI with what's in local config.world / world
	privateFields.refreshWorld = function()
		if shape then
			shape:remove()
			shape = nil
		end

		if world.thumbnail ~= nil then
			thumbnailArea:setImage(world.thumbnail)
		end

		if name ~= nil then
			name.Text = world.title or ""
		end

		if config.mode == "create" then
			if world.description == nil or world.description == "" then
				description.empty = true
				description.Text = "Worlds are easier to find with a description!"
				description.Color = theme.textColorSecondary
			else
				description.Text = world.description
				description.Color = theme.textColor
			end
		else
			description.Text = world.description or ""
			description.Color = theme.textColor
		end

		if likes then
			likes.Text = "❤️ " .. (world.likes and math.floor(world.likes) or 0)
		elseif likeBtn then
			likeBtn.Text = "❤️ " .. (world.likes and math.floor(world.likes) or 0)

			likeBtn.onRelease = function()
				world.liked = not world.liked

				if world.liked == true then
					world.likes = world.likes ~= nil and world.likes + 1 or 1
				else
					world.likes = world.likes ~= nil and world.likes - 1 or 0
				end

				if likeRequest then
					likeRequest:Cancel()
				end
				likeRequest = systemApi:likeWorld(world.id, world.liked, function(_)
					-- TODO: this request should return the refreshed number of likes
				end)
				table.insert(requests, likeRequest)

				if world.liked then
					likeBtn:setColor(theme.colorPositive)
				else
					likeBtn:setColor(theme.buttonColor)
				end

				local nbLikes = (world.likes and math.floor(world.likes) or 0)

				likeBtn.Text = "❤️ " .. nbLikes

				likeBtn.pos.X = thumbnailArea.pos.X + thumbnailArea.Width - likeBtn.Width
				print("SET VIEW POS (4)")
				-- views.pos.X = thumbnailArea.pos.X + thumbnailArea.Width - likeBtn.Width - views.Width - theme.padding
			end
		end

		-- views.Text = "👁 " .. (world.views and math.floor(world.views) or 0)
		-- views.Text = "TEST"

		if world.created then
			local n, unitType = time.ago(world.created)
			if n == 1 then
				unitType = unitType:sub(1, #unitType - 1)
			end
			if math.floor(n) == n then
				creationDate.Text = string.format("🌎 published %d %s ago", math.floor(n), unitType)
			else
				creationDate.Text = string.format("🌎 published %.1f %s ago", n, unitType)
			end
		end

		if world.updated then
			local n, unitType = time.ago(world.updated)
			if n == 1 then
				unitType = unitType:sub(1, #unitType - 1)
			end
			if math.floor(n) == n then
				updateDate.Text = string.format("✨ updated %d %s ago", math.floor(n), unitType)
			else
				updateDate.Text = string.format("✨ updated %.1f %s ago", n, unitType)
			end
		end

		local t = 0
		local listener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
			t = t + dt
			if shape ~= nil then
				shape.pivot.LocalRotation.Y = t
			end
		end)
		table.insert(listeners, listener)

		if shape ~= nil then
			shape.pivot.Rotation = Number3(-0.1, -math.pi * 0.2, -0.2)
			shape:setParent(worldDetails)
		end

		-- update author text/button
		if author then
			author.Text = " @" .. (world.authorName or "…")
		elseif authorBtn and world.authorName then
			authorBtn.Text = "@" .. world.authorName
			authorBtn.onRelease = function(_)
				local profileConfig = {
					isLocal = false,
					username = world.authorName,
					userID = world.authorId,
					uikit = ui,
				}
				local profileContent = require("profile"):create(profileConfig)
				content:push(profileContent)
			end
		end

		print("WORLD TITLE:", world.title)
		content.title = world.title or "…"

		-- update description text
		if description ~= nil then
			description.Text = world.description or ""
		end

		-- update views label
		-- views.Text = "👁 " .. (world.views and math.floor(world.views) or 0)
		-- views.Text = "TEST 2"

		-- update like button
		if world.liked ~= nil then
			if likeBtn ~= nil and likeBtn.setColor ~= nil then
				if world.liked then
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

		privateFields:scheduleRefresh()
		-- worldDetails:refresh()
	end

	-- send request to gather world information
	privateFields.loadWorld = function()
		local req = api:getWorld(world.id, {
			"authorName",
			"authorId",
			"description",
			"liked",
			"likes",
			"views",
			"title",
			"created",
			"updated",
		}, function(worldInfo, err)
			if err ~= nil then
				-- TODO: handle error (retry button?)
				return
			end

			world.authorName = worldInfo.authorName
			world.authorId = worldInfo.authorId
			world.description = worldInfo.description
			world.title = worldInfo.title
			world.liked = worldInfo.liked
			world.likes = worldInfo.likes
			world.views = worldInfo.views
			world.created = worldInfo.created
			world.updated = worldInfo.updated

			privateFields:refreshWorld()
		end)
		table.insert(requests, req)

		if world.thumbnail == nil then
			local req = api:getWorldThumbnail(world.id, function(thumbnail, err)
				if err ~= nil then
					return
				end
				world.thumbnail = thumbnail

				privateFields:refreshWorld()
			end)
			table.insert(requests, req)
		end
	end

	local w = 400
	local h = 400

	privateFields.scheduleRefresh = function()
		if refreshTimer ~= nil then
			return
		end
		refreshTimer = Timer(0.01, function()
			refreshTimer = nil
			worldDetails:refresh()
		end)
	end

	worldDetails._width = function(_)
		return w
	end

	worldDetails._height = function(_)
		return h
	end

	worldDetails._setWidth = function(_, v)
		w = v
		privateFields:scheduleRefresh()
	end

	worldDetails._setHeight = function(_, v)
		h = v
		privateFields:scheduleRefresh()
	end

	worldDetails.refresh = function(self)
		if world.thumbnail ~= nil then
			if shape ~= nil then
				shape:remove()
				shape = nil
			end
			thumbnailArea:setImage(world.thumbnail)
		end

		local createMode = config.mode == "create"

		local padding = theme.padding
		local width = self.Width - padding * 2

		thumbnailArea.Width = 200
		thumbnailArea.Height = 200

		description.object.MaxWidth = width

		local likes = likes or likeBtn
		local viewAndLikesWidth = views.Width + padding + likes.Width
		local viewAndLikesHeight = math.max(views.Height, likes.Height)

		local author = author or authorBtn
		local byAuthorHeight = math.max(by.Height, author.Height)

		local contentHeight = thumbnailArea.Height
			+ viewAndLikesHeight
			+ byAuthorHeight
			+ creationDate.Height
			+ updateDate.Height
			+ description.Height
			+ padding * 5
		cell.Height = contentHeight
		cell.Width = width

		local y = contentHeight - thumbnailArea.Height

		thumbnailArea.pos.X = width * 0.5 - thumbnailArea.Width * 0.5
		thumbnailArea.pos.Y = y

		-- view and likes
		y = y - padding - viewAndLikesHeight * 0.5
		views.pos = { width * 0.5 - viewAndLikesWidth * 0.5, y - views.Height * 0.5 }
		likes.pos = { views.pos.X + views.Width + padding, y - likes.Height * 0.5 }
		y = y - viewAndLikesHeight * 0.5

		-- author
		y = y - padding - byAuthorHeight * 0.5
		by.pos = { 0, y - by.Height * 0.5 }
		authorBtn.pos = { by.pos.X + by.Width + padding, y - author.Height * 0.5 }
		y = y - byAuthorHeight * 0.5

		y = y - padding - creationDate.Height
		creationDate.pos = { 0, y }

		y = y - padding - updateDate.Height
		updateDate.pos = { 0, y }

		y = y - padding - description.Height
		description.pos = { 0, y }

		scroll.Width = self.Width
		scroll.Height = self.Height
		scroll:flush()
		scroll:refresh()

		if true then
			return
		end

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

		thumbnailArea.Width = previewSize
		thumbnailArea.Height = previewSize

		thumbnailArea.LocalPosition.X = self.Width - thumbnailArea.Width
		thumbnailArea.LocalPosition.Y = self.Height - thumbnailArea.Height

		if shape ~= nil then
			shape.Width = thumbnailArea.Width
			shape.Height = thumbnailArea.Height
			shape.LocalPosition = thumbnailArea.LocalPosition
		end

		if likeBtn then
			likeBtn.LocalPosition.X = thumbnailArea.LocalPosition.X + thumbnailArea.Width - likeBtn.Width
			likeBtn.LocalPosition.Y = thumbnailArea.LocalPosition.Y - likeBtn.Height - theme.padding
			print("SET VIEW POS (1)")
			-- views.pos.X = thumbnailArea.pos.X + thumbnailArea.Width - likeBtn.Width - views.Width - theme.padding
			-- views.pos.Y = likeBtn.pos.Y + likeBtn.Height * 0.5 - views.Height * 0.5
		end

		if likes then
			likes.pos.X = thumbnailArea.pos.X + thumbnailArea.Width - likes.Width
			likes.pos.Y = thumbnailArea.pos.Y - likes.Height - theme.padding
			print("SET VIEW POS (2)")
			-- views.pos.X = thumbnailArea.pos.X + thumbnailArea.Width - likes.Width - views.Width - theme.padding
			-- views.pos.Y = likes.pos.Y + likes.Height * 0.5 - views.Height * 0.5
		end

		if signalBtn then
			signalBtn.LocalPosition.X = thumbnailArea.LocalPosition.X
			signalBtn.LocalPosition.Y = thumbnailArea.LocalPosition.Y - signalBtn.Height - theme.padding
		end

		if createMode then
			nameArea.Width = detailsWidth
			nameArea.Height = name.Height

			editNameBtn.Width = name.Height
			editNameBtn.Height = name.Height

			name.Width = nameArea.Width - editNameBtn.Width
			editNameBtn.pos.X = nameArea.Width - editNameBtn.Width

			nameArea.LocalPosition = { 0, self.Height - nameArea.Height, 0 }

			infoArea.Height = by.Height + creationDate.Height + updateDate.Height + theme.padding * 4
		else
			infoArea.Height = authorBtn.Height + creationDate.Height + updateDate.Height + theme.padding * 4
		end
		infoArea.Width = detailsWidth

		if createMode then
			infoArea.LocalPosition = nameArea.LocalPosition - { 0, infoArea.Height + theme.padding, 0 }
			descriptionArea.Height = availableHeight - nameArea.Height - infoArea.Height - theme.padding * 2
		else
			infoArea.LocalPosition = { 0, self.Height - infoArea.Height, 0 }
			descriptionArea.Height = availableHeight - infoArea.Height - theme.padding * 2
		end

		descriptionArea.Width = detailsWidth
		descriptionArea.LocalPosition = infoArea.LocalPosition - { 0, descriptionArea.Height + theme.padding, 0 }

		if editDescriptionBtn ~= nil then
			editDescriptionBtn.pos = {
				descriptionArea.Width - editDescriptionBtn.Width - theme.padding,
				descriptionArea.Height - editDescriptionBtn.Height - theme.padding,
				0,
			}

			description.object.MaxWidth = descriptionArea.Width - editDescriptionBtn.Width - theme.padding * 3
		else
			description.object.MaxWidth = descriptionArea.Width - theme.padding * 2
		end

		description.LocalPosition.Y = descriptionArea.Height - description.Height - theme.padding
	end

	privateFields:refreshWorld()
	privateFields:loadWorld()

	return content
end

return worldDetailsMod
