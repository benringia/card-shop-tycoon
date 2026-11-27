--!strict
local AdminPanel = require("../src/shared/Config/AdminPanel")
local CardList = require("../src/shared/Config/CardList")
local Pish = require("../src/shared/Config/Pish")
local expect = require("./lib/expect")
local fs = require("@lune/fs")

-- The chat commands DevService registers ("/cash" -> "cash")
local function registered(): { [string]: boolean }
	local source = fs.readFile("src/server/Services/DevService.luau")
	local aliases = {}
	for alias in string.gmatch(source, 'addCommand%(folder, "(%w+)"') do
		aliases[alias] = true
	end
	return aliases
end

return {
	["admin panel: every button sends a command DevService knows"] = function()
		local aliases = registered()
		local count = 0
		for _, section in AdminPanel.SECTIONS do
			for _, button in section.buttons do
				count += 1
				local alias = string.match(button.command, "^/(%w+)")
				expect.equal(alias ~= nil and aliases[alias] == true, true, `{button.label}: {button.command}`)
			end
		end
		expect.equal(count > 10, true, "the panel has buttons")
		expect.equal(aliases.item and aliases.boss, true, "items and bosses (built from their configs) exist too")
	end,

	["admin panel: a Weapons section gives weapons and boss materials (weapons round 1)"] = function()
		local aliases = registered()
		expect.equal(aliases.weapon and aliases.material, true, "/weapon and /material exist")
		local commands = {}
		for _, section in AdminPanel.SECTIONS do
			if section.title == "Weapons" then
				for _, button in section.buttons do
					commands[string.match(button.command, "^/(%w+)") or ""] = true
				end
			end
		end
		expect.equal(commands.weapon and commands.material and commands.item, true, "weapon, material and Wild Ore buttons")
	end,

	["admin panel: a Pish section runs the tutorial, each lesson visit and his luck"] = function()
		local commands = {}
		for _, section in AdminPanel.SECTIONS do
			if section.title == "Pish (tutorial)" then
				for _, button in section.buttons do
					commands[button.command] = true
				end
			end
		end
		for _, command in { "/tutorial reset", "/tutorial step %s", "/pish", "/pishluck" } do
			expect.equal(commands[command], true, command)
		end
		for _, lesson in Pish.LESSONS do
			expect.equal(commands[`/tutorial lesson {lesson.id}`], true, `lesson {lesson.id}`)
		end
	end,

	["admin panel: a Chikin section runs his combat tutorial"] = function()
		local commands = {}
		for _, section in AdminPanel.SECTIONS do
			if section.title == "Chikin (combat tutorial)" then
				for _, button in section.buttons do
					commands[button.command] = true
				end
			end
		end
		for _, command in { "/chikin reset", "/chikin step %s" } do
			expect.equal(commands[command], true, command)
		end
	end,

	-- The boss chests (spec 2026-11-11-boss-chests-design): /chests shows them for a boss without a fight or a reward
	["admin panel: the Weapons section previews the boss chests"] = function()
		local aliases = registered()
		expect.equal(aliases.chests, true, "/chests exists")
		local found = false
		for _, section in AdminPanel.SECTIONS do
			for _, button in section.buttons do
				if section.title == "Weapons" and string.match(button.command, "^/chests") then
					found = true
				end
			end
		end
		expect.equal(found, true, "a Boss chests button")
	end,

	-- The Dungeon's puzzles (spec 2026-11-11-dungeon-puzzles): /puzzle solve solves the one the run is at (Studio)
	["admin panel: the Dungeon section solves the current puzzle"] = function()
		local aliases = registered()
		expect.equal(aliases.puzzle, true, "/puzzle exists")
		local found = false
		for _, section in AdminPanel.SECTIONS do
			for _, button in section.buttons do
				if string.match(section.title, "^Dungeon") and button.command == "/puzzle solve" then
					found = true
				end
			end
		end
		expect.equal(found, true, "a Solve puzzle button")
	end,

	["admin panel: typed commands fill in the text box"] = function()
		expect.equal(AdminPanel.fill("/maxcard %s foil", "solarion"), "/maxcard solarion foil", "fills the input")
		expect.equal(AdminPanel.fill("/maxcard %s", "  "), nil, "an empty input sends nothing")
		expect.equal(AdminPanel.fill("/cash 1000", ""), "/cash 1000", "no input needed")
	end,

	-- Owner 2026-11-27: "this will help me record some footage for marketing without grinding as much" (spec
	-- 2026-11-27-live-admin-creator-design): one-tap setups at the top of the panel
	["admin panel: Footage comes first, with Late game, Full shop and Golden hour"] = function()
		local first = AdminPanel.SECTIONS[1]
		expect.equal(first.title, "Footage")
		local commands = {}
		for _, button in first.buttons do
			table.insert(commands, button.command)
		end
		expect.equal(table.concat(commands, ", "), "/footage late, /footage shop, /footage golden")
		expect.equal(registered().footage, true, "/footage exists")
	end,

	["admin panel: every Footage step is a command DevService knows"] = function()
		local aliases = registered()
		for _, preset in { "shop", "golden" } do
			for _, command in AdminPanel.FOOTAGE[preset].commands do
				local alias = string.match(command, "^/(%w+)")
				expect.equal(alias ~= nil and aliases[alias] == true, true, `{preset}: {command}`)
			end
		end
		expect.equal(AdminPanel.FOOTAGE.golden.commands[1], "/time sunset")
	end,

	["admin panel: Late game is shop Lv 60, $1,000,000, three maxed Legendaries and every weapon S 10 Legendary"] = function()
		local late = AdminPanel.FOOTAGE.late
		expect.equal(late.level, 60)
		expect.equal(late.cash, 1000000)
		expect.equal(late.weapon.grade, "S")
		expect.equal(late.weapon.level, 10)
		expect.equal(late.weapon.mutation, "Legendary")
		expect.equal(#late.party, 3, "a full party")
		local rarities = {}
		for _, set in { CardList.SET1, CardList.FRONTIER } do
			for _, row in set do
				rarities[row[1]] = row[3]
			end
		end
		for _, name in late.party do
			expect.equal(rarities[name], "Legendary", name)
		end
	end,
}
