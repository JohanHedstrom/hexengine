print("Loading Tile...")

local Tile = {}

-- Declare globals to be used by this package
local print = print
local setmetatable = setmetatable
local error = error
local type = type
local tostring = tostring
local string = string
local display = display
local math = math
local options = options
local native = native

-- Forbid access of all other globals
local _P = {}
setmetatable(_P, {
    __index = function(t,k) error("Attempt to access global key " .. k, 2) end, 
    __newindex = function(t,k,v) error("attempt to set global key " .. k, 2) end })
setfenv(1,_P)

-- Expose public interface with controlled read and/or write access 
-- Key present and false means read only, true means read/write
local accessTable = {
    -- The q coordinate of the tile
    q = false,
    -- The r coordinate of the tile
    r = false,
    -- The terran type
    terrain = false,
    -- visibility(visible) Called when the tile visibility changes
    onVisibility = false,
    -- onTap() Called when the tile is tapped
    onTap = false,
    -- onSelect(bool selected) Call to select/deselect the tile
    onSelect = false,
    -- int elevationLevel The level of elevation of the tile 
    elevationLevel = false,
    -- setUnit(Unit) Sets/unsets the unit of this tile. Don't call directly, use Unit:move() instead.
    setUnit = false,
    -- Unit getUnit() Sets/unsets the unit of this tile. Don't call directly, use Unit:move() instead.
    getUnit = false,
    -- Number getMovementCost(Unit) Returns the movement cost for this tile for the provided unit. 
    -- If the unit can't enter this tile then -1 is returned.
    getMovementCost = false,
}

-- Transform elevation level to elevation pixels
function Tile:getElevationPixels(level)
    if level == 0 then return 0
    elseif level == 1 then return -7
    else return level * -12 + 5 end
end

-- Creates a tile that belongs to the provided board and is placed at q,r, with the provided terrain
function Tile:new(board, q, r, terrain, elevationLevel)
    local o = {}
    o.elevationLevel = elevationLevel
    o.q = q
    o.r = r
    o.terrain = terrain

    local mSelected = false
    
    local mUnit = nil
        
    -- The root of the tile UI
    local mGroup = nil
    
    -- The selection overlay
    local mSelectionOverlay = nil
        
    local function createUI()
        mGroup = display.newGroup()
        local bgImage = display.newImageRect(mGroup, terrain.imagePath, terrain.imageWidth, terrain.imageHeight)
        mSelectionOverlay = display.newImageRect(mGroup, "3DTest/Resources/selectedOverlay.png", 117, 167 )
        
        -- Take corrections and elevation into account
        local elevationPixels = Tile:getElevationPixels(elevationLevel)
        bgImage:translate(terrain.correctionX, terrain.correctionY + elevationPixels)
        
        -- Add the selection overlay and set its starting visibility
        if mSelected then mSelectionOverlay.isVisible = true else mSelectionOverlay.isVisible = false end
        mSelectionOverlay:translate(terrain.correctionX, terrain.correctionY + elevationPixels)
        
        -- Add unit if any
        if mUnit ~= nil then 
            local unitUI = mUnit:createUI()
            unitUI:translate(0, elevationPixels)
            mGroup:insert(unitUI)
        end
        
        -- Add the coordinate if debug is enabled
        if options.debug then
            local text = display.newText(q..","..r, 0, 0, native.systemFont, board.view.hexSize/2.5)
            text.alpha = 0.6
            text:translate(0, elevationPixels)
            mGroup:insert(text)
        end
        
        return mGroup
    end
    
    function o:onVisibility(visible)
        --print("Tile:visibility()", visible, board, q, r)
        if visible == true then
            board.view:setHex(q,r,createUI())
        else
            board.view:removeHex(q,r)
            mGroup = nil
            if mUnit ~= nil then mUnit:destroyUI() end
        end
    end

    function o:onTap()
        -- Redirect to the unit if any
        if mUnit ~= nil then return mUnit:onTap(q,r) else return false end
    end
    
    function o:onSelect(selected)
        if selected == mSelected then return end
        mSelected = (selected == true)

        -- Nothing to do if there is no UI
        if mSelectionOverlay == nil then return end

        mSelectionOverlay.isVisible = selected
    end

    function o:setUnit(unit)
        if (unit ~= nil) and (mUnit ~= nil) then error("Attempt to add unit to tile that already has a unit.") end
        mUnit = unit
        
        -- If unit was cleared then nothing to do (it will automatically be removed from the 
        -- display hierarcy if moved/destroyed)
        if unit == nil then return end

        if mGroup == nil then 
            -- If placed on a tile with no UI then destroy the UI of the Unit
            if mUnit then mUnit:destroyUI(true) end
        else
            -- Otherwise create the UI (if not already created) and insert it into the group
            local unitUI = unit:createUI()
            mGroup:insert(unitUI)
            unitUI.y = Tile:getElevationPixels(elevationLevel)
        end
        
    end

    function o:getUnit()
        return mUnit
    end
        
    function o:getMovementCost(unit)
        if mUnit ~= nil then return math.huge end 
        if terrain.name == "Water" then return math.huge end
        return terrain.movementCost
    end
    
        
    -- Return proxy that enforce access only to public members and methods
    local proxy = {}
    setmetatable(proxy, {
        __index = function(t,k) 
            if accessTable[k] ~= nil
                then return o[k]
            else
                error("Attempt to access key " .. k .. " in instance of type " .. "Tile", 2)
            end
        end, 
        __newindex = function(t,k,v) 
            if accessTable[k] == true
                then return o[k]
            else
                error("Attempt to set key " .. k .. "=" .. v .. " in instance of type " .. "Tile", 2)
            end
        end })
    return proxy
end

return Tile

