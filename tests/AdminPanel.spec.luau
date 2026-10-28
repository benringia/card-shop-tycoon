--!strict
local AdminPanel = require("../src/shared/Config/AdminPanel")
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

	["admin panel: typed commands fill in the text box"] = function()
		expect.equal(AdminPanel.fill("/maxcard %s foil", "solarion"), "/maxcard solarion foil", "fills the input")
		expect.equal(AdminPanel.fill("/maxcard %s", "  "), nil, "an empty input sends nothing")
		expect.equal(AdminPanel.fill("/cash 1000", ""), "/cash 1000", "no input needed")
	end,
}
