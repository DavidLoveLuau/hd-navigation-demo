--!strict

--[[
	StarRemote: advanced remote-event library
	
	Version: 1.5.0
	Author: @Davidhello9
]]

local RunService = game.RunService :: RunService
local Is_Server = RunService:IsServer()
local StarRateLimiter = require(script.Parent.RateLimiter)

--[[ Types ]]
--

type Remotes = RemoteEvent | UnreliableRemoteEvent

--[[ Constants ]]
--
local _Remotes: { [string]: RemoteClass } = {}
local _Functions: { [string]: FunctionClass } = {}
local _Folder: Folder
do
	const name = "__Dev__StarRemotes__"
	const parent = game.ReplicatedStorage

	if Is_Server then
		_Folder = Instance.new "Folder"
		_Folder.Name = name
		_Folder.Parent = parent
	else
		_Folder = parent:WaitForChild(name, 60) :: Folder
		assert(_Folder, "Any Error while waiting for folder.")
	end
end

--[[ Private ]]
--

local function GetOrCreateFunction(name: string): RemoteFunction
	local remote = _Folder:FindFirstChild(name) :: RemoteFunction

	if not remote then
		if Is_Server then
			remote = Instance.new "RemoteFunction"
			remote.Name = name
			remote.Parent = _Folder
		else
			remote = _Folder:WaitForChild(name, 30)
		end
	end

	return remote :: RemoteFunction
end

local function GetOrCreateRemote(name: string, is_unreliable: boolean?): Remotes
	local remote = _Folder:FindFirstChild(name)

	if not remote then
		if Is_Server then
			remote = if is_unreliable
				then Instance.new "UnreliableRemoteEvent"
				else Instance.new "RemoteEvent"

			remote.Name = name
			remote.Parent = _Folder
		else
			remote = _Folder:WaitForChild(name, 60)
		end
	end

	return remote :: RemoteEvent
end

local math_isfinite = math.isfinite
local createLimiter = StarRateLimiter.new

local function isfinite(num: number): boolean
	return type(num) == "number" and math_isfinite(num)
end

local function isValidArguments(...): boolean
	for i = 1, select("#", ...) do
		if not isfinite(select(i, ...)) then
			return false
		end
	end

	return true
end

--[[ Public ]]
--

--[[ RemoteEvent Class ]]
--
local RemoteClass = {}
RemoteClass.__index = RemoteClass

type RemoteClass<T... = ...any?> = typeof(setmetatable(
	{} :: {
		read name: string,
		read _is_unreliable: boolean?,
		read _remote: RemoteEvent,
		read _limiter: StarRateLimiter.StarRateLimit,

		FireServer: (self: RemoteClass<T...>, T...) -> (),
		FireClient: (self: RemoteClass<T...>, player: Player, T...) -> (),
		FireClients: (self: RemoteClass<T...>, players: { Player }, T...) -> (),
		FireAllClients: (self: RemoteClass<T...>, T...) -> (),
		OnServer: (self: RemoteClass<T...>, (player: Player, T...) -> ()) -> RBXScriptConnection,
		OnClient: (self: RemoteClass<T...>, (T...) -> ()) -> RBXScriptConnection,
		OnServerOnce: (
			self: RemoteClass<T...>,
			(player: Player, T...) -> ()
		) -> RBXScriptConnection,
		OnClientOnce: (self: RemoteClass<T...>, (T...) -> ()) -> RBXScriptConnection,
		GetOnServerEvent: (self: RemoteClass<T...>) -> RBXScriptSignal,
		GetOnClientEvent: (self: RemoteClass<T...>) -> RBXScriptSignal,
		OnServerValidated: (
			self: RemoteClass<T...>,
			(player: Player, T...) -> ()
		) -> RBXScriptConnection,
		OnServerCustom: (
			self: RemoteClass<T...>,
			(player: Player, T...) -> (),
			check: (T...) -> boolean
		) -> RBXScriptConnection,
		Destroy: (self: RemoteClass<T...>) -> (),
	},
	RemoteClass
))

function RemoteClass.new<T...>(
	name: string,
	is_unreliable: boolean?,
	limiterConfig: StarRateLimiter.Config
): RemoteClass<T...>
	if _Remotes[name] then
		return _Remotes[name] :: RemoteClass<T...>
	end

	local self = setmetatable({
		name = name,
		_is_unreliable = is_unreliable,
		_remote = GetOrCreateRemote(name, is_unreliable),
		_limiter = createLimiter(limiterConfig),
	}, RemoteClass) :: RemoteClass<T...>

	_Remotes[name] = self :: RemoteClass
	return self
