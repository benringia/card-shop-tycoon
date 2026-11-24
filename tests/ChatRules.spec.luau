--!strict
-- Customer chat bubbles (owner 2026-11-19, second playthrough: "add personalities for the customers like chat
-- bubbles"): each type speaks in its own voice at the moments of its visit
local ChatRules = require("../src/shared/Util/ChatRules")
local CustomerChat = require("../src/shared/Config/CustomerChat")
local Customers = require("../src/shared/Config/Customers")
local expect = require("./lib/expect")

-- every moment the server speaks at (CustomerService.Say callers)
local MOMENTS = { "enter", "found", "pricey", "missing", "queue", "gaveUp", "paid", "tip", "foundAll", "haggle", "deal", "noDeal", "admire", "pet", "pull", "sell", "sold" }
-- moments only one type lives through ("Found it all!" pays plain customers only: Config/Customers FOUND_ALL)
local ONLY = { haggle = "bargain", pull = "kid", sell = "kid", sold = "kid", foundAll = "plain" }

return {
	["every customer type has something to say at every moment of its visit"] = function()
		for kind in Customers.TYPES do
			for _, moment in MOMENTS do
				if ONLY[moment] == nil or ONLY[moment] == kind then
					local lines = ChatRules.lines(CustomerChat, kind, moment)
					assert(lines and #lines > 0, `{kind} at {moment}: a line`)
				end
			end
		end
		for _, moment in MOMENTS do
			assert(CustomerChat.CHANCE[moment], `{moment}: how often they speak`)
		end
		for moment in CustomerChat.CHANCE do
			assert(table.find(MOMENTS, moment), `{moment}: a moment the server speaks at`)
		end
	end,

	["each type has its own voice: its own lines walking in and paying"] = function()
		local plain = CustomerChat.LINES.plain
		for kind in Customers.TYPES do
			if kind ~= "plain" then
				local own = CustomerChat.LINES[kind]
				assert(own, `{kind} has lines`)
				assert(own.enter and own.enter ~= plain.enter and #own.enter >= 2, `{kind}: its own hellos`)
				assert(own.paid and #own.paid >= 2, `{kind}: its own goodbyes`)
			end
		end
		expect.equal(ChatRules.lines(CustomerChat, "collector", "gaveUp"), plain.gaveUp, "a moment without its own: the plain customer's")
		expect.equal(ChatRules.lines(CustomerChat, "nobody", "enter"), plain.enter, "an unknown type too")
		expect.isNil(ChatRules.lines(CustomerChat, "plain", "nothing"))
	end,

	["missing lines name the product"] = function()
		expect.equal(ChatRules.text(CustomerChat, "plain", "missing", 1, "sleeves"), "No sleeves? Aww.")
		expect.equal(ChatRules.text(CustomerChat, "kid", "missing", 1, "packs"), "Nooo, no packs?")
		for kind, moments in CustomerChat.LINES do
			for index in moments.missing or {} do
				local text = ChatRules.text(CustomerChat, kind, "missing", index, "Frontier packs") :: string
				assert(#text <= CustomerChat.MAX_CHARS + 4, `{kind} missing {index}: "{text}" fits with the longest product word`)
			end
		end
		for index, line in CustomerChat.LINES.plain.missing do
			assert(string.find(line, "%s", 1, true), `plain missing {index} names the product`)
		end
	end,

	["found it all lines"] = function()
		local lines = CustomerChat.LINES.plain.foundAll
		assert(lines and #lines >= 2, "a few ways to cheer")
		expect.equal(lines[1], "Found it all!")
		expect.equal(CustomerChat.CHANCE.foundAll, 1, "always said: it explains the bonus")
	end,

	["lines are short, plain ASCII and never show a raw %s"] = function()
		for kind, moments in CustomerChat.LINES do
			for moment, lines in moments do
				for index, line in lines do
					assert(#line <= CustomerChat.MAX_CHARS, `{kind} {moment} {index}: fits the bubble ("{line}")`)
					assert(not string.find(line, "[^\32-\126]"), `{kind} {moment} {index}: plain ASCII`)
					assert(not string.find(line, "|", 1, true), "never the attribute's separator")
					local text = ChatRules.text(CustomerChat, kind, moment, index, "$2.72")
					assert(text and not string.find(text, "%s", 1, true), `{kind} {moment} {index}: its word filled in`)
					assert(#(text :: string) <= CustomerChat.MAX_CHARS + 4, "still short with a price in it")
				end
			end
		end
		expect.equal(ChatRules.text(CustomerChat, "bargain", "haggle", 1, "$2.72"), "How about $2.72?")
		expect.equal(ChatRules.text(CustomerChat, "bargain", "haggle", 1, "$5%1"), "How about $5%1?", "a word is never read as a pattern")
		expect.equal(ChatRules.text(CustomerChat, "plain", "paid", 1, "$9"), CustomerChat.LINES.plain.paid[1], "a line without a word ignores it")
		expect.isNil(ChatRules.text(CustomerChat, "plain", "paid", 99, nil))
	end,

	["whether they speak: the moment's chance, then one of the lines"] = function()
		local chance = CustomerChat.CHANCE.enter
		assert(chance > 0 and chance < 1, "not everyone says hello: a full shop isn't a wall of text")
		expect.isNil(ChatRules.pick(CustomerChat, "kid", "enter", chance, 0), "the roll at the chance: quiet")
		expect.equal(ChatRules.pick(CustomerChat, "kid", "enter", chance - 0.01, 0), 1)
		local count = #CustomerChat.LINES.kid.enter
		expect.equal(ChatRules.pick(CustomerChat, "kid", "enter", 0, 0.999), count, "the last line")
		expect.equal(ChatRules.pick(CustomerChat, "kid", "enter", 0, 1), count, "never past it")
		expect.equal(ChatRules.pick(CustomerChat, "bargain", "haggle", 0.99, 0), 1, "an offer is always said")
		expect.isNil(ChatRules.pick(CustomerChat, "plain", "nothing", 0, 0), "an unknown moment")
		expect.isNil(ChatRules.pick(CustomerChat, "plain", "haggle", 0, 0), "a moment that type has no lines for")
	end,

	["the attribute round trips, and junk is nothing"] = function()
		local value = ChatRules.encode("haggle", 2, 17, "$2.72")
		local said = ChatRules.decode(value)
		assert(said, "read back")
		expect.equal(said.moment, "haggle")
		expect.equal(said.index, 2)
		expect.equal(said.word, "$2.72")
		assert(ChatRules.encode("paid", 1, 1, nil) ~= ChatRules.encode("paid", 1, 2, nil), "the same line twice is still a change")
		expect.equal((ChatRules.decode(ChatRules.encode("paid", 1, 3, nil)) :: any).word, "")
		expect.equal((ChatRules.decode(ChatRules.encode("haggle", 1, 3, "a|b")) :: any).word, "ab", "no separator in the word")
		expect.isNil(ChatRules.decode(nil))
		expect.isNil(ChatRules.decode(12))
		expect.isNil(ChatRules.decode("hello"))
		expect.isNil(ChatRules.decode("paid|x|1|"))
	end,

	["a bubble is short-lived and sits over the mood icon"] = function()
		assert(CustomerChat.SECONDS >= 2 and CustomerChat.SECONDS <= 5)
		assert(CustomerChat.OFFSET_Y > 3, "above the mood icon over the head")
		assert(CustomerChat.OFFSET_Y_COLLECTOR > Customers.COLLECTOR.thought.offsetY + 2, "above a collector's card bubble")
		assert(CustomerChat.MAX_DISTANCE <= 80)
	end,
}
