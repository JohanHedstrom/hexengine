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
    -- placeTile(tile) Places the provided Tile on the board. 
    placeTile = false,
    onHexVisibility = false,
    -- setFocus(Tappable) Sets/unsets a tappable object (implements bool onTap()) that will receive all tap events regardless of where the tap is made. 
    setFocus = false,
    -- The view of the board 
    view = false,
    -- setMapGenerator(generator) If set, generator:generateTile(q,r) will be called if Board:getTile() is called for a non-existing tile.
    setMapGenerator = false,
}

-- Creates a Board on which manages tiles, units, etc. The visual representation is managed by the 
-- View which displays part of the board. The provided level is responsible for populating the board 
-- with tiles, units, etc.
function Board:new(view)
    local o = {}
    
    o.view = view
    
    local mTiles = Map2D:new()

    -- The object currently in focus (will receive all tap events) or nil
    local mFocus = nil
    
    -- The map generator, if any, responsible for generating tiles on-the-fly
    local mMapGenerator = nil
    
    -- Set up tap handler
    local mInputHandler = ScrollerInputHandler:new(view)

    function o:getTile(q,r)
        local tile = mTiles:get(q,r)
        if tile == nil and mMapGenerator ~= nil then
            tile = mMapGenerator:generateTile(q,r)
            if tile ~= nil then
                mTiles:set(q,r,tile)
            end
        end
        return tile
    end

    function o:placeTile(tile)
        if tile == nil then return end
        -- TODO: handle replaced tiles correctly
        mTiles:set(tile.q, tile.r, tile)
    end
    
    function o:setMapGenerator(generator)
        if generator ~= nil and generator.generateTile == nil then error("Attempt to set an invalid map generator. It must have the function generateTile()", 2) end
        mMapGenerator = generator
    end
    
--[[    
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
                tile = Tile:new(self, q, r, TerrainTypes:getType("Water"), elevation)
            elseif elevation > 2 then 
                tile = Tile:new(self, q, r, TerrainTypes:getType("Stone"), elevation)
            else 
                if (rand == 1) then 
                    tile = Tile:new(self, q, r, TerrainTypes:getType("Desert"), elevation)
                else
                    tile = Tile:new(self, q, r, TerrainTypes:getType("Plain"), elevation)
                end
            end    
            mTiles:set(q,r,tile)
        end
        return tile
    end
    
    local tile = o:getTile(0,0);
    local unit = Unit:new(o, UnitTypes:getType("LarvaSpear"))
    unit:moveTo(tile)

    tile = o:getTile(-3,0);
    unit = Unit:new(o, UnitTypes:getType("Slime"))
    unit:moveTo(tile)

    tile = o:getTile(1,2);
    unit = Unit:new(o, UnitTypes:getType("SlimeFloating"))
    unit:moveTo(tile)

    tile = o:getTile(3,-4);
    unit = Unit:new(o, UnitTypes:getType("Slime"))
    unit:moveTo(tile)

    tile = o:getTile(-2,2);
    unit = Unit:new(o, UnitTypes:getType("Larva"))
    unit:moveTo(tile)

    tile = o:getTile(3,-1);
    unit = Unit:new(o, UnitTypes:getType("Larva"))
    unit:moveTo(tile)

--]]
    
    
    -- Called by the view when a tile becomes visible/invisible
    function o:onHexVisibility(q,r,visible)
        local tile = self:getTile(q,r)
        if tile ~= nil then 
            tile:onVisibility(visible)
        end
    end
        
    -- Tap handler
	local mTapHandler = {}
	function mTapHandler:onHexTap(q,r,x,y)
        local boardX, boardY = view:contentToBoard(x,y);
        local tq, tr, elevPixels
        
        -- Check if tile below left, below, or below right overshadows the tapped tile
        local overshadowed = false
        local t = o:getTile(q-1,r+1);
        if t ~= nil then
            elevPixels = Tile:getElevationPixels(t.elevationLevel);
            tq, tr = view:boardToTile(boardX, boardY-elevPixels)
            if tq == (q-1) and tr == (r+1) then q=tq; r=tr; overshadowed = true end
        end
            
        if overshadowed == false then 
            t = o:getTile(q,r+1);
            if t ~= nil then
                elevPixels = Tile:getElevationPixels(t.elevationLevel);
                tq, tr = view:boardToTile(boardX, boardY-elevPixels)
                if tq == q and tr == (r+1) then q=tq; r=tr; overshadowed = true end
            end
        end
        
        if overshadowed == false then
            t = o:getTile(q+1,r);
            if t ~= nil then
                elevPixels = Tile:getElevationPixels(t.elevationLevel);
                tq, tr = view:boardToTile(boardX, boardY-elevPixels)
                if tq == (q+1) and tr == r then q=tq; r=tr; overshadowed = true end
            end
        end
        
--        print("tap:", q, r, " checked: ",q, r+1, elevPixels, "result: ", tq, tr)
        
		print("Tap on: ", q, r)
        
        -- Redirect to focus object if any
        if mFocus ~= nil then return mFocus:onTap(q,r) end

        -- Otherwise redirect to the tapped tile
        local tile = o:getTile(q,r);
        if tile ~= nil then
            tile:onTap(q,r)
        end
    end
    
	mInputHandler:setInputHandler(mTapHandler)    

    function o:setFocus(obj)
        mFocus = obj
    end
    
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

