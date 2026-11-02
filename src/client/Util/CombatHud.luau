--!strict
-- The boss-fight HUD (spec 2026-11-02-you-in-the-fight-design): top-left your headshot in a ring (your creature's
-- card on a badge) beside your HP and your creature's in slanted neon bars (Util/HpBar), and the
-- controls in "anime slash" panels (Config/CombatHud) placed by UiLayout.combatButtons: Attack, Dodge, sword Skill,
-- Pet skill (and the creature's Signature when it has one), Swap (pops out your rested cards when there's more than
-- one) and Run. Each button drains top-down while it cools down, with the seconds left. BattleController builds one
-- per boss fight and feeds it the fight's snapshots; SwordController reports the sword's own cooldowns. When you're
-- hit the portrait shakes with a red ring and the screen's edges flash red (pulsing below 30% HP: Util/HpBarRules).
-- Wild monster fights use the same HUD without the sword (owner 2026-11-03, `wild`): your creature in the ring with its
-- HP (a called-in one's under it), the Pet button big where Attack was, Call in (the Swap button, while the call-in
-- window is open) and Run with its chance (UiLayout.wildButtons).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatHudConfig = require(Shared:WaitForChild("Config"):WaitForChild("CombatHud"))
local UIIcons = require(Shared:WaitForChild("Config"):WaitForChild("UIIcons"))
local HpBarRules = require(Shared:WaitForChild("Util"):WaitForChild("HpBarRules"))
local UiLayout = require(Shared:WaitForChild("Util"):WaitForChild("UiLayout"))
local HpBar = require((script.Parent :: Instance):WaitForChild("HpBar"))
local UIKit = require((script.Parent :: Instance):WaitForChild("UIKit"))

local CombatHud = {}

export type Reserve = { id: string, name: string, hp: number, maxHp: number, art: string? }
export type View = {
	playerHp: number,
	playerMax: number,
	down: boolean,
	out: boolean,
	creatureId: string,
	creatureName: string,
	creatureArt: string?, -- its card's painting, for the badge
	creatureElement: string, -- for the pet button's tooltip (Config/CombatHud PET_TIPS)
	petMove: string, -- its element ability's name ("Vine Snare"), for the pet button's name and tooltip
	signatureMove: string?, -- its signature's name, when it has one
	perkText: string?, -- its fight perk working now ("🔥 Hype: hits 23% harder"), for the chip under its bar
	perkColor: Color3?, -- its element's colour
	creatureHp: number,
	creatureMax: number,
	hasSignature: boolean,
	reserves: { Reserve },
	-- Wild fights: a called-in creature on the field too, the call-in window's seconds left, the run chance
	secondName: string?,
	secondHp: number?,
	secondMax: number?,
	callInFor: number?,
	runChance: number?,
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

type Button = { frame: ImageButton, drain: Frame, shade: ImageLabel, seconds: TextLabel, label: TextLabel, readyAt: number, total: number }

local BUTTON_ORDER = { "attack", "dodge", "skill", "pet", "signature", "swap", "run" }
local WILD_ORDER = { "pet", "signature", "swap", "run" }
local PORTRAIT_BACK = Color3.fromRGB(42, 29, 51) -- behind the headshot and the card while they load
local CHIP_POP = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- A slanted panel: a dark face shading into the button's colour at its far corner, neon edges, the icon, a cooldown
-- drain with its seconds, (PC) its key on a chip, and its name below it (placed by the HUD). Resting the mouse on it,
-- or holding a finger on it, shows its tooltip (`showTip`); a press held long enough for the tooltip doesn't act.
local function makeButton(parent: Instance, name: string, onPress: () -> (), showTip: (name: string, show: boolean) -> ()): Button
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
	local label = UIKit.label(parent, spec.name, Enum.Font.FredokaOne, 13, Color3.new(1, 1, 1):Lerp(tint, 0.55))
	label.Name = `{name}Name`
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Visible = false
	UIKit.outlined(label)

	local suppress = false -- this press showed the tooltip: don't act on it
	local holdToken, hoverToken = 0, 0
	frame.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		suppress = false
		holdToken += 1
		local token = holdToken
		task.delay(CombatHudConfig.TIP_HOLD, function()
			if holdToken == token then
				suppress = true
				showTip(name, true)
			end
		end)
	end)
	frame.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			holdToken += 1
			showTip(name, false)
		end
	end)
	frame.MouseEnter:Connect(function()
		if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
			return -- phones fire this on a tap too: their tooltip is the hold
		end
		hoverToken += 1
		local token = hoverToken
		task.delay(CombatHudConfig.TIP_HOVER, function()
			if hoverToken == token then
				showTip(name, true)
			end
		end)
	end)
	frame.MouseLeave:Connect(function()
		hoverToken += 1
		showTip(name, false)
	end)
	frame.Activated:Connect(function()
		if suppress then
			suppress = false
			return
		end
		onPress()
	end)
	return { frame = frame, drain = drain, shade = shade, seconds = seconds, label = label, readyAt = 0, total = 1 }
