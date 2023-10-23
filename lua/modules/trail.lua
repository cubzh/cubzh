local MAX_TRAIL_SEGMENTS = 100

local addSegment = function(segments, color, thickness, segmentLength)
    local segment = MutableShape()
    segment:AddBlock(color, 0, 0, 0)
    segment:SetParent(World)
    segment.IsUnlit = true
    segment.CastShadows = false
    segment.Physics = PhysicsMode.Disabled
    segment.Pivot = { 0.5, 0.5, 0 }
    segment.Scale = { thickness, thickness, segmentLength }
    segment.IsHidden = true
    table.insert(segments, segment)
    return segment
end

local create = function(_, source, target, color, thickness, segmentLength)
    local t = {}
    source = source
    target = target
    color = color or Color.White
    thickness = thickness or 0.5
    segmentLength = segmentLength or 5

    local nbSegments = 10

    local segments = {}
    for _=1,nbSegments do
        addSegment(segments, color, thickness, segmentLength)
    end

    local spaceBetweenTwoSegmentOrigins = (segmentLength + segmentLength * 0.5)
    local tickListener = LocalEvent:Listen(LocalEvent.Name.Tick, function(_)
        local sourcePos = source.Position + Number3(0,6,0)
        local targetPos = target.Position + Number3(0,6,0)
        local vector = targetPos - sourcePos
        local length = vector.Length - spaceBetweenTwoSegmentOrigins
        vector:Normalize()
        local segmentIndex = 1
        local dist = 0
        while dist < length do
            local segment = segments[segmentIndex]
            if not segment then
                if segmentIndex >= MAX_TRAIL_SEGMENTS then return end
                addSegment(segments, color, thickness, segmentLength)
            end
            if not segment then return end
            segment.IsHidden = false
            segment.Position = sourcePos + vector * (segmentIndex - 1) * spaceBetweenTwoSegmentOrigins
            segment.Forward = vector
            dist = dist + spaceBetweenTwoSegmentOrigins
            segmentIndex = segmentIndex + 1
        end
        for i=segmentIndex, #segments do
            segments[i].IsHidden = true
        end
    end)

    t.remove = function(_)
        tickListener:Remove()
        for _,segment in ipairs(segments) do
            segment:RemoveFromParent()
        end
        segments = {}
    end
    return t
end

return {
    create = create
}