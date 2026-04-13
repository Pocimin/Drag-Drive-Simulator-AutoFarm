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
	
	-- Loading screen text (bottom right corner "Luna UI")
	source = source:gsub('"Luna Interface Suite"', '"nznt\'s hub"')
	source = source:gsub("Luna Interface Suite", "nznt's hub")
	source = source:gsub('LoadingTitle = "Luna"', 'LoadingTitle = "nznt"')
	source = source:gsub('"Nebula Client %(Luna Hub%)"', '"nznt\'s hub"')
	
	-- Execute and get Luna table
	local fn, err = loadstring(source)
	if not fn then
		error("Failed to compile: " .. tostring(err))
	end
	
	local Luna = fn()
	if not Luna then
		error("Luna returned nil")
	end
	
	-- Store original CreateWindow
	local OriginalCreateWindow = Luna.CreateWindow
	
	-- Override CreateWindow to apply custom styling
	Luna.CreateWindow = function(Settings)
		local Window = OriginalCreateWindow(Settings)
		
		-- Wait for UI to be created then customize it
		spawn(function()
			wait(0.5) -- Let UI initialize
			
			-- Find the main GUI
			local gui = game.CoreGui:FindFirstChild("LunaInterface") or game.CoreGui:FindFirstChild("NZNTInterface")
			if gui then
				-- Style buttons - make fonts match title
				for _, obj in pairs(gui:GetDescendants()) do
					if obj:IsA("TextButton") or obj:IsA("TextLabel") then
						-- Match button text to title font style
						if obj.Name == "Title" or obj.Name == "Name" or obj.Parent and obj.Parent.Name == "Button" then
							obj.Font = Enum.Font.GothamBold
						end
						if obj.Name == "Desc" or obj.Name == "Description" then
							obj.Font = Enum.Font.Gotham
						end
					end
					
					-- Round logo corners
					if obj.Name == "Logo" or obj.Name == "IconLabel" then
						if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
							-- Add or modify UICorner
							local corner = obj:FindFirstChildOfClass("UICorner")
							if not corner then
								corner = Instance.new("UICorner")
								corner.Parent = obj
							end
							corner.CornerRadius = UDim.new(0, 8)
						end
					end
				end
			end
		end)
		
		return Window
	end
	
	-- Return Luna but expose it as both Luna and NZNT
	getgenv().Luna = Luna
	getgenv().NZNT = Luna
	
	return Luna
end

return LoadBrandedLuna()
