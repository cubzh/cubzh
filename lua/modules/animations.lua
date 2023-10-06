local create = function(_)
    local attributes = {
        stanceDirty = false,
        onPlayCallbacks = {},
        onStopCallbacks = {}
    }

    attributes.AddOnPlayCallback = function(self, callback)
        if type(callback) ~= "function" then
            error("Animations:AddOnPlayCallback - first argument must be a function", 2)
            return
        end
        table.insert(attributes.onPlayCallbacks, callback)
    end

    attributes.RemoveOnPlayCallback = function(self, callback)
        for k,f in ipairs(attributes.onPlayCallbacks) do
            if f == callback then table.remove(attributes.onPlayCallbacks, k) end
        end
    end

    attributes.AddOnStopCallback = function(self, callback)
        if type(callback) ~= "function" then
            error("Animations:AddOnStopCallback - first argument must be a function", 2)
            return
        end
        table.insert(attributes.onStopCallbacks, callback)
    end

    attributes.RemoveOnStopCallback = function(self, callback)
        for k,f in ipairs(attributes.onStopCallbacks) do
            if f == callback then table.remove(attributes.onStopCallbacks, k) end
        end
    end

    local animations = {}

    local animationsTable = {}

    local animationsIndex = function(t, k)
        local anim = animationsTable[k]
        if anim then return anim end
        return attributes[k]
    end

    local animationsNewIndex = function(t, k, v)
        if attributes[k] ~= nil then
        	local expectedType = type(attributes[k])
        	if type(v) ~= expectedType then
	    		error("Animations." .. k .. " should be of type " .. expectedType, 2)
	    	end

            if k == "stanceDirty" then
                attributes[k] = v
            else
                error("Animations." .. k .. " is read-only")
            end
            return
        end

        if type(v) ~= "Animation" then
        	error("Animations." .. k .. " should be of type Animation", 2)
        end

        animationsTable[k] = v
        if v == nil then return end
        v:AddOnPlayCallback(function()
            for _,callback in ipairs(attributes.onPlayCallbacks) do
                callback(t, k, v)
            end
        end)
        v:AddOnStopCallback(function()
            for _,callback in ipairs(attributes.onStopCallbacks) do
                callback(t, k, v)
            end
        end)
    end

    local animationsMetatable = {
        __index = animationsIndex,
        __newindex = animationsNewIndex,
        __metatable = false
    }
    setmetatable(animations, animationsMetatable)

    LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
        for _,anim in pairs(animationsTable) do
            anim:Tick(dt)
        end
    end)

    return animations
end

return {
    create = create   
}