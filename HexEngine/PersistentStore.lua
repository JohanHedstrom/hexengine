print("Loading PersistentStore...")

-- The persistant store makes sure that all data stored in it are persisted between runs. 
-- Internally an sqlite database is used to store all the data as a plain key-value store.
-- When opeing a store it will create the db file if it wasn't already created and return 
-- a Group. Groups can contain leaf values that are stored as key value pairs in the group
-- table. A Group can also contain subgroups, and each group will have its own table in 
-- the sqlite database. The values are stored in Leaf objects that has a value member. 
-- This membler must be json serializable and is accessed through the member "value"
local PersistentStore = {}

-- Declare globals to be used by this package
local print = print
local setmetatable = setmetatable
local error = error
local type = type
local sqlite = require( "sqlite3" )
local system = system
local Runtime = Runtime
local pairs = pairs
local json = require( "json" )
local string = string
local next = next

-- Forbid access of all other globals
local _P = {}
setmetatable(_P, {
    __index = function(t,k) error("Attempt to access global key " .. k, 2) end, 
    __newindex = function(t,k,v) error("attempt to set global key " .. k, 2) end })
setfenv(1,_P)

-- Expose public interface for a Leaf with controlled read and/or write access 
-- Key present and false means read only, true means read/write
local accessTablePersistentStore = {
    -- Group,wasCreated open(name) Opens a new persistent store with the given name and returns 
	-- the root group for the store. If the store was already present it will be read from disk,
	-- otherwise a new store will be created.
    open = true,
}

-- Expose public interface for a Group with controlled read and/or write access 
-- Key present and false means read only, true means read/write
local accessTableGroup = {
    -- Group addGroup(name, isDynamic) Adds a group with the provided name and returns it. If isDynamic is left out
	--     or set to false the group will generate errors if non-existent keys are accessed. If set to true accessing 
	--     non-existent keys will return nil and assigning to them will create new group values.
    addGroup = false,
    -- bool addValue(name, value) Adds a leaf with the provided name and value and returns true if successful.
    addValue = false,
	-- save() Persists all changes to the db in this group and all sub groups
	save = false,
    -- bool has(key) Returns true if there is a child (group or leaf) with the provided name.
    has = false,
}

local function to_safe_json(str)
	if str == nil then return "null" end
	local encoded = json.encode(str)
	return string.gsub(encoded,"'","''")
end

local function from_safe_json(str)
	local orig = string.gsub(str, "''", "'")
	return json.decode(orig)
end

-- Helper that executes an sql query with error catching
local function exec(db, query, callback)
--	print("executing query", query)
	local errorCode = db:exec(query, callback)
	if errorCode ~= sqlite.OK then error("sqlite.exec() failed: "..db:errmsg(), 2) end
end

-- Returns true if the table exists
local function checkTableExists(db, name)
	local exists = false;
	local function processRows(udata, cols, values, names)
		exists = true
		return 0
	end
	exec(db, [[SELECT name FROM sqlite_master WHERE type='table' AND name=']]..name..[[']], processRows);
	return exists
end

