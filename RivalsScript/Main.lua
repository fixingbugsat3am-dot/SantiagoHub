-- ============================================================
--  Rivals AimBot v5.0 ULTRA | StarterPlayerScripts > LocalScript
--  Fix: split into sub-functions so no single scope exceeds
--       Luau's 200 local register limit.
--  Font fix: Font.new("rbxassetid://12187365364") = Comic Neue Angular
--  Client-side only. Zero server RemoteEvent calls.
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
--  API BAN BYPASS
-- ============================================================
pcall(function() setidentity(8) end)
pcall(function()
    local genv = getgenv and getgenv() or {}
    genv.printidentity    = function() return 1 end
    genv.identifyexecutor = function() return "RobloxStudio", "1.0" end
end)

-- ============================================================
--  CONSTANTS
-- ============================================================
local LOGO_IMG    = "rbxassetid://139094506464240"
local BANNER_IMG  = "rbxassetid://113710199838722"
local CORRECT_KEY = "Santiago"
local DISCORD_URL = "https://discord.gg/Kxxapq6RWZ"
local SAVE_FILE   = "rivals_ab_v5.json"
local VERSION     = "v5.0 ULTRA"

-- ============================================================
--  FONT HELPERS  (FIXED — Comic Neue Angular via correct ID)
-- ============================================================
local function safeFont(id, weight, style)
    local ok, f = pcall(function()
        return Font.new("rbxassetid://" .. id,
            weight or Enum.FontWeight.Bold,
            style  or Enum.FontStyle.Normal)
    end)
    return (ok and f) or Font.fromEnum(Enum.Font.GothamBlack)
end

local FONT_COMIC  = safeFont("12187365364", Enum.FontWeight.Bold,   Enum.FontStyle.Normal)
local FONT_GOTHAM = Font.fromEnum(Enum.Font.GothamBlack)

-- ============================================================
--  SAVE DATA
-- ============================================================
local saveData = {
    keyPassed=false, autoSave=true, theme="Red",
    fov=75, hbs=10, aimSmooth=18, predStrength=0.35, triggerDelay=0.08,
    crosshair=true, notifications=true,
    espNames=true, espHealth=true, espBoxes=false, tracers=false,
    wallCheck=false, teamCheck=false, visCheck=false,
    aimBone="UpperTorso", tracerOrigin="Bottom",
    radarEnabled=false, radarRange=150,
    miniPos={x=0.08, y=0.1},
}

local function loadSave()
    pcall(function()
        if isfile and isfile(SAVE_FILE) then
            local d = HTTP:JSONDecode(readfile(SAVE_FILE))
            if d then for k,v in pairs(d) do saveData[k]=v end end
        end
    end)
end
local function writeSave()
    pcall(function()
        if writefile and saveData.autoSave then
            writefile(SAVE_FILE, HTTP:JSONEncode(saveData))
        end
    end)
end
loadSave()

-- ============================================================
--  RUNTIME STATE (module-level so sub-functions share it)
-- ============================================================
local FOV        = saveData.fov          or 75
local HBS        = saveData.hbs          or 10
local SMOOTH     = saveData.aimSmooth    or 18
local PRED       = saveData.predStrength or 0.35
local TRIG_DELAY = saveData.triggerDelay or 0.08
local AIM_BONE   = saveData.aimBone      or "UpperTorso"

local aimOn, espOn, tpOn, hbOn            = false, false, false, false
local silentAim, speedOn, trigBot         = false, false, false
local radarOn, ambOn, crOn                = false, false, saveData.crosshair
local espNamesOn   = saveData.espNames
local espHealthOn  = saveData.espHealth
local espBoxesOn   = saveData.espBoxes
local tracersOn    = saveData.tracers
local wallChk      = saveData.wallCheck
local teamChk      = saveData.teamCheck
local visChk       = saveData.visCheck
local noclipOn     = false
local infJumpOn    = false
local fullbrightOn = false
local antiAfkOn    = false
local chamsOn      = false
local skelOn       = false
local headLockOn   = false

local locked     = nil
local guiOpen    = false
local isDrag, isMini = false, false
local dS, dF, mS, mF, mMov = nil, nil, nil, nil, false

local espT       = {}
local espNameT   = {}
local espHealthT = {}
local espBoxT    = {}
local tracerT    = {}
local chamsT     = {}
local skelLines  = {}
local origSz     = {}
local hbC        = {}
local prevPos    = {}
local prevTime   = {}
local killCount  = 0
local sessionKills = {}

-- shared pill refs (set by buildTabAimbot / buildTabESP / etc.)
local pillRefs = {}

-- shared UI refs
local uiRefs   = {}

-- ============================================================
--  UTILITIES
-- ============================================================
local function clamp(v,mn,mx) return math.max(mn,math.min(mx,v)) end
local function lerp(a,b,t)    return a+(b-a)*t end
local function round(n,d)
    local f=10^(d or 0) return math.floor(n*f+0.5)/f
end
local function formatTime(s)
    return string.format("%02d:%02d",math.floor(s/60),math.floor(s%60))
end
local function getGreeting()
    local h=tonumber(os.date("%H"))
    if h>=5 and h<12 then return "Good Morning"
    elseif h>=12 and h<18 then return "Good Afternoon"
    else return "Good Night" end
end
local function copyToClipboard(text)
    local ok=false
    if setclipboard  then pcall(function() setclipboard(text)  ok=true end) end
    if not ok and toclipboard then pcall(function() toclipboard(text) ok=true end) end
    if not ok then pcall(function()
        local cs=game:GetService("Clipboard")
        if cs then cs:SetText(text) ok=true end
    end) end
    return ok
end

-- ============================================================
--  THEMES
-- ============================================================
local THEMES = {
    Red    = {Color3.fromRGB(215,38,38),   Color3.fromRGB(255,70,70)   },
    Blue   = {Color3.fromRGB(42,95,210),   Color3.fromRGB(80,140,255)  },
    Green  = {Color3.fromRGB(38,155,85),   Color3.fromRGB(60,200,110)  },
    Purple = {Color3.fromRGB(130,50,210),  Color3.fromRGB(180,90,255)  },
    Gold   = {Color3.fromRGB(180,130,0),   Color3.fromRGB(255,200,40)  },
    Cyan   = {Color3.fromRGB(0,170,200),   Color3.fromRGB(60,220,255)  },
    Pink   = {Color3.fromRGB(210,60,140),  Color3.fromRGB(255,100,180) },
    Orange = {Color3.fromRGB(210,100,20),  Color3.fromRGB(255,150,50)  },
}
local function getTheme() return THEMES[saveData.theme] or THEMES.Red end

-- ============================================================
--  GOLD GRADIENT CONSTANT
-- ============================================================
local GOLD_SEQ = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(255,215,60)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255,255,175)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(210,148,30)),
})

-- ============================================================
--  UI FACTORIES  (all small, shared across scopes)
-- ============================================================
local function gG(o)
    local g=Instance.new("UIGradient") g.Color=GOLD_SEQ g.Rotation=90 g.Parent=o return g
end
local function mkCorner(o,r)
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 12) c.Parent=o return c
end
local function mkStroke(o,t,col,tr)
    local s=Instance.new("UIStroke") s.Thickness=t s.Color=col s.Transparency=tr or 0 s.Parent=o return s
end
local function mkGrad(o,c1,c2,rot)
    local g=Instance.new("UIGradient")
    g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,c1),ColorSequenceKeypoint.new(1,c2)})
    g.Rotation=rot or 90 g.Parent=o return g
end
local function mkLabel(parent,text,sz,col,font,xa,zi)
    local l=Instance.new("TextLabel")
    l.BackgroundTransparency=1 l.Text=text l.TextSize=sz or 12
    l.TextColor3=col or Color3.fromRGB(255,255,255)
    l.FontFace=font or FONT_GOTHAM
    l.TextXAlignment=xa or Enum.TextXAlignment.Left
    l.ZIndex=zi or 13 l.Parent=parent return l
end
local function mkBtn(parent,text,sz,zi)
    local b=Instance.new("TextButton")
    b.BackgroundTransparency=1 b.Text=text b.TextSize=sz or 11
    b.TextColor3=Color3.fromRGB(255,255,255) b.FontFace=FONT_GOTHAM
    b.ZIndex=zi or 13 b.Parent=parent return b
end

-- ============================================================
--  CLOSE BUTTON FACTORY  (font fix applied here)
-- ============================================================
local function mkCloseBtn(parent,zIdx,onClose)
    local CB=Instance.new("TextButton")
    CB.Size=UDim2.new(0,28,0,28) CB.Position=UDim2.new(1,-34,0,6)
    CB.BackgroundColor3=Color3.fromRGB(255,255,255) CB.BackgroundTransparency=0
    CB.BorderSizePixel=0 CB.Text="X"
    CB.FontFace=FONT_COMIC  -- Comic Neue Angular Bold (fixed ID)
    CB.TextScaled=false CB.TextSize=13
    CB.TextColor3=Color3.fromRGB(255,255,255) CB.ZIndex=zIdx CB.Parent=parent
    mkCorner(CB,7)
    local bg=Instance.new("UIGradient")
    bg.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255,70,70)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200,35,35)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(110,10,10)),
    }) bg.Rotation=90 bg.Parent=CB
    gG(CB)
    local cbs=Instance.new("UIStroke")
    cbs.Thickness=2 cbs.ApplyStrokeMode=Enum.ApplyStrokeMode.Border cbs.Parent=CB
    local cbsg=Instance.new("UIGradient")
    cbsg.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255,180,80)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,255,160)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(200,120,20)),
    }) cbsg.Rotation=90 cbsg.Parent=cbs
    CB.MouseEnter:Connect(function() TS:Create(CB,TweenInfo.new(0.12),{BackgroundTransparency=0.2}):Play() end)
    CB.MouseLeave:Connect(function() TS:Create(CB,TweenInfo.new(0.12),{BackgroundTransparency=0}):Play() end)
    CB.MouseButton1Down:Connect(function() TS:Create(CB,TweenInfo.new(0.07),{BackgroundTransparency=0.4}):Play() end)
    CB.MouseButton1Up:Connect(function()   TS:Create(CB,TweenInfo.new(0.1), {BackgroundTransparency=0}):Play() end)
    CB.MouseButton1Click:Connect(onClose) CB.TouchTap:Connect(onClose)
    return CB
end

-- ============================================================
--  TOGGLE PILL FACTORY
-- ============================================================
local function mkPill(parent,zi)
    local pill=Instance.new("Frame")
    pill.Size=UDim2.new(0,42,0,21) pill.Position=UDim2.new(1,-52,0.5,-10.5)
    pill.BackgroundColor3=Color3.fromRGB(42,42,52) pill.BorderSizePixel=0
    pill.ZIndex=zi or 14 pill.Parent=parent mkCorner(pill,99)
    local knob=Instance.new("Frame")
    knob.Size=UDim2.new(0,15,0,15) knob.Position=UDim2.new(0,3,0.5,-7.5)
    knob.BackgroundColor3=Color3.fromRGB(140,140,155) knob.BorderSizePixel=0
    knob.ZIndex=(zi or 14)+1 knob.Parent=pill mkCorner(knob,99)
    return pill,knob
end

-- ============================================================
--  CARD FACTORY
-- ============================================================
local function mkCard(parent,lbl,x,y,w,h)
    w=w or 172 h=h or 52
    local card=Instance.new("Frame")
    card.Size=UDim2.new(0,w,0,h) card.Position=UDim2.new(0,x,0,y)
    card.BackgroundColor3=Color3.fromRGB(24,24,30) card.BackgroundTransparency=0.08
    card.BorderSizePixel=0 card.ZIndex=13 card.Parent=parent
    mkCorner(card,10) mkStroke(card,1,Color3.fromRGB(50,50,62),0.5)
    local lt=Instance.new("TextLabel")
    lt.Size=UDim2.new(1,-56,0,17) lt.Position=UDim2.new(0,10,0,8)
    lt.BackgroundTransparency=1 lt.Text=lbl
    lt.TextColor3=Color3.fromRGB(255,255,255) lt.FontFace=FONT_GOTHAM
    lt.TextSize=11 lt.TextXAlignment=Enum.TextXAlignment.Left lt.ZIndex=14 lt.Parent=card
    gG(lt)
    local dot=Instance.new("Frame")
    dot.Size=UDim2.new(0,6,0,6) dot.Position=UDim2.new(0,10,0,32)
    dot.BackgroundColor3=Color3.fromRGB(70,70,82) dot.BorderSizePixel=0
    dot.ZIndex=14 dot.Parent=card mkCorner(dot,99)
    local dtxt=Instance.new("TextLabel")
    dtxt.Size=UDim2.new(1,-56,0,12) dtxt.Position=UDim2.new(0,20,0,29)
    dtxt.BackgroundTransparency=1 dtxt.Text="OFF"
    dtxt.TextColor3=Color3.fromRGB(90,90,105) dtxt.FontFace=FONT_GOTHAM
    dtxt.TextSize=9 dtxt.TextXAlignment=Enum.TextXAlignment.Left dtxt.ZIndex=14 dtxt.Parent=card
    local pill,knob=mkPill(card,15)
    return card,pill,knob,dot,dtxt
end

-- ============================================================
--  ANIMATE TOGGLE
-- ============================================================
local function animT(pill,knob,dot,dtxt,state,col,onTxt)
    local ti=TweenInfo.new(0.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
    if state then
        TS:Create(pill,ti,{BackgroundColor3=col}):Play()
        TS:Create(knob,ti,{Position=UDim2.new(0,23,0.5,-7.5),BackgroundColor3=Color3.fromRGB(255,255,255)}):Play()
        TS:Create(dot,TweenInfo.new(0.15),{BackgroundColor3=col}):Play()
        dtxt.Text=onTxt or "ON" dtxt.TextColor3=col
    else
        TS:Create(pill,ti,{BackgroundColor3=Color3.fromRGB(42,42,52)}):Play()
        TS:Create(knob,ti,{Position=UDim2.new(0,3,0.5,-7.5),BackgroundColor3=Color3.fromRGB(140,140,155)}):Play()
        TS:Create(dot,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(70,70,82)}):Play()
        dtxt.Text="OFF" dtxt.TextColor3=Color3.fromRGB(90,90,105)
    end
end

