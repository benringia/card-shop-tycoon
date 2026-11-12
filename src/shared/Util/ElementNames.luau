--!strict
-- An element's name as players read it (Config/ElementNames: Ember reads "Fire"...). Pure, Lune-tested.
local ElementNames = {}

-- The plain name for an internal key; an unknown key reads back as given, none as ""
function ElementNames.display(key: string?, cfg: any): string
	if key == nil then
		return ""
	end
	local name = cfg[key]
	return if typeof(name) == "string" then name else key
end

-- The internal keys in the wheel's order
function ElementNames.all(cfg: any): { string }
	return table.clone(cfg.ORDER)
end

return ElementNames
