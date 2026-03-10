-- ============================================================
--  SantiagoHub | BloxFruitsScripts/Functions.lua
--  All shared utility functions used across the hub.
--  Ported from redz Hub internals + our own additions.
--  Returns a Functions table.
-- ============================================================

local cloneref       = cloneref or (function(...) return ... end)
local RS             = cloneref(game:GetService("RunService"))
local PL             = cloneref(game:GetService("Players"))
local TS             = cloneref(game:GetService("TweenService"))
local HTTP           = cloneref(game:GetService("HttpService"))
local UIS            = cloneref(game:GetService("UserInputService"))
local VIM            = cloneref(game:GetService("VirtualInputManager"))
local TPS            = cloneref(game:GetService("TeleportService"))
local Lighting       = cloneref(game:GetService("Lighting"))
local LP             = PL.LocalPlayer
local CAM            = workspace.CurrentCamera

local F = {}

-- ============================================================
--  SAFE OBJECT  (nil-safe property set)
-- ============================================================
function F.safeSet(obj, prop, val)
    if obj and obj.Parent then
        pcall(function() obj[prop] = val end)
    end
end

-- ============================================================
--  TWEEN HELPER
-- ============================================================
function F.tween(obj, t, props)
    local ti = TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TS:Create(obj, ti, props):Play()
end

-- ============================================================
--  CHARACTER HELPERS
-- ============================================================
function F.getChar()
    return LP and LP.Character
end

function F.getHRP()
    local c = F.getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

function F.getHum()
    local c = F.getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

function F.isAlive()
    local hum = F.getHum()
    return hum and hum.Health > 0
end

function F.getLevel()
    local ok, lvl = pcall(function()
        return LP.Data.Level.Value
    end)
    return ok and lvl or 0
end

function F.getBeli()
    local ok, b = pcall(function()
        return LP.Data.Beli.Value
    end)
    return ok and b or 0
end

function F.getSea()
    local ok, s = pcall(function()
        return game:GetService("ReplicatedStorage"):FindFirstChild("IslandData") and
               workspace:GetAttribute("CurrentSea") or 1
    end)
    return ok and s or 1
end

-- ============================================================
--  TELEPORT HELPER
-- ============================================================
function F.teleport(pos)
    local hrp = F.getHRP()
    if hrp then
        hrp.CFrame = CFrame.new(pos)
    end
end

function F.teleportCF(cf)
    local hrp = F.getHRP()
    if hrp then
        hrp.CFrame = cf
    end
end

-- ============================================================
--  FIND NEAREST ENEMY
--  Returns: model, distance
-- ============================================================
function F.getNearestEnemy(maxDist)
    maxDist = maxDist or 500
    local hrp = F.getHRP()
    if not hrp then return nil, math.huge end

    local best, bestDist = nil, maxDist
    for _, m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") and m ~= LP.Character then
            local mHum = m:FindFirstChildOfClass("Humanoid")
            local mHRP = m:FindFirstChild("HumanoidRootPart")
            if mHum and mHum.Health > 0 and mHRP then
                if not PL:GetPlayerFromCharacter(m) then
                    local d = (hrp.Position - mHRP.Position).Magnitude
                    if d < bestDist then
                        bestDist = d
                        best     = m
                    end
                end
            end
        end
    end
    return best, bestDist
end

-- ============================================================
--  FIND ENEMY BY NAME (partial match)
-- ============================================================
function F.findEnemyByName(name, maxDist)
    maxDist = maxDist or 1000
    local hrp = F.getHRP()
    if not hrp then return nil end

    local best, bestDist = nil, maxDist
    for _, m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") and m.Name:lower():find(name:lower()) then
            local mHum = m:FindFirstChildOfClass("Humanoid")
            local mHRP = m:FindFirstChild("HumanoidRootPart")
            if mHum and mHum.Health > 0 and mHRP then
                if not PL:GetPlayerFromCharacter(m) then
                    local d = (hrp.Position - mHRP.Position).Magnitude
                    if d < bestDist then
                        bestDist = d
                        best     = m
                    end
                end
            end
        end
    end
    return best
