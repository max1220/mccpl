#!/usr/bin/env luajit
-- this is the main server executable. It loads all worlds, starts networking, and handles global tick events.
local time = require("time")
local copas = require("copas")

local plugins = require("mccpl.common.plugins")
local log_utils = require("mccpl.common.log")
local world = require("mccpl.common.world")

-- this object contains the entire server state and all methods.
local server = {
    config = require("mccpl.server.config"),
	worlds = require("mccpl.server.worlds"),
    networking = require("mccpl.server.networking"),
}
local log, logf = log_utils:new_logger(server.config.log)
server.log, server.logf = log,logf
server.worlds.log, server.worlds.logf = log,logf
plugins.log,plugins.logf = log, logf
plugins.base_name = "mccpl.plugins."
plugins.disable_pcall = false

-- periodically called to update the world. currently only meassures delta-time(dt)
-- TODO: Implement tick-dependent block updates like water/lava
-- TODO: Move to worlds
function server:periodic_update()
    local last = time.realtime()
	while true do
		local now = time.realtime()
		local dt = now - last
		last = now
        log("debug3", "dt:", dt)
        plugins:trigger_callback("server_periodic_update", dt)
		copas.sleep(1)
	end
end

function server:add_world_from_name(world_name)
    local filepath = self.config.worlds_dir .. world_name .. ".gzip"
    local loaded_world = assert(world.new_from_file(filepath))
    loaded_world.name = world_name
    self.worlds:add(loaded_world)
    plugins:trigger_callback("server_loaded_world", loaded_world)
    return loaded_world
end

-- start the server
function server:start()
    -- load plugins
    assert(not plugins.server)
    plugins.server = self -- provide reference to server instance to plugins
    for _, plugin_name in ipairs(self.config.plugins) do
        plugins:load_plugin(plugin_name)
    end
    plugins:trigger_callback("server_init_early", self)

    -- load all configured worlds
	for _, world_name in ipairs(self.config.worlds) do
        local loaded_world = self:add_world_from_name(world_name)
		logf("notice","Loaded world %s: %dx%dx%d", world_name, loaded_world.width, loaded_world.height, loaded_world.depth )
	end

	-- set default world
	local default_world = assert(self.worlds[self.config.default_world])
	self.worlds:set_default_world(default_world)

    -- start tick update coroutine
    -- TODO: Add in worlds maybe?
    copas.addthread(function()
        self:periodic_update()
    end)

    -- start listening on port, register connection handler, create clients on connect
    self.networking:start(self)
    plugins:trigger_callback("server_init", self)

    -- enter copas event loop
    log("notice", "Server ready.")
	copas.loop()
end

-- TODO: Maybe return the server object for easily embedding in other applications? (library/non-standalone server)
server:start()
