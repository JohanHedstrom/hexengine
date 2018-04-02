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

-- Used to generate unique names for all created units
local unitCounter = 0

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
    -- Tile createTile(q,r,type,elevation) Creates a tile of the specified type and place it at q,r on the board with the given elevation. 
    createTile = false,
    -- bool removeTile(q,r) Removes the tile at q,r. Returns true if a tile was removed.
    destroyTile = false,
    -- Unit createUnit(q,r,type) Creates a unit of the specified type and place it at q,r on the board.
    createUnit = false,
    -- setFocus(Tappable) Sets/unsets a tappable object (implements bool onTap()) that will receive all tap events regardless of where the tap is made. 
    setFocus = false,
    -- The view of the board 
    view = false,
    -- setMapGenerator(generator) If set, generator:generateTile(q,r) will be called if Board:getTile() is called for a non-existing tile.
    setMapGenerator = false,
    -- inputHandler The input handler that takes care of all touch events to pan and zoom the map, etc.
    inputHandler = false,
}

-- Creates a Board which manages tiles, units, etc. The visual representation is managed by the 
-- view which displays part of the board. Persistent session board state is provided in the state
-- object. Board state will either be restored or initialized.
function Board:new(view, state)
    local o = {}
    
    o.view = view
    
    -- The proxy that expose the API
    local proxy = {}
    
    -- Allow a hex to undershoot a maximum of one hex height. Needed so that tiles above transparent tiles 
    -- (water for instance) aren't flagged as no longer visible when in fact they are still visible because 
    -- of the undershoot.    
    view:setMaxTileUndershoot(view.hexHeight)
    
    -- The Tile objects currently on the board.
    local mTiles = Map2D:new()

    -- The persistent data required to recreate all the tiles on the board. This is a Map2D backed up by
    -- the persistent group state.map which contains {name=terrain, elevation=height} objects.
    local mTilesData = nil;
    
    -- The object currently in focus (will receive all tap events) or nil
    local mFocus = nil
    
    -- The map generator, if any, responsible for generating tiles on-the-fly
    local mMapGenerator = nil
    
    -- Set up tap handler
    o.inputHandler = ScrollerInputHandler:new(view)
    
    -- The maximum elevation level of a tile placed so far
    local mMaxElevationLevel = 0

    local function restoreBoardState()
        -- Restore all board state
        if not state:has("map") then
            print("Starting with a clean board state.")
            state:addGroup("map", true)
            mTilesData = Map2D:new(state.map)
            
            state:addGroup("units")
        else
            print("Restoring board tiles...")
            mTilesData = Map2D:new(state.map)
            for q, r, v in mTilesData:iterator() do
                --print(q,r,v)
                local tile = o:createTile(q, r, v.name, v.elevation, true)
            end

            print("Restoring units...")
            for k,unitGroup in state.units:groupPairs() do
                print("unit: ", k)
                local i = string.find(k, "_")
                local unitType = string.sub(k,0,i-1)
                print(i, unitType)

                local unit = Unit:new(proxy, UnitTypes:getType(unitType), k, unitGroup)
                unitCounter = unitCounter + 1
            end
        end    
    end
    
    function o:getTile(q,r)
        local tile = mTiles:get(q,r)
        if tile == nil and mMapGenerator ~= nil then
            tile = mMapGenerator:generateTile(q,r)
        end
        return tile
    end

    function o:createTile(q,r,terrainType,elevation,suppressPersistance)
		if type(q) ~= "number" then error("q is of invalid type " .. type(q), 2) end 
		if type(r) ~= "number" then error("r is of invalid type " .. type(r), 2) end 
		if type(terrainType) ~= "string" then error("terrainType is of invalid type " .. type(terrainType), 2) end 
        if elevation == nil then elevation = 0 end

        local terrain = TerrainTypes:getType(terrainType);
        if terrain == nil then error("Terrain type " .. type(name) .. " doesn't exist.", 2) end

        local tile = Tile:new(proxy, q, r, terrain, elevation)
        if tile == nil then error("Failed to create tile.", 2) end
        
        -- TODO: handle replaced tiles correctly
        if suppressPersistance == nil or suppressPersistance == false then
            --print("Updated tiles data!")
            mTilesData:set(tile.q, tile.r, {name=tile.terrain.name, elevation=tile.elevationLevel})
        end
        mTiles:set(tile.q, tile.r, tile)
        
        if tile.elevationLevel > mMaxElevationLevel then
            mMaxElevationLevel = tile.elevationLevel
            print("New maximum elevation level of "..mMaxElevationLevel.." detected!")
            -- Update the maximum tile overshoot to elevation pixels + a full hex height for any unit. This 
            -- prevents tiles from being flagged as no longer visible when they are visible because of overshoot.
            -- (*-1 because elevation pixels are actually negative)
            view:setMaxTileOvershoot(Tile:getElevationPixels(mMaxElevationLevel)*-1 + view.hexHeight)
        end
                
        return tile
    end
    
    function o:createUnit(q,r,unitType)
        -- Generate unique unit id
        unitCounter = unitCounter + 1
        local unitID = unitType.."_"..unitCounter

        print("Creating unit "..unitID)
 
        if state.units:has(unitID) then error("Creation of unit "..unitID.." failed. Persisted data already exists!", 2) end
        local unitState = state.units:addGroup(unitID)
        local unit = Unit:new(proxy, UnitTypes:getType(unitType), unitID, unitState)

        local tile = o:getTile(q,r)
        if tile == nil then error("Creation of unit "..unitID.." failed. No tile at provided coordinate.", 2) end
        unit:moveTo(tile)
    end
    
    function o:setMapGenerator(generator)
        if generator ~= nil and generator.generateTile == nil then error("Attempt to set an invalid map generator. It must have the function generateTile()", 2) end
        mMapGenerator = generator
    end    
    
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
        -- Get the origin tile set when originally touching the tile. Use this as the tap tile coordinate 
        -- since the calculated tile coordinate from the board coordinate is not valid because of tile 
        -- elevation.
        local origin = o.inputHandler:getOrigin()
        if origin ~= nil then 
            print("Tap on: ", q, r, "origin: ", origin.q, origin.r)
        else
            print("Tap on: ", q, r, "(no origin)")
        end
        
        if origin ~= nil then
            -- Redirect to focus object if any
            if mFocus ~= nil then return mFocus:onTap(origin.q, origin.r) end

            -- Otherwise redirect to the tapped tile
            local tile = o:getTile(origin.q, origin.r);
            if tile ~= nil then
                tile:onTap()
            end
        end
    end
    
	o.inputHandler:setInputHandler(mTapHandler)    

    function o:setFocus(obj)
        mFocus = obj
    end
    
    view:setVisibilityHandler(o)
    
    -- Return proxy that enforce access only to public members and methods
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

    restoreBoardState()
        
    return proxy
end

return Board

