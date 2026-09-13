const StarRemote = require(script.Core)
const Event = StarRemote.Event
const Function = StarRemote.Function

const function config(burst: number, cost: number, rate: number)
	return { burst = burst, cost = cost, rate = rate }
end

return table.freeze {
	Template = Event<<(number, string)>>("Template", false, config(10, 1, 2)),

	ZombieWorld_RequestInitialState = Event<<()>>(
		"ZombieWorld_RequestInitialState",
		false,
		config(1, 1, 1)
	),
	ZombieWorld_Initialize = Event<<(number, number, buffer)>>(
		"ZombieWorld_Initialize",
		false,
		config(0, 0, 0)
	),
	ZombieWorld_Lifecycle = Event<<(number, buffer)>>(
		"ZombieWorld_Lifecycle",
		false,
		config(0, 0, 0)
	),
	ZombieWorld_Snapshot = Event<<(number, number, number, buffer)>>(
		"ZombieWorld_Snapshot",
		true,
		config(0, 0, 0)
	),
	ZombieWorld_DebugSnapshot = Event<<(number, number, buffer)>>(
		"ZombieWorld_DebugSnapshot",
		true,
		config(0, 0, 0)
	),
	Ability_RequestShockwave = Event<<(number)>>(
		"Ability_RequestShockwave",
		false,
		config(2, 1, 4)
	),
	Ability_ShockwaveEffect = Event<<(number, number, Vector3, number)>>(
		"Ability_ShockwaveEffect",
		false,
		config(0, 0, 0)
	),
	Ability_RequestMeteor = Event<<(number, Vector3)>>(
		"Ability_RequestMeteor",
		false,
		config(2, 1, 4)
	),
	Ability_MeteorCast = Event<<(number, number, Vector3, number, number)>>(
		"Ability_MeteorCast",
		false,
		config(0, 0, 0)
	),
	Ability_MeteorImpact = Event<<(number, number, Vector3, number)>>(
		"Ability_MeteorImpact",
		false,
		config(0, 0, 0)
	),

	Event = Event,
	Function = Function,
}
