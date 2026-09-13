--!strict

const StarRemote = require(script.Parent.Parent.StarRemote)

const RequestReplicasEvent =
	StarRemote.Event<<()>>("StarReplica_RequestReplicas", false, { rate = 1, cost = 1, burst = 1 })
const ReplicateReplicaOperation = StarRemote.Event<<(any)>>(
	"StarReplica_ReplicateReplicaOperation",
	false,
	{ burst = 0, cost = 0, rate = 0 }
)
const ReplicateReplicaLifecycleOperation = StarRemote.Event<<(any)>>(
	"StarReplica_ReplicateReplicaLifecycleOperation",
	false,
	{ burst = 0, cost = 0, rate = 0 }
)
const RequestReplicaSet = StarRemote.Event<<(string, string, any)>>(
	"StarReplica_RequestSet",
	false,
	{ burst = 20, cost = 1, rate = 10 }
)

local function initialize(onLifecycle: (operation: any) -> (), onOperation: (operation: any) -> ())
	ReplicateReplicaLifecycleOperation:OnClient(onLifecycle)
	ReplicateReplicaOperation:OnClient(onOperation)
	RequestReplicasEvent:FireServer()
end

local function requestSet(name: string, path: string, value: any)
	RequestReplicaSet:FireServer(name, path, value)
end

return table.freeze {
	Initialize = initialize,
	RequestSet = requestSet,
}
