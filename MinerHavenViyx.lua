--[[
    Miner's Haven by Viyx
    - Rayfield (sirius.menu) UI, purple theme (press K to hide/show)
    - Works with the new Jolt networking (Rebirth, Drop, Pulse, DestroyAll, Layouts)
    - Boost tab: auto rebirth cycle + ore boost + layouts (feature set inspired by MX6's hub)
    - Built-in diagnostics: Settings tab -> "Run Diagnostics" / "Dump Remotes"
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players             = game:GetService("Players")
local RS                  = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser         = game:GetService("VirtualUser")
local LocalPlayer         = Players.LocalPlayer or Players.PlayerAdded:Wait()

----------------------------------------------------------------------
-- Load Rayfield
----------------------------------------------------------------------
local okLib, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not okLib or type(Rayfield) ~= "table" then
    warn("[MH] Could not load Rayfield. Your executor may block HttpGet/loadstring:", Rayfield)
    return
end

local function notify(title, content, duration)
    pcall(function()
        Rayfield:Notify({ Title = title, Content = content, Duration = duration or 6 })
    end)
end

----------------------------------------------------------------------
-- Anti-AFK
----------------------------------------------------------------------
LocalPlayer.Idled:Connect(function()
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
        while loops[key] == token do
            local ok, err = pcall(fn)
            if not ok then warn("[MH] loop '" .. key .. "' error:", err) end
            task.wait(interval)
        end
    end)
end

local remoteCache = {}
local function findRemote(name)
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
}

local Jolt
do
    local ok, mod = pcall(function()
        return require(RS:WaitForChild("Modules", 10).Networking.Jolt)
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
        if ch then
            return pcall(ch[method], ch, ...)
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
-- Window + Tabs
----------------------------------------------------------------------
local PurpleTheme = {
    TextColor = Color3.fromRGB(245, 240, 255),

    Background = Color3.fromRGB(24, 18, 38),
    Topbar = Color3.fromRGB(40, 28, 66),
    Shadow = Color3.fromRGB(14, 10, 24),

    NotificationBackground = Color3.fromRGB(30, 22, 50),
    NotificationActionsBackground = Color3.fromRGB(200, 170, 255),

    TabBackground = Color3.fromRGB(52, 38, 86),
    TabStroke = Color3.fromRGB(90, 66, 140),
    TabBackgroundSelected = Color3.fromRGB(150, 100, 240),
    TabTextColor = Color3.fromRGB(225, 215, 245),
    SelectedTabTextColor = Color3.fromRGB(255, 255, 255),

    ElementBackground = Color3.fromRGB(36, 27, 58),
    ElementBackgroundHover = Color3.fromRGB(48, 36, 78),
    SecondaryElementBackground = Color3.fromRGB(28, 21, 46),
    ElementStroke = Color3.fromRGB(78, 58, 122),
    SecondaryElementStroke = Color3.fromRGB(60, 45, 96),

    SliderBackground = Color3.fromRGB(110, 70, 190),
    SliderProgress = Color3.fromRGB(150, 100, 245),
    SliderStroke = Color3.fromRGB(176, 136, 255),

    ToggleBackground = Color3.fromRGB(30, 22, 50),
    ToggleEnabled = Color3.fromRGB(150, 100, 245),
    ToggleDisabled = Color3.fromRGB(90, 80, 110),
    ToggleEnabledStroke = Color3.fromRGB(180, 140, 255),
    ToggleDisabledStroke = Color3.fromRGB(120, 108, 145),
    ToggleEnabledOuterStroke = Color3.fromRGB(110, 84, 170),
    ToggleDisabledOuterStroke = Color3.fromRGB(66, 54, 92),

    DropdownSelected = Color3.fromRGB(52, 38, 86),
    DropdownUnselected = Color3.fromRGB(34, 25, 56),

    InputBackground = Color3.fromRGB(32, 24, 52),
    InputStroke = Color3.fromRGB(90, 66, 140),
    PlaceholderColor = Color3.fromRGB(170, 155, 200),
}

local Window = Rayfield:CreateWindow({
    Name = "Miners Haven by Viyx",
    LoadingTitle = "Miners Haven",
    LoadingSubtitle = "by Viyx",
    Theme = "Amethyst",  -- built-in purple, replaced below by PurpleTheme
    ToggleUIKeybind = "K",
    DisableRayfieldPrompts = true,
    ConfigurationSaving = {
        Enabled = false,  -- true = remember toggles, but they auto-start on inject
        FolderName = "MinersHavenViyx",
        FileName = "Config",
    },
    KeySystem = false,
})
pcall(function() Window.ModifyTheme(PurpleTheme) end)

local MainTab     = Window:CreateTab("Main")
local BoostTab    = Window:CreateTab("Boost")
local SettingsTab = Window:CreateTab("Settings")
local FactoryTab  = Window:CreateTab("Factory")
local NPCTab      = Window:CreateTab("NPC Teleport")
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
MainTab:CreateSection("Main")

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

-- Layout 1 / 2 / 3 loops
for i = 1, 3 do
    MainTab:CreateToggle({
        Name = "Layout " .. i,
        CurrentValue = false,
        Flag = "Layout" .. i,
        Callback = function(state)
            setLoop("layout" .. i, state, 0.01, function()
                callRemote("Layouts", "Load", "Layout" .. i)
            end)
        end,
    })
end

MainTab:CreateToggle({
    Name = "Auto Rebirth",
    CurrentValue = false,
    Flag = "AutoRebirth",
    Callback = function(state)
        setLoop("mainRebirth", state, 0.01, function()
            callRemote("Rebirth")
        end)
    end,
})

MainTab:CreateToggle({
    Name = "Auto Drop",
    CurrentValue = false,
    Flag = "AutoDrop",
    Callback = function(state)
        setLoop("autoDrop", state, 0.02, function()
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
            setLoop("box" .. boxType, state, 0.01, function()
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
        setLoop("autoPulse", state, 0.01, function()
            callRemote("Pulse")
        end)
    end,
})

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
SettingsTab:CreateSection("Auto Layout Switch Settings")

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

SettingsTab:CreateDropdown({
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

SettingsTab:CreateToggle({
    Name = "Auto Layout Switch (1 to 2)",
    CurrentValue = false,
    Flag = "AutoLayout12",
    Callback = function(state) startLayoutSwitch("switch12", state, "Layout2") end,
})

SettingsTab:CreateToggle({
    Name = "Auto Layout Switch (1 to 3)",
    CurrentValue = false,
    Flag = "AutoLayout13",
    Callback = function(state) startLayoutSwitch("switch13", state, "Layout3") end,
})

SettingsTab:CreateDropdown({
    Name = "Auto Rebirth at (only rebirth when cash is met)",
    Options = rebirthOptions,
    CurrentOption = { "1K (Thousand)" },
    MultipleOptions = false,
    Flag = "RebirthThreshold",
    Callback = function(sel)
        rebirthThreshold = rebirthValues[firstOption(sel)] or 1e3
    end,
})

SettingsTab:CreateToggle({
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

SettingsTab:CreateButton({ Name = "Run Diagnostics", Callback = diagnose })

SettingsTab:CreateButton({
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
FactoryTab:CreateSection("Factory Speed Adjuster")

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

RunService.Heartbeat:Connect(function()
    if not boostEnabled then return end
    local dropped = workspace:FindFirstChild("DroppedParts")
    if not dropped then return end
    for _, factory in ipairs(dropped:GetChildren()) do
        if factory.Name:match("^Factory%d+$") then
            for _, ore in ipairs(factory:GetChildren()) do
                if ore:IsA("BasePart") then
                    local vel = ore.AssemblyLinearVelocity
                    if vel.Magnitude > 0 then
                        ore.AssemblyLinearVelocity = Vector3.new(
                            vel.X * oreSpeedMultiplier, vel.Y, vel.Z * oreSpeedMultiplier)
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
    while not myFactory do
        myFactory = getPlayerFactory()
        if not myFactory then task.wait(1) end
    end
    print("[MH] Found factory:", myFactory.Name)
    local adj = myFactory:WaitForChild("AdjustSpeed", 15)
    if not adj then warn("[MH] AdjustSpeed not found in factory"); return end
    while true do
        if not adj.Parent then adj = myFactory:FindFirstChild("AdjustSpeed") end
        if adj and lockEnabled and adj.Value ~= lockedValue then
            adj.Value = lockedValue
        end
        task.wait(0.2)
    end
end)

----------------------------------------------------------------------
-- NPC TELEPORT TAB (targets are resolved when you click, not at load)
----------------------------------------------------------------------
NPCTab:CreateSection("Teleport to NPCs & Factory")

local function addTeleportButton(name, finder)
    NPCTab:CreateButton({
        Name = name,
        Callback = function()
            local ok, target = pcall(finder)
            teleportTo(ok and target or nil)
        end,
    })
end

local function findInMap(npcName)
    local map = workspace:FindFirstChild("Map")
    return map and map:FindFirstChild(npcName, true)
end

addTeleportButton("Craftsman (Wizard Tower #557)", function()
    local map = workspace:FindFirstChild("Map")
    local tower = map and map:FindFirstChild("Tower")
    local wizard = tower and tower:FindFirstChild("Wizard Tower")
    return wizard and wizard:GetChildren()[557]
end)
addTeleportButton("Box Shop (SpookMcDook)", function() return findInMap("SpookMcDook") end)
addTeleportButton("Guest666 (JohnDoe)", function() return findInMap("JohnDoe") end)
addTeleportButton("Superstitious Craftsman (Draedon)", function() return findInMap("Draedon") end)

NPCTab:CreateButton({
    Name = "Find All NPCs in Map (print to console)",
    Callback = function()
        local map = workspace:FindFirstChild("Map")
        if not map then warn("[MH] workspace.Map not found"); return end
        local count = 0
        for _, obj in ipairs(map:GetDescendants()) do
            if obj:IsA("Model") or obj:IsA("BasePart") then
                local n = obj.Name:lower()
                if obj:FindFirstChild("Humanoid") or n:find("npc") or n:find("dude")
                    or n:find("john") or n:find("craft") or n:find("shop") then
                    print("• " .. obj:GetFullName())
                    count += 1
                end
            end
        end
        print("===== Found " .. count .. " possible NPCs =====")
    end,
})

NPCTab:CreateButton({
    Name = "Teleport to My Factory",
    Callback = function()
        local f = getPlayerFactory()
        if f then teleportTo(f) else notify("Factory", "Could not find your factory.") end
    end,
})

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
    text.TextColor3 = Color3.fromRGB(255, 255, 0)
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

    ------------------------------------------------------------------
    -- Shared state
    ------------------------------------------------------------------
    local B = {
        layout1 = "Layout1", layout2 = "None", layoutWait = 10, withdraw = false,
        autoRebirth = false, minWait = 20, randomness = false, skips = 0, stopLife = 0,
        oreBoost = false, oreBoostActive = false, loopCount = 1,
        useIndMine = false, useMoneyLoop = false, farmRP = false,
        oreSize = 0, upgraderSize = 1, autoResize = false, singleItem = "",
        trackOres = false, trackBoxes = false, antiLeave = false,
        walk = 16, jump = 50,
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
            local old = (gethui and gethui() or LocalPlayer:WaitForChild("PlayerGui")):FindFirstChild("ViyxText")
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
            gui.Parent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")
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
    -- Game data (item names)
    ------------------------------------------------------------------
    local function ML(cap, effect, minVal, minWait)
        return { Cap = cap, Effect = effect, MinVal = minVal, MinWait = minWait }
    end
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
        ["Morning Star"] = ML(1e30, "Fire", nil, 1.5),
        ["⭐ Celestial Morning Star ⭐"] = ML(1e30, "Fire", nil, 1.5),
        ["Red Giant"] = ML(1e60, "Fire", nil, 1.5),
        ["⭐ Wholesome Red Giant ⭐"] = ML(1e60, "Fire", nil, 1.5),
        ["Catalyzed Star"] = ML(1e60, "Fire", nil, 1.5),
        ["Neutron Star"] = ML(1e72, "Fire", nil, 1.5),
        ["⭐ Wholesome Neutron Star ⭐"] = ML(1e72, "Fire", nil, 1.5),
        ["Blue Supergiant"] = ML(1e90, "Fire", nil, 1.5),
        ["⭐ Hypergiant Blue Supergiant ⭐"] = ML(1e90, "Fire", nil, 1.5),
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
    -- Ore boost: teleport each ore through the upgraders, then sell it
    ------------------------------------------------------------------
    local function upgradePart(item)
        local model = item and item:FindFirstChild("Model")
        if not model then return nil end
        return model:FindFirstChild("Upgrade") or model:FindFirstChild("Upgrader") or model:FindFirstChild("Scan")
    end

    local function isItem(item)
        return item:FindFirstChild("ItemId") ~= nil or item:GetAttribute("ItemId") ~= nil
    end

    local function refreshFurnace()
        local t = getTycoon()
        if not t then return end
        local f = V.furnace
        if not (f and f.Parent and f:FindFirstChild("Model") and f.Model:FindFirstChild("Lava")) then V.furnace = nil end
        local m = V.indMine
        if not (m and m.Parent and m:FindFirstChild("Model")) then V.indMine = nil end
        for _, item in ipairs(t:GetChildren()) do
            local model = item:FindFirstChild("Model")
            local lava = model and model:FindFirstChild("Lava")
            if lava and not lava:FindFirstChild("TeleportSend") then
                if model:FindFirstChild("Drop") then
                    V.indMine = V.indMine or item
                elseif not item:FindFirstChild("Upgrade") then
                    V.furnace = V.furnace or item
                end
            end
        end
    end

    local function lavaOf(item)
        local model = item and item.Parent and item:FindFirstChild("Model")
        return model and model:FindFirstChild("Lava")
    end

    local function sellOre(ore)
        if not lavaOf(V.furnace) then refreshFurnace() end
        local lava = lavaOf(V.furnace)
        if lava and ore and ore.Parent then
            ore.CFrame = lava.CFrame + Vector3.new(0, 1, 0)
        end
    end

    local function sendThrough(ore, part)
        for _ = 1, B.loopCount do
            if not (ore.Parent and part.Parent and B.oreBoostActive) then return end
            ore.CFrame = part.CFrame
            task.wait(0.01)
        end
    end

    local function boostOre(ore)
        local t = getTycoon()
        if not t then return end
        for _, item in ipairs(t:GetChildren()) do
            if not (B.oreBoostActive and ore.Parent) then return end
            if not MONEY_LOOPABLES[item.Name] and not RESETTER_SET[item.Name]
                and item:FindFirstChild("Plane") and isItem(item) then
                local part = upgradePart(item)
                if part then sendThrough(ore, part) end
            end
        end
    end

    local function resetOre(ore)
        local t = getTycoon()
        if not t then return end
        boostOre(ore)
        for _, group in ipairs(RESET_GROUPS) do
            if not (B.oreBoostActive and ore.Parent) then return end
            local item
            for _, n in ipairs(group) do
                item = t:FindFirstChild(n)
                if item then break end
            end
            local part = item and upgradePart(item)
            if part then
                sendThrough(ore, part)
                boostOre(ore)
            end
        end
    end

    local function moneyLoop(ore)
        local t = getTycoon()
        if not t then return end
        local bestItem, bestInfo
        for name, info in pairs(MONEY_LOOPABLES) do
            local it = t:FindFirstChild(name)
            if it and it:FindFirstChild("Model") and (not bestInfo or info.Cap > bestInfo.Cap) then
                bestItem, bestInfo = it, info
            end
        end
        if not bestItem then return end
        local part = upgradePart(bestItem)
        local cash = ore:FindFirstChild("Cash")
        if not part or not cash then return end
        if bestInfo.MinVal and cash.Value < bestInfo.MinVal then return end

        local protectPart
        for _, n in ipairs(EFFECT_REMOVERS) do
            local p = t:FindFirstChild(n)
            if p then protectPart = upgradePart(p); break end
        end

        local started = os.clock()
        while B.oreBoost and B.oreBoostActive and ore.Parent and bestItem.Parent and cash.Parent
            and cash.Value < bestInfo.Cap and os.clock() - started < 60 do
            for _ = 1, B.loopCount do
                if not (ore.Parent and part.Parent) then break end
                ore.CFrame = part.CFrame
                task.wait(bestInfo.MinWait or 0.01)
                if bestInfo.Effect and protectPart then ore.CFrame = protectPart.CFrame end
            end
            task.wait(0.05)
        end
    end

    local function startOreBoost(ore)
        local cash = ore:WaitForChild("Cash", 5)
        if not cash then return end
        if cash.Value <= 0 then ore.Anchored = false; return end
        if B.useMoneyLoop then moneyLoop(ore) end
        if B.oreBoostActive and ore.Parent then resetOre(ore) end
        if ore.Parent then
            ore.AssemblyAngularVelocity = Vector3.zero
            ore.AssemblyLinearVelocity = Vector3.zero
            sellOre(ore)
        end
    end

    ------------------------------------------------------------------
    -- Trackers (ore value / boxes)
    ------------------------------------------------------------------
    local oreTags, boxTags = {}, {}

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
        if oreTags[ore] then return end
        oreTags[ore] = true
        task.spawn(function()
            local cash = ore:WaitForChild("Cash", 5)
            if not cash or not ore.Parent or not B.trackOres then oreTags[ore] = nil; return end
            local gui, label = makeTag("$" .. shorten(cash.Value))
            gui.Adornee = ore
            gui.Parent = ore
            oreTags[ore] = gui
            local conn = cash.Changed:Connect(function() label.Text = "$" .. shorten(cash.Value) end)
            ore.Destroying:Connect(function() conn:Disconnect(); oreTags[ore] = nil end)
        end)
    end

    local function clearTags(tags)
        for k, gui in pairs(tags) do
            if typeof(gui) == "Instance" then gui:Destroy() end
            tags[k] = nil
        end
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
            if B.useIndMine and ore:FindFirstChild("Fuel") then
                refreshFurnace()
                local lava = lavaOf(V.indMine)
                if lava then ore.CFrame = lava.CFrame + Vector3.new(0, 1, 0) end
                return
            end
            startOreBoost(ore)
        elseif B.farmRP then
            sellOre(ore)
        end
    end

    task.spawn(function()
        local hookedFolder, hookConn
        while true do
            local folder = getOres()
            if folder ~= hookedFolder then
                if hookConn then hookConn:Disconnect(); hookConn = nil end
                hookedFolder = folder
                if folder then
                    refreshFurnace()
                    hookConn = folder.ChildAdded:Connect(function(child)
                        task.spawn(function()
                            local ok, err = pcall(onOreAdded, child)
                            if not ok then warn("[MH] ore error:", err) end
                        end)
                    end)
                end
            end
            task.wait(2)
        end
    end)

    ------------------------------------------------------------------
    -- Layouts + auto rebirth cycle
    ------------------------------------------------------------------
    local function resizeUpgrader(item)
        local model = item:FindFirstChild("Model")
        local up = model and model:FindFirstChild("Upgrade")
        if not up then return end
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

    local function loadLayouts()
        if B.oreBoost then B.oreBoostActive = true end
        callRemote("DestroyAll")
        task.wait(0.3)
        callRemote("Layouts", "Load", B.layout1)
        if B.layout2 ~= "None" then
            task.wait(B.layoutWait)
            B.oreBoostActive = false
            task.wait(0.3)
            if B.withdraw then
                callRemote("DestroyAll")
                task.wait(0.3)
            end
            callRemote("Layouts", "Load", B.layout2)
            task.wait(0.3)
            if B.oreBoost then B.oreBoostActive = true end
        end
        if B.autoResize then resizeAll() end
    end

    local lastRebirth, nextWait, rebirthBusy = os.time(), 20, false

    local function autoRebirthStep()
        if rebirthBusy then return end
        local tycoon = getTycoon()
        local active = LocalPlayer:FindFirstChild("ActiveTycoon")
        if not (tycoon and active and active.Value == tycoon) then
            setStatus("Waiting: you are not in your base")
            return
        end
        local count = getRebirthCount() or 0
        if B.stopLife > 0 and count >= B.stopLife then
            setStatus("Stopped: reached rebirth " .. count)
            B.autoRebirth = false
            pcall(function() rebirthToggle:Set(false) end)
            return
        end

        local price = getRebirthPrice() * 1000 ^ B.skips
        local money = getMoney()
        local remaining = nextWait - (os.time() - lastRebirth)
        setStatus(("Cash %s / need %s%s"):format(shorten(money), shorten(price),
            remaining > 0 and (" | wait " .. remaining .. "s") or ""))
        if money <= price or remaining > 0 then return end

        rebirthBusy = true
        B.oreBoostActive = false
        task.wait(0.1)
        local before = getRebirthCount()
        callRemote("Rebirth")

        local done = false
        for _ = 1, 25 do
            task.wait(0.2)
            local now = getRebirthCount()
            if (before and now and now ~= before) or getMoney() < money * 0.5 then
                done = true
                break
            end
        end

        lastRebirth = os.time()
        nextWait = B.minWait + (B.randomness and math.random(1, 20) or 0)
        if done then
            task.wait(2)
            loadLayouts()
        else
            B.oreBoostActive = B.oreBoost
        end
        rebirthBusy = false
    end

    ------------------------------------------------------------------
    -- BOOST TAB
    ------------------------------------------------------------------
    BoostTab:CreateSection("Auto Rebirth")
    boostStatus = BoostTab:CreateLabel("Status: idle")

    rebirthToggle = BoostTab:CreateToggle({
        Name = "Auto Rebirth (real game price)",
        CurrentValue = false,
        Flag = "VxAutoRebirth",
        Callback = function(state)
            B.autoRebirth = state
            lastRebirth = os.time()
            nextWait = B.minWait
            setLoop("vxAutoRebirth", state, 0.5, autoRebirthStep)
            if not state then setStatus("Status: stopped") end
        end,
    })

    BoostTab:CreateInput({
        Name = "Min time between rebirths (seconds)",
        CurrentValue = "20",
        PlaceholderText = "20",
        RemoveTextAfterFocusLost = false,
        Flag = "VxMinWait",
        Callback = function(text) B.minWait = tonumber(text) or 20 end,
    })

    BoostTab:CreateToggle({
        Name = "Add random wait (+1 to 20 s)",
        CurrentValue = false,
        Flag = "VxRandom",
        Callback = function(state) B.randomness = state end,
    })

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

    BoostTab:CreateSection("Layouts (loaded after every rebirth)")
    BoostTab:CreateDropdown({
        Name = "First layout (ore boost layout)",
        Options = { "Layout1", "Layout2", "Layout3" },
        CurrentOption = { "Layout1" },
        MultipleOptions = false,
        Flag = "VxLayout1",
        Callback = function(sel) B.layout1 = firstOption(sel) or "Layout1" end,
    })
    BoostTab:CreateDropdown({
        Name = "Second layout (loaded after the wait)",
        Options = { "None", "Layout1", "Layout2", "Layout3" },
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

    BoostTab:CreateSection("Ore Boost (ores teleport through your upgraders)")
    oreBoostToggle = BoostTab:CreateToggle({
        Name = "Ore Boost",
        CurrentValue = false,
        Flag = "VxOreBoost",
        Callback = function(state)
            B.oreBoost = state
            B.oreBoostActive = state
        end,
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
        Name = "Track ore value",
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
                clearTags(oreTags)
            end
        end,
    })
    BoostTab:CreateToggle({
        Name = "Track dropped boxes",
        CurrentValue = false,
        Flag = "VxTrackBoxes",
        Callback = function(state)
            B.trackBoxes = state
            setLoop("vxBoxTags", state, 1, function()
                local folder = workspace:FindFirstChild("Boxes")
                if not folder then return end
                for _, box in ipairs(folder:GetChildren()) do
                    if not boxTags[box] then
                        local part = boxAdornee(box)
                        if part then
                            local gui = makeTag(box.Name)
                            gui.Adornee = part
                            gui.Parent = part
                            boxTags[box] = gui
                            box.Destroying:Connect(function()
                                if boxTags[box] then boxTags[box]:Destroy(); boxTags[box] = nil end
                            end)
                        end
                    end
                end
            end)
            if not state then clearTags(boxTags) end
        end,
    })

    BoostTab:CreateSection("Debug")
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
            lines[#lines + 1] = "Furnace: " .. (V.furnace and V.furnace.Name or "none") .. " | Ind mine: " .. (V.indMine and V.indMine.Name or "none")
            lines[#lines + 1] = "-- items (Name | Plane | ItemId | Model | UpgradePart) --"
            if t then
                for i, item in ipairs(t:GetChildren()) do
                    if i > 120 then lines[#lines + 1] = "..."; break end
                    lines[#lines + 1] = ("%s | %s | %s | %s | %s"):format(item.Name,
                        tostring(item:FindFirstChild("Plane") ~= nil), tostring(isItem(item)),
                        tostring(item:FindFirstChild("Model") ~= nil),
                        tostring(upgradePart(item) ~= nil))
                end
            end
            showText(table.concat(lines, "\n"))
        end,
    })

    ------------------------------------------------------------------
    -- TELEPORT TAB
    ------------------------------------------------------------------
    local TeleportTab = Window:CreateTab("Teleport")
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
    Players.PlayerAdded:Connect(refreshPlayers)
    Players.PlayerRemoving:Connect(function() task.delay(0.2, refreshPlayers) end)
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
    local placeNames = { "The Void", "Revenge of John Doe", "Illusion", "Heart of Void",
        "The Temple", "Shiny Void", "Restore Data 2", "Data Restore V3" }
    local selectedPlace = "The Void"
    TeleportTab:CreateDropdown({
        Name = "Place",
        Options = placeNames,
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

    ------------------------------------------------------------------
    -- MISC TAB
    ------------------------------------------------------------------
    local MiscTab = Window:CreateTab("Misc")
    MiscTab:CreateSection("Character")

    local function applyCharacter(hum)
        if not hum then return end
        if B.walk > 16 then hum.WalkSpeed = B.walk end
        if B.jump > 50 then
            hum.UseJumpPower = true
            hum.JumpPower = B.jump
        end
    end
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
    LocalPlayer.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 10)
        applyCharacter(hum)
        if hum then
            hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                if B.walk > 16 and hum.WalkSpeed < B.walk then hum.WalkSpeed = B.walk end
            end)
        end
    end)

    MiscTab:CreateSection("World")
    MiscTab:CreateToggle({
        Name = "Disable game blur",
        CurrentValue = false,
        Flag = "VxBlur",
        Callback = function(state)
            local blur = game:GetService("Lighting"):FindFirstChild("Blur")
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
        activeValue.Changed:Connect(function()
            local tycoon = getTycoon()
            if B.antiLeave and tycoon and (activeValue.Value == nil or activeValue.Value ~= tycoon) then
                local hum = currentHumanoid()
                if hum then hum.Health = 0 end
            end
        end)
    end
end

----------------------------------------------------------------------
-- Finish
----------------------------------------------------------------------
pcall(function() Rayfield:LoadConfiguration() end)
task.delay(3, diagnose)  -- auto-report anything missing
print("[MH] Script loaded.")
