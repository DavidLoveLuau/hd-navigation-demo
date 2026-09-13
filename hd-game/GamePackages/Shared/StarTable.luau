--!optimize 2
--!strict

--[[
	StarTable: advanced table library
	
	Version: 1.0.0
	Author: @Davidhello9
]]

export type readtable<K = any, V = any> = { read [K]: V }
export type readarray<T = any> = { read T }
export type table<K = any, V = any> = { [K]: V }
export type array<T = any> = { T }

const function assertTable(value: any): ()
	const type = type(value)
	assert(type == "table", `[StarTable]: table expected, got: {type}`)
end

const function isTable(value: any)
	return type(value) == "table"
end

export function deepFreeze<T>(t: T): T
	if table.isfrozen(t) == false then
		table.freeze(t)
	end

	for _, value in t do
		if isTable(value) == true and table.freeze(value) == false then
			deepFreeze(value)
		end
	end

	return t
end
