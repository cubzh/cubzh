local gizmoFactory = {}
local gizmoFactoryMetatable = {
	__index = {
		create = function()
			local gizmo = {}
			local gizmoMetatable = {
				__index = {
					Orientation = { Local=1, World=2 },
					Mode = { Move=1, Rotate=2, Scale=3 },
					object = nil,
					gizmoCamera = nil,
					activeGizmo = nil,
					mode = 1,
					_layer = 2,
					_isInit = false,
					_init = function(self)
						local gizmoCamera = Camera()
						gizmoCamera:SetParent(Camera)
						gizmoCamera.Layers = self._layer -- TODO: we need a way to ask for unused layer
						gizmoCamera.On = true
						self.gizmoCamera = gizmoCamera
			
						local moveGizmo = require("movegizmo"):create()
						local rotateGizmo = require("rotategizmo"):create()
						local scaleGizmo = require("scalegizmo"):create()
			
						self._gizmos = { moveGizmo, rotateGizmo, scaleGizmo }
						for _,g in ipairs(self._gizmos) do
							g:_init()
							g.gizmoCamera.Tick = nil
							g.gizmoCamera.On = false
							g.gizmoCamera:RemoveFromParent()
							g.gizmoCamera = nil
						end
			
						gizmoCamera.Tick = function()
							if not self.activeGizmo then return end
							if self.activeGizmo._updateHandles ~= nil then self.activeGizmo:_updateHandles() end
						end
			
						self.activeGizmo = self._gizmos[self.mode]
						self._isInit = true
					end,
					setMode = function(self, mode)
						if not self._isInit then self:_init() end
					
						-- already current mode
						if mode == self.mode then return end
						local gizmo = self._gizmos[mode]
						if not gizmo then
							print("Error: parameter of gizmo:setMode is not a gizmo.Mode value")
							return
						end
			
						-- Hide previous gizmo
						if self.activeGizmo then
							self.activeGizmo:setObject(nil)
						end
			
						gizmo:setObject(self.object)
						self.activeGizmo = gizmo
						self.mode = mode
					end,
					setLayer = function(self, layer)
						if not self._isInit then self:_init() end
						self.gizmoCamera.Layers = layer
						for _,gizmo in ipairs(self._gizmos) do
							gizmo:setLayer(layer)
						end
					end,
					setSnap = function(self, mode, snap)
						if not self._isInit then self:_init() end
						self._gizmos[mode].snap = snap
					end,
					setObject = function(self, object)
						if not self._isInit then self:_init() end
						self.object = object
						self.activeGizmo:setObject(object)
					end,
					getObject = function(self)
						return self.object
					end,
					setAxisVisibility = function(self, xVisible, yVisible, zVisible)
						if not self._isInit then self:_init() end
						for _,gizmo in ipairs(self._gizmos) do
							gizmo.handles[gizmo.Axis.X]:setVisible(xVisible)
							gizmo.handles[gizmo.Axis.Y]:setVisible(yVisible)
							gizmo.handles[gizmo.Axis.Z]:setVisible(zVisible)
						end
					end,
					setGizmoScale = function(self, scale)
						if not self._isInit then self:_init() end
						for _,gizmo in ipairs(self._gizmos) do
							gizmo.gizmoObject.Scale = scale
						end
					end,
					setOrientation = function(self, mode)
						if not self._isInit then self:_init() end
						for _,gizmo in ipairs(self._gizmos) do
							gizmo:setOrientation(mode)
						end
					end,
					down = function(self, pe)
						return self.activeGizmo:down(pe)
					end,
					drag = function(self, pe)
						return self.activeGizmo:drag(pe)
					end,
					up = function(self, pe)
						return self.activeGizmo:up(pe)
					end
				}
			}
			setmetatable(gizmo, gizmoMetatable)
			return gizmo
		end
	}
}
setmetatable(gizmoFactory, gizmoFactoryMetatable)

return gizmoFactory