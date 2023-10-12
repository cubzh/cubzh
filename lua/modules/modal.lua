--[[
wip_modal module handles the "Work in Progress" modal.
]]--

local modal = {}

local modalContentMT = {
	__index = function(t,k)
		if k == "cleanup" then
			return function(self)
				self._attr.modal = nil
				for _, element in ipairs(self.topLeft) do if element.remove then element:remove() end end
				for _, element in ipairs(self.topCenter) do if element.remove then element:remove() end end
				for _, element in ipairs(self.bottomLeft) do if element.remove then element:remove() end end
				for _, element in ipairs(self.bottomCenter) do if element.remove then element:remove() end end
				for _, element in ipairs(self.bottomRight) do if element.remove then element:remove() end end
				if self.node ~= nil and self.node.remove then
					self.node:remove()
					self.node = nil
				end

				-- go through attr not to trigger __newindex
				local attr = t._attr
				if attr ~= nil then
					attr.topLeft = {}
					attr.topCenter = {}
					attr.bottomLeft = {}
					attr.bottomCenter = {}
					attr.bottomRight = {}
				end

				self.title = nil
				self.icon = nil
				self.idealReducedContentSize = nil
				self.tabs = {}
			end
		elseif k == "modal" then
			error("modalContent.modal is private")
			return nil -- modal is not exposed
		end
		return t._attr[k]
	end,
	__newindex = function(t,k,v)
		local attr = t._attr

		if 	k == "topLeft" or k == "topCenter" or
			k == "bottomLeft" or k == "bottomCenter" or k == "bottomRight" then
			if type(v) ~= "table" then error("modalContent." .. k .. " can only be a table", 2) end

			local elements = attr[k]
			local ok, err
			for _, element in ipairs(elements) do
				ok, err = pcall(function()
					element:remove()
				end)
				if ok == false then
					print("⚠️ modal: can't remove " .. k .. " element", err)
				end
			end

			for _, element in ipairs(v) do
				element.contentDidResize = function(_)
					local modal = t:getModalIfContentIsActive()
					if modal then
						modal:refreshContent(true) -- schedule
					end
				end
			end

			attr[k] = v

			local modal = t:getModalIfContentIsActive()
			if modal ~= nil then modal:refreshContent() end

		elseif k == "modal" then
			-- attr[k] = v
			error("modalContent.modal is not settable")
		else
			rawset(t,k,v)
		end
	end,
	__gc = function(t)
		t:cleanup()
		for k, _ in pairs(t._attr) do t._attr[k] = nil end
		for k, _ in pairs(t) do t[k] = nil end
	end,
}

