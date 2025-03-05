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
			groups = anim.Groups
			for _, groupName in ipairs(groups) do
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

animationsMT.__newindex = function(t, k, v)
	if indexFunctions[k] ~= nil then
		error("Animations." .. k .. " is read-only")
	end

	if v ~= nil and typeof(v) ~= "Animation" then
		error("Animations." .. k .. " should be of type Animation", 2)
	end

	-- TODO: REMOVE CALLBACKS

	privateFields[t].anims[k] = v

	if v == nil then
		return
	end

	local animations = t
	local animName = k

	-- NOTE: could use same callback function for all
	-- animations, indexing animations on anim pointers
	v:AddOnPlayCallback(function(anim)
		startPlaying(animations, animName, anim)
	end)

	v:AddOnStopCallback(function(anim)
		if anim.RemoveWhenDone == true then
			stopPlaying(animations, animName)
		end
	end)
end

local create = function(_)
	local animations = {}
	privateFields[animations] = {}

	if privateFields[animations].anims == nil then
		privateFields[animations].anims = {}
	end

	-- all playing animations, { animName = anim }
	if privateFields[animations].playing == nil then
		privateFields[animations].playing = {}
	end

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
	for animations, animationsPrivateFields in pairs(privateFields) do
		anims = animationsPrivateFields.playing
		if anims ~= nil then
			for name, anim in pairs(anims) do
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
