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
local AutofarmEnabled = true
local NoclipEnabled = true  -- Always enabled

local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local Remote = game:GetService("ReplicatedStorage")
    .BaristaAssets.Events.BaristaEvent

-- =====================
-- WEBHOOK SUPPORT
-- =====================
local WEBHOOK_FILE = "nznt_webhook_config.json"
local HttpService = game:GetService("HttpService")
local webhookUrl = ""
local webhookInterval = 60
local webhookEnabled = false
local lastWebhookTime = 0
local sessionStart = os.time()
local ordersCompleted = 0
local startMoney = 0

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

local function loadWebhookConfig()
    local ok, content = pcall(function() return readfile(WEBHOOK_FILE) end)
    if ok and content then
        local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
        if ok2 and data then
            webhookUrl = data.url or ""
            webhookInterval = data.interval or 60
            webhookEnabled = data.enabled or false
            warn("[Barista Autofarm] Webhook config loaded: " .. (webhookEnabled and "enabled" or "disabled"))
        end
    end
end

local function sendWebhook()
    if not webhookEnabled or webhookUrl == "" or not webhookUrl:find("discord") then return end
    if (os.time() - lastWebhookTime) < webhookInterval then return end
    
    local money = getMoney()
    local earned = money - startMoney
    local sessionElapsed = os.time() - sessionStart
    local mph = sessionElapsed > 60 and math.floor((math.max(0, earned) / sessionElapsed) * 3600) or 0
    
    local body = '{"embeds":[{"title":"Barista Autofarm","color":16776960,"fields":['
        ..'{"name":"💰 Current Money","value":"Rp. ' .. formatNumber(money) .. '","inline":true},'
        ..'{"name":"📈 Session Earned","value":"Rp. ' .. formatNumber(math.max(0, earned)) .. '","inline":true},'
        ..'{"name":"⚡ Money/Hour","value":"Rp. ' .. formatNumber(mph) .. '","inline":true},'
        ..'{"name":"⏱ Session Time","value":"' .. formatTime(sessionElapsed) .. '","inline":true},'
        ..'{"name":"☕ Orders","value":"' .. tostring(ordersCompleted) .. '","inline":true},'
        ..'{"name":"📍 Map","value":"Barista Simulator","inline":true}'
        ..'],"footer":{"text":"by _nznt — Barista Autofarm"}}]}'
    
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
        warn("[Barista Autofarm] Webhook sent!")
    end
end

loadWebhookConfig()
startMoney = getMoney()

-- =====================
-- 🔥 NEW MINIGAME SOLVER
-- =====================
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

print("[Minigame Solver] Loading...")

local isRunning = false
local connection = nil

-- Find minigame GUI
local function findMinigameGui()
    for _, gui in ipairs(Player.PlayerGui:GetChildren()) do
        local minigameFrame = gui:FindFirstChild("MinigameFrame", true)
        if minigameFrame and minigameFrame.Visible then
            return minigameFrame
        end
    end
    return nil
end

-- Find PlayerCursor (white bar)
local function findPlayerCursor(minigameFrame)
    local cursor = minigameFrame:FindFirstChild("PlayerCursor", true)
    if cursor then return cursor end
    
    -- Fallback: small horizontal bar
    for _, element in ipairs(minigameFrame:GetDescendants()) do
        if element:IsA("Frame") and element.AbsoluteSize.Y < 15 and element.AbsoluteSize.Y > 5 then
            if element.AbsoluteSize.X > 100 and element.AbsoluteSize.X < 150 then
                return element
            end
        end
    end
    
    return nil
end

-- Check if we should click (cursor is below target zone)
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

-- Main solver loop (uses MouseButton1Down method)
local function solve()
    local minigameFrame = findMinigameGui()
    if not minigameFrame then
        if connection then connection:Disconnect() end
        isRunning = false
        return
    end
    
    local tapZone = minigameFrame:FindFirstChild("TapZone")
    local targetZone = minigameFrame:FindFirstChild("TargetZone", true)
    local playerCursor = findPlayerCursor(minigameFrame)
    local progressBar = minigameFrame:FindFirstChild("ProgressBar", true)
    
    if not tapZone or not targetZone or not playerCursor then return end
    
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
            for _, conn in pairs(getconnections(tapButton.MouseButton1Down)) do
                conn:Fire()
            end
        end)
    end
    
    if progressBar and progressBar.Size.X.Scale >= 0.99 then
        print("[Minigame Solver] Complete!")
        if connection then connection:Disconnect() end
        isRunning = false
    end
end

local function start()
    if isRunning then return end
    isRunning = true
    local attempts = 0
    while not findMinigameGui() and attempts < 100 do
        task.wait(0.1)
        attempts = attempts + 1
    end
    if not findMinigameGui() then
        isRunning = false
        return
    end
    print("[Minigame Solver] Running...")
    connection = RunService.Heartbeat:Connect(solve)
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if not isRunning and findMinigameGui() then start() end
    end
end)

print("[Minigame Solver] Ready!")

_G.MinigameSolver = {
    start = start,
    stop = function()
        isRunning = false
        if connection then connection:Disconnect() end
    end
}

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
-- CHARACTER HANDLING
-- =====================
Player.CharacterAdded:Connect(function(c)
    Character = c
    HumanoidRootPart = c:WaitForChild("HumanoidRootPart")
end)

