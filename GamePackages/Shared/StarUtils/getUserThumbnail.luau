--!strict
const pattern = "rbxthumb://type=AvatarHeadShot&id=%d&w=%d&h=%d"

--[[
	Returns an AvatarHeadShot thumbnail URI for the given `userId`.
	Width and height default to 60 pixels.
]]
return function(userId: number, width: number?, height: number?)
	return string.format(pattern, userId, width or 60, height or 60)
end
