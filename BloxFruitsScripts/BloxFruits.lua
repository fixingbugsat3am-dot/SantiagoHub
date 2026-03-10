-- ============================================================
--  SantiagoHub | BloxFruitsScripts/BloxFruits.lua
--  Main entry point. Loaded by main.lua.
--  Wires together: Functions, QuestData, Codes, GUI + redz backend.
-- ============================================================

local _G2    = (getgenv or getrenv or getfenv)()
local HUB    = _G2.SantiagoHub
local BASE   = HUB.BASE
local fetch  = HUB.fetch
local load   = HUB.load

local cloneref = cloneref or (function(...) return ... end)
local HTTP     = cloneref(game:GetService("HttpService"))
local RS       = cloneref(game:GetService("RunService"))
local PL       = cloneref(game:GetService("Players"))
local LP       = PL.LocalPlayer

-- ============================================================
--  SAVE / LOAD  (writefile / readfile)
-- ============================================================
local SAVE_FILE = "SantiagoHub_bf.json"

local DEFAULT_SAVE = {
    keyPassed   = false,
    AutoFarm    = false,
    AutoQuest   = false,
    AutoRaid    = false,
    AutoBoss    = false,
    AutoMastery = false,
    AutoChest   = false,
    AutoBerry   = false,
    FastAttack  = false,
    SilentAim   = false,
    AutoSkills  = false,
    SpeedBoost  = false,
    NoClip      = false,
    BusoHaki    = false,
    KenHaki     = false,
    AntiAfk     = true,
    FruitSniper = false,
    AutoEat     = false,
    SaveFruit   = false,
    FruitHop    = false,
    TargetFruit = "",
    AutoSave    = true,
    Notifs      = true,
    Fullbright  = false,
    VisCheck    = false,
    Theme       = 1,
}

local function deepCopy(t)
    local c = {}
    for k,v in pairs(t) do c[k] = v end
    return c
end

local saveData = deepCopy(DEFAULT_SAVE)

local function loadSave()
    local ok, raw = pcall(readfile, SAVE_FILE)
    if ok and raw and raw ~= "" then
        local ok2, data = pcall(function()
            return HTTP:JSONDecode(raw)
        end)
        if ok2 and type(data) == "table" then
            for k, v in pairs(data) do
                if DEFAULT_SAVE[k] ~= nil then
                    saveData[k] = v
                end
            end
        end
    end
end

local function writeSave()
    local ok, enc = pcall(function()
        return HTTP:JSONEncode(saveData)
    end)
    if ok then
        pcall(writefile, SAVE_FILE, enc)
    end
end

pcall(loadSave)

-- auto save every 30 seconds
task.spawn(function()
    while true do
        task.wait(30)
        if saveData.AutoSave then
            pcall(writeSave)
        end
    end
end)

-- ============================================================
--  LOAD MODULES
-- ============================================================
local F     = load("Functions.lua")
local QD    = load("QuestData.lua")
local CODES = load("Codes.lua")
local ICONS = load("Icons.lua")
local GUI   = load("GUI.lua")

-- expose icons globally so RedzLib + GUI can resolve icon names
_G2.SantiagoHub.Icons = ICONS
s = _G2.SantiagoHub

