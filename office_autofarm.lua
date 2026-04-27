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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local STATS_FILE = "nznt_office_stats.txt"
local CONFIG_FILE = "nznt_office_config.txt"

local MIN_DELAY = 1.0
local MAX_DELAY = 10.0

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
local isDoingPrinterJob = false

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

local function releaseSprint()
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
    end)
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
    VirtualUser:CaptureController()
    VirtualUser:SetKeyDown("0x65")
    task.wait(1.8)
    VirtualUser:SetKeyUp("0x65")
    return true
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

local function walkTo(targetPos)
    local char = getChar()
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end

    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
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
        task.wait(2)
        releaseSprint()
        return false
    end

    for _, waypoint in ipairs(path:GetWaypoints()) do
        if not active or not isDoingPrinterJob then break end

        if waypoint.Action == Enum.PathWaypointAction.Jump then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end

        hum:MoveTo(waypoint.Position)

        local timeout = 0
        while active and isDoingPrinterJob and (root.Position - waypoint.Position).Magnitude > 4 and timeout < 50 do
            task.wait(0.1)
            timeout = timeout + 1
        end
    end

    releaseSprint()
    return true
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

makeSection("Office Stats", 30)
local vStatus = makeRow("▶", "Status", "Auto starting...", 31)
local vQuestions = makeRow("🧠", "Questions Answered", "0", 32)
local vPrinters = makeRow("🖨", "Printers Completed", "0", 33)

local function setStatus(text)
    vStatus.Text = text
    print("[Office Farm] " .. text)
end

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

local function normalizeAnswerText(text)
    return tostring(text or ""):lower():gsub("%s+", ""):gsub(",", "")
end

local function getGuiText(obj)
    if obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("TextBox") then
        return obj.Text or ""
    end

    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("TextBox") then
            local text = child.Text
            if text and text ~= "" then
                return text
            end
        end
    end

    return ""
end

local function isVisibleGuiObject(obj)
    if obj:IsDescendantOf(Gui) then return false end
    if not obj:IsA("GuiObject") then return false end
    if obj.AbsoluteSize.X <= 0 or obj.AbsoluteSize.Y <= 0 then return false end

    local current = obj
    while current do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        if (current:IsA("ScreenGui") or current:IsA("SurfaceGui") or current:IsA("BillboardGui")) and not current.Enabled then
            return false
        end
        current = current.Parent
    end

    return true
end

local function answerTextMatches(buttonText, answerText, solvedValue)
    local normalizedButton = normalizeAnswerText(buttonText)
    local normalizedAnswer = normalizeAnswerText(answerText)
    local normalizedSolved = normalizeAnswerText(solvedValue)

    if normalizedButton == "" then return false end
    if normalizedAnswer ~= "" and normalizedButton == normalizedAnswer then return true end
    if normalizedSolved ~= "" and normalizedButton == normalizedSolved then return true end

    local numericButton = tonumber(buttonText:match("%-?%d+"))
    local numericSolved = tonumber(solvedValue)
    return numericButton ~= nil and numericSolved ~= nil and numericButton == numericSolved
end

local function getAnswerButtonRoots()
    local roots = {PlayerGui}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("SurfaceGui") or obj:IsA("BillboardGui") then
            table.insert(roots, obj)
        end
    end

    return roots
end

local function findAnswerButton(answerText, solvedValue)
    for _, root in ipairs(getAnswerButtonRoots()) do
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                if isVisibleGuiObject(obj) and answerTextMatches(getGuiText(obj), answerText, solvedValue) then
                    return obj
                end
            end
        end
    end

    return nil
end

local function clickGuiButton(button)
    if not button or not isVisibleGuiObject(button) then return false end

    local center = button.AbsolutePosition + (button.AbsoluteSize / 2)
    pcall(function()
        VirtualInputManager:SendMouseMoveEvent(center.X, center.Y, game)
    end)
    task.wait(0.05)

    local clicked = pcall(function()
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
        task.wait(0.08)
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
    end)

    return clicked
end

