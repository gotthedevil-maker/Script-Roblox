-- ====================================================================
-- PROJECT: ANTI-AFK & FPS OPTIMIZER GUI V4.5 (PERMANENT OPTIMIZE + STATS)
-- Cập nhật: Thêm Slider tùy chỉnh WalkSpeed và JumpPower
-- ====================================================================

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui") 
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function debug_print(msg)
    print("🤖 [System V4.5]: " .. msg)
end

-- ====================================================================
-- 1. SETUP UI & KHẮC PHỤC LỖI EXECUTOR
-- ====================================================================
local TargetParent = pcall(function() return gethui() end) and gethui() or CoreGui

if TargetParent:FindFirstChild("AntiAFK_Gui_V4") then TargetParent:FindFirstChild("AntiAFK_Gui_V4"):Destroy() end
if PlayerGui:FindFirstChild("AntiAFK_BlackoutGui") then PlayerGui:FindFirstChild("AntiAFK_BlackoutGui"):Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AntiAFK_Gui_V4"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = TargetParent

-- 2. Khung nền chính (MainFrame) - Đã tăng chiều cao lên 490
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 260, 0, 490) 
MainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15) 
MainFrame.Active = true
MainFrame.Visible = true
MainFrame.Parent = ScreenGui

local FrameCorner = Instance.new("UICorner")
FrameCorner.CornerRadius = UDim.new(0, 10) 
FrameCorner.Parent = MainFrame

local FrameStroke = Instance.new("UIStroke")
FrameStroke.Thickness = 2
FrameStroke.Color = Color3.fromRGB(139, 92, 246) 
FrameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
FrameStroke.Parent = MainFrame

-- Hệ thống Drag (Kéo thả)
local dragging, dragInput, dragStart, startPos

local function updateDrag(input)
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateDrag(input)
    end
end)

-- ====================================================================
-- 3. THIẾT KẾ GIAO DIỆN CHÍNH
-- ====================================================================

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(1, 0, 0, 35) 
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🛡️ OPTIMIZER & ANTI-AFK V4.5"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextSize = 16
TitleLabel.Parent = MainFrame

local function createButton(name, text, posY, sizeY)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0.85, 0, 0, sizeY or 35) 
    btn.Position = UDim2.new(0.075, 0, 0, posY) 
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 15
    btn.Text = text
    btn.Parent = MainFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(255, 255, 255) 
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = btn

    return btn
end

-- ====================================================================
-- HÀM TẠO SLIDER
-- ====================================================================
local function createSlider(name, text, posY, minVal, maxVal, defaultVal, callback)
    local SliderContainer = Instance.new("Frame")
    SliderContainer.Name = name
    SliderContainer.Size = UDim2.new(0.85, 0, 0, 40)
    SliderContainer.Position = UDim2.new(0.075, 0, 0, posY)
    SliderContainer.BackgroundTransparency = 1
    SliderContainer.Parent = MainFrame

    local TitleInfo = Instance.new("TextLabel")
    TitleInfo.Size = UDim2.new(1, 0, 0, 15)
    TitleInfo.BackgroundTransparency = 1
    TitleInfo.Text = text .. ": " .. tostring(defaultVal)
    TitleInfo.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleInfo.Font = Enum.Font.SourceSansBold
    TitleInfo.TextSize = 14
    TitleInfo.TextXAlignment = Enum.TextXAlignment.Left
    TitleInfo.Parent = SliderContainer

    local Track = Instance.new("TextButton")
    Track.Size = UDim2.new(1, 0, 0, 10)
    Track.Position = UDim2.new(0, 0, 0, 22)
    Track.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Track.Text = ""
    Track.AutoButtonColor = false
    Track.Parent = SliderContainer

    local TrackCorner = Instance.new("UICorner")
    TrackCorner.CornerRadius = UDim.new(1, 0)
    TrackCorner.Parent = Track

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new(math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(139, 92, 246)
    Fill.Parent = Track

    local FillCorner = Instance.new("UICorner")
    FillCorner.CornerRadius = UDim.new(1, 0)
    FillCorner.Parent = Fill

    local isSliding = false

    local function updateSlider(input)
        local pos = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
        Fill.Size = UDim2.new(pos, 0, 1, 0)
        local value = math.floor(minVal + (maxVal - minVal) * pos)
        TitleInfo.Text = text .. ": " .. tostring(value)
        callback(value)
    end

    Track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isSliding = true
            updateSlider(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isSliding = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isSliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
end

-- ====================================================================
-- BỐ TRÍ CÁC NÚT & SLIDER
-- ====================================================================
local MainButton = createButton("MainButton", "ANTI-AFK: OFF", 40, 40) 
local OptLightBtn = createButton("OptLightBtn", "⚡ Tối ưu Ánh Sáng", 90)
local OptWorldBtn = createButton("OptWorldBtn", "🗑️ XÓA TEXTURES: OFF", 135) 
local OptTerrainBtn = createButton("OptTerrainBtn", "🌊 Tối ưu Địa Hình", 180)
local ZenModeBtn = createButton("ZenModeBtn", "🚀 CHỐNG LAG LÚC LOAD", 225)
ZenModeBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255) 

-- Logic quản lý Tốc độ & Sức nhảy
local customWalkSpeed = 16
local customJumpPower = 50

createSlider("SpeedSlider", "🏃 Tốc độ (Speed)", 275, 16, 250, 16, function(val)
    customWalkSpeed = val
end)

createSlider("JumpSlider", "🦘 Sức nhảy (Jump)", 325, 50, 300, 50, function(val)
    customJumpPower = val
end)

-- Ép chỉ số liên tục để chống game reset
RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if customWalkSpeed ~= 16 then
                hum.WalkSpeed = customWalkSpeed
            end
            if customJumpPower ~= 50 then
                hum.UseJumpPower = true
                hum.JumpPower = customJumpPower
            end
        end
    end
end)

