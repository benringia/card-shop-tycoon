--!strict
-- Whether a cinematic may start now (owner 2026-11-13: "make the cinematic start only after the player screen is clear.
-- same with other cinematics"; client Util/ScreenClear): not while a purchase dialog is open (`promptSince`: when one
-- opened, nil once Roblox said it closed; one that never reports closing stops counting after `maxPrompt` seconds) or
-- the Roblox menu. Pure, Lune-tested.
local ScreenClearRules = {}

function ScreenClearRules.clear(s: { promptSince: number?, menuOpen: boolean, now: number }, maxPrompt: number): boolean
	if s.menuOpen then
		return false
	end
	return s.promptSince == nil or s.now - s.promptSince >= maxPrompt
end

return ScreenClearRules
