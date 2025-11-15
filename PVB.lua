local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")


local backpack = LocalPlayer:WaitForChild("Backpack")
local attackEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AttacksServer"):WaitForChild("WeaponAttack")
local missionFolder = workspace:WaitForChild("ScriptedMap"):WaitForChild("MissionBrainrots")

local Seeds = {"Cactus Seed", "Strawberry Seed", "Pumpkin Seed", "Sunflower Seed", "Dragon Fruit Seed", "Eggplant Seed", "Watermelon Seed", "Grape Seed", "Cocotank Seed", "Carnivorous Plant Seed", "Mr Carrot Seed", "Tomatrio Seed", "Shroobino Seed", "Mango Seed", "King Limone Seed", "Starfruit Seed"}
local Gears = {"Water Bucket", "Frost Grenade", "Banana Gun", "Frost Blower", "Carrot Laucher"}

LocalPlayer.Idled:Connect(function()
VirtualUser:CaptureController()
end)


-- buy seed
local seeddachon = {}
local function autobuyseed()
    for _, seed in pairs(seeddachon) do
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("BuyItem"):FireServer(seed, true)
        task.wait(0.1)
    end
end


-- buy gear
local geardachon = {}
local function autobuygear()
    for _, gear in pairs(geardachon) do
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("BuyGear"):FireServer(gear, true)
        task.wait(0.1)
    end
end




local equipen = false
local delayeq = 30
local function eqbr()
    while equipen do
        ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EquipBestBrainrots"):FireServer()
        task.wait(delayeq)
    end
end


-- noclip
local connection = nil

local function enableNoclip()
if connection then return end
connection = RunService.Stepped:Connect(function()
    local character = LocalPlayer.Character
    if character then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)
end

local function disableNoclip()
if connection then
    connection:Disconnect()
    connection = nil
end
end


local function startAutoEquip()
    if AutoEquipActive then return end
    AutoEquipActive = true
    task.spawn(function()
        while AutoEquipActive do
            local tool
            for _, t in pairs(backpack:GetChildren()) do
                if t:IsA("Tool") and t.Name:sub(-3) == "Bat" then
                    tool = t
                    break
                end
            end
            if tool then
                local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
                if humanoid then
                    local currentTool = LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
                    if currentTool ~= tool then
                        if currentTool then
                            humanoid:UnequipTools()
                            task.wait(0.2)
                        end
                        humanoid:EquipTool(tool)
                        task.wait(0.2)
                    end
                end
            end
            task.wait(0.8)
        end
    end)
end

-- stop auto equip
local function stopAutoEquip()
    AutoEquipActive = false
end




-- Get Brainrot IDs for attacks
local function getBrainrotIds()
local missionIds = {}
for _, mob in pairs(missionFolder:GetChildren()) do
    local id = mob:GetAttribute("ID")
    if id then
        table.insert(missionIds, id)
    end
end
return missionIds
end





-- KillAura
local KillAuraActive = false
local function killaura()
    while KillAuraActive do
        local missionIds = getBrainrotIds()
        if #missionIds > 0 then
            local args = {{
                NormalBrainrots = {},
                MissionBrainrots = missionIds
            }}
            attackEvent:FireServer(unpack(args))
            task.wait(0.1)
        else
            task.wait(0.3)
        end
    end
end

-- Tween đến mob duy nhất cho đến khi nó biến mất
local function tweenToOneMob()
    while KillAuraActive do
        local mob = nil
        local closestDistance = math.huge
        for _, m in pairs(missionFolder:GetChildren()) do
            if m:IsA("Model") and m:GetAttribute("ID") then
                local pivot = m:GetPivot()
                local dist = (HumanoidRootPart.Position - pivot.Position).Magnitude
                if dist < closestDistance then
                    closestDistance = dist
                    mob = m
                end
            end
        end

        if mob and mob.Parent == missionFolder then
            while KillAuraActive and mob.Parent == missionFolder do
                local targetPos = mob:GetPivot()
                HumanoidRootPart.CFrame = targetPos
                task.wait(0.02)
            end
        else
            task.wait(0.7)
        end
    end
end







