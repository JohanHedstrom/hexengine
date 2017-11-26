print("Loading Unit...")

local unit = {}

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
    -- visibility(visible) Called when the unit visibility changes
    onVisibility = false,
    -- onSelection(selected) Called when selection status of the unit changes
    onSelection = false,
}

-- Creates a Unit that belongs to the provided level located at q,r, that is of the provided unit type
-- world - Map2D containing all the tiles of the world
function Unit:new(level, q, r, unitType)
    local o = {}
    
    local mSelected = false
    
    local function createUI()
        local group = display.newGroup()
        local bgImage = display.newImageRect(group, terrain.bgImagePath, terrain.w, terrain.h )
        local selectionOverlay = nil
        if mSelected == true then 
            selectionOverlay = display.newImageRect(group, "3DTest/Resources/selectedOverlay.png", 117, 167 )
        end
        
        -- Take corrections and elevation into account
        local elevationPixels = Unit:getElevationPixels(elevationLevel)
        bgImage.x = terrain.correctionX
        bgImage.y = terrain.correctionY + elevationPixels
        
        -- And the selection overlay if any
        if selectionOverlay ~= nil then 
            selectionOverlay.x = terrain.correctionX
            selectionOverlay.y = terrain.correctionY + elevationPixels
        end
        return group
    end
    
    function o:onVisibility(visible)
        print("Unit:visibility()", visible, board, q, r)
        if visible == true then
            board:setHex(q,r,createUI())
        else
            board:removeHex(q,r)
        end
    end

    function o:onSelection(selected)
        mSelected = selected
        o:onVisibility(false)
        o:onVisibility(true)
        board:updateView()
        -- TODO Update in a better way !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
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

return unit

