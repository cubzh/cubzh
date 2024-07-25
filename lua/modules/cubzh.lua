-- Modules = {
-- 	bundle = "bundle",
-- }

bundle = require("bundle")

config = {
	WORLD_CELL_SIZE = 150,
	ITEM_CELL_SIZE = 150,
	FRIEND_CELL_SIZE = 100,
	TINY_PADDING = 2,
	CELL_PADDING = 5,
	LOAD_CONTENT_DELAY = 0.3,
}

Client.OnStart = function()
	Screen.Orientation = "portrait" -- force portrait

	Clouds.On = false

	api = require("api")
	ease = require("ease")
	particles = require("particles")

	drawerHeight = 0

	avatarCameraFocus = "body" -- body / head
	avatarCameraTarget = nil

	backgroundCamera = Camera()
	backgroundCamera.Projection = ProjectionMode.Orthographic
	backgroundCamera.On = true
	backgroundCamera.Layers = { 6 }
	World:AddChild(backgroundCamera)

	backgroundCamera.ViewOrder = 1
	Camera.ViewOrder = 2

	function getAvatarCameraTargetPosition(h, w)
		if avatarCameraTarget == nil then
			return nil
		end

		local _w = Camera.TargetWidth
		local _h = Camera.TargetHeight

		Camera.TargetHeight = h
		Camera.TargetWidth = w
		Camera.Height = h
		Camera.Width = w
		Camera.TargetX = 0
		Camera.TargetY = 0

		local box = Box()
		local pos = Camera.Position:Copy()
		if avatarCameraFocus == "body" then
			box:Fit(avatarCameraTarget, { recursive = true })
			Camera:FitToScreen(box, 0.7)
		elseif avatarCameraFocus == "head" then
			box:Fit(avatarCameraTarget.Head, { recursive = true })
			Camera:FitToScreen(box, 0.5)
		elseif avatarCameraFocus == "eyes" then
			box:Fit(avatarCameraTarget.Head, { recursive = true })
			Camera:FitToScreen(box, 0.6)
		elseif avatarCameraFocus == "nose" then
			box:Fit(avatarCameraTarget.Head, { recursive = true })
			Camera:FitToScreen(box, 0.6)
		end

		local targetPos = Camera.Position:Copy()

		-- restore
		Camera.TargetHeight = _h
		Camera.TargetWidth = _w
		Camera.Height = _h
		Camera.Width = _w
		Camera.TargetX = 0
		Camera.TargetY = 0
		Camera.Position:Set(pos)

		return targetPos
	end

	local avatarCameraState = {}
	function layoutCamera(config)
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

		ease:cancel(Camera)

		if config.noAnimation then
			Camera.TargetHeight = h
			Camera.TargetWidth = Screen.Width
			Camera.Height = h
			Camera.Width = Screen.Width
			Camera.TargetX = 0
			Camera.TargetY = 0
			Camera.Position:Set(p)
			return
		end

		local anim = ease:inOutSine(Camera, 0.2, {
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
		layoutCamera()
	end)

	LocalEvent:Listen("signup_flow_start_or_login", function()
		titleScreen():show()
		avatar():hide()
	end)

	LocalEvent:Listen("signup_drawer_height_update", function(height)
		drawerHeight = height
		layoutCamera()
	end)

	LocalEvent:Listen("signup_flow_login_success", function(height)
		drawerHeight = 0
		titleScreen():hide()
		home():show()
		layoutCamera({ noAnimation = true })
	end)

	light = Light()
	light.Color = Color(150, 150, 200)
	light.Intensity = 1.0
	light.CastsShadows = true
	light.On = true
	light.Type = LightType.Directional
	World:AddChild(light)
	light.Rotation:Set(math.rad(5), math.rad(-20), 0)

	Light.Ambient.SkyLightFactor = 0.2
	Light.Ambient.DirectionalLightFactor = 0.5

	local logoTile = bundle:Data("images/logo-tile-rotated.png")

	backgroundQuad = Quad()
	backgroundQuad.IsUnlit = true
	backgroundQuad.IsDoubleSided = true
	backgroundQuad.Color = { gradient = "V", from = Color(166, 96, 255), to = Color(72, 102, 209) }
	backgroundQuad.Width = Screen.RenderWidth
	backgroundQuad.Height = Screen.RenderHeight
	backgroundQuad.Anchor = { 0.5, 0.5 }
	backgroundQuad.Layers = { 6 }
	World:AddChild(backgroundQuad)
	backgroundQuad.Position.Z = 2

	backgroundLogo = Quad()
	backgroundLogo.IsUnlit = true
	backgroundLogo.IsDoubleSided = true
	backgroundLogo.Color = Color(255, 255, 255, 0.1)
	backgroundLogo.Image = logoTile
	backgroundLogo.Width = math.max(Screen.RenderWidth, Screen.RenderHeight)
	backgroundLogo.Height = backgroundLogo.Width
	backgroundLogo.Tiling = backgroundLogo.Width / Number2(100, 100)
	backgroundLogo.Anchor = { 0.5, 0.5 }
	backgroundLogo.Layers = { 6 }
	World:AddChild(backgroundLogo)
	backgroundLogo.Position.Z = 1

	local delta = Number2(-1, 1)
	speed = 0.2
	LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
		backgroundLogo.Offset = backgroundLogo.Offset + delta * dt * speed
	end)

	if Client.LoggedIn then
		home():show()
	else
		titleScreen():show()
	end
	layoutCamera({ noAnimation = true })
end

Screen.DidResize = function()
	if backgroundQuad then
		backgroundQuad.Width = Screen.RenderWidth
		backgroundQuad.Height = Screen.RenderHeight
		backgroundLogo.Width = math.max(Screen.RenderWidth, Screen.RenderHeight)
		backgroundLogo.Height = backgroundLogo.Width
		backgroundLogo.Tiling = backgroundLogo.Width / Number2(100, 100)
	end
