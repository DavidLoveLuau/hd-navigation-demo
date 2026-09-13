--!strict

const MAX_CACHE_SIZE = 500
const DIVIDER = "."

type array<T> = { T }
type table<T = any, K = any> = { [K]: T }

const CACHED_PATHS = {}
local CacheSize = 0

--[[ PRIVATE FUNCTIONS ]]
--

const function isTable(value: any): boolean
	return type(value) == "table"
end

const function addToCache(path: string, splitPath: array<string>): array<string>
	if CacheSize >= MAX_CACHE_SIZE then
		table.clear(CACHED_PATHS)
		CacheSize = 0
	end

	CACHED_PATHS[path] = splitPath
	CacheSize += 1
	return splitPath
end

const function findInString(str: string, pos: number?)
	return string.find(str, DIVIDER, pos or 1, true)
end

const function splitIntoArray(path: string): array<string>
	return string.split(path, DIVIDER)
end

const function getCachedPath(path: string): array<string>
	local cached = CACHED_PATHS[path]
	if cached then
		return cached
	end
	return addToCache(path, findInString(path) and splitIntoArray(path) or { path })
end

const function traverseTable(rootTable: any, path: array<string>): (table?, string?)
	local current = rootTable
	local len = #path

	for index = 1, len - 1 do
		current = current[path[index]]
		if isTable(current) == false then
			return nil :: any
		end
	end

	return current, path[len]
end

const function getParentPath(path: string): (string?, string?)
	local pathArray = getCachedPath(path)
	local len = #pathArray

	if len <= 1 then
		return nil, path
	end

	return table.concat(pathArray, DIVIDER, 1, len - 1), pathArray[len]
end

--return link and key of value
const function getValueAtPath(parentTable: any, path: string)
	return traverseTable(parentTable, getCachedPath(path))
end

const function setValueAtPath(parentTable: any, path: string, value: any)
	const parent, key = traverseTable(parentTable, getCachedPath(path))
	if parent and key then
		parent[key] = value
	end
end

return table.freeze {
	--ParsePath = getValueAtPath,
	GetParentPath = getParentPath,
	SetValueAtPath = setValueAtPath,
	GetValueAtPath = getValueAtPath,
}
