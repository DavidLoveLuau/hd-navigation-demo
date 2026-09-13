const Players = game:GetService("Players")

const StarRemote = require(game.ReplicatedStorage.Packages.StarRemote)
const StarSignal = require(game.ReplicatedStorage.Packages.StarSignal)

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

const readyPlayers: { Player } = {}
const onPlayerRequestReplicas = StarSignal.new<<(player: Player) -> ()>>()
const onRequestReplicaSet =
	StarSignal.new<<(player: Player, name: string, path: string, value: any) -> ()>>()

const function IsPlayerReady(player: Player)
	return table.find(readyPlayers, player) ~= nil
end

const function MarkPlayerReady(player: Player)
	assert(IsPlayerReady(player) == false, `{player.Name} aready required replicas`)
	table.insert(readyPlayers, player)
	onPlayerRequestReplicas:Fire(player)
end

const function DeletePlayerData(player: Player)
	const index = table.find(readyPlayers, player)
	if index ~= nil then
		table.remove(readyPlayers, index)
	end
end

Players.PlayerRemoving:Connect(DeletePlayerData)
RequestReplicasEvent:OnServer(MarkPlayerReady)
RequestReplicaSet:OnServer(function(player: Player, name: string, path: string, value: any)
	if type(name) ~= "string" or type(path) ~= "string" then
		return
	end

	onRequestReplicaSet:Fire(player, name, path, value)
end)

const function SendReplicaOperation(players: { Player }, operation: any)
	for _, player in players do
		if IsPlayerReady(player) == false then
			continue
		end

		ReplicateReplicaOperation:FireClient(player, operation)
	end
end

const function SendReplicaLifecycleOperation(players: { Player }, operation: any)
	for _, player in players do
		if IsPlayerReady(player) == false then
			continue
		end

		ReplicateReplicaLifecycleOperation:FireClient(player, operation)
	end
end

const function RegisterRequestReplicasCallback(callback: (player: Player) -> ())
	return onPlayerRequestReplicas:Connect(callback)
end

const function RegisterRequestReplicaSetCallback(callback: (
	player: Player,
	name: string,
	path: string,
	value: any
) -> ())
	return onRequestReplicaSet:Connect(callback)
end

return table.freeze {
	RegisterRequestReplicasCallback = RegisterRequestReplicasCallback,
	RegisterRequestReplicaSetCallback = RegisterRequestReplicaSetCallback,
	SendReplicaLifecycleOperation = SendReplicaLifecycleOperation,
	SendReplicaOperation = SendReplicaOperation,
}
