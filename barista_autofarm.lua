-- ============================================
-- BARISTA AUTOFARM - Premium UI Edition
-- Creator: _nznt
-- Discord: discord.gg/q6dUF4CsKH
-- ============================================

local d = false
local h = {}
local x, y
setthreadidentity(2)
for i, v in getgc(true) do
    if typeof(v) == "table" then
        local a = rawget(v, "Detected")
        local b = rawget(v, "Kill")
        if typeof(a) == "function" and not x then
            x = a
            local o; o = hookfunction(x, function(c, f, n)
                if c ~= "_" then
                    if d then warn(`Adonis flagged\nMethod: {c}\nInfo: {f}`) end
                end
                return true
            end)
            table.insert(h, x)
        end
        if rawget(v, "Variables") and rawget(v, "Process") and typeof(b) == "function" and not y then
            y = b
            local o; o = hookfunction(y, function(f)
                if d then warn(`Adonis tried to kill: {f}`) end
            end)
            table.insert(h, y)
        end
    end
end
local o; o = hookfunction(getrenv().debug.info, newcclosure(function(...)
    local a, f = ...
    if x and a == x then return coroutine.yield(coroutine.running()) end
    return o(...)
end))
setthreadidentity(7)

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(2)

-- SETTINGS
local AutofarmEnabled = false
local NoclipEnabled = false
local AntiAFKEnabled = true
local farmingActive = false
local sessionStartMoney = 0
local sessionStartTime = 0

local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")

local Remote = game:GetService("ReplicatedStorage")
    .BaristaAssets.Events.BaristaEvent

-- =====================
-- STATS FUNCTIONS
-- =====================
local function getMoney()
    local pd = Player:FindFirstChild("PlayerData")
    if pd then
        local rp = pd:FindFirstChild("RPValue")
        if rp then return rp.Value end
    end
    return 0
end

local function formatNumber(n)
    local s = tostring(math.floor(n))
    return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function formatTime(t)
    return string.format("%02d:%02d:%02d", math.floor(t/3600)%24, math.floor(t/60)%60, t%60)
end

-- =====================
-- 🔥 NEW MINIGAME SOLVER
-- =====================
local isRunning = false
local connection = nil

local function findMinigameGui()
    for _, gui in ipairs(Player.PlayerGui:GetChildren()) do
        local minigameFrame = gui:FindFirstChild("MinigameFrame", true)
        if minigameFrame and minigameFrame.Visible then
            return minigameFrame
        end
    end
    return nil
end

local function findPlayerCursor(minigameFrame)
    local cursor = minigameFrame:FindFirstChild("PlayerCursor", true)
    if cursor then return cursor end
    
    for _, element in ipairs(minigameFrame:GetDescendants()) do
        if element:IsA("Frame") and element.AbsoluteSize.Y < 15 and element.AbsoluteSize.Y > 5 then
            if element.AbsoluteSize.X > 100 and element.AbsoluteSize.X < 150 then
                return element
            end
        end
    end
    return nil
end

local function shouldClick(playerCursor, targetZone)
    if not playerCursor or not targetZone then return false end
    
    local cursorY = playerCursor.AbsolutePosition.Y
    local cursorHeight = playerCursor.AbsoluteSize.Y
    local cursorCenter = cursorY + cursorHeight / 2
    
    local targetY = targetZone.AbsolutePosition.Y
    local targetHeight = targetZone.AbsoluteSize.Y
    local targetCenter = targetY + targetHeight / 2
    
    return cursorCenter > (targetCenter + 10)
end

