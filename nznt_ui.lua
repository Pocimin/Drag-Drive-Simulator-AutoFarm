--[[



███╗   ██╗███████╗███████╗███╗   ██╗████████╗    ██╗   ██╗██╗
████╗  ██║╚══███╔╝██╔════╝████╗  ██║╚══██╔══╝    ██║   ██║██║
██╔██╗ ██║  ███╔╝ █████╗  ██╔██╗ ██║   ██║       ██║   ██║██║
██║╚██╗██║ ███╔╝  ██╔══╝  ██║╚██╗██║   ██║       ██║   ██║██║
██║ ╚████║███████╗███████╗██║ ╚████║   ██║       ╚██████╔╝██║
╚═╝  ╚═══╝╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝        ╚═════╝ ╚═╝
                                                               
                    Premium Interface Suite
                         by _nznt
                         discord.gg/q6dUF4CsKH

Main Credits
_nznt | Designing And Programming | Main Developer

Original Luna UI by Nebula Softworks - Used as base

]]

-- ============================================
-- nznt UI - Rebranded Luna Interface Suite
-- ============================================
-- This loader fetches Luna and rebrands it to nznt
-- with custom purple theme and updated branding
-- ============================================

local function LoadnzntUI()
	-- Fetch original Luna source
	local lunaSource = game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua", true)
	
	-- nznt Branding replacements
	local replacements = {
		-- ASCII Art header replacement
		["local Luna = {"] = "local nznt = {",
		['Folder = "Luna"'] = 'Folder = "nznt"',
		
		-- Theme gradient - Purple/Premium colors
		["Color3.fromRGB(117, 164, 206)"] = "Color3.fromRGB(147, 112, 219)", -- MediumPurple
		["Color3.fromRGB(123, 201, 201)"] = "Color3.fromRGB(138, 43, 226)", -- BlueViolet  
		["Color3.fromRGB(224, 138, 175)"] = "Color3.fromRGB(75, 0, 130)", -- Indigo
		
		-- Logo ID replacement
		['LogoID = "82795327169782"'] = 'LogoID = "75353810328300"',
		['LogoID = "123795201100198"'] = 'LogoID = "75353810328300"',
		['LogoID = "6031097225"'] = 'LogoID = "75353810328300"',
		
		-- Website/Discord
		['local website = "github.com/Nebula%-Softworks"'] = 'local website = "discord.gg/q6dUF4CsKH"',
		['local website = "nebulasoftworks%.xyz"'] = 'local website = "discord.gg/q6dUF4CsKH"',
		
		-- Function names
		["Luna:CreateWindow"] = "nznt:CreateWindow",
		["Luna:Notification"] = "nznt:Notification",
		["Luna:SaveConfig"] = "nznt:SaveConfig",
		["Luna:LoadConfig"] = "nznt:LoadConfig",
		["Luna:Destroy"] = "nznt:Destroy",
		["Luna.Options"] = "nznt.Options",
		["Luna.Flags"] = "nznt.Flags",
		["Luna.ThemeGradient"] = "nznt.ThemeGradient",
		["Luna.Folder"] = "nznt.Folder",
		["Luna:RefreshConfigList"] = "nznt:RefreshConfigList",
		["Luna:LoadAutoloadConfig"] = "nznt:LoadAutoloadConfig",
		["Luna:SaveConfig"] = "nznt:SaveConfig",
		["Luna:LoadConfig"] = "nznt:LoadConfig",
		
		-- UI Names
		['Name = "LunaInterface"'] = 'Name = "nzntInterface"',
		['Name = "Luna"'] = 'Name = "nznt"',
		
		-- Loading screen
		['LoadingTitle = "Luna Interface Suite"'] = 'LoadingTitle = "nznt UI"',
		['LoadingTitle = "Nebula Client %(Luna Hub%)"'] = 'LoadingTitle = "nznt UI"',
		['LoadingSubtitle = "by Nebula Softworks"'] = 'LoadingSubtitle = "Premium Edition"',
		['LoadingSubtitle = "Loading script for Blade Ball"'] = 'LoadingSubtitle = "Initializing..."',
		
		-- Notifications
		['Title = "Interface"'] = 'Title = "nznt"',
		['Title = "Luna"'] = 'Title = "nznt"',
		["Luna Interface Suite |"] = "nznt UI |",
		['Title = "Luna Is Deprecated"'] = 'Title = "nznt UI"',
		
		-- Config system
		['"/settings"'] = '"/nznt_settings"',
		['".luna"'] = '".nznt"',
		['"%.luna"'] = '"%%.nznt"',
		
		-- Credits and branding
		["Nebula Softworks"] = "_nznt",
		["nebulasoftworks%.xyz"] = "discord.gg/q6dUF4CsKH",
		["github%.com/Nebula%-Softworks"] = "discord.gg/q6dUF4CsKH",
		["by Nebula Softworks"] = "by _nznt",
		
		-- Deprecation warning
		["Luna Is Deprecated"] = "nznt UI",
		["getgenv%(%)%.ConfirmLuna"] = "getgenv().Confirmnznt",
		["ConfirmLuna"] = "Confirmnznt",
		
		-- Release version
		['local Release = "Prerelease Beta 6%.1"'] = 'local Release = "nznt UI 1.0"',
	}
	
	-- Apply replacements
	local rebranded = lunaSource
	for old, new in pairs(replacements) do
		rebranded = rebranded:gsub(old, new)
	end
	
	-- Add nznt header comment
	local nzntHeader = [[-- ============================================
-- nznt UI - Premium Interface Suite
-- Creator: _nznt
-- Discord: discord.gg/q6dUF4CsKH
-- ============================================
-- Forked from Luna Interface Suite by Nebula Softworks
-- Rebranded and customized for nznt's Hub
-- ============================================

]]
	
	rebranded = nzntHeader .. rebranded
	
	-- Execute the rebranded source
	local executeRebranded = loadstring(rebranded)
	if executeRebranded then
		return executeRebranded()
	else
		error("Failed to load nznt UI - rebranding failed")
	end
end

-- Export the library loader
getgenv().nznt = LoadnzntUI()
return getgenv().nznt
