-- this file manages the list of worlds loaded by the server
local plugins = require("mccpl.common.plugins")
local world = require("mccpl.common.world")

local worlds = {}

-- add a client to a world("player joins a world")
function worlds:add_client(client, world)
    self.log("debug2", "adding client", client.username, "to world", world.name)
    plugins:trigger_callback("server_worlds_add_client", self,client,world)
    table.insert(world.clients, client)
end

-- remove a client from a world
function worlds:remove_client(client, world)
    self.log("debug2", "removing client", client.username, "from world", world.name)
    plugins:trigger_callback("server_worlds_add_client", self,client,world)
    for i=1, #world.clients do
        if world.clients[i] == client then
            client:send_despawn()
            return table.remove(world.clients, i)
        end
    end
end

-- add a world to the list of loaded(active) worlds
function worlds:add(world)
    assert(world and world.name)
    assert(not self[world.name])
    self.log("debug2", "adding world", world.name)
    plugins:trigger_callback("server_worlds_add_world", self,world)
    table.insert(self, world) -- numeric index for iteration
    
    -- append server functions to world
    world.clients = world.clients or {}
    
    self[world.name] = world -- index by world name
    self[world] = true -- index by world
    return world
end

-- remove a world from the list of loaded worlds
function worlds:remove(world)
    assert(self[world])
    self.log("debug2", "removing world", world.name)
    plugins:trigger_callback("server_worlds_remove_world", self,world)
    for i=1, #self do
        if self[i] == world then
            for i=1, world.clients do -- remove all loaded clients
                self:remove_client(world.clients[i], world)
            end
            world.add_client = nil -- make sure worlds-dependant function can't be called afterwards
            world.remove_client = nil
            world.clients = nil
            table.remove(self, i) -- remove all references
            self[world.name] = nil
            self[world] = nil
            break
        end
    end
end


return worlds