# Hugging Face module

This module is an Hugging Face API client.
The call function targets the Inference API.
The modelName passed as first parameter must be an endpoint that is compatible with the Inference API.
Depending on the model, the response can be a text, an image or audio data.

![image-genaration.gif](https://raw.githubusercontent.com/cubzh/cubzh/main/mods/huggingface/img/image-genaration.gif)

Usage examples:

```lua
Modules = {
    hf = "github.com/cubzh/cubzh/mods/huggingface"
}

-- Text generation example
Client.OnChat = function(payload)
    -- Use a custom prompt to place the user input inside a User/Assistant context
    local inputs = "User:"..payload.message.."\n\nAssistant:"
    local model = "google/gemma-7b"
    hf:call(model, inputs, function(success, response)
        if not success then
            error(response.error)
        end
        -- remove the user input from the response
        local responseText = string.sub(response.text,#inputs + 1,#response.text)
        -- display response in a text bubble above player
        Player:TextBubble(responseText)
        print(responseText) -- also display response in the chat
    end)
end

-- Image generation example
Client.OnChat = function(payload)
    local inputs = payload.message
    local model = "runwayml/stable-diffusion-v1-5"
    hf:call(model, inputs, function(success, response)
        if not success then
            error(response.error)
        end
        local quad = response.quadImage
        quad:SetParent(World)
        quad.Position = Player.Position
        quad.Rotation.Y = Player.Rotation.Y
        -- you can also access the image Data using response.image
    end)
end

-- Sound generation example
Client.OnChat = function(payload)
    local inputs = payload.message
    local model = "suno/bark-small"
    hf:call(model, inputs, function(success, response)
        if not success then
            error(response.error)
        end
        print("playing", inputs)
        local audioSource = response.audioSource
        -- This audioSource is by default added in the World without spatialization
        audioSource:Play()
        -- you can also access the sound Data using response.audio
    end)
end
```