-- Creates a new Group with the given name and parent and that operates on the given database. The group
-- is dynamic if isDynamic is true. If dynamic it will behave as a normal table, if not accesses to 
-- non-existent keys will result in an error.
-- returns Group,wasCreated
local function createGroup(db, name, parent, isDynamic)
    local o = {}

	o.name = name
	o.parent = parent
	
	-- Figure out the fully qualified name for this group
	local mFullName = name
	local current = parent
	while current ~= nil do
		mFullName = current.name.."_"..mFullName
		current = current.parent
	end
	
	o.fullName = mFullName
	
	-- Contains the set of entries that needs to be updated/created/deleted when saving this group.
	-- Keys are entries and the value is U/C/D for UPDATE/CREATE/DELETE.
	local mDirtySet = {}
	
	-- The set of child groups that belongs to this group. Group name as key and the Group as value.
	local mGroups = {}
	
	-- The set of leaf values that belong to this group. Leaf name as key and Leaf as value.
	local mLeafs = {}
	
	-- Adds a leaf with the provided initial value.
	function o:addValue(name, value)
		if type(name) ~= "string" then error("name is of invalid type " .. type(name), 2) end 
		
		-- Check if there is already a group or a leaf with this name
		if mGroups[name] ~= nil then 
			print("Failed to add leaf "..name..". A group with that name already exists.") 
			return false
		end
		if mLeafs[name] ~= nil then 
			print("Failed to add leaf "..name..". A leaf with that name already exists.") 
			return false
		end
		
		-- Add the leaf
		mLeafs[name] = value
	
		-- Add a create entry in the dirty set
		mDirtySet[name] = "C"
		
		return true
	end

	-- Adds a group with the provided initial value.
	function o:addGroup(name, isDynamic)
		if type(name) ~= "string" then error("name is of invalid type " .. type(name), 2) end 
		
		-- Check if there is already a group or a leaf with this name
		if mGroups[name] ~= nil then 
			print("Failed to add group "..name..". A group with that name already exists.") 
			return nil
		end
		if mLeafs[name] ~= nil then 
			print("Failed to add group "..name..". A leaf with that name already exists.") 
			return nil 
		end

		-- Add a create group entry in the dirty set (groups are prefixed with *)
		if isDynamic then 
			mDirtySet["*"..name] = "C"
		else
			mDirtySet["-"..name] = "C"
		end
		
		-- Add the group
		local group = createGroup(db,name,o,isDynamic)
		mGroups[name] = group
		--print("Added group "..mFullName.."."..name)
		return group
	end

	function o:save()
        -- TODO: optimize so that children mark their parents as dirty when changed to avoid
        --       having to save children unless the parent is marked as dirty
    
		-- Persist all sub groups recursively
		for k,v in pairs(mGroups) do v:save() end
    
        if next(mDirtySet) ~= nil then
            local sql_statement = ""
            
            -- Persist all dirty values
            for k,v in pairs(mDirtySet) do
                local value = mLeafs[k]
                if v == "C" then 
                    sql_statement = sql_statement..[[INSERT INTO ]]..mFullName..[[ VALUES(']]..k..[[', ']]..to_safe_json(value)..[[');]] 
                elseif v == "U" then 
                    sql_statement = sql_statement..[[UPDATE ]]..mFullName..[[ SET value=']]..to_safe_json(value)..[[' WHERE name=']]..k..[[';]] 
                    --print("Updated "..mFullName.."."..k.." with value \""..json.encode(value).."\"")
                else error("Unsupported dirty type "..v) end
            end

            --print(sql_statement)
            exec(db, sql_statement)
            
    --		for row in db:nrows([[SELECT * FROM ]]..mFullName) do
    --			print(row.name, row.value)
    --		end
            mDirtySet = {}
            print("Persisted group "..mFullName)
        end    
	end
    
    function o:has(k)
        local v = mGroups[k]
        if v ~= nil then return true end
        v = mLeafs[k]
        if v ~= nil then return true end
        return false
    end
	
	-- Marks a leaf dirty (called by the leaf, not part of the public interface)
	function o:markLeafDirty(leafName)
		print("marked leaf "..mFullName.."."..leafName.." dirty.")
		mDirtySet[leafName] = "U"
	end
	
	-- Create the group table
	
-- exec(db, [[DROP TABLE test]])
	
	local exists = checkTableExists(db, mFullName);
	if exists then 
