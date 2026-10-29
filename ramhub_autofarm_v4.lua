-- RAMHUB | AutoFarm Zombies v4 (HoodLocal) - LocalScript
-- Zombies cacheados | objetivo fijo | kite/seguir | huida + curacion | recarga por ammo real
-- recogida de drops | anti-stuck | anti-AFK | auto-rejoin | modo ahorro | stats | config guardada
-- v4: menu con tecla propia (a prueba de gameProcessed) + boton en HUD | skip de animaciones | OPTIMIZADOR de juego

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players  = game:GetService("Players")
local WS       = game:GetService("Workspace")
local VIM      = game:GetService("VirtualInputManager")
local VU       = game:GetService("VirtualUser")
local UIS      = game:GetService("UserInputService")
local RunServ  = game:GetService("RunService")
local TPS      = game:GetService("TeleportService")
local GuiServ  = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = WS.CurrentCamera
-- celular = pantalla tactil sin teclado ni raton
local IS_MOBILE = UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.MouseEnabled
local DEF_HUD_Y = IS_MOBILE and (-math.floor(camera.ViewportSize.Y / 2) + 10) or -240

-- ================= Abrir/cerrar menu (a prueba de gameProcessed) =================
local function toggleMenu()
    local ok = pcall(function()
        Rayfield:SetVisibility(not Rayfield:IsVisible())
    end)
    if ok then return end
    local hosts = { gethui and gethui() or nil, game:GetService("CoreGui"), player:FindFirstChild("PlayerGui") }
    for _, host in ipairs(hosts) do
        local g = host and host:FindFirstChild("Rayfield")
        if g then g.Enabled = not g.Enabled return end
    end
end

-- ================= CONFIG =================
local CFG = {
    ENABLED = true, AUTOFARM = true,
    MAX_DIST = 1000, AIM_PART = "Head", PRIORITY = "Cercano", -- Cercano | Menos vida
    WEAPON_KEY = Enum.KeyCode.Two, RELOAD_KEY = Enum.KeyCode.R,
    SPAM_KEY = Enum.KeyCode.E, TOGGLE_KEY = Enum.KeyCode.F, HEAL_KEY = Enum.KeyCode.Three,
    MENU_KEY = Enum.KeyCode.RightShift,
    SHOT_DELAY = 0.08, BURST_SIZE = 3, BURST_PAUSE = 0.25, AIM_STRICT = 0.97,
    RIGHT_HOLD = true, ALWAYS_AIM = true, -- ALWAYS_AIM: mantiene la mira aunque no haya zombie a la vista
    MOVE_MODE = "Quieto", KITE_MIN = 25, FOLLOW_MAX = 60,
    AUTO_RELOAD = true, RELOAD_EVERY = 12,
    AUTO_HEAL = false, HEAL_HP = 0.5,
    FLEE = true, FLEE_HP = 0.3,
    COLLECT = true, COLLECT_KEYWORDS = {"cash","money","coin","loot","drop","argent"}, COLLECT_RANGE = 300,
    ANTI_STUCK = true, AUTO_REJOIN = true, SAVE_RENDER = false,
    HUD_VISIBLE = true,
    HUD_X = 16, HUD_Y = DEF_HUD_Y, HUD_SCALE = IS_MOBILE and 0.7 or 1, HUD_ALPHA = 0.05,
    HUD_RADAR = not IS_MOBILE, HUD_MINI = IS_MOBILE, -- en celular el HUD arranca pequeño y minimizado
    AFK_MODE = true, AFK_NORENDER = true, AFK_FPS = 30, -- AFK total: funciona con la ventana minimizada / sin foco
    PC_INPUT = not IS_MOBILE, -- true = clics/teclas reales (modo original, necesita ventana activa). false = todo dentro del juego
    FACE_TARGET = false, SMOOTH_AIM = false, TURN_SPEED = 0.25, -- false = apuntado directo (modo original)
    WEAPON_NAME = "", WEAPON_SLOT = 2, HEAL_NAME = "", FPS_CAP = 0,
    AUTO_E = true, ALL_PROMPTS = true, E_RANGE = 25,
    AUTO_HOP = false, HOP_MAX_PLAYERS = 3, HOP_NO_ZOMBIES = 0, SCRIPT_FILE = "", SCRIPT_URL = "",
    HOLD_POSITION = true, -- true = el personaje NUNCA se mueve (spot fijo)
    SKIP_ANIM = false, SKIP_MODE = "Acelerar", SKIP_SPEED = 10, -- salto de animaciones (recarga/equipar)
    SWITCH_SHOTS = 6, SWITCH_TIME = 5, -- cambia de objetivo tras N disparos al mismo (0 = no cambiar) y lo ignora N segundos
    HUMAN = true, HUMAN_REACT = 0.35, HUMAN_MISS = 0.08, HUMAN_JITTER = 0.6, -- modo discreto (comportamiento mas humano)
    OPT_LEVEL = "Ligero", OPT_NEW = true, -- optimizador: Apagado | Ligero | Fuerte | Extremo
}

-- ================= Guardado propio de configuracion =================
local HttpService = game:GetService("HttpService")
local SAVE_DIR, SAVE_FILE, OLD_FILE = "AFZ", "AFZ/config_v4.json", "AFZ/config_v3.json"
local NO_SAVE = { ENABLED = true } -- el script siempre arranca activado
local saveQueued = false
local function saveCfg()
    if saveQueued or not writefile then return end
    saveQueued = true
    task.delay(1, function()
        saveQueued = false
        pcall(function()
            local o = {}
            for k, v in pairs(CFG) do
                if not NO_SAVE[k] then
                    o[k] = (typeof(v) == "EnumItem") and ("Enum:" .. v.Name) or v
                end
            end
            if makefolder and isfolder and not isfolder(SAVE_DIR) then makefolder(SAVE_DIR) end
            writefile(SAVE_FILE, HttpService:JSONEncode(o))
        end)
    end)
end
local function loadCfg()
    local file, migrated = SAVE_FILE, false
    if not (isfile and isfile(file)) then file, migrated = OLD_FILE, true end
    if not (readfile and isfile and isfile(file)) then return end
    local ok, d = pcall(function() return HttpService:JSONDecode(readfile(file)) end)
    if not ok or type(d) ~= "table" then return end
    for k, v in pairs(d) do
        local cur = CFG[k]
        if cur ~= nil and not NO_SAVE[k] then
            if typeof(cur) == "EnumItem" then
                if type(v) == "string" then
                    local ok2, kc = pcall(function() return Enum.KeyCode[(v:gsub("^Enum:", ""))] end)
                    if ok2 and kc then CFG[k] = kc end
                end
            elseif type(v) == type(cur) then
                CFG[k] = v
            end
        end
    end
    if CFG.MOVE_MODE == "Kite" then CFG.MOVE_MODE = "Alejarse" end
    if migrated then CFG.PC_INPUT = true; CFG.SMOOTH_AIM = false; CFG.FACE_TARGET = false end
end
loadCfg()

local S = {
    firing = CFG.AUTOFARM, rightHeld = false, lastShot = 0, lastBurst = 0, burst = 0,
    shots = 0, kills = 0, t0 = os.clock(), waiting = nil, target = nil,
    safePos = nil, lastHeal = 0, stuckT = 0, lastPos = nil, reloading = false,
    skip = setmetatable({}, { __mode = "k" }), curM = nil, curShots = 0, -- cambio de objetivo por disparos
}
local AFK = { learning = false, fire = nil, hooked = false, eqTool = nil, lbl = nil, wasOn = false }

-- ================= HoodLocal + cache =================
local hood = WS:WaitForChild("HoodLocal", 10)
if not hood then warn("[AF] HoodLocal no encontrado") return end

local zombies = {} -- [Model] = Humanoid
local function track(m)
    if not m:IsA("Model") or not m.Name:lower():match("^zombie") then return end
    local hum = m:FindFirstChildOfClass("Humanoid") or m:WaitForChild("Humanoid", 5)
    if not hum then return end
    zombies[m] = hum
    hum.Died:Once(function() if zombies[m] then S.kills += 1 end zombies[m] = nil end)
end
for _, m in ipairs(hood:GetChildren()) do task.spawn(track, m) end
hood.ChildAdded:Connect(function(m) task.spawn(track, m) end)
hood.ChildRemoved:Connect(function(m) zombies[m] = nil end)

-- ================= Drops =================
local drops = {} -- [BasePart] = ProximityPrompt|false
local function isDrop(o)
    if not o:IsA("BasePart") or o:IsDescendantOf(hood) then return false end
    if player.Character and o:IsDescendantOf(player.Character) then return false end
    local n = o.Name:lower()
    for _, k in ipairs(CFG.COLLECT_KEYWORDS) do if n:find(k, 1, true) then return true end end
    return false
end
local function addDrop(o)
    if isDrop(o) then drops[o] = o:FindFirstChildOfClass("ProximityPrompt") or false end
end
local prompts = {} -- [ProximityPrompt] = true
local function addAny(o)
    addDrop(o)
    if o:IsA("ProximityPrompt") then prompts[o] = true end
end
task.spawn(function()
    for i, o in ipairs(WS:GetDescendants()) do
        addAny(o)
        if i % 500 == 0 then task.wait() end
    end
end)
WS.DescendantAdded:Connect(addAny)
WS.DescendantRemoving:Connect(function(o) drops[o] = nil; prompts[o] = nil end)

-- ================= Dinero =================
local function getMoney()
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            if v:IsA("ValueBase") and type(v.Value) == "number" then
                local n = v.Name:lower()
                if n:find("cash") or n:find("money") or n:find("coin") or n:find("argent") or n:find("dollar") then
                    return v.Value
                end
            end
        end
    end
    for _, a in ipairs({"Money","Cash","Coins","Argent","Dollars"}) do
        local v = player:GetAttribute(a)
        if type(v) == "number" then return v end
    end
end
local moneyStart = getMoney() or 0

local releaseRight -- forward declaration (se define en Input)

