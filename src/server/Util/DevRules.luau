--!strict
-- Who may run a dev command, and where (spec docs/superpowers/specs/2026-11-27-live-admin-creator-design.md; owner
-- 2026-11-27: "proper admin UI I can publish that only I can use", pick A: the test save only). Studio: anyone, as
-- before. The published game: only the game's owner, only on their test save (their real save, the leaderboards and the
-- analytics stay clean); a command that changes other players' game ("server" scope) only when the owner is alone in the
-- server or in their own private server; a "studio" command never. Pure, Lune-tested (tests/DevRules); Util/DevAccess
-- gathers the facts.
local DevRules = {}

export type Facts = {
	studio: boolean, -- running in Studio
	owner: boolean, -- the game's owner (Util/SaveSlots.isOwner)
	testSlot: boolean, -- playing their test save (the server-set TestSave attribute; false until the save has loaded)
	players: number, -- players in this server
	privateOwner: boolean, -- this is the player's own private server
}
export type Scope = "own" | "server" | "studio"
export type Reason = "notOwner" | "mainSave" | "notAlone" | "studioOnly"

-- A command's scope (Config/AdminPanel SCOPE); every command not listed only changes the owner's own game
function DevRules.scope(cfg: any, alias: string): Scope
	local scope = cfg.SCOPE[alias]
	if scope == "server" or scope == "studio" then
		return scope
	end
	return "own"
end

-- Whether a command of `scope` runs for these facts, and why not
function DevRules.check(facts: Facts, scope: Scope): (boolean, Reason?)
	if facts.studio then
		return true, nil
	end
	if not facts.owner then
		return false, "notOwner"
	end
	if not facts.testSlot then
		return false, "mainSave"
	end
	if scope == "studio" then
		return false, "studioOnly"
	end
	if scope == "server" and not (facts.players == 1 or facts.privateOwner) then
		return false, "notAlone"
	end
	return true, nil
end

return DevRules
