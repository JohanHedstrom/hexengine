local TerrainTypes = require("3DTest.TerrainTypes")
local Map2D = require("HexEngine.Map2D")
local Tile = require("3DTest.Tile")
local Board = require("3DTest.Board")
local UnitTypes = require("3DTest.UnitTypes")
local Unit = require("3DTest.Unit")
local HexUtils = require("HexEngine.HexUtils")

print("Loading LevelIsland...")

local LevelIsland = {}

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
function LevelIsland:new(board, data)
    local o = {}
    
    local mBoard = board

    local function setup()
                
        -- Generate heightmap
        local heightMap = Map2D:new()
    
        local function generateMountain(q,r,radius)
            for i=1,radius do
                for cq,cr in HexUtils.circle(q,r,i) do
                    local rand = math.random(3)-2
                    local height = radius+1-i+rand
                    local currentHeight = heightMap:get(cq,cr)
                    if currentHeight == nil or currentHeight < height then
                        heightMap:set(cq,cr,height)
                    end
                end
            end
            
            local rand = math.random(3)-2
            local height = radius+1+rand
            local currentHeight = heightMap:get(q,r)
            if currentHeight == nil or currentHeight < height then
                heightMap:set(q,r,height)
            end
        end

--[[        generateMountain(-5,0,5)
        generateMountain(5,1,5)
        generateMountain(0,0,1)
        generateMountain(4,-7,2)
        generateMountain(-4,8,2)
--]]       

        generateMountain(0,0,6)
 
        -- Generate tiles depending on heightmap
        print("...", heightMap.size)
        for q,r,height in heightMap:iterator() do
            local tile = nil
            if height <= 0 then 
                tile = mBoard:createTile(q, r, "Water", height)
            elseif height > 4 then 
                tile = mBoard:createTile(q, r, "Stone", height)
            elseif height == 1 then 
                tile = mBoard:createTile(q, r, "Desert", height)
            else 
                tile = mBoard:createTile(q, r, "Plain", height)
            end
        end
        
        mBoard:createUnit(0,0,"LarvaSpear")
        mBoard:createUnit(1,0,"Larva")
        mBoard:createUnit(-1,0,"Butterfly")

        local enemyCount = 0
        while enemyCount < 5 do
            local lq = math.random(11) - 6
            local lr = math.random(11) - 6
            --print(lq, lr)
            local tile = mBoard:getTile(lq,lr)
            if tile ~= nil and tile:getUnit() == nil and tile.terrain.name ~= "Water" then
                local r = math.random(10)
                if(r >= 9) then
                    mBoard:createUnit(lq,lr,"SlimeFloating")
                else
                    mBoard:createUnit(lq,lr,"Slime")
                end
                enemyCount = enemyCount + 1
            end
        end   
    end
    
    -- Public function generateTile()
    function o:generateTile(q,r)
        return mBoard:createTile(q, r, "Water", 0)
    end

    -- Perform setup if not already done
    if not data:has("initialized") then 
        print("Performing Island level setup.")
        data:addValue("initialized", true)
        setup()
    else
        print("Resuming Island level.")
    end
    
    -- Return proxy that enforce access only to public members and methods
    local proxy = {}
    setmetatable(proxy, {
        __index = function(t,k) 
            if accessTable[k] ~= nil
                then return o[k]
            else
                error("Attempt to access key " .. k .. " in instance of type " .. "LevelIsland", 2)
            end
        end, 
        __newindex = function(t,k,v) 
            if accessTable[k] == true
                then return o[k]
            else
                error("Attempt to set key " .. k .. "=" .. v .. " in instance of type " .. "LevelIsland", 2)
            end
        end })
        
    return proxy
end

return LevelIsland

