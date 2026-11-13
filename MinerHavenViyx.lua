--[[
    MINER'S HAVEN BY VIYX  |  1.5  (November 2026)
    Maintainer: Viyx
    Source base: MinerHavenViyx.lua
    Gameplay/reference integration: MX6Share.txt (MX6 & A4; credit retained)
    New self-contained purple / charcoal GUI, no external UI downloads.
    Hotkey: K (toggle hub), or on-screen V button when minimized.

    Changes: removed Settings, NPC Teleport, Halloween tabs;
    important threshold settings are available under Auto Section.
    This script uses client-side game/executor APIs and cannot be
    validated against live Roblox server behavior by an offline test.
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players             = game:GetService("Players")
local RS                  = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser         = game:GetService("VirtualUser")
local LocalPlayer         = Players.LocalPlayer or Players.PlayerAdded:Wait()

----------------------------------------------------------------------
-- Hub: lets you inject the script again without duplicate loops/menus
----------------------------------------------------------------------
local ENV = (getgenv and getgenv()) or _G
local HUB_KEY = "Viyx_MinersHavenHub"
if type(ENV[HUB_KEY]) == "table" and type(ENV[HUB_KEY].Unload) == "function" then
    pcall(ENV[HUB_KEY].Unload)
    task.wait(0.2)
end
local Hub = { Alive = true, Cleanups = {}, Conns = {} }
ENV[HUB_KEY] = Hub

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Hub.Conns, c)
    return c
end

local function httpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and #body > 0 then return body end
    local req = request or http_request or (syn and syn.request)
    if req then
        local okReq, res = pcall(req, { Url = url, Method = "GET" })
        if okReq and type(res) == "table" and type(res.Body) == "string" then return res.Body end
    end
    error("HTTP request failed for " .. url)
end

-- ================================================================
-- VIYX UI 1.5 | Self-contained, two-column purple/black dashboard
-- Compatible with the Rayfield CreateTab/CreateToggle/etc. API used
-- by the Viyx gameplay modules.  No remote UI library is executed.
-- ================================================================
local Rayfield = (function()
    local UI = { Window = nil }
    local UIS = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local P = {
        bg = Color3.fromRGB(13, 12, 21), panel = Color3.fromRGB(22, 20, 33),
        side = Color3.fromRGB(17, 16, 27), card = Color3.fromRGB(29, 26, 43),
        field = Color3.fromRGB(37, 33, 54), hover = Color3.fromRGB(44, 37, 66),
        border = Color3.fromRGB(59, 49, 82), accent = Color3.fromRGB(164, 108, 255),
        accentDim = Color3.fromRGB(72, 49, 108), text = Color3.fromRGB(244, 239, 255),
        muted = Color3.fromRGB(160, 151, 180), good = Color3.fromRGB(119, 222, 166),
    }
    local function new(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props or {}) do o[k] = v end
        if parent then o.Parent = parent end
        return o
    end
    local function round(parent, r)
        return new("UICorner", { CornerRadius = UDim.new(0, r or 9) }, parent)
    end
    local function outline(parent, color, weight)
        return new("UIStroke", { Color = color or P.border, Thickness = weight or 1,
            Transparency = 0.12, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
    end
    local function pad(parent, top, right, bottom, left)
        return new("UIPadding", { PaddingTop = UDim.new(0, top or 0),
            PaddingRight = UDim.new(0, right or 0), PaddingBottom = UDim.new(0, bottom or 0),
            PaddingLeft = UDim.new(0, left or 0) }, parent)
    end
    local function txt(parent, value, size, color, bold, extra)
        local cfg = { BackgroundTransparency = 1, Text = tostring(value or ""),
            Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
            TextSize = size or 13, TextColor3 = color or P.text,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
            BorderSizePixel = 0 }
        for k, v in pairs(extra or {}) do cfg[k] = v end
        return new("TextLabel", cfg, parent)
    end
    local function tw(obj, props, seconds)
        if obj and obj.Parent then
            TweenService:Create(obj, TweenInfo.new(seconds or 0.16, Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out), props):Play()
        end
    end
    local function safeCall(fn, ...)
        if type(fn) ~= "function" then return end
        local ok, err = pcall(fn, ...)
        if not ok then warn("[Viyx UI] Callback:", err) end
    end
    local function binding(signal, fn)
        local c = signal:Connect(fn)
        table.insert(Hub.Conns, c)
        return c
    end

    function UI:Notify(data)
        local w = self.Window
        if not (w and w.Screen and w.Screen.Parent) then
            warn("[Viyx] " .. tostring(data.Title or "Info") .. ": " .. tostring(data.Content or ""))
            return
        end
        local holder = w.Notifications
        local toast = new("Frame", { BackgroundColor3 = P.card, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 82) }, holder)
        round(toast, 10); outline(toast, P.accentDim)
        new("Frame", { Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(8, 8),
            BorderSizePixel = 0, BackgroundColor3 = P.accent }, toast)
        txt(toast, data.Title or "Viyx", 13, P.text, true, {
            Position = UDim2.fromOffset(21, 8), Size = UDim2.new(1, -30, 0, 20) })
        txt(toast, data.Content or "", 11, P.muted, false, {
            Position = UDim2.fromOffset(21, 29), Size = UDim2.new(1, -32, 1, -34),
            TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
        task.delay(math.clamp(tonumber(data.Duration) or 5, 2, 30), function()
            if toast.Parent then toast:Destroy() end
        end)
    end
    function UI:Destroy()
        if self.Window and self.Window.Screen then self.Window.Screen:Destroy() end
        self.Window = nil
    end
    function UI:LoadConfiguration() end

    function UI:CreateWindow(conf)
        self:Destroy()
        local parent = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
        if type(gethui) == "function" then
            local ok, gui = pcall(gethui)
            if ok and gui then parent = gui end
        end
        local screen = new("ScreenGui", { Name = "ViyxMinerHaven15", ResetOnSpawn = false,
            DisplayOrder = 175, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            IgnoreGuiInset = true }, parent)
        local surface = new("Frame", { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1010, 670),
            BorderSizePixel = 0, BackgroundColor3 = P.bg, ClipsDescendants = true }, screen)
        round(surface, 13); outline(surface, P.border, 1.25)
        local scale = new("UIScale", { Scale = 1 }, surface)
        local function rescale()
            local camera = workspace.CurrentCamera
            local v = camera and camera.ViewportSize or Vector2.new(1200, 800)
            scale.Scale = math.clamp(math.min((v.X - 16) / 1010, (v.Y - 16) / 670), 0.45, 1.0)
        end
        rescale()
        if workspace.CurrentCamera then
            binding(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), rescale)
        end
        local side = new("Frame", { BackgroundColor3 = P.side, BorderSizePixel = 0,
            Size = UDim2.new(0, 205, 1, 0) }, surface)
        new("Frame", { Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0),
            BackgroundColor3 = P.border, BorderSizePixel = 0 }, side)
        local logo = new("Frame", { BackgroundTransparency = 1,
            Position = UDim2.fromOffset(18, 20), Size = UDim2.new(1, -30, 0, 54) }, side)
        local emblem = new("Frame", { Size = UDim2.fromOffset(34, 34),
            Position = UDim2.fromOffset(0, 2), BackgroundColor3 = P.accentDim,
            BorderSizePixel = 0 }, logo)
        round(emblem, 10)
        txt(emblem, "V", 19, P.text, true, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
        txt(logo, "VIYX", 17, P.text, true, {
            Position = UDim2.fromOffset(45, 0), Size = UDim2.new(1, -48, 0, 26) })
        txt(logo, "MINER'S HAVEN", 9, P.muted, true, {
            Position = UDim2.fromOffset(45, 24), Size = UDim2.new(1, -46, 0, 18) })
        new("Frame", { Position = UDim2.fromOffset(16, 83), Size = UDim2.new(1, -32, 0, 1),
            BackgroundColor3 = P.border, BorderSizePixel = 0 }, side)
        local nav = new("ScrollingFrame", { Name = "Navigation", BackgroundTransparency = 1,
            BorderSizePixel = 0, Position = UDim2.fromOffset(8, 101), Size = UDim2.new(1, -16, 1, -166),
            ScrollBarThickness = 2, ScrollBarImageColor3 = P.accentDim,
            CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y }, side)
        pad(nav, 4, 5, 12, 5)
        new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, nav)
        local footer = new("Frame", { Position = UDim2.new(0, 12, 1, -57),
            Size = UDim2.new(1, -24, 0, 43), BackgroundColor3 = P.card,
            BorderSizePixel = 0 }, side)
        round(footer, 8)
        txt(footer, "VIYX  /  v1.5", 11, P.text, true, {
            Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 17) })
        txt(footer, "MX6 + A4 acknowledged", 9, P.muted, false, {
            Position = UDim2.fromOffset(10, 23), Size = UDim2.new(1, -20, 0, 14) })

        local right = new("Frame", { Position = UDim2.fromOffset(205, 0),
            Size = UDim2.new(1, -205, 1, 0), BackgroundTransparency = 1 }, surface)
        local bar = new("Frame", { BackgroundColor3 = P.panel, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 65) }, right)
        txt(bar, "Dashboard", 18, P.text, true, { Name = "PageTitle",
            Position = UDim2.fromOffset(22, 9), Size = UDim2.new(1, -175, 0, 27) })
        txt(bar, "Miners Haven automation  •  Viyx Edition", 10, P.muted, false, {
            Position = UDim2.fromOffset(22, 36), Size = UDim2.new(1, -175, 0, 16) })
        local version = new("TextLabel", { Text = "v1.5", Font = Enum.Font.GothamBold,
            TextSize = 11, TextColor3 = P.accent, TextXAlignment = Enum.TextXAlignment.Center,
            BackgroundColor3 = P.accentDim, BorderSizePixel = 0,
            Position = UDim2.new(1, -120, 0, 17), Size = UDim2.fromOffset(45, 28) }, bar)
        round(version, 7)
        local minimize = new("TextButton", { Text = "—", Font = Enum.Font.GothamBold,
            TextSize = 18, TextColor3 = P.muted, BackgroundTransparency = 1,
            Position = UDim2.new(1, -72, 0, 16), Size = UDim2.fromOffset(30, 30) }, bar)
        local close = new("TextButton", { Text = "×", Font = Enum.Font.GothamBold,
            TextSize = 21, TextColor3 = P.muted, BackgroundTransparency = 1,
            Position = UDim2.new(1, -39, 0, 16), Size = UDim2.fromOffset(30, 30) }, bar)
        new("Frame", { Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 1),
            BorderSizePixel = 0, BackgroundColor3 = P.border }, bar)
        local pages = new("Frame", { Position = UDim2.fromOffset(0, 65),
            Size = UDim2.new(1, 0, 1, -65), BackgroundTransparency = 1 }, right)
        local notifications = new("Frame", { Name = "Notifications", AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(300, 0),
            AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, screen)
        new("UIListLayout", { Padding = UDim.new(0, 7), VerticalAlignment = Enum.VerticalAlignment.Bottom,
            SortOrder = Enum.SortOrder.LayoutOrder }, notifications)

        local launcher = new("TextButton", { Visible = false, Text = "V", TextColor3 = P.text,
            Font = Enum.Font.GothamBold, TextSize = 21, BackgroundColor3 = P.accentDim,
            Position = UDim2.new(0, 18, 0.5, -25), Size = UDim2.fromOffset(50, 50),
            BorderSizePixel = 0 }, screen)
        round(launcher, 14); outline(launcher, P.accent)
        local window = { Screen = screen, Surface = surface, Pages = pages,
            Nav = nav, Title = bar.PageTitle, Notifications = notifications,
            Tabs = {}, Selected = nil, Launcher = launcher }
        self.Window = window
        local function show(state)
            surface.Visible = state
            launcher.Visible = not state
        end
        binding(minimize.MouseButton1Click, function() show(false) end)
        binding(launcher.MouseButton1Click, function() show(true) end)
        binding(close.MouseButton1Click, function()
            if Hub.Unload then Hub.Unload() else UI:Destroy() end
        end)
        binding(UIS.InputBegan, function(input, processed)
            if processed then return end
            if input.KeyCode == Enum.KeyCode.K then show(not surface.Visible) end
        end)
        -- Dragging via top bar (except the close/minimize controls).
        local dragging, dragStart, startPos = false, nil, nil
        binding(bar.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
                input.UserInputType == Enum.UserInputType.Touch then
                dragging, dragStart, startPos = true, input.Position, surface.Position
            end
        end)
        binding(UIS.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
                input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
        binding(UIS.InputChanged, function(input)
            if dragging and dragStart and (input.UserInputType == Enum.UserInputType.MouseMovement or
                input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                surface.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X / scale.Scale,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y / scale.Scale)
            end
        end)
        return window
    end

    local sectionIcons = { Main = "◆", Boost = "⚡", Factory = "▤",
        ["Box Farming"] = "◇", Vendors = "▦", Teleport = "⌖",
        Music = "♫", Misc = "◈", ["Esp Egg"] = "◎" }
    local tabNames = { Main = "Dashboard", Boost = "Auto Section",
        Factory = "Factory", ["Box Farming"] = "Box Farming", Vendors = "Vendors",
        Teleport = "Teleport", Music = "Music", Misc = "Player", ["Esp Egg"] = "Egg ESP" }
    local function createControlBase(tab, height)
        if not tab.CurrentCard then tab:CreateSection("Controls") end
        local item = new("Frame", { BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, height), BorderSizePixel = 0,
            LayoutOrder = tab.ElementCount + 1 }, tab.CurrentCard.Body)
        tab.ElementCount = tab.ElementCount + 1
        return item
    end
    local function decorateBtn(b, bg, stroke)
        b.BackgroundColor3 = bg or P.field
        b.BorderSizePixel = 0
        round(b, 7); outline(b, stroke or P.border)
    end
    function UI.WindowDummy() end
    -- Called on the returned window, not UI itself.
    local tabMethods = {}
    local windowMethods = {}
    function windowMethods:ModifyTheme(_) end -- design palette is intentionally fixed
    function windowMethods:CreateTab(name)
        local label = tabNames[name] or name
        local category = (name == "Main") and "OVERVIEW" or
            (name == "Boost" or name == "Factory" or name == "Box Farming") and "AUTOMATION" or
            (name == "Vendors" or name == "Teleport" or name == "Misc") and "UTILITIES" or "PERSONALIZATION"
        if self.LastCategory ~= category then
            local heading = txt(self.Nav, category, 9, P.muted, true, {
                Size = UDim2.new(1, 0, 0, 22), LayoutOrder = #self.Tabs * 2 + 1 })
            heading.TextXAlignment = Enum.TextXAlignment.Left
            self.LastCategory = category
        end
        local b = new("TextButton", { Text = "", AutoButtonColor = false,
            BackgroundColor3 = P.side, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 38), LayoutOrder = #self.Tabs * 2 + 2 }, self.Nav)
        round(b, 8)
        local accent = new("Frame", { BackgroundColor3 = P.accent, BorderSizePixel = 0,
            Visible = false, Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(3, 22) }, b)
        round(accent, 3)
        txt(b, sectionIcons[name] or "◈", 16, P.muted, false, {
            Name = "Icon", Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(23, 38) })
        txt(b, label, 12, P.muted, true, { Name = "Label",
            Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -46, 1, 0) })
        local scroll = new("ScrollingFrame", { Name = name:gsub("%W", ""),
            Visible = false, BackgroundTransparency = 1, BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1), ScrollBarThickness = 4,
            ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarImageColor3 = P.accentDim,
            CanvasSize = UDim2.fromOffset(0, 0), ClipsDescendants = true }, self.Pages)
        local cols, listLayouts = {}, {}
        for i = 1, 2 do
            local col = new("Frame", { BackgroundTransparency = 1,
                Position = UDim2.new((i - 1) * 0.5, i == 1 and 16 or 6, 0, 16),
                Size = UDim2.new(0.5, -24, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, scroll)
            pad(col, 0, 0, 3, 0)
            listLayouts[i] = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 12) }, col)
            cols[i] = col
        end
        local function updateCanvas()
            scroll.CanvasSize = UDim2.new(0, 0, 0, math.max(
                listLayouts[1].AbsoluteContentSize.Y, listLayouts[2].AbsoluteContentSize.Y) + 44)
        end
        for i = 1, 2 do
            binding(listLayouts[i]:GetPropertyChangedSignal("AbsoluteContentSize"), updateCanvas)
        end
        local tab = { Parent = self, Name = name, Button = b, Scroll = scroll,
            Columns = cols, CardCount = 0, ElementCount = 0, CurrentCard = nil,
            Searchable = {} }
        table.insert(self.Tabs, tab)
        local function select()
            self.Selected = tab
            self.Title.Text = label
            for _, t in ipairs(self.Tabs) do
                local active = t == tab
                t.Scroll.Visible = active
                tw(t.Button, { BackgroundColor3 = active and P.accentDim or P.side })
                t.Button.Icon.TextColor3 = active and P.accent or P.muted
                t.Button.Label.TextColor3 = active and P.text or P.muted
                local marker = t.Button:FindFirstChildOfClass("Frame")
                if marker then marker.Visible = active end
            end
        end
        binding(b.MouseButton1Click, select)
        if not self.Selected then select() end
        return setmetatable(tab, { __index = tabMethods })
    end
    -- tabMethods are forward declared before window:CreateTab is first called.
    function windowMethods.__index(_, key) return windowMethods[key] end
    -- Return window with the CreateTab method attached.
    local baseCreate = UI.CreateWindow
    function UI:CreateWindow(conf)
        local w = baseCreate(self, conf)
        return setmetatable(w, { __index = windowMethods })
    end

    function tabMethods:CreateSection(title)
        self.CardCount = self.CardCount + 1
        local col = self.Columns[(self.CardCount - 1) % 2 + 1]
        local card = new("Frame", { BackgroundColor3 = P.card, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = self.CardCount }, col)
        round(card, 10); outline(card, P.border)
        pad(card, 13, 12, 13, 12)
        new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 9) }, card)
        local header = new("Frame", { BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1 }, card)
        new("Frame", { BackgroundColor3 = P.accent, BorderSizePixel = 0,
            Size = UDim2.fromOffset(3, 16), Position = UDim2.fromOffset(0, 4) }, header)
        txt(header, title, 12, P.text, true, {
            Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -12, 1, 0) })
        local body = new("Frame", { Name = "Controls", BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 2 }, card)
        new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 5) }, body)
        self.CurrentCard = { Frame = card, Body = body }
        return card
    end
    function tabMethods:CreateLabel(value)
        local root = createControlBase(self, 36)
        local label = txt(root, value, 11, P.muted, false, {
            Size = UDim2.fromScale(1, 1), TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top })
        return { Set = function(_, text) label.Text = tostring(text or "") end }
    end
    function tabMethods:CreateToggle(opt)
        local root = createControlBase(self, 45)
        local click = new("TextButton", { Text = "", AutoButtonColor = false,
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
        txt(click, opt.Name, 11, P.text, true, {
            Position = UDim2.fromOffset(1, 0), Size = UDim2.new(1, -56, 1, 0), TextWrapped = true })
        local sw = new("Frame", { Position = UDim2.new(1, -47, 0.5, -12),
            Size = UDim2.fromOffset(46, 24), BackgroundColor3 = P.field,
            BorderSizePixel = 0 }, click)
        round(sw, 12); outline(sw, P.border)
        local knob = new("Frame", { Size = UDim2.fromOffset(17, 17),
            Position = UDim2.fromOffset(4, 3), BackgroundColor3 = P.muted,
            BorderSizePixel = 0 }, sw)
        round(knob, 9)
        local current = not not opt.CurrentValue
        local function set(value)
            value = not not value
            if current == value then return end
            current = value
            tw(sw, { BackgroundColor3 = value and P.accent or P.field })
            tw(knob, { Position = UDim2.fromOffset(value and 25 or 4, 3),
                BackgroundColor3 = value and P.text or P.muted })
            safeCall(opt.Callback, value)
        end
        current = not current
        set(not not opt.CurrentValue)
        binding(click.MouseButton1Click, function() set(not current) end)
        return { Set = function(_, value) set(value) end, Get = function() return current end }
    end
    function tabMethods:CreateButton(opt)
        local root = createControlBase(self, 42)
        local btn = new("TextButton", { Text = opt.Name or "Action", AutoButtonColor = false,
            Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = P.text,
            Size = UDim2.new(1, 0, 1, -3) }, root)
        decorateBtn(btn, P.field)
        binding(btn.MouseEnter, function() tw(btn, { BackgroundColor3 = P.hover }) end)
        binding(btn.MouseLeave, function() tw(btn, { BackgroundColor3 = P.field }) end)
        binding(btn.MouseButton1Click, function()
            task.spawn(function() safeCall(opt.Callback) end)
        end)
        return { Set = function(_, name) btn.Text = tostring(name) end }
    end
    function tabMethods:CreateInput(opt)
        local root = createControlBase(self, 75)
        txt(root, opt.Name or "Input", 11, P.text, true, {
            Size = UDim2.new(1, 0, 0, 27), TextWrapped = true })
        local input = new("TextBox", { Name = "Field", Text = tostring(opt.CurrentValue or ""),
            ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12,
            TextColor3 = P.text, PlaceholderColor3 = P.muted,
            PlaceholderText = opt.PlaceholderText or "",
            BackgroundColor3 = P.field, BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 31), Size = UDim2.new(1, 0, 0, 36),
            TextXAlignment = Enum.TextXAlignment.Left }, root)
        round(input, 7); outline(input, P.border); pad(input, 0, 9, 0, 9)
        binding(input.FocusLost, function()
            safeCall(opt.Callback, input.Text)
            if opt.RemoveTextAfterFocusLost then input.Text = "" end
        end)
        return { Set = function(_, value) input.Text = tostring(value or "") end,
            Get = function() return input.Text end }
    end
    function tabMethods:CreateDropdown(opt)
        local root = createControlBase(self, 75)
        txt(root, opt.Name or "Select", 11, P.text, true, {
            Size = UDim2.new(1, 0, 0, 27), TextWrapped = true })
        local action = new("TextButton", { Text = "", AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 31) }, root)
        decorateBtn(action, P.field)
        local active = txt(action, "None Selected", 11, P.muted, false, {
            Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -35, 1, 0),
            TextTruncate = Enum.TextTruncate.AtEnd })
        txt(action, "⌄", 17, P.accent, false, {
            Position = UDim2.new(1, -26, 0, 0), Size = UDim2.fromOffset(20, 36),
            TextXAlignment = Enum.TextXAlignment.Center })
        local menu = new("ScrollingFrame", { BackgroundColor3 = P.field,
            BorderSizePixel = 0, Visible = false, Position = UDim2.fromOffset(0, 71),
            Size = UDim2.new(1, 0, 0, 0), ScrollBarThickness = 3,
            ScrollBarImageColor3 = P.accent, CanvasSize = UDim2.fromOffset(0, 0) }, root)
        round(menu, 7); outline(menu, P.border)
        pad(menu, 4, 5, 4, 5)
        local menuLayout = new("UIListLayout", { Padding = UDim.new(0, 3),
            SortOrder = Enum.SortOrder.LayoutOrder }, menu)
        local opts, selected, opened = {}, {}, false
        local multi = not not opt.MultipleOptions
        local function selectedValues()
            local values, seen = {}, {}
            for _, option in ipairs(opts) do
                if selected[option] then values[#values + 1] = option; seen[option] = true end
            end
            for option, yes in pairs(selected) do
                if yes and not seen[option] then values[#values + 1] = option end
            end
            return values
        end
        local function emit()
            local values = selectedValues()
            if multi then safeCall(opt.Callback, values)
            else safeCall(opt.Callback, { values[1] }) end
        end
        local function refreshTitle()
            local values = selectedValues()
            if #values == 0 then
                active.Text = "None Selected"; active.TextColor3 = P.muted
            else
                active.Text = table.concat(values, ", "); active.TextColor3 = P.text
            end
        end
        local function updateSize()
            menu.Size = UDim2.new(1, 0, 0, math.min(#opts, 6) * 34 + 8)
            menu.CanvasSize = UDim2.fromOffset(0, #opts * 34 + 8)
            root.Size = UDim2.new(1, 0, 0, opened and (77 + math.min(#opts, 6) * 34 + 8) or 75)
            menu.Visible = opened
        end
        local function rebuild()
            for _, c in ipairs(menu:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            for i, option in ipairs(opts) do
                local label = option
                local btn = new("TextButton", { Name = "Option", Text = "",
                    LayoutOrder = i, AutoButtonColor = false,
                    BackgroundColor3 = selected[option] and P.accentDim or P.field,
                    BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 31) }, menu)
                round(btn, 5)
                local mark = txt(btn, selected[option] and "●" or "○", 12,
                    selected[option] and P.accent or P.muted, true, {
                    Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(16, 31) })
                txt(btn, label, 11, P.text, false, {
                    Position = UDim2.fromOffset(25, 0), Size = UDim2.new(1, -27, 1, 0),
                    TextTruncate = Enum.TextTruncate.AtEnd })
                binding(btn.MouseButton1Click, function()
                    if multi then selected[label] = not selected[label]
                    else selected = { [label] = true }; opened = false end
                    refreshTitle(); rebuild(); updateSize(); emit()
                end)
            end
            updateSize()
        end
        local function set(val, call)
            local nextSelected = {}
            if type(val) == "table" then
                for _, v in ipairs(val) do nextSelected[tostring(v)] = true end
            elseif val ~= nil then nextSelected[tostring(val)] = true end
            selected = nextSelected
            refreshTitle()
            rebuild()
            if call then emit() end
        end
        local function refresh(list)
            opts = {}
            for _, val in ipairs(list or {}) do opts[#opts + 1] = tostring(val) end
            rebuild(); refreshTitle()
        end
        binding(action.MouseButton1Click, function()
            opened = not opened
            updateSize()
        end)
        refresh(opt.Options or {})
        set(opt.CurrentOption or {}, false)
        return { Set = function(_, value) set(value, true) end,
            Refresh = function(_, values) refresh(values) end }
    end
    function tabMethods:CreateSlider(opt)
        local root = createControlBase(self, 72)
        txt(root, opt.Name or "Slider", 11, P.text, true, {
            Size = UDim2.new(1, -64, 0, 28), TextWrapped = true })
        local readout = txt(root, "", 11, P.accent, true, {
            Position = UDim2.new(1, -66, 0, 0), Size = UDim2.new(0, 66, 0, 28),
            TextXAlignment = Enum.TextXAlignment.Right })
        local track = new("Frame", { Position = UDim2.fromOffset(5, 46),
            Size = UDim2.new(1, -10, 0, 5), BackgroundColor3 = P.field,
            BorderSizePixel = 0 }, root)
        round(track, 3)
        local fill = new("Frame", { Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = P.accent, BorderSizePixel = 0 }, track)
        round(fill, 3)
        local handle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(14, 14), Position = UDim2.fromScale(0, 0.5),
            BackgroundColor3 = P.text, BorderSizePixel = 0 }, track)
        round(handle, 7); outline(handle, P.accent)
        local hit = new("TextButton", { Text = "", BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 0.5, -14) }, track)
        local lo = tonumber(opt.Range and opt.Range[1]) or 0
        local hi = math.max(lo + 1e-6, tonumber(opt.Range and opt.Range[2]) or 100)
        local step = math.max(1e-6, tonumber(opt.Increment) or 1)
        local current = lo
        local function set(v, send)
            local quant = math.floor((math.clamp(tonumber(v) or lo, lo, hi) - lo) / step + 0.5) * step + lo
            current = math.clamp(quant, lo, hi)
            local ratio = (current - lo) / (hi - lo)
            fill.Size = UDim2.fromScale(ratio, 1)
            handle.Position = UDim2.fromScale(ratio, 0.5)
            readout.Text = string.format("%g", current) .. (opt.Suffix and " " .. opt.Suffix or "")
            if send then safeCall(opt.Callback, current) end
        end
        set(opt.CurrentValue or lo, false)
        local dragging = false
        local function update(x)
            if track.AbsoluteSize.X > 0 then
                set(lo + math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1) * (hi - lo), true)
            end
        end
        binding(hit.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
                input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; update(input.Position.X)
            end
        end)
        binding(UIS.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                input.UserInputType == Enum.UserInputType.Touch) then update(input.Position.X) end
        end)
        binding(UIS.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
                input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
        return { Set = function(_, value) set(value, true) end, Get = function() return current end }
    end
    return UI
end)()


local function notify(title, content, duration)
    pcall(function()
        Rayfield:Notify({ Title = title, Content = content, Duration = duration or 6 })
    end)
end

----------------------------------------------------------------------
-- Anti-AFK
----------------------------------------------------------------------
connect(LocalPlayer.Idled, function()
    pcall(function()
        local cam = workspace.CurrentCamera
        VirtualUser:Button2Down(Vector2.new(0, 0), cam and cam.CFrame or CFrame.new())
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), cam and cam.CFrame or CFrame.new())
    end)
end)
print("[MH] Anti-AFK enabled")

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local loops = {}  -- token table: starting/stopping loops safely (no duplicate loops)
local function setLoop(key, enabled, interval, fn)
    loops[key] = (loops[key] or 0) + 1
    local token = loops[key]
    if not enabled then return end
    task.spawn(function()
        while Hub.Alive and loops[key] == token do
            local ok, err = pcall(fn)
            if not ok then warn("[MH] loop '" .. key .. "' error:", err) end
            task.wait(interval)
        end
    end)
end

local remoteCache, missingRemoteAt = {}, {}
local function findRemote(name)
    if missingRemoteAt[name] and os.clock() - missingRemoteAt[name] < 3 then return nil end
    local cached = remoteCache[name]
    if cached and cached.Parent then return cached end
    local function search(root)
        if not root then return nil end
        for _, d in ipairs(root:GetDescendants()) do
            if d.Name == name and (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) then
                return d
            end
        end
    end
    -- new game layout: ReplicatedStorage.Remotes.<Category>.<Name>; fall back to old layout
    local r = search(RS:FindFirstChild("Remotes")) or RS:FindFirstChild(name)
    if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then
        remoteCache[name] = r
        return r
    end
    missingRemoteAt[name] = os.clock()
    return nil
end

-- New game networking: most commands go through Jolt channels (Fire / Invoke)
local JOLT_METHODS = {
    Rebirth    = "Invoke",   -- game: Rebirth:Invoke()
    DestroyAll = "Invoke",   -- game: DestroyAll:Invoke()
    RemoteDrop = "Fire",     -- game: RemoteDrop:Fire()
    Pulse      = "Fire",     -- game: Pulse:Fire()
    MysteryBox = "Invoke",   -- game: MysteryBox:Invoke(boxType)
    PlaySolo   = "Invoke",   -- old script: PlaySolo:InvokeServer(islandType)
    BuyItem    = "Invoke",   -- game: BuyItem:Invoke(itemId, amount)
    PlaceItem  = "Invoke",   -- game: PlaceItem:Invoke(itemId, cframe + base.Position, {base})
    CraftsmanEvents = "Invoke", -- game: CraftsmanEvents:Invoke("type:hasblueprint", id)
}

local Jolt
do
    local ok, mod = pcall(function()
        local modules = RS:WaitForChild("Modules", 15)
        local networking = modules and modules:WaitForChild("Networking", 10)
        local module = networking and networking:WaitForChild("Jolt", 10)
        assert(module, "ReplicatedStorage.Modules.Networking.Jolt is unavailable")
        return require(module)
    end)
    if ok and type(mod) == "table" and type(mod.Client) == "function" then
        Jolt = mod
    else
        warn("[MH] Could not load Jolt module:", mod)
    end
end

local joltChannels = {}
local function joltChannel(name)
    if not Jolt then return nil end
    local ch = joltChannels[name]
    if not ch then
        local ok, res = pcall(Jolt.Client, name)
        if ok then
            ch = res
            joltChannels[name] = ch
        end
    end
    return ch
end

local warnedRemote = {}
local function callRemote(name, ...)
    local method = JOLT_METHODS[name]
    if method then
        local ch = joltChannel(name)
        if ch and type(ch[method]) == "function" then
            local ok, result, extra = pcall(ch[method], ch, ...)
            if ok then return true, result, extra end
        end
    end
    local r = findRemote(name)
    if not r then
        if not warnedRemote[name] then
            warnedRemote[name] = true
            warn("[MH] Remote not found in ReplicatedStorage: " .. name)
        end
        return false
    end
    if r:IsA("RemoteFunction") then
        return pcall(r.InvokeServer, r, ...)
    elseif r:IsA("RemoteEvent") then
        return pcall(r.FireServer, r, ...)
    end
    return false
end

local warnedMoney = false
local function getMoney()
    local ok, v = pcall(function()
        return LocalPlayer.PlayerGui.GUI.Money.Value
    end)
    if ok and type(v) == "number" then return v end
    if not warnedMoney then
        warnedMoney = true
        warn("[MH] Cannot read PlayerGui.GUI.Money.Value (path changed?). Auto Rebirth / Layout Switch won't work.")
    end
    return 0
end

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function firstOption(sel)  -- new Rayfield returns a table
    if type(sel) == "table" then return sel[1] end
    return sel
end

local function getTargetCFrame(target)
    if not target then return nil end
    if target:IsA("Model") then
        local ok, cf = pcall(function() return target:GetPivot() end)
        if ok then return cf end
    end
    if target:IsA("BasePart") then return target.CFrame end
    for _, d in ipairs(target:GetDescendants()) do
        if d:IsA("BasePart") then return d.CFrame end
    end
    return nil
end

local function teleportTo(target)
    local hrp = getHRP()
    if not hrp then warn("[MH] No HumanoidRootPart"); return end
    if not target then warn("[MH] Target not found"); notify("Teleport", "Target not found (not loaded yet?)"); return end
    local cf = getTargetCFrame(target)
    if cf then
        hrp.CFrame = cf + Vector3.new(0, 5, 0)
        print("[MH] Teleported to:", target:GetFullName())
    else
        warn("[MH] No valid position for:", target.Name)
    end
end

local function getPlayerFactory()
    local tycoons = workspace:FindFirstChild("Tycoons")
    if not tycoons then return nil end
    for _, factory in ipairs(tycoons:GetChildren()) do
        local owner = factory:FindFirstChild("Owner")
        if owner and (owner.Value == LocalPlayer.Name or owner.Value == LocalPlayer) then
            return factory
        end
    end
    return nil
end

----------------------------------------------------------------------
-- Create dashboard pages (two-column responsive-style cards)
----------------------------------------------------------------------
local Window = Rayfield:CreateWindow({ Name = "Miner's Haven by Viyx", Version = "1.5" })
local MainTab     = Window:CreateTab("Main")
local BoostTab    = Window:CreateTab("Boost")
local BoxTab      = Window:CreateTab("Box Farming")
local FactoryTab  = Window:CreateTab("Factory")
local VendorTab   = Window:CreateTab("Vendors")
local TeleportTab = Window:CreateTab("Teleport")
local MiscTab     = Window:CreateTab("Misc")
local MusicTab    = Window:CreateTab("Music")
local EspTab      = Window:CreateTab("Esp Egg")

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local layoutSwitchThreshold = 1e3
local rebirthThreshold      = 1e3
local lockedValue           = 7
local lockEnabled           = true
local oreSpeedMultiplier    = 3
local boostEnabled          = false
local autoTeleport          = false
local boxOriginCFrame
local myFactory

----------------------------------------------------------------------
-- MAIN TAB
----------------------------------------------------------------------
MainTab:CreateSection("Quick Actions")

-- Auto Press Z
MainTab:CreateToggle({
    Name = "Auto Press Z",
    CurrentValue = false,
    Flag = "AutoPressZ",
    Callback = function(Value)
        setLoop("pressZ", Value, 0.05, function()
            local ok = pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Z, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Z, false, game)
            end)
            if not ok and keypress and keyrelease then  -- executor fallback
                keypress(0x5A); task.wait(0.05); keyrelease(0x5A)
            end
        end)
    end,
})

