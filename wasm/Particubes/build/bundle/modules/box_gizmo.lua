boxGizmo = {}
boxGizmoMetatable = {
	__index = {
		_isInit = false,
		_rootEdges = nil,
		_edges = {},
		activated = false,
		setGizmoMode = function(self, mode)
			self.activated = true
			self.mode = mode
		end,
		_init = function(self)
			self._rootEdges = Object()
			for _ = 1, 12 do
				local edge = MutableShape()
				edge:AddBlock(Color.White, 0, 0, 0)
				edge:SetParent(self._rootEdges)
				edge.CollisionGroups = nil
				edge.CollidesWithGroups = nil
				table.insert(self._edges, edge)
			end
			self._isInit = true
		end,
		toggle = function(self, object)
			if not self._isInit then
				self:_init()
			end

			-- clear current box
			self._rootEdges:RemoveFromParent()

			self.object = object
			if not object then
				return
			end

			local shape = object
			local savedRotation = shape.Rotation:Copy()
			local box = Box()
			shape.Rotation = Number3(0, 0, 0)
			Timer(0.001, function()
				box:Fit(shape, true)
				shape.Rotation = savedRotation
				shape:Refresh()
				local isNotShape = type(shape) ~= "Shape" and type(shape) ~= "MutableShape"
				local w = isNotShape and 5 or (box.Max.X - box.Min.X)
				local h = isNotShape and 5 or (box.Max.Y - box.Min.Y)
				local d = isNotShape and 5 or (box.Max.Z - box.Min.Z)
				local pivot = isNotShape and Number3(2.5, 2.5, 2.5) or (shape.Position - box.Min)
				local size = Number3(w, h, d)
				local edgeSetups = {
					{ pos = -pivot, px = 0, sx = w },
					{ pos = -pivot, py = 0, sy = h },
					{ pos = -pivot, pz = 0, sz = d },
					{ pos = -pivot + size, px = 1, sx = w },
					{ pos = -pivot + size, py = 1, sy = h },
					{ pos = -pivot + size, pz = 1, sz = d },
					{ pos = -pivot + Number3(w, 0, 0), py = 0, sy = h },
					{ pos = -pivot + Number3(w, 0, 0), pz = 0, sz = d },
					{ pos = -pivot + Number3(0, h, 0), px = 0, sx = w },
					{ pos = -pivot + Number3(0, h, 0), pz = 0, sz = d },
					{ pos = -pivot + Number3(0, 0, d), px = 0, sx = w },
					{ pos = -pivot + Number3(0, 0, d), py = 0, sy = h },
				}

				self._rootEdges:SetParent(object)
				self._rootEdges.LocalPosition = Number3(0, 0, 0)
				self._rootEdges.LocalRotation = Number3(0, 0, 0)
				self._rootEdges.LocalScale = 1 / object.Scale.X
				for key, setup in ipairs(edgeSetups) do
					local b = self._edges[key]
					b.LocalPosition = setup.pos
					b.LocalRotation = { 0, 0, 0 }
					b.Pivot = { setup.px or 0.5, setup.py or 0.5, setup.pz or 0.5 }
					b.Scale = { setup.sx or 0.1, setup.sy or 0.1, setup.sz or 0.1 }
				end
			end)
		end,
	},
	__newIndex = function()
		print("Error: boxGizmo is read-only")
	end,
}
setmetatable(boxGizmo, boxGizmoMetatable)

return boxGizmo
