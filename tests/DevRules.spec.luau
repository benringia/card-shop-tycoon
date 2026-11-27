--!strict
-- Who may run a dev command, and where (spec 2026-11-27-live-admin-creator-design; owner 2026-11-27: "proper admin
-- UI I can publish that only I can use", pick A: the test save only). Studio: anyone, as before. The published game:
-- only the game's owner, only on their test save; a command that changes other players' game only when the owner is
-- alone or in their own private server; Studio-only commands never.
local AdminPanel = require("../src/shared/Config/AdminPanel")
local DevRules = require("../src/server/Util/DevRules")
local expect = require("./lib/expect")
local fs = require("@lune/fs")

local LIVE: DevRules.Facts = { studio = false, owner = true, testSlot = true, players = 3, privateOwner = false }

-- LIVE with some facts changed
local function with(changes: { [string]: any }): DevRules.Facts
	local facts = table.clone(LIVE) :: any
	for key, value in changes do
		facts[key] = value
	end
	return facts
end

local function verdict(facts: DevRules.Facts, scope: DevRules.Scope): string
	local ok, reason = DevRules.check(facts, scope)
	return if ok then "yes" else reason or "no reason"
end

return {
	["Studio: anyone may run any command"] = function()
		local stranger = { studio = true, owner = false, testSlot = false, players = 5, privateOwner = false }
		for _, scope in { "own", "server", "studio" } :: { DevRules.Scope } do
			expect.equal(verdict(stranger, scope), "yes", scope)
		end
	end,

	["live: anyone but the owner is refused (notOwner), even with a test save flag"] = function()
		expect.equal(verdict(with({ owner = false }), "own"), "notOwner")
		expect.equal(verdict(with({ owner = false, players = 1 }), "server"), "notOwner")
		expect.equal(verdict(with({ owner = false, testSlot = false }), "own"), "notOwner")
	end,

	["live: the owner's real save is refused (mainSave), also before the save has loaded"] = function()
		expect.equal(verdict(with({ testSlot = false }), "own"), "mainSave")
		expect.equal(verdict(with({ testSlot = false, players = 1 }), "server"), "mainSave")
	end,

	["live: the owner's test save runs their own commands"] = function()
		expect.equal(verdict(LIVE, "own"), "yes")
	end,

	["live: a command that changes other players' game needs the owner alone or in their own private server"] = function()
		expect.equal(verdict(LIVE, "server"), "notAlone")
		expect.equal(verdict(with({ players = 1 }), "server"), "yes", "alone")
		expect.equal(verdict(with({ privateOwner = true }), "server"), "yes", "their own private server")
	end,

	["live: a Studio-only command is refused (studioOnly)"] = function()
		expect.equal(verdict(LIVE, "studio"), "studioOnly")
		expect.equal(verdict(with({ players = 1, privateOwner = true }), "studio"), "studioOnly")
	end,

	["scope: own unless the table says server or studio"] = function()
		expect.equal(DevRules.scope(AdminPanel, "cash"), "own")
		expect.equal(DevRules.scope(AdminPanel, "time"), "server")
		expect.equal(DevRules.scope(AdminPanel, "event"), "server")
		expect.equal(DevRules.scope(AdminPanel, "room"), "server")
		expect.equal(DevRules.scope(AdminPanel, "jobslot"), "studio")
		expect.equal(DevRules.scope(AdminPanel, "nonsense"), "own", "an unknown alias is refused by DevService, not here")
	end,

	-- Final review: these make every player in the server see a find that never happened ("found Stormking!", a new
	-- Legendary weapon's announcement), so they wait until the owner is alone or in their own private server
	["scope: commands that announce a pretend find to the whole server are server commands"] = function()
		for _, alias in { "frontierdrop", "weapondrop", "bosscard", "carddrop" } do
			expect.equal(DevRules.scope(AdminPanel, alias), "server", alias)
		end
	end,

	["scope: the table names only commands DevService registers"] = function()
		local source = fs.readFile("src/server/Services/DevService.luau")
		local aliases = {}
		for alias in string.gmatch(source, 'addCommand%(folder, "(%w+)"') do
			aliases[alias] = true
		end
		local count = 0
		for alias, scope in AdminPanel.SCOPE do
			count += 1
			expect.equal(aliases[alias] == true, true, `/{alias} is a command`)
			expect.equal(scope == "server" or scope == "studio", true, `/{alias}'s scope`)
		end
		expect.equal(count >= 15, true, "the server list and jobslot")
	end,

	["refusals have plain words for the owner"] = function()
		for _, reason in { "mainSave", "notAlone", "studioOnly" } do
			local words = AdminPanel.REFUSE[reason]
			expect.equal(type(words) == "string" and #words > 10, true, reason)
		end
		expect.equal(string.find(AdminPanel.REFUSE.mainSave, "/slot test", 1, true) ~= nil, true, "how to get there")
	end,
}