MainTab:CreateSection("Saved Layouts")
-- Layout 1 / 2 / 3 loops
for i = 1, 3 do
    MainTab:CreateToggle({
        Name = "Layout " .. i,
        CurrentValue = false,
        Flag = "Layout" .. i,
        Callback = function(state)
            setLoop("layout" .. i, state, 0.75, function()
                callRemote("Layouts", "Load", "Layout" .. i)
            end)
        end,
    })
end

MainTab:CreateSection("Quick Automation")
MainTab:CreateLabel("Fast actions and prompt assistance. Smart rebirth and ore boost are in Auto Section.")
MainTab:CreateToggle({
    Name = "Auto Rebirth",
    CurrentValue = false,
    Flag = "AutoRebirth",
    Callback = function(state)
        setLoop("mainRebirth", state, 0.6, function()
            callRemote("Rebirth")
        end)
    end,
})

MainTab:CreateToggle({
    Name = "Auto Drop",
    CurrentValue = false,
    Flag = "AutoDrop",
    Callback = function(state)
        setLoop("autoDrop", state, 0.2, function()
            callRemote("RemoteDrop")
        end)
    end,
})

for _, boxType in ipairs({ "Regular", "Unreal", "Inferno" }) do
    MainTab:CreateToggle({
        Name = "Auto " .. boxType .. " Box",
        CurrentValue = false,
        Flag = "Auto" .. boxType .. "Box",
        Callback = function(state)
            setLoop("box" .. boxType, state, 1, function()
                callRemote("MysteryBox", boxType)
            end)
        end,
    })
