const Players = game:GetService("Players")

const StarSignal = require(game.ReplicatedStorage.Packages.StarSignal)
const StarReplica = require(game.ServerScriptService.ServerPackages.StarReplica)
const ProfileStore = require(game.ServerScriptService.ServerPackages.Wally.ProfileStore)
const Template = require(script.Template)

export type ProfileData = typeof(Template)

type StoreProfile = {
	Data: ProfileData,
	OnSessionEnd: {
		Connect: (self: any, callback: () -> ()) -> RBXScriptConnection,
	},
	IsActive: (self: StoreProfile) -> boolean,
	Reconcile: (self: StoreProfile) -> (),
	EndSession: (self: StoreProfile) -> (),
	AddUserId: (self: StoreProfile, userId: number) -> (),
}

export type Profile = {
	read player: Player,
	read data: ProfileData,
	read replica: ReplicaServer<ProfileData>,
}

const store = ProfileStore.New("TheBestGame_PlayerData_v1", Template)
const profiles: { [Player]: Profile } = {}
const storeProfiles: { [Player]: StoreProfile } = {}
const loadingPlayers: { [Player]: boolean } = {}
export const OnProfileLoaded = StarSignal.newT<<(Player, Profile)>>() :: SSignal<(Player, Profile)>
export const OnProfileUnloaded = StarSignal.newT<<(Player, Profile)>>() :: SSignal<(Player, Profile)>

export function GetProfile(player: Player): Profile?
	return profiles[player]
end

export function WaitForProfile(player: Player, timeout: number?): Profile?
	const existingProfile = GetProfile(player)
	if existingProfile ~= nil then
		return existingProfile
	end

	const _, loadedProfile = OnProfileLoaded:WaitWithCheckAndTimeout(function(loadedPlayer: Player): boolean
		return loadedPlayer == player
	end, timeout or 120)

	return loadedProfile
end

const function UnloadProfile(player: Player, endSession: boolean)
	const profile = profiles[player]
	const storeProfile = storeProfiles[player]
	if profile == nil or storeProfile == nil then
		return
	end

	profiles[player] = nil
	storeProfiles[player] = nil
	profile.replica:Destroy()
	OnProfileUnloaded:Fire(player, profile)

	if endSession and storeProfile:IsActive() then
		storeProfile:EndSession()
	end
end

const function CreateClientConfig()
	return {
		setValidators = {
			["Settings.MusicVolume"] = function(_player: Player, value: unknown): number?
				if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
					return nil
				end

				return math.clamp(value, 0, 10)
			end,
			["Settings.MusicEnabled"] = function(_player: Player, value: unknown): boolean?
				return if type(value) == "boolean" then value else nil
			end,
		},
	}
end

const function LoadProfile(player: Player)
	if profiles[player] ~= nil or loadingPlayers[player] == true then
		return
	end

	loadingPlayers[player] = true
	const storeProfile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	loadingPlayers[player] = nil

	if storeProfile == nil then
		if player.Parent == Players then
			player:Kick "Your data could not be loaded. Please rejoin."
		end
		return
	end

	storeProfile:AddUserId(player.UserId)
	storeProfile:Reconcile()

	if player.Parent ~= Players or storeProfile:IsActive() == false then
		storeProfile:EndSession()
		return
	end

	const replica = StarReplica.new(`Profile_{player.UserId}`, storeProfile.Data, {
		players = { player },
		client = CreateClientConfig(),
	}):Initialize "subscribers"
	const profile = {
		player = player,
		data = storeProfile.Data,
		replica = replica,
	} :: Profile

	profiles[player] = profile
	storeProfiles[player] = storeProfile
	storeProfile.OnSessionEnd:Connect(function()
		if profiles[player] ~= profile then
			return
		end

		UnloadProfile(player, false)
		if player.Parent == Players then
			player:Kick "Your data session ended. Please rejoin."
		end
	end)

	OnProfileLoaded:Fire(player, profile)
end

Players.PlayerAdded:Connect(LoadProfile)
Players.PlayerRemoving:Connect(function(player: Player)
	UnloadProfile(player, true)
end)

for _, player in Players:GetPlayers() do
	task.spawn(LoadProfile, player)
end

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		UnloadProfile(player, true)
	end
end)
