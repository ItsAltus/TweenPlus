local Workspace = game:GetService("Workspace")
local TweenPlus = require(game.ReplicatedStorage.TweenPlus)

local part = Instance.new("Part")
part.Parent = Workspace
part.Name = "TestPart"
part.Size = Vector3.new(2, 2, 2)
part.Position = Vector3.new(0, 0.5, -20)
part.Anchored = true

local h = TweenPlus
    :Debug("starting tween")
    :Create(part, TweenInfo.new(0.5), {Position = part.Position + Vector3.new(0,3,0)})
    :Tag("FastRiseThenDrop")
    :Wait(0.2)
    :Debug("at the top")
    :Wait(1)
    :Then(TweenPlus:Create(part, TweenInfo.new(0.5), {Position = part.Position}))
    :Wait(0.2)
    :Debug("at the bottom")

local move = TweenPlus
    :Debug("starting tween")
    :Create(part, TweenInfo.new(1), {Position = part.Position + Vector3.new(0,5,0)})
    :Tag("RiseThenDrop")
    :Wait(0.2)
    :Debug("at the top")
    :Wait(1)
    :Then(TweenPlus:Create(part, TweenInfo.new(1), {Position = part.Position}))
    :Wait(0.2)
    :Debug("at the bottom")

task.wait(1.5)

move:Then(h):Play()
task.delay(4.25, function()
    print(">>> cancel FastRiseThenDrop")
    h:Cancel()
end)
