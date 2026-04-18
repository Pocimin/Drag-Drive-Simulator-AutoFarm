-- ============================================
-- DRAG AUTOFARM - Surakarta Only
-- by _nznt
-- ============================================

-- Anticheat bypass
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
                if c ~= "_" then if d then warn(`Adonis flagged\nMethod: {c}\nInfo: {f}`) end end
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

-- =====================
-- SERVICES
-- =====================
local Player = game:GetService("Players").LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- Wait for character
repeat task.wait(0.5) until Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
task.wait(2)

-- =====================
-- CONFIG
-- =====================
local SURAKARTA_ID = 131378148336503
local RACE_DELAY = 15
local CHECKPOINT_DELAY = 1.5
local LOOP_DELAY = 2
local SAVE_FILE = "nznt_dragfarm.json"
local WEBHOOK_FILE = "nznt_webhook_config.json"
local SCRIPT_URL = "https://raw.githubusercontent.com/Pocimin/Drag-Drive-Simulator-AutoFarm/refs/heads/main/drag_autofarm_surakarta.lua"

-- Webhook config (loaded from loader)
local webhookUrl = ""
local webhookInterval = 60
local webhookEnabled = false
local lastWebhookTime = 0

-- Map check
local currentID = game.PlaceId ~= 0 and game.PlaceId or game.GameId
if currentID ~= SURAKARTA_ID then
    warn("WRONG MAP - Need Surakarta (" .. SURAKARTA_ID .. "), got " .. currentID)
    warn("Teleporting to Surakarta...")
    task.spawn(function()
        for i = 1, 3 do
            local remote = RS:FindFirstChild("CreatePrivateServer", true)
            if remote then remote:FireServer(tostring(SURAKARTA_ID)) task.wait(5) end
        end
    end)
    return
end
warn("--- SURAKARTA DETECTED ---")

-- Script source for rejoin
local scriptSource = ""
pcall(function() scriptSource = game:HttpGet(SCRIPT_URL, true) end)
local function queueReExec() pcall(function() queue_on_teleport(scriptSource) end) end

-- =====================
-- HELPERS
-- =====================
local function getMoney()
    local pd = Player:FindFirstChild("PlayerData")
    if pd then local rp = pd:FindFirstChild("RPValue") if rp then return rp.Value end end
    return 0
end
local function formatNumber(n)
    local s = tostring(math.floor(n))
    return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end
local function formatTime(t)
    return string.format("%02d:%02d:%02d", math.floor(t/3600)%24, math.floor(t/60)%60, t%60)
end
local function getPing()
    local ok, ping = pcall(function() return Player:GetNetworkPing() end)
    return ok and math.floor(ping*1000) or 0
end
local function getExecutorName()
    if identifyexecutor then local ok, n = pcall(identifyexecutor) if ok and n then return n end end
    if getexecutorname then local ok, n = pcall(getexecutorname) if ok and n then return n end end
    return "Unknown"
end
local EXECUTOR_NAME = getExecutorName()

local function findMotorInBackpack()
    local bp = Player:FindFirstChild("Backpack")
    if not bp then return nil end
    for _, tool in pairs(bp:GetChildren()) do
        if tool:IsA("Tool") and tool:FindFirstChildWhichIsA("VehicleSeat", true) then
            return tool.Name
        end
    end
    return nil
end

-- =====================
-- SAVE / LOAD
-- =====================
local function saveData(earned, elapsed)
    pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode({earned=earned, elapsed=elapsed})) end)
end
local function loadData()
    local ok, content = pcall(function() return readfile(SAVE_FILE) end)
    if ok and content then
        local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
        if ok2 and data then return data.earned or 0, data.elapsed or 0 end
    end
    return 0, 0
end
local function clearData()
    pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode({earned=0, elapsed=0})) end)
end

-- =====================
-- WEBHOOK SUPPORT
-- =====================
local function loadWebhookConfig()
    local ok, content = pcall(function() return readfile(WEBHOOK_FILE) end)
    if ok and content then
        local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
        if ok2 and data then
            webhookUrl = data.url or ""
            webhookInterval = data.interval or 60
            webhookEnabled = data.enabled or false
            warn("[Drag Autofarm] Webhook config loaded: " .. (webhookEnabled and "enabled" or "disabled"))
        end
    end
end

