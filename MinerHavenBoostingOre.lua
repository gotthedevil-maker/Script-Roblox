--[[
    Miner's Haven by Vendios  (fixed / hardened version)
    - Rayfield (sirius.menu) UI
    - Every path / remote is looked up safely (no more infinite WaitForChild hangs)
    - Dropdowns fixed for the new Rayfield API (CurrentOption + Callback are tables)
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
local Window = Rayfield:CreateWindow({
    Name = "Miners Haven by Vendios",
    LoadingTitle = "MH by Vendios",
    LoadingSubtitle = "Rayfield",
    ConfigurationSaving = {
        Enabled = false,  -- true = remember toggles, but they auto-start on inject
        FolderName = "MinersHavenVendios",
        FileName = "Config",
    },
    KeySystem = false,
})

local MainTab     = Window:CreateTab("Main")
local BoostTab    = Window:CreateTab("Ore Boost")
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
-- ORE BOOST TAB
-- Cycle: load boost layout -> wait until cash >= rebirth price -> Rebirth
--        -> (factory is wiped) -> load boost layout again -> repeat
----------------------------------------------------------------------
local boostLayout       = "Layout2"
local boostUseGamePrice = true
local boostClearFirst   = true
local boostLoaded       = false
local boostBackoffUntil = 0
local boostStatus

local function fmtNum(n)
    if type(n) ~= "number" then return tostring(n) end
    if n ~= n then return "nan" end
    if n == math.huge then return "inf" end
    if n < 1e6 then return tostring(math.floor(n)) end
    return ("%.2e"):format(n)
end

local function setBoostStatus(text)
    if boostStatus then pcall(function() boostStatus:Set(text) end) end
end

local warnedPrice = false
local function getRebirthPrice()
    local ok, price = pcall(function()
        return require(RS.Modules.Game.MoneyLib).RebornPrice(LocalPlayer)
    end)
    if ok and type(price) == "number" then return price end
    if not warnedPrice then
        warnedPrice = true
        warn("[MH] Could not read the game's rebirth price (" .. tostring(price) ..
            "). Falling back to the Settings > 'Auto Rebirth at' value.")
    end
    return nil
end

local function getRebirthCount()
    local r = LocalPlayer:FindFirstChild("Rebirths")
    return r and r.Value or nil
end

local function loadBoostLayout()
    if boostClearFirst then
        callRemote("DestroyAll")
        task.wait(0.5)
    end
    callRemote("Layouts", "Load", boostLayout)
end

local function boostStep()
    if not boostLoaded then
        setBoostStatus("Loading " .. boostLayout .. "...")
        loadBoostLayout()
        boostLoaded = true
        task.wait(1)
        return
    end

    local price = (boostUseGamePrice and getRebirthPrice()) or rebirthThreshold
    local money = getMoney()
    setBoostStatus(("Boosting | cash %s / need %s"):format(fmtNum(money), fmtNum(price)))

    if money >= price and os.clock() >= boostBackoffUntil then
        setBoostStatus("Rebirthing...")
        local before = getRebirthCount()
        callRemote("Rebirth")

        local rebirthed = false
        for _ = 1, 20 do  -- wait up to ~4s for the rebirth to register
            task.wait(0.2)
            local now = getRebirthCount()
            if (before and now and now ~= before) or getMoney() < money * 0.5 then
                rebirthed = true
                break
            end
        end

        if rebirthed then
            boostLoaded = false  -- factory was wiped, rebuild it
            task.wait(2)         -- let the rebirth finish before placing again
        else
            boostBackoffUntil = os.clock() + 3  -- rebirth refused, retry later
        end
    end
end

BoostTab:CreateSection("Ore Boost (auto layout + rebirth cycle)")
boostStatus = BoostTab:CreateLabel("Status: idle")

BoostTab:CreateToggle({
    Name = "Ore Boost (auto cycle)",
    CurrentValue = false,
    Flag = "OreBoost",
    Callback = function(state)
        boostLoaded = false
        boostBackoffUntil = 0
        setBoostStatus(state and "Starting..." or "Status: stopped")
        setLoop("oreBoost", state, 0.5, boostStep)
    end,
})

BoostTab:CreateDropdown({
    Name = "Boost layout (the machine setup to place)",
    Options = { "Layout1", "Layout2", "Layout3" },
    CurrentOption = { "Layout2" },
    MultipleOptions = false,
    Flag = "BoostLayout",
    Callback = function(sel)
        boostLayout = firstOption(sel) or "Layout2"
        boostLoaded = false  -- reload with the new layout
    end,
})

BoostTab:CreateToggle({
    Name = "Rebirth at the game's real price",
    CurrentValue = true,
    Flag = "BoostUseGamePrice",
    Callback = function(state) boostUseGamePrice = state end,
})

BoostTab:CreateToggle({
    Name = "Clear factory (DestroyAll) before loading layout",
    CurrentValue = true,
    Flag = "BoostClearFirst",
    Callback = function(state) boostClearFirst = state end,
})

BoostTab:CreateButton({
    Name = "Reload boost layout now",
    Callback = function()
        task.spawn(function()
            loadBoostLayout()
            notify("Ore Boost", "Loaded " .. boostLayout)
        end)
    end,
})

BoostTab:CreateButton({
    Name = "Show cash / rebirth price",
    Callback = function()
        local price = getRebirthPrice()
        notify("Rebirth info", ("Cash: %s\nGame price: %s\nRebirths: %s"):format(
            fmtNum(getMoney()), price and fmtNum(price) or "unavailable (using Settings threshold)",
            tostring(getRebirthCount())))
    end,
})

----------------------------------------------------------------------
-- Finish
----------------------------------------------------------------------
pcall(function() Rayfield:LoadConfiguration() end)
task.delay(3, diagnose)  -- auto-report anything missing
print("[MH] Script loaded.")
