--!strict
-- Every RemoteEvent the game uses, defined in one place.
-- The server creates them on first require; clients wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"OpenOrderMenu", -- server → client: owner used their order computer
	"OrderProduct", -- client → server: (productId: string)
	"Notify", -- server → client: (message: string, isError: boolean, style: "side"?) side = small toast at the left (sales)
	"PlaceShelf", -- client → server: (shelfId: string, gridX: number, gridZ: number, rotation: number)
	"MoveShelf", -- client → server: (uid: string, gridX: number, gridZ: number, rotation: number)
	"MoveFixture", -- client → server: (fixtureId: string, gridX: number, gridZ: number, rotation: number)
	"SellShelf", -- client → server: (uid: string)
	"StockShelf", -- client → server: (uid: string) put the carried box's units on this shelf
	"FillBulkBin", -- client → server: (uid: string) put the binder's extra Commons in this Bulk Bin (BulkService)
	"SetPrices", -- client → server: ({ [productId: string]: number })
	"CheckoutUpdate", -- server → client: (total: number?, remaining: number, lines: { { name, price, done, product?, card? } }?) nil total = checkout over
	"RegisterBell", -- server → client: (ring: number) a customer waits at your register with nobody there (Config/RegisterBell)
	"UpgradeJobs", -- server → client: { [station] = { kind, left, total, name, detail } } the stations' jobs (UpgradeJobService)
	"SkipUpgrade", -- client → server: (station: string) the job "Finish now" is about to buy for (UpgradeJobService)
	"Knockout", -- server → client: { left: number, paused: boolean } knocked out in the Wild, or nil when it's over (KnockoutService)
	"KnockoutChoice", -- client → server: ("spring" | "revive") wake at the spring now, or open the Revive purchase
	"SupportState", -- server → client: { gifts: number, best: number } "Support the dev" (SupportService); client → server: () ask for it
	"SupportThanks", -- server → client: { tier: number, raised: boolean } a gift just given: the dogs' thank-you (ThanksController); client → server: () its glow ended, show the aura
	"TitleUnlocked", -- server → client: (titleId: string) a title earned for the first time: the "New title!" card (CharacterController)
	"TitlesSeen", -- client → server: () the Titles tab was seen: no title is new any more (TitleService)
	"Reviews", -- server → client: { posts } the feed, or { post } a new one (ReviewService); client → server: () ask for the feed
	"TurtsStock", -- server → client: (index: number, offers: { string }, bought: { string }, endsAt: number) your offers on Turts' rug; client → server: () ask again
	"BinderShown", -- client → server: (shown: boolean) your binder opened or closed: you're posed reading it (BinderReadService)
	"TurtsBuy", -- client → server: (offerId: string, seen: number) buy one of your offers from Turts; seen: the restock your window showed (TurtsService)
	"TurtsRestockNow", -- client → server: () open the Robux "restock now" purchase
	"ShopLook", -- client → server: (action: "buy" | "use", lookId: string) buy or switch your shop's look from the Decor tab (DecorService)
	"PlaceWindow", -- client → server: (style: string, side: string, at: number) buy a window into your shop's wall (WindowService)
	"MoveWindow", -- client → server: (index: number, side: string, at: number) move one of your windows
	"SellWindow", -- client → server: (index: number) sell one of your windows (half its price back)
	"BuyLuck", -- client → server: (product: string) open the Robux purchase of a Config/Luck product from the Store (LuckService)
	"BuyUnlock", -- client → server: (key: string) open the Robux purchase of a one-time unlock (Monetization UNLOCKS; MonetizationService)
	"PrologueSeen", -- client → server: () the prologue is over (finished or skipped): saved as seen (WelcomeService)
	"PrologueReplay", -- server → client: () Studio's /prologue: play it now (PrologueController)
	"PrologueStep", -- client → server: (step: "begin" | "fight" | "vanish" | "take") the prologue's next part (PrologueService)
	"PrologueArena", -- server → client: (centre: Vector3?) this player's lair, its loadout lent; nil: no prologue now
	"RedeemCode", -- client → server: (typed: string) the Store's code box: try this code (CodeService; rate-limited)
	"CodeResult", -- server → client: (ok: boolean, message: string) the answer for the code just sent (Util/CodeBox)
	"StoreWin", -- server → client: (kind: "x2" | "x3" | "jobslot", seconds: number) a Store purchase went through: its win card (StoreWinController)
	"GiftState", -- server → client: (view: GiftRules.View, counting: boolean) the daily, weekly and monthly gifts; client → server: () send it again (GiftService)
	"GiftClaim", -- client → server: (kind: "daily" | "weekly" | "monthly") claim it; server → client: (kind, day: number, lines: { GiftRules.Line }) its win moment (GiftController)
	"QuestState", -- server → client: (view: QuestRules.View?, done: number?) today's quests (nil before Pish's tour ends), a quest just finished; client → server: () send it again (QuestService)
	"QuestClaim", -- client → server: (which: number | "bonus") claim a done quest or the bonus chest; server → client: (which, cash: number, xp: number, items: { { item, count } }) its reward moment (QuestController)
	"MainQuestDone", -- server → client: (shelfId: string, xp: number) a main quest item's first build paid its shop XP: its moment on the strip (MainQuestService, QuestController)
	"WelcomeBack", -- server → client: (summary: { minutes, units, cash, xp, sold: { [productId]: number }, empty: boolean }) what the shop sold while you were away; client → server: () ready to show it (OfflineService)
	"TeamInvite", -- client → server: (userId: number) invite that player to your team; server → client: (fromUserId: number, members: { number }, seconds: number) an invite card (TeamService)
	"TeamAnswer", -- client → server: (fromUserId: number, join: boolean) answer an invite
	"TeamState", -- server → client: (team: { leader: number, members: { number } }?) your team now (nil: none); client → server: () leave your team
	"TeamFight", -- server → client: (bossId: string, fromUserId: number, joined: { number }, seconds: number) a teammate's boss fight is forming; client → server: (bossId: string) join it
	"Charge", -- client → server: take payment for the fully scanned checkout
	-- server → owner: the payment step after Charge (Config/Payment), nil = closed: { method: "card" | "cash", total: cents,
	-- given: cents (cash: what they handed over), items: string }
	"PaymentStart",
	"PayAnswer", -- client → server: (answer: number | { number }) card: the typed total in cents; cash: the bills and coins given, in cents
	"PaymentResult", -- server → owner: (result: "wrong" | "short" | "over") a wrong answer: the screen says why
	"ManRegister", -- client → server: (on: boolean) step onto your register in first person, or off it (RegisterStationController)
	-- server → owner: the open kid offer or haggle at the register, nil = closed. { id, kind: "kid"|"haggle",
	-- card: { cardId, foil, grade }?, asking?, worth?, offer?, total?, range: { low, high }, step, edges: { sure, maybe },
	-- triesLeft }
	"OfferUpdate",
	"OfferAction", -- client → server: (id: number, action: "accept"|"counter"|"decline", price: number?)
	-- server → owner: { rating: number, parts: { { name, score, weight, known } } } (RatingService, heaviest part first;
	-- known false: scored neutral for want of anything to score, so no tip)
	"RatingUpdate",
	"DropBox", -- client → server: put carried boxes back on the delivery pad
	"BagBox", -- client → server: the packs in your carried boxes go in your Bag (To Bag)
	"RemoveStock", -- client → server: (shelfUid: string) box up a product shelf's stock onto the delivery pad
	"RipPack", -- client → server: open one pack from the carried box
	"PackOpened", -- server → client: (productId: string, results: { { cardId, foil, grade } }, newFlags: { boolean }, itemId: string?) itemId: the Bag item it came from (Open another)
	"CollectionChanged", -- server → client: ({ [cardId: string]: { normal: number, foil: number } })
	"RequestCollection", -- client → server: ask for a CollectionChanged (sent on client start)
	"DisplayCard", -- client → server: (shelfUid: string, slot: number, cardId: string, foil: boolean, beastId: string?, grade: string?) binder → case; plain copies picked by grade
	"RemoveDisplayedCard", -- client → server: (shelfUid: string, slot: number) case → binder
	"SetCardPrice", -- client → server: (shelfUid: string, changes: { { slot: number, price: number } })
	"ReleaseListings", -- client → server: (shelfUid: string, slot: number?) Done on a new card, or its case's window closed: on sale now
	"BuyDisplayedCard", -- client → server: (ownerUserId, shelfUid, slot, cardId, foil, expectedPrice, expectedBeastId?, expectedGrade?) from a Collector Case
	"PullAnnouncement", -- server → clients: (displayName: string, cardId: string, foil: boolean, kind: "frontier"?, finderUserId?) big pulls and Frontier finds
	"PullRevealed", -- client → server: (cardId: string, foil: boolean) puller flipped a big pull; announce it
	"Condense", -- client → server: (shelfUid, cardId, mainBeastId?, mainFoil?, mainGrade?) +1 star from duplicates
	"CondenserSeen", -- client → server: () the finished star was taken out in the Condenser's window (clears CondenserDone)
	"GradingSeen", -- client → server: () the finished grade was taken out in the Grading Station's window (clears GradingDone)
	"GradeUp", -- client → server: (shelfUid, cardId, mainBeastId?, mainFoil?, mainGrade?, useSeals, useGold) +1 grade from duplicates (and Grading Seals) and cash (or a Gold Seal)
	"AssignJob", -- client → server: (target: beastId | { cardId, foil, grade }, job: string) card starts a shop job
	"UnassignJob", -- client → server: (slot: number)
	"SwitchJob", -- client → server: (slot: number) that slot's worker takes the next job (Restocker <-> Cashier)
	"JobsChanged", -- server → owner: { slotCount, maxSlots, unlockLevel, hasPass, passId, slots = { { slot, beastId, job, status } } }
	"RequestJobs", -- client → server: () resend JobsChanged
	"SetPartySlot", -- client → server: (slot: number, target: beastId | { cardId, foil, grade } | nil) nil removes
	"Summon", -- client → server: (slot: number?) nil unsummons
	"PartyChanged", -- server → owner: { slots = { { slot, beastId } }, summoned: number?, perk = { kind, value, text }? }
	"RequestParty", -- client → server: () resend PartyChanged
	"WildTravel", -- client → server: (where: "wild" | "home"); server → client: (where) after moving you, "loading" as a trip to the Wild starts, "stay" if it doesn't happen
	"StartFight", -- client → server: (monsterId: string)
	"CallIn", -- client → server: (beastId: string) second party card joins, first seconds only
	"UseAbility", -- client → server: (fighterId: string, which: "element" | "signature")
	"RunFight", -- client → server: ()
	"BattleStarted", -- server → client: { monsterId, species, level, elite, element, names = { [beastId] = name }, snapshot }
	"BattleEvent", -- server → client: { events = { Event }, snapshot } (BattleSim)
	"ArenaWatch", -- server → client: a PvP fight for players watching from the stands: { events, markers? } or { ended = true }
	"BattleEnded", -- server → client: { result, rested = { beastId }, xpEach?, cash?, card? = { cardId, foil, grade }, partyIds? }
	"RestChanged", -- server → client: { entries = { { beastId, seconds } }, nearSpring: boolean }
	"Challenge", -- client → server: (targetUserId: number, bet: number) PvP challenge
	"ChallengeRespond", -- client → server: (accept: boolean)
	"ChallengeCancel", -- client → server: () cancel your challenge or leave the arena queue
	"ChallengeIncoming", -- server → target: { fromUserId, fromName, bet, yourPower, theirPower, seconds }
	"ChallengeStatus", -- server → client: { state: sent|declined|expired|cancelled|queued|starting|refused, message?, position? }
	"ItemsChanged", -- server → owner: { [itemId] = count }
	"RequestItems", -- client → server: () resend ItemsChanged
	"BossesChanged", -- server → owner: { [bossId] = { unlocked, cleared, lootIn: seconds, bonusReady, fragments, weaponPity } }
	"RequestBosses", -- client → server: () resend BossesChanged
	"BossResetBuy", -- client → server: () open the Robux "reset all boss timers" purchase (Bosses.RESET)
	"BossCleared", -- server → clients: (displayName: string, bossId: string) someone beat a boss for the first time
	"BossLoot", -- server → owner: { drops = { { id, item, count, x, y, z } }, from = { x, y, z } } or { taken = id }
	"PickUpLoot", -- client → server: (ids: { string }) pick up your boss drops close by (up to Bosses.LOOT_PICKUP_BATCH)
	"BossTravel", -- client → server: (index: number) the board's Take me there: to boss n's gate when its arena is in this place
	"DevPanel", -- client → server: (command: string) a dev chat command from the admin panel; handled in Studio only
	"DungeonRun", -- server → client: { room, rooms, stage = "waiting" | "room" | "gather" | "beams" | "plates" | "lock" | "boss" | "won" | "out", next?, here?, total? (gather: the next puzzle, players on its island / still in the run), message?, intro? = "full" | "short" (play the Hydra's welcome; sent until the client acks) } the Dungeon run; client → server: () ask for it, or ("introSeen") the welcome started
	"DungeonLeave", -- client → server: () leave the Dungeon run (back to the Frontier)
	"Titles", -- server → client: { earned = { titleId }, equipped = titleId ("" automatic) }; client → server: () ask (TitleService)
	"EquipTitle", -- client → server: (titleId: string) show that earned title over your name ("" = automatic; TitleService)
	"Blocked", -- server → client: { reason, title?, icon?, shove: Vector3?, tone: "info"?, seconds? } you can't do that yet (tone "info": an answer, the healing spring's): a big locked card with what's needed (Util/Blocked, BlockedController); a knockout's card; a dangerous monster's shove for your client to apply
	"DungeonCinematic", -- server → client: { kind = "door" | "hydra", door: Vector3, through: Vector3, sockets?: { Vector3 } } a puzzle's gate opening, or the way to the Hydra (DungeonCinematicController)
	"DungeonChest", -- server → client: { key, kind = "puzzle" | "secret", cash?, xp?, item?, count?, title? } you opened that Dungeon chest
	"UseXpTonic", -- client → server: (beastId: string) one XP Tonic on a party card
	"OpenBagPack", -- client → server: (itemId: string) open one pack item from the Bag (LevelUpService; main game)
	"OpenBagPacks", -- client → server: (itemId: string, count: number) Open 10: up to Levels.OPEN_MANY packs of a Bag stack at once (LevelUpService)
	"PacksOpened", -- server → client: (productId, results: { { cardId, foil, grade } }, newFlags: { boolean }, itemId: string, packs: number) Open 10's cards, pack by pack (BulkOpenController)
	"LevelUpFx", -- server → clients: { kind = "shop", userId, from, to } or { kind = "creature", userId, beastId, element, from, to, fromFight }
	"MovePreview", -- server → one client, Studio only: { move = "rain" | "vine" | "orbs" | "curse", grade = "C" | "B" | "A" | "S", big } (DevService /movefx), or { super = <Config/SuperFx look id>, grade } (/superfx)
	"FrontierTravel", -- client → server: (where: "explore" | "friend" | "home", friendUserId?); server → client: { open = true } (portal menu) or { message }
	"WelcomeSeen", -- client → server: () the welcome cinematic finished or was skipped
	"SwordState", -- server → client: { sword: string?, popup: boolean } your sword and whether to show the first-sword popup; client → server: () ask
	"SwordSeen", -- client → server: () the first-sword popup was closed
	"SwordAttack", -- client → server: () an Attack tap in a boss fight (the server picks the cut and checks reach)
	"SwordSkill", -- client → server: () the sword skill in a boss fight
	"SoftLock", -- client → server: (targetId: string?) the enemy you locked in a fight: your creature attacks it (nil: let go)
	"PetPylon", -- client → server: (pylonId: string | false) your creature attacks that Dungeon room 3 crystal pylon (its sim id), or comes back
	"SwordCast", -- server → all clients: (userId, move, x, z) a round 1 sword's cut ("cut1"-"cut3") or "skill" starts there: its effects for others
	"Dodge", -- client → server: () a dodge in a boss fight (the dash is the client's; the server makes you untouchable)
	"EquipWeapon", -- client → server: (weaponId: string) hold an owned weapon (WeaponService; not in a fight)
	"WeaponsChanged", -- server → client: { owned = { [weaponId]: { grade, level } }, equipped = weaponId }; client → server: () ask
	"ForgeWeapon", -- client → server: (shelfUid: string, weaponId: string) make a weapon at your Forge (ForgeService)
	"UpgradeWeapon", -- client → server: (shelfUid: string, weaponId: string) one more upgrade level on an owned weapon
	"ReforgeWeapon", -- client → server: (shelfUid: string, weaponId: string) a new grade roll on an owned weapon, the better kept
	"ForgeResult", -- server → client: { action = "forge" | "reforge" | "upgrade", weaponId, grade (rolled), level, kept, owned (its grade now) } (kept: the old grade stayed)
	"WeaponDropped", -- server → client: { weaponId, grade, refund, material } a boss dropped its weapon (refund > 0: you had it)
	"WeaponAnnouncement", -- server → all clients: (displayName, weaponId, grade, userId) an Epic or Legendary weapon dropped
	"WeaponBeacon", -- server → all clients: (userId, weaponId, position) a new boss weapon dropped there: its light column
	"BossChests", -- server → owner: { id, bossId, seconds } a boss win's three chests to pick from (no contents yet)
	"OpenBossChest", -- client → server: (id: string, index: number) the chest tapped (1-3)
	"BossChestOpened", -- server → owner: { id, index, contents = { { kind = "weapon"|"material"|"mystery", weaponId?, item?, count? } x3 } }
	"PishPetted", -- server → all clients: (userId, lucky: boolean) Town Pish was petted: his hearts, and the luck it gave
	"ChikinPetted", -- server → all clients: (userId, granted: boolean) Town Chikin was petted: his hearts, and the Courage it gave
	"TutorialAction", -- client → server: (action: "skip" | "replay" | "bye" | "lessonDone", lessonId: string?) the tutorial
	"CombatTutorialAction", -- client → server: (action: "next" | "skip" | "replay") Chikin's combat tutorial; gives nothing
	"TutorialState", -- server → client: { firstVisit, step, giftClaimed, lesson: string? } the tutorial's state, a lesson visit
}

local isServer = RunService:IsServer()
local folder: Instance
if isServer then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local remotes: { [string]: RemoteEvent } = {}
for _, name in NAMES do
	if isServer then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	else
		remotes[name] = folder:WaitForChild(name) :: RemoteEvent
	end
end

return {
	OpenOrderMenu = remotes.OpenOrderMenu,
	OrderProduct = remotes.OrderProduct,
	Notify = remotes.Notify,
	TurtsStock = remotes.TurtsStock,
	TurtsBuy = remotes.TurtsBuy,
	BinderShown = remotes.BinderShown,
	TurtsRestockNow = remotes.TurtsRestockNow,
	ShopLook = remotes.ShopLook,
	PlaceWindow = remotes.PlaceWindow,
	MoveWindow = remotes.MoveWindow,
	SellWindow = remotes.SellWindow,
	BuyLuck = remotes.BuyLuck,
	BuyUnlock = remotes.BuyUnlock,
	StoreWin = remotes.StoreWin,
	RedeemCode = remotes.RedeemCode,
	CodeResult = remotes.CodeResult,
	GiftState = remotes.GiftState,
	GiftClaim = remotes.GiftClaim,
	QuestState = remotes.QuestState,
	QuestClaim = remotes.QuestClaim,
	MainQuestDone = remotes.MainQuestDone,
	WelcomeBack = remotes.WelcomeBack,
	TeamInvite = remotes.TeamInvite,
	TeamAnswer = remotes.TeamAnswer,
	TeamState = remotes.TeamState,
	TeamFight = remotes.TeamFight,
	PrologueSeen = remotes.PrologueSeen,
	PrologueReplay = remotes.PrologueReplay,
	PrologueStep = remotes.PrologueStep,
	PrologueArena = remotes.PrologueArena,
	PlaceShelf = remotes.PlaceShelf,
	MoveShelf = remotes.MoveShelf,
	MoveFixture = remotes.MoveFixture,
	SellShelf = remotes.SellShelf,
	StockShelf = remotes.StockShelf,
	FillBulkBin = remotes.FillBulkBin,
	SetPrices = remotes.SetPrices,
	CheckoutUpdate = remotes.CheckoutUpdate,
	PaymentStart = remotes.PaymentStart,
	PayAnswer = remotes.PayAnswer,
	PaymentResult = remotes.PaymentResult,
	ManRegister = remotes.ManRegister,
	RegisterBell = remotes.RegisterBell,
	UpgradeJobs = remotes.UpgradeJobs,
	SkipUpgrade = remotes.SkipUpgrade,
	Knockout = remotes.Knockout,
	KnockoutChoice = remotes.KnockoutChoice,
	SupportState = remotes.SupportState,
	SupportThanks = remotes.SupportThanks,
	TitleUnlocked = remotes.TitleUnlocked,
	TitlesSeen = remotes.TitlesSeen,
	Reviews = remotes.Reviews,
	Charge = remotes.Charge,
	OfferUpdate = remotes.OfferUpdate,
	OfferAction = remotes.OfferAction,
	RatingUpdate = remotes.RatingUpdate,
	DropBox = remotes.DropBox,
	BagBox = remotes.BagBox,
	RemoveStock = remotes.RemoveStock,
	RipPack = remotes.RipPack,
	PackOpened = remotes.PackOpened,
	CollectionChanged = remotes.CollectionChanged,
	RequestCollection = remotes.RequestCollection,
	DisplayCard = remotes.DisplayCard,
	RemoveDisplayedCard = remotes.RemoveDisplayedCard,
	SetCardPrice = remotes.SetCardPrice,
	ReleaseListings = remotes.ReleaseListings,
	BuyDisplayedCard = remotes.BuyDisplayedCard,
	PullAnnouncement = remotes.PullAnnouncement,
	PullRevealed = remotes.PullRevealed,
	Condense = remotes.Condense,
	CondenserSeen = remotes.CondenserSeen,
	GradingSeen = remotes.GradingSeen,
	GradeUp = remotes.GradeUp,
	AssignJob = remotes.AssignJob,
	UnassignJob = remotes.UnassignJob,
	SwitchJob = remotes.SwitchJob,
	JobsChanged = remotes.JobsChanged,
	RequestJobs = remotes.RequestJobs,
	SetPartySlot = remotes.SetPartySlot,
	Summon = remotes.Summon,
	PartyChanged = remotes.PartyChanged,
	RequestParty = remotes.RequestParty,
	WildTravel = remotes.WildTravel,
	StartFight = remotes.StartFight,
	CallIn = remotes.CallIn,
	UseAbility = remotes.UseAbility,
	RunFight = remotes.RunFight,
	BattleStarted = remotes.BattleStarted,
	BattleEvent = remotes.BattleEvent,
	ArenaWatch = remotes.ArenaWatch,
	BattleEnded = remotes.BattleEnded,
	RestChanged = remotes.RestChanged,
	Challenge = remotes.Challenge,
	ChallengeRespond = remotes.ChallengeRespond,
	ChallengeCancel = remotes.ChallengeCancel,
	ChallengeIncoming = remotes.ChallengeIncoming,
	ChallengeStatus = remotes.ChallengeStatus,
	ItemsChanged = remotes.ItemsChanged,
	RequestItems = remotes.RequestItems,
	BossesChanged = remotes.BossesChanged,
	RequestBosses = remotes.RequestBosses,
	BossResetBuy = remotes.BossResetBuy,
	BossCleared = remotes.BossCleared,
	BossLoot = remotes.BossLoot,
	PickUpLoot = remotes.PickUpLoot,
	BossTravel = remotes.BossTravel,
	DevPanel = remotes.DevPanel,
	DungeonRun = remotes.DungeonRun,
	DungeonLeave = remotes.DungeonLeave,
	DungeonCinematic = remotes.DungeonCinematic,
	Blocked = remotes.Blocked,
	Titles = remotes.Titles,
	EquipTitle = remotes.EquipTitle,
	DungeonChest = remotes.DungeonChest,
	UseXpTonic = remotes.UseXpTonic,
	OpenBagPack = remotes.OpenBagPack,
	OpenBagPacks = remotes.OpenBagPacks,
	PacksOpened = remotes.PacksOpened,
	LevelUpFx = remotes.LevelUpFx,
	MovePreview = remotes.MovePreview,
	FrontierTravel = remotes.FrontierTravel,
	WelcomeSeen = remotes.WelcomeSeen,
	SwordState = remotes.SwordState,
	SwordSeen = remotes.SwordSeen,
	SwordAttack = remotes.SwordAttack,
	SoftLock = remotes.SoftLock,
	SwordSkill = remotes.SwordSkill,
	PetPylon = remotes.PetPylon,
	SwordCast = remotes.SwordCast,
	Dodge = remotes.Dodge,
	EquipWeapon = remotes.EquipWeapon,
	WeaponsChanged = remotes.WeaponsChanged,
	ForgeWeapon = remotes.ForgeWeapon,
	UpgradeWeapon = remotes.UpgradeWeapon,
	ReforgeWeapon = remotes.ReforgeWeapon,
	ForgeResult = remotes.ForgeResult,
	WeaponDropped = remotes.WeaponDropped,
	WeaponAnnouncement = remotes.WeaponAnnouncement,
	WeaponBeacon = remotes.WeaponBeacon,
	BossChests = remotes.BossChests,
	OpenBossChest = remotes.OpenBossChest,
	BossChestOpened = remotes.BossChestOpened,
	PishPetted = remotes.PishPetted,
	ChikinPetted = remotes.ChikinPetted,
	TutorialAction = remotes.TutorialAction,
	CombatTutorialAction = remotes.CombatTutorialAction,
	TutorialState = remotes.TutorialState,
}
