Modules = {
	bundle = "bundle",
}

-- Dev.DisplayColliders = true
-- Dev.DisplayBoxes = true

Client.OnStart = function()
	ease = require("ease")
	particles = require("particles")

	drawerHeight = 0
	avatarLayers = 5
	avatarCamera = nil

	avatarCameraFocus = "body" -- body / head
	avatarCameraTarget = nil

	function getAvatarCameraTargetPosition(h, w)
		if avatarCameraTarget == nil then
			-- error("avatarCameraTarget should not be nil", 2)
			return nil
		end

		local _w = avatarCamera.TargetWidth
		local _h = avatarCamera.TargetHeight

		avatarCamera.TargetHeight = h
		avatarCamera.TargetWidth = w
		avatarCamera.Height = h
		avatarCamera.Width = w
		avatarCamera.TargetX = 0
		avatarCamera.TargetY = 0

		local box = Box()
		local pos = avatarCamera.Position:Copy()
		if avatarCameraFocus == "body" then
			box:Fit(avatarCameraTarget, { recursive = true })
			avatarCamera:FitToScreen(box, 0.7)
		elseif avatarCameraFocus == "head" then
			box:Fit(avatarCameraTarget.Head, { recursive = true })
			avatarCamera:FitToScreen(box, 0.5)
		elseif avatarCameraFocus == "eyes" then
			box:Fit(avatarCameraTarget.Head, { recursive = true })
			avatarCamera:FitToScreen(box, 0.6)
		elseif avatarCameraFocus == "nose" then
			box:Fit(avatarCameraTarget.Head, { recursive = true })
			avatarCamera:FitToScreen(box, 0.6)
		end

		local targetPos = avatarCamera.Position:Copy()

		-- restore
		avatarCamera.TargetHeight = _h
		avatarCamera.TargetWidth = _w
		avatarCamera.Height = _h
		avatarCamera.Width = _w
		avatarCamera.TargetX = 0
		avatarCamera.TargetY = 0
		avatarCamera.Position:Set(pos)

		return targetPos
	end

	local avatarCameraState = {}
	function layoutAvatarCamera(config)
		-- print("layoutAvatarCamera, drawerHeight:", drawerHeight)
		local h = Screen.Height - drawerHeight

		if
			avatarCameraState.h == h
			and avatarCameraState.screenWidth == Screen.Width
			and avatarCameraState.focus == avatarCameraFocus
			and avatarCameraState.target == avatarCameraTarget
		then
			-- nothing changed, early return
			return
		end

		local p = getAvatarCameraTargetPosition(h, Screen.Width)
		if p == nil then
			return
		end

		avatarCameraState.h = h
		avatarCameraState.screenWidth = Screen.Width
		avatarCameraState.focus = avatarCameraFocus
		avatarCameraState.target = avatarCameraTarget

		ease:cancel(avatarCamera)

		if config.noAnimation then
			avatarCamera.TargetHeight = h
			avatarCamera.TargetWidth = Screen.Width
			avatarCamera.Height = h
			avatarCamera.Width = Screen.Width
			avatarCamera.TargetX = 0
			avatarCamera.TargetY = 0
			avatarCamera.Position:Set(p)
			return
		end

		local anim = ease:inOutSine(avatarCamera, 0.2, {
			onDone = function()
				avatarCameraState.animation = nil
			end,
		})

		anim.TargetHeight = h
		anim.TargetWidth = Screen.Width
		anim.Height = h
		anim.Width = Screen.Width
		anim.TargetX = 0
		anim.TargetY = 0
		anim.Position = p
	end

	Camera:SetModeFree()
	Camera:SetParent(World)

	Sky.AbyssColor = Color(120, 0, 178)
	Sky.HorizonColor = Color(106, 73, 243)
	Sky.SkyColor = Color(121, 169, 255)
	Sky.LightColor = Color(100, 100, 100)

	titleScreen():show()

	LocalEvent:Listen("signup_flow_avatar_preview", function()
		titleScreen():hide()
		avatar():show({ mode = "demo" })
	end)

	LocalEvent:Listen("signup_flow_avatar_editor", function()
		titleScreen():hide()
		avatar():show({ mode = "user" })
	end)

	LocalEvent:Listen("signup_flow_dob", function()
		avatarCameraFocus = "body"
		layoutAvatarCamera()
	end)

	LocalEvent:Listen("signup_flow_start_or_login", function()
		titleScreen():show()
		avatar():hide()
	end)

	LocalEvent:Listen("signup_drawer_height_update", function(height)
		drawerHeight = height
		layoutAvatarCamera()
	end)

	light = Light()
	light.Color = Color(150, 150, 200)
	-- light.Color = Color(200, 200, 230)
	light.Intensity = 1.0
	light.CastsShadows = true
	light.On = true
	light.Type = LightType.Directional
	-- light.Layers = Camera.Layers + avatarLayers
	light.Layers = avatarLayers
	light.Layers = { 1, avatarLayers } -- Camera.Layers + avatarLayers
	World:AddChild(light)
	light.Rotation:Set(math.rad(20), math.rad(20), 0)

	Light.Ambient.SkyLightFactor = 0.2
	Light.Ambient.DirectionalLightFactor = 0.5

	avatarCamera = Camera()
	-- avatarCamera.Layers = Camera.Layers
	avatarCamera.Layers = avatarLayers
	avatarCamera:SetParent(World)
	avatarCamera.On = true
	-- avatarCamera.FOV = Camera.FOV

	LocalEvent:Listen(LocalEvent.Name.ScreenDidResize, function()
		layoutAvatarCamera()
	end)

	local logoTile = bundle:Data("images/logo-tile-rotated.png")

	backgroundQuad = Quad()
	backgroundQuad.IsDoubleSided = false
	backgroundQuad.Tiling = Number2(30, 30)
	backgroundQuad.Color = Color(0, 0, 0, 0.2)
	backgroundQuad.Image = logoTile
	backgroundQuad.Width = 500
	backgroundQuad.Height = 500
	backgroundQuad.Anchor = { 0.5, 0.5 }
	World:AddChild(backgroundQuad)

	local delta = Number2(-1, 1)
	speed = 0.2
	LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
		backgroundQuad.Offset = backgroundQuad.Offset + delta * dt * speed
	end)
