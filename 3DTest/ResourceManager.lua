print("Loading ResourceManager...")

-- Static information about a type of unit.
local ResourceManager = {}

-- Declare globals to be used by this package
local print = print
local setmetatable = setmetatable
local error = error
local type = type
local tostring = tostring
local string = string
local display = display

-- Forbid access of all other globals
local _P = {}
setmetatable(_P, {
    __index = function(t,k) error("Attempt to access global key " .. k, 2) end, 
    __newindex = function(t,k,v) error("attempt to set global key " .. k, 2) end })
setfenv(1,_P)

-- Expose public interface.
local accessTable = {
    -- addImageResource(name, path, width, height, corrX, corrY) Adds an image resource that will be loaded from the given path and has the original 1x size width x height. The Image will be translated with the provided correction when created.
    addImageResource = false,
    -- dispObj create(name) Creates a display object from the resource with the provided name
    create = false,
}

-- Creates the ResourceManager that will be returned from the file.
local function new()
    local o = {}

    local mResources = {}
    
    function o:addImageResource(name, path, width, height, corrX, corrY)
        if type(name) ~= "string" then error("ResourceManager:addImageResource(): name is of invalid type " .. type(name), 2) end 
        if type(path) ~= "string" then error("ResourceManager:addImageResource(): path is of invalid type " .. type(path), 2) end 
        if type(width) ~= "number" then error("ResourceManager:addImageResource(): width is of invalid type " .. type(width), 2) end 
        if type(height) ~= "number" then error("ResourceManager:addImageResource(): height is of invalid type " .. type(height), 2) end 
        if type(corrX) ~= "number" then error("ResourceManager:addImageResource(): corrX is of invalid type " .. type(corrX), 2) end 
        if type(corrY) ~= "number" then error("ResourceManager:addImageResource(): corrY is of invalid type " .. type(corrY), 2) end 

        if mResources[name] ~= nil then error("Attempt to add already existing resource " .. name .. " to resource manager.") end
        
        print("Added resource " .. name .. " to ResourceManager.")
        
        mResources[name] = {name=name, path=path, width=width, height=height, corrX=corrX, corrY=corrY}
    end
    
    function o:create(name)
        if type(name) ~= "string" then error("ResourceManager:addImageResource(): name is of invalid type " .. type(name), 2) end 
        
        local resource = mResources[name]
        if resource == nil then error("Failed to create resource \" " .. name .. "\". Resource doesn't exist.", 2) end
    
        local image = display.newImageRect(resource.path, resource.width, resource.height)

        -- Take corrections into account
        image:translate(resource.corrX, resource.corrY)
        
        return image
    end
    
    -- Return proxy that enforce access only to public members and methods
    local proxy = {}
    setmetatable(proxy, {
        __index = function(t,k) 
            if accessTable[k] ~= nil
                then return o[k]
            else
                error("Attempt to access key " .. k .. " in instance of type " .. "ResourceManager", 2)
            end
        end, 
        __newindex = function(t,k,v) 
            if accessTable[k] == true
                then return o[k]
            else
                error("Attempt to set key " .. k .. "=" .. v .. " in instance of type " .. "ResourceManager", 2)
            end
        end })
    return proxy
end

return new()

