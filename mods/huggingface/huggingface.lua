--[[
--- This module is responsible for calling the Hugging Face API.
--- The call method is using the Inference API. The modelName passed as first parameter must be an endpoint compatible with the Inference API.
--- The callback is called when the response is received.
--- success is a boolean indicating if the call was successful or not.
--- response is a table containing:
---     - data: the raw Data returned by the API
---     - error: the error message returned by the API
---     - rawText: the raw JSON response as text
---     - text: the parsed text
---     - quadImage: the Quad type containing the image
---     - image: the image data (alias of data)
---     - audioSource: the AudioSource, use audioSource:Play() to play the sound
---     - audio: the audio data (alias of data)
---
---@code -- A few examples:
---
--- Modules = {
---    huggingFace = "github.com/cubzh/cubzh/mods/huggingface"
--- }
---
--- -- Text generation example
--- Client.OnChat = function(payload)
--- 	-- Use a custom prompt to place the user input inside a User/Assistant context
---     local inputs = "User:"..payload.message.."\n\nAssistant:"
---     local model = "google/gemma-7b"
---     huggingFaceModule:call(model, inputs, function(success, response)
--- 	    	if not success then
---             error(response.error)
---         end
--- 		-- remove the user input from the response
--- 		local responseText = string.sub(response.text,#inputs + 1,#response.text)
---         Player:TextBubble(responseText) -- display response a bubble above the player
--- 		print(responseText) -- display response in the chat
---     end)
--- end
---
--- -- Image generation example
--- Client.OnChat = function(payload)
---     local inputs = payload.message
---     local model = "runwayml/stable-diffusion-v1-5"
---     huggingFaceModule:call(model, inputs, function(success, response)
---	    	if not success then
---             error(response.error)
---         end
---         local quad = response.quadImage
---		    quad:SetParent(World)
---		    quad.Position = Player.Position
---		    quad.Rotation.Y = Player.Rotation.Y
---
---         -- you can also access the image Data using response.image
---	    end)
--- end
---
--- -- Sound generation example
--- Client.OnChat = function(payload)
---     local inputs = payload.message
---     local model = "suno/bark-small"
---     huggingFaceModule:call(model, inputs, function(success, response)
---	    	if not success then
---             error(response.error)
---         end
---    		print("playing", inputs)
---         local audioSource = response.audioSource
---         -- This audioSource is by default added in the World without spatialization
---	    	audioSource:Play()
---         -- you can also access the sound Data using response.audio
---	    end)
--- end
--]]

local huggingFaceModule = {}

huggingFaceModule.call = function(_, modelName, inputs, callback)
	local modelUrl = "https://api-inference.huggingface.co/models/" .. modelName
	local headers = {
		["Content-Type"] = "application/json",
	}
	local body = { inputs = inputs }
	HTTP:Post(modelUrl, headers, body, function(res)
		local success = res.StatusCode == 200
		local raw_text = res.Body:ToString()
		local data
		if not success then
			data = {
				statusCode = res.StatusCode,
				rawData = res.Body,
				error = JSON:Decode(raw_text).error,
			}
		else
			data = {
				statusCode = res.StatusCode,
				data = res.Body,
				rawText = raw_text,
				image = res.Body,
			}

			-- Make Quad
			local quad = Quad()
			quad.Width = 30
			quad.Height = 30
			quad.Anchor = { 0.5, 0 }
			quad.Image = res.Body
			data.quadImage = quad

			if string.sub(raw_text, 1, 1) == "[" or string.sub(raw_text, 1, 1) == "{" then
				data.text = JSON:Decode(raw_text)[1].generated_text
			end
			if string.sub(raw_text, 1, 4) == "fLaC" then
				local audioSource = AudioSource()
				audioSource:SetParent(World)
				audioSource.Spatialized = false
				audioSource.Sound = res.Body
				data.audioSource = audioSource
				data.audio = res.Body
			end
		end
		callback(success, data)
	end)
end

return huggingFaceModule
