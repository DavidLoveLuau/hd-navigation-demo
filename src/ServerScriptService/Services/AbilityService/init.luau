--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local StarRemote = require(game.ReplicatedStorage.Packages.StarRemote)
local AbilityConfig = require(game.ReplicatedStorage.Shared.GameData.AbilityConfig)
local ZombieService = require(script.Parent.ZombieService)

local RequestShockwave = StarRemote.Ability_RequestShockwave
local ShockwaveEffect = StarRemote.Ability_ShockwaveEffect
local RequestMeteor = StarRemote.Ability_RequestMeteor
local MeteorCast = StarRemote.Ability_MeteorCast
local MeteorImpact = StarRemote.Ability_MeteorImpact
local ShockwaveConfig = AbilityConfig.Shockwave
local MeteorConfig = AbilityConfig.Meteor

local nextShockwaveTimeByPlayer: { [Player]: number } = {}
local nextMeteorTimeByPlayer: { [Player]: number } = {}
-- selene: allow(incorrect_standard_library_use)
local mathIsFinite = math.isfinite

local function getShockwaveOrigin(player: Player): Vector3?
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

	return root.Position
end

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and mathIsFinite(value)
end

local function isFiniteVector3(value: any): boolean
	return typeof(value) == "Vector3"
		and isFiniteNumber(value.X)
		and isFiniteNumber(value.Y)
		and isFiniteNumber(value.Z)
end

local function getMeteorImpactPosition(player: Player, requestedPosition: Vector3): Vector3?
	if isFiniteVector3(requestedPosition) == false then
		return nil
	end

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

	local horizontalOffset =
		Vector3.new(requestedPosition.X - root.Position.X, 0, requestedPosition.Z - root.Position.Z)
	if horizontalOffset.Magnitude > MeteorConfig.MaxCastDistance then
		return nil
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	local rayOrigin = Vector3.new(
		requestedPosition.X,
		root.Position.Y + MeteorConfig.TargetRayHeight,
		requestedPosition.Z
	)
	local raycastResult =
		Workspace:Raycast(rayOrigin, -Vector3.yAxis * MeteorConfig.TargetRayDistance, raycastParams)

	return if raycastResult ~= nil then raycastResult.Position else nil
end

local function Start()
	RequestShockwave:OnServerValidated(function(player: Player, castId: number)
		local serverTime = Workspace:GetServerTimeNow()
		local nextShockwaveTime = nextShockwaveTimeByPlayer[player] or 0
		if serverTime < nextShockwaveTime then
			return
		end

		local origin = getShockwaveOrigin(player)
		if origin == nil then
			return
		end

		nextShockwaveTimeByPlayer[player] = serverTime + ShockwaveConfig.Cooldown
		ZombieService.DamageInCylinder(
			origin,
			ShockwaveConfig.Radius,
			ShockwaveConfig.MaxVerticalDistance,
			ShockwaveConfig.Damage
		)
		ShockwaveEffect:FireAllClients(player.UserId, castId, origin, serverTime)
	end)

	RequestMeteor:OnServer(function(player: Player, castId: number, requestedPosition: Vector3)
		if isFiniteNumber(castId) == false then
			return
		end

		local serverTime = Workspace:GetServerTimeNow()
		local nextMeteorTime = nextMeteorTimeByPlayer[player] or 0
		if serverTime < nextMeteorTime then
			return
		end

		local impactPosition = getMeteorImpactPosition(player, requestedPosition)
		if impactPosition == nil then
			return
		end

		local impactTime = serverTime + MeteorConfig.FallDuration
		nextMeteorTimeByPlayer[player] = serverTime + MeteorConfig.Cooldown
		MeteorCast:FireAllClients(player.UserId, castId, impactPosition, serverTime, impactTime)

		task.delay(MeteorConfig.FallDuration, function()
			ZombieService.DamageInCylinder(
				impactPosition,
				MeteorConfig.DamageRadius,
				MeteorConfig.MaxVerticalDistance,
				MeteorConfig.Damage
			)
			MeteorImpact:FireAllClients(player.UserId, castId, impactPosition, impactTime)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		nextShockwaveTimeByPlayer[player] = nil
		nextMeteorTimeByPlayer[player] = nil
	end)
end

return table.freeze {
	Start = Start,
}
