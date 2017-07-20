print("Loading ScrollerInputHandler...")

local ScrollerInputHandler = {}

-- Declare globals to be used by this package
local print = print
local setmetatable = setmetatable
local error = error
local type = type
local system = system 
local options = options
local display = display
local pairs = pairs
local math = math
local native = native
local string = string

-- Forbid access of all other globals
local _P = {}
setmetatable(_P, {
    __index = function(t,k) error("Attempt to access global key " .. k, 2) end, 
    __newindex = function(t,k,v) error("attempt to set global key " .. k, 2) end })
setfenv(1,_P)

-- Expose public interface with controlled read and/or write access 
-- Key present and false means read only, true means read/write
local accessTable = {
    -- Callbacks from the view
    onHexVisibility = false,
    onHexTouchBegin = false,
    onHexTouchMove = false,
    onHexTouchEnd = false,

    -- setInputHandler(inputHandler) Sets the input handler. The handler can implement the following callbacks
    --     onHexTap(q,r,x,y) -- Called when a hex q,r is tapped. x,y is the content space coordinate of the tap
    setInputHandler = false,
}

function ScrollerInputHandler:new(hexView, minScale, maxScale)
    if type(hexView) ~= "table" then error("hexView is of invalid type " .. type(hexView), 2) end

    if minScale == nil then minScale = 0.3 end
    if maxScale == nil then maxScale = 1.5 end    
    local o = {}

    o.row = {}
 
    local hexView = hexView

    -- The set input handler that will be called on touch events
    local mInputHandler = nil
    
    local mLastTapTimestamp = 0
    local mZoomedIn = true
    local mTouchX = 0
    local mTouchY = 0
    local mOldTapX = 0
    local mOldTapY = 0
    
    local trackers = {}
    local trackersCount = 0
    local trackersMidPoint = {x=0,y=0}
    local oldTrackersMidPoint = {x=0,y=0}
    local trackersMidpointDebugMarker = nil
    local scaleDebugMarker = nil
    
    -- pinching
    local oldPinchDistance = 0
    local pinchID1 = 0
    local pinchID2 = 0
    
    local function trackerCountChange()
        print("Tracker count changed. Tracker count: "..trackersCount)
        if trackersCount == 0 then 
            if trackersMidpointDebugMarker ~= nil then 
                trackersMidpointDebugMarker:removeSelf()
                trackersMidpointDebugMarker = nil
                trackersMidPoint.x = 0; trackersMidPoint.y = 0
            end
            return 
        end

        local sumX = 0
        local sumY = 0
        for key,value in pairs(trackers) do 
            sumX = sumX + value.x
            sumY = sumY + value.y
        end
        trackersMidPoint.x = sumX/trackersCount
        trackersMidPoint.y = sumY/trackersCount
        oldTrackersMidPoint.x = trackersMidPoint.x
        oldTrackersMidPoint.y = trackersMidPoint.y

        -- Update pinch trackers if tracker count is 2
        if trackersCount == 2 then
            local i = 1
            for key,value in pairs(trackers) do 
                if i == 1 then pinchID1 = key
                elseif i == 2 then pinchID2 = key
                end
                i = i + 1
            end
        end
        
        -- Create or update position of trackers midpoint debug marker
        if (trackersMidpointDebugMarker == nil) and (trackersCount > 0) and options.debug then
            trackersMidpointDebugMarker = display.newCircle(trackersMidPoint.x, trackersMidPoint.y, 15)
            trackersMidpointDebugMarker:setFillColor( 1.0, 0.3, 0.3, 0.5)
        elseif trackersMidpointDebugMarker ~= nil then
            trackersMidpointDebugMarker.x = trackersMidPoint.x
            trackersMidpointDebugMarker.y = trackersMidPoint.y
        end 
        
        -- Create or update position of scale debug marker
        if (scaleDebugMarker == nil) and (trackersCount == 2) and options.debug then
            local scale = hexView:getScale()
            print("scale: "..scale)
            scaleDebugMarker = display.newText(scale, trackersMidPoint.x, trackersMidPoint.y, native.systemFont, 22)
            scaleDebugMarker:setFillColor( 1, 1, 1, 0.5)
        elseif scaleDebugMarker ~= nil then
            scaleDebugMarker.x = trackersMidPoint.x
            scaleDebugMarker.y = trackersMidPoint.y
        end
        
        -- Remove scale debug marker if trackers count is below 2
        if (scaleDebugMarker ~= nil) and (trackersCount < 2) then
            scaleDebugMarker:removeSelf()
            scaleDebugMarker = nil
        end

    end

    local function updateTrackerMidpoint()
       --print("Tracker moved. Tracker count: "..trackersCount) 

        local sumX = 0
        local sumY = 0
        for key,value in pairs(trackers) do 
            sumX = sumX + value.x
            sumY = sumY + value.y
            --print(sumX, sumY)
        end
        trackersMidPoint.x = sumX/trackersCount
        trackersMidPoint.y = sumY/trackersCount

        if (trackersMidpointDebugMarker ~= nil) then
            trackersMidpointDebugMarker.x = trackersMidPoint.x
            trackersMidpointDebugMarker.y = trackersMidPoint.y
        end

        if (scaleDebugMarker ~= nil) then
            scaleDebugMarker.x = trackersMidPoint.x
            scaleDebugMarker.y = trackersMidPoint.y
        end
        
    end
    
    function o:onHexTouchBegin(q,r,x,y,id)
        
        -- check if this is a new id in which case a tracker should be added. 
        -- (can happen when simulating multiview in the emulator)
        local tracker = trackers[id]
        if tracker == nil then 
            trackers[id] = {x=x,y=y}
            trackersCount = trackersCount + 1
            trackerCountChange()
        end
        
        print("Touch begin at hex("..q..","..r..")" .. " cord("..x..","..y..")".." id "..id)

        -- pinching
        if trackersCount == 2 then
            local p1 = trackers[pinchID1]
            local p2 = trackers[pinchID2]
            local v = {x=(p2.x-p1.x), y=(p2.y-p1.y)}
            oldPinchDistance = math.abs(math.sqrt(v.x*v.x + v.y*v.y))
            print("oldPinchDistance "..oldPinchDistance)
        end
        
        mTouchX = x
        mTouchY = y
    end

    function o:onHexTouchMove(q,r,x,y,id)

        -- Update the tracker and calculate the new midpoint
        local tracker = trackers[id]
        if tracker == nil then 
            print("Ignoring hexTouchMove call for id "..id..". No active tracker.")
            return
        end
        tracker.x = x
        tracker.y = y
        updateTrackerMidpoint()

        -- Calculate the delta for the tracker midpoint and update the old mid point
        local midDx = trackersMidPoint.x - oldTrackersMidPoint.x
        local midDy = trackersMidPoint.y - oldTrackersMidPoint.y
        oldTrackersMidPoint.x = trackersMidPoint.x
        oldTrackersMidPoint.y = trackersMidPoint.y

        -- update pinch
        if trackersCount == 2 then 
            local p1 = trackers[pinchID1]
            local p2 = trackers[pinchID2]
            local v = {x=(p2.x-p1.x), y=(p2.y-p1.y)}
            local pinchDelta = oldPinchDistance
            oldPinchDistance = math.abs(math.sqrt(v.x*v.x + v.y*v.y))
            pinchDelta = oldPinchDistance - pinchDelta;
