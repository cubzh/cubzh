-- this module provides UI components and 3D handles to transform 3D objects.

gizmo = {}

ui = require("uikit")
conf = require("config")
ease = require("ease")
bundle = require("bundle")

function updatePosition(self)
	local config = self.config
	if not config then
		return
	end
	if not config.target then
		return
	end

	local pos = config.target:PositionLocalToWorld(config.offset)
	local screenPos = Camera:WorldToScreen(pos)

	if screenPos.X == nil or screenPos.Y == nil then
		self:hide()
		return
	else
		self:show()
	end

	self.pos = { screenPos.X * Screen.Width, screenPos.Y * Screen.Height }
end

grid = Quad()
grid.Height = 10000
grid.Width = 10000
-- grid.IsUnlit = true
grid.Color = Color(255, 255, 255, 254)
grid.Anchor = { 0.5, 0.5 }
-- grid.Image = bundle.Data("images/frame-black-32x32.png")
grid.Image = bundle.Data("images/frame-white-32x32.png")
grid.Tiling = Number2(2000, 2000)

defaultRadialHandleConfig = {
	image = "",
	text = "🙂",
	angle = 0,
	radius = 50,
	parentConfig = {},
	onRelease = function() end,
	onPress = function() end,
}

function addRadialHandle(root, config)
	config = conf:merge(defaultRadialHandleConfig, config)

	local btn = ui:createButton(config.text)
	btn:setParent(root)
	btn.pos = -Number2(btn.Width, btn.Height) * 0.5

	local angle = math.rad(config.angle)
	local v = Number2(math.cos(angle), math.sin(angle))
	local target = v * config.radius - Number2(btn.Width, btn.Height) * 0.5

	ease:outBack(btn, 0.3).pos = Number3(target.X, target.Y, 0)

	btn.onPress = config.onPress
	btn.onRelease = config.onRelease

	btn.config = config

	btn.onRemove = function(self)
		self.config = nil
	end

	return btn
end

defaultConfig = {
	target = nil,
	radius = 60,
	offset = { 0, 0, 0 },
}

function startMove(self)
	print("START MOVE")
	local target = self.config.parentConfig.target
	if not target then
		return
	end
	print("target OK")
	grid:SetParent(World)
	grid.Position = target.Position
	grid.Rotation = target.Rotation
end

function endMove(_)
	grid:SetParent(nil)
end

gizmo.create = function(self, config)
	if self ~= gizmo then
		error("transformgizmo:create(config) should be called with `:`")
	end

	config = conf:merge(
		defaultConfig,
		config,
		{ acceptTypes = { target = { "Object", "Shape", "MutableShape", "Player" }, offset = { "table", "Number3" } } }
	)

	local root = ui:createNode()
	root.config = config

	root.parentDidResize = function(self)
		updatePosition(self)
	end
	root:parentDidResize()

	-- addRadialHandle(root, { text = "C", angle = 0, radius = 0 }) -- center?

	addRadialHandle(root, {
		text = "M",
		angle = -140,
		radius = config.radius,
		parentConfig = config,
		onPress = startMove,
		onRelease = endMove,
	})
	addRadialHandle(root, { text = "R", angle = -90, radius = config.radius, parentConfig = config })
	addRadialHandle(root, { text = "S", angle = -40, radius = config.radius, parentConfig = config })

	addRadialHandle(root, { text = "P", angle = 40, radius = config.radius, parentConfig = config })

	root.listener = LocalEvent:Listen(LocalEvent.Name.Tick, function(_)
		updatePosition(root)
	end)

	root.onRemove = function()
		root.listener:Remove()
		root.listener = nil
		root.config = nil
	end

	return root
end

return gizmo
