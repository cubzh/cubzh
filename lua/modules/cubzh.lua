Modules = {
	bundle = "bundle",
}

-- Dev.DisplayColliders = true
-- Dev.DisplayBoxes = true

Client.OnStart = function()
	Camera:SetModeFree()
	Camera:SetParent(World)

	Sky.AbyssColor = Color(120, 0, 178)
	Sky.HorizonColor = Color(106, 73, 243)
	Sky.SkyColor = Color(121, 169, 255)
	Sky.LightColor = Color(100, 100, 100)

	titleScreen():show()

	LocalEvent:Listen("signup_flow_avatar_preview", function()
		titleScreen():hide()
		avatar():show()
	end)

	LocalEvent:Listen("signup_flow_start_or_login", function()
		titleScreen():show()
		avatar():hide()
	end)

	light = Light()
	light.Color = Color(150, 150, 200)
	-- light.Color = Color(200, 200, 230)
	light.Intensity = 1.0
	light.CastsShadows = true
	light.On = true
	light.Type = LightType.Directional
	World:AddChild(light)
	light.Rotation:Set(math.rad(20), math.rad(20), 0)

	Light.Ambient.SkyLightFactor = 0.2
	Light.Ambient.DirectionalLightFactor = 0.5
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

	local root
	local didResizeFunction
	local didResizeListener
	local dragListener
	local changeTimer

	local function drag(dx, dy)
		yaw = yaw - dx * 0.01
		pitch = math.min(math.rad(45), math.max(math.rad(-45), pitch + dy * 0.01))
		if root then
			root.LocalRotation = Rotation(pitch, 0, 0) * Rotation(0, yaw, 0)
		end
	end

	_avatar.show = function()
		if root ~= nil then
			return
		end
		root = Object()
		root:SetParent(World)

		local avatar = avatarModule:get({
			usernameOrId = "",
			-- size = math.min(Screen.Height * 0.5, Screen.Width * 0.75),
			-- ui = ui,
			eyeBlinks = false,
		})

		avatar:SetParent(root)
		root.avatar = avatar

		avatar.Animations.Idle:Stop()
		avatar.Animations.Walk:Stop()
		-- avatar.Animations.Walk:Play()

		local b = Box()
		b:Fit(avatar, { recursive = true, ["local"] = true })
		avatar.LocalPosition.Y = -b.Size.Y * 0.5

		avatar:loadEquipment({ type = "hair", shape = hairs[1] })
		avatar:loadEquipment({ type = "jacket", shape = jackets[1] })
		avatar:loadEquipment({ type = "pants", shape = pants[1] })
		avatar:loadEquipment({ type = "boots", shape = boots[1] })

		didResizeFunction = function()
			local box = Box()
			box:Fit(root, { recursive = true })
			Camera:FitToScreen(box, 0.5)
		end

		dragListener = LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pe)
			drag(pe.DX, pe.DY)
		end)
		drag(0, 0)

		didResizeListener = LocalEvent:Listen(LocalEvent.Name.ScreenDidResize, didResizeFunction)
		Timer(0.01, function()
			didResizeFunction()
		end)
		-- didResizeFunction()

		local i = 8
		local r
		local eyesIndex = 1
		local eyesCounter = 1
		local eyesTrigger = 3
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

	_avatar.hide = function()
		if root == nil then
			return
		end

		local avatar = root.avatar
		avatar:loadEquipment({ type = "jacket", item = "" })
		avatar:loadEquipment({ type = "hair", item = "" })
		avatar:loadEquipment({ type = "pants", item = "" })
		avatar:loadEquipment({ type = "boots", item = "" })

		changeTimer:Cancel()
		changeTimer = nil
		dragListener:Remove()
		dragListener = nil
		didResizeListener:Remove()
		didResizeFunction = nil
		root:RemoveFromParent()
		root = nil
	end

	return _avatar
end

Client.DirectionalPad = nil
