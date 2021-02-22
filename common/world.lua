-- this file contains common functions related to managing minecraft classic worlds
-- for example, it contains a function for getting a world instance, with functions
-- for setting and getting blocks, compressing and uncompressing world data, etc.
local World = {}
local ezlib = require("ezlib")
local struct = require("struct")

-- return a new world object
-- Returned world does not contain any world data yet, use :fill or :load_from_file
function World.new(width, height, depth)
    local world = {}
    world.width = width
    world.height = height
    world.depth = depth

    -- fill the entire world using return value from function if fill is a function,
    -- otherwise assumes fill is a block_type.
    function world:fill(fill)
        local world_data = self.world_data or {}
        for z=0, self.depth-1 do
            local cplane = {}
            for y=0, self.height-1 do
                local cline = {}
                for x=0, self.width-1 do
                    local block_type
                    if type(fill) == "function" then
                        block_type = fill(self, x,y,z)
                    else
                        block_type = fill
                    end
                    cline[x] = block_type
                end
                cplane[y] = cline
            end
            world_data[z] = cplane
        end
        self.world_data = world_data
        return true
    end

    -- set block at x,y,z to block_type
    function world:set_block(x,y,z, block_type)
        if (x < 0) or (y < 0) or (z < 0) or (x >= self.width) or (y >= self.height) or (z >= self.depth) then
            return
        end
        self.world_data[math.floor(z)][math.floor(y)][math.floor(x)] = block_type
        return true
    end

    -- get block at x,y,z
    function world:get_block(x,y,z)
        if (x < 0) or (y < 0) or (z < 0) or (x >= self.width) or (y >= self.height) or (z >= self.depth) then
            return
        end
        return self.world_data[math.floor(z)][math.floor(y)][math.floor(x)]
    end

    -- return true if the block position is valid and not block_type 0
    function world:get_block_bool(x,y,z)
        local b = self:get_block(x,y,z)
        return b and (b ~= 0)
    end

    -- returns true if the block_type at x,y,t represents a solid block
    function world:get_block_solid_bool(x,y,z)
        local b = self:get_block(x,y,z)
        return b and (b ~= 0) and (b ~= 20) and (b ~= 44)
    end

    -- return compressed encoded version of the map content.
    -- the first 4 byte of the returned string is the data compressed data length
    function world:compress()
        local uncompressed = {}
        local i = 1
        for y=0, self.height-1 do
            for z=0, self.depth-1 do
                for x=0, self.width-1 do
                    local block_type = assert(world:get_block(x,y,z))
                    uncompressed[i] = string.char(block_type)
                    i = i + 1
                end
            end
        end
        local uncompressed_str = table.concat(uncompressed)
        local encoded_str = struct.pack(">i4", #uncompressed_str) .. uncompressed_str
        local compressed_str = ezlib.deflate(encoded_str, "gzip")
        return compressed_str, encoded_str
    end

    -- decompress the compressed encoded data into the world
    function world:decompress(world_data_compressed, new_width, new_height, new_depth)
        local encoded = ezlib.inflate(world_data_compressed, "gzip")
        local data = encoded:sub(5)
        local length = struct.unpack(">i4", world_data_compressed)
        assert(new_width*new_height*new_depth == length)
        assert(#data==data)
        self.width,self.height,self.depth = new_width, new_height, new_depth
        self:fill(new_width, new_height, new_depth, function(_world, x,y,z)
                local i = y*new_depth*new_width + z*new_width + x
                return data:byte(i+1)
            end)
    end

    function world:save_to_file(filename)
        -- TODO: Also save dimensions etc.
        local file = assert(io.open(filename, "w"))
        local comp_data = world:compress() .. struct.pack("HHHHHH", self.width, self.height, self.depth, self.spawn_x,self.spawn_y,self.spawn_z)
        file:write(comp_data)
        file:close()
    end

    function world:load_from_file(filename)
        local file = assert(io.open(filename, "r"))
        local comp_data = file:read("*a")
        file:close()
        local data = ezlib.inflate(comp_data, "gzip")

        local w,h,d,sx,sy,sz = struct.unpack("HHHHHH", comp_data:sub(-struct.size("HHHHHH")))

        self.width = assert(tonumber(w))
        self.height = assert(tonumber(h))
        self.depth = assert(tonumber(d))
        self.spawn_x = assert(tonumber(sx))
        self.spawn_y = assert(tonumber(sy))
        self.spawn_z = assert(tonumber(sz))
        world:fill(self.width,self.height,self.depth, function() return 0 end )

        local i = 5
        for y=0, h-1 do
            for z=0, d-1 do
                for x=0, w-1 do
                    local block_type = data:byte(i)
                    world:set_block(x,y,z, block_type)
                    i = i + 1
                end
            end
        end
    end

    return world
end

function World.new_from_file(filename)
    local world = World.new()
    world:load_from_file(filename)
    return world
end


return World