local function sendWebhook()
    if not webhookEnabled or webhookUrl == "" or not webhookUrl:find("discord") then return end
    if (os.time() - lastWebhookTime) < webhookInterval then return end
    
    local money = getMoney()
    local earned = (money - (startMoney or money)) + savedEarned
    local sessionElapsed = savedElapsed + (os.time() - sessionStart)
    local mph = sessionElapsed > 60 and math.floor((math.max(0, earned) / sessionElapsed) * 3600) or 0
    
    local body = '{"embeds":[{"title":"Drag Autofarm — Surakarta","color":16776960,"fields":['
        ..'{"name":"💰 Current Money","value":"Rp. ' .. formatNumber(money) .. '","inline":true},'
        ..'{"name":"📈 Session Earned","value":"Rp. ' .. formatNumber(math.max(0, earned)) .. '","inline":true},'
        ..'{"name":"⚡ Money/Hour","value":"Rp. ' .. formatNumber(mph) .. '","inline":true},'
        ..'{"name":"⏱ Session Time","value":"' .. formatTime(sessionElapsed) .. '","inline":true},'
        ..'{"name":"🏁 Races Done","value":"' .. tostring(raceCount) .. '","inline":true},'
        ..'{"name":"📍 Map","value":"Surakarta","inline":true}'
        ..'],"footer":{"text":"by _nznt — Drag Autofarm"}}]}'
    
    local ok = pcall(function()
        request({
            Url = webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = body
        })
    end)
    if ok then
        lastWebhookTime = os.time()
        warn("[Drag Autofarm] Webhook sent!")
    end
end

-- Load webhook config
loadWebhookConfig()

local savedEarned, savedElapsed = loadData()
local startMoney = getMoney()
local sessionStart = os.time()

-- =====================
-- SEAT FINDER (closest like autofarm_yellow)
-- =====================
local function findClosestSeat()
    local best, bestDist = nil, math.huge
    local char = Player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    for _, obj in ipairs(workspace:GetChildren()) do
        local seat = obj:FindFirstChildWhichIsA("VehicleSeat", true)
        if seat then
            local dist = (seat.Position - root.Position).Magnitude
            if dist < bestDist then best, bestDist = seat, dist end
        end
    end
    return best
end

-- =====================
-- DRAG RACE FINDER
-- =====================
local function findDragRace()
    -- Try workspace root
    local dr = workspace:FindFirstChild("DragRace")
    if dr then return dr end
    
    -- Try in folders/models
    for _, obj in pairs(workspace:GetChildren()) do
        if obj:IsA("Folder") or obj:IsA("Model") then
            dr = obj:FindFirstChild("DragRace")
            if dr then return dr end
            dr = obj:FindFirstChild("DragRace", true)
            if dr then return dr end
        end
    end
    
    -- Try common alternative names
    local alts = {"Race", "Drag", "SpeedRace", "SpeedTrap"}
    for _, alt in ipairs(alts) do
        dr = workspace:FindFirstChild(alt)
        if dr then return dr end
    end
    
    return nil
end

local function findDetectors(dragRace)
    if not dragRace then return nil, nil, nil, nil, nil end
    
    local detector = dragRace:FindFirstChild("Detector") or dragRace:FindFirstChild("Detectors")
    if not detector then
        -- Direct children of DragRace
        local start = dragRace:FindFirstChild("Start") or dragRace:FindFirstChild("DetectorStart")
        local c1 = dragRace:FindFirstChild("DetectorC1") or dragRace:FindFirstChild("C1")
        local c2 = dragRace:FindFirstChild("DetectorC2") or dragRace:FindFirstChild("C2")
        local c3 = dragRace:FindFirstChild("DetectorC3") or dragRace:FindFirstChild("C3")
        local finish = dragRace:FindFirstChild("Finish") or dragRace:FindFirstChild("DetectorFinish")
        return start, c1, c2, c3, finish
    end
    
    if detector then
        local start = detector:FindFirstChild("DetectorStart") or detector:FindFirstChild("Start")
        local c1 = detector:FindFirstChild("DetectorC1") or detector:FindFirstChild("C1")
        local c2 = detector:FindFirstChild("DetectorC2") or detector:FindFirstChild("C2")
        local c3 = detector:FindFirstChild("DetectorC3") or detector:FindFirstChild("C3")
        local finish = detector:FindFirstChild("DetectorFinish") or detector:FindFirstChild("Finish")
        return start, c1, c2, c3, finish
    end
    
    return nil, nil, nil, nil, nil
end

-- Helper to touch a detector (start or checkpoint)
local function touchDetector(detector, seatPos)
    if not detector then return end
    pcall(function()
        detector.CFrame = seatPos
    end)
    task.wait(0.1)
    pcall(function()
        detector.CFrame = seatPos * CFrame.new(0, -100, 0)
    end)
end

-- =====================
-- STATE
-- =====================
local raceCount = 0
local active = true
local antiAfkEnabled = true
local lowGraphicsEnabled = true
local lastFPS = 60

