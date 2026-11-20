--!strict
-- The binder's card view (client CardDetailController, rules in Util/CardViewRules). Owner 2026-11-21: "make this
-- suitable for a person with low attention span. relayout this, only display what is important": it opens on this
-- copy (grade, level, stars, one big Power, XP and next star) and what it's strong and weak against; skills, buffs,
-- the element numbers, the other stats and the sell hint wait behind the More button. Plain data, Lune-tested.
return {
	-- the More button's words, and its height in px (a tap target)
	TOGGLE = { more = "More about this card", less = "Show less" },
	TOGGLE_HEIGHT = 48,
	-- never more than this many things in the simple view
	SIMPLE_MAX = 4,
	-- the big Power number's text size and its tile's height in px
	POWER = { size = 30, height = 52 },
	-- a matchup chip's height in px
	CHIP_HEIGHT = 34,
}
