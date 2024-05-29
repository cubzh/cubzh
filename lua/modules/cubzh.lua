Modules = {
	bundle = "bundle",
}

Dev.DisplayColliders = false

Client.OnStart = function()
	Camera:SetModeFree()
	Camera:SetParent(World)

	Sky.AbyssColor = Color(120, 0, 178)
	Sky.HorizonColor = Color(106, 73, 243)
	Sky.SkyColor = Color(121, 169, 255)
	Sky.LightColor = Color(0, 0, 0)

	logo = nil

	placeItems()

	LocalEvent:Listen("signup_flow_avatar_preview", function()
		titleRoot.IsHidden = true
	end)

	LocalEvent:Listen("signup_flow_start_or_login", function()
		titleRoot.IsHidden = false
	end)

	light = Light()
	light.Color = Color(150, 150, 200)
	light.Intensity = 0.9
	light.CastsShadows = true
	light.On = true
	light.Type = LightType.Directional
	World:AddChild(light)
	light.Rotation:Set(math.rad(20), math.rad(20), 0)

	Light.Ambient.SkyLightFactor = 0
	Light.Ambient.DirectionalLightFactor = 1.0
end

-- Client.OnWorldObjectLoad = function(obj)
-- 	obj:RemoveFromParent()
-- end

function placeItems()
	titleRoot = Object()
	titleRoot:SetParent(World)

	logo = Object()
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

	local giraffe = bundle.Shape("voxels.giraffe_head.3zh")
	giraffe.Pivot:Set(giraffe.Width * 0.5, giraffe.Height * 0.5, giraffe.Depth * 0.5)
	giraffe:SetParent(titleRoot)
	giraffe.Scale = 1
	giraffe.LocalPosition:Set(0, 0, 12)
	giraffe.rot = Rotation(0, 0, math.rad(20))
	giraffe.Rotation:Set(giraffe.rot)

	local chest = bundle.Shape("voxels.chest.3zh")
	chest.Pivot:Set(chest.Width * 0.5, chest.Height * 0.5, chest.Depth * 0.5)
	chest:SetParent(titleRoot)
	chest.Scale = 0.5
	chest.LocalPosition:Set(7, -12, -7)
	chest.rot = Rotation(0, math.rad(25), math.rad(-5))
	chest.Rotation:Set(chest.rot)
	local chestLid = chest.Lid
	local chestLidRot = chest.Lid.LocalRotation:Copy()

	local pezh = bundle.Shape("voxels.pezh_coin_2.3zh")
	pezh.Pivot:Set(pezh.Size * 0.5)
	pezh:SetParent(titleRoot)
	pezh.Scale = 0.5
	pezh.LocalPosition:Set(-5, -12, -7)
	pezh.rot = Rotation(0, 0, math.rad(20))
	pezh.Rotation:Set(pezh.rot)

	local cube = bundle.Shape("voxels.cube.3zh")
	cube.Pivot:Set(cube.Size * 0.5)
	cube:SetParent(titleRoot)
	cube.Scale = 0.5
	cube.LocalPosition:Set(17, -8, -12)
	cube.rot = Rotation(0, 0, math.rad(20))
	cube.Rotation:Set(cube.rot)

	local sword = bundle.Shape("voxels.sword.3zh")
	sword.Pivot:Set(sword.Size * 0.5)
	sword:SetParent(titleRoot)
	sword.Scale = 0.5
	sword.LocalPosition:Set(-10, -10, -12)
	sword.rot = Rotation(0, 0, math.rad(-45))
	sword.Rotation:Set(sword.rot)

	local spaceship = bundle.Shape("voxels.spaceship_2.3zh")
	spaceship.Pivot:Set(spaceship.Size * 0.5)
	spaceship.Pivot.Y = spaceship.Pivot.Y + 55
	spaceship:SetParent(titleRoot)
	spaceship.Scale = 0.5
	spaceship.LocalPosition:Set(0, 0, 0)
	spaceship.rot = Rotation(0, math.rad(-30), math.rad(-30))
	spaceship.Rotation:Set(spaceship.rot)

	local space = 2
	local totalWidth = c.Width + u.Width + b.Width + z.Width + h.Width + space * 4

	c.LocalPosition.X = -totalWidth * 0.5 + c.Width * 0.5
	u.LocalPosition:Set(c.LocalPosition.X + c.Width * 0.5 + space + u.Width * 0.5, c.LocalPosition.Y, c.LocalPosition.Z)
	b.LocalPosition:Set(u.LocalPosition.X + u.Width * 0.5 + space + b.Width * 0.5, c.LocalPosition.Y, c.LocalPosition.Z)
	z.LocalPosition:Set(b.LocalPosition.X + b.Width * 0.5 + space + z.Width * 0.5, c.LocalPosition.Y, c.LocalPosition.Z)
	h.LocalPosition:Set(z.LocalPosition.X + z.Width * 0.5 + space + h.Width * 0.5, c.LocalPosition.Y, c.LocalPosition.Z)

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
	titleRoot.Tick = function(o, dt)
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
	end

	logo:SetParent(titleRoot)

	local box = Box()
	box:Fit(logo, { recursive = true })
	Camera:FitToScreen(box, 1.0)

	LocalEvent:Listen(LocalEvent.Name.ScreenDidResize, function()
		local box = Box()
		box:Fit(logo, { recursive = true })
		Camera:FitToScreen(box, 1.7)
	end)
end

Client.DirectionalPad = nil
