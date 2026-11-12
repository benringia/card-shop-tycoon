--!strict
-- The register's bell (owner 2026-11-12: "when a customer is at the cashier and there's no one there. play a 'Ding'
-- sound then notification 'someone is at the register'"; Util/RegisterBell, RegisterService): a customer at the counter
-- with nothing scanned for `grace` seconds (a working cashier starts first) while you're not behind it rings the desk
-- bell on your screen with `text`, then again every `every` seconds while nobody comes, `max` times in all; never
-- while you're in the Wild (owner 2026-11-12: "only be heard when I'm in town"). The toast shows on every `toastEvery`th
-- ring, the first included (owner 2026-11-12: "only once every two dings"). Plain data.
return {
	grace = 2.5,
	every = 20,
	max = 3,
	toastEvery = 2,
	check = 0.5, -- seconds between looks
	text = "Someone is at the register!",
	sound = { id = "rbxassetid://9125485591", volume = 0.12 }, -- Desk Bell Counter Service Single Ringing Ding (softer twice, owner 2026-11-12)
}
