--!strict
-- A sale's coins (owner 2026-11-16, register mockup approved; Config/RegisterStation SALE_FX): gold coins burst out
-- around `from` (viewport pixels) and arc into `target` (your cash pill), one after another; `onLanded` runs as the
-- last one lands (the pill counts up then). Drawn in `screen` (a ScreenGui), over everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RegisterStation = require(Shared:WaitForChild("Config"):WaitForChild("RegisterStation"))
local UIIcons = require(Shared:WaitForChild("Config"):WaitForChild("UIIcons"))
local SparkPath = require(Shared:WaitForChild("Util"):WaitForChild("SparkPath"))

local CoinBurst = {}

local FX = RegisterStation.SALE_FX

-- Seconds until the last coin lands, for `count` coins
function CoinBurst.duration(count: number): number
	return (count - 1) * FX.stagger + FX.flySeconds
end

function CoinBurst.fly(screen: ScreenGui, from: Vector2, target: GuiObject, count: number, onLanded: (() -> ())?)
	local origin = screen.AbsolutePosition
	local start = from - origin
	local random = Random.new()
	for index = 1, count do
		task.delay((index - 1) * FX.stagger, function()
			local coin = Instance.new("ImageLabel")
			coin.Name = "SaleCoin"
			coin.BackgroundTransparency = 1
			coin.Image = UIIcons.Coin
			coin.AnchorPoint = Vector2.new(0.5, 0.5)
			coin.Size = UDim2.fromOffset(FX.coinSize, FX.coinSize)
			coin.ZIndex = 30
			coin.Parent = screen
			-- out of the register in a little burst first, then arcing into the pill
			local angle = random:NextNumber(0, math.pi * 2)
			local out = start + Vector2.new(math.cos(angle), math.sin(angle) * 0.6) * random:NextNumber(FX.spread * 0.4, FX.spread)
			local spin = random:NextNumber(-360, 360)
			local started = os.clock()
			local connection: RBXScriptConnection
			connection = RunService.RenderStepped:Connect(function()
				local t = math.min((os.clock() - started) / FX.flySeconds, 1)
				local goal = target.AbsolutePosition + target.AbsoluteSize / 2 - origin
				local x, y
				if t < 0.25 then
					local u = t / 0.25
					local eased = 1 - (1 - u) * (1 - u)
					x, y = start.X + (out.X - start.X) * eased, start.Y + (out.Y - start.Y) * eased
				else
					local u = (t - 0.25) / 0.75
					local eased = u * u * (3 - 2 * u)
					x, y = SparkPath.point(out.X, out.Y, goal.X, goal.Y, FX.lift, eased)
				end
				coin.Position = UDim2.fromOffset(x, y)
				coin.Rotation = spin * t
				local size = FX.coinSize * (if t > 0.8 then 1 - (t - 0.8) * 2 else 1)
				coin.Size = UDim2.fromOffset(size, size)
				if t >= 1 then
					connection:Disconnect()
					coin:Destroy()
					if index == count and onLanded then
						onLanded()
					end
				end
			end)
		end)
	end
end

return CoinBurst
