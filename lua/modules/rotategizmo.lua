--[[
    Example:

Client.OnStart = function()
	...

    rotateGizmo = require("rotategizmo"):create()

    Pointer:Show()

	-- Orientation can be Local or World
    rotateGizmo:setOrientation(rotateGizmo.Orientation.World)
	
    Shape:Load("caillef.fox", function(shape)
        shape:SetParent(Player)
        rotateGizmo:setShape(shape)
    end)

	-- Called when the gizmo is moved
	rotateGizmo.onDrag = function(rotation)
		print(rotation)
	end
	...
end

Pointer.Down = function(pe)
	local eventsCapturedByRotateGizmo = rotateGizmo:down(pe)
	if eventsCapturedByRotateGizmo then
		Camera:SetModeFree()
	end
end

Pointer.Drag = function(pe)
	rotateGizmo:drag(pe)
end

Pointer.Down = function(pe)
	local eventsCapturedByRotateGizmo = rotateGizmo:up(pe)
	if eventsCapturedByRotateGizmo then
		Camera:SetModeThirdPerson()
	end
end
]]--


local rotateGizmoFactory = {}
local rotateGizmoFactoryMetatable = {
	__index = {
		create = function()
			local rotateGizmo = {}
			local rotateGizmoMetatable = {
				__index = {
					Axis = { X=1, Y=2, Z=3 }, -- rotates around
					AxisName = { "X", "Y", "Z" },
					Orientation = { Local=1, World=2 },
					object = nil,
					gizmoCamera = nil,
					selectedHandle = nil,
					snap = 0,
					handles = {},
					_orientation = 1, -- Local by default
					_layer = 2,
					_isInit = false,
					-- empty objects to remember start situations
					_gizmoObjectCopy = nil, 
					_objectCopy = nil,
					_debug = false,

					_init = function(self)
						self.plane = require("plane")
						self.hierarchyActions = require("hierarchyactions")
						local polygonBuilder = require("polygonbuilder")

						-- Move this in gizmo module
						local gizmoCamera = Camera()
						gizmoCamera:SetParent(Camera)
						gizmoCamera.Layers = self._layer -- TODO: we need a way to ask for unused layer
						gizmoCamera.On = true
						gizmoCamera.Tick = function()
							self:_updateHandles()
						end
						self.gizmoCamera = gizmoCamera

						local gizmoObject = Object()
						self.gizmoObject = gizmoObject
						local axisColors = { Color.Red, Color.Blue, Color.Green }
						for axis,color in ipairs(axisColors) do
							local handle = polygonBuilder:create({
								nbSides = 16,
								color = color,
								thickness = 1,
								size = axis == self.Axis.X and 7 or axis == self.Axis.Y and 6.9 or 6.8
							})

							-- Apply options to each part of the circle
							self.hierarchyActions:applyToDescendants(handle, { includeRoot = true }, function(obj)
								pcall(function()
									obj.Layers = self._layer
								end)
								obj.axis = axis
							end)
							
							handle:SetParent(gizmoObject)
							
							if axis == self.Axis.X then
								handle.LocalRotation = {0, math.pi * 0.5, 0}
							elseif axis == self.Axis.Y then
								handle.LocalRotation = {math.pi * 0.5, 0, 0}
							end
							
							handle.setVisible = function(self, visible)
								if visible then
									handle:SetParent(gizmoObject)
								else
									handle:RemoveFromParent()
								end
							end

							self.handles[handle.axis] = handle
						end

						self._gizmoObjectCopy = Object()
						self._objectCopy = Object()

						if self._debug then
							self._rotationNormal = MutableShape()
							World:AddChild(self._rotationNormal)
							self._rotationNormal:AddBlock(Color.White,0,0,0)
							self._rotationNormal.Pivot = Number3(0.5,0.5,0)
							self._rotationNormal.Scale = Number3(0.02,0.02,20)
							-- self._rotationNormal.IsUnlit = true
							-- self._rotationNormal.Layers = self._layer
						end

						self._isInit = true
					end,
					_updateHandles = function(self)
						if not self.object then return end

						if self._orientation == self.Orientation.Local then
							self.gizmoObject.Rotation = self.object.Rotation
						else
							self.gizmoObject.Rotation = {0,0,0}
						end

						if type(self.object) == "Object" then
							self.gizmoObject.Position = self.object.Position
						else
							-- center gizmo if shape
							local localPos = Number3(self.object.Width * 0.5 - self.object.Pivot.X,
													self.object.Height * 0.5 - self.object.Pivot.Y,
													self.object.Depth * 0.5 - self.object.Pivot.Z)
							self.gizmoObject.Position = self.object:PositionLocalToWorld(localPos)
						end

						-- don't hide handles if moving gizmo
						if self.selectedHandle then return end

						for axis, handle in ipairs(self.handles) do
							local v = self.gizmoObject.Position - Camera.Position
							v:Normalize()
							local crossProduct = handle.Forward:Dot(v) - 0.001 -- Avoid glitch when attaching object to Camera
							handle.IsHidden = math.abs(crossProduct) <= 0.04 -- threshold to hide handle
						end
					end,
					setLayer = function(self, layer)
						if self.gizmoCamera then
							self.gizmoCamera.Layers = layer
						end
						for _,a in ipairs(self.handles) do
							-- Apply options to each part of the circle
							self.hierarchyActions:applyToDescendants(a, { includeRoot = true }, function(obj)
								pcall(function()
									obj.Layers = layer
								end)
							end)
						end
						self._layer = layer
					end,
					setObject = function(self, object)
						if not self._isInit then self:_init() end
						self.object = object
						if object == nil then
							self.gizmoObject:RemoveFromParent()
							self._gizmoObjectCopy:RemoveFromParent()
							self._objectCopy:RemoveFromParent()
							return
						end
						self.gizmoObject:SetParent(World)
						self._gizmoObjectCopy:SetParent(World)
						self._objectCopy:SetParent(World)

						self:_updateHandles()
					end,
					setOrientation = function(self, mode)
						if not self._isInit then self:_init() end
						self._orientation = mode
						self:_updateHandles()
					end,
					down = function(self, pe)
						if not self.object then return false end
						local ray = Ray(pe.Position, pe.Direction)

						local target = nil
						local handle

						for axis = self.Axis.X,self.Axis.Z do
							handle = self.handles[axis]
							for i= 1,handle.ChildrenCount do
								local part = handle:GetChild(i)
								local impact = ray:Cast(part)
								if impact then
									if target == nil or target.impact.Distance > impact.Distance then
										if target == nil then target = {} end
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

							if self.selectedHandle.axis == self.Axis.X then
								v1 = self._objectCopy.Forward
								v2 = self._objectCopy.Up
							elseif self.selectedHandle.axis == self.Axis.Y then
								v1 = self._objectCopy.Right
								v2 = self._objectCopy.Forward
							else
								v1 = self._objectCopy.Right
								v2 = self._objectCopy.Up
							end

							self.p = self.plane:New(self.impactPosition, v1, v2)

							return true
						end	

						self.selectedHandle = nil
						return false
					end,
					drag = function(self, pe)
						if not self.object or not self.selectedHandle then return false end
						local ray = Ray(pe.Position, pe.Direction)
						local pos = self.p:hit(ray)
						if pos == nil then return false end

						local p2 = self._gizmoObjectCopy:PositionWorldToLocal(pos)

						local dot = self._localImpactPosition:Dot(p2)

						local axis
						if self.selectedHandle.axis == self.Axis.X then
							if Camera.Forward:Dot(self._objectCopy.Right) >= 0 then
								axis = self._objectCopy.Right:Copy()
							else
								axis = self._objectCopy.Left:Copy()
							end
						elseif self.selectedHandle.axis == self.Axis.Y then
							if Camera.Forward:Dot(self._objectCopy.Up) >= 0 then
								axis = self._objectCopy.Up:Copy()
							else
								axis = self._objectCopy.Down:Copy()
							end
						else
							if Camera.Forward:Dot(self._objectCopy.Forward) >= 0 then
								axis = self._objectCopy.Forward:Copy()
							else
								axis = self._objectCopy.Backward:Copy()
							end
						end

						if self._debug then
							self._rotationNormal.Position = self._gizmoObjectCopy.Position
							self._rotationNormal.Forward = -axis
						end

						local cross = self._gizmoObjectCopy:PositionLocalToWorld(self._localImpactPosition:Cross(p2))
						local det = axis:Dot(cross)

						local angle = math.atan(det, dot)

						local snap = (self.snap or 0)
						if snap > 0 then
							angle = math.floor(angle / snap) * snap
						end

						-- print("" .. angle / math.pi * 180.0 .. "°")

						local o = Object()
						o.Rotation = self._objectCopy.Rotation
						o.Position = self._objectCopy.Position
						o:RotateWorld(axis, angle)

						self.object.Rotation = o.Rotation
						
						if self.onDrag then
							self.onDrag(self.object.Rotation)
						end
						return true	
					end,
					up = function(self, pe)
						if self.selectedHandle then
							self.selectedHandle = nil
							return true
						end
						return false
					end
				}
			}
			setmetatable(rotateGizmo, rotateGizmoMetatable)
			return rotateGizmo
		end
	}
}
setmetatable(rotateGizmoFactory, rotateGizmoFactoryMetatable)

return rotateGizmoFactory