end

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

		drawerHeight = 0
		layoutCamera({ noAnimation = true })

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

		local titleShapes = {}

		local function addShape(name, config)
			local s = bundle:Shape(name)
			s:SetParent(root)
			s.Pivot:Set(s.Size * 0.5)
			s.Scale = config.scale or 1
			s.LocalPosition:Set(config.position or Number3.Zero)
			s.rot = config.rotation or Rotation(0, 0, 0)
			s.Rotation:Set(s.rot)
			table.insert(titleShapes, s)
			return s
		end

		addShape(
			"shapes/giraffe_head",
			{ scale = 1, position = Number3(0, 0, 12), rotation = Rotation(0, 0, math.rad(20)) }
		)

		local chest = addShape(
			"shapes/chest",
			{ scale = 0.7, position = Number3(7, -18, -7), rotation = Rotation(0, math.rad(25), math.rad(-5)) }
		)
		local chestLid = chest.Lid
		chest.Coins.IsUnlit = true
		local chestLidRot = chest.Lid.LocalRotation:Copy()

		addShape(
			"shapes/pezh_coin_2",
			{ scale = 0.7, position = Number3(-5, -12, -7), rotation = Rotation(0, 0, math.rad(20)) }
		)

		addShape(
			"shapes/cube",
			{ scale = 0.7, position = Number3(18, -9, -12), rotation = Rotation(0, 0, math.rad(20)) }
		)

		addShape("shapes/paint_set", {
			scale = 0.7,
			position = Number3(-22, 12, 6),
			rotation = Rotation(math.rad(-60), math.rad(20), math.rad(-20)),
		})

		addShape(
			"shapes/pizza_slice",
			{ scale = 0.7, position = Number3(12, 8, -5), rotation = Rotation(math.rad(-40), math.rad(-20), 0) }
		)

		addShape("shapes/smartphone", {
			scale = 0.7,
			position = Number3(30, 8, 20),
			rotation = Rotation(math.rad(10), math.rad(30), math.rad(-20)),
		})

		addShape(
			"shapes/sword",
			{ scale = 0.7, position = Number3(-14, -12, 7), rotation = Rotation(0, 0, math.rad(-45)) }
		)

		addShape("shapes/spaceship_2", {
			scale = 0.5,
			position = Number3(-15, -22, -14),
			rotation = Rotation(math.rad(-10), math.rad(-30), math.rad(-30)),
		})

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
		local d1, d2, d3, d4, d5

		local modifiers = {}
		local nbModifiers = 5
		local modifier
		local r
		for i = 1, nbModifiers do
			r = math.random(1, 2)
			modifier = {
				t = 0,
				dtCoef = 1 + math.random() * 0.10,
				amplitude = math.rad(math.random(5, 10)),
			}
			if r == 1 then
				modifier.fn1 = math.cos
				modifier.fn2 = math.sin
			else
				modifier.fn1 = math.sin
				modifier.fn2 = math.cos
			end
			modifiers[i] = modifier
		end

		tickListener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
			t = t + dt
			t2 = t2 + dt * 1.05
			d1 = math.sin(t) * math.rad(10)
			d2 = math.cos(t2) * math.rad(10)
			d3 = math.sin(t2) * math.rad(10)
			d4 = math.cos(t) * math.rad(10)

			d5 = math.sin(t) * math.rad(5)

			c.Rotation = cRot * Rotation(d1, d2, 0)
			u.Rotation = uRot * Rotation(d2, d1, 0)
			b.Rotation = bRot * Rotation(d3, d4, 0)
			z.Rotation = zRot * Rotation(d4, d3, 0)
			h.Rotation = hRot * Rotation(d1, d3, 0)

			chestLid.LocalRotation = chestLidRot * Rotation(d5, 0, 0)

			for _, modifier in ipairs(modifiers) do
				modifier.t = t + dt * modifier.dtCoef
				modifier.rot = Rotation(
					modifier.fn1(modifier.t) * modifier.amplitude,
					modifier.fn2(modifier.t) * modifier.amplitude,
					0
				)
			end

			for i, s in ipairs(titleShapes) do
				modifier = modifiers[(i % nbModifiers) + 1]
				s.Rotation = s.rot * modifier.rot
			end
		end)

		logo:SetParent(root)

		didResizeFunction = function()
			layoutCamera({ noAnimation = true })
			local box = Box()
			box:Fit(logo, { recursive = true })
			Camera:FitToScreen(box, 0.8)
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

