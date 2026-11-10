--!strict
-- A special's spotlight (the owner 2026-11-10: "the basic attack effects of the creature fighting with me is causing
-- my weapon skill animation to be hard to see... special skills animation/fx should always be visible"): while your
-- sword skill or a super plays, or a camera moment (your skill's, a super's), creatures' basic attacks draw nothing
-- new (Util/FightFx). Bosses' and monsters' attacks still show: they warn you where a hit lands. On this client only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("Config"):WaitForChild("AttackFx"))
local FightFxRules = require(Shared:WaitForChild("Util"):WaitForChild("FightFxRules"))
local SkillCinematic = require((script.Parent :: Instance):WaitForChild("SkillCinematic"))
local SuperCinematic = require((script.Parent :: Instance):WaitForChild("SuperCinematic"))

local Spotlight = {}

local holdUntil = 0

-- A special plays for `seconds` from now (and AttackFx.SPOTLIGHT.tail after, while its effects fade)
function Spotlight.hold(seconds: number)
	holdUntil = FightFxRules.spotlightUntil(os.clock(), holdUntil, math.max(0, seconds), AttackFx.SPOTLIGHT.tail)
end

-- Whether creatures' basic attacks keep out of the picture now
function Spotlight.active(): boolean
	return FightFxRules.quiet(os.clock(), holdUntil, SkillCinematic.isPlaying() or SuperCinematic.isPlaying())
end

return Spotlight
