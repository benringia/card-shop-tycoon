--!strict
-- Which pulls in a pack are NEW to the player's collection (pure, Lune-tested). The server checks before it
-- adds the cards, so the pack results screen can put a NEW ribbon on them. Only the first copy of a card
-- counts: two of the same new card in one pack show one NEW.
local NewPulls = {}

-- owned: cards the player has now (binder, beasts or on display). Returns one flag per pull, in order.
function NewPulls.flag(pulls: { { cardId: string } }, owned: { [string]: boolean }): { boolean }
	local seen: { [string]: boolean } = {}
	local flags = {}
	for index, pull in pulls do
		flags[index] = not owned[pull.cardId] and not seen[pull.cardId]
		seen[pull.cardId] = true
	end
	return flags
end

function NewPulls.count(flags: { boolean }): number
	local total = 0
	for _, isNew in flags do
		if isNew then
			total += 1
		end
	end
	return total
end

return NewPulls
