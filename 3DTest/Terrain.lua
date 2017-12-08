print("Loading Terrain...")

-- Static information about a type of unit.
local Terrain = {}

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
    imagePath = false,
    setImagePath = false,
    -- Integer with the width of image for the unit.
    imageWidth = false,
    setImageWidth = false,
    -- Integer with the height of image for the unit.
    imageHeight = false,
    setImageHeight = false,
    -- Number with the an optional correction in x of the unit image in pixels.
    correctionX = false,
    setCorrectionX = false,
    -- Number with the an optional correction in y of the unit image in pixels.
    correctionY = false,
    setCorrectionY = false,
    -- Movement cost.
    movementCost = false,
    setMovementCost = false,
}

-- Creates a Terrain 
function Terrain:new(name)
    local o = {}

	o.name = name
	o.imagePath = "default"
    o.imageWidth = 0
    o.imageHeight = 0
	o.correctionX = 0
	o.correctionY = 0
    o.movementCost = 1;

    function o:setImagePath(path)
        o.imagePath = path;
    end

    function o:setImageWidth(width)
        o.imageWidth = width;
    end

    function o:setImageHeight(height)
        o.imageHeight = height;
    end

    function o:setCorrectionX(correctionX)
        o.CorrectionX = correctionX;
    end

    function o:setCorrectionY(correctionY)
        o.CorrectionY = correctionY;
    end

    function o:setMovementCost(movementCost)
        o.MovementCost = movementCost;
    end

    -- Return proxy that enforce access only to public members and methods
    local proxy = {}
    setmetatable(proxy, {
        __index = function(t,k) 
            if accessTable[k] ~= nil
                then return o[k]
            else
                error("Attempt to access key " .. k .. " in instance of type " .. "Terrain", 2)
            end
        end, 
        __newindex = function(t,k,v) 
            if accessTable[k] == true
                then return o[k]
            else
                error("Attempt to set key " .. k .. "=" .. v .. " in instance of type " .. "Terrain", 2)
            end
        end })
    return proxy
end

return Terrain

