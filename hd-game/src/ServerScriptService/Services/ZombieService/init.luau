--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Jecs = require(game.ServerScriptService.ServerPackages.Wally.jecs)
local StarRemote = require(game.ReplicatedStorage.Packages.StarRemote)
local ZombieConfig = require(script.Config)
local ZombieProtocol = require(game.ReplicatedStorage.Shared.ZombieProtocol)
local NavigationGraph = require(script.NavigationGraph)
local ZombieRaycaster = require(script.ZombieRaycaster)

local RequestInitialState = StarRemote.ZombieWorld_RequestInitialState
local Initialize = StarRemote.ZombieWorld_Initialize
local Lifecycle = StarRemote.ZombieWorld_Lifecycle
local Snapshot = StarRemote.ZombieWorld_Snapshot
local DebugSnapshot = StarRemote.ZombieWorld_DebugSnapshot

local SimulationConfig = ZombieConfig.Simulation
local NetworkingConfig = ZombieConfig.Networking
local SpawningConfig = ZombieConfig.Spawning
local GroundingConfig = ZombieConfig.Grounding
local SeparationConfig = ZombieConfig.Separation
local DebugConfig = ZombieConfig.Debug

local world = Jecs.World.new()
local zombieRaycaster = ZombieRaycaster.new()
local navigationGraph = NavigationGraph.new(zombieRaycaster)
navigationGraph:SetDebugEnabled(ZombieConfig.Debug.ShowNavigationGraph)
local Position = world:component()
local Velocity = world:component()
local TargetPlayer = world:component()
local NetworkId = world:component()
local ZombieTypeId = world:component()
local DebugState = world:component()
local NextAttackTime = world:component()
local Health = world:component()
local SpawnOwner = world:component()

type ZombieSpatialEntry = {
	netId: number,
	position: Vector3,
	separationRadius: number,
}

type ZombieSpatialHash = { [number]: { [number]: { ZombieSpatialEntry } } }

local entitiesByPlayer: { [Player]: { number } } = {}
local nextNetworkId = 0
local simulationTick = 0
local simulationAccumulator = 0
local snapshotAccumulator = 0
local maximumSeparationRadius = 0

for _, zombieType in ZombieConfig.Types do
	maximumSeparationRadius = math.max(maximumSeparationRadius, zombieType.SeparationRadius)
end

local function getPlayerTarget(player: Player): NavigationGraph.PlayerTarget?
	local character = player.Character
	if character == nil then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass "Humanoid"
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end

	local root = character:FindFirstChild "HumanoidRootPart"
	if root == nil or root:IsA "BasePart" == false then
		return nil
	end

	return {
		player = player,
		position = root.Position,
		humanoid = humanoid,
	}
end

local function getRootPosition(player: Player): Vector3?
	local target = getPlayerTarget(player)
	return if target ~= nil then target.position else nil
end

local function collectPlayerTargets(): { NavigationGraph.PlayerTarget }
	local targets = {}

	for _, player in Players:GetPlayers() do
		local target = getPlayerTarget(player)
		if target ~= nil then
			table.insert(targets, target)
		end
	end

	return targets
end

local function findClosestTarget(
	position: Vector3,
	targets: { NavigationGraph.PlayerTarget }
): NavigationGraph.PlayerTarget?
	local closestTarget: NavigationGraph.PlayerTarget? = nil
	local closestDistanceSquared = math.huge

	for _, target in targets do
		local offset = target.position - position
		local distanceSquared = offset:Dot(offset)
		if distanceSquared < closestDistanceSquared then
			closestTarget = target
			closestDistanceSquared = distanceSquared
		end
	end

	return closestTarget
end

local function getZombieState(entity: number): ZombieProtocol.ZombieState
	return {
		netId = assert(world:get(entity, NetworkId)),
		position = assert(world:get(entity, Position)),
		velocity = assert(world:get(entity, Velocity)),
	}
end

local function collectZombieStates(): { ZombieProtocol.ZombieState }
	local zombies = {}

	for entity in world:query(Position, Velocity, NetworkId) do
		table.insert(zombies, getZombieState(entity))
	end

	return zombies
end

local function collectZombieDebugStates(): { ZombieProtocol.ZombieDebugState }
	local zombies = {}

	for _, netId, kind in world:query(NetworkId, DebugState) do
		table.insert(zombies, {
			netId = netId,
			kind = kind,
		})
	end

	return zombies
