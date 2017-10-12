print("Loading 3DTest...")

local perlin = require("3DTest.PerlinNoise")
perlin:load()

local HexView = require("HexEngine.HexView")
local HexUtils = require("HexEngine.HexUtils")
local Map2D = require("HexEngine.Map2D")
local ScrollerInputHandler = require("HexEngine.ScrollerInputHandler")
local PersistentStore = require("HexEngine.PersistentStore")

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
    updateView = false,
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
    addTerrainType("mountain", 1, "3DTest/Resources/mountain.png", 137, 174, 0, 8);
    
    local function getElevationPixels(level)
        if level == 0 then return 0
        elseif level == 1 then return -5
        else return level * -10 + 5 end
    end
    
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
            local elevation = math.random(5)-2 
            --print("perlin noise: ", noise, "elevation: ", elevation)
            
            -- Choose terrain depending on elevation
            local terrainIndex = 0
            if elevation <= 0 then 
                elevation = 0
                terrainIndex = 1 -- water
            elseif elevation < 2 then
                terrainIndex = 2 -- plain
            else
                terrainIndex = math.random(2)+1
            end
            tile = {terrain=terrainTypes[terrainIndex], elevation=elevation}
--            if(tile.terrain.type == "plain") then tile.elevation = math.random(2) end
--            if(tile.terrain.type == "desert") then tile.elevation = math.random(2) + 1 end
        end

		if tile.type ~= "hole" then
			world:set(q,r,tile)
		end
        
        local group = display.newGroup()
        
        -- Add the terain
        local terrain = tile.terrain;
        local bgImage = display.newImageRect(group, terrain.bgImagePath, terrain.w, terrain.h )
        local selectionOverlay = nil
        if mSelected:get(q,r) == true then 
            selectionOverlay = display.newImageRect(group, "3DTest/Resources/selectedOverlay.png", 117, 167 )
        end
        
        -- Take corrections and elevation into account
        local elevationPixels = getElevationPixels(tile.elevation)
        bgImage.x = terrain.correctionX
        bgImage.y = terrain.correctionY + elevationPixels
        
        -- And the selection overlay if any
        if selectionOverlay ~= nil then 
            selectionOverlay.x = terrain.correctionX
            selectionOverlay.y = terrain.correctionY + elevationPixels
        end
        
--        if tile.terrain.type == "water" then bgImage.y = 5 end
        --print("elevation", tile.elevation)
        
--        local testHex = hexView:createTile();
--        testHex.alpha = 0.5
--        group:insert(testHex)
        
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
    
	-- Setup a tap handler that toggles selected on/off
	local mTapHandler = {}
	function mTapHandler:onHexTap(q,r,x,y)
        local boardX, boardY = hexView:contentToBoard(x,y);
        
        -- Check if tile below left, below, or below right overshadows the tapped tile
        local tile = world:get(q-1,r+1);
        local elevPixels = getElevationPixels(tile.elevation);
        local tq, tr = hexView:boardToTile(boardX, boardY-elevPixels)
        if tq == (q-1) and tr == (r+1) then q=tq; r=tr; print("overshadowed!") end

        tile = world:get(q,r+1);
        elevPixels = getElevationPixels(tile.elevation);
        tq, tr = hexView:boardToTile(boardX, boardY-elevPixels)
        if tq == q and tr == (r+1) then q=tq; r=tr; print("overshadowed!") end

        tile = world:get(q+1,r);
        elevPixels = getElevationPixels(tile.elevation);
        tq, tr = hexView:boardToTile(boardX, boardY-elevPixels)
        if tq == (q+1) and tr == r then q=tq; r=tr; print("overshadowed!") end

--        print("tap:", q, r, " checked: ",q, r+1, elevPixels, "result: ", tq, tr)
        
        local tile = world:get(q-1,r);
        local below = world:get(q,r+1);
        local belowRight = world:get(q+1,r+1);
        
		print("Tap on: ", q, r)
		local selected = mSelected:get(q,r)
		if selected == nil then
			mSelected:set(q,r,true)
		else
			mSelected:erase(q,r)
		end
		hexView:setHex(q,r,getHex(q,r))
        hexView:updateView()
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

return ThreeDTest

