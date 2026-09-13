--!strict
const Players = game:GetService("Players")

return function(callback: (player: Player) -> ())
	for _, player in Players:GetPlayers() do
		task.spawn(callback, player)
	end

	return Players.PlayerAdded:Connect(callback)
end
