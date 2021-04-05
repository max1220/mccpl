# mccpl

(Minecraft Classic Protocol Lua)
This library contains utillities for decoding and encoding Minecraft Classic packets,
an abstraction layer for Minecraft Classic Worlds, and even a complete
Minecraft Classic server utilizing this library.



## Installation

    sudo luarocks install luasocket
    sudo luarocks install copas
    sudo luarocks install lua-ezlib
    git clone https://github.com/max1220/mccpl
    ln -s $(PWD)/mccpl /usr/local/share/lua/5.1/

## Server usage

Keep in mind that the server is currently work-in-progress, and provides no authentication!

You can start the server by using:

    cd mccpl/
    ./server/main.lua

Edit the server config in server/config.


## Plugins

### Note! Not all plugin callbacks are properly documented yet, documentation might be out of date!

If you want to write a plugin, you should start by reading the example plugin
source code and the comments at the top of the plugin library source
in `common/plugins.lua`.

Because there is currently no stable API, expect the Plugin API documentation to
be out of date.
You can search the source code for `plugins:trigger_callback(` and `plugins:trigger_callback_unpack(` to see what callbacks are supported and how
they are called.


# TODO

You should also use grep TODO find more TODO's, e.g.:
`rgrep --color=always -H -n TODO`.
This list is just the "major topics".

TODO: Re-add world generator
TODO: Re-add clients
TODO: Write Plugin documentation
