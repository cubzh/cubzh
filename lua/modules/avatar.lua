mod = {}

-- storage for avatar instances' private fields
-- (allows to check if a table is in fact an avatar)
-- { config = {},
--   equipments = { equipmentType = { request = onGoingRequest, shapes = {} }, ... },
--   requests = {},
--   palette = Palette()
-- }
avatarPrivateFields = setmetatable({}, { __mode = "k" })

-- MODULES
api = require("api")
bundle = require("bundle")
hierarchyactions = require("hierarchyactions")

function emptyFunc() end

local SKIN_1_PALETTE_INDEX = 1
local SKIN_2_PALETTE_INDEX = 2
local CLOTH_PALETTE_INDEX = 3
local MOUTH_PALETTE_INDEX = 4
local EYES_WHITE_PALETTE_INDEX = 5
local EYES_PALETTE_INDEX = 6
local NOSE_PALETTE_INDEX = 7
local EYES_DARK_PALETTE_INDEX = 8

-- bodyPartsNames = {
-- 	"Head",
-- 	"Body",
-- 	"RightArm",
-- 	"RightHand",
-- 	"LeftArm",
-- 	"LeftHand",
-- 	"RightLeg",
-- 	"LeftLeg",
-- 	"RightFoot",
-- 	"LeftFoot",
-- 	"EyeLidRight",
-- 	"EyeLidLeft",
-- }

cachedHead = bundle:Shape("shapes/head_skin2_v2")

mod.eyeColors = {
	Color(80, 80, 80),
	Color(166, 142, 163),
	Color(68, 172, 229),
	Color(61, 204, 141),
	Color(127, 80, 51),
	Color(51, 38, 29),
	Color(229, 114, 189),
	Color(80, 80, 80),
}

local DEFAULT_EYES_COLOR_INDEX = 1
mod.defaultEyesColorIndex = DEFAULT_EYES_COLOR_INDEX

mod.skinColors = {
	{
		skin1 = Color(246, 227, 208),
		skin2 = Color(246, 216, 186),
		nose = Color(246, 210, 175),
		mouth = Color(220, 188, 157),
	},
	{
		skin1 = Color(252, 202, 156),
		skin2 = Color(252, 186, 129),
		nose = Color(249, 167, 117),
		mouth = Color(216, 162, 116),
	},
	{
		skin1 = Color(255, 194, 173),
		skin2 = Color(255, 178, 152),
		nose = Color(255, 162, 133),
		mouth = Color(217, 159, 140),
	},
	{
		skin1 = Color(182, 129, 108),
		skin2 = Color(183, 117, 94),
		nose = Color(189, 114, 80),
		mouth = Color(153, 102, 79),
	},
	{
		skin1 = Color(156, 92, 88),
		skin2 = Color(136, 76, 76),
		nose = Color(135, 64, 68),
		mouth = Color(109, 63, 61),
	},
	{
		skin1 = Color(140, 96, 64),
		skin2 = Color(124, 82, 52),
		nose = Color(119, 76, 45),
		mouth = Color(104, 68, 43),
	},
	{
		skin1 = Color(59, 46, 37),
		skin2 = Color(53, 41, 33),
		nose = Color(47, 33, 25),
		mouth = Color(47, 36, 29),
	},
	{ -- 8
		skin1 = Color(108, 194, 231),
		skin2 = Color(100, 158, 192),
		nose = Color(98, 147, 189),
		mouth = Color(113, 169, 200),
	},
}

local DEFAULT_BODY_COLOR = 8
mod.defaultSkinColorIndex = DEFAULT_BODY_COLOR

