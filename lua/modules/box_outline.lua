-- Example
--[[

-- Place a red outline around the head of the player
local boxOutline = require("box_outline")

local size = Number3(Player.Head.Width + 1,Player.Head.Height + 1,Player.Head.Depth + 1)
local thickness = 1
local c = boxOutline:create(size,thickness,Color.Red)
c:SetParent(Player.Head)
c.LocalPosition = -Player.Head.Pivot - Number3(0.5,0.5,0.5)

]]--

local boxOutlineModule = {}
local boxOutlineModuleMetatable = {
	__index = {
		create = function(self, size, thickness, color)
			local o = Object()

			o.resize = function(o, size, thickness, color)
				size = size or o.size
				thickness = thickness or o.thickness
				color = color or o.color

				o.size = size
				o.thickness = thickness
				o.color = color

				local segments = {
					{ scaleField="X", pos={0,0,0} }, 			-- bottom front
					{ scaleField="X", pos={0,0,size.Z} },  	  -- bottom back
					{ scaleField="Z", pos={0,0,0} }, 			-- bottom left
					{ scaleField="Z", pos={size.X,0,0} },  	  -- bottom right
					{ scaleField="X", pos={0,size.Y,0} }, 	   -- top front
					{ scaleField="X", pos={0,size.Y,size.Z} },   -- top back
					{ scaleField="Z", pos={0,size.Y,0} },    	-- top left
					{ scaleField="Z", pos={size.X,size.Y,0} },   -- top right
					{ scaleField="Y", pos={0,0,0} }, 	  	  -- v left front
					{ scaleField="Y", pos={0,0,size.Z} },   	 -- v left back
					{ scaleField="Y", pos={size.X,0,0} },    	-- v right front
					{ scaleField="Y", pos={size.X,0,size.Z} },   -- v right back
				}
				for k,segment in ipairs(segments) do
					local l = o:GetChild(k)
					l.Scale = thickness
					l.Scale[segment.scaleField] = size[segment.scaleField]
					l.LocalPosition = segment.pos
					if k == #segments then
						l.Scale[segment.scaleField] = size[segment.scaleField] + thickness
					end
				end
			end			

			local line = MutableShape()
			line:AddBlock(color or Color.White,0,0,0)

			-- build 12 segments
			for i=1,12 do
				local l = Shape(line)
				l:SetParent(o)
				o[i] = l
			end

			o:resize(size, thickness, color)
			return o
		end
	}
}
setmetatable(boxOutlineModule, boxOutlineModuleMetatable)

return boxOutlineModule