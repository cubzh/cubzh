Config = {
    Items = {"%item_name%", "cube_white", "cube_selector" },
    ChatAvailable = false,
}

Client.OnStart = function()
	
	controls = require("controls")

	box_outline = require("box_outline")
	ui = require("uikit")

	max_total_nb_shapes = 32

	colliderMinGizmo = require("gizmo"):create()
	colliderMinGizmo:setLayer(4)
	colliderMinGizmo:setGizmoScale(0.3)
	colliderMinGizmo:setOrientation(colliderMinGizmo.Orientation.World)
	colliderMinGizmo:setMode(colliderMinGizmo.Mode.Move)
	colliderMinGizmo:setSnap(colliderMinGizmo.Mode.Move, 0.5)
	colliderMinGizmo._gizmos[colliderMinGizmo.Mode.Move].onDrag = function()
		local axis = { "X", "Y", "Z" }
		for _,a in ipairs(axis) do
			if colliderMinObject.Position[a] >= colliderMaxObject.Position[a] then
				colliderMinObject.Position[a] = colliderMaxObject.Position[a] - 0.5
			end
		end
		colliderMinGizmo:setObject(colliderMinObject)
		updateCollider()
	end

	colliderMaxGizmo = require("gizmo"):create()
	colliderMaxGizmo:setLayer(4)
	colliderMaxGizmo:setGizmoScale(0.3)
	colliderMaxGizmo:setOrientation(colliderMaxGizmo.Orientation.World)
	colliderMaxGizmo:setMode(colliderMaxGizmo.Mode.Move)
	colliderMaxGizmo:setSnap(colliderMaxGizmo.Mode.Move, 0.5)
	colliderMaxGizmo._gizmos[colliderMaxGizmo.Mode.Move].onDrag = function()
		local axis = { "X", "Y", "Z" }
		for _,a in ipairs(axis) do
			if colliderMaxObject.Position[a] <= colliderMinObject.Position[a] then
				colliderMaxObject.Position[a] = colliderMinObject.Position[a] + 0.5
			end
		end
		colliderMaxGizmo:setObject(colliderMaxObject)
		updateCollider()
	end

	colorPickerModule = require("colorpicker")

	-- Descendants
	hierarchyActions = require("hierarchyactions")
	getSelfAndDescendantsBlocksCount = function(shape)
		local count = 0
		hierarchyActions:applyToDescendants(shape, { includeRoot = true }, function(s)
			count = count + s.BlocksCount
		end)
		return count
	end

	hideAllTools = function()
		palette:hide()
		colorPicker:hide()
		selectControls:hide()
		mirrorControls:hide()
	end

	-- Displays the right tools based on state
	refreshToolsDisplay = function()

		local enablePaletteBtn = currentMode == mode.edit and (
			currentEditSubmode == editSubmode.add
			or currentEditSubmode == editSubmode.remove
			or currentEditSubmode == editSubmode.paint
			)

		local showPalette = currentMode == mode.edit and paletteDisplayed and (
								currentEditSubmode == editSubmode.add 
								or currentEditSubmode == editSubmode.remove
								or currentEditSubmode == editSubmode.paint
							)

		local showColorPicker = showPalette and colorPickerDisplayed
		local showMirrorControls = currentMode == mode.edit and currentEditSubmode == editSubmode.mirror

		local showSelectControls = currentMode == mode.edit and currentEditSubmode == editSubmode.select

		if enablePaletteBtn then paletteBtn:enable() else paletteBtn:disable() end

		if showPalette then updatePalettePosition() palette:show() else palette:hide() end
		if showColorPicker then colorPicker:show() else colorPicker:hide() end
		if showSelectControls then selectControlsRefresh() selectControls:show() else selectControls:hide() end

		if showMirrorControls then
			mirrorControls:show()
			if not mirrorShape then
				mirrorGizmo:setObject(nil)
				placeMirrorText:show()
				rotateMirrorBtn:hide()
				removeMirrorBtn:hide()
				mirrorControls.Width = placeMirrorText.Width + ui_config.padding * 2
			else
				mirrorGizmo:setObject(mirrorAnchor)
				placeMirrorText:hide()
				rotateMirrorBtn:show()
				removeMirrorBtn:show()
				mirrorControls.Width = ui_config.padding + (rotateMirrorBtn.Width + ui_config.padding) * 2
			end
			mirrorControls.LocalPosition = {Screen.Width - mirrorControls.Width - ui_config.padding, editMenu.Height + 2 * ui_config.padding, 0}
		else
			mirrorControls:hide()
		end
	end

	refreshDrawMode = function(forcedDrawMode)
		hierarchyActions:applyToDescendants(item, { includeRoot = true }, function(s)
			if forcedDrawMode ~= nil then
				s.PrivateDrawMode = forcedDrawMode
			else
				if currentMode == mode.points then
					s.PrivateDrawMode = 0
				elseif currentMode == mode.edit then
					s.PrivateDrawMode = (s == focusShape and 2 or 0) + (gridEnabled and 8 or 0) + (dragging2 and 1 or 0)
				end
			end
		end)
	end

	setSelfAndDescendantsHiddenSelf = function(shape, isHiddenSelf)
		hierarchyActions:applyToDescendants(shape,  { includeRoot = true }, function(s)
			s.IsHiddenSelf = isHiddenSelf
		end)
	end
	
	undoShapesStack = {}
	redoShapesStack = {}
	
	----------------------------
	-- SETTINGS
	----------------------------

	Dev.DisplayBoxes = false

	cameraSpeed = 1.4 -- unit/sec per screen point
	cameraVelocityDrag = 0.6 -- ratio of carry-over camera velocity per frame
	cameraDPadSpeed = 6 -- unit/sec
	cameraDistFactor = 0.05 -- additive factor per distance unit above threshold
	cameraDistThreshold = 15 -- distance under which scaling is 1
	zoomSpeed = 7 -- unit/sec
	zoomSpeedMax = 200
	dPadMoveSpeed = 5.0 -- unit/sec
	zoomVelocityDrag = 0.92 -- ratio of carry-over zoom velocity per frame
	zoomMin = 5 -- unit, minimum zoom distance allowed
	angularSpeed = 0.4 -- rad/sec per screen point
	angularVelocityDrag = 0.91 -- ratio of carry-over angular velocity per frame
	dPadAngularFactor = 0.7 -- in free mode (triggered after using dPad), this multiplies angular velocity
	autosnapDuration = 0.3 -- seconds

	cameraStartRotation = Number3(0.32, -0.81, 0.0)
	cameraStartPreviewRotation = Number3(0, math.pi * -0.75, 0)
	cameraStartPreviewDistance = 15
	cameraThumbnailRotation = Number3(0.32, 3.9, 0.0) --- other option for Y: 2.33

	saveTrigger = 60 -- seconds

    mirrorMargin = 1.0 -- the mirror is x block larger than the item
    mirrorThickness = 1.0/4.0

    darkTextColor = Color(100, 100, 100)
    darkTextColorDisabled = Color(100, 100, 100, 20)
    lightTextColor = Color(255, 255, 255)
    selectedButtonColor = Color(100, 100, 100)
    modeButtonColor = Color(50, 149, 201)
    modeButtonColorSelected = Color(94, 192, 242)

    ----------------------------
    -- AMBIANCE
    ----------------------------

    local gradientStart = 120
    local gradientStep = 40

    Sky.AbyssColor = Color(gradientStart, gradientStart, gradientStart)
    Sky.HorizonColor = Color(gradientStart + gradientStep,
    						gradientStart + gradientStep,
    						gradientStart + gradientStep)
    Sky.SkyColor = Color(gradientStart + gradientStep * 2,
    						gradientStart + gradientStep * 2,
    						gradientStart + gradientStep * 2)
    Clouds.On = false
    Fog.On = false

	----------------------------
	-- CURSOR / CROSSHAIR
	----------------------------

    Pointer:Show()
	UI.Crosshair = false

	----------------------------
	-- STATE VALUES
	----------------------------

	-- item editor modes

	mode = { edit = 1, points = 2, max = 2 }
    modeName = { "EDIT", "POINTS" }

    editSubmode = { add = 1, remove = 2, paint = 3, pick = 4, mirror = 5, select = 6, max = 6}
    editSubmodeName = { "add", "remove", "paint", "pick", "mirror", "import", "select" }

    pointsSubmode = { move = 1, rotate = 2, max = 2}
    pointsSubmodeName = { "Move", "Rotate"}

    focusMode = { othersVisible = 1, othersTransparent = 2, othersHidden = 3, max = 3 }
    focusModeName = { "Others Visible", "Others Transparent", "Others Hidden" }

	wearablePreviewMode = { hide = 1, bodyPart = 2, fullBody = 3 }
	currentWearablePreviewMode = wearablePreviewMode.hide

    currentMode = nil
    currentEditSubmode = nil
    currentPointsSubmode = pointsSubmode.move -- points sub mode
    
    -- used to go back to previous submode and btn after pick
    prePickEditSubmode = nil
    prePickSelectedBtn = nil

    paletteDisplayed = true
    colorPickerDisplayed = false

    -- camera

	cameraRotation = cameraStartRotation
	zoomVelocity = 0.0
	angularVelocity = Number3(0, 0, 0)
	cameraVelocity = Number3(0, 0, 0)
	blockHighlightDirty = false
	autosnapFromTarget = Number3(0, 0, 0)
	autosnapFromDistance = 0
	autosnapToTarget = Number3(0, 0, 0)
	autosnapToDistance = 0
	autosnapTimer = -1.0
	cameraFree = false -- used with dPad to rotate camera freely

	cameraStates = {
		item = {
		    -- initialized at the end of OnStart
		    target = nil,
		    distance = 0,
		    rotation = nil
		},
		preview = {
			distance = cameraStartPreviewDistance,
			rotation = cameraStartPreviewRotation
		}
	}
	cameraCurrentState = cameraStates.item
	
	-- input

	dragging = false -- drag motion active
    dragging2 = false -- drag2 motion active
    editBlockedUntilUp = false

    dPad = { x = 0.0, y = 0.0 }

    -- mirror mode

    mirrorShape = nil
    mirrorAnchor = nil
    mirrorAxes = { x = 1, y = 2, z = 3}
    currentMirrorAxis = nil

    -- other variables

    item = nil
    itemPalette = nil -- set if a palette is found when loading assets
	
	gridEnabled = false
	displayedModeUIElements = {} -- displayed UI elements specific to current mode
	currentFacemode = false
	changesSinceLastSave = false
	autoSaveDT = 0.0
	halfVoxel = Number3(0.5, 0.5, 0.5)
	picker = nil
    poiNameHand = "ModelPoint_Hand_v2"
    poiNameHat = "ModelPoint_Hat"
    poiNameBackpack = "ModelPoint_Backpack"
	
	poiAvatarRightHandPalmDefaultValue = Number3(3.5, 1.5, 2.5)
	
    poiActiveName = poiNameHand

	itemCategory = Environment.itemCategory
	if itemCategory == "" then itemCategory = "generic" end
	isWearable = itemCategory ~= "generic"
	enableWearablePattern = true -- blue/red blocks to guide creation

	----------------------------
	-- OBJECTS & UI ELEMENTS
	----------------------------

	itemLoaded = false

	local loadConfig = { useLocal = true, mutable = true}
	Assets:Load(Environment.itemFullname, AssetType.Any, function(assets)

		local shapesNotParented = {}

        for _,v in ipairs(assets) do
        	if type(v) == "Palette" then
        		itemPalette = v
        	else
        		if v:GetParent() == nil then
                	table.insert(shapesNotParented, v)
            	end
        	end
        end
        
        local finalObject
        if #shapesNotParented == 1 then
            finalObject = shapesNotParented[1]
        elseif #shapesNotParented > 1 then
            local root = Object()
            for _,v in ipairs(shapesNotParented) do
                root:AddChild(v)
            end
            finalObject = root
        end
        
        item = finalObject
        
        item:SetParent(World)
        item.History = true -- enable history for the edited item
		item.Physics = PhysicsMode.Trigger

		if isWearable then
			bodyParts = { "Head", "Body", "RightArm", "LeftArm", "RightHand", "LeftHand", "RightLeg", "LeftLeg", "RightFoot", "LeftFoot" }
			__equipments = require("equipments.lua")

			if itemCategory == "pants" then
				item.Scale = 1.05
			end
		
			hierarchyActions:applyToDescendants(item, { includeRoot = true }, function(s)
				s.Physics = PhysicsMode.Trigger
				s.Pivot = s:GetPoint("origin").Coords
			end)
			if enableWearablePattern then
				Object:Load("caillef.pattern" .. itemCategory, function(obj)
					if not obj then
						print("Error: can't load pattern")
						enableWearablePattern = false
					end
					obj.Physics = PhysicsMode.Disabled
					pattern = obj
				end)
			end
		end

		-- set customCollisionBox if not equals to BoundingBox
		if item.BoundingBox.Min ~= item.CollisionBox.Min and item.BoundingBox.Max ~= item.CollisionBox.Max then
			customCollisionBox = Box(item.CollisionBox.Min, item.CollisionBox.Max)
		end

		-- INIT UI
    	ui_init()

    	post_item_load()

    	Client.WillOpenGameMenu = willOpenGameMenu
    	Client.Tick = tick
    	Pointer.Zoom = zoom
    	Pointer.Down = down
    	Pointer.Up = up
    	Pointer.LongPress = longPress
    	Pointer.DragBegin = dragBegin
    	Pointer.Drag = drag
    	Pointer.DragEnd = dragEnd
    	Pointer.Drag2Begin = drag2Begin
    	Pointer.Drag2 = drag2
    	Pointer.Drag2End = drag2End
    	Screen.DidResize = didResize
    	Screen.DidResize(Screen.Width, Screen.Height)

	end, loadConfig)

	updateWearableSubShapesPosition = function(forceNoShift)
		local parents = __equipments.equipmentParent(Player, itemCategory)
		if type(parents) ~= "table" then return end
		local child = item:GetChild(1)
		local coords = parents[2]:GetPoint("origin").Coords
		if coords == nil then
			print("can't get parent coords for equipment")
			return
		end
		local pos = parents[2]:BlockToWorld(coords)
		local shift = Number3(0,0,0)
		if not forceNoShift and currentWearablePreviewMode == wearablePreviewMode.hide then
			shift = #parents == 2 and Number3(-5,0,0) or Number3(5,0,0)
		end
		child.Position = pos + shift
		child.Rotation = parents[2].Rotation
		if not parents[3] then return end
		local child = child:GetChild(1)
		local coords = parents[3]:GetPoint("origin").Coords
		if coords == nil then
			print("can't get parent coords for equipment")
			return
		end
		local pos = parents[3]:BlockToWorld(coords)
		local shift = Number3(0,0,0)
		if not forceNoShift and currentWearablePreviewMode == wearablePreviewMode.hide then
			shift = Number3(-5,0,0)
		end
		child.Position = pos + shift
		child.Rotation = parents[3].Rotation
	end

	-- long press + drag
	continuousEdition = false
	blocksAddedWithDrag = {}

	-- a cube to show where the camera is looking at
	blockHighlight = MutableShape(Items.cube_selector)
	blockHighlight.PrivateDrawMode = 2 + (gridEnabled and 8 or 0) -- highlight
	blockHighlight.Scale = 1 / (blockHighlight.Width - 1)
	blockHighlight:SetParent(World)
	blockHighlight.IsHidden = true

	-- item info: blocks counter
	blocksCounterNeedsRefresh = true