end

function RemoteClass.FireServer(self: RemoteClass, ...)
	self._remote:FireServer(...)
end

function RemoteClass.FireClient(self: RemoteClass, player: Player, ...)
	self._remote:FireClient(player, ...)
end

function RemoteClass.FireAllClients(self: RemoteClass, ...)
	self._remote:FireAllClients(...)
end

function RemoteClass.FireClients(self: RemoteClass, players: { Player }, ...)
	for _, player in players do
		self._remote:FireClient(player, ...)
	end
end

function RemoteClass.OnServer<T...>(
	self: RemoteClass,
	callback: (player: Player, T...) -> ()
): RBXScriptConnection
	return self._remote.OnServerEvent:Connect(function(player: Player, ...)
		if self._limiter:Check(player) then
			callback(player, ...)
		end
	end)
end

function RemoteClass.OnClient<T...>(self: RemoteClass, callback: (T...) -> ()): RBXScriptConnection
	return self._remote.OnClientEvent:Connect(callback)
end

function RemoteClass.OnServerOnce<T...>(
	self: RemoteClass,
	callback: (player: Player, T...) -> ()
): RBXScriptConnection
	return self._remote.OnServerEvent:Once(callback)
end

function RemoteClass.OnClientOnce<T...>(self: RemoteClass, callback: (T...) -> ()): RBXScriptConnection
	return self._remote.OnClientEvent:Once(callback)
end

function RemoteClass.GetOnServerEvent(self: RemoteClass): RBXScriptSignal
	return self._remote.OnServerEvent
end

function RemoteClass.GetOnClientEvent(self: RemoteClass): RBXScriptSignal
	return self._remote.OnClientEvent
end

function RemoteClass.OnServerValidated<T...>(
	self: RemoteClass,
	callback: (player: Player, T...) -> ()
): RBXScriptConnection
	return self:OnServer(function(player: Player, ...)
		if isValidArguments(...) then
			callback(player, ...)
		end
	end)
end

@deprecated
function RemoteClass.OnServerCustom<T...>(
	self: RemoteClass,
	callback: (player: Player, T...) -> (),
	check: (T...) -> boolean
): RBXScriptConnection
	return self:OnServer(function(player: Player, ...)
		if check(...) then
			callback(player, ...)
		end
	end)
end

function RemoteClass.Destroy(self: RemoteClass): ()
	_Remotes[self.name] = nil
	if Is_Server then
		self._remote:Destroy()
	end

	self._limiter:Destroy()
	setmetatable(self, nil)
end

--[[ RemoteFunction Class ]]
--
local FunctionClass = {}
FunctionClass.__index = FunctionClass

type FunctionClass<T... = ...any?, R... = ...any?> = typeof(setmetatable(
	{} :: {
		read name: string,
		read _remote: RemoteFunction,

		InvokeServer: (self: FunctionClass<T..., R...>, T...) -> R...,
		InvokeClient: (self: FunctionClass<T..., R...>, player: Player, T...) -> R...,
		OnClient: (self: FunctionClass<T..., R...>, (T...) -> R...) -> (),
		OnServer: (self: FunctionClass<T..., R...>, (player: Player, T...) -> R...) -> (),

		Destroy: (self: FunctionClass<T..., R...>) -> (),
	},
	FunctionClass
))

function FunctionClass.new<T..., R...>(name: string): FunctionClass<T..., R...>
	if _Functions[name] then
		return _Functions[name] :: FunctionClass<T..., R...>
	end

	local self = setmetatable({
		name = name,
		_remote = GetOrCreateFunction(name),
	}, FunctionClass) :: FunctionClass<T..., R...>

	_Functions[name] = self :: FunctionClass
	return self
end

function FunctionClass.InvokeServer(self: FunctionClass, ...): ...any
	return self._remote:InvokeServer(...)
end

function FunctionClass.InvokeClient(self: FunctionClass, player: Player, ...): ...any
	return self._remote:InvokeClient(player, ...)
end

function FunctionClass.OnClient<T...>(self: FunctionClass, callback: (T...) -> ()): ()
	self._remote.OnClientInvoke = callback
end

function FunctionClass.OnServer<T...>(self: FunctionClass, callback: (player: Player, T...) -> ()): ()
	self._remote.OnServerInvoke = callback
end

function FunctionClass.Destroy(self: FunctionClass): ()
	_Functions[self.name] = nil
	if Is_Server then
		self._remote:Destroy()
	end
	setmetatable(self, nil)
end

return table.freeze {
	Event = RemoteClass.new,
	Function = FunctionClass.new,
}
