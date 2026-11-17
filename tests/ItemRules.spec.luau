--!strict
local ItemRules = require("../src/shared/Util/ItemRules")
local config = require("../src/shared/Config/Items")
local Bosses = require("../src/shared/Config/Bosses")
local expect = require("./lib/expect")

return {
	-- Owner 2026-11-17 ("do all": Open 10): a stack of Bag packs opens up to 10 at once; one pack has just Open
	["Open 10: up to ten packs from a stack of two or more"] = function()
		expect.equal(ItemRules.openMany(85, 10), 10, "a big stack: ten")
		expect.equal(ItemRules.openMany(4, 10), 4, "a small stack: all of it")
		expect.equal(ItemRules.openMany(1, 10), 0, "one pack: just Open")
		expect.equal(ItemRules.openMany(0, 10), 0, "none")
		expect.equal(ItemRules.openMany(-3, 10), 0, "nonsense")
		expect.equal(ItemRules.openMany(7.6, 10), 7, "whole packs")
	end,

	-- Owner 2026-11-14: "item description should be rewritten, it should easily be understandable by a child". The
	-- Bag shows each item's three lines (what it does, where to get it, how to use it): plain words our fonts draw
	-- (ASCII plus "·"; the "→" arrows were drawn as boxes), short, no trading-card jargon
	["item text is short, plain and kid-friendly"] = function()
		local JARGON = { "duplicate", "condens", "forges and upgrades", "booster" }
		for id, info in config.ITEMS do
			for _, field in { "description", "source", "use" } do
				local text = info[field]
				assert(type(text) == "string" and text ~= "", `{id} has a {field}`)
				local plain = string.gsub(text, "·", "")
				assert(not string.find(plain, "[^\32-\126]"), `{id}'s {field} is plain text: {text}`)
			end
			assert(#info.description <= 90, `{id}'s description is short ({#info.description} letters)`)
			local lower = string.lower(info.description)
			for _, word in JARGON do
				assert(not string.find(lower, word, 1, true), `{id}'s description says "{word}": {info.description}`)
			end
		end
	end,

	["only pack items open"] = function()
		expect.equal(ItemRules.openablePack(config, "sparkPack"), "FirstSparkPack", "the level-up pack")
		for _, bad in { "xpTonic", "nope", 42, nil } do
			expect.isNil(ItemRules.openablePack(config, bad), `not openable: {tostring(bad)}`)
		end
		expect.isNil(ItemRules.openablePack(config, nil), "nil")
	end,

	-- Owner 2026-11-17: "on pack boxes. add an option that player can put all the cardpacks inside the box to their
	-- inventory ... they will never have to go back to the delivery to pickup packs to rip". A carried box of packs or
	-- deck boxes goes in the Bag as its item; opening one gives its market price in shop XP, like ripping it from the box
	["a carried box of packs goes in the Bag as its pack item"] = function()
		expect.equal(ItemRules.stockItem(config, "FirstSparkPack"), "sparkPack", "packs")
		expect.equal(ItemRules.stockItem(config, "DeckBox"), "deckBox", "deck boxes")
		for _, bad in { "FirstSparkBox", "CardSleeves", "nope", 42, nil } do
			expect.isNil(ItemRules.stockItem(config, bad), `no Bag item for {tostring(bad)}`)
		end
		expect.equal(ItemRules.openablePack(config, "deckBox"), "DeckBox", "a deck box opens as one")
	end,

	["a Bag pack from stock gives shop XP when opened; gifts don't"] = function()
		expect.equal(ItemRules.stockOf(config, "sparkPack"), "FirstSparkPack")
		expect.equal(ItemRules.stockOf(config, "deckBox"), "DeckBox")
		for _, gift in { "pishPresent", "pishGift", "vrPack", "legendaryPack", "xpTonic", "nope", 7 } do
			expect.isNil(ItemRules.stockOf(config, gift), `{tostring(gift)}: no shop XP`)
		end
	end,

	-- Turts' rug shop (spec 2026-11-13-turts-shop-design): his packs open from the Bag with their floors; the Legendary
	-- Pack's Legendary rolls the stingy pity grades, so it can't skip the long Grade S chase
	["Turts' packs open from the Bag with their floors; the Legendary Pack's grade is the stingy one"] = function()
		local product, floor, stingy = ItemRules.openablePack(config, "legendaryPack")
		expect.equal(product, "FirstSparkPack")
		expect.equal(floor, "Legendary")
		expect.equal(stingy, true)
		local _, epicFloor, epicStingy = ItemRules.openablePack(config, "epicPack")
		expect.equal(epicFloor, "Epic")
		expect.equal(epicStingy, false)
		local _, vrFloor, vrStingy = ItemRules.openablePack(config, "vrPack")
		expect.equal(vrFloor, "Very Rare")
		expect.equal(vrStingy, false)
		local _, giftFloor, giftStingy = ItemRules.openablePack(config, "pishGift")
		expect.equal(giftFloor, "Very Rare")
		expect.equal(giftStingy, false, "Pish's gift rolls its grade as usual")
		-- every item Turts sells exists
		local Turts = require("../src/shared/Config/Turts")
		for id, offer in Turts.OFFERS do
			assert(config.ITEMS[offer.item], `{id} sells {offer.item}, which isn't an item`)
		end
	end,

	-- Owner 2026-11-13 (Turts' window showed "Forges the Magma Halberd (coming soon)"): an item never calls a weapon
	-- that's out "coming soon"
	["no item calls a released weapon coming soon"] = function()
		local Weapons = require("../src/shared/Config/Weapons")
		for id, info in config.ITEMS do
			local text = string.lower(info.description or "")
			for _, weapon in Weapons.WEAPONS do
				if weapon.ready ~= false and string.find(text, string.lower(weapon.name), 1, true) then
					assert(not string.find(text, "coming soon", 1, true), `{id} calls the {weapon.name} coming soon`)
				end
			end
		end
	end,

	-- Pish's end gift (spec 2026-11-09-tutorial-pish-design 5): a First Spark pack whose hit card is Very Rare or better
	["openablePack: the gift opens a First Spark pack with a Very Rare floor"] = function()
		local product, floor = ItemRules.openablePack(config, "pishGift")
		expect.equal(product, "FirstSparkPack")
		expect.equal(floor, "Very Rare")
		local plain, none = ItemRules.openablePack(config, "sparkPack")
		expect.equal(plain, "FirstSparkPack")
		expect.isNil(none, "the level-up pack has no floor")
	end,

	-- Round 3 (owner 2026-11-10: "we need an icon for pish's gift. that will make players excited"): his present at the
	-- start is its own item with his picture, his gift at the end too
	["Pish's present is its own item: a First Spark pack, no floor, his pictures on both gifts"] = function()
		local Pish = require("../src/shared/Config/Pish")
		local UIIcons = require("../src/shared/Config/UIIcons")
		expect.equal(Pish.FIRST_ITEM, "pishPresent")
		local product, floor = ItemRules.openablePack(config, Pish.FIRST_ITEM)
		expect.equal(product, "FirstSparkPack")
		expect.isNil(floor, "a plain pack")
		expect.equal(config.ITEMS.pishPresent.icon, "PishPresent")
		expect.equal(config.ITEMS.pishGift.icon, "PishGift")
		assert(UIIcons.PishPresent and UIIcons.PishGift, "both pictures uploaded")
	end,

	-- owner 2026-11-14: "all card pack in my inventory look the same (epic/legendary/first cardpack) ... samewith the
	-- trophies and keys": each key fragment, trophy and Turts pack has its own uploaded picture
	["every key fragment, trophy and rarity pack has its own picture"] = function()
		local UIIcons = require("../src/shared/Config/UIIcons")
		local seen: { [string]: string } = {}
		local checked = 0
		for id, item in config.ITEMS do
			local own = string.match(id, "^fragment_") or string.match(id, "^trophy_") or item.floor ~= nil and item.icon ~= "PishGift"
			if own then
				checked += 1
				assert(UIIcons[item.icon], `{id}: its icon {item.icon} is uploaded`)
				expect.equal(item.icon ~= "KeyFragment" and item.icon ~= "Trophy" and item.icon ~= "BoosterPack", true, `{id}: not the shared picture`)
				expect.isNil(seen[item.icon], `{id} shares {item.icon} with {seen[item.icon]}`)
				seen[item.icon] = id
			end
		end
		expect.equal(checked, 6 + 7 + 3, "six keys, seven trophies, three packs")
	end,

	-- Owner 2026-11-17: "first spark pack in the inventory should use the actual card icon/model": the Bag's First Spark
	-- Pack and Deck Box show the real models' pictures, the same ones the Order Stock and Prices menus show
	["the First Spark Pack and Deck Box show their real models' pictures"] = function()
		local UIIcons = require("../src/shared/Config/UIIcons")
		local ProductPictures = require("../src/shared/Config/ProductPictures")
		expect.equal(UIIcons[config.ITEMS.sparkPack.icon], ProductPictures.LOOKS.FirstSpark.Pack, "the pack")
		expect.equal(UIIcons[config.ITEMS.deckBox.icon], ProductPictures.LOOKS.FirstSpark.Deck, "the deck box")
	end,

	-- Owner 2026-11-17: "trophies should have "PLACE" button on them that you can place directly to the shop. remove them
	-- from the shop": every trophy is placed from the Bag (its id is its Config/Shelves entry's), nothing else is, and its
	-- words say so, never the Shop's Build menu
	["trophies are placed from the Bag with Place, never from the Shop"] = function()
		local trophies = 0
		for id, info in config.ITEMS do
			local trophy = string.match(id, "^trophy_") ~= nil
			expect.equal(ItemRules.placesInShop(config, id), trophy, `{id} placed from the Bag`)
			if trophy then
				trophies += 1
				assert(string.find(info.use, "Place", 1, true), `{id} says to tap Place: {info.use}`)
				assert(not string.find(info.use, "Build", 1, true), `{id} no longer goes through Build: {info.use}`)
			end
		end
		expect.equal(trophies, #Bosses.LADDER, "one trophy per boss")
		for _, bad in { "nope", 42, nil } do
			expect.equal(ItemRules.placesInShop(config, bad), false, `not placeable: {tostring(bad)}`)
		end
	end,

	-- Owner 2026-11-17: "make the description for the upgrade materials easier to understand. like Used to upgrade
	-- whatever item": each weapon material says "Used to make and upgrade" and names every weapon it makes or upgrades
	["weapon materials say plainly which weapons they make and upgrade"] = function()
		local Weapons = require("../src/shared/Config/Weapons")
		local WeaponRules = require("../src/shared/Util/WeaponRules")
		local PREFIX = "Used to make and upgrade the "
		for id, info in config.ITEMS do
			if string.match(id, "^material_") then
				expect.equal(string.sub(info.description, 1, #PREFIX), PREFIX, `{id} starts plainly`)
				for _, weapon in Weapons.WEAPONS do
					local cost = WeaponRules.makeCost(Weapons, weapon.id)
					local uses = WeaponRules.material(Weapons, weapon.id) == id or (cost ~= nil and (cost.items[id] or 0) > 0)
					if uses and weapon.ready ~= false then
						assert(string.find(info.description, weapon.name, 1, true), `{id} names the {weapon.name}: {info.description}`)
					end
				end
			end
		end
		expect.equal(config.ITEMS.wildOre.description, "Used to make and upgrade the Forge Sword, Forge Spear and Forge Scythe.")
	end,

	-- Owner 2026-11-17: "nerf exp tonic from 400exp to 300"
	["the XP Tonic gives 300 XP and says so"] = function()
		expect.equal(config.ITEMS.xpTonic.xp, 300)
		assert(string.find(config.ITEMS.xpTonic.description, "300 XP", 1, true), config.ITEMS.xpTonic.description)
	end,

	["sanitize: unknown ids, bad counts dropped; whole numbers; capped"] = function()
		local items = ItemRules.sanitize(config, { starShard = 4.9, mystery = 3, [5] = 1 })
		expect.equal(items.starShard, 4, "floored")
		expect.isNil(items.mystery, "unknown id dropped")
		for _, bad in { -1, 0 / 0, "7", math.huge } do
			expect.isNil(ItemRules.sanitize(config, { starShard = bad }).starShard, `bad {tostring(bad)}`)
		end
		expect.equal(ItemRules.sanitize(config, { starShard = 123456 }).starShard, config.MAX_STACK, "capped")
		expect.equal(next(ItemRules.sanitize(config, "junk")), nil, "junk -> empty")
	end,

	["add: capped at the stack limit, reports what was added"] = function()
		local items, added = ItemRules.add(config, { starShard = 9998 }, "starShard", 5)
		expect.equal(items.starShard, config.MAX_STACK, "capped")
		expect.equal(added, 1, "only 1 fit")
		local fresh, one = ItemRules.add(config, {}, "starShard", 1)
		expect.equal(fresh.starShard, 1, "first shard")
		expect.equal(one, 1, "added 1")
		local _, none = ItemRules.add(config, {}, "nope", 3)
		expect.equal(none, 0, "unknown id adds nothing")
	end,

	["take: nil when short, new table when enough"] = function()
		local items = { starShard = 3 }
		expect.isNil(ItemRules.take(items, "starShard", 4), "short")
		local after = ItemRules.take(items, "starShard", 3) :: any
		expect.isNil(after.starShard, "used up -> removed")
		expect.equal(items.starShard, 3, "input untouched")
		expect.isNil(ItemRules.take(items, "starShard", -1), "negative refused")
	end,
	["every boss drop, unlock and first-clear item exists in Config/Items"] = function()
		local function check(item: string, where: string)
			assert(config.ITEMS[item], `{where} gives {item}, which isn't in Config/Items`)
		end
		for id, boss in Bosses.BOSSES do
			for _, drop in boss.drops do
				check(drop.item, `{id} drops`)
			end
			for _, grant in boss.firstClear do
				check(grant.item, `{id} first clear`)
			end
			for _, grant in boss.dailyBonus do
				check(grant.item, `{id} daily bonus`)
			end
			if boss.unlock then
				check(boss.unlock.item, `{id} unlock`)
			end
		end
		assert(typeof(config.ITEMS.xpTonic and config.ITEMS.xpTonic.xp) == "number", "the XP Tonic says how much XP it gives")
	end,
	-- Owner 2026-11-17: "xp tonics should have a "Use button" then lets the player choose which pet in the party". The
	-- Bag's picker lists the party in slot order (gaps and cards the binder doesn't hold left out); a card at max level
	-- shows but can't take one (the server never wastes a tonic on it)
	["the XP Tonic's picker lists the party in slot order and marks max-level cards"] = function()
		local beasts = {
			low = { cardId = "c1", level = 4, xp = 10 },
			top = { cardId = "c2", level = 50, xp = 0 },
		}
		local targets = ItemRules.tonicTargets({ [3] = "low", [1] = "top", [2] = "gone" }, beasts, 3, 50)
		expect.equal(#targets, 2, "the two cards the binder holds")
		expect.equal(targets[1].slot, 1, "slot order")
		expect.equal(targets[1].beastId, "top", "slot 1's card")
		expect.equal(targets[1].maxed, true, "at max level")
		expect.equal(targets[2].slot, 3, "the unknown card in slot 2 left out")
		expect.equal(targets[2].cardId, "c1", "its card")
		expect.equal(targets[2].level, 4, "its level")
		expect.equal(targets[2].maxed, false, "can still level")
		expect.equal(#ItemRules.tonicTargets({}, beasts, 3, 50), 0, "an empty party")
	end,
	["bossOf: fragments and trophies name their ladder step"] = function()
		local ladder = { "meadowWarden", "caveBroodQueen", "emberColossus" }
		local index, kind = ItemRules.bossOf("fragment_caveBroodQueen", ladder)
		expect.equal(index, 2, "opens boss 2")
		expect.equal(kind, "fragment", "a fragment")
		index, kind = ItemRules.bossOf("trophy_meadowWarden", ladder)
		expect.equal(index, 1, "boss 1's trophy")
		expect.equal(kind, "trophy", "a trophy")
		expect.isNil((ItemRules.bossOf("xpTonic", ladder)), "not a boss item")
		expect.isNil((ItemRules.bossOf("fragment_unknownBoss", ladder)), "unknown boss")
	end,
}