function shuffle(array)
	local n = #array
	for i = n, 2, -1 do
		local j = math.random(i)
		array[i], array[j] = array[j], array[i]
	end
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
		bundle:Shape("shapes/signup_demo/elf_hair"),
		bundle:Shape("shapes/signup_demo/sennin_head"),
		bundle:Shape("shapes/signup_demo/geek_long_hair"),
		bundle:Shape("shapes/signup_demo/elvis"),
		bundle:Shape("shapes/signup_demo/wolf_cut"),
		bundle:Shape("shapes/signup_demo/luffy_hair"),
		bundle:Shape("shapes/signup_demo/crown"),
		bundle:Shape("shapes/signup_demo/raccoon_head"),
		bundle:Shape("shapes/signup_demo/just_hair"),
		bundle:Shape("shapes/signup_demo/grass_cubzh"),
	}
	local hairsCurrentIndex = 0
	local hairsRandomIndexes = {}
	for i = 1, #hairs do
		table.insert(hairsRandomIndexes, i)
	end
	shuffle(hairsRandomIndexes)

	local jackets = {
		bundle:Shape("shapes/signup_demo/astronaut_top"),
		bundle:Shape("shapes/signup_demo/cute_top"),
		bundle:Shape("shapes/signup_demo/lab_coat"),
		bundle:Shape("shapes/signup_demo/princess_dresstop"),
		bundle:Shape("shapes/signup_demo/red_robot_suit"),
		bundle:Shape("shapes/signup_demo/sweater"),
		bundle:Shape("shapes/signup_demo/jedi_tunic"),
	}

	local jacketsCurrentIndex = 0
	local jacketsRandomIndexes = {}
	for i = 1, #jackets do
		table.insert(jacketsRandomIndexes, i)
	end
	shuffle(jacketsRandomIndexes)

	local pants = {
		bundle:Shape("shapes/signup_demo/overalls_pants"),
		bundle:Shape("shapes/signup_demo/jorts"),
		bundle:Shape("shapes/signup_demo/red_crewmate_pants"),
		bundle:Shape("shapes/signup_demo/stripe_pants2"),
	}

	local pantsCurrentIndex = 0
	local pantsRandomIndexes = {}
	for i = 1, #pants do
		table.insert(pantsRandomIndexes, i)
	end
	shuffle(pantsRandomIndexes)

	local boots = {
		bundle:Shape("shapes/signup_demo/astronaut_shoes"),
		bundle:Shape("shapes/signup_demo/flaming_boots"),
		bundle:Shape("shapes/signup_demo/kids_shoes"),
		bundle:Shape("shapes/signup_demo/pirate_boots_01"),
	}

	local bootsCurrentIndex = 0
	local bootsRandomIndexes = {}
	for i = 1, #boots do
		table.insert(bootsRandomIndexes, i)
	end
	shuffle(bootsRandomIndexes)

	local defaultHair = bundle:Shape("shapes/default_hair")
	local defaultJacket = bundle:Shape("shapes/default_jacket")
	local defaultPants = bundle:Shape("shapes/default_pants")
	local defaultShoes = bundle:Shape("shapes/default_shoes")

	local yaw = math.rad(-190)
	local pitch = 0

	local root
	local listeners = {}

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
				color = function()
					return particlesColor
				end,
			})
		end

		mode = config.mode

		root = Object()

		local eyeBlinks = true
		if mode == "demo" then
			eyeBlinks = false
		end

		local avatar = avatarModule:get({
			usernameOrId = Player.UserID,
			-- size = math.min(Screen.Height * 0.5, Screen.Width * 0.75),
			-- ui = ui,
			eyeBlinks = eyeBlinks,
		})

		avatar:SetParent(root)
		root.avatar = avatar

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
		else
			avatar:loadEquipment({ type = "hair", shape = defaultHair })
			avatar:loadEquipment({ type = "jacket", shape = defaultJacket })
			avatar:loadEquipment({ type = "pants", shape = defaultPants })
			avatar:loadEquipment({ type = "boots", shape = defaultShoes })
		end

		local l = LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pe)
			drag(pe.DX, pe.DY)
		end)
		drag(0, 0)
		table.insert(listeners, l)

		l = LocalEvent:Listen(LocalEvent.Name.ScreenDidResize, function()
			layoutCamera()
		end)

		table.insert(listeners, l)

		l = LocalEvent:Listen("avatar_editor_should_focus_on_head", function()
			avatarCameraFocus = "head"
			layoutCamera()
		end)
		table.insert(listeners, l)

		l = LocalEvent:Listen("avatar_editor_should_focus_on_eyes", function()
			avatarCameraFocus = "eyes"
			layoutCamera()
		end)
		table.insert(listeners, l)

		l = LocalEvent:Listen("avatar_editor_should_focus_on_nose", function()
			avatarCameraFocus = "nose"
			layoutCamera()
		end)
		table.insert(listeners, l)

		l = LocalEvent:Listen("avatar_editor_should_focus_on_body", function()
			avatarCameraFocus = "body"
			layoutCamera()
		end)
		table.insert(listeners, l)

		l = LocalEvent:Listen("signup_flow_avatar_preview", function()
			avatarCameraFocus = "body"
			layoutCamera()
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
				})
			end
			if config.eyesColorIndex then
				avatar:setEyes({
					color = avatarModule.eyeColors[config.eyesColorIndex],
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

				hairsCurrentIndex = hairsCurrentIndex + 1
				if hairsCurrentIndex > #hairsRandomIndexes then
					shuffle(hairsRandomIndexes)
					hairsCurrentIndex = 1
				end

				avatar:loadEquipment({
					type = "hair",
					shape = hairs[hairsRandomIndexes[hairsCurrentIndex]],
					didAttachEquipmentParts = didAttachEquipmentParts,
				})

				jacketsCurrentIndex = jacketsCurrentIndex + 1
				if jacketsCurrentIndex > #jacketsRandomIndexes then
					shuffle(jacketsRandomIndexes)
					jacketsCurrentIndex = 1
				end

				avatar:loadEquipment({
					type = "jacket",
					shape = jackets[jacketsRandomIndexes[jacketsCurrentIndex]],
					didAttachEquipmentParts = didAttachEquipmentParts,
				})

				pantsCurrentIndex = pantsCurrentIndex + 1
				if pantsCurrentIndex > #pantsRandomIndexes then
					shuffle(pantsRandomIndexes)
					pantsCurrentIndex = 1
				end

				avatar:loadEquipment({
					type = "pants",
					shape = pants[pantsRandomIndexes[pantsCurrentIndex]],
					didAttachEquipmentParts = didAttachEquipmentParts,
				})

				bootsCurrentIndex = bootsCurrentIndex + 1
				if bootsCurrentIndex > #bootsRandomIndexes then
					shuffle(bootsRandomIndexes)
					bootsCurrentIndex = 1
				end

				avatar:loadEquipment({
					type = "boots",
					shape = boots[bootsRandomIndexes[bootsCurrentIndex]],
					didAttachEquipmentParts = didAttachEquipmentParts,
				})
			end)
		end

		avatarCameraTarget = nil

		root:SetParent(World)
		root.IsHidden = true

		Timer(0.03, function()
			root.IsHidden = false
			avatarCameraTarget = root
			layoutCamera({ noAnimation = true })
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

local _home
function home()
	if _home then
		return _home
	end

	_home = {}

	local theme = require("uitheme").current
	local ui = require("uikit")
	local uiAvatar = require("ui_avatar")

	local root
	-- local didResizeFunction
	-- local didResizeListener
	-- local tickListener

	_home.show = function()
		if root ~= nil then
			return
		end

		-- backgroundCamera.On = false

		root = ui:frame() -- { color = Color(255, 0, 0, 0.3) }
		root.parentDidResize = function(self)
			self.Width = Screen.Width
			self.Height = Screen.Height
		end
		root:parentDidResize()

		local profileCell -- cell to showcase avatar

		local padding = theme.padding

		local recycledWorldCells = {}
		local recycledWorldIcons = {}
		local worldIcons = {}
		local worldThumbnails = {} -- cache for loaded world thumbnails

		local recycledItemCells = {}
		local recycledItemLoadingShapes = {}
		local itemLoadingShapes = {}
		local itemShapes = {} -- cache for loaded items
		local activeItemShapes = {}

		local recycledFriendCells = {}
		local friendAvatarCache = {}

		local cellSelector = ui:frameScrollCellSelector()
		cellSelector:setParent(nil)

		local t = 0.0
		tickListener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
			t = t + dt
			for icon, _ in pairs(worldIcons) do
				icon.pivot.LocalRotation:Set(-0.1, t, -0.2)
			end

			for itemShape, _ in pairs(activeItemShapes) do
				itemShape.pivot.LocalRotation:Set(-0.1, t, -0.2)
			end

			for loadingShape, _ in pairs(itemLoadingShapes) do
				loadingShape.pivot.LocalRotation:Set(-0.1, t, -0.2)
			end
		end)

		local function cellResizeFn(self)
			self.Width = self.parent.Width
			self.title.pos = { padding, self.Height - self.title.Height - padding }

			if self.scroll then
				self.scroll.pos = { padding, padding }
				self.scroll.Height = self.Height - self.title.Height - padding * 3
				self.scroll.Width = self.Width - padding * 2
			end
		end

		local function worldCellResizeFn(self)
			self.Height = self.parent.Height

			if self.shape then
				self.shape.pos = { 0, 0 }
				self.shape.Height = self.Height
				self.shape.Width = self.Width
				self.shape.pivot.LocalRotation:Set(-0.1, 0, -0.2)
			end

			if self.loadingShape then
				self.loadingShape.pos = { 0, 0 }
				self.loadingShape.Height = self.Height
				self.loadingShape.Width = self.Width
				self.loadingShape.pivot.LocalRotation:Set(-0.1, 0, -0.2)
			end

			if self.itemShape then
				self.itemShape.pos = { 0, 0 }
				self.itemShape.Height = self.Height
				self.itemShape.Width = self.Width
				self.itemShape.pivot.LocalRotation:Set(-0.1, 0, -0.2)
			end

			if self.avatar then
				self.avatar.pos = { padding, padding }
				self.avatar.Height = self.Height - padding * 2
				self.avatar.Width = self.Width - padding * 2
			end

			if self.thumbnail then
				self.thumbnail.pos = { padding, padding }
				self.thumbnail.Width = self.Width - padding * 2
				self.thumbnail.Height = self.Height - padding * 2
			end
		end

		local function requestWorlds(dataFetcher, config)
			if dataFetcher.req then
				dataFetcher.req:Cancel()
			end

			dataFetcher.req = api:getWorlds({
				category = config.category,
				sortBy = config.sortBy,
				fields = { "title", "created", "updated", "views", "likes" },
			}, function(worlds, err)
				if err ~= nil then
					return
				end

				dataFetcher.entities = worlds
				dataFetcher.nbEntities = #worlds

				if dataFetcher.scroll then
					dataFetcher.scroll:refresh()
				end

				if dataFetcher.displayNumberOfEntries and dataFetcher.row and dataFetcher.title then
					dataFetcher.row.title.Text = dataFetcher.title .. " (" .. dataFetcher.nbEntities .. ")"
				end
			end)
		end

		local function recycleWorldCellShape(cell)
			if cell.shape ~= nil then
				cell.shape:setParent(nil)
				table.insert(recycledWorldIcons, cell.shape)
				worldIcons[cell.shape] = nil
				cell.shape = nil
			end
		end

		local function recycleWorldCell(cell)
			recycleWorldCellShape(cell)
			if cell.thumbnail ~= nil then
				cell.thumbnail:setParent(nil)
				cell.thumbnail = nil
			end
			if cell.loadThumbnailTimer then
				cell.loadThumbnailTimer:Cancel()
				cell.loadThumbnailTimer = nil
			end
			if cell.req then
				cell.req:Cancel()
				cell.req = nil
			end
			cell:setParent(nil)
			table.insert(recycledWorldCells, cell)
		end

		local function getOrCreateWorldCell(world, category)
			local cell = table.remove(recycledWorldCells)

			if cell == nil then
				cell = ui:frameScrollCell()
				cell.Width = config.WORLD_CELL_SIZE

				local titleFrame = ui:frame({ color = Color(0, 0, 0, 0.5) })
				titleFrame:setParent(cell)
				titleFrame.pos = { padding, padding }
				titleFrame.LocalPosition.Z = -500 -- ui.kForegroundDepth

				local title = ui:createText("…", Color.White, "small")
				title:setParent(titleFrame)
				title.pos = { 2, 2 }

				cell.titleFrame = titleFrame
				cell.title = title

				cell.parentDidResize = worldCellResizeFn

				cell.onPress = function(self)
					cellSelector:setParent(self)
					cellSelector.Width = self.Width
					cellSelector.Height = self.Height
				end

				cell.onRelease = function(self)
					Menu:ShowWorld({ world = self.world })
				end

				cell.onCancel = function(_)
					cellSelector:setParent(nil)
				end
			end

			cell.category = category or ""

			if world then
				local thumbnail = worldThumbnails[cell.category .. "_" .. world.id]
				if thumbnail ~= nil then
					thumbnail:setParent(cell)
					cell.thumbnail = thumbnail
					recycleWorldCellShape(cell)
				else
					cell.loadThumbnailTimer = Timer(config.LOAD_CONTENT_DELAY, function()
						cell.req = api:getWorldThumbnail(world.id, function(img, err)
							if err ~= nil then
								return
							end

							local thumbnail = ui:frame({ image = img })
							thumbnail:setParent(cell)
							cell.thumbnail = thumbnail
							worldThumbnails[cell.category .. "_" .. world.id] = thumbnail
							recycleWorldCellShape(cell)
							worldCellResizeFn(cell)
						end)

						-- placeholder shape, waiting for thumbnail
						local item = table.remove(recycledWorldIcons)
						if item == nil then
							local shape = bundle:Shape("shapes/world_icon")
							item = ui:createShape(shape, { spherized = true })
						end

						item:setParent(cell)
						cell.shape = item
						worldIcons[item] = true
						cell:parentDidResize()
					end)
				end

				cell.world = world
				cell.title.Text = world.title
			else
				cell.title.Text = "…"
			end

			cell.title.object.MaxWidth = cell.Width - (padding + config.TINY_PADDING) * 2
			cell.titleFrame.Width = cell.title.Width + config.TINY_PADDING * 2
			cell.titleFrame.Height = cell.title.Height + config.TINY_PADDING * 2

			return cell
		end

		-- ITEMS

		local function prettifyItemName(str)
			local s = string.gsub(str, "_%a", string.upper)
			s = string.gsub(s, "_", " ")
			s = string.gsub(s, "^%l", string.upper)
			return s
		end

		local function requestItems(dataFetcher, config)
			if dataFetcher.req then
				dataFetcher.req:Cancel()
			end

			dataFetcher.req = api:getItems({
				category = config.category,
				sortBy = config.sortBy,
				fields = { "repo", "name", "created", "updated", "likes" },
			}, function(items, err)
				if err ~= nil then
					return
				end

				dataFetcher.entities = items
				dataFetcher.nbEntities = #items

				if dataFetcher.scroll then
					dataFetcher.scroll:refresh()
				end

				if dataFetcher.displayNumberOfEntries and dataFetcher.row and dataFetcher.title then
					dataFetcher.row.title.Text = dataFetcher.title .. " (" .. dataFetcher.nbEntities .. ")"
				end
			end)
		end

		local function recycleItemCellLoadingShape(cell)
			local loadingShape = cell.loadingShape
			if loadingShape ~= nil then
				loadingShape:setParent(nil)
				table.insert(recycledItemLoadingShapes, loadingShape)
				itemLoadingShapes[loadingShape] = nil
				cell.loadingShape = nil
			end
		end

		local function recycleItemCell(cell)
			recycleItemCellLoadingShape(cell)
			if cell.loadShapeTimer then
				cell.loadShapeTimer:Cancel()
				cell.loadShapeTimer = nil
			end
			if cell.req then
				cell.req:Cancel()
				cell.req = nil
			end
			if cell.itemShape then
				activeItemShapes[cell.itemShape] = nil
				cell.itemShape:setParent(nil)
				cell.itemShape = nil
			end
			cell:setParent(nil)
			table.insert(recycledItemCells, cell)
		end

		local function getOrCreateItemCell(item, category)
			local cell = table.remove(recycledItemCells)

			if cell == nil then
				cell = ui:frameScrollCell()
				cell.Width = config.ITEM_CELL_SIZE

				local titleFrame = ui:frame({ color = Color(0, 0, 0, 0.5) })
				titleFrame:setParent(cell)
				titleFrame.pos = { padding, padding }
				titleFrame.LocalPosition.Z = -500 -- ui.kForegroundDepth

				local title = ui:createText("…", Color.White, "small")
				title:setParent(titleFrame)
				title.pos = { 2, 2 }

				cell.titleFrame = titleFrame
				cell.title = title

				cell.parentDidResize = worldCellResizeFn

				cell.onPress = function(self)
					cellSelector:setParent(self)
					cellSelector.Width = self.Width
					cellSelector.Height = self.Height
				end

				cell.onRelease = function(self)
					Menu:ShowItem({ item = self.item })
				end

				cell.onCancel = function(_)
					cellSelector:setParent(nil)
				end
			end

			cell.category = category or ""
			cell.item = item

			if cell.item then
				local item = cell.item
				local itemShape = itemShapes[cell.category .. "_" .. item.repo .. "." .. item.name]
				if itemShape ~= nil then
					-- print("USE CACHED itemShape:", cell.category .. "_" .. item.repo .. "." .. item.name, itemShape)
					itemShape:setParent(cell)
					activeItemShapes[itemShape] = true
					cell.itemShape = itemShape
					recycleItemCellLoadingShape(cell)
				else
					cell.loadShapeTimer = Timer(config.LOAD_CONTENT_DELAY, function()
						cell.req = Object:Load(item.repo .. "." .. item.name, function(obj)
							if obj == nil then
								return
							end

							local itemShape = ui:createShape(obj, { spherized = true })
							cell.itemShape = itemShape
							itemShape:setParent(cell)
							activeItemShapes[itemShape] = true
							itemShape.pivot.LocalRotation:Set(-0.1, 0, -0.2)

							-- print("CACHE itemShape:", cell.category .. "_" .. item.repo .. "." .. item.name, itemShape)
							itemShapes[cell.category .. "_" .. item.repo .. "." .. item.name] = itemShape

							recycleItemCellLoadingShape(cell)
							cell:parentDidResize()
						end)

						-- placeholder shape, waiting for thumbnail
						local loadingShape = table.remove(recycledItemLoadingShapes)
						if loadingShape == nil then
							local shape = bundle:Shape("shapes/world_icon")
							loadingShape = ui:createShape(shape, { spherized = true })
						end

						loadingShape:setParent(cell)
						cell.loadingShape = loadingShape
						itemLoadingShapes[loadingShape] = true
						cell:parentDidResize()
					end)
				end
				cell.title.Text = prettifyItemName(item.name)
			else
				cell.title.Text = "…"
			end

			cell.title.object.MaxWidth = cell.Width - (padding + config.TINY_PADDING) * 2
			cell.titleFrame.Width = cell.title.Width + config.TINY_PADDING * 2
			cell.titleFrame.Height = cell.title.Height + config.TINY_PADDING * 2

			return cell
		end

		local function requestFriends(dataFetcher)
			if dataFetcher.req then
				dataFetcher.req:Cancel()
			end

			dataFetcher.req = api:getFriends({ fields = { "id", "username", "lastSeen" } }, function(friends, err)
				if err ~= nil then
					return
				end

				local function sortByLastSeen(a, b)
					if a.lastSeen ~= nil and b.lastSeen ~= nil then
						return a.lastSeen > b.lastSeen
					end
					return a.id > b.id
				end

				table.sort(friends, sortByLastSeen)

				dataFetcher.entities = friends
				dataFetcher.nbEntities = #friends

				if dataFetcher.scroll then
					dataFetcher.scroll:refresh()
				end

				if dataFetcher.row and dataFetcher.title then
					dataFetcher.row.title.Text = dataFetcher.title .. " (" .. dataFetcher.nbEntities .. ")"
				end
			end)
		end

		local function getOrCreateFriendCell()
			local cell = table.remove(recycledFriendCells)

			if cell == nil then
				cell = ui:frameScrollCell()
				cell.Width = config.FRIEND_CELL_SIZE
				cell.parentDidResize = worldCellResizeFn

				cell.onPress = function(self)
					cellSelector:setParent(self)
					cellSelector.Width = self.Width
					cellSelector.Height = self.Height
				end

				cell.onRelease = function(self)
					Menu:ShowProfile({ id = self.userID, username = self.username })
				end

				cell.onCancel = function(_)
					cellSelector:setParent(nil)
				end
			end

			-- worldIcons[item] = true
			return cell
		end

		local function recycleFriendCell(cell)
			if cell.avatar then
				cell.avatar:setParent(nil)
				cell.avatar = nil
			end
			cell:setParent(nil)
			table.insert(recycledFriendCells, cell)
		end

		local categoryUnusedCells = {}
		local categoryCells = {}
		local categories = {
			{
				title = "👥 Friends",
				displayNumberOfEntries = true,
				cellSize = config.FRIEND_CELL_SIZE,
				loadCell = function(index, dataFetcher)
					if index <= dataFetcher.nbEntities then
						local friend = dataFetcher.entities[index]
						local friendCell = getOrCreateFriendCell()

						local avatar = friendAvatarCache[index]
						if avatar == nil then
							avatar = uiAvatar:getHeadAndShoulders({
								usernameOrId = friend.id,
								backgroundColor = Color(49, 51, 57),
							})
							friendAvatarCache[index] = avatar
						end
						avatar:setParent(friendCell)

						friendCell.userID = friend.id
						friendCell.username = friend.username

						local usernameFrame = ui:frame({ color = Color(0, 0, 0, 0.5) })
						usernameFrame:setParent(avatar)
						usernameFrame.LocalPosition.Z = ui.kForegroundDepth

						local username = ui:createText(friend.username, Color.White, "small")
						username:setParent(usernameFrame)
						username.pos = { 2, 2 }

						usernameFrame.Width = username.Width + 4
						usernameFrame.Height = username.Height + 4

						avatar.username = username
						avatar.usernameFrame = usernameFrame

						friendCell.avatar = avatar

						return friendCell
					end
				end,
				unloadCell = function(_, cell)
					recycleFriendCell(cell)
				end,
				extraSetup = function(dataFetcher)
					requestFriends(dataFetcher)
				end,
			},
			{
				title = "✨ Featured Worlds",
				cellSize = config.WORLD_CELL_SIZE,
				loadCell = function(index, dataFetcher)
					if index <= dataFetcher.nbEntities then
						local world = dataFetcher.entities[index]
						return getOrCreateWorldCell(world, "featured")
					end
				end,
				unloadCell = function(_, cell)
					recycleWorldCell(cell)
				end,
				extraSetup = function(dataFetcher)
					requestWorlds(dataFetcher, { category = "featured" })
				end,
			},
			{
				title = "😛 Fun with friends",
				cellSize = config.WORLD_CELL_SIZE,
				loadCell = function(index, dataFetcher)
					if index <= dataFetcher.nbEntities then
						local world = dataFetcher.entities[index]
						return getOrCreateWorldCell(world, "fun_with_friends")
					end
				end,
				unloadCell = function(_, cell)
					recycleWorldCell(cell)
				end,
				extraSetup = function(dataFetcher)
					requestWorlds(dataFetcher, { category = "fun_with_friends" })
				end,
			},
			{
				title = "🤠 Playing solo",
				cellSize = config.WORLD_CELL_SIZE,
				loadCell = function(index, dataFetcher)
					if index <= dataFetcher.nbEntities then
						local world = dataFetcher.entities[index]
						return getOrCreateWorldCell(world, "solo")
					end
				end,
				unloadCell = function(_, cell)
					recycleWorldCell(cell)
				end,
				extraSetup = function(dataFetcher)
					requestWorlds(dataFetcher, { category = "solo" })
				end,
			},
			{
				title = "🍏 New Items",
				cellSize = config.ITEM_CELL_SIZE,
				loadCell = function(index, dataFetcher)
					if index <= dataFetcher.nbEntities then
						local item = dataFetcher.entities[index]
						return getOrCreateItemCell(item, "popular_items")
					end
				end,
				unloadCell = function(_, cell)
					recycleItemCell(cell)
				end,
				extraSetup = function(dataFetcher)
					requestItems(dataFetcher, { sortBy = "updatedAt:desc" })
				end,
			},
			{
				title = "❤️ Top Rated",
				cellSize = config.WORLD_CELL_SIZE,
				loadCell = function(index, dataFetcher)
					if index <= dataFetcher.nbEntities then
						local world = dataFetcher.entities[index]
						return getOrCreateWorldCell(world, "top_rated")
					end
				end,
				unloadCell = function(_, cell)
					recycleWorldCell(cell)
				end,
				extraSetup = function(dataFetcher)
					requestWorlds(dataFetcher, { sortBy = "likes:desc" })
				end,
			},
			{
				title = "⚔️ Popular Items",
				cellSize = config.ITEM_CELL_SIZE,
				loadCell = function(index, dataFetcher)
					if index <= dataFetcher.nbEntities then
						local item = dataFetcher.entities[index]
						return getOrCreateItemCell(item, "popular_items")
					end
				end,
				unloadCell = function(_, cell)
					recycleItemCell(cell)
				end,
				extraSetup = function(dataFetcher)
					requestItems(dataFetcher, { sortBy = "likes:desc" })
				end,
			},
		}
		local nbCategories = #categories

		local function createCategoryCell(category)
			cell = ui:frameGenericContainer()
			cell.parentDidResize = cellResizeFn

			local title = ui:createText("Title", Color.White)
			title:setParent(cell)

			cell.Height = title.Height + (category.cellSize or 100) + padding * 3 + config.CELL_PADDING * 2
			cell.title = title
			return cell
		end

		local scroll
		scroll = ui:createScroll({
			-- backgroundColor = Color(0, 255, 0, 0.3),
			-- gradientColor = Color(37, 23, 59), -- Color(155, 97, 250),
			padding = {
				top = Screen.SafeArea.Top + config.CELL_PADDING,
				bottom = config.CELL_PADDING,
				left = config.CELL_PADDING,
				right = config.CELL_PADDING,
			},
			cellPadding = config.CELL_PADDING,
			loadCell = function(index)
				if index == 1 then
					if profileCell == nil then
						local homeAvatar = uiAvatar:get({ usernameOrId = Player.UserID, spherized = false })

						-- profileCell = ui:frame({ color = Color(0, 0, 0, 0.5) })
						profileCell = ui:frame()
						profileCell.Height = 150

						local usernameFrame = ui:frame({ color = Color(0, 0, 0, 0.5) })
						usernameFrame:setParent(profileCell)

						local username = ui:createText(Player.Username, Color.White)
						username:setParent(usernameFrame)

						local editAvatarBtn = ui:buttonNeutral({ content = "✏️ Edit avatar" })
						editAvatarBtn:setParent(profileCell)

						editAvatarBtn.onRelease = function(_)
							if bottomBar then
								bottomBar:hide()
							end
							scroll:hide()
							avatar():show({ mode = "user" })

							drawer = require("drawer"):create({ ui = ui })

							local okBtn = ui:buttonPositive({
								content = "Done!",
								textSize = "big",
								unfocuses = false,
								padding = 5,
							})
							okBtn:setParent(drawer)
							okBtn.onRelease = function()
								drawer:remove()
								if bottomBar then
									bottomBar:show()
								end
								scroll:show()
								drawer = nil
								avatar():hide()
							end

							avatarEditor = require("ui_avatar_editor"):create({
								ui = ui,
								requestHeightCallback = function(height)
									drawer:updateConfig({
										layoutContent = function(self)
											local drawerHeight = height + padding * 2 + Screen.SafeArea.Bottom
											drawerHeight = math.floor(math.min(Screen.Height * 0.6, drawerHeight))

											self.Height = drawerHeight

											if avatarEditor then
												avatarEditor.Width = self.Width - padding * 2
												avatarEditor.Height = drawerHeight
													- Screen.SafeArea.Bottom
													- padding * 2
												avatarEditor.pos = { padding, Screen.SafeArea.Bottom + padding }
											end

											okBtn.pos = {
												self.Width - okBtn.Width - padding,
												self.Height + padding,
											}

											-- layoutInfoFrame()
											LocalEvent:Send("signup_drawer_height_update", drawerHeight)
										end,
									})
									drawer:bump()
								end,
							})

							avatarEditor:setParent(drawer)
							drawer:show()
						end

						local visitHouseBtn = ui:buttonNeutral({ content = "🏠 Visit house" })
						visitHouseBtn:setParent(profileCell)
						visitHouseBtn:disable()

						homeAvatar:setParent(profileCell)

						profileCell.parentDidResize = function(self)
							self.Width = self.parent.Width

							usernameFrame.Width = username.Width + padding * 2
							usernameFrame.Height = username.Height + config.TINY_PADDING * 2

							local infoWidth = math.max(username.Width, editAvatarBtn.Width, visitHouseBtn.Width)

							local infoHeight = math.max(
								usernameFrame.Height + editAvatarBtn.Height + visitHouseBtn.Height + padding * 2
							)
							local totalWidth = infoWidth + homeAvatar.Width + padding

							homeAvatar.Height = self.Height * 0.9
							homeAvatar.pos = {
								self.Width * 0.5 - totalWidth * 0.5,
								self.Height * 0.5 - homeAvatar.Height * 0.5,
							}

							local y = self.Height * 0.5 + infoHeight * 0.5 - username.Height
							local x = homeAvatar.pos.X + homeAvatar.Width + padding

							usernameFrame.pos = { x, y }

							username.pos = { padding, config.TINY_PADDING }
							y = y - padding - editAvatarBtn.Height
							editAvatarBtn.pos = { x, y }
							y = y - padding - visitHouseBtn.Height
							visitHouseBtn.pos = { x, y }
						end
					end
					return profileCell
				elseif index <= nbCategories + 1 then
					local categoryIndex = index - 1
					local category = categories[categoryIndex]

					local cell = categoryCells[categoryIndex]
					if cell == nil then
						cell = table.remove(categoryUnusedCells)
						if cell == nil then
							-- no cell in recycle pool, create it
							cell = createCategoryCell(category)
						end
						cell.categoryIndex = categoryIndex
						categoryCells[categoryIndex] = cell

						cell.title.Text = category.title

						if category.loadCell ~= nil then
							if cell.scroll then
								cell.scroll:remove()
							end

							local dataFetcher = {
								entities = {},
								nbEntities = 0,
								row = cell,
								title = category.title,
								displayNumberOfEntries = category.displayNumberOfEntries,
							}

							local scroll = ui:createScroll({
								-- backgroundColor = Color(255, 255, 255),
								backgroundColor = Color(43, 45, 49),
								padding = config.CELL_PADDING,
								cellPadding = config.CELL_PADDING,
								direction = "right",
								loadCell = category.loadCell,
								unloadCell = category.unloadCell,
								userdata = dataFetcher,
							})

							dataFetcher.scroll = scroll

							scroll:setParent(cell)
							cell.scroll = scroll

							scroll.onRemove = function()
								if dataFetcher.req then
									dataFetcher.req:Cancel()
									dataFetcher.req = nil
								end
								dataFetcher.row = nil
								dataFetcher.scroll = nil
							end

							if category.extraSetup then
								category.extraSetup(dataFetcher)
							end
						end
					end
					return cell
				end
			end,
			unloadCell = function(_, _)
				-- TODO: recycle
			end,
		})
		scroll:setParent(root)

		bottomBar = ui:frame()

		local function createBottomBarButton(text, icon)
			local btn = ui:frame({ color = Color(0, 0, 0) })

			local content = ui:frame()

			local data = Data:FromBundle(icon or "images/logo.png")
			local quad = Quad()
			quad.Image = {
				data = data,
				alpha = true,
			}

			icon = ui:frame({ quad = quad })
			icon.Width = 20
			icon.Height = 20
			icon:setParent(content)

			local title = ui:createText(text, { size = "small", color = Color.White })
			title:setParent(content)

			content.Width = 50
			content.Height = title.Height + icon.Height + padding * 2.2

			content.parentDidResize = function(self)
				self.Width = self.parent.Width
				self.pos = { 0, self.parent.Height - self.Height }

				local y = self.Height - padding - icon.Height
				icon.pos = { self.Width * 0.5 - icon.Width * 0.5, y }
				y = y - padding * 0.2 - title.Height
				title.pos = { self.Width * 0.5 - title.Width * 0.5, y }
			end

			content:setParent(btn)
			btn.content = content

			btn:setParent(bottomBar)
			return btn
		end

		local btnHome = createBottomBarButton("Home", "images/logo.png")
		local btnExplore = createBottomBarButton("Explore", "images/icon-explore.png")
		local btnProfile = createBottomBarButton("Profile", "images/icon-profile.png")
		local btnFriends = createBottomBarButton("Friends", "images/icon-friends.png")
		local btnCreate = createBottomBarButton("Create", "images/icon-create.png")

		btnProfile.onRelease = function()
			Menu:ShowProfile({ player = Player })
		end

		btnFriends.onRelease = function()
			Menu:ShowFriends()
		end

		bottomBar.parentDidResize = function(self)
			self.Width = self.parent.Width
			local btnWidth = self.Width / 5.0

			local h = btnHome.content.Height + Screen.SafeArea.Bottom

			self.Height = h
			btnHome.Height = h
			btnExplore.Height = h
			btnProfile.Height = h
			btnFriends.Height = h
			btnCreate.Height = h

			btnHome.Width = btnWidth
			btnExplore.Width = btnWidth
			btnProfile.Width = btnWidth
			btnFriends.Width = btnWidth
			btnCreate.Width = btnWidth

			btnHome.pos = { 0, 0 }
			btnExplore.pos = btnHome.pos + { btnWidth, 0 }
			btnCreate.pos = btnExplore.pos + { btnWidth, 0 }
			btnProfile.pos = btnCreate.pos + { btnWidth, 0 }
			btnFriends.pos = btnProfile.pos + { btnWidth, 0 }

			scroll.pos = { 0, self.Height }
			scroll.Width = Screen.Width
			scroll.Height = Screen.Height - self.Height --  - Screen.SafeArea.Top
		end
		bottomBar:setParent(root)
	end

	_home.hide = function()
		if root == nil then
			return
		end
	end

	return _home
end

Client.DirectionalPad = nil
