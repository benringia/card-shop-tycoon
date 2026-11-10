--!strict
-- Which of Pish's lines shows (spec 2026-11-09-tutorial-pish-design 14). Pure: `talk` is a Config/PishTalk step.
export type StepTalk = { intro: { string }, now: { [string]: string } }
export type Shown = {
	text: string,
	next: boolean, -- a Next button (the intro); the line for now stays until it's done
	finish: boolean, -- this Next ends the talk (the goodbye's last line)
}

local TalkRules = {}

-- The intro one line at a time (`introIndex` from 1), then the line for now by situation (else its default); a talk
-- with only intro lines stays on its last one, whose Next finishes it
function TalkRules.show(talk: StepTalk, introIndex: number, situation: string): Shown
	local count = #talk.intro
	local hasNow = next(talk.now) ~= nil
	if introIndex <= count or (not hasNow and count > 0) then
		local index = math.clamp(introIndex, 1, count)
		return { text = talk.intro[index], next = true, finish = not hasNow and index == count }
	end
	return { text = talk.now[situation] or talk.now.default or "", next = false, finish = false }
end

-- Whether Pish's talk card sits at the top centre (the owner 2026-11-11: "move the dialogue at the center top so that
-- pish model can be seen"): yes, unless it would cover what he points at there (`target`: its top and bottom on
-- screen and whether it lies across the card's width), his paw `pawRoom` px over it included; then it goes down above
-- the HUD. `forceTop`: a fight keeps it at the top, clear of the combat buttons
export type Target = { top: number, low: number, across: boolean }
function TalkRules.cardAtTop(top: number, height: number, pawRoom: number, target: Target?, forceTop: boolean): boolean
	if forceTop or not target or not target.across then
		return true
	end
	local covered = target.low > top and target.top - pawRoom < top + height
	return not covered
end

-- A line with the game's name in it ("{game}")
function TalkRules.fill(text: string, gameName: string): string
	return (string.gsub(text, "{game}", function()
		return gameName
	end))
end

return TalkRules
