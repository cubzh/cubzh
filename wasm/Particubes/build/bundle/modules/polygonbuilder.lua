--[[
    Polygon Builder
 call polygonBuilder:create(options) where options is a table containing
   options.nbSides: number of sides (>= 3)
   options.color: Color.White by default
   options.size: general size of the shape, 10 by default
   options.thickness: thickness of polygon (0.3 by default)
--]]
local polygonBuilder = {}
local polygonBuilderMetatable = {
	__index = {
		create = function(_, options)
			local nbSides = options.nbSides or 4
			if nbSides < 3 then
				print("Error: can't create a polygon with less than 3 sides.")
				return
			end
			local size = options.size or 10
			local color = options.color or Color.White
			local thickness = options.thickness or 0.3

			local sideT = MutableShape(false)
			sideT:AddBlock(color, 0, 0, 0)

			local polygon = Object()
			local vertices = {}

			for i = 0, nbSides do
				local angle = (i / nbSides) * 2 * math.pi - math.pi / 2
				local vertice = {
					pos = Number3(math.cos(angle), math.sin(angle), 0) * size,
					angle = angle,
				}
				table.insert(vertices, vertice)
			end

			local distance -- distance between vertices

			for i, vertice in ipairs(vertices) do
				if i == #vertices then
					break
				end
				local next = vertices[i + 1]

				if distance == nil then
					distance = (next.pos - vertice.pos).Length
				end

				local pos = vertice.pos + (next.pos - vertice.pos) * 0.5
				local angle = vertice.angle + (next.angle - vertice.angle) * 0.5

				local s = Shape(sideT)
				s:SetParent(polygon)

				s.LocalPosition = pos

				s.LocalRotation.Z = angle + math.pi * -0.5
				s.Pivot = Number3(0.5, 1, 0.5)

				s.Scale = { distance, thickness, thickness }
			end

			return polygon
		end,
	},
}
setmetatable(polygonBuilder, polygonBuilderMetatable)

return polygonBuilder
