--!strict
local AdminPanel = require("../src/shared/Config/AdminPanel")
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

	["admin panel: typed commands fill in the text box"] = function()
		expect.equal(AdminPanel.fill("/maxcard %s foil", "solarion"), "/maxcard solarion foil", "fills the input")
		expect.equal(AdminPanel.fill("/maxcard %s", "  "), nil, "an empty input sends nothing")
		expect.equal(AdminPanel.fill("/cash 1000", ""), "/cash 1000", "no input needed")
	end,
}
