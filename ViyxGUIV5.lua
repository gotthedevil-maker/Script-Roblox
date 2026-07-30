-- ====================================================================
-- PROJECT: ANTI-AFK & FPS OPTIMIZER GUI V5.0 (UI REMAKE + AUTO KEYS)
-- Cập nhật: Làm lại UI chuyên nghiệp theo Dark Theme, thêm Auto 1-5
-- ====================================================================

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui") 
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Bảng màu chuẩn theo ảnh mẫu
local Theme = {
    Background = Color3.fromRGB(30, 30, 45),     -- Nền chính (Xanh đen)
    Sidebar = Color3.fromRGB(25, 25, 38),        -- Nền cột trái
    Accent = Color3.fromRGB(99, 102, 241),       -- Tím/Xanh dương nổi bật
    RowBg = Color3.fromRGB(35, 35, 52),          -- Nền từng hàng chức năng
    TextMain = Color3.fromRGB(240, 240, 240),
    TextMuted = Color3.fromRGB(150, 150, 170)
}

-- ====================================================================
-- 1. SETUP UI & KHẮC PHỤC LỖI EXECUTOR
-- ====================================================================
local TargetParent = pcall(function() return gethui() end) and gethui() or CoreGui

if TargetParent:FindFirstChild("AntiAFK_Gui_V5") then TargetParent:FindFirstChild("AntiAFK_Gui_V5"):Destroy() end
if PlayerGui:FindFirstChild("AntiAFK_BlackoutGui") then PlayerGui:FindFirstChild("AntiAFK_BlackoutGui"):Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AntiAFK_Gui_V5"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = TargetParent

-- Khung nền chính (MainFrame)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 520, 0, 340) 
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -170)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

-- Top Bar (Để kéo UI)
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundTransparency = 1
TopBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Menu GUI | By S I L X N C E (V5.0)"
Title.TextColor3 = Theme.TextMain
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Theme.TextMuted
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = TopBar

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Kéo thả UI
local dragging, dragInput, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
TopBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ====================================================================
-- 2. TẠO CẤU TRÚC LAYOUT (SIDEBAR & CONTENT)
-- ====================================================================
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 140, 1, -30)
Sidebar.Position = UDim2.new(0, 0, 0, 30)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 8)
SidebarCorner.Parent = Sidebar
-- Che góc bo phải của Sidebar để nối liền với Content
local SidebarPatch = Instance.new("Frame")
SidebarPatch.Size = UDim2.new(0, 8, 1, 0)
SidebarPatch.Position = UDim2.new(1, -8, 0, 0)
SidebarPatch.BackgroundColor3 = Theme.Sidebar
SidebarPatch.BorderSizePixel = 0
SidebarPatch.Parent = Sidebar

local SidebarList = Instance.new("UIListLayout")
SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
SidebarList.Padding = UDim.new(0, 5)
SidebarList.Parent = Sidebar

local SidebarPadding = Instance.new("UIPadding")
SidebarPadding.PaddingTop = UDim.new(0, 10)
SidebarPadding.PaddingLeft = UDim.new(0, 10)
SidebarPadding.PaddingRight = UDim.new(0, 10)
SidebarPadding.Parent = Sidebar

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -140, 1, -30)
ContentArea.Position = UDim2.new(0, 140, 0, 30)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local Tabs = {}
local TabContents = {}
local currentTab = nil

local function switchTab(tabName)
    for name, content in pairs(TabContents) do content.Visible = (name == tabName) end
    for name, tabBtn in pairs(Tabs) do
        if name == tabName then
            tabBtn.BackgroundColor3 = Theme.Accent
            tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            tabBtn.BackgroundColor3 = Theme.Sidebar
            tabBtn.TextColor3 = Theme.TextMuted
        end
    end
end

local function createTab(name, title)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1, 0, 0, 30)
    TabBtn.BackgroundColor3 = Theme.Sidebar
    TabBtn.Text = title
    TabBtn.TextColor3 = Theme.TextMuted
    TabBtn.Font = Enum.Font.GothamSemibold
    TabBtn.TextSize = 13
    TabBtn.AutoButtonColor = false
    TabBtn.Parent = Sidebar

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = TabBtn

    local ScrollContent = Instance.new("ScrollingFrame")
    ScrollContent.Size = UDim2.new(1, 0, 1, -10)
    ScrollContent.Position = UDim2.new(0, 0, 0, 0)
    ScrollContent.BackgroundTransparency = 1
    ScrollContent.ScrollBarThickness = 4
    ScrollContent.BorderSizePixel = 0
    ScrollContent.Visible = false
    ScrollContent.Parent = ContentArea

    local ContentLayout = Instance.new("UIListLayout")
    ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ContentLayout.Padding = UDim.new(0, 2)
    ContentLayout.Parent = ScrollContent

    local ContentPadding = Instance.new("UIPadding")
    ContentPadding.PaddingTop = UDim.new(0, 10)
    ContentPadding.PaddingLeft = UDim.new(0, 10)
    ContentPadding.PaddingRight = UDim.new(0, 15)
    ContentPadding.Parent = ScrollContent

    Tabs[name] = TabBtn
    TabContents[name] = ScrollContent

    TabBtn.MouseButton1Click:Connect(function() switchTab(name) end)
    
    return ScrollContent
