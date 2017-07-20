print("Loading HexView...")

local Map2D = require("HexEngine.Map2D")
local HexUtils = require("HexEngine.HexUtils")

local HexView = {}

-- Declare globals to be used by this package
local print = print
local math = math
local setmetatable = setmetatable
local type = type
local error = error
local display = display
local isDevice = isDevice
local options = options
local tostring = tostring

-- Forbid access of all other globals
local _P = {}
setmetatable(_P, {
    __index = function(t,k) error("Attempt to access global key " .. k, 2) end, 
    __newindex = function(t,k,v) error("attempt to set global key " .. k, 2) end })
setfenv(1,_P)

-- Expose public interface with controlled read and/or write access for HexView instances
-- Key present and false means read only, true means read/write
local accessTable = {
    -- Boolean. True if the hexagons are pointy topped, false if it is flat topped
    hexIsPointyTop = false,
    -- The hexagon size in pixels from center to corner. Pixel assets needs to use this size.
    hexSize = false,
    -- The height of the hexagons, dependent on the size and orientation (pointy or flat topped)
    hexHeight = false,
    -- The width of the hexagons dependent on the size and orientatoin (pointy or flat topped)
    hexWidth = false,
    -- The horizontal distance between two adjacent hex centers.
    hexHorDist = false,
    -- The vertical distance between two adjacent hex centers.
    hexVertDist = false,
    -- The game object
    game = false,
    -- Returns a string representation of the HexView instance for debugging purposes
    toString = false,
    -- 	s the hex view.
    updateView = false,
    -- setHex(q,r,hex) Adds the display object for hex q,r to the board.
    setHex = false,
    -- removeHex(q,r) Removes the display object for hex q,r from the board.
    removeHex = false,
    -- setBoardOffset(x,y) Sets the offset of the board (i.e. board.x and board.y)
    setBoardOffset = false,
    -- getBoardOffset() Returns offsetX,offsetY
    getBoardOffset = false,
    -- setScale(scale, x,y) Sets the scale of the board. Scaling will be done around x,y (in content space). Everything placed on the board will have this scale applied to it. 
    setScale = false,
    -- getScale() Returns the scale of the board. 
    getScale = false,    
    -- resize(width, height) Resize the view. Note that any clipping the application applies, for instance by using a container, must also be updated by the application.
    resize = false,
    -- center(q,r) Places the hex q,r in the center of the view. Returns new xOffset,yOffset. 
    center = false,
    -- setInputHandler(inputHandler) Sets the input handler. The handler can implement the following callbacks
    --     onHexTouchBegin(q,r,x,y,id) -- Called on first touch.
    --     onHexTouchMove(q,r,x,y,id)  -- Called on touch move.
    --     onHexTouchEnd(q,r,x,y,id)   -- Called when finger is lifted.
    --       q,r The coordinate of the hex
    --       x,y The coordinate in content space
    --       id The id of the multitouch event
    setInputHandler = false,
    -- setVisibilityHandler(inputHandler) Sets the visibility handler. The handler can implement the following callbacks
    --     onHexVisibility(q,r,visible) -- Called with visible = true when hex q,r becomes visible 
    --                                     in the view. When a hex is not visible anymore it is 
    --                                     called again with visible = false
    setVisibilityHandler = false,
}

local THIRTY_DEGGREES_RAD = math.pi/180*30

