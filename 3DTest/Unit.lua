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
}

-- Creates a Unit
function Unit:new(board, unitType)
    local o = {}
    
    local mType = unitType
    
    local mGroup = nil
        
    function o:createUI()
        if mGroup ~= nil then return mGroup end
    
        mGroup = display.newGroup()
        local image = display.newImageRect(mGroup, mType.imagePath, mType.imageWidth, mType.imageHeight)
         
        -- Take corrections into account
        image.x = mType.correctionX
        image.y = mType.correctionY
        
        return mGroup
    end
    
    -- Destroys the UI of this unit. If needsRemoval is true or omitted the UI will also be removed from the display.
    function o:destroyUI(needsRemoval)
        if mGroup == nil then return end
        if needsRemoval == true or needsRemoval == nil then mGroup:removeSelf() end
        mGroup = nil
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

