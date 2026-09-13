const StarSignal = require(game.ReplicatedStorage.Packages.StarSignal)
const StarJanitor = require(game.ReplicatedStorage.Packages.StarJanitor)
const CacheHandler = require(script.CacheHandler)
const Bridge = require(script.Bridge)

const GetValueAtKey = CacheHandler.GetValueAtPath
const SetValueAtKey = CacheHandler.SetValueAtPath
const GetParentKey = CacheHandler.GetParentPath

type function GetPathDivider()
	return "."
end

export type function ParsePath(t: type, path: type): type
	if path:is "string" == true then
		return types.any
	elseif (t:is "table" and path:is "singleton") == false then
		return types.never
	end

	const value = path:value() :: string
	const arrayValue = value:split(GetPathDivider())
	const singleton = types.singleton

	local previous = t

	for index, value in arrayValue do
		previous = previous:readproperty(singleton(value))

		if previous == nil then
			return types.any
		end
	end

	return previous :: type
end

export type function GetArrayKeys(t: type): type
	if t:is "table" == false then
		print(`{t.tag} is not a table`)
		return types.singleton(`type: {t.tag}, must be a table`)
	end

	const singleton = types.singleton
	const unionof = types.unionof
	const divider = GetPathDivider() -- if want like items/key then change this to "/"

	local pathType = types.never

	const function makeunion(key: type)
		pathType = unionof(pathType, key)
	end

	const function createpath(key: type, parentKey: type)
		return singleton(parentKey:value() :: string .. divider .. key:value() :: string)
	end

	const function isarray(t: type)
		const indexer = t:indexer()
		const index = indexer and indexer.index
		return index and index:is "number"
	end

	local function iterateTable(t: type, parentKey: type?)
		for key, value in t:properties() do
			const read = value.read or value.write
			const newkey = parentKey and createpath(key, parentKey) or key

			if read and read:is "table" then
				if isarray(read) == true then
					makeunion(newkey)
				end
				iterateTable(read, newkey)
			end
		end
	end

	iterateTable(t)
	return pathType
end

export type function GetNumberKeys(t: type): type
	if t:is "table" == false then
		print(`{t.tag} is not a table`)
		return types.singleton(`type: {t.tag}, must be a table`)
	end

	const singleton = types.singleton
	const unionof = types.unionof
	const divider = GetPathDivider() -- if want like items/key then change this to "/"

	local pathType = types.never

	const function makeunion(key: type)
		pathType = unionof(pathType, key)
	end

	const function createpath(key: type, parentKey: type)
		return singleton(parentKey:value() :: string .. divider .. key:value() :: string)
	end

	local function iterateTable(t: type, parentKey: type?)
		for key, value in t:properties() do
			const read = value.read or value.write
			const newkey = parentKey and createpath(key, parentKey) or key

			if read then
				if read:is "number" then
					makeunion(newkey)
				elseif read:is "table" then
					iterateTable(read, newkey)
				end
			end
		end
	end

	iterateTable(t)
	return pathType
end

export type function GetKeys(t: type): type
	if t:is "table" == false then
		print(`{t.tag} is not a table`)
		return types.singleton(`type: {t.tag}, must be a table`)
	end

	const singleton = types.singleton
	const unionof = types.unionof
	const divider = GetPathDivider()

	local pathType = types.never

	const function makeunion(key: type)
		pathType = unionof(pathType, key)
	end

	const function createpath(key: type, parentKey: type)
		return singleton(parentKey:value() :: string .. divider .. key:value() :: string)
	end

	const function iterateTable(t: type, parentKey: type?)
		for key, value in t:properties() do
			const read = value.read or value.write
			const newkey = parentKey and createpath(key, parentKey) or key

			makeunion(newkey)

			if read and read:is "table" then
				iterateTable(read, newkey)
			end
		end
	end

	iterateTable(t)
	return pathType
end

type Path<T, Y> = GetKeys<T> | Y | ""
type Janitor = StarJanitor.Janitor
type UpdateCallback<T = any> = (value: T) -> T
type ObserverCallback<T = any> = (value: T, oldvalue: T) -> ()

export type ClientSetValidator<T = any> = (player: Player, value: unknown, currentValue: T) -> T?

