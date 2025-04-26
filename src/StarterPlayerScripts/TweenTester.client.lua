local Workspace = game:GetService("Workspace")
local TweenPlus = require(game.ReplicatedStorage.TweenPlus)

local part = Instance.new("Part")
part.Parent = Workspace
part.Name = "TestPart"
part.Size = Vector3.new(2, 2, 2)
part.Position = Vector3.new(0, 0.5, -20)
part.Anchored = true

TweenPlus:CreatePreset(
    "SlideInFast",
    TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    { Position = part.Position + Vector3.new(0, 5, 0) }
)

local slide1 = TweenPlus
    :ApplyPreset("SlideInFast", part)
    :Tag("Slide1")
    :Debug("at the top")
    :Wait(0.5)
    :Then(TweenPlus:Create(part, TweenInfo.new(0.2), {Position = part.Position}))
    :Debug("at the bottom")
    :Wait(0.5)

local slideLoop = TweenPlus
    :ApplyPreset("SlideInFast", part)
    :Tag("LoopedSlide")
    :Debug("at the top")
    :Wait(0.5)
    :Then(TweenPlus:Create(part, TweenInfo.new(0.2), {Position = part.Position}))
    :Debug("at the bottom")
    :Wait(0.5)
    :Loop("infinite")

task.wait(1)
slide1:Play()
    :Then(function(resolve)
        slideLoop:Play()
        resolve()
    end)