-- =====================
-- YELLOW UI (like autofarm_yellow)
-- =====================
local Gui = Instance.new("ScreenGui", Player:WaitForChild("PlayerGui"))
Gui.Name = "nznt_DragUI"; Gui.IgnoreGuiInset = true; Gui.DisplayOrder = 999; Gui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", Gui)
MainFrame.Size = UDim2.new(1,0,1,0); MainFrame.BackgroundColor3 = Color3.fromRGB(10,10,10)
MainFrame.ZIndex = 1; MainFrame.BorderSizePixel = 0

local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1,0,0,44); TopBar.BackgroundColor3 = Color3.fromRGB(18,18,18)
TopBar.BorderSizePixel = 0; TopBar.ZIndex = 2

local TopTitle = Instance.new("TextLabel", TopBar)
TopTitle.Size = UDim2.new(1,-120,1,0); TopTitle.Position = UDim2.new(0,14,0,0)
TopTitle.BackgroundTransparency = 1; TopTitle.Text = "DRAG AUTOFARM  ·  SURAKARTA  ·  nznt_"
TopTitle.TextColor3 = Color3.fromRGB(255,215,0); TopTitle.Font = Enum.Font.GothamBold
TopTitle.TextSize = 13; TopTitle.TextXAlignment = Enum.TextXAlignment.Left; TopTitle.ZIndex = 3

local hideBtn = Instance.new("TextButton", TopBar)
hideBtn.Size = UDim2.new(0,70,0,28); hideBtn.Position = UDim2.new(1,-80,0.5,-14)
hideBtn.BackgroundColor3 = Color3.fromRGB(40,40,40); hideBtn.TextColor3 = Color3.fromRGB(200,200,200)
hideBtn.Font = Enum.Font.GothamBold; hideBtn.TextSize = 12; hideBtn.Text = "HIDE"
hideBtn.ZIndex = 3; hideBtn.BorderSizePixel = 0
Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0,6)

local ScrollFrame = Instance.new("ScrollingFrame", MainFrame)
ScrollFrame.Size = UDim2.new(1,0,1,-44); ScrollFrame.Position = UDim2.new(0,0,0,44)
ScrollFrame.BackgroundTransparency = 1; ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4; ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80,80,80)
ScrollFrame.CanvasSize = UDim2.new(0,0,0,0); ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y; ScrollFrame.ZIndex = 2

hideBtn.MouseButton1Click:Connect(function()
    ScrollFrame.Visible = not ScrollFrame.Visible
    local t = ScrollFrame.Visible and 0 or 1
    MainFrame.BackgroundTransparency = t; TopBar.BackgroundTransparency = t
    TopTitle.TextTransparency = t; hideBtn.Text = ScrollFrame.Visible and "HIDE" or "SHOW"
end)

local ll = Instance.new("UIListLayout", ScrollFrame)
ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Padding = UDim.new(0,1)
Instance.new("UIPadding", ScrollFrame).PaddingBottom = UDim.new(0,10)

local function makeContainer(h, order)
    local f = Instance.new("Frame", ScrollFrame)
    f.Size = UDim2.new(1,0,0,h); f.BackgroundColor3 = Color3.fromRGB(16,16,16)
    f.BorderSizePixel = 0; f.ZIndex = 3; f.LayoutOrder = order
    return f
end

local function makeSection(title, order)
    local sec = makeContainer(28, order)
    sec.BackgroundColor3 = Color3.fromRGB(13,13,13)
    local lbl = Instance.new("TextLabel", sec)
    lbl.Size = UDim2.new(1,-14,1,0); lbl.Position = UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = title:upper()
    lbl.TextColor3 = Color3.fromRGB(255,215,0); lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 4
end

local function makeRow(icon, label, valueDefault, order)
    local row = makeContainer(38, order)
    local iL = Instance.new("TextLabel", row)
    iL.Size = UDim2.new(0,30,1,0); iL.Position = UDim2.new(0,10,0,0)
    iL.BackgroundTransparency = 1; iL.Text = icon; iL.TextColor3 = Color3.fromRGB(255,215,0)
    iL.Font = Enum.Font.GothamBold; iL.TextSize = 16; iL.ZIndex = 4
    local nL = Instance.new("TextLabel", row)
    nL.Size = UDim2.new(0.45,0,1,0); nL.Position = UDim2.new(0,44,0,0)
    nL.BackgroundTransparency = 1; nL.Text = label; nL.TextColor3 = Color3.fromRGB(130,130,130)
    nL.Font = Enum.Font.Gotham; nL.TextSize = 13; nL.TextXAlignment = Enum.TextXAlignment.Left; nL.ZIndex = 4
    local vL = Instance.new("TextLabel", row)
    vL.Size = UDim2.new(0.5,-14,1,0); vL.Position = UDim2.new(0.5,0,0,0)
    vL.BackgroundTransparency = 1; vL.Text = valueDefault; vL.TextColor3 = Color3.fromRGB(230,230,230)
    vL.Font = Enum.Font.GothamBold; vL.TextSize = 13; vL.TextXAlignment = Enum.TextXAlignment.Right; vL.ZIndex = 4
    local sep = Instance.new("Frame", row)
    sep.Size = UDim2.new(1,-14,0,1); sep.Position = UDim2.new(0,7,1,-1)
    sep.BackgroundColor3 = Color3.fromRGB(28,28,28); sep.BorderSizePixel = 0; sep.ZIndex = 4
    return vL
