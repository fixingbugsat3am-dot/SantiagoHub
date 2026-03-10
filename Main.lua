-- ============================================================
--  SantiagoHub | main.lua
--  Paste this into your executor and run it.
--  Repository: github.com/fixingbugsat3am-dot/SantiagoHub
-- ============================================================

local RAW = "https://raw.githubusercontent.com/fixingbugsat3am-dot/SantiagoHub/main/"
local BASE = RAW .. "BloxFruitsScripts/"

-- debounce so re-running doesn't double-load
local _G2 = (getgenv or getrenv or getfenv)()
if _G2.SantiagoHub_Loaded and (tick() - (_G2.SantiagoHub_Loaded)) < 5 then
    return warn("[SantiagoHub] Already running!")
end
_G2.SantiagoHub_Loaded = tick()

-- teleport queue so it survives server hops
local function queueReload()
    local qtp = queue_on_teleport or (syn and syn.queue_on_teleport)
    if type(qtp) == "function" then
        pcall(qtp, ("loadstring(game:HttpGet('%smain.lua'))()"):format(RAW))
    end
end
queueReload()

-- loader utility
local function fetch(path)
    local ok, res = pcall(game.HttpGet, game, BASE .. path)
    if not ok then
        error("[SantiagoHub] Failed to fetch: " .. path .. "\n" .. tostring(res), 2)
    end
    return res
end

local function load(path, ...)
    local fn, err = loadstring(fetch(path))
    if type(fn) ~= "function" then
        error("[SantiagoHub] Syntax error in: " .. path .. "\n" .. tostring(err), 2)
    end
    return fn(...)
end

-- expose loader to all modules
_G2.SantiagoHub = {
    BASE  = BASE,
    RAW   = RAW,
    fetch = fetch,
    load  = load,
}

-- boot
load("BloxFruits.lua")