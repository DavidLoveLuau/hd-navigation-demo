--!strict

const Players = game:GetService("Players")
const SharedPackages = game.ReplicatedStorage.Packages

const StarReplica = require(SharedPackages.StarReplica)
const StarRemote = require(SharedPackages.StarRemote)

const TestAcknowledged =
	StarRemote.Event<<()>>("StarReplica_TestAcknowledged", false, { burst = 2, cost = 1, rate = 1 })

const player = Players.LocalPlayer
const replicaName = `StarReplicaTest_{player.UserId}`
const replica = assert(
	StarReplica.WaitForReplica(replicaName, 15),
	`[StarReplicaTest] Timed out waiting for {replicaName}`
)

assert(replica:Get "coins" == 10, "[StarReplicaTest] Initial coins snapshot is incorrect")
assert(
	replica:Get "nested.state" == "initial",
	"[StarReplicaTest] Initial nested snapshot is incorrect"
)
assert(
	replica:Get "nested.secret" == nil,
	"[StarReplicaTest] Hidden nested value reached the client"
)
assert(replica:Get "hidden" == nil, "[StarReplicaTest] Hidden table reached the client")
assert(replica:Get "settings.musicVolume" == 5, "[StarReplicaTest] Initial setting is incorrect")
assert(
	replica:ArrayFind("items", "Starter") == 1,
	"[StarReplicaTest] Initial array snapshot is incorrect"
)

local observedInitialValue = false
local coinsChanged = false
local childChanged = false
local inserted = false
local removed = false
local replicaDestroyed = false

replica:Observe("coins", function(value)
	if value == 10 then
		observedInitialValue = true
	end
end)

replica:OnValueChanged("coins", function(value, oldValue)
	coinsChanged = value == 25 and oldValue == 10
end)

replica:OnChildChanged("nested", function(action, key, value, oldValue)
	childChanged = action == "changed"
		and key == "state"
		and value == "updated"
		and oldValue == "initial"
end)

replica:OnArrayInsert("items", function(value, index)
	inserted = value == "Second" and index == 2
end)

replica:OnArrayRemove("items", function(value, index)
	removed = value == "Starter" and index == 1
end)

StarReplica.OnReplicaRemoved:Connect(function(removedReplica)
	if removedReplica.name == replicaName then
		replicaDestroyed = true
	end
end)

task.wait(0.1)
assert(observedInitialValue, "[StarReplicaTest] Observe did not provide the initial value")

replica:RequestSet("settings.musicVolume", 11)
task.wait(0.2)
assert(
	replica:Get "settings.musicVolume" == 10,
	"[StarReplicaTest] Client setting was not normalized by the server"
)

replica:RequestSet("coins", 999999)
replica:RequestSet("settings.musicVolume", "invalid")
task.wait(0.2)
assert(replica:Get "coins" == 10, "[StarReplicaTest] Client changed a non-writable field")
assert(
	replica:Get "settings.musicVolume" == 10,
	"[StarReplicaTest] Invalid client setting was accepted"
)

TestAcknowledged:FireServer()
task.wait(0.5)

assert(coinsChanged, "[StarReplicaTest] OnValueChanged did not receive the Set operation")
assert(childChanged, "[StarReplicaTest] OnChildChanged did not receive the nested Set operation")
assert(inserted, "[StarReplicaTest] OnArrayInsert did not receive the insert operation")
assert(removed, "[StarReplicaTest] OnArrayRemove did not receive the remove operation")
assert(replica:Get "coins" == 25, "[StarReplicaTest] Coins were not replicated")
assert(replica:Get "nested.state" == "updated", "[StarReplicaTest] Nested value was not replicated")
assert(
	replica:Get "nested.secret" == nil,
	"[StarReplicaTest] Hidden nested update reached the client"
)
assert(replica:Get "hidden" == nil, "[StarReplicaTest] Hidden update reached the client")
assert(
	replica:ArrayFind("items", "Starter") == nil,
	"[StarReplicaTest] Removed array value still exists"
)
assert(
	replica:ArrayFind("items", "Second") == 1,
	"[StarReplicaTest] Inserted array value is incorrect"
)

task.wait(3)
assert(replicaDestroyed, "[StarReplicaTest] Client did not receive replica destruction")

print "[StarReplicaTest][Client] PASS: snapshot, operations, observers, and destruction work"