mod.eyes = {
	{
		-- right eye
		{ x = 1, y = 1, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 1, c = EYES_PALETTE_INDEX },
		{ x = 3, y = 1, c = EYES_PALETTE_INDEX },

		{ x = 1, y = 2, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 2, c = EYES_PALETTE_INDEX },
		{ x = 3, y = 2, c = EYES_DARK_PALETTE_INDEX },

		{ x = 1, y = 3, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 3, c = EYES_PALETTE_INDEX },
		{ x = 3, y = 3, c = EYES_DARK_PALETTE_INDEX },

		{ x = 1, y = 4, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 4, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 3, y = 4, c = EYES_WHITE_PALETTE_INDEX },

		-- left eye
		{ x = 9, y = 1, c = EYES_PALETTE_INDEX },
		{ x = 10, y = 1, c = EYES_PALETTE_INDEX },
		{ x = 11, y = 1, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 9, y = 2, c = EYES_DARK_PALETTE_INDEX },
		{ x = 10, y = 2, c = EYES_PALETTE_INDEX },
		{ x = 11, y = 2, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 9, y = 3, c = EYES_DARK_PALETTE_INDEX },
		{ x = 10, y = 3, c = EYES_PALETTE_INDEX },
		{ x = 11, y = 3, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 9, y = 4, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 10, y = 4, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 11, y = 4, c = EYES_WHITE_PALETTE_INDEX },
	},
	{
		-- right eye
		{ x = 1, y = 1, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 1, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 3, y = 1, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 1, y = 2, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 2, c = EYES_DARK_PALETTE_INDEX },
		{ x = 3, y = 2, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 1, y = 3, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 3, c = EYES_DARK_PALETTE_INDEX },
		{ x = 3, y = 3, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 1, y = 4, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 4, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 3, y = 4, c = EYES_WHITE_PALETTE_INDEX },

		-- left eye
		{ x = 9, y = 1, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 10, y = 1, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 11, y = 1, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 9, y = 2, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 10, y = 2, c = EYES_DARK_PALETTE_INDEX },
		{ x = 11, y = 2, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 9, y = 3, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 10, y = 3, c = EYES_DARK_PALETTE_INDEX },
		{ x = 11, y = 3, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 9, y = 4, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 10, y = 4, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 11, y = 4, c = EYES_WHITE_PALETTE_INDEX },
	},
	{
		-- right eye
		{ x = 1, y = 1, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 1, c = EYES_DARK_PALETTE_INDEX },
		{ x = 3, y = 1, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 1, y = 2, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 2, c = EYES_PALETTE_INDEX },
		{ x = 3, y = 2, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 1, y = 3, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 3, c = EYES_PALETTE_INDEX },
		{ x = 3, y = 3, c = EYES_WHITE_PALETTE_INDEX },

		-- left eye
		{ x = 9, y = 1, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 10, y = 1, c = EYES_DARK_PALETTE_INDEX },
		{ x = 11, y = 1, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 9, y = 2, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 10, y = 2, c = EYES_PALETTE_INDEX },
		{ x = 11, y = 2, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 9, y = 3, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 10, y = 3, c = EYES_PALETTE_INDEX },
		{ x = 11, y = 3, c = EYES_WHITE_PALETTE_INDEX },
	},
	{
		-- right eye
		{ x = 1, y = 1, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 1, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 3, y = 1, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 1, y = 2, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 2, c = EYES_DARK_PALETTE_INDEX },
		{ x = 3, y = 2, c = EYES_DARK_PALETTE_INDEX },

		{ x = 1, y = 3, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 3, c = EYES_DARK_PALETTE_INDEX },
		{ x = 3, y = 3, c = EYES_DARK_PALETTE_INDEX },

		{ x = 1, y = 4, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 4, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 3, y = 4, c = EYES_WHITE_PALETTE_INDEX },

		-- left eye
		{ x = 9, y = 1, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 10, y = 1, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 11, y = 1, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 9, y = 2, c = EYES_DARK_PALETTE_INDEX },
		{ x = 10, y = 2, c = EYES_DARK_PALETTE_INDEX },
		{ x = 11, y = 2, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 9, y = 3, c = EYES_DARK_PALETTE_INDEX },
		{ x = 10, y = 3, c = EYES_DARK_PALETTE_INDEX },
		{ x = 11, y = 3, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 9, y = 4, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 10, y = 4, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 11, y = 4, c = EYES_WHITE_PALETTE_INDEX },
	},
	{
		-- right eye
		{ x = 2, y = 1, c = EYES_DARK_PALETTE_INDEX },
		{ x = 3, y = 1, c = EYES_DARK_PALETTE_INDEX },

		{ x = 2, y = 2, c = EYES_DARK_PALETTE_INDEX },
		{ x = 3, y = 2, c = EYES_DARK_PALETTE_INDEX },

		-- left eye
		{ x = 9, y = 1, c = EYES_DARK_PALETTE_INDEX },
		{ x = 10, y = 1, c = EYES_DARK_PALETTE_INDEX },

		{ x = 9, y = 2, c = EYES_DARK_PALETTE_INDEX },
		{ x = 10, y = 2, c = EYES_DARK_PALETTE_INDEX },
	},
	{
		-- right eye
		{ x = 1, y = 1, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 1, c = EYES_DARK_PALETTE_INDEX },
		{ x = 3, y = 1, c = EYES_DARK_PALETTE_INDEX },

		{ x = 1, y = 2, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 2, c = EYES_DARK_PALETTE_INDEX },
		{ x = 3, y = 2, c = EYES_PALETTE_INDEX },

		{ x = 1, y = 3, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 2, y = 3, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 3, y = 3, c = EYES_WHITE_PALETTE_INDEX },

		-- left eye
		{ x = 9, y = 1, c = EYES_DARK_PALETTE_INDEX },
		{ x = 10, y = 1, c = EYES_DARK_PALETTE_INDEX },
		{ x = 11, y = 1, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 9, y = 2, c = EYES_PALETTE_INDEX },
		{ x = 10, y = 2, c = EYES_DARK_PALETTE_INDEX },
		{ x = 11, y = 2, c = EYES_WHITE_PALETTE_INDEX },

		{ x = 9, y = 3, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 10, y = 3, c = EYES_WHITE_PALETTE_INDEX },
		{ x = 11, y = 3, c = EYES_WHITE_PALETTE_INDEX },
	},
}

local DEFAULT_EYES_INDEX = 1
mod.defaultEyesIndex = DEFAULT_EYES_INDEX

