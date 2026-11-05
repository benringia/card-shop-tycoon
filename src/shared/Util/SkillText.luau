--!strict
-- A card's skills in words for the card view (the owner 2026-11-05: "Add Creature Skill to the creature card", option A
-- "a Skills box under the pills"): its element's Pet move and, for the cards that have one, its super move, each
-- with a line written from the fight's own numbers (Config/Combat ABILITIES and SIGNATURES). Roblox-free (Lune-tested).
local SkillText = {}

export type Skill = { kind: string, name: string, text: string }

local function percent(share: number): string
	return `{math.round(share * 100)}%`
end

local function seconds(value: number): string
	return `{value} s`
end

-- What one move does, in a short plain-ASCII line
function SkillText.describe(ability: any): string
	local kind = ability.kind
	if kind == "Fireball" then
		return `A big hit: {ability.power}x ATK`
	elseif kind == "Rain" then
		return `Heals your creature {percent(ability.heal)} over {seconds(ability.ticks * ability.every)}`
	elseif kind == "Snare" then
		return `Slows the foe {percent(ability.slow)} for {seconds(ability.seconds)}`
	elseif kind == "Overcharge" then
		return if ability.speed == 2 then `Next {ability.attacks} attacks twice as fast` else `Next {ability.attacks} attacks {ability.speed}x as fast`
	elseif kind == "Curse" then
		return `Foe hits {percent(ability.weaken)} weaker for {seconds(ability.seconds)}`
	elseif kind == "Inferno" then
		return `Burns the foe for {seconds(ability.seconds)}`
	elseif kind == "TidalShield" then
		return `A shield worth {percent(ability.shield)} of its HP`
	elseif kind == "Stampede" then
		return `A {ability.power}x hit and a {seconds(ability.stun)} stun`
	elseif kind == "Eclipse" then
		return `Dodges everything for {seconds(ability.seconds)}`
	elseif kind == "Supernova" then
		return `A huge {ability.power}x hit`
	elseif kind == "Devour" then
		return if ability.lifesteal == 0.5 then `A {ability.power}x hit that heals it for half` else `A {ability.power}x hit that heals it {percent(ability.lifesteal)}`
	end
	return ability.name
end

local function skill(ability: any): Skill
	return { kind = ability.kind, name = ability.name, text = SkillText.describe(ability) }
end

-- An element's place on the element wheel (Config/Combat BEATS): the elements it deals STRONG damage to, and the ones
-- that deal STRONG damage to it (it deals them WEAK damage), sorted
function SkillText.matchups(combat: any, element: string): { strong: { string }, weak: { string } }
	local strong = table.clone(combat.BEATS[element] or {})
	local weak = {}
	for other, beaten in combat.BEATS do
		if table.find(beaten, element) then
			table.insert(weak, other)
		end
	end
	table.sort(strong)
	table.sort(weak)
	return { strong = strong, weak = weak }
end

-- A card's skills: `pet` from its element, `super` from its name (nil: it has none)
function SkillText.forCard(combat: any, element: string, cardName: string): { pet: Skill, super: Skill? }
	local signature = combat.SIGNATURES[cardName]
	return { pet = skill(combat.ABILITIES[element]), super = if signature then skill(signature) else nil }
end

return SkillText
