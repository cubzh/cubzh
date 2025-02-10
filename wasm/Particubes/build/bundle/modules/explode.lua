-- WORLK IN PROGRESS

local explode = {
	hierarchyActions = require("hierarchyactions"),
}

-- explodes all shapes in object
-- (including object itself if it's a shape)
explode.shapes = function(self, object)
	self.hierarchyActions:applyToDescendants(object, { includeRoot = true }, function(o)
		if type(o) == "Shape" or type(o) == "MutableShape" then
			local s = Shape(o)
			World:AddChild(s)

			s.Scale = o.LossyScale
			s.Position = o.Position
			s.Rotation = o.Rotation

			s.Physics = true
			s.CollisionGroups = nil
			s.CollidesWithGroups = Map.CollisionGroups
			s.Bounciness = 0.1

			local v = Number3(0, 0, 1) * (50 + math.random() * 100)
			v:Rotate(Number3(math.random() * -math.pi, math.random() * math.pi * 2, 0))
			s.Velocity = v

			-- s.rot = s.Rotation:Copy()

			-- s.Tick = function(o, dt)
			-- 	print(o.rot)
			-- 	o.rot.Y = o.rot.Y * dt * 10
			-- 	o.rot.X = o.rot.X * dt * 10
			-- 	o.Rotation = o.rot
			-- end

			Timer(5, function()
				s:RemoveFromParent()
			end)
		end
	end)
end

return explode