-- Creates a HexView instance
-- group The display group where the view should display all the hexes
-- width The width of the group that the view may use. The view can still 
--       place hexes outside the 0-x range but they will be considered not visible.
-- height The height of the group that the view may use. The view can still 
--       place hexes outside the 0-y range but they will be considered not visible.
-- isPointyTop true for pointy top, false for flat top
-- hexSize The size to use for the hexagons, center to corner
local function createView(group, width, height, isPointyTop, hexSize)
    local o = {}

    -- value checking
    if type(group) ~= "table" then error("createView: group is of invalid type " .. type(group), 2) end 
    if type(width) ~= "number" then error("createView: width is of invalid type " .. type(width), 2) end 
    if type(height) ~= "number" then error("createView: height is of invalid type " .. type(height), 2) end 
    if type(isPointyTop) ~= "boolean" then error("createView: isPointyTop is of invalid type " .. type(isPointyTop), 2) end 
    if type(hexSize) ~= "number" or hexSize < 0 then error("Attempt to set HexView:hexhexSize to invalid value " .. hexSize, 2) end 

    ---------- public members ----------

    o.hexIsPointyTop = isPointyTop
    o.hexSize = hexSize;
    
    if isPointyTop then
        o.hexHeight = o.hexSize * 2 
        o.hexWidth = math.sqrt(3)/2 * o.hexHeight
        o.hexHorDist = o.hexWidth
        o.hexVertDist = o.hexHeight * 3/4
    else
        o.hexWidth = o.hexSize * 2
        o.hexHeight = math.sqrt(3)/2 * o.hexWidth  
        o.hexHorDist = o.hexWidth * 3/4
        o.hexVertDist = o.hexHeight
    end

    ---------- private members ----------
    
    -- The set input handler that will be called on board touch events
    local inputHandler = nil

    -- The visibility handler that will be called when hexes are visible/not visible any more in the view
    local visibilityHandler = nil
    
    -- The group assigned for the hex view by the application
    local mViewGroup = group    
    -- The width of the viewGroup that is considered visible (up to applicaiton to clip anything outside)
    local mViewWidth = width
    -- The height of the viewGroup that is considered visible (up to applicaiton to clip anything outside)
    local mViewHeight = height
    
    -- The group where the game hexes will be displayed. Hexes will be placed on the 
    -- board group depending on their hex coordinates with (0,0,0) cetered around the 
    -- group coordinate 0,0
    local mBoard = display.newGroup()
    
    -- The scale of the board
    local mScale = 1.0
    
    -- The hexes (display objects created by the game) that are currently placed on the board mapped to q,r
    local mHexes = Map2D:new()
    
    -- The subset of hexes that are currently visible (i.e. within the view area) mapped to 
    -- the value true.
    -- Note that a hex is present in this map doesn't mean that it is also in mHexes, the 
    -- game might not have created a hex in response to the visibility event.
    local mVisibleHexes = Map2D:new()
    
    -- The plate used to catch touch events
    local mTouchPlate = display.newRect(mViewGroup,0,0,width,height)
    mTouchPlate.anchorX = 0; mTouchPlate.anchorY = 0;
    mTouchPlate:setFillColor( 0.0, 0.0, 0.0,1.0)
    
    local function pixelToHex(x,y)
        return HexUtils.pixelToHex(x,y,isPointyTop,hexSize)
    end
    
    local function hexToPixel(q,r)
        return HexUtils.hexToPixel(q,r,isPointyTop,hexSize)
    end
    
    local function createHexagon()
        return HexUtils.createHexagon(isPointyTop, hexSize)
    end

    local function contentToBoard(x,y)
        local boardX, boardY = mTouchPlate:contentToLocal(x,y)
        boardX = (math.floor(boardX + mViewWidth/2 + 0.5) - mBoard.x)/mScale;
        boardY = (math.floor(boardY + mViewHeight/2 + 0.5) - mBoard.y)/mScale;
        return boardX, boardY
    end
    
    -- The id of the next tracker
    local nextTrackerId = 1
        
    -- Creates a multitouch tracker
    local function newTracker(event)
        local circle = display.newCircle(event.x, event.y, 30)
        if options.debug == true or options.multitouchEmulation then
            circle:setFillColor( 1.0, 1.0, 1.0, 0.5)
        else
            circle:setFillColor( 1.0, 1.0, 1.0, 0.0)
        end    
        
        local id = nextTrackerId
        nextTrackerId = nextTrackerId + 1
        
        -- Convert coordinates to board coordinates (0,0 in upper left corner) and account for scaling
        local boardX, boardY = contentToBoard(event.x, event.y)
        
        local q,r = pixelToHex(boardX, boardY)
        
        function circle:touch(event)
            if ( event.phase == "began" ) then
                display.getCurrentStage():setFocus(self, event.id)
                print("touch begin "..event.x..","..event.y.." id: "..id)
                if(inputHandler ~= nil and inputHandler.onHexTouchBegin ~= nil) then 
                    inputHandler:onHexTouchBegin(q,r, event.x, event.y, id)
                end
            elseif ( event.phase == "moved") then
                --print("touch move "..event.x..","..event.y.." id: "..id)
                circle.x = event.x
                circle.y = event.y
                if(inputHandler ~= nil and inputHandler.onHexTouchMove ~= nil) then 
                    inputHandler:onHexTouchMove(q,r, event.x, event.y, id)
                end
            elseif ( event.phase == "ended" or event.phase == "cancelled" ) then
                print("touch ended at "..event.x..","..event.y.." id: "..id)
                display.getCurrentStage():setFocus(self,  nil )

                if options.isDevice or not options.multitouchEmulation then
                    circle:removeSelf(event.id)
                    if(inputHandler ~= nil and inputHandler.onHexTouchEnd ~= nil) then 
                        inputHandler:onHexTouchEnd(q,r, event.x, event.y, id)
                    end
                end    
            end
            return true
        end

        function circle:tap(event)
            if event.numTaps == 2 then
                self:removeSelf()
                if(inputHandler ~= nil and inputHandler.onHexTouchEnd ~= nil) then 
                    inputHandler:onHexTouchEnd(q,r, event.x, event.y,id)
                end
            end
        end
        
        if not options.isDevice then 
            circle:addEventListener("tap")
        end
            
        circle:addEventListener("touch")
        circle:touch(event)
    end

    local function onPlateTouch(event)
        if ( event.phase == "began" ) then
            newTracker(event)
            print("created tracker object at "..event.x..","..event.y.." id: ".. tostring(event.id))
            return true
        end 
    end    
    
