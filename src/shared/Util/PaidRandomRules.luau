--!strict
-- Chance-based purchases (the content questionnaire, 2026-11-16): luck boosts (Config/Luck) raise the odds of rare
-- pulls and Turts' "restock now" (Config/Turts PRODUCT) is a paid re-roll of his offers, so both count as paid random
-- items. Where Roblox restricts those (PolicyService:GetPolicyInfoForPlayerAsync's ArePaidRandomItemsRestricted)
-- neither is sold. Pure: the caller passes the pcall's result; a policy that can't be read counts as restricted.
local PaidRandomRules = {}

function PaidRandomRules.restricted(ok: boolean, info: unknown): boolean
	if not ok or typeof(info) ~= "table" then
		return true
	end
	return (info :: { [string]: unknown }).ArePaidRandomItemsRestricted ~= false
end

return PaidRandomRules
