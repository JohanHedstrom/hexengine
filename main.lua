
-- Enable multitouch
system.activate("multitouch")

-- Global Options
options = {} 
options.multitouchEmulation = false
options.isDevice = system.getInfo("environment") == "device"
options.debug = false

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

print("content: ", display.contentWidth, display.contentHeight)
print("pixel: ", display.pixelWidth, display.pixelHeight)
print("actualContent: ", display.actualContentWidth, display.actualContentHeight)

if display.actualContentWidth < display.actualContentHeight then
    print("Content scale: "..(display.pixelWidth/display.actualContentWidth))
else
    print("Content scale: "..(display.pixelWidth/display.actualContentHeight))
end