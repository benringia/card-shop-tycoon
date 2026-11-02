--!strict
-- Turns fight events into attack pictures (spec 2026-11-02-attack-animations-design): a creature's "charge" makes it
-- stop, crouch and glow, then lets its element's attack go (Config/AttackFx: a projectile, a 3-hit combo or a
-- lightning zip) so the hit lands with the sim's "attack" event and its damage number. The final hit waits for that
-- event: a charge whose attack never comes (a stun, a faint, a swap) fades without one (Util/AttackTiming). An attack
-- that arrives with no charge strikes at once. Effects are capped (Util/FightFxRules). The fight controller and PvP
-- spectators each make one, passing how to reach the creatures.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("Config"):WaitForChild("AttackFx"))
local AttackTiming = require(Shared:WaitForChild("Util"):WaitForChild("AttackTiming"))
local FightFxRules = require(Shared:WaitForChild("Util"):WaitForChild("FightFxRules"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))
local Extras = require((script.Parent :: Instance):WaitForChild("Extras"))

local FightFx = {}

export type View = { root: BasePart, element: string, height: number }
export type Resolve = {
	marker: (id: string) -> BasePart?, -- a fighter's marker by sim id
	creature: (marker: BasePart) -> View?, -- the creature drawn on it (nil: a monster or boss, not handled here)
	setCharging: (marker: BasePart, seconds: number) -> (),
	pose: (marker: BasePart, kind: string) -> (),
	dash: (marker: BasePart, toward: Vector3, share: number, seconds: number) -> (),
}
export type Dispatcher = { onEvents: (events: { any }) -> (), destroy: () -> () }

type Pending = {
	at: number, -- os.clock of the charge
	lead: number,
	to: string?,
	color: Color3,
	element: string,
	attacked: boolean,
	waiters: { () -> () }, -- final hits waiting for the attack event
	stopGlow: () -> (),
}

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

