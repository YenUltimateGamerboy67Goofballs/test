--[[
    RavineUI - Modern Dashboard UI Library
    Version 2.6 - CRIMSON EDITION

    Farben: Crimson (rot)
    Icons: Lucide (lucide-roblox-direct, mit Fallback)
]]

local RavineUI = {
    Version = "2.6.0",
    Toggles = {},
    Options = {},
    CustomIcons = {},
}

RavineUI.__index = RavineUI
RavineUI.Build = "ravine-26-crimson"

-- ============ SERVICES ============
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local LocalizationService = game:GetService("LocalizationService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

RavineUI.IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
RavineUI.MobileScale = 0.7

local GENV = (getgenv and getgenv()) or _G
if GENV.RavineUI_Instance and GENV.RavineUI_Instance.Unload then
    pcall(GENV.RavineUI_Instance.Unload, GENV.RavineUI_Instance)
end
GENV.RavineUI_Instance = RavineUI

local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local Groupbox = {}
Groupbox.__index = Groupbox

-- ============ THEME (CRIMSON) ============
local Theme = {
    Background = Color3.fromRGB(10, 10, 13),
    Secondary = Color3.fromRGB(16, 16, 20),
    Tertiary = Color3.fromRGB(24, 24, 29),
    Card = Color3.fromRGB(7, 7, 9),
    Border = Color3.fromRGB(42, 42, 50),
    BorderLight = Color3.fromRGB(55, 55, 65),
    Divider = Color3.fromRGB(70, 70, 84),
    Text = Color3.fromRGB(235, 235, 240),
    SubText = Color3.fromRGB(140, 140, 155),
    Accent = Color3.fromRGB(200, 30, 40),
    AccentDark = Color3.fromRGB(140, 20, 28),
    ToggleOn = Color3.fromRGB(200, 30, 40),
    ToggleOff = Color3.fromRGB(55, 55, 65),
    Success = Color3.fromRGB(46, 204, 113),
    Warning = Color3.fromRGB(236, 190, 60),
    Error = Color3.fromRGB(231, 76, 60),
    Font = Enum.Font.GothamMedium,
    FontBold = Enum.Font.GothamBold,
    TextSize = 14,
    CornerRadius = 6,
}
RavineUI.Theme = Theme

RavineUI.ThemeState = {
    Preset = "Crimson",
    Accent = Theme.Accent,
    Rainbow = false,
    RainbowSpeed = 0.15,
    Transparency = 0.04,
    Animations = true,
}

local ThemeBinds = setmetatable({}, { __mode = "k" })
local ThemeHooks = {}
local ThemedProps = {
    BackgroundColor3 = true,
    TextColor3 = true,
    ImageColor3 = true,
    BorderColor3 = true,
    Color = true,
    ScrollBarImageColor3 = true,
    PlaceholderColor3 = true,
}

local function BindTheme(inst, prop, value)
    if typeof(value) ~= "Color3" then return end
    for key, c in pairs(Theme) do
        if typeof(c) == "Color3" and c == value then
            local list = ThemeBinds[inst]
            if not list then
                list = {}
                ThemeBinds[inst] = list
            end
            table.insert(list, { prop, key })
            return
        end
    end
end

-- ============ UTILITIES ============
local Connections = {}

local function Connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Connections, c)
    return c
end

local function Create(className, props, noTheme)
    local inst = Instance.new(className)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then
            parent = v
        else
            inst[k] = v
            if not noTheme and ThemedProps[k] then
                BindTheme(inst, k, v)
            end
        end
    end
    if parent then inst.Parent = parent end
    return inst
end

local function Corner(inst, radius)
    return Create("UICorner", { CornerRadius = UDim.new(0, radius or Theme.CornerRadius), Parent = inst })
end

local function Stroke(inst, color, thickness)
    return Create("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = inst,
    })
end

local function Tween(inst, time, props, style, dir)
    local t = TweenService:Create(inst, TweenInfo.new(
        time or 0.15,
        style or Enum.EasingStyle.Quad,
        dir or Enum.EasingDirection.Out
    ), props)
    t:Play()
    return t
end

local function Anim()
    return RavineUI.ThemeState.Animations ~= false
end

local CountTokens = setmetatable({}, { __mode = "k" })
local function CountTo(label, from, to, fmt, dur)
    fmt = fmt or tostring
    CountTokens[label] = (CountTokens[label] or 0) + 1
    local token = CountTokens[label]
    if not Anim() or from == to then
        label.Text = fmt(to)
        return
    end
    dur = dur or 0.9
    task.spawn(function()
        local t0 = os.clock()
        while CountTokens[label] == token and label.Parent do
            local a = math.clamp((os.clock() - t0) / dur, 0, 1)
            local e = 1 - (1 - a) ^ 3
            label.Text = fmt(math.floor(from + (to - from) * e + 0.5))
            if a >= 1 then return end
            task.wait()
        end
    end)
end

local function NumFmt(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

local function Ripple(btn, color)
    btn.ClipsDescendants = true
    btn.InputBegan:Connect(function(input)
        if not Anim() then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local abs, sz = btn.AbsolutePosition, btn.AbsoluteSize
        if sz.X <= 0 or sz.Y <= 0 then return end
        local uis = (RavineUI._scaleInst and RavineUI._scaleInst.Scale) or 1
        local rx = math.clamp((input.Position.X - abs.X) / sz.X, 0, 1)
        local ry = math.clamp((input.Position.Y - abs.Y) / sz.Y, 0, 1)
        local d = math.max(sz.X, sz.Y) * 2.2 / math.max(uis, 0.05)
        local dot = Create("Frame", {
            BackgroundColor3 = color or Color3.new(1, 1, 1),
            BackgroundTransparency = 0.82, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(rx, ry),
            Size = UDim2.fromOffset(0, 0),
            ZIndex = 10, Parent = btn,
        }, true)
        Corner(dot, 1000)
        Tween(dot, 0.55, { Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        task.delay(0.6, function() dot:Destroy() end)
    end)
end

local function Gradient(frame, keypoints, rotation)
    local seq = {}
    for _, k in ipairs(keypoints) do
        table.insert(seq, ColorSequenceKeypoint.new(k[1], k[2]))
    end
    return Create("UIGradient", { Color = ColorSequence.new(seq), Rotation = rotation or 0, Parent = frame })
end

local function Glow(parent, color, rotation, strength)
    local g = Create("Frame", {
        Name = "Glow", BackgroundColor3 = color, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = parent,
    })
    Corner(g, 10)
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1 - (strength or 0.5)),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Rotation = rotation or 0, Parent = g,
    })
    return g
end

local function Round(v, decimals)
    local m = 10 ^ (decimals or 0)
    return math.floor(v * m + 0.5) / m
end

local function ScaleColor(c, f)
    return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

local function Arg(obj, a, b)
    if a == obj then return b end
    return a
end

local function FormatTime(s)
    s = math.floor(s)
    return string.format("%02d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
end

local function Plural(n, word)
    if n == 0 then return "no " .. word .. "s" end
    return n .. " " .. word .. (n == 1 and "" or "s")
end

local function Copy(text)
    local fn = setclipboard or toclipboard or set_clipboard
    if fn then return pcall(fn, text) end
    return false
end

local function MakeDraggable(frame, handle, getScale)
    local state = { Moved = 0 }
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            state.Moved = 0
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    Connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local s = getScale and getScale() or 1
            local d = (input.Position - dragStart) / s
            state.Moved = math.max(state.Moved, d.Magnitude)
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
    return state
end

local function TrackDrag(hit, column, onMove, onBegin, onEnd)
    local dragging = false
    local function setScroll(v)
        if column then column.ScrollingEnabled = v end
    end
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setScroll(false)
            if onBegin then onBegin() end
            onMove(input.Position)
        end
    end)
    Connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            onMove(input.Position)
        end
    end)
    Connect(UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            setScroll(true)
            if onEnd then onEnd() end
        end
    end)
end

-- ============ LUCIDE ICONS (robust) ============
local IconModule

-- 1) Cache probieren
if type(isfile) == "function" and type(readfile) == "function" then
    local ok, cached = pcall(function()
        if isfile("RavineUI/lucide.lua") then return readfile("RavineUI/lucide.lua") end
        return nil
    end)
    if ok and type(cached) == "string" and cached ~= "" then
        local ok2, mod = pcall(function() return loadstring(cached)() end)
        if ok2 and type(mod) == "table" and mod.GetAsset then
            IconModule = mod
        end
    end
end

-- 2) Aus dem Internet laden (mehrere URLs)
if not IconModule then
    local IconSources = {
        "https://raw.githubusercontent.com/mstudio45/lucide-roblox-direct/refs/heads/main/source.lua",
        "https://raw.githubusercontent.com/mstudio45/lucide-roblox-direct/main/source.lua",
        "https://raw.githubusercontent.com/mstudio45/lucide-roblox-direct/master/source.lua",
    }
    for _, url in ipairs(IconSources) do
        local ok, mod = pcall(function()
            local src = game:HttpGet(url)
            return loadstring(src)()
        end)
        if ok and type(mod) == "table" and mod.GetAsset then
            IconModule = mod
            -- Cache für nächstes Mal
            if type(writefile) == "function" and type(makefolder) == "function" and type(isfolder) == "function" then
                pcall(function()
                    if not isfolder("RavineUI") then makefolder("RavineUI") end
                    writefile("RavineUI/lucide.lua", game:HttpGet(url))
                end)
            end
            break
        end
    end
end

if IconModule then
    print("[RavineUI] Lucide Icons geladen: OK")
else
    warn("[RavineUI] Lucide Icons NICHT geladen - Icons = Buchstaben-Fallback")
end

local IconAliases = {
    home = "house", gear = "settings", close = "x", plus = "plus", search = "search",
    minus = "minus", trash = "trash-2", folder = "folder", save = "save", load = "folder-open",
    refresh = "refresh-cw", check = "check", warning = "triangle-alert", error = "circle-x",
    success = "circle-check", info = "info", user = "user", users = "users", shield = "shield",
    lock = "lock", key = "key", eye = "eye", eye_off = "eye-off", bell = "bell", zap = "zap",
    star = "star", heart = "heart", palette = "palette", settings = "settings",
    tools = "wrench", cloud = "cloud", sun = "sun", moon = "moon", sparkles = "sparkles",
    gamepad = "gamepad-2", sword = "sword", swords = "swords",
}

function RavineUI:SetIconModule(mod) IconModule = mod end
function RavineUI:AddIcon(name, asset)
    local url = type(asset) == "number" and ("rbxassetid://" .. asset) or asset
    self.CustomIcons[name] = {
        Url = url,
        ImageRectOffset = Vector2.new(0, 0),
        ImageRectSize = Vector2.new(0, 0),
    }
end

function RavineUI:GetIcon(icon)
    local t = type(icon)
    if t == "table" then return icon.Url and icon or nil end
    if t == "number" then
        return { Url = "rbxassetid://" .. icon, ImageRectOffset = Vector2.new(0, 0), ImageRectSize = Vector2.new(0, 0) }
    end
    if t ~= "string" or icon == "" then return nil end
    if self.CustomIcons[icon] then return self.CustomIcons[icon] end
    if icon:sub(1, 13) == "rbxassetid://" or icon:sub(1, 4) == "http" then
        return { Url = icon, ImageRectOffset = Vector2.new(0, 0), ImageRectSize = Vector2.new(0, 0) }
    end
    if tonumber(icon) then return self:GetIcon(tonumber(icon)) end
    local name = (icon:gsub("^lucide[-:]", ""))
    name = IconAliases[name] or name
    if IconModule and IconModule.GetAsset then
        local ok, data = pcall(IconModule.GetAsset, name)
        if ok and data then return data end
    end
    return nil
end

local function SetIcon(img, icon)
    local data = RavineUI:GetIcon(icon)
    if not data then return false end
    img.Image = data.Url
    img.ImageRectOffset = data.ImageRectOffset or Vector2.new(0, 0)
    img.ImageRectSize = data.ImageRectSize or Vector2.new(0, 0)
    return true
end

local function NewIcon(parent, icon, px, color, fallback)
    local img = Create("ImageLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromOffset(px, px),
        ImageColor3 = color, ScaleType = Enum.ScaleType.Fit, Parent = parent,
    })
    if SetIcon(img, icon) then
        return { Instance = img, Prop = "ImageColor3", Ok = true }
    end
    img:Destroy()
    local lbl = Create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromOffset(px, px),
        Font = Theme.FontBold, Text = fallback or "?", TextColor3 = color,
        TextSize = math.floor(px * 0.85), Parent = parent,
    })
    return { Instance = lbl, Prop = "TextColor3", Ok = false }
end

local function TintIcon(ic, color, time)
    Tween(ic.Instance, time or 0.15, { [ic.Prop] = color })
end

local function IsCustomImage(icon)
    local t = type(icon)
    if t == "number" then return true end
    if t == "string" then
        return icon:sub(1, 13) == "rbxassetid://" or icon:sub(1, 4) == "http" or tonumber(icon) ~= nil
    end
    return false
end

-- ============ OPTION REGISTRY ============
local function NewOption(kind, id, value)
    local obj = { Type = kind, Id = id, Value = value, _changed = {} }
    function obj:OnChanged(fn)
        table.insert(self._changed, fn)
        return self
    end
    local function changed(v)
        obj.Value = v
        for _, fn in ipairs(obj._changed) do task.spawn(fn, v) end
    end
    local registry = (kind == "Toggle") and RavineUI.Toggles or RavineUI.Options
    registry[id] = obj
    return obj, changed
end

-- ============ GUI CONTAINER ============
local function GetGuiParent()
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then return hui end
    return CoreGui
end

local function EnsureGui()
    if RavineUI.Gui and RavineUI.Gui.Parent then return RavineUI.Gui end
    RavineUI.Gui = Create("ScreenGui", {
        Name = "RavineUI", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100, Parent = GetGuiParent(),
    })
    return RavineUI.Gui
end

-- ============ TOOLTIP ============
local Tip = { Frame = nil, Label = nil, Conn = nil, Token = 0, Bounds = nil }

local function TipEnsure()
    if Tip.Frame and Tip.Frame.Parent then return Tip.Frame end
    local gui = EnsureGui()
    local f = Create("Frame", {
        Name = "Tooltip", BackgroundColor3 = Theme.Secondary, BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0),
        Visible = false, ZIndex = 1000, Parent = gui,
    })
    Corner(f, 6)
    Stroke(f, Theme.Border, 1)
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), Parent = f,
    })
    local label = Create("TextLabel", {
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.fromOffset(0, 0), Font = Theme.Font, Text = "",
        TextColor3 = Theme.Text, TextSize = 12, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 1001, Parent = f,
    })
    Create("UISizeConstraint", { MaxSize = Vector2.new(260, 1000), Parent = label })
    Tip.Frame = f
    Tip.Label = label
    return f
end

local function TipHide()
    Tip.Token = Tip.Token + 1
    Tip.Bounds = nil
    if Tip.Conn then Tip.Conn:Disconnect(); Tip.Conn = nil end
    if Tip.Frame then Tip.Frame.Visible = false end
end

local function TipHideFor(bounds)
    if Tip.Bounds == bounds then TipHide() end
end

local function TipPlace(tx, ty, flipY)
    local f = Tip.Frame
    if not f then return end
    local vp = (RavineUI.Gui and RavineUI.Gui.AbsoluteSize) or Vector2.new(1920, 1080)
    local sz = f.AbsoluteSize
    local px = math.clamp(tx, 4, math.max(vp.X - sz.X - 4, 4))
    local py = ty
    if py + sz.Y > vp.Y - 4 then py = flipY - sz.Y end
    f.Position = UDim2.fromOffset(px, math.max(py, 4))
end

local function TipShow(text, bounds)
    TipHide()
    if not text or text == "" then return end
    local f = TipEnsure()
    Tip.Label.Text = text
    Tip.Bounds = bounds
    f.Visible = true
    local function update()
        if bounds and not bounds.Parent then TipHide(); return end
        local m = UserInputService:GetMouseLocation()
        if bounds then
            local p, sz = bounds.AbsolutePosition, bounds.AbsoluteSize
            if m.X < p.X or m.Y < p.Y or m.X > p.X + sz.X or m.Y > p.Y + sz.Y then
                TipHide(); return
            end
        end
        TipPlace(m.X + 14, m.Y + 18, m.Y - 10)
    end
    update()
    if Tip.Frame and Tip.Frame.Visible then
        Tip.Conn = RunService.RenderStepped:Connect(update)
    end
end

local function TipFlash(text, target)
    TipHide()
    if not text or text == "" then return end
    local f = TipEnsure()
    Tip.Label.Text = text
    Tip.Bounds = target
    f.Visible = true
    local token = Tip.Token
    local function place()
        if Tip.Token == token and target.Parent then
            local p, sz = target.AbsolutePosition, target.AbsoluteSize
            TipPlace(p.X, p.Y + sz.Y + 6, p.Y - 6)
        end
    end
    place()
    task.defer(place)
    task.delay(2.5, function()
        if Tip.Token == token then TipHide() end
    end)
end

function RavineUI:HideTooltip() TipHide() end

-- ============ NOTIFICATIONS ============
local NotifContainer

local function EnsureNotifContainer()
    if NotifContainer and NotifContainer.Parent then return NotifContainer end
    RavineUI.NotifGui = Create("ScreenGui", {
        Name = "RavineUI_Notifs", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 101, Parent = GetGuiParent(),
    })
    NotifContainer = Create("Frame", {
        Name = "Container", BackgroundTransparency = 1,
        Position = UDim2.new(1, -20, 1, -20),
        Size = UDim2.new(0, 300, 1, -40),
        AnchorPoint = Vector2.new(1, 1), Parent = RavineUI.NotifGui,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8), Parent = NotifContainer,
    })
    return NotifContainer
end

