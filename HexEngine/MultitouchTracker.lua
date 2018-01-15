print("Loading MultitouchTracker...")

local MultitouchTracker = {}

-- Activate multitouch
system.activate( "multitouch" )

-- Declare globals to be used by this package
local print = print
local setmetatable = setmetatable
local error = error
local type = type
local display = display
local options = options
local tostring = tostring

-- Forbid access of all other globals
local _P = {}
setmetatable(_P, {
    __index = function(t,k) error("Attempt to access global key " .. k, 2) end, 
    __newindex = function(t,k,v) error("attempt to set global key " .. k, 2) end })
setfenv(1,_P)

-- Expose public interface with controlled read and/or write access 
-- Key present and false means read only, true means read/write
local accessTable = {
}

-- Creates a new multitouch tracker with multitouch emulation support that works in the simulator. 
-- Set it as a touch event table handler:
--
--     dispObj:addEventListener("touch", tracker)
--
-- The tracker will call MultitouchTracker.multitouch which is either a function with the signature
--
--     eventFunc(event, touchId) 
--
-- or a table with a multitouch method with that signature.
function MultitouchTracker:new()
    local o = {}

    -- The id of the next tracker
    local nextTrackerId = 1

    -- Creates a tracker circle
    local function newTracker(event)
        local circle = display.newCircle(event.x, event.y, 30)
        if options ~= nil and (options.debug == true or options.multitouchEmulation) then
            circle:setFillColor( 1.0, 1.0, 1.0, 0.5)
        else
            circle:setFillColor( 1.0, 1.0, 1.0, 0.0)
        end    
        
        local id = nextTrackerId
        nextTrackerId = nextTrackerId + 1
        
        -- Convert coordinates to board coordinates (0,0 in upper left corner) and account for scaling
--        local boardX, boardY = o:contentToBoard(event.x, event.y)
        
--        local q,r = o:boardToTile(boardX, boardY)
        
        local function propagateEvent(event, id)
            if o.multitouch ~= nil then 
                if type(o.multitouch) == "table" and type(o.multitouch.multitouch) == "function" then
                    o.multitouch:multitouch(event, id)
                elseif type(o.multitouch) == "function" then
                    o.multitouch(event, id)
                end 
            end
        end
        
        function circle:touch(event)
                    
            if ( event.phase == "began" ) then
                display.getCurrentStage():setFocus(self, event.id)
                print("touch begin "..event.x..","..event.y.." id: "..id, "event.id: " .. tostring(event.id))
                propagateEvent(event, id)
            elseif ( event.phase == "moved") then
                --print("touch move "..event.x..","..event.y.." id: "..id)
                circle.x = event.x
                circle.y = event.y
                propagateEvent(event, id)
            elseif ( event.phase == "ended" or event.phase == "cancelled" ) then
                print("touch ended at "..event.x..","..event.y.." id: "..id)
                display.getCurrentStage():setFocus(self,  nil )

                if options.isDevice or not options.multitouchEmulation then
                    circle:removeSelf(event.id)
                    propagateEvent(event, id)
                end    
            end
            return true

        end

        function circle:tap(event)
            if event.numTaps == 2 then
                self:removeSelf()
                propagateEvent(event, id)
            end
        end
        
        if not options.isDevice then 
            circle:addEventListener("tap")
        end
            
        circle:addEventListener("touch")
        circle:touch(event)
    end

    function o:touch(event)
        if ( event.phase == "began" ) then
            newTracker(event)
            print("created tracker object at "..event.x..","..event.y.." id: ".. tostring(event.id))
            return true
        end 
        return true
    end
    
    return o
end

return MultitouchTracker

