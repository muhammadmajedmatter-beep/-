--[[
    ============================================================
    TimeBomb AnkleBreak — Full DEV Suite
    ============================================================
    UI: Kavo UI Library
    Includes: Bomb Logic + Movement + Survival + Visuals
              + Utilities + Automation + Anti-Cheat Protection
    Protection: __index hook + __namecall block + Kick block
    Toggle: Draggable floating button
    ============================================================
]]

-- ============================================================
-- SECTION 0: Services
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- SECTION 1: Protection Layer
-- ============================================================
local Protection = {
    HooksActive = false,
    BlockedCount = 0,
    PlaceVersion = game.PlaceVersion,
    DefaultWalkSpeed = 16,
    DefaultJumpPower = 50,
    DefaultHipHeight = 2,
    BlockedPatterns = {
        "kick", "ban", "cheatcheck", "walkspeeddetection",
        "teleportcheck", "exploitreport", "anticheat",
        "suspiciousactivity", "movementreport"
    },
    Debug = false
}

local function plog(...)
    if Protection.Debug then
        print("[Protection]", ...)
    end
end

-- Randomized wait for behavioral safety
local function randomWait(minD, maxD)
    local mn = minD or 0.15
    local mx = maxD or 0.85
    task.wait(mn + math.random() * (mx - mn))
end

-- Install protection hooks
local function installProtection()
    local ok, mt = pcall(getrawmetatable, game)
    if not ok or not mt then
        warn("[Protection] Cannot access game metatable")
        return false
    end

    local oldIndex = rawget(mt, "__index")
    local oldNamecall = rawget(mt, "__namecall")

    setreadonly(mt, false)

    -- __index: spoof Humanoid property reads
    if type(oldIndex) == "function" then
        mt.__index = newcclosure(function(self, key)
            if typeof(self) == "Instance" and self.ClassName == "Humanoid" then
                if key == "WalkSpeed" then return Protection.DefaultWalkSpeed end
                if key == "JumpPower" then return Protection.DefaultJumpPower end
                if key == "HipHeight" then return Protection.DefaultHipHeight end
            end
            return oldIndex(self, key)
        end)
    end

    -- __namecall: block suspicious remotes + Kick
    if type(oldNamecall) == "function" then
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()

            -- Block Kick
            if method == "Kick" and self == LocalPlayer then
                plog("Blocked Kick")
                Protection.BlockedCount = Protection.BlockedCount + 1
                return nil
            end

            -- Block suspicious remotes
            if (method == "FireServer" or method == "InvokeServer")
                and typeof(self) == "Instance"
                and (self.ClassName == "RemoteEvent" or self.ClassName == "RemoteFunction") then
                local name = string.lower(self.Name)
                for _, pat in ipairs(Protection.BlockedPatterns) do
                    if string.find(name, pat, 1, true) then
                        Protection.BlockedCount = Protection.BlockedCount + 1
                        plog("Blocked remote:", self.Name)
                        return nil
                    end
                end
            end

            return oldNamecall(self, ...)
        end)
    end

    setreadonly(mt, true)
    Protection.HooksActive = true
    plog("Protection installed | PlaceVersion:", Protection.PlaceVersion)
    return true
end

pcall(installProtection)

-- ============================================================
-- SECTION 2: Kavo UI Library
-- ============================================================
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"
))()

local Window = Library.CreateLib("💣 TimeBomb AnkleBreak — DEV", "BloodTheme")

-- ============================================================
-- SECTION 3: Shared State & Helpers
-- ============================================================
local State = {
    AutoPass = false,
    AutoDodge = false,
    AutoSafeZone = false,
    SafeZonePosition = Vector3.new(0, 300, 0),
    WalkSpeed = 16,
    JumpPower = 50,
    InfJump = false,
    Fly = false,
    FlySpeed = 50,
    NoClip = false,
    GodMode = false,
    BombESP = false,
    NameESP = false,
    FullBright = false,
    BigHitbox = false,
    HitboxSize = 15,
    AntiAFK = false,
    ChatSpam = false,
}

local Connections = {}

local function getChar() return LocalPlayer.Character end
local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getMyBomb()
    local c = getChar()
    if not c then return nil end
    for _, tool in pairs(c:GetChildren()) do
        if tool:IsA("Tool") then return tool end
    end
    return nil
end

local function getBombFromPlayer(player)
    if not player or not player.Character then return nil end
    for _, tool in pairs(player.Character:GetChildren()) do
        if tool:IsA("Tool") then return tool end
    end
    return nil
end