function RavineUI:Notify(opts)
    if type(opts) == "string" then opts = { Description = opts } end
    opts = opts or {}

    local activeWin = RavineUI._activeWindow
    if activeWin and activeWin.Minimized and activeWin._miniBar and activeWin._miniSetState then
        activeWin._miniSetState("Expanded")
        task.delay(2.5, function()
            if activeWin.Minimized and not activeWin._miniHovered then
                activeWin._miniSetState("Compact")
            end
        end)
    end

    local container = EnsureNotifContainer()
    local title = opts.Title or "Notification"
    local text = opts.Description or opts.Text or ""
    local duration = opts.Time or 4

    local holder = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 62), Parent = container })
    local notif = Create("Frame", {
        Name = "Notif", BackgroundColor3 = Theme.Secondary, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), Position = UDim2.new(1, 340, 0, 0),
        ClipsDescendants = true, Parent = holder,
    })
    Corner(notif, 8)
    Stroke(notif, Theme.Border, 1)

    local accent = Create("Frame", {
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.new(0, 3, 1, -24), Parent = notif,
    })
    Corner(accent, 3)

    local ic = NewIcon(notif, opts.Icon or "bell", 18, Theme.Accent, "!")
    ic.Instance.Position = UDim2.new(0, 14, 0, 9)

    Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 40, 0, 8),
        Size = UDim2.new(1, -48, 0, 18), Font = Theme.FontBold,
        Text = title, TextColor3 = Theme.Text, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = notif,
    })
    Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 40, 0, 26),
        Size = UDim2.new(1, -48, 1, -30), Font = Theme.Font,
        Text = text, TextColor3 = Theme.SubText, TextSize = 12, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Parent = notif,
    })

    local bar = Create("Frame", {
        BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.3,
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 2),
        ZIndex = 3, Parent = notif,
    })
    local dismiss = Create("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Text = "", ZIndex = 4, Parent = notif,
    })

    local animated = Anim()
    local closed = false
    local function close()
        if closed then return end
        closed = true
        pcall(function()
            Tween(notif, animated and 0.3 or 0.01, { Position = UDim2.new(1, 340, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        end)
        task.wait(animated and 0.3 or 0.02)
        pcall(function()
            Tween(holder, 0.2, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end)
        task.wait(0.22)
        holder:Destroy()
    end
    dismiss.MouseButton1Click:Connect(function() task.spawn(close) end)

    if animated then
        Tween(notif, 0.5, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        local ico = ic.Instance
        ico.AnchorPoint = Vector2.new(0.5, 0.5)
        ico.Position = UDim2.new(0, 23, 0, 18)
        ico.Size = UDim2.fromOffset(0, 0)
        task.delay(0.15, function()
            if ico.Parent then
                Tween(ico, 0.4, { Size = UDim2.fromOffset(18, 18) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            end
        end)
        Tween(bar, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
    else
        notif.Position = UDim2.new(0, 0, 0, 0)
        bar.Visible = false
    end

    task.delay(duration, function() close() end)
end

-- ============ CHANGELOG ============
function RavineUI:ShowChangelog(opts)
    opts = opts or {}
    local scriptName = opts.Title or "Script"
    local version = opts.Version or "1.0.0"
    local entries = opts.Entries or {}
    local discord = opts.Discord

    local stored = {}
    for k, v in pairs(opts) do if k ~= "OnClose" then stored[k] = v end end
    RavineUI._LastChangelog = stored

    if RavineUI._ChangelogGui and RavineUI._ChangelogGui.Parent then
        RavineUI._ChangelogGui:Destroy()
    end

    local gui = Create("ScreenGui", {
        Name = "RavineUI_Changelog", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999, Parent = GetGuiParent(),
    })
    RavineUI._ChangelogGui = gui

    local size = UDim2.fromOffset(520, 470)
    local main = Create("Frame", {
        Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = size,
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = RavineUI.ThemeState.Transparency,
        BorderSizePixel = 0, ClipsDescendants = true, Parent = gui,
    })
    Corner(main, 12)
    Stroke(main, Theme.Border, 1)
    local uiScale = Create("UIScale", { Parent = main })

    local function fitScale()
        local cam = workspace.CurrentCamera
        if not cam then return 1 end
        local vp = cam.ViewportSize
        local fit = math.min((vp.X - 24) / size.X.Offset, (vp.Y - 24) / size.Y.Offset)
        local s = math.min(1, fit)
        if RavineUI.IsMobile then s = s * (RavineUI.MobileScale or 0.7) end
        return math.clamp(s, 0.25, 2)
    end
    local targetScale = fitScale()
    uiScale.Scale = targetScale * 0.86

    local topBar = Create("Frame", { Name = "TopBar", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Parent = main })
    Create("Frame", { BackgroundColor3 = Theme.Border, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), Parent = topBar })

    local logo = NewIcon(topBar, opts.Icon or "scroll-text", 22, Theme.Accent, "*")
    logo.Instance.Position = UDim2.new(0, 16, 0.5, -11)

    local titleHolder = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 48, 0, 0), Size = UDim2.new(1, -100, 1, 0), Parent = topBar })
    Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = titleHolder })
    Create("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 20), LayoutOrder = 1, Font = Theme.FontBold, Text = scriptName, TextColor3 = Theme.Text, TextSize = 15, Parent = titleHolder })
    Create("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 20), LayoutOrder = 2, Font = Theme.Font, Text = "Changelog  v" .. version, TextColor3 = Theme.SubText, TextSize = 12, Parent = titleHolder })

    local closeBtn = Create("TextButton", {
        BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(28, 28), Text = "", AutoButtonColor = false, Parent = topBar,
    })
    Corner(closeBtn, 8)
    local closeStrk = Stroke(closeBtn, Theme.Border, 1)
    local closeIco = NewIcon(closeBtn, "x", 14, Theme.SubText, "x")
    closeIco.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    closeIco.Instance.Position = UDim2.fromScale(0.5, 0.5)
    closeBtn.MouseEnter:Connect(function() TintIcon(closeIco, Theme.Text); Tween(closeStrk, 0.15, { Color = Theme.Accent }) end)
    closeBtn.MouseLeave:Connect(function() TintIcon(closeIco, Theme.SubText); Tween(closeStrk, 0.15, { Color = Theme.Border }) end)

    local typeIcons = { Added = "plus", Improved = "sparkles", Changed = "refresh-cw", Fixed = "wrench", Removed = "minus", Information = "info" }
    local typeOrder = { "Information", "Added", "Improved", "Changed", "Fixed", "Removed" }

    local groups, extra = {}, {}
    for _, entry in ipairs(entries) do
        local eType, eText
        if entry.Type and entry.Text then eType, eText = entry.Type, entry.Text
        else for k, v in pairs(entry) do eType, eText = k, v; break end end
        eType = tostring(eType or "Changed")
        if not groups[eType] then
            groups[eType] = {}
            if not typeIcons[eType] then table.insert(extra, eType) end
        end
        table.insert(groups[eType], tostring(eText))
    end

    local scroll = Create("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 0, 56), Size = UDim2.new(1, -20, 1, -120),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.Border,
        ScrollingDirection = Enum.ScrollingDirection.Y, Parent = main,
    })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = scroll })
    Create("UIPadding", { PaddingRight = UDim.new(0, 4), Parent = scroll })

    local fakeTab = { Groupboxes = {} }
    local function buildGroup(typeName)
        local list = groups[typeName]
        if not list then return end
        local box = Tab._AddGroupbox(fakeTab, typeName, typeIcons[typeName] or "info", scroll)
        for _, text in ipairs(list) do
            box._n = box._n + 1
            local row = Create("Frame", {
                BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = box._n, Parent = box.Container,
            })
            Corner(row, 6)
            Stroke(row, Theme.Border, 1)
            Create("UIPadding", { PaddingBottom = UDim.new(0, 9), Parent = row })
            local ic = NewIcon(row, typeIcons[typeName] or "info", 14, Theme.Accent, "*")
            ic.Instance.Position = UDim2.fromOffset(12, 10)
            Create("TextLabel", {
                BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 9),
                Size = UDim2.new(1, -48, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                Font = Theme.Font, Text = text, TextColor3 = Theme.Text, TextSize = 13,
                TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top, Parent = row,
            })
        end
    end
    for _, t in ipairs(typeOrder) do buildGroup(t) end
    for _, t in ipairs(extra) do buildGroup(t) end

    local footer = Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 54), Parent = main })
    Create("Frame", { BackgroundColor3 = Theme.Border, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Parent = footer })

    local infoHolder = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -150, 1, 0), Parent = footer })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 1), Parent = infoHolder })
    Create("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, Font = Theme.FontBold, Text = scriptName .. "  v" .. version, TextColor3 = Theme.Text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = infoHolder })
    if discord then
        Create("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2, Font = Theme.Font, Text = discord, TextColor3 = Theme.SubText, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = infoHolder })
    end

    local okBtn = Create("TextButton", {
        BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(112, 34), Font = Theme.Font, Text = "Continue",
        TextColor3 = Theme.Text, TextSize = 13, AutoButtonColor = false, Parent = footer,
    })
    Corner(okBtn, 6)
    local okStrk = Stroke(okBtn, Theme.Border, 1)
    okBtn.TextXAlignment = Enum.TextXAlignment.Left
    Create("UIPadding", { PaddingLeft = UDim.new(0, 14), Parent = okBtn })
    local okIco = NewIcon(okBtn, "arrow-right", 14, Theme.Text, ">")
    okIco.Instance.AnchorPoint = Vector2.new(1, 0.5)
    okIco.Instance.Position = UDim2.new(1, -10, 0.5, 0)

    okBtn.MouseEnter:Connect(function() Tween(okBtn, 0.15, { BackgroundColor3 = Theme.Accent }); Tween(okStrk, 0.15, { Color = Theme.Accent }) end)
    okBtn.MouseLeave:Connect(function() Tween(okBtn, 0.15, { BackgroundColor3 = Theme.Tertiary }); Tween(okStrk, 0.15, { Color = Theme.Border }) end)

    Tween(uiScale, 0.45, { Scale = targetScale }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    MakeDraggable(main, topBar, function() return uiScale.Scale end)

    local closing = false
    local function close()
        if closing then return end
        closing = true
        Tween(uiScale, 0.18, { Scale = targetScale * 0.88 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.wait(0.18)
        gui:Destroy()
        if opts.OnClose then task.spawn(opts.OnClose) end
    end
    closeBtn.MouseButton1Click:Connect(close)
    okBtn.MouseButton1Click:Connect(close)
end

-- ============ CONFIG ============
local ConfigFolder = "RavineUI/configs"

local function HasFS()
    return writefile and readfile and isfile and isfolder and makefolder
end

local function EnsureFolders()
    if not isfolder("RavineUI") then makefolder("RavineUI") end
    if not isfolder(ConfigFolder) then makefolder(ConfigFolder) end
end

function RavineUI:SaveConfig(name)
    if not name or name == "" then return false, "Kein Name angegeben" end
    if not HasFS() then return false, "Executor unterstuetzt keine Dateifunktionen" end
    local data = {}
    for id, o in pairs(self.Toggles) do
        if id:sub(1, 9) ~= "RavineUI_" then data[id] = { t = o.Type, v = o.Value } end
    end
    for id, o in pairs(self.Options) do
        if id:sub(1, 9) ~= "RavineUI_" then
            local v = o.Value
            if typeof(v) == "Color3" then
                v = { math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5) }
            end
            data[id] = { t = o.Type, v = v }
        end
    end
    local ok, err = pcall(function()
        EnsureFolders()
        writefile(ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    end)
    return ok, err
end

function RavineUI:LoadConfig(name)
    if not name or name == "" then return false, "Kein Name angegeben" end
    if not HasFS() then return false, "Executor unterstuetzt keine Dateifunktionen" end
    local path = ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false, "Config nicht gefunden" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(data) ~= "table" then return false, "Config ist beschaedigt" end
    for id, entry in pairs(data) do
        local o = self.Toggles[id] or self.Options[id]
        if o and o.Set then
            local v = entry.v
            if o.Type == "ColorPicker" and type(v) == "table" then
                v = Color3.fromRGB(v[1], v[2], v[3])
            end
            pcall(o.Set, v)
        end
    end
    return true
end

function RavineUI:ListConfigs()
    local out = {}
    if not (HasFS() and listfiles) then return out end
    pcall(function()
        EnsureFolders()
        for _, path in ipairs(listfiles(ConfigFolder)) do
            local n = path:match("([^/\\]+)%.json$")
            if n then table.insert(out, n) end
        end
    end)
    table.sort(out)
    return out
end

-- ============ UNLOAD ============
function RavineUI:Unload()
    self.Unloaded = true
    TipHide()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)
    self._rainbowConn = nil
    table.clear(ThemeHooks)
    if self.Gui then self.Gui:Destroy() end
    if self.NotifGui then self.NotifGui:Destroy() end
    if self._ChangelogGui then self._ChangelogGui:Destroy() end
    table.clear(self.Toggles)
    table.clear(self.Options)
    if GENV.RavineUI_Instance == self then GENV.RavineUI_Instance = nil end
end

-- ============ CARD HELPERS ============
local AvatarCache

local function LoadAvatar(img)
    task.spawn(function()
        if not AvatarCache then
            local ok, url = pcall(Players.GetUserThumbnailAsync, Players, LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
            if ok then AvatarCache = url end
        end
        if AvatarCache and img.Parent then img.Image = AvatarCache end
    end)
end

local function Card(parent, size, bg, class)
    local isButton = class == "TextButton"
    local f = Create(class or "Frame", {
        BackgroundColor3 = bg or Theme.Card, BorderSizePixel = 0, Size = size, Parent = parent,
    })
    if isButton then f.Text = ""; f.AutoButtonColor = false end
    Corner(f, 10)
    Stroke(f, Theme.Border, 1)
    return f
end

local function CardText(card, title, desc, titleSize, descScale)
    Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 10),
        Size = UDim2.new(1, -28, 0, 20), Font = Theme.FontBold, Text = title,
        TextColor3 = Theme.Text, TextSize = titleSize or 15,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Parent = card,
    })
    if desc then
        Create("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 31),
            Size = UDim2.new(descScale or 1, -28, 0, 28), Font = Theme.Font, Text = desc,
            TextColor3 = Theme.SubText, TextSize = 11, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 2, Parent = card,
        })
    end
end

local function TileRow(parent, order, hScale, hOffset)
    local r = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, hScale, hOffset), LayoutOrder = order, Parent = parent })
    Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = r })
    return r
end

