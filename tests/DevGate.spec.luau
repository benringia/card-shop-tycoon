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

return {
	["DevService does nothing outside Studio: its first lines leave"] = function()
		local start = opening(read("src/server/Services/DevService.luau"), "DevService.Start")
		expect.equal(start, "if not RunService:IsStudio() then return end")
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

	["the admin panel is only built in Studio"] = function()
		local start = opening(read("src/client/Controllers/AdminPanelController.luau"), "AdminPanelController.Start")
		expect.equal(start, "if not RunService:IsStudio() then return end")
		local preview = read("src/client/Controllers/MovePreviewController.luau")
		assert(string.find(preview, "if not RunService:IsStudio() then", 1, true), "the effect previews too")
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