--		print("Restoring group "..mFullName.." from db...")
		for row in db:nrows([[SELECT * FROM ]]..mFullName) do
			local name = row.name
			local prefix = string.sub(name,1,1)
			if prefix == "*" or prefix == "-" then
				-- create sub groups recursively
				local dyn = (prefix == "*")
				local groupName = string.sub(name,2)
				local subGroup = createGroup(db,groupName,o,dyn)
				mGroups[groupName] = subGroup
			else
				print("Restored leaf "..mFullName.."."..name.." to value "..row.value)
				mLeafs[name] = from_safe_json(row.value)
			end
		end
		print("Restored group "..mFullName.. " isDynamic: "..((isDynamic and "true") or "false")) 
	else 
		print("Created new group "..mFullName.. " isDynamic: "..((isDynamic and "true") or "false")) 
		exec(db, [[CREATE TABLE ]]..mFullName..[[(name PRIMARY KEY,value)]])
	end
	
    -- Return proxy that enforce access only to public members and methods
    local proxy = {}
    setmetatable(proxy, {
        __index = function(t,k) 
--			print("group", "index", t, k)
            if accessTableGroup[k] ~= nil
                then return o[k]
            else
				local v = mGroups[k]
				if v ~= nil then return v end
				v = mLeafs[k]
				if v ~= nil then return v end
				if isDynamic == true then return nil else 
					error("Attempt to access key " .. k .. " in Group " .. mFullName, 2)
				end
            end
        end, 
        __newindex = function(t,k,v)
--			print("group", "newindex", t, k, v)
			local leafValue = mLeafs[k]
            if accessTableGroup[k] ~= nil then 
				error("Attempt to set reserved field " .. k .. "=" .. (v or "nil") .. " in Group " .. mFullName, 2)
            elseif leafValue == nil and isDynamic == true then
				mLeafs[k] = v
				mDirtySet[k] = "C"
			elseif (leafValue ~= nil) then
				mLeafs[k] = v
				mDirtySet[k] = "U"
            else
                error("Attempt to set key " .. k .. "=" .. (v or "nil") .. " in Group " .. mFullName, 2)
            end
        end })
    return proxy, (not exists)
end

function PersistentStore.open(name, isDynamic)
	if type(name) ~= "string" then error("name is of invalid type " .. type(name), 2) end 

    local o = {}

	print("Opening persistent store \"" .. name .. "\"...")
    
	local path = system.pathForFile(name..".db", system.DocumentsDirectory)
	local db = sqlite.open(path)	

    -- Make sure that the db is closed on application exit
	local function onSystemEvent( event )
		if ( event.type == "applicationExit" ) then
			if ( db and db:isopen() ) then
				db:close()
				print("Closed db \""..name.."\" on application exit.")
			end
		end
	end
	Runtime:addEventListener( "system", onSystemEvent )
	
	return createGroup(db, name, nil, isDynamic)
end

-- Unit test
local function test()

	local store, wasCreated = PersistentStore.open("test87")

	if wasCreated then 
		print("Initializing test store...")
		local settings = store:addGroup("settings")
		local sound = settings:addGroup("sound")
			sound:addValue("disableSound",false)
			sound:addValue("volume", 42)
		local graphics = settings:addGroup("graphics")
			graphics:addValue("brightness", 80)
			graphics:addValue("effects", false)
		store:addValue("compound", {str="it's a problem", kalle=42, sune={var1=1, var2=2}})	
		local dynamic = store:addGroup("dynamic", true)
		store:save()
	else
		print("Restored test store from db")
	end
	
	print("store.settings.sound.volume", store.settings.sound.volume)
	print("store.settings.sound.disableSound", store.settings.sound.disableSound)
	print("store.settings.graphics.brightness", store.settings.graphics.brightness)
	print("store.settings.graphics.effects", store.settings.graphics.effects)
	print("store.compound", json.encode(store.compound))
	print("store.dynamic.newVal3", store.dynamic.newVal3)
	
	store.settings.sound.volume = store.settings.sound.volume + 10
	store.settings.sound.disableSound = not store.settings.sound.disableSound

	store.dynamic.newVal3 = 102

	store:save()
end

--test()


return PersistentStore