local function StatTile(row, order, title, value, wScale, onClick)
    local btn = Create("TextButton", {
        BackgroundColor3 = Color3.fromRGB(22, 22, 27), BackgroundTransparency = 0.15,
        BorderSizePixel = 0, Size = UDim2.new(wScale, -3, 1, 0), LayoutOrder = order,
        Text = "", AutoButtonColor = false, Parent = row,
    })
    Corner(btn, 8)
    local strk = Stroke(btn, Theme.Border, 1)
    local holder = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = btn })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 1), Parent = holder })
    Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 6), Parent = holder })
    Create("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 15), LayoutOrder = 1, Font = Theme.FontBold, Text = title, TextColor3 = Theme.Text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = holder })
    local valueLabel = Create("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 2, Font = Theme.Font, Text = value, TextColor3 = Theme.SubText, TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, Parent = holder })
    if onClick then
        btn.MouseEnter:Connect(function() Tween(strk, 0.15, { Color = Theme.Accent }) end)
        btn.MouseLeave:Connect(function() Tween(strk, 0.15, { Color = Theme.Border }) end)
        btn.MouseButton1Click:Connect(function() task.spawn(onClick) end)
    end
    return { Button = btn, Set = function(text) valueLabel.Text = text end }
end

local function JoinDiscord(invite)
    local code = invite:match("discord%.gg/([%w%-_]+)") or invite:match("discord%.com/invite/([%w%-_]+)") or invite
    local link = "https://discord.gg/" .. code
    local copied = Copy(link)
    task.spawn(function()
        local opened = false
        local req = (syn and syn.request) or request or http_request or (http and http.request)
        if req then
            for port = 6463, 6472 do
                local ok, res = pcall(req, {
                    Url = "http://127.0.0.1:" .. port .. "/rpc?v=1", Method = "POST",
                    Headers = { ["Content-Type"] = "application/json", ["Origin"] = "https://discord.com" },
                    Body = HttpService:JSONEncode({ cmd = "INVITE_BROWSER", args = { code = code }, nonce = HttpService:GenerateGUID(false) }),
                })
                if ok and type(res) == "table" and (res.Success == true or res.StatusCode == 200) then opened = true; break end
            end
        end
        if not opened then
            local env = (getgenv and getgenv()) or _G
            for _, name in ipairs({ "openurl", "open_url", "OpenURL" }) do
                local fn = env[name]
                if type(fn) == "function" and pcall(fn, link) then opened = true; break end
            end
            if not opened then
                opened = pcall(function() game:GetService("GuiService"):OpenBrowserWindow(link) end)
            end
        end
        local desc
        if opened and copied then desc = "link copied (discord.gg/" .. code .. ")"
        elseif opened then desc = "Opening Discord... (discord.gg/" .. code .. ")"
        elseif copied then desc = "Link copied - paste it in your browser: discord.gg/" .. code
        else desc = "Open this link manually: discord.gg/" .. code end
        RavineUI:Notify({ Title = "Discord", Description = desc, Icon = (opened or copied) and "circle-check" or "triangle-alert" })
    end)
end

-- ---- Discord ----
local function HttpGetAny(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and type(res) == "string" and res ~= "" then return res end
    local req = (syn and syn.request) or request or http_request or (http and http.request)
    if req then
        local ok2, r = pcall(req, { Url = url, Method = "GET" })
        if ok2 and type(r) == "table" and type(r.Body) == "string" and r.Body ~= "" then return r.Body end
    end
    return nil
end

local DiscordCache = {}

local function FetchDiscord(invite)
    local code = tostring(invite or ""):match("discord%.gg/([%w%-_]+)") or tostring(invite or ""):match("discord%.com/invite/([%w%-_]+)") or tostring(invite or "")
    if code == "" then return nil end
    local c = DiscordCache[code]
    if c and os.clock() - c.t < 55 then return c.data end
    local body = HttpGetAny("https://discord.com/api/v9/invites/" .. code .. "?with_counts=true")
    local ok, res = pcall(function() return HttpService:JSONDecode(body) end)
    if ok and type(res) == "table" and type(res.guild) == "table" then
        local data = {
            Code = code, Name = tostring(res.guild.name or "Discord"),
            Members = tonumber(res.approximate_member_count), Online = tonumber(res.approximate_presence_count),
            GuildId = res.guild.id, Icon = res.guild.icon,
        }
        DiscordCache[code] = { t = os.clock(), data = data }
        return data
    end
    return c and c.data or nil
end

function RavineUI:GetDiscordInfo(invite) return FetchDiscord(invite) end

local function LoadDiscordIcon(img, data, onDone)
    task.spawn(function()
        if not (data and data.GuildId and data.Icon and HasFS() and getcustomasset) then return end
        local path = "RavineUI/dc_" .. tostring(data.Icon) .. ".png"
        local ok = pcall(function()
            EnsureFolders()
            if not isfile(path) then
                local png = game:HttpGet(string.format("https://cdn.discordapp.com/icons/%s/%s.png?size=128", tostring(data.GuildId), tostring(data.Icon)))
                writefile(path, png)
            end
            img.Image = getcustomasset(path)
        end)
        if ok and img.Parent and img.Image ~= "" then onDone() end
    end)
end

local function GetPing()
    local ok, v = pcall(function() return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
    return ok and v or nil
end

local function GetExecutorName()
    local ok, name = pcall(function() return identifyexecutor() end)
    return (ok and name) or "Unknown executor"
end

-- ============ SCALE SPEICHERN ============
local function ScaleFile(mobile) return mobile and "RavineUI/scale_mobile.txt" or "RavineUI/scale.txt" end

local function ReadSavedScale(mobile)
    if not HasFS() then return nil end
    local ok, v = pcall(function()
        if isfile(ScaleFile(mobile)) then return tonumber(readfile(ScaleFile(mobile))) end
        return nil
    end)
    if ok and v then return math.clamp(v, 0.25, 2) end
    return nil
end

local function WriteSavedScale(v, mobile)
    if not HasFS() then return end
    pcall(function() EnsureFolders(); writefile(ScaleFile(mobile), tostring(v)) end)
end

-- ============ THEME SYSTEM ============
local Presets = {
    { Name = "Crimson", Color = Color3.fromRGB(200, 30, 40) },
    { Name = "Ocean", Color = Color3.fromRGB(37, 124, 235) },
    { Name = "Violet", Color = Color3.fromRGB(139, 92, 246) },
    { Name = "Emerald", Color = Color3.fromRGB(34, 180, 95) },
    { Name = "Amber", Color = Color3.fromRGB(235, 150, 20) },
    { Name = "Rose", Color = Color3.fromRGB(236, 64, 140) },
    { Name = "Cyan", Color = Color3.fromRGB(8, 170, 200) },
    { Name = "Orange", Color = Color3.fromRGB(240, 105, 30) },
}

local function NearColor(a, b, tol)
    return math.abs(a.R - b.R) <= tol and math.abs(a.G - b.G) <= tol and math.abs(a.B - b.B) <= tol
end

local function ApplyColors(new, tol)
    local old = {}
    for k, v in pairs(new) do old[k] = Theme[k]; Theme[k] = v end
    tol = tol or (RavineUI.ThemeState.Rainbow and 0.15 or 0.004)
    for inst, list in pairs(ThemeBinds) do
        for _, b in ipairs(list) do
            local key = b[2]
            local o, n = old[key], new[key]
            if o and n and NearColor(inst[b[1]], o, tol) then inst[b[1]] = n end
        end
    end
    for _, fn in ipairs(ThemeHooks) do pcall(fn) end
end

local function DarkenColor(c, f)
    local h, s, v = Color3.toHSV(c)
    return Color3.fromHSV(h, s, v * f)
end

function RavineUI:SetAccent(color, fromRainbow, tolOverride)
    if typeof(color) ~= "Color3" then return end
    if not fromRainbow then self.ThemeState.Accent = color end
    ApplyColors({ Accent = color, ToggleOn = color, AccentDark = DarkenColor(color, 0.7) }, tolOverride)
end

function RavineUI:SetTheme(name)
    for _, p in ipairs(Presets) do
        if p.Name == name then
            self.ThemeState.Preset = p.Name
            self:SetAccent(p.Color)
            return true
        end
    end
    return false
end

function RavineUI:GetThemeNames()
    local out = {}
    for _, p in ipairs(Presets) do table.insert(out, p.Name) end
    return out
end

function RavineUI:AddThemePreset(name, color)
    if type(name) ~= "string" or typeof(color) ~= "Color3" then return end
    for _, p in ipairs(Presets) do
        if p.Name == name then p.Color = color; return end
    end
    table.insert(Presets, { Name = name, Color = color })
end

function RavineUI:OnThemeChanged(fn)
    if type(fn) == "function" then table.insert(ThemeHooks, fn) end
end

function RavineUI:SetRainbow(on, speed, silent)
    local ts = self.ThemeState
    if speed then ts.RainbowSpeed = math.clamp(tonumber(speed) or 0.15, 0.02, 1) end
    ts.Rainbow = on and true or false
    if self._rainbowConn then self._rainbowConn:Disconnect(); self._rainbowConn = nil end
    if ts.Rainbow then
        local last = 0
        self._rainbowConn = Connect(RunService.Heartbeat, function()
            local now = os.clock()
            if now - last < 0.04 then return end
            last = now
            self:SetAccent(Color3.fromHSV((now * ts.RainbowSpeed) % 1, 0.85, 0.95), true)
        end)
    else
        self:SetAccent(ts.Accent, false, 0.15)
    end
    if not silent then self:_QueueThemeSave() end
end

local ThemeFile = "RavineUI/theme.json"

local function ReadSavedTheme()
    if not HasFS() then return nil end
    local ok, data = pcall(function()
        if isfile(ThemeFile) then return HttpService:JSONDecode(readfile(ThemeFile)) end
        return nil
    end)
    if ok and type(data) == "table" then return data end
    return nil
end

function RavineUI:SaveTheme()
    if not HasFS() then return false end
    local ts = self.ThemeState
    local a = ts.Accent
    pcall(function()
        EnsureFolders()
        writefile(ThemeFile, HttpService:JSONEncode({
            Preset = ts.Preset,
            Accent = { math.floor(a.R * 255 + 0.5), math.floor(a.G * 255 + 0.5), math.floor(a.B * 255 + 0.5) },
            Rainbow = ts.Rainbow, RainbowSpeed = ts.RainbowSpeed,
            Transparency = ts.Transparency, Animations = ts.Animations,
        }))
    end)
    return true
end

function RavineUI:_QueueThemeSave()
    self._themeSaveToken = (self._themeSaveToken or 0) + 1
    local token = self._themeSaveToken
    task.delay(0.6, function()
        if token == self._themeSaveToken and not self.Unloaded then self:SaveTheme() end
    end)
end

function RavineUI:_InitTheme(opts)
    local ts = self.ThemeState
    if typeof(opts.Accent) == "Color3" then
        ts.Preset = "Custom"; self:SetAccent(opts.Accent)
    elseif opts.ThemePreset then
        self:SetTheme(opts.ThemePreset)
    end
    if opts.Transparency then ts.Transparency = math.clamp(tonumber(opts.Transparency) or 0.04, 0, 0.7) end
    if opts.Animations ~= nil then ts.Animations = opts.Animations and true or false end
    if opts.IgnoreSavedTheme then return end
    local saved = ReadSavedTheme()
    if not saved then return end
    local a = saved.Accent
    if type(a) == "table" and #a >= 3 then
        local function ch(x) return math.clamp(tonumber(x) or 0, 0, 255) end
        self:SetAccent(Color3.fromRGB(ch(a[1]), ch(a[2]), ch(a[3])))
        ts.Preset = type(saved.Preset) == "string" and saved.Preset or "Custom"
    end
    if saved.RainbowSpeed then ts.RainbowSpeed = math.clamp(tonumber(saved.RainbowSpeed) or ts.RainbowSpeed, 0.02, 1) end
    if saved.Transparency then ts.Transparency = math.clamp(tonumber(saved.Transparency) or ts.Transparency, 0, 0.7) end
    if saved.Animations == false then ts.Animations = false end
    if saved.Rainbow == true then self:SetRainbow(true, nil, true) end
end

-- ============ SEARCH ============
local SearchTypeIcons = {
    Toggle = "toggle-right", Slider = "sliders-horizontal",
    Dropdown = "list", Textbox = "type",
    ColorPicker = "palette", KeyPicker = "keyboard",
    Button = "mouse-pointer-click", Tab = "layout-dashboard",
}

local function BuildSearch(win, main, onState)
    local entries = {}
    local shown = {}
    local api = { Entries = entries, IsOpen = false }

    local panel = Create("Frame", {
        Name = "SearchPanel", BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 30, 0.5, 23), Size = UDim2.new(1, -76, 1, -62),
        Visible = false, Active = true, ZIndex = 60, Parent = main,
    })
    Corner(panel, 10)
    Stroke(panel, Theme.Border, 1)
    local panelScale = Create("UIScale", { Parent = panel })

    local inputRow = Create("Frame", {
        BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(1, -20, 0, 38), Parent = panel,
    })
    Corner(inputRow, 8)
    local inputStroke = Stroke(inputRow, Theme.Border, 1)

    local sIcon = NewIcon(inputRow, "search", 16, Theme.SubText, "?")
    sIcon.Instance.AnchorPoint = Vector2.new(0, 0.5)
    sIcon.Instance.Position = UDim2.new(0, 12, 0.5, 0)

    local box = Create("TextBox", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 38, 0, 0),
        Size = UDim2.new(1, -76, 1, 0), Font = Theme.Font, Text = "",
        PlaceholderText = "Search all options...", PlaceholderColor3 = Theme.SubText,
        TextColor3 = Theme.Text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false, Parent = inputRow,
    })

    local clearBtn = Create("TextButton", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(26, 26),
        Text = "", AutoButtonColor = false, Visible = false, Parent = inputRow,
    })
    local clearIcon = NewIcon(clearBtn, "x", 14, Theme.SubText, "x")
    clearIcon.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    clearIcon.Instance.Position = UDim2.fromScale(0.5, 0.5)
    clearBtn.MouseEnter:Connect(function() TintIcon(clearIcon, Theme.Text) end)
    clearBtn.MouseLeave:Connect(function() TintIcon(clearIcon, Theme.SubText) end)

    local info = Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 52),
        Size = UDim2.new(1, -24, 0, 16), Font = Theme.Font, Text = "",
        TextColor3 = Theme.SubText, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
    })

    local results = Create("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 0, 74), Size = UDim2.new(1, -20, 1, -84),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.Border,
        ScrollingDirection = Enum.ScrollingDirection.Y, Parent = panel,
    })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = results })
    Create("UIPadding", { PaddingRight = UDim.new(0, 4), Parent = results })

    local empty = Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 96),
        Size = UDim2.new(1, -32, 0, 40), Font = Theme.Font, Text = "",
        TextColor3 = Theme.SubText, TextSize = 12, TextWrapped = true, Parent = panel,
    })

    local function reveal(e)
        local frame, col = e.Frame, e.Column
        if not (frame and frame.Parent and col and col.Parent) then return end
        local scale = math.max(win.Scale.Scale, 0.01)
        local rel = (frame.AbsolutePosition.Y - col.AbsolutePosition.Y) / scale
        local maxY = math.max((col.AbsoluteCanvasSize.Y - col.AbsoluteWindowSize.Y) / scale, 0)
        local target = math.clamp(col.CanvasPosition.Y + rel - 50, 0, maxY)
        Tween(col, 0.25, { CanvasPosition = Vector2.new(0, target) })
        local stroke = frame:FindFirstChildOfClass("UIStroke")
        if stroke then
            task.spawn(function()
                pcall(function()
                    for _ = 1, 2 do
                        Tween(stroke, 0.18, { Color = Theme.Accent, Thickness = 2 })
                        task.wait(0.3)
                        Tween(stroke, 0.25, { Color = Theme.Border, Thickness = 1 })
                        task.wait(0.35)
                    end
                end)
            end)
        end
    end

    local function jump(e)
        api.SetOpen(false)
        win:SelectTab(e.Tab)
        if e.Frame then task.delay(0.1, function() reveal(e) end) end
    end

    local function makeRow(e, order)
        local btn = Create("TextButton", {
            BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
            Size = UDim2.new(1, -4, 0, 44), LayoutOrder = order, Text = "",
            AutoButtonColor = false, Parent = results,
        })
        Corner(btn, 8)
        local st = Stroke(btn, Theme.Border, 1)
        local ic = NewIcon(btn, SearchTypeIcons[e.Type] or "search", 16, Theme.Accent, "*")
        ic.Instance.AnchorPoint = Vector2.new(0, 0.5)
        ic.Instance.Position = UDim2.new(0, 12, 0.5, 0)
        Create("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 38, 0, 6),
            Size = UDim2.new(1, -50, 0, 18), Font = Theme.FontBold, Text = e.Name,
            TextColor3 = Theme.Text, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = btn,
        })
        local sub
        if e.Type == "Tab" then sub = "Tab"
        else sub = (e.Tab and e.Tab.Name or "") .. " / " .. tostring(e.Group or "") end
        if e.Obj and e.Obj.Disabled then sub = sub .. "  -  locked" end
        Create("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 38, 0, 24),
            Size = UDim2.new(1, -50, 0, 14), Font = Theme.Font, Text = sub,
            TextColor3 = Theme.SubText, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = btn,
        })
        btn.MouseEnter:Connect(function() Tween(st, 0.12, { Color = Theme.Accent }) end)
        btn.MouseLeave:Connect(function() Tween(st, 0.12, { Color = Theme.Border }) end)
        btn.MouseButton1Click:Connect(function() jump(e) end)
    end

    local function render(query)
        for _, c in ipairs(results:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        shown = {}
        local tokens = {}
        for t in query:lower():gmatch("%S+") do table.insert(tokens, t) end
        if #tokens == 0 then
            if api.ListMode then
                local n, tabCount, seen = 0, 0, {}
                for _, e in ipairs(entries) do
                    if e.Type ~= "Tab" and e.Tab and not e.Tab._internal then
                        n = n + 1
                        shown[n] = e
                        makeRow(e, n)
                        if not seen[e.Tab] then seen[e.Tab] = true; tabCount = tabCount + 1 end
                    end
                end
                info.Text = "Feature list  -  " .. n .. (n == 1 and " feature" or " features") .. " across " .. Plural(tabCount, "tab")
                empty.Text = "No features yet"
                empty.Visible = n == 0
                return
            end
            info.Text = Plural(#entries, "option") .. " searchable"
            empty.Text = "Type to search every option across all tabs"
            empty.Visible = true
            return
        end
        local scored = {}
        for _, e in ipairs(entries) do
            local score = 0
            for _, t in ipairs(tokens) do
                local i = e.Lower:find(t, 1, true)
                if i then score = score + (i == 1 and 3 or 2)
                elseif e.Blob:find(t, 1, true) then score = score + 1
                else score = 0; break end
            end
            if score > 0 then table.insert(scored, { s = score, e = e }) end
        end
        table.sort(scored, function(a, b)
            if a.s ~= b.s then return a.s > b.s end
            return a.e.Lower < b.e.Lower
        end)
        for i = 1, math.min(#scored, 40) do
            shown[i] = scored[i].e
            makeRow(scored[i].e, i)
        end
        info.Text = Plural(#shown, "result") .. (#scored > #shown and " (showing first 40)" or "")
        empty.Visible = #shown == 0
        if #shown == 0 then empty.Text = 'No results for "' .. query .. '"' end
    end

    box:GetPropertyChangedSignal("Text"):Connect(function()
        clearBtn.Visible = box.Text ~= ""
        render(box.Text)
    end)
    box.Focused:Connect(function() Tween(inputStroke, 0.15, { Color = Theme.Accent }) end)
    box.FocusLost:Connect(function(enterPressed, input)
        Tween(inputStroke, 0.15, { Color = Theme.Border })
        if input and input.KeyCode == Enum.KeyCode.Escape then api.SetOpen(false)
        elseif enterPressed and shown[1] then jump(shown[1]) end
    end)
    clearBtn.MouseButton1Click:Connect(function()
        box.Text = ""
        box:CaptureFocus()
    end)

    function api.SetOpen(v, query)
        v = v and true or false
        if v == api.IsOpen then
            if v and query then box.Text = query end
            return
        end
        api.IsOpen = v
        if not v then api.ListMode = false end
        TipHide()
        panel.Visible = v
        if v then
            if Anim() then
                panelScale.Scale = 0.94
                Tween(panelScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            else
                panelScale.Scale = 1
            end
            box.Text = query or ""
            render(box.Text)
            task.delay(0.05, function()
                if api.IsOpen then box:CaptureFocus() end
            end)
        else
            pcall(function() box:ReleaseFocus() end)
        end
        if onState then onState(v) end
    end

    function api.OpenList()
        api.ListMode = true
        if api.IsOpen then render(box.Text)
        else api.SetOpen(true, "") end
    end

    function api.Add(e)
        e.Name = tostring(e.Name or "?")
        e.Type = e.Type or "Option"
        e.Lower = e.Name:lower()
        e.Blob = (e.Name .. " " .. (e.Tab and e.Tab.Name or "") .. " " .. tostring(e.Group or "")
            .. " " .. e.Type .. " " .. tostring(e.Keywords or "")):lower()
        table.insert(entries, e)
    end

    return api
end

-- ============ LOADING SCREEN ============
function RavineUI:ShowLoader(opts)
    opts = opts or {}
    local gui = EnsureGui()
    local duration = opts.Duration or 1.8
    local steps = opts.Steps or { "Preparing interface", "Loading icons", "Almost there" }
    local title = opts.Title or "RavineUI"
    local subtitle = opts.Subtitle or "Loading"
    local icon = opts.Icon or "moon"
    local W, H = 340, 74 + #steps * 24 + 16

    local card = Create("CanvasGroup", {
        Name = "Loader", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 10), Size = UDim2.fromOffset(W, H),
        BackgroundColor3 = Theme.Background, BorderSizePixel = 0,
        GroupTransparency = 1, ZIndex = 100, Parent = gui,
    })
    Corner(card, 12)
    local stroke = Stroke(card, Theme.Border, 1)
    local scale = Create("UIScale", { Scale = 0.97, Parent = card })
    local shadow = Create("ImageLabel", {
        Position = UDim2.fromOffset(-25, -25), Size = UDim2.new(1, 50, 1, 50),
        BackgroundTransparency = 1, Image = "rbxassetid://6014261993",
        ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 0, Parent = card,
    })
    local content = Create("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = card })
    local logo = NewIcon(content, icon, 30, Theme.Accent, "\u{2022}")
    logo.Instance.Position = UDim2.fromOffset(22, 22)
    Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(64, 20),
        Size = UDim2.new(1, -134, 0, 18), Font = Theme.FontBold, Text = title,
        TextColor3 = Theme.Text, TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = content,
    })
    Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(64, 39),
        Size = UDim2.new(1, -134, 0, 15), Font = Theme.Font, Text = subtitle,
        TextColor3 = Theme.SubText, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = content,
    })
    local pct = Create("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -22, 0, 26), Size = UDim2.fromOffset(56, 16),
        Font = Theme.Font, Text = "0%", TextColor3 = Theme.SubText, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = content,
    })
    Create("Frame", {
        BackgroundColor3 = Theme.Border, BorderSizePixel = 0,
        Position = UDim2.fromOffset(22, 66), Size = UDim2.new(1, -44, 0, 1),
        Parent = content,
    })
    local stepRows = {}
    for i, stepText in ipairs(steps) do
        local row = Create("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(22, 74 + (i - 1) * 24),
            Size = UDim2.new(1, -44, 0, 24), Parent = content,
        })
        local dot = Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 7, 0.5, 0),
            Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Theme.Tertiary,
            BorderSizePixel = 0, Parent = row,
        })
        Corner(dot, 3)
        local spinner = Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 7, 0.5, 0),
            Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Visible = false, Parent = row,
        })
        Corner(spinner, 6)
        local sp = Create("UIStroke", { Color = Theme.Accent, Thickness = 2, Parent = spinner })
        Create("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0),
                NumberSequenceKeypoint.new(0.501, 1), NumberSequenceKeypoint.new(1, 1),
            }), Parent = sp,
        })
        local check = NewIcon(row, "check", 14, Theme.Accent, "\u{2713}")
        check.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
        check.Instance.Position = UDim2.new(0, 7, 0.5, 0)
        check.Instance.Visible = false
        local lbl = Create("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 0),
            Size = UDim2.new(1, -24, 1, 0), Font = Theme.Font, Text = stepText,
            TextColor3 = Theme.SubText, TextSize = 13, TextTransparency = 0.45,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
        })
        stepRows[i] = { Dot = dot, Spinner = spinner, Check = check, Label = lbl, State = "pending" }
    end
    local barBg = Create("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Theme.Tertiary,
        BorderSizePixel = 0, Parent = content,
    })
    local barFill = Create("Frame", {
        Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0, Parent = barBg,
    })
    local function setStep(i, state)
        local r = stepRows[i]
        if not r or r.State == state then return end
        r.State = state
        r.Dot.Visible = state == "pending"
        r.Spinner.Visible = state == "active"
        r.Check.Instance.Visible = state == "done"
        Tween(r.Label, 0.2, {
            TextTransparency = state == "pending" and 0.45 or 0,
            TextColor3 = state == "active" and Theme.Text or Theme.SubText,
        })
    end
    Tween(card, 0.45, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0) }, Enum.EasingStyle.Quint)
    Tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Quint)
    Tween(shadow, 0.4, { ImageTransparency = 0.55 })
    Tween(barFill, 0.8 * duration, { Size = UDim2.fromScale(0.85, 1) }, Enum.EasingStyle.Quart)
    local rotConn
    rotConn = RunService.RenderStepped:Connect(function(dt)
        if not card.Parent then rotConn:Disconnect(); return end
        pct.Text = math.floor(barFill.Size.X.Scale * 100 + 0.5) .. "%"
        for _, r in ipairs(stepRows) do
            if r.State == "active" then
                r.Spinner.Rotation = (r.Spinner.Rotation + dt * 360) % 360
            end
        end
    end)
    task.spawn(function()
        for i = 1, #steps do
            task.wait(duration / #steps)
            if not card.Parent then return end
            if i > 1 then setStep(i - 1, "done") end
            setStep(i, "active")
        end
    end)
    task.delay(duration + 0.3, function()
        for i = 1, #stepRows do setStep(i, "done") end
        Tween(barFill, 0.25, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Quint)
        Tween(content, 0.18, { GroupTransparency = 1 })
        local finalScale = RavineUI._scaleInst and RavineUI._scaleInst.Scale or 1
        local mainSize = RavineUI._main and RavineUI._main.Size or UDim2.fromOffset(700, 430)
        Tween(card, 0.5, {
            Size = UDim2.fromOffset(mainSize.X.Offset * finalScale, mainSize.Y.Offset * finalScale),
            Position = UDim2.new(0.5, 0, 0.5, 0),
        }, Enum.EasingStyle.Quint)
        task.delay(0.28, function()
            if rotConn then rotConn:Disconnect() end
            if RavineUI._main then
                RavineUI._main.Visible = true
                if RavineUI._scaleInst then
                    local s = RavineUI._scaleInst.Scale
                    RavineUI._scaleInst.Scale = s * 0.86
                    Tween(RavineUI._scaleInst, 0.5, { Scale = s }, Enum.EasingStyle.Back)
                end
            end
            Tween(card, 0.25, { GroupTransparency = 1 })
            Tween(stroke, 0.2, { Transparency = 1 })
            Tween(shadow, 0.2, { ImageTransparency = 1 })
        end)
        task.delay(0.6, function() card:Destroy() end)
    end)
end

-- ============ MINI BAR / ISLAND ============
local MINI = { Top = 8, Width = 168, Height = 32, Wide = 340, Radius = 34 }

function Window:BuildMiniBar()
    if self._miniBar then return self._miniBar end
    local gui = self.Gui
    local orb = Create("CanvasGroup", {
        Name = "MiniBar", AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, MINI.Top),
        Size = UDim2.fromOffset(MINI.Width, MINI.Height),
        BackgroundColor3 = Theme.Background, BorderSizePixel = 0,
        GroupTransparency = 1, Visible = false, ZIndex = 30, Parent = gui,
    })
    Corner(orb, MINI.Height / 2)
    Stroke(orb, Theme.Border, 1)
    local orbScale = Create("UIScale", { Parent = orb })

    local compact = Create("CanvasGroup", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0, Parent = orb,
    })
    Corner(compact, MINI.Height / 2)
    local logoBox = Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 5, 0.5, 0),
        Size = UDim2.fromOffset(MINI.Height - 10, MINI.Height - 10),
        BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.82,
        BorderSizePixel = 0, Parent = compact,
    })
    Corner(logoBox, (MINI.Height - 10) / 2)
    local miniLogo = NewIcon(logoBox, "moon", 16, Theme.Accent, "\u{2022}")
    miniLogo.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    miniLogo.Instance.Position = UDim2.fromScale(0.5, 0.5)
    Create("TextLabel", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, MINI.Height + 2, 0.5, 0),
        Size = UDim2.new(1, -MINI.Height - 2 - 72, 0, 18), BackgroundTransparency = 1,
        Font = Theme.FontBold, Text = self.Title, TextColor3 = Theme.Text,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = compact,
    })
    local rightBox = Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18),
        BackgroundTransparency = 1, Parent = compact,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 7), Parent = rightBox,
    })
    local activeDot = Create("Frame", {
        Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0, LayoutOrder = -1, Parent = rightBox,
    })
    Corner(activeDot, 3)
    local sessionSmall = Create("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18),
        BackgroundTransparency = 1, Font = Theme.FontBold, Text = "0s",
        TextColor3 = Theme.SubText, TextSize = 12,
        TextTruncate = Enum.TextTruncate.None, LayoutOrder = 0, Parent = rightBox,
    })

    local expanded = Create("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0),
        Size = UDim2.new(0, MINI.Wide, 0, 400), BackgroundTransparency = 1,
        GroupTransparency = 1, Parent = orb,
    })
    local expInner = Create("Frame", {
        Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = expanded,
    })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = expInner })

    local topRow = Create("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, LayoutOrder = 1, Parent = expInner })
    local avatar = Create("ImageLabel", {
        Size = UDim2.fromOffset(48, 48), BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
        Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", LocalPlayer.UserId),
        Parent = topRow,
    })
    Corner(avatar, 12)
    Create("TextLabel", {
        Position = UDim2.fromOffset(60, 5), Size = UDim2.new(1, -150, 0, 20), BackgroundTransparency = 1,
        Font = Theme.FontBold, Text = LocalPlayer.DisplayName, TextColor3 = Theme.Text,
        TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Parent = topRow,
    })
    local gameLbl = Create("TextLabel", {
        Position = UDim2.fromOffset(60, 26), Size = UDim2.new(1, -150, 0, 15), BackgroundTransparency = 1,
        Font = Theme.Font, Text = "", TextColor3 = Theme.SubText, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = topRow,
    })
    task.spawn(function()
        local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
        if ok and type(info) == "table" and gameLbl.Parent then gameLbl.Text = tostring(info.Name) end
    end)
    local sessionBig = Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 3),
        Size = UDim2.fromOffset(90, 24), BackgroundTransparency = 1, Font = Theme.FontBold,
        Text = "0s", TextColor3 = Theme.Text, TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = topRow,
    })
    Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 27),
        Size = UDim2.fromOffset(90, 14), BackgroundTransparency = 1, Font = Theme.Font,
        Text = "session", TextColor3 = Theme.SubText, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = topRow,
    })

    local barsRow = Create("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, LayoutOrder = 2, Parent = expInner })
    local function makeStatBar(xScale, xOffset, label)
        local holder = Create("Frame", {
            Position = UDim2.new(xScale, xOffset, 0, 0), Size = UDim2.new(0.5, -10, 1, 0),
            BackgroundTransparency = 1, Parent = barsRow,
        })
        local num = Create("TextLabel", {
            Size = UDim2.new(1, -70, 0, 24), BackgroundTransparency = 1, Font = Theme.FontBold,
            Text = "0", TextColor3 = Theme.Text, TextSize = 20,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
        })
        Create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6),
            Size = UDim2.fromOffset(70, 14), BackgroundTransparency = 1, Font = Theme.Font,
            Text = label, TextColor3 = Theme.SubText, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right, Parent = holder,
        })
        local barBg = Create("Frame", {
            AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -4),
            Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Theme.Tertiary,
            BorderSizePixel = 0, Parent = holder,
        })
        Corner(barBg, 1.5)
        local fill = Create("Frame", {
            Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Success,
            BorderSizePixel = 0, Parent = barBg,
        })
        Corner(fill, 1.5)
        return num, fill
    end
    local fpsNum, fpsFill = makeStatBar(0, 0, "FRAME RATE")
    local pingNum, pingFill = makeStatBar(0.5, 10, "PING")

    local chipsRow = Create("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 3, Parent = expInner })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = chipsRow,
    })
    local function chip(order, label, valueColor)
        local box = Create("Frame", {
            AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30),
            BackgroundColor3 = Theme.Secondary, BorderSizePixel = 0,
            LayoutOrder = order, Parent = chipsRow,
        })
        Corner(box, 15)
        Create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = box })
        Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 7), Parent = box,
        })
        Create("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1,
            Font = Theme.Font, Text = label, TextColor3 = Theme.SubText, TextSize = 12,
            TextTruncate = Enum.TextTruncate.None, LayoutOrder = 1, Parent = box,
        })
        local value = Create("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1,
            Font = Theme.FontBold, Text = "", TextColor3 = valueColor or Theme.Text, TextSize = 12,
            TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2, Parent = box,
        })
        return value
    end
    local cPlayers = chip(1, "Players")
    local cToggles = chip(2, "Running", Theme.Accent)
    local cTab = chip(3, "Tab")
    Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = Theme.Font,
        Text = "Click to open", TextColor3 = Theme.SubText, TextSize = 12,
        LayoutOrder = 5, Parent = expInner,
    })

    local hit = Create("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, ZIndex = 10, Parent = orb,
    })

    local state = "Compact"
    local hovered, dragging, pendingDrag = false, false, false
    local dragStart, dragAnchor

    local function fitFor(s)
        if s == "Expanded" then
            return Vector2.new(MINI.Wide, math.floor(expInner.AbsoluteSize.Y + 28 + 0.5)), MINI.Radius
        end
        return Vector2.new(MINI.Width, MINI.Height), MINI.Height / 2
    end
    local function place(n)
        local ps = gui.AbsoluteSize
        local anchor = self._miniAnchor
        if not anchor then anchor = Vector2.new(ps.X / 2, MINI.Top) end
        local p = n or anchor
        return Vector2.new(
            math.clamp(p.X, MINI.Width / 2 + 6, math.max(ps.X - MINI.Width / 2 - 6, 6)),
            math.clamp(p.Y, 6, math.max(ps.Y - MINI.Height - 6, 6))
        )
    end
    local function setState(s, instant)
        if s == state then return end
        state = s
        local sz = fitFor(s)
        local oldSz = Vector2.new(orb.Size.X.Offset, orb.Size.Y.Offset)
        local grow = sz.X > oldSz.X + 1 or sz.Y > oldSz.Y + 1
        local dur = instant and 0 or (grow and 0.5 or 0.38)
        local pos = place()
        Tween(orb, dur, { Size = UDim2.fromOffset(sz.X, sz.Y) }, grow and Enum.EasingStyle.Back or Enum.EasingStyle.Quint)
        Tween(orb, dur, { Position = UDim2.fromOffset(pos.X, pos.Y) }, grow and Enum.EasingStyle.Back or Enum.EasingStyle.Quint)
        if grow and not instant then
            orbScale.Scale = 0.96
            Tween(orbScale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
        end
        for name, view in pairs({ Compact = compact, Expanded = expanded }) do
            if name ~= s then Tween(view, instant and 0 or 0.14, { GroupTransparency = 1 }, Enum.EasingStyle.Quad) end
        end
        local view = (s == "Compact") and compact or expanded
        if instant then
            view.GroupTransparency = 0
            view.Position = UDim2.fromScale(0.5, 0)
        else
            view.Position = (s == "Compact") and UDim2.fromScale(0.5, 0) or UDim2.new(0.5, 0, 0, 6)
            task.delay(0.1, function()
                if state == s then
                    Tween(view, 0.22, { GroupTransparency = 0 }, Enum.EasingStyle.Quad)
                    if s == "Expanded" then
                        Tween(view, 0.32, { Position = UDim2.fromScale(0.5, 0) }, Enum.EasingStyle.Quint)
                    end
                end
            end)
        end
    end
    local function refreshStats()
        local elapsed = os.clock() - (self._miniStart or os.clock())
        local t = FormatTime(elapsed)
        sessionSmall.Text = t
        sessionBig.Text = t
        local fps = self._cachedFPS or 60
        local ping = self._cachedPing or 0
        fpsNum.Text = tostring(fps)
        pingNum.Text = tostring(ping) .. " ms"
        fpsFill.Size = UDim2.fromScale(math.clamp(fps / 60, 0.05, 1), 1)
        pingFill.Size = UDim2.fromScale(math.clamp(1 - (ping - 40) / 360, 0.05, 1), 1)
        cPlayers.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
        cTab.Text = self.ActiveTab and self.ActiveTab.Name or "-"
        local n = 0
        for _, o in pairs(RavineUI.Toggles) do
            if o.Value == true then n += 1 end
        end
        cToggles.Text = tostring(n)
    end
    hit.MouseEnter:Connect(function()
        if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then return end
        hovered = true
        self._miniHovered = true
        if not dragging then setState("Expanded") end
    end)
    hit.MouseLeave:Connect(function()
        hovered = false
        self._miniHovered = false
        task.delay(0.28, function()
            if not hovered and not dragging then setState("Compact") end
        end)
    end)
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            pendingDrag = false
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
            dragAnchor = place()
            Tween(orbScale, 0.12, { Scale = 0.95 }, Enum.EasingStyle.Quad)
        end
    end)
    Connect(UserInputService.InputChanged, function(input)
        if not dragging or not dragStart then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = Vector2.new(input.Position.X, input.Position.Y) - dragStart
        if not pendingDrag and d.Magnitude >= 6 then
            pendingDrag = true
            hovered = false
            setState("Compact")
            Tween(orbScale, 0.2, { Scale = 1.06 }, Enum.EasingStyle.Quint)
        end
        if not pendingDrag then return end
        local ps = gui.AbsoluteSize
        local np = dragAnchor + d
        np = Vector2.new(
            math.clamp(np.X, MINI.Width / 2 + 6, math.max(ps.X - MINI.Width / 2 - 6, 6)),
            math.clamp(np.Y, 6, math.max(ps.Y - MINI.Height - 6, 6))
        )
        self._miniAnchor = Vector2.new(np.X / math.max(ps.X, 1), np.Y / math.max(ps.Y, 1))
        orb.Position = UDim2.fromOffset(np.X, np.Y)
    end)
    Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if not dragging then return end
        dragging = false
        Tween(orbScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
        if pendingDrag then
            pendingDrag = false
            local center = Vector2.new(gui.AbsoluteSize.X / 2, MINI.Top)
            local pos = place()
            if (pos - center).Magnitude < 28 then
                self._miniAnchor = nil
                Tween(orb, 0.35, { Position = UDim2.fromOffset(center.X, center.Y) }, Enum.EasingStyle.Back)
            end
        else
            hovered = not (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
            self._miniHovered = hovered
            task.delay(0.15, function()
                if not hovered and not dragging then setState("Compact") end
            end)
        end
    end)
    hit.MouseButton1Click:Connect(function()
        if pendingDrag then pendingDrag = false; return end
        self:Restore()
    end)
    Connect(RunService.RenderStepped, function()
        if orb.Visible then refreshStats() end
    end)

    self._miniBar = orb
    self._miniSetState = setState
    return orb
end

function Window:Minimize()
    if self.Minimized or not self.Alive then return end
    self.Minimized = true
    self._miniStart = os.clock()
    self:CloseSearch()
    local mini = self:BuildMiniBar()
    mini.Visible = true
    mini.GroupTransparency = 1
    if Anim() then
        local s = self.Scale.Scale
        self.Scale.Scale = s * 0.92
        Tween(self.Scale, 0.16, { Scale = s * 0.88 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.1, function()
            self.Main.Visible = false
            self.Scale.Scale = s
            Tween(mini, 0.35, { GroupTransparency = 0 }, Enum.EasingStyle.Quint)
        end)
    else
        self.Main.Visible = false
        mini.GroupTransparency = 0
    end
    if self.ToggleButton then self.ToggleButton.Visible = false end
end

function Window:Restore()
    if not self.Minimized then return end
    self.Minimized = false
    if self._miniBar then
        Tween(self._miniBar, 0.15, { GroupTransparency = 1 }, Enum.EasingStyle.Quad)
        task.delay(0.16, function()
            if self._miniBar then self._miniBar.Visible = false end
        end)
    end
    task.delay(0.08, function()
        if not self.Main or not self.Main.Parent then return end
        self.Main.Visible = true
        if Anim() then
            local s = self.Scale.Scale
            self.Scale.Scale = s * 0.88
            Tween(self.Scale, 0.4, { Scale = s }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end
        if self.ToggleButton and not RavineUI.IsMobile then
            self.ToggleButton.Visible = false
        elseif self.ToggleButton and RavineUI.IsMobile then
            self.ToggleButton.Visible = true
        end
    end)
end

-- ============ BACKDROP + WEATHER ============
local WEATHER = {
    Rain      = { Image = "rbxassetid://241868005", Count = 90, Stretch = true },
    Snow      = { Image = "rbxassetid://99851851", Count = 60 },
    Ember     = { Image = "rbxassetid://242205518", Count = 55, Glow = Color3.fromRGB(255, 60, 15) },
    Sakura    = { Petal = true, Count = 46 },
    Fireflies = { Image = "rbxassetid://8992230677", Count = 34, Glow = Color3.fromRGB(70, 150, 60) },
    Matrix    = { Text = true, Count = 38, Glyphs = "0123456789\u{30a2}\u{30a4}\u{30a6}\u{30a8}\u{30aa}\u{30ab}\u{30ad}\u{30af}\u{30b1}\u{30b3}" },
}

function Window:SetBackdrop(enabled)
    if enabled and not self._backdrop then self:_buildBackdrop() end
    self._backdropEnabled = enabled ~= false
    if self._backdrop then
        self._backdrop.Visible = self._backdropEnabled
        if self._backdropEnabled then self:_rebuildWeather() end
    end
end

function Window:SetWeather(name)
    if not WEATHER[name] and name ~= "None" then return end
    self.Weather = name
    if self._backdrop then self:_rebuildWeather() end
end

function Window:_buildBackdrop()
    local gui = self.Gui
    local bd = Create("Frame", {
        Name = "Backdrop", Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, ZIndex = -1, Parent = gui,
    })
    Create("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = bd,
    })
    local field = Create("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        ClipsDescendants = true, ZIndex = 0, Parent = bd,
    })
    self._backdrop = bd
    self._backdropField = field
    self._weatherParticles = {}
    self.Weather = "Snow"
    task.defer(function() if bd.Parent then self:_rebuildWeather() end end)
    Connect(RunService.RenderStepped, function(dt)
        if not bd.Visible then return end
        self:_stepWeather(dt)
    end)
    if self.Main then self.Main.ZIndex = 3 end
    if self.Body then self.Body.ZIndex = 3 end
    if self.Content then self.Content.ZIndex = 3 end
    if self.TabBar then self.TabBar.ZIndex = 3 end
end

function Window:_rebuildWeather()
    for _, p in ipairs(self._weatherParticles or {}) do p.Label:Destroy() end
    self._weatherParticles = {}
    local cfg = WEATHER[self.Weather]
    if not cfg or not self._backdropField then return end
    local rng = Random.new()
    local vp = self.Gui.AbsoluteSize
    if vp.X <= 0 or vp.Y <= 0 then
        task.delay(0.3, function()
            if self._backdrop and self._backdrop.Visible then self:_rebuildWeather() end
        end)
        return
    end
    for i = 1, cfg.Count do
        local label
        if cfg.Text then
            label = Create("TextLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
                Font = Enum.Font.Code, Text = "", TextColor3 = Color3.fromRGB(90, 255, 140),
                TextTransparency = 1, TextSize = rng:NextInteger(12, 19), ZIndex = 0,
                Parent = self._backdropField,
            })
        elseif cfg.Petal then
            label = Create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 190, 210),
                BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0,
                Parent = self._backdropField,
            })
            Corner(label, 4)
        else
            label = Create("ImageLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
                Image = cfg.Image, ImageTransparency = 1,
                ScaleType = cfg.Stretch and Enum.ScaleType.Stretch or Enum.ScaleType.Fit,
                ZIndex = 0, Parent = self._backdropField,
            })
        end
        local p = {
            Label = label,
            VY = (self.Weather == "Ember" and -rng:NextNumber(60, 170))
                or (self.Weather == "Rain" and rng:NextNumber(950, 1400))
                or rng:NextNumber(30, 90),
            VX = rng:NextNumber(-12, 12),
            Sway = rng:NextNumber(8, 38), Freq = rng:NextNumber(0.5, 1.4),
            Phase = rng:NextNumber(0, math.pi * 2), Spin = rng:NextNumber(-90, 90),
            Rotation = rng:NextNumber(0, 360), X = rng:NextNumber(0, vp.X),
            Y = rng:NextNumber(-vp.Y, 0),
            Size = Vector2.new(rng:NextNumber(6, 17), rng:NextNumber(6, 17)),
            Time = 0, Alpha = rng:NextNumber(0.05, 0.4),
        }
        label.Size = UDim2.fromOffset(p.Size.X, p.Size.Y)
        label.Position = UDim2.fromOffset(p.X, p.Y)
        table.insert(self._weatherParticles, p)
    end