end

local function sendInitialState(player: Player)
	Initialize:FireClient(
		player,
		NetworkingConfig.WorldRevision,
		Workspace:GetServerTimeNow(),
		ZombieProtocol.encodeStates(collectZombieStates())
	)
end

local function spawnZombiesForPlayer(player: Player)
	if entitiesByPlayer[player] ~= nil then
		return
	end

	local rootPosition = getRootPosition(player)
	if rootPosition == nil then
		return
	end

	local entities = {}
	for index = 1, SpawningConfig.ZombiesPerPlayer do
		local ring = math.floor((index - 1) / SpawningConfig.ZombiesPerRing)
		local ringIndex = (index - 1) % SpawningConfig.ZombiesPerRing
		local angle = ringIndex / SpawningConfig.ZombiesPerRing * math.pi * 2
			+ ring * SpawningConfig.RingAngleOffset
		local radius = SpawningConfig.FirstRingRadius + ring * SpawningConfig.RingRadiusStep
		local spawnOffset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

		nextNetworkId += 1
		local entity = world:entity()
		world:set(entity, Position, rootPosition + spawnOffset)
		world:set(entity, Velocity, Vector3.zero)
		world:set(entity, TargetPlayer, player)
		world:set(entity, NetworkId, nextNetworkId)
		world:set(entity, ZombieTypeId, SpawningConfig.DefaultType)
		world:set(entity, DebugState, "NoReachableTarget")
		world:set(entity, NextAttackTime, 0)
		world:set(entity, Health, ZombieConfig.Types[SpawningConfig.DefaultType].MaxHealth)
		world:set(entity, SpawnOwner, player)
		table.insert(entities, entity)

		Lifecycle:FireAllClients(
			NetworkingConfig.WorldRevision,
			ZombieProtocol.encodeSpawn(getZombieState(entity))
		)
	end

	entitiesByPlayer[player] = entities
end

local function removeEntityFromSpawnOwner(entity: number, player: Player)
	local entities = entitiesByPlayer[player]
	if entities == nil then
		return
	end

	local entityIndex = table.find(entities, entity)
	if entityIndex ~= nil then
		table.remove(entities, entityIndex)
	end
end

local function despawnZombie(entity: number)
	local netId = assert(world:get(entity, NetworkId))
	local spawnOwner = world:get(entity, SpawnOwner)
	if spawnOwner ~= nil then
		removeEntityFromSpawnOwner(entity, spawnOwner)
	end

	world:delete(entity)
	Lifecycle:FireAllClients(NetworkingConfig.WorldRevision, ZombieProtocol.encodeDespawn(netId))
end

local function despawnZombiesForPlayer(player: Player)
	local entities = entitiesByPlayer[player]
	if entities == nil then
		return
	end

	for _, entity in table.clone(entities) do
		despawnZombie(entity)
	end

	entitiesByPlayer[player] = nil
	navigationGraph:RemoveTarget(player)
end

local function DamageInCylinder(
	center: Vector3,
	radius: number,
	maxVerticalDistance: number,
	damage: number
): number
	local hitCount = 0
	local destroyedEntities = {}

	for entity, position, health, zombieTypeId in world:query(Position, Health, ZombieTypeId) do
		if math.abs(position.Y - center.Y) > maxVerticalDistance then
			continue
		end

		local offset = position - center
		local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)
		local zombieType = ZombieConfig.Types[zombieTypeId]
		if horizontalOffset.Magnitude > radius + zombieType.HitRadius then
			continue
		end

		hitCount += 1
		local remainingHealth = health - damage
		if remainingHealth <= 0 then
			table.insert(destroyedEntities, entity)
		else
			world:set(entity, Health, remainingHealth)
		end
	end

	for _, entity in destroyedEntities do
		despawnZombie(entity)
	end

	return hitCount
end

local function getSpatialCellCoordinates(position: Vector3): (number, number)
	return math.floor(position.X / SeparationConfig.CellSize),
		math.floor(position.Z / SeparationConfig.CellSize)
end

