-- this file contains generic plugin support for applications.
-- A plugin is a table containing some info and callback functions.
-- First, the application has to configure plugin support by providing the
-- logging functions and loading some plugins(using plugins:load_plugin(plugin_name)).
-- Then application needs to call the plugins:trigger_callback(callback_name, ...) function,
-- on important events it wished to add plugin support for: Every plugin(in order they are loaded)
-- is checked for a callback matching callback_name, which is called when found.
-- The last return value of one of these callbacks is returned for the call to plugins:trigger_callback().
-- Also see comments in plugins:trigger_callback(callback_name, ...)

local plugins = {}
-- this table contains the list of loaded plugins(in order), and functions for managing the list of plugins.
-- There should only be one instance of this table per application!
-- The caching behaviour of require() is required!

-- this is added before every require() for the plugins.
-- basically this defines the folder plugins are loaded from.
plugins.base_name = "mccpl.plugins."

-- you need to provide these plugins.log and plugins.logf functions externally,
-- in the application that implements plugin support!
--plugins.log = function(category, ...) end
--plugins.logf = function(category, fmt, ...) end

-- call func using xpcall if available, otherwise use pcall
local function safe_call(func, ...)
    return xpcall and (xpcall(func, debug.traceback, ...)) or (pcall(func, ...))
end

-- return the arg pseudo-table for all vararg-function.
-- Unlike function pack() return {...} end, this also has a n field, contianing the number of returned values.
-- e.g. pack("hello", "world") -- would return a table like {n=2, "hello", "world"}
local function pack2(...)
    return arg 
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
        if plugin.callbacks[callback_name] then
            local ok, ret = safe_call(self.trigger_plugin_callback, plugins, plugin, callback_name, last_ret, ...)
            if not ok then
                -- plugin callback error
                self.logf("error", "An error occured in plugin callback %s for plugin %s", tostring(callback_name), tostring(plugin.plugin_name))
                self.log("error", tostring(ret))
                last_ret = nil -- don't return anything
                break
            end
            if (ret.n == 1) and (type(ret[1]) == "table") then
                -- callback only one value returned, and it's a table. Return that table later(if not overridden)
                last_ret = ret[1]
            elseif ret.n > 0 then
                -- callback returned values, overwrite last return valiue
                last_ret = ret
            end
        end
    end
    return last_ret
end
-- same as :trigger_callback, but automatically unpacks values.
-- Keep in mind that because unpack() only unpacks the continous integer index range,
-- something like return nil,foo probably won't work!
function plugins:trigger_callback_unpack(callback_name, ...)
    local ret = self:trigger_callback(callback_name, ...)
    if ret then
        return unpack(ret)
    end
end

-- trigger a specific callback in the specified plugin.
-- this function is typically called protected(in pcall/xpcall)
function plugins:trigger_plugin_callback(plugin, callback_name, last_ret, ...)
    return pack2(plugin.callbacks[callback_name](plugin, last_ret, ...))
end

-- load a plugin(append to list of loaded plugins)
-- the order in which plugins are loaded is important, because callbacks are called in this order!
function plugins:load_plugin(plugin_name)
    assert(type(plugin_name)=="string")
    self.log("notice", "Loading plugin", plugin_name)
    assert(not self[plugin_name]) -- also so we can't overwrite functions accidentally
    
    -- load the plugin from the basepath and plugin name
    local plugin = require(self.base_name .. plugin_name)
    
    -- check returned plugin
    assert(type(plugin)=="table")
    assert(type(plugin.callbacks)=="table")
    assert(plugin_name == plugin.plugin_name)
    -- TODO: Add more checks for plugins? Maybe provide way to check versions?
    
    -- store reference by name
    self[plugin_name] = plugin
end

return plugins
