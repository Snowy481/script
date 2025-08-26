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
local IgnoreBotHighlight = false -- true = игнорировать RedHighlight
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

	-- Игроки
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= Player and p.Team ~= Player.Team and p.Character then
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			local bone = p.Character:FindFirstChild(SelectedBone)
			if hum and bone and hum.Health > 0 then
				local screenPos, onScreen = Camera:WorldToViewportPoint(bone.Position)
				if onScreen then
					local dist = (Vector2.new(screenPos.X, screenPos.Y) -
								  Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
					if dist < minDist then
						if not IgnoreBotHighlight and not p.Character:FindFirstChild("RedHighlight") then
							-- если включен фильтр, то скипаем
						elseif ForceFieldCheck and p.Character:FindFirstChildOfClass("ForceField") then
							-- игнорим FF
						elseif IsVisible(bone.Position) then
							closest, minDist = bone, dist
						end
					end
				end
			end
		end
	end

	-- Боты
	local ServerBots = workspace:FindFirstChild("ServerBots")
	if ServerBots then
		for _, bot in ipairs(ServerBots:GetChildren()) do
			local hum = bot:FindFirstChildOfClass("Humanoid")
			local bone = bot:FindFirstChild(SelectedBone)
			if hum and bone and hum.Health > 0 then
				local screenPos, onScreen = Camera:WorldToViewportPoint(bone.Position)
				if onScreen then
					local dist = (Vector2.new(screenPos.X, screenPos.Y) -
								  Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
					if dist < minDist then
						if not IgnoreBotHighlight and not bot:FindFirstChild("RedHighlight") then
							-- скип
						elseif ForceFieldCheck and bot:FindFirstChildOfClass("ForceField") then
							-- скип
						elseif IsVisible(bone.Position) then
							closest, minDist = bone, dist
						end
					end
				end
			end
		end
	end

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
			if SilentAimEnabled then
				-- поддержка StickyTarget
				if StickyTarget and CurrentTarget then
					local hum = CurrentTarget.Parent:FindFirstChildOfClass("Humanoid")
					if not hum or hum.Health <= 0 or not IsVisible(CurrentTarget.Position) then
						CurrentTarget = nil
					end
				end
				if not CurrentTarget then
					CurrentTarget = GetClosestTarget()
				end

				if CurrentTarget then
					local hum = CurrentTarget.Parent:FindFirstChildOfClass("Humanoid")
					if hum then
						local isHead = (SelectedBone == "Head")
						local isTorso = (SelectedBone == "UpperTorso" or SelectedBone == "LowerTorso")
						local dist = (Camera.CFrame.Position - CurrentTarget.Position).Magnitude

						local fakeHit = {
							hum,
							isHead,
							isTorso,
							math.floor(dist)
						}
						args[5] = { ["1"] = fakeHit }
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
end

return SilentAimModule
