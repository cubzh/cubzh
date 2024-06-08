local mod = {}

ui = require("uikit")
theme = require("uitheme").current
avatar = require("avatar")
itemGrid = require("item_grid")

privateFields = setmetatable({}, { __mode = "k" })

mod.create = function(self, config)
	if self ~= mod then
		error("ui_avatar_editor:create(config) should be called with `:`", 2)
	end

	local defaultConfig = {
		ui = ui, -- can only be used by System to override UI instance
		margin = theme.padding,
	}

	local ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config)
	end)
	if not ok then
		error("ui_avatar_editor:create(config) - config error: " .. err, 2)
	end

	local ui = config.ui
	local node = ui:createFrame(Color(255, 0, 0, 0.3))

	privateFields[node] = {}

	node.onRemove = function(self)
		privateFields[self] = nil
	end

	local refButton = ui:createButton("dummy")
	refButton:setParent(nil)

	local categories = ui:createScroll({
		backgroundColor = Color(200, 200, 200),
		direction = "right",
		cellPadding = 6.0,
		loadCell = function(index)
			-- print("LOAD", index)
			if index == 1 then
				return ui:createButton("🙂 Head & Body")
			elseif index == 2 then
				return ui:createButton("👕 Clothing")
			elseif index == 3 then
				return ui:createButton("👕 Clothing 2")
			elseif index == 4 then
				return ui:createButton("👕 Clothing 3")
			elseif index == 5 then
				return ui:createButton("👕 Clothing 4")
			elseif index == 6 then
				return ui:createButton("👕 Clothing 5")
			elseif index == 7 then
				return ui:createButton("👕 Clothing 6")
			end
			return nil
		end,
		unloadCell = function(index, cell)
			-- print("UNLOAD", index)
			cell:remove()
		end,
	})

	local subCategories = ui:createScroll({
		backgroundColor = Color(200, 200, 200),
		direction = "right",
		cellPadding = 6.0,
		loadCell = function(index)
			if index == 1 then
				return ui:createButton("Skin")
			elseif index == 2 then
				return ui:createButton("Hair")
			elseif index == 3 then
				return ui:createButton("Eyes")
			elseif index == 4 then
				return ui:createButton("Ears")
			elseif index == 5 then
				return ui:createButton("Nose")
			end
			return nil
		end,
		unloadCell = function(_, cell)
			cell:remove()
		end,
	})
	subCategories:setParent(node)

	local grid = itemGrid:create({ categories = { "jacket" }, uikit = ui })
	grid:setParent(node)

	categories.parentDidResize = function(self)
		local parent = self.parent
		categories.Width = parent.Width
		categories.Height = refButton.Height
		categories.pos.Y = parent.Height - categories.Height

		subCategories.Width = categories.Width
		subCategories.Height = refButton.Height
		subCategories.pos = { categories.pos.X, categories.pos.Y - 10 - subCategories.Height }

		grid.Width = parent.Width
		grid.Height = parent.Height - categories.Height - subCategories.Height - 10 * 2
		grid.pos = { 0, 0 }
		grid:refresh()
		grid:getItems()
	end
	categories:setParent(node)

	return node
end

return mod
