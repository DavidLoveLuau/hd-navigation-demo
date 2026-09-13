--!strict

const CacheHandler = require(script.Parent.CacheHandler)
const Bridge = require(script.Parent.Bridge)
const StarJanitor = require(script.Parent.Parent.StarJanitor)
const StarSignal = require(script.Parent.Parent.StarSignal)

type SignalMap = { [string]: any }

export type Replica<T = any> = {
	name: string,
	data: T,
	janitor: any,
	signals: {
		changed: SignalMap,
		childchanged: SignalMap,
		arrayinsert: SignalMap,
		arrayremove: SignalMap,
	},
	Get: (self: Replica<T>, path: string) -> any,
	ArrayFind: (self: Replica<T>, path: string, value: any) -> number?,
	Observe: (
		self: Replica<T>,
		path: string,
		callback: (value: any, oldValue: any) -> ()
	) -> StarSignal.Connect,
	ObserveB: (
		self: Replica<T>,
		path: string
	) -> ((value: any, oldValue: any) -> ()) -> StarSignal.Connect,
	OnValueChanged: (
		self: Replica<T>,
		path: string,
		callback: (value: any, oldValue: any) -> ()
	) -> StarSignal.Connect,
	OnChildChanged: (
		self: Replica<T>,
		path: string,
		callback: (
			action: "added" | "changed" | "removed",
			key: string,
			value: any,
			oldValue: any
		) -> ()
	) -> StarSignal.Connect,
	OnArrayInsert: (
		self: Replica<T>,
		path: string,
		callback: (value: any, index: number) -> ()
	) -> StarSignal.Connect,
	OnArrayRemove: (
		self: Replica<T>,
		path: string,
		callback: (value: any, index: number) -> ()
	) -> StarSignal.Connect,
	RequestSet: (self: Replica<T>, path: string, value: any) -> (),
	_Set: (self: Replica<T>, path: string, value: any) -> boolean,
	_ArrayInsert: (self: Replica<T>, path: string, value: any, index: number?) -> boolean,
	_ArrayRemoveAt: (self: Replica<T>, path: string, index: number) -> boolean,
	Apply: (self: Replica<T>, operation: any) -> boolean,
	Destroy: (self: Replica<T>) -> (),
}

local ClientReplica = {}
ClientReplica.__index = ClientReplica

local function fire(signal: any, ...: any)
	if signal ~= nil then
		signal:Fire(...)
	end
end

local function createSignal(self: Replica): any
	return self.janitor:AddItem(StarSignal.new(), "Destroy")
end

local function getSignal(signals: SignalMap, path: string, self: Replica): any
	local signal = signals[path]
	if signal == nil then
		signal = createSignal(self)
		signals[path] = signal
	end

	return signal
end

local function fireChildChanged(self: Replica, path: string, value: any, oldValue: any)
	local parentPath, key = CacheHandler.GetParentPath(path)
	if parentPath == nil then
		return
	end

	local action = if oldValue == nil then "added" elseif value == nil then "removed" else "changed"
	fire(self.signals.childchanged[parentPath], action, key, value, oldValue)
end

local function fireValueChanged(self: Replica, path: string, value: any, oldValue: any)
	fire(self.signals.changed[path], value, oldValue)
	fireChildChanged(self, path, value, oldValue)
end

function ClientReplica.new<T>(name: string, data: T): Replica<T>
	return setmetatable({
		name = name,
		data = data,
		janitor = StarJanitor.new(),
		signals = {
			changed = {},
			childchanged = {},
			arrayinsert = {},
			arrayremove = {},
		},
	}, ClientReplica) :: any
end

function ClientReplica.Get(self: Replica, path: string): any
	if path == "" or path == "@self" then
		return self.data
	end

	local parent, key = CacheHandler.GetValueAtPath(self.data, path)
	return if parent ~= nil and key ~= nil then parent[key] else nil
end

function ClientReplica.ArrayFind(self: Replica, path: string, value: any): number?
	local array = self:Get(path)
	return if type(array) == "table" then table.find(array, value) else nil
end

