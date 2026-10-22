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

-- File-level `local name = ...` / `local name: T` used inside a function written above it: same trap, the
-- name is a nil global there. Only top-level (unindented) declarations count, and a use only counts when the
-- earlier line doesn't declare its own `name` (as a local, a parameter or a loop variable).
local function findEarlyVariables(path: string): { string }
	local lines = codeLines(fs.readFile(path))
	local problems = {}
	for index, line in lines do
		local name = string.match(line, "^local%s+([%w_]+)%s*[:=]")
		if name and not string.match(line, "^local%s+function") then
			for earlier = 1, index - 1 do
				local text = lines[earlier]
				local ownsName = string.match(text, "local%s+[%w_,%s]*%f[%w_]" .. name .. "%f[^%w_]")
					or string.match(text, "function[^%(]*%([^%)]*%f[%w_]" .. name .. "%f[^%w_]")
					or string.match(text, "for%s+[%w_,%s]*%f[%w_]" .. name .. "%f[^%w_]")
				local start = 1
				while not ownsName do
					local from, to = string.find(text, "%f[%w_]" .. name .. "%f[^%w_]", start)
					if not from then
						break
					end
					local before = if from > 1 then string.sub(text, from - 1, from - 1) else ""
					local inString = select(2, string.gsub(string.sub(text, 1, from), "[\"`]", "")) % 2 == 1
					if not string.match(before, "[%.:]") and not inString then
						table.insert(problems, `{path}:{earlier}: {name} is used before line {index} declares it`)
						break
					end
					start = to + 1
				end
			end
		end
	end
	return problems
end

-- A capitalised name used like a module or library (`Name.x` / `Name:x`) that the file never declares and that
-- isn't a Roblox or Luau global: it's a nil global at runtime (a missing require).
local GLOBALS = {}
for _, name in {
	"Enum", "Instance", "Vector2", "Vector3", "CFrame", "Color3", "UDim", "UDim2", "TweenInfo", "NumberSequence",
	"NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "NumberRange", "Random", "RaycastParams",
	"OverlapParams", "BrickColor", "Rect", "Region3", "Ray", "Font", "DateTime", "PhysicalProperties", "Axes", "Faces",
	"Vector2int16", "Vector3int16", "Content", "SharedTable", "Path2DControlPoint",
} do
	GLOBALS[name] = true
end

local function findUndeclared(path: string): { string }
	local lines = codeLines(fs.readFile(path))
	local declared: { [string]: boolean } = {}
	for _, line in lines do
		for name in string.gmatch(line, "local%s+([%w_]+)") do
			declared[name] = true
		end
		for name in string.gmatch(line, "local%s+function%s+([%w_]+)") do
			declared[name] = true
		end
		-- function parameters and for-loop names
		for params in string.gmatch(line, "function[^%(]*%(([^%)]*)%)") do
			for name in string.gmatch(params, "([%w_]+)") do
				declared[name] = true
			end
		end
		for names in string.gmatch(line, "for%s+([%w_,%s]+)%s+in") do
			for name in string.gmatch(names, "([%w_]+)") do
				declared[name] = true
			end
		end
	end
	local problems, seen = {}, {}
	for index, line in lines do
		local stripped = string.gsub(line, "%b\"\"", "")
		stripped = string.gsub(stripped, "%b``", "")
		for before, name in string.gmatch(stripped, "(.?)%f[%w_]([A-Z][%w_]*)%s*[%.:][%a_]") do
			if before ~= "." and before ~= ":" and not declared[name] and not GLOBALS[name] and not seen[name] then
				seen[name] = true
				table.insert(problems, `{path}:{index}: {name} is used but never required or declared`)
			end
		end
	end
	return problems
end

return {
	["every module a file uses is required or declared"] = function()
		local files = {}
		listFiles("src", files)
		local problems = {}
		for _, path in files do
			for _, problem in findUndeclared(path) do
				table.insert(problems, problem)
			end
		end
		table.sort(problems)
		assert(#problems == 0, `undeclared names:\n    {table.concat(problems, "\n    ")}`)
	end,

	["no file-level local is used above its declaration"] = function()
		local files = {}
		listFiles("src", files)
		local problems = {}
		for _, path in files do
			for _, problem in findEarlyVariables(path) do
				table.insert(problems, problem)
			end
		end
		table.sort(problems)
		assert(#problems == 0, `locals used before they exist:\n    {table.concat(problems, "\n    ")}`)
	end,

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
