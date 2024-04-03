-- The following functions have been deprecated as of 0.0.48,
-- - Object:TextBubble(string text, number duration, number offset, Color color, Color bgColor, boolean tail)
-- - Object:ClearTextBubble()
--
-- They were replaced by the Text API: https://docs.cu.bzh/reference/text
--
-- Here is an example of how to re-enact the legacy use of text bubbles with the new Text objects.

textbubbles = {}

-- keeping weak references on all creates bubbles
-- to adapt font size when screen size changes
-- each entry contains bubble config, indexed by bubble table ref
bubbles = {}
bubblesMT = {
	__mode = "k", -- weak keys
	__metatable = false,
}
setmetatable(bubbles, bubblesMT)

textbubbles.set = function(object, text, duration, offset, color, backgroundColor, tail)
	if object == nil then
		return
	end

	if object.__text == nil then
		object.__text = Text()
		object.__text.Type = TextType.Screen
		object.__text.Padding = 5
		object.__text.IsUnlit = true
		object.__text.FontSize = Text.FontSizeDefault
		object.__text:SetParent(object)
	end

	object.__text.MaxWidth = 250
	object.__text.Text = text ~= nil and text or ""
	object.__text.LocalPosition = offset ~= nil and offset or { 0, 0, 0 }
	object.__text.Color = color ~= nil and color or Color.Black
	object.__text.BackgroundColor = backgroundColor ~= nil and backgroundColor or Color.White
	object.__text.Tail = tail ~= nil and tail or false

	if object.__text.__timer ~= nil then
		object.__text.__timer:Cancel()
		object.__text.__timer = nil
	end
	if duration ~= nil and duration > 0 then
		object.__text.__timer = Timer(duration, false, function()
			object.__text.Text = ""
			object.__text.__timer = nil
		end)
	end
end

textbubbles.clear = function(object)
	if object ~= nil and object.__text ~= nil then
		object.__text:RemoveFromParent()
		object.__text = nil
	end
end

defaultFontSize = function()
	return Text.FontSizeSmall
end

emptyFunction = function() end

textbubbles.create = function(self, config)
	if self ~= textbubbles then
		error("textbubbles:create should be called with `:`", 2)
	end

	local defaultConfig = {
		text = "...",
		maxWidth = 250,
		padding = 5,
		tail = true,
		textColor = Color.Black,
		backgroundColor = Color.White,
		-- fontSize has to be a function, it is called
		-- when the screen size or resolution changes
		fontSize = defaultFontSize,
		onExpire = emptyFunction, -- called when bubble is removed by timer
		expiresIn = 0, -- time in seconds, 0 -> remains displayed forever
	}

	config = require("config"):merge(defaultConfig, config)

	local t = Text()
	t.Type = TextType.Screen
	t.MaxWidth = config.maxWidth
	t.Padding = config.padding
	t.IsUnlit = true
	t.FontSize = config.fontSize()
	t.Color = config.textColor
	t.BackgroundColor = config.backgroundColor
	t.Tail = config.tail
	t.Text = config.text

	if config.expiresIn > 0 and tickListener == nil then
		tickListener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
			local removeTickListener = true
			for bubble, config in pairs(bubbles) do
				if bubble.Parent ~= nil then
					if config.expiresIn ~= 0 then
						removeTickListener = false
						config.expiresIn = config.expiresIn - dt
						if config.expiresIn <= 0 then
							config.expiresIn = 0
							config.onExpire(bubble)
							if bubble.Parent ~= nil then
								bubble:RemoveFromParent()
							end
						end
					end
				end
			end
			if removeTickListener then
				tickListener:Remove()
				tickListener = nil
			end
		end)
	end

	bubbles[t] = config

	return t
end

LocalEvent:Listen(LocalEvent.Name.ScreenDidResize, function()
	for bubble, config in pairs(bubbles) do
		bubble.FontSize = config.fontSize()
	end
end)

displayPlayerChatBubbles = false

mt = {
	__index = {},
	__newindex = function(t, k, v)
		if k == "displayPlayerChatBubbles" then
			if type(v) == "boolean" then
				if v ~= displayPlayerChatBubbles then
					displayPlayerChatBubbles = v
					if displayPlayerChatBubbles then
                    -- TODO: review this
						chatListener = LocalEvent:Listen(LocalEvent.Name.Log, function(msgInfo)
							if msgInfo.sender.id ~= nil and msgInfo.message ~= nil then
								local sender = Players[msgInfo.sender.id]
								if sender ~= nil then
									sender:TextBubble(msgInfo.message)
								end
							end
						end)
					else
						if chatListener then
							chatListener:Remove()
						end
					end
				end
			end
		else
			error("textbubbles." .. k .. " can't be set", 2)
		end
	end,
}
setmetatable(textbubbles, mt)

return textbubbles
