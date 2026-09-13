--!strict
const RunService = game:GetService("RunService")
const Player = game:GetService("Players").LocalPlayer

local lastPosition = Vector3.zero

RunService.Heartbeat:Connect(function()
	const character = Player.Character
	if character == nil then
		return
	end

	const position = character:GetPivot().Position
	lastPosition = position
end)

--[[
	Returns the distance from `lastPosition` to `position`.
	If `allowedDistance` is specified, returns `true` when the distance does not exceed it.
]]
@checked
@native
const function GetDistance(position: Vector3, allowedDistance: number?): boolean | number
	assert(typeof(position) == "Vector3", "position must have type Vector3")
	const magnitude = (lastPosition - position).Magnitude
	
	if allowedDistance ~= nil then
		assert(typeof(allowedDistance) == "number", "allowedDistance must have type number")
		return magnitude <= allowedDistance
	end

	return (lastPosition - position).Magnitude
end

return GetDistance
