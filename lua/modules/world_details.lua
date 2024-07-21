mod = {}

mod.createModalContent = function(_, config)
	local time = require("time")
	local theme = require("uitheme").current
	local systemApi = require("system_api", System)
	local api = require("api")

	local defaultConfig = {
		world = {
			id = "",
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
		error("worldDetails:createModalContent(config) - config error: " .. err, 2)
	end

	local ui = config.uikit

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

	local btnLaunch = ui:buttonPositive({ content = "Start", textSize = "big", padding = 10 })
	btnLaunch.onRelease = function()
		URL:Open("https://app.cu.bzh?worldID=" .. world.id)
	end
	btnLaunch:setParent(worldDetails)

	-- TODO: only display servers button if multiplayer
	local btnServers = ui:buttonNeutral({ content = "Servers", textSize = "default" })
	btnServers.onRelease = function()
		local config = { worldID = world.id, title = world.title, uikit = ui }
		local list = require("server_list"):create(config)
		content:push(list)
	end
	btnServers:setParent(worldDetails)

	local cell = ui:frame() -- { color = Color(100, 100, 100) }
	cell.Height = 100
	cell:setParent(nil)

	local name
	local editNameBtn
	local by
	local authorBtn
	local author
	local likeBtn
	local likes
	local editDescriptionBtn
	local nameArea
	local description
	local views
	local creationDate
	local updateDate

	local thumbnailRatio = 16 / 9

	local thumbnailArea = ui:frame({ color = Color(20, 20, 22) })
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

	local secondaryTextColor = Color(150, 150, 150)

	creationDate = ui:createText("🌎 published … ago", secondaryTextColor, "small")
	creationDate:setParent(cell)

	updateDate = ui:createText("✨ updated … ago", secondaryTextColor, "small")
	updateDate:setParent(cell)

	by = ui:createText("🛠️ created by", secondaryTextColor, "small")
	by:setParent(cell)

	if createMode then
		local str = " @" .. Player.Username
		author = ui:createText(str, Color.Green, "small")
		author:setParent(cell)
	else
		authorBtn = ui:buttonLink({ content = "@…", textSize = "small" })
		authorBtn:setParent(cell)
	end

	views = ui:createText("👁 …", secondaryTextColor, "small")
	views:setParent(cell)

	description = ui:createText("description", Color.White, "small")
	description:setParent(cell)

	if createMode then
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
	scroll:setParent(worldDetails)

	-- refreshes UI with what's in local config.world / world
	privateFields.refreshWorld = function()
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

				privateFields.alignViewsAndLikes()
			end
		end

		views.Text = "👁 " .. (world.views and math.floor(world.views) or 0)

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

		-- update author text/button
		if author then
			author.Text = " @" .. (world.authorName or "…")
		elseif authorBtn and world.authorName then
			authorBtn.Text = "@" .. world.authorName
			authorBtn.onRelease = function(_)
				local profileConfig = {
					username = world.authorName,
					userID = world.authorId,
					uikit = ui,
				}
				local profileContent = require("profile"):create(profileConfig)
				content:push(profileContent)
			end
		end

		content.title = world.title or "…"

		-- update description text
		if description ~= nil then
			description.Text = world.description or ""
		end

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

		worldDetails:refresh()
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

	privateFields.alignViewsAndLikes = function()
		local likes = likes or likeBtn
		local parent = likes.parent
		if parent == nil then
			return
		end
		local viewAndLikesWidth = views.Width + theme.padding + likes.Width
		views.pos.X = parent.Width * 0.5 - viewAndLikesWidth * 0.5
		likes.pos.X = views.pos.X + views.Width + theme.padding
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
			thumbnailArea:setImage(world.thumbnail)
		end

		-- local createMode = config.mode == "create"

		local padding = theme.padding
		local width = self.Width - padding * 2

		local thumbnailHeight = self.Height * 0.3
		local thumbnailWidth = thumbnailHeight * thumbnailRatio
		if thumbnailWidth > width then
			thumbnailWidth = width
			thumbnailHeight = thumbnailWidth * 1.0 / thumbnailRatio
		end

		thumbnailArea.Width = thumbnailWidth
		thumbnailArea.Height = thumbnailHeight

		description.object.MaxWidth = width

		local likes = likes or likeBtn
		local viewAndLikesHeight = math.max(views.Height, likes.Height)

		local author = author or authorBtn
		local singleLineHeight = math.max(by.Height, author.Height)

		local contentHeight = thumbnailArea.Height
			+ padding
			+ viewAndLikesHeight -- views and likes
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

		local y = contentHeight - thumbnailArea.Height

		thumbnailArea.pos.X = width * 0.5 - thumbnailArea.Width * 0.5
		thumbnailArea.pos.Y = y

		-- view and likes
		y = y - padding - viewAndLikesHeight * 0.5
		views.pos.Y = y - views.Height * 0.5
		likes.pos.Y = y - likes.Height * 0.5
		privateFields.alignViewsAndLikes()
		y = y - viewAndLikesHeight * 0.5

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
		scroll.Height = self.Height - btnLaunch.Height - padding * 2

		local bottomButtonsWidth = btnServers.Width + padding + btnLaunch.Width

		btnServers.pos = {
			width * 0.5 - bottomButtonsWidth * 0.5,
			padding + btnLaunch.Height * 0.5 - btnServers.Height * 0.5,
		}
		btnLaunch.pos = { btnServers.pos.X + btnServers.Width + padding, padding }
		scroll.pos.Y = btnLaunch.pos.Y + btnLaunch.Height + padding

		scroll:flush()
		scroll:refresh()
	end

	privateFields:refreshWorld()
	privateFields:loadWorld()

	return content
end

return mod