function ClientReplica.RequestSet(self: Replica, path: string, value: any)
	Bridge.RequestSet(self.name, path, value)
end

function ClientReplica._Set(self: Replica, path: string, value: any): boolean
	local parent, key = CacheHandler.GetValueAtPath(self.data, path)
	if parent == nil or key == nil then
		warn(`[StarReplica]: ignored Set for invalid path "{path}" on "{self.name}"`)
		return false
	end

	local oldValue = parent[key]
	if oldValue == value then
		return false
	end

	parent[key] = value
	fireValueChanged(self, path, value, oldValue)
	return true
end

function ClientReplica._ArrayInsert(
	self: Replica,
	path: string,
	value: any,
	index: number?
): boolean
	local array = self:Get(path)
	if type(array) ~= "table" then
		warn(`[StarReplica]: ignored ArrayInsert for invalid path "{path}" on "{self.name}"`)
		return false
	end

	local oldArray = table.clone(array)
	local insertIndex = index or #array + 1
	table.insert(array, insertIndex, value)
	fireValueChanged(self, path, array, oldArray)
	fire(self.signals.arrayinsert[path], value, insertIndex)
	return true
end

function ClientReplica._ArrayRemoveAt(self: Replica, path: string, index: number): boolean
	local array = self:Get(path)
	if type(array) ~= "table" then
		warn(`[StarReplica]: ignored ArrayRemove for invalid path "{path}" on "{self.name}"`)
		return false
	end

	local oldArray = table.clone(array)
	local value = table.remove(array, index)
	if value == nil then
		warn(`[StarReplica]: ignored ArrayRemove at missing index {index} on "{self.name}"`)
		return false
	end

	fireValueChanged(self, path, array, oldArray)
	fire(self.signals.arrayremove[path], value, index)
	return true
end

function ClientReplica.Apply(self: Replica, operation: any): boolean
	if type(operation) ~= "table" or type(operation.op) ~= "string" then
		warn(`[StarReplica]: ignored malformed operation on "{self.name}"`)
		return false
	end

	if operation.op == "set" then
		return self:_Set(operation.path, operation.value)
	elseif operation.op == "insert" then
		return self:_ArrayInsert(operation.path, operation.value, operation.index)
	elseif operation.op == "remove" then
		return self:_ArrayRemoveAt(operation.path, operation.index)
	end

	warn(`[StarReplica]: ignored unknown operation "{operation.op}" on "{self.name}"`)
	return false
end

function ClientReplica.OnValueChanged(
	self: Replica,
	path: string,
	callback: (value: any, oldValue: any) -> ()
): StarSignal.Connect
	return getSignal(self.signals.changed, path, self):Connect(callback)
end

function ClientReplica.OnChildChanged(
	self: Replica,
	path: string,
	callback: (
		action: "added" | "changed" | "removed",
		key: string,
		value: any,
		oldValue: any
	) -> ()
): StarSignal.Connect
	return getSignal(self.signals.childchanged, path, self):Connect(callback)
end

function ClientReplica.OnArrayInsert(
	self: Replica,
	path: string,
	callback: (value: any, index: number) -> ()
): StarSignal.Connect
	return getSignal(self.signals.arrayinsert, path, self):Connect(callback)
end

function ClientReplica.OnArrayRemove(
	self: Replica,
	path: string,
	callback: (value: any, index: number) -> ()
): StarSignal.Connect
	return getSignal(self.signals.arrayremove, path, self):Connect(callback)
end

function ClientReplica.Observe(
	self: Replica,
	path: string,
	callback: (value: any, oldValue: any) -> ()
): StarSignal.Connect
	local connection = self:OnValueChanged(path, callback)
	local value = self:Get(path)
	task.spawn(callback, value, value)
	return connection
end

function ClientReplica.ObserveB(
	self: Replica,
	path: string
): ((value: any, oldValue: any) -> ()) -> StarSignal.Connect
	return function(callback)
		return self:Observe(path, callback)
	end
end

function ClientReplica.Destroy(self: Replica)
	self.janitor:Destroy()
	setmetatable(self, nil)
end

return table.freeze(ClientReplica)
