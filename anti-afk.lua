-- ============================================
-- ANTI-AFK Script for NZNT Hub
-- Prevents idle/AFK kicks
-- Creator: _nznt
-- ============================================

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")

-- Anti-AFK System
local antiAFKEnabled = false

-- Function to enable/disable anti-AFK
local function setAntiAFK(enabled)
    antiAFKEnabled = enabled
end

-- Function to get current status
local function getAntiAFKStatus()
    return antiAFKEnabled
end

-- Hook into idle detection (method 1: disable connections)
if getconnections then
    for _, connection in pairs(getconnections(Player.Idled)) do
        if connection["Disable"] then
            connection["Disable"](connection)
        elseif connection["Disconnect"] then
            connection["Disconnect"](connection)
        end
    end
end

-- Backup idle handler (method 2: capture controller)
Player.Idled:Connect(function()
    if antiAFKEnabled then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- Return functions for external control
return {
    setAntiAFK = setAntiAFK,
    getAntiAFKStatus = getAntiAFKStatus
}