export type ClientConfig = {
	hiddenPaths: { string }?,
	setValidators: { [string]: ClientSetValidator }?,
}

export type Config = {
	players: { Player }?,
	client: ClientConfig?,
}

export type Replica<T = table> = {
	read name: string,
	read data: T,
	read janitor: StarJanitor.Janitor,
	read config: Config,

	read subscribers: { Player },

	read signals: {
		read changed: table<string, Signal>,
		read arrayinsert: table<string, Signal>,
		read arrayremove: table<string, Signal>,
		read childchanged: table<string, Signal>,
	},

	Get: <Y>(self: Replica<T>, Path<T, Y>) -> ParsePath<T, Y>,
	Set: <Y>(self: Replica<T>, Path<T, Y>, value: ParsePath<T, Y>) -> (),

	Update: <Y>(
		self: Replica<T>,
		path: Path<T, Y>,
		callback: UpdateCallback<ParsePath<T, Y>>
	) -> (),
	UpdateB: <Y>(
		self: Replica<T>,
		path: Path<T, Y>
	) -> (callback: UpdateCallback<ParsePath<T, Y>>) -> (),
	Increment: (self: Replica<T>, path: GetNumberKeys<T>, amount: number) -> (),

	ArrayFind: (self: Replica<T>, path: GetArrayKeys<T>, value: any) -> number?,
	ArrayRemove: (self: Replica<T>, path: GetArrayKeys<T>, value: any) -> (),
	ArrayInsert: (self: Replica<T>, path: GetArrayKeys<T>, value: any, index: number?) -> (),
	ArrayRemoveAt: (self: Replica<T>, path: GetArrayKeys<T>, index: number) -> any,

	Observe: <Y>(
		self: Replica<T>,
		path: Path<T, Y>,
		callback: ObserverCallback<ParsePath<T, Y>>
	) -> Connect,
	ObserveB: <Y>(
		self: Replica<T>,
		path: Path<T, Y>
	) -> (callback: ObserverCallback<ParsePath<T, Y>>) -> Connect,

	OnValueChanged: <Y>(
		self: Replica<T>,
		path: Path<T, Y>,
		callback: ObserverCallback<ParsePath<T, Y>>
	) -> Connect,
	OnChildChanged: (
		self: Replica<T>,
		path: GetKeys<T>,
		callback: (
			action: "changed" | "added" | "removed",
			key: string,
			value: any,
			oldvalue: any
		) -> ()
	) -> Connect,
	OnArrayInsert: (
		self: Replica<T>,
		path: GetArrayKeys<T>,
		callback: (value: any, index: number) -> ()
	) -> Connect,
	OnArrayRemove: (
		self: Replica<T>,
		path: GetArrayKeys<T>,
		callback: (value: any, index: number) -> ()
	) -> Connect,

	GetSubscribers: (self: Replica<T>) -> { Player },
	Subscribe: (self: Replica<T>, player: Player) -> (),
	UnSubscribe: (self: Replica<T>, player: Player) -> (),
	Initialize: (self: Replica<T>, replicationType: "all" | "subscribers") -> (),
	Destroy: (self: Replica<T>) -> (),
}

export type TestData = {
	Stats: {
		Cash: number,
		Gems: number,
		Rebirths: number,
		Level: number,
		Exp: number,
	},

	Settings: {
		MusicVolume: number,
		SfxVolume: number,
		GiftBrainrots: boolean,
		GiftGamepasses: boolean,
	},

	Inventory: {
		Items: { string },
		Jetpacks: {
			[string]: boolean,
		},
		EquippedJetpack: string,
	},

	Market: {
		Gamepasses: {
			VIP: boolean,
			Magnet: boolean,
			DoubleSpeed: boolean,
		},

		Entitlements: {
			VIP: boolean,
			Magnet: boolean,
			DoubleSpeed: boolean,
		},

		ProcessedReceipts: {
			[string]: boolean,
		},
	},

	Session: {
		JoinTime: number,
		IsLoaded: boolean?,
	},
}

const function CreateSignalInJanitor(janitor: Janitor)
	return janitor:AddItem(StarSignal.new<<(...any) -> ()>>(), "Destroy")
