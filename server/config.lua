-- this is the configuration file for the minecraft classic protocol server.
return {
    -- network settings

	-- address the minecraft server listens on(default * means listen on any interface)
    address = "*",

	-- TCP port the minecraft server listens on
	port = 25565,

    -- game settings

	-- name of server
	server_name = "test server name",

	-- motto of the day
	motd = "test server motd",

	-- Message sent when a player connects. Can be a table(list of strings)
	welcome_msg = {
		"Welcome!",
		"Type /help for a list of commands."
	},

    -- log settings
	log = {
		disable = { -- list of disabled log categories
			"debug3" -- by default, don't show spammy debug messages
		}
	},

    -- world settings
	worlds_dir = "saves/", -- directory in which to look for the saved world files
	worlds = { -- list of worlds the server automatically tries to load at startup
		"flat",
	},
    default_world = "flat", -- the world the player is on after the initial connection or after a world is unloaded

    -- plugin settings
    plugins_dir = "server/plugins/", -- directory in which to look for plugins
    plugins = { -- list of plugins that are automatically loaded
		"basic_commands",
        "hello_world",
    },
	pcall_plugins = true, -- use pcall/xpcall for plugins on platforms that support it
}
