-- ============================================================
--  Client Movement GUI v1.0 | StarterPlayerScripts > LocalScript
--  GUI ONLY: Key System, Loading Screen, Main Frame, Mini Button
--  Features: Speed, Jump, Fly (R6/R15), Misc tab
-- ============================================================

-- ============================================================
--  SERVICES
-- ============================================================
local cloneref = cloneref or (function(...) return ... end)
local _G_SVC = setmetatable({}, {
    __index = function(t, k)
        local s = cloneref(game:GetService(k))
        rawset(t, k, s)
        return s
    end
})
local UIS      = _G_SVC.UserInputService
local TS       = _G_SVC.TweenService
local RS       = _G_SVC.RunService
local PL       = _G_SVC.Players
local LP       = PL.LocalPlayer
local CAM      = workspace.CurrentCamera
local Lighting = _G_SVC.Lighting
local HTTP     = _G_SVC.HttpService

-- ============================================================
--  CONSTANTS
-- ============================================================
local LOGO_IMG    = "rbxassetid://139094506464240"
local BANNER_IMG  = "rbxassetid://113710199838722"
local CORRECT_KEY = "Santiago"
local SAVE_FILE   = "clientmov_v1.json"
local VERSION     = "v1.0"

-- Animation IDs
local ANIM_R6_IDLE  = "rbxassetid://90376859703329"
local ANIM_R6_FLY   = "rbxassetid://97923540261908"
local ANIM_R15_IDLE = "rbxassetid://106579227293825"
local ANIM_R15_FLY  = "rbxassetid://101871517902097"

-- ============================================================
--  FONT HELPERS
-- ============================================================
local function safeFont(id, weight, style)
    local ok, f = pcall(function()
        return Font.new("rbxassetid://" .. id,
            weight or Enum.FontWeight.Bold,
            style  or Enum.FontStyle.Normal)
    end)
    return (ok and f) or Font.fromEnum(Enum.Font.GothamBlack)
end

local FONT_COMIC  = safeFont("12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local FONT_GOTHAM = Font.fromEnum(Enum.Font.GothamBlack)

-- ============================================================
--  SAVE DATA
-- ============================================================
local saveData = {
    keyPassed    = false,
    theme        = "Red",
    speed        = 16,
    jumpPower    = 50,
    flySpeed     = 40,
    flyFOV       = 90,
    rigType      = "R15",
    miniPos      = { x = 0.06, y = 0.5 },
}

local function loadSave()
    pcall(function()
        if isfile and isfile(SAVE_FILE) then
            local d = HTTP:JSONDecode(readfile(SAVE_FILE))
            if d then for k, v in pairs(d) do saveData[k] = v end end
        end
    end)
end
local function writeSave()
    pcall(function()
        if writefile then
            writefile(SAVE_FILE, HTTP:JSONEncode(saveData))
        end
    end)
end
loadSave()

-- ============================================================
--  RUNTIME STATE
-- ============================================================
local flyOn      = false
local guiOpen    = false
local isDrag     = false
local isMini     = false
local dS, dF     = nil, nil
local mS, mF     = nil, nil
local mMov       = false

local flyConn    = nil
local flyAnim    = nil
local idleAnim   = nil
local origFOV    = CAM.FieldOfView
local origGrav   = workspace.Gravity

local uiRefs     = {}
local pillRefs   = {}

-- ============================================================
--  GOLD GRADIENT
-- ============================================================
local GOLD_SEQ = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 215, 60)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 255, 175)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(210, 148, 30)),
})

-- ============================================================
--  THEMES
-- ============================================================
local THEMES = {
    Red    = { Color3.fromRGB(215, 38, 38),  Color3.fromRGB(255, 70, 70)   },
    Blue   = { Color3.fromRGB(42, 95, 210),  Color3.fromRGB(80, 140, 255)  },
    Green  = { Color3.fromRGB(38, 155, 85),  Color3.fromRGB(60, 200, 110)  },
    Purple = { Color3.fromRGB(130, 50, 210), Color3.fromRGB(180, 90, 255)  },
    Gold   = { Color3.fromRGB(180, 130, 0),  Color3.fromRGB(255, 200, 40)  },
    Cyan   = { Color3.fromRGB(0, 170, 200),  Color3.fromRGB(60, 220, 255)  },
}
local function getTheme() return THEMES[saveData.theme] or THEMES.Red end

-- ============================================================
--  UTILITIES
-- ============================================================
local function clamp(v, mn, mx) return math.max(mn, math.min(mx, v)) end
local function getGreeting()
    local h = tonumber(os.date("%H"))
    if h >= 5 and h < 12 then return "Good Morning"
    elseif h >= 12 and h < 18 then return "Good Afternoon"
    else return "Good Night" end
end

-- ============================================================
--  UI FACTORIES
-- ============================================================
local function gG(o)
    local g = Instance.new("UIGradient")
    g.Color = GOLD_SEQ g.Rotation = 90 g.Parent = o return g
end
local function mkCorner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 12) c.Parent = o return c
end
local function mkStroke(o, t, col, tr)
    local s = Instance.new("UIStroke")
    s.Thickness = t s.Color = col s.Transparency = tr or 0 s.Parent = o return s
end
local function mkGrad(o, c1, c2, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(1, c2) })
    g.Rotation = rot or 90 g.Parent = o return g
end

local function mkCloseBtn(parent, zIdx, onClose)
    local CB = Instance.new("TextButton")
    CB.Size = UDim2.new(0, 28, 0, 28)
    CB.Position = UDim2.new(1, -34, 0, 6)
    CB.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    CB.BackgroundTransparency = 0
    CB.BorderSizePixel = 0
    CB.Text = "X"
    CB.FontFace = FONT_COMIC
    CB.TextScaled = false CB.TextSize = 13
    CB.TextColor3 = Color3.fromRGB(255, 255, 255)
    CB.ZIndex = zIdx CB.Parent = parent
    mkCorner(CB, 7)
    local bg = Instance.new("UIGradient")
    bg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 70, 70)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 35, 35)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(110, 10, 10)),
    }) bg.Rotation = 90 bg.Parent = CB
    local cbs = Instance.new("UIStroke")
    cbs.Thickness = 2 cbs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border cbs.Parent = CB
    local cbsg = Instance.new("UIGradient")
    cbsg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 180, 80)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 160)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(200, 120, 20)),
    }) cbsg.Rotation = 90 cbsg.Parent = cbs
    CB.MouseEnter:Connect(function()    TS:Create(CB, TweenInfo.new(0.12), { BackgroundTransparency = 0.2 }):Play() end)
    CB.MouseLeave:Connect(function()    TS:Create(CB, TweenInfo.new(0.12), { BackgroundTransparency = 0   }):Play() end)
    CB.MouseButton1Down:Connect(function() TS:Create(CB, TweenInfo.new(0.07), { BackgroundTransparency = 0.4 }):Play() end)
    CB.MouseButton1Up:Connect(function()   TS:Create(CB, TweenInfo.new(0.1),  { BackgroundTransparency = 0   }):Play() end)
    CB.MouseButton1Click:Connect(onClose) CB.TouchTap:Connect(onClose)
    return CB
end

local function mkPill(parent, zi)
    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0, 42, 0, 21)
    pill.Position = UDim2.new(1, -52, 0.5, -10.5)
    pill.BackgroundColor3 = Color3.fromRGB(42, 42, 52)
    pill.BorderSizePixel = 0 pill.ZIndex = zi or 14 pill.Parent = parent
    mkCorner(pill, 99)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 15, 0, 15)
    knob.Position = UDim2.new(0, 3, 0.5, -7.5)
    knob.BackgroundColor3 = Color3.fromRGB(140, 140, 155)
    knob.BorderSizePixel = 0 knob.ZIndex = (zi or 14) + 1 knob.Parent = pill
    mkCorner(knob, 99)
    return pill, knob
end

local function mkCard(parent, lbl, x, y, w, h)
    w = w or 172 h = h or 52
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, w, 0, h)
    card.Position = UDim2.new(0, x, 0, y)
    card.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    card.BackgroundTransparency = 0.08
    card.BorderSizePixel = 0 card.ZIndex = 13 card.Parent = parent
    mkCorner(card, 10) mkStroke(card, 1, Color3.fromRGB(50, 50, 62), 0.5)
    local lt = Instance.new("TextLabel")
    lt.Size = UDim2.new(1, -56, 0, 17)
    lt.Position = UDim2.new(0, 10, 0, 8)
    lt.BackgroundTransparency = 1 lt.Text = lbl
    lt.TextColor3 = Color3.fromRGB(255, 255, 255) lt.FontFace = FONT_GOTHAM
    lt.TextSize = 11 lt.TextXAlignment = Enum.TextXAlignment.Left lt.ZIndex = 14 lt.Parent = card
    gG(lt)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 6, 0, 6)
    dot.Position = UDim2.new(0, 10, 0, 32)
    dot.BackgroundColor3 = Color3.fromRGB(70, 70, 82)
    dot.BorderSizePixel = 0 dot.ZIndex = 14 dot.Parent = card mkCorner(dot, 99)
    local dtxt = Instance.new("TextLabel")
    dtxt.Size = UDim2.new(1, -56, 0, 12)
    dtxt.Position = UDim2.new(0, 20, 0, 29)
    dtxt.BackgroundTransparency = 1 dtxt.Text = "OFF"
    dtxt.TextColor3 = Color3.fromRGB(90, 90, 105) dtxt.FontFace = FONT_GOTHAM
    dtxt.TextSize = 9 dtxt.TextXAlignment = Enum.TextXAlignment.Left dtxt.ZIndex = 14 dtxt.Parent = card
    local pill, knob = mkPill(card, 15)
    return card, pill, knob, dot, dtxt
