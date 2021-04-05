-- this function decodes packets from the connection with the server, and calls the handler functions in the client object.
-- It is called once per connection in a copas coroutine, and calls the configured protocol client callbacks.
local copas = require("copas")
local protocol_utils = require("mccpl.protocol.utils")


local function make_copas_client(client)
	-- this function reads the next byte from the socket, and returns it as a number(0-255),
	-- that represents the packet id.
	function client:read_packet_id()
		local packet_id,err = copas.receive(self.con, 1)
		if err == "closed" then -- client closed connection
			return
		end
		return assert(packet_id,err):byte()
	end

	-- this function reads a specified ammount of bytes from the socket, and returns it as a string
	function client:read_packet_data(packet_len)
		return assert(copas.receive(self.con, packet_len))
	end

	-- this function sends a string to the client
	function client:send(raw)
		-- send data to client
		copas.send(self.con, raw)
	end

	function client:close()
		self.con:close()
	end

	function client:update()
		pcall(client_update)
	end
end



local function client_update(client)
	-- get the first byte of a packet, the packet_id
	local packet_id = client:read_packet_id()

	-- get length of packet by looking up the packet_id
	local packet_len = assert(protocol_utils.len_by_id(packet_id), "Unknown packet id:"..tostring(packet_id))

	-- get raw packet data as a string
	local data = client:read_packet_data(packet_len)

	-- resolve data string to table with proper field names
	local packet = assert(protocol_utils.decode_by_id(packet_id, data), "Can't decode packet data!")
	assert(packet.type)
	client.log("debug3", "Got packet:", packet.type)

	-- call client handler(implementation) of packet
	local packet_handler = assert(client["handle_"..packet.type], "No handler for packet: "..tostring(packet.type))
	local resp_packet_id, resp_packet_data = packet_handler(client, packet)

	-- if client handler returned a response packet, try to send it.
	if (type(packet_id) == "number") and (type(resp_packet_id)=="table") then
		client:send(protocol_utils.encode_by_id(resp_packet_id, resp_packet_data))
	end
end


local function client_handler(client)
	while true do

	end

	client.log("debug2", "Server handler terminated, closing...")
	client:close()
end
return client_handler