modal.createContent = function(_)

	-- modalContent describes content modals can load
	-- pushing content into a modal automatically manages
	-- navigation (back buttons)
	local modalContent = {
		--
		isModalContent = true,

		-- icon can be an emoji (string), automatically centered (padding)
		-- and considered as first topLeft element
		icon = nil,

		-- title can be a string, it's automatically centered
		-- considered as first topCenter element
		title = nil,

		-- closeButton is displayed by default, set to false to hide it
		closeButton = true,

		-- each tab should be of this form:
		-- {label = "🙂 label", short = "🙂", action = function() print("tab pressed") end}
		tabs = {},

		node = nil, -- central uikit node

		-- function triggered when computing content layout,
		-- giving it a chance to shrink for better display.
		-- (used to better fit grids for example)
		-- The callback receives the size that's about to be applied
		-- and should return the same size or smaller one.
		idealReducedContentSize = nil, -- function(content, width, height)

		-- called right after modal content did become active
		didBecomeActive = nil, -- function(content)

		-- called right before modal content resigns active
		-- (when popped or when content pushed replacing it)
		willResignActive = nil, -- function(content)

		-- attributes that need to be controlled by metatable
		_attr = {
			topLeft = {},
			topCenter = {},
			-- topRight is reserved for close button
			bottomLeft = {},
			bottomCenter = {},
			bottomRight = {},
			modal = nil,
			getModalIfContentIsActive = function(self)
				local modal = self._attr.modal
				if modal ~= nil and modal.contentStack ~= nil and modal.contentStack[#modal.contentStack] == self then
					return modal
				end
				return nil
			end,
			pushAndRemoveSelf = function(self, content)
				local modal = self._attr.modal
				if modal ~= nil then
					if modal.contentStack[#modal.contentStack] == self then
						if self.willResignActive ~= nil then
							self:willResignActive()
						end
						local toRemove = #modal.contentStack
						modal:push(content, true)
						modal:pop(toRemove)
						modal:refreshContent()
						if content.didBecomeActive ~= nil then
							content:didBecomeActive()
						end
					else
						error("pushAndRemoveSelf: caller is not active content", 2)
						return
					end
				else
					error("pushAndRemoveSelf: can't get modal", 2)
				end
			end,
			push = function(self, content)
				local modal = self:getModalIfContentIsActive()
				if modal ~= nil then
					modal:push(content)
				end
			end,
			pop = function(self, _)
				local modal = self:getModalIfContentIsActive()
				if modal ~= nil then
					modal:pop()
				end
			end,
			refreshModal = function(self)
				local modal = self:getModalIfContentIsActive()
				if modal ~= nil then
					modal:refresh()
				end
			end,
		}
	}

	setmetatable(modalContent, modalContentMT)

	return modalContent
end

--[[

+--------------------------+
| back/icon  TOP BAR     X |
+--------------------------+
|     TABS (optional)      |
+--------------------------+
|                          |
|         CONTENT          |
|                          |
+--------------------------+
|  BOTTOM BAR (optional)   |
+--------------------------+

]]--

-- uikit: optional, allows to provide specific instance of uikit
modal.create = function(_, content, maxWidth, maxHeight, position, uikit)

	local theme = require("uitheme").current

	local ui = uikit or require("uikit")

	if content == nil then error("modal needs content to display", 2) end
	if content.isModalContent ~= true then error("modal content should be of modalContent type", 2) end
	if maxHeight == nil or type(maxHeight) ~= "function" then error("modal needs a maxHeight function", 2) end
	if maxWidth == nil or type(maxWidth) ~= "function" then error("modal need a maxWidth function", 2) end
	if position == nil or type(position) ~= "function" then error("modal needs a position function", 2) end

	-- a modal is always placed at top level when created
	local node = ui:createNode()

	content._attr.modal = node
	node.contentStack = {content}
	node.shouldRefreshContent = true

	node.maxWidth = maxWidth
	node.maxHeight = maxHeight

	node._refreshTimer = nil

	node._icon = nil
	node._title = nil
	node._backButton = nil
	node._topLeft = {}
	node._topCenter = {}
	node._tabs = {}
	node._content = nil
	node._bottomLeft = {}
	node._bottomCenter = {}
	node._bottomRight = {}

	-- forces refresh to be called right away
	node._triggerRefresh = function(self)
		if self._refreshTimer ~= nil then
			self._refreshTimer:Cancel()
			self._refreshTimer = nil
		end
		if self._refresh then self:_refresh() end
	end

	-- schedules refresh in 0.02 sec to avoid refreshing
	-- the whole layout several times due to layour impacting
	-- operations called in sequence.
	node._scheduleRefresh = function(self)
		if self._refreshTimer == nil then
			self._refreshTimer = Timer(0.02, function()
				if node._refresh then node:_triggerRefresh() end
			end)
		end
	end

	node.refreshContent = function(self, schedule)
		self.shouldRefreshContent = true
		-- return if a refresh has already been scheduled
		if self._refreshTimer ~= nil then return end
		-- otherwise, trigger refresh right away
		if schedule then
			self:_scheduleRefresh()
		else
			self:_triggerRefresh()
		end
	end

	node.refresh = function(self)
		self:refreshContent()
	end

	-- push new content page
	node.push = function(self, content, skipRefresh)
		if content == nil then error("can't push nil content", 2) end

		self:_hideAllDisplayedElements()
		content._attr.modal = self

		local active = self.contentStack[#self.contentStack]
		if active ~= nil and active.willResignActive ~= nil then
			active:willResignActive()
		end

		table.insert(self.contentStack, content)
		if not skipRefresh then
			self:refreshContent()
			if content.didBecomeActive ~= nil then
				content:didBecomeActive()
			end
		end
	end

	node.pop = function(self, n)
		if n ~= nil then
			if #self.contentStack < n then return end
			if n == #self.contentStack then
				self:pop()
				return
			end
			local content = self.contentStack[n]
			table.remove(self.contentStack, n)
			content:cleanup()
			collectgarbage("collect")
			return
		end
		if #self.contentStack < 2 then return end
		self:_hideAllDisplayedElements()
		local content = self.contentStack[#self.contentStack]

		if content.willResignActive ~= nil then
			content:willResignActive()
		end

		table.remove(self.contentStack)
		content:cleanup()

		self._content = nil
		self:refreshContent()
		collectgarbage("collect")

		content = self.contentStack[#self.contentStack]
		if content ~= nil and content.didBecomeActive ~= nil then
			content:didBecomeActive()
		end
	end

	-- accessors
	node._width = function(self)
		return self.border.Width
	end

	node._height = function(self)
		return self.border.Height
	end

	node._computeWidth = function(self)
		local min = theme.modalBorder * 2 + theme.padding * 2
		local max = self.maxWidth()
		local w = math.max(min,max)
		return w
	end

	node._computeHeight = function(self)
		local min= self.topBar.Height + self.bottomBar.Height + theme.modalBorder * 2 + theme.padding * 2
		local max = self.maxHeight()
		local h = math.max(min,max)
		return h
	end

	node.parentDidResize = function(self)
		self:_scheduleRefresh()
	end

	node._updatePosition = function(self)
		position(self)
	end

	node._hideAllContentElements = function(_, content)
		for _, element in ipairs(content.topLeft) do element:setParent(nil) end
		for _, element in ipairs(content.topCenter) do element:setParent(nil) end
		for _, element in ipairs(content.bottomLeft) do element:setParent(nil) end
		for _, element in ipairs(content.bottomCenter) do element:setParent(nil) end
		for _, element in ipairs(content.bottomRight) do element:setParent(nil) end
		if content.node ~= nil then content.node:setParent(nil) end
	end

	node._hideAllDisplayedElements = function(self)
		for _, element in ipairs(self._topLeft) do element:setParent(nil) end
		for _, element in ipairs(self._topCenter) do element:setParent(nil) end
		for _, element in ipairs(self._bottomLeft) do element:setParent(nil) end
		for _, element in ipairs(self._bottomCenter) do element:setParent(nil) end
		for _, element in ipairs(self._bottomRight) do element:setParent(nil) end
		for _, element in ipairs(self._tabs) do element:setParent(nil) end
		if self._content ~= nil then self._content:setParent(nil) end
	end

	node._refreshTabs = function(self)
		local nbTabs = #self._tabs
		if nbTabs > 0 then
			local eqWidth = (self.Width - theme.modalTabSpace * (nbTabs - 1)) / nbTabs
			local fitsEqWidth = true
			local largerTabWidth = 0
			local w
			for _, tab in ipairs(self._tabs) do
				w = tab.text.Width + theme.padding * 2
				if w > eqWidth then
					fitsEqWidth = false
					if w > largerTabWidth then
						largerTabWidth = w
					end
				end
			end
			local smallerTabsWidth = 0
			if nbTabs > 1 and fitsEqWidth == false then
				smallerTabsWidth = (self.Width - largerTabWidth - theme.modalTabSpace * (nbTabs - 1)) / (nbTabs - 1)
			end

			local previous = nil
			for _, tab in ipairs(self._tabs) do
				if tab.selected then
					tab.Color = theme.modalTabColorSelected
				else
					tab.Color = theme.modalTabColorIdle
				end

				if fitsEqWidth then
					tab.Width = eqWidth
					tab.Height = tab.text.Height + theme.padding * 2
					tab.short:setParent(nil)
					tab.text:setParent(tab)
					tab.text.pos.X = tab.Width * 0.5 - tab.text.Width * 0.5
					tab.text.pos.Y = theme.padding
				else
					if tab.selected then
						tab.Width = largerTabWidth
						tab.Height = tab.text.Height + theme.padding * 2
						tab.short:setParent(nil)
						tab.text:setParent(tab)
						tab.text.pos.X = tab.Width * 0.5 - tab.text.Width * 0.5
						tab.text.pos.Y = theme.padding
					else
						tab.Width = smallerTabsWidth
						tab.Height = tab.short.Height + theme.padding * 2
						tab.short:setParent(tab)
						tab.text:setParent(nil)
						tab.short.pos.X = tab.Width * 0.5 - tab.short.Width * 0.5
						tab.short.pos.Y = theme.padding
					end
				end

				if previous then
					tab.pos.X = previous.pos.X + previous.Width + theme.modalTabSpace
				else
					tab.pos.X = 0
				end
				previous = tab
			end
		end
	end

	node._refresh = function(self)
		local stackIndex = #self.contentStack
		if stackIndex == 0 then return end

		local modalContent = self.contentStack[stackIndex]
		local previous

		if self.shouldRefreshContent then

			-- remove generated elements
			if self._icon ~= nil then self._icon:remove() self._icon = nil end
			if self._title ~= nil then self._title:remove() self._title = nil end
			if self._backButton ~= nil then self._backButton:remove() self._backButton = nil end

			self._topLeft = {}
			self._topCenter = {}

			-- tabs are generated by modal, remove them
			for _, element in ipairs(self._tabs) do element:remove() end
			self._tabs = {}

			self._bottomLeft = {}
			self._bottomCenter = {}
			self._bottomRight = {}

			if stackIndex > 1 then
				local backBtn = ui:createButton("⬅️")
				backBtn:setColor(theme.colorNegative)
				backBtn.onRelease = function()
					self:pop()
				end
				backBtn:setParent(self.topBar)
				table.insert(self._topLeft, backBtn)
				self._backButton = backBtn
			end

			if modalContent.icon ~= nil and type(modalContent.icon) == "string" then

				local icon = ui:createFrame(Color(0,0,0,0))
				local iconTxt = ui:createText(modalContent.icon, Color(255,255,255,254))
				iconTxt:setParent(icon)
				local padding = ui.kButtonPadding + ui.kButtonBorder
				icon.Width = iconTxt.Width + padding * 2
				icon.Height = iconTxt.Height + padding * 2
				iconTxt.pos = {padding, padding, 0}

				icon.contentDidResize = function(self)
					self.Width = iconTxt.Width + padding * 2
					self.Height = iconTxt.Height + padding * 2
				end

				icon:setParent(self.topBar)
				table.insert(self._topLeft, icon)
				self._icon = icon
			end

			for _, element in ipairs(modalContent.topLeft) do
				element:setParent(self.topBar)
				table.insert(self._topLeft, element)
			end

			if modalContent.title ~= nil and type(modalContent.title) == "string" then
				local title = ui:createText(modalContent.title, theme.textColor)
				title:setParent(self.topBar)
				table.insert(self._topCenter, title)
				self._title = title
			end

			for _, element in ipairs(modalContent.topCenter) do
				element:setParent(self.topBar)
				table.insert(self._topCenter, element)
			end

			local selectedSet = false
			for _, element in ipairs(modalContent.tabs) do
				local tab = ui:createFrame(Color(255,0,0))

				if not selectedSet then
					if element.selected == true then
						tab.selected = true
						selectedSet = true
					end
				end

				tab:setParent(self.topBar)
				tab.text = ui:createText(element.label, theme.textColor)
				tab.short = ui:createText(element.short or ".", theme.textColor)
				tab.short:setParent(nil)
				tab.action = element.action
				tab.text:setParent(tab)
				tab.onPress = function()
					if not tab.selected then
						tab.Color = theme.modalTabColorPressed
					end
				end
				tab.onCancel = function()
					if not tab.selected then
						tab.Color = theme.modalTabColorIdle
					end
				end
				tab.onRelease = function()
					if not tab.selected then
						local selectedIndex = 0
						for i, t in ipairs(self._tabs) do
							if t == tab then
								selectedIndex = i
								t.selected = true
								t.Color = theme.modalTabColorSelected
							else
								t.selected = false
								t.Color = theme.modalTabColorIdle
							end
						end
						if selectedIndex > 0 then
							for i, t in ipairs(modalContent.tabs) do
								if i == selectedIndex then
									t.selected = true
								else
									t.selected = false
								end
							end
						end
						self:_refreshTabs()
						tab:action()
					end
				end

				table.insert(self._tabs, tab)
			end

			if #self._tabs > 0 and selectedSet == false then
				self._tabs[1].selected = true
			end

			self._content = modalContent.node
			if self._content.setParent ~= nil then
				self._content:setParent(self.background)
			end

			for _, element in ipairs(modalContent.bottomLeft) do
				if element.setParent ~= nil then
					element:setParent(self.bottomBar)
					table.insert(self._bottomLeft, element)
				end
			end
			for _, element in ipairs(modalContent.bottomCenter) do
				if element.setParent ~= nil then
					element:setParent(self.bottomBar)
					table.insert(self._bottomCenter, element)
				end
			end
			for _, element in ipairs(modalContent.bottomRight) do
				if element.setParent ~= nil then
					element:setParent(self.bottomBar)
					table.insert(self._bottomRight, element)
				end
			end

			if modalContent.closeButton then self.closeBtn:show()  else  self.closeBtn:hide() end

			self.shouldRefreshContent = false
		end

		if self._content == nil or self._content.pos == nil then return end

		-- COMPUTE TOP BAR SIZES

		local topbarHeight = self.closeBtn:isVisible() and self.closeBtn.Height or 0

		local topLeftElementsWidth = 0
		for i, element in ipairs(self._topLeft) do
			if i > 1 then topLeftElementsWidth = topLeftElementsWidth + theme.padding end
			topLeftElementsWidth = topLeftElementsWidth + element.Width
			if element.Height > topbarHeight then topbarHeight = element.Height end
		end

		local topCenterElementsWidth = 0
		for i, element in ipairs(self._topCenter) do
			if i > 1 then topCenterElementsWidth = topCenterElementsWidth + theme.padding end
			topCenterElementsWidth = topCenterElementsWidth + element.Width
			if element.Height > topbarHeight then topbarHeight = element.Height end
		end

		self.topBar.Height = topbarHeight
		if self.topBar.Height > 0 then
			self.topBar.Height = self.topBar.Height + theme.modalTopBarPadding * 2
		end

		-- COMPUTE TABS BAR SIZES

		local nbTabs = #self._tabs
		if nbTabs > 0 then
			self.topBar.Height = self.topBar.Height + self._tabs[1].text.Height + theme.padding * 2
		end

		-- COMPUTE BOTTOM BAR SIZES

		local bottomBarHeight = 0
		local bottomRightElementsWidth = 0
		for i, element in ipairs(self._bottomRight) do
			if i > 1 then bottomRightElementsWidth = bottomRightElementsWidth + theme.padding end
			bottomRightElementsWidth = bottomRightElementsWidth + element.Width
			if element.Height > bottomBarHeight then bottomBarHeight = element.Height end
		end

		local bottomCenterElementsWidth = 0
		for i, element in ipairs(self._bottomCenter) do
			if i > 1 then bottomCenterElementsWidth = bottomCenterElementsWidth + theme.padding end
			bottomCenterElementsWidth = bottomCenterElementsWidth + element.Width
			if element.Height > bottomBarHeight then bottomBarHeight = element.Height end
		end

		local bottomLeftElementsWidth = 0
		for i, element in ipairs(self._bottomLeft) do
			if i > 1 then bottomLeftElementsWidth = bottomLeftElementsWidth + theme.padding end
			bottomLeftElementsWidth = bottomLeftElementsWidth + element.Width
			if element.Height > bottomBarHeight then bottomBarHeight = element.Height end
		end

		if bottomBarHeight > 0 then
			self.bottomBar.Height = bottomBarHeight + theme.modalBottomBarPadding * 2
		else
			self.bottomBar.Height = 0
		end

		local totalTopWidth = topLeftElementsWidth + topCenterElementsWidth + self.closeBtn.Width + theme.padding * 4
		local totalBottomWidth = bottomRightElementsWidth + bottomCenterElementsWidth + bottomLeftElementsWidth + theme.padding * 4

		-- Start from max size
		local borderSize = Number2(self:_computeWidth(), self:_computeHeight())
		if borderSize.Width < totalTopWidth then borderSize.Width = totalTopWidth end
		if borderSize.Width < totalBottomWidth then borderSize.Width = totalBottomWidth end

		local backgroundSize = borderSize - Number2(theme.modalBorder * 2, theme.modalBorder * 2)
		local contentSize = backgroundSize - Number2(theme.padding * 2, (theme.padding * 2) + self.topBar.Height + self.bottomBar.Height)

		if modalContent.idealReducedContentSize ~= nil then
			local reducedContentSize = modalContent.idealReducedContentSize(self._content, contentSize.Width, contentSize.Height)
			if reducedContentSize ~= nil and reducedContentSize ~= contentSize then

				if reducedContentSize.X < totalTopWidth then reducedContentSize.X = totalTopWidth end
				if reducedContentSize.X < totalBottomWidth then reducedContentSize.X = totalBottomWidth end

				local diff = reducedContentSize - contentSize
				borderSize = borderSize + diff
				backgroundSize = backgroundSize + diff
				contentSize = contentSize + diff
			end
		end

		-- border
		self.border.Width = borderSize.Width
		self.border.Height = borderSize.Height

		-- shadow
		self.shadow.Width = self.border.Width - theme.padding * 2
		self.shadow.Height = theme.padding

		-- background
		self.background.Width = backgroundSize.Width
		self.background.Height = backgroundSize.Height

		self._content.Width = contentSize.Width
		self._content.Height = contentSize.Height

		self._content.pos = {self.background.Width * 0.5 - self._content.Width * 0.5, theme.modalBorder + theme.padding, 0}
		if self.bottomBar.Height > 0 then
			self._content.pos.Y = self._content.pos.Y + self.bottomBar.Height
		end

		-- bottom bar
		if self.bottomBar.Height > 0 then
			self.bottomBar.Width = self.background.Width

			previous = nil
			for _, element in ipairs(self._bottomLeft) do
				element.pos.Y = self.bottomBar.Height * 0.5 - element.Height * 0.5
				if previous then
					element.pos.X = previous.pos.X + previous.Width + theme.padding
				else
					element.pos.X = theme.modalBottomBarPadding
				end
				previous = element
			end

			previous = nil
			for _, element in ipairs(self._bottomCenter) do
				element.pos.Y = self.bottomBar.Height * 0.5 - element.Height * 0.5
				if previous then
					element.pos.X = previous.pos.X + previous.Width + theme.padding
				else
					element.pos.X = self.bottomBar.Width * 0.5 - bottomCenterElementsWidth * 0.5
				end
				previous = element
			end

			previous = nil
			for _, element in ipairs(self._bottomRight) do
				element.pos.Y = self.bottomBar.Height * 0.5 - element.Height * 0.5
				if previous then
					element.pos.X = previous.pos.X - element.Width - theme.padding
				else
					element.pos.X = self.bottomBar.Width - element.Width - theme.modalBottomBarPadding
				end
				previous = element
			end
		end

		-- top bar

		self.topBar.Width = self.background.Width
		self.topBar.pos.Y = self.background.Height - self.topBar.Height

		self.closeBtn.pos.X = self.topBar.Width - self.closeBtn.Width - theme.modalTopBarPadding
		self.closeBtn.pos.Y = self.topBar.Height - self.closeBtn.Height - theme.modalTopBarPadding

		previous = nil
		for _, element in ipairs(self._topLeft) do
			if self.closeBtn:isVisible() and element.Height < self.closeBtn.Height then
				element.pos.Y = self.closeBtn.pos.Y + self.closeBtn.Height * 0.5 - element.Height * 0.5
			else
				element.pos.Y = self.topBar.Height - element.Height - theme.modalTopBarPadding
			end

			if previous then
				element.pos.X = previous.pos.X + previous.Width + theme.padding
			else
				element.pos.X = self.topBar.pos.X + theme.modalTopBarPadding
			end
			previous = element
		end

		previous = nil
		for _, element in ipairs(self._topCenter) do
			if self.closeBtn:isVisible() and element.Height < self.closeBtn.Height then
				element.pos.Y = self.closeBtn.pos.Y + self.closeBtn.Height * 0.5 - element.Height * 0.5
			else
				element.pos.Y = self.topBar.Height - element.Height - theme.modalTopBarPadding
			end
			if previous then
				element.pos.X = previous.pos.X + previous.Width + theme.padding
			else
				element.pos.X = self.topBar.Width * 0.5 - topCenterElementsWidth * 0.5
			end
			previous = element
		end

		-- tabs

		self:_refreshTabs()

		-- just in case, force trigger parentDidResize for content node
		if self._content.parentDidResize then self._content:parentDidResize() end

		self:_updatePosition()
	end

	node.didClose = nil

	node.close = function(self)

		local active = self.contentStack[#self.contentStack]
		if active ~= nil and active.willResignActive ~= nil then
			active:willResignActive()
		end

		-- if self._content.onClose ~= nil then
		-- 	self._content:onClose()
		-- end
		self:setParent(nil)
		if self.didClose ~= nil then
			self:didClose()
		end

		for _, content in ipairs(self.contentStack) do
			content:cleanup()
		end
		self.contentStack = {}

		if self.remove ~= nil then
			self:remove() -- does a deep cleanup
		end
		collectgarbage("collect")
	end

	local border = ui:createFrame(Color(120,120,120,0))
	border:setParent(node)
	node.border = border

	local shadow = ui:createFrame(Color(0,0,0,20))
	shadow:setParent(node)
	shadow.LocalPosition = {theme.padding, -theme.padding, 0}
	node.shadow = shadow

	-- background
	local background = ui:createFrame(Color(0,0,0,0.8))
	background:setParent(node)
	background.LocalPosition = {theme.modalBorder, theme.modalBorder, 0}
	node.background = background

	-- top bar
	local topBar = ui:createFrame(theme.modalTopBarColor)
	topBar:setParent(background)
	node.topBar = topBar

	-- bottom bar
	local bottomBar = ui:createFrame(theme.modalTopBarColor)
	bottomBar:setParent(background)
	node.bottomBar = bottomBar

	-- close button
	node.closeBtn = ui:createButton("❌")
	node.closeBtn:setParent(topBar)
	node.closeBtn.onRelease = function(_)
		node:close()
	end

	node:_hideAllContentElements(content)

	-- do not refresh right away, as users could still be updating
	-- content right after creating the modal.
	node:_scheduleRefresh()

	if content.didBecomeActive then
		content:didBecomeActive()
	end

	node.LocalPosition.Y = -10000 -- out of screen by default
	return node
end

return modal
