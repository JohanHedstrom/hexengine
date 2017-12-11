local TerrainTypes = require("3DTest.TerrainTypes")
local Map2D = require("HexEngine.Map2D")
local Tile = require("3DTest.Tile")
local ScrollerInputHandler = require("HexEngine.ScrollerInputHandler")
local Unit = require("3DTest.Unit")
local UnitTypes = require("3DTest.UnitTypes")

print("Loading Board...")

local Board = {}

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
    -- getTile(q,r) Returns the Tile under q,r or nil if that coordinate is not part of the Board. 
    getTile = false,
    onHexVisibility = false,
}

-- Creates a Board on which manages tiles, units, etc. The visual representation is managed by the 
-- View which displays part of the board.
function Board:new(view)
    local o = {}
    
    local mTiles = Map2D:new()

    -- Set up tap handler
    local mInputHandler = ScrollerInputHandler:new(view)
    view:setInputHandler(mInputHandler)

	local mTapHandler = {}
	function mTapHandler:onHexTap(q,r,x,y)
        print("Tapped: ", q, r)
    end

	mInputHandler:setInputHandler(mTapHandler)    
    
    -- Public function getTile()
    function o:getTile(q,r)
        local tile = mTiles:get(q,r)
        if tile == nil then 
            local rand = math.random(2)
            local elevation = math.random(3)-3 + math.random(3)
            
            if q == 0 and r == 0 then if elevation <1 then elevation = 1 end end
            if q == -3 and r == 0 then if elevation <1 then elevation = 1 end end
            if q == 3 and r == -4 then if elevation <1 then elevation = 1 end end
            if q == -2 and r == 2 then if elevation <1 then elevation = 1 end end
            if q == 3 and r == -1 then if elevation <1 then elevation = 1 end end
            
            if elevation <= 0 then 
                elevation = 0
                tile = Tile:new(view, q, r, TerrainTypes:getType("Water"), elevation)
            elseif elevation > 2 then 
                tile = Tile:new(view, q, r, TerrainTypes:getType("Stone"), elevation)
            else 
                if (rand == 1) then 
                    tile = Tile:new(view, q, r, TerrainTypes:getType("Desert"), elevation)
                else
                    tile = Tile:new(view, q, r, TerrainTypes:getType("Plain"), elevation)
                end
            end    
            mTiles:set(q,r,tile)
        end
        return tile
    end

    -- Called by the view when a tile becomes visible/invisible
    function o:onHexVisibility(q,r,visible)
        local tile = self:getTile(q,r)
        tile:onVisibility(visible)
    end
    
    local tile = o:getTile(0,0);
    local unit = Unit:new(o, UnitTypes:getType("LarvaSpear"))
    tile:addUnit(unit)

    tile = o:getTile(-3,0);
    unit = Unit:new(o, UnitTypes:getType("Slime"))
    tile:addUnit(unit)

    tile = o:getTile(1,2);
    unit = Unit:new(o, UnitTypes:getType("SlimeFloating"))
    tile:addUnit(unit)

    tile = o:getTile(3,-4);
    unit = Unit:new(o, UnitTypes:getType("Slime"))
    tile:addUnit(unit)

    tile = o:getTile(-2,2);
    unit = Unit:new(o, UnitTypes:getType("Larva"))
    tile:addUnit(unit)

    tile = o:getTile(3,-1);
    unit = Unit:new(o, UnitTypes:getType("Larva"))
    tile:addUnit(unit)
    
    -- Return proxy that enforce access only to public members and methods
    local proxy = {}
    setmetatable(proxy, {
        __index = function(t,k) 
            if accessTable[k] ~= nil
                then return o[k]
            else
                error("Attempt to access key " .. k .. " in instance of type " .. "Board", 2)
            end
        end, 
        __newindex = function(t,k,v) 
            if accessTable[k] == true
                then return o[k]
            else
                error("Attempt to set key " .. k .. "=" .. v .. " in instance of type " .. "Board", 2)
            end
        end })
        
    view:setVisibilityHandler(proxy)
                
    return proxy
end

return Board

