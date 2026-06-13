-- ====================================================================
-- PROJECT: ANTI-AFK GUI V2.1 (FIXED FONT ERROR)
-- ====================================================================

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui") 

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function debug_print(msg)
    print("🤖 [Anti-AFK V2.1]: " .. msg)
end

-- 1. Dọn dẹp bản cũ
local existingGui = PlayerGui:FindFirstChild("AntiAFK_Gui_V2")
if existingGui then existingGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AntiAFK_Gui_V2"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

-- 2. Khung nền chính (MainFrame)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 240, 0, 150) 
MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10) 
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

-- 3. Tiêu đề (TitleLabel) - ĐÃ SỬA LỖI FONT Ở ĐÂY
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(1, 0, 0, 30) 
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🛡️ ANTI-AFK SYSTEM V2.1"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.SourceSansBold -- Đã đổi sang font mặc định an toàn
TitleLabel.TextSize = 16
TitleLabel.Position = UDim2.new(0, 0, 0, 0)
TitleLabel.Visible = true
TitleLabel.Parent = MainFrame

-- 4. Nút bấm Toggle chính (MainButton)
local MainButton = Instance.new("TextButton")
MainButton.Name = "MainButton"
MainButton.Size = UDim2.new(0.85, 0, 0, 50) 
MainButton.Position = UDim2.new(0.075, 0, 0, 40) 
MainButton.Font = Enum.Font.SourceSansBold
MainButton.TextSize = 18
MainButton.Visible = true
MainButton.Parent = MainFrame

local ButtonCorner = Instance.new("UICorner")
ButtonCorner.CornerRadius = UDim.new(0, 8)
ButtonCorner.Parent = MainButton

local ButtonStroke = Instance.new("UIStroke")
ButtonStroke.Thickness = 1
ButtonStroke.Color = Color3.fromRGB(255, 255, 255) 
ButtonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ButtonStroke.Parent = MainButton

-- 5. Nút Cài đặt Phím tắt (KeybindButton)
local KeybindButton = Instance.new("TextButton")
KeybindButton.Name = "KeybindButton"
KeybindButton.Size = UDim2.new(0.45, 0, 0, 25) 
KeybindButton.Position = UDim2.new(0.075, 0, 0, 100) 
KeybindButton.BackgroundColor3 = Color3.fromRGB(139, 92, 246) 
KeybindButton.Font = Enum.Font.SourceSansBold
KeybindButton.TextSize = 14
KeybindButton.Visible = true
KeybindButton.Parent = MainFrame

local KeybindCorner = Instance.new("UICorner")
KeybindCorner.CornerRadius = UDim.new(0, 6)
KeybindCorner.Parent = KeybindButton

-- 6. Nhãn Giải thích (ExplanationLabel)
local ExplanationLabel = Instance.new("TextLabel")
ExplanationLabel.Name = "ExplanationLabel"
ExplanationLabel.Size = UDim2.new(0.4, 0, 0, 25)
ExplanationLabel.Position = UDim2.new(0.55, 0, 0, 100) 
ExplanationLabel.BackgroundTransparency = 1
ExplanationLabel.Text = "Nhấn phím để ẩn/hiện"
ExplanationLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
ExplanationLabel.Font = Enum.Font.SourceSans
ExplanationLabel.TextSize = 12
ExplanationLabel.TextWrapped = true
ExplanationLabel.Visible = true
ExplanationLabel.Parent = MainFrame

debug_print("Đã load xong toàn bộ khung UI!")

-- ====================================================================
-- LOGIC CỦA HỆ THỐNG
-- ====================================================================

local antiAFKEnabled = false 
local currentKeybind = Enum.KeyCode.Q 
local isAssigningKeybind = false 

local function updateMainButtonAppearance()
    if antiAFKEnabled then
        MainButton.BackgroundColor3 = Color3.fromRGB(139, 92, 246) 
        MainButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        MainButton.Text = "ANTI-AFK: ON"
        ButtonStroke.Color = Color3.fromRGB(139, 92, 246) 
    else
        MainButton.BackgroundColor3 = Color3.fromRGB(239, 68, 68) 
        MainButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        MainButton.Text = "ANTI-AFK: OFF"
        ButtonStroke.Color = Color3.fromRGB(239, 68, 68) 
    end
end

local function updateKeybindButtonAppearance()
    if isAssigningKeybind then
        KeybindButton.Text = "Gán phím..."
        KeybindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        KeybindButton.BackgroundColor3 = Color3.fromRGB(255, 165, 0) 
    else
        KeybindButton.Text = "⚙️ Phím: [" .. currentKeybind.Name .. "]"
        KeybindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        KeybindButton.BackgroundColor3 = Color3.fromRGB(139, 92, 246) 
    end
end

updateMainButtonAppearance()
updateKeybindButtonAppearance()

MainButton.MouseButton1Click:Connect(function()
    if isAssigningKeybind then return end 
    antiAFKEnabled = not antiAFKEnabled
    updateMainButtonAppearance()
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

debug_print("✅ SCRIPT CHẠY THÀNH CÔNG KHÔNG LỖI!")
