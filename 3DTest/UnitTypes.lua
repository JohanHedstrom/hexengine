local UnitType = require("3DTest.UnitType")

print("Loading UnitTypes...")

local UnitTypes = {}

local types = {}

-- Declare globals to be used by this package
local print = print
local setmetatable = setmetatable
local error = error
local type = type
local tostring = tostring
local string = string

-- Forbid access of all other globals
local _P = {}
setmetatable(_P, {
    __index = function(t,k) error("Attempt to access global key " .. k, 2) end, 
    __newindex = function(t,k,v) error("attempt to set global key " .. k, 2) end })
setfenv(1,_P)

-------- Slime
local unitType = UnitType:new("Slime")
unitType:setResource("UnitSlime")
unitType:setMovement(1)
unitType:setHitpoints(1)
unitType:setDisplayXOffset(10)
unitType:setDisplayYOffset(-40)
types[unitType.name] = unitType;

-------- SlimeFloating
local unitType = UnitType:new("SlimeFloating")
unitType:setResource("UnitSlimeFloating")
unitType:setMovement(2)
unitType:setHitpoints(2)
unitType:setDisplayXOffset(0)
unitType:setDisplayYOffset(-60)
types[unitType.name] = unitType;

-------- Larva
local unitType = UnitType:new("Larva")
unitType:setResource("UnitLarva")
unitType:setMovement(1)
unitType:setHitpoints(1)
unitType:setDisplayXOffset(15)
unitType:setDisplayYOffset(-38)
types[unitType.name] = unitType;

-------- LarvaSpear
local unitType = UnitType:new("LarvaSpear")
unitType:setResource("UnitLarvaSpear")
unitType:setMovement(2)
unitType:setHitpoints(3)
unitType:setDisplayXOffset(5)
unitType:setDisplayYOffset(-45)
types[unitType.name] = unitType;

-------- Butterfly
local unitType = UnitType:new("Butterfly")
unitType:setResource("UnitButterfly")
unitType:setMovement(3)
unitType:setHitpoints(2)
unitType:setDisplayXOffset(-25)
unitType:setDisplayYOffset(-47)
types[unitType.name] = unitType;

function UnitTypes:getType(name)
    local t = types[name];
    if t == nil then error("Failed to get unit type \"" .. name .. "\" That type doesn't exist.") end
    return t
end

return UnitTypes

