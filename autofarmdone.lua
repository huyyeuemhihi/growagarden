-- ===== UI =====
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
    Name = "Block Kid",
    LoadingTitle = "Skidd is my life",
    LoadingSubtitle = "Huyyy",
    Theme = "Default",
    ToggleUIKeybind = Enum.KeyCode.K,
    ConfigurationSaving = { Enabled = false }
})
local Tab = Window:CreateTab("Main")

-- ===== SERVICES =====
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

-- ===== SETTINGS =====
local Settings = {
    AutoFarm = false,
    TweenHeight = 28,
    TweenSpeed = 350,
    BringRadius = 150
}

local SelectedWeapon = "Sword"

-- ===== NOCLIP =====
local noclipConnection
local function ToggleNoclip(state)
    if state then
        if noclipConnection then return end
        noclipConnection = RunService.Stepped:Connect(function()
            for _, v in pairs(Character:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
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

-- ===== EQUIP WEAPON =====
local function EquipWeapon()
    local tool = Character:FindFirstChildOfClass("Tool")
    if tool and (tool.Name == SelectedWeapon or tool.ToolTip == SelectedWeapon) then return end
    for _, t in pairs(Player.Backpack:GetChildren()) do
        if t:IsA("Tool") and (t.Name == SelectedWeapon or t.ToolTip == SelectedWeapon) then
            Humanoid:EquipTool(t)
            break
        end
    end
end

-- ===== MOB FUNCTIONS =====
local function Alive(m)
    local h = m:FindFirstChild("Humanoid")
    return h and h.Health > 0
end

local function GetNearestMob()
    local nearest, dist = nil, math.huge
    for _, m in pairs(Workspace.Enemies:GetChildren()) do
        if m:IsA("Model") and Alive(m) and m:FindFirstChild("HumanoidRootPart") then
            local d = (m.HumanoidRootPart.Position - HRP.Position).Magnitude
            if d < dist then
                dist = d
                nearest = m
            end
        end
    end
    return nearest
end

-- ===== TWEEN PLAYER TO TARGET + BRING + LOCK TARGET =====
-- ===== TWEEN PLAYER TO TARGET + BRING + LOCK TARGET =====
local currentTween
local function TweenToTargetAndBring(targetMob)
    if not targetMob or not targetMob:FindFirstChild("HumanoidRootPart") then return end
    local targetHRP = targetMob.HumanoidRootPart

    -- Tween player lên trên đầu target mob
    local targetPos = targetHRP.Position + Vector3.new(-4, Settings.TweenHeight, 5)
    local targetCFrame = CFrame.new(targetPos, targetPos + targetHRP.CFrame.LookVector)

    if currentTween then currentTween:Cancel() end

    local dist = (HRP.Position - targetPos).Magnitude
    local tweenTime = dist / Settings.TweenSpeed

    currentTween = TweenService:Create(HRP, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
    currentTween:Play()
    HRP.Velocity = Vector3.new(0,0,0)

    -- Khi tween hoàn tất, lock mob target và bring mob xung quanh
    currentTween.Completed:Connect(function()
        -- Anchor mob target để đứng yên
        if targetMob:FindFirstChild("Humanoid") then
            targetMob.Humanoid.JumpPower = 0
            targetMob.Humanoid.WalkSpeed = 0
        end

        -- Bring các mob xung quanh ổn định
        for _, m in pairs(Workspace.Enemies:GetChildren()) do
            if m ~= targetMob and Alive(m) and m:FindFirstChild("HumanoidRootPart") then
                local hrp = m.HumanoidRootPart
                local distanceToTarget = (hrp.Position - targetHRP.Position).Magnitude
                if distanceToTarget <= Settings.BringRadius then
                    hrp.CanCollide = false
                    -- Tween mob xung quanh đến vị trí gần target
                    local goalCFrame = targetHRP.CFrame * CFrame.new(math.random(-0.5,0.5),0,math.random(-0.5,0.5))
                    local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Linear)
                    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = goalCFrame})
                    tween:Play()
                end
            end
        end
    end)
end


-- ===== ATTACK MAX SPEED =====
local Net = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net")
local RA = Net:WaitForChild("RE/RegisterAttack")
local RH = Net:WaitForChild("RE/RegisterHit")

-- ===== ATTACK MAX SPEED =====
task.spawn(function()
    while true do
        if Settings.AutoFarm then
            EquipWeapon()
            local tool = Character:FindFirstChildOfClass("Tool")
            if tool then
                for _, m in pairs(Workspace.Enemies:GetChildren()) do
                    if Alive(m) and m:FindFirstChild("HumanoidRootPart") then
                        local hrpMob = m.HumanoidRootPart
                        local distance = (hrpMob.Position - HRP.Position).Magnitude
                        if distance <= Settings.BringRadius then
                            pcall(function()
                                if tool:FindFirstChild("LeftClickRemote") then
                                    tool.LeftClickRemote:FireServer((hrpMob.Position - HRP.Position).Unit)
                                else
                                    RA:FireServer(0)
                                    RH:FireServer(hrpMob, {{m, hrpMob}})
                                end
                            end)
                        end
                    end
                end
            end
        end
        task.wait(0)
    end
end)


-- ===== MOVE LOOP =====
task.spawn(function()
    while true do
        if Settings.AutoFarm then
            local mob = GetNearestMob()
            if mob then
                TweenToTargetAndBring(mob)
            end
        end
        RunService.Heartbeat:Wait()
    end
end)

-- ===== UI =====
Tab:CreateDropdown({
    Name = "Select Weapon",
    Options = {"Melee", "Sword", "Fruit", "Gun"},
    CurrentOption = "Melee",
    Callback = function(v)
        SelectedWeapon = v
    end
})

Tab:CreateToggle({
    Name = "Auto Farm (MAX ATTACK)",
    CurrentValue = false,
    Callback = function(v)
        Settings.AutoFarm = v
        ToggleNoclip(v)
    end
})

Tab:CreateSlider({
    Name = "Tốc độ Tween (Speed)",
    Range = {300, 500},
    Increment = 1,
    CurrentValue = Settings.TweenSpeed,
    Callback = function(v)
        Settings.TweenSpeed = v
    end
})

Tab:CreateSlider({
    Name = "Radius Bring Mob",
    Range = {100, 300},
    Increment = 1,
    CurrentValue = Settings.BringRadius,
    Callback = function(v)
        Settings.BringRadius = v
    end
})
