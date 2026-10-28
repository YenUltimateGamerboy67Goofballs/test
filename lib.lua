--[[
    RavineUI "Aurora" - komplett anderer Look, GLEICHE API wie RavineUI
    Version 3.0

    So testest du es: in deinem Script nur die loadstring-URL tauschen, sonst nichts aendern.

    Was anders aussieht:
        - Tabs oben als Pillen (aktiver Tab klappt mit Namen auf, die anderen zeigen nur das Icon)
        - Animierter Farbverlauf-Rand um das ganze Fenster (in Appearance abschaltbar)
        - Dropdowns und Farbwaehler oeffnen als schwebendes Popover (nichts schiebt mehr die Zeilen auseinander)
        - Toggles als leuchtende Schalter, Slider mit Farbverlauf, Buttons mit Ripple-Effekt
        - Benachrichtigungen mit ablaufendem Zeitbalken (Klick zum Wegwischen)
        - Neues Home-Dashboard: Hero-Karte, FPS/Ping-Graph, Quick-Actions (Rejoin/Hop/Lowest/Job ID)

    Alles aus der alten Library bleibt: Theme-System (SetTheme/SetAccent/SetRainbow/AddThemePreset), Suchleiste
    (Lupe oder Strg+F), Config (SaveConfig/LoadConfig/ListConfigs), Disabled/Tooltip, Keywords/Searchable,
    Window:AddAppearanceBox(tab), Window:AddSettingsTab(), ShowChangelog, Mobile-Auto-Scale.
]]

local RavineUI = {
    Version = "3.0.0",
    Build = "aurora-1",
    Toggles = {},
    Options = {},
    CustomIcons = {},
}
RavineUI.__index = RavineUI

-- ============ SERVICES ============
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer

-- Touch-Geraet ohne Tastatur = Mobile (kann in CreateWindow mit Mobile = true/false ueberschrieben werden)
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

local HEADER_H = 52
local TABBAR_H = 46
local TOP_H = HEADER_H + TABBAR_H

-- ============ THEME ============
local Theme = {
    Background = Color3.fromRGB(12, 12, 17),
    Secondary = Color3.fromRGB(19, 19, 27),
    Tertiary = Color3.fromRGB(28, 28, 38),
    Card = Color3.fromRGB(9, 9, 13),
    Border = Color3.fromRGB(44, 44, 58),
    BorderLight = Color3.fromRGB(62, 62, 80),
    Divider = Color3.fromRGB(70, 70, 90),
    Text = Color3.fromRGB(238, 238, 245),
    SubText = Color3.fromRGB(144, 144, 162),
    Accent = Color3.fromRGB(200, 30, 40),
    AccentDark = Color3.fromRGB(140, 20, 28),
    ToggleOn = Color3.fromRGB(200, 30, 40),
    ToggleOff = Color3.fromRGB(58, 58, 74),
    Success = Color3.fromRGB(46, 204, 113),
    Warning = Color3.fromRGB(236, 190, 60),
    Danger = Color3.fromRGB(231, 76, 60),
    Font = Enum.Font.GothamMedium,
    FontBold = Enum.Font.GothamBold,
    TextSize = 13,
    CornerRadius = 8,
}
RavineUI.Theme = Theme

RavineUI.ThemeState = {
    Preset = "Crimson",
    Accent = Theme.Accent,
    Rainbow = false,
    RainbowSpeed = 0.15,
    Transparency = 0.04,
    AnimBorder = true,
}

-- Elemente, deren Farbe beim Erstellen einer Theme-Farbe entspricht, werden (schwach) vermerkt und beim
-- Theme-Wechsel live umgefaerbt. Farbverlaeufe haben eigene Eintraege (GradBinds).
local ThemeBinds = setmetatable({}, { __mode = "k" })
local GradBinds = setmetatable({}, { __mode = "k" })
local BorderGrads = setmetatable({}, { __mode = "k" })
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
    if typeof(value) ~= "Color3" then
        return
    end
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

-- noTheme = true: Farben dieses Elements werden NIE vom Theme umgefaerbt
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
    if parent then
        inst.Parent = parent
    end
    return inst
end

local function Corner(inst, radius)
    return Create("UICorner", {
        CornerRadius = UDim.new(0, radius or Theme.CornerRadius),
        Parent = inst,
    })
end

local function Stroke(inst, color, thickness, transparency)
    return Create("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
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

local function Lighten(c, a)
    return c:Lerp(Color3.new(1, 1, 1), a)
end

local function AccentSeq()
    local a = Theme.Accent
    return ColorSequence.new(a, Lighten(a, 0.35))
end

local function BorderSeq()
    local a = Theme.Accent
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, a),
        ColorSequenceKeypoint.new(0.5, Lighten(a, 0.5)),
        ColorSequenceKeypoint.new(1, a),
    })
end

-- Farbverlauf in der Akzentfarbe (faerbt sich bei Theme-Wechsel mit um). Elternobjekt sollte weiss sein.
local function AccentGradient(parent, rotation)
    local g = Create("UIGradient", {
        Color = AccentSeq(),
        Rotation = rotation or 0,
        Parent = parent,
    })
    GradBinds[g] = AccentSeq
    return g
end

local function BorderGradient(stroke)
    local g = Create("UIGradient", {
        Color = BorderSeq(),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(0.5, 0.8),
            NumberSequenceKeypoint.new(1, 0.1),
        }),
        Parent = stroke,
    })
    GradBinds[g] = BorderSeq
    BorderGrads[g] = true
    return g
end

-- animierter Rand: ein einziger Heartbeat dreht alle Rand-Verlaeufe
Connect(RunService.Heartbeat, function()
    if not RavineUI.ThemeState.AnimBorder then
        return
    end
    local rot = (os.clock() * 50) % 360
    for g in pairs(BorderGrads) do
        g.Rotation = rot
    end
end)

local function Round(v, decimals)
    local m = 10 ^ (decimals or 0)
    return math.floor(v * m + 0.5) / m
end

-- Erlaubt sowohl obj.Set(x) als auch obj:Set(x)
local function Arg(obj, a, b)
    if a == obj then
        return b
    end
    return a
end

local function FormatSession(s)
    s = math.floor(s)
    if s >= 3600 then
        return string.format("%dh %dm", s // 3600, (s % 3600) // 60)
    end
    if s >= 60 then
        return string.format("%dm %ds", s // 60, s % 60)
    end
    return s .. "s"
end

local function Plural(n, word)
    if n == 0 then
        return "no " .. word .. "s"
    end
    return n .. " " .. word .. (n == 1 and "" or "s")
end

local function Copy(text)
    local fn = setclipboard or toclipboard or set_clipboard
    if fn then
        return pcall(fn, text)
    end
    return false
end

local KeyShort = {
    RightControl = "RCtrl", LeftControl = "LCtrl", RightShift = "RShift", LeftShift = "LShift",
    RightAlt = "RAlt", LeftAlt = "LAlt", Insert = "Ins", Delete = "Del", Return = "Enter",
    Backspace = "Bksp", PageUp = "PgUp", PageDown = "PgDn", Escape = "Esc",
}
local function ShortKey(name)
    return KeyShort[name] or name
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
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
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

-- Eingabe-Koordinaten und AbsolutePosition koennen um die GuiInset versetzt sein: einmal beim Anfassen kalibrieren
local function CalibrateY(input, gui)
    local ap, asz = gui.AbsolutePosition, gui.AbsoluteSize
    local py = input.Position.Y
    if py >= ap.Y - 3 and py <= ap.Y + asz.Y + 3 then
        return 0
    end
    local inset = GuiService:GetGuiInset().Y
    local alt = py + inset
    if alt >= ap.Y - 3 and alt <= ap.Y + asz.Y + 3 then
        return inset
    end
    return 0
end

local function TrackDrag(hit, column, onMove)
    local dragging = false
    local offY = 0
    local function adj(pos)
        return Vector2.new(pos.X, pos.Y + offY)
    end
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            offY = CalibrateY(input, hit)
            if column then
                column.ScrollingEnabled = false
            end
            onMove(adj(input.Position))
        end
    end)
    Connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            onMove(adj(input.Position))
        end
    end)
    Connect(UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            if column then
                column.ScrollingEnabled = true
            end
        end
    end)
end

-- Ripple-Effekt (Elternobjekt braucht ClipsDescendants = true)
local function Ripple(btn, xPos)
    pcall(function()
        local s = math.max(RavineUI._uiScale or 1, 0.01)
        local w, h = btn.AbsoluteSize.X / s, btn.AbsoluteSize.Y / s
        local x = w / 2
        if xPos then
            x = math.clamp((xPos - btn.AbsolutePosition.X) / s, 0, w)
        end
        local r = Create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.8,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(x, h / 2),
            Size = UDim2.fromOffset(0, 0),
            Parent = btn,
        }, true)
        Corner(r, 999)
        local d = math.max(w, h) * 2.6
        Tween(r, 0.45, { Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1 })
        task.delay(0.5, function()
            r:Destroy()
        end)
    end)
end

-- ============ LUCIDE ICONS ============
local IconModule
do
    local ok, mod = pcall(function()
        return loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/mstudio45/lucide-roblox-direct/refs/heads/main/source.lua"
        ))()
    end)
    if ok and type(mod) == "table" then
        IconModule = mod
    end
end

local IconAliases = { home = "house", gear = "settings", close = "x" }

function RavineUI:SetIconModule(mod)
    IconModule = mod
end

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
    if t == "table" then
        return icon.Url and icon or nil
    end
    if t == "number" then
        return { Url = "rbxassetid://" .. icon, ImageRectOffset = Vector2.new(0, 0), ImageRectSize = Vector2.new(0, 0) }
    end
    if t ~= "string" or icon == "" then
        return nil
    end
    if self.CustomIcons[icon] then
        return self.CustomIcons[icon]
    end
    if icon:sub(1, 13) == "rbxassetid://" or icon:sub(1, 4) == "http" then
        return { Url = icon, ImageRectOffset = Vector2.new(0, 0), ImageRectSize = Vector2.new(0, 0) }
    end
    if tonumber(icon) then
        return self:GetIcon(tonumber(icon))
    end
    local name = (icon:gsub("^lucide[-:]", ""))
    name = IconAliases[name] or name
    if IconModule and IconModule.GetAsset then
        local ok, data = pcall(IconModule.GetAsset, name)
        if ok and data then
            return data
        end
    end
    return nil
end

local function SetIcon(img, icon)
    local data = RavineUI:GetIcon(icon)
    if not data then
        return false
    end
    img.Image = data.Url
    img.ImageRectOffset = data.ImageRectOffset or Vector2.new(0, 0)
    img.ImageRectSize = data.ImageRectSize or Vector2.new(0, 0)
    return true
end

local function NewIcon(parent, icon, px, color, fallback)
    local img = Create("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(px, px),
        ImageColor3 = color,
        ScaleType = Enum.ScaleType.Fit,
        Parent = parent,
    })
    if SetIcon(img, icon) then
        return { Instance = img, Prop = "ImageColor3", Ok = true }
    end
    img:Destroy()
    local lbl = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(px, px),
        Font = Theme.FontBold,
        Text = fallback or "?",
        TextColor3 = color,
        TextSize = math.floor(px * 0.85),
        Parent = parent,
    })
    return { Instance = lbl, Prop = "TextColor3", Ok = false }
end

local function TintIcon(ic, color, time)
    Tween(ic.Instance, time or 0.15, { [ic.Prop] = color })
end

local function IsCustomImage(icon)
    local t = type(icon)
    if t == "number" then
        return true
    end
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
        for _, fn in ipairs(obj._changed) do
            task.spawn(fn, v)
        end
    end

    local registry = (kind == "Toggle") and RavineUI.Toggles or RavineUI.Options
    registry[id] = obj
    return obj, changed
end

-- ============ GUI CONTAINER ============
local function GetGuiParent()
    local ok, hui = pcall(function()
        return gethui and gethui()
    end)
    if ok and hui then
        return hui
    end
    return CoreGui
end

local function EnsureGui()
    if RavineUI.Gui and RavineUI.Gui.Parent then
        return RavineUI.Gui
    end
    RavineUI.Gui = Create("ScreenGui", {
        Name = "RavineUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
        Parent = GetGuiParent(),
    })
    return RavineUI.Gui
end

-- ============ TOOLTIP ============
local Tip = { Frame = nil, Label = nil, Conn = nil, Token = 0, Bounds = nil }

local function TipEnsure()
    if Tip.Frame and Tip.Frame.Parent then
        return Tip.Frame
    end
    local f = Create("Frame", {
        Name = "Tooltip",
        BackgroundColor3 = Theme.Tertiary,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.fromOffset(0, 0),
        Visible = false,
        ZIndex = 1000,
        Parent = EnsureGui(),
    })
    Corner(f, 8)
    Stroke(f, Theme.BorderLight, 1)
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7),
        Parent = f,
    })
    local label = Create("TextLabel", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.fromOffset(0, 0),
        Font = Theme.Font,
        Text = "",
        TextColor3 = Theme.Text,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 1001,
        Parent = f,
    })
    Create("UISizeConstraint", { MaxSize = Vector2.new(260, 1000), Parent = label })
    Tip.Frame, Tip.Label = f, label
    return f
end

local function TipHide()
    Tip.Token = Tip.Token + 1
    Tip.Bounds = nil
    if Tip.Conn then
        Tip.Conn:Disconnect()
        Tip.Conn = nil
    end
    if Tip.Frame then
        Tip.Frame.Visible = false
    end
end

local function TipHideFor(bounds)
    if Tip.Bounds == bounds then
        TipHide()
    end
end

local function TipPlace(tx, ty, flipY)
    local f = Tip.Frame
    if not f then
        return
    end
    local vp = (RavineUI.Gui and RavineUI.Gui.AbsoluteSize) or Vector2.new(1920, 1080)
    local sz = f.AbsoluteSize
    local px = math.clamp(tx, 4, math.max(vp.X - sz.X - 4, 4))
    local py = ty
    if py + sz.Y > vp.Y - 4 then
        py = flipY - sz.Y
    end
    f.Position = UDim2.fromOffset(px, math.max(py, 4))
end

local function TipShow(text, bounds)
    TipHide()
    if not text or text == "" then
        return
    end
    local f = TipEnsure()
    Tip.Label.Text = text
    Tip.Bounds = bounds
    f.Visible = true
    local function update()
        if bounds and not bounds.Parent then
            TipHide()
            return
        end
        local m = UserInputService:GetMouseLocation()
        if bounds then
            local p, sz = bounds.AbsolutePosition, bounds.AbsoluteSize
            if m.X < p.X or m.Y < p.Y or m.X > p.X + sz.X or m.Y > p.Y + sz.Y then
                TipHide()
                return
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
    if not text or text == "" then
        return
    end
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
        if Tip.Token == token then
            TipHide()
        end
    end)
end

function RavineUI:HideTooltip()
    TipHide()
end

-- ============ NOTIFICATIONS ============
local NotifContainer

local function EnsureNotifContainer()
    if NotifContainer and NotifContainer.Parent then
        return NotifContainer
    end
    RavineUI.NotifGui = Create("ScreenGui", {
        Name = "RavineUI_Notifs",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 101,
        Parent = GetGuiParent(),
    })
    NotifContainer = Create("Frame", {
        Name = "Container",
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -18, 1, -18),
        Size = UDim2.new(0, 310, 1, -36),
        AnchorPoint = Vector2.new(1, 1),
        Parent = RavineUI.NotifGui,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = NotifContainer,
    })
    Create("UIScale", { Scale = RavineUI.IsMobile and 0.85 or 1, Parent = NotifContainer })
    return NotifContainer
