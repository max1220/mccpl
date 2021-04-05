--local world_generator = require("server.world_generator")
local plugins = require("mccpl.common.plugins")
local packets = require("mccpl.common.packets")

-- commands are always called with the client as first argument
local commands_client = {}

-- split space-seperated string into argument list
--[[
local function args_split(str)
	local args = {}
	for arg in str:gmatch("%S+") do
		table.insert(args, arg)
	end
	return args
end
]]

-- returns true if the file can be opened for reading(exists and has correct permissions)
local function file_exists(filename)
	local f = io.open(filename, "r")
	if f then
		f:close()
		return true
	end
end

-- get a list of worlds and their connected players
function commands_client:worlds()
	self:send_command_reply("List of worlds:")
    local worlds_list = {}
	for _, world in ipairs(self.server.worlds) do
		table.insert(worlds_list, world.name)
	end
    self:send_command_reply(table.concat(worlds_list, ", "))
end

--[[
function commands_client:world_create(_, args)
	args = args_split(args)
	local world = world_generator:generate_world(unpack(args))
    world.name = name
    self.server.worlds:add(world)
    self:send_command_reply(("Created world %s."):format())
end
]]

-- load a world from file by it's world_name
function commands_client:world_load(_, args)
	local world_name = args:match("^%s*(.-)%s*$")

	local file_name = self.server.config.worlds_dir .. world_name .. ".gzip"
	if not file_exists(file_name) then
		self:send_command_reply("World file not found!")
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
        self:send_command_reply("World re-loaded!")
    else
        -- newly loaded world
        loaded_world = self.server:add_world_from_name(world_name)
    end

	self:send_command_reply(("World %s loaded from file %q."):format(world_name, file_name))
end

-- save current player's world or specified world to file
function commands_client:world_save(_, args)
    local world_name = args:match("^%s*(.-)%s*$") or self.world.name
    if not self.server.worlds[world_name] then
        self:send_command_reply("World not found!")
        return
    end

    local file_name = self.server.config.worlds_dir .. self.world.name .. ".gzip"
    self.world:save_to_file(file_name)

	self:send_command_reply(("World %s has been saved to %q."):format(world_name, file_name))
end

-- unload a world.
function commands_client:world_unload(cmd, args)
	local world_name = args:match("^%s*(.-)%s*$")
	if not self.server.worlds[world_name] then
		self:send_command_reply("World not found!")
		return
	end
	if self.server.worlds.default_world == self.server.worlds[world_name] then
		self:send_command_reply("Can't unload default world!")
		return
	end
    self.server.worlds:remove(self.server.worlds[world_name])
    self:send_command_reply(("World %s has been unloaded."):format(world_name))
end

function commands_client:world_join(cmd, args)
	local world_name = args:match("^%s*(.-)%s*$")
	if not self.server.worlds[world_name] then
		self:send_command_reply("World not found!")
		return
	end
	self:change_world(self.server.worlds[world_name])
	self:send_command_reply("Changed world to " .. world_name..".")
end

function commands_client:set_default_world(cmd, args)
	local world_name = args:match("^%s*(.-)%s*$")
	if world_name and self.server.worlds[world_name] then
		self.server.config.default_world = world_name
		self:send_command_reply("Set default world to: " .. world_name)
	else
		self:send_command_reply("World not found: " .. tostring(world_name or args))
	end
end

function commands_client:set_spawn(cmd, args)
    self.world.spawn_x = self.pos[1]
    self.world.spawn_y = self.pos[2]
    self.world.spawn_z = self.pos[3]
	self:send_command_reply("Spawn point set to current position.")
end


function commands_client:resend(cmd, args)
	self:send_command_reply("Re-sending world data...")
	self:send_world(self.world)
end



function commands_client:op(cmd, args)
    self:send_packet(packets.update_user_type, {
        user_type = 0x64
    })
	self:send_command_reply("Sent OP packet.")
end

function commands_client:players(cmd, args)
    local current_client_list
    self:send_command_reply("List of players:")
    for _,world in ipairs(self.server.worlds) do
        local client_list = {}
        for _, client in ipairs(world.clients) do
            table.insert(client_list, tostring(client.username))
        end
        table.sort(client_list)
        if world == self.world then
            current_client_list = client_list
        else
            self:send_command_reply((" %s: %s"):format(world.name, table.concat(client_list, ", ")))
        end
    end
    if current_client_list then
        self:send_command_reply((" Current world(%s): %s"):format(self.world.name, table.concat(current_client_list, ", ")))
    end
end



return commands_client
