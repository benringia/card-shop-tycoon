--!strict
-- A weapon's card (owner's pick 2026-11-06: A, the creature card's shape; spec 2026-11-06-weapons-round1-design 6):
-- the Armory, the Forge, the Boss Board. Drawn with CardFace's pieces so it matches the binder's cards.
--   owned: the rarity's rim, its portrait (Config/WeaponLooks) over the Armory cover painting, dimmed, with soft rays and
--          its glow colour behind it (owner's pick 1B, 2026-11-09; no portrait: a big sword), its element and name,
--          grade, +level, and its Power where a card shows its value
--   locked: the missing card's dark rim, the same painting dark, the portrait as a black shadow under a lock (owner's
--          pick 2B), where it comes from (WeaponText.source) and the progress toward forging it (the main material)
--   not built yet: the same, "Coming soon"
-- The Steel Sword is everyone's: always drawn owned.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BinderCovers = require(Config:WaitForChild("BinderCovers"))
local Bosses = require(Config:WaitForChild("Bosses"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local Combat = require(Config:WaitForChild("Combat"))
local PackFx = require(Config:WaitForChild("PackFx"))
local Rarities = require(Config:WaitForChild("Rarities"))
local UIIcons = require(Config:WaitForChild("UIIcons"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local Weapons = require(Config:WaitForChild("Weapons"))
local WeaponRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponRules"))
local WeaponText = require(Shared:WaitForChild("Util"):WaitForChild("WeaponText"))

local ClientUtil = script.Parent :: Instance
local CardFace = require(ClientUtil:WaitForChild("CardFace"))

export type Owned = WeaponRules.Owned
export type Progress = { have: number, need: number }

local WeaponFace = {}

local P = CardFace.parts
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local SWORD = "⚔️"
local PROGRESS_FILL = Color3.fromRGB(142, 235, 120)
local CARD = WeaponLooks.CARD
local BACKDROP = BinderCovers.SETS.Armory.art

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- The element emoji before its name: its element's, a rainbow for the Prism Blade, none for the Steel Sword
local function emojiOf(weapon: Weapons.Weapon): string
	if weapon.prism then
		return "🌈"
	end
	return if weapon.element then CardDesign.EMOJI[weapon.element] or "" else ""
end

local function centered(label: TextLabel): TextLabel
	label.TextXAlignment = Enum.TextXAlignment.Center
	return label
end

-- A square picture centred at (0.5, y) of the art, `size` of its width
local function centredSquare(art: Frame, name: string, id: string, y: number, size: number, zIndex: number): ImageLabel
	local picture = P.image(art, name, id, zIndex)
	picture.ScaleType = Enum.ScaleType.Fit
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, y)
	picture.Size = UDim2.fromScale(size, size)
	picture.SizeConstraint = Enum.SizeConstraint.RelativeXX
	return picture
end

-- The weapon's portrait (the model cut out), clear of the Power line at the bottom; nil until it's made
local function portrait(art: Frame, weaponId: string, zIndex: number): ImageLabel?
	local look = WeaponLooks.WEAPONS[weaponId]
	if not look or look.portrait == "" then
		return nil
	end
	local picture = P.image(art, "Picture", look.portrait, zIndex)
	picture.ScaleType = Enum.ScaleType.Fit
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position = UDim2.fromScale(0.5, 0.06)
	picture.Size = UDim2.fromScale(0.9, 0.7)
	return picture
end

-- The picture: the Armory painting dimmed, soft rays and a glow in the weapon's colour, then its portrait (else a big
-- sword)
local function picture(art: Frame, weaponId: string)
	local look = WeaponLooks.WEAPONS[weaponId]
	local glow = if look then rgb(look.glow) else Color3.fromRGB(207, 230, 255)
	P.image(art, "Backdrop", BACKDROP, 3).ImageColor3 = rgb(CARD.backdrop)
	local rays = centredSquare(art, "Rays", PackFx.IMAGES.rays, 0.42, CARD.raysSize, 3)
	rays.ImageColor3 = glow:Lerp(WHITE, 0.5)
	rays.ImageTransparency = CARD.rays
	local halo = centredSquare(art, "Glow", CardDesign.IMAGES.GLOW, 0.42, CARD.glowSize, 3)
	halo.ImageColor3 = glow
	halo.ImageTransparency = CARD.glow
	if portrait(art, weaponId, 4) then
		return
	end
	centered(P.text(art, SWORD, { x = 0.15, y = 0.24, w = 0.7, h = 0.42 }, WHITE, 4))
end

local function owned(frame: Frame, weapon: Weapons.Weapon, record: Owned)
	local face = P.newFace(frame)
	P.addRim(face, CardDesign.RIMS[weapon.rarity] or CardDesign.RIMS.Common)
	local art = P.addArtWindow(face)
	picture(art, weapon.id)
	P.addTextShade(art)
	local tier = (Rarities.Tiers :: any)[weapon.rarity]
	local shineFrom = (Rarities.Tiers :: any)[CardDesign.SHINE_FROM]
	if tier and shineFrom and tier.order >= shineFrom.order then
		P.addShine(art)
	end
	if weapon.rarity == "Legendary" and record.grade == "S" then
		P.addSupremeRim(art)
	end
	local layout = CardDesign.TEXT
	local name = P.text(face, `{emojiOf(weapon)}{weapon.name}`, layout.NAME, WHITE, 7)
	name.Name = "Name"
	P.chip(face, "Grade", record.grade, layout.GRADE, CardDesign.GRADE_COLORS[record.grade] or CardDesign.GRADE_COLORS.C, 0)
	if weapon.id ~= Weapons.STARTER then
		P.chip(face, "Level", `+{record.level}`, layout.LEVEL, CardDesign.LEVEL_CHIP, CardDesign.LEVEL_CHIP_TRANSPARENCY)
	end
	local power = WeaponRules.shownPower(Weapons, Combat, weapon.id, record.grade, record.level)
	centered(P.text(face, string.format("Power x%.2f", power), layout.VALUE, CardDesign.VALUE_TEXT, 7)).Name = "Power"
	P.lift(frame, face)
end

local function locked(frame: Frame, weapon: Weapons.Weapon, progress: Progress?)
	local look = CardDesign.MISSING
	local words = rgb(CARD.lockedText)
	local face = P.newFace(frame)
	P.addRim(face, look.RIM)
	local art = P.addArtWindow(face)
	art.BackgroundColor3 = look.INSIDE
	P.image(art, "Backdrop", BACKDROP, 3).ImageColor3 = rgb(CARD.lockedBackdrop)
	local veil = Instance.new("Frame")
	veil.Name = "Veil"
	veil.Size = UDim2.fromScale(1, 1)
	veil.BorderSizePixel = 0
	veil.BackgroundColor3 = rgb(CARD.veil)
	veil.BackgroundTransparency = CARD.veilTransparency
	veil.ZIndex = 4
	veil.Parent = art
	local shadow = portrait(art, weapon.id, 5)
	if shadow then
		shadow.ImageColor3 = BLACK
		shadow.ImageTransparency = CARD.shadow
	else
		local silhouette = centered(P.text(art, SWORD, { x = 0.2, y = 0.2, w = 0.6, h = 0.34 }, BLACK, 5))
		silhouette.TextTransparency = 0.45
	end
	P.addTextShade(art)
	local lock = UIIcons.Lock
	if lock then
		centredSquare(art, "Lock", lock, 0.4, CARD.lockSize, 6)
	end
	P.text(face, weapon.name, CardDesign.TEXT.NAME, rgb(CARD.lockedName), 7).Name = "Name"
	local where = if weapon.ready then WeaponText.source(Weapons, Bosses, weapon.id) else "Coming soon"
	local line = centered(P.text(art, where, { x = 0.06, y = 0.62, w = 0.88, h = 0.14 }, words, 6))
	line.TextWrapped = true
	if not weapon.ready then
		centered(P.text(art, WeaponText.source(Weapons, Bosses, weapon.id), { x = 0.06, y = 0.78, w = 0.88, h = 0.08 }, words, 6)).TextWrapped = true
	elseif progress and progress.need > 0 then
		local track = Instance.new("Frame")
		track.Name = "Progress"
		track.Position = UDim2.fromScale(0.1, 0.8)
		track.Size = UDim2.fromScale(0.8, 0.05)
		track.BackgroundColor3 = BLACK
		track.BackgroundTransparency = 0.4
		track.BorderSizePixel = 0
		track.ZIndex = 6
		track.Parent = art
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = track
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(math.clamp(progress.have / progress.need, 0, 1), 1)
		fill.BackgroundColor3 = PROGRESS_FILL
		fill.BorderSizePixel = 0
		fill.ZIndex = 7
		fill.Parent = track
		corner:Clone().Parent = fill
		centered(P.text(art, `{progress.have}/{progress.need}`, { x = 0.2, y = 0.86, w = 0.6, h = 0.08 }, words, 6))
	end
	P.lift(frame, face)
end

-- Draws a weapon's card into `frame` (its `stroke`, the caller's border, stays hidden like a card's)
function WeaponFace.render(frame: Frame, stroke: UIStroke?, weaponId: string, record: Owned?, progress: Progress?)
	local weapon = Weapons.ById[weaponId]
	P.clear(frame)
	if stroke then
		P.removeAurora(stroke)
		stroke.Transparency = 1
	end
	frame.BackgroundTransparency = 1
	if not weapon then
		return
	end
	local have = record or (if weapon.id == Weapons.STARTER then { grade = "C", level = 0 } else nil)
	if have and weapon.ready then
		owned(frame, weapon, have)
	else
		locked(frame, weapon, progress)
	end
end

-- What a weapon's card shows now, as a key: redraw only when it changes (faces are costly to build)
function WeaponFace.key(weaponId: string, record: Owned?, progress: Progress?): string
	if record then
		return `{weaponId}:{record.grade}:{record.level}`
	end
	return `{weaponId}:locked:{if progress then progress.have else 0}`
end

return WeaponFace
