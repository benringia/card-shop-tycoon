--!strict
-- Studio only (paste into the command bar in Play, or run it through the Studio MCP on the Client): measures how loud
-- sounds are for Config/SoundLevels. Fill IDS from `lune run tools/audio/sound_ids` (the number part is enough). Each
-- plays at Volume 0 (PlaybackLoudness ignores Volume, so it's silent) and its level is the louder of its 90th percentile
-- and half its peak over up to 4 s; it prints `["<id>"] = <level>,` lines to paste into LEVELS.
local IDS: { string } = {
	-- "9116394876",
}

local SoundService = game:GetService("SoundService")
local results: { [string]: number } = {}
local pending = #IDS
for _, id in IDS do
	task.spawn(function()
		local sound = Instance.new("Sound")
		sound.SoundId = `rbxassetid://{id}`
		sound.Volume = 0
		sound.Parent = SoundService
		local started = os.clock()
		while not sound.IsLoaded and os.clock() - started < 8 do
			task.wait()
		end
		sound:Play()
		local samples = {}
		started = os.clock()
		while (sound.IsPlaying or os.clock() - started < 0.2) and os.clock() - started < 4 do
			table.insert(samples, sound.PlaybackLoudness)
			task.wait()
		end
		table.sort(samples)
		local peak = samples[#samples] or 0
		local high = samples[math.max(1, math.floor(#samples * 0.9))] or 0
		results[id] = math.round(math.max(high, peak * 0.5))
		sound:Destroy()
		pending -= 1
	end)
end
while pending > 0 do
	task.wait(0.2)
end
for id, level in results do
	print(`["{id}"] = {level},`)
end
