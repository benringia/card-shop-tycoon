--!strict
-- The petting popup's words (Config/PetReward; owner 2026-11-23): what a dog's buff gives, from its own numbers
-- (Config/Pish LUCK, Config/Chikin COURAGE), and when petting gives it again. Pure, Lune-tested (tests/PetRewardRules).
local PetRewardRules = {}

export type Words = { title: string, line: string, chip: string }

-- "3 minutes", "1 minute", "45 seconds"
function PetRewardRules.duration(seconds: number): string
	local whole = math.max(0, math.floor(seconds + 0.5))
	if whole >= 60 and whole % 60 == 0 then
		local minutes = whole // 60
		return if minutes == 1 then "1 minute" else `{minutes} minutes`
	end
	return if whole == 1 then "1 second" else `{whole} seconds`
end

-- "12:30", "0:45", "1:05:00" for a wait of `seconds`
function PetRewardRules.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	local hours, minutes, secs = whole // 3600, (whole % 3600) // 60, whole % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

-- What the popup says for `dog` ("Pish" or "Chikin"): its title, how long, what it does
function PetRewardRules.words(dog: string, config: any, luck: any, courage: any): Words?
	local style = config.DOGS[dog]
	if not style then
		return nil
	end
	if dog == "Pish" then
		return {
			title = style.title,
			line = string.format(style.line, PetRewardRules.duration(luck.seconds)),
			chip = string.format(style.chip, luck.fromRarity, math.floor(luck.boost * 100 + 0.5)),
		}
	end
	return {
		title = style.title,
		line = string.format(style.line, PetRewardRules.duration(courage.seconds)),
		chip = string.format(style.chip, math.floor(courage.share * 100 + 0.5)),
	}
end

-- The dog's bubble when petted too soon: "Lucky again in 12:30!"; nil when nothing is left to wait
function PetRewardRules.again(dog: string, config: any, left: number): string?
	local style = config.DOGS[dog]
	if not style or left <= 0 then
		return nil
	end
	return string.format(style.again, PetRewardRules.clock(left))
end

return PetRewardRules