-- ================= HUD RAMHUB (overlay propio) =================
local LOGO_ID = 0 -- <- pon aqui el ID numerico de tu logo subido a Roblox. 0 = logo "RH" generado
local ACCENT, ACCENT2 = Color3.fromRGB(139, 92, 246), Color3.fromRGB(34, 211, 238)
local WHITE, GRAY = Color3.fromRGB(240, 240, 250), Color3.fromRGB(150, 150, 170)
local BG, CARD = Color3.fromRGB(13, 13, 20), Color3.fromRGB(24, 24, 36)
local GREEN, AMBER, RED = Color3.fromRGB(34, 197, 94), Color3.fromRGB(245, 158, 11), Color3.fromRGB(239, 68, 68)
local HUD = { stateText = "listo" }
do
    local TweenService = game:GetService("TweenService")
    local Stats = game:GetService("Stats")

    local function new(cls, props, par)
        local o = Instance.new(cls)
        for k, v in pairs(props) do o[k] = v end
        o.Parent = par
        return o
    end
    local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
    local function label(par, props)
        props.BackgroundTransparency = 1
        props.Font = props.Font or Enum.Font.Gotham
        props.TextColor3 = props.TextColor3 or WHITE
        return new("TextLabel", props, par)
    end
    local function comma(n)
        local str = tostring(math.floor(math.abs(n)))
        str = str:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return (n < 0 and "-" or "") .. str
    end
    local function fmtTime(sec)
        sec = math.floor(sec)
        return string.format("%02d:%02d:%02d", sec // 3600, sec % 3600 // 60, sec % 60)
    end
    local function tween(o, props, t, style, dir)
        TweenService:Create(o, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quad,
            dir or Enum.EasingDirection.Out), props):Play()
    end
    local function fpsCol(v) return v >= 50 and GREEN or (v >= 30 and AMBER or RED) end
    local function pingCol(v) return v <= 90 and GREEN or (v <= 180 and AMBER or RED) end

    local gui = new("ScreenGui", { Name = "RAMHUB_HUD", ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 999, Enabled = CFG.HUD_VISIBLE }, nil)
    local host = (gethui and gethui()) or game:GetService("CoreGui")
    pcall(function() local old = host:FindFirstChild("RAMHUB_HUD"); if old then old:Destroy() end end)
    if not pcall(function() gui.Parent = host end) then gui.Parent = player:WaitForChild("PlayerGui") end

    local main = new("Frame", { Name = "Main", Size = UDim2.fromOffset(280, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0, CFG.HUD_X, 0.5, CFG.HUD_Y), BackgroundColor3 = BG,
        BackgroundTransparency = CFG.HUD_ALPHA, BorderSizePixel = 0 }, gui)
    corner(main, 14)
    local stroke = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.8, Transparency = 0.1 }, main)
    local strokeGrad = new("UIGradient", { Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, ACCENT), ColorSequenceKeypoint.new(0.5, ACCENT2), ColorSequenceKeypoint.new(1, ACCENT) }) }, stroke)
    new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, main)
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, main)
    local scale = new("UIScale", { Scale = 0.9 * CFG.HUD_SCALE }, main)

    -- ===== cabecera: logo, titulo, menu, minimizar (arrastrable) =====
    local head = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 1 }, main)
    if LOGO_ID > 0 then
        local img = new("ImageLabel", { Size = UDim2.fromOffset(38, 38), BackgroundTransparency = 1,
            Image = "rbxassetid://" .. LOGO_ID }, head)
        corner(img, 9)
    else
        local badge = new("Frame", { Size = UDim2.fromOffset(38, 38), BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0 }, head)
        corner(badge, 9)
        new("UIGradient", { Color = ColorSequence.new(ACCENT, ACCENT2), Rotation = 45 }, badge)
        label(badge, { Size = UDim2.fromScale(1, 1), Text = "RH", Font = Enum.Font.GothamBlack, TextSize = 19,
            TextColor3 = Color3.new(1, 1, 1) })
    end
    local title = label(head, { Position = UDim2.fromOffset(46, 1), Size = UDim2.new(1, -110, 0, 22), Text = "RAMHUB",
        Font = Enum.Font.GothamBlack, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.new(1, 1, 1) })
    new("UIGradient", { Color = ColorSequence.new(ACCENT, ACCENT2) }, title)
    label(head, { Position = UDim2.fromOffset(46, 23), Size = UDim2.new(1, -110, 0, 14), Text = "AutoFarm Zombies  ·  v4",
        TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GRAY })
    local menuBtn = new("TextButton", { Position = UDim2.new(1, -56, 0, 7), Size = UDim2.fromOffset(26, 26),
        BackgroundColor3 = CARD, BorderSizePixel = 0, Text = "≡", Font = Enum.Font.GothamBold, TextSize = 16,
        TextColor3 = WHITE }, head)
    corner(menuBtn, 7)
    menuBtn.MouseButton1Click:Connect(toggleMenu)
    local minBtn = new("TextButton", { Position = UDim2.new(1, -26, 0, 7), Size = UDim2.fromOffset(26, 26),
        BackgroundColor3 = CARD, BorderSizePixel = 0, Text = "–", Font = Enum.Font.GothamBold, TextSize = 16,
        TextColor3 = WHITE }, head)
    corner(minBtn, 7)

    -- arrastre (la posicion se guarda)
    local dragging, dragStart, startX, startY
    head.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart = true, i.Position
            startX, startY = main.Position.X.Offset, main.Position.Y.Offset
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    CFG.HUD_X, CFG.HUD_Y = main.Position.X.Offset, main.Position.Y.Offset
                    saveCfg()
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
            local d = (i.Position - dragStart) / math.max(scale.Scale, 0.1)
            main.Position = UDim2.new(0, startX + d.X, 0.5, startY + d.Y)
        end
    end)

    -- ===== estado =====
    local pill = new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = CARD, BorderSizePixel = 0,
        LayoutOrder = 2 }, main)
    corner(pill, 9)
    local dot = new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 10, 0.5, -5),
        BackgroundColor3 = GREEN, BorderSizePixel = 0 }, pill)
    corner(dot, 5)
    local stLbl = label(pill, { Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -140, 1, 0), Text = "listo",
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
    local perf = label(pill, { Position = UDim2.new(1, -116, 0, 0), Size = UDim2.new(0, 108, 1, 0), Text = "",
        TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GRAY, RichText = true })

    -- ===== cuerpo (se oculta al minimizar) =====
    local body = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = 3, Visible = not CFG.HUD_MINI }, main)
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    minBtn.Text = CFG.HUD_MINI and "+" or "–"
    minBtn.MouseButton1Click:Connect(function()
        body.Visible = not body.Visible
        CFG.HUD_MINI = not body.Visible
        minBtn.Text = body.Visible and "–" or "+"
        saveCfg()
    end)

    -- tarjetas 2x2
    local grid = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = 1 }, body)
    new("UIGridLayout", { CellSize = UDim2.new(0.5, -3, 0, 50), CellPadding = UDim2.fromOffset(6, 6),
        SortOrder = Enum.SortOrder.LayoutOrder }, grid)
    local function card(order, caption)
        local f = new("Frame", { BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = order }, grid)
        corner(f, 9)
        label(f, { Position = UDim2.fromOffset(9, 4), Size = UDim2.new(1, -18, 0, 12), Text = caption:upper(),
            TextSize = 9, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GRAY })
        local val = label(f, { Position = UDim2.fromOffset(9, 16), Size = UDim2.new(1, -18, 0, 20), Text = "-",
            TextSize = 17, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left })
        local sub = label(f, { Position = UDim2.fromOffset(9, 36), Size = UDim2.new(1, -18, 0, 11), Text = "",
            TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = ACCENT2 })
        return val, sub
    end
    local vZ, sZ = card(1, "Zombies")
    local vK, sK = card(2, "Bajas")
    local vM, sM = card(3, "Dinero")
    local vT, sT = card(4, "Sesion")

    -- ===== fila info: radar + tarjeta de objetivo/arma =====
    local RADAR_RANGE, RADAR_R = 150, 52
    local info = new("Frame", { Size = UDim2.new(1, 0, 0, 112), BackgroundTransparency = 1, LayoutOrder = 2 }, body)
    local radar = new("Frame", { Size = UDim2.fromOffset(112, 112), BackgroundColor3 = CARD, BorderSizePixel = 0,
        ClipsDescendants = true }, info)
    corner(radar, 56)
    new("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 0.5 }, radar)
    local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 }, radar)
    corner(ring, 28)
    new("UIStroke", { Color = GRAY, Thickness = 1, Transparency = 0.75 }, ring)
    new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = GRAY, BackgroundTransparency = 0.82, BorderSizePixel = 0 }, radar)
    new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = GRAY, BackgroundTransparency = 0.82, BorderSizePixel = 0 }, radar)
    local me = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(7, 7), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 3 }, radar)
    corner(me, 4)
    label(radar, { Position = UDim2.new(0, 0, 1, -15), Size = UDim2.new(1, 0, 0, 12), Text = RADAR_RANGE .. "u",
        TextSize = 9, TextColor3 = GRAY })

    local side = new("Frame", { Position = UDim2.fromOffset(120, 0), Size = UDim2.new(1, -120, 1, 0),
        BackgroundColor3 = CARD, BorderSizePixel = 0 }, info)
    corner(side, 9)
    label(side, { Position = UDim2.fromOffset(9, 5), Size = UDim2.new(1, -18, 0, 12), Text = "OBJETIVO", TextSize = 9,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GRAY })
    local tName = label(side, { Position = UDim2.fromOffset(9, 17), Size = UDim2.new(1, -18, 0, 16), Text = "-",
        TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd })
    local tDist = label(side, { Position = UDim2.fromOffset(9, 33), Size = UDim2.new(1, -18, 0, 12), Text = "",
        TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = ACCENT2,
        TextTruncate = Enum.TextTruncate.AtEnd })
    local tHpBg = new("Frame", { Position = UDim2.fromOffset(9, 49), Size = UDim2.new(1, -18, 0, 7),
        BackgroundColor3 = BG, BorderSizePixel = 0 }, side)
    corner(tHpBg, 4)
    local tHpFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = RED, BorderSizePixel = 0 }, tHpBg)
    corner(tHpFill, 4)
    label(side, { Position = UDim2.fromOffset(9, 62), Size = UDim2.new(1, -18, 0, 12), Text = "ARMA", TextSize = 9,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GRAY })
    local wLbl = label(side, { Position = UDim2.fromOffset(9, 74), Size = UDim2.new(1, -18, 0, 15), Text = "-",
        TextSize = 12, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd })
    local srvLbl = label(side, { Position = UDim2.fromOffset(9, 92), Size = UDim2.new(1, -18, 0, 12), Text = "-",
        TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GRAY })

    -- puntos del radar (pool)
    local dots = {}
    local function getDot(k)
        if not dots[k] then
            local d = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5, 5),
                BackgroundColor3 = RED, BorderSizePixel = 0, Visible = false, ZIndex = 2 }, radar)
            new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, d)
            dots[k] = d
        end
        return dots[k]
    end
    local function updateRadar()
        local c = player.Character
        local root = c and c:FindFirstChild("HumanoidRootPart")
        local used = 0
        if root then
            local look = camera.CFrame.LookVector
            local fwd = Vector3.new(look.X, 0, look.Z)
            if fwd.Magnitude > 0.01 then
                fwd = fwd.Unit
                local right = fwd:Cross(Vector3.yAxis)
                local sc = RADAR_R / RADAR_RANGE
                for m, h in pairs(zombies) do
                    if used >= 40 then break end
                    if m.Parent and h.Health > 0 then
                        local rpart = h.RootPart or m.PrimaryPart
                        if rpart then
                            local v = rpart.Position - root.Position
                            local x, y = v:Dot(right) * sc, v:Dot(fwd) * sc
                            local mag = math.sqrt(x * x + y * y)
                            local far = mag > RADAR_R - 4
                            if far then
                                local k2 = (RADAR_R - 4) / mag
                                x, y = x * k2, y * k2
                            end
                            used += 1
                            local d = getDot(used)
                            local isT = S.target ~= nil and S.target.m == m
                            d.Position = UDim2.new(0.5, x, 0.5, -y)
                            d.Size = isT and UDim2.fromOffset(8, 8) or UDim2.fromOffset(5, 5)
                            d.BackgroundColor3 = isT and ACCENT2 or RED
                            d.BackgroundTransparency = far and 0.55 or 0
                            d.Visible = true
                        end
                    end
                end
            end
        end
        for k = used + 1, #dots do dots[k].Visible = false end
    end
    task.spawn(function()
        while true do
            task.wait(0.08)
            if gui.Enabled and body.Visible and CFG.HUD_RADAR then pcall(updateRadar) end
        end
    end)

    -- vida (con animacion)
    local hpBg = new("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = CARD, BorderSizePixel = 0,
        LayoutOrder = 3 }, body)
    corner(hpBg, 8)
    local hpFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0 }, hpBg)
    corner(hpFill, 8)
    local hpGrad = new("UIGradient", { Color = ColorSequence.new(GREEN, ACCENT2) }, hpFill)
    local hpTxt = label(hpBg, { Size = UDim2.fromScale(1, 1), Text = "VIDA", TextSize = 10, Font = Enum.Font.GothamBold,
        ZIndex = 3 })

    -- grafica de FPS (ultimos ~6 s)
    local SP_N, hist, spark = 26, {}, {}
    local sparkRow = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = CARD, BorderSizePixel = 0,
        LayoutOrder = 4 }, body)
    corner(sparkRow, 8)
    local sparkArea = new("Frame", { Position = UDim2.fromOffset(7, 4), Size = UDim2.new(1, -14, 1, -8),
        BackgroundTransparency = 1 }, sparkRow)
    for k = 1, SP_N do
        local b = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new((k - 1) / SP_N, 0, 1, 0),
            Size = UDim2.new(1 / SP_N, -2, 0.05, 0), BackgroundColor3 = GRAY, BorderSizePixel = 0, Visible = false }, sparkArea)
        corner(b, 1)
        spark[k] = b
    end

    -- chips de funciones activas
    local chipsRow = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = 5 }, body)
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder }, chipsRow)
    local chips = {}
    local function chip(name, order)
        local c = new("TextLabel", { Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = CARD, BorderSizePixel = 0, Text = name, Font = Enum.Font.GothamBold, TextSize = 9,
            TextColor3 = GRAY, LayoutOrder = order }, chipsRow)
        corner(c, 9)
        new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, c)
        chips[name] = c
    end
    chip("PC", 1); chip("SPOT", 2); chip("E", 3); chip("MIRA", 4); chip("HOP", 5); chip("OPT", 6); chip("HUM", 7); chip("AFK", 8)

    -- boton ON/OFF
    local btn = new("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = ACCENT, BorderSizePixel = 0,
        Text = "AUTOFARM: ON", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
        LayoutOrder = 6 }, body)
    corner(btn, 9)
    new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 220)), Rotation = 90 }, btn)
    btn.MouseButton1Click:Connect(function()
        S.firing = not S.firing; S.burst = 0
        if not S.firing then releaseRight() end
    end)

    -- ===== FPS + animaciones =====
    local fps, t0 = 60, 0
    RunServ.Heartbeat:Connect(function(dt)
        if dt > 0 then fps = fps * 0.92 + (1 / dt) * 0.08 end
        if not gui.Enabled then return end
        if CFG.OPT_LEVEL ~= "Apagado" then return end -- con el optimizador activo no animamos el HUD
        t0 = os.clock()
        strokeGrad.Rotation = (t0 * 45) % 360
        if CFG.ENABLED and S.firing then
            dot.BackgroundTransparency = 0.45 - 0.45 * math.sin(t0 * 5) * 0.5 - 0.0
        else
            dot.BackgroundTransparency = 0
        end
    end)

    local AMMO_NAMES = {"Ammo","CurrentAmmo","Mag","Magazine","Clip","Bullets"}
    local function ammoOf(t)
        for _, n in ipairs(AMMO_NAMES) do
            local a = t:GetAttribute(n)
            if type(a) == "number" then return a end
            local v = t:FindFirstChild(n, true)
            if v and v:IsA("ValueBase") and type(v.Value) == "number" then return v.Value end
        end
    end
    local function setChip(name, on)
        local c = chips[name]
        c.BackgroundColor3 = on and ACCENT or CARD
        c.TextColor3 = on and Color3.new(1, 1, 1) or GRAY
    end

    -- aplica tamaño / opacidad / radar (se llama desde el refresco)
    function HUD.apply()
        main.BackgroundTransparency = CFG.HUD_ALPHA
        if scale.Scale ~= CFG.HUD_SCALE then scale.Scale = CFG.HUD_SCALE end
        radar.Visible = CFG.HUD_RADAR
        side.Position = CFG.HUD_RADAR and UDim2.fromOffset(120, 0) or UDim2.fromOffset(0, 0)
        side.Size = CFG.HUD_RADAR and UDim2.new(1, -120, 1, 0) or UDim2.new(1, 0, 1, 0)
    end
    function HUD.resetPos()
        CFG.HUD_X, CFG.HUD_Y = 16, DEF_HUD_Y
        main.Position = UDim2.new(0, 16, 0.5, DEF_HUD_Y)
        saveCfg()
    end

    local introDone = false
    HUD.apply()
    scale.Scale = 0.9 * CFG.HUD_SCALE
    tween(scale, { Scale = CFG.HUD_SCALE }, 0.35, Enum.EasingStyle.Back)
    task.delay(0.6, function() introDone = true end)

    function HUD.refresh()
        if introDone then HUD.apply() end
        local n = 0
        for m, h in pairs(zombies) do if m.Parent and h.Health > 0 then n += 1 end end
        local el = os.clock() - S.t0
        local mins = math.max(el / 60, 1 / 60)
        local gain = (getMoney() or moneyStart) - moneyStart

        vZ.Text = tostring(n)
        sZ.Text = S.target and string.format("objetivo a %.0f u", S.target.d) or "sin objetivo"
        vK.Text = comma(S.kills)
        sK.Text = string.format("%.1f / min", S.kills / mins)
        vM.Text = (gain >= 0 and "+" or "") .. comma(gain)
        sM.Text = comma(gain / mins * 60) .. " / hora"
        vT.Text = fmtTime(el)
        sT.Text = string.format("%d disparos", S.shots)

        local on = CFG.ENABLED and S.firing
        dot.BackgroundColor3 = (not CFG.ENABLED) and RED or (S.firing and GREEN or AMBER)
        stLbl.Text = body.Visible and HUD.stateText or string.format("%s  ·  %d bajas", HUD.stateText, S.kills)
        local okp, ping = pcall(function() return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        local f = math.floor(fps)
        perf.Text = string.format('<font color="#%s">%d FPS</font>  ·  <font color="#%s">%s</font>',
            fpsCol(f):ToHex(), f, (okp and pingCol(ping) or GRAY):ToHex(), okp and (ping .. " ms") or "-")
        btn.Text = on and "AUTOFARM: ON" or "AUTOFARM: OFF"
        btn.BackgroundColor3 = on and ACCENT or Color3.fromRGB(70, 70, 90)

        -- objetivo actual
        local tg = S.target
        if tg and tg.m.Parent and tg.hum.Health > 0 then
            tName.Text = tg.m.Name
            tDist.Text = string.format("%.0f u  ·  %d HP", tg.d, math.floor(tg.hum.Health))
            local tp = math.clamp(tg.hum.Health / math.max(tg.hum.MaxHealth, 1), 0, 1)
            tween(tHpFill, { Size = UDim2.fromScale(tp, 1) }, 0.2)
        else
            tName.Text = "sin objetivo"
            tDist.Text = ""
            tween(tHpFill, { Size = UDim2.fromScale(0, 1) }, 0.2)
        end

        -- vida propia
        local c = player.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        local pct = h and math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1) or 0
        tween(hpFill, { Size = UDim2.fromScale(pct, 1) }, 0.25)
        hpGrad.Color = pct < 0.3 and ColorSequence.new(RED, AMBER) or ColorSequence.new(GREEN, ACCENT2)
        hpTxt.Text = h and string.format("VIDA  %d / %d", math.floor(h.Health), math.floor(h.MaxHealth)) or "VIDA  -"

        -- arma
        local tl
        if c then for _, x in ipairs(c:GetChildren()) do if x:IsA("Tool") then tl = x break end end end
        if tl then
            local a = ammoOf(tl)
            wLbl.Text = tl.Name .. (a and ("  ·  " .. a) or "")
        else
            wLbl.Text = "sin arma"
        end
        srvLbl.Text = string.format("%d jugadores", #Players:GetPlayers())

        -- grafica de FPS
        hist[#hist + 1] = f
        if #hist > SP_N then table.remove(hist, 1) end
        local off = SP_N - #hist
        for k = 1, SP_N do
            local v, bar = hist[k - off], spark[k]
            if v then
                bar.Visible = true
                bar.Size = UDim2.new(1 / SP_N, -2, math.clamp(v / 120, 0.06, 1), 0)
                bar.BackgroundColor3 = fpsCol(v)
            else
                bar.Visible = false
            end
        end

        setChip("PC", CFG.PC_INPUT)
        setChip("SPOT", CFG.HOLD_POSITION)
        setChip("E", CFG.AUTO_E and CFG.COLLECT)
        setChip("MIRA", CFG.ALWAYS_AIM and CFG.RIGHT_HOLD and CFG.PC_INPUT)
        setChip("HOP", CFG.AUTO_HOP or CFG.HOP_NO_ZOMBIES > 0)
        setChip("OPT", CFG.OPT_LEVEL ~= "Apagado")
        setChip("HUM", CFG.HUMAN)
        setChip("AFK", CFG.AFK_MODE)
    end
    HUD.gui = gui
end
task.spawn(function() while true do task.wait(0.25); pcall(HUD.refresh) end end)


-- ================= SERVIDORES (server hop) =================
local lblHop
local hopping, lastHopTry = false, 0
local function notify(t) pcall(function() Rayfield:Notify({ Title = "RAMHUB", Content = t, Duration = 5 }) end) end
local function fetchServers()
    local list, cursor = {}, nil
    for _ = 1, 3 do
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s")
            :format(game.PlaceId, cursor and ("&cursor=" .. cursor) or "")
        local ok, res = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
        if not ok or type(res) ~= "table" or type(res.data) ~= "table" then break end
        for _, sv in ipairs(res.data) do list[#list + 1] = sv end
        cursor = res.nextPageCursor
        if not cursor then break end
    end
    return list
end
local function queueSelf() -- vuelve a ejecutar el script al cambiar de servidor
    if not queue_on_teleport then return end
    if CFG.SCRIPT_URL ~= "" then
        pcall(queue_on_teleport, string.format("loadstring(game:HttpGet(%q))()", CFG.SCRIPT_URL))
    elseif CFG.SCRIPT_FILE ~= "" then
        pcall(queue_on_teleport, string.format("loadstring(readfile(%q))()", CFG.SCRIPT_FILE))
    end
end
local function hop(reason, force)
    if hopping then return end
    if not force and os.clock() - lastHopTry < 60 then return end
    lastHopTry = os.clock()
    hopping = true
    notify("Buscando servidor... (" .. reason .. ")")
    task.spawn(function()
        local cands = {}
        for _, sv in ipairs(fetchServers()) do
            if sv.id ~= game.JobId and type(sv.playing) == "number" and type(sv.maxPlayers) == "number"
                and sv.playing < sv.maxPlayers and sv.playing <= CFG.HOP_MAX_PLAYERS then
                cands[#cands + 1] = sv
            end
        end
        if #cands == 0 then
            notify("No hay servidores con " .. CFG.HOP_MAX_PLAYERS .. " jugadores o menos")
            hopping = false
            return
        end
        table.sort(cands, function(a, b) return a.playing < b.playing end)
        local pick = cands[math.random(1, math.min(#cands, 5))]
        queueSelf()
        notify(string.format("Saltando a servidor con %d jugador(es)", pick.playing))
        pcall(function() TPS:TeleportToPlaceInstance(game.PlaceId, pick.id, player) end)
        task.wait(15)
        hopping = false
    end)
end
TPS.TeleportInitFailed:Connect(function() hopping = false end)

task.spawn(function()
    task.wait(15)
    local lastSeen = os.clock()
    while true do
        task.wait(5)
        local alive = false
        for m, h in pairs(zombies) do if m.Parent and h.Health > 0 then alive = true break end end
        if alive then lastSeen = os.clock() end
        local n = #Players:GetPlayers()
        if lblHop then pcall(function() lblHop:Set("Jugadores en este servidor: " .. n) end) end
        if CFG.ENABLED and S.firing then
            if CFG.AUTO_HOP and n > CFG.HOP_MAX_PLAYERS then
                hop("demasiados jugadores")
            elseif CFG.HOP_NO_ZOMBIES > 0 and os.clock() - lastSeen > CFG.HOP_NO_ZOMBIES then
                hop("sin zombies")
                lastSeen = os.clock()
            end
        end
    end
end)

-- ================= OPTIMIZADOR DE JUEGO =================
-- Ligero : sin sombras, sin efectos de post-proceso, sin particulas/trails, calidad grafica media
-- Fuerte : + materiales planos, sin reflejos, decals/texturas ocultos, niebla/agua/atmosfera apagadas, calidad minima
-- Extremo: + luces apagadas, mallas en rendimiento, texturas de mallas fuera, ambiente sin iluminacion especular
-- No toca personajes ni zombies (la puntería no cambia). Para REVERTIR hay que reentrar al servidor.
local LEVELS = { Apagado = 0, Ligero = 1, Fuerte = 2, Extremo = 3 }
local OPT = { busy = false, applied = 0 }

local function isCharPart(o)
    local m = o.Parent
    return m ~= nil and m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") ~= nil
end

local function optimizeInstance(o, lvl)
    if o:IsA("BasePart") then
        if o:IsA("Terrain") then return end
        o.CastShadow = false
        if lvl >= 2 then
            o.Reflectance = 0
            if not isCharPart(o) then
                o.Material = Enum.Material.Plastic
                if lvl >= 3 and o:IsA("MeshPart") then
                    o.RenderFidelity = Enum.RenderFidelity.Performance
                    o.TextureID = ""
                end
            end
        end
    elseif o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam") or o:IsA("Smoke")
        or o:IsA("Fire") or o:IsA("Sparkles") then
        o.Enabled = false
    elseif o:IsA("PostEffect") then
        o.Enabled = false
    elseif o:IsA("Light") then
        o.Shadows = false
        if lvl >= 3 then o.Enabled = false end
    elseif o:IsA("Decal") or o:IsA("Texture") then
        if lvl >= 2 and not (o.Parent and isCharPart(o.Parent)) then o.Transparency = 1 end
    elseif o:IsA("Atmosphere") then
        if lvl >= 2 then o.Density = 0; o.Haze = 0; o.Glare = 0 end
    elseif o:IsA("Clouds") then
        if lvl >= 2 then o.Enabled = false end
    end
end

local function optimizeGlobal(lvl)
    pcall(function()
        local q = (lvl >= 3 and Enum.QualityLevel.Level01) or (lvl >= 2 and Enum.QualityLevel.Level02) or Enum.QualityLevel.Level05
        settings().Rendering.QualityLevel = q
    end)
    pcall(function()
        UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    end)
    pcall(function() Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 0 end)
    if lvl >= 2 then
        pcall(function() Lighting.FogEnd = 9e9; Lighting.FogStart = 9e9 end)
        pcall(function() if sethiddenproperty then sethiddenproperty(Lighting, "Technology", Enum.Technology.Compatibility) end end)
        pcall(function() settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04 end)
        pcall(function()
            local t = WS.Terrain
            t.WaterWaveSize = 0; t.WaterWaveSpeed = 0; t.WaterReflectance = 0; t.WaterTransparency = 1
            if sethiddenproperty then sethiddenproperty(t, "Decoration", false) end
        end)
    end
    if lvl >= 3 then
        pcall(function() Lighting.EnvironmentSpecularScale = 0; Lighting.EnvironmentDiffuseScale = 0 end)
    end
end

local function applyOpt()
    local lvl = LEVELS[CFG.OPT_LEVEL] or 0
    if lvl == 0 then notify("Optimizador apagado"); return end
    if OPT.busy then return end
    OPT.busy = true
    task.spawn(function()
        pcall(optimizeGlobal, lvl)
        for _, o in ipairs(Lighting:GetDescendants()) do pcall(optimizeInstance, o, lvl) end
        local all = WS:GetDescendants()
        for i, o in ipairs(all) do
            pcall(optimizeInstance, o, lvl)
            if i % 300 == 0 then task.wait() end -- por tandas, sin congelar el juego
        end
        OPT.applied = lvl
        OPT.busy = false
        notify("Optimizador aplicado: " .. CFG.OPT_LEVEL .. " (" .. #all .. " objetos)")
    end)
end

WS.DescendantAdded:Connect(function(o)
    if CFG.OPT_NEW and OPT.applied > 0 then
        task.defer(function() pcall(optimizeInstance, o, OPT.applied) end)
    end
end)

-- ================= UI =================
local Win = Rayfield:CreateWindow({
    Name = "RAMHUB | AutoFarm Zombies", LoadingTitle = "RAMHUB", LoadingSubtitle = "AutoFarm Zombies by RAM",
    Icon = (LOGO_ID > 0) and LOGO_ID or "crosshair", ShowText = "RH", Theme = "Amethyst",
    ToggleUIKeybind = "F13", -- la tecla real del menu la maneja el script (CFG.MENU_KEY); F13 evita que se duplique
    ConfigurationSaving = { Enabled = false }, KeySystem = false,
})
local TMain = Win:CreateTab("Principal", "home")
local TAfk  = Win:CreateTab("AFK", "moon")
local TAim  = Win:CreateTab("Disparo", "crosshair")
local TMove = Win:CreateTab("Supervivencia", "shield")
local TFarm = Win:CreateTab("Recolección", "package")
local TOpt  = Win:CreateTab("Optimizador", "zap")
local TKeys = Win:CreateTab("Teclas", "keyboard")
local TSrv  = Win:CreateTab("Servidores", "server")

local function tg(tab, name, field, default, flag, cb)
    tab:CreateToggle({ Name = name, CurrentValue = CFG[field], Flag = flag, Callback = function(v)
        CFG[field] = v; if cb then cb(v) end; saveCfg()
    end })
end
local function sl(tab, name, field, rng, inc, def, suf, flag, scale)
    tab:CreateSlider({ Name = name, Range = rng, Increment = inc, Suffix = suf, CurrentValue = scale and math.floor(CFG[field] * scale + 0.5) or CFG[field], Flag = flag,
        Callback = function(v) CFG[field] = scale and v / scale or v; saveCfg() end })
end
local function dd(tab, name, field, opts, def, flag)
    tab:CreateDropdown({ Name = name, Options = opts, CurrentOption = {CFG[field]}, Flag = flag,
        Callback = function(o) CFG[field] = type(o) == "table" and o[1] or o; saveCfg() end })
end

TMain:CreateSection("RAMHUB")
local lblZ = TMain:CreateLabel("Zombies: 0")
local lblK = TMain:CreateLabel("Bajas: 0 (0/min)")
local lblM = TMain:CreateLabel("Dinero: +0 (0/h)")
local lblS = TMain:CreateLabel("Estado: listo")
tg(TMain, "Script activado", "ENABLED", true, "AF_On")
tg(TMain, "Mostrar HUD RAMHUB", "HUD_VISIBLE", true, "AF_HUD", function(v) HUD.gui.Enabled = v end)
tg(TMain, "Radar de zombies en el HUD", "HUD_RADAR", true, "AF_Radar")
sl(TMain, "Tamaño del HUD", "HUD_SCALE", {60,140}, 5, 100, "%", "AF_HUDScale", 100)
sl(TMain, "Transparencia del HUD", "HUD_ALPHA", {0,60}, 5, 5, "%", "AF_HUDAlpha", 100)
TMain:CreateButton({ Name = "Restablecer posición del HUD", Callback = function() HUD.resetPos() end })
tg(TMain, "Quedarse quieto en el spot (no moverse)", "HOLD_POSITION", true, "AF_Hold")
tg(TMain, "Autofarm (sin pulsar F)", "AUTOFARM", true, "AF_Auto", function(v) S.firing = v end)
tg(TMain, "Entrada de PC (clic derecho/teclas; necesita ventana activa)", "PC_INPUT", false, "AF_PC", function(v) if not v then releaseRight() end end)
tg(TMain, "Clic derecho mantenido (solo con entrada de PC)", "RIGHT_HOLD", true, "AF_RH", function(v) if not v then releaseRight() end end)
tg(TMain, "Mantener la mira siempre (aunque no haya zombie)", "ALWAYS_AIM", true, "AF_AA")
tg(TMain, "Anti-atasco", "ANTI_STUCK", true, "AF_Stuck")
tg(TMain, "Reconectar si te expulsan", "AUTO_REJOIN", true, "AF_Rejoin")
tg(TMain, "Modo ahorro (sin render 3D)", "SAVE_RENDER", false, "AF_Save", function() AFK.apply() end)
sl(TMain, "Límite de FPS (0 = sin cambios)", "FPS_CAP", {0,240}, 10, 0, "fps", "AF_FPS")
sl(TMain, "Distancia máxima", "MAX_DIST", {10, 3000}, 10, 1000, "unidades", "AF_Dist")
TMain:CreateButton({ Name = "Reiniciar estadísticas", Callback = function()
    S.kills = 0; S.t0 = os.clock(); moneyStart = getMoney() or 0
end })

TAfk:CreateSection("AFK total (ventana minimizada)")
TAfk:CreateLabel("Pasos: 1) equipa el arma  2) 'Aprender disparo' y dispara UNA vez a mano a un zombie  3) minimiza la ventana.")
tg(TAfk, "Modo AFK total (sin clics ni teclas reales)", "AFK_MODE", true, "AF_AFK", function() AFK.apply() end)
tg(TAfk, "Apagar el render 3D en AFK (ahorra GPU/CPU)", "AFK_NORENDER", true, "AF_AFKRender", function() AFK.apply() end)
sl(TAfk, "FPS máximos en AFK", "AFK_FPS", {10,60}, 5, 30, "fps", "AF_AFKFps")
TAfk:CreateButton({ Name = "Aprender disparo (luego dispara 1 vez a mano)", Callback = function() AFK.learn() end })
TAfk:CreateButton({ Name = "Olvidar disparo aprendido", Callback = function() AFK.forget() end })
AFK.lbl = TAfk:CreateLabel("Disparo aprendido: ninguno (se usará Tool:Activate)")
TAfk:CreateLabel("Sin disparo aprendido el script usa Tool:Activate; si tu arma lee el clic del ratón, aprende el disparo.")

dd(TAim, "Parte del cuerpo", "AIM_PART", {"Head","UpperTorso","HumanoidRootPart"}, "Head", "AF_Part")
dd(TAim, "Prioridad", "PRIORITY", {"Cercano","Menos vida"}, "Cercano", "AF_Prio")
tg(TAim, "Girar el personaje hacia el zombie al disparar", "FACE_TARGET", true, "AF_Face")
tg(TAim, "Mira suave (sin salto brusco de cámara)", "SMOOTH_AIM", true, "AF_Smooth")
sl(TAim, "Velocidad de giro", "TURN_SPEED", {5,100}, 5, 25, "%", "AF_Turn", 100)
TAim:CreateInput({ Name = "Nombre del arma (vacío = automático)", CurrentValue = CFG.WEAPON_NAME,
    PlaceholderText = "ej: AK47", RemoveTextAfterFocusLost = false, Flag = "AF_WName",
    Callback = function(t) CFG.WEAPON_NAME = t or ""; saveCfg() end })
sl(TAim, "Posición del arma en la mochila (si no hay nombre)", "WEAPON_SLOT", {1,9}, 1, 2, "", "AF_WSlot")
TAim:CreateInput({ Name = "Nombre del objeto de curar (opcional)", CurrentValue = CFG.HEAL_NAME,
    PlaceholderText = "ej: Medkit", RemoveTextAfterFocusLost = false, Flag = "AF_HName",
    Callback = function(t) CFG.HEAL_NAME = t or ""; saveCfg() end })
TAim:CreateButton({ Name = "Listar remotos del arma (consola F9)", Callback = function()
    local c = player.Character
    local t
    if c then for _, x in ipairs(c:GetChildren()) do if x:IsA("Tool") then t = x break end end end
    if not t then print("[RAMHUB] No hay arma equipada"); return end
    print("[RAMHUB] Arma:", t.Name)
    for _, d in ipairs(t:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") or d:IsA("LocalScript") or d:IsA("Script") then
            print("  -", d.ClassName, d:GetFullName())
        end
    end
end })
sl(TAim, "Retraso entre balas", "SHOT_DELAY", {40,300}, 10, 80, "ms", "AF_SD", 1000)
sl(TAim, "Balas por ráfaga", "BURST_SIZE", {1,10}, 1, 3, "", "AF_BS")
sl(TAim, "Pausa entre ráfagas", "BURST_PAUSE", {100,1000}, 25, 250, "ms", "AF_BP", 1000)
sl(TAim, "Alineación requerida", "AIM_STRICT", {85,100}, 1, 97, "%", "AF_AS", 100)
sl(TAim, "Cambiar de objetivo tras N disparos (0 = no)", "SWITCH_SHOTS", {0,30}, 1, 6, "tiros", "AF_SwShots")
sl(TAim, "Ignorar ese zombie durante", "SWITCH_TIME", {1,30}, 1, 5, "s", "AF_SwTime")
tg(TAim, "Recarga automática", "AUTO_RELOAD", true, "AF_AR")
sl(TAim, "Balas entre recargas (si no detecta munición)", "RELOAD_EVERY", {3,60}, 1, 12, "", "AF_RE")
TAim:CreateSection("Saltar animaciones")
tg(TAim, "Saltar animaciones (recarga/equipar)", "SKIP_ANIM", false, "AF_SkipAnim")
dd(TAim, "Modo de salto de animación", "SKIP_MODE", {"Acelerar","Detener"}, "Acelerar", "AF_SkipMode")
sl(TAim, "Velocidad de animaciones", "SKIP_SPEED", {2,50}, 1, 10, "x", "AF_SkipSpeed")
TAim:CreateSection("Modo discreto (menos descarado)")
tg(TAim, "Comportamiento humano (mira suave, retrasos, fallos)", "HUMAN", true, "AF_Human")
sl(TAim, "Tiempo de reacción máx. al ver un zombie", "HUMAN_REACT", {0,1000}, 50, 350, "ms", "AF_HReact", 1000)
sl(TAim, "Probabilidad de fallar un disparo", "HUMAN_MISS", {0,40}, 1, 8, "%", "AF_HMiss", 100)
sl(TAim, "Temblor de la mira", "HUMAN_JITTER", {0,20}, 1, 6, "x0.1", "AF_HJitter", 10)

dd(TMove, "Movimiento", "MOVE_MODE", {"Quieto","Alejarse","Seguir"}, "Alejarse", "AF_Move")
sl(TMove, "Alejarse: distancia mínima", "KITE_MIN", {5,100}, 5, 25, "unidades", "AF_Kite")
sl(TMove, "Seguir: distancia máxima", "FOLLOW_MAX", {10,200}, 5, 60, "unidades", "AF_Follow")
tg(TMove, "Huir con poca vida", "FLEE", true, "AF_Flee")
sl(TMove, "Huir bajo (% vida)", "FLEE_HP", {5,80}, 5, 30, "%", "AF_FleeHP", 100)
tg(TMove, "Curación automática", "AUTO_HEAL", false, "AF_Heal")
sl(TMove, "Curar bajo (% vida)", "HEAL_HP", {10,90}, 5, 50, "%", "AF_HealHP", 100)

tg(TFarm, "Recoger botín/dinero", "COLLECT", true, "AF_Collect")
tg(TFarm, "Pulsar E automáticamente al recoger", "AUTO_E", true, "AF_AutoE")
tg(TFarm, "Activar todos los botones E cercanos", "ALL_PROMPTS", true, "AF_AllPrompts")
sl(TFarm, "Rango de la E", "E_RANGE", {5,100}, 5, 25, "unidades", "AF_ERange")
sl(TFarm, "Rango de recogida", "COLLECT_RANGE", {20,1000}, 10, 300, "unidades", "AF_CR")
TFarm:CreateInput({ Name = "Palabras del botín (separadas por coma)", PlaceholderText = "cash,money,coin,loot", RemoveTextAfterFocusLost = false,
    Callback = function(t)
        local k = {}
        for w in t:gmatch("[^,%s]+") do k[#k+1] = w:lower() end
        if #k > 0 then
            CFG.COLLECT_KEYWORDS = k; drops = {}; saveCfg()
            task.spawn(function() for _, o in ipairs(WS:GetDescendants()) do addDrop(o) end end)
        end
    end })

-- Optimizador
TOpt:CreateSection("Rendimiento del juego")
TOpt:CreateLabel("Ligero: sin sombras/efectos/partículas. Fuerte: + materiales planos y sin texturas. Extremo: máximo FPS.")
dd(TOpt, "Nivel de optimización", "OPT_LEVEL", {"Apagado","Ligero","Fuerte","Extremo"}, "Ligero", "AF_OptLvl")
tg(TOpt, "Optimizar también objetos nuevos", "OPT_NEW", true, "AF_OptNew")
TOpt:CreateButton({ Name = "Aplicar optimización ahora", Callback = function() applyOpt() end })
TOpt:CreateLabel("Para quitar la optimización hay que volver a entrar al servidor. No toca personajes ni zombies.")

local function keyBtn(name, field)
    local b
    b = TKeys:CreateButton({ Name = name .. ": [" .. CFG[field].Name .. "]", Callback = function()
        S.waiting = {field, name, b}; b:Set(name .. ": [pulsa una tecla...]")
    end })
end
TSrv:CreateSection("Cambiar de servidor")
lblHop = TSrv:CreateLabel("Jugadores en este servidor: " .. #Players:GetPlayers())
TSrv:CreateButton({ Name = "Ir a un servidor vacío / con pocos jugadores", Callback = function() hop("manual", true) end })
TSrv:CreateButton({ Name = "Entrar a un servidor aleatorio", Callback = function()
    pcall(function() TPS:Teleport(game.PlaceId, player) end)
end })
sl(TSrv, "Máx. jugadores del servidor destino", "HOP_MAX_PLAYERS", {1,30}, 1, 3, "jugadores", "AF_HopMax")
tg(TSrv, "Cambiar solo si hay más jugadores que ese máximo", "AUTO_HOP", false, "AF_AutoHop")
sl(TSrv, "Cambiar si no hay zombies durante (0 = no)", "HOP_NO_ZOMBIES", {0,600}, 10, 0, "s", "AF_HopZ")
TSrv:CreateInput({ Name = "Archivo del script en workspace (re-ejecutar tras saltar)", CurrentValue = CFG.SCRIPT_FILE,
    PlaceholderText = "ej: ramhub_autofarm_v4.lua", RemoveTextAfterFocusLost = false, Flag = "AF_ScriptFile",
    Callback = function(t) CFG.SCRIPT_FILE = t or ""; saveCfg() end })
TSrv:CreateInput({ Name = "Link del script (loadstring) para re-ejecutar tras saltar", CurrentValue = CFG.SCRIPT_URL,
    PlaceholderText = "https://raw.githubusercontent.com/...", RemoveTextAfterFocusLost = false, Flag = "AF_ScriptURL",
    Callback = function(t) CFG.SCRIPT_URL = t or ""; saveCfg() end })
TSrv:CreateLabel("Guarda este script en la carpeta workspace de tu executor y pon aquí su nombre.")

TKeys:CreateLabel("Estas teclas (menos 'Abrir menú') solo se usan con 'Entrada de PC' activada. En celular abre el menú con el botón ≡ del HUD o el botón RH.")
keyBtn("Abrir menú", "MENU_KEY")
keyBtn("Arma", "WEAPON_KEY"); keyBtn("Recarga", "RELOAD_KEY"); keyBtn("Tecla extra", "SPAM_KEY")
keyBtn("Curar", "HEAL_KEY"); keyBtn("Activar", "TOGGLE_KEY")

-- ================= Input =================
-- Clic derecho robusto: usa mouse2press/mouse2release si existen, si no VIM en el centro de pantalla.
-- Se re-asegura solo: comprueba el estado real del boton y re-presiona si el juego lo suelta
-- (recarga, equipar arma, respawn, etc.).
local lastHold = 0
local function m2(down)
    if down and mouse2press then pcall(mouse2press)
    elseif not down and mouse2release then pcall(mouse2release)
    else
        local c = camera.ViewportSize / 2
        VIM:SendMouseButtonEvent(c.X, c.Y, 1, down, game, 0)
    end
end
releaseRight = function()
    if S.rightHeld then m2(false); S.rightHeld = false end
end
local function holdRight()
    if not CFG.RIGHT_HOLD or not CFG.PC_INPUT then return end
    local now = os.clock()
    local pressed = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    if not S.rightHeld then
        m2(true); S.rightHeld = true; lastHold = now
    elseif (not pressed and now - lastHold > 0.4) or now - lastHold > 2 then
        m2(false); m2(true); lastHold = now -- re-press
    end
end
local function tap(key)
    VIM:SendKeyEvent(true, key, false, game); task.wait(0.02); VIM:SendKeyEvent(false, key, false, game)
end

-- Un solo manejador de teclas. La tecla del menu se procesa ANTES de mirar gameProcessed,
-- asi funciona aunque el juego use Shift (sprint / shift-lock).
UIS.InputBegan:Connect(function(i, gp)
    if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if S.waiting then
        local f, n, b = unpack(S.waiting)
        CFG[f] = i.KeyCode; b:Set(n .. ": [" .. i.KeyCode.Name .. "]"); saveCfg(); S.waiting = nil
        return
    end
    if i.KeyCode == CFG.MENU_KEY and not UIS:GetFocusedTextBox() then
        toggleMenu()
        return
    end
    if gp then return end
    if i.KeyCode == CFG.TOGGLE_KEY and CFG.ENABLED then
        S.firing = not S.firing; S.burst = 0
        if not S.firing then releaseRight() end
    end
end)

player.Idled:Connect(function() VU:CaptureController(); VU:ClickButton2(Vector2.new()) end)

GuiServ.ErrorMessageChanged:Connect(function()
    if CFG.AUTO_REJOIN then task.wait(3); queueSelf(); pcall(function() TPS:Teleport(game.PlaceId, player) end) end
end)

-- ================= Logica =================
local function aimPartOf(m)
    local p = m:FindFirstChild(CFG.AIM_PART)
    if p and p:IsA("BasePart") then return p end
    for _, n in ipairs({"Head","UpperTorso","Torso","HumanoidRootPart"}) do
        p = m:FindFirstChild(n)
        if p and p:IsA("BasePart") then return p end
    end
    return m.PrimaryPart
end

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
local function los(from, to, myChar)
    rp.FilterDescendantsInstances = {myChar, hood}
    local r = WS:Raycast(from, to - from, rp)
    if not r then return true end
    local m = r.Instance:FindFirstAncestorOfClass("Model")
    return m ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil
end

local function tool(c)
    for _, x in ipairs(c:GetChildren()) do if x:IsA("Tool") then return x end end
end

-- ================= AFK TOTAL (sin ventana activa) =================
-- Con AFK_MODE el script NO usa clics/teclas reales (esos necesitan la ventana en primer plano).
-- Dispara con el "disparo aprendido": captura UNA vez el FireServer real del arma y lo repite
-- cambiando el punto de impacto / la parte / la direccion por las del zombie objetivo.
-- Sin disparo aprendido usa Tool:Activate (sirve si el arma usa Tool.Activated).
local AFK_KW = {"fire","shoot","shot","bullet","attack","hit","damage","gun"}

function AFK.cap()
    if CFG.AFK_MODE then
        return (CFG.FPS_CAP > 0) and math.min(CFG.FPS_CAP, CFG.AFK_FPS) or CFG.AFK_FPS
    end
    return CFG.FPS_CAP
end

function AFK.guard() -- evita que el juego reaccione a perder el foco
    pcall(function()
        if getconnections then
            for _, c in ipairs(getconnections(UIS.WindowFocusReleased)) do pcall(function() c:Disable() end) end
        end
    end)
end

function AFK.apply()
    if CFG.AFK_MODE and CFG.PC_INPUT then CFG.PC_INPUT = false; releaseRight() end
    pcall(function()
        RunServ:Set3dRenderingEnabled(not (CFG.SAVE_RENDER or (CFG.AFK_MODE and CFG.AFK_NORENDER)))
    end)
    if CFG.AFK_MODE then AFK.guard() end
    local cap = AFK.cap()
    if setfpscap then
        if cap > 0 then pcall(setfpscap, cap)
        elseif AFK.wasOn then pcall(setfpscap, 0) end
    end
    AFK.wasOn = CFG.AFK_MODE
    saveCfg()
end

task.spawn(function() -- arma equipada (la lee el hook sin hacer llamadas a instancias)
    while true do
        task.wait(0.5)
        local c = player.Character
        AFK.eqTool = c and tool(c) or nil
    end
end)

function AFK.hook()
    if AFK.hooked then return true end
    if not (hookmetamethod and getnamecallmethod) then return false end
    local old
    local function handler(self, ...)
        local method = getnamecallmethod()
        if AFK.learning and method == "FireServer" and not (checkcaller and checkcaller()) then
            local packed = table.pack(...)
            pcall(function()
                if typeof(self) == "Instance" and self.ClassName == "RemoteEvent" then
                    local n = self.Name:lower()
                    if not n:find("reload", 1, true) and not n:find("equip", 1, true) then
                        local match = false
                        for _, k in ipairs(AFK_KW) do if n:find(k, 1, true) then match = true break end end
                        if not match and AFK.eqTool then
                            local pr = self.Parent
                            while pr do
                                if pr == AFK.eqTool then match = true break end
                                pr = pr.Parent
                            end
                        end
                        if match then
                            AFK.fire = { remote = self, args = packed }
                            AFK.learning = false
                            local nm = self.Name
                            task.defer(function()
                                notify("Disparo aprendido: " .. nm)
                                if AFK.lbl then pcall(function() AFK.lbl:Set("Disparo aprendido: " .. nm) end) end
                            end)
                        end
                    end
                end
            end)
        end
        if setnamecallmethod then setnamecallmethod(method) end
        return old(self, ...)
    end
    local ok = pcall(function()
        old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(handler) or handler)
    end)
    if ok and old then AFK.hooked = true end
    return AFK.hooked
end

function AFK.learn()
    if not AFK.hook() then
        notify("Tu executor no soporta hookmetamethod: se usará Tool:Activate")
        return
    end
    AFK.learning = true
    notify("Equipa el arma y dispara UNA vez a mano a un zombie...")
end

function AFK.forget()
    AFK.fire, AFK.learning = nil, false
    if AFK.lbl then pcall(function() AFK.lbl:Set("Disparo aprendido: ninguno (se usará Tool:Activate)") end) end
end

-- sustituye en los argumentos capturados: origen -> camara, impacto -> zombie, parte/modelo -> zombie
local function subst(v, tpos, tpart, tmodel, thum, camPos, myChar, depth)
    local tv = typeof(v)
    if tv == "Vector3" then
        if math.abs(v.Magnitude - 1) < 0.02 then return (tpos - camPos).Unit end -- direccion
        if (v - camPos).Magnitude < 8 then return camPos end                     -- origen
        return tpos                                                              -- impacto
    elseif tv == "CFrame" then
        if (v.Position - camPos).Magnitude < 8 then return CFrame.new(camPos, tpos) end
        return CFrame.new(tpos)
    elseif tv == "Instance" then
        if v:IsA("BasePart") and not v:IsDescendantOf(myChar) then return tpart end
        if v:IsA("Humanoid") and v.Parent ~= myChar then return thum end
        if v:IsA("Model") and v ~= myChar and v:FindFirstChildOfClass("Humanoid") then return tmodel end
        return v
    elseif tv == "table" and depth < 2 then
        local out = {}
        for k, x in pairs(v) do out[k] = subst(x, tpos, tpart, tmodel, thum, camPos, myChar, depth + 1) end
        return out
    end
    return v
end

function AFK.shoot(target)
    local f = AFK.fire
    if not (f and f.remote and f.remote.Parent and f.args) then return false end
    local c = player.Character
    if not c then return false end
    local camPos = camera.CFrame.Position
    local args = {}
    for i = 1, f.args.n do
        args[i] = subst(f.args[i], target.p.Position, target.p, target.m, target.hum, camPos, c, 0)
    end
    return (pcall(function() f.remote:FireServer(table.unpack(args, 1, f.args.n)) end))
end

-- ===== Acciones DENTRO del juego (sin teclado/raton de PC) =====
local function findToolByName(c, name)
    if not name or name == "" then return nil end
    local t = c:FindFirstChild(name)
    if t and t:IsA("Tool") then return t end
    local bp = player:FindFirstChildOfClass("Backpack")
    t = bp and bp:FindFirstChild(name)
    if t and t:IsA("Tool") then return t end
end
local function findWeapon(c)
    local w = findToolByName(c, CFG.WEAPON_NAME)
    if w or CFG.WEAPON_NAME ~= "" then return w end
    local eq = tool(c)
    if eq then return eq end
    local bp = player:FindFirstChildOfClass("Backpack")
    if bp then
        local n = 0
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then
                n += 1
                if n == CFG.WEAPON_SLOT then return t end
            end
        end
    end
end
local function equipWeapon(c, hum)
    local w = findWeapon(c)
    if w and w.Parent ~= c then pcall(function() hum:EquipTool(w) end) end
end

local remoteCache = setmetatable({}, { __mode = "k" })
local function findRemote(t, kw)
    local c = remoteCache[t]
    if not c then c = {}; remoteCache[t] = c end
    if c[kw] == nil then
        c[kw] = false
        for _, d in ipairs(t:GetDescendants()) do
            if (d:IsA("RemoteEvent") or d:IsA("BindableEvent")) and d.Name:lower():find(kw, 1, true) then
                c[kw] = d; break
            end
        end
    end
    return c[kw]
end
local function doReload(t)
    if CFG.PC_INPUT then task.spawn(tap, CFG.RELOAD_KEY); return true end
    local r = t and findRemote(t, "reload")
    if r then
        pcall(function() if r:IsA("RemoteEvent") then r:FireServer() else r:Fire() end end)
        return true
    end
    return false
end
local function fireShot(t)
    task.spawn(function()
        if CFG.PC_INPUT then
            local c = camera.ViewportSize / 2
            VIM:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 0)
            task.wait(0.02)
            VIM:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 0)
        else
            pcall(function() t:Activate() end)
            task.wait(0.02)
            pcall(function() t:Deactivate() end)
        end
    end)
end
local function healNow(c, hum)
    if S.healing then return end
    local h = findToolByName(c, CFG.HEAL_NAME)
    if not h then
        if CFG.PC_INPUT then task.spawn(tap, CFG.HEAL_KEY) end
        return
    end
    S.healing = true
    task.spawn(function()
        pcall(function() hum:EquipTool(h) end); task.wait(0.3)
        pcall(function() h:Activate() end); task.wait(1.5)
        S.healing = false
        equipWeapon(c, hum)
    end)
end

-- ammo real si el juego lo expone (atributo o NumberValue); nil si no se detecta
local AMMO = {"Ammo","CurrentAmmo","Mag","Magazine","Clip","Bullets"}
local function readAmmo(t)
    if not t then return nil end
    for _, n in ipairs(AMMO) do
        local a = t:GetAttribute(n)
        if type(a) == "number" then return a end
        local v = t:FindFirstChild(n, true)
        if v and v:IsA("ValueBase") and type(v.Value) == "number" then return v.Value end
    end
end

local function scan(root, myChar)
    local list, cam = {}, camera.CFrame.Position
    for m, hum in pairs(zombies) do
        if m.Parent and hum.Health > 0 then
            local p = aimPartOf(m)
            if p then
                local d = (root.Position - p.Position).Magnitude
                if d <= CFG.MAX_DIST then list[#list+1] = {m = m, p = p, hum = hum, d = d} end
            end
        end
    end
    local byHp = CFG.PRIORITY == "Menos vida"
    table.sort(list, function(a, b)
        if byHp then return a.hum.Health < b.hum.Health end
        return a.d < b.d
    end)
    local nearest = list[1]
    -- zombies a los que ya se les dispararon demasiados tiros: se ignoran un rato
    local now = os.clock()
    local pool = {}
    for _, e in ipairs(list) do
        local exp = S.skip[e.m]
        if not exp or now >= exp then pool[#pool + 1] = e end
    end
    if #pool == 0 then pool = list end -- si solo quedan descartados, seguimos con ellos
    -- objetivo fijo: mantiene el actual mientras viva y con LOS (evita parpadeo)
    if S.target and S.target.m.Parent and S.target.hum.Health > 0 then
        for _, e in ipairs(pool) do
            if e.m == S.target.m and los(cam, e.p.Position, myChar) then S.target = e; return e, #list, nearest end
        end
    end
    S.target = nil
    for _, e in ipairs(pool) do
        if los(cam, e.p.Position, myChar) then S.target = e; return e, #list, nearest end
    end
    return nil, #list, nearest
end

local function nearestDrop(root)
    local best, bd = nil, CFG.COLLECT_RANGE
    for part, pr in pairs(drops) do
        if part.Parent then
            local d = (root.Position - part.Position).Magnitude
            if d < bd then best, bd = {part = part, prompt = pr, d = d}, d end
        else drops[part] = nil end
    end
    return best
end

local function collect(root, hum, dr)
    if CFG.HOLD_POSITION then -- sin moverse: solo interaccion a distancia
        if dr.prompt and fireproximityprompt then pcall(fireproximityprompt, dr.prompt)
        elseif firetouchinterest then
            pcall(function() firetouchinterest(root, dr.part, 0); firetouchinterest(root, dr.part, 1) end)
        end
        return
    end
    if dr.d > 8 then hum:MoveTo(dr.part.Position); return end
    if dr.prompt and fireproximityprompt then pcall(fireproximityprompt, dr.prompt)
    elseif firetouchinterest then
        pcall(function() firetouchinterest(root, dr.part, 0); firetouchinterest(root, dr.part, 1) end)
    else hum:MoveTo(dr.part.Position) end
end

local function move(root, hum, nearest)
    if CFG.HOLD_POSITION or CFG.MOVE_MODE == "Quieto" or not nearest then return end
    local d = nearest.d
    if CFG.MOVE_MODE == "Alejarse" and d < CFG.KITE_MIN then
        local away = (root.Position - nearest.p.Position) * Vector3.new(1, 0, 1)
        if away.Magnitude > 0 then hum:MoveTo(root.Position + away.Unit * 15) end
    elseif CFG.MOVE_MODE == "Seguir" and d > CFG.FOLLOW_MAX then
        hum:MoveTo(nearest.p.Position)
    end
end

-- ================= Loops auxiliares =================
task.spawn(function() -- equipar arma
    while true do
        task.wait(0.5)
        local c = player.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if CFG.ENABLED and S.firing and hum and hum.Health > 0 and not S.healing then
            if CFG.PC_INPUT and CFG.WEAPON_NAME == "" then
                if not tool(c) then tap(CFG.WEAPON_KEY); S.rightHeld = false end
            else
                local w = findWeapon(c)
                if w and w.Parent ~= c then equipWeapon(c, hum); S.rightHeld = false end
            end
        end
    end
end)

task.spawn(function() -- limite de FPS (ahorro / segundo plano)
    while true do
        task.wait(5)
        local cap = AFK.cap()
        if cap > 0 and setfpscap then pcall(setfpscap, cap) end
    end
end)

-- E automatica: dispara los ProximityPrompt cercanos (sin espera) y spamea la tecla E
local function promptMatches(pr)
    local txt = ((pr.Parent and pr.Parent.Name or "") .. " " .. pr.ObjectText .. " " .. pr.ActionText):lower()
    for _, k in ipairs(CFG.COLLECT_KEYWORDS) do if txt:find(k, 1, true) then return true end end
    return false
end
task.spawn(function()
    while true do
        task.wait(0.12)
        local c = player.Character
        local root = c and c:FindFirstChild("HumanoidRootPart")
        if CFG.ENABLED and S.firing and CFG.COLLECT and CFG.AUTO_E and root and not S.healing then
            local near = false
            for pr in pairs(prompts) do
                local part = pr.Parent
                if part and pr.Enabled then
                    local pos = part:IsA("BasePart") and part.Position or (part:IsA("Attachment") and part.WorldPosition)
                    if pos and (pos - root.Position).Magnitude <= CFG.E_RANGE then
                        near = true
                        if CFG.ALL_PROMPTS or promptMatches(pr) then
                            pcall(function() pr.HoldDuration = 0 end)
                            if fireproximityprompt then pcall(fireproximityprompt, pr) end
                        end
                    end
                end
            end
            if not near then
                for part in pairs(drops) do
                    if part.Parent and (part.Position - root.Position).Magnitude <= CFG.E_RANGE then near = true break end
                end
            end
            if CFG.PC_INPUT and (near or S.target) then task.spawn(tap, CFG.SPAM_KEY) end
        end
    end
end)

task.spawn(function() -- stats
    while true do
        task.wait(1)
        local mins = math.max((os.clock() - S.t0) / 60, 1/60)
        local gain = (getMoney() or moneyStart) - moneyStart
        pcall(function()
            lblK:Set(string.format("Bajas: %d (%.1f/min)", S.kills, S.kills / mins))
            lblM:Set(string.format("Dinero: +%d (%d/h)", math.floor(gain), math.floor(gain / mins * 60)))
        end)
    end
end)

task.spawn(function() -- anti-stuck: salta si no avanza mientras intenta moverse
    while true do
        task.wait(1)
        local c = player.Character
        local root, hum = c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
        if CFG.ANTI_STUCK and not CFG.HOLD_POSITION and root and hum and S.firing and CFG.MOVE_MODE ~= "Quieto" then
            if S.lastPos and (root.Position - S.lastPos).Magnitude < 0.5 and hum.MoveDirection.Magnitude > 0 then
                S.stuckT += 1
                if S.stuckT >= 2 then hum.Jump = true; S.stuckT = 0 end
            else S.stuckT = 0 end
            S.lastPos = root.Position
        end
    end
end)

-- ================= Loop principal =================
local acc, uiAcc = 0, 0
RunServ.Heartbeat:Connect(function(dt)
    acc += dt; uiAcc += dt
    if acc < 0.03 then return end
    acc = 0
    local ui = uiAcc >= 0.25
    if ui then uiAcc = 0 end
    local function status(t)
        HUD.stateText = (t:gsub("^Estado: ", ""))
        if ui then pcall(function() lblS:Set(t) end) end
    end

    local myChar = player.Character
    local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local root = myChar and myChar:FindFirstChild("HumanoidRootPart")

    if not CFG.ENABLED or not S.firing or not hum or hum.Health <= 0 or not root then
        releaseRight(); S.burst = 0; S.target = nil
        status(CFG.ENABLED and "Estado: en espera" or "Estado: desactivado")
        return
    end

    if not S.safePos then S.safePos = root.Position end
    local hpPct = hum.Health / math.max(hum.MaxHealth, 1)

    if CFG.ALWAYS_AIM then holdRight() end

    -- curacion
    if CFG.AUTO_HEAL and hpPct < CFG.HEAL_HP and os.clock() - S.lastHeal > 5 then
        S.lastHeal = os.clock(); healNow(myChar, hum)
    end

    local target, count, nearest = scan(root, myChar)
    if ui then pcall(function() lblZ:Set("Zombies: " .. count) end) end

    -- huida
    if CFG.FLEE and not CFG.HOLD_POSITION and hpPct < CFG.FLEE_HP and nearest and nearest.d < 40 then
        hum:MoveTo(S.safePos)
        status(string.format("Huyendo (vida %d%%)", math.floor(hpPct * 100)))
    else
        move(root, hum, nearest)
    end

    -- sin objetivo: recoger drops
    if not target then
        if not CFG.ALWAYS_AIM then releaseRight() end
        if CFG.COLLECT and (not CFG.HOLD_POSITION or fireproximityprompt or firetouchinterest) then
            local dr = nearestDrop(root)
            if dr then collect(root, hum, dr); status(string.format("Recogiendo botín (%.0f unidades)", dr.d)); return end
        end
        status(count == 0 and "Estado: sin zombies" or "Estado: sin línea de visión")
        return
    end

    if S.healing then return end
    holdRight()
    local now = os.clock()

    -- apuntar: la camara y el personaje giran hacia el zombie de forma gradual
    local pos = target.p.Position
    local alpha = CFG.TURN_SPEED
    local smooth = CFG.SMOOTH_AIM
    if CFG.HUMAN then
        pos = pos + Vector3.new(math.noise(now * 1.3, 1.1, 0), math.noise(now * 1.1, 2.2, 0),
            math.noise(now * 0.9, 3.3, 0)) * CFG.HUMAN_JITTER
        alpha = math.clamp(dt * 14, 0.06, 0.4) * (0.8 + math.random() * 0.4)
        smooth = true
        if S.lastTargetM ~= target.m then
            S.lastTargetM = target.m
            S.reactUntil = now + 0.08 + math.random() * CFG.HUMAN_REACT
        end
    end
    local goal = CFrame.new(camera.CFrame.Position, pos)
    camera.CFrame = smooth and camera.CFrame:Lerp(goal, alpha) or goal
    local faceOk = true
    if CFG.FACE_TARGET then
        local flat = Vector3.new(pos.X, root.Position.Y, pos.Z)
        if (flat - root.Position).Magnitude > 0.5 then
            root.CFrame = root.CFrame:Lerp(CFrame.lookAt(root.Position, flat), alpha)
            faceOk = root.CFrame.LookVector:Dot((flat - root.Position).Unit) > 0.95
        end
    end
    local dot = camera.CFrame.LookVector:Dot((pos - camera.CFrame.Position).Unit)
    status(string.format("Objetivo a %.0f unidades | alineación %.2f", target.d, dot))

    if CFG.HUMAN and S.reactUntil and now < S.reactUntil then return end
    if now - S.lastBurst < (S.nextPause or CFG.BURST_PAUSE) or now - S.lastShot < (S.nextDelay or CFG.SHOT_DELAY) then return end

    if dot >= CFG.AIM_STRICT and faceOk and target.hum.Health > 0 then
        local wt = tool(myChar)
        if not wt then return end
        if CFG.HUMAN and math.random() < CFG.HUMAN_MISS then
            S.lastShot = now; S.nextDelay = CFG.SHOT_DELAY * (1 + math.random()); return
        end
        if not (CFG.AFK_MODE and AFK.shoot(target)) then fireShot(wt) end
        S.lastShot = now; S.shots += 1; S.burst += 1
        if S.curM ~= target.m then S.curM = target.m; S.curShots = 0 end
        S.curShots += 1
        if CFG.SWITCH_SHOTS > 0 and S.curShots >= CFG.SWITCH_SHOTS then
            S.skip[target.m] = now + CFG.SWITCH_TIME -- pasa al siguiente zombie
            S.target = nil; S.curM = nil; S.curShots = 0
        end
        S.nextDelay = CFG.SHOT_DELAY * (CFG.HUMAN and (0.8 + math.random() * 0.8) or 1)
        if S.burst >= CFG.BURST_SIZE then
            S.burst = 0; S.lastBurst = now
            S.nextPause = CFG.BURST_PAUSE * (CFG.HUMAN and (0.7 + math.random() * 1.2) or 1)
        end

        if CFG.AUTO_RELOAD then
            local ammo = readAmmo(tool(myChar))
            local need = (ammo ~= nil and ammo <= 0) or (ammo == nil and S.shots % CFG.RELOAD_EVERY == 0)
            if need and doReload(tool(myChar)) then S.lastBurst = now + 1.2; S.rightHeld = false end
        end
    end
end)

-- ================= Skip de animaciones =================
local animConn
local function hookAnimator(char)
    if animConn then animConn:Disconnect(); animConn = nil end
    local hum = char:WaitForChild("Humanoid", 10)
    local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5))
    if not animator then return end
    animConn = animator.AnimationPlayed:Connect(function(track)
        if not CFG.SKIP_ANIM or track.Looped then return end
        pcall(function()
            if CFG.SKIP_MODE == "Detener" then track:Stop(0)
            else track:AdjustSpeed(CFG.SKIP_SPEED) end
        end)
    end)
end
if player.Character then task.spawn(hookAnimator, player.Character) end
player.CharacterAdded:Connect(function(c) task.spawn(hookAnimator, c) end)

player.OnTeleport:Connect(function() S.firing = false; releaseRight() end)
player.CharacterAdded:Connect(function()
    task.wait(0.5)
    S.burst = 0; S.target = nil; S.safePos = nil; releaseRight(); S.firing = CFG.AUTOFARM
end)

-- aplicar el optimizador al arrancar (con el nivel guardado)
task.delay(3, function()
    AFK.apply()
    if (LEVELS[CFG.OPT_LEVEL] or 0) > 0 then applyOpt() end
end)

pcall(function() Rayfield:Notify({ Title = "RAMHUB", Content = "AutoFarm v4 cargado", Duration = 4 }) end)
print("[RAMHUB] listo")
