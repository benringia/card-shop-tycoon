--!strict
-- The register's payment step (Config/Payment): how a customer pays, the bill they hand over, the card machine's keys
-- and the change you count. Money is in whole cents. Pure: the server checks every answer with it, the client draws
-- and pre-checks with the same rules (Lune-tested)
local PaymentRules = {}

export type Method = "card" | "cash"
export type ChangeResult = "ok" | "short" | "over" | "bad"

function PaymentRules.method(config: any, kind: string, roll: number): Method
	local chance = config.CARD_CHANCE[kind] or config.CARD_CHANCE.default
	return if roll < chance then "card" else "cash"
end

-- The money the customer hands over: the smallest bill above the total, or past the biggest bill the next $50 above
function PaymentRules.given(config: any, totalCents: number): number
	for _, bill in config.BILLS do
		if bill > totalCents then
			return bill
		end
	end
	local step = config.BIG_ROUND
	return (math.floor(totalCents / step) + 1) * step
end

-- The card machine's screen after a key: a digit, ".", "del" or "clear"; at most two decimals, no leading zeros
function PaymentRules.typeKey(text: string, key: string, maxLength: number): string
	if key == "del" then
		return string.sub(text, 1, -2)
	elseif key == "clear" then
		return ""
	end
	local dot = string.find(text, ".", 1, true)
	if key == "." then
		if dot or #text >= maxLength then
			return text
		end
		return if text == "" then "0." else text .. "."
	end
	if not string.match(key, "^%d$") or #text >= maxLength then
		return text
	end
	if dot and #text - dot >= 2 then
		return text
	end
	return if text == "0" then key else text .. key
end

-- What the screen says, in cents; nil when it isn't an amount yet
function PaymentRules.typedCents(text: string): number?
	local whole, fraction = string.match(text, "^(%d*)%.?(%d*)$")
	if not whole or not fraction or (whole == "" and fraction == "") or #fraction > 2 then
		return nil
	end
	local dollars = if whole == "" then 0 else tonumber(whole) :: number
	local cents = if fraction == "" then 0 else (tonumber(fraction) :: number) * (if #fraction == 1 then 10 else 1)
	return dollars * 100 + cents
end

function PaymentRules.cardRight(typedCents: number, totalCents: number): boolean
	return typedCents == totalCents and typedCents == math.floor(typedCents)
end

-- The change you're giving (a list of bills and coins, each a Config/Payment DRAWER value) against what's due
function PaymentRules.checkChange(config: any, pieces: unknown, changeCents: number): ChangeResult
	if typeof(pieces) ~= "table" then
		return "bad"
	end
	local list = pieces :: { unknown }
	if #list > config.MAX_PIECES then
		return "bad"
	end
	local sum = 0
	for key, piece in list do
		if typeof(key) ~= "number" or typeof(piece) ~= "number" or not table.find(config.DRAWER, piece) then
			return "bad"
		end
		sum += piece :: number
	end
	if sum == changeCents then
		return "ok"
	end
	return if sum < changeCents then "short" else "over"
end

function PaymentRules.money(cents: number): string
	return string.format("$%d.%02d", math.floor(cents / 100), cents % 100)
end

-- A bill without cents ("$20"), a coin with them ("$0.25")
function PaymentRules.pieceText(cents: number): string
	return if cents >= 100 and cents % 100 == 0 then `${cents // 100}` else PaymentRules.money(cents)
end

return PaymentRules
