print("Loading Test...")

local HexView = require("HexEngine.HexView")
local HexUtils = require("HexEngine.HexUtils")
local Map2D = require("HexEngine.Map2D")
local ScrollerInputHandler = require("HexEngine.ScrollerInputHandler")

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
    updateView = false,
}

function Test:new(isPointyTop, hexSize, group, width, height)
    local o = {}

    -- The hex view for the Test instance (created after the proxy is created)
    local hexView = nil 

    local mSelected = Map2D:new()
    
    local function getHex(q,r)
        local group = display.newGroup()
        local hex = HexUtils.createHexagon(isPointyTop, hexSize)
        if mSelected:get(q,r) == true then 
            hex:setFillColor( 0.3, 1.0, 1.0, 0.8)
        else
            hex:setFillColor( 0.3, 0.4, 1.0, 0.8)
        end
        hex:setStrokeColor( 0.8, 0.9, 1.0, 0.4)
        hex.strokeWidth = 2
        local text = display.newText(q..","..r, 0, 0, native.systemFont, hexSize/2)
        group:insert(hex)
        group:insert(text)
        return group
    end
    -- Returns a display object for hex at q,r 
    function o:onHexVisibility(q,r,visible)
        if visible == true then
            hexView:setHex(q,r,getHex(q,r))
        else
            hexView:removeHex(q,r)
        end
    end

    local mDragging = false
    local mTapping = false
    local mLastTapTimestamp = 0
    local mZoomedIn = true
    local mOldx = 0
    local mOldy = 0
    local mOffsetx = 0
    local mOffsety = 0
    
    function o:onHexTouchBegin(q,r,x,y)
        print("Touch begin at hex("..q..","..r..")" .. " cord("..x..","..y..")")
        mDragging = true
        mTapping = true
        mOldx = x
        mOldy = y
--        hexView:setHex(q,r,self:getHex(q,r))
    end

    function o:onHexTouchMove(q,r,x,y)
        if mDragging then

            if not (x >= (mOldx-1) and x <= (mOldx+1)) and (y >= (mOldy-1) and y <= (mOldy+1)) then
                mTapping = false
            end

            local dx = x-mOldx
            local dy = y-mOldy
            mOldx = x
            mOldy = y
            mOffsetx = mOffsetx + dx
            mOffsety = mOffsety + dy
--            print("Drag delta: "..dx..","..dy.." offset: "..mOffsetx..","..mOffsety.." at hex("..q..","..r..")" .. " cord("..x..","..y..")")
            hexView:setBoardOffset(mOffsetx,mOffsety)
            hexView:updateView()
        end
    --    hexView:setHex(q,r,self:getHex(q,r))
    end

    function o:onHexTouchEnd(q,r,x,y) 
        if mTapping then
            -- Tap made
            local doubleTapTime = system.getTimer() - mLastTapTimestamp
            if(doubleTapTime < 500) then
                -- Double tap made
                print("Double-tap at hex("..q..","..r..")" .. " cord("..x..","..y..")", mZoomedIn)
                if mZoomedIn then
                    mZoomedIn = false
                    self:setScale(0.5)
                    self:center(q,r)
                    self:updateView()
                else
                    mZoomedIn = true
                    self:setScale(1.0)
                    self:center(q,r)
                    self:updateView()
                end
            else    
                print("Tap at hex("..q..","..r..")" .. " cord("..x..","..y..")")
                -- Select tapped hex
                local selected = mSelected:get(q,r)
                if selected == nil then
                    mSelected:set(q,r,true)
                else
                    mSelected:erase(q,r)
                end
                hexView:setHex(q,r,getHex(q,r))
            end
            mLastTapTimestamp = system.getTimer()
        else
            print("Touch end at hex("..q..","..r..")" .. " cord("..x..","..y..")")
        end
        
        mTapping = true
        mDragging = false
    end

    function o:resize(w,h) 
        hexView:resize(w,h)
    end
    
    function o:center(q,r)
        mOffsetx, mOffsety = hexView:center(q,r)
    end

    function o:setScale(s)
        hexView:setScale(s)
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
        
    -- Create the HexView for this Test instance.
    hexView = HexView.createView(group, width, height, isPointyTop, hexSize, proxy)    
    hexView:setInputHandler(proxy)
    hexView:setVisibilityHandler(proxy)
    print(hexView:toString())
    return proxy
end

local bgRect1 = display.newRect(0,0,100,100)
bgRect1.anchorX = 0
bgRect1.anchorY = 0
bgRect1:setFillColor( 0.5 ,0,0)
local bgRect2 = display.newRect(1,1,100-2, 100-2)
bgRect2.anchorX = 0
bgRect2.anchorY = 0
bgRect2:setFillColor(0.5)

local view1 = display.newContainer(100, 100)
--local view1 = display.newGroup()
view1.height = 100
view1.width = 100
view1.anchorX = 0
view1.anchorY = 0
view1.anchorChildren = false
local test1 = Test:new(true, 50, view1, view1.width, view1.height)

local view2 = display.newContainer(100, 100)
view2.anchorChildren = false
view2.height = 100
view2.width = 100
view2.anchorX = 0
view2.anchorY = 0
local test2 = Test:new(false, 30, view2, view2.width, view2.height)

local function layout()
    print("content: ", display.contentWidth, display.contentHeight)
    print("pixel: ", display.pixelWidth, display.pixelHeight)
    print("actualContent: ", display.actualContentWidth, display.actualContentHeight)

    -- layout background
    bgRect1.width = display.contentWidth
    bgRect1.height = display.contentHeight

    bgRect2.width = display.contentWidth-2
    bgRect2.height = display.contentHeight-2
            
    if display.contentWidth > display.contentHeight then 
        view1.x = 10
        view1.y = 10 + 30
        view1.width = (display.contentWidth-30)/2
        view1.height = (display.contentHeight-20) -30
        test1:resize(view1.width, view1.height)
        
        view2.x = view1.width+20
        view2.y = 10 + 30
        view2.width = (display.contentWidth-30)/2
        view2.height = (display.contentHeight-20) -30
        test2:resize(view2.width, view2.height)
    else
        view1.x = 10
        view1.y = 10 + 30
        view1.height = (display.contentHeight-30)/2 -15
        view1.width = (display.contentWidth-20)
        test1:resize(view1.width, view1.height)

        view2.y = view1.height+20+30
        view2.x = 10
        view2.height = (display.contentHeight-30)/2 -15
        view2.width = (display.contentWidth-20)
        test2:resize(view2.width, view2.height)
    end
--[[
]]--
end

layout()

test1:setScale(1.0)
test1:center(0,0)

test2:setScale(1.0)
test2:center(0,0)

test1:updateView()
test2:updateView()

-- The resize event handler
local function onResize(event)
    print("Resize event!")
    layout()
end

-- Add the "resize" event listener
Runtime:addEventListener( "resize", onResize )

return Test

