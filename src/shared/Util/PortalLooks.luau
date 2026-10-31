--!strict
-- The town portals grown from their worlds (spec 2026-10-30-town-portals-design): which model stands at a portal,
-- where its name floats, and which parts and effects a look needs. Pure, Lune-tested; Config/Town PORTAL_LOOKS holds
-- the looks, Server/Util/PortalBuild dresses a model with them, TownService places them.
local PortalLooks = {}

local FALLBACK_SLOT = "Portal" -- today's frame, standing in until a portal's own model is saved

-- The PORTAL_LOOKS key of a look table (PortalBuild.dress stamps it on the model as the PortalLook attribute, which the
-- client's swirl animator reads: model names can't tell the Boss and Arena looks apart, and boss portals are renamed)
function PortalLooks.keyOf(looks: { [string]: any }, look: any): string?
	for key, candidate in looks do
		if candidate == look then
			return key
		end
	end
	return nil
end

-- The slot standing at a portal: its own model once saved (hasModel: Props.hasModel), else today's frame
function PortalLooks.slot(look: string, town: any, hasModel: (slot: string) -> boolean): string
	local entry = town.PORTAL_LOOKS[look]
	if entry and hasModel(entry.slot) then
		return entry.slot
	end
	return FALLBACK_SLOT
end

-- How high over the portal's foot its name floats: just above whichever model stands there
function PortalLooks.labelHeight(slot: string, town: any): number
	return town.SLOTS[slot].height + town.PORTAL_FX.LABEL_GAP
end

-- How far to move a placed portal model up (negative: down) so its ground part's bottom (partBottom) stands `bottom`
-- studs (Blender, at the model's scale) over the foot it was placed on
function PortalLooks.groundShift(partBottom: number, foot: number, bottom: number, scale: number): number
	return foot + bottom * scale - partBottom
end

-- The swirl panel's side: round (a stretched swirl wobbles), big enough that the swirl's disc covers the opening
-- (VORTEX_SCALE of its larger side; what spills over hides behind the frame)
function PortalLooks.vortexSize(width: number, height: number, town: any): number
	return math.max(width, height) * town.PORTAL_FX.VORTEX_SCALE
end

-- The swirl's layers at a moment (seconds): the swirl's and the inner swirl's turn (degrees, 0-360), the glowing core's
-- transparency and the light's brightness as a share of the look's
function PortalLooks.animate(now: number, look: any, town: any): { swirl: number, inner: number, glow: number, light: number }
	local fx = town.PORTAL_FX
	local wave = math.sin(now / fx.PULSE.period * math.pi * 2)
	local low, high = fx.PULSE.glow[1], fx.PULSE.glow[2]
	return {
		swirl = (look.vortex.spin * now) % 360,
		inner = (look.vortex.spin * fx.INNER.speed * now) % 360,
		glow = (low + high) / 2 + (high - low) / 2 * wave,
		light = 1 + fx.PULSE.light * wave,
	}
end

-- Beams and emitters a portal draws, its vortex included
function PortalLooks.effectCount(look: any): number
	return #look.effects + 1
end

-- The parts an effect is drawn on or between
local function spots(effect: any): { string }
	if effect.kind == "beam" then
		return { effect.from, effect.to }
	end
	return { effect.at }
end

-- Every part a look's model must have, sorted: the frame, the opening, its effects' spots and its glowing parts
function PortalLooks.parts(look: any): { string }
	local seen: { [string]: boolean } = { Frame = true, Opening = true }
	for _, effect in look.effects do
		for _, part in spots(effect) do
			seen[part] = true
		end
	end
	for part in look.glow do
		seen[part] = true
	end
	local list = {}
	for part in seen do
		table.insert(list, part)
	end
	table.sort(list)
	return list
end

-- The look's effects whose parts all exist in the model (has: does the model have this part?)
function PortalLooks.effectsFor(look: any, has: (part: string) -> boolean): { any }
	local kept = {}
	for _, effect in look.effects do
		local ok = true
		for _, part in spots(effect) do
			if not has(part) then
				ok = false
			end
		end
		if ok then
			table.insert(kept, effect)
		end
	end
	return kept
end

return PortalLooks