end

makeSection("Money", 10)
local vCurrent   = makeRow("$",  "Current Money", "Rp. 0",          11)
local vEarned    = makeRow("↑",  "Earned",        "Rp. 0",          12)
local vMoneyHour = makeRow("⚡", "Money / Hour",  "Calculating...", 13)

makeSection("Race", 20)
local vStatus  = makeRow("▶", "Status",     "Waiting...", 21)
local vRaces   = makeRow("#", "Races Done", "0",          22)
local vElapsed = makeRow("⏱", "Elapsed",   "00:00:00",   23)

makeSection("Device", 30)
local vPing = makeRow("◉", "Ping",     "0 ms",        31)
local vFPS  = makeRow("◈", "FPS",      "0",           32)
local vExec = makeRow("⌘", "Executor", EXECUTOR_NAME, 33)

makeSection("Settings", 40)

-- Delay slider
local delayRow = makeContainer(70, 41)
local iL = Instance.new("TextLabel", delayRow)
iL.Size = UDim2.new(0,30,0,28); iL.Position = UDim2.new(0,10,0,5)
iL.BackgroundTransparency = 1; iL.Text = "⏲"; iL.TextColor3 = Color3.fromRGB(255,215,0)
iL.Font = Enum.Font.GothamBold; iL.TextSize = 16; iL.ZIndex = 4
local nL = Instance.new("TextLabel", delayRow)
nL.Size = UDim2.new(0.4,0,0,28); nL.Position = UDim2.new(0,44,0,5)
nL.BackgroundTransparency = 1; nL.Text = "Race Delay"; nL.TextColor3 = Color3.fromRGB(130,130,130)
nL.Font = Enum.Font.Gotham; nL.TextSize = 13; nL.TextXAlignment = Enum.TextXAlignment.Left; nL.ZIndex = 4
local vBox = Instance.new("TextBox", delayRow)
vBox.Size = UDim2.new(0,50,0,28); vBox.Position = UDim2.new(1,-60,0,5)
vBox.BackgroundColor3 = Color3.fromRGB(28,28,28); vBox.Text = tostring(RACE_DELAY)
vBox.TextColor3 = Color3.fromRGB(230,230,230); vBox.Font = Enum.Font.GothamBold; vBox.TextSize = 13
vBox.TextXAlignment = Enum.TextXAlignment.Center; vBox.ZIndex = 10; vBox.BorderSizePixel = 0
Instance.new("UICorner",vBox).CornerRadius = UDim.new(0,4)
local track = Instance.new("Frame", delayRow)
track.Size = UDim2.new(1,-60,0,6); track.Position = UDim2.new(0,44,0,45)
track.BackgroundColor3 = Color3.fromRGB(40,40,40); track.BorderSizePixel = 0; track.ZIndex = 4
Instance.new("UICorner",track).CornerRadius = UDim.new(0,3)
local fill = Instance.new("Frame", track)
fill.BackgroundColor3 = Color3.fromRGB(255,215,0); fill.BorderSizePixel = 0; fill.ZIndex = 5
Instance.new("UICorner",fill).CornerRadius = UDim.new(0,3)
local knob = Instance.new("Frame", track)
knob.Size = UDim2.new(0,18,0,18); knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
knob.BorderSizePixel = 0; knob.ZIndex = 6
Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)

local MIN_DELAY, MAX_DELAY = 3.0, 10.0
local function refreshDelay(v)
    local r = (v-MIN_DELAY)/(MAX_DELAY-MIN_DELAY)
    fill.Size = UDim2.new(r,0,1,0); knob.Position = UDim2.new(r,-9,0.5,-9); vBox.Text = string.format("%.1f", v)
end
refreshDelay(RACE_DELAY)
vBox.FocusLost:Connect(function()
    local val = tonumber(vBox.Text:gsub("[^%d%.%-]",""))
    if val then val = math.clamp(val,MIN_DELAY,MAX_DELAY); RACE_DELAY = val; refreshDelay(val) end
end)
local dragging = false

