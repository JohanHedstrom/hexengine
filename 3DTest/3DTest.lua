print("Loading 3DTest...")

local perlin = require("3DTest.PerlinNoise")
perlin:load()

local HexView = require("HexEngine.HexView")
local HexUtils = require("HexEngine.HexUtils")
local Map2D = require("HexEngine.Map2D")
local ScrollerInputHandler = require("HexEngine.ScrollerInputHandler")
local PersistentStore = require("HexEngine.PersistentStore")
local Board = require("3DTest.Board")
local Tile = require("3DTest.Tile")
local Unit = require("3DTest.Unit")
local UnitTypes = require("3DTest.UnitTypes")
local LevelRandom = require("3DTest.LevelRandom")
local LevelIsland = require("3DTest.LevelIsland")

local ThreeDTest = {}

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

--local view = display.newContainer(100, 100)
local view = display.newGroup()
view.height = 100
view.width = 100
view.anchorX = 0
view.anchorY = 0
view.anchorChildren = false

function ThreeDTest:new(group, width, height)
    local o = {}

    -- The hex view for the Test instance (created after the proxy is created)
    local hexView = HexView.createView(group, width, height, false, 50/math.cos(math.pi/6), 0.8)
    
    local board = Board:new(hexView)
    local level = LevelIsland:new(board)
    board:setMapGenerator(level)
    
    function o:resize(w,h) 
        hexView:resize(w,h)
    end
    
    function o:center(q,r)
        hexView:center(q,r)
    end

    function o:setScale(s)
        hexView:setScale(s,0,0)
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
        
    return proxy
end

function ThreeDTest:old_new(group, width, height)
    local o = {}

    -- The hex view for the Test instance (created after the proxy is created)
    local hexView = HexView.createView(group, width, height, false, 50/math.cos(math.pi/6), 0.8)
    local inputHandler = ScrollerInputHandler:new(hexView)
    hexView:setInputHandler(inputHandler)

    local mSelected = Map2D:new()

    local world = Map2D:new()

    local terrainTypes = {}
    local terrainCount = 0;

    local function addTerrainType(terrainType, movementCost, bgImagePath, w, h, correctionX, correctionY)
        terrainCount = terrainCount + 1;
        terrainTypes[terrainCount] = {type=terrainType, movementCost=movementCost, bgImagePath=bgImagePath, w=w, h=h,
            correctionX=correctionX, correctionY=correctionY}

        print("Added Terrain(" ..terrainType ..") movementCost: " ..movementCost .. " terrain count: " .. terrainCount)
    end

    addTerrainType("water", 1, "3DTest/Resources/water.png", 137, 167, 0, 8);
    addTerrainType("plain", 1, "3DTest/Resources/plain.png", 137, 167, 0, 8);
    addTerrainType("desert", 1, "3DTest/Resources/desert.png", 137, 167, 0, 8);
    addTerrainType("stone", 1, "3DTest/Resources/stone.png", 139, 167, 0, 8);
        
    -- Returns the tile at x,z, creating it if not already in the world.
    -- The elevation is how high the tile is lifted, 0 means waterlevel, 1 ground, 2 raised, 3 max raised
    -- tile: {terrain=terrain elevation=0...3}
    local function getHex(q,r)

        local tile = world:get(q,r)
        
        -- Generate a tile if it didn't exist
        if tile == nil then
--            local terrainIndex = math.random(terrainCount)

            -- Get elevation from perlin noise
            --local noise = (perlin:noise(q/10, r/10, 1)) * 15
            --local elevation = math.floor(noise)  
            local elevation = math.random(2)-2 + math.random(2)
            --print("perlin noise: ", noise, "elevation: ", elevation)
            
            -- Choose terrain depending on elevation
            local terrainIndex = 0
            if elevation <= 0 then 
                elevation = 0
                terrainIndex = 1 -- water
            elseif elevation < 3 then
                terrainIndex = math.random(2)+1
            else
                terrainIndex = math.random(2)+2
            end
            
            tile = Tile:new(hexView, q, r, terrainTypes[terrainIndex], elevation)
              
            world:set(q,r,tile)
        end

        return tile
    end
    
    function o:onHexVisibility(q,r,visible)
        local tile = getHex(q,r)
        tile:onVisibility(visible)
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
    
	-- Setup a tap handler that toggles selected on/off
	local mTapHandler = {}
	function mTapHandler:onHexTap(q,r,x,y)
        local boardX, boardY = hexView:contentToBoard(x,y);
        
        -- Check if tile below left, below, or below right overshadows the tapped tile
        local overshadowed = false
        local t = world:get(q-1,r+1);
        local elevPixels = Tile:getElevationPixels(t.elevationLevel);
        local tq, tr = hexView:boardToTile(boardX, boardY-elevPixels)
        if tq == (q-1) and tr == (r+1) then q=tq; r=tr; overshadowed = true end
        
        if overshadowed == false then 
            t = world:get(q,r+1);
            elevPixels = Tile:getElevationPixels(t.elevationLevel);
            tq, tr = hexView:boardToTile(boardX, boardY-elevPixels)
            if tq == q and tr == (r+1) then q=tq; r=tr; overshadowed = true end
        end
        
        if overshadowed == false then
            t = world:get(q+1,r);
            elevPixels = Tile:getElevationPixels(t.elevationLevel);
            tq, tr = hexView:boardToTile(boardX, boardY-elevPixels)
            if tq == (q+1) and tr == r then q=tq; r=tr; overshadowed = true end
        end
        
--        print("tap:", q, r, " checked: ",q, r+1, elevPixels, "result: ", tq, tr)
        
        local tile = world:get(q,r);
        
		print("Tap on: ", q, r)
		local selected = mSelected:get(q,r)
		if selected == nil then
			mSelected:set(q,r,true)
            tile:onSelection(true)
		else
			mSelected:erase(q,r)
            tile:onSelection(false)
		end

	end
	inputHandler:setInputHandler(mTapHandler)    

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

local game = ThreeDTest:new(view, view.width, view.height)

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

--	view.x = 150
--	view.y = 150
--    game:resize(display.contentWidth-300, display.contentHeight-300)
end

layout()

game:setScale(0.5)
game:center(0,0)

-- The resize event handler
local function onResize(event)
    print("Resize event!")
    layout()
end

-- Add the "resize" event listener
Runtime:addEventListener( "resize", onResize )

return ThreeDTest

