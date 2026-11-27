--!strict
-- Whether a player's play goes into the analytics (Creator Hub: funnels, custom events). The game owner's test save
-- (`/slot test`, SaveSlotService sets the TestSave attribute when it loads) never does: its fresh runs and admin panel
-- jumps would read as new players (spec docs/superpowers/specs/2026-11-27-live-admin-creator-design.md). Every
-- AnalyticsService call asks here first (tests/DevGate).
local AnalyticsGate = {}

function AnalyticsGate.allowed(player: Player): boolean
	return player:GetAttribute("TestSave") ~= true
end

return AnalyticsGate
