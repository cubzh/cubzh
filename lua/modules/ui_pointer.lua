local pointer = {}

conf = require("config")
bundle = require("bundle")
ease = require("ease")

DEFAULT_CONFIG = {
	uikit = require("uikit"),
}

DEFAULT_POINT_AT_CONFIG = {
	target = nil,
	from = "below", -- "below", "above", "left", "right"
}

pointer.create = function(_, config)
	config = conf:merge(DEFAULT_CONFIG, config)
	local ui = config.uikit

	local shape = bundle.Shape("aduermael.ui_pointer_arrow")
	local p = ui:createShape(shape)
	local ratio = p.Width / p.Height
	p.Width = 40
	p.Height = p.Width / ratio

	p.config = nil

	p.parentDidResize = function(self)
		local config = self.config
		if config == nil then
			return
		end

		local ok = pcall(function()
			local targetPos = config.target.pos

			if config.target.Width ~= nil and config.target.Height ~= nil then
				if config.from == "below" then
					targetPos = targetPos + { config.target.Width * 0.5, 0, 0 } - { self.Width * 0.5, self.Height, 0 }
				elseif config.from == "above" then
					targetPos = targetPos
						+ { config.target.Width * 0.5, config.target.Height, 0 }
						- { self.Width * 0.5, 0, 0 }
				elseif config.from == "left" then
					targetPos = targetPos + { 0, config.target.Height * 0.5, 0 } - { self.Width, self.Height * 0.5, 0 }
				elseif config.from == "right" then
					targetPos = targetPos
						+ { config.target.Width, config.target.Height * 0.5, 0 }
						- { 0, self.Height * 0.5, 0 }
				end
			end

			local parent = config.target.parent

			while parent ~= nil do
				targetPos = targetPos + parent.pos
				parent = parent.parent
			end

			self.pos = targetPos
		end)

		if not ok then
			ok = pcall(function()
				self.pos = config.target.Position
			end)
		end

		if not ok then
			ok = pcall(function()
				self.pos = config.target
			end)
		end

		if not ok then
			error("pointAt: couldn't point at " .. config.target, 2)
		end

		self.LocalPosition.Z = ui.kForegroundDepth

		self.initPos = p.pos:Copy()

		ease:cancel(self)

		local animOffset = { 0, -10, 0 }

		if config.from == "below" then
			animOffset = { 0, -10, 0 }
			self.pivot.LocalRotation = Rotation(0, 0, 0)
		elseif config.from == "above" then
			animOffset = { 0, 10, 0 }
			self.pivot.LocalRotation = Rotation(0, 0, math.pi)
		elseif config.from == "left" then
			animOffset = { -10, 0, 0 }
			self.pivot.LocalRotation = Rotation(0, 0, math.pi * 1.5)
		elseif config.from == "right" then
			animOffset = { 10, 0, 0 }
			self.pivot.LocalRotation = Rotation(0, 0, math.pi * 0.5)
		end

		local anim = {}
		anim.part1 = function()
			ease:inOutSine(self, 0.3, {
				onDone = anim.part2,
			}).pos = self.initPos + animOffset
		end
		anim.part2 = function()
			ease:inOutSine(self, 0.3, {
				onDone = anim.part1,
			}).pos = self.initPos
		end
		anim.part1()
	end

	p.pointAt = function(self, config)
		config = conf:merge(DEFAULT_POINT_AT_CONFIG, config, {
			acceptTypes = {
				target = { "Object", "Shape", "MutableShape", "Number3", "Number2", "table" },
			},
		})

		self.config = config
		p:parentDidResize()
	end

	local remove = p.remove
	p.remove = function(self)
		ease:cancel(self)
		remove(self)
	end

	return p
end

return pointer