local function solve()
    local minigameFrame = findMinigameGui()
    if not minigameFrame then
        print("[Minigame Solver] Minigame closed")
        if connection then connection:Disconnect() end
        isRunning = false
        return
    end
    
    local tapZone = minigameFrame:FindFirstChild("TapZone")
    local targetZone = minigameFrame:FindFirstChild("TargetZone", true)
    local playerCursor = findPlayerCursor(minigameFrame)
    local progressBar = minigameFrame:FindFirstChild("ProgressBar", true)
    
    if not tapZone or not targetZone or not playerCursor then
        return
    end
    
    local tapButton = nil
    for _, child in ipairs(tapZone:GetDescendants()) do
        if child:IsA("GuiButton") or child:IsA("TextButton") or child:IsA("ImageButton") then
            tapButton = child
            break
        end
    end
    
    if not tapButton and (tapZone:IsA("GuiButton") or tapZone:IsA("TextButton") or tapZone:IsA("ImageButton")) then
        tapButton = tapZone
    end
    
    if not tapButton then return end
    
    if shouldClick(playerCursor, targetZone) then
        pcall(function()
            for _, conn in pairs(getconnections(tapButton.MouseButton1Click)) do
                conn:Fire()
            end
        end)
        pcall(function()
            for _, conn in pairs(getconnections(tapButton.MouseButton1Down)) do
                conn:Fire()
            end
        end)
        pcall(function()
            for _, conn in pairs(getconnections(tapButton.Activated)) do
                conn:Fire()
            end
        end)
    end
    
    if progressBar then
        local progress = progressBar.Size.X.Scale
        if progress >= 0.99 then
            print("[Minigame Solver] Complete!")
            if connection then connection:Disconnect() end
            isRunning = false
        end
    end
end

local function startSolver()
    if isRunning then return end
    
    print("[Minigame Solver] Waiting for minigame...")
    isRunning = true
    
    local attempts = 0
    while not findMinigameGui() and attempts < 100 do
        task.wait(0.1)
        attempts = attempts + 1
    end
    
    if not findMinigameGui() then
        print("[Minigame Solver] Not found")
        isRunning = false
        return
    end
    
    print("[Minigame Solver] Solving!")
    connection = RunService.Heartbeat:Connect(solve)
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if not isRunning and findMinigameGui() then
            startSolver()
        end
    end
end)

-- =====================
-- UI SETUP
-- =====================
local Gui = Instance.new("ScreenGui", Player:WaitForChild("PlayerGui"))
Gui.Name = "nznt_BaristaUI"; Gui.IgnoreGuiInset = true; Gui.DisplayOrder = 999; Gui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", Gui)
MainFrame.Size = UDim2.new(0, 320, 0, 400); MainFrame.Position = UDim2.new(0, 20, 0, 20)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
MainFrame.BorderSizePixel = 0; MainFrame.ZIndex = 1
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

-- Top Bar
local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 44); TopBar.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
TopBar.BorderSizePixel = 0; TopBar.ZIndex = 2
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 8)

local TopTitle = Instance.new("TextLabel", TopBar)
TopTitle.Size = UDim2.new(1, -80, 1, 0); TopTitle.Position = UDim2.new(0, 14, 0, 0)
TopTitle.BackgroundTransparency = 1; TopTitle.Text = "BARISTA FARM  ·  nznt_"
TopTitle.TextColor3 = Color3.fromRGB(255, 215, 0); TopTitle.Font = Enum.Font.GothamBold
TopTitle.TextSize = 13; TopTitle.TextXAlignment = Enum.TextXAlignment.Left; TopTitle.ZIndex = 3

-- Hide Button
local hideBtn = Instance.new("TextButton", TopBar)
hideBtn.Size = UDim2.new(0, 60, 0, 28); hideBtn.Position = UDim2.new(1, -70, 0.5, -14)
hideBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40); hideBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
hideBtn.Font = Enum.Font.GothamBold; hideBtn.TextSize = 11; hideBtn.Text = "HIDE"
hideBtn.ZIndex = 3; hideBtn.BorderSizePixel = 0
Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 6)

-- Content Frame
local ContentFrame = Instance.new("Frame", MainFrame)
ContentFrame.Size = UDim2.new(1, -20, 1, -54); ContentFrame.Position = UDim2.new(0, 10, 0, 49)
ContentFrame.BackgroundTransparency = 1; ContentFrame.ZIndex = 2

-- Status Section
local statusLabel = Instance.new("TextLabel", ContentFrame)
statusLabel.Size = UDim2.new(1, 0, 0, 20); statusLabel.Position = UDim2.new(0, 0, 0, 0)
statusLabel.BackgroundTransparency = 1; statusLabel.Text = "Status: Idle"
statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0); statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 14; statusLabel.TextXAlignment = Enum.TextXAlignment.Left; statusLabel.ZIndex = 3

