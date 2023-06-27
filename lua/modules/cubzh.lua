Config = {
	Items = { 
		"official.cubzh",
		"official.alpha",
		"aduermael.coin",
		"world_icon",
		"one_cube_template",
		"jacket_template",
		"hair_template",
		"pants_template",
		"shoes_template",
		"hub_collosseum_chunk",
		"hub_scifi_chunk",
		"hub_medieval_chunk",
		"hub_floating_islands_chunk",
		"hub_volcano_chunk"
	}
}

-- CONSTANTS

local WATER_ALPHA = 220
local MAP_SCALE = 5.5

directionalPad = Client.DirectionalPad
action1 = function()
	if Player.IsOnGround then
		Player.Velocity.Y = 100
	end
end

Client.DirectionalPad = nil
Client.Action1 = nil

Client.Action2 = function() end

Client.OnStart = function()

	debugEvent("APP_LAUNCH")

	local ambience = require("ambience") 
	ambience:set(ambience.noon)

	controls = require("controls")
	controls:setButtonIcon("action1", "⬆️")

	-- AMBIENCE --

	camera2 = Camera()
	camera2.Layers = {5}
	camera2:SetParent(World)
	camera2.On = true	
	camera2.TargetY = Screen.Height
	
	-- IMPORT MODULES
	
	ui = require("uikit")
	ease = require("ease")
	api = require("api")
	palette = require("palette")
	friends = require("friends")
	alert = require("alert")
	modal = require("modal")
	pezhUIModule = require("pezh_modal")
	theme = require("uitheme").current

	menu:init()
	menu:refreshFriends()

	-- MAP

	function setChunkPos(chunk, x,y,z) chunk.Position = Number3(x,y,z) * MAP_SCALE end

	function setWaterTransparency(chunk)
		-- local i = chunk.Palette:GetIndex(Color(48, 192, 204, 255))
		-- if i ~= nil then
		-- 	chunk.Palette[i].Color.A = WATER_ALPHA
		-- end
		-- i = chunk.Palette:GetIndex(Color(252, 252, 252, 255))
		-- if i ~= nil then
		-- 	chunk.Palette[i].Color.A = WATER_ALPHA
		-- end
	end

	function setLights(chunk)
		-- local i = chunk.Palette:GetIndex(Color(252, 240, 176, 255))
		-- if i ~= nil then
		-- 	chunk.Palette[i].Color.A = 230
		-- 	chunk.Palette[i].Light = true
		-- end
	end

	collosseumChunk = Shape(Items.hub_collosseum_chunk)
    collosseumChunk.InnerTransparentFaces = false
	collosseumChunk.Physics = PhysicsMode.StaticPerBlock
	collosseumChunk.CollisionGroups = Map.CollisionGroups
	collosseumChunk.Scale = MAP_SCALE
	collosseumChunk.Pivot = {0,0,0}
	collosseumChunk.Friction = Map.Friction
	collosseumChunk.Bounciness = Map.Bounciness
	World:AddChild(collosseumChunk)
	collosseumChunk.Position = {0,0,0}
	setWaterTransparency(collosseumChunk)
	setLights(collosseumChunk)

	scifiChunk = MutableShape(Items.hub_scifi_chunk)
	scifiChunk.InnerTransparentFaces = false
	scifiChunk.Physics = PhysicsMode.StaticPerBlock
	scifiChunk.CollisionGroups = Map.CollisionGroups
	scifiChunk.Scale = MAP_SCALE
	scifiChunk.Pivot = {0,0,0}
	scifiChunk.Friction = Map.Friction
	scifiChunk.Bounciness = Map.Bounciness
	World:AddChild(scifiChunk)
	setChunkPos(scifiChunk, 8, 20, -100)
	setWaterTransparency(scifiChunk)
	setLights(scifiChunk)

	medievalChunk = Shape(Items.hub_medieval_chunk)
	medievalChunk.InnerTransparentFaces = false
	medievalChunk.Physics = PhysicsMode.StaticPerBlock
	medievalChunk.CollisionGroups = Map.CollisionGroups
	medievalChunk.Scale = MAP_SCALE
	medievalChunk.Pivot = {0,0,0}
	medievalChunk.Friction = Map.Friction
	medievalChunk.Bounciness = Map.Bounciness
	World:AddChild(medievalChunk)
	setChunkPos(medievalChunk, -10, -6, 92)
	setWaterTransparency(medievalChunk)
	setLights(medievalChunk)

	floatingIslandsChunks = Shape(Items.hub_floating_islands_chunk)
	floatingIslandsChunks.InnerTransparentFaces = false
	floatingIslandsChunks.Physics = PhysicsMode.StaticPerBlock
	floatingIslandsChunks.CollisionGroups = Map.CollisionGroups
	floatingIslandsChunks.Scale = MAP_SCALE
	floatingIslandsChunks.Pivot = {0,0,0}
	floatingIslandsChunks.Friction = Map.Friction
	floatingIslandsChunks.Bounciness = Map.Bounciness
	World:AddChild(floatingIslandsChunks)
	setChunkPos(floatingIslandsChunks, 141, -4, 0)
	setWaterTransparency(floatingIslandsChunks)
	setLights(floatingIslandsChunks)

	volcanoChunk = Shape(Items.hub_volcano_chunk)
	volcanoChunk.Physics = PhysicsMode.StaticPerBlock
	volcanoChunk.CollisionGroups = Map.CollisionGroups
	volcanoChunk.Scale = MAP_SCALE
	volcanoChunk.Pivot = {0,0,0}
	volcanoChunk.Friction = Map.Friction
	volcanoChunk.Bounciness = Map.Bounciness
	World:AddChild(volcanoChunk)
	volcanoChunk.Position = {800,18,-500}
	setChunkPos(volcanoChunk, 116, 13, -76)
	setWaterTransparency(volcanoChunk)
	setLights(volcanoChunk)

	-- Using a function because this is called by the engine when logging out.
	-- It's safe if the engine doesn't have to know how this table is formed.
	function resetAccountInfo()
		accountInfo = {
			hasUsername = false,
			hasEmail = false,
			hasPassword = false,
			hasDOB = false,
			hasAcceptedTerms = false,
			isUnder13 = false,
		}
	end
	resetAccountInfo()

	function dropPlayer(p)
		World:AddChild(p)
		p.Position = Number3(139, 75, 68) * MAP_SCALE
		p.Rotation = Number3(0.06, math.pi * -0.75, 0)
		p.Velocity = {0,0,0}
		p.Physics = true
	end

	-- TITLE SCREEN
	function displayTitleScreen()
		if titleScreen ~= nil then return end

		Client.DirectionalPad = nil
		Client.Action1 = nil

		account:hideAvatar()
		hideLoading()
		menu:hide()

		titleScreen = ui:createFrame()
		titleScreen.dt = 0.0

		local logoShape = Shape(Items.official.cubzh)
		local alphaShape = Shape(Items.official.alpha)

		logo = ui:createShape(logoShape)
		alpha = ui:createShape(alphaShape)

		logo:setParent(titleScreen)
		alpha:setParent(titleScreen)
		alpha.pos.Z = -700

		alpha.shape.rot = alpha.shape.Rotation:Copy()

		version = ui:createText(Client.AppVersion .. " (alpha) #" .. Client.BuildNumber, Color.White)
		version:setParent(titleScreen)
		copyright = ui:createText("© Voxowl INC", Color.White)
		copyright:setParent(titleScreen)
		pressAnywhere = ui:createText("Press Anywhere", Color.White)
		pressAnywhere:setParent(titleScreen)

		logoNativeWidth = logo.Width
		logoNativeHeight = logo.Height

		titleScreen.parentDidResize = function()
			titleScreen.Width = Screen.Width
			titleScreen.Height = Screen.Height

			local maxWidth = math.min(600, Screen.Width * 0.8)
			local maxHeight = math.min(216, Screen.Height * 0.3)

			local ratio = math.min(maxWidth / logoNativeWidth, maxHeight / logoNativeHeight)

			logo.Width = logoNativeWidth * ratio
			logo.Height = logoNativeHeight * ratio	
			logo.pos = { Screen.Width * 0.5 - logo.Width * 0.5,
						Screen.Height * 0.5 - logo.Height * 0.5 + (pressAnywhere.Height + theme.padding) * 0.5, 0 }

			version.pos = { Screen.SafeArea.Left + theme.padding, Screen.SafeArea.Bottom + theme.padding,0 }
			copyright.pos = { Screen.Width - Screen.SafeArea.Right - theme.padding - copyright.Width, Screen.SafeArea.Bottom + theme.padding, 0 }

			alpha.Height = logo.Height * 3 / 9
			alpha.Width = alpha.Height * 33 / 12
			
			alpha.pos = logo.pos + { logo.Width * 24.5 / 25 - alpha.Width, 
									logo.Height * 3.5 / 9 - alpha.Height, 
									0}

			pressAnywhere.pos = { Screen.Width * 0.5 - pressAnywhere.Width * 0.5,
						logo.pos.Y - pressAnywhere.Height - theme.padding, 0 }


		end
		titleScreen:parentDidResize()

		controls:turnOn()
		ui:turnOn()
	end

	function hideTitleScreen()
		if titleScreen == nil then return end
		titleScreen:remove()
		titleScreen = nil
	end

	function displayLoading(text)
		if loadingModal ~= nil then
			loadingModal:setText(text)
			return
		end

		closeModals()
		
		loadingModal = require("loading_modal"):create(text)

		loadingModal.didClose = function()
			loadingModal = nil
			refreshMenuDisplayMode()
		end
		refreshMenuDisplayMode()
	end

	function hideLoading()
		if loadingModal == nil then return end
		loadingModal:close()
		loadingModal = nil
	end

	function maxModalWidth()
		local computed = Screen.Width - Screen.SafeArea.Left - Screen.SafeArea.Right - menu.windowPadding * 2
		local max = 1400
		local w = math.min(max, computed)
		return w
	end

	function maxModalHeight()
		local vMargin = menu:topReservedHeight() + menu:bottomReservedHeight()
		local h = Screen.Height - Screen.SafeArea.Top - Screen.SafeArea.Bottom - vMargin
		return h
	end

	function updateModalPosition(modal, forceBounce)

		local vMin = Screen.SafeArea.Bottom + menu:bottomReservedHeight() + menu.padding
		local vMax = Screen.Height - Screen.SafeArea.Top - menu:topReservedHeight() - menu.padding

		local vCenter = vMin + (vMax - vMin) * 0.5

		local p = Number3(Screen.Width * 0.5 - modal.Width * 0.5, vCenter - modal.Height * 0.5, 0)

		if not modal.updatedPosition or forceBounce then
			modal.LocalPosition = p - {0,100,0}
			modal.updatedPosition = true
			ease:cancel(modal) -- cancel modal ease animations if any
			ease:outBack(modal, 0.22).LocalPosition = p
		else
			modal.LocalPosition = p
		end
	end

	friendsModal = nil
	alertModal = nil
	coinsModal = nil

	refreshMenuDisplayMode = function()
		if friendsModal == nil and shopModal == nil and 
			avatarEditor == nil and exploreModal == nil and 
			createModal == nil and coinsModal == nil and
			alertModal == nil and secretModal == nil and
			settingsModal == nil then

			menu:maximize()
			controls:turnOn()
			ui:turnOn()
		else
			menu:minimize()
			controls:turnOff()
		end
	end

	closeModals = function()
		if friendsModal ~= nil then
			menu.friendsBtn:unselect()
			friendsModal:close()
			friendsModal = nil
		end
		if shopModal ~= nil then
			menu.shopBtn:unselect()
			shopModal:close()
			shopModal = nil
		end
		if alertModal ~= nil then
			alertModal:close()
			alertModal = nil
		end
		if avatarEditor ~= nil then
			menu.profileBtn:unselect()
			avatarEditor:close()
			avatarEditor = nil
		end
		if exploreModal ~= nil then
			exploreModal:close()
			exploreModal = nil
		end
		if createModal ~= nil then
			createModal:close()
			createModal = nil
		end
		if coinsModal ~= nil then
			menu.coinsBtn:unselect()
			coinsModal:close()
			coinsModal = nil
		end
		if secretModal ~= nil then
			secretModal:close()
			secretModal = nil
		end
		if loadingModal ~= nil then
			loadingModal:close()
			loadingModal = nil
		end
		if settingsModal ~= nil then
			settingsModal:close()
			settingsModal = nil
		end

		secretCount = nil
	end

	menu.shopAction = function(self)
		if shopModal ~= nil then
			updateModalPosition(shopModal, true) -- make it bounce
			return
		end

		debugEvent("MAIN_MENU_GALLERY_BUTTON")

		closeModals()

		menu.shopBtn:select()
		menu:minimize()

		shopModal = require("gallery"):create(maxModalWidth, maxModalHeight, updateModalPosition)

		shopModal.didClose = function()
			menu.shopBtn:unselect()
			shopModal = nil
			refreshMenuDisplayMode()
		end

		refreshMenuDisplayMode()
	end

	menu.coinAction = function(self)
		if coinsModal ~= nil then
			if secretCount == nil then 
				secretCount = 1 
			else
				secretCount = secretCount + 1
				if secretCount == 9 then
					closeModals()
					secretModal = require("input_modal"):create("Oh, it seems like you have something to say? 🤨")
					secretModal:setPositiveCallback("Oh yeah!", function(text)
						if text ~= "" then
							api:postSecret(text, function(success, message) 
								if success then
									if message ~= nil and message ~= "" then
										self:showAlert({message = message})
									else
										self:showAlert({message = "✅"})
									end
									api.getBalance(function(err, balance)
										if err then return end
										menu.coinsBtn.Text = "" .. math.floor(balance.total) .. " 💰"
										menu:refresh()
									end)
								else
									self:showAlert({message = "❌ Error"})
								end
							end)
						end
					end)
					secretModal:setNegativeCallback("Hmm, no.", function() end)
					secretModal.didClose = function()
						secretModal = nil
						refreshMenuDisplayMode()
					end
					refreshMenuDisplayMode()
					return
				end
			end
			updateModalPosition(coinsModal, true) -- make it bounce
			return
		end

		debugEvent("MAIN_MENU_COINS_BUTTON")

		closeModals()

		function maxPezhModalWidth()
			local computed = Screen.Width - Screen.SafeArea.Left - Screen.SafeArea.Right - menu.windowPadding * 2
			local max = 600
			local w = math.min(max, computed)
			return w
		end
	
		function maxPezhModalHeight()
			local vMargin = menu:topReservedHeight() + menu:bottomReservedHeight()
			local h = Screen.Height - Screen.SafeArea.Top - Screen.SafeArea.Bottom - vMargin
			return h
		end

		menu.coinsBtn:select()
		menu:minimize()

		coinsModal = pezhUIModule:create(maxPezhModalWidth, maxPezhModalHeight, updateModalPosition)

		coinsModal.didClose = function()
			menu.coinsBtn:unselect()
			coinsModal = nil
			refreshMenuDisplayMode()
		end

		refreshMenuDisplayMode()
	end

	menu.profileAction = function()
		if avatarEditor ~= nil then 
			avatarEditorPosition(avatarEditor, true) -- make it bounce
			return
		end

		debugEvent("MAIN_MENU_PROFILE_BUTTON")

		closeModals()

		menu.profileBtn:select()
		menu:minimize()

		function avatarEditorMaxWidth()

			local portrait = Screen.Width < Screen.Height
			local max = 700
			local computed = 300
			local safe = math.max(Screen.SafeArea.Left, Screen.SafeArea.Right)

			if portrait then
				computed = (Screen.Width - safe * 2) - menu.windowPadding * 2
			else
				computed = (Screen.Width - safe * 2) * 0.6 - menu.windowPadding * 2
			end

			local w = math.min(max, computed)
			return w
		end
	
		function avatarEditorMaxHeight()
			local vMargin = menu:bottomReservedHeight() + menu:topReservedHeight()
			local h = Screen.Height - Screen.SafeArea.Top - Screen.SafeArea.Bottom - vMargin
			return h
		end

		function avatarEditorPosition(modal, forceBounce)
			local portrait = Screen.Width < Screen.Height
			local p

			local vMin = Screen.SafeArea.Bottom + menu:bottomReservedHeight() + menu.padding
			local vMax = Screen.Height - Screen.SafeArea.Top - menu:topReservedHeight() - menu.padding
			local vCenter = vMin + (vMax - vMin) * 0.5

			if portrait then
				p = Number3(Screen.Width * 0.5 - modal.Width * 0.5, vMin + menu.windowPadding, 0)
			else
				p = Number3(Screen.Width * 0.7 - modal.Width * 0.5, vCenter - modal.Height * 0.5, 0)
			end

			-- camera2 always renders on screen size
			camera2.Width = Screen.Width
			camera2.TargetWidth = Screen.Width
			camera2.Height = Screen.Height
			camera2.TargetHeight = Screen.Height

			if not modal.updatedPosition or forceBounce then

				modal.LocalPosition = p - {0,100,0}
				ease:cancel(modal) -- cancel modal ease animations if any
				ease:outBack(modal, 0.22).LocalPosition = p

				if portrait then
					camera2.TargetX = 0
					camera2.TargetY = Screen.Height
				else
					camera2.TargetX = Screen.Width * 0.25 - camera2.Width * 0.5
					camera2.TargetY = Screen.Height
				end

				-- also size / position avatar camera
				-- (not when just bounding modal)
				if not modal.updatedPosition then
					Camera.Color = Color(100,100,100)
					Player.Layers = camera2.Layers
					require("hierarchyactions"):applyToDescendants(Player.Body,{includeRoot = true},function(o)
						o.IsUnlit = true
					end)
					camera2:SetParent(Player)
					camera2.rot = Number3(0, math.pi, 0)
					camera2.LocalRotation = camera2.rot
					camera2.Position = Player.Position + {0,8,0} + camera2.Backward * 30
					-- can't make it work...
					-- camera2:FitToScreen(Player.Body:ComputeWorldBoundingBox(), 1.0)

					avatarEditorDragListener = LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pointerEvent)
						camera2.rot.Y = camera2.rot.Y + pointerEvent.DX * 0.02
						camera2.rot.X = camera2.rot.X - pointerEvent.DY * 0.02
						if camera2.rot.X > math.pi * 0.4 then camera2.rot.X = math.pi * 0.4 end
						if camera2.rot.X < -math.pi * 0.4 then camera2.rot.X = -math.pi * 0.4 end

						camera2.LocalRotation = camera2.rot
						camera2.Position = Player.Position + {0,8,0} + camera2.Backward * 30
					end)
				end

				modal.updatedPosition = true
			else
				modal.LocalPosition = p
			end

			ease:cancel(camera2)
			local anim = ease:outBack(camera2, 0.22)

			if portrait then
				local y = p.Y + modal.Height + menu.windowPadding
				local h = Screen.Height - y
				anim.TargetX = 0
				anim.TargetY = y + h * 0.5 - camera2.Height * 0.5
			else
				anim.TargetX = Screen.Width * 0.25 - camera2.Width * 0.5
				anim.TargetY = 0
			end
		end

		avatarEditor = require("avatar_editor"):create(avatarEditorMaxWidth, avatarEditorMaxHeight, avatarEditorPosition)

		avatarEditor.didClose = function()
			if avatarEditorDragListener then avatarEditorDragListener:Remove() avatarEditorDragListener = nil end
			menu.profileBtn:unselect()
			avatarEditor = nil
			refreshMenuDisplayMode()

			local anim = ease:outBack(camera2, 0.4, {
				onDone = function()
					Player.Layers = Camera.Layers
				end,
			})

			local layers = {}
			for _, l in ipairs(Camera.Layers) do table.insert(layers, l) end
			for _, l in ipairs(camera2.Layers) do table.insert(layers, l) end
			Player.Layers = layers
			require("hierarchyactions"):applyToDescendants(Player.Body,{includeRoot = true},function(o)
				o.IsUnlit = false
			end)
			anim.TargetWidth = Screen.Width
			anim.Width = Screen.Width
			anim.TargetHeight = Screen.Height
			anim.Height = Screen.Height
			-- anim.TargetX = 0
			anim.TargetY = Screen.Height

			Camera.Color = Color(255,255,255)
		end

		refreshMenuDisplayMode()
	end

	menu.friendsAction = function()
		if friendsModal ~= nil then 
			updateModalPosition(friendsModal, true) -- make it bounce
			return
		end

		debugEvent("MAIN_MENU_FRIENDS_BUTTON")

		closeModals()

		menu.friendsBtn:select()
		menu:minimize()

		friendsModal = friends:create(maxModalWidth, maxModalHeight, updateModalPosition)

		friendsModal.didClose = function()
			menu.friendsBtn:unselect()
			friendsModal = nil
			refreshMenuDisplayMode()
			menu:refreshFriends()
		end
		
		refreshMenuDisplayMode()
	end

	-- config: {message = "",
	--  		positiveCallback = function() end, positiveLabel = "yes",
	--          negativeCallback = function() end, negativeLabel = "no"}
	menu.showAlert = function(self, config)
		if alertModal ~= nil then
			alertModal:bounce()
			return
		end

		closeModals()
		
		alertModal = alert:create(config.message or "")
		if config.positiveCallback then
			alertModal:setPositiveCallback(config.positiveLabel or "OK", config.positiveCallback)
		end
		if config.negativeCallback then
			alertModal:setNegativeCallback(config.negativeLabel or "No", config.negativeCallback)
		end
		if config.neutralCallback then
			alertModal:setNeutralCallback(config.neutralLabel or "...", config.neutralCallback)
		end

		alertModal.didClose = function()
			alertModal = nil
			refreshMenuDisplayMode()
		end
		refreshMenuDisplayMode()
	end

	menu.settingsAction = function()
		if settingsModal ~= nil then
			updateModalPosition(settingsModal, true) -- make it bounce
			return
		end

		closeModals()
		menu:minimize()

		settingsModal = require("settings"):create(updateModalPosition, { clearCache = true, logout = true })

		settingsModal.didClose = function()
			settingsModal = nil
			refreshMenuDisplayMode()
		end

		refreshMenuDisplayMode()

		-- controls:turnOff()
		-- ui:turnOff()
		-- openSettings()
	end

	menu.exploreAction = function(self)
		if exploreModal ~= nil then
			updateModalPosition(exploreModal, true) -- make it bounce
			return
		end

		closeModals()
		menu:minimize()

		exploreModal = require("explore_menu"):create(maxModalWidth, maxModalHeight, updateModalPosition)

		exploreModal.didClose = function()
			exploreModal = nil
			refreshMenuDisplayMode()
		end

		refreshMenuDisplayMode()
	end

	menu.createAction = function(self)
		if accountInfo.hasUsername == false then -- Account actions (login, username, password)
			self:showAlert({message = "💬 You need a username to create!"})
			return
		end

		if createModal ~= nil then
			updateModalPosition(createModal, true) -- make it bounce
			return
		end

		closeModals()
		menu:minimize()

		createModal = require("create_menu"):create(maxModalWidth, maxModalHeight, updateModalPosition)

		createModal.didClose = function()
			createModal = nil
			refreshMenuDisplayMode()
		end

		refreshMenuDisplayMode()
	end

	-- for all animations, goes back to main menu 
	-- after this amount of time:
	kPostTriggerTime = 1.75

	pi2 = math.pi * 2
	moveDT = 0.0
	kCameraPositionY = 90
	yaw = -1.4 -- initial camera yaw value

	kCameraPositionRotating = Number3(139, kCameraPositionY, 68) * MAP_SCALE

	UI.Crosshair = false

	Private.PauseAvailable = false

	Camera:SetModeFree()
	Camera.Position = kCameraPositionRotating
	Camera.Rotation = { 0, yaw, 0 } -- start right before the PARTICUBES text :)
	Pointer:Show()

	-- Called by C++ code when from within C++ UI.
	function backFromCPP()
		showUI()
		LocalEvent:Send(LocalEvent.Name.ScreenDidResize, Screen.Width, Screen.Height) -- necessary when coming back from launched experience
		menu:refresh()
		refreshMenuDisplayMode()
	end

	-- hides all UI elements
	function hideUI()
		ui.rootFrame:SetParent(nil)
	end

	function showUI()
		if ui.rootFrame:GetParent() == nil then
			ui.rootFrame:SetParent(World)
			LocalEvent:Send("uishown")
		end
	end

	Screen.DidResize = function(width, height)
		menu:refresh()
	end

	displayTitleScreen()
	if hasEnvironmentToLaunch() then
		skipTitleScreen()
	end
