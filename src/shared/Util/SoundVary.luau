--!strict
-- A sound that plays over and over shouldn't sound like one clip on a loop (owner 2026-11-12: "randomize basic attack
-- sound for pets. adjust pitch every attack, so that it doesnt feel repeating, same with monster basic attack"): a clip
-- other than the last one, at a pitch clearly apart from the last. Pure (the roll is passed in), Lune-tested.
local SoundVary = {}

-- One of `count` clips, never `last` again when there's another
function SoundVary.pick(count: number, last: number?, roll: () -> number): number
	if count <= 1 then
		return 1
	end
	if not last or last < 1 or last > count then
		return math.min(count, 1 + math.floor(roll() * count))
	end
	-- one of the others: count - 1 choices, skipping `last`
	local index = 1 + math.floor(roll() * (count - 1))
	return if index >= last then index + 1 else index
end

-- A pitch in `range` at least `gap` from `last` (the side with room when the roll lands too close)
function SoundVary.pitch(range: { number }, last: number?, gap: number, roll: () -> number): number
	local low, high = range[1], range[2]
	local value = low + roll() * (high - low)
	if not last or math.abs(value - last) >= gap then
		return value
	end
	local above = high - (last + gap) -- room above the gap
	local below = (last - gap) - low -- and below it
	if above <= 0 and below <= 0 then
		return value -- the range is narrower than the gap: anything
	end
	local share = roll()
	if below <= 0 or (above > 0 and share >= below / (above + below)) then
		return last + gap + roll() * math.max(0, above)
	end
	return last - gap - roll() * math.max(0, below)
end

return SoundVary
