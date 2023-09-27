
creations = {}

creations.createModalContent = function(self, config)

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
	}

	if config then
		for k, v in pairs(_config) do
			if type(config[k]) == type(v) then _config[k] = config[k] end
		end
	end

	local ui = _config.uikit

	-- if original isn't nil, it means we're duplicating an entity
	-- original: name of copied entity
	-- grid parameter is used to force content reload after item creation
	local createNewContent = function(what, original, grid)
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

		local categories = {"null"} 
		local categoryShapes = {"official.one_cube_template"}
		local buttonLabels = {"✨ Create Item ⚔️"}
		local inputLabel = "Item Name?"

		local textWithEmptyInput = "An Item needs a name, coders will use it as a reference within world scripts. Choose wisely, it cannot be changed!"

		if what == "wearable" and original == nil then
			categories = {"hair", "jacket", "pants", "boots"}
			categoryShapes = {"official.hair_template", "official.jacket_template", "official.pants_template", "official.shoes_template"}
			buttonLabels = {
							"✨ Create Hair 🙂",
							"✨ Create Jacket 👕",
							"✨ Create Pants 👖",
							"✨ Create Shoes 👞"
							}
		elseif what == "world" then
			categories = {"null"} 
			categoryShapes = {"official.world_icon"}
			buttonLabels = {"✨ Create World 🌎"}
			inputLabel = "World Name?"
			textWithEmptyInput = "A World needs a name! No pressure, this can be changed later on."
		end

		local btnLabelDuplicate = ""

		local currentCategory = 1

		local btnCreate
		if original == nil then
			btnCreate = ui:createButton(buttonLabels[1])
		else
			btnCreate = ui:createButton("✨ Duplicate 📑")
		end
		btnCreate:setColor(theme.colorPositive)
		newContent.bottomCenter = {btnCreate}

		local templatePreview = ui:createShape(System.ShapeFromBundle(categoryShapes[currentCategory]), {spherized = true})
		templatePreview:setParent(node)

		templatePreview.pivot.LocalRotation = {-0.1,0,-0.2}
		templatePreview.object.dt = 0
		templatePreview.object.Tick = function(o, dt)
			o.dt = o.dt + dt
			if templatePreview.pivot ~= nil then
				templatePreview.pivot.LocalRotation = {-0.1,o.dt,-0.2}
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
				if currentCategory > #categories then currentCategory = 1 end
				local category = categories[currentCategory]
				local label = buttonLabels[currentCategory]
				btnCreate.Text = label

				text.Text = textWithEmptyInput
				text.Color = theme.textColor
				text.pos = {node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0}

				templatePreview:setShape(System.ShapeFromBundle(categoryShapes[currentCategory]))
			end

			previousTemplateBtn = ui:createButton("⬅️")
			previousTemplateBtn:setParent(node)
			previousTemplateBtn:setColor(theme.buttonColorSecondary)
			previousTemplateBtn.onRelease = function()
				currentCategory = currentCategory -1
				if currentCategory < 1 then currentCategory = #categories end
				local category = categories[currentCategory]
				local label = buttonLabels[currentCategory]
				btnCreate.Text = label

				text.Text = textWithEmptyInput
				text.Color = theme.textColor
				text.pos = {node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0}

				templatePreview:setShape(System.ShapeFromBundle(categoryShapes[currentCategory]))
			end
		end

		btnCreate.onRelease = function()

			local sanitized = ""
			local err = nil

			if what == "world" then
				sanitized, err = api.checkWorldName(input.Text)
				if err ~= nil then
					text.Text = "❌ " .. err
					text.Color = theme.colorNegative
					text.pos = {node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0}
					return
				end
			else
				sanitized, err = api.checkItemName(input.Text)
				if err ~= nil then
					text.Text = "❌ " .. err
					text.Color = theme.colorNegative
					text.pos = {node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0}
					return
				end
			end

			btnCreate:disable()
			input:disable()

			text.Text = "Creating..."
			text.Color = theme.textColor
			text.pos = {node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0}

			local category = categories[currentCategory]
			if category == "null" then category = nil end

			local _category = category
			if original ~= nil then _category = nil end

			if what == "world" then

				api:createWorld({title = sanitized, category = _category, original = original}, function(err, world)
					if err ~= nil then
						text.Text = "❌ Sorry, there's been an error."
						text.Color = theme.colorNegative
						text.pos = {node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0}

						btnCreate:enable()
						input:enable()
					else
						-- forces grid to refresh when coming back
						if grid ~= nil then grid.needsToRefreshEntries = true end

						local worldDetailsContent = worldDetails:create({mode = "create", title = world.title, uikit = ui })

						local cell = {}

						cell.id = world.id
						cell.title = world.title
						cell.description = ""
						cell.created = world.created
						cell.item = {shape = System.ShapeFromBundle("official.world_icon")}

						worldDetailsContent:loadCell(cell)

						local btnEditCode = ui:createButton("🤓 Code", {textSize="default"})
						btnEditCode.onRelease = function()
							System.EditWorldCode(cell.id)
						end

						local btnEdit = ui:createButton("✏️ Edit", {textSize="big"})
						btnEdit:setColor(theme.colorCreate)
						btnEdit.onRelease = function()
							System.EditWorld(cell.id)
						end

						worldDetailsContent.bottomRight = {btnEdit, btnEditCode}

						worldDetailsContent.idealReducedContentSize = function(content, width, height)
							content.Width = width
							content.Height = height
							return Number2(content.Width, content.Height)
						end

						newContent:pushAndRemoveSelf(worldDetailsContent)
					end

				end)

			else
				api:createItem({name = sanitized, category = _category, original = original}, function(err, item)
					if err ~= nil then
						if err.statusCode == 409 then
							text.Text = "❌ You already have an item with that name!"
						else
							-- print(err.message, err.statusCode)
							text.Text = "❌ Sorry, there's been an error."
						end
						text.Color = theme.colorNegative
						text.pos = {node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0}

						btnCreate:enable()
						input:enable()
					else
						-- forces grid to refresh when coming back
						if grid ~= nil then grid.needsToRefreshEntries = true end

						local itemFullName = item.repo .. "." .. item.name
						-- local category = cell.category

						local itemDetailsContent = itemDetails:createModalContent({mode = "create", uikit = ui})

						local cell = {}

						cell.id = item.id
						cell.name = item.name
						cell.repo = item.repo
						cell.description = ""
						cell.itemFullName = itemFullName
						cell.created = item.created

                        itemDetailsContent:loadCell(cell)

						local btnEdit = ui:createButton("✏️ Edit", {textSize="big"})
						btnEdit:setColor(theme.colorCreate)
						btnEdit.onRelease = function()
							System.LaunchItemEditor(itemFullName, category)
						end

						local btnDuplicate = ui:createButton("📑 Duplicate", {textSize="default"})
						btnDuplicate.onRelease = function()
							-- no need to pass grid, it's already marked
							-- for refresh at this point
							local m = itemDetailsContent:getModalIfContentIsActive()
							if m ~= nil then
								m:push(createNewContent("item", itemFullName))
							end
						end

						-- itemDetailsContent.bottomCenter = {btnDuplicate, btnEdit}
						itemDetailsContent.bottomRight = {btnEdit}
						itemDetailsContent.bottomLeft = {btnDuplicate}

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
			text.pos = {node.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0}
		end

		node._w = 300
		node._h = 300
		node._width = function(self) return self._w end
		node._height = function(self) return self._h end

		node._setWidth = function(self, v) self._w = v end
		node._setHeight = function(self, v) self._h = v end

		newContent.node = node

		node.refresh = function(self)
			local extraBottomPadding = input.Height
			text.object.MaxWidth = (self.Width - theme.padding * 2)
			input.Width = self.Width

			local availableHeightForPreview = self.Height - text.Height - input.Height - theme.padding * 2 - extraBottomPadding
			local availableWidthForPreview = self.Width
			if #categories > 1 then
				availableWidthForPreview = availableWidthForPreview - previousTemplateBtn.Width - nextTemplateBtn.Width - theme.padding * 2
			end

			local availableSizeForPreview = math.min(200, availableHeightForPreview, availableWidthForPreview)

			self.Height = availableSizeForPreview + input.Height + text.Height + theme.padding * 2 + extraBottomPadding

			templatePreview.Height = availableSizeForPreview
			templatePreview.pos = {self.Width * 0.5 - templatePreview.Width * 0.5, self.Height - templatePreview.Height, 0}			

			if #categories > 1 then
				previousTemplateBtn.Height = templatePreview.Height
				nextTemplateBtn.Height = templatePreview.Height

				previousTemplateBtn.pos = {0, self.Height - templatePreview.Height, 0}
				nextTemplateBtn.pos = {self.Width - previousTemplateBtn.Width, self.Height - templatePreview.Height, 0}
			end

			input.pos = {self.Width * 0.5 - input.Width * 0.5, templatePreview.pos.Y - input.Height - theme.padding, 0}
			text.pos = {self.Width * 0.5 - text.Width * 0.5, input.pos.Y - text.Height - theme.paddingBig, 0}
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

		local grid = itemGrid:create({	minBlocks = 1, 
										repo = Player.Username, 
										categories = {"null"},
										uikit = ui,
									})

		creationsContent.node = grid

		creationsContent.willResignActive = function(self)
			grid:cancelRequestsAndTimers()
		end

		creationsContent.didBecomeActive = function(self)
			if gridNeedRefresh then
				-- re-download grid content
				if grid.getItems then grid:getItems() end
				gridNeedRefresh = false
			else
				-- simply display the grid (same content)
				if grid.refresh then grid:refresh() end
			end
		end

		local pages = pages:create(ui)
		creationsContent.bottomCenter = {pages}

		local btnNew = ui:createButton("✨ New ⚔️")
		btnNew:setColor(theme.colorPositive)
		creationsContent.bottomRight = {btnNew}

		local newItem = function()
			local m = creationsContent:getModalIfContentIsActive()
			if m ~= nil then
				m:push(createNewContent("item", nil, grid))
			end
		end

		local newWearable = function()
			local m = creationsContent:getModalIfContentIsActive()
			if m ~= nil then
				m:push(createNewContent("wearable", nil, grid))
			end
		end

		local newWorld = function()
			local m = creationsContent:getModalIfContentIsActive()
			if m ~= nil then
				m:push(createNewContent("world", nil, grid))
			end
		end

		btnNew.onRelease = newItem

		creationsContent.tabs = {
			{
				label = "⚔️ Items",
				short = "⚔️",
				action = function()
					grid:setCategories({"null"}, "items")
					btnNew.Text = "✨ New ⚔️"
					btnNew.onRelease = newItem
				end,
			},
			{
				label = "👕 Wearables",
				short = "👕",
				action = function()
					grid:setCategories({"hair", "jacket", "pants", "boots"}, "items")
					btnNew.Text = "✨ New 👕"
					btnNew.onRelease = newWearable
				end,
			},
			{
				label = "🌎 Worlds",
				short = "🌎",
				action = function()
					grid:setCategories({"null"}, "worlds")
					btnNew.Text = "✨ New 🌎"
					btnNew.onRelease = newWorld
				end,
			}
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

		grid.onOpen = function(self, cell)

			if cell.type == "item" then

				local itemFullName = cell.itemFullName
				local category = cell.category

				local itemDetailsContent = itemDetails:createModalContent({mode = "create", uikit = ui})
                itemDetailsContent:loadCell(cell)

				local btnEdit = ui:createButton("✏️ Edit", {textSize="big"})
				btnEdit:setColor(theme.colorCreate)
				btnEdit.onRelease = function()
					System.LaunchItemEditor(itemFullName, category)
				end

				local btnDuplicate = ui:createButton("📑 Duplicate", {textSize="default"})
				btnDuplicate.onRelease = function()
					local m = itemDetailsContent:getModalIfContentIsActive()
					if m ~= nil then
						m:push(createNewContent("item", itemFullName, grid))
					end
				end

				local btnExport = ui:createButton("📤", {textSize="default"})
				btnExport.onRelease = function()
					File:ExportItem(cell.repo, cell.name, "vox", function(err, message)
						if err then
							print("Error: " .. message)
							return
						end
					end)
				end

				--itemDetailsContent.bottomCenter = {btnDuplicate, btnEdit, btnExport}
				itemDetailsContent.bottomLeft = {btnDuplicate, btnExport}
				itemDetailsContent.bottomRight = {btnEdit}

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

				local worldDetailsContent = worldDetails:create({mode = "create", title = cell.title, uikit = ui})
				worldDetailsContent.onContentUpdate = function(updatedWorld)
					gridNeedRefresh = true
					worldDetailsContent.title = updatedWorld.title
					if worldDetailsContent.refreshModal then worldDetailsContent:refreshModal() end
				end

				worldDetailsContent:loadCell(cell)

				local btnEditCode = ui:createButton("🤓 Code", {textSize="default"})
				btnEditCode.onRelease = function()
					System.EditWorldCode(cell.id)
				end

				local btnEdit = ui:createButton("✏️ Edit", {textSize="big"})
				btnEdit:setColor(theme.colorCreate)
				btnEdit.onRelease = function()
					System.EditWorld(cell.id)
				end

				worldDetailsContent.bottomRight = {btnEdit, btnEditCode}

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

	local createPickCategoryContent = function()
		local pickCategoryContent = modal:createContent()
		pickCategoryContent.title = "Create"
		pickCategoryContent.icon = "🏗️"

		local node = ui:createNode()

		local label = ui:createText("What do you want to create?", theme.textColor)
		label:setParent(node)

		local itemButton = ui:createButton("⚔️ Item", {textSize="big"})
		itemButton:setParent(node)
		local wearableButton = ui:createButton("👕 Wearable", {textSize="big"})
		wearableButton:setParent(node)
		local worldButton = ui:createButton("🌎 World", {textSize="big"})
		worldButton:setParent(node)

		local itemShape = ui:createShape(System.ShapeFromBundle("official.one_cube_template"), {spherized = true})
		itemShape:setParent(node)

		local wearableShape = ui:createShape(System.ShapeFromBundle("official.jacket_template"), {spherized = true})
		wearableShape:setParent(node)

		local worldShape = ui:createShape(System.ShapeFromBundle("official.world_icon"), {spherized = true})
		worldShape:setParent(node)

		itemShape.pivot.Rotation = Number3(-0.1,-math.pi * 0.2,-0.2)
		wearableShape.pivot.Rotation = Number3(-0.1,-math.pi * 0.2,-0.2)
		worldShape.pivot.Rotation = Number3(-0.1,-math.pi * 0.2,-0.2)

		itemShape.object.dt = 0
		itemShape.object.Tick = function(o, dt)
			o.dt = o.dt + dt
			if itemShape.pivot ~= nil then
				itemShape.pivot.LocalRotation.Y = o.dt
			end
			if wearableShape.pivot ~= nil then
				wearableShape.pivot.LocalRotation.Y = o.dt
			end
			if worldShape.pivot ~= nil then
				worldShape.pivot.LocalRotation.Y = o.dt
			end
		end

		node._w = 300
		node._h = 300
		node._width = function(self) return self._w end
		node._height = function(self) return self._h end

		node._setWidth = function(self, v) self._w = v end
		node._setHeight = function(self, v) self._h = v end

		pickCategoryContent.node = node

		node.refresh = function(self)
			if self.Width < self.Height then -- portrait
				local btnWidth = self.Width

				local remainingHeightForShapes = self.Height - itemButton.Height * 3 - label.Height - theme.padding * 6
				local shapeHeight = math.min(remainingHeightForShapes / 3, btnWidth)

				self.Height = itemButton.Height * 3 + shapeHeight * 3 + label.Height + theme.padding * 6

				label.pos = {self.Width * 0.5 - label.Width * 0.5, self.Height - label.Height, 0}

				itemButton.Width = btnWidth
				wearableButton.Width = btnWidth
				worldButton.Width = btnWidth

				itemShape.Height = shapeHeight
				itemShape.pos = {0, label.pos.Y - itemShape.Height - theme.padding, 0}

				itemButton.pos = itemShape.pos - {0, itemButton.Height + theme.padding, 0}

				wearableShape.Height = shapeHeight
				wearableShape.pos = itemButton.pos - {0, wearableShape.Height + theme.padding, 0}

				wearableButton.pos = wearableShape.pos - {0, wearableButton.Height + theme.padding, 0}

				worldShape.Height = shapeHeight
				worldShape.pos = wearableButton.pos - {0, worldShape.Height + theme.padding, 0}

				worldButton.pos = worldShape.pos - {0, worldButton.Height + theme.padding, 0}

				itemShape.pos.X = self.Width * 0.5 - itemShape.Width * 0.5
				wearableShape.pos.X = self.Width * 0.5 - wearableShape.Width * 0.5
				worldShape.pos.X = self.Width * 0.5 - worldShape.Width * 0.5

			else -- landscape
				local btnWidth = (self.Width - theme.padding * 2) / 3

				self.Height = itemButton.Height + theme.padding + btnWidth + theme.padding + label.Height

				label.pos = {self.Width * 0.5 - label.Width * 0.5, self.Height - label.Height, 0}

				itemButton.Width = btnWidth
				wearableButton.Width = btnWidth
				worldButton.Width = btnWidth

				itemButton.pos = {0,0,0}
				wearableButton.pos = {self.Width * 0.5 - wearableButton.Width * 0.5,0,0}
				worldButton.pos = {self.Width - worldButton.Width,0,0}

				itemShape.Width = btnWidth
				-- itemShape.Height = btnWidth
				itemShape.pos = itemButton.pos + {0, itemButton.Height + theme.padding, 0}

				wearableShape.Width = btnWidth
				-- wearableShape.Height = btnWidth
				wearableShape.pos = wearableButton.pos + {0, wearableButton.Height + theme.padding, 0}

				worldShape.Width = btnWidth
				-- worldShape.Height = btnWidth
				worldShape.pos = worldButton.pos + {0, worldButton.Height + theme.padding, 0}
			end
		end

		pickCategoryContent.idealReducedContentSize = function(content, width, height)
			content.Width = width
			content.Height = height
			content:refresh()
			return Number2(content.Width, content.Height)
		end

		return pickCategoryContent
	end

	return createCreationsContent()
end

return creations
