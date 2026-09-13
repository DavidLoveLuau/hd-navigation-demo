--!strict

const Bridge = require(script.Parent.Bridge)
const ClientReplica = require(script.Parent.ClientReplica)
const StarSignal = require(script.Parent.Parent.StarSignal)

export type Replica<T = any> = ClientReplica.Replica<T>

local replicas: { [string]: Replica } = {}
local onReplicaAdded = StarSignal.new<<(replica: Replica) -> ()>>()
local onReplicaRemoved = StarSignal.new<<(replica: Replica) -> ()>>()

local function get(name: string): Replica?
	return replicas[name]
end

local function waitForReplica(name: string, timeout: number?): Replica?
	local existing = get(name)
	if existing ~= nil then
		return existing
	end

	return onReplicaAdded:WaitWithCheckAndTimeout(function(replica: Replica)
		return replica.name == name
	end, timeout or 60)
end

local function createReplica(name: string, data: any)
	local existing = replicas[name]
	if existing ~= nil then
		existing:Destroy()
	end

	local replica = ClientReplica.new(name, data)
	replicas[name] = replica
	onReplicaAdded:Fire(replica)
end

local function destroyReplica(name: string)
	local replica = replicas[name]
	if replica == nil then
		return
	end

	replicas[name] = nil
	onReplicaRemoved:Fire(replica)
	replica:Destroy()
end

local function onLifecycle(operation: any)
	if type(operation) ~= "table" or type(operation.name) ~= "string" then
		warn "[StarReplica]: ignored malformed lifecycle operation"
		return
	end

	if operation.kind == "Create" then
		createReplica(operation.name, operation.data)
	elseif operation.kind == "Destroy" then
		destroyReplica(operation.name)
	else
		warn(`[StarReplica]: ignored unknown lifecycle operation "{tostring(operation.kind)}"`)
	end
end

local function onOperation(operation: any)
	if type(operation) ~= "table" or type(operation.name) ~= "string" then
		warn "[StarReplica]: ignored malformed replica operation"
		return
	end

	local replica = replicas[operation.name]
	if replica ~= nil then
		replica:Apply(operation)
	end
end

Bridge.Initialize(onLifecycle, onOperation)

return table.freeze {
	GetReplica = get,
	WaitForReplica = waitForReplica,
	OnReplicaAdded = onReplicaAdded,
	OnReplicaRemoved = onReplicaRemoved,
}
