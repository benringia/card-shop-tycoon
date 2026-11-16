--!strict
-- Grown-up customers (owner 2026-11-16: "improve customer's look. add some adult"; picked look B): Roblox's own "Man"
-- and "Woman" bodies with their animated faces, dressed from Roblox's free catalog; kids the same way ("update the kids
-- to be the same style as the adults"): Roblox's Boy and Girl bodies with an animated head
local CustomerLook = require("../src/shared/Util/CustomerLook")
local Customers = require("../src/shared/Config/Customers")
local expect = require("./lib/expect")

local LOOK = Customers.ADULT_LOOK
local KIDS = Customers.KID_LOOK

-- A fixed list of rolls, so every pick is the same each run
local function rolls(values: { number }): () -> number
	local index = 0
	return function(): number
		index = index % #values + 1
		return values[index]
	end
end

local function isId(value: unknown): boolean
	return typeof(value) == "number" and value > 0 and value == math.floor(value)
end

return {
	["kids: a Boy or Girl body, an animated head, kid clothes and hair made for that body"] = function()
		local bodies = {}
		for step = 0, 19 do
			local look = CustomerLook.pick(Customers, "kid", rolls({ step / 20 }))
			assert(look and look.kid, "a kid look")
			bodies[look.body] = true
			assert(KIDS.bodies[look.body], "a kid body")
			assert(look.head and KIDS.heads[look.head], "one of the animated heads")
			assert(table.find(KIDS.hair[look.body], look.hair), "hair made for that body")
			assert(table.find(KIDS.outfits.shirts, look.shirt) and table.find(KIDS.outfits.pants, look.pants), "kid clothes")
		end
		expect.equal(bodies.boy, true)
		expect.equal(bodies.girl, true)
		for name, body in KIDS.bodies do
			for _, part in { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
				assert(isId((body :: any)[part]), `{name}.{part}`)
			end
		end
		for index, head in KIDS.heads do
			assert(isId(head.Head) and isId(head.MoodAnimation), `head {index}`)
		end
		local grownUp = CustomerLook.pick(Customers, "plain", rolls({ 0.5 }))
		expect.equal(grownUp and grownUp.kid, false, "grown-ups aren't kids")
	end,

	["every other type is a grown-up: a body, its own hair, a shirt and pants, a skin colour"] = function()
		for _, kind in { "plain", "collector", "bargain", "bigSpender" } do
			for _, roll in { 0, 0.25, 0.5, 0.75, 0.999 } do
				local look = CustomerLook.pick(Customers, kind, rolls({ roll }))
				assert(look, `{kind} at {roll} is a grown-up`)
				local body = LOOK.bodies[look.body]
				assert(body, `{kind}: a known body`)
				assert(table.find(LOOK.hair[look.body], look.hair), `{kind}: hair made for that body`)
				local pool = LOOK.outfits[kind] or LOOK.outfits.plain
				assert(table.find(pool.shirts, look.shirt), `{kind}: a shirt from its own pool`)
				assert(table.find(pool.pants, look.pants), `{kind}: pants from its own pool`)
				assert(look.skin >= 1 and look.skin <= #Customers.SKIN_COLORS, `{kind}: a skin colour`)
			end
		end
	end,

	["both bodies come up"] = function()
		local seen = {}
		for step = 0, 19 do
			local look = CustomerLook.pick(Customers, "plain", rolls({ step / 20 }))
			if look then
				seen[look.body] = true
			end
		end
		expect.equal(seen.man, true)
		expect.equal(seen.woman, true)
	end,

	["each type keeps its colours: collectors purple, bargain hunters casual, big spenders dark"] = function()
		for kind, pool in LOOK.outfits do
			assert(#pool.shirts >= 3 and #pool.pants >= 2, `{kind} has a few outfits to mix`)
		end
		-- the plain shoppers wear everything the others do, and more
		for _, kind in { "collector", "bargain", "bigSpender" } do
			for _, shirt in LOOK.outfits[kind].shirts do
				assert(table.find(LOOK.outfits.plain.shirts, shirt), `plain shoppers also wear {kind}'s shirt {shirt}`)
			end
		end
	end,

	["every id is a whole asset id; every body has every part and an animated face"] = function()
		for name, body in LOOK.bodies do
			for _, part in { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Head", "MoodAnimation" } do
				assert(isId((body :: any)[part]), `{name}.{part}`)
			end
		end
		for name, list in LOOK.hair do
			assert(#list >= 5, `{name}: a few hair styles`)
			for _, id in list do
				assert(isId(id), `{name} hair {id}`)
			end
		end
		for kind, pool in LOOK.outfits do
			for _, id in pool.shirts do
				assert(isId(id), `{kind} shirt`)
			end
			for _, id in pool.pants do
				assert(isId(id), `{kind} pants`)
			end
		end
	end,

	-- Catalog items whose texture Roblox has deleted: they load as a bare grey mesh and print "Request asset was not
	-- found" (Brown Hair 62234425: its texture 81504106 gone, seen in Studio 2026-11-16)
	["no hair whose texture is gone"] = function()
		local GONE = { 62234425 }
		for _, looks in { LOOK.hair, KIDS.hair } do
			for name, list in looks do
				for _, id in GONE do
					expect.equal(table.find(list, id), nil, `{name} hair {id}`)
				end
			end
		end
	end,
}
