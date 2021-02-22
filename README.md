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



# TODO

You should also use grep to find more TODO's

TODO: Re-add world generator
TODO: Re-add clients
TODO: Write documentation
