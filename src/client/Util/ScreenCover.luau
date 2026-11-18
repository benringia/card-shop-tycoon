--!strict
-- Covers reach the very edges of the screen (owner 2026-11-18: a phone's cinema bars stopped short of its sides). A
-- gui with IgnoreGuiInset keeps a phone's safe area (DeviceSafeInsets: clear of the notch, the rounded corners and the
-- home bar) and clips everything in it there: right for words and buttons, but a letterbox bar, a fade or a dim then
-- leaves bands of the world showing. A gui holding covers only sets ScreenInsets None instead; in a gui with words and
-- buttons, covers go in `ScreenCover.layer`: a frame spanning the whole screen, so the covers keep their sizes by scale
-- (now of the whole screen) and stack as before. Shared/Util/ScreenEdges.
-- Where a gui's space starts is read from a hidden probe gui with the same ScreenInsets, never from the gui itself: a
-- gui not parented yet reads (0, 0), and its AbsolutePosition signal never fires once it is, so the desktop's bars sat
-- one top bar (58 px) too high, a gap under the bottom one (owner 2026-11-18). Probes are always parented and their
-- frames' signals fire when the screen changes (a window resized, a phone turned).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScreenEdges = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("ScreenEdges"))

local ScreenCover = {}

-- The attribute marking a gui that a cinematic turning every other screen off leaves on (PrologueStage, Welcome)
ScreenCover.KEEP = "KeepEnabled"

type Probe = { gui: ScreenGui, whole: Frame, origin: Frame }

local probes: { [Enum.ScreenInsets]: Probe } = {}

-- The hidden gui measuring `mode`'s space: `whole` spans it, `origin` (no size, so a phone's full-screen extension
-- never stretches it) marks its top-left
local function probe(mode: Enum.ScreenInsets): Probe
	local made = probes[mode]
	if made and made.gui.Parent then
		return made
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "ScreenEdges" .. mode.Name
	gui.ScreenInsets = mode
	gui.ResetOnSpawn = false
	gui:SetAttribute(ScreenCover.KEEP, true) -- a turned-off gui stops signalling
	local whole = Instance.new("Frame")
	whole.Name = "Whole"
	whole.BackgroundTransparency = 1
	whole.Size = UDim2.fromScale(1, 1)
	whole.Parent = gui
	local origin = Instance.new("Frame")
	origin.Name = "Origin"
	origin.BackgroundTransparency = 1
	origin.Size = UDim2.fromOffset(0, 0)
	origin.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local fresh = { gui = gui, whole = whole, origin = origin }
	probes[mode] = fresh
	return fresh
end

-- The whole screen in `gui`'s own space (parented or not yet); drawing there, the gui stops clipping at its safe area
function ScreenCover.rect(gui: ScreenGui): ScreenEdges.Rect
	gui.ClipToDeviceSafeArea = false
	local whole = probe(Enum.ScreenInsets.None).whole
	local origin = probe(gui.ScreenInsets).origin
	local at, size = whole.AbsolutePosition, whole.AbsoluteSize
	return ScreenEdges.rect({ x = at.X, y = at.Y, w = size.X, h = size.Y }, origin.AbsolutePosition.X, origin.AbsolutePosition.Y)
end

-- A frame in `gui` spanning the whole screen, `zIndex` among the gui's children: make it where the cover was made
-- (the same order and ZIndex) and put the cover in it
function ScreenCover.layer(gui: ScreenGui, zIndex: number?): Frame
	local layer = Instance.new("Frame")
	layer.Name = "ScreenCover"
	layer.BackgroundTransparency = 1
	layer.BorderSizePixel = 0
	layer.Active = false
	layer.ZIndex = zIndex or 1
	local own: RBXScriptConnection? = nil
	local function place()
		local whole = ScreenCover.rect(gui)
		layer.Position = UDim2.fromOffset(whole.x, whole.y)
		layer.Size = UDim2.fromOffset(whole.w, whole.h)
	end
	-- the gui's own space moving (its safe area as a phone turns), followed again if its ScreenInsets change
	local function follow()
		if own then
			own:Disconnect()
		end
		own = probe(gui.ScreenInsets).origin:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
		place()
	end
	follow()
	local screen = probe(Enum.ScreenInsets.None).whole
	local watching = {
		screen:GetPropertyChangedSignal("AbsolutePosition"):Connect(place),
		screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(place),
		gui:GetPropertyChangedSignal("ScreenInsets"):Connect(follow),
		gui:GetPropertyChangedSignal("IgnoreGuiInset"):Connect(follow),
	}
	layer.Destroying:Connect(function()
		for _, connection in watching do
			connection:Disconnect()
		end
		if own then
			own:Disconnect()
			own = nil
		end
	end)
	layer.Parent = gui
	return layer
end

return ScreenCover
