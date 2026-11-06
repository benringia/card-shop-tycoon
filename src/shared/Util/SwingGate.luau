--!strict
-- Which of your sword actions is still live (SwordController; the sword-moves round's final review). Each cut, the
-- dash slash and the dodge takes a token when it's pressed; whatever is still waiting to happen for an older one (a cut
-- queued for its cancel point, its lunge, its arc, the dash) checks its token and stops. A dodge, a knock-down or the
-- fight's end cancels everything. No cut starts until a skill frees you (its damage committed). The last cut whose strike frame came is
-- kept for the server's hit a round trip later: a mash tap moves the combo on, not what landed. Roblox-free.
local SwingGate = {}

-- `cancelledAt`: the token the last dodge, knock-down or fight end took (actions before it were cancelled)
export type Gate = { token: number, skillEndsAt: number, struckIndex: number?, cancelledAt: number }

function SwingGate.new(): Gate
	return { token = 0, skillEndsAt = 0, struckIndex = nil, cancelledAt = 0 }
end

-- A new action takes over: its token (older ones stop being live)
function SwingGate.begin(gate: Gate): number
	gate.token += 1
	return gate.token
end

-- A dodge, a knock-down or the fight's end: nothing queued or playing carries on, and the attack button is free
function SwingGate.cancel(gate: Gate)
	gate.token += 1
	gate.cancelledAt = gate.token
	gate.skillEndsAt = 0
end

function SwingGate.live(gate: Gate, token: number): boolean
	return gate.token == token
end

-- Not cancelled since it started (a newer cut doesn't count): a skill's damage moment and effects still come
-- (owner 2026-11-07, "free after the hit": you can cut again once its damage is committed)
function SwingGate.uncancelled(gate: Gate, token: number): boolean
	return token > gate.cancelledAt
end

-- A skill starts at `now`, holding the attack button for `free` seconds (SwordRules.skillFreeAt): its token
function SwingGate.startSkill(gate: Gate, now: number, free: number): number
	gate.skillEndsAt = now + free
	return SwingGate.begin(gate)
end

function SwingGate.canAttack(gate: Gate, now: number): boolean
	return now >= gate.skillEndsAt
end

-- Cut `index` reached its strike frame
function SwingGate.struck(gate: Gate, index: number)
	gate.struckIndex = index
end

function SwingGate.lastStruck(gate: Gate): number?
	return gate.struckIndex
end

return SwingGate
