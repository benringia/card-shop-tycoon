--!strict
-- The Studio admin panel (AdminPanelController): the dev chat commands (DevService) as buttons. A command with "%s"
-- has a text box beside its button and sends what's typed there. Items and bosses get their own sections, built from
-- Config/Items and Config/Bosses. Plain data so Lune tests check every command exists.
export type Button = { label: string, command: string, placeholder: string? }
export type Section = { title: string, buttons: { Button } }

local AdminPanel = {}

AdminPanel.SECTIONS = {
	{
		-- The binder loading screens (spec 2026-11-13-loading-screen-binder-design), each played on your screen
		title = "Loading screens",
		buttons = {
			{ label = "Town", command = "/loading main" },
			{ label = "The Wild", command = "/loading wild" },
			{ label = "The Frontier", command = "/loading frontier" },
			{ label = "The Dungeon", command = "/loading dungeon" },
		},
	},
	{
		-- Shop decor (spec 2026-11-14-shop-decor-design): each shop look as if bought and in use, every piece placed
		title = "Decor",
		buttons = {
			{ label = "Cozy Wood", command = "/decor CozyWood" },
			{ label = "Candy Pastel", command = "/decor CandyPastel" },
			{ label = "Enchanted Forest", command = "/decor EnchantedForest" },
			{ label = "Neon Arcade", command = "/decor NeonArcade" },
			{ label = "Crystal Cave", command = "/decor CrystalCave" },
			{ label = "Starry Night", command = "/decor StarryNight" },
			{ label = "Every piece", command = "/decor pieces" },
		},
	},
	{
		title = "Windows",
		buttons = {
			{ label = "Square (left)", command = "/window Square left -12" },
			{ label = "Wide (left)", command = "/window Wide left 4" },
			{ label = "Arched (right)", command = "/window Arched right -12" },
			{ label = "Porthole (right)", command = "/window Porthole right 0" },
			{ label = "Stained (back)", command = "/window Stained back 0" },
		},
	},
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
		-- Weapons round 1 (Config/Weapons): weapons set exactly, boss materials, Wild Ore for the Forge weapons
		title = "Weapons",
		buttons = {
			{ label = "Give a weapon", command = "/weapon %s", placeholder = "id [grade] [level] (verdantBlade S 4)" },
			{ label = "Prism Blade +10 S", command = "/weapon prismBlade S 10" },
			{ label = "Boss material", command = "/material %s", placeholder = "boss id amount (meadowWarden 20)" },
			{ label = "+50 Wild Ore", command = "/item wildOre 50" },
			{ label = "Boss weapon drop", command = "/weapondrop %s", placeholder = "boss id (meadowWarden, prismHydra)" },
			{ label = "Drop cinematic (preview)", command = "/weapondrop %s preview", placeholder = "boss id (meadowWarden, prismHydra)" },
			{ label = "Boss chests", command = "/chests %s", placeholder = "boss id [drop|miss|strong|tired] (meadowWarden drop)" },
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
		-- The round 1 swords' effects (spec 2026-11-06-sword-skills-design 7): your character casts the sword's finisher or
		-- skill at a dummy in front of you (MovePreviewController), coloured and scaled like that weapon at that level
		title = "Sword skills",
		buttons = {
			{ label = "Sunforged finisher", command = "/skillfx sunforged cut3" },
			{ label = "Sunfall Cleave", command = "/skillfx sunforged skill" },
			{ label = "Verdant finisher", command = "/skillfx verdant cut3" },
			{ label = "Thornline", command = "/skillfx verdant skill" },
			{ label = "Prism finisher", command = "/skillfx prism cut3" },
			{ label = "Prism Judgment", command = "/skillfx prism skill" },
			{ label = "Forge finisher", command = "/skillfx forge cut3" },
			{ label = "Elemental Spin", command = "/skillfx forge skill" },
			{ label = "Spear thrust", command = "/skillfx spear cut1" },
			{ label = "Spear sweep", command = "/skillfx spear cut2" },
			{ label = "Sky Pierce", command = "/skillfx halberd cut3" },
			{ label = "Piercing Rush", command = "/skillfx spear skill" },
			{ label = "Magma Cleave", command = "/skillfx halberd skill" },
			{ label = "Torrent Strike", command = "/skillfx trident skill" },
			{ label = "Titan's Wrath", command = "/skillfx lance skill" },
			-- the scythes (weapons round 3)
			{ label = "Reap", command = "/skillfx scythe cut1" },
			{ label = "Back Sweep", command = "/skillfx scythe cut2" },
			{ label = "Whirlwind", command = "/skillfx scythe cut3" },
			{ label = "Reaping Cyclone", command = "/skillfx scythe skill" },
			{ label = "Thousand Cuts", command = "/skillfx rift skill" },
			{ label = "Any sword move", command = "/skillfx %s", placeholder = "sword [cut1|cut2|cut3|skill] [level] (tide skill 10)" },
		},
	},
	{
		title = "Fights and places",
		buttons = {
			{ label = "Wake resting cards", command = "/rest" },
			{ label = "Tire the party (keep summoned)", command = "/tire" },
			{ label = "Elite next to me", command = "/elite" },
			{ label = "Knock me out (in the Wild)", command = "/knockout" },
			{ label = "Supporter tier 1 (as if bought)", command = "/support 1" },
			{ label = "Supporter tier 3 (as if bought)", command = "/support 3" },
			{ label = "Not a supporter again", command = "/support 0" },
			{ label = "Titles: unlock again (new card, dot)", command = "/titles forget" },
			{ label = "Review: happy customer", command = "/review happyMoment" },
			{ label = "Review: empty shelves", command = "/review noStock" },
			{ label = "Go to the Wild", command = "/wild" },
			{ label = "Go to the arena", command = "/arena" },
			{ label = "Toggle Extra Job Slot", command = "/jobslot" },
			{ label = "2x Luck 1 min (as if bought)", command = "/luck x2 1" },
			{ label = "3x Super Luck 1 min (as if bought)", command = "/luck x3 1" },
			{ label = "Clear bought luck", command = "/luck clear" },
			{ label = "Workers tired / rested", command = "/jobtired" },
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
			{ label = "Victory sound 1: Victory Fanfare (now)", command = "/victorysound 1" },
			{ label = "Victory sound 2: Arc Of Triumph", command = "/victorysound 2" },
			{ label = "Victory sound 3: Light Fun Orchestral", command = "/victorysound 3" },
			{ label = "Sword popup again", command = "/swordpopup" },
			{ label = "Button names again (3 fights)", command = "/buttonnames" },
		},
	},
	{
		-- The tutorial with Pish (spec 2026-11-09-tutorial-pish-design): the first visit, his lesson visits, Town Pish
		title = "Pish (tutorial)",
		buttons = {
			{ label = "First visit again (a new player's)", command = "/tutorial reset" },
			{ label = "Jump to a step", command = "/tutorial step %s", placeholder = "step 1-8" },
			{ label = "Lesson: Glass Showcase (Lv 2)", command = "/tutorial lesson showcase" },
			{ label = "Lesson: Decor (Lv 2)", command = "/tutorial lesson decor" },
			{ label = "Lesson: Card Sleeves (Lv 3)", command = "/tutorial lesson sleeves" },
			{ label = "Lesson: Collector Case (Lv 3)", command = "/tutorial lesson collectorCase" },
			{ label = "Lesson: first sword (Lv 4)", command = "/tutorial lesson sword" },
			{ label = "Lesson: Wall Shelf (Lv 4)", command = "/tutorial lesson wallShelf" },
			{ label = "Lesson: Card Condenser (Lv 5)", command = "/tutorial lesson condenser" },
			{ label = "Lesson: Forge (Lv 6)", command = "/tutorial lesson forge" },
			{ label = "Lesson: Deck Boxes (Lv 7)", command = "/tutorial lesson expand" },
			{ label = "Lesson: Accessory Hook (Lv 7)", command = "/tutorial lesson accessoryHook" },
			{ label = "Lesson: Big Display Rack (Lv 9)", command = "/tutorial lesson bigRack" },
			{ label = "Lesson: Booster Boxes (Lv 11)", command = "/tutorial lesson boosterBox" },
			{ label = "Lesson: Grading Station (Lv 14)", command = "/tutorial lesson grading" },
			{ label = "Lesson: Shop jobs (Lv 20)", command = "/tutorial lesson jobs" },
			{ label = "Lesson: first trophy", command = "/tutorial lesson trophy" },
			{ label = "Lesson: first title", command = "/tutorial lesson titles" },
			{ label = "Town Pish to me", command = "/pish" },
			{ label = "Petting gives luck again now", command = "/pishluck" },
		},
	},
	{
		-- Turts' rug shop (spec 2026-11-13-turts-shop-design)
		title = "Turts' rug shop",
		buttons = {
			{ label = "New roll for me now", command = "/turts restock" },
			{ label = "Turts moves now", command = "/turts move" },
			{ label = "Legendary Pack in my stock", command = "/turts offer legendaryPack" },
			{ label = "Boss material in my stock", command = "/turts offer material_meadowWarden" },
			{ label = "Gold Seal in my stock", command = "/turts offer goldSeal" },
		},
	},
	{
		-- Chikin's combat tutorial (spec 2026-11-10-chikin-combat-tutorial-design): after Pish's, and at shop level 4
		title = "Chikin (combat tutorial)",
		buttons = {
			{ label = "His tour again (a new player's)", command = "/chikin reset" },
			{ label = "Jump to a step", command = "/chikin step %s", placeholder = "step 1-11" },
		},
	},
	{
		title = "Dungeon (Dungeon window)",
		buttons = {
			{ label = "To room 2", command = "/room 2" },
			{ label = "To room 3", command = "/room 3" },
			{ label = "To the Hydra", command = "/room 4" },
			{ label = "Win this room", command = "/winroom" },
			{ label = "To the beams", command = "/puzzle beams" },
			{ label = "To the plates", command = "/puzzle plates" },
			{ label = "To the lock", command = "/puzzle lock" },
			{ label = "Solve puzzle", command = "/puzzle solve" },
			{ label = "Hydra's welcome", command = "/dungeonfx intro" },
			{ label = "Short welcome", command = "/dungeonfx introshort" },
			{ label = "Distant roar", command = "/dungeonfx roar" },
			{ label = "Eyes in the dark", command = "/dungeonfx glimpse" },
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