end

function RavineUI:Notify(opts)
    if type(opts) == "string" then
        opts = { Description = opts }
    end
    opts = opts or {}
    local container = EnsureNotifContainer()
    local title = opts.Title or "Notification"
    local text = opts.Description or opts.Text or ""
    local duration = opts.Time or 4

    local holder = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 74),
        Parent = container,
    })
    local toast = Create("Frame", {
        Name = "Toast",
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.new(1, 340, 0, 0),
        ClipsDescendants = true,
        Parent = holder,
    })
    Corner(toast, 14)
    Stroke(toast, Theme.Border, 1)

    local badge = Create("Frame", {
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(12, 15),
        Size = UDim2.fromOffset(36, 36),
        Parent = toast,
    })
    Corner(badge, 11)
    local ic = NewIcon(badge, opts.Icon or "bell", 18, Theme.Accent, "!")
    ic.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    ic.Instance.Position = UDim2.fromScale(0.5, 0.5)

    Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(58, 11),
        Size = UDim2.new(1, -70, 0, 18),
        Font = Theme.FontBold,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 14,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = toast,
    })
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(58, 30),
        Size = UDim2.new(1, -70, 0, 36),
        Font = Theme.Font,
        Text = text,
        TextColor3 = Theme.SubText,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = toast,
    })

    local bar = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 3),
        Parent = toast,
    }, true)
    AccentGradient(bar, 0)

    local closed = false
    local function close()
        if closed then
            return
        end
        closed = true
        pcall(function()
            Tween(toast, 0.25, { Position = UDim2.new(1, 340, 0, 0) })
        end)
        task.wait(0.28)
        holder:Destroy()
    end

    local hit = Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        Parent = toast,
    })
    hit.MouseButton1Click:Connect(function()
        task.spawn(close)
    end)

    Tween(toast, 0.35, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
    Tween(bar, duration, { Size = UDim2.new(0, 0, 0, 3) }, Enum.EasingStyle.Linear)
    task.delay(duration, close)
end

-- ============ CONFIG ============
local ConfigFolder = "RavineUI/configs"

local function HasFS()
    return writefile and readfile and isfile and isfolder and makefolder
end

local function EnsureFolders()
    if not isfolder("RavineUI") then
        makefolder("RavineUI")
    end
    if not isfolder(ConfigFolder) then
        makefolder(ConfigFolder)
    end
end

-- Rueckgabe: true, { Toggles = n, Options = n }   oder   false, "Fehlertext"
function RavineUI:SaveConfig(name)
    if not name or name == "" then
        return false, "Kein Name angegeben"
    end
    if not HasFS() then
        return false, "Executor unterstuetzt keine Dateifunktionen"
    end
    local data = {}
    local nT, nO = 0, 0
    for id, o in pairs(self.Toggles) do
        if id:sub(1, 9) ~= "RavineUI_" then
            data[id] = { t = o.Type, v = o.Value }
            nT = nT + 1
        end
    end
    for id, o in pairs(self.Options) do
        if id:sub(1, 9) ~= "RavineUI_" then
            local v = o.Value
            if typeof(v) == "Color3" then
                v = { math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5) }
            end
            data[id] = { t = o.Type, v = v }
            nO = nO + 1
        end
    end
    local ok, err = pcall(function()
        EnsureFolders()
        writefile(ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    end)
    if not ok then
        return false, tostring(err)
    end
    return true, { Toggles = nT, Options = nO }
end

-- Rueckgabe: true, { Applied = n }   oder   false, "Fehlertext"
function RavineUI:LoadConfig(name)
    if not name or name == "" then
        return false, "Kein Name angegeben"
    end
    if not HasFS() then
        return false, "Executor unterstuetzt keine Dateifunktionen"
    end
    local path = ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then
        return false, "Config nicht gefunden"
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or type(data) ~= "table" then
        return false, "Config ist beschaedigt"
    end
    local applied = 0
    for id, entry in pairs(data) do
        local o = self.Toggles[id] or self.Options[id]
        if o and o.Set then
            local v = entry.v
            if o.Type == "ColorPicker" and type(v) == "table" then
                v = Color3.fromRGB(v[1], v[2], v[3])
            end
            if pcall(o.Set, v) then
                applied = applied + 1
            end
        end
    end
    return true, { Applied = applied }
end

function RavineUI:ListConfigs()
    local out = {}
    if not (HasFS() and listfiles) then
        return out
    end
    pcall(function()
        EnsureFolders()
        for _, path in ipairs(listfiles(ConfigFolder)) do
            local n = path:match("([^/\\]+)%.json$")
            if n then
                table.insert(out, n)
            end
        end
    end)
    table.sort(out)
    return out
end

-- ============ SCALE SPEICHERN ============
local function ScaleFile(mobile)
    return mobile and "RavineUI/scale_mobile.txt" or "RavineUI/scale.txt"
end

local function ReadSavedScale(mobile)
    if not HasFS() then
        return nil
    end
    local ok, v = pcall(function()
        if isfile(ScaleFile(mobile)) then
            return tonumber(readfile(ScaleFile(mobile)))
        end
        return nil
    end)
    if ok and v then
        return math.clamp(v, 0.25, 2)
    end
    return nil
end

local function WriteSavedScale(v, mobile)
    if not HasFS() then
        return
    end
    pcall(function()
        EnsureFolders()
        writefile(ScaleFile(mobile), tostring(v))
    end)
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
    { Name = "Aurora", Color = Color3.fromRGB(124, 92, 255) },
}

local function NearColor(a, b, tol)
    return math.abs(a.R - b.R) <= tol and math.abs(a.G - b.G) <= tol and math.abs(a.B - b.B) <= tol
end

local function ApplyColors(new, tol)
    local old = {}
    for k, v in pairs(new) do
        old[k] = Theme[k]
        Theme[k] = v
    end
    tol = tol or (RavineUI.ThemeState.Rainbow and 0.15 or 0.004)
    for inst, list in pairs(ThemeBinds) do
        for _, b in ipairs(list) do
            local key = b[2]
            local o, n = old[key], new[key]
            if o and n and NearColor(inst[b[1]], o, tol) then
                inst[b[1]] = n
            end
        end
    end
    for g, fn in pairs(GradBinds) do
        g.Color = fn()
    end
    for _, fn in ipairs(ThemeHooks) do
        pcall(fn)
    end
end

local function DarkenColor(c, f)
    local h, s, v = Color3.toHSV(c)
    return Color3.fromHSV(h, s, v * f)
end

function RavineUI:SetAccent(color, fromRainbow, tolOverride)
    if typeof(color) ~= "Color3" then
        return
    end
    if not fromRainbow then
        self.ThemeState.Accent = color
    end
    ApplyColors({
        Accent = color,
        ToggleOn = color,
        AccentDark = DarkenColor(color, 0.7),
    }, tolOverride)
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
    for _, p in ipairs(Presets) do
        table.insert(out, p.Name)
    end
    return out
end

function RavineUI:AddThemePreset(name, color)
    if type(name) ~= "string" or typeof(color) ~= "Color3" then
        return
    end
    for _, p in ipairs(Presets) do
        if p.Name == name then
            p.Color = color
            return
        end
    end
    table.insert(Presets, { Name = name, Color = color })
end

function RavineUI:OnThemeChanged(fn)
    if type(fn) == "function" then
        table.insert(ThemeHooks, fn)
    end
end

function RavineUI:SetRainbow(on, speed, silent)
    local ts = self.ThemeState
    if speed then
        ts.RainbowSpeed = math.clamp(tonumber(speed) or 0.15, 0.02, 1)
    end
    ts.Rainbow = on and true or false
    if self._rainbowConn then
        self._rainbowConn:Disconnect()
        self._rainbowConn = nil
    end
    if ts.Rainbow then
        local last = 0
        self._rainbowConn = Connect(RunService.Heartbeat, function()
            local now = os.clock()
            if now - last < 0.04 then
                return
            end
            last = now
            self:SetAccent(Color3.fromHSV((now * ts.RainbowSpeed) % 1, 0.85, 0.95), true)
        end)
    else
        self:SetAccent(ts.Accent, false, 0.15)
    end
    if not silent then
        self:_QueueThemeSave()
    end
end

function RavineUI:SetBorderAnimated(on)
    self.ThemeState.AnimBorder = on and true or false
    if not self.ThemeState.AnimBorder then
        for g in pairs(BorderGrads) do
            g.Rotation = 0
        end
    end
    self:_QueueThemeSave()
end

local ThemeFile = "RavineUI/theme.json"

local function ReadSavedTheme()
    if not HasFS() then
        return nil
    end
    local ok, data = pcall(function()
        if isfile(ThemeFile) then
            return HttpService:JSONDecode(readfile(ThemeFile))
        end
        return nil
    end)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

function RavineUI:SaveTheme()
    if not HasFS() then
        return false
    end
    local ts = self.ThemeState
    local a = ts.Accent
    pcall(function()
        EnsureFolders()
        writefile(ThemeFile, HttpService:JSONEncode({
            Preset = ts.Preset,
            Accent = { math.floor(a.R * 255 + 0.5), math.floor(a.G * 255 + 0.5), math.floor(a.B * 255 + 0.5) },
            Rainbow = ts.Rainbow,
            RainbowSpeed = ts.RainbowSpeed,
            Transparency = ts.Transparency,
            AnimBorder = ts.AnimBorder,
        }))
    end)
    return true
end

function RavineUI:_QueueThemeSave()
    self._themeSaveToken = (self._themeSaveToken or 0) + 1
    local token = self._themeSaveToken
    task.delay(0.6, function()
        if token == self._themeSaveToken and not self.Unloaded then
            self:SaveTheme()
        end
    end)
end

function RavineUI:_InitTheme(opts)
    local ts = self.ThemeState
    if typeof(opts.Accent) == "Color3" then
        ts.Preset = "Custom"
        self:SetAccent(opts.Accent)
    elseif opts.ThemePreset then
        self:SetTheme(opts.ThemePreset)
    end
    if opts.Transparency then
        ts.Transparency = math.clamp(tonumber(opts.Transparency) or 0.04, 0, 0.7)
    end
    if opts.IgnoreSavedTheme then
        return
    end
    local saved = ReadSavedTheme()
    if not saved then
        return
    end
    local a = saved.Accent
    if type(a) == "table" and #a >= 3 then
        local function ch(x)
            return math.clamp(tonumber(x) or 0, 0, 255)
        end
        self:SetAccent(Color3.fromRGB(ch(a[1]), ch(a[2]), ch(a[3])))
        ts.Preset = type(saved.Preset) == "string" and saved.Preset or "Custom"
    end
    if saved.RainbowSpeed then
        ts.RainbowSpeed = math.clamp(tonumber(saved.RainbowSpeed) or ts.RainbowSpeed, 0.02, 1)
    end
    if saved.Transparency then
        ts.Transparency = math.clamp(tonumber(saved.Transparency) or ts.Transparency, 0, 0.7)
    end
    if saved.AnimBorder ~= nil then
        ts.AnimBorder = saved.AnimBorder == true
    end
    if saved.Rainbow == true then
        self:SetRainbow(true, nil, true)
    end
end

-- ============ UNLOAD ============
function RavineUI:Unload()
    self.Unloaded = true
    TipHide()
    for _, c in ipairs(Connections) do
        pcall(function()
            c:Disconnect()
        end)
    end
    table.clear(Connections)
    self._rainbowConn = nil
    table.clear(ThemeHooks)
    if self.Gui then
        self.Gui:Destroy()
    end
    if self.NotifGui then
        self.NotifGui:Destroy()
    end
    if self._ChangelogGui then
        self._ChangelogGui:Destroy()
    end
    table.clear(self.Toggles)
    table.clear(self.Options)
    if GENV.RavineUI_Instance == self then
        GENV.RavineUI_Instance = nil
    end
end

-- ============ CHANGELOG ============
local ChangelogColors = {
    Added = Color3.fromRGB(46, 204, 113),
    Improved = Color3.fromRGB(88, 166, 255),
    Changed = Color3.fromRGB(236, 190, 60),
    Fixed = Color3.fromRGB(171, 130, 255),
    Removed = Color3.fromRGB(231, 76, 60),
}
local ChangelogIcons = {
    Added = "plus", Improved = "sparkles", Changed = "refresh-cw", Fixed = "wrench", Removed = "minus",
}
local ChangelogOrder = { "Added", "Improved", "Changed", "Fixed", "Removed" }

