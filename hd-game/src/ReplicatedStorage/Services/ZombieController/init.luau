--!strict

const RunService = game:GetService("RunService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Workspace = game:GetService("Workspace")

const StarRemote = require "@game/ReplicatedStorage/Packages/StarRemote"
const getServerTimeNow = require "@game/ReplicatedStorage/Packages/StarUtils/getServerTimeNow"
const ZombieProtocol = require "@game/ReplicatedStorage/Shared/ZombieProtocol"

const RequestInitialState = StarRemote.ZombieWorld_RequestInitialState
const Initialize = StarRemote.ZombieWorld_Initialize
const Lifecycle = StarRemote.ZombieWorld_Lifecycle
const Snapshot = StarRemote.ZombieWorld_Snapshot
const DebugSnapshot = StarRemote.ZombieWorld_DebugSnapshot
const ZombieTemplate = ReplicatedStorage.Assets.Zombies.Template

const INTERPOLATION_DELAY = 0.15

type TimedState = {
	position: Vector3,
	velocity: Vector3,
	serverTime: number,
}

type ZombieVisual = {
	model: Model,
	previous: TimedState,
	current: TimedState,
	lastTick: number,
	lastDebugTick: number,
	debugLabel: TextLabel?,
}

const visuals: { [number]: ZombieVisual } = {}
local worldRevision: number? = nil
local visualsFolder: Folder? = nil

const DEBUG_STATE_COLORS: { [ZombieProtocol.ZombieDebugStateKind]: Color3 } = {
	Moving = Color3.fromRGB(89, 255, 132),
	NoReachableTarget = Color3.fromRGB(255, 82, 82),
	NoSteeringTarget = Color3.fromRGB(255, 170, 51),
	FinalStop = Color3.fromRGB(255, 226, 102),
	Attacking = Color3.fromRGB(255, 112, 72),
}

const function getVisualsFolder(): Folder
	if visualsFolder ~= nil then
		return visualsFolder
	end

	const folder = Instance.new "Folder"
	folder.Name = "ClientZombieVisuals"
	folder.Parent = Workspace
	visualsFolder = folder
	return folder
end

const function removeVisual(netId: number)
	const visual = visuals[netId]
	if visual == nil then
		return
	end

	visual.model:Destroy()
	visuals[netId] = nil
end

const function clearVisuals()
	for netId in visuals do
		removeVisual(netId)
	end
end

const function createDebugLabel(model: Model): TextLabel?
	const adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if adornee == nil then
		return nil
	end

	const billboard = Instance.new "BillboardGui"
	billboard.Name = "ZombieDebugState"
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(180, 24)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.Parent = model

	const label = Instance.new "TextLabel"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = billboard

	return label
end

const function createVisual(zombie: ZombieProtocol.ZombieState, serverTime: number): ZombieVisual
	const state = {
		position = zombie.position,
		velocity = zombie.velocity,
		serverTime = serverTime,
	}
	const model = ZombieTemplate:Clone()
	model.Name = `Zombie_{zombie.netId}`
	model:PivotTo(CFrame.new(zombie.position))
	model.Parent = getVisualsFolder()

	const visual = {
		model = model,
		previous = state,
		current = state,
		lastTick = 0,
		lastDebugTick = 0,
		debugLabel = nil,
	}
	visuals[zombie.netId] = visual
	return visual
end

const function updateVisual(
	zombie: ZombieProtocol.ZombieState,
	serverTick: number,
	serverTime: number
)
	local visual = visuals[zombie.netId]
	if visual == nil then
		visual = createVisual(zombie, serverTime)
	end

	if serverTick <= visual.lastTick then
		return
	end

	visual.previous = visual.current
	visual.current = {
		position = zombie.position,
		velocity = zombie.velocity,
		serverTime = serverTime,
	}
	visual.lastTick = serverTick
end

const function updateDebugState(zombie: ZombieProtocol.ZombieDebugState, serverTick: number)
	const visual = visuals[zombie.netId]
	if visual == nil or serverTick <= visual.lastDebugTick then
		return
	end

	visual.lastDebugTick = serverTick
	if visual.debugLabel == nil then
		visual.debugLabel = createDebugLabel(visual.model)
	end

	const label = visual.debugLabel
	if label == nil then
		return
	end

	label.Text = zombie.kind
	label.TextColor3 = DEBUG_STATE_COLORS[zombie.kind]
end

const function onInitialize(revision: number, serverTime: number, state: buffer)
	worldRevision = revision
	clearVisuals()

	ZombieProtocol.forEachState(state, function(zombie)
		createVisual(zombie, serverTime)
	end)
end

const function onLifecycle(revision: number, operation: buffer)
	if worldRevision ~= revision then
		return
	end

	const lifecycle = ZombieProtocol.decodeLifecycle(operation)
	if lifecycle.kind == "Spawn" then
		createVisual(
			assert(lifecycle.state, "Spawn lifecycle operation requires a zombie state"),
			getServerTimeNow()
		)
	else
		removeVisual(lifecycle.netId)
	end
end

const function onSnapshot(revision: number, serverTick: number, serverTime: number, state: buffer)
	if worldRevision ~= revision then
		return
	end

	ZombieProtocol.forEachState(state, function(zombie)
		updateVisual(zombie, serverTick, serverTime)
	end)
end

const function onDebugSnapshot(revision: number, serverTick: number, state: buffer)
	if worldRevision ~= revision then
		return
	end

	ZombieProtocol.forEachDebugState(state, function(zombie)
		updateDebugState(zombie, serverTick)
	end)
end

const function renderVisuals()
	debug.profilebegin "ZombieWorld.Render"
	const renderTime = getServerTimeNow() - INTERPOLATION_DELAY

	for _, visual in visuals do
		const previous = visual.previous
		const current = visual.current
		const duration = current.serverTime - previous.serverTime
		local position: Vector3
		local velocity: Vector3

		if duration <= 0 then
			position = current.position
			velocity = current.velocity
		elseif renderTime <= current.serverTime then
			const alpha = math.clamp((renderTime - previous.serverTime) / duration, 0, 1)
			position = previous.position:Lerp(current.position, alpha)
			velocity = previous.velocity:Lerp(current.velocity, alpha)
		else
			const extrapolation = math.min(renderTime - current.serverTime, 0.2)
			position = current.position + current.velocity * extrapolation
			velocity = current.velocity
		end

		if velocity.Magnitude > 0 then
			visual.model:PivotTo(CFrame.lookAt(position, position + velocity))
		else
			visual.model:PivotTo(CFrame.new(position))
		end
	end

	debug.profileend()
end

const function Start()
	Initialize:OnClient(onInitialize)
	Lifecycle:OnClient(onLifecycle)
	Snapshot:OnClient(onSnapshot)
	DebugSnapshot:OnClient(onDebugSnapshot)
	RunService.RenderStepped:Connect(renderVisuals)
	RequestInitialState:FireServer()
end

return table.freeze {
	Start = Start,
}
