--!strict
-- What players read for each element (owner 2026-11-12: "let's just call them water, fire, electric, dark and so on",
-- "replace everywhere"). Saved data, configs and code keep the internal keys (Ember, Tide, Bloom, Volt, Shade); every
-- player-facing text goes through Util/ElementNames. The icons are images (Config/UIIcons by the same keys).
return {
	Ember = "Fire",
	Tide = "Water",
	Bloom = "Nature",
	Volt = "Electric",
	Shade = "Dark",
	ORDER = { "Ember", "Bloom", "Tide", "Volt", "Shade" }, -- the wheel: Fire beats Nature beats Water beats Fire, Electric and Dark each other
}
