--- This module allows you to use AI to chat and generate images.
---@code -- A few examples:
---  
--- local aiChat = ai:CreateChat("You are a geography expert that answers with answers of 20 words maximum.")
--- aiChat:Say("Give me 5 random european countries.", function(err, message)
---     if err then print(err) return end
---     print("AI says: " .. message)
--- end)
---
--- AI:CreateImage("a cute cat", function(err, quad)
---     if err then print(err) return end
---     quad:SetParent(World)
---     quad.Position = Player.Position
--- end)
---
--- -- Quad 512x512, default style
--- AI:CreateImage("a cute cat", { size=512, pixelart=false }, function(err, quad)
---     if err then print(err) return end
---     quad.Width = 30
---     quad.Height = 30
---     quad:SetParent(World)
---     quad.Position = Player.Position
--- end)
---
--- -- Quad 256x256, pixel art style
--- AI:CreateImage("a cute cat", { size=256, pixelart=true }, function(err, quad)
---     if err then print(err) return end
---     quad.Width = 30
---     quad.Height = 30
---     quad:SetParent(World)
---     quad.Position = Player.Position
--- end)
---
--- -- Shape, always 32x32 pixel art
--- AI:CreateImage("a cute cat", { output="Shape", pixelart=true }, function(err, shape)
---     if err then print(err) return end
---     shape:SetParent(World)
---     shape.Position = Player.Position
--- end)
---
--- -- Just URL, you can HTTP:Get the content in the server side and pass it to Client to generate a Shape or a Quad.
--- -- Useful for multiplayer sync to avoid storing all shapes in memory to send it to new players.
--- -- You can save URLs and retrieve each Shape/Quad when a new player joins
--- AI:CreateImage("a cute cat", { size=512, output="Quad", pixelart=false, asURL=true }, function(err, url)
---     if err then print(err) return end
---     print("retrieved url: "..url)
---     Dev:CopyToClipboard(url) -- copy URL to clipboard
--- end)

---@type ai

local ai = {}

---@function aiChat:say Ask AI
---@param self aiChat
---@param prompt string
---@param callback function
ai._chatSay = function(self, prompt, callback)
    if not prompt or #prompt <= 0 then
        return callback("Error: prompt is not valid")
    end
    prompt = string.gsub(prompt, '"', '\\"') -- avoid issue with JSON

    table.insert(self.messages, {
        role = "user",
        content = prompt
    })

    require("api").aiChatCompletions(self.messages, function(err, message)
        if err then return callback(err) end
        callback(nil, message.content)
        message.content = string.gsub(message.content, '"', '\\"') -- avoid issue with JSON
        table.insert(self.messages, message)
    end)
end

---@function createChat Create a new AI chat
---@param self ai
---@param context string
ai.CreateChat = function(self, context)
    local aiChat = {}
    aiChat.messages = {}
    if context then
        table.insert(aiChat.messages, {
            role = "system",
            content = context
        })
    end
    aiChat.Say = ai._chatSay
    return aiChat
end

---@function CreateImage Create a generated image, either pixel-art or classic image
---@param self ai
---@param prompt string
---@param options table
---@param callback function
ai.CreateImage = function(self, prompt, optionsOrCallback, callback)
    require("api").aiImageGenerations(prompt, optionsOrCallback, callback)
end

---@type aiChat
---@property say function

return ai
