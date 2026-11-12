--!strict
-- One slanted neon HP bar (Config/CombatHud HP_BAR): a glowing edge in the bar's colour, a dark rim around a sunken
-- well, the ghost of lost HP (or a heal's pale lead) behind a shaded fill, a tick every 20% and a white flash on a hit.
-- The images are 9-sliced, so the slanted ends keep their angle at any width. Util/HpBarRules times the motion; the
-- bar animates only while something moves. The combat HUD's bars and the boss bar use it.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatHudConfig = require(Shared:WaitForChild("Config"):WaitForChild("CombatHud"))
local HpBarRules = require(Shared:WaitForChild("Util"):WaitForChild("HpBarRules"))

local HpBar = {}

export type Shade = { top: { number }, bottom: { number } }
export type Look = { edge: { number }, top: { number }, bottom: { number } }
export type Bar = {
	frame: Frame, -- sized by the caller (its height should be the one passed in)
	topZIndex: number, -- for anything drawn over the bar (its numbers)
	set: (hp: number, maxHp: number) -> (),
	reset: (hp: number, maxHp: number) -> (), -- jump there with no ghost (a new creature)
	setLook: (look: Look) -> (), -- recolour the edge and fill (a monster bar turning gold for an elite)
	destroy: () -> (),
}

local CFG = CombatHudConfig.HP_BAR

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function gradient(parent: Instance, shade: Shade): UIGradient
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(color(shade.top), color(shade.bottom))
	g.Parent = parent
	return g
end

-- A 9-sliced image `width` x `height` pixels whose slanted ends (`ends` pixels each) keep their size, drawn at
-- `scale`; only its middle stretches
local function sliced(parent: Instance, image: string, ends: number, width: number, height: number, scale: number, z: number): ImageLabel
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Image = image
	label.ScaleType = Enum.ScaleType.Slice
	label.SliceCenter = Rect.new(ends, 0, width - ends, height)
	label.SliceScale = scale
	label.ZIndex = z
	label.Parent = parent
	return label
end

function HpBar.new(parent: Instance, height: number, look: Look, ghost: Shade): Bar
	local scale = height / CFG.IMAGE_HEIGHT
	local base = if parent:IsA("GuiObject") then parent.ZIndex else 1
	local frame = Instance.new("Frame")
	frame.Name = "HpBar"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.ZIndex = base
	frame.Parent = parent

	-- Image sizes (pixels, as tools/textures/make_hp_bars.py draws them)
	local imageW, imageH = 200, CFG.IMAGE_HEIGHT
	local pad, rim = CFG.EDGE_PAD, CFG.RIM
	local wellH = imageH - 2 * rim
	local edgeEnds = pad + math.ceil(CFG.SLANT * (imageH + 12)) + 3
	local backEnds = math.ceil(CFG.SLANT * imageH) + 2
	local fillEnds = math.ceil(CFG.SLANT * wellH) + 2

	local edge = sliced(frame, CFG.EDGE, edgeEnds, imageW + 2 * pad, imageH + 2 * pad, scale, base + 1)
	edge.Name = "Edge"
	edge.ImageColor3 = color(look.edge)
	edge.Position = UDim2.fromOffset(-pad * scale, -pad * scale)
	edge.Size = UDim2.new(1, 2 * pad * scale, 1, 2 * pad * scale)

	local back = sliced(frame, CFG.BACK, backEnds, imageW, imageH, scale, base + 2)
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)

	-- The well: the rim's inside, its left edge where hp_back's well starts
	local rimX = (rim + CFG.SLANT * rim * 0.5) * scale
	local well = Instance.new("Frame")
	well.Name = "Well"
	well.BackgroundTransparency = 1
	well.Position = UDim2.fromOffset(rimX, rim * scale)
	well.Size = UDim2.new(1, -2 * rimX, 1, -2 * rim * scale)
	well.ZIndex = base + 3
	well.Parent = frame

	local function fillImage(name: string, z: number): ImageLabel
		local label = sliced(well, CFG.FILL, fillEnds, imageW, wellH, scale, z)
		label.Name = name
		label.Size = UDim2.fromScale(1, 1)
		return label
	end
	local ghostImage = fillImage("Ghost", base + 3)
	local ghostShade = gradient(ghostImage, ghost)
	local fill = fillImage("Fill", base + 4)
	local fillShade = gradient(fill, look)
	-- A shine along the top of the whole well, filled or not
	local gloss = fillImage("Gloss", base + 5)
	local shine = Instance.new("UIGradient")
	shine.Rotation = 90
	shine.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, CFG.GLOSS),
		NumberSequenceKeypoint.new(0.38, 0.92),
		NumberSequenceKeypoint.new(0.39, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	shine.Parent = gloss
	local flash = fillImage("Flash", base + 6)
	flash.ImageTransparency = 1

	local tickW = 13 * scale -- hp_tick is 13 px wide
	for i = 1, CFG.TICKS - 1 do
		local tick = Instance.new("ImageLabel")
		tick.Name = "Tick"
		tick.BackgroundTransparency = 1
		tick.Image = CFG.TICK
		tick.ImageColor3 = Color3.new(0, 0, 0)
		tick.ImageTransparency = CFG.TICK_TRANSPARENCY
		tick.AnchorPoint = Vector2.new(0.5, 0)
		tick.Position = UDim2.fromScale(i / CFG.TICKS, 0)
		tick.Size = UDim2.new(0, tickW, 1, 0)
		tick.ZIndex = base + 5
		tick.Parent = well
	end

	local state = HpBarRules.new(1)
	local wasHealing: boolean? = nil
	local ticker: RBXScriptConnection? = nil

	local function render(now: number)
		local fillShare, ghostShare, flashShare, healing = HpBarRules.sample(state, now, CombatHudConfig)
		fill.Size = UDim2.fromScale(fillShare, 1)
		fill.Visible = fillShare > 0
		ghostImage.Size = UDim2.fromScale(ghostShare, 1)
		ghostImage.Visible = ghostShare > fillShare
		flash.ImageTransparency = 1 - flashShare * 0.75
		if healing ~= wasHealing then
			wasHealing = healing
			local shade: Shade = if healing then CFG.HEAL_LEAD else ghost
			ghostShade.Color = ColorSequence.new(color(shade.top), color(shade.bottom))
		end
	end

	local function animate()
		if ticker then
			return
		end
		ticker = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			render(now)
			if HpBarRules.settled(state, now, CombatHudConfig) and ticker then
				ticker:Disconnect()
				ticker = nil
			end
		end)
	end

	local function share(hp: number, maxHp: number): number
		return if maxHp > 0 then hp / maxHp else 0
	end

	local function set(hp: number, maxHp: number)
		local now = os.clock()
		HpBarRules.set(state, share(hp, maxHp), now, CombatHudConfig)
		render(now)
		if not HpBarRules.settled(state, now, CombatHudConfig) then
			animate()
		end
	end

	local function reset(hp: number, maxHp: number)
		state = HpBarRules.new(share(hp, maxHp))
		render(os.clock())
	end

	local function setLook(new: Look)
		edge.ImageColor3 = color(new.edge)
		fillShade.Color = ColorSequence.new(color(new.top), color(new.bottom))
	end

	local function destroy()
		if ticker then
			ticker:Disconnect()
			ticker = nil
		end
		frame:Destroy()
	end

	render(os.clock())
	return { frame = frame, topZIndex = base + 7, set = set, reset = reset, setLook = setLook, destroy = destroy }
end

-- A small foe's HP bar in the fight's own look, its number over it (owner 2026-11-12: "the second monster's health
-- bar has no design"; BattleController's pack and adds rows): the top plate's monster bar `height` tall, 14 px under
-- the holder's top (its name above); `label` makes the number (UIKit.label)
function HpBar.small(holder: Frame, height: number, label: (Instance, string, Enum.Font, number, Color3) -> TextLabel, textColor: Color3): (Bar, TextLabel)
	local spec = CombatHudConfig.HP_BAR
	local bar = HpBar.new(holder, height, spec.MONSTER, spec.GHOST)
	bar.frame.Position = UDim2.fromOffset(0, 14)
	bar.frame.Size = UDim2.new(1, 0, 0, height)
	local text = label(bar.frame, "", Enum.Font.GothamBold, 10, textColor)
	text.Size = UDim2.fromScale(1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextStrokeTransparency = 0.4
	text.ZIndex = 5
	return bar, text
end

-- A small bar's HP and its number
function HpBar.setSmall(bar: Bar, text: TextLabel, hp: number, maxHp: number)
	bar.set(math.max(0, hp), math.max(maxHp, 1))
	text.Text = `{math.max(0, math.round(hp))} / {math.round(maxHp)}`
end

return HpBar
