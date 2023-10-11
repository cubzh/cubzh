return {
	max_line_length = false,
	allow_defined = true,
	ignore = {
		"421", -- Shadowing a local variable.
		"422", -- Shadowing an argument.
		"423", -- Shadowing a loop variable.
		"431", -- Shadowing an upvalue.
		"432", -- Shadowing an upvalue argument.
		"433", -- Shadowing an upvalue loop variable.
	},

	globals = {
		"Client",
		"Dev",
		"Player",
		"Pointer",
		"System",
	},

	read_globals = {
		"Assets",
		"AssetType",
		"AudioListener",
		"AudioSource",
		"Box",
		"Camera",
		"Color",
		"Event",
		"Environment",
		"Face",
		"File",
		"Items",
		"JSON",
		"LocalEvent",
		"Map",
		"MutableShape",
		"Number2",
		"Number3",
		"Object",
		"OtherPlayers",
		"PhysicsMode",
		"Players",
		"ProjectionMode",
		"Quad",
		"Ray",
		"Rotation",
		"Screen",
		"Shape",
		"Text",
		"TextType",
		"Time",
		"Timer",
		"Type",
		"URL",
		"World",
	}
}