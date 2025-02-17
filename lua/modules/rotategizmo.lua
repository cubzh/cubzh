rotateGizmo = {
	Axis = { X = 1, Y = 2, Z = 3 },
	AxisName = { "X", "Y", "Z" },
	Orientation = { Local = 1, World = 2 },
}

plane = require("plane")
polygonBuilder = require("polygonbuilder")

local functions = {}

functions.show = function(self)
	self.hidden = false

	for _, l in ipairs(self.listeners) do
		l:Resume()
	end

	if self.object ~= nil then
		self.gizmoObject:SetParent(World)
	end
end

functions.hide = function(self)
	self.hidden = true

	for _, l in ipairs(self.listeners) do
		l:Pause()
	end

	self.gizmoObject:SetParent(nil)
end

functions.isShown = function(self)
	return self.gizmoObject.Parent ~= nil
end

functions.setLayer = function(self, layer)
	self.camera.Layers = layer
	for _, a in ipairs(self.handles) do
		a:Recurse(function(obj)
			pcall(function()
				obj.Layers = layer
			end)
		end, { includeRoot = true })
	end
end

functions.up = function(self, _)
	if self.selectedHandle then
		if self.onDragEnd then
			self.onDragEnd(self.object.Position)
		end
		self.selectedHandle = nil
		return true
	end
	return false
end

functions.drag = function(self, pe)
	if not self.object or not self.selectedHandle then
		return false
	end

	local ray = Ray(pe.Position, pe.Direction)
	local pos = self.p:hit(ray)

	if pos == nil then
		return false
	end

	local p2 = self.gizmoObject:PositionWorldToLocal(pos)

	local dot = self._localImpactPosition:Dot(p2)

	local axis
	if self.selectedHandle.axis == rotateGizmo.Axis.X then
		if self.camera.Forward:Dot(self._objectCopy.Right) >= 0 then
			axis = self._objectCopy.Right:Copy()
		else
			axis = self._objectCopy.Left:Copy()
		end
	elseif self.selectedHandle.axis == rotateGizmo.Axis.Y then
		if self.camera.Forward:Dot(self._objectCopy.Up) >= 0 then
			axis = self._objectCopy.Up:Copy()
		else
			axis = self._objectCopy.Down:Copy()
		end
	else
		if self.camera.Forward:Dot(self._objectCopy.Forward) >= 0 then
			axis = self._objectCopy.Forward:Copy()
		else
			axis = self._objectCopy.Backward:Copy()
		end
	end

	local cross = self._gizmoObjectCopy:PositionLocalToWorld(self._localImpactPosition:Cross(p2))
	local det = axis:Dot(cross)

	local angle = math.atan2(det, dot)

	local snap = (self.snap or 0)
	if snap > 0 then
		angle = math.floor(angle / snap) * snap
	end

	local o = Object()
	o.Rotation = self._objectCopy.Rotation
	o.Position = self._objectCopy.Position
	o:RotateWorld(axis, angle)

	self.object.Rotation = o.Rotation

	if self.onDrag then
		self.onDrag(self.object.Rotation)
	end
	return true
end

functions.down = function(self, pe)
	if not self.object then
		return false
	end

	local ray = Ray(pe.Position, pe.Direction)

	local target
	local handle

	for axis = rotateGizmo.Axis.X, rotateGizmo.Axis.Z do
		handle = self.handles[axis]
		for i = 1, handle.ChildrenCount do
			local part = handle:GetChild(i)
			local impact = ray:Cast(part)
			if impact then
				if target == nil or target.impact.Distance > impact.Distance then
					if target == nil then
						target = {}
					end
					target.handle = handle
					target.ray = ray
					target.impact = impact
				end
			end
		end
	end

	if target ~= nil then
		self.selectedHandle = target.handle

		self.impactPosition = target.ray.Origin + target.ray.Direction * target.impact.Distance

		self._gizmoObjectCopy.Position = self.gizmoObject.Position
		self._gizmoObjectCopy.Rotation = self.gizmoObject.Rotation

		self._objectCopy.Position = self.object.Position
		self._objectCopy.Rotation = self.object.Rotation

		self._localImpactPosition = self._gizmoObjectCopy:PositionWorldToLocal(self.impactPosition)
		self._localImpactPositionSqrLen = self._localImpactPosition.SquaredLength

		local v1, v2

		if self.selectedHandle.axis == rotateGizmo.Axis.X then
			v1 = self._objectCopy.Forward
			v2 = self._objectCopy.Up
		elseif self.selectedHandle.axis == rotateGizmo.Axis.Y then
			v1 = self._objectCopy.Right
			v2 = self._objectCopy.Forward
		else
			v1 = self._objectCopy.Right
			v2 = self._objectCopy.Up
		end

		self.p = plane:New(self.impactPosition, v1, v2)

		if self.onDragBegin then
			self.onDragBegin(self.object.Rotation)
		end

		return true
	end

	self.selectedHandle = nil
	return false
end

functions.setObject = function(self, object)
	if self.object == object then
		return
	end

	self.object = object
	if object == nil then
		self.gizmoObject:RemoveFromParent()
		return
	end

	self._objectCopy.Position = object.Position
	self._objectCopy.Rotation = object.Rotation

	if not self.hidden then
		self.gizmoObject:SetParent(World)
	end
	self:updateHandles()
