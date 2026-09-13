--!strict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local StarEmmiter = require "@game/ReplicatedStorage/Packages/StarEmmiter"
local StarRemote = require "@game/ReplicatedStorage/Packages/StarRemote"
local getServerTimeNow = require "@game/ReplicatedStorage/Packages/StarUtils/getServerTimeNow"
local AbilityConfig = require "@game/ReplicatedStorage/Shared/GameData/AbilityConfig"

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local RequestShockwave = StarRemote.Ability_RequestShockwave
local ShockwaveEffect = StarRemote.Ability_ShockwaveEffect
local RequestMeteor = StarRemote.Ability_RequestMeteor
local MeteorCast = StarRemote.Ability_MeteorCast
local MeteorImpact = StarRemote.Ability_MeteorImpact
local ShockwaveConfig = AbilityConfig.Shockwave
local MeteorConfig = AbilityConfig.Meteor
local MeteorAssets = ReplicatedStorage.Assets.Abilities.Meteor
local MeteorTemplate = MeteorAssets.Meteor :: Model
local ExplosionTemplate = MeteorAssets.ExplosionVFX :: Model

local nextShockwaveTime = 0
local nextMeteorTime = 0
local nextCastId = 0
local predictedCastIds: { [number]: boolean } = {}
local effectsFolder: Folder? = nil
local completedMeteorCastKeys: { [string]: boolean } = {}

type MeteorVisual = {
	indicator: Part,
	meteor: Model?,
	updateConnection: RBXScriptConnection?,
}

local meteorVisualsByCastKey: { [string]: MeteorVisual } = {}

local function getEffectsFolder(): Folder
	if effectsFolder ~= nil then
		return effectsFolder
	end

	local folder = Instance.new "Folder"
	folder.Name = "ClientAbilityEffects"
	folder.Parent = Workspace
	effectsFolder = folder
	return folder
end

local function getRootPosition(): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end

	local root = character:FindFirstChild "HumanoidRootPart"
	if root == nil or root:IsA "BasePart" == false then
		return nil
	end

	return root.Position
end

local function getMeteorCastKey(casterUserId: number, castId: number): string
	return `{casterUserId}:{castId}`
end

local function createMeteorIndicator(impactPosition: Vector3): Part
	local indicator = Instance.new "Part"
	indicator.Name = "MeteorImpactWarning"
	indicator.Shape = Enum.PartType.Cylinder
	indicator.Size = Vector3.new(0.15, MeteorConfig.DamageRadius * 2, MeteorConfig.DamageRadius * 2)
	indicator.CFrame = CFrame.new(impactPosition + Vector3.yAxis * 0.1)
		* CFrame.Angles(0, 0, math.pi / 2)
	indicator.Anchored = true
	indicator.CanCollide = false
	indicator.CanTouch = false
	indicator.CanQuery = false
	indicator.Material = Enum.Material.Neon
	indicator.Color = MeteorConfig.IndicatorColor
	indicator.Transparency = MeteorConfig.IndicatorTransparency
	indicator.Parent = getEffectsFolder()
	return indicator
end

local function destroyMeteorVisual(castKey: string)
	local visual = meteorVisualsByCastKey[castKey]
	if visual == nil then
		return
	end

	if visual.updateConnection ~= nil then
		visual.updateConnection:Disconnect()
	end
	visual.indicator:Destroy()
	if visual.meteor ~= nil then
		visual.meteor:Destroy()
	end
	meteorVisualsByCastKey[castKey] = nil
end

local function prepareMeteorVisual(meteor: Model)
	for _, descendant in meteor:GetDescendants() do
		if descendant:IsA "BasePart" then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

local function createMeteorCastVisual(
	casterUserId: number,
	castId: number,
	impactPosition: Vector3,
	castServerTime: number,
	impactServerTime: number
)
	local castKey = getMeteorCastKey(casterUserId, castId)
	if completedMeteorCastKeys[castKey] then
		return
	end

	destroyMeteorVisual(castKey)

	local meteor = MeteorTemplate:Clone()
	prepareMeteorVisual(meteor)
	meteor.Name = "Meteor"
	meteor.Parent = getEffectsFolder()

	local visual = {
		indicator = createMeteorIndicator(impactPosition),
		meteor = meteor,
		updateConnection = nil,
	}
	meteorVisualsByCastKey[castKey] = visual

	local startPosition = impactPosition + Vector3.yAxis * MeteorConfig.StartHeight
	local fallDuration = impactServerTime - castServerTime
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.clamp((getServerTimeNow() - castServerTime) / fallDuration, 0, 1)
		if alpha >= 1 then
			meteor:PivotTo(CFrame.new(impactPosition))
			connection:Disconnect()
			visual.updateConnection = nil
			return
		end

		local position = startPosition:Lerp(impactPosition, alpha * alpha)
		meteor:PivotTo(CFrame.lookAt(position, impactPosition))
	end)
	visual.updateConnection = connection
end