end

-- ============================================================
--  FIND NPC BY NAME
-- ============================================================
function F.findNPC(name)
    for _, m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") and m.Name:lower():find(name:lower()) then
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if hrp then return m end
        end
    end
    return nil
end

-- ============================================================
--  INTERACT WITH NPC (fire proximity prompt or click)
-- ============================================================
function F.interactNPC(npcModel)
    if not npcModel then return end
    for _, v in ipairs(npcModel:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            fireproximityprompt(v)
            return
        end
        if v:IsA("ClickDetector") then
            pcall(function() fireclickdetector(v) end)
            return
        end
    end
end

-- ============================================================
--  ACCEPT / COMPLETE QUEST (fire remotes)
-- ============================================================
function F.acceptQuest(npcModel)
    local RS2 = game:GetService("ReplicatedStorage")
    if not npcModel then return end
    -- try proximity prompt first
    for _, v in ipairs(npcModel:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            fireproximityprompt(v)
            task.wait(0.5)
        end
    end
    -- fire quest remote
    local remote = RS2:FindFirstChild("Interactions", true)
    if remote then
        pcall(function() remote:FireServer(npcModel) end)
    end
end

-- ============================================================
--  ANTI AFK
-- ============================================================
local antiAfkConn = nil
function F.startAntiAfk()
    if antiAfkConn then return end
    antiAfkConn = task.spawn(function()
        while true do
            task.wait(55)
            pcall(function() VIM:SendKeyEvent(true,  Enum.KeyCode.Space, false, game) end)
            task.wait(0.1)
            pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
        end
    end)
end

function F.stopAntiAfk()
    if antiAfkConn then
        task.cancel(antiAfkConn)
        antiAfkConn = nil
    end
end

-- ============================================================
--  SPEED BOOST
-- ============================================================
local speedConn = nil
function F.setSpeed(enabled, amount)
    amount = amount or 32
    local hum = F.getHum()
    if not hum then return end
    if enabled then
        hum.WalkSpeed = amount
        speedConn = LP.CharacterAdded:Connect(function(c)
            local h = c:WaitForChild("Humanoid", 5)
            if h then h.WalkSpeed = amount end
        end)
    else
        hum.WalkSpeed = 16
        if speedConn then speedConn:Disconnect(); speedConn = nil end
    end
end

-- ============================================================
--  NO CLIP
-- ============================================================
local noclipConn = nil
function F.setNoClip(enabled)
    if not enabled then
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        return
    end
    noclipConn = RS.Stepped:Connect(function()
        local char = F.getChar()
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
        end
    end)
end

-- ============================================================
--  FULLBRIGHT
-- ============================================================
local origAmbient, origOutdoor, origBrightness
function F.setFullbright(enabled)
    if enabled then
        origAmbient    = Lighting.Ambient
        origOutdoor    = Lighting.OutdoorAmbient
        origBrightness = Lighting.Brightness
        Lighting.Ambient        = Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
        Lighting.Brightness     = 2
    else
        if origAmbient    then Lighting.Ambient        = origAmbient    end
        if origOutdoor    then Lighting.OutdoorAmbient = origOutdoor    end
        if origBrightness then Lighting.Brightness     = origBrightness end
    end
end

-- ============================================================
--  BUSO HAKI (simulate activate)
-- ============================================================
function F.setBusoHaki(enabled)
    local RS2 = game:GetService("ReplicatedStorage")
    local remote = RS2:FindFirstChild("UseHaki", true)
        or RS2:FindFirstChild("Haki", true)
    if remote then
        pcall(function() remote:FireServer(enabled) end)
    end
end

-- ============================================================
--  KEN HAKI (observation)
-- ============================================================
local kenThread = nil
function F.setKenHaki(enabled)
    if not enabled then
        if kenThread then task.cancel(kenThread); kenThread = nil end
        return
    end
    kenThread = task.spawn(function()
        while true do
            task.wait(0.1)
            local RS2 = game:GetService("ReplicatedStorage")
            local remote = RS2:FindFirstChild("ObservationHaki", true)
            if remote then
                pcall(function() remote:FireServer() end)
            end
        end
    end)
end

-- ============================================================
--  SILENT AIM  (camlock / bone lock)
-- ============================================================
local silentAimConn = nil
function F.setSilentAim(enabled)
    if not enabled then
        if silentAimConn then silentAimConn:Disconnect(); silentAimConn = nil end
        return
    end
    silentAimConn = UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local enemy, _ = F.getNearestEnemy(300)
        if not enemy then return end
        local head = enemy:FindFirstChild("Head")
            or enemy:FindFirstChild("HumanoidRootPart")
        if head then
            -- move mouse to target for this frame
            local screenPos, onScreen = CAM:WorldToScreenPoint(head.Position)
            if onScreen then
                pcall(function()
                    mousemoveabs(screenPos.X, screenPos.Y)
                end)
            end
        end
    end)
end

-- ============================================================
--  FAST ATTACK
-- ============================================================
local fastAtkConn = nil
function F.setFastAttack(enabled)
    if not enabled then
        if fastAtkConn then fastAtkConn:Disconnect(); fastAtkConn = nil end
        return
    end
    fastAtkConn = RS.Heartbeat:Connect(function()
        local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
        if tool then
            local activate = tool:FindFirstChild("Activate")
            if activate then
                pcall(function() activate:FireServer() end)
            end
        end
    end)
end

-- ============================================================
--  AUTO SKILLS (spam all skills)
-- ============================================================
local autoSkillThread = nil
function F.setAutoSkills(enabled)
    if not enabled then
        if autoSkillThread then task.cancel(autoSkillThread); autoSkillThread = nil end
        return
    end
    local keys = {
        Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V, Enum.KeyCode.F
    }
    autoSkillThread = task.spawn(function()
        while true do
            for _, k in ipairs(keys) do
                task.wait(0.05)
                pcall(function()
                    VIM:SendKeyEvent(true,  k, false, game)
                    VIM:SendKeyEvent(false, k, false, game)
                end)
            end
            task.wait(0.3)
        end
    end)
end

-- ============================================================
--  AUTO MASTERY (equip + attack nearest enemy)
-- ============================================================
local autoMasteryThread = nil
function F.setAutoMastery(enabled)
    if not enabled then
        if autoMasteryThread then task.cancel(autoMasteryThread); autoMasteryThread = nil end
        return
    end
    autoMasteryThread = task.spawn(function()
        while true do
            task.wait(0.1)
            if not F.isAlive() then task.wait(3); end
            local enemy = F.getNearestEnemy(600)
            if enemy then
                local eHRP = enemy:FindFirstChild("HumanoidRootPart")
                if eHRP then
                    F.teleport(eHRP.Position + Vector3.new(0,3,5))
                    task.wait(0.05)
                    pcall(function()
                        VIM:SendKeyEvent(true,  Enum.KeyCode.Z, false, game)
                        VIM:SendKeyEvent(false, Enum.KeyCode.Z, false, game)
                    end)
                end
            end
        end
    end)
end

-- ============================================================
--  AUTO CHEST  (find and open nearby chests)
-- ============================================================
local autoChestThread = nil
function F.setAutoChest(enabled)
    if not enabled then
        if autoChestThread then task.cancel(autoChestThread); autoChestThread = nil end
        return
    end
    autoChestThread = task.spawn(function()
        while true do
            task.wait(1)
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj.Name:lower():find("chest") and obj:IsA("Model") then
                    local hrp2 = obj:FindFirstChild("HumanoidRootPart")
                        or obj:FindFirstChildOfClass("BasePart")
                    if hrp2 then
                        F.teleport(hrp2.Position + Vector3.new(0,2,0))
                        task.wait(0.3)
                        for _, pp in ipairs(obj:GetDescendants()) do
                            if pp:IsA("ProximityPrompt") then
                                fireproximityprompt(pp)
                                task.wait(0.2)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ============================================================
--  AUTO BERRY  (auto collect berries/beli)
-- ============================================================
local autoBerryThread = nil
function F.setAutoBerry(enabled)
    if not enabled then
        if autoBerryThread then task.cancel(autoBerryThread); autoChestThread = nil end
        return
    end
    autoBerryThread = task.spawn(function()
        while true do
            task.wait(0.5)
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj.Name:lower():find("berry") or obj.Name:lower():find("beli") then
                    if obj:IsA("BasePart") or obj:IsA("Model") then
                        local p = obj:IsA("BasePart") and obj.Position
                            or (obj.PrimaryPart and obj.PrimaryPart.Position)
                        if p then
                            F.teleport(p + Vector3.new(0,2,0))
                            task.wait(0.1)
                        end
                    end
                end
            end
        end
    end)
end

-- ============================================================
--  SERVER HOP
-- ============================================================
function F.serverHop()
    local servers = {}
    local ok, result = pcall(function()
        return HTTP:JSONDecode(game:HttpGet(
            ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100")
            :format(game.PlaceId)
        ))
    end)
    if ok and result and result.data then
        for _, s in ipairs(result.data) do
            if s.id ~= game.JobId and s.playing < s.maxPlayers then
                table.insert(servers, s.id)
            end
        end
    end
    if #servers > 0 then
        local jobId = servers[math.random(1, #servers)]
        TPS:TeleportToPlaceInstance(game.PlaceId, jobId, LP)
    else
        warn("[SantiagoHub] No available servers found.")
    end
end

-- ============================================================
--  FRUIT SNIPER  (scan workspace for devil fruits)
-- ============================================================
function F.getFruitsInWorkspace()
    local found = {}
    local fruitKeywords = {
        "fruit","Fruit","Gomu","Mera","Hie","Goro","Pika","Magu","Ope","Ito",
        "Yami","Gura","Tori","Ryu","Zoan","Logia","Paramecia"
    }
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            for _, kw in ipairs(fruitKeywords) do
                if obj.Name:find(kw) then
                    local pos = obj:IsA("BasePart") and obj.Position
                        or (obj.PrimaryPart and obj.PrimaryPart.Position)
                    if pos then
                        table.insert(found, { Name=obj.Name, Position=pos, Object=obj })
                    end
                    break
                end
            end
        end
    end
    return found
end

-- ============================================================
--  AUTO EAT FRUIT
-- ============================================================
function F.autoEatFruit()
    for _, obj in ipairs(LP.Backpack:GetChildren()) do
        local remote = game:GetService("ReplicatedStorage"):FindFirstChild("EatFruit", true)
        if remote then
            pcall(function() remote:FireServer(obj) end)
            return true
        end
    end
    return false
end

-- ============================================================
--  SAVE FRUIT
-- ============================================================
function F.saveFruit()
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("SaveFruit", true)
    if remote then
        pcall(function() remote:FireServer() end)
        return true
    end
    return false
end

-- ============================================================
--  TELEPORT FRUIT HOP (server hop to find specific fruit)
-- ============================================================
local fruitHopThread = nil
function F.setFruitHop(enabled, targetName)
    if not enabled then
        if fruitHopThread then task.cancel(fruitHopThread); fruitHopThread = nil end
        return
    end
    fruitHopThread = task.spawn(function()
        while true do
            task.wait(2)
            local fruits = F.getFruitsInWorkspace()
            for _, ft in ipairs(fruits) do
                local name = ft.Name:lower()
                local tgt  = (targetName or ""):lower()
                if tgt == "" or name:find(tgt) then
                    -- found target fruit, teleport to it
                    F.teleport(ft.Position + Vector3.new(0,3,0))
                    task.wait(0.5)
                    return
                end
            end
            -- not found, hop server
            F.serverHop()
            task.wait(8)
        end
    end)
end

-- ============================================================
--  AUTO RAID
-- ============================================================
local autoRaidThread = nil
function F.setAutoRaid(enabled)
    if not enabled then
        if autoRaidThread then task.cancel(autoRaidThread); autoRaidThread = nil end
        return
    end
    autoRaidThread = task.spawn(function()
        while true do
            task.wait(0.5)
            if not F.isAlive() then task.wait(3) end
            local enemy = F.getNearestEnemy(500)
            if enemy then
                local eHRP = enemy:FindFirstChild("HumanoidRootPart")
                if eHRP then
                    F.teleport(eHRP.Position + Vector3.new(0, 3, 4))
                    task.wait(0.1)
                    pcall(function()
                        VIM:SendKeyEvent(true,  Enum.KeyCode.Z, false, game)
                        VIM:SendKeyEvent(false, Enum.KeyCode.Z, false, game)
                    end)
                end
            end
        end
    end)
end

-- ============================================================
--  AUTO BOSS
-- ============================================================
local autoBossThread = nil
function F.setAutoBoss(enabled)
    if not enabled then
        if autoBossThread then task.cancel(autoBossThread); autoBossThread = nil end
        return
    end
    autoBossThread = task.spawn(function()
        while true do
            task.wait(0.5)
            if not F.isAlive() then task.wait(5) end
            -- find a boss (model with a lot of HP)
            local hrp = F.getHRP()
            if not hrp then task.wait(1) end
            local bestBoss, bestDist = nil, 3000
            for _, m in ipairs(workspace:GetDescendants()) do
                if m:IsA("Model") and not PL:GetPlayerFromCharacter(m) then
                    local h = m:FindFirstChildOfClass("Humanoid")
                    local r = m:FindFirstChild("HumanoidRootPart")
                    if h and h.MaxHealth >= 5000 and h.Health > 0 and r and hrp then
                        local d = (hrp.Position - r.Position).Magnitude
                        if d < bestDist then
                            bestDist  = d
                            bestBoss  = m
                        end
                    end
                end
            end
            if bestBoss then
                local bHRP = bestBoss:FindFirstChild("HumanoidRootPart")
                if bHRP then
                    F.teleport(bHRP.Position + Vector3.new(0,3,5))
                    task.wait(0.1)
                    pcall(function()
                        VIM:SendKeyEvent(true,  Enum.KeyCode.Z, false, game)
                        VIM:SendKeyEvent(false, Enum.KeyCode.Z, false, game)
                        VIM:SendKeyEvent(true,  Enum.KeyCode.X, false, game)
                        VIM:SendKeyEvent(false, Enum.KeyCode.X, false, game)
                    end)
                end
            end
            task.wait(0.3)
        end
    end)
end

-- ============================================================
--  AUTO FARM (full loop with respawn check)
-- ============================================================
local autoFarmThread = nil
function F.setAutoFarm(enabled, questData)
    if not enabled then
        if autoFarmThread then task.cancel(autoFarmThread); autoFarmThread = nil end
        return
    end
    autoFarmThread = task.spawn(function()
        while true do
            task.wait(0.3)
            if not F.isAlive() then
                task.wait(4)
            end

            local level = F.getLevel()
            local best, bestKey

            if questData then
                best, bestKey = questData.getBestQuest(level)
            end

            -- find target enemy from quest task
            local targetName = nil
            if best then
                for name, _ in pairs(best.Task) do
                    targetName = name
                    break
                end
            end

            local enemy
            if targetName then
                enemy = F.findEnemyByName(targetName, 2000)
            else
                enemy = F.getNearestEnemy(500)
            end

            if enemy then
                local eHRP = enemy:FindFirstChild("HumanoidRootPart")
                if eHRP then
                    F.teleport(eHRP.Position + Vector3.new(0, 3, 4))
                    task.wait(0.1)
                    pcall(function()
                        VIM:SendKeyEvent(true,  Enum.KeyCode.Z, false, game)
                        VIM:SendKeyEvent(false, Enum.KeyCode.Z, false, game)
                        VIM:SendKeyEvent(true,  Enum.KeyCode.X, false, game)
                        VIM:SendKeyEvent(false, Enum.KeyCode.X, false, game)
                    end)
                end
            end
        end
    end)
end

-- ============================================================
--  AUTO QUEST
-- ============================================================
local autoQuestThread = nil
function F.setAutoQuest(enabled, questData)
    if not enabled then
        if autoQuestThread then task.cancel(autoQuestThread); autoQuestThread = nil end
        return
    end
    autoQuestThread = task.spawn(function()
        while true do
            task.wait(2)
            local level  = F.getLevel()
            local best, bestKey = questData.getBestQuest(level)
            if not best then task.wait(3); end

            local npcName = questData.getNPCName(bestKey)
            local npc     = npcName and F.findNPC(npcName)
            if npc then
                local nHRP = npc:FindFirstChild("HumanoidRootPart")
                if nHRP then
                    F.teleport(nHRP.Position + Vector3.new(0,2,3))
                    task.wait(0.5)
                    F.acceptQuest(npc)
                    task.wait(1)
                end
            end
        end
    end)
end

-- ============================================================
--  REDEEM CODES
-- ============================================================
function F.redeemCode(code)
    local RS2    = game:GetService("ReplicatedStorage")
    local remote = RS2:FindFirstChild("RedeemCode", true)
        or RS2:FindFirstChild("Redeem", true)
        or RS2:FindFirstChild("CodeRedemption", true)
    if remote then
        local ok2, err = pcall(function() remote:FireServer(code) end)
        return ok2
    end
    return false
end

function F.redeemAllCodes(codes, callback)
    task.spawn(function()
        for _, code in ipairs(codes) do
            local success = F.redeemCode(code)
            if callback then callback(code, success) end
            task.wait(0.8)
        end
    end)
end

-- ============================================================
--  GET PING
-- ============================================================
function F.getPing()
    local stats = game:GetService("Stats")
    if stats then
        local net = stats:FindFirstChild("Network")
        if net then
            local ping = net:FindFirstChild("ServerStatsItem|Data Ping")
            if ping then return math.floor(ping.Value) end
        end
    end
    return 0
end

-- ============================================================
--  HOOK MANAGER  (connect/disconnect groups of connections)
-- ============================================================
local HookManager = {}
HookManager.__index = HookManager

function HookManager.new()
    return setmetatable({ _conns = {} }, HookManager)
end

function HookManager:add(conn)
    table.insert(self._conns, conn)
    return conn
end

function HookManager:disconnectAll()
    for _, c in ipairs(self._conns) do
        pcall(function() c:Disconnect() end)
    end
    self._conns = {}
end

F.HookManager = HookManager

-- ============================================================
--  VISUAL CHECK  (skip enemies behind walls)
-- ============================================================
function F.hasLineOfSight(targetPos)
    local hrp = F.getHRP()
    if not hrp then return false end
    local origin = hrp.Position + Vector3.new(0, 2, 0)
    local dir    = (targetPos - origin)
    local ray    = Ray.new(origin, dir)
    local hit    = workspace:FindPartOnRayWithIgnoreList(ray, {LP.Character})
    if not hit then return true end
    local char = LP.Character
    if hit:IsDescendantOf(workspace) and not hit:IsDescendantOf(char) then
        -- check if hit is part of an enemy
        local mdl = hit:FindFirstAncestorOfClass("Model")
        if mdl and mdl:FindFirstChildOfClass("Humanoid") then
            return true
        end
        return false
    end
    return true
end

return F