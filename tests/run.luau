--!strict
-- Runs every spec file listed below. Each spec returns { [testName] = function }.
-- Usage: lune run tests/run
local process = require("@lune/process")

local specs: { [string]: { [string]: () -> () } } = {
	BeastMath = require("./BeastMath.spec"),
	Migrations = require("./Migrations.spec"),
	SaleRules = require("./SaleRules.spec"),
}

local passed, failed = 0, 0
for specName, tests in specs do
	for testName, test in tests do
		local ok, err = pcall(test)
		if ok then
			passed += 1
		else
			failed += 1
			print(`FAIL {specName} > {testName}\n    {err}`)
		end
	end
end
print(`{passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