local function buildZombieSpatialHash(): ZombieSpatialHash
	local spatialHash: ZombieSpatialHash = {}

	for _, position, netId, zombieTypeId in world:query(Position, NetworkId, ZombieTypeId) do
		local cellX, cellZ = getSpatialCellCoordinates(position)
		local column = spatialHash[cellX]
		if column == nil then
			column = {}
			spatialHash[cellX] = column
		end

		local cell = column[cellZ]
		if cell == nil then
			cell = {}
			column[cellZ] = cell
		end

		local zombieType = ZombieConfig.Types[zombieTypeId]
		table.insert(cell, {
			netId = netId,
			position = position,
			separationRadius = zombieType.SeparationRadius,
		})
	end

	return spatialHash
end

local function getOverlapDirection(firstNetId: number, secondNetId: number): Vector3
	local lowerNetId = math.min(firstNetId, secondNetId)
	local higherNetId = math.max(firstNetId, secondNetId)
	local angle = (lowerNetId * 73856093 + higherNetId * 19349663) % 6283 / 1000
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))

	return if firstNetId == lowerNetId then direction else -direction
end

local function getSeparationDirection(
	position: Vector3,
	netId: number,
	separationRadius: number,
	spatialHash: ZombieSpatialHash
): Vector3
	local cellX, cellZ = getSpatialCellCoordinates(position)
	local searchRadius =
		math.ceil((separationRadius + maximumSeparationRadius) / SeparationConfig.CellSize)
	local separationDirection = Vector3.zero

	for offsetX = -searchRadius, searchRadius do
		local column = spatialHash[cellX + offsetX]
		if column == nil then
			continue
		end

		for offsetZ = -searchRadius, searchRadius do
			local cell = column[cellZ + offsetZ]
			if cell == nil then
				continue
			end

			for _, otherZombie in cell do
				if otherZombie.netId == netId then
					continue
				end

				local offset = position - otherZombie.position
				local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)
				local distance = horizontalOffset.Magnitude
				local desiredDistance = separationRadius + otherZombie.separationRadius
				if distance >= desiredDistance then
					continue
				end

				local direction = if distance > 0.001
					then horizontalOffset / distance
					else getOverlapDirection(netId, otherZombie.netId)
				local weight = (desiredDistance - distance) / desiredDistance
				separationDirection += direction * weight
			end
		end
	end

	return separationDirection
end

local function tryAttackPlayer(
	entity: number,
	position: Vector3,
	target: NavigationGraph.PlayerTarget,
	zombieType: ZombieConfig.ZombieType,
	serverTime: number
): boolean
	if
		target.humanoid.Health <= 0
		or (target.position - position).Magnitude > zombieType.AttackRange
	then
		return false
	end

	local nextAttackTime = assert(world:get(entity, NextAttackTime))
	if serverTime >= nextAttackTime then
		target.humanoid:TakeDamage(zombieType.AttackDamage)
		world:set(entity, NextAttackTime, serverTime + zombieType.AttackCooldown)
	end

	return true
end

local function simulateZombies()
	debug.profilebegin "ZombieWorld.Simulate"
	simulationTick += 1
	local hasNavigationNodes = navigationGraph:HasNodes()
	local playerTargets = collectPlayerTargets()
	local spatialHash = if SeparationConfig.Enabled then buildZombieSpatialHash() else nil
	local serverTime = Workspace:GetServerTimeNow()

	for entity, position, _, netId, zombieTypeId in
		world:query(Position, Velocity, NetworkId, ZombieTypeId)
	do
		local zombieType = ZombieConfig.Types[zombieTypeId]
		local target = if hasNavigationNodes
			then navigationGraph:FindClosestReachableTarget(position, playerTargets)
			else findClosestTarget(position, playerTargets)
		if target == nil then
			world:set(entity, Velocity, Vector3.zero)
			world:set(entity, DebugState, "NoReachableTarget")
			continue
		end
		world:set(entity, TargetPlayer, target.player)

		local steeringTarget: Vector3?
		local isFinalTarget: boolean
		if hasNavigationNodes then
			steeringTarget, isFinalTarget =
				navigationGraph:GetSteeringTarget(target.player, position, target.position)
		else
			steeringTarget = target.position
			isFinalTarget = true
		end
		if steeringTarget == nil then
			world:set(entity, Velocity, Vector3.zero)
			world:set(entity, DebugState, "NoSteeringTarget")
			continue
		end

		local isAttacking = if isFinalTarget
			then tryAttackPlayer(entity, position, target, zombieType, serverTime)
			else false
		local offset = steeringTarget - position
		local movementOffset = Vector3.new(offset.X, 0, offset.Z)
		local distance = movementOffset.Magnitude
		local stopDistance = if isFinalTarget then zombieType.StopDistance else 0
		local movementVelocity = Vector3.zero
		if distance > stopDistance then
			local movementSpeed =
				math.min(zombieType.Speed, (distance - stopDistance) / SimulationConfig.Step)
			movementVelocity = movementOffset.Unit * movementSpeed
		end

		local separationVelocity = Vector3.zero
		if spatialHash ~= nil then
			local separationDirection =
				getSeparationDirection(position, netId, zombieType.SeparationRadius, spatialHash)
			separationVelocity = separationDirection * zombieType.Speed * SeparationConfig.Strength
		end

		local velocity = movementVelocity + separationVelocity
		if velocity.Magnitude > zombieType.Speed then
			velocity = velocity.Unit * zombieType.Speed
		end

		if velocity.Magnitude <= 0.001 then
			world:set(entity, Velocity, Vector3.zero)
			world:set(entity, DebugState, if isAttacking then "Attacking" else "FinalStop")
			continue
		end

		world:set(entity, Velocity, velocity)
		world:set(entity, DebugState, if isAttacking then "Attacking" else "Moving")
		world:set(entity, Position, position + velocity * SimulationConfig.Step)
	end

	debug.profileend()
