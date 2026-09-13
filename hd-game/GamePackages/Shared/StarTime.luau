-- --!optimize 2
-- --!strict

--[[
	StarTime runs callbacks on shared Unix-time boundaries. Use it from server
	gameplay for recurring authoritative work, such as refreshing global stock.
]]

const StarSignal = require("@game/ReplicatedStorage/Packages/StarSignal")

export type EveryTask = {
	type: "every",
	interval: number,
	lastBucket: number,
	signal: Signal<(unixTime: number) -> ()>,
}

export type FixedTask = {
	type: "fixed",
	intervals: { number },
	lastBuckets: { number },
	signal: Signal<(unixTime: number) -> ()>,
}

export type Task = EveryTask | FixedTask

const Tasks: { Task } = {}
const UPDATE_INTERVAL = 0.25

const function GetBucket(now: number, interval: number): number
	return math.floor(now / interval)
end

const function ValidateInterval(interval: number)
	assert(
		math.isfinite(interval) and interval > 0 and interval % 1 == 0,
		"[StarTime]: Interval must be a positive whole number of seconds"
	)
end

const function Initialize()
	const function update()
		const now = os.time()

		for index, scheduledTask in Tasks do
			if getmetatable(scheduledTask.signal) == nil then
				Tasks[index] = nil
				continue
			end

			if scheduledTask.type == "every" then
				const bucket = GetBucket(now, scheduledTask.interval)
				if bucket ~= scheduledTask.lastBucket then
					scheduledTask.lastBucket = bucket
					scheduledTask.signal:Fire(bucket * scheduledTask.interval)
				end
			else
				local latestBoundary: number? = nil

				for intervalIndex, interval in scheduledTask.intervals do
					const bucket = GetBucket(now, interval)
					if bucket ~= scheduledTask.lastBuckets[intervalIndex] then
						scheduledTask.lastBuckets[intervalIndex] = bucket

						const boundary = bucket * interval
						if latestBoundary == nil or boundary > latestBoundary then
							latestBoundary = boundary
						end
					end
				end

				if latestBoundary ~= nil then
					scheduledTask.signal:Fire(latestBoundary)
				end
			end
		end
	end

	const function startUpdating()
		while task.wait(UPDATE_INTERVAL) do
			update()
		end
	end

	task.spawn(startUpdating)
end

--[[
	Fires at every Unix-time boundary divisible by `interval`.
	For example, Every(300) fires at :00, :05, :10, and so on.
	The callback receives the boundary Unix timestamp, rather than the possibly
	delayed scheduler timestamp.
]]
export function Every(interval: number)
	ValidateInterval(interval)

	const signal = StarSignal.new<<(number) -> ()>>()
	const task: EveryTask = {
		type = "every",
		interval = interval,
		lastBucket = GetBucket(os.time(), interval),
		signal = signal,
	}

	table.insert(Tasks, task)

	return signal
end

--[[
	Fires when one or more listed Unix-time intervals reaches a new boundary.
	AtSeconds({ 300, 1800 }) fires once at each five-minute boundary, including
	the boundaries that are also thirty minutes apart.
]]
export function AtSeconds(intervals: { number })
	assert(#intervals > 0, "[StarTime]: AtSeconds requires at least one interval")

	const copiedIntervals = table.create<<number>>(#intervals)
	const lastBuckets = table.create<<number>>(#intervals)
	const now = os.time()

	for index, interval in intervals do
		ValidateInterval(interval)
		copiedIntervals[index] = interval
		lastBuckets[index] = GetBucket(now, interval)
	end

	const signal = StarSignal.new<<(number) -> ()>>()
	const task: FixedTask = {
		type = "fixed",
		intervals = copiedIntervals,
		lastBuckets = lastBuckets,
		signal = signal,
	}

	table.insert(Tasks, task)

	return signal
end

Initialize()
