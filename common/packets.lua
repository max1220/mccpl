-- this file contains packet definitions and information
-- table index is the packet id byte
--  name is used in callbacks
--  format is used to define packet byte format and length
--  fields is the list of names for the fields of the format
-- You can also index this table using the name.
-- Every packet is automatically assigned a packet_id filed in it's table
-- that is equal to the one specified in the index for convenience.

local packets = {
	[0x00] = {
		name = "identification",
		format = ">B c64 c64 B",
		fields = {"protocol_version", "user_or_server_name", "motd_or_key", "user_type"}
	},
	[0x01] = {
		name = "ping",
		format = "",
		fields = {}
	},
	[0x02] = {
		name = "level_initialize",
		format = "",
		fields = {}
	},
	[0x03] = {
		name = "level_data_chunk",
		format = ">i2 c1024 B",
		fields = {"chunk_len","chunk_data","percent_complete"}
	},
	[0x04] = {
		name = "level_finalize",
		format = ">i2 i2 i2",
		fields = {"x_size","y_size","z_size"}
	},
	[0x05] = {
		name = "set_block_client",
		format = ">i2 i2 i2 B B",
		fields = {"x","y","z", "mode", "block_type"}
	},
	[0x06] = {
		name = "set_block_server",
		format = ">i2 i2 i2 B",
		fields = {"x", "y", "z", "block_type"}
	},
	[0x07] = {
		name = "spawn_player",
		format = ">b c64 i2 i2 i2 B B",
		fields = {"player_id", "player_name", "x", "y", "z", "yaw", "pitch"}
	},
	[0x08] = {
		name = "position_orientation",
		format = ">b i2 i2 i2 B B",
		fields = {"player_id", "x", "y", "z", "yaw", "pitch"}
	},
	[0x09] = {
		name = "position_orientation_update",
		format = ">b b b b B B",
		fields = {"player_id", "dx", "dy", "dz", "yaw", "pitch"}
	},
	--0x0a
	--0x0b
	[0x0c] = {
		name = "despawn_player",
		format = ">b",
		fields = {"player_id"}
	},
	[0x0d] = {
		name = "message",
		format = ">b c64",
		fields = {"player_id", "message"}
	},
	[0x0e] = {
		name = "disconnect",
		format = ">c64",
		fields = {"message"}
	},
	[0x0f] = {
		name = "update_user_type",
		format = "B",
		fields = {"user_type"}
	}
}

-- add packet_id field to every packet info and add additional index by packet name, resolving to packet_id
local by_name = {}
for packet_id,packet_info in pairs(packets) do
    packet_info.packet_id = packet_id
    assert((packet_info.name) and (not by_name[packet_info.name]))
    by_name[packet_info.name] = packet_id
end
for packet_name,packet_id in pairs(by_name) do
    packets[packet_name] = packet_id
end

return packets
