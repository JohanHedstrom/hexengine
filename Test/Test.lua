print("Loading Test...")

-- Test settings
local squishFactor = 0.85
local isPointyTop = true

local HexView = require("HexEngine.HexView")
local HexUtils = require("HexEngine.HexUtils")
local Map2D = require("HexEngine.Map2D")
local ScrollerInputHandler = require("HexEngine.ScrollerInputHandler")
local PersistentStore = require("HexEngine.PersistentStore")

local Test = {}

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

function Test:new(group, width, height)
    local o = {}

    -- The hex view for the Test instance (created after the proxy is created)
    local hexView = HexView.createView(group, width, height, isPointyTop, 50/math.cos(math.pi/6), squishFactor)
    local inputHandler = ScrollerInputHandler:new(hexView)
    hexView:setMaxTileOvershoot(50)
    hexView:setMaxTileUndershoot(50)
	
    local mSelected = Map2D:new()
		
    local world = Map2D:new()

    -- Returns the tile at x,z, creating it if not already in the world.
	local function getHex(q,r)
        local group = display.newGroup()
		local hex = HexUtils.createHexagon(isPointyTop, hexView.hexSize, squishFactor)
        if mSelected:get(q,r) == true then 
            hex:setFillColor( 0.3, 1.0, 1.0, 0.8)
        else
            hex:setFillColor( 0.3, 0.4, 1.0, 0.8)
        end
        hex:setStrokeColor( 0.8, 0.9, 1.0, 0.4)
        hex.strokeWidth = 2
        local text = display.newText(q..","..r, 0, 0, native.systemFont, hexView.hexSize/2)
        group:insert(hex)
        group:insert(text)
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
	
	print(hexView:toString())

	-- Setup a tap handler that toggles selected on/off
	local mTapHandler = {}
	function mTapHandler:onHexTap(q,r,x,y)
		print("Tap on: ", q, r)
		local selected = mSelected:get(q,r)
		if selected == nil then
			mSelected:set(q,r,true)
		else
			mSelected:erase(q,r)
		end
		hexView:setHex(q,r,getHex(q,r))
	end

	inputHandler:setInputHandler(mTapHandler)
	
    return proxy
end

--local view = display.newContainer(100, 100)
local view = display.newGroup()
view.height = 100
view.width = 100
view.anchorX = 0
view.anchorY = 0
view.anchorChildren = false
local game = Test:new(view, view.width, view.height)

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
--    game:resize(display.contentWidth, display.contentHeight)

	view.x = 200
	view.y = 150
    game:resize(display.contentWidth-400, display.contentHeight-300)

	local rect = display.newRect(200, 150, display.contentWidth-400, display.contentHeight-300)	
	rect:setFillColor( 0.3, 0.4, 1.0, 0)
	rect:setStrokeColor( 0.8, 0, 0, 0.4)
	rect.strokeWidth = 2
    rect.anchorX = 0
	rect.anchorY = 0
end

layout()

game:setScale(0.6)
game:center(0,0)

-- The resize event handler
local function onResize(event)
    print("Resize event!")
    layout()
end

-- Add the "resize" event listener
Runtime:addEventListener( "resize", onResize )

return Test

