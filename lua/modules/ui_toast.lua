--- This module allows you to create UI toast messages

uikit = require("uikit")
ease = require("ease")

local PADDING = require("uitheme").current.padding

topRightToast = nil
centerToast = nil

local mod = {}

mod.create = function(_, config)
	local DEFAULT_CONFIG = {
		message = "hello!",
		center = false,
		iconShape = nil,
		duration = 4.0, -- in seconds
		animationSpeed = 250, -- in points per second
	}

	config = require("config"):merge(DEFAULT_CONFIG, config, {
		acceptTypes = {
			iconShape = { "Shape", "MutableShape" },
		},
	})

	local toast = uikit:createFrame(Color.Black)

	if config.center then
		if centerToast then
			centerToast.removeTimer:Cancel()
			centerToast:remove()
		end
		centerToast = toast
	else
		if topRightToast then
			topRightToast.removeTimer:Cancel()
			topRightToast:remove()
		end
		topRightToast = toast
	end

	-- Create text
	local text = uikit:createText(config.message, Color.White)
	text:setParent(toast)

	-- Create icon (optional)
	local iconFrame
	if config.iconShape then
		iconFrame = uikit:createShape(config.iconShape, { spherized = true })
		iconFrame:setParent(toast)
	end

	-- Setup toast layout, size, and position
	toast.parentDidResize = function(_)
		if iconFrame then
			-- icon + text
			local toastHeight = text.Size.Y + (PADDING * 1.5)
			iconFrame.Size = Number2(toastHeight, toastHeight)
			toast.Size = Number2(iconFrame.Size.X + text.Size.X + (PADDING * 2), toastHeight)
			iconFrame.position = Number2(PADDING, 0)
			text.position.X = iconFrame.position.X + iconFrame.Size.X
			text.position.Y = toast.Size.Y / 2 - text.Size.Y / 2
		else
			-- text only
			toast.Size = text.Size + Number2(PADDING * 1.5, PADDING * 1.5)
			text.position = toast.Size / 2 - text.Size / 2
		end

		local toastPosition
		if config.center then
			toastPosition = Screen.Size / 2 - toast.Size / 2
		else
			toastPosition = Screen.Size - toast.Size - Number2(0, Screen.SafeArea.Top) - Number2(PADDING, PADDING)
		end
		toast.position = toastPosition
	end
	toast:parentDidResize()

	-- Animate toast
	local toastPosition
	local animationDuration
	if config.center then
		local animationDistance = toast.Height * 2
		toastPosition = Screen.Size / 2 - toast.Size / 2
		toast.position = toastPosition - Number2(0, animationDistance)
		animationDuration = animationDistance / config.animationSpeed
	else
		toastPosition = Screen.Size - toast.Size - Number2(0, Screen.SafeArea.Top) - Number2(PADDING, PADDING)
		toast.position = toastPosition + Number2(toast.Width, 0)
		animationDuration = toast.Width / config.animationSpeed
	end
	ease:cancel(toast)
	ease:outBack(toast, animationDuration).position = Number3(toastPosition.X, toastPosition.Y, 0)

	-- Remove toast after a while
	toast.removeTimer = Timer(config.duration, function()
		if toast == centerToast then
			centerToast = nil
		elseif toast == topRightToast then
			topRightToast = nil
		end
		toast.removeTimer = nil
		toast:remove()
	end)
end

return mod
