Config = {
	Map = "land_map",
	Items = { 
				"official.cubzh",
				"official.alpha",
				"aduermael.coin",
				"world_icon",
				"one_cube_template",
				"jacket_template",
				"hair_template",
				"pants_template",
				"shoes_template"
			}
}

Client.OnStart = function()

	-- AMBIENCE --

	sun = Light()
	if sun.CastsShadows ~= nil then sun.CastsShadows = true end
    sun.On = true
	sun.Color = Color(50,40,30)
	sun.Type = LightType.Directional
	World:AddChild(sun)
	sun.Rotation = {math.pi * 0.26, math.pi * 1.5, 0}

	-- Dev.DisplayColliders = true

	camera2 = Camera()
	camera2.Layers = 5
	camera2:SetParent(World)
	camera2.On = true	
	
	ease = require("ease")
	ui = require("uikit")
	api = require("api")
	messenger = require("local_messenger")
	palette = require("palette")
	friends = require("friends")
	alert = require("alert")
	modal = require("modal")
	pezhUIModule = require("pezh_modal")

	theme = require("uitheme").current

	menu:init()
	menu:refreshFriends()

	-- TITLE SCREEN
	function displayTitleScreen()
		if titleScreen ~= nil then return end
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

		version = ui:createText(Environment.version, Color.White)
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
	end

	function hideTitleScreen()
		if titleScreen == nil then return end
		titleScreen:remove()
		titleScreen = nil
	end

	displayTitleScreen()

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
		if friendsModal == nil and shopModal == nil and avatarEditor == nil and createModal == nil and coinsModal == nil and alertModal == nil and secretModal == nil then
			menu:maximize()
		else
			menu:minimize()
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

		secretCount = nil
	end

	menu.inventoryAction = function(self)
		self:showAlert("⚠️ Work in progress!")
	end

	menu.shopAction = function(self)
		if shopModal ~= nil then
			updateModalPosition(shopModal, true) -- make it bounce
			return
		end

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
										self:showAlert(message)
									else
										self:showAlert("✅")
									end
									api.getBalance(function(err, balance)
										if err then return end
										menu.coinsBtn.Text = "" .. math.floor(balance.total) .. " 💰"
										menu:refresh()
									end)
								else
									self:showAlert("❌ Error")
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

				-- also size / position avatar camera
				-- (not when just bounding modal)
				if not modal.updatedPosition then
					camera2.Position = Camera.Position
					camera2.Rotation = Camera.Rotation

					Camera.Color = Color(100,100,100)
					Player.Layers = camera2.Layers
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
			menu.profileBtn:unselect()
			avatarEditor = nil
			refreshMenuDisplayMode()

			local anim = ease:outBack(camera2, 0.22, {
				onDone = function()
					Player.Layers = Camera.Layers
				end,
			})
			anim.TargetWidth = Screen.Width
			anim.Width = Screen.Width
			anim.TargetHeight = Screen.Height
			anim.Height = Screen.Height
			anim.TargetX = 0
			anim.TargetY = 0

			Camera.Color = Color(255,255,255)
		end

		refreshMenuDisplayMode()
	end

	menu.friendsAction = function()
		if friendsModal ~= nil then 
			updateModalPosition(friendsModal, true) -- make it bounce
			return
		end

		closeModals()

		menu.friendsBtn:select()
		menu:minimize()

		friendsModal = friends:create(maxModalWidth, maxModalHeight, updateModalPosition)

		friendsModal.didClose = function()
			menu.friendsBtn:unselect()
			friendsModal = nil
			refreshMenuDisplayMode()
		end
		
		refreshMenuDisplayMode()
	end

	menu.showAlert = function(self, message)
		if alertModal ~= nil then
			alertModal:bounce()
			return
		end

		closeModals()
		
		alertModal = alert:create(message)
		-- alertModal:setNegativeCallback("No", function() end)
		-- alertModal:setNeutralCallback("Hmmm...", function() end)

		alertModal.didClose = function()
			alertModal = nil
			refreshMenuDisplayMode()
		end
		refreshMenuDisplayMode()
	end

	menu.settingsAction = function()
		closeModals()
		openSettings()
	end

	menu.exploreAction = function()
		closeModals()
		gotoExplore()
		hideUI()
	end

	menu.createAction = function(self)
		if isAnonymous ~= nil and isAnonymous() then -- Account actions (login, username, password)
			self:showAlert("💬 You need a username to create!")
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
	kCameraPositionY = 80
	yaw = -1.4 -- initial camera yaw value

	kCameraPositionRotating = Number3(Map.Width * 0.5, kCameraPositionY, Map.Depth * 0.4) * Map.Scale
	kCameraPositionRewardChest = Number3(Map.Width * 0.5, 75, Map.Depth * 0.4) * Map.Scale

	UI.Crosshair = false
	Client.DirectionalPad = nil
	Client.Action1 = nil
	Config.ChatAvailable = false
	Private.PauseAvailable = false

	Camera:SetModeFree()
	Camera.Position = kCameraPositionRotating
	Camera.Rotation = { 0, yaw, 0 } -- start right before the PARTICUBES text :)
	Pointer:Show()

	-- Called by C++ code when from within C++ UI.
	function backFromCPP()
		menu:show()
		showUI()
		ui:fitScreen() -- necessary when coming back from launched experience
		menu:refresh()
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
		ui:fitScreen()
		menu:refresh()
	end

	ui:fitScreen()
