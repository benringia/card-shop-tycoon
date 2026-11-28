--!strict
-- VIP (spec 2026-11-28-robux-round-design): a gold [VIP] in front of a VIP's chat lines (VipChatController puts it on
-- each incoming message, which can come by more than once: sending, then delivered)
local VipRules = require("../src/shared/Util/VipRules")
local Vip = require("../src/shared/Config/Vip")
local expect = require("./lib/expect")

return {
	["the prefix puts a gold [VIP] in front"] = function()
		expect.equal(VipRules.chatPrefix("n0gginss:", Vip), '<font color="#FFD23F"><b>[VIP]</b></font> n0gginss:')
	end,

	["the prefix is added once"] = function()
		local once = VipRules.chatPrefix("n0gginss:", Vip)
		expect.equal(VipRules.chatPrefix(once, Vip), once)
	end,

	["an empty prefix still gets the tag"] = function()
		expect.equal(VipRules.chatPrefix("", Vip), '<font color="#FFD23F"><b>[VIP]</b></font> ')
	end,

	["the gold name's look"] = function()
		expect.equal(Vip.NAME.crown, "👑")
		expect.equal(#Vip.NAME.gradient >= 2, true, "a gradient")
	end,
}
