-- this is the hello-world plugin;
-- it simply logs "Hello World" to the server log on load, and
-- registers a command callback handler.

-- this is the main table, defining the plugin.
-- All information about a plugin, and all callbacks(implementing the plugin)
-- need to be in a table structured like this!
local plugins = require("mccpl.common.plugins")
local plugin = {
    plugin_name = "hello_world", -- Needs to be the same as the plugin main filename/foldername!
    callbacks = {}, -- table of callback the plugin registers. We'll add a function later.
    
    -- all other fields are just by convention, and are not checked for now.
    -- you should still specify them for actual plugin releases
    version = "0.0.1",
    license = "MIT",
    author = "max1220",
    description = [[A simple server hello-world plugin
Shows greeting on load, provides /hello command.]],
    git = "https://github.com/max1220/mccpl"
}

-- add a callback for the init function.
-- all callbacks are called with the plugin table as the first argument.
function plugin.callbacks.init_server(self, last_ret)
    -- check that this plugin is loaded on a server!
    assert(self.server)
    
    -- on load, output a message to the server console
    self.log("plugin", "Hello World from plugin.callbacks.init!")
    
    -- returning true in a plugin means don't call further plugin callbacks afterwards.
    -- Plugins callbacks are executed in the order they are loaded (typically specified
    -- in the server/client config).
    -- If plugins need further coordination between them, they need to implement it in
    -- the plugins, and specify the correct load order!
    return false
end

-- add a callback for the command function.
-- This function is called after the internal commands have been tried,
-- but before the unknown command reply has been send.
-- If any of the plugins return truethy in this callback chain, it is
-- assumed that the command was handled and no error needs to be shown.
function plugin.callbacks.command(self, client, cmd, args)
    if cmd == "hello" then
        client:send_chat_message("Hello World!") -- send a reply to the client that send the command!
        return true -- no other commands should react to the /hello command
    end
    return -- return nothing means try other command callback handlers as well.
end


-- the plugin main table needs to be returned
return plugin