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
    -- visibility(visible) Called when the tile visibility changes
    onVisibility = false,
    -- onSelection(selected) Called when selection status of the tile changes
    onSelection = false,
    -- int elevationLevel The level of elevation of the tile 
    elevationLevel = false,
    -- addUnit(unit) Adds a unit to this tile.
    addUnit = false,
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
            print(">>>>>>>>><<<<<<<< unitUI", unitUI, "mGroup", mGroup)

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

    function o:onSelection(selected)
        mSelected = selected
        o:onVisibility(false)
        o:onVisibility(true)
        board:updateView()
        -- TODO Update in a better way !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    end

    function o:addUnit(unit)
        if mUnit ~= nil then error("Attempt to add unit to time that already has a unit.") end
        mUnit = unit
            
        -- Nothing more to do if there is no UI
        if mGroup == nil then return end;
        
        local unitUI = unit:createUI()
        mGroup:insert(unitUI)
        print(">>>> Added unit to tile ", q, r )
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

