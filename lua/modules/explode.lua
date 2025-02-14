--- This module provides functionality to create explosion effects by breaking objects into smaller pieces
--- and applying physics to them.
---@code
--- local explode = require("explode")
--- -- Explode an object and all its shape descendants into pieces
--- explode:shapes(someObject)

local explode = {
}

---@function shapes Explodes all shapes in an object (including the object itself if it's a shape).
---@param self explode
---@param object Object|Shape The object to explode into pieces
---@code
--- local explode = require("explode")
---
--- -- Explode a single shape
--- local shape = Shape(...)
--- explode:shapes(shape)
---
--- -- Explode an object and all its shape descendants
--- local object = Object()
--- -- Add some shapes as children...
--- explode:shapes(object) -- Will explode all shapes in hierarchy
explode.shapes = function(self, object)
    object:Recurse(function(o)
        if type(o) == "Shape" or type(o) == "MutableShape" then
            -- Create copy of shape
            local s = Shape(o)
            World:AddChild(s)

            -- Preserve original transform
            s.Scale = o.LossyScale
            s.Position = o.Position
            s.Rotation = o.Rotation

            -- Setup physics properties
            s.Physics = true
            s.CollisionGroups = nil
            s.CollidesWithGroups = Map.CollisionGroups
            s.Bounciness = 0.1

            -- Apply random upward explosion force
            local v = Number3(0, 0, 1) * (50 + math.random() * 100)
            v:Rotate(Number3(math.random() * -math.pi, math.random() * math.pi * 2, 0))
            s.Velocity = v

            -- Remove the exploded piece after 5 seconds
            Timer(5, function()
                s:RemoveFromParent()
            end)
        end
    end, { includeRoot = true })
end

return explode