end

MainTab:CreateToggle({
    Name = "Auto Pulse",
    CurrentValue = false,
    Flag = "AutoPulse",
    Callback = function(state)
        setLoop("autoPulse", state, 0.25, function()
            callRemote("Pulse")
        end)
    end,
})

-- MX6/A4 contribution: automatically confirms the game's "Collect Candy" prompt.
-- This does NOT locate or physically pick up candy in the world.
local lastCandyConfirmAt = 0
local function confirmCandyCollection()
    if not Hub.Alive or os.clock() - lastCandyConfirmAt < 0.4 then return end

    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end
    local gameGui = playerGui:FindFirstChild("GUI")
    local prompts = playerGui:FindFirstChild("Prompts")
        or (gameGui and gameGui:FindFirstChild("Prompts"))
    local promptContainer = prompts and prompts:FindFirstChild("InputPrompt")
    local prompt = (promptContainer and promptContainer:FindFirstChild("InputPrompt"))
        or (gameGui and gameGui:FindFirstChild("InputPrompt")
            and gameGui.InputPrompt:FindFirstChild("InputPrompt"))
    if not (prompt and prompt:IsA("GuiObject") and prompt.Visible) then return end

    local title = prompt:FindFirstChild("Title")
    local yes = prompt:FindFirstChild("Yes")
    if not (title and title:IsA("TextLabel") and yes and yes:IsA("GuiButton") and yes.Visible) then
        return
    end
    local promptText = string.lower(title.Text or "")
    if not (string.find(promptText, "collect", 1, true)
        and string.find(promptText, "candy", 1, true)) then
        return
    end

    -- Prefer the same click hooks as MX6; fallback to Roblox GuiButton:Activate().
    local clicked = false
    if type(getconnections) == "function" then
        local ok, connections = pcall(getconnections, yes.MouseButton1Click)
        if ok and type(connections) == "table" then
            for _, conn in ipairs(connections) do
                if type(conn.Function) == "function" then
                    clicked = pcall(conn.Function) or clicked
                end
            end
        end
    end
    if not clicked and type(firesignal) == "function" then
        clicked = pcall(firesignal, yes.MouseButton1Click)
    end
    if not clicked then
        clicked = pcall(function() yes:Activate() end)
    end
    if clicked then lastCandyConfirmAt = os.clock() end
end

MainTab:CreateToggle({
    Name = "Auto Collect Candy",
    CurrentValue = false,
    Flag = "AutoCollectCandy",
    Callback = function(enabled)
        setLoop("autoCollectCandy", enabled, 0.15, confirmCandyCollection)
    end,
})
MainTab:CreateLabel("Automatically selects Yes on Collect Candy popups; does not hunt for candy.")

