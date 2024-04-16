creations = {}

creations.createModalContent = function(_, config)
	local itemGrid = require("item_grid")
	local itemDetails = require("item_details")
	local worldDetails = require("world_details")
	local pages = require("pages")
	local theme = require("uitheme").current
	local modal = require("modal")
	local api = require("system_api", System)
	local gridNeedRefresh = false

	-- default config
	local _config = {
		uikit = require("uikit"), -- allows to provide specific instance of uikit
		onOpen = nil,
	}

	if config then
		for k, v in pairs(_config) do
			if type(config[k]) == type(v) then
				_config[k] = config[k]
			end
		end
		_config.onOpen = config.onOpen
	end

	local ui = _config.uikit

	local functions = {}

	-- if original isn't nil, it means we're duplicating an entity
	-- original: name of copied entity
	-- grid parameter is used to force content reload after item creation
	functions.createNewContent = function(what, original, grid, originalCategory)
		local newContent = modal:createContent()

		if what == "item" or what == "wearable" then
			if original then
				newContent.title = "Duplicate Item"
			else
				newContent.title = "New Item"
			end
		else
			newContent.title = "New World"
		end

		newContent.icon = "✨"

		local node = ui:createNode()

		local categories = { "null" }
		local categoryShapes = { "official.one_cube_template" }
		local buttonLabels = { "✨ Create Item ⚔️" }
		local inputLabel = "Item Name?"

		local textWithEmptyInput =
			"An Item needs a name, coders will use it as a reference within world scripts. Choose wisely, it cannot be changed!"

		if what == "wearable" and original == nil then
			categories = { "hair", "jacket", "pants", "boots" }
			categoryShapes = {
				"official.hair_template",
				"official.jacket_template",
				"official.pants_template",
				"official.shoes_template",
			}
			buttonLabels = {
				"✨ Create Hair 🙂",
				"✨ Create Jacket 👕",
				"✨ Create Pants 👖",
				"✨ Create Shoes 👞",
			}
		elseif what == "world" then
			categories = { "null" }
			categoryShapes = { "official.world_icon" }
			buttonLabels = { "✨ Create World 🌎" }
			inputLabel = "World Name?"
			textWithEmptyInput = "A World needs a name! No pressure, this can be changed later on."
		end

		local currentCategory = 1

		local btnCreate
		if original == nil then
			btnCreate = ui:createButton(buttonLabels[1])
		else
			btnCreate = ui:createButton("✨ Duplicate 📑")
		end
		btnCreate:setColor(theme.colorPositive)
		newContent.bottomCenter = { btnCreate }

		local templatePreview =
			ui:createShape(System.ShapeFromBundle(categoryShapes[currentCategory]), { spherized = true })
		templatePreview:setParent(node)

		templatePreview.pivot.LocalRotation = { -0.1, 0, -0.2 }
		templatePreview.object.dt = 0
		templatePreview.object.Tick = function(o, dt)
			o.dt = o.dt + dt
			if templatePreview.pivot ~= nil then
				templatePreview.pivot.LocalRotation = { -0.1, o.dt, -0.2 }
			end
		end

		if original then
			Object:Load(original, function(shape)
				if shape and templatePreview.setShape then
					templatePreview:setShape(shape)
				end
			end)
		end

		local nextTemplateBtn
		local previousTemplateBtn

		local input = ui:createTextInput("", inputLabel)
		input:setParent(node)

		local text = ui:createText(textWithEmptyInput, theme.textColor)
		text:setParent(node)

		if #categories > 1 then
			nextTemplateBtn = ui:createButton("➡️")
			nextTemplateBtn:setParent(node)
			nextTemplateBtn:setColor(theme.buttonColorSecondary)
			nextTemplateBtn.onRelease = function()
				currentCategory = currentCategory + 1
				if currentCategory > #categories then
					currentCategory = 1
				end
				local label = buttonLabels[currentCategory]
				btnCreate.Text = label

				text.Text = textWithEmptyInput
				text.Color = theme.textColor
				text.pos = { node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0 }

				templatePreview:setShape(System.ShapeFromBundle(categoryShapes[currentCategory]))
			end

			previousTemplateBtn = ui:createButton("⬅️")
			previousTemplateBtn:setParent(node)
			previousTemplateBtn:setColor(theme.buttonColorSecondary)
			previousTemplateBtn.onRelease = function()
				currentCategory = currentCategory - 1
				if currentCategory < 1 then
					currentCategory = #categories
				end
				local label = buttonLabels[currentCategory]
				btnCreate.Text = label

				text.Text = textWithEmptyInput
				text.Color = theme.textColor
				text.pos = { node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0 }

				templatePreview:setShape(System.ShapeFromBundle(categoryShapes[currentCategory]))
			end
		end

		btnCreate.onRelease = function()
			local sanitized
			local err

			if what == "world" then
				sanitized, err = api.checkWorldName(input.Text)
				if err ~= nil then
					text.Text = "❌ " .. err
					text.Color = theme.colorNegative
					text.pos = { node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0 }
					return
				end
			else
				sanitized, err = api.checkItemName(input.Text)
				if err ~= nil then
					text.Text = "❌ " .. err
					text.Color = theme.colorNegative
					text.pos = { node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0 }
					return
				end
			end

			btnCreate:disable()
			input:disable()

			text.Text = "Creating..."
			text.Color = theme.textColor
			text.pos = { node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0 }

			local newCategory = categories[currentCategory]
			if originalCategory then
				newCategory = originalCategory
			end
			if newCategory == "null" then
				newCategory = nil
			end

			if what == "world" then
				api:createWorld({ title = sanitized, category = newCategory, original = original }, function(err, world)
					if err ~= nil then
						text.Text = "❌ Sorry, there's been an error."
						text.Color = theme.colorNegative
						text.pos =
							{ node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0 }

						btnCreate:enable()
						input:enable()
					else
						-- forces grid to refresh when coming back
						if grid ~= nil then
							grid.needsToRefreshEntries = true
						end

						local worldDetailsContent =
							worldDetails:create({ mode = "create", title = world.title, uikit = ui })

						local cell = {}

						cell.id = world.id
						cell.title = world.title
						cell.description = ""
						cell.created = world.created
						cell.item = { shape = System.ShapeFromBundle("official.world_icon") }

						worldDetailsContent:loadCell(cell)

						local btnEditCode = ui:createButton("🤓 Code", { textSize = "default" })
						btnEditCode.onRelease = function()
							System.EditWorldCode(cell.id)
						end

						local btnEdit = ui:createButton("✏️ Edit", { textSize = "big" })
						btnEdit:setColor(theme.colorCreate)
						btnEdit.onRelease = function()
							System.EditWorld(cell.id)
						end

						worldDetailsContent.bottomRight = { btnEdit, btnEditCode }

						worldDetailsContent.idealReducedContentSize = function(content, width, height)
							content.Width = width
							content.Height = height
							return Number2(content.Width, content.Height)
						end

						newContent:pushAndRemoveSelf(worldDetailsContent)
					end
				end)
			else
				api:createItem({ name = sanitized, category = newCategory, original = original }, function(err, item)
					if err ~= nil then
						if err.statusCode == 409 then
							text.Text = "❌ You already have an item with that name!"
						else
							-- print(err.message, err.statusCode)
							text.Text = "❌ Sorry, there's been an error."
						end
						text.Color = theme.colorNegative
						text.pos =
							{ node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0 }

						btnCreate:enable()
						input:enable()
					else
						-- forces grid to refresh when coming back
						if grid ~= nil then
							grid.needsToRefreshEntries = true
						end

						local itemFullName = item.repo .. "." .. item.name
						-- local category = cell.category

						local itemDetailsContent = itemDetails:createModalContent({ mode = "create", uikit = ui })

						local cell = {}

						cell.id = item.id
						cell.name = item.name
						cell.repo = item.repo
						cell.description = ""
						cell.itemFullName = itemFullName
						cell.created = item.created

						itemDetailsContent:loadCell(cell)

						local btnEdit = ui:createButton("✏️ Edit", { textSize = "big" })
						btnEdit:setColor(theme.colorCreate)
						btnEdit.onRelease = function()
							System.LaunchItemEditor(itemFullName, newCategory)
						end

						local btnDuplicate = ui:createButton("📑 Duplicate", { textSize = "default" })
						btnDuplicate.onRelease = function()
							-- no need to pass grid, it's already marked
							-- for refresh at this point
							local m = itemDetailsContent:getModalIfContentIsActive()
							if m ~= nil then
								local what
								if newCategory == nil then
									what = "item"
								else
									what = "wearable"
								end
								m:push(functions.createNewContent(what, itemFullName, nil, newCategory))
							end
						end

						-- itemDetailsContent.bottomCenter = {btnDuplicate, btnEdit}
						itemDetailsContent.bottomRight = { btnEdit }
						itemDetailsContent.bottomLeft = { btnDuplicate }

						itemDetailsContent.idealReducedContentSize = function(content, width, height)
							content.Width = width
							content.Height = height
							return Number2(content.Width, content.Height)
						end

						newContent:pushAndRemoveSelf(itemDetailsContent)
					end
				end) -- api:createItem
			end -- end if world/item
		end

		input.onTextChange = function(self)
			local name = self.Text

			if name == "" then
				text.Text = textWithEmptyInput
				text.Color = theme.textColor
			else
				if what == "world" then
					local sanitized, err = api.checkWorldName(name)
					if err ~= nil then
						text.Text = "❌ " .. err
						text.Color = theme.colorNegative
					else
						text.Text = "✅ " .. sanitized
						text.Color = theme.colorPositive
					end
				else
					local slug, err = api.checkItemName(name, Player.Username)
					if err ~= nil then
						text.Text = "❌ " .. err
						text.Color = theme.colorNegative
					else
						text.Text = "✅ " .. slug
						text.Color = theme.colorPositive
					end
				end
			end
			text.pos = { node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0 }
		end

		node._w = 300
		node._h = 300
		node._width = function(self)
			return self._w
		end
		node._height = function(self)
			return self._h
		end

		node._setWidth = function(self, v)
			self._w = v
		end
		node._setHeight = function(self, v)
			self._h = v
		end

		newContent.node = node

		node.refresh = function(self)
			local extraBottomPadding = input.Height
			text.object.MaxWidth = (self.Width - theme.padding * 2)
			input.Width = self.Width

			local availableHeightForPreview = self.Height
				- text.Height
				- input.Height
				- theme.padding * 2
				- extraBottomPadding
			local availableWidthForPreview = self.Width
			if #categories > 1 then
				availableWidthForPreview = availableWidthForPreview
					- previousTemplateBtn.Width
					- nextTemplateBtn.Width
					- theme.padding * 2
			end

			local availableSizeForPreview = math.min(200, availableHeightForPreview, availableWidthForPreview)

			self.Height = availableSizeForPreview + input.Height + text.Height + theme.padding * 2 + extraBottomPadding

			templatePreview.Height = availableSizeForPreview
			templatePreview.pos =
				{ self.Width * 0.5 - templatePreview.Width * 0.5, self.Height - templatePreview.Height, 0 }
			if #categories > 1 then
				previousTemplateBtn.Height = templatePreview.Height
				nextTemplateBtn.Height = templatePreview.Height

				previousTemplateBtn.pos = { 0, self.Height - templatePreview.Height, 0 }
				nextTemplateBtn.pos =
					{ self.Width - previousTemplateBtn.Width, self.Height - templatePreview.Height, 0 }
			end

			input.pos =
				{ self.Width * 0.5 - input.Width * 0.5, templatePreview.pos.Y - input.Height - theme.padding, 0 }
			text.pos = { self.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0 }
		end

		newContent.idealReducedContentSize = function(content, width, height)
			content.Width = math.min(600, width)
			content.Height = math.min(500, height)
			content:refresh()
			return Number2(content.Width, content.Height)
		end

		input:focus()

		return newContent
	end

	local createCreationsContent = function()
		local creationsContent = modal:createContent()
		creationsContent.title = "Creations"
		creationsContent.icon = "🏗️"

		local grid = itemGrid:create({ minBlocks = 1, repo = Player.Username, categories = { "null" }, uikit = ui })

		creationsContent.node = grid

		creationsContent.willResignActive = function(_)
			grid:cancelRequestsAndTimers()
		end

		creationsContent.didBecomeActive = function(_)
			if gridNeedRefresh then
				-- re-download grid content
				if grid.getItems then
					grid:getItems()
				end
				gridNeedRefresh = false
			else
				-- simply display the grid (same content)
				if grid.refresh then
					grid:refresh()
				end
			end
		end

		local pages = pages:create(ui)
		creationsContent.bottomCenter = { pages }

		local btnNew = ui:createButton("✨ New ⚔️")
		btnNew:setColor(theme.colorPositive)
		creationsContent.bottomRight = { btnNew }

		local newItem = function()
			local m = creationsContent:getModalIfContentIsActive()
			if m ~= nil then
				m:push(functions.createNewContent("item", nil, grid))
			end
		end

		local newWearable = function()
			local m = creationsContent:getModalIfContentIsActive()
			if m ~= nil then
				m:push(functions.createNewContent("wearable", nil, grid))
			end
		end

		local newWorld = function()
			local m = creationsContent:getModalIfContentIsActive()
			if m ~= nil then
				m:push(functions.createNewContent("world", nil, grid))
			end
		end

		btnNew.onRelease = newItem

		creationsContent.tabs = {
			{
				label = "⚔️ Items",
				short = "⚔️",
				action = function()
					grid:setCategories({ "null" }, "items")
					btnNew.Text = "✨ New ⚔️"
					btnNew.onRelease = newItem
				end,
			},
			{
				label = "👕 Wearables",
				short = "👕",
				action = function()
					grid:setCategories({ "hair", "jacket", "pants", "boots" }, "items")
					btnNew.Text = "✨ New 👕"
					btnNew.onRelease = newWearable
				end,
			},
			{
				label = "🌎 Worlds",
				short = "🌎",
				action = function()
					grid:setCategories({ "null" }, "worlds")
					btnNew.Text = "✨ New 🌎"
					btnNew.onRelease = newWorld
				end,
			},
		}

		grid.onPaginationChange = function(page, nbPages)
			pages:setNbPages(nbPages)
			pages:setPage(page)
		end

		pages:setPageDidChange(function(page)
			grid:setPage(page)
		end)

		creationsContent.node = grid

		creationsContent.idealReducedContentSize = function(content, width, height)
			local grid = content
			grid.Width = width
			grid.Height = height
			grid:refresh()
			return Number2(grid.Width, grid.Height)
		end

		grid.onOpen = function(_, cell)
			if config.onOpen then
				config.onOpen(creationsContent, cell)
				return
			end
			if cell.type == "item" then
				local itemFullName = cell.itemFullName
				local category = cell.category

				local itemDetailsContent = itemDetails:createModalContent({ mode = "create", uikit = ui })
				itemDetailsContent:loadCell(cell)

				local btnEdit = ui:createButton("✏️ Edit", { textSize = "big" })
				btnEdit:setColor(theme.colorCreate)
				btnEdit.onRelease = function()
					System.LaunchItemEditor(itemFullName, category)
				end

				local btnDuplicate = ui:createButton("📑 Duplicate", { textSize = "default" })
				btnDuplicate.onRelease = function()
					local m = itemDetailsContent:getModalIfContentIsActive()
					if m ~= nil then
						local what
						if category == nil then
							what = "item"
						else
							what = "wearable"
						end
						m:push(functions.createNewContent(what, itemFullName, grid, category))
					end
				end

				local btnExport = ui:createButton("📤", { textSize = "default" })
				btnExport.onRelease = function()
					File:ExportItem(cell.repo, cell.name, "vox", function(err, message)
						if err then
							print("Error: " .. message)
							return
						end
					end)
				end

				local btnArchive = ui:createButton("🗑️", { textSize = "default" })
				btnArchive.onRelease = function()
					local str = "Are you sure you want to archive this item?"
					local positive = function()
						local data = { archived = true }
						api:patchItem(cell.id, data, function(err, itm)
							if err or not itm.archived then
								require("menu"):ShowAlert({ message = "Could not archive item" }, System)
								return
							end
							itemDetailsContent:pop()
							grid:getItems()
						end)
					end
					local negative = function() end
					local alertConfig = {
						message = str,
						positiveLabel = "Yes",
						positiveCallback = positive,
						negativeLabel = "No",
						negativeCallback = negative,
					}

					require("menu"):ShowAlert(alertConfig, System)
				end

				itemDetailsContent.bottomLeft = { btnDuplicate, btnExport, btnArchive }
				itemDetailsContent.bottomRight = { btnEdit }

				itemDetailsContent.idealReducedContentSize = function(content, width, height)
					content.Width = width
					content.Height = height
					return Number2(content.Width, content.Height)
				end

				local m = creationsContent:getModalIfContentIsActive()
				if m ~= nil then
					m:push(itemDetailsContent)
				end
			elseif cell.type == "world" then
				local worldDetailsContent = worldDetails:create({ mode = "create", title = cell.title, uikit = ui })
				worldDetailsContent.onContentUpdate = function(updatedWorld)
					gridNeedRefresh = true
					worldDetailsContent.title = updatedWorld.title
					if worldDetailsContent.refreshModal then
						worldDetailsContent:refreshModal()
					end
				end

				worldDetailsContent:loadCell(cell)

				local btnEditCode = ui:createButton("🤓 Code", { textSize = "default" })
				btnEditCode.onRelease = function()
					System.EditWorldCode(cell.id)
				end

				local btnEdit = ui:createButton("✏️ Edit", { textSize = "big" })
				btnEdit:setColor(theme.colorCreate)
				btnEdit.onRelease = function()
					System.EditWorld(cell.id)
				end

				worldDetailsContent.bottomRight = { btnEdit, btnEditCode }

				worldDetailsContent.idealReducedContentSize = function(content, width, height)
					content.Width = width
					content.Height = height
					return Number2(content.Width, content.Height)
				end

				local m = creationsContent:getModalIfContentIsActive()
				if m ~= nil then
					m:push(worldDetailsContent)
				end
			end
		end

		return creationsContent
	end

	return createCreationsContent()
end

creations.createModal = function(_, config)
	local modal = require("modal")
	local ui = config.ui or require("uikit")
	local ease = require("ease")
	local theme = require("uitheme").current
	local MODAL_MARGIN = theme.paddingBig -- space around modals

	-- TODO: handle this correctly
	local topBarHeight = 50

	local content = modal:createContent()

	local creationsContent = creations:createModalContent({ uikit = ui, onOpen = config.onOpen })

	creationsContent.idealReducedContentSize = function(content, width, height)
		local grid = content
		grid.Width = width
		grid.Height = height -- - content.pages.Height - theme.padding
		grid:refresh() -- affects width and height (possibly reducing it)
		return Number2(grid.Width, grid.Height)
	end

	function maxModalWidth()
		local computed = Screen.Width - Screen.SafeArea.Left - Screen.SafeArea.Right - MODAL_MARGIN * 2
		local max = Screen.Width * 0.8
		local w = math.min(max, computed)
		return w
	end

	function maxModalHeight()
		return (Screen.Height - Screen.SafeArea.Bottom - topBarHeight - MODAL_MARGIN * 2) * 0.95
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

	content:pushAndRemoveSelf(creationsContent)

	return currentModal, creationsContent
end

return creations
