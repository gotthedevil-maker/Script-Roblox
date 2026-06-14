-- ====================================================================
-- PROJECT: ANTI-AFK & FPS OPTIMIZER GUI V3.0
-- ====================================================================

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui") 
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function debug_print(msg)
    print("🤖 [System V3.0]: " .. msg)
end

-- 1. Dọn dẹp bản cũ
local existingGui = PlayerGui:FindFirstChild("AntiAFK_Gui_V3")
if existingGui then existingGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AntiAFK_Gui_V3"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

-- 2. Khung nền chính (MainFrame) - Đã mở rộng chiều cao để chứa nhiều nút
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 260, 0, 360) -- Tăng chiều cao lên 360
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15) 
MainFrame.Active = true
MainFrame.Draggable = true 
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

-- 3. Tiêu đề
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(1, 0, 0, 35) 
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🛡️ OPTIMIZER & ANTI-AFK V3"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextSize = 16
TitleLabel.Position = UDim2.new(0, 0, 0, 0)
TitleLabel.Parent = MainFrame

-- ====================================================================
-- HÀM TẠO NÚT BẤM NHANH (UI FACTORY)
-- ====================================================================
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

-- 4. Tạo các nút chức năng
local MainButton = createButton("MainButton", "ANTI-AFK: OFF", 45, 45) -- Nút Anti AFK to hơn chút
local OptLightBtn = createButton("OptLightBtn", "⚡ Tối ưu Ánh Sáng", 100)
local OptWorldBtn = createButton("OptWorldBtn", "🗑️ Xóa Textures & Hạt", 145)
local OptTerrainBtn = createButton("OptTerrainBtn", "🌊 Tối ưu Địa Hình", 190)

-- 5. Khu vực Keybind
local KeybindButton = createButton("KeybindButton", "⚙️ Phím: [Q]", 250, 30)
KeybindButton.Size = UDim2.new(0.45, 0, 0, 30)
KeybindButton.BackgroundColor3 = Color3.fromRGB(139, 92, 246) 

local ExplanationLabel = Instance.new("TextLabel")
ExplanationLabel.Name = "ExplanationLabel"
ExplanationLabel.Size = UDim2.new(0.4, 0, 0, 30)
ExplanationLabel.Position = UDim2.new(0.55, 0, 0, 250) 
ExplanationLabel.BackgroundTransparency = 1
ExplanationLabel.Text = "Nhấn để Ẩn/Hiện UI"
ExplanationLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
ExplanationLabel.Font = Enum.Font.SourceSans
ExplanationLabel.TextSize = 13
ExplanationLabel.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Size = UDim2.new(0.85, 0, 0, 20)
StatusLabel.Position = UDim2.new(0.075, 0, 0, 300) 
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Trạng thái: Đang chờ..."
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
StatusLabel.Font = Enum.Font.SourceSansItalic
StatusLabel.TextSize = 14
StatusLabel.Parent = MainFrame

-- ====================================================================
-- LOGIC OPTIMIZER (CÓ YIELDING & WHITELIST)
-- ====================================================================
local function updateStatus(text)
    StatusLabel.Text = "Trạng thái: " .. text
end

-- Tối ưu Ánh sáng
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

-- Tối ưu Môi trường (Có task.wait và Whitelist)
OptWorldBtn.MouseButton1Click:Connect(function()
    updateStatus("Đang quét và xóa tài nguyên...")
    local count = 0
    
    for _, v in pairs(workspace:GetDescendants()) do
        -- NÂNG CẤP: WHITELIST - Bỏ qua Character của người chơi để không làm nhân vật bị tàng hình/xấu đi
        local model = v:FindFirstAncestorWhichIsA("Model")
        if model and Players:GetPlayerFromCharacter(model) then
            continue 
        end

        -- NÂNG CẤP: WHITELIST - Bỏ qua các vật phẩm quan trọng
        if v.Name == "Handle" or v:IsA("SpawnLocation") or v:IsA("Tool") then
            continue
        end

        if v:IsA("BasePart") then
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0
            v.CastShadow = false
        elseif v:IsA("Texture") or v:IsA("Decal") then
            v:Destroy()
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
            v.Enabled = false
        end

        -- NÂNG CẤP: YIELDING - Ngăn chặn tình trạng đứng game (Freeze)
        count = count + 1
        if count % 800 == 0 then
            task.wait() -- Cho phép game thở 1 frame sau mỗi 800 part được xử lý
        end
    end
    
    OptWorldBtn.Text = "✔️ Đã Xóa Textures/Hạt"
    OptWorldBtn.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
    updateStatus("Xong! Đã quét " .. count .. " vật thể.")
end)

-- Tối ưu Địa hình
OptTerrainBtn.MouseButton1Click:Connect(function()
    updateStatus("Đang tối ưu địa hình...")
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        -- Dùng pcall để thực thi, nếu game khóa thuộc tính thì script vẫn không bị crash
        pcall(function() terrain.WaterWaveSize = 0 end)
        pcall(function() terrain.WaterWaveSpeed = 0 end)
        pcall(function() terrain.WaterReflectance = 0 end)
        pcall(function() terrain.WaterTransparency = 0 end)
        pcall(function() terrain.Decoration = false end) -- Dòng gây lỗi đã được bảo vệ an toàn
    end
    OptTerrainBtn.Text = "✔️ Đã Tối ưu Địa Hình"
    OptTerrainBtn.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
    updateStatus("Hoàn tất địa hình nước/cỏ!")
end)

-- ====================================================================
-- LOGIC ANTI-AFK & KEYBIND (GIỮ NGUYÊN BẢN CŨ CỦA BẠN)
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
        debug_print("Đã giả lập click chuột chống AFK!")
    end
end)

debug_print("✅ SCRIPT V3.0 CHẠY THÀNH CÔNG!")
