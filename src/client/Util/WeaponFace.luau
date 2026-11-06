--!strict
-- A weapon's card (owner's pick 2026-11-06: A, the creature card's shape; spec 2026-11-06-weapons-round1-design 6):
-- the Armory, the Forge, the Boss Board. Drawn with CardFace's pieces so it matches the binder's cards.
--   owned: the rarity's rim, its portrait (Config/WeaponLooks; until it's made, its glow colour behind a big sword),
--          its element and name, grade, +level, and its Power where a card shows its value
--   locked: the missing card's dark rim and window, a sword silhouette, where it comes from (WeaponText.source) and
--          the progress toward forging it (the main material, have / need)
--   not built yet: the same, "Coming soon"
-- The Steel Sword is everyone's: always drawn owned.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local Rarities = require(Config:WaitForChild("Rarities"))
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

-- The picture: the portrait, else the weapon's glow colour (light at the top, deeper at the bottom) behind a big sword
local function picture(art: Frame, weaponId: string)
	local look = WeaponLooks.WEAPONS[weaponId]
	if look and look.portrait ~= "" then
		P.image(art, "Picture", look.portrait, 3)
		return
	end
	local glow = if look then rgb(look.glow) else Color3.fromRGB(207, 230, 255)
	art.BackgroundColor3 = WHITE
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(glow:Lerp(WHITE, 0.6), glow:Lerp(BLACK, 0.3))
	shade.Rotation = 90
	shade.Parent = art
	centered(P.text(art, SWORD, { x = 0.15, y = 0.24, w = 0.7, h = 0.42 }, WHITE, 3))
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
	local power = WeaponRules.power(Weapons, weapon.id, record.grade, record.level)
	centered(P.text(face, string.format("Power x%.2f", power), layout.VALUE, CardDesign.VALUE_TEXT, 7)).Name = "Power"
	P.lift(frame, face)
end

local function locked(frame: Frame, weapon: Weapons.Weapon, progress: Progress?)
	local look = CardDesign.MISSING
	local face = P.newFace(frame)
	P.addRim(face, look.RIM)
	local art = P.addArtWindow(face)
	art.BackgroundColor3 = look.INSIDE
	local silhouette = centered(P.text(art, SWORD, { x = 0.2, y = 0.2, w = 0.6, h = 0.34 }, BLACK, 3))
	silhouette.TextTransparency = 0.45
	local name = centered(P.text(face, weapon.name, CardDesign.TEXT.NAME, look.MARK, 7))
	name.Size = UDim2.fromScale(0.86, CardDesign.TEXT.NAME.h)
	local where = if weapon.ready then WeaponText.source(Weapons, Bosses, weapon.id) else "Coming soon"
	local line = centered(P.text(art, where, { x = 0.06, y = 0.58, w = 0.88, h = 0.16 }, look.MARK, 4))
	line.TextWrapped = true
	if not weapon.ready then
		centered(P.text(art, WeaponText.source(Weapons, Bosses, weapon.id), { x = 0.06, y = 0.75, w = 0.88, h = 0.08 }, look.MARK, 4)).TextWrapped = true
	elseif progress and progress.need > 0 then
		local track = Instance.new("Frame")
		track.Name = "Progress"
		track.Position = UDim2.fromScale(0.1, 0.8)
		track.Size = UDim2.fromScale(0.8, 0.05)
		track.BackgroundColor3 = BLACK
		track.BackgroundTransparency = 0.4
		track.BorderSizePixel = 0
		track.ZIndex = 4
		track.Parent = art
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = track
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(math.clamp(progress.have / progress.need, 0, 1), 1)
		fill.BackgroundColor3 = PROGRESS_FILL
		fill.BorderSizePixel = 0
		fill.ZIndex = 5
		fill.Parent = track
		corner:Clone().Parent = fill
		centered(P.text(art, `{progress.have}/{progress.need}`, { x = 0.2, y = 0.86, w = 0.6, h = 0.08 }, look.MARK, 4))
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
