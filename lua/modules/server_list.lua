
local serverList = {}

serverList.create = function(self, maxWidth, maxHeight, position, config)
	if type(config) ~= Type.table then
		error("server_list:create(maxWidth, maxHeight, position, config): config should be a table", 2)
	end
	if type(config.worldID) ~= Type.string then
		error("server_list:create(maxWidth, maxHeight, position, config): config.worldID should be a string", 2)
	end

	local uikit = require("uikit")
	local theme = require("uitheme").current
	local modal = require("modal")
	local api = require ("api")

	local idealReducedContentSize = function(content, width, height)
		width = math.min(width, 500)
		height = math.min(height, 500)

		local cellHeight, maxLines = content.getCellHeightAndMaxLines(height)
		return Number2(width, (cellHeight + theme.padding) * maxLines - theme.padding)
	end

	local content = modal:createContent()

	local node = uikit:createFrame(Color(0,0,0,0))

	local pages = require("pages"):create()
	pages:setPageDidChange(function(page) 
		node:refreshList((page - 1) * node.displayedCells + 1)
	end)

	node.pages = pages
	content.bottomLeft = {node.pages}

	content.node = node
	content.idealReducedContentSize = idealReducedContentSize

	node.displayedCells = 0

	-- Data
	node.data = {}

	node.data.worldID = config.worldID
	
	node.data.servers = {} -- servers collection
	node.data.requestFlying = false
	node.data.node = node
	node.data.updateServers = function(self)
		-- Prevent multiple requests
		if self.requestFlying == true then return end
		self.requestFlying = true

		node:flushLines()
		node.data.servers = {}
		if self.noServerText ~= nil then
			self.noServerText:remove()
			self.noServerText = nil
		end
		if self.noServerBtn ~= nil then
			self.noServerBtn:remove()
			self.noServerBtn = nil
		end
		self.launchBtn.IsHidden = true

		local loadingCube = ui:createFrame(Color.White)
		loadingCube:setParent(self.node)
		loadingCube.Width = 10
		loadingCube.Height = 10
		loadingCube.LocalPosition = Number3(self.node.Width / 2, self.node.Height / 2, 0)
		loadingCube.t = 0
		loadingCube.object.Tick = function(o, dt)
			if not loadingCube.LocalPosition then
				o.Tick = nil
				return
			end
			loadingCube.t = loadingCube.t + dt * 4
			loadingCube.LocalPosition = Number3(self.node.Width / 2 + math.cos(loadingCube.t) * 20, self.node.Height / 2 - math.sin(loadingCube.t) * 20, 0)
		end

		api:getServers(self.worldID, function(err, servers)
			loadingCube:remove()
			self.requestFlying = false
			if err or self.node == nil or self.node.refreshList == nil then
				return
			end
			self.servers = servers

			if #servers ~= 0 then
				self.launchBtn.IsHidden = false
				self.node:refreshList()
				return
			end

			-- no server, create UI to create an join server
			self.noServerText = ui:createText("No server", Color.White)
			self.noServerText:setParent(self.node)
			self.noServerText.pos.X = self.node.pos.X + self.node.Width / 2 - self.noServerText.Width / 2
			self.noServerText.pos.Y = self.node.pos.Y + self.node.Height / 2 + theme.padding / 2

			self.noServerBtn = ui:createButton("Create one")
			self.noServerBtn:setColor(theme.colorPositive, Color.White)
			self.noServerBtn:setParent(self.node)
			self.noServerBtn.pos.X = self.node.pos.X + self.node.Width / 2 - self.noServerBtn.Width / 2
			self.noServerBtn.pos.Y = self.node.pos.Y + self.node.Height / 2 - self.noServerBtn.Height - theme.padding / 2
			self.noServerBtn.onRelease = function(btn)
				self.noServerText:remove()
				self.noServerBtn:remove()
				self.noServerText = nil
				self.noServerBtn = nil
				self.joinAndHideUI(config.worldID)
			end
		end)
	end

	-- Lines
	node.lines = {}
	node.flushLines = function(self)
		for i, v in ipairs(node.lines) do
			v:remove()
		end
		node.lines = {}
	end

	-- Refresh list UI

	node.getCellHeightAndMaxLines = function(height)
		local t = ui:createText("A")
		local b = ui:createButton("💬")
		local cellHeight = math.max(t.Height, b.Height) + theme.padding * 3
		b:remove()
		t:remove()

		local h = cellHeight + theme.padding
		local maxLines = math.floor(height / h)

		if (maxLines + 1) * (cellHeight + theme.padding) - theme.padding <= height then
			maxLines = maxLines + 1
		end

		return cellHeight, maxLines
	end

	node.flushContentGetCellHeightAndMaxLines = function(self)
		self:flushLines()
		local top = self.Height
		return self.getCellHeightAndMaxLines(top)
	end

	-- returns cell
	node.createCell = function(self, cellHeight, server)
		if server.players == nil or server["max-players"] == nil or server["dev-mode"] == nil then return end

		local cell = ui:createFrame(Color(255,255,255,200))
		cell.Height = cellHeight
		cell:setParent(self)
		table.insert(self.lines, cell)
		cell.Width = self.Width

		local vPos = cell.Height * 0.5

		local str = math.tointeger(math.floor(server.players)) .. "/" .. math.tointeger(math.floor(server["max-players"])) .. " "
		if type(server.address) == Type.string then
			if string.find(server.address, "us") ~= nil then
				str = str .. "🇺" -- USA
			elseif string.find(server.address, "sg") ~= nil then
				str = str .. "🇸" -- Singapore
			else
				str = str .. "🇪" -- default to Europe
			end
		end

		if server["dev-mode"] then
			str = str .. " - DEV 🏗"
		end

		local cellText = ui:createText(str, Color(20,20,20))
		cellText:setParent(cell)
		cellText.pos.X = theme.padding * 2
		cellText.pos.Y = vPos - cellText.Height * 0.5

		local btn = ui:createButton("Join")
		btn:setParent(cell)
		btn.pos.Y = vPos - btn.Height * 0.5
		btn.pos.X = cell.Width - btn.Width - theme.padding * 2

		btn.worldID = self.data.worldID
		btn.address = server.address
		btn.onRelease = function(b)
			self.data.joinAndHideUI(b.worldID, b.address)
		end

		return cell
	end

	node.refreshList = function(self, from)
		local list = self.data.servers
		if list == nil then return end

		local top = self.Height

		local cellHeight, maxLines = self:flushContentGetCellHeightAndMaxLines()
		if maxLines <= 0 then return end

		self.displayedCells = maxLines -- update number of displayed cells

		local total = #list
		local from = from or 1

		if maxLines > 1 and (from % maxLines ~= 1 or from > total) then
			-- go back to first page
			from = 1
		end

		local page = math.floor(from / maxLines) + 1
		local totalPages = math.floor(total / maxLines) + 1
		if node.pages ~= nil then
			node.pages:setNbPages(totalPages)
			node.pages:setPage(page)
		end

		local server, cell
		local line = 0
		for i = from, total do
			line = line + 1
			if line > maxLines then break end
			local p = i - from
			server = list[i]

			cell = self:createCell(cellHeight, server)
		
			if cell ~= nil and cell.Height ~= nil then
				cell.pos.Y = top - (p + 1) * cell.Height - p * theme.padding
			end
		end
	end

	node.parentDidResize = function(self)
		node:refreshList()
	end

	node.onClose = function(self)
		if self.preventRefresh then return end
		-- refresh whole menu
		closeModals()
		refreshMenuDisplayMode()
	end

	local _modal = modal:create(content, maxWidth, maxHeight, position)

	local backBtn = ui:createButton("⬅️")
	backBtn:setColor(theme.colorNegative)
	backBtn.onRelease = function(b)
		config.parentModal.IsHidden = false
		node.preventRefresh = true
		_modal:close()
	end

	local titleStr = config.title .. "'s servers"
	local titleText = ui:createText(titleStr, Color.White)

	local refreshBtn = ui:createButton("🔃")
	refreshBtn.onRelease = function(b)
		node.data:updateServers()
	end

	local launchBtn = ui:createButton("Launch")
	launchBtn:setColor(theme.colorPositive)
	launchBtn.onRelease = function(b)
		node.data.joinAndHideUI(config.worldID)
	end
	node.data.launchBtn = launchBtn

	node.data.joinAndHideUI = function(worldID, address)
		config.parentModal.IsHidden = false
		hideUI()
		joinWorld(worldID, address)
		node.preventRefresh = true
		_modal:close()
	end
	
	content.topLeft = { backBtn }
	content.topCenter = { titleText }
	content.bottomRight = { refreshBtn, launchBtn }

	node.data:updateServers()

	return _modal
end

return serverList
