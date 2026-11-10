--!strict
-- Every combat sound id the super moves, Pet button moves, basic attacks and swords play (Config/SuperFx, Config/MoveFx,
-- Config/AttackFx SOUNDS, Config/Swords each sword's sounds) and Pish's (Config/Pish SOUNDS), one per line as "<config>.<path> <id>", for measuring their loudness in Studio
-- (docs/sounds.md "Skill loudness"). Usage: lune run tools/audio/sound_ids
local SuperFx = require("../../src/shared/Config/SuperFx")
local MoveFx = require("../../src/shared/Config/MoveFx")
local AttackFx = require("../../src/shared/Config/AttackFx")
local Swords = require("../../src/shared/Config/Swords")
local Pish = require("../../src/shared/Config/Pish")

local function walk(prefix: string, value: any)
	if type(value) == "string" then
		print(`{prefix} {value}`)
	elseif type(value) == "table" then
		local keys = {}
		for key in value do
			table.insert(keys, tostring(key))
		end
		table.sort(keys)
		for _, key in keys do
			walk(`{prefix}.{key}`, value[key])
		end
	end
end

walk("SuperFx", SuperFx.SOUNDS)
walk("MoveFx", MoveFx.SOUNDS)
walk("AttackFx", AttackFx.SOUNDS)
walk("Pish", Pish.SOUNDS)
for id, sword in Swords.SWORDS do
	walk(`Swords.{id}`, sword.sounds)
end
