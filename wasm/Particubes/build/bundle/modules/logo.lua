--
-- Programmable Cubzh logo
--

mod = {}

mod.createShape = function(_)
	local shapeBlocks = [["
  1 1 1
 1111111
11     11
 1 111 1
11 1   11
 1 111 1
11     11
 1111111
  1 1 1
"]]

	local function buildShape(s, blocks)
		local white = s.Palette:AddColor(Color(255, 255, 255))

		local x, y = 0, 0
		for i = 1, #blocks do
			local c = blocks:sub(i, i)
			x = x + 1
			if c == "1" then
				s:AddBlock(white, x, y, 0)
			elseif c == "\n" then
				y = y - 1
				x = 0
			end
		end
	end

	local shape = MutableShape()
	buildShape(shape, shapeBlocks)

	shape.Pivot = shape.Center

	return shape
end

return mod
