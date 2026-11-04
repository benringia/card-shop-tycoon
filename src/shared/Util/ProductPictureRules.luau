--!strict
-- Which picture a pack or deck box shows in a menu row (spec 2026-11-04-round5-design section 6): its look's uploaded
-- picture, else the drawn icon. Pure (no requires, no Roblox APIs): callers pass Config/ProductPictures in.
local ProductPictureRules = {}

type Config = {
	LOOKS: { [string]: { [string]: string } },
	FALLBACK: { [string]: string },
}

-- The picture's image id (nil until the look has one) and the icon name to show without it
function ProductPictureRules.pick(cfg: Config, look: string, kind: "Pack" | "Deck"): (string?, string)
	local pictures = cfg.LOOKS[look]
	return if pictures then pictures[kind] else nil, cfg.FALLBACK[kind]
end

-- Whether the drawn icon shows under a picture: until the picture has downloaded (still processing after the upload, or
-- rejected), so the slot is never empty
function ProductPictureRules.showIcon(imageReady: boolean): boolean
	return not imageReady
end

return ProductPictureRules
