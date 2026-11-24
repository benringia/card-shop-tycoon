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

-- Where the card goes: "top", "bottom" (cardAtTop), or "side" while you man the register in first person (seen
-- 2026-11-20 on Pish's first sale: the register's screen is at the top centre and its cash drawer at the bottom, and
-- the card lay on the amount to give back): at the left edge, half way down
function TalkRules.cardPlace(top: number, height: number, pawRoom: number, target: Target?, forceTop: boolean, manning: boolean): string
	if manning and not forceTop then
		return "side"
	end
	return if TalkRules.cardAtTop(top, height, pawRoom, target, forceTop) then "top" else "bottom"
end

-- How long a typed line stays before its Next presses itself (Config/PishTalk AUTO_NEXT; owner 2026-11-20: "people
-- hardly press next on tutorial"): longer for a longer line
function TalkRules.readSeconds(letters: number, cfg: { base: number, perLetter: number, min: number, max: number }): number
	return math.clamp(cfg.base + letters * cfg.perLetter, cfg.min, cfg.max)
end

-- Whether the card's button presses itself: only a plain Next (`label` is what the button says, nil: no button).
-- Got it!, Bye! and Go! send someone off and wait for the player
function TalkRules.pressesItself(label: string?, nextLabel: string, buttonOnly: boolean): boolean
	return label == nextLabel and not buttonOnly
end

-- How much bigger the card draws (Config/PishTalk CARD): on a computer DESKTOP times the HUD's own growth
-- (`hudGrow`, Config/HudGrow), on a touch screen as designed
function TalkRules.cardGrow(touch: boolean, hudGrow: number, cfg: { DESKTOP: number }): number
	return if touch then 1 else hudGrow * cfg.DESKTOP
end

-- The gold edge's transparency `elapsed` s after a new line (Config/PishTalk CARD.GLOW): full gold at once, `beats`
-- flashes fading out over `seconds`, then gone (1)
function TalkRules.glow(elapsed: number, cfg: { seconds: number, beats: number }): number
	if elapsed >= cfg.seconds then
		return 1
	end
	local share = math.max(0, elapsed) / cfg.seconds
	local bright = math.abs(math.cos(math.pi * cfg.beats * share)) * (1 - share)
	return math.clamp(1 - bright, 0, 1)
end

-- Whether a talk's request (its last Next, Got it!) may go to the server now: the first time, and again `seconds`
-- after one that got no answer (Config/Chikin RESEND_SECONDS); never in a burst
function TalkRules.maySend(sentAt: number, now: number, seconds: number): boolean
	return now - sentAt >= seconds
end

-- A line with the game's name in it ("{game}")
function TalkRules.fill(text: string, gameName: string): string
	return (string.gsub(text, "{game}", function()
		return gameName
	end))
end

-- A line with the product a customer missed in place of "{product}" ("That customer wanted Card Sleeves!")
function TalkRules.product(text: string, name: string): string
	return (string.gsub(text, "{product}", function()
		return name
	end))
end

return TalkRules
