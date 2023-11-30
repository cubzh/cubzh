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
		maxWidth = nil,
		center = false,
		iconShape = nil,
		animationSpeed = 250, -- in points per second
		duration = 4.0, -- in seconds
	}

	config = require("config"):merge(DEFAULT_CONFIG, config, {
		acceptTypes = {
			maxWidth = { "number", "integer" },
			iconShape = { "Shape", "MutableShape" },
		},
	})

	local toast = {}
	local toastFrame = uikit:createFrame(Color.Black)
	toast.frame = toastFrame

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
	text:setParent(toastFrame)
	-- apply max width if specified
	if config.maxWidth then
		text.object.MaxWidth = config.maxWidth
	end

	-- Create icon (optional)
	local iconFrame
	if config.iconShape then
		iconFrame = uikit:createShape(config.iconShape, { spherized = true })
		iconFrame:setParent(toastFrame)
	end

	-- Setup toast layout, size, and position
	toastFrame.parentDidResize = function(_)
		if iconFrame then
			-- icon + text
			local toastHeight = text.Size.Y + (PADDING * 1.5)
			iconFrame.Size = Number2(toastHeight, toastHeight)
			toastFrame.Size = Number2(iconFrame.Size.X + text.Size.X + (PADDING * 2), toastHeight)
			iconFrame.position = Number2(PADDING, 0)
			text.position.X = iconFrame.position.X + iconFrame.Size.X
			text.position.Y = toastFrame.Size.Y / 2 - text.Size.Y / 2
		else
			-- text only
			toastFrame.Size = text.Size + Number2(PADDING * 1.5, PADDING * 1.5)
			text.position = toastFrame.Size / 2 - text.Size / 2
		end

		local toastPosition
		if config.center then
			toastPosition = Screen.Size / 2 - toastFrame.Size / 2
		else
			toastPosition = Screen.Size - toastFrame.Size - Number2(0, Screen.SafeArea.Top) - Number2(PADDING, PADDING)
		end
		toastFrame.position = toastPosition
	end
	toastFrame:parentDidResize()

	-- Animate toast
	local toastPosition
	local animationDuration
	if config.center then
		local animationDistance = toastFrame.Height * 2
		toastPosition = Screen.Size / 2 - toastFrame.Size / 2
		toastFrame.position = toastPosition - Number2(0, animationDistance)
		animationDuration = animationDistance / config.animationSpeed
	else
		toastPosition = Screen.Size - toastFrame.Size - Number2(0, Screen.SafeArea.Top) - Number2(PADDING, PADDING)
		toastFrame.position = toastPosition + Number2(toastFrame.Width, 0)
		animationDuration = toastFrame.Width / config.animationSpeed
	end
	ease:cancel(toastFrame)
	ease:outBack(toastFrame, animationDuration).position = Number3(toastPosition.X, toastPosition.Y, 0)

	-- If a duration has been specified (positive value), remove toast after a while
	if config.duration ~= nil and config.duration >= 0 then
		toast.removeTimer = Timer(config.duration, function()
			if toastFrame == centerToast then
				centerToast = nil
			elseif toastFrame == topRightToast then
				topRightToast = nil
			end
			toast.removeTimer = nil
			toastFrame:remove()
		end)
	end

	-- Provide a function to remove the toast
	toast.remove = function(p_toast)
		if p_toast == centerToast then
			centerToast = nil
		elseif p_toast == topRightToast then
			topRightToast = nil
		end
		p_toast.frame:remove()
	end

	return toast
end

return mod