-- ============================================================
--  REDZ HUB BACKEND  (runs in parallel)
-- ============================================================
task.spawn(function()
    -- debounce: don't double-load if main.lua already started it
    if _G2.rz_execute_debounce and (tick() - _G2.rz_execute_debounce) < 5 then
        return
    end
    _G2.rz_execute_debounce = tick()

    local rzUrls = {
        Owner      = "https://raw.githubusercontent.com/tlredz/",
        Repository = "https://raw.githubusercontent.com/tlredz/Scripts/refs/heads/main/",
    }

    local identifyexecutor2 = identifyexecutor or (function() return "Unknown" end)

    local rz = {}

    local function rzError(msg)
    end

    function rz.get(Url)
        local ok, resp = pcall(function()
            return game:HttpGet(Url)
        end)
        if ok then return resp end
        rzError("HTTP fail: " .. Url .. "\n" .. tostring(resp))
        return nil
    end

    function rz.load(Url, concat)
        local raw = rz.get(Url)
        if not raw then return end
        raw = raw .. (concat or "")
        local fn, err = loadstring(raw)
        if type(fn) ~= "function" then
            rzError("Syntax error: " .. Url .. "\n" .. tostring(err))
            return
        end
        return fn
    end

    local BETA = _G2.BETA_VERSION

    local Scripts = {
        { GameId=994732206, Path="Games/" .. (BETA and "BLOX-FRUITS-BETA.lua" or "BloxFruits.lua") },
        { PlacesIds={10260193230}, Path="Games/MemeSea.lua" },
    }

    for _, Script in ipairs(Scripts) do
        local match = false
        if Script.PlacesIds and table.find(Script.PlacesIds, game.PlaceId) then
            match = true
        elseif Script.GameId and Script.GameId == game.GameId then
            match = true
        end

        if match then
            local fn = rz.load(rzUrls.Repository .. Script.Path)
            if fn then
                local ok2, err2 = pcall(fn, rz)
                if not ok2 then
                    rzError("Runtime error in " .. Script.Path .. ": " .. tostring(err2))
                end
            end
            break
        end
    end
end)

-- ============================================================
--  FEATURE TOGGLE HANDLER
-- ============================================================
local function onToggle(feature, enabled)
    if feature == "AutoFarm"    then F.setAutoFarm(enabled, QD)    end
    if feature == "AutoQuest"   then F.setAutoQuest(enabled, QD)   end
    if feature == "AutoRaid"    then F.setAutoRaid(enabled)        end
    if feature == "AutoBoss"    then F.setAutoBoss(enabled)        end
    if feature == "AutoMastery" then F.setAutoMastery(enabled)     end
    if feature == "AutoChest"   then F.setAutoChest(enabled)       end
    if feature == "AutoBerry"   then F.setAutoBerry(enabled)       end
    if feature == "FastAttack"  then F.setFastAttack(enabled)      end
    if feature == "SilentAim"   then F.setSilentAim(enabled)       end
    if feature == "AutoSkills"  then F.setAutoSkills(enabled)      end
    if feature == "SpeedBoost"  then F.setSpeed(enabled, 32)       end
    if feature == "NoClip"      then F.setNoClip(enabled)          end
    if feature == "BusoHaki"    then F.setBusoHaki(enabled)        end
    if feature == "KenHaki"     then F.setKenHaki(enabled)         end
    if feature == "AntiAfk"     then
        if enabled then F.startAntiAfk() else F.stopAntiAfk() end
    end
    if feature == "FruitSniper" then
        F.setFruitHop(enabled, saveData.TargetFruit)
    end
    if feature == "FruitHop"    then
        F.setFruitHop(enabled, saveData.TargetFruit)
    end
    if feature == "Fullbright"  then F.setFullbright(enabled)      end
end

-- ============================================================
--  RESUME SAVED FEATURES  (re-enable anything that was on)
-- ============================================================
local function resumeFeatures()
    for feature, _ in pairs(DEFAULT_SAVE) do
        if type(saveData[feature]) == "boolean" and saveData[feature] then
            pcall(onToggle, feature, true)
        end
    end
end

-- ============================================================
--  BOOT GUI
-- ============================================================
local guiAPI = GUI(saveData, F, QD, CODES, ICONS, onToggle)

-- resume features after a short delay (let GUI settle)
task.delay(2, resumeFeatures)

-- on character respawn, re-apply speed/noclip
LP.CharacterAdded:Connect(function()
    task.wait(1)
    if saveData.SpeedBoost then F.setSpeed(true, 32) end
    if saveData.NoClip     then F.setNoClip(true)   end
    if saveData.Fullbright then F.setFullbright(true) end
end)

print("[SantiagoHub] BloxFruits.lua loaded — "
    .. #CODES .. " codes, "
    .. (QD and #QD.Quests or 0) .. " quest regions | redz backend injected")