local loading = {}

loading.create = function(self)
		
	local uikit = require("uikit")
	local modal = require("modal")
	local theme = require("uitheme").current
	local ease = require("ease")

	local _year
	local _month
	local _day

	local function idealReducedContentSize(content, width, height)
		if content.refresh then content:refresh() end
		return Number2(content.Width,content.Height)
	end

	local maxWidth = function()
		return Screen.Width - theme.modalMargin * 2
	end

	local maxHeight = function()
		return Screen.Height - 100
	end

	local position = function(modal, forceBounce)
		local p = Number3(Screen.Width * 0.5 - modal.Width * 0.5, Screen.Height * 0.5 - modal.Height * 0.5, 0)

		if not modal.updatedPosition or forceBounce then
			modal.LocalPosition = p - {0,100,0}
			modal.updatedPosition = true
			ease:outElastic(modal, 0.3).LocalPosition = p
		else
			modal.LocalPosition = p
		end
	end

	-- initial content, asking for year of birth
	local content = modal:createContent()
	content.idealReducedContentSize = idealReducedContentSize

	local node = uikit:createFrame(Color(0,0,0,0))
	content.node = node

	content.title = "Birthdate?"
	content.icon = "🙂"

	local popup = modal:create(content, maxWidth, maxHeight, position)

	popup.onDone = function(y,m,d) end

	local text = "Sorry for being nosy, we need to know that to protect young ones. So, what year?"
	local label = uikit:createText(text, Color(200,200,200,255), "default")
	label:setParent(node)

	local yearStart = 2000
	local yearRange = uikit:createText("2000-2009", Color.White)
	local yearRangeNext = uikit:createButton("➡️")
	local yearRangePrevious = uikit:createButton("⬅️")

	yearRangeNext.onRelease = function()
		local currentYear = tonumber(os.date("%Y"))
		if yearStart + 10 < currentYear then
			yearStart = yearStart + 10
			node:refresh()
		end
	end

	yearRangePrevious.onRelease = function()
		if yearStart - 10 >= 1920 then
			yearStart = yearStart - 10
			node:refresh()
		end
	end

	content.bottomCenter = {yearRangePrevious, yearRange, yearRangeNext}

	local monthNames = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}

	local function isLeapYear(year)
	    if year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then
	        return true
	    else
	        return false
	    end
	end

	local function nbDays(m)
		if m == 2 then
			if isLeapYear(m) then return 29 else return 28 end
		else
			local days = {31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
			return days[m]
		end
	end

	local function setDay(dd)
		debugEvent("BIRTHDATE_SET_DAY")
		_day = dd

		local content = modal:createContent()
		content.idealReducedContentSize = idealReducedContentSize
		local node = uikit:createFrame(Color(0,0,0,0))
		content.node = node

		content.title = "Done!"

		local birthTime = os.time({year=_year, month=_month, day=_day})
		local n, unit = require("time").ago(birthTime)
		if unit ~= "years" then n = 1 end

		local text = string.format("So you're born on %s %d, %d, meaning you're %d. Is that right? 🙂", monthNames[_month], _day, _year, math.floor(n))

		local label = uikit:createText(text, Color(200,200,200,255), "default")
		label:setParent(node)

		local confirmBtn = uikit:createButton("YES!", {textSize = "big"})
		content.bottomCenter = {confirmBtn}
		confirmBtn:setColor(Color(161,217,0), Color(45,57,17), false)
		confirmBtn.onRelease = function()
			if popup.onDone ~= nil then popup.onDone(_year, _month, _day) end
		end

		node._width = function(self)
			local w = label.Width + theme.padding * 2
			return w
		end

		node._height = function(self)
			return label.Height + theme.padding * 2
		end

		node.refresh = function(self)
			label.object.MaxWidth = math.min(400,Screen.Width * 0.7)
			label.pos = { self.Width * 0.5 - label.Width * 0.5, self.Height - label.Height - theme.padding, 0 }
		end

		popup:push(content)
	end

	local function setMonth(mm)
		debugEvent("BIRTHDATE_SET_MONTH")
		_month = mm

		local content = modal:createContent()
		content.idealReducedContentSize = idealReducedContentSize
		local node = uikit:createFrame(Color(0,0,0,0))
		content.node = node

		content.title = "Birthdate?"

		local text = string.format("%s %d, starting to know you better! What day? 🙂", monthNames[_month], _year)
		local label = uikit:createText(text, Color(200,200,200,255), "default")
		label:setParent(node)

		local dayButtons = {}
		for i = 1,nbDays(_month) do
			local btn = uikit:createButton(string.format("%02d", i))
			btn:setParent(node)
			table.insert(dayButtons, btn)
			btn.onRelease = function()
				setDay(i)
			end
		end

		local function daysColsAndWidth()
			local btn = dayButtons[1]
			local w = btn.Width + theme.paddingBig
			local cols = math.floor(math.min(12, (Screen.Width - theme.modalMargin * 2 - theme.padding * 6) / w))
			if cols == 5 then cols = 4 end
			return cols, (cols * w) - theme.paddingBig
		end

		node._width = function(self)
			local w = label.Width + theme.padding * 2
			local _, btnW = daysColsAndWidth()
			if w < btnW then w = btnW end
			return w
		end

		node._height = function(self)

			local cols = daysColsAndWidth()
			local rows = math.ceil(#dayButtons / cols)
			local btn = dayButtons[1]
			local h = btn.Height + theme.paddingBig

			return label.Height + theme.paddingBig + rows * h
		end

		node.refresh = function(self)

			local cols, w = daysColsAndWidth()
			local rows = math.ceil(#dayButtons / cols)

			label.object.MaxWidth = w
			label.pos = { self.Width * 0.5 - label.Width * 0.5, self.Height - label.Height - theme.padding, 0 }

			local btn = dayButtons[1]
			local offset = btn.Width + theme.paddingBig

			local startX = self.Width * 0.5 - w * 0.5
			local startY = label.pos.Y - btn.Height - theme.paddingBig
			local col = 0

			for i, b in ipairs(dayButtons) do
				b.pos.X = startX + col * offset
				b.pos.Y = startY

				col = col + 1
				if col % cols == 0 then
					col = 0
					startY = startY - btn.Height - theme.paddingBig
				end
			end
		end

		popup:push(content)
	end

	local function setYear(yyyy)
		debugEvent("BIRTHDATE_SET_YEAR")
		_year = yyyy

		local content = modal:createContent()
		content.idealReducedContentSize = idealReducedContentSize
		local node = uikit:createFrame(Color(0,0,0,0))
		content.node = node

		content.title = "Birthdate?"
		-- content.icon = "🙂"

		local text = string.format("%d is awesome! Now, what month did you arrive in this world?", _year)
		local label = uikit:createText(text, Color(200,200,200,255), "default")
		label:setParent(node)

		local monthButtons = {}
		for i = 1,12 do
			-- local btn = uikit:createButton(string.format("%02d %s", i, monthNames[i]))
			local btn = uikit:createButton(string.format("%s", monthNames[i]))
			btn:setParent(node)
			table.insert(monthButtons, btn)
			btn.onRelease = function()
				setMonth(i)
			end
		end

		local function monthsColsAndWidth()
			local btn = monthButtons[1]
			local w = btn.Width + theme.paddingBig
			local cols = math.floor(math.min(6, (Screen.Width - theme.modalMargin * 2 - theme.padding * 6) / w))
			if cols == 5 then cols = 4 end
			return cols, (cols * w) - theme.paddingBig
		end

		node._width = function(self)
			local w = label.Width + theme.padding * 2
			local _, btnW = monthsColsAndWidth()
			if w < btnW then w = btnW end
			return w
		end

		node._height = function(self)

			local cols = monthsColsAndWidth()
			local rows = math.ceil(#monthButtons / cols)
			local btn = monthButtons[1]
			local h = btn.Height + theme.paddingBig

			return label.Height + theme.paddingBig + rows * h
		end

		node.refresh = function(self)

			local cols, w = monthsColsAndWidth()
			local rows = math.ceil(#monthButtons / cols)

			label.object.MaxWidth = w
			label.pos = { self.Width * 0.5 - label.Width * 0.5, self.Height - label.Height - theme.padding, 0 }

			local btn = monthButtons[1]
			local offset = btn.Width + theme.paddingBig

			local startX = self.Width * 0.5 - w * 0.5
			local startY = label.pos.Y - btn.Height - theme.paddingBig
			local col = 0

			for i, b in ipairs(monthButtons) do
				b.pos.X = startX + col * offset
				b.pos.Y = startY

				col = col + 1
				if col % cols == 0 then
					col = 0
					startY = startY - btn.Height - theme.paddingBig
				end
			end
		end

		popup:push(content)
	end

	local yearButtons = {}
	for i = 1,10 do
		local btn = uikit:createButton("0000")
		btn:setParent(node)
		table.insert(yearButtons, btn)
		btn.onRelease = function()
			setYear(yearStart + i - 1)
		end
	end

	local function yearColsAndWidth()
		local btn = yearButtons[1]
		local w = btn.Width + theme.paddingBig
		local cols = math.floor(math.min(5, (Screen.Width - theme.modalMargin * 2 - theme.padding * 6) / w))
		return cols, (cols * w) - theme.paddingBig
	end

	node._width = function(self)
		local w = label.Width + theme.padding * 2
		local _, btnW = yearColsAndWidth()
		if w < btnW then w = btnW end
		return w
	end

	node._height = function(self)

		local cols = yearColsAndWidth()
		local rows = math.ceil(#yearButtons / cols)
		local btn = yearButtons[1]
		local h = btn.Height + theme.paddingBig

		return label.Height + theme.paddingBig + rows * h
	end

	node.refresh = function(self)
		yearRange.Text = tostring(yearStart) .. "-" .. tostring(yearStart + 9)

		local cols, w = yearColsAndWidth()
		local rows = math.ceil(#yearButtons / cols)

		label.object.MaxWidth = w
		label.pos = { self.Width * 0.5 - label.Width * 0.5, self.Height - label.Height - theme.padding, 0 }

		local btn = yearButtons[1]
		local offset = btn.Width + theme.paddingBig

		local startX = self.Width * 0.5 - w * 0.5
		local startY = label.pos.Y - btn.Height - theme.paddingBig
		local col = 0

		local currentYear = tonumber(os.date("%Y"))
		local y
		for i, b in ipairs(yearButtons) do

			y = yearStart + (i - 1)

			b.Text = tostring(y)
			b.pos.X = startX + col * offset
			b.pos.Y = startY

			if y >= currentYear then
				b:disable()
			else
				b:enable()
			end

			col = col + 1
			if col % cols == 0 then
				col = 0
				startY = startY - btn.Height - theme.paddingBig
			end
		end
	end

	popup.bounce = function(self)
		position(popup, true)
	end

	return popup
end

return loading
