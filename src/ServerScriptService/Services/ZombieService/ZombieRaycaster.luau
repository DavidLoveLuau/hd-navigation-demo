--!strict

const CollectionService = game:GetService("CollectionService")
const Workspace = game:GetService("Workspace")

const ZombieConfig = require(script.Parent.Config)
const RaycastingConfig = ZombieConfig.Raycasting

export type Raycaster = {
	Cast: (self: Raycaster, origin: Vector3, direction: Vector3) -> RaycastResult?,
}

const ZombieRaycaster = {
	IgnoreTag = RaycastingConfig.IgnoreTag,
}

ZombieRaycaster.__index = ZombieRaycaster

function ZombieRaycaster.new(): Raycaster
	const raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = RaycastingConfig.IgnoreWater

	const function refreshIgnoredInstances()
		raycastParams.FilterDescendantsInstances =
			CollectionService:GetTagged(RaycastingConfig.IgnoreTag)
	end

	refreshIgnoredInstances()
	CollectionService:GetInstanceAddedSignal(RaycastingConfig.IgnoreTag)
		:Connect(refreshIgnoredInstances)
	CollectionService:GetInstanceRemovedSignal(RaycastingConfig.IgnoreTag)
		:Connect(refreshIgnoredInstances)

	return setmetatable({
		_raycastParams = raycastParams,
	}, ZombieRaycaster) :: any
end

function ZombieRaycaster:Cast(origin: Vector3, direction: Vector3): RaycastResult?
	return Workspace:Raycast(origin, direction, self._raycastParams)
end

return table.freeze(ZombieRaycaster)




