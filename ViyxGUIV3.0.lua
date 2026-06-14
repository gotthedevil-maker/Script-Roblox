-- ====================================================================
-- PROJECT: ANTI-AFK & FPS OPTIMIZER GUI V4.0 (PERMANENT OPTIMIZE)
-- Đã được sửa lỗi đơ nút và tối ưu cho Executor
-- ====================================================================

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui") 
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local function debug_print(msg)
    print("🤖 [System V4.0]: " .. msg)
end

-- ====================================================================
-- 1. SETUP UI & KHẮC PHỤC LỖI EXECUTOR
-- ====================================================================
-- Sử dụng gethui() hoặc CoreGui để game không đè UI lên và không block click
local TargetParent = pcall(function() return gethui() end) and gethui() or CoreGui

-- Dọn dẹp bản cũ
local existingGui = TargetParent:FindFirstChild("AntiAFK_Gui_V4")
if existingGui then existingGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AntiAFK_Gui_V4"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = TargetParent

-- 2. Khung nền chính (MainFrame)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 260, 0, 405) 
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
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

-- Hệ thống Drag (Kéo thả) mượt mà thay thế cho Draggable = true
local dragging
local dragInput
local dragStart
local startPos

local function update(input)
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
        update(input)
    end
end)

-- ====================================================================
-- 3. THIẾT KẾ GIAO DIỆN CHÍNH
-- ====================================================================

-- Tiêu đề
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(1, 0, 0, 35) 
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🛡️ OPTIMIZER & ANTI-AFK V4"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextSize = 16
TitleLabel.Position = UDim2.new(0, 0, 0, 0)
TitleLabel.Parent = MainFrame

-- Hàm tạo nút bấm
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

-- Tạo các nút chức năng
local MainButton = createButton("MainButton", "ANTI-AFK: OFF", 45, 45) 
local OptLightBtn = createButton("OptLightBtn", "⚡ Tối ưu Ánh Sáng", 100)
local OptWorldBtn = createButton("OptWorldBtn", "🗑️ XÓA TEXTURES: OFF", 145) 
local OptTerrainBtn = createButton("OptTerrainBtn", "🌊 Tối ưu Địa Hình", 190)

local ZenModeBtn = createButton("ZenModeBtn", "🚀 CHỐNG LAG KHI LOAD LAYOUT", 235)
ZenModeBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255) 

-- Khu vực Keybind & Trạng thái
local KeybindButton = createButton("KeybindButton", "⚙️ Phím: [Q]", 295, 30)
KeybindButton.Size = UDim2.new(0.45, 0, 0, 30)
KeybindButton.BackgroundColor3 = Color3.fromRGB(139, 92, 246) 

local ExplanationLabel = Instance.new("TextLabel")
ExplanationLabel.Name = "ExplanationLabel"
ExplanationLabel.Size = UDim2.new(0.4, 0, 0, 30)
ExplanationLabel.Position = UDim2.new(0.55, 0, 0, 295) 
ExplanationLabel.BackgroundTransparency = 1
ExplanationLabel.Text = "Nhấn để Ẩn/Hiện UI"
ExplanationLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
ExplanationLabel.Font = Enum.Font.SourceSans
ExplanationLabel.TextSize = 13
ExplanationLabel.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Size = UDim2.new(0.85, 0, 0, 20)
StatusLabel.Position = UDim2.new(0.075, 0, 0, 345) 
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

-- ⚡ TỐI ƯU ÁNH SÁNG
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

-- 🌊 TỐI ƯU ĐỊA HÌNH 
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

-- 🗑️ LOGIC XÓA TEXTURE VĨNH VIỄN
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
-- 5. LOGIC ZEN MODE (CHỐNG FREEZE KHI LOAD LAYOUT)
-- ====================================================================
local isZenMode = false
local blackoutFrame = nil

ZenModeBtn.MouseButton1Click:Connect(function()
    isZenMode = not isZenMode
    
    if isZenMode then
        ZenModeBtn.Text = "🛑 ĐANG CHỐNG LAG... BẤM ĐỂ TẮT"
        ZenModeBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68) 
        updateStatus("Đã che mắt GPU. Hãy bấm Load Layout ngay!")
        
        blackoutFrame = Instance.new("Frame")
        blackoutFrame.Size = UDim2.new(1, 0, 1, 0)
        blackoutFrame.Position = UDim2.new(0, 0, 0, -50) 
        blackoutFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        blackoutFrame.ZIndex = 9999 
        blackoutFrame.Parent = ScreenGui
        
        local loadingText = Instance.new("TextLabel")
        loadingText.Size = UDim2.new(1, 0, 1, 0)
        loadingText.BackgroundTransparency = 1
        loadingText.Text = "ĐANG LOAD LAYOUT...\n(Hệ thống đang vô hiệu hóa Render để chống văng game)"
        loadingText.TextColor3 = Color3.fromRGB(255, 255, 255)
        loadingText.Font = Enum.Font.SourceSansBold
        loadingText.TextSize = 24
        loadingText.Parent = blackoutFrame
        
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        
    else
        ZenModeBtn.Text = "🚀 CHỐNG LAG KHI LOAD LAYOUT"
        ZenModeBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        updateStatus("Đã gỡ màn hình chờ.")
        
        if blackoutFrame then
            blackoutFrame:Destroy()
            blackoutFrame = nil
        end
        
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

debug_print("✅ SCRIPT V4.0 CHẠY THÀNH CÔNG!")
