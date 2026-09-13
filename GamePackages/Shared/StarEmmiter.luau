--!strict
-- [[ Types ]]--

type EmitConfig = {
	EmitCount: number?,
	EmitDelay: number?,
	EmitDuration: number?,
}

--[[ Private ]]
--

local function setEnabled(emitter: ParticleEmitter, enabled: boolean)
	emitter.Enabled = enabled
end

local function emitParticles(emitter: ParticleEmitter, count: number)
	emitter:Emit(count)
end

local function emitEmitter(emitter: ParticleEmitter)
	local attributes = emitter:GetAttributes() :: EmitConfig

	local emitCount = attributes.EmitCount or 0
	local emitDelay = attributes.EmitDelay or 0
	local emitDuration = attributes.EmitDuration or 0

	if emitCount > 0 then
		if emitDelay > 0 then
			task.delay(emitDelay, emitParticles, emitter, emitCount)
		else
			emitParticles(emitter, emitCount)
		end

		return
	end

	emitter.Enabled = true

	if emitDuration > 0 then
		task.delay(emitDuration, setEnabled, emitter, false)
	end
end

local function EmitInstance(instance: Instance)
	if instance:IsA "ParticleEmitter" then
		emitEmitter(instance)
	end

	for _, descendant in instance:GetDescendants() do
		if descendant:IsA "ParticleEmitter" then
			emitEmitter(descendant)
		end
	end
end

return table.freeze {
	EmitInstance = EmitInstance,
}
