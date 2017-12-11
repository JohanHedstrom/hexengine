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
}

-- Transform elevation level to elevation pixels
function Tile:getElevationPixels(level)
    if level == 0 then return 0
    elseif level == 1 then return -5
    else return level * -10 + 5 end
end

-- Creates a tile that belongs to the provided board and is placed at q,r, with the provided terrain
function Tile:new(board, q, r, terrain, elevationLevel)
    local o = {}
    o.elevationLevel = elevationLevel
    o.q = q
    o.r = r
    
    local mSelected = false
    
    local mUnit = nil
    
    local mGroup = nil
        
    local function createUI()
        mGroup = display.newGroup()
        local bgImage = display.newImageRect(mGroup, terrain.imagePath, terrain.imageWidth, terrain.imageHeight )
        local selectionOverlay = nil
        if mSelected == true then 
            selectionOverlay = display.newImageRect(mGroup, "3DTest/Resources/selectedOverlay.png", 117, 167 )
        end
        
        -- Take corrections and elevation into account
        local elevationPixels = Tile:getElevationPixels(elevationLevel)
        bgImage.x = terrain.correctionX
        bgImage.y = terrain.correctionY + elevationPixels
        
        -- Add the selection overlay if any
        if selectionOverlay ~= nil then 
            selectionOverlay.x = terrain.correctionX
            selectionOverlay.y = terrain.correctionY + elevationPixels
        end
        
        -- Add unit if any
        if mUnit ~= nil then 
            local unitUI = mUnit:createUI()
            unitUI.y = elevationPixels
            mGroup:insert(unitUI)
        end
        
        return mGroup
    end
    
    function o:onVisibility(visible)
        --print("Tile:visibility()", visible, board, q, r)
        if visible == true then
            board:setHex(q,r,createUI())
        else
            board:removeHex(q,r)
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
        mSelected = selected == true;

        -- TODO Update in a better way !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        o:onVisibility(false)
        o:onVisibility(true)
        board:updateView()
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