-- Noclip (optimized - only runs when enabled)
local noclipConnection = nil
local function setNoclip(enabled)
    NoclipEnabled = enabled
    if enabled then
        if noclipConnection then noclipConnection:Disconnect() end
        noclipConnection = RunService.Heartbeat:Connect(function()
            if Character then
                for _, part in ipairs(Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end
end

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
    
    -- Method 1: VirtualInputManager (hold E)
    local success = pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(duration)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    
    if not success then
        -- Method 2: VirtualUser fallback (hold E)
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:SetKeyDown(Enum.KeyCode.E)
            task.wait(duration)
            VirtualUser:SetKeyUp(Enum.KeyCode.E)
        end)
    end
end

-- Legacy FirePrompt for compatibility
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
    -- Fallback to key press
    PressKeyE(0.5)
    return true
end

local walkConnections = {}
local function WalkTo(position, speed)
    local hum = Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- Cleanup old connections
    for _, conn in ipairs(walkConnections) do
        pcall(function() conn:Disconnect() end)
    end
    walkConnections = {}

    hum.WalkSpeed = speed or 16
    hum:MoveTo(position)

    local reached = false
    local conn = hum.MoveToFinished:Connect(function()
        reached = true
    end)
    table.insert(walkConnections, conn)

    local start = tick()
    repeat
        task.wait(0.1)
        if tick() - start > 0.5 then hum:MoveTo(position) end
    until reached or tick() - start > 30

    pcall(function() conn:Disconnect() end)
end

-- =====================
-- AUTO-SERVE CHECK
-- =====================
local function hasItemInHand()
    -- Check if player is holding an item (tool in character)
    for _, tool in ipairs(Character:GetChildren()) do
        if tool:IsA("Tool") then
            return true, tool
        end
    end
    -- Check backpack
    local backpack = Player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                -- Common barista item names
                local name = tool.Name:lower()
                if name:find("coffee") or name:find("latte") or name:find("cappuccino") 
                   or name:find("espresso") or name:find("mocha") or name:find("drink")
                   or name:find("cup") or name:find("mug") or name:find("glass") then
                    return true, tool
                end
            end
        end
    end
    return false, nil
end

local function isBrewingComplete()
    -- Check GUI indicators for brewing completion
    for _, gui in ipairs(Player.PlayerGui:GetChildren()) do
        -- Look for completion indicators
        for _, element in ipairs(gui:GetDescendants()) do
            if element:IsA("TextLabel") or element:IsA("TextButton") then
                local text = element.Text:lower()
                if (text:find("ready") or text:find("done") or text:find("complete") 
                    or text:find("finished") or text:find("serve")) and element.Visible then
                    return true
                end
            end
        end
    end
    return false
end

local function autoServeIfReady()
    local hasItem, item = hasItemInHand()
    local brewingDone = isBrewingComplete()
    
    if hasItem or brewingDone then
        print("[Auto-Serve] Item ready, serving...")
        -- Find serve position and serve
        local servePos = Vector3.new(-4995.79, 4.29, -759.78)
        WalkTo(servePos, 16)
        task.wait(0.3)
        PressKeyE(1.5)
        return true
    end
    return false
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
    -- Enable noclip immediately
    setNoclip(true)
    print("[Autofarm] Noclip enabled")
    
    -- Join team first
    joinBaristaTeam()
    
    local seat = getSeat()
    if not seat then
        warn("No seat found!")
        return
    end

    local hum = Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- sit
    seat.CFrame = HumanoidRootPart.CFrame * CFrame.new(0, -2, -3)
    task.wait(0.3)
    seat:Sit(hum)
    task.wait(0.8)

    -- travel
    SeatTo(Vector3.new(-658.01, 3.18, -701.16))
    SeatTo(Vector3.new(-755.63, 3.80, -641.64))
    SeatTo(Vector3.new(-5011.18, 3.80, -588.81))

    -- NEW: Job position logic with freeze
    local jobPos = Vector3.new(-4989.87, 4.29, -714.39)

    SeatTo(jobPos)

    -- jump using real input
    VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
    task.wait(0.1)
    VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)

    task.wait(0.4)

    -- destroy seat
    local seat = getSeat()
    if seat then
        seat:Destroy()
        currentSeat = nil
    end

    -- freeze movement
    local root = HumanoidRootPart
    local oldVel = root.Velocity
    root.Velocity = Vector3.zero

    task.wait(0.5)

    -- press E key
    PressKeyE(1)

    task.wait(0.5)

    -- restore movement
    root.Velocity = oldVel

    while AutofarmEnabled do
        -- Send webhook if enabled
        sendWebhook()
        
        -- Auto-serve check - always serve if holding item or brewing done
        autoServeIfReady()
        
        if CheckMachineBroke() then
            RepairMachine()
        end

        -- Walk to brewing machine and hold E
        WalkTo(Vector3.new(-4997.14, 4.29, -795.25), 16)
        PressKeyE(1.5)

        -- Wait for minigame to complete
        local minigameWait = 0
        while isRunning and minigameWait < 15 do
            task.wait(0.5)
            minigameWait = minigameWait + 0.5
        end
        
        -- Small buffer after minigame
        task.wait(0.5)

        -- Walk to cashier and hold E
        WalkTo(Vector3.new(-4995.79, 4.29, -759.78), 16)
        PressKeyE(1.5)

        -- Count completed order
        ordersCompleted = ordersCompleted + 1

        task.wait(3)
    end
end

-- START
task.spawn(RunAutofarm)
