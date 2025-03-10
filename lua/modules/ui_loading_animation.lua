mod = {}

-- modules
ui = require("uikit")
conf = require("config")

loadingInstances = {} -- table ref: quad
nbLoadingInstances = 0
loadingTickListener = nil

animationQuadData = nil

function nodeRemove(self)
	if self.animation == nil then return end
	loadingInstances[self.animation] = nil
	nbLoadingInstances = nbLoadingInstances - 1
	if nbLoadingInstances == 0 and loadingTickListener ~= nil then
		loadingTickListener:Remove()
		loadingTickListener = nil
	end
end

mod.create = function(self, config)
	if self ~= mod then
		error("uiLoading:create(config): use `:`", 2)
	end

	local defaultConfig = {
		ui = ui,
	}

	local ok, err = pcall(function()
		config = conf:merge(defaultConfig, config)
	end)
	if not ok then
		error("uiLoading:create(config) - config error: " .. err, 2)
	end

	if animationQuadData == nil then
		animationQuadData = Data:FromBundle("images/loading.png")
	end

	local ui = config.ui

	local node = ui:frame()

	local nbFrames = 6
	local animation = ui:frame()
	local q = animation:getQuad()
	q.Image = {
		data = animationQuadData,
		alpha = true,
	}
	q.Color = Color.White
	q.Tiling = Number2(1, 1 / nbFrames)
	animation:setParent(node)

	loadingInstances[animation] = q
	nbLoadingInstances = nbLoadingInstances + 1

	if loadingTickListener == nil then
		local t = 0
		local frame = 0
		local fps = 20
		local frameDuration = 1.0 / fps
		local framePercentage = 1 / nbFrames
		local totalDuration = frameDuration * nbFrames
		local newFrame
		local offset

		loadingTickListener = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
			t = (t + dt) % totalDuration
			newFrame = math.floor(t / frameDuration)
			if newFrame ~= frame then
				frame = newFrame
				offset = framePercentage * frame
				for _, q in pairs(loadingInstances) do
					q.Offset:Set(0, offset)
				end
			end
		end)
	end

	animation.Width = 32
	animation.Height = 20

	node.Width = animation.Width
	node.Height = animation.Height
	node.animation = animation

	node.onRemoveSystem = nodeRemove

	return node
end

return mod