end -- OnStart end

Client.Action1 = nil
Client.Action2 = nil
Client.Action1Release = nil
Client.Action2Release = nil
Client.Action3Release = nil

Client.WillOpenGameMenu = function() end
willOpenGameMenu = function()
	if changesSinceLastSave then
		save()
	end
end

Client.Tick = function() end
tick = function(dt)

	if changesSinceLastSave then
		autoSaveDT = autoSaveDT + dt
		if autoSaveDT > saveTrigger then
			save()
		else
			local remaining = math.floor(saveTrigger - autoSaveDT)
			saveBtn.label.Text = (remaining < 10 and " " or "") .. remaining
		end
	end

	-- if camera target moved last frame, refresh block highlight
	if blockHighlightDirty then
        refreshBlockHighlight()
    end

    if cameraFree then
        -- consume camera angular velocity
        cameraRotation = cameraRotation + angularVelocity * dt * dPadAngularFactor
        angularVelocity = dragging and Number3(0, 0, 0) or (angularVelocity * angularVelocityDrag)
        Camera.Rotation = cameraRotation

        -- up/down directional pad can be used as an alternative to mousewheel
		if dPad.y ~= 0 then
			Camera.Position = Camera.Position + Camera.Forward * dPad.y * dPadMoveSpeed * dt 
		end
		-- right/left directional pad maps to lateral camera pan
		if dPad.x ~= 0 then
		    Camera.Position = Camera.Position + Camera.Right * dPad.x * dPadMoveSpeed * dt 
		end

        if zoomSum then
			Camera.Position = Camera.Position + Camera.Backward * zoomSum
			zoomSum = nil
		end
	else

        -- consume camera angular velocity
        local rotation = cameraRotation + angularVelocity * dt
        angularVelocity = dragging and Number3(0, 0, 0) or (angularVelocity * angularVelocityDrag)

        local target = nil
        local distance = nil
        if autosnapTimer < 0 then
            -- consume camera target velocity and refresh block highlight
            target = Camera.target + cameraVelocity * dt
            cameraVelocity = dragging2 and Number3(0, 0, 0) or (cameraVelocity * cameraVelocityDrag)
            blockHighlightDirty = n3Equals(target, Camera.target, 0.001) == false

            -- consume camera zoom velocity
            -- distance = math.max(zoomMin, Camera.distance + zoomVelocity * dt)
            distance = Camera.distance

			if zoomSum then
				distance = math.max(zoomMin, Camera.distance + zoomSum * getCameraDistanceFactor())
				-- distance = math.max(zoomMin, Camera.distance + zoomSum)
				zoomSum = nil
			end

            zoomVelocity = zoomVelocity * zoomVelocityDrag
        else -- execute autosnap
            autosnapTimer = autosnapTimer - dt
            if autosnapTimer <= 0.0 then
                target = autosnapToTarget
                distance = autosnapToDistance
                autosnapTimer = -1.0
            else
                local v = easingQuadOut(1.0 - autosnapTimer / autosnapDuration)
                target = lerp(autosnapFromTarget, autosnapToTarget, v)
                distance = lerp(autosnapFromDistance, autosnapToDistance, v)
            end
            cameraVelocity = Number3(0, 0, 0)
            zoomVelocity = 0
        end

        setSatelliteCamera(rotation, target, distance, false)
    end

    if blocksCounterNeedsRefresh then
    	blocksCounterNeedsRefresh = false
    	-- local count = getSelfAndDescendantsBlocksCount(item)
    	-- blocksCounterLabel.Text = "⚀ " .. count
	end
end

Pointer.Zoom = function() end
zoom = function(zoomValue)
	if not zoomSum then zoomSum = zoomValue else zoomSum = zoomSum + zoomValue end
end

Pointer.Down = function() end
down = function(e)
	if gizmo:down(e) then
		gizmoCapturedPointer = true
		return
	end
	if mirrorGizmo:down(e) then
		mirrorGizmoCapturedPointer = true
		return
	end
	if placeGizmo:down(e) then
		placeGizmoCapturedPointer = true
		return
	end
	if colliderMinGizmo:down(e) then
		colliderMinGizmoCapturedPointer = true
		return
	end
	if colliderMaxGizmo:down(e) then
		colliderMaxGizmoCapturedPointer = true
		return
	end
end

Pointer.Up = function() end
up = function(e)
	if gizmoCapturedPointer then
		gizmoCapturedPointer = false
		gizmo:up(e)
	end
	if mirrorGizmoCapturedPointer then
		mirrorGizmoCapturedPointer = false
		mirrorGizmo:up(e)
		return
	end
	if placeGizmoCapturedPointer then
		placeGizmoCapturedPointer = false
		placeGizmo:up(e)
		return
	end
	if colliderMinGizmoCapturedPointer then
		colliderMinGizmoCapturedPointer = false
		colliderMinGizmo:up(e)
		return
	end
	if colliderMaxGizmoCapturedPointer then
		colliderMaxGizmoCapturedPointer = false
		colliderMaxGizmo:up(e)
		return
	end

	if blockerShape ~= nil then
		blockerShape:RemoveFromParent()
		blockerShape = nil
	end

	if currentMode == mode.edit and not editBlockedUntilUp then
		local impact
		local shape
		local impactDistance = 1000000000
		for k,subShape in ipairs(shapes) do
			if subShape.IsHidden == false then
				local tmpImpact = e:CastRay(subShape)
				-- if tmpImpact then print("HIT subShape, distance =", tmpImpact.Distance) end
				if tmpImpact and tmpImpact.Distance < impactDistance then
					shape = subShape
					impactDistance = tmpImpact.Distance
					impact = tmpImpact
				end
			end
		end
		if not continuousEdition then
			if currentEditSubmode == editSubmode.pick then
				if Player.IsHidden == false then
					for _,bodyPartName in ipairs(bodyParts) do
						local bodyPart = Player[bodyPartName]
						if bodyPart.IsHidden == false then
							local tmpImpact = e:CastRay(bodyPart)
							-- if tmpImpact then print("HIT bodyPart, distance =", tmpImpact.Distance) end
							if tmpImpact and tmpImpact.Distance < impactDistance then
								impactDistance = tmpImpact.Distance
								impact = tmpImpact
							end
						end
					end
					for _,equipment in pairs(Player.equipments) do
						if equipment.IsHidden == false then
							local tmpImpact = e:CastRay(equipment)
							-- if tmpImpact then print("HIT equipment, distance =", tmpImpact.Distance) end
							if tmpImpact and tmpImpact.Distance < impactDistance then
								impactDistance = tmpImpact.Distance
								impact = tmpImpact
							end

							for _,shape in ipairs(equipment.attachedParts or {}) do
								if shape.IsHidden == false then
									local tmpImpact = e:CastRay(shape)
									-- if tmpImpact then print("HIT attached part, distance =", tmpImpact.Distance) end
									if tmpImpact and tmpImpact.Distance < impactDistance then
										impactDistance = tmpImpact.Distance
										impact = tmpImpact
									end	
								end
							end
						end
					end
				end -- end Player.IsHidden == false

				-- copies are body parts copied when editing a wearable
				-- and hiding other player parts
				if copies then
					for _,copy in ipairs(copies) do
						if copy.IsHidden == false then
							local tmpImpact = e:CastRay(copy)
							-- if tmpImpact then print("HIT copy, distance =", tmpImpact.Distance) end
							if tmpImpact and tmpImpact.Distance < impactDistance then
								impactDistance = tmpImpact.Distance
								impact = tmpImpact
							end
						end
					end
				end

				if impact then
					pickCubeColor(impact.Block)
				end
			elseif currentEditSubmode == editSubmode.add then
				addBlockWithImpact(impact, currentFacemode, shape)
				table.insert(undoShapesStack, shape)
				redoShapesStack = {}
			elseif currentEditSubmode == editSubmode.remove and shape ~= nil then
				removeBlockWithImpact(impact, currentFacemode, shape)
				table.insert(undoShapesStack, shape)
				redoShapesStack = {}
			elseif currentEditSubmode == editSubmode.paint then
				replaceBlockWithImpact(impact, currentFacemode, shape)
				table.insert(undoShapesStack, shape)
				redoShapesStack = {}
			elseif currentEditSubmode == editSubmode.mirror then
				placeMirror(impact, shape)
			elseif currentEditSubmode == editSubmode.select then
				selectFocusShape(shape)
			end
		end
		if impact ~= nil then
			checkAutoSave()
			refreshUndoRedoButtons()
		end

	elseif currentMode == mode.points then
		
	end

	local shape = selectedShape or focusShape
	if shape then
		shape.KeepHistoryTransactionPending = false
	end
	continuousEdition = false
	editBlockedUntilUp = false
end

Client.OnPlayerJoin = function(p)
	Player.Physics = false
end

Pointer.LongPress = function() end
longPress = function(e)
	if gizmoCapturedPointer then return end

	if currentMode == mode.edit then

		local impact = nil
		selectedShape = nil
		local impactDistance = 1000000000
		for _,subShape in ipairs(shapes) do
			local tmpImpact = e:CastRay(subShape, mirrorShape)
			if tmpImpact and tmpImpact.Distance < impactDistance then
				selectedShape = subShape
				impactDistance = tmpImpact.Distance
				impact = tmpImpact
			end
		end

		if impact.Block ~= nil then
			selectedShape.KeepHistoryTransactionPending = true

			continuousEdition = true

			-- add / remove / paint first block
			if currentEditSubmode == editSubmode.add then
				local addedBlock = addBlockWithImpact(impact, currentFacemode, selectedShape)
				table.insert(blocksAddedWithDrag, addedBlock)
				table.insert(undoShapesStack, selectedShape)
	
			elseif currentEditSubmode == editSubmode.remove then

				blockerShape = MutableShape()
				blockerShape.Palette:AddColor(Color(0, 0, 0, 0))
				World:AddChild(blockerShape)
				blockerShape.Scale = selectedShape.Scale
				blockerShape.Pivot = selectedShape.Pivot
				blockerShape.Position = selectedShape.Position
				blockerShape.Rotation = selectedShape.Rotation
				local coords = blockerShape:WorldToBlock(selectedShape:BlockToWorld(impact.Block))
				blockerShape:AddBlock(1, coords)

				removeBlockWithImpact(impact, currentFacemode, selectedShape)
				table.insert(undoShapesStack, selectedShape)
	
			elseif currentEditSubmode == editSubmode.paint then
				replaceBlockWithImpact(impact, currentFacemode, selectedShape)
				table.insert(undoShapesStack, selectedShape)
			end
		end
	end
end

Pointer.DragBegin = function() end
dragBegin = function()
	dragging = true
	editBlockedUntilUp = not continuousEdition
end

Pointer.Drag = function() end
drag = function(e)
	if gizmoCapturedPointer then
		gizmo:drag(e)
		return
	end
	if mirrorGizmoCapturedPointer then
		mirrorGizmo:drag(e)
		return
	end
	if placeGizmoCapturedPointer then
		placeGizmo:drag(e)
		return
	end
	if colliderMinGizmoCapturedPointer then
		colliderMinGizmo:drag(e)
		return
	end
	if colliderMaxGizmoCapturedPointer then
		colliderMaxGizmo:drag(e)
		return
	end

	if not continuousEdition then
		angularVelocity = angularVelocity + Number3(-e.DY * angularSpeed, e.DX * angularSpeed, 0)
	end

	if continuousEdition and currentMode == mode.edit then
		local impact = e:CastRay(selectedShape, mirrorShape)

		if impact.Block == nil then
			return
		end

		if currentEditSubmode == editSubmode.add then
			local canBeAdded = true
			for k, b in pairs(blocksAddedWithDrag) do
				if impact.Block.Coords == b.Coords then
					-- do not add on top of added blocks
					canBeAdded = false
					break
				end
			end
			if canBeAdded then
				local addedBlock = addBlockWithImpact(impact, currentFacemode, selectedShape)
				table.insert(blocksAddedWithDrag, addedBlock)
			end

		elseif currentEditSubmode == editSubmode.remove then

			local impactOnBlocker = e:CastRay(blockerShape, mirrorShape)
				
			if impactOnBlocker.Block ~= nil and impact.Distance > impactOnBlocker.Distance then
				return
			end

			local coords = blockerShape:WorldToBlock(item:BlockToWorld(impact.Block))
			blockerShape:AddBlock(1, coords)
			removeBlockWithImpact(impact, false, selectedShape)

		elseif currentEditSubmode == editSubmode.paint then
			replaceBlockWithImpact(impact, currentFacemode, selectedShape)
		end
	end
