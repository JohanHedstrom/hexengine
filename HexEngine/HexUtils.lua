print("Loading HexUtils...")

local HexUtils = {}

-- Declare globals to be used by this package
local print = print
local math = math
local setmetatable = setmetatable
local type = type
local error = error
local display = display

-- Forbid access of all other globals
local _P = {}
setmetatable(_P, {
    __index = function(t,k) error("Attempt to access global key " .. k, 2) end, 
    __newindex = function(t,k,v) error("attempt to set global key " .. k, 2) end })
setfenv(1,_P)

local THIRTY_DEGGREES_RAD = math.pi/180*30

-- Creates a hexagon display object
local function createHexagon(isPointyTop, size, squishFactor)
	if squishFactor == nil then squishFactor = 1 end 
    local vertices = {}
    if isPointyTop == true then
        for i=0,5,1 do
            local angle = 2 * math.pi / 6 * (i + 0.5)
            local x = size * math.cos(angle)
            local y = size * math.sin(angle)
            vertices[i*2+1] = x
            vertices[i*2+2] = y * squishFactor
        end    
    else
        for i=0,5,1 do
            local angle = 2 * math.pi / 6 * (i + 0.5) + THIRTY_DEGGREES_RAD
            local x = size * math.cos(angle)
            local y = size * math.sin(angle)
            vertices[i*2+1] = x
            vertices[i*2+2] = y * squishFactor
        end    
    end
    return display.newPolygon(0, 0, vertices )
end

-- Returns the integer cube coordinates that corresponds to the provided 
-- floating point cube coordinates.
local function cubeRound(x,y,z)
    local rx = math.floor(x+0.5)
    local ry = math.floor(y+0.5)
    local rz = math.floor(z+0.5)
    -- make sure that x+y+z=1 contraint still holds
    local diffx = math.abs(rx-x)
    local diffy = math.abs(ry-y)
    local diffz = math.abs(rz-z)
    if diffx > diffy and diffx > diffz then
        rx = -ry-rz
    elseif diffy > diffz then
        ry = -rx-rz
    else 
        rz = -rx-ry    
    end
    
    return rx,ry,rz
 end

-- Returns the q,r pair for the hex that is under x,y
local function pixelToHex(x, y, isPointyTop, size)
    local q, r
    if isPointyTop == true then
        q = (x * math.sqrt(3)/3 - y / 3) / size
        r = y * 2/3 / size
    else
        q = x * 2/3 / size
        r = ((x*-1) / 3 + math.sqrt(3)/3 * y) / size
    end
    
 --   print("pixelToHex "..x..","..y.."->"..q..","..r )
    
    -- r,q are now floating point, need to round to the correct hex coordinate
    local x = q; local z=r; local y = -x-z;
    x,y,z = cubeRound(x,y,z)
    return x,z
end

-- Convert Hex r,q coordinate to pixel coordinates.
local function hexToPixel(q, r, isPointyTop, size)
    if type(q) ~= "number" then error("HexView.hexToPixel: q is of invalid type " .. type(q), 2) end 
    if type(r) ~= "number" then error("HexView.hexToPixel: r is of invalid type " .. type(r), 2) end 
    if type(isPointyTop) ~= "boolean" then error("HexView.hexToPixel: isPointyTop is of invalid type " .. type(isPointyTop), 2) end 
    if type(size) ~= "number" then error("HexView.hexToPixel: size is of invalid type " .. type(size), 2) end 
    local x; local y;
    if isPointyTop == true then
        x = size * math.sqrt(3) * (q + r/2)
        y = size * 3/2 * r
    else
        x = size * 3/2 * q
        y = size * math.sqrt(3) * (r + q/2)
    end
    return x,y
end

-- Iterator that iterates over the neighbors of the hex at q,r. Pointyness doesn't matter.
local function neighbors(q,r)
    if type(q) ~= "number" then error("HexView.hexToPixel: q is of invalid type " .. type(q), 2) end 
    if type(r) ~= "number" then error("HexView.hexToPixel: r is of invalid type " .. type(r), 2) end 

    local n = {1,0, 0,1, -1,1, -1,0, 0,-1, 1,-1}
    local i = 0;
    return function ()
        if i > 5 then return nil end
        local qn = q+n[i*2+1]
        local rn = r+n[i*2+2]
        i = i + 1
        return qn,rn
    end
end

