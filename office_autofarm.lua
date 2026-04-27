-- ============================================
-- Office Farm Stealth UI
-- Creator: _nznt
-- Features: Office Worker farm, stats UI, configurable answer delays
-- ============================================

pcall(function()
    if getgenv and getgenv().NZNT_OFFICE_STOP then
        getgenv().NZNT_OFFICE_STOP()
    end
end)

-- Anticheat bypass
pcall(function()
    local debugMode = false
    local detectedFn, killFn

    if setthreadidentity then setthreadidentity(2) end

    if getgc and hookfunction then
        for _, v in ipairs(getgc(true)) do
            if typeof(v) == "table" then
                local detected = rawget(v, "Detected")
                local kill = rawget(v, "Kill")

                if typeof(detected) == "function" and not detectedFn then
                    detectedFn = detected
                    hookfunction(detectedFn, function(method, info, extra)
                        if method ~= "_" and debugMode then
                            warn("[Office Farm] Adonis flagged: " .. tostring(method) .. " | " .. tostring(info))
                        end
                        return true
                    end)
                end

                if rawget(v, "Variables") and rawget(v, "Process") and typeof(kill) == "function" and not killFn then
                    killFn = kill
                    hookfunction(killFn, function(reason)
                        if debugMode then
                            warn("[Office Farm] Adonis tried to kill: " .. tostring(reason))
                        end
                    end)
                end
            end
        end
    end

    if getrenv and hookfunction and newcclosure and detectedFn then
        local oldDebugInfo
        oldDebugInfo = hookfunction(getrenv().debug.info, newcclosure(function(...)
            local target = ...
            if target == detectedFn then
                return coroutine.yield(coroutine.running())
            end
            return oldDebugInfo(...)
        end))
    end

    if setthreadidentity then setthreadidentity(7) end
end)

pcall(function()
    if setthreadidentity then setthreadidentity(7) end
end)

if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(2)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local STATS_FILE = "nznt_office_stats.txt"
local CONFIG_FILE = "nznt_office_config.txt"

local MIN_DELAY = 1.0
local MAX_DELAY = 10.0
local QUESTION_IDLE_TIMEOUT = 7.0
local QUESTION_REQUEST_COOLDOWN = 1.5
local PRINTER_CONFIRM_TIMEOUT = 18.0
local PRINTER_INTERACT_PAUSE = 1.25
local PRINTER_MONEY_CONFIRM_DELTA = 0
local PRINTER_MAX_INTERACT_ATTEMPTS = 3

local answerDelayMin = 2.5
local answerDelayMax = 4.0

local CHAIR_SEARCH_AREA = Vector3.new(-5927.33, 4.57, -228.61)
local CHAIR_SEARCH_RADIUS = 50

local PRINTER_POS = {
    Print_1 = Vector3.new(-6008.84, 4.58, -210.84),
    Print_2 = Vector3.new(-6008.84, 4.58, -224.52),
    Print_3 = Vector3.new(-6008.84, 4.58, -238.36),
    Print_4 = Vector3.new(-5868.43, 4.58, -213.19),
    Print_5 = Vector3.new(-5868.43, 4.58, -249.96)
}

local active = false
local farmRunning = false
local joiningTeam = false
local currentSeat = nil
local pendingPrint = nil
local pendingPrintFromRecovery = false
local isDoingPrinterJob = false
local answeringQuestion = false
local lowGraphicsEnabled = true

local questionsAnswered = 0
local printersCompleted = 0
local totalEarned = 0
local totalTime = 0
local sessionStartTime = nil
local sessionStartMoney = nil
local startTime = nil
local startMoney = nil

local remCorrectAnswer = nil
local remGenQuestion = nil
local remAssignPrint = nil
local questionConnection = nil
local printConnection = nil
local connections = {}
local seatBlockActive = false
local seatBlockToken = 0
local lastQuestionSeenAt = os.clock()
local lastQuestionRequestAt = 0
local questionRequestInFlight = false
local lastKnownPrint = nil
local chairIdleRescueCount = 0
local lowGraphicsApplied = false

local function simplifyVisual(instance)
    pcall(function()
        if instance:IsA("BasePart") then
            instance.Material = Enum.Material.SmoothPlastic
            instance.Reflectance = 0
            instance.CastShadow = false
        end

        if instance:IsA("MeshPart") then
            instance.TextureID = ""
        elseif instance:IsA("SpecialMesh") then
            instance.TextureId = ""
        elseif instance:IsA("Decal") or instance:IsA("Texture") or instance:IsA("SurfaceAppearance") then
            instance:Destroy()
        elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam") then
            instance.Enabled = false
        elseif instance:IsA("Smoke") or instance:IsA("Fire") or instance:IsA("Sparkles") then
            instance.Enabled = false
        end
    end)
end

local function applyLowGraphics()
    if not lowGraphicsEnabled or lowGraphicsApplied then return end
    lowGraphicsApplied = true

    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        settings().Rendering.QualityLevel = 1
    end)

    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 1
    end)

    for _, effect in ipairs(Lighting:GetChildren()) do
        pcall(function()
            if effect:IsA("PostEffect") or effect:IsA("Atmosphere") or effect:IsA("Sky") then
                effect:Destroy()
            end
        end)
    end

    task.spawn(function()
        local processed = 0
        for _, obj in ipairs(workspace:GetDescendants()) do
            simplifyVisual(obj)
            processed = processed + 1
            if processed % 250 == 0 then
                task.wait()
            end
        end
    end)

    table.insert(connections, workspace.DescendantAdded:Connect(function(obj)
        if lowGraphicsEnabled then
            task.defer(simplifyVisual, obj)
        end
    end))
