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
    -- String with the terrain type name
    name = false,
    -- The name of the terrain resource image.
    resource = false,
    setResource = false,
    -- Movement cost.
    movementCost = false,
    setMovementCost = false,
}

-- Creates a Terrain 
function Terrain:new(name)
    local o = {}

	o.name = name
	o.resource = ""
    o.movementCost = 1;

    function o:setResource(name)
        o.resource = name;
    end

    function o:setMovementCost(movementCost)
        o.movementCost = movementCost;
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

