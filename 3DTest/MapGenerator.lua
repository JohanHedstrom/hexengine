print("Loading Map2D...")

local Map2D = {}

-- Declare globals to be used by this package
local print = print
local setmetatable = setmetatable
local error = error
local type = type
local pairs = pairs
local tostring = tostring
local tonumber = tonumber
local string = string
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
    -- set(x,y,value) Sets the value at row y and col x
    set = false,
    -- get(x,y) Returns the value at row y and col x
    get = false,
    -- erase(x,y) Returns the value erased value at row y and col x, or nil if value wasn't set
    erase = false,
    -- Returns an iterator iterating over all the keys stored in the map. Returns x,y,val.
    iterator = false,
    -- Read only propery containing the number of elements stored in the map.
    size = false,
}

local function coordToString(x,y)
	-- Get rid of -0 index since when converting to a string -0 and 0 will be different strings 
	-- which is not a good thing.
	if x == 0 then x = 0 end
	if y == 0 then y = 0 end
	return ""..x..","..y
end

local function stringToCoord(str)
	local commaIndex = string.find(str, ",")
	local x = string.sub(str,1,commaIndex-1)
	local y = string.sub(str,commaIndex+1)
	return tonumber(x),tonumber(y)
end

function Map2D:new(store)
    local o = {}
	o.data = store or {}
    o.size = 0
    
    function o:get(x,y)
        if type(x) ~= "number" then error("x is of invalid type " .. type(x), 2) end 
        if type(y) ~= "number" then error("y is of invalid type " .. type(y), 2) end
		if math.floor(x) ~= x then error("x muse be an integer. x="..x, 2) end
		if math.floor(y) ~= y then error("y muse be an integer. y="..y, 2) end

		return o.data[coordToString(x,y)]
    end
    
    function o:set(x,y,val)
        if type(x) ~= "number" then error("x is of invalid type " .. type(x), 2) end 
        if type(y) ~= "number" then error("y is of invalid type " .. type(y), 2) end 
		if math.floor(x) ~= x then error("x muse be an integer. x="..x, 2) end
		if math.floor(y) ~= y then error("y muse be an integer. y="..y, 2) end
        if val == nil then error("val is nil. Use erase(x,y) to erase values instead", 2) end 

		local strCoord = coordToString(x,y)
		local prev = o.data[strCoord]
        if prev == nil then o.size = o.size + 1 end
		o.data[strCoord] = val
    end

    function o:erase(x,y)
        if type(x) ~= "number" then error("x is of invalid type " .. type(x), 2) end 
        if type(y) ~= "number" then error("y is of invalid type " .. type(y), 2) end 
		if math.floor(x) ~= x then error("x muse be an integer. x="..x, 2) end
		if math.floor(y) ~= y then error("y muse be an integer. y="..y, 2) end

		local strCoord = coordToString(x,y)
		local prev = o.data[strCoord]
		
        if prev == nil then return nil end
        o.data[strCoord] = nil
        o.size = o.size - 1
        return prev
    end

    function o:iterator()
        local i,is,cv = pairs(o.data)
		local coordStr = cv
		
		return function()
			local val = nil
			coordStr,val = i(is,coordStr)
			if coordStr == nil then return nil end
			local x,y = stringToCoord(coordStr)
			return x,y,val
		end
    end

    -- Return proxy that enforce access only to public members and methods
    local proxy = {}
    setmetatable(proxy, {
        __index = function(t,k) 
            if accessTable[k] ~= nil
                then return o[k]
            else
                error("Attempt to access key " .. k .. " in instance of type " .. "Map2D", 2)
            end
        end, 
        __newindex = function(t,k,v) 
            if accessTable[k] == true
                then return o[k]
            else
                error("Attempt to set key " .. k .. "=" .. v .. " in instance of type " .. "Map2D", 2)
            end
        end })
    return proxy
end

local function test()
    local m = Map2D:new()
    if m.size ~= 0 then error("Map2D test failed. Start size must be 0") end
    m:set(10,10, true)
    m:set(10,10, true)
    if m.size ~= 1 then error("Map2D test failed. Wrong size after add detected") end
    if m:get(5,5) ~= nil then error("Map2D test failed. Get of unset coordinate returned non-nil value") end
    if m:get(10,10) == nil then error("Map2D test failed. Get of set coordinate returned nil value") end
    if m:erase(10,10) == nil then error("Map2D test failed. Failed to erase.") end
    if m:erase(10,10) ~= nil then error("Map2D test failed. Failed to erase.") end
    if m.size ~= 0 then error("Map2D test failed. Wrong size after eraze detected") end
    if m:erase(5,5) ~= nil then error("Map2D test failed. Erase succeeded when it shouldn't.") end
		
	local size = 0
	for x,y,val in m:iterator() do
		size = size + 1
	end
	if size ~= 0 then error("Map didn't iterate over the expected number of entries") end

	size = 0
	m:set(1,2,42)
	for x,y,val in m:iterator() do
		size = size + 1
	end
	if size ~= 1 then error("Map didn't iterate over the expected number of entries") end

	size = 0
	m:set(3,4,43)
	m:set(3,5,43)
	m:set(4,4,43)
	for x,y,val in m:iterator() do
		size = size + 1
	end
	print(size)
	if size ~= 4 then error("Map didn't iterate over the expected number of entries") end

	
end

test()


return Map2D