end

function Window:_stepWeather(dt)
    local vp = self.Gui.AbsoluteSize
    for _, p in ipairs(self._weatherParticles) do
        p.Time += dt
        p.X += p.VX * dt
        p.Y += p.VY * dt
        p.Rotation += p.Spin * dt
        if p.Y > vp.Y + 40 or p.Y < -40 then
            p.Y = p.VY > 0 and -40 or vp.Y + 40
            p.X = math.random() * vp.X
        end
        if p.X > vp.X + 40 then p.X = -40 elseif p.X < -40 then p.X = vp.X + 40 end
        local x = p.X + math.sin(p.Time * p.Freq + p.Phase) * p.Sway
        p.Label.Position = UDim2.fromOffset(x, p.Y)
        p.Label.Rotation = p.Rotation
        local prop = p.Label:IsA("TextLabel") and "TextTransparency"
            or p.Label:IsA("Frame") and "BackgroundTransparency"
            or "ImageTransparency"
        p.Label[prop] = 1 - p.Alpha
    end
end

-- ============ WINDOW ============
function RavineUI:CreateWindow(opts)
    opts = opts or {}
    local title = opts.Title or "RavineUI"
    local subtitle = opts.Subtitle or ""
    local mobile = opts.Mobile
    if mobile == nil then mobile = RavineUI.IsMobile end
    RavineUI.IsMobile = mobile
    RavineUI.MobileScale = opts.MobileScale or 0.7
    RavineUI:_InitTheme(opts)
    local size = opts.Size or (mobile and UDim2.fromOffset(600, 380) or UDim2.fromOffset(700, 430))
    local savedScale = ReadSavedScale(mobile)
    local gui = EnsureGui()

    local main = Create("Frame", {
        Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = size,
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = RavineUI.ThemeState.Transparency,
        BorderSizePixel = 0, ClipsDescendants = true, Parent = gui,
    })
    Corner(main, 12)
    Stroke(main, Theme.Border, 1)
    local uiScale = Create("UIScale", { Parent = main })
    RavineUI._scaleInst = uiScale
    RavineUI._main = main

    local topBar = Create("Frame", { Name = "TopBar", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Parent = main })
    Create("Frame", { BackgroundColor3 = Theme.Border, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), Parent = topBar })

    local logoSrc = opts.Logo or opts.Icon or "moon"
    local customLogo = IsCustomImage(logoSrc)
    local logoPx = math.clamp(opts.LogoSize or (customLogo and 32 or 22), 12, 44)
    local logoX = customLogo and 12 or 16
    local logo = NewIcon(topBar, logoSrc, logoPx, customLogo and Color3.new(1, 1, 1) or Theme.Accent, "V")
    logo.Instance.AnchorPoint = Vector2.new(0, 0.5)
    logo.Instance.Position = UDim2.new(0, logoX, 0.5, 0)
    local titleX = logoX + logoPx + 10
    local reserve = (opts.Search ~= false) and 158 or 122

    local titleHolder = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, titleX, 0, 0), Size = UDim2.new(1, -(titleX + reserve), 1, 0), Parent = topBar })
    Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = titleHolder })
    Create("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 20), LayoutOrder = 1, Font = Theme.FontBold, Text = title, TextColor3 = Theme.Text, TextSize = 15, Parent = titleHolder })
    Create("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 20), LayoutOrder = 2, Font = Theme.Font, Text = subtitle, TextColor3 = Theme.SubText, TextSize = 12, Parent = titleHolder })

    local btnHolder = Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.X, Parent = topBar })
    Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = btnHolder })

    local function TopButton(order, icon, fallback)
        local active = false
        local b = Create("TextButton", { BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0, Size = UDim2.fromOffset(28, 28), LayoutOrder = order, Text = "", AutoButtonColor = false, Parent = btnHolder })
        Corner(b, 8)
        local s = Stroke(b, Theme.Border, 1)
        Ripple(b)
        local ic = NewIcon(b, icon, 14, Theme.SubText, fallback)
        ic.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
        ic.Instance.Position = UDim2.fromScale(0.5, 0.5)
        b.MouseEnter:Connect(function() TintIcon(ic, Theme.Text); Tween(s, 0.15, { Color = Theme.Accent }) end)
        b.MouseLeave:Connect(function() TintIcon(ic, active and Theme.Accent or Theme.SubText); Tween(s, 0.15, { Color = active and Theme.Accent or Theme.Border }) end)
        local api = {
            SetActive = function(v)
                active = v and true or false
                TintIcon(ic, active and Theme.Accent or Theme.SubText)
                Tween(s, 0.15, { Color = active and Theme.Accent or Theme.Border })
            end,
        }
        return b, api
    end

    local searchBtn, searchApi
    if opts.Search ~= false then searchBtn, searchApi = TopButton(1, "search", "S") end
    local minBtn = TopButton(2, "minus", "-")
    local closeBtn = TopButton(3, "x", "x")

    local body = Create("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(1, 0, 1, -46), Parent = main })
    local sidebar = Create("Frame", { Name = "Sidebar", BackgroundTransparency = 1, Size = UDim2.new(0, 60, 1, 0), ZIndex = 5, Parent = body })
    Create("Frame", { BackgroundColor3 = Theme.Border, BorderSizePixel = 0, Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), Parent = sidebar })

    local tabIndicator = Create("Frame", {
        Name = "TabIndicator", BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
        Position = UDim2.fromOffset(9, 10), Size = UDim2.fromOffset(42, 42), Visible = false, Parent = sidebar,
    })
    Corner(tabIndicator, 10)
    Stroke(tabIndicator, Theme.Border, 1)
    local tabAccent = Create("Frame", {
        Name = "TabAccent", BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 21), Size = UDim2.fromOffset(3, 20), Visible = false, Parent = sidebar,
    })
    Corner(tabAccent, 2)

    local tabList = Create("Frame", { Name = "TabList", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -64), Parent = sidebar })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), Parent = tabList })
    Create("UIPadding", { PaddingTop = UDim.new(0, 10), Parent = tabList })

    local content = Create("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.new(0, 60, 0, 0), Size = UDim2.new(1, -60, 1, 0), Parent = body })

    local avatarBtn = Create("ImageButton", {
        Name = "Avatar", BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(42, 42),
        ScaleType = Enum.ScaleType.Crop, AutoButtonColor = false, Parent = sidebar,
    })
    Corner(avatarBtn, 10)
    Stroke(avatarBtn, Theme.Border, 1)
    LoadAvatar(avatarBtn)

    local avatarHiddenIcon = NewIcon(avatarBtn, "eye-off", 18, Theme.SubText, "?")
    avatarHiddenIcon.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    avatarHiddenIcon.Instance.Position = UDim2.fromScale(0.5, 0.5)
    avatarHiddenIcon.Instance.Visible = false

    MakeDraggable(main, topBar, function() return uiScale.Scale end)

    local dragAccent = Stroke(main, Theme.Accent, 2)
    dragAccent.Transparency = 1
    local wasDragging = false
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            wasDragging = true
        end
    end)
    Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            wasDragging = false
            Tween(dragAccent, 0.25, { Transparency = 1 })
        end
    end)
    Connect(UserInputService.InputChanged, function(input)
        if wasDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            Tween(dragAccent, 0.15, { Transparency = 0.2 })
        end
    end)

    local windowObj = setmetatable({
        Gui = gui, Main = main, Body = body, TabBar = tabList, Content = content,
        Scale = uiScale, Title = title, Tabs = {}, ActiveTab = nil, HomeTab = nil,
        ToggleKeybind = opts.ToggleKeybind or Enum.KeyCode.RightControl,
        Minimized = false, Alive = true, Size = size,
        UserScale = savedScale, _shown = true,
    }, Window)
    windowObj._indicator = tabIndicator
    windowObj._indBar = tabAccent
    windowObj.Logo = logo
    windowObj.TitleHolder = titleHolder
    windowObj._logoX = logoX
    windowObj._reserve = reserve
    windowObj.AvatarButton = avatarBtn
    windowObj.AvatarHiddenIcon = avatarHiddenIcon

    RavineUI._activeWindow = windowObj

    if searchBtn then
        windowObj._search = BuildSearch(windowObj, main, function(v) searchApi.SetActive(v) end)
        searchBtn.MouseButton1Click:Connect(function() windowObj:ToggleSearch() end)
    end

    local function clampToScreen()
        local ps = gui.AbsoluteSize
        if ps.X <= 0 or ps.Y <= 0 then return end
        local w = size.X.Offset * uiScale.Scale
        local h = (windowObj.Minimized and 46 or size.Y.Offset) * uiScale.Scale
        local cx = main.Position.X.Scale * ps.X + main.Position.X.Offset
        local cy = main.Position.Y.Scale * ps.Y + main.Position.Y.Offset
        cx = math.clamp(cx, w / 2, math.max(ps.X - w / 2, w / 2))
        cy = math.clamp(cy, h / 2, math.max(ps.Y - h / 2, h / 2))
        main.Position = UDim2.fromScale(cx / ps.X, cy / ps.Y)
    end

    local function updateScale()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local fit = math.min((vp.X - 24) / math.max(size.X.Offset, 1), (vp.Y - 24) / math.max(size.Y.Offset, 1))
        local maxScale = math.clamp(fit, 0.25, 2)
        local s
        if windowObj.UserScale then
            s = math.min(windowObj.UserScale, maxScale)
        else
            s = math.min(opts.Scale or 1, fit)
            if mobile then s = s * RavineUI.MobileScale end
        end
        uiScale.Scale = math.clamp(s, 0.25, 2)
        clampToScreen()
    end
    windowObj._updateScale = updateScale
    updateScale()

    windowObj._ensureHeight = function(minHeight)
        if size.Y.Scale ~= 0 or size.Y.Offset >= minHeight then return end
        size = UDim2.new(size.X.Scale, size.X.Offset, 0, minHeight)
        windowObj.Size = size
        if not windowObj.Minimized then Tween(main, 0.2, { Size = size }) end
        updateScale()
    end
    if workspace.CurrentCamera then
        Connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale)
    end

    local resizeLayer
    if opts.Resizable ~= false then
        resizeLayer = Create("Frame", { Name = "Resize", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = main })
        local EDGE = mobile and 12 or 8
        local CORNER = mobile and 30 or 22

        local function applyDrag(mode, pos, a)
            local W, H = size.X.Offset, size.Y.Offset
            local ps = gui.AbsoluteSize
            local s
            if mode == "r" then s = (pos.X - a.L) / W
            elseif mode == "l" then s = (a.R - pos.X) / W
            elseif mode == "b" then s = (pos.Y - a.T) / H
            else s = ((pos.X - a.L) / W + (pos.Y - a.T) / H) / 2 end
            local maxS = math.clamp(math.min((ps.X - 24) / W, (ps.Y - 24) / H), 0.25, 2)
            s = math.clamp(s, 0.25, maxS)
            local cx = (mode == "l") and (a.R - s * W / 2) or (a.L + s * W / 2)
            local cy = a.T + s * H / 2
            local hw, hh = s * W / 2, s * H / 2
            cx = math.clamp(cx, hw, math.max(ps.X - hw, hw))
            cy = math.clamp(cy, hh, math.max(ps.Y - hh, hh))
            main.Position = UDim2.fromScale(cx / ps.X, cy / ps.Y)
            windowObj.UserScale = s
            uiScale.Scale = s
        end

        local function onResizeEnd()
            local pct = math.floor(uiScale.Scale * 100 + 0.5)
            windowObj:SetScale(pct / 100, true)
            if windowObj._scaleSlider then windowObj._scaleSlider.Set(pct) end
        end

        local function Handle(name, pos, sz, mode, isCorner)
            local h = Create("TextButton", { Name = name, BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Position = pos, Size = sz, Text = "", AutoButtonColor = false, ZIndex = 50, Parent = resizeLayer })
            local dots = {}
            if isCorner then
                local o = CORNER - 8
                for _, p in ipairs({ { o, o }, { o, o - 6 }, { o - 6, o } }) do
                    local d = Create("Frame", { BackgroundColor3 = Theme.SubText, BackgroundTransparency = 0.3, BorderSizePixel = 0, Position = UDim2.fromOffset(p[1], p[2]), Size = UDim2.fromOffset(2, 2), ZIndex = 51, Parent = h })
                    Corner(d, 1)
                    table.insert(dots, d)
                end
            end
            local function setHot(on)
                for _, d in ipairs(dots) do Tween(d, 0.12, { BackgroundColor3 = on and Theme.Text or Theme.SubText }) end
            end
            local dragging = false
            local anchors
            h.MouseEnter:Connect(function() if not dragging then setHot(true) end end)
            h.MouseLeave:Connect(function() if not dragging then setHot(false) end end)
            h.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    local p, sz = main.AbsolutePosition, main.AbsoluteSize
                    anchors = { L = p.X, T = p.Y, R = p.X + sz.X }
                    setHot(true)
                end
            end)
            Connect(UserInputService.InputChanged, function(input)
                if dragging and anchors and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    applyDrag(mode, input.Position, anchors)
                end
            end)
            Connect(UserInputService.InputEnded, function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                    dragging = false
                    setHot(false)
                    onResizeEnd()
                end
            end)
            return h
        end

        Handle("Right", UDim2.new(1, -EDGE, 0, 46), UDim2.new(0, EDGE, 1, -46 - CORNER), "r", false)
        Handle("Left", UDim2.new(0, 0, 0, 46), UDim2.new(0, EDGE, 1, -46 - EDGE), "l", false)
        Handle("Bottom", UDim2.new(0, 0, 1, -EDGE), UDim2.new(1, -CORNER, 0, EDGE), "b", false)
        Handle("Corner", UDim2.new(1, -CORNER, 1, -CORNER), UDim2.fromOffset(CORNER, CORNER), "d", true)
    end

    avatarBtn.MouseButton1Click:Connect(function()
        if windowObj.HomeTab then windowObj:SelectTab(windowObj.HomeTab) end
    end)

    closeBtn.MouseButton1Click:Connect(function() windowObj:SetVisible(false) end)
    minBtn.MouseButton1Click:Connect(function()
        windowObj:CloseSearch()
        windowObj:Minimize()
    end)

    Connect(UserInputService.InputBegan, function(input, gpe)
        if gpe then return end
        if input.KeyCode == windowObj.ToggleKeybind then windowObj:Toggle() end
        if input.KeyCode == Enum.KeyCode.F and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            and main.Visible and windowObj._search then
            windowObj:ToggleSearch()
        end
    end)

    local wantButton = opts.ToggleButton
    if wantButton == nil then wantButton = mobile end
    if wantButton then
        local fb = Create("TextButton", {
            Name = "ToggleButton", BackgroundColor3 = Theme.Secondary,
            Position = UDim2.new(0, 16, 0.5, -24), Size = UDim2.fromOffset(48, 48),
            Text = "", AutoButtonColor = false, Parent = gui,
        })
        Corner(fb, 12)
        Stroke(fb, Theme.Border, 1)
        local fic = NewIcon(fb, logoSrc, customLogo and 30 or 22, customLogo and Color3.new(1, 1, 1) or Theme.Accent, "V")
        fic.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
        fic.Instance.Position = UDim2.fromScale(0.5, 0.5)
        local drag = MakeDraggable(fb, fb)
        fb.MouseButton1Click:Connect(function()
            if drag.Moved < 6 then windowObj:Toggle() end
        end)
        windowObj.ToggleButton = fb
    end

    if Anim() and opts.Loading == false then
        local s = uiScale.Scale
        uiScale.Scale = s * 0.86
        Tween(uiScale, 0.5, { Scale = s }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end

    if opts.Loading ~= false then
        main.Visible = false
        task.defer(function()
            if not windowObj.Alive then return end
            RavineUI:ShowLoader({
                Duration = type(opts.Loading) == "table" and opts.Loading.Duration or 1.8,
                Steps = type(opts.Loading) == "table" and opts.Loading.Steps or nil,
                Title = title,
                Subtitle = subtitle ~= "" and subtitle or "Loading",
                Icon = logoSrc,
            })
        end)
    end

    if opts.Weather then
        windowObj:SetBackdrop(true)
        windowObj:SetWeather(opts.Weather)
    end

    return windowObj
end

function Window:Toggle()
    if self.Minimized then self:Restore(); return end
    self:SetVisible(not self._shown)
end

function Window:SetVisible(v)
    v = v and true or false
    if self._shown == v then return end
    self._shown = v
    TipHide()
    local main, us = self.Main, self.Scale
    self._visToken = (self._visToken or 0) + 1
    local token = self._visToken
    if v then
        if self._updateScale then self._updateScale() end
        if Anim() then
            local s = us.Scale
            us.Scale = s * 0.88
            main.Visible = true
            Tween(us, 0.4, { Scale = s }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        else
            main.Visible = true
        end
    else
        self:CloseSearch()
        if Anim() then
            local s = us.Scale
            Tween(us, 0.16, { Scale = s * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.delay(0.17, function()
                if self._visToken == token then
                    main.Visible = false
                    us.Scale = s
                end
            end)
        else
            main.Visible = false
        end
    end
end

function Window:_MoveIndicator(tab, instant)
    local ind, bar = self._indicator, self._indBar
    if not ind then return end
    local idx = table.find(self.Tabs, tab) or 1
    local y = 10 + (idx - 1) * 48
    local pos = UDim2.fromOffset(9, y)
    local barPos = UDim2.fromOffset(0, y + 11)
    ind.Visible = true
    bar.Visible = true
    if instant or not Anim() then
        ind.Position = pos
        bar.Position = barPos
    else
        Tween(ind, 0.35, { Position = pos }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        task.delay(0.05, function()
            if bar.Parent then Tween(bar, 0.35, { Position = barPos }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out) end
        end)
    end
end

function Window:SetAvatarHidden(hidden)
    hidden = hidden and true or false
    self.AvatarHidden = hidden
    if self.AvatarButton then self.AvatarButton.ImageTransparency = hidden and 1 or 0 end
    if self.AvatarHiddenIcon then self.AvatarHiddenIcon.Instance.Visible = hidden end
end

function Window:SetLogoSize(px)
    px = math.clamp(tonumber(px) or 32, 12, 44)
    local inst = self.Logo.Instance
    inst.Size = UDim2.fromOffset(px, px)
    local titleX = self._logoX + px + 10
    self.TitleHolder.Position = UDim2.new(0, titleX, 0, 0)
    self.TitleHolder.Size = UDim2.new(1, -(titleX + (self._reserve or 122)), 1, 0)
end

function Window:SetScale(scale, save)
    if scale then
        self.UserScale = math.clamp(tonumber(scale) or 1, 0.25, 2)
    else
        self.UserScale = nil
    end
    if self._updateScale then self._updateScale() end
    if save and self.UserScale then WriteSavedScale(self.Scale.Scale, RavineUI.IsMobile) end
end

function Window:GetScale() return self.Scale.Scale end

function Window:GetMaxScale()
    local ps = self.Gui.AbsoluteSize
    if ps.X <= 0 or ps.Y <= 0 then
        local cam = workspace.CurrentCamera
        ps = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    end
    return math.clamp(
        math.min((ps.X - 24) / math.max(self.Size.X.Offset, 1), (ps.Y - 24) / math.max(self.Size.Y.Offset, 1)),
        0.25, 2
    )
end

function Window:SetTransparency(t)
    t = math.clamp(tonumber(t) or 0.04, 0, 0.7)
    RavineUI.ThemeState.Transparency = t
    self.Main.BackgroundTransparency = t
    RavineUI:_QueueThemeSave()
end

function Window:OpenSearch(query) if self._search and not self.Minimized then self._search.SetOpen(true, query) end end
function Window:CloseSearch() if self._search then self._search.SetOpen(false) end end
function Window:ToggleSearch() if self._search and not self.Minimized then self._search.SetOpen(not self._search.IsOpen) end end
function Window:IsSearchOpen() return self._search ~= nil and self._search.IsOpen end
function Window:AddSearchEntry(entry) if self._search and type(entry) == "table" and entry.Tab then self._search.Add(entry) end end
function Window:Notify(opts) RavineUI:Notify(opts) end

function Window:Destroy()
    self.Alive = false
    self.Main:Destroy()
    if self.ToggleButton then self.ToggleButton:Destroy() end
    if self._miniBar then self._miniBar:Destroy() end
end

function Window:AddTab(name, icon)
    local tab = setmetatable({ Name = name, Window = self, Icon = icon, Groupboxes = {} }, Tab)
    local btn = Create("TextButton", {
        Name = name, BackgroundColor3 = Theme.Tertiary, BackgroundTransparency = 1,
        BorderSizePixel = 0, Size = UDim2.fromOffset(42, 42),
        LayoutOrder = #self.Tabs + 1, Text = "", AutoButtonColor = false, Parent = self.TabBar,
    })
    Corner(btn, 10)
    local strk = Stroke(btn, Theme.Border, 1)
    strk.Transparency = 1
    local ic = NewIcon(btn, icon, 20, Theme.SubText, string.upper(string.sub(name, 1, 1)))
    ic.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    ic.Instance.Position = UDim2.fromScale(0.5, 0.5)
    local tip = Create("TextLabel", {
        BackgroundColor3 = Theme.Secondary, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(1, 10, 0.5, 0), AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.fromOffset(0, 0), Font = Theme.Font, Text = name,
        TextColor3 = Theme.Text, TextSize = 12, Visible = false, ZIndex = 10, Parent = btn,
    })
    Corner(tip, 6)
    Stroke(tip, Theme.Border, 1)
    Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), Parent = tip })

    local frame = Create("Frame", { Name = name .. "_Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = self.Content })
    Create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = frame })

    local function Column(nameStr, pos)
        local col = Create("ScrollingFrame", {
            Name = nameStr, BackgroundTransparency = 1, BorderSizePixel = 0, Position = pos,
            Size = UDim2.new(0.5, -5, 1, 0), CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Border, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = frame,
        })
        Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = col })
        Create("UIPadding", { PaddingRight = UDim.new(0, 4), Parent = col })
        return col
    end

    tab.Button = btn
    tab.Frame = frame
    tab.Left = Column("Left", UDim2.new(0, 0, 0, 0))
    tab.Right = Column("Right", UDim2.new(0.5, 5, 0, 0))
    tab._btn = btn
    tab._stroke = strk
    tab._icon = ic

    btn.MouseEnter:Connect(function()
        tip.Visible = true
        if self.ActiveTab ~= tab then
            Tween(btn, 0.15, { BackgroundTransparency = 0.6 })
            TintIcon(ic, Theme.Text)
        end
    end)
    btn.MouseLeave:Connect(function()
        tip.Visible = false
        if self.ActiveTab ~= tab then
            Tween(btn, 0.15, { BackgroundTransparency = 1 })
            TintIcon(ic, Theme.SubText)
        end
    end)
    btn.MouseButton1Click:Connect(function()
        if RavineUI.IsMobile then tip.Visible = false end
        self:SelectTab(tab)
    end)

    table.insert(self.Tabs, tab)

    if self._search then
        self._search.Add({ Name = name, Type = "Tab", Tab = tab, Group = "" })
    end

    if not self.ActiveTab then self:SelectTab(tab) end
    if self._ensureHeight then self._ensureHeight(116 + 48 * #self.Tabs) end
    return tab
end

function Window:SelectTab(tab)
    if self._search then self._search.SetOpen(false) end
    if self.ActiveTab == tab then return end
    TipHide()
    local first = self.ActiveTab == nil
    for _, t in ipairs(self.Tabs) do
        t.Frame.Visible = false
        t:_SetActive(false)
    end
    self.ActiveTab = tab
    tab.Frame.Visible = true
    tab:_SetActive(true)
    self:_MoveIndicator(tab, first)
    if not first then tab:_PlayIntro() end
end

-- ============ HOME TAB ============
local HomeFile = "RavineUI/home.json"

local function ReadHomeData()
    local data = { Execs = {} }
    if not HasFS() then return data end
    pcall(function()
        if isfile(HomeFile) then
            local d = HttpService:JSONDecode(readfile(HomeFile))
            if type(d) == "table" then
                data = d
                if type(data.Execs) ~= "table" then data.Execs = {} end
            end
        end
    end)
    return data
end

local function WriteHomeData(data)
    if not HasFS() then return end
    pcall(function() EnsureFolders(); writefile(HomeFile, HttpService:JSONEncode(data)) end)
end

local KeyShort = {
    RightControl = "RCtrl", LeftControl = "LCtrl", RightShift = "RShift", LeftShift = "LShift",
    RightAlt = "RAlt", LeftAlt = "LAlt", Insert = "Ins", Delete = "Del", Return = "Enter",
    Backspace = "Bksp", PageUp = "PgUp", PageDown = "PgDn", Escape = "Esc",
}

local function ShortKey(name) return KeyShort[name] or name end

local function FormatSession(s)
    s = math.floor(s)
    if s >= 3600 then return string.format("%dh %dm", s // 3600, (s % 3600) // 60) end
    if s >= 60 then return string.format("%dm %ds", s // 60, s % 60) end
    return s .. "s"
end

local function FetchServers(sort)
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100&excludeFullGames=true", game.PlaceId, sort)
    local ok, res = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
    if ok and type(res) == "table" and type(res.data) == "table" then return res.data end
    return nil
end

local function PickServer(mode)
    local list = FetchServers(mode == "lowest" and "Asc" or "Desc")
    if not list then return nil end
    local pool = {}
    for _, s in ipairs(list) do
        if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
            table.insert(pool, s)
        end
    end
    if #pool == 0 then return nil end
    if mode == "lowest" then return pool[1] end
    return pool[math.random(#pool)]
end

local function RejoinServer()
    if #Players:GetPlayers() <= 1 then
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    else
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
end

local GRAPH_BAR = Color3.fromRGB(62, 62, 70)
local BAD_COLOR = Color3.fromRGB(231, 76, 60)

local function MakeGraph(parent, position, size, n)
    local holder = Create("Frame", { BackgroundTransparency = 1, Position = position, Size = size, Parent = parent })
    local bars, values = {}, {}
    for i = 1, n do
        values[i] = 0
        bars[i] = Create("Frame", {
            BackgroundColor3 = GRAPH_BAR, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 1), Position = UDim2.new((i - 1) / n, 0, 1, 0),
            Size = UDim2.new(1 / n, -2, 0.06, 0), Parent = holder,
        }, true)
        Corner(bars[i], 1)
    end
    local api = {}
    function api.Push(v, color, minMax)
        table.remove(values, 1)
        table.insert(values, v)
        local maxV = minMax or 1
        for _, x in ipairs(values) do if x > maxV then maxV = x end end
        for i = 1, n do
            local h = math.max(values[i] / maxV, 0.06)
            Tween(bars[i], 0.4, {
                Size = UDim2.new(1 / n, -2, h, 0),
                BackgroundColor3 = (i == n) and color or GRAPH_BAR,
            }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end
    end
    return api
end

local function HomeChip(parent, order, icon, text, onClick)
    local btn = Create("TextButton", {
        BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26),
        LayoutOrder = order, Text = "", AutoButtonColor = false, Parent = parent,
    })
    Corner(btn, 7)
    local st = Stroke(btn, Theme.Border, 1)
    if onClick then Ripple(btn) end
    Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12), Parent = btn })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = btn,
    })
    local static = onClick == nil
    local baseColor = static and Theme.Text or Theme.SubText
    local ic = NewIcon(btn, icon, 13, baseColor, "*")
    ic.Instance.LayoutOrder = 1
    local lbl = Create("TextLabel", {
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 14), LayoutOrder = 2, Font = Theme.FontBold,
        Text = text, TextColor3 = baseColor, TextSize = 11, Parent = btn,
    })
    local active, hovering = false, false
    local api = { Button = btn }
    local function paint()
        local c = baseColor
        if active then c = Theme.Accent
        elseif hovering and not static then c = Theme.Text end
        TintIcon(ic, c)
        Tween(lbl, 0.15, { TextColor3 = c })
        Tween(st, 0.15, { Color = (active or (hovering and not static)) and Theme.Accent or Theme.Border })
    end
    btn.MouseEnter:Connect(function() hovering = true; paint() end)
    btn.MouseLeave:Connect(function() hovering = false; paint() end)
    api.SetActive = function(v) active = v and true or false; paint() end
    if onClick then btn.MouseButton1Click:Connect(onClick) end
    return api
