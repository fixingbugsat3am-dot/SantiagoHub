-- ============================================================
--  SantiagoHub | BloxFruitsScripts/GUI.lua
--  Full custom GUI — key system, loading screen, main frame.
--  Called by BloxFruits.lua with: GUI(saveData, F, QD, CODES, ICONS, onToggle)
-- ============================================================

local cloneref   = cloneref or (function(...) return ... end)
local TS         = cloneref(game:GetService("TweenService"))
local UIS        = cloneref(game:GetService("UserInputService"))
local RS         = cloneref(game:GetService("RunService"))
local PL         = cloneref(game:GetService("Players"))
local LP         = PL.LocalPlayer

-- ============================================================
--  CONSTANTS
-- ============================================================
local LOGO_IMG    = "rbxassetid://139094506464240"
local BANNER_IMG  = "rbxassetid://113710199838722"
local CORRECT_KEY = "Santiago"
local DISCORD_URL = "https://discord.gg/Kxxapq6RWZ"
local VERSION     = "v5.0"

local FONT_GOTHAM = Enum.Font.GothamBold
local FONT_COMIC  = Enum.Font.Cartoon

-- ============================================================
--  THEMES
-- ============================================================
local THEMES = {
    { name="Blox Blue",    accent=Color3.fromRGB(30,100,255),  bg=Color3.fromRGB(15,15,30)   },
    { name="Dragon Red",   accent=Color3.fromRGB(220,40,40),   bg=Color3.fromRGB(20,10,10)   },
    { name="Forest Green", accent=Color3.fromRGB(40,180,80),   bg=Color3.fromRGB(10,20,10)   },
    { name="Galaxy Purple",accent=Color3.fromRGB(140,60,220),  bg=Color3.fromRGB(15,10,25)   },
    { name="Gold",         accent=Color3.fromRGB(255,190,30),  bg=Color3.fromRGB(20,18,8)    },
    { name="Ice",          accent=Color3.fromRGB(100,220,255), bg=Color3.fromRGB(10,18,25)   },
    { name="Midnight",     accent=Color3.fromRGB(60,60,90),    bg=Color3.fromRGB(10,10,18)   },
    { name="Sakura",       accent=Color3.fromRGB(255,120,180), bg=Color3.fromRGB(22,10,18)   },
}

-- ============================================================
--  UI HELPERS
-- ============================================================
local function mkCorner(r, p)
    local c = Instance.new("UICorner", p)
    c.CornerRadius = UDim.new(0, r or 8)
    return c
end

local function mkStroke(color, t, p)
    local s = Instance.new("UIStroke", p)
    s.Color = color or Color3.fromRGB(255,255,255)
    s.Thickness = t or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end

local function mkGrad(c0, c1, p)
    local g = Instance.new("UIGradient", p)
    g.Color = ColorSequence.new(c0, c1)
    g.Rotation = 90
    return g
end

local function mkLabel(text, size, font, color, parent)
    local l = Instance.new("TextLabel", parent)
    l.Text = text
    l.TextSize = size or 14
    l.Font = font or FONT_GOTHAM
    l.TextColor3 = color or Color3.fromRGB(255,255,255)
    l.BackgroundTransparency = 1
    l.Size = UDim2.new(1,0,0,size and size+8 or 22)
    l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

local function mkBtn(text, size, parent)
    local b = Instance.new("TextButton", parent)
    b.Text = text
    b.TextSize = size or 13
    b.Font = FONT_GOTHAM
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.AutoButtonColor = false
    b.Size = UDim2.new(1,0,0,36)
    mkCorner(8, b)
    return b
end

local function animBtn(btn, accent)
    btn.MouseEnter:Connect(function()
        TS:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = accent:Lerp(Color3.fromRGB(255,255,255), 0.15)
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TS:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = accent
        }):Play()
    end)
end

-- ============================================================
--  NOTIFICATION SYSTEM
-- ============================================================
local notifHolder
local function setupNotifs(screenGui)
    notifHolder = Instance.new("Frame", screenGui)
    notifHolder.Name = "NotifHolder"
    notifHolder.BackgroundTransparency = 1
    notifHolder.Size = UDim2.new(0,280,1,0)
    notifHolder.Position = UDim2.new(1,-290,0,0)
    notifHolder.AnchorPoint = Vector2.new(0,0)
    local list = Instance.new("UIListLayout", notifHolder)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0,6)
    list.VerticalAlignment = Enum.VerticalAlignment.Bottom
    list.HorizontalAlignment = Enum.HorizontalAlignment.Right
end

local function showNotif(title, body, accent, duration)
    if not notifHolder then return end
    accent   = accent   or Color3.fromRGB(30,100,255)
    duration = duration or 4

    local card = Instance.new("Frame", notifHolder)
    card.BackgroundColor3 = Color3.fromRGB(18,18,28)
    card.Size = UDim2.new(1,0,0,0)
    card.ClipsDescendants = true
    mkCorner(10, card)
    mkStroke(accent, 1.5, card)

    local bar = Instance.new("Frame", card)
    bar.BackgroundColor3 = accent
    bar.Size = UDim2.new(0,4,1,0)
    bar.Position = UDim2.new(0,0,0,0)
    mkCorner(4, bar)

    local inner = Instance.new("Frame", card)
    inner.BackgroundTransparency = 1
    inner.Size = UDim2.new(1,-12,1,0)
    inner.Position = UDim2.new(0,10,0,0)

    local tl = Instance.new("TextLabel", inner)
    tl.Text = title
    tl.Font = FONT_GOTHAM
    tl.TextSize = 13
    tl.TextColor3 = accent
    tl.BackgroundTransparency = 1
    tl.Size = UDim2.new(1,0,0,20)
    tl.Position = UDim2.new(0,0,0,6)
    tl.TextXAlignment = Enum.TextXAlignment.Left

    local bl = Instance.new("TextLabel", inner)
    bl.Text = body
    bl.Font = Enum.Font.Gotham
    bl.TextSize = 11
    bl.TextColor3 = Color3.fromRGB(200,200,200)
    bl.BackgroundTransparency = 1
    bl.Size = UDim2.new(1,0,0,30)
    bl.Position = UDim2.new(0,0,0,26)
    bl.TextXAlignment = Enum.TextXAlignment.Left
    bl.TextWrapped = true

    TS:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.new(1,0,0,62)}):Play()

    task.delay(duration, function()
        TS:Create(card, TweenInfo.new(0.2), {Size = UDim2.new(1,0,0,0)}):Play()
        task.wait(0.22)
        pcall(function() card:Destroy() end)
    end)
