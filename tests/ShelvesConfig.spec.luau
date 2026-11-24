--!strict
-- Config/Shelves holds Vector3 and Color3 values, so Lune can't load it; these checks read its text instead.
local fs = require("@lune/fs")
local expect = require("./lib/expect")
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
		local byKind = { Products = "Shelves", CustomerCards = "Cases", PlayerCards = "Cases", Condenser = "Fixtures", Grading = "Fixtures", Forge = "Fixtures", Recycler = "Fixtures", Trophy = "Trophies", Decor = "Decor", Storage = "Shelves" }
		for _, entry in entries() do
			local kind = string.match(entry.body, 'kind = "([%w_]+)"')
			local category = string.match(entry.body, 'category = "([%w_]+)"')
			assert(category, `{entry.id} has no category`)
			assert(category == byKind[kind], `{entry.id} ({kind}) is in {category}, expected {byKind[kind]}`)
		end
	end,

	-- Storage racks (spec 2026-11-24-storage-racks-design; owner 2026-11-24: "numbers OK"): 9 boxes on Config/Storage's
	-- spots, $400 at shop level 5, 10 x 2 studs, drawn by code (Town.SLOTS StorageRack built)
	["the storage rack: 9 boxes on its spots, $400 at level 5, 10 x 2 studs, its code-built look"] = function()
		local Storage = require("../src/shared/Config/Storage")
		local rack: string? = nil
		for _, entry in entries() do
			if entry.id == "StorageRack" then
				rack = entry.body
			end
		end
		assert(rack, "a StorageRack entry")
		local body = rack :: string
		assert(string.match(body, 'kind = "Storage"'), "kind Storage")
		expect.equal(tonumber(string.match(body, "capacity = (%d+)")), #Storage.SPOTS.x * #Storage.SPOTS.decks, "a box on every spot")
		expect.equal(tonumber(string.match(body, "cost = (%d+)")), 400)
		expect.equal(tonumber(string.match(body, "unlockLevel = (%d+)")), 5)
		assert(string.match(body, "size = Vector3.new%(10, 7, 2%)"), "10 x 7 x 2")
		assert(string.match(body, 'prop = "StorageRack"'), "its own prop slot")
		local town = fs.readFile("src/shared/Config/Town.luau")
		assert(string.find(town, "StorageRack = { height = 0, collide = false, built = true }", 1, true), "drawn by code")
	end,

	-- Shop decor (spec 2026-11-14-shop-decor-design): the twelve placeable pieces
	["decor pieces: twelve, each with points, a prop slot of its own id, a grid footprint, in unlock order"] = function()
		local town = fs.readFile("src/shared/Config/Town.luau")
		local pieces, lastLevel = 0, 0
		for _, entry in entries() do
			if string.match(entry.body, 'kind = "Decor"') then
				pieces += 1
				assert(string.match(entry.body, 'category = "Decor"'), `{entry.id} in the Decor tab`)
				assert(string.match(entry.body, "capacity = 0,"), `{entry.id} holds nothing`)
				assert(string.match(entry.body, 'prop = "([%w_]+)"') == entry.id, `{entry.id} draws its own prop slot`)
				local points = tonumber(string.match(entry.body, "decor = (%d+)"))
				assert(points and points >= 1 and points <= 3, `{entry.id} gives 1-3 decor points`)
				local x, z = string.match(entry.body, "size = Vector3.new%(([%d%.]+), [%d%.]+, ([%d%.]+)%)")
				assert(x and z and tonumber(x) :: number % 2 == 0 and tonumber(z) :: number % 2 == 0, `{entry.id} fills whole 2-stud cells`)
				local level = tonumber(string.match(entry.body, "unlockLevel = (%d+)")) :: number
				if string.match(entry.body, "needs = {") then
					-- achievement decor (spec 2026-11-14-shop-windows-design): out of the level order, says what it needs
					assert(string.match(entry.body, 'how = "[^"]+"'), `{entry.id} says what unlocks it`)
				else
					assert(level >= lastLevel, `{entry.id} unlocks no earlier than the piece before it`)
					lastLevel = level
				end
				assert(string.find(town, "%s" .. entry.id .. " = {"), `Town.SLOTS has {entry.id}`)
			end
		end
		assert(pieces == 12, `expected 12 decor pieces, found {pieces}`)
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

	-- Owner 2026-11-23: "we need a model for the trophies. draw from blender": each boss's trophy its own Blender model
	["each boss trophy draws its own model slot, a stand-in until it's imported, with its glow colours"] = function()
		local town = fs.readFile("src/shared/Config/Town.luau")
		local seen: { [string]: boolean } = {}
		for _, entry in entries() do
			if string.match(entry.body, 'kind = "Trophy"') then
				local prop = string.match(entry.body, 'prop = "([%w_]+)"')
				assert(prop and string.match(prop, "^Trophy%u%a+$"), `{entry.id} draws a Trophy<Boss> slot, not {prop}`)
				assert(not seen[prop :: string], `{entry.id} shares {prop} with another trophy`)
				seen[prop :: string] = true
				assert(string.find(town, "%s" .. prop .. " = { height = 0, collide = false, standIn = true }"), `Town.SLOTS.{prop}: a stand-in until its model is in`)
				assert(string.find(town, "%s" .. prop .. " = {[^\n]*}"), `TROPHY_LOOK.GLOWS has {prop}`)
				assert(string.match(entry.body, "propColors = { Gem = "), `{entry.id} lights its Gem in the boss's colour`)
			end
		end
		assert(not string.find(town, "%sTrophy = {"), "no shared Trophy slot left (its files would be every trophy's variants)")
	end,

	["each shelf type has its own look"] = function()
		local props: { [string]: string } = {}
		for _, entry in entries() do
			props[entry.id] = string.match(entry.body, 'prop = "([%w_]+)"') or ""
		end
		assert(props.WallShelf == "WallShelf", "WallShelf prop")
		assert(props.AccessoryHook == "HookRack", "AccessoryHook prop")
		assert(props.BigDisplayRack == "DisplayRack", "BigDisplayRack prop")
		assert(props.GlassShowcase == "CardCase", "GlassShowcase prop (the spinning-card case, UI project 3)")
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

	["the Forge is a Fixture from shop level 6 for $1,500 (weapons round 1)"] = function()
		for _, entry in entries() do
			if entry.id == "Forge" then
				assert(string.find(entry.body, 'kind = "Forge"', 1, true), "kind Forge")
				assert(string.find(entry.body, 'prop = "Forge"', 1, true), "prop Forge")
				assert(string.match(entry.body, "cost = (%d+)") == "1500", "costs $1,500")
				assert(string.match(entry.body, "unlockLevel = (%d+)") == "6", "opens at shop level 6")
				local x, y, z = string.match(entry.body, "size = Vector3.new%((%d+), (%d+), (%d+)%)")
				assert(tonumber(x) == 6 and tonumber(y) == 6 and tonumber(z) == 6, `Forge size {x} x {y} x {z}`)
				return
			end
		end
		error("no Forge entry")
	end,

	["the Collector Case is the spinning-card case in its own colours"] = function()
		for _, entry in entries() do
			if entry.id == "CollectorCase" then
				assert(string.find(entry.body, 'prop = "CardCase"', 1, true), "CollectorCase uses the CardCase")
				assert(string.find(entry.body, "cardsUpright = true", 1, true), "its cards stand up and spin")
				for _, part in { "Support", "Frame", "Carpet" } do
					assert(string.find(entry.body, part .. " = Color3", 1, true), `CollectorCase recolours {part}`)
				end
				return
			end
		end
		error("no CollectorCase entry")
	end,
}