end

local function formatNumber(n)
    n = tonumber(n) or 0
    local sign = n < 0 and "-" or ""
    local s = tostring(math.floor(math.abs(n)))
    return sign .. s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function formatTime(t)
    t = math.max(0, math.floor(tonumber(t) or 0))
    return string.format("%02d:%02d:%02d", math.floor(t / 3600) % 24, math.floor(t / 60) % 60, t % 60)
end

local function formatDelay(v)
    return string.format("%.1f", tonumber(v) or 0)
end

local function getMoney()
    local playerData = Player:FindFirstChild("PlayerData")
    if playerData then
        local value = playerData:FindFirstChild("RPValue")
            or playerData:FindFirstChild("Money")
            or playerData:FindFirstChild("Cash")
        if value and value.Value ~= nil then
            return tonumber(value.Value) or 0
        end
    end

    local leaderstats = Player:FindFirstChild("leaderstats")
    if leaderstats then
        local value = leaderstats:FindFirstChild("RP")
            or leaderstats:FindFirstChild("Money")
            or leaderstats:FindFirstChild("Cash")
        if value and value.Value ~= nil then
            return tonumber(value.Value) or 0
        end
    end

    return 0
end

local function loadStats()
    if not isfile or not readfile or not isfile(STATS_FILE) then return end

    local content = readfile(STATS_FILE)
    local earned, time = tostring(content):match("^%s*([%d%.%-]+)%s*,%s*([%d%.%-]+)%s*$")
    totalEarned = tonumber(earned) or totalEarned
    totalTime = tonumber(time) or totalTime
end

local function saveStats(earned, time)
    if not writefile then return end
    writefile(STATS_FILE, tostring(math.max(0, earned or totalEarned)) .. "," .. tostring(math.max(0, time or totalTime)))
end

local function loadConfig()
    if not isfile or not readfile or not isfile(CONFIG_FILE) then return end

    local content = tostring(readfile(CONFIG_FILE) or "")
    local values = {}
    for value in content:gmatch("[%d%.]+") do
        table.insert(values, tonumber(value))
    end

    if #values >= 4 then
        answerDelayMin = math.clamp(values[3] or answerDelayMin, MIN_DELAY, MAX_DELAY)
        answerDelayMax = math.clamp(values[4] or answerDelayMax, answerDelayMin, MAX_DELAY)
    elseif #values >= 2 then
        answerDelayMin = math.clamp(values[1] or answerDelayMin, MIN_DELAY, MAX_DELAY)
        answerDelayMax = math.clamp(values[2] or answerDelayMax, answerDelayMin, MAX_DELAY)
    end
end

local function saveConfig()
    if not writefile then return end
    writefile(CONFIG_FILE, table.concat({
        formatDelay(answerDelayMin),
        formatDelay(answerDelayMax)
    }, ","))
end

loadStats()
loadConfig()

local function randomDelay(minValue, maxValue)
    minValue = math.clamp(tonumber(minValue) or MIN_DELAY, MIN_DELAY, MAX_DELAY)
    maxValue = math.clamp(tonumber(maxValue) or minValue, minValue, MAX_DELAY)
    return minValue + math.random() * (maxValue - minValue)
end

local function safeFireServer(remote, ...)
    if not remote then return end

    local args = {...}
    task.spawn(function()
        if setthreadidentity then pcall(setthreadidentity, 2) end
        pcall(function()
            remote:FireServer(unpack(args))
        end)
        if setthreadidentity then pcall(setthreadidentity, 7) end
    end)
end

local function getChar()
    return Player.Character or Player.CharacterAdded:Wait()
end

local function sendKey(key)
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local sprintHoldToken = 0

local function startSprintHold()
    sprintHoldToken = sprintHoldToken + 1
    local token = sprintHoldToken

    task.spawn(function()
        while token == sprintHoldToken and active do
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
            end)
            task.wait(0.2)
        end
    end)
end

local function releaseSprint()
    sprintHoldToken = sprintHoldToken + 1

    pcall(function()
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
    end)
end

local function forceStand(hum)
    if not hum then return end

    if hum.SeatPart or hum.Sit then
        hum.Sit = false
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end

local function setSeatBlocking(enabled)
    seatBlockActive = enabled
    seatBlockToken = seatBlockToken + 1
    local token = seatBlockToken

    local function updateHumanoid()
        local char = Player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if not hum then return end

        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.Seated, not enabled)
        end)

        if enabled and hum.SeatPart then
            hum.Sit = false
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
        end
    end

    updateHumanoid()

    if enabled then
        task.spawn(function()
            while seatBlockActive and seatBlockToken == token do
                updateHumanoid()
                task.wait(0.1)
            end
        end)
    end
end

local function interactWithPrinter()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(1.8)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    return true
end

local function nudgeToward(root, targetPos)
    if not root then return end

    local delta = targetPos - root.Position
    if delta.Magnitude < 1 then return end

    pcall(function()
        local step = math.min(delta.Magnitude, 4)
        root.CFrame = CFrame.new(root.Position + delta.Unit * step + Vector3.new(0, 0.25, 0), targetPos)
    end)
