local avatarEditor = {} 

-- avatar editor always occupies max width,
-- updating modal size to fit height.
avatarEditor.create = function(self, maxWidth, maxHeight, position, config)

	local ui = require("uikit")
	local modal = require("modal")
	local theme = require("uitheme").current
	local __equipments = require("equipments")
	local api = require("api")
	local itemgrid = require("item_grid")
    local avatar = require("avatar")
    local pages = require("pages")

    local savedEyesColor = avatar:getEyesColor(Player)
    local savedNoseColor = avatar:getNoseColor(Player)
    local savedMouthColor = avatar:getMouthColor(Player)

    local func = {}

    func.createTopLevelMenu = function()
    	local topLevelMenu = modal:createContent()
    	local node = ui:createNode()
		topLevelMenu.node = node
		topLevelMenu.icon = "😬"
		topLevelMenu.title = "Avatar"

		topLevelMenu.idealReducedContentSize = function(content, width, height)
			return Number2(content.Width, content.Height)
		end

		local faceBtn = ui:createButton("😬 Face")
		faceBtn:setParent(node)
		faceBtn.onRelease = function()
			topLevelMenu.modal:push(func.createFaceMenu())
		end

		local outfitBtn = ui:createButton("👤 Outfit")
		outfitBtn:setParent(node)
		outfitBtn.onRelease = function()
			topLevelMenu.modal:push(func.createOutfitMenu())
		end

		local pictureBtn = ui:createButton("📸 Take picture!")
		pictureBtn:setParent(node)

		pictureBtn.onRelease = function()
			local as = AudioSource()
			as.Sound = "gun_reload_1"
			as:SetParent(World)
			as.Volume = 0.5
		    as.Pitch = 1
		    as.Spatialized = false
		    as:Play()
			Timer(1, function() as:RemoveFromParent() as=nil end)

			local whiteBg = ui:createFrame(Color.White)
			whiteBg.Width = Screen.Width
			whiteBg.Height = Screen.Height

			Timer(0.05, function()
				whiteBg:remove()
				whiteBg = nil

				ui.rootFrame:SetParent(nil)
				Timer(0.2, function()
					-- setting unused layer to hide everything
					-- Camera.On = false didn't work, because the next
					-- visible camera is force to render on the whole surface
					Camera.Layers = 7
					Clouds.On = false
					Screen:Capture(Player.Username)
					Clouds.On = true
					Camera.Layers = 1
					ui.rootFrame:SetParent(World)
				end)
			end)
		end

		node._width = function(self)
			-- faceBtn.Width = nil outfitBtn.Width = nil pictureBtn.Width = nil
			-- local w = math.max(math.max(faceBtn.Width, outfitBtn.Width), pictureBtn.Width)
			local max = math.min(300, maxWidth())
			local w = max - theme.padding * 2
			faceBtn.Width = w outfitBtn.Width = w pictureBtn.Width = w
			return w
		end

		node._height = function(self)
			return faceBtn.Height + outfitBtn.Height + pictureBtn.Height + theme.padding * 2
		end

		node.parentDidResize = function(self)
			outfitBtn.pos = pictureBtn.pos + {0, pictureBtn.Height + theme.padding, 0}
			faceBtn.pos = outfitBtn.pos + {0, outfitBtn.Height + theme.padding, 0}
		end

		return topLevelMenu
    end

    func.createFaceMenu = function()
    	local faceMenu = modal:createContent()
    	local node = ui:createNode()
		faceMenu.node = node
		faceMenu.icon = "🙂"
		faceMenu.title = "Face"

		faceMenu.idealReducedContentSize = function(content, width, height)
			return Number2(content.Width, content.Height)
		end

		local eyesPickerButton = ui:createButton("🎨")
	
		local nosePickerButton = ui:createButton("🎨")
		local noseShapeButton = ui:createButton("shape")

		local mouthPickerButton = ui:createButton("🎨")
		local mouthShapeButton = ui:createButton("shape")

		local skinLabel = ui:createText("👤 Skin", theme.textColor)
		skinLabel:setParent(node)

		local skinButtons = {}
		for _,colors in ipairs(avatar.skinColors) do
			local btn = ui:createButton("")
			btn:setParent(node)
			btn:setColor(colors.skin1)
			btn.onRelease = function()
				local data = {}
				data.skinColor = { r=colors.skin1.R, g=colors.skin1.G, b=colors.skin1.B }
				data.skinColor2 = { r=colors.skin2.R, g=colors.skin2.G, b=colors.skin2.B }
				data.noseColor = { r=colors.nose.R, g=colors.nose.G, b=colors.nose.B }
				data.mouthColor = { r=colors.mouth.R, g=colors.mouth.G, b=colors.mouth.B }
				api.updateAvatar(data, function(err, success)
					if err then
						print(err)
					end
				end)
				avatar:setSkinColor(Player, colors.skin1, colors.skin2, colors.nose, colors.mouth)
				nosePickerButton:setColor(colors.nose)
				mouthPickerButton:setColor(colors.mouth)
			end
			table.insert(skinButtons, btn)
		end

		local eyesLabel = ui:createText("👁️ Eyes", theme.textColor)
		eyesLabel:setParent(node)

		local eyesButtons = {}
		for _,color in ipairs(avatar.eyesColors) do
			local btn = ui:createButton("")
			btn:setParent(node)
			btn:setColor(color)
			btn.onRelease = function()
				avatar:setEyesColor(Player, color)
				eyesPickerButton:setColor(color)
				local data = {}
	            data.eyesColor = { r=color.R, g=color.G, b=color.B }
	            api.updateAvatar(data, function(err, success)
					if err then
						print(err)
					end
				end)
			end
			table.insert(eyesButtons, btn)
		end

		eyesPickerButton:setParent(node)
		eyesPickerButton:setColor(avatar:getEyesColor(Player))
		eyesPickerButton.onRelease = function(self)
			savedEyesColor = avatar:getEyesColor(Player)
			local colorPickerMenu = func.createColorPickerMenu()
			colorPickerMenu.picker.didPickColor = function(self, c)
				avatar:setEyesColor(Player, c)
				eyesPickerButton:setColor(c)
				local data = {}
				data.eyesColor = { r=c.R, g=c.G, b=c.B }
				api.updateAvatar(data, function(err, success)
					if err then
						print(err)
					end
				end)
			end
			faceMenu.modal:push(colorPickerMenu)
		end

		local noseLabel = ui:createText("👃 Nose", theme.textColor)
		noseLabel:setParent(node)

		noseShapeButton:setParent(node)
		noseShapeButton:disable()

		nosePickerButton:setParent(node)
		nosePickerButton:setColor(avatar:getNoseColor(Player))
		nosePickerButton.onRelease = function(self)
			savedNoseColor = avatar:getNoseColor(Player)
			local colorPickerMenu = func.createColorPickerMenu()
			colorPickerMenu.picker.didPickColor = function(self, c)
				avatar:setNoseColor(Player, c)
				nosePickerButton:setColor(c)
				local data = {}
	            data.noseColor = { r=c.R, g=c.G, b=c.B }
	            api.updateAvatar(data, function(err, success)
					if err then
						print(err)
					end
				end)
			end
			faceMenu.modal:push(colorPickerMenu)
		end

		local mouthLabel = ui:createText("👄 Mouth", theme.textColor)
		mouthLabel:setParent(node)

		mouthShapeButton:setParent(node)
		mouthShapeButton:disable()

		mouthPickerButton:setParent(node)
		mouthPickerButton:setColor(avatar:getMouthColor(Player))
		mouthPickerButton.onRelease = function(self)
			savedMouthColor = avatar:getMouthColor(Player)
			local colorPickerMenu = func.createColorPickerMenu()
			colorPickerMenu.picker.didPickColor = function(self, c)
				avatar:setMouthColor(Player, c)
				mouthPickerButton:setColor(c)
				local data = {}
	            data.mouthColor = { r=c.R, g=c.G, b=c.B }
	            api.updateAvatar(data, function(err, success)
					if err then
						print(err)
					end
				end)
			end
			faceMenu.modal:push(colorPickerMenu)
		end

		node._width = function(self)
			local max = math.min(400, maxWidth())
			local w = max - theme.padding * 2
			return w
		end

		node._height = function(self)
			local lineHeight = skinButtons[1].Height
			return lineHeight * 4 + theme.padding * 3
		end

		node.parentDidResize = function(self)
			local lineHeight = skinButtons[1].Height

			mouthLabel.pos = {0, lineHeight * 0.5 - mouthLabel.Height * 0.5, 0}
			noseLabel.pos = {0, (lineHeight + theme.padding) * 1 + lineHeight * 0.5 - noseLabel.Height * 0.5, 0}
			eyesLabel.pos = {0, (lineHeight + theme.padding) * 2 + lineHeight * 0.5 - noseLabel.Height * 0.5, 0}
			skinLabel.pos = {0, (lineHeight + theme.padding) * 3 + lineHeight * 0.5 - noseLabel.Height * 0.5, 0}

			local largestLabel = math.max(mouthLabel.Width, noseLabel.Width, eyesLabel.Width, skinLabel.Width)

			local widthWithoutLabels = self.Width - largestLabel
			local skinBtnWidth = widthWithoutLabels
			skinBtnWidth = skinBtnWidth / #skinButtons - theme.padding

			local pos = Number3(largestLabel + theme.padding, (lineHeight + theme.padding) * 3, 0)

			for i, btn in ipairs(skinButtons) do
				btn.Width = skinBtnWidth
				btn.pos = pos
				pos = pos + {skinBtnWidth + theme.padding, 0, 0}
			end

			local widthWithoutLabelsAndBtn = self.Width - largestLabel - theme.padding - eyesPickerButton.Width
			local eyeBtnWidth = widthWithoutLabelsAndBtn
			eyeBtnWidth = eyeBtnWidth / #eyesButtons - theme.padding

			pos = Number3(largestLabel + theme.padding, (lineHeight + theme.padding) * 2, 0)

			for i, btn in ipairs(eyesButtons) do
				btn.Width = eyeBtnWidth
				btn.pos = pos
				pos = pos + {eyeBtnWidth + theme.padding, 0, 0}
			end

			eyesPickerButton.pos = pos

			noseShapeButton.Width = widthWithoutLabels - theme.padding * 2 - nosePickerButton.Width
			noseShapeButton.pos = {largestLabel + theme.padding, (lineHeight + theme.padding) * 1, 0}

			nosePickerButton.pos = noseShapeButton.pos + {noseShapeButton.Width + theme.padding, 0, 0}

			mouthShapeButton.Width = widthWithoutLabels - theme.padding * 2 - mouthPickerButton.Width
			mouthShapeButton.pos = {largestLabel + theme.padding, 0, 0}

			mouthPickerButton.pos = mouthShapeButton.pos + {mouthShapeButton.Width + theme.padding, 0, 0}
		end
		
		return faceMenu
    end

    func.createColorPickerMenu = function()
    	local colorPickerMenu = modal:createContent()
    	local node = ui:createNode()
		colorPickerMenu.node = node
		colorPickerMenu.icon = "🎨"
		colorPickerMenu.title = "Picker"

		colorPickerMenu.idealReducedContentSize = function(content, width, height)
			colorPickerMenu.picker.config.maxWidth = math.min(500, width)
			colorPickerMenu.picker.config.maxHeight = math.min(300, height)
			colorPickerMenu.picker:_refresh()

			return Number2(colorPickerMenu.picker.Width, colorPickerMenu.picker.Height)
		end

		local colorPickerConfig = {
			closeBtnIcon = "✅",
			previewColorInCloseBtn = true,
			transparency = false,
			colorPreview = false,
			colorCode = false,
		}
		local colorPicker = require("colorpicker"):create(colorPickerConfig)
		colorPicker:setColor(avatar:getEyesColor(Player))
		colorPicker.onClose = function()
			local modal = colorPickerMenu:getModalIfContentIsActive()
			if modal then modal:pop() end
		end
		colorPicker:setParent(node)
		colorPickerMenu.picker = colorPicker

		node._width = function(self)
			return colorPicker.Width
		end

		node._height = function(self)
			return colorPicker.Height
		end

    	return colorPickerMenu
    end

    func.createOutfitMenu = function()
    	local outfitMenu = modal:createContent()

    	local selectedCategory = "hair"
    	local grid = itemgrid:create({searchbar = true, categories = {selectedCategory}})
		outfitMenu.node = grid
		outfitMenu.icon = "👤"
		outfitMenu.title = "Outfit"

		outfitMenu.tabs = {
			{
				label = "🙂 Hair",
				short = "🙂",
				action = function()
					selectedCategory = "hair"
					grid:setCategories({selectedCategory})
				end,
			},
			{
				label = "👕 Jacket",
				short = "👕",
				action = function()
					selectedCategory = "jacket"
					grid:setCategories({selectedCategory})
				end,
			},
			{
				label = "👖 Pants",
				short = "👖",
				action = function()
					selectedCategory = "pants"
					grid:setCategories({selectedCategory})
				end,
			},
			{
				label = "👞 Boots",
				short = "👞",
				action = function()
					selectedCategory = "boots"
					grid:setCategories({selectedCategory})
				end,
			}
		}

		outfitMenu.idealReducedContentSize = function(content, width, height)
			local grid = content
			if Screen.Width < Screen.Height then
				height = height * 0.67
			end
			grid.Width = width
			grid.Height = height
			grid:refresh()
			return Number2(grid.Width, grid.Height)
		end

		grid.onOpen = function(_,cell)
			if not cell.repo or not cell.name then return end
			local category = selectedCategory
			local fullname = cell.repo .. "." .. cell.name
			__equipments.load(category, fullname, Player, false, false, function(eq)
				if eq == nil then
					print("Error: invalid item.")
					return
				end
				local data = {}
				data[category] = fullname
				api.updateAvatar(data, function(err, success)
					if err then
						print(err)
					end
				end)
			end)
		end

		local pages = pages:create()
		outfitMenu.bottomCenter = {pages}

		grid.onPaginationChange = function(page, nbPages)
			pages:setNbPages(nbPages)
			pages:setPage(page)
		end

		pages:setPageDidChange(function(page)
			grid:setPage(page)
		end)

    	return outfitMenu
    end

	return modal:create(func.createTopLevelMenu(), maxWidth, maxHeight, position)
end

return avatarEditor