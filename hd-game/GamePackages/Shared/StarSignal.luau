--!optimize 2

--[[
	StarSignal
	Author: @Davidhello9
]]

const StarSignal, Connect = {}, {}
StarSignal.__index = StarSignal
Connect.__index = Connect

--[[ TYPES ]]

type callback = (...any) -> ()
type checkCallback = (...any) -> boolean

--[[
	Creates a new connection for the specified signal.
]]
function Connect.Create(signal: Signal, callback: callback): Connect
	return setmetatable({
		_signal = signal,
		_fn = callback,
		_next = signal._next,
		_prev = nil,
		Connected = true,
	}, Connect) :: Connect
end

--[[
	Disconnects the connection from its signal.
]]
function Connect.Disconnect(self: Connect)
	if self.Connected == false then
		return
	end

	if self._signal._next == self then
		self._signal._next = self._next
	end

	if self._prev ~= nil then
		self._prev._next = self._next
	end

	if self._next ~= nil then
		self._next._prev = self._prev
	end

	self._signal = nil
	self._next = nil
	self._prev = nil

	self.Connected = false
	setmetatable(self, nil)
end

--[[
	Creates a new signal with an optional name.
]]
function StarSignal.new<callback>(name: string?): Signal<callback>
	return setmetatable({
		name = name,
	}, StarSignal) :: Signal<callback>
end

function StarSignal.newT<T...>(name: string?): SSignal<T...>
	return setmetatable({
		name = name,
	}, StarSignal) :: SSignal<T...>
end

--[[
	Connects a callback that runs whenever the signal fires.
]]
function StarSignal.Connect(self: Signal, callback: callback): Connect
	const connect = Connect.Create(self, callback)
	if self._next ~= nil then
		self._next._prev = connect
	end

	self._next = connect
	return connect
end

--[[
	Connects a callback that runs in parallel execution.
]]
function StarSignal.ConnectParallel(self: Signal, callback: callback): Connect
	const parallelCallback = function(...: any)
		task.desynchronize()
		callback(...)
	end

	return self:Connect(parallelCallback)
end

--[[
	Connects a callback that runs only once.
]]
function StarSignal.Once(self: Signal, callback: callback): Connect
	local connection: Connect

	connection = self:Connect(function(...)
		if connection.Connected == true then
			connection:Disconnect()
		end
		callback(...)
	end)

	return connection
end

--[[
	Connects a callback that runs once after the check succeeds.
]]
function StarSignal.OnceWithCheck(self: Signal, callback: callback, check: checkCallback): Connect
	local connection: Connect

	connection = self:Connect(function(...)
		if check(...) == false then
			return
		end

		if connection.Connected == true then
			connection:Disconnect()
		end

		callback(...)
	end)

	return connection
end

--[[
	Yields the current thread until the signal fires.
]]
function StarSignal.Wait(self: Signal): ...any
	const thread = coroutine.running()

	self:Once(function(...)
		task.defer(thread, ...)
	end)

	return coroutine.yield()
end

--[[
	Yields until the signal fires with arguments that pass the check.
]]
function StarSignal.WaitWithCheck(self: Signal, check: checkCallback): ...any
	const thread = coroutine.running()

	self:OnceWithCheck(function(...)
		task.defer(thread, ...)
	end, check)

	return coroutine.yield()
end

--[[
	Yields until the signal fires or the timeout is reached.
	Returns no values if the timeout is reached.
]]
function StarSignal.WaitWithTimeout(self: Signal, timeout: number): ...any
	const thread = coroutine.running()

	local timer: thread, connection: Connect
	do
		timer = task.delay(timeout, function()
			if connection and connection.Connected then
				connection:Disconnect()
				task.defer(thread)
			end
		end)
	end

	connection = self:Once(function(...)
		task.cancel(timer)
		task.defer(thread, ...)
	end)

	return coroutine.yield()
end

--[[
	Yields until the check succeeds or the timeout is reached.
	Returns no values if the timeout is reached.
]]
function StarSignal.WaitWithCheckAndTimeout(
	self: Signal,
	check: checkCallback,
	timeout: number
): ...any
	const thread = coroutine.running()

	local timer: thread, connection: Connect
	do
		timer = task.delay(timeout, function()
			if connection ~= nil and connection.Connected == true then
				connection:Disconnect()
				task.defer(thread)
			end
		end)
	end

	connection = self:OnceWithCheck(function(...)
		task.cancel(timer)
		task.defer(thread, ...)
	end, check)

	return coroutine.yield()
end

--[[
	Fires the signal and schedules all connected callbacks.
]]
function StarSignal.Fire(self: Signal, ...: any): ()
	local connection = self._next

	while connection ~= nil do
		task.defer(connection._fn, ...)
		connection = connection._next
	end
end

--[[
	Disconnects all callbacks from the signal.
]]
function StarSignal.Disconnect(self: Signal)
	local connection = self._next

	while connection ~= nil do
		const _next = connection._next
		connection:Disconnect()
		connection = _next
	end

	self._next = nil
end

--[[
	Disconnects all callbacks and destroys the signal.
]]
function StarSignal.Destroy(self: Signal)
	self:Disconnect()
	setmetatable(self, nil)
end

return table.freeze(StarSignal)
