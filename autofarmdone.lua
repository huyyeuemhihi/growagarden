repeat wait() until game:IsLoaded() and game.Players.LocalPlayer
task.wait(3)
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
local BossTab = Window:CreateTab("Boss Farm")

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

-- Cache remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NetModule = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")

-- ===== SETTINGS =====
_G.Settings = {
    AutoFarm = false,
    BringMob = true,
    FarmNearest = false,
    TweenHeight = 22,
    TweenSpeed = 350,
    BringRadius = 300,
    AutoStatEnabled = false,
    StatTarget = "Melee",
    AutoEquip = true,
    Weapon = "Melee",
    AutoHaki = true,
    FarmKata = false,
    FarmBone = false
}

local Settings = _G.Settings
local currentTween = nil
local NPC_Sub_Pos = CFrame.new(-16269.4, 23.9, 1371.6)

-- Sea detection
local Sea1 = game.PlaceId == 2753915549
local Sea2 = game.PlaceId == 4442272183 or game.PlaceId == 79091703265657
local Sea3 = game.PlaceId == 7449423635 or game.PlaceId == 100117331123089

-- Mob tracking
local lastBringTick = 0
local BypassDist = 250
local LockedMobs = {}
local OriginalCanCollide = {}
local ProcessedMobs = {}
local firstBringDone = false
local bringDelay = 2
local normalBringDelay = 0.18

task.wait(3)

-- ===== CORE FUNCTIONS =====
local function Alive(mob)
    if not mob then return false end
    local h = mob:FindFirstChild("Humanoid")
    local hrp = mob:FindFirstChild("HumanoidRootPart")
    return h and hrp and h.Health > 0
end

local function CheckPlayerAlive()
    if not Character or not Character.Parent or not Humanoid or Humanoid.Health <= 0 then
        Character = Player.Character or Player.CharacterAdded:Wait()
        HRP = Character:WaitForChild("HumanoidRootPart")
        Humanoid = Character:WaitForChild("Humanoid")
        return false
    end
    return true
end