end

local function animT(pill, knob, dot, dtxt, state, col, onTxt)
    local ti = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    if state then
        TS:Create(pill, ti, { BackgroundColor3 = col }):Play()
        TS:Create(knob, ti, { Position = UDim2.new(0, 23, 0.5, -7.5), BackgroundColor3 = Color3.fromRGB(255, 255, 255) }):Play()
        TS:Create(dot, TweenInfo.new(0.15), { BackgroundColor3 = col }):Play()
        dtxt.Text = onTxt or "ON" dtxt.TextColor3 = col
    else
        TS:Create(pill, ti, { BackgroundColor3 = Color3.fromRGB(42, 42, 52) }):Play()
        TS:Create(knob, ti, { Position = UDim2.new(0, 3, 0.5, -7.5), BackgroundColor3 = Color3.fromRGB(140, 140, 155) }):Play()
        TS:Create(dot, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(70, 70, 82) }):Play()
        dtxt.Text = "OFF" dtxt.TextColor3 = Color3.fromRGB(90, 90, 105)
    end
end

local function mkInput(parent, lbl, def, maxV, x, y)
    local blk = Instance.new("Frame")
    blk.Size = UDim2.new(0, 172, 0, 66)
    blk.Position = UDim2.new(0, x, 0, y)
    blk.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    blk.BackgroundTransparency = 0.08 blk.BorderSizePixel = 0 blk.ZIndex = 13 blk.Parent = parent
    mkCorner(blk, 10) mkStroke(blk, 1, Color3.fromRGB(50, 50, 62), 0.5)
    local lt = Instance.new("TextLabel")
    lt.Size = UDim2.new(1, -12, 0, 15) lt.Position = UDim2.new(0, 10, 0, 6)
    lt.BackgroundTransparency = 1 lt.Text = lbl lt.TextColor3 = Color3.fromRGB(255, 255, 255)
    lt.FontFace = FONT_GOTHAM lt.TextSize = 10 lt.TextXAlignment = Enum.TextXAlignment.Left
    lt.ZIndex = 14 lt.Parent = blk gG(lt)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 75, 0, 26) box.Position = UDim2.new(0, 10, 0, 24)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 38) box.BackgroundTransparency = 0.05
    box.BorderSizePixel = 0 box.Text = tostring(def)
    box.TextColor3 = Color3.fromRGB(255, 215, 60) box.FontFace = FONT_GOTHAM
    box.TextSize = 13 box.ClearTextOnFocus = true box.ZIndex = 15 box.Parent = blk
    mkCorner(box, 6)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 58, 0, 26) btn.Position = UDim2.new(0, 94, 0, 24)
    btn.BackgroundColor3 = Color3.fromRGB(42, 95, 210) btn.BorderSizePixel = 0
    btn.Text = "APPLY" btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.FontFace = FONT_GOTHAM btn.TextSize = 10 btn.ZIndex = 15 btn.Parent = blk
    mkCorner(btn, 6)
    local ht = Instance.new("TextLabel")
    ht.Size = UDim2.new(1, -12, 0, 12) ht.Position = UDim2.new(0, 10, 0, 52)
    ht.BackgroundTransparency = 1 ht.Text = "MAX " .. tostring(maxV)
    ht.TextColor3 = Color3.fromRGB(58, 58, 70) ht.FontFace = FONT_GOTHAM
    ht.TextSize = 8 ht.TextXAlignment = Enum.TextXAlignment.Left ht.ZIndex = 14 ht.Parent = blk
    return box, btn
end

-- ============================================================
--  SCREEN GUI (root)
-- ============================================================
local SG = Instance.new("ScreenGui")
SG.Name = "ClientMovGUI_v1"
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent = LP.PlayerGui

-- ============================================================
--  BLUR EFFECT
-- ============================================================
local blur = Instance.new("BlurEffect") blur.Size = 0 blur.Parent = Lighting

-- ============================================================
--  NOTIFICATION SYSTEM
-- ============================================================
local function showNotif(title, msg, col, dur)
    col = col or Color3.fromRGB(42, 95, 210) dur = dur or 3.5
    local NF = SG:FindFirstChild("__NF")
    if not NF then
        NF = Instance.new("Frame") NF.Name = "__NF"
        NF.Size = UDim2.new(0, 270, 1, 0)
        NF.Position = UDim2.new(1, -280, 0, 0)
        NF.BackgroundTransparency = 1 NF.BorderSizePixel = 0 NF.ZIndex = 500 NF.Parent = SG
    end
    local nc = Instance.new("Frame")
    nc.Size = UDim2.new(1, 0, 0, 64)
    nc.Position = UDim2.new(0, 0, 1, 10)
    nc.BackgroundColor3 = Color3.fromRGB(18, 18, 24) nc.BackgroundTransparency = 0.06
    nc.BorderSizePixel = 0 nc.ZIndex = 501 nc.Parent = NF
    mkCorner(nc, 12) mkStroke(nc, 1.5, col, 0.25)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 0.75, 0) bar.Position = UDim2.new(0, 0, 0.125, 0)
    bar.BackgroundColor3 = col bar.BorderSizePixel = 0 bar.ZIndex = 502 bar.Parent = nc
    mkCorner(bar, 99)
    local nT = Instance.new("TextLabel")
    nT.Size = UDim2.new(1, -18, 0, 18) nT.Position = UDim2.new(0, 12, 0, 7)
    nT.BackgroundTransparency = 1 nT.Text = title nT.TextColor3 = col
    nT.FontFace = FONT_GOTHAM nT.TextSize = 11 nT.TextXAlignment = Enum.TextXAlignment.Left
    nT.ZIndex = 502 nT.Parent = nc
    local nM = Instance.new("TextLabel")
    nM.Size = UDim2.new(1, -18, 0, 26) nM.Position = UDim2.new(0, 12, 0, 27)
    nM.BackgroundTransparency = 1 nM.Text = msg
    nM.TextColor3 = Color3.fromRGB(175, 175, 195) nM.FontFace = FONT_GOTHAM
    nM.TextSize = 9 nM.TextXAlignment = Enum.TextXAlignment.Left
    nM.TextWrapped = true nM.ZIndex = 502 nM.Parent = nc
    local npbg = Instance.new("Frame")
    npbg.Size = UDim2.new(1, -10, 0, 2) npbg.Position = UDim2.new(0, 5, 1, -4)
    npbg.BackgroundColor3 = Color3.fromRGB(40, 40, 50) npbg.BorderSizePixel = 0
    npbg.ZIndex = 502 npbg.Parent = nc mkCorner(npbg, 99)
    local npb = Instance.new("Frame")
    npb.Size = UDim2.new(1, 0, 1, 0) npb.BackgroundColor3 = col
    npb.BorderSizePixel = 0 npb.ZIndex = 503 npb.Parent = npbg mkCorner(npb, 99)
    local kids = #NF:GetChildren()
    local yOff = -(kids * 72 + 8)
    TS:Create(nc, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 1, yOff) }):Play()
    TS:Create(npb, TweenInfo.new(dur, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) }):Play()
    task.delay(dur, function()
        TS:Create(nc, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 20, 1, yOff), BackgroundTransparency = 1 }):Play()
        task.delay(0.32, function()
            if nc and nc.Parent then nc:Destroy() end
        end)
    end)
end

-- ============================================================
--  FLY SYSTEM (GUI wires into these)
-- ============================================================
local function getAnimTrack(animId)
    local c = LP.Character if not c then return nil end
    local humanoid = c:FindFirstChildOfClass("Humanoid") if not humanoid then return nil end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator") animator.Parent = humanoid
    end
    local anim = Instance.new("Animation")
    anim.AnimationId = animId
    local track = animator:LoadAnimation(anim)
    return track
end

local function getRigType()
    local c = LP.Character if not c then return saveData.rigType end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    local upperTorso = c:FindFirstChild("UpperTorso")
    if upperTorso then return "R15" else return "R6" end
end

local function playFlyAnim()
    local rig = getRigType()
    local animId = (rig == "R15") and ANIM_R15_FLY or ANIM_R6_FLY
    if flyAnim and flyAnim.IsPlaying then flyAnim:Stop() end
    if idleAnim and idleAnim.IsPlaying then idleAnim:Stop() end
    flyAnim = getAnimTrack(animId)
    if flyAnim then flyAnim:Play() end
end

local function playIdleAnim()
    local rig = getRigType()
    local animId = (rig == "R15") and ANIM_R15_IDLE or ANIM_R6_IDLE
    if flyAnim and flyAnim.IsPlaying then flyAnim:Stop() end
    idleAnim = getAnimTrack(animId)
    if idleAnim then idleAnim:Play() end
end

local function stopFlyAnims()
    if flyAnim  and flyAnim.IsPlaying  then flyAnim:Stop()  end
    if idleAnim and idleAnim.IsPlaying then idleAnim:Stop() end
    flyAnim  = nil
    idleAnim = nil
end