end

Client.OnPlayerJoin = function(p)
	if p ~= Player then return end
	dropPlayer(p)
end

Client.Tick = function(dt)

	if account.shown then
		if Player.Position.Y < -500 then
			dropPlayer(Player)
		end
	else
		-- UP/DOWN MOVEMENT
		moveDT = moveDT + dt * 0.2
		-- keep moveDT between -pi & pi
		while moveDT > math.pi do
			moveDT = moveDT - pi2
		end
		Camera.Position.Y = (kCameraPositionY + math.sin(moveDT) * 5.0) * MAP_SCALE

		-- ROTATION
		yaw = yaw + 0.1 * dt
		-- keep yaw between -pi & pi
		while yaw > math.pi do
			yaw = yaw - pi2
		end
		-- rotate camera
		Camera.Rotation.Y = yaw
	end

	if titleScreen and titleScreen:isVisible() then
		titleScreen.dt = titleScreen.dt + dt * 4.0
		pressAnywhere.Color = Color(255,255,255, (math.sin(titleScreen.dt) + 1.0) * 0.5)

		alpha.shape.Rotation = alpha.shape.rot + {0, titleScreen.dt * 0.4, 0}
	end
end

Pointer.Down = function(pointerEvent)
	skipTitleScreen()
end

function parseVersion(versionStr)
	local maj, min, patch = versionStr:match("(%d+)%.(%d+)%.(%d+)")
	maj = math.floor(tonumber(maj))
	min = math.floor(tonumber(min))
	patch = math.floor(tonumber(patch))
	return maj, min, patch
