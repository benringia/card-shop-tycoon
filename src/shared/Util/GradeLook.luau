--!strict
-- A card's grade you notice (Config/GradeLook, passed in as `look`): where the medal sits on a card and what it leaves
-- room for, how an A or S card glows, and what a pulled or dropped one says. Card widths from the card's top-left
-- corner, unless said otherwise. Pure (Lune-tested: tests/GradeLook.spec).
local GradeLook = {}

-- A square: its top-left corner and size
export type Square = { x: number, y: number, size: number }
export type Box = { x: number, y: number, w: number, h: number }

local function known(look: any, grade: string): string
	return if look.MEDAL[grade] then grade else "C"
end

-- The medal's circle, inside the card's top-right corner, bigger the better the grade
function GradeLook.medal(look: any, grade: string): Square
	local size = look.MEDAL[known(look, grade)]
	return { x = 1 - look.INSET - size, y = look.INSET, size = size }
end

-- The medal's picture: its circle in the middle, its soft shadow round it
function GradeLook.picture(look: any, grade: string): Square
	local circle = GradeLook.medal(look, grade)
	local size = circle.size / look.PICTURE
	local spare = (size - circle.size) / 2
	return { x = circle.x - spare, y = circle.y - spare, size = size }
end

-- The name's width from NAME.x, stopping NAME.gap short of the medal
function GradeLook.nameWidth(look: any, grade: string): number
	return GradeLook.medal(look, grade).x - look.NAME.gap - look.NAME.x
end

-- The Level chip, centred under the medal
function GradeLook.level(look: any, grade: string): Box
	local circle = GradeLook.medal(look, grade)
	local chip = look.LEVEL
	return { x = circle.x + circle.size / 2 - chip.w / 2, y = circle.y + circle.size + chip.gap, w = chip.w, h = chip.h }
end

-- How an A or S card glows (Config/GradeLook GLOW); nil: C and B stay calm
function GradeLook.glow(look: any, grade: string): any?
	return look.GLOW[grade]
end

-- An A or S card stands out where pulls are shown together (Open 10 dims the rest)
function GradeLook.standsOut(look: any, grade: string): boolean
	return look.GLOW[grade] ~= nil
end

-- The glow picture's size behind a card `aspect` (its width over its height) wide, as shares of the card's width and
-- height: as far past every edge (shares, not pixels: a window's UIScale scales them once)
function GradeLook.glowSize(look: any, aspect: number): (number, number)
	local reach = look.GLOW_PICTURE.reach
	return 1 + 2 * reach, 1 + 2 * reach * aspect
end

-- The ring round an A or S card `aspect` wide whose corner is `corner` of its width: the ring's size (shares of the
-- card's width and height) and its corner (a share of its shorter side, its width, as UICorner takes it)
function GradeLook.ring(look: any, grade: string, aspect: number, corner: number): (number, number, number)
	local glow = look.GLOW[grade]
	local width = if glow then glow.width else 0
	return 1 + 2 * width, 1 + 2 * width * aspect, (corner + width) / (1 + 2 * width)
end

-- An S card's sparkle `index`: its middle (card widths across, card heights down) and size; `inside` (a card on its own
-- 3D surface, which can't draw past its edges): moved in so it stays whole
function GradeLook.sparkle(look: any, index: number, inside: boolean): Square
	local spot = look.SPARKLES[index]
	local x = spot.x
	if inside then
		local edge = look.TWINKLE.inside + spot.size / 2
		x = math.clamp(x, edge, 1 - edge)
	end
	return { x = x, y = spot.y, size = spot.size }
end

-- What a pulled card says out loud ("GRADE S!"); nil for C and B
function GradeLook.callout(look: any, grade: string): string?
	return look.CALLOUT.words[grade]
end

-- A dropped card's tag ("Voidmaw · Grade A!"); nil for C and B
function GradeLook.dropTag(look: any, name: string, grade: string): string?
	if not look.GLOW[grade] then
		return nil
	end
	return string.format(look.DROP.words, name, grade)
end

return GradeLook