function RavineUI:ShowChangelog(opts)
    opts = opts or {}
    -- Das Changelog kann vor CreateWindow erscheinen: gespeichertes Theme schon jetzt anwenden
    if not RavineUI._themeReady then
        RavineUI._themeReady = true
        RavineUI:_InitTheme({})
    end
    local scriptName = opts.Title or "Script"
    local version = opts.Version or "1.0.0"
    local entries = opts.Entries or {}
    local discord = opts.Discord

    local stored = {}
    for k, v in pairs(opts) do
        if k ~= "OnClose" then
            stored[k] = v
        end
    end
    RavineUI._LastChangelog = stored

    if RavineUI._ChangelogGui and RavineUI._ChangelogGui.Parent then
        RavineUI._ChangelogGui:Destroy()
    end

    local gui = Create("ScreenGui", {
        Name = "RavineUI_Changelog",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999,
        Parent = GetGuiParent(),
    })
    RavineUI._ChangelogGui = gui

    local dim = Create("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Parent = gui,
    }, true)
    Tween(dim, 0.25, { BackgroundTransparency = 0.55 })

    local size = UDim2.fromOffset(500, 450)
    local card = Create("Frame", {
        Name = "Card",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = size,
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = RavineUI.ThemeState.Transparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = gui,
    })
    Corner(card, 18)
    Stroke(card, Theme.Border, 1)
    BorderGradient(Stroke(card, Theme.Accent, 1.5))
    local uiScale = Create("UIScale", { Parent = card })

    local function targetScale()
        local cam = workspace.CurrentCamera
        if not cam then
            return 1
        end
        local vp = cam.ViewportSize
        local fit = math.min((vp.X - 24) / size.X.Offset, (vp.Y - 24) / size.Y.Offset)
        local s = math.min(1, fit)
        if RavineUI.IsMobile then
            s = s * (RavineUI.MobileScale or 0.7)
        end
        return math.clamp(s, 0.25, 2)
    end
    local target = targetScale()
    uiScale.Scale = target * 0.92
    Tween(uiScale, 0.3, { Scale = target }, Enum.EasingStyle.Back)

    -- Kopf
    local badge = Create("Frame", {
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(20, 18),
        Size = UDim2.fromOffset(40, 40),
        Parent = card,
    })
    Corner(badge, 12)
    local bic = NewIcon(badge, opts.Icon or "scroll-text", 20, Theme.Accent, "•")
    bic.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    bic.Instance.Position = UDim2.fromScale(0.5, 0.5)

    Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(72, 18),
        Size = UDim2.new(1, -150, 0, 22),
        Font = Theme.FontBold,
        Text = "What's new",
        TextColor3 = Theme.Text,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(72, 40),
        Size = UDim2.new(1, -150, 0, 16),
        Font = Theme.Font,
        Text = scriptName .. "  ·  v" .. version,
        TextColor3 = Theme.SubText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })

    local closeBtn = Create("TextButton", {
        BackgroundColor3 = Theme.Tertiary,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -18, 0, 22),
        Size = UDim2.fromOffset(30, 30),
        Text = "",
        AutoButtonColor = false,
        Parent = card,
    })
    Corner(closeBtn, 15)
    local cst = Stroke(closeBtn, Theme.Border, 1)
    local cic = NewIcon(closeBtn, "x", 14, Theme.SubText, "x")
    cic.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    cic.Instance.Position = UDim2.fromScale(0.5, 0.5)
    closeBtn.MouseEnter:Connect(function()
        TintIcon(cic, Theme.Text)
        Tween(cst, 0.15, { Color = Theme.Accent })
    end)
    closeBtn.MouseLeave:Connect(function()
        TintIcon(cic, Theme.SubText)
        Tween(cst, 0.15, { Color = Theme.Border })
    end)

    -- Daten gruppieren
    local groups, extra = {}, {}
    for _, entry in ipairs(entries) do
        local eType, eText
        if entry.Type and entry.Text then
            eType, eText = entry.Type, entry.Text
        else
            for k, v in pairs(entry) do
                eType, eText = k, v
                break
            end
        end
        eType = tostring(eType or "Changed")
        if not groups[eType] then
            groups[eType] = {}
            if not ChangelogColors[eType] then
                table.insert(extra, eType)
            end
        end
        table.insert(groups[eType], tostring(eText))
    end

    local scroll = Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(16, 72),
        Size = UDim2.new(1, -32, 1, -150),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Border,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = card,
    })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = scroll })
    Create("UIPadding", { PaddingRight = UDim.new(0, 6), Parent = scroll })

    local order = 0
    local function buildGroup(typeName)
        local list = groups[typeName]
        if not list then
            return
        end
        local color = ChangelogColors[typeName] or Theme.Accent
        order = order + 1
        local head = Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 24),
            LayoutOrder = order,
            Parent = scroll,
        })
        local chip = Create("Frame", {
            BackgroundColor3 = color,
            BackgroundTransparency = 0.82,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 22),
            Position = UDim2.fromOffset(0, 1),
            Parent = head,
        })
        Corner(chip, 11)
        Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12), Parent = chip })
        Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = chip,
        })
        local ci = NewIcon(chip, ChangelogIcons[typeName] or "info", 12, color, "•")
        ci.Instance.LayoutOrder = 1
        Create("TextLabel", {
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 14),
            LayoutOrder = 2,
            Font = Theme.FontBold,
            Text = string.upper(typeName),
            TextColor3 = color,
            TextSize = 11,
            Parent = chip,
        })
        for _, text in ipairs(list) do
            order = order + 1
            local row = Create("Frame", {
                BackgroundColor3 = Theme.Secondary,
                BorderSizePixel = 0,
                AutomaticSize = Enum.AutomaticSize.Y,
                Size = UDim2.new(1, 0, 0, 0),
                LayoutOrder = order,
                Parent = scroll,
            })
            Corner(row, 10)
            Stroke(row, Theme.Border, 1)
            Create("UIPadding", {
                PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
                PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
                Parent = row,
            })
            local dot = Create("Frame", {
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(0, 5),
                Size = UDim2.fromOffset(6, 6),
                Parent = row,
            })
            Corner(dot, 3)
            Create("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(16, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Size = UDim2.new(1, -16, 0, 0),
                Font = Theme.Font,
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                Parent = row,
            })
        end
    end
    for _, t in ipairs(ChangelogOrder) do
        buildGroup(t)
    end
    for _, t in ipairs(extra) do
        buildGroup(t)
    end

    -- Fuss
    local footer = Create("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 68),
        Parent = card,
    })
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 0),
        Size = UDim2.new(1, -190, 1, 0),
        Font = Theme.Font,
        Text = discord or "",
        TextColor3 = Theme.SubText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = footer,
    })
    local okBtn = Create("TextButton", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -18, 0.5, 0),
        Size = UDim2.fromOffset(140, 38),
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Parent = footer,
    }, true)
    Corner(okBtn, 12)
    AccentGradient(okBtn, 20)
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Theme.FontBold,
        Text = "Continue",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 13,
        Parent = okBtn,
    }, true)

    local closing = false
    local function close()
        if closing then
            return
        end
        closing = true
        Tween(dim, 0.2, { BackgroundTransparency = 1 })
        Tween(uiScale, 0.2, { Scale = target * 0.92 })
        task.wait(0.2)
        gui:Destroy()
        if opts.OnClose then
            task.spawn(opts.OnClose)
        end
    end
    closeBtn.MouseButton1Click:Connect(close)
    okBtn.MouseButton1Click:Connect(function()
        Ripple(okBtn, UserInputService:GetMouseLocation().X)
        close()
    end)
end

-- ============ ELEMENT HELPERS ============
local function RowH()
    return RavineUI.IsMobile and 40 or 36
end

local function Add(self, className, props)
    self._n = self._n + 1
    props.LayoutOrder = self._n
    props.Parent = self.Container
    return Create(className, props)
end

local function AddRow(self, height)
    local row = Add(self, "Frame", {
        BackgroundColor3 = Theme.Tertiary,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height or RowH()),
    })
    Corner(row, 8)
    return row
end

local function RowLabel(row, text, rightInset)
    return Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -(12 + (rightInset or 12)), 0, row.Size.Y.Offset),
        Font = Theme.Font,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
end

local function HitButton(row)
    return Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        Parent = row,
    })
end

local function RegisterSearch(self, kind, label, frame, obj, opts)
    local tab = self.Tab
    local win = tab and tab.Window
    if not (win and win._search) or opts.Searchable == false then
        return
    end
    local kw = opts.Keywords
    if type(kw) == "table" then
        kw = table.concat(kw, " ")
    end
    win._search.Add({
        Name = tostring(label),
        Type = kind,
        Tab = tab,
        Group = self.Name,
        Frame = frame,
        Column = self.Column,
        Obj = obj,
        Keywords = kw and tostring(kw) or "",
    })
end

local function MakeDisabler(target, radius, opts)
    local d = { Tip = opts.DisabledTooltip }
    local overlay = Create("TextButton", {
        Name = "DisabledOverlay",
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        AutoButtonColor = false,
        Visible = false,
        ZIndex = 20,
        Parent = target,
    })
    Corner(overlay, radius or 8)
    local lock = NewIcon(overlay, "lock", 14, Theme.SubText, "!")
    lock.Instance.AnchorPoint = Vector2.new(1, 0.5)
    lock.Instance.Position = UDim2.new(1, -12, 0.5, 0)
    lock.Instance.ZIndex = 21
    overlay.MouseEnter:Connect(function()
        if d.Tip then
            TipShow(d.Tip, overlay)
        end
    end)
    overlay.MouseLeave:Connect(function()
        TipHideFor(overlay)
    end)
    overlay.MouseButton1Click:Connect(function()
        if d.Tip and UserInputService.TouchEnabled then
            TipFlash(d.Tip, overlay)
        end
    end)
    d.Set = function(v)
        overlay.Visible = v
        if not v then
            TipHideFor(overlay)
        end
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
        if onChange then
            onChange(v)
        end
    end
    obj.SetDisabledTooltip = function(a, b)
        d.Tip = Arg(obj, a, b)
    end
    obj.IsDisabled = function()
        return obj.Disabled
    end
    if opts.Disabled then
        obj.SetDisabled(true)
    end
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
        if count == 0 then
            token = token + 1
            TipHideFor(target)
        end
    end
    local function hook(o)
        o.MouseEnter:Connect(enter)
        o.MouseLeave:Connect(leave)
    end
    local function ensure()
        if hooked then
            return
        end
        hooked = true
        hook(target)
        for _, c in ipairs(target:GetDescendants()) do
            if c:IsA("GuiButton") or c:IsA("TextBox") then
                hook(c)
            end
        end
    end
    obj.SetTooltip = function(a, b)
        text = Arg(obj, a, b)
        if text and not (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
            ensure()
        end
    end
    if text then
        obj.SetTooltip(text)
    end
end

-- ============ POPOVER (Dropdown / Farbwaehler) ============
function Window:_OpenPopover(anchor, width, height, onClose, align)
    self:_ClosePopover()
    local layer = self._popLayer
    local scale = math.max(self.Scale.Scale, 0.01)

    local catcher = Create("TextButton", {
        Name = "Catcher",
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        Parent = layer,
    }, true)
    local pop = Create("Frame", {
        Name = "Popover",
        BackgroundColor3 = Theme.Tertiary,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(width, height),
        Parent = layer,
    })
    Corner(pop, 12)
    Stroke(pop, Theme.BorderLight, 1)

    local mainPos, mainSize = self.Main.AbsolutePosition, self.Main.AbsoluteSize
    local ap, asz = anchor.AbsolutePosition, anchor.AbsoluteSize
    local mw, mh = mainSize.X / scale, mainSize.Y / scale
    local x = (ap.X - mainPos.X) / scale
    if align == "right" then
        x = x + asz.X / scale - width
    end
    local y = (ap.Y - mainPos.Y + asz.Y) / scale + 6
    if y + height > mh - 8 then
        local above = (ap.Y - mainPos.Y) / scale - height - 6
        if above >= 8 then
            y = above
        else
            y = math.max(mh - height - 8, 8)
        end
    end
    x = math.clamp(x, 8, math.max(mw - width - 8, 8))
    pop.Position = UDim2.fromOffset(x, y + 6)
    Tween(pop, 0.14, { Position = UDim2.fromOffset(x, y) })

    self._pop = { pop = pop, catcher = catcher, onClose = onClose }
    catcher.MouseButton1Click:Connect(function()
        self:_ClosePopover()
    end)
    return pop
end

function Window:_ClosePopover()
    local p = self._pop
    if not p then
        return
    end
    self._pop = nil
    if p.onClose then
        pcall(p.onClose)
    end
    p.catcher:Destroy()
    p.pop:Destroy()
end

-- ============ GROUPBOX ELEMENTS ============
function Groupbox:AddDivider(thickness)
    local holder = Add(self, "Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 12),
    })
    local line = Create("Frame", {
        BackgroundColor3 = Theme.Divider,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 6, 0.5, 0),
        Size = UDim2.new(1, -12, 0, math.max(thickness or 1, 1)),
        Parent = holder,
    })
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, 0.2),
            NumberSequenceKeypoint.new(0.8, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = line,
    })
    return holder
end

function Groupbox:AddLabel(text)
    return Add(self, "TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 22),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.Font,
        Text = text,
        TextColor3 = Theme.SubText,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

function Groupbox:AddButton(name, opts)
    if type(opts) == "function" then
        opts = { Callback = opts }
    end
    opts = opts or {}
    local callback = opts.Callback or function() end

    local btn = Add(self, "TextButton", {
        BackgroundColor3 = Theme.Tertiary,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, RavineUI.IsMobile and 40 or 36),
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
    })
    Corner(btn, 10)
    local strk = Stroke(btn, Theme.Border, 1)

    local fillFrame = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Parent = btn,
    }, true)
    AccentGradient(fillFrame, 20)

    local label = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Theme.Font,
        Text = name,
        TextColor3 = Theme.Text,
        TextSize = 13,
        Parent = btn,
    })
    local ic
    if opts.Icon then
        ic = NewIcon(btn, opts.Icon, 15, Theme.SubText, "")
        ic.Instance.AnchorPoint = Vector2.new(0, 0.5)
        ic.Instance.Position = UDim2.new(0, 14, 0.5, 0)
    end

    btn.MouseEnter:Connect(function()
        Tween(fillFrame, 0.18, { BackgroundTransparency = 0.18 })
        Tween(strk, 0.18, { Color = Theme.Accent })
        if ic then
            TintIcon(ic, Color3.new(1, 1, 1))
        end
    end)
    btn.MouseLeave:Connect(function()
        Tween(fillFrame, 0.18, { BackgroundTransparency = 1 })
        Tween(strk, 0.18, { Color = Theme.Border })
        if ic then
            TintIcon(ic, Theme.SubText)
        end
    end)

    local obj = setmetatable({ Instance = btn, Container = btn, Type = "Button" }, {
        __index = function(_, k)
            return btn[k]
        end,
    })
    obj.SetText = function(a, b)
        label.Text = tostring(Arg(obj, a, b))
    end

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if not obj.Disabled then
                Ripple(btn, input.Position.X)
            end
        end
    end)
    btn.MouseButton1Click:Connect(function()
        if obj.Disabled then
            return
        end
        task.spawn(callback)
        if RavineUI.IsMobile then
            task.delay(0.2, function()
                pcall(function()
                    Tween(fillFrame, 0.18, { BackgroundTransparency = 1 })
                    Tween(strk, 0.18, { Color = Theme.Border })
                end)
            end)
        end
    end)

    AttachTooltip(obj, btn, opts)
    AttachDisable(obj, btn, 10, opts)
    RegisterSearch(self, "Button", name, btn, obj, opts)
    return obj
end

function Groupbox:AddToggle(id, opts)
    opts = opts or {}
    local callback = opts.Callback or function() end
    local state = opts.Default or false
    local obj, changed = NewOption("Toggle", id, state)

    local row = AddRow(self)
    RowLabel(row, opts.Text or id, 66)

    local track = Create("Frame", {
        BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(40, 22),
        Parent = row,
    })
    Corner(track, 11)
    local glow = Stroke(track, Theme.Accent, 3, state and 0.65 or 1)
    local thumb = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        Parent = track,
    })
    Corner(thumb, 8)

    local function setState(v)
        state = v and true or false
        Tween(track, 0.2, { BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff })
        Tween(thumb, 0.22, {
            Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        }, Enum.EasingStyle.Back)
        Tween(glow, 0.2, { Transparency = state and 0.65 or 1 })
        changed(state)
        task.spawn(callback, state)
    end

    local hit = HitButton(row)
    hit.MouseEnter:Connect(function()
        Tween(row, 0.12, { BackgroundTransparency = 0.55 })
    end)
    hit.MouseLeave:Connect(function()
        Tween(row, 0.12, { BackgroundTransparency = 1 })
    end)
    hit.MouseButton1Click:Connect(function()
        if obj.Disabled then
            return
        end
        setState(not state)
    end)

    obj.Container = row
    obj.Set = function(a, b)
        if obj.Disabled then
            return
        end
        setState(Arg(obj, a, b))
    end
    obj.Get = function()
        return state
    end
    function obj:SetValue(v)
        obj.Set(v)
    end
    AttachTooltip(obj, row, opts)
    AttachDisable(obj, row, 8, opts)
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

    local row = AddRow(self, RavineUI.IsMobile and 58 or 54)
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 6),
        Size = UDim2.new(1, -96, 0, 18),
        Font = Theme.Font,
        Text = opts.Text or id,
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    local chip = Create("Frame", {
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.88,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 5),
        Size = UDim2.fromOffset(68, 20),
        Parent = row,
    })
    Corner(chip, 10)
    local valueLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Theme.FontBold,
        Text = tostring(value) .. suffix,
        TextColor3 = Theme.Accent,
        TextSize = 12,
        Parent = chip,
    })

    local barY = RavineUI.IsMobile and 40 or 37
    local barBg = Create("Frame", {
        BackgroundColor3 = Theme.ToggleOff,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 14, 0, barY),
        Size = UDim2.new(1, -28, 0, 6),
        Parent = row,
    })
    Corner(barBg, 3)
    local fill = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Size = UDim2.new((value - min) / range, 0, 1, 0),
        Parent = barBg,
    }, true)
    Corner(fill, 3)
    AccentGradient(fill, 0)
    local thumb = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((value - min) / range, 0, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        ZIndex = 2,
        Parent = barBg,
    })
    Corner(thumb, 8)
    Stroke(thumb, Theme.Accent, 2)

    local hit = Create("TextButton", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, barY - 14),
        Size = UDim2.new(1, 0, 0, 34),
        Text = "",
        Parent = row,
    })

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
        if obj.Disabled then
            return
        end
        local rel = math.clamp((pos.X - barBg.AbsolutePosition.X) / math.max(barBg.AbsoluteSize.X, 1), 0, 1)
        setValue(min + range * rel)
    end)

    obj.Container = row
    obj.Set = function(a, b)
        if obj.Disabled then
            return
        end
        setValue(Arg(obj, a, b), 0.1)
    end
    obj.Get = function()
        return value
    end
    function obj:SetValue(v)
        obj.Set(v)
    end
    AttachTooltip(obj, row, opts)
    AttachDisable(obj, row, 8, opts)
    RegisterSearch(self, "Slider", opts.Text or id, row, obj, opts)
    return obj
