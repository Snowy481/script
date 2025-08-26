-- silent_aim_module.luau
-- ⚠️ Учебный скрипт для теста защиты ⚠️

local SilentAimModule = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera

local Player = Players.LocalPlayer
local Shoot = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Shoot")

-- Silent Aim Variables
local SilentAimEnabled = false
local StickyTarget = false
local IgnoreBotHighlight = false
local FovRadius = 150
local SelectedBone = "Head"
local WallCheck = true
local ForceFieldCheck = true
local CurrentTarget = nil

-- Проверка видимости через Raycast
local function IsVisible(targetPos)
    if not WallCheck then return true end
    local origin = Camera.CFrame.Position
    local direction = (targetPos - origin)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = { Player.Character }
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, direction, raycastParams)
    return result == nil or (result and (result.Instance.Position - targetPos).Magnitude < 2)
end

-- Поиск ближайшей цели
local function GetClosestTarget()
    local closest, minDist = nil, FovRadius
    print("Searching for target, FovRadius:", FovRadius, "SelectedBone:", SelectedBone)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local bone = p.Character:FindFirstChild(SelectedBone)
            print("Checking player:", p.Name, "Humanoid:", hum, "Bone:", bone)
            if hum and bone and hum.Health > 0 then
                local screenPos, onScreen = Camera:WorldToViewportPoint(bone.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) -
                                  Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                    print("Player:", p.Name, "Distance:", dist, "OnScreen:", onScreen)
                    if dist < minDist then
                        if not IgnoreBotHighlight and p.Character:FindFirstChild("RedHighlight") then
                            print("Skipping player due to RedHighlight:", p.Name)
                        elseif ForceFieldCheck and p.Character:FindFirstChildOfClass("ForceField") then
                            print("Skipping player due to ForceField:", p.Name)
                        elseif IsVisible(bone.Position) then
                            print("Valid player target found:", p.Name, "Bone:", bone.Name)
                            closest, minDist = bone, dist
                        else
                            print("Player not visible:", p.Name)
                        end
                    end
                end
            end
        end
    end

    local ServerBots = workspace:FindFirstChild("ServerBots")
    if ServerBots then
        for _, bot in ipairs(ServerBots:GetChildren()) do
            local hum = bot:FindFirstChildOfClass("Humanoid")
            local bone = bot:FindFirstChild(SelectedBone)
            print("Checking bot:", bot.Name, "Humanoid:", hum, "Bone:", bone)
            if hum and bone and hum.Health > 0 then
                local screenPos, onScreen = Camera:WorldToViewportPoint(bone.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) -
                                  Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                    print("Bot:", bot.Name, "Distance:", dist, "OnScreen:", onScreen)
                    if dist < minDist then
                        if not IgnoreBotHighlight and bot:FindFirstChild("RedHighlight") then
                            print("Skipping bot due to RedHighlight:", bot.Name)
                        elseif ForceFieldCheck and bot:FindFirstChildOfClass("ForceField") then
                            print("Skipping bot due to ForceField:", bot.Name)
                        elseif IsVisible(bone.Position) then
                            print("Valid bot target found:", bot.Name, "Bone:", bone.Name)
                            closest, minDist = bone, dist
                        else
                            print("Bot not visible:", bot.Name)
                        end
                    end
                end
            end
        end
    end

    print("Closest target:", closest and closest.Name or "nil")
    return closest
end

-- Хук FireServer
local oldNamecall
function SilentAimModule:Start()
    if oldNamecall then return end
    if not Shoot:IsA("RemoteEvent") then
        warn("Shoot is not RemoteEvent")
        return
    end

    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if self == Shoot and getnamecallmethod() == "FireServer" then
            local args = {...}
            print("FireServer called with args:", args)
            if SilentAimEnabled then
                print("SilentAimEnabled is true")
                if StickyTarget and CurrentTarget then
                    local hum = CurrentTarget.Parent:FindFirstChildOfClass("Humanoid")
                    if not hum or hum.Health <= 0 or not IsVisible(CurrentTarget.Position) then
                        print("StickyTarget invalidated, resetting CurrentTarget")
                        CurrentTarget = nil
                    end
                end
                if not CurrentTarget then
                    CurrentTarget = GetClosestTarget()
                    print("Selected CurrentTarget:", CurrentTarget and CurrentTarget.Name or "nil")
                end
                if CurrentTarget then
                    local hum = CurrentTarget.Parent:FindFirstChildOfClass("Humanoid")
                    print("Target Humanoid:", hum and hum.Parent.Name or "nil", "Bone:", SelectedBone)
                    if hum then
                        local isHead = (SelectedBone == "Head")
                        local isTorso = true -- Всегда true для игроков
                        local dist = (Camera.CFrame.Position - CurrentTarget.Position).Magnitude
                        print("isHead:", isHead, "isTorso:", isTorso, "Distance:", math.floor(dist))
                        local fakeHit = { hum, isHead, isTorso, math.floor(dist) }
                        args[5] = { ["1"] = fakeHit }
                        args[4] = true -- Устанавливаем true, как в логах
                        args[3] = CFrame.new(Camera.CFrame.Position, CurrentTarget.Position) -- Направляем CFrame на цель
                        print("Modified args[3]:", args[3], "Modified args[4]:", args[4], "Modified args[5]:", args[5])
                    end
                end
            end
            return oldNamecall(self, unpack(args))
        end
        return oldNamecall(self, ...)
    end)

    print("[SilentAimModule] Hooked FireServer")
end

function SilentAimModule:Stop()
    if oldNamecall then
        hookmetamethod(game, "__namecall", oldNamecall)
        oldNamecall = nil
        print("[SilentAimModule] Unhooked")
    end
    CurrentTarget = nil
end

function SilentAimModule:SetConfig(config)
    SilentAimEnabled = config.SilentAimEnabled ~= nil and config.SilentAimEnabled or SilentAimEnabled
    StickyTarget = config.StickyTarget ~= nil and config.StickyTarget or StickyTarget
    IgnoreBotHighlight = config.IgnoreBotHighlight ~= nil and config.IgnoreBotHighlight or IgnoreBotHighlight
    FovRadius = config.FovRadius or FovRadius
    SelectedBone = config.SelectedBone or SelectedBone
    WallCheck = config.WallCheck ~= nil and config.WallCheck or WallCheck
    ForceFieldCheck = config.ForceFieldCheck ~= nil and config.ForceFieldCheck or ForceFieldCheck
    print("Config updated:", config)
end

return SilentAimModule
