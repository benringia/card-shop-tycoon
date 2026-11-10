--!strict
-- The pack opening's sounds (spec 2026-11-09-tutorial-pish-design 16): the owner found the rip loud and the lineup
-- sounding like a boss win
local Victory = require("../src/shared/Config/Victory")
local expect = require("./lib/expect")

-- Config/PackOpening builds Vector3s, so Lune reads its text: each sound's id and volume by name
local function openingSounds(): ({ [string]: string }, { [string]: number })
	local source = require("@lune/fs").readFile("src/shared/Config/PackOpening.luau")
	local ids, volumes = {}, {}
	for name, id in string.gmatch(source, "(%w+) = \"(rbxassetid://%d+)\"") do
		ids[name] = id
	end
	for name, volume in string.gmatch(source, "(%w+) = ([%d%.]+)[,\n]") do
		volumes[name] = tonumber(volume) :: number
	end
	return ids, volumes
end

return {
	["the rip is soft: the tear and the crinkle at about half their first levels (owner: lower the ripping sound)"] = function()
		local _, volumes = openingSounds()
		assert(volumes.snap and volumes.snap <= 0.3, `the tear at {volumes.snap}`)
		assert(volumes.crinkle and volumes.crinkle <= 0.35, `the crinkle at {volumes.crinkle}`)
	end,

	["the lineup's sounds aren't the boss victory's (owner: it sounds like killing a boss)"] = function()
		local ids = openingSounds()
		local victory = {}
		for moment, id in Victory.SOUNDS do
			victory[id] = moment
		end
		for _, key in { "land", "chime" } do
			local id = ids[key]
			assert(id ~= nil, `the lineup's {key} sound is set`)
			expect.equal(victory[id], nil, `the lineup's {key} is the victory's {victory[id]}`)
		end
	end,
}