end

-- Dropdown: Einzelauswahl oder Multi = true. Oeffnet als Popover. Search = true/false (ohne Angabe ab 8 Eintraegen)
function Groupbox:AddDropdown(id, opts)
    opts = opts or {}
    local values = opts.Values or {}
    local callback = opts.Callback or function() end
    local multi = opts.Multi == true
    local current = nil
    if not multi then
        current = opts.Default or (values[1] or "")
    end
    local selected = {}

    local function inValues(key)
        for _, v in ipairs(values) do
            if tostring(v) == key then
                return true
            end
        end
        return false
    end
    local function toMap(v)
        local map = {}
        local function add(x)
            local k = tostring(x)
            if inValues(k) then
                map[k] = true
            end
        end
        if type(v) == "table" then
            for k, val in pairs(v) do
                if type(k) == "number" then
                    add(val)
                elseif val then
                    add(k)
                end
            end
        elseif v ~= nil and v ~= "" then
            add(v)
        end
        return map
    end
    local function snapshot()
        local m = {}
        for k in pairs(selected) do
            m[k] = true
        end
        return m
    end
    local function count()
        local n = 0
        for _ in pairs(selected) do
            n = n + 1
        end
        return n
    end
    local function summary()
        local n = count()
        if n == 0 then
            return "None"
        end
        if n == 1 then
            for k in pairs(selected) do
                return k
            end
        end
        return n .. " selected"
    end
    if multi then
        selected = toMap(opts.Default)
    end

    local obj, changed = NewOption("Dropdown", id, multi and snapshot() or current)
    local win = self.Tab and self.Tab.Window
    local column = self.Column

    local row = AddRow(self)
    RowLabel(row, opts.Text or id, 164)

    local btn = Create("TextButton", {
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(140, 26),
        Text = "",
        AutoButtonColor = false,
        Parent = row,
    })
    Corner(btn, 8)
    local bst = Stroke(btn, Theme.Border, 1)
    local curLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -34, 1, 0),
        Font = Theme.Font,
        Text = multi and summary() or tostring(current),
        TextColor3 = Theme.Accent,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = btn,
    })
    local chev = NewIcon(btn, "chevron-down", 14, Theme.SubText, "v")
    chev.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    chev.Instance.Position = UDim2.new(1, -14, 0.5, 0)

    local activeRender = nil
    local isOpen = false
    local scrollConn = nil

    local function isSelected(val)
        if multi then
            return selected[tostring(val)] == true
        end
        return tostring(val) == tostring(current)
    end
    local function choose(val)
        current = val
        curLabel.Text = tostring(val)
        changed(val)
        task.spawn(callback, val)
        if activeRender then
            activeRender()
        end
    end
    local function applyMulti()
        curLabel.Text = summary()
        local snap = snapshot()
        changed(snap)
        task.spawn(callback, snap)
        if activeRender then
            activeRender()
        end
    end
    local function toggleMulti(val)
        local k = tostring(val)
        if selected[k] then
            selected[k] = nil
        else
            selected[k] = true
        end
        applyMulti()
    end

    local function openPop()
        if obj.Disabled or not win then
            return
        end
        if isOpen then
            win:_ClosePopover()
            return
        end
        local showSearch = opts.Search
        if showSearch == nil then
            showSearch = #values >= 8
        end
        local listTop = showSearch and 42 or 8
        local listH = math.min(math.max(#values, 1) * 28, 168)
        local pop = win:_OpenPopover(btn, 190, listTop + listH + 8, function()
            isOpen = false
            activeRender = nil
            if scrollConn then
                scrollConn:Disconnect()
                scrollConn = nil
            end
            Tween(chev.Instance, 0.15, { Rotation = 0 })
            Tween(bst, 0.15, { Color = Theme.Border })
        end, "right")
        isOpen = true
        Tween(chev.Instance, 0.15, { Rotation = 180 })
        Tween(bst, 0.15, { Color = Theme.Accent })
        if column then
            scrollConn = column:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                win:_ClosePopover()
            end)
        end

        local searchBox
        if showSearch then
            local sf = Create("Frame", {
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(8, 8),
                Size = UDim2.new(1, -16, 0, 26),
                Parent = pop,
            })
            Corner(sf, 8)
            local sst = Stroke(sf, Theme.Border, 1)
            local si = NewIcon(sf, "search", 13, Theme.SubText, "?")
            si.Instance.AnchorPoint = Vector2.new(0, 0.5)
            si.Instance.Position = UDim2.new(0, 8, 0.5, 0)
            searchBox = Create("TextBox", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(28, 0),
                Size = UDim2.new(1, -36, 1, 0),
                Font = Theme.Font,
                Text = "",
                PlaceholderText = "Search...",
                PlaceholderColor3 = Theme.SubText,
                TextColor3 = Theme.Text,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                ClearTextOnFocus = false,
                Parent = sf,
            })
            searchBox.Focused:Connect(function()
                Tween(sst, 0.15, { Color = Theme.Accent })
            end)
            searchBox.FocusLost:Connect(function()
                Tween(sst, 0.15, { Color = Theme.Border })
            end)
        end

        local list = Create("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(8, listTop),
            Size = UDim2.new(1, -16, 0, listH),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Border,
            Parent = pop,
        })
        Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = list })
        local empty = Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(8, listTop),
            Size = UDim2.new(1, -16, 0, 26),
            Font = Theme.Font,
            Text = "No results",
            TextColor3 = Theme.SubText,
            TextSize = 12,
            Visible = false,
            Parent = pop,
        })

        local firstVal = nil
        local function render()
            for _, c in ipairs(list:GetChildren()) do
                if c:IsA("TextButton") then
                    c:Destroy()
                end
            end
            local q = searchBox and searchBox.Text:lower() or ""
            local n = 0
            firstVal = nil
            for i, val in ipairs(values) do
                local name = tostring(val)
                if q == "" or name:lower():find(q, 1, true) then
                    n = n + 1
                    if firstVal == nil then
                        firstVal = val
                    end
                    local sel = isSelected(val)
                    local o = Create("TextButton", {
                        BackgroundColor3 = Theme.Accent,
                        BackgroundTransparency = sel and 0.85 or 1,
                        BorderSizePixel = 0,
                        Size = UDim2.new(1, -4, 0, 26),
                        LayoutOrder = i,
                        Font = Theme.Font,
                        Text = name,
                        TextColor3 = sel and Theme.Accent or Theme.Text,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        AutoButtonColor = false,
                        Parent = list,
                    })
                    Create("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = o })
                    Corner(o, 7)
                    if sel then
                        local ck = NewIcon(o, "check", 14, Theme.Accent, "•")
                        ck.Instance.AnchorPoint = Vector2.new(1, 0.5)
                        ck.Instance.Position = UDim2.new(1, -8, 0.5, 0)
                    end
                    o.MouseEnter:Connect(function()
                        Tween(o, 0.1, { BackgroundTransparency = 0.8 })
                    end)
                    o.MouseLeave:Connect(function()
                        Tween(o, 0.1, { BackgroundTransparency = sel and 0.85 or 1 })
                    end)
                    o.MouseButton1Click:Connect(function()
                        if multi then
                            toggleMulti(val)
                        else
                            choose(val)
                            win:_ClosePopover()
                        end
                    end)
                end
            end
            empty.Visible = n == 0
        end
        activeRender = render
        render()

        if searchBox then
            searchBox:GetPropertyChangedSignal("Text"):Connect(render)
            searchBox.FocusLost:Connect(function(enter)
                if enter and not multi and firstVal ~= nil then
                    choose(firstVal)
                    win:_ClosePopover()
                end
            end)
            if not RavineUI.IsMobile then
                task.delay(0.05, function()
                    if isOpen then
                        searchBox:CaptureFocus()
                    end
                end)
            end
        end
    end
    btn.MouseButton1Click:Connect(openPop)

    obj.Container = row
    obj.Multi = multi
    obj.Set = function(a, b)
        if obj.Disabled then
            return
        end
        local v = Arg(obj, a, b)
        if multi then
            selected = toMap(v)
            applyMulti()
        else
            choose(v)
        end
    end
    obj.Get = function()
        if multi then
            return snapshot()
        end
        return current
    end
    obj.GetSelected = function()
        local out = {}
        if multi then
            for _, v in ipairs(values) do
                if selected[tostring(v)] then
                    table.insert(out, v)
                end
            end
        elseif current ~= nil and current ~= "" then
            table.insert(out, current)
        end
        return out
    end
    obj.SelectAll = function()
        if multi and not obj.Disabled then
            selected = toMap(values)
            applyMulti()
        end
    end
    obj.Clear = function()
        if multi and not obj.Disabled then
            selected = {}
            applyMulti()
        end
    end
    obj.Refresh = function(a, b)
        local newValues = Arg(obj, a, b)
        if type(newValues) ~= "table" then
            return
        end
        values = newValues
        local before = count()
        if multi then
            selected = toMap(selected)
            curLabel.Text = summary()
            if count() ~= before then
                applyMulti()
            end
        end
        if activeRender then
            activeRender()
        end
    end
    function obj:SetValue(v)
        obj.Set(v)
    end
    AttachTooltip(obj, row, opts)
    AttachDisable(obj, row, 8, opts, function(v)
        if v and isOpen and win then
            win:_ClosePopover()
        end
    end)
    RegisterSearch(self, "Dropdown", opts.Text or id, row, obj, opts)
    return obj
end

function Groupbox:AddTextbox(id, opts)
    opts = opts or {}
    local callback = opts.Callback or function() end
    local obj, changed = NewOption("Textbox", id, opts.Default or "")

    local row = AddRow(self, 58)
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 6),
        Size = UDim2.new(1, -24, 0, 14),
        Font = Theme.Font,
        Text = opts.Text or id,
        TextColor3 = Theme.SubText,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    local field = Create("Frame", {
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 0, 25),
        Size = UDim2.new(1, -20, 0, 27),
        Parent = row,
    })
    Corner(field, 8)
    local fst = Stroke(field, Theme.Border, 1)
    local box = Create("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -20, 1, 0),
        Font = Theme.Font,
        Text = opts.Default or "",
        PlaceholderText = opts.Placeholder or "",
        TextColor3 = Theme.Text,
        PlaceholderColor3 = Theme.SubText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = field,
    })
    box.Focused:Connect(function()
        Tween(fst, 0.15, { Color = Theme.Accent })
    end)
    box.FocusLost:Connect(function()
        Tween(fst, 0.15, { Color = Theme.Border })
        changed(box.Text)
        task.spawn(callback, box.Text)
    end)

    obj.Instance = box
    obj.Container = row
    obj.Set = function(a, b)
        if obj.Disabled then
            return
        end
        box.Text = tostring(Arg(obj, a, b))
        changed(box.Text)
        task.spawn(callback, box.Text)
    end
    obj.Get = function()
        return box.Text
    end
    function obj:SetValue(t)
        obj.Set(t)
    end
    AttachTooltip(obj, row, opts)
    AttachDisable(obj, row, 8, opts, function(v)
        box.TextEditable = not v
        if v then
            pcall(function()
                if box:IsFocused() then
                    box:ReleaseFocus()
                end
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
    local obj, changed = NewOption("ColorPicker", id, color)
    local win = self.Tab and self.Tab.Window
    local column = self.Column

    local row = AddRow(self)
    RowLabel(row, opts.Text or id, 66)

    local swatch = Create("TextButton", {
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(38, 22),
        Text = "",
        AutoButtonColor = false,
        Parent = row,
    }, true)
    Corner(swatch, 7)
    Stroke(swatch, Theme.BorderLight, 1)

    -- Der Picker wird einmal gebaut und beim Oeffnen in das Popover gehaengt
    local picker = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, true)
    local sv = Create("Frame", {
        BackgroundColor3 = Color3.fromHSV(h, 1, 1),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.new(1, -44, 0, 110),
        Parent = picker,
    }, true)
    Corner(sv, 8)
    local white = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = sv,
    })
    Corner(white, 8)
    Create("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
    local black = Create("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = sv,
    })
    Corner(black, 8)
    Create("UIGradient", { Transparency = NumberSequence.new(1, 0), Rotation = 90, Parent = black })
    local svCursor = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(10, 10),
        ZIndex = 3,
        Parent = sv,
    })
    Corner(svCursor, 5)
    Stroke(svCursor, Color3.new(0, 0, 0), 1)

    local hueBar = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Position = UDim2.new(1, -26, 0, 10),
        Size = UDim2.fromOffset(16, 110),
        Parent = picker,
    })
    Corner(hueBar, 8)
    local hueKeys = {}
    for i = 0, 6 do
        table.insert(hueKeys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(math.min(i / 6, 0.999), 1, 1)))
    end
    Create("UIGradient", { Color = ColorSequence.new(hueKeys), Rotation = 90, Parent = hueBar })
    local hueCursor = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(1, 4, 0, 4),
        ZIndex = 3,
        Parent = hueBar,
    })
    Corner(hueCursor, 2)
    Stroke(hueCursor, Color3.new(0, 0, 0), 1)

    local hexField = Create("Frame", {
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 130),
        Size = UDim2.new(1, -20, 0, 26),
        Parent = picker,
    })
    Corner(hexField, 8)
    local hst = Stroke(hexField, Theme.Border, 1)
    local hexBox = Create("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -20, 1, 0),
        Font = Theme.FontBold,
        Text = "",
        PlaceholderText = "#RRGGBB",
        PlaceholderColor3 = Theme.SubText,
        TextColor3 = Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = hexField,
    })

    local function toHex(c)
        return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
    end
    local function render()
        color = Color3.fromHSV(h, s, v)
        swatch.BackgroundColor3 = color
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svCursor.Position = UDim2.fromScale(s, 1 - v)
        hueCursor.Position = UDim2.fromScale(0.5, h)
        if not hexBox:IsFocused() then
            hexBox.Text = toHex(color)
        end
    end
    local function commit()
        render()
        changed(color)
        task.spawn(callback, color)
    end
    render()

    TrackDrag(sv, nil, function(pos)
        s = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
        v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
        commit()
    end)
    TrackDrag(hueBar, nil, function(pos)
        h = math.clamp((pos.Y - hueBar.AbsolutePosition.Y) / math.max(hueBar.AbsoluteSize.Y, 1), 0, 1)
        commit()
    end)
    hexBox.Focused:Connect(function()
        Tween(hst, 0.15, { Color = Theme.Accent })
    end)
    hexBox.FocusLost:Connect(function()
        Tween(hst, 0.15, { Color = Theme.Border })
        local hex = hexBox.Text:match("^#?(%x%x%x%x%x%x)$")
        if hex then
            local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
            h, s, v = Color3.toHSV(Color3.fromRGB(r, g, b))
            commit()
        else
            hexBox.Text = toHex(color)
        end
    end)

    local isOpen = false
    local scrollConn = nil
    swatch.MouseButton1Click:Connect(function()
        if obj.Disabled or not win then
            return
        end
        if isOpen then
            win:_ClosePopover()
            return
        end
        local pop = win:_OpenPopover(swatch, 210, 168, function()
            isOpen = false
            picker.Parent = nil
            if scrollConn then
                scrollConn:Disconnect()
                scrollConn = nil
            end
        end, "right")
        isOpen = true
        picker.Parent = pop
        if column then
            scrollConn = column:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                win:_ClosePopover()
            end)
        end
    end)

    obj.Container = row
    obj.Set = function(a, b)
        if obj.Disabled then
            return
        end
        local c = Arg(obj, a, b)
        h, s, v = Color3.toHSV(c)
        commit()
    end
    obj.Get = function()
        return color
    end
    function obj:SetValue(c)
        obj.Set(c)
    end
    AttachTooltip(obj, row, opts)
    AttachDisable(obj, row, 8, opts, function(dis)
        if dis and isOpen and win then
            win:_ClosePopover()
        end
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

    local row = AddRow(self)
    RowLabel(row, opts.Text or id, 96)

    local keyBtn = Create("TextButton", {
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(76, 24),
        Font = Theme.FontBold,
        Text = ShortKey(current),
        TextColor3 = Theme.Text,
        TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = false,
        Parent = row,
    })
    Corner(keyBtn, 8)
    local kst = Stroke(keyBtn, Theme.Border, 1)

    keyBtn.MouseButton1Click:Connect(function()
        if obj.Disabled then
            return
        end
        listening = true
        keyBtn.Text = "..."
        Tween(kst, 0.15, { Color = Theme.Accent })
    end)

    Connect(UserInputService.InputBegan, function(input, gpe)
        if gpe then
            return
        end
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                listening = false
                if input.KeyCode ~= Enum.KeyCode.Escape then
                    current = input.KeyCode.Name
                    changed(current)
                end
                keyBtn.Text = ShortKey(current)
                Tween(kst, 0.15, { Color = Theme.Border })
            end
        elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == current
            and not obj.Disabled then
            task.spawn(callback)
        end
    end)

    obj.Container = row
    obj.Set = function(a, b)
        if obj.Disabled then
            return
        end
        current = Arg(obj, a, b)
        keyBtn.Text = ShortKey(current)
        changed(current)
    end
    obj.Get = function()
        return current
    end
    function obj:SetValue(k)
        obj.Set(k)
    end
    AttachTooltip(obj, row, opts)
    AttachDisable(obj, row, 8, opts, function(dis)
        if dis then
            listening = false
            keyBtn.Text = ShortKey(current)
            Tween(kst, 0.15, { Color = Theme.Border })
        end
    end)
    RegisterSearch(self, "KeyPicker", opts.Text or id, row, obj, opts)
    return obj
end

-- ============ SEARCH ============
local SearchTypeIcons = {
    Toggle = "toggle-right", Slider = "sliders-horizontal", Dropdown = "list", Textbox = "type",
    ColorPicker = "palette", KeyPicker = "keyboard", Button = "mouse-pointer-click", Tab = "layout-dashboard",
}

local function BuildSearch(win, main, onState)
    local entries = {}
    local shown = {}
    local api = { Entries = entries, IsOpen = false }

    local panel = Create("Frame", {
        Name = "SearchPanel",
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 0, TOP_H + 4),
        Size = UDim2.new(1, -24, 1, -(TOP_H + 16)),
        Visible = false,
        Active = true,
        ZIndex = 60,
        Parent = main,
    })
    Corner(panel, 14)
    Stroke(panel, Theme.BorderLight, 1)

    local inputRow = Create("Frame", {
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 0, 12),
        Size = UDim2.new(1, -24, 0, 40),
        Parent = panel,
    })
    Corner(inputRow, 12)
    local inputStroke = Stroke(inputRow, Theme.Border, 1)
    local sIcon = NewIcon(inputRow, "search", 16, Theme.SubText, "?")
    sIcon.Instance.AnchorPoint = Vector2.new(0, 0.5)
    sIcon.Instance.Position = UDim2.new(0, 14, 0.5, 0)
    local box = Create("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 40, 0, 0),
        Size = UDim2.new(1, -78, 1, 0),
        Font = Theme.Font,
        Text = "",
        PlaceholderText = "Search all options...",
        PlaceholderColor3 = Theme.SubText,
        TextColor3 = Theme.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = inputRow,
    })
    local clearBtn = Create("TextButton", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(26, 26),
        Text = "",
        AutoButtonColor = false,
        Visible = false,
        Parent = inputRow,
    })
    local clearIcon = NewIcon(clearBtn, "x", 14, Theme.SubText, "x")
    clearIcon.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    clearIcon.Instance.Position = UDim2.fromScale(0.5, 0.5)

    local info = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 56),
        Size = UDim2.new(1, -32, 0, 16),
        Font = Theme.Font,
        Text = "",
        TextColor3 = Theme.SubText,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = panel,
    })
    local results = Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 0, 78),
        Size = UDim2.new(1, -24, 1, -88),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Border,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = panel,
    })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5), Parent = results })
    Create("UIPadding", { PaddingRight = UDim.new(0, 4), Parent = results })
    local empty = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 100),
        Size = UDim2.new(1, -32, 0, 40),
        Font = Theme.Font,
        Text = "",
        TextColor3 = Theme.SubText,
        TextSize = 12,
        TextWrapped = true,
        Parent = panel,
    })

    local function reveal(e)
        local frame, col = e.Frame, e.Column
        if not (frame and frame.Parent and col and col.Parent) then
            return
        end
        local scale = math.max(win.Scale.Scale, 0.01)
        local rel = (frame.AbsolutePosition.Y - col.AbsolutePosition.Y) / scale
        local maxY = math.max((col.AbsoluteCanvasSize.Y - col.AbsoluteWindowSize.Y) / scale, 0)
        local target = math.clamp(col.CanvasPosition.Y + rel - 50, 0, maxY)
        Tween(col, 0.25, { CanvasPosition = Vector2.new(0, target) })
        local stroke = frame:FindFirstChildOfClass("UIStroke")
        local baseT = frame.BackgroundTransparency
        task.spawn(function()
            pcall(function()
                for _ = 1, 2 do
                    if stroke then
                        Tween(stroke, 0.18, { Color = Theme.Accent, Thickness = 2 })
                    else
                        Tween(frame, 0.18, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.7 })
                    end
                    task.wait(0.3)
                    if stroke then
                        Tween(stroke, 0.25, { Color = Theme.Border, Thickness = 1 })
                    else
                        Tween(frame, 0.25, { BackgroundColor3 = Theme.Tertiary, BackgroundTransparency = baseT })
                    end
                    task.wait(0.35)
                end
            end)
        end)
    end

    local function jump(e)
        api.SetOpen(false)
        win:SelectTab(e.Tab)
        if e.Frame then
            task.delay(0.12, function()
                reveal(e)
            end)
        end
    end

    local function makeRow(e, order)
        local btn = Create("TextButton", {
            BackgroundColor3 = Theme.Tertiary,
            BorderSizePixel = 0,
            Size = UDim2.new(1, -4, 0, 46),
            LayoutOrder = order,
            Text = "",
            AutoButtonColor = false,
            Parent = results,
        })
        Corner(btn, 10)
        local st = Stroke(btn, Theme.Border, 1)
        local tile = Create("Frame", {
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 0.86,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 8, 0.5, 0),
            Size = UDim2.fromOffset(30, 30),
            Parent = btn,
        })
        Corner(tile, 9)
        local ic = NewIcon(tile, SearchTypeIcons[e.Type] or "search", 15, Theme.Accent, "•")
        ic.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
        ic.Instance.Position = UDim2.fromScale(0.5, 0.5)
        Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 48, 0, 7),
            Size = UDim2.new(1, -60, 0, 18),
            Font = Theme.FontBold,
            Text = e.Name,
            TextColor3 = Theme.Text,
            TextSize = 13,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = btn,
        })
        local sub = e.Type == "Tab" and "Tab" or ((e.Tab and e.Tab.Name or "") .. " / " .. tostring(e.Group or ""))
        if e.Obj and e.Obj.Disabled then
            sub = sub .. "  -  locked"
        end
        Create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 48, 0, 25),
            Size = UDim2.new(1, -60, 0, 14),
            Font = Theme.Font,
            Text = sub,
            TextColor3 = Theme.SubText,
            TextSize = 11,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = btn,
        })
        btn.MouseEnter:Connect(function()
            Tween(st, 0.12, { Color = Theme.Accent })
        end)
        btn.MouseLeave:Connect(function()
            Tween(st, 0.12, { Color = Theme.Border })
        end)
        btn.MouseButton1Click:Connect(function()
            jump(e)
        end)
    end

    local function render(query)
        for _, c in ipairs(results:GetChildren()) do
            if c:IsA("TextButton") then
                c:Destroy()
            end
        end
        shown = {}
        local tokens = {}
        for t in query:lower():gmatch("%S+") do
            table.insert(tokens, t)
        end

        if #tokens == 0 then
            if api.ListMode then
                local n, tabCount, seen = 0, 0, {}
                for _, e in ipairs(entries) do
                    if e.Type ~= "Tab" and e.Tab and not e.Tab._internal then
                        n = n + 1
                        shown[n] = e
                        makeRow(e, n)
                        if not seen[e.Tab] then
                            seen[e.Tab] = true
                            tabCount = tabCount + 1
                        end
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
                if i then
                    score = score + (i == 1 and 3 or 2)
                elseif e.Blob:find(t, 1, true) then
                    score = score + 1
                else
                    score = 0
                    break
                end
            end
            if score > 0 then
                table.insert(scored, { s = score, e = e })
            end
        end
        table.sort(scored, function(a, b)
            if a.s ~= b.s then
                return a.s > b.s
            end
            return a.e.Lower < b.e.Lower
        end)
        for i = 1, math.min(#scored, 40) do
            shown[i] = scored[i].e
            makeRow(scored[i].e, i)
        end
        info.Text = Plural(#shown, "result") .. (#scored > #shown and " (showing first 40)" or "")
        empty.Visible = #shown == 0
        if #shown == 0 then
            empty.Text = 'No results for "' .. query .. '"'
        end
    end

    box:GetPropertyChangedSignal("Text"):Connect(function()
        clearBtn.Visible = box.Text ~= ""
        render(box.Text)
    end)
    box.Focused:Connect(function()
        Tween(inputStroke, 0.15, { Color = Theme.Accent })
    end)
    box.FocusLost:Connect(function(enterPressed, input)
        Tween(inputStroke, 0.15, { Color = Theme.Border })
        if input and input.KeyCode == Enum.KeyCode.Escape then
            api.SetOpen(false)
        elseif enterPressed and shown[1] then
            jump(shown[1])
        end
    end)
    clearBtn.MouseButton1Click:Connect(function()
        box.Text = ""
        box:CaptureFocus()
    end)

    function api.SetOpen(v, query)
        v = v and true or false
        if v == api.IsOpen then
            if v and query then
                box.Text = query
            end
            return
        end
        api.IsOpen = v
        if not v then
            api.ListMode = false
        end
        TipHide()
        panel.Visible = v
        if v then
            win:_ClosePopover()
            box.Text = query or ""
            render(box.Text)
            task.delay(0.05, function()
                if api.IsOpen then
                    box:CaptureFocus()
                end
            end)
        else
            pcall(function()
                box:ReleaseFocus()
            end)
        end
        if onState then
            onState(v)
        end
    end

    function api.OpenList()
        api.ListMode = true
        if api.IsOpen then
            render(box.Text)
        else
            api.SetOpen(true, "")
        end
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

-- ============ WINDOW ============
function RavineUI:CreateWindow(opts)
    opts = opts or {}
    local title = opts.Title or "RavineUI"
    local subtitle = opts.Subtitle or ""
    local mobile = opts.Mobile
    if mobile == nil then
        mobile = RavineUI.IsMobile
    end
    RavineUI.IsMobile = mobile
    RavineUI.MobileScale = opts.MobileScale or 0.7
    RavineUI:_InitTheme(opts)
    local size = opts.Size or (mobile and UDim2.fromOffset(620, 400) or UDim2.fromOffset(720, 450))
    local savedScale = ReadSavedScale(mobile)
    local gui = EnsureGui()

    local main = Create("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = size,
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = RavineUI.ThemeState.Transparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = gui,
    })
    Corner(main, 18)
    Stroke(main, Theme.Border, 1)
    BorderGradient(Stroke(main, Theme.Accent, 1.5))
    local uiScale = Create("UIScale", { Parent = main })

    -- ===== Kopfzeile =====
    local header = Create("Frame", {
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, HEADER_H),
        Parent = main,
    })

    local logoSrc = opts.Logo or opts.Icon or "moon"
    local customLogo = IsCustomImage(logoSrc)
    local logoPx = math.clamp(opts.LogoSize or (customLogo and 32 or 22), 12, 44)
    local logoX = customLogo and 14 or 18
    local logo = NewIcon(header, logoSrc, logoPx, customLogo and Color3.new(1, 1, 1) or Theme.Accent, "V")
    logo.Instance.AnchorPoint = Vector2.new(0, 0.5)
    logo.Instance.Position = UDim2.new(0, logoX, 0.5, 0)
    local titleX = logoX + logoPx + 12
    local reserve = (opts.Search ~= false) and 150 or 112

    local titleHolder = Create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, titleX, 0, 0),
        Size = UDim2.new(1, -(titleX + reserve), 1, 0),
        Parent = header,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        Parent = titleHolder,
    })
    Create("TextLabel", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 0, 20),
        LayoutOrder = 1,
        Font = Theme.FontBold,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 16,
        Parent = titleHolder,
    })
    if subtitle ~= "" then
        local chip = Create("Frame", {
            BackgroundColor3 = Theme.Tertiary,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 22),
            LayoutOrder = 2,
            Parent = titleHolder,
        })
        Corner(chip, 11)
        Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip })
        Create("TextLabel", {
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            Font = Theme.Font,
            Text = subtitle,
            TextColor3 = Theme.SubText,
            TextSize = 11,
            Parent = chip,
        })
    end

    local btnHolder = Create("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.new(0, 0, 0, 30),
        AutomaticSize = Enum.AutomaticSize.X,
        Parent = header,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = btnHolder,
    })

    local function TopButton(order, icon, fallback)
        local active = false
        local b = Create("TextButton", {
            BackgroundColor3 = Theme.Tertiary,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(30, 30),
            LayoutOrder = order,
            Text = "",
            AutoButtonColor = false,
            Parent = btnHolder,
        })
        Corner(b, 15)
        local s = Stroke(b, Theme.Border, 1)
        local ic = NewIcon(b, icon, 14, Theme.SubText, fallback)
        ic.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
        ic.Instance.Position = UDim2.fromScale(0.5, 0.5)
        b.MouseEnter:Connect(function()
            TintIcon(ic, Theme.Text)
            Tween(s, 0.15, { Color = Theme.Accent })
        end)
        b.MouseLeave:Connect(function()
            TintIcon(ic, active and Theme.Accent or Theme.SubText)
            Tween(s, 0.15, { Color = active and Theme.Accent or Theme.Border })
        end)
        return b, {
            SetActive = function(v)
                active = v and true or false
                TintIcon(ic, active and Theme.Accent or Theme.SubText)
                Tween(s, 0.15, { Color = active and Theme.Accent or Theme.Border })
            end,
        }
    end

    local searchBtn, searchApi
    if opts.Search ~= false then
        searchBtn, searchApi = TopButton(1, "search", "S")
    end
    local minBtn = TopButton(2, "minus", "-")
    local closeBtn = TopButton(3, "x", "x")

    local hair = Create("Frame", {
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, HEADER_H - 1),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = main,
    })
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.15, 0.2),
            NumberSequenceKeypoint.new(0.85, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = hair,
    })

    -- ===== Tab-Leiste (Pillen) =====
    local tabBar = Create("ScrollingFrame", {
        Name = "TabBar",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 0, HEADER_H),
        Size = UDim2.new(1, -24, 0, TABBAR_H),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X,
        Parent = main,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = tabBar,
    })

    local content = Create("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, TOP_H),
        Size = UDim2.new(1, 0, 1, -TOP_H),
        ClipsDescendants = true,
        Parent = main,
    })

    local popLayer = Create("Frame", {
        Name = "Popovers",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 80,
        Parent = main,
    })

    MakeDraggable(main, header, function()
        return uiScale.Scale
    end)

    local windowObj = setmetatable({
        Gui = gui,
        Main = main,
        Header = header,
        TabBar = tabBar,
        Content = content,
        Scale = uiScale,
        Title = title,
        Tabs = {},
        ActiveTab = nil,
        HomeTab = nil,
        ToggleKeybind = opts.ToggleKeybind or Enum.KeyCode.RightControl,
        Minimized = false,
        Alive = true,
        Size = size,
        UserScale = savedScale,
        AvatarHidden = false,
        _popLayer = popLayer,
        _targetScale = 1,
    }, Window)
    windowObj.Logo = logo
    windowObj.TitleHolder = titleHolder
    windowObj._logoX = logoX
    windowObj._reserve = reserve

    if searchBtn then
        windowObj._search = BuildSearch(windowObj, main, function(v)
            searchApi.SetActive(v)
        end)
        searchBtn.MouseButton1Click:Connect(function()
            windowObj:ToggleSearch()
        end)
    end

    -- ===== Skalierung =====
    local function clampToScreen()
        local ps = gui.AbsoluteSize
        if ps.X <= 0 or ps.Y <= 0 then
            return
        end
        local w = size.X.Offset * uiScale.Scale
        local h = (windowObj.Minimized and HEADER_H or size.Y.Offset) * uiScale.Scale
        local cx = main.Position.X.Scale * ps.X + main.Position.X.Offset
        local cy = main.Position.Y.Scale * ps.Y + main.Position.Y.Offset
        cx = math.clamp(cx, w / 2, math.max(ps.X - w / 2, w / 2))
        cy = math.clamp(cy, h / 2, math.max(ps.Y - h / 2, h / 2))
        main.Position = UDim2.fromScale(cx / ps.X, cy / ps.Y)
    end

    local function updateScale()
        local cam = workspace.CurrentCamera
        if not cam then
            return
        end
        local vp = cam.ViewportSize
        local fit = math.min((vp.X - 24) / math.max(size.X.Offset, 1), (vp.Y - 24) / math.max(size.Y.Offset, 1))
        local maxScale = math.clamp(fit, 0.25, 2)
        local s
        if windowObj.UserScale then
            s = math.min(windowObj.UserScale, maxScale)
        else
            s = math.min(opts.Scale or 1, fit)
            if mobile then
                s = s * RavineUI.MobileScale
            end
        end
        s = math.clamp(s, 0.25, 2)
        windowObj._targetScale = s
        RavineUI._uiScale = s
        uiScale.Scale = s
        clampToScreen()
    end
    windowObj._updateScale = updateScale
    updateScale()
    if workspace.CurrentCamera then
        Connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale)
    end

    -- ===== Resize-Ecke =====
    local resizeLayer
    if opts.Resizable ~= false then
        local CORNER = mobile and 34 or 24
        resizeLayer = Create("TextButton", {
            Name = "ResizeCorner",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.fromScale(1, 1),
            Size = UDim2.fromOffset(CORNER, CORNER),
            Text = "",
            AutoButtonColor = false,
            ZIndex = 70,
            Parent = main,
        })
        local dots = {}
        for _, p in ipairs({ { 10, 4 }, { 4, 10 }, { 10, 10 } }) do
            local d = Create("Frame", {
                BackgroundColor3 = Theme.SubText,
                BackgroundTransparency = 0.3,
                BorderSizePixel = 0,
                AnchorPoint = Vector2.new(1, 1),
                Position = UDim2.new(1, -p[1], 1, -p[2]),
                Size = UDim2.fromOffset(3, 3),
                ZIndex = 71,
                Parent = resizeLayer,
            })
            Corner(d, 2)
            table.insert(dots, d)
        end
        local function setHot(on)
            for _, d in ipairs(dots) do
                Tween(d, 0.12, { BackgroundColor3 = on and Theme.Accent or Theme.SubText })
            end
        end

        local dragging, anchors = false, nil
        resizeLayer.MouseEnter:Connect(function()
            if not dragging then
                setHot(true)
            end
        end)
        resizeLayer.MouseLeave:Connect(function()
            if not dragging then
                setHot(false)
            end
        end)
        resizeLayer.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                local p = main.AbsolutePosition
                anchors = { L = p.X, T = p.Y, off = CalibrateY(input, resizeLayer) }
                setHot(true)
            end
        end)
        Connect(UserInputService.InputChanged, function(input)
            if dragging and anchors and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local W, H = size.X.Offset, size.Y.Offset
                local ps = gui.AbsoluteSize
                local py = input.Position.Y + anchors.off
                local s = ((input.Position.X - anchors.L) / W + (py - anchors.T) / H) / 2
                local maxS = math.clamp(math.min((ps.X - 24) / W, (ps.Y - 24) / H), 0.25, 2)
                s = math.clamp(s, 0.25, maxS)
                local hw, hh = s * W / 2, s * H / 2
                local cx = math.clamp(anchors.L + hw, hw, math.max(ps.X - hw, hw))
                local cy = math.clamp(anchors.T + hh, hh, math.max(ps.Y - hh, hh))
                main.Position = UDim2.fromScale(cx / ps.X, cy / ps.Y)
                windowObj.UserScale = s
                windowObj._targetScale = s
                RavineUI._uiScale = s
                uiScale.Scale = s
            end
        end)
        Connect(UserInputService.InputEnded, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false
                setHot(false)
                local pct = math.floor(uiScale.Scale * 100 + 0.5)
                windowObj:SetScale(pct / 100, true)
                if windowObj._scaleSlider then
                    windowObj._scaleSlider.Set(pct)
                end
            end
        end)
    end

    closeBtn.MouseButton1Click:Connect(function()
        windowObj:CloseSearch()
        windowObj:_ClosePopover()
        main.Visible = false
    end)

    minBtn.MouseButton1Click:Connect(function()
        windowObj:CloseSearch()
        windowObj:_ClosePopover()
        windowObj.Minimized = not windowObj.Minimized
        if windowObj.Minimized then
            Tween(main, 0.22, { Size = UDim2.new(size.X.Scale, size.X.Offset, 0, HEADER_H) })
            task.delay(0.22, function()
                if windowObj.Minimized then
                    tabBar.Visible = false
                    content.Visible = false
                    if resizeLayer then
                        resizeLayer.Visible = false
                    end
                end
            end)
        else
            tabBar.Visible = true
            content.Visible = true
            if resizeLayer then
                resizeLayer.Visible = true
            end
            Tween(main, 0.22, { Size = size })
        end
    end)

    Connect(UserInputService.InputBegan, function(input, gpe)
        if gpe then
            return
        end
        if input.KeyCode == windowObj.ToggleKeybind then
            windowObj:Toggle()
        end
        if input.KeyCode == Enum.KeyCode.F and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            and main.Visible and windowObj._search then
            windowObj:ToggleSearch()
        end
    end)

    local wantButton = opts.ToggleButton
    if wantButton == nil then
        wantButton = mobile
    end
    if wantButton then
        local fb = Create("TextButton", {
            Name = "ToggleButton",
            BackgroundColor3 = Theme.Secondary,
            Position = UDim2.new(0, 16, 0.5, -26),
            Size = UDim2.fromOffset(52, 52),
            Text = "",
            AutoButtonColor = false,
            Parent = gui,
        })
        Corner(fb, 26)
        Stroke(fb, Theme.Border, 1)
        BorderGradient(Stroke(fb, Theme.Accent, 1.5))
        local fic = NewIcon(fb, logoSrc, customLogo and 30 or 22, customLogo and Color3.new(1, 1, 1) or Theme.Accent, "V")
        fic.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
        fic.Instance.Position = UDim2.fromScale(0.5, 0.5)
        local drag = MakeDraggable(fb, fb)
        fb.MouseButton1Click:Connect(function()
            if drag.Moved < 6 then
                windowObj:Toggle()
            end
        end)
        windowObj.ToggleButton = fb
    end

    return windowObj
