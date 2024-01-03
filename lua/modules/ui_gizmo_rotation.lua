-- Example
--	local node = ui_rotation:create({ shape = shape })
--	node.Size = 220
--	node.pos = { 50, 300 }
--  node:setShape(shape2)

local SNAP = math.pi * 0.0625

local Orientation = require("gizmo").Orientation

local create = function(_, config)
	local ui = require("uikit")
	local node = ui:createFrame(Color(0,0,0,0.2))

	local shape = config.shape or Object()
	local onRotate = config.onRotate

	local orientationMode = Orientation.World

	node.setOrientation = function(_, mode)
		orientationMode = mode
	end

	local ratio = 7
	local axisConfig = {
		{ color = Color.Red, axis = "X", vector = "Right" },
		{ color = Color.Green, axis = "Y", vector = "Up" },
		{ color = Color.Blue, axis = "Z", vector = "Forward" },
	}
	local axisList = {}
	local fakeObject = Object()

	local diff = nil
	for _,config in ipairs(axisConfig) do
		local handle = MutableShape()
		handle:AddBlock(config.color,0,0,0)

		local uiAxis = ui:createShape(handle)
		uiAxis:setParent(node)

		uiAxis.parentDidResize = function()
			uiAxis.pos = { (node.Width - ratio) * 0.5, (node.Height - ratio) * 0.5 }
			local handleSize = node.Width / ratio
			handle.Scale[config.axis] = handleSize
			if handle.sphereUp then
				handle.sphereUp.Scale[config.axis] = 1 / handleSize
                handle.sphereUp.Scale = handle.sphereUp.Scale * (node.Width / 200)
				handle.sphereDown.Scale[config.axis] = 1 / handleSize
                handle.sphereDown.Scale = handle.sphereDown.Scale * (node.Width / 200)
			end
		end
		handle.Pivot = { 0.5, 0.5, 0.5 }

		uiAxis.onPress = function(_, _, _, pe)
			diff = pe.X
			fakeObject.Rotation = shape.Rotation
		end
		uiAxis.onDrag = function(_, pe)
			if not shape then return end
			if orientationMode == Orientation.Local then
				fakeObject:RotateWorld(fakeObject[config.vector], (diff - pe.X) * 6)
				shape.Rotation = Rotation(
					fakeObject.Rotation.X,
					fakeObject.Rotation.Y,
					fakeObject.Rotation.Z
				) -- trigger onsetcallback
			else
				fakeObject:RotateWorld(Number3[config.vector], (diff - pe.X) * 6)
				shape.Rotation = Rotation(
					math.floor(fakeObject.Rotation.X / SNAP) * SNAP,
					math.floor(fakeObject.Rotation.Y / SNAP) * SNAP,
					math.floor(fakeObject.Rotation.Z / SNAP) * SNAP
				) -- trigger onsetcallback
			end
			diff = pe.X
			if onRotate then
				onRotate(shape.Rotation)
			end
			return true
		end
		table.insert(axisList, { handle = handle, uiAxis = uiAxis })

		-- sphere handles
		Object:Load("caillef.sphere7x7", function(obj)
			obj:SetParent(handle)
			obj.Pivot = { obj.Width * 0.5, obj.Height * 0.5, obj.Depth * 0.5 }
			obj.Palette[1].Color = config.color
			obj.LocalPosition[config.axis] = 0.5
			obj.Layers = handle.Layers
			obj.CollisionGroups = handle.CollisionGroups
			obj.Physics = PhysicsMode.TriggerPerBlock
            obj.IsUnlit = true
			handle.sphereUp = obj

			obj = Shape(obj)
			obj:SetParent(handle)
			obj.Pivot = { obj.Width * 0.5, obj.Height * 0.5, obj.Depth * 0.5 }
			obj.Palette[1].Color = config.color
			obj.LocalPosition[config.axis] = -0.5
			obj.Layers = handle.Layers
			obj.CollisionGroups = handle.CollisionGroups
			obj.Physics = PhysicsMode.TriggerPerBlock
            obj.IsUnlit = true
			handle.sphereDown = obj

			uiAxis:parentDidResize()
		end)
	end

	LocalEvent:Listen(LocalEvent.Name.Tick, function()
		for _,axis in ipairs(axisList) do
			local newRotation
			if orientationMode == Orientation.Local then
				if not shape then return end
				newRotation = -Camera.Rotation * shape.Rotation
			else
				newRotation = -Camera.Rotation
			end
			axis.handle.Rotation = newRotation
		end
	end)

	node.setShape = function(_, newShape)
		shape = newShape
	end
	if shape then
		node:setShape(shape)
	end

	return node
end

return {
    create = create
}