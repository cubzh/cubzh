local mod = {}

-- no margin when Screen.Width below NO_MARGIN_SCREEN_WIDTH
local NO_MARGIN_SCREEN_WIDTH = 400
local MAX_WIDTH = 600
local ANIMATION_TIME = 0.2

local BOTTOM_OFFSET = 20

local SHOW_BUMP_HEIGHT = 200
local BUMP_HEIGHT = 100

conf = require("config")
theme = require("uitheme").current
ease = require("ease")

privateFields = setmetatable({}, { __mode = "k" })

mod.create = function(self, config)
	if self ~= mod then
		error("drawer:create(config) should be called with `:`", 2)
	end
	local defaultConfig = {
		ui = require("uikit"),
		layoutContent = function(_) end,
	}

	config = conf:merge(defaultConfig, config)

	local ui = config.ui

	local container = ui:frameGenericContainer()
	local drawer = ui:frame()
	drawer:setParent(container)
	container.drawer = drawer

	drawer.updateConfig = _updateConfig
	drawer.clear = _clear

	privateFields[drawer] = {
		display = "default", -- "default", "expanded", "minimized"
		maxDefaultVerticalCover = 0.5,
		maxExpandedVerticalCover = 0.95,
		maxMinimizedVerticalCover = 0.1,
		config = config,
		container = container,
	}

	container.parentDidResize = function(self)
		local drawer = self.drawer
		local fields = privateFields[drawer]
		if fields == nil then
			return
		end

		if Screen.Width <= NO_MARGIN_SCREEN_WIDTH then
			drawer.Width = Screen.Width
		else
			drawer.Width = math.min(MAX_WIDTH, Screen.Width - theme.padding * 2)
		end

		drawer.Height = 100 -- depends on content

		fields.config.layoutContent(drawer)

		self.Width = drawer.Width
		self.Height = drawer.Height + BOTTOM_OFFSET
		drawer.pos.Y = BOTTOM_OFFSET

		self.pos = { Screen.Width * 0.5 - self.Width * 0.5, -BOTTOM_OFFSET }
	end
	container:parentDidResize()

	-- local show = drawer.show
	drawer.show = function(self)
		local fields = privateFields[self]
		if fields == nil then
			return
		end

		local container = fields.container
		ease:cancel(container)

		fields.config.layoutContent(self)

		container.Width = self.Width
		container.Height = self.Height + BOTTOM_OFFSET
		self.pos.Y = BOTTOM_OFFSET

		container:show()

		container.pos = { Screen.Width * 0.5 - container.Width * 0.5, -SHOW_BUMP_HEIGHT }
		ease:outBack(container, ANIMATION_TIME).pos =
			Number3(Screen.Width * 0.5 - container.Width * 0.5, -BOTTOM_OFFSET, 0)
	end

	drawer.hide = function(self)
		local fields = privateFields[self]
		if fields == nil then
			return
		end

		local container = fields.container
		ease:cancel(container)

		container:hide()
	end

	drawer.bump = function(self)
		local fields = privateFields[self]
		if fields == nil then
			return
		end

		local container = fields.container
		ease:cancel(container)

		container.pos = { Screen.Width * 0.5 - container.Width * 0.5, -BUMP_HEIGHT }
		ease:outBack(container, ANIMATION_TIME).pos =
			Number3(Screen.Width * 0.5 - container.Width * 0.5, -BOTTOM_OFFSET, 0)
	end

	return drawer
end

function _updateConfig(self, config)
	local fields = privateFields[self]
	if fields == nil then
		error("drawer:updateConfig(config) should be called with `:`, on a drawer instance", 2)
		return
	end

	local needsLayout = false
	if config.layoutContent ~= nil then
		needsLayout = true
	end

	config = conf:merge(fields.config, config)

	fields.config = config

	if needsLayout then
		fields.container:parentDidResize()
	end
end

function _clear(self)
	local fields = privateFields[self]
	if fields == nil then
		error("drawer:clear(config) should be called with `:`, on a drawer instance", 2)
		return
	end

	fields.config.layoutContent = function(_) end

	local toRemove = {}
	for _, child in pairs(self.children) do
		table.insert(toRemove, child)
	end

	local child = table.remove(toRemove)
	while child ~= nil do
		child:remove()
		child = table.remove(toRemove)
	end
end

return mod
