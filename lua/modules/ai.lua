--- This module exposes various AI APIs.
--- So far it allows to create chats & images, more features will be added at some point.

local ai = {}

local functions = {}

---@function CreateChat Creates a new AI chat with given context.
---@param self ai
---@param context string
---@return aiChat
---@code
--- local ai = require("ai")
--- local chat = ai:CreateChat("You are a geography expert that answers with answers of 20 words maximum.")
--- chat:Say("Give me 5 random european countries.", function(err, message)
---     if err then print(err) return end
---     print("ai says: " .. message)
--- end)
ai.CreateChat = function(_, context)
    local aiChat = {}
    aiChat.messages = {}
    if context then
		context = string.gsub(context, '"', '\"')
        table.insert(aiChat.messages, {
            role = "system",
            content = context
        })
    end
    aiChat.Say = functions.chatSay
    return aiChat
end

---@function CreateImage Generates image considering prompt and options. Returns a Quad or Shape depending on options.
---@param self ai
---@param prompt string
---@param options table
---@param callback function
---@code
--- local ai = require("ai")
---
--- ai:CreateImage("a cute cat", function(err, quad)
---     if err then print(err) return end
---     quad:SetParent(World)
---     quad.Position = Player.Position
--- end)
---
--- -- Quad 512x512, default style
--- ai:CreateImage("a cute cat", { size=512, pixelart=false }, function(err, quad)
---     if err then print(err) return end
---     quad.Width = 30
---     quad.Height = 30
---     quad:SetParent(World)
---     quad.Position = Player.Position
--- end)
---
--- -- Quad 256x256, pixel art style
--- ai:CreateImage("a cute cat", { size=256, pixelart=true }, function(err, quad)
---     if err then print(err) return end
---     quad.Width = 30
---     quad.Height = 30
---     quad:SetParent(World)
---     quad.Position = Player.Position
--- end)
---
--- -- Shape, always 32x32 pixel art
--- ai:CreateImage("a cute cat", { output="Shape", pixelart=true }, function(err, shape)
---     if err then print(err) return end
---     shape:SetParent(World)
---     shape.Position = Player.Position
--- end)
---
--- -- Just URL, you can HTTP:Get the content in the server side and pass it to Client to generate a Shape or a Quad.
--- -- Useful for multiplayer sync to avoid storing all shapes in memory to send it to new players.
--- -- You can save URLs and retrieve each Shape/Quad when a new player joins
--- ai:CreateImage("a cute cat", { size=512, output="Quad", pixelart=false, asURL=true }, function(err, url)
---     if err then print(err) return end
---     print("retrieved url: "..url)
---     Dev:CopyToClipboard(url) -- copy URL to clipboard
--- end)
ai.CreateImage = function(_, prompt, optionsOrCallback, callback)
    require("api").aiImageGenerations(prompt, optionsOrCallback, callback)
end

---@type aiChat

---@function Say Says something to [aiChat] and receives response through callback.
---@param self aiChat
---@param prompt string
---@param callback function
---@code
--- local ai = require("ai")
--- local chat = ai:CreateChat("You're a pirate, only answer like a grumpy pirate in 20 words max.")
--- chat:Say("Hey, how's life?", function(err, message)
---     if err then print(err) return end
---     print("ai says: " .. message)
--- end)
functions.chatSay = function(self, prompt, callback)
    if not prompt or #prompt <= 0 then
        return callback("Error: prompt is not valid")
    end
    prompt = string.gsub(prompt, '"', '\"') -- avoid issue with JSON

    table.insert(self.messages, {
        role = "user",
        content = prompt
    })

    require("api").aiChatCompletions(self.messages, function(err, message)
        if err then return callback(err) end
        callback(nil, message.content)
        message.content = string.gsub(message.content, '"', '\"') -- avoid issue with JSON
        table.insert(self.messages, message)
    end)
end

return ai