end

function skipTitleScreen()
	if titleScreen == nil then return end

	debugEvent("SKIP_SPLASHSCREEN")

	hideTitleScreen()
	menu:hide()

	local function done()
		if dobModal ~= nil then
			dobModal.didClose = nil
			dobModal:close()
			dobModal = nil
		end
		closeModals()
		hideLoading()

		debugEvent("MAIN_MENU")

		Client.DirectionalPad = directionalPad
		Client.Action1 = action1

		menu:refresh()
		menu:show()
		account:showAvatar()
		
		if hasEnvironmentToLaunch() then
			hideUI()
			launchEnvironment()
		end
	end

	local function checkUserInfo()

		displayLoading("Checking user info")

		if hasCredentials() == false then

			debugEvent("SKIP_SPLASHSCREEN_WITH_NO_ACCOUNT")

			closeModals()

			local helpBtn = ui:createButton("👾 Need help?", {textSize = "small"})
			helpBtn:setColor(theme.colorDiscord, Color.White)
			helpBtn.onRelease = function()
				URL:Open("https://cu.bzh/discord")
			end
			helpBtn.parentDidResize = function(self)
				self.pos = {Screen.Width - self.Width - theme.padding - Screen.SafeArea.Right, Screen.Height - self.Height - theme.padding - Screen.SafeArea.Top, 0}
			end
			helpBtn:parentDidResize()

			local loginBtn = ui:createButton("Login", {textSize = "small"})
			loginBtn.parentDidResize = function(self)
				self.pos = {Screen.SafeArea.Left + theme.padding, Screen.Height - self.Height - theme.padding - Screen.SafeArea.Top, 0}
			end
			loginBtn.onRelease = function()
				login(function(success, info)
					if success then
						accountInfo = info
						helpBtn:remove()
						loginBtn:remove()
						done()
					end
				end)
			end
			loginBtn:parentDidResize()

			dobModal = require("dob_modal"):create()
	
			dobModal.onDone = function(year, month, day)
				debugEvent("BIRTHDATE_SUBMIT")
				loginBtn:remove()
				helpBtn:remove()
				dobModal.didClose = nil
				dobModal:close()
				dobModal = nil
				refreshMenuDisplayMode()

				local function _createAccount(onError)
					displayLoading("Connecting")
					createAccount(string.format("%02d-%02d-%04d", month, day, year), function(err)
						if err ~= nil then
							if onError ~= nil then onError(onError) end
							return
						else
							debugEvent("ACCOUNT_CREATED")
							done()
						end
					end)
				end

				local function onError(onError)
					menu:showAlert({
						message = "❌ Sorry, something went wrong.",
						positiveCallback = function() _createAccount(onError) end,
						positiveLabel = "Retry",
						neutralCallback = function() displayTitleScreen() end,
						neutralLabel = "Cancel",
					})
				end

				_createAccount(onError)
			end

			dobModal.didClose = function()
				loginBtn:remove()
				helpBtn:remove()
				displayTitleScreen()
				dobModal = nil
				refreshMenuDisplayMode()
			end
			refreshMenuDisplayMode()
		else
			-- Fetches account info
			-- it's ok to continue if err == nil
			-- (info updated at the engine level)
			getAccountInfo(function(err, res)
				if err ~= nil then
					menu:showAlert({
						message = "❌ Sorry, something went wrong.",
						positiveCallback = function() displayTitleScreen() end,
						positiveLabel = "OK",
					})
					return
				end

				accountInfo = res
				
				-- if accountInfo.hasDOB == false then
				-- 	-- This is not supposed to happen, as DOB is required to create an account
				-- 	return
				-- end

				done()
			end)
		end
	end

	local function preliminaryChecks()
		if hasCredentials() == false and askedForMagicKey() then
			checkMagicKey(
				function(error, info)
					if error ~= nil then
						displayTitleScreen()
					else
						accountInfo = info
						done()
					end
				end,
				function(keyIsValid)
					if keyIsValid then
						closeModals()
					else
						checkUserInfo()
					end
				end
			)
			return
		else
			checkUserInfo()
		end
	end

	displayLoading("Checking app version")

	api:getMinAppVersion(function(error, minVersion)
		-- print("checking min app version...")
		if error ~= nil then
			menu:showAlert({
				message = "❌ Network error ❌ ",
				positiveCallback = function() displayTitleScreen() end,
				positiveLabel = "OK",
			})
			return
		end

		local major, minor, patch = parseVersion(Client.AppVersion)
		local minMajor, minMinor, minPatch = parseVersion(minVersion)

		-- minPatch = 51 -- force trigger, for tests
		if major < minMajor or
			(major == minMajor and minor < minMinor) or 
			(minor == minMinor and patch < minPatch) then
			
			hideLoading()
			menu:showAlert({
				message = string.format("Sorry but this app needs to be updated!\nminimum: %d.%d.%d\ninstalled: %d.%d.%d", 
					minMajor, minMinor, minPatch,
					major, minor, patch),
				positiveCallback = function() displayTitleScreen() end,
				positiveLabel = "I'll do it!",
			})
		else 
			preliminaryChecks()
		end
	end)
