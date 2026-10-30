--!strict
-- Which painting a card face draws (Config/CardArt): the half-size copy wherever the face is drawn no taller than it,
-- the full painting only for big views (a missing copy falls back to the full one). Pure, Lune-tested; CardFace calls
-- it with the art's drawn height, again whenever that changes.
local CardArt = {}

function CardArt.pick(name: string, drawnHeight: number, art: any): string?
	local small = art.SMALL[name]
	if small and small ~= "" and drawnHeight <= art.SMALL_HEIGHT then
		return small
	end
	return art.FULL[name]
end

return CardArt
