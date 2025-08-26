local AimbotModule = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local ClientBots = workspace:WaitForChild("ClientBots")

-- Vars
local AimbotEnabled = false
local WallCheck = false
local FovCheck = false
local HighlightCheck = true
local ForceFieldCheck = true
local StickyTarget = false
local Smoothness = 0
local FovRadius = 150
local SelectedBone = "Head"
local AimKey = "MouseButton2"
local CurrentTarget = nil

-- FOV Circle + Center Dot
local FovCircle = Drawing.new("Circle")
FovCircle.Visible = false
FovCircle.Thickness = 2
FovCircle.Color = Color3.fromRGB(255, 0, 0)
FovCircle.Filled = false
FovCircle.Radius = FovRadius

local CenterDot = Drawing.new("Circle")
CenterDot.Visible = true
CenterDot.Thickness = 2
CenterDot.Color = Color3.fromRGB(255, 0, 0)
CenterDot.Filled = true
CenterDot.Radius = 2
CenterDot.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

-- Visibility check
local function IsVisible(targetPos, targetChar)
    if not WallCheck then return true end
    local origin = Camera.CFrame.Position
    local direction = targetPos - origin
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { Player.Character }
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true

    local result = workspace:Raycast(origin, direction, params)
    if not result then return true end
    if not result.Instance.CanCollide then return true end
    return result.Instance:IsDescendantOf(targetChar)
end

-- Target finder
local function GetClosestTarget()
    local closest, minDist = nil, FovCheck and FovRadius or math.huge
    local allTargets = {}

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            table.insert(allTargets, p.Character)
        end
    end
    for _, bot in ipairs(ClientBots:GetChildren()) do
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
                    if HighlightCheck and not char:FindFirstChild("RedHighlight") then continue end
                    if ForceFieldCheck and char:FindFirstChildOfClass("ForceField") then continue end
                    if IsVisible(bone.Position, char) then
                        minDist = dist
                        closest = bone
                    end
                end
            end
        end
    end

    return closest
end

-- Main aimbot loop
local aimbotConnection
function AimbotModule:Start()
    if aimbotConnection then return end
    aimbotConnection = RunService.RenderStepped:Connect(function()
        CenterDot.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        if AimbotEnabled and FovCheck then
            FovCircle.Visible = true
            FovCircle.Radius = FovRadius
            FovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        else
            FovCircle.Visible = false
        end

        if not AimbotEnabled then 
            CurrentTarget = nil
            return 
        end

        local shouldAim = false
        if AimKey:find("MouseButton") then
            local btn = Enum.UserInputType[AimKey]
            if btn then shouldAim = UserInputService:IsMouseButtonPressed(btn) end
        else
            local kc = Enum.KeyCode[AimKey]
            if kc then shouldAim = UserInputService:IsKeyDown(kc) end
        end

        if shouldAim then
            if StickyTarget and CurrentTarget then
                local humanoid = CurrentTarget.Parent and CurrentTarget.Parent:FindFirstChild("Humanoid")
                if not humanoid or humanoid.Health <= 0 or not CurrentTarget.Parent or not IsVisible(CurrentTarget.Position, CurrentTarget.Parent) then
                    CurrentTarget = nil
                end
            end

            if not CurrentTarget then
                CurrentTarget = GetClosestTarget()
            end

            if CurrentTarget then
                local camPos = Camera.CFrame.Position
                local newCFrame = CFrame.new(camPos, CurrentTarget.Position)
                Camera.CFrame = Smoothness > 0 and Camera.CFrame:Lerp(newCFrame, Smoothness) or newCFrame
            end
        elseif not StickyTarget then
            CurrentTarget = nil
        end
    end)
end

function AimbotModule:Stop()
    if aimbotConnection then
        aimbotConnection:Disconnect()
        aimbotConnection = nil
    end
    CurrentTarget = nil
    FovCircle.Visible = false
    CenterDot.Visible = false
end

function AimbotModule:SetConfig(config)
    AimbotEnabled = config.AimbotEnabled or AimbotEnabled
    WallCheck = config.WallCheck or WallCheck
    FovCheck = config.FovCheck or FovCheck
    HighlightCheck = config.HighlightCheck or HighlightCheck
    ForceFieldCheck = config.ForceFieldCheck or ForceFieldCheck
    StickyTarget = config.StickyTarget or StickyTarget
    Smoothness = config.Smoothness or Smoothness
    FovRadius = config.FovRadius or FovRadius
    SelectedBone = config.SelectedBone or SelectedBone
    AimKey = config.AimKey or AimKey
end


return AimbotModule