local KeybindButton = createButton("KeybindButton", "⚙️ Phím: [Q]", 380, 30)
KeybindButton.Size = UDim2.new(0.45, 0, 0, 30)
KeybindButton.BackgroundColor3 = Color3.fromRGB(139, 92, 246) 

local ExplanationLabel = Instance.new("TextLabel")
ExplanationLabel.Name = "ExplanationLabel"
ExplanationLabel.Size = UDim2.new(0.4, 0, 0, 30)
ExplanationLabel.Position = UDim2.new(0.55, 0, 0, 380) 
ExplanationLabel.BackgroundTransparency = 1
ExplanationLabel.Text = "Nhấn để Ẩn/Hiện UI"
ExplanationLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
ExplanationLabel.Font = Enum.Font.SourceSans
ExplanationLabel.TextSize = 13
ExplanationLabel.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Size = UDim2.new(0.85, 0, 0, 20)
StatusLabel.Position = UDim2.new(0.075, 0, 0, 425) 
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Trạng thái: Đang chờ..."
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
StatusLabel.Font = Enum.Font.SourceSansItalic
StatusLabel.TextSize = 14
StatusLabel.Parent = MainFrame

local function updateStatus(text)
    StatusLabel.Text = "Trạng thái: " .. text
end

-- ====================================================================
-- 4. LOGIC OPTIMIZER 
-- ====================================================================
OptLightBtn.MouseButton1Click:Connect(function()
    updateStatus("Đang tối ưu ánh sáng...")
    local lighting = game:GetService("Lighting")
    lighting.GlobalShadows = false
    lighting.FogEnd = 9e9
    lighting.Brightness = 1
    
    for _, v in pairs(lighting:GetDescendants()) do
        if v:IsA("PostEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then
            v.Enabled = false
        end
    end
    OptLightBtn.Text = "✔️ Đã Tối ưu Ánh Sáng"
    OptLightBtn.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
    updateStatus("Hoàn tất tối ưu ánh sáng!")
end)

OptTerrainBtn.MouseButton1Click:Connect(function()
    updateStatus("Đang tối ưu địa hình...")
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        pcall(function() terrain.WaterWaveSize = 0 end)
        pcall(function() terrain.WaterWaveSpeed = 0 end)
        pcall(function() terrain.WaterReflectance = 0 end)
        pcall(function() terrain.WaterTransparency = 0 end)
    end
    OptTerrainBtn.Text = "✔️ Đã Tối ưu Địa Hình"
    OptTerrainBtn.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
    updateStatus("Hoàn tất địa hình nước!")
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

OptWorldBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
OptWorldBtn.MouseButton1Click:Connect(function()
    autoOptimizeWorld = not autoOptimizeWorld
    
    if autoOptimizeWorld then
        OptWorldBtn.Text = "XÓA TEXTURES: ON"
        OptWorldBtn.BackgroundColor3 = Color3.fromRGB(139, 92, 246)
        updateStatus("Đang quét toàn bộ map...")
        
        local count = 0
        for _, v in pairs(workspace:GetDescendants()) do
            cleanObject(v)
            count = count + 1
            if count % 800 == 0 then task.wait() end
        end
        
        worldConnection = workspace.DescendantAdded:Connect(function(newObj)
            task.delay(0.1, function()
                if autoOptimizeWorld then
                    cleanObject(newObj)
                end
            end)
        end)
        
        updateStatus("Đã BẬT dọn dẹp vĩnh viễn!")
    else
        OptWorldBtn.Text = "XÓA TEXTURES: OFF"
        OptWorldBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68) 
        
        if worldConnection then
            worldConnection:Disconnect()
            worldConnection = nil
        end
        updateStatus("Đã TẮT dọn dẹp vĩnh viễn.")
    end
end)

-- ====================================================================
-- 5. LOGIC ZEN MODE
-- ====================================================================
local isZenMode = false
local BlackoutGui = nil

ZenModeBtn.MouseButton1Click:Connect(function()
    isZenMode = not isZenMode
    
    if isZenMode then
        ZenModeBtn.Text = "🛑 ĐANG CHỐNG LAG... BẤM ĐỂ TẮT"
        ZenModeBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68) 
        updateStatus("Đã che mắt GPU. Hãy Load Layout ngay!")
        
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
        loadingText.Text = "ĐANG LOAD LAYOUT...\n(Hệ thống đang vô hiệu hóa Render)"
        loadingText.TextColor3 = Color3.fromRGB(255, 255, 255)
        loadingText.Font = Enum.Font.SourceSansBold
        loadingText.TextSize = 24
        loadingText.Parent = blackoutFrame
        
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    else
        ZenModeBtn.Text = "🚀 CHỐNG LAG KHI LOAD LAYOUT"
        ZenModeBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        updateStatus("Đã gỡ màn hình chờ.")
        
        if BlackoutGui then BlackoutGui:Destroy() BlackoutGui = nil end
        
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
    end
end)

