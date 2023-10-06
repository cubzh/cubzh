
animationsModule = {}

local privateFields = {}
privateFieldsMT = {
	__mode = "k", -- weak keys
	__metatable = false,
}
setmetatable(privateFields, privateFieldsMT)

local addOnPlayCallback = function(self, callback)
	if type(callback) ~= "function" then
		error("Animations:AddOnPlayCallback - first argument must be a function", 2)
	end

	if privateFields[self].onPlayCallbacks == nil then
		privateFields[self].onPlayCallbacks = {}
	end

	privateFields[self].onPlayCallbacks[callback] = callback
end

local addOnStopCallback = function(self, callback)
	if type(callback) ~= "function" then
		error("Animations:AddOnStopCallback - first argument must be a function", 2)
	end

	if privateFields[self].onStopCallbacks == nil then
		privateFields[self].onStopCallbacks = {}
	end

	privateFields[self].onStopCallbacks[callback] = callback
end

local removeOnPlayCallback = function(self, callback)
	if type(callback) ~= "function" then
		error("Animations:RemoveOnPlayCallback(callback) - callback must be a function", 2)
	end

	local onPlayCallbacks = privateFields[self].onPlayCallbacks
	
	-- onPlayCallbacks does not exist for those Animations, return
	if onPlayCallbacks == nil then return end

	onPlayCallbacks[callback] = nil
end

local removeOnStopCallback = function(self, callback)
	if type(callback) ~= "function" then
		error("Animations:RemoveOnStopCallback(callback) - callback must be a function", 2)
	end

	local onStopCallbacks = privateFields[self].onStopCallbacks
	
	-- onStopCallbacks does not exist for those Animations, return
	if onStopCallbacks == nil then return end

	onStopCallbacks[callback] = nil
end

local animationsMT = {
	__gc = function(t)
		privateFields[t] = nil -- (may not be required as privateFields uses weak keys)
	end,
	__metatable = false,
}

local indexFunctions = {
	AddOnStopCallback = addOnStopCallback,
	AddOnPlayCallback = addOnPlayCallback,
	RemoveOnPlayCallback = removeOnPlayCallback,
	RemoveOnStopCallback = removeOnStopCallback,
}

animationsMT.__index = function(t, k)
	if indexFunctions[k] then return indexFunctions[k] end
	return privateFields[t].anims[k]	
end

animationsMT.__newindex = function(t, k, v)
	if indexFunctions[k] ~= nil then
		error("Animations." .. k .. " is read-only")
	end

	if v ~= nil and type(v) ~= "Animation" then
		error("Animations." .. k .. " should be of type Animation", 2)
	end

	if privateFields[t].anims == nil then privateFields[t].anims = {} end

	-- TODO: REMOVE CALLBACKS

	privateFields[t].anims[k] = v

	if v == nil then return end

	v:AddOnPlayCallback(function(anim)
		print("PLAY ANIM:", anim)
		local g = anim.Groups
	end)

	v:AddOnStopCallback(function(anim)
		print("STOP ANIM:", anim)
	end)
end

local create = function(self)

	local animations = {}
	privateFields[animations] = {}

	setmetatable(animations, animationsMT)

	return animations
end

local mt = {
	__call = create,
	__metatable = false,
}
setmetatable(animationsModule, mt)

-- tick for all Animations
local anims
LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
	for _, animations in pairs(privateFields) do
		anims = animations.anims
		if anims ~= nil then
			for _, anim in pairs(anims) do
				anim:Tick(dt)
			end
		end
	end
end)

return animationsModule
