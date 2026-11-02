--!strict
-- The boss-fight HUD (spec 2026-11-02-you-in-the-fight-design): your HP and your creature's top-left, and the
-- controls in "anime slash" panels (Config/CombatHud) placed by UiLayout.combatButtons: Attack, Dodge, sword Skill,
-- Pet skill (and the creature's Signature when it has one), Swap (pops out your rested cards when there's more than
-- one) and Run. Each button drains top-down while it cools down, with the seconds left. BattleController builds one
-- per boss fight and feeds it the fight's snapshots; SwordController reports the sword's own cooldowns.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatHudConfig = require(Shared:WaitForChild("Config"):WaitForChild("CombatHud"))
local UIIcons = require(Shared:WaitForChild("Config"):WaitForChild("UIIcons"))
local UiLayout = require(Shared:WaitForChild("Util"):WaitForChild("UiLayout"))
local UIKit = require((script.Parent :: Instance):WaitForChild("UIKit"))

local CombatHud = {}

export type Reserve = { id: string, name: string, hp: number, maxHp: number }
export type View = {
	playerHp: number,
	playerMax: number,
	down: boolean,
	out: boolean,
	creatureName: string,
	creatureHp: number,
	creatureMax: number,
	hasSignature: boolean,
	reserves: { Reserve },
}
export type Callbacks = {
	attack: () -> (),
	dodge: () -> (),
	skill: () -> (),
	pet: () -> (),
	signature: () -> (),
	swap: (id: string) -> (),
	run: () -> (),
}
export type Hud = {
	update: (view: View) -> (),
	setCooldown: (name: string, readyAt: number, total: number) -> (),
	setVisible: (visible: boolean) -> (),
	destroy: () -> (),
}

type Button = { frame: ImageButton, drain: Frame, shade: ImageLabel, seconds: TextLabel, readyAt: number, total: number }

