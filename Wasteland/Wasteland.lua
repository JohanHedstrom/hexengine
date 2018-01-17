print("Loading Wasteland...")

local HexView = require("HexEngine.HexView")
local HexUtils = require("HexEngine.HexUtils")
local Map2D = require("HexEngine.Map2D")
local ScrollerInputHandler = require("HexEngine.ScrollerInputHandler")

local Wasteland = {}

-- Declare globals to be used by this package
local print = print
local setmetatable = setmetatable
local error = error
local type = type
local display = display
local native = native
local transition = transition
local Runtime = Runtime
local system = system
local math = math

-- Forbid access of all other globals
local _P = {}
setmetatable(_P, {
    __index = function(t,k) error("Attempt to access global key " .. k, 2) end, 
    __newindex = function(t,k,v) error("attempt to set global key " .. k, 2) end })
setfenv(1,_P)

-- Expose public interface with controlled read and/or write access 
-- Key present and false means read only, true means read/write
local accessTable = {
    -- Callbacks from HexView
    onHexVisibility = false,
    -- Starts test
    start = false,
    resize = false,
    center = false,
    setScale = false,
}

function Wasteland:new(group, width, height)
    local o = {}

    -- The hex view for the Test instance (created after the proxy is created)
    local hexView = HexView.createView(group, width, height, true, 50)
    local inputHandler = ScrollerInputHandler:new(hexView)

    local mSelected = Map2D:new()

    local world = Map2D:new()

    local terrainTypes = {}
    local terrainCount = 0;

    local function addTerrainType(terrainType, movementCost, bgImagePath, behindImagePath, w, h)
        terrainCount = terrainCount + 1;
        terrainTypes[terrainCount] = {type=terrainType, movementCost=movementCost, bgImagePath=bgImagePath, behindImagePath=behindImagePath, w=w, h=h}

        print("Added Terrain(" ..terrainType ..") movementCost: " ..movementCost .. " terrain count: " .. terrainCount)
    end

    addTerrainType("plains", 1, "Wasteland/images/terrain/plains_50.png", nil, 87, 100);
    addTerrainType("rubble", 3, "Wasteland/images/terrain/rubble_50.png", nil, 87, 100);
    addTerrainType("swamp", 5, "Wasteland/images/terrain/swamp_50.png", nil, 107, 122);
    addTerrainType("dirt", 2, "Wasteland/images/terrain/dirt_50.png", nil, 87, 100);
    addTerrainType("mountain", 20, "Wasteland/images/terrain/mountain_bg_50.png", "Wasteland/images/terrain/mountain_behind_50.png", 107, 122);
    addTerrainType("monolith", 20, "Wasteland/images/terrain/monolith_bg_50.png", "Wasteland/images/terrain/monolith_behind_50.png", 236, 270);

    -- Returns the tile at x,z, creating it if not already in the world.
    -- tile: {terrainIndex=nr, selectType=nil/"normal"/"danger", selectedText=nil/"some text"}
    local function getHex(q,r)
        local tile = world:get(q,r)
        if tile == nil then
            local terrainIndex = math.random(terrainCount)
            tile = {terrainIndex=terrainIndex}
            world:set(q,r,tile)
            --tile.selectType = "normal"
            --if z == 1 then tile.selectType = "danger" end
            --tile.selectText = ""..x..","..z .."("..tile.terrainIndex..")"
            --print("Generated new terrain \"" ..World.terrainTypes[terrainIndex].type .." at " ..x .."," ..z)
        end
        
        local terrainType = terrainTypes[tile.terrainIndex];
        
        local hex = display.newImageRect(terrainType.bgImagePath, terrainType.w, terrainType.h );
        
--[[        local hex = display.newGroup()
                
        local bgImage = display.newImageRect(hex, terrainType.bgImagePath, terrainType.w, terrainType.h )
        local borderImage = display.newImageRect(hex, "Wasteland/images/hex_outline.png", 109, 126)	
        if terrainType.behindImagePath ~= nil then
            local behindImage = display.newImageRect(hex, terrainType.behindImagePath, terrainType.w, terrainType.h)	
        end
--]]        
--[[        local hex = HexUtils.createHexagon(true, 50)
        hex:setFillColor( 0.3, 0.4, 1.0, 0.0)
        hex:setStrokeColor( 0.4, 0.4, 0.4, 0.6)
        hex.strokeWidth = 2
        hex:insert(hex)
]]--        
        return hex
    end
    
    local initialized = false
    
    function o:onHexVisibility(q,r,visible)
        if visible == true then
        
--[[            if initialized == false then 
                initialized = true
                for qv,rv in HexUtils.verticals(q-10,r-10,true,50) do
                    for qh,rh in HexUtils.horizontals(qv,rv,true, 50) do
                        hexView:setHex(qh,rh,getHex(qh,rh))
                    end
                end
                print("Initialized board!")
            end
--]]        
            hexView:setHex(q,r,getHex(q,r))
        else
            hexView:removeHex(q,r)
        end
    end

    function o:resize(w,h) 
        hexView:resize(w,h)
    end
    
    function o:center(q,r)
        hexView:center(q,r)
    end

    function o:setScale(s)
        hexView:setScale(s)
    end
    
    -- Return proxy that enforce access only to public members and methods
    local proxy = {}
    setmetatable(proxy, {
        __index = function(t,k) 
            if accessTable[k] ~= nil
                then return o[k]
            else
                error("Attempt to access key " .. k .. " in instance of type " .. "Test", 2)
            end
        end, 
        __newindex = function(t,k,v) 
            if accessTable[k] == true
                then return o[k]
            else
                error("Attempt to set key " .. k .. "=" .. v .. " in instance of type " .. "Test", 2)
            end
        end })

    hexView:setVisibilityHandler(proxy)
    return proxy
end

--local view = display.newContainer(100, 100)
local view = display.newGroup()
view.height = 100
view.width = 100
view.anchorX = 0
view.anchorY = 0
view.anchorChildren = false
local game = Wasteland:new(view, view.width, view.height)

local function layout()
    print("content: ", display.contentWidth, display.contentHeight)
    print("pixel: ", display.pixelWidth, display.pixelHeight)
    print("actualContent: ", display.actualContentWidth, display.actualContentHeight)

if display.actualContentWidth < display.actualContentHeight then
    print("Content scale: "..(display.pixelWidth/display.actualContentWidth))
else
    print("Content scale: "..(display.pixelWidth/display.actualContentHeight))
end

--    view1.width = display.contentWidth
--    view1.height = display.contentHeight
    game:resize(display.contentWidth, display.contentHeight)
end

layout()

game:setScale(1.0)
game:center(0,0)

-- The resize event handler
local function onResize(event)
    print("Resize event!")
    layout()
end

-- Add the "resize" event listener
Runtime:addEventListener( "resize", onResize )

return Wasteland

