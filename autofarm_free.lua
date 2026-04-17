-- ============================================
-- STEALTH FARM FREE
-- Creator: _nznt
-- Discord: discord.gg/q6dUF4CsKH
-- ============================================
-- FREE FEATURES:
-- - MioSporty vehicle only
-- - Auto-Respawn
-- - Void Protection
-- - Baseplate Protection
-- - Anti-AFK System
-- - Total Statistics
-- - Auto-Detection
-- ============================================

-- Lightweight Adonis bypass
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

if not game:IsLoaded() then game.Loaded:Wait() end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local RS               = game:GetService("ReplicatedStorage")
local VIM              = game:GetService("VirtualInputManager")
local Player           = Players.LocalPlayer

local SPEED             = 290
local MIN_SPEED         = 0
local MAX_SPEED         = 400
local CHECK_DISTANCE    = 15
local HUGE_PLATFORM_SIZE= 2000
local FARM_THRESHOLD    = 500000
local DEFAULT_THRESHOLD = 500000
local MIN_THRESHOLD     = 100000
local MAX_THRESHOLD     = 2500000

local active          = false
local currentVehicle  = nil
local force           = nil
local gyro            = nil
local attachment      = nil
local direction       = 1
local savedFloor      = nil
local startTime       = nil
local startMoney      = nil
local seatOffset      = 1.5  -- Dynamic seat-to-wheel offset
local lastDirChange   = 0
local DIR_COOLDOWN    = 0.3
local isRespawning    = false
local isRestarting    = false
local totalEarned     = 0
local totalTime       = 0

local function getExecutorName()
    if identifyexecutor then local ok, n = pcall(identifyexecutor) if ok and n then return n end end
    if getexecutorname  then local ok, n = pcall(getexecutorname)  if ok and n then return n end end
    return "Unknown"
end
local EXECUTOR_NAME = getExecutorName()

local lastFPS = 60
RunService.Heartbeat:Connect(function(dt)
    if dt > 0 then lastFPS = math.floor(1/dt) end
end)

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
local function sendKey(key)
    VIM:SendKeyEvent(true, key, false, game)
    task.wait(0.1)
    VIM:SendKeyEvent(false, key, false, game)
end
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
local function calculateSeatOffset(vehicle, seat)
    local lowestWheelY = math.huge
    for _, part in ipairs(vehicle:GetDescendants()) do
        if part:IsA("BasePart") then
            local name = part.Name:lower()
            if name:find("wheel") or name:find("tire") then
                local wheelBottom = part.Position.Y - (part.Size.Y / 2)
                if wheelBottom < lowestWheelY then
                    lowestWheelY = wheelBottom
                end
            end
        end
    end
    if lowestWheelY ~= math.huge then
        return seat.Position.Y - lowestWheelY
    end
    return 1.5
end
local function setupPhysics(seat)
    attachment = Instance.new("Attachment", seat)
    force = Instance.new("LinearVelocity", seat)
    force.MaxForce = 99999999
    force.Attachment0 = attachment
    force.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
    gyro = Instance.new("BodyGyro", seat)
    gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    gyro.P = 100000
    gyro.D = 1000
    gyro.CFrame = seat.CFrame
end
local function cleanupPhysics()
    if force then force:Destroy() force = nil end
    if gyro then gyro:Destroy() gyro = nil end
    if attachment then attachment:Destroy() attachment = nil end
end

-- FREE: Only MioSporty spawn
local function spawnMio()
    local sf = RS:FindFirstChild("SpawnCarEvents")
    if sf then
        local r = sf:FindFirstChild("SpawnCar")
        if r then r:FireServer("Yamahax-MioSporty") return true end
    end
    return false
end
local function despawnMio()
    local sf = RS:FindFirstChild("SpawnCarEvents")
    if sf then
        local r = sf:FindFirstChild("DespawnCar")
        if r then r:FireServer() end
    end
end

-- =====================
-- UI
-- =====================
local ScreenGui = Instance.new("ScreenGui", Player:WaitForChild("PlayerGui"))
ScreenGui.Name = "nznt_StealthUI_Free"
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(1, 0, 1, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
MainFrame.Visible = true
MainFrame.ZIndex = 1
MainFrame.BorderSizePixel = 0

local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 44)
TopBar.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 2

local TopTitle = Instance.new("TextLabel", TopBar)
TopTitle.Size = UDim2.new(1, -120, 1, 0)
TopTitle.Position = UDim2.new(0, 14, 0, 0)
TopTitle.BackgroundTransparency = 1
TopTitle.Text = "STEALTH FARM FREE  ·  nznt_"
TopTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
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

