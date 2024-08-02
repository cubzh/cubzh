local flow = {}

conf = require("config")

-- keeping weak references on created steps, and using this
-- to check if tables provided to flow:push are valid flow steps.
createdSteps = setmetatable({}, { __mode = "k" })

function emptyFunction() end

flow.create = function(self)
	if self ~= flow then
		error("flow:create() should be called with `:`", 2)
	end

	local f = {
		steps = {},
	}

	f.push = function(self, step)
		if self ~= f then
			error("flow:push(step) should be called with `:`", 2)
		end
		if createdSteps[step] ~= true then
			error("flow:push(step) expects a step created with flow:createStep(config)", 2)
		end

		if #self.steps > 0 then
			local currentStep = self.steps[#self.steps]
			currentStep:onExit()
		end

		table.insert(self.steps, step)
		step:onEnter()
	end

	f.pushAndRemove = function(self, step)
		if self ~= f then
			error("flow:push(step) should be called with `:`", 2)
		end
		if createdSteps[step] ~= true then
			error("flow:push(step) expects a step created with flow:createStep(config)", 2)
		end

		if #self.steps > 0 then
			local currentStep = self.steps[#self.steps]
			currentStep:onExit()
		end

		table.insert(self.steps, step)
		step:onEnter()
	end

	f.back = function(self)
		if self ~= f then
			error("flow:back() should be called with `:`", 2)
		end

		-- exit and remove current step
		local step = table.remove(self.steps)
		if step ~= nil then
			step:onExit()
			step:onRemove()
		end

		-- enter previous step
		if #self.steps > 0 then
			step = self.steps[#self.steps]
			step:onEnter()
		end
	end

	-- removes all steps
	f.flush = function(self)
		if self ~= f then
			error("flow:removes() should be called with `:`", 2)
		end

		-- exit and remove current step
		local step = table.remove(self.steps)
		if step ~= nil then
			step:onExit()
			step:onRemove()
			step = table.remove(self.steps)
		end

		-- remove following steps:
		while step ~= nil do
			step:onRemove()
			step = table.remove(self.steps)
		end
	end

	f.remove = function(self)
		if self ~= f then
			error("flow:remove() should be called with `:`", 2)
		end
		self:flush()
	end

	return f
end

flow.createStep = function(self, config)
	if self ~= flow then
		error("flow:createStep() should be called with `:`", 2)
	end

	local defaultConfig = {
		onEnter = emptyFunction,
		onExit = emptyFunction,
		onRemove = emptyFunction,
	}

	local ok, err = pcall(function()
		config = conf:merge(defaultConfig, config)
	end)
	if not ok then
		error("flow:createStep(config) - config error: " .. err, 2)
	end

	local step = {
		onEnter = config.onEnter,
		onExit = config.onExit,
		onRemove = config.onRemove,
	}

	createdSteps[step] = true

	return step
end

return flow
