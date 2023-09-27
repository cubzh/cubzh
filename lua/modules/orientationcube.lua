-- Example
--[[
    local orientationCube = require("orientationcube")
    orientationCube:init()

    orientationCube:setSize(200)
    orientationCube:setScreenPosition(Screen.Width - 205, Screen.Height - 205)

    orientationCube:setRotation(Camera.Rotation) (in Tick to rotate at each frame)

    orientationCube:setLayer(3) -- set camera and cube layer

    orientationCube:show()
    orientationCube:hide()
    orientationCube:toggle()
--]]

local orientationCube = {}
local orientationCubeMetatable = {
	__index = {
		_defaultLayer = 5,
        layer = nil,
		setScreenPosition = function(self, x, y)
			local camera = self.camera
			if not camera then self:init() end
			camera.TargetX = x
			camera.TargetY = y
		end,
		setSize = function(self, size)
			local camera = self.camera
			if not camera then self:init() end
			camera.TargetWidth = size
			camera.TargetHeight = size
			camera.Width = size
			camera.Height = size
		end,
		setRotation = function(self, cameraRotation)
			local camera = self.camera
			if not camera then self:init() end
			
			self.camera.Rotation:Set(cameraRotation)

			for _,t in ipairs(self.texts) do
				local visible = t.Forward:Dot(self.camera.Forward) > -0.3
				if visible then
					t:SetParent(self.cube)
				else
					t:RemoveFromParent()
				end
			end
		end,
		show = function(self)
			self.camera.On = true
		end,
		hide = function(self)
			self.camera.On = false
		end,
		isVisible = function(self)
			return self.camera.On
		end,
		toggle = function(self, show)
			if show == nil then show = self:isVisible() == false end
			if show then self:show()
			else self:hide() end
		end,
		setLayer = function(self, layer)
            local camera = self.camera
			if not camera then self:init() end
            if self.layer == layer then return end
            self.layer = layer
			camera.Layers = layer
            if self.cube then
    			self.cube.Layers = layer
	    		for _,t in ipairs(self.texts) do
		    		t.Layers = layer
			    end
            end
		end,
		init = function(self,x,y,size)
            self.layer = self._defaultLayer
			local camera = Camera()
			self.camera = camera
            camera.Layers = self.layer
			camera:SetParent(World)
			camera.On = true
			camera.Rotation = Camera.Rotation

			Object:Load("minadune.camera_gizmo", function(cube)
				self.cube = cube
				cube.Physics = PhysicsMode.Disabled
				cube:SetParent(World)
                cube.Layers = self.layer
				cube.CollisionGroups = 3
				cube.Pivot = { cube.Width * 0.5, cube.Height * 0.5, cube.Depth * 0.5 }

				camera:SetModeSatellite(cube,17)
				
				local textsInfo = {
					{
						text = "Front",
						p = { 0, 0, cube.Depth * 0.51 },
						r = { 0, math.pi, 0 }
					},
					{
						text = "Back",
						p = { 0, 0, -cube.Depth * 0.51 },
						r = { 0, 0, 0 }
					},
					{
						text = "Top",
						p = { 0, cube.Height * 0.51, 0 },
						r = { math.pi / 2, 0, 0 }
					},
					{
						text = "Bottom",
						p = { 0, -cube.Height * 0.51, 0 },
						r = { -math.pi / 2, 0, 0 }
					},
					{
						text = "Right",
						p = { cube.Width * 0.51, 0, 0 },
						r = { 0, -math.pi / 2, 0 }
					},
					{
						text = "Left",
						p = { -cube.Width * 0.51, 0, 0 },
						r = { 0, math.pi / 2, 0 }
					}
				}

				local texts = {}
				self.texts = texts

				for _,data in ipairs(textsInfo) do
					local t = Text()
					t:SetParent(cube)
					t.Anchor = { 0.5, 0.5 }
					t.Type = TextType.World
					t.Text = data.text
					t.Padding = 0
					t.Color = Color.White
					t.BackgroundColor = Color(0,0,0,0)
                    t.Layers = self.layer

					t.LocalPosition = data.p
					t.LocalRotation = data.r
					table.insert(texts, t)
				end
				self:setLayer(self.layer)
			end)
	
			self:setScreenPosition(x or Screen.Width - 105, y or Screen.Height - 105)
			self:setSize(size or 100)
            self:setLayer(self.layer)
		end
	}
}
setmetatable(orientationCube, orientationCubeMetatable)

return orientationCube
