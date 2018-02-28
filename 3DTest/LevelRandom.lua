local TerrainTypes = require("3DTest.TerrainTypes")
local Map2D = require("HexEngine.Map2D")
local Tile = require("3DTest.Tile")
local Board = require("3DTest.Board")
local UnitTypes = require("3DTest.UnitTypes")
local Unit = require("3DTest.Unit")

print("Loading LevelRandom...")

local LevelRandom = {}

-- Declare globals to be used by this package
local print = print
local setmetatable = setmetatable
local error = error
local type = type
local tostring = tostring
local string = string
local display = display
local math = math

-- Forbid access of all other globals
local _P = {}
setmetatable(_P, {
    __index = function(t,k) error("Attempt to access global key " .. k, 2) end, 
    __newindex = function(t,k,v) error("attempt to set global key " .. k, 2) end })
setfenv(1,_P)

-- Expose public interface with controlled read and/or write access 
-- Key present and false means read only, true means read/write
local accessTable = {
    -- Tile generateTile(q,r) Generates a tile for q,r. Called by the board when getTile() is called but no tile is present for just-in-time placement.
    generateTile = false,
}

-- Creates a level responsible for generating tiles and units.
function LevelRandom:new(board)
    local o = {}
    
    local mBoard = board
    
    local function setup()
        local tile = o:generateTile(0,0);
        mBoard:addTile(tile)
        local unit = Unit:new(mBoard, UnitTypes:getType("LarvaSpear"))
        unit:moveTo(tile)

        tile = o:generateTile(-3,0);
        mBoard:addTile(tile)
        unit = Unit:new(mBoard, UnitTypes:getType("Slime"))
        unit:moveTo(tile)

        tile = o:generateTile(1,2);
        mBoard:addTile(tile)
        unit = Unit:new(mBoard, UnitTypes:getType("SlimeFloating"))
        unit:moveTo(tile)

        tile = o:generateTile(3,-4);
        mBoard:addTile(tile)
        unit = Unit:new(mBoard, UnitTypes:getType("Slime"))
        unit:moveTo(tile)

        tile = o:generateTile(-2,2);
        mBoard:addTile(tile)
        unit = Unit:new(mBoard, UnitTypes:getType("Larva"))
        unit:moveTo(tile)

        tile = o:generateTile(3,-1);
        mBoard:addTile(tile)
        unit = Unit:new(mBoard, UnitTypes:getType("Larva"))
        unit:moveTo(tile)
        
    end
    
    -- Public function generateTile()
    function o:generateTile(q,r)
        local tile = nil
        local rand = math.random(2)
        local elevation = math.random(3)-3 + math.random(3)
        
        if q == 0 and r == 0 then if elevation <1 then elevation = 1 end end
        if q == -3 and r == 0 then if elevation <1 then elevation = 1 end end
        if q == 3 and r == -4 then if elevation <1 then elevation = 1 end end
        if q == -2 and r == 2 then if elevation <1 then elevation = 1 end end
        if q == 3 and r == -1 then if elevation <1 then elevation = 1 end end
        
        if elevation <= 0 then 
            elevation = 0
            tile = Tile:new(mBoard, q, r, TerrainTypes:getType("Water"), elevation)
        elseif elevation > 2 then 
            tile = Tile:new(mBoard, q, r, TerrainTypes:getType("Stone"), elevation)
        else 
            if (rand == 1) then 
                tile = Tile:new(mBoard, q, r, TerrainTypes:getType("Desert"), elevation)
            else
                tile = Tile:new(mBoard, q, r, TerrainTypes:getType("Plain"), elevation)
            end
        end    
--        print("Generated tile", tile, q, r)
        return tile
    end

    setup()
    
    -- Return proxy that enforce access only to public members and methods
    local proxy = {}
    setmetatable(proxy, {
        __index = function(t,k) 
            if accessTable[k] ~= nil
                then return o[k]
            else
                error("Attempt to access key " .. k .. " in instance of type " .. "LevelRandom", 2)
            end
        end, 
        __newindex = function(t,k,v) 
            if accessTable[k] == true
                then return o[k]
            else
                error("Attempt to set key " .. k .. "=" .. v .. " in instance of type " .. "LevelRandom", 2)
            end
        end })
        
    return proxy
end

return LevelRandom

