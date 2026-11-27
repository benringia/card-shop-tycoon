--!strict
-- Owner 2026-11-21 (launch day): "make sure no admin commands is effective on the live version". Every dev command
-- (the chat commands, ServerStorage.DevCommand, the admin panel's remote) is made in DevService.Start, which leaves at
-- once outside Studio; the admin panel's tile is only built in Studio; the one chat command the live game has
-- ("/slot", the owner's test save) checks on the server that the sender owns the game. This reads the source so none
-- of that can slip: a dev command registered anywhere else, or a gate moved under its first line, fails here.
local fs = require("@lune/fs")
local SaveSlots = require("../src/server/Util/SaveSlots")
local expect = require("./lib/expect")

local function read(path: string): string
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end

-- Every .luau file under `dir`
local function files(dir: string, into: { string }?): { string }
	local list = into or {}
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			files(path, list)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(list, path)
		end
	end
	return list
end

-- The first statement of `functionName`'s body in `source` (comments skipped), up to its `end`
local function opening(source: string, functionName: string): string
	local at = string.find(source, "function " .. functionName .. "(", 1, true)
	assert(at, functionName .. " exists")
	local body = string.sub(source, (string.find(source, "\n", at, true) :: number) + 1)
	local lines = {}
	for line in string.gmatch(body, "(.-)\n") do
		local trimmed = string.match(line, "^%s*(.-)%s*$") :: string
		if trimmed ~= "" and string.sub(trimmed, 1, 2) ~= "--" then
			table.insert(lines, (string.gsub(trimmed, "%s*%-%-.*$", "")))
			if #lines == 3 then
				break
			end
		end
	end
	return table.concat(lines, " ")
end

-- The text of a top-level `local function name(` up to its closing `end`
local function body(source: string, functionName: string): string
	local at = string.find(source, "local function " .. functionName .. "(", 1, true)
	assert(at, functionName .. " exists")
	local stop = string.find(source, "\nend\n", at, true)
	assert(stop, functionName .. " ends")
	return string.sub(source, at, stop)
end

-- The dev functions other services hold, each behind DevAccess (spec 2026-11-27-live-admin-creator-design)
local GATED = {
	{ "BattleService", "BattleService.SetBossHpShare" },
	{ "BossService", "BossService.DevSetBeaten" },
	{ "BossService", "BossService.DevSetLootIn" },
	{ "DecorService", "DecorService.SetLookForDev" },
	{ "EventService", "EventService.Dev" },
	{ "MainQuestService", "MainQuestService.Dev" },
	{ "PlacementService", "PlacementService.DevPlace" },
	{ "RoomService", "RoomService.DevSet" },
	{ "WindowService", "WindowService.DevPlace" },
	{ "WildService", "WildService.SetPhantomPlayers" },
	{ "DungeonPuzzleService", "DungeonPuzzleService.Solve" },
	{ "DungeonPuzzleService", "DungeonPuzzleService.Tap" },
	{ "DungeonService", "DungeonService.WinRoom" },
	{ "DungeonService", "DungeonService.SolvePuzzle" },
	{ "DungeonService", "DungeonService.TapGate" },
	{ "DungeonService", "DungeonService.SkipToPuzzle" },
	{ "DungeonService", "DungeonService.SkipTo" },
	-- the Footage setup's helpers (DevService /footage)
	{ "PartyService", "PartyService.SetSlotsForTesting" },
	{ "TutorialService", "TutorialService.SkipForTesting" },
	{ "CombatTutorialService", "CombatTutorialService.SkipForTesting" },
}

return {
	-- Owner 2026-11-27: "proper admin UI I can publish that only I can use" (pick A: the test save only). The live
	-- game has no dev chat commands and no DevCommand; the panel's remote runs a command only after DevAccess said yes
	["chat commands and the DevCommand bindable are made only in Studio"] = function()
		local source = read("src/server/Services/DevService.luau")
		assert(string.find(source, "local folder: Instance? = if RunService:IsStudio() then", 1, true), "no chat folder live")
		assert(string.find(opening(source, "addCommand"), "if not folder then return", 1, true), "addCommand makes no chat command live")
		expect.equal(opening(source, "makeStudioRunner"), "if not RunService:IsStudio() then return end")
	end,

	["the panel's remote asks DevAccess before it runs anything"] = function()
		local source = read("src/server/Services/DevService.luau")
		local handler = body(source, "onPanel")
		local checked = string.find(handler, "DevAccess.check(", 1, true)
		local ran = string.find(handler, "run(player", 1, true)
		assert(checked and ran and checked < ran, "DevAccess.check before run")
		assert(string.find(source, "Remotes.DevPanel.OnServerEvent:Connect(onPanel)", 1, true), "the remote goes through onPanel")
	end,

	["only the game's owner gets the Admin mark"] = function()
		local source = read("src/server/Services/DevService.luau")
		assert(string.find(opening(source, "markAdmin"), "SaveSlots.isOwner(player.UserId, game.CreatorId, game.CreatorType.Name)", 1, true), "owner checked first")
	end,

	["DevAccess fails closed: the owner from the game's creator, the test save from the server's own mark"] = function()
		local source = read("src/server/Util/DevAccess.luau")
		assert(string.find(source, "SaveSlots.isOwner(player.UserId, game.CreatorId, game.CreatorType.Name)", 1, true), "owner")
		assert(string.find(source, 'GetAttribute("TestSave") == true', 1, true), "test save")
	end,

	-- The owner's test save stays out of the analytics (funnels, custom events): its fresh runs would read as new players
	["every file that logs to analytics asks AnalyticsGate first"] = function()
		local count = 0
		for _, path in files("src/server") do
			local source = read(path)
			if string.find(source, "AnalyticsService:Log", 1, true) then
				count += 1
				assert(string.find(source, "AnalyticsGate.allowed(", 1, true), `{path} logs without AnalyticsGate`)
			end
		end
		expect.equal(count >= 5, true, "the funnel and the tutorials, Pish and Chikin")
		local gate = read("src/server/Util/AnalyticsGate.luau")
		assert(string.find(gate, 'GetAttribute("TestSave") ~= true', 1, true), "the server's own test save mark")
	end,

	["every other service's dev function asks DevAccess first, never a bare Studio check"] = function()
		for _, entry in GATED do
			local first = opening(read(`src/server/Services/{entry[1]}.luau`), entry[2])
			assert(string.find(first, "DevAccess.can(", 1, true), `{entry[2]} asks DevAccess: {first}`)
			assert(not string.find(first, "RunService:IsStudio()", 1, true), `{entry[2]} has a bare Studio check: {first}`)
		end
	end,

	["dev commands are registered nowhere else"] = function()
		for _, path in files("src/server") do
			local source = read(path)
			local name = string.match(path, "([%w_]+)%.luau$")
			if name ~= "DevService" then
				assert(not string.find(source, "Remotes.DevPanel", 1, true), `{path} handles the admin panel's remote`)
				assert(not string.find(source, '"DevCommand"', 1, true), `{path} makes a DevCommand`)
			end
			if name ~= "DevService" and name ~= "SaveSlotService" then
				assert(not string.find(source, "TextChatCommand", 1, true), `{path} registers a chat command`)
				assert(not string.find(source, ".Chatted", 1, true), `{path} listens to chat`)
			end
		end
	end,

	["nothing but DevService calls a service's dev or test function"] = function()
		for _, path in files("src/server") do
			if not string.find(path, "DevService", 1, true) then
				for line in string.gmatch(read(path), "(.-)\n") do
					local definition = string.match(line, "^function ") ~= nil
					local call = string.match(line, "%.Dev%u?%a*%(") or string.match(line, "%a+ForTest%a*%(") or string.match(line, "%a+ForDev%(")
					assert(definition or not call, `{path} calls a dev function: {line}`)
				end
			end
		end
	end,

	["the admin panel is built in Studio, or live only from the server's Admin mark"] = function()
		local source = read("src/client/Controllers/AdminPanelController.luau")
		local start = opening(source, "AdminPanelController.Start")
		expect.equal(start, 'if RunService:IsStudio() then buildPanel("🛠 Admin (Studio)") return')
		assert(string.find(source, 'GetAttribute("AdminAccess")', 1, true), "live: the tile waits for the owner's mark")
		-- the effect previews (/movefx, /superfx...) only play what the gated server sends; they never ask it for anything
		local preview = read("src/client/Controllers/MovePreviewController.luau")
		assert(not string.find(preview, "FireServer", 1, true), "the previews send nothing")
	end,

	["/slot, the one live chat command, is the game owner's alone"] = function()
		local source = read("src/server/Services/SaveSlotService.luau")
		local first = opening(source, "onCommand")
		assert(string.find(first, "if not SaveSlots.isOwner(player.UserId, game.CreatorId, game.CreatorType.Name)", 1, true) == 1, "checked first, on the server")
		expect.equal(SaveSlots.isOwner(42, 42, "User"), true, "the owner")
		expect.equal(SaveSlots.isOwner(43, 42, "User"), false, "anyone else")
		expect.equal(SaveSlots.isOwner(42, 42, "Group"), false, "a group's game: nobody")
		expect.equal(SaveSlots.isOwner(0, 0, "User"), false, "no creator id (an unpublished file)")
	end,
}