end

-- ============================================================
--  KEY SYSTEM
-- ============================================================
local function buildKeySystem(screenGui, accent, bg, onSuccess)
    local overlay = Instance.new("Frame", screenGui)
    overlay.Name = "KeyOverlay"
    overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
    overlay.BackgroundTransparency = 0.3
    overlay.Size = UDim2.new(1,0,1,0)
    overlay.ZIndex = 20

    local card = Instance.new("Frame", overlay)
    card.BackgroundColor3 = bg
    card.Size = UDim2.new(0,380,0,280)
    card.Position = UDim2.new(0.5,-190,0.5,-140)
    card.ZIndex = 21
    mkCorner(14, card)
    mkStroke(accent, 2, card)
    mkGrad(bg, bg:Lerp(Color3.fromRGB(0,0,0),0.4), card)

    -- logo
    local logo = Instance.new("ImageLabel", card)
    logo.Image = LOGO_IMG
    logo.Size = UDim2.new(0,64,0,64)
    logo.Position = UDim2.new(0.5,-32,0,16)
    logo.BackgroundTransparency = 1
    logo.ZIndex = 22
    mkCorner(12, logo)

    -- title
    local title = Instance.new("TextLabel", card)
    title.Text = "SantiagoHub " .. VERSION
    title.Font = FONT_GOTHAM
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1,0,0,24)
    title.Position = UDim2.new(0,0,0,90)
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.ZIndex = 22

    -- subtitle
    local sub = Instance.new("TextLabel", card)
    sub.Text = "Enter your key to continue"
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 12
    sub.TextColor3 = Color3.fromRGB(160,160,180)
    sub.BackgroundTransparency = 1
    sub.Size = UDim2.new(1,0,0,18)
    sub.Position = UDim2.new(0,0,0,116)
    sub.TextXAlignment = Enum.TextXAlignment.Center
    sub.ZIndex = 22

    -- input box
    local inputBg = Instance.new("Frame", card)
    inputBg.BackgroundColor3 = Color3.fromRGB(12,12,22)
    inputBg.Size = UDim2.new(1,-40,0,38)
    inputBg.Position = UDim2.new(0,20,0,148)
    inputBg.ZIndex = 22
    mkCorner(8, inputBg)
    mkStroke(accent, 1, inputBg)

    local input = Instance.new("TextBox", inputBg)
    input.PlaceholderText = "Key here..."
    input.PlaceholderColor3 = Color3.fromRGB(100,100,120)
    input.Text = ""
    input.Font = FONT_GOTHAM
    input.TextSize = 13
    input.TextColor3 = Color3.fromRGB(255,255,255)
    input.BackgroundTransparency = 1
    input.Size = UDim2.new(1,-16,1,0)
    input.Position = UDim2.new(0,8,0,0)
    input.ZIndex = 23
    input.ClearTextOnFocus = false

    -- status label
    local status = Instance.new("TextLabel", card)
    status.Text = ""
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.TextColor3 = Color3.fromRGB(255,80,80)
    status.BackgroundTransparency = 1
    status.Size = UDim2.new(1,0,0,16)
    status.Position = UDim2.new(0,0,0,192)
    status.TextXAlignment = Enum.TextXAlignment.Center
    status.ZIndex = 22

    -- submit btn
    local btn = Instance.new("TextButton", card)
    btn.Text = "▶  Unlock Hub"
    btn.Font = FONT_GOTHAM
    btn.TextSize = 13
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.BackgroundColor3 = accent
    btn.AutoButtonColor = false
    btn.Size = UDim2.new(1,-40,0,36)
    btn.Position = UDim2.new(0,20,0,212)
    btn.ZIndex = 22
    mkCorner(10, btn)
    animBtn(btn, accent)

    -- discord hint
    local disc = Instance.new("TextLabel", card)
    disc.Text = "Key: Santiago  |  Discord: discord.gg/Kxxapq6RWZ"
    disc.Font = Enum.Font.Gotham
    disc.TextSize = 10
    disc.TextColor3 = Color3.fromRGB(100,100,130)
    disc.BackgroundTransparency = 1
    disc.Size = UDim2.new(1,0,0,14)
    disc.Position = UDim2.new(0,0,1,-16)
    disc.TextXAlignment = Enum.TextXAlignment.Center
    disc.ZIndex = 22

    local function tryKey()
        local entered = input.Text:gsub("%s","")
        if entered == CORRECT_KEY then
            status.Text = "✔ Correct!"
            status.TextColor3 = Color3.fromRGB(40,220,80)
            TS:Create(overlay, TweenInfo.new(0.4), {BackgroundTransparency=1}):Play()
            TS:Create(card, TweenInfo.new(0.4), {
                Size=UDim2.new(0,380,0,0),
                Position=UDim2.new(0.5,-190,0.5,0)
            }):Play()
            task.wait(0.45)
            overlay:Destroy()
            onSuccess()
        else
            status.Text = "✘ Wrong key!"
            status.TextColor3 = Color3.fromRGB(255,60,60)
            TS:Create(card, TweenInfo.new(0.05), {Position=UDim2.new(0.5,-190+6,0.5,-140)}):Play()
            task.wait(0.05)
            TS:Create(card, TweenInfo.new(0.05), {Position=UDim2.new(0.5,-190-6,0.5,-140)}):Play()
            task.wait(0.05)
            TS:Create(card, TweenInfo.new(0.05), {Position=UDim2.new(0.5,-190,0.5,-140)}):Play()
        end
    end

    btn.MouseButton1Click:Connect(tryKey)
    input.FocusLost:Connect(function(enter)
        if enter then tryKey() end
    end)
