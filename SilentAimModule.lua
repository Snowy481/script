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
local SilentAimEnabled = true
local StickyTarget = true
local IgnoreBotHighlight = true
local FovRadius = 1000
local SelectedBone = "HumanoidRootPart"
local WallCheck = false
local ForceFieldCheck = false
local CurrentTarget = nil

-- Получение объекта оружия
local function getWeapon()
    local weaponName = Player.Name .. "CustomGun1"
    local weapon = workspace:FindFirstChild(weaponName) or 
                   workspace:FindFirstChild("KocTuk_TOPCustomGun_1") or 
                   workspace:FindFirstChild("KocTuk_TOPCustomGun_2")
    if not weapon then
        warn("Weapon not found in workspace:", weaponName, "KocTuk_TOPCustomGun_1", "KocTuk_TOPCustomGun_2")
    else
        print("Found weapon:", weapon.Name)
    end
    return weapon
end

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

-- Функция для создания аргументов
local function buildShootArgs(originalArgs, tool, targetCharacter, targetPos, selectedBone, isBot)
    if not (tool and targetCharacter and targetPos) then return originalArgs end
    local humanoid = targetCharacter:FindFirstChild("Humanoid")
    if not humanoid then return originalArgs end

    local cameraPos = Camera.CFrame.Position
    local cf = CFrame.new(cameraPos, targetPos)
    local dist = math.floor((cameraPos - targetPos).Magnitude)

    -- hitData (копия оригинального формата)
    local hitData = {
        ["1"] = {
            humanoid,
            true,
            true,
            dist
        }
    }

    -- копируем оригинальные аргументы и подменяем нужное
    local newArgs = table.clone(originalArgs)
    newArgs[2] = tool
    newArgs[3] = cf
    newArgs[5] = hitData

    return newArgs
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
                print("Player:", p.Name, "ScreenPos:", screenPos, "OnScreen:", onScreen)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) -
                                  Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                    print("Player:", p.Name, "Distance:", dist)
                    if dist < minDist then
                        closest, minDist = bone, dist
                        print("Valid player target found:", p.Name, "Bone:", bone.Name)
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
                print("Bot:", bot.Name, "ScreenPos:", screenPos, "OnScreen:", onScreen)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) -
                                  Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                    print("Bot:", bot.Name, "Distance:", dist)
                    if dist < minDist then
                        closest, minDist = bone, dist
                        print("Valid bot target found:", bot.Name, "Bone:", bone.Name)
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
            for i, v in ipairs(args) do
                print("Arg["..i.."] =", v, typeof(v))
            end
            print("FireServer called with args:", args)
            print("Original args[2]:", args[2] and args[2].Name or "nil")
            print("Original args[4]:", args[4])
            print("SilentAimEnabled:", SilentAimEnabled)
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
                        local isBot = CurrentTarget.Parent.Parent == workspace:FindFirstChild("ServerBots")
                        local tool = getWeapon()
                        if not tool then
                            warn("No valid weapon found, using original args[2]")
                            return oldNamecall(self, unpack(args))
                        end
                        local newArgs = buildShootArgs(args, tool, CurrentTarget.Parent, CurrentTarget.Position, SelectedBone, isBot)
                    end
                end
            end
if CurrentTarget then
    local hum = CurrentTarget.Parent:FindFirstChildOfClass("Humanoid")
    print("Target Humanoid:", hum and hum.Parent.Name or "nil", "Bone:", SelectedBone)
    if hum then
        local isBot = CurrentTarget.Parent.Parent == workspace:FindFirstChild("ServerBots")
        local tool = getWeapon()
        if not tool then
            warn("No valid weapon found, using original args[2]")
            return oldNamecall(self, unpack(args))
        end
        local newArgs = buildShootArgs(args, tool, CurrentTarget.Parent, CurrentTarget.Position, SelectedBone, isBot)
        return oldNamecall(self, unpack(newArgs))
    end
end

-- если нет CurrentTarget или что-то пошло не так — стреляем по дефолту
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
    SilentAimEnabled = config.SilentAimEnabled or SilentAimEnabled
    StickyTarget = config.StickyTarget or StickyTarget
    IgnoreBotHighlight = config.IgnoreBotHighlight or IgnoreBotHighlight
    FovRadius = config.FovRadius or FovRadius
    SelectedBone = config.SelectedBone or SelectedBone
    WallCheck = config.WallCheck or WallCheck
    ForceFieldCheck = config.ForceFieldCheck or ForceFieldCheck
end

return SilentAimModule