end

local function HomeTile(parent, order, icon, text, onClick)
    local btn = Create("TextButton", {
        BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
        Size = UDim2.new(0.25, -5, 1, 0), LayoutOrder = order, Text = "",
        AutoButtonColor = false, Parent = parent,
    })
    Corner(btn, 8)
    local st = Stroke(btn, Theme.Border, 1)
    Ripple(btn)
    local holder = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = btn })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6), Parent = holder,
    })
    local ic = NewIcon(holder, icon, 16, Theme.SubText, "*")
    ic.Instance.LayoutOrder = 1
    local lbl = Create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 14), LayoutOrder = 2,
        Font = Theme.Font, Text = text, TextColor3 = Theme.SubText, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.None,
        RichText = false, Parent = holder,
    })
    btn.MouseEnter:Connect(function() TintIcon(ic, Theme.Text); Tween(lbl, 0.15, { TextColor3 = Theme.Text }); Tween(st, 0.15, { Color = Theme.Accent }) end)
    btn.MouseLeave:Connect(function() TintIcon(ic, Theme.SubText); Tween(lbl, 0.15, { TextColor3 = Theme.SubText }); Tween(st, 0.15, { Color = Theme.Border }) end)
    btn.MouseButton1Click:Connect(function() task.spawn(onClick) end)
    return btn
end

