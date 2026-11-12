--!strict
-- The phone's Reviews app (owner 2026-11-13: "yes ratings app show customer feedbacks", the small version for the
-- testers; Config/Reviews, Util/ReviewRules): each customer visit's outcome (CustomerService.OnOutcome: paid, a happy
-- moment, annoyed by a haggle, gave up waiting, no stock) may become a post in the shop owner's feed, the newest
-- Reviews.MAX this session (not saved). A new post goes to the owner (Remotes.Reviews { post }); the app asks for the
-- whole feed (Remotes.Reviews from the client, answered { posts }).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Reviews = require(Shared:WaitForChild("Config"):WaitForChild("Reviews"))
local ReviewRules = require(Shared:WaitForChild("Util"):WaitForChild("ReviewRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local CustomerService = require(Services:WaitForChild("CustomerService"))
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))

local ReviewService = {}

local feeds: { [Player]: { ReviewRules.Post } } = {}
local rng = Random.new()
local allowAsk = RateLimiter.new(1)

local function onOutcome(owner: Player, outcome: string)
	if not owner.Parent then
		return
	end
	local post = ReviewRules.make(Reviews, outcome, {
		chance = rng:NextNumber(),
		name = rng:NextNumber(),
		line = rng:NextNumber(),
		stars = rng:NextNumber(),
		color = rng:NextNumber(),
	}, os.time())
	if not post then
		return
	end
	feeds[owner] = ReviewRules.push(feeds[owner] or {}, post, Reviews.MAX)
	Remotes.Reviews:FireClient(owner, { post = post })
end

-- Studio's /review <outcome>: a post as if a customer just had that visit (every chance met)
function ReviewService.PostForTest(owner: Player, outcome: string): boolean
	local post = ReviewRules.make(Reviews, outcome, { chance = 0, name = rng:NextNumber(), line = rng:NextNumber(), stars = rng:NextNumber(), color = rng:NextNumber() }, os.time())
	if not post then
		return false
	end
	feeds[owner] = ReviewRules.push(feeds[owner] or {}, post, Reviews.MAX)
	Remotes.Reviews:FireClient(owner, { post = post })
	return true
end

function ReviewService.Start()
	CustomerService.OnOutcome(onOutcome)
	Remotes.Reviews.OnServerEvent:Connect(function(player: Player)
		if allowAsk(player) then
			Remotes.Reviews:FireClient(player, { posts = feeds[player] or {} })
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		feeds[player] = nil
	end)
end

return ReviewService
