local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
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

-- equipbrainrot
local function eqbr()
    while equiten do
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("EquipBestBrainrots"):FireServer()
        task.wait(delayeq)
    end
end

-- tween
local function TweenObject(Object, Pos, Speed)
    Speed = 350
    if not Object or not Pos then return end
    local Distance = (Pos.Position - Object.Position).Magnitude
    local info = TweenInfo.new(Distance / Speed, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(Object, info, {CFrame = Pos})
    tween:Play()
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


local AutoEquipActive = false

-- en auto equip
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
                            task.wait(0.05)
                        end
                        humanoid:EquipTool(tool)
                        task.wait(0.05)
                    end
                end
            end
            task.wait(0.1)
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
            task.wait(0.05)
        end
    end
end


-- Tween đến mob duy nhất cho đến khi nó biến mất
local function tweenToOneMob()
    while KillAuraActive do
        -- Lấy mob gần nhất
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
                local targetPos = mob:GetPivot() * CFrame.new(0, 1, 0)
                TweenObject(HumanoidRootPart, targetPos, 400)
                task.wait(0.05)
            end
        else
            task.wait(0.1) 
        end
    end
end











--  UI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = " PVB Script",
    Author = "by quachlehuy",
    Folder = "ftgshub",
    Icon = "bird",
    NewElements = true,
    Size = UDim2.fromOffset(485, 370),
    Theme = "Red",
    HideSearchBar = false,
    Background = "https://img4.thuthuatphanmem.vn/uploads/2020/04/07/hinh-nen-toi_061743174.jpg",
    OpenButton = {
        Title = "L HUB",
        CornerRadius = UDim.new(20,9),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = false,
        OnlyMobile = false,

        Color = ColorSequence.new(
            Color3.fromHex("#30FF6A"),
            Color3.fromHex("#e7ff2f")
        )
    }
})




local Tab = Window:Tab({
    Title = "Farm",
    Icon = "sword",
})

local Shop = Window:Tab({
	Title = "Shop",
	Icon = "shop"
})

Tab:Toggle({
    Title = "Kill Aura",
    Desc = "Auto Kill All Mob",
    Locked = false,
    Callback = function(Value)
        KillAuraActive = Value
        if Value then
            enableNoclip()
            task.spawn(startAutoEquip)
            task.spawn(killaura)
            task.spawn(tweenToOneMob)
        else
            disableNoclip()
            stopAutoEquip()
        end
    end
})


local delaymacdinh = 20
Tab:Input({
    Title = "Delay Equip",
    Value = delaymacdinh,
    Callback = function(value)
        delayeq = value or "default"
    end
})



Tab:Toggle({
    Title = "Auto Equip",
    Desc = "Auto Equip Best Brain Rot",
    Callback = function(Value)
        equiten = Value
    	if Value then
        	task.spawn(function()
                eqbr()
            end)
    	end
	end
})



Shop:Dropdown({
    Title = "Select Seed",
    Desc = "Choose seeds to buy",
    SearchBarEnabled = true,
    Multi = true,
    Values = Seeds,
    Icon = "file-plus",
    Callback = function(Value)
        seeddachon = {}
    	for _, v in ipairs(Value) do
            table.insert(seeddachon, v)
        end
    end
})


local autobuyseed_active = false

Shop:Toggle({
    Title = "Auto Buy Seed",
    Desc = "Automatically buy selected seeds",
    Callback = function(v)
        autobuyseed_active = v
        if v then
            task.spawn(function()
                while autobuyseed_active do
                    autobuyseed()
                    task.wait(0.001)
                end
            end)
        end
    end
})







Shop:Dropdown({
    Title = "Select Gear",
    Desc = "Choose gears to buy",
    Multi = true,
    Values = Gears,
    Icon = "file-plus",
    Callback = function(Value)
        geardachon = {}
    	for _, v in ipairs(Value) do
            table.insert(geardachon, v)
        end
    end
})


local autobuygear_active = false

Shop:Toggle({
    Title = "Auto Buy Gear",
    Desc = "Automatically buy selected gears",
    Callback = function(v)
        autobuygear_active = v
        if v then
            task.spawn(function()
                while autobuygear_active do
                    autobuygear()
                    task.wait(0.001)
                end
            end)
        end
    end
})
