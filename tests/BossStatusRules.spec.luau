--!strict
local BossStatusRules = require("../src/shared/Util/BossStatusRules")
local BossStatus = require("../src/shared/Config/BossStatus")
local expect = require("./lib/expect")

-- The owner 2026-11-12: "every boss debuff should be shown below their healthbar with tooltips"
return {
	["every state the sim reports has an icon, a name, a colour and a tooltip"] = function()
		for _, kind in { "shield", "guarded", "enraged", "stunned", "snared", "cursed", "burning" } do
			local look = BossStatus.KINDS[kind]
			assert(look, `{kind} has a look`)
			expect.equal(#look.icon > 0 and #look.name > 0 and #look.color == 3, true, `{kind}'s icon, name, colour`)
			expect.equal(#look.about > 0 and #look.plain > 0, true, `{kind}'s tooltip, and one without numbers`)
			expect.equal(table.find(BossStatus.ORDER, kind) ~= nil, true, `{kind} has its place in the row`)
			-- plain ASCII, the middle dot and emoji only (Gotham/Fredoka draw other symbols as boxes)
			for _, text in { look.name, look.about, look.plain } do
				expect.equal(string.find(text, "[\128-\255]") == nil, true, `{kind}: "{text}" is plain ASCII`)
			end
		end
		expect.equal(BossStatus.PHONE_CHIP >= 48, true, "a phone's tap target")
		expect.equal(BossStatus.TOOLTIP_SECONDS >= 2, true, "a tapped tooltip stays long enough to read")
	end,

	["the row: in its order, unknown kinds left out"] = function()
		local row = BossStatusRules.sorted({ { kind = "burning", seconds = 2 }, { kind = "mystery" }, { kind = "shield", value = 900 }, { kind = "stunned", seconds = 1 } }, BossStatus)
		expect.equal(#row, 3)
		expect.equal(row[1].kind, "shield")
		expect.equal(row[2].kind, "stunned")
		expect.equal(row[3].kind, "burning")
		expect.equal(BossStatusRules.key(row), "shield,stunned,burning", "what changes the row")
		expect.equal(#BossStatusRules.sorted(nil, BossStatus), 0, "none sent: an empty row")
	end,

	["a chip's number: seconds left, a shield's size, a percentage"] = function()
		expect.equal(BossStatusRules.badge({ kind = "stunned", seconds = 2.2 }), "3s", "seconds up")
		expect.equal(BossStatusRules.badge({ kind = "shield", value = 3600 }), "3.6k")
		expect.equal(BossStatusRules.badge({ kind = "shield", value = 450 }), "450")
		expect.equal(BossStatusRules.badge({ kind = "enraged", value = 15 }), "+15%")
		expect.equal(BossStatusRules.badge({ kind = "guarded", value = 50 }), "-50%")
		expect.equal(BossStatusRules.badge({ kind = "enraged" }), "", "nothing to show")
	end,

	["a tooltip: its name and what it does, with its numbers"] = function()
		local title, about = BossStatusRules.text({ kind = "cursed", value = 30, seconds = 3.4 }, BossStatus)
		expect.equal(string.find(title, BossStatus.KINDS.cursed.name, 1, true) ~= nil, true, "its name")
		expect.equal(string.find(about, "30%", 1, true) ~= nil, true, "how much weaker")
		expect.equal(string.find(about, "4s", 1, true) ~= nil, true, "for how long")
		local _, plain = BossStatusRules.text({ kind = "enraged" }, BossStatus)
		expect.equal(plain, BossStatus.KINDS.enraged.plain, "no number: its plain words")
		expect.equal(string.find(plain, "{", 1, true), nil, "never a placeholder left")
	end,
}