--            print("oldPinchDistance "..oldPinchDistance.." delta: "..pinchDelta)

            local scale = hexView:getScale()
            scale = scale + pinchDelta/400
            if scale < minScale then scale = minScale elseif scale > maxScale then scale = maxScale end
            hexView:setScale(scale,trackersMidPoint.x,trackersMidPoint.y)
            
            -- update debug scale marker
            if scaleDebugMarker ~= nil then 
                scaleDebugMarker:removeSelf()
                scaleDebugMarker = display.newText(string.format("%.2f",scale), oldTrackersMidPoint.x, oldTrackersMidPoint.y, native.systemFont, 22)
                scaleDebugMarker:setFillColor( 1, 1, 1, 0.5)
            end
        end
        
        local offsetX, offsetY = hexView:getBoardOffset()
        offsetX = offsetX + midDx
        offsetY = offsetY + midDy
--      print("Drag delta: "..dx..","..dy.." offset: "..mOffsetx..","..mOffsety.." at hex("..q..","..r..")" .. " cord("..x..","..y..")")
        hexView:setBoardOffset(offsetX,offsetY)
        hexView:updateView()
    end

    function o:onHexTouchEnd(q,r,x,y,id) 

        local tracker = trackers[id]
        if tracker == nil then 
            print("Ignoring hexTouchEnd call for id "..id..". No active tracker.")
            return
        end
   
        trackers[id] = nil
        trackersCount = trackersCount - 1
        trackerCountChange()
    
        local tapped = false
        if (x >= (mTouchX-5) and x <= (mTouchX+5)) and (y >= (mTouchY-5) and y <= (mTouchY+5)) then
            tapped = true
        end

        -- Tap made
        if tapped then
            local doubleTapTime = system.getTimer() - mLastTapTimestamp
            if(doubleTapTime < 500) and (x >= (mOldTapX-10) and x <= (mOldTapX+10)) and (y >= (mOldTapY-10) and y <= (mOldTapY+10)) then
                -- Double tap made
                print("Double-tap at hex("..q..","..r..")" .. " cord("..x..","..y..")", mZoomedIn)
                if mZoomedIn then
                    mZoomedIn = false
                    hexView:setScale(0.5,x,y)
                    hexView:updateView()
                else
                    mZoomedIn = true
                    hexView:setScale(1.0,x,y)
                    hexView:updateView()
                end
            else    
                print("Tap at hex("..q..","..r..")" .. " cord("..x..","..y..")".." id "..id)
                if mInputHandler ~= nil and mInputHandler.onHexTap ~= nil then
                    mInputHandler:onHexTap(q,r,x,y)
                end
                mOldTapX = x
                mOldTapY = y
            end
            mLastTapTimestamp = system.getTimer()
        end    
    end

    function o:setInputHandler(ih)
        if ih == nil then mInputHandler = nil end
        if type(ih) ~= "table" then error("inputHandler is of invalid type " .. type(ih), 2) end
        mInputHandler = ih
    end
    
    -- Return proxy that enforce access only to public members and methods
    local proxy = {}
    setmetatable(proxy, {
        __index = function(t,k) 
            if accessTable[k] ~= nil
                then return o[k]
            else
                error("Attempt to access key " .. k .. " in instance of type " .. "ScrollerInputHandler", 2)
            end
        end, 
        __newindex = function(t,k,v) 
            if accessTable[k] == true
                then return o[k]
            else
                error("Attempt to set key " .. k .. "=" .. v .. " in instance of type " .. "ScrollerInputHandler", 2)
            end
        end })
    return proxy
end

return ScrollerInputHandler

