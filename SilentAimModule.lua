-- silent_aim_module.luau
local SilentAimModule = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera

local Player = Players.LocalPlayer
local Shoot = game.ReplicatedStorage.Events.Shoot

-- Silent Aim Variables
local SilentAimEnabled = false
local StickyTarget = false
local IgnoreBotHighlight = false -- true means ignore RedHighlight
local FovRadius = 15 -- Matches UI default
local SelectedBone = "Head" -- Synced with aimbot
local WallCheck = true -- Synced with aimbot
local ForceFieldCheck = true -- From aimbot
local CurrentTarget = nil -- For StickyTarget

-- Function to check if visible (wall check)
local function IsVisible(targetPos)
    if not WallCheck then return true end
    local origin = Camera.CFrame.Position
    local direction = targetPos - origin
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = { Player.Character }
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local raycastResult = workspace:Raycast(origin, direction, raycastParams)
    return raycastResult == nil or raycastResult.Position == targetPos
end

-- Function to get closest target (players and bots in ServerBots)
local function GetClosestTarget()
    local closest = nil
    local minDist = FovRadius or math.huge
    local allTargets = {}

    -- Players
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            table.insert(allTargets, p.Character)
        end
    end

    -- Bots in ServerBots
    local ServerBots = workspace:FindFirstChild("ServerBots") or workspace:WaitForChild("ServerBots")
    for _, bot in ipairs(ServerBots:GetChildren()) do
        if bot:IsA("Model") and bot:FindFirstChild("Humanoid") and bot.Humanoid.Health > 0 then
            table.insert(allTargets, bot)
        end
    end

    for _, char in ipairs(allTargets) do
        local bone = char:FindFirstChild(SelectedBone)
        if bone then
            local screenPos, onScreen = Camera:WorldToViewportPoint(bone.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                if dist < minDist then
                    if not IgnoreBotHighlight and not char:FindFirstChild("RedHighlight") then continue end
                    if ForceFieldCheck and char:FindFirstChildOfClass("ForceField") then continue end
                    if IsVisible(bone.Position) then
                        minDist = dist
                        closest = bone
                    end
                end
            end
        end
    end

    return closest
end

-- Hook using hookmetamethod for namecall
local oldNamecall
function SilentAimModule:Start()
    if oldNamecall then return end
    if not Shoot:IsA("RemoteEvent") then
        warn("Shoot is not a RemoteEvent, cannot hook FireServer")
        return
    end
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if self == Shoot and getnamecallmethod() == "FireServer" then
            local args = {...}
            local timestamp, blaster, cframe, isAimed, hits = args[1], args[2], args[3], args[4], args[5]
            if SilentAimEnabled then
                if StickyTarget and CurrentTarget then
                    local humanoid = CurrentTarget.Parent and CurrentTarget.Parent:FindFirstChild("Humanoid")
                    if not humanoid or humanoid.Health <= 0 or not CurrentTarget.Parent or not IsVisible(CurrentTarget.Position) then
                        CurrentTarget = nil
                    end
                end

                if not CurrentTarget then
                    CurrentTarget = GetClosestTarget()
                end

                if CurrentTarget then
                    local targetHumanoid = CurrentTarget.Parent:FindFirstChild("Humanoid")
                    if targetHumanoid then
                        local isHeadshot = (SelectedBone == "Head")
                        local isTorsoShot = (SelectedBone == "UpperTorso" or SelectedBone == "LowerTorso")
                        local shotDistance = (Camera.CFrame.Position - CurrentTarget.Position).Magnitude

                        local fakeHit = {
                            targetHumanoid,
                            isHeadshot,
                            isTorsoShot,
                            math.floor(shotDistance)
                        }

                        hits = { ["1"] = fakeHit } -- Replace hits; adjust for multi-ray weapons if needed
                    end
                end
            end
            return oldNamecall(self, timestamp, blaster, cframe, isAimed, hits)
        end
        return oldNamecall(self, ...)
    end)
    print("Silent Aim hooked successfully at", os.time())
end

function SilentAimModule:Stop()
    if oldNamecall then
        hookmetamethod(game, "__namecall", oldNamecall)
        oldNamecall = nil
        print("Silent Aim unhooked successfully at", os.time())
    else
        warn("Failed to unhook namecall: oldNamecall is nil")
    end
    CurrentTarget = nil
end

function SilentAimModule:SetConfig(config)
    SilentAimEnabled = config.SilentAimEnabled or SilentAimEnabled
    StickyTarget = config.StickyTarget or StickyTarget
    IgnoreBotHighlight = config.IgnoreBotHighlight or IgnoreBotHighlight
    FovRadius = config.FovRadius or FovRadius
    SelectedBone = config.SelectedBone or SelectedBone
    WallCheck = config.WallCheck or WallCheck
    ForceFieldCheck = config.ForceFieldCheck or ForceFieldCheck
end

return SilentAimModule

