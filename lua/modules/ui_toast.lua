--- This module allows you to create UI toast messages

uikit = require("uikit")
ease = require("ease")

-- Global variables
local PADDING = require("uitheme").current.padding
local topRightStack = {}
local centerStack = {}

local mod = {}

mod.create = function(_, config)
	local DEFAULT_CONFIG = {
		message = "hello!",
		maxWidth = 250,
		center = false,
		iconShape = nil,
		animationSpeed = 250, -- in points per second
		duration = 4.0, -- in seconds
		keepInStack = true, -- when false, the toast is not kept in the stack when a new toast comes in
		closeButton = false,
		actionText = "",
		action = nil,
	}

	config = require("config"):merge(DEFAULT_CONFIG, config, {
		acceptTypes = {
			iconShape = { "Shape", "MutableShape" },
			action = { "function" },
		},
	})

	-- create toast object
	local toast = {}
	toast.config = config
	toast.remove = remove

	local toastFrame = uikit:createFrame(Color.Black)
	toast.frame = toastFrame

	toast.stack = config.center and centerStack or topRightStack
	-- If there already is a toast on the stack, disable it
	if #toast.stack > 0 then
		local t = toast.stack[#toast.stack]
		if t.config.keepInStack == false then
			t:remove()
		else
			disable(toast.stack[#toast.stack])
		end
	end
	-- Push new toast to stack
	table.insert(toast.stack, toast)

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

	local actionBtn
	if config.action then
		actionBtn = uikit:createButton(config.actionText)
		actionBtn:setParent(toastFrame)
		actionBtn.onRelease = function()
			config.action()
		end
	end

	-- Setup toast layout, size, and position
	toastFrame.parentDidResize = function(_)
		if iconFrame then
			-- icon + text
			local toastHeight = text.Size.Y + (PADDING * 1.5)
			iconFrame.Size = Number2(toastHeight, toastHeight)
			toastFrame.Size = Number2(iconFrame.Size.X + text.Size.X + (PADDING * 2), toastHeight)
			iconFrame.pos = { PADDING, 0 }
			text.position.X = iconFrame.position.X + iconFrame.Size.X
			text.position.Y = toastFrame.Size.Y / 2 - text.Size.Y / 2
		else
			-- text only
			toastFrame.Size = text.Size + Number2(PADDING * 1.5, PADDING * 1.5)
			text.position = toastFrame.Size / 2 - text.Size / 2
		end

		if actionBtn then
			actionBtn.Width = toastFrame.Width
			actionBtn.pos = { toastFrame.Width - actionBtn.Width, -actionBtn.Height }
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
	enable(toast)

	return toast
end

-- start toast timer
constructAndStartTimer = function(p_toast)
	if p_toast.config.duration ~= nil and p_toast.config.duration >= 0 then
		if p_toast.removeTimer then
			p_toast.removeTimer:Cancel()
			p_toast.removeTimer = nil
		end
		p_toast.removeTimer = Timer(p_toast.config.duration, function()
			p_toast:remove()
		end)
	end
end

-- Provide a function to remove the toast
remove = function(p_toast)
	if p_toast.removeTimer then
		p_toast.removeTimer:Cancel()
		p_toast.removeTimer = nil
	end

	-- Remove toast from stack
	local stack = p_toast.stack
	for i, toast in ipairs(stack) do
		if toast == p_toast then
			if i == #stack and i > 1 then -- toast is on top
				-- re-enable toast below
				enable(stack[i - 1])
			end
			table.remove(stack, i)
			break
		end
	end

	p_toast.frame:remove()
end

-- temporary disable toast
disable = function(p_toast)
	p_toast.frame:hide()
	if p_toast.removeTimer then
		p_toast.removeTimer:Cancel()
		p_toast.removeTimer = nil
	end
end

-- re-enable toast
enable = function(p_toast)
	local frame = p_toast.frame

	p_toast.frame:show()

	local toastPosition
	local animationDuration
	if p_toast.config.center then
		local animationDistance = frame.Height * 2
		toastPosition = Screen.Size / 2 - frame.Size / 2
		frame.position = toastPosition - Number2(0, animationDistance)
		animationDuration = animationDistance / p_toast.config.animationSpeed
	else
		toastPosition = Screen.Size - frame.Size - Number2(0, Screen.SafeArea.Top) - Number2(PADDING, PADDING)
		frame.position = toastPosition + Number2(frame.Width, 0)
		animationDuration = frame.Width / p_toast.config.animationSpeed
	end
	ease:cancel(frame)
	ease:outBack(frame, animationDuration).position = Number3(toastPosition.X, toastPosition.Y, 0)

	constructAndStartTimer(p_toast)
end

return mod
