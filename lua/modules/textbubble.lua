-- The following functions have been deprecated as of 0.0.48,
-- - Object:TextBubble(string text, number duration, number offset, Color color, Color bgColor, boolean tail)
-- - Object:ClearTextBubble()
--
-- They were replaced by the Text API: https://docs.cu.bzh/reference/text
--
-- Here is an example of how to re-enact the legacy use of text bubbles with the new Text objects.

local textbubble = {}

textbubble.set = function(object, text, duration, offset, color, backgroundColor, tail)
	if object == nil then
		return
	end

	if object.__text == nil then
		object.__text = Text()
		object.__text.Type = TextType.Screen
		object.__text.IsUnlit = true
		object.__text.FontSize = Text.FontSizeDefault
		object.__text:SetParent(object)
	end

	object.__text.MaxWidth = 400
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

textbubble.clear = function(object)
	if object ~= nil and object.__text ~= nil then
		object.__text:RemoveFromParent()
		object.__text = nil
	end
end

return textbubble
