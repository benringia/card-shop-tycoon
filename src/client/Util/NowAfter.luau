--!strict
-- Now beside After (owner 2026-11-20, on the Card Condenser: "this part needs to be better/easily understandable with
-- no '->'"): a small table for a station window's chosen card, a row a number ("Power  320  371  +51"), the After
-- column in green with how much it grows. The Condenser and the Grading Station draw their before and after with it.
local ClientUtil = script.Parent :: Instance
local UIKit = require(ClientUtil:WaitForChild("UIKit"))

local NowAfter = {}

export type Row = { name: string, now: string, after: string, gain: string }

local LOOK = { label = 54, now = 78, rowHeight = 22, headHeight = 18 }

-- The table's height for this many rows
function NowAfter.height(rows: number): number
	return LOOK.headHeight + rows * LOOK.rowHeight
end

-- Draws it at `position` in `parent`, as wide as the room left of `rightPad`
function NowAfter.draw(parent: Instance, position: UDim2, rows: { Row }, palette: UIKit.Palette, rightPad: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "NowAfter"
	holder.BackgroundTransparency = 1
	holder.Position = position
	holder.Size = UDim2.new(1, -(position.X.Offset + rightPad), 0, NowAfter.height(#rows))
	holder.Parent = parent
	local function cell(text: string, x: number, y: number, width: UDim2, height: number, font: Enum.Font, size: number, color: Color3)
		local label = UIKit.label(holder, text, font, size, color)
		label.Position = UDim2.fromOffset(x, y)
		label.Size = UDim2.new(width.X.Scale, width.X.Offset, 0, height)
		label.TextWrapped = false
		label.TextTruncate = Enum.TextTruncate.AtEnd
	end
	local afterX = LOOK.label + LOOK.now
	cell("Now", LOOK.label, 0, UDim2.fromOffset(LOOK.now, 0), LOOK.headHeight, Enum.Font.GothamBold, 12, palette.inkSoft)
	cell("After", afterX, 0, UDim2.new(1, -afterX, 0, 0), LOOK.headHeight, Enum.Font.GothamBold, 12, palette.good)
	for index, row in rows do
		local y = LOOK.headHeight + (index - 1) * LOOK.rowHeight
		cell(row.name, 0, y, UDim2.fromOffset(LOOK.label, 0), LOOK.rowHeight, Enum.Font.GothamBold, 14, palette.inkSoft)
		cell(row.now, LOOK.label, y, UDim2.fromOffset(LOOK.now, 0), LOOK.rowHeight, Enum.Font.FredokaOne, 14, palette.ink)
		local after = if row.gain ~= "" then `{row.after}  {row.gain}` else row.after
		cell(after, afterX, y, UDim2.new(1, -afterX, 0, 0), LOOK.rowHeight, Enum.Font.FredokaOne, 14, palette.good)
	end
	return holder
end

return NowAfter
