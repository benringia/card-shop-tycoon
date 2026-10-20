--!strict
-- Save data migrations. MIGRATIONS[n] upgrades a profile from version n to n + 1.
-- Pure (no requires, no Roblox APIs) so tests/ can run it in Lune. DataService calls run().
local Migrations = {}

local function lowerStars(entry: any)
	if typeof(entry) == "table" and typeof(entry.stars) == "number" then
		entry.stars = math.max(0, entry.stars - 1)
	end
end

local MIGRATIONS: { [number]: (data: any) -> () } = {
	-- v2: displayed cards live on each saved shelf; the old top-level showcase list was never used
	[1] = function(data)
		data.showcase = nil
	end,
	-- v3: levelled cards live in their own table; existing cards are plain stacks already
	[2] = function(data)
		data.beasts = data.beasts or {}
	end,
	-- v4: stars now run 0-5 instead of 1-5, so every saved star count drops by one
	[3] = function(data)
		if typeof(data.beasts) == "table" then
			for _, beast in data.beasts do
				lowerStars(beast)
			end
		end
		if typeof(data.layout) == "table" then
			for _, shelf in data.layout do
				if typeof(shelf) == "table" and typeof(shelf.cards) == "table" then
					for _, card in shelf.cards do
						lowerStars(card)
					end
				end
			end
		end
	end,
}

function Migrations.run(data: any, targetVersion: number)
	local version = if typeof(data.version) == "number" then data.version else 1
	while version < targetVersion do
		local step = MIGRATIONS[version]
		if step then
			step(data)
		end
		version += 1
	end
	data.version = targetVersion
end

return Migrations
