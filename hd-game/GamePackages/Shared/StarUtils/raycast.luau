--!strict
return function(origin: Vector3, direction: Vector3, raycastParams: RaycastParams?)
	return workspace:Raycast(origin, direction, raycastParams)
end