hideBtn.MouseButton1Click:Connect(function()
    ScrollFrame.Visible = not ScrollFrame.Visible
    local t = ScrollFrame.Visible and 0 or 1
    MainFrame.BackgroundTransparency = t
    TopBar.BackgroundTransparency = t
    TopTitle.TextTransparency = t
    hideBtn.Text = ScrollFrame.Visible and "HIDE" or "SHOW"
end)

local ListLayout = Instance.new("UIListLayout", ScrollFrame)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 1)
Instance.new("UIPadding", ScrollFrame).PaddingBottom = UDim.new(0, 10)

local function makeSection(title, order)
    local sec = Instance.new("Frame", ScrollFrame)
    sec.Size = UDim2.new(1, 0, 0, 28) sec.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
    sec.BorderSizePixel = 0 sec.ZIndex = 3 sec.LayoutOrder = order
    local lbl = Instance.new("TextLabel", sec)
    lbl.Size = UDim2.new(1, -14, 1, 0) lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1 lbl.Text = title:upper()
    lbl.TextColor3 = Color3.fromRGB(70, 70, 70)
    lbl.Font = Enum.Font.GothamBold lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.ZIndex = 4
end

local function makeRow(icon, label, valueDefault, order)
    local row = Instance.new("Frame", ScrollFrame)
    row.Size = UDim2.new(1, 0, 0, 38) row.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
    row.BorderSizePixel = 0 row.ZIndex = 3 row.LayoutOrder = order
    local iL = Instance.new("TextLabel", row)
    iL.Size = UDim2.new(0, 30, 1, 0) iL.Position = UDim2.new(0, 10, 0, 0)
    iL.BackgroundTransparency = 1 iL.Text = icon
    iL.TextColor3 = Color3.fromRGB(100, 160, 255)
    iL.Font = Enum.Font.GothamBold iL.TextSize = 16 iL.ZIndex = 4
    local nL = Instance.new("TextLabel", row)
    nL.Size = UDim2.new(0.45, 0, 1, 0) nL.Position = UDim2.new(0, 44, 0, 0)
    nL.BackgroundTransparency = 1 nL.Text = label
    nL.TextColor3 = Color3.fromRGB(130, 130, 130)
    nL.Font = Enum.Font.Gotham nL.TextSize = 13
    nL.TextXAlignment = Enum.TextXAlignment.Left nL.ZIndex = 4
    local vL = Instance.new("TextLabel", row)
    vL.Size = UDim2.new(0.5, -14, 1, 0) vL.Position = UDim2.new(0.5, 0, 0, 0)
    vL.BackgroundTransparency = 1 vL.Text = valueDefault
    vL.TextColor3 = Color3.fromRGB(230, 230, 230)
    vL.Font = Enum.Font.GothamBold iL.TextSize = 13
    vL.TextXAlignment = Enum.TextXAlignment.Right vL.ZIndex = 4
    local sep = Instance.new("Frame", row)
    sep.Size = UDim2.new(1, -14, 0, 1) sep.Position = UDim2.new(0, 7, 1, -1)
    sep.BackgroundColor3 = Color3.fromRGB(28, 28, 28) sep.BorderSizePixel = 0 sep.ZIndex = 4
    return vL
end