-- Click on track to set value
track.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        local r = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        RACE_DELAY = math.floor((MIN_DELAY + r * (MAX_DELAY - MIN_DELAY)) * 10) / 10
        refreshDelay(RACE_DELAY)
    end
end)

-- Drag knob
knob.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true
    end
end)

UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local r = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        RACE_DELAY = math.floor((MIN_DELAY + r * (MAX_DELAY - MIN_DELAY)) * 10) / 10
        refreshDelay(RACE_DELAY)
    end
end)

-- Checkpoint Delay slider
local cpRow = makeContainer(70, 42)
local cpIcon = Instance.new("TextLabel", cpRow)
cpIcon.Size = UDim2.new(0,30,0,28); cpIcon.Position = UDim2.new(0,10,0,5)
cpIcon.BackgroundTransparency = 1; cpIcon.Text = "⌚"; cpIcon.TextColor3 = Color3.fromRGB(255,215,0)
cpIcon.Font = Enum.Font.GothamBold; cpIcon.TextSize = 16; cpIcon.ZIndex = 4
local cpName = Instance.new("TextLabel", cpRow)
cpName.Size = UDim2.new(0.4,0,0,28); cpName.Position = UDim2.new(0,44,0,5)
cpName.BackgroundTransparency = 1; cpName.Text = "Checkpoint Delay"; cpName.TextColor3 = Color3.fromRGB(130,130,130)
cpName.Font = Enum.Font.Gotham; cpName.TextSize = 13; cpName.TextXAlignment = Enum.TextXAlignment.Left; cpName.ZIndex = 4
local cpBox = Instance.new("TextBox", cpRow)
cpBox.Size = UDim2.new(0,50,0,28); cpBox.Position = UDim2.new(1,-60,0,5)
cpBox.BackgroundColor3 = Color3.fromRGB(28,28,28); cpBox.Text = tostring(CHECKPOINT_DELAY)
cpBox.TextColor3 = Color3.fromRGB(230,230,230); cpBox.Font = Enum.Font.GothamBold; cpBox.TextSize = 13
cpBox.TextXAlignment = Enum.TextXAlignment.Center; cpBox.ZIndex = 10; cpBox.BorderSizePixel = 0
Instance.new("UICorner",cpBox).CornerRadius = UDim.new(0,4)
local cpTrack = Instance.new("Frame", cpRow)
cpTrack.Size = UDim2.new(1,-60,0,6); cpTrack.Position = UDim2.new(0,44,0,45)
cpTrack.BackgroundColor3 = Color3.fromRGB(40,40,40); cpTrack.BorderSizePixel = 0; cpTrack.ZIndex = 4
Instance.new("UICorner",cpTrack).CornerRadius = UDim.new(0,3)
local cpFill = Instance.new("Frame", cpTrack)
cpFill.BackgroundColor3 = Color3.fromRGB(255,215,0); cpFill.BorderSizePixel = 0; cpFill.ZIndex = 5
Instance.new("UICorner",cpFill).CornerRadius = UDim.new(0,3)
local cpKnob = Instance.new("Frame", cpTrack)
cpKnob.Size = UDim2.new(0,18,0,18); cpKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
cpKnob.BorderSizePixel = 0; cpKnob.ZIndex = 6
Instance.new("UICorner",cpKnob).CornerRadius = UDim.new(1,0)

local MIN_CP, MAX_CP = 0.5, 5.0
local function refreshCp(v)
    local r = (v-MIN_CP)/(MAX_CP-MIN_CP)
    cpFill.Size = UDim2.new(r,0,1,0); cpKnob.Position = UDim2.new(r,-9,0.5,-9); cpBox.Text = string.format("%.1f", v)
end
refreshCp(CHECKPOINT_DELAY)
cpBox.FocusLost:Connect(function()
    local val = tonumber(cpBox.Text:gsub("[^%d%.%-]",""))
    if val then val = math.clamp(val,MIN_CP,MAX_CP); CHECKPOINT_DELAY = val; refreshCp(val) end
end)
local cpDragging = false
cpTrack.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        local r = math.clamp((i.Position.X - cpTrack.AbsolutePosition.X) / cpTrack.AbsoluteSize.X, 0, 1)
        CHECKPOINT_DELAY = math.floor((MIN_CP + r * (MAX_CP - MIN_CP)) * 10) / 10
        refreshCp(CHECKPOINT_DELAY)
    end
end)
cpKnob.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        cpDragging = true
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        cpDragging = false
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if cpDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local r = math.clamp((i.Position.X - cpTrack.AbsolutePosition.X) / cpTrack.AbsoluteSize.X, 0, 1)
        CHECKPOINT_DELAY = math.floor((MIN_CP + r * (MAX_CP - MIN_CP)) * 10) / 10
        refreshCp(CHECKPOINT_DELAY)
    end
