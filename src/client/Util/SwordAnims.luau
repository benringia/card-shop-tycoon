--!strict
-- Plays a sword's animations on a character (spec 2026-11-02-you-in-the-fight-design; docs/animations.md). Moves come
-- from Config/Swords' published ids; in Studio a move without one plays its KeyframeSequence from
-- ReplicatedStorage.SwordAnimations.<model> (registered locally, never published), so new moves can be tried before
-- they're uploaded. Tracks load once per character, on first use.
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Swords = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Swords"))

local SwordAnims = {}

export type Set = {
	play: (key: string, speed: number?, fade: number?) -> AnimationTrack?,
	stop: (key: string, fade: number?) -> (),
	track: (key: string) -> AnimationTrack?,
	hitStop: (seconds: number) -> (),
}

-- Moves a hit freezes for a moment (hit-stop)
local STRIKES = { "cut1", "cut2", "cut3", "skill" }

-- The animation id for a move: its published id, or (Studio) a temporary one from its KeyframeSequence
local function idFor(sword: Swords.Sword, key: string): string?
	local published = sword.animations[key]
	if published and published ~= "" then
		return published
	end
	if not RunService:IsStudio() then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild("SwordAnimations")
	local set = if folder then folder:FindFirstChild(sword.model) else nil
	local sequence = if set then set:FindFirstChild(key) else nil
	if not sequence or not sequence:IsA("KeyframeSequence") then
		return nil
	end
	return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
end

function SwordAnims.load(humanoid: Humanoid, swordId: string): Set
	local sword = Swords.SWORDS[swordId]
	local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator?
	local tracks: { [string]: AnimationTrack } = {}

	local function track(key: string): AnimationTrack?
		if tracks[key] or not sword or not animator then
			return tracks[key]
		end
		local id = idFor(sword, key)
		if not id then
			return nil
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, loaded = pcall(function()
			return (animator :: Animator):LoadAnimation(animation)
		end)
		if ok and loaded then
			tracks[key] = loaded
		end
		return tracks[key]
	end

	local function play(key: string, speed: number?, fade: number?): AnimationTrack?
		local loaded = track(key)
		if loaded then
			loaded:Play(fade or 0.05, 1, speed or 1)
		end
		return loaded
	end

	local function stop(key: string, fade: number?)
		local loaded = tracks[key]
		if loaded and loaded.IsPlaying then
			loaded:Stop(fade or 0.15)
		end
	end

	-- Every playing strike freezes for `seconds`, then carries on
	local function hitStop(seconds: number)
		for _, key in STRIKES do
			local loaded = tracks[key]
			if loaded and loaded.IsPlaying then
				loaded:AdjustSpeed(0)
				task.delay(seconds, function()
					if loaded.IsPlaying then
						loaded:AdjustSpeed(1)
					end
				end)
			end
		end
	end

	return { play = play, stop = stop, track = track, hitStop = hitStop }
end

return SwordAnims
