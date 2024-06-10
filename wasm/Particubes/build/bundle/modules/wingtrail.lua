wingTrail = {}

pool = {}
oneCube = nil
firstSegments = {} -- first segments, indexed by object

wingTrail.remove = function(_, o)
	o:RemoveFromParent()
	o.Tick = nil
	local segment = firstSegments[o]
	while segment ~= nil do
		segment.cube:RemoveFromParent()
		table.insert(pool, segment)
		segment = segment.next
	end
end

wingTrail.create = function(_, config)
	local defaultConfig = {
		scale = 1.0,
	}

	config = require("config"):merge(defaultConfig, config)

	local o = Object()

	local nextSegmentDT = 0.0

	local color = Color(255, 255, 255, 20)
	local nbSegments = 0
	local firstSegment
	local currentSegment
	local scale = config.scale

	o.setColor = function(_, c)
		color = c
		if currentSegment ~= nil then
			currentSegment.cube.Palette[1].Color = color
		end
	end

	o.Tick = function(o, dt)
		-- if true then
		-- 	return
		-- end
		nextSegmentDT = nextSegmentDT - dt

		local t = currentSegment

		if nextSegmentDT <= 0 then
			nextSegmentDT = 0.3

			t = table.remove(pool)
			if t == nil then
				if oneCube == nil then
					oneCube = MutableShape()
					oneCube:AddBlock(color, 0, 0, 0)
					oneCube = Shape(oneCube)
					oneCube.IsUnlit = true
				end

				t = {
					originPos = Number3.Zero,
					currentPos = Number3.Zero,
					next = nil,
					cube = Shape(oneCube),
				}

				t.cube.Pivot = { 1, 0.5, 0.5 }
				t.cube.Physics = PhysicsMode.Disabled
			end

			t.next = nil
			t.cube:SetParent(World)
			t.cube.Palette[1].Color = color

			t.currentPos:Set(o.Position)

			if currentSegment then
				t.originPos:Set(currentSegment.currentPos)
				currentSegment.next = t
			else
				t.originPos:Set(o.Position)
			end

			t.cube.Position = t.originPos

			currentSegment = t

			if firstSegment == nil then
				firstSegment = currentSegment
				firstSegments[o] = firstSegment
			end

			nbSegments = nbSegments + 1
			if nbSegments > 20 and firstSegment ~= nil then
				nbSegments = nbSegments - 1
				firstSegment.cube:RemoveFromParent()
				table.insert(pool, firstSegment)
				firstSegment = firstSegment.next
				firstSegments[o] = firstSegment
			end
		end

		if t == nil then
			return
		end

		t.currentPos:Set(o.Position)
		t.cube.Right = t.originPos - t.currentPos

		t.cube.Scale = { (t.originPos - t.currentPos).Length, scale, scale }
	end

	return o
end

return wingTrail
