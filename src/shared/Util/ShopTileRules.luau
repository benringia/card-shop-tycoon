--!strict
-- The Shop window's layout numbers (Config/ShopTiles): how tall its list is on a screen, and how a phone's row tile
-- is put together. Pure (callers pass the config), Lune-tested; client Util/ShopTile applies it.
local ShopTileRules = {}

type Config = {
	FULL: { width: number, height: number, picture: number, gap: number },
	PHONE: { columns: number, height: number, picture: number, gap: number, nameSize: number, detailSize: number, button: number },
	WINDOW: { header: number, height: number, tabs: number, chrome: number, phoneHeight: number, phoneTabs: number, phoneChrome: number },
}

-- The list's height in a window on a screen `guiHeight` px tall (under Roblox's top bar)
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
