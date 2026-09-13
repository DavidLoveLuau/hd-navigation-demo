--!strict

export type ShockwaveConfig = {
	KeyCode: Enum.KeyCode,
	Cooldown: number,
	Radius: number,
	MaxVerticalDistance: number,
	Damage: number,
	EffectDuration: number,
	EffectColor: Color3,
}

export type MeteorConfig = {
	KeyCode: Enum.KeyCode,
	Cooldown: number,
	MaxCastDistance: number,
	TargetRayHeight: number,
	TargetRayDistance: number,
	FallDuration: number,
	StartHeight: number,
	DamageRadius: number,
	MaxVerticalDistance: number,
	Damage: number,
	IndicatorColor: Color3,
	IndicatorTransparency: number,
	ExplosionLifetime: number,
}

local Shockwave = table.freeze {
	-- Key used by the local client to request a Shockwave cast.
	KeyCode = Enum.KeyCode.Q,
	-- Minimum server-authoritative time in seconds between casts by one player.
	Cooldown = 3,
	-- Horizontal radius in studs of the Shockwave damage cylinder.
	Radius = 14,
	-- Maximum vertical distance in studs between the wave and a zombie hit by it.
	MaxVerticalDistance = 8,
	-- Server-authoritative damage dealt once to every zombie hit by the wave.
	Damage = 40,
	-- Lifetime in seconds of the local expanding-ring visual.
	EffectDuration = 0.45,
	-- Display color of the local expanding-ring visual.
	EffectColor = Color3.fromRGB(108, 232, 255),
} :: ShockwaveConfig

local Meteor = table.freeze {
	-- Key used by the local client to request a Meteor cast at its cursor position.
	KeyCode = Enum.KeyCode.E,
	-- Minimum server-authoritative time in seconds between casts by one player.
	Cooldown = 4,
	-- Maximum horizontal distance in studs from the caster to the requested impact point.
	MaxCastDistance = 60,
	-- Height in studs above the caster used as the origin for the server ground ray cast.
	TargetRayHeight = 128,
	-- Maximum downward distance in studs checked by the server for a valid impact surface.
	TargetRayDistance = 256,
	-- Time in seconds between the confirmed cast and the authoritative impact.
	FallDuration = 1.25,
	-- Height in studs above the impact position from which clients render the meteor model.
	StartHeight = 100,
	-- Horizontal radius in studs of the impact damage cylinder.
	DamageRadius = 16,
	-- Maximum vertical distance in studs between the impact and a zombie damaged by it.
	MaxVerticalDistance = 10,
	-- Server-authoritative damage dealt once to every zombie hit by the impact.
	Damage = 100,
	-- Display color of the local impact warning circle.
	IndicatorColor = Color3.fromRGB(255, 74, 74),
	-- Transparency of the local impact warning circle.
	IndicatorTransparency = 0.45,
	-- Lifetime in seconds of the cloned explosion VFX after impact.
	ExplosionLifetime = 5,
} :: MeteorConfig

return table.freeze {
	Shockwave = Shockwave,
	Meteor = Meteor,
}
