-- this file specifies client behaviour.
local plugins = require("mccpl.common.plugins")
local protocol_utils = require("mccpl.common.protocol_utils")
local packets = require("mccpl.common.packets")
local commands = require("mccpl.server.commands")

local clients = {
    next_player_id = 1
}


-- add a new client to the server clients list
function clients:add(client)
    assert(client)
    assert(not client.player_id)
    table.insert(self, client)
    client.player_id = self.next_player_id
    self.next_player_id = self.next_player_id + 1
end

-- remove a client from the server clients list
function clients:remove(remove_client)
    local found_client,found_client_i
	for i,client in ipairs(clients) do
		if client == remove_client then
            found_client = remove_client
            found_client_i = i
		end
	end
    if not found_client then
        return
    end
    found_client:send_despawn()
    found_client.server.worlds:remove_client(found_client, found_client.world)
	table.remove(clients, found_client_i)
	return true
end

-- return a newly generated client.
-- the client object contains a bunch of callback handlers that are called when
-- the server packet loop receives a specified packet, and utillity functions for
-- sending data back to the client
function clients:new(server)
	local client = {}

    -- store client state
    client.pos = {}
    client.rot = {}

	-- store reference to server
	client.server = server
    
    local log,logf = server.log, server.logf

    -- the functions client:send() and client:send_packet() are addeded to the client in server/networking.lua

    -- handle client identification packets
    -- authenticate, then spawn the player on the default world
	function client:handle_identification(packet)
		self.username = protocol_utils.destring64(packet.user_or_server_name)
		self.key = protocol_utils.destring64(packet.motd_or_key)
        
		-- TODO: authentication!

		log("notice", "Player connected:", self.username, self.player_id, self.con:getpeername())

		-- send server info
		self:send_identification()

		-- load initial world
		self:change_world(self.server.worlds[self.server.config.default_world])

		-- send welcome message
        self:send_chat_message(self.server.config.welcome_msg)
	end

    -- callback for a position/orientation packet from the client.
    -- update internal player position, broadcast new player position to all players on this players world
	function client:handle_position_orientation(packet)
		-- update position/rotation        
		self.pos[1] = packet.x/32
		self.pos[2] = packet.y/32
		self.pos[3] = packet.z/32
		self.rot[1] = packet.yaw
		self.rot[2] = packet.pitch

		-- send updated position to everyone on the world, except self
		-- TODO: (When) does it make sense to aggregate/rate-limit this?
		self.server.networking:broadcast_packet_world(packets.position_orientation, {
			player_id = self.player_id,
			x = self.pos[1]*32,
			y = self.pos[2]*32,
			z = self.pos[3]*32,
			yaw = self.rot[1],
			pitch = self.rot[2]
		}, self.world, self)

        plugins:trigger_callback("server_client_handle_position_orientation", self)

		logf("debug3", "handle_position_orientation: %6.3f %6.3f %6.3f - %6.3f %6.3f", self.pos[1], self.pos[2], self.pos[3], self.rot[1], self.rot[2])
	end

    -- callback for a set_block packet from the client.
    --- Make change in world, and broadcast update to players
	function client:handle_set_block_client(packet)
		-- determine new block type for the specified position
		local block_type = (packet.mode == 0x01) and packet.block_type or 0
		log("debug3", "handle_set_block_client",packet.x,packet.y,packet.z, block_type)
        local ignore = plugins:trigger_callback_unpack("server_client_set_block", self, packet.x,packet.y,packet.z, block_type)
        if ignore then
            return
        end
        
		self.world:set_block(packet.x,packet.y,packet.z, block_type)

		-- send block change to everyone on the world, except self(client assumes always success)
		self.server.networking:broadcast_packet_world(packets.set_block_server, {
			x = packet.x,
			y = packet.y,
			z = packet.z,
			block_type = block_type
		}, self.world, self)
	end

    -- callback for a chat message packet from the client.
    -- send chat message to everyone, or handle command.
	function client:handle_message(packet)
		local message = protocol_utils.destring64(packet.message)

		if message:sub(1,1) == "/" then
            -- server command
			local cmd, args = message:match("^/(%S+)(.*)$")
			logf("command", ("[%s]: %s%s"):format(self.username, cmd, args))
            local plugin_handled = plugins:trigger_callback_unpack("server_command", self, cmd, args)
            if plugin_handled then
                return -- a plugin has handled this command, don't call default handlers
            end
			if commands[cmd] then
				return commands[cmd](self, cmd, args) -- default command handler
			else
				self:send_chat_message("Unknown command!")
			end
		else
            -- chat message
			logf("chat", ("[%s]: %q"):format(self.username, message))
			local server_msg = protocol_utils.string64(("&e[%s]:&f %s"):format(self.username, message))
            self.server.networking:broadcast_packet_global(packets.message, {
				player_id = self.player_id,
				message = server_msg
			})
		end
	end

    -- send a chat message.
    -- origin_player_id is the sender, -1 for server
    function client:send_chat_message(chat_msg, origin_player_id)
        plugins:trigger_callback("server_send_chat_message", self, chat_msg, origin_player_id)
        self:send_packet(packets.message, {
            player_id = origin_player_id or -1,
            message = protocol_utils.string64(chat_msg)
        })
    end

    -- send the server information(response to player information)
	function client:send_identification()
        self:send_packet(packets.identification, {
			protocol_version = 7,
			user_or_server_name = protocol_utils.string64(self.server.config.server_name),
			motd_or_key = protocol_utils.string64(self.server.config.motd),
			user_type = 0
		})
	end

    -- send the specified world data to the client
	function client:send_world(world)
        world = assert(world or self.world)
		local compressed,uncompressed = world:compress()
		logf("debug", "Sending world to player (uncompressed: %d, compressed: %d)...", #uncompressed, #compressed)

        -- send level_initialize, to signal that we're ready to send world data
        self:send_packet(packets.level_initialize)

        -- send world data as compressed segments of 1024 bytes
		for i=0, #compressed/1024 do
			local chunk_data = compressed:sub(i*1024+1, (i+1)*1024)
			local pct = math.min(math.max((i*1024+512) / #compressed, 0), 1)
			logf("debug2", "sending bytes %d -> %d (%d%%)", i*1024+1, #chunk_data, pct*100)
            self:send_packet(packets.level_data_chunk, {
				chunk_len = #chunk_data,
				chunk_data = protocol_utils.data1024(chunk_data),
				percent_complete = pct*255
			})
		end

        -- send level_finalize with the world dimensions
		self:send_packet(packets.level_finalize, {
			x_size = world.width,
			y_size = world.height,
			z_size = world.depth,
		})
	end

    -- send the spawn packet to the clients 
	function client:send_player_spawn()
        -- inform this client about the spawn
		self:send_packet(packets.spawn_player, {
			player_id = -1,
			player_name = protocol_utils.string64(self.username),
			x = self.world.spawn_x*32,
			y = self.world.spawn_y*32,
			z = self.world.spawn_z*32,
			yaw = 0,
			pitch = 0,
		})
    
        -- send spawn packet for other connected players on this world
        self.server.networking:broadcast_packet_world(packets.spawn_player, {
			player_id = self.player_id,
			player_name = protocol_utils.string64(self.username),
			x = self.world.spawn_x*32,
			y = self.world.spawn_y*32,
			z = self.world.spawn_z*32,
			yaw = 0,
			pitch = 0,
		}, assert(self.world), self)
	end

    -- send a list of all connected players on this players world to the client
	function client:send_players()
		for _, client in ipairs(self.world.clients) do
			if client ~= self then
                self:send_packet(packets.spawn_player, {
					player_id = client.player_id,
					player_name = protocol_utils.string64(client.username),
					x = client.pos[1]*32,
					y = client.pos[2]*32,
					z = client.pos[3]*32,
					yaw = client.rot[1],
					pitch = client.rot[2],
				})
			end
		end
	end

    -- broadcast a packet informing all players on this players world about this player despawning
	function client:send_despawn(player_id)
		player_id = player_id or self.player_id
        self.server.networking:broadcast_packet_world(packets.despawn_player, {player_id = client.player_id}, self.world, self)
	end

    -- change the world this player is currently connected to
	function client:change_world(new_world)
		assert(new_world)

        -- unload old world first
        if self.world then
			self.server.worlds:remove_client(self, self.world)
		end

        self.server.worlds:add_client(self, new_world)
        self.world = new_world

		-- send world data
		self:send_world(new_world)

		-- send spawn point to player, notify other players on the world
		self:send_player_spawn()

		-- send list of players on this world
		self:send_players()
        
        plugins:trigger_callback("server_change_world", self, new_world)
	end

	return client
end


return clients


--