end)

-- Loop Delay slider (delay between races)
local loopRow = makeContainer(70, 43)
local loopIcon = Instance.new("TextLabel", loopRow)
loopIcon.Size = UDim2.new(0,30,0,28); loopIcon.Position = UDim2.new(0,10,0,5)
loopIcon.BackgroundTransparency = 1; loopIcon.Text = "⏸️"; loopIcon.TextColor3 = Color3.fromRGB(255,215,0)
loopIcon.Font = Enum.Font.GothamBold; loopIcon.TextSize = 16; loopIcon.ZIndex = 4
local loopName = Instance.new("TextLabel", loopRow)
loopName.Size = UDim2.new(0.4,0,0,28); loopName.Position = UDim2.new(0,44,0,5)
loopName.BackgroundTransparency = 1; loopName.Text = "Loop Delay"; loopName.TextColor3 = Color3.fromRGB(130,130,130)
loopName.Font = Enum.Font.Gotham; loopName.TextSize = 13; loopName.TextXAlignment = Enum.TextXAlignment.Left; loopName.ZIndex = 4
local loopBox = Instance.new("TextBox", loopRow)
loopBox.Size = UDim2.new(0,50,0,28); loopBox.Position = UDim2.new(1,-60,0,5)
loopBox.BackgroundColor3 = Color3.fromRGB(28,28,28); loopBox.Text = tostring(LOOP_DELAY)
loopBox.TextColor3 = Color3.fromRGB(230,230,230); loopBox.Font = Enum.Font.GothamBold; loopBox.TextSize = 13
loopBox.TextXAlignment = Enum.TextXAlignment.Center; loopBox.ZIndex = 10; loopBox.BorderSizePixel = 0
Instance.new("UICorner",loopBox).CornerRadius = UDim.new(0,4)
local loopTrack = Instance.new("Frame", loopRow)
loopTrack.Size = UDim2.new(1,-60,0,6); loopTrack.Position = UDim2.new(0,44,0,45)
loopTrack.BackgroundColor3 = Color3.fromRGB(40,40,40); loopTrack.BorderSizePixel = 0; loopTrack.ZIndex = 4
Instance.new("UICorner",loopTrack).CornerRadius = UDim.new(0,3)
local loopFill = Instance.new("Frame", loopTrack)
loopFill.BackgroundColor3 = Color3.fromRGB(255,215,0); loopFill.BorderSizePixel = 0; loopFill.ZIndex = 5
Instance.new("UICorner",loopFill).CornerRadius = UDim.new(0,3)
local loopKnob = Instance.new("Frame", loopTrack)
loopKnob.Size = UDim2.new(0,18,0,18); loopKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
loopKnob.BorderSizePixel = 0; loopKnob.ZIndex = 6
Instance.new("UICorner",loopKnob).CornerRadius = UDim.new(1,0)

local MIN_LOOP, MAX_LOOP = 0, 10
local function refreshLoop(v)
    local r = (v-MIN_LOOP)/(MAX_LOOP-MIN_LOOP)
    loopFill.Size = UDim2.new(r,0,1,0); loopKnob.Position = UDim2.new(r,-9,0.5,-9); loopBox.Text = string.format("%.1f", v)
end
refreshLoop(LOOP_DELAY)
loopBox.FocusLost:Connect(function()
    local val = tonumber(loopBox.Text:gsub("[^%d%.%-]",""))
    if val then val = math.clamp(val,MIN_LOOP,MAX_LOOP); LOOP_DELAY = val; refreshLoop(val) end
end)
local loopDragging = false
loopTrack.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        local r = math.clamp((i.Position.X - loopTrack.AbsolutePosition.X) / loopTrack.AbsoluteSize.X, 0, 1)
        LOOP_DELAY = math.floor((MIN_LOOP + r * (MAX_LOOP - MIN_LOOP)) * 10) / 10
        refreshLoop(LOOP_DELAY)
    end
end)
loopKnob.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        loopDragging = true
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        loopDragging = false
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if loopDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local r = math.clamp((i.Position.X - loopTrack.AbsolutePosition.X) / loopTrack.AbsoluteSize.X, 0, 1)
        LOOP_DELAY = math.floor((MIN_LOOP + r * (MAX_LOOP - MIN_LOOP)) * 10) / 10
        refreshLoop(LOOP_DELAY)
    end
end)