local function setFly(state)
    flyOn = state
    local c = LP.Character if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    if state then
        origFOV = CAM.FieldOfView
        TS:Create(CAM, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { FieldOfView = saveData.flyFOV }):Play()
        hum.PlatformStand = true
        hrp.Velocity = Vector3.new(0, 0, 0)
        playFlyAnim()

        flyConn = RS.RenderStepped:Connect(function(dt)
            if not flyOn then return end
            local c2 = LP.Character if not c2 then return end
            local hrp2 = c2:FindFirstChild("HumanoidRootPart") if not hrp2 then return end
            local cf = CAM.CFrame
            local moveDir = Vector3.new(0, 0, 0)
            local spd = saveData.flySpeed or 40

            if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.C) then
                moveDir = moveDir - Vector3.new(0, 1, 0)
            end

            local isMoving = moveDir.Magnitude > 0.01
            if isMoving then
                moveDir = moveDir.Unit
                hrp2.Velocity = moveDir * spd
                if not (flyAnim and flyAnim.IsPlaying) then playFlyAnim() end
            else
                hrp2.Velocity = Vector3.new(0, 0, 0)
                if flyAnim and flyAnim.IsPlaying and not (idleAnim and idleAnim.IsPlaying) then
                    playIdleAnim()
                elseif not (idleAnim and idleAnim.IsPlaying) then
                    playIdleAnim()
                end
            end
        end)
    else
        if flyConn then flyConn:Disconnect() flyConn = nil end
        stopFlyAnims()
        hum.PlatformStand = false
        TS:Create(CAM, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { FieldOfView = origFOV }):Play()
    end
end

local function setSpeed(v)
    saveData.speed = v writeSave()
    local c = LP.Character if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid") if not hum then return end
    hum.WalkSpeed = v
end

local function setJump(v)
    saveData.jumpPower = v writeSave()
    local c = LP.Character if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid") if not hum then return end
    if hum.UseJumpPower then hum.JumpPower = v else hum.JumpHeight = v end
end

-- Re-apply on respawn
LP.CharacterAdded:Connect(function(c)
    task.wait(0.3)
    local hum = c:WaitForChild("Humanoid", 5) if not hum then return end
    hum.WalkSpeed = saveData.speed or 16
    if hum.UseJumpPower then hum.JumpPower = saveData.jumpPower or 50
    else hum.JumpHeight = saveData.jumpPower or 50 end
    if flyOn then
        task.wait(0.2)
        setFly(true)
    end
end)

-- ============================================================
--  KEY SYSTEM
-- ============================================================
local function buildKeySystem(onSuccess)
    TS:Create(blur, TweenInfo.new(0.5), { Size = 24 }):Play()

    local KF = Instance.new("Frame")
    KF.Size = UDim2.new(1, 0, 1, 0)
    KF.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    KF.BackgroundTransparency = 0.45 KF.BorderSizePixel = 0 KF.ZIndex = 200 KF.Parent = SG

    local KC = Instance.new("Frame")
    KC.AnchorPoint = Vector2.new(0.5, 0.5)
    KC.Position = UDim2.new(0.5, 0, 0.5, 0)
    KC.Size = UDim2.new(0, 0, 0, 215)
    KC.BackgroundColor3 = Color3.fromRGB(17, 17, 24) KC.BackgroundTransparency = 1
    KC.BorderSizePixel = 0 KC.ZIndex = 201 KC.Parent = KF
    mkCorner(KC, 16) mkStroke(KC, 1.8, Color3.fromRGB(55, 55, 70), 0.3)
    mkGrad(KC, Color3.fromRGB(22, 22, 32), Color3.fromRGB(12, 12, 18), 140)

    TS:Create(KC, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 480, 0, 215), BackgroundTransparency = 0.02 }):Play()

    -- Drag
    local kDrag, kDS, kDF = false, nil, nil
    KC.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            kDrag = true kDS = inp.Position kDF = KC.Position
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if kDrag and (inp.UserInputType == Enum.UserInputType.MouseMovement
                   or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - kDS
            KC.Position = UDim2.new(kDF.X.Scale, kDF.X.Offset + d.X, kDF.Y.Scale, kDF.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then kDrag = false end
    end)

    local function closeKF()
        TS:Create(KC, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 215), BackgroundTransparency = 1 }):Play()
        task.delay(0.28, function()
            TS:Create(blur, TweenInfo.new(0.4), { Size = 0 }):Play()
            TS:Create(KF, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            task.delay(0.32, function() if KF and KF.Parent then KF:Destroy() end end)
        end)
    end
    mkCloseBtn(KC, 215, closeKF)

    -- Left panel
    local KLeft = Instance.new("Frame")
    KLeft.Size = UDim2.new(0, 155, 1, 0)
    KLeft.BackgroundColor3 = Color3.fromRGB(11, 11, 16) KLeft.BackgroundTransparency = 0.05
    KLeft.BorderSizePixel = 0 KLeft.ZIndex = 202 KLeft.Parent = KC
    mkCorner(KLeft, 16) mkGrad(KLeft, Color3.fromRGB(18, 18, 26), Color3.fromRGB(9, 9, 14), 180)

    local KLogo = Instance.new("ImageLabel")
    KLogo.Size = UDim2.new(0, 68, 0, 68)
    KLogo.AnchorPoint = Vector2.new(0.5, 0)
    KLogo.Position = UDim2.new(0.5, 0, 0, 18)
    KLogo.BackgroundTransparency = 1 KLogo.Image = LOGO_IMG
    KLogo.ImageTransparency = 0 KLogo.ScaleType = Enum.ScaleType.Fit
    KLogo.ZIndex = 203 KLogo.Parent = KLeft mkCorner(KLogo, 10)
    local KLS = mkStroke(KLogo, 2, Color3.fromRGB(255, 0, 0))
    local klhue = 0
    RS.Heartbeat:Connect(function(dt)
        klhue = (klhue + dt * 0.55) % 1
        if KLS and KLS.Parent then KLS.Color = Color3.fromHSV(klhue, 1, 1) end
    end)

    local function kTxt(p, text, y, sz, col)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -8, 0, 20) l.Position = UDim2.new(0, 4, 0, y)
        l.BackgroundTransparency = 1 l.Text = text
        l.TextColor3 = col or Color3.fromRGB(255, 255, 255)
        l.FontFace = FONT_GOTHAM l.TextSize = sz
        l.TextXAlignment = Enum.TextXAlignment.Center l.ZIndex = 203 l.Parent = p
        return l
    end
    local kt = kTxt(KLeft, "MOVEMENT", 92, 14) gG(kt)
    kTxt(KLeft, "CLIENT GUI", 112, 11, Color3.fromRGB(200, 200, 215))
    kTxt(KLeft, "🔐 KEY SYSTEM", 132, 9, Color3.fromRGB(110, 110, 130))
    kTxt(KLeft, VERSION, 196, 8, Color3.fromRGB(45, 45, 58))

    -- Right panel
    local KRight = Instance.new("Frame")
    KRight.Size = UDim2.new(1, -163, 1, -8)
    KRight.Position = UDim2.new(0, 159, 0, 4)
    KRight.BackgroundTransparency = 1 KRight.ZIndex = 202 KRight.Parent = KC

    local feats = { "🏃 Speed Control", "🦅 Jump Control", "✈️ Fly Mode", "🎮 R6 / R15", "🌐 Client Side", "💾 Auto Save" }
    for i, f in ipairs(feats) do
        local col = (i - 1) % 2 local row = math.floor((i - 1) / 2)
        local fl = Instance.new("TextLabel")
        fl.Size = UDim2.new(0, 145, 0, 14)
        fl.Position = UDim2.new(0, col * 149, 0, 2 + row * 15)
        fl.BackgroundTransparency = 1 fl.Text = f
        fl.TextColor3 = Color3.fromRGB(170, 170, 190) fl.FontFace = FONT_GOTHAM
        fl.TextSize = 8 fl.TextXAlignment = Enum.TextXAlignment.Left
        fl.ZIndex = 203 fl.Parent = KRight
    end

    local KDiv = Instance.new("Frame") KDiv.Size = UDim2.new(1, 0, 0, 1)
    KDiv.Position = UDim2.new(0, 0, 0, 96)
    KDiv.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    KDiv.BackgroundTransparency = 0.82 KDiv.BorderSizePixel = 0 KDiv.ZIndex = 203 KDiv.Parent = KRight

    local KBox = Instance.new("TextBox")
    KBox.Size = UDim2.new(1, -8, 0, 36) KBox.Position = UDim2.new(0, 4, 0, 104)
    KBox.BackgroundColor3 = Color3.fromRGB(26, 26, 36) KBox.BackgroundTransparency = 0.05
    KBox.BorderSizePixel = 0 KBox.PlaceholderText = "Enter key here..."
    KBox.PlaceholderColor3 = Color3.fromRGB(80, 80, 95) KBox.Text = ""
    KBox.TextColor3 = Color3.fromRGB(255, 255, 255) KBox.FontFace = FONT_GOTHAM
    KBox.TextSize = 14 KBox.ClearTextOnFocus = false KBox.ZIndex = 203 KBox.Parent = KRight
    mkCorner(KBox, 9) mkStroke(KBox, 1.5, Color3.fromRGB(60, 60, 80), 0.3)

    local KErrL = Instance.new("TextLabel")
    KErrL.Size = UDim2.new(1, -8, 0, 13) KErrL.Position = UDim2.new(0, 4, 0, 144)
    KErrL.BackgroundTransparency = 1 KErrL.Text = ""
    KErrL.TextColor3 = Color3.fromRGB(220, 60, 60) KErrL.FontFace = FONT_GOTHAM
    KErrL.TextSize = 9 KErrL.TextXAlignment = Enum.TextXAlignment.Center KErrL.ZIndex = 203 KErrL.Parent = KRight

    local function mkKBtn(txt, xOff, c1, c2, c3)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 145, 0, 36) b.Position = UDim2.new(0, xOff, 0, 162)
        b.BackgroundColor3 = c1 b.BorderSizePixel = 0 b.Text = txt
        b.TextColor3 = Color3.fromRGB(255, 255, 255) b.FontFace = FONT_GOTHAM
        b.TextSize = 11 b.ZIndex = 203 b.Parent = KRight mkCorner(b, 9) mkGrad(b, c2, c3, 90)
        b.MouseEnter:Connect(function()    TS:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.15 }):Play() end)
        b.MouseLeave:Connect(function()    TS:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0   }):Play() end)
        b.MouseButton1Down:Connect(function() TS:Create(b, TweenInfo.new(0.07), { BackgroundTransparency = 0.35 }):Play() end)
        b.MouseButton1Up:Connect(function()   TS:Create(b, TweenInfo.new(0.1),  { BackgroundTransparency = 0   }):Play() end)
        return b
    end
    local KVerBtn = mkKBtn("✅  Verify Key", 4,
        Color3.fromRGB(38, 140, 75), Color3.fromRGB(55, 175, 95), Color3.fromRGB(25, 105, 55))
    local KHintBtn = mkKBtn("💡  Get Key", 153,
        Color3.fromRGB(180, 120, 0), Color3.fromRGB(255, 185, 30), Color3.fromRGB(160, 95, 0))

    -- Hint popup
    local KWarn = Instance.new("Frame")
    KWarn.Size = UDim2.new(0, 260, 0, 110)
    KWarn.AnchorPoint = Vector2.new(0.5, 0.5)
    KWarn.Position = UDim2.new(0.5, 0, 0.5, 0)
    KWarn.BackgroundColor3 = Color3.fromRGB(30, 18, 6)
    KWarn.BackgroundTransparency = 0.02 KWarn.BorderSizePixel = 0
    KWarn.Visible = false KWarn.ZIndex = 250 KWarn.Parent = SG
    mkCorner(KWarn, 14) mkStroke(KWarn, 2, Color3.fromRGB(255, 165, 30), 0.15)
    mkGrad(KWarn, Color3.fromRGB(48, 26, 8), Color3.fromRGB(22, 12, 4), 140)

    local kwT = Instance.new("TextLabel") kwT.Size = UDim2.new(1, -20, 0, 20)
    kwT.Position = UDim2.new(0, 10, 0, 10) kwT.BackgroundTransparency = 1
    kwT.Text = "🔑  Key Hint" kwT.TextColor3 = Color3.fromRGB(255, 180, 30)
    kwT.FontFace = FONT_GOTHAM kwT.TextSize = 13
    kwT.TextXAlignment = Enum.TextXAlignment.Left kwT.ZIndex = 251 kwT.Parent = KWarn

    local kwSub = Instance.new("TextLabel") kwSub.Size = UDim2.new(1, -20, 0, 26)
    kwSub.Position = UDim2.new(0, 10, 0, 36) kwSub.BackgroundTransparency = 1
    kwSub.Text = "The key is a name — think of a city\nin Spain! 😉"
    kwSub.TextColor3 = Color3.fromRGB(220, 180, 100) kwSub.FontFace = FONT_GOTHAM
    kwSub.TextSize = 10 kwSub.TextWrapped = true
    kwSub.TextXAlignment = Enum.TextXAlignment.Left kwSub.ZIndex = 251 kwSub.Parent = KWarn

    local kwClose = Instance.new("TextButton")
    kwClose.Size = UDim2.new(1, -20, 0, 28) kwClose.Position = UDim2.new(0, 10, 0, 74)
    kwClose.BackgroundColor3 = Color3.fromRGB(70, 70, 82) kwClose.BorderSizePixel = 0
    kwClose.Text = "✖  Close" kwClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    kwClose.FontFace = FONT_GOTHAM kwClose.TextSize = 10 kwClose.ZIndex = 251 kwClose.Parent = KWarn
    mkCorner(kwClose, 8) mkGrad(kwClose, Color3.fromRGB(90, 90, 105), Color3.fromRGB(50, 50, 62), 90)

    local function closeWarn()
        TS:Create(KWarn, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 260, 0, 0), BackgroundTransparency = 1 }):Play()
        task.delay(0.25, function()
            KWarn.Visible = false KWarn.Size = UDim2.new(0, 260, 0, 110) KWarn.BackgroundTransparency = 0.02
        end)
    end
    kwClose.MouseButton1Click:Connect(closeWarn) kwClose.TouchTap:Connect(closeWarn)

    KHintBtn.MouseButton1Click:Connect(function()
        KWarn.Visible = true KWarn.Size = UDim2.new(0, 260, 0, 0) KWarn.BackgroundTransparency = 1
        TS:Create(KWarn, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 260, 0, 110), BackgroundTransparency = 0.02 }):Play()
    end)
    KHintBtn.TouchTap:Connect(function() KHintBtn.MouseButton1Click:Fire() end)

    local function tryKey()
        local input = KBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if input == CORRECT_KEY then
            saveData.keyPassed = true writeSave()
            KErrL.Text = "✅  Key accepted!" KErrL.TextColor3 = Color3.fromRGB(80, 220, 120)
            TS:Create(KBox, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(18, 38, 22) }):Play()
            task.delay(0.32, function()
                TS:Create(KC, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                    Size = UDim2.new(0, 0, 0, 215), BackgroundTransparency = 1 }):Play()
            end)
            task.delay(0.62, function()
                TS:Create(KF, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
                task.delay(0.32, function()
                    if KF and KF.Parent then KF:Destroy() end
                    if KWarn and KWarn.Parent then KWarn:Destroy() end
                end)
                onSuccess()
            end)
        else
            KErrL.Text = "❌  Wrong key!" KErrL.TextColor3 = Color3.fromRGB(220, 60, 60)
            TS:Create(KBox, TweenInfo.new(0.06), { BackgroundColor3 = Color3.fromRGB(60, 20, 20) }):Play()
            local orig = KC.Position
            for i = 1, 5 do
                task.delay(i * 0.045, function()
                    KC.Position = UDim2.new(orig.X.Scale, orig.X.Offset + (i % 2 == 0 and 8 or -8), orig.Y.Scale, orig.Y.Offset)
                end)
            end
            task.delay(0.26, function() TS:Create(KC, TweenInfo.new(0.14), { Position = orig }):Play() end)
            task.delay(0.6, function() TS:Create(KBox, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(26, 26, 36) }):Play() end)
        end
    end
    KVerBtn.MouseButton1Click:Connect(tryKey) KVerBtn.TouchTap:Connect(tryKey)
    KBox.FocusLost:Connect(function(ep) if ep then tryKey() end end)
