--!strict
const DEFAULT_MAX_ATTEMPTS = 3
const DEFAULT_INITIAL_DELAY = 1
const DEFAULT_DELAY_MULTIPLIER = 2

--[[
	@yields 
	Up to 3 seconds with the default retry options.
]]
return function<T...>(
	callback: () -> T...,
	maxAttempts: number?,
	initialDelay: number?,
	delayMultiplier: number?
): (boolean, T...)
	const attempts = maxAttempts or DEFAULT_MAX_ATTEMPTS
	local currentDelay = initialDelay or DEFAULT_INITIAL_DELAY
	const multiplier = delayMultiplier or DEFAULT_DELAY_MULTIPLIER

	assert(attempts >= 1, "maxAttempts must be at least 1")
	assert(currentDelay >= 0, "initialDelay cannot be negative")
	assert(multiplier >= 1, "delayMultiplier must be at least 1")

	local lastError: any

	for attempt = 1, attempts do
		const results = table.pack<<any>>(pcall(callback))
		const success = results[1]

		if success == true then
			return true, table.unpack(results :: {any}, 2, results.n)
		end

		lastError = results[2]

		if attempt < attempts then
			task.wait(currentDelay)
			currentDelay *= multiplier
		end
	end
	
	return false, lastError
end