end

-- ============ WINDOW METHODS ============
function Window:Toggle()
    TipHide()
    local main = self.Main
    if main.Visible then
        self:CloseSearch()
        self:_ClosePopover()
        local target = self._targetScale
        Tween(self.Scale, 0.14, { Scale = target * 0.94 })
        task.delay(0.14, function()
            if self.Scale and self.Scale.Parent then
                main.Visible = false
                self.Scale.Scale = self._targetScale
            end
        end)
    else
        local target = self._targetScale
        self.Scale.Scale = target * 0.94
        main.Visible = true
        Tween(self.Scale, 0.22, { Scale = target }, Enum.EasingStyle.Back)
    end
end

function Window:SetAvatarHidden(hidden)
    self.AvatarHidden = hidden and true or false
end

function Window:SetLogoSize(px)
    px = math.clamp(tonumber(px) or 32, 12, 44)
    self.Logo.Instance.Size = UDim2.fromOffset(px, px)
    local titleX = self._logoX + px + 12
    self.TitleHolder.Position = UDim2.new(0, titleX, 0, 0)
    self.TitleHolder.Size = UDim2.new(1, -(titleX + (self._reserve or 112)), 1, 0)
end

function Window:SetScale(scale, save)
    if scale then
        self.UserScale = math.clamp(tonumber(scale) or 1, 0.25, 2)
    else
        self.UserScale = nil
    end
    if self._updateScale then
        self._updateScale()
    end
    if save and self.UserScale then
        WriteSavedScale(self.Scale.Scale, RavineUI.IsMobile)
    end
