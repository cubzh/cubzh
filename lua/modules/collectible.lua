-- TODO: do not only load collectibles from bundle

collectible = {}

defaultCollectibleConfig = {
	onCollisionBegin = function(c) -- receives collectible config
		collectible:remove(c)
	end,
	onCollisionEnd = function(_) end,
	scale = 1.0,
	position = Number3.Zero,
	rotation = Number3.Zero,
	shadow = true,
	unlit = false,
	itemName = "",
	userdata = {},
}

-- { object1 = config1, object2 = config2, ... }
-- (indexed by object to find config on collision)
-- each config contains provided field + inserted ones like object
pool = {}

nbCollectibles = 0
tickListener = nil

function toggleTick()
	if nbCollectibles > 0 and tickListener == nil then
		local t = 0.0
		local offset
		tickListener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
			t = t + dt
			offset = ((math.sin(t) + 1) / 2) * 2
			for object, config in pairs(pool) do
				object:RotateLocal(0, dt, 0)
				object.Position.Y = config.position.Y + offset
			end
		end)
	elseif nbCollectibles == 0 and tickListener ~= nil then
		tickListener:Remove()
		tickListener = nil
	end
end

collectibleOnCollisionBegin = function(collectibleObject, other)
	if other ~= Player then
		return
	end
	local config = pool[collectibleObject]
	if config == nil then
		return -- config not found
	end
	config:onCollisionBegin()
end

collectibleOnCollisionEnd = function(_, _) end

collectible.create = function(_, config)
	local bundle = require("bundle")
	local hierarchyactions = require("hierarchyactions")
	local conf = require("config")

	config = conf:merge(defaultCollectibleConfig, config)

	local s = bundle.Shape(config.itemName)
	s:SetParent(World)

	hierarchyactions:applyToDescendants(s, { includeRoot = true }, function(o)
		o.Physics = PhysicsMode.Disabled
		o.IsUnlit = config.unlit
		-- o.PrivateDrawMode = 2
	end)

	s.Physics = PhysicsMode.Trigger
	s.CollisionGroups = {}
	s.CollidesWithGroups = Player.CollisionGroups

	if config.shadow then
		s.Shadow = true
	end

	s.Pivot = { s.Width * 0.5, 0, s.Depth * 0.5 }

	s.Scale = config.scale
	s.Position = config.position
	s.Rotation = config.rotation

	s.OnCollisionBegin = collectibleOnCollisionBegin
	s.OnCollisionEnd = collectibleOnCollisionEnd

	config.object = s

	if pool[s] == nil then
		-- increase count if not replacing
		nbCollectibles = nbCollectibles + 1
	end
	pool[s] = config

	toggleTick()

	return config
end

collectible.remove = function(_, c)
	local object = c.object
	if object == nil then
		return
	end
	object:RemoveFromParent()
	pool[object] = nil
	nbCollectibles = nbCollectibles - 1
	toggleTick()
end

return collectible
