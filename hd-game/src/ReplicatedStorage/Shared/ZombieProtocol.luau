--!strict

export type ZombieState = {
	netId: number,
	position: Vector3,
	velocity: Vector3,
}

export type ZombieDebugStateKind =
	"Moving"
	| "NoReachableTarget"
	| "NoSteeringTarget"
	| "FinalStop"
	| "Attacking"

export type ZombieDebugState = {
	netId: number,
	kind: ZombieDebugStateKind,
}

export type LifecycleOperation = {
	kind: "Spawn" | "Despawn",
	state: ZombieState?,
	netId: number,
}

local POSITION_SCALE = 16
local STATE_HEADER_SIZE = 2
local STATE_RECORD_SIZE = 12
local DEBUG_STATE_HEADER_SIZE = 2
local DEBUG_STATE_RECORD_SIZE = 3
local LIFECYCLE_SPAWN = 1
local LIFECYCLE_DESPAWN = 2
local DEBUG_STATE_MOVING = 1
local DEBUG_STATE_NO_REACHABLE_TARGET = 2
local DEBUG_STATE_NO_STEERING_TARGET = 3
local DEBUG_STATE_FINAL_STOP = 4
local DEBUG_STATE_ATTACKING = 5

local function quantize(value: number): number
	return math.round(value * POSITION_SCALE)
end

local function dequantize(value: number): number
	return value / POSITION_SCALE
end

local function writeState(state: buffer, offset: number, zombie: ZombieState)
	buffer.writeu16(state, offset, zombie.netId)
	buffer.writei16(state, offset + 2, quantize(zombie.position.X))
	buffer.writei16(state, offset + 4, quantize(zombie.position.Y))
	buffer.writei16(state, offset + 6, quantize(zombie.position.Z))
	buffer.writei16(state, offset + 8, quantize(zombie.velocity.X))
	buffer.writei16(state, offset + 10, quantize(zombie.velocity.Z))
end

local function readState(state: buffer, offset: number): ZombieState
	return {
		netId = buffer.readu16(state, offset),
		position = Vector3.new(
			dequantize(buffer.readi16(state, offset + 2)),
			dequantize(buffer.readi16(state, offset + 4)),
			dequantize(buffer.readi16(state, offset + 6))
		),
		velocity = Vector3.new(
			dequantize(buffer.readi16(state, offset + 8)),
			0,
			dequantize(buffer.readi16(state, offset + 10))
		),
	}
end

local function encodeStates(zombies: { ZombieState }): buffer
	local state = buffer.create(STATE_HEADER_SIZE + #zombies * STATE_RECORD_SIZE)
	buffer.writeu16(state, 0, #zombies)

	for index, zombie in zombies do
		writeState(state, STATE_HEADER_SIZE + (index - 1) * STATE_RECORD_SIZE, zombie)
	end

	return state
end

local function forEachState(state: buffer, callback: (ZombieState) -> ())
	local count = buffer.readu16(state, 0)

	for index = 0, count - 1 do
		callback(readState(state, STATE_HEADER_SIZE + index * STATE_RECORD_SIZE))
	end
end

local function encodeDebugStateKind(kind: ZombieDebugStateKind): number
	if kind == "Moving" then
		return DEBUG_STATE_MOVING
	end

	if kind == "NoReachableTarget" then
		return DEBUG_STATE_NO_REACHABLE_TARGET
	end

	if kind == "NoSteeringTarget" then
		return DEBUG_STATE_NO_STEERING_TARGET
	end

	if kind == "Attacking" then
		return DEBUG_STATE_ATTACKING
	end

	return DEBUG_STATE_FINAL_STOP
end

local function decodeDebugStateKind(value: number): ZombieDebugStateKind
	if value == DEBUG_STATE_MOVING then
		return "Moving"
	end

	if value == DEBUG_STATE_NO_REACHABLE_TARGET then
		return "NoReachableTarget"
	end

	if value == DEBUG_STATE_NO_STEERING_TARGET then
		return "NoSteeringTarget"
	end

	if value == DEBUG_STATE_ATTACKING then
		return "Attacking"
	end

	assert(value == DEBUG_STATE_FINAL_STOP, "Unknown zombie debug state")
	return "FinalStop"
end

local function encodeDebugStates(zombies: { ZombieDebugState }): buffer
	local state = buffer.create(DEBUG_STATE_HEADER_SIZE + #zombies * DEBUG_STATE_RECORD_SIZE)
	buffer.writeu16(state, 0, #zombies)

	for index, zombie in zombies do
		local offset = DEBUG_STATE_HEADER_SIZE + (index - 1) * DEBUG_STATE_RECORD_SIZE
		buffer.writeu16(state, offset, zombie.netId)
		buffer.writeu8(state, offset + 2, encodeDebugStateKind(zombie.kind))
	end

	return state
end

local function forEachDebugState(state: buffer, callback: (ZombieDebugState) -> ())
	local count = buffer.readu16(state, 0)

	for index = 0, count - 1 do
		local offset = DEBUG_STATE_HEADER_SIZE + index * DEBUG_STATE_RECORD_SIZE
		callback {
			netId = buffer.readu16(state, offset),
			kind = decodeDebugStateKind(buffer.readu8(state, offset + 2)),
		}
	end
end

local function encodeSpawn(zombie: ZombieState): buffer
	local operation = buffer.create(1 + STATE_RECORD_SIZE)
	buffer.writeu8(operation, 0, LIFECYCLE_SPAWN)
	writeState(operation, 1, zombie)
	return operation
end

local function encodeDespawn(netId: number): buffer
	local operation = buffer.create(3)
	buffer.writeu8(operation, 0, LIFECYCLE_DESPAWN)
	buffer.writeu16(operation, 1, netId)
	return operation
end

local function decodeLifecycle(operation: buffer): LifecycleOperation
	local kind = buffer.readu8(operation, 0)

	if kind == LIFECYCLE_SPAWN then
		local state = readState(operation, 1)
		return {
			kind = "Spawn",
			state = state,
			netId = state.netId,
		}
	end

	assert(kind == LIFECYCLE_DESPAWN, "Unknown zombie lifecycle operation")
	return {
		kind = "Despawn",
		netId = buffer.readu16(operation, 1),
	}
end

return table.freeze {
	encodeStates = encodeStates,
	forEachState = forEachState,
	encodeDebugStates = encodeDebugStates,
	forEachDebugState = forEachDebugState,
	encodeSpawn = encodeSpawn,
	encodeDespawn = encodeDespawn,
	decodeLifecycle = decodeLifecycle,
}
