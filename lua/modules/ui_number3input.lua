--[[ Example
	local node = ui_number3input:create({
		shape = shape,
		field = "fullname",

		-- when typing a value, what is the value to apply
		textToField = function(text) return tonumber(text) end,

		-- when the value changed in the shape, how to display it in the input
		fieldToText = function(field) return string.format("%.2f", field) end
	})
--]]

local defaultConfig = {
	textToField = function(text)
		return tonumber(text)
	end,
	fieldToText = function(field)
		return string.format("%.1f", field)
	end,
	shape = nil,
	field = nil,
}

local create = function(_, config)
	config = require("config"):merge(defaultConfig, config, {
		acceptTypes = {
			textToField = { "function" },
			fieldToText = { "function" },
			shape = { "Shape", "Object", "MutableShape" },
			field = { "string" },
		},
	})

	local ui = require("uikit")
	local padding = require("uitheme").current.padding
	local nodeContainer = require("ui_container"):createHorizontalContainer()

	local shape = config.shape
	if not config.field then
		error('missing "field" in config', 2)
	end
	local textToField = config.textToField
	local fieldToText = config.fieldToText

	local updateUI

	local xInput
	local xText
	local yInput
	local yText
	local zInput
	local zText
	local currentValue = shape and shape[config.field] or Number3(0, 0, 0)
	xInput = ui:createTextInput(math.deg(currentValue.X), "X")
	xInput.onSubmit = function()
		shape[config.field].X = textToField(xInput.Text)
		updateUI()
	end
	xText = ui:createButton("X")
	xText.Height = xInput.Height
	xText.onRelease = function()
		xInput:focus()
	end
	xText:setColor(Color.Red)
	yInput = ui:createTextInput(math.deg(currentValue.Y), "Y")
	yInput.onSubmit = function()
		shape[config.field].Y = textToField(yInput.Text)
		updateUI()
	end
	yText = ui:createButton("Y")
	yText.onRelease = function()
		yInput:focus()
	end
	yText:setColor(Color.Green)
	zInput = ui:createTextInput(math.deg(currentValue.Z), "Z")
	zInput.onSubmit = function()
		shape[config.field].Z = textToField(zInput.Text)
		updateUI()
	end
	zText = ui:createButton("Z")
	zText.onRelease = function()
		zInput:focus()
	end
	zText:setColor(Color.Blue)

	updateUI = function()
		if not shape then
			return
		end
		xInput.Text = fieldToText(shape[config.field].X)
		yInput.Text = fieldToText(shape[config.field].Y)
		zInput.Text = fieldToText(shape[config.field].Z)
		nodeContainer:parentDidResize()
	end
	nodeContainer.setShape = function(_, newShape)
		if shape then
			shape[config.field]:RemoveOnSetCallback(updateUI)
		end
		shape = newShape
		shape[config.field]:AddOnSetCallback(updateUI)
		updateUI()
	end

	if shape then
		nodeContainer:setShape(shape)
	end

	nodeContainer:pushElement(xText)
	nodeContainer:pushElement(xInput)
	nodeContainer:pushElement(yText)
	nodeContainer:pushElement(yInput)
	nodeContainer:pushElement(zText)
	nodeContainer:pushElement(zInput)

	nodeContainer.parentDidResize = function()
		xInput.Width = (250 - xText.Width * 3 - padding * 2) / 3
		yInput.Width = xInput.Width
		zInput.Width = xInput.Width

		xText.Height = xInput.Height
		yText.Height = yInput.Height
		zText.Height = zInput.Height
		nodeContainer:refresh()
	end

	return nodeContainer
end

return {
	create = create,
}
