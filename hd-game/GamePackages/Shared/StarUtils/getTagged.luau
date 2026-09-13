--!strict
const CollectionService = game:GetService("CollectionService")

return function(tag: string, filter: ((Instance) -> (boolean))?): { Instance }
	const taggedInstances = CollectionService:GetTagged(tag)
	
	if filter == nil then
		return taggedInstances
	end

	const result = {}
	for _, instance in taggedInstances do
		if filter(instance) == true then
			table.insert(result, instance)
		end
	end

	return result
end
