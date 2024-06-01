--[[
This module can be used to display a crosshair in the middle of the screen.
]]
--

crosshair = {}

scale = 0.2

default = [["
    2222
    2112
    2112
    2112
222222222222
21112  21112
21112  21112
222222222222
    2112
    2112
    2112
    2222
"]]

crosshair.show = function(_, shape)
	if shape == nil then
		shape = default
	end

	if _crosshair == nil then
		local ui = require("uikit")

		local mShape = MutableShape()
		local white = mShape.Palette:AddColor(Color(255, 255, 255))
		local black = mShape.Palette:AddColor(Color(0, 0, 0, 0.4))

		local x, y = 0, 0
		for i = 1, #shape do
			local c = shape:sub(i, i)
			x = x + 1
			if c == "1" then
				mShape:AddBlock(white, x, y, 0)
			elseif c == "2" then
				mShape:AddBlock(black, x, y, 0)
			elseif c == "\n" then
				y = y - 1
				x = 0
			end
		end

		local s = Shape(mShape)
		_crosshair = ui:createShape(s)

		_crosshair.Width = _crosshair.Width * scale
		_crosshair.Height = _crosshair.Height * scale

		_crosshair.parentDidResize = function()
			_crosshair.pos =
				{ Screen.Width * 0.5 - _crosshair.Width * 0.5, Screen.Height * 0.5 - _crosshair.Height * 0.5, 0 }
		end
		_crosshair:parentDidResize()
	end

	_crosshair:show()
end

crosshair.hide = function()
	if _crosshair == nil then
		return
	end
	_crosshair:hide()
end

return crosshair
