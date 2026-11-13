--!strict
-- Turts' rug shop (spec 2026-11-13-turts-shop-design; owner: "a dog on the rug selling stuff. called Turts"): the
-- owner's dog sells 3 random offers from a rug that moves round the town every restock. Prices are "higher than
-- usual" (owner): each at least PREMIUM times its usual value, the cash it takes to earn it the normal way (a pack's
-- expected pack spend, a drop's farming time at about $700 an hour; Util/TurtsRules.priceOk, Lune-tested). Plain data.
-- TurtsService (server) and TurtsController (client); `weight`: how often it's picked (rarer = lower).
export type Offer = {
	name: string,
	item: string, -- the Config/Items id given
	count: number,
	price: number,
	value: number,
	weight: number,
	excited: boolean?, -- Turts spins when someone buys it
	glow: string?, -- a Config/Rarities tier: its icon glows in that colour on his rug and in his window (his packs)
}
export type Spot = { name: string, group: string, x: number, z: number, face: { x: number, z: number } }

local function material(boss: string, name: string): Offer
	return { name = name, item = `material_{boss}`, count = 1, price = 350, value = 150, weight = 1.5, excited = true }
end

local OFFERS: { [string]: Offer } = {
	vrPack = { name = "Very Rare Pack", item = "vrPack", count = 1, price = 25, value = 10, weight = 16, glow = "Very Rare" },
	epicPack = { name = "Epic Pack", item = "epicPack", count = 1, price = 75, value = 25, weight = 8, excited = true, glow = "Epic" },
	legendaryPack = { name = "Legendary Pack", item = "legendaryPack", count = 1, price = 600, value = 300, weight = 2.5, excited = true, glow = "Legendary" },
	wildOre10 = { name = "Wild Ore x10", item = "wildOre", count = 10, price = 400, value = 165, weight = 20 },
	xpTonic = { name = "XP Tonic", item = "xpTonic", count = 1, price = 120, value = 35, weight = 16 },
	starShard = { name = "Star Shard", item = "starShard", count = 1, price = 300, value = 90, weight = 10 },
	gradingSeal = { name = "Grading Seal", item = "gradingSeal", count = 1, price = 400, value = 150, weight = 8 },
	-- value: the most grading cash it can pay (an Epic's A to S step); the spec's $12,500 broke its own 1.5x rule
	goldSeal = { name = "Gold Seal", item = "goldSeal", count = 1, price = 15000, value = 10000, weight = 1.5 },
	-- each boss's weapon material, its own rare offer (owner: "you can add boss materials but at a low odds")
	material_meadowWarden = material("meadowWarden", "Warden Heartwood"),
	material_caveBroodQueen = material("caveBroodQueen", "Brood Silk"),
	material_emberColossus = material("emberColossus", "Colossus Core"),
	material_frostTyrant = material("frostTyrant", "Frost Heart"),
	material_stormSovereign = material("stormSovereign", "Storm Crystal"),
	material_riftDevourer = material("riftDevourer", "Rift Shard"),
	material_prismHydra = material("prismHydra", "Prism Scale"),
}

-- Where he sets up (owner: "spawn him randomly on the corner of the streets or the side of the plaza with his rug"):
-- the four street corners past the outer crosswalks and the plaza's four diagonal edges, clear of lanes, crosswalks,
-- doors, walker stops and plaza props (Lune-tested). -Z is north, +X east; `face`: the point his rug faces. The groups
-- take turns (TurtsRules.spotFor: corners on even restocks, plaza edges on odd), so he never stays put
local function corner(name: string, x: number, z: number): Spot
	return { name = name, group = "corner", x = x, z = z, face = { x = x, z = 0 } }
end
local function edge(name: string, degrees: number, r: number): Spot
	local a = math.rad(degrees)
	local x, z = math.cos(a) * r, math.sin(a) * r
	return { name = name, group = "edge", x = x, z = z, face = { x = x * 2, z = z * 2 } }
end

return {
	RESTOCK_SECONDS = 480, -- the owner's 8 minutes, on the same clock in every server
	PICKS = 3, -- offers per restock, each buyable once per player (owner: "only 1qty per item")
	PREMIUM = 1.5, -- every price at least this times its usual value
	PRODUCT = "TurtsRestock", -- Config/Monetization PRODUCTS: Robux "restock now" (a new roll for that player)
	BEACON_SECONDS = 30, -- a light over his rug after he moves
	RUG_RADIUS = 4, -- studs
	-- How high he stands: on his cushion's top (TurtsRug's cushion is 0.3-0.38 under his paws; on the street they went
	-- through it, owner 2026-11-13: "turts feet are through the rug")
	SEAT_HEIGHT = 0.32,
	PROMPT_RANGE = 10, -- studs: his "Shop" prompt; buying needs you this near (plus a little)
	SHAKE = { degrees = 7, hz = 3.2 }, -- his head's constant wobble (owner: "main animation will be the head shake")
	SIT_EVERY = { 20, 40 }, -- seconds between his sit-downs
	-- Drawn like Pish and Chikin (Util/PishVisual: NpcModels.Turts, his clips in MonsterAnimations.Turts): his height
	-- and Pish's licensed barks a little lower (a gruffer little dog)
	HEIGHT = 2.6, -- studs
	SOUNDS = {
		bark = "rbxassetid://9113955093",
		whimper = "rbxassetid://9113951583",
		yawn = "",
		yip = "rbxassetid://9113955748",
		dig = "",
	} :: { [string]: string },
	SOUND_PITCH = { bark = 1.3, whimper = 1.1, yip = 1.6 } :: { [string]: number },
	SOUND_VOLUME = 1,
	OFFERS = OFFERS,
	SPOTS = {
		corner("the north-west corner", -80, -32),
		corner("the north-east corner", 80, -32),
		corner("the south-west corner", -80, 32),
		corner("the south-east corner", 80, 32),
		edge("the plaza's south-east edge", 45, 31),
		edge("the plaza's south-west edge", 135, 31),
		edge("the plaza's north-west edge", 225, 31),
		edge("the plaza's north-east edge", 315, 31),
	} :: { Spot },
}