-- Money Earned Row
local moneyLabel = Instance.new("TextLabel", ContentFrame)
moneyLabel.Size = UDim2.new(1, 0, 0, 18); moneyLabel.Position = UDim2.new(0, 0, 0, 25)
moneyLabel.BackgroundTransparency = 1; moneyLabel.Text = "Session Earned: Rp. 0"
moneyLabel.TextColor3 = Color3.fromRGB(200, 200, 200); moneyLabel.Font = Enum.Font.Gotham
moneyLabel.TextSize = 12; moneyLabel.TextXAlignment = Enum.TextXAlignment.Left; moneyLabel.ZIndex = 3

-- Time Row
local timeLabel = Instance.new("TextLabel", ContentFrame)
timeLabel.Size = UDim2.new(1, 0, 0, 18); timeLabel.Position = UDim2.new(0, 0, 0, 45)
timeLabel.BackgroundTransparency = 1; timeLabel.Text = "Session Time: 00:00:00"
timeLabel.TextColor3 = Color3.fromRGB(200, 200, 200); timeLabel.Font = Enum.Font.Gotham
timeLabel.TextSize = 12; timeLabel.TextXAlignment = Enum.TextXAlignment.Left; timeLabel.ZIndex = 3

-- Toggle Button
local toggleBtn = Instance.new("TextButton", ContentFrame)
toggleBtn.Size = UDim2.new(1, 0, 0, 40); toggleBtn.Position = UDim2.new(0, 0, 0, 75)
toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 70); toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.GothamBold; toggleBtn.TextSize = 14; toggleBtn.Text = "START FARMING"
toggleBtn.ZIndex = 3; toggleBtn.BorderSizePixel = 0
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

-- Settings Section
local settingsLabel = Instance.new("TextLabel", ContentFrame)
settingsLabel.Size = UDim2.new(1, 0, 0, 20); settingsLabel.Position = UDim2.new(0, 0, 0, 130)
settingsLabel.BackgroundTransparency = 1; settingsLabel.Text = "SETTINGS"
settingsLabel.TextColor3 = Color3.fromRGB(255, 215, 0); settingsLabel.Font = Enum.Font.GothamBold
settingsLabel.TextSize = 12; settingsLabel.TextXAlignment = Enum.TextXAlignment.Left; settingsLabel.ZIndex = 3

-- Noclip Toggle
local noclipBtn = Instance.new("TextButton", ContentFrame)
noclipBtn.Size = UDim2.new(1, 0, 0, 30); noclipBtn.Position = UDim2.new(0, 0, 0, 155)
noclipBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40); noclipBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
noclipBtn.Font = Enum.Font.Gotham; noclipBtn.TextSize = 12; noclipBtn.Text = "Noclip: OFF"
noclipBtn.ZIndex = 3; noclipBtn.BorderSizePixel = 0
Instance.new("UICorner", noclipBtn).CornerRadius = UDim.new(0, 6)

-- Anti-AFK Toggle
local antiafkBtn = Instance.new("TextButton", ContentFrame)
antiafkBtn.Size = UDim2.new(1, 0, 0, 30); antiafkBtn.Position = UDim2.new(0, 0, 0, 190)
antiafkBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40); antiafkBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
antiafkBtn.Font = Enum.Font.Gotham; antiafkBtn.TextSize = 12; antiafkBtn.Text = "Anti-AFK: ON"
antiafkBtn.ZIndex = 3; antiafkBtn.BorderSizePixel = 0
Instance.new("UICorner", antiafkBtn).CornerRadius = UDim.new(0, 6)

-- Credits
local creditLabel = Instance.new("TextLabel", ContentFrame)
creditLabel.Size = UDim2.new(1, 0, 0, 30); creditLabel.Position = UDim2.new(0, 0, 1, -30)
creditLabel.BackgroundTransparency = 1; creditLabel.Text = "by _nznt | discord.gg/q6dUF4CsKH"
creditLabel.TextColor3 = Color3.fromRGB(130, 130, 130); creditLabel.Font = Enum.Font.Gotham
creditLabel.TextSize = 10; creditLabel.TextXAlignment = Enum.TextXAlignment.Center; creditLabel.ZIndex = 3