mod.noses = {
	{
		{ x = 1, y = 1, c = NOSE_PALETTE_INDEX },
		{ x = 2, y = 1, c = NOSE_PALETTE_INDEX },
		{ x = 3, y = 1, c = NOSE_PALETTE_INDEX },
	},
	{
		{ x = 2, y = 1, c = NOSE_PALETTE_INDEX },
		{ x = 2, y = 2, c = NOSE_PALETTE_INDEX },
		{ x = 2, y = 3, c = NOSE_PALETTE_INDEX },
	},
	{
		{ x = 2, y = 1, c = NOSE_PALETTE_INDEX },
		{ x = 2, y = 2, c = NOSE_PALETTE_INDEX },
	},
	{
		{ x = 2, y = 1, c = NOSE_PALETTE_INDEX },
	},
	{},
	{
		{ x = 1, y = 1, c = NOSE_PALETTE_INDEX },
		{ x = 2, y = 1, c = NOSE_PALETTE_INDEX },
		{ x = 3, y = 1, c = NOSE_PALETTE_INDEX },

		{ x = 1, y = 2, c = NOSE_PALETTE_INDEX },
		{ x = 2, y = 2, c = NOSE_PALETTE_INDEX },
		{ x = 3, y = 2, c = NOSE_PALETTE_INDEX },
	},
	{
		{ x = 1, y = 1, c = NOSE_PALETTE_INDEX },
		{ x = 2, y = 1, c = NOSE_PALETTE_INDEX },
		{ x = 3, y = 1, c = NOSE_PALETTE_INDEX },

		{ x = 1, y = 2, c = NOSE_PALETTE_INDEX },
		{ x = 2, y = 2, c = NOSE_PALETTE_INDEX },
		{ x = 3, y = 2, c = NOSE_PALETTE_INDEX },

		{ x = 2, y = 3, c = NOSE_PALETTE_INDEX },
	},
	{
		{ x = 1, y = 1, c = NOSE_PALETTE_INDEX },
		{ x = 2, y = 1, c = NOSE_PALETTE_INDEX },
		{ x = 3, y = 1, c = NOSE_PALETTE_INDEX },

		{ x = 1, y = 2, c = NOSE_PALETTE_INDEX },
		{ x = 2, y = 2, c = NOSE_PALETTE_INDEX },
		{ x = 3, y = 2, c = NOSE_PALETTE_INDEX },

		{ x = 1, y = 3, c = NOSE_PALETTE_INDEX },
		{ x = 2, y = 3, c = NOSE_PALETTE_INDEX },
		{ x = 3, y = 3, c = NOSE_PALETTE_INDEX },
	},
	{
		{ x = 1, y = 1, c = NOSE_PALETTE_INDEX },
		{ x = 2, y = 1, c = NOSE_PALETTE_INDEX },
		{ x = 3, y = 1, c = NOSE_PALETTE_INDEX },

		{ x = 2, y = 2, c = NOSE_PALETTE_INDEX },

		{ x = 2, y = 3, c = NOSE_PALETTE_INDEX },
	},
	{
		{ x = 1, y = 1, c = NOSE_PALETTE_INDEX },
		{ x = 2, y = 1, c = NOSE_PALETTE_INDEX },
		{ x = 3, y = 1, c = NOSE_PALETTE_INDEX },

		{ x = 2, y = 2, c = NOSE_PALETTE_INDEX },
	},
	{
		{ x = 2, y = 1, c = NOSE_PALETTE_INDEX },

		{ x = 2, y = 2, c = NOSE_PALETTE_INDEX },

		{ x = 1, y = 3, c = NOSE_PALETTE_INDEX },
		{ x = 2, y = 3, c = NOSE_PALETTE_INDEX },
		{ x = 3, y = 3, c = NOSE_PALETTE_INDEX },
	},
	{
		{ x = 2, y = 1, c = NOSE_PALETTE_INDEX },

		{ x = 1, y = 2, c = NOSE_PALETTE_INDEX },
		{ x = 2, y = 2, c = NOSE_PALETTE_INDEX },
		{ x = 3, y = 2, c = NOSE_PALETTE_INDEX },
	},
}

local DEFAULT_NOSE_INDEX = 1
mod.defaultNoseIndex = DEFAULT_NOSE_INDEX

avatarPalette = Palette()
avatarPalette:AddColor(mod.skinColors[DEFAULT_BODY_COLOR].skin1) -- skin 1
avatarPalette:AddColor(mod.skinColors[DEFAULT_BODY_COLOR].skin2) -- skin 2
avatarPalette:AddColor(Color(231, 230, 208)) -- cloth
avatarPalette:AddColor(mod.skinColors[DEFAULT_BODY_COLOR].mouth) -- mouth
avatarPalette:AddColor(Color(255, 255, 255)) -- eyes white
avatarPalette:AddColor(Color(50, 50, 50)) -- eyes
avatarPalette:AddColor(mod.skinColors[DEFAULT_BODY_COLOR].nose) -- nose
avatarPalette:AddColor(Color(10, 10, 10)) -- eyes dark