end

const function FireSignalIfExist(signal: Signal?, ...)
	if signal ~= nil then
		signal:Fire(...)
	end
end

const function FireChildChangedSignal(signalmap: table, path: string, value, old)
	const rootpath, key = GetParentKey(path)
	if rootpath == nil then
		return
	end

	const signal = signalmap[rootpath]
	const action = if old == nil then "added" elseif value == nil then "removed" else "changed"
	FireSignalIfExist(signal, action, key, value, old)
end

const function FireObserveSignals(signalmap: index<Replica, "signals">, path: string, value, old)
	FireSignalIfExist(signalmap.changed[path], value, old)
	FireChildChangedSignal(signalmap.childchanged, path, value, old)
end

const replicasByName: { [string]: Replica } = {}

const function IsSameOrChildPath(path: string, parentPath: string): boolean
	return path == parentPath or string.sub(path, 1, #parentPath + 1) == `{parentPath}.`
end

const function IsHiddenPath(replica: Replica, path: string): boolean
	const hiddenPaths = replica.config.client and replica.config.client.hiddenPaths
	if hiddenPaths == nil then
		return false
	end

	for _, hiddenPath in hiddenPaths do
		if IsSameOrChildPath(path, hiddenPath) then
			return true
		end
	end

	return false
end

const function CreateClientSnapshot(replica: Replica, value: any, path: string): (any, boolean)
	const hiddenPaths = replica.config.client and replica.config.client.hiddenPaths
	if hiddenPaths == nil or #hiddenPaths == 0 then
		return value, true
	end

	if IsHiddenPath(replica, path) then
		return nil, false
	end

	if type(value) ~= "table" then
		return value, true
	end

	const snapshot = {}
	for key, childValue in value do
		const childPath = if path == "" then tostring(key) else `{path}.{key}`
		const clientValue, shouldReplicate = CreateClientSnapshot(replica, childValue, childPath)
		if shouldReplicate then
			snapshot[key] = clientValue
		end
	end

	return snapshot, true
end

const function replicateOperation(replica: Replica, operation: any)
	const path = operation.path
	if type(path) == "string" then
		if IsHiddenPath(replica, path) then
			return
		end

		if operation.value ~= nil then
			const clientValue, shouldReplicate =
				CreateClientSnapshot(replica, operation.value, path)
			if shouldReplicate == false then
				return
			end

			operation.value = clientValue
		end
	end

	const subscribers = replica:GetSubscribers()
	operation.name = replica.name
	Bridge.SendReplicaOperation(subscribers, operation)
end

--[[ PUBLIC FUNCTIONS ]]
--

const function Get(self: Replica, path: string): any?
	const parent, key = GetValueAtKey(self.data, path)
	return parent ~= nil and parent[key]
end

const function Set(self: Replica, path: string, value: any)
	local parent, key = GetValueAtKey(self.data, path)
	if parent ~= nil and key ~= nil then
		const oldvalue = parent[key]
		if oldvalue == value then
			return
		end

		parent[key] = value
		FireObserveSignals(self.signals, path, value, oldvalue)
		replicateOperation(self, { op = "set", path = path, value = value })
	else
		error("[StarReplica]: Invalid path: " .. path)
	end
end

const function Update(self: Replica, path: string, callback: UpdateCallback)
	const value = Get(self, path)
	Set(self, path, callback(value))
end

const function UpdateB(self: Replica, path: string): UpdateCallback
	return function(callback)
		Update(self, path, callback)
	end
end

const function Increment(self: Replica, path: string, amount: number)
	Update(self, path, function(value)
		assert(type(value) == "number", `Value at path: {path} must be number!`)
		assert(math.isfinite(value), "Attempt to add to a non-finite value")
		return value + amount
	end)
end

-- [[ Array operations ]] --

const function ArrayFind(self: Replica, path: string, value: any): number?
	const t = Get(self, path)
	assert(type(t) == "table", `[StarReplica]: value at path: {path} must be array.`)
	return table.find(t, value)
end

const function ArrayInsert(self: Replica, path: string, value: any, index: number?)
	const parent, key = GetValueAtKey(self.data, path)
	if parent == nil or key == nil then
		error("[StarReplica]: path " .. path .. " is not valid")
		return
	end

	assert(type(parent[key]) == "table", `[StarReplica]: value at path: {path} must be array.`)
	const index = index or #parent[key] + 1
	table.insert(parent[key], index, value)

	FireObserveSignals(self.signals, path, parent[key], parent[key])
	FireSignalIfExist(self.signals.arrayinsert[path], value, index)
	replicateOperation(self, { op = "insert", path = path, value = value, index = index })
end

const function ArrayRemoveAt(self: Replica, path: string, index: number): any?
	const parent, key = GetValueAtKey(self.data, path)
	if parent == nil or key == nil then
		error("[StarReplica]: path " .. path .. " is not valid")
		return
	end

	assert(type(parent[key]) == "table", `[StarReplica]: value at path: {path} must be array.`)
	const value = table.remove(parent[key], index)
	if value == nil then
		error("[StarReplica]: array index " .. tostring(index) .. " is out of range")
		return
	end

	FireObserveSignals(self.signals, path, parent[key], parent[key])
	FireSignalIfExist(self.signals.arrayremove[path], value, index)
	replicateOperation(self, { op = "remove", path = path, index = index })
	return value
end

const function ArrayRemove(self: Replica, path: string, value: any)
	const parent, key = GetValueAtKey(self.data, path)
	if parent == nil or key == nil then
		error("[StarReplica]: path " .. path .. " is not valid")
		return
	end

	const index = ArrayFind(self, path, value)
	if index == nil then
		error("[StarReplica]: value " .. tostring(value) .. " is not in array")
		return
	end

	ArrayRemoveAt(self, path, index)
end

-- [[ Batch operations ]] --

-- const function Batch(self: Observer, ops: {singleoperation})
-- 	for _, operation in ops do
-- 		if operation.op == "set" then
-- 			Set(self, operation.path, operation.value)
-- 		elseif operation.op == "insert" then
-- 			ArrayInsert(self, operation.path, operation.value, operation.index)
-- 		elseif operation.op == "remove" then
-- 			ArrayRemoveAt(self, operation.path, operation.index)
-- 		end
-- 	end
-- end

-- const function MultiSet(self: Observer, ops: table<string, any>)
-- 	const batch = {}
-- 	for path, value in ops do
-- 		table.insert(batch, {op = "set" :: "set", path = path, value = value})
-- 	end
-- 	Batch(self, batch)
-- end

-- Observers. completed--

const function OnValueChanged(self: Replica, path: string, callback: ObserverCallback): Connect
	const signal = self.signals.changed[path]
	if signal ~= nil then
		return signal:Connect(callback)
	end

	const signal = CreateSignalInJanitor(self.janitor)
	self.signals.changed[path] = signal
	return signal:Connect(callback)
end

const function OnChildChanged(
	self: Replica,
	path: string,
	callback: (
		action: "changed" | "added" | "removed",
		key: string,
		value: any,
		oldvalue: any
	) -> ()
): Connect
	const signal = self.signals.childchanged[path]
	if signal ~= nil then
		return signal:Connect(callback)
	end

	const signal = CreateSignalInJanitor(self.janitor)
	self.signals.childchanged[path] = signal
	return signal:Connect(callback)
end

const function OnArrayInsert(
	self: Replica,
	path: string,
	callback: (value: any, index: number) -> ()
): Connect
	const signal = self.signals.arrayinsert[path]
	if signal ~= nil then
		return signal:Connect(callback)
	end

	const signal = CreateSignalInJanitor(self.janitor)
	self.signals.arrayinsert[path] = signal
	return signal:Connect(callback)
end

const function OnArrayRemove(
	self: Replica,
	path: string,
	callback: (value: any, index: number) -> ()
): Connect
	const signal = self.signals.arrayremove[path]
	if signal ~= nil then
		return signal:Connect(callback)
	end

	const signal = CreateSignalInJanitor(self.janitor)
	self.signals.arrayremove[path] = signal
	return signal:Connect(callback)
end

const function Observe(self: Replica, path: string, callback: ObserverCallback): Connect
	const connect = self:OnValueChanged(path, callback)
	const value = Get(self, path)
	task.defer(callback, value, value)
	return connect
end

const function ObserveB(self: Replica, path: string): (callback: ObserverCallback) -> Connect
	return function(callback)
		return Observe(self, path, callback)
	end
end

const function Destroy(self: Replica)
	self.janitor:Destroy()
	setmetatable(self, nil)
end

const StarObserve = {}
StarObserve.__index = StarObserve

StarObserve.Get = Get
StarObserve.Set = Set
StarObserve.Update = Update
StarObserve.UpdateB = UpdateB
StarObserve.Increment = Increment

StarObserve.ArrayFind = ArrayFind
StarObserve.ArrayInsert = ArrayInsert
StarObserve.ArrayRemove = ArrayRemove
StarObserve.ArrayRemoveAt = ArrayRemoveAt

StarObserve.Observe = Observe
StarObserve.ObserveB = ObserveB

StarObserve.OnValueChanged = OnValueChanged
StarObserve.OnChildChanged = OnChildChanged
StarObserve.OnArrayInsert = OnArrayInsert
StarObserve.OnArrayRemove = OnArrayRemove

StarObserve.Destroy = Destroy

function StarObserve.new<T>(name: string, data: T, config: Config?): Replica<T>
	const janitor = StarJanitor.new()
	const replicaConfig = config or {}
	assert(replicasByName[name] == nil, `[StarReplica]: a replica named "{name}" already exists`)

	const self = setmetatable({
		name = name,
		data = data,
		janitor = janitor,
		config = replicaConfig,
		subscribers = {},
		signals = {
			changed = {},
			childchanged = {},
			arrayinsert = {},
			arrayremove = {},
		},
	}, StarObserve) :: Replica<T>
	replicasByName[name] = self

	if replicaConfig.players then
		for _, player in replicaConfig.players do
			self:Subscribe(player)
		end
	end

	return self
end

function StarObserve.GetSubscribers(self: Replica)
	return self.subscribers
end

function StarObserve.Subscribe(self: Replica, player: Player): ()
	if table.find(self.subscribers, player) == nil then
		table.insert(self.subscribers, player)
	end

	Bridge.SendReplicaLifecycleOperation({ player }, {
		name = self.name,
		data = CreateClientSnapshot(self, self.data, ""),
		kind = "Create",
	})
end

function StarObserve.Unsubscribe(self: Replica, player: Player): ()
	const index = table.find(self.subscribers, player)
	if index ~= nil then
		table.remove(self.subscribers, index)
		Bridge.SendReplicaLifecycleOperation({ player }, {
			name = self.name,
			kind = "Destroy",
		})
	end
end

function StarObserve.Initialize(self: Replica, replicationType: "all" | "subscribers"?): Replica
	self.janitor:AddItem(
		Bridge.RegisterRequestReplicasCallback(function(player: Player)
			if replicationType == "all" or table.find(self.subscribers, player) ~= nil then
				self:Subscribe(player)
			end
		end),
		"Disconnect"
	)

	return self
end

function StarObserve.Destroy(self: Replica): ()
	Bridge.SendReplicaLifecycleOperation(self.subscribers, {
		name = self.name,
		kind = "Destroy",
	})

	if replicasByName[self.name] == self then
		replicasByName[self.name] = nil
	end

	self.janitor:Destroy()
	setmetatable(self, nil)
end

Bridge.RegisterRequestReplicaSetCallback(
	function(player: Player, name: string, path: string, value: any)
		const replica = replicasByName[name]
		if replica == nil or table.find(replica.subscribers, player) == nil then
			return
		end

		const validators = replica.config.client and replica.config.client.setValidators
		const validator = validators and validators[path]
		if validator == nil or IsHiddenPath(replica, path) then
			return
		end

		const parent, key = GetValueAtKey(replica.data, path)
		if parent == nil or key == nil then
			return
		end

		local success, normalizedValue = pcall(validator, player, value, parent[key])
		if success == false then
			warn(`[StarReplica]: client validator failed for "{name}.{path}": {normalizedValue}`)
			return
		end

		if normalizedValue == nil then
			return
		end

		Set(replica, path, normalizedValue)
	end
)

return table.freeze(StarObserve)
