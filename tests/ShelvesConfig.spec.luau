--!strict
-- Config/Shelves holds Vector3 and Color3 values, so Lune can't load it; these checks read its text instead.
local fs = require("@lune/fs")
local Bosses = require("../src/shared/Config/Bosses")

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

	["every shelf sits in a Build menu category that matches its kind"] = function()
		local byKind = { Products = "Shelves", CustomerCards = "Cases", PlayerCards = "Cases", Condenser = "Fixtures", Grading = "Fixtures", Trophy = "Trophies" }
		for _, entry in entries() do
			local kind = string.match(entry.body, 'kind = "([%w_]+)"')
			local category = string.match(entry.body, 'category = "([%w_]+)"')
			assert(category, `{entry.id} has no category`)
			assert(category == byKind[kind], `{entry.id} ({kind}) is in {category}, expected {byKind[kind]}`)
		end
	end,

	["each boss trophy is placed from its own trophy item"] = function()
		local trophies = 0
		for _, entry in entries() do
			if string.match(entry.body, 'kind = "Trophy"') then
				trophies += 1
				assert(string.match(entry.body, 'requiresItem = "([%w_]+)"') == entry.id, `{entry.id} must require the item {entry.id}`)
				assert(string.match(entry.body, "cost = 0,"), `{entry.id} must be free (the item is the price)`)
			end
		end
		assert(trophies == #Bosses.LADDER, `expected one trophy per boss ({#Bosses.LADDER}), found {trophies}`)
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

	["the Card Condenser stands big enough to read as a machine"] = function()
		for _, entry in entries() do
			if entry.id == "Condenser" then
				local x, y, z = string.match(entry.body, "size = Vector3.new%((%d+), (%d+), (%d+)%)")
				assert(tonumber(x) == 6 and tonumber(y) == 7 and tonumber(z) == 6, `Condenser size {x} x {y} x {z}`)
				return
			end
		end
		error("no Condenser entry")
	end,

	["the Collector Case is a glass counter in its own colours"] = function()
		for _, entry in entries() do
			if entry.id == "CollectorCase" then
				assert(string.find(entry.body, 'prop = "Showcase"', 1, true), "CollectorCase uses the Showcase counter")
				assert(string.find(entry.body, "cardsFlat = true", 1, true), "its cards lie flat")
				for _, part in { "Support", "Frame", "Carpet" } do
					assert(string.find(entry.body, part .. " = Color3", 1, true), `CollectorCase recolours {part}`)
				end
				return
			end
		end
		error("no CollectorCase entry")
	end,
}