function initAnimations(avatar)
	local leftLegOrigin = avatar.LeftLeg.LocalPosition:Copy()
	local rightLegOrigin = avatar.RightLeg.LocalPosition:Copy()

	local animWalk = Animation("Walk", { speed = 1.8, loops = 0, priority = 2 })
	local walk_llegK = {
		{ time = 0.0, rotation = { -1.1781, 0, 0 } },
		{ time = 1 / 6, rotation = { -0.785398, 0, 0 } },
		{ time = 1 / 3, rotation = { 0.785398, 0, 0 } },
		{ time = 1 / 2, rotation = { 1.1781, 0, 0 } },
		{ time = 2 / 3, rotation = { 0.392699, 0, 0 } },
		{ time = 5 / 6, rotation = { -1.1781, 0, 0 } },
		{ time = 1.0, rotation = { -1.1781, 0, 0 } },
	}
	local walk_lfootK = {
		{ time = 0.0, rotation = { 0, 0, 0 } },
		{ time = 1 / 6, rotation = { 0.687223, 0, 0 } },
		{ time = 1 / 3, rotation = { -0.392699, 0, 0 } },
		{ time = 1 / 2, rotation = { 0.785398, 0, 0 } },
		{ time = 2 / 3, rotation = { 1.1781, 0, 0 } },
		{ time = 5 / 6, rotation = { 1.9635, 0, 0 } },
		{ time = 1.0, rotation = { 0, 0, 0 } },
	}
	local walk_rlegK = {
		{ time = 0.0, rotation = { 1.1781, 0, 0 } },
		{ time = 1 / 6, rotation = { 0.392699, 0, 0 } },
		{ time = 1 / 3, rotation = { -1.1781, 0, 0 } },
		{ time = 1 / 2, rotation = { -1.1781, 0, 0 } },
		{ time = 2 / 3, rotation = { -0.785398, 0, 0 } },
		{ time = 5 / 6, rotation = { 0.785398, 0, 0 } },
		{ time = 1.0, rotation = { 1.1781, 0, 0 } },
	}
	local walk_rfootK = {
		{ time = 0.0, rotation = { 0.785398, 0, 0 } },
		{ time = 1 / 6, rotation = { 1.1781, 0, 0 } },
		{ time = 1 / 3, rotation = { 1.9635, 0, 0 } },
		{ time = 1 / 2, rotation = { 0, 0, 0 } },
		{ time = 2 / 3, rotation = { 0.687223, 0, 0 } },
		{ time = 5 / 6, rotation = { -0.392699, 0, 0 } },
		{ time = 1.0, rotation = { 0.785398, 0, 0 } },
	}
	local walk_larmK = {
		{ time = 0.0, rotation = { 1.1781, 0, 1.0472 } },
		{ time = 1 / 6, rotation = { 0.589049, 0.19635, 1.0472 } },
		{ time = 1 / 3, rotation = { 0.19635, 0, 1.0472 } },
		{ time = 1 / 2, rotation = { -1.37445, 0.19635, 1.0472 } },
		{ time = 2 / 3, rotation = { -0.589049, 0, 1.0472 } },
		{ time = 5 / 6, rotation = { 0.19635, 0, 1.0472 } },
		{ time = 1.0, rotation = { 1.1781, 0, 1.0472 } },
	}
	local walk_lhandK = {
		{ time = 0.0, rotation = { 0, 0.245437, 0.294524 } },
		{ time = 1 / 6, rotation = { 0, 0.785398, 0 } },
		{ time = 1 / 3, rotation = { 0, 1.1781, 0 } },
		{ time = 1 / 2, rotation = { 0, 0.19635, 0 } },
		{ time = 2 / 3, rotation = { 0, 0.589049, 0 } },
		{ time = 5 / 6, rotation = { 0, 0.392699, 0.0981748 } },
		{ time = 1.0, rotation = { 0, 0.245437, 0.294524 } },
	}
	local walk_rarmK = {
		{ time = 0.0, rotation = { -1.37445, -0.19635, -1.0472 } },
		{ time = 1 / 6, rotation = { -0.589049, 0, -1.0472 } },
		{ time = 1 / 3, rotation = { 0.19635, 0, -1.0472 } },
		{ time = 1 / 2, rotation = { 1.1781, 0, -1.0472 } },
		{ time = 2 / 3, rotation = { 0.589049, 0.19635, -1.0472 } },
		{ time = 5 / 6, rotation = { 0.19635, 0, -1.0472 } },
		{ time = 1.0, rotation = { -1.37445, -0.19635, -1.0472 } },
	}
	local walk_rhandK = {
		{ time = 0.0, rotation = { 0, -0.19635, 0 } },
		{ time = 1 / 6, rotation = { 0, -0.589049, 0 } },
		{ time = 1 / 3, rotation = { 0, -0.392699, -0.0981748 } },
		{ time = 1 / 2, rotation = { 0, -0.245437, -0.294524 } },
		{ time = 2 / 3, rotation = { 0, -0.785398, 0 } },
		{ time = 5 / 6, rotation = { 0, -1.1781, 0 } },
		{ time = 1.0, rotation = { 0, -0.19635, 0 } },
	}
	local walk_bodyK = {
		{ time = 0.0, position = { 0.0, 15.0, 0.0 }, rotation = { 0, 0, 0 } },
		{ time = 1 / 6, position = { 0.0, 12.0, 0.0 }, rotation = { 0, 0, 0 } },
		{ time = 1 / 3, position = { 0.0, 14.0, 0.0 }, rotation = { 0, 0, 0 } },
		{ time = 1 / 2, position = { 0.0, 15.0, 0.0 }, rotation = { 0, 0, 0 } },
		{ time = 2 / 3, position = { 0.0, 12.0, 0.0 }, rotation = { 0, 0, 0 } },
		{ time = 5 / 6, position = { 0.0, 14.0, 0.0 }, rotation = { 0, 0, 0 } },
		{ time = 1.0, position = { 0.0, 15.0, 0.0 }, rotation = { 0, 0, 0 } },
	}
	local walkConfig = {
		RightArm = walk_rarmK,
		RightHand = walk_rhandK,
		LeftArm = walk_larmK,
		LeftHand = walk_lhandK,
		RightLeg = walk_rlegK,
		RightFoot = walk_rfootK,
		LeftLeg = walk_llegK,
		LeftFoot = walk_lfootK,
		Body = walk_bodyK,
	}

	local owner
	for name, v in pairs(walkConfig) do
		for _, frame in ipairs(v) do
			owner = (name == "Body" and not avatar[name]) and avatar or avatar[name]
			if owner ~= nil then
				animWalk:AddFrameInGroup(name, frame.time, { position = frame.position, rotation = frame.rotation })
				animWalk:Bind(name, owner)
			end
		end
	end

	local yOffset = 0.4
	local animIdle = Animation("Idle", { speed = 0.5, loops = 0 })
	local idle_keyframes_data = {
		{ name = "LeftLeg", time = 0.0, position = leftLegOrigin, rotation = { 0, 0, 0 } },
		{ name = "LeftLeg", time = 0.5, position = leftLegOrigin + { 0.0, yOffset, 0.0 }, rotation = { 0, 0, 0 } },
		{ name = "LeftLeg", time = 1.0, position = leftLegOrigin, rotation = { 0, 0, 0 } },
		{ name = "LeftFoot", time = 0.0, rotation = { 0, 0, 0 } },
		{ name = "LeftFoot", time = 0.5, rotation = { 0, 0, 0 } },
		{ name = "LeftFoot", time = 1.0, rotation = { 0, 0, 0 } },
		{ name = "RightLeg", time = 0.0, position = rightLegOrigin, rotation = { 0, 0, 0 } },
		{ name = "RightLeg", time = 0.5, position = rightLegOrigin + { 0.0, yOffset, 0.0 }, rotation = { 0, 0, 0 } },
		{ name = "RightLeg", time = 1.0, position = rightLegOrigin, rotation = { 0, 0, 0 } },
		{ name = "RightFoot", time = 0.0, rotation = { 0, 0, 0 } },
		{ name = "RightFoot", time = 0.5, rotation = { 0, 0, 0 } },
		{ name = "RightFoot", time = 1.0, rotation = { 0, 0, 0 } },
		{ name = "LeftArm", time = 0.0, rotation = { 0, 0, 1.14537 + 0.1 } },
		{ name = "LeftArm", time = 0.5, rotation = { 0, 0, 1.14537 } },
		{ name = "LeftArm", time = 1.0, rotation = { 0, 0, 1.14537 + 0.1 } },
		{ name = "LeftHand", time = 0.0, rotation = { 0, 0.294524, -0.0981748 } },
		{ name = "LeftHand", time = 0.5, rotation = { 0, 0.19635, -0.0981748 } },
		{ name = "LeftHand", time = 1.0, rotation = { 0, 0.294524, -0.0981748 } },
		{ name = "RightArm", time = 0.0, rotation = { 0, 0, -1.14537 - 0.1 } },
		{ name = "RightArm", time = 0.5, rotation = { 0, 0, -1.14537 } },
		{ name = "RightArm", time = 1.0, rotation = { 0, 0, -1.14537 - 0.1 } },
		{ name = "RightHand", time = 0.0, rotation = { 0, -0.294524, 0 } },
		{ name = "RightHand", time = 0.5, rotation = { 0, -0.19635, 0 } },
		{ name = "RightHand", time = 1.0, rotation = { 0, -0.294524, 0 } },
		-- can't move head first person if head is set in animations
		-- { name = "Head", time = 0.0, rotation = { 0, 0, 0 } },
		-- { name = "Head", time = 0.5, rotation = { 0, 0, 0 } },
		-- { name = "Head", time = 1.0, rotation = { 0, 0, 0 } },
		{ name = "Body", time = 0.0, position = { 0.0, 12.0, 0.0 }, rotation = { 0, 0, 0 } },
		{ name = "Body", time = 0.5, position = { 0.0, 12.0 - yOffset, 0.0 }, rotation = { 0, 0, 0 } },
		{ name = "Body", time = 1.0, position = { 0.0, 12.0, 0.0 }, rotation = { 0, 0, 0 } },
	}

	for _, frame in ipairs(idle_keyframes_data) do
		animIdle:AddFrameInGroup(frame.name, frame.time, { position = frame.position, rotation = frame.rotation })
		animIdle:Bind(frame.name, (frame.name == "Body" and not avatar[frame.name]) and avatar or avatar[frame.name])
	end

	local animSwingRight = Animation("SwingRight", { speed = 3, priority = 1 })
	local swingRight_rightArm = {
		{ time = 0.0, rotation = { 0, 0, -1.0472 } },
		{ time = 1 / 3, rotation = { -0.785398, 0.392699, 0.1309 } },
		{ time = 2 / 3, rotation = { 0.392699, -1.9635, -0.261799 } },
		{ time = 1.0, rotation = { 0, 0, -1.0472 } },
	}
	local swingRight_rightHand = {
		{ time = 0.0, rotation = { 0, -0.392699, 0 } },
		{ time = 1 / 3, rotation = { -1.5708, -0.392699, 0 } },
		{ time = 2 / 3, rotation = { -2.74889, -1.5708, 0 } },
		{ time = 1.0, rotation = { 0, -0.392699, 0 } },
	}
	local swingRightConfig = {
		RightArm = swingRight_rightArm,
		RightHand = swingRight_rightHand,
	}
	for name, v in pairs(swingRightConfig) do
		for _, frame in ipairs(v) do
			animSwingRight:AddFrameInGroup(name, frame.time, { position = frame.position, rotation = frame.rotation })
			animSwingRight:Bind(name, (name == "Body" and not avatar[name]) and avatar or avatar[name])
		end
	end

	local animSwingLeft = Animation("SwingLeft", { speed = 3, priority = 1 })
	local swingLeft_leftArm = {
		{ time = 0.0, rotation = { 0, 0, -1.0472 } },
		{ time = 1 / 3, rotation = { -0.785398, 0.392699, 0.1309 } },
		{ time = 2 / 3, rotation = { 0.392699, -1.9635, -0.261799 } },
		{ time = 1.0, rotation = { 0, 0, -1.0472 } },
	}
	local swingLeft_leftHand = {
		{ time = 0.0, rotation = { 0, -0.392699, 0 } },
		{ time = 1 / 3, rotation = { -1.5708, -0.392699, 0 } },
		{ time = 2 / 3, rotation = { -2.74889, -1.5708, 0 } },
		{ time = 1.0, rotation = { 0, -0.392699, 0 } },
	}
	local swingLeftConfig = {
		LeftHand = swingLeft_leftHand,
		LeftArm = swingLeft_leftArm,
	}
	for name, v in pairs(swingLeftConfig) do
		for _, frame in ipairs(v) do
			animSwingLeft:AddFrameInGroup(name, frame.time, { position = frame.position, rotation = frame.rotation })
			animSwingLeft:Bind(name, (name == "Body" and not avatar[name]) and avatar or avatar[name])
		end
	end

	local anims = require("animations")()
	anims.Walk = animWalk
	anims.Idle = animIdle
	anims.SwingRight = animSwingRight
	anims.SwingLeft = animSwingLeft

	avatar.Animations = anims

	anims.Idle:Play()