end

function Window:GetScale()
    return self.Scale.Scale
end

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

function Window:OpenSearch(query)
    if self._search and not self.Minimized then
        self._search.SetOpen(true, query)
    end
end

function Window:CloseSearch()
    if self._search then
        self._search.SetOpen(false)
    end
end

function Window:ToggleSearch()
    if self._search and not self.Minimized then
        self._search.SetOpen(not self._search.IsOpen)
    end
end

function Window:IsSearchOpen()
    return self._search ~= nil and self._search.IsOpen
end

function Window:AddSearchEntry(entry)
    if self._search and type(entry) == "table" and entry.Tab then
        self._search.Add(entry)
    end
end

function Window:GetFeatureCount()
    local features, tabs, seen = 0, 0, {}
    if self._search then
        for _, e in ipairs(self._search.Entries) do
            if e.Type ~= "Tab" and e.Tab and not e.Tab._internal then
                features = features + 1
                if not seen[e.Tab] then
                    seen[e.Tab] = true
                    tabs = tabs + 1
                end
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

function Window:Notify(opts)
    RavineUI:Notify(opts)
end

function Window:Destroy()
    self.Alive = false
    self.Main:Destroy()
    if self.ToggleButton then
        self.ToggleButton:Destroy()
    end
end

-- ============ TABS ============
function Window:AddTab(name, icon)
    local tab = setmetatable({
        Name = name,
        Window = self,
        Icon = icon,
        Groupboxes = {},
    }, Tab)

    local textW = TextService:GetTextSize(name, 12, Theme.FontBold, Vector2.new(400, 20)).X
    local wOpen = 12 + 16 + 8 + math.ceil(textW) + 16
    local wClosed = 40

    local btn = Create("TextButton", {
        Name = name,
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(wClosed, 32),
        LayoutOrder = #self.Tabs + 1,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Parent = self.TabBar,
    })
    Corner(btn, 16)
    local strk = Stroke(btn, Theme.Accent, 1, 1)
    local ic = NewIcon(btn, icon, 16, Theme.SubText, string.upper(string.sub(name, 1, 1)))
    ic.Instance.AnchorPoint = Vector2.new(0, 0.5)
    ic.Instance.Position = UDim2.new(0, 12, 0.5, 0)
    local lbl = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(36, 0),
        Size = UDim2.new(1, -36, 1, 0),
        Font = Theme.FontBold,
        Text = name,
        TextColor3 = Theme.Accent,
        TextSize = 12,
        TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.None,
        Parent = btn,
    })

    local frame = Create("Frame", {
        Name = name .. "_Content",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        Parent = self.Content,
    })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 12),
        Parent = frame,
    })

    local function Column(nameStr, pos)
        local col = Create("ScrollingFrame", {
            Name = nameStr,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = pos,
            Size = UDim2.new(0.5, -6, 1, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Border,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Parent = frame,
        })
        Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10), Parent = col })
        Create("UIPadding", { PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 2), Parent = col })
        return col
    end

    tab.Button = btn
    tab.Frame = frame
    tab.Left = Column("Left", UDim2.new(0, 0, 0, 0))
    tab.Right = Column("Right", UDim2.new(0.5, 6, 0, 0))
    tab._btn, tab._stroke, tab._icon, tab._label = btn, strk, ic, lbl
    tab._wOpen, tab._wClosed = wOpen, wClosed

    btn.MouseEnter:Connect(function()
        if self.ActiveTab ~= tab then
            Tween(btn, 0.15, { BackgroundTransparency = 0.92 })
            TintIcon(ic, Theme.Text)
            if not RavineUI.IsMobile then
                TipShow(name, btn)
            end
        end
    end)
    btn.MouseLeave:Connect(function()
        TipHideFor(btn)
        if self.ActiveTab ~= tab then
            Tween(btn, 0.15, { BackgroundTransparency = 1 })
            TintIcon(ic, Theme.SubText)
        end
    end)
    btn.MouseButton1Click:Connect(function()
        TipHide()
        self:SelectTab(tab)
    end)

    table.insert(self.Tabs, tab)
    if self._search then
        self._search.Add({ Name = name, Type = "Tab", Tab = tab, Group = "" })
    end
    if not self.ActiveTab then
        self:SelectTab(tab)
    end
    return tab
end

function Tab:_SetActive(active)
    Tween(self._btn, 0.22, { Size = UDim2.fromOffset(active and self._wOpen or self._wClosed, 32) }, Enum.EasingStyle.Quint)
    Tween(self._btn, 0.2, { BackgroundTransparency = active and 0.86 or 1 })
    Tween(self._stroke, 0.2, { Transparency = active and 0.55 or 1 })
    Tween(self._label, 0.2, { TextTransparency = active and 0 or 1 })
    TintIcon(self._icon, active and Theme.Accent or Theme.SubText)
end

function Window:SelectTab(tab)
    if self._search then
        self._search.SetOpen(false)
    end
    self:_ClosePopover()
    if self.ActiveTab == tab then
        return
    end
    TipHide()
    for _, t in ipairs(self.Tabs) do
        t.Frame.Visible = false
        t:_SetActive(false)
    end
    self.ActiveTab = tab
    tab.Frame.Position = UDim2.fromOffset(0, 10)
    tab.Frame.Visible = true
    Tween(tab.Frame, 0.22, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint)
    tab:_SetActive(true)

    -- aktiven Tab in der Leiste ins Bild scrollen
    task.delay(0.25, function()
        local bar = self.TabBar
        if not (bar and bar.Parent and tab.Button and tab.Button.Parent) then
            return
        end
        local scale = math.max(self.Scale.Scale, 0.01)
        local rel = (tab.Button.AbsolutePosition.X - bar.AbsolutePosition.X) / scale + bar.CanvasPosition.X
        local barW = bar.AbsoluteSize.X / scale
        local maxX = math.max(bar.AbsoluteCanvasSize.X / scale - barW, 0)
        local target = math.clamp(rel - (barW - tab._wOpen) / 2, 0, maxX)
        Tween(bar, 0.25, { CanvasPosition = Vector2.new(target, 0) })
    end)