end

-- ============================================================
--  LOADING SCREEN
-- ============================================================
local function buildLoadingScreen(screenGui, accent, bg, onDone)
    local overlay = Instance.new("Frame", screenGui)
    overlay.Name = "Loader"
    overlay.BackgroundColor3 = bg
    overlay.Size = UDim2.new(1,0,1,0)
    overlay.ZIndex = 15

    local banner = Instance.new("ImageLabel", overlay)
    banner.Image = BANNER_IMG
    banner.Size = UDim2.new(0,400,0,120)
    banner.Position = UDim2.new(0.5,-200,0.3,-60)
    banner.BackgroundTransparency = 1
    banner.ZIndex = 16
    mkCorner(12, banner)

    local bar_bg = Instance.new("Frame", overlay)
    bar_bg.BackgroundColor3 = Color3.fromRGB(30,30,50)
    bar_bg.Size = UDim2.new(0,380,0,8)
    bar_bg.Position = UDim2.new(0.5,-190,0.6,0)
    bar_bg.ZIndex = 16
    mkCorner(4, bar_bg)

    local bar = Instance.new("Frame", bar_bg)
    bar.BackgroundColor3 = accent
    bar.Size = UDim2.new(0,0,1,0)
    bar.ZIndex = 17
    mkCorner(4, bar)
    mkGrad(accent, accent:Lerp(Color3.fromRGB(255,255,255),0.3), bar)

    local lbl = Instance.new("TextLabel", overlay)
    lbl.Text = "Loading SantiagoHub..."
    lbl.Font = FONT_GOTHAM
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.fromRGB(180,180,200)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0,380,0,20)
    lbl.Position = UDim2.new(0.5,-190,0.6,16)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 16

    local steps = {
        "Initializing services...",
        "Loading quest data...",
        "Loading promo codes...",
        "Connecting to backend...",
        "Setting up GUI...",
        "Configuring auto-farm...",
        "Loading fruit data...",
        "Applying theme...",
        "Done! Welcome back.",
    }

    task.spawn(function()
        for i, step in ipairs(steps) do
            lbl.Text = step
            TS:Create(bar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(i/#steps, 0, 1, 0)
            }):Play()
            task.wait(0.45)
        end
        task.wait(0.3)
        TS:Create(overlay, TweenInfo.new(0.5), {BackgroundTransparency=1}):Play()
        task.wait(0.55)
        overlay:Destroy()
        onDone()
    end)
end

-- ============================================================
--  PILL (toggle button)
-- ============================================================
local function mkPill(label, state, accent, bg, parent, onChange)
    local row = Instance.new("Frame", parent)
    row.BackgroundColor3 = bg:Lerp(Color3.fromRGB(255,255,255), 0.04)
    row.Size = UDim2.new(1,0,0,40)
    mkCorner(8, row)

    local txt = Instance.new("TextLabel", row)
    txt.Text = label
    txt.Font = FONT_GOTHAM
    txt.TextSize = 12
    txt.TextColor3 = Color3.fromRGB(220,220,240)
    txt.BackgroundTransparency = 1
    txt.Size = UDim2.new(1,-64,1,0)
    txt.Position = UDim2.new(0,12,0,0)
    txt.TextXAlignment = Enum.TextXAlignment.Left

    local pillBg = Instance.new("Frame", row)
    pillBg.Size = UDim2.new(0,46,0,24)
    pillBg.Position = UDim2.new(1,-54,0.5,-12)
    pillBg.BackgroundColor3 = state and accent or Color3.fromRGB(50,50,70)
    mkCorner(12, pillBg)

    local knob = Instance.new("Frame", pillBg)
    knob.Size = UDim2.new(0,20,0,20)
    knob.Position = state and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    mkCorner(10, knob)

    local cur = state
    local btn = Instance.new("TextButton", row)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Size = UDim2.new(1,0,1,0)

    btn.MouseButton1Click:Connect(function()
        cur = not cur
        TS:Create(pillBg, TweenInfo.new(0.18), {
            BackgroundColor3 = cur and accent or Color3.fromRGB(50,50,70)
        }):Play()
        TS:Create(knob, TweenInfo.new(0.18), {
            Position = cur and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)
        }):Play()
        if onChange then onChange(cur) end
    end)

    return row, function() return cur end
end

