--!strict

export type ZombieTypeId = "Normal"

export type ZombieType = {
	Speed: number,
	StopDistance: number,
	GroundOffset: number,
	AttackRange: number,
	AttackDamage: number,
	AttackCooldown: number,
	SeparationRadius: number,
	MaxHealth: number,
	HitRadius: number,
}

const Types = table.freeze {
	Normal = table.freeze {
		-- Horizontal movement speed in studs per second.
		Speed = 15,
		-- Distance in studs at which this zombie stops moving towards its steering target.
		StopDistance = 4,
		-- Height in studs from the hit ground surface to this zombie's ECS position.
		GroundOffset = 3,
		-- Maximum 3D distance in studs at which this zombie can damage a player.
		AttackRange = 3,
		-- Health removed by one successful melee attack.
		AttackDamage = 1,
		-- Minimum time in seconds between this zombie's melee attacks.
		AttackCooldown = 1,
		-- Personal-space radius in studs used for non-physical zombie separation.
		SeparationRadius = 2.5,
		-- Maximum server-authoritative health of this zombie type.
		MaxHealth = 100,
		-- Radius in studs added when checking whether area damage hits this zombie.
		HitRadius = 2.5,
	},
} :: { [ZombieTypeId]: ZombieType }

return table.freeze {
	Simulation = table.freeze {
		-- Fixed duration in seconds of one authoritative zombie simulation tick.
		Step = 1 / 20,
	},
	Networking = table.freeze {
		-- Interval in seconds between unreliable transform snapshots.
		SnapshotInterval = 1 / 10,
		-- Version of the zombie-world protocol and server simulation state.
		WorldRevision = 3,
		-- Maximum zombie records placed in one unreliable snapshot packet.
		MaxZombiesPerSnapshot = 60,
	},
	Spawning = table.freeze {
		-- Temporary number of zombies spawned for each player during the load test.
		ZombiesPerPlayer = 100,
		-- Type assigned to all temporary load-test zombies.
		DefaultType = "Normal" :: ZombieTypeId,
		-- Number of zombies placed in one spawn ring.
		ZombiesPerRing = 12,
		-- Radius in studs of the first spawn ring around the player.
		FirstRingRadius = 18,
		-- Additional radius in studs for every following spawn ring.
		RingRadiusStep = 4,
		-- Angular offset in radians applied to each following spawn ring.
		RingAngleOffset = 0.2,
	},
	Grounding = table.freeze {
		-- Height in studs above a zombie from which its downward ground ray begins.
		RayHeight = 12,
		-- Maximum downward distance in studs checked for walkable ground.
		RayDistance = 32,
	},
	Separation = table.freeze {
		-- Whether zombies steer apart locally without enabling model collision.
		Enabled = true,
		-- Width and depth in studs of one spatial-hash cell used to find nearby zombies.
		CellSize = 6,
		-- Multiplier applied to the local separation steering vector.
		Strength = 1.25,
	},
	Navigation = table.freeze {
		-- CollectionService tag assigned to walkable-surface navigation attachments.
		NodeTag = "ZombieNavNode",
		-- Maximum 3D distance in studs for an automatically created graph edge.
		LinkDistance = 24,
		-- Maximum vertical difference in studs for an automatically created graph edge.
		MaxVerticalLinkDistance = 6,
		-- Height in studs above node attachments used to check edge clearance.
		LinkRayHeight = 3,
	},
	Raycasting = table.freeze {
		-- CollectionService tag assigned to decoration excluded from zombie ray casts.
		IgnoreTag = "ZombieRaycastIgnore",
		-- Whether zombie ray casts ignore terrain water.
		IgnoreWater = true,
	},
	Debug = table.freeze {
		-- Whether the server renders navigation nodes and edges for map authoring.
		ShowNavigationGraph = true,
		-- Whether clients render server-reported movement-state labels above zombie visuals.
		ShowZombieStateLabels = true,
		-- Name of the temporary Workspace folder containing navigation debug instances.
		NavigationFolderName = "ZombieNavigationDebug",
		-- Diameter in studs of a navigation-node marker.
		NodeSize = Vector3.new(0.6, 0.6, 0.6),
		-- Display color of a navigation-node marker.
		NodeColor = Color3.fromRGB(79, 255, 122),
		-- Display color of a navigation-edge beam.
		LinkColor = Color3.fromRGB(255, 213, 79),
		-- Transparency of a navigation-node marker.
		NodeTransparency = 0.15,
		-- Width in studs of a navigation-edge beam.
		LinkWidth = 0.15,
	},
	-- Server-authoritative characteristics for each zombie type.
	Types = Types,
}