-- Toggle maker
local function makeToggle(icon, label, default, order, onToggle)
    local row = makeContainer(38, order)
    local iL = Instance.new("TextLabel", row)
    iL.Size = UDim2.new(0,30,1,0); iL.Position = UDim2.new(0,10,0,0)
    iL.BackgroundTransparency = 1; iL.Text = icon; iL.TextColor3 = Color3.fromRGB(255,215,0)
    iL.Font = Enum.Font.GothamBold; iL.TextSize = 16; iL.ZIndex = 4
    local nL = Instance.new("TextLabel", row)
    nL.Size = UDim2.new(0.6,0,1,0); nL.Position = UDim2.new(0,44,0,0)
    nL.BackgroundTransparency = 1; nL.Text = label; nL.TextColor3 = Color3.fromRGB(130,130,130)
    nL.Font = Enum.Font.Gotham; nL.TextSize = 13; nL.TextXAlignment = Enum.TextXAlignment.Left; nL.ZIndex = 4
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0,56,0,26); btn.Position = UDim2.new(1,-66,0.5,-13)
    btn.BorderSizePixel = 0; btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; btn.ZIndex = 4
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1,0)
    local sep = Instance.new("Frame", row)
    sep.Size = UDim2.new(1,-14,0,1); sep.Position = UDim2.new(0,7,1,-1)
    sep.BackgroundColor3 = Color3.fromRGB(28,28,28); sep.BorderSizePixel = 0; sep.ZIndex = 4
    local on = default
    local function refresh()
        btn.Text = on and "ON" or "OFF"
        btn.BackgroundColor3 = on and Color3.fromRGB(255,215,0) or Color3.fromRGB(150,35,35)
        btn.TextColor3 = on and Color3.fromRGB(0,0,0) or Color3.fromRGB(255,255,255)
    end
    btn.MouseButton1Click:Connect(function() on = not on; refresh(); onToggle(on) end)
    refresh()
end

makeToggle("◎", "Anti-AFK", true, 42, function(v) antiAfkEnabled = v end)
makeToggle("◑", "Low Graphics", true, 43, function(v)
    lowGraphicsEnabled = v; settings().Rendering.QualityLevel = v and 1 or 10
end)

-- Reset button
local resetRow = makeContainer(38, 44)
local resetBtn = Instance.new("TextButton", resetRow)
resetBtn.Size = UDim2.new(1,-20,0,26); resetBtn.Position = UDim2.new(0,10,0.5,-13)
resetBtn.BackgroundColor3 = Color3.fromRGB(150,35,35); resetBtn.TextColor3 = Color3.fromRGB(255,255,255)
resetBtn.Font = Enum.Font.GothamBold; resetBtn.TextSize = 12; resetBtn.Text = "⟳  Reset Stats"
resetBtn.BorderSizePixel = 0; resetBtn.ZIndex = 4
Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0,5)
resetBtn.MouseButton1Click:Connect(function()
    clearData(); savedEarned = 0; savedElapsed = 0; sessionStart = os.time(); startMoney = getMoney()
    resetBtn.Text = "✓  Reset!"; task.wait(1.5); resetBtn.Text = "⟳  Reset Stats"
end)

makeSection("About", 50)
local aboutRow = makeContainer(60, 51)
local aL = Instance.new("TextLabel", aboutRow)
aL.Size = UDim2.new(1,-20,1,0); aL.Position = UDim2.new(0,10,0,0)
aL.BackgroundTransparency = 1; aL.Text = "Script by _nznt\nDrag Autofarm for Surakarta\nDiscord: discord.gg/q6dUF4CsKH"
aL.TextColor3 = Color3.fromRGB(150,150,150); aL.Font = Enum.Font.Gotham; aL.TextSize = 12
aL.TextXAlignment = Enum.TextXAlignment.Left; aL.TextYAlignment = Enum.TextYAlignment.Center; aL.ZIndex = 4
aL.TextWrapped = true

-- =====================
-- BACKGROUND SYSTEMS
-- =====================
RunService.Heartbeat:Connect(function(dt) if dt > 0 then lastFPS = math.floor(1/dt) end end)

