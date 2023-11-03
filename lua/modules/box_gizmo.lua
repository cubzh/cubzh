
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
			for _=1,12 do
				local edge = MutableShape()
				edge:AddBlock(Color.White,0,0,0)
				edge:SetParent(self._rootEdges)
				edge.CollisionGroups = nil
				edge.Scale = 0.05
				table.insert(self._edges,edge)
			end

			local scaleGizmo = MutableShape()
			scaleGizmo.IsUnlit = true
			scaleGizmo.Scale = 2
			scaleGizmo:AddBlock(Color.Orange,0,0,0)
			scaleGizmo.Pivot = { 0.5, 0.5, 0.5 }
			scaleGizmo.CollisionGroups = { 6 }
			scaleGizmo.onPress = function()
				self:setGizmoMode("scale")
			end
			self._scaleGizmo = scaleGizmo

			self._isInit = true
		end,
		toggle = function(self, object)
			if not self._isInit then self:_init() end

			-- clear current box
			self._rootEdges:RemoveFromParent()
			self._scaleGizmo:RemoveFromParent()

			self.object = object
			if not object then return end

			local shape = object
            local savedRotation = shape.Rotation:Copy()
            local box = Box()
            shape.Rotation = Number3(0,0,0)
            Timer(0.001, function()
                box:Fit(shape, true)
                print(box.Max - box.Min)
				shape.Rotation = savedRotation
				shape:Refresh()
				local isNotShape = type(object) ~= "Shape" and type(object) ~= "MutableShape"
				local w = isNotShape and 5 or (box.Max.X - box.Min.X)
				local h = isNotShape and 5 or (box.Max.Y - box.Min.Y)
				local d = isNotShape and 5 or (box.Max.Z - box.Min.Z)
				local pivot = isNotShape and Number3(2.5,2.5,2.5) or (shape.Position - box.Min + Number3(1,1,1))
				local size = Number3(w,h,d)
				local edgeSetups = {
					{ pos=-pivot,px=0,sx=w }, { pos=-pivot,py=0,sy=h }, { pos=-pivot,pz=0,sz=d },
					{ pos=-pivot+size,px=1,sx=w }, { pos=-pivot+size,py=1,sy=h }, { pos=-pivot+size,pz=1,sz=d },
					{ pos=-pivot+Number3(w,0,0),py=0,sy=h }, { pos=-pivot+Number3(w,0,0),pz=0,sz=d },
					{ pos=-pivot+Number3(0,h,0),px=0,sx=w }, { pos=-pivot+Number3(0,h,0),pz=0,sz=d },
					{ pos=-pivot+Number3(0,0,d),px=0,sx=w }, { pos=-pivot+Number3(0,0,d),py=0,sy=h }
				}

				self._rootEdges:SetParent(World)
				self._rootEdges.Position = object.Position
				self._rootEdges.Rotation = object.Rotation
				self._rootEdges.Scale = { 1, 1, 1 }
				for key,setup in ipairs(edgeSetups) do
					local b = self._edges[key]
					b.LocalPosition = setup.pos
					b.LocalRotation = { 0, 0, 0 }
					b.Pivot = { setup.px or 0.5, setup.py or 0.5, setup.pz or 0.5 }
					b.Scale = { setup.sx or 1, setup.sy or 1, setup.sz or 1 }
				end

				self._scaleGizmo:SetParent(object)
				self._scaleGizmo.IsHidden = false
				self._scaleGizmo.CollisionGroups = { 6 }
				self._scaleGizmo.LocalPosition = -pivot + Number3(w,h,0)
			end)
		end,
		pointerDown = function(self, pointerEvent)
			if not self.object then return end
			local impact = pointerEvent:CastRay({ 6 })
			if impact and impact.Object and impact.Object == self._scaleGizmo then
				self.dragGizmo = true
                Camera:SetModeFree()
			end
		end,
		pointerUp = function(self)
			self.dragGizmo = false
            Camera:SetModeThirdPerson()
		end,
		pointerDrag = function(self, pe)
			if not self.object or not self.dragGizmo then return end
			self.object.Scale = self.object.Scale + Number3(1,1,1) * (pe.DX / 60)
            if self.onScaleChange then self:onScaleChange(self.object.Scale) end
		end
	},
	__newIndex = function() print("Error: boxGizmo is read-only") end
}
setmetatable(boxGizmo, boxGizmoMetatable)

LocalEvent:Listen(LocalEvent.Name.PointerDown, function(pe)
	boxGizmo:pointerDown(pe)
end)
LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pe)
	boxGizmo:pointerDrag(pe)
end)
LocalEvent:Listen(LocalEvent.Name.PointerUp, function(pe)
	boxGizmo:pointerUp(pe)
end)

return boxGizmo