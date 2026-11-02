--!strict
-- Turns fight events into attack pictures (spec 2026-11-02-attack-animations-design): a creature's "charge" makes it
-- stop, crouch and glow, then lets its element's attack go (Config/AttackFx: a projectile, a 3-hit combo or a
-- lightning zip) so the hit lands with the sim's "attack" event and its damage number. The final hit waits for that
-- event: a charge whose attack never comes (a stun, a faint, a swap) fades without one (Util/AttackTiming). An attack
-- that arrives with no charge strikes at once. Effects are capped (Util/FightFxRules). The fight controller and PvP
-- spectators each make one, passing how to reach the creatures.
-- Bosses and wild monsters (Config/AttackFx BOSS, MONSTER) play their keyed clips (Util/MonsterMoves picks which): a
-- wind-up before each hit, the strike with an impact where it lands; a boss also the special wind-up with sparks
-- pulling in over a ring's warning, then the release with its effect over the ring. Their effects always play: one
-- monster per fight, and they show where it hit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("Config"):WaitForChild("AttackFx"))
local Combat = require(Shared:WaitForChild("Config"):WaitForChild("Combat"))
local AttackTiming = require(Shared:WaitForChild("Util"):WaitForChild("AttackTiming"))
local FightFxRules = require(Shared:WaitForChild("Util"):WaitForChild("FightFxRules"))
local MonsterMoves = require(Shared:WaitForChild("Util"):WaitForChild("MonsterMoves"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))
local Extras = require((script.Parent :: Instance):WaitForChild("Extras"))
local RingFx = require((script.Parent :: Instance):WaitForChild("RingFx"))

local FightFx = {}

export type View = { root: BasePart, element: string, height: number }
export type Resolve = {
	marker: (id: string) -> BasePart?, -- a fighter's marker by sim id
	creature: (marker: BasePart) -> View?, -- the creature drawn on it (nil: a monster or boss, not handled here)
	setCharging: (marker: BasePart, seconds: number) -> (),
	pose: (marker: BasePart, kind: string) -> (),
	dash: (marker: BasePart, toward: Vector3, share: number, seconds: number) -> (),
	-- The boss or monster drawn on a marker, and playing its clips (nil: no monsters here, PvP)
	monster: ((marker: BasePart) -> MonsterView?)?,
	playClip: ((marker: BasePart, name: string, speed: number, hold: number) -> ())?,
}
-- key: its boss id or species; lengths: its attack clips (name -> seconds)
export type MonsterView = { root: BasePart, height: number, key: string, lengths: { [string]: number } }
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

	-- A Pet button move or super move: a cast pose on the caster and its effect, all landing now (with the event)
	local function onSpecial(event: any)
		local spec = AttackFx.SPECIALS[event.kind]
		local marker = resolve.marker(event.from)
		local view = if marker then resolve.creature(marker) else nil
		if not spec or not marker or not view or not FightFxRules.budget(active, Extras.enabled(), AttackFx) then
			return
		end
		local caster = view.root.Position + Vector3.new(0, view.height * 0.4, 0)
		local target = targetPosition(event.to, caster)
		resolve.pose(marker, "cast")
		ElementFx.sound(AttackFx.SPECIAL_SOUND, caster)
		hitSound(view.element, target)
		ElementFx.special(spec.style, caster, target, color(spec.color), spec.seconds or 0)
	end

	local moves: { [BasePart]: MonsterMoves.State } = {}
	local rings: { [string]: any } = {} -- each player's latest ring (by sim id): where its hit lands
	local gathering: { [BasePart]: () -> () } = {} -- a boss's sparks pulling in for a ring
	local strikeSoundAt = 0
	local moveCfg = { CHARGE_GRACE = AttackFx.CHARGE_GRACE, HIT_GRACE = Combat.HIT_GRACE }

	local function monsterOf(id: string): (BasePart?, MonsterView?)
		local lookup = resolve.monster
		local marker = if lookup then resolve.marker(id) else nil
		return marker, if lookup and marker then lookup(marker) else nil
	end

	local function stopGathering(marker: BasePart)
		local stop = gathering[marker]
		if stop then
			gathering[marker] = nil
			stop()
		end
	end

	-- A boss's or wild monster's move: its clip (MonsterMoves) and, with looks (AttackFx BOSS or MONSTER), the effect
	local function onMonster(event: any, marker: BasePart, view: MonsterView)
		local state = moves[marker]
		if not state then
			state = MonsterMoves.new()
			moves[marker] = state
		end
		local move = MonsterMoves.decide(state, event, os.clock(), view.lengths, moveCfg)
		if move and resolve.playClip then
			resolve.playClip(marker, move.clip, move.speed, move.hold)
		end
		local spec = AttackFx.BOSS[view.key] or AttackFx.MONSTER[view.key]
		if not spec then
			return
		end
		local tint = color(spec.color)
		local slam = event.type == "attack" and (event.kind == "Slam" or event.kind == "Swipe")
		if event.type == "ring" then
			if typeof(event.to) == "string" and typeof(event.x) == "number" then
				rings[event.to] = event
			end
			if move then
				stopGathering(marker)
				local middle = view.root.Position + Vector3.new(0, view.height * 0.5, 0)
				local seconds = (tonumber(event.seconds) or 1) + Combat.HIT_GRACE
				gathering[marker] = ElementFx.gather(middle, tint, seconds, view.height * 0.6)
			end
		elseif slam then
			stopGathering(marker)
			if move then
				ElementFx.sound(spec.sounds.release, view.root.Position)
			end
			local ring = if typeof(event.to) == "string" then rings[event.to] else nil
			if ring then
				rings[event.to] = nil
				local ground = Vector3.new(ring.x, RingFx.groundY(ring.x, ring.y, ring.z), ring.z)
				local direction = Vector3.new(tonumber(ring.dirX) or 0, 0, tonumber(ring.dirZ) or -1)
				ElementFx.bossRelease(spec.release, ground, ring.radius or 7, direction, ring.length or 0, ring.halfAngle or 0, tint)
			end
		elseif event.type == "attack" and not event.dodged then
			local spot = targetPosition(event.to, view.root.Position)
			ElementFx.monsterStrike(spec.strike, spot, view.root.Position, tint)
			local now = os.clock()
			if now - strikeSoundAt > 0.2 then -- a group hit in one moment sounds once
				strikeSoundAt = now
				ElementFx.sound(spec.sounds.strike, spot)
			end
		end
	end

	local function onEvents(events: { any })
		if not alive then
			return
		end
		for _, event in events do
			if typeof(event) ~= "table" or typeof(event.from) ~= "string" then
				continue
			end
			local monster, monsterView = monsterOf(event.from)
			if monster and monsterView then
				onMonster(event, monster, monsterView)
				continue
			end
			if event.type == "charge" then
				onCharge(event)
			elseif event.type == "attack" and not event.kind and not event.dodged then
				onAttack(event)
			elseif event.type == "ability" and event.kind and AttackFx.SPECIALS[event.kind] then
				onSpecial(event)
			end
		end
	end

	local function destroy()
		alive = false
		for _, entry in pending do
			entry.stopGlow()
		end
		pending = {}
		for marker in gathering do
			stopGathering(marker)
		end
	end

	return { onEvents = onEvents, destroy = destroy }
end

return FightFx