end

avatarDefaultConfig = {
	usernameOrId = "", -- item repo and name (like "aduermael.hair")
	didLoad = emptyFunc, -- function(err) end
	eyeBlinks = true,
	defaultAnimations = true,
	loadEquipments = true,
}

-- Returns sent requests
-- /!\ return table of requests does not contain all requests right away
-- reference should be kept, not copying entries right after function call.
mod.getPlayerHead = function(self, config)
	if self ~= mod then
		error("avatar:getPlayerHead(config) should be called with `:`", 2)
	end

	-- LEGACY
	if type(config) == "string" then
		config = {
			usernameOrId = config, -- parameter used to be usernameOrId
		}
	end

	ok, err = pcall(function()
		config = require("config"):merge(avatarDefaultConfig, config)
	end)
	if not ok then
		error("avatar:getPlayerHead(config) - config error: " .. err, 2)
	end

	local head = MutableShape(cachedHead)
	-- need custom functions for heads
	-- head.load = avatar_load
	-- head.loadEquipment = avatar_loadEquipment
	head.setColors = avatar_setColors
	head.setEyes = avatar_setEyes
	head.setNose = avatar_setNose

	local requests = {}
	local palette = avatarPalette:Copy()

	avatarPrivateFields[head] =
		{ config = config, equipments = {}, requests = requests, palette = palette, isHead = true }

	-- error("REVIEW getPlayerHead")
	head.Name = "Head"
	hierarchyactions:applyToDescendants(head, { includeRoot = true }, function(o)
		o.Physics = PhysicsMode.Disabled
		o.Palette = palette
	end)

	-- head:setEyes({ index = 1 })
	-- head:setNose({ index = DEFAULT_NOSE_INDEX })

	-- local requests = self:prepareHead(head, usernameOrId, callback)
	return head, requests