local function makeSlider(icon, label, minV, maxV, curV, order, isFloat, onChange)
    local row = Instance.new("Frame", ScrollFrame)
    row.Size = UDim2.new(1, 0, 0, 70) row.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
    row.BorderSizePixel = 0 row.ZIndex = 3 row.LayoutOrder = order
    local iL = Instance.new("TextLabel", row)
    iL.Size = UDim2.new(0,30,0,28) iL.Position=UDim2.new(0,10,0,5)
    iL.BackgroundTransparency=1 iL.Text=icon
    iL.TextColor3=Color3.fromRGB(100,160,255)
    iL.Font=Enum.Font.GothamBold iL.TextSize=16 iL.ZIndex=4
    local nL = Instance.new("TextLabel", row)
    nL.Size = UDim2.new(0.4,0,0,28) nL.Position=UDim2.new(0,44,0,5)
    nL.BackgroundTransparency=1 nL.Text=label
    nL.TextColor3=Color3.fromRGB(130,130,130)
    nL.Font=Enum.Font.Gotham nL.TextSize=13
    nL.TextXAlignment=Enum.TextXAlignment.Left nL.ZIndex=4
    local vL = Instance.new("TextLabel", row)
    vL.Size = UDim2.new(0.3,-14,0,28) vL.Position=UDim2.new(0.65,0,0,5)
    vL.BackgroundTransparency=1 vL.Text=tostring(curV)
    vL.TextColor3=Color3.fromRGB(230,230,230)
    vL.Font=Enum.Font.GothamBold vL.TextSize=13
    vL.TextXAlignment=Enum.TextXAlignment.Right vL.ZIndex=4
    local track = Instance.new("Frame", row)
    track.Size=UDim2.new(1,-60,0,6) track.Position=UDim2.new(0,44,0,45)
    track.BackgroundColor3=Color3.fromRGB(40,40,40) track.BorderSizePixel=0 track.ZIndex=4
    Instance.new("UICorner",track).CornerRadius=UDim.new(0,3)
    local fill = Instance.new("Frame", track)
    fill.BackgroundColor3=Color3.fromRGB(0,170,255) fill.BorderSizePixel=0 fill.ZIndex=5
    Instance.new("UICorner",fill).CornerRadius=UDim.new(0,3)
    local knob = Instance.new("Frame", track)
    knob.Size=UDim2.new(0,18,0,18) knob.BackgroundColor3=Color3.fromRGB(255,255,255)
    knob.BorderSizePixel=0 knob.ZIndex=6
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)
    local sep = Instance.new("Frame", row)
    sep.Size=UDim2.new(1,-14,0,1) sep.Position=UDim2.new(0,7,1,-1)
    sep.BackgroundColor3=Color3.fromRGB(28,28,28) sep.BorderSizePixel=0 sep.ZIndex=4
    local function refresh(v)
        local r=(v-minV)/(maxV-minV)
        fill.Size=UDim2.new(r,0,1,0)
        knob.Position=UDim2.new(r,-9,0.5,-9)
        vL.Text=tostring(v)
    end
    refresh(curV)
    local dragging=false
    knob.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local r=math.clamp((i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
            local v = isFloat and (math.floor((minV+r*(maxV-minV))*10)/10) or math.floor(minV+r*(maxV-minV))
            refresh(v) onChange(v)
        end
    end)
end

makeSection("Money", 10)
local vCurrent   = makeRow("$",  "Current Money", "Rp. 0",          11)
local vEarned    = makeRow("↑",  "Earned",        "Rp. 0",          12)
local vMoneyHour = makeRow("⚡", "Money / Hour",  "Calculating...", 13)
makeSection("Total Stats", 15)
local vTotalEarned = makeRow("💰", "Total Earned", "Rp. " .. formatNumber(totalEarned), 16)
local vTotalTime   = makeRow("⏰", "Total Time",   formatTime(totalTime),               17)

local resetRow = Instance.new("Frame", ScrollFrame)
resetRow.Size = UDim2.new(1,0,0,50) resetRow.BackgroundColor3=Color3.fromRGB(16,16,16)
resetRow.BorderSizePixel=0 resetRow.ZIndex=3 resetRow.LayoutOrder=18
local resetBtn = Instance.new("TextButton", resetRow)
resetBtn.Size=UDim2.new(1,-20,0,32) resetBtn.Position=UDim2.new(0,10,0,9)
resetBtn.BackgroundColor3=Color3.fromRGB(200,50,50) resetBtn.TextColor3=Color3.fromRGB(255,255,255)
resetBtn.Font=Enum.Font.GothamBold resetBtn.TextSize=12
resetBtn.Text="🔄 Reset Total Stats" resetBtn.BorderSizePixel=0 resetBtn.ZIndex=4
Instance.new("UICorner",resetBtn).CornerRadius=UDim.new(0,5)
resetBtn.MouseButton1Click:Connect(function()
    totalEarned=0 totalTime=0
    vTotalEarned.Text="Rp. 0" vTotalTime.Text="00:00:00"
    resetBtn.Text="✓ Stats Reset!" resetBtn.BackgroundColor3=Color3.fromRGB(0,150,70)
    task.wait(2)
    resetBtn.Text="🔄 Reset Total Stats" resetBtn.BackgroundColor3=Color3.fromRGB(200,50,50)
end)

makeSection("Stats", 20)
local vStatus  = makeRow("▶", "Status",  "Starting...", 21)
local vElapsed = makeRow("⏱", "Elapsed", "00:00:00",    22)
makeSection("Settings", 25)
makeSlider("⚡","Speed",MIN_SPEED,MAX_SPEED,SPEED,26,false,function(v) SPEED=v end)
makeSlider("💰","Farm Threshold",MIN_THRESHOLD,MAX_THRESHOLD,FARM_THRESHOLD,27,false,function(v) FARM_THRESHOLD=v end)
makeSection("Device", 30)
local vPing = makeRow("◉","Ping","0 ms",31)
local vFPS  = makeRow("◈","FPS","0",32)
local vExec = makeRow("⌘","Executor",EXECUTOR_NAME,33)
makeSection("About", 40)
local aboutRow = Instance.new("Frame", ScrollFrame)
aboutRow.Size=UDim2.new(1,0,0,60) aboutRow.BackgroundColor3=Color3.fromRGB(16,16,16)
aboutRow.BorderSizePixel=0 aboutRow.ZIndex=3 aboutRow.LayoutOrder=41
local credit = Instance.new("TextLabel", aboutRow)
credit.Size=UDim2.new(1,-20,1,0) credit.Position=UDim2.new(0,10,0,0)
credit.BackgroundTransparency=1 credit.Text="FREE VERSION\nUpgrade to Premium for all vehicles & auto-features"
credit.TextColor3=Color3.fromRGB(150,150,150) credit.Font=Enum.Font.Gotham
credit.TextSize=11 credit.TextXAlignment=Enum.TextXAlignment.Left
credit.TextYAlignment=Enum.TextYAlignment.Center credit.ZIndex=4 credit.TextWrapped=true

local blur = Instance.new("BlurEffect", Lighting)
blur.Size = 24

-- =====================
-- RESPAWN BIKE (Auto-respawn at threshold)
-- =====================
local function respawnBike(hum)
    if isRespawning then return end
    isRespawning = true
    active = false
    vStatus.Text = "Reached " .. formatNumber(FARM_THRESHOLD) .. "! Respawning bike..."

    sendKey(Enum.KeyCode.Space); task.wait(0.5)
    cleanupPhysics()
    despawnMio(); task.wait(2)
    spawnMio(); task.wait(3)
    
    local seat = findClosestSeat()
    if not seat then vStatus.Text = "No seat found!"; isRespawning = false; return end
    
    local char = Player.Character or Player.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    root.CFrame = seat.CFrame * CFrame.new(0, 2, 0); task.wait(1)
    seat:Sit(hum); task.wait(1)
    
    currentVehicle = seat.Parent
    seatOffset = calculateSeatOffset(currentVehicle, seat)
    startMoney = getMoney(); startTime = os.time()
    setupPhysics(seat)
    
    active = true
    isRespawning = false
    vStatus.Text = "Farming!"
end

-- =====================
-- START FARMING
-- =====================
local function startFarming()
    local char = Player.Character or Player.CharacterAdded:Wait()
    local hum  = char:WaitForChild("Humanoid")
    local root = char:WaitForChild("HumanoidRootPart")

    vStatus.Text = "Joining game..."
    local lce = RS:FindFirstChild("LoadCharacterEvent")
    if lce then
        lce:FireServer()
        char = Player.CharacterAdded:Wait()
        hum  = char:WaitForChild("Humanoid")
        root = char:WaitForChild("HumanoidRootPart")
        task.wait(1)
    end

    -- Drill down to the huge platform
    vStatus.Text = "Loading Script..."
    local searching = true
    while searching do
        local result = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0))
        if result and result.Instance then
            local part = result.Instance
            if part.Size.X >= HUGE_PLATFORM_SIZE or part.Name == "THE_SACRED_FLOOR" then
                savedFloor = part
                savedFloor.Name = "THE_SACRED_FLOOR"
                savedFloor.Parent = workspace
                searching = false
            else
                part:Destroy()
                task.wait(0.02)
            end
        else
            searching = false
        end
    end

    for _, obj in pairs(workspace:GetChildren()) do
        if obj ~= workspace.CurrentCamera and obj ~= char then
            if obj.Name == "THE_SACRED_FLOOR" then
                -- Keep it
            elseif obj ~= savedFloor and not obj:IsA("Terrain") then
                obj:Destroy()
            end
        end
    end

    spawnMio()
    task.wait(4)

    vStatus.Text = "Finding bike..."
    local seat, attempts = nil, 0
    repeat task.wait(0.5); attempts = attempts + 1; seat = findClosestSeat()
    until seat or attempts > 20
    if not seat then vStatus.Text = "No seat found!"; return end

    vStatus.Text = "Sitting on bike..."
    root.CFrame = seat.CFrame * CFrame.new(0, 2, 0); task.wait(0.5)
    seat:Sit(hum); task.wait(1)

    pcall(function() blur:Destroy() end)
    currentVehicle = seat.Parent
    seatOffset = calculateSeatOffset(currentVehicle, seat)
    startMoney = getMoney(); startTime = os.time()
    active = true
    setupPhysics(seat)
    
    -- Auto-respawn loop
    coroutine.wrap(function()
        while true do
            task.wait(1)
            if active and not isRespawning and startMoney then
                local earned = getMoney() - startMoney
                if earned >= FARM_THRESHOLD then
                    respawnBike(hum)
                end
            end
        end
    end)()