end

Client.OnPlayerJoin = function(p)
	if p ~= Player then return end
	-- place Player
	Player:RemoveFromParent()
	World:AddChild(Player)

	Player.Position = Number3(360, 350, 186)
	Player.Rotation = Number3(0.06, 2.37, 0)
	Player.Velocity.Y = 5
	Player.Physics = true
	Player:Wave(true)
end

Client.Tick = function(dt)
	-- ambiance manager has its own tick
	ambiance:tick()

	if account.shown then
		-- nothing for now
	else
		-- UP/DOWN MOVEMENT
		moveDT = moveDT + dt * 0.2
		-- keep moveDT between -pi & pi
		while moveDT > math.pi do
			moveDT = moveDT - pi2
		end
		Camera.Position.Y = (kCameraPositionY + math.sin(moveDT) * 5.0) * Map.Scale.Y

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
	uiCaptured = ui:pointerDown(pointerEvent)
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

Pointer.Up = function(pointerEvent)

	ui:pointerUp(pointerEvent)
	-- if not uiCaptured then
	
	-- end

	uiCaptured = false
end

-- AMBIANCE TRANSITIONS

ambiance = {
	fadingToCustom = false, -- normal -> custom
	fadingToTimeCycle = false, -- custom -> normal
	customColor = {
		abyss = nil,
		ambientLight = nil,
		horizonColor = nil,
		skyColor = nil,
		skyLightColor = nil,
	},

	save = {
		timeCycleDuration = nil,
		timeCycleNoon = nil,
		timeCycleDusk = nil,
	},
	
	tick = function(self, dt)
		if self.fadingToCustom == true then
			-- TimeCyle is currently cycling between Noon & Dusk
			if Time.Current.H >= 18 then -- Dusk has been reached (18h)
				Time.Current = Time.Dusk
				TimeCycle.On = false
				self.fadingToCustom = false
			end

		elseif self.fadingToTimeCycle == true then
			if Time.Current.H >= 18 then
				
				TimeCycle.Marks.Noon.AbyssColor = self.save.timeCycleNoon.AbyssColor
				TimeCycle.Marks.Noon.AmbientLightColor = self.save.timeCycleNoon.AmbientLightColor
				TimeCycle.Marks.Noon.HorizonColor = self.save.timeCycleNoon.HorizonColor
				TimeCycle.Marks.Noon.SkyColor = self.save.timeCycleNoon.SkyColor
				TimeCycle.Marks.Noon.SkyLightColor = self.save.timeCycleNoon.SkyLightColor

				Time.Current = Time.Noon

				TimeCycle.Marks.Dusk.AbyssColor = self.save.timeCycleDusk.AbyssColor
				TimeCycle.Marks.Dusk.AmbientLightColor = self.save.timeCycleDusk.AmbientLightColor
				TimeCycle.Marks.Dusk.HorizonColor = self.save.timeCycleDusk.HorizonColor
				TimeCycle.Marks.Dusk.SkyColor = self.save.timeCycleDusk.SkyColor
				TimeCycle.Marks.Dusk.SkyLightColor = self.save.timeCycleDusk.SkyLightColor
				
				TimeCycle.Duration = self.save.timeCycleDuration
				TimeCycle.On = true
	
				self.fadingToTimeCycle = false
			end
		end
	end,

	explore = function(self)

		self:fadeToCustomAmbiance(0.5,
								  Color(95, 151, 228),
								  Color(95, 151, 228),
								  Color(95, 151, 228),
								  Color(95, 151, 228),
								  Color(95, 151, 228))

	end,

	build = function(self)

		self:fadeToCustomAmbiance(0.5,
								  Color(220, 160, 88),
								  Color(220, 160, 88),
								  Color(220, 160, 88),
								  Color(220, 160, 88),
								  Color(220, 160, 88))

	end,

	clear = function(self)

		self:fadeToCustomAmbiance(0.5,
								  Color(0, 93, 127),
								  Color(0, 95, 139),
								  Color(153, 242, 255),
								  Color(0, 174, 255),
								  Color(255, 255, 234))

	end,

	fadeToCustomAmbiance = function(self, durationSec, abyss, ambientLight, horizonColor, skyColor, skyLightColor)
		if self.fadingToTimeCycle == true then 
			self.fadingToTimeCycle = false
		end
				
		self.customColor.abyss = abyss
		self.customColor.ambientLight = ambientLight
		self.customColor.horizonColor = horizonColor
		self.customColor.skyColor = skyColor
		self.customColor.skyLightColor = skyLightColor

		self.fadingToCustom = true
		
		-- get current ambiance
		local currentMark = TimeCycleMark(Time.Current)
		
		-- modify Noon (set new value of TimeCycle.Marks.Noon to currentMark colors)
		TimeCycle.Marks.Noon.AbyssColor = currentMark.AbyssColor
		TimeCycle.Marks.Noon.AmbientLightColor = currentMark.AmbientLightColor
		TimeCycle.Marks.Noon.HorizonColor = currentMark.HorizonColor
		TimeCycle.Marks.Noon.SkyColor = currentMark.SkyColor
		TimeCycle.Marks.Noon.SkyLightColor = currentMark.SkyLightColor

		-- Set current time to Noon
		Time.Current = Time.Noon

		-- remove currentMark from the TimeCycle
		if #TimeCycle.Marks > 4 then
			TimeCycle:RemoveMark(currentMark)
		end

		-- modify Dusk (with custom colors)
		TimeCycle.Marks.Dusk.AbyssColor = self.customColor.abyss
		TimeCycle.Marks.Dusk.AmbientLightColor = self.customColor.ambientLight
		TimeCycle.Marks.Dusk.HorizonColor = self.customColor.horizonColor
		TimeCycle.Marks.Dusk.SkyColor = self.customColor.skyColor
		TimeCycle.Marks.Dusk.SkyLightColor = self.customColor.skyLightColor

		-- Set custom TimeCycle duration
		TimeCycle.Duration = durationSec * 4.0

		-- Make sure the TimeCycle is ON
		TimeCycle.On = true
	end,
}

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

		-- place Camera
		Camera.Rotation = {0.05, 5.5, 0}
		Camera.Position = Number3(380, 300, 165)

		-- place Player
		Player:RemoveFromParent()
		World:AddChild(Player)

		Player.Position = Number3(360, 350, 186)
		Player.Rotation = Number3(0.06, 2.37, 0)
		Player.Velocity.Y = 5
		Player.Physics = true
		Player:Wave(true)
	end,
	hideAvatar = function(self)
		if not self.shown then return end
		self.shown = false
		
		Player:Wave(false)
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
	inventoryAction = nil,
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
		self.friendsBtn.Text = "❤️"
		if self.nbFriends > 0 then
			self.friendsBtn.Text = self.friendsBtn.Text .. "(" .. self.nbFriends .. ")"
		end
		self.inventoryBtn.Text = "🎒"

		self.shopBtn.Text = "✨"

		self.discordBtn:setParent(nil)

		self:refresh()
	end,

	maximize = function(self)
		if self.minimized == false then
			return
		end
		self.minimized = false

		self:refreshProfileBtn()
		self.friendsBtn.Text = "❤️ Friends"
		if self.nbFriends > 0 then
			self.friendsBtn.Text = self.friendsBtn.Text .. "(" .. self.nbFriends .. ")"
		end

		self.shopBtn.Text = "Gallery ✨"
		self.inventoryBtn.Text = "Inventory 🎒"

		if not self.discordBtn.parent then 
			self.discordBtn:setParent(self.topRight)
		end

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

			self.inventoryBtn.LocalPosition = {0, 0, 0}
			self.shopBtn.LocalPosition = {self.inventoryBtn.Width + self.padding, 0, 0}
			self.coinsBtn.LocalPosition = {self.shopBtn.LocalPosition.X + self.shopBtn.Width + self.padding, 0, 0}
		else
			if self.hidden == false and self.bottom.object:GetParent() == nil then self.bottom:setParent(ui.rootFrame) end

			local accountBtnsTotalHeight = 0
			-- at the beginning, Lua functions are nil
			if isAnonymous ~= nil then -- Account actions (login, username, password)
				if isAnonymous() then -- show a frame with 2 buttons (login & set password)
					self.accountFrame:setParent(self.topLeft)
					self.accountFrame:parentDidResize()
					accountBtnsTotalHeight = accountBtnsTotalHeight + self.accountFrame.Height + self.padding
				else -- not anonymous
					local _hasPassword = hasPassword()
					local _hasEmail = hasEmail()
					local _isUnder13 = isUnder13()
					accountBtnsTotalHeight = self.padding
					if _hasPassword == false then
						-- show button to set password
						self.setPasswordBtn:setParent(self.topLeft)
						self.setPasswordBtn.LocalPosition.Y = accountBtnsTotalHeight
						accountBtnsTotalHeight = accountBtnsTotalHeight + self.setPasswordBtn.Height + self.padding
					end
					if _hasEmail == false and _isUnder13 == false then
						-- show button to set email
						self.setEmailBtn:setParent(self.topLeft)
						self.setEmailBtn.LocalPosition.Y = accountBtnsTotalHeight
						accountBtnsTotalHeight = accountBtnsTotalHeight + self.setEmailBtn.Height + self.padding
					end
				end
			end

			self.friendsBtn.LocalPosition = {0, accountBtnsTotalHeight, 0}
			self.profileBtn.LocalPosition = {0, self.friendsBtn.LocalPosition.Y + self.friendsBtn.Height + self.padding, 0}
			self.settingsBtn.LocalPosition = {self.profileBtn.Width + self.padding, self.profileBtn.LocalPosition.Y, 0}

			local w = self.topRight.Width

			self.discordBtn.LocalPosition = {w - self.discordBtn.Width, 0, 0}
			-- TEST
			-- ease:outQuad(self.discordBtn,1.0).LocalPosition = Number3(w - self.discordBtn.Width, 0, 0)

			self.inventoryBtn.LocalPosition = {w - self.inventoryBtn.Width, self.discordBtn.LocalPosition.Y + self.discordBtn.Height + self.padding, 0}
			self.shopBtn.LocalPosition = {w - self.shopBtn.Width, self.inventoryBtn.LocalPosition.Y + self.inventoryBtn.Height + self.padding, 0}
			self.coinsBtn.LocalPosition = {w - self.coinsBtn.Width, self.shopBtn.LocalPosition.Y + self.shopBtn.Height + self.padding, 0}

			local w = self.exploreBtn.Width + self.padding + self.createButton.Width
			self.exploreBtn.LocalPosition = {-(w * 0.5), 0, 0}
			self.createButton.LocalPosition = {self.exploreBtn.LocalPosition.X + self.padding + self.exploreBtn.Width, 0, 0}

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
			-- print(self.friendsAction, self.friendsBtn, self.friendsBtn.select)
			if self.friendsAction ~= nil then self.friendsAction() end
		end
		-- TODO: remove recipient when it is removed/destroyed
		messenger:addRecipient(self.friendsBtn, friends.kNotifFriendsUpdated, function(r,n,d)
			self.nbFriends = #d
			if self.minimized then
				r.Text = "❤️"
			else
				r.Text = "❤️ Friends"
			end
			if self.nbFriends > 0 then
				r.Text = r.Text .. "(" .. self.nbFriends .. ")"
			end
			self:refresh()
		end)

		-- Frame box buttons for account actions (login/username)
		self.accountFrame = ui:createFrame(Color(0, 0, 0, 128))
		self.accountFrame.LocalPosition.Z = 0
		self.accountFrame.parentDidResize = function(frame)
			frame.Width = math.max(self.accountAnonText.Width, self.pickUsernameBtn.Width) + (2 * self.padding)
			frame.Height = self.accountAnonText.Height + self.pickUsernameBtn.Height + self.loginBtn.Height + (4 * self.padding)
		end

		self.accountAnonText = ui:createText("You are a guest")
		self.accountAnonText.Color = Color(255, 255, 255, 255)
		self.accountAnonText:setParent(self.accountFrame)
		self.accountAnonText.parentDidResize = function(selfText)
			selfText.LocalPosition.X = self.padding
			selfText.LocalPosition.Y = selfText.parent.Height - selfText.Height - self.padding
		end

		self.pickUsernameBtn = ui:createButton("🧪 Pick username")
		self.pickUsernameBtn:setParent(self.accountFrame)
		self.pickUsernameBtn.parentDidResize = function(selfBtn)
			selfBtn.LocalPosition.X = self.padding
			selfBtn.LocalPosition.Y = selfBtn.parent.Height - self.accountAnonText.Height - selfBtn.Height - (2 * self.padding)
		end
		self.pickUsernameBtn.onRelease = function()
			promptForUsername()
		end

		self.loginBtn = ui:createButton("🔑 Login")
		self.loginBtn:setParent(self.accountFrame)
		self.loginBtn.parentDidResize = function(selfBtn)
			selfBtn.LocalPosition.X = self.padding
			selfBtn.LocalPosition.Y = self.padding
		end
		self.loginBtn.onRelease = function()
			login()
		end

		self.accountFrame:parentDidResize()

		-- Buttons for email/password
		self.setPasswordBtn = ui:createButton("🔑 Set password")
		self.setPasswordBtn.onRelease = function()
			promptForPassword()
		end
		self.setEmailBtn = ui:createButton("Set email")
		self.setEmailBtn.onRelease = function()
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

		self.inventoryBtn = ui:createButton("🎒 Inventory")
		self.inventoryBtn:setParent(self.topRight)
		self.inventoryBtn.onRelease = function()
			if self.inventoryAction ~= nil then self:inventoryAction() end
		end

		self.discordBtn = ui:createButton("👾 Need help?")
		self.discordBtn:setColor(theme.colorDiscord, Color.White)
		self.discordBtn:setParent(self.topRight)
		self.discordBtn.onRelease = function()
			-- if self.discordBtn ~= nil then self:shopAction() end
			URL:Open("https://cu.bzh/discord")
		end

		-- BOTTOM

		self.exploreBtn = ui:createButton("🌎 Explore", {textSize ="big"})
		self.exploreBtn:setParent(self.bottom)
		self.exploreBtn:setColor(theme.colorExplore, Color.White)
		self.exploreBtn.onRelease = function()
			if self.exploreAction ~= nil then self:exploreAction() end
		end

		self.createButton = ui:createButton("🏗️ Create", {textSize ="big"})
		self.createButton:setParent(self.bottom)
		self.createButton:setColor(theme.colorCreate, Color.White)
		self.createButton.onRelease = function()
			if self.createAction ~= nil then self:createAction() end
		end

		self:maximize() -- start with maximized ui
		self:show()
	end,
}