end

Pointer.Drag = function(pointerEvent)
	if uiCaptured then 
		ui:pointerDrag(pointerEvent)
		return
	end

	if avatarEditor ~= nil then
		camera2.Position = Camera.Position
		camera2.Rotation = Camera.Rotation

		local p = Player.Position:Copy()
		p.Y = camera2.Position.Y
		local diff = camera2.Position - p

		local l = diff.Length
		local a = math.atan(diff.Z, diff.X)

		if rotDT == nil then
			rotDT = 0.0
		end
		rotDT = rotDT - pointerEvent.DX * 0.01

		a = a - rotDT

		camera2.Rotation = Number3(Camera.Rotation.X, 0, Camera.Rotation.Z) + {0, a, 0}

		local x = math.cos(a) * l
		local z = math.sin(a) * l

		camera2.Position = p - {z, 0, x}
	end
end

-- //////////////////////////////////////////////////
-- ///
-- /// ACCOUNT MENU
-- ///
-- //////////////////////////////////////////////////

account = {
	shown = false, -- indicates whether the account menu is shown to the user
	showAvatar = function(self)
		if self.shown then return end
		self.shown = true

		-- reload avatar
		Client.__loadAvatar(Player.ID, true)

		Camera:SetModeThirdPerson()

		dropPlayer(Player)
	end,
	hideAvatar = function(self)
		if not self.shown then return end
		self.shown = false
		
		Camera:SetModeFree()
		Player:RemoveFromParent()
	end,
}