end

local function solveQuestion(question)
    local a, op, b = tostring(question):match("(%d+)%s*([%+%-%*%/])%s*(%d+)")
    if not a then return nil end

    a = tonumber(a)
    b = tonumber(b)

    if op == "+" then
        return a + b
    elseif op == "-" then
        return a - b
    elseif op == "*" then
        return a * b
    elseif op == "/" and b ~= 0 then
        return math.floor(a / b)
    end

    return nil
end

local function findAvailableChair()
    local bestChair = nil
    local closestDist = math.huge

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Seat") or obj:IsA("VehicleSeat") then
            local dist = (obj.Position - CHAIR_SEARCH_AREA).Magnitude
            if dist < CHAIR_SEARCH_RADIUS and not obj.Occupant and dist < closestDist then
                closestDist = dist
                bestChair = obj
            end
        end
    end

    return bestChair
end

local function seatTP(targetSeat)
    if not targetSeat then return false end

    local char = getChar()
    local hum = char:WaitForChild("Humanoid")
    local root = char:WaitForChild("HumanoidRootPart")

    local tempSeat = Instance.new("Seat")
    tempSeat.Size = Vector3.new(4, 1, 4)
    tempSeat.Transparency = 1
    tempSeat.CanCollide = false
    tempSeat.Anchored = true
    tempSeat.CFrame = CFrame.new(root.Position + Vector3.new(0, -2, 0))
    tempSeat.Parent = workspace

    task.wait(0.1)
    tempSeat:Sit(hum)
    task.wait(0.3)
    tempSeat.CFrame = targetSeat.CFrame
    task.wait(0.5)
    hum.Sit = false
    task.wait(0.2)

    pcall(function()
        tempSeat:Destroy()
    end)

    task.wait(0.1)
    targetSeat:Sit(hum)
    task.wait(0.5)

    return hum.SeatPart == targetSeat
end

local function walkTo(targetPos, options)
    options = options or {}

    local char = getChar()
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end

    local radius = options.radius or 5
    local finalTimeout = options.finalTimeout or 4
    local requirePrinterJob = options.requirePrinterJob ~= false

    local function shouldKeepWalking()
        return active and (not requirePrinterJob or isDoingPrinterJob)
    end

    startSprintHold()
    forceStand(hum)

    local path = PathfindingService:CreatePath({
        AgentRadius = options.agentRadius or 3.5,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentJumpHeight = 7.5,
        AgentMaxSlope = 45
    })

    local success = pcall(function()
        path:ComputeAsync(root.Position, targetPos)
    end)

    if not success or path.Status ~= Enum.PathStatus.Success then
        hum:MoveTo(targetPos)
        local started = os.clock()
        while shouldKeepWalking() and (root.Position - targetPos).Magnitude > radius and os.clock() - started < finalTimeout do
            forceStand(hum)
            hum:MoveTo(targetPos)
            task.wait(0.2)
        end
        releaseSprint()
        return (root.Position - targetPos).Magnitude <= radius
    end

    for _, waypoint in ipairs(path:GetWaypoints()) do
        if not shouldKeepWalking() then break end

        if waypoint.Action == Enum.PathWaypointAction.Jump then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end

        hum:MoveTo(waypoint.Position)

        local started = os.clock()
        local lastDistance = (root.Position - waypoint.Position).Magnitude
        local stallTicks = 0

        while shouldKeepWalking() and (root.Position - waypoint.Position).Magnitude > radius and os.clock() - started < 3.5 do
            forceStand(hum)

            local currentDistance = (root.Position - waypoint.Position).Magnitude
            if currentDistance >= lastDistance - 0.15 then
                stallTicks = stallTicks + 1
            else
                stallTicks = 0
            end

            if stallTicks >= 8 then
                hum:MoveTo(waypoint.Position)
                hum.Jump = true
            end

            if stallTicks >= 16 then
                nudgeToward(root, waypoint.Position)
                break
            end

            lastDistance = currentDistance
            task.wait(0.1)
        end
    end

    local started = os.clock()
    while shouldKeepWalking() and (root.Position - targetPos).Magnitude > radius and os.clock() - started < finalTimeout do
        forceStand(hum)
        hum:MoveTo(targetPos)
        task.wait(0.2)
    end

    releaseSprint()
    return (root.Position - targetPos).Magnitude <= radius
end

local function ensureRemotes()
    local jobEvents = ReplicatedStorage:WaitForChild("JobEvents", 10)
    if not jobEvents then
        return false, "JobEvents not found"
    end

    remCorrectAnswer = jobEvents:WaitForChild("CorrectAnswer", 10)
    remGenQuestion = jobEvents:WaitForChild("GenerateQuestion", 10)
    remAssignPrint = jobEvents:WaitForChild("AssignPrintJob", 10)

    if not remCorrectAnswer or not remGenQuestion or not remAssignPrint then
        return false, "Office remotes not found"
    end

    return true
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "nznt_OfficeFarmUI"
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 999
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local MainFrame = Instance.new("Frame", Gui)
MainFrame.Size = UDim2.new(1, 0, 1, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
MainFrame.BorderSizePixel = 0
MainFrame.ZIndex = 1

local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 44)
TopBar.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 2

