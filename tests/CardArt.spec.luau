--!strict
-- Which painting a card face draws (Util/CardArt): the half-size copy wherever the face is drawn no taller than it
-- (binder pages, shelves, cases), the full one only for big views. The full paintings (680 x 1014) took about 113 MB
-- of texture memory and 6 MB to download; drawn small they got evicted and reloaded, leaving binder faces blank.
local art = require("../src/shared/Config/CardArt")
local CardArt = require("../src/shared/Util/CardArt")
local expect = require("./lib/expect")

local function aCard(): string
	for name in art.FULL do
		return name
	end
	error("no art")
end

return {
	["small faces draw the small copy"] = function()
		local name = aCard()
		expect.equal(CardArt.pick(name, 300, art), art.SMALL[name], "a binder-size face")
		expect.equal(CardArt.pick(name, art.SMALL_HEIGHT, art), art.SMALL[name], "as tall as the copy")
	end,

	["big views draw the full painting"] = function()
		local name = aCard()
		expect.equal(CardArt.pick(name, art.SMALL_HEIGHT + 1, art), art.FULL[name], "taller than the copy")
		expect.equal(CardArt.pick(name, 900, art), art.FULL[name], "a big view")
	end,

	["every painting has its small copy"] = function()
		for name in art.FULL do
			assert(art.SMALL[name] and art.SMALL[name] ~= "", `{name} has no small copy`)
		end
		for name in art.SMALL do
			assert(art.FULL[name], `{name} has a small copy but no painting`)
		end
	end,

	["a missing copy or painting falls back"] = function()
		local fake = { FULL = { Test = "full" }, SMALL = {}, SMALL_HEIGHT = 507 }
		expect.equal(CardArt.pick("Test", 100, fake), "full", "no small copy: the full painting")
		expect.isNil(CardArt.pick("Nobody", 100, fake), "no painting at all")
	end,
}
