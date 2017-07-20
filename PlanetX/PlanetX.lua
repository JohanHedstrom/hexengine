print("Loading PlanetX...")

local HexView = require("HexEngine.HexView")
local HexUtils = require("HexEngine.HexUtils")
local Map2D = require("HexEngine.Map2D")
local ScrollerInputHandler = require("HexEngine.ScrollerInputHandler")

local PlanetX = {}

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
    updateView = false,
}

function PlanetX:new(group, width, height)
    local o = {}

    -- The hex view for the Test instance (created after the proxy is created)
    local hexView = HexView.createView(group, width, height, true, 50/math.cos(math.pi/6))
    local inputHandler = ScrollerInputHandler:new(hexView)
    hexView:setInputHandler(inputHandler)

    local mSelected = Map2D:new()

    local world = Map2D:new()

    local terrainTypes = {}
    local terrainCount = 0;

    local function addTerrainType(terrainType, movementCost, bgImagePath, behindImagePath, w, h)
        terrainCount = terrainCount + 1;
        terrainTypes[terrainCount] = {type=terrainType, movementCost=movementCost, bgImagePath=bgImagePath, behindImagePath=behindImagePath, w=w, h=h}

        print("Added Terrain(" ..terrainType ..") movementCost: " ..movementCost .. " terrain count: " .. terrainCount)
    end

    addTerrainType("barren", 1, "PlanetX/Resources/barren.png", nil, 120, 139);
    addTerrainType("barren", 1, "PlanetX/Resources/barren2.png", nil, 120, 139);
    addTerrainType("rock", 1, "PlanetX/Resources/rock1.png", nil, 188, 188);
    addTerrainType("rock", 1, "PlanetX/Resources/rock2.png", nil, 184, 184  );
 --   addTerrainType("rock", 1, "PlanetX/Resources/rock3.png", nil, 156, 156  );

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
        
        local group = display.newGroup()
        
        local terrainType = terrainTypes[tile.terrainIndex];
        
        local bgImage = display.newImageRect(group, terrainType.bgImagePath, terrainType.w, terrainType.h )
--        local borderImage = display.newImageRect(group, "PlanetX/Resources/border.png", 87, 100)	
--        if terrainType.behindImagePath ~= nil then
--            local behindImage = display.newImageRect(group, terrainType.behindImagePath, terrainType.w, terrainType.h)	
--        end
--[[        local hex = HexUtils.createHexagon(true, 50)
        hex:setFillColor( 0.3, 0.4, 1.0, 0.0)
        hex:setStrokeColor( 0.4, 0.4, 0.4, 0.6)
        hex.strokeWidth = 2
        group:insert(hex)
]]--        
        return group
    end
    
    function o:onHexVisibility(q,r,visible)
        if visible == true then
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
        hexView:setScale(s,0,0)
    end
    
    function o:updateView()
        hexView:updateView()
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
local game = PlanetX:new(view, view.width, view.height)

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
    game:updateView()
end

layout()

game:setScale(1.0)
game:center(0,0)
game:updateView()

-- The resize event handler
local function onResize(event)
    print("Resize event!")
    layout()
end

-- Add the "resize" event listener
Runtime:addEventListener( "resize", onResize )

return PlanetX

