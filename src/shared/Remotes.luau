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
	"SetPrices", -- client → server: ({ [productId: string]: number })
	"CheckoutUpdate", -- server → client: (total: number?, remaining: number) nil total = checkout over
	"Charge", -- client → server: take payment for the fully scanned checkout
	"LevelUp", -- server → client: (level: number)
	"DropBox", -- client → server: put carried boxes back on the delivery pad
	"RemoveStock", -- client → server: (shelfUid: string) box up a product shelf's stock onto the delivery pad
	"RipPack", -- client → server: open one pack from the carried box
	"PackOpened", -- server → client: (productId: string, results: { { cardId: string, foil: boolean } })
	"CollectionChanged", -- server → client: ({ [cardId: string]: { normal: number, foil: number } })
	"RequestCollection", -- client → server: ask for a CollectionChanged (sent on client start)
	"DisplayCard", -- client → server: (shelfUid: string, slot: number, cardId: string, foil: boolean, beastId: string?, grade: string?) binder → case; plain copies picked by grade
	"RemoveDisplayedCard", -- client → server: (shelfUid: string, slot: number) case → binder
	"SetCardPrice", -- client → server: (shelfUid: string, changes: { { slot: number, price: number } })
	"BuyDisplayedCard", -- client → server: (ownerUserId, shelfUid, slot, cardId, foil, expectedPrice, expectedBeastId?, expectedGrade?) from a Collector Case
	"PullAnnouncement", -- server → other clients: (displayName: string, cardId: string, foil: boolean)
	"PullRevealed", -- client → server: (cardId: string, foil: boolean) puller flipped a big pull; announce it
	"Condense", -- client → server: (shelfUid, cardId, mainBeastId?, mainFoil?, mainGrade?) +1 star from duplicates
	"AssignJob", -- client → server: (target: beastId | { cardId, foil, grade }, job: string) card starts a shop job
	"UnassignJob", -- client → server: (slot: number)
	"JobsChanged", -- server → owner: { slotCount, maxSlots, unlockLevel, hasPass, passId, slots = { { slot, beastId, job, status } } }
	"RequestJobs", -- client → server: () resend JobsChanged
	"SetPartySlot", -- client → server: (slot: number, target: beastId | { cardId, foil, grade } | nil) nil removes
	"Summon", -- client → server: (slot: number?) nil unsummons
	"PartyChanged", -- server → owner: { slots = { { slot, beastId } }, summoned: number?, perk = { kind, value, text }? }
	"RequestParty", -- client → server: () resend PartyChanged
	"WildTravel", -- client → server: (where: "wild" | "home"); server → client: (where) after moving you
	"StartFight", -- client → server: (monsterId: string)
	"CallIn", -- client → server: (beastId: string) second party card joins, first seconds only
	"UseAbility", -- client → server: (fighterId: string, which: "element" | "signature")
	"RunFight", -- client → server: ()
	"BattleStarted", -- server → client: { monsterId, species, level, elite, element, names = { [beastId] = name }, snapshot }
	"BattleEvent", -- server → client: { events = { Event }, snapshot } (BattleSim)
	"BattleEnded", -- server → client: { result, rested = { beastId }, xpEach?, cash?, card? = { cardId, foil, grade }, partyIds? }
	"RestChanged", -- server → client: { entries = { { beastId, seconds } }, nearSpring: boolean }
	"Challenge", -- client → server: (targetUserId: number, bet: number) PvP challenge
	"ChallengeRespond", -- client → server: (accept: boolean)
	"ChallengeCancel", -- client → server: () cancel your challenge or leave the arena queue
	"ChallengeIncoming", -- server → target: { fromUserId, fromName, bet, yourPower, theirPower, seconds }
	"ChallengeStatus", -- server → client: { state: sent|declined|expired|cancelled|queued|starting|refused, message?, position? }
	"ItemsChanged", -- server → owner: { [itemId] = count }
	"RequestItems", -- client → server: () resend ItemsChanged
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
	PlaceShelf = remotes.PlaceShelf,
	MoveShelf = remotes.MoveShelf,
	MoveFixture = remotes.MoveFixture,
	SellShelf = remotes.SellShelf,
	StockShelf = remotes.StockShelf,
	SetPrices = remotes.SetPrices,
	CheckoutUpdate = remotes.CheckoutUpdate,
	Charge = remotes.Charge,
	LevelUp = remotes.LevelUp,
	DropBox = remotes.DropBox,
	RemoveStock = remotes.RemoveStock,
	RipPack = remotes.RipPack,
	PackOpened = remotes.PackOpened,
	CollectionChanged = remotes.CollectionChanged,
	RequestCollection = remotes.RequestCollection,
	DisplayCard = remotes.DisplayCard,
	RemoveDisplayedCard = remotes.RemoveDisplayedCard,
	SetCardPrice = remotes.SetCardPrice,
	BuyDisplayedCard = remotes.BuyDisplayedCard,
	PullAnnouncement = remotes.PullAnnouncement,
	PullRevealed = remotes.PullRevealed,
	Condense = remotes.Condense,
	AssignJob = remotes.AssignJob,
	UnassignJob = remotes.UnassignJob,
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
	BattleEnded = remotes.BattleEnded,
	RestChanged = remotes.RestChanged,
	Challenge = remotes.Challenge,
	ChallengeRespond = remotes.ChallengeRespond,
	ChallengeCancel = remotes.ChallengeCancel,
	ChallengeIncoming = remotes.ChallengeIncoming,
	ChallengeStatus = remotes.ChallengeStatus,
	ItemsChanged = remotes.ItemsChanged,
	RequestItems = remotes.RequestItems,
}