--  UI
local Fluent = loadstring(Game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/Beta.lua", true))()
local Window = Fluent:CreateWindow({
    Title = "PVB Script",
    SubTitle = "by quachlehuy",
    TabWidth = 120,
    Size = UDim2.fromOffset(485, 370),
    Acrylic = true, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})
local Tabs = {
    Farm = Window:AddTab({ Title = "Farm", Icon = "" }),
    Shop = Window:AddTab({ Title = "Shop", Icon = "" }),
    Player = Window:AddTab({ Title = "Player", Icon = "" })
}

local Options = Fluent.Options


Tabs.Farm:AddToggle("killaura", {Title="Auto Farm", Default=false}):OnChanged(function(Value)
    KillAuraActive = Value
    if Value then
        enableNoclip()
        startAutoEquip()
        task.spawn(killaura)
        task.spawn(tweenToOneMob)
    else
        stopAutoEquip()
        disableNoclip()
    end
end)


Tabs.Farm:AddInput("Delayeq", {Title="Delay Equip", Default=30, Numeric=true, Finished=true, Callback=function(Value)
    local num = tonumber(Value)
    if num then
        delayeq = num
    else
        delayeq = 30
    end
end})


Tabs.Farm:AddToggle("autoeq", {Title="Auto Equip", Default=false}):OnChanged(function(Value)
    equipen = Value
    if Value then
        eqbr()
    end
end)


Tabs.Shop:AddDropdown("Select Seed", {Title="Select Seed", Values=Seeds, Multi=true, Default=""}):OnChanged(function(Value)
    seeddachon = {}
    for val, _ in pairs(Value) do
        table.insert(seeddachon, val)
    end
end)

Tabs.Shop:AddToggle("AutoBuySeed", {Title="Auto Buy Seed", Default=false}):OnChanged(function(Value)
    task.spawn(function()
        while Options.AutoBuySeed.Value do
            if seeddachon and #seeddachon > 0 then autobuyseed() end
            task.wait(0.5)
        end
    end)
end)


Tabs.Shop:AddDropdown("Select Gear", {Title="Select Gear", Values=Gears, Multi=true, Default=""}):OnChanged(function(Value)
    geardachon = {}
    for val, _ in pairs(Value) do table.insert(geardachon, val) end
end)

Tabs.Shop:AddToggle("AutoBuyGear", {Title="Auto Buy Gear", Default=false}):OnChanged(function(Value)
    task.spawn(function()
        while Options.AutoBuyGear.Value do
            if geardachon and #geardachon > 0 then autobuygear() end
            task.wait(0.5)
        end
    end)
end)

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- UI setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Frame = Instance.new("Frame")
Frame.Parent = ScreenGui
Frame.Position = UDim2.new(0, 20, 0.1, -6)
Frame.Size = UDim2.new(0, 50, 0, 50)
Frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Frame.Name = "UIFrame"

local ImageLabel = Instance.new("ImageLabel")
ImageLabel.Parent = Frame
ImageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
ImageLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
ImageLabel.Size = UDim2.new(0, 40, 0, 40)
ImageLabel.BackgroundTransparency = 1
ImageLabel.Image = "http://www.roblox.com/asset/?id=5009915795"

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(1, 0)
UICorner.Parent = Frame

local TextButton = Instance.new("TextButton")
TextButton.Parent = Frame
TextButton.Size = UDim2.new(1, 0, 1, 0)
TextButton.BackgroundTransparency = 1
TextButton.Text = ""

-- Variables for drag
local dragging = false
local dragStart, startPos

Frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Frame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        Frame.Position = UDim2.new(0, startPos.X.Offset + delta.X, 0, startPos.Y.Offset + delta.Y)
    end
end)

-- Zoom + Fade toggle
local zoomedIn = false
local faded = false
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local fadeInTween = TweenService:Create(Frame, tweenInfo, {BackgroundTransparency = 0.25})
local fadeOutTween = TweenService:Create(Frame, tweenInfo, {BackgroundTransparency = 0})

TextButton.MouseButton1Click:Connect(function()
    local newSize = zoomedIn and UDim2.new(0, 40, 0, 40) or UDim2.new(0, 30, 0, 30)
    TweenService:Create(ImageLabel, tweenInfo, {Size = newSize}):Play()
    zoomedIn = not zoomedIn

    if faded then
        fadeOutTween:Play()
    else
        fadeInTween:Play()
    end
    faded = not faded

    -- Simulate key press for hotkey
    VirtualInputManager:SendKeyEvent(true, "LeftControl", false, game)
    VirtualInputManager:SendKeyEvent(false, "LeftControl", false, game)
end)
