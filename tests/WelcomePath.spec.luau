--!strict
-- The first-visit welcome cinematic (Portal Worlds spec): a 10-12 s flight past Forest Falls, Frostpeak, the plaza and
-- Ember Canyon to the player's own shop, as a time-lapse from morning to sunset that holds sunset for the last half.
local welcome = require("../src/shared/Config/Welcome")
local AttackFx = require("../src/shared/Config/AttackFx")
local WelcomePath = require("../src/shared/Util/WelcomePath")
local expect = require("./lib/expect")

local DOOR = { x = -64, y = 0, z = -48 }
local OUT = { x = 0, z = 1 }

return {
	-- The owner 2026-11-11: "the tutorial cinematic is a bit plain. can you make it more epic/jolly/welcoming, like a
	-- whoosh sound on the camera and stuff like that": whooshes on the fast stretches, a wider and banking camera, music,
	-- and confetti at your shop. Then 2026-11-16: "remove the world labels", and later the same day "on the intro.
	-- remove all texts and pish chikin. just the scenery is enough": no title, no cards, no dogs on screen
	["the flight is just the scenery: no title, no place cards, no dogs"] = function()
		local config = welcome :: any
		expect.equal(config.TITLE, nil, "no title")
		expect.equal(config.CARDS, nil, "no place cards")
		expect.equal(config.CARD_POP, nil)
		expect.equal(WelcomePath.cardAt, nil, "nothing left that pops a card in")
		for name in welcome.SOUNDS do
			assert(name ~= "chime" and name ~= "sparkle", `{name}: the title's and cards' sounds went with them`)
		end
	end,

	["the confetti goes off as the flight reaches your shop"] = function()
		local at = welcome.FINALE.at
		assert(at > welcome.SECONDS * 0.8 and at < welcome.SECONDS, `{at} s: near the end, before it`)
		local cued = false
		for _, cue in welcome.CUES do
			cued = cued or (cue.sound == "finale" and math.abs(cue.at - at) < 0.2)
		end
		expect.equal(cued, true, "its sound with it")
	end,

	["cues fire once, as the flight passes their moment"] = function()
		local cues = { { at = 1, sound = "a" }, { at = 2, sound = "b" }, { at = 2.05, sound = "c" } }
		expect.equal(#WelcomePath.crossed(cues, 0, 0.9), 0)
		local first = WelcomePath.crossed(cues, 0.9, 1)
		expect.equal(#first, 1)
		expect.equal(first[1].sound, "a")
		expect.equal(#WelcomePath.crossed(cues, 1, 1.5), 0, "not again")
		local both = WelcomePath.crossed(cues, 1.5, 2.1)
		expect.equal(#both, 2, "a long frame passes two")
		for _, cue in welcome.CUES do
			assert(cue.at >= 0 and cue.at <= welcome.SECONDS, "every cue inside the flight")
			assert(welcome.SOUNDS[cue.sound], `{cue.sound}: a sound it knows`)
		end
		for name, id in welcome.SOUNDS do
			assert(string.match(id, "^rbxassetid://%d+$"), `{name}: a sound id`)
		end
		local whooshes = 0
		for _, cue in welcome.CUES do
			whooshes += if string.find(cue.sound, "whoosh") then 1 else 0
		end
		assert(whooshes >= 3, "a whoosh on the fast stretches")
	end,

	-- The owner 2026-11-11: "dont add drawn confetti. search for a free/safe particle/VFX on creator store that suits
	-- this cinematic": Onogork's Confetti Particle Emitter (8250441745, its own textures, a colour-only script left out)
	-- and the Euphoric Games VFX Pack's star burst, stars and glow (vetted 2026-11-08), copied into our emitters
	["the finale's effects are the store packs' particles, with textures we know"] = function()
		local finale = welcome.FINALE
		local confetti = 0
		for _, piece in { finale.confetti, finale.burst, finale.stars, finale.glow } do
			assert(piece and piece.emitter, "each piece has its emitter")
			assert(AttackFx.TEXTURES[piece.emitter.texture], `{piece.emitter.texture}: a texture in AttackFx`)
			assert(piece.count > 0, "it bursts")
		end
		for _, colors in finale.confetti.palette do
			confetti += 1
			expect.equal(#colors, 2, "a light and a dark side (it flickers as it spins)")
		end
		assert(confetti >= 4, "confetti in a few colours")
		assert(finale.confetti.count * confetti * 2 >= 60, "a good shower from both cannons")
	end,

	["lens: wider when flying fast, banking into turns, within limits"] = function()
		local lens = welcome.LENS
		local fov, roll = WelcomePath.lens(0, 0, lens)
		expect.equal(fov, lens.fov, "still: the normal view")
		expect.equal(roll, 0)
		local fastFov = WelcomePath.lens(1000, 0, lens)
		expect.equal(fastFov, lens.fov + lens.maxExtra, "never wider than its limit")
		local _, left = WelcomePath.lens(50, 40, lens)
		local _, right = WelcomePath.lens(50, -40, lens)
		assert(left > 0 and right < 0, "banks into the turn (a left turn rolls it left)")
		local _, hard = WelcomePath.lens(50, 10000, lens)
		expect.equal(hard, lens.maxRoll, "never past its bank")
	end,

	["the flight lasts 10-12 seconds"] = function()
		assert(welcome.SECONDS >= 10 and welcome.SECONDS <= 12, `{welcome.SECONDS} s`)
	end,

	["it ends at the player's own shop"] = function()
		local keys = WelcomePath.keys(welcome, DOOR, OUT)
		local pos, look = WelcomePath.sample(keys, 1)
		expect.near(pos.z, DOOR.z + welcome.SHOP_VIEW.back, 1e-6, "in front of the door")
		expect.near(pos.y, DOOR.y + welcome.SHOP_VIEW.up, 1e-6, "a little above it")
		expect.near(look.x, DOOR.x, 1e-6, "looking at it")
		expect.near(look.z, DOOR.z, 1e-6, "looking at it")
	end,

	["it starts at the first key"] = function()
		local keys = WelcomePath.keys(welcome, DOOR, OUT)
		local pos = WelcomePath.sample(keys, 0)
		expect.near(pos.x, welcome.KEYS[1].pos.x, 1e-6, "x")
		expect.near(pos.z, welcome.KEYS[1].pos.z, 1e-6, "z")
	end,

	["sunset holds for the last half"] = function()
		expect.equal(WelcomePath.dayProgress(welcome, 0), 0, "morning at the start")
		expect.equal(WelcomePath.dayProgress(welcome, 0.5), 1, "sunset by halfway")
		expect.equal(WelcomePath.dayProgress(welcome, 0.9), 1, "still sunset")
		local quarter = WelcomePath.dayProgress(welcome, 0.25)
		assert(quarter > 0 and quarter < 1, "a time-lapse in between")
	end,

	["keys run in order through the three areas and the plaza"] = function()
		local keys = WelcomePath.keys(welcome, DOOR, OUT)
		expect.equal(keys[1].t, 0, "starts at 0")
		expect.equal(keys[#keys].t, 1, "ends at 1")
		for index = 2, #keys do
			assert(keys[index].t > keys[index - 1].t, `key {index} is out of order`)
		end
		expect.equal(#keys, #welcome.KEYS + 1, "every config key plus the shop")
	end,

	["the flight moves smoothly (no jumps between frames)"] = function()
		local keys = WelcomePath.keys(welcome, DOOR, OUT)
		local last = WelcomePath.sample(keys, 0)
		local steps = welcome.SECONDS * 60
		for step = 1, steps do
			local pos = WelcomePath.sample(keys, step / steps)
			local jump = math.sqrt((pos.x - last.x) ^ 2 + (pos.y - last.y) ^ 2 + (pos.z - last.z) ^ 2)
			assert(jump < 8, `a {jump}-stud jump at frame {step}`)
			last = pos
		end
	end,
}