end

-- Client.OnWorldObjectLoad = function(obj)
-- 	obj:RemoveFromParent()
-- end

local _titleScreen
function titleScreen()
	if _titleScreen then
		return _titleScreen
	end

	_titleScreen = {}

	local root
	local didResizeFunction
	local didResizeListener
	local tickListener

	_titleScreen.show = function()
		if root ~= nil then
			return
		end
		root = Object()
		root:SetParent(World)

		local logo = Object()
		local c = bundle:Shape("shapes/cubzh_logo_c")
		c.Shadow = true
		c.Pivot:Set(c.Width * 0.5, c.Height * 0.5, c.Depth * 0.5)
		c:SetParent(logo)

		local u = bundle:Shape("shapes/cubzh_logo_u")
		u.Pivot:Set(u.Width * 0.5, u.Height * 0.5, u.Depth * 0.5)
		u:SetParent(logo)

		local b = bundle:Shape("shapes/cubzh_logo_b")
		b.Pivot:Set(b.Width * 0.5, b.Height * 1.5 / 4.0, b.Depth * 0.5)
		b:SetParent(logo)

		local z = bundle:Shape("shapes/cubzh_logo_z")
		z.Pivot:Set(z.Width * 0.5, z.Height * 0.5, z.Depth * 0.5)
		z:SetParent(logo)

		local h = bundle:Shape("shapes/cubzh_logo_h")
		h.Pivot:Set(h.Width * 0.5, h.Height * 1.5 / 4.0, h.Depth * 0.5)
		h:SetParent(logo)

		local giraffe = bundle:Shape("shapes/giraffe_head")
		giraffe.Pivot:Set(giraffe.Width * 0.5, giraffe.Height * 0.5, giraffe.Depth * 0.5)
		giraffe:SetParent(root)
		giraffe.Scale = 1
		giraffe.LocalPosition:Set(0, 0, 12)
		giraffe.rot = Rotation(0, 0, math.rad(20))
		giraffe.Rotation:Set(giraffe.rot)

		local chest = bundle:Shape("shapes/chest")
		chest.Pivot:Set(chest.Width * 0.5, chest.Height * 0.5, chest.Depth * 0.5)
		chest:SetParent(root)
		chest.Scale = 0.5
		chest.LocalPosition:Set(7, -12, -7)
		chest.rot = Rotation(0, math.rad(25), math.rad(-5))
		chest.Rotation:Set(chest.rot)
		local chestLid = chest.Lid
		local chestLidRot = chest.Lid.LocalRotation:Copy()

		local pezh = bundle:Shape("shapes/pezh_coin_2")
		pezh.Pivot:Set(pezh.Size * 0.5)
		pezh:SetParent(root)
		pezh.Scale = 0.5
		pezh.LocalPosition:Set(-5, -12, -7)
		pezh.rot = Rotation(0, 0, math.rad(20))
		pezh.Rotation:Set(pezh.rot)

		local cube = bundle:Shape("shapes/cube")
		cube.Pivot:Set(cube.Size * 0.5)
		cube:SetParent(root)
		cube.Scale = 0.5
		cube.LocalPosition:Set(17, -8, -12)
		cube.rot = Rotation(0, 0, math.rad(20))
		cube.Rotation:Set(cube.rot)

		local sword = bundle:Shape("shapes/sword")
		sword.Pivot:Set(sword.Size * 0.5)
		sword:SetParent(root)
		sword.Scale = 0.5
		sword.LocalPosition:Set(-10, -10, -12)
		sword.rot = Rotation(0, 0, math.rad(-45))
		sword.Rotation:Set(sword.rot)

		local spaceship = bundle:Shape("shapes/spaceship_2")
		spaceship.Pivot:Set(spaceship.Size * 0.5)
		spaceship.Pivot.Y = spaceship.Pivot.Y + 55
		spaceship:SetParent(root)
		spaceship.Scale = 0.5
		spaceship.LocalPosition:Set(0, 0, 0)
		spaceship.rot = Rotation(0, math.rad(-30), math.rad(-30))
		spaceship.Rotation:Set(spaceship.rot)

		local space = 2
		local totalWidth = c.Width + u.Width + b.Width + z.Width + h.Width + space * 4

		c.LocalPosition.X = -totalWidth * 0.5 + c.Width * 0.5
		u.LocalPosition:Set(
			c.LocalPosition.X + c.Width * 0.5 + space + u.Width * 0.5,
			c.LocalPosition.Y,
			c.LocalPosition.Z
		)
		b.LocalPosition:Set(
			u.LocalPosition.X + u.Width * 0.5 + space + b.Width * 0.5,
			c.LocalPosition.Y,
			c.LocalPosition.Z
		)
		z.LocalPosition:Set(
			b.LocalPosition.X + b.Width * 0.5 + space + z.Width * 0.5,
			c.LocalPosition.Y,
			c.LocalPosition.Z
		)
		h.LocalPosition:Set(
			z.LocalPosition.X + z.Width * 0.5 + space + h.Width * 0.5,
			c.LocalPosition.Y,
			c.LocalPosition.Z
		)

		cRot = Rotation(0, 0, math.rad(10))
		uRot = Rotation(0, 0, math.rad(-10))
		bRot = Rotation(0, 0, math.rad(10))
		zRot = Rotation(0, 0, math.rad(-10))
		hRot = Rotation(0, 0, math.rad(10))

		c.Rotation = cRot
		u.Rotation = uRot
		b.Rotation = bRot
		z.Rotation = zRot
		h.Rotation = hRot

		local t = 0
		local t2 = 1
		local d1, d2, d3, d4, d5, d6, d7, d8
		tickListener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
			t = t + dt
			t2 = t2 + dt * 1.05
			d1 = math.sin(t) * math.rad(10)
			d2 = math.cos(t2) * math.rad(10)
			d3 = math.sin(t2) * math.rad(10)
			d4 = math.cos(t) * math.rad(10)

			d5 = math.sin(t) * math.rad(5)
			d6 = math.cos(t2) * math.rad(5)
			d7 = math.sin(t2) * math.rad(5)
			d8 = math.cos(t) * math.rad(5)

			c.Rotation = cRot * Rotation(d1, d2, 0)
			u.Rotation = uRot * Rotation(d2, d1, 0)
			b.Rotation = bRot * Rotation(d3, d4, 0)
			z.Rotation = zRot * Rotation(d4, d3, 0)
			h.Rotation = hRot * Rotation(d1, d3, 0)

			giraffe.Rotation = giraffe.rot * Rotation(d6, d5, 0)

			chest.Rotation = chest.rot * Rotation(d7, d8, 0)
			chestLid.LocalRotation = chestLidRot * Rotation(d5, 0, 0)

			-- spaceship.Rotation = spaceship.Rotation * Rotation(dt * 3, 0, 0)
		end)

		logo:SetParent(root)

		didResizeFunction = function()
			local box = Box()
			box:Fit(logo, { recursive = true })
			Camera:FitToScreen(box, 0.8)

			if backgroundQuad then
				backgroundQuad.Rotation = Camera.Rotation
				backgroundQuad.Position = Camera.Position + Camera.Forward * 150
			end
		end

		didResizeListener = LocalEvent:Listen(LocalEvent.Name.ScreenDidResize, didResizeFunction)
		didResizeFunction()
	end

	_titleScreen.hide = function()
		if root == nil then
			return
		end
		tickListener:Remove()
		tickListener = nil
		didResizeListener:Remove()
		didResizeFunction = nil

		root:RemoveFromParent()
		root = nil
	end

	return _titleScreen
