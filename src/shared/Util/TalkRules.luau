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

-- A box on screen (px): the talk card, its Skip pill, what Pish points at, his paw's room
export type Box = { x: number, y: number, w: number, h: number }
-- A place the card can stand: its name and the boxes it fills there (the card, and Skip's tap area while it shows)
export type Spot = { name: string, boxes: { Box } }

-- The area two boxes share (0 when apart; touching edges share none)
function TalkRules.overlap(a: Box, b: Box): number
	local w = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x)
	local h = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y)
	return if w > 0 and h > 0 then w * h else 0
end

-- The room Pish's paw bounces in over a button: `room` px square over its middle, its bottom on the button's top
function TalkRules.pawBox(target: Box, room: number): Box
	return { x = target.x + target.w / 2 - room / 2, y = target.y - room, w = room, h = room }
end

local function covered(spot: Spot, box: Box): number
	local area = 0
	for _, part in spot.boxes do
		area += TalkRules.overlap(part, box)
	end
	return area
end

-- Where Pish's talk card stands (the owner 2026-11-11: at the top centre "so that pish model can be seen";
-- 2026-11-25, look A: never on what he points at, seen covering the Bag and the rack's $100 on a phone): the first of
-- `spots` (top, then bottom) leaving both the target (what the ring goes round) and the paw's room clear; else the
-- first leaving the target clear (the paw may touch the card); else the one covering least of the target
function TalkRules.pickSpot(spots: { Spot }, target: Box?, paw: Box?): string
	if not target then
		return spots[1].name
	end
	for _, spot in spots do
		if covered(spot, target) == 0 and (not paw or covered(spot, paw) == 0) then
			return spot.name
		end
	end
	for _, spot in spots do
		if covered(spot, target) == 0 then
			return spot.name
		end
	end
	local best, least = spots[1].name, math.huge
	for _, spot in spots do
		local area = covered(spot, target)
		if area < least then
			best, least = spot.name, area
		end
	end
	return best
end

-- Where the card goes: "side" while you man the register in first person (seen 2026-11-20 on Pish's first sale: the
-- register's screen is at the top centre and its cash drawer at the bottom, and the card lay on the amount to give
-- back: at the left edge, half way down); "top" in a fight (`forceTop`: clear of the combat buttons); else pickSpot
function TalkRules.cardPlace(spots: { Spot }, target: Box?, paw: Box?, forceTop: boolean, manning: boolean): string
	if manning and not forceTop then
		return "side"
	end
	if forceTop then
		return "top"
	end
	return TalkRules.pickSpot(spots, target, paw)
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
