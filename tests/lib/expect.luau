--!strict
-- Minimal assertions for Lune unit tests. Errors carry a readable message.
local expect = {}

function expect.equal(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function expect.near(actual: number, expected: number, tolerance: number, label: string?)
	if math.abs(actual - expected) > tolerance then
		error(`{label or "value"}: expected ~{expected}, got {actual}`, 2)
	end
end

function expect.isNil(actual: any, label: string?)
	if actual ~= nil then
		error(`{label or "value"}: expected nil, got {tostring(actual)}`, 2)
	end
end

return expect
