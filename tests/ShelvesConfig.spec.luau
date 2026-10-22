--!strict
-- Config/Shelves holds Vector3 and Color3 values, so Lune can't load it; these checks read its text instead.
local fs = require("@lune/fs")

local SOURCE = fs.readFile("src/shared/Config/Shelves.luau")

-- Each shelf entry, from its `id = "..."` line to the next one
local function entries(): { { id: string, body: string } }
	local found = {}
	local starts = {}
	for position, id in string.gmatch(SOURCE, '()id = "([%w_]+)"') do
		table.insert(starts, { position = position :: number, id = id })
	end
	for index, start in starts do
		local finish = if starts[index + 1] then starts[index + 1].position - 1 else #SOURCE
		table.insert(found, { id = start.id, body = string.sub(SOURCE, start.position, finish) })
	end
	return found
end

return {
	["no shelf entry sets the same field twice"] = function()
		for _, entry in entries() do
			local seen: { [string]: boolean } = {}
			for field in string.gmatch(entry.body, "\n%s*([%a_]+)%s*=") do
				assert(not seen[field], `{entry.id} sets {field} twice (Luau keeps the last one)`)
				seen[field] = true
			end
		end
	end,

	["each shelf type has its own look"] = function()
		local props: { [string]: string } = {}
		for _, entry in entries() do
			props[entry.id] = string.match(entry.body, 'prop = "([%w_]+)"') or ""
		end
		assert(props.WallShelf == "WallShelf", "WallShelf prop")
		assert(props.AccessoryHook == "HookRack", "AccessoryHook prop")
		assert(props.BigDisplayRack == "DisplayRack", "BigDisplayRack prop")
		assert(props.GlassShowcase == "Showcase", "GlassShowcase prop")
	end,
}
