--!strict
-- The phone's Reviews app (Config/Reviews): a customer's visit becomes a post, the feed keeps the newest, and how many
-- came since the last look. Pure (rolls passed in), Lune-tested.
local ReviewRules = {}

export type Post = { name: string, stars: number, line: string, at: number, color: number }
export type Rolls = { chance: number, name: number, line: number, stars: number, color: number } -- each 0 to <1

local function pick<T>(list: { T }, roll: number): T
	return list[math.floor(math.clamp(roll, 0, 0.999999) * #list) + 1]
end

-- The post for a visit's `outcome` at time `now`, or nil (an outcome with no posts, or this one doesn't post)
function ReviewRules.make(cfg: any, outcome: string, rolls: Rolls, now: number): Post?
	local look = cfg.OUTCOMES[outcome]
	if not look or rolls.chance >= look.chance then
		return nil
	end
	local low, high = look.stars[1], look.stars[2]
	return {
		name = pick(cfg.NAMES, rolls.name),
		stars = low + math.floor(math.clamp(rolls.stars, 0, 0.999999) * (high - low + 1)),
		line = pick(look.lines, rolls.line),
		at = now,
		color = math.floor(math.clamp(rolls.color, 0, 0.999999) * #cfg.COLORS) + 1,
	}
end

-- The feed with `post` on top, at most `max` long
function ReviewRules.push(list: { Post }, post: Post, max: number): { Post }
	local feed = { post }
	for index = 1, math.min(#list, max - 1) do
		table.insert(feed, list[index])
	end
	return feed
end

-- How many posts came after `seenAt` (the last time the app was opened)
function ReviewRules.unseen(list: { Post }, seenAt: number): number
	local count = 0
	for _, post in list do
		if post.at > seenAt then
			count += 1
		end
	end
	return count
end

return ReviewRules