--[[    
    local function onPlateTouch(event)
        -- Convert coordinates to board coordinates (0,0 in upper left corner) and account for scaling
        local boardX, boardY = event.target:contentToLocal(event.x, event.y)
        boardX = (math.floor(boardX + mViewWidth/2 + 0.5) - mBoard.x)/mScale;
        boardY = (math.floor(boardY + mViewHeight/2 + 0.5) - mBoard.y)/mScale;
        
        local q,r = pixelToHex(boardX, boardY)
    
        if ( event.phase == "began" ) then
            display.getCurrentStage():setFocus( event.target )
--            print("touch begin "..boardX..","..boardY)
            if(inputHandler ~= nil and inputHandler.onHexTouchBegin ~= nil) then 
                inputHandler:onHexTouchBegin(q,r, event.x, event.y)
            end
        elseif ( event.phase == "moved") then
--            print("touch move "..boardX..","..boardY)
            if(inputHandler ~= nil and inputHandler.onHexTouchMove ~= nil) then 
                inputHandler:onHexTouchMove(q,r, event.x, event.y)
            end
        elseif ( event.phase == "ended" or event.phase == "cancelled" ) then
--            print("touch ended at "..boardX..","..boardY)
            display.getCurrentStage():setFocus( nil )
            if(inputHandler ~= nil and inputHandler.onHexTouchEnd ~= nil) then 
                inputHandler:onHexTouchEnd(q,r, event.x, event.y)
            end
        end
        return true
    end
]]--
    mTouchPlate:addEventListener("touch", onPlateTouch)
    
    mViewGroup:insert(mBoard)
    
    ---------- public methods ----------
    
    function o:toString()
        return "HexView(type: " .. ((self.hexIsPointyTop and "pointy topped") or "flat topped")  .. " size: " .. self.hexSize .. " height: " .. self.hexHeight .. " width: " .. self.hexWidth .. " horDist: " .. self.hexHorDist .. " vertDist: " .. self.hexVertDist .. ")";
    end
    
    local mLastTopLeftQ = -1000.5
    local mLastTopLeftR = -1000.5
    
    function o:updateView()
        -- top left hex