end

local _avatar
function avatar()
	if _avatar then
		return _avatar
	end

	_avatar = {}

	local bundle = require("bundle")
	local avatarModule = require("avatar")

	local hairs = {
		bundle:Shape("shapes/signup_demo/air_goggles"),
		bundle:Shape("shapes/signup_demo/hair_pink_blue"),
		bundle:Shape("shapes/signup_demo/lofi_girl_head"),
		bundle:Shape("shapes/signup_demo/pink_pop_hair"),
		bundle:Shape("shapes/signup_demo/pirate_captain_hat"),
		bundle:Shape("shapes/signup_demo/santa_hair"),
	}

	local jackets = {
		bundle:Shape("shapes/signup_demo/astronaut_top"),
		bundle:Shape("shapes/signup_demo/cute_top"),
		bundle:Shape("shapes/signup_demo/lab_coat"),
		bundle:Shape("shapes/signup_demo/princess_dresstop"),
		bundle:Shape("shapes/signup_demo/red_robot_suit"),
		bundle:Shape("shapes/signup_demo/sweater"),
	}

	local pants = {
		bundle:Shape("shapes/signup_demo/overalls_pants"),
		bundle:Shape("shapes/signup_demo/jorts"),
		bundle:Shape("shapes/signup_demo/red_crewmate_pants"),
		bundle:Shape("shapes/signup_demo/stripe_pants2"),
	}

	local boots = {
		bundle:Shape("shapes/signup_demo/astronaut_shoes"),
		bundle:Shape("shapes/signup_demo/flaming_boots"),
		bundle:Shape("shapes/signup_demo/kids_shoes"),
		bundle:Shape("shapes/signup_demo/pirate_boots_01"),
	}

	local yaw = math.rad(-190)
	local pitch = 0

	-- local avatarCamera
	local root
	local listeners = {}
	local avatarLayers = 5

	local function drag(dx, dy)
		yaw = yaw - dx * 0.01
		pitch = math.min(math.rad(45), math.max(math.rad(-45), pitch + dy * 0.01))
		if root then
			root.LocalRotation = Rotation(pitch, 0, 0) * Rotation(0, yaw, 0)
		end
	end

	local mode = "demo" -- demo / user

	local emitter
	local particlesColor = Color(0, 0, 0)

	_avatar.show = function(self, config)
		if root ~= nil then
			if mode == config.mode then
				return
			end
			self:hide()
		end

		if emitter == nil then
			emitter = particles:newEmitter({
				acceleration = -Config.ConstantAcceleration,
				velocity = function()
					local v = Number3(0, 0, math.random(40, 50))
					v:Rotate(math.random() * math.pi * 2, math.random() * math.pi * 2, 0)
					return v
				end,
				life = 3.0,
				scale = function()
					return 0.7 + math.random() * 1.0
				end,
				layers = avatarLayers,
				color = function()
					return particlesColor
				end,
			})
		end

		mode = config.mode

		local hierarchyactions = require("hierarchyactions")

		root = Object()

		local avatar = avatarModule:get({
			usernameOrId = "",
			-- size = math.min(Screen.Height * 0.5, Screen.Width * 0.75),
			-- ui = ui,
			eyeBlinks = mode == "demo" and false or true,
		})

		avatar:SetParent(root)
		root.avatar = avatar

		hierarchyactions:applyToDescendants(root, { includeRoot = true }, function(o)
			pcall(function()
				o.Layers = avatarLayers
			end)
		end)

		avatar.Animations.Walk:Stop()
		avatar.Animations.Idle:Play()

		local b = Box()
		b:Fit(avatar, { recursive = true, ["local"] = true })
		avatar.LocalPosition.Y = -b.Size.Y * 0.5

		if mode == "demo" then
			avatar:loadEquipment({ type = "hair", shape = hairs[1] })
			avatar:loadEquipment({ type = "jacket", shape = jackets[1] })
			avatar:loadEquipment({ type = "pants", shape = pants[1] })
			avatar:loadEquipment({ type = "boots", shape = boots[1] })
		end

		local l = LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pe)
			drag(pe.DX, pe.DY)
		end)
		drag(0, 0)
		table.insert(listeners, l)

		l = LocalEvent:Listen(LocalEvent.Name.ScreenDidResize, function()
			layoutAvatarCamera()
		end)

		table.insert(listeners, l)

		l = LocalEvent:Listen("avatar_editor_should_focus_on_head", function()
			avatarCameraFocus = "head"
			layoutAvatarCamera()
		end)
		table.insert(listeners, l)

		l = LocalEvent:Listen("avatar_editor_should_focus_on_eyes", function()
			avatarCameraFocus = "eyes"
			layoutAvatarCamera()
		end)
		table.insert(listeners, l)

		l = LocalEvent:Listen("avatar_editor_should_focus_on_nose", function()
			avatarCameraFocus = "nose"
			layoutAvatarCamera()
		end)
		table.insert(listeners, l)

		l = LocalEvent:Listen("avatar_editor_should_focus_on_body", function()
			avatarCameraFocus = "body"
			layoutAvatarCamera()
		end)
		table.insert(listeners, l)

		l = LocalEvent:Listen("signup_flow_avatar_preview", function()
			avatarCameraFocus = "body"
			layoutAvatarCamera()
		end)
		table.insert(listeners, l)

		local didAttachEquipmentParts = function(equipmentParts)
			for _, part in ipairs(equipmentParts) do
				ease:cancel(part)
				local scale = part.Scale:Copy()
				part.Scale = part.Scale * 0.8
				ease:outBack(part, 0.2).Scale = scale
			end
		end

		l = LocalEvent:Listen("avatar_editor_update", function(config)
			if config.skinColorIndex then
				local colors = avatarModule.skinColors[config.skinColorIndex]
				local avatar = root.avatar
				avatar:setColors({
					skin1 = colors.skin1,
					skin2 = colors.skin2,
					nose = colors.nose,
					mouth = colors.mouth,
				})

				ease:cancel(root)
				root.Scale = 0.8
				ease:outBack(root, 0.2).Scale = Number3(1.0, 1.0, 1.0)

				particlesColor = colors.skin1
				emitter.Position = root.Position
				emitter:spawn(10)
			end
			if config.eyesIndex then
				avatar:setEyes({
					index = config.eyesIndex,
					-- color = avatarModule.eyeColors[math.random(1, #avatarModule.eyeColors)],
				})
			end
			if config.noseIndex then
				avatar:setNose({ index = config.noseIndex })
			end
			if config.jacket then
				avatar:loadEquipment({
					type = "jacket",
					item = config.jacket,
					didAttachEquipmentParts = didAttachEquipmentParts,
				})
			end
			if config.hair then
				avatar:loadEquipment({
					type = "hair",
					item = config.hair,
					didAttachEquipmentParts = didAttachEquipmentParts,
				})
			end
			if config.pants then
				avatar:loadEquipment({
					type = "pants",
					item = config.pants,
					didAttachEquipmentParts = didAttachEquipmentParts,
				})
			end
			if config.boots then
				avatar:loadEquipment({
					type = "boots",
					item = config.boots,
					didAttachEquipmentParts = didAttachEquipmentParts,
				})
			end
		end)
		table.insert(listeners, l)

		local i = 8
		local r
		local eyesIndex = 1
		local eyesCounter = 1
		local eyesTrigger = 3
		if mode == "demo" then
			changeTimer = Timer(0.3, true, function()
				r = math.random(1, #avatarModule.skinColors)
				if r == i then
					r = i + 1
					if r > #avatarModule.skinColors then
						r = 1
					end
				end
				i = r
				local colors = avatarModule.skinColors[i]
				local avatar = root.avatar
				avatar:setColors({
					skin1 = colors.skin1,
					skin2 = colors.skin2,
					nose = colors.nose,
					mouth = colors.mouth,
				})
				eyesCounter = eyesCounter + 1
				if eyesCounter >= eyesTrigger then
					eyesCounter = 0
					eyesIndex = eyesIndex + 1
					if eyesIndex > #avatarModule.eyes then
						eyesIndex = 1
					end
					avatar:setEyes({
						index = eyesIndex,
						color = avatarModule.eyeColors[math.random(1, #avatarModule.eyeColors)],
					})
					avatar:setNose({
						index = math.random(1, #avatarModule.noses),
					})
				end

				avatar:loadEquipment({ type = "hair", shape = hairs[math.random(1, #hairs)] })
				avatar:loadEquipment({ type = "jacket", shape = jackets[math.random(1, #jackets)] })
				avatar:loadEquipment({ type = "pants", shape = pants[math.random(1, #pants)] })
				avatar:loadEquipment({ type = "boots", shape = boots[math.random(1, #boots)] })
			end)
		end

		avatarCameraTarget = nil

		root:SetParent(World)
		root.IsHidden = true

		Timer(0.03, function()
			root.IsHidden = false
			avatarCameraTarget = root
			layoutAvatarCamera({ noAnimation = true })
		end)

		return root
	end

	_avatar.hide = function()
		if root == nil then
			return
		end

		local avatar = root.avatar
		avatar:loadEquipment({ type = "jacket", item = "" })
		avatar:loadEquipment({ type = "hair", item = "" })
		avatar:loadEquipment({ type = "pants", item = "" })
		avatar:loadEquipment({ type = "boots", item = "" })

		if changeTimer then
			changeTimer:Cancel()
			changeTimer = nil
		end

		for _, l in ipairs(listeners) do
			l:Remove()
		end
		listeners = {}
		root:RemoveFromParent()
		root = nil

		emitter:RemoveFromParent()
		emitter = nil
	end

	return _avatar
end

Client.DirectionalPad = nil
