--!strict
-- Order Stock's row words (spec 2026-11-04-round4-design section 4): the button shows the box price to order it,
-- "Need $48" (the box price) when you can't afford it, "Lv 11" while the shop level is too low; the tag says what each
-- unit sells for. The server re-checks level and cash (StockService). Pure, Lune-tested.
local OrderRules = {}

export type Button = { text: string, state: "locked" | "short" | "ready" }

-- $48 -> "$48.00"; whole 100 or more drop the cents ("$120")
local function money(amount: number, dropCents: boolean): string
	if dropCents and amount >= 100 and amount == math.floor(amount) then
		return `${amount}`
	end
	return string.format("$%.2f", amount)
end

-- "Need $48": whole dollars without cents, otherwise with them ("Need $2.50")
local function need(amount: number): string
	if amount == math.floor(amount) then
		return `Need ${amount}`
	end
	return `Need {string.format("$%.2f", amount)}`
end

function OrderRules.button(level: number, unlockLevel: number, cash: number, boxCost: number): Button
	if level < unlockLevel then
		return { text = `Lv {unlockLevel}`, state = "locked" }
	end
	if cash < boxCost then
		return { text = need(boxCost), state = "short" }
	end
	return { text = money(boxCost, false), state = "ready" }
end

function OrderRules.sells(marketPrice: number): string
	return `sells ~{money(marketPrice, true)}`
end

return OrderRules
