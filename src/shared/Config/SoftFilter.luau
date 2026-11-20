--!strict
-- The soft colour filter (owner 2026-11-21: "can we put a filter so the colors are not too sharp/saturated?"): one
-- dial over every sky look's colour grading (Util/SkyLook applies it: the town's day cycle, the valleys, the arenas).
-- `saturation` and `contrast` are added to each look's own (the town's looks run +0.12 to +0.22 saturation, so -0.2
-- brings them to about neutral); a look never goes under FLOOR saturation because of the filter (never grey).
-- ON false: the looks as they were. The UI's colours are its theme's (Config/CreamTheme, BabyColors), not this.
-- Plain data, Lune-tested (tests/SoftFilter).
return {
	ON = true,
	saturation = -0.2,
	contrast = -0.05,
	FLOOR = -0.25,
}
