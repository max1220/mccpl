-- this file manages the list of worlds loaded by the server
local plugins = require("mccpl.common.plugins")

local worlds = {}

-- set the default world to this world
-- the default world can't be removed and must be set before use.
function worlds:set_default_world(target_world)
	self.log("debug2", "Setting default world to ", target_world)
    assert(self[target_world])
    self.default_world = target_world
	plugins:trigger_callback("server_worlds_set_default_world", self, target_world)
end

-- add a client to a world("player joins a world")
function worlds:add_client(client, target_world)
    self.log("debug2", "adding client", client.username, "to world", target_world.name)
	local ignore_add_client = plugins:trigger_callback_unpack("server_worlds_add_client", self,client,target_world)
    if ignore_add_client then
		return -- plugin handeled the add client to world logic
	end

	-- client can't have another world loaded!
    assert(not client.world)

	-- the world list needs to containt the world we atempt to load.
	-- TODO: Maybe relax this for easy plugin worlds?
	assert(self[target_world])

	-- add client to list of connected clients for this world
    table.insert(target_world.clients, client)

    -- add current world reference to client
    client.world = target_world

	-- send new world data to client
	client:send_world()

	-- send spawn point to client, notify other players on this world of the new player
	client:send_player_spawn()

	-- send list of players on this world
	client:send_players()
end

-- remove a client from it's world("player leaves a world")
function worlds:remove_client_world(client)
    self.log("debug2", "removing client", client.username, "from world", client.world.name)
    plugins:trigger_callback("server_worlds_add_client", self,client,client.world)
	client:send_despawn(client.player_id)
    for i=1, #client.world.clients do
        if client.world.clients[i] == client then
			table.remove(client.world.clients, i)
			client.world = nil
			break
        end
    end
end

-- move a client from one loaded world to another
function worlds:move_client(client, new_world)
    assert(new_world)

    -- remove from current world
    if client.world then
        self:remove_client_world(client)
    end

    -- add to new world
    self:add_client(client, new_world)
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
	assert(world~=self.default_world)
    self.log("debug2", "removing world", world.name)
    plugins:trigger_callback("server_worlds_remove_world", self,world)
    for i=1, #self do
        if self[i] == world then
            if world.clients then
                for _,client in ipairs(world.clients) do
                    self:move_client(client, self.default_world)
                end
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