end

-- ====================================================================
-- 3. HÀM TẠO CÁC COMPONENT GIAO DIỆN CON (SECTION, TOGGLE, SLIDER)
-- ====================================================================
local function addSection(parent, titleText)
    local SectionFrame = Instance.new("Frame")
    SectionFrame.Size = UDim2.new(1, 0, 0, 28)
    SectionFrame.BackgroundColor3 = Theme.Accent
    SectionFrame.Parent = parent

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 4)
    Corner.Parent = SectionFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -20, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = titleText
    Title.TextColor3 = Theme.TextMain
    Title.Font = Enum.Font.GothamSemibold
    Title.TextSize = 13
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = SectionFrame
end

local function addToggle(parent, icon, text, default, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 35)
    Row.BackgroundColor3 = Theme.RowBg
    Row.BackgroundTransparency = 0.5
    Row.Parent = parent

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -60, 1, 0)
    Label.Position = UDim2.new(0, 30, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Theme.TextMuted
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local Icon = Instance.new("TextLabel")
    Icon.Size = UDim2.new(0, 30, 1, 0)
    Icon.BackgroundTransparency = 1
    Icon.Text = icon
    Icon.TextColor3 = Theme.Accent
    Icon.Font = Enum.Font.Gotham
    Icon.TextSize = 16
    Icon.Parent = Row

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 40, 0, 20)
    ToggleBtn.Position = UDim2.new(1, -45, 0.5, -10)
    ToggleBtn.BackgroundColor3 = default and Theme.Accent or Color3.fromRGB(50, 50, 70)
    ToggleBtn.Text = ""
    ToggleBtn.Parent = Row

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(1, 0)
    Corner.Parent = ToggleBtn

    local Indicator = Instance.new("Frame")
    Indicator.Size = UDim2.new(0, 16, 0, 16)
    Indicator.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    Indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Indicator.Parent = ToggleBtn

    local IndCorner = Instance.new("UICorner")
    IndCorner.CornerRadius = UDim.new(1, 0)
    IndCorner.Parent = Indicator

    local state = default
    ToggleBtn.MouseButton1Click:Connect(function()
        state = not state
        ToggleBtn.BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(50, 50, 70)
        Indicator:TweenPosition(state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 0.2, true)
        Label.TextColor3 = state and Theme.TextMain or Theme.TextMuted
        callback(state)
    end)
    return Row
end

