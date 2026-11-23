--!strict
-- Deliveries (owner 2026-11-23: "how can we make this deliveries system more immersive/better", mockups A, 1 and 3:
-- "go A with 1 and 3"; DESIGN.md 4.2 "The packenship.co van"). The supplier's van brings every order down the street,
-- stops by the shop's delivery pad and the boxes hop out onto it; stocking a shelf unboxes the box onto it pack by
-- pack; the shop's door bell rings when a delivery lands and a chip over the pad counts the boxes waiting. Read by
-- StockService (the hop times) and DeliveryController; plain data (tests/DeliveryRules). Studs and seconds; colours
-- { r, g, b }.
return {
	-- The trip: firstHop s after the van stops the first box leaves its door, hopGap s apart, each hopTime s in the
	-- air (owner 2026-11-23: "make the boxes animation from the van to the delivery pad faster"; was 0.55 / 0.3 /
	-- 0.5); it drives off linger s after the last one lands. speed studs a second, slowing into the stop and speeding
	-- away over brake s
	TRIP = { firstHop = 0.35, hopGap = 0.16, hopTime = 0.3, linger = 0.9, speed = 30, brake = 1.1 },
	-- Where it drives: along each shop row's curb (Util/DeliveryRules.laneOffset) from the street's end behind it to the
	-- end ahead (Town.LAYOUT.STREET_HALF_LENGTH less endInset), fading in and out over `fade` studs there. It keeps to
	-- the right, so its sliding door faces the pad
	STREET = { endInset = 4, fade = 10 },
	-- The van: the Blender model (tools/blender/build_delivery_van.py) once it's saved as assets/props/DeliveryVan.rbxm,
	-- else code-built from these (Util/DeliveryVan); the model's lamps glow in light / tail
	VAN = {
		length = 11,
		width = 5.5,
		height = 6.2, -- the parcel on its roof over the street (the model's)
		curb = 0.6, -- its side this far off the curb
		wheel = 2, -- a wheel's diameter
		body = { 255, 255, 255 },
		skirt = { 220, 203, 255 }, -- lilac along its bottom
		stripe = { 63, 214, 160 }, -- the mint band with the supplier's name
		glass = { 180, 224, 255 },
		tyre = { 43, 34, 56 },
		hub = { 156, 143, 176 },
		door = { 58, 42, 74 },
		light = { 255, 244, 214 },
		tail = { 255, 110, 120 },
		name = "packenship.co", -- the order computer's supplier (Config/OrderComputer)
		doorHeight = 2.6, -- a box leaves the door this high over the street
		doorOpen = 0.35, -- s the sliding door takes
	},
	-- A box's hop from the van's door to its place on the pad: an arc `peak` studs over the higher end (about
	-- Roblox gravity's for a hopTime flight), `spins` whole turns, and a puff of dust where it lands (`puff` s)
	HOP = { peak = 2.2, spins = 1, puff = 0.45, recent = 1.5 }, -- recent: only a box made this many s ago hops in
	-- Unboxing onto a shelf (Util/UnboxFx): the carried box opens in your hands (`open` s) and up to `items` packs hop
	-- onto the shelf `gap` s apart, `flight` s each, an arc `peak` studs over the higher end, each pop `pitchStep`
	-- higher, the count rolling up over the shelf; played for players within `reach` studs
	UNBOX = { items = 6, gap = 0.09, flight = 0.32, peak = 2.4, pitchStep = 0.08, open = 0.14, reach = 80 },
	-- The chip over your own pad while boxes wait on it: `up` studs over the pad, `height` px, seen from `maxDistance`
	CHIP = { up = 5.2, height = 40, maxDistance = 120 },
	-- Licensed sounds (Pro Sound Effects), each at its own volume
	SOUNDS = {
		arrive = { id = "rbxassetid://9114239952", volume = 0.3 }, -- Electric Car Pass By Airy Whirring 12: rolling in
		leave = { id = "rbxassetid://9114240386", volume = 0.3 }, -- the same whirr, shorter: driving off
		horn = { id = "rbxassetid://9113013987", volume = 0.35, pitch = 1.15 }, -- an SUV honk, played twice: beep beep
		door = { id = "rbxassetid://9120364893", volume = 0.4 }, -- Van Door Fumbly Hits 1: the sliding door
		thud = { id = "rbxassetid://9113720176", volume = 0.45 }, -- Cardboard Box 10: a box set down on the pad
		bell = { id = "rbxassetid://9119642861", volume = 0.5, stopAfter = 2.4 }, -- Store Entry Bell 4: the shop's door
		flap = { id = "rbxassetid://9113562807", volume = 0.4 }, -- Box Grab Department Store 10: the box opening
		pop = { id = "rbxassetid://9117841516", volume = 0.3 }, -- Pop Airy 2: each pack landing on the shelf
	},
}
