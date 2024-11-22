local json = require("json")

local exe = arg[0]
local file = arg[1]
local output = arg[2]

-- print("file:", file)

local moduleName = string.match(file, "([a-zA-Z][a-zA-Z0-9]*).lua$")

-- print("module:", moduleName)

file = string.gsub(file, "^%.", os.getenv("PWD"))

-- print("file: " .. file)

local f = io.open(file, "r")
if f == nil then
	error("could not open", file)
end

-- print(f)
local content = f:read("*all")
f:close()

-- print(content)

local doc = {
	name = "",
	keywords = {},
	description = {},
	types = {},
}

--[[
local doc =  {
	name = "",
	keywords = {},
	description = {
		{text="text"},
		{code="-- some code"},
	},
	types = { -- array
		{
			-- using file name by default if @type token not found
			-- when discovering other function or property
			name = "uikit",
			description = {
				{text="text"},
				{sample="-- some code"},
			}
			functions = {
				description = {
					{text="text"},
					{code="-- some code"},
				},
				name = "functionName",
				params = {

				},
				ret = {
					{
						types = {},
						description = "",
					},
					{
						type = {},
						description = "",
					}
				},
			},
			properties = {

			},
		}
	}
}
]]
--

-- returns name & remaining string
-- or nil if can't parse name
function parseName(s)
	local prefix, name, optional
	if string.match(s, "^[%s]*%.%.%.") then
		prefix = string.match(s, "^([%s]*)")
		name = "..."
		optional = string.match(s:sub(prefix:len() + 3), "^([?])")
	else
		prefix, name, optional = string.match(s, "^([%s]*)([a-zA-Z][a-zA-Z0-9]*)([?]?)")
	end
	if name ~= nil then
		s = s:sub(prefix:len() + name:len() + 1)
		return name, s, optional == "?"
	end
end

-- returns text or nil if can't parse inline text
function parseInlineText(s)
	text = string.match(s, "[ ]*([^\n\r]+)")
	return text or ""
end

function parseTypes(s)
	local prefix, type = string.match(s, "([%s]*)([a-zA-Z][a-zA-Z0-9]*)")

	if type ~= nil then
		local types = { type }
		s = s:sub(prefix:len() + type:len() + 1)

		while true do
			prefix, type = string.match(s, "(|)([a-zA-Z][a-zA-Z0-9]*)")
			if type ~= nil then
				table.insert(types, type)
				s = s:sub(prefix:len() + type:len() + 1)
			else
				break
			end
		end

		return types, s
	end

	return nil, s
end

-- returns true if found & remaining string
function parseFunctionToken(s)
	token = string.match(s, "^(@function)")
	if token ~= nil then
		s = s:sub(token:len() + 1)
		return true, s
	end
	return false, s
end

-- returns true if found & remaining string
function parsePropertyToken(s)
	token = string.match(s, "^(@property)")
	if token ~= nil then
		s = s:sub(token:len() + 1)
		return true, s
	end
	return false, s
end

-- returns true if found & remaining string
function parseParamToken(s)
	token = string.match(s, "^(@param)")
	if token ~= nil then
		s = s:sub(token:len() + 1)
		return true, s
	end
	return false, s
end

-- returns true if found & remaining string
function parseTypeToken(s)
	token = string.match(s, "^(@type)")
	if token ~= nil then
		s = s:sub(token:len() + 1)
		return true, s
	end
	return false, s
end

-- returns true if found & remaining string
function parseReturnToken(s)
	token = string.match(s, "^(@return)")
	if token ~= nil then
		s = s:sub(token:len() + 1)
		return true, s
	end
	return false, s
end

-- returns true if found & remaining string
function parseCodeToken(s)
	token = string.match(s, "^(@code)")
	if token ~= nil then
		s = s:sub(token:len() + 1)
		return true, s
	end
	return false, s
end

-- returns true if found & remaining string
function parseTextToken(s)
	token = string.match(s, "^(@text)")
	if token ~= nil then
		s = s:sub(token:len() + 1)
		return true, s
	end
	return false, s
end

local currentType = nil
local currentFunction = nil
local currentField = nil -- can be a parameter or return
local currentProperty = nil
local current = nil
local i, j
local name
local text
local token
local currentBlock = nil
local currentDescription = doc.description
local currentDescriptionBlockType = "text"

function ensureType()
	if currentType == nil then
		currentType = {}
		table.insert(doc.types, currentType)
		currentType.name = moduleName
		currentType.description = {}
		currentType.functions = {}
		currentType.properties = {}
	end
end

