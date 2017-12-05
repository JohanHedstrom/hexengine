print("Loading UnitType...")

-- Static information about a type of unit.
local unitType = {}

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
    -- String with the unit type name
    name = false,
    -- String with the path to the image for the unit.
    imagePath = true,
    -- Integer with the width of image for the unit.
    imageWidth = true,
    -- Integer with the height of image for the unit.
    imageHeight = true,
    -- Number with the an optional correction in x of the unit image in pixels.
    correctionX = true,
    -- Number with the an optional correction in y of the unit image in pixels.
    correctionY = true,
    -- The number of tiles this unit type can move.
    movement = true,
}

-- Creates a UnitType that belongs to the provided level located at q,r, that is of the provided UnitType type
-- world - Map2D containing all the tiles of the world
function UnitType:new(name)
    local o = {}

	o.name = name
	o.imagePath = ""
    o.imageWidth = 0
    o.imageHeight = 0
	o.correctionX = 0
	o.correctionY = 0
	    
    -- Return proxy that enforce access only to public members and methods
    local proxy = {}
    setmetatable(proxy, {
        __index = function(t,k) 
            if accessTable[k] ~= nil
                then return o[k]
            else
                error("Attempt to access key " .. k .. " in instance of type " .. "UnitType", 2)
            end
        end, 
        __newindex = function(t,k,v) 
            if accessTable[k] == true
                then return o[k]
            else
                error("Attempt to set key " .. k .. "=" .. v .. " in instance of type " .. "UnitType", 2)
            end
        end })
    return proxy
end

return unitType