local TopTitle = Instance.new("TextLabel", TopBar)
TopTitle.Size = UDim2.new(1, -120, 1, 0)
TopTitle.Position = UDim2.new(0, 14, 0, 0)
TopTitle.BackgroundTransparency = 1
TopTitle.Text = "OFFICE FARM - nznt_"
TopTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
TopTitle.Font = Enum.Font.GothamBold
TopTitle.TextSize = 13
TopTitle.TextXAlignment = Enum.TextXAlignment.Left
TopTitle.ZIndex = 3

local hideBtn = Instance.new("TextButton", TopBar)
hideBtn.Size = UDim2.new(0, 70, 0, 28)
hideBtn.Position = UDim2.new(1, -80, 0.5, -14)
hideBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
hideBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
hideBtn.Font = Enum.Font.GothamBold
hideBtn.TextSize = 12
hideBtn.Text = "HIDE"
hideBtn.ZIndex = 3
hideBtn.BorderSizePixel = 0
Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 6)

local ScrollFrame = Instance.new("ScrollingFrame", MainFrame)
ScrollFrame.Size = UDim2.new(1, 0, 1, -44)
ScrollFrame.Position = UDim2.new(0, 0, 0, 44)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollFrame.ZIndex = 2

local listLayout = Instance.new("UIListLayout", ScrollFrame)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 1)

local padding = Instance.new("UIPadding", ScrollFrame)
padding.PaddingBottom = UDim.new(0, 10)

hideBtn.MouseButton1Click:Connect(function()
    ScrollFrame.Visible = not ScrollFrame.Visible
    local transparency = ScrollFrame.Visible and 0 or 1
    MainFrame.BackgroundTransparency = transparency
    TopBar.BackgroundTransparency = transparency
    TopTitle.TextTransparency = transparency
    hideBtn.Text = ScrollFrame.Visible and "HIDE" or "SHOW"
end)

local function makeContainer(height, order)
    local frame = Instance.new("Frame", ScrollFrame)
    frame.Size = UDim2.new(1, 0, 0, height)
    frame.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
    frame.BorderSizePixel = 0
    frame.ZIndex = 3
    frame.LayoutOrder = order
    return frame
end