function appendDescription(text)
	if currentField ~= nil then
		if currentDescriptionBlockType ~= "text" then
			error("field only supports text description")
		end

		-- fields (function param or return) support simple text descriptions
		-- (not rich ones with typed blocks)
		currentField.description = currentField.description == nil and text or currentField.description .. "\n" .. text

		return
	end

	if currentDescription ~= nil then
		if #currentDescription == 0 or currentDescription[#currentDescription][currentDescriptionBlockType] == nil then
			if text ~= "" then
				local block = {}
				block[currentDescriptionBlockType] = text
				table.insert(currentDescription, block)
			end
		else
			local block = currentDescription[#currentDescription]
			if text == "" then
				if block[currentDescriptionBlockType] ~= "" then
					block.addEmptyLine = true
				end
			else
				local cr = "\n"
				if block.addEmptyLine then
					cr = "\n\n"
					block.addEmptyLine = nil
				end
				block[currentDescriptionBlockType] = block[currentDescriptionBlockType] .. cr .. text
			end
		end
	end
end

function printDescription(desc)
	if desc == nil then
		return
	end

	if type(desc) == "string" then
		print("\27[02m" .. desc .. "\27[0m")
		return
	end

	for _, block in ipairs(desc) do
		if block.text ~= nil then
			print("\27[02m" .. block.text .. "\27[0m")
		end
	end
end

lines = {}
for prefix, line in string.gmatch(content, "[%s]*(%-%-%-)([^\n\r]*)") do
	table.insert(lines, prefix .. line)
	typeToken, line = parseTypeToken(line)
	if typeToken then
		currentType = {}
		table.insert(doc.types, currentType)
		currentType.description = {}
		currentType.functions = {}
		currentType.properties = {}

		currentDescription = currentType.description
		currentDescriptionBlockType = "text"

		currentFunction = nil
		currentProperty = nil

		name, line = parseName(line)
		if name == nil then
			error("a type needs a name")
		end
		currentType.name = name

		goto continue
	end

	functionToken, line = parseFunctionToken(line)
	if functionToken then
		ensureType()
		currentFunction = { params = { {} }, description = {}, ret = {} }
		currentDescription = currentFunction.description
		currentDescriptionBlockType = "text"
		currentProperty = nil
		currentField = nil
		table.insert(currentType.functions, currentFunction)

		name, line = parseName(line)
		if name ~= nil then
			currentFunction.name = name
			text = parseInlineText(line)
			appendDescription(text)
		end
		goto continue
	end

	propToken, line = parsePropertyToken(line)
	if propToken then
		ensureType()
		currentProperty = { description = {} }
		currentDescription = currentProperty.description
		currentDescriptionBlockType = "text"
		currentFunction = nil
		currentField = nil
		table.insert(currentType.properties, currentProperty)

		name, line = parseName(line)
		if name ~= nil then
			currentProperty.name = name
			types, line = parseTypes(line)
			if types ~= nil then
				currentProperty.types = types
				text = parseInlineText(line)
				appendDescription(text)
			end
		end
		goto continue
	end

	token, line = parseParamToken(line)
	if token then
		if currentFunction == nil then
			print("❌ found param while not in the context of a function")
		end

		currentField = {}
		currentDescriptionBlockType = "text"

		local currentSet = currentFunction.params[#currentFunction.params]
		table.insert(currentSet, currentField)

		name, line, optional = parseName(line)
		if name ~= nil then
			currentField.optional = optional
			currentField.name = name

			types, line = parseTypes(line)
			if types ~= nil then
				currentField.types = types

				text = parseInlineText(line)
				appendDescription(text)
			end
		end
		goto continue
	end

	token, line = parseReturnToken(line)
	if token then
		if currentFunction == nil then
			print("❌ found return while not in the context of a function")
		end

		currentField = {}
		currentDescriptionBlockType = "text"

		table.insert(currentFunction.ret, currentField)

		types, line = parseTypes(line)
		if types ~= nil then
			currentField.types = types
			text = parseInlineText(line)
			appendDescription(text)
		end

		goto continue
	end

	token, line = parseCodeToken(line)
	if token then
		if currentDescription ~= nil then
			currentField = nil
			currentDescriptionBlockType = "code"
			local block = {}
			block[currentDescriptionBlockType] = ""
			table.insert(currentDescription, block)
		end
	end

	token, line = parseTextToken(line)
	if token then
		if currentDescription ~= nil then
			currentField = nil
			currentDescriptionBlockType = "text"
			local block = {}
			block[currentDescriptionBlockType] = ""
			table.insert(currentDescription, block)
		end
	end

	text = parseInlineText(line)
	appendDescription(text)

	::continue::
end

-- for _,l in ipairs(lines) do
-- 	print(l)
-- end

-- print("\nDESCRIPTION:\n")

-- 	printDescription(doc.description)

-- print("\nTYPES:\n")

-- 	for _,t in ipairs(doc.types) do

-- 	print(t.name)

-- 	print("\nFUNCTIONS:\n")
-- 	for _,f in ipairs(t.functions) do

-- 		local paramsStr = "("

-- 		for i, p in ipairs(f.params) do
-- 			if i > 1 then paramsStr = paramsStr .. ", " end
-- 			paramsStr = paramsStr .. p.name
-- 			if p.types ~= nil and #p.types > 0 then
-- 				paramsStr = paramsStr .. " "
-- 				for it, t in ipairs(p.types) do
-- 					if it > 1 then paramsStr = paramsStr .. "|" end
-- 					paramsStr = paramsStr .. t
-- 				end
-- 			end
-- 		end

-- 		paramsStr = paramsStr .. ")"

-- 		local retStr = ""

-- 		if f.ret ~= nil then
-- 			local ret = f.ret
-- 			if ret.types ~= nil and #ret.types > 0 then
-- 				retStr = retStr .. " -> "
-- 				for it, t in ipairs(ret.types) do
-- 					if it > 1 then retStr = retStr .. "|" end
-- 					retStr = retStr .. t
-- 				end
-- 			end
-- 		end

-- 		print("# " .. f.name .. paramsStr .. retStr)

-- 		printDescription(f.description)

-- 		print("")
-- 	end

-- 	print("PROPERTIES:\n")
-- 	for _,p in ipairs(t.properties) do

-- 		print("# " .. p.name)
-- 		printDescription(p.description)
-- 	end
-- end

if output ~= nil then
	local f = io.open(output, "w")
	io.output(f)
	io.write(json.encode(doc))
	io.close()
else
	print(json.encode(doc))
end