end

-- returns MutaleShape + sent requests (table)
-- /!\ return table of requests does not contain all requests right away
-- reference should be kept, not copying entries right after function call.
-- replaced is optional, but can be provided to replace an existing avatar instead of creating a new one.
-- LEGACY: config used to be usernameOrId
mod.get = function(self, config, replaced_deprecated, didLoadCallback_deprecated)
	if self ~= mod then
		error("avatar:get(config) should be called with `:`", 2)
	end

	-- LEGACY
	if type(config) == "string" then
		config = {
			usernameOrId = config, -- parameter used to be usernameOrId
		}
	end
	if type(didLoadCallback_deprecated) == "function" then
		if config == nil then
			config = {}
		end
		config.didLoad = didLoadCallback_deprecated
	end

	ok, err = pcall(function()
		config = require("config"):merge(avatarDefaultConfig, config)
	end)
	if not ok then
		error("avatar:get(config) - config error: " .. err, 2)
	end

	local avatar = Object()
	avatar.load = avatar_load
	avatar.loadEquipment = avatar_loadEquipment
	avatar.setColors = avatar_setColors
	avatar.setEyes = avatar_setEyes
	avatar.setNose = avatar_setNose

	local requests = {}
	local palette = avatarPalette:Copy()

	avatarPrivateFields[avatar] = { config = config, equipments = {}, requests = requests, palette = palette }

	local body = bundle:MutableShape("shapes/avatar.3zh")
	body.Name = "Body"
	hierarchyactions:applyToDescendants(body, { includeRoot = true }, function(o)
		o.Physics = PhysicsMode.Disabled
	end)

	avatar:AddChild(body)
	body.LocalPosition.Y = 12

	if config.defaultAnimations then
		initAnimations(avatar)
	end

	avatar:setEyes({ index = DEFAULT_EYES_INDEX, color = mod.eyeColors[DEFAULT_EYES_COLOR_INDEX] })
	avatar:setNose({ index = DEFAULT_NOSE_INDEX })

	local eyeLidRight = MutableShape()
	eyeLidRight.Physics = PhysicsMode.Disabled
	eyeLidRight.Palette = palette
	eyeLidRight:AddBlock(1, 0, 0, 0)

	eyeLidRight = Shape(eyeLidRight)
	eyeLidRight.Name = "EyeLidRight"
	eyeLidRight:SetParent(avatar.Head)
	eyeLidRight.Pivot = { 0.5, 1, 0.5 }
	eyeLidRight.Scale.Z = 1
	eyeLidRight.Scale.X = 3.2
	eyeLidRight.Scale.Y = 0 -- 4.2
	eyeLidRight.IsHidden = true
	eyeLidRight.LocalPosition:Set(4, 5.1, 5.1)

	local eyeLidLeft = Shape(eyeLidRight)
	eyeLidLeft.Name = "EyeLidLeft"
	eyeLidLeft:SetParent(avatar.Head)
	eyeLidLeft.Pivot = { 0.5, 1, 0.5 }
	eyeLidLeft.Scale.Z = 1
	eyeLidLeft.Scale.X = 3.2
	eyeLidLeft.Scale.Y = 0 -- 4.2
	eyeLidLeft.IsHidden = true
	eyeLidLeft.LocalPosition:Set(-4, 5.1, 5.1)

	hierarchyactions:applyToDescendants(body, { includeRoot = true }, function(o)
		o.Palette = palette
	end)

	if config.eyeBlinks then
		local eyeBlinks = {}
		eyeBlinks.close = function()
			-- removing eyelids when head loses its parent
			-- not ideal, but no easy way currently to detect when the avatar is destroyed
			if eyeLidRight:GetParent() == nil or eyeLidRight:GetParent():GetParent() == nil then
				eyeBlinks = nil
				eyeLidRight:RemoveFromParent()
				eyeLidLeft:RemoveFromParent()
				return
			end
			eyeLidRight.Scale.Y = 4.2
			eyeLidRight.IsHidden = false
			eyeLidLeft.Scale.Y = 4.2
			eyeLidLeft.IsHidden = false
			Timer(0.1, eyeBlinks.open)
		end
		eyeBlinks.open = function()
			eyeLidRight.Scale.Y = 0
			eyeLidRight.IsHidden = true
			eyeLidLeft.Scale.Y = 0
			eyeLidLeft.IsHidden = true
			eyeBlinks.schedule()
		end
		eyeBlinks.schedule = function()
			Timer(3.0 + math.random() * 1.0, eyeBlinks.close)
		end
		eyeBlinks.schedule()
	end

	avatar:load()

	return avatar, requests
