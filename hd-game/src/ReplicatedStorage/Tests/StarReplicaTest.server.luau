--!strict

const Players = game:GetService("Players")
const ServerPackages = game.ServerScriptService.ServerPackages
const SharedPackages = game.ReplicatedStorage.Packages

const StarReplica = require(ServerPackages.StarReplica)
const StarRemote = require(SharedPackages.StarRemote)

const TestAcknowledged =
	StarRemote.Event<<()>>("StarReplica_TestAcknowledged", false, { burst = 2, cost = 1, rate = 1 })

local replicasByPlayer: { [Player]: any } = {}

local function createTestReplica(player: Player)
	const name = `StarReplicaTest_{player.UserId}`
	const replica = StarReplica.new(name, {
		coins = 10,
		nested = {
			state = "initial",
			secret = "not for clients",
		},
		items = { "Starter" },
		settings = {
			musicVolume = 5,
		},
		hidden = {
			receiptToken = "not for clients",
		},
	}, {
		players = { player },
		client = {
			hiddenPaths = { "hidden", "nested.secret" },
			setValidators = {
				["settings.musicVolume"] = function(_player, value: unknown): number?
					if
						type(value) ~= "number"
						or value ~= value
						or value == math.huge
						or value == -math.huge
					then
						return nil
					end

					return math.clamp(value, 0, 10)
				end,
			},
		},
	}):Initialize "subscribers"

	replicasByPlayer[player] = replica
	print(`[StarReplicaTest][Server] Created {name}`)
end

local function destroyTestReplica(player: Player)
	const replica = replicasByPlayer[player]
	if replica == nil then
		return
	end

	replicasByPlayer[player] = nil
	replica:Destroy()
end

Players.PlayerAdded:Connect(createTestReplica)
Players.PlayerRemoving:Connect(destroyTestReplica)

TestAcknowledged:OnServer(function(player: Player)
	const replica = replicasByPlayer[player]
	if replica == nil then
		warn(`[StarReplicaTest][Server] No replica for {player.Name}`)
		return
	end

	print(`[StarReplicaTest][Server] Client acknowledged {replica.name}; applying operations`)
	replica:Set("coins", 25)
	replica:Set("nested.state", "updated")
	replica:Set("nested.secret", "still not for clients")
	replica:Set("hidden.receiptToken", "still not for clients")
	replica:ArrayInsert("items", "Second")
	replica:ArrayRemoveAt("items", 1)

	task.delay(2, function()
		if replicasByPlayer[player] == replica then
			print(`[StarReplicaTest][Server] Destroying {replica.name}`)
			destroyTestReplica(player)
		end
	end)
end)

for _, player in Players:GetPlayers() do
	createTestReplica(player)
end
