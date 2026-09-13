--!strict

local Janitor = {}
Janitor.__index = Janitor

type CleanupMethod = "Disconnect" | "Destroy" | ((any) -> ()) | true

export type Janitor = setmetatable<{
	_objects: { [any]: CleanupMethod },
}, typeof(Janitor)>

local function getCleanupMethod(object: any): CleanupMethod
	local objectType = typeof(object)

	if objectType == "RBXScriptConnection" then
		return "Disconnect"
	elseif objectType == "Instance" then
		return "Destroy"
	elseif objectType == "function" then
		return true
	elseif objectType == "table" then
		if type(object.Destroy) == "function" then
			return "Destroy"
		elseif type(object.Disconnect) == "function" then
			return "Disconnect"
		end
	end

	return true
end

local function cleanupObject(object: any, cleanupMethod: CleanupMethod)
	if cleanupMethod == true then
		pcall(object)
	elseif type(cleanupMethod) == "function" then
		pcall(cleanupMethod, object)
	elseif type(cleanupMethod) == "string" then
		local method = object[cleanupMethod]
		if method then
			pcall(method, object)
		end
	end
end

function Janitor.new(): Janitor
	return setmetatable({
		_objects = {},
	}, Janitor) :: Janitor
end

function Janitor.AddItem<T>(self: Janitor, object: T, cleanupMethod: CleanupMethod?): T
	assert(object, "[StarJanitor]: Object is nil")
	self._objects[object] = cleanupMethod or getCleanupMethod(object)
	return object
end

function Janitor.Cleanup(self: Janitor)
	for object, cleanupMethod in self._objects do
		self._objects[object] = nil
		cleanupObject(object, cleanupMethod)
	end
end

function Janitor.Destroy(self: Janitor)
	self:Cleanup()
	setmetatable(self, nil)
end

return table.freeze(Janitor)
