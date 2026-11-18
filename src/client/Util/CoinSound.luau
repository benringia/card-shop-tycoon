--!strict
-- The coin sound whenever your cash goes up (owner 2026-11-19: "Add a coin sound effect everytime you earn coin for
-- everything"; Config/CoinSound, Util/CoinSoundRules): a sale, a quest, a level-up, a fight, a kid's offer, money
-- back... once for a burst of them, a little pitch variety each time, held while a reward plays its own coins (a
-- monster's knockout poof). /coinsound <n> picks one of the options by ear (the CoinSoundPick attribute) and plays it
-- once (CoinSoundPreview).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CoinSoundConfig = require(Shared:WaitForChild("Config"):WaitForChild("CoinSound"))
local CoinSoundRules = require(Shared:WaitForChild("Util"):WaitForChild("CoinSoundRules"))
local SoundBank = require((script.Parent :: Instance):WaitForChild("SoundBank"))

local CoinSound = {}

local player = Players.LocalPlayer
local rng = Random.new()
local lastPlayed: number? = nil
local heldUntil = 0
local started = false

local function chosenId(): string
	local option = CoinSoundRules.option(CoinSoundConfig, player:GetAttribute("CoinSoundPick"))
	return CoinSoundConfig.OPTIONS[option].id
end

-- The coin sound now, whatever the gap or a hold (the cash watcher checks those first)
function CoinSound.play()
	lastPlayed = os.clock()
	local sound = SoundBank.make(chosenId())
	local pitch = CoinSoundConfig.PITCH
	sound.Volume = CoinSoundConfig.VOLUME
	sound.PlaybackSpeed = pitch[1] + rng:NextNumber() * (pitch[2] - pitch[1])
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
end

-- Keeps quiet for `seconds` (a reward that plays its own coins when it lands: a monster's knockout poof)
function CoinSound.hold(seconds: number)
	heldUntil = math.max(heldUntil, os.clock() + seconds)
end

-- Starts listening to the cash (once): each rise, DEFER later (so a reward with its own moment can hold it first)
function CoinSound.start()
	if started then
		return
	end
	started = true
	local ids = {}
	for _, option in CoinSoundConfig.OPTIONS do
		table.insert(ids, option.id)
	end
	SoundBank.keep(ids)
	local last = player:GetAttribute("Cash")
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		local before, after = last, player:GetAttribute("Cash")
		last = after
		task.delay(CoinSoundConfig.DEFER, function()
			if CoinSoundRules.plays(before, after, os.clock(), lastPlayed, heldUntil, CoinSoundConfig) then
				CoinSound.play()
			end
		end)
	end)
	player:GetAttributeChangedSignal("CoinSoundPreview"):Connect(CoinSound.play)
end

return CoinSound
