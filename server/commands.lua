--local world_generator = require("server.world_generator")
local plugins = require("mccpl.common.plugins")
local protocol_utils = require("mccpl.common.protocol_utils")
local packets = require("mccpl.common.packets")

-- commands are always called with the client as first argument, so you ca
local commands_client = {}

-- split space-seperated string into argument list 
local function args_split(str)
	local args = {}
	for arg in str:gmatch("%S+") do
		table.insert(args, arg)
	end
	return args
end

-- send a reply to a command.
local function send_command_reply(client, str)
	client.server.logf("command", ("[%s]> %s"):format(client.username, str))
	client:send_chat_message(str, -1)
end

-- returns true if the file can be opened for reading(exists and has correct permissions)
local function file_exists(filename)
	local f = io.open(filename, "r")
	if f then
		f:close()
		return true
	end
end

-- respond with "Pong!" as a command-reply
function commands_client:ping()
    send_command_reply(self, "Pong!")
end

-- send the disconnect packet
function commands_client:quit()
    send_command_reply(self, "Quitting!(Sending disconnect packet!)")
    self:send_packet(packets.disconnect, {
		player_id = -1,
		message = protocol_utils.string64("Bye! (Quit by command)")
	})
	return true
end

-- get a list of worlds and their connected players
function commands_client:worlds()
	send_command_reply(self, "List of worlds:")
    local worlds_list = {}
	for _, world in ipairs(self.server.worlds) do
		table.insert(worlds_list, world.name)
	end
    send_command_reply(self, table.concat(worlds_list, ", "))
end

--[[
function commands_client:world_create(_, args)
	args = args_split(args)
	local world = world_generator:generate_world(unpack(args))
    world.name = name
    self.server.worlds:add(world)
    send_command_reply(self, ("Created world %s."):format())
end
]]

-- load a world from file by it's world_name
function commands_client:world_load(_, args)
	local world_name = args:match("^%s*(.-)%s*$")
    
	local file_name = self.server.config.worlds_dir .. world_name .. ".gzip"
	if not file_exists(file_name) then
		send_command_reply(self, "World file not found!")
		return
	end
    
    local loaded_world
    if self.server.worlds[world_name] then
        -- already loaded, re-load from disk
        loaded_world = self.server.worlds[world_name]
        loaded_world:load_from_file(file_name)
        for _,client in ipairs(loaded_world.clients) do
            client:send_world(loaded_world)
        end
        send_command_reply(self, "World re-loaded!")
    else
        -- newly loaded world
        loaded_world = self.server:add_world_from_name(world_name)
    end
    
	send_command_reply(self, ("World %s loaded from file %q."):format(world_name, file_name))
end

-- save current player's world or specified world to file
function commands_client:world_save(_, args)
    local world_name = args:match("^%s*(.-)%s*$") or self.world.name
    if not self.server.worlds[world_name] then
        send_command_reply(self, "World not found!")
        return
    end
    
    local file_name = self.server.config.worlds_dir .. self.world.name .. ".gzip"
    self.world:save_to_file(file_name)
    
	send_command_reply(self, ("World %s has been saved to %q."):format(world_name, file_name))
end

-- unload a world. 
function commands_client:world_unload(cmd, args)
	local world_name = args:match("^%s*(.-)%s*$")
	if not self.server.worlds[world_name] then
		send_command_reply(self, "World not found!")
		return
	end	
    self.server.worlds:remove(self.server.worlds[world_name])
    send_command_reply(self, ("World %s has been unloaded."):format(world_name))
end

function commands_client:world_join(cmd, args)
	local world_name = args:match("^%s*(.-)%s*$")
	if not self.server.worlds[world_name] then
		send_command_reply(self, "World not found!")
		return
	end
	self:change_world(self.server.worlds[world_name])
	send_command_reply(self, "Changed world to " .. world_name..".")
end

function commands_client:set_default_world(cmd, args)
	local world_name = args:match("^%s*(.-)%s*$")
	if world_name and self.server.worlds[world_name] then
		self.server.config.default_world = world_name
		send_command_reply(self, "Set default world to: " .. world_name)
	else
		send_command_reply(self, "World not found: " .. tostring(world_name or args))
	end
end

function commands_client:set_spawn(cmd, args)
    self.world.spawn_x = self.pos[1]
    self.world.spawn_y = self.pos[2]
    self.world.spawn_z = self.pos[3]
	send_command_reply(self, "Spawn point set to current position.")
end

function commands_client:op(cmd, args)
    self:send_packet(packets.update_user_type, {
        user_type = 0x64
    })
	send_command_reply(self, "Sent OP packet.")
end

function commands_client:players(cmd, args)
    local current_client_list
    send_command_reply(self, "List of players:")
    for _,world in ipairs(self.server.worlds) do
        local client_list = {}
        for _, client in ipairs(world.clients) do
            table.insert(client_list, client.name)
        end
        table.sort(client_list)
        if world == self.world then
            current_client_list = client_list
        else
            send_command_reply(self, (" %s: %s"):format(world.name, table.concat(client_list, ", ")))
        end
    end
    send_command_reply(self, (" Current world(%s): %s"):format(self.world.name, table.concat(current_client_list, ", ")))
end

function commands_client:resend(cmd, args)
	send_command_reply(self, "Re-sending world data...")
	self:send_world(self.world)
end

function commands_client:plugins()
    send_command_reply(self, "Plugin list:")
    local plugin_name_list = {}
    for _,plugin in ipairs(plugins) do
        table.insert(plugin_name_list, tostring(plugin.plugin_name))
    end
    send_command_reply(self, table.concat(plugin_name_list, ", "))
end

function commands_client:help(cmd, args)
	local _commands = {}
	for k in pairs(commands_client) do
		table.insert(_commands, "/"..k)
	end
	table.sort(_commands)
	send_command_reply(self, "List of commands:")
	for _, command in ipairs(_commands) do
		send_command_reply(self, " " .. command)
	end
    plugins:trigger_callback("server_commands_help", self,world)
end


return commands_client
