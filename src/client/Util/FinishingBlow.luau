--!strict
-- The finishing blow (owner 2026-11-25: picked it "but no KO popout", felt a test: "strong feels good, freeze the
-- creature too"; spec 2026-11-25-finishing-blow-design, numbers Config/FinishingBlow): your own fight's last hit holds
-- everything a beat (the monster, held by MonsterController and Util/MonsterKO; your character's animations; every
-- creature in the fight), punches your camera in and lands a deep thud; a boss's flashes your screen white too. Played
-- through hooks BattleController wires (it knows your fight), on MonsterController's beaten monsters.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("FinishingBlow"))
local FinishingBlowRules = require(Shared:WaitForChild("Util"):WaitForChild("FinishingBlowRules"))

local ClientUtil = script.Parent :: Instance
local ScreenFx = require(ClientUtil:WaitForChild("ScreenFx"))
local SoundBank = require(ClientUtil:WaitForChild("SoundBank"))

local FinishingBlow = {}

export type Hooks = {
	-- MonsterController.SetFinishingBlow: asks once a monster is beaten
	onBeaten: (callback: (marker: BasePart, boss: boolean) -> FinishingBlowRules.Moment?) -> (),
	-- your fight is running and this is its monster (FinishingBlowRules.mine)
	isFoe: (marker: BasePart) -> boolean,
	-- SwordController.PunchZoom
	punch: (degrees: number, inSeconds: number, holdSeconds: number, backSeconds: number) -> (),
	-- the fight's creatures held still this long (CreatureController.Freeze on each)
	holdCreatures: (seconds: number) -> (),
}

-- Your character's playing animations held still `seconds`, then on at the speed each had
local function holdCharacter(seconds: number)
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if not animator then
		return
	end
	local held: { [AnimationTrack]: number } = {}
	for _, track in animator:GetPlayingAnimationTracks() do
		held[track] = track.Speed
		track:AdjustSpeed(0)
	end
	task.delay(seconds, function()
		for track, speed in held do
			if track.IsPlaying then
				track:AdjustSpeed(speed)
			end
		end
	end)
end

local function playSound(id: string, volume: number)
	local sound = SoundBank.make(id)
	sound.Volume = volume
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

function FinishingBlow.attach(hooks: Hooks)
	SoundBank.keep({ Config.WILD.sound, Config.BOSS.sound }) -- loaded before the first win
	hooks.onBeaten(function(marker: BasePart, boss: boolean): FinishingBlowRules.Moment?
		if not hooks.isFoe(marker) then
			return nil
		end
		local moment: FinishingBlowRules.Moment = if boss then Config.BOSS else Config.WILD
		holdCharacter(moment.hold)
		hooks.holdCreatures(moment.hold)
		hooks.punch(moment.zoom, moment.zoomIn, moment.hold, moment.back)
		playSound(moment.sound, moment.volume)
		if boss then
			-- a wild monster's kick comes with its knockout (Util/MonsterKO); a boss isn't knocked out
			ScreenFx.shakeAt(moment.shake, marker.Position)
		end
		if moment.flash > 0 then
			ScreenFx.flash(Color3.new(1, 1, 1), moment.flash, moment.hold + Config.FLASH_TAIL)
		end
		return moment
	end)
end

return FinishingBlow