end

-- Start farming initially
startFarming()

-- Respawn detection - restart farming when character respawns
local isRestarting = false
Player.CharacterAdded:Connect(function()
    if isRestarting then return end
    isRestarting = true
    
    active = false
    isRespawning = false
    task.wait(2)
    startFarming()
    
    isRestarting = false
end)

-- =====================
-- ANTI-AFK SYSTEM
-- =====================
local VirtualInputManager = game:GetService("VirtualInputManager")
local lastActivity = tick()

coroutine.wrap(function()
    while task.wait(30) do
        if not active then continue end
        
        local now = tick()
        if now - lastActivity >= 120 then -- 2 minutes
            local keys = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D}
            local randomKey = keys[math.random(#keys)]
            
            VirtualInputManager:SendKeyEvent(true, randomKey, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, randomKey, false, game)
            
            lastActivity = now
        end
    end
end)()

-- =====================
-- STATS LOOP
-- =====================
coroutine.wrap(function()
    while task.wait(0.5) do
        if not active then continue end
        local elapsed = os.time() - startTime
        local money   = getMoney()
        local earned  = startMoney and (money - startMoney) or 0
        local mph     = elapsed > 0 and math.floor((earned/elapsed)*3600) or 0

        vCurrent.Text   = "Rp. " .. formatNumber(money)
        vEarned.Text    = "Rp. " .. formatNumber(math.max(0, earned))
        vMoneyHour.Text = elapsed > 10 and ("Rp. " .. formatNumber(mph) .. " /hr") or "Calculating..."
        vElapsed.Text   = formatTime(elapsed)
        vPing.Text      = getPing() .. " ms"
        vFPS.Text       = tostring(lastFPS)

        local ct  = totalEarned + earned
        local ctt = totalTime   + elapsed
        vTotalEarned.Text = "Rp. " .. formatNumber(ct)
        vTotalTime.Text   = formatTime(ctt)
    end
end)()

-- =====================
-- HEARTBEAT FARM (with Void Protection)
-- =====================

RunService.Heartbeat:Connect(function()
    if not active or not force or not currentVehicle then return end
    local seat = currentVehicle:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then return end

    -- Edge/void detection - immediate respawn with retry
    local groundRay = workspace:Raycast(seat.Position, Vector3.new(0, -10, 0))
    if not groundRay then
        vStatus.Text = "In air! Respawning..."
        active = false
        cleanupPhysics()
        despawnMio()
        
        for retry = 1, 5 do
            task.wait(1)
            spawnMio(); task.wait(3)
            local newSeat = findClosestSeat()
            if newSeat then
                local char = Player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if hum and root then
                        root.CFrame = newSeat.CFrame * CFrame.new(0, 2, 0)
                        task.wait(0.5)
                        newSeat:Sit(hum)
                        task.wait(1)
                        currentVehicle = newSeat.Parent
                        seatOffset = calculateSeatOffset(currentVehicle, newSeat)
                        startMoney = getMoney()
                        startTime = os.time()
                        setupPhysics(newSeat)
                        active = true
                        vStatus.Text = "Farming!"
                        return
                    end
                end
            end
            vStatus.Text = "Retry " .. retry .. "/5..."
        end
        vStatus.Text = "Failed after 5 retries!"
        return
    end
    
    -- Keep vehicle flat on ground using dynamic seat offset
    local p = seat.Position
    local _, ry = seat.CFrame:ToEulerAnglesYXZ()
    local targetCFrame = CFrame.new(p.X, groundRay.Position.Y + seatOffset, p.Z) * CFrame.Angles(0, ry, 0)
    seat.CFrame = targetCFrame
    if gyro then
        gyro.CFrame = CFrame.new(p.X, groundRay.Position.Y + seatOffset, p.Z) * CFrame.Angles(0, ry, 0)
    end

    local rayOrigin = (seat.CFrame * CFrame.new(0, 0, -CHECK_DISTANCE * direction)).p
    local hit = workspace:Raycast(rayOrigin, Vector3.new(0, -30, 0))
    if not hit then
        local now = tick()
        if now - lastDirChange >= DIR_COOLDOWN then
            direction     = direction * -1
            lastDirChange = now
        end
    end

    force.VectorVelocity = Vector3.new(0, 0, -SPEED * direction)
end)

-- ============================================
-- FREE SCRIPT END
-- ============================================
