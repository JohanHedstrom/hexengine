local Terrain = require("3DTest.Terrain")

print("Loading TerrainTypes...")

local TerrainTypes = {}

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

-------- Plain
local terrainType = Terrain:new("Plain")
terrainType:setImagePath("3DTest/Resources/plain.png")
terrainType:setImageWidth(137)
terrainType:setImageHeight(167)
terrainType:setCorrectionX(0)
terrainType.setCorrectionY(8)
terrainType.setMovementCost(1)
types["Plain"] = terrainType

function TerrainTypes:getType(name)
    if name == nil then error("Attempt to access a terrain type with a nil name") end
    local terrainType = types[name]
    if terrainType == nil then error("Attempt to access nonexistent terrain type " .. name) end
    return terrainType
end

return TerrainTypes