local function HomeLink(parent, order, icon, title, desc, onClick)
    local row = Create("TextButton", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 46),
        LayoutOrder = order, Text = "", AutoButtonColor = false, Parent = parent,
    })
    local ic = NewIcon(row, icon, 16, Theme.SubText, "*")
    ic.Instance.AnchorPoint = Vector2.new(0, 0.5)
    ic.Instance.Position = UDim2.new(0, 6, 0.5, 0)
    Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 34, 0, 6),
        Size = UDim2.new(1, -84, 0, 16), Font = Theme.FontBold, Text = title,
        TextColor3 = Theme.Text, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local descLbl = Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 34, 0, 23),
        Size = UDim2.new(1, -84, 0, 14), Font = Theme.Font, Text = desc or "",
        TextColor3 = Theme.SubText, TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local chev = Create("Frame", {
        BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(30, 30), Parent = row,
    })
    Corner(chev, 8)
    local cst = Stroke(chev, Theme.Border, 1)
    local cic = NewIcon(chev, "chevron-right", 14, Theme.SubText, ">")
    cic.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    cic.Instance.Position = UDim2.fromScale(0.5, 0.5)
    row.MouseEnter:Connect(function()
        TintIcon(ic, Theme.Text); TintIcon(cic, Theme.Text)
        Tween(cst, 0.15, { Color = Theme.Accent })
        Tween(cic.Instance, 0.3, { Position = UDim2.new(0.5, 3, 0.5, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)
    row.MouseLeave:Connect(function()
        TintIcon(ic, Theme.SubText); TintIcon(cic, Theme.SubText)
        Tween(cst, 0.15, { Color = Theme.Border })
        Tween(cic.Instance, 0.3, { Position = UDim2.new(0.5, 0, 0.5, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    end)
    row.MouseButton1Click:Connect(function() task.spawn(onClick) end)
    return { SetDesc = function(text) descLbl.Text = text end }
end

function Window:GetFeatureCount()
    local features, tabs, seen = 0, 0, {}
    if self._search then
        for _, e in ipairs(self._search.Entries) do
            if e.Type ~= "Tab" and e.Tab and not e.Tab._internal then
                features = features + 1
                if not seen[e.Tab] then seen[e.Tab] = true; tabs = tabs + 1 end
            end
        end
    end
    return features, tabs
end

function Window:OpenFeatureList()
    if self._search and not self.Minimized then
        self._search.OpenList()
    else
        RavineUI:Notify({ Title = "Feature list", Description = "Search is disabled for this window", Icon = "info" })
    end
end

function Window:AddHomeTab(opts)
    opts = opts or {}
    local tab = self:AddTab(opts.Name or "Home", opts.Icon or "house")
    tab._internal = true
    tab.Left:Destroy()
    tab.Right:Destroy()
    self.HomeTab = tab

    local home = {}
    tab.Home = home

    local data = ReadHomeData()
    local uid = tostring(LocalPlayer.UserId)
    local prefs = { HideName = data.HideName == true, HideAvatar = data.HideAvatar == true }
    local function saveData()
        data.HideName = prefs.HideName
        data.HideAvatar = prefs.HideAvatar
        WriteHomeData(data)
    end

    local page = Create("ScrollingFrame", {
        Name = "HomePage", BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Border, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = tab.Frame,
    })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10), Parent = page })
    Create("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 2), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = page })

    local function Label(parent, props)
        props.BackgroundTransparency = 1
        props.Parent = parent
        props.Font = props.Font or Theme.Font
        props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
        return Create("TextLabel", props)
    end

    local header = Card(page, UDim2.new(1, 0, 0, 108), Theme.Secondary)
    header.LayoutOrder = 1
    header.ClipsDescendants = true

    Label(header, {
        Position = UDim2.new(0, 22, 0, 14), Size = UDim2.new(1, -170, 0, 12),
        Text = string.upper(opts.Greeting or "Welcome back"), TextColor3 = Theme.SubText, TextSize = 10,
    })
    local nameLabel = Label(header, {
        Position = UDim2.new(0, 22, 0, 26), Size = UDim2.new(1, -170, 0, 28),
        Font = Theme.FontBold, Text = LocalPlayer.DisplayName, TextColor3 = Theme.Text, TextSize = 24,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local userLabel = Label(header, {
        Position = UDim2.new(0, 22, 0, 55), Size = UDim2.new(1, -170, 0, 14),
        Text = "@" .. LocalPlayer.Name, TextColor3 = Theme.SubText, TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local avatar = Create("ImageLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -14, 1, 8), Size = UDim2.fromOffset(110, 110),
        ScaleType = Enum.ScaleType.Fit, Parent = header,
    })
    local avatarHidden = Create("Frame", {
        BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -28, 0.5, 0),
        Size = UDim2.fromOffset(64, 64), Visible = false, Parent = header,
    })
    Corner(avatarHidden, 14)
    Stroke(avatarHidden, Theme.Border, 1)
    local hiddenIc = NewIcon(avatarHidden, "eye-off", 22, Theme.SubText, "?")
    hiddenIc.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    hiddenIc.Instance.Position = UDim2.fromScale(0.5, 0.5)

    task.spawn(function()
        local ok, url = pcall(Players.GetUserThumbnailAsync, Players, LocalPlayer.UserId,
            Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size180x180)
        if avatar.Parent then
            if ok and url then avatar.Image = url else LoadAvatar(avatar) end
        end
    end)

    local chips = Create("Frame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 22, 0, 76),
        Size = UDim2.new(1, -170, 0, 26), Parent = header,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = chips,
    })

    local nameChip, avatarChip
    local function applyPrivacy()
        nameLabel.Text = prefs.HideName and "Hidden" or LocalPlayer.DisplayName
        userLabel.Text = prefs.HideName and "@hidden" or ("@" .. LocalPlayer.Name)
        avatar.Visible = not prefs.HideAvatar
        avatarHidden.Visible = prefs.HideAvatar
        self:SetAvatarHidden(prefs.HideAvatar)
        if nameChip then nameChip.SetActive(prefs.HideName) end
        if avatarChip then avatarChip.SetActive(prefs.HideAvatar) end
    end

    if opts.Badge ~= false then
        HomeChip(chips, 1, opts.BadgeIcon or "swords", opts.Badge or "Beta", nil)
    end
    nameChip = HomeChip(chips, 2, "eye-off", "Name", function()
        prefs.HideName = not prefs.HideName
        applyPrivacy(); saveData()
    end)
    avatarChip = HomeChip(chips, 3, "user-round", "Avatar", function()
        prefs.HideAvatar = not prefs.HideAvatar
        applyPrivacy(); saveData()
    end)
    applyPrivacy()

    local perf = Card(page, UDim2.new(1, 0, 0, 128), Theme.Secondary)
    perf.LayoutOrder = 2
    local BARS = 32
    local function PerfColumn(xScale, xOffset, icon, title)
        local col = Create("Frame", {
            BackgroundTransparency = 1, Position = UDim2.new(xScale, xOffset, 0, 12),
            Size = UDim2.new(0.5, -24, 0, 74), Parent = perf,
        })
        local ic = NewIcon(col, icon, 11, Theme.SubText, "")
        ic.Instance.Position = UDim2.fromOffset(0, 1)
        Label(col, {
            Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -16, 0, 14),
            Text = title, TextColor3 = Theme.SubText, TextSize = 10,
        })
        local value = Label(col, {
            Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 28),
            Font = Theme.FontBold, Text = "-", TextColor3 = Theme.Success, TextSize = 24,
        })
        local graph = MakeGraph(col, UDim2.fromOffset(0, 48), UDim2.new(1, 0, 0, 26), BARS)
        return value, graph
    end
    local fpsValue, fpsGraph = PerfColumn(0, 16, "gauge", "FPS")
    local pingValue, pingGraph = PerfColumn(0.5, 8, "wifi", "PING")

    Create("Frame", {
        BackgroundColor3 = Theme.Border, BorderSizePixel = 0,
        Position = UDim2.new(0, 16, 0, 90), Size = UDim2.new(1, -32, 0, 1), Parent = perf,
    })

    local function Stat(i, title)
        local v = Label(perf, {
            Position = UDim2.new((i - 1) / 3, 16, 0, 96),
            Size = UDim2.new(1 / 3, -16, 0, 16), Font = Theme.FontBold,
            Text = "-", TextColor3 = Theme.Text, TextSize = 13,
        })
        Label(perf, {
            Position = UDim2.new((i - 1) / 3, 16, 0, 112),
            Size = UDim2.new(1 / 3, -16, 0, 12), Text = title, TextColor3 = Theme.SubText, TextSize = 9,
        })
        return v
    end
    local sPlayers = Stat(1, "PLAYERS")
    local sExecs = Stat(2, "EXECS")
    local sSession = Stat(3, "SESSION")

    local execShown = 0
    home.SetExecutions = function(n)
        local num = tonumber(n)
        if num then
            CountTo(sExecs, execShown, num, tostring, 1.1)
            execShown = num
        else
            sExecs.Text = tostring(n)
        end
    end
    if type(opts.Executions) == "number" then
        home.SetExecutions(opts.Executions)
    elseif type(opts.Executions) == "function" then
        home.SetExecutions("...")
        task.spawn(function()
            local ok, v = pcall(opts.Executions)
            home.SetExecutions(ok and v or "N/A")
        end)
    else
        local n = (tonumber(data.Execs[uid]) or 0) + 1
        data.Execs[uid] = n
        saveData()
        home.SetExecutions(n)
    end

    -- Discord Card
    local discordCard
    local hasDiscordCard = (opts.Discord ~= nil and opts.Discord ~= "") and opts.DiscordCard ~= false
    if hasDiscordCard then
        local BLURPLE = Color3.fromRGB(88, 101, 242)
        local BLURPLE_LIGHT = Color3.fromRGB(112, 124, 255)
        discordCard = Card(page, UDim2.new(1, 0, 0, 76), Theme.Secondary)
        discordCard.LayoutOrder = 3
        discordCard.ClipsDescendants = true
        Glow(discordCard, BLURPLE, 0, 0.2)
        local iconBox = Create("Frame", {
            BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
            Position = UDim2.fromOffset(14, 15), Size = UDim2.fromOffset(46, 46), Parent = discordCard,
        })
        Corner(iconBox, 12)
        Stroke(iconBox, Theme.Border, 1)
        local dIcon = NewIcon(iconBox, "message-circle", 22, BLURPLE, "D")
        dIcon.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
        dIcon.Instance.Position = UDim2.fromScale(0.5, 0.5)
        local dImg = Create("ImageLabel", {
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
            ScaleType = Enum.ScaleType.Crop, Visible = false, Parent = iconBox,
        })
        Corner(dImg, 12)
        local nameLbl = Label(discordCard, {
            Position = UDim2.fromOffset(70, 17), Size = UDim2.new(1, -200, 0, 18),
            Font = Theme.FontBold, Text = "Discord", TextColor3 = Theme.Text, TextSize = 14,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        local stat = Create("Frame", {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(70, 40),
            Size = UDim2.new(1, -200, 0, 16), Parent = discordCard,
        })
        Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = stat,
        })
        local liveDot = Create("Frame", {
            BackgroundColor3 = Theme.Success, BorderSizePixel = 0,
            Size = UDim2.fromOffset(8, 8), LayoutOrder = 1, Parent = stat,
        })
        Corner(liveDot, 4)
        local onlineLbl = Label(stat, {
            AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), LayoutOrder = 2,
            Font = Theme.FontBold, Text = "Loading...", TextColor3 = Theme.Text, TextSize = 11,
        })
        local sep = Create("Frame", {
            BackgroundColor3 = Theme.Divider, BorderSizePixel = 0,
            Size = UDim2.fromOffset(3, 3), LayoutOrder = 3, Visible = false, Parent = stat,
        })
        Corner(sep, 2)
        local membersLbl = Label(stat, {
            AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), LayoutOrder = 4,
            Text = "", TextColor3 = Theme.SubText, TextSize = 11,
        })
        local joinBtn = Create("TextButton", {
            BackgroundColor3 = BLURPLE, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
            Size = UDim2.fromOffset(112, 34), Font = Theme.FontBold, Text = "Join server",
            TextColor3 = Color3.new(1, 1, 1), TextSize = 13, AutoButtonColor = false, Parent = discordCard,
        }, true)
        Corner(joinBtn, 8)
        Ripple(joinBtn)
        joinBtn.MouseEnter:Connect(function() Tween(joinBtn, 0.15, { BackgroundColor3 = BLURPLE_LIGHT }) end)
        joinBtn.MouseLeave:Connect(function() Tween(joinBtn, 0.2, { BackgroundColor3 = BLURPLE }) end)
        joinBtn.MouseButton1Click:Connect(function() task.spawn(JoinDiscord, opts.Discord) end)
        local shownOnline, shownMembers = 0, 0
        local function refreshDiscord(first)
            task.spawn(function()
                local d = FetchDiscord(opts.Discord)
                if not discordCard.Parent then return end
                if not d then
                    if first then onlineLbl.Text = "Join the community"; liveDot.Visible = false end
                    return
                end
                nameLbl.Text = d.Name
                liveDot.Visible = d.Online ~= nil
                if d.Online then
                    CountTo(onlineLbl, shownOnline, d.Online, function(n) return NumFmt(n) .. " online" end, 1.2)
                    shownOnline = d.Online
                else
                    onlineLbl.Text = "Live stats unavailable"
                end
                if d.Members then
                    sep.Visible = d.Online ~= nil
                    CountTo(membersLbl, shownMembers, d.Members, function(n) return NumFmt(n) .. " members" end, 1.2)
                    shownMembers = d.Members
                end
                if first then
                    LoadDiscordIcon(dImg, d, function() dImg.Visible = true; dIcon.Instance.Visible = false end)
                end
            end)
        end
        refreshDiscord(true)
        task.spawn(function()
            while self.Alive and not RavineUI.Unloaded and discordCard.Parent do
                task.wait(60)
                if discordCard.Parent then refreshDiscord(false) end
            end
        end)
        task.spawn(function()
            while self.Alive and not RavineUI.Unloaded and discordCard.Parent do
                if Anim() and liveDot.Visible then
                    Tween(liveDot, 0.9, { BackgroundTransparency = 0.65 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                    task.wait(0.9)
                    Tween(liveDot, 0.9, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                    task.wait(0.9)
                else
                    task.wait(1)
                end
            end
        end)
    end

    local mid = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 176), LayoutOrder = 4, Parent = page })
    local gameCard = Card(mid, UDim2.new(0.62, -5, 1, 0), Theme.Secondary)
    local thumb = Create("ImageLabel", {
        BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
        Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(46, 46),
        ScaleType = Enum.ScaleType.Crop,
        Image = string.format("rbxthumb://type=GameIcon&id=%d&w=150&h=150", game.GameId), Parent = gameCard,
    })
    Corner(thumb, 8)
    Stroke(thumb, Theme.Border, 1)
    local gameName = Label(gameCard, {
        Position = UDim2.new(0, 70, 0, 15), Size = UDim2.new(1, -84, 0, 18),
        Font = Theme.FontBold, Text = "Loading...", TextColor3 = Theme.Text,
        TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local gameSub = Label(gameCard, {
        Position = UDim2.new(0, 70, 0, 35), Size = UDim2.new(1, -84, 0, 14),
        Text = "", TextColor3 = Theme.SubText, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local creatorName = ""
    task.spawn(function()
        local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
        if ok and type(info) == "table" then
            gameName.Text = tostring(info.Name or "Unknown game")
            creatorName = info.Creator and tostring(info.Creator.Name) or ""
        else
            gameName.Text = "Unknown game"
        end
    end)
    local tiles = Create("Frame", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 72),
        Size = UDim2.new(1, -28, 0, 62), Parent = gameCard,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6), Parent = tiles,
    })
    local busy = false
    local function teleportTo(mode)
        if busy then return end
        busy = true
        RavineUI:Notify({ Title = mode == "lowest" and "Lowest server" or "Server hop", Description = "Searching for a server...", Icon = "search" })
        local server = PickServer(mode)
        if not server then
            busy = false
            RavineUI:Notify({ Title = "No server found", Description = "Try again in a moment", Icon = "triangle-alert" })
            return
        end
        local ok = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer) end)
        if not ok then
            RavineUI:Notify({ Title = "Teleport failed", Description = "Could not join that server", Icon = "triangle-alert" })
        end
        task.delay(4, function() busy = false end)
    end
    HomeTile(tiles, 1, "refresh-cw", "Rejoin", function()
        RavineUI:Notify({ Title = "Rejoin", Description = "Rejoining this server...", Icon = "refresh-cw" })
        pcall(RejoinServer)
    end)
    HomeTile(tiles, 2, "shuffle", "Hop", function() teleportTo("random") end)
    HomeTile(tiles, 3, "users", "Lowest", function() teleportTo("lowest") end)
    HomeTile(tiles, 4, "copy", "Job ID", function()
        local ok = Copy(game.JobId)
        RavineUI:Notify({ Title = ok and "Copied" or "Copy failed", Description = ok and "Job ID copied to clipboard" or "Your executor has no clipboard function", Icon = ok and "copy" or "triangle-alert" })
    end)
    local jobId = game.JobId
    local jobShort = jobId == "" and "-" or (#jobId > 14 and (jobId:sub(1, 8) .. ".." .. jobId:sub(-4)) or jobId)
    Label(gameCard, {
        Position = UDim2.new(0, 14, 0, 148), Size = UDim2.new(1, -28, 0, 14),
        Text = "Job " .. jobShort .. "   \u{b7}   Place " .. tostring(game.PlaceId),
        TextColor3 = Theme.SubText, TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local linkCard = Card(mid, UDim2.new(0.38, -5, 1, 0), Theme.Secondary)
    linkCard.Position = UDim2.new(0.62, 5, 0, 0)
    Label(linkCard, {
        Position = UDim2.new(0, 16, 0, 12), Size = UDim2.new(1, -32, 0, 12),
        Text = "LINKS", TextColor3 = Theme.SubText, TextSize = 10,
    })
    local linkList = Create("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 0, 32), Size = UDim2.new(1, -20, 1, -40),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.Border,
        ScrollingDirection = Enum.ScrollingDirection.Y, Parent = linkCard,
    })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = linkList })
    local linkOrder = 0
    local featureRow
    if opts.FeatureList ~= false then
        linkOrder = linkOrder + 1
        featureRow = HomeLink(linkList, linkOrder, "list-checks", "Feature list", "Counting features...", function()
            self:OpenFeatureList()
        end)
    end
    if opts.Discord and opts.Discord ~= "" and not hasDiscordCard then
        linkOrder = linkOrder + 1
        HomeLink(linkList, linkOrder, "message-circle", "Discord", "Tap to join the server", function()
            JoinDiscord(opts.Discord)
        end)
    end
    local cl = opts.Changelog or RavineUI._LastChangelog
    if type(cl) == "table" then
        linkOrder = linkOrder + 1
        local count = type(cl.Entries) == "table" and #cl.Entries or 0
        HomeLink(linkList, linkOrder, "scroll-text", "Changelog",
            "Version " .. tostring(cl.Version or RavineUI.Version) .. " - " .. Plural(count, "change"),
            function()
                local copy = {}
                for k, v in pairs(cl) do if k ~= "OnClose" then copy[k] = v end end
                RavineUI:ShowChangelog(copy)
            end)
    end
    for _, l in ipairs(opts.Links or {}) do
        linkOrder = linkOrder + 1
        HomeLink(linkList, linkOrder, l.Icon or "link", l.Name or "Link", l.Description or l.Url or "", function()
            if l.Callback then task.spawn(l.Callback)
            elseif l.Url then
                local ok = Copy(l.Url)
                RavineUI:Notify({ Title = ok and "Link copied" or "Copy failed", Description = ok and l.Url or "Your executor has no clipboard function", Icon = ok and "link" or "triangle-alert" })
            end
        end)
    end

    local required = opts.RequiredFunctions or { "loadstring" }
    local supported = true
    local env = (getgenv and getgenv()) or _G
    for _, fn in ipairs(required) do
        if env[fn] == nil then supported = false; break end
    end
    local statusRow = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 5, Parent = page })
    local statusLeft = Create("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), Parent = statusRow })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = statusLeft,
    })
    Create("UIPadding", { PaddingLeft = UDim.new(0, 6), Parent = statusLeft })
    local dot = Create("Frame", {
        BackgroundColor3 = supported and Theme.Success or Theme.Warning, BorderSizePixel = 0,
        Size = UDim2.fromOffset(8, 8), LayoutOrder = 1, Parent = statusLeft,
    })
    Corner(dot, 4)
    Label(statusLeft, {
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), LayoutOrder = 2,
        Font = Theme.FontBold, Text = GetExecutorName(), TextColor3 = Theme.Text, TextSize = 12,
    })
    Label(statusLeft, {
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), LayoutOrder = 3,
        Text = supported and "Your executor is supported and fully compatible." or "Your executor might not support all features.",
        TextColor3 = Theme.SubText, TextSize = 11,
    })
    local statusRight = Create("Frame", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0),
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), Parent = statusRow,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = statusRight,
    })
    Label(statusRight, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), LayoutOrder = 1, Text = "Hide with", TextColor3 = Theme.SubText, TextSize = 11 })
    local keyBadge = Create("Frame", {
        BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 22), LayoutOrder = 2, Parent = statusRight,
    })
    Corner(keyBadge, 6)
    Stroke(keyBadge, Theme.Border, 1)
    Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = keyBadge })
    local keyLabel = Label(keyBadge, {
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22),
        Font = Theme.FontBold, Text = ShortKey(self.ToggleKeybind.Name), TextColor3 = Theme.Text, TextSize = 11,
    })

    local accountRows = {}
    local accountCard
    if opts.Account ~= false then
        local acc = type(opts.Account) == "table" and opts.Account or {}
        local box = Card(page, UDim2.new(1, 0, 0, 0), Theme.Secondary)
        box.AutomaticSize = Enum.AutomaticSize.Y
        box.LayoutOrder = 6
        accountCard = box
        Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = box })
        local head = Create("TextButton", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 1,
            Text = "", AutoButtonColor = false, Parent = box,
        })
        local hIc = NewIcon(head, acc.Icon or "shield", 16, Theme.SubText, "*")
        hIc.Instance.AnchorPoint = Vector2.new(0, 0.5)
        hIc.Instance.Position = UDim2.new(0, 16, 0.5, 0)
        Label(head, {
            Position = UDim2.new(0, 44, 0, 0), Size = UDim2.new(1, -90, 1, 0),
            Font = Theme.FontBold, Text = acc.Title or "Account", TextColor3 = Theme.Text, TextSize = 13,
        })
        local chevron = NewIcon(head, "chevron-down", 14, Theme.SubText, "v")
        chevron.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
        chevron.Instance.Position = UDim2.new(1, -24, 0.5, 0)
        local body = Create("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, Parent = box })
        Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
        Create("Frame", { BackgroundColor3 = Theme.Border, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 0, Parent = body })
        local rows = acc.Rows or {
            { Label = "Flagged", Value = opts.Flagged and "Yes" or "No", Color = opts.Flagged and BAD_COLOR or nil },
            { Label = "Account age", Value = function() return LocalPlayer.AccountAge .. " days" end },
            { Label = "User ID", Value = tostring(LocalPlayer.UserId) },
        }
        for i, r in ipairs(rows) do
            local row = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = i, Parent = body })
            Label(row, {
                Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(0.5, -16, 1, 0),
                Text = tostring(r.Label), TextColor3 = Theme.SubText, TextSize = 12,
            })
            local valueLbl = Label(row, {
                Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -16, 1, 0),
                Font = Theme.FontBold, Text = "-", TextColor3 = r.Color or Theme.Text, TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
            })
            local entry = { Label = tostring(r.Label), Lbl = valueLbl, Value = r.Value }
            table.insert(accountRows, entry)
            if type(r.Value) ~= "function" then valueLbl.Text = tostring(r.Value) end
        end
        local collapsed = acc.Collapsed == true
        local function applyCollapse()
            body.Visible = not collapsed
            Tween(chevron.Instance, 0.15, { Rotation = collapsed and -90 or 0 })
        end
        applyCollapse()
        head.MouseEnter:Connect(function() TintIcon(hIc, Theme.Text) end)
        head.MouseLeave:Connect(function() TintIcon(hIc, Theme.SubText) end)
        head.MouseButton1Click:Connect(function() collapsed = not collapsed; applyCollapse() end)
    end

    home.SetAccountRow = function(label, value, color)
        for _, r in ipairs(accountRows) do
            if r.Label == label then
                r.Value = value
                r.Lbl.Text = tostring(type(value) == "function" and value() or value)
                if color then r.Lbl.TextColor3 = color end
            end
        end
    end

    local frames, lastT = 0, os.clock()
    Connect(RunService.Heartbeat, function() frames = frames + 1 end)
    local startClock = os.clock()
    local lastFeatureText = ""
    local function qualityColor(v, goodAt, okAt, higherIsBetter)
        local good, ok
        if higherIsBetter then good, ok = v >= goodAt, v >= okAt
        else good, ok = v <= goodAt, v <= okAt end
        if good then return Theme.Success elseif ok then return Theme.Warning end
        return BAD_COLOR
    end
    local function refresh()
        local now = os.clock()
        local dt = now - lastT
        local fps = dt > 0 and math.floor(frames / dt + 0.5) or 0
        frames = 0
        lastT = now
        self._cachedFPS = fps
        local fc = qualityColor(fps, 50, 30, true)
        fpsValue.Text = tostring(fps)
        fpsValue.TextColor3 = fc
        fpsGraph.Push(fps, fc, 120)
        local ping = GetPing()
        self._cachedPing = ping or 0
        local pc = qualityColor(ping or 999, 80, 150, false)
        pingValue.Text = ping and (ping .. "ms") or "N/A"
        pingValue.TextColor3 = pc
        pingGraph.Push(ping or 0, pc, 150)
        sPlayers.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
        sSession.Text = FormatSession(now - startClock)
        gameSub.Text = (creatorName ~= "" and ("by " .. creatorName .. "  \u{b7}  ") or "")
            .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers .. " players"
        keyLabel.Text = ShortKey(self.ToggleKeybind.Name)
        if featureRow then
            local f, t = self:GetFeatureCount()
            local text = f .. (f == 1 and " feature" or " features") .. " across " .. Plural(t, "tab")
            if text ~= lastFeatureText then
                lastFeatureText = text
                featureRow.SetDesc(text)
            end
        end
        for _, r in ipairs(accountRows) do
            if type(r.Value) == "function" then
                local ok, v = pcall(r.Value)
                r.Lbl.Text = ok and tostring(v) or "N/A"
            end
        end
    end
    task.spawn(function()
        while self.Alive and not RavineUI.Unloaded do
            pcall(refresh)
            task.wait(0.5)
        end
    end)
    local function playCascade()
        if not Anim() then return end
        local items = { header, perf, discordCard, mid, statusRow, accountCard }
        local n = 0
        for _, it in ipairs(items) do
            if it then
                n = n + 1
                local us = it:FindFirstChild("PopScale") or Create("UIScale", { Name = "PopScale", Parent = it })
                us.Scale = 0.9
                task.delay((n - 1) * 0.06, function()
                    if us.Parent then Tween(us, 0.55, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out) end
                end)
            end
        end
    end
    tab._onShow = playCascade
    if self.ActiveTab == tab then playCascade() end
    tab.Refresh = function() pcall(refresh) end
    return tab
