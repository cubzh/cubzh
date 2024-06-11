local mod = {}

-- no margin when Screen.Width below NO_MARGIN_SCREEN_WIDTH
local NO_MARGIN_SCREEN_WIDTH = 400
local MAX_WIDTH = 600
local ANIMATION_TIME = 0.2

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

	local drawer = ui:createFrame(Color.White)
	drawer.updateConfig = _updateConfig
	drawer.clear = _clear

	privateFields[drawer] = {
		display = "default", -- "default", "expanded", "minimized"
		maxDefaultVerticalCover = 0.5,
		maxExpandedVerticalCover = 0.95,
		maxMinimizedVerticalCover = 0.1,
		config = config,
	}

	drawer.parentDidResize = function(self)
		local fields = privateFields[self]
		if fields == nil then
			return
		end

		if Screen.Width <= NO_MARGIN_SCREEN_WIDTH then
			self.Width = Screen.Width
		else
			self.Width = math.min(MAX_WIDTH, Screen.Width - theme.padding * 2)
		end
		self.Height = 300 -- TODO (depends on content)

		fields.config.layoutContent(self)

		self.pos = { Screen.Width * 0.5 - self.Width * 0.5, 0 }
	end
	drawer:parentDidResize()

	local show = drawer.show
	drawer.show = function(self)
		local fields = privateFields[self]
		if fields == nil then
			return
		end

		ease:cancel(self)
		fields.config.layoutContent(self)

		show(self)
		self.pos = { Screen.Width * 0.5 - self.Width * 0.5, -SHOW_BUMP_HEIGHT }
		ease:outBack(self, ANIMATION_TIME).pos = Number3(Screen.Width * 0.5 - self.Width * 0.5, 0, 0)
	end

	drawer.bump = function(self)
		local fields = privateFields[self]
		if fields == nil then
			return
		end
		ease:cancel(self)
		self.pos = { Screen.Width * 0.5 - self.Width * 0.5, -BUMP_HEIGHT }
		ease:outBack(self, ANIMATION_TIME).pos = Number3(Screen.Width * 0.5 - self.Width * 0.5, 0, 0)
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
		self:parentDidResize()
	end
end

function _clear(self)
	local fields = privateFields[self]
	if fields == nil then
		error("drawer:clear(config) should be called with `:`, on a drawer instance", 2)
		return
	end

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
