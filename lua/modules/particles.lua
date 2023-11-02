-- WORK IN PROGRESS

local particles = {
	pool = {},
	model = MutableShape(),
	initialized = false,
	n = 0,
	fromConfigOrDefault = function(f, default)
		if f then
			if type(f) == "function" then
				return f()
			else
				return f
			end
		else
			return default
		end
	end,
	lerp = function(a, b, w)
		return a + (b-a)*w
	end
}

--[[
Config fields can be nil, default values used in that case
Also fields can be just values

config = {
	velocity = function() return Number3(0,0,0) end, -- start velocity
	position = function() return Number3(0,0,0) end, -- start position
	rotation = function() return Rotation(0, 0, 0) end,
	start_scale = function() return Number3(1,1,1) end, -- start scale
	end_scale = function() return Number3(0,0,0) end, -- end scale
	-- scale = function() return Number3(1, 1, 1) -- start_scale & end_scale will be equal
	mass = function() return 1 end, -- should be or return a number
	physics = true, -- should be or return a boolean
	acceleration = function() return Number3(0,0,0) end, -- should be or return a Number3
	life = function() return 1.5 end, -- should be or return time in seconds
	collidesWithGroups = function return nil end -- should be or return collision groups
	collisionGroups = function return nil end -- should be or return collision groups
	color = function return Color.White end -- should be or return a Color
}

--]]

particles.newEmitter = function(_, config)
	local emitter = Object()
	emitter.config = config or {}

	if not particles.initialized then
		particles.model:AddBlock(Color.White, 0, 0, 0)
		particles.initialized = true
	end

	emitter.spawn = function(self, n)
		n = n or 1
		local conf = self.config
		for _ = 1, n do
			local p = table.remove(particles.pool)
			if p == nil then
				p = Shape(particles.model)
				particles.n = particles.n + 1
			end

			p.Physics = particles.fromConfigOrDefault(conf.physics, true)
			p.Velocity = particles.fromConfigOrDefault(conf.velocity, Number3(0, 0, 0))
			p.Position = self.Position + particles.fromConfigOrDefault(conf.position, Number3(0, 0, 0))
			p.Rotation = particles.fromConfigOrDefault(conf.rotation, Rotation(0, 0, 0))
			p.Acceleration = particles.fromConfigOrDefault(conf.acceleration, Number3(0, 0, 0))
			p.startScale = particles.fromConfigOrDefault(conf.start_scale, particles.fromConfigOrDefault(conf.scale, 1.0))
			p.endScale = particles.fromConfigOrDefault(conf.end_scale, particles.fromConfigOrDefault(conf.start_scale, particles.fromConfigOrDefault(conf.scale, 1.0)))
			p.Mass = particles.fromConfigOrDefault(conf.mass, 1.0)
			p.Palette[1].Color = particles.fromConfigOrDefault(conf.color, Color.White)
			p.CollisionGroups = particles.fromConfigOrDefault(conf.collisionGroups, nil)
			p.CollidesWithGroups = particles.fromConfigOrDefault(conf.collidesWithGroups, nil)
			p.startLife = particles.fromConfigOrDefault(conf.life, 10.0)
			p.life = particles.fromConfigOrDefault(conf.life, 10.0)

			p.remove = function(s)
				s.Tick = nil
				s:RemoveFromParent()
				table.insert(particles.pool, s)
			end

			World:AddChild(p)

			p.Tick = function(s, dt)
				s.Scale = particles.lerp(s.startScale, s.endScale, 1-(s.life/s.startLife))
				
				s.life = s.life - dt
				if s.life <= 0 then
					s:remove()
				end
			end
		end
	end

	return emitter
end

return particles
