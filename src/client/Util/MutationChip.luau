--!strict
-- The weapon in hand's mutation, shown (owner 2026-11-27: "add a small chip somewhere indicating that a mutation is
-- active", picks B and C; Config/Mutations CHIP): a chip right after your HP words in a fight (CombatHud) that opens into
-- its words on hover or after a tap, and a mark on the weapon dial's medallion (WeaponSwitchController). Both read the
-- character's SwordMutationId and SwordMutation attributes (WeaponService.ApplyAttributes) through MutationRules.chip,
-- so a weapon switch or a new mutation shows at once.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Mutations = require(Config:WaitForChild("Mutations"))
local Rarities = require(Config:WaitForChild("Rarities"))
local UIIcons = require(Config:WaitForChild("UIIcons"))
local MutationRules = require(Shared:WaitForChild("Util"):WaitForChild("MutationRules"))

local MutationChip = {}

type Shown = { name: string, open: string, icon: string, rarity: string }

local LOOK = Mutations.CHIP
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local function corner(parent: Instance, radius: number)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, radius)
	round.Parent = parent
end

-- The weapon in hand's mutation now, or nil
local function now(): Shown?
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end
	return MutationRules.chip(Mutations, character:GetAttribute("SwordMutationId"), character:GetAttribute("SwordMutation"))
end

local function rarityColor(rarity: string): Color3
	local entry = Rarities.Tiers[rarity]
	return if entry then entry.color else WHITE
end

-- Calls `changed` whenever the weapon in hand's mutation may have changed (a switch, a new mutation, a respawn)
local function watch(changed: () -> ())
	local function hook(character: Model)
		character:GetAttributeChangedSignal("SwordMutationId"):Connect(changed)
		character:GetAttributeChangedSignal("SwordMutation"):Connect(changed)
		changed()
	end
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(hook)
	if player.Character then
		hook(player.Character)
	end
end

-- B: the chip after your HP words (`label`, its row's top line). `setAllowed(false)` hides it (a wild fight before the
-- sword shows the creature on that line)
function MutationChip.onLine(label: TextLabel): { setAllowed: (allowed: boolean) -> () }
	local row = label.Parent :: Instance
	local chip = Instance.new("TextButton")
	chip.Name = "MutationChip"
	chip.Text = ""
	chip.AutoButtonColor = false
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, LOOK.height)
	chip.Visible = false
	chip.ZIndex = label.ZIndex + 1
	corner(chip, LOOK.height // 2)
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Thickness = 1.5
	edge.Parent = chip
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 5), UDim.new(0, 7)
	pad.Parent = chip
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 3)
	list.Parent = chip
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(LOOK.icon, LOOK.icon)
	icon.LayoutOrder = 1
	icon.ZIndex = chip.ZIndex
	icon.Parent = chip
	local words = Instance.new("TextLabel")
	words.BackgroundTransparency = 1
	words.AutomaticSize = Enum.AutomaticSize.X
	words.Size = UDim2.fromOffset(0, LOOK.height)
	words.Font = Enum.Font.FredokaOne
	words.TextSize = LOOK.height - 5
	words.TextWrapped = false
	words.LayoutOrder = 2
	words.ZIndex = chip.ZIndex
	words.Parent = chip
	chip.Parent = row

	local allowed, hover, openUntil = true, false, 0
	local shown: Shown? = nil
	local function place()
		chip.Position = UDim2.fromOffset(label.TextBounds.X + LOOK.gap, (label.AbsoluteSize.Y - LOOK.height) / 2)
	end
	local function draw()
		shown = now()
		local mutation = shown
		chip.Visible = allowed and mutation ~= nil
		if not mutation then
			return
		end
		local tint = rarityColor(mutation.rarity)
		chip.BackgroundColor3 = tint:Lerp(WHITE, LOOK.fillToWhite)
		edge.Color = tint
		icon.Image = (UIIcons :: any)[mutation.icon] or ""
		icon.ImageColor3 = tint:Lerp(BLACK, LOOK.inkToBlack * 0.5)
		words.TextColor3 = tint:Lerp(BLACK, LOOK.inkToBlack)
		words.Text = if hover or os.clock() < openUntil then mutation.open else mutation.name
		place()
	end
	label:GetPropertyChangedSignal("TextBounds"):Connect(place)
	chip.MouseEnter:Connect(function()
		hover = true
		draw()
	end)
	chip.MouseLeave:Connect(function()
		hover = false
		draw()
	end)
	chip.Activated:Connect(function()
		openUntil = os.clock() + LOOK.openSeconds
		draw()
		task.delay(LOOK.openSeconds + 0.05, function()
			if chip.Parent then
				draw()
			end
		end)
	end)
	watch(draw)
	return {
		setAllowed = function(isAllowed: boolean)
			if allowed ~= isAllowed then
				allowed = isAllowed
				draw()
			end
		end,
	}
end

-- C: a mark on the weapon dial's medallion: a circle in the rarity's colour with its group's icon, past its top-left
-- corner; hidden without a mutation
function MutationChip.onDial(medallion: GuiObject)
	local spec = LOOK.mark
	local mark = Instance.new("Frame")
	mark.Name = "MutationMark"
	mark.Size = UDim2.fromOffset(spec.size, spec.size)
	mark.Position = UDim2.fromOffset(spec.offset, spec.offset)
	mark.Visible = false
	mark.ZIndex = medallion.ZIndex + 3
	corner(mark, spec.size // 2)
	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Color = WHITE
	ring.Thickness = 2
	ring.Parent = mark
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(spec.icon, spec.icon)
	icon.ImageColor3 = WHITE
	icon.ZIndex = mark.ZIndex + 1
	icon.Parent = mark
	mark.Parent = medallion
	watch(function()
		local mutation = now()
		mark.Visible = mutation ~= nil
		if mutation then
			mark.BackgroundColor3 = rarityColor(mutation.rarity)
			icon.Image = (UIIcons :: any)[mutation.icon] or ""
		end
	end)
end

return MutationChip
