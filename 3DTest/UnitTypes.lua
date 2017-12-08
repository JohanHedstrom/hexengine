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
unitType:setImagePath("3DTest/Resources/Units/slime.png")
unitType:setImageWidth(78)
unitType:setImageHeight(51)
unitType:setCorrectionX(-4)
unitType:setCorrectionY(-5)
unitType:setMovement(3)
types["Slime"] = unitType;

function UnitTypes:getType(name)
    return types[name];
end

return UnitTypes

