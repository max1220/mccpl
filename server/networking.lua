-- this file contains networking related code
local socket = require("socket")
local copas = require("copas")
local coxpcall = require("coxpcall")

local plugins = require("mccpl.common.plugins")
local protocol_utils = require("mccpl.common.protocol_utils")

local networking = {
    clients = require("mccpl.server.clients")
}

-- add the network-implementation specific functions for the client here.
-- TODO: Create other, non-copas client implementations? Maybe using select directly?
function networking:add_client_networking(client, con)
    client.con = con
    plugins:trigger_callback("server_add_client_networking_early", client)
    
    -- send the raw string to the client
    function client:send(raw_data)
        local ignore_send = plugins:trigger_callback_unpack("server_packet_receive", raw_data)
        if ignore_send then
            return
        end
        return copas.send(self.con, raw_data)
    end
    
    -- send a package specified by the packed_id and packet_data table
    function client:send_packet(packet_id, packet_data)
        return self:send(protocol_utils.encode_by_id(packet_id, packet_data or {}))
    end
    
    -- read a raw string of len bytes from the connection
    function client:read(len)
        return copas.receive(self.con, len) -- returns data, or nil,error
    end
    
    -- read next byte from the socket, and return as a number(0-255, packet_id),
	function client:read_packet_id()
		local packet_id,err = copas.receive(self.con, 1)
		if err == "closed" then -- client closed connection, ignore
			return
		end
		return assert(packet_id,err):byte() -- otherwise we always need data
	end

	-- this function reads a specified ammount of bytes from the socket, and returns it as a string
	function client:read_packet_data(packet_len)
		return assert(copas.receive(self.con, packet_len))
	end
    
    -- this is the main client update function. Here packets are decoded, and callbacks are fired.
    -- it should always be called in a connection handler coroutine, and regularity call copas receive/send/sleep functions.
    function client:update()
        -- get the first byte of a packet, the packet_id
        local packet_id = self:read_packet_id()
        if not packet_id then
            -- closed connection
            assert(self.server.networking.clients:remove(self))
            return true
        end

        -- get length of packet by looking up the packet_id
        local packet_len = assert(protocol_utils.len_by_id(packet_id), "Unknown packet id:"..tostring(packet_id))

        -- get raw packet data as a string
        local data = self:read_packet_data(packet_len)

        -- resolve data string to table with proper field names
        local packet = assert(protocol_utils.decode_by_id(packet_id, data), "Can't decode packet data!")
        assert(packet.type)
        self.server.log("debug3", "Got packet:", packet.type)

        local ignore_handler = plugins:trigger_callback("server_got_client_packet", packet)
        if ignore_handler then
            return -- ingore the default packet handler by returning early
        end

        -- call client handler(implementation) of packet
        local packet_handler = assert(client["handle_"..packet.type], "No handler for packet: "..tostring(packet.type))
        local resp_packet_id, resp_packet_data = packet_handler(client, packet)

        -- if client handler returned a response packet, try to send it.
        if (type(packet_id) == "number") and (type(resp_packet_id)=="table") then
            self:send(protocol_utils.encode_by_id(resp_packet_id, resp_packet_data))
        end
    end
    
    -- this function is called in the connection handler coroutine once the connection and client have been setup.
    -- it is running the client update function in a loop, to continously decode packets and trigger client callbacks.
    function client:run_loop()
        while true do
            local ok, ret = coxpcall.xpcall(self.update,debug.traceback, self)
            if not ok then -- lua error occured, ret is error stacktrace
                self.server.log("error", "client:update() error: ", tostring(ret))
                self.server.networking.clients:remove(self)
                break
            elseif ok and ret then
                -- client closed connection, terminate loop
                break
            end
        end
    end
    plugins:trigger_callback("server_client_connected", client)
end

-- start the server-side networking(listen on port)
function networking:start(server)
    plugins:trigger_callback("server_networking_init_early", self)
    self.server = server
    self.server_con = socket.bind(self.server.config.address, self.server.config.port)
    
    -- add copas new connection handler
	copas.addserver(self.server_con, function(con)
        local client = self.clients:new(self.server)
        self:add_client_networking(client, con)
        self.clients:add(client)
        client:run_loop()
    end, 0.1)
    plugins:trigger_callback("server_networking_init", self)
end

-- send data to all connected players
function networking:broadcast_global(msg, exclude)
    plugins:trigger_callback("server_broadcast_global", msg, exclude)
	for _, client in ipairs(self.clients) do
		if client ~= exclude then
			client:send(msg)
		end
	end
end

-- serialize packet and send to all connected players
function networking:broadcast_packet_global(packet_id, packet_data, exclude)
	return self:broadcast_global(protocol_utils.encode_by_id(packet_id, packet_data), exclude)
end

-- send data to all players on target_world
function networking:broadcast_world(msg, target_world, exclude)
    plugins:trigger_callback("server_broadcast_world", msg, target_world, exclude)
	for _, client in ipairs(target_world.clients) do
		if client ~= exclude then
			client:send(msg)
		end
	end
end

-- serialize packet and send to all connected players on target_world
function networking:broadcast_packet_world(packet_id, packet_data, target_world, exclude)
	return self:broadcast_world(protocol_utils.encode_by_id(packet_id, packet_data), target_world, exclude)
end

return networking