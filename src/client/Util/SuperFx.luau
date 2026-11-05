--!strict
-- The super moves in the world, for everyone in the fight (spec 2026-11-05-super-moves-design, Config/SuperFx): each
-- look's charge (from the press to the impact, on the caster) and its impact and linger (where it lands, for as long
-- as the move lasts). Routed from Util/FightFx; the caster's own screen (camera, cut-in, flash) is Util/SuperCinematic.
-- A look not finished yet plays its kind's first-pass effect (ElementFx.special) with a bigger wind-up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("Config"):WaitForChild("AttackFx"))
local Combat = require(Shared:WaitForChild("Config"):WaitForChild("Combat"))
local SuperFxConfig = require(Shared:WaitForChild("Config"):WaitForChild("SuperFx"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))

local SuperFx = {}

-- The caster as Util/FightFx sees it
export type View = { root: BasePart, element: string, height: number, grade: string?, mine: boolean }
type Look = {
	charge: (view: View, grade: string, seconds: number, target: Vector3?) -> () -> (),
	impact: (view: View, grade: string, target: Vector3, targetBody: BasePart?, targetHeight: number) -> () -> (),
}

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function nothing() end

-- The super of a look's card (Config/Combat SIGNATURES): its kind, name and numbers
function SuperFx.abilityOf(lookId: string): any?
	local look = SuperFxConfig.LOOKS[lookId]
	return if look then Combat.SIGNATURES[look.card] else nil
end

-- The first-pass wind-up, bigger with grade: a glow, a ring under it and the move's name
local function placeholderCharge(lookId: string, view: View, grade: string, seconds: number): () -> ()
	local look = SuperFxConfig.LOOKS[lookId]
	local ability = SuperFx.abilityOf(lookId)
	local tint = color(look.color)
	local scale = look.grades[grade].scale
	local stop = ElementFx.chargeGlow(view.root, tint, seconds, 2 * scale)
	ElementFx.castRing(view.root.Position - Vector3.new(0, view.height * 0.45, 0), tint, math.max(2, view.height * 0.8) * scale, seconds)
	ElementFx.callout(view.root, view.height * 0.6, `{string.upper(if ability then ability.name else lookId)}!`, tint, seconds)
	ElementFx.sound(AttackFx.SOUNDS.charge, view.root.Position)
	return stop
end

-- The first-pass impact: its kind's effect (AttackFx.SPECIALS, ElementFx.special) and the shared chime and boom
local function placeholderImpact(lookId: string, view: View, target: Vector3): () -> ()
	local look = SuperFxConfig.LOOKS[lookId]
	local ability = SuperFx.abilityOf(lookId)
	local spec = if ability then AttackFx.SPECIALS[ability.kind] else nil
	if not spec then
		return nothing
	end
	local caster = view.root.Position + Vector3.new(0, view.height * 0.4, 0)
	local hitAt = if ability and (ability.kind == "TidalShield" or ability.kind == "Eclipse") then caster else target
	ElementFx.sound(AttackFx.SPECIAL_SOUND, caster)
	ElementFx.sound(AttackFx.SOUNDS.big[view.element] or AttackFx.SOUNDS.boom, hitAt, 0.6)
	ElementFx.special(spec.style, caster, hitAt, color(look.color), spec.seconds or 0)
	return nothing
end

-- The finished looks (spec "The ten moves"), by look id; the rest play the first pass
local LOOKS: { [string]: Look } = {}

-- Everything from the press to the impact on the caster; returns a stop
function SuperFx.charge(lookId: string, view: View, grade: string, seconds: number, target: Vector3?): () -> ()
	local own = LOOKS[lookId]
	if own then
		return own.charge(view, grade, seconds, target)
	end
	return placeholderCharge(lookId, view, grade, seconds)
end

-- The impact and what lingers on the field for the move's seconds; returns a stop
function SuperFx.impact(lookId: string, view: View, grade: string, target: Vector3, targetBody: BasePart?, targetHeight: number): () -> ()
	local own = LOOKS[lookId]
	if own then
		return own.impact(view, grade, target, targetBody, targetHeight)
	end
	return placeholderImpact(lookId, view, target)
end

return SuperFx
