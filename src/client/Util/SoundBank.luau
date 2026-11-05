--!strict
-- Keeps one silent copy of each fight sound loaded for the whole session, so a sound made on the spot plays at once.
-- Measured in Studio (2026-11-05, owner: "some are delay some doesnt play specially on combat"): Roblox drops a sound's
-- audio once no Sound holds it, so a fresh Sound of an id whose last copy was destroyed loads again (about 0.46 s for
-- a boss's move played every 10 s, even with the asset fetched), and at a fight's start, with everything loading at
-- once, the first loads ran past the 4 s their holder part lives: those never played. With one copy kept, a fresh
-- Sound of the id is loaded the moment it's made. Util/CombatAssets keeps every id Util/CombatPreload lists while the
-- loading screen is up; `make` keeps any other id from its first play on.
local SoundService = game:GetService("SoundService")

local SoundBank = {}

local kept: { [string]: Sound } = {}
local folder: Folder? = nil

local function holder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local made = Instance.new("Folder")
	made.Name = "SoundBank"
	made.Parent = SoundService
	folder = made
	return made
end

-- Keeps a loaded copy of each id (never played); returns the new copies, for ContentProvider:PreloadAsync (preload
-- the Sound instances: an id string preloads nothing)
function SoundBank.keep(ids: { string }): { Sound }
	local fresh: { Sound } = {}
	for _, id in ids do
		local existing = kept[id]
		if id ~= "" and not (existing and existing.Parent) then
			local sound = Instance.new("Sound")
			sound.Name = string.match(id, "%d+") or id
			sound.SoundId = id
			sound.Parent = holder()
			kept[id] = sound
			table.insert(fresh, sound)
		end
	end
	return fresh
end

-- A fresh one-shot Sound for `id` (not parented, not playing), its audio already loaded when the id was kept
function SoundBank.make(id: string): Sound
	SoundBank.keep({ id })
	local sound = Instance.new("Sound")
	sound.SoundId = id
	return sound
end

return SoundBank
