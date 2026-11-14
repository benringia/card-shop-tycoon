--!strict
-- What a summoned creature's name tag shows, and where it sits (owner 2026-11-14, option B of three: the gacha title;
-- tests/CreatureTag). Its stars crown the name (earned ones bright, the rest faint), the name big in its rarity
-- colour, a pill under it with the element, level and grade, and the owner's name small on top, only on other
-- players' creatures (like the pet games: your own never repeats your name). Roblox-free; drawn by client
-- Util/CreatureTagGui with Party.TAG's sizes.
local CreatureTag = {}

export type Input = {
	cardName: string?,
	level: any, -- the marker's attributes, as they come
	stars: any,
	grade: any,
	foil: boolean?,
	ownerName: string?, -- the owner's display name, nil when they've left
	mine: boolean,
	maxStars: number,
}

export type Info = {
	owner: string?,
	stars: number,
	emptyStars: number,
	name: string,
	level: string,
	grade: string,
	foil: boolean,
}

local GRADES = { C = true, B = true, A = true, S = true }

function CreatureTag.info(input: Input): Info
	local stars = if typeof(input.stars) == "number" then math.clamp(math.floor(input.stars), 0, input.maxStars) else 0
	local level = if typeof(input.level) == "number" then math.max(1, math.floor(input.level)) else 1
	return {
		owner = if input.mine then nil else input.ownerName,
		stars = stars,
		emptyStars = input.maxStars - stars,
		name = input.cardName or "Creature",
		level = `Lv {level}`,
		grade = if typeof(input.grade) == "string" and GRADES[input.grade] then input.grade else "C",
		foil = input.foil == true,
	}
end

-- The tag's height in pixels: the owner's line, the stars, the name and the pill, with a gap between each
function CreatureTag.height(tag: any): number
	return tag.OWNER + tag.STARS + tag.NAME + tag.PILL + 3 * tag.GAP
end

-- Its billboard's SizeOffset Y (fractions of its height, up): the bottom stays BELOW pixels under its point, where
-- the old one-line tag's bottom was, and it grows upward
function CreatureTag.lift(tag: any): number
	local height = CreatureTag.height(tag)
	return (height / 2 - tag.BELOW) / height
end

-- The "+ Healing" pill's SizeOffset Y (Util/HealFx, HEAL_PILL tall, the same point): resting a gap above the tag's top
function CreatureTag.healLift(tag: any): number
	local top = CreatureTag.height(tag) - tag.BELOW + tag.GAP
	return (top + tag.HEAL_PILL / 2) / tag.HEAL_PILL
end

return CreatureTag