end

-- One HP line: a label over a slanted bar `height` pixels tall
local function statusRow(parent: Instance, order: number, height: number, look: HpBar.Look): (TextLabel, HpBar.Bar)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 18 + height)
	row.LayoutOrder = order
	row.Parent = parent
	local label = UIKit.label(row, "", Enum.Font.FredokaOne, UIKit.textSize("small"), Color3.new(1, 1, 1))
	label.Size = UDim2.new(1, 0, 0, 16)
	UIKit.outlined(label)
	local bar = HpBar.new(row, height, look, CombatHudConfig.HP_BAR.GHOST)
	bar.frame.Position = UDim2.fromOffset(0, 18)
	bar.frame.Size = UDim2.new(1, -height * CombatHudConfig.HP_BAR.SLANT, 0, height)
	return label, bar
end

local function ringColors(colors: { { number } }): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, color(colors[1])),
		ColorSequenceKeypoint.new(0.5, color(colors[2])),
		ColorSequenceKeypoint.new(1, color(colors[3])),
	})
end

-- Your headshot in a bevelled ring, your creature's card on a badge at its corner. Returns the ring (it shakes), its
-- shading, its hurt glow and the badge.
local function portrait(parent: Instance, size: number): (Frame, UIGradient, UIStroke, ImageLabel, ImageLabel)
	local spec = CombatHudConfig.PORTRAIT
	local holder = Instance.new("Frame")
	holder.Name = "Portrait"
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.new(0, 0, 0.5, -size / 2)
	holder.Size = UDim2.fromOffset(size, size)
	holder.Parent = parent
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.BackgroundColor3 = Color3.new(1, 1, 1)
	ring.Size = UDim2.fromScale(1, 1)
	ring.Parent = holder
	UIKit.corner(ring, size)
	local shading = Instance.new("UIGradient")
	shading.Rotation = 45
	shading.Color = ringColors(spec.RING_COLORS)
	shading.Parent = ring
	local glow = Instance.new("UIStroke")
	glow.Color = color(spec.HURT_COLORS[2])
	glow.Thickness = 3
	glow.Transparency = 1
	glow.Parent = ring
	local face = Instance.new("ImageLabel")
	face.Name = "Headshot"
	face.BackgroundColor3 = PORTRAIT_BACK
	face.Image = `rbxthumb://type=AvatarHeadShot&id={(Players.LocalPlayer :: Player).UserId}&w=150&h=150`
	face.Position = UDim2.fromOffset(spec.RING, spec.RING)
	face.Size = UDim2.new(1, -2 * spec.RING, 1, -2 * spec.RING)
	face.Parent = ring
	UIKit.corner(face, size)
	local badgeSize = math.round(size * spec.BADGE)
	local badge = Instance.new("ImageLabel")
	badge.Name = "CreatureBadge"
	badge.BackgroundColor3 = PORTRAIT_BACK
	badge.ScaleType = Enum.ScaleType.Crop
	badge.AnchorPoint = Vector2.new(1, 1)
	badge.Position = UDim2.new(1, math.round(badgeSize * 0.3), 1, math.round(badgeSize * 0.18))
	badge.Size = UDim2.fromOffset(badgeSize, badgeSize)
	badge.Visible = false
	badge.Parent = ring
	UIKit.corner(badge, badgeSize)
	local edge = Instance.new("UIStroke")
	edge.Color = color(CombatHudConfig.HP_BAR.CREATURE.edge)
	edge.Thickness = 2.5
	edge.Parent = badge
	return ring, shading, glow, badge, face
