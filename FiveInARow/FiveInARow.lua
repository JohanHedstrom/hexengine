print("Loading FiveInARow...")

local HexView = require("HexEngine.HexView")
local HexUtils = require("HexEngine.HexUtils")
local Map2D = require("HexEngine.Map2D")
local ScrollerInputHandler = require("HexEngine.ScrollerInputHandler")

local FiveInARow = {}

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
local options = options

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
    onHexTouchBegin = false,
    onHexTouchMove = false,
    onHexTouchEnd = false,
    -- Starts test
    start = false,
    resize = false,
    center = false,
    setScale = false,
    
    onHexTap = false,
}

function FiveInARow:new(group, width, height)
    local o = {}

    -- To make it easy choose a size that makes the width of the pointy hex 100
    local size = 50/math.cos(math.pi/6) --58.2--50/math.cos((math.pi/180)*15)
    
    -- The hex view for the Test instance (created after the proxy is created)
    local hexView = HexView.createView(group, width, height, true, size)
    print(hexView:toString())
    local inputHandler = ScrollerInputHandler:new(hexView)

    -- Keeps track of if it is whites turn or blacks
    local mWhiteTurn = true

    -- Keeps track of the stones places on the board, true for white and false for black
    local mStones = Map2D:new()
    
    -- Creates and returns the tile at q,r.
    local function getHex(q,r)
        local hex = nil
        local whiteStone = mStones:get(q,r)
        if whiteStone ~= nil then
            if whiteStone == true then 
                hex = display.newImageRect("FiveInARow/Assets/White.png", 157, 151 )
            else
                hex = display.newImageRect("FiveInARow/Assets/Black.png", 157, 151 )
            end
--            hex = display.newImageRect("FiveInARow/Assets/Blank.png", 157, 151 )
        else
            hex = display.newImageRect("FiveInARow/Assets/Blank.png", 157, 151 )
        end

        if options.debug == true then
            local group = display.newGroup()
            group.alpha = 0.7
            local text = display.newText(q..","..r, 0, 0, native.systemFont, size/3)
            text:setFillColor( 1, 1, 1,0.4)
            group:insert(hex)
            group:insert(text)
            return group
        end
        
        return hex
    end
    
    function o:onHexVisibility(q,r,visible)
--        print("onHexVisibility: ", q, r, visible)
        if visible == true then
            hexView:setHex(q,r,getHex(q,r))
        else
            hexView:removeHex(q,r)
        end
    end

    function o:onHexTap(q,r,x,y)
        -- Do nothing if an already placed stone is tapped
        if mStones:get(q,r) ~= nil then return end
        
        hexView:removeHex(q,r)
        if mWhiteTurn == true then 
            mStones:set(q,r,true)
        else
            mStones:set(q,r,false)
        end
        hexView:setHex(q,r,getHex(q,r))
        
        mWhiteTurn = not mWhiteTurn
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

    inputHandler:setInputHandler(proxy)
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
local game = FiveInARow:new(view, view.width, view.height)

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

return FiveInARow

