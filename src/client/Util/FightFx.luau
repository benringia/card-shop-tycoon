--!strict
-- Turns fight events into attack pictures (spec 2026-11-02-attack-animations-design): a creature's "charge" makes it
-- stop, crouch and glow, then lets its element's attack go (Config/AttackFx: a projectile, a 3-hit combo or a
-- lightning bolt) so the hit lands with the sim's "attack" event and its damage number. The final hit waits for that
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
local ScreenFx = require((script.Parent :: Instance):WaitForChild("ScreenFx"))

local FightFx = {}

-- grade: its card copy's (the attack grows with it); mine: the local player's creature
export type View = { root: BasePart, element: string, height: number, grade: string?, mine: boolean }
type Tier = { scale: number, sparks: number, extra: number, shake: number }
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

-- Each special move's name by its kind (Combat ABILITIES and SIGNATURES), for its callout
local MOVE_NAMES: { [string]: string } = {}
for _, list in { Combat.ABILITIES, Combat.SIGNATURES } do
	for _, ability in list do
		MOVE_NAMES[ability.kind] = ability.name
	end
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

	-- A creature's hit landing at `at`: the impact at its grade's size, its sound, shake on your own creature's hits,
	-- and at grade S the boom layer, a flash on your screen and the element's big extra
	local function impact(view: View, tier: Tier, at: Vector3, tint: Color3, finisher: boolean)
		local s = tier.scale
		ElementFx.burst(at, tint, s * (if finisher then 1.15 else 1))
		hitSound(view.element, at)
		if view.mine then
			ScreenFx.shakeAt((if finisher or tier.extra >= 2 then AttackFx.SHAKE.creatureFinisher else AttackFx.SHAKE.creatureHit) * tier.shake, at)
		end
		if tier.extra < 2 then
			return
		end
		ElementFx.sound(AttackFx.SOUNDS.big[view.element] or AttackFx.SOUNDS.boom, at, 0.8)
		if view.mine then
			ScreenFx.flash(tint, AttackFx.FLASH.gradeS.strength, AttackFx.FLASH.gradeS.seconds)
		end
		local ground = at - Vector3.new(0, 2, 0)
		if view.element == "Ember" then
			ElementFx.pillar(ground, tint, 9 * s, 0.4, "flame")
		elseif view.element == "Tide" then
			ElementFx.pillar(ground, tint:Lerp(Color3.new(1, 1, 1), 0.3), 9 * s, 0.4, "glow")
		elseif view.element == "Volt" then
			task.delay(AttackFx.BOLT.skyDelay, function()
				ElementFx.skyStrike(at, tint, s * 0.6)
			end)
		end
	end

	local function onCharge(event: any)
		local marker = resolve.marker(event.from)
		local view = if marker then resolve.creature(marker) else nil
		local kind = if view then FightFxRules.kindFor(view.element, AttackFx) else nil
		if not marker or not view or not kind or not FightFxRules.budget(active, Extras.enabled(), AttackFx) then
			return
		end
		local tier = FightFxRules.tier(view.grade, AttackFx)
		local s = tier.scale
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
			stopGlow = ElementFx.chargeGlow(view.root, tint, lead, s),
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
				local flight = schedule.impactIn - schedule.releaseIn
				local ember = view.element == "Ember"
				local opts = { scale = s, flames = ember, rings = if view.element == "Tide" then 1 + tier.extra else 0, sparkle = tier.extra >= 2 }
				-- Ember throws one more fireball a grade A, two more at S, a little after and to the sides, all landing together
				local shots = if ember then 1 + tier.extra else 1
				for shot = 1, shots do
					local wait = (shot - 1) * AttackFx.EXTRA_SHOT_GAP
					local side = if shot == 1 then 0 elseif shot % 2 == 0 then 1 else -1
					task.delay(wait, function()
						local offset = Vector3.new(0, 0, 0)
						ElementFx.projectile(from, function()
							local goal = targetPosition(entry.to, from)
							local flat = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
							if side ~= 0 and flat.Magnitude > 0.1 then
								offset = flat.Unit:Cross(Vector3.yAxis) * side * 1.5 * s
							end
							return goal + offset
						end, tint, math.max(0.1, flight - wait), (AttackFx.ARC[view.element] or 0) + (shot - 1) * 2, function(at)
							if shot == 1 then
								whenAttacked(entry, function()
									impact(view, tier, at, tint, false)
								end)
							else
								ElementFx.burst(at, tint, s * 0.6)
							end
						end, if shot == 1 then opts else { scale = s * 0.75, flames = ember, sparkle = opts.sparkle })
					end)
				end
			end)
		elseif kind == "combo" then
			local window = AttackFx.COMBO.window
			local times = AttackTiming.comboTimes(AttackFx.COMBO.count + tier.extra, window)
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
							ElementFx.slash(spot, view.root.Position, tint, style, index, s)
							if index < #times then
								hitSound(view.element, spot)
								if view.mine then
									ScreenFx.shakeAt(AttackFx.SHAKE.creatureHit * 0.5 * tier.shake, spot)
								end
								return
							end
							impact(view, tier, spot, tint, true)
							if tier.extra >= 2 then
								-- The finishing X
								ElementFx.slash(spot, view.root.Position, Color3.new(1, 1, 1), style, 1, s * 1.5, 45)
								ElementFx.slash(spot, view.root.Position, tint, style, 2, s * 1.5, -45)
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
		elseif kind == "bolt" then
			-- Shot from where it stands (the owner's mockup): it holds and glows, then the bolt flickers across as the hit
			-- lands
			task.delay(lead, function()
				if not alive then
					return
				end
				entry.stopGlow()
				whenAttacked(entry, function()
					resolve.pose(marker, "cast")
					local spot = targetPosition(entry.to, view.root.Position)
					local from = view.root.Position + Vector3.new(0, view.height * 0.5, 0)
					ElementFx.bolt(from, spot, tint, AttackFx.BOLT.seconds, s)
					-- Forked side bolts: one at grade A, two at S
					for fork = 1, tier.extra do
						local up = Vector3.new(0, if fork == 1 then 2.5 else -1.5, 0) * s
						ElementFx.bolt(from + up * 0.5, spot + up, tint:Lerp(Color3.new(1, 1, 1), 0.4), AttackFx.BOLT.seconds, s * 0.65)
					end
					impact(view, tier, spot, tint, false)
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
		local tier = FightFxRules.tier(view.grade, AttackFx)
		ElementFx.burst(spot, tint, 0.7 * tier.scale)
		hitSound(view.element, spot)
	end

	-- A Pet button move or super move winding up (Combat.ABILITY_WINDUP, owner 2026-11-04 design A): the creature
	-- holds still in a big glow, a ring in the move's colour spins under it and the move's name pops above it; the move
	-- itself lands with its "ability" event. Always shown (it's the cue everyone watches for).
	local function onCast(event: any)
		local spec = AttackFx.SPECIALS[event.kind]
		local marker = resolve.marker(event.from)
		local view = if marker then resolve.creature(marker) else nil
		if not spec or not marker or not view then
			return
		end
		local seconds = math.max(0.1, tonumber(event.seconds) or 0.5)
		local tint = color(spec.color)
		resolve.setCharging(marker, seconds)
		resolve.pose(marker, "charge")
		ElementFx.chargeGlow(view.root, tint, seconds, 1.7)
		ElementFx.castRing(view.root.Position - Vector3.new(0, view.height * 0.45, 0), tint, math.max(2, view.height * 0.8), seconds)
		ElementFx.callout(view.root, view.height * 0.6, `{string.upper(MOVE_NAMES[event.kind] or event.kind)}!`, tint, seconds)
		ElementFx.sound(AttackFx.SOUNDS.charge, view.root.Position)
	end

	-- A Pet button move or super move: a cast pose on the caster and its effect, all landing now (with the event), a
	-- shake near it and a flash on your screen when it's your creature's
	local function onSpecial(event: any)
		local spec = AttackFx.SPECIALS[event.kind]
		local marker = resolve.marker(event.from)
		local view = if marker then resolve.creature(marker) else nil
		if not spec or not marker or not view or not FightFxRules.budget(active, Extras.enabled(), AttackFx) then
			return
		end
		local caster = view.root.Position + Vector3.new(0, view.height * 0.4, 0)
		local target = targetPosition(event.to, caster)
		local tint = color(spec.color)
		resolve.pose(marker, "cast")
		ElementFx.sound(AttackFx.SPECIAL_SOUND, caster)
		hitSound(view.element, target)
		ElementFx.sound(AttackFx.SOUNDS.big[view.element] or AttackFx.SOUNDS.boom, target, 0.6)
		ElementFx.special(spec.style, caster, target, tint, spec.seconds or 0)
		ScreenFx.shakeAt(AttackFx.SHAKE.special, target)
		if view.mine then
			ScreenFx.flash(tint, AttackFx.FLASH.special.strength, AttackFx.FLASH.special.seconds)
		end
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
			-- A meteor heaved off the boss's back, arcing high to land on the ring with the slam (AttackFx BOSS meteor;
			-- the Ember Colossus, owner 2026-11-04)
			local meteor = spec.meteor
			if meteor and typeof(event.x) == "number" then
				local seconds = (tonumber(event.seconds) or 1) + Combat.HIT_GRACE
				local from = view.root.Position + Vector3.new(0, view.height * 0.9, 0)
				local ground = Vector3.new(event.x, RingFx.groundY(event.x, event.y, event.z), event.z)
				ElementFx.projectile(from, function()
					return ground
				end, tint, seconds, meteor.arc, function() end, { scale = meteor.scale, flames = true })
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
				ElementFx.bossRelease(spec.release, ground, ring.radius or 7, direction, ring.length or 0, ring.halfAngle or 0, tint, view.height)
				ElementFx.sound(AttackFx.SOUNDS.boom, ground, 0.7)
				ScreenFx.shakeAt(AttackFx.SHAKE.bossSlam, ground)
				local flash = AttackFx.FLASH.bossSlam
				if ScreenFx.distance(ground) <= AttackFx.SHAKE.NEAR then
					ScreenFx.flash(color(flash.color), flash.strength, flash.seconds)
				end
			end
		elseif event.type == "attack" and not event.dodged then
			local spot = targetPosition(event.to, view.root.Position)
			ElementFx.monsterStrike(spec.strike, spot, view.root.Position, tint)
			ScreenFx.shakeAt(AttackFx.SHAKE.bossStrike, spot)
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
			elseif event.type == "cast" then
				onCast(event)
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
