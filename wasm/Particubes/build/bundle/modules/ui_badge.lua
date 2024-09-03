--- This module allows you to create UI toast messages

ui = require("uikit")
ease = require("ease")
conf = require("config")

local mod = {}

defaultConfig = {
	text = "test",
	ui = ui,
}

mod.create = function(_, config)
	config = conf:merge(defaultConfig, config)
	local ui = config.ui

	local badge = ui:createNode()

	local textShape = stringToShape(config.text)

	-- add red blocks:

	local hMargin = 3
	local vMargin = 2

	local minX = textShape.Min.X - hMargin
	local maxX = textShape.Max.X - 1 + hMargin
	local minY = textShape.Min.Y - vMargin
	local maxY = textShape.Max.Y - 1 + vMargin

	local fill = textShape.Palette:AddColor(Color(255, 0, 0))
	local border = textShape.Palette:AddColor(Color(140, 0, 0))

	for w = minX, maxX do
		for h = minY, maxY do
			if
				not (
					(w == minX and h == minY)
					or (w == minX and h == maxY)
					or (w == maxX and h == minY)
					or (w == maxX and h == maxY)
				)
			then
				if textShape:GetBlock(w, h, 0) == nil then
					if w == minX or w == maxX or h == minY or h == maxY then
						textShape:AddBlock(border, w, h, 0)
					else
						textShape:AddBlock(fill, w, h, 0)
					end
				end
			end
		end
	end

	local shape = ui:createShape(textShape, { doNotFlip = true })
	shape:setParent(badge)

	badge.shape = shape

	if refreshBadge == nil then
		refreshBadge = function(badge)
			badge.shape.pos = { -badge.shape.Width * 0.5, -badge.shape.Height * 0.5 }
			badge.shape.LocalPosition.Z = -450
			badge.shape.pivot.Scale = 0.5
		end
	end

	badge.parentDidResize = refreshBadge
	badge:parentDidResize()

	logoAnim = {}
	logoAnim.start = function()
		ease:inOutSine(badge.object, 0.15, {
			onDone = function()
				ease:inOutSine(badge.object, 0.15, {
					onDone = function()
						logoAnim.start()
					end,
				}).Scale =
					Number3(0.9, 0.9, 0.9)
			end,
		}).Scale =
			Number3(1.1, 1.1, 1.1)
	end
	logoAnim.start()

	local remove = badge.remove
	badge.remove = function(self)
		ease:cancel(self.object)
		remove(self)
	end

	return badge
end

-- char shapes (this could be in another module)

chars = {}
chars["!"] = [["
1
1
1

1
"]]
chars["1"] = [["
1
1
1
1
1
"]]
chars["2"] = [["
111
  1
111
1
111
"]]
chars["3"] = [["
111
  1
111
  1
111
"]]
chars["4"] = [["
1 1
1 1
111
  1
  1
"]]
chars["5"] = [["
111
1
111
  1
111
"]]
chars["6"] = [["
111
1
111
1 1
111
"]]
chars["7"] = [["
111
  1
  1
  1
  1
"]]
chars["8"] = [["
111
1 1
111
1 1
111
"]]
chars["9"] = [["
111
1 1
111
  1
111
"]]

function stringToShape(str)
	local s = MutableShape()
	local white = s.Palette:AddColor(Color(255, 255, 255))
	local x, y
	local blocks
	local char
	local c
	local len = #str
	local cursor = 0
	local xStart

	for ci = 1, len do
		char = str:sub(ci, ci)
		blocks = chars[char]
		xStart = cursor
		x, y = xStart, 0

		if blocks ~= nil then
			for i = 1, #blocks do
				c = blocks:sub(i, i)
				x = x + 1
				cursor = math.max(cursor, x)
				if c == "1" then
					s:AddBlock(white, x, y, 0)
				elseif c == "\n" then
					y = y - 1
					x = xStart
				end
			end
			cursor = cursor + 1
		end
	end

	return s
end

return mod