local function makeSection(title, order)
    local section = makeContainer(28, order)
    section.BackgroundColor3 = Color3.fromRGB(13, 13, 13)

    local label = Instance.new("TextLabel", section)
    label.Size = UDim2.new(1, -14, 1, 0)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = string.upper(title)
    label.TextColor3 = Color3.fromRGB(255, 215, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 10
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 4
end

local function makeRow(icon, label, valueDefault, order)
    local row = makeContainer(38, order)

    local iconLabel = Instance.new("TextLabel", row)
    iconLabel.Size = UDim2.new(0, 30, 1, 0)
    iconLabel.Position = UDim2.new(0, 10, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 16
    iconLabel.ZIndex = 4

    local nameLabel = Instance.new("TextLabel", row)
    nameLabel.Size = UDim2.new(0.45, 0, 1, 0)
    nameLabel.Position = UDim2.new(0, 44, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = label
    nameLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextSize = 13
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 4

    local valueLabel = Instance.new("TextLabel", row)
    valueLabel.Size = UDim2.new(0.5, -14, 1, 0)
    valueLabel.Position = UDim2.new(0.5, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = valueDefault
    valueLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 13
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.ZIndex = 4

    local sep = Instance.new("Frame", row)
    sep.Size = UDim2.new(1, -14, 0, 1)
    sep.Position = UDim2.new(0, 7, 1, -1)
    sep.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    sep.BorderSizePixel = 0
    sep.ZIndex = 4

    return valueLabel
end

local function makeSlider(icon, label, minValue, maxValue, currentValue, order, onChange)
    local row = makeContainer(70, order)
    local current = currentValue

    local iconLabel = Instance.new("TextLabel", row)
    iconLabel.Size = UDim2.new(0, 30, 0, 28)
    iconLabel.Position = UDim2.new(0, 10, 0, 5)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 16
    iconLabel.ZIndex = 4

    local nameLabel = Instance.new("TextLabel", row)
    nameLabel.Size = UDim2.new(0.45, 0, 0, 28)
    nameLabel.Position = UDim2.new(0, 44, 0, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = label
    nameLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextSize = 13
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 4

    local valueBox = Instance.new("TextBox", row)
    valueBox.Size = UDim2.new(0, 56, 0, 28)
    valueBox.Position = UDim2.new(1, -70, 0, 5)
    valueBox.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    valueBox.Text = formatDelay(current)
    valueBox.TextColor3 = Color3.fromRGB(230, 230, 230)
    valueBox.Font = Enum.Font.GothamBold
    valueBox.TextSize = 13
    valueBox.TextXAlignment = Enum.TextXAlignment.Center
    valueBox.ClearTextOnFocus = false
    valueBox.BorderSizePixel = 0
    valueBox.ZIndex = 10
    Instance.new("UICorner", valueBox).CornerRadius = UDim.new(0, 4)

    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(1, -114, 0, 6)
    track.Position = UDim2.new(0, 44, 0, 45)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    track.BorderSizePixel = 0
    track.ZIndex = 4
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 3)

    local fill = Instance.new("Frame", track)
    fill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    fill.BorderSizePixel = 0
    fill.ZIndex = 5
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 6
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local sep = Instance.new("Frame", row)
    sep.Size = UDim2.new(1, -14, 0, 1)
    sep.Position = UDim2.new(0, 7, 1, -1)
    sep.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    sep.BorderSizePixel = 0
    sep.ZIndex = 4

    local function refresh(value, callCallback)
        value = math.clamp(tonumber(value) or current, minValue, maxValue)
        value = math.floor(value * 10) / 10
        current = value

        local ratio = (value - minValue) / (maxValue - minValue)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, -9, 0.5, -9)
        valueBox.Text = formatDelay(value)

        if callCallback then
            onChange(value)
        end
    end

    local function setFromInput(input)
        local width = track.AbsoluteSize.X
        if width <= 0 then return end

        local ratio = math.clamp((input.Position.X - track.AbsolutePosition.X) / width, 0, 1)
        refresh(minValue + ratio * (maxValue - minValue), true)
    end

    refresh(current, false)

    valueBox.FocusLost:Connect(function()
        local parsed = tonumber(valueBox.Text:gsub("[^%d%.%-]", ""))
        if parsed then
            refresh(parsed, true)
        else
            valueBox.Text = formatDelay(current)
        end
    end)

    local dragging = false
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromInput(input)
        end
    end)
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromInput(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromInput(input)
        end
    end)

    return function(value)
        refresh(value, false)
    end
end

makeSection("About", 0)
local aboutRow = makeContainer(100, 1)

local avatar = Instance.new("ImageLabel", aboutRow)
avatar.Size = UDim2.new(0, 80, 0, 80)
avatar.Position = UDim2.new(0, 10, 0.5, -40)
avatar.BackgroundTransparency = 1
avatar.Image = "rbxassetid://75353810328300"
avatar.ScaleType = Enum.ScaleType.Crop
avatar.ZIndex = 4
Instance.new("UICorner", avatar).CornerRadius = UDim.new(0, 10)

local credit = Instance.new("TextLabel", aboutRow)
credit.Size = UDim2.new(1, -104, 1, 0)
credit.Position = UDim2.new(0, 100, 0, 0)
credit.BackgroundTransparency = 1
credit.Text = "Script made by _nznt\nOffice Farm + Anti-AFK + Auto Start\n100% by myself"
credit.TextColor3 = Color3.fromRGB(255, 215, 0)
credit.Font = Enum.Font.Gotham
credit.TextSize = 12
credit.TextXAlignment = Enum.TextXAlignment.Left
credit.TextYAlignment = Enum.TextYAlignment.Center
credit.TextWrapped = true
credit.ZIndex = 4

makeSection("Money", 10)
local vCurrent = makeRow("💰", "Current Money", "Rp. 0", 11)
local vEarned = makeRow("📈", "Earned", "Rp. 0", 12)
local vMoneyHour = makeRow("⚡", "Money / Hour", "Calculating...", 13)

makeSection("Total Stats", 15)
local vTotalEarned = makeRow("🏆", "Total Earned", "Rp. " .. formatNumber(totalEarned), 16)
local vTotalTime = makeRow("⏰", "Total Time", formatTime(totalTime), 17)

local resetRow = makeContainer(50, 18)
local resetBtn = Instance.new("TextButton", resetRow)
resetBtn.Size = UDim2.new(1, -20, 0, 32)
resetBtn.Position = UDim2.new(0, 10, 0, 9)
resetBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
resetBtn.Font = Enum.Font.GothamBold
resetBtn.TextSize = 12
resetBtn.Text = "🔄 Reset Total Stats"
resetBtn.BorderSizePixel = 0
resetBtn.ZIndex = 4
Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 5)

makeSection("Delays", 20)

local setAnswerMinSlider
local setAnswerMaxSlider

setAnswerMinSlider = makeSlider("⏱", "Answer Delay Min", MIN_DELAY, MAX_DELAY, answerDelayMin, 21, function(value)
    answerDelayMin = value
    if answerDelayMax < answerDelayMin then
        answerDelayMax = answerDelayMin
        if setAnswerMaxSlider then setAnswerMaxSlider(answerDelayMax) end
    end
    saveConfig()
end)

setAnswerMaxSlider = makeSlider("⏳", "Answer Delay Max", MIN_DELAY, MAX_DELAY, answerDelayMax, 22, function(value)
    answerDelayMax = math.max(value, answerDelayMin)
    if value < answerDelayMin and setAnswerMaxSlider then
        setAnswerMaxSlider(answerDelayMax)
    end
    saveConfig()
end)

makeSection("Performance", 24)
local vLowGraphics = makeRow("▣", "Low Graphics", lowGraphicsEnabled and "Enabled" or "Off", 25)

makeSection("Office Stats", 30)
local vStatus = makeRow("▶", "Status", "Auto starting...", 31)
local vQuestions = makeRow("🧠", "Questions Answered", "0", 32)
local vPrinters = makeRow("🖨", "Printers Completed", "0", 33)

local function setStatus(text)
    vStatus.Text = text
    print("[Office Farm] " .. text)
end

applyLowGraphics()
vLowGraphics.Text = lowGraphicsEnabled and "Enabled" or "Off"

resetBtn.MouseButton1Click:Connect(function()
    totalEarned = 0
    totalTime = 0
    saveStats(0, 0)
    vTotalEarned.Text = "Rp. 0"
    vTotalTime.Text = "00:00:00"
    resetBtn.Text = "Stats Reset"
    resetBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 70)
    task.wait(2)
    resetBtn.Text = "🔄 Reset Total Stats"
    resetBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
end)

