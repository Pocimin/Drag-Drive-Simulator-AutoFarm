--[[
███╗   ██╗███████╗███████╗███╗   ██╗████████╗    ██╗   ██╗██╗
████╗  ██║╚══███╔╝██╔════╝████╗  ██║╚══██╔══╝    ██║   ██║██║
██╔██╗ ██║  ███╔╝ █████╗  ██╔██╗ ██║   ██║       ██║   ██║██║
██║╚██╗██║ ███╔╝  ██╔══╝  ██║╚██╗██║   ██║       ██║   ██║██║
██║ ╚████║███████╗███████╗██║ ╚████║   ██║       ╚██████╔╝██║
╚═╝  ╚═══╝╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝        ╚═════╝ ╚═╝
                    Premium Interface Suite
                         by _nznt
]]

local function LoadnzntUI()
	local lunaSource = game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua", true)
	
	local r = lunaSource
	
	-- Use plain string.gsub (4th param = true means PLAIN string, no patterns)
	r = r:gsub("local Luna = {", "local nznt = {", 1)
	r = r:gsub('Folder = "Luna"', 'Folder = "nznt"', 1)
	
	-- Colors
	r = r:gsub("Color3.fromRGB(117, 164, 206)", "Color3.fromRGB(147, 112, 219)")
	r = r:gsub("Color3.fromRGB(123, 201, 201)", "Color3.fromRGB(138, 43, 226)")
	r = r:gsub("Color3.fromRGB(224, 138, 175)", "Color3.fromRGB(75, 0, 130)")
	
	-- Logo
	r = r:gsub('"82795327169782"', '"75353810328300"')
	r = r:gsub('"123795201100198"', '"75353810328300"')
	r = r:gsub('"6031097225"', '"75353810328300"')
	
	-- Website - these have dots so we need pattern matching, but replacement is safe
	r = r:gsub("github%.com/Nebula%-Softworks", "discord.gg/q6dUF4CsKH")
	r = r:gsub("nebulasoftworks%.xyz", "discord.gg/q6dUF4CsKH")
	
	-- Functions
	r = r:gsub("Luna:CreateWindow", "nznt:CreateWindow")
	r = r:gsub("Luna:Notification", "nznt:Notification")
	r = r:gsub("Luna:SaveConfig", "nznt:SaveConfig")
	r = r:gsub("Luna:LoadConfig", "nznt:LoadConfig")
	r = r:gsub("Luna:Destroy", "nznt:Destroy")
	r = r:gsub("Luna.Options", "nznt.Options")
	r = r:gsub("Luna.Flags", "nznt.Flags")
	r = r:gsub("Luna.ThemeGradient", "nznt.ThemeGradient")
	r = r:gsub("Luna.Folder", "nznt.Folder")
	r = r:gsub("Luna:RefreshConfigList", "nznt:RefreshConfigList")
	r = r:gsub("Luna:LoadAutoloadConfig", "nznt:LoadAutoloadConfig")
	
	-- UI Names
	r = r:gsub('"LunaInterface"', '"nzntInterface"')
	r = r:gsub('Name = "Luna"', 'Name = "nznt"')
	
	-- Loading
	r = r:gsub('LoadingTitle = "Luna Interface Suite"', 'LoadingTitle = "nznt UI"')
	r = r:gsub('LoadingTitle = "Nebula Client %([^)]*%)"', 'LoadingTitle = "nznt UI"')
	r = r:gsub('LoadingSubtitle = "by Nebula Softworks"', 'LoadingSubtitle = "Premium Edition"')
	
	-- Notifications
	r = r:gsub('Title = "Interface"', 'Title = "nznt"')
	r = r:gsub("Luna Interface Suite |", "nznt UI |")
	
	-- Config
	r = r:gsub('"/settings"', '"/nznt_settings"')
	r = r:gsub('".luna"', '".nznt"')
	
	-- Credits
	r = r:gsub("Nebula Softworks", "_nznt")
	r = r:gsub("by Nebula Softworks", "by _nznt")
	
	-- Deprecation
	r = r:gsub("Luna Is Deprecated", "nznt UI")
	r = r:gsub("ConfirmLuna", "Confirmnznt")
	
	-- Release
	r = r:gsub('local Release = "Prerelease Beta 6%.1"', 'local Release = "nznt UI 1.0"')
	
	-- Header
	local header = "-- ============================================\n-- nznt UI - Premium Interface Suite\n-- Creator: _nznt\n-- Discord: discord.gg/q6dUF4CsKH\n-- ============================================\n\n"
	r = header .. r
	
	local fn = loadstring(r)
	if fn then return fn() else error("Failed to load nznt UI") end
end

getgenv().nznt = LoadnzntUI()
return getgenv().nznt