-- =====================
-- UI FUNCTIONS
-- =====================
local uiVisible = true
hideBtn.MouseButton1Click:Connect(function()
    uiVisible = not uiVisible
    ContentFrame.Visible = uiVisible
    MainFrame.BackgroundTransparency = uiVisible and 0 or 1
    TopBar.BackgroundTransparency = uiVisible and 0 or 1
    TopTitle.TextTransparency = uiVisible and 0 or 1
    hideBtn.Text = uiVisible and "HIDE" or "SHOW"
end)

noclipBtn.MouseButton1Click:Connect(function()
    NoclipEnabled = not NoclipEnabled
    noclipBtn.Text = "Noclip: " .. (NoclipEnabled and "ON" or "OFF")
    noclipBtn.BackgroundColor3 = NoclipEnabled and Color3.fromRGB(0, 150, 70) or Color3.fromRGB(40, 40, 40)
end)

antiafkBtn.MouseButton1Click:Connect(function()
    AntiAFKEnabled = not AntiAFKEnabled
    antiafkBtn.Text = "Anti-AFK: " .. (AntiAFKEnabled and "ON" or "OFF")
    antiafkBtn.BackgroundColor3 = AntiAFKEnabled and Color3.fromRGB(0, 150, 70) or Color3.fromRGB(40, 40, 40)
end)

-- Update stats loop
task.spawn(function()
    while true do
        task.wait(1)
        if farmingActive then
            local currentMoney = getMoney()
            local earned = math.max(0, currentMoney - sessionStartMoney)
            local elapsed = tick() - sessionStartTime
            moneyLabel.Text = "Session Earned: Rp. " .. formatNumber(earned)
            timeLabel.Text = "Session Time: " .. formatTime(elapsed)
        end
    end
end)

-- =====================
-- CHARACTER HANDLING
-- =====================
Player.CharacterAdded:Connect(function(c)
    Character = c
    HumanoidRootPart = c:WaitForChild("HumanoidRootPart")
end)

