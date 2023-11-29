--- This module allows you to create UI toast messages

uikit = require("uikit")
theme = require("uitheme").current
ease = require("ease")

-- in seconds
local TOAST_DEFAULT_DURATION = 4.0
local PADDING = theme.padding

local mod = {}

mod.Placement = {
	Center = 0,
	TopRight = 2,
	Custom = 3,
}

local modMetatable = {
	__index = {
		-- Create a toast message
		-- @param message (string) The message to display
		create = function(_, message, placement, iconShape)
			-- validate params
			do
				local typePlacement = type(placement)
				if typePlacement ~= "nil" and typePlacement ~= "integer" then
					error("placement must be an integer or nil", 2)
				end
				local typeIconShape = type(iconShape)
				if typeIconShape ~= "nil" and typeIconShape ~= "Shape" and typeIconShape ~= "MutableShape" then
					error("iconShape must be a Shape, MutableShape or nil", 2)
				end
			end
			-- placement default value
			placement = placement or mod.Placement.Center

			-- Create frame
			local frameConfig = {
				-- image = Data()
				unfocuses = false,
			}
			local toast = uikit:createFrame(Color.Black, frameConfig)
			toast.placement = placement

			-- Create text
			local text = uikit:createText(message, Color.White)
			text:setParent(toast)
			toast.text = text

			-- Create icon (optional)
			if iconShape then
				local iconFrame = uikit:createShape(iconShape, { spherized = true })
				iconFrame:setParent(toast)
				toast.icon = iconFrame
			end

			-- Setup toast layout, size, and position
			toast.parentDidResize = function(_)
				if toast.icon then
					-- icon + text
					local toastHeight = text.Size.Y + (PADDING * 1.5)
					toast.icon.Size = Number2(toastHeight, toastHeight)
					toast.Size = Number2(toast.icon.Size.X + toast.text.Size.X + (PADDING * 2), toastHeight)
					toast.icon.position = Number2(PADDING, 0)
					toast.text.position.X = toast.icon.position.X + toast.icon.Size.X
					toast.text.position.Y = toast.Size.Y / 2 - text.Size.Y / 2
				else
					-- text only
					toast.Size = text.Size + Number2(PADDING * 1.5, PADDING * 1.5)
					text.position = toast.Size / 2 - text.Size / 2
				end

				local toastPosition = Number2(0, 0)
				if toast.placement == mod.Placement.Center then
					toastPosition = Screen.Size / 2 - toast.Size / 2
				elseif toast.placement == mod.Placement.TopRight then
					toastPosition = Screen.Size
						- toast.Size
						- Number2(0, Screen.SafeArea.Top)
						- Number2(PADDING, PADDING)
				end
				toast.position = toastPosition
			end
			toast:parentDidResize()

			-- Animate toast
			local toastPosition = Number2(0, 0)
			if toast.placement == mod.Placement.Center then
				toastPosition = Screen.Size / 2 - toast.Size / 2
				toast.position = toastPosition - Number2(0, toast.Height)
			elseif toast.placement == mod.Placement.TopRight then
				toastPosition = Screen.Size - toast.Size - Number2(0, Screen.SafeArea.Top) - Number2(PADDING, PADDING)
				toast.position = toastPosition + Number2(toast.Width, 0)
			end
			ease:cancel(toast)
			ease:outBack(toast, 0.75).position = Number3(toastPosition.X, toastPosition.Y, 0)

			-- Remove toast after a while
			toast.removeTimer = Timer(TOAST_DEFAULT_DURATION, function()
				toast:setParent(nil)
				toast.removeTimer = nil
			end)

			return toast
		end,
	},
}
setmetatable(mod, modMetatable)

return mod