local VirtualUser = game:GetService("VirtualUser")
Player.Idled:Connect(function()
    if not antiAfkEnabled then return end
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

task.spawn(function()
    while true do
        if lowGraphicsEnabled then settings().Rendering.QualityLevel = 1 end
        task.wait(5)
    end
end)

local Lighting = game:GetService("Lighting")
Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9
for _, v in pairs(Lighting:GetChildren()) do
    if v:IsA("PostEffect") or v:IsA("Atmosphere") or v:IsA("Sky") then pcall(function() v:Destroy() end) end
end

-- =====================
-- MAIN FARM LOOP
-- =====================
startMoney = getMoney()

task.spawn(function()
    local char = Player.Character or Player.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid")

    local motorName = findMotorInBackpack() or "Yamahax-MioSporty"
    vStatus.Text = "Found motor: " .. motorName
    
    local spawnFolder = RS:FindFirstChild("SpawnCarEvents")
    if spawnFolder then
        local remote = spawnFolder:FindFirstChild("SpawnCar")
        if remote then remote:FireServer(motorName) end
    end
    task.wait(5)

    vStatus.Text = "Finding bike..."
    local seat = nil
    local timeout = 0
    repeat
        task.wait(0.5); timeout = timeout + 0.5
        seat = findClosestSeat()
    until seat ~= nil or timeout >= 15

    if not seat then vStatus.Text = "No motor found!"; return end
    
    -- Get fresh character reference
    char = Player.Character or Player.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
    
    -- Teleport to seat first (like autofarm_yellow)
    vStatus.Text = "Teleporting to seat..."
    root.CFrame = seat.CFrame * CFrame.new(0, 3, 0)
    task.wait(0.5)
    
    vStatus.Text = "Sitting on bike..."
    seat:Sit(hum)
    task.wait(1)
    
    -- Verify we sat
    if hum.SeatPart ~= seat then
        vStatus.Text = "Failed to sit, retrying..."
        -- Try again
        root.CFrame = seat.CFrame * CFrame.new(0, 3, 0)
        task.wait(0.5)
        seat:Sit(hum)
        task.wait(1)
    end
    
    if hum.SeatPart ~= seat then
        vStatus.Text = "Could not sit on bike!"
        return
    end

    startMoney = getMoney()
    vStatus.Text = "Farming..."

    while active do
        -- Send webhook if enabled and interval passed
        sendWebhook()
        
        local seatPos = seat.CFrame
        local dragRace = findDragRace()
        
        if not dragRace then
            vStatus.Text = "DragRace not found - scanning..."
            task.wait(2)
        else
            local startDet, c1, c2, c3, finishDet = findDetectors(dragRace)
            
            if not startDet or not finishDet then
                vStatus.Text = "Detectors not found..."
                task.wait(2)
            else
                -- Hit start
                vStatus.Text = "Crossing start..."
                touchDetector(startDet, seatPos)
                task.wait(CHECKPOINT_DELAY)
                
                -- Hit C1 if exists
                if c1 then
                    vStatus.Text = "Checkpoint 1..."
                    touchDetector(c1, seatPos)
                    task.wait(CHECKPOINT_DELAY)
                end
                
                -- Hit C2 if exists
                if c2 then
                    vStatus.Text = "Checkpoint 2..."
                    touchDetector(c2, seatPos)
                    task.wait(CHECKPOINT_DELAY)
                end
                
                -- Hit C3 if exists
                if c3 then
                    vStatus.Text = "Checkpoint 3..."
                    touchDetector(c3, seatPos)
                    task.wait(CHECKPOINT_DELAY)
                end
                
                -- Wait for race delay
                vStatus.Text = string.format("Racing... (%.1fs)", RACE_DELAY)
                task.wait(RACE_DELAY)
                
                -- Hit finish
                vStatus.Text = "Crossing finish..."
                touchDetector(finishDet, seatPos)
                
                raceCount = raceCount + 1
                
                -- Delay before next race
                if LOOP_DELAY > 0 then
                    vStatus.Text = string.format("Waiting %.1fs before next race...", LOOP_DELAY)
                    task.wait(LOOP_DELAY)
                end
                
                if raceCount % 100 == 0 then
                    saveData((getMoney() - startMoney) + savedEarned, savedElapsed + (os.time() - sessionStart))
                    vStatus.Text = "100 races! Rejoining..."
                    task.wait(2); queueReExec(); task.wait(0.5)
                    pcall(function() TS:Teleport(SURAKARTA_ID, Player) end)
                end
            end
        end
    end
end)

-- =====================
-- STATS LOOP
-- =====================
task.spawn(function()
    while task.wait(0.5) do
        local money = getMoney()
        local earned = (money - (startMoney or money)) + savedEarned
        local totalElapsed = savedElapsed + (os.time() - sessionStart)
        local mph = totalElapsed > 60 and math.floor((math.max(0, earned) / totalElapsed) * 3600) or 0
        
        vCurrent.Text = "Rp. " .. formatNumber(money)
        vEarned.Text = "Rp. " .. formatNumber(math.max(0, earned))
        vMoneyHour.Text = totalElapsed > 60 and ("Rp. " .. formatNumber(mph) .. " /hr") or "Calculating..."
        vRaces.Text = tostring(raceCount)
        vElapsed.Text = formatTime(totalElapsed)
        vPing.Text = getPing() .. " ms"
        vFPS.Text = tostring(lastFPS)
    end
end)

warn("[Drag Autofarm] Loaded on Surakarta")
