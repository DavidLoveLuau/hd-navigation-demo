--!strict
-- StarRateLimit: Token Bucket rate limiter с burst поддержкой

const Players = game:GetService("Players")
local OnPlayerRemoving = Players.PlayerRemoving

export type Config = {
	rate: number, -- токенов в секунду (устойчивая частота)
	burst: number, -- ёмкость ведра (max burst)
	cost: number, -- токенов за вызов (default 1)
}

local StarRateLimit = {}
StarRateLimit.__index = StarRateLimit

export type StarRateLimit = typeof(setmetatable(
	{} :: {
		_buckets: { [number]: { tokens: number, lastTime: number } },
		_config: {
			rate: number,
			burst: number,
			cost: number,
		},
		_cleanup: RBXScriptConnection,

		Check: (self: StarRateLimit, player: Player) -> boolean,
		Reset: (self: StarRateLimit, player: Player) -> (),
		Destroy: (self: StarRateLimit) -> (),
	},
	StarRateLimit
))

function StarRateLimit.new(config: Config): StarRateLimit
	local config = config or {} :: { rate: number?, burst: number?, cost: number? }
	local self = setmetatable({
		_buckets = {},
		_config = {
			rate = config.rate or 2,
			burst = config.burst or 40,
			cost = config.cost or 1,
		},
	}, StarRateLimit)

	-- Автоочистка при выходе игрока
	self._cleanup = OnPlayerRemoving:Connect(function(player)
		self._buckets[player.UserId] = nil
	end)

	return self :: StarRateLimit
end

--[[
    Проверяет можно ли пропустить вызов.
    Возвращает true = разрешено, false = заблокировано.
]]
function StarRateLimit.Check(self: StarRateLimit, player: Player): boolean
	local userId = player.UserId
	local conf = self._config
	local now = tick()

	local bucket = self._buckets[userId]

	if not bucket then
		-- Первый вызов: стартуем с полным ведром минус cost
		self._buckets[userId] = {
			tokens = conf.burst - conf.cost,
			lastTime = now,
		}
		return true
	end

	-- Lazy refill: добавляем накопленные токены
	local delta = now - bucket.lastTime
	local refill = delta * conf.rate
	local tokens = math.min(conf.burst, bucket.tokens + refill)

	bucket.lastTime = now

	if tokens >= conf.cost then
		bucket.tokens = tokens - conf.cost
		return true
	end

	-- Недостаточно токенов
	bucket.tokens = tokens
	return false
end

-- Сбросить состояние конкретного игрока (например после кика)
function StarRateLimit.Reset(self: StarRateLimit, player: Player)
	self._buckets[player.UserId] = nil
end

function StarRateLimit.Destroy(self: StarRateLimit)
	self._cleanup:Disconnect()
	table.clear(self._buckets)
	setmetatable(self, nil)
end

return StarRateLimit
