--!strict
-- Customer chat bubbles (Config/CustomerChat; owner 2026-11-19: "add personalities for the customers like chat
-- bubbles"): which line a customer of a type says at a moment, whether they speak at all, and the model attribute the
-- server sets for the client to draw ("Say" = "<moment>|<line>|<serial>|<word>"). Pure, Lune-tested.
local ChatRules = {}

export type Said = { moment: string, index: number, word: string }

-- The lines a `kind` of customer has for `moment`: their own, else the plain customer's; nil when nobody has any
function ChatRules.lines(cfg: any, kind: string, moment: string): { string }?
	local own = cfg.LINES[kind]
	local list = if own then own[moment] else nil
	if not list or #list == 0 then
		list = cfg.LINES.plain[moment]
	end
	return if list and #list > 0 then list else nil
end

-- Which line they say (its index), nil when they stay quiet: `speakRoll` (0-1) against the moment's chance, then
-- `lineRoll` (0-1) picks the line
function ChatRules.pick(cfg: any, kind: string, moment: string, speakRoll: number, lineRoll: number): number?
	local chance = cfg.CHANCE[moment]
	local list = ChatRules.lines(cfg, kind, moment)
	if not chance or not list or speakRoll >= chance then
		return nil
	end
	return math.clamp(math.floor(lineRoll * #list) + 1, 1, #list)
end

-- The words of line `index`, its `%s` filled with `word` (a line without one ignores it); nil for a line that isn't there
function ChatRules.text(cfg: any, kind: string, moment: string, index: number, word: string?): string?
	local list = ChatRules.lines(cfg, kind, moment)
	local line = if list then list[index] else nil
	if not line then
		return nil
	end
	if string.find(line, "%s", 1, true) then
		return (string.gsub(line, "%%s", function()
			return word or ""
		end))
	end
	return line
end

-- The attribute's value. `serial` makes two of the same line in a row a change the client hears; `word` may not hold
-- the separator
function ChatRules.encode(moment: string, index: number, serial: number, word: string?): string
	return `{moment}|{index}|{serial}|{string.gsub(word or "", "|", "")}`
end

function ChatRules.decode(value: unknown): Said?
	if typeof(value) ~= "string" then
		return nil
	end
	local moment, index, _serial, word = string.match(value, "^(%a+)|(%d+)|(%d+)|(.*)$")
	local number = tonumber(index)
	if not moment or not number then
		return nil
	end
	return { moment = moment, index = number, word = word or "" }
end

return ChatRules
