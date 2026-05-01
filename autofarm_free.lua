-- ============================================
-- STEALTH FARM FREE
-- Creator: _nznt
-- Discord: discord.gg/q6dUF4CsKH
-- ============================================
-- FREE FEATURES:
-- - MioSporty vehicle only
-- - Auto-Start (no manual start button)
-- - Auto-Respawn
-- - Void Protection
-- - Total Statistics
-- ============================================

    -- Adonis bypass
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

    local Players          = game:GetService("Players")
    local RunService       = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Lighting         = game:GetService("Lighting")
    local RS               = game:GetService("ReplicatedStorage")
    local VIM              = game:GetService("VirtualInputManager")
    local Player           = Players.LocalPlayer
    local TeleportService  = game:GetService("TeleportService")
    local GuiService       = game:GetService("GuiService")

    local SPEED             = 290
    local MIN_SPEED         = 0
    local MAX_SPEED         = 400
    local CHECK_DISTANCE    = 15
    local HUGE_PLATFORM_SIZE= 2000
    local FARM_THRESHOLD    = 500000
    local DEFAULT_THRESHOLD = 500000
    local MIN_THRESHOLD     = 500000
    local MAX_THRESHOLD     = 5000000
    local NOT_SEATED_TIMEOUT = 20

    local active          = false
    local farmingActive   = false
    local currentVehicle  = nil
    local force           = nil
    local gyro            = nil
    local attachment      = nil
    local direction       = 1
    local savedFloor      = nil
    local startTime       = nil  -- Set when farming starts
    local startMoney      = nil
    local sessionStartTime = nil  -- Set when farming starts
    local sessionStartMoney = nil
    local lastDirChange   = 0
    local DIR_COOLDOWN    = 0.3
    local isRespawning    = false
    local unseatedSince   = nil
    local vehicleInput    = "Yamahax-MioSporty"  -- FREE: Locked to MioSporty
    local lastVoidTime    = 0
    local voidThreshold   = 2
    local seatOffset      = 1.5  -- Dynamic seat-to-wheel offset
    local rejoinInterval  = 0    -- 0 = disabled, minutes until auto-rejoin
    local sessionStart    = os.time()  -- Track session time for rejoin
    local autoRejoinEnabled = false  -- Toggle for auto-rejoin feature
    local autoPSJoinEnabled = false  -- Toggle for auto private server join
    local SURAKARTA_ID    = 131378148336503  -- Surakarta map ID
    local SURAKARTA_ARG   = "131378148336503"  -- Arg for CreatePrivateServer

    local totalEarned = 0
    local totalTime   = 0
    if isfile and readfile and isfile("nznt_stealth_stats.txt") then
        local content = readfile("nznt_stealth_stats.txt")
        local commaPos = content:find(",")
        if commaPos then
            totalEarned = tonumber(content:sub(1, commaPos-1)) or 0
            totalTime   = tonumber(content:sub(commaPos+1)) or 0
        end
    end

    local CFG_FILE = "nznt_stealth_config.txt"

    local function saveConfig()
        if not writefile then return end
        writefile(CFG_FILE, '{"speed":'..SPEED..',"farmThreshold":'..FARM_THRESHOLD..'}')
    end

    local function loadConfig()
        if not isfile or not readfile or not isfile(CFG_FILE) then return end
        local s = readfile(CFG_FILE)
        if not s or s == "" then return end
        local function g(k, d)
            local v = s:match('"'..k..'":"([^"]*)"') or s:match('"'..k..'":([%d%.]+)')
            return v and (tonumber(v) or v) or d
        end
        SPEED = g("speed", SPEED)
        FARM_THRESHOLD = g("farmThreshold", FARM_THRESHOLD)
    end
    loadConfig()

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
    local function getVehicleRootFromSeat(seat)
        local node = seat
        while node and node.Parent and node.Parent ~= workspace do
            node = node.Parent
        end
        if node and node ~= seat then
            return node
        end
        return seat
    end
    local function getPartLowestY(part)
        local cf, half = part.CFrame, part.Size * 0.5
        local lowest = math.huge
        for _, x in ipairs({-1, 1}) do
            for _, y in ipairs({-1, 1}) do
                for _, z in ipairs({-1, 1}) do
                    local p = cf * Vector3.new(half.X * x, half.Y * y, half.Z * z)
                    if p.Y < lowest then
                        lowest = p.Y
                    end
                end
            end
        end
        return lowest
    end

    local function isWheelPart(part)
        local name = part.Name:lower()
        return name:find("wheel") or name:find("tire") or name:find("tyre") or name:find("rim")
    end

    local function calculateSeatOffset(vehicle, seat)
        local lowestWheelY = math.huge
        local lowestVehicleY = math.huge
        for _, part in ipairs(vehicle:GetDescendants()) do
            if part:IsA("BasePart") and part ~= seat then
                local wheelBottom = getPartLowestY(part)
                if wheelBottom < lowestVehicleY then
                    lowestVehicleY = wheelBottom
                end
                if isWheelPart(part) then
                    if wheelBottom < lowestWheelY then
                        lowestWheelY = wheelBottom
                    end
                end
            end
        end
        local lowestY = lowestWheelY ~= math.huge and lowestWheelY or lowestVehicleY
        if lowestY ~= math.huge then
            return math.clamp(seat.Position.Y - lowestY, 1, 12)
        end
        return 1.5  -- Default fallback
    end
    local function setupPhysics(seat)
        attachment = Instance.new("Attachment", seat)
        force = Instance.new("LinearVelocity", seat)
        force.MaxForce = 99999999
        force.Attachment0 = attachment
        force.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
        gyro = Instance.new("BodyGyro", seat)
        gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)  -- Lock all rotation
        gyro.P = 100000  -- Stronger P for faster correction
        gyro.D = 1000    -- Add damping to prevent oscillation
        gyro.CFrame = seat.CFrame
    end
    local function cleanupPhysics()
        if force then force:Destroy() force = nil end
        if gyro then gyro:Destroy() gyro = nil end
        if attachment then attachment:Destroy() attachment = nil end
    end

    local function groundRaycast(origin, distance)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Blacklist
        params.IgnoreWater = true
        local filter = {}
        if currentVehicle then table.insert(filter, currentVehicle) end
        if Player.Character then table.insert(filter, Player.Character) end
        params.FilterDescendantsInstances = filter
        return workspace:Raycast(origin, Vector3.new(0, -distance, 0), params)
    end

    -- Anti-AFK removed - now handled by UI loader

    local function fireCarEvent(name, ...)
        local sf = RS:FindFirstChild("SpawnCarEvents")
        if sf then local r = sf:FindFirstChild(name) if r then r:FireServer(...) return true end end
        return false
    end
    local function spawnVehicle(id) return fireCarEvent("SpawnCar", id or vehicleInput) end
    local function despawnVehicle() fireCarEvent("DespawnCar") end

    -- UI
    local Gui = Instance.new("ScreenGui", Player:WaitForChild("PlayerGui"))
    Gui.Name = "nznt_StealthUI_Free"; Gui.IgnoreGuiInset = true; Gui.DisplayOrder = 999; Gui.ResetOnSpawn = false

    local MainFrame = Instance.new("Frame", Gui)
    MainFrame.Size = UDim2.new(1,0,1,0); MainFrame.BackgroundColor3 = Color3.fromRGB(10,10,10)
    MainFrame.ZIndex = 1; MainFrame.BorderSizePixel = 0; MainFrame.Active = false

    local TopBar = Instance.new("Frame", MainFrame)
    TopBar.Size = UDim2.new(1,0,0,44); TopBar.BackgroundColor3 = Color3.fromRGB(18,18,18)
    TopBar.BorderSizePixel = 0; TopBar.ZIndex = 2

    local TopTitle = Instance.new("TextLabel", TopBar)
    TopTitle.Size = UDim2.new(1,-120,1,0); TopTitle.Position = UDim2.new(0,14,0,0)
    TopTitle.BackgroundTransparency = 1; TopTitle.Text = "STEALTH FARM FREE  ·  nznt_"
    TopTitle.TextColor3 = Color3.fromRGB(180,180,180); TopTitle.Font = Enum.Font.GothamBold
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
        lbl.TextColor3 = Color3.fromRGB(70,70,70); lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 10; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 4
    end

    local function makeRow(icon, label, valueDefault, order)
        local row = makeContainer(38, order)
        local iL = Instance.new("TextLabel", row)
        iL.Size = UDim2.new(0,30,1,0); iL.Position = UDim2.new(0,10,0,0)
        iL.BackgroundTransparency = 1; iL.Text = icon; iL.TextColor3 = Color3.fromRGB(100,160,255)
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

    local function makeSlider(icon, label, minV, maxV, curV, order, isFloat, onChange)
        local row = makeContainer(70, order)
        local iL = Instance.new("TextLabel", row)
        iL.Size = UDim2.new(0,30,0,28); iL.Position = UDim2.new(0,10,0,5)
        iL.BackgroundTransparency = 1; iL.Text = icon; iL.TextColor3 = Color3.fromRGB(100,160,255)
        iL.Font = Enum.Font.GothamBold; iL.TextSize = 16; iL.ZIndex = 4
        local nL = Instance.new("TextLabel", row)
        nL.Size = UDim2.new(0.4,0,0,28); nL.Position = UDim2.new(0,44,0,5)
        nL.BackgroundTransparency = 1; nL.Text = label; nL.TextColor3 = Color3.fromRGB(130,130,130)
        nL.Font = Enum.Font.Gotham; nL.TextSize = 13; nL.TextXAlignment = Enum.TextXAlignment.Left; nL.ZIndex = 4
        
        local vBox = Instance.new("TextBox", row)
        vBox.Size = UDim2.new(0,50,0,28); vBox.Position = UDim2.new(1,-60,0,5)
        vBox.BackgroundColor3 = Color3.fromRGB(28,28,28); vBox.Text = tostring(curV)
        vBox.TextColor3 = Color3.fromRGB(230,230,230); vBox.Font = Enum.Font.GothamBold; vBox.TextSize = 13
        vBox.TextXAlignment = Enum.TextXAlignment.Center; vBox.ZIndex = 10
        vBox.BorderSizePixel = 0; vBox.ClearTextOnFocus = false; vBox.Active = true
        Instance.new("UICorner",vBox).CornerRadius = UDim.new(0,4)
        
        local track = Instance.new("Frame", row)
        track.Size = UDim2.new(1,-60,0,6); track.Position = UDim2.new(0,44,0,45)
        track.BackgroundColor3 = Color3.fromRGB(40,40,40); track.BorderSizePixel = 0; track.ZIndex = 4
        Instance.new("UICorner",track).CornerRadius = UDim.new(0,3)
        local fill = Instance.new("Frame", track)
        fill.BackgroundColor3 = Color3.fromRGB(0,170,255); fill.BorderSizePixel = 0; fill.ZIndex = 5
        Instance.new("UICorner",fill).CornerRadius = UDim.new(0,3)
        local knob = Instance.new("Frame", track)
        knob.Size = UDim2.new(0,18,0,18); knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
        knob.BorderSizePixel = 0; knob.ZIndex = 6
        Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)
        local sep = Instance.new("Frame", row)
        sep.Size = UDim2.new(1,-14,0,1); sep.Position = UDim2.new(0,7,1,-1)
        sep.BackgroundColor3 = Color3.fromRGB(28,28,28); sep.BorderSizePixel = 0; sep.ZIndex = 4
        
        local function refresh(v)
            local r = (v-minV)/(maxV-minV)
            fill.Size = UDim2.new(r,0,1,0); knob.Position = UDim2.new(r,-9,0.5,-9); vBox.Text = tostring(v)
        end
        refresh(curV)
        vBox.FocusLost:Connect(function()
            local val = isFloat and tonumber(vBox.Text:gsub("[^%d%.%-]","")) or tonumber(vBox.Text:gsub("[^%d%-]",""))
            if val then val = math.clamp(val,minV,maxV); refresh(val); onChange(val)
            else vBox.Text = tostring(isFloat and math.floor(curV*10)/10 or curV) end
        end)
        local dragging = false
        knob.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true end end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
        UserInputService.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
                local r = math.clamp((i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
                local v = isFloat and (math.floor((minV+r*(maxV-minV))*10)/10) or math.floor(minV+r*(maxV-minV))
                refresh(v); onChange(v)
            end
        end)
    end

    local function getVehicleList()
        local vehicles = {}
        pcall(function()
            local d = RS:FindFirstChild("DealershipEvents")
            if not d then return end
            local init = d:FindFirstChild("InitializeCarData")
            if not init or not init:IsA("RemoteFunction") then return end
            local ok, cfg = pcall(function() return init:InvokeServer() end)
            if ok and type(cfg) == "table" then
                for _, v in pairs(cfg) do
                    if type(v) == "table" and v.Name then
                        table.insert(vehicles, {id = v.Name, name = v.DisplayName or v.Name})
                    end
                end
            end
        end)
        if #vehicles > 0 then table.sort(vehicles, function(a,b) return a.name < b.name end) return vehicles end
        return {{id = "Yamahax-MioSporty", name = "Yamahax - Mio Sporty (2006)"}}
    end

    local function createDropdown(parent, position, size, options, onSelect)
        local dd = Instance.new("Frame", parent)
        dd.Size = size; dd.Position = position; dd.BackgroundColor3 = Color3.fromRGB(28,28,28)
        dd.BorderSizePixel = 0; dd.ZIndex = 10
        Instance.new("UICorner", dd).CornerRadius = UDim.new(0,4)
        
        local display = Instance.new("TextButton", dd)
        display.Size = UDim2.new(1,0,1,0); display.BackgroundTransparency = 1
        display.Text = options[1] and options[1].name or "Select Vehicle"
        display.TextColor3 = Color3.fromRGB(255,255,255); display.Font = Enum.Font.Gotham
        display.TextSize = 12; display.TextXAlignment = Enum.TextXAlignment.Left; display.ZIndex = 11
        
        local arrow = Instance.new("TextLabel", dd)
        arrow.Size = UDim2.new(0,20,1,0); arrow.Position = UDim2.new(1,-20,0,0)
        arrow.BackgroundTransparency = 1; arrow.Text = "▼"; arrow.TextColor3 = Color3.fromRGB(255,215,0)
        arrow.Font = Enum.Font.GothamBold; arrow.TextSize = 10; arrow.ZIndex = 11
        
        local list = Instance.new("ScrollingFrame", parent)
        list.Size = UDim2.new(0,size.X.Offset,0,math.min(200,#options*28))
        list.Position = UDim2.new(0,position.X.Offset,0,position.Y.Offset+size.Y.Offset+2)
        list.BackgroundColor3 = Color3.fromRGB(35,35,35); list.BorderSizePixel = 0
        list.ScrollBarThickness = 4; list.ScrollBarImageColor3 = Color3.fromRGB(80,80,80)
        list.CanvasSize = UDim2.new(0,0,0,#options*28); list.Visible = false; list.ZIndex = 20
        Instance.new("UICorner", list).CornerRadius = UDim.new(0,4)
        
        for i, opt in ipairs(options) do
            local btn = Instance.new("TextButton", list)
            btn.Size = UDim2.new(1,-8,0,26); btn.Position = UDim2.new(0,4,0,(i-1)*28+2)
            btn.BackgroundColor3 = Color3.fromRGB(28,28,28); btn.Text = opt.name
            btn.TextColor3 = Color3.fromRGB(230,230,230); btn.Font = Enum.Font.Gotham
            btn.TextSize = 11; btn.TextXAlignment = Enum.TextXAlignment.Left; btn.ZIndex = 21
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0,3)
            btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(255,215,0); btn.TextColor3 = Color3.fromRGB(0,0,0) end)
            btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(28,28,28); btn.TextColor3 = Color3.fromRGB(230,230,230) end)
            btn.MouseButton1Click:Connect(function()
                display.Text = opt.name; list.Visible = false; arrow.Text = "▼"; onSelect(opt.id, opt.name)
            end)
        end
        
        display.MouseButton1Click:Connect(function() list.Visible = not list.Visible; arrow.Text = list.Visible and "▲" or "▼" end)
        UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local p = input.Position
                local function inside(f) local fp,fs = f.AbsolutePosition,f.AbsoluteSize return p.X>=fp.X and p.X<=fp.X+fs.X and p.Y>=fp.Y and p.Y<=fp.Y+fs.Y end
                if not inside(list) and not inside(dd) then list.Visible = false; arrow.Text = "▼" end
            end
        end)
        return dd
    end

    -- FREE: No vehicle selection, auto-starts with MioSporty
    
    makeSection("Money", 10)
    local vCurrent   = makeRow("$", "Current Money", "Rp. 0", 11)
    local vEarned    = makeRow("↑", "Earned", "Rp. 0", 12)
    local vMoneyHour = makeRow("⚡", "Money / Hour", "Calculating...", 13)

    makeSection("Total Stats", 15)
    local vTotalEarned = makeRow("💰", "Total Earned", "Rp. " .. formatNumber(totalEarned), 16)
    local vTotalTime   = makeRow("⏰", "Total Time", formatTime(totalTime), 17)

    local resetRow = makeContainer(50, 18)
    local resetBtn = Instance.new("TextButton", resetRow)
    resetBtn.Size = UDim2.new(1,-20,0,32); resetBtn.Position = UDim2.new(0,10,0,9)
    resetBtn.BackgroundColor3 = Color3.fromRGB(200,50,50); resetBtn.TextColor3 = Color3.fromRGB(255,255,255)
    resetBtn.Font = Enum.Font.GothamBold; resetBtn.TextSize = 12; resetBtn.Text = "🔄 Reset Total Stats"
    resetBtn.BorderSizePixel = 0; resetBtn.ZIndex = 4
    Instance.new("UICorner",resetBtn).CornerRadius = UDim.new(0,5)
    resetBtn.MouseButton1Click:Connect(function()
        totalEarned=0 totalTime=0
        if writefile then writefile("nznt_stealth_stats.txt","0,0") end
        vTotalEarned.Text="Rp. 0" vTotalTime.Text="00:00:00"
        resetBtn.Text="✓ Stats Reset!"
        resetBtn.BackgroundColor3 = Color3.fromRGB(0,150,70)
        task.wait(2)
        resetBtn.Text="🔄 Reset Total Stats"
        resetBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
    end)

    makeSection("Stats", 20)
    local vStatus  = makeRow("▶", "Status", "Starting...", 21)
    local vElapsed = makeRow("⏱", "Elapsed", "00:00:00", 22)

    makeSection("Settings", 25)
    makeSlider("⚡","Speed",MIN_SPEED,MAX_SPEED,SPEED,26,false,function(v) SPEED=v saveConfig() end)
    makeSlider("💰","Farm Threshold",MIN_THRESHOLD,MAX_THRESHOLD,FARM_THRESHOLD,27,false,function(v) FARM_THRESHOLD=v saveConfig() end)
    makeSlider("🔄","Auto Rejoin (min)",0,120,rejoinInterval,28,false,function(v) rejoinInterval=v saveConfig() end)
    makeSection("Device", 30)
    local vPing = makeRow("◉","Ping","0 ms",31)
    local vFPS  = makeRow("◈","FPS","0",32)
    local vExec = makeRow("⌘","Executor",EXECUTOR_NAME,33)

    makeSection("About", 40)
    local aboutRow = makeContainer(60, 41)
    local credit = Instance.new("TextLabel", aboutRow)
    credit.Size = UDim2.new(1,-20,1,0); credit.Position = UDim2.new(0,10,0,0)
    credit.BackgroundTransparency = 1; credit.Text = "FREE VERSION\nUpgrade to Premium for all vehicles & auto-features"
    credit.TextColor3 = Color3.fromRGB(150,150,150); credit.Font = Enum.Font.Gotham; credit.TextSize = 11
    credit.TextXAlignment = Enum.TextXAlignment.Left; credit.TextYAlignment = Enum.TextYAlignment.Center
    credit.ZIndex = 4; credit.TextWrapped = true

    local blur = Instance.new("BlurEffect", Lighting)
    blur.Size = 24

    local function cleanWorkspace()
        local char = Player.Character
        if not char then
            char = Player.CharacterAdded:Wait()
            task.wait(2)
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then
            root = char:WaitForChild("HumanoidRootPart")
            task.wait(2)
        end
        
        -- Drill down to the huge platform (exactly like autofarm.lua)
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

        -- Cleanup except platform (exactly like autofarm.lua)
        for _, obj in pairs(workspace:GetChildren()) do
            if obj ~= workspace.CurrentCamera and obj ~= char and obj ~= savedFloor and not obj:IsA("Terrain") then
                obj:Destroy()
            end
        end
    end

    local function respawnVehicle(hum, statusText)
        if isRespawning then return end
        isRespawning = true; farmingActive = false
        unseatedSince = nil
        vStatus.Text = statusText or ("Reached " .. formatNumber(FARM_THRESHOLD) .. "! Respawning...")
        
        -- Don't update totalEarned/totalTime here - UI handles it with session values
        -- This prevents double counting
        
        sendKey(Enum.KeyCode.Space); task.wait(0.5)
        cleanupPhysics()
        despawnVehicle(); task.wait(2)
        spawnVehicle(vehicleInput); task.wait(3)
        
        local seat = findClosestSeat()
        if not seat then vStatus.Text = "No seat found!"; isRespawning = false; return end
        
        local char = Player.Character or Player.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart")
        root.CFrame = seat.CFrame * CFrame.new(0, 2, 0); task.wait(1)
        seat:Sit(hum); task.wait(1)
        
        currentVehicle = getVehicleRootFromSeat(seat)
        seatOffset = calculateSeatOffset(currentVehicle, seat)
        startMoney = getMoney(); startTime = os.time()
        unseatedSince = nil
        setupPhysics(seat)
        farmingActive = true; isRespawning = false; vStatus.Text = "Farming!"
    end

    local function startFarming()
        if farmingActive then return end
        local char = Player.Character or Player.CharacterAdded:Wait()
        local hum, root = char:WaitForChild("Humanoid"), char:WaitForChild("HumanoidRootPart")
        
        vStatus.Text = "Joining..."
        local lce = RS:FindFirstChild("LoadCharacterEvent")
        if lce then
            lce:FireServer()
            char = Player.CharacterAdded:Wait()
            hum = char:WaitForChild("Humanoid"); root = char:WaitForChild("HumanoidRootPart")
            task.wait(1)
        end
        
        vStatus.Text = "Spawning vehicle..."
        spawnVehicle(vehicleInput); task.wait(4)
        
        vStatus.Text = "Finding seat..."
        local seat, attempts = nil, 0
        repeat task.wait(0.5); attempts = attempts + 1; seat = findClosestSeat()
        until seat or attempts > 20
        if not seat then vStatus.Text = "No seat found!"; return false end
        
        vStatus.Text = "Sitting..."
        root.CFrame = seat.CFrame * CFrame.new(0, 2, 0); task.wait(0.5)
        seat:Sit(hum); task.wait(1)
        if hum.SeatPart ~= seat then vStatus.Text = "Failed to sit!"; return false end
        
        pcall(function() blur:Destroy() end)
        currentVehicle = getVehicleRootFromSeat(seat)
        seatOffset = calculateSeatOffset(currentVehicle, seat)
        startMoney = getMoney(); startTime = os.time()
        sessionStartMoney = startMoney; sessionStartTime = os.time()
        unseatedSince = nil
        farmingActive = true; active = true
        setupPhysics(seat)
        
        vStatus.Text = "Farming!"
        
        task.spawn(function()
            while farmingActive do
                task.wait(1)
                if farmingActive and not isRespawning and startMoney and getMoney() - startMoney >= FARM_THRESHOLD then
                    respawnVehicle(hum)
                end
            end
        end)
        return true
    end

    -- FREE: No stop function - auto-start only

    task.spawn(function()
        while true do
            task.wait(1)

            if not farmingActive or isRespawning then
                unseatedSince = nil
                continue
            end

            local char = Player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local expectedSeat = currentVehicle and (currentVehicle:IsA("VehicleSeat") and currentVehicle or currentVehicle:FindFirstChildWhichIsA("VehicleSeat", true))

            if hum and hum.SeatPart and (not expectedSeat or hum.SeatPart == expectedSeat) then
                unseatedSince = nil
                continue
            end

            unseatedSince = unseatedSince or os.clock()
            if os.clock() - unseatedSince >= NOT_SEATED_TIMEOUT then
                unseatedSince = nil
                vStatus.Text = "Not seated for 20s! Restarting..."

                if hum then
                    respawnVehicle(hum, "Not seated for 20s! Respawning...")
                else
                    farmingActive = false
                    active = false
                    cleanupPhysics()
                    despawnVehicle()
                    task.wait(1)
                    startFarming()
                end
            end
        end
    end)

    -- FREE: No webhook functionality

    task.spawn(function()
        while task.wait(0.5) do
            if not farmingActive then continue end
            if not startTime then continue end
            
            local money = getMoney()
            -- Earned THIS bike (resets on each spawn)
            local earnedThisBike = startMoney and (money - startMoney) or 0
            -- For money/hour, use session time
            local sessionElapsed = sessionStartTime and (os.time() - sessionStartTime) or 0
            local sessionEarned = sessionStartMoney and (money - sessionStartMoney) or 0
            local mph = sessionElapsed > 60 and math.floor((sessionEarned/sessionElapsed)*3600) or 0
            
            vCurrent.Text = "Rp. " .. formatNumber(money)
            vEarned.Text = "Rp. " .. formatNumber(math.max(0, earnedThisBike))
            vMoneyHour.Text = sessionElapsed > 60 and ("Rp. " .. formatNumber(mph) .. " /hr") or "Calculating..."
            vElapsed.Text = formatTime(os.time() - startTime)
            vPing.Text = getPing() .. " ms"
            vFPS.Text = tostring(lastFPS)
            
            -- Total stats = saved totals + current session
            local ct = totalEarned + sessionEarned
            local ctt = totalTime + sessionElapsed
            vTotalEarned.Text = "Rp. " .. formatNumber(ct)
            vTotalTime.Text = formatTime(ctt)
            
            -- Save combined totals to file periodically for crash recovery (don't update in-memory totals)
            if sessionElapsed > 0 and sessionElapsed % 30 < 1 and writefile then
                writefile("nznt_stealth_stats.txt", tostring(ct) .. "," .. tostring(ctt))
            end
        end
    end)

    RunService.Heartbeat:Connect(function()
        if not farmingActive or not force or not currentVehicle then return end
        local seat = currentVehicle:IsA("VehicleSeat") and currentVehicle or currentVehicle:FindFirstChildWhichIsA("VehicleSeat", true)
        if not seat then return end
        
        -- Check auto-rejoin timer
        if autoRejoinEnabled and rejoinInterval > 0 and os.time() - sessionStart >= rejoinInterval * 60 then
            vStatus.Text = "Auto rejoining..."
            farmingActive = false; active = false
            cleanupPhysics()
            despawnVehicle()
            task.wait(1)
            if queue_on_teleport and scriptSource ~= "" then
                queue_on_teleport(scriptSource)
            end
            TeleportService:Teleport(game.PlaceId, Player)
            return
        end
        
        -- Check farm threshold first
        if startMoney and getMoney() - startMoney >= FARM_THRESHOLD and not isRespawning then
            local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                respawnVehicle(hum)
                return
            end
        end
        
        local groundRay = groundRaycast(seat.Position, math.max(25, seatOffset + 8))
        if not groundRay then
            -- In air/void - respawn immediately with retry
            vStatus.Text = "In air! Respawning..."
            farmingActive = false; active = false
            cleanupPhysics()
            despawnVehicle()
            
            -- Retry loop until successful
            for retry = 1, 5 do
                task.wait(1)
                spawnVehicle(vehicleInput); task.wait(3)
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
                            currentVehicle = getVehicleRootFromSeat(newSeat)
                            seatOffset = calculateSeatOffset(currentVehicle, newSeat)
                            startMoney = getMoney()
                            startTime = os.time()
                            if not sessionStartMoney then sessionStartMoney = startMoney end
                            setupPhysics(newSeat)
                            farmingActive = true; active = true
                            vStatus.Text = "Farming!"
                            return  -- Success, exit heartbeat
                        end
                    end
                end
                vStatus.Text = "Retry " .. retry .. "/5..."
            end
            vStatus.Text = "Failed after 5 retries! Click START"
            return
        end
        
        -- Keep vehicle flat on ground using dynamic seat offset
        local p = seat.Position
        local _, ry = seat.CFrame:ToEulerAnglesYXZ()
        local targetCFrame = CFrame.new(p.X, groundRay.Position.Y + seatOffset, p.Z) * CFrame.Angles(0, ry, 0)
        seat.CFrame = targetCFrame
        -- Update gyro to maintain upright orientation
        if gyro then
            gyro.CFrame = CFrame.new(p.X, groundRay.Position.Y + seatOffset, p.Z) * CFrame.Angles(0, ry, 0)
        end
        
        -- Direction change detection
        local rayOrigin = (seat.CFrame * CFrame.new(0, 0, -CHECK_DISTANCE * direction)).p
        local hit = groundRaycast(rayOrigin, 30)
        if not hit then
            local now = tick()
            if now - lastDirChange >= DIR_COOLDOWN then
                direction = direction * -1
                lastDirChange = now
                -- Reset velocity to instantly stop momentum when changing direction
                for _, part in ipairs(currentVehicle:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    end
                end
                if seat:IsA("BasePart") then
                    seat.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end
            end
        end
        
        force.VectorVelocity = Vector3.new(0, 0, -SPEED * direction)
    end)

    task.spawn(function()
        task.wait(2)
        cleanWorkspace()
        pcall(function() blur:Destroy() end)
        vStatus.Text = "Ready - Select vehicle and click START"
    end)

    print("✅ Stealth Farm Loaded - Free Version (Auto-Start)")

    -- FREE: Auto-start farming
    task.spawn(function()
        task.wait(2)  -- Wait for everything to initialize
        startFarming()
    end)

    local isRestarting = false
    Player.CharacterAdded:Connect(function()
        if isRestarting then return end
        isRestarting = true
        farmingActive = false; active = false; isRespawning = false
        cleanupPhysics(); task.wait(2)
        if not isRestarting then return end
        vStatus.Text = "Respawned - Restarting..."
        if not startFarming() then
            vStatus.Text = "Respawned - Failed to restart"
        end
        isRestarting = false
    end)
