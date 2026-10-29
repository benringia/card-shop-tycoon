--!strict
-- Tags and bubbles drawn on top of everything (customer moods, pet name tags) would show over a stage scene (the 3D
-- binder, the card view): while any key is held they're switched off, and back on when the last key lets go.
-- Reference-counted by key, so the card view opening from the binder doesn't bring them back early.
local WorldTags = {}

local held: { [string]: boolean } = {}
local hidden: { [BillboardGui]: boolean } = {}
local watch: RBXScriptConnection? = nil

local function hideTag(item: Instance)
	if item:IsA("BillboardGui") and item.AlwaysOnTop and item.Enabled then
		hidden[item] = true
		item.Enabled = false
	end
end

function WorldTags.hide(key: string)
	local first = next(held) == nil
	held[key] = true
	if not first then
		return
	end
	for _, item in workspace:GetDescendants() do
		hideTag(item)
	end
	watch = workspace.DescendantAdded:Connect(hideTag)
end

function WorldTags.show(key: string)
	if not held[key] then
		return
	end
	held[key] = nil
	if next(held) ~= nil then
		return
	end
	if watch then
		watch:Disconnect()
		watch = nil
	end
	for tag in hidden do
		if tag.Parent then
			tag.Enabled = true
		end
	end
	table.clear(hidden)
end

return WorldTags
