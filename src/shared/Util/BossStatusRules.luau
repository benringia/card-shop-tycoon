--!strict
-- A boss's states under its HP bar (Config/BossStatus; BattleSim.statusesOf; BattleController draws the chips): their
-- order, the number on each chip and each tooltip's words. Pure, Lune-tested.
local BossStatusRules = {}

export type Status = { kind: string, value: number?, seconds: number? }

-- The statuses in the row's order; kinds the config doesn't know are left out
function BossStatusRules.sorted(list: { Status }?, cfg: any): { Status }
	local row = {}
	for _, status in list or {} do
		if cfg.KINDS[status.kind] then
			table.insert(row, status)
		end
	end
	table.sort(row, function(a, b)
		return (table.find(cfg.ORDER, a.kind) or math.huge) < (table.find(cfg.ORDER, b.kind) or math.huge)
	end)
	return row
end

-- What the row shows (it's rebuilt when this changes)
function BossStatusRules.key(row: { Status }): string
	local kinds = {}
	for _, status in row do
		table.insert(kinds, status.kind)
	end
	return table.concat(kinds, ",")
end

-- The small number on a chip: seconds left, a shield's size, or a percentage
function BossStatusRules.badge(status: Status): string
	if status.seconds then
		return `{math.ceil(status.seconds)}s`
	end
	local value = status.value
	if not value then
		return ""
	end
	if status.kind == "shield" then
		return if value >= 1000 then `{math.floor(value / 100) / 10}k` else tostring(value)
	elseif status.kind == "guarded" then
		return `-{value}%`
	end
	return `+{value}%`
end

-- A tooltip: its icon and name, and what it does with its numbers (its plain words when one is missing)
function BossStatusRules.text(status: Status, cfg: any): (string, string)
	local look = cfg.KINDS[status.kind]
	local title = `{look.icon} {look.name}`
	local about = look.about
	if string.find(about, "{value}", 1, true) then
		if not status.value then
			return title, look.plain
		end
		about = string.gsub(about, "{value}", tostring(status.value))
	end
	if string.find(about, "{seconds}", 1, true) then
		if not status.seconds then
			return title, look.plain
		end
		about = string.gsub(about, "{seconds}", tostring(math.ceil(status.seconds)))
	end
	return title, about
end

return BossStatusRules