end

function avatar_load(self, config)
	local fields = avatarPrivateFields[self]
	if fields == nil then
		error("avatar:load(config) should be called with `:`", 2)
	end

	-- if config parameter isn't nil: load provided field,
	-- load avatar's config otherwise
	if config == nil then
		config = fields.config
	end

	if config.usernameOrId ~= nil and config.usernameOrId ~= "" then
		local req = api.getAvatar(config.usernameOrId, function(err, data)
			if err and config.didLoad then
				config.didLoad(err)
				return
			end

			local skinColor = nil
			local skinColor2 = nil
			local noseColor = nil
			local mouthColor = nil
			local eyesColor = nil

			if data.skinColor then
				skinColor =
					Color(math.floor(data.skinColor.r), math.floor(data.skinColor.g), math.floor(data.skinColor.b))
			end
			if data.skinColor2 then
				skinColor2 =
					Color(math.floor(data.skinColor2.r), math.floor(data.skinColor2.g), math.floor(data.skinColor2.b))
			end
			if data.noseColor then
				noseColor =
					Color(math.floor(data.noseColor.r), math.floor(data.noseColor.g), math.floor(data.noseColor.b))
			end
			if data.mouthColor then
				mouthColor =
					Color(math.floor(data.mouthColor.r), math.floor(data.mouthColor.g), math.floor(data.mouthColor.b))
			end
			if data.eyesColor then
				eyesColor =
					Color(math.floor(data.eyesColor.r), math.floor(data.eyesColor.g), math.floor(data.eyesColor.b))
			end

			self:setColors({
				skin1 = skinColor,
				skin2 = skinColor2,
				nose = noseColor,
				mouth = mouthColor,
				eyes = eyesColor,
			})

			-- print("data:", JSON:Encode(data))

			if data.jacket then
				self:loadEquipment({ type = "jacket", item = data.jacket })
			end
			if data.pants then
				self:loadEquipment({ type = "pants", item = data.pants })
			end
			if data.hair then
				self:loadEquipment({ type = "hair", item = data.hair })
			end
			if data.boots then
				self:loadEquipment({ type = "boots", item = data.boots })
			end
		end)

		table.insert(fields.requests, req)
	end
end

function _attachEquipmentToBodyPart(bodyPart, equipment, scale)
	if equipment == nil or bodyPart == nil then
		return
	end
	equipment.Physics = PhysicsMode.Disabled
	equipment.LocalRotation:Set(0, 0, 0)

	equipment:SetParent(bodyPart)
	equipment.Shadow = bodyPart.Shadow
	equipment.IsUnlit = bodyPart.IsUnlit
	System:SetLayersElevated(equipment, System:GetLayersElevated(bodyPart))

	local coords = bodyPart:GetPoint("origin").Coords
	if coords == nil then
		print("can't get parent coords for equipment")
		return
	end

	local localPos = bodyPart:BlockToLocal(coords)
	local origin = Number3(0, 0, 0)
	local point = equipment:GetPoint("origin")
	if point ~= nil then
		origin = point.Coords
	end
	equipment.Pivot = origin
	equipment.LocalPosition = localPos

	equipment.Scale = scale or 1
end

function avatar_loadEquipment(self, config)
	local fields = avatarPrivateFields[self]
	if fields == nil then
		error("avatar:loadEquipment(config) should be called with `:`", 2)
	end

	local requests = fields.requests

	local defaultConfig = {
		type = "",
		item = "", -- item repo and name (like "aduermael.hair")
		avatar = nil, -- avatar to be equipped (can remain nil)
		mutable = false, -- equipment shape(s) made mutable when true
		didLoad = emptyFunc, -- function(shape, equipmentType) end
		-- allows to provide shape that's already been loaded
		-- /!\ shape then managed by avatar, provide copy if needed
		shape = nil,
		bumpAnimation = false,
		didAttachEquipmentParts = nil, -- function(equipmentParts)
	}

	ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config, {
			acceptTypes = {
				shape = { "Shape", "MutableShape" },
				didAttachEquipmentParts = { "function" },
			},
		})
	end)
	if not ok then
		error("loadEquipment(config) - config error: " .. err, 2)
	end

	local currentEquipment = fields.equipments[config.type]
	if currentEquipment == nil then
		currentEquipment = {}
		fields.equipments[config.type] = currentEquipment
	end

	if currentEquipment.request ~= nil then
		currentEquipment.request:Cancel()
		currentEquipment.request = nil
	end

	local attachEquipment = function(equipment)
		-- remove current equipment
		if currentEquipment.shapes ~= nil then
			for i, previousEquipment in ipairs(currentEquipment.shapes) do
				if i > 1 then
					previousEquipment:SetParent(currentEquipment.shapes[i - 1])
				else
					previousEquipment:RemoveFromParent()
				end
			end
		end
		if equipment == nil then
			-- no equipment to attach
			return
		end

		if config.type == "jacket" then
			local rightSleeve
			local leftSleeve
			rightSleeve = equipment:GetChild(1)
			if rightSleeve then
				leftSleeve = rightSleeve:GetChild(1)
			end
			currentEquipment.shapes = { equipment, rightSleeve, leftSleeve }
			_attachEquipmentToBodyPart(self.Body, equipment)
			if rightSleeve then
				_attachEquipmentToBodyPart(self.RightArm, rightSleeve)
			end
			if leftSleeve then
				_attachEquipmentToBodyPart(self.LeftArm, leftSleeve)
			end

			if config.didAttachEquipmentParts then
				config.didAttachEquipmentParts({ equipment, rightSleeve, leftSleeve })
			end
		elseif config.type == "pants" then
			local leftLeg = equipment:GetChild(1)
			currentEquipment.shapes = { equipment, leftLeg }
			_attachEquipmentToBodyPart(self.RightLeg, equipment, 1.05)
			_attachEquipmentToBodyPart(self.LeftLeg, leftLeg, 1.05)

			if config.didAttachEquipmentParts then
				config.didAttachEquipmentParts({ equipment, leftLeg })
			end
		elseif config.type == "boots" then
			local leftFoot = equipment:GetChild(1)
			currentEquipment.shapes = { equipment, leftFoot }
			_attachEquipmentToBodyPart(self.RightFoot, equipment)
			_attachEquipmentToBodyPart(self.LeftFoot, leftFoot)

			if config.didAttachEquipmentParts then
				config.didAttachEquipmentParts({ equipment, leftFoot })
			end
		elseif config.type == "hair" then
			currentEquipment.shapes = { equipment }
			_attachEquipmentToBodyPart(self.Head, equipment)

			if config.didAttachEquipmentParts then
				config.didAttachEquipmentParts({ equipment })
			end
		end
	end

	if config.shape then
		attachEquipment(config.shape)
	elseif config.item == "" then
		attachEquipment(nil)
	else
		local req = Object:Load(config.item, function(equipment)
			currentEquipment.request = nil

			if equipment == nil then
				-- TODO: keep retrying
				return
			end

			attachEquipment(equipment)
		end)

		currentEquipment.request = req

		table.insert(requests, req)
	end