-- Iterator that iterates over all hexes in a column (increasing q coordinate) starting at q,r. Note 
-- that this iterator will iterate indefinitely if width is nil so has to be used in a while loop
-- with some custom end criteria.
local function colHexes(q,r,height,inc)
    if type(q) ~= "number" then error("q is of invalid type " .. type(q), 2) end 
    if type(r) ~= "number" then error("r is of invalid type " .. type(r), 2) end 
    if (type(height) ~= "number" and type(height) ~= "nil") then error("height is of invalid type " .. type(height), 2) end 
    if (type(inc) ~= "number" and type(inc) ~= "nil") then error("inc is of invalid type " .. type(width), 2) end 
	if type(inc) == "nil" then inc = 1 end

    local q = q
    local r = r
    local i = 0
    
    return function ()
        if height ~= nil and i>=height then return nil end
        if i==0 then i=i+1 return q,r end
		q = q + inc
		r = r
        i = i+1
        return q,r
    end
end


-- Iterator that iterates over all hexes in a row (increasing r coordinate) starting at q,r. Note 
-- that this iterator will iterate indefinitely if width is nil so has to be used in a while loop
-- with some custom end criteria.
local function rowHexes(q,r,width,inc)
    if type(q) ~= "number" then error("q is of invalid type " .. type(q), 2) end 
    if type(r) ~= "number" then error("r is of invalid type " .. type(r), 2) end 
    if (type(width) ~= "number" and type(width) ~= "nil") then error("width is of invalid type " .. type(width), 2) end 
    if (type(inc) ~= "number" and type(inc) ~= "nil") then error("inc is of invalid type " .. type(width), 2) end 
	if type(inc) == "nil" then inc = 1 end
	
    local q = q
    local r = r
    local i = 0
    
    return function ()
        if width ~= nil and i>=width then return nil end
        if i==0 then i=i+1 return q,r end
		q = q
		r = r + inc
        i = i+1
        return q,r
    end
end


-- Iterator that iterates over all hexes in a horizontal line starting at q,r. Note that this iterator
-- will iterate indefinitely if width is nil so has to be used in a while loop with some custom end 
-- criteria. For pointy top the line will be straight. For flat topped odd columns will be offset
-- down and even up.
local function horizontals(q,r,isPointyTop,width)
    if type(q) ~= "number" then error("q is of invalid type " .. type(q), 2) end 
    if type(r) ~= "number" then error("r is of invalid type " .. type(r), 2) end 
    if type(isPointyTop) ~= "boolean" then error("isPointyTop is of invalid type " .. type(isPointyTop), 2) end 
    if (type(width) ~= "number" and type(width) ~= "nil") then error("width is of invalid type " .. type(width), 2) end 

    local q = q
    local r = r
    local i = 0
    
    return function ()
        if width ~= nil and i>=width then return nil end
    
        if i==0 then i=i+1 return q,r end
        
        if(isPointyTop) then
            q = q + 1
            r = r
        else
            if q%2 == 0 then
                -- even column
                q = q + 1 
                r = r
            else
                -- odd column
                q = q + 1
                r = r - 1
            end
        end
        i = i+1
        return q,r
    end
end

-- Iterator that iterates over all hexes in a vertical line starting at q,r. Note that this iterator
-- will iterate indefinitely if height is nil so has to be used in a while loop with some custom end 
-- criteria. For pointy top the line will be wobbly, odd rows will be offset to the left and even to the 
-- right. For flat top it will be straight.
local function verticals(q,r,isPointyTop,height)
    if type(q) ~= "number" then error("q is of invalid type " .. type(q), 2) end 
    if type(r) ~= "number" then error("r is of invalid type " .. type(r), 2) end 
    if type(isPointyTop) ~= "boolean" then error("isPointyTop is of invalid type " .. type(isPointyTop), 2) end 
    if (type(height) ~= "number" and type(height) ~= "nil") then error("height is of invalid type " .. type(height), 2) end 

    local q = q
    local r = r
    local i = 0
    
    return function ()
        if height ~= nil and i>=height then return nil end
    
        if i==0 then i=i+1 return q,r end
        
        if(isPointyTop) then
            if r%2 == 0 then
                -- even row
                q = q 
                r = r + 1
            else
                -- odd row
                q = q - 1
                r = r + 1
            end
        else
            q = q 
            r = r + 1
        end
        i = i+1
        return q,r
    end
end

-- Return the HexView name space that controls access to supported interface
HexUtils.hexToPixel = hexToPixel
HexUtils.pixelToHex = pixelToHex
HexUtils.createHexagon = createHexagon
HexUtils.neighbors = neighbors
HexUtils.horizontals = horizontals
HexUtils.verticals = verticals
HexUtils.rowHexes = rowHexes
HexUtils.colHexes = colHexes

setmetatable(HexUtils, {
    __index = function(t,k) error("Attempt to access unsupported key in HexUtils", 2) end, 
    __newindex = function(t,k,v) error("attempt to set unsupported key in HexUtils", 2) end })
return HexUtils
