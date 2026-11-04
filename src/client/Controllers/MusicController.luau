--!strict
-- Background music (Config/Music, Util/MusicRules): the town's gentle pieces under its birds, wind and waterfall (owner
-- 2026-11-04), and the Wild valley's (owner 2026-11-04: "finalize the wilds"): a piece for each of its three areas and a
-- battle piece in each boss arena. Where you are picks whose music plays (an arena, else the valley's area, else the
-- town; nowhere: quiet) and moving on crossfades to the next on a second sound. The town's tracks take turns with a
-- little quiet between them; the Wild's loop. Started in the main place only.
-- In Studio, "/music [place] <n> [volume]" (DevService) sets the player's MusicPreviewPlace / MusicPreview /
-- MusicPreviewVolume attributes: that option loops wherever you are instead ("/music <place> 0" clears them).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Music = require(Config:WaitForChild("Music"))
local Town = require(Config:WaitForChild("Town"))
local WildValleyConfig = require(Config:WaitForChild("WildValley"))
local MusicRules = require(Shared:WaitForChild("Util"):WaitForChild("MusicRules"))
local WildValley = require(Shared:WaitForChild("Util"):WaitForChild("WildValley"))

local MusicController = {}

-- One of the two sounds the music crossfades between
type Deck = { sound: Sound, squash: CompressorSoundEffect, fade: Tween?, token: number }

local function makeDeck(name: string): Deck
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.Volume = 0
	sound.Parent = SoundService
	-- Evens out a track's louder parts where its place asks for it (Config/Music TOWN compressor)
	local squash = Instance.new("CompressorSoundEffect")
	squash.Enabled = false
	squash.Parent = sound
	return { sound = sound, squash = squash, fade = nil, token = 0 }
end

local function fadeTo(deck: Deck, volume: number, seconds: number)
	if deck.fade then
		deck.fade:Cancel()
	end
	local tween = TweenService:Create(deck.sound, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Volume = volume })
	deck.fade = tween
	tween:Play()
end

-- What should play: a place's settings, the sound id, whether it loops, its volume and a name for it (nil place: quiet)
type Want = { place: any, id: string?, looped: boolean, volume: number, name: string }

function MusicController.Start()
	local player = Players.LocalPlayer
	local decks = { makeDeck("MusicA"), makeDeck("MusicB") }
	local live = 1 -- the deck playing now
	local playing = "none" -- the name of what plays (Want.name)
	local last: string? = nil -- the place you were in
	local tracks: { [string]: number } = {} -- each place's track in its turns

	-- Studio's music preview: the place and option it picked, and its volume
	local function preview(): Want?
		local key = player:GetAttribute("MusicPreviewPlace")
		local index = player:GetAttribute("MusicPreview")
		local volume = player:GetAttribute("MusicPreviewVolume")
		local place = if typeof(key) == "string" then MusicRules.find(Music, key) else nil
		if not place or typeof(index) ~= "number" or not place.options[index] then
			return nil
		end
		return {
			place = place,
			id = place.options[index].id,
			looped = true,
			volume = if typeof(volume) == "number" then volume else place.volume,
			name = `{place.key}:preview:{index}`,
		}
	end

	-- Whose music plays where you are (MusicRules.place, from the arena, the valley's area and the town)
	local function here(): string?
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not root or not root:IsA("BasePart") then
			return last
		end
		local x, z = root.Position.X, root.Position.Z
		local arena = WildValley.arenaZoneAt(WildValleyConfig, Bosses.ARENA_COPIES, x, z)
		local area = WildValley.zoneAt(WildValleyConfig, { x = x, z = z })
		local inTown = MusicRules.inTown(x, z, Town.BOUNDS, Music.TOWN.margin)
		last = MusicRules.place(Music, arena, area, inTown, last)
		return last
	end

	local function wanted(): Want
		local test = preview()
		if test then
			return test
		end
		local key = here()
		local place = if key then MusicRules.find(Music, key) else nil
		if not place then
			return { place = nil, id = nil, looped = true, volume = 0, name = "none" }
		end
		-- A place with a gap between tracks (the town) takes turns; one track and no gap loops
		local turns = place.gap ~= nil or #place.tracks > 1
		local index = tracks[place.key] or 1
		return { place = place, id = place.tracks[index], looped = not turns, volume = place.volume, name = place.key }
	end

	-- Crossfades to `want` on the other deck (nothing to play: just fades out)
	local function switch(want: Want)
		local seconds = if want.place then want.place.fade or Music.WILD.fade else Music.WILD.fade
		local old = decks[live]
		old.token += 1
		local oldToken = old.token
		fadeTo(old, 0, seconds)
		task.delay(seconds + 0.1, function()
			if old.token == oldToken then
				old.sound:Stop()
			end
		end)
		playing = want.name
		if not want.id then
			return
		end
		live = 3 - live
		local deck = decks[live]
		deck.token += 1
		deck.sound.SoundId = want.id
		deck.sound.Looped = want.looped
		deck.sound.TimePosition = 0
		deck.sound.Volume = 0
		local squash = want.place.compressor
		deck.squash.Enabled = squash ~= nil
		if squash then
			deck.squash.Threshold = squash.threshold
			deck.squash.Ratio = squash.ratio
			deck.squash.Attack = squash.attack
			deck.squash.Release = squash.release
		end
		deck.sound:Play()
		fadeTo(deck, want.volume, seconds)
	end

	local function update()
		local want = wanted()
		if want.name ~= playing then
			switch(want)
		elseif want.id then
			fadeTo(decks[live], want.volume, 0.3) -- a preview's volume changed
		end
	end

	-- A place's track ended (the town's turns): its next one after the quiet gap, on the same deck
	for index, deck in decks do
		deck.sound.Ended:Connect(function()
			local want = wanted()
			if index ~= live or want.looped or not want.place or want.name ~= playing then
				return
			end
			local place = want.place
			local token = deck.token
			task.delay(place.gap or 0, function()
				if index ~= live or deck.token ~= token or playing ~= place.key then
					return
				end
				local turn = MusicRules.nextTrack(tracks[place.key] or 1, #place.tracks)
				tracks[place.key] = turn
				deck.sound.SoundId = place.tracks[turn]
				deck.sound.TimePosition = 0
				deck.sound:Play()
			end)
		end)
	end

	for _, attribute in { "MusicPreviewPlace", "MusicPreview", "MusicPreviewVolume" } do
		player:GetAttributeChangedSignal(attribute):Connect(update)
	end
	task.spawn(function()
		while true do
			update()
			task.wait(Music.TOWN.checkEvery)
		end
	end)
end

return MusicController