-- ============================================================
--  INPUT BLOCK FACTORY
-- ============================================================
local function mkInput(parent,lbl,def,maxV,x,y)
    local blk=Instance.new("Frame")
    blk.Size=UDim2.new(0,172,0,66) blk.Position=UDim2.new(0,x,0,y)
    blk.BackgroundColor3=Color3.fromRGB(20,20,26) blk.BackgroundTransparency=0.08
    blk.BorderSizePixel=0 blk.ZIndex=13 blk.Parent=parent
    mkCorner(blk,10) mkStroke(blk,1,Color3.fromRGB(50,50,62),0.5)
    local lt=Instance.new("TextLabel")
    lt.Size=UDim2.new(1,-12,0,15) lt.Position=UDim2.new(0,10,0,6)
    lt.BackgroundTransparency=1 lt.Text=lbl lt.TextColor3=Color3.fromRGB(255,255,255)
    lt.FontFace=FONT_GOTHAM lt.TextSize=10 lt.TextXAlignment=Enum.TextXAlignment.Left
    lt.ZIndex=14 lt.Parent=blk gG(lt)
    local box=Instance.new("TextBox")
    box.Size=UDim2.new(0,75,0,26) box.Position=UDim2.new(0,10,0,24)
    box.BackgroundColor3=Color3.fromRGB(30,30,38) box.BackgroundTransparency=0.05
    box.BorderSizePixel=0 box.Text=tostring(def)
    box.TextColor3=Color3.fromRGB(255,215,60) box.FontFace=FONT_GOTHAM
    box.TextSize=13 box.ClearTextOnFocus=true box.ZIndex=15 box.Parent=blk mkCorner(box,6)
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(0,58,0,26) btn.Position=UDim2.new(0,94,0,24)
    btn.BackgroundColor3=Color3.fromRGB(42,95,210) btn.BorderSizePixel=0
    btn.Text="APPLY" btn.TextColor3=Color3.fromRGB(255,255,255)
    btn.FontFace=FONT_GOTHAM btn.TextSize=10 btn.ZIndex=15 btn.Parent=blk mkCorner(btn,6)
    local ht=Instance.new("TextLabel")
    ht.Size=UDim2.new(1,-12,0,12) ht.Position=UDim2.new(0,10,0,52)
    ht.BackgroundTransparency=1 ht.Text="MAX "..tostring(maxV)
    ht.TextColor3=Color3.fromRGB(58,58,70) ht.FontFace=FONT_GOTHAM
    ht.TextSize=8 ht.TextXAlignment=Enum.TextXAlignment.Left ht.ZIndex=14 ht.Parent=blk
    return box,btn
end

-- ============================================================
--  SCREEN GUI  (root)
-- ============================================================
local SG=Instance.new("ScreenGui")
SG.Name="RivalsAB_v5" SG.ResetOnSpawn=false
SG.IgnoreGuiInset=true SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
SG.Parent=LP.PlayerGui

-- ============================================================
--  BLUR EFFECT
-- ============================================================
local blur=Instance.new("BlurEffect") blur.Size=0 blur.Parent=Lighting

-- ============================================================
--  NOTIFICATION SYSTEM   ← own scope = own register pool
-- ============================================================
local notifCount=0
local function showNotif(title,msg,col,dur)
    if not saveData.notifications then return end
    col=col or Color3.fromRGB(42,95,210) dur=dur or 3.5
    notifCount=notifCount+1

    local NF=SG:FindFirstChild("__NF")
    if not NF then
        NF=Instance.new("Frame") NF.Name="__NF"
        NF.Size=UDim2.new(0,270,1,0) NF.Position=UDim2.new(1,-280,0,0)
        NF.BackgroundTransparency=1 NF.BorderSizePixel=0 NF.ZIndex=500 NF.Parent=SG
    end

    local nc=Instance.new("Frame")
    nc.Size=UDim2.new(1,0,0,64) nc.Position=UDim2.new(0,0,1,10)
    nc.BackgroundColor3=Color3.fromRGB(18,18,24) nc.BackgroundTransparency=0.06
    nc.BorderSizePixel=0 nc.ZIndex=501 nc.Parent=NF mkCorner(nc,12) mkStroke(nc,1.5,col,0.25)

    local bar=Instance.new("Frame") bar.Size=UDim2.new(0,3,0.75,0)
    bar.Position=UDim2.new(0,0,0.125,0) bar.BackgroundColor3=col
    bar.BorderSizePixel=0 bar.ZIndex=502 bar.Parent=nc mkCorner(bar,99)

    local nT=Instance.new("TextLabel") nT.Size=UDim2.new(1,-18,0,18)
    nT.Position=UDim2.new(0,12,0,7) nT.BackgroundTransparency=1
    nT.Text=title nT.TextColor3=col nT.FontFace=FONT_GOTHAM
    nT.TextSize=11 nT.TextXAlignment=Enum.TextXAlignment.Left nT.ZIndex=502 nT.Parent=nc

    local nM=Instance.new("TextLabel") nM.Size=UDim2.new(1,-18,0,26)
    nM.Position=UDim2.new(0,12,0,27) nM.BackgroundTransparency=1
    nM.Text=msg nM.TextColor3=Color3.fromRGB(175,175,195) nM.FontFace=FONT_GOTHAM
    nM.TextSize=9 nM.TextXAlignment=Enum.TextXAlignment.Left
    nM.TextWrapped=true nM.ZIndex=502 nM.Parent=nc

    local npbg=Instance.new("Frame") npbg.Size=UDim2.new(1,-10,0,2)
    npbg.Position=UDim2.new(0,5,1,-4) npbg.BackgroundColor3=Color3.fromRGB(40,40,50)
    npbg.BorderSizePixel=0 npbg.ZIndex=502 npbg.Parent=nc mkCorner(npbg,99)
    local npb=Instance.new("Frame") npb.Size=UDim2.new(1,0,1,0)
    npb.BackgroundColor3=col npb.BorderSizePixel=0 npb.ZIndex=503 npb.Parent=npbg mkCorner(npb,99)

    local kids=#NF:GetChildren()
    local yOff=-(kids*72+8)
    TS:Create(nc,TweenInfo.new(0.3,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.new(0,0,1,yOff)}):Play()
    TS:Create(npb,TweenInfo.new(dur,Enum.EasingStyle.Linear),{Size=UDim2.new(0,0,1,0)}):Play()

    task.delay(dur,function()
        TS:Create(nc,TweenInfo.new(0.28,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{
            Position=UDim2.new(1,20,1,yOff),BackgroundTransparency=1}):Play()
        task.delay(0.32,function()
            if nc and nc.Parent then nc:Destroy() end
            notifCount=math.max(0,notifCount-1)
        end)
    end)
end

-- ============================================================
--  ESP SYSTEM
-- ============================================================
local function addESP(p)
    if p==LP then return end
    local tc=getTheme()
    local function apply()
        local c=p.Character if not c then return end
        if espT[p]       then espT[p]:Destroy()       espT[p]=nil       end
        if espNameT[p]   then espNameT[p]:Destroy()   espNameT[p]=nil   end
        if espHealthT[p] then espHealthT[p]:Destroy() espHealthT[p]=nil end
        if espBoxT[p]    then espBoxT[p]:Destroy()    espBoxT[p]=nil    end
        if teamChk and p.Team==LP.Team then return end
        if espOn then
            local sb=Instance.new("SelectionBox")
            sb.Color3=tc[1] sb.LineThickness=0.04
            sb.SurfaceTransparency=0.6 sb.SurfaceColor3=tc[1]
            sb.Adornee=c sb.Parent=c espT[p]=sb
        end
        if espNamesOn then
            local head=c:FindFirstChild("Head")
            if head then
                local bg=Instance.new("BillboardGui")
                bg.Size=UDim2.new(0,80,0,20) bg.StudsOffset=Vector3.new(0,2.5,0)
                bg.AlwaysOnTop=true bg.Adornee=head bg.Parent=head
                local tl=Instance.new("TextLabel")
                tl.Size=UDim2.new(1,0,1,0) tl.BackgroundTransparency=1
                tl.Text=p.DisplayName tl.TextColor3=tc[2]
                tl.FontFace=FONT_GOTHAM tl.TextScaled=true tl.ZIndex=5 tl.Parent=bg
                espNameT[p]=bg
            end
        end
        if espHealthOn then
            local hrp=c:FindFirstChild("HumanoidRootPart")
            local hum=c:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                local bg2=Instance.new("BillboardGui")
                bg2.Size=UDim2.new(0,60,0,10) bg2.StudsOffset=Vector3.new(0,-1.5,0)
                bg2.AlwaysOnTop=true bg2.Adornee=hrp bg2.Parent=hrp
                local barBG=Instance.new("Frame")
                barBG.Size=UDim2.new(1,0,1,0) barBG.BackgroundColor3=Color3.fromRGB(30,30,30)
                barBG.BorderSizePixel=0 barBG.Parent=bg2 mkCorner(barBG,4)
                local fill=Instance.new("Frame")
                fill.Size=UDim2.new(hum.Health/hum.MaxHealth,0,1,0)
                fill.BackgroundColor3=Color3.fromRGB(80,220,80)
                fill.BorderSizePixel=0 fill.Parent=barBG mkCorner(fill,4)
                hum:GetPropertyChangedSignal("Health"):Connect(function()
                    if not fill or not fill.Parent then return end
                    local pct=clamp(hum.Health/hum.MaxHealth,0,1)
                    fill.Size=UDim2.new(pct,0,1,0)
                    fill.BackgroundColor3=Color3.fromHSV(pct*0.33,0.9,0.9)
                end)
                espHealthT[p]=bg2
            end
        end
        if espBoxesOn then
            local hl=Instance.new("Highlight")
            hl.FillTransparency=0.8 hl.OutlineTransparency=0
            hl.FillColor=tc[1] hl.OutlineColor=tc[2] hl.Adornee=c hl.Parent=c
            espBoxT[p]=hl
        end
    end
    apply()
    p.CharacterAdded:Connect(function() task.wait(0.12) apply() end)
end

local function remESP(p)
    if espT[p]       then espT[p]:Destroy()       espT[p]=nil       end
    if espNameT[p]   then espNameT[p]:Destroy()   espNameT[p]=nil   end
    if espHealthT[p] then espHealthT[p]:Destroy() espHealthT[p]=nil end
    if espBoxT[p]    then espBoxT[p]:Destroy()    espBoxT[p]=nil    end
    if chamsT[p]     then chamsT[p]:Destroy()     chamsT[p]=nil     end
end
local function enESP()  for _,p in ipairs(PL:GetPlayers()) do addESP(p) end end
local function disESP() for _,p in ipairs(PL:GetPlayers()) do remESP(p) end end

-- Chams
local function applyCham(p)
    if p==LP or not chamsOn then return end
    local c=p.Character if not c then return end
    if chamsT[p] then chamsT[p]:Destroy() chamsT[p]=nil end
    local hl=Instance.new("Highlight")
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency=0.4 hl.OutlineTransparency=0
    local tc=getTheme() hl.FillColor=tc[1] hl.OutlineColor=tc[2]
    hl.Adornee=c hl.Parent=c chamsT[p]=hl
end
local function enChams()  for _,p in ipairs(PL:GetPlayers()) do applyCham(p) end end
local function disChams() for _,p in ipairs(PL:GetPlayers()) do
    if chamsT[p] then chamsT[p]:Destroy() chamsT[p]=nil end
end end

-- Tracer frame
local TracerFrame=Instance.new("Frame")
TracerFrame.Size=UDim2.new(1,0,1,0) TracerFrame.BackgroundTransparency=1
TracerFrame.BorderSizePixel=0 TracerFrame.ZIndex=8 TracerFrame.Parent=SG

local function updateTracers()
    for _,ln in pairs(tracerT) do if ln and ln.Parent then ln:Destroy() end end
    tracerT={}
    if not tracersOn then return end
    local vp=CAM.ViewportSize
    local originY=(saveData.tracerOrigin=="Center") and vp.Y/2 or vp.Y
    local origin=Vector2.new(vp.X/2,originY)
    local tc=getTheme()
    for _,p in ipairs(PL:GetPlayers()) do
        if p==LP then continue end
        local c=p.Character if not c then continue end
        local hrp=c:FindFirstChild("HumanoidRootPart") if not hrp then continue end
        local sp,on=CAM:WorldToViewportPoint(hrp.Position)
        if not on then continue end
        local target=Vector2.new(sp.X,sp.Y)
        local dir=(target-origin) local dist=dir.Magnitude
        if dist<1 then continue end
        local ang=math.atan2(dir.Y,dir.X)
        local ln=Instance.new("Frame")
        ln.Size=UDim2.new(0,dist,0,1) ln.Position=UDim2.new(0,origin.X,0,origin.Y)
        ln.Rotation=math.deg(ang) ln.AnchorPoint=Vector2.new(0,0.5)
        ln.BackgroundColor3=tc[1] ln.BackgroundTransparency=0.3
        ln.BorderSizePixel=0 ln.ZIndex=8 ln.Parent=TracerFrame
        tracerT[p]=ln
    end
end

-- ============================================================
--  HITBOX SYSTEM
-- ============================================================
local function expHB(p)
    if p==LP then return end
    local c=p.Character if not c then return end
    local r=c:FindFirstChild("HumanoidRootPart") if not r then return end
    if not origSz[p] then origSz[p]=r.Size end
    r.Size=Vector3.new(HBS,HBS,HBS)
end
local function rstHB(p)
    if origSz[p] then
        local c=p.Character
        if c then local r=c:FindFirstChild("HumanoidRootPart") if r then r.Size=origSz[p] end end
        origSz[p]=nil
    end
end
local function enHB()
    for _,p in ipairs(PL:GetPlayers()) do
        expHB(p)
        table.insert(hbC,p.CharacterAdded:Connect(function()
            task.wait(0.1) if hbOn then expHB(p) end
        end))
    end
end
local function disHB()
    for _,c in ipairs(hbC) do c:Disconnect() end hbC={}
    for _,p in ipairs(PL:GetPlayers()) do rstHB(p) end
end

-- ============================================================
--  TELEPORT MARK
-- ============================================================
local function findMark()
    for _,n in ipairs({"Mark","KillMark","TeleportMark","Marker","TargetMark","CheckPoint"}) do
        local p=workspace:FindFirstChild(n,true)
        if p and p:IsA("BasePart") then return p end
    end
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Material==Enum.Material.Neon then
            local ip=false
            for _,pl in ipairs(PL:GetPlayers()) do
                if pl.Character and obj:IsDescendantOf(pl.Character) then ip=true break end
            end
            if not ip then return obj end
        end
    end
end
local function doTP()
    local c=LP.Character if not c then return end
    local r=c:FindFirstChild("HumanoidRootPart") if not r then return end
    local mk=findMark() if not mk then return end
    TS:Create(r,TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
        CFrame=CFrame.new(mk.Position+Vector3.new(0,3,0))}):Play()
