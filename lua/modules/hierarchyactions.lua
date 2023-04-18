--[[
    Example:

Client.OnStart = function()
	hierarchyActions = require("hierarchyactions")

    -- get a list of all descendants including the root shape
    local shapes = {}
	hierarchyActions:applyToDescendants(shape,  { includeRoot = true }, function(s)
		table.insert(shapes, s)
	end)

    -- get the number of blocks in children
    local count = 0
    hierarchyActions:applyToDescendants(shape, { depth = 1 }, function(s)
		count = count + s.BlocksCount
    end)

    -- set a value for all descendants
    hierarchyActions:applyToDescendants(shape, function(s)
        s.PrivateDrawMode = drawMode
    end)
end
--]]

local hierarchyActions = {}
local hierarchyActionsMetatable = {
    __index = {
    	_maxDepth = -1,
        applyToDescendants = function(self, shape, options, callback)
            if callback == nil then
                callback = options
                options = {}
            end
            if options.depth == nil then
                options.depth = self._maxDepth
            end
            if options.includeRoot then
                callback(shape)
            end
            if options.depth == 0 then
                return
            end
            local newDepth = options.depth
            if newDepth ~= self._maxDepth then
                newDepth = newDepth - 1
            end
            local newOptions = {
                depth = newDepth,
                includeRoot = true -- always include root for descendants
            }
            for i=1,shape.ChildrenCount do
                local child = shape:GetChild(i)
                self:applyToDescendants(child, newOptions, callback)
            end
        end
    } 
}
setmetatable(hierarchyActions, hierarchyActionsMetatable)

return hierarchyActions