--        local lastQ = mLastTopLeftQ
--        local lastR = mLastTopLeftR
--        mLastTopLeftQ = q
--        mLastTopLeftR = r
            
        -- Check if new visibility calculations have to be done
--        if q == lastQ and r == lastR then return end

--        print("updateView() Update required")
        
        -- Account for the part of the board that fits in the view after scaling
        local width = mViewWidth/mScale;
        local height = mViewHeight/mScale
        
        -- Any hexes in this table were visible before the update but no longer
        local previouslyVisible = mVisibleHexes
        
        -- The new updated map of visible hexes
        mVisibleHexes = Map2D:new()        

		-- The pointy top layout case
		if self.hexIsPointyTop == true then
			-- The hex at the top left of the visible area 
			local q,r = pixelToHex((0-mBoard.x)/mScale,(0-mBoard.y)/mScale)
		
			-- The number of columns and rows to process
			local numCols = math.floor(width/self.hexHorDist+0.5)
			if numCols*self.hexHorDist < width then numCols = numCols+1 end
			
			local numRows = math.floor(height/self.hexVertDist+0.5)
			if numRows*self.hexVertDist < height then numRows = numRows+1 end
		
			r = r - 1
			numCols = numCols + 2
			numRows = numRows + 3
			
			for qv,rv in HexUtils.verticals(q,r,self.hexIsPointyTop,numRows) do
				for qh,rh in HexUtils.horizontals(qv,rv,self.hexIsPointyTop, numCols) do

					-- Add it to the new set of visible hexes
					mVisibleHexes:set(qh,rh,true)

					-- If it was not visible before then this is a newly visible hex
					if previouslyVisible:erase(qh,rh) ~= true then
						if visibilityHandler ~= nil and visibilityHandler.onHexVisibility ~= nil then 
							visibilityHandler:onHexVisibility(qh,rh,true)
						end
					end
					
					-- Enforce correct z order for all visible hexes (right overlaps left and bottom overlaps top)
					local hex = mHexes:get(qh,rh)
					if hex ~= nil then mBoard:insert(hex) end
	--[[
					local x,y = hexToPixel(qh,rh)
					 
					local rect = display.newRect(mBoard,x,y,self.hexWidth,self.hexHeight)
					rect:setFillColor( 1.0, 1.0, 1.0, 0.5)
					rect:setStrokeColor( 0, 0, 0, 0.5)
					rect.strokeWidth = 1
	]]--        
				end
			end
		else -- The flat topped layout case	
			
			-- The hex at the top right of the visible area
			local topRightX = (0-mBoard.x+mViewWidth)/mScale
			local topRightY = (0-mBoard.y)/mScale
			local bottomLeftX = (0-mBoard.x)/mScale
			local bottomLeftY = (0-mBoard.y+mViewHeight)/mScale
			local qStart,rStart = pixelToHex(topRightX,topRightY)

			local q = qStart
			local r = rStart
			
			local numRows = math.floor((width/self.hexHorDist)+1+0.5)
			local numCols = 3
			local row = 0
			local col = 0
			local contCol = true
			local contRow = true
			local firstVisibleColumnTopY = 0
			local firstVisibleColumnDetected = false
			while contRow do
				r = rStart + row
				--for col=0,numCols-1,1 do
				while contCol do
					q = qStart + col - row*2 - 1
					
					-- check if the hex is outside to the left, in which case it should not be 
					-- added to the visible hexes
					local qx,qy = hexToPixel(q,r)
					local rightEdgeX = qx + self.hexWidth/2
					if rightEdgeX < bottomLeftX then else
						-- Note the top y for the first visible column hex
						if firstVisibleColumnDetected == false then
							firstVisibleColumnDetected = true
							firstVisibleColumnTopY = qy - self.hexWidth/2
						end
						
						-- Add it to the new set of visible hexes
						mVisibleHexes:set(q,r,true)
					
						-- If it was not visible before then this is a newly visible hex
						if previouslyVisible:erase(q,r) ~= true then
							if visibilityHandler ~= nil and visibilityHandler.onHexVisibility ~= nil then 
								visibilityHandler:onHexVisibility(q,r,true)
							end
						end
						
						-- Enforce correct z order for all visible hexes
						local hex = mHexes:get(q,r)
						if hex ~= nil then mBoard:insert(hex) end
											
						-- Check if leftmost corner is outside the view or if the top is below the view in 
						-- which case the column is outside the board and should stop
						local leftEdgeX = qx - self.hexWidth/2
						local topEdgeY = qy - self.hexWidth/2
						if leftEdgeX > topRightX or topEdgeY > bottomLeftY then contCol = false end
					end
					col = col + 1
				end	
				row = row + 1
				if firstVisibleColumnDetected == false then contRow = false end
				if firstVisibleColumnTopY > bottomLeftY then contRow = false end
				col = 0
				contCol = true
				firstVisibleColumnDetected = false
			end
 --[[			
			for qv,rv in HexUtils.rowHexes(q,r,3) do
				for qh,rh in HexUtils.colHexes(qv,rv,2) do

					-- Add it to the new set of visible hexes
					mVisibleHexes:set(qh,rh,true)

					-- If it was not visible before then this is a newly visible hex
					if previouslyVisible:erase(qh,rh) ~= true then
						if visibilityHandler ~= nil and visibilityHandler.onHexVisibility ~= nil then 
							visibilityHandler:onHexVisibility(qh,rh,true)
						end
					end
					
					-- Enforce correct z order for all visible hexes (right overlaps left and bottom overlaps top)
					local hex = mHexes:get(qh,rh)
					if hex ~= nil then mBoard:insert(hex) end
				end
				i = i + 1
			end
]]-- 			
			-- Any hexes left in previouslyVisible are no longer visible
			if previouslyVisible.size > 0 then print(""..previouslyVisible.size.." hexes no longer visible.") end
			for q,r in previouslyVisible:iterator() do
				if visibilityHandler ~= nil and visibilityHandler.onHexVisibility ~= nil then 
					visibilityHandler:onHexVisibility(q,r,false)
				end
			end
        end
 --[[       for qn,rn in HexUtils.neighbors(0,0) do
            local hexn = self.game:getHex(qn,rn)
            self:setHex(qn,rn,hexn)
        end
]]--        
--[[        
        local r; local q;
        for r=0,20,1 do
            for q=0,20,1 do
                local hex = self.game:getHex(q,r)
                local x,y = hexToPixel(q,r)
                hex.x = x; hex.y = y
                if hex ~= nil then mBoard:insert(hex) end
            end
        end]]--
    end    

    function o:removeHex(q,r)
        if type(q) ~= "number" then error("q is of invalid type " .. type(q), 2) end 
        if type(r) ~= "number" then error("r is of invalid type " .. type(r), 2) end 

        local hex = mHexes:erase(q,r)
        if hex ~= nil then 
            hex:removeSelf()
