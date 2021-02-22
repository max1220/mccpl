-- this is the configuration file for the minecraft classic protocol server.
return {
    -- network settings
    address = "*", -- address the minecraft server listens on
	port = 25565, -- port the minecraft server listens on
    
    -- game settings
	server_name = "test server name", -- name of server
	motd = "test server motd", -- motto of the day
	welcome_msg = "Welcome! Type /help for a list of commands.", -- message displayed after connection
    
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
        "hello_world",
    }
}