local function fireGuiButtonSignals(button)
    if not button then return false end

    local fired = false
    local center = button.AbsolutePosition + (button.AbsoluteSize / 2)

    local function tryFireSignal(signal, ...)
        local args = {...}
        if firesignal then
            local ok = pcall(function()
                firesignal(signal, unpack(args))
            end)
            fired = fired or ok
        end

        if getconnections then
            local ok, signalConnections = pcall(getconnections, signal)
            if ok and type(signalConnections) == "table" then
                for _, connection in ipairs(signalConnections) do
                    local fireOk = pcall(function()
                        connection:Fire(unpack(args))
                    end)
                    fired = fired or fireOk
                end
            end
        end
    end

    pcall(function()
        button.Active = true
        button.Selectable = true
    end)

    if button:IsA("GuiButton") then
        tryFireSignal(button.MouseButton1Down, center.X, center.Y)
        task.wait(0.05)
        tryFireSignal(button.MouseButton1Click)
        task.wait(0.05)
        tryFireSignal(button.Activated)
        task.wait(0.05)
        tryFireSignal(button.MouseButton1Up, center.X, center.Y)
    end

    return fired
end

local function clickAnswerButtonAndWait(button, timeout)
    local response = nil
    local done = false
    local conn

    conn = remCorrectAnswer.OnClientEvent:Connect(function(result)
        response = result
        done = true
    end)

    local clicked = clickGuiButton(button)

    local started = os.clock()
    while active and not done and os.clock() - started < math.min(timeout, 1) do
        task.wait(0.05)
    end

    local signalFired = false
    if active and not done then
        signalFired = fireGuiButtonSignals(button)
    end

    while active and not done and os.clock() - started < timeout do
        task.wait(0.05)
    end

    if conn then conn:Disconnect() end
    return response, clicked or signalFired
end

local function onQuestionReceived(question, answers, sessionId)
    pcall(function()
        if not active then return end
        local solvedValue = solveQuestion(question)
        if not solvedValue then return end

        local correctAnswerText = tostring(solvedValue)
        local foundAnswer = false
        if type(answers) == "table" then
            for _, answer in ipairs(answers) do
                if type(answer) == "table" and tonumber(answer.Text) == solvedValue then
                    correctAnswerText = tostring(answer.Text)
                    foundAnswer = true
                    break
                end
            end
        end

        if not foundAnswer then return end

        task.wait(randomDelay(answerDelayMin, answerDelayMax))
        if not active then return end

        local answerButton = findAnswerButton(correctAnswerText, solvedValue)
        if not answerButton then
            setStatus("Answer button not found: " .. tostring(correctAnswerText))
            warn("[Office Farm] Could not find answer button for " .. tostring(correctAnswerText))
            return
        end

        local response, clicked = clickAnswerButtonAndWait(answerButton, 5)

        if response == "success" then
            questionsAnswered = questionsAnswered + 1
            vQuestions.Text = tostring(questionsAnswered)
            setStatus("Answered question")
        elseif clicked then
            setStatus("Answer click failed")
            warn("[Office Farm] Clicked/fired answer button but no success response. Button: " .. answerButton:GetFullName())
        end
    end)
end

local function hookOfficeRemotes()
    if questionConnection or printConnection then return end

    questionConnection = remGenQuestion.OnClientEvent:Connect(onQuestionReceived)
    printConnection = remAssignPrint.OnClientEvent:Connect(function(printerName)
        if not active then return end
        pendingPrint = printerName
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
    isDoingPrinterJob = false

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

        while active do
            if pendingPrint then
                local pos = PRINTER_POS[pendingPrint]
                if pos then
                    isDoingPrinterJob = true
                    setStatus("Walking to printer...")
                    setSeatBlocking(true)

                    sendKey(Enum.KeyCode.Space)
                    task.wait(0.5)

                    walkTo(pos)
                    task.wait(0.5)

                    setStatus("Collecting printer job...")
                    local currentPrint = pendingPrint
                    local attempts = 0

                    while active and pendingPrint == currentPrint and attempts < 1 do
                        interactWithPrinter()
                        task.wait(1)
                        attempts = attempts + 1
                    end

                    if pendingPrint ~= currentPrint then
                        printersCompleted = printersCompleted + 1
                        vPrinters.Text = tostring(printersCompleted)
                        setStatus("Printer completed")
                    end
                    pendingPrint = nil

                    setStatus("Returning to chair...")
                    local newSeat = findAvailableChair()
                    if newSeat then
                        currentSeat = newSeat
                        walkTo(newSeat.Position)
                        task.wait(0.5)
                        setSeatBlocking(false)
                        newSeat:Sit(hum)
                        task.wait(0.5)
                        setStatus("Back in chair")
                    else
                        setSeatBlocking(false)
                        setStatus("No return chair found")
                    end

                    isDoingPrinterJob = false
                    setSeatBlocking(false)
                else
                    pendingPrint = nil
                end
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
    currentSeat = nil
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