-- Anti-AFK
Player.Idled:Connect(function()
    if AntiAFKEnabled then
        local hum = Character and Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Noclip
RunService.Stepped:Connect(function()
    if NoclipEnabled and Character then
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- =====================
-- SEAT SYSTEM
-- =====================
local currentSeat = nil

local function findSeat()
    for _, v in ipairs(workspace:GetChildren()) do
        local found = v:FindFirstChildWhichIsA("VehicleSeat", true)
            or v:FindFirstChildWhichIsA("Seat", true)
        if found then return found end
    end
end

local function getSeat()
    if currentSeat and currentSeat.Parent then return currentSeat end
    currentSeat = findSeat()
    return currentSeat
end

local function SeatTo(position)
    local seat = getSeat()
    if not seat then return false end

    local hum = Character:FindFirstChildOfClass("Humanoid")
    if not hum then return false end

    if hum.SeatPart ~= seat then
        seat.CFrame = HumanoidRootPart.CFrame * CFrame.new(0, -2, -3)
        task.wait(0.2)
        seat:Sit(hum)
        task.wait(0.5)
    end

    seat.CFrame = CFrame.new(position)
    task.wait(0.3)
    return true
end

-- =====================
-- HELPERS
-- =====================
local function PressKeyE(duration)
    duration = duration or 0.5
    
    local success = pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(duration)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    
    if not success then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:SetKeyDown(Enum.KeyCode.E)
            task.wait(duration)
            VirtualUser:SetKeyUp(Enum.KeyCode.E)
        end)
    end
end

local function FirePrompt(position, maxDist)
    maxDist = maxDist or 20
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local part = v.Parent
            if part:IsA("BasePart") and (part.Position - position).Magnitude < maxDist then
                fireproximityprompt(v)
                return true
            end
        end
    end
    PressKeyE(0.5)
    return true
end

local function WalkTo(position, speed)
    local hum = Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    hum.WalkSpeed = speed or 16
    hum:MoveTo(position)

    local reached = false
    local conn
    conn = hum.MoveToFinished:Connect(function()
        reached = true
        conn:Disconnect()
    end)

    local start = tick()
    repeat
        task.wait(0.1)
        if tick() - start > 0.5 then hum:MoveTo(position) end
    until reached or tick() - start > 30

    if conn then conn:Disconnect() end
end

-- =====================
-- JOIN BARISTA TEAM
-- =====================
local function joinBaristaTeam()
    print("[Barista Farm] Joining Barista team...")
    local TeamGui = Player.PlayerGui:FindFirstChild("TeamSelection")
    if TeamGui then
        local BaristaButton = TeamGui:FindFirstChild("BaristaButton", true)
        if BaristaButton and BaristaButton:IsA("TextButton") then
            for _, connection in pairs(getconnections(BaristaButton.MouseButton1Click)) do
                connection:Fire()
            end
            task.wait(1)
        end
    end
end

-- =====================
-- MACHINE CHECK
-- =====================
local function CheckMachineBroke()
    for _, desc in ipairs({game:GetService("CoreGui"), Player.PlayerGui}) do
        for _, gui in ipairs(desc:GetDescendants()) do
            if (gui:IsA("TextLabel") or gui:IsA("TextButton"))
            and gui.Text:find("Machine broke down")
            and gui.Visible then
                return true
            end
        end
    end
    return false
end

local function RepairMachine()
    local repairPos = Vector3.new(-5113.27, 3.19, -672.99)

    SeatTo(repairPos)
    task.wait(0.3)

    local hum = Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.Jump = true end

    task.wait(0.3)
    FirePrompt(repairPos)
    task.wait(6)
end

-- =====================
-- AUTOFARM
-- =====================
local function RunAutofarm()
    joinBaristaTeam()
    
    local seat = getSeat()
    if not seat then
        warn("No seat found!")
        statusLabel.Text = "Status: No seat found"
        return
    end

    local hum = Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    seat.CFrame = HumanoidRootPart.CFrame * CFrame.new(0, -2, -3)
    task.wait(0.3)
    seat:Sit(hum)
    task.wait(0.8)

    SeatTo(Vector3.new(-658.01, 3.18, -701.16))
    SeatTo(Vector3.new(-755.63, 3.80, -641.64))
    SeatTo(Vector3.new(-5011.18, 3.80, -588.81))

    local jobPos = Vector3.new(-4989.87, 4.29, -714.39)
    SeatTo(jobPos)

    VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
    task.wait(0.1)
    VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)

    task.wait(0.4)

    local seat = getSeat()
    if seat then
        seat:Destroy()
        currentSeat = nil
    end

    local root = HumanoidRootPart
    local oldVel = root.Velocity
    root.Velocity = Vector3.zero

    task.wait(0.5)
    PressKeyE(1)
    task.wait(0.5)

    root.Velocity = oldVel

    sessionStartMoney = getMoney()
    sessionStartTime = tick()

    while AutofarmEnabled do
        if CheckMachineBroke() then
            RepairMachine()
        end

        statusLabel.Text = "Status: Brewing..."
        WalkTo(Vector3.new(-4997.14, 4.29, -795.25), 16)
        PressKeyE(1.5)

        local minigameWait = 0
        while isRunning and minigameWait < 15 do
            task.wait(0.5)
            minigameWait = minigameWait + 0.5
        end
        
        task.wait(0.5)

        statusLabel.Text = "Status: Serving..."
        WalkTo(Vector3.new(-4995.79, 4.29, -759.78), 16)
        PressKeyE(1.5)

        task.wait(3)
    end

    farmingActive = false
    statusLabel.Text = "Status: Stopped"
    toggleBtn.Text = "START FARMING"
    toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 70)
end

-- Toggle Button Handler
toggleBtn.MouseButton1Click:Connect(function()
    if farmingActive then
        AutofarmEnabled = false
        farmingActive = false
        statusLabel.Text = "Status: Stopping..."
        toggleBtn.Text = "START FARMING"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 70)
    else
        AutofarmEnabled = true
        farmingActive = true
        statusLabel.Text = "Status: Starting..."
        toggleBtn.Text = "STOP FARMING"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        task.spawn(RunAutofarm)
    end
end)

print("[Barista Autofarm] UI Loaded! Press START FARMING to begin.")
