local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
    Name = "Block Kid",
    LoadingTitle = "Skidd is my life",
    LoadingSubtitle = "Huyyeuem",
    Theme = "Green",
    ToggleUIKeybind = Enum.KeyCode.RightControl,
    ConfigurationSaving = { Enabled = false }
})

local Tab = Window:CreateTab("Main Farm")
local StatsTab = Window:CreateTab("Stats & Points")
local Setting = Window:CreateTab("Setting")

-- ===== SERVICES =====
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- Biến hỗ trợ logic
local Mon, Qname, Qdata, NameMon, PosM, PosQ
local isWaitingQuest = false

Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ===== SETTINGS & VARIABLES =====
_G.Settings = {
    AutoFarm = false,
    BringMob = true,
    FarmNearest = false,
    TweenHeight = 24,
    TweenSpeed = 350,
    BringRadius = 200,
    AutoStatEnabled = false,
    StatTarget = "Melee",
    AutoEquip = true,
    Weapon = "Melee",
    AutoHaki = true
}
local Settings = _G.Settings
local currentTween
local lastBringTick = 0
local NPC_Sub_Pos = CFrame.new(-16269.4, 23.9, 1371.6)


local Sea1 = false
local Sea2 = false
local Sea3 = false
local v6 = game.PlaceId
if v6 == 2753915549 then
    Sea1 = true
elseif v6 == 4442272183 or v6 == 79091703265657 then -- Thêm v6 == ở đây
    Sea2 = true
elseif v6 == 7449423635 or v6 == 100117331123089 then -- Thêm v6 == ở đây
    Sea3 = true
end

