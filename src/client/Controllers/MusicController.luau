--!strict
-- Background music (Config/Music, Util/MusicRules): the town's gentle pieces under its birds, wind and waterfall (owner
-- 2026-11-04), and the Wild valley's (owner 2026-11-04: "finalize the wilds"): a piece for each of its three areas, with
-- an ambient loop under it, and a battle piece in each boss arena. Where you are picks whose music plays (an arena,
-- else the valley's area, else the town; nowhere: quiet) and moving on crossfades to the next on a second sound (the
-- ambience the same way, on its own pair). A place's leveler (`compressor`) evens out its louder parts. The town's tracks
-- take turns with a little quiet between them; the Wild's loop. Started in the main place only.
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
local MusicRules = require(Shared:WaitForChild("Util"):WaitForChild("MusicRules"))
local WildValley = require(Shared:WaitForChild("Util"):WaitForChild("WildValley"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local WildValleyConfig = Place.getValley() -- the place's valley (Util/Place)
local FRONTIER = Place.isFrontier()
local World = if FRONTIER then (Music :: any).FRONTIER else Music.WILD -- the valley's music (no town in the Frontier)
local OpeningStage = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("OpeningStage"))

local MusicController = {}

-- One of the two sounds a layer crossfades between
type Deck = { sound: Sound, squash: CompressorSoundEffect, fade: Tween?, token: number }
-- The music or the ambience: its two decks, the one playing and the name of what plays
type Layer = { decks: { Deck }, live: number, playing: string }
-- What a layer should play: its sound id (nil: quiet), whether it loops, its volume, its leveler and a name for it
type Want = { place: any, id: string?, looped: boolean, volume: number, compressor: any, name: string }

local QUIET: Want = { place = nil, id = nil, looped = true, volume = 0, compressor = nil, name = "none" }

local function makeDeck(name: string): Deck
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.Volume = 0
	sound.Parent = SoundService
	local squash = Instance.new("CompressorSoundEffect")
	squash.Enabled = false
	squash.Parent = sound
	return { sound = sound, squash = squash, fade = nil, token = 0 }
end

local function makeLayer(name: string): Layer
	return { decks = { makeDeck(`{name}A`), makeDeck(`{name}B`) }, live = 1, playing = "none" }
end

local function fadeTo(deck: Deck, volume: number, seconds: number)
	if deck.fade then
		deck.fade:Cancel()
	end
	local tween = TweenService:Create(deck.sound, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Volume = volume })
	deck.fade = tween
	tween:Play()
end

-- Crossfades a layer to `want` on its other deck (nothing to play: just fades out)
local function switch(layer: Layer, want: Want)
	local seconds = if want.place then want.place.fade or Music.WILD.fade else Music.WILD.fade
	local old = layer.decks[layer.live]
	old.token += 1
	local oldToken = old.token
	fadeTo(old, 0, seconds)
	task.delay(seconds + 0.1, function()
		if old.token == oldToken then
			old.sound:Stop()
		end
	end)
	layer.playing = want.name
	if not want.id then
		return
	end
	layer.live = 3 - layer.live
	local deck = layer.decks[layer.live]
	deck.token += 1
	deck.sound.SoundId = want.id
	deck.sound.Looped = want.looped
	deck.sound.TimePosition = 0
	deck.sound.Volume = 0
	local squash = want.compressor
	deck.squash.Enabled = squash ~= nil
	if squash then
		deck.squash.Threshold = squash.threshold
		deck.squash.Ratio = squash.ratio
		deck.squash.Attack = squash.attack
		deck.squash.Release = squash.release
		deck.squash.GainMakeup = squash.makeup or 0
	end
	deck.sound:Play()
	fadeTo(deck, want.volume, seconds)
end

-- Plays `want` on the layer: crossfading when it's something new, else easing to its volume (a preview's changed)
local function apply(layer: Layer, want: Want)
	if want.name ~= layer.playing then
		switch(layer, want)
	elseif want.id then
		fadeTo(layer.decks[layer.live], want.volume, 0.3)
	end
end

function MusicController.Start()
	local player = Players.LocalPlayer
	local music = makeLayer("Music")
	local ambience = makeLayer("Ambience")
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
			compressor = place.compressor,
			name = `{place.key}:preview:{index}`,
		}
	end

	-- Whose music plays where you are (MusicRules.place, from the arena, the valley's area and the town)
	local function here(): any
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			local x, z = root.Position.X, root.Position.Z
			local arena = WildValley.arenaZoneAt(WildValleyConfig, Bosses.ARENA_COPIES, x, z)
			local area = WildValley.zoneAt(WildValleyConfig, { x = x, z = z })
			local inTown = not FRONTIER and MusicRules.inTown(x, z, Town.BOUNDS, Music.TOWN.margin)
			last = MusicRules.place(Music, arena, area, inTown, last, World)
		end
		-- The pack opening has its own music while it shows; where you are (`last`) is kept for after
		if OpeningStage.isShown() then
			return Music.OPENING
		end
		return if last then MusicRules.find(Music, last) else nil
	end

	local function wantedMusic(place: any): Want
		local test = preview()
		if test then
			return test
		end
		if not place then
			return QUIET
		end
		-- A place with a gap between tracks (the town) takes turns; one track and no gap loops, and so does each visit's
		-- piece of a place that changes it per visit (the pack opening)
		local turns = place.rotate ~= "visit" and (place.gap ~= nil or #place.tracks > 1)
		local index = tracks[place.key] or 1
		return { place = place, id = place.tracks[index], looped = not turns, volume = place.volume, compressor = place.compressor, name = place.key }
	end

	local function wantedAmbience(place: any): Want
		local loop = if place then place.ambient else nil
		if not loop then
			return QUIET
		end
		return { place = place, id = loop.id, looped = true, volume = loop.volume, compressor = nil, name = place.key }
	end

	local visiting: string? = nil -- the place whose music wants playing now, to see you arrive at it
	local function update()
		local place = here()
		local key = if place then place.key else nil
		if key ~= visiting then
			visiting = key
			if place and place.rotate == "visit" then
				tracks[place.key] = MusicRules.visitTrack(tracks[place.key], #place.tracks)
			end
		end
		apply(music, wantedMusic(place))
		apply(ambience, wantedAmbience(place))
	end

	-- A place's music track ended (the town's turns): its next one after the quiet gap, on the same deck
	for index, deck in music.decks do
		deck.sound.Ended:Connect(function()
			local want = wantedMusic(here())
			if index ~= music.live or want.looped or not want.place or want.name ~= music.playing then
				return
			end
			local place = want.place
			local token = deck.token
			task.delay(place.gap or 0, function()
				if index ~= music.live or deck.token ~= token or music.playing ~= place.key then
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