MainTab:CreateSection("Box Utilities")
-- Auto Teleport to boxes
local function collectBoxes(folder, out)
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("Folder") then
            collectBoxes(obj, out)
        elseif obj:IsA("BasePart") or obj:IsA("Model") then
            out[#out + 1] = obj
        end
    end
    return out
end

MainTab:CreateToggle({
    Name = "Auto Teleport to Boxes & Stay",
    CurrentValue = false,
    Flag = "AutoTeleportBoxes",
    Callback = function(state)
        autoTeleport = state
        local hrp = getHRP()
        if state and hrp then boxOriginCFrame = hrp.CFrame end

        setLoop("teleportBoxes", state, 0.1, function()
            local root = getHRP()
            local folder = workspace:FindFirstChild("Boxes")
            if not root or not folder then return end

            local boxes = collectBoxes(folder, {})
            if #boxes > 0 then
                for _, box in ipairs(boxes) do
                    if not autoTeleport then return end
                    local cf = getTargetCFrame(box)
                    if cf then
                        root.CFrame = cf * CFrame.new(0, 0.5, 1.5)
                        task.wait(0.05)
                    end
                end
            elseif boxOriginCFrame then
                root.CFrame = boxOriginCFrame
                task.wait(0.5)
            end
        end)
    end,
})

----------------------------------------------------------------------
-- SETTINGS TAB
----------------------------------------------------------------------
BoostTab:CreateSection("Cash Threshold & Layout Switching")
BoostTab:CreateLabel("Alternative simple modes: do not enable both rebirth methods together.")

local rebirthOptions = {
    "1K (Thousand)", "1M (Million)", "1B (Billion)", "1T (Trillion)", "1qd (Quadrillion)", "1Qn (Quintillion)",
    "1sx (Sextillion)", "1Sp (Septillion)", "1O (Octillion)", "1N (Nonillion)", "1de (Decillion)", "1Ud (Undecillion)",
    "1DD (Duodecillion)", "1tdD (Tredecillion)", "1qdD (Quattuordecillion)", "1QnD (Quindecillion)", "1sxD (Sedecillion)", "1SpD (Septendecillion)",
    "1OcD (Octodecillion)", "1NvD (Novemdecillion)", "1Vgn (Vigintillion)", "1UVg (Unvigintillion)", "1DVg (Duovigintillion)", "1TVg (Tresvigintillion)",
    "1qtV (Quattuorvigintillion)", "1QnV (Quinvigintillion)", "1SeV (Sesvigintillion)", "1SPG (Septemvigintillion)", "1OVG (Octovigintillion)", "1NVG (Novemvigintillion)",
    "1TGN (Trigintillion)", "1UTG (Untrigintillion)", "1DTG (Duotrigintillion)", "1tsTG (Trestrigintillion)", "1qtTG (Quattuortrigintillion)", "1QnTG (Quintrigintillion)",
    "1ssTG (Sestrigintillion)", "1SpTG (Septentrigintillion)", "1OcTG (Octotrigintillion)", "1NoTG (Novemtrigintillion)", "1QdDR (Quadragintillion)", "1uQDR (Unquadragintillion)",
    "1dQDR (Duoquadragintillion)", "1tQDR (Tresquadragintillion)", "1qdQDR (Quattuorquadragintillion)", "1QnQDR (Quinquadragintillion)", "1sxQDR (Sesquadragintillion)", "1SpQDR (Septenquadragintillion)",
    "1OQDDr (Octoquadragintillion)", "1NQDDr (Novemquadragintillion)", "1qQGNT (Quinquagintillion)", "1uQGNT (Unquinquagintillion)", "1dQGNT (Duoquinquagintillion)", "1tQGNT (Tresquinquagintillion)",
    "1qdQGNT (Quattuorquinquagintillion)", "1QnQGNT (Quinquinquagintillion)", "1sxQGNT (Sesquinquagintillion)", "1SpQGNT (Septenquinquagintillion)", "1OQQGNT (Octoquinquagintillion)", "1NQQGNT (Novemquinquagintillion)",
    "1SXGNTL (Sexagintillion)", "1USXGNTL (Unsexagintillion)", "1DSXGNTL (Duosexagintillion)", "1TSXGNTL (Tresexagintillion)", "1QTSXGNTL (Quattuorsexagintillion)", "1QNSXGNTL (Quinsexagintillion)",
    "1SXSXGNTL (Sesexagintillion)", "1SPSXGNTL (Septensexagintillion)", "1OSXGNTL (Octosexagintillion)", "1NVSXGNTL (Novemsexagintillion)", "1SPTGNTL (Septuagintillion)", "1USPTGNTL (Unseptuagintillion)",
    "1DSPTGNTL (Duoseptuagintillion)", "1TSPTGNTL (Treseptuagintillion)", "1QTSPTGNTL (Quattuorseptuagintillion)", "1QNSPTGNTL (Quinseptuagintillion)", "1SXSPTGNTL (Seseptuagintillion)", "1SPSPTGNTL (Septenseptuagintillion)",
    "1OSPTGNTL (Octoseptuagintillion)", "1NVSPTGNTL (Novemseptuagintillion)", "1OTGNTL (Octogintillion)", "1UOTGNTL (Unoctogintillion)", "1DOTGNTL (Duooctogintillion)", "1TOTGNTL (Treoctogintillion)",
    "1QTOTGNTL (Quattuoroctogintillion)", "1QNOTGNTL (Quinoctogintillion)", "1SXOTGNTL (Sexoctogintillion)", "1SPOTGNTL (Septemoctogintillion)", "1OTOTGNTL (Octooctogintillion)", "1NVOTGNTL (Novemoctogintillion)",
    "1NONGNTL (Nonagintillion)", "1UNONGNTL (Unnonagintillion)", "1DNONGNTL (Duononagintillion)", "1TNONGNTL (Trenonagintillion)", "1QTNONGNTL (Quattuornonagintillion)", "1QNNONGNTL (Quinnonagintillion)",
    "1SXNONGNTL (Senonagintillion)", "1SPNONGNTL (Septenonagintillion)", "1OTNONGNTL (Octononagintillion)", "1NONONGNTL (Novemnonagintillion)", "1CENT (Centillion)", "1UNCENT (Uncentillion)", 
    "inf (Infinity)"
}

local rebirthValues = {}
for i, v in ipairs(rebirthOptions) do
    rebirthValues[v] = 10 ^ (3 * i)
end
rebirthValues["inf (Infinity)"] = math.huge

-- Layout threshold uses the first 18 options (1K .. 1SpD)
local thresholdOptions = {}
for i = 1, 18 do thresholdOptions[i] = rebirthOptions[i] end

BoostTab:CreateDropdown({
    Name = "Layout Switch at (cash value)",
    Options = thresholdOptions,
    CurrentOption = { "1K (Thousand)" },
    MultipleOptions = false,
    Flag = "LayoutThreshold",
    Callback = function(sel)
        layoutSwitchThreshold = rebirthValues[firstOption(sel)] or 1e3
    end,
})

local function startLayoutSwitch(key, enabled, targetLayout)
    local loadedTarget = false
    setLoop(key, enabled, 0.05, function()
        if getMoney() >= layoutSwitchThreshold then
            if not loadedTarget then
                callRemote("DestroyAll")
                callRemote("Layouts", "Load", targetLayout)
                loadedTarget = true
            end
        else
            callRemote("Layouts", "Load", "Layout1")
            loadedTarget = false
        end
    end)
end

BoostTab:CreateToggle({
    Name = "Auto Layout Switch (1 to 2)",
    CurrentValue = false,
    Flag = "AutoLayout12",
    Callback = function(state) startLayoutSwitch("switch12", state, "Layout2") end,
})

BoostTab:CreateToggle({
    Name = "Auto Layout Switch (1 to 3)",
    CurrentValue = false,
    Flag = "AutoLayout13",
    Callback = function(state) startLayoutSwitch("switch13", state, "Layout3") end,
})

BoostTab:CreateDropdown({
    Name = "Auto Rebirth at (only rebirth when cash is met)",
    Options = rebirthOptions,
    CurrentOption = { "1K (Thousand)" },
    MultipleOptions = false,
    Flag = "RebirthThreshold",
    Callback = function(sel)
        rebirthThreshold = rebirthValues[firstOption(sel)] or 1e3
    end,
})

BoostTab:CreateToggle({
    Name = "Auto Rebirth (by cash threshold)",
    CurrentValue = false,
    Flag = "AutoRebirthToggle",
    Callback = function(state)
        setLoop("thresholdRebirth", state, 0.05, function()
            if getMoney() >= rebirthThreshold then
                callRemote("Rebirth")
            end
        end)
    end,
})

----------------------------------------------------------------------
-- Diagnostics
----------------------------------------------------------------------
local function diagnose()
    local missing = {}
    for _, n in ipairs({ "Layouts", "DestroyAll", "Rebirth", "RemoteDrop", "MysteryBox", "Pulse" }) do
        local r = findRemote(n)
        if r then
            print("[MH] found remote:", r:GetFullName(), r.ClassName)
        elseif JOLT_METHODS[n] and joltChannel(n) then
            print("[MH] Jolt channel OK:", n, JOLT_METHODS[n])
        else
            missing[#missing + 1] = "Remote: " .. n
        end
    end
    for _, n in ipairs({ "Tycoons", "DroppedParts", "Boxes", "Map" }) do
        if not workspace:FindFirstChild(n) then missing[#missing + 1] = "workspace." .. n end
    end
    if not pcall(function() return LocalPlayer.PlayerGui.GUI.Money.Value end) then
        missing[#missing + 1] = "PlayerGui.GUI.Money"
    end
    if #missing == 0 then
        print("[MH] Diagnostics: everything found.")
        notify("Diagnostics", "All paths and remotes found.")
    else
        local msg = table.concat(missing, "\n")
        warn("[MH] Diagnostics - MISSING:\n" .. msg)
        notify("Diagnostics - missing", msg, 12)
    end
end

BoostTab:CreateSection("Diagnostics & Compatibility")
BoostTab:CreateButton({ Name = "Run Diagnostics", Callback = diagnose })

BoostTab:CreateButton({
    Name = "Dump Remotes (print to F9 console)",
    Callback = function()
        print("===== ReplicatedStorage children =====")
        for _, v in ipairs(RS:GetChildren()) do
            print(v.ClassName, v.Name)
        end
        print("===== workspace children =====")
        for _, v in ipairs(workspace:GetChildren()) do
            print(v.ClassName, v.Name)
        end
    end,
})

----------------------------------------------------------------------
-- FACTORY TAB
----------------------------------------------------------------------
FactoryTab:CreateSection("Factory Speed Control")

FactoryTab:CreateSlider({
    Name = "Ore Speed Multiplier",
    Range = { 1, 10 },
    Increment = 1,
    Suffix = "x Speed",
    CurrentValue = 3,
    Flag = "OreSpeedMult",
    Callback = function(v) oreSpeedMultiplier = v end,
})

FactoryTab:CreateToggle({
    Name = "Enable Ore Speed Boost",
    CurrentValue = false,
    Flag = "EnableOreBoost",
    Callback = function(state) boostEnabled = state end,
})

connect(RunService.Heartbeat, function()
    if not Hub.Alive or not boostEnabled then return end
    local dropped = workspace:FindFirstChild("DroppedParts")
    if not dropped then return end
    -- Apply a bounded correction instead of exponential acceleration per frame.
    for _, factory in ipairs(dropped:GetChildren()) do
        if factory.Name:match("^Factory%d+$") then
            for _, ore in ipairs(factory:GetChildren()) do
                if ore:IsA("BasePart") then
                    local vel = ore.AssemblyLinearVelocity
                    local horizontal = Vector3.new(vel.X, 0, vel.Z)
                    local speed = horizontal.Magnitude
                    local target = math.min(150, 20 * oreSpeedMultiplier)
                    if speed > 0.5 and speed < target then
                        local accelerated = horizontal.Unit * math.min(target, speed + 1.0)
                        ore.AssemblyLinearVelocity = Vector3.new(accelerated.X, vel.Y, accelerated.Z)
                    end
                end
            end
        end
    end
end)

FactoryTab:CreateSlider({
    Name = "AdjustSpeed Value",
    Range = { 1, 100 },
    Increment = 1,
    Suffix = "Speed",
    CurrentValue = 7,
    Flag = "AdjustSpeedValue",
    Callback = function(v)
        lockedValue = v
        local adj = myFactory and myFactory:FindFirstChild("AdjustSpeed")
        if adj then adj.Value = lockedValue end
    end,
})

FactoryTab:CreateToggle({
    Name = "Lock Speed (Prevent Game Changes)",
    CurrentValue = true,
    Flag = "LockSpeed",
    Callback = function(state) lockEnabled = state end,
})

-- Find my factory and keep AdjustSpeed locked
task.spawn(function()
    while Hub.Alive and not myFactory do
        myFactory = getPlayerFactory()
        if not myFactory then task.wait(1) end
    end
    if not Hub.Alive or not myFactory then return end
    print("[MH] Found factory:", myFactory.Name)
    local adj = myFactory:WaitForChild("AdjustSpeed", 15)
    if not adj then warn("[MH] AdjustSpeed not found in factory"); return end
    while Hub.Alive do
        if not adj.Parent then adj = myFactory:FindFirstChild("AdjustSpeed") end
        if adj and lockEnabled and adj.Value ~= lockedValue then
            adj.Value = lockedValue
        end
        task.wait(0.2)
    end
end)



----------------------------------------------------------------------
-- EGG ESP TAB
----------------------------------------------------------------------
local ESPEnabled = false
local allESPs = {}

local function getEggFolders()
    local list = {}
    local easter = workspace:FindFirstChild("Easter")
    if easter then
        local f = easter:FindFirstChild("EASTER ISLAND EGG SPAWNS")
        if f then list[#list + 1] = f end
    end
    local map = workspace:FindFirstChild("Map")
    if map then
        local f = map:FindFirstChild("EGG_SPAWNS")
        if f then list[#list + 1] = f end
    end
    return list
end

local function createESP(egg)
    if egg:FindFirstChild("EggESP") then return end
    local adornee, label
    if egg:IsA("BasePart") then
        adornee = egg
    elseif egg:IsA("Model") then
        adornee = egg.PrimaryPart
    end
    for _, child in ipairs(egg:GetChildren()) do
        if child:IsA("BasePart") or child:IsA("Model") then
            label = label or child.Name
            if not adornee then
                adornee = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart", true)
            end
            break
        end
    end
    if not adornee then
        adornee = egg:FindFirstChildWhichIsA("BasePart", true)
    end
    if not adornee then return end

    local esp = Instance.new("BillboardGui")
    esp.Name = "EggESP"
    esp.Size = UDim2.new(0, 100, 0, 40)
    esp.AlwaysOnTop = true
    esp.StudsOffset = Vector3.new(0, 3, 0)
    esp.Adornee = adornee
    esp.Parent = egg

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.Text = label or egg.Name
    text.TextColor3 = Color3.fromRGB(187, 136, 255)
    text.TextStrokeTransparency = 0
    text.TextScaled = true
    text.Font = Enum.Font.SourceSansBold
    text.Parent = esp

    allESPs[#allESPs + 1] = esp
end

local function clearAllESP()
    for _, esp in ipairs(allESPs) do
        if esp and esp.Parent then esp:Destroy() end
    end
    allESPs = {}
end

EspTab:CreateSection("Egg Finder")
EspTab:CreateToggle({
    Name = "Egg ESP",
    CurrentValue = false,
    Flag = "EggESP",
    Callback = function(Value)
        ESPEnabled = Value
        setLoop("eggEsp", Value, 1, function()
            for _, folder in ipairs(getEggFolders()) do
                for _, egg in ipairs(folder:GetChildren()) do
                    if egg:IsA("Model") or egg:IsA("BasePart") then
                        createESP(egg)
                    end
                end
            end
        end)
        if not Value then clearAllESP() end
    end,
})

----------------------------------------------------------------------
-- VIYX FEATURES
-- Feature set inspired by MX6's Miners Haven hub, rewritten from scratch
-- for the new game (Jolt networking, no mouse-clicking on the UI).
----------------------------------------------------------------------
do
    local TeleportService = game:GetService("TeleportService")
    local SoundService    = game:GetService("SoundService")
    local HttpService     = game:GetService("HttpService")
    local Lighting        = game:GetService("Lighting")

    ------------------------------------------------------------------
    -- Shared state
    ------------------------------------------------------------------
    local B = {
        -- rebirth + layouts
        autoRebirth = false, minWait = 7, maxWait = 20, skips = 0, stopLife = 0, stopSlip = "None",
        ghostLoad = false, layout1 = "Layout1", layout2 = "None", layoutWait = 10, withdraw = false,
        layoutString = "", layoutExpected = 0, layoutLoading = false, rebirthing = false,
        -- ore boost
        oreBoost = false, oreBoostActive = false, loopCount = 1, useIndMine = false,
        useMoneyLoop = false, farmRP = false, primaryFurnace = "Auto", selectedMines = {}, oreCap = 1e250, maxWorkers = 6,
        oreSize = 0, upgraderSize = 1, autoResize = false, singleItem = "", autoPrompts = false,
        -- trackers
        trackOres = false, trackBoxes = false,
        -- boxes
        farmBoxes = false, boxSpeed = 30, safetyTeleport = false,
        selectedBox = "Regular", boxWait = 1,
        -- misc
        antiLeave = false, walk = 16, jump = 50,
    }
    local V = { furnace = nil, indMine = nil }
    local boostStatus, rebirthToggle, oreBoostToggle

    ------------------------------------------------------------------
    -- Small utilities
    ------------------------------------------------------------------
    local SUFFIXES = { "k", "M", "B", "T", "qd", "Qn", "sx", "Sp", "O", "N", "de", "Ud",
        "DD", "tdD", "qdD", "QnD", "sxD", "SpD", "OcD", "NvD", "Vgn" }

    local function shorten(n)
        if type(n) ~= "number" then return tostring(n) end
        if n ~= n then return "nan" end
        if n == math.huge then return "inf" end
        local neg = n < 0
        n = math.abs(n)
        local sign = neg and "-" or ""
        if n < 1000 then return sign .. tostring(math.floor(n)) end
        local idx = math.floor(math.log10(n) / 3)
        if idx > #SUFFIXES then return sign .. ("%.2e"):format(n) end
        return sign .. ("%.2f"):format(n / 10 ^ (3 * idx)) .. SUFFIXES[idx]
    end

    local function setStatus(text)
        if boostStatus then pcall(function() boostStatus:Set(text) end) end
    end

    local function showText(text)
        pcall(function()
            local parent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")
            local old = parent:FindFirstChild("ViyxText")
            if old then old:Destroy() end
            local gui = Instance.new("ScreenGui")
            gui.Name = "ViyxText"
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 999
            local box = Instance.new("TextBox")
            box.Size = UDim2.new(0.8, 0, 0.7, 0)
            box.Position = UDim2.new(0.1, 0, 0.15, 0)
            box.BackgroundColor3 = Color3.fromRGB(28, 20, 46)
            box.TextColor3 = Color3.fromRGB(240, 232, 255)
            box.MultiLine = true
            box.ClearTextOnFocus = false
            box.TextXAlignment = Enum.TextXAlignment.Left
            box.TextYAlignment = Enum.TextYAlignment.Top
            box.TextSize = 14
            box.Font = Enum.Font.Code
            box.Text = text
            box.Parent = gui
            local close = Instance.new("TextButton")
            close.Size = UDim2.new(0, 40, 0, 28)
            close.Position = UDim2.new(0.9, -40, 0.15, -30)
            close.Text = "X"
            close.BackgroundColor3 = Color3.fromRGB(140, 70, 220)
            close.TextColor3 = Color3.new(1, 1, 1)
            close.Parent = gui
            close.MouseButton1Click:Connect(function() gui:Destroy() end)
            gui.Parent = parent
            if setclipboard then pcall(setclipboard, text) end
        end)
    end

    local function getTycoon()
        local pt = LocalPlayer:FindFirstChild("PlayerTycoon")
        local t = pt and pt.Value
        if typeof(t) == "Instance" then return t end
        return getPlayerFactory()
    end

    local function getOres()
        local t = getTycoon()
        local dp = workspace:FindFirstChild("DroppedParts")
        return t and dp and dp:FindFirstChild(t.Name)
    end

    local function getRebirthCount()
        local r = LocalPlayer:FindFirstChild("Rebirths")
        return r and r.Value or nil
    end

    local function teleportToOwnBase()
        local t = getTycoon()
        local base = t and t:FindFirstChild("Base")
        local hrp = getHRP()
        if not (base and hrp) then return false end
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame = base.CFrame + Vector3.new(0, 10, 0)
        return true
    end

    local function teleportForLoad()
        if B.ghostLoad then return false end
        return teleportToOwnBase()
    end

    ------------------------------------------------------------------
    -- Rebirth price (game's MoneyLib first, local formula as fallback)
    ------------------------------------------------------------------
    local function formulaRebirthPrice(rebirths)
        local life = rebirths + 1
        if life >= 80351 then return 1e241 end
        local x = life - 1
        local cost
        if life <= 40 then
            cost = 2.5e19 * (x + 1)
        elseif life <= 5000 then
            cost = (1e19 * ((5 * math.floor(x / 5)) + 2.5) * ((100 * math.floor(x / 25)) + 1)
                * ((1000 * math.floor(x / 500)) + 1)) ^ ((0.00024 * x) + 1)
        else
            cost = (1e19 * ((5 * math.floor(x / 5)) + 2.5) * ((100 * math.floor(x / 25)) + 1)
                * ((1000 * math.floor(x / 500)) + 1))
                ^ ((0.00024 * math.floor(10 * ((12500 * (x ^ 4)) ^ (1 / 7)))) + 1)
        end
        if cost >= 1e241 then return 1e241 end
        return cost
    end

    local moneyLibFailed = false
    local function getRebirthPrice()
        if not moneyLibFailed then
            local ok, price = pcall(function()
                return require(RS.Modules.Game.MoneyLib).RebornPrice(LocalPlayer)
            end)
            if ok and type(price) == "number" then return price end
            moneyLibFailed = true
            warn("[MH] MoneyLib price unavailable, using built-in formula:", price)
        end
        return formulaRebirthPrice(getRebirthCount() or 0)
    end

    ------------------------------------------------------------------
    -- Items (ids, names)
    ------------------------------------------------------------------
    local itemMap
    local function getItemId(item)
        if not item then return nil end
        local a = tonumber(item:GetAttribute("ItemId"))
        if a then return a end
        local v = item:FindFirstChild("ItemId")
        return v and tonumber(v.Value) or nil
    end

    local function resolveItem(identifier)
        local items = RS:FindFirstChild("Items")
        if not items or identifier == nil then return nil end
        local direct = items:FindFirstChild(tostring(identifier))
        if direct then return direct end
        local wanted = tonumber(identifier)
        if not wanted then return nil end
        if not itemMap then
            itemMap = {}
            for _, it in ipairs(items:GetChildren()) do
                local id = getItemId(it)
                if id then itemMap[id] = it end
            end
        end
        return itemMap[wanted]
    end

    local function isItem(item)
        return item:FindFirstChild("ItemId") ~= nil or item:GetAttribute("ItemId") ~= nil
    end

    local function countPlaced()
        local t = getTycoon()
        if not t then return 0 end
        local n = 0
        for _, v in ipairs(t:GetChildren()) do
            if isItem(v) then n = n + 1 end
        end
        return n
    end

    ------------------------------------------------------------------
    -- Game data (item names)
    ------------------------------------------------------------------
    local function ML(cap, effect, minVal, minWait, isStar, cooldown)
        return { Cap = cap, Effect = effect, MinVal = minVal, MinWait = minWait, IsStar = isStar, Cooldown = cooldown }
    end
    local function STAR(cap) return ML(cap, "Fire", nil, 0.12, true, 1.55) end

    local MONEY_LOOPABLES = {
        ["Large Ore Upgrader"] = ML(50e3), ["Solar Large Upgrader"] = ML(50e3),
        ["Precision Refiner"] = ML(1e8, "Fire"), ["Rainbow Upgrader"] = ML(1e8),
        ["Way-Up-High Upgrader"] = ML(1e9), ["Digital Ore Cleaner"] = ML(10e9),
        ["Freon-Blast Upgrader"] = ML(125e9), ["Fire-Blast Upgrader"] = ML(64e9, "Fire"),
        ["Serpentine Upgrader"] = ML(1e12), ["Suspended Refiner"] = ML(1e18),
        ["Molten Upgrader"] = ML(50e18, nil, 1e12), ["Advanced Ore Atomizer"] = ML(1e21),
        ["Freon Suppressor"] = ML(100e21), ["Horizon Centrifuge"] = ML(1e24, nil, 1e21),
        ["Ore Thermocrusher"] = ML(100e24), ["Suspended Lava Refiner"] = ML(1e27),
        ["Ore Transistor"] = ML(1e30, nil, 1e24), ["Ore Transponder"] = ML(1e33),
        ["Morning Star"] = STAR(1e30), ["⭐ Celestial Morning Star ⭐"] = STAR(1e30),
        ["Red Giant"] = STAR(1e60), ["⭐ Wholesome Red Giant ⭐"] = STAR(1e60),
        ["Catalyzed Star"] = STAR(1e60), ["Neutron Star"] = STAR(1e72),
        ["⭐ Wholesome Neutron Star ⭐"] = STAR(1e72), ["Nova Star"] = STAR(1e72),
        ["Blue Supergiant"] = STAR(1e90), ["⭐ Hypergiant Blue Supergiant ⭐"] = STAR(1e90),
        ["Sinister Sepulcher"] = ML(1e99), ["Renegade Sinister Sepulcher"] = ML(1e99),
        ["⭐ Ornate Sinister Sepulcher ⭐"] = ML(1e99),
    }
    local RESET_GROUPS = {
        { "Void Star", "Black Dwarf", "⭐ Stargazed Black Dwarf ⭐", "⭐ Beloved Black Dwarf ⭐", "⭐ Stargazed Void Star ⭐" },
        { "Tesla Resetter", "⭐ Advanced Tesla Resetter ⭐", "⭐ Spooky Tesla Resetter ⭐", "Tesla Refuter", "⭐ Advanced Tesla Refuter ⭐" },
        { "The Final Upgrader", "The Ultimate Sacrifice" },
        { "Daestrophe" },
    }
    local RESETTER_SET = {}
    for _, group in ipairs(RESET_GROUPS) do
        for _, n in ipairs(group) do RESETTER_SET[n] = true end
    end
    local EFFECT_REMOVERS = { "Wild Spore", "Deadly Spore", "Azure Spore", "The Death Cap" }

    ------------------------------------------------------------------
    -- Finding parts on items
    ------------------------------------------------------------------
    local function hasTouch(part)
        return part ~= nil and (part:FindFirstChild("TouchInterest") ~= nil
            or part:FindFirstChildOfClass("TouchTransmitter") ~= nil)
    end

    local function toPart(inst)
        if not inst then return nil end
        if inst:IsA("BasePart") then return inst end
        if inst:IsA("Model") or inst:IsA("Folder") or inst:IsA("Configuration") then
            for _, d in ipairs(inst:GetDescendants()) do
                if d:IsA("BasePart") and hasTouch(d) then return d end
            end
            for _, d in ipairs(inst:GetDescendants()) do
                if d:IsA("BasePart") then return d end
            end
            if inst:IsA("Model") then return inst.PrimaryPart end
        end
        return nil
    end

    local UPGRADE_NAMES = { "Upgrade", "Upgrader", "Scan", "UpgraderPart" }
    local function upgradePart(item)
        if not item then return nil end
        for _, n in ipairs(UPGRADE_NAMES) do
            local part = toPart(item:FindFirstChild(n, true))
            if part and hasTouch(part) then return part end
        end
        for _, n in ipairs(UPGRADE_NAMES) do
            local part = toPart(item:FindFirstChild(n, true))
            if part then return part end
        end
        for _, d in ipairs(item:GetDescendants()) do
            if d:IsA("BasePart") and hasTouch(d) then
                local n = d.Name:lower()
                if n:find("upgrade", 1, true) or n:find("scan", 1, true)
                    or n:find("refine", 1, true) or n:find("advanc", 1, true) then
                    return d
                end
            end
        end
        if item:FindFirstChild("UpgraderShip", true) then
            for _, d in ipairs(item:GetDescendants()) do
                if d:IsA("BasePart") and hasTouch(d) then
                    local n = d.Name:lower()
                    if not n:find("lava", 1, true) and n ~= "hitbox" and n ~= "base" and n ~= "plane" then
                        return d
                    end
                end
            end
        end
        return nil
    end

    local LAVA_NAMES = { "Lava", "Lava1", "MiniLava", "Lava2" }
    local function lavaPart(item)
        if not item or not item.Parent then return nil end
        local model = item:FindFirstChild("Model") or item
        for _, n in ipairs(LAVA_NAMES) do
            local p = model:FindFirstChild(n, true)
            if p and p:IsA("BasePart") and not p:FindFirstChild("TeleportSend") then return p end
        end
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") and d.Name:lower():find("lava", 1, true) and not d:FindFirstChild("TeleportSend") then
                return d
            end
        end
        return nil
    end

    local function isFurnace(item)
        if not item or not item.Parent then return false end
        local model = item:FindFirstChild("Model")
        local hasMoney = item:FindFirstChild("MoneyScript", true) ~= nil
        if not model and not hasMoney then return false end
        local lava = lavaPart(item)
        if lava and lava:FindFirstChild("TeleportSend") then return false end
        if hasMoney then return true end
        return lava ~= nil and model ~= nil and model:FindFirstChild("Drop", true) == nil
    end

    local function isMine(item)
        local model = item and item:FindFirstChild("Model")
        return model ~= nil and model:FindFirstChild("Drop", true) ~= nil
    end

    local function refreshFurnace()
        local t = getTycoon()
        if not t then return nil end
        local pref = B.primaryFurnace
        if pref and pref ~= "" and pref ~= "Auto" then
            local f = t:FindFirstChild(pref)
            if isFurnace(f) then V.furnace = f end
        end
        for _, item in ipairs(t:GetChildren()) do
            if isFurnace(item) and not isFurnace(V.furnace) then V.furnace = item end
            if isMine(item) and not (V.indMine and V.indMine.Parent) then V.indMine = item end
        end
        return V.furnace
    end

    local function furnaceNames()
        local list, seen = { "Auto" }, { Auto = true }
        local t = getTycoon()
        if t then
            for _, v in ipairs(t:GetChildren()) do
                if isFurnace(v) and not seen[v.Name] then
                    seen[v.Name] = true
                    list[#list + 1] = v.Name
                end
            end
        end
        return list
    end

    local function mineNames()
        local list, seen = {}, {}
        local t = getTycoon()
        if t then
            for _, v in ipairs(t:GetChildren()) do
                if isMine(v) and not seen[v.Name] then
                    seen[v.Name] = true
                    list[#list + 1] = v.Name
                end
            end
        end
        return list
    end

    local function sellOre(ore)
        if not (ore and ore.Parent) then return end
        local furn
        local pref = B.primaryFurnace
        if pref and pref ~= "" and pref ~= "Auto" then
            local t = getTycoon()
            local f = t and t:FindFirstChild(pref)
            if isFurnace(f) then furn = f end
        end
        if not furn then
            if not isFurnace(V.furnace) then refreshFurnace() end
            furn = V.furnace
        end
        V.furnace = furn or V.furnace
        local lava = furn and lavaPart(furn)
        if lava then ore.CFrame = lava.CFrame + Vector3.new(0, 1, 0) end
    end

    ------------------------------------------------------------------
    -- Ore boost: teleport each ore through the upgraders, then sell it
    ------------------------------------------------------------------
    -- Overflow protection: an ore that gets too rich is sold instead of boosted
    -- further, otherwise cash overflows to inf and then becomes NaN.
    local capCache, capAt = 1e250, 0
    local function effectiveOreCap()
        if os.clock() - capAt > 2 then
            capAt = os.clock()
            local price = getRebirthPrice() * 1000 ^ B.skips
            capCache = math.min(1e290, math.max(B.oreCap, price * 1e6))
        end
        return capCache
    end

    local function oreTooRich(ore)
        local cash = ore:FindFirstChild("Cash")
        if not cash then return false end
        local v = cash.Value
        return v ~= v or v >= effectiveOreCap()
    end

    local function runThrough(ore, part)
        part = toPart(part)
        if not (ore and part) then return end
        for _ = 1, math.max(1, B.loopCount) do
            if not (Hub.Alive and B.oreBoostActive and ore.Parent and part.Parent) or oreTooRich(ore) then break end
            pcall(function()
                ore.Anchored = true
                ore.AssemblyLinearVelocity = Vector3.zero
                ore.AssemblyAngularVelocity = Vector3.zero
                ore.CFrame = part.CFrame + Vector3.new(0, 0.5, 0)
            end)
            task.wait(0.008)
            pcall(function() ore.Anchored = false end)
            task.wait(0.004)
        end
    end

    local function boostOre(ore)
        local t = getTycoon()
        if not t then return end
        for _, item in ipairs(t:GetChildren()) do
            if not (Hub.Alive and B.oreBoostActive and ore.Parent) or oreTooRich(ore) then return end
            if not RESETTER_SET[item.Name] and not (B.useMoneyLoop and MONEY_LOOPABLES[item.Name]) then
                local part = upgradePart(item)
                if part then
                    runThrough(ore, part)
                elseif isFurnace(item) then
                    local pref = B.primaryFurnace
                    local auto = (not pref or pref == "" or pref == "Auto")
                    if auto and not isFurnace(V.furnace) then
                        V.furnace = item
                    elseif not auto and item.Name == pref then
                        V.furnace = item
                    end
                elseif isMine(item) and not (V.indMine and V.indMine.Parent) then
                    V.indMine = item
                end
            end
        end
    end

    local function resetOre(ore)
        local t = getTycoon()
        if not t then return end
        boostOre(ore)
        for _, group in ipairs(RESET_GROUPS) do
            if not (Hub.Alive and B.oreBoostActive and ore.Parent) or oreTooRich(ore) then return end
            local item
            for _, n in ipairs(group) do
                item = t:FindFirstChild(n)
                if item then break end
            end
            local part = item and upgradePart(item)
            if part then
                runThrough(ore, part)
                boostOre(ore)
            end
        end
    end

    local function hitPart(ore, part, wait)
        if not (ore and part and part.Parent) then return end
        pcall(function()
            ore.Anchored = true
            ore.AssemblyLinearVelocity = Vector3.zero
            ore.AssemblyAngularVelocity = Vector3.zero
            ore.CFrame = part.CFrame + Vector3.new(0, 0.5, 0)
        end)
        task.wait(wait or 0.1)
        pcall(function() if ore.Parent then ore.Anchored = false end end)
    end

    local function protectPartOf(t)
        for _, n in ipairs(EFFECT_REMOVERS) do
            local item = t:FindFirstChild(n)
            if item then
                local p = upgradePart(item)
                if p then return p end
            end
        end
        return nil
    end

    local function moneyLoopActive(ore)
        return Hub.Alive and B.oreBoost and B.oreBoostActive and B.useMoneyLoop and ore.Parent and not oreTooRich(ore)
    end

    local function starLoop(ore, stars, protect)
        local cap = 0
        for _, s in ipairs(stars) do
            if s.Info.Cap and s.Info.Cap > cap then cap = s.Info.Cap end
        end
        if cap <= 0 then cap = 1e30 end
        local started = os.clock()
        while moneyLoopActive(ore) and os.clock() - started < 120 do
            local cash = ore:FindFirstChild("Cash")
            if not cash or cash.Value <= 0 or cash.Value >= cap then break end
            local hits = 0
            for _, s in ipairs(stars) do
                if not moneyLoopActive(ore) then break end
                cash = ore:FindFirstChild("Cash")
                if not cash or cash.Value <= 0 or cash.Value >= cap then break end
                if s.Item.Parent then
                    if not (s.Part and s.Part.Parent) then s.Part = upgradePart(s.Item) end
                    if s.Part then
                        local need = (s.LastHit + (s.Info.Cooldown or 1.55)) - os.clock()
                        if need > 0 then task.wait(need) end
                        if ore.Parent and s.Part.Parent then
                            hitPart(ore, s.Part, s.Info.MinWait or 0.12)
                            s.LastHit = os.clock()
                            hits = hits + 1
                            if s.Info.Effect and protect and protect.Parent and ore.Parent then
                                pcall(function() ore.CFrame = protect.CFrame + Vector3.new(0, 0.5, 0) end)
                                task.wait(0.06)
                            end
                        end
                    end
                end
            end
            if hits == 0 then break end
        end
    end

    local function normalLoop(ore, entries, protect)
        table.sort(entries, function(a, b) return (a.Info.Cap or 0) > (b.Info.Cap or 0) end)
        local info = entries[1].Info
        local cap = info.Cap or 1e30
        local started = os.clock()
        while moneyLoopActive(ore) and os.clock() - started < 120 do
            local cash = ore:FindFirstChild("Cash")
            if not cash or cash.Value <= 0 or cash.Value >= cap then break end
            if info.MinVal and cash.Value < info.MinVal then break end
            for _, e in ipairs(entries) do
                if not ore.Parent then break end
                cash = ore:FindFirstChild("Cash")
                if not cash or cash.Value >= cap then break end
                if not (e.Part and e.Part.Parent) then e.Part = upgradePart(e.Item) end
                if e.Part then
                    for _ = 1, math.max(1, B.loopCount) do
                        hitPart(ore, e.Part, info.MinWait or 0.01)
                        if info.Effect and protect then
                            pcall(function() ore.CFrame = protect.CFrame end)
                            task.wait(0.03)
                        end
                    end
                end
            end
            task.wait(0.02)
        end
    end

    local function runMoneyLoops(ore)
        local t = getTycoon()
        if not t then return end
        local stars, normals = {}, {}
        for name, info in pairs(MONEY_LOOPABLES) do
            for _, child in ipairs(t:GetChildren()) do
                if child.Name == name then
                    local part = upgradePart(child)
                    if part then
                        local entry = { Item = child, Info = info, Part = part, LastHit = 0 }
                        if info.IsStar then stars[#stars + 1] = entry else normals[#normals + 1] = entry end
                    end
                end
            end
        end
        local protect = protectPartOf(t)
        if #stars > 0 then
            starLoop(ore, stars, protect)
        elseif #normals > 0 then
            normalLoop(ore, normals, protect)
        end
    end

    local function runOreBoost(ore)
        local cash = ore:WaitForChild("Cash", 5)
        if not (Hub.Alive and cash and ore.Parent) then return end
        if cash.Value <= 0 then ore.Anchored = false; return end
        if B.useMoneyLoop then runMoneyLoops(ore) end
        if B.oreBoostActive and ore.Parent and not oreTooRich(ore) then resetOre(ore) end
        if ore.Parent then
            ore.AssemblyAngularVelocity = Vector3.zero
            ore.AssemblyLinearVelocity = Vector3.zero
            sellOre(ore)
        end
    end

    -- Worker pool: at most B.maxWorkers ores are boosted at once. Ores that arrive
    -- while every worker is busy wait in a queue instead of being skipped.
    local activeBoost, activeCount = {}, 0
    local boostQueue = {}
    local function startOreBoost(ore, selectedMode)
        if not (Hub.Alive and ore and ore.Parent) then return end
        if activeBoost[ore] then return end
        if activeCount >= B.maxWorkers then
            if #boostQueue < 80 then boostQueue[#boostQueue + 1] = ore end
            return
        end
        activeCount = activeCount + 1
        local current = ore
        while current do
            if current.Parent and not activeBoost[current] then
                activeBoost[current] = true
                local ok, err = pcall(runOreBoost, current)
                activeBoost[current] = nil
                if not ok then warn("[MH] ore boost error:", err) end
            end
            current = nil
            if not (Hub.Alive and B.oreBoost) then
                table.clear(boostQueue)
                break
            end
            while #boostQueue > 0 do
                local nextOre = table.remove(boostQueue, 1)
                if nextOre.Parent then current = nextOre; break end
            end
        end
        activeCount = math.max(0, activeCount - 1)
    end

    -- Which mine did this ore come from? (only used for "Mines to boost")
    local mineCache = setmetatable({}, { __mode = "k" })
    local function identifyMine(ore)
        local cached = mineCache[ore]
        if cached ~= nil then return cached or nil end
        local result
        for _, n in ipairs({ "Source", "Mine", "Origin", "DroppedFrom", "From" }) do
            local c = ore:FindFirstChild(n)
            if c then
                if c:IsA("ObjectValue") and c.Value then result = c.Value.Name; break end
                if c:IsA("StringValue") and c.Value ~= "" then result = c.Value; break end
            end
        end
        if not result then
            local a = ore:GetAttribute("Mine") or ore:GetAttribute("Source") or ore:GetAttribute("Origin")
            if a and tostring(a) ~= "" then result = tostring(a) end
        end
        if not result then
            local t = getTycoon()
            local best, bestDist = nil, 30
            if t and ore:IsA("BasePart") then
                for _, v in ipairs(t:GetChildren()) do
                    if isMine(v) then
                        local drop = v.Model:FindFirstChild("Drop", true)
                        if drop and drop:IsA("BasePart") then
                            local d = (drop.Position - ore.Position).Magnitude
                            if d < bestDist then bestDist, best = d, v.Name end
                        end
                    end
                end
            end
            result = best
        end
        mineCache[ore] = result or false
        return result
    end

    local function shouldBoostOre(ore)
        if next(B.selectedMines) then
            return B.selectedMines[identifyMine(ore)] == true, true
        end
        return true, false
    end

    ------------------------------------------------------------------
    -- Trackers (ore value / boxes), capped so they cannot lag the game
    ------------------------------------------------------------------
    local oreTags, boxTags = {}, {}
    local oreTagCount, boxTagCount = 0, 0

    local function makeTag(text)
        local gui = Instance.new("BillboardGui")
        gui.Name = "ViyxTag"
        gui.AlwaysOnTop = true
        gui.Size = UDim2.new(0, 200, 0, 50)
        gui.ExtentsOffset = Vector3.new(0, 2, 0)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(230, 210, 255)
        label.TextStrokeTransparency = 0
        label.TextScaled = true
        label.Font = Enum.Font.SourceSansBold
        label.Text = text
        label.Parent = gui
        return gui, label
    end

    local function addOreTag(ore)
        if oreTags[ore] or oreTagCount >= 50 then return end
        oreTags[ore] = true
        oreTagCount = oreTagCount + 1
        task.spawn(function()
            local cash = ore:WaitForChild("Cash", 5)
            if not (cash and ore.Parent and B.trackOres) then
                if oreTags[ore] then oreTags[ore] = nil; oreTagCount = math.max(0, oreTagCount - 1) end
                return
            end
            local gui, label = makeTag("$" .. shorten(cash.Value))
            gui.Adornee = ore
            gui.Parent = ore
            oreTags[ore] = gui
            local conn = cash.Changed:Connect(function() label.Text = "$" .. shorten(cash.Value) end)
            ore.Destroying:Connect(function()
                conn:Disconnect()
                if oreTags[ore] then oreTags[ore] = nil; oreTagCount = math.max(0, oreTagCount - 1) end
            end)
        end)
    end

    local function clearOreTags()
        for ore, gui in pairs(oreTags) do
            if typeof(gui) == "Instance" then gui:Destroy() end
            oreTags[ore] = nil
        end
        oreTagCount = 0
    end

    local function clearBoxTags()
        for box, gui in pairs(boxTags) do
            if typeof(gui) == "Instance" then gui:Destroy() end
            boxTags[box] = nil
        end
        boxTagCount = 0
    end

    local function boxAdornee(box)
        if box:IsA("BasePart") then return box end
        return box:FindFirstChild("Crate") or box:FindFirstChildWhichIsA("BasePart", true)
    end

    ------------------------------------------------------------------
    -- Ore hook (re-hooks if the ore folder changes)
    ------------------------------------------------------------------
    local function onOreAdded(ore)
        if not ore:IsA("BasePart") then return end
        if B.trackOres then addOreTag(ore) end
        if B.oreSize > 0 then ore.Size = Vector3.new(B.oreSize, B.oreSize, B.oreSize) end
        if B.oreBoost then
            local cashNow = getMoney()
            if cashNow ~= cashNow then return end  -- cash is NaN: stop boosting further
            if B.useIndMine and ore:FindFirstChild("Fuel") then
                refreshFurnace()
                local lava = lavaPart(V.indMine)
                if lava then ore.CFrame = lava.CFrame + Vector3.new(0, 1, 0) end
                return
            end
            local should, selectedMode = shouldBoostOre(ore)
            if should then startOreBoost(ore, selectedMode) end
        elseif B.farmRP then
            sellOre(ore)
        end
    end

    task.spawn(function()
        local hookedFolder, hookConn
        while Hub.Alive do
            local folder = getOres()
            if folder ~= hookedFolder then
                if hookConn then hookConn:Disconnect(); hookConn = nil end
                hookedFolder = folder
                if folder then
                    refreshFurnace()
                    hookConn = folder.ChildAdded:Connect(function(child)
                        if not Hub.Alive then return end
                        task.spawn(function()
                            local ok, err = pcall(onOreAdded, child)
                            if not ok then warn("[MH] ore error:", err) end
                        end)
                    end)
                    table.insert(Hub.Conns, hookConn)
                end
            end
            task.wait(2)
        end
    end)

    ------------------------------------------------------------------
    -- Item size helpers + kill ores
    ------------------------------------------------------------------
    local function resizeUpgrader(item)
        local up = upgradePart(item)
        if not (up and up:IsA("BasePart")) then return end
        local base = up:FindFirstChild("BaseSize")
        if not base then
            base = Instance.new("Vector3Value")
            base.Name = "BaseSize"
            base.Value = up.Size
            base.Parent = up
        end
        up.Size = base.Value * B.upgraderSize
    end

    local function resizeAll()
        local t = getTycoon()
        if not t then return end
        for _, item in ipairs(t:GetChildren()) do
            if isItem(item) then pcall(resizeUpgrader, item) end
        end
    end

    local function killOres()
        local t, ores = getTycoon(), getOres()
        if not (t and ores and t:FindFirstChild("Base")) then return end
        for _, ore in ipairs(ores:GetChildren()) do
            if ore:IsA("BasePart") then ore.CFrame = t.Base.CFrame end
        end
    end

    ------------------------------------------------------------------
    -- Layout strings (export / import through PlaceItem)
    ------------------------------------------------------------------
    local function decodeCFrame(raw)
        if typeof(raw) == "CFrame" then return raw end
        local values = {}
        if type(raw) == "table" then
            for i = 1, math.min(#raw, 12) do
                local v = tonumber(raw[i])
                if not v then return nil end
                values[#values + 1] = v
            end
        elseif type(raw) == "string" then
            for token in string.gmatch(raw, "[^,]+") do
                local clean = token:match("^%s*(.-)%s*$"):gsub("^%(", ""):gsub("%)$", "")
                local v = tonumber(clean)
                if not v then return nil end
                values[#values + 1] = v
                if #values == 12 then break end
            end
        else
            return nil
        end
        if #values >= 12 then return CFrame.new(table.unpack(values, 1, 12)) end
        if #values == 3 then return CFrame.new(values[1], values[2], values[3]) end
        return nil
    end

    local function placeEntry(identifier, rawPos)
        local item = resolveItem(identifier)
        if not item then return false, "item not found: " .. tostring(identifier) end
        local itemId = getItemId(item)
        local cf = decodeCFrame(rawPos)
        local t = getTycoon()
        local base = t and t:FindFirstChild("Base")
        if not (itemId and cf and base) then return false, "invalid item, position or base" end

        local function tryPlace()
            local ok, placed, code = callRemote("PlaceItem", itemId, cf + base.Position, { base })
            if ok and placed ~= false then return true end
            return false, tostring(code or placed)
        end

        local ok, why = tryPlace()
        if ok then return true end
        -- not in inventory: buy it once if it is a cash shop item, then retry
        local itemType, cost = item:FindFirstChild("ItemType"), item:FindFirstChild("Cost")
        if itemType and cost and itemType.Value >= 1 and itemType.Value < 5 and getMoney() >= cost.Value then
            callRemote("BuyItem", itemId, 1)
            ok, why = tryPlace()
            if ok then return true end
        end
        return false, why
    end

    local function waitSettle(timeout, minItems)
        local deadline = os.clock() + (timeout or 12)
        local last, stable = -1, 0
        while os.clock() < deadline do
            local c = countPlaced()
            if c == last and c >= (minItems or 1) then
                stable = stable + 0.2
                if stable >= 1 then return c end
            else
                stable, last = 0, c
            end
            task.wait(0.2)
        end
        return countPlaced()
    end

    local function importLayout(entries, getEntry)
        local queue = {}
        for _, e in ipairs(entries) do queue[#queue + 1] = e end
        if #queue == 0 then
            for _, e in pairs(entries) do queue[#queue + 1] = e end
        end
        local expected = #queue
        if expected == 0 then return 0 end
        local nextIndex, placed, firstIssue, finished = 1, 0, nil, 0
        local workers = math.min(4, expected)
        for _ = 1, workers do
            task.spawn(function()
                while Hub.Alive do
                    local index = nextIndex
                    nextIndex = nextIndex + 1
                    if index > expected then break end
                    local identifier, pos = getEntry(queue[index])
                    local ok, issue = placeEntry(identifier, pos)
                    if ok then placed = placed + 1 elseif not firstIssue then firstIssue = issue end
                    task.wait()
                end
                finished = finished + 1
            end)
        end
        while finished < workers and Hub.Alive do task.wait() end
        local settled = placed > 0 and waitSettle(12, math.max(1, math.floor(placed * 0.5))) or 0
        if firstIssue then
            notify("Layout import", ("Placed %d/%d. %s"):format(placed, expected, tostring(firstIssue)), 8)
        end
        return math.max(placed, settled)
    end

    local function loadStringLayout(text)
        if type(text) ~= "string" or text == "" then return 0 end
        local ok, layout = pcall(function() return HttpService:JSONDecode(text) end)
        if not ok or type(layout) ~= "table" then
            notify("Layout string", "The layout string could not be parsed.", 8)
            return 0
        end
        local entries = type(layout.Items) == "table" and layout.Items or layout
        return importLayout(entries, function(e)
            return e[1] or e.Name or e.ItemId, e[2] or e.Pos or e.CFrame
        end)
    end

    local function exportBaseString()
        local t = getTycoon()
        local base = t and t:FindFirstChild("Base")
        if not base then return nil end
        local list = {}
        for _, v in ipairs(t:GetChildren()) do
            local id = getItemId(v)
            local hitbox = v:FindFirstChild("Hitbox")
            if id and hitbox and hitbox:IsA("BasePart") then
                list[#list + 1] = { id, tostring(hitbox.CFrame - base.Position) }
            end
        end
        return HttpService:JSONEncode(list)
    end

    ------------------------------------------------------------------
    -- Loading layouts (with verification)
    ------------------------------------------------------------------
    local function loadOneLayout(name)
        if not name or name == "None" then return countPlaced() end
        if name == "Layout String" then
            if B.layoutString ~= "" then return loadStringLayout(B.layoutString) end
            notify("Layout string", "The layout string is empty.")
            return 0
        end
        callRemote("Layouts", "Load", name)
        return waitSettle(14, 1)
    end

    local function looksComplete(expected, fraction)
        local have = countPlaced()
        if expected and expected > 0 then
            return have >= math.max(1, math.floor(expected * (fraction or 0.9)))
        end
        return have >= 5
    end

    local function loadLayouts()
        B.layoutLoading = true
        local ok, err = pcall(function()
            teleportForLoad()
            task.wait(0.15)
            if B.oreBoost then B.oreBoostActive = true end
            callRemote("DestroyAll")
            task.wait(0.15)

            local expected = loadOneLayout(B.layout1) or 0
            if not looksComplete(expected, 0.5) then
                teleportForLoad()
                task.wait(0.1)
                callRemote("DestroyAll")
                task.wait(0.15)
                expected = loadOneLayout(B.layout1) or expected
            end

            if B.layout2 ~= "None" then
                task.wait(B.layoutWait)
                B.oreBoostActive = false
                task.wait(0.3)
                if B.withdraw then
                    callRemote("DestroyAll")
                    task.wait(0.15)
                end
                teleportForLoad()
                local second = loadOneLayout(B.layout2)
                if B.withdraw then expected = second or countPlaced() else expected = countPlaced() end
                if not looksComplete(expected, 0.85) then
                    teleportForLoad()
                    task.wait(0.1)
                    if B.withdraw then callRemote("DestroyAll"); task.wait(0.15) end
                    local retry = loadOneLayout(B.layout2)
                    if B.withdraw then expected = retry or expected else expected = math.max(expected, countPlaced()) end
                end
                task.wait(0.1)
                if B.oreBoost then B.oreBoostActive = true end
            end

            local settled = waitSettle(3, 1)
            B.layoutExpected = (expected and expected > 0) and math.max(expected, settled) or settled
            if B.autoResize then resizeAll() end
            V.furnace, V.indMine = nil, nil
            refreshFurnace()
        end)
        B.layoutLoading = false
        if B.oreBoost then B.oreBoostActive = true end
        if not ok then warn("[MH] loadLayouts error:", err) end
    end

    local lastReload, reloadFails = 0, 0
    local function ensureLayout()
        if B.layoutLoading or B.rebirthing or not B.autoRebirth then return end
        if B.layoutExpected <= 0 then return end
        local have = countPlaced()
        local needed = math.max(1, math.floor(B.layoutExpected * 0.9))
        if have >= needed then reloadFails = 0; return end
        if os.clock() - lastReload < 6 then return end
        if reloadFails >= 3 then
            if have > 0 then B.layoutExpected, reloadFails = have, 0 end
            return
        end
        lastReload = os.clock()
        loadLayouts()
        if countPlaced() >= needed then reloadFails = 0 else reloadFails = reloadFails + 1 end
    end

    ------------------------------------------------------------------
    -- Auto rebirth cycle
    ------------------------------------------------------------------
    local nextRebirthAt = 0
    local nanRetryAt, nanWarned = 0, false
    local function rollWait()
        local lo, hi = math.max(0, B.minWait), math.max(0, B.maxWait)
        if hi < lo then lo, hi = hi, lo end
        if hi <= lo then return lo end
        return lo + math.random() * (hi - lo)
    end

    local function autoRebirthStep()
        if B.rebirthing or B.layoutLoading then return end
        local count = getRebirthCount() or 0
        if B.stopLife > 0 and count >= B.stopLife then
            setStatus("Stopped: reached rebirth " .. count)
            B.autoRebirth = false
            pcall(function() rebirthToggle:Set(false) end)
            return
        end

        local price = getRebirthPrice() * 1000 ^ B.skips
        local money = getMoney()
        local remaining = nextRebirthAt - os.clock()
        setStatus(("Cash %s / need %s%s"):format(shorten(money), shorten(price),
            remaining > 0 and (" | wait " .. math.ceil(remaining) .. "s") or ""))
        local isNaN = (money ~= money)
        if isNaN and not nanWarned then
            nanWarned = true
            notify("Cash is NaN", "Your cash overflowed. Trying to rebirth every 5s to recover. Lower the loop count / ore cap to avoid this.", 12)
        elseif not isNaN then
            nanWarned = false
        end
        local canAfford = (money == math.huge) or (money > price) or (isNaN and os.clock() >= nanRetryAt)
        if not canAfford or remaining > 0 then return end
        if isNaN then nanRetryAt = os.clock() + 5 end

        B.rebirthing = true
        B.oreBoostActive = false
        local before = getRebirthCount()
        local ok, err = pcall(function()
            task.wait(0.1)
            callRemote("Rebirth")
            local deadline = os.clock() + 3
            local done = false
            while os.clock() < deadline do
                local now = getRebirthCount()
                if (before and now and now > before) or getMoney() < money * 0.5 then done = true; break end
                task.wait(0.1)
            end
            if not done then
                nextRebirthAt = os.clock() + rollWait()
                return
            end
            local now = getRebirthCount() or 0
            if B.stopLife > 0 and now >= B.stopLife then
                B.autoRebirth, B.oreBoost, B.oreBoostActive = false, false, false
                pcall(function() rebirthToggle:Set(false) end)
                pcall(function() oreBoostToggle:Set(false) end)
                return
            end
            task.wait(2)
            if B.autoRebirth then
                loadLayouts()
                nextRebirthAt = os.clock() + rollWait()
            end
        end)
        B.rebirthing = false
        B.layoutLoading = false
        if B.oreBoost and B.autoRebirth then B.oreBoostActive = true end
        if not ok then
            warn("[MH] auto rebirth error:", err)
            nextRebirthAt = os.clock() + rollWait()
        end
    end

    -- Stop on Slipstream: watch the game's own "item obtained" channel
    local slipstreams = { "None" }
    do
        local items = RS:FindFirstChild("Items")
        if items then
            for _, v in ipairs(items:GetChildren()) do
                local tier = v:FindFirstChild("Tier")
                if tier and tier.Value == 78 then slipstreams[#slipstreams + 1] = v.Name end
            end
        end
    end
    task.spawn(function()
        local ch
        for _ = 1, 20 do
            ch = joltChannel("ItemObtained")
            if ch then break end
            task.wait(1)
        end
        if not ch then return end
        pcall(function()
            table.insert(Hub.Conns, ch:Connect(function(item)
                if not Hub.Alive or B.stopSlip == "None" then return end
                if typeof(item) == "Instance" and item.Name == B.stopSlip then
                    B.autoRebirth, B.oreBoost, B.oreBoostActive = false, false, false
                    pcall(function() rebirthToggle:Set(false) end)
                    pcall(function() oreBoostToggle:Set(false) end)
                    notify("Stop on Slipstream", "You got " .. item.Name .. ". Auto rebirth stopped.", 10)
                end
            end))
        end)
    end)

    -- Auto fire proximity prompts on the base
    local cachedPrompts, nextPromptScan = {}, 0
    local function firePrompts()
        if B.rebirthing or B.layoutLoading then return end
        local now = os.clock()
        if now >= nextPromptScan then
            cachedPrompts = {}
            local t = getTycoon()
            if t then
                for _, d in ipairs(t:GetDescendants()) do
                    if d:IsA("ProximityPrompt") then cachedPrompts[#cachedPrompts + 1] = d end
                end
            end
            nextPromptScan = now + 1
        end
        for _, p in ipairs(cachedPrompts) do
            if p.Parent and p.Enabled ~= false then
                pcall(function() p:InputHoldBegin() end)
                pcall(function() p:InputHoldEnd() end)
                if fireproximityprompt then pcall(fireproximityprompt, p) end
            end
        end
    end

    ------------------------------------------------------------------
    -- Box farming
    ------------------------------------------------------------------
    local boxFilter = { research = true, golden = true, diamond = true, lucky = true,
        shadow = true, crystal = true, others = true }
    local collecting = false

    local function shouldFarm(name)
        name = name:lower()
        if name:find("crystal") then return boxFilter.crystal end
        if name:find("research") or name:find("basic") then return boxFilter.research end
        if name:find("golden") or name:find("gold") then return boxFilter.golden end
        if name:find("diamond") then return boxFilter.diamond end
        if name:find("lucky") then return boxFilter.lucky end
        if name:find("shadow") then return boxFilter.shadow end
        return boxFilter.others
    end

    local function collectBoxes(force)
        if collecting or B.rebirthing or B.layoutLoading then return end
        if not (force or B.farmBoxes) then return end
        local folder = workspace:FindFirstChild("Boxes")
        if not (folder and getHRP()) then return end
        collecting = true
        local ok, err = pcall(function()
            for _, box in ipairs(folder:GetChildren()) do
                if not Hub.Alive or not (force or B.farmBoxes) or B.rebirthing or B.layoutLoading then break end
                local root = getHRP()
                if not root then break end
                if shouldFarm(box.Name) then
                    local cf
                    if box:IsA("Model") and box:FindFirstChild("Crate") then
                        cf = box.Crate.CFrame
                    else
                        cf = getTargetCFrame(box)
                    end
                    if cf then
                        root.CFrame = cf
                        task.wait((101 - B.boxSpeed) / 100)
                    end
                end
            end
            if B.safetyTeleport then teleportToOwnBase() end
        end)
        collecting = false
        if not ok then warn("[MH] box farm error:", err) end
    end



    ------------------------------------------------------------------
    -- Menus (vendors) + blueprints
    ------------------------------------------------------------------
    local function openMenu(name)
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local gui = pg and pg:FindFirstChild("GUI")
        local menus = pg and pg:FindFirstChild("Menus")
        local focus = gui and gui:FindFirstChild("FocusWindow")
        if focus and focus.Value then
            local f = focus.Value
            if f:IsA("LayerCollector") then f.Enabled = false elseif f:IsA("GuiObject") then f.Visible = false end
            task.wait(0.01)
            focus.Value = nil
        end
        local ui = (menus and menus:FindFirstChild(name, true)) or (gui and gui:FindFirstChild(name, true))
        if not ui then notify("Menu", name .. " not found"); return end
        if ui:IsA("LayerCollector") then
            ui.Enabled = true
        elseif ui:IsA("GuiObject") then
            ui.Visible = true
        else
            return
        end
        if focus then focus.Value = ui end
    end

    local function blueprintList()
        local list = {}
        local items = RS:FindFirstChild("Items")
        if not items then return list end
        for _, v in ipairs(items:GetChildren()) do
            local tier = v:FindFirstChild("Tier")
            local price = v:FindFirstChild("BlueprintPrice")
            if tier and tier.Value ~= 78 and price then
                list[#list + 1] = { getItemId(v), price.Value }
            end
        end
        return list
    end

    ------------------------------------------------------------------
    -- Music (client side only)
    ------------------------------------------------------------------
    local function getClientSound(name)
        local s = SoundService:FindFirstChild(name, true)
        if s and s:IsA("Sound") then return s end
        return nil
    end
    local function replaceSound(name, value, play)
        local id = tostring(value or ""):match("(%d+)")
        if not id then notify("Music", "Enter a valid Roblox audio asset ID."); return false end
        local sound = getClientSound(name)
        if not sound then notify("Music", "Could not find sound: " .. name); return false end
        sound.SoundId = "rbxassetid://" .. id
        if play then pcall(function() sound.TimePosition = 0; sound:Play() end) end
        return true
    end
    local MUSIC_PRESETS = {
        ["Halloween Day"] = { ClientBackgroundMusic = 5707767063, ["Day ambience"] = 9733943062 },
        ["Halloween Night"] = { ClientBackgroundMusic = 5707766686, ["Night ambience"] = 9733940528 },
        ["Normal Night"] = { ClientBackgroundMusic = 6454368847, ["Night ambience"] = 9733940528 },
    }
    local RADIO_TRACKS = {
        Mesmerize = 404060129, Roots = 474419296, ["Cloud 9"] = 385287232,
        ["Track 404064184"] = 404064184, Magic = 385290279, ["Track 428553983"] = 428553983,
        Dreams = 385285034, ["Tobu - Candyland"] = 335695249,
    }

    ------------------------------------------------------------------
    -- Cleanup when the script is re-executed
    ------------------------------------------------------------------
    table.insert(Hub.Cleanups, function()
        B.autoRebirth, B.oreBoost, B.oreBoostActive, B.farmRP = false, false, false, false
        B.farmBoxes, B.autoPrompts, B.antiLeave = false, false, false
        B.trackOres, B.trackBoxes = false, false
        clearOreTags()
        clearBoxTags()
    end)

    ------------------------------------------------------------------
    -- BOOST TAB
    ------------------------------------------------------------------
    do
    BoostTab:CreateSection("Smart Auto Rebirth · MX6 / Viyx")
    boostStatus = BoostTab:CreateLabel("Status: idle")

    rebirthToggle = BoostTab:CreateToggle({
        Name = "Auto Rebirth (real game price)",
        CurrentValue = false,
        Flag = "VxAutoRebirth",
        Callback = function(state)
            B.autoRebirth = state
            nextRebirthAt = 0
            if state then B.layoutExpected = 0; reloadFails = 0 end
            setLoop("vxAutoRebirth", state, 0.4, function()
                autoRebirthStep()
                ensureLayout()
            end)
            if not state then setStatus("Status: stopped") end
        end,
    })

    BoostTab:CreateInput({
        Name = "Wait after layout: min (seconds)",
        CurrentValue = "7",
        PlaceholderText = "7",
        RemoveTextAfterFocusLost = false,
        Flag = "VxMinWait",
        Callback = function(text) B.minWait = math.max(0, tonumber(text) or 7) end,
    })
    BoostTab:CreateInput({
        Name = "Wait after layout: max (seconds)",
        CurrentValue = "20",
        PlaceholderText = "20",
        RemoveTextAfterFocusLost = false,
        Flag = "VxMaxWait",
        Callback = function(text) B.maxWait = math.max(0, tonumber(text) or 20) end,
    })
    BoostTab:CreateLabel("A random wait between min and max happens before each rebirth. Set both the same for a fixed wait.")

    BoostTab:CreateSlider({
        Name = "Wait for skips (price x1000 per skip)",
        Range = { 0, 20 },
        Increment = 1,
        Suffix = "skips",
        CurrentValue = 0,
        Flag = "VxSkips",
        Callback = function(v) B.skips = v end,
    })
    BoostTab:CreateInput({
        Name = "Stop at rebirth count (0 = never)",
        CurrentValue = "0",
        PlaceholderText = "0",
        RemoveTextAfterFocusLost = false,
        Flag = "VxStopLife",
        Callback = function(text) B.stopLife = tonumber(text) or 0 end,
    })
    BoostTab:CreateDropdown({
        Name = "Stop when you get this Slipstream",
        Options = slipstreams,
        CurrentOption = { "None" },
        MultipleOptions = false,
        Flag = "VxStopSlip",
        Callback = function(sel) B.stopSlip = firstOption(sel) or "None" end,
    })

    BoostTab:CreateSection("Layouts (loaded after every rebirth)")
    BoostTab:CreateToggle({
        Name = "Ghost Load (do not teleport to base before loading)",
        CurrentValue = false,
        Flag = "VxGhostLoad",
        Callback = function(state) B.ghostLoad = state end,
    })
    BoostTab:CreateDropdown({
        Name = "First layout (ore boost layout)",
        Options = { "Layout1", "Layout2", "Layout3", "Layout String" },
        CurrentOption = { "Layout1" },
        MultipleOptions = false,
        Flag = "VxLayout1",
        Callback = function(sel) B.layout1 = firstOption(sel) or "Layout1" end,
    })
    BoostTab:CreateDropdown({
        Name = "Second layout (loaded after the wait)",
        Options = { "None", "Layout1", "Layout2", "Layout3", "Layout String" },
        CurrentOption = { "None" },
        MultipleOptions = false,
        Flag = "VxLayout2",
        Callback = function(sel) B.layout2 = firstOption(sel) or "None" end,
    })
    BoostTab:CreateInput({
        Name = "Second layout wait (seconds)",
        CurrentValue = "10",
        PlaceholderText = "10",
        RemoveTextAfterFocusLost = false,
        Flag = "VxLayoutWait",
        Callback = function(text) B.layoutWait = tonumber(text) or 10 end,
    })
    BoostTab:CreateToggle({
        Name = "Clear base between layouts",
        CurrentValue = false,
        Flag = "VxWithdraw",
        Callback = function(state) B.withdraw = state end,
    })
    BoostTab:CreateButton({
        Name = "Load layouts now",
        Callback = function() task.spawn(loadLayouts) end,
    })

    BoostTab:CreateSection("Layout string (share or back up a base)")
    local layoutInput
    layoutInput = BoostTab:CreateInput({
        Name = "Layout string",
        CurrentValue = "",
        PlaceholderText = "paste a layout string",
        RemoveTextAfterFocusLost = false,
        Flag = "VxLayoutString",
        Callback = function(text) B.layoutString = text or "" end,
    })
    BoostTab:CreateButton({
        Name = "Copy my current base as a layout string",
        Callback = function()
            local s = exportBaseString()
            if not s then notify("Layout string", "Could not read your base."); return end
            B.layoutString = s
            if setclipboard then pcall(setclipboard, s) end
            pcall(function() layoutInput:Set(s) end)
            notify("Layout string", "Copied (" .. #s .. " characters).")
        end,
    })
    BoostTab:CreateButton({
        Name = "Clear base and load the layout string",
        Callback = function()
            task.spawn(function()
                teleportForLoad()
                callRemote("DestroyAll")
                task.wait(0.3)
                loadStringLayout(B.layoutString)
            end)
        end,
    })

    BoostTab:CreateSection("Ore Boost & Furnace Automation")
    oreBoostToggle = BoostTab:CreateToggle({
        Name = "Ore Boost",
        CurrentValue = false,
        Flag = "VxOreBoost",
        Callback = function(state)
            B.oreBoost = state
            B.oreBoostActive = state
        end,
    })

    BoostTab:CreateLabel("Primary furnace = where ore is sold after boosting. Auto uses the first one found.")
    local furnaceDropdown
    furnaceDropdown = BoostTab:CreateDropdown({
        Name = "Primary furnace (from your base)",
        Options = furnaceNames(),
        CurrentOption = { "Auto" },
        MultipleOptions = false,
        Flag = "VxFurnace",
        Callback = function(sel)
            B.primaryFurnace = firstOption(sel) or "Auto"
            V.furnace = nil
            refreshFurnace()
        end,
    })
    BoostTab:CreateInput({
        Name = "Primary furnace name (exact)",
        CurrentValue = "",
        PlaceholderText = "or type Auto",
        RemoveTextAfterFocusLost = false,
        Flag = "VxFurnaceName",
        Callback = function(text)
            local name = (text or ""):match("^%s*(.-)%s*$")
            if name == "" then name = "Auto" end
            B.primaryFurnace = name
            V.furnace = nil
            refreshFurnace()
            pcall(function() furnaceDropdown:Set({ name }) end)
        end,
    })
    BoostTab:CreateButton({
        Name = "Refresh furnace list",
        Callback = function() pcall(function() furnaceDropdown:Refresh(furnaceNames()) end) end,
    })

    BoostTab:CreateLabel("Mines to boost: leave empty to boost every mine, or pick the ones you want boosted.")
    local function setMines(names)
        B.selectedMines = {}
        for _, n in ipairs(names or {}) do
            if n and n ~= "" and n ~= "None" then B.selectedMines[n] = true end
        end
    end
    local mineDropdown
    mineDropdown = BoostTab:CreateDropdown({
        Name = "Mines to boost",
        Options = mineNames(),
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "VxMines",
        Callback = function(sel) setMines(sel) end,
    })
    BoostTab:CreateInput({
        Name = "Mines to boost (names, comma separated)",
        CurrentValue = "",
        PlaceholderText = "Havium Mine, Pumpkinite Mine",
        RemoveTextAfterFocusLost = false,
        Flag = "VxMinesInput",
        Callback = function(text)
            local names = {}
            for name in string.gmatch(text or "", "[^,]+") do
                name = name:match("^%s*(.-)%s*$")
                if name ~= "" then names[#names + 1] = name end
            end
            setMines(names)
            pcall(function() mineDropdown:Set(names) end)
        end,
    })
    BoostTab:CreateButton({
        Name = "Refresh mine list",
        Callback = function() pcall(function() mineDropdown:Refresh(mineNames()) end) end,
    })

    BoostTab:CreateSlider({
        Name = "Upgrade loop count (times per upgrader)",
        Range = { 1, 5 },
        Increment = 1,
        Suffix = "loops",
        CurrentValue = 1,
        Flag = "VxLoopCount",
        Callback = function(v) B.loopCount = v end,
    })
    BoostTab:CreateSlider({
        Name = "Ores boosted at the same time",
        Range = { 1, 20 },
        Increment = 1,
        Suffix = "ores",
        CurrentValue = 6,
        Flag = "VxMaxWorkers",
        Callback = function(v) B.maxWorkers = v end,
    })
    BoostTab:CreateToggle({
        Name = "Using Industrial Mine (fuel ores)",
        CurrentValue = false,
        Flag = "VxIndMine",
        Callback = function(state) B.useIndMine = state end,
    })
    BoostTab:CreateToggle({
        Name = "Use money loopables (loop until item cap)",
        CurrentValue = false,
        Flag = "VxMoneyLoop",
        Callback = function(state) B.useMoneyLoop = state end,
    })
    BoostTab:CreateInput({
        Name = "Max ore value before selling (protects from NaN cash)",
        CurrentValue = "1e250",
        PlaceholderText = "1e250",
        RemoveTextAfterFocusLost = false,
        Flag = "VxOreCap",
        Callback = function(text) B.oreCap = math.clamp(tonumber(text) or 1e250, 1e9, 1e290) end,
    })
    BoostTab:CreateToggle({
        Name = "Farm RP (sell every ore, turns off Ore Boost + Auto Rebirth)",
        CurrentValue = false,
        Flag = "VxFarmRP",
        Callback = function(state)
            B.farmRP = state
            if state then
                B.oreBoost, B.oreBoostActive, B.autoRebirth = false, false, false
                pcall(function() oreBoostToggle:Set(false) end)
                pcall(function() rebirthToggle:Set(false) end)
            end
        end,
    })
    BoostTab:CreateToggle({
        Name = "Auto fire proximity prompts on base",
        CurrentValue = false,
        Flag = "VxPrompts",
        Callback = function(state)
            B.autoPrompts = state
            setLoop("vxPrompts", state, 0.5, firePrompts)
        end,
    })

    BoostTab:CreateSection("Item manipulation")
    BoostTab:CreateSlider({
        Name = "Ore size (value / 10, 0 = off)",
        Range = { 0, 100 },
        Increment = 1,
        Suffix = "size",
        CurrentValue = 0,
        Flag = "VxOreSize",
        Callback = function(v) B.oreSize = v / 10 end,
    })
    BoostTab:CreateSlider({
        Name = "Upgrader size",
        Range = { 1, 20 },
        Increment = 1,
        Suffix = "x",
        CurrentValue = 1,
        Flag = "VxUpgSize",
        Callback = function(v) B.upgraderSize = v end,
    })
    BoostTab:CreateInput({
        Name = "Item name (case sensitive)",
        CurrentValue = "",
        PlaceholderText = "Name",
        RemoveTextAfterFocusLost = false,
        Flag = "VxItemName",
        Callback = function(text) B.singleItem = text end,
    })
    BoostTab:CreateButton({
        Name = "Resize single item",
        Callback = function()
            local t = getTycoon()
            local item = t and t:FindFirstChild(B.singleItem)
            if item then pcall(resizeUpgrader, item) else notify("Resize", "Item not found") end
        end,
    })
    BoostTab:CreateButton({ Name = "Resize all upgraders", Callback = resizeAll })
    BoostTab:CreateToggle({
        Name = "Auto resize upgraders after loading layouts",
        CurrentValue = false,
        Flag = "VxAutoResize",
        Callback = function(state) B.autoResize = state end,
    })
    BoostTab:CreateButton({ Name = "Kill ores", Callback = killOres })
    BoostTab:CreateInput({
        Name = "Auto kill ores every N seconds (0 = off)",
        CurrentValue = "0",
        PlaceholderText = "0",
        RemoveTextAfterFocusLost = false,
        Flag = "VxAutoKill",
        Callback = function(text)
            local n = tonumber(text) or 0
            setLoop("vxAutoKill", n > 0, math.max(n, 0.1), killOres)
        end,
    })

    BoostTab:CreateSection("Tracking")
    BoostTab:CreateToggle({
        Name = "Track ore value (max 50 ores)",
        CurrentValue = false,
        Flag = "VxTrackOres",
        Callback = function(state)
            B.trackOres = state
            if state then
                local ores = getOres()
                if ores then
                    for _, ore in ipairs(ores:GetChildren()) do
                        if ore:IsA("BasePart") then addOreTag(ore) end
                    end
                end
            else
                clearOreTags()
            end
        end,
    })

    BoostTab:CreateSection("Debug & Credits")
    BoostTab:CreateLabel("Viyx 1.5 | Source functionality: Viyx, MX6 & A4. This is not an official game tool.")
    BoostTab:CreateButton({
        Name = "Scan my factory (shows copyable text)",
        Callback = function()
            local lines = {}
            local t = getTycoon()
            lines[#lines + 1] = "Tycoon: " .. (t and t:GetFullName() or "NOT FOUND")
            lines[#lines + 1] = "Rebirths: " .. tostring(getRebirthCount()) .. " | Cash: " .. shorten(getMoney())
            lines[#lines + 1] = "Rebirth price: " .. shorten(getRebirthPrice())
            local ores = getOres()
            lines[#lines + 1] = "Ore folder: " .. (ores and (ores:GetFullName() .. " (" .. #ores:GetChildren() .. " ores)") or "NOT FOUND")
            refreshFurnace()
            lines[#lines + 1] = "Furnace: " .. (V.furnace and V.furnace.Name or "none") .. " | Mine: " .. (V.indMine and V.indMine.Name or "none")
            lines[#lines + 1] = "Placed items: " .. countPlaced()
            lines[#lines + 1] = "-- items (Name | ItemId | Model | UpgradePart | Furnace | Mine) --"
            if t then
                for i, item in ipairs(t:GetChildren()) do
                    if i > 120 then lines[#lines + 1] = "..."; break end
                    lines[#lines + 1] = ("%s | %s | %s | %s | %s | %s"):format(item.Name,
                        tostring(isItem(item)), tostring(item:FindFirstChild("Model") ~= nil),
                        tostring(upgradePart(item) ~= nil), tostring(isFurnace(item)), tostring(isMine(item)))
                end
            end
            showText(table.concat(lines, "\n"))
        end,
    })

    end

    ------------------------------------------------------------------
    -- BOX FARMING TAB
    ------------------------------------------------------------------
    do
    -- Box Farming tab is pre-created above for navigation order
    BoxTab:CreateSection("Farming")
    BoxTab:CreateToggle({
        Name = "Farm boxes (teleports to every dropped box)",
        CurrentValue = false,
        Flag = "VxFarmBoxes",
        Callback = function(state)
            B.farmBoxes = state
            setLoop("vxFarmBoxes", state, 0.1, collectBoxes)
        end,
    })
    BoxTab:CreateSlider({
        Name = "Farm speed",
        Range = { 1, 100 },
        Increment = 1,
        Suffix = "speed",
        CurrentValue = 30,
        Flag = "VxBoxSpeed",
        Callback = function(v) B.boxSpeed = v end,
    })
    BoxTab:CreateToggle({
        Name = "Return to base after farming",
        CurrentValue = false,
        Flag = "VxSafetyTp",
        Callback = function(state) B.safetyTeleport = state end,
    })
    BoxTab:CreateButton({
        Name = "Collect boxes once",
        Callback = function() task.spawn(collectBoxes, true) end,
    })


    BoxTab:CreateToggle({
        Name = "Track dropped boxes (max 25)",
        CurrentValue = false,
        Flag = "VxTrackBoxes",
        Callback = function(state)
            B.trackBoxes = state
            setLoop("vxBoxTags", state, 1, function()
                local folder = workspace:FindFirstChild("Boxes")
                if not folder then return end
                for _, box in ipairs(folder:GetChildren()) do
                    if not boxTags[box] and boxTagCount < 25 then
                        local part = boxAdornee(box)
                        if part then
                            local gui = makeTag(box.Name)
                            gui.Adornee = part
                            gui.Parent = part
                            boxTags[box] = gui
                            boxTagCount = boxTagCount + 1
                            box.Destroying:Connect(function()
                                if boxTags[box] then
                                    boxTags[box]:Destroy()
                                    boxTags[box] = nil
                                    boxTagCount = math.max(0, boxTagCount - 1)
                                end
                            end)
                        end
                    end
                end
            end)
            if not state then clearBoxTags() end
        end,
    })

    BoxTab:CreateSection("Which boxes to farm")
    local filterToggles = {
        { "Research / basic crates", "research" }, { "Golden crates", "golden" },
        { "Diamond crates", "diamond" }, { "Lucky crates", "lucky" },
        { "Shadow crates", "shadow" }, { "Crystal crates", "crystal" },
        { "Others (seasonal, executive, gift, gamepass)", "others" },
    }
    for _, entry in ipairs(filterToggles) do
        BoxTab:CreateToggle({
            Name = entry[1],
            CurrentValue = true,
            Flag = "VxFilter" .. entry[2],
            Callback = function(state) boxFilter[entry[2]] = state end,
        })
    end

    BoxTab:CreateSection("Mystery boxes")
    BoxTab:CreateDropdown({
        Name = "Box to open",
        Options = { "Regular", "Unreal", "Inferno", "Red-Banded", "Spectral", "Pumpkin", "Luxury",
            "Festive", "Magnificent", "Twitch", "Birthday", "Heavenly", "Easter", "Cake Raffle" },
        CurrentOption = { "Regular" },
        MultipleOptions = false,
        Flag = "VxBoxType",
        Callback = function(sel) B.selectedBox = firstOption(sel) or "Regular" end,
    })
    BoxTab:CreateInput({
        Name = "Seconds between opens",
        CurrentValue = "1",
        PlaceholderText = "1",
        RemoveTextAfterFocusLost = false,
        Flag = "VxBoxWait",
        Callback = function(text) B.boxWait = math.max(0.05, tonumber(text) or 1) end,
    })
    local lastBoxOpen = 0
    BoxTab:CreateToggle({
        Name = "Auto open the selected box",
        CurrentValue = false,
        Flag = "VxOpenBox",
        Callback = function(state)
            setLoop("vxOpenBox", state, 0.05, function()
                if os.clock() - lastBoxOpen >= B.boxWait then
                    lastBoxOpen = os.clock()
                    callRemote("MysteryBox", B.selectedBox)
                end
            end)
        end,
    })

    end



    ------------------------------------------------------------------
    -- VENDORS TAB
    ------------------------------------------------------------------
    do
    -- Vendors tab is pre-created above for navigation order
    VendorTab:CreateSection("Open menus")
    local MENUS = {
        { "Craftsman", "Craftsman" }, { "Masked Man", "MaskedMan" }, { "Box man", "SpookMcDook" },
        { "Superstitious Crafting", "Superstitious" }, { "True Book Of Knowledge", "BookOfKnowledge" },
        { "Phantasm", "Phantasm" }, { "Fleabag", "Fleabag" }, { "Event", "Event" },
    }
    for _, m in ipairs(MENUS) do
        VendorTab:CreateButton({
            Name = "Open " .. m[1],
            Callback = function() task.spawn(openMenu, m[2]) end,
        })
    end

    VendorTab:CreateSection("Shop Actions · MX6 Reference")
    VendorTab:CreateLabel("Shop Spam buys game-cash shop items. Two clicks within 8 seconds are required; it is never automatic on launch.")
    local shopConfirmUntil = 0
    local shopBusy = false
    VendorTab:CreateButton({
        Name = "Shop Spam (click twice to confirm)",
        Callback = function()
            if os.clock() > shopConfirmUntil then
                shopConfirmUntil = os.clock() + 8
                notify("Shop Spam", "This spends in-game cash. Click again within 8 seconds to confirm.", 7)
                return
            end
            shopConfirmUntil = 0
            if shopBusy then return end
            shopBusy = true
            task.spawn(function()
                local items, count = RS:FindFirstChild("Items"), 0
                if items then
                    for _, item in ipairs(items:GetChildren()) do
                        if not Hub.Alive or count >= 60 then break end
                        local itemType = item:FindFirstChild("ItemType")
                        local id = getItemId(item)
                        if id and itemType and itemType.Value >= 1 and itemType.Value < 5 then
                            callRemote("BuyItem", id, 1)
                            count = count + 1
                            task.wait(0.12)
                        end
                    end
                end
                shopBusy = false
                notify("Shop Spam", ("Sent %d purchase request(s)."):format(count))
            end)
        end,
    })
    VendorTab:CreateSection("Craftsman blueprints (uses RP)")
    local bpLabel = VendorTab:CreateLabel("Press refresh to count your missing blueprints.")
    local function refreshBlueprints()
        local list = blueprintList()
        local missing, cost = 0, 0
        for _, bp in ipairs(list) do
            local ok, has = callRemote("CraftsmanEvents", "type:hasblueprint", bp[1])
            if ok and not has then missing = missing + 1; cost = cost + bp[2] end
        end
        pcall(function()
            bpLabel:Set(("Missing %d/%d blueprints, total cost %s RP"):format(missing, #list, shorten(cost)))
        end)
    end
    VendorTab:CreateButton({
        Name = "Refresh blueprint count",
        Callback = function() task.spawn(refreshBlueprints) end,
    })
    VendorTab:CreateButton({
        Name = "Buy all missing blueprints",
        Callback = function()
            task.spawn(function()
                for _, bp in ipairs(blueprintList()) do
                    local ok, has = callRemote("CraftsmanEvents", "type:hasblueprint", bp[1])
                    if ok and not has then callRemote("CraftsmanEvents", "type:buyblueprint", bp[1]) end
                end
                refreshBlueprints()
            end)
        end,
    })

    end

    ------------------------------------------------------------------
    -- TELEPORT TAB
    ------------------------------------------------------------------
    do
    -- Teleport tab is pre-created above for navigation order
    TeleportTab:CreateSection("Player base")
    local selectedPlayer = LocalPlayer.Name
    local function playerNames()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do list[#list + 1] = p.Name end
        return list
    end
    local playerDropdown = TeleportTab:CreateDropdown({
        Name = "Select player",
        Options = playerNames(),
        CurrentOption = { LocalPlayer.Name },
        MultipleOptions = false,
        Flag = "VxPlayerSelect",
        Callback = function(sel) selectedPlayer = firstOption(sel) or LocalPlayer.Name end,
    })
    local function refreshPlayers() pcall(function() playerDropdown:Refresh(playerNames()) end) end
    connect(Players.PlayerAdded, refreshPlayers)
    connect(Players.PlayerRemoving, function() task.delay(0.2, refreshPlayers) end)
    TeleportTab:CreateButton({
        Name = "Teleport to base",
        Callback = function()
            local p = Players:FindFirstChild(selectedPlayer)
            local pt = p and p:FindFirstChild("PlayerTycoon")
            local base = pt and typeof(pt.Value) == "Instance" and pt.Value:FindFirstChild("Base")
            local hrp = getHRP()
            if base and hrp then
                hrp.CFrame = base.CFrame + Vector3.new(0, 10, 0)
            else
                notify("Teleport", "Could not find that player's base")
            end
        end,
    })

    TeleportTab:CreateSection("Solo island")
    local island = "Default"
    TeleportTab:CreateDropdown({
        Name = "Island type",
        Options = { "Default", "Executive", "Mars", "Sporest", "Void" },
        CurrentOption = { "Default" },
        MultipleOptions = false,
        Flag = "VxIsland",
        Callback = function(sel) island = firstOption(sel) or "Default" end,
    })
    TeleportTab:CreateButton({
        Name = "Go to solo island",
        Callback = function() task.spawn(callRemote, "PlaySolo", island) end,
    })

    TeleportTab:CreateSection("Other game places (leaves this server)")
    local PLACES = {
        ["The Void"] = 4464946645, ["Revenge of John Doe"] = 4780479031, ["Illusion"] = 4888384971,
        ["Heart of Void"] = 5621678877, ["The Temple"] = 5621679766, ["Shiny Void"] = 5621680266,
        ["Restore Data 2"] = 1778064565, ["Data Restore V3"] = 16433781330,
    }
    local selectedPlace = "The Void"
    TeleportTab:CreateDropdown({
        Name = "Place",
        Options = { "The Void", "Revenge of John Doe", "Illusion", "Heart of Void",
            "The Temple", "Shiny Void", "Restore Data 2", "Data Restore V3" },
        CurrentOption = { "The Void" },
        MultipleOptions = false,
        Flag = "VxPlace",
        Callback = function(sel) selectedPlace = firstOption(sel) or "The Void" end,
    })
    TeleportTab:CreateButton({
        Name = "Teleport to place",
        Callback = function()
            local id = PLACES[selectedPlace]
            if id then pcall(TeleportService.Teleport, TeleportService, id, LocalPlayer) end
        end,
    })

    end

    ------------------------------------------------------------------
    -- MUSIC TAB
    ------------------------------------------------------------------
    do
    -- Music tab is pre-created above for navigation order
    MusicTab:CreateSection("Seasonal music (only you hear it)")
    local selectedPreset = "Halloween Day"
    MusicTab:CreateDropdown({
        Name = "Music preset",
        Options = { "Halloween Day", "Halloween Night", "Normal Night" },
        CurrentOption = { "Halloween Day" },
        MultipleOptions = false,
        Flag = "VxMusicPreset",
        Callback = function(sel) selectedPreset = firstOption(sel) or "Halloween Day" end,
    })
    MusicTab:CreateButton({
        Name = "Apply preset",
        Callback = function()
            local preset = MUSIC_PRESETS[selectedPreset]
            if not preset then return end
            local applied = 0
            for target, id in pairs(preset) do
                if replaceSound(target, id, true) then applied = applied + 1 end
            end
            notify("Music", "Updated " .. applied .. " sound(s).")
        end,
    })

    MusicTab:CreateSection("Base radio")
    local radioNames = {}
    for name in pairs(RADIO_TRACKS) do radioNames[#radioNames + 1] = name end
    table.sort(radioNames)
    local selectedRadio = "Mesmerize"
    MusicTab:CreateDropdown({
        Name = "Radio song",
        Options = radioNames,
        CurrentOption = { "Mesmerize" },
        MultipleOptions = false,
        Flag = "VxRadio",
        Callback = function(sel) selectedRadio = firstOption(sel) or "Mesmerize" end,
    })
    MusicTab:CreateButton({
        Name = "Set and play base radio",
        Callback = function()
            if replaceSound("ClientBaseRadio", RADIO_TRACKS[selectedRadio], true) then
                notify("Base radio", selectedRadio .. " is playing.")
            end
        end,
    })

    MusicTab:CreateSection("Custom sound")
    local musicTargets = { "Day ambience", "Night ambience", "ClientBackgroundMusic", "ClientBaseRadio" }
    local selectedTarget, customId = "ClientBaseRadio", ""
    MusicTab:CreateDropdown({
        Name = "Sound to replace",
        Options = musicTargets,
        CurrentOption = { "ClientBaseRadio" },
        MultipleOptions = false,
        Flag = "VxMusicTarget",
        Callback = function(sel) selectedTarget = firstOption(sel) or "ClientBaseRadio" end,
    })
    MusicTab:CreateInput({
        Name = "Replacement audio ID",
        CurrentValue = "",
        PlaceholderText = "404060129 or rbxassetid://404060129",
        RemoveTextAfterFocusLost = false,
        Flag = "VxCustomMusic",
        Callback = function(text) customId = text or "" end,
    })
    MusicTab:CreateButton({
        Name = "Replace and play",
        Callback = function()
            if replaceSound(selectedTarget, customId, true) then
                notify("Music", selectedTarget .. " updated.")
            end
        end,
    })

    end

    ------------------------------------------------------------------
    -- MISC TAB
    ------------------------------------------------------------------
    do
    -- Misc tab is pre-created above for navigation order
    MiscTab:CreateSection("Character")

    local function currentHumanoid()
        local c = LocalPlayer.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    MiscTab:CreateSlider({
        Name = "Walk speed",
        Range = { 16, 300 },
        Increment = 1,
        Suffix = "speed",
        CurrentValue = 16,
        Flag = "VxWalk",
        Callback = function(v)
            B.walk = v
            local hum = currentHumanoid()
            if hum then hum.WalkSpeed = v end
        end,
    })
    MiscTab:CreateSlider({
        Name = "Jump power",
        Range = { 50, 300 },
        Increment = 1,
        Suffix = "power",
        CurrentValue = 50,
        Flag = "VxJump",
        Callback = function(v)
            B.jump = v
            local hum = currentHumanoid()
            if hum then hum.UseJumpPower = true; hum.JumpPower = v end
        end,
    })
    connect(LocalPlayer.CharacterAdded, function(char)
        local hum = char:WaitForChild("Humanoid", 10)
        if not hum then return end
        if B.walk > 16 then hum.WalkSpeed = B.walk end
        if B.jump > 50 then hum.UseJumpPower = true; hum.JumpPower = B.jump end
        hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if Hub.Alive and B.walk > 16 and hum.WalkSpeed < B.walk then hum.WalkSpeed = B.walk end
        end)
    end)

    MiscTab:CreateSection("World")
    MiscTab:CreateToggle({
        Name = "Disable game blur",
        CurrentValue = false,
        Flag = "VxBlur",
        Callback = function(state)
            local blur = Lighting:FindFirstChild("Blur")
            if blur then blur.Enabled = not state end
        end,
    })
    MiscTab:CreateToggle({
        Name = "Anti leave base (respawn if you leave your base)",
        CurrentValue = false,
        Flag = "VxAntiLeave",
        Callback = function(state) B.antiLeave = state end,
    })
    local activeValue = LocalPlayer:FindFirstChild("ActiveTycoon")
    if activeValue then
        connect(activeValue.Changed, function()
            if not Hub.Alive then return end
            local tycoon = getTycoon()
            if B.antiLeave and tycoon and (activeValue.Value == nil or activeValue.Value ~= tycoon) then
                local hum = currentHumanoid()
                if hum then hum.Health = 0 end
            end
        end)
    end
    end
end

----------------------------------------------------------------------
-- Unload (so injecting the script again replaces this copy cleanly)
----------------------------------------------------------------------
function Hub.Unload()
    Hub.Alive = false
    for key in pairs(loops) do loops[key] = (loops[key] or 0) + 1 end
    clearAllESP()
    for _, fn in ipairs(Hub.Cleanups) do pcall(fn) end
    for _, conn in ipairs(Hub.Conns) do pcall(function() conn:Disconnect() end) end
    pcall(function() Rayfield:Destroy() end)
    pcall(function()
        local parent = (gethui and gethui()) or LocalPlayer:FindFirstChild("PlayerGui")
        local text = parent and parent:FindFirstChild("ViyxText")
        if text then text:Destroy() end
    end)
    if ENV[HUB_KEY] == Hub then ENV[HUB_KEY] = nil end
    print("[MH] Previous instance unloaded.")
end

----------------------------------------------------------------------
-- Finish
----------------------------------------------------------------------
pcall(function() Rayfield:LoadConfiguration() end)
-- Diagnostics available manually under Auto Section.
notify("Viyx 1.5", "Dashboard loaded. Press K to show or hide the hub.", 5)
print("[Viyx MH 1.5] Loaded. Original Viyx + MX6/A4 features integrated.")