local function Tween(targetCFrame)
    if not HRP or not targetCFrame then return end
    local dist = (HRP.Position - targetCFrame.p).Magnitude
    
    if currentTween then currentTween:Cancel() end
    
    local tweenTime = dist / _G.Settings.TweenSpeed
    currentTween = TweenService:Create(HRP, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
    currentTween:Play()
    return currentTween
end


-- ===== HELPER FUNCTIONS =====
local function Alive(m)
    local h = m:FindFirstChild("Humanoid")
    return h and h.Health > 0 and m:FindFirstChild("HumanoidRootPart")
end

local function ResetMobPhysics()
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then
        for _, m in pairs(enemies:GetChildren()) do
            for _, p in pairs(m:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
            if m:FindFirstChild("HumanoidRootPart") then m.HumanoidRootPart.Anchored = false end
            if m:FindFirstChild("Humanoid") then m.Humanoid.WalkSpeed = 16 end
        end
    end
end

local function CheckPlayerAlive()
    if not Character or not Character.Parent or not Humanoid or Humanoid.Health <= 0 then
        Character = Player.Character or Player.CharacterAdded:Wait()
        HRP = Character:WaitForChild("HumanoidRootPart")
        Humanoid = Character:WaitForChild("Humanoid")
        return false -- Vừa hồi sinh, đợi vòng lặp sau farm tiếp
    end
    return true
end

local function UpdateHover()
    if not HRP then return end 
    local bv = HRP:FindFirstChild("FarmHover")

    if Settings.FarmNearest or Settings.AutoFarm then
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "FarmHover"
            bv.MaxForce = Vector3.new(0, math.huge, 0) 
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = HRP
        else
            bv.Velocity = Vector3.new(0, 0, 0)
        end
    else
        if bv then bv:Destroy() end
    end
end

local function ToggleNoclip(state)
    if state then
        _G.NoclipConn = RunService.Stepped:Connect(function()
            if Character then
                for _, v in pairs(Character:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
        end)
    else
        if _G.NoclipConn then _G.NoclipConn:Disconnect(); _G.NoclipConn = nil end
    end
end


local function AddStat(name, amount)
    local remote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_")
    if remote then
        pcall(function()
            remote:InvokeServer("AddPoint", name, 5)
        end)
    end
end


local function EquipWeapon()
    if not Settings.AutoEquip then return end
    
    -- Nếu đã cầm đúng loại vũ khí rồi thì không chạy tiếp (tránh lag tay)
    local currentTool = Character:FindFirstChildOfClass("Tool")
    if currentTool and currentTool.ToolTip == Settings.Weapon then 
        return 
    end
    
    -- Nếu đang cầm sai loại hoặc không cầm gì, thì tìm trong Backpack
    local inventory = Player.Backpack:GetChildren()
    for _, tool in pairs(inventory) do
        if tool:IsA("Tool") and tool.ToolTip == Settings.Weapon then
            -- Cất vũ khí cũ nếu đang cầm sai loại
            if currentTool then 
                currentTool.Parent = Player.Backpack 
            end
            -- Trang bị vũ khí đúng
            Humanoid:EquipTool(tool)
            break
        end
    end
end

local function ActiveHaki()
    if not Settings.AutoHaki then return end
    if not Character:FindFirstChild("HasBuso") then
        local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
        if remote then
            remote:InvokeServer("Buso")
        end
    end
end

-- ===== LEVEL =====
local function UpdateQuestData()
    local a = Player.Data.Level.Value
    
    -- Reset các biến teleport nếu cần
    local function CheckTeleport(targetPos, entrancePos)
        local dist = (targetPos - HRP.Position).Magnitude
        if Settings.AutoFarm and dist > 10000 then
            ReplicatedStorage.Remotes.CommF_:InvokeServer("requestEntrance", entrancePos)
            task.wait(1)
        end
    end

    if Sea1 then
        if a >= 1 and a <= 9 then
            if tostring(Player.Team) == "Marines" then
                Mon = "Trainee"; Qname = "MarineQuest"; Qdata = 1; NameMon = "Trainee"
                PosQ = CFrame.new(-2709, 25, 2104); PosM = PosQ
            else
                Mon = "Bandit"; Qname = "BanditQuest1"; Qdata = 1; NameMon = "Bandit"
                PosQ = CFrame.new(1059, 16, 1546); PosM = CFrame.new(1045, 26, 1560)
            end
        elseif a >= 10 and a <= 14 then
            Mon = "Monkey"; Qdata = 1; Qname = "JungleQuest"; NameMon = "Monkey"
            PosQ = CFrame.new(-1598, 36, 153); PosM = CFrame.new(-1448, 68, 11)
        elseif a >= 15 and a <= 29 then
            Mon = "Gorilla"; Qdata = 2; Qname = "JungleQuest"; NameMon = "Gorilla"
            PosQ = CFrame.new(-1598, 36, 153); PosM = CFrame.new(-1129, 41, -525)
        elseif a >= 30 and a <= 39 then
            Mon = "Pirate"; Qdata = 1; Qname = "BuggyQuest1"; NameMon = "Pirate"
            PosQ = CFrame.new(-1141, 5, 3831); PosM = CFrame.new(-1103, 14, 3896)
        elseif a >= 40 and a <= 59 then
            Mon = "Brute"; Qdata = 2; Qname = "BuggyQuest1"; NameMon = "Brute"
            PosQ = CFrame.new(-1141, 5, 3831); PosM = CFrame.new(-1140, 15, 4322)
        elseif a >= 60 and a <= 74 then
            Mon = "Desert Bandit"; Qdata = 1; Qname = "DesertQuest"; NameMon = "Desert Bandit"
            PosQ = CFrame.new(894, 5, 4392); PosM = CFrame.new(924, 6, 4481)
        elseif a >= 75 and a <= 89 then
            Mon = "Desert Officer"; Qdata = 2; Qname = "DesertQuest"; NameMon = "Desert Officer"
            PosQ = CFrame.new(894, 5, 4392); PosM = CFrame.new(1608, 9, 4371)
        elseif a >= 90 and a <= 99 then
            Mon = "Snow Bandit"; Qdata = 1; Qname = "SnowQuest"; NameMon = "Snow Bandit"
            PosQ = CFrame.new(1389, 88, -1298); PosM = CFrame.new(1354, 87, -1393)
        elseif a >= 100 and a <= 119 then
            Mon = "Snowman"; Qdata = 2; Qname = "SnowQuest"; NameMon = "Snowman"
            PosQ = CFrame.new(1389, 88, -1298); PosM = CFrame.new(1241, 51, -1243)
        elseif a >= 120 and a <= 149 then
            Mon = "Chief Petty Officer"; Qdata = 1; Qname = "MarineQuest2"; NameMon = "Chief Petty Officer"
            PosQ = CFrame.new(-5039, 27, 4324); PosM = CFrame.new(-4881, 23, 4273)
        elseif a >= 150 and a <= 174 then
            Mon = "Sky Bandit"; Qdata = 1; Qname = "SkyQuest"; NameMon = "Sky Bandit"
            PosQ = CFrame.new(-4839, 716, -2619); PosM = CFrame.new(-4953, 296, -2899)
        elseif a >= 175 and a <= 189 then
            Mon = "Dark Master"; Qdata = 2; Qname = "SkyQuest"; NameMon = "Dark Master"
            PosQ = CFrame.new(-4839, 716, -2619); PosM = CFrame.new(-5259, 391, -2229)
        elseif a >= 190 and a <= 209 then
            Mon = "Prisoner"; Qdata = 1; Qname = "PrisonerQuest"; NameMon = "Prisoner"
            PosQ = CFrame.new(5308, 2, 475); PosM = CFrame.new(5098, 1, 474)
        elseif a >= 210 and a <= 249 then
            Mon = "Dangerous Prisoner"; Qdata = 2; Qname = "PrisonerQuest"; NameMon = "Dangerous Prisoner"
            PosQ = CFrame.new(5308, 2, 475); PosM = CFrame.new(5654, 16, 866)
        elseif a >= 250 and a <= 274 then
            Mon = "Toga Warrior"; Qdata = 1; Qname = "ColosseumQuest"; NameMon = "Toga Warrior"
            PosQ = CFrame.new(-1580, 6, -2986); PosM = CFrame.new(-1820, 52, -2740)
        elseif a >= 275 and a <= 299 then
            Mon = "Gladiator"; Qdata = 2; Qname = "ColosseumQuest"; NameMon = "Gladiator"
            PosQ = CFrame.new(-1580, 6, -2986); PosM = CFrame.new(-1292, 56, -3339)
        elseif a >= 300 and a <= 324 then
            Mon = "Military Soldier"; Qdata = 1; Qname = "MagmaQuest"; NameMon = "Military Soldier"
            PosQ = CFrame.new(-5313, 11, 8515); PosM = CFrame.new(-5411, 11, 8454)
        elseif a >= 325 and a <= 374 then
            Mon = "Military Spy"; Qdata = 2; Qname = "MagmaQuest"; NameMon = "Military Spy"
            PosQ = CFrame.new(-5313, 11, 8515); PosM = CFrame.new(-5802, 86, 8828)
        elseif a >= 375 and a <= 399 then
            Mon = "Fishman Warrior"; Qdata = 1; Qname = "FishmanQuest"; NameMon = "Fishman Warrior"
            PosQ = CFrame.new(61122, 18, 1569); PosM = CFrame.new(60878, 18, 1543)
            CheckTeleport(PosQ.Position, Vector3.new(61163, 11, 1819))
        elseif a >= 400 and a <= 449 then
            Mon = "Fishman Commando"; Qdata = 2; Qname = "FishmanQuest"; NameMon = "Fishman Commando"
            PosQ = CFrame.new(61122, 18, 1569); PosM = CFrame.new(61922, 18, 1493)
            CheckTeleport(PosQ.Position, Vector3.new(61163, 11, 1819))
        elseif a >= 450 and a <= 474 then
            Mon = "God's Guard"; Qdata = 1; Qname = "SkyExp1Quest"; NameMon = "God's Guard"
            PosQ = CFrame.new(-4721, 843, -1949); PosM = CFrame.new(-4710, 845, -1927)
            CheckTeleport(PosQ.Position, Vector3.new(-4607, 872, -1667))
        elseif a >= 475 and a <= 524 then
            Mon = "Shanda"; Qdata = 2; Qname = "SkyExp1Quest"; NameMon = "Shanda"
            PosQ = CFrame.new(-7859, 5544, -381); PosM = CFrame.new(-7678, 5566, -497)
            CheckTeleport(PosQ.Position, Vector3.new(-7894, 5547, -380))
        elseif a >= 525 and a <= 549 then
            Mon = "Royal Squad"; Qdata = 1; Qname = "SkyExp2Quest"; NameMon = "Royal Squad"
            PosQ = CFrame.new(-7906, 5634, -1411); PosM = CFrame.new(-7635, 5637, -1408)
        elseif a >= 550 and a <= 624 then
            Mon = "Royal Guard"; Qname = "SkyExp2Quest"; Qdata = 2; NameMon = "Royal Guard"
            PosQ = CFrame.new(-7906, 5634, -1411); PosM = CFrame.new(-7658, 5623, -1450)
            CheckTeleport(PosQ.Position, Vector3.new(-7894, 5547, -380))
        elseif a >= 625 and a <= 649 then
            Mon = "Galley Pirate"; Qname = "FontaineQuest"; Qdata = 1; NameMon = "Galley Pirate"
            PosQ = CFrame.new(5256, 38, 4050); PosM = CFrame.new(5589, 39, 3996)
        elseif a >= 650 and a <= 699 then
            Mon = "Galley Captain"; Qname = "FontaineQuest"; Qdata = 2; NameMon = "Galley Captain"
            PosQ = CFrame.new(5256, 38, 4050); PosM = CFrame.new(5649, 39, 4936)
        end
    elseif Sea2 then
        if a >= 700 and a <= 724 then
            Mon = "Raider"; Qname = "Area1Quest"; Qdata = 1; NameMon = "Raider"
            PosQ = CFrame.new(-425, 73, 1837); PosM = CFrame.new(-742, 93, 1588)
        elseif a >= 725 and a <= 774 then
            Mon = "Mercenary"; Qname = "Area1Quest"; Qdata = 2; NameMon = "Mercenary"
            PosQ = CFrame.new(-425, 73, 1837); PosM = CFrame.new(-1022, 93, 1678)
        elseif a >= 775 and a <= 799 then
            Mon = "Swan Pirate"; Qname = "Area2Quest"; Qdata = 1; NameMon = "Swan Pirate"
            PosQ = CFrame.new(634, 73, 918); PosM = CFrame.new(878, 122, 1212)
        elseif a >= 800 and a <= 874 then
            Mon = "Factory Staff"; Qname = "Area2Quest"; Qdata = 2; NameMon = "Factory Staff"
            PosQ = CFrame.new(634, 73, 918); PosM = CFrame.new(295, 73, -55)
        elseif a >= 875 and a <= 899 then
            Mon = "Marine Lieutenant"; Qname = "MarineQuest3"; Qdata = 1; NameMon = "Marine Lieutenant"
            PosQ = CFrame.new(-2441, 73, -3220); PosM = CFrame.new(-2820, 73, -3075)
        elseif a >= 900 and a <= 949 then
            Mon = "Marine Captain"; Qname = "MarineQuest3"; Qdata = 2; NameMon = "Marine Captain"
            PosQ = CFrame.new(-2441, 73, -3220); PosM = CFrame.new(-1869, 73, -3320)
        elseif a >= 950 and a <= 974 then
            Mon = "Zombie"; Qname = "ZombieQuest"; Qdata = 1; NameMon = "Zombie"
            PosQ = CFrame.new(-5495, 48, -795); PosM = CFrame.new(-5721, 48, -718)
        elseif a >= 975 and a <= 1049 then
            Mon = "Vampire"; Qname = "ZombieQuest"; Qdata = 2; NameMon = "Vampire"
            PosQ = CFrame.new(-5495, 48, -795); PosM = CFrame.new(-6033, 7, -1317)
        elseif a >= 1050 and a <= 1074 then
            Mon = "Snow Trooper"; Qname = "SnowMountainQuest"; Qdata = 1; NameMon = "Snow Trooper"
            PosQ = CFrame.new(607, 401, -5371); PosM = CFrame.new(478, 401, -5343)
        elseif a >= 1075 and a <= 1124 then
            Mon = "Winter Warrior"; Qname = "SnowMountainQuest"; Qdata = 2; NameMon = "Winter Warrior"
            PosQ = CFrame.new(607, 401, -5371); PosM = CFrame.new(1157, 430, -5188)
        elseif a >= 1125 and a <= 1149 then
            Mon = "Lab Subordinate"; Qname = "IceSideQuest"; Qdata = 1; NameMon = "Lab Subordinate"
            PosQ = CFrame.new(-6061, 16, -4905); PosM = CFrame.new(-6503, 20, -5803)
        elseif a >= 1150 and a <= 1224 then
            Mon = "Horned Marine"; Qname = "IceSideQuest"; Qdata = 2; NameMon = "Horned Marine"
            PosQ = CFrame.new(-6061, 16, -4905); PosM = CFrame.new(-6384, 16, -4467)
        elseif a >= 1225 and a <= 1249 then
            Mon = "Magma Ninja"; Qname = "FireSideQuest"; Qdata = 1; NameMon = "Magma Ninja"
            PosQ = CFrame.new(-5430, 16, -5295); PosM = CFrame.new(-5405, 16, -5863)
        elseif a >= 1250 and a <= 1324 then
            Mon = "Lava Pirate"; Qname = "FireSideQuest"; Qdata = 2; NameMon = "Lava Pirate"
            PosQ = CFrame.new(-5430, 16, -5295); PosM = CFrame.new(-5270, 16, -4800)
        elseif a >= 1325 and a <= 1349 then
            Mon = "Ship Pirate"; Qname = "ShipQuest1"; Qdata = 1; NameMon = "Ship Pirate"
            PosQ = CFrame.new(1038, 125, 32911); PosM = CFrame.new(906, 125, 33034)
        elseif a >= 1350 and a <= 1424 then
            Mon = "Ship Engineer"; Qname = "ShipQuest1"; Qdata = 2; NameMon = "Ship Engineer"
            PosQ = CFrame.new(1038, 125, 32911); PosM = CFrame.new(917, 125, 32740)
        elseif a >= 1425 and a <= 1449 then
            Mon = "Ship Steward"; Qname = "ShipQuest2"; Qdata = 1; NameMon = "Ship Steward"
            PosQ = CFrame.new(969, 125, 33245); PosM = CFrame.new(915, 130, 33419)
        elseif a >= 1450 and a <= 1474 then
            Mon = "Ship Officer"; Qname = "ShipQuest2"; Qdata = 2; NameMon = "Ship Officer"
            PosQ = CFrame.new(969, 125, 33245); PosM = CFrame.new(685, 130, 33230)
        end
    elseif Sea3 then
        if a >= 1500 and a <= 1524 then
            Mon = "Pirate Millionaire"; Qname = "TurtleQuest1"; Qdata = 1; NameMon = "Pirate Millionaire"
            PosQ = CFrame.new(-11485, 14, -13180); PosM = CFrame.new(-11440, 14, -12750)
        elseif a >= 1525 and a <= 1574 then
            Mon = "Pistol Billionaire"; Qname = "TurtleQuest1"; Qdata = 2; NameMon = "Pistol Billionaire"
            PosQ = CFrame.new(-11485, 14, -13180); PosM = CFrame.new(-11590, 80, -12810)
        elseif a >= 1575 and a <= 1624 then
            Mon = "Dragon Crew Warrior"; Qname = "TurtleQuest2"; Qdata = 1; NameMon = "Dragon Crew Warrior"
            PosQ = CFrame.new(-13233, 404, -7767); PosM = CFrame.new(-13390, 404, -7640)
        elseif a >= 1625 and a <= 1699 then
            Mon = "Dragon Crew Archer"; Qname = "TurtleQuest2"; Qdata = 2; NameMon = "Dragon Crew Archer"
            PosQ = CFrame.new(-13233, 404, -7767); PosM = CFrame.new(-13500, 440, -7800)
        elseif a >= 1700 and a <= 1724 then
            Mon = "Female Island Pirate"; Qname = "HydraQuest1"; Qdata = 1; NameMon = "Female Island Pirate"
            PosQ = CFrame.new(5740, 601, -210); PosM = CFrame.new(5815, 601, -300)
        elseif a >= 1725 and a <= 1774 then
            Mon = "Giant Island Pirate"; Qname = "HydraQuest1"; Qdata = 2; NameMon = "Giant Island Pirate"
            PosQ = CFrame.new(5740, 601, -210); PosM = CFrame.new(5560, 601, -110)
        elseif a >= 1775 and a <= 1799 then
            Mon = "Forest Pirate"; Qname = "DeepForestQuest1"; Qdata = 1; NameMon = "Forest Pirate"
            PosQ = CFrame.new(-13240, 331, -131); PosM = CFrame.new(-13440, 331, -300)
        elseif a >= 1800 and a <= 1874 then
            Mon = "Mythical Pirate"; Qname = "DeepForestQuest1"; Qdata = 2; NameMon = "Mythical Pirate"
            PosQ = CFrame.new(-13240, 331, -131); PosM = CFrame.new(-13550, 470, -430)
        elseif a >= 1875 and a <= 1899 then
            Mon = "Jungle Pirate"; Qname = "DeepForestQuest2"; Qdata = 1; NameMon = "Jungle Pirate"
            PosQ = CFrame.new(-12680, 390, -2250); PosM = CFrame.new(-12100, 330, -2350)
        elseif a >= 1900 and a <= 1974 then
            Mon = "Musketeer Pirate"; Qname = "DeepForestQuest2"; Qdata = 2; NameMon = "Musketeer Pirate"
            PosQ = CFrame.new(-12680, 390, -2250); PosM = CFrame.new(-13280, 390, -2370)
        elseif a >= 1975 and a <= 1999 then
            Mon = "Reborn Skeleton"; Qname = "HauntedQuest1"; Qdata = 1; NameMon = "Reborn Skeleton"
            PosQ = CFrame.new(-9515, 162, 5786); PosM = CFrame.new(-9350, 162, 6130)
        elseif a >= 2000 and a <= 2074 then
            Mon = "Living Zombie"; Qname = "HauntedQuest1"; Qdata = 2; NameMon = "Living Zombie"
            PosQ = CFrame.new(-9515, 162, 5786); PosM = CFrame.new(-10150, 162, 5820)
        elseif a >= 2075 and a <= 2099 then
            Mon = "Demonic Soul"; Qname = "HauntedQuest2"; Qdata = 1; NameMon = "Demonic Soul"
            PosQ = CFrame.new(-9515, 162, 5786); PosM = CFrame.new(-9500, 162, 5450)
        elseif a >= 2100 and a <= 2199 then
            Mon = "Posessed Mummy"; Qname = "HauntedQuest2"; Qdata = 2; NameMon = "Posessed Mummy"
            PosQ = CFrame.new(-9515, 162, 5786); PosM = CFrame.new(-10500, 162, 5950)
        elseif a >= 2200 and a <= 2224 then
            Mon = "Cookie Crafter"; Qname = "IceCreamIslandQuest1"; Qdata = 1; NameMon = "Cookie Crafter"
            PosQ = CFrame.new(-900, 65, -12100); PosM = CFrame.new(-1050, 65, -12050)
        elseif a >= 2225 and a <= 2274 then
            Mon = "Cake Guard"; Qname = "IceCreamIslandQuest1"; Qdata = 2; NameMon = "Cake Guard"
            PosQ = CFrame.new(-900, 65, -12100); PosM = CFrame.new(-750, 65, -12300)
        elseif a >= 2275 and a <= 2299 then
            Mon = "Baking Staff"; Qname = "CakeIslandQuest1"; Qdata = 1; NameMon = "Baking Staff"
            PosQ = CFrame.new(-1910, 38, -12810); PosM = CFrame.new(-1800, 38, -12950)
        elseif a >= 2300 and a <= 2374 then
            Mon = "Head Baker"; Qname = "CakeIslandQuest1"; Qdata = 2; NameMon = "Head Baker"
            PosQ = CFrame.new(-1910, 38, -12810); PosM = CFrame.new(-2050, 38, -13100)
        elseif a >= 2375 and a <= 2399 then
            Mon = "Cocoa Warrior"; Qname = "CandyIslandQuest1"; Qdata = 1; NameMon = "Cocoa Warrior"
            PosQ = CFrame.new(-1160, 15, -14250); PosM = CFrame.new(-1050, 15, -14150)
        elseif a >= 2400 and a <= 2449 then
            Mon = "Chocolate Bar Battler"; Qname = "CandyIslandQuest1"; Qdata = 2; NameMon = "Chocolate Bar Battler"
            PosQ = CFrame.new(-1160, 15, -14250); PosM = CFrame.new(-1000, 65, -14550)
        elseif a >= 2450 and a <= 2474 then
            Mon = "Isle Outlaw"; Qname = "TikiQuest1"; Qdata = 1; NameMon = "Isle Outlaw"
            PosQ = CFrame.new(-16548, 55, -172); PosM = CFrame.new(-16479, 226, -300)
        elseif a >= 2475 and a <= 2499 then
            Mon = "Island Boy"; Qname = "TikiQuest1"; Qdata = 2; NameMon = "Island Boy"
            PosQ = CFrame.new(-16548, 55, -172); PosM = CFrame.new(-16849, 192, -150)
        elseif a >= 2500 and a <= 2524 then
            Mon = "Sun-kissed Warrior"; Qname = "TikiQuest2"; Qdata = 1; NameMon = "Sun-kissed Warrior" -- Sửa lỗi thiếu chữ "Sun-"
            PosQ = CFrame.new(-16538, 55, 1049); PosM = CFrame.new(-16347, 64, 984)
        elseif a >= 2525 and a <= 2550 then
            Mon = "Isle Champion"; Qname = "TikiQuest2"; Qdata = 2; NameMon = "Isle Champion"
            PosQ = CFrame.new(-16541, 57, 1051); PosM = CFrame.new(-16602, 130, 1087)
        elseif a >= 2551 and a <= 2574 then
            Mon = "Serpent Hunter"; Qname = "TikiQuest3"; Qdata = 1; NameMon = "Serpent Hunter"
            PosQ = CFrame.new(-16679, 176, 1474); PosM = PosQ
        elseif a >= 2575 and a <= 2599 then
            Mon = "Skull Slayer"; Qname = "TikiQuest3"; Qdata = 2; NameMon = "Skull Slayer"
            PosQ = CFrame.new(-16759, 71, 1595); PosM = PosQ
        elseif a >= 2600 and a <= 2624 then
            Mon = "Reef Bandit"; Qname = "SubmergedQuest1"; Qdata = 1; NameMon = "Reef Bandit"
            PosQ = CFrame.new(10882, -2086, 10034); PosM = CFrame.new(10736, -2087, 9338)
        elseif a >= 2625 and a <= 2649 then
            Mon = "Coral Pirate"; Qname = "SubmergedQuest1"; Qdata = 2; NameMon = "Coral Pirate"
            PosQ = CFrame.new(10882, -2086, 10034); PosM = CFrame.new(10965, -2158, 9177)
        elseif a >= 2650 and a <= 2674 then
            Mon = "Sea Chanter"; Qname = "SubmergedQuest2"; Qdata = 1; NameMon = "Sea Chanter"
            PosQ = CFrame.new(10882, -2086, 10034); PosM = CFrame.new(10621, -2087, 10102)
        elseif a >= 2675 and a <= 2699 then
            Mon = "Ocean Prophet"; Qname = "SubmergedQuest2"; Qdata = 2; NameMon = "Ocean Prophet"
            PosQ = CFrame.new(10882, -2086, 10034); PosM = CFrame.new(11056, -2001, 10117)
        elseif a >= 2700 and a <= 2724 then
            Mon = "High Disciple"; Qname = "SubmergedQuest3"; Qdata = 1; NameMon = "High Disciple"
            PosQ = CFrame.new(9638, -1993, 9615); PosM = CFrame.new(9818.4014, -1962.3967, 9810.8350)
        elseif a >= 2725 then
            Mon = "Grand Devotee";  Qname = "SubmergedQuest3"; Qdata = 2; NameMon = "Grand Devotee"
            PosQ = CFrame.new(9638, -1993, 9615); PosM = CFrame.new(9585.79, -1912.35, 9822.90)
        end
    end
end


-- ===== MAIN FARM LOOP =====
task.spawn(function()
    local lastBringTick = 0
    local BypassDist = 250
    local isWaitingQuest = false

    while true do
        task.wait()
        if not Character or not Character.Parent or not HRP or not Humanoid or Humanoid.Health <= 0 then
            Character = Player.Character
            if Character then
                HRP = Character:FindFirstChild("HumanoidRootPart")
                Humanoid = Character:FindFirstChild("Humanoid")
            end
            if currentTween then currentTween:Cancel() end
            continue -- Nhảy qua vòng lặp này để đợi nhân vật sẵn sàng
        end
        
        if (Settings.AutoFarm or Settings.FarmNearest) and HRP and Humanoid.Health > 0 then
            
            -- Biến dùng chung cho cả 2 chế độ
            local targetMob = nil
            
            if Settings.FarmNearest then
                -- Tìm quái gần nhất không phân biệt tên
                local dist = math.huge
                for _, m in pairs(Workspace.Enemies:GetChildren()) do
                    if Alive(m) then
                        local d = (m.HumanoidRootPart.Position - HRP.Position).Magnitude
                        if d < dist then dist = d; targetMob = m end
                    end
                end
            elseif Settings.AutoFarm then
                UpdateQuestData()
                
                -- Logic Travel (Dành riêng cho Farm Level)
                if Player.Data.Level.Value >= 2675 and HRP.Position.Y > -500 then
                    local distToSub = (HRP.Position - NPC_Sub_Pos.p).Magnitude
                    if distToSub > 20 then
                        Tween(NPC_Sub_Pos)
                    else
                        if currentTween then currentTween:Cancel() end
                        ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/SubmarineWorkerSpeak"):InvokeServer("TravelToSubmergedIsland")
                        task.wait(2)
                    end
                    continue
                end

                -- Logic Nhận Quest
                if not Player.PlayerGui.Main.Quest.Visible then
                    local distQ = (HRP.Position - PosQ.Position).Magnitude
                    if distQ > 12 then
                        Tween(PosQ)
                    else
                        if currentTween then currentTween:Cancel() end
                        HRP.CFrame = PosQ
                        if not isWaitingQuest then
                            isWaitingQuest = true
                            task.wait(1)
                            if not Player.PlayerGui.Main.Quest.Visible then
                                ReplicatedStorage.Remotes.CommF_:InvokeServer("StartQuest", Qname, Qdata)
                            end
                            isWaitingQuest = false
                        end
                    end
                else
                    -- Tìm đúng quái nhiệm vụ
                    for _, m in pairs(Workspace.Enemies:GetChildren()) do
                        if Alive(m) and m.Name == NameMon then
                            targetMob = m
                            break
                        end
                    end
                end
            end

            -- ==========================================
            -- LOGIC DI CHUYỂN VÀ BRING MOB (Y HỆT NHAU)
            -- ==========================================
            if targetMob then
                local targetHRP = targetMob.HumanoidRootPart
                -- Tọa độ đứng farm lệch để né đòn (Y hệt farm level)
                local targetPos = targetHRP.Position + Vector3.new(-4, Settings.TweenHeight, 5)
                local targetCFrame = CFrame.new(targetPos, targetPos + targetHRP.CFrame.LookVector)

                if (HRP.Position - targetPos).Magnitude > BypassDist then 
                    if currentTween then currentTween:Cancel() end 
                    local tweenTime = (HRP.Position - targetPos).Magnitude / Settings.TweenSpeed 
                    currentTween = TweenService:Create(HRP, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {CFrame = targetCFrame}) 
                    currentTween:Play() 
                else 
                    if currentTween then currentTween:Cancel() end 
                    HRP.CFrame = targetCFrame 
                    HRP.Velocity = Vector3.new(0,0,0)

                    -- Logic Bring Mob (Gom quái y hệt farm level)
                    if Settings.BringMob and (tick() - lastBringTick) >= 0.234 then
                        lastBringTick = tick()
                        for _, m in pairs(Workspace.Enemies:GetChildren()) do
                            -- Nếu farm Near thì gom mọi quái gần đó, nếu farm Level thì chỉ gom quái cùng tên
                            local canBring = false
                            if Settings.FarmNearest then
                                canBring = Alive(m)
                            else
                                canBring = Alive(m) and m.Name == NameMon
                            end

                            if canBring then
                                local mhrp = m.HumanoidRootPart
                                if (mhrp.Position - targetHRP.Position).Magnitude <= Settings.BringRadius then
                                    -- Noclip quái
                                    for _, p in pairs(m:GetDescendants()) do
                                        if p:IsA("BasePart") then p.CanCollide = false end
                                    end
                                    -- Đưa về tâm
                                    if m ~= targetMob then
                                        mhrp.CFrame = targetHRP.CFrame * CFrame.new(0, 0, math.random(-2,2)/3)
                                        mhrp.Velocity = Vector3.new(0,0,0)
                                    end
                                    m.Humanoid.WalkSpeed = 0
                                end
                            end
                        end
                    end
                end
            else
                if Settings.FarmNearest then
                    if currentTween then currentTween:Cancel() end
                    UpdateHover()
                end
    
                -- Nếu hết quái (Chỉ dành cho Farm Level để về bãi chờ)
                if Settings.AutoFarm and Player.PlayerGui.Main.Quest.Visible then
                    if currentTween then currentTween:Cancel() end
                    local distToM = (HRP.Position - PosM.p).Magnitude
                    currentTween = TweenService:Create(HRP, TweenInfo.new(distToM/Settings.TweenSpeed, Enum.EasingStyle.Linear), {CFrame = PosM * CFrame.new(0, 20, 0)})
                    currentTween:Play()
                end
            end
        end
    end
end)


-- ===== EXTREME ATTACK SYSTEM (FIXED) =====
task.spawn(function()
    local Net = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net")
    local RegisterAttack = Net:WaitForChild("RE/RegisterAttack")
    local RegisterHit = Net:WaitForChild("RE/RegisterHit")

    while true do
        task.wait() -- Đảm bảo vòng lặp mượt mà

        -- GỌI HÀM CỦA BẠN TẠI ĐÂY ĐỂ CẬP NHẬT CHARACTER/HRP/HUMANOID
        if CheckPlayerAlive() then 
            UpdateHover()
            ActiveHaki()
            
            -- Chỉ chạy Attack khi bật farm
            if (Settings.AutoFarm or Settings.FarmNearest) then
                pcall(function()
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if not enemies then return end
                    
                    local targets = {}
                    for _, m in pairs(enemies:GetChildren()) do
                        if Alive(m) then
                            local mHRP = m:FindFirstChild("HumanoidRootPart")
                            if mHRP then
                                -- Sử dụng HRP đã được CheckPlayerAlive cập nhật mới nhất
                                local dist = (mHRP.Position - HRP.Position).Magnitude
                                
                                local canHit = false
                                if Settings.FarmNearest then
                                    if dist <= (Settings.BringRadius or 250) + 50 then
                                        canHit = true
                                    end
                                elseif Settings.AutoFarm then
                                    if m.Name == NameMon and dist <= (Settings.BringRadius or 250) + 50 then
                                        canHit = true
                                    end
                                end

                                if canHit then
                                    table.insert(targets, {m, mHRP})
                                end
                            end
                        end
                    end

                    if #targets > 0 then
                        EquipWeapon()
                        if Character:FindFirstChildOfClass("Tool") then
                            for i = 1, 4 do 
                                RegisterAttack:FireServer(0.015)
                                RegisterHit:FireServer(targets[1][2], targets)
                            end
                        end
                    end
                end)
            end
        end
    end
end)

task.spawn(function()
    game:GetService("RunService").Stepped:Connect(function()
        if (Settings.AutoFarm or Settings.FarmNearest) and Character then
            for _, v in pairs(Character:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                end
            end
        end
    end)
end)

-- ===== UI ELEMENTS =====
Tab:CreateDropdown({
   Name = "Select Weapon",
   Options = {"Melee", "Sword", "Demon Fruit"},
   CurrentOption = {"Melee"},
   Callback = function(Option)
      Settings.Weapon = Option[1]
   end,
})

Tab:CreateToggle({
    Name = "Auto Farm Level",
    CurrentValue = false,
    Callback = function(v)
        Settings.AutoFarm = v
        UpdateHover()
        ToggleNoclip(v)
        if not v then
            if currentTween then currentTween:Cancel() end
            HRP.Velocity = Vector3.new(0,0,0)
            ResetMobPhysics()
            isWaitingQuest = false
        end
    end
})

Setting:CreateToggle({
    Name = "Bring Mob",
    CurrentValue = true,
    Callback = function(v)
        Settings.BringMob = v
        if not v then ResetMobPhysics() end
    end
})

Setting:CreateSlider({
    Name = "Tween Speed",
    Range = {100, 600},
    Increment = 10,
    CurrentValue = 350,
    Callback = function(v) Settings.TweenSpeed = v end
})

Tab:CreateToggle({
    Name = "Auto Farm Nearest",
    CurrentValue = false,
    Callback = function(v) 
        _G.Settings.FarmNearest = v 
        if not v then if currentTween then currentTween:Cancel() end end
    end
})

StatsTab:CreateDropdown({
   Name = "Select Stat Type",
   Options = {"Melee", "Defense", "Sword", "Gun", "Demon Fruit"},
   CurrentOption = {"Melee"},
   MultipleOptions = false,
   Callback = function(Option)
      Settings.StatTarget = Option[1]
   end,
})

StatsTab:CreateToggle({
   Name = "Auto Add Stats",
   CurrentValue = false,
   Callback = function(Value)
       Settings.AutoStatEnabled = Value
       if Value then
           task.spawn(function()
               while Settings.AutoStatEnabled do
                   if Player.Data.Points.Value > 0 then
                       AddStat(Settings.StatTarget, 1)
                   end
                   task.wait(0.5)
               end
           end)
       end
   end,
})
Rayfield:LoadConfiguration()


