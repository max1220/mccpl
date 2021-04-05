-- this file contains generic plugin support for applications.
-- A plugin is a table containing some information about a plugin,
-- and a set of callback functions.
-- In the application there are plugin triggers that call the associated plugin
-- callbacks in every plugin that has a callback for this trigger.
-- First, the application has to configure plugin support by providing the
-- logging functions and loading some plugins:
--   plugins = require("plugins") -- load this file
--   plugins.log = print -- provide logging functions
--   plugins.logf = function(cat, fmt, ....) print(cat, fmt:format(...)) end
--   plugins.base_name = "base_name." -- concatenated with the plugin name for require().
--   plugins:load_plugin("plugin_name") -- load an example plugin(will require("base_name.plugin_name"))
-- Then application needs to call the plugins:trigger_callback(callback_name, ...) function,
-- on important events it wished to add plugin support for: Every plugin(in order they are loaded)
-- is checked for a callback matching callback_name, which is called when found.
-- the first two arguments for a callback function call are always the plugin table itself,
-- then the return value of the previous callback, if any.
-- If the first value returned by a callback is the boolean value true,
-- no further callbacks will be called for this call to trigger_callback.
-- The last return value of one of these callbacks is returned for the call to plugins:trigger_callback().
-- Also see comments in plugins:trigger_callback(callback_name, ...)

local plugins = {}
-- this table contains the list of loaded plugins(in order), and functions for managing the list of plugins.
-- There should only be one instance of this table per application!
-- The caching behaviour of require() is required!

-- this is added before every require() for the plugins.
-- basically this defines the folder plugins are loaded from.
plugins.base_name = "mccpl.plugins."

-- you can disable the use of pcall/xpcall.
-- Errors will be propagated, and plugins errors might crash the server!
plugins.disable_pcall = true

-- you need to provide these plugins.log and plugins.logf functions externally,
-- in the application that implements plugin support!
--plugins.log = function(category, ...) end
--plugins.logf = function(category, fmt, ...) end

-- check if xpcall works as expected.
-- lua5.1 does not support passing arguments without a closure, while luajit does.
local function xpcall_test()
	if not xpcall then
		return
	end
	local ok,ret_a,ret_b = xpcall(function(a,b) assert(a=="test1"); assert(b=="test2"); return "ok",a..b end, debug.traceback, "test1", "test2")
	if ok and (ret_a == "ok") and (ret_b == "test1test2") then
		return true -- xpcall works as expected
	end
end
local use_xpcall = xpcall_test()

-- call func using xpcall if available, otherwise use pcall
local function safe_call(func, ...)
	if use_xpcall then
		return xpcall(func, debug.traceback, ...)
	else
		return pcall(func, ...)
	end
end

-- return a table containing all vararg-arguments, and the count of arguments.
-- e.g. pack2("hello", "world") -- would return a table like: {n=2, "hello", "world"}
local function pack2(...)
	local t = {...}
	t.n = select("#", ...)
    return t
end


-- trigger a specific callback in the specified plugin.
-- this function is typically called protected(in pcall/xpcall)
function plugins:trigger_plugin_callback(plugin, callback_name, last_ret, ...)
    return pack2(plugin.callbacks[callback_name](plugin, last_ret, ...))
end

-- from the perspective of an application making use of this library for
-- plugin implementation, this is the most important function:
-- It takes a callback_name, and calls the callbacks matching that name for every plugin.
-- additional arguments are passed to the plugin callbacks.
-- It returns a table containing the last return value of the last callback, in load order.
-- If the callback returned a single table only, this table is returned instead.
-- If the callback retuned no values(Not even nil!), the return value is not affected by this callback.
function plugins:trigger_callback(callback_name, ...)
    self.log("debug3", "trigger_callback", callback_name)
    local last_ret
    for _,plugin in ipairs(self) do
		local ok,ret
        if plugin.callbacks[callback_name] and self.disable_pcall then
			ret = self:trigger_plugin_callback(plugin, callback_name, last_ret, ...)
			ok = true
		elseif plugin.callbacks[callback_name] then
			ok, ret = safe_call(self.trigger_plugin_callback, self, plugin, callback_name, last_ret, ...)
            if not ok then
                -- plugin callback error
                self.logf("error", "An error occured in plugin callback %s for plugin %s", tostring(callback_name), tostring(plugin.plugin_name))
                self.log("error", tostring(ret))
            end
        end
		if ok and (ret.n > 0) then
			-- callback returned without error
			last_ret = ret
			if ret[1]==true then
				break
			end
		end
    end
    return last_ret
end
-- same as :trigger_callback, but automatically unpacks values.
-- The first returned value from the callback(abort boolean) is not returned
-- Keep in mind that because unpack() only unpacks the continous integer index range,
-- something like return nil,foo probably won't work!
function plugins:trigger_callback_unpack(callback_name, ...)
    local ret = self:trigger_callback(callback_name, ...)
    if ret then
		return unpack(ret, 2, ret.n)
    end
end


-- load a plugin(append to list of loaded plugins)
-- the order in which plugins are loaded is important, because callbacks are called in this order!
function plugins:load_plugin(plugin_name)
    assert(type(plugin_name)=="string")
    assert(not self[plugin_name]) -- also so we can't overwrite functions accidentally
	self.log("notice", "Loading plugin", plugin_name)

    -- load the plugin from the basepath and plugin name
    local plugin = require(self.base_name .. plugin_name)

	plugin.log = self.log
	plugin.logf = self.logf

    -- check returned plugin
    assert(type(plugin)=="table")
    assert(type(plugin.callbacks)=="table")
    assert(plugin_name == plugin.plugin_name)
    -- TODO: Add more checks for plugins? Maybe provide way to check versions?

	self.logf("notice", "Loaded plugin: %s (%s)", plugin_name, tostring(plugin))

    -- by name
    self[plugin_name] = plugin

	-- by numerical index
	-- The order of plugins in the plugins table is important for callbacks!
	table.insert(self, plugin)
end

return plugins