end

-- ============ SETTINGS TAB ============
function Window:AddSettingsTab(opts)
    opts = opts or {}
    local tab = self:AddTab(opts.Name or "Settings", opts.Icon or "settings")
    tab._internal = true

    local menu = tab:AddLeftGroupbox("Menu", "layout-dashboard")
    if not RavineUI.IsMobile then
        local keybind = menu:AddKeyPicker("RavineUI_MenuKey", { Text = "Menu keybind", Default = self.ToggleKeybind.Name })
        keybind:OnChanged(function(keyName)
            local ok, key = pcall(function() return Enum.KeyCode[keyName] end)
            if ok and key then self.ToggleKeybind = key end
        end)
    end

    local scaleToken = 0
    self._scaleSlider = menu:AddSlider("RavineUI_Scale", {
        Text = "UI scale", Min = 40,
        Max = math.max(50, math.min(200, math.floor(self:GetMaxScale() * 100))),
        Default = math.floor(self.Scale.Scale * 100 + 0.5),
        Rounding = 0, Suffix = "%",
        Callback = function(v)
            scaleToken += 1
            local token = scaleToken
            task.delay(0.25, function()
                if token == scaleToken then self:SetScale(v / 100, true) end
            end)
        end,
    })
    menu:AddButton("Unload UI", { Icon = "power", Callback = function() RavineUI:Unload() end })

    local look = tab:AddLeftGroupbox("Appearance", "palette")
    local ts = RavineUI.ThemeState
    local syncing = false
    local picker

    local names = RavineUI:GetThemeNames()
    table.insert(names, "Custom")
    local presetDD = look:AddDropdown("RavineUI_ThemePreset", {
        Text = "Theme", Values = names, Default = ts.Preset,
        Callback = function(name)
            if syncing then return end
            if name ~= "Custom" then
                RavineUI:SetTheme(name)
                syncing = true
                if picker then picker.Set(ts.Accent) end
                syncing = false
            else
                ts.Preset = "Custom"
            end
            RavineUI:_QueueThemeSave()
        end,
    })
    picker = look:AddColorPicker("RavineUI_AccentColor", {
        Text = "Accent color", Default = ts.Accent, Searchable = true, Keywords = "color colour theme custom",
        Callback = function(c)
            if syncing then return end
            ts.Preset = "Custom"
            RavineUI:SetAccent(c)
            syncing = true
            presetDD.Set("Custom")
            syncing = false
            RavineUI:_QueueThemeSave()
        end,
    })
    look:AddToggle("RavineUI_Rainbow", {
        Text = "Rainbow accent", Default = ts.Rainbow, Keywords = "rgb animated color",
        Callback = function(v) RavineUI:SetRainbow(v) end,
    })
    look:AddSlider("RavineUI_RainbowSpeed", {
        Text = "Rainbow speed", Min = 2, Max = 100,
        Default = math.clamp(math.floor(ts.RainbowSpeed * 100 + 0.5), 2, 100),
        Rounding = 0, Suffix = "%",
        Callback = function(v) ts.RainbowSpeed = v / 100; RavineUI:_QueueThemeSave() end,
    })
    look:AddSlider("RavineUI_Transparency", {
        Text = "Window transparency", Min = 0, Max = 60,
        Default = math.clamp(math.floor(ts.Transparency * 100 + 0.5), 0, 60),
        Rounding = 0, Suffix = "%", Keywords = "opacity see through",
        Callback = function(v) self:SetTransparency(v / 100) end,
    })
    look:AddToggle("RavineUI_Animations", {
        Text = "Animations", Default = ts.Animations ~= false, Keywords = "motion transitions effects ripple",
        Callback = function(v) ts.Animations = v; RavineUI:_QueueThemeSave() end,
    })
    look:AddDropdown("RavineUI_Weather", {
        Text = "Weather", Values = { "None", "Snow", "Rain", "Ember", "Sakura", "Fireflies", "Matrix" },
        Default = "None",
        Callback = function(name)
            if name == "None" then self:SetBackdrop(false)
            else self:SetBackdrop(true); self:SetWeather(name) end
        end,
    })

    local cfg = tab:AddRightGroupbox("Config", "save")
    local nameBox = cfg:AddTextbox("RavineUI_ConfigName", { Text = "Config name", Placeholder = "default" })
    local list = cfg:AddDropdown("RavineUI_ConfigList", { Text = "Configs", Values = RavineUI:ListConfigs() })
    local function currentName()
        local n = nameBox.Get()
        if n == "" then n = list.Get() end
        return n
    end
    cfg:AddButton("Save config", {
        Icon = "save",
        Callback = function()
            local n = currentName()
            local ok, err = RavineUI:SaveConfig(n)
            RavineUI:Notify({ Title = ok and "Config saved" or "Save failed", Description = ok and n or tostring(err), Icon = ok and "circle-check" or "triangle-alert" })
            list.Refresh(RavineUI:ListConfigs())
        end,
    })
    cfg:AddButton("Load config", {
        Icon = "folder",
        Callback = function()
            local n = currentName()
            local ok, err = RavineUI:LoadConfig(n)
            RavineUI:Notify({ Title = ok and "Config loaded" or "Load failed", Description = ok and n or tostring(err), Icon = ok and "circle-check" or "triangle-alert" })
        end,
    })
    cfg:AddButton("Refresh list", {
        Icon = "refresh-cw",
        Callback = function() list.Refresh(RavineUI:ListConfigs()) end,
    })

    return tab
end

-- ============ TAB METHODS ============
function Tab:_SetActive(active)
    Tween(self._btn, 0.15, { BackgroundTransparency = 1 })
    TintIcon(self._icon, active and Theme.Text or Theme.SubText)
    if active and Anim() and self._icon.Ok then
        local ic = self._icon.Instance
        Tween(ic, 0.1, { Size = UDim2.fromOffset(25, 25) })
        task.delay(0.1, function()
            if ic.Parent then
                Tween(ic, 0.4, { Size = UDim2.fromOffset(20, 20) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            end
        end)
    end
end

function Tab:_PlayIntro()
    if not Anim() then return end
    local f = self.Frame
    f.Position = UDim2.fromOffset(0, 14)
    Tween(f, 0.4, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if self._onShow then task.spawn(self._onShow) end
    for i, box in ipairs(self.Groupboxes) do
        local outer = box.Outer
        if outer then
            local us = outer:FindFirstChild("PopScale") or Create("UIScale", { Name = "PopScale", Parent = outer })
            us.Scale = 0.93
            task.delay((i - 1) * 0.05, function()
                if us.Parent then
                    Tween(us, 0.45, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                end
            end)
        end
    end
end

function Tab:PlayIntro() self:_PlayIntro() end
function Tab:AddLeftGroupbox(name, icon) return self:_AddGroupbox(name, icon, self.Left) end
function Tab:AddRightGroupbox(name, icon) return self:_AddGroupbox(name, icon, self.Right) end

function Tab:_AddGroupbox(name, icon, column)
    local box = setmetatable({ Name = name, Tab = self, Column = column, _n = 0 }, Groupbox)
    local outer = Create("Frame", {
        Name = name .. "_Outer", BackgroundColor3 = Theme.Border, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = #self.Groupboxes + 1, Parent = column,
    })
    Corner(outer, 9)
    Create("UIPadding", { PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 1), Parent = outer })
    local frame = Create("Frame", {
        Name = name, BackgroundColor3 = Theme.Secondary, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = outer,
    })
    Corner(frame, 8)
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
    local titleFrame = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1, Parent = frame })
    local x = 12
    if icon then
        local ic = NewIcon(titleFrame, icon, 16, Theme.Accent, "")
        ic.Instance.Position = UDim2.new(0, 12, 0.5, -8)
        x = 34
    end
    Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, x, 0, 0), Size = UDim2.new(1, -x - 12, 1, 0),
        Font = Theme.FontBold, Text = name, TextColor3 = Theme.Text, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = titleFrame,
    })
    Create("Frame", { BackgroundColor3 = Theme.Border, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 2, Parent = frame })
    local container = Create("Frame", {
        Name = "Container", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = frame,
    })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = container })
    Create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = container })
    box.Frame = frame
    box.Outer = outer
    box.Container = container
    box.Scroll = container
    table.insert(self.Groupboxes, box)
    return box
end

-- ============ GROUPBOX ELEMENTS ============
local function Add(self, className, props)
    self._n = self._n + 1
    props.LayoutOrder = self._n
    props.Parent = self.Container
    return Create(className, props)
end

local function AddRow(self, height, clip)
    local row = Add(self, "Frame", {
        BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height or 34), ClipsDescendants = clip or false,
    })
    Corner(row, 6)
    Stroke(row, Theme.Border, 1)
    return row
end

local function RowLabel(row, text, rightInset)
    return Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -(12 + (rightInset or 12)), 0, 34), Font = Theme.Font,
        Text = text, TextColor3 = Theme.Text, TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
end

