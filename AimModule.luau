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
if tool then
args[2] = tool
end
local isHead = (SelectedBone == "Head")
local isTorso = true
local dist = math.floor((Camera.CFrame.Position - CurrentTarget.Position).Magnitude)
local fakeHit = { hum, isHead, isTorso, dist }
args[5] = { ["1"] = fakeHit }
args[3] = CFrame.new(Camera.CFrame.Position, CurrentTarget.Position)
args[4] = true
print("Modified args[3]:", args[3])
print("Modified args[4]:", args[4])
print("Modified args[5]:", args[5])
if tool then
print("Modified args[2]:", args[2].Name)
end
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
return SilentAimModule