end

-- ============================================================
--  AIMBOT HELPERS
-- ============================================================
local function getVC()
    local vp=CAM.ViewportSize return Vector2.new(vp.X/2,vp.Y/2)
end
local function inFOV(wp)
    local sp,on=CAM:WorldToViewportPoint(wp)
    if not on or sp.Z<0 then return false,nil,nil end
    local sv=Vector2.new(sp.X,sp.Y)
    local d=(sv-getVC()).Magnitude
    return d<=FOV,sv,d
end
local function isVisible(pos)
    if not wallChk then return true end
    local c=LP.Character if not c then return true end
    local origin=c:FindFirstChild("Head") if not origin then return true end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={c}
    local result=workspace:Raycast(origin.Position,pos-origin.Position,params)
    if result then
        for _,p in ipairs(PL:GetPlayers()) do
            if p~=LP and p.Character and result.Instance:IsDescendantOf(p.Character) then return true end
        end
        return false
    end
    return true
end
local function getPredictedPos(hrp)
    local now=os.clock()
    if prevPos[hrp] and prevTime[hrp] then
        local dt2=now-prevTime[hrp]
        if dt2>0 then
            local vel=(hrp.Position-prevPos[hrp])/dt2
            prevPos[hrp]=hrp.Position prevTime[hrp]=now
            return hrp.Position+vel*PRED
        end
    end
    prevPos[hrp]=hrp.Position prevTime[hrp]=now return hrp.Position
end
local function tgtValid(part)
    if not part or not part.Parent then return false end
    local c=part.Parent
    local hum=c:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health<=0 then return false end
    if teamChk then
        local owner=PL:GetPlayerFromCharacter(c)
        if owner and owner.Team==LP.Team then return false end
    end
    return true
end
local function findTgt()
    local best,bd=nil,math.huge
    for _,pl in ipairs(PL:GetPlayers()) do
        if pl==LP then continue end
        local c=pl.Character if not c then continue end
        local hum=c:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health<=0 then continue end
        local bone=c:FindFirstChild(AIM_BONE) or c:FindFirstChild("UpperTorso") or c:FindFirstChild("HumanoidRootPart")
        if not bone then continue end
        if teamChk and pl.Team==LP.Team then continue end
        local ok,_,d=inFOV(bone.Position)
        if ok and d<bd then
            if not visChk or isVisible(bone.Position) then bd=d best=bone end
        end
    end
    return best
end

-- ============================================================
--  EXTRA SYSTEMS (noclip, infJump, fullbright, antiAfk)
-- ============================================================
local origAmb    = Lighting.Ambient
local origOutAmb = Lighting.OutdoorAmbient
local origBright = Lighting.Brightness
local origClock  = Lighting.ClockTime
local origFog    = Lighting.FogEnd
local origWS     = nil
local origCamFOV = 70
local noclipConn, infJumpConn, antiAfkConn = nil, nil, nil

