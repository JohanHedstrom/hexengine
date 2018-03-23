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
local ResourceManager = require("3DTest.ResourceManager")

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

--Install all resources
ResourceManager:addImageResource("TilePlain", "3DTest/Resources/plain.png", 137, 167, 0, 8)
ResourceManager:addImageResource("TileWater", "3DTest/Resources/water.png", 139, 167, 0, 8)
ResourceManager:addImageResource("TileSand", "3DTest/Resources/desert.png", 139, 167, 0, 8)
ResourceManager:addImageResource("TileStone", "3DTest/Resources/stone.png", 139, 167, 0, 8)

ResourceManager:addImageResource("UnitSlime", "3DTest/Resources/Units/slime.png", 78, 51, -4, -10)
ResourceManager:addImageResource("UnitSlimeFloating", "3DTest/Resources/Units/slime_floating.png", 69, 95, 0, -35)
ResourceManager:addImageResource("UnitLarva", "3DTest/Resources/Units/larva.png", 77, 46, 0, -8)
ResourceManager:addImageResource("UnitLarvaSpear", "3DTest/Resources/Units/larva_spear.png", 107, 95, 6, -30)
ResourceManager:addImageResource("UnitButterfly", "3DTest/Resources/Units/butterfly.png", 158, 113, -5, -47)

ResourceManager:addImageResource("SelectionOverlay", "3DTest/Resources/selectedOverlay.png", 117, 167, 0, 8)


function ThreeDTest:new(group, width, height)
    local o = {}

    -- Restore the current session, if one is present. The session contains all the data needed to 
    -- restore the current game, or a new session is created to keep track of all the needed data.
    -- Anything non-transient regarding the current game session needs to be stored here.
    local session, wasCreated = PersistentStore.open("session")

    -- Make sure that the session data is saved whenever changed. Saving the persistent store when
    -- there are no changes is cheap, so no problem doing it in enterFrame.
    local function enterFrame(event)
        session:save()
    end

    Runtime:addEventListener('enterFrame', enterFrame)
    
	if wasCreated then 
		print("Starting new game session.")
        
        session:addValue("level", "Island")
        session:addGroup("levelData")
        
    else
        print("Resuming game session.")
    end
    
    -- The hex view for the Test instance (created after the proxy is created)
    local hexView = HexView.createView(group, width, height, false, 50/math.cos(math.pi/6), 0.8)
    
    local board = Board:new(hexView)
    
    -- Restore the level (or reinitialize it)
    local levelName = session.level
    local level = nil
    if levelName == "Island" then 
        level = LevelIsland:new(board, session.levelData)
    else 
        error("Failed to restore session. No level generator with the name \"" .. levelName .. "\" is present.", 1)
    end
    
    if level == nil then 
        error("Failed to restore session. Failed to restore level \"" .. levelName .. "\".", 1)
    end
    
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

game:setScale(0.7)
game:center(0,0)

-- The resize event handler
local function onResize(event)
    print("Resize event!")
    layout()
end

-- Add the "resize" event listener
Runtime:addEventListener( "resize", onResize )

return ThreeDTest

