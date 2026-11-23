--!strict
-- The Shop window's layout numbers (Config/ShopTiles): how tall its list is on a screen, and how a phone's row tile
-- is put together. Pure (callers pass the config), Lune-tested; client Util/ShopTile applies it.
local ShopTileRules = {}

type Config = {
	FULL: { columns: number, height: number, picture: number, gap: number },
	PHONE: { columns: number, height: number, picture: number, gap: number, nameSize: number, detailSize: number, button: number },
	WINDOW: { header: number, height: number, tabs: number, chrome: number, phoneHeight: number, phoneTabs: number, phoneChrome: number },
}

-- The list's height in a window on a screen `guiHeight` px tall (under Roblox's top bar)
-- Whether a tile wears the NEW tag (client Util/NewTag): its thing unlocked at this shop level or the one before.
-- What a new shop starts with (level 1) is never news, and a locked tile shows its lock instead
function ShopTileRules.isNew(level: number, unlockLevel: number): boolean
	return unlockLevel > 1 and level >= unlockLevel and level - unlockLevel <= 1
end

-- A tile's line as chips (owner 2026-11-23, Shop A): "Holds 24 · Any stock" -> two chips, the first the main one (what
-- it holds, mint), the rest soft; an empty line, none
function ShopTileRules.chips(line: string): { { text: string, main: boolean } }
	local chips = {}
	for _, part in string.split(line, " · ") do
		local text = string.match(part, "^%s*(.-)%s*$") or ""
		if text ~= "" then
			table.insert(chips, { text = text, main = #chips == 0 })
		end
	end
	return chips
end

-- Whether a tile's button shows a price (a coin beside it): "$350" does, "Use", "Place", "🔒 Lv 9" don't
function ShopTileRules.isPrice(text: string): boolean
	return string.match(text, "^%$%d") ~= nil
end

-- "You have 2" over a tile's picture; nil (no badge) while you have none
function ShopTileRules.ownedText(count: number): string?
	return if count > 0 then `You have {count}` else nil
end

function ShopTileRules.listHeight(cfg: Config, guiHeight: number, phone: boolean): number
	local window = cfg.WINDOW
	local share = if phone then window.phoneHeight else window.height
	local chrome = if phone then window.phoneChrome else window.chrome
	return math.floor(guiHeight * share) - chrome
end

-- A tile's height
function ShopTileRules.tileHeight(cfg: Config, phone: boolean): number
	return if phone then cfg.PHONE.height else cfg.FULL.height
end

-- A phone's row tile: the picture's square on the left, the name and the line beside its top, the button under them
-- (offsets in px from the tile's top left; `beside`: where the words and the button start, `margin`: the tile's edge)
function ShopTileRules.row(cfg: Config): { picture: number, beside: number, margin: number, nameY: number, nameHeight: number, detailY: number, detailHeight: number, button: number }
	local look = cfg.PHONE
	return {
		picture = look.picture,
		beside = look.picture + 16,
		margin = 8,
		nameY = 6,
		nameHeight = look.nameSize + 5,
		detailY = 6 + look.nameSize + 5,
		detailHeight = look.detailSize + 4,
		button = look.button,
	}
end

return ShopTileRules
