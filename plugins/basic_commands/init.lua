local plugins = require("mccpl.common.plugins")
local protocol_utils = require("mccpl.common.protocol_utils")
local packets = require("mccpl.common.packets")

local plugin = {
    plugin_name = "basic_commands",
    callbacks = {},
    version = "0.0.1",
    license = "MIT",
    author = "max1220",
    description = "Provides basic commands",
	url = "https://github.com/max1220/mccpl",
	commands_description = {
		{"help", "Show help messages"},
		{"plugins", "Show a list of server plugins"},
		{"quit", "Disconnect from server"},
		{"ping", "Sends Pong! as command reply"}
	},
	help_topics = {
		{"help", [[Use /help to show a list of commands,
or use /help <topic> to show a specific help page]]},
	}
}

-- on load generate help text for all plugins!
function plugin.callbacks.server_init(self, last_ret)
	-- pre-generate the help text for the /help command
	local help_text = {}
	for _,_plugin in ipairs(plugins) do
		for _, command_desc in ipairs(_plugin.commands_description or {}) do
			local command_name, command_text = command_desc[1], command_desc[2]
			local help_line = ("&e%s&f - %s(%s)"):format(command_name, command_text, _plugin.plugin_name)
			table.insert(help_text, {command_name, help_line})
		end
	end
	table.sort(help_text, function(a,b)
		return a[1]<b[1]
	end)
	self.help_text = help_text

	-- pre-generate help topics
	local help_topics = {}
	for _,_plugin in ipairs(plugins) do
		for _, topic_desc in ipairs(_plugin.help_topics) do
			local topic_name, topic_text = topic_desc[1], topic_desc[2]
			if not help_topics[topic_name] then
				help_topics[topic_name] = {}
			end
			table.insert(help_topics[topic_name], topic_text)
		end
	end
	self.help_topics = help_topics

	-- pre-generate the /plugins list of plugins
	local plugins_text = {}
	for _,_plugin in ipairs(plugins) do
		local plugin_line = ("&e%s&f - %s"):format(_plugin.plugin_name, _plugin.description)
		table.insert(plugins_text, plugin_line)
	end
	table.sort(plugins_text)
	self.plugins_text = plugins_text

	self.log("plugin", "basic_commands plugin loaded!")
    return false
end

-- this table contaions the commands this plugin defines
-- self is always the plugin, client the
-- all callbacks here take the same arguments:
-- self is the plugin structure that defined this command,
-- client is the client that triggered this command
-- cmd is the command the user typed, without the leading /, and without arguments
-- arg is the arguments supplied to the command(might be nil)
local chat_commands = {}
function chat_commands.help(self, client, cmd, arg)
	if arg then
		-- look up a specific help topic
		if not self.help_topics[arg] then
			client:send_command_reply("The help topic specified was not found!")
			return true
		end
		client:send_command_reply("Help for topic " .. arg)
		for _,topic_text in ipairs(self.help_topics[arg]) do
			client:send_command_reply(topic_text)
		end
	else
		-- show the non-specific help page
		client:send_command_reply("List of commands:")
		for _, help_line in ipairs(self.help_text) do
			client:send_command_reply("  " .. help_line[2])
		end
	end
	return true
end
function chat_commands.plugins(self, client, cmd, arg)
	client:send_command_reply("List of plugins:")
	for _, plugin_line in ipairs(self.plugins_text) do
		client:send_command_reply("  " .. plugin_line)
	end
	return true
end
function chat_commands.quit(self, client, cmd, arg)
	client:send_command_reply("Quitting!(Sending disconnect packet!)")
    client:send_packet(packets.disconnect, {
		player_id = -1,
		message = protocol_utils.string64("Bye! (Quit by command)")
	})
	return true
end
function chat_commands.ping(self, client, cmd, arg)
	client:send_command_reply(client, "Pong!")
	return true
end


-- command callback handler
function plugin.callbacks.server_command(self, last_ret, client, cmd, args)
	if chat_commands[cmd] then
		return true, chat_commands[cmd](self, client, cmd, args)
	end
end

-- the plugin main table needs to be returned
return plugin