local function requestQuestion(statusText)
    if not remGenQuestion then return false end
    if pendingPrint or isDoingPrinterJob then
        if statusText then
            setStatus("Print pending - skipping question request")
        end
        return false
    end
    if questionRequestInFlight then
        if statusText then
            setStatus("Question request already pending")
        end
        return false
    end
    if os.clock() - lastQuestionRequestAt < QUESTION_REQUEST_COOLDOWN then return false end

    questionRequestInFlight = true
    lastQuestionRequestAt = os.clock()
    if statusText then
        setStatus(statusText)
    end

    task.spawn(function()
        if setthreadidentity then pcall(setthreadidentity, 2) end
        local ok = pcall(function()
            remGenQuestion:FireServer()
        end)
        if setthreadidentity then pcall(setthreadidentity, 7) end

        if not ok then
            questionRequestInFlight = false
            setStatus("Question request failed")
        end
    end)

    return true
end

local function detectAssignedPrinterFromGui()
    local containers = {PlayerGui}
    pcall(function()
        table.insert(containers, game:GetService("CoreGui"))
    end)

    for _, container in ipairs(containers) do
        local ok, descendants = pcall(function()
            return container:GetDescendants()
        end)

        if ok then
            for _, gui in ipairs(descendants) do
                local isOwnUi = false
                pcall(function()
                    isOwnUi = Gui and gui:IsDescendantOf(Gui)
                end)

                if not isOwnUi and (gui:IsA("TextLabel") or gui:IsA("TextButton") or gui:IsA("TextBox")) then
                    local text = tostring(gui.Text or "")
                    local direct = text:match("Print_%d")
                    if direct and PRINTER_POS[direct] then
                        return direct
                    end

                    local numbered = text:match("[Pp]rinter%s*(%d)") or text:match("[Pp]rint[%s_%-]*(%d)")
                    if numbered and PRINTER_POS["Print_" .. numbered] then
                        return "Print_" .. numbered
                    end
                end
            end
        end
    end

    return nil
end

local function recoverIdleOfficeFlow()
    local detectedPrint = detectAssignedPrinterFromGui()
    if detectedPrint then
        pendingPrint = detectedPrint
        pendingPrintFromRecovery = true
        lastKnownPrint = detectedPrint
        setStatus("No question - printer detected: " .. detectedPrint)
        return
    end

    chairIdleRescueCount = chairIdleRescueCount + 1

    if lastKnownPrint then
        pendingPrint = lastKnownPrint
        pendingPrintFromRecovery = true
        setStatus("No question - checking last printer")
        return
    end

    if questionRequestInFlight then
        setStatus("Waiting for question response")
        return
    end

    requestQuestion("No question for 7s - refreshing")
end

local function completePrinterJob(printName, pos)
    local started = os.clock()
    local attempts = 0
    local moneyBeforePrint = getMoney()
    local sawPrintInGui = detectAssignedPrinterFromGui() == printName

    while active and pendingPrint == printName and os.clock() - started < PRINTER_CONFIRM_TIMEOUT do
        local char = getChar()
        local root = char:FindFirstChild("HumanoidRootPart")

        if root and (root.Position - pos).Magnitude > 8 then
            setStatus("Repositioning to printer...")
            walkTo(pos, {radius = 5, finalTimeout = 5})
        end

        attempts = attempts + 1
        setStatus("Printing " .. tostring(printName) .. " (" .. tostring(attempts) .. ")")
        interactWithPrinter()

        local waitUntil = os.clock() + PRINTER_INTERACT_PAUSE
        repeat
            if getMoney() > moneyBeforePrint + PRINTER_MONEY_CONFIRM_DELTA then
                pendingPrint = nil
                pendingPrintFromRecovery = false
                lastKnownPrint = nil
                return true, attempts
            end

            local detectedPrint = detectAssignedPrinterFromGui()
            if detectedPrint == printName then
                sawPrintInGui = true
            elseif sawPrintInGui and os.clock() - started > 1.5 then
                pendingPrint = nil
                pendingPrintFromRecovery = false
                lastKnownPrint = nil
                return true, attempts
            end

            task.wait(0.1)
        until not active or pendingPrint ~= printName or os.clock() >= waitUntil

        if attempts >= PRINTER_MAX_INTERACT_ATTEMPTS then
            pendingPrint = nil
            pendingPrintFromRecovery = false
            return true, attempts
        end
    end

    return pendingPrint ~= printName, attempts
end

local function fireCorrectAnswer(correctAnswerId, sessionId)
    local response = nil
    local received = false
    local connection

    connection = remCorrectAnswer.OnClientEvent:Connect(function(value)
        response = value
        received = true
    end)

    if setthreadidentity then pcall(setthreadidentity, 2) end
    pcall(function()
        remCorrectAnswer:FireServer(correctAnswerId, sessionId)
    end)
    if setthreadidentity then pcall(setthreadidentity, 7) end

    local started = os.clock()
    while active and not received and os.clock() - started < 6 do
        task.wait(0.1)
    end

    pcall(function()
        connection:Disconnect()
    end)

    return response
end