-- //////////////////////////////////////////////////
-- ///
-- /// MENU (could move to module)
-- ///
-- //////////////////////////////////////////////////

menu = {
	minimized = true,
	hidden = true,

	profileAction = nil,
	settingsAction = nil,
	friendsAction = nil,
	coinAction = nil,
	shopAction = nil,
	exploreAction = nil,
	createAction = nil,

	padding = 6,
	windowPadding = 12,
	nbFriends = 0,
	nbCoins = 0,

	bottomReservedHeight = function(self) 
		if self.hidden then return 0 end
		if self.minimized then return menu.windowPadding end
		return self.bottom.Height + menu.padding + menu.windowPadding
	end,

	topReservedHeight = function(self) 
		if self.hidden then return 0 end
		return self.topLeft.Height + menu.padding + menu.windowPadding
	end,


	show = function(self)
		if self.hidden == false then return end
		self.hidden = false

		self.topLeft:setParent(ui.rootFrame)
		self.topRight:setParent(ui.rootFrame)

		if self.minimized == false then
			self.bottom:setParent(ui.rootFrame)
		end
	end,

	hide = function(self)
		if self.hidden then return end
		self.hidden = true

		self.topLeft:setParent(nil)
		self.topRight:setParent(nil)
		self.bottom:setParent(nil)
	end,

	setNbFriends = function(self, n)
		self.nbFriends = n
		if self.minimized then
			self.friendsBtn.Text = "❤️"
		else
			self.friendsBtn.Text = "❤️ Friends"
		end
		if n > 0 then
			self.friendsBtn.Text = self.friendsBtn.Text .. "(" .. n .. ")"
		end
		self:refresh()
	end,

	refreshFriends = function(self)
		api:getFriendCount(function(ok, count)
			self:setNbFriends(count)
		end)
	end,

	minimize = function(self)
		if self.minimized then return end
		self.minimized = true

		self:refreshProfileBtn()

		self:setNbFriends(self.nbFriends)

		self.shopBtn.Text = "✨"

		self.discordBtn:setParent(nil)
		self.createButton:setParent(nil)
		self.exploreBtn:setParent(nil)

		self:refresh()
	end,

	maximize = function(self)
		if self.minimized == false then
			return
		end
		self.minimized = false

		self:refreshProfileBtn()

		self:setNbFriends(self.nbFriends)

		self.shopBtn.Text = "Gallery ✨"

		if not self.discordBtn.parent then 
			self.discordBtn:setParent(self.topRight)
		end

		if not self.createButton.parent then  self.createButton:setParent(self.topLeft) end
		if not self.exploreBtn.parent then  self.exploreBtn:setParent(self.topLeft) end

		self:refresh()
	end,

	refreshProfileBtn = function(self)
		if self.minimized then
			self.profileBtn.Text = "🙂"
		else
			self.profileBtn.Text = "🙂 " .. Player.Username
		end
	end,

	refresh = function(self)

		if self.accountFrame ~= nil then
			self.accountFrame:setParent(nil)
		end
		if self.setPasswordBtn ~= nil then
			self.setPasswordBtn:setParent(nil)
		end
		if self.setEmailBtn ~= nil then
			self.setEmailBtn:setParent(nil)
		end
		
		if self.minimized then
			if self.bottom.object:GetParent() ~= nil then self.bottom:setParent(nil) end

			self.profileBtn.LocalPosition = {0, 0, 0}
			self.settingsBtn.LocalPosition = { self.profileBtn.Width + self.padding, 0, 0}
			self.friendsBtn.LocalPosition = { self.settingsBtn.LocalPosition.X + self.settingsBtn.Width + self.padding, 0, 0}

			self.shopBtn.LocalPosition = {0, 0, 0}
			self.coinsBtn.LocalPosition = {self.shopBtn.LocalPosition.X + self.shopBtn.Width + self.padding, 0, 0}
		else
			if self.hidden == false and self.bottom.object:GetParent() == nil then self.bottom:setParent(ui.rootFrame) end

			self.exploreBtn.LocalPosition = {0, 0, 0}
			self.createButton.LocalPosition = {0, self.exploreBtn.LocalPosition.Y + self.exploreBtn.Height + self.padding, 0}
			self.friendsBtn.LocalPosition = {0, self.createButton.LocalPosition.Y + self.createButton.Height + self.padding, 0}
			self.profileBtn.LocalPosition = {0, self.friendsBtn.LocalPosition.Y + self.friendsBtn.Height + self.padding, 0}

			self.settingsBtn.LocalPosition = {self.profileBtn.Width + self.padding, self.profileBtn.LocalPosition.Y, 0}

			local w = self.topRight.Width


			local accountBtnsTotalHeight = 0
			
			if accountInfo.hasUsername == false then -- show a frame with 2 buttons (login & set username)
				self.accountFrame:setParent(self.topRight)
				self.accountFrame:parentDidResize()
				w = self.topRight.Width
				accountBtnsTotalHeight = accountBtnsTotalHeight + self.accountFrame.Height + self.padding
			else -- not anonymous
				if accountInfo.hasPassword == false then
					-- show button to set password
					self.setPasswordBtn:setParent(self.topRight)
					self.setPasswordBtn.LocalPosition.Y = accountBtnsTotalHeight
					w = self.topRight.Width
					accountBtnsTotalHeight = accountBtnsTotalHeight + self.setPasswordBtn.Height + self.padding
				end
				if accountInfo.hasEmail == false and accountInfo.isUnder13 == false then
					-- show button to set email
					self.setEmailBtn:setParent(self.topRight)
					self.setEmailBtn.LocalPosition.Y = accountBtnsTotalHeight
					w = self.topRight.Width
					accountBtnsTotalHeight = accountBtnsTotalHeight + self.setEmailBtn.Height + self.padding
				end
			end

			if self.accountFrame.parent ~= nil then self.accountFrame.pos = {w - self.accountFrame.Width, 0, 0} end
			local y = 0
			if self.setPasswordBtn.parent ~= nil then 
				self.setPasswordBtn.pos = {w - self.setPasswordBtn.Width, 0, 0} 
				y = self.setPasswordBtn.Height + self.padding 
			end
			if self.setEmailBtn.parent ~= nil then self.setEmailBtn.pos = {w - self.setEmailBtn.Width, y, 0} end

			self.discordBtn.LocalPosition = {w - self.discordBtn.Width, accountBtnsTotalHeight, 0}

			self.shopBtn.LocalPosition = {w - self.shopBtn.Width, self.discordBtn.LocalPosition.Y + self.discordBtn.Height + self.padding, 0}
			self.coinsBtn.LocalPosition = {w - self.coinsBtn.Width, self.shopBtn.LocalPosition.Y + self.shopBtn.Height + self.padding, 0}
		end

		self.topLeft.LocalPosition = {self.padding + Screen.SafeArea.Left, Screen.Height - self.topLeft.Height - self.padding - Screen.SafeArea.Top, 0}
		self.topRight.LocalPosition = { Screen.Width - self.topRight.Width - self.padding - Screen.SafeArea.Right, Screen.Height - self.topRight.Height - self.padding - Screen.SafeArea.Top, 0}
		self.bottom.LocalPosition = { Screen.Width * 0.5, self.padding + Screen.SafeArea.Bottom, 0}
	end,

	computeNodeHeight = function(self)
		local max = 0
		local min = 0
		for _, child in pairs(self.children) do
			if min > child.LocalPosition.Y then min = child.LocalPosition.Y end
			if max < child.LocalPosition.Y + child.Height then max = child.LocalPosition.Y + child.Height end
		end
		return max - min
	end,

	computeNodeWidth = function(self)
		local max = 0
		local min = 0
		for _, child in pairs(self.children) do
			if min > child.LocalPosition.X then min = child.LocalPosition.X end
			if max < child.LocalPosition.X + child.Width then max = child.LocalPosition.X + child.Width end
		end
		return max - min
	end,

	init = function(self)

		self.topLeft = ui:createNode()
		self.topLeft.height = self.computeNodeHeight
		self.topLeft.width = self.computeNodeWidth

		self.topRight = ui:createNode()
		self.topRight.height = self.computeNodeHeight
		self.topRight.width = self.computeNodeWidth

		self.bottom = ui:createNode()
		self.bottom.height = self.computeNodeHeight
		self.bottom.width = self.computeNodeWidth

		self.profileBtn = ui:createButton("🙂 Profile")
		self.profileBtn:setParent(self.topLeft)
		self.profileBtn.onRelease = function()
			if self.profileAction ~= nil then self.profileAction() end
		end

		self.settingsBtn = ui:createButton("⚙️")
		self.settingsBtn:setParent(self.topLeft)
		self.settingsBtn.onRelease = function()
			if self.settingsAction ~= nil then self.settingsAction() end
		end

		self.friendsBtn = ui:createButton("❤️ Friends")
		self.friendsBtn:setParent(self.topLeft)
		self.friendsBtn.onRelease = function()
			if self.friendsAction ~= nil then self.friendsAction() end
		end

		-- Frame box buttons for account actions (login/username)
		self.accountFrame = ui:createFrame(Color(0, 0, 0, 128))
		self.accountFrame.LocalPosition.Z = 0
		self.accountFrame.parentDidResize = function(frame)
			frame.Width = math.max(self.loginBtn.Width, self.pickUsernameBtn.Width) + (2 * self.padding)
			frame.Height = self.pickUsernameBtn.Height + self.loginBtn.Height + (3 * self.padding)
		end

		self.pickUsernameBtn = ui:createButton("🧪 Pick username")
		self.pickUsernameBtn:setColor(theme.colorPositive, Color(23,30,14))
		self.pickUsernameBtn:setParent(self.accountFrame)
		self.pickUsernameBtn.parentDidResize = function(selfBtn)
			selfBtn.LocalPosition.X = selfBtn.parent.Width - selfBtn.Width - self.padding
			selfBtn.LocalPosition.Y = selfBtn.parent.Height - selfBtn.Height - self.padding
		end
		self.pickUsernameBtn.onRelease = function()
			debugEvent("PICK_USERNAME_REQUEST")
			controls:turnOff()
			ui:turnOff()
			promptForUsername()
		end

		self.loginBtn = ui:createButton("🔑 Login")
		self.loginBtn:setParent(self.accountFrame)
		self.loginBtn.parentDidResize = function(selfBtn)
			selfBtn.LocalPosition.X = selfBtn.parent.Width - selfBtn.Width - self.padding
			selfBtn.LocalPosition.Y = self.padding
		end
		self.loginBtn.onRelease = function()
			controls:turnOff()
			ui:turnOff()
			login(function(success, info)
				controls:turnOn()
				ui:turnOn()
				if success then
					accountInfo = info
					menu:refresh()
				end
			end)
		end

		self.accountFrame:parentDidResize()

		-- Buttons for email/password
		self.setPasswordBtn = ui:createButton("🔑 Set password")
		self.setPasswordBtn.onRelease = function()
			debugEvent("SET_PASSWORD_REQUEST")
			controls:turnOff()
			ui:turnOff()
			promptForPassword()
		end
		self.setEmailBtn = ui:createButton("✉️ Set email")
		self.setEmailBtn.onRelease = function()
			debugEvent("SET_EMAIL_REQUEST")
			controls:turnOff()
			ui:turnOff()
			promptForEmail()
		end

		-- RIGHT

		self.coinsBtn = ui:createButton("0 💰", {sound = "coin_1"})
		self.coinsBtn:setParent(self.topRight)
		self.coinsBtn.onRelease = function()
			if self.coinAction ~= nil then self:coinAction() end
		end
		api.getBalance(function(err, balance)
			if err then
				self.coinsBtn.Text = "0 💰"
				return
			end
			self.coinsBtn.Text = "" .. math.floor(balance.total) .. " 💰"
			menu:refresh()
		end)

		self.shopBtn = ui:createButton("Shop ✨")
		self.shopBtn:setParent(self.topRight)
		self.shopBtn.onRelease = function()
			if self.shopAction ~= nil then self:shopAction() end
		end

		self.discordBtn = ui:createButton("👾 Need help?")
		self.discordBtn:setColor(theme.colorDiscord, Color.White)
		self.discordBtn:setParent(self.topRight)
		self.discordBtn.onRelease = function()
			debugEvent("MAIN_MENU_DISCORD_BUTTON")
			URL:Open("https://cu.bzh/discord")
		end

		-- BOTTOM

		self.exploreBtn = ui:createButton("🌎 Explore")
		-- self.exploreBtn:setParent(self.bottom)
		self.exploreBtn:setParent(self.topLeft)
		self.exploreBtn:setColor(theme.colorExplore, Color.White)
		self.exploreBtn.onRelease = function()
			if self.exploreAction ~= nil then 
				debugEvent("MAIN_MENU_EXPLORE_BUTTON")
				self:exploreAction() 
			end
		end

		self.createButton = ui:createButton("🏗️ Build")
		-- self.createButton:setParent(self.bottom)
		self.createButton:setParent(self.topLeft)
		self.createButton:setColor(theme.colorCreate, Color.White)
		self.createButton.onRelease = function()
			if self.createAction ~= nil then
				debugEvent("MAIN_MENU_CREATE_BUTTON")
				self:createAction()
			end
		end

		self:maximize() -- start with maximized ui
		self:show()
	end,
}
