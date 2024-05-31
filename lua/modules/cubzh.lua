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
	Sky.LightColor = Color(255, 255, 234)

	logo = nil

	placeItems()

	LocalEvent:Listen("signup_flow_avatar_preview", function()
		logo.IsHidden = true
	end)

	LocalEvent:Listen("signup_flow_start_or_login", function()
		logo.IsHidden = false
	end)
end

-- Client.OnWorldObjectLoad = function(obj)
-- 	obj:RemoveFromParent()
-- end

function placeItems()
	logo = Object()
	local c = bundle:Shape("shapes/cubzh_logo_c")
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

	local space = 2
	u.LocalPosition:Set(c.LocalPosition.X + c.Width * 0.5 + space + u.Width * 0.5, c.LocalPosition.Y, c.LocalPosition.Z)
	b.LocalPosition:Set(u.LocalPosition.X + u.Width * 0.5 + space + b.Width * 0.5, c.LocalPosition.Y, c.LocalPosition.Z)
	z.LocalPosition:Set(b.LocalPosition.X + b.Width * 0.5 + space + z.Width * 0.5, c.LocalPosition.Y, c.LocalPosition.Z)
	h.LocalPosition:Set(z.LocalPosition.X + z.Width * 0.5 + space + h.Width * 0.5, c.LocalPosition.Y, c.LocalPosition.Z)

	c.Rotation:Set(0, 0, math.rad(10))
	u.Rotation:Set(0, 0, math.rad(-10))
	b.Rotation:Set(0, 0, math.rad(10))
	z.Rotation:Set(0, 0, math.rad(-10))
	h.Rotation:Set(0, 0, math.rad(10))

	logo:SetParent(World)

	local box = Box()
	box:Fit(logo, { recursive = true })

	Camera:FitToScreen(box, 1.0)
end

Client.DirectionalPad = nil
