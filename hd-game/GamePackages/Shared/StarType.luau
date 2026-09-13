--!strict
export type LuauTypes =
	"nil"
	| "string"
	| "number"
	| "boolean"
	| "table"
	| "function"
	| "thread"
	| "userdata"
	| "vector"
	| "buffer"
export type RobloxTypes =
	LuauTypes
	| "Vector2"
	| "Vector3"
	| "UDim"
	| "UDim2"
	| "CFrame"
	| "Instance"
	| "RBXScriptSignal"
	| "RBXScriptConnection"

const function isType(value: any, expectedType: LuauTypes): boolean
	return type(value) == expectedType
end

const function isTypeOf(value: any, expectedType: RobloxTypes): boolean
	return typeof(value) == expectedType
end

const function assertType<T>(value: T, expectedType: LuauTypes, message: string?): T
	const isEqual = isType(value, expectedType)

	if isEqual == false then
		error(message or `Expected type "{expectedType}", got "{type(value)}"`, 2)
	end

	return value
end

const function assertTypeOf<T>(value: T, expectedType: RobloxTypes, message: string?): T
	const isEqual = isTypeOf(value, expectedType)

	if isEqual == false then
		error(message or `Expected type "{expectedType}", got "{typeof(value)}"`, 2)
	end

	return value
end

return table.freeze {
	isType = isType,
	isTypeOf = isTypeOf,

	assertType = assertType,
	assertTypeOf = assertTypeOf,
}