end

-- ============================================================
--  LOADING SCREEN
-- ============================================================
local function buildLoadingScreen(onDone)
    local LF = Instance.new("Frame")
    LF.Size = UDim2.new(1, 0, 1, 0)
    LF.BackgroundColor3 = Color3.fromRGB(0, 0, 0) LF.BackgroundTransparency = 0.35
    LF.BorderSizePixel = 0 LF.ZIndex = 100 LF.Parent = SG

    local LLogo = Instance.new("ImageLabel")
    LLogo.Size = UDim2.new(0, 100, 0, 100)
    LLogo.AnchorPoint = Vector2.new(0.5, 0.5)
    LLogo.Position = UDim2.new(0.5, 0, 0.34, 0)
    LLogo.BackgroundTransparency = 1 LLogo.Image = LOGO_IMG
    LLogo.ImageTransparency = 0 LLogo.ScaleType = Enum.ScaleType.Fit
    LLogo.Visible = true LLogo.ZIndex = 101 LLogo.Parent = LF mkCorner(LLogo, 16)
    local LLS = mkStroke(LLogo, 2.5, Color3.fromRGB(255, 0, 0))
    TS:Create(LLogo, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        Size = UDim2.new(0, 115, 0, 115) }):Play()
    local llhue = 0
    RS.Heartbeat:Connect(function(dt)
        llhue = (llhue + dt * 0.55) % 1
        if LLS and LLS.Parent then LLS.Color = Color3.fromHSV(llhue, 1, 1) end
    end)

    local LTit = Instance.new("TextLabel")
    LTit.Size = UDim2.new(0, 320, 0, 36)
    LTit.AnchorPoint = Vector2.new(0.5, 0.5) LTit.Position = UDim2.new(0.5, 0, 0.52, 0)
    LTit.BackgroundTransparency = 1 LTit.Text = "CLIENT MOVEMENT GUI " .. VERSION
    LTit.TextColor3 = Color3.fromRGB(255, 255, 255) LTit.FontFace = FONT_GOTHAM
    LTit.TextSize = 20 LTit.ZIndex = 101 LTit.Parent = LF gG(LTit)

    local LGreet = Instance.new("TextLabel")
    LGreet.Size = UDim2.new(0, 300, 0, 20)
    LGreet.AnchorPoint = Vector2.new(0.5, 0.5) LGreet.Position = UDim2.new(0.5, 0, 0.60, 0)
    LGreet.BackgroundTransparency = 1
    LGreet.Text = getGreeting() .. ", " .. LP.DisplayName .. "!"
    LGreet.TextColor3 = Color3.fromRGB(255, 215, 60) LGreet.FontFace = FONT_GOTHAM
    LGreet.TextSize = 13 LGreet.ZIndex = 101 LGreet.Parent = LF

    local LSub = Instance.new("TextLabel")
    LSub.Size = UDim2.new(0, 300, 0, 18)
    LSub.AnchorPoint = Vector2.new(0.5, 0.5) LSub.Position = UDim2.new(0.5, 0, 0.67, 0)
    LSub.BackgroundTransparency = 1 LSub.Text = "Initializing..."
    LSub.TextColor3 = Color3.fromRGB(165, 165, 165) LSub.FontFace = FONT_GOTHAM
    LSub.TextSize = 12 LSub.ZIndex = 101 LSub.Parent = LF

    local BBG = Instance.new("Frame")
    BBG.Size = UDim2.new(0, 280, 0, 6)
    BBG.AnchorPoint = Vector2.new(0.5, 0.5) BBG.Position = UDim2.new(0.5, 0, 0.74, 0)
    BBG.BackgroundColor3 = Color3.fromRGB(32, 32, 32) BBG.BackgroundTransparency = 0.15
    BBG.BorderSizePixel = 0 BBG.ZIndex = 101 BBG.Parent = LF mkCorner(BBG, 99)
    local BFill = Instance.new("Frame")
    BFill.Size = UDim2.new(0, 0, 1, 0)
    BFill.BackgroundColor3 = Color3.fromRGB(255, 200, 50) BFill.BorderSizePixel = 0
    BFill.ZIndex = 102 BFill.Parent = BBG gG(BFill) mkCorner(BFill, 99)

    local steps = {
        { t = "Initializing modules...",     d = 0.26 },
        { t = "Loading movement system...",  d = 0.24 },
        { t = "Setting up fly engine...",    d = 0.22 },
        { t = "Loading R6 animations...",    d = 0.20 },
        { t = "Loading R15 animations...",   d = 0.18 },
        { t = "Building GUI panels...",      d = 0.16 },
        { t = "Applying saved config...",    d = 0.14 },
        { t = "Ready! 🚀",                   d = 0.10 },
    }
    task.spawn(function()
        for i, s in ipairs(steps) do
            LSub.Text = s.t
            TS:Create(BFill, TweenInfo.new(s.d, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(i / #steps, 0, 1, 0) }):Play()
            task.wait(s.d + 0.04)
        end
        task.wait(0.3)
        TS:Create(blur, TweenInfo.new(0.6), { Size = 0 }):Play()
        TS:Create(LF, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
        for _, obj in ipairs(LF:GetDescendants()) do
            if obj:IsA("TextLabel") then TS:Create(obj, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
            elseif obj:IsA("ImageLabel") then TS:Create(obj, TweenInfo.new(0.35), { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
            elseif obj:IsA("Frame") then TS:Create(obj, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play() end
        end
        task.wait(0.55)
        if LF and LF.Parent then LF:Destroy() end
        onDone()
    end)
end

-- ============================================================
--  MAIN FRAME + TABS
-- ============================================================
local function buildMainFrame()
    local MF = Instance.new("Frame")
    MF.Size = UDim2.new(0, 560, 0, 0)
    MF.AnchorPoint = Vector2.new(0.5, 0.5)
    MF.Position = UDim2.new(0.5, 0, 0.5, 0)
    MF.BackgroundColor3 = Color3.fromRGB(17, 17, 22) MF.BackgroundTransparency = 0.05
    MF.BorderSizePixel = 0 MF.Visible = false MF.ZIndex = 10 MF.Parent = SG
    mkCorner(MF, 16) mkStroke(MF, 1.5, Color3.fromRGB(55, 55, 65), 0.4)
    mkGrad(MF, Color3.fromRGB(24, 24, 30), Color3.fromRGB(13, 13, 17), 140)

    -- Banner
    local BNR = Instance.new("ImageLabel")
    BNR.Size = UDim2.new(1, 0, 0, 72)
    BNR.BackgroundColor3 = Color3.fromRGB(10, 10, 15) BNR.BackgroundTransparency = 0
    BNR.BorderSizePixel = 0 BNR.Image = BANNER_IMG BNR.ImageTransparency = 0
    BNR.ScaleType = Enum.ScaleType.Crop BNR.ZIndex = 11 BNR.Parent = MF mkCorner(BNR, 16)
    local bFd = Instance.new("UIGradient")
    bFd.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.72, 0), NumberSequenceKeypoint.new(1, 1) })
    bFd.Rotation = 90 bFd.Parent = BNR

    local VBadge = Instance.new("TextLabel")
    VBadge.Size = UDim2.new(0, 115, 0, 18)
    VBadge.Position = UDim2.new(0, 10, 0, 8)
    VBadge.BackgroundColor3 = Color3.fromRGB(0, 0, 0) VBadge.BackgroundTransparency = 0.4
    VBadge.BorderSizePixel = 0 VBadge.Text = "Movement GUI " .. VERSION
    VBadge.TextColor3 = Color3.fromRGB(255, 215, 60) VBadge.FontFace = FONT_GOTHAM
    VBadge.TextSize = 7 VBadge.ZIndex = 12 VBadge.Parent = BNR mkCorner(VBadge, 6)

    -- Banner drag
    BNR.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            isDrag = true dS = inp.Position dF = MF.Position
        end
    end)

    local function closeMF()
        guiOpen = false
        TS:Create(MF, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 560, 0, 0), BackgroundTransparency = 1 }):Play()
        task.delay(0.28, function()
            MF.Visible = false MF.Size = UDim2.new(0, 560, 0, 370) MF.BackgroundTransparency = 0.05
        end)
    end
    mkCloseBtn(MF, 20, closeMF)

    -- Tab bar
    local TB = Instance.new("Frame")
    TB.Size = UDim2.new(1, -16, 0, 30)
    TB.Position = UDim2.new(0, 8, 0, 76)
    TB.BackgroundTransparency = 1 TB.ZIndex = 12 TB.Parent = MF

    local tabNames = { "Home", "Movement", "Misc" }
    local tabBtns = {} local tabPages = {}

    for i, tn in ipairs(tabNames) do
        local tb = Instance.new("TextButton")
        tb.Size = UDim2.new(0, 110, 0, 28)
        tb.Position = UDim2.new(0, (i - 1) * 115, 0, 0)
        tb.BackgroundColor3 = Color3.fromRGB(24, 24, 32) tb.BackgroundTransparency = 0.1
        tb.BorderSizePixel = 0 tb.Text = tn tb.TextColor3 = Color3.fromRGB(130, 130, 150)
        tb.FontFace = FONT_GOTHAM tb.TextSize = 10 tb.ZIndex = 13 tb.Parent = TB mkCorner(tb, 8)
        local pg = Instance.new("Frame")
        pg.Size = UDim2.new(1, -16, 1, -118)
        pg.Position = UDim2.new(0, 8, 0, 110)
        pg.BackgroundTransparency = 1 pg.Visible = false pg.ZIndex = 12 pg.Parent = MF
        tabBtns[tn] = tb tabPages[tn] = pg
    end

    local function switchTab(name)
        for n, pg in pairs(tabPages) do
            pg.Visible = (n == name)
            local bt = tabBtns[n]
            if n == name then
                bt.TextColor3 = Color3.fromRGB(255, 215, 60)
                bt.BackgroundColor3 = Color3.fromRGB(35, 35, 48) bt.BackgroundTransparency = 0
            else
                bt.TextColor3 = Color3.fromRGB(130, 130, 150)
                bt.BackgroundColor3 = Color3.fromRGB(24, 24, 32) bt.BackgroundTransparency = 0.1
            end
        end
    end
    for tn, bt in pairs(tabBtns) do
        bt.MouseButton1Click:Connect(function() switchTab(tn) end)
        bt.TouchTap:Connect(function() switchTab(tn) end)
    end

    uiRefs.MF = MF uiRefs.tabPages = tabPages uiRefs.switchTab = switchTab
    return MF, tabPages, switchTab
end

-- ============================================================
--  HOME TAB
-- ============================================================
local function buildHomeTab(HP)
    local HBnr = Instance.new("ImageLabel")
    HBnr.Size = UDim2.new(1, 0, 0, 65)
    HBnr.BackgroundColor3 = Color3.fromRGB(10, 10, 15) HBnr.BackgroundTransparency = 0
    HBnr.BorderSizePixel = 0 HBnr.Image = BANNER_IMG HBnr.ImageTransparency = 0
    HBnr.ScaleType = Enum.ScaleType.Crop HBnr.ZIndex = 13 HBnr.Parent = HP mkCorner(HBnr, 10)

    local HWel = Instance.new("TextLabel")
    HWel.Size = UDim2.new(1, 0, 0, 22)
    HWel.Position = UDim2.new(0, 0, 0, 72)
    HWel.BackgroundTransparency = 1
    HWel.Text = getGreeting() .. ", " .. LP.DisplayName .. "! 👋"
    HWel.TextColor3 = Color3.fromRGB(255, 255, 255) HWel.FontFace = FONT_GOTHAM
    HWel.TextSize = 13 HWel.TextXAlignment = Enum.TextXAlignment.Center HWel.ZIndex = 13 HWel.Parent = HP
    gG(HWel)

    local function mkStatCard(parent, icon, label, val, x)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 118, 0, 50)
        f.Position = UDim2.new(0, x, 0, 102)
        f.BackgroundColor3 = Color3.fromRGB(22, 22, 30) f.BackgroundTransparency = 0.1
        f.BorderSizePixel = 0 f.ZIndex = 13 f.Parent = parent
        mkCorner(f, 10) mkStroke(f, 1, Color3.fromRGB(50, 50, 62), 0.5)
        local ic = Instance.new("TextLabel")
        ic.Size = UDim2.new(0, 30, 1, 0) ic.BackgroundTransparency = 1
        ic.Text = icon ic.FontFace = FONT_GOTHAM ic.TextSize = 16 ic.ZIndex = 14 ic.Parent = f
        local lt = Instance.new("TextLabel")
        lt.Size = UDim2.new(1, -34, 0, 16) lt.Position = UDim2.new(0, 32, 0, 6)
        lt.BackgroundTransparency = 1 lt.Text = label
        lt.TextColor3 = Color3.fromRGB(130, 130, 150) lt.FontFace = FONT_GOTHAM lt.TextSize = 9
        lt.TextXAlignment = Enum.TextXAlignment.Left lt.ZIndex = 14 lt.Parent = f
        local vl = Instance.new("TextLabel")
        vl.Size = UDim2.new(1, -34, 0, 20) vl.Position = UDim2.new(0, 32, 0, 22)
        vl.BackgroundTransparency = 1 vl.Text = val
        vl.TextColor3 = Color3.fromRGB(255, 255, 255) vl.FontFace = FONT_GOTHAM vl.TextSize = 12
        vl.TextXAlignment = Enum.TextXAlignment.Left vl.ZIndex = 14 vl.Parent = f
        return vl
    end

    local spdV  = mkStatCard(HP, "🏃", "Speed",      tostring(saveData.speed), 0)
    local jmpV  = mkStatCard(HP, "🦅", "Jump Power", tostring(saveData.jumpPower), 122)
    local flyV  = mkStatCard(HP, "✈️",  "Fly",        "OFF", 244)
    local pingV = mkStatCard(HP, "📡", "Ping",       "—ms", 366)

    uiRefs.homeSpdV = spdV uiRefs.homeJmpV = jmpV uiRefs.homeFlyV = flyV

    RS.Heartbeat:Connect(function()
        local ok, ping = pcall(function() return LP:GetNetworkPing() end)
        if ok and pingV and pingV.Parent then pingV.Text = math.floor(ping * 1000) .. "ms" end
        if spdV and spdV.Parent then spdV.Text = tostring(saveData.speed) end
        if jmpV and jmpV.Parent then jmpV.Text = tostring(saveData.jumpPower) end
        if flyV and flyV.Parent then
            local tc = getTheme()
            flyV.Text = flyOn and "ON" or "OFF"
            flyV.TextColor3 = flyOn and tc[1] or Color3.fromRGB(255, 255, 255)
        end
    end)

    local HDiv = Instance.new("Frame")
    HDiv.Size = UDim2.new(0.92, 0, 0, 1) HDiv.AnchorPoint = Vector2.new(0.5, 0)
    HDiv.Position = UDim2.new(0.5, 0, 0, 162)
    HDiv.BackgroundColor3 = Color3.fromRGB(255, 255, 255) HDiv.BackgroundTransparency = 0.82
    HDiv.BorderSizePixel = 0 HDiv.ZIndex = 13 HDiv.Parent = HP

    local startTime = os.clock()
    local UptL = Instance.new("TextLabel")
    UptL.Size = UDim2.new(1, 0, 0, 16)
    UptL.Position = UDim2.new(0, 0, 0, 170)
    UptL.BackgroundTransparency = 1 UptL.Text = "⏱  Session: 00:00"
    UptL.TextColor3 = Color3.fromRGB(90, 90, 110) UptL.FontFace = FONT_GOTHAM UptL.TextSize = 9
    UptL.TextXAlignment = Enum.TextXAlignment.Center UptL.ZIndex = 13 UptL.Parent = HP
    RS.Heartbeat:Connect(function()
        if UptL and UptL.Parent then
            local s = math.floor(os.clock() - startTime)
            UptL.Text = string.format("⏱  Session: %02d:%02d", math.floor(s / 60), s % 60)
        end
    end)

    local rigLbl = Instance.new("TextLabel")
    rigLbl.Size = UDim2.new(1, 0, 0, 14)
    rigLbl.Position = UDim2.new(0, 0, 0, 192)
    rigLbl.BackgroundTransparency = 1
    rigLbl.Text = "Rig type: " .. getRigType() .. "  |  RightShift = Toggle GUI"
    rigLbl.TextColor3 = Color3.fromRGB(75, 75, 95) rigLbl.FontFace = FONT_GOTHAM rigLbl.TextSize = 8
    rigLbl.TextXAlignment = Enum.TextXAlignment.Center rigLbl.ZIndex = 13 rigLbl.Parent = HP

    RS.Heartbeat:Connect(function()
        if rigLbl and rigLbl.Parent then
            rigLbl.Text = "Rig type: " .. getRigType() .. "  |  RightShift = Toggle GUI"
        end
    end)
end

-- ============================================================
--  MOVEMENT TAB
-- ============================================================
local function buildMovementTab(MP)
    -- Speed card + input
    local _,  sp,  sk,  sd,  sdt = mkCard(MP, "🏃 Speed Boost",  0,   0)
    local _,  jp,  jk,  jd,  jdt = mkCard(MP, "🦅 Jump Power",   178, 0)
    local _,  fp,  fk,  fd,  fdt = mkCard(MP, "✈️  Fly Mode",     0,   58)

    pillRefs.spdPill = sp  pillRefs.spdKnob = sk  pillRefs.spdDot = sd  pillRefs.spdDtxt = sdt
    pillRefs.jmpPill = jp  pillRefs.jmpKnob = jk  pillRefs.jmpDot = jd  pillRefs.jmpDtxt = jdt
    pillRefs.flyPill = fp  pillRefs.flyKnob = fk  pillRefs.flyDot = fd  pillRefs.flyDtxt = fdt

    local spdBox, spdBtn  = mkInput(MP, "Walk Speed",   saveData.speed,      500, 0,   118)
    local jmpBox, jmpBtn  = mkInput(MP, "Jump Power",   saveData.jumpPower,  500, 178, 118)
    local flyBox, flyBtn  = mkInput(MP, "Fly Speed",    saveData.flySpeed,   200, 0,   190)
    local fovBox, fovBtn  = mkInput(MP, "Fly FOV",      saveData.flyFOV,     120, 178, 190)

    uiRefs.spdBox = spdBox uiRefs.spdBtn = spdBtn
    uiRefs.jmpBox = jmpBox uiRefs.jmpBtn = jmpBtn
    uiRefs.flyBox = flyBox uiRefs.flyBtn = flyBtn
    uiRefs.fovBox = fovBox uiRefs.fovBtn = fovBtn

    -- Fly controls hint
    local flyHint = Instance.new("TextLabel")
    flyHint.Size = UDim2.new(1, 0, 0, 18)
    flyHint.Position = UDim2.new(0, 0, 1, -22)
    flyHint.BackgroundTransparency = 1
    flyHint.Text = "✈️  Fly controls: WASD to move · Space = up · Ctrl/C = down"
    flyHint.TextColor3 = Color3.fromRGB(75, 75, 95) flyHint.FontFace = FONT_GOTHAM flyHint.TextSize = 8
    flyHint.TextXAlignment = Enum.TextXAlignment.Center flyHint.ZIndex = 13 flyHint.Parent = MP

    -- init pill states from save
    local tc = getTheme()
    animT(pillRefs.spdPill, pillRefs.spdKnob, pillRefs.spdDot, pillRefs.spdDtxt, saveData.speed ~= 16, tc[1], "ACTIVE")
    animT(pillRefs.jmpPill, pillRefs.jmpKnob, pillRefs.jmpDot, pillRefs.jmpDtxt, saveData.jumpPower ~= 50, tc[1], "ACTIVE")
end

-- ============================================================
--  MISC TAB
-- ============================================================
local function buildMiscTab(MSP)
    -- Rig type label
    local rigTitle = Instance.new("TextLabel")
    rigTitle.Size = UDim2.new(1, 0, 0, 16)
    rigTitle.Position = UDim2.new(0, 0, 0, 0)
    rigTitle.BackgroundTransparency = 1 rigTitle.Text = "🎮  Rig Type Selection"
    rigTitle.TextColor3 = Color3.fromRGB(160, 160, 180) rigTitle.FontFace = FONT_GOTHAM rigTitle.TextSize = 10
    rigTitle.TextXAlignment = Enum.TextXAlignment.Left rigTitle.ZIndex = 13 rigTitle.Parent = MSP

    -- R6 button
    local R6Btn = Instance.new("TextButton")
    R6Btn.Size = UDim2.new(0, 172, 0, 52)
    R6Btn.Position = UDim2.new(0, 0, 0, 22)
    R6Btn.BackgroundColor3 = Color3.fromRGB(24, 24, 30) R6Btn.BackgroundTransparency = 0.08
    R6Btn.BorderSizePixel = 0 R6Btn.Text = "" R6Btn.ZIndex = 13 R6Btn.Parent = MSP
    mkCorner(R6Btn, 10) mkStroke(R6Btn, 1, Color3.fromRGB(50, 50, 62), 0.5)
    local r6ico = Instance.new("TextLabel")
    r6ico.Size = UDim2.new(1, 0, 0, 24) r6ico.Position = UDim2.new(0, 12, 0, 6)
    r6ico.BackgroundTransparency = 1 r6ico.Text = "🤖  R6"
    r6ico.TextColor3 = Color3.fromRGB(255, 255, 255) r6ico.FontFace = FONT_GOTHAM r6ico.TextSize = 13
    r6ico.TextXAlignment = Enum.TextXAlignment.Left r6ico.ZIndex = 14 r6ico.Parent = R6Btn gG(r6ico)
    local r6sub = Instance.new("TextLabel")
    r6sub.Size = UDim2.new(1, 0, 0, 14) r6sub.Position = UDim2.new(0, 12, 0, 32)
    r6sub.BackgroundTransparency = 1 r6sub.Text = "6-part classic rig"
    r6sub.TextColor3 = Color3.fromRGB(90, 90, 105) r6sub.FontFace = FONT_GOTHAM r6sub.TextSize = 8
    r6sub.TextXAlignment = Enum.TextXAlignment.Left r6sub.ZIndex = 14 r6sub.Parent = R6Btn
    uiRefs.R6Btn = R6Btn

    -- R15 button
    local R15Btn = Instance.new("TextButton")
    R15Btn.Size = UDim2.new(0, 172, 0, 52)
    R15Btn.Position = UDim2.new(0, 178, 0, 22)
    R15Btn.BackgroundColor3 = Color3.fromRGB(24, 24, 30) R15Btn.BackgroundTransparency = 0.08
    R15Btn.BorderSizePixel = 0 R15Btn.Text = "" R15Btn.ZIndex = 13 R15Btn.Parent = MSP
    mkCorner(R15Btn, 10) mkStroke(R15Btn, 1, Color3.fromRGB(50, 50, 62), 0.5)
    local r15ico = Instance.new("TextLabel")
    r15ico.Size = UDim2.new(1, 0, 0, 24) r15ico.Position = UDim2.new(0, 12, 0, 6)
    r15ico.BackgroundTransparency = 1 r15ico.Text = "🦾  R15"
    r15ico.TextColor3 = Color3.fromRGB(255, 255, 255) r15ico.FontFace = FONT_GOTHAM r15ico.TextSize = 13
    r15ico.TextXAlignment = Enum.TextXAlignment.Left r15ico.ZIndex = 14 r15ico.Parent = R15Btn gG(r15ico)
    local r15sub = Instance.new("TextLabel")
    r15sub.Size = UDim2.new(1, 0, 0, 14) r15sub.Position = UDim2.new(0, 12, 0, 32)
    r15sub.BackgroundTransparency = 1 r15sub.Text = "15-part modern rig"
    r15sub.TextColor3 = Color3.fromRGB(90, 90, 105) r15sub.FontFace = FONT_GOTHAM r15sub.TextSize = 8
    r15sub.TextXAlignment = Enum.TextXAlignment.Left r15sub.ZIndex = 14 r15sub.Parent = R15Btn
    uiRefs.R15Btn = R15Btn

    -- Active indicator label
    local rigStatus = Instance.new("TextLabel")
    rigStatus.Size = UDim2.new(1, 0, 0, 14)
    rigStatus.Position = UDim2.new(0, 0, 0, 80)
    rigStatus.BackgroundTransparency = 1
    rigStatus.Text = "Detected: " .. getRigType() .. " · Override: " .. saveData.rigType
    rigStatus.TextColor3 = Color3.fromRGB(90, 90, 110) rigStatus.FontFace = FONT_GOTHAM rigStatus.TextSize = 8
    rigStatus.TextXAlignment = Enum.TextXAlignment.Left rigStatus.ZIndex = 13 rigStatus.Parent = MSP

    local function refreshRigBtns()
        local tc = getTheme()
        for _, rb in ipairs({ R6Btn, R15Btn }) do
            local ex = rb:FindFirstChildOfClass("UIStroke") if ex then ex:Destroy() end
        end
        local active = (saveData.rigType == "R6") and R6Btn or R15Btn
        mkStroke(active, 2.5, getTheme()[1], 0)
        rigStatus.Text = "Detected: " .. getRigType() .. " · Override: " .. saveData.rigType
    end
    refreshRigBtns()

    R6Btn.MouseButton1Click:Connect(function()
        saveData.rigType = "R6" writeSave()
        refreshRigBtns()
        showNotif("🤖 Rig Type", "Set to R6 — animations updated", Color3.fromRGB(42, 95, 210))
        if flyOn then setFly(false) task.wait(0.1) setFly(true) end
    end)
    R6Btn.TouchTap:Connect(function() R6Btn.MouseButton1Click:Fire() end)

    R15Btn.MouseButton1Click:Connect(function()
        saveData.rigType = "R15" writeSave()
        refreshRigBtns()
        showNotif("🦾 Rig Type", "Set to R15 — animations updated", Color3.fromRGB(130, 50, 210))
        if flyOn then setFly(false) task.wait(0.1) setFly(true) end
    end)
    R15Btn.TouchTap:Connect(function() R15Btn.MouseButton1Click:Fire() end)

    -- Divider
    local div = Instance.new("Frame")
    div.Size = UDim2.new(1, 0, 0, 1) div.Position = UDim2.new(0, 0, 0, 104)
    div.BackgroundColor3 = Color3.fromRGB(255, 255, 255) div.BackgroundTransparency = 0.82
    div.BorderSizePixel = 0 div.ZIndex = 13 div.Parent = MSP

    -- Anim IDs display
    local animTitle = Instance.new("TextLabel")
    animTitle.Size = UDim2.new(1, 0, 0, 14)
    animTitle.Position = UDim2.new(0, 0, 0, 112)
    animTitle.BackgroundTransparency = 1 animTitle.Text = "🎞️  Loaded Animations"
    animTitle.TextColor3 = Color3.fromRGB(160, 160, 180) animTitle.FontFace = FONT_GOTHAM animTitle.TextSize = 10
    animTitle.TextXAlignment = Enum.TextXAlignment.Left animTitle.ZIndex = 13 animTitle.Parent = MSP

    local animInfo = {
        { "R6  Idle",  ANIM_R6_IDLE  },
        { "R6  Fly",   ANIM_R6_FLY   },
        { "R15 Idle",  ANIM_R15_IDLE },
        { "R15 Fly",   ANIM_R15_FLY  },
    }
    for i, ai in ipairs(animInfo) do
        local col = (i - 1) % 2 local row = math.floor((i - 1) / 2)
        local af = Instance.new("Frame")
        af.Size = UDim2.new(0, 255, 0, 32)
        af.Position = UDim2.new(0, col * 264, 0, 130 + row * 36)
        af.BackgroundColor3 = Color3.fromRGB(22, 22, 30) af.BackgroundTransparency = 0.1
        af.BorderSizePixel = 0 af.ZIndex = 13 af.Parent = MSP
        mkCorner(af, 8) mkStroke(af, 1, Color3.fromRGB(50, 50, 62), 0.6)
        local aLbl = Instance.new("TextLabel")
        aLbl.Size = UDim2.new(0, 70, 1, 0) aLbl.Position = UDim2.new(0, 8, 0, 0)
        aLbl.BackgroundTransparency = 1 aLbl.Text = ai[1]
        aLbl.TextColor3 = Color3.fromRGB(160, 160, 180) aLbl.FontFace = FONT_GOTHAM aLbl.TextSize = 8
        aLbl.TextXAlignment = Enum.TextXAlignment.Left aLbl.ZIndex = 14 aLbl.Parent = af
        local aId = Instance.new("TextLabel")
        aId.Size = UDim2.new(1, -82, 1, 0) aId.Position = UDim2.new(0, 78, 0, 0)
        aId.BackgroundTransparency = 1 aId.Text = ai[2]:gsub("rbxassetid://", "")
        aId.TextColor3 = Color3.fromRGB(255, 215, 60) aId.FontFace = FONT_GOTHAM aId.TextSize = 8
        aId.TextXAlignment = Enum.TextXAlignment.Left aId.ZIndex = 14 aId.Parent = af
    end
end

-- ============================================================
--  FEATURE SETTERS (wire pills + inputs)
-- ============================================================
local function buildFeatureSetters()
    local function flashBtn(btn)
        TS:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(45, 190, 75) }):Play()
        task.delay(0.38, function() TS:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(42, 95, 210) }):Play() end)
    end

    local tc = getTheme()

    -- Speed pill toggle (speed enabled/disabled — resets to default if off)
    local speedEnabled = saveData.speed ~= 16
    pillRefs.spdPill.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        speedEnabled = not speedEnabled
        if speedEnabled then
            local v = tonumber(uiRefs.spdBox.Text) or saveData.speed
            v = clamp(math.floor(v), 1, 500)
            setSpeed(v) uiRefs.spdBox.Text = tostring(v)
            animT(pillRefs.spdPill, pillRefs.spdKnob, pillRefs.spdDot, pillRefs.spdDtxt, true, tc[1], "ON")
            showNotif("🏃 Speed", "Speed set to " .. v, tc[1])
        else
            setSpeed(16)
            animT(pillRefs.spdPill, pillRefs.spdKnob, pillRefs.spdDot, pillRefs.spdDtxt, false, tc[1], "OFF")
            showNotif("🏃 Speed", "Speed reset to 16", Color3.fromRGB(90, 90, 105))
        end
    end)

    -- Jump pill toggle
    local jumpEnabled = saveData.jumpPower ~= 50
    pillRefs.jmpPill.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        jumpEnabled = not jumpEnabled
        if jumpEnabled then
            local v = tonumber(uiRefs.jmpBox.Text) or saveData.jumpPower
            v = clamp(math.floor(v), 1, 500)
            setJump(v) uiRefs.jmpBox.Text = tostring(v)
            animT(pillRefs.jmpPill, pillRefs.jmpKnob, pillRefs.jmpDot, pillRefs.jmpDtxt, true, tc[1], "ON")
            showNotif("🦅 Jump", "Jump power set to " .. v, tc[1])
        else
            setJump(50)
            animT(pillRefs.jmpPill, pillRefs.jmpKnob, pillRefs.jmpDot, pillRefs.jmpDtxt, false, tc[1], "OFF")
        end
    end)

    -- Fly pill toggle
    pillRefs.flyPill.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        flyOn = not flyOn
        setFly(flyOn)
        animT(pillRefs.flyPill, pillRefs.flyKnob, pillRefs.flyDot, pillRefs.flyDtxt, flyOn, Color3.fromRGB(60, 160, 240), "ON")
        if flyOn then
            showNotif("✈️ Fly", "Fly enabled  [WASD+Space+Ctrl]", Color3.fromRGB(60, 160, 240))
        else
            showNotif("✈️ Fly", "Fly disabled", Color3.fromRGB(90, 90, 105))
        end
    end)

    -- Speed input APPLY
    uiRefs.spdBtn.MouseButton1Click:Connect(function()
        local v = tonumber(uiRefs.spdBox.Text) if not v then return end
        v = clamp(math.floor(v), 1, 500) uiRefs.spdBox.Text = tostring(v)
        setSpeed(v) speedEnabled = true
        animT(pillRefs.spdPill, pillRefs.spdKnob, pillRefs.spdDot, pillRefs.spdDtxt, true, tc[1], "ON")
        flashBtn(uiRefs.spdBtn)
        showNotif("🏃 Speed", "Walk speed → " .. v, tc[1])
    end)
    uiRefs.spdBtn.TouchTap:Connect(function() uiRefs.spdBtn.MouseButton1Click:Fire() end)

    -- Jump input APPLY
    uiRefs.jmpBtn.MouseButton1Click:Connect(function()
        local v = tonumber(uiRefs.jmpBox.Text) if not v then return end
        v = clamp(math.floor(v), 1, 500) uiRefs.jmpBox.Text = tostring(v)
        setJump(v) jumpEnabled = true
        animT(pillRefs.jmpPill, pillRefs.jmpKnob, pillRefs.jmpDot, pillRefs.jmpDtxt, true, tc[1], "ON")
        flashBtn(uiRefs.jmpBtn)
        showNotif("🦅 Jump", "Jump power → " .. v, tc[1])
    end)
    uiRefs.jmpBtn.TouchTap:Connect(function() uiRefs.jmpBtn.MouseButton1Click:Fire() end)

    -- Fly speed APPLY
    uiRefs.flyBtn.MouseButton1Click:Connect(function()
        local v = tonumber(uiRefs.flyBox.Text) if not v then return end
        v = clamp(math.floor(v), 1, 200) uiRefs.flyBox.Text = tostring(v)
        saveData.flySpeed = v writeSave()
        flashBtn(uiRefs.flyBtn)
        showNotif("✈️ Fly Speed", "Fly speed → " .. v, Color3.fromRGB(60, 160, 240))
    end)
    uiRefs.flyBtn.TouchTap:Connect(function() uiRefs.flyBtn.MouseButton1Click:Fire() end)

    -- Fly FOV APPLY
    uiRefs.fovBtn.MouseButton1Click:Connect(function()
        local v = tonumber(uiRefs.fovBox.Text) if not v then return end
        v = clamp(math.floor(v), 40, 120) uiRefs.fovBox.Text = tostring(v)
        saveData.flyFOV = v writeSave()
        if flyOn then TS:Create(CAM, TweenInfo.new(0.4), { FieldOfView = v }):Play() end
        flashBtn(uiRefs.fovBtn)
        showNotif("🔭 Fly FOV", "FOV → " .. v, Color3.fromRGB(60, 160, 240))
    end)
    uiRefs.fovBtn.TouchTap:Connect(function() uiRefs.fovBtn.MouseButton1Click:Fire() end)
