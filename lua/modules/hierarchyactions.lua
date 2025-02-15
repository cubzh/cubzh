-- DEPRECATED: USE Object:Recurse(callback, options) directly
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
			shape:Recurse(callback, options)
		end,
	},
}
setmetatable(hierarchyActions, hierarchyActionsMetatable)

return hierarchyActions
