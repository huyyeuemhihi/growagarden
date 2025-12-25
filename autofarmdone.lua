-- UI
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Tween + NoCD Attack",
    LoadingTitle = "Fly On Mob",
    LoadingSubtitle = "Trieudz",
    Theme = "Default",
    ToggleUIKeybind = Enum.KeyCode.K,
    ConfigurationSaving = { Enabled = false }
})

local Tab = Window:CreateTab("Main")

-- SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

Player.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:WaitForChild("Humanoid")
end)

-- SETTINGS
local Settings = {
    AutoFarm = false,
    TweenHeight = 30,
    TweenTime = 350, -- Default Speed
    ClickDelay = 0, -- Set to 0 for fastest attack
}

-- NOCLIP
local noclipConnection
local function ToggleNoclip(enabled)
    if enabled then
        if noclipConnection then return end
        noclipConnection = RunService.Stepped:Connect(function()
            if Character then
                for _, part in pairs(Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end
end

-- FUNCTIONS

-- Tự động cầm Melee
local function EquipMelee()
    local inventory = Player.Backpack
    local char = Character
    if not char then return end
    
    -- Tìm Melee trong Backpack
    for _, tool in pairs(inventory:GetChildren()) do
        if tool:IsA("Tool") and (tool.ToolTip == "Melee" or tool:FindFirstChild("Melee")) then
            Humanoid:EquipTool(tool)
            task.wait(0.5)
            return
        end
    end
end

-- Kiểm tra mob còn sống
local function isAlive(mob)
    local hum = mob:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

-- Lấy mob gần nhất
local function GetNearestMob()
    local nearest = nil
    local nearestDist = math.huge
    local pos = HRP.Position

    for _, mob in pairs(Workspace:WaitForChild("Enemies"):GetChildren()) do
        if mob:IsA("Model") and isAlive(mob) then
            local mHRP = mob:FindFirstChild("HumanoidRootPart")
            if mHRP then
                local dist = (mHRP.Position - pos).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = mob
                end
            end
        end
    end
    return nearest
end

-- Tween tới mob (Dùng TweenService)
local currentTween
local function TweenToMob(mob)
    if not mob then return end
    local targetHRP = mob:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    local targetCFrame = CFrame.new(targetHRP.Position + Vector3.new(0, Settings.TweenHeight, 0))
    
    if currentTween then
        currentTween:Cancel()
    end

    local dist = (HRP.Position - targetCFrame.Position).Magnitude
    local tweenTime = dist / Settings.TweenTime
    
    currentTween = TweenService:Create(HRP, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
    currentTween:Play()
    HRP.Velocity = Vector3.new(0, 0, 0)
end

-- Attack No CoolDown (Tối ưu tốc độ)
local function AttackNoCoolDown()
    local char = Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end

    local mob = GetNearestMob()
    if mob then
        local HRPMob = mob:FindFirstChild("HumanoidRootPart")
        if HRPMob then
            pcall(function()
                if tool:FindFirstChild("LeftClickRemote") then
                    local dir = (HRPMob.Position - HRP.Position).Unit
                    tool.LeftClickRemote:FireServer(di)
                else
                    local Net = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net")
                    local RA = Net:WaitForChild("RE/RegisterAttack")
                    local RH = Net:WaitForChild("RE/RegisterHit")
                    RA:FireServer(0)
                    RH:FireServer(HRPMob, {{mob, HRPMob}})
                end
            end)
        end
    end
end

-- MAIN LOOP
task.spawn(function()
    while true do
        if Settings.ClickDelay > 0 then
            task.wait(Settings.ClickDelay)
        else
            RunService.Heartbeat:Wait()
        end

        if Settings.AutoFarm then
            local mob = GetNearestMob()
            if mob then
                -- Cầm vũ khí
                EquipMelee()
                -- Tween tới mob
                task.spawn(function()
                    TweenToMob(mob)
                end)
                -- Tấn công
                AttackNoCoolDown()
            else
                -- Nếu không thấy mob, giữ nguyên vị trí trên không và dừng vận tốc
                HRP.Velocity = Vector3.new(0, 0, 0)
                if currentTween then
                    currentTween:Cancel()
                end
            end
        end
    end
end)

-- UI
Tab:CreateToggle({
    Name = "Auto Farm (Tween + Attack + NoClip)",
    CurrentValue = false,
    Callback = function(v)
        Settings.AutoFarm = v
        ToggleNoclip(v)
    end
})

Tab:CreateSlider({
    Name = "Chiều cao Tween",
    Range = {1, 30},
    Increment = 1,
    CurrentValue = Settings.TweenHeight,
    Callback = function(v)
        Settings.TweenHeight = v
    end
})

Tab:CreateSlider({
    Name = "Tốc độ Tween (Speed)",
    Range = {10, 500},
    Increment = 1,
    CurrentValue = Settings.TweenTime,
    Callback = function(v)
        Settings.TweenTime = v
    end
})

Tab:CreateSlider({
    Name = "Delay Attack",
    Range = {0.01, 0.3},
    Increment = 0.01,
    CurrentValue = Settings.ClickDelay,
    Callback = function(v)
        Settings.ClickDelay = v
    end
})