end

-- ============================================================
--  INPUT HANDLERS
-- ============================================================
local function buildInputHandlers(MF)
    UIS.InputChanged:Connect(function(inp)
        if isDrag and (inp.UserInputType == Enum.UserInputType.MouseMovement
                    or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dS
            MF.Position = UDim2.new(dF.X.Scale, dF.X.Offset + d.X, dF.Y.Scale, dF.Y.Offset + d.Y)
        end
        if isMini and (inp.UserInputType == Enum.UserInputType.MouseMovement
                    or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - mS
            if d.Magnitude > 6 then mMov = true end
            if uiRefs.MB then
                uiRefs.MB.Position = UDim2.new(mF.X.Scale, mF.X.Offset + d.X, mF.Y.Scale, mF.Y.Offset + d.Y)
            end
        end
    end)

    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            isDrag = false
            if isMini then
                if not mMov then
                    if guiOpen then
                        guiOpen = false
                        TS:Create(MF, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                            Size = UDim2.new(0, 560, 0, 0), BackgroundTransparency = 1 }):Play()
                        task.delay(0.28, function()
                            MF.Visible = false MF.Size = UDim2.new(0, 560, 0, 370) MF.BackgroundTransparency = 0.05
                        end)
                    else
                        guiOpen = true MF.Visible = true
                        MF.Size = UDim2.new(0, 560, 0, 0) MF.BackgroundTransparency = 1
                        TS:Create(MF, TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Size = UDim2.new(0, 560, 0, 370), BackgroundTransparency = 0.05 }):Play()
                    end
                else
                    if uiRefs.MB then
                        saveData.miniPos = { x = uiRefs.MB.Position.X.Scale, y = uiRefs.MB.Position.Y.Scale }
                        writeSave()
                    end
                end
            end
            isMini = false mMov = false
        end
    end)

    UIS.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.KeyCode == Enum.KeyCode.RightShift then
            if guiOpen then
                guiOpen = false
                TS:Create(MF, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                    Size = UDim2.new(0, 560, 0, 0), BackgroundTransparency = 1 }):Play()
                task.delay(0.28, function()
                    MF.Visible = false MF.Size = UDim2.new(0, 560, 0, 370) MF.BackgroundTransparency = 0.05
                end)
            else
                guiOpen = true MF.Visible = true
                MF.Size = UDim2.new(0, 560, 0, 0) MF.BackgroundTransparency = 1
                TS:Create(MF, TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, 560, 0, 370), BackgroundTransparency = 0.05 }):Play()
            end
        end
    end)