-- ============================================================
-- TAB 1: 💣 Bomb Logic
-- ============================================================
local BombTab = Window:NewTab("💣 Bomb")
local BombSec = BombTab:NewSection("Auto Passing")

BombSec:NewToggle("Auto Pass Bomb", "Pass bomb to nearest player", function(state)
    State.AutoPass = state
    if state then
        task.spawn(function()
            while State.AutoPass do
                randomWait(0.15, 0.45)
                local bomb = getMyBomb()
                local root = getRoot()
                if bomb and root then
                    local closest, minDist = nil, 20
                    for _, p in pairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and p.Character then
                            local pr = p.Character:FindFirstChild("HumanoidRootPart")
                            local ph = p.Character:FindFirstChildOfClass("Humanoid")
                            if pr and ph and ph.Health > 0 then
                                local d = (root.Position - pr.Position).Magnitude
                                if d < minDist then
                                    minDist = d
                                    closest = p
                                end
                            end
                        end
                    end
                    if closest then
                        pcall(function()
                            bomb.Parent = closest.Character
                        end)
                    end
                end
            end
        end)
    end
end)

BombSec:NewToggle("Auto Dodge", "Escape from bomb carrier", function(state)
    State.AutoDodge = state
    if state then
        task.spawn(function()
            while State.AutoDodge do
                randomWait(0.12, 0.28)
                local root = getRoot()
                if root then
                    for _, p in pairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer then
                            local bomb = getBombFromPlayer(p)
                            if bomb then
                                local pr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                                if pr then
                                    local dist = (root.Position - pr.Position).Magnitude
                                    if dist < 25 then
                                        local escape = (root.Position - pr.Position).Unit
                                        root.CFrame = root.CFrame + escape * 8
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end)

BombSec:NewToggle("Auto Safe Zone", "Auto teleport when holding bomb", function(state)
    State.AutoSafeZone = state
    if state then
        task.spawn(function()
            while State.AutoSafeZone do
                randomWait(0.4, 0.9)
                if getMyBomb() then
                    local root = getRoot()
                    if root then
                        root.CFrame = CFrame.new(State.SafeZonePosition)
                    end
                end
            end
        end)
    end
end)

BombSec:NewButton("Safe Zone Teleport", "Teleport instantly", function()
    local root = getRoot()
    if root then
        root.CFrame = CFrame.new(State.SafeZonePosition)
    end
end)

-- ============================================================
-- TAB 2: ⚡ Movement
-- ============================================================
local MoveTab = Window:NewTab("⚡ Movement")
local MoveSec = MoveTab:NewSection("Speed")

MoveSec:NewSlider("WalkSpeed", "Character speed", 200, 16, function(v)
    State.WalkSpeed = v
    local h = getHum()
    if h then h.WalkSpeed = v end
end)

MoveSec:NewSlider("JumpPower", "Jump power", 200, 50, function(v)
    State.JumpPower = v
    local h = getHum()
    if h then
        h.UseJumpPower = true
        h.JumpPower = v
    end
end)

MoveSec:NewToggle("Infinite Jump", "Jump in mid-air", function(state)
    State.InfJump = state
    if state then
        Connections.InfJump = UserInputService.JumpRequest:Connect(function()
            if State.InfJump then
                local h = getHum()
                if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
            end
        end)
    else
        if Connections.InfJump then
            Connections.InfJump:Disconnect()
            Connections.InfJump = nil
        end
    end
end)

MoveSec:NewToggle("Fly", "Enable flight", function(state)
    State.Fly = state
    if state then
        local root = getRoot()
        if not root then return end
        local bv = Instance.new("BodyVelocity")
        bv.Name = "TB_Fly"
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.zero
        bv.Parent = root
        Connections.Fly = RunService.RenderStepped:Connect(function()
            if not State.Fly or not root or not root.Parent then
                if bv then bv:Destroy() end
                return
            end
            local cam = workspace.CurrentCamera
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end
            bv.Velocity = dir.Magnitude > 0 and dir.Unit * State.FlySpeed or Vector3.zero
        end)
    else
        if Connections.Fly then Connections.Fly:Disconnect() end
        local root = getRoot()
        if root then
            local f = root:FindFirstChild("TB_Fly")
            if f then f:Destroy() end
        end
    end
end)

MoveSec:NewSlider("Fly Speed", "Flight speed", 500, 20, function(v)
    State.FlySpeed = v
end)

MoveSec:NewToggle("NoClip", "Walk through walls", function(state)
    State.NoClip = state
    if state then
        Connections.NoClip = RunService.Stepped:Connect(function()
            if State.NoClip then
                local c = getChar()
                if c then
                    for _, p in pairs(c:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                end
            end
        end)
    else
        if Connections.NoClip then Connections.NoClip:Disconnect() end
    end
end)

-- ============================================================
-- TAB 3: 🛡️ Survival
-- ============================================================
local SurvTab = Window:NewTab("🛡️ Survival")
local SurvSec = SurvTab:NewSection("Protection")

SurvSec:NewToggle("God Mode", "Infinite health", function(state)
    State.GodMode = state
    if state then
        Connections.God = RunService.Heartbeat:Connect(function()
            if State.GodMode then
                local h = getHum()
                if h then h.Health = h.MaxHealth end
            end
        end)
    else
        if Connections.God then Connections.God:Disconnect() end
    end
end)

SurvSec:NewButton("Respawn", "Respawn instantly", function()
    LocalPlayer:LoadCharacter()
end)

-- ============================================================
-- TAB 4: 👁️ Visuals
-- ============================================================
local VisTab = Window:NewTab("👁️ Visuals")
local VisSec = VisTab:NewSection("ESP")

VisSec:NewToggle("Bomb Carrier ESP", "Highlight bomb carrier", function(state)
    State.BombESP = state
    if state then
        Connections.BombESP = RunService.RenderStepped:Connect(function()
            if State.BombESP then
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        if getBombFromPlayer(p) then
                            if not p.Character:FindFirstChild("TB_BombHL") then
                                local h = Instance.new("Highlight")
                                h.Name = "TB_BombHL"
                                h.Adornee = p.Character
                                h.FillColor = Color3.fromRGB(255, 0, 0)
                                h.OutlineColor = Color3.fromRGB(255, 0, 0)
                                h.Parent = p.Character
                            end
                        else
                            local h = p.Character:FindFirstChild("TB_BombHL")
                            if h then h:Destroy() end
                        end
                    end
                end
            end
        end)
    else
        if Connections.BombESP then Connections.BombESP:Disconnect() end
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                local h = p.Character:FindFirstChild("TB_BombHL")
                if h then h:Destroy() end
            end
        end
    end
end)

VisSec:NewToggle("Name ESP", "Show names through walls", function(state)
    State.NameESP = state
    if state then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local head = p.Character:FindFirstChild("Head")
                if head and not head:FindFirstChild("TB_Name") then
                    local bb = Instance.new("BillboardGui")
                    bb.Name = "TB_Name"
                    bb.Adornee = head
                    bb.Size = UDim2.new(0, 100, 0, 50)
                    bb.StudsOffset = Vector3.new(0, 3, 0)
                    bb.AlwaysOnTop = true
                    bb.Parent = head
                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(1, 0, 1, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.Text = p.Name
                    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                    lbl.TextStrokeTransparency = 0
                    lbl.TextScaled = true
                    lbl.Parent = bb
                end
            end
        end
    else
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                local head = p.Character:FindFirstChild("Head")
                if head then
                    local bb = head:FindFirstChild("TB_Name")
                    if bb then bb:Destroy() end
                end
            end
        end
    end
end)

VisSec:NewToggle("Full Bright", "Maximum lighting", function(state)
    State.FullBright = state
    if state then
        Lighting.Brightness = 3
        Lighting.ClockTime = 12
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
    else
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1000
        Lighting.GlobalShadows = true
    end
end)

-- ============================================================
-- TAB 5: 🎯 Utilities
-- ============================================================
local UtilTab = Window:NewTab("🎯 Utilities")
local UtilSec = UtilTab:NewSection("Player")

UtilSec:NewToggle("Big Hitbox", "Enlarge player hitboxes", function(state)
    State.BigHitbox = state
    if state then
        Connections.Hitbox = RunService.Stepped:Connect(function()
            if State.BigHitbox then
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local root = p.Character:FindFirstChild("HumanoidRootPart")
                        if root then
                            root.Size = Vector3.new(State.HitboxSize, State.HitboxSize, State.HitboxSize)
                        end
                    end
                end
            end
        end)
    else
        if Connections.Hitbox then Connections.Hitbox:Disconnect() end
    end
end)

UtilSec:NewSlider("Hitbox Size", "Hitbox dimension", 50, 2, function(v)
    State.HitboxSize = v
end)

UtilSec:NewButton("Rejoin Server", "Reconnect", function()
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end)

UtilSec:NewToggle("Anti-AFK", "Prevent idle kick", function(state)
    State.AntiAFK = state
    if state then
        Connections.AFK = LocalPlayer.Idled:Connect(function()
            if State.AntiAFK then
                local vu = game:GetService("VirtualUser")
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end
        end)
    else
        if Connections.AFK then Connections.AFK:Disconnect() end
    end
end)

-- ============================================================
-- TAB 6: ⚙️ Automation
-- ============================================================
local AutoTab = Window:NewTab("⚙️ Automation")
local AutoSec = AutoTab:NewSection("Farm")

AutoSec:NewToggle("Auto Farm Wins", "Enable Auto Pass + Auto Dodge + Safe Zone", function(state)
    if state then
        State.AutoPass = true
        State.AutoDodge = true
        State.AutoSafeZone = true
    else
        State.AutoPass = false
        State.AutoDodge = false
        State.AutoSafeZone = false
    end
end)

AutoSec:NewToggle("Chat Spam", "Send repeated messages", function(state)
    State.ChatSpam = state
    if state then
        task.spawn(function()
            while State.ChatSpam do
                randomWait(1.5, 3.0)
                pcall(function()
                    local chatEvents = game:GetService("ReplicatedStorage")
                        :FindFirstChild("DefaultChatSystemChatEvents")
                    if chatEvents then
                        local sayReq = chatEvents:FindFirstChild("SayMessageRequest")
                        if sayReq then
                            sayReq:FireServer("TimeBomb DEV!", "All")
                        end
                    end
                end)
            end
        end)
    end
end)

-- ============================================================
-- TAB 7: 🛡️ Protection Layer
-- ============================================================
local ProtTab = Window:NewTab("🛡️ Protection")
local ProtSec = ProtTab:NewSection("Anti-Cheat Bypass")

ProtSec:NewParagraph("Hooks: " .. (Protection.HooksActive and "✅ Active" or "❌ Inactive"))
ProtSec:NewParagraph("PlaceVersion: " .. tostring(Protection.PlaceVersion))
ProtSec:NewParagraph("Blocked Remotes: " .. tostring(Protection.BlockedCount))

ProtSec:NewButton("Refresh Status", "Print status to console", function()
    print("[Protection] Hooks:", Protection.HooksActive)
    print("[Protection] Blocked:", Protection.BlockedCount)
    print("[Protection] PlaceVersion:", Protection.PlaceVersion)
end)

ProtSec:NewButton("Block Kick (Extra)", "Install additional Kick block", function()
    local mt = getrawmetatable(game)
    if mt and rawget(mt, "__namecall") then
        local old = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            if getnamecallmethod() == "Kick" and self == LocalPlayer then
                plog("Blocked extra Kick")
                return nil
            end
            return old(self, ...)
        end)
        setreadonly(mt, true)
        print("[Protection] Extra Kick block installed")
    end
end)

-- ============================================================
-- SECTION 4: Kavo Toggle Button (Draggable)
-- ============================================================
local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Name = "KavoToggle"
ToggleGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ToggleGui.ResetOnSpawn = false
ToggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "KavoToggleBtn"
ToggleButton.Parent = ToggleGui
ToggleButton.BackgroundColor3 = Color3.fromRGB(35, 0, 0)
ToggleButton.BorderSizePixel = 0
ToggleButton.Position = UDim2.new(0, 15, 0.45, 0)
ToggleButton.Size = UDim2.new(0, 100, 0, 42)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Text = "💣 MENU"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 18
ToggleButton.Draggable = true
ToggleButton.Active = true
ToggleButton.AutoButtonColor = true

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = ToggleButton

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(180, 0, 0)
stroke.Thickness = 2
stroke.Parent = ToggleButton

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 0, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 0, 0))
}
gradient.Rotation = 45
gradient.Parent = ToggleButton

ToggleButton.MouseButton1Click:Connect(function()
    Library:ToggleUI()
end)

-- ============================================================
-- SECTION 5: Character Respawn Handler
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function(character)
    randomWait(0.3, 0.7)
    local hum = character:WaitForChild("Humanoid", 5)
    if hum then
        hum.WalkSpeed = State.WalkSpeed
        hum.JumpPower = State.JumpPower
        hum.UseJumpPower = true
    end
end)

-- ============================================================
-- SECTION 6: Initialization Notification
-- ============================================================
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "TimeBomb DEV",
    Text = "Protection: " .. (Protection.HooksActive and "ON" or "OFF")
        .. " | Blocked: " .. Protection.BlockedCount,
    Duration = 5
})

print("[TimeBomb DEV] Loaded")
print("[Protection] PlaceVersion:", Protection.PlaceVersion)
print("[Protection] Hooks:", Protection.HooksActive)
