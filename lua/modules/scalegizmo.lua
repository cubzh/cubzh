local scaleGizmoFactory = {}
local scaleGizmoFactoryMetatable = {
	__index = {
		create = function()
			local scaleGizmo = {}
			local scaleGizmoMetatable = {
				__index = {
					Axis = { X = 1, Y = 2, Z = 3 },
					AxisName = { "X", "Y", "Z" },
					Orientation = { Local = 1, World = 2 },
					object = nil,
					gizmoCamera = nil,
					selectedHandle = nil,
					snap = 0,
					handles = {},
					_orientation = 2, -- World by default
					_layer = 2,
					_isInit = false,
					_init = function(self)
						self.plane = require("plane")

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
						for axis, color in ipairs(axisColors) do
							local handle = MutableShape()

							handle:AddBlock(color, 0, 0, 0)
							handle.Pivot = Number3(0.5, 0.5, 0)
							handle.Scale = Number3(1, 1, 10)
							local handle2 = MutableShape()
							handle2:AddBlock(color, 0, 0, 0)
							handle2.Pivot = Number3(0.5, 0.5, 0.5)
							handle2.Scale = Number3(2.5, 2.5, 2.5)
							handle2:SetParent(handle)
							handle2.LocalPosition = Number3(0, 0, 10)

							if axis == self.Axis.X then
								handle.Forward = { 1, 0, 0 }
							elseif axis == self.Axis.Y then
								handle.Forward = { 0, 1, 0 }
							elseif axis == self.Axis.Z then
								handle.Forward = { 0, 0, 1 }
							end

							handle.Layers = self._layer
							handle:SetParent(gizmoObject)

							handle.axis = axis

							handle.setVisible = function(_, visible)
								if visible then
									handle:SetParent(gizmoObject)
								else
									handle:RemoveFromParent()
								end
							end

							self.handles[handle.axis] = handle
						end
						self._isInit = true
					end,
					_updateHandles = function(self)
						if not self.object then
							return
						end

						if self._orientation == self.Orientation.Local then
							self.gizmoObject.Rotation = self.object.Rotation
						else
							self.gizmoObject.Rotation = { 0, 0, 0 }
						end

						local checktype = type(self.object)
						if checktype == "Object" or checktype == "Player" then
							self.gizmoObject.Position = self.object.Position
						else
							-- center gizmo if shape
							local localPos = Number3(
								self.object.Width * 0.5 - self.object.Pivot.X,
								self.object.Height * 0.5 - self.object.Pivot.Y,
								self.object.Depth * 0.5 - self.object.Pivot.Z
							)
							self.gizmoObject.Position = self.object:PositionLocalToWorld(localPos)
						end

						-- Does not hide or rotate handles if moving gizmo
						if self.selectedHandle then
							return
						end

						for _, handle in ipairs(self.handles) do
							local v = self.gizmoObject.Position - Camera.Position
							v:Normalize()
							local crossProduct = handle.Forward:Dot(v) - 0.001 -- Avoid glitch when attaching object to Camera
							handle.IsHidden = math.abs(crossProduct) >= 0.98 -- threshold to hide handle
							-- Revert if camera on the other side, not for axis Y
							if crossProduct > 0 then
								handle.Forward = -handle.Forward
							end
						end
					end,
					setLayer = function(self, layer)
						if self.gizmoCamera then
							self.gizmoCamera.Layers = layer
						end
						for _, a in ipairs(self.handles) do
							a.Layers = layer
						end
						self._layer = layer
					end,
					setObject = function(self, object)
						if not self._isInit then
							self:_init()
						end
						self.object = object
						if object == nil then
							self.gizmoObject:RemoveFromParent()
							return
						end
						self.gizmoObject:SetParent(World)
						self:_updateHandles()
					end,
					setOrientation = function(self, mode)
						if not self._isInit then
							self:_init()
						end
						self._orientation = mode
						self:_updateHandles()
					end,
					down = function(self, pe)
						if not self.object then
							return false
						end
						local ray = Ray(pe.Position, pe.Direction)
						for axis = self.Axis.X, self.Axis.Z do
							local handle = self.handles[axis]
							local impact = ray:Cast(handle)
							if impact then
								self.selectedHandle = handle

								self.impactPosition = ray.Origin + ray.Direction * impact.Distance
								self.originalScale = self.object.Scale:Copy()

								if handle.axis == self.Axis.X then
									self.p = self.plane:New(
										self.impactPosition,
										handle.Forward,
										self.handles[self.Axis.Y].Forward
									)
									self.p2 = self.plane:New(
										self.impactPosition,
										handle.Forward,
										self.handles[self.Axis.Z].Forward
									)
								elseif handle.axis == self.Axis.Y then
									self.p = self.plane:New(
										self.impactPosition,
										handle.Forward,
										self.handles[self.Axis.X].Forward
									)
									self.p2 = self.plane:New(
										self.impactPosition,
										handle.Forward,
										self.handles[self.Axis.Z].Forward
									)
								elseif handle.axis == self.Axis.Z then
									self.p = self.plane:New(
										self.impactPosition,
										handle.Forward,
										self.handles[self.Axis.Y].Forward
									)
									self.p2 = self.plane:New(
										self.impactPosition,
										handle.Forward,
										self.handles[self.Axis.X].Forward
									)
								end

								return true
							end
						end
						self.selectedHandle = nil
						return false
					end,
					drag = function(
						self,
						pe, --[[ optional ]]
						isUniform
					)
						if not self.object or not self.selectedHandle then
							return false
						end
						local ray = Ray(pe.Position, pe.Direction)
						local pos = self.p:hit(ray)
						if pos == nil then
							return false
						end

						-- project pos on move axis
						pos = self.p2:hit(Ray(pos, self.p2.normal))
						if pos == nil then
							return false
						end

						-- get final scale
						local shift = (pos - self.impactPosition):Dot(self.p.v1)
						local axisName = self.AxisName[self.selectedHandle.axis]
						local scale
						if isUniform == true then
							scale = self.originalScale + shift * Number3(1, 1, 1)
						else
							scale = self.originalScale
								+ shift
									* Number3(
										axisName == "X" and 1 or 0,
										axisName == "Y" and 1 or 0,
										axisName == "Z" and 1 or 0
									)
						end

						-- align if snap > 0
						local snap = (self.snap or 0)
						local pobj = self.object:GetParent()
						if pobj ~= nil then
							snap = snap * self.object:GetParent().Scale[axisName]
						end
						if snap > 0 then
							scale[axisName] = math.floor(scale[axisName] / snap) * snap
						end

						local currentLocalScale = self.object.LocalPosition
						if currentLocalScale[axisName] ~= scale[axisName] then
							self.object.Scale = scale
						end

						if self.onDrag then
							self.onDrag(self.object.Position)
						end
						return true
					end,
					up = function(self, _)
						if self.selectedHandle then
							self.selectedHandle = nil
							return true
						end
						return false
					end,
				},
			}
			setmetatable(scaleGizmo, scaleGizmoMetatable)
			return scaleGizmo
		end,
	},
}
setmetatable(scaleGizmoFactory, scaleGizmoFactoryMetatable)

return scaleGizmoFactory
