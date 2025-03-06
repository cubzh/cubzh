animationsModule = {}

local privateFields = {}
privateFieldsMT = {
	__mode = "k", -- weak keys
	__metatable = false,
}
setmetatable(privateFields, privateFieldsMT)

local animationFields = {}  -- Map from animation objects to their names and parent animations container

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
	if onPlayCallbacks == nil then
		return
	end

	onPlayCallbacks[callback] = nil
end

local removeOnStopCallback = function(self, callback)
	if type(callback) ~= "function" then
		error("Animations:RemoveOnStopCallback(callback) - callback must be a function", 2)
	end

	local onStopCallbacks = privateFields[self].onStopCallbacks
	-- onStopCallbacks does not exist for those Animations, return
	if onStopCallbacks == nil then
		return
	end

	onStopCallbacks[callback] = nil
end

local animationsMT = {
	__metatable = false,
}

local indexFunctions = {
	AddOnStopCallback = addOnStopCallback,
	AddOnPlayCallback = addOnPlayCallback,
	RemoveOnPlayCallback = removeOnPlayCallback,
	RemoveOnStopCallback = removeOnStopCallback,
}

animationsMT.__index = function(t, k)
	if indexFunctions[k] then
		return indexFunctions[k]
	end
	return privateFields[t].anims[k]
end

local toggleGroups = function(animations)
	local playing = privateFields[animations].playing

	local groupsPlaying = {} -- { groupName: anim }
	local otherAnimPlayingGroup

	for _, anim in pairs(playing) do
		if anim then
			for _, groupName in ipairs(anim.Groups) do
				otherAnimPlayingGroup = groupsPlaying[groupName]
				if otherAnimPlayingGroup ~= nil then
					-- print("**", groupName, "other:", otherAnimPlayingGroup.Priority, animName .. ":", anim.Priority)
					if otherAnimPlayingGroup.Priority < anim.Priority then
						otherAnimPlayingGroup:Toggle(groupName, false)
						anim:Toggle(groupName, true)
						groupsPlaying[groupName] = anim
					else
						anim:Toggle(groupName, false)
					end
				else
					anim:Toggle(groupName, true)
					groupsPlaying[groupName] = anim
				end
			end
		end
	end
end

local startPlaying = function(animations, animName, anim)
	privateFields[animations].playing[animName] = anim
	toggleGroups(animations)
end

local stopPlaying = function(animations, animName)
	privateFields[animations].playing[animName] = nil
	toggleGroups(animations)
end

local onAnimPlayCallback = function(anim)
	local info = animationFields[anim]
	if info then
		startPlaying(info.animations, info.name, anim)
	end
end

local onAnimStopCallback = function(anim)
	if anim.RemoveWhenDone == true then
		local info = animationFields[anim]
		if info then
			stopPlaying(info.animations, info.name)
		end
	end
end

animationsMT.__newindex = function(t, k, v)
	if indexFunctions[k] ~= nil then
		error(string.format("Animations.%s is read-only", k))
	end

	if v ~= nil and typeof(v) ~= "Animation" then
		error(string.format("Animations.%s should be of type Animation", k), 2)
	end

	-- TODO: REMOVE CALLBACKS

	privateFields[t].anims[k] = v

	if v == nil then
		return
	end

	-- Store animation info for callbacks
	animationFields[v] = {
		animations = t,
		name = k
	}

	-- Use the shared callback functions
	v:AddOnPlayCallback(onAnimPlayCallback)
	v:AddOnStopCallback(onAnimStopCallback)
end

local create = function(_)
	local animations = {}
	privateFields[animations] = {
		anims = {},
		playing = {}
	}

	setmetatable(animations, animationsMT)

	return animations
end

local mt = {
	__call = create,
	__metatable = false,
}
setmetatable(animationsModule, mt)

-- tick for all Animations
LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
	for animations, animationsPrivateFields in pairs(privateFields) do
		local playing = animationsPrivateFields.playing
		if playing ~= nil then
			for name, anim in pairs(playing) do
				if anim.IsPlaying == false then
					stopPlaying(animations, name)
				else
					anim:Tick(dt)
				end
			end
		end
	end
end)

return animationsModule
