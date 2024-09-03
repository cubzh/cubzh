------------------------------------------------------------------------
-- @module: Pathfinding A-star
-- @description: Pathfinding module for a 2D Matrix with a single value to evaluate
-- @tags: Algorithm, Pathfinding, Logic, Map
------------------------------------------------------------------------
local pf_astar = {
	-- Constants
	kCount = 500, --to avoid infinite while
	kStep = 1, --step between nodes
}

------------------------
--- PUBLIC FUNCTIONS ---
------------------------

--[[
-- Creates a pathfinder object with specific global search instructions
-- @param {int} [step = 1] - The value of each movement for this pathfinder
-- @param {bool} [useDiagonals = false] - Can the pathfinder use NE, SE, SW, NW ? Can be overriden in find
-- @param {bool} [useCache = true] - Can the pathfinder use cache for already calculated paths ? Can be overriden in find
]]
pf_astar.newPathfinder = function(self, step, useDiagonals, useCache)
	local pathfinder = {}
	if step ~= nil then
		pathfinder.step = step
	else
		pathfinder.step = pf_astar.kStep
	end
	if useDiagonals ~= nil then
		pathfinder.useDiagonals = useDiagonals
	else
		pathfinder.useDiagonals = false
	end
	if useCache ~= nil then
		pathfinder.useCache = useCache
		pathfinder.cached = {}
	else
		pathfinder.useCache = false
	end
	pathfinder.kCount = self.kCount

	--[[ Table for internal functions]]
	local internal = {}

	------------------------
	--- PUBLIC FUNCTIONS ---
	------------------------

	--[[
  -- Clear cached paths
  ]]
	pathfinder.clearCache = function(self)
		if self.cached ~= nil then
			self.cached = {}
		end
	end

	--[[
  -- Find the path based on positions and a test function (for available coords)
  -- @param {int} startX - starting X position
  -- @param {int} startZ - starting Z position
  -- @param {int} endX - X position to find
  -- @param {int} endZ - Z position to find
  -- @param {*[][]} map - A 2D array representing the map
  -- @param {function} testFunction - A function testing the availability criteria for given map coordinates (map[x][z])
  -- @param {bool} [diagonalsAllowed = false] - Can the pathfinder use NE, SE, SW, NW ? Defaults to pathfinder settings
  -- @param {bool} [useCached = true] - Can the pathfinder use cache for already calculated paths ? Defaults to pathfinder settings
  ]]
	pathfinder.find = function(self, startX, startZ, endX, endZ, map, testFunction, useDiagonals, useCache)
		-- Overrides
		if useDiagonals == nil then
			useDiagonals = self.useDiagonals
		end
		if useCache == nil then
			useCache = self.useCache
		end

		-- If the pathfinder uses cache and there is a cached path, return it
		if useCache == true and internal.getCache(self, startX, startZ, endX, endZ) ~= nil then
			return internal.getCache(self, startX, startZ, endX, endZ)
		end
		-- Init lists to run the nodes & a count as protection for while
		local openList = {}
		local closedList = {}
		local count = 0
		-- Setup startNode and endNode
		local endNode = internal.createNode(endX, endZ, nil)
		local startNode = internal.createNode(startX, startZ, nil)
		-- Calculate starting node score
		internal.calculateScores(startNode, endNode)
		-- Insert the startNode as first node to examine
		table.insert(openList, startNode)
		-- While there are nodes to examine and the count is under kCount (and the function did not return)
		while #openList > 0 and count < self.kCount do
			count = count + 1
			-- Sort openList with ascending f
			table.sort(openList, function(a, b)
				return a.f > b.f
			end)
			-- Examine the last node
			local currentNode = table.remove(openList)
			table.insert(closedList, currentNode)
			if internal.listContains(closedList, endNode) then
				local path = {}
				local current = currentNode
				while current ~= nil do
					table.insert(path, current)
					current = current.parent
				end
				internal.setCache(self, startNode, endNode, path)
				return path
			end
			-- Generate children based on map and test function
			local children = internal.getChildren(currentNode, testFunction, useDiagonals, map)
			for _, child in ipairs(children) do
				-- Create child node
				local childNode = internal.createNode(child.x, child.z, currentNode)
				-- Check if it's already been examined
				if not internal.listContains(closedList, childNode) then
					-- Check if it's already planned to be examined with a bigger f (meaning further away)
					if not internal.listContains(openList, childNode) then -- or self.listContains(openList, childNode).f > childNode.f then
						internal.calculateScores(childNode, endNode)
						table.insert(openList, childNode)
					end
				end
			end
		end
		return false
	end

	----------------
	--- INTERNAL ---
	----------------

	--[[ Returns a cache index for given coordinates ]]
	internal.getCacheIndex = function(startX, startZ, endX, endZ)
		return string.format("%d,%d-%d,%d", startX, startZ, endX, endZ)
	end

	--[[ Creates and sets node ]]
	internal.getCache = function(pathfinder, startX, startZ, endX, endZ)
		if pathfinder.cached ~= nil then
			local pathIndex = internal.getCacheIndex(startX, startZ, endX, endZ)
			if pathfinder.cached[pathIndex] ~= nil then
				return pathfinder.cached[pathIndex]
			else
				return nil
			end
		else
			return nil
		end
	end

	--[[ Creates cache for a given path ]]
	internal.setCache = function(pathfinder, startNode, endNode, path)
		local pathIndex = internal.getCacheIndex(startNode.x, startNode.z, endNode.x, endNode.z)
		pathfinder.cached[pathIndex] = path
	end

	--[[ Creates and sets node ]]
	internal.createNode = function(x, z, parent)
		local node = {}
		node.x = x
		node.z = z
		node.parent = parent
		return node
	end

	--[[ Manhattan heuristic evaluation ]]
	internal.heuristic = function(x1, x2, z1, z2)
		local dx = x1 - x2
		local dz = z1 - z2
		local h = dx * dx + dz * dz
		return h
	end

	--[[ Elapsed path based on kStep and parent ]]
	internal.elapsed = function(parentNode)
		return parentNode.g + 1
	end

	--[[ Setting all nodes values ]]
	internal.calculateScores = function(node, endNode)
		if node.parent ~= nil then
			node.g = internal.elapsed(node.parent)
		else
			node.g = 0
		end
		node.h = internal.heuristic(node.x, endNode.x, node.z, endNode.z)
		node.f = node.g + node.h
	end

	--[[ Compare based on coordinates ]]
	internal.listContains = function(list, node)
		for _, v in ipairs(list) do
			if v.x == node.x and v.z == node.z then
				return v
			end
		end
		return false
	end

	--[[ Get all childrens based on the value to test and adjacency settings ]]
	internal.getChildren = function(node, testFunction, diagonalsAllowed, map)
		local children = {}
		local neighbors

		neighbors = {
			{ x = -1, z = 0 },
			{ x = 0, z = 1 },
			{ x = 1, z = 0 },
			{ x = 0, z = -1 },
		}
		if diagonalsAllowed == true then
			neighbors = {
				{ x = -1, z = 0 },
				{ x = 0, z = 1 },
				{ x = 1, z = 0 },
				{ x = 0, z = -1 },
				{ x = -1, z = -1 },
				{ x = 1, z = -1 },
				{ x = 1, z = 1 },
				{ x = -1, z = 1 },
			}
		end

		-- Create all neighbors
		for _, neighbor in ipairs(neighbors) do
			local x = node.x + neighbor.x
			local z = node.z + neighbor.z
			if testFunction(map[x][z]) then
				table.insert(children, { x = x, z = z })
			end
		end
		return children
	end
	return pathfinder
end

return pf_astar
