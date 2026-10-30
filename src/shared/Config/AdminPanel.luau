--!strict
-- The Studio admin panel (AdminPanelController): the dev chat commands (DevService) as buttons. A command with "%s"
-- has a text box beside its button and sends what's typed there. Items and bosses get their own sections, built from
-- Config/Items and Config/Bosses. Plain data so Lune tests check every command exists.
export type Button = { label: string, command: string, placeholder: string? }
export type Section = { title: string, buttons: { Button } }

local AdminPanel = {}

AdminPanel.SECTIONS = {
	{
		title = "Money and levels",
		buttons = {
			{ label = "+$1,000", command = "/cash 1000" },
			{ label = "+$100,000", command = "/cash 100000" },
			{ label = "+1,000 XP", command = "/xp 1000" },
			{ label = "+50,000 XP", command = "/xp 50000" },
			{ label = "Set level", command = "/level %s", placeholder = "shop level" },
		},
	},
	{
		title = "Cards",
		buttons = {
			{ label = "Maxed card", command = "/maxcard %s", placeholder = "card name or number" },
			{ label = "Maxed foil card", command = "/maxcard %s foil", placeholder = "card name or number" },
			{ label = "Plain copies", command = "/givecard %s", placeholder = "number amount (e.g. 12 5)" },
			{ label = "+100,000 creature XP", command = "/beastxp 100000" },
			{ label = "Grade S Legendaries", command = "/legendarys" },
			{ label = "Foil Grade S Legendaries", command = "/legendarys foil" },
			{ label = "Rarity pack", command = "/raritypack" },
			{ label = "Foil rarity pack", command = "/raritypack foil" },
			{ label = "Foil Legendary pack", command = "/testpack" },
			{ label = "Star Shard + Frontier card", command = "/frontierdrop" },
		},
	},
	{
		title = "Fights and places",
		buttons = {
			{ label = "Wake resting cards", command = "/rest" },
			{ label = "Elite next to me", command = "/elite" },
			{ label = "Go to the Wild", command = "/wild" },
			{ label = "Go to the arena", command = "/arena" },
			{ label = "Toggle Extra Job Slot", command = "/jobslot" },
		},
	},
	{
		title = "Town",
		buttons = {
			{ label = "Morning", command = "/time morning" },
			{ label = "Afternoon", command = "/time afternoon" },
			{ label = "Sunset", command = "/time sunset" },
			{ label = "Night", command = "/time night" },
			{ label = "Dawn", command = "/time dawn" },
		},
	},
	{
		title = "Dungeon (Dungeon window)",
		buttons = {
			{ label = "To room 2", command = "/room 2" },
			{ label = "To room 3", command = "/room 3" },
			{ label = "To the Hydra", command = "/room 4" },
			{ label = "+10 Hydra fragments", command = "/item fragment_prismHydra 10" },
		},
	},
} :: { Section }

AdminPanel.ITEM_AMOUNTS = { 1, 10 } -- one button each per item
AdminPanel.COMMAND_MAX_LENGTH = 120 -- the server ignores longer requests
AdminPanel.COMMAND_COOLDOWN = 0.2 -- seconds between requests

-- The command to send: "%s" filled with the typed text (nil when it needs text and none was typed)
function AdminPanel.fill(command: string, typed: string): string?
	if not string.find(command, "%s", 1, true) then
		return command
	end
	local text = string.match(typed, "^%s*(.-)%s*$") or ""
	if text == "" then
		return nil
	end
	return (string.gsub(command, "%%s", function()
		return text
	end))
end

return AdminPanel