end

functions.setOrientation = function(self, v)
	self.orientation = v
	self:updateHandles()
end

functions.updateHandles = function(self)
	if not self.object then
		return
	end

	if self.orientation == rotateGizmo.Orientation.Local then
		self.gizmoObject.Rotation = self._objectCopy.Rotation
	else
		self.gizmoObject.Rotation = { 0, 0, 0 }
	end

	self.gizmoObject.Position = self.object.Position

	-- Does not hide or rotate handles if moving gizmo
	if self.selectedHandle then
		return
	end

	for _, handle in ipairs(self.handles) do
		local v = self.gizmoObject.Position - self.camera.Position
		v:Normalize()
		local crossProduct = handle.Forward:Dot(v) - 0.001 -- Avoid glitch when attaching object to Camera
		handle.IsHidden = math.abs(crossProduct) <= 0.04 -- threshold to hide handle
	end
end

functions.setAxisVisibility = function(self, x, y, z)
	self.handles[rotateGizmo.Axis.X]:setVisible(x == true)
	self.handles[rotateGizmo.Axis.Y]:setVisible(y == true)
	self.handles[rotateGizmo.Axis.Z]:setVisible(z == true)
end

functions.setScale = function(self, scale)
	self.gizmoObject.Scale = scale
end

mt = {
	__gc = function(t)
		for _, l in ipairs(t.listeners) do
			l:Remove()
		end
		t.listeners = nil
	end,
	__index = {
		show = functions.show,
		hide = functions.hide,
		isShown = functions.isShown,
		setObject = functions.setObject,
		setOrientation = functions.setOrientation,
		updateHandles = functions.updateHandles,
		setAxisVisibility = functions.setAxisVisibility,
		setScale = functions.setScale,
		setLayer = functions.setLayer,
	},
	__metatable = false,
}

-- Variables shared by all gizmo instances:

local scale = 1.0
local layer = nil
local camera = Camera()
camera:SetParent(Camera)
camera.On = true

rotateGizmo.setLayer = function(_, l)
	layer = l
	camera.Layers = l
end
rotateGizmo.setLayer(2) -- TODO: we need a way to ask for unused layer

rotateGizmo.setScale = function(_, s)
	scale = s
end

rotateGizmo.create = function(_, config)
	local _config = { -- default config
		orientation = rotateGizmo.Orientation.World,
		snap = 0.0,
		scale = scale,
		camera = camera,
	}

	local function sameType(a, b)
		if type(a) == type(b) then
			return true
		end
		if type(a) == "number" and type(b) == "integer" then
			return true
		end
		if type(a) == "integer" and type(b) == "number" then
			return true
		end
		return false
	end

	if config ~= nil then
		for k, v in pairs(_config) do
			if sameType(v, config[k]) then
				_config[k] = config[k]
			end
		end
	end

	local g = {
		selectedHandle = nil,
		gizmoObject = nil,
		object = nil,
		orientation = _config.orientation,
		handles = {},
		snap = _config.snap,
		listeners = {},
		onDragBegin = nil,
		onDrag = nil,
		onDragEnd = nil,
		camera = _config.camera,
	}
	setmetatable(g, mt)

	g.gizmoObject = Object()

	g._gizmoObjectCopy = Object()
	g._objectCopy = Object()

	g.gizmoObject.Scale = _config.scale

	local axisColors = { Color.Red, Color.Green, Color.Blue }

	for axis, color in ipairs(axisColors) do
		local handle = polygonBuilder:create({
			nbSides = 16,
			color = color,
			thickness = 1,
			size = axis == rotateGizmo.Axis.X and 7 or axis == rotateGizmo.Axis.Y and 6.9 or 6.8,
		})

		-- Apply options to each part of the circle
		handle:Recurse(function(obj)
			pcall(function()
				obj.Layers = layer
			end)
			obj.axis = axis
			obj.Physics = PhysicsMode.Trigger
		end, { includeRoot = true })

		handle:SetParent(g.gizmoObject)
		handle.axis = axis

		if axis == rotateGizmo.Axis.X then
			handle.LocalRotation = { 0, math.pi * 0.5, 0 }
		elseif axis == rotateGizmo.Axis.Y then
			handle.LocalRotation = { math.pi * 0.5, 0, 0 }
		end

		handle.setVisible = function(_, visible)
			if visible then
				handle:SetParent(g.gizmoObject)
			else
				handle:RemoveFromParent()
			end
		end

		g.handles[handle.axis] = handle
	end

	local l = LocalEvent:Listen(LocalEvent.Name.PointerDown, function(pe)
		return functions.down(g, pe)
	end, { topPriority = true })
	table.insert(g.listeners, l)

	l = LocalEvent:Listen(LocalEvent.Name.PointerUp, function(pe)
		return functions.up(g, pe)
	end, { topPriority = true })
	table.insert(g.listeners, l)

	l = LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pe)
		return functions.drag(g, pe)
	end, { topPriority = true })
	table.insert(g.listeners, l)

	l = LocalEvent:Listen(LocalEvent.Name.Tick, function(_)
		g:updateHandles()
	end)
	table.insert(g.listeners, l)

	return g
end

return rotateGizmo