end

function avatar_setColors(self, config)
	local fields = avatarPrivateFields[self]
	if fields == nil then
		error("avatar:load(config) should be called with `:`", 2)
	end

	config = require("config"):merge({}, config, {
		acceptTypes = {
			skin1 = { "Color" },
			skin2 = { "Color" },
			cloth = { "Color" },
			mouth = { "Color" },
			eyes = { "Color" },
			eyesWhite = { "Color" },
			eyesDark = { "Color" },
			nose = { "Color" },
		},
	})

	local palette = fields.palette

	if config.skin1 then
		palette[SKIN_1_PALETTE_INDEX].Color = config.skin1
	end
	if config.skin2 then
		palette[SKIN_2_PALETTE_INDEX].Color = config.skin2
	end
	if config.cloth then
		palette[CLOTH_PALETTE_INDEX].Color = config.cloth
	end
	if config.mouth then
		palette[MOUTH_PALETTE_INDEX].Color = config.mouth
	end
	if config.eyes then
		palette[EYES_PALETTE_INDEX].Color = config.eyes
		if config.eyesDark == nil then
			config.eyesDark = Color(palette[EYES_PALETTE_INDEX].Color)
			config.eyesDark:ApplyBrightnessDiff(-0.2)
		end
	end
	if config.eyesWhite then
		palette[EYES_WHITE_PALETTE_INDEX].Color = config.eyesWhite
	end
	if config.eyesDark then
		palette[EYES_DARK_PALETTE_INDEX].Color = config.eyesDark
	end
	if config.nose then
		palette[NOSE_PALETTE_INDEX].Color = config.nose
	end
end

function avatar_setEyes(self, config)
	local fields = avatarPrivateFields[self]
	if fields == nil then
		error("avatar:setEyes(config) should be called with `:`", 2)
	end

	config = require("config"):merge({}, config, {
		acceptTypes = {
			index = { "integer" },
			color = { "Color" },
		},
	})

	if config.index ~= nil then
		-- remove current eyes
		local head
		if fields.isHead == true then
			head = self
		else
			head = self.Head
		end
		local b
		for x = 4, head.Width - 5 do -- width -> left side when looking at face
			for y = 3, head.Height - 5 do
				b = head:GetBlock(x, y, head.Depth - 2)
				if b then
					b:Replace(SKIN_1_PALETTE_INDEX)
				end
			end
		end

		local eyes = mod.eyes[config.index]
		for _, e in ipairs(eyes) do
			b = head:GetBlock(15 - e.x, e.y + 2, head.Depth - 2)
			if b then
				b:Replace(e.c)
			end
		end
	end

	if config.color ~= nil then
		self:setColors({
			eyes = config.color,
		})
	end
end

function avatar_setNose(self, config)
	local fields = avatarPrivateFields[self]
	if fields == nil then
		error("avatar:setNose(config) should be called with `:`", 2)
	end

	config = require("config"):merge({}, config, {
		acceptTypes = {
			index = { "integer" },
			color = { "Color" },
		},
	})

	if config.index ~= nil then
		local nodeBlocks = {}

		local nose = mod.noses[config.index]
		for _, n in ipairs(nose) do
			local x = 11 - n.x
			local y = n.y + 2
			if nodeBlocks[x] == nil then
				nodeBlocks[x] = {}
			end
			nodeBlocks[x][y] = n.c
		end

		-- remove current nose
		local head
		if fields.isHead == true then
			head = self
		else
			head = self.Head
		end
		local b
		local depth = 12
		for x = 8, head.Width - 9 do -- width -> left side when looking at face
			for y = 3, head.Height - 5 do
				if nodeBlocks[x][y] == nil then
					b = head:GetBlock(x, y, depth)
					if b ~= nil then
						b:Remove()
					end
				else
					b = head:GetBlock(x, y, depth)
					if b == nil then
						head:AddBlock(nodeBlocks[x][y], x, y, depth)
					end
				end
			end
		end

		-- NOTE: there seems to be an issue when removing then adding block at same position
	end

	if config.color ~= nil then
		-- self:setColors({
		-- 	eyes = config.color,
		-- })
	end
end

-- EQUIPMENTS

equipmentTypes = {
	"hair",
	"jacket",
	"pants",
	"boots",
}

equipmentIndex = {}
for _, e in ipairs(equipmentTypes) do
	equipmentIndex[e] = true
end

return mod
