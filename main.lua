
-- Enable multitouch
system.activate("multitouch")

-- Global Options
options = {} 
options.multitouchEmulation = false
options.debug = false

-- Sleep function for debugging purposes
function sleep(ms)
    local startTime = system.getTimer()
    local endTime = startTime + ms

    while true do 
        if system.getTimer() >= endTime then
            break
        end
    end
 end

-- Keyboard events (does not work on ios devices in emulator)
local function onKeyEvent( event )
--    print("Key '" .. event.keyName .. "' was pressed " .. event.phase)

    if event.keyName == "m" then 
        if event.phase == "down" then 
            options.multitouchEmulation = not options.multitouchEmulation 
            if options.multitouchEmulation == true then
                print("Multitouch emulation on.")
            else 
                print("Multitouch emulation off.")
            end
        end    
    elseif event.keyName == "d" then 
        if event.phase == "down" then 
            options.debug = not options.debug 
            if options.debug == true then
                print("Debug mode on.")
            else 
                print("Debug mode off.")
            end
        end    
    end
    return false
end
Runtime:addEventListener( "key", onKeyEvent )

--local PersistentStore = require("HexEngine.PersistentStore")
--local Map2D = require("HexEngine.Map2D")
--local Test = require("Test.Test")
--local Wasteland = require("Wasteland.Wasteland")
--local PlanetX = require("PlanetX.PlanetX")
--local FiveInARow = require("FiveInARow.FiveInARow")
local ThreeDTest = require("3DTest.3DTest")

local lastFrameTimestamp = system.getTimer()
local fpsText = nil
local fps = display.fps
local lastUpdateTimestamp = system.getTimer()
local minFps = display.fps

local function enterFrame(event)
    local current = system.getTimer()
    fps = 1000/(current - lastFrameTimestamp) * 0.3 + 0.7 * fps
    fps = math.floor(fps+0.5)
    local sinceLastUpdate = current - lastUpdateTimestamp
    lastFrameTimestamp = current
    if(fps < minFps) then minFps = fps end
    if(sinceLastUpdate >= 500) then
        lastUpdateTimestamp = current
        --print(fps, minFps)
        if fpsText then 
            fpsText:removeSelf()
        end
        fpsText = display.newText(""..minFps, 30, 20, native.systemFont, 20)
        minFps = math.floor(fps * 0.5 + minFps * 0.5 + 0.5)
    end
end

Runtime:addEventListener('enterFrame', enterFrame)


print("content: ", display.contentWidth, display.contentHeight)
print("pixel: ", display.pixelWidth, display.pixelHeight)
print("actualContent: ", display.actualContentWidth, display.actualContentHeight)

if display.actualContentWidth < display.actualContentHeight then
    print("Content scale: "..(display.pixelWidth/display.actualContentWidth))
else
    print("Content scale: "..(display.pixelWidth/display.actualContentHeight))
end

