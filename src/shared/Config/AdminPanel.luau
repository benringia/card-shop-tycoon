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
			{ label = "Set XP (down too)", command = "/setxp %s", placeholder = "total XP" },
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
		-- The Pet button moves at each grade (spec 2026-11-05-pet-moves-design): played on your summoned creature against a
		-- dummy in front of it (MovePreviewController); "big" against a 14-stud dummy
		title = "Pet moves",
		buttons = {
			{ label = "Healing Rain C", command = "/movefx rain C" },
			{ label = "Healing Rain B", command = "/movefx rain B" },
			{ label = "Healing Rain A", command = "/movefx rain A" },
			{ label = "Healing Rain S", command = "/movefx rain S" },
			{ label = "Healing Rain S, big target", command = "/movefx rain S big" },
			{ label = "Vine Snare C", command = "/movefx vine C" },
			{ label = "Vine Snare B", command = "/movefx vine B" },
			{ label = "Vine Snare A", command = "/movefx vine A" },
			{ label = "Vine Snare S", command = "/movefx vine S" },
			{ label = "Vine Snare S, big target", command = "/movefx vine S big" },
			{ label = "Overcharge C", command = "/movefx orbs C" },
			{ label = "Overcharge B", command = "/movefx orbs B" },
			{ label = "Overcharge A", command = "/movefx orbs A" },
			{ label = "Overcharge S", command = "/movefx orbs S" },
			{ label = "Overcharge S, big target", command = "/movefx orbs S big" },
			{ label = "Curse C", command = "/movefx curse C" },
			{ label = "Curse B", command = "/movefx curse B" },
			{ label = "Curse A", command = "/movefx curse A" },
			{ label = "Curse S", command = "/movefx curse S" },
			{ label = "Curse S, big target", command = "/movefx curse S big" },
		},
	},
	{
		-- The super moves at grade C and S (spec 2026-11-05-super-moves-design): played on your summoned creature against a
		-- dummy in front of it, with the caster's cinematic (MovePreviewController)
		title = "Super moves",
		buttons = {
			{ label = "Inferno C", command = "/superfx inferno C" },
			{ label = "Inferno S", command = "/superfx inferno S" },
			{ label = "Magma Slam C", command = "/superfx magmaslam C" },
			{ label = "Magma Slam S", command = "/superfx magmaslam S" },
			{ label = "Tidal Shield C", command = "/superfx tidalshield C" },
			{ label = "Tidal Shield S", command = "/superfx tidalshield S" },
			{ label = "Tidal Blessing C", command = "/superfx tidalblessing C" },
			{ label = "Tidal Blessing S", command = "/superfx tidalblessing S" },
			{ label = "Stampede C", command = "/superfx stampede C" },
			{ label = "Stampede S", command = "/superfx stampede S" },
			{ label = "Eclipse C", command = "/superfx eclipse C" },
			{ label = "Eclipse S", command = "/superfx eclipse S" },
			{ label = "Rift Step C", command = "/superfx riftstep C" },
			{ label = "Rift Step S", command = "/superfx riftstep S" },
			{ label = "Supernova C", command = "/superfx supernova C" },
			{ label = "Supernova S", command = "/superfx supernova S" },
			{ label = "Thunderstorm C", command = "/superfx thunderstorm C" },
			{ label = "Thunderstorm S", command = "/superfx thunderstorm S" },
			{ label = "Devour C", command = "/superfx devour C" },
			{ label = "Devour S", command = "/superfx devour S" },
		},
	},
	{
		title = "Fights and places",
		buttons = {
			{ label = "Wake resting cards", command = "/rest" },
			{ label = "Tire the party (keep summoned)", command = "/tire" },
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
			{ label = "Replay intro", command = "/intro" },
			{ label = "Music 1: White Owl", command = "/music 1" },
			{ label = "Music 2: Wistful Wonderings", command = "/music 2" },
			{ label = "Music 3: Soft Tranquility", command = "/music 3" },
			{ label = "Music 4: Drifting Into Dreamland", command = "/music 4" },
			{ label = "Music 5: Lakefront Days (old)", command = "/music 5" },
			{ label = "Music: normal tracks", command = "/music 0" },
			{ label = "Music option at a volume", command = "/music %s", placeholder = "option volume (e.g. 2 0.08)" },
			{ label = "Meadow 1: Butterflies (guitar)", command = "/music meadow 1" },
			{ label = "Meadow 2: Running Through The Fields (piano)", command = "/music meadow 2" },
			{ label = "Meadow 3: Woodland Walk (guitar)", command = "/music meadow 3" },
			{ label = "Caves 1: Secret Waterfall (piano)", command = "/music gorge 1" },
			{ label = "Caves 2: Calm Waters (guitar)", command = "/music gorge 2" },
			{ label = "Caves 3: Air Currents (guitar)", command = "/music gorge 3" },
			{ label = "Ridge 1: Moonlight Sonata (piano)", command = "/music ridge 1" },
			{ label = "Ridge 2: Live Piano Stories 04 (piano)", command = "/music ridge 2" },
			{ label = "Ridge 3: Hombre Solo (guitar)", command = "/music ridge 3" },
			{ label = "Ridge 4: Air Currents (guitar)", command = "/music ridge 4" },
			{ label = "Warden 1: Forest Chase", command = "/music warden 1" },
			{ label = "Warden 2: Battle Of Wonderland", command = "/music warden 2" },
			{ label = "Warden 3: Combat Of Giants", command = "/music warden 3" },
			{ label = "Brood 1: Creepy Crawlers", command = "/music brood 1" },
			{ label = "Brood 2: Ghastly Unknown", command = "/music brood 2" },
			{ label = "Brood 3: The Dark Walk", command = "/music brood 3" },
			{ label = "Colossus 1: Giant's Grave", command = "/music colossus 1" },
			{ label = "Colossus 2: Heroic Battle of Giants", command = "/music colossus 2" },
			{ label = "Colossus 3: Fuel to the Fire", command = "/music colossus 3" },
			{ label = "Wild music at a volume", command = "/music %s", placeholder = "place option volume (e.g. meadow 2 0.003)" },
			{ label = "Summon 1: Soft bell ding", command = "/summonsound 1" },
			{ label = "Summon 2: Long bell ring", command = "/summonsound 2" },
			{ label = "Summon 3: Echo sparkle ping", command = "/summonsound 3" },
			{ label = "Summon 4: Airy magic swell", command = "/summonsound 4" },
			{ label = "Summon 5: Quiet twinkle (now)", command = "/summonsound 5" },
			{ label = "Unsummon 1: Airy whoosh", command = "/unsummonsound 1" },
			{ label = "Unsummon 2: Short soft whoosh", command = "/unsummonsound 2" },
			{ label = "Unsummon 3: Quick swish", command = "/unsummonsound 3" },
			{ label = "Unsummon 4: Shimmer pass", command = "/unsummonsound 4" },
			{ label = "Unsummon 5: Soft magic fade (now)", command = "/unsummonsound 5" },
			{ label = "Level up (pillar)", command = "/levelfx" },
			{ label = "Level 10 (rainbow + pack)", command = "/levelfx 10" },
			{ label = "Creature level up", command = "/beastlevelfx" },
			{ label = "Level sound 1: Soft sparkle ping (now)", command = "/levelsound 1" },
			{ label = "Level sound 2: Bright bell ding", command = "/levelsound 2" },
			{ label = "Level sound 3: Twirling chime", command = "/levelsound 3" },
			{ label = "Level sound at a volume", command = "/levelsound %s", placeholder = "set volume (e.g. 2 0.05)" },
			{ label = "Sword popup again", command = "/swordpopup" },
			{ label = "Button names again (3 fights)", command = "/buttonnames" },
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
