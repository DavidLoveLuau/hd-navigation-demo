--!strict

const Players = game:GetService("Players")
const player = Players.LocalPlayer

const StarReplica = require("@game/ReplicatedStorage/Packages/StarReplica")

local function get(): ReplicaClient?
	return StarReplica.GetReplica(`Profile_{player.UserId}`) :: ReplicaClient?
end

local function wait(timeout: number?): ReplicaClient?
	return StarReplica.WaitForReplica(`Profile_{player.UserId}`, timeout) :: ReplicaClient?
end

return table.freeze {
	Get = get,
	Wait = wait,
}
