-- Combines all 3 types of gizmos (move, rotate, scale)

gizmo = {
	Mode = { Move=1, Rotate=2, Scale=3 },
	Axis = { X=1, Y=2, Z=3 },
	AxisName = { "X", "Y", "Z" },
	Orientation = { Local=1, World=2 }
}

-- Variables shared by all gizmo instances:

local scale = 1.0
local layer = nil
local camera = Camera()
camera:SetParent(Camera)
camera.On = true

gizmo.setLayer = function(_, l)
	layer = l
	camera.Layers = l
end
gizmo.setLayer(2) -- TODO: we need a way to ask for unused layer

gizmo.setScale = function(_, s)
	scale = s
end

local functions = {}

functions.setObject = function(self, object)
	self.object = object
	for _, m in pairs(gizmo.Mode) do
		local g = self.gizmos[m]
		if g then
			if g.setObject then g:setObject(object) end
		end
	end
end

functions.getObject = function(self)
	return self.object
end

functions.setOrientation = function(self, orientation)
	self.orientation = orientation
	for _, m in pairs(gizmo.Mode) do
		local g = self.gizmos[m]
		if g then
			if g.setOrientation then g:setOrientation(orientation) end
		end
	end
end

functions.setAxisVisibility = function(self, x, y, z)
	for _, m in pairs(gizmo.Mode) do
		local g = self.gizmos[m]
		if g then
			if g.setAxisVisibility then g:setAxisVisibility(x, y, z) end
		end
	end
end

functions.setScale = function(self, scale)
	for _, m in pairs(gizmo.Mode) do
		local g = self.gizmos[m]
		if g then
			if g.setScale then g:setScale(scale) end
		end
	end
end

functions.setOnMove = function(self, fn)
	local g = self.gizmos[gizmo.Mode.Move]
	if g then g.onDrag = fn end
end

functions.setOnRotate = function(self, fn)
	local g = self.gizmos[gizmo.Mode.Rotate]
	if g then g.onDrag = fn end
end

functions.setOnScale = function(self, fn)
	local g = self.gizmos[gizmo.Mode.Scale]
	if g then g.onDrag = fn end
end

functions.setMoveSnap = function(self, v)
	self.moveSnap = v
	local g = self.gizmos[gizmo.Mode.Move]
	if g then g.snap = v end
end

functions.setRotateSnap = function(self, v)
	self.rotateSnap = v
	local g = self.gizmos[gizmo.Mode.Rotate]
	if g then g.snap = v end
end

functions.setScaleSnap = function(self, v)
	self.scaleSnap = v
	local g = self.gizmos[gizmo.Mode.Scale]
	if g then g.snap = v end
end

functions.setMode = function(self, mode)
	if mode ~= gizmo.Mode.Move and mode ~= gizmo.Mode.Rotate and mode ~= gizmo.Mode.Scale then
		return
	end
	self.mode = mode
	if self.gizmos[mode] == nil then
		if mode == gizmo.Mode.Move then
			local g = require("movegizmo"):create({ orientation = self.orientation,
													snap = self.moveSnap,
													scale = self.scale,
													camera = camera })
			g:setObject(self.object)
			g:setLayer(self.layer)
			g.onDrag = self.onMove
			self.gizmos[mode] = g

		elseif mode == gizmo.Mode.Rotate then
			local g = require("rotategizmo"):create({ orientation = self.orientation,
													snap = self.rotateSnap,
													scale = self.scale,
													camera = camera })
			g:setObject(self.object)
			g:setLayer(self.layer)
			g.onDrag = self.onMove
			self.gizmos[mode] = g

		elseif mode == gizmo.Mode.Scale then
			-- self.gizmos[mode] = require("scalegizmo"):create({ orientation = self.orientation, snap = self.scaleSnap, scale = self.scale })
			error("❌ scale gizmo not supported yet")
		end
	end

	for _, m in pairs(gizmo.Mode) do
		local g = self.gizmos[m]
		if g then
			if m == mode then
				if g.show then g:show() end
			else
				if g.hide then g:hide() end
			end
		end
	end
end

mt = {
	__index = {
		setObject = functions.setObject,
		getObject = functions.getObject,
		setOrientation = functions.setOrientation,
		setAxisVisibility = functions.setAxisVisibility,
		setScale = functions.setScale,
		setMode = functions.setMode,
		setOnMove = functions.setOnMove,
		setOnRotate = functions.setOnRotate,
		setOnScale = functions.setOnScale,
		setMoveSnap = functions.setMoveSnap,
		setRotateSnap = functions.setRotateSnap,
		setScaleSnap = functions.setScaleSnap,
	},
	__metatable = false,
}

gizmo.create = function(_, config)

	local _config = { -- default config
		orientation = gizmo.Orientation.World,
		mode = gizmo.Mode.Move,
		moveSnap = 0.0,
		rotateSnap = 0.0,
		scaleSnap = 0.0,
		scale = scale,
		onMove = function() end,
		onRotate = function() end,
		onScale = function() end,
	}

	local function sameType(a, b)
		if type(a) == type(b) then return true end
		if type(a) == "number" and type(b) == "integer" then return true end
		if type(a) == "integer" and type(b) == "number" then return true end
		return false
	end

	if config ~= nil then
		for k, v in pairs(_config) do
			if sameType(v, config[k]) then _config[k] = config[k] end
		end
	end

	local g = {
		object = nil,
		orientation = _config.orientation,
		mode = _config.mode,
		moveSnap = _config.moveSnap,
		rotateSnap = _config.rotateSnap,
		scaleSnap = _config.scaleSnap,
		onMove = _config.onMove,
		onRotate = _config.onRotate,
		onScale = _config.onScale,
		gizmos = {}, -- create them on demand
		scale = scale,
		layer = layer,
		camera = camera,
	}
	setmetatable(g, mt)

	g:setMode(g.mode) -- init with active mode

	return g
end

return gizmo