--!strict
const Players = game:GetService("Players")

const userIdUserNameCache: { [number]: string } = {}

const function GetNameFromUserIdAsync(userId)
    return Players:GetNameFromUserIdAsync(userId)
end

--[[
Sends a query to the Roblox website for the username of an account with a given `UserId`.
@yields
]]
return function(userId: number)
    if userIdUserNameCache[userId] ~= nil then
        return userIdUserNameCache[userId]
    end

    const success, result = pcall(GetNameFromUserIdAsync, userId)

    if success == true then
        userIdUserNameCache[userId] = result
        return result
    end

    return "unknown"
end
