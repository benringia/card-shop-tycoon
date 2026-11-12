--!strict
local ObjectiveRules = require("../src/shared/Util/ObjectiveRules")
local expect = require("./lib/expect")

local TEXTS = { room = "Defeat the guardians", plates = "Hold every plate", boss = "Defeat the Prism Hydra" }

return {
	["line: the stage's text and its progress"] = function()
		local line = ObjectiveRules.line("plates", 1, 2, TEXTS)
		expect.equal(line.text, "Hold every plate", "text")
		expect.equal(line.progress, "1 / 2", "progress")
	end,

	["line: no progress without a total; an unknown stage reads as a room"] = function()
		expect.equal(ObjectiveRules.line("boss", nil, nil, TEXTS).progress, nil, "boss: no count")
		expect.equal(ObjectiveRules.line("plates", 1, 0, TEXTS).progress, nil, "a zero total")
		expect.equal(ObjectiveRules.line("nonsense", nil, nil, TEXTS).text, "Defeat the guardians", "fallback")
	end,

	["label: a puzzle's own name over its line, OBJECTIVE elsewhere"] = function()
		local labels = { beams = "PUZZLE ROOM: PRISM BEAMS" }
		expect.equal(ObjectiveRules.label("beams", labels), "PUZZLE ROOM: PRISM BEAMS", "a puzzle")
		expect.equal(ObjectiveRules.label("room", labels), "OBJECTIVE", "a fight")
	end,

	["hint: the first at once, a new one every `every` seconds, the last stays"] = function()
		local hints = { beams = { "one", "two", "three" } }
		expect.equal(ObjectiveRules.hint("beams", 0, hints, 40), "one", "at once")
		expect.equal(ObjectiveRules.hint("beams", 39, hints, 40), "one", "not yet")
		expect.equal(ObjectiveRules.hint("beams", 40, hints, 40), "two", "after a while")
		expect.equal(ObjectiveRules.hint("beams", 500, hints, 40), "three", "the last stays")
		expect.equal(ObjectiveRules.hint("room", 10, hints, 40), nil, "no hints for a fight")
		expect.equal(ObjectiveRules.hint("beams", -5, hints, 40), "one", "a clock skew")
	end,
}
