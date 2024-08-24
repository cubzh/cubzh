-- This modules allows to create planes and test how they collide with rays.

local plane = {}

local hit = function(self, ray)
	if type(ray) ~= "Ray" then
		error("plane:hit(ray) - ray parameter should be a Ray")
	end

	-- if origin on plane, return origin
	if (self.origin - ray.Origin):Dot(self.normal) == 0 then
		return ray.Origin
	end

	-- if ray parallel to plane, return nil
	if math.abs(ray.Direction:Dot(self.normal)) == 0 then
		return nil
	end

	return ray.Origin + ray.Direction * ((self.origin - ray.Origin):Dot(self.normal) / ray.Direction:Dot(self.normal))
end

local planeMetatable = {
	__index = {
		New = function(_, origin, v1, v2)
			local planeInstance = {}
			local normal = v1:Cross(v2)
			normal:Normalize()
			local planeInstanceMetatable = {
				__index = {
					origin = origin:Copy(),
					v1 = v1:Copy(),
					v2 = v2:Copy(),
					normal = normal,
					hit = hit,
				},
				_newindex = function(_, k, v)
					if k == "origin" then
						origin:Set(v)
					elseif k == "normal" then
						normal:Set(v)
						normal:Normalize()
					end
				end,
			}
			setmetatable(planeInstance, planeInstanceMetatable)
			return planeInstance
		end,
	},
}
setmetatable(plane, planeMetatable)

-- local planeUnitTests = function()
--     local equal = function(n1, n2)
--         local epsilon = 0.001
--         return math.abs(n1.X - n2.X) < epsilon and math.abs(n1.Y - n2.Y) < epsilon and math.abs(n1.Z - n2.Z) < epsilon
--     end

--     -- XY plane
-- 	local p = plane:New(Number3(0,0,0), Number3(1,0,0), Number3(0,1,0))
-- 	local r = Ray(Number3(0,0,-3), Number3(0,0,1))
-- 	local hit = p:hit(r)
-- 	local res = Number3(0,0,0)
--     assert(equal(hit,res))

-- 	local r = Ray(Number3(0,1,-3), Number3(1,0,1))
-- 	local hit = p:hit(r)
-- 	local res = Number3(3,1,0)
--     assert(equal(hit,res))

-- 	-- Ray origin on plane
-- 	local r = Ray(Number3(2,1,0), Number3(1,0,3))
-- 	local hit = p:hit(r)
-- 	local res = Number3(2,1,0)
-- 	assert(equal(hit,res))

-- 	-- Ray parallel not on plane
-- 	local r = Ray(Number3(0,0,-1), Number3(1,0,0))
-- 	local hit = p:hit(r)
--     assert(hit == nil)

-- 	-- Ray parallel on plane
-- 	local r = Ray(Number3(2,1,0), Number3(1,0,0))
-- 	local hit = p:hit(r)
-- 	local res = Number3(2,1,0)
-- 	assert(equal(hit,res))

-- 	-- X axis aligned, 45 tilted
-- 	local p2 = plane:New(Number3(0,0,0), Number3(1,0,0), Number3(0,1,1))
-- 	local r = Ray(Number3(0,-1,-3), Number3(-1,0,1))
-- 	local hit = p2:hit(r)
-- 	local res = Number3(-2,-1,-1)
--     assert(equal(hit,res))
-- end
--planeUnitTests()

return plane
