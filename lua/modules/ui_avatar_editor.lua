local mod = {}

ui = require("uikit")
theme = require("uitheme").current
avatar = require("avatar")
itemGrid = require("item_grid")

local MAX_COLOR_SWATCH_SIZE = 100
local PADDING = 4.0
local CELL_PADDING = 4.0
local SCROLL_PADDING = 4.0

privateFields = setmetatable({}, { __mode = "k" })

local avatarProperties = {
	skinColorIndex = avatar.defaultSkinColorIndex,
	noseIndex = avatar.defaultNoseIndex,
	eyesIndex = avatar.defaultEyesIndex,
	eyesColorIndex = avatar.defaultEyesColorIndex,
}

mod.create = function(self, config)
	if self ~= mod then
		error("ui_avatar_editor:create(config) should be called with `:`", 2)
	end

	local defaultConfig = {
		ui = ui, -- can only be used by System to override UI instance
		margin = theme.padding,
		requestHeightCallback = function(_) end, -- height
	}

	local ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config)
	end)
	if not ok then
		error("ui_avatar_editor:create(config) - config error: " .. err, 2)
	end

	local ui = config.ui
	local node = ui:createFrame(Color(0, 0, 0, 0))

	privateFields[node] = {}

	node.onRemove = function(self)
		privateFields[self] = nil
	end

	local refButton = ui:createButton("dummy")
	refButton:setParent(nil)

	local categoryNode
	local categories

	local function setSkin()
		if categoryNode then
			categoryNode:remove()
		end
		categoryNode = ui:createFrame()

		local btns = {}
		for skinColorIndex, color in pairs(avatar.skinColors) do
			local btn = ui:createButton("", {
				color = color.skin1,
			})
			btn.onRelease = function()
				avatarProperties.skinColorIndex = skinColorIndex
				LocalEvent:Send("avatar_editor_update", { skinColorIndex = skinColorIndex })
			end
			btn:setParent(categoryNode)
			table.insert(btns, btn)
		end

		btns[1].parentDidResize = function(self)
			local parent = self.parent
			local half = math.floor(#btns / 2)
			local size = (parent.Width - theme.padding * (half - 1)) / half
			size = math.min(Screen.Height * 0.15, MAX_COLOR_SWATCH_SIZE, size)
			local totalSize = (size + theme.padding) * half - theme.padding
			local startX = parent.Width * 0.5 - totalSize * 0.5
			for i = 1, half do
				btn = btns[i]
				btn.Width = size
				btn.Height = size
				btn.pos = { startX + (i - 1) * (size + theme.padding), btn.Height + theme.padding }
			end
			for i = half + 1, #btns do
				btn = btns[i]
				btn.Width = size
				btn.Height = size
				btn.pos = { startX + (i - half - 1) * (size + theme.padding), 0 }
			end

			config.requestHeightCallback(size * 2 + theme.padding * 2 + categories.Height)
		end

		categoryNode:setParent(node)
		categories:parentDidResize()
		LocalEvent:Send("avatar_editor_should_focus_on_body")
	end

	local btns = {}

	local displayedCategoryIndex = 1

	local function refreshCategoryButtons()
		for _, b in pairs(btns) do
			if b.index == displayedCategoryIndex then
				b:select()
			else
				b:unselect()
			end
		end
	end

	categories = ui:createScroll({
		backgroundColor = theme.buttonTextColor,
		direction = "right",
		cellPadding = CELL_PADDING,
		padding = SCROLL_PADDING,
		loadCell = function(index)
			if index == 1 then
				local btn = ui:buttonNeutral({ content = "🙂 Skin" })
				btn.index = index
				btns[btn.index] = btn
				btn.onRelease = function()
					if displayedCategoryIndex == index then
						return
					end
					displayedCategoryIndex = index
					refreshCategoryButtons()

					setSkin()
				end
				return btn
			elseif index == 2 then
				local btn = ui:buttonNeutral({ content = "✨ Hair" })
				btn.index = index
				btns[btn.index] = btn
				btn.onRelease = function()
					if displayedCategoryIndex == index then
						return
					end
					displayedCategoryIndex = index
					refreshCategoryButtons()

					if categoryNode then
						categoryNode:remove()
					end
					categoryNode = itemGrid:create({
						categories = { "hair" },
						uikit = ui,
						backgroundColor = theme.buttonTextColor,
						cellPadding = CELL_PADDING,
						padding = SCROLL_PADDING,
						onOpen = function(cell)
							LocalEvent:Send("avatar_editor_update", { hair = cell.fullName })
						end,
					})
					categoryNode:setParent(node)
					categories:parentDidResize()

					config.requestHeightCallback(10000)
					LocalEvent:Send("avatar_editor_should_focus_on_head")
				end
				return btn
			elseif index == 3 then
				local btn = ui:buttonNeutral({ content = "🙂 Eyes" })
				btn.index = index
				btns[btn.index] = btn
				btn.onRelease = function()
					if displayedCategoryIndex == index then
						return
					end
					displayedCategoryIndex = index
					refreshCategoryButtons()

					if categoryNode then
						categoryNode:remove()
					end
					categoryNode = ui:createFrame()

					local uiAvatar = require("ui_avatar")
					local btnRatio = 130 / 90
					local headMaskRatio = 190 / 130
					local size = 130

					local btns = {}
					for eyesIndex, _ in pairs(avatar.eyes) do
						-- 13 x 9
						-- 19 x 9 with ears
						local mask = ui:createFrame(Color(0, 0, 0, 0))
						mask.IsMask = true
						mask.Width = size
						mask.Height = size / btnRatio
						mask:setParent(categoryNode)
						local head = uiAvatar:getHead("", size * headMaskRatio, ui, { spherized = false })
						head:setParent(mask)

						head:setEyes({
							index = eyesIndex,
							-- color = avatarModule.eyeColors[math.random(1, #avatarModule.eyeColors)],
						})

						head:setNose({ index = avatarProperties.noseIndex })

						local colors = avatar.skinColors[avatarProperties.skinColorIndex]
						head:setColors({
							skin1 = colors.skin1,
							skin2 = colors.skin2,
							nose = colors.nose,
							mouth = colors.mouth,
						})

						head.pos.X = mask.Width * 0.5 - head.Width * 0.5
						mask.head = head

						local btn = ui:createButton(mask, {
							color = Color(181, 186, 193),
							padding = false,
						})
						btn.onRelease = function()
							avatarProperties.eyesIndex = eyesIndex
							LocalEvent:Send("avatar_editor_update", { eyesIndex = eyesIndex })
						end
						btn:setParent(categoryNode)
						table.insert(btns, btn)
					end

					local colorBtns = {}
					local lastIndex = #avatar.eyeColors
					for eyesColorIndex, color in ipairs(avatar.eyeColors) do
						local btn
						if eyesColorIndex == lastIndex then -- premium feature, not yet implemented
							btn = ui:button({
								content = "🎨",
								color = Color(0, 0, 0, 0.3),
							})
							local premiumBadge = ui:createText("👑", { size = "big" })
							premiumBadge.parentDidResize = function(self)
								local parent = self.parent
								self.pos.X = parent.Width - self.Width - 5
								self.pos.Y = 5
							end
							premiumBadge:setParent(btn)

							btn:disable()
						else
							btn = ui:button({
								content = "",
								color = color,
							})
							btn.onRelease = function()
								-- head:setColors({
								-- 	skin1 = colors.skin1,
								-- 	skin2 = colors.skin2,
								-- 	nose = colors.nose,
								-- 	mouth = colors.mouth,
								-- })
								avatarProperties.eyesColorIndex = eyesColorIndex
								LocalEvent:Send("avatar_editor_update", { eyesColorIndex = eyesColorIndex })
							end
						end

						btn:setParent(categoryNode)
						table.insert(colorBtns, btn)
					end

					btns[1].parentDidResize = function(self)
						local parent = self.parent
						local half = math.floor(#btns / 2)

						local size = (parent.Width - theme.padding * (half - 1)) / half
						size = math.min(Screen.Height * 0.15, MAX_COLOR_SWATCH_SIZE, size)

						local halfColors = math.floor(#colorBtns / 2)
						local colorWidth = (parent.Width - theme.padding * (halfColors - 1)) / halfColors
						local colorHeight = math.min(Screen.Height * 0.15, 50, colorWidth)

						local startYEyeShapes = colorHeight * 2 + theme.padding * 2

						-- TODO: this should be dynamic
						local maskSize = size - 3 * 2 -- 3 = border
						local btnHeight = maskSize / btnRatio + 3 * 2 -- 3 = border

						local totalSize = (size + theme.padding) * half - theme.padding
						local startX = parent.Width * 0.5 - totalSize * 0.5
						for i = 1, half do
							btn = btns[i]
							btn.content.Width = maskSize
							btn.content.Height = maskSize / btnRatio
							btn.content.head.Width = maskSize * headMaskRatio
							btn.content.head.pos.X = btn.content.Width * 0.5 - btn.content.head.Width * 0.5
							btn.pos = {
								startX + (i - 1) * (size + theme.padding),
								startYEyeShapes + btn.Height + theme.padding,
							}
						end
						for i = half + 1, #btns do
							btn = btns[i]
							btn.content.Width = maskSize
							btn.content.Height = maskSize / btnRatio
							btn.content.head.Width = maskSize * headMaskRatio
							btn.content.head.pos.X = btn.content.Width * 0.5 - btn.content.head.Width * 0.5
							btn.pos = { startX + (i - half - 1) * (size + theme.padding), startYEyeShapes }
						end

						totalSize = (colorWidth + theme.padding) * halfColors - theme.padding
						startX = parent.Width * 0.5 - totalSize * 0.5
						for i = 1, halfColors do
							btn = colorBtns[i]
							btn.Width = colorWidth
							btn.Height = colorHeight
							btn.pos = {
								startX + (i - 1) * (colorWidth + theme.padding),
								btn.Height + theme.padding,
							}
						end
						for i = halfColors + 1, #colorBtns do
							btn = colorBtns[i]
							btn.Width = colorWidth
							btn.Height = colorHeight
							btn.pos = { startX + (i - halfColors - 1) * (colorWidth + theme.padding), 0 }
						end

						config.requestHeightCallback(
							colorHeight * 2 + btnHeight * 2 + theme.padding * 4 + categories.Height
						)
					end

					categoryNode:setParent(node)
					categories:parentDidResize()
					LocalEvent:Send("avatar_editor_should_focus_on_eyes")
				end
				return btn
			-- elseif index == 4 then
			-- 	local btn = ui:createButton("✨ Ears")
			-- 	btn:disable()
			-- 	return btn
			elseif index == 4 then
				local btn = ui:buttonNeutral({ content = "👃 Nose" })
				btn.index = index
				btns[btn.index] = btn
				btn.onRelease = function()
					if displayedCategoryIndex == index then
						return
					end
					displayedCategoryIndex = index
					refreshCategoryButtons()

					if categoryNode then
						categoryNode:remove()
					end
					categoryNode = ui:createFrame()

					local uiAvatar = require("ui_avatar")
					local btnRatio = 130 / 90
					local headMaskRatio = 190 / 130
					local size = 130

					local btns = {}
					for noseIndex, _ in pairs(avatar.noses) do
						-- 13 x 9
						-- 19 x 9 with ears
						local mask = ui:createFrame(Color(0, 0, 0, 0))
						mask.IsMask = true
						mask.Width = size
						mask.Height = size / btnRatio
						mask:setParent(categoryNode)
						local head = uiAvatar:getHead("", size * headMaskRatio, ui, { spherized = false })
						head:setParent(mask)

						head:setEyes({
							index = avatarProperties.eyesIndex,
							-- color = avatarModule.eyeColors[math.random(1, #avatarModule.eyeColors)],
						})

						head:setNose({ index = noseIndex })

						local colors = avatar.skinColors[avatarProperties.skinColorIndex]
						head:setColors({
							skin1 = colors.skin1,
							skin2 = colors.skin2,
							nose = colors.nose,
							mouth = colors.mouth,
						})

						head.pos.X = mask.Width * 0.5 - head.Width * 0.5
						mask.head = head

						local btn = ui:createButton(mask, {
							color = Color(181, 186, 193),
							padding = false,
						})
						btn.onRelease = function()
							avatarProperties.noseIndex = noseIndex
							LocalEvent:Send("avatar_editor_update", { noseIndex = noseIndex })
						end
						btn:setParent(categoryNode)
						table.insert(btns, btn)
					end

					btns[1].parentDidResize = function(self)
						local parent = self.parent
						local half = math.floor(#btns / 2)
						local size = (parent.Width - theme.padding * (half - 1)) / half
						size = math.min(MAX_COLOR_SWATCH_SIZE, size)

						local maskSize = size - 3 * 2 -- 3 = border
						local btnHeight = maskSize / btnRatio + 3 * 2 -- 3 = border

						local totalSize = (size + theme.padding) * half - theme.padding
						local startX = parent.Width * 0.5 - totalSize * 0.5
						for i = 1, half do
							btn = btns[i]
							btn.content.Width = maskSize
							btn.content.Height = maskSize / btnRatio
							btn.content.head.Width = maskSize * headMaskRatio
							btn.content.head.pos.X = btn.content.Width * 0.5 - btn.content.head.Width * 0.5
							-- btn.Width = size
							-- btn.Height = size
							btn.pos = { startX + (i - 1) * (size + theme.padding), btn.Height + theme.padding }
						end
						for i = half + 1, #btns do
							btn = btns[i]
							btn.content.Width = maskSize
							btn.content.Height = maskSize / btnRatio
							btn.content.head.Width = maskSize * headMaskRatio
							btn.content.head.pos.X = btn.content.Width * 0.5 - btn.content.head.Width * 0.5
							-- btn.Width = size
							-- btn.Height = size
							btn.pos = { startX + (i - half - 1) * (size + theme.padding), 0 }
						end

						config.requestHeightCallback(btnHeight * 2 + theme.padding * 2 + categories.Height)
					end

					categoryNode:setParent(node)
					categories:parentDidResize()
					LocalEvent:Send("avatar_editor_should_focus_on_nose")
				end
				return btn
			-- elseif index == 6 then
			-- 	local btn = ui:createButton("👕 Shirt")
			-- 	btn:disable()
			-- 	return btn
			elseif index == 5 then
				local btn = ui:buttonNeutral({ content = "👕 Jacket" })
				btn.index = index
				btns[btn.index] = btn
				btn.onRelease = function()
					if displayedCategoryIndex == index then
						return
					end
					displayedCategoryIndex = index
					refreshCategoryButtons()

					if categoryNode then
						categoryNode:remove()
					end
					categoryNode = itemGrid:create({
						categories = { "jacket" },
						uikit = ui,
						onOpen = function(cell)
							LocalEvent:Send("avatar_editor_update", { jacket = cell.fullName })
						end,
					})
					categoryNode:setParent(node)
					categories:parentDidResize()

					config.requestHeightCallback(10000)
					LocalEvent:Send("avatar_editor_should_focus_on_body")
				end
				return btn
			elseif index == 6 then
				local btn = ui:buttonNeutral({ content = "👖 Pants" })
				btn.index = index
				btns[btn.index] = btn
				btn.onRelease = function()
					if displayedCategoryIndex == index then
						return
					end
					displayedCategoryIndex = index
					refreshCategoryButtons()

					if categoryNode then
						categoryNode:remove()
					end
					categoryNode = itemGrid:create({
						categories = { "pants" },
						uikit = ui,
						onOpen = function(cell)
							LocalEvent:Send("avatar_editor_update", { pants = cell.fullName })
						end,
					})
					categoryNode:setParent(node)
					categories:parentDidResize()

					config.requestHeightCallback(10000)
					LocalEvent:Send("avatar_editor_should_focus_on_body")
				end
				return btn
			elseif index == 7 then
				local btn = ui:buttonNeutral({ content = "👞 Shoes" })
				btn.index = index
				btns[btn.index] = btn
				btn.onRelease = function()
					if displayedCategoryIndex == index then
						return
					end
					displayedCategoryIndex = index
					refreshCategoryButtons()

					if categoryNode then
						categoryNode:remove()
					end
					categoryNode = itemGrid:create({
						categories = { "boots" },
						uikit = ui,
						onOpen = function(cell)
							LocalEvent:Send("avatar_editor_update", { boots = cell.fullName })
						end,
					})
					categoryNode:setParent(node)
					categories:parentDidResize()

					config.requestHeightCallback(10000)
					LocalEvent:Send("avatar_editor_should_focus_on_body")
				end
				return btn
				-- elseif index == 10 then
				-- 	local btn = ui:createButton("✨ Gloves")
				-- 	btn:disable()
				-- 	return btn
				-- elseif index == 11 then
				-- 	local btn = ui:createButton("🎒 Backpack")
				-- 	btn:disable()
				-- 	return btn
			end
			return nil
		end,
		unloadCell = function(_, cell)
			-- print("UNLOAD", index)
			cell:remove()
		end,
	})

	categories.parentDidResize = function(self)
		local parent = self.parent
		categories.Width = parent.Width
		categories.Height = refButton.Height + SCROLL_PADDING * 2
		categories.pos.Y = parent.Height - categories.Height

		if categoryNode then
			categoryNode.Width = parent.Width
			categoryNode.Height = parent.Height - categories.Height - PADDING
			categoryNode.pos = { 0, 0 }

			if categoryNode.getItems then
				categoryNode:getItems()
			end
		end
	end

	categories:setParent(node)
	refreshCategoryButtons()

	setSkin()

	return node
end

return mod