--            print("Removed hex "..q..","..r)
        else print("Failed to remove hex "..q..","..r) end
    end
    
    function o:setHex(q,r,hex)
        if type(q) ~= "number" then error("q is of invalid type " .. type(q), 2) end 
        if type(r) ~= "number" then error("r is of invalid type " .. type(r), 2) end 
        if type(hex) ~= "table" then error("hex is of invalid type " .. type(hex), 2) end

        -- Insert hex into board group
        local x,y = hexToPixel(q,r)
--        print("Set hex at "..q..","..r.." board " .. x ..",".. y)
        hex.x = x; hex.y = y
        mBoard:insert(hex)
        
        -- insert hex into hexes
        local prev = mHexes:get(q,r)
        if prev ~= nil then 
            self:removeHex(q,r) 
            print("Removed overwritten hex at "..q..","..r.." board " .. x ..",".. y)
        end
        mHexes:set(q,r,hex)
    end
    
    function o:setBoardOffset(x,y)
        if type(x) ~= "number" then error("x is of invalid type " .. type(x), 2) end 
        if type(y) ~= "number" then error("y is of invalid type " .. type(y), 2) end 
        mBoard.x = x
        mBoard.y = y
    end

    function o:getBoardOffset()
        return mBoard.x, mBoard.y
    end
    
    function o:setScale(scale, x, y)
        if type(scale) ~= "number" then error("scale is of invalid type " .. type(scale), 2) end 
        if type(x) ~= "number" then error("x is of invalid type " .. type(x), 2) end 
        if type(y) ~= "number" then error("y is of invalid type " .. type(y), 2) end 

        -- The offset of x,y from the center of the touch plate (origin in center)
        local centerOffsetX, centerOffsetY = mTouchPlate:contentToLocal(x,y);
        
        -- The board coordinate directly under x,y
        local bx, by = mBoard:contentToLocal(x,y)