local function setNoclip(s)
    noclipOn=s
    if s then
        noclipConn=RS.Stepped:Connect(function()
            local c=LP.Character if not c then return end
            for _,part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide=false end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect() noclipConn=nil end
        local c=LP.Character if not c then return end
        for _,part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide=true end
        end
    end
end
local function setInfJump(s)
    infJumpOn=s
    if s then
        infJumpConn=UIS.JumpRequest:Connect(function()
            local c=LP.Character if not c then return end
            local hum=c:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    else
        if infJumpConn then infJumpConn:Disconnect() infJumpConn=nil end
    end
end
local function setFullbright(s)
    fullbrightOn=s
    if s then
        TS:Create(Lighting,TweenInfo.new(0.8),{Brightness=2,FogEnd=100000}):Play()
        Lighting.ClockTime=14
    else
        TS:Create(Lighting,TweenInfo.new(0.8),{Brightness=origBright,FogEnd=origFog}):Play()
        Lighting.ClockTime=origClock
    end
end
local function setAntiAfk(s)
    antiAfkOn=s
    if s then
        antiAfkConn=RS.Heartbeat:Connect(function()
            local vu=game:GetService("VirtualUser")
            if vu then
                pcall(function() vu:CaptureController() end)
                pcall(function() vu:ClickButton2(Vector2.new()) end)
            end
        end)
    else
        if antiAfkConn then antiAfkConn:Disconnect() antiAfkConn=nil end
    end
end

-- ============================================================
--  KEY SYSTEM  (own function = own register pool)
-- ============================================================
local function buildKeySystem(onSuccess)
    TS:Create(blur,TweenInfo.new(0.5),{Size=24}):Play()

    local KF=Instance.new("Frame")
    KF.Size=UDim2.new(1,0,1,0) KF.BackgroundColor3=Color3.fromRGB(0,0,0)
    KF.BackgroundTransparency=0.45 KF.BorderSizePixel=0 KF.ZIndex=200 KF.Parent=SG

    local KC=Instance.new("Frame")
    KC.AnchorPoint=Vector2.new(0.5,0.5) KC.Position=UDim2.new(0.5,0,0.5,0)
    KC.Size=UDim2.new(0,0,0,215)
    KC.BackgroundColor3=Color3.fromRGB(17,17,24) KC.BackgroundTransparency=1
    KC.BorderSizePixel=0 KC.ZIndex=201 KC.Parent=KF
    mkCorner(KC,16) mkStroke(KC,1.8,Color3.fromRGB(55,55,70),0.3)
    mkGrad(KC,Color3.fromRGB(22,22,32),Color3.fromRGB(12,12,18),140)

    TS:Create(KC,TweenInfo.new(0.32,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{
        Size=UDim2.new(0,480,0,215),BackgroundTransparency=0.02}):Play()

    -- drag
    local kDrag,kDS,kDF=false,nil,nil
    KC.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            kDrag=true kDS=inp.Position kDF=KC.Position
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if kDrag and(inp.UserInputType==Enum.UserInputType.MouseMovement
                  or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-kDS
            KC.Position=UDim2.new(kDF.X.Scale,kDF.X.Offset+d.X,kDF.Y.Scale,kDF.Y.Offset+d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then kDrag=false end
    end)

    local function closeKF()
        TS:Create(KC,TweenInfo.new(0.26,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{
            Size=UDim2.new(0,0,0,215),BackgroundTransparency=1}):Play()
        task.delay(0.28,function()
            TS:Create(blur,TweenInfo.new(0.4),{Size=0}):Play()
            TS:Create(KF,TweenInfo.new(0.3),{BackgroundTransparency=1}):Play()
            task.delay(0.32,function() if KF and KF.Parent then KF:Destroy() end end)
        end)
    end
    mkCloseBtn(KC,215,closeKF)

    -- Left panel
    local KLeft=Instance.new("Frame")
    KLeft.Size=UDim2.new(0,155,1,0) KLeft.BackgroundColor3=Color3.fromRGB(11,11,16)
    KLeft.BackgroundTransparency=0.05 KLeft.BorderSizePixel=0 KLeft.ZIndex=202 KLeft.Parent=KC
    mkCorner(KLeft,16) mkGrad(KLeft,Color3.fromRGB(18,18,26),Color3.fromRGB(9,9,14),180)

    local KLogo=Instance.new("ImageLabel")
    KLogo.Size=UDim2.new(0,68,0,68) KLogo.AnchorPoint=Vector2.new(0.5,0)
    KLogo.Position=UDim2.new(0.5,0,0,18) KLogo.BackgroundTransparency=1
    KLogo.Image=LOGO_IMG KLogo.ImageTransparency=0 KLogo.ScaleType=Enum.ScaleType.Fit
    KLogo.ZIndex=203 KLogo.Parent=KLeft mkCorner(KLogo,10)
    local KLS=mkStroke(KLogo,2,Color3.fromRGB(255,0,0))
    local klhue=0
    RS.Heartbeat:Connect(function(dt)
        klhue=(klhue+dt*0.55)%1
        if KLS and KLS.Parent then KLS.Color=Color3.fromHSV(klhue,1,1) end
    end)

    local function kTxt(p,text,y,sz,col)
        local l=Instance.new("TextLabel")
        l.Size=UDim2.new(1,-8,0,20) l.Position=UDim2.new(0,4,0,y)
        l.BackgroundTransparency=1 l.Text=text
        l.TextColor3=col or Color3.fromRGB(255,255,255)
        l.FontFace=FONT_GOTHAM l.TextSize=sz
        l.TextXAlignment=Enum.TextXAlignment.Center l.ZIndex=203 l.Parent=p
        return l
    end
    local kt=kTxt(KLeft,"RIVALS",92,16) gG(kt)
    kTxt(KLeft,"AIMBOT",112,12,Color3.fromRGB(200,200,215))
    kTxt(KLeft,"🔐 KEY SYSTEM",132,9,Color3.fromRGB(110,110,130))
    kTxt(KLeft,VERSION,196,8,Color3.fromRGB(45,45,58))

    -- Right panel
    local KRight=Instance.new("Frame")
    KRight.Size=UDim2.new(1,-163,1,-8) KRight.Position=UDim2.new(0,159,0,4)
    KRight.BackgroundTransparency=1 KRight.ZIndex=202 KRight.Parent=KC

    local feats={"🎯 AimBot","👀 ESP","📡 Health","🛠️ Hitbox","🎨 Themes","🔔 Notifs",
                 "🚀 Teleport","📊 Kills","🔮 Prediction","🌙 Ambient","➕ Crosshair","🔕 Silent"}
    for i,f in ipairs(feats) do
        local col=(i-1)%2 local row=math.floor((i-1)/2)
        local fl=Instance.new("TextLabel")
        fl.Size=UDim2.new(0,145,0,14) fl.Position=UDim2.new(0,col*149,0,2+row*15)
        fl.BackgroundTransparency=1 fl.Text=f fl.TextColor3=Color3.fromRGB(170,170,190)
        fl.FontFace=FONT_GOTHAM fl.TextSize=8 fl.TextXAlignment=Enum.TextXAlignment.Left
        fl.ZIndex=203 fl.Parent=KRight
    end

    local KDiv=Instance.new("Frame") KDiv.Size=UDim2.new(1,0,0,1)
    KDiv.Position=UDim2.new(0,0,0,96) KDiv.BackgroundColor3=Color3.fromRGB(255,255,255)
    KDiv.BackgroundTransparency=0.82 KDiv.BorderSizePixel=0 KDiv.ZIndex=203 KDiv.Parent=KRight

    local KBox=Instance.new("TextBox")
    KBox.Size=UDim2.new(1,-8,0,36) KBox.Position=UDim2.new(0,4,0,104)
    KBox.BackgroundColor3=Color3.fromRGB(26,26,36) KBox.BackgroundTransparency=0.05
    KBox.BorderSizePixel=0 KBox.PlaceholderText="Enter key here..."
    KBox.PlaceholderColor3=Color3.fromRGB(80,80,95) KBox.Text=""
    KBox.TextColor3=Color3.fromRGB(255,255,255) KBox.FontFace=FONT_GOTHAM
    KBox.TextSize=14 KBox.ClearTextOnFocus=false KBox.ZIndex=203 KBox.Parent=KRight
    mkCorner(KBox,9) mkStroke(KBox,1.5,Color3.fromRGB(60,60,80),0.3)

    local KErrL=Instance.new("TextLabel")
    KErrL.Size=UDim2.new(1,-8,0,13) KErrL.Position=UDim2.new(0,4,0,144)
    KErrL.BackgroundTransparency=1 KErrL.Text="" KErrL.TextColor3=Color3.fromRGB(220,60,60)
    KErrL.FontFace=FONT_GOTHAM KErrL.TextSize=9
    KErrL.TextXAlignment=Enum.TextXAlignment.Center KErrL.ZIndex=203 KErrL.Parent=KRight

    local function mkKBtn(txt,xOff,c1,c2,c3)
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(0,145,0,36) b.Position=UDim2.new(0,xOff,0,162)
        b.BackgroundColor3=c1 b.BorderSizePixel=0 b.Text=txt
        b.TextColor3=Color3.fromRGB(255,255,255) b.FontFace=FONT_GOTHAM
        b.TextSize=11 b.ZIndex=203 b.Parent=KRight mkCorner(b,9)
        mkGrad(b,c2,c3,90)
        b.MouseEnter:Connect(function() TS:Create(b,TweenInfo.new(0.12),{BackgroundTransparency=0.15}):Play() end)
        b.MouseLeave:Connect(function() TS:Create(b,TweenInfo.new(0.12),{BackgroundTransparency=0}):Play() end)
        b.MouseButton1Down:Connect(function() TS:Create(b,TweenInfo.new(0.07),{BackgroundTransparency=0.35}):Play() end)
        b.MouseButton1Up:Connect(function()   TS:Create(b,TweenInfo.new(0.1), {BackgroundTransparency=0}):Play() end)
        return b
    end
    local KGetBtn=mkKBtn("🔑  Get Key",0,
        Color3.fromRGB(180,120,0),Color3.fromRGB(255,185,30),Color3.fromRGB(160,95,0))
    local KVerBtn=mkKBtn("✅  Verify Key",149,
        Color3.fromRGB(38,140,75),Color3.fromRGB(55,175,95),Color3.fromRGB(25,105,55))

    -- Secret key popup
    local KWarn=Instance.new("Frame")
    KWarn.Size=UDim2.new(0,280,0,135) KWarn.AnchorPoint=Vector2.new(0.5,0.5)
    KWarn.Position=UDim2.new(0.5,0,0.5,0) KWarn.BackgroundColor3=Color3.fromRGB(30,18,6)
    KWarn.BackgroundTransparency=0.02 KWarn.BorderSizePixel=0
    KWarn.Visible=false KWarn.ZIndex=250 KWarn.Parent=SG
    mkCorner(KWarn,14) mkStroke(KWarn,2,Color3.fromRGB(255,165,30),0.15)
    mkGrad(KWarn,Color3.fromRGB(48,26,8),Color3.fromRGB(22,12,4),140)

    local kwT=Instance.new("TextLabel") kwT.Size=UDim2.new(1,-20,0,20)
    kwT.Position=UDim2.new(0,10,0,10) kwT.BackgroundTransparency=1
    kwT.Text="⚠️  SECRET KEY" kwT.TextColor3=Color3.fromRGB(255,180,30)
    kwT.FontFace=FONT_GOTHAM kwT.TextSize=13
    kwT.TextXAlignment=Enum.TextXAlignment.Left kwT.ZIndex=251 kwT.Parent=KWarn

    local kwBox=Instance.new("Frame") kwBox.Size=UDim2.new(1,-20,0,30)
    kwBox.Position=UDim2.new(0,10,0,36) kwBox.BackgroundColor3=Color3.fromRGB(20,12,4)
    kwBox.BackgroundTransparency=0.1 kwBox.BorderSizePixel=0 kwBox.ZIndex=251 kwBox.Parent=KWarn
    mkCorner(kwBox,8) mkStroke(kwBox,1.2,Color3.fromRGB(255,165,30),0.4)
    local kwKey=Instance.new("TextLabel") kwKey.Size=UDim2.new(1,-12,1,0)
    kwKey.Position=UDim2.new(0,6,0,0) kwKey.BackgroundTransparency=1
    kwKey.Text="🔑  "..CORRECT_KEY kwKey.TextColor3=Color3.fromRGB(255,235,140)
    kwKey.FontFace=FONT_GOTHAM kwKey.TextSize=14
    kwKey.TextXAlignment=Enum.TextXAlignment.Center kwKey.ZIndex=252 kwKey.Parent=kwBox

    local kwSub=Instance.new("TextLabel") kwSub.Size=UDim2.new(1,-20,0,13)
    kwSub.Position=UDim2.new(0,10,0,72) kwSub.BackgroundTransparency=1
    kwSub.Text="Do not share this key!" kwSub.TextColor3=Color3.fromRGB(160,110,50)
    kwSub.FontFace=FONT_GOTHAM kwSub.TextSize=8
    kwSub.TextXAlignment=Enum.TextXAlignment.Center kwSub.ZIndex=251 kwSub.Parent=KWarn

    local function mkWB(txt,xOff,c1,c2,c3)
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(0,120,0,30) b.Position=UDim2.new(0,xOff,0,93)
        b.BackgroundColor3=c1 b.BorderSizePixel=0 b.Text=txt
        b.TextColor3=Color3.fromRGB(255,255,255) b.FontFace=FONT_GOTHAM
        b.TextSize=11 b.ZIndex=251 b.Parent=KWarn mkCorner(b,8) mkGrad(b,c2,c3,90) return b
    end
    local WCopyBtn=mkWB("📋  Copy Key",12,
        Color3.fromRGB(42,95,210),Color3.fromRGB(70,125,245),Color3.fromRGB(28,68,170))
    local WNvmBtn=mkWB("✖  Nevermind",146,
        Color3.fromRGB(70,70,82),Color3.fromRGB(90,90,105),Color3.fromRGB(50,50,62))

    local function openWarn()
        KWarn.Visible=true KWarn.Size=UDim2.new(0,280,0,0) KWarn.BackgroundTransparency=1
        TS:Create(KWarn,TweenInfo.new(0.28,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{
            Size=UDim2.new(0,280,0,135),BackgroundTransparency=0.02}):Play()
    end
    local function closeWarn()
        TS:Create(KWarn,TweenInfo.new(0.22,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{
            Size=UDim2.new(0,280,0,0),BackgroundTransparency=1}):Play()
        task.delay(0.25,function() KWarn.Visible=false KWarn.Size=UDim2.new(0,280,0,135) KWarn.BackgroundTransparency=0.02 end)
    end
    WCopyBtn.MouseButton1Click:Connect(function()
        local ok=copyToClipboard(CORRECT_KEY)
        WCopyBtn.Text=ok and "✅  Copied!" or "Key: "..CORRECT_KEY
        TS:Create(WCopyBtn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(38,155,75)}):Play()
        task.delay(0.85,function() closeWarn() end)
        task.delay(1.15,function()
            WCopyBtn.Text="📋  Copy Key"
            TS:Create(WCopyBtn,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(42,95,210)}):Play()
        end)
    end)
    WCopyBtn.TouchTap:Connect(function() WCopyBtn.MouseButton1Click:Fire() end)
    WNvmBtn.MouseButton1Click:Connect(closeWarn) WNvmBtn.TouchTap:Connect(closeWarn)
    KGetBtn.MouseButton1Click:Connect(openWarn) KGetBtn.TouchTap:Connect(openWarn)

    local function tryKey()
        local input=KBox.Text:gsub("^%s+",""):gsub("%s+$","")
        if input==CORRECT_KEY then
            saveData.keyPassed=true writeSave()
            KErrL.Text="✅  Key accepted!" KErrL.TextColor3=Color3.fromRGB(80,220,120)
            TS:Create(KBox,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(18,38,22)}):Play()
            task.delay(0.32,function()
                TS:Create(KC,TweenInfo.new(0.26,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{
                    Size=UDim2.new(0,0,0,215),BackgroundTransparency=1}):Play()
            end)
            task.delay(0.62,function()
                TS:Create(KF,TweenInfo.new(0.3),{BackgroundTransparency=1}):Play()
                task.delay(0.32,function()
                    if KF and KF.Parent then KF:Destroy() end
                    if KWarn and KWarn.Parent then KWarn:Destroy() end
                end)
                onSuccess()
            end)
        else
            KErrL.Text="❌  Wrong key!" KErrL.TextColor3=Color3.fromRGB(220,60,60)
            TS:Create(KBox,TweenInfo.new(0.06),{BackgroundColor3=Color3.fromRGB(60,20,20)}):Play()
            local orig=KC.Position
            for i=1,5 do
                task.delay(i*0.045,function()
                    KC.Position=UDim2.new(orig.X.Scale,orig.X.Offset+(i%2==0 and 8 or -8),orig.Y.Scale,orig.Y.Offset)
                end)
            end
            task.delay(0.26,function() TS:Create(KC,TweenInfo.new(0.14),{Position=orig}):Play() end)
            task.delay(0.6,function() TS:Create(KBox,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(26,26,36)}):Play() end)
        end
    end
    KVerBtn.MouseButton1Click:Connect(tryKey) KVerBtn.TouchTap:Connect(tryKey)
    KBox.FocusLost:Connect(function(ep) if ep then tryKey() end end)
end

-- ============================================================
--  BUILD MAIN GUI  (split into sub-functions to stay under 200 locals each)
-- ============================================================

-- ---- SUB: LOADING SCREEN ----
local function buildLoadingScreen(onDone)
    local LF=Instance.new("Frame") LF.Size=UDim2.new(1,0,1,0)
    LF.BackgroundColor3=Color3.fromRGB(0,0,0) LF.BackgroundTransparency=0.35
    LF.BorderSizePixel=0 LF.ZIndex=100 LF.Parent=SG

    local LLogo=Instance.new("ImageLabel")
    LLogo.Size=UDim2.new(0,100,0,100) LLogo.AnchorPoint=Vector2.new(0.5,0.5)
    LLogo.Position=UDim2.new(0.5,0,0.34,0) LLogo.BackgroundTransparency=1
    LLogo.Image=LOGO_IMG LLogo.ImageTransparency=0 LLogo.ScaleType=Enum.ScaleType.Fit
    LLogo.Visible=true LLogo.ZIndex=101 LLogo.Parent=LF mkCorner(LLogo,16)
    local LLS=mkStroke(LLogo,2.5,Color3.fromRGB(255,0,0))
    TS:Create(LLogo,TweenInfo.new(0.85,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{
        Size=UDim2.new(0,115,0,115)}):Play()
    local llhue=0
    RS.Heartbeat:Connect(function(dt)
        llhue=(llhue+dt*0.55)%1
        if LLS and LLS.Parent then LLS.Color=Color3.fromHSV(llhue,1,1) end
    end)

    local LTit=Instance.new("TextLabel") LTit.Size=UDim2.new(0,300,0,36)
    LTit.AnchorPoint=Vector2.new(0.5,0.5) LTit.Position=UDim2.new(0.5,0,0.52,0)
    LTit.BackgroundTransparency=1 LTit.Text="RIVALS AIMBOT "..VERSION
    LTit.TextColor3=Color3.fromRGB(255,255,255) LTit.FontFace=FONT_GOTHAM
    LTit.TextSize=22 LTit.ZIndex=101 LTit.Parent=LF gG(LTit)

    local LGreet=Instance.new("TextLabel") LGreet.Size=UDim2.new(0,300,0,20)
    LGreet.AnchorPoint=Vector2.new(0.5,0.5) LGreet.Position=UDim2.new(0.5,0,0.60,0)
    LGreet.BackgroundTransparency=1 LGreet.Text=getGreeting()..", "..LP.DisplayName.."!"
    LGreet.TextColor3=Color3.fromRGB(255,215,60) LGreet.FontFace=FONT_GOTHAM
    LGreet.TextSize=13 LGreet.ZIndex=101 LGreet.Parent=LF

    local LSub=Instance.new("TextLabel") LSub.Size=UDim2.new(0,300,0,18)
    LSub.AnchorPoint=Vector2.new(0.5,0.5) LSub.Position=UDim2.new(0.5,0,0.67,0)
    LSub.BackgroundTransparency=1 LSub.Text="Initializing..."
    LSub.TextColor3=Color3.fromRGB(165,165,165) LSub.FontFace=FONT_GOTHAM
    LSub.TextSize=12 LSub.ZIndex=101 LSub.Parent=LF

    local BBG=Instance.new("Frame") BBG.Size=UDim2.new(0,280,0,6)
    BBG.AnchorPoint=Vector2.new(0.5,0.5) BBG.Position=UDim2.new(0.5,0,0.74,0)
    BBG.BackgroundColor3=Color3.fromRGB(32,32,32) BBG.BackgroundTransparency=0.15
    BBG.BorderSizePixel=0 BBG.ZIndex=101 BBG.Parent=LF mkCorner(BBG,99)
    local BFill=Instance.new("Frame") BFill.Size=UDim2.new(0,0,1,0)
    BFill.BackgroundColor3=Color3.fromRGB(255,200,50) BFill.BorderSizePixel=0
    BFill.ZIndex=102 BFill.Parent=BBG gG(BFill) mkCorner(BFill,99)

    local steps={
        {t="Initializing v5 modules...",    d=0.28},
        {t="Loading ESP & Radar...",         d=0.26},
        {t="Calibrating aimbot...",          d=0.24},
        {t="Setting up hitbox expander...",  d=0.22},
        {t="Building notifications...",      d=0.20},
        {t="Loading visual settings...",     d=0.18},
        {t="Applying saved config...",       d=0.16},
        {t="Finalizing...",                  d=0.14},
        {t="Ready! 🎯",                      d=0.10},
    }
    task.spawn(function()
        for i,s in ipairs(steps) do
            LSub.Text=s.t
            TS:Create(BFill,TweenInfo.new(s.d,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
                Size=UDim2.new(i/#steps,0,1,0)}):Play()
            task.wait(s.d+0.04)
        end
        task.wait(0.3)
        TS:Create(blur,TweenInfo.new(0.6),{Size=0}):Play()
        TS:Create(LF,TweenInfo.new(0.5),{BackgroundTransparency=1}):Play()
        for _,obj in ipairs(LF:GetDescendants()) do
            if obj:IsA("TextLabel") then TS:Create(obj,TweenInfo.new(0.35),{TextTransparency=1}):Play()
            elseif obj:IsA("ImageLabel") then TS:Create(obj,TweenInfo.new(0.35),{ImageTransparency=1,BackgroundTransparency=1}):Play()
            elseif obj:IsA("Frame") then TS:Create(obj,TweenInfo.new(0.35),{BackgroundTransparency=1}):Play() end
        end
        task.wait(0.55)
        if LF and LF.Parent then LF:Destroy() end
        onDone()
    end)
end

-- ---- SUB: MAIN FRAME + TABS ----
local function buildMainFrame()
    local MF=Instance.new("Frame")
    MF.Size=UDim2.new(0,620,0,0) MF.AnchorPoint=Vector2.new(0.5,0.5)
    MF.Position=UDim2.new(0.5,0,0.5,0) MF.BackgroundColor3=Color3.fromRGB(17,17,22)
    MF.BackgroundTransparency=0.05 MF.BorderSizePixel=0 MF.Visible=false MF.ZIndex=10 MF.Parent=SG
    mkCorner(MF,16) mkStroke(MF,1.5,Color3.fromRGB(55,55,65),0.4)
    mkGrad(MF,Color3.fromRGB(24,24,30),Color3.fromRGB(13,13,17),140)

    local BNR=Instance.new("ImageLabel") BNR.Size=UDim2.new(1,0,0,82)
    BNR.BackgroundColor3=Color3.fromRGB(10,10,15) BNR.BackgroundTransparency=0
    BNR.BorderSizePixel=0 BNR.Image=BANNER_IMG BNR.ImageTransparency=0
    BNR.ScaleType=Enum.ScaleType.Crop BNR.ZIndex=11 BNR.Parent=MF mkCorner(BNR,16)
    local bFd=Instance.new("UIGradient")
    bFd.Transparency=NumberSequence.new({
        NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.72,0),NumberSequenceKeypoint.new(1,1)})
    bFd.Rotation=90 bFd.Parent=BNR

    local VBadge=Instance.new("TextLabel") VBadge.Size=UDim2.new(0,85,0,18)
    VBadge.Position=UDim2.new(0,10,0,8) VBadge.BackgroundColor3=Color3.fromRGB(0,0,0)
    VBadge.BackgroundTransparency=0.4 VBadge.BorderSizePixel=0 VBadge.Text=VERSION
    VBadge.TextColor3=Color3.fromRGB(255,215,60) VBadge.FontFace=FONT_GOTHAM
    VBadge.TextSize=7 VBadge.ZIndex=12 VBadge.Parent=BNR mkCorner(VBadge,6)

    -- Banner = drag handle
    BNR.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            isDrag=true dS=inp.Position dF=MF.Position
        end
    end)

    local function closeMF()
        guiOpen=false
        TS:Create(MF,TweenInfo.new(0.26,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{
            Size=UDim2.new(0,620,0,0),BackgroundTransparency=1}):Play()
        task.delay(0.28,function()
            MF.Visible=false MF.Size=UDim2.new(0,620,0,375) MF.BackgroundTransparency=0.05
        end)
    end
    mkCloseBtn(MF,20,closeMF)

    -- Tab bar
    local TB=Instance.new("Frame") TB.Size=UDim2.new(1,-16,0,30)
    TB.Position=UDim2.new(0,8,0,86) TB.BackgroundTransparency=1 TB.ZIndex=12 TB.Parent=MF

    local tabNames={"Home","Aimbot","ESP","Visuals","Settings"}
    local tabBtns={} local tabPages={}

    for i,tn in ipairs(tabNames) do
        local tb=Instance.new("TextButton")
        tb.Size=UDim2.new(0,82,0,28) tb.Position=UDim2.new(0,(i-1)*86,0,0)
        tb.BackgroundColor3=Color3.fromRGB(24,24,32) tb.BackgroundTransparency=0.1
        tb.BorderSizePixel=0 tb.Text=tn tb.TextColor3=Color3.fromRGB(130,130,150)
        tb.FontFace=FONT_GOTHAM tb.TextSize=10 tb.ZIndex=13 tb.Parent=TB mkCorner(tb,8)
        local pg=Instance.new("Frame")
        pg.Size=UDim2.new(1,-16,1,-130) pg.Position=UDim2.new(0,8,0,122)
        pg.BackgroundTransparency=1 pg.Visible=false pg.ZIndex=12 pg.Parent=MF
        tabBtns[tn]=tb tabPages[tn]=pg
    end

    local function switchTab(name)
        for n,pg in pairs(tabPages) do
            pg.Visible=(n==name)
            local bt=tabBtns[n]
            if n==name then
                bt.TextColor3=Color3.fromRGB(255,215,60)
                bt.BackgroundColor3=Color3.fromRGB(35,35,48) bt.BackgroundTransparency=0
            else
                bt.TextColor3=Color3.fromRGB(130,130,150)
                bt.BackgroundColor3=Color3.fromRGB(24,24,32) bt.BackgroundTransparency=0.1
            end
        end
    end
    for tn,bt in pairs(tabBtns) do
        bt.MouseButton1Click:Connect(function() switchTab(tn) end)
        bt.TouchTap:Connect(function() switchTab(tn) end)
    end

    uiRefs.MF=MF uiRefs.tabPages=tabPages uiRefs.switchTab=switchTab
    return MF,tabPages,switchTab
end

-- ---- SUB: HOME TAB ----
local function buildHomeTab(HP)
    local HBnr=Instance.new("ImageLabel") HBnr.Size=UDim2.new(1,0,0,72)
    HBnr.BackgroundColor3=Color3.fromRGB(10,10,15) HBnr.BackgroundTransparency=0
    HBnr.BorderSizePixel=0 HBnr.Image=BANNER_IMG HBnr.ImageTransparency=0
    HBnr.ScaleType=Enum.ScaleType.Crop HBnr.ZIndex=13 HBnr.Parent=HP mkCorner(HBnr,10)

    local HWel=Instance.new("TextLabel") HWel.Size=UDim2.new(1,0,0,22)
    HWel.Position=UDim2.new(0,0,0,78) HWel.BackgroundTransparency=1
    HWel.Text=getGreeting()..", "..LP.DisplayName.."! 👋"
    HWel.TextColor3=Color3.fromRGB(255,255,255) HWel.FontFace=FONT_GOTHAM
    HWel.TextSize=13 HWel.TextXAlignment=Enum.TextXAlignment.Center HWel.ZIndex=13 HWel.Parent=HP gG(HWel)

    local function mkStatCard(parent,icon,label,val,x)
        local f=Instance.new("Frame") f.Size=UDim2.new(0,130,0,50)
        f.Position=UDim2.new(0,x,0,106) f.BackgroundColor3=Color3.fromRGB(22,22,30)
        f.BackgroundTransparency=0.1 f.BorderSizePixel=0 f.ZIndex=13 f.Parent=parent
        mkCorner(f,10) mkStroke(f,1,Color3.fromRGB(50,50,62),0.5)
        local ic=Instance.new("TextLabel") ic.Size=UDim2.new(0,30,1,0)
        ic.BackgroundTransparency=1 ic.Text=icon ic.FontFace=FONT_GOTHAM ic.TextSize=16 ic.ZIndex=14 ic.Parent=f
        local lt=Instance.new("TextLabel") lt.Size=UDim2.new(1,-34,0,16)
        lt.Position=UDim2.new(0,32,0,6) lt.BackgroundTransparency=1 lt.Text=label
        lt.TextColor3=Color3.fromRGB(130,130,150) lt.FontFace=FONT_GOTHAM lt.TextSize=9
        lt.TextXAlignment=Enum.TextXAlignment.Left lt.ZIndex=14 lt.Parent=f
        local vl=Instance.new("TextLabel") vl.Size=UDim2.new(1,-34,0,20)
        vl.Position=UDim2.new(0,32,0,22) vl.BackgroundTransparency=1 vl.Text=val
        vl.TextColor3=Color3.fromRGB(255,255,255) vl.FontFace=FONT_GOTHAM vl.TextSize=12
        vl.TextXAlignment=Enum.TextXAlignment.Left vl.ZIndex=14 vl.Parent=f
        return vl
    end

    local killV = mkStatCard(HP,"🎯","Session Kills","0",0)
    local pingV = mkStatCard(HP,"📡","Ping","—ms",134)
    local fovV  = mkStatCard(HP,"🔵","FOV Radius",tostring(FOV),268)
    local kpmV  = mkStatCard(HP,"⚡","KPM","0.0",402)

    uiRefs.killStatV=killV uiRefs.fovStatV=fovV uiRefs.kpmStatV=kpmV

    RS.Heartbeat:Connect(function()
        local ok,ping=pcall(function() return LP:GetNetworkPing() end)
        if ok then pingV.Text=math.floor(ping*1000).."ms" end
        if fovV and fovV.Parent then fovV.Text=tostring(FOV) end
        local now=os.clock() local recent=0
        for _,t in ipairs(sessionKills) do if now-t<60 then recent=recent+1 end end
        if kpmV and kpmV.Parent then kpmV.Text=tostring(round(recent,1)) end
    end)

    local HDiv=Instance.new("Frame") HDiv.Size=UDim2.new(0.92,0,0,1)
    HDiv.AnchorPoint=Vector2.new(0.5,0) HDiv.Position=UDim2.new(0.5,0,0,164)
    HDiv.BackgroundColor3=Color3.fromRGB(255,255,255) HDiv.BackgroundTransparency=0.82
    HDiv.BorderSizePixel=0 HDiv.ZIndex=13 HDiv.Parent=HP

    local HDiscBtn=Instance.new("TextButton")
    HDiscBtn.Size=UDim2.new(0,220,0,30) HDiscBtn.AnchorPoint=Vector2.new(0.5,0)
    HDiscBtn.Position=UDim2.new(0.5,0,0,172) HDiscBtn.BackgroundColor3=Color3.fromRGB(88,101,242)
    HDiscBtn.BorderSizePixel=0 HDiscBtn.Text="📋  Copy Discord Link"
    HDiscBtn.TextColor3=Color3.fromRGB(255,255,255) HDiscBtn.FontFace=FONT_GOTHAM
    HDiscBtn.TextSize=11 HDiscBtn.ZIndex=13 HDiscBtn.Parent=HP
    mkCorner(HDiscBtn,10) mkGrad(HDiscBtn,Color3.fromRGB(114,137,255),Color3.fromRGB(70,90,200),90)
    HDiscBtn.MouseButton1Click:Connect(function()
        local ok=copyToClipboard(DISCORD_URL)
        HDiscBtn.Text=ok and "✅  Copied!" or "discord.gg/Kxxapq6RWZ"
        TS:Create(HDiscBtn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(45,190,75)}):Play()
        task.delay(1.6,function()
            HDiscBtn.Text="📋  Copy Discord Link"
            TS:Create(HDiscBtn,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(88,101,242)}):Play()
        end)
    end)
    HDiscBtn.TouchTap:Connect(function() HDiscBtn.MouseButton1Click:Fire() end)

    local startTime=os.clock()
    local UptL=Instance.new("TextLabel") UptL.Size=UDim2.new(0,180,0,16)
    UptL.AnchorPoint=Vector2.new(0.5,0) UptL.Position=UDim2.new(0.5,0,0,210)
    UptL.BackgroundTransparency=1 UptL.Text="⏱  Session: 00:00"
    UptL.TextColor3=Color3.fromRGB(90,90,110) UptL.FontFace=FONT_GOTHAM UptL.TextSize=9
    UptL.TextXAlignment=Enum.TextXAlignment.Center UptL.ZIndex=13 UptL.Parent=HP
    RS.Heartbeat:Connect(function()
        if UptL and UptL.Parent then UptL.Text="⏱  Session: "..formatTime(os.clock()-startTime) end
    end)
end

-- ---- SUB: AIMBOT TAB ----
local function buildAimbotTab(AP)
    local _,ap,ak,ad,adt = mkCard(AP,"🎯 AimBot",    0,  0)
    local _,sp,sk,sd,sdt = mkCard(AP,"🔕 Silent Aim",178, 0)
    local _,tp2,tk,td,tdt= mkCard(AP,"🖱️ TriggerBot", 0, 58)
    local _,pp,pk,pd,pdt = mkCard(AP,"🔮 Prediction",178,58)

    pillRefs.aimPill=ap   pillRefs.aimKnob=ak   pillRefs.aimDot=ad   pillRefs.aimDtxt=adt
    pillRefs.siPill=sp    pillRefs.siKnob=sk    pillRefs.siDot=sd    pillRefs.siDtxt=sdt
    pillRefs.tbPill=tp2   pillRefs.tbKnob=tk    pillRefs.tbDot=td    pillRefs.tbDtxt=tdt
    pillRefs.pcPill=pp    pillRefs.pcKnob=pk    pillRefs.pcDot=pd    pillRefs.pcDtxt=pdt

    local fovBox, fovBtn     = mkInput(AP,"FOV Radius",    FOV,   500,  0,120)
    local smBox,  smBtn      = mkInput(AP,"Aim Smoothness",SMOOTH, 30,178,120)
    local predBox,predBtn    = mkInput(AP,"Prediction",    PRED,    1,  0,192)
    local trigBox,trigBtn    = mkInput(AP,"Trigger Delay", TRIG_DELAY,5,178,192)

    uiRefs.fovBox=fovBox uiRefs.fovBtn=fovBtn
    uiRefs.smBox=smBox   uiRefs.smBtn=smBtn
    uiRefs.predBox=predBox uiRefs.predBtn=predBtn
    uiRefs.trigBox=trigBox uiRefs.trigBtn=trigBtn

    -- Bone selector
    local bones={"UpperTorso","HumanoidRootPart","Head","LowerTorso"}
    local boneBtns={}
    for i,bn in ipairs(bones) do
        local bb=Instance.new("TextButton")
        bb.Size=UDim2.new(0,85,0,22) bb.Position=UDim2.new(0,(i-1)*89,0,90)
        bb.BackgroundColor3=(bn==AIM_BONE) and Color3.fromRGB(42,95,210) or Color3.fromRGB(30,30,40)
        bb.BorderSizePixel=0 bb.Text=bn:sub(1,9)
        bb.TextColor3=Color3.fromRGB(200,200,220) bb.FontFace=FONT_GOTHAM
        bb.TextSize=8 bb.ZIndex=13 bb.Parent=AP mkCorner(bb,6)
        boneBtns[bn]=bb
        bb.MouseButton1Click:Connect(function()
            AIM_BONE=bn saveData.aimBone=bn writeSave()
            for _,b2 in pairs(boneBtns) do
                TS:Create(b2,TweenInfo.new(0.15),{
                    BackgroundColor3=(b2==bb) and Color3.fromRGB(42,95,210) or Color3.fromRGB(30,30,40)
                }):Play()
            end
        end)
        bb.TouchTap:Connect(function() bb.MouseButton1Click:Fire() end)
    end
    uiRefs.boneBtns=boneBtns

    local AimStat=Instance.new("TextLabel") AimStat.Size=UDim2.new(1,0,0,14)
    AimStat.Position=UDim2.new(0,0,1,-18) AimStat.BackgroundTransparency=1
    AimStat.Text="STATUS: DISABLED" AimStat.TextColor3=Color3.fromRGB(110,110,125)
    AimStat.FontFace=FONT_GOTHAM AimStat.TextSize=9
    AimStat.TextXAlignment=Enum.TextXAlignment.Center AimStat.ZIndex=13 AimStat.Parent=AP
    uiRefs.AimStat=AimStat
end

-- ---- SUB: ESP TAB ----
local function buildESPTab(EP)
    local _,e1p,e1k,e1d,e1t = mkCard(EP,"👀 ESP Player",   0,  0)
    local _,e2p,e2k,e2d,e2t = mkCard(EP,"🛠️ Hitbox Size", 178,  0)
    local _,e3p,e3k,e3d,e3t = mkCard(EP,"🏷️ ESP Names",    0, 58)
    local _,e4p,e4k,e4d,e4t = mkCard(EP,"❤️ ESP Health",  178, 58)
    local _,e5p,e5k,e5d,e5t = mkCard(EP,"📦 ESP Boxes",    0,116)
    local _,e6p,e6k,e6d,e6t = mkCard(EP,"📍 Tracers",     178,116)
    local _,e7p,e7k,e7d,e7t = mkCard(EP,"🚀 Teleport",     0,174)
    local _,e8p,e8k,e8d,e8t = mkCard(EP,"🧱 Wall Check",  178,174)
    local _,e9p,e9k,e9d,e9t = mkCard(EP,"💀 Skeleton",     0,232)

    pillRefs.espPill=e1p   pillRefs.espKnob=e1k  pillRefs.espDot=e1d  pillRefs.espDtxt=e1t
    pillRefs.hbPill=e2p    pillRefs.hbKnob=e2k   pillRefs.hbDot=e2d   pillRefs.hbDtxt=e2t
    pillRefs.enPill=e3p    pillRefs.enKnob=e3k   pillRefs.enDot=e3d   pillRefs.enDtxt=e3t
    pillRefs.ehPill=e4p    pillRefs.ehKnob=e4k   pillRefs.ehDot=e4d   pillRefs.ehDtxt=e4t
    pillRefs.ebPill=e5p    pillRefs.ebKnob=e5k   pillRefs.ebDot=e5d   pillRefs.ebDtxt=e5t
    pillRefs.trPill=e6p    pillRefs.trKnob=e6k   pillRefs.trDot=e6d   pillRefs.trDtxt=e6t
    pillRefs.tpPill=e7p    pillRefs.tpKnob=e7k   pillRefs.tpDot=e7d   pillRefs.tpDtxt=e7t
    pillRefs.wcPill=e8p    pillRefs.wcKnob=e8k   pillRefs.wcDot=e8d   pillRefs.wcDtxt=e8t
    pillRefs.skPill=e9p    pillRefs.skKnob=e9k   pillRefs.skDot=e9d   pillRefs.skDtxt=e9t

    local hbBox,hbBtn=mkInput(EP,"Hitbox Size",HBS,250,0,290)
    uiRefs.hbBox=hbBox uiRefs.hbBtn=hbBtn
end

-- ---- SUB: VISUALS TAB ----
local function buildVisualsTab(VP)
    local _,v1p,v1k,v1d,v1t = mkCard(VP,"➕ Crosshair",    0,  0)
    local _,v2p,v2k,v2d,v2t = mkCard(VP,"🌙 Dark Ambient",178,  0)
    local _,v3p,v3k,v3d,v3t = mkCard(VP,"🏃 Speed Boost",  0, 58)
    local _,v4p,v4k,v4d,v4t = mkCard(VP,"🔭 Mini Radar",  178, 58)
    local _,v5p,v5k,v5d,v5t = mkCard(VP,"👥 Team Check",   0,116)
    local _,v6p,v6k,v6d,v6t = mkCard(VP,"🎭 Chams",       178,116)

    pillRefs.crPill=v1p    pillRefs.crKnob=v1k   pillRefs.crDot=v1d   pillRefs.crDtxt=v1t
    pillRefs.ambPill=v2p   pillRefs.ambKnob=v2k  pillRefs.ambDot=v2d  pillRefs.ambDtxt=v2t
    pillRefs.spPill=v3p    pillRefs.spKnob=v3k   pillRefs.spDot=v3d   pillRefs.spDtxt=v3t
    pillRefs.radPill=v4p   pillRefs.radKnob=v4k  pillRefs.radDot=v4d  pillRefs.radDtxt=v4t
    pillRefs.tcPill=v5p    pillRefs.tcKnob=v5k   pillRefs.tcDot=v5d   pillRefs.tcDtxt=v5t
    pillRefs.chPill=v6p    pillRefs.chKnob=v6k   pillRefs.chDot=v6d   pillRefs.chDtxt=v6t

    -- Theme buttons
    local ThemeLbl=Instance.new("TextLabel") ThemeLbl.Size=UDim2.new(1,0,0,14)
    ThemeLbl.Position=UDim2.new(0,0,0,174) ThemeLbl.BackgroundTransparency=1
    ThemeLbl.Text="🎨  Accent Theme" ThemeLbl.TextColor3=Color3.fromRGB(160,160,180)
    ThemeLbl.FontFace=FONT_GOTHAM ThemeLbl.TextSize=10 ThemeLbl.ZIndex=13 ThemeLbl.Parent=VP

    local thOrder={"Red","Blue","Green","Purple","Gold","Cyan","Pink","Orange"}
    local thColors={
        Red=Color3.fromRGB(215,38,38),Blue=Color3.fromRGB(42,95,210),
        Green=Color3.fromRGB(38,155,85),Purple=Color3.fromRGB(130,50,210),
        Gold=Color3.fromRGB(200,160,0),Cyan=Color3.fromRGB(0,170,200),
        Pink=Color3.fromRGB(210,60,140),Orange=Color3.fromRGB(210,100,20),
    }
    local thBtns={}
    for i,tn in ipairs(thOrder) do
        local tb=Instance.new("TextButton")
        tb.Size=UDim2.new(0,66,0,26) tb.Position=UDim2.new(0,(i-1)*70,0,190)
        tb.BackgroundColor3=thColors[tn] tb.BorderSizePixel=0 tb.Text=tn
        tb.TextColor3=Color3.fromRGB(255,255,255) tb.FontFace=FONT_GOTHAM
        tb.TextSize=8 tb.ZIndex=13 tb.Parent=VP mkCorner(tb,8)
        if saveData.theme==tn then mkStroke(tb,2.5,Color3.fromRGB(255,255,255),0) end
        thBtns[tn]=tb
        tb.MouseButton1Click:Connect(function()
            saveData.theme=tn writeSave()
            showNotif("🎨 Theme","Switched to "..tn,thColors[tn])
            if espOn then disESP() enESP() end
            for _,b2 in pairs(thBtns) do
                local ex=b2:FindFirstChildOfClass("UIStroke") if ex then ex:Destroy() end
                if b2.Text==tn then mkStroke(b2,2.5,Color3.fromRGB(255,255,255),0) end
            end
        end)
        tb.TouchTap:Connect(function() tb.MouseButton1Click:Fire() end)
    end
end

-- ---- SUB: SETTINGS TAB ----
local function buildSettingsTab(SP2)
    local _,s1p,s1k,s1d,s1t = mkCard(SP2,"💾 Auto Save",    0,  0)
    local _,s2p,s2k,s2d,s2t = mkCard(SP2,"🔔 Notifications",178,  0)
    local _,s3p,s3k,s3d,s3t = mkCard(SP2,"👁️ Vis Check",    0, 58)
    local _,s4p,s4k,s4d,s4t = mkCard(SP2,"🚶 No-Clip",      178, 58)
    local _,s5p,s5k,s5d,s5t = mkCard(SP2,"🦅 Inf Jump",     0,116)
    local _,s6p,s6k,s6d,s6t = mkCard(SP2,"☀️ Fullbright",  178,116)
    local _,s7p,s7k,s7d,s7t = mkCard(SP2,"💤 Anti-AFK",     0,174)

    pillRefs.asPill=s1p   pillRefs.asKnob=s1k  pillRefs.asDot=s1d  pillRefs.asDtxt=s1t
    pillRefs.ntPill=s2p   pillRefs.ntKnob=s2k  pillRefs.ntDot=s2d  pillRefs.ntDtxt=s2t
    pillRefs.viPill=s3p   pillRefs.viKnob=s3k  pillRefs.viDot=s3d  pillRefs.viDtxt=s3t
    pillRefs.ncPill=s4p   pillRefs.ncKnob=s4k  pillRefs.ncDot=s4d  pillRefs.ncDtxt=s4t
    pillRefs.ijPill=s5p   pillRefs.ijKnob=s5k  pillRefs.ijDot=s5d  pillRefs.ijDtxt=s5t
    pillRefs.fbPill=s6p   pillRefs.fbKnob=s6k  pillRefs.fbDot=s6d  pillRefs.fbDtxt=s6t
    pillRefs.afkPill=s7p  pillRefs.afkKnob=s7k pillRefs.afkDot=s7d pillRefs.afkDtxt=s7t

    local hint=Instance.new("TextLabel") hint.Size=UDim2.new(1,0,0,26)
    hint.Position=UDim2.new(0,0,0,232) hint.BackgroundTransparency=1
    hint.Text="⌨️  RightShift=GUI  Tab=Cycle  F=HeadLock  G=Skeleton  H=Chams  Del=ClearESP"
    hint.TextColor3=Color3.fromRGB(75,75,95) hint.FontFace=FONT_GOTHAM hint.TextSize=8
    hint.TextXAlignment=Enum.TextXAlignment.Left hint.TextWrapped=true hint.ZIndex=13 hint.Parent=SP2

    local credit=Instance.new("TextLabel") credit.Size=UDim2.new(1,0,0,12)
    credit.Position=UDim2.new(0,0,1,-16) credit.BackgroundTransparency=1
    credit.Text="Rivals AimBot "..VERSION.."  |  client-side only"
    credit.TextColor3=Color3.fromRGB(45,45,60) credit.FontFace=FONT_GOTHAM credit.TextSize=8
    credit.TextXAlignment=Enum.TextXAlignment.Center credit.ZIndex=13 credit.Parent=SP2
end

-- ---- SUB: HUD OVERLAYS ----
local function buildHUD()
    -- FOV circle
    local FC=Instance.new("Frame") FC.Size=UDim2.new(0,FOV*2,0,FOV*2)
    FC.AnchorPoint=Vector2.new(0.5,0.5) FC.Position=UDim2.new(0.5,0,0.5,0)
    FC.BackgroundTransparency=1 FC.BorderSizePixel=0 FC.Visible=false FC.ZIndex=10 FC.Parent=SG
    mkCorner(FC,99)
    local FCS=mkStroke(FC,1.8,Color3.fromRGB(255,55,55),0.1)
    uiRefs.FC=FC uiRefs.FCS=FCS

    -- Crosshair
    local CRF=Instance.new("Frame") CRF.Size=UDim2.new(0,22,0,22)
    CRF.AnchorPoint=Vector2.new(0.5,0.5) CRF.Position=UDim2.new(0.5,0,0.5,0)
    CRF.BackgroundTransparency=1 CRF.Visible=crOn CRF.ZIndex=20 CRF.Parent=SG
    local crH=Instance.new("Frame") crH.Size=UDim2.new(1,0,0,1.5)
    crH.AnchorPoint=Vector2.new(0.5,0.5) crH.Position=UDim2.new(0.5,0,0.5,0)
    crH.BackgroundColor3=Color3.fromRGB(255,255,255) crH.BorderSizePixel=0 crH.ZIndex=21 crH.Parent=CRF mkCorner(crH,99)
    local crV=Instance.new("Frame") crV.Size=UDim2.new(0,1.5,1,0)
    crV.AnchorPoint=Vector2.new(0.5,0.5) crV.Position=UDim2.new(0.5,0,0.5,0)
    crV.BackgroundColor3=Color3.fromRGB(255,255,255) crV.BorderSizePixel=0 crV.ZIndex=21 crV.Parent=CRF mkCorner(crV,99)
    local crDot=Instance.new("Frame") crDot.Size=UDim2.new(0,3,0,3)
    crDot.AnchorPoint=Vector2.new(0.5,0.5) crDot.Position=UDim2.new(0.5,0,0.5,0)
    crDot.BackgroundColor3=Color3.fromRGB(255,50,50) crDot.BorderSizePixel=0 crDot.ZIndex=22 crDot.Parent=CRF mkCorner(crDot,99)
    uiRefs.CRF=CRF

    -- Speed HUD
    local SHUD=Instance.new("Frame") SHUD.Size=UDim2.new(0,100,0,26)
    SHUD.AnchorPoint=Vector2.new(0.5,1) SHUD.Position=UDim2.new(0.5,0,1,-46)
    SHUD.BackgroundColor3=Color3.fromRGB(14,14,20) SHUD.BackgroundTransparency=0.2
    SHUD.BorderSizePixel=0 SHUD.Visible=true SHUD.ZIndex=35 SHUD.Parent=SG
    mkCorner(SHUD,8) mkStroke(SHUD,1,Color3.fromRGB(50,50,65),0.4)
    local SLbl=Instance.new("TextLabel") SLbl.Size=UDim2.new(1,0,1,0)
    SLbl.BackgroundTransparency=1 SLbl.Text="⚡ 0 s/s" SLbl.TextColor3=Color3.fromRGB(200,200,220)
    SLbl.FontFace=FONT_GOTHAM SLbl.TextSize=9 SLbl.TextXAlignment=Enum.TextXAlignment.Center
    SLbl.ZIndex=36 SLbl.Parent=SHUD

    -- Health bar
    local HHUD=Instance.new("Frame") HHUD.Size=UDim2.new(0,140,0,14)
    HHUD.AnchorPoint=Vector2.new(0.5,1) HHUD.Position=UDim2.new(0.5,0,1,-20)
    HHUD.BackgroundColor3=Color3.fromRGB(30,30,30) HHUD.BackgroundTransparency=0.2
    HHUD.BorderSizePixel=0 HHUD.Visible=true HHUD.ZIndex=35 HHUD.Parent=SG mkCorner(HHUD,4)
    local HFill=Instance.new("Frame") HFill.Size=UDim2.new(1,0,1,0)
    HFill.BackgroundColor3=Color3.fromRGB(80,220,80) HFill.BorderSizePixel=0 HFill.ZIndex=36 HFill.Parent=HHUD mkCorner(HFill,4)
    local HLbl=Instance.new("TextLabel") HLbl.Size=UDim2.new(1,0,1,0)
    HLbl.BackgroundTransparency=1 HLbl.Text="100/100" HLbl.TextColor3=Color3.fromRGB(255,255,255)
    HLbl.FontFace=FONT_GOTHAM HLbl.TextSize=8 HLbl.TextXAlignment=Enum.TextXAlignment.Center HLbl.ZIndex=37 HLbl.Parent=HHUD

    -- Mini radar
    local RadF=Instance.new("Frame") RadF.Size=UDim2.new(0,185,0,185)
    RadF.Position=UDim2.new(1,-200,1,-200) RadF.BackgroundColor3=Color3.fromRGB(10,12,16)
    RadF.BackgroundTransparency=0.15 RadF.BorderSizePixel=0 RadF.Visible=false RadF.ZIndex=30 RadF.Parent=SG
    mkCorner(RadF,8) mkStroke(RadF,1.5,Color3.fromRGB(50,50,65),0.2)
    for _,pct in ipairs({0.25,0.5,0.75}) do
        local gh=Instance.new("Frame") gh.Size=UDim2.new(1,0,0,1) gh.Position=UDim2.new(0,0,pct,0)
        gh.BackgroundColor3=Color3.fromRGB(50,55,65) gh.BackgroundTransparency=0.5 gh.BorderSizePixel=0 gh.ZIndex=31 gh.Parent=RadF
        local gv=Instance.new("Frame") gv.Size=UDim2.new(0,1,1,0) gv.Position=UDim2.new(pct,0,0,0)
        gv.BackgroundColor3=Color3.fromRGB(50,55,65) gv.BackgroundTransparency=0.5 gv.BorderSizePixel=0 gv.ZIndex=31 gv.Parent=RadF
    end
    local RadC=Instance.new("Frame") RadC.Size=UDim2.new(0,6,0,6) RadC.AnchorPoint=Vector2.new(0.5,0.5)
    RadC.Position=UDim2.new(0.5,0,0.5,0) RadC.BackgroundColor3=Color3.fromRGB(100,200,255)
    RadC.BorderSizePixel=0 RadC.ZIndex=33 RadC.Parent=RadF mkCorner(RadC,99)
    uiRefs.RadF=RadF

    -- Per-frame HUD updates
    local prevHRP,prevHRPT=nil,nil
    local radarDots={}
    RS.Heartbeat:Connect(function()
        -- speed
        local c=LP.Character if c then
            local hrp=c:FindFirstChild("HumanoidRootPart")
            if hrp then
                local now=os.clock()
                if prevHRP and prevHRPT then
                    local dt2=now-prevHRPT
                    if dt2>0 then
                        local spd=(hrp.Position-prevHRP).Magnitude/dt2
                        if SLbl and SLbl.Parent then SLbl.Text=string.format("⚡ %.1f s/s",spd) end
                    end
                end
                prevHRP=hrp.Position prevHRPT=os.clock()
            end
            -- health
            local hum=c:FindFirstChildOfClass("Humanoid")
            if hum then
                local pct=clamp(hum.Health/hum.MaxHealth,0,1)
                if HFill and HFill.Parent then
                    HFill.Size=UDim2.new(pct,0,1,0)
                    HFill.BackgroundColor3=Color3.fromHSV(pct*0.33,0.9,0.9)
                end
                if HLbl and HLbl.Parent then
                    HLbl.Text=string.format("%d/%d",math.floor(hum.Health),math.floor(hum.MaxHealth))
                end
            end
        end
        -- radar
        if radarOn and c then
            for _,d in pairs(radarDots) do if d and d.Parent then d:Destroy() end end
            radarDots={}
            local hrpSelf=c:FindFirstChild("HumanoidRootPart")
            if hrpSelf then
                local tc=getTheme()
                local range=saveData.radarRange or 150
                for _,p in ipairs(PL:GetPlayers()) do
                    if p==LP then continue end
                    local pc=p.Character if not pc then continue end
                    local hrp2=pc:FindFirstChild("HumanoidRootPart") if not hrp2 then continue end
                    local rel=hrpSelf.CFrame:ToObjectSpace(hrp2.CFrame)
                    local rx=clamp(rel.X/range,-1,1) local rz=clamp(rel.Z/range,-1,1)
                    local dot=Instance.new("Frame") dot.Size=UDim2.new(0,7,0,7)
                    dot.AnchorPoint=Vector2.new(0.5,0.5) dot.Position=UDim2.new(0.5+rx*0.45,0,0.5+rz*0.45,0)
                    dot.BackgroundColor3=tc[1] dot.BorderSizePixel=0 dot.ZIndex=32 dot.Parent=RadF mkCorner(dot,99)
                    table.insert(radarDots,dot)
                end
            end
        end
        -- tracers
        if tracersOn then updateTracers() end
    end)
end

-- ---- SUB: FEATURE SETTERS ----
local function buildFeatureSetters()
    local function flashBtn(btn)
        TS:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(45,190,75)}):Play()
        task.delay(0.38,function() TS:Create(btn,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(42,95,210)}):Play() end)
    end

    local function setAim(s)
        aimOn=s
        local FC=uiRefs.FC local FCS=uiRefs.FCS
        if FC then FC.Visible=s end
        local tc=getTheme() if FCS then FCS.Color=tc[1] end
        animT(pillRefs.aimPill,pillRefs.aimKnob,pillRefs.aimDot,pillRefs.aimDtxt,s,tc[1],"LOCKING")
        if s then
            CAM.CameraType=Enum.CameraType.Custom
            local st=uiRefs.AimStat if st then st.Text="STATUS: SEARCHING..." st.TextColor3=Color3.fromRGB(215,150,40) end
            showNotif("🎯 AimBot","Aimbot enabled — FOV "..FOV,tc[1])
        else
            locked=nil
            local st=uiRefs.AimStat if st then st.Text="STATUS: DISABLED" st.TextColor3=Color3.fromRGB(110,110,125) end
            showNotif("🎯 AimBot","Aimbot disabled",Color3.fromRGB(90,90,105))
        end
    end
    local function setESP(s)
        espOn=s local tc=getTheme()
        animT(pillRefs.espPill,pillRefs.espKnob,pillRefs.espDot,pillRefs.espDtxt,s,tc[1],"ACTIVE")
        if s then enESP() showNotif("👀 ESP","ESP enabled",tc[1])
        else disESP() showNotif("👀 ESP","ESP disabled",Color3.fromRGB(90,90,105)) end
    end
    local function setTP(s)
        tpOn=s
        animT(pillRefs.tpPill,pillRefs.tpKnob,pillRefs.tpDot,pillRefs.tpDtxt,s,Color3.fromRGB(50,105,225),"ACTIVE")
        if s then
            doTP()
            task.spawn(function() while tpOn do doTP() task.wait(0.5) end end)
            showNotif("🚀 Teleport","Teleporting to mark",Color3.fromRGB(50,105,225))
        end
    end
    local function setHB(s)
        local v=tonumber(uiRefs.hbBox and uiRefs.hbBox.Text)
        if v then HBS=clamp(math.floor(v),1,250) if uiRefs.hbBox then uiRefs.hbBox.Text=tostring(HBS) end saveData.hbs=HBS writeSave() end
        hbOn=s
        animT(pillRefs.hbPill,pillRefs.hbKnob,pillRefs.hbDot,pillRefs.hbDtxt,s,Color3.fromRGB(172,72,215),"ACTIVE")
        if s then enHB() showNotif("🛠️ Hitbox","Hitbox "..HBS,Color3.fromRGB(172,72,215))
        else disHB() end
    end

    -- wire all pills
    local pillActions = {
        {pillRefs.aimPill,   function() setAim(not aimOn) end},
        {pillRefs.siPill,    function()
            silentAim=not silentAim
            animT(pillRefs.siPill,pillRefs.siKnob,pillRefs.siDot,pillRefs.siDtxt,silentAim,Color3.fromRGB(180,80,220),"ON")
            if silentAim then showNotif("🔕 Silent","Silent aim ON",Color3.fromRGB(180,80,220)) end
        end},
        {pillRefs.tbPill,    function()
            trigBot=not trigBot
            animT(pillRefs.tbPill,pillRefs.tbKnob,pillRefs.tbDot,pillRefs.tbDtxt,trigBot,Color3.fromRGB(215,80,180),"ON")
            if trigBot then showNotif("🖱️ TriggerBot","TriggerBot ON",Color3.fromRGB(215,80,180)) end
        end},
        {pillRefs.pcPill,    function()
            local on2=not (PRED>0) PRED=on2 and 0.35 or 0 saveData.predStrength=PRED writeSave()
            animT(pillRefs.pcPill,pillRefs.pcKnob,pillRefs.pcDot,pillRefs.pcDtxt,on2,Color3.fromRGB(60,160,240),"ON")
        end},
        {pillRefs.espPill,   function() setESP(not espOn) end},
        {pillRefs.hbPill,    function() setHB(not hbOn) end},
        {pillRefs.enPill,    function()
            espNamesOn=not espNamesOn saveData.espNames=espNamesOn writeSave()
            animT(pillRefs.enPill,pillRefs.enKnob,pillRefs.enDot,pillRefs.enDtxt,espNamesOn,Color3.fromRGB(60,180,120),"ON")
            if espOn then disESP() enESP() end
        end},
        {pillRefs.ehPill,    function()
            espHealthOn=not espHealthOn saveData.espHealth=espHealthOn writeSave()
            animT(pillRefs.ehPill,pillRefs.ehKnob,pillRefs.ehDot,pillRefs.ehDtxt,espHealthOn,Color3.fromRGB(220,60,60),"ON")
            if espOn then disESP() enESP() end
        end},
        {pillRefs.ebPill,    function()
            espBoxesOn=not espBoxesOn saveData.espBoxes=espBoxesOn writeSave()
            animT(pillRefs.ebPill,pillRefs.ebKnob,pillRefs.ebDot,pillRefs.ebDtxt,espBoxesOn,Color3.fromRGB(42,95,210),"ON")
            if espOn then disESP() enESP() end
        end},
        {pillRefs.trPill,    function()
            tracersOn=not tracersOn saveData.tracers=tracersOn writeSave()
            animT(pillRefs.trPill,pillRefs.trKnob,pillRefs.trDot,pillRefs.trDtxt,tracersOn,Color3.fromRGB(255,160,30),"ON")
            if not tracersOn then updateTracers() end
        end},
        {pillRefs.tpPill,    function() setTP(not tpOn) end},
        {pillRefs.wcPill,    function()
            wallChk=not wallChk saveData.wallCheck=wallChk writeSave()
            animT(pillRefs.wcPill,pillRefs.wcKnob,pillRefs.wcDot,pillRefs.wcDtxt,wallChk,Color3.fromRGB(100,80,200),"ON")
        end},
        {pillRefs.skPill,    function()
            skelOn=not skelOn
            animT(pillRefs.skPill,pillRefs.skKnob,pillRefs.skDot,pillRefs.skDtxt,skelOn,Color3.fromRGB(200,80,80),"ON")
            if skelOn then showNotif("💀 Skeleton","Skeleton ESP ON",Color3.fromRGB(200,80,80)) end
        end},
        {pillRefs.crPill,    function()
            crOn=not crOn saveData.crosshair=crOn writeSave()
            if uiRefs.CRF then uiRefs.CRF.Visible=crOn end
            animT(pillRefs.crPill,pillRefs.crKnob,pillRefs.crDot,pillRefs.crDtxt,crOn,Color3.fromRGB(42,95,210),"ON")
        end},
        {pillRefs.ambPill,   function()
            ambOn=not ambOn
            animT(pillRefs.ambPill,pillRefs.ambKnob,pillRefs.ambDot,pillRefs.ambDtxt,ambOn,Color3.fromRGB(80,60,180),"ON")
            if ambOn then
                TS:Create(Lighting,TweenInfo.new(1),{Ambient=Color3.fromRGB(0,0,0),OutdoorAmbient=Color3.fromRGB(10,10,20)}):Play()
                showNotif("🌙 Ambient","Darkened for visibility",Color3.fromRGB(80,60,180))
            else
                TS:Create(Lighting,TweenInfo.new(1),{Ambient=origAmb,OutdoorAmbient=origOutAmb}):Play()
            end
        end},
        {pillRefs.spPill,    function()
            speedOn=not speedOn
            animT(pillRefs.spPill,pillRefs.spKnob,pillRefs.spDot,pillRefs.spDtxt,speedOn,Color3.fromRGB(50,200,120),"ON")
            local c=LP.Character
            if c then local hum=c:FindFirstChildOfClass("Humanoid") if hum then
                if speedOn then origWS=hum.WalkSpeed hum.WalkSpeed=30
                    showNotif("🏃 Speed","WalkSpeed → 30",Color3.fromRGB(50,200,120))
                else hum.WalkSpeed=origWS or 16 end
            end end
        end},
        {pillRefs.radPill,   function()
            radarOn=not radarOn saveData.radarEnabled=radarOn writeSave()
            if uiRefs.RadF then uiRefs.RadF.Visible=radarOn end
            animT(pillRefs.radPill,pillRefs.radKnob,pillRefs.radDot,pillRefs.radDtxt,radarOn,Color3.fromRGB(0,170,200),"ON")
            if radarOn then showNotif("🔭 Radar","Mini radar ON",Color3.fromRGB(0,170,200)) end
        end},
        {pillRefs.tcPill,    function()
            teamChk=not teamChk saveData.teamCheck=teamChk writeSave()
            animT(pillRefs.tcPill,pillRefs.tcKnob,pillRefs.tcDot,pillRefs.tcDtxt,teamChk,Color3.fromRGB(255,200,30),"ON")
        end},
        {pillRefs.chPill,    function()
            chamsOn=not chamsOn
            animT(pillRefs.chPill,pillRefs.chKnob,pillRefs.chDot,pillRefs.chDtxt,chamsOn,Color3.fromRGB(180,80,220),"ON")
            if chamsOn then enChams() showNotif("🎭 Chams","Chams ON",Color3.fromRGB(180,80,220))
            else disChams() end
        end},
        {pillRefs.asPill,    function()
            saveData.autoSave=not saveData.autoSave writeSave()
            animT(pillRefs.asPill,pillRefs.asKnob,pillRefs.asDot,pillRefs.asDtxt,saveData.autoSave,Color3.fromRGB(38,155,85),"ON")
            showNotif("💾 Save",saveData.autoSave and "Auto save ON" or "Auto save OFF",saveData.autoSave and Color3.fromRGB(38,155,85) or Color3.fromRGB(215,38,38))
        end},
        {pillRefs.ntPill,    function()
            saveData.notifications=not saveData.notifications writeSave()
            animT(pillRefs.ntPill,pillRefs.ntKnob,pillRefs.ntDot,pillRefs.ntDtxt,saveData.notifications,Color3.fromRGB(38,155,85),"ON")
        end},
        {pillRefs.viPill,    function()
            visChk=not visChk saveData.visCheck=visChk writeSave()
            animT(pillRefs.viPill,pillRefs.viKnob,pillRefs.viDot,pillRefs.viDtxt,visChk,Color3.fromRGB(100,200,100),"ON")
        end},
        {pillRefs.ncPill,    function()
            setNoclip(not noclipOn)
            animT(pillRefs.ncPill,pillRefs.ncKnob,pillRefs.ncDot,pillRefs.ncDtxt,noclipOn,Color3.fromRGB(100,80,200),"ON")
            showNotif("🚶 No-Clip",noclipOn and "No-Clip ON" or "No-Clip OFF",Color3.fromRGB(100,80,200))
        end},
        {pillRefs.ijPill,    function()
            setInfJump(not infJumpOn)
            animT(pillRefs.ijPill,pillRefs.ijKnob,pillRefs.ijDot,pillRefs.ijDtxt,infJumpOn,Color3.fromRGB(60,160,240),"ON")
        end},
        {pillRefs.fbPill,    function()
            setFullbright(not fullbrightOn)
            animT(pillRefs.fbPill,pillRefs.fbKnob,pillRefs.fbDot,pillRefs.fbDtxt,fullbrightOn,Color3.fromRGB(255,200,30),"ON")
        end},
        {pillRefs.afkPill,   function()
            setAntiAfk(not antiAfkOn)
            animT(pillRefs.afkPill,pillRefs.afkKnob,pillRefs.afkDot,pillRefs.afkDtxt,antiAfkOn,Color3.fromRGB(100,200,100),"ON")
        end},
    }

    for _,t in ipairs(pillActions) do
        if t[1] then
            t[1].InputBegan:Connect(function(inp)
                if inp.UserInputType==Enum.UserInputType.MouseButton1
                or inp.UserInputType==Enum.UserInputType.Touch then t[2]() end
            end)
        end
    end

    -- Input apply buttons
    local function wireInput(box,btn,getter,setter,mn,mx,key)
        btn.MouseButton1Click:Connect(function()
            local v=tonumber(box.Text) if not v then return end
            local cv=clamp(key=="float" and v or math.floor(v),mn,mx)
            box.Text=tostring(cv) setter(cv)
            flashBtn(btn)
        end)
        btn.TouchTap:Connect(function() btn.MouseButton1Click:Fire() end)
        box.FocusLost:Connect(function()
            local v=tonumber(box.Text)
            if not v then box.Text=tostring(getter()) return end
            local cv=clamp(key=="float" and v or math.floor(v),mn,mx)
            box.Text=tostring(cv) setter(cv)
        end)
    end

    wireInput(uiRefs.fovBox,uiRefs.fovBtn,
        function() return FOV end,
        function(v) FOV=v if uiRefs.FC then uiRefs.FC.Size=UDim2.new(0,FOV*2,0,FOV*2) end saveData.fov=v writeSave() end,
        10,500)
    wireInput(uiRefs.smBox,uiRefs.smBtn,
        function() return SMOOTH end,
        function(v) SMOOTH=v saveData.aimSmooth=v writeSave() end,
        1,30)
    wireInput(uiRefs.predBox,uiRefs.predBtn,
        function() return PRED end,
        function(v) PRED=v saveData.predStrength=v writeSave() end,
        0,1,"float")
    wireInput(uiRefs.trigBox,uiRefs.trigBtn,
        function() return TRIG_DELAY end,
        function(v) TRIG_DELAY=v saveData.triggerDelay=v writeSave() end,
        0,5,"float")
    wireInput(uiRefs.hbBox,uiRefs.hbBtn,
        function() return HBS end,
        function(v) HBS=v saveData.hbs=v writeSave() if hbOn then disHB() enHB() end end,
        1,250)

    -- init from saveData
    if uiRefs.CRF then uiRefs.CRF.Visible=crOn end
    animT(pillRefs.asPill,pillRefs.asKnob,pillRefs.asDot,pillRefs.asDtxt,saveData.autoSave,Color3.fromRGB(38,155,85),"ON")
    animT(pillRefs.ntPill,pillRefs.ntKnob,pillRefs.ntDot,pillRefs.ntDtxt,saveData.notifications,Color3.fromRGB(38,155,85),"ON")
    animT(pillRefs.crPill,pillRefs.crKnob,pillRefs.crDot,pillRefs.crDtxt,crOn,Color3.fromRGB(42,95,210),"ON")
end

-- ---- SUB: AIMBOT RENDER LOOP ----
local function buildAimbotLoop()
    local FC=uiRefs.FC local FCS=uiRefs.FCS
    local trigCD=false
    local chamHue=0

    CAM:GetPropertyChangedSignal("CameraType"):Connect(function()
        if aimOn and CAM.CameraType==Enum.CameraType.Scriptable then
            CAM.CameraType=Enum.CameraType.Custom
        end
    end)
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        CAM=workspace.CurrentCamera
    end)

    RS.RenderStepped:Connect(function(dt)
        -- chams cycling
        chamHue=(chamHue+dt*0.3)%1
        if chamsOn then
            local col=Color3.fromHSV(chamHue,0.9,1)
            for _,hl in pairs(chamsT) do
                if hl and hl.Parent then
                    hl.FillColor=col hl.OutlineColor=Color3.fromHSV((chamHue+0.5)%1,0.7,1)
                end
            end
        end

        if not aimOn then return end
        if not tgtValid(locked) then locked=nil end
        if not locked then locked=findTgt() end

        if locked then
            local ok=inFOV(locked.Position)
            if not ok then
                locked=nil
                if FCS then FCS.Color=Color3.fromRGB(255,55,55) FCS.Thickness=1.8 end
                local st=uiRefs.AimStat if st then st.Text="STATUS: SEARCHING..." st.TextColor3=Color3.fromRGB(215,150,40) end
                if pillRefs.aimDtxt then pillRefs.aimDtxt.Text="SEARCH" pillRefs.aimDtxt.TextColor3=Color3.fromRGB(215,150,40) end
                return
            end
            local cf=CAM.CFrame
            local tgtPos=getPredictedPos(locked)
            if silentAim then
                tgtPos=tgtPos+Vector3.new((math.random()-0.5)*0.22,(math.random()-0.5)*0.14,0)
            end
            local dir=(tgtPos-cf.Position).Unit
            CAM.CFrame=cf:Lerp(CFrame.new(cf.Position,cf.Position+dir),math.min(1,dt*SMOOTH))
            local tc=getTheme()
            if FCS then FCS.Color=tc[1] FCS.Thickness=2.5 end
            local nm=(locked.Parent and locked.Parent.Name) or "?"
            local st=uiRefs.AimStat if st then st.Text="LOCKED: "..string.upper(nm) st.TextColor3=tc[1] end
            if pillRefs.aimDtxt then pillRefs.aimDtxt.Text="LOCKED" pillRefs.aimDtxt.TextColor3=tc[1] end
            if trigBot and not trigCD then
                local sp2,on2=CAM:WorldToViewportPoint(tgtPos)
                if on2 then
                    local dist=(Vector2.new(sp2.X,sp2.Y)-getVC()).Magnitude
                    if dist<12 then
                        trigCD=true
                        task.delay(TRIG_DELAY,function()
                            local vu=game:GetService("VirtualUser")
                            if vu then
                                pcall(function() vu:Button1Down(getVC(),CAM.CFrame) end)
                                task.wait(0.06)
                                pcall(function() vu:Button1Up(getVC(),CAM.CFrame) end)
                            end
                            trigCD=false
                        end)
                    end
                end
            end
        else
            if FCS then FCS.Color=Color3.fromRGB(255,55,55) FCS.Thickness=1.8 end
            local st=uiRefs.AimStat if st then st.Text="STATUS: SEARCHING..." st.TextColor3=Color3.fromRGB(215,150,40) end
        end
    end)
end

-- ---- SUB: KILL COUNTER ----
local function buildKillCounter()
    local function watchPlayer(pl)
        pl.CharacterAdded:Connect(function(c2)
            local hum=c2:WaitForChild("Humanoid",5) if not hum then return end
            hum.Died:Connect(function()
                if aimOn or espOn then
                    killCount=killCount+1
                    if uiRefs.killStatV and uiRefs.killStatV.Parent then
                        uiRefs.killStatV.Text=tostring(killCount)
                    end
                    table.insert(sessionKills,os.clock())
                    showNotif("🎯 Eliminated!",pl.DisplayName.."  ["..killCount.." kills]",Color3.fromRGB(215,38,38),2.5)
                end
            end)
        end)
    end
    for _,p in ipairs(PL:GetPlayers()) do watchPlayer(p) end
    PL.PlayerAdded:Connect(watchPlayer)
    PL.PlayerRemoving:Connect(function(pl)
        remESP(pl) origSz[pl]=nil prevPos[pl]=nil prevTime[pl]=nil
    end)
    LP.CharacterAdded:Connect(function(c2)
        if speedOn then task.wait(0.25)
            local h=c2:FindFirstChildOfClass("Humanoid") if h then h.WalkSpeed=30 end
        end
        if espOn then task.wait(0.15) enESP() end
        if hbOn  then task.wait(0.2)  enHB()  end
    end)
end

-- ---- SUB: INPUT HANDLING ----
local function buildInputHandlers(MF)
    UIS.InputChanged:Connect(function(inp)
        if isDrag and(inp.UserInputType==Enum.UserInputType.MouseMovement
                   or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-dS
            MF.Position=UDim2.new(dF.X.Scale,dF.X.Offset+d.X,dF.Y.Scale,dF.Y.Offset+d.Y)
        end
        if isMini and(inp.UserInputType==Enum.UserInputType.MouseMovement
                   or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-mS
            if d.Magnitude>6 then mMov=true end
            if uiRefs.MB then uiRefs.MB.Position=UDim2.new(mF.X.Scale,mF.X.Offset+d.X,mF.Y.Scale,mF.Y.Offset+d.Y) end
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            isDrag=false
            if isMini then
                if not mMov then
                    if guiOpen then
                        guiOpen=false
                        TS:Create(MF,TweenInfo.new(0.26,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{
                            Size=UDim2.new(0,620,0,0),BackgroundTransparency=1}):Play()
                        task.delay(0.28,function() MF.Visible=false MF.Size=UDim2.new(0,620,0,375) MF.BackgroundTransparency=0.05 end)
                    else
                        guiOpen=true MF.Visible=true
                        MF.Size=UDim2.new(0,620,0,0) MF.BackgroundTransparency=1
                        TS:Create(MF,TweenInfo.new(0.30,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{
                            Size=UDim2.new(0,620,0,375),BackgroundTransparency=0.05}):Play()
                    end
                else
                    if uiRefs.MB then saveData.miniPos={x=uiRefs.MB.Position.X.Scale,y=uiRefs.MB.Position.Y.Scale} writeSave() end
                end
            end
            isMini=false
        end
    end)
    UIS.InputBegan:Connect(function(inp,gp)
        if gp then return end
        if inp.KeyCode==Enum.KeyCode.RightShift then
            if guiOpen then
                guiOpen=false
                TS:Create(MF,TweenInfo.new(0.26,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{
                    Size=UDim2.new(0,620,0,0),BackgroundTransparency=1}):Play()
                task.delay(0.28,function() MF.Visible=false MF.Size=UDim2.new(0,620,0,375) MF.BackgroundTransparency=0.05 end)
            else
                guiOpen=true MF.Visible=true
                MF.Size=UDim2.new(0,620,0,0) MF.BackgroundTransparency=1
                TS:Create(MF,TweenInfo.new(0.30,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{
                    Size=UDim2.new(0,620,0,375),BackgroundTransparency=0.05}):Play()
            end
        end
        if inp.KeyCode==Enum.KeyCode.Tab and aimOn then
            local targets={}
            for _,pl in ipairs(PL:GetPlayers()) do
                if pl==LP then continue end
                local c=pl.Character if not c then continue end
                local hum=c:FindFirstChildOfClass("Humanoid") if not hum or hum.Health<=0 then continue end
                local bone=c:FindFirstChild(AIM_BONE) or c:FindFirstChild("UpperTorso")
                if not bone then continue end
                local ok,_,d=inFOV(bone.Position)
                if ok then table.insert(targets,{bone=bone,d=d}) end
            end
            table.sort(targets,function(a,b) return a.d<b.d end)
            if #targets>1 then
                for i,t in ipairs(targets) do
                    if t.bone==locked then
                        locked=targets[(i%#targets)+1].bone
                        showNotif("🔄 Target","Switched target",Color3.fromRGB(255,215,60),1.5)
                        return
                    end
                end
                if #targets>0 then locked=targets[1].bone end
            end
        end
        if inp.KeyCode==Enum.KeyCode.Delete then
            disESP() disChams()
            if pillRefs.espPill then animT(pillRefs.espPill,pillRefs.espKnob,pillRefs.espDot,pillRefs.espDtxt,false,Color3.fromRGB(38,155,85),"ACTIVE") end
            espOn=false
            showNotif("🗑️ Cleared","All ESP removed",Color3.fromRGB(215,80,80),2)
        end
    end)
end

-- ============================================================
--  MAIN ENTRY — called after key passes
-- ============================================================
local function startMain()
    -- mini button
    local MB=Instance.new("ImageButton")
    MB.Size=UDim2.new(0,45,0,45) MB.AnchorPoint=Vector2.new(0.5,0.5)
    MB.Position=UDim2.new(saveData.miniPos.x,0,saveData.miniPos.y,0)
    MB.BackgroundColor3=Color3.fromRGB(17,17,22) MB.BackgroundTransparency=0.08
    MB.BorderSizePixel=0 MB.Image=LOGO_IMG MB.ImageTransparency=1
    MB.ScaleType=Enum.ScaleType.Fit MB.Visible=false MB.ZIndex=50 MB.Parent=SG
    mkCorner(MB,10)
    local MBS=mkStroke(MB,2.5,Color3.fromRGB(255,0,0))
    uiRefs.MB=MB
    local mbHue=0
    RS.Heartbeat:Connect(function(dt) mbHue=(mbHue+dt*0.55)%1 MBS.Color=Color3.fromHSV(mbHue,1,1) end)
    MB.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            isMini=true mMov=false mS=inp.Position mF=MB.Position
        end
    end)

    -- build all pieces in separate function scopes
    local MF,tabPages,switchTab = buildMainFrame()
    buildHomeTab(tabPages["Home"])
    buildAimbotTab(tabPages["Aimbot"])
    buildESPTab(tabPages["ESP"])
    buildVisualsTab(tabPages["Visuals"])
    buildSettingsTab(tabPages["Settings"])
    buildHUD()
    buildFeatureSetters()
    buildAimbotLoop()
    buildKillCounter()
    buildInputHandlers(MF)

    switchTab("Home")

    buildLoadingScreen(function()
        MB.Visible=true MB.Size=UDim2.new(0,0,0,0) MB.ImageTransparency=1
        TS:Create(MB,TweenInfo.new(0.38,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{
            Size=UDim2.new(0,45,0,45),ImageTransparency=0}):Play()
        task.delay(0.5,function()
            showNotif("👋 Welcome Back!",getGreeting()..", "..LP.DisplayName.."! "..VERSION.." loaded.",Color3.fromRGB(255,215,60),4.5)
        end)
        task.delay(5.5,function()
            showNotif("⌨️ Keybinds","RShift=GUI  Tab=Cycle  F=HeadLock  Del=ClearESP",Color3.fromRGB(100,100,140),6)
        end)
    end)
end

-- ============================================================
--  BOOTSTRAP
-- ============================================================
if saveData.keyPassed then
    TS:Create(blur,TweenInfo.new(0.5),{Size=24}):Play()
    startMain()
else
    buildKeySystem(startMain)
end

-- Cleanup on character removal
LP.AncestryChanged:Connect(function()
    pcall(function() Lighting.Ambient=origAmb Lighting.OutdoorAmbient=origOutAmb
        Lighting.Brightness=origBright Lighting.ClockTime=origClock Lighting.FogEnd=origFog end)
    pcall(function() disHB() disESP() disChams() end)
    pcall(function()
        if noclipConn  then noclipConn:Disconnect()  end
        if infJumpConn then infJumpConn:Disconnect()  end
        if antiAfkConn then antiAfkConn:Disconnect()  end
    end)
end)

print("[Rivals AimBot "..VERSION.."] Loaded — "..tostring(#SG:GetChildren()).." GUI elements. No server writes.")