--!strict
-- The owner's test save (owner 2026-11-16: "is there anyway I can experience what new player experience without
-- wiping?"): the game's owner alone can switch to a separate save and back ("/slot test", "/slot main") and start
-- another fresh one ("/slot reset"); the real save is never touched. Which key a profile loads, the stored choice
-- checked, the commands, and who may choose. Pure (no Roblox APIs); DataService and SaveSlotService use it.
local SaveSlots = {}

export type State = { test: boolean, run: number }

function SaveSlots.clean(raw: any): State
	if typeof(raw) ~= "table" then
		return { test = false, run = 1 }
	end
	local run = if typeof(raw.run) == "number" and raw.run >= 1 then math.floor(raw.run) else 1
	return { test = raw.test == true, run = run }
end

-- The profile key: the real one, or the test run's own. Studio's test save is its own (2026-11-16: Studio checks were
-- landing on the owner's live playthrough), whatever the run
function SaveSlots.key(prefix: string, userId: number, state: State, studio: boolean?): string
	if state.test and studio then
		return `{prefix}{userId}_studio`
	elseif state.test then
		return `{prefix}{userId}_test{state.run}`
	end
	return `{prefix}{userId}`
end

-- "test" (the test save), "main" (the real one), "reset" (a fresh test save); false for anything else
function SaveSlots.apply(state: State, command: string): (State, boolean)
	if command == "test" then
		return { test = true, run = state.run }, true
	elseif command == "main" then
		return { test = false, run = state.run }, true
	elseif command == "reset" then
		return { test = true, run = state.run + 1 }, true
	end
	return state, false
end

-- The game's owner: a user-owned game's creator (a group's id is no player's; 0: not published)
function SaveSlots.isOwner(userId: number, creatorId: number, creatorType: string): boolean
	return creatorType == "User" and creatorId ~= 0 and userId == creatorId
end

return SaveSlots
