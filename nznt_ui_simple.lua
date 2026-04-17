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

-- Load Luna and apply branding changes
local function LoadBrandedLuna()
	local source = game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/main/source.lua", true)
	
	-- Apply branding changes only (keep Luna internals working)
	source = source:gsub('Folder = "Luna"', 'Folder = "NZNT"')
	source = source:gsub("github%.com/Nebula%-Softworks", "discord.gg/q6dUF4CsKH")
	source = source:gsub("nebulasoftworks%.xyz", "discord.gg/q6dUF4CsKH")
	
	-- Colors - Purple theme
	source = source:gsub("Color3.fromRGB%(117, 164, 206%)", "Color3.fromRGB(147, 112, 219)")
	source = source:gsub("Color3.fromRGB%(123, 201, 201%)", "Color3.fromRGB(138, 43, 226)")
	source = source:gsub("Color3.fromRGB%(224, 138, 175%)", "Color3.fromRGB(75, 0, 130)")
	
	-- Logo IDs - replace all known Luna logo IDs
	source = source:gsub('"82795327169782"', '"75353810328300"')
	source = source:gsub('"123795201100198"', '"75353810328300"')
	source = source:gsub('"6031097225"', '"75353810328300"')
	
	-- Credits
	source = source:gsub("Nebula Softworks", "_nznt")
	source = source:gsub("by _nznt", "by _nznt") -- just in case
	
	-- Version
	source = source:gsub('"Prerelease Beta 6%.1"', '"NZNT UI 1.0"')
	
	-- Execute and get Luna table
	local fn, err = loadstring(source)
	if not fn then
		error("Failed to compile: " .. tostring(err))
	end
	
	local Luna = fn()
	if not Luna then
		error("Luna returned nil")
	end
	
	-- Return Luna but expose it as both Luna and NZNT
	getgenv().Luna = Luna
	getgenv().NZNT = Luna
	
	return Luna
end

return LoadBrandedLuna()