end

Pointer.DragEnd = nil
dragEnd = function()
	dragging = false
	blocksAddedWithDrag = {}
end

Pointer.Drag2Begin = function() end
drag2Begin = function()
    if currentMode == mode.edit then
        dragging2 = true
		editBlockedUntilUp = true
        UI.Crosshair = true
		refreshDrawMode()
    end
end

Pointer.Drag2 = function() end
drag2 = function(e)
	-- in edit mode, Drag2 performs camera pan
	if currentMode == mode.edit then
		local dx = e.DX * cameraSpeed * getCameraDistanceFactor()
		local dy = e.DY * cameraSpeed * getCameraDistanceFactor()
		cameraVelocity = cameraVelocity - Camera.Right * dx - Camera.Up * dy

		-- restore satellite mode if dPad was in use
		if cameraFree then
			cameraFree = false
			blockHighlightDirty = true
			Camera.target = Camera.Position + Camera.Forward * Camera.distance
			Camera:SetModeSatellite(Camera.target, Camera.distance)
		end
	end
end

Pointer.Drag2End = function() end
drag2End = function()
	-- snaps to nearby block center after drag2 (camera pan)
	if dragging2 then

		local impact
		local shape
		local impactDistance = 1000000000
		for k,subShape in ipairs(shapes) do
			local tmpImpact = Camera:CastRay(subShape)
			if tmpImpact and tmpImpact.Distance < impactDistance then
				shape = subShape
				impactDistance = tmpImpact.Distance
				impact = tmpImpact
			end
		end

	    if shape ~= nil then impact = Camera:CastRay(shape) end

        if impact.Block ~= nil then
            autosnapFromTarget = Camera.target
            autosnapFromDistance = Camera.distance

            -- both distance & target will need to be animated to emulate a camera translation
            autosnapToTarget = impact.Block.Position + halfVoxel
            autosnapToDistance = (autosnapToTarget - Camera.Position).Length

            autosnapTimer = autosnapDuration
        end

        dragging2 = false
        UI.Crosshair = false
		refreshDrawMode()
    end
end

Screen.DidResize = function() end
didResize = function(width, height)
	ui:fitScreen()
	-- 
	-- Camera.FOV = (width / height) * 60.0
	if orientationCube ~= nil then
		local size = paletteBtn.Width * 2 + ui_config.padding
		orientationCube:setSize(size)
		orientationCube:setScreenPosition(editSubMenu.LocalPosition.X + editSubMenu.Width - size, editSubMenu.LocalPosition.Y - size - ui_config.padding)
	end

	if colorPicker ~= nil then
		local maxW = math.min(Screen.Width * 0.5 - ui.kPadding * 3, 400)
		local maxH = math.min(Screen.Height * 0.4 - ui.kPadding * 3, 300)
		colorPicker:setMaxSize(maxW, maxH)
	end

	updatePalettePosition()

	-- selectButtons.LocalPosition = Number3(5, Screen.Height / 2 - 25, 0)
end

--------------------------------------------------
-- Utilities
--------------------------------------------------