end

function Tab:AddLeftGroupbox(name, icon)
    return self:_AddGroupbox(name, icon, self.Left)
end

function Tab:AddRightGroupbox(name, icon)
    return self:_AddGroupbox(name, icon, self.Right)
end

function Tab:_AddGroupbox(name, icon, column)
    local box = setmetatable({
        Name = name,
        Tab = self,
        Column = column,
        _n = 0,
    }, Groupbox)

    local outer = Create("Frame", {
        Name = name .. "_Card",
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = #self.Groupboxes + 1,
        Parent = column,
    })
    Corner(outer, 14)
    Stroke(outer, Theme.Border, 1)
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = outer })

    local titleFrame = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 44),
        LayoutOrder = 1,
        Parent = outer,
    })
    local x = 14
    if icon then
        local tile = Create("Frame", {
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 0.86,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 12, 0.5, 0),
            Size = UDim2.fromOffset(26, 26),
            Parent = titleFrame,
        })
        Corner(tile, 8)
        local ic = NewIcon(tile, icon, 14, Theme.Accent, "")
        ic.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
        ic.Instance.Position = UDim2.fromScale(0.5, 0.5)
        x = 048
    end
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, x, 0, 0),
        Size = UDim2.new(1, -x - 12, 1, 0),
        Font = Theme.FontBold,
        Text = name,
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = titleFrame,
    })
    local line = Create("Frame", {
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        LayoutOrder = 2,
        Parent = outer,
    })
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.12, 0.2),
            NumberSequenceKeypoint.new(0.88, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = line,
    })

    local container = Create("Frame", {
        Name = "Container",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 3,
        Parent = outer,
    })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3), Parent = container })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8),
        Parent = container,
    })

    box.Frame = outer
    box.Outer = outer
    box.Container = container
    box.Scroll = container
    table.insert(self.Groupboxes, box)
    return box
end

-- ============ HOME TAB (Dashboard) ============
local HomeFile = "RavineUI/home.json"

local function ReadHomeData()
    local data = {}
    if not HasFS() then
        return data
    end
    pcall(function()
        if isfile(HomeFile) then
            local d = HttpService:JSONDecode(readfile(HomeFile))
            if type(d) == "table" then
                data = d
            end
        end
    end)
    return data
end

local function WriteHomeData(data)
    if not HasFS() then
        return
    end
    pcall(function()
        EnsureFolders()
        writefile(HomeFile, HttpService:JSONEncode(data))
    end)
end

local function GetPing()
    local ok, v = pcall(function()
        return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
    end)
    return ok and v or nil
end

local function GetExecutorName()
    local ok, name = pcall(function()
        return identifyexecutor()
    end)
    return (ok and name) or "Unknown executor"
end

local function JoinDiscord(invite)
    local code = invite:match("discord%.gg/([%w%-_]+)")
        or invite:match("discord%.com/invite/([%w%-_]+)")
        or invite
    Copy("https://discord.gg/" .. code)
    local req = (syn and syn.request) or request or http_request or (http and http.request)
    if req then
        pcall(req, {
            Url = "http://127.0.0.1:6463/rpc?v=1",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json", ["Origin"] = "https://discord.com" },
            Body = HttpService:JSONEncode({
                cmd = "INVITE_BROWSER",
                args = { code = code },
                nonce = HttpService:GenerateGUID(false),
            }),
        })
    end
    RavineUI:Notify({ Title = "Discord", Description = "Invite copied: discord.gg/" .. code, Icon = "circle-check" })
end

local function FetchServers(sort)
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100&excludeFullGames=true",
        game.PlaceId, sort
    )
    local ok, res = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if ok and type(res) == "table" and type(res.data) == "table" then
        return res.data
    end
    return nil
end

local function PickServer(mode)
    local list = FetchServers(mode == "lowest" and "Asc" or "Desc")
    if not list then
        return nil
    end
    local pool = {}
    for _, sv in ipairs(list) do
        if sv.id ~= game.JobId and sv.playing and sv.maxPlayers and sv.playing < sv.maxPlayers then
            table.insert(pool, sv)
        end
    end
    if #pool == 0 then
        return nil
    end
    if mode == "lowest" then
        return pool[1]
    end
    return pool[math.random(#pool)]
end

local function RejoinServer()
    if #Players:GetPlayers() <= 1 then
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    else
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
end

local GRAPH_BAR = Color3.fromRGB(62, 62, 76)

local function MakeGraph(parent, position, size, n)
    local holder = Create("Frame", { BackgroundTransparency = 1, Position = position, Size = size, Parent = parent })
    local bars, values = {}, {}
    for i = 1, n do
        values[i] = 0
        bars[i] = Create("Frame", {
            BackgroundColor3 = GRAPH_BAR,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new((i - 1) / n, 0, 1, 0),
            Size = UDim2.new(1 / n, -2, 0.08, 0),
            Parent = holder,
        }, true)
        Corner(bars[i], 2)
    end
    local api = {}
    function api.Push(v, color, minMax)
        table.remove(values, 1)
        table.insert(values, v)
        local maxV = minMax or 1
        for _, x in ipairs(values) do
            if x > maxV then
                maxV = x
            end
        end
        for i = 1, n do
            bars[i].Size = UDim2.new(1 / n, -2, math.max(values[i] / maxV, 0.08), 0)
            bars[i].BackgroundColor3 = (i == n) and color or GRAPH_BAR
        end
    end
    return api
end

local function HomeLabel(parent, props)
    props.BackgroundTransparency = 1
    props.Parent = parent
    props.Font = props.Font or Theme.Font
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    return Create("TextLabel", props)
end

local function HomeCard(parent, size, order)
    local f = Create("Frame", {
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0,
        Size = size,
        LayoutOrder = order or 0,
        Parent = parent,
    })
    Corner(f, 14)
    Stroke(f, Theme.Border, 1)
    return f
end

local function HomeChip(parent, order, icon, text, onClick)
    local btn = Create("TextButton", {
        BackgroundColor3 = Theme.Tertiary,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 26),
        LayoutOrder = order,
        Text = "",
        AutoButtonColor = false,
        Parent = parent,
    })
    Corner(btn, 13)
    local st = Stroke(btn, Theme.Border, 1)
    Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12), Parent = btn })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = btn,
    })
    local static = onClick == nil
    local base = static and Theme.Text or Theme.SubText
    local ic = NewIcon(btn, icon, 13, base, "•")
    ic.Instance.LayoutOrder = 1
    local lbl = Create("TextLabel", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 14),
        LayoutOrder = 2,
        Font = Theme.FontBold,
        Text = text,
        TextColor3 = base,
        TextSize = 11,
        Parent = btn,
    })
    local active, hovering = false, false
    local api = {}
    local function paint()
        local c = base
        if active then
            c = Theme.Accent
        elseif hovering and not static then
            c = Theme.Text
        end
        TintIcon(ic, c)
        Tween(lbl, 0.15, { TextColor3 = c })
        Tween(st, 0.15, { Color = (active or (hovering and not static)) and Theme.Accent or Theme.Border })
    end
    btn.MouseEnter:Connect(function()
        hovering = true
        paint()
    end)
    btn.MouseLeave:Connect(function()
        hovering = false
        paint()
    end)
    api.SetActive = function(v)
        active = v and true or false
        paint()
    end
    if onClick then
        btn.MouseButton1Click:Connect(onClick)
    end
    return api
end

local function HomeTile(parent, order, icon, text, onClick)
    local btn = Create("TextButton", {
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0,
        Size = UDim2.new(0.25, -6, 1, 0),
        LayoutOrder = order,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Parent = parent,
    })
    Corner(btn, 14)
    local st = Stroke(btn, Theme.Border, 1)
    local fillF = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Parent = btn,
    }, true)
    AccentGradient(fillF, 25)
    local holder = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = btn })
    Create("UIListLayout", {
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
        Parent = holder,
    })
    local ic = NewIcon(holder, icon, 17, Theme.SubText, "•")
    ic.Instance.LayoutOrder = 1
    local lbl = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -8, 0, 14),
        LayoutOrder = 2,
        Font = Theme.Font,
        Text = text,
        TextColor3 = Theme.SubText,
        TextSize = 11,
        Parent = holder,
    })
    btn.MouseEnter:Connect(function()
        Tween(fillF, 0.18, { BackgroundTransparency = 0.2 })
        Tween(st, 0.18, { Color = Theme.Accent })
        TintIcon(ic, Color3.new(1, 1, 1))
        Tween(lbl, 0.18, { TextColor3 = Color3.new(1, 1, 1) })
    end)
    btn.MouseLeave:Connect(function()
        Tween(fillF, 0.18, { BackgroundTransparency = 1 })
        Tween(st, 0.18, { Color = Theme.Border })
        TintIcon(ic, Theme.SubText)
        Tween(lbl, 0.18, { TextColor3 = Theme.SubText })
    end)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Ripple(btn, input.Position.X)
        end
    end)
    btn.MouseButton1Click:Connect(function()
        task.spawn(onClick)
    end)
    return btn
end

