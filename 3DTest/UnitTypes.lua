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
unitType:setCorrectionY(-10)
unitType:setMovement(3)
types["Slime"] = unitType;

-------- SlimeFloating
local unitType = UnitType:new("SlimeFloating")
unitType:setImagePath("3DTest/Resources/Units/slime_floating.png")
unitType:setImageWidth(69)
unitType:setImageHeight(95)
unitType:setCorrectionX(0)
unitType:setCorrectionY(-35)
unitType:setMovement(2)
types["SlimeFloating"] = unitType;

-------- Larva
unitType = UnitType:new("Larva")
unitType:setImagePath("3DTest/Resources/Units/larva.png")
unitType:setImageWidth(77)
unitType:setImageHeight(46)
unitType:setCorrectionX(0)
unitType:setCorrectionY(-8)
unitType:setMovement(5)
types["Larva"] = unitType;

-------- LarvaSpear
unitType = UnitType:new("LarvaSpear")
unitType:setImagePath("3DTest/Resources/Units/larva_spear.png")
unitType:setImageWidth(107)
unitType:setImageHeight(95)
unitType:setCorrectionX(6)
unitType:setCorrectionY(-30)
unitType:setMovement(2)
types["LarvaSpear"] = unitType;

function UnitTypes:getType(name)
    local t = types[name];
    if t == nil then error("Failed to get unit type \"" .. name .. "\" That type doesn't exist.") end
    return t
end

return UnitTypes