initClientFunctions = function()
	function getCurrentColor()
		return palette:getCurrentColor()
	end

	function setMode(newMode, newSubmode)
		local updatingMode = newMode ~= nil and newMode ~= currentMode
		local updatingSubMode = false

		-- going from one mode to another
		if updatingMode then
			if newMode < 1 or newMode > mode.max then
				error("setMode - invalid change:" .. newMode .. " " .. newSubmode)
				return
			end

			cameraStateSave()

			currentMode = newMode

			if currentMode == mode.edit then
				-- unequip Player
				if poiActiveName == poiNameHand then
					Player:EquipRightHand(nil)
				elseif poiActiveName == poiNameHat then
					Player:EquipHat(nil)
				elseif poiActiveName == poiNameBackpack then
					Player:EquipBackpack(nil)
				end

				-- remove avatar and arrows
				Player:RemoveFromParent()

				item:SetParent(World)
                item.LocalPosition = { 0, 0, 0 }
                item.LocalRotation = { 0, 0, 0 }

                -- in edit mode, using dPad will set camera free
				-- Client.DirectionalPad = function(x, y)
				--     dPad.x = x
				--     dPad.y = y
				--     setFreeCamera()
				-- end

			else -- place item points / preview
				-- make player appear in front of camera with item in hand

				Player.Head.IgnoreAnimations = true
				Player.Body.IgnoreAnimations = true
				Player.RightArm.IgnoreAnimations = true
				Player.RightHand.IgnoreAnimations = true
				Player.LeftArm.IgnoreAnimations = true
				Player.LeftHand.IgnoreAnimations = true
				Player.LeftLeg.IgnoreAnimations = true
				Player.LeftFoot.IgnoreAnimations = true
				Player.RightLeg.IgnoreAnimations = true
				Player.RightFoot.IgnoreAnimations = true
				
				Player:SetParent(World)
				Player.Physics = false
				
				if poiActiveName == poiNameHand then
					Player:EquipRightHand(item)
				elseif poiActiveName == poiNameHat then
					Player:EquipHat(item)
				elseif poiActiveName == poiNameBackpack then
					Player:EquipBackpack(item)
				end

				Client.DirectionalPad = nil
				cameraFree = false
			end

			refreshUndoRedoButtons()
			cameraStateSetToExpected()
		end -- end updating node

		-- see if submode needs to be changed
		if newSubmode ~= nil then
			selectFocusShape()
			if newSubmode < 1 then
				error("setMode - invalid change:" .. newMode .. " " .. newSubmode)
				return
			end

			if currentMode == mode.edit then
				if newSubmode > editSubmode.max then
					error("setMode - invalid change:" .. newMode .. " " .. newSubmode)
					return
				end
				confirmColliderBtn:_onRelease()
				-- return if new submode is already active
				if newSubmode == currentEditSubmode then return end
				updatingSubMode = true
				currentEditSubmode = newSubmode

			elseif currentMode == mode.points then
				if newSubmode > pointsSubmode.max then
					error("setMode - invalid change:" .. newMode .. " " .. newSubmode)
					return
				end
				-- return if new submode is already active
				if newSubmode == currentPointsSubmode then return end
				updatingSubMode = true
				currentPointsSubmode = newSubmode
			end
		end

		if updatingMode then
			LocalEvent:Send("modeDidChange")
		end

		if updatingMode or updatingSubMode then
			LocalEvent:Send("modeOrSubmodeDidChange")
		end
	end

	function checkAutoSave()
		if changesSinceLastSave == false then
			changesSinceLastSave = true
			autoSaveDT = 0.0
		end
	end

	function save()
		--TODO: Remove customCollisionBox mechanic when adding and removing blocks, does not shrink collider by default
		if customCollisionBox then
			item.CollisionBox = customCollisionBox
		end

		item:Save(Environment.itemFullname, palette.colorsShape.Palette)

		changesSinceLastSave = false
		autoSaveDT = 0.0

		saveBtn.label.Text = "✅"
	end

	addBlockWithImpact = function(impact, facemode, shape)
		if shape == nil or impact == nil or facemode == nil or impact.Block == nil then return end
		if type(facemode) ~= Type.boolean then return end
		blocksCounterNeedsRefresh = true

		-- always add the first block
		local addedBlock = addSingleBlock(impact.Block, impact.FaceTouched, shape)

		-- if facemode is enable, test the neighbor blocks of impact.Block
		if addedBlock ~= nil and facemode == true then
			local faceTouched = impact.FaceTouched
			local impactBlockColor = shape.Palette[impact.Block.PaletteIndex].Color
			local queue = { impact.Block }
			-- neighbor finder (depending on the mirror orientation)
			local neighborFinder = {}
			if faceTouched == Face.Top or faceTouched == Face.Bottom then
				neighborFinder = { Number3(1,0,0), Number3(-1,0,0), Number3(0,0,1), Number3(0,0,-1) }
			elseif faceTouched == Face.Left or faceTouched == Face.Right then
				neighborFinder = { Number3(0,1,0), Number3(0,-1,0), Number3(0,0,1), Number3(0,0,-1) }
			elseif faceTouched == Face.Front or faceTouched == Face.Back then
				neighborFinder = { Number3(1,0,0), Number3(-1,0,0), Number3(0,1,0), Number3(0,-1,0) }
			end

			-- explore
			while true do
				local b = table.remove(queue)
				if b == nil then break end
				for i, f in ipairs(neighborFinder) do
					local neighborCoords = b.Coords + f
					-- check there is a block
					local neighborBlock = shape:GetBlock(neighborCoords)
					-- check it is the same color
					if neighborBlock ~= nil and shape.Palette[neighborBlock.PaletteIndex].Color == impactBlockColor then 
						-- try to add new block on top of neighbor
						addedBlock = addSingleBlock(neighborBlock, faceTouched, shape)
						if addedBlock ~= nil then
							table.insert(queue, neighborBlock)
						end
					end
				end
			end
		end

		updateMirror()

		return addedBlock
	end

	addSingleBlock = function(block, faceTouched, shape)
		local faces = {
			[Face.Top] = Number3(0, 1, 0),
			[Face.Bottom] = Number3(0, -1, 0),
			[Face.Left] = Number3(-1, 0, 0),
			[Face.Right] = Number3(1, 0, 0),
			[Face.Back] = Number3(0, 0, -1),
			[Face.Front] = Number3(0, 0, 1)
		}
		local newBlockCoords = block.Coordinates + faces[faceTouched]

		if enableWearablePattern and pattern then
			local targetPattern = pattern
			if item.ChildrenCount > 0 then
				local child = item:GetChild(1) -- Is first child (left part or right sleeve)
				if shape == child then
					targetPattern = pattern:GetChild(1)
				elseif child.ChildrenCount > 0 then
					if shape == child:GetChild(1) then -- Is first child of child (left sleeve)
						targetPattern = pattern:GetChild(1):GetChild(1)
					end
				end
			end
			local coords = newBlockCoords
			local relativeCoords = coords - shape:GetPoint("origin").Coords
			local pos = relativeCoords + targetPattern:GetPoint("origin").Coords
			local b = targetPattern:GetBlock(pos)
			if not b or b.Color == Color.Red then
				pattern:SetParent(World)
				local nextShape = item
				pattern.Scale = item.Scale + Number3(1,1,1) * 0.001
				hierarchyActions:applyToDescendants(pattern, { includeRoot = true }, function(s)
					s.PrivateDrawMode = 1
					s.Pivot = s:GetPoint("origin").Coords
					s.Position = nextShape.Position
					nextShape = nextShape:GetChild(1)
				end)
				Timer(0.5, function()
					pattern:RemoveFromParent()
				end)
				return
			end
		end

		local added = shape:AddBlock(getCurrentColor(), newBlockCoords)
		if not added then
			return nil
		end

		local addedBlock = shape:GetBlock(newBlockCoords)
		-- add a block to the other side of the mirror
		if addedBlock ~= nil and shape == mirrorAnchor.selectedShape then
			local mirrorBlockCoords = mirrorAnchor.coords
			local mirrorBlock = nil

			local posX = currentMirrorAxis == mirrorAxes.x and (mirrorBlockCoords.X - (addedBlock.Coordinates.X - mirrorBlockCoords.X)) or addedBlock.Coordinates.X
			local posY = currentMirrorAxis == mirrorAxes.y and (mirrorBlockCoords.Y - (addedBlock.Coordinates.Y - mirrorBlockCoords.Y)) or addedBlock.Coordinates.Y
			local posZ = currentMirrorAxis == mirrorAxes.z and (mirrorBlockCoords.Z - (addedBlock.Coordinates.Z - mirrorBlockCoords.Z)) or addedBlock.Coordinates.Z
			local added = shape:AddBlock(getCurrentColor(), posX, posY, posZ)
			if added then
				local mirrorBlock = shape:GetBlock(posX, posY, posZ)
				if mirrorBlock and continuousEdition then
					table.insert(blocksAddedWithDrag, mirrorBlock)
				end
			end
		end

		return addedBlock
	end

	removeBlockWithImpact = function(impact, facemode, shape)
		if shape.BlocksCount == 1 then return end
		if shape == nil or impact == nil or facemode == nil or impact.Block == nil then return end
		if type(facemode) ~= Type.boolean then return end
		blocksCounterNeedsRefresh = true

		-- always remove the first block
		local removed = removeSingleBlock(impact.Block, shape)
		
		-- if facemode is enable, test the neighbor blocks of impact.Block
		if removed and facemode == true then

			local faceTouched = impact.FaceTouched
			local impactBlockColor = shape.Palette[impact.Block.PaletteIndex].Color
			local queue = { impact.Block }
			-- neighbor finder (depending on the mirror orientation)
			local neighborFinder = {}
			if faceTouched == Face.Top or faceTouched == Face.Bottom then
				neighborFinder = { Number3(1,0,0), Number3(-1,0,0), Number3(0,0,1), Number3(0,0,-1) }
			elseif faceTouched == Face.Left or faceTouched == Face.Right then
				neighborFinder = { Number3(0,1,0), Number3(0,-1,0), Number3(0,0,1), Number3(0,0,-1) }
			elseif faceTouched == Face.Front or faceTouched == Face.Back then
				neighborFinder = { Number3(1,0,0), Number3(-1,0,0), Number3(0,1,0), Number3(0,-1,0) }
			end

			-- relative coords from touched plan to block next to it
			-- (needed to check if there is a block next to the one we want to remove)
			local targetNeighbor = targetBlockDeltaFromTouchedFace(faceTouched)

			-- explore
			while true do
				local b = table.remove(queue)
				if b == nil then break end
				for i, f in ipairs(neighborFinder) do
					local neighborCoords = b.Coords + f
					-- check there is a block
					local neighborBlock = shape:GetBlock(neighborCoords)
					-- check block on top
					local blockOnTopPosition = neighborCoords + targetNeighbor
					local blockOnTop = shape:GetBlock(blockOnTopPosition)
					-- check it is the same color
					if neighborBlock ~= nil and shape.Palette[neighborBlock.PaletteIndex].Color == impactBlockColor and blockOnTop == nil then
						removeSingleBlock(neighborBlock, shape)
						table.insert(queue, neighborBlock)
					end
				end
				if shape.BlocksCount == 1 then return end
			end
		end

		updateMirror()
	end

	removeSingleBlock = function(block, shape)
		if enableWearablePattern and pattern then
			local targetPattern = pattern
			if item.ChildrenCount > 0 then
				local child = item:GetChild(1) -- Is first child (left part or right sleeve)
				if shape == child then
					targetPattern = pattern:GetChild(1)
				elseif child.ChildrenCount > 0 then
					if shape == child:GetChild(1) then -- Is first child of child (left sleeve)
						targetPattern = pattern:GetChild(1):GetChild(1)
					end
				end
			end
			local coords = block.Coords
			local relativeCoords = coords - shape:GetPoint("origin").Coords
			local pos = relativeCoords + targetPattern:GetPoint("origin").Coords
			local b = targetPattern:GetBlock(pos)
			if b and b.Color == Color.Red then
				pattern:SetParent(World)
				local nextShape = item
				hierarchyActions:applyToDescendants(pattern, { includeRoot = true }, function(s)
					s.PrivateDrawMode = 1
					s.Scale = 1.001
					s.Pivot = s:GetPoint("origin").Coords
					s.Position = nextShape.Position
					nextShape = nextShape:GetChild(1)
				end)
				Timer(0.5, function()
					pattern:RemoveFromParent()
				end)
				return
			end
		end
		block:Remove()

        -- last block can't be removed via mirror mode
		if shape.BlocksCount > 2 and shape == mirrorAnchor.selectedShape then
			local mirrorBlockCoords = mirrorAnchor.coords
			local mirrorBlock = nil

			local posX = currentMirrorAxis == mirrorAxes.x and (mirrorBlockCoords.X - (block.Coordinates.X - mirrorBlockCoords.X)) or block.Coordinates.X
			local posY = currentMirrorAxis == mirrorAxes.y and (mirrorBlockCoords.Y - (block.Coordinates.Y - mirrorBlockCoords.Y)) or block.Coordinates.Y
			local posZ = currentMirrorAxis == mirrorAxes.z and (mirrorBlockCoords.Z - (block.Coordinates.Z - mirrorBlockCoords.Z)) or block.Coordinates.Z
			mirrorBlock = shape:GetBlock(posX, posY, posZ)

			if mirrorBlock ~= nil then
				mirrorBlock:Remove()
			end
		end

		return true
	end

	replaceBlockWithImpact = function(impact, facemode, shape)
		if impact == nil or facemode == nil or impact.Block == nil then return end
		if type(facemode) ~= Type.boolean then return end

		local impactBlockColor = shape.Palette[impact.Block.PaletteIndex].Color

		-- return if trying to replace with same color index
		if impactBlockColor == getCurrentColor() then return end

		-- always remove the first block
		-- it would be nice to have a return value here
		replaceSingleBlock(impact.Block, shape)

		if facemode == true then
			local faceTouched = impact.FaceTouched
			local queue = { impact.Block }
			-- neighbor finder (depending on the mirror orientation)
			local neighborFinder = {}
			if faceTouched == Face.Top or faceTouched == Face.Bottom then
				neighborFinder = { Number3(1,0,0), Number3(-1,0,0), Number3(0,0,1), Number3(0,0,-1) }
			elseif faceTouched == Face.Left or faceTouched == Face.Right then
				neighborFinder = { Number3(0,1,0), Number3(0,-1,0), Number3(0,0,1), Number3(0,0,-1) }
			elseif faceTouched == Face.Front or faceTouched == Face.Back then
				neighborFinder = { Number3(1,0,0), Number3(-1,0,0), Number3(0,1,0), Number3(0,-1,0) }
			end

			-- relative coords from touched plan to block next to it
			-- (needed to check if there is a block next to the one we want to remove)
			local targetNeighbor = targetBlockDeltaFromTouchedFace(faceTouched)

			-- explore
			while true do
				local b = table.remove(queue)
				if b == nil then break end
				for i, f in ipairs(neighborFinder) do
					local neighborCoords = b.Coords + f
					-- check there is a block
					local neighborBlock = shape:GetBlock(neighborCoords)
					-- check block on top
					local blockOnTopPosition = neighborCoords + targetNeighbor
					local blockOnTop = shape:GetBlock(blockOnTopPosition)
					-- check it is the same color
					if neighborBlock ~= nil and shape.Palette[neighborBlock.PaletteIndex].Color == impactBlockColor and blockOnTop == nil then
						replaceSingleBlock(neighborBlock, shape)
						table.insert(queue, neighborBlock)
					end
				end
			end
		end
	end

	replaceSingleBlock = function(block, shape)
		block:Replace(getCurrentColor())

		if shape == mirrorAnchor.selectedShape then
			local mirrorBlockCoords = mirrorAnchor.coords
			local mirrorBlock = nil

			local posX = currentMirrorAxis == mirrorAxes.x and (mirrorBlockCoords.X - (block.Coordinates.X - mirrorBlockCoords.X)) or block.Coordinates.X
			local posY = currentMirrorAxis == mirrorAxes.y and (mirrorBlockCoords.Y - (block.Coordinates.Y - mirrorBlockCoords.Y)) or block.Coordinates.Y
			local posZ = currentMirrorAxis == mirrorAxes.z and (mirrorBlockCoords.Z - (block.Coordinates.Z - mirrorBlockCoords.Z)) or block.Coordinates.Z
			mirrorBlock = shape:GetBlock(posX, posY, posZ)

			if mirrorBlock ~= nil then
				mirrorBlock:Replace(getCurrentColor())
			end
		end
	end

	pickCubeColor = function(block)
		if block ~= nil then
			local color = block.Color
			palette:selectOrAddColorIfMissing(color)
		end

    	if prePickEditSubmode then setMode(nil, prePickEditSubmode) end
    	if prePickSelectedBtn then editMenuToggleSelect(prePickSelectedBtn) end

		LocalEvent:Send("selectedColorDidChange")
	end

	selectFocusShape = function(shape)
		focusShape = shape

		-- Do not show gizmo if root item or if shape is nil (unselect)
		local gizmoShape = (shape ~= nil and shape ~= item) and shape or nil
		gizmo:setObject(gizmoShape)

		if focusShape then
			local maxLength = math.max(focusShape.Width, math.max(focusShape.Height, focusShape.Depth))
			gizmo:setGizmoScale(1 - (1 / maxLength) - 0.3)
		end
		refreshDrawMode()

		selectControlsRefresh()
	end

	refreshUndoRedoButtons = function()
		-- show these buttons only on edit mode
		if currentMode ~= mode.edit then
			return
		end

		local lastUndoableShape = undoShapesStack[#undoShapesStack]
		if lastUndoableShape.CanUndo then
			undoBtn:enable()
		else
			undoBtn:disable()
		end

		local lastRedoableShape = redoShapesStack[#redoShapesStack]
		if lastRedoableShape.CanRedo then
			redoBtn:enable()
		else 
			redoBtn:disable()
		end
	end

	placeMirror = function(impact, shape)
		if not shape then return end
		-- place mirror if block has been hit
		-- and parent shape is equal to shape parameter
		if impact ~= nil and impact.Object == shape and impact.Block ~= nil then
			-- first time the mirror is placed since last removal
			if mirrorShape == nil then

				local face = impact.FaceTouched

				mirrorShape = Shape(Items.cube_white)
				mirrorShape.Pivot = {0.5, 0.5, 0.5}
				mirrorShape.PrivateDrawMode = 1

				-- no rotation, only using scale
				if face == Face.Right then
					currentMirrorAxis = mirrorAxes.x
				elseif face == Face.Left then
					currentMirrorAxis = mirrorAxes.x
				elseif face == Face.Top then
					currentMirrorAxis = mirrorAxes.y
				elseif face == Face.Bottom then
					currentMirrorAxis = mirrorAxes.y
				elseif face == Face.Back then
					currentMirrorAxis = mirrorAxes.z
				elseif face == Face.Front then
					currentMirrorAxis = mirrorAxes.z
				else
					error("can't set mirror axis")
					currentMirrorAxis = nil
				end

				-- Anchor at the shape position because the mirror is not attached to the shape
				mirrorAnchor = Object()
				mirrorAnchor:SetParent(World)
				mirrorShape:SetParent(mirrorAnchor)
			end

			mirrorAnchor.coords = impact.Block.Coords
			mirrorAnchor.selectedShape = shape

			mirrorGizmo:setObject(mirrorAnchor)

			mirrorControls:show()

			placeMirrorText:hide()
			rotateMirrorBtn:show()
			removeMirrorBtn:show()
			mirrorControls.Width = ui_config.padding + (rotateMirrorBtn.Width + ui_config.padding) * 2
			mirrorControls.LocalPosition = {Screen.Width - mirrorControls.Width - ui_config.padding, editMenu.Height + 2 * ui_config.padding, 0}	
	
		-- no block touched, remove mirror
		elseif mirrorShape ~= nil then
			removeMirror()
			mirrorGizmo:setObject(nil)
			placeMirrorText:show()
			rotateMirrorBtn:hide()
			removeMirrorBtn:hide()	
			mirrorControls.Width = placeMirrorText.Width + ui_config.padding * 2
			mirrorControls.LocalPosition = {Screen.Width - mirrorControls.Width - ui_config.padding, editMenu.Height + 2 * ui_config.padding, 0}
		end

		updateMirror()
	end

	removeMirror = function()
		if mirrorShape ~= nil then
			mirrorGizmo:setObject(nil)
			mirrorShape:RemoveFromParent()
			mirrorAnchor:RemoveFromParent()
		end
		mirrorShape = nil
		mirrorAnchor = nil
		currentMirrorAxis = nil
	end

	-- updates the dimension of the mirror when adding/removing cubes
	updateMirror = function()
		if mirrorShape ~= nil and mirrorAnchor ~= nil then

			local shape = mirrorAnchor.selectedShape
			if not shape then return end

			local width = shape.Width + mirrorMargin
			local height = shape.Height + mirrorMargin
			local depth = shape.Depth + mirrorMargin
				
			mirrorAnchor.Position = shape:BlockToWorld(mirrorAnchor.coords + {0.5, 0.5, 0.5})
			mirrorAnchor.Rotation = shape.Rotation

			local shapeCenter = shape:BlockToWorld(Number3(shape.Width * 0.5, shape.Height * 0.5, shape.Depth * 0.5))

			mirrorShape.Position = shapeCenter

			if currentMirrorAxis == mirrorAxes.x then
				mirrorShape.LocalScale = { mirrorThickness, height, depth }
				mirrorShape.LocalPosition.X = 0
				mirrorGizmo:setAxisVisibility(true, false, false)
			elseif currentMirrorAxis == mirrorAxes.y then
				mirrorShape.LocalScale = { width, mirrorThickness, depth }
				mirrorShape.LocalPosition.Y = 0
				mirrorGizmo:setAxisVisibility(false, true, false)
			elseif currentMirrorAxis == mirrorAxes.z then
				mirrorShape.LocalScale = { width, height, mirrorThickness }
				mirrorShape.LocalPosition.Z = 0
				mirrorGizmo:setAxisVisibility(false, false, true)
			end

			mirrorGizmo:setObject(mirrorShape)
		end
	end

	getAlignment = function(normal)
		return math.abs(normal:Dot(Camera.Forward))
	end

	sqr_len = function(dx, dy)
		return dx * dx + dy * dy
	end

	cameraStateSave = function()
	    if cameraFree then
	        cameraCurrentState.target = Camera.Position:Copy()
	    else
            cameraCurrentState.target = Camera.target:Copy()
            cameraCurrentState.distance = Camera.distance
        end
        cameraCurrentState.rotation = cameraRotation:Copy()
	end

	cameraStateSet = function(state)
		if state == cameraStates.preview then
		    setSatelliteCamera(state.rotation, Player.Head.Position, state.distance, false)

			blockHighlight.IsHidden = true
            Pointer:Show()
            UI.Crosshair = false
        elseif cameraFree then
            Camera.Position = state.target:Copy()
            setCameraRotation(state.rotation)

            setFreeCamera()
		else
            setSatelliteCamera(state.rotation, state.target, state.distance, true) -- refresh camera immediately...
            blockHighlightDirty = true -- so that highlight block can be refreshed asap
		end
		cameraCurrentState = state
	end

	cameraStateSetToExpected = function(alwaysRefresh)
	    local state = cameraStates.item
		if currentMode == mode.points then
            state = cameraStates.preview
        end
		if alwaysRefresh == nil or alwaysRefresh or state ~= cameraCurrentState then
			cameraStateSet(state)
		end
	end

	setSatelliteCamera = function(rotation, target, distance, immediate)
	    if rotation ~= nil then
	        setCameraRotation(rotation)
        end

        -- store variables used for satellite mode, we need them to handle zoom&drag
        if target ~= nil then
            Camera.target = target:Copy()
        end
        if distance ~= nil then
            Camera.distance = distance
        end
        Camera:SetModeSatellite(Camera.target, Camera.distance)

        if immediate then
            Camera.Position = target + Camera.Backward * distance
        end
	end

	setFreeCamera = function()
        blockHighlight.IsHidden = true
        Camera.distance = cameraDistThreshold -- reset distance, make dist scaling neutral
        cameraFree = true
        Camera:SetModeFree()
    end

	fitObjectToScreen = function(object, rotation)
	    -- set camera positioning using FitToScreen
        local targetPoint = object:BlockToWorld(object.Center)
        Camera.Position = targetPoint
        if rotation ~= nil then
            Camera.Rotation = rotation
        end

		local box = Box()
		box:Fit(object, true)
        Camera:FitToScreen(box, 0.8, true) -- sets camera back

        -- maintain camera satellite mode
        local distance = (Camera.Position - targetPoint).Length
        setSatelliteCamera(rotation, targetPoint, distance, false)
	end

	getCameraDistanceFactor = function()
	    return 1 + math.max(0, cameraDistFactor * (Camera.distance - cameraDistThreshold))
	end

	applyDrag = function(velocity, drag, isZero)
	    if isZero then
	        velocity = Number3(0, 0, 0)
        else
            velocity = velocity * drag
        end
	end

	setCameraRotation = function(rotation)
	    cameraRotation = rotation:Copy()

        -- clamp rotation between 90° and -90° on X
        cameraRotation.X = clamp(cameraRotation.X, -math.pi * 0.4999, math.pi * 0.4999)

        Camera.Rotation = cameraRotation

		if orientationCube ~= nil then
			orientationCube:setRotation(cameraRotation)
		end
	end

	refreshBlockHighlight = function()
		local shape
		local impactDistance = 1000000000
		for k,subShape in ipairs(shapes) do
			local tmpImpact = Camera:CastRay(subShape)
			if tmpImpact and tmpImpact.Distance < impactDistance then
				shape = subShape
				impactDistance = tmpImpact.Distance
				impact = tmpImpact
			end
		end

	    local impact
	    if shape ~= nil then impact = Camera:CastRay(shape) end

        if impact.Block ~= nil then
			local halfVoxelVec = Number3(0.5,0.5,0.5)
			halfVoxelVec:Rotate(shape.Rotation)
            blockHighlight.Position = impact.Block.Position + halfVoxelVec
            blockHighlight.IsHidden = false
			blockHighlight.Rotation = shape.Rotation
        else
            blockHighlight.IsHidden = true
        end
        blockHighlightDirty = false
	end
end

setFacemode = function(newFacemode)
	if newFacemode ~= currentFacemode then
		currentFacemode = newFacemode	
	end
end

targetBlockDeltaFromTouchedFace = function(faceTouched)
	-- relative coords from touched plan to block next to it
	-- (needed to check if there is a block next to the one we want to remove)
	local targetNeighbor = Number3(0, 0, 0)
	if faceTouched == Face.Top then
		targetNeighbor = Number3(0, 1, 0)
	elseif faceTouched == Face.Bottom then
		targetNeighbor = Number3(0, -1, 0)
	elseif faceTouched == Face.Left then
		targetNeighbor = Number3(-1, 0, 0)
	elseif faceTouched == Face.Right then
		targetNeighbor = Number3(1, 0, 0)
	elseif faceTouched == Face.Front then
		targetNeighbor = Number3(0, 0, 1)
	elseif faceTouched == Face.Back then
		targetNeighbor = Number3(0, 0, -1)
	end
	return targetNeighbor
end

function savePOI()
    if poiActiveName == nil or poiActiveName == "" then
        return
    end

    -- body parts have a point stored in model space (block coordinates), where item must be attached
    -- we can use it to find the corresponding item block
	local worldBodyPoint = Number3(0, 0, 0)

	if poiActiveName == poiNameHand then
		worldBodyPoint = Player.RightHand:GetPoint(poiAvatarRightHandPalm).Position
		if worldBodyPoint == nil then
			-- default value
			worldBodyPoint = Player.RightHand:BlockToWorld(poiAvatarRightHandPalmDefaultValue)
		end
	elseif poiActiveName == poiNameHat then
		-- TODO: review this
		worldBodyPoint = Player.Head:GetPoint(poiNameHat).Position
		if worldBodyPoint == nil then
			-- default value
			worldBodyPoint = Player.Head:PositionLocalToWorld({ -0.5, 8.5, -0.5 })
		end
	elseif poiActiveName == poiNameBackpack then
		-- TODO: review this
		worldBodyPoint = Player.Body:GetPoint(poiNameBackpack).Position
		if worldBodyPoint == nil then
			 -- default value
			worldBodyPoint = Player.Body:PositionLocalToWorld({ 0.5, 2.5, -1.5 })
		end
	end

    -- item POI is stored in model space (block coordinates)
	local modelPoint = item:WorldToBlock(worldBodyPoint)

	-- Save new point coords/rotation
	item:AddPoint(poiActiveName, modelPoint, item.LocalRotation)

	changesSinceLastSave = false
	checkAutoSave()
end

clamp = function(v, min, max)
    if v < min then
        return min
    elseif v > max then
        return max
    else
        return v
    end
end

n3Equals = function(v1, v2, epsilon)
    return (v2 - v1).Length < epsilon
end

lerp = function(from, to, v)
    return from + (to - from) * clamp(v, 0.0, 1.0)
end

easingQuadOut = function(v)
    return 1.0 - (1.0 - v) * (1.0 - v);
end

------------
-- UI
------------

ui_config = {
	groupBackgroundColor = Color(0,0,0,150),
	padding = 6,
	btnColor = Color(120,120,120),
	btnColorSelected = Color(97,71,206),
	btnColorDisabled = Color(120,120,120,0.2),
	btnTextColorDisabled = Color(255,255,255,0.2),
	btnColorMode = Color(38,85,128),
	btnColorModeSelected = Color(75,128,192),
}

function ui_init()

	local padding = ui_config.padding
	local btnColor = ui_config.btnColor
	local btnColorSelected = ui_config.btnColorSelected
	local btnColorDisabled = ui_config.btnColorDisabled
	local btnTextColorDisabled = ui_config.btnTextColorDisabled
	local btnColorMode = ui_config.btnColorMode
	local btnColorModeSelected = ui_config.btnColorModeSelected

	function createButton(text, color, colorSelected)
		local btn = ui:createButton(text)
		btn:setColor(color, Color.White)
		btn:setColorSelected(colorSelected, Color.White)
		btn:setColorDisabled(btnColorDisabled, btnTextColorDisabled)
		return btn
	end

	LocalEvent:Listen("modeDidChange", function()
		 -- update pivot when switching from one mode to the other
		if not item:GetPoint("origin") then -- if not an equipment, update Pivot
			item.Pivot = Number3(item.Width / 2, item.Height / 2, item.Depth / 2)
		end
		if currentMode == mode.edit then
			editModeBtn:select()
			placeModeBtn:unselect()
			if orientationCube ~= nil then orientationCube:show() end
			editMenu:setParent(ui.rootFrame)
			editSubMenu:setParent(ui.rootFrame)
			recenterBtn:setParent(ui.rootFrame)
			placeMenu:setParent(nil)
			placeSubMenu:setParent(nil)
			placeGizmo:setObject(nil)

			palette:setParent(ui.rootFrame)
			if currentEditSubmode ~= editSubmode.mirror then
				removeMirror()
				mirrorControls:hide()
			end
			if currentEditSubmode ~= editSubmode.select then
				selectControls:hide()
			end
		else
			editModeBtn:unselect()
			placeModeBtn:select()
			if orientationCube ~= nil then orientationCube:hide() end
			editMenu:setParent(nil)
			editSubMenu:setParent(nil)
			recenterBtn:setParent(nil)
			placeMenu:setParent(ui.rootFrame)
			placeSubMenu:setParent(ui.rootFrame)
			palette:setParent(nil)
			colorPicker:setParent(nil)
			mirrorControls:hide()
			selectControls:hide()
			mirrorGizmo:setObject(nil)
			gizmo:setObject(nil)

			placeGizmo:setObject(item)
		end
	end)

	LocalEvent:Listen("modeOrSubmodeDidChange", function()
		refreshToolsDisplay()
		-- NOTE: it may not always be necessary to call these too,
		-- playing it safe, could be improved.
		Screen.DidResize()
		refreshDrawMode()
	end)

	-- MODE MENU (+ settings)

	modeMenu = ui:createFrame(ui_config.groupBackgroundColor)

	editModeBtn = createButton("✏️", btnColorMode, btnColorModeSelected)
	editModeBtn:setParent(modeMenu)
	editModeBtn.onRelease = function()
		setMode(mode.edit, nil)
	end
	editModeBtn:select()

	placeModeBtn = createButton("👤", btnColorMode, btnColorModeSelected)
	placeModeBtn:setParent(modeMenu)
	placeModeBtn.onRelease = function()
		setMode(mode.points, nil)
	end

	importBtn = createButton("📥", btnColor, btnColorSelected)
	importBtn:setParent(modeMenu)
	importBtn.onRelease = function()
		if confirmImportFrame then return end
		local frame = ui:createFrame(Color.Black)
		confirmImportFrame = frame
		local text = ui:createText("Importing a shape will replace the current item. If you want to keep this item, create a new one.", Color.White)
		text:setParent(frame)
		text.object.Anchor = { 0, 1 }
		local acceptImportBtn = createButton("Import", Color.Green)
		acceptImportBtn:setParent(frame)
		acceptImportBtn.onRelease = function()
			confirmImportFrame:remove()
			confirmImportFrame = nil
			replaceShapeWithImportedShape()
		end
		local cancelImportBtn = createButton("Cancel", Color.Red)
		cancelImportBtn:setParent(frame)
		cancelImportBtn.onRelease = function()
			confirmImportFrame:remove()
			confirmImportFrame = nil
		end
		frame.Width = 300
		text.object.MaxWidth = frame.Width - 10
		frame.Height = text.Height + 15 + acceptImportBtn.Height
		text.LocalPosition = Number3(5,frame.Height - 5,0)
		cancelImportBtn.LocalPosition = Number3(5,5,0)
		acceptImportBtn.LocalPosition = Number3(frame.Width - acceptImportBtn.Width - 5,5,0)
		frame.LocalPosition = Number3(Screen.Width / 2 - frame.Width / 2, Screen.Height / 2 - frame.Height / 2, 0)
	end

	replaceShapeWithImportedShape = function()
		if importBlocker then return end
		importBlocker = true

		File:OpenAndReadAll(function(success, fileData)
			importBlocker = false
			
			if not success or fileData == nil then return end

			if item ~= nil and item.Parent ~= nil then
				item:RemoveFromParent()
			end
			item = nil

			item = MutableShape(fileData) -- raises an error on failure / do not share palette colors
			item.History = true -- enable history for the edited item
			item:SetParent(World)

			customCollisionBox = nil
			if item.BoundingBox.Min ~= item.CollisionBox.Min and item.BoundingBox.Max ~= item.CollisionBox.Max then
				customCollisionBox = Box(item.CollisionBox.Min, item.CollisionBox.Max)
			end
		
			if currentEditSubmode == editSubmode.select then
				selectFocusShape(item)
			end

			initShapes()

			fitObjectToScreen(item)

			-- refresh UI
			gridEnabled = false
			refreshUndoRedoButtons()
			changesSinceLastSave = true

			blocksCounterNeedsRefresh = true
		end)
	end

	screenshotBtn = createButton("📷", btnColor, btnColorSelected)
	screenshotBtn:setParent(modeMenu)
	screenshotBtn.onRelease = function()
		if waitForScreenshot == true then return end
		waitForScreenshot = true

		local as = AudioSource()
		as.Sound = "gun_reload_1"
		as:SetParent(World)
		as.Volume = 0.5
	    as.Pitch = 1
	    as.Spatialized = false
	    as:Play()
		Timer(1, function() as:RemoveFromParent() as=nil end)

		local whiteBg = ui:createFrame(Color.White)
		whiteBg.Width = Screen.Width
		whiteBg.Height = Screen.Height

		Timer(0.05, function()
			whiteBg:remove()
			whiteBg = nil

			-- hide UI elements before screenshot

			local mirrorDisplayed = mirrorAnchor ~= nil and mirrorAnchor.IsHidden == false
			if mirrorDisplayed then mirrorAnchor.IsHidden = true end

			local placeGizmoObject
			if placeGizmo then
				placeGizmoObject = placeGizmo:getObject()
				placeGizmo:setObject(nil)
			end

	        local highlightHidden = blockHighlight.IsHidden
			blockHighlight.IsHidden = true

			local paletteIsVisible = palette:isVisible()
			palette:hide()

			ui.rootFrame:RemoveFromParent()
			if isWearable then
				Player.IsHidden = true
				for _,v in ipairs(copies) do
					v.IsHidden = true
				end	
			end

			local orientationCubeDisplayed = orientationCube and orientationCube:isVisible()
			if orientationCubeDisplayed then
				orientationCube:hide()
			end

			Timer(0.2, function()

				item:Capture(Environment.itemFullname)

				-- restore UI elements after screenshot

				if mirrorDisplayed then mirrorAnchor.IsHidden = false end
				
				if placeGizmo then placeGizmo:setObject(placeGizmoObject) end

				if paletteIsVisible then
					palette:show()
				end
				
				ui.rootFrame:SetParent(World)

				if orientationCubeDisplayed then orientationCube:show() end

				if isWearable then
					if currentWearablePreviewMode == wearablePreviewMode.fullBody then
						Player.IsHidden = false
					else -- hide player and toggle copies if not hide mode
						Player.IsHidden = true
						for _,v in ipairs(copies) do
							v.IsHidden = currentWearablePreviewMode == wearablePreviewMode.hide
						end	
					end
				end

				blockHighlight.IsHidden = highlightHidden

				waitForScreenshot = false
			end)
		end)
	end

	saveBtn = createButton("💾", btnColor, btnColorSelected)
	saveBtn:setParent(modeMenu)
	saveBtn.label = ui:createText("✅", Color.Black, {fontSize="small"})
	saveBtn.label:setParent(saveBtn)
	-- saveBtn.label.object.BackgroundColor = Color(0,0,0,200)

	saveBtn.onRelease = function()
		save()
	end

	if isWearable then
		placeModeBtn:disable()
		importBtn:disable()
	end

	modeMenu.parentDidResize = function(self)
		
		saveBtn.LocalPosition = {padding, padding, 0}
		saveBtn.label.pos = {saveBtn.Width - saveBtn.label.Width - 1, 1, 0}

		screenshotBtn.LocalPosition = {padding, saveBtn.LocalPosition.Y + saveBtn.Height + padding, 0}

		importBtn.LocalPosition = {padding, screenshotBtn.LocalPosition.Y + screenshotBtn.Height + padding, 0}
		placeModeBtn.LocalPosition = {padding, importBtn.LocalPosition.Y + importBtn.Height + padding, 0}
		editModeBtn.LocalPosition = {padding, placeModeBtn.LocalPosition.Y + placeModeBtn.Height, 0}
		
		w, h = computeContentSize(self)
		self.Width = w + padding * 2
		self.Height = h + padding * 2
		self.LocalPosition = {padding + Screen.SafeArea.Left, Screen.Height - self.Height - padding - Screen.SafeArea.Top, 0}

		if visibilityMenu ~= nil then 
			visibilityMenu:refresh()
		end
	end

	modeMenu:parentDidResize()

	-- CAMERA CONTROLS

	recenterBtn = createButton("🎯", btnColor, btnColorSelected)
	recenterBtn.onRelease = function()
		if currentMode == mode.edit then
            fitObjectToScreen(item, nil)
            if cameraFree == false then
                blockHighlightDirty = true
            end
        else
            setSatelliteCamera(cameraStartPreviewRotation, nil, cameraStartPreviewDistance, false)
        end
	end

	recenterBtn.place = function(self)
		self.LocalPosition = {editSubMenu.LocalPosition.X + editSubMenu.Width - self.Width * 3 - padding * 2,
									editSubMenu.LocalPosition.Y - self.Height - padding, 0}
	end

	-- EDIT MENU

    editMenu = ui:createFrame(ui_config.groupBackgroundColor)
    editMenuToggleBtns = {}
    editMenuToggleSelected = nil
    function editMenuToggleSelect(target)
    	for _,btn in ipairs(editMenuToggleBtns) do btn:unselect() end
		target:select()
		editMenuToggleSelected = target
    end

	addBlockBtn = createButton("➕", btnColor, btnColorSelected)
	table.insert(editMenuToggleBtns, addBlockBtn)
	addBlockBtn:setParent(editMenu)
	addBlockBtn.onRelease = function()
		editMenuToggleSelect(addBlockBtn)
		setMode(nil, editSubmode.add)
	end
	editMenuToggleSelect(addBlockBtn)

	removeBlockBtn = createButton("➖", btnColor, btnColorSelected)
	table.insert(editMenuToggleBtns, removeBlockBtn)
	removeBlockBtn:setParent(editMenu)
	removeBlockBtn.onRelease = function()
		editMenuToggleSelect(removeBlockBtn)
		setMode(nil, editSubmode.remove)
	end

	replaceBlockBtn = createButton("🖌️", btnColor, btnColorSelected)
	table.insert(editMenuToggleBtns, replaceBlockBtn)
	replaceBlockBtn:setParent(editMenu)
	replaceBlockBtn.onRelease = function()
		editMenuToggleSelect(replaceBlockBtn)
		setMode(nil, editSubmode.paint)
	end

	selectShapeBtn = createButton("►", btnColor, btnColorSelected)
	table.insert(editMenuToggleBtns, selectShapeBtn)
	selectShapeBtn:setParent(editMenu)
	selectShapeBtn.onRelease = function()
		editMenuToggleSelect(selectShapeBtn)
		setMode(nil, editSubmode.select)
	end

	mirrorBtn = createButton("🪞", btnColor, btnColorSelected)
	table.insert(editMenuToggleBtns, mirrorBtn)
	mirrorBtn:setParent(editMenu)
	mirrorBtn.onRelease = function()
		editMenuToggleSelect(mirrorBtn)
		setMode(nil, editSubmode.mirror)
	end
	if isWearable then
		mirrorBtn:disable()
		selectShapeBtn:disable()
	end

	pickColorBtn = createButton("🧪", btnColor, btnColorSelected)
	table.insert(editMenuToggleBtns, pickColorBtn)
	pickColorBtn:setParent(editMenu)
	pickColorBtn.onRelease = function()
		if currentEditSubmode == editSubmode.pick then return end
		prePickSelectedBtn = editMenuToggleSelected
		prePickEditSubmode = currentEditSubmode
		editMenuToggleSelect(pickColorBtn)
		setMode(nil, editSubmode.pick)
	end

	paletteBtn = createButton("🎨", btnColor, btnColorSelected)
	paletteBtn:setParent(editMenu)
	paletteBtn.onRelease = function()
		paletteDisplayed = not paletteDisplayed
		refreshToolsDisplay()
	end

	LocalEvent:Listen("selectedColorDidChange", function()
		paletteBtn:setColor(palette:getCurrentColor())
	end)

	editMenu.parentDidResize = function(self)
		addBlockBtn.LocalPosition = {padding, padding, 0}
		removeBlockBtn.LocalPosition = {addBlockBtn.LocalPosition.X + addBlockBtn.Width, padding, 0}
		replaceBlockBtn.LocalPosition = {removeBlockBtn.LocalPosition.X + removeBlockBtn.Width, padding, 0}
		selectShapeBtn.LocalPosition = {replaceBlockBtn.LocalPosition.X + replaceBlockBtn.Width, padding, 0}
		mirrorBtn.LocalPosition = {selectShapeBtn.LocalPosition.X + selectShapeBtn.Width + padding, padding, 0}
		
		pickColorBtn.LocalPosition = {mirrorBtn.LocalPosition.X + mirrorBtn.Width + padding, padding, 0}
		paletteBtn.LocalPosition = {pickColorBtn.LocalPosition.X + pickColorBtn.Width + padding, padding, 0}

		w, h = computeContentSize(self)
		self.Width = w + padding * 2
		self.Height = h + padding * 2
		self.LocalPosition = {Screen.Width - self.Width - padding - Screen.SafeArea.Right, padding + Screen.SafeArea.Bottom, 0}
	end

	editMenu:parentDidResize()

	-- EDIT SUB MENU

	editSubMenu = ui:createFrame(ui_config.groupBackgroundColor)

	oneBlockBtn = createButton("⚀", btnColor, btnColorSelected)
	oneBlockBtn:setParent(editSubMenu)
	oneBlockBtn.onRelease = function()
		oneBlockBtn:select()
		faceModeBtn:unselect()
		setFacemode(false)
	end
	oneBlockBtn:select()

	faceModeBtn = createButton("⚅", btnColor, btnColorSelected)
	faceModeBtn:setParent(editSubMenu)
	faceModeBtn.onRelease = function()
		oneBlockBtn:unselect()
		faceModeBtn:select()
		setFacemode(true)
	end

	redoBtn = createButton("↩️", btnColor, btnColorSelected)
	redoBtn:setParent(editSubMenu)
	redoBtn.onRelease = function()
		local lastRedoableShape = redoShapesStack[#redoShapesStack]
		if lastRedoableShape ~= nil and lastRedoableShape.CanRedo then
			lastRedoableShape:Redo()
			table.insert(undoShapesStack, lastRedoableShape)
			table.remove(redoShapesStack, #redoShapesStack)
			updateMirror()
			checkAutoSave()
			refreshUndoRedoButtons()
			blocksCounterNeedsRefresh = true
		end
	end

	undoBtn = createButton('↪️', btnColor, btnColorSelected)
	undoBtn:setParent(editSubMenu)
	undoBtn.onRelease = function()
		local lastUndoableShape = undoShapesStack[#undoShapesStack]
		if lastUndoableShape ~= nil and lastUndoableShape.CanUndo then
			lastUndoableShape:Undo()
			table.remove(undoShapesStack, #undoShapesStack)
			table.insert(redoShapesStack, lastUndoableShape)
			updateMirror()
			checkAutoSave()
			refreshUndoRedoButtons()
			blocksCounterNeedsRefresh = true
		end
	end

	gridEnabled = false
	gridBtn = createButton("𐄳", btnColor, btnColorSelected)
	gridBtn:setParent(editSubMenu)
	gridBtn.onRelease = function()
		gridEnabled = not gridEnabled
		if gridEnabled then gridBtn:select() else gridBtn:unselect() end
		refreshDrawMode()
	end

	editSubMenu.parentDidResize = function(self)
		redoBtn.LocalPosition = {padding, padding, 0}
		undoBtn.LocalPosition = {redoBtn.LocalPosition.X + redoBtn.Width, padding, 0}

		oneBlockBtn.LocalPosition = {undoBtn.LocalPosition.X + undoBtn.Width + padding, padding, 0}
		faceModeBtn.LocalPosition = {oneBlockBtn.LocalPosition.X + oneBlockBtn.Width, padding, 0}

		gridBtn.LocalPosition = {faceModeBtn.LocalPosition.X + faceModeBtn.Width + padding, padding, 0}

		w, h = computeContentSize(self)
		self.Width = w + padding * 2
		self.Height = h + padding * 2
		self.LocalPosition = {Screen.Width - self.Width - padding - Screen.SafeArea.Right, Screen.Height - self.Height - padding - Screen.SafeArea.Top, 0}

		if recenterBtn ~= nil then recenterBtn:place() end
	end

	editSubMenu:parentDidResize()

	-- PLACE MENU

	placeMenu = ui:createFrame(ui_config.groupBackgroundColor)
	placeMenuToggleBtns = {}
	function placeMenuToggleSelect(target)
		for _,btn in ipairs(placeMenuToggleBtns) do btn:unselect() end
		target:select()
	end

	placeInHandBtn = createButton("✋", btnColor, btnColorSelected)
	table.insert(placeMenuToggleBtns, placeInHandBtn)
	placeInHandBtn:setParent(placeMenu)
	placeInHandBtn.onRelease = function()
		placeMenuToggleSelect(placeInHandBtn)
		poiActiveName = poiNameHand
		Player:EquipHat(nil)
		Player:EquipBackpack(nil)
		Player:EquipRightHand(item)
	end
	placeInHandBtn:select()

	placeAsHat = createButton("🤠", btnColor, btnColorSelected)
	table.insert(placeMenuToggleBtns, placeAsHat)
	placeAsHat:setParent(placeMenu)
	placeAsHat.onRelease = function()
		placeMenuToggleSelect(placeAsHat)
		poiActiveName = poiNameHat
		Player:EquipRightHand(nil)
		Player:EquipBackpack(nil)
		Player:EquipHat(item)
	end

	placeAsBackpack = createButton("🎒", btnColor, btnColorSelected)
	table.insert(placeMenuToggleBtns, placeAsBackpack)
	placeAsBackpack:setParent(placeMenu)
	placeAsBackpack.onRelease = function()
		placeMenuToggleSelect(placeAsBackpack)
		poiActiveName = poiNameBackpack
		Player:EquipRightHand(nil)
		Player:EquipHat(nil)
		Player:EquipBackpack(item)
	end

	placeMenu.parentDidResize = function(self)
		placeInHandBtn.LocalPosition = {padding, padding, 0}
		placeAsHat.LocalPosition = {placeInHandBtn.LocalPosition.X + placeInHandBtn.Width, padding, 0}
		placeAsBackpack.LocalPosition = {placeAsHat.LocalPosition.X + placeAsHat.Width, padding, 0}

		w, h = computeContentSize(self)
		self.Width = w + padding * 2
		self.Height = h + padding * 2
		self.LocalPosition = {Screen.Width - self.Width - padding - Screen.SafeArea.Right, padding + Screen.SafeArea.Bottom, 0}

		if placeSubMenu ~= nil then placeSubMenu:place() end
	end

	placeMenu:parentDidResize()

	-- MIRROR MENU
	mirrorControls = ui:createFrame(ui_config.groupBackgroundColor)
	mirrorControls:hide()

	mirrorGizmo = require("gizmo"):create()
	mirrorGizmo:setLayer(4)
	mirrorGizmo:setGizmoScale(0.2)
	mirrorGizmo:setMode(mirrorGizmo.Mode.Move)
	mirrorGizmo:setSnap(mirrorGizmo.Mode.Move, 0.5)

	rotateMirrorBtn = createButton("↻", ui_config.btnColor, ui_config.btnColorSelected)
	rotateMirrorBtn:setParent(mirrorControls)
	rotateMirrorBtn.onRelease = function()
		currentMirrorAxis = currentMirrorAxis + 1
		if currentMirrorAxis > mirrorAxes.z then
			currentMirrorAxis = mirrorAxes.x
		end
		updateMirror()
	end

	removeMirrorBtn = createButton("❌", ui_config.btnColor, ui_config.btnColorSelected)
	removeMirrorBtn:setParent(mirrorControls)
	removeMirrorBtn.onRelease = function()
		removeMirror()
		placeMirrorText:show()
		rotateMirrorBtn:hide()
		removeMirrorBtn:hide()
		mirrorControls.Width = placeMirrorText.Width + ui_config.padding * 2
		mirrorControls.LocalPosition = {Screen.Width - mirrorControls.Width - ui_config.padding, editMenu.Height + 2 * ui_config.padding, 0}
	end

	placeMirrorText = ui:createText("Click on shape to place mirror.", Color.White)
	placeMirrorText:setParent(mirrorControls)

	rotateMirrorBtn:hide()
	removeMirrorBtn:hide()

	mirrorControls.parentDidResize = function()
		placeMirrorText.LocalPosition = Number3(ui_config.padding, editMenu.Height / 2 - placeMirrorText.Height / 2, 0)
		rotateMirrorBtn.LocalPosition = Number3(ui_config.padding, ui_config.padding, 0)
		removeMirrorBtn.LocalPosition = rotateMirrorBtn.LocalPosition + Number3(rotateMirrorBtn.Width + ui_config.padding, 0, 0)
	
		if placeMirrorText:isVisible() then
			mirrorControls.Width = placeMirrorText.Width + ui_config.padding * 2
		else
			mirrorControls.Width = ui_config.padding + (rotateMirrorBtn.Width + ui_config.padding) * 2
		end
		mirrorControls.Height = ui_config.padding * 2 + rotateMirrorBtn.Height
		mirrorControls.LocalPosition = {Screen.Width - mirrorControls.Width - ui_config.padding, editMenu.Height + 2 * ui_config.padding, 0}	
	end
	mirrorControls:parentDidResize()

	-- SELECT MENU
	selectControls = ui:createFrame(ui_config.groupBackgroundColor)
	selectControls:hide()

	selectToggleBtns = {}
	function selectToggleBtnsSelect(target)
		for _,btn in ipairs(selectToggleBtns) do btn:unselect() end
		if target then
			target:select()
		end
	end

	-- TODO: rename selectGizmo and handle 3 gizmos in array for input
	gizmo = require("gizmo"):create()
	gizmo.snap = 0
	gizmo:setGizmoScale(0.2)
	gizmo:setLayer(4)
	gizmo:setOrientation(gizmo.Orientation.Local)

	-- Snap to grid 0.5 for movement
	gizmo:setSnap(gizmo.Mode.Move, 0.5)

	addChild = ui:createText("Add shape", Color.White)
	addChild:setParent(selectControls)

	addBlockChildBtn = createButton("⚀", ui_config.btnColor, ui_config.btnColorSelected)
	addBlockChildBtn:setParent(selectControls)
	addBlockChildBtn.onRelease = function()
		if countTotalNbShapes() >= max_total_nb_shapes then
			print(string.format("Error: item can't have more than %d shapes.", max_total_nb_shapes))
			return
		end
		local s = MutableShape()
		s.History = true -- enable history for the edited item
		s:AddBlock(palette:getCurrentColor(),0,0,0)
		s.Pivot = Number3(0.5,0.5,0.5)
		s:SetParent(focusShape)
		-- Spawn next to the parent
		s.Position = focusShape.Position - Number3(focusShape.Width / 2 + 2, 0, 0)
		table.insert(shapes, s)
		selectFocusShape(s)
	end

	importChildBtn = createButton("📥 Import", ui_config.btnColor, ui_config.btnColorSelected)
	importChildBtn:setParent(selectControls)
	importChildBtn.onRelease = function()
		if countTotalNbShapes() >= max_total_nb_shapes then
			print(string.format("Error: item can't have more than %d shapes.", max_total_nb_shapes))
			return
		end

		if importBlocker then return end
		importBlocker = true

		File:OpenAndReadAll(function(success, fileData)
			importBlocker = false

			if not success or fileData == nil then return end

			child = MutableShape(fileData) -- raises an error on failure / do not share palette colors
			child:SetParent(focusShape)

			-- Spawn next to the parent
			child.Position = child.Position - Number3(focusShape.Width / 2 + child.Width * 2, 0, 0)

			hierarchyActions:applyToDescendants(child, { includeRoot = true }, function(s)
				s.History = true -- enable history for the edited item
				table.insert(shapes, s)
			end)

			selectFocusShape(child)

			-- refresh UI
			gridEnabled = false
			refreshUndoRedoButtons()
			changesSinceLastSave = true

			blocksCounterNeedsRefresh = true
		end)
	end

	removeShapeBtn = createButton("➖ Remove Shape", ui_config.btnColor, ui_config.btnColorSelected)
	removeShapeBtn:setParent(selectControls)
	removeShapeBtn.onRelease = function()
		if not focusShape then return end
		for k,s in ipairs(shapes) do
			if s == focusShape then
				table.remove(shapes,k)
			end
		end
		focusShape:RemoveFromParent()
		selectFocusShape()
		removeShapeBtn:hide()
	end

	moveShapeBtn = createButton("⇢", ui_config.btnColor, ui_config.btnColorSelected)
	moveShapeBtn:setParent(selectControls)
	table.insert(selectToggleBtns, moveShapeBtn)
	moveShapeBtn.onRelease = function()
		if gizmo.object and gizmo.mode == gizmo.Mode.Move then
			selectToggleBtnsSelect(nil)
			gizmo:setObject(nil)
		else
			selectToggleBtnsSelect(moveShapeBtn)
			gizmo:setObject(focusShape)
			gizmo:setMode(gizmo.Mode.Move)
		end
	end

	rotateShapeBtn = createButton("↻", ui_config.btnColor, ui_config.btnColorSelected)
	rotateShapeBtn:setParent(selectControls)
	table.insert(selectToggleBtns, rotateShapeBtn)
	rotateShapeBtn.onRelease = function()
		if gizmo.object and gizmo.mode == gizmo.Mode.Rotate then
			selectToggleBtnsSelect(nil)
			gizmo:setObject(nil)
		else
			selectToggleBtnsSelect(rotateShapeBtn)
			gizmo:setObject(focusShape)
			gizmo:setMode(gizmo.Mode.Rotate)
		end
	end

	selectShapeText = ui:createText("or Select a shape.", Color.White)
	selectShapeText:setParent(selectControls)

	-- Update Collision Box Menu
	updateCollider = function()
		local minPos = colliderMinObject.Position - item:BlockToWorld(0,0,0)
		local maxPos = colliderMaxObject.Position - item:BlockToWorld(0,0,0)
		customCollisionBox = Box(minPos, maxPos)
		collider:resize(customCollisionBox.Max - customCollisionBox.Min)
		collider.Position = item:BlockToWorld(customCollisionBox.Min) - Number3(0.125,0.125,0.125)
		checkAutoSave()
	end

	setColliderBtn = createButton("Set Collision Box", ui_config.btnColor, ui_config.btnColorSelected)
	setColliderBtn:setParent(selectControls)
	setColliderBtn.onRelease = function()
		selectControls:hide()

		collisionBoxMenu:parentDidResize()
		collisionBoxMenu:show()

		if not customCollisionBox then
			customCollisionBox = Box(item.CollisionBox.Min, item.CollisionBox.Max)
		end
		if collider then
			collider:RemoveFromParent()
		end
		collider = box_outline:create(customCollisionBox.Max - customCollisionBox.Min, 0.25)
		collider:SetParent(World)
		collider.Position = item:BlockToWorld(customCollisionBox.Min) - Number3(0.125,0.125,0.125)

		if not colliderMinObject then
			colliderMinObject = Object()
			colliderMinObject:SetParent(World)
			colliderMaxObject = Object()
			colliderMaxObject:SetParent(World)
		end
		colliderMinObject.Position = item:BlockToWorld(customCollisionBox.Min)
		colliderMinGizmo:setObject(colliderMinObject)
		colliderMaxObject.Position = item:BlockToWorld(customCollisionBox.Max)
		colliderMaxGizmo:setObject(colliderMaxObject)
	end

	collisionBoxMenu = ui:createFrame(ui_config.groupBackgroundColor)
	collisionBoxMenu:hide()

	editingCollisionBoxText = ui:createText("Editing Collision Box...", Color.White)
	editingCollisionBoxText:setParent(collisionBoxMenu)

	confirmColliderBtn = createButton("✅", ui_config.btnColor, ui_config.btnColorSelected)
	confirmColliderBtn:setParent(collisionBoxMenu)
	confirmColliderBtn.onRelease = function()
		if not collider then return end
		collisionBoxMenu:hide()
		selectControls:show()
		collider:RemoveFromParent()
		collider = nil
		colliderMinGizmo:setObject(nil)
		colliderMaxGizmo:setObject(nil)
	end

	collisionBoxMenu.parentDidResize = function()
		collisionBoxMenu.Width = editingCollisionBoxText.Width + confirmColliderBtn.Width + padding * 3
		collisionBoxMenu.Height = editMenu.Height
		editingCollisionBoxText.LocalPosition = Number3(padding, collisionBoxMenu.Height / 2 - editingCollisionBoxText.Height / 2, 0)
		confirmColliderBtn.LocalPosition = Number3(editingCollisionBoxText.Width + 2 * padding, padding, 0)
		collisionBoxMenu.LocalPosition = Number3(Screen.Width - padding - collisionBoxMenu.Width, editMenu.Height + 2 * padding, 0)
	end

	selectControlsRefresh = function()
		if currentEditSubmode ~= editSubmode.select then return end

		if not currentEditSubmode or not focusShape then
			selectShapeText:show()
			setColliderBtn:show()
			addChild:hide()
			addBlockChildBtn:hide()
			importChildBtn:hide()
			removeShapeBtn:hide()
			moveShapeBtn:hide()
			rotateShapeBtn:hide()
			selectControls:parentDidResize()
			return
		end

		selectShapeText:hide()
		setColliderBtn:hide()

		addChild:show()
		addBlockChildBtn:show()
		importChildBtn:show()

		-- if root, can't remove, move or rotate
		local funcSubShapesControls = focusShape == item and "hide" or "show"
		if funcSubShapesControls == "show" then
			-- gizmo:setObject(focusShape)
			if gizmo.mode == gizmo.Mode.Move then
				selectToggleBtnsSelect(moveShapeBtn)
			else
				selectToggleBtnsSelect(rotateShapeBtn)
			end
		end
		removeShapeBtn[funcSubShapesControls](removeShapeBtn)
		moveShapeBtn[funcSubShapesControls](moveShapeBtn)
		rotateShapeBtn[funcSubShapesControls](rotateShapeBtn)

		selectControls:parentDidResize()
	end

	selectControls.parentDidResize = function()
		local padding = ui_config.padding
		selectShapeText.LocalPosition = Number3(padding * 1.5, editMenu.Height / 2 - selectShapeText.Height / 2, 0)
		setColliderBtn.LocalPosition = Number3(padding, addBlockChildBtn.Height + 2 * padding, 0)
		addChild.LocalPosition = Number3(padding, editMenu.Height / 2 - selectShapeText.Height / 2, 0)
		addBlockChildBtn.LocalPosition = Number3(addChild.LocalPosition.X + addChild.Width + padding, padding, 0)
		importChildBtn.LocalPosition = Number3(addBlockChildBtn.LocalPosition.X + addBlockChildBtn.Width + padding, addBlockChildBtn.LocalPosition.Y, 0)
		moveShapeBtn.LocalPosition = Number3(padding, addBlockChildBtn.LocalPosition.Y + addBlockChildBtn.Height + padding, 0)
		rotateShapeBtn.LocalPosition = Number3(moveShapeBtn.LocalPosition.X + moveShapeBtn.Width, moveShapeBtn.LocalPosition.Y, 0)
		removeShapeBtn.LocalPosition = Number3(rotateShapeBtn.LocalPosition.X + rotateShapeBtn.Width + padding, rotateShapeBtn.LocalPosition.Y, 0)

		local width = 0
		local height = padding
		if selectShapeText:isVisible() then
			width = math.max(width, setColliderBtn.Width)
			height = height + (addBlockChildBtn.Height + padding) * 2
		end
		if addBlockChildBtn:isVisible() then
			width = math.max(width,addChild.Width + padding + importChildBtn.Width + padding + addBlockChildBtn.Width)
			height = height + addBlockChildBtn.Height + padding
		end
		if moveShapeBtn:isVisible() then
			width = math.max(width,removeShapeBtn.Width + moveShapeBtn.Width + rotateShapeBtn.Width + padding)
			height = height + moveShapeBtn.Height + padding
		end

		width = width + 2 * padding
		selectControls.Width = width
		selectControls.Height = height
		selectControls.LocalPosition = { Screen.Width - selectControls.Width - padding, editMenu.Height + 2 * padding, 0 }
	end
	selectControlsRefresh()

	-- PLACE SUB MENU

	placeSubMenu = ui:createFrame(ui_config.groupBackgroundColor)
	placeSubMenuToggleBtns = {}
	function placeSubMenuToggleSelect(target)
		for _,btn in ipairs(placeSubMenuToggleBtns) do btn:unselect() end
		if target then
			target:select()		
		end
	end

	placeGizmo = require("gizmo"):create()
	placeGizmo:setLayer(4)
	placeGizmo:setGizmoScale(0.3)
	placeGizmo:setOrientation(placeGizmo.Orientation.Local)
	placeGizmo._gizmos[placeGizmo.Mode.Move].onDrag = function()
		savePOI()
	end
	placeGizmo._gizmos[placeGizmo.Mode.Rotate].onDrag = function()
		savePOI()
	end

	moveBtn = createButton("⇢", btnColor, btnColorSelected)
	table.insert(placeSubMenuToggleBtns, moveBtn)
	moveBtn:setParent(placeSubMenu)
	moveBtn.onRelease = function()
		setMode(nil, pointsSubmode.move)
		if placeGizmo.object and placeGizmo.mode == placeGizmo.Mode.Move then
			placeSubMenuToggleSelect(nil)
			placeGizmo:setObject(nil)
		else
			placeSubMenuToggleSelect(moveBtn)
			placeGizmo:setObject(item)
			placeGizmo:setMode(placeGizmo.Mode.Move)
			placeGizmo:setSnap(placeGizmo.Mode.Move, 0.5)
		end
	end
	moveBtn:select()
	placeGizmo:setMode(placeGizmo.Mode.Move)
	placeGizmo:setSnap(placeGizmo.Mode.Move, 0.5)

	rotateBtn = createButton("↻", btnColor, btnColorSelected)
	table.insert(placeSubMenuToggleBtns, rotateBtn)
	rotateBtn:setParent(placeSubMenu)
	rotateBtn.onRelease = function()
		setMode(nil, pointsSubmode.rotate)
		if placeGizmo.object and placeGizmo.mode == placeGizmo.Mode.Rotate then
			placeSubMenuToggleSelect(nil)
			placeGizmo:setObject(nil)
		else
			placeSubMenuToggleSelect(rotateBtn)
			placeGizmo:setObject(item)
			placeGizmo:setMode(placeGizmo.Mode.Rotate)
			placeGizmo:setSnap(placeGizmo.Mode.Rotate, math.pi / 16)
		end
	end

	resetBtn = createButton("Reset", btnColor, btnColorSelected)
	resetBtn:setParent(placeSubMenu)
	resetBtn.onRelease = function()
		item:AddPoint(poiActiveName)
		
		if poiActiveName == poiNameHand then
			Player:EquipRightHand(item)
		elseif poiActiveName == poiNameHat then
			Player:EquipHat(item)
		elseif poiActiveName == poiNameBackpack then
			Player:EquipBackpack(item)
		end
	end

	placeSubMenu.place = function(self)
		moveBtn.LocalPosition = {padding, padding, 0}
		rotateBtn.LocalPosition = {moveBtn.LocalPosition.X + moveBtn.Width, padding, 0}
		resetBtn.LocalPosition = {rotateBtn.LocalPosition.X + rotateBtn.Width + padding, padding, 0}

		w, h = computeContentSize(self)
		self.Width = w + padding * 2
		self.Height = h + padding * 2
		self.LocalPosition = {Screen.Width - self.Width - padding - Screen.SafeArea.Right, placeMenu.LocalPosition.Y + placeMenu.Height + padding, 0}
	end

	placeSubMenu:place()
end -- ui_init end

function computeContentSize(self)
	return computeContentWidth(self), computeContentHeight(self)
end

function computeContentHeight(self)
	local max = nil
	local min = nil
	for _, child in pairs(self.children) do
		if child:isVisible() then
			if min == nil or min > child.LocalPosition.Y then min = child.LocalPosition.Y end
			if max == nil or max < child.LocalPosition.Y + child.Height then max = child.LocalPosition.Y + child.Height end
		end
	end
	if max == nil then return 0 end
	return max - min
end

function computeContentWidth(self)
	local max = nil
	local min = nil
	for _, child in pairs(self.children) do
		if child:isVisible() then
			if min == nil or min > child.LocalPosition.X then min = child.LocalPosition.X end
			if max == nil or max < child.LocalPosition.X + child.Width then max = child.LocalPosition.X + child.Width end
		end
	end
	if max == nil then return 0 end
	return max - min
end

function post_item_load()

	initClientFunctions()
	setFacemode(false)
	refreshUndoRedoButtons()

	-- gizmos
	orientationCube = require("orientationcube.lua")
	orientationCube:init()
	orientationCube:setLayer(6)

	fitObjectToScreen(item, cameraStartRotation)

	refreshBlockHighlight()
	cameraStateSave()

	setCameraRotation(cameraThumbnailRotation)

	initShapes = function()
		shapes = {}
		hierarchyActions:applyToDescendants(item,  { includeRoot = true }, function(s)
			s.History = true -- enable history for the edited item
			table.insert(shapes, s)
		end)
	end

	-- Shapes array
	initShapes()

	local SHOW_FOCUS_MODE_BUTTONS = false
	if SHOW_FOCUS_MODE_BUTTONS then
		-- Focus mode buttons
		x = Screen.Width - 205
		y = Screen.Height / 2 - 100
		local toggleFocusBtns = {}
		for i=1,focusMode.max do
			local btn = ui:createButton(200,50)
			btn.LocalPosition = Number3(x, y - (i - 1) * 55, 0)
			btn.Text = focusModeName[i]
			btn.onRelease = function()
				if not focusShape then return end
				if i == focusMode.othersVisible then
					setSelfAndDescendantsHiddenSelf(item, false)
					refreshDrawMode()
				elseif i == focusMode.othersTransparent then
					setSelfAndDescendantsHiddenSelf(item, false)
					refreshDrawMode()
					focusShape.PrivateDrawMode = 0
				elseif i == focusMode.othersHidden then
					setSelfAndDescendantsHiddenSelf(item, true)
					focusShape.IsHiddenSelf = false
				end
			end
			table.insert(toggleFocusBtns, btn)
		end
		local toggleFocusMode = ui:createToggle(toggleFocusBtns)
		selectFocusShape(item)
	end

	local colorPickerConfig = {
		closeBtnColor = ui_config.btnColor,
		extraPadding = true,
	}
	colorPicker = colorPickerModule:create(colorPickerConfig)
	colorPicker:hide()

	palette = require("palette"):create(ui, ui_config.btnColor)

	prevColor = nil
	colorPicker.didPickColor = function(self, color)
		if prevColor then
			if prevColor == color then
				-- selecting same color, nothing to do
				return
			end
			-- check if new color is not already use in shape
			local colorAlreadyUsed = false
			hierarchyActions:applyToDescendants(item, { includeRoot = true }, function(s)
				local index = s.Palette:GetIndex(color)
				if index ~= nil then
					if s.Palette[index].BlocksCount > 0 then
						colorAlreadyUsed = true
					end
				end
			end)
			if colorAlreadyUsed then
				colorPicker:setColor(prevColor)
				print("⚠️ You can't replace a color with a color already in the shape.")	
				return
			end

			local refreshAlpha = color.A ~= prevColor.A
			hierarchyActions:applyToDescendants(item, { includeRoot = true }, function(s)
				for i=1,#s.Palette do
					if s.Palette[i].Color == prevColor then
						s.Palette[i].Color = color
					end
				end
				if refreshAlpha then
					s:RefreshModel()
				end
			end)
			checkAutoSave()
		end
		palette:setSelectedColor(color)
	end

	colorPicker.didClose = function()
		colorPickerDisplayed = false
	end

	palette.didAdd = function(self, color)
		colorPicker:setColor(color)
		if not colorPickerDisplayed then
			colorPickerDisplayed = true
			refreshToolsDisplay()
		end
		prevColor = color
		checkAutoSave()
		updatePalettePosition()
	end

	palette.didRefresh = function(self)
		updatePalettePosition()
	end

	palette.didChangeSelection = function(self, color)
		LocalEvent:Send("selectedColorDidChange")
		colorPicker:setColor(color)
		prevColor = color
	end
	palette.requiresEdit = function(self, _, color)
		colorPickerDisplayed = not colorPickerDisplayed
		if colorPickerDisplayed then
			colorPicker:setColor(color)
			prevColor = color
		end
		refreshToolsDisplay()
	end

	updatePalettePosition = function()
		palette.LocalPosition = {Screen.Width - palette.Width - ui_config.padding - Screen.SafeArea.Left, editMenu.LocalPosition.Y + editSubMenu.Height + ui_config.padding, 0}	
		colorPicker.LocalPosition = Number3(palette.LocalPosition.X - colorPicker.Width - ui_config.padding, palette.LocalPosition.Y, 0)
	end

	if itemPalette ~= nil then
		palette:setColors(itemPalette)
	end

	LocalEvent:Send("selectedColorDidChange")
	updatePalettePosition()

	setMode(mode.edit, editSubmode.add)
	Screen.DidResize()

	countTotalNbShapes = function()
		local nbShapes = 0
		hierarchyActions:applyToDescendants(item, { includeRoot = true }, function(s)
			nbShapes = nbShapes + 1
		end)
		return nbShapes
	end

	LocalEvent:listen(LocalEvent.Name.AvatarLoaded, function()
		-- if equipment, show preview buttons
		if not isWearable then return end
		-- T-pose
		for _,p in ipairs(bodyParts) do
			if p == "RightArm" or p == "LeftArm" or p == "RightHand" or p == "LeftHand" then
				Player[p].Rotation = Number3(0,0,0)
			end
			Player[p].IgnoreAnimations = true
			Player[p].Physics = PhysicsMode.Trigger
		end
		for key,shape in pairs(Player.equipments) do
			shape.Physics = PhysicsMode.Trigger
			for _,s in ipairs(shape.attachedParts or {}) do
				s.Physics = PhysicsMode.Trigger
			end
		end

		-- Remove Equipments
		Player.equipments = Player.equipments or {}
		if Player.equipments[itemCategory] then
			local shape = Player.equipments[itemCategory]
			for _,s in ipairs(shape.attachedParts or {}) do
				s:RemoveFromParent()
			end
			shape:RemoveFromParent()
		end

		copies = {}

		visibilityMenu = ui:createFrame(ui_config.groupBackgroundColor)

		local onlyItemBtn = ui:createButton("⚅")
		local itemPlusBodyPartBtn = ui:createButton("✋")
		local itemPlusAvatarBtn = ui:createButton("👤")

		onlyItemBtn:setParent(visibilityMenu)
		onlyItemBtn.onRelease = function(btn)

			onlyItemBtn:select()
			itemPlusBodyPartBtn:unselect()
			itemPlusAvatarBtn:unselect()

			currentWearablePreviewMode = wearablePreviewMode.hide
			updateWearableSubShapesPosition()
			Player.IsHidden = true
			for _,v in ipairs(copies) do
				v.IsHidden = true
			end
		end

		itemPlusBodyPartBtn:setParent(visibilityMenu)
		itemPlusBodyPartBtn.onRelease = function(btn)

			onlyItemBtn:unselect()
			itemPlusBodyPartBtn:select()
			itemPlusAvatarBtn:unselect()

			currentWearablePreviewMode = wearablePreviewMode.bodyPart
			updateWearableSubShapesPosition()
			Player.IsHidden = true
			if #copies > 0 then
				for _,v in ipairs(copies) do
					v.IsHidden = false
				end	
				return
			end
			local parent = __equipments.equipmentParent(Player, itemCategory)
			if type(parent) == "table" then
				for _,p in ipairs(parent) do
					local copy = Shape(p)
					copy:SetParent(World)
					copy.Physics = PhysicsMode.Trigger
					copy.Position = p.Position
					copy.Rotation = p.Rotation
					table.insert(copies, copy)
				end
			else
				local copy = Shape(parent)
				copy:SetParent(World)
				copy.Physics = PhysicsMode.Trigger
				copy.Position = parent.Position
				copy.Rotation = parent.Rotation
				table.insert(copies, copy)
			end
		end

		itemPlusAvatarBtn:setParent(visibilityMenu)
		itemPlusAvatarBtn.onRelease = function(btn)
			
			onlyItemBtn:unselect()
			itemPlusBodyPartBtn:unselect()
			itemPlusAvatarBtn:select()

			currentWearablePreviewMode = wearablePreviewMode.fullBody
			updateWearableSubShapesPosition()

			for _,v in ipairs(copies) do
				v.IsHidden = true
			end
			copies = {}
			Player.IsHidden = false
		end

		visibilityMenu.refresh = function(self)
			local padding = ui_config.padding

			onlyItemBtn.pos = {padding, padding, 0}
			itemPlusBodyPartBtn.pos = onlyItemBtn.pos + {0, onlyItemBtn.Height + padding, 0}
			itemPlusAvatarBtn.pos = itemPlusBodyPartBtn.pos + {0, itemPlusBodyPartBtn.Height + padding, 0}
			
			w, h = computeContentSize(self)
			self.Width = w + padding * 2
			self.Height = h + padding * 2
			self.pos = modeMenu.pos + {modeMenu.Width + padding, modeMenu.Height - self.Height, 0}
		end

		visibilityMenu:refresh()

		Player:SetParent(World)
		Player.Scale = 1
		local parents = __equipments.equipmentParent(Player, itemCategory)
		local parent = parents
		if type(parents) == "table" then
			parent = parents[1]
		end
		Player.Position = -parent:GetPoint("origin").Position
		
		itemPlusAvatarBtn:onRelease()
		Timer(0.1, updateWearableSubShapesPosition)
	end)
end