local function onQuestionReceived(question, answers, sessionId)
    questionRequestInFlight = false
    lastQuestionSeenAt = os.clock()
    chairIdleRescueCount = 0
    answeringQuestion = true

    pcall(function()
        if not active then return end
        local solvedValue = solveQuestion(question)
        if not solvedValue then return end

        local correctAnswerId = nil
        if type(answers) == "table" then
            for _, answer in ipairs(answers) do
                if type(answer) == "table" and tonumber(answer.Text) == solvedValue then
                    correctAnswerId = answer.ID
                    break
                end
            end
        end

        if not correctAnswerId then return end

        task.wait(randomDelay(answerDelayMin, answerDelayMax))
        if not active then return end

        local response = fireCorrectAnswer(correctAnswerId, sessionId)

        if response == "success" then
            questionsAnswered = questionsAnswered + 1
            vQuestions.Text = tostring(questionsAnswered)
            setStatus("Answered question")
            lastQuestionSeenAt = os.clock()
            task.delay(0.5, function()
                if active and not pendingPrint and not isDoingPrinterJob then
                    requestQuestion()
                end
            end)
        else
            setStatus("Answer timed out - waiting")
            lastQuestionSeenAt = os.clock()
        end
    end)

    answeringQuestion = false
end

local function hookOfficeRemotes()
    if questionConnection or printConnection then return end

    questionConnection = remGenQuestion.OnClientEvent:Connect(onQuestionReceived)
    printConnection = remAssignPrint.OnClientEvent:Connect(function(printerName)
        if not active then return end
        questionRequestInFlight = false
        pendingPrint = printerName
        pendingPrintFromRecovery = false
        if printerName and PRINTER_POS[printerName] then
            lastKnownPrint = printerName
        end
        chairIdleRescueCount = 0
        setStatus("Print job assigned: " .. tostring(printerName))
    end)

    table.insert(connections, questionConnection)
    table.insert(connections, printConnection)
end

local function joinOfficeTeam()
    if joiningTeam then return true end
    joiningTeam = true

    setStatus("Joining office team...")

    local menuToggleRemote = ReplicatedStorage:WaitForChild("menuToggleRequest", 10)
    if menuToggleRemote then
        safeFireServer(menuToggleRemote)
        task.wait(1)
    end

    local jobEvents = ReplicatedStorage:WaitForChild("JobEvents", 10)
    if not jobEvents then
        joiningTeam = false
        return false, "JobEvents not found"
    end

    local teamChangeRemote = jobEvents:WaitForChild("TeamChangeRequest", 10)
    if not teamChangeRemote then
        joiningTeam = false
        return false, "TeamChangeRequest not found"
    end

    safeFireServer(teamChangeRemote, "Office Worker", 0, 0, 0, "MainMenu")
    task.wait(3)

    joiningTeam = false
    return true
end

local function saveCurrentTotals()
    if sessionStartTime and sessionStartMoney then
        local sessionElapsed = os.time() - sessionStartTime
        local sessionEarned = math.max(0, getMoney() - sessionStartMoney)
        saveStats(totalEarned + sessionEarned, totalTime + sessionElapsed)
    else
        saveStats(totalEarned, totalTime)
    end
end

local function stopFarm()
    if not farmRunning then return end

    active = false
    farmRunning = false
    releaseSprint()
    setSeatBlocking(false)

    if sessionStartTime and sessionStartMoney then
        local sessionElapsed = os.time() - sessionStartTime
        local sessionEarned = math.max(0, getMoney() - sessionStartMoney)
        totalEarned = totalEarned + sessionEarned
        totalTime = totalTime + sessionElapsed
        saveStats(totalEarned, totalTime)
    end

    sessionStartTime = nil
    sessionStartMoney = nil
    startTime = nil
    startMoney = nil
    pendingPrint = nil
    pendingPrintFromRecovery = false
    isDoingPrinterJob = false
    answeringQuestion = false
    questionRequestInFlight = false
    chairIdleRescueCount = 0

    setStatus("Stopped - Ready")
    vEarned.Text = "Rp. 0"
    vMoneyHour.Text = "Calculating..."
    vTotalEarned.Text = "Rp. " .. formatNumber(totalEarned)
    vTotalTime.Text = formatTime(totalTime)
end