local BUTTON_ORDER = { "attack", "dodge", "skill", "pet", "signature", "swap", "run" }

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- A slanted panel: a dark face shading into the button's colour at its far corner, neon edges, the icon, a cooldown
-- drain with its seconds, and (PC) its key on a chip
local function makeButton(parent: Instance, name: string, onPress: () -> ()): Button
	local spec = CombatHudConfig.BUTTONS[name]
	local tint = color(spec.color)
	local panel = color(CombatHudConfig.PANEL_COLOR)
	local frame = Instance.new("ImageButton")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Image = CombatHudConfig.SLANT_FILL
	frame.ImageTransparency = CombatHudConfig.PANEL_TRANSPARENCY
	frame.AutoButtonColor = false
	frame.Parent = parent
	local sheen = Instance.new("UIGradient")
	sheen.Rotation = 35
	sheen.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, panel),
		ColorSequenceKeypoint.new(0.55, panel),
		ColorSequenceKeypoint.new(1, panel:Lerp(tint, 0.45)),
	})
	sheen.Parent = frame
	local edge = Instance.new("ImageLabel")
	edge.Name = "Edge"
	edge.BackgroundTransparency = 1
	edge.Image = CombatHudConfig.SLANT_EDGE
	edge.ImageColor3 = tint
	edge.Size = UDim2.fromScale(1, 1)
	edge.ZIndex = 2
	edge.Parent = frame
	-- Its drawn icon (white line art, tinted a touch toward the button's colour), or its emoji if there's none
	local image = UIIcons[spec.icon]
	local icon: GuiObject
	if image then
		local picture = Instance.new("ImageLabel")
		picture.Image = image
		picture.ImageColor3 = Color3.new(1, 1, 1):Lerp(tint, 0.25)
		picture.ScaleType = Enum.ScaleType.Fit
		icon = picture
	else
		local text = Instance.new("TextLabel")
		text.Text = spec.emoji
		text.TextScaled = true
		icon = text
	end
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(0.5, 0.5)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.ZIndex = 3
	icon.Parent = frame
	-- The cooldown: a dark copy of the panel shown down to the share still cooling
	local drain = Instance.new("Frame")
	drain.Name = "Drain"
	drain.BackgroundTransparency = 1
	drain.ClipsDescendants = true
	drain.Size = UDim2.fromScale(1, 0)
	drain.ZIndex = 4
	drain.Parent = frame
	local shade = Instance.new("ImageLabel")
	shade.BackgroundTransparency = 1
	shade.Image = CombatHudConfig.SLANT_FILL
	shade.ImageColor3 = Color3.new(0, 0, 0)
	shade.ImageTransparency = CombatHudConfig.COOLDOWN_SHADE
	shade.ZIndex = 4
	shade.Parent = drain
	local seconds = UIKit.label(frame, "", Enum.Font.FredokaOne, UIKit.textSize("number"), Color3.new(1, 1, 1))
	seconds.Name = "Seconds"
	seconds.TextXAlignment = Enum.TextXAlignment.Center
	seconds.Size = UDim2.fromScale(1, 1)
	seconds.ZIndex = 5
	UIKit.outlined(seconds)
	if spec.key and not UIKit.isPhone() then
		local chip = UIKit.label(frame, spec.key, Enum.Font.GothamBold, 11, Color3.new(1, 1, 1))
		chip.Name = "Key"
		chip.TextXAlignment = Enum.TextXAlignment.Center
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.Size = UDim2.fromOffset(18, 16)
		chip.AnchorPoint = Vector2.new(1, 1)
		chip.Position = UDim2.new(0.82, 0, 1, -2)
		chip.BackgroundColor3 = Color3.new(0, 0, 0)
		chip.BackgroundTransparency = 0.3
		chip.ZIndex = 6
		UIKit.corner(chip, 4)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
		pad.Parent = chip
	end
	frame.Activated:Connect(onPress)
	return { frame = frame, drain = drain, shade = shade, seconds = seconds, readyAt = 0, total = 1 }
end

-- One HP line: a label over a bar
local function statusRow(parent: Instance, order: number, fill: Color3): (TextLabel, Frame)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 34)
	row.LayoutOrder = order
	row.Parent = parent
	local label = UIKit.label(row, "", Enum.Font.GothamBold, UIKit.textSize("small"), Color3.new(1, 1, 1))
	label.Size = UDim2.new(1, 0, 0, 16)
	UIKit.outlined(label)
	local track, inside = UIKit.bar(row, 1, fill)
	track.Position = UDim2.fromOffset(0, 18)
	return label, inside
end