local function HomeLink(parent, order, icon, title, desc, onClick)
    local row = Create("TextButton", {
        BackgroundColor3 = Theme.Tertiary,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -4, 0, 46),
        LayoutOrder = order,
        Text = "",
        AutoButtonColor = false,
        Parent = parent,
    })
    Corner(row, 10)
    local tile = Create("Frame", {
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.88,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 8, 0.5, 0),
        Size = UDim2.fromOffset(30, 30),
        Parent = row,
    })
    Corner(tile, 9)
    local ic = NewIcon(tile, icon, 15, Theme.Accent, "•")
    ic.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    ic.Instance.Position = UDim2.fromScale(0.5, 0.5)
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 48, 0, 7),
        Size = UDim2.new(1, -90, 0, 16),
        Font = Theme.FontBold,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    local descLbl = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 48, 0, 24),
        Size = UDim2.new(1, -90, 0, 14),
        Font = Theme.Font,
        Text = desc or "",
        TextColor3 = Theme.SubText,
        TextSize = 10,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    local chev = NewIcon(row, "chevron-right", 14, Theme.SubText, ">")
    chev.Instance.AnchorPoint = Vector2.new(1, 0.5)
    chev.Instance.Position = UDim2.new(1, -12, 0.5, 0)
    row.MouseEnter:Connect(function()
        Tween(row, 0.12, { BackgroundTransparency = 0.5 })
        TintIcon(chev, Theme.Accent)
    end)
    row.MouseLeave:Connect(function()
        Tween(row, 0.12, { BackgroundTransparency = 1 })
        TintIcon(chev, Theme.SubText)
    end)
    row.MouseButton1Click:Connect(function()
        task.spawn(onClick)
    end)
    return {
        SetDesc = function(text)
            descLbl.Text = text
        end,
    }
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
    local prefs = { HideName = data.HideName == true, HideAvatar = data.HideAvatar == true }
    local function saveData()
        data.HideName = prefs.HideName
        data.HideAvatar = prefs.HideAvatar
        WriteHomeData(data)
    end

    local page = Create("ScrollingFrame", {
        Name = "HomePage",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Border,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = tab.Frame,
    })
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10), Parent = page })
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 2),
        PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
        Parent = page,
    })

    -- ===== Hero =====
    local hero = HomeCard(page, UDim2.new(1, 0, 0, 126), 1)
    hero.ClipsDescendants = true
    local heroGlow = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Parent = hero,
    }, true)
    local gg = AccentGradient(heroGlow, 30)
    gg.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.7),
        NumberSequenceKeypoint.new(0.6, 0.94),
        NumberSequenceKeypoint.new(1, 1),
    })

    HomeLabel(hero, {
        Position = UDim2.new(0, 22, 0, 16),
        Size = UDim2.new(1, -170, 0, 12),
        Text = string.upper(opts.Greeting or "Welcome back"),
        TextColor3 = Theme.SubText,
        TextSize = 10,
    })
    local nameLabel = HomeLabel(hero, {
        Position = UDim2.new(0, 22, 0, 29),
        Size = UDim2.new(1, -170, 0, 30),
        Font = Theme.FontBold,
        Text = LocalPlayer.DisplayName,
        TextColor3 = Theme.Text,
        TextSize = 26,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local userLabel = HomeLabel(hero, {
        Position = UDim2.new(0, 22, 0, 61),
        Size = UDim2.new(1, -170, 0, 14),
        Text = "@" .. LocalPlayer.Name,
        TextColor3 = Theme.SubText,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local avatar = Create("ImageLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -12, 1, 14),
        Size = UDim2.fromOffset(120, 120),
        ScaleType = Enum.ScaleType.Fit,
        Parent = hero,
    })
    local avatarHidden = Create("Frame", {
        BackgroundColor3 = Theme.Tertiary,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -30, 0.5, 0),
        Size = UDim2.fromOffset(66, 66),
        Visible = false,
        Parent = hero,
    })
    Corner(avatarHidden, 33)
    Stroke(avatarHidden, Theme.Border, 1)
    local hiddenIc = NewIcon(avatarHidden, "eye-off", 22, Theme.SubText, "?")
    hiddenIc.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
    hiddenIc.Instance.Position = UDim2.fromScale(0.5, 0.5)
    task.spawn(function()
        local ok, url = pcall(Players.GetUserThumbnailAsync, Players, LocalPlayer.UserId,
            Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size180x180)
        if avatar.Parent and ok and url then
            avatar.Image = url
        end
    end)

    local chips = Create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 22, 0, 86),
        Size = UDim2.new(1, -170, 0, 26),
        Parent = hero,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = chips,
    })
    local nameChip, avatarChip
    local function applyPrivacy()
        nameLabel.Text = prefs.HideName and "Hidden" or LocalPlayer.DisplayName
        userLabel.Text = prefs.HideName and "@hidden" or ("@" .. LocalPlayer.Name)
        avatar.Visible = not prefs.HideAvatar
        avatarHidden.Visible = prefs.HideAvatar
        self:SetAvatarHidden(prefs.HideAvatar)
        if nameChip then
            nameChip.SetActive(prefs.HideName)
        end
        if avatarChip then
            avatarChip.SetActive(prefs.HideAvatar)
        end
    end
    if opts.Badge ~= false then
        HomeChip(chips, 1, opts.BadgeIcon or "swords", opts.Badge or "Beta", nil)
    end
    nameChip = HomeChip(chips, 2, "eye-off", "Name", function()
        prefs.HideName = not prefs.HideName
        applyPrivacy()
        saveData()
    end)
    avatarChip = HomeChip(chips, 3, "user-round", "Avatar", function()
        prefs.HideAvatar = not prefs.HideAvatar
        applyPrivacy()
        saveData()
    end)
    applyPrivacy()

    -- ===== Stats =====
    local statsRow = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 92),
        LayoutOrder = 2,
        Parent = page,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = statsRow,
    })
    local BARS = 18
    local function StatCard(order, icon, title, withGraph)
        local card = HomeCard(statsRow, UDim2.new(0.25, -6, 1, 0), order)
        local ic = NewIcon(card, icon, 12, Theme.SubText, "")
        ic.Instance.Position = UDim2.fromOffset(12, 11)
        HomeLabel(card, {
            Position = UDim2.fromOffset(30, 10),
            Size = UDim2.new(1, -40, 0, 14),
            Text = title,
            TextColor3 = Theme.SubText,
            TextSize = 10,
        })
        local value = HomeLabel(card, {
            Position = UDim2.fromOffset(12, 26),
            Size = UDim2.new(1, -24, 0, 26),
            Font = Theme.FontBold,
            Text = "-",
            TextColor3 = Theme.Text,
            TextSize = 21,
        })
        local graph
        if withGraph then
            graph = MakeGraph(card, UDim2.fromOffset(12, 58), UDim2.new(1, -24, 0, 24), BARS)
        end
        return value, graph
    end
    local fpsValue, fpsGraph = StatCard(1, "gauge", "FPS", true)
    local pingValue, pingGraph = StatCard(2, "wifi", "PING", true)
    local playersValue = StatCard(3, "users", "PLAYERS", false)
    local sessionValue = StatCard(4, "clock", "SESSION", false)

    -- ===== Quick Actions =====
    local actions = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 64),
        LayoutOrder = 3,
        Parent = page,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = actions,
    })
    local busy = false
    local function teleportTo(mode)
        if busy then
            return
        end
        busy = true
        RavineUI:Notify({
            Title = mode == "lowest" and "Lowest server" or "Server hop",
            Description = "Searching for a server...",
            Icon = "search",
        })
        local server = PickServer(mode)
        if not server then
            busy = false
            RavineUI:Notify({ Title = "No server found", Description = "Try again in a moment", Icon = "triangle-alert" })
            return
        end
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
        end)
        if not ok then
            RavineUI:Notify({ Title = "Teleport failed", Description = "Could not join that server", Icon = "triangle-alert" })
        end
        task.delay(4, function()
            busy = false
        end)
    end
    HomeTile(actions, 1, "refresh-cw", "Rejoin", function()
        RavineUI:Notify({ Title = "Rejoin", Description = "Rejoining this server...", Icon = "refresh-cw" })
        pcall(RejoinServer)
    end)
    HomeTile(actions, 2, "shuffle", "Hop", function()
        teleportTo("random")
    end)
    HomeTile(actions, 3, "users", "Lowest", function()
        teleportTo("lowest")
    end)
    HomeTile(actions, 4, "copy", "Job ID", function()
        local ok = Copy(game.JobId)
        RavineUI:Notify({
            Title = ok and "Copied" or "Copy failed",
            Description = ok and "Job ID copied to clipboard" or "Your executor has no clipboard function",
            Icon = ok and "copy" or "triangle-alert",
        })
    end)

    -- ===== Links + Server =====
    local lower = Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 188),
        LayoutOrder = 4,
        Parent = page,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = lower,
    })

    local linkCard = HomeCard(lower, UDim2.new(0.5, -4, 1, 0), 1)
    HomeLabel(linkCard, {
        Position = UDim2.fromOffset(16, 12),
        Size = UDim2.new(1, -32, 0, 12),
        Text = "LINKS",
        TextColor3 = Theme.SubText,
        TextSize = 10,
    })
    local linkList = Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 8, 0, 32),
        Size = UDim2.new(1, -16, 1, -40),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Border,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = linkCard,
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
    if opts.Discord and opts.Discord ~= "" then
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
                for k, v in pairs(cl) do
                    if k ~= "OnClose" then
                        copy[k] = v
                    end
                end
                RavineUI:ShowChangelog(copy)
            end)
    end
    for _, l in ipairs(opts.Links or {}) do
        linkOrder = linkOrder + 1
        HomeLink(linkList, linkOrder, l.Icon or "link", l.Name or "Link", l.Description or l.Url or "", function()
            if l.Callback then
                task.spawn(l.Callback)
            elseif l.Url then
                local ok = Copy(l.Url)
                RavineUI:Notify({
                    Title = ok and "Link copied" or "Copy failed",
                    Description = ok and l.Url or "Your executor has no clipboard function",
                    Icon = ok and "link" or "triangle-alert",
                })
            end
        end)
    end

    local serverCard = HomeCard(lower, UDim2.new(0.5, -4, 1, 0), 2)
    local thumb = Create("ImageLabel", {
        BackgroundColor3 = Theme.Tertiary,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(14, 14),
        Size = UDim2.fromOffset(42, 42),
        ScaleType = Enum.ScaleType.Crop,
        Image = string.format("rbxthumb://type=GameIcon&id=%d&w=150&h=150", game.GameId),
        Parent = serverCard,
    })
    Corner(thumb, 10)
    Stroke(thumb, Theme.Border, 1)
    local gameName = HomeLabel(serverCard, {
        Position = UDim2.new(0, 66, 0, 15),
        Size = UDim2.new(1, -78, 0, 18),
        Font = Theme.FontBold,
        Text = "Loading...",
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local gameSub = HomeLabel(serverCard, {
        Position = UDim2.new(0, 66, 0, 35),
        Size = UDim2.new(1, -78, 0, 14),
        Text = "",
        TextColor3 = Theme.SubText,
        TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local creatorName = ""
    task.spawn(function()
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfo(game.PlaceId)
        end)
        if ok and type(info) == "table" then
            gameName.Text = tostring(info.Name or "Unknown game")
            creatorName = info.Creator and tostring(info.Creator.Name) or ""
        else
            gameName.Text = "Unknown game"
        end
    end)

    local jobId = game.JobId
    local jobShort = jobId == "" and "-" or (#jobId > 14 and (jobId:sub(1, 8) .. ".." .. jobId:sub(-4)) or jobId)
    HomeLabel(serverCard, {
        Position = UDim2.new(0, 14, 0, 68),
        Size = UDim2.new(1, -28, 0, 14),
        Text = "Job  " .. jobShort,
        TextColor3 = Theme.SubText,
        TextSize = 11,
    })
    HomeLabel(serverCard, {
        Position = UDim2.new(0, 14, 0, 86),
        Size = UDim2.new(1, -28, 0, 14),
        Text = "Place  " .. tostring(game.PlaceId),
        TextColor3 = Theme.SubText,
        TextSize = 11,
    })
    local sepLine = Create("Frame", {
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 14, 0, 110),
        Size = UDim2.new(1, -28, 0, 1),
        Parent = serverCard,
    })
    local required = opts.RequiredFunctions or { "loadstring" }
    local supported = true
    local env = (getgenv and getgenv()) or _G
    for _, fn in ipairs(required) do
        if env[fn] == nil then
            supported = false
            break
        end
    end
    local dot = Create("Frame", {
        BackgroundColor3 = supported and Theme.Success or Theme.Warning,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 14, 0, 124),
        Size = UDim2.fromOffset(8, 8),
        Parent = serverCard,
    })
    Corner(dot, 4)
    HomeLabel(serverCard, {
        Position = UDim2.new(0, 30, 0, 119),
        Size = UDim2.new(1, -44, 0, 18),
        Font = Theme.FontBold,
        Text = GetExecutorName(),
        TextColor3 = Theme.Text,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    HomeLabel(serverCard, {
        Position = UDim2.new(0, 14, 0, 140),
        Size = UDim2.new(1, -28, 0, 14),
        Text = supported and "Your executor is fully supported." or "Your executor might not support everything.",
        TextColor3 = Theme.SubText,
        TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local hideLbl = HomeLabel(serverCard, {
        Position = UDim2.new(0, 14, 0, 160),
        Size = UDim2.new(1, -28, 0, 14),
        Text = "Hide / show with  " .. ShortKey(self.ToggleKeybind.Name),
        TextColor3 = Theme.SubText,
        TextSize = 11,
    })

    -- ===== Live-Update =====
    local frames, lastT = 0, os.clock()
    Connect(RunService.Heartbeat, function()
        frames = frames + 1
    end)
    local startClock = os.clock()
    local lastFeatureText = ""

    local function quality(val, goodAt, okAt, higherIsBetter)
        local good, ok
        if higherIsBetter then
            good, ok = val >= goodAt, val >= okAt
        else
            good, ok = val <= goodAt, val <= okAt
        end
        if good then
            return Theme.Success
        elseif ok then
            return Theme.Warning
        end
        return Theme.Danger
    end

    local function refresh()
        local now = os.clock()
        local dt = now - lastT
        local fps = dt > 0 and math.floor(frames / dt + 0.5) or 0
        frames = 0
        lastT = now
        local fc = quality(fps, 50, 30, true)
        fpsValue.Text = tostring(fps)
        fpsValue.TextColor3 = fc
        fpsGraph.Push(fps, fc, 120)
        local ping = GetPing()
        local pc = quality(ping or 999, 80, 150, false)
        pingValue.Text = ping and (ping .. "ms") or "N/A"
        pingValue.TextColor3 = pc
        pingGraph.Push(ping or 0, pc, 150)
        playersValue.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
        sessionValue.Text = FormatSession(now - startClock)
        gameSub.Text = (creatorName ~= "" and ("by " .. creatorName .. "  ·  ") or "")
            .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers .. " players"
        hideLbl.Text = "Hide / show with  " .. ShortKey(self.ToggleKeybind.Name)
        if featureRow then
            local f, t = self:GetFeatureCount()
            local text = f .. (f == 1 and " feature" or " features") .. " across " .. Plural(t, "tab")
            if text ~= lastFeatureText then
                lastFeatureText = text
                featureRow.SetDesc(text)
            end
        end
    end
    task.spawn(function()
        while self.Alive and not RavineUI.Unloaded do
            pcall(refresh)
            task.wait(0.5)
        end
    end)
    tab.Refresh = function()
        pcall(refresh)
    end
    return tab
end

-- Alte Home-Seite gibt es hier nicht extra: gleicher Aufruf, gleiches Dashboard
Window.AddHomeTabClassic = Window.AddHomeTab

-- ============ APPEARANCE / SETTINGS ============
function Window:AddAppearanceBox(tab, right)
    local look = right and tab:AddRightGroupbox("Appearance", "palette") or tab:AddLeftGroupbox("Appearance", "palette")

    if not self._scaleSlider then
        local scaleToken = 0
        self._scaleSlider = look:AddSlider("RavineUI_Scale", {
            Text = "UI scale",
            Min = 40,
            Max = math.max(50, math.min(200, math.floor(self:GetMaxScale() * 100))),
            Default = math.floor(self.Scale.Scale * 100 + 0.5),
            Rounding = 0,
            Suffix = "%",
            Callback = function(v)
                scaleToken += 1
                local token = scaleToken
                task.delay(0.25, function()
                    if token == scaleToken then
                        self:SetScale(v / 100, true)
                    end
                end)
            end,
        })
    end

    local ts = RavineUI.ThemeState
    local syncing = false
    local picker
    local names = RavineUI:GetThemeNames()
    table.insert(names, "Custom")

    local presetDD = look:AddDropdown("RavineUI_ThemePreset", {
        Text = "Theme",
        Values = names,
        Default = ts.Preset,
        Search = false,
        Callback = function(name)
            if syncing then
                return
            end
            if name ~= "Custom" then
                RavineUI:SetTheme(name)
                syncing = true
                if picker then
                    picker.Set(ts.Accent)
                end
                syncing = false
            else
                ts.Preset = "Custom"
            end
            RavineUI:_QueueThemeSave()
        end,
    })

    picker = look:AddColorPicker("RavineUI_AccentColor", {
        Text = "Accent color",
        Default = ts.Accent,
        Keywords = "color colour theme custom",
        Callback = function(c)
            if syncing then
                return
            end
            ts.Preset = "Custom"
            RavineUI:SetAccent(c)
            syncing = true
            presetDD.Set("Custom")
            syncing = false
            RavineUI:_QueueThemeSave()
        end,
    })

    look:AddToggle("RavineUI_Rainbow", {
        Text = "Rainbow accent",
        Default = ts.Rainbow,
        Keywords = "rgb animated color",
        Callback = function(v)
            RavineUI:SetRainbow(v)
        end,
    })
    look:AddSlider("RavineUI_RainbowSpeed", {
        Text = "Rainbow speed",
        Min = 2,
        Max = 100,
        Default = math.clamp(math.floor(ts.RainbowSpeed * 100 + 0.5), 2, 100),
        Rounding = 0,
        Suffix = "%",
        Callback = function(v)
            ts.RainbowSpeed = v / 100
            RavineUI:_QueueThemeSave()
        end,
    })
    look:AddToggle("RavineUI_AnimBorder", {
        Text = "Animated border",
        Default = ts.AnimBorder,
        Keywords = "glow gradient outline",
        Callback = function(v)
            RavineUI:SetBorderAnimated(v)
        end,
    })
    look:AddSlider("RavineUI_Transparency", {
        Text = "Window transparency",
        Min = 0,
        Max = 60,
        Default = math.clamp(math.floor(ts.Transparency * 100 + 0.5), 0, 60),
        Rounding = 0,
        Suffix = "%",
        Keywords = "opacity see through",
        Callback = function(v)
            self:SetTransparency(v / 100)
        end,
    })
    return look
end

function Window:AddSettingsTab(opts)
    opts = opts or {}
    local tab = self:AddTab(opts.Name or "Settings", opts.Icon or "settings")
    tab._internal = true

    local menu = tab:AddLeftGroupbox("Menu", "layout-dashboard")
    if not RavineUI.IsMobile then
        local keybind = menu:AddKeyPicker("RavineUI_MenuKey", {
            Text = "Menu keybind",
            Default = self.ToggleKeybind.Name,
        })
        keybind:OnChanged(function(keyName)
            local ok, key = pcall(function()
                return Enum.KeyCode[keyName]
            end)
            if ok and key then
                self.ToggleKeybind = key
            end
        end)
    end

    local scaleToken = 0
    self._scaleSlider = menu:AddSlider("RavineUI_Scale", {
        Text = "UI scale",
        Min = 40,
        Max = math.max(50, math.min(200, math.floor(self:GetMaxScale() * 100))),
        Default = math.floor(self.Scale.Scale * 100 + 0.5),
        Rounding = 0,
        Suffix = "%",
        Callback = function(v)
            scaleToken += 1
            local token = scaleToken
            task.delay(0.25, function()
                if token == scaleToken then
                    self:SetScale(v / 100, true)
                end
            end)
        end,
    })
    menu:AddButton("Unload UI", {
        Icon = "power",
        Callback = function()
            RavineUI:Unload()
        end,
    })

    self:AddAppearanceBox(tab)

    local cfg = tab:AddRightGroupbox("Config", "save")
    local nameBox = cfg:AddTextbox("RavineUI_ConfigName", { Text = "Config name", Placeholder = "default" })
    local list = cfg:AddDropdown("RavineUI_ConfigList", { Text = "Configs", Values = RavineUI:ListConfigs() })
    local function currentName()
        local n = nameBox.Get()
        if n == "" then
            n = list.Get()
        end
        return n
    end
    cfg:AddButton("Save config", {
        Icon = "save",
        Callback = function()
            local n = currentName()
            local ok, info = RavineUI:SaveConfig(n)
            RavineUI:Notify({
                Title = ok and "Config saved" or "Save failed",
                Description = ok and n or tostring(info),
                Icon = ok and "circle-check" or "triangle-alert",
            })
            list.Refresh(RavineUI:ListConfigs())
        end,
    })
    cfg:AddButton("Load config", {
        Icon = "folder",
        Callback = function()
            local n = currentName()
            local ok, info = RavineUI:LoadConfig(n)
            RavineUI:Notify({
                Title = ok and "Config loaded" or "Load failed",
                Description = ok and n or tostring(info),
                Icon = ok and "circle-check" or "triangle-alert",
            })
        end,
    })
    cfg:AddButton("Refresh list", {
        Icon = "refresh-cw",
        Callback = function()
            list.Refresh(RavineUI:ListConfigs())
        end,
    })
    return tab
end

-- ============ INIT ============
return RavineUI
