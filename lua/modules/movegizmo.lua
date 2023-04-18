--[[
    Example:

Client.OnStart = function()
	...

    moveGizmo = require("movegizmo"):create()

    Pointer:Show()

	-- Orientation can be Local or World
    moveGizmo:setOrientation(moveGizmo.Orientation.World)
	
    Shape:Load("caillef.fox", function(shape)
        shape:SetParent(Player)
        moveGizmo:setShape(shape)
    end)

	-- Called when the gizmo is moved
	moveGizmo.onDrag = function(position)
		print(position)
	end
	...
end

Pointer.Down = function(pe)
	local eventsCapturedByMoveGizmo = moveGizmo:down(pe)
	if eventsCapturedByMoveGizmo then
		Camera:SetModeFree()
	end
end

Pointer.Drag = function(pe)
	moveGizmo:drag(pe)
end

Pointer.Down = function(pe)
	local eventsCapturedByMoveGizmo = moveGizmo:up(pe)
	if eventsCapturedByMoveGizmo then
		Camera:SetModeThirdPerson()
	end
end
]]--

local moveGizmoFactory = {}
local moveGizmoFactoryMetatable = {
	__index = {
		create = function()
			local moveGizmo = {}
			local moveGizmoMetatable = {
				__index = {
					Axis = { X=1, Y=2, Z=3 },
					AxisName = { "X", "Y", "Z" },
					Orientation = { Local=1, World=2 },
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
						for axis,color in ipairs(axisColors) do
							local handle = MutableShape()
			
							handle:AddBlock(color,0,0,0)
							handle.Pivot = Number3(0.5,0.5,0)
							handle.Scale = Number3(1,1,10)
			
							handle.Layers = self._layer
							handle:SetParent(gizmoObject)
							
							handle.axis = axis
			
							handle.setVisible = function(self, visible)
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
						if not self.object then return end
			
						if self._orientation == self.Orientation.Local then
							self.gizmoObject.Rotation = self.object.Rotation
						else
							self.gizmoObject.Rotation = {0,0,0}
						end
			
						self.handles[self.Axis.X].Forward = self.gizmoObject.Right
						self.handles[self.Axis.Y].Forward = self.gizmoObject.Up
						self.handles[self.Axis.Z].Forward = self.gizmoObject.Forward
			
						  local checktype = type(self.object)
						if checktype == "Object" or checktype == "Player" then
							self.gizmoObject.Position = self.object.Position
						else
							-- center gizmo if shape
							local localPos = Number3(self.object.Width * 0.5 - self.object.Pivot.X,
													self.object.Height * 0.5 - self.object.Pivot.Y,
													self.object.Depth * 0.5 - self.object.Pivot.Z)
							self.gizmoObject.Position = self.object:PositionLocalToWorld(localPos)
						end
			
						-- Does not hide or rotate handles if moving gizmo
						if self.selectedHandle then return end
			
						for axis, handle in ipairs(self.handles) do
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
						for _,a in ipairs(self.handles) do
							a.Layers = layer
						end
						self._layer = layer
					end,
					setObject = function(self, object)
						if not self._isInit then self:_init() end
						self.object = object
						if object == nil then
							self.gizmoObject:RemoveFromParent()
							return
						end
						self.gizmoObject:SetParent(World)
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
						for axis=self.Axis.X, self.Axis.Z do
							local handle = self.handles[axis]
							local impact = ray:Cast(handle)
							if impact then
								self.selectedHandle = handle
			
								self.impactPosition = ray.Origin + ray.Direction * impact.Distance
								self.originalPosition = self.object.Position:Copy()
			
								if handle.axis == self.Axis.X then
									self.p = self.plane:New(self.impactPosition, handle.Forward, self.handles[self.Axis.Y].Forward)
									self.p2 = self.plane:New(self.impactPosition, handle.Forward, self.handles[self.Axis.Z].Forward)
								elseif handle.axis == self.Axis.Y then
									self.p = self.plane:New(self.impactPosition, handle.Forward, self.handles[self.Axis.X].Forward)
									self.p2 = self.plane:New(self.impactPosition, handle.Forward,self.handles[self.Axis.Z].Forward)
								elseif handle.axis == self.Axis.Z then
									self.p = self.plane:New(self.impactPosition, handle.Forward, self.handles[self.Axis.Y].Forward)
									self.p2 = self.plane:New(self.impactPosition, handle.Forward, self.handles[self.Axis.X].Forward)
								end
			
								return true
							end
						end
						self.selectedHandle = nil
						return false
					end,
					drag = function(self, pe)
						if not self.object or not self.selectedHandle then return false end
						local ray = Ray(pe.Position, pe.Direction)
						local pos = self.p:hit(ray)
						if pos == nil then return false end
			
						-- project pos on move axis
						pos = self.p2:hit(Ray(pos, self.p2.normal))
						if pos == nil then return false end
			
						-- get final pos
						pos = self.originalPosition + pos - self.impactPosition
			
						-- align if snap > 0
						local axisName = self.AxisName[self.selectedHandle.axis]
						local snap = (self.snap or 0)
						if snap > 0 then
							if self._orientation == self.Orientation.Local then
								pos = self.object:PositionWorldToLocal(pos)
							end
							pos[axisName] = math.floor(pos[axisName] / snap) * snap
							if self._orientation == self.Orientation.Local then
								pos = self.object:PositionLocalToWorld(pos)
							end
						end
			
						local currentLocalPos = self.object:PositionWorldToLocal(self.object.Position)
						if currentLocalPos[axisName] ~= self.object:PositionWorldToLocal(pos)[axisName] then
							self.object.Position = pos
							self.gizmoObject.Position = pos
						end
			
						if self.onDrag then
							self.onDrag(self.object.Position)
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
			setmetatable(moveGizmo, moveGizmoMetatable)
			return moveGizmo
		end
	} 
}
setmetatable(moveGizmoFactory, moveGizmoFactoryMetatable)

return moveGizmoFactory