function CombatHud.new(parent: ScreenGui, callbacks: Callbacks): Hud
	local root = Instance.new("Frame")
	root.Name = "CombatHud"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = parent

	local status = Instance.new("Frame")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(12, 8)
	status.Size = UDim2.new(CombatHudConfig.STATUS_WIDTH, 0, 0, 76)
	status.Parent = root
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(CombatHudConfig.STATUS_MAX_WIDTH, 120)
	limit.Parent = status
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = status
	local playerLabel, playerFill = statusRow(status, 1, color(CombatHudConfig.PLAYER_HP_COLOR))
	local creatureLabel, creatureFill = statusRow(status, 2, color(CombatHudConfig.CREATURE_HP_COLOR))

	local latest: View? = nil
	local picker: Frame? = nil
	local function closePicker()
		if picker then
			picker:Destroy()
			picker = nil
		end
	end

	local buttons: { [string]: Button } = {}
	local function onSwap()
		local view = latest
		if not view or #view.reserves == 0 then
			return
		end
		if #view.reserves == 1 then
			callbacks.swap(view.reserves[1].id)
			return
		end
		if picker then
			closePicker()
			return
		end
		-- More than one rested card: pick one, a column of small buttons over Swap
		local anchor = buttons.swap.frame
		local column = Instance.new("Frame")
		column.Name = "SwapPicker"
		column.BackgroundTransparency = 1
		column.AnchorPoint = Vector2.new(0, 1)
		column.Position = UDim2.fromOffset(anchor.AbsolutePosition.X - root.AbsolutePosition.X, anchor.AbsolutePosition.Y - root.AbsolutePosition.Y - 8)
		column.Size = UDim2.fromOffset(170, #view.reserves * 56)
		column.Parent = root
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 6)
		list.Parent = column
		for _, reserve in view.reserves do
			local label = if reserve.maxHp > 0 then `{reserve.name} · {math.round(reserve.hp / reserve.maxHp * 100)}%` else reserve.name
			local pick = UIKit.button(column, label, UIKit.Colors.Secondary)
			pick.Size = UDim2.new(1, 0, 0, 50)
			pick.TextSize = 16
			pick.Activated:Connect(function()
				closePicker()
				callbacks.swap(reserve.id)
			end)
		end
		picker = column
	end

	local presses: { [string]: () -> () } = {
		attack = callbacks.attack,
		dodge = callbacks.dodge,
		skill = callbacks.skill,
		pet = callbacks.pet,
		signature = callbacks.signature,
		swap = onSwap,
		run = callbacks.run,
	}
	for _, name in BUTTON_ORDER do
		buttons[name] = makeButton(root, name, presses[name])
	end

	-- Laid out in the HUD's own frame (the screen below Roblox's top bar), so nothing hangs off its bottom
	local function relayout()
		local size = root.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local rects = UiLayout.combatButtons({ w = size.X, h = size.Y }) :: any
		for name, button in buttons do
			local r = rects[name]
			button.frame.Position = UDim2.fromOffset(r.x, r.y)
			button.frame.Size = UDim2.fromOffset(r.w, r.h)
			button.shade.Size = UDim2.fromOffset(r.w, r.h)
		end
	end
	relayout()
	local resized: RBXScriptConnection? = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)

	local function setCooldown(name: string, readyAt: number, total: number)
		local button = buttons[name]
		if button then
			button.readyAt, button.total = readyAt, math.max(total, 0.01)
		end
	end

	local ticker = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, button in buttons do
			local left = button.readyAt - now
			local share = math.clamp(left / button.total, 0, 1)
			button.drain.Size = UDim2.fromScale(1, share)
			button.seconds.Text = if left > 0.05 then tostring(math.ceil(left)) else ""
		end
	end)

	local function update(view: View)
		latest = view
		local beaten = view.down or view.out
		playerLabel.Text = if view.out then "You · OUT (watching)" elseif view.down then "You · DOWN" else `You · {math.round(view.playerHp)} / {view.playerMax}`
		playerLabel.TextColor3 = if beaten then color(CombatHudConfig.DOWN_COLOR) else Color3.new(1, 1, 1)
		playerFill.Size = UDim2.fromScale(if view.playerMax > 0 then math.clamp(view.playerHp / view.playerMax, 0, 1) else 0, 1)
		creatureLabel.Text = `{view.creatureName} · {math.round(view.creatureHp)} / {math.round(view.creatureMax)}`
		creatureFill.Size = UDim2.fromScale(if view.creatureMax > 0 then math.clamp(view.creatureHp / view.creatureMax, 0, 1) else 0, 1)
		buttons.signature.frame.Visible = view.hasSignature
		for _, name in { "attack", "dodge", "skill" } do
			buttons[name].frame.ImageTransparency = if beaten then 0.6 else CombatHudConfig.PANEL_TRANSPARENCY
		end
		if #view.reserves == 0 then
			closePicker()
		end
	end

	local function destroy()
		ticker:Disconnect()
		if resized then
			resized:Disconnect()
		end
		root:Destroy()
	end

	local function setVisible(visible: boolean)
		root.Visible = visible
		if not visible then
			closePicker()
		end
	end

	return { update = update, setCooldown = setCooldown, setVisible = setVisible, destroy = destroy }
end

return CombatHud