local function Tween(targetCFrame)
    if not HRP or not targetCFrame then return end
    if currentTween then currentTween:Cancel() end
    
    local dist = (HRP.Position - targetCFrame.p).Magnitude
    local tweenTime = math.max(0.01, dist / Settings.TweenSpeed)
    
    -- TẠO BODYGYRO ĐỂ GIỮ ỔN ĐỊNH
    local bg = HRP:FindFirstChild("TweenGyro") or Instance.new("BodyGyro")
    bg.Name = "TweenGyro"
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 50000
    bg.D = 100000
    bg.CFrame = HRP.CFrame
    bg.Parent = HRP
    
    -- TẠO BODYVELOCITY ĐỂ CHỐNG RƠI
    local bv = HRP:FindFirstChild("TweenVelocity") or Instance.new("BodyVelocity")
    bv.Name = "TweenVelocity"
    bv.MaxForce = Vector3.new(9000, 9000, 9000)  -- CHỈ GIỮ THEO TRỤC Y
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = HRP
    
    currentTween = TweenService:Create(HRP, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
    currentTween:Play()
    
    -- XÓA KHI TWEEN XONG
    currentTween.Completed:Connect(function()
        local bg = HRP:FindFirstChild("TweenGyro")
        local bv = HRP:FindFirstChild("TweenVelocity")
        if bg then bg:Destroy() end
        if bv then bv:Destroy() end
        HRP.Velocity = Vector3.new(0, 0, 0)
    end)
    
    return currentTween
end

-- ===== ATTACK SYSTEM =====
local function PerformAttack()
    if not CheckPlayerAlive() then return end
    
    local Net = NetModule
    local RegisterAttack = Net and Net:FindFirstChild("RE/RegisterAttack")
    local RegisterHit = Net and Net:FindFirstChild("RE/RegisterHit")
    
    if not RegisterAttack or not RegisterHit then return end
    
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return end
    
    local targets = {}
    local closestDist = math.huge
    local closestMob = nil
    
    for _, mob in pairs(enemies:GetChildren()) do
        if Alive(mob) then
            local mHRP = mob:FindFirstChild("HumanoidRootPart")
            if mHRP then
                local dist = (mHRP.Position - HRP.Position).Magnitude
                
                if dist <= Settings.BringRadius and dist < closestDist then
                    closestDist = dist
                    closestMob = {mob, mHRP}
                end
            end
        end
    end
    
    if closestMob and closestDist <= 100 then
        table.insert(targets, closestMob)
        
        if Settings.BringMob then
            for _, mob in pairs(enemies:GetChildren()) do
                if Alive(mob) and mob ~= closestMob[1] then
                    local mHRP = mob:FindFirstChild("HumanoidRootPart")
                    if mHRP and (mHRP.Position - HRP.Position).Magnitude <= 80 then
                        table.insert(targets, {mob, mHRP})
                        if #targets >= 8 then break end
                    end
                end
            end
        end
        
        if #targets > 0 then
            local tool = Character:FindFirstChildOfClass("Tool")
            if tool then
                RegisterAttack:FireServer()
                for _ = 1, 8 do
                    RegisterHit:FireServer(targets[1][2], targets)
                    task.wait()
                end
            end
        end
    end
end

-- ===== MOB MANAGEMENT =====
local function CountMobsInRange(targetPos, nameFilter)
    local count = 0
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return 0 end
    
    for _, mob in pairs(enemies:GetChildren()) do
        if Alive(mob) and (not nameFilter or mob.Name == nameFilter) then
            local mhrp = mob:FindFirstChild("HumanoidRootPart")
            if mhrp and (mhrp.Position - targetPos).Magnitude <= Settings.BringRadius then
                count = count + 1
            end
        end
    end
    return count
end

local function DisableMobCollision(mob)
    if OriginalCanCollide[mob] then return end
    
    OriginalCanCollide[mob] = {}
    for _, part in ipairs(mob:GetDescendants()) do
        if part:IsA("BasePart") then
            OriginalCanCollide[mob][part] = part.CanCollide
            part.CanCollide = false
            part.Massless = true
        end
    end
end

local function TeleportMob(mob, targetPos, targetLookVector, lockEnabled)
    if not Alive(mob) then return end
    
    local hrp = mob:FindFirstChild("HumanoidRootPart")
    local humanoid = mob:FindFirstChild("Humanoid")
    if not hrp then return end
    
    if not mob:GetAttribute("MobFixed") then
        mob:SetAttribute("MobFixed", true)
        DisableMobCollision(mob)
        hrp.CanCollide = true
        hrp.Massless = false
    end
    
    local teleportPos = Vector3.new(
        targetPos.X,
        targetPos.Y + math.random(1, 1.7),
        targetPos.Z + math.random(-1, 1)
    )
    
    hrp.CFrame = targetLookVector and CFrame.new(teleportPos, teleportPos + targetLookVector) or CFrame.new(teleportPos)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    
    if lockEnabled then
        if not hrp:FindFirstChild("MobLockBP") then
            local bp = Instance.new("BodyPosition")
            bp.Name = "MobLockBP"
            bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bp.P = 5000 
            bp.D = 1000
            bp.Position = hrp.Position
            bp.Parent = hrp
        end
        
        if targetLookVector then
            local bg = hrp:FindFirstChild("MobLockBG") or Instance.new("BodyGyro")
            bg.Name = "MobLockBG"
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 170000
            bg.D = 1999
            bg.CFrame = CFrame.new(hrp.Position, hrp.Position + targetLookVector)
            bg.Parent = hrp
        end
        
        if humanoid then
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
        end
        
        LockedMobs[mob] = true
    else
        local bp = hrp:FindFirstChild("MobLockBP")
        local bg = hrp:FindFirstChild("MobLockBG")
        if bp then bp:Destroy() end
        if bg then bg:Destroy() end
        
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
        
        LockedMobs[mob] = nil
    end
end

local function UnlockMob(mob)
    if not mob then return end
    pcall(function()
        local hrp = mob:FindFirstChild("HumanoidRootPart")
        local humanoid = mob:FindFirstChild("Humanoid")
        
        if hrp then
            local bp = hrp:FindFirstChild("MobLockBP")
            local bg = hrp:FindFirstChild("MobLockBG")
            if bp then bp:Destroy() end
            if bg then bg:Destroy() end
        end
        
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
        
        local orig = OriginalCanCollide[mob]
        if orig then
            for part, canCollide in pairs(orig) do
                if part and part.Parent then
                    part.CanCollide = canCollide
                end
            end
            OriginalCanCollide[mob] = nil
        end
        
        LockedMobs[mob] = nil
        ProcessedMobs[mob] = nil
        mob:SetAttribute("MobFixed", nil)
    end)
end

local function SimpleTeleportMobs(targetHRP)
    if not Settings.BringMob or not targetHRP then return end
    
    -- Tính delay dựa trên lần bring đầu tiên hay không
    local currentDelay = firstBringDone and normalBringDelay or bringDelay
    if tick() - lastBringTick < currentDelay then return end
    
    lastBringTick = tick()
    firstBringDone = true -- Đánh dấu đã qua lần bring đầu tiên
    
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return end
    
    local targetPos = targetHRP.Position
    local targetLookVector = targetHRP.CFrame.LookVector
    local nameFilter = Settings.AutoFarm and NameMon or nil
    
    -- Cleanup dead mobs first
    local mobsToRemove = {}
    for mob, _ in pairs(LockedMobs) do
        if not mob or not mob.Parent or not Alive(mob) then
            table.insert(mobsToRemove, mob)
        end
    end
    for _, mob in ipairs(mobsToRemove) do
        UnlockMob(mob)
    end
    
    -- Clear processed mobs mỗi lần chạy
    ProcessedMobs = {}
    
    for _, mob in pairs(enemies:GetChildren()) do
        if Alive(mob) then
            ProcessedMobs[mob] = true
            
            local canTeleport = false
            if Settings.FarmNearest then
                canTeleport = true
            else
                canTeleport = not nameFilter or mob.Name == nameFilter
            end
            
            if canTeleport then
                local mhrp = mob:FindFirstChild("HumanoidRootPart")
                if mhrp then
                    -- TÍNH KHOẢNG CÁCH TỪ MOB ĐẾN TARGET
                    local distanceToTarget = (mhrp.Position - targetPos).Magnitude
                    
                    -- Chỉ bring mob trong phạm vi 30 studs từ target
                    if distanceToTarget <= Settings.BringRadius then
                        TeleportMob(mob, targetPos, targetLookVector, true)
                    elseif LockedMobs[mob] then
                        UnlockMob(mob)
                    end
                end
            end
        end
    end
end

local function ResetMobPhysics()
    -- Reset trạng thái bring đầu tiên
    firstBringDone = false
    
    for mob, _ in pairs(LockedMobs) do
        UnlockMob(mob)
    end
    LockedMobs = {}
    OriginalCanCollide = {}
    ProcessedMobs = {}
end

-- ===== PLAYER PHYSICS =====
local function UpdateHover()
    if not HRP then return end
    
    if Settings.FarmNearest or Settings.AutoFarm or Settings.FarmKata or Settings.FarmBone then
        -- FIXED: Better hover with velocity locking
        local bv = HRP:FindFirstChild("FarmHover")
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "FarmHover"
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = HRP
        else
            bv.Velocity = Vector3.new(0, 0, 0)
        end
        
        local bg = HRP:FindFirstChild("FarmHoverGyro")
        if not bg then
            bg = Instance.new("BodyGyro")
            bg.Name = "FarmHoverGyro"
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 15000  -- Increased for better stability
            bg.D = 1000   -- Added damping
            bg.CFrame = HRP.CFrame
            bg.Parent = HRP
        end
        
        -- Zero out velocities to prevent falling
        HRP.AssemblyLinearVelocity = Vector3.zero
        HRP.AssemblyAngularVelocity = Vector3.zero
    else
        local bv = HRP:FindFirstChild("FarmHover")
        local bg = HRP:FindFirstChild("FarmHoverGyro")
        if bv then bv:Destroy() end
        if bg then bg:Destroy() end
    end
end

local function ToggleNoclip(state)
    if state then
        if _G.NoclipConn then return end
        _G.NoclipConn = RunService.Stepped:Connect(function()
            if Character then
                for _, v in pairs(Character:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
        end)
    else
        if _G.NoclipConn then _G.NoclipConn:Disconnect() _G.NoclipConn = nil end
    end
end

-- ===== EQUIPMENT =====
local function EquipWeapon()
    if not Settings.AutoEquip or not Settings.Weapon then return end
    
    local currentTool = Character:FindFirstChildOfClass("Tool")
    if currentTool then
        local toolType = currentTool:FindFirstChild("ToolTip") or currentTool:FindFirstChild("Tooltip")
        if toolType and (toolType.Value == Settings.Weapon or toolType == Settings.Weapon) then
            return
        end
    end
    
    for _, tool in pairs(Player.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local toolType = tool:FindFirstChild("ToolTip") or tool:FindFirstChild("Tooltip")
            if toolType and (toolType.Value == Settings.Weapon or toolType == Settings.Weapon) then
                if currentTool then currentTool.Parent = Player.Backpack end
                Humanoid:EquipTool(tool)
                break
            end
        end
    end
end

local function ActiveHaki()
    if not Settings.AutoHaki then return end
    if not Character:FindFirstChild("HasBuso") then
        local remote = Remotes:FindFirstChild("CommF_")
        if remote then
            pcall(function() remote:InvokeServer("Buso") end)
        end
    end
end

-- ===== QUEST DATA =====
local Mon, Qname, Qdata, NameMon, PosM, PosQ

local function UpdateQuestData()
    local level = Player.Data.Level.Value
    
    local function CheckTeleport(targetPos, entrancePos)
        local dist = (targetPos - HRP.Position).Magnitude
        if Settings.AutoFarm and dist > 10000 and Remotes:FindFirstChild("CommF_") then
            pcall(function() Remotes.CommF_:InvokeServer("requestEntrance", entrancePos) end)
            task.wait(1)
        end
    end

    if Sea1 then
        if level >= 1 and level <= 9 then
            if Player.Team and Player.Team.Name == "Marines" then
                Mon = "Trainee"; Qname = "MarineQuest"; Qdata = 1; NameMon = "Trainee"
                PosQ = CFrame.new(-2709, 25, 2104); PosM = PosQ
            else
                Mon = "Bandit"; Qname = "BanditQuest1"; Qdata = 1; NameMon = "Bandit"
                PosQ = CFrame.new(1059, 16, 1546); PosM = CFrame.new(1045, 26, 1560)
            end
        elseif level >= 10 and level <= 14 then
            Mon = "Monkey"; Qdata = 1; Qname = "JungleQuest"; NameMon = "Monkey"
            PosQ = CFrame.new(-1598, 36, 153); PosM = CFrame.new(-1448, 68, 11)
        elseif level >= 15 and level <= 29 then
            Mon = "Gorilla"; Qdata = 2; Qname = "JungleQuest"; NameMon = "Gorilla"
            PosQ = CFrame.new(-1598, 36, 153); PosM = CFrame.new(-1129, 41, -525)
        elseif level >= 30 and level <= 39 then
            Mon = "Pirate"; Qdata = 1; Qname = "BuggyQuest1"; NameMon = "Pirate"
            PosQ = CFrame.new(-1141, 5, 3831); PosM = CFrame.new(-1103, 14, 3896)
        elseif level >= 40 and level <= 59 then
            Mon = "Brute"; Qdata = 2; Qname = "BuggyQuest1"; NameMon = "Brute"
            PosQ = CFrame.new(-1141, 5, 3831); PosM = CFrame.new(-1140, 15, 4322)
        elseif level >= 60 and level <= 74 then
            Mon = "Desert Bandit"; Qdata = 1; Qname = "DesertQuest"; NameMon = "Desert Bandit"
            PosQ = CFrame.new(894, 5, 4392); PosM = CFrame.new(924, 6, 4481)
        elseif level >= 75 and level <= 89 then
            Mon = "Desert Officer"; Qdata = 2; Qname = "DesertQuest"; NameMon = "Desert Officer"
            PosQ = CFrame.new(894, 5, 4392); PosM = CFrame.new(1608, 9, 4371)
        elseif level >= 90 and level <= 99 then
            Mon = "Snow Bandit"; Qdata = 1; Qname = "SnowQuest"; NameMon = "Snow Bandit"
            PosQ = CFrame.new(1389, 88, -1298); PosM = CFrame.new(1354, 87, -1393)
        elseif level >= 100 and level <= 119 then
            Mon = "Snowman"; Qdata = 2; Qname = "SnowQuest"; NameMon = "Snowman"
            PosQ = CFrame.new(1389, 88, -1298); PosM = CFrame.new(1241, 51, -1243)
        elseif level >= 120 and level <= 149 then
            Mon = "Chief Petty Officer"; Qdata = 1; Qname = "MarineQuest2"; NameMon = "Chief Petty Officer"
            PosQ = CFrame.new(-5039, 27, 4324); PosM = CFrame.new(-4881, 23, 4273)
        elseif level >= 150 and level <= 174 then
            Mon = "Sky Bandit"; Qdata = 1; Qname = "SkyQuest"; NameMon = "Sky Bandit"
            PosQ = CFrame.new(-4839, 716, -2619); PosM = CFrame.new(-4953, 296, -2899)
        elseif level >= 175 and level <= 189 then
            Mon = "Dark Master"; Qdata = 2; Qname = "SkyQuest"; NameMon = "Dark Master"
            PosQ = CFrame.new(-4839, 716, -2619); PosM = CFrame.new(-5259, 391, -2229)
        elseif level >= 190 and level <= 209 then
            Mon = "Prisoner"; Qdata = 1; Qname = "PrisonerQuest"; NameMon = "Prisoner"
            PosQ = CFrame.new(5308, 2, 475); PosM = CFrame.new(5098, 1, 474)
        elseif level >= 210 and level <= 249 then
            Mon = "Dangerous Prisoner"; Qdata = 2; Qname = "PrisonerQuest"; NameMon = "Dangerous Prisoner"
            PosQ = CFrame.new(5308, 2, 475); PosM = CFrame.new(5654, 16, 866)
        elseif level >= 250 and level <= 274 then
            Mon = "Toga Warrior"; Qdata = 1; Qname = "ColosseumQuest"; NameMon = "Toga Warrior"
            PosQ = CFrame.new(-1580, 6, -2986); PosM = CFrame.new(-1820, 52, -2740)
        elseif level >= 275 and level <= 299 then
            Mon = "Gladiator"; Qdata = 2; Qname = "ColosseumQuest"; NameMon = "Gladiator"
            PosQ = CFrame.new(-1580, 6, -2986); PosM = CFrame.new(-1292, 56, -3339)
        elseif level >= 300 and level <= 324 then
            Mon = "Military Soldier"; Qdata = 1; Qname = "MagmaQuest"; NameMon = "Military Soldier"
            PosQ = CFrame.new(-5313, 11, 8515); PosM = CFrame.new(-5411, 11, 8454)
        elseif level >= 325 and level <= 374 then
            Mon = "Military Spy"; Qdata = 2; Qname = "MagmaQuest"; NameMon = "Military Spy"
            PosQ = CFrame.new(-5313, 11, 8515); PosM = CFrame.new(-5802, 86, 8828)
        elseif level >= 375 and level <= 399 then
            Mon = "Fishman Warrior"; Qdata = 1; Qname = "FishmanQuest"; NameMon = "Fishman Warrior"
            PosQ = CFrame.new(61122, 18, 1569); PosM = CFrame.new(60878, 18, 1543)
            CheckTeleport(PosQ.Position, Vector3.new(61163, 11, 1819))
        elseif level >= 400 and level <= 449 then
            Mon = "Fishman Commando"; Qdata = 2; Qname = "FishmanQuest"; NameMon = "Fishman Commando"
            PosQ = CFrame.new(61122, 18, 1569); PosM = CFrame.new(61922, 18, 1493)
            CheckTeleport(PosQ.Position, Vector3.new(61163, 11, 1819))
        elseif level >= 450 and level <= 474 then
            Mon = "God's Guard"; Qdata = 1; Qname = "SkyExp1Quest"; NameMon = "God's Guard"
            PosQ = CFrame.new(-4721, 843, -1949); PosM = CFrame.new(-4710, 845, -1927)
            CheckTeleport(PosQ.Position, Vector3.new(-4607, 872, -1667))
        elseif level >= 475 and level <= 524 then
            Mon = "Shanda"; Qdata = 2; Qname = "SkyExp1Quest"; NameMon = "Shanda"
            PosQ = CFrame.new(-7859, 5544, -381); PosM = CFrame.new(-7678, 5566, -497)
            CheckTeleport(PosQ.Position, Vector3.new(-7894, 5547, -380))
        elseif level >= 525 and level <= 549 then
            Mon = "Royal Squad"; Qdata = 1; Qname = "SkyExp2Quest"; NameMon = "Royal Squad"
            PosQ = CFrame.new(-7906, 5634, -1411); PosM = CFrame.new(-7635, 5637, -1408)
        elseif level >= 550 and level <= 624 then
            Mon = "Royal Soldier"; Qdata = 2; Qname = "SkyExp2Quest"; NameMon = "Royal Soldier"
            PosQ = CFrame.new(-7906, 5634, -1411); PosM = CFrame.new(-7836, 5681, -1792)
            CheckTeleport(PosQ.Position, Vector3.new(-7894, 5547, -380))
        elseif level >= 625 and level <= 649 then
            Mon = "Galley Pirate"; Qdata = 1; Qname = "FountainQuest"; NameMon = "Galley Pirate"
            PosQ = CFrame.new(5256, 38, 4050); PosM = CFrame.new(5589, 39, 3996)
        elseif level >= 650 and level <= 699 then
            Mon = "Galley Captain"; Qdata = 2; Qname = "FountainQuest"; NameMon = "Galley Captain"
            PosQ = CFrame.new(5256, 38, 4050); PosM = CFrame.new(5649, 39, 4936)
        else
            Mon = "Galley Captain"; Qdata = 2; Qname = "FountainQuest"; NameMon = "Galley Captain"
            PosQ = CFrame.new(5256, 38, 4050); PosM = CFrame.new(5649, 39, 4936)
        end
    elseif Sea2 then
        if level >= 700 and level <= 724 then
            Mon = "Raider"; Qname = "Area1Quest"; Qdata = 1; NameMon = "Raider"
            PosQ = CFrame.new(-425, 73, 1837); PosM = CFrame.new(-742, 93, 1588)
        elseif level >= 725 and level <= 774 then
            Mon = "Mercenary"; Qname = "Area1Quest"; Qdata = 2; NameMon = "Mercenary"
            PosQ = CFrame.new(-425, 73, 1837); PosM = CFrame.new(-1022, 93, 1678)
        elseif level >= 775 and level <= 799 then
            Mon = "Swan Pirate"; Qname = "Area2Quest"; Qdata = 1; NameMon = "Swan Pirate"
            PosQ = CFrame.new(634, 73, 918); PosM = CFrame.new(878, 122, 1212)
        elseif level >= 800 and level <= 874 then
            Mon = "Factory Staff"; Qname = "Area2Quest"; Qdata = 2; NameMon = "Factory Staff"
            PosQ = CFrame.new(634, 73, 918); PosM = CFrame.new(295, 73, -55)
        elseif level >= 875 and level <= 899 then
            Mon = "Marine Lieutenant"; Qname = "MarineQuest3"; Qdata = 1; NameMon = "Marine Lieutenant"
            PosQ = CFrame.new(-2441, 73, -3220); PosM = CFrame.new(-2820, 73, -3075)
        elseif level >= 900 and level <= 949 then
            Mon = "Marine Captain"; Qname = "MarineQuest3"; Qdata = 2; NameMon = "Marine Captain"
            PosQ = CFrame.new(-2441, 73, -3220); PosM = CFrame.new(-1869, 73, -3320)
        elseif level >= 950 and level <= 974 then
            Mon = "Zombie"; Qname = "ZombieQuest"; Qdata = 1; NameMon = "Zombie"
            PosQ = CFrame.new(-5495, 48, -795); PosM = CFrame.new(-5721, 48, -718)
        elseif level >= 975 and level <= 1049 then
            Mon = "Vampire"; Qname = "ZombieQuest"; Qdata = 2; NameMon = "Vampire"
            PosQ = CFrame.new(-5495, 48, -795); PosM = CFrame.new(-6033, 7, -1317)
        elseif level >= 1050 and level <= 1074 then
            Mon = "Snow Trooper"; Qname = "SnowMountainQuest"; Qdata = 1; NameMon = "Snow Trooper"
            PosQ = CFrame.new(607, 401, -5371); PosM = CFrame.new(478, 401, -5343)
        elseif level >= 1075 and level <= 1124 then
            Mon = "Winter Warrior"; Qname = "SnowMountainQuest"; Qdata = 2; NameMon = "Winter Warrior"
            PosQ = CFrame.new(607, 401, -5371); PosM = CFrame.new(1157, 430, -5188)
        elseif level >= 1125 and level <= 1149 then
            Mon = "Lab Subordinate"; Qname = "IceSideQuest"; Qdata = 1; NameMon = "Lab Subordinate"
            PosQ = CFrame.new(-6061, 16, -4905); PosM = CFrame.new(-6503, 20, -5803)
        elseif level >= 1150 and level <= 1224 then
            Mon = "Horned Marine"; Qname = "IceSideQuest"; Qdata = 2; NameMon = "Horned Marine"
            PosQ = CFrame.new(-6061, 16, -4905); PosM = CFrame.new(-6384, 16, -4467)
        elseif level >= 1225 and level <= 1249 then
            Mon = "Magma Ninja"; Qname = "FireSideQuest"; Qdata = 1; NameMon = "Magma Ninja"
            PosQ = CFrame.new(-5430, 16, -5295); PosM = CFrame.new(-5405, 16, -5863)
        elseif level >= 1250 and level <= 1324 then
            Mon = "Lava Pirate"; Qname = "FireSideQuest"; Qdata = 2; NameMon = "Lava Pirate"
            PosQ = CFrame.new(-5430, 16, -5295); PosM = CFrame.new(-5270, 16, -4800)
        elseif level >= 1325 and level <= 1349 then
            Mon = "Ship Pirate"; Qname = "ShipQuest1"; Qdata = 1; NameMon = "Ship Pirate"
            PosQ = CFrame.new(1038, 125, 32911); PosM = CFrame.new(906, 125, 33034)
        elseif level >= 1350 and level <= 1424 then
            Mon = "Ship Engineer"; Qname = "ShipQuest1"; Qdata = 2; NameMon = "Ship Engineer"
            PosQ = CFrame.new(1038, 125, 32911); PosM = CFrame.new(917, 125, 32740)
        elseif level >= 1425 and level <= 1449 then
            Mon = "Water Fighter"; Qname = "ForgottenQuest"; Qdata = 1; NameMon = "Water Fighter"
            PosQ = CFrame.new(-3051, 239, -10141); PosM = CFrame.new(915, 130, 33419)
        elseif level >= 1450 and level <= 1474 then
            Mon = "Tide Keeper"; Qname = "ForgottenQuest"; Qdata = 3; NameMon = "Tide Keeper"
            PosQ = CFrame.new(-3051, 239, -10141); PosM = CFrame.new(-3266, 298, -10551)
        else
            Mon = "Tide Keeper"; Qname = "ForgottenQuest"; Qdata = 3; NameMon = "Tide Keeper"
            PosQ = CFrame.new(-3051, 239, -10141); PosM = CFrame.new(-3266, 298, -10551)
        end
    elseif Sea3 then
        if level >= 1500 and level <= 1524 then
            Mon = "Pirate Millionaire"; Qname = "TurtleQuest1"; Qdata = 1; NameMon = "Pirate Millionaire"
            PosQ = CFrame.new(-11485, 14, -13180); PosM = CFrame.new(-11440, 14, -12750)
        elseif level >= 1525 and level <= 1574 then
            Mon = "Pistol Billionaire"; Qname = "TurtleQuest1"; Qdata = 2; NameMon = "Pistol Billionaire"
            PosQ = CFrame.new(-11485, 14, -13180); PosM = CFrame.new(-11590, 80, -12810)
        elseif level >= 1575 and level <= 1624 then
            Mon = "Dragon Crew Warrior"; Qname = "TurtleQuest2"; Qdata = 1; NameMon = "Dragon Crew Warrior"
            PosQ = CFrame.new(-13233, 404, -7767); PosM = CFrame.new(-13390, 404, -7640)
        elseif level >= 1625 and level <= 1699 then
            Mon = "Dragon Crew Archer"; Qname = "TurtleQuest2"; Qdata = 2; NameMon = "Dragon Crew Archer"
            PosQ = CFrame.new(-13233, 404, -7767); PosM = CFrame.new(-13500, 440, -7800)
        elseif level >= 1700 and level <= 1724 then
            Mon = "Female Island Pirate"; Qname = "HydraQuest1"; Qdata = 1; NameMon = "Female Island Pirate"
            PosQ = CFrame.new(5740, 601, -210); PosM = CFrame.new(5815, 601, -300)
        elseif level >= 1725 and level <= 1774 then
            Mon = "Giant Island Pirate"; Qname = "HydraQuest1"; Qdata = 2; NameMon = "Giant Island Pirate"
            PosQ = CFrame.new(5740, 601, -210); PosM = CFrame.new(5560, 601, -110)
        elseif level >= 1775 and level <= 1799 then
            Mon = "Forest Pirate"; Qname = "DeepForestQuest1"; Qdata = 1; NameMon = "Forest Pirate"
            PosQ = CFrame.new(-13240, 331, -131); PosM = CFrame.new(-13440, 331, -300)
        elseif level >= 1800 and level <= 1874 then
            Mon = "Mythical Pirate"; Qname = "DeepForestQuest1"; Qdata = 2; NameMon = "Mythical Pirate"
            PosQ = CFrame.new(-13240, 331, -131); PosM = CFrame.new(-13550, 470, -430)
        elseif level >= 1875 and level <= 1899 then
            Mon = "Jungle Pirate"; Qname = "DeepForestQuest2"; Qdata = 1; NameMon = "Jungle Pirate"
            PosQ = CFrame.new(-12680, 390, -2250); PosM = CFrame.new(-12100, 330, -2350)
        elseif level >= 1900 and level <= 1974 then
            Mon = "Musketeer Pirate"; Qname = "DeepForestQuest2"; Qdata = 2; NameMon = "Musketeer Pirate"
            PosQ = CFrame.new(-12680, 390, -2250); PosM = CFrame.new(-13280, 390, -2370)
        elseif level >= 1975 and level <= 1999 then
            Mon = "Reborn Skeleton"; Qname = "HauntedQuest1"; Qdata = 1; NameMon = "Reborn Skeleton"
            PosQ = CFrame.new(-9515, 162, 5786); PosM = CFrame.new(-9350, 162, 6130)
        elseif level >= 2000 and level <= 2074 then
            Mon = "Living Zombie"; Qname = "HauntedQuest1"; Qdata = 2; NameMon = "Living Zombie"
            PosQ = CFrame.new(-9515, 162, 5786); PosM = CFrame.new(-10150, 162, 5820)
        elseif level >= 2075 and level <= 2099 then
            Mon = "Demonic Soul"; Qname = "HauntedQuest2"; Qdata = 1; NameMon = "Demonic Soul"
            PosQ = CFrame.new(-9515, 162, 5786); PosM = CFrame.new(-9500, 162, 5450)
        elseif level >= 2100 and level <= 2199 then
            Mon = "Posessed Mummy"; Qname = "HauntedQuest2"; Qdata = 2; NameMon = "Posessed Mummy"
            PosQ = CFrame.new(-9515, 162, 5786); PosM = CFrame.new(-10500, 162, 5950)
        elseif level >= 2200 and level <= 2224 then
            Mon = "Cookie Crafter"; Qname = "IceCreamIslandQuest1"; Qdata = 1; NameMon = "Cookie Crafter"
            PosQ = CFrame.new(-900, 65, -12100); PosM = CFrame.new(-1050, 65, -12050)
        elseif level >= 2225 and level <= 2274 then
            Mon = "Cake Guard"; Qname = "IceCreamIslandQuest1"; Qdata = 2; NameMon = "Cake Guard"
            PosQ = CFrame.new(-900, 65, -12100); PosM = CFrame.new(-750, 65, -12300)
        elseif level >= 2275 and level <= 2299 then
            Mon = "Baking Staff"; Qname = "CakeIslandQuest1"; Qdata = 1; NameMon = "Baking Staff"
            PosQ = CFrame.new(-1910, 38, -12810); PosM = CFrame.new(-1800, 38, -12950)
        elseif level >= 2300 and level <= 2374 then
            Mon = "Head Baker"; Qname = "CakeIslandQuest1"; Qdata = 2; NameMon = "Head Baker"
            PosQ = CFrame.new(-1910, 38, -12810); PosM = CFrame.new(-2050, 38, -13100)
        elseif level >= 2375 and level <= 2399 then
            Mon = "Cocoa Warrior"; Qname = "CandyIslandQuest1"; Qdata = 1; NameMon = "Cocoa Warrior"
            PosQ = CFrame.new(-1160, 15, -14250); PosM = CFrame.new(-1050, 15, -14150)
        elseif level >= 2400 and level <= 2449 then
            Mon = "Chocolate Bar Battler"; Qname = "CandyIslandQuest1"; Qdata = 2; NameMon = "Chocolate Bar Battler"
            PosQ = CFrame.new(-1160, 15, -14250); PosM = CFrame.new(-1000, 65, -14550)
        elseif level >= 2450 and level <= 2474 then
            Mon = "Isle Outlaw"; Qname = "TikiQuest1"; Qdata = 1; NameMon = "Isle Outlaw"
            PosQ = CFrame.new(-16548, 55, -172); PosM = CFrame.new(-16479, 226, -300)
        elseif level >= 2475 and level <= 2499 then
            Mon = "Island Boy"; Qname = "TikiQuest1"; Qdata = 2; NameMon = "Island Boy"
            PosQ = CFrame.new(-16548, 55, -172); PosM = CFrame.new(-16849, 192, -150)
        elseif level >= 2500 and level <= 2524 then
            Mon = "Sun-kissed Warrior"; Qname = "TikiQuest2"; Qdata = 1; NameMon = "Sun-kissed Warrior"
            PosQ = CFrame.new(-16538, 55, 1049); PosM = CFrame.new(-16347, 64, 984)
        elseif level >= 2525 and level <= 2550 then
            Mon = "Isle Champion"; Qname = "TikiQuest2"; Qdata = 2; NameMon = "Isle Champion"
            PosQ = CFrame.new(-16541, 57, 1051); PosM = CFrame.new(-16602, 130, 1087)
        elseif level >= 2551 and level <= 2574 then
            Mon = "Serpent Hunter"; Qname = "TikiQuest3"; Qdata = 1; NameMon = "Serpent Hunter"
            PosQ = CFrame.new(-16679, 176, 1474); PosM = PosQ
        elseif level >= 2575 and level <= 2599 then
            Mon = "Skull Slayer"; Qname = "TikiQuest3"; Qdata = 2; NameMon = "Skull Slayer"
            PosQ = CFrame.new(-16759, 71, 1595); PosM = PosQ
        elseif level >= 2600 and level <= 2624 then
            Mon = "Reef Bandit"; Qname = "SubmergedQuest1"; Qdata = 1; NameMon = "Reef Bandit"
            PosQ = CFrame.new(10882, -2086, 10034); PosM = CFrame.new(10736, -2087, 9338)
        elseif level >= 2625 and level <= 2649 then
            Mon = "Coral Pirate"; Qname = "SubmergedQuest1"; Qdata = 2; NameMon = "Coral Pirate"
            PosQ = CFrame.new(10882, -2086, 10034); PosM = CFrame.new(10965, -2158, 9177)
        elseif level >= 2650 and level <= 2674 then
            Mon = "Sea Chanter"; Qname = "SubmergedQuest2"; Qdata = 1; NameMon = "Sea Chanter"
            PosQ = CFrame.new(10882, -2086, 10034); PosM = CFrame.new(10621, -2087, 10102)
        elseif level >= 2675 and level <= 2699 then
            Mon = "Ocean Prophet"; Qname = "SubmergedQuest2"; Qdata = 2; NameMon = "Ocean Prophet"
            PosQ = CFrame.new(10882, -2086, 10034); PosM = CFrame.new(11056, -2001, 10117)
        elseif level >= 2700 and level <= 2724 then
            Mon = "High Disciple"; Qname = "SubmergedQuest3"; Qdata = 1; NameMon = "High Disciple"
            PosQ = CFrame.new(9638, -1993, 9615); PosM = CFrame.new(9818.4014, -1962.3967, 9810.8350)
        else
            Mon = "Grand Devotee"; Qname = "SubmergedQuest3"; Qdata = 2; NameMon = "Grand Devotee"
            PosQ = CFrame.new(9638, -1993, 9615); PosM = CFrame.new(9585.79, -1912.35, 9822.90)
        end
    end
end

-- ===== BOSS FARM FUNCTIONS =====
local function FarmKata()
    if not Settings.FarmKata or not CheckPlayerAlive() then return false end
    
    local cakeMobs = {"Baking Staff", "Cake Guard", "Cookie Crafter", "Head Baker"}
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return false end
    
    local targetMob, closestDist = nil, math.huge
    
    for _, mob in pairs(enemies:GetChildren()) do
        if Alive(mob) then
            for _, cakeMobName in pairs(cakeMobs) do
                if mob.Name == cakeMobName then
                    local mhrp = mob:FindFirstChild("HumanoidRootPart")
                    if mhrp then
                        local dist = (mhrp.Position - HRP.Position).Magnitude
                        if dist < closestDist then
                            closestDist = dist
                            targetMob = mob
                        end
                    end
                    break
                end
            end
        end
    end
    
    if targetMob then
        local targetHRP = targetMob:FindFirstChild("HumanoidRootPart")
        if targetHRP then
            local targetPos = targetHRP.Position + Vector3.new(-4, Settings.TweenHeight, 5)
            local targetCFrame = CFrame.new(targetPos, targetPos + targetHRP.CFrame.LookVector)
            
            if currentTween then currentTween:Cancel() end
            currentTween = Tween(targetCFrame)
            
            if (HRP.Position - targetPos).Magnitude < BypassDist then
                HRP.CFrame = targetCFrame
                HRP.Velocity = Vector3.new(0,0,0)
                if Settings.BringMob then SimpleTeleportMobs(targetHRP) end
            end
            return true
        end
    end
    
    return false
end

local function FarmBone()
    if not Settings.FarmBone or not CheckPlayerAlive() then return false end
    
    local boneMobs = {"Demonic Soul", "Living Zombie", "Posessed Mummy", "Reborn Skeleton"}
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return false end
    
    local targetMob, closestDist = nil, math.huge
    
    for _, mob in pairs(enemies:GetChildren()) do
        if Alive(mob) then
            for _, boneMobName in pairs(boneMobs) do
                if mob.Name == boneMobName then
                    local mhrp = mob:FindFirstChild("HumanoidRootPart")
                    if mhrp then
                        local dist = (mhrp.Position - HRP.Position).Magnitude
                        if dist < closestDist then
                            closestDist = dist
                            targetMob = mob
                        end
                    end
                    break
                end
            end
        end
    end

    
    if targetMob then
        local targetHRP = targetMob:FindFirstChild("HumanoidRootPart")
        if targetHRP then
            local targetPos = targetHRP.Position + Vector3.new(-4, Settings.TweenHeight, 5)
            local targetCFrame = CFrame.new(targetPos, targetPos + targetHRP.CFrame.LookVector)
            
            if currentTween then currentTween:Cancel() end
            currentTween = Tween(targetCFrame)
            
            if (HRP.Position - targetPos).Magnitude < BypassDist then
                HRP.CFrame = targetCFrame
                HRP.Velocity = Vector3.new(0,0,0)
                if Settings.BringMob then SimpleTeleportMobs(targetHRP) end
            end
            return true
        end
    end

    return false
end

-- ===== MAIN FARM LOOP =====
task.spawn(function()
    while true do
        task.wait()
        
        if not CheckPlayerAlive() then
            if currentTween then currentTween:Cancel() end
            continue
        end
        
        if Settings.FarmKata and FarmKata() then continue end
        if Settings.FarmBone and FarmBone() then continue end
        
        if (Settings.AutoFarm or Settings.FarmNearest) and Humanoid.Health > 0 then
            local targetMob = nil
            
            if Settings.FarmNearest then
                local enemies = Workspace:FindFirstChild("Enemies")
                if enemies then
                    local closestDist = math.huge
                    for _, mob in pairs(enemies:GetChildren()) do
                        if Alive(mob) then
                            local mhrp = mob:FindFirstChild("HumanoidRootPart")
                            if mhrp then
                                local dist = (mhrp.Position - HRP.Position).Magnitude
                                if dist < closestDist then
                                    closestDist = dist
                                    targetMob = mob
                                end
                            end
                        end
                    end
                end
                if not targetMob then
                    if currentTween then currentTween:Cancel() end
                    UpdateHover()
                    continue
                end
            elseif Settings.AutoFarm then
                if Player.Data.Level.Value >= 2675 and HRP.Position.Y > -500 then
                    local distToSub = (HRP.Position - NPC_Sub_Pos.p).Magnitude
                    if distToSub > 20 then
                        Tween(NPC_Sub_Pos)
                    else
                        if currentTween then currentTween:Cancel() end
                        ReplicatedStorage.Modules.Net.RF.SubmarineWorkerSpeak:InvokeServer("TravelToSubmergedIsland")
                        task.wait(2)
                    end
                    continue
                end
                
                UpdateQuestData()
                
                if not Player.PlayerGui.Main.Quest.Visible then
                    local distQ = (HRP.Position - PosQ.Position).Magnitude
                    if distQ > 12 then
                        Tween(PosQ)
                    else
                        if currentTween then currentTween:Cancel() end
                        HRP.CFrame = PosQ
                        task.wait(0.5)
                        if not Player.PlayerGui.Main.Quest.Visible then
                            pcall(function() Remotes.CommF_:InvokeServer("StartQuest", Qname, Qdata) end)
                        end
                    end
                else
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if enemies then
                        for _, mob in pairs(enemies:GetChildren()) do
                            if Alive(mob) and mob.Name == NameMon then
                                targetMob = mob
                                break
                            end
                        end
                    end
                end
            end
            
            if targetMob then
                local targetHRP = targetMob:FindFirstChild("HumanoidRootPart")
                if not targetHRP then continue end
                
                local targetPos = targetHRP.Position + Vector3.new(-4, Settings.TweenHeight, 5)
                local targetCFrame = CFrame.new(targetPos, targetPos + targetHRP.CFrame.LookVector)
                
                local distanceToTarget = (HRP.Position - targetPos).Magnitude
                
                -- KIỂM TRA NẾU CÒN CÁCH TARGET 30 STUDS THÌ BẮT ĐẦU BRING
                local shouldStartBringing = distanceToTarget <= 60 and Settings.BringMob
                
                if distanceToTarget > BypassDist then
                    if currentTween then currentTween:Cancel() end
                    currentTween = Tween(targetCFrame)
                    
                    -- BẮT ĐẦU BRING KHI CÒN CÁCH TARGET 30 STUDS
                    if shouldStartBringing then
                        SimpleTeleportMobs(targetHRP)
                    end
                else
                    if currentTween then currentTween:Cancel() end
                    HRP.CFrame = targetCFrame
                    HRP.Velocity = Vector3.new(0,0,0)
                    
                    -- BRING MOB KHI ĐÃ ĐẾN SÁT TARGET
                    if Settings.BringMob then
                        SimpleTeleportMobs(targetHRP)
                    end
                end
            end
        else
            UpdateHover()
        end
    end
end)

-- ===== ATTACK LOOP =====
RunService.Heartbeat:Connect(function()
    if not CheckPlayerAlive() then return end
    UpdateHover()
    ActiveHaki()
    EquipWeapon()
    
    if Settings.AutoFarm or Settings.FarmNearest or Settings.FarmKata or Settings.FarmBone then
        PerformAttack()
    end
end)

-- ===== ANTI-AFK =====
Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ===== UI =====
Tab:CreateDropdown({
    Name = "Select Weapon",
    Options = {"Melee", "Sword", "Blox Fruit"},
    CurrentOption = "Melee",
    Callback = function(Option) Settings.Weapon = Option end
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
            if HRP then HRP.Velocity = Vector3.new(0,0,0) end
            ResetMobPhysics()
        end
    end
})

Tab:CreateToggle({
    Name = "Auto Farm Nearest",
    CurrentValue = false,
    Callback = function(v)
        Settings.FarmNearest = v
        UpdateHover()
        ToggleNoclip(v)
        if not v then
            if currentTween then currentTween:Cancel() end
            ResetMobPhysics()
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

Setting:CreateSlider({
    Name = "Bring Distance",
    Range = {150, 400},
    Increment = 10,
    CurrentValue = 300,
    Callback = function(v) Settings.BringRadius = v end
})

Setting:CreateToggle({
    Name = "Auto Haki",
    CurrentValue = true,
    Callback = function(v) Settings.AutoHaki = v end
})

Setting:CreateToggle({
    Name = "Auto Equip Weapon",
    CurrentValue = true,
    Callback = function(v) Settings.AutoEquip = v end
})

Setting:CreateSlider({
    Name = "Tween Height",
    Range = {10, 50},
    Increment = 1,
    CurrentValue = 22,
    Callback = function(v) Settings.TweenHeight = v end
})

BossTab:CreateToggle({
    Name = "Farm Kata",
    CurrentValue = false,
    Callback = function(v)
        Settings.FarmKata = v
        UpdateHover()
        ToggleNoclip(v)
        if not v then
            if currentTween then currentTween:Cancel() end
            ResetMobPhysics()
        end
    end
})

BossTab:CreateToggle({
    Name = "Farm Bone",
    CurrentValue = false,
    Callback = function(v)
        Settings.FarmBone = v
        UpdateHover()
        ToggleNoclip(v)
        if not v then
            if currentTween then currentTween:Cancel() end
            ResetMobPhysics()
        end
    end
})

StatsTab:CreateDropdown({
    Name = "Select Stat Type",
    Options = {"Melee", "Defense", "Sword", "Gun", "Blox Fruit"},
    CurrentOption = "Melee",
    Callback = function(Option) Settings.StatTarget = Option end
})

StatsTab:CreateToggle({
    Name = "Auto Add Stats",
    CurrentValue = false,
    Callback = function(v)
        Settings.AutoStatEnabled = v
        if v then
            task.spawn(function()
                while Settings.AutoStatEnabled do
                    if Player.Data.Points.Value > 0 then
                        local remote = Remotes:FindFirstChild("CommF_")
                        if remote then
                            pcall(function() remote:InvokeServer("AddPoint", Settings.StatTarget, 1) end)
                        end
                    end
                    task.wait(0.5)
                end
            end)
        end
    end
})

Rayfield:LoadConfiguration()
