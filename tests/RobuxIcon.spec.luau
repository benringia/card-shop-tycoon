--!strict
-- Owner 2026-11-17: "can the R$ be replaced with an actual robux icon". Robux prices go through client
-- Util/RobuxPrice (Roblox's own Robux glyph, tinted like the button's text), never the letters "R$" in player text.
local fs = require("@lune/fs")
local expect = require("./lib/expect")

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

-- A line's code without its comment (a "--" outside a string is close enough here)
local function codeOf(line: string): string
	local at = string.find(line, "--", 1, true)
	return if at then string.sub(line, 1, at - 1) else line
end

return {
	["no player text spells a Robux price as R$"] = function()
		local files = {}
		listFiles("src", files)
		local found = {}
		for _, path in files do
			for number, line in string.split(fs.readFile(path), "\n") do
				if string.find(codeOf(line), "R$", 1, true) then
					table.insert(found, `{path}:{number}`)
				end
			end
		end
		expect.equal(table.concat(found, ", "), "", "R$ in code: show the Robux icon with Util/RobuxPrice")
	end,

	["the Robux price helper exists and uses Roblox's Robux glyph"] = function()
		local source = fs.readFile("src/client/Util/RobuxPrice.luau")
		assert(string.find(source, "rbxasset://textures/ui/common/robux", 1, true), "Roblox's own Robux glyph")
	end,
}
