--!strict
-- Catches what neither the syntax check nor the other tests can: two modules that require each other at load, through
-- any chain ("Requested module was required recursively": the server never boots). Found 2026-11-19 when EventService
-- (needs LuckService -> PackService -> ... -> BossService) was required by BossChestService. Only requires at the top
-- of a file count (a require inside a function runs later and is how a real cycle is broken). Checked per folder of
-- modules that require their neighbours by name: server Services and Util, client Controllers and Util, shared Util.
local fs = require("@lune/fs")

-- The neighbours a module requires at load: `local X = require(<anything>:WaitForChild("Name"))` or `.Name)` at the
-- start of a line, where Name is another module of the same set. A line that names one of `elsewhere` reaches into
-- another folder (Config/SwordSkillFx is not the client's Util/SwordSkillFx), so it isn't a neighbour
local function loadRequires(path: string, names: { [string]: boolean }, elsewhere: { string }): { string }
	local found = {}
	for line in string.gmatch(fs.readFile(path) .. "\n", "(.-)\r?\n") do
		local outside = false
		for _, word in elsewhere do
			outside = outside or string.find(line, word, 1, true) ~= nil
		end
		if not outside and string.match(line, "^local%s") and string.find(line, "require(", 1, true) then
			local name = string.match(line, 'WaitForChild%("([%w_]+)"%)%)%s*') or string.match(line, "%.([%w_]+)%)%s*$")
			if name and names[name] then
				table.insert(found, name)
			end
		end
	end
	return found
end

-- The first cycle in these folders' modules (as "A -> B -> A"), or nil
local function findCycle(dirs: { string }, elsewhere: { string }): string?
	local paths: { [string]: string } = {}
	local names: { [string]: boolean } = {}
	for _, dir in dirs do
		for _, file in fs.readDir(dir) do
			local name = string.match(file, "^([%w_]+)%.luau$")
			if name then
				paths[name] = `{dir}/{file}`
				names[name] = true
			end
		end
	end
	local graph: { [string]: { string } } = {}
	for name, path in paths do
		-- its own name is the shared module it wraps (server Util/Funnel requires shared Util/Funnel), never itself
		local needed = {}
		for _, other in loadRequires(path, names, elsewhere) do
			if other ~= name then
				table.insert(needed, other)
			end
		end
		graph[name] = needed
	end
	local state: { [string]: number } = {} -- 1: on the stack, 2: done
	local stack: { string } = {}
	local function visit(name: string): string?
		state[name] = 1
		table.insert(stack, name)
		for _, needed in graph[name] do
			if state[needed] == 1 then
				local from = table.find(stack, needed) or 1
				return table.concat(stack, " -> ", from) .. " -> " .. needed
			elseif not state[needed] then
				local cycle = visit(needed)
				if cycle then
					return cycle
				end
			end
		end
		table.remove(stack)
		state[name] = 2
		return nil
	end
	local sorted = {}
	for name in graph do
		table.insert(sorted, name)
	end
	table.sort(sorted)
	for _, name in sorted do
		if not state[name] then
			local cycle = visit(name)
			if cycle then
				return cycle
			end
		end
	end
	return nil
end

return {
	["no server module requires itself back at load (services and their utils)"] = function()
		local cycle = findCycle({ "src/server/Services", "src/server/Util" }, { "Config", "Shared" })
		assert(cycle == nil, `require cycle: {cycle}`)
	end,

	["no client module requires itself back at load (controllers and their utils)"] = function()
		local cycle = findCycle({ "src/client/Controllers", "src/client/Util" }, { "Config", "Shared" })
		assert(cycle == nil, `require cycle: {cycle}`)
	end,

	["no shared util requires itself back at load"] = function()
		local cycle = findCycle({ "src/shared/Util" }, { "Config" })
		assert(cycle == nil, `require cycle: {cycle}`)
	end,
}