end

-- ============================================================
--  MAIN ENTRY
-- ============================================================
local function startMain()
    -- Mini button
    local MB = Instance.new("ImageButton")
    MB.Size = UDim2.new(0, 45, 0, 45)
    MB.AnchorPoint = Vector2.new(0.5, 0.5)
    MB.Position = UDim2.new(saveData.miniPos.x, 0, saveData.miniPos.y, 0)
    MB.BackgroundColor3 = Color3.fromRGB(17, 17, 22) MB.BackgroundTransparency = 0.08
    MB.BorderSizePixel = 0 MB.Image = LOGO_IMG MB.ImageTransparency = 1
    MB.ScaleType = Enum.ScaleType.Fit MB.Visible = false MB.ZIndex = 50 MB.Parent = SG
    mkCorner(MB, 10)
    local MBS = mkStroke(MB, 2.5, Color3.fromRGB(255, 0, 0))
    uiRefs.MB = MB
    local mbHue = 0
    RS.Heartbeat:Connect(function(dt)
        mbHue = (mbHue + dt * 0.55) % 1
        if MBS and MBS.Parent then MBS.Color = Color3.fromHSV(mbHue, 1, 1) end
    end)
    MB.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            isMini = true mMov = false mS = inp.Position mF = MB.Position
        end
    end)

    -- Build all panels
    local MF, tabPages, switchTab = buildMainFrame()
    buildHomeTab(tabPages["Home"])
    buildMovementTab(tabPages["Movement"])
    buildMiscTab(tabPages["Misc"])
    buildFeatureSetters()
    buildInputHandlers(MF)

    switchTab("Home")

    -- Loading screen then show mini button
    buildLoadingScreen(function()
        MB.Visible = true MB.Size = UDim2.new(0, 0, 0, 0) MB.ImageTransparency = 1
        TS:Create(MB, TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 45, 0, 45), ImageTransparency = 0 }):Play()
        task.delay(0.5, function()
            showNotif("👋 Welcome!", getGreeting() .. ", " .. LP.DisplayName .. "! Movement GUI loaded.", Color3.fromRGB(255, 215, 60), 4.5)
        end)
        task.delay(5, function()
            showNotif("⌨️ Keybind", "RightShift = Toggle GUI  ·  Tap mini button to open", Color3.fromRGB(100, 100, 140), 5)
        end)
    end)
end

-- ============================================================
--  BOOTSTRAP
-- ============================================================
if saveData.keyPassed then
    TS:Create(blur, TweenInfo.new(0.5), { Size = 24 }):Play()
    startMain()
else
    buildKeySystem(startMain)
end

-- Cleanup
LP.AncestryChanged:Connect(function()
    pcall(function()
        if flyConn then flyConn:Disconnect() flyConn = nil end
        stopFlyAnims()
        local c = LP.Character
        if c then
            local hum = c:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand = false end
        end
        TS:Create(CAM, TweenInfo.new(0.3), { FieldOfView = origFOV }):Play()
    end)
end)

print("[Client Movement GUI " .. VERSION .. "] Loaded — Client-side only.")