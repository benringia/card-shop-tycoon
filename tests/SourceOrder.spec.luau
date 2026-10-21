--!strict
-- Catches a Luau trap the syntax check can't: calling a `local function` from code written above its
-- definition. The name isn't in scope there, so it's a nil global and the call errors at runtime.
-- For every file under src, any `name(` call before `local function name` (with no earlier `local name`
-- forward declaration) fails this test.
local fs = require("@lune/fs")

local function listFiles(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			listFiles(path, out)
		elseif string.match(name, "%.luau$") then
			table.insert(out, path)
		end
	end
end

-- Lines without comments, so names mentioned in comments don't count
local function codeLines(source: string): { string }
	local lines = {}
	for line in string.gmatch(source .. "\n", "(.-)\n") do
		table.insert(lines, (string.gsub(line, "%-%-.*$", "")))
	end
	return lines
end

local function findEarlyCalls(path: string): { string }
	local lines = codeLines(fs.readFile(path))
	local defined: { [string]: number } = {}
	local declared: { [string]: number } = {}
	for index, line in lines do
		local name = string.match(line, "^%s*local%s+function%s+([%w_]+)")
		if name and not defined[name] then
			defined[name] = index
		end
		for declaration in string.gmatch(line, "^%s*local%s+([%w_]+)%s*:") do
			declared[declaration] = declared[declaration] or index
		end
		local plain = string.match(line, "^%s*local%s+([%w_]+)%s*$")
		if plain then
			declared[plain] = declared[plain] or index
		end
	end
	local problems = {}
	for name, definedAt in defined do
		local forward = declared[name]
		if not (forward and forward < definedAt) then
			for index = 1, definedAt - 1 do
				local line = lines[index]
				-- A call to the bare name: not obj.name( or obj:name(, and not part of a longer identifier
				local start = 1
				while true do
					local from, to = string.find(line, name .. "%s*%(", start)
					if not from then
						break
					end
					local before = if from > 1 then string.sub(line, from - 1, from - 1) else ""
					if not string.match(before, "[%w_%.:]") then
						table.insert(problems, `{path}:{index}: {name}() is used before line {definedAt} defines it`)
						break
					end
					start = to + 1
				end
			end
		end
	end
	return problems
end

return {
	["no local function is called above its definition"] = function()
		local files = {}
		listFiles("src", files)
		local problems = {}
		for _, path in files do
			for _, problem in findEarlyCalls(path) do
				table.insert(problems, problem)
			end
		end
		table.sort(problems)
		assert(#problems == 0, `local functions used before they exist:\n    {table.concat(problems, "\n    ")}`)
	end,
}
