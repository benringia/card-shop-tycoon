--!strict
-- VIP's chat tag (spec 2026-11-28-robux-round-design; Config/Vip): a gold bold [VIP] in front of a chat line's prefix,
-- once (TextChatService may run its callback for a message more than once). Pure; tested in tests/VipRules.
local VipRules = {}

function VipRules.chatPrefix(prefix: string, cfg: any): string
	local tag = `<font color="{cfg.CHAT.color}"><b>{cfg.CHAT.tag}</b></font> `
	if string.sub(prefix, 1, #tag) == tag then
		return prefix
	end
	return tag .. prefix
end

return VipRules
