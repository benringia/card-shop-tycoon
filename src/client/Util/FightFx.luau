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
local MoveFxConfig = require(Shared:WaitForChild("Config"):WaitForChild("MoveFx"))
local MoveFxRules = require(Shared:WaitForChild("Util"):WaitForChild("MoveFxRules"))
local AttackTiming = require(Shared:WaitForChild("Util"):WaitForChild("AttackTiming"))
local FightFxRules = require(Shared:WaitForChild("Util"):WaitForChild("FightFxRules"))
local MonsterMoves = require(Shared:WaitForChild("Util"):WaitForChild("MonsterMoves"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))
local Extras = require((script.Parent :: Instance):WaitForChild("Extras"))
local MoveFx = require((script.Parent :: Instance):WaitForChild("MoveFx"))
local SuperFx = require((script.Parent :: Instance):WaitForChild("SuperFx"))
local SuperFxConfig = require(Shared:WaitForChild("Config"):WaitForChild("SuperFx"))
local SuperFxRules = require(Shared:WaitForChild("Util"):WaitForChild("SuperFxRules"))
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
	pose: (marker: BasePart, kind: string, amount: number?) -> (), -- amount: how big (1 when nil)
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

	-- Super moves (spec 2026-11-05-super-moves-design): their charge from the press to the impact and what lingers after,
	-- by caster id (Util/SuperFx). Always played (the cue everyone watches for); an onlooker's capped at C while the
	-- effects are over budget.
	local superCharges: { [string]: () -> () } = {}
	local superLingers: { [string]: () -> () } = {}

	local function stopSuperCharge(id: string)
		local stop = superCharges[id]
		if stop then
			superCharges[id] = nil
			stop()
		end
	end

	local function stopSuperLinger(id: string)
		local stop = superLingers[id]
		if stop then
			superLingers[id] = nil
			stop()
		end
	end

	local function superGrade(view: View): string
		local grade = SuperFxRules.grade(view.grade, Extras.enabled(), SuperFxConfig)
		if not view.mine and not FightFxRules.budget(active, Extras.enabled(), AttackFx) then
			return "C"
		end
		return grade
	end

	local function onSuperCast(event: any)
		local marker = resolve.marker(event.from)
		local view = if marker then resolve.creature(marker) else nil
		if not marker or not view then
			return
		end
		local seconds = math.max(0.1, tonumber(event.seconds) or 1.5)
		local grade = superGrade(view)
		stopSuperCharge(event.from)
		resolve.setCharging(marker, seconds)
		local look = SuperFxConfig.LOOKS[event.look]
		-- Its wind-up pose (owner 2026-11-05: Inferno and Magma Slam leap high), else the charge crouch
		resolve.pose(marker, look.windupPose or "charge", if look.windupPose then 1 else look.grades[grade].scale)
		local target = if typeof(event.to) == "string" then targetPosition(event.to, view.root.Position) else nil
		local ok, stop = pcall(SuperFx.charge, event.look, view, grade, seconds, target)
		if ok and stop then
			superCharges[event.from] = stop
		elseif not ok then
			warn("[FightFx] super charge:", stop)
		end
	end

	-- A Pet button move or super move winding up (Combat.ABILITY_WINDUP, owner 2026-11-04 design A): the creature
	-- holds still in a big glow, a ring in the move's colour spins under it and the move's name pops above it; the move
	-- itself lands with its "ability" event. Always shown (it's the cue everyone watches for).
	local function onCast(event: any)
		if typeof(event.look) == "string" and SuperFxConfig.LOOKS[event.look] then
			onSuperCast(event)
			return
		end
		local spec = AttackFx.SPECIALS[event.kind]
		local marker = resolve.marker(event.from)
		local view = if marker then resolve.creature(marker) else nil
		if not spec or not marker or not view then
			return
		end
		local seconds = math.max(0.1, tonumber(event.seconds) or 0.5)
		local tint = color(spec.color)
		-- The four finished Pet button moves wind up bigger with grade (Config/MoveFx WINDUP, POSE_AMOUNT)
		local grade = MoveFxRules.grade(view.grade, Extras.enabled(), MoveFxConfig)
		local finished = MoveFxConfig.POSES[event.kind] ~= nil
		local windup = if finished then MoveFxConfig.WINDUP[grade] else { glow = 1.7, ring = 1 }
		resolve.setCharging(marker, seconds)
		resolve.pose(marker, "charge", if finished then MoveFxConfig.POSE_AMOUNT[grade] else nil)
		ElementFx.chargeGlow(view.root, tint, seconds, windup.glow)
		ElementFx.castRing(view.root.Position - Vector3.new(0, view.height * 0.45, 0), tint, math.max(2, view.height * 0.8) * windup.ring, seconds)
		ElementFx.callout(view.root, view.height * 0.6, `{string.upper(MOVE_NAMES[event.kind] or event.kind)}!`, tint, seconds)
		if event.kind == "Curse" then
			-- Its rune circle opens under the caster as it winds up and stays through the hex (Util/MoveFx)
			MoveFx.curseCircle(view, grade, seconds + 0.9)
		end
		ElementFx.sound(AttackFx.SOUNDS.charge, view.root.Position)
	end

	-- Healing Rain's clouds (Util/MoveFx), one per creature it heals, by sim id
	local rains: { [string]: { stop: () -> (), ends: number } } = {}
	local RAIN = Combat.ABILITIES.Tide
	local RAIN_SECONDS = RAIN.ticks * RAIN.every + 0.4

	local function stopRain(id: string)
		local rain = rains[id]
		if rain then
			rains[id] = nil
			rain.stop()
		end
	end

	-- Overcharge's orbs (Util/MoveFx), by the caster's sim id: the sim's attack events say when one is spent
	local orbSets: { [string]: MoveFx.OrbSet } = {}

	local function clearOrbs(id: string)
		local set = orbSets[id]
		if set then
			orbSets[id] = nil
			MoveFx.clearOrbs(set)
		end
	end

	-- Vine Snare's vines on their target (Util/MoveFx), by the target's sim id
	local snares: { [string]: () -> () } = {}

	local function stopSnare(id: string)
		local stop = snares[id]
		if stop then
			snares[id] = nil
			stop()
		end
	end

	-- Curses on their targets (Util/MoveFx), by the target's sim id
	local curses: { [string]: () -> () } = {}

	local function stopCurse(id: string)
		local stop = curses[id]
		if stop then
			curses[id] = nil
			stop()
		end
	end

	-- A target's root part and height: a boss or monster (its view), a creature (the arena), else its marker
	local function targetBody(id: string?): (BasePart?, number)
		local marker = if typeof(id) == "string" then resolve.marker(id) else nil
		if not marker then
			return nil, 0
		end
		local lookup = resolve.monster
		local monster = if lookup then lookup(marker) else nil
		if monster then
			return monster.root, monster.height
		end
		local creature = resolve.creature(marker)
		if creature then
			return creature.root, creature.height
		end
		return marker, 6
	end

	local function startRain(id: string, view: View, grade: string, seconds: number, withSounds: boolean)
		stopRain(id)
		rains[id] = { stop = MoveFx.rain(view, grade, seconds, withSounds), ends = os.clock() + seconds }
	end

	-- A Healing Rain tick: its rising number on the healed creature (always shown: it's what the heal is), and a cloud
	-- over a creature the caster healed that has none yet (the caster's own starts as the move lands)
	local function onRegen(event: any)
		local to = event.to
		local marker = if typeof(to) == "string" then resolve.marker(to) else nil
		local view = if marker then resolve.creature(marker) else nil
		if not view then
			return
		end
		local casterMarker = if typeof(event.from) == "string" then resolve.marker(event.from) else nil
		local casterView = if casterMarker then resolve.creature(casterMarker) else nil
		local grade = MoveFxRules.grade((casterView or view).grade, Extras.enabled(), MoveFxConfig)
		local rain = rains[to]
		if (not rain or os.clock() > rain.ends) and FightFxRules.budget(active, Extras.enabled(), AttackFx) then
			startRain(to, view, grade, RAIN_SECONDS - RAIN.every, false)
		end
		MoveFx.rainTick(view, grade, tonumber(event.heal) or 0)
	end

	-- A super landing: its impact and linger (Util/SuperFx), a shake for everyone near it (the caster's own, bigger, is
	-- Util/SuperCinematic's)
	local function onSuperImpact(event: any)
		stopSuperCharge(event.from)
		local marker = resolve.marker(event.from)
		local view = if marker then resolve.creature(marker) else nil
		if not marker or not view then
			return
		end
		local grade = superGrade(view)
		local look = SuperFxConfig.LOOKS[event.look]
		resolve.pose(marker, look.pose or "cast", look.grades[grade].scale)
		if look.dash and typeof(event.to) == "string" then
			-- Stampede: the creature itself charges through its target and back
			resolve.dash(marker, targetPosition(event.to, view.root.Position), 1.25, 0.45)
		end
		local caster = view.root.Position + Vector3.new(0, view.height * 0.4, 0)
		local target = targetPosition(event.to, caster)
		local body, height = targetBody(event.to)
		stopSuperLinger(event.from)
		local ok, stop = pcall(SuperFx.impact, event.look, view, grade, target, body, height, string.sub(event.from, 1, 1))
		if ok and stop then
			superLingers[event.from] = stop
		elseif not ok then
			warn("[FightFx] super impact:", stop)
		end
	end

	-- A Pet button move or super move: a cast pose on the caster and its effect, all landing now (with the event), a
	-- shake near it and a flash on your screen when it's your creature's
	local function onSpecial(event: any)
		if typeof(event.look) == "string" and SuperFxConfig.LOOKS[event.look] then
			onSuperImpact(event)
			return
		end
		local spec = AttackFx.SPECIALS[event.kind]
		local marker = resolve.marker(event.from)
		local view = if marker then resolve.creature(marker) else nil
		if not spec or not marker or not view or not FightFxRules.budget(active, Extras.enabled(), AttackFx) then
			return
		end
		local caster = view.root.Position + Vector3.new(0, view.height * 0.4, 0)
		local target = targetPosition(event.to, caster)
		local tint = color(spec.color)
		local movePose = MoveFxConfig.POSES[event.kind]
		local grade = MoveFxRules.grade(view.grade, Extras.enabled(), MoveFxConfig)
		if movePose then
			resolve.pose(marker, movePose, MoveFxConfig.POSE_AMOUNT[grade])
		else
			resolve.pose(marker, "cast")
		end
		-- The finished moves play their own looks and sounds (Util/MoveFx)
		if event.kind == "Rain" then
			startRain(event.from, view, grade, RAIN_SECONDS, true)
			if view.mine then
				ScreenFx.flash(tint, AttackFx.FLASH.special.strength * 0.6, AttackFx.FLASH.special.seconds)
			end
			return
		elseif event.kind == "Overcharge" then
			clearOrbs(event.from)
			local set = MoveFx.orbs(view, grade)
			orbSets[event.from] = set
			task.delay(MoveFxConfig.ORB_TIMEOUT, function()
				if orbSets[event.from] == set then
					clearOrbs(event.from)
				end
			end)
			if view.mine then
				ScreenFx.flash(tint, AttackFx.FLASH.special.strength * 0.6, AttackFx.FLASH.special.seconds)
			end
			return
		elseif event.kind == "Curse" then
			local body, height = targetBody(event.to)
			if body and typeof(event.to) == "string" then
				stopCurse(event.to)
				curses[event.to] = MoveFx.curse(caster, body, height, grade, Combat.ABILITIES.Shade.seconds)
			end
			if view.mine then
				ScreenFx.flash(tint, AttackFx.FLASH.special.strength * 0.6, AttackFx.FLASH.special.seconds)
			end
			return
		elseif event.kind == "Snare" then
			local body, height = targetBody(event.to)
			if body and typeof(event.to) == "string" then
				stopSnare(event.to)
				snares[event.to] = MoveFx.vines(body, height, grade, Combat.ABILITIES.Bloom.seconds)
			end
			ScreenFx.shakeAt(AttackFx.SHAKE.special * MoveFxConfig.POSE_AMOUNT[grade], target)
			if view.mine then
				ScreenFx.flash(tint, AttackFx.FLASH.special.strength * 0.6, AttackFx.FLASH.special.seconds)
			end
			return
		end
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
			-- The supers' lasting looks react to any sender's events first (final review: a shield running out has no
			-- sender, a boss's hits take the monster path below)
			local decor = SuperFxRules.decorations(event)
			if decor.gone then
				SuperFx.shieldGone(decor.gone)
			end
			if decor.soaked then
				SuperFx.shieldHit(decor.soaked, targetPosition(event.from, Vector3.zero))
			end
			if decor.dodged then
				local dodger = resolve.marker(decor.dodged)
				local dodgerView = if dodger then resolve.creature(dodger) else nil
				if dodgerView then
					SuperFx.dodged(dodgerView.root, dodgerView.root.Position + Vector3.new(0, dodgerView.height * 0.5, 0))
				end
			end
			if typeof(event) == "table" then
				if event.type == "regen" then
					onRegen(event)
					continue
				elseif (event.type == "faint" or event.type == "swap") and typeof(event.to) == "string" then
					stopRain(event.to) -- the heal stops with it (BattleSim)
					clearOrbs(event.to)
					if event.type == "faint" then
						stopSnare(event.to)
						stopCurse(event.to)
					end
				end
			end
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
			elseif event.type == "attack" and not event.kind and typeof(event.orb) == "number" and orbSets[event.from] then
				-- An Overcharge fast attack spends an orb: it flies at the target with the hit
				local set = orbSets[event.from]
				MoveFx.spendOrb(set, targetPosition(event.to, set.view.root.Position), set.view.mine)
				if event.orb <= 0 then
					clearOrbs(event.from) -- the last fast attack: whatever's left goes (review: a set could outlive its fight)
				end
				if not event.dodged then
					onAttack(event)
				end
			elseif event.type == "orbs" and orbSets[event.from] then
				MoveFx.fizzleOrb(orbSets[event.from])
			elseif event.type == "attack" and not event.kind and not event.dodged then
				onAttack(event)
			elseif event.type == "ability" and event.kind and AttackFx.SPECIALS[event.kind] then
				onSpecial(event)
			elseif event.type == "fizzle" and typeof(event.from) == "string" then
				stopSuperCharge(event.from) -- its caster fainted mid wind-up
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
		for id in rains do
			stopRain(id)
		end
		for id in snares do
			stopSnare(id)
		end
		for id in orbSets do
			clearOrbs(id)
		end
		for id in curses do
			stopCurse(id)
		end
		for id in superCharges do
			stopSuperCharge(id)
		end
		-- A super that just landed (often the killing blow) plays out on its own timers (final review: the fight's end
		-- wiped its impact); only the shields' domes burst now
		superLingers = {}
		SuperFx.burstDomes()
	end

	return { onEvents = onEvents, destroy = destroy }
end

return FightFx
