--!strict
-- Icons made of other icons (client Util/Icon draws them like any Config/UIIcons name): each layer is a UIIcons
-- picture at x, y (its centre) and size, all as a share of the icon's holder, turned `rotation` degrees, drawn from the
-- first layer up. Plain data, Lune-tested (tests/IconStacks).
export type Layer = { icon: string, x: number, y: number, size: number, rotation: number }

return {
	-- To Bag (owner 2026-11-17 picked B of three: "a pack dropping in"): the backpack with a gold First Spark pack by
	-- it and a blue arrow pointing down into it, so it never reads as the Bag button
	ToBag = {
		{ icon = "Bag", x = 0.55, y = 0.6, size = 0.98, rotation = 0 },
		{ icon = "BoosterPack", x = 0.24, y = 0.24, size = 0.66, rotation = -18 },
		{ icon = "Next", x = 0.86, y = 0.12, size = 0.46, rotation = 90 },
	},
} :: { [string]: { Layer } }