local function createMeteorPrediction(castId: number, requestedPosition: Vector3)
	local castKey = getMeteorCastKey(player.UserId, castId)
	destroyMeteorVisual(castKey)

	local visual = {
		indicator = createMeteorIndicator(requestedPosition),
		meteor = nil,
		updateConnection = nil,
	}
	meteorVisualsByCastKey[castKey] = visual

	task.delay(MeteorConfig.FallDuration + 1, function()
		if meteorVisualsByCastKey[castKey] == visual then
			destroyMeteorVisual(castKey)
		end
	end)
end

local function playMeteorImpact(casterUserId: number, castId: number, impactPosition: Vector3)
	local castKey = getMeteorCastKey(casterUserId, castId)
	completedMeteorCastKeys[castKey] = true
	destroyMeteorVisual(castKey)

	local explosion = ExplosionTemplate:Clone()
	explosion.Name = "MeteorExplosion"
	explosion:PivotTo(CFrame.new(impactPosition))
	explosion.Parent = getEffectsFolder()
	StarEmmiter.EmitInstance(explosion)
	Debris:AddItem(explosion, MeteorConfig.ExplosionLifetime)

	task.delay(MeteorConfig.ExplosionLifetime, function()
		completedMeteorCastKeys[castKey] = nil
	end)
end

local function playShockwaveEffect(origin: Vector3, startedAt: number)
	local elapsed = getServerTimeNow() - startedAt
	if elapsed >= ShockwaveConfig.EffectDuration then
		return
	end

	local wave = Instance.new "Part"
	wave.Name = "Shockwave"
	wave.Shape = Enum.PartType.Cylinder
	wave.Anchored = true
	wave.CanCollide = false
	wave.CanTouch = false
	wave.CanQuery = false
	wave.Material = Enum.Material.Neon
	wave.Color = ShockwaveConfig.EffectColor
	wave.Transparency = 0.15
	wave.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.pi / 2)
	wave.Parent = getEffectsFolder()

	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local alpha =
			math.clamp((getServerTimeNow() - startedAt) / ShockwaveConfig.EffectDuration, 0, 1)
		local easedAlpha = 1 - (1 - alpha) ^ 3
		local diameter = math.max(0.1, ShockwaveConfig.Radius * 2 * easedAlpha)
		wave.Size = Vector3.new(0.25, diameter, diameter)
		wave.Transparency = 0.15 + alpha * 0.85

		if alpha >= 1 then
			connection:Disconnect()
			wave:Destroy()
		end
	end)
end

local function requestShockwave()
	local serverTime = getServerTimeNow()
	if serverTime < nextShockwaveTime then
		return
	end

	local origin = getRootPosition()
	if origin == nil then
		return
	end

	nextShockwaveTime = serverTime + ShockwaveConfig.Cooldown
	nextCastId += 1
	local castId = nextCastId
	predictedCastIds[castId] = true
	playShockwaveEffect(origin, serverTime)
	RequestShockwave:FireServer(castId)

	task.delay(ShockwaveConfig.EffectDuration + 1, function()
		predictedCastIds[castId] = nil
	end)
end

local function requestMeteor()
	local serverTime = getServerTimeNow()
	if serverTime < nextMeteorTime then
		return
	end

	local rootPosition = getRootPosition()
	if rootPosition == nil then
		return
	end

	local requestedPosition = mouse.Hit.Position
	local horizontalOffset =
		Vector3.new(requestedPosition.X - rootPosition.X, 0, requestedPosition.Z - rootPosition.Z)
	if horizontalOffset.Magnitude > MeteorConfig.MaxCastDistance then
		return
	end

	nextMeteorTime = serverTime + MeteorConfig.Cooldown
	nextCastId += 1
	local castId = nextCastId
	createMeteorPrediction(castId, requestedPosition)
	RequestMeteor:FireServer(castId, requestedPosition)
end

local function Start()
	ShockwaveEffect:OnClient(
		function(casterUserId: number, castId: number, origin: Vector3, serverTime: number)
			if casterUserId == player.UserId and predictedCastIds[castId] then
				predictedCastIds[castId] = nil
				return
			end

			playShockwaveEffect(origin, serverTime)
		end
	)
	MeteorCast:OnClient(
		function(
			casterUserId: number,
			castId: number,
			impactPosition: Vector3,
			castServerTime: number,
			impactServerTime: number
		)
			createMeteorCastVisual(
				casterUserId,
				castId,
				impactPosition,
				castServerTime,
				impactServerTime
			)
		end
	)
	MeteorImpact:OnClient(
		function(
			casterUserId: number,
			castId: number,
			impactPosition: Vector3,
			_impactServerTime: number
		)
			playMeteorImpact(casterUserId, castId, impactPosition)
		end
	)

	UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent or UserInputService:GetFocusedTextBox() ~= nil then
			return
		end

		if input.KeyCode == ShockwaveConfig.KeyCode then
			requestShockwave()
		elseif input.KeyCode == MeteorConfig.KeyCode then
			requestMeteor()
		end
	end)
end

return table.freeze {
	Start = Start,
}
