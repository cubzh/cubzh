--- This module allows you to create UI toast messages

uikit = require("uikit")
theme = require("uitheme").current

-- in seconds
local TOAST_DEFAULT_DURATION = 4.0

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
		create = function(_, message, placement)
			-- placement default value
			placement = placement or mod.Placement.Center

			-- Create frame
			local frameConfig = {
				-- image = Data()
				unfocuses = false,
			}
			local toast = uikit:createFrame(Color.Black, frameConfig)
			toast.placement = placement

			local text = uikit:createText(message, Color.White)
			toast.text = text
			text:setParent(toast)

			toast.parentDidResize = function(_)
				local padding = theme.padding
				toast.Size = text.Size + Number2(padding * 1.5, padding * 1.5)
				text.position = toast.Size / 2 - text.Size / 2
				if toast.placement == mod.Placement.Center then
					toast.position = Screen.Size / 2 - toast.Size / 2
				elseif toast.placement == mod.Placement.TopRight then
					toast.position = Screen.Size
						- toast.Size
						- Number2(0, Screen.SafeArea.Top)
						- Number2(padding, padding)
				end
			end
			toast:parentDidResize()

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
