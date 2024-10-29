local PRINT_JSONL_ENTRIES = true
local PRINT_JSONL_MODE_READABLE = true
local DEBUG_LOGS = false

local debug = function(...)
	if not DEBUG_LOGS then
		return
	end
	print(...)
end

local json = require("json")
local yml = require("yaml")

local exe = arg[0]
local file = arg[1]
local output = arg[2]

local outputFile
local firstEntry = false
if output ~= nil then
	debug("OUTPUT:", output)
	outputFile = io.open(output, "a+")
	outputFile:seek("set", 0)
	size = outputFile:seek("end")
	firstEntry = size == 0
end

local system =
	"Buzzh is a senior Cubzh developer chatbot that always provides the shortest useful answers to help users create on the Cubzh platform. Buzzh always considers discussions to be about Cubzh and coding questions about Lua scripting for Cubzh (only using Cubzh's official APIs and never mentioning Lua features that aren't explicitly supported in the Cubzh environment)."

local function jsonlEntry(user, assistant)
	local e = {
		messages = {
			{
				role = "system",
				content = system,
			},
			{
				role = "user",
				content = user,
			},
			{
				role = "assistant",
				content = assistant,
			},
		},
	}

	local jsonE = json.encode(e)

	if PRINT_JSONL_ENTRIES then
		if PRINT_JSONL_MODE_READABLE then
			print("USER: " .. e.messages[2].content)
			print("ASSISTANT: \n" .. e.messages[3].content)
		else
			print(jsonE)
		end
	end

	if outputFile ~= nil then
		io.output(outputFile)
		if firstEntry == true then
			firstEntry = false
		else
			io.write("\n")
		end
		io.write(jsonE)
	end

	return jsonE
end

-- add introduction data about Cubzh if data.jsonl is empty
if firstEntry then
	jsonlEntry(
		"What is Cubzh?",
		"Cubzh is a platforms where users can create all kinds of digital experiences. It's a very lighweight application (~20MB) that you can install on mobile (iOS, Android) or desktop (Windows, macOS), you can also use it in your browser at https://app.cu.bzh"
	)
	jsonlEntry(
		"What is Cubzh's scripting language?",
		"All games and experiences in Cubzh are scripted in Lua. (https://docs.cu.bzh)"
	)
	jsonlEntry("What version of Lua?", "Cubzh uses Lua 5.3")
	jsonlEntry("Where can I find Cubzh dev documentation?", "Right here: https://docs.cu.bzh")
	jsonlEntry(
		"I just want to play games, is that ok?",
		"Sure! There are many games on Cubzh, and new ones get published by community members each day!"
	)
	jsonlEntry(
		"Can you show me a Hello World?",
		'```lua\nClient.OnStart = function()\n\tprint("Hello World!")\nend\n```'
	)
end

debug("file:", file)

-- local moduleName = string.match(file, "([a-zA-Z][a-zA-Z0-9]*).lua$")

-- -- print("module:", moduleName)

-- file = string.gsub(file, "^%.", os.getenv("PWD"))

-- -- print("file: " .. file)

local f = io.open(file, "r")
if f == nil then
	error("could not open " .. file)
end

local content = f:read("*all")
f:close()

local doc = yml.load(content)

local function sanitize(str)
	return str:gsub("%[([^%]]+)%]", "%1")
end

if doc.type ~= nil then
	-- print(doc.type)
	-- print(doc.description)

	local informationResponse = sanitize(doc.description)
	if doc.properties ~= nil and #doc.properties > 0 then
		informationResponse = informationResponse .. "\n" .. doc.type .. " exposes those properties:"
		for i, p in ipairs(doc.properties) do
			if p.name ~= nil then
				if i > 1 then
					informationResponse = informationResponse .. ", " .. p.name
				else
					informationResponse = informationResponse .. " " .. p.name
				end
			end
		end
	end
	if doc.functions ~= nil and #doc.functions > 0 then
		informationResponse = informationResponse .. "\n" .. doc.type .. " exposes those functions:"
		for i, fn in ipairs(doc.functions) do
			if fn.name ~= nil then
				if i > 1 then
					informationResponse = informationResponse .. ", " .. fn.name
				else
					informationResponse = informationResponse .. " " .. fn.name
				end
			end
		end
	end
	jsonlEntry("I would like information about the " .. doc.type .. " API.", informationResponse)

	jsonlEntry(
		"Do I need to require " .. doc.type .. " to use it?",
		"No, "
			.. doc.type
			.. " is part of Cubzh's system environment. You can can use it from anywhere without calling `require` and without mentioning it in the `Modules` import table."
	)

	if doc.creatable == false then
		jsonlEntry(
			"How to create an instance of " .. doc.type .. "?",
			doc.type .. " is not creatable, there's only one globally exposed instance of it."
		)
	end

	-- if doc.properties ~= nil then
	--     for _, property in ipairs(doc.properties) do

	--     end
	-- end

	if doc.functions ~= nil then
		for _, fn in ipairs(doc.functions) do
			if fn.name ~= nil then
				if fn.description ~= nil then
					jsonlEntry(
						"I would like information about the " .. doc.type .. " " .. fn.name .. " function.",
						sanitize(fn.description)
					)
				end
				if fn["argument-sets"] ~= nil then
					local response = ""
					-- if #fn["argument-sets"] == 1 then
					response = doc.type .. " " .. fn.name .. " can be called with those parameters:\n```lua"
					-- end
					for _, set in ipairs(fn["argument-sets"]) do
						-- TODO: through instance when creatable
						local nbArgs = #set
						local hasOptionalArgs = false
						for i, arg in ipairs(set) do
							if arg.optional == true then
								hasOptionalArgs = true
								break
							end
						end

						-- first loop ignoring all optional args
						do
							-- comments to describe parameters
							-- response = response .. "\n-- Parameters:"
							response = response .. "\n" .. doc.type .. ":" .. fn.name .. "("
							for i, arg in ipairs(set) do
								response = response .. (i > 1 and ", " or "") .. arg.name
							end
							response = response .. ")"
							local first = true
							for i, arg in ipairs(set) do
								if arg.optional ~= true then
									if first then
										first = false
										response = response .. " -- " .. arg.name .. " (" .. arg.type .. ")"
									else
										response = response .. ", " .. arg.name .. " (" .. arg.type .. ")"
									end
								end
							end
						end

						-- do it again including all optional args
						if hasOptionalArgs then
							do
								-- comments to describe parameters
								-- response = response .. "\n-- Parameters:"
								response = response .. "\n" .. doc.type .. ":" .. fn.name .. "("
								for i, arg in ipairs(set) do
									response = response .. (i > 1 and ", " or "") .. arg.name
								end
								response = response .. ")"
								local first = true
								for i, arg in ipairs(set) do
									if first then
										first = false
										response = response .. " -- " .. arg.name .. " (" .. arg.type .. ")"
									else
										response = response .. ", " .. arg.name .. " (" .. arg.type .. ")"
									end
								end
							end
						end
					end
					response = response .. "\n```"

					debug(response)
					jsonlEntry("What are " .. doc.type .. " " .. fn.name .. " parameters?", response)
				end
				if fn.samples ~= nil then
					for _, sample in ipairs(fn.samples) do
						if sample.code ~= nil then
							local response = "```lua\n" .. sample.code .. "\n```"
							if sample.description ~= nil then
								response = sample.description .. "\n\n" .. response
							end
							jsonlEntry(
								"Show me how to use the " .. doc.type .. " " .. fn.name .. " function.",
								response
							)
						end
					end
				end
			end
		end
	end
end