--        if mScale == 0.5 then mScale = 1.0 else mScale = 0.5 end
        mBoard.xScale = scale
        mBoard.yScale = scale
        mScale = scale

--        print("board coordinates", bx, by)
--        display.newCircle(mBoard,bx,by,30)
        
--        bx = (bx - mBoard.x + (mViewWidth)/2)/mScale
--        by = (by - mBoard.y + mViewHeight/2)/mScale

        -- Calculate the board offset in unscaled coordinates that places the board coordinate bx,by under x,y after scaling
        local offsetX = mViewWidth/2 + centerOffsetX - bx*mScale
        local offsetY = mViewHeight/2 + centerOffsetY - by*mScale
        self:setBoardOffset(offsetX,offsetY)

    end
    
    function o:getScale()
        return mScale
    end

    function o:resize(width, height)
        if type(width) ~= "number" then error("width is of invalid type " .. type(width), 2) end 
        if type(height) ~= "number" then error("height is of invalid type " .. type(height), 2) end 
        mTouchPlate.width = width
        mTouchPlate.height = height
        mViewWidth = width
        mViewHeight = height
        print("Resized HexView to "..mViewWidth.."x"..mViewHeight)
    end
    
    function o:center(q, r)
        if type(q) ~= "number" then error("q is of invalid type " .. type(q), 2) end 
        if type(r) ~= "number" then error("r is of invalid type " .. type(r), 2) end 

        local x,y = hexToPixel(q,r)
        
        local offsetX = mViewWidth/2 - x*mScale
        local offsetY = mViewHeight/2 - y*mScale
        
        print("center", q,r, x,y, mScale)
        self:setBoardOffset(offsetX,offsetY)
        return offsetX, offsetY
    end
    
    function o:setInputHandler(ih)
        if ih == nil then inputHandler = nil end
        if type(ih) ~= "table" then error("inputHandler is of invalid type " .. type(ih), 2) end
        inputHandler = ih
    end

    function o:setVisibilityHandler(bh)
        if bh == nil then visibilityHandler = nil end
        if type(bh) ~= "table" then error("visibilityHandler is of invalid type " .. type(bh), 2) end
        visibilityHandler = bh
    end
    
    -- private methods
        
    -- Return proxy that enforce access only to public members and methods
    local proxy = {}
    setmetatable(proxy, {
        __index = function(t,k) 
            if accessTable[k] ~= nil
                then return o[k]
            else
                error("Attempt to access key " .. k .. " in instance of type " .. "HexView", 2)
            end
        end, 
        __newindex = function(t,k,v) 
            if accessTable[k] == true
                then return o[k]
            else
                error("Attempt to set key " .. k .. "=" .. v .. " in instance of type " .. "HexView", 2)
            end
        end })
    return proxy
end

-- Return the proxy for the HexView name space that conrols access to supported interface
local proxy = {createView = createView}
setmetatable(proxy, {
    __index = function(t,k) error("attempt to access unsupported key", 2) end, 
    __newindex = function(t,k,v) error("attempt to access unsupported key", 2) end })
return proxy