local function mainFarmLoop()
    while active do
        local char = getChar()
        local hum = char:WaitForChild("Humanoid")

        setStatus("Finding empty chair...")
        local seat = findAvailableChair()

        if not seat then
            setStatus("No chair found, retrying...")
            task.wait(3)
            continue
        end

        currentSeat = seat
        setStatus("Moving to chair...")
        local seated = seatTP(seat)

        if not seated then
            setStatus("Seat failed, retrying...")
            task.wait(2)
            continue
        end

        setStatus("Seated - answering questions")
        lastQuestionSeenAt = os.clock()
        chairIdleRescueCount = 0
        requestQuestion("Seated - requesting question")

        while active do
            if pendingPrint then
                local pos = PRINTER_POS[pendingPrint]
                if pos then
                    isDoingPrinterJob = true
                    setStatus("Walking to printer...")
                    setSeatBlocking(true)

                    sendKey(Enum.KeyCode.Space)
                    task.wait(0.5)

                    walkTo(pos, {radius = 5, finalTimeout = 5})
                    task.wait(0.5)

                    setStatus("Collecting printer job...")
                    local currentPrint = pendingPrint
                    local completed, attempts = completePrinterJob(currentPrint, pos)

                    if completed then
                        pendingPrintFromRecovery = false
                        printersCompleted = printersCompleted + 1
                        vPrinters.Text = tostring(printersCompleted)
                        setStatus("Printer completed after " .. tostring(attempts) .. " attempt(s)")
                    else
                        if pendingPrintFromRecovery then
                            pendingPrint = nil
                            pendingPrintFromRecovery = false
                            lastKnownPrint = nil
                            setStatus("Printer check failed - returning to chair")
                        else
                            setStatus("Printer not confirmed - retrying")
                            task.wait(0.75)
                            isDoingPrinterJob = false
                            continue
                        end
                    end

                    setStatus("Returning to chair...")
                    local newSeat = currentSeat
                    if not newSeat or not newSeat.Parent or newSeat.Occupant then
                        newSeat = findAvailableChair()
                    end

                    if newSeat then
                        currentSeat = newSeat
                        walkTo(newSeat.Position, {radius = 5, finalTimeout = 5})
                        task.wait(0.5)
                        setSeatBlocking(false)
                        newSeat:Sit(hum)
                        task.wait(0.5)
                        setStatus("Back in chair")
                        lastQuestionSeenAt = os.clock()
                        chairIdleRescueCount = 0
                        requestQuestion("Back in chair - requesting question")
                    else
                        setSeatBlocking(false)
                        setStatus("No return chair found")
                    end

                    isDoingPrinterJob = false
                    setSeatBlocking(false)
                else
                    pendingPrint = nil
                end
            elseif hum.SeatPart == currentSeat and not answeringQuestion and os.clock() - lastQuestionSeenAt >= QUESTION_IDLE_TIMEOUT then
                recoverIdleOfficeFlow()
                lastQuestionSeenAt = os.clock()
            elseif not isDoingPrinterJob and hum.SeatPart ~= currentSeat then
                setStatus("Reseating...")
                if currentSeat and currentSeat.Parent then
                    currentSeat:Sit(hum)
                    task.wait(0.5)

                    if hum.SeatPart ~= currentSeat then
                        local newSeat = findAvailableChair()
                        if newSeat then
                            currentSeat = newSeat
                            seatTP(newSeat)
                        else
                            break
                        end
                    end
                else
                    break
                end
            end

            task.wait(0.2)
        end

        task.wait(1)
    end
end

local function startFarm()
    if farmRunning then return true end

    setStatus("Loading...")

    local joined, joinErr = joinOfficeTeam()
    if not joined then
        setStatus(joinErr or "Could not join office team")
        return false
    end

    local waitStarted = os.clock()
    repeat
        task.wait(0.5)
    until (
        Player.Character
        and Player.Character:FindFirstChild("HumanoidRootPart")
        and Player.Character:FindFirstChild("Humanoid")
    ) or os.clock() - waitStarted > 15

    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") or not Player.Character:FindFirstChild("Humanoid") then
        setStatus("Character not ready")
        return false
    end

    local ok, err = ensureRemotes()
    if not ok then
        setStatus(err or "Remote setup failed")
        return false
    end

    active = true
    farmRunning = true
    questionsAnswered = 0
    printersCompleted = 0
    pendingPrint = nil
    pendingPrintFromRecovery = false
    answeringQuestion = false
    currentSeat = nil
    lastQuestionSeenAt = os.clock()
    lastQuestionRequestAt = 0
    questionRequestInFlight = false
    lastKnownPrint = nil
    chairIdleRescueCount = 0
    sessionStartTime = os.time()
    sessionStartMoney = getMoney()
    startTime = os.time()
    startMoney = sessionStartMoney

    vQuestions.Text = "0"
    vPrinters.Text = "0"
    setStatus("Running")

    hookOfficeRemotes()
    task.spawn(mainFarmLoop)
    return true
end

table.insert(connections, Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end))

task.spawn(startFarm)

task.spawn(function()
    while Gui.Parent do
        task.wait(0.5)

        local money = getMoney()
        local sessionElapsed = sessionStartTime and (os.time() - sessionStartTime) or 0
        local sessionEarned = sessionStartMoney and math.max(0, money - sessionStartMoney) or 0
        local currentEarned = startMoney and math.max(0, money - startMoney) or 0
        local moneyPerHour = sessionElapsed > 60 and math.floor((sessionEarned / sessionElapsed) * 3600) or 0

        vCurrent.Text = "Rp. " .. formatNumber(money)
        vEarned.Text = "Rp. " .. formatNumber(currentEarned)
        vMoneyHour.Text = sessionElapsed > 60 and ("Rp. " .. formatNumber(moneyPerHour) .. " /hr") or "Calculating..."

        vTotalEarned.Text = "Rp. " .. formatNumber(totalEarned + sessionEarned)
        vTotalTime.Text = formatTime(totalTime + sessionElapsed)

        if farmRunning and sessionElapsed > 0 and sessionElapsed % 30 < 1 then
            saveCurrentTotals()
        end
    end
end)

local function cleanup()
    if farmRunning then
        pcall(stopFarm)
    else
        saveCurrentTotals()
    end

    active = false
    farmRunning = false
    releaseSprint()
    setSeatBlocking(false)

    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    if Gui and Gui.Parent then
        Gui:Destroy()
    end
end

if getgenv then
    getgenv().NZNT_OFFICE_STOP = cleanup
end

print("[Office Farm] UI loaded. Auto starting.")