local function addSlider(parent, icon, text, min, max, default, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 50)
    Row.BackgroundColor3 = Theme.RowBg
    Row.BackgroundTransparency = 0.5
    Row.Parent = parent

    local Icon = Instance.new("TextLabel")
    Icon.Size = UDim2.new(0, 30, 0, 30)
    Icon.BackgroundTransparency = 1
    Icon.Text = icon
    Icon.TextColor3 = Theme.Accent
    Icon.Font = Enum.Font.Gotham
    Icon.TextSize = 16
    Icon.Parent = Row

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -60, 0, 30)
    Label.Position = UDim2.new(0, 30, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text .. " (" .. default .. ")"
    Label.TextColor3 = Theme.TextMuted
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local SliderBg = Instance.new("TextButton")
    SliderBg.Size = UDim2.new(1, -20, 0, 6)
    SliderBg.Position = UDim2.new(0, 10, 0, 35)
    SliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    SliderBg.Text = ""
    SliderBg.AutoButtonColor = false
    SliderBg.Parent = Row

    local BgCorner = Instance.new("UICorner")
    BgCorner.CornerRadius = UDim.new(1, 0)
    BgCorner.Parent = SliderBg

    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    SliderFill.BackgroundColor3 = Theme.Accent
    SliderFill.Parent = SliderBg

    local FillCorner = Instance.new("UICorner")
    FillCorner.CornerRadius = UDim.new(1, 0)
    FillCorner.Parent = SliderFill

    local isSliding = false
    local function updateSlider(input)
        local pos = math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
        SliderFill.Size = UDim2.new(pos, 0, 1, 0)
        local value = math.floor(min + (max - min) * pos)
        Label.Text = text .. " (" .. value .. ")"
        callback(value)
    end

    SliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isSliding = true
            updateSlider(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isSliding = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if isSliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
end

-- ====================================================================
-- 4. LOGIC CHỨC NĂNG VÀ ĐỔ DỮ LIỆU LÊN UI
-- ====================================================================
local TabPlayer = createTab("Player", "Player")
local TabOptimizer = createTab("Optimizer", "Optimizer")
local TabMisc = createTab("Misc", "Misc")
switchTab("Player") -- Default tab

-- [TAB PLAYER]
addSection(TabPlayer, "Player Modifications")

local antiAFKEnabled = false
addToggle(TabPlayer, "📌", "Anti-AFK", false, function(state)
    antiAFKEnabled = state
end)
LocalPlayer.Idled:Connect(function()
    if antiAFKEnabled then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end
end)

local customWalkSpeed = 16
local customJumpPower = 50
addSlider(TabPlayer, "⚡", "WalkSpeed", 16, 250, 16, function(val) customWalkSpeed = val end)
addSlider(TabPlayer, "🦘", "Jump Power", 50, 300, 50, function(val) customJumpPower = val end)

RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if customWalkSpeed ~= 16 then hum.WalkSpeed = customWalkSpeed end
            if customJumpPower ~= 50 then 
                hum.UseJumpPower = true
                hum.JumpPower = customJumpPower 
            end
        end
    end
end)

-- [TAB OPTIMIZER]
addSection(TabOptimizer, "FPS & Graphics")

addToggle(TabOptimizer, "💡", "Tối ưu Ánh Sáng", false, function(state)
    if state then
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 1
        for _, v in pairs(Lighting:GetDescendants()) do
            if v:IsA("PostEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then
                v.Enabled = false
            end
        end
    end
end)

addToggle(TabOptimizer, "🌊", "Tối ưu Địa Hình Nước", false, function(state)
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain and state then
        pcall(function() terrain.WaterWaveSize = 0 end)
        pcall(function() terrain.WaterWaveSpeed = 0 end)
        pcall(function() terrain.WaterReflectance = 0 end)
        pcall(function() terrain.WaterTransparency = 0 end)
    end
end)

local autoOptimizeWorld = false
local worldConnection = nil
local function cleanObject(v)
    local model = v:FindFirstAncestorWhichIsA("Model")
    if model and Players:GetPlayerFromCharacter(model) then return end
    if v.Name == "Handle" or v:IsA("SpawnLocation") or v:IsA("Tool") then return end

    if v:IsA("BasePart") then
        v.Material = Enum.Material.SmoothPlastic
        v.Reflectance = 0
        v.CastShadow = false
    elseif v:IsA("Texture") or v:IsA("Decal") then
        v:Destroy()
    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
        v.Enabled = false
    end
end

addToggle(TabOptimizer, "🗑️", "Xóa Textures Toàn Map", false, function(state)
    autoOptimizeWorld = state
    if autoOptimizeWorld then
        local count = 0
        for _, v in pairs(workspace:GetDescendants()) do
            cleanObject(v)
            count = count + 1
            if count % 800 == 0 then task.wait() end
        end
        worldConnection = workspace.DescendantAdded:Connect(function(newObj)
            task.delay(0.1, function() if autoOptimizeWorld then cleanObject(newObj) end end)
        end)
    else
        if worldConnection then worldConnection:Disconnect(); worldConnection = nil end
    end
end)

local BlackoutGui = nil
addToggle(TabOptimizer, "🛑", "Zen Mode (Chống Lag Load Layout)", false, function(state)
    if state then
        BlackoutGui = Instance.new("ScreenGui")
        BlackoutGui.Name = "AntiAFK_BlackoutGui"
        BlackoutGui.IgnoreGuiInset = true 
        BlackoutGui.Parent = PlayerGui 
        local blackoutFrame = Instance.new("Frame")
        blackoutFrame.Size = UDim2.new(1, 0, 1, 0)
        blackoutFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        blackoutFrame.Parent = BlackoutGui
        local loadingText = Instance.new("TextLabel")
        loadingText.Size = UDim2.new(1, 0, 1, 0)
        loadingText.BackgroundTransparency = 1
        loadingText.Text = "HỆ THỐNG ĐANG VÔ HIỆU HÓA RENDER..."
        loadingText.TextColor3 = Color3.fromRGB(255, 255, 255)
        loadingText.Font = Enum.Font.GothamBold
        loadingText.TextSize = 24
        loadingText.Parent = blackoutFrame
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    else
        if BlackoutGui then BlackoutGui:Destroy() BlackoutGui = nil end
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
    end
end)

-- [TAB MISC - AUTO KEYS]
addSection(TabMisc, "Automation Macros")

local autoKeyEnabled = false
addToggle(TabMisc, "⌨️", "Auto Bấm Phím 1 -> 5", false, function(state)
    autoKeyEnabled = state
end)

-- Vòng lặp chạy Auto Phím
task.spawn(function()
    -- Các phím từ 1 đến 5 theo Enum của Roblox
    local keysToPress = {
        Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five
    }
    
    while true do
        task.wait(0.5) -- Khoảng nghỉ giữa mỗi chu kỳ bấm 1-5
        
        -- Nếu đang bật và người chơi KHÔNG GÕ CHAT
        if autoKeyEnabled and not UserInputService:GetFocusedTextBox() then
            for i = 1, #keysToPress do
                if not autoKeyEnabled then break end -- Dừng ngay nếu lỡ tắt giữa chừng
                
                -- Giả lập bấm phím xuống
                VirtualInputManager:SendKeyEvent(true, keysToPress[i], false, game)
                task.wait(0.05)
                -- Giả lập thả phím ra
                VirtualInputManager:SendKeyEvent(false, keysToPress[i], false, game)
                task.wait(0.05)
            end
        end
    end
end)

-- Ẩn Hiện GUI bằng phím Q
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Q then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

print("🤖 [System V5.0]: Loaded Successfully!")
