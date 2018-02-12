local HexUtils = require("HexEngine.HexUtils")
local Map2D = require("HexEngine.Map2D")
local ResourceManager = require("3DTest.ResourceManager")

print("Loading Unit...")

local Unit = {}

-- Declare globals to be used by this package
local print = print
local setmetatable = setmetatable
local error = error
local type = type
local tostring = tostring
local string = string
local display = display
local table = table
local ipairs = ipairs
local system = system


-- Forbid access of all other globals
local _P = {}
setmetatable(_P, {
    __index = function(t,k) error("Attempt to access global key " .. k, 2) end, 
    __newindex = function(t,k,v) error("attempt to set global key " .. k, 2) end })
setfenv(1,_P)

-- Expose public interface with controlled read and/or write access 
-- Key present and false means read only, true means read/write
local accessTable = {
    -- createUI() Creates the UI for the unit and returns its group.
    createUI = false,
    -- destroyUI(needsRemoval) Sets the UI to nil and optionaly removes it from the stage.
    destroyUI = false,
    -- moveTo(Tile tile) Moves the unit from it's current tile to the provided tile.
    moveTo = false,
    -- bool onTap(q,r) Called when the tile this unit is placed on is tapped (or is in focus). Return true if the tap is handled.
    onTap = false,
    -- Number getMovement() Gets the movement points for this unit
    getMovement = false,
}


-- Creates a Unit
function Unit:new(board, unitType)
    local o = {}
    
    -- The unit type
    local mType = unitType
    
    -- The unit UI or nil if it currently has no UI
    local mGroup = nil
    
    -- The tile this unit is placed on, or nil if it isn't placed on the board.
    local mTile = nil

    -- The Map2D with info of the selected tiles. The info obj: {movementCost:0}
    local mSelection = nil
    
    -- Selects the tiles this unit can move to or attack, including the tile the unit is standing on.
    function o:selectReachableTiles()
        local start = system.getTimer()
        if mTile == nil then mSelection = nil; return end
        
        mSelection = Map2D:new()

        local movementPoints = o:getMovement()
        
        local function selectNeighbors(origin, movementCost)
            origin:onSelect(true)
            mSelection:set(origin.q, origin.r, {tile=origin, movementCost=movementCost})
            
            for q,r in HexUtils.neighbors(origin.q, origin.r) do
                local info = mSelection:get(q,r)
                local keepGoing = (info == nil)
                if info ~= nil then
                    -- check if this route is cheaper than the previous
                    keepGoing = (info.tile:getMovementCost(self) + movementCost) < info.movementCost
                end
                
                if keepGoing then
                    local tile = board:getTile(q,r)
                    if tile ~= nil then
                        local cost = tile:getMovementCost(self) + movementCost
                        if cost <= movementPoints then
                            selectNeighbors(tile, cost)
                        end
                    end
                end
            end
        end
        
        selectNeighbors(mTile, 0)
        
        print("elapsed:", system.getTimer() - start)
    end
    
    function o:getMovement()
        return mType.movement
    end
    
    function o:createUI()
        if mGroup ~= nil then return mGroup end
    
        mGroup = display.newGroup()
        local image = ResourceManager:create(unitType.resource);
        mGroup:insert(image)
         
        return mGroup
    end
    
    -- Destroys the UI of this unit. If needsRemoval is true or omitted the UI will also be removed from the display.
    function o:destroyUI(needsRemoval)
        if mGroup == nil then return end
        if needsRemoval == true or needsRemoval == nil then mGroup:removeSelf() end
        mGroup = nil
    end        
        
    function o:onTap(q,r)
        if type(q) ~= "number" then error("Unit:onTap(): q is of invalid type " .. type(q), 2) end 
        if type(r) ~= "number" then error("Unit:onTap(): r is of invalid type " .. type(r), 2) end 
        print(unitType.name .. " tapped at "..q..","..r)
    
        if mSelection == nil then
            o:selectReachableTiles()
            if mSelection ~= nil then 
                board:setFocus(self)
            end
        elseif q == mTile.q and r == mTile.r then
            for qv,rv,info in mSelection:iterator() do
                info.tile:onSelect(false)
            end
            mSelection = nil
            board:setFocus(nil)
        else
            for qv,rv,info in mSelection:iterator() do
                local tile = info.tile
                tile:onSelect(false)
                if tile.q == q and tile.r == r then o:moveTo(tile) end
            end
            mSelection = nil
            board:setFocus(nil)
        end
        
--[[        if mSelection == nil then
            mSelection = {}
            for q,r in HexUtils.neighbors(mTile.q, mTile.r) do
                local tile = board:getTile(q,r)
                tile:onSelect(true)
                table.insert(mSelection, tile)
            end
            mTile:onSelect(true)
            board:setFocus(self)
        elseif q == mTile.q and r == mTile.r then
            board:setFocus(nil)
            mTile:onSelect(false)
            for i,tile in ipairs(mSelection) do
                tile:onSelect(false)
            end
            mSelection = nil
        else
            mTile:onSelect(false)
            for i,tile in ipairs(mSelection) do
                tile:onSelect(false)
                if tile.q == q and tile.r == r then o:moveTo(tile) end
            end
            mSelection = nil
            board:setFocus(nil)
        end
--]]
        return true
    end
    
    function o:moveTo(tile)
        if mTile ~= nil then mTile:setUnit(nil) end
    
        mTile = tile
        if tile ~= nil then 
            tile:setUnit(self) 
        else
            -- If moved from the board then destroy the UI (and remove it from the stage)
            o:destroyUI(true)
        end
    end
        
    -- Return proxy that enforce access only to public members and methods
    local proxy = {}
    setmetatable(proxy, {
        __index = function(t,k) 
            if accessTable[k] ~= nil
                then return o[k]
            else
                error("Attempt to access key " .. k .. " in instance of type " .. "Unit", 2)
            end
        end, 
        __newindex = function(t,k,v) 
            if accessTable[k] == true
                then return o[k]
            else
                error("Attempt to set key " .. k .. "=" .. v .. " in instance of type " .. "Unit", 2)
            end
        end })
    return proxy
end

return Unit

