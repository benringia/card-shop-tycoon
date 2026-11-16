--!strict
-- A customer's look (owner 2026-11-16, look B: Config/Customers ADULT_LOOK, KID_LOOK): a body, hair made for it, a
-- shirt and pants (a grown-up's from its type's own pool), a skin colour, and for a kid one of the animated heads.
-- Pure: the server turns it into a HumanoidDescription (CustomerService)
local CustomerLook = {}

export type Look = { kid: boolean, body: string, head: number?, hair: number, shirt: number, pants: number, skin: number }

local BODIES = { "man", "woman" }
local KID_BODIES = { "boy", "girl" }

local function index(count: number, roll: number): number
	return math.clamp(math.floor(roll * count) + 1, 1, count)
end

function CustomerLook.pick(config: any, kind: string, random: () -> number): Look?
	if kind == "kid" then
		local kids = config.KID_LOOK
		if not kids then
			return nil
		end
		local body = KID_BODIES[index(#KID_BODIES, random())]
		local hair = kids.hair[body]
		return {
			kid = true,
			body = body,
			head = index(#kids.heads, random()),
			hair = hair[index(#hair, random())],
			shirt = kids.outfits.shirts[index(#kids.outfits.shirts, random())],
			pants = kids.outfits.pants[index(#kids.outfits.pants, random())],
			skin = index(#config.SKIN_COLORS, random()),
		}
	end
	local look = config.ADULT_LOOK
	if not look then
		return nil
	end
	local body = BODIES[index(#BODIES, random())]
	local hair = look.hair[body]
	local pool = look.outfits[kind] or look.outfits.plain
	return {
		kid = false,
		body = body,
		hair = hair[index(#hair, random())],
		shirt = pool.shirts[index(#pool.shirts, random())],
		pants = pool.pants[index(#pool.pants, random())],
		skin = index(#config.SKIN_COLORS, random()),
	}
end

return CustomerLook