-- ============================================================
--  SLIDER
-- ============================================================
local function mkSlider(label, min, max, default, accent, bg, parent, onChange)
    local row = Instance.new("Frame", parent)
    row.BackgroundColor3 = bg:Lerp(Color3.fromRGB(255,255,255), 0.04)
    row.Size = UDim2.new(1,0,0,52)
    mkCorner(8, row)

    local lbl2 = Instance.new("TextLabel", row)
    lbl2.Text = label .. ": " .. tostring(default)
    lbl2.Font = FONT_GOTHAM
    lbl2.TextSize = 12
    lbl2.TextColor3 = Color3.fromRGB(220,220,240)
    lbl2.BackgroundTransparency = 1
    lbl2.Size = UDim2.new(1,-12,0,22)
    lbl2.Position = UDim2.new(0,12,0,4)
    lbl2.TextXAlignment = Enum.TextXAlignment.Left

    local trackBg = Instance.new("Frame", row)
    trackBg.BackgroundColor3 = Color3.fromRGB(30,30,50)
    trackBg.Size = UDim2.new(1,-24,0,8)
    trackBg.Position = UDim2.new(0,12,0,30)
    mkCorner(4, trackBg)

    local fill = Instance.new("Frame", trackBg)
    local pct = (default - min) / (max - min)
    fill.BackgroundColor3 = accent
    fill.Size = UDim2.new(pct, 0, 1, 0)
    mkCorner(4, fill)

    local dragging = false
    local sliderBtn = Instance.new("TextButton", trackBg)
    sliderBtn.BackgroundTransparency = 1
    sliderBtn.Text = ""
    sliderBtn.Size = UDim2.new(1,0,1,0)

    local function updateFromMouse(x)
        local abs = trackBg.AbsolutePosition.X
        local w   = trackBg.AbsoluteSize.X
        local p2  = math.clamp((x - abs) / w, 0, 1)
        local val = math.floor(min + p2 * (max - min))
        fill.Size = UDim2.new(p2, 0, 1, 0)
        lbl2.Text = label .. ": " .. tostring(val)
        if onChange then onChange(val) end
    end

    sliderBtn.MouseButton1Down:Connect(function()
        dragging = true
        updateFromMouse(UIS:GetMouseLocation().X)
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            updateFromMouse(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    return row
end

-- ============================================================
--  SCROLLING FRAME HELPER
-- ============================================================
local function mkScroll(parent, size, pos)
    local s = Instance.new("ScrollingFrame", parent)
    s.BackgroundTransparency = 1
    s.Size = size or UDim2.new(1,0,1,-40)
    s.Position = pos or UDim2.new(0,0,0,40)
    s.ScrollBarThickness = 4
    s.ScrollBarImageColor3 = Color3.fromRGB(80,80,120)
    s.CanvasSize = UDim2.new(0,0,0,0)
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    local list = Instance.new("UIListLayout", s)
    list.Padding = UDim.new(0,6)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", s)
    pad.PaddingLeft   = UDim.new(0,6)
    pad.PaddingRight  = UDim.new(0,6)
    pad.PaddingTop    = UDim.new(0,6)
    pad.PaddingBottom = UDim.new(0,6)
    return s
end

-- ============================================================
--  SECTION HEADER
-- ============================================================
local function mkSection(text, accent, parent)
    local f = Instance.new("Frame", parent)
    f.BackgroundTransparency = 1
    f.Size = UDim2.new(1,0,0,24)

    local line1 = Instance.new("Frame", f)
    line1.BackgroundColor3 = accent
    line1.Size = UDim2.new(0,3,0,18)
    line1.Position = UDim2.new(0,0,0.5,-9)
    mkCorner(2, line1)

    local lbl2 = Instance.new("TextLabel", f)
    lbl2.Text = text
    lbl2.Font = FONT_GOTHAM
    lbl2.TextSize = 12
    lbl2.TextColor3 = accent
    lbl2.BackgroundTransparency = 1
    lbl2.Size = UDim2.new(1,-10,1,0)
    lbl2.Position = UDim2.new(0,8,0,0)
    lbl2.TextXAlignment = Enum.TextXAlignment.Left
    return f
end

-- ============================================================
--  MAIN GUI BUILDER
--  params: saveData, F (Functions), QD (QuestData), CODES, onToggle
-- ============================================================
return function(saveData, F, QD, CODES, ICONS, onToggle)
    local curTheme = THEMES[1]

    -- icon helper: get rbxassetid string by name
    local function getIcon(name)
        if not name then return "" end
        local id = ICONS and ICONS[name:lower()]
        return id and ("rbxassetid://" .. tostring(id)) or ""
    end

    -- destroy old gui
    local old = LP.PlayerGui:FindFirstChild("SantiagoHub")
    if old then old:Destroy() end

    local SG = Instance.new("ScreenGui", LP.PlayerGui)
    SG.Name = "SantiagoHub"
    SG.ResetOnSpawn = false
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    setupNotifs(SG)

    -- blur
    local blur = Instance.new("BlurEffect", game:GetService("Lighting"))
    blur.Size = 0
    blur.Name = "SantiagoBlur"

    -- =====================
    --  MAIN FRAME
    -- =====================
    local function buildMain()
        TS:Create(blur, TweenInfo.new(0.5), {Size=0}):Play()

        local accent = curTheme.accent
        local bg     = curTheme.bg

        local mf = Instance.new("Frame", SG)
        mf.Name = "MainFrame"
        mf.BackgroundColor3 = bg
        mf.Size = UDim2.new(0,600,0,420)
        mf.Position = UDim2.new(0.5,-300,0.5,-210)
        mf.ClipsDescendants = true
        mkCorner(14, mf)
        mkStroke(accent, 2, mf)
        mkGrad(bg, bg:Lerp(Color3.fromRGB(0,0,0),0.5), mf)

        -- drag
        do
            local drag, dragStart, frameStart = false
            mf.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    drag = true
                    dragStart = i.Position
                    frameStart = mf.Position
                end
            end)
            mf.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
            end)
            UIS.InputChanged:Connect(function(i)
                if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
                    local delta = i.Position - dragStart
                    mf.Position = UDim2.new(
                        frameStart.X.Scale, frameStart.X.Offset + delta.X,
                        frameStart.Y.Scale, frameStart.Y.Offset + delta.Y
                    )
                end
            end)
        end

        -- top bar
        local topBar = Instance.new("Frame", mf)
        topBar.BackgroundColor3 = bg:Lerp(Color3.fromRGB(0,0,0), 0.5)
        topBar.Size = UDim2.new(1,0,0,44)

        local logoImg = Instance.new("ImageLabel", topBar)
        logoImg.Image = LOGO_IMG
        logoImg.Size = UDim2.new(0,32,0,32)
        logoImg.Position = UDim2.new(0,8,0.5,-16)
        logoImg.BackgroundTransparency = 1
        mkCorner(8, logoImg)

        local hubTitle = Instance.new("TextLabel", topBar)
        hubTitle.Text = "SantiagoHub " .. VERSION
        hubTitle.Font = FONT_GOTHAM
        hubTitle.TextSize = 15
        hubTitle.TextColor3 = Color3.fromRGB(255,255,255)
        hubTitle.BackgroundTransparency = 1
        hubTitle.Size = UDim2.new(0,200,1,0)
        hubTitle.Position = UDim2.new(0,48,0,0)
        hubTitle.TextXAlignment = Enum.TextXAlignment.Left

        -- close button
        local closeBtn = Instance.new("TextButton", topBar)
        closeBtn.Text = "✕"
        closeBtn.Font = FONT_GOTHAM
        closeBtn.TextSize = 14
        closeBtn.TextColor3 = Color3.fromRGB(255,80,80)
        closeBtn.BackgroundTransparency = 1
        closeBtn.Size = UDim2.new(0,36,1,0)
        closeBtn.Position = UDim2.new(1,-36,0,0)
        closeBtn.MouseButton1Click:Connect(function()
            TS:Create(mf, TweenInfo.new(0.3), {Size=UDim2.new(0,600,0,0)}):Play()
            task.wait(0.35)
            mf:Destroy()
            -- mini icon
            local mini = Instance.new("ImageButton", SG)
            mini.Image = LOGO_IMG
            mini.Size = UDim2.new(0,44,0,44)
            mini.Position = UDim2.new(0,10,0.5,-22)
            mini.BackgroundColor3 = bg
            mkCorner(10, mini)
            mkStroke(accent, 1.5, mini)
            mini.MouseButton1Click:Connect(function()
                mini:Destroy()
                buildMain()
            end)
        end)

        -- minimize
        local minBtn = Instance.new("TextButton", topBar)
        minBtn.Text = "—"
        minBtn.Font = FONT_GOTHAM
        minBtn.TextSize = 14
        minBtn.TextColor3 = Color3.fromRGB(200,200,200)
        minBtn.BackgroundTransparency = 1
        minBtn.Size = UDim2.new(0,36,1,0)
        minBtn.Position = UDim2.new(1,-72,0,0)
        local minimized = false
        minBtn.MouseButton1Click:Connect(function()
            minimized = not minimized
            TS:Create(mf, TweenInfo.new(0.25), {
                Size = minimized and UDim2.new(0,600,0,44) or UDim2.new(0,600,0,420)
            }):Play()
        end)

        -- =====================
        --  TAB BAR
        -- =====================
        local tabBar = Instance.new("Frame", mf)
        tabBar.BackgroundColor3 = bg:Lerp(Color3.fromRGB(0,0,0),0.3)
        tabBar.Size = UDim2.new(0,110,1,-44)
        tabBar.Position = UDim2.new(0,0,0,44)

        local tabList = Instance.new("UIListLayout", tabBar)
        tabList.SortOrder = Enum.SortOrder.LayoutOrder
        tabList.Padding = UDim.new(0,4)
        local tabPad = Instance.new("UIPadding", tabBar)
        tabPad.PaddingTop = UDim.new(0,8)
        tabPad.PaddingLeft = UDim.new(0,6)
        tabPad.PaddingRight = UDim.new(0,6)

        -- content area
        local content = Instance.new("Frame", mf)
        content.BackgroundTransparency = 1
        content.Size = UDim2.new(1,-118,1,-44)
        content.Position = UDim2.new(0,116,0,44)

        local tabs = {}
        local activeTab = nil

        local tabDefs = {
            { name="Home",     key="home",     icon="home"     },
            { name="Farm",     key="farm",     icon="sprout"   },
            { name="Combat",   key="combat",   icon="sword"    },
            { name="Fruit",    key="fruit",    icon="apple"    },
            { name="Settings", key="settings", icon="settings" },
        }

        local function switchTab(key)
            for k, t in pairs(tabs) do
                t.btn.BackgroundColor3 = k == key
                    and accent
                    or  bg:Lerp(Color3.fromRGB(255,255,255),0.04)
                t.panel.Visible = (k == key)
            end
            activeTab = key
        end

        for _, def in ipairs(tabDefs) do
            local btn = Instance.new("TextButton", tabBar)
            btn.Text = def.name
            btn.Font = FONT_GOTHAM
            btn.TextSize = 11
            btn.TextColor3 = Color3.fromRGB(220,220,240)
            btn.BackgroundColor3 = bg:Lerp(Color3.fromRGB(255,255,255),0.04)
            btn.AutoButtonColor = false
            btn.Size = UDim2.new(1,0,0,36)
            btn.TextXAlignment = Enum.TextXAlignment.Left
            mkCorner(8, btn)

            local leftBar = Instance.new("Frame", btn)
            leftBar.BackgroundColor3 = accent
            leftBar.Size = UDim2.new(0,3,0.6,0)
            leftBar.Position = UDim2.new(0,4,0.2,0)
            mkCorner(2, leftBar)

            -- icon image on tab button
            local iconImg = Instance.new("ImageLabel", btn)
            iconImg.Image = getIcon(def.icon)
            iconImg.Size = UDim2.new(0,16,0,16)
            iconImg.Position = UDim2.new(0,16,0.5,-8)
            iconImg.BackgroundTransparency = 1
            iconImg.ImageColor3 = Color3.fromRGB(200,200,220)

            btn.Text = ""
            local btnLbl = Instance.new("TextLabel", btn)
            btnLbl.Text = def.name
            btnLbl.Font = FONT_GOTHAM
            btnLbl.TextSize = 11
            btnLbl.TextColor3 = Color3.fromRGB(220,220,240)
            btnLbl.BackgroundTransparency = 1
            btnLbl.Size = UDim2.new(1,-40,1,0)
            btnLbl.Position = UDim2.new(0,36,0,0)
            btnLbl.TextXAlignment = Enum.TextXAlignment.Left

            local panel = Instance.new("ScrollingFrame", content)
            panel.BackgroundTransparency = 1
            panel.Size = UDim2.new(1,0,1,0)
            panel.ScrollBarThickness = 4
            panel.ScrollBarImageColor3 = Color3.fromRGB(80,80,120)
            panel.CanvasSize = UDim2.new(0,0,0,0)
            panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
            panel.Visible = false
            local pl = Instance.new("UIListLayout", panel)
            pl.Padding = UDim.new(0,6)
            pl.SortOrder = Enum.SortOrder.LayoutOrder
            local pp = Instance.new("UIPadding", panel)
            pp.PaddingLeft   = UDim.new(0,8)
            pp.PaddingRight  = UDim.new(0,8)
            pp.PaddingTop    = UDim.new(0,8)
            pp.PaddingBottom = UDim.new(0,8)

            tabs[def.key] = { btn=btn, panel=panel }
            btn.MouseButton1Click:Connect(function() switchTab(def.key) end)
        end

        -- =====================
        --  HOME TAB
        -- =====================
        do
            local p = tabs["home"].panel

            -- stats cards
            local statDefs = {
                { key="level", label="Level",    icon="⭐" },
                { key="ping",  label="Ping",     icon="📶" },
                { key="sea",   label="Sea",      icon="🌊" },
                { key="beli",  label="Beli",     icon="💰" },
            }
            local statLabels = {}

            local statsRow = Instance.new("Frame", p)
            statsRow.BackgroundTransparency = 1
            statsRow.Size = UDim2.new(1,0,0,70)
            local srl = Instance.new("UIListLayout", statsRow)
            srl.FillDirection = Enum.FillDirection.Horizontal
            srl.Padding = UDim.new(0,6)

            for _, sd in ipairs(statDefs) do
                local card = Instance.new("Frame", statsRow)
                card.BackgroundColor3 = bg:Lerp(Color3.fromRGB(255,255,255),0.05)
                card.Size = UDim2.new(0.25,-5,1,0)
                mkCorner(10, card)
                mkStroke(accent, 1, card)

                local ic = Instance.new("TextLabel", card)
                ic.Text = sd.icon
                ic.Font = FONT_GOTHAM
                ic.TextSize = 18
                ic.BackgroundTransparency = 1
                ic.Size = UDim2.new(1,0,0,26)
                ic.Position = UDim2.new(0,0,0,6)
                ic.TextXAlignment = Enum.TextXAlignment.Center

                local vl = Instance.new("TextLabel", card)
                vl.Text = "..."
                vl.Font = FONT_GOTHAM
                vl.TextSize = 13
                vl.TextColor3 = Color3.fromRGB(255,255,255)
                vl.BackgroundTransparency = 1
                vl.Size = UDim2.new(1,0,0,16)
                vl.Position = UDim2.new(0,0,0,32)
                vl.TextXAlignment = Enum.TextXAlignment.Center

                local lb = Instance.new("TextLabel", card)
                lb.Text = sd.label
                lb.Font = Enum.Font.Gotham
                lb.TextSize = 9
                lb.TextColor3 = Color3.fromRGB(140,140,170)
                lb.BackgroundTransparency = 1
                lb.Size = UDim2.new(1,0,0,14)
                lb.Position = UDim2.new(0,0,0,48)
                lb.TextXAlignment = Enum.TextXAlignment.Center

                statLabels[sd.key] = vl
            end

            -- uptime
            local upStart = tick()
            local uptimeLbl = Instance.new("TextLabel", p)
            uptimeLbl.Text = "Uptime: 0s"
            uptimeLbl.Font = Enum.Font.Gotham
            uptimeLbl.TextSize = 11
            uptimeLbl.TextColor3 = Color3.fromRGB(140,140,170)
            uptimeLbl.BackgroundTransparency = 1
            uptimeLbl.Size = UDim2.new(1,0,0,18)
            uptimeLbl.TextXAlignment = Enum.TextXAlignment.Center

            -- discord btn
            local discBtn = mkBtn("📋  Copy Discord", 13, p)
            discBtn.BackgroundColor3 = accent
            animBtn(discBtn, accent)
            discBtn.MouseButton1Click:Connect(function()
                pcall(function() setclipboard(DISCORD_URL) end)
                showNotif("Discord", "Link copied to clipboard!", accent, 3)
            end)

            -- live updater
            RS.Heartbeat:Connect(function()
                if not statLabels.level then return end
                pcall(function()
                    statLabels.level.Text = tostring(F.getLevel())
                    statLabels.ping.Text  = tostring(F.getPing()) .. "ms"
                    statLabels.sea.Text   = "Sea " .. tostring(F.getSea())
                    statLabels.beli.Text  = tostring(F.getBeli())
                    local u = tick() - upStart
                    local m = math.floor(u/60)
                    local s = math.floor(u%60)
                    uptimeLbl.Text = ("Uptime: %dm %ds"):format(m,s)
                end)
            end)
        end

        -- =====================
        --  FARM TAB
        -- =====================
        do
            local p = tabs["farm"].panel
            mkSection("🌾  Auto Farm", accent, p)
            mkPill("Auto Farm",    saveData.AutoFarm,    accent, bg, p, function(v) saveData.AutoFarm=v; onToggle("AutoFarm",v) end)
            mkPill("Auto Quest",   saveData.AutoQuest,   accent, bg, p, function(v) saveData.AutoQuest=v; onToggle("AutoQuest",v) end)
            mkPill("Auto Raid",    saveData.AutoRaid,    accent, bg, p, function(v) saveData.AutoRaid=v; onToggle("AutoRaid",v) end)
            mkPill("Auto Boss",    saveData.AutoBoss,    accent, bg, p, function(v) saveData.AutoBoss=v; onToggle("AutoBoss",v) end)
            mkPill("Auto Mastery", saveData.AutoMastery, accent, bg, p, function(v) saveData.AutoMastery=v; onToggle("AutoMastery",v) end)
            mkPill("Auto Chest",   saveData.AutoChest,   accent, bg, p, function(v) saveData.AutoChest=v; onToggle("AutoChest",v) end)
            mkPill("Auto Berry",   saveData.AutoBerry,   accent, bg, p, function(v) saveData.AutoBerry=v; onToggle("AutoBerry",v) end)

            mkSection("🌐  Server", accent, p)
            local hopBtn = mkBtn("🌐  Server Hop", 13, p)
            hopBtn.BackgroundColor3 = accent
            animBtn(hopBtn, accent)
            hopBtn.MouseButton1Click:Connect(function()
                showNotif("Server Hop", "Finding a new server...", accent, 3)
                task.delay(1, F.serverHop)
            end)
        end

        -- =====================
        --  COMBAT TAB
        -- =====================
        do
            local p = tabs["combat"].panel
            mkSection("⚔  Combat Features", accent, p)
            mkPill("Fast Attack",  saveData.FastAttack,  accent, bg, p, function(v) saveData.FastAttack=v; onToggle("FastAttack",v) end)
            mkPill("Silent Aim",   saveData.SilentAim,   accent, bg, p, function(v) saveData.SilentAim=v; onToggle("SilentAim",v) end)
            mkPill("Auto Skills",  saveData.AutoSkills,  accent, bg, p, function(v) saveData.AutoSkills=v; onToggle("AutoSkills",v) end)
            mkSection("🏃  Movement", accent, p)
            mkPill("Speed Boost",  saveData.SpeedBoost,  accent, bg, p, function(v) saveData.SpeedBoost=v; onToggle("SpeedBoost",v) end)
            mkPill("No Clip",      saveData.NoClip,      accent, bg, p, function(v) saveData.NoClip=v; onToggle("NoClip",v) end)
            mkSection("💪  Haki", accent, p)
            mkPill("Buso Haki",    saveData.BusoHaki,    accent, bg, p, function(v) saveData.BusoHaki=v; onToggle("BusoHaki",v) end)
            mkPill("Ken Haki",     saveData.KenHaki,     accent, bg, p, function(v) saveData.KenHaki=v; onToggle("KenHaki",v) end)
            mkSection("🛡  Defense", accent, p)
            mkPill("Anti AFK",     saveData.AntiAfk,     accent, bg, p, function(v) saveData.AntiAfk=v; onToggle("AntiAfk",v) end)
        end

        -- =====================
        --  FRUIT TAB
        -- =====================
        do
            local p = tabs["fruit"].panel
            mkSection("🍎  Devil Fruits", accent, p)
            mkPill("Fruit Sniper",    saveData.FruitSniper, accent, bg, p, function(v) saveData.FruitSniper=v; onToggle("FruitSniper",v) end)
            mkPill("Auto Eat Fruit",  saveData.AutoEat,     accent, bg, p, function(v) saveData.AutoEat=v; onToggle("AutoEat",v) end)
            mkPill("Save Fruit",      saveData.SaveFruit,   accent, bg, p, function(v) saveData.SaveFruit=v; onToggle("SaveFruit",v) end)
            mkPill("Devil Fruit Hop", saveData.FruitHop,    accent, bg, p, function(v) saveData.FruitHop=v; onToggle("FruitHop",v) end)

            -- target fruit input
            local targetRow = Instance.new("Frame", p)
            targetRow.BackgroundColor3 = bg:Lerp(Color3.fromRGB(255,255,255),0.04)
            targetRow.Size = UDim2.new(1,0,0,44)
            mkCorner(8, targetRow)

            local targetLbl = Instance.new("TextLabel", targetRow)
            targetLbl.Text = "Target Fruit:"
            targetLbl.Font = FONT_GOTHAM
            targetLbl.TextSize = 11
            targetLbl.TextColor3 = Color3.fromRGB(180,180,200)
            targetLbl.BackgroundTransparency = 1
            targetLbl.Size = UDim2.new(0,90,1,0)
            targetLbl.Position = UDim2.new(0,10,0,0)
            targetLbl.TextXAlignment = Enum.TextXAlignment.Left

            local targetInput = Instance.new("TextBox", targetRow)
            targetInput.PlaceholderText = "e.g. Dragon..."
            targetInput.PlaceholderColor3 = Color3.fromRGB(100,100,120)
            targetInput.Text = saveData.TargetFruit or ""
            targetInput.Font = Enum.Font.Gotham
            targetInput.TextSize = 12
            targetInput.TextColor3 = Color3.fromRGB(255,255,255)
            targetInput.BackgroundColor3 = Color3.fromRGB(12,12,22)
            targetInput.Size = UDim2.new(1,-110,0,28)
            targetInput.Position = UDim2.new(0,100,0.5,-14)
            targetInput.ClearTextOnFocus = false
            mkCorner(6, targetInput)
            mkStroke(accent, 1, targetInput)

            targetInput.FocusLost:Connect(function()
                saveData.TargetFruit = targetInput.Text
            end)

            mkSection("🎁  Codes", accent, p)
            local redeemBtn = mkBtn("🎁  Redeem All " .. #CODES .. " Codes", 13, p)
            redeemBtn.BackgroundColor3 = Color3.fromRGB(38,155,85)
            animBtn(redeemBtn, Color3.fromRGB(38,155,85))
            local redeeming = false
            redeemBtn.MouseButton1Click:Connect(function()
                if redeeming then return end
                redeeming = true
                redeemBtn.Text = "⏳ Redeeming..."
                local done = 0
                F.redeemAllCodes(CODES, function(code, ok)
                    done = done + 1
                    redeemBtn.Text = ("⏳ %d / %d"):format(done, #CODES)
                    if ok then
                        showNotif("✅ Code Redeemed", code, Color3.fromRGB(38,200,80), 2)
                    end
                end)
                task.delay(#CODES * 0.85, function()
                    redeemBtn.Text = "✔ All codes redeemed!"
                    task.wait(3)
                    redeemBtn.Text = "🎁  Redeem All " .. #CODES .. " Codes"
                    redeeming = false
                end)
            end)
        end

        -- =====================
        --  SETTINGS TAB
        -- =====================
        do
            local p = tabs["settings"].panel
            mkSection("⚙  General", accent, p)
            mkPill("Auto Save",      saveData.AutoSave,   accent, bg, p, function(v) saveData.AutoSave=v end)
            mkPill("Notifications",  saveData.Notifs,     accent, bg, p, function(v) saveData.Notifs=v end)
            mkPill("Fullbright",     saveData.Fullbright, accent, bg, p, function(v) saveData.Fullbright=v; F.setFullbright(v) end)
            mkPill("Vis Check",      saveData.VisCheck,   accent, bg, p, function(v) saveData.VisCheck=v end)

            mkSection("🎨  Theme", accent, p)
            for i, th in ipairs(THEMES) do
                local tBtn = mkBtn("  " .. th.name, 12, p)
                tBtn.BackgroundColor3 = th.accent
                animBtn(tBtn, th.accent)
                tBtn.MouseButton1Click:Connect(function()
                    curTheme = th
                    showNotif("Theme", th.name .. " applied!", th.accent, 3)
                    -- rebuild GUI with new theme
                    task.delay(0.5, function()
                        mf:Destroy()
                        buildMain()
                    end)
                end)
            end

            mkSection("ℹ  Info", accent, p)
            local creditLbl = Instance.new("TextLabel", p)
            creditLbl.Text = "SantiagoHub " .. VERSION .. " • Key: Santiago\nDiscord: discord.gg/Kxxapq6RWZ"
            creditLbl.Font = Enum.Font.Gotham
            creditLbl.TextSize = 10
            creditLbl.TextColor3 = Color3.fromRGB(120,120,150)
            creditLbl.BackgroundTransparency = 1
            creditLbl.Size = UDim2.new(1,0,0,32)
            creditLbl.TextWrapped = true
            creditLbl.TextXAlignment = Enum.TextXAlignment.Center
        end

        -- show first tab
        switchTab("home")

        -- RightShift to toggle
        UIS.InputBegan:Connect(function(i, gpe)
            if gpe then return end
            if i.KeyCode == Enum.KeyCode.RightShift then
                mf.Visible = not mf.Visible
            end
        end)

        -- welcome notif
        task.delay(1, function()
            showNotif("Welcome!", "SantiagoHub loaded. RightShift to hide.", accent, 5)
        end)
        task.delay(7, function()
            showNotif("🎁 Codes", "Go to Fruit tab to redeem " .. #CODES .. " promo codes!", accent, 5)
        end)
    end

    -- =====================
    --  BOOT SEQUENCE
    -- =====================
    TS:Create(blur, TweenInfo.new(0.4), {Size=20}):Play()

    local accent = curTheme.accent
    local bg     = curTheme.bg

    if saveData.keyPassed then
        buildLoadingScreen(SG, accent, bg, buildMain)
    else
        buildKeySystem(SG, accent, bg, function()
            saveData.keyPassed = true
            buildLoadingScreen(SG, accent, bg, buildMain)
        end)
    end

    -- cleanup blur on leave
    LP.AncestryChanged:Connect(function()
        pcall(function() blur.Size = 0 end)
    end)

    return {
        showNotif = showNotif,
    }
end