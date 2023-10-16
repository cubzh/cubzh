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
	if indexFunctions[k] then
		return indexFunctions[k]
	end
	return privateFields[t].anims[k]
end

local toggleGroups = function(animations)
	local anims = privateFields[animations].anims

	local playingInLoop = privateFields[animations].playingInLoop
	local playingOnce = privateFields[animations].playingOnce

	local anim
	local groups
	-- activate all groups

	for _, name in ipairs(playingOnce) do
		anim = anims[name]
		if anim then
			groups = anim.Groups
			for _, groupName in ipairs(groups) do
				anim:Toggle(groupName, true)
			end
		end
	end

	for _, name in ipairs(playingInLoop) do
		anim = anims[name]
		if anim then
			groups = anim.Groups
			for _, groupName in ipairs(groups) do
				anim:Toggle(groupName, true)
			end
		end
	end

	local groupsPlaying = {}

	for _, name in ipairs(playingOnce) do
		anim = anims[name]
		if anim then
			groups = anim.Groups
			for _, groupName in ipairs(groups) do
				if groupsPlaying[groupName] == true then
					anim:Toggle(groupName, false)
				else
					groupsPlaying[groupName] = true
				end
			end
		end
	end

	for _, name in ipairs(playingInLoop) do
		anim = anims[name]
		if anim then
			groups = anim.Groups
			for _, groupName in ipairs(groups) do
				if groupsPlaying[groupName] == true then
					anim:Toggle(groupName, false)
				else
					groupsPlaying[groupName] = true
				end
			end
		end
	end
end

local startPlaying = function(animations, animName, anim)
	privateFields[animations].playing[animName] = true

	local playingInLoop = privateFields[animations].playingInLoop
	local playingOnce = privateFields[animations].playingOnce

	for i, name in ipairs(playingInLoop) do
		if name == animName then
			table.remove(playingInLoop, i)
			break
		end
	end

	for i, name in ipairs(playingOnce) do
		if name == animName then
			table.remove(playingOnce, i)
			break
		end
	end

	if anim.Mode == AnimationMode.Loop then
		table.insert(playingInLoop, 1, animName)
	else
		table.insert(playingOnce, 1, animName)
	end

	toggleGroups(animations)
end

local stopPlaying = function(animations, animName)
	if privateFields[animations].playing[animName] ~= true then
		return
	end
	privateFields[animations].playing[animName] = false

	local playingInLoop = privateFields[animations].playingInLoop
	local playingOnce = privateFields[animations].playingOnce

	for i, name in ipairs(playingInLoop) do
		if name == animName then
			table.remove(playingInLoop, i)
			break
		end
	end

	for i, name in ipairs(playingOnce) do
		if name == animName then
			table.remove(playingOnce, i)
			break
		end
	end
	toggleGroups(animations)
end

animationsMT.__newindex = function(t, k, v)
	if indexFunctions[k] ~= nil then
		error("Animations." .. k .. " is read-only")
	end

	if v ~= nil and type(v) ~= "Animation" then
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

	v:AddOnStopCallback(function(_)
		stopPlaying(animations, animName)
	end)
end

local create = function(_)
	local animations = {}
	privateFields[animations] = {}

	if privateFields[animations].anims == nil then
		privateFields[animations].anims = {}
	end

	-- all playing animations, { animName = true }
	if privateFields[animations].playing == nil then
		privateFields[animations].playing = {}
	end

	if privateFields[animations].playingInLoop == nil then
		privateFields[animations].playingInLoop = {}
	end

	if privateFields[animations].playingOnce == nil then
		privateFields[animations].playingOnce = {}
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
		anims = animationsPrivateFields.anims
		if anims ~= nil then
			for name, anim in pairs(anims) do
				if anim.IsPlaying == false then
					if animationsPrivateFields.playing[name] == true then
						stopPlaying(animations, name)
					end
				else
					anim:Tick(dt)
				end
			end
		end
	end
end)

return animationsModule