local function HitButton(row, height)
    return Create("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height or 34), Text = "", Parent = row })
end

local function RegisterSearch(self, kind, label, frame, obj, opts)
    local tab = self.Tab
    local win = tab and tab.Window
    if not (win and win._search) or opts.Searchable == false then return end
    local kw = opts.Keywords
    if type(kw) == "table" then kw = table.concat(kw, " ") end
    win._search.Add({
        Name = tostring(label), Type = kind, Tab = tab, Group = self.Name,
        Frame = frame, Column = self.Column, Obj = obj,
        Keywords = kw and tostring(kw) or "",
    })
end

local function MakeDisabler(target, radius, opts)
    local d = { Tip = opts.DisabledTooltip }
    local overlay = Create("TextButton", {
        Name = "DisabledOverlay", BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.35, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
        Text = "", AutoButtonColor = false, Visible = false, ZIndex = 20, Parent = target,
    })
    Corner(overlay, radius or 6)
    local lock = NewIcon(overlay, "lock", 14, Theme.SubText, "!")
    lock.Instance.AnchorPoint = Vector2.new(1, 0.5)
    lock.Instance.Position = UDim2.new(1, -12, 0.5, 0)
    lock.Instance.ZIndex = 21
    overlay.MouseEnter:Connect(function() if d.Tip then TipShow(d.Tip, overlay) end end)
    overlay.MouseLeave:Connect(function() TipHideFor(overlay) end)
    overlay.MouseButton1Click:Connect(function()
        if d.Tip and UserInputService.TouchEnabled then TipFlash(d.Tip, overlay) end
    end)
    d.Overlay = overlay
    d.Set = function(v)
        overlay.Visible = v
        if not v then TipHideFor(overlay) end
    end
    return d
end

local function AttachDisable(obj, target, radius, opts, onChange)
    local d = MakeDisabler(target, radius, opts)
    obj.Disabled = false
    obj.SetDisabled = function(a, b)
        local v = Arg(obj, a, b) and true or false
        obj.Disabled = v
        d.Set(v)
        if onChange then onChange(v) end
    end
    obj.SetDisabledTooltip = function(a, b) d.Tip = Arg(obj, a, b) end
    obj.IsDisabled = function() return obj.Disabled end
    if opts.Disabled then obj.SetDisabled(true) end
end

local function AttachTooltip(obj, target, opts)
    local text = opts.Tooltip
    local hooked = false
    local count, token = 0, 0
    local function enter()
        count = count + 1
        if count == 1 then
            token = token + 1
            local mine = token
            task.delay(0.4, function()
                if mine == token and count > 0 and text and not obj.Disabled then
                    TipShow(text, target)
                end
            end)
        end
    end
    local function leave()
        count = math.max(count - 1, 0)
        if count == 0 then token = token + 1; TipHideFor(target) end
    end
    local function hook(o) o.MouseEnter:Connect(enter); o.MouseLeave:Connect(leave) end
    local function ensure()
        if hooked then return end
        hooked = true
        hook(target)
        for _, c in ipairs(target:GetDescendants()) do
            if c:IsA("GuiButton") or c:IsA("TextBox") then hook(c) end
        end
    end
    obj.SetTooltip = function(a, b)
        text = Arg(obj, a, b)
        if text and not (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then ensure() end
    end
    if text then obj.SetTooltip(text) end
end

function Groupbox:AddDivider(thickness)
    local t = thickness or 2
    local holder = Add(self, "Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, t + 12) })
    local line = Create("Frame", {
        BackgroundColor3 = Theme.Divider, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0, t), Parent = holder,
    })
    Corner(line, t)
    return holder
end

function Groupbox:AddLabel(text)
    return Add(self, "TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.Font, Text = text, TextColor3 = Theme.Text, TextSize = 13,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    })
end

function Groupbox:AddButton(name, opts)
    if type(opts) == "function" then opts = { Callback = opts } end
    opts = opts or {}
    local callback = opts.Callback or function() end
    local btn = Add(self, "TextButton", {
        BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 34), Font = Theme.Font, Text = name,
        TextColor3 = Theme.Text, TextSize = 13, AutoButtonColor = false,
    })
    Corner(btn, 6)
    local strk = Stroke(btn, Theme.Border, 1)
    Ripple(btn)
    if opts.Icon then
        local ic = NewIcon(btn, opts.Icon, 16, Theme.Text, "")
        ic.Instance.Position = UDim2.new(0, 12, 0.5, -8)
    end
    btn.MouseEnter:Connect(function() Tween(btn, 0.15, { BackgroundColor3 = Theme.Accent }); Tween(strk, 0.15, { Color = Theme.Accent }) end)
    btn.MouseLeave:Connect(function() Tween(btn, 0.15, { BackgroundColor3 = Theme.Tertiary }); Tween(strk, 0.15, { Color = Theme.Border }) end)
    local obj = setmetatable({ Instance = btn, Container = btn, Type = "Button" }, {
        __index = function(_, k) return btn[k] end,
    })
    obj.SetText = function(a, b) btn.Text = tostring(Arg(obj, a, b)) end
    btn.MouseButton1Click:Connect(function()
        if obj.Disabled then return end
        task.spawn(callback)
        if RavineUI.IsMobile then
            task.delay(0.15, function()
                pcall(function()
                    Tween(btn, 0.15, { BackgroundColor3 = Theme.Tertiary })
                    Tween(strk, 0.15, { Color = Theme.Border })
                end)
            end)
        end
    end)
    AttachTooltip(obj, btn, opts)
    AttachDisable(obj, btn, 6, opts)
    RegisterSearch(self, "Button", name, btn, obj, opts)
    return obj
end

function Groupbox:AddToggle(id, opts)
    opts = opts or {}
    local callback = opts.Callback or function() end
    local state = opts.Default or false
    local obj, changed = NewOption("Toggle", id, state)
    local row = AddRow(self, 34)
    RowLabel(row, opts.Text or id, 60)
    local track = Create("Frame", {
        BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff, BorderSizePixel = 0,
        Position = UDim2.new(1, -46, 0.5, -10), Size = UDim2.fromOffset(36, 20), Parent = row,
    })
    Corner(track, 10)
    local thumb = Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0,
        Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        Size = UDim2.fromOffset(16, 16), Parent = track,
    })
    Corner(thumb, 8)
    local function thumbPos(on, w)
        if on then return UDim2.new(1, -(w + 2), 0.5, -8) end
        return UDim2.new(0, 2, 0.5, -8)
    end
    local function setState(v)
        state = v and true or false
        Tween(track, 0.2, { BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff })
        Tween(thumb, 0.32, { Position = thumbPos(state, 16), Size = UDim2.fromOffset(16, 16) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        changed(state)
        task.spawn(callback, state)
    end
    local toggleHit = HitButton(row, 34)
    local squished = false
    toggleHit.MouseButton1Down:Connect(function()
        if obj.Disabled or not Anim() then return end
        squished = true
        Tween(thumb, 0.1, { Size = UDim2.fromOffset(22, 16), Position = thumbPos(state, 22) })
    end)
    toggleHit.MouseLeave:Connect(function()
        if squished then
            squished = false
            Tween(thumb, 0.2, { Size = UDim2.fromOffset(16, 16), Position = thumbPos(state, 16) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end
    end)
    toggleHit.MouseButton1Click:Connect(function()
        squished = false
        if obj.Disabled then return end
        setState(not state)
    end)
    obj.Container = row
    obj.Set = function(a, b)
        if obj.Disabled then return end
        setState(Arg(obj, a, b))
    end
    obj.Get = function() return state end
    function obj:SetValue(v) obj.Set(v) end
    AttachTooltip(obj, row, opts)
    AttachDisable(obj, row, 6, opts)
    RegisterSearch(self, "Toggle", opts.Text or id, row, obj, opts)
    return obj
end

function Groupbox:AddSlider(id, opts)
    opts = opts or {}
    local min = opts.Min or 0
    local max = opts.Max or 100
    local callback = opts.Callback or function() end
    local suffix = opts.Suffix or ""
    local rounding = opts.Rounding or 0
    local range = math.max(max - min, 1e-9)
    local value = math.clamp(opts.Default or min, min, max)
    local obj, changed = NewOption("Slider", id, value)
    local row = AddRow(self, 46)
    Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 4),
        Size = UDim2.new(1, -80, 0, 18), Font = Theme.Font, Text = opts.Text or id,
        TextColor3 = Theme.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local valueLabel = Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(1, -62, 0, 4),
        Size = UDim2.new(0, 50, 0, 18), Font = Theme.FontBold, Text = tostring(value) .. suffix,
        TextColor3 = Theme.Accent, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
    })
    local barBg = Create("Frame", {
        BackgroundColor3 = Theme.ToggleOff, BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 0, 30), Size = UDim2.new(1, -24, 0, 6), Parent = row,
    })
    Corner(barBg, 3)
    local fill = Create("Frame", { BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Size = UDim2.new((value - min) / range, 0, 1, 0), Parent = barBg })
    Corner(fill, 3)
    local thumb = Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new((value - min) / range, 0, 0.5, 0),
        Size = UDim2.fromOffset(12, 12), ZIndex = 2, Parent = barBg,
    })
    Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = thumb })
    local hit = Create("TextButton", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 24), Text = "", Parent = row })
    local function render(v, time)
        local rel = (v - min) / range
        Tween(fill, time, { Size = UDim2.new(rel, 0, 1, 0) })
        Tween(thumb, time, { Position = UDim2.new(rel, 0, 0.5, 0) })
        valueLabel.Text = tostring(v) .. suffix
    end
    local function setValue(v, time)
        value = math.clamp(Round(v, rounding), min, max)
        render(value, time or 0.05)
        changed(value)
        task.spawn(callback, value)
    end
    TrackDrag(hit, self.Column, function(pos)
        if obj.Disabled then return end
        local rel = math.clamp((pos.X - barBg.AbsolutePosition.X) / math.max(barBg.AbsoluteSize.X, 1), 0, 1)
        setValue(min + range * rel)
    end, function()
        if Anim() and not obj.Disabled then
            Tween(thumb, 0.25, { Size = UDim2.fromOffset(17, 17) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end
    end, function()
        Tween(thumb, 0.3, { Size = UDim2.fromOffset(12, 12) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)
    obj.Container = row
    obj.Set = function(a, b)
        if obj.Disabled then return end
        setValue(Arg(obj, a, b), 0.1)
    end
    obj.Get = function() return value end
    function obj:SetValue(v) obj.Set(v) end
    AttachTooltip(obj, row, opts)
    AttachDisable(obj, row, 6, opts)
    RegisterSearch(self, "Slider", opts.Text or id, row, obj, opts)
    return obj
end

function Groupbox:AddDropdown(id, opts)
    opts = opts or {}
    local values = opts.Values or {}
    local callback = opts.Callback or function() end
    local multi = opts.Multi == true
    local current = nil
    if not multi then current = opts.Default or (values[1] or "") end
    local selected = {}
    local open = false
    local visibleCount = #values

    local function inValues(key)
        for _, v in ipairs(values) do if tostring(v) == key then return true end end
        return false
    end
    local function toMap(v)
        local map = {}
        local function add(x)
            local k = tostring(x)
            if inValues(k) then map[k] = true end
        end
        if type(v) == "table" then
            for k, val in pairs(v) do
                if type(k) == "number" then add(val)
                elseif val then add(k) end
            end
        elseif v ~= nil and v ~= "" then add(v) end
        return map
    end
    local function snapshot()
        local m = {}
        for k in pairs(selected) do m[k] = true end
        return m
    end
    local function count() local n = 0; for _ in pairs(selected) do n = n + 1 end; return n end
    local function summary()
        local n = count()
        if n == 0 then return "None" end
        if n == 1 then for k in pairs(selected) do return k end end
        return n .. " selected"
    end
    if multi then selected = toMap(opts.Default) end
    local obj, changed = NewOption("Dropdown", id, multi and snapshot() or current)
    local row = AddRow(self, 34, true)
    RowLabel(row, opts.Text or id, 130)
    local currentLabel = Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(1, -130, 0, 0),
        Size = UDim2.new(0, 104, 0, 34), Font = Theme.Font,
        Text = multi and summary() or tostring(current), TextColor3 = Theme.Accent,
        TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
    })
    local arrow = NewIcon(row, "chevron-down", 14, Theme.SubText, "v")
    arrow.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.Instance.Position = UDim2.new(1, -15, 0, 17)
    local hit = HitButton(row, 34)

    local function searchOn()
        if opts.Search ~= nil then return opts.Search == true end
        return #values >= 8
    end
    local function listTop() return searchOn() and 68 or 38 end
    local function listHeight()
        if visibleCount == 0 then return 26 end
        return math.min(visibleCount * 26, 130)
    end
    local function fullHeight() return listTop() + listHeight() + 6 end

    local searchFrame = Create("Frame", {
        BackgroundColor3 = Theme.Secondary, BorderSizePixel = 0,
        Position = UDim2.new(0, 6, 0, 38), Size = UDim2.new(1, -12, 0, 26),
        Visible = false, Parent = row,
    })
    Corner(searchFrame, 5)
    local searchStroke = Stroke(searchFrame, Theme.Border, 1)
    local searchIcon = NewIcon(searchFrame, "search", 13, Theme.SubText, "?")
    searchIcon.Instance.AnchorPoint = Vector2.new(0, 0.5)
    searchIcon.Instance.Position = UDim2.new(0, 8, 0.5, 0)
    local searchBox = Create("TextBox", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 28, 0, 0),
        Size = UDim2.new(1, -52, 1, 0), Font = Theme.Font, Text = "",
        PlaceholderText = "Search...", PlaceholderColor3 = Theme.SubText,
        TextColor3 = Theme.Text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false, Parent = searchFrame,
    })
    local clearBtn = Create("TextButton", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(20, 20),
        Text = "", AutoButtonColor = false, Visible = false, Parent = searchFrame,
    })
    local clearIcon = NewIcon(clearBtn, "x", 12, Theme.SubText, "x")
    clearIcon.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    clearIcon.Instance.Position = UDim2.fromScale(0.5, 0.5)
    clearBtn.MouseEnter:Connect(function() TintIcon(clearIcon, Theme.Text) end)
    clearBtn.MouseLeave:Connect(function() TintIcon(clearIcon, Theme.SubText) end)
    local list = Create("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.new(0, 6, 0, 38), Size = UDim2.new(1, -12, 0, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.Border,
        Visible = false, Parent = row,
    })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = list })
    local emptyLabel = Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 6, 0, 38),
        Size = UDim2.new(1, -12, 0, 26), Font = Theme.Font, Text = "No results",
        TextColor3 = Theme.SubText, TextSize = 12, Visible = false, Parent = row,
    })
    local entries = {}

    local function relayout()
        if not open then return end
        list.Position = UDim2.new(0, 6, 0, listTop())
        emptyLabel.Position = UDim2.new(0, 6, 0, listTop())
        emptyLabel.Visible = visibleCount == 0
        list.Visible = visibleCount > 0
        Tween(row, 0.12, { Size = UDim2.new(1, 0, 0, fullHeight()) })
        Tween(list, 0.12, { Size = UDim2.new(1, -12, 0, visibleCount > 0 and listHeight() or 0) })
    end
    local function applyFilter()
        local q = (searchBox.Text:lower():gsub("^%s+", ""):gsub("%s+$", ""))
        visibleCount = 0
        for _, e in ipairs(entries) do
            local show = q == "" or tostring(e.Value):lower():find(q, 1, true) ~= nil
            e.Button.Visible = show
            if show then visibleCount = visibleCount + 1 end
        end
        list.CanvasPosition = Vector2.new(0, 0)
        relayout()
    end
    local function setOpen(v)
        open = v
        Tween(arrow.Instance, 0.35, { Rotation = v and 180 or 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        if v then
            if Anim() then
                for i, e in ipairs(entries) do
                    if i > 12 then break end
                    e.Button.TextTransparency = 1
                    task.delay(0.03 * i, function()
                        if e.Button.Parent then Tween(e.Button, 0.22, { TextTransparency = 0 }) end
                    end)
                end
            end
            searchFrame.Visible = searchOn()
            list.Position = UDim2.new(0, 6, 0, listTop())
            emptyLabel.Position = UDim2.new(0, 6, 0, listTop())
            emptyLabel.Visible = visibleCount == 0
            list.Visible = visibleCount > 0
            Tween(row, 0.18, { Size = UDim2.new(1, 0, 0, fullHeight()) })
            Tween(list, 0.18, { Size = UDim2.new(1, -12, 0, visibleCount > 0 and listHeight() or 0) })
            if searchOn() and not RavineUI.IsMobile then
                task.delay(0.05, function()
                    if open then searchBox:CaptureFocus() end
                end)
            end
        else
            pcall(function() searchBox:ReleaseFocus() end)
            Tween(row, 0.18, { Size = UDim2.new(1, 0, 0, 34) })
            Tween(list, 0.18, { Size = UDim2.new(1, -12, 0, 0) })
            emptyLabel.Visible = false
            task.delay(0.18, function()
                if not open then
                    list.Visible = false
                    searchFrame.Visible = false
                    if searchBox.Text ~= "" then searchBox.Text = "" end
                end
            end)
        end
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        clearBtn.Visible = searchBox.Text ~= ""
        applyFilter()
    end)
    searchBox.Focused:Connect(function() Tween(searchStroke, 0.15, { Color = Theme.Accent }) end)
    searchBox.FocusLost:Connect(function(enterPressed)
        Tween(searchStroke, 0.15, { Color = Theme.Border })
        if enterPressed and not multi then
            for _, e in ipairs(entries) do
                if e.Button.Visible then
                    e.Button.MouseButton1Click:Fire()
                    break
                end
            end
        end
    end)
    clearBtn.MouseButton1Click:Connect(function()
        searchBox.Text = ""
        if not RavineUI.IsMobile then searchBox:CaptureFocus() end
    end)
    local function isSelected(val)
        if multi then return selected[tostring(val)] == true end
        return tostring(val) == tostring(current)
    end
    local function restTransparency(val)
        return (multi and isSelected(val)) and 0.85 or 1
    end
    local function styleEntry(e)
        local sel = isSelected(e.Value)
        e.Button.TextColor3 = sel and Theme.Accent or Theme.Text
        e.Check.Instance.Visible = multi and sel
        Tween(e.Button, 0.1, { BackgroundTransparency = restTransparency(e.Value) })
    end
    local function choose(val)
        current = val
        currentLabel.Text = tostring(val)
        for _, e in ipairs(entries) do styleEntry(e) end
        changed(val)
        task.spawn(callback, val)
    end
    local function applyMulti()
        currentLabel.Text = summary()
        for _, e in ipairs(entries) do styleEntry(e) end
        local snap = snapshot()
        changed(snap)
        task.spawn(callback, snap)
    end
    local function toggleMulti(val)
        local k = tostring(val)
        if selected[k] then selected[k] = nil else selected[k] = true end
        applyMulti()
    end
    local function refresh()
        for _, e in ipairs(entries) do e.Button:Destroy() end
        entries = {}
        for i, val in ipairs(values) do
            local option = Create("TextButton", {
                BackgroundColor3 = Theme.Accent, BackgroundTransparency = restTransparency(val),
                BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 24), LayoutOrder = i,
                Font = Theme.Font, Text = tostring(val),
                TextColor3 = isSelected(val) and Theme.Accent or Theme.Text,
                TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false, Parent = list,
            })
            Create("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = option })
            Corner(option, 4)
            local check = NewIcon(option, "check", 14, Theme.Accent, "*")
            check.Instance.Position = UDim2.new(1, -22, 0.5, -7)
            check.Instance.Visible = multi and isSelected(val)
            table.insert(entries, { Button = option, Check = check, Value = val })
            option.MouseEnter:Connect(function() Tween(option, 0.1, { BackgroundTransparency = 0.7 }) end)
            option.MouseLeave:Connect(function() Tween(option, 0.1, { BackgroundTransparency = restTransparency(val) }) end)
            option.MouseButton1Click:Connect(function()
                if multi then toggleMulti(val)
                else choose(val); setOpen(false) end
            end)
        end
        applyFilter()
    end
    refresh()
    hit.MouseButton1Click:Connect(function()
        if obj.Disabled then return end
        setOpen(not open)
    end)
    obj.Container = row
    obj.Multi = multi
    obj.Set = function(a, b)
        if obj.Disabled then return end
        local v = Arg(obj, a, b)
        if multi then selected = toMap(v); applyMulti()
        else choose(v) end
    end
    obj.Get = function()
        if multi then return snapshot() end
        return current
    end
    obj.GetSelected = function()
        local out = {}
        if multi then
            for _, v in ipairs(values) do
                if selected[tostring(v)] then table.insert(out, v) end
            end
        elseif current ~= nil and current ~= "" then
            table.insert(out, current)
        end
        return out
    end
    obj.SelectAll = function()
        if multi and not obj.Disabled then selected = toMap(values); applyMulti() end
    end
    obj.Clear = function()
        if multi and not obj.Disabled then selected = {}; applyMulti() end
    end
    obj.Refresh = function(a, b)
        local newValues = Arg(obj, a, b)
        if type(newValues) ~= "table" then return end
        values = newValues
        local before = count()
        if multi then selected = toMap(selected) end
        refresh()
        if multi then
            currentLabel.Text = summary()
            if count() ~= before then applyMulti() end
        end
        if open then
            searchFrame.Visible = searchOn()
            relayout()
        end
    end
    function obj:SetValue(v) obj.Set(v) end
    AttachTooltip(obj, row, opts)
    AttachDisable(obj, row, 6, opts, function(v)
        if v and open then setOpen(false) end
    end)
    RegisterSearch(self, "Dropdown", opts.Text or id, row, obj, opts)
    return obj
end

function Groupbox:AddTextbox(id, opts)
    opts = opts or {}
    local callback = opts.Callback or function() end
    local obj, changed = NewOption("Textbox", id, opts.Default or "")
    local row = AddRow(self, 42)
    Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 5),
        Size = UDim2.new(1, -24, 0, 14), Font = Theme.Font, Text = opts.Text or id,
        TextColor3 = Theme.SubText, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local box = Create("TextBox", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 21),
        Size = UDim2.new(1, -24, 0, 16), Font = Theme.Font, Text = opts.Default or "",
        PlaceholderText = opts.Placeholder or "", TextColor3 = Theme.Text,
        PlaceholderColor3 = Theme.SubText, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = row,
    })
    local rowStroke = row:FindFirstChildOfClass("UIStroke")
    box.Focused:Connect(function() if rowStroke then Tween(rowStroke, 0.2, { Color = Theme.Accent }) end end)
    box.FocusLost:Connect(function()
        if rowStroke then Tween(rowStroke, 0.3, { Color = Theme.Border }) end
        changed(box.Text)
        task.spawn(callback, box.Text)
    end)
    obj.Instance = box
    obj.Container = row
    obj.Set = function(a, b)
        if obj.Disabled then return end
        local t = Arg(obj, a, b)
        box.Text = tostring(t)
        changed(box.Text)
        task.spawn(callback, box.Text)
    end
    obj.Get = function() return box.Text end
    function obj:SetValue(t) obj.Set(t) end
    AttachTooltip(obj, row, opts)
    AttachDisable(obj, row, 6, opts, function(v)
        box.TextEditable = not v
        if v then
            pcall(function()
                if box:IsFocused() then box:ReleaseFocus() end
            end)
        end
    end)
    RegisterSearch(self, "Textbox", opts.Text or id, row, obj, opts)
    return obj
end

function Groupbox:AddColorPicker(id, opts)
    opts = opts or {}
    local callback = opts.Callback or function() end
    local color = opts.Default or Color3.fromRGB(255, 255, 255)
    local h, s, v = Color3.toHSV(color)
    local open = false
    local PICK_H = 100
    local obj, changed = NewOption("ColorPicker", id, color)
    local row = AddRow(self, 34, true)
    RowLabel(row, opts.Text or id, 60)
    local swatch = Create("Frame", {
        BackgroundColor3 = color, BorderSizePixel = 0,
        Position = UDim2.new(1, -40, 0, 7), Size = UDim2.fromOffset(28, 20), Parent = row,
    }, true)
    Corner(swatch, 4)
    Stroke(swatch, Theme.Border, 1)
    local hit = HitButton(row, 34)
    local area = Create("Frame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 40),
        Size = UDim2.new(1, -20, 0, PICK_H), Parent = row,
    })
    local sv = Create("Frame", {
        BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0,
        Size = UDim2.new(1, -24, 1, 0), Parent = area,
    }, true)
    Corner(sv, 4)
    local white = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = sv,
    })
    Corner(white, 4)
    Create("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
    local black = Create("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = sv,
    })
    Corner(black, 4)
    Create("UIGradient", { Transparency = NumberSequence.new(1, 0), Rotation = 90, Parent = black })
    local svCursor = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), ZIndex = 3, Parent = sv,
    })
    Corner(svCursor, 4)
    Stroke(svCursor, Color3.new(0, 0, 0), 1)
    local hueBar = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 16, 1, 0), Parent = area,
    })
    Corner(hueBar, 4)
    local hueKeys = {}
    for i = 0, 6 do
        table.insert(hueKeys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(math.min(i / 6, 0.999), 1, 1)))
    end
    Create("UIGradient", { Color = ColorSequence.new(hueKeys), Rotation = 90, Parent = hueBar })
    local hueCursor = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 4, 0, 3), ZIndex = 3, Parent = hueBar,
    })
    Stroke(hueCursor, Color3.new(0, 0, 0), 1)
    local function render()
        color = Color3.fromHSV(h, s, v)
        swatch.BackgroundColor3 = color
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svCursor.Position = UDim2.fromScale(s, 1 - v)
        hueCursor.Position = UDim2.fromScale(0.5, h)
    end
    local function commit()
        render()
        changed(color)
        task.spawn(callback, color)
    end
    render()
    TrackDrag(sv, self.Column, function(pos)
        s = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
        v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
        commit()
    end)
    TrackDrag(hueBar, self.Column, function(pos)
        h = math.clamp((pos.Y - hueBar.AbsolutePosition.Y) / math.max(hueBar.AbsoluteSize.Y, 1), 0, 1)
        commit()
    end)
    hit.MouseButton1Click:Connect(function()
        if obj.Disabled then return end
        open = not open
        Tween(row, 0.35, { Size = UDim2.new(1, 0, 0, open and (40 + PICK_H + 10) or 34) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    end)
    obj.Container = row
    obj.Set = function(a, b)
        if obj.Disabled then return end
        local c = Arg(obj, a, b)
        h, s, v = Color3.toHSV(c)
        commit()
    end
    obj.Get = function() return color end
    function obj:SetValue(c) obj.Set(c) end
    AttachTooltip(obj, row, opts)
    AttachDisable(obj, row, 6, opts, function(v)
        if v and open then open = false; Tween(row, 0.18, { Size = UDim2.new(1, 0, 0, 34) }) end
    end)
    RegisterSearch(self, "ColorPicker", opts.Text or id, row, obj, opts)
    return obj
end

function Groupbox:AddKeyPicker(id, opts)
    opts = opts or {}
    local callback = opts.Callback or function() end
    local current = opts.Default or "F"
    local listening = false
    local obj, changed = NewOption("KeyPicker", id, current)
    local row = AddRow(self, 34)
    RowLabel(row, opts.Text or id, 82)
    local keyLabel = Create("TextButton", {
        BackgroundColor3 = Theme.Secondary, BorderSizePixel = 0,
        Position = UDim2.new(1, -70, 0.5, -10), Size = UDim2.fromOffset(58, 20),
        Font = Theme.FontBold, Text = current, TextColor3 = Theme.Text, TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = false, Parent = row,
    })
    Corner(keyLabel, 4)
    local keyStroke = Stroke(keyLabel, Theme.Border, 1)
    keyLabel.MouseButton1Click:Connect(function()
        if obj.Disabled then return end
        listening = true
        keyLabel.Text = "..."
        Tween(keyStroke, 0.2, { Color = Theme.Accent })
    end)
    Connect(UserInputService.InputBegan, function(input, gpe)
        if gpe then return end
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                listening = false
                if input.KeyCode ~= Enum.KeyCode.Escape then
                    current = input.KeyCode.Name
                    changed(current)
                end
                keyLabel.Text = current
                Tween(keyStroke, 0.3, { Color = Theme.Border })
            end
        elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == current
            and not obj.Disabled then
            task.spawn(callback)
        end
    end)
    obj.Container = row
    obj.Set = function(a, b)
        if obj.Disabled then return end
        local k = Arg(obj, a, b)
        current = k
        keyLabel.Text = k
        changed(k)
    end
    obj.Get = function() return current end
    function obj:SetValue(k) obj.Set(k) end
    AttachTooltip(obj, row, opts)
    AttachDisable(obj, row, 6, opts, function(v)
        if v then listening = false; keyLabel.Text = current end
    end)
    RegisterSearch(self, "KeyPicker", opts.Text or id, row, obj, opts)
    return obj
end

-- ============ INIT ============
return RavineUI