end

local function groundZombies()
	debug.profilebegin "ZombieWorld.Ground"

	for entity, position, zombieTypeId in world:query(Position, ZombieTypeId) do
		local zombieType = ZombieConfig.Types[zombieTypeId]
		local rayOrigin = position + Vector3.yAxis * GroundingConfig.RayHeight
		local result = zombieRaycaster:Cast(rayOrigin, -Vector3.yAxis * GroundingConfig.RayDistance)
		if result ~= nil then
			world:set(
				entity,
				Position,
				Vector3.new(position.X, result.Position.Y + zombieType.GroundOffset, position.Z)
			)
		end
	end

	debug.profileend()
end

local function sendSnapshots()
	debug.profilebegin "ZombieWorld.Snapshot"
	local zombies = collectZombieStates()
	local debugZombies = if DebugConfig.ShowZombieStateLabels
		then collectZombieDebugStates()
		else nil
	local serverTime = Workspace:GetServerTimeNow()

	for startIndex = 1, #zombies, NetworkingConfig.MaxZombiesPerSnapshot do
		local endIndex = math.min(startIndex + NetworkingConfig.MaxZombiesPerSnapshot - 1, #zombies)
		local snapshotZombies = table.move(zombies, startIndex, endIndex, 1, {})
		local state = ZombieProtocol.encodeStates(snapshotZombies)

		for _, player in Players:GetPlayers() do
			Snapshot:FireClient(
				player,
				NetworkingConfig.WorldRevision,
				simulationTick,
				serverTime,
				state
			)
		end

		if debugZombies ~= nil then
			local snapshotDebugZombies = table.move(debugZombies, startIndex, endIndex, 1, {})
			local debugState = ZombieProtocol.encodeDebugStates(snapshotDebugZombies)

			for _, player in Players:GetPlayers() do
				DebugSnapshot:FireClient(
					player,
					NetworkingConfig.WorldRevision,
					simulationTick,
					debugState
				)
			end
		end
	end

	debug.profileend()
end

local function startPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		spawnZombiesForPlayer(player)
	end)

	if player.Character ~= nil then
		spawnZombiesForPlayer(player)
	end
end

local function Start()
	RequestInitialState:OnServer(function(player)
		sendInitialState(player)
	end)

	Players.PlayerAdded:Connect(startPlayer)
	Players.PlayerRemoving:Connect(despawnZombiesForPlayer)

	for _, player in Players:GetPlayers() do
		startPlayer(player)
	end

	RunService.Heartbeat:Connect(function(deltaTime)
		groundZombies()
		simulationAccumulator += deltaTime
		snapshotAccumulator += deltaTime

		while simulationAccumulator >= SimulationConfig.Step do
			simulationAccumulator -= SimulationConfig.Step
			simulateZombies()
		end

		while snapshotAccumulator >= NetworkingConfig.SnapshotInterval do
			snapshotAccumulator -= NetworkingConfig.SnapshotInterval
			sendSnapshots()
		end
	end)
end

return table.freeze {
	Start = Start,
	DamageInCylinder = DamageInCylinder,
}