-- ====================================================================
-- 6. LOGIC ANTI-AFK & KEYBIND
-- ====================================================================
local antiAFKEnabled = false 
local currentKeybind = Enum.KeyCode.Q 
local isAssigningKeybind = false 

local function updateMainButtonAppearance()
    local stroke = MainButton:FindFirstChildOfClass("UIStroke")
    if antiAFKEnabled then
        MainButton.BackgroundColor3 = Color3.fromRGB(139, 92, 246) 
        MainButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        MainButton.Text = "ANTI-AFK: ON"
        if stroke then stroke.Color = Color3.fromRGB(139, 92, 246) end
    else
        MainButton.BackgroundColor3 = Color3.fromRGB(239, 68, 68) 
        MainButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        MainButton.Text = "ANTI-AFK: OFF"
        if stroke then stroke.Color = Color3.fromRGB(239, 68, 68) end
    end
end

local function updateKeybindButtonAppearance()
    if isAssigningKeybind then
        KeybindButton.Text = "Gán phím..."
        KeybindButton.BackgroundColor3 = Color3.fromRGB(255, 165, 0) 
    else
        KeybindButton.Text = "⚙️ Phím: [" .. currentKeybind.Name .. "]"
        KeybindButton.BackgroundColor3 = Color3.fromRGB(139, 92, 246) 
    end
end

updateMainButtonAppearance()

MainButton.MouseButton1Click:Connect(function()
    if isAssigningKeybind then return end 
    antiAFKEnabled = not antiAFKEnabled
    updateMainButtonAppearance()
    updateStatus(antiAFKEnabled and "Đã BẬT Anti-AFK" or "Đã TẮT Anti-AFK")
end)

KeybindButton.MouseButton1Click:Connect(function()
    isAssigningKeybind = not isAssigningKeybind
    updateKeybindButtonAppearance()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if isAssigningKeybind then
        if input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode ~= currentKeybind then
            currentKeybind = input.KeyCode
            isAssigningKeybind = false
            updateKeybindButtonAppearance()
        end
    else
        if input.KeyCode == currentKeybind then
            MainFrame.Visible = not MainFrame.Visible
        end
    end
end)

local idledConnection
idledConnection = LocalPlayer.Idled:Connect(function()
    if antiAFKEnabled then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end
end)

debug_print("✅ SCRIPT V4.5 CHẠY THÀNH CÔNG!")