function FightFx.new(resolve: Resolve): Dispatcher
	local pending: { [string]: Pending } = {}
	local active = 0
	local alive = true

	local function targetPosition(id: string?, fallback: Vector3): Vector3
		local marker = if id then resolve.marker(id) else nil
		return if marker then marker.Position + Vector3.new(0, 2, 0) else fallback
	end

	-- Runs `hit` once the charge's attack has come (at once if it has), or drops it after the grace
	local function whenAttacked(entry: Pending, hit: () -> ())
		if entry.attacked then
			hit()
			return
		end
		table.insert(entry.waiters, hit)
		task.delay(entry.lead + AttackFx.CHARGE_GRACE, function()
			local index = table.find(entry.waiters, hit)
			if index then
				table.remove(entry.waiters, index) -- no attack came: no hit
			end
		end)
	end

	local function hitSound(element: string, at: Vector3)
		local sounds = AttackFx.SOUNDS[element]
		ElementFx.sound(if sounds then sounds.hit else nil, at)
	end

	local function onCharge(event: any)
		local marker = resolve.marker(event.from)
		local view = if marker then resolve.creature(marker) else nil
		local kind = if view then FightFxRules.kindFor(view.element, AttackFx) else nil
		if not marker or not view or not kind or not FightFxRules.budget(active, Extras.enabled(), AttackFx) then
			return
		end
		local lead = math.max(0, tonumber(event.seconds) or 0)
		local tint = color(AttackFx.ELEMENT[view.element].color)
		local entry: Pending = {
			at = os.clock(),
			lead = lead,
			to = event.to,
			color = tint,
			element = view.element,
			attacked = false,
			waiters = {},
			stopGlow = ElementFx.chargeGlow(view.root, tint, lead),
		}
		active += 1
		pending[event.from] = entry
		resolve.setCharging(marker, lead)
		resolve.pose(marker, "charge")
		ElementFx.sound(AttackFx.SOUNDS.charge, view.root.Position)
		task.delay(lead + AttackFx.CHARGE_GRACE + 0.5, function()
			active = math.max(0, active - 1)
			if pending[event.from] == entry then
				pending[event.from] = nil
			end
		end)

		if kind == "projectile" then
			local schedule = AttackTiming.schedule(lead, AttackFx.FLIGHT[view.element] or 0.3)
			task.delay(schedule.releaseIn, function()
				if not alive then
					return
				end
				entry.stopGlow()
				resolve.pose(marker, "cast")
				local sounds = AttackFx.SOUNDS[view.element]
				ElementFx.sound(if sounds then sounds.release else nil, view.root.Position)
				local from = view.root.Position + Vector3.new(0, view.height * 0.5, 0)
				ElementFx.projectile(from, function()
					return targetPosition(entry.to, from)
				end, tint, schedule.impactIn - schedule.releaseIn, AttackFx.ARC[view.element] or 0, function(at)
					whenAttacked(entry, function()
						ElementFx.burst(at, tint)
						hitSound(view.element, at)
					end)
				end)
			end)
		elseif kind == "combo" then
			local window = AttackFx.COMBO.window
			local times = AttackTiming.comboTimes(AttackFx.COMBO.count, window)
			local startIn = math.max(0, lead - window)
			task.delay(startIn, function()
				if not alive then
					return
				end
				entry.stopGlow()
				local toward = targetPosition(entry.to, view.root.Position)
				resolve.dash(marker, toward, AttackFx.DASH.combo, window + 0.2)
				resolve.pose(marker, "combo")
				local style = if view.element == "Shade" then "claw" else "vine"
				for index, at in times do
					task.delay(at, function()
						local function slash()
							local spot = targetPosition(entry.to, toward)
							ElementFx.slash(spot, view.root.Position, tint, style, index)
							hitSound(view.element, spot)
							if index == #times then
								ElementFx.burst(spot, tint, 0.7)
							end
						end
						if index == #times then
							whenAttacked(entry, slash) -- the last one carries the damage
						else
							slash()
						end
					end)
				end
			end)
		elseif kind == "zip" then
			local zipIn = math.max(0, lead - 0.25)
			task.delay(zipIn, function()
				if not alive then
					return
				end
				entry.stopGlow()
				local toward = targetPosition(entry.to, view.root.Position)
				resolve.dash(marker, toward, AttackFx.DASH.zip, 0.45)
				resolve.pose(marker, "strike")
				task.delay(lead - zipIn, function()
					whenAttacked(entry, function()
						local spot = targetPosition(entry.to, toward)
						ElementFx.bolt(view.root.Position + Vector3.new(0, 1, 0), spot, tint, 0.2)
						ElementFx.burst(spot, tint, 0.8)
						hitSound(view.element, spot)
					end)
				end)
			end)
		end
	end

	-- An auto-attack landed: release whatever waited for it, or strike at once when it came uncharged
	local function onAttack(event: any)
		local entry = pending[event.from]
		if entry and not entry.attacked then
			entry.attacked = true
			entry.to = event.to or entry.to
			local waiters = entry.waiters
			entry.waiters = {}
			for _, hit in waiters do
				hit()
			end
			return
		end
		local marker = resolve.marker(event.from)
		local view = if marker then resolve.creature(marker) else nil
		if not marker or not view or not AttackFx.ELEMENT[view.element] or not FightFxRules.budget(active, Extras.enabled(), AttackFx) then
			return
		end
		local tint = color(AttackFx.ELEMENT[view.element].color)
		local spot = targetPosition(event.to, view.root.Position)
		resolve.pose(marker, "strike")
		ElementFx.burst(spot, tint, 0.7)
		hitSound(view.element, spot)
	end

	local function onEvents(events: { any })
		if not alive then
			return
		end
		for _, event in events do
			if typeof(event) ~= "table" or typeof(event.from) ~= "string" then
				continue
			end
			if event.type == "charge" then
				onCharge(event)
			elseif event.type == "attack" and not event.kind and not event.dodged then
				onAttack(event)
			end
		end
	end

	local function destroy()
		alive = false
		for _, entry in pending do
			entry.stopGlow()
		end
		pending = {}
	end

	return { onEvents = onEvents, destroy = destroy }
end

return FightFx
