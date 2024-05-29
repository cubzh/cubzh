bundle = {}

function hasExtension(filepath)
	local lastSlash = filepath:match(".*[/\\]()")
	local filename = filepath
	if lastSlash then
		filename = filepath:sub(lastSlash)
	end
	if filename:find("%.") then
		return true
	else
		return false
	end
end

---@function Shape creates a Shape, loading file from local app bundle.
---@param relPath string
---@param config? table
---@return Shape
---@code
--- local bundle = require("bundle")
--- local shape = bundle:Shape("path/to/shape.3zh")
bundle.Shape = function(self, relPath, config)
	if self ~= bundle then
		error("bundle:Shape(relPath, config) should be called with `:`", 2)
	end
	if type(relPath) ~= "string" then
		error("bundle:Shape(relPath, config) - relPath should be a string", 2)
	end
	if config ~= nil and type(config) ~= "table" then
		error("bundle:Shape(relPath, config) - config should be a table", 2)
	end
	if hasExtension(relPath) == false then
		relPath = relPath .. ".3zh"
	end
	local data = bundle:Data(relPath)
	if data == nil then
		error("bundle:Shape(relPath, config) - couldn't load file from bundle at " .. relPath, 2)
	end
	return Shape(data, config)
end

---@function MutableShape creates a MutableShape, loading file from local app bundle.
---@param relPath string
---@param config? table
---@return MutableShape
---@code
--- local bundle = require("bundle")
--- local mutableShape = bundle:MutableShape("path/to/shape.3zh")
bundle.MutableShape = function(self, relPath, config)
	if self ~= bundle then
		error("bundle:MutableShape(relPath, config) should be called with `:`", 2)
	end
	if type(relPath) ~= "string" then
		error("bundle:MutableShape(relPath, config) - relPath should be a string", 2)
	end
	if config ~= nil and type(config) ~= "table" then
		error("bundle:MutableShape(relPath, config) - config should be a table", 2)
	end
	if hasExtension(relPath) == false then
		relPath = relPath .. ".3zh"
	end
	local data = bundle:Data(relPath)
	if data == nil then
		error("bundle:MutableShape(relPath, config) - couldn't load file from bundle at " .. relPath, 2)
	end
	return MutableShape(data, config)
end

---@function Data reads a file from the local app bundle.
---@param relPath string
---@return Data
---@code
--- local bundle = require("bundle")
--- local data = bundle:Data("path/to/data.ext")
bundle.Data = function(self, relPath)
	if self ~= bundle then
		error("bundle:Data(relPath) should be called with `:`", 2)
	end
	if type(relPath) ~= "string" then
		error("bundle:Data(relPath) - relPath should be a string", 2)
	end
	return System.DataFromBundle(relPath)
end

return bundle