end

-- showNames: name the buttons (the player's first boss fights; the server decides); wild: a wild monster fight's HUD
function CombatHud.new(parent: ScreenGui, callbacks: Callbacks, showNames: boolean, wild: boolean?): Hud
	local root = Instance.new("Frame")
	root.Name = "CombatHud"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = parent

	-- The red edges: the whole screen, the top bar too (MainGui starts below it)
	local inset = GuiService:GetGuiInset()
	local vignette = Instance.new("ImageLabel")
	vignette.Name = "HitFlash"
	vignette.BackgroundTransparency = 1
	vignette.Image = CombatHudConfig.HIT_FLASH.IMAGE
	vignette.ImageColor3 = color(CombatHudConfig.HIT_FLASH.COLOR)
	vignette.ImageTransparency = 1
	vignette.Position = UDim2.fromOffset(0, -inset.Y)
	vignette.Size = UDim2.new(1, 0, 1, inset.Y)
	vignette.ZIndex = 0
	vignette.Visible = false
	vignette.Parent = root

	local portraitSize = if UIKit.isPhone() then CombatHudConfig.PORTRAIT.PHONE_SIZE else CombatHudConfig.PORTRAIT.SIZE
	local barSpec = CombatHudConfig.HP_BAR
	local status = Instance.new("Frame")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(12, 8)
	status.Size = UDim2.new(CombatHudConfig.STATUS_WIDTH, 0, 0, math.max(portraitSize, 2 * 18 + barSpec.HEIGHT + barSpec.SMALL_HEIGHT + 12 + CombatHudConfig.PERK_CHIP_HEIGHT))
	status.Parent = root
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(CombatHudConfig.STATUS_MAX_WIDTH, 120)
	limit.Parent = status
	local ring, ringShading, ringGlow, badge, face = portrait(status, portraitSize)
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(portraitSize + 16, 0)
	rows.Size = UDim2.new(1, -(portraitSize + 16), 1, 0)
	rows.Parent = status
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = rows
	local playerLabel, playerBar = statusRow(rows, 1, barSpec.HEIGHT, barSpec.PLAYER)
	local creatureLabel, creatureBar = statusRow(rows, 2, barSpec.SMALL_HEIGHT, barSpec.CREATURE)
	-- The creature's fight perk working now: a chip in its element's colour under its bar (pops in on a swap)
	local chipSize = CombatHudConfig.PERK_CHIP_HEIGHT
	local chip = UIKit.label(rows, "", Enum.Font.FredokaOne, chipSize - 8, Color3.new(1, 1, 1))
	chip.Name = "PerkChip"
	chip.LayoutOrder = 3
	chip.Size = UDim2.fromOffset(0, chipSize)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.BackgroundColor3 = color(CombatHudConfig.PANEL_COLOR)
	chip.BackgroundTransparency = 0.15
	chip.Visible = false
	UIKit.corner(chip, chipSize)
	local chipPad = Instance.new("UIPadding")
	chipPad.PaddingLeft, chipPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 9)
	chipPad.Parent = chip
	local chipEdge = Instance.new("UIStroke")
	chipEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	chipEdge.Thickness = 1.5
	chipEdge.Parent = chip
	local chipScale = Instance.new("UIScale")
	chipScale.Parent = chip
	-- A swap's toast: the new creature's perk, just under the top-left status for a moment
	local toast = UIKit.label(root, "", Enum.Font.FredokaOne, 18, Color3.new(1, 1, 1))
	toast.Name = "PerkToast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, status.Size.Y.Offset + 16) -- clear of the status on narrow phones
	toast.Size = UDim2.fromOffset(0, 34)
	toast.AutomaticSize = Enum.AutomaticSize.X
	toast.BackgroundColor3 = color(CombatHudConfig.PANEL_COLOR)
	toast.BackgroundTransparency = 0.1
	toast.Visible = false
	UIKit.corner(toast, 10)
	local toastPad = Instance.new("UIPadding")
	toastPad.PaddingLeft, toastPad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	toastPad.Parent = toast
	local toastEdge = Instance.new("UIStroke")
	toastEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	toastEdge.Thickness = 1.5
	toastEdge.Parent = toast
	local toastToken = 0
	local lastPlayerHp: number? = nil
	local creatureId: string? = nil
	local hitAt, hitPeak = -math.huge, 0
	local wasHurt = false
	local swapped = false -- the first creature isn't a swap: no toast for it

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
	-- The tooltip: the button's name in its colour, then what it does, just above the button
	local tip = Instance.new("Frame")
	tip.Name = "ButtonTip"
	tip.AnchorPoint = Vector2.new(0.5, 1)
	tip.Size = UDim2.fromOffset(CombatHudConfig.TIP_WIDTH, 0)
	tip.AutomaticSize = Enum.AutomaticSize.Y
	tip.BackgroundColor3 = color(CombatHudConfig.PANEL_COLOR)
	tip.BackgroundTransparency = 0.05
	tip.Visible = false
	tip.ZIndex = 20
	tip.Parent = root
	UIKit.corner(tip, 10)
	local tipEdge = Instance.new("UIStroke")
	tipEdge.Thickness = 2
	tipEdge.Parent = tip
	local tipPad = Instance.new("UIPadding")
	tipPad.PaddingTop, tipPad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 9)
	tipPad.PaddingLeft, tipPad.PaddingRight = UDim.new(0, 11), UDim.new(0, 11)
	tipPad.Parent = tip
	local tipList = Instance.new("UIListLayout")
	tipList.SortOrder = Enum.SortOrder.LayoutOrder
	tipList.Padding = UDim.new(0, 3)
	tipList.Parent = tip
	local tipTitle = UIKit.label(tip, "", Enum.Font.FredokaOne, 16, Color3.new(1, 1, 1))
	tipTitle.LayoutOrder = 1
	tipTitle.Size = UDim2.new(1, 0, 0, 20)
	tipTitle.ZIndex = 21
	local tipBody = UIKit.label(tip, "", Enum.Font.GothamBold, 14, Color3.new(1, 1, 1))
	tipBody.LayoutOrder = 2
	tipBody.Size = UDim2.new(1, 0, 0, 0)
	tipBody.AutomaticSize = Enum.AutomaticSize.Y
	tipBody.TextWrapped = true
	tipBody.ZIndex = 21
	local tipFor: string? = nil

	-- What a button is called right now: the pet and signature buttons are named after the creature's moves
	local function moveName(name: string): string
		local view = latest
		if name == "pet" and view then
			return view.petMove
		elseif name == "signature" and view and view.signatureMove then
			return view.signatureMove
		elseif wild and name == "swap" then
			return if view and view.callInFor then `Call in {math.max(0, math.ceil(view.callInFor))}s` else "Call in"
		elseif wild and name == "run" and view and view.runChance then
			return `Run {math.round(view.runChance * 100)}%`
		end
		return CombatHudConfig.BUTTONS[name].name
	end

	local function onTip(name: string, show: boolean)
		if not show then
			if tipFor == name then
				tip.Visible = false
				tipFor = nil
			end
			return
		end
		local spec = CombatHudConfig.BUTTONS[name]
		local anchor = buttons[name].frame
		local title = moveName(name)
		if title == spec.name then
			title = string.sub(title, 1, 1) .. string.lower(string.sub(title, 2)) -- "PET MOVE" -> "Pet move"
		end
		tipTitle.Text = title
		tipTitle.TextColor3 = color(spec.color)
		local view = latest
		tipBody.Text = if name == "pet" and view then CombatHudConfig.PET_TIPS[view.creatureElement] or spec.tip else spec.tip
		tipEdge.Color = color(spec.color)
		local half = CombatHudConfig.TIP_WIDTH / 2 + 8
		local x = anchor.AbsolutePosition.X - root.AbsolutePosition.X + anchor.AbsoluteSize.X / 2
		tip.Position = UDim2.fromOffset(math.clamp(x, half, root.AbsoluteSize.X - half), anchor.AbsolutePosition.Y - root.AbsolutePosition.Y - 8)
		tip.Visible = true
		tipFor = name
	end

	for _, name in (if wild then WILD_ORDER else BUTTON_ORDER) do
		buttons[name] = makeButton(root, name, presses[name], onTip)
	end

	-- Laid out in the HUD's own frame (the screen below Roblox's top bar), so nothing hangs off its bottom; each name
	-- just under its button
	local function relayout()
		local size = root.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local rects = (if wild then UiLayout.wildButtons({ w = size.X, h = size.Y }) else UiLayout.combatButtons({ w = size.X, h = size.Y })) :: any
		local nameSize = math.clamp(math.round((rects.attack or rects.pet).h * 0.13), 11, 16)
		for name, button in buttons do
			local r = rects[name]
			button.frame.Position = UDim2.fromOffset(r.x, r.y)
			button.frame.Size = UDim2.fromOffset(r.w, r.h)
			button.shade.Size = UDim2.fromOffset(r.w, r.h)
			button.label.Position = UDim2.fromOffset(r.x + r.w / 2, r.y + r.h + 1)
			button.label.Size = UDim2.fromOffset(0, nameSize + 2)
			button.label.TextSize = nameSize
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

	-- The red edges (a hit's flash or the low-HP pulse), the portrait's shake and its red ring
	local function feedback(now: number)
		local view = latest
		local share = if view and view.playerMax > 0 then view.playerHp / view.playerMax else 1
		local beaten = view ~= nil and (view.down or view.out)
		local alpha = HpBarRules.edgeAlpha(now, hitAt, hitPeak, share, beaten, CombatHudConfig)
		vignette.Visible = alpha > 0.005
		vignette.ImageTransparency = 1 - alpha
		local x, y = HpBarRules.shake(now, hitAt, CombatHudConfig)
		ring.Position = UDim2.fromOffset(x, y)
		local hurt = now - hitAt < CombatHudConfig.PORTRAIT.HURT_SECONDS
		if hurt ~= wasHurt then
			wasHurt = hurt
			ringShading.Color = ringColors(if hurt then CombatHudConfig.PORTRAIT.HURT_COLORS else CombatHudConfig.PORTRAIT.RING_COLORS)
			ringGlow.Transparency = if hurt then 0.1 else 1
		end
	end

	local ticker = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		feedback(now)
		for _, button in buttons do
			local left = button.readyAt - now
			local share = math.clamp(left / button.total, 0, 1)
			button.drain.Size = UDim2.fromScale(1, share)
			button.seconds.Text = if left > 0.05 then tostring(math.ceil(left)) else ""
		end
	end)

	-- Wild fights: your creature takes the top row (and the ring), a called-in one the second
	local function updateWild(view: View)
		playerLabel.Text = `{view.creatureName} · {math.round(view.creatureHp)} / {math.round(view.creatureMax)}`
		if view.creatureId ~= creatureId then
			playerBar.reset(view.creatureHp, view.creatureMax)
			face.Image = view.creatureArt or ""
		else
			playerBar.set(view.creatureHp, view.creatureMax)
		end
		local second = view.secondName ~= nil
		creatureLabel.Parent.Visible = second
		if second then
			creatureLabel.Text = `{view.secondName} · {math.round(view.secondHp or 0)} / {math.round(view.secondMax or 1)}`
			creatureBar.set(view.secondHp or 0, view.secondMax or 1)
		end
		buttons.swap.frame.Visible = (view.callInFor or 0) > 0 and #view.reserves > 0
		-- Call in shows the card it brings (the first one; more open the picker)
		local icon = buttons.swap.frame:FindFirstChild("Icon")
		local art = if view.reserves[1] then view.reserves[1].art else nil
		if icon and icon:IsA("ImageLabel") and art then
			icon.Image = art
			icon.ImageColor3 = Color3.new(1, 1, 1)
			icon.ScaleType = Enum.ScaleType.Crop
			icon.Size = UDim2.fromScale(0.72, 0.72)
		end
	end

	local function update(view: View)
		latest = view
		local beaten = view.down or view.out
		if wild then
			updateWild(view)
		else
			playerLabel.Text = if view.out then "You · OUT (watching)" elseif view.down then "You · DOWN" else `You · {math.round(view.playerHp)} / {view.playerMax}`
			playerLabel.TextColor3 = if beaten then color(CombatHudConfig.DOWN_COLOR) else Color3.new(1, 1, 1)
			if lastPlayerHp and view.playerHp < lastPlayerHp then
				hitAt = os.clock()
				hitPeak = HpBarRules.flashPeak(lastPlayerHp - view.playerHp, view.playerMax, CombatHudConfig)
			end
			lastPlayerHp = view.playerHp
			playerBar.set(view.playerHp, view.playerMax)
			creatureLabel.Text = `{view.creatureName} · {math.round(view.creatureHp)} / {math.round(view.creatureMax)}`
		end
		if view.creatureId ~= creatureId then
			-- A new creature (a swap): its own HP at once, no ghost from the last one's
			creatureId = view.creatureId
			if not wild then
				creatureBar.reset(view.creatureHp, view.creatureMax)
				badge.Image = view.creatureArt or ""
				badge.Visible = view.creatureArt ~= nil
			end
			local perkColor = view.perkColor or Color3.new(1, 1, 1)
			chip.Text = view.perkText or ""
			chip.Visible = view.perkText ~= nil
			chipEdge.Color = perkColor
			chipScale.Scale = 0.5
			TweenService:Create(chipScale, CHIP_POP, { Scale = 1 }):Play()
			if view.perkText and swapped then
				toastToken += 1
				local token = toastToken
				toast.Text = view.perkText
				toastEdge.Color = perkColor
				toast.Visible = true
				task.delay(CombatHudConfig.PERK_TOAST_SECONDS, function()
					if toastToken == token then
						toast.Visible = false
					end
				end)
			end
			swapped = true
		elseif not wild then
			creatureBar.set(view.creatureHp, view.creatureMax)
		end
		buttons.signature.frame.Visible = view.hasSignature
		for name, button in buttons do
			button.label.Text = string.upper(moveName(name))
			button.label.Visible = showNames and button.frame.Visible
		end
		if tipFor then
			onTip(tipFor, true) -- a swap renames the pet's move under an open tooltip
		end
		for _, name in { "attack", "dodge", "skill" } do
			local button = buttons[name]
			if button then
				button.frame.ImageTransparency = if beaten then 0.6 else CombatHudConfig.PANEL_TRANSPARENCY
			end
		end
		if #view.reserves == 0 then
			closePicker()
		end
	end

	local function destroy()
		ticker:Disconnect()
		playerBar.destroy()
		creatureBar.destroy()
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
