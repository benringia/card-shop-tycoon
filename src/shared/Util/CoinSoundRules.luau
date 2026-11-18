--!strict
-- When the coin sound plays (owner 2026-11-19: "Add a coin sound effect everytime you earn coin for everything";
-- Config/CoinSound, client Util/CoinSound): your cash went up (not down, not when it first arrives as your save loads),
-- not within GAP of the last one (a burst of earnings sounds once), and not while a reward holds it for its own moment.
-- Pure (no requires, no Roblox APIs): tests/CoinSoundRules runs it in Lune.
local CoinSoundRules = {}

type Config = { OPTIONS: { { id: string, name: string } }, DEFAULT: number, GAP: number }

-- Whether a change of cash from `before` to `after` at `now` plays the coin sound; `lastPlayed` the last time it did,
-- `heldUntil` the end of a hold (0: none)
function CoinSoundRules.plays(before: any, after: any, now: number, lastPlayed: number?, heldUntil: number, cfg: Config): boolean
	if typeof(before) ~= "number" or typeof(after) ~= "number" or after <= before + 1e-6 then
		return false
	end
	if now < heldUntil then
		return false
	end
	return lastPlayed == nil or now - lastPlayed >= cfg.GAP
end

-- Which of OPTIONS plays: the one picked by ear when it's a real option, else DEFAULT
function CoinSoundRules.option(cfg: Config, pick: any): number
	if typeof(pick) == "number" and pick == math.floor(pick) and pick >= 1 and pick <= #cfg.OPTIONS then
		return pick
	end
	return cfg.DEFAULT
end

return CoinSoundRules
