-- this file utility functions for using the Minecraft classic protocol,
-- for example encoding and decoding of string arguments in packets,
-- getting expected packet length, etc.
local struct = require("struct")
local packets = require("mccpl.common.packets")

local protocol_utils = {}

-- return the list of arguments as a table
local function pack(...)
	return {...}
end

-- return a string with a length of 64, padded with 0x20(space)
function protocol_utils.string64(str)
	str = str:sub(1, 64)
	str = str .. (" "):rep(64-#str)
	return str
end

-- right-trim spaces from a string
function protocol_utils.destring64(str)
	for i=#str, 1, -1 do
		if str:byte(i) ~= 0x20 then
			return str:sub(1, i)
		end
	end
end

-- return a string with a lenght of 1024, padded with 0x00
function protocol_utils.data1024(str)
	str = str:sub(1, 1024)
	str = str .. ("\0"):rep(1024-#str)
	return str
end

-- decode a packet by it's ID(int) and data(string). The packet must exist, and data must have the right length
function protocol_utils.decode_by_id(id, data)
	id = assert(tonumber(id))
	local packet_info = assert(packets[id])

	local packet_data = pack(struct.unpack(packet_info.format, data))
	assert(#packet_data-1 == #packet_info.fields, "Invalid packet specification:".. id)
	local packet = {}
	packet.type = packet_info.name
	for i=1, #packet_info.fields do
		local field_name = packet_info.fields[i]
		packet[field_name] = packet_data[i]
	end
	return packet
end

-- get the lenght of the packet based on it's ID. Returns nil if the packet does not exist.
function protocol_utils.len_by_id(id)
	id = assert(tonumber(id))
	local packet_info = packets[id]
	if not packet_info then
		return nil, "packet not found"
	end
	return struct.size(packet_info.format)
end

-- return a packet as a string, from an ID and a table. Each field name from the packet config must be present.
function protocol_utils.encode_by_id(id, t)
	id = assert(tonumber(id))
	local packet_info = assert(packets[id])
	local args = {}
	for i=1, #packet_info.fields do
		local field_name = packet_info.fields[i]
		local arg_val = assert(t[field_name])
		args[i] = arg_val
	end
	return string.char(id) .. struct.pack(packet_info.format, unpack(args))
end


return protocol_utils
