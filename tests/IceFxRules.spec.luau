--!strict
-- The Frost Tyrant's ice (the owner 2026-11-10: "Frost shield will be a shield made of ice around him... his special
-- attack maybe a very large ice spikes falling from above. on impact: shatters the ice spike with ice smokes")
local IceFxRules = require("../src/shared/Util/IceFxRules")
local AttackFx = require("../src/shared/Config/AttackFx")
local Bosses = require("../src/shared/Config/Bosses")
local expect = require("./lib/expect")

return {
	["a spike hangs over its ring, then drops to land with the hit"] = function()
		local seconds, fall, height = 1.25, 0.45, 60
		expect.near(IceFxRules.dropAt(seconds, fall), 0.8, 1e-9)
		expect.equal(IceFxRules.dropAt(0.2, fall), 0, "a short warning drops at once")
		expect.equal(IceFxRules.heightAt(0, seconds, fall, height), height)
		expect.equal(IceFxRules.heightAt(0.7, seconds, fall, height), height, "still hanging")
		expect.near(IceFxRules.heightAt(seconds, seconds, fall, height), 0, 1e-9, "lands on the hit")
		local last = height
		for step = 1, 10 do
			local now = IceFxRules.heightAt(0.8 + step * 0.045, seconds, fall, height)
			assert(now <= last, "it only falls")
			last = now
		end
		-- it speeds up as it falls: the second half of the drop covers more than the first
		local middle = IceFxRules.heightAt(0.8 + fall / 2, seconds, fall, height)
		assert(height - middle < middle, "eases in")
	end,

	["the shield's shards spread round the bubble, none sticking down into the ground"] = function()
		local shards = IceFxRules.shieldShards(24)
		expect.equal(#shards, 24)
		local quarters = { 0, 0, 0, 0 }
		for _, shard in shards do
			assert(shard.pitch >= -15 and shard.pitch <= 70, `pitch {shard.pitch}`)
			assert(shard.length > shard.width, "pointed, longer than wide")
			local quarter = math.floor((shard.yaw % 360) / 90) + 1
			quarters[quarter] += 1
		end
		for index, n in quarters do
			assert(n >= 4, `quarter {index} has only {n} shards`)
		end
	end,

	["a shattered spike throws its pieces all round, out and up"] = function()
		local pieces = IceFxRules.shatterPieces(12)
		expect.equal(#pieces, 12)
		local left, right = 0, 0
		for _, piece in pieces do
			assert(piece.up > 0 and piece.speed > 0 and piece.size > 0, "flung up and out")
			if math.cos(math.rad(piece.yaw)) < 0 then
				left += 1
			else
				right += 1
			end
		end
		assert(left >= 4 and right >= 4, "both ways")
	end,

	["the Frost Tyrant's ice looks and sounds are set"] = function()
		local ice = AttackFx.ICE
		assert(ice.spike.height >= 40 and ice.spike.length >= 12, "a very large spike from high up")
		assert(ice.spike.fall > 0 and ice.spike.fall < Bosses.BOSSES.frostTyrant.playerAttacks.warning, "it drops within the warning")
		assert(ice.shield.shards >= 16, "shards jutting out of the bubble")
		for _, key in { "fall", "shatter", "shieldForm", "shieldBreak", "freeze" } do
			assert(string.match(ice.sounds[key] or "", "^rbxassetid://%d+$"), `ICE.sounds.{key}`)
		end
		local boss = AttackFx.BOSS.frostTyrant
		assert(boss, "the Frost Tyrant has its attack looks")
		expect.equal(boss.spikes, true, "his ring is ice spikes")
		expect.equal(boss.iceShield, true, "his shield is the ice bubble")
		assert(string.match(boss.sounds.strike, "^rbxassetid://%d+$") and string.match(boss.sounds.release, "^rbxassetid://%d+$"), "his hit sounds")
	end,
}
