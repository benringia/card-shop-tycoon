--!strict
-- The Wild's dangerous places (owner 2026-11-11/12; spec 2026-11-12-wild-danger-character-window-design): what a
-- chasing monster's contact does, and when a lost fight knocks you out. Pure, Lune-tested.
local DangerRules = {}

export type Contact = {
	fighting: boolean, -- already in a fight
	locked: boolean, -- the party locked (a cinematic, a fight starting)
	hasCard: boolean, -- any card in the party
	summoned: boolean, -- a card is out
	summonedRested: boolean, -- and it can fight
	restedSlot: number?, -- the first party slot with a rested card (the lead first)
	hasSword: boolean,
}

-- "none" (nothing), "fight" (today's try to start), "summon" (that slot first, then the fight), "swordOnly" (you alone),
-- "shove" (it shoves you off and leaves: nothing to fight with). The same in every place: only chasing monsters (elites,
-- aggro zones) catch anyone (owner 2026-11-12: "elite/aggressive monsters should still attack me")
function DangerRules.onContact(s: Contact): (string, number?)
	if s.fighting or s.locked then
		return "none"
	end
	if s.summoned and s.summonedRested then
		return "fight"
	end
	if s.restedSlot then
		return "summon", s.restedSlot
	end
	if s.hasCard and s.hasSword then
		return "swordOnly"
	end
	return "shove"
end

-- The share of a wild monster's swings that go at the player while their creature stands (owner 2026-11-12: "elite/
-- aggressive monsters should still attack me even if my summons are not dead"): elites anywhere and every monster of
-- an aggro or dangerous place; nil for the rest (pets first, Combat.PLAYER_TARGET_SHARE)
function DangerRules.playerShare(elite: boolean, zone: { aggro: boolean?, danger: boolean? }?, share: number): number?
	if elite or (zone ~= nil and (zone.aggro == true or zone.danger == true)) then
		return share
	end
	return nil
end

-- Whether a fight's end knocks the player out: a lost wild fight in a dangerous place (a boss or a Dungeon room keeps
-- its own defeat)
function DangerRules.knockout(result: string, danger: boolean, boss: boolean, run: boolean): boolean
	return result == "lose" and danger and not boss and not run
end

return DangerRules
