-- NZNT MacLib Fork
-- Modified version with logo instead of globe + full-width sections
-- Original: https://github.com/biggaboy212/Maclib

local MacLib = { 
	Options = {}, 
	Folder = "Maclib", 
	GetService = function(service)
		return cloneref and cloneref(game:GetService(service)) or game:GetService(service)
	end
}

local TweenService = MacLib.GetService("TweenService")
local RunService = MacLib.GetService("RunService")
local HttpService = MacLib.GetService("HttpService")
local ContentProvider = MacLib.GetService("ContentProvider")
local UserInputService = MacLib.GetService("UserInputService")
local Lighting = MacLib.GetService("Lighting")
local Players = MacLib.GetService("Players")

local isStudio = RunService:IsStudio()
local LocalPlayer = Players.LocalPlayer
local windowState, acrylicBlur, hasGlobalSetting
local tabs, currentTabInstance, tabIndex, unloaded = {}, nil, 0, false

-- NZNT: Logo replaces globe
local assets = {
	interFont = "rbxassetid://12187365364",
	userInfoBlurred = "rbxassetid://18824089198",
	toggleBackground = "rbxassetid://18772190202",
	togglerHead = "rbxassetid://18772309008",
	buttonImage = "rbxassetid://10709791437",
	searchIcon = "rbxassetid://86737463322606",
	colorWheel = "rbxassetid://2849458409",
	colorTarget = "rbxassetid://73265255323268",
	grid = "rbxassetid://121484455191370",
	logo = "rbxassetid://75353810328300",
	transform = "rbxassetid://90336395745819",
	dropdown = "rbxassetid://18865373378",
	sliderbar = "rbxassetid://18772615246",
	sliderhead = "rbxassetid://18772834246",
}

local function GetGui()
	local newGui = Instance.new("ScreenGui")
	newGui.ScreenInsets = Enum.ScreenInsets.None
	newGui.ResetOnSpawn = false
	newGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	newGui.DisplayOrder = 2147483647
	local parent = RunService:IsStudio() and LocalPlayer:FindFirstChild("PlayerGui") or (gethui and gethui()) or (cloneref and cloneref(MacLib.GetService("CoreGui")) or MacLib.GetService("CoreGui"))
	newGui.Parent = parent
	return newGui
end

local function Tween(instance, tweeninfo, propertytable)
	return TweenService:Create(instance, tweeninfo, propertytable)
end

function MacLib:Window(Settings)
	local WindowFunctions = {Settings = Settings}
	acrylicBlur = Settings.AcrylicBlur ~= nil and Settings.AcrylicBlur or true
	
	local macLib = GetGui()
	
	local notifications = Instance.new("Frame")
	notifications.Name = "Notifications"
	notifications.BackgroundTransparency = 1
	notifications.Size = UDim2.fromScale(1, 1)
	notifications.Parent = macLib
	notifications.ZIndex = 2
	
	local notifList = Instance.new("UIListLayout")
	notifList.Padding = UDim.new(0, 10)
	notifList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	notifList.SortOrder = Enum.SortOrder.LayoutOrder
	notifList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	notifList.Parent = notifications
	
	local notifPad = Instance.new("UIPadding")
	notifPad.PaddingBottom = UDim.new(0, 10)
	notifPad.PaddingLeft = UDim.new(0, 10)
	notifPad.PaddingRight = UDim.new(0, 10)
	notifPad.PaddingTop = UDim.new(0, 10)
	notifPad.Parent = notifications
	
	local base = Instance.new("Frame")
	base.Name = "Base"
	base.AnchorPoint = Vector2.new(0.5, 0.5)
	base.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	base.BackgroundTransparency = Settings.AcrylicBlur and 0.05 or 0
	base.Position = UDim2.fromScale(0.5, 0.5)
	base.Size = Settings.Size or UDim2.fromOffset(868, 650)
	
	local baseUIScale = Instance.new("UIScale")
	baseUIScale.Parent = base
	
	local baseUICorner = Instance.new("UICorner")
	baseUICorner.CornerRadius = UDim.new(0, 10)
	baseUICorner.Parent = base
	
	local baseUIStroke = Instance.new("UIStroke")
	baseUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	baseUIStroke.Color = Color3.fromRGB(255, 255, 255)
	baseUIStroke.Transparency = 0.9
	baseUIStroke.Parent = base
	
	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.BackgroundTransparency = 1
	sidebar.Size = UDim2.fromScale(0.325, 1)
	
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.AnchorPoint = Vector2.new(1, 0)
	divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	divider.BackgroundTransparency = 0.9
	divider.Position = UDim2.fromScale(1, 0)
	divider.Size = UDim2.new(0, 1, 1, 0)
	divider.Parent = sidebar
	
	local windowControls = Instance.new("Frame")
	windowControls.Name = "WindowControls"
	windowControls.BackgroundTransparency = 1
	windowControls.Size = UDim2.new(1, 0, 0, 31)
	
	local controls = Instance.new("Frame")
	controls.Name = "Controls"
	controls.BackgroundTransparency = 1
	controls.Size = UDim2.fromScale(1, 1)
	
	local controlsList = Instance.new("UIListLayout")
	controlsList.Padding = UDim.new(0, 5)
	controlsList.FillDirection = Enum.FillDirection.Horizontal
	controlsList.SortOrder = Enum.SortOrder.LayoutOrder
	controlsList.VerticalAlignment = Enum.VerticalAlignment.Center
	controlsList.Parent = controls
	
	local controlsPad = Instance.new("UIPadding")
	controlsPad.PaddingLeft = UDim.new(0, 11)
	controlsPad.Parent = controls
	
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.9
	
	local function makeControlBtn(name, color, layoutOrder)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = color
		btn.LayoutOrder = layoutOrder
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = btn
		return btn
	end
	
	local exit = makeControlBtn("Exit", Color3.fromRGB(250, 93, 86), 0)
	exit.Parent = controls
	
	local minimize = makeControlBtn("Minimize", Color3.fromRGB(252, 190, 57), 1)
	minimize.Parent = controls
	
	local maximize = makeControlBtn("Maximize", Color3.fromRGB(119, 174, 94), 1)
	maximize.Size = UDim2.fromOffset(7, 7)
	maximize.BackgroundTransparency = 1
	stroke:Clone().Parent = maximize
	maximize.Parent = controls
	
	if Settings.DisabledWindowControls then
		for _, btnName in pairs(Settings.DisabledWindowControls) do
			if btnName == "Exit" then
				exit.Size = UDim2.fromOffset(7, 7)
				exit.BackgroundTransparency = 1
				stroke:Clone().Parent = exit
			elseif btnName == "Minimize" then
				minimize.Size = UDim2.fromOffset(7, 7)
				minimize.BackgroundTransparency = 1
				stroke:Clone().Parent = minimize
			end
		end
	end
	
	controls.Parent = windowControls
	
	local divider1 = Instance.new("Frame")
	divider1.Name = "Divider"
	divider1.AnchorPoint = Vector2.new(0, 1)
	divider1.BackgroundTransparency = 0.9
	divider1.Position = UDim2.fromScale(0, 1)
	divider1.Size = UDim2.new(1, 0, 0, 1)
	divider1.Parent = windowControls
	
	windowControls.Parent = sidebar
	
	local information = Instance.new("Frame")
	information.Name = "Information"
	information.BackgroundTransparency = 1
	information.Position = UDim2.fromOffset(0, 31)
	information.Size = UDim2.new(1, 0, 0, 60)
	
	local divider2 = Instance.new("Frame")
	divider2.Name = "Divider"
	divider2.AnchorPoint = Vector2.new(0, 1)
	divider2.BackgroundTransparency = 0.9
	divider2.Position = UDim2.fromScale(0, 1)
	divider2.Size = UDim2.new(1, 0, 0, 1)
	divider2.Parent = information
	
	local informationHolder = Instance.new("Frame")
	informationHolder.Name = "InformationHolder"
	informationHolder.BackgroundTransparency = 1
	informationHolder.Size = UDim2.fromScale(1, 1)
	
	local holderPad = Instance.new("UIPadding")
	holderPad.PaddingBottom = UDim.new(0, 10)
	holderPad.PaddingLeft = UDim.new(0, 23)
	holderPad.PaddingRight = UDim.new(0, 22)
	holderPad.PaddingTop = UDim.new(0, 10)
	holderPad.Parent = informationHolder
	
	-- NZNT: Logo button with rounded corners
	local globalSettingsButton = Instance.new("ImageButton")
	globalSettingsButton.Name = "GlobalSettingsButton"
	globalSettingsButton.Image = assets.logo
	globalSettingsButton.ImageTransparency = 0.5
	globalSettingsButton.AnchorPoint = Vector2.new(1, 0.5)
	globalSettingsButton.BackgroundTransparency = 1
	globalSettingsButton.Position = UDim2.fromScale(1, 0.5)
	globalSettingsButton.Size = UDim2.fromOffset(24, 24)
	globalSettingsButton.Parent = informationHolder
	
	-- NZNT: Rounded corners for logo
	local logoCorner = Instance.new("UICorner")
	logoCorner.CornerRadius = UDim.new(0, 6)
	logoCorner.Parent = globalSettingsButton
	
	local function ChangeGlobalSettingsButtonState(State)
		if State == "Default" then
			Tween(globalSettingsButton, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {ImageTransparency = 0.5}):Play()
		elseif State == "Hover" then
			Tween(globalSettingsButton, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {ImageTransparency = 0.3}):Play()
		end
	end
	
	globalSettingsButton.MouseEnter:Connect(function() ChangeGlobalSettingsButtonState("Hover") end)
	globalSettingsButton.MouseLeave:Connect(function() ChangeGlobalSettingsButtonState("Default") end)
	
	local titleFrame = Instance.new("Frame")
	titleFrame.Name = "TitleFrame"
	titleFrame.BackgroundTransparency = 1
	titleFrame.Size = UDim2.fromScale(1, 1)
	
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.FontFace = Font.new(assets.interFont, Enum.FontWeight.SemiBold)
	title.Text = Settings.Title
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.RichText = true
	title.TextSize = 18
	title.TextTransparency = 0.1
	title.TextTruncate = Enum.TextTruncate.SplitWord
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Top
	title.AutomaticSize = Enum.AutomaticSize.Y
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -20, 0, 0)
	title.Parent = titleFrame
	
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.FontFace = Font.new(assets.interFont, Enum.FontWeight.Medium)
	subtitle.RichText = true
	subtitle.Text = Settings.Subtitle
	subtitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	subtitle.TextSize = 12
	subtitle.TextTransparency = 0.7
	subtitle.TextTruncate = Enum.TextTruncate.SplitWord
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextYAlignment = Enum.TextYAlignment.Top
	subtitle.AutomaticSize = Enum.AutomaticSize.Y
	subtitle.BackgroundTransparency = 1
	subtitle.LayoutOrder = 1
	subtitle.Size = UDim2.new(1, -20, 0, 0)
	subtitle.Parent = titleFrame
	
	local titleList = Instance.new("UIListLayout")
	titleList.Padding = UDim.new(0, 3)
	titleList.SortOrder = Enum.SortOrder.LayoutOrder
	titleList.VerticalAlignment = Enum.VerticalAlignment.Center
	titleList.Parent = titleFrame
	
	titleFrame.Parent = informationHolder
	informationHolder.Parent = information
	information.Parent = sidebar
	
	local sidebarGroup = Instance.new("Frame")
	sidebarGroup.Name = "SidebarGroup"
	sidebarGroup.BackgroundTransparency = 1
	sidebarGroup.Position = UDim2.fromOffset(0, 91)
	sidebarGroup.Size = UDim2.new(1, 0, 1, -91)
	
	local userInfo = Instance.new("Frame")
	userInfo.Name = "UserInfo"
	userInfo.AnchorPoint = Vector2.new(0, 1)
	userInfo.BackgroundTransparency = 1
	userInfo.Position = UDim2.fromScale(0, 1)
	userInfo.Size = UDim2.new(1, 0, 0, 107)
	
	local infoGroup = Instance.new("Frame")
	infoGroup.Name = "InformationGroup"
	infoGroup.BackgroundTransparency = 1
	infoGroup.Size = UDim2.fromScale(1, 1)
	
	local infoGroupPad = Instance.new("UIPadding")
	infoGroupPad.PaddingBottom = UDim.new(0, 17)
	infoGroupPad.PaddingLeft = UDim.new(0, 25)
	infoGroupPad.Parent = infoGroup
	
	local infoGroupList = Instance.new("UIListLayout")
	infoGroupList.FillDirection = Enum.FillDirection.Horizontal
	infoGroupList.SortOrder = Enum.SortOrder.LayoutOrder
	infoGroupList.VerticalAlignment = Enum.VerticalAlignment.Center
	infoGroupList.Parent = infoGroup
	
	local userId = LocalPlayer.UserId
	local headshotImage, isReady = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size48x48)
	
	local headshot = Instance.new("ImageLabel")
	headshot.Name = "Headshot"
	headshot.BackgroundTransparency = 1
	headshot.Size = UDim2.fromOffset(32, 32)
	headshot.Image = isReady and headshotImage or "rbxassetid://0"
	
	local headshotCorner = Instance.new("UICorner")
	headshotCorner.CornerRadius = UDim.new(1, 0)
	headshotCorner.Parent = headshot
	
	local headshotStroke = Instance.new("UIStroke")
	headshotStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	headshotStroke.Color = Color3.fromRGB(255, 255, 255)
	headshotStroke.Transparency = 0.9
	headshotStroke.Parent = headshot
	
	headshot.Parent = infoGroup
	
	local userDisplayFrame = Instance.new("Frame")
	userDisplayFrame.Name = "UserAndDisplayFrame"
	userDisplayFrame.BackgroundTransparency = 1
	userDisplayFrame.LayoutOrder = 1
	userDisplayFrame.Size = UDim2.new(1, -42, 0, 32)
	
	local displayName = Instance.new("TextLabel")
	displayName.Name = "DisplayName"
	displayName.FontFace = Font.new(assets.interFont, Enum.FontWeight.SemiBold)
	displayName.Text = LocalPlayer.DisplayName
	displayName.TextColor3 = Color3.fromRGB(255, 255, 255)
	displayName.TextSize = 13
	displayName.TextTransparency = 0.1
	displayName.TextTruncate = Enum.TextTruncate.SplitWord
	displayName.TextXAlignment = Enum.TextXAlignment.Left
	displayName.TextYAlignment = Enum.TextYAlignment.Top
	displayName.AutomaticSize = Enum.AutomaticSize.XY
	displayName.BackgroundTransparency = 1
	displayName.Size = UDim2.fromScale(1, 0)
	displayName.Parent = userDisplayFrame
	
	local displayFramePad = Instance.new("UIPadding")
	displayFramePad.PaddingLeft = UDim.new(0, 8)
	displayFramePad.PaddingTop = UDim.new(0, 3)
	displayFramePad.Parent = userDisplayFrame
	
	local displayFrameList = Instance.new("UIListLayout")
	displayFrameList.Padding = UDim.new(0, 1)
	displayFrameList.SortOrder = Enum.SortOrder.LayoutOrder
	displayFrameList.Parent = userDisplayFrame
	
	local username = Instance.new("TextLabel")
	username.Name = "Username"
	username.FontFace = Font.new(assets.interFont, Enum.FontWeight.SemiBold)
	username.Text = "@" .. LocalPlayer.Name
	username.TextColor3 = Color3.fromRGB(255, 255, 255)
	username.TextSize = 12
	username.TextTransparency = 0.7
	username.TextTruncate = Enum.TextTruncate.SplitWord
	username.TextXAlignment = Enum.TextXAlignment.Left
	username.TextYAlignment = Enum.TextYAlignment.Top
	username.AutomaticSize = Enum.AutomaticSize.XY
	username.BackgroundTransparency = 1
	username.LayoutOrder = 1
	username.Size = UDim2.fromScale(1, 0)
	username.Parent = userDisplayFrame
	
	userDisplayFrame.Parent = infoGroup
	infoGroup.Parent = userInfo
	
	local userInfoPad = Instance.new("UIPadding")
	userInfoPad.PaddingLeft = UDim.new(0, 10)
	userInfoPad.PaddingRight = UDim.new(0, 10)
	userInfoPad.Parent = userInfo
	
	userInfo.Parent = sidebarGroup
	
	local sidebarPad = Instance.new("UIPadding")
	sidebarPad.PaddingLeft = UDim.new(0, 10)
	sidebarPad.PaddingRight = UDim.new(0, 10)
	sidebarPad.PaddingTop = UDim.new(0, 31)
	sidebarPad.Parent = sidebarGroup
	
	local tabSwitchers = Instance.new("Frame")
	tabSwitchers.Name = "TabSwitchers"
	tabSwitchers.BackgroundTransparency = 1
	tabSwitchers.Size = UDim2.new(1, 0, 1, -107)
	
	local tabScroll = Instance.new("ScrollingFrame")
	tabScroll.Name = "TabSwitchersScrollingFrame"
	tabScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabScroll.BottomImage = ""
	tabScroll.CanvasSize = UDim2.new()
	tabScroll.ScrollBarImageTransparency = 0.8
	tabScroll.ScrollBarThickness = 1
	tabScroll.TopImage = ""
	tabScroll.BackgroundTransparency = 1
	tabScroll.Size = UDim2.fromScale(1, 1)
	
	local tabScrollList = Instance.new("UIListLayout")
	tabScrollList.Padding = UDim.new(0, 17)
	tabScrollList.SortOrder = Enum.SortOrder.LayoutOrder
	tabScrollList.Parent = tabScroll
	
	local tabScrollPad = Instance.new("UIPadding")
	tabScrollPad.PaddingTop = UDim.new(0, 2)
	tabScrollPad.Parent = tabScroll
	
	tabScroll.Parent = tabSwitchers
	tabSwitchers.Parent = sidebarGroup
	sidebarGroup.Parent = sidebar
	sidebar.Parent = base
	
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.AnchorPoint = Vector2.new(1, 0)
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromScale(1, 0)
	content.Size = UDim2.new(0, (base.AbsoluteSize.X - sidebar.AbsoluteSize.X), 1, 0)
	
	-- Topbar
	local topbar = Instance.new("Frame")
	topbar.Name = "Topbar"
	topbar.BackgroundTransparency = 1
	topbar.Size = UDim2.new(1, 0, 0, 63)
	
	local divider4 = Instance.new("Frame")
	divider4.Name = "Divider"
	divider4.AnchorPoint = Vector2.new(0, 1)
	divider4.BackgroundTransparency = 0.9
	divider4.Position = UDim2.fromScale(0, 1)
	divider4.Size = UDim2.new(1, 0, 0, 1)
	divider4.Parent = topbar
	
	local elements = Instance.new("Frame")
	elements.Name = "Elements"
	elements.BackgroundTransparency = 1
	elements.Size = UDim2.fromScale(1, 1)
	
	local elementsPad = Instance.new("UIPadding")
	elementsPad.PaddingLeft = UDim.new(0, 20)
	elementsPad.PaddingRight = UDim.new(0, 20)
	elementsPad.Parent = elements
	
	elements.Parent = topbar
	topbar.Parent = content
	content.Parent = base
	
	-- Global Settings popup
	local globalSettings = Instance.new("Frame")
	globalSettings.Name = "GlobalSettings"
	globalSettings.AutomaticSize = Enum.AutomaticSize.XY
	globalSettings.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	globalSettings.Position = UDim2.fromScale(0.298, 0.104)
	
	local gsStroke = Instance.new("UIStroke")
	gsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	gsStroke.Color = Color3.fromRGB(255, 255, 255)
	gsStroke.Transparency = 0.9
	gsStroke.Parent = globalSettings
	
	local gsCorner = Instance.new("UICorner")
	gsCorner.CornerRadius = UDim.new(0, 10)
	gsCorner.Parent = globalSettings
	
	local gsPad = Instance.new("UIPadding")
	gsPad.PaddingBottom = UDim.new(0, 10)
	gsPad.PaddingTop = UDim.new(0, 10)
	gsPad.Parent = globalSettings
	
	local gsList = Instance.new("UIListLayout")
	gsList.Padding = UDim.new(0, 5)
	gsList.SortOrder = Enum.SortOrder.LayoutOrder
	gsList.Parent = globalSettings
	
	local gsScale = Instance.new("UIScale")
	gsScale.Scale = 1e-07
	gsScale.Parent = globalSettings
	globalSettings.Parent = base
	
	base.Parent = macLib
	
	-- Functions
	function WindowFunctions:UpdateTitle(NewTitle)
		title.Text = NewTitle
	end
	
	function WindowFunctions:UpdateSubtitle(NewSubtitle)
		subtitle.Text = NewSubtitle
	end
	
	local hovering, toggled = false, false
	local function toggle()
		if not toggled then
			Tween(gsScale, TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Scale = 1}):Play()
			toggled = true
		else
			Tween(gsScale, TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Scale = 0}):Play()
			toggled = false
		end
	end
	
	globalSettingsButton.MouseButton1Click:Connect(function()
		if not hasGlobalSetting then return end
		toggle()
	end)
	globalSettings.MouseEnter:Connect(function() hovering = true end)
	globalSettings.MouseLeave:Connect(function() hovering = false end)
	UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 and toggled and not hovering then
			toggle()
		end
	end)
	
	function WindowFunctions:GlobalSetting(Settings)
		hasGlobalSetting = true
		local GlobalSettingFunctions = {}
		local gsBtn = Instance.new("TextButton")
		gsBtn.Name = "GlobalSetting"
		gsBtn.Text = ""
		gsBtn.BackgroundTransparency = 1
		gsBtn.Size = UDim2.fromOffset(200, 30)
		
		local gsBtnPad = Instance.new("UIPadding")
		gsBtnPad.PaddingLeft = UDim.new(0, 15)
		gsBtnPad.Parent = gsBtn
		
		local settingName = Instance.new("TextLabel")
		settingName.Name = "SettingName"
		settingName.FontFace = Font.new(assets.interFont)
		settingName.Text = Settings.Name
		settingName.RichText = true
		settingName.TextColor3 = Color3.fromRGB(255, 255, 255)
		settingName.TextSize = 13
		settingName.TextTransparency = 0.5
		settingName.TextTruncate = Enum.TextTruncate.SplitWord
		settingName.TextXAlignment = Enum.TextXAlignment.Left
		settingName.AnchorPoint = Vector2.new(0, 0.5)
		settingName.AutomaticSize = Enum.AutomaticSize.Y
		settingName.BackgroundTransparency = 1
		settingName.Position = UDim2.fromScale(0, 0.5)
		settingName.Size = UDim2.new(1, -40, 0, 0)
		settingName.Parent = gsBtn
		
		local checkmark = Instance.new("TextLabel")
		checkmark.Name = "Checkmark"
		checkmark.FontFace = Font.new(assets.interFont, Enum.FontWeight.Medium)
		checkmark.Text = "✓"
		checkmark.TextColor3 = Color3.fromRGB(255, 255, 255)
		checkmark.TextSize = 13
		checkmark.TextTransparency = 1
		checkmark.TextXAlignment = Enum.TextXAlignment.Left
		checkmark.AnchorPoint = Vector2.new(0, 0.5)
		checkmark.AutomaticSize = Enum.AutomaticSize.Y
		checkmark.BackgroundTransparency = 1
		checkmark.LayoutOrder = -1
		checkmark.Position = UDim2.fromScale(0, 0.5)
		checkmark.Size = UDim2.fromOffset(-10, 0)
		checkmark.Parent = gsBtn
		
		gsBtn.Parent = globalSettings
		
		local function Toggle(State)
			if not State then
				Tween(checkmark, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Size = UDim2.fromOffset(-10, 0)}):Play()
				Tween(settingName, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {TextTransparency = 0.5}):Play()
			else
				Tween(checkmark, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Size = UDim2.fromOffset(12, 0)}):Play()
				Tween(settingName, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {TextTransparency = 0.2}):Play()
			end
		end
		
		local state = Settings.Default
		Toggle(state)
		
		gsBtn.MouseButton1Click:Connect(function()
			state = not state
			Toggle(state)
			if Settings.Callback then
				task.spawn(function() Settings.Callback(state) end)
			end
		end)
		
		function GlobalSettingFunctions:UpdateName(NewName)
			settingName.Text = NewName
		end
		function GlobalSettingFunctions:UpdateState(NewState)
			Toggle(NewState)
			state = NewState
		end
		
		return GlobalSettingFunctions
	end
	
	function WindowFunctions:TabGroup()
		local SectionFunctions = {}
		
		local tabGroup = Instance.new("Frame")
		tabGroup.Name = "Section"
		tabGroup.AutomaticSize = Enum.AutomaticSize.Y
		tabGroup.BackgroundTransparency = 1
		tabGroup.Size = UDim2.fromScale(1, 0)
		
		local divider3 = Instance.new("Frame")
		divider3.Name = "Divider"
		divider3.AnchorPoint = Vector2.new(0.5, 1)
		divider3.BackgroundTransparency = 0.9
		divider3.Position = UDim2.fromScale(0.5, 1)
		divider3.Size = UDim2.new(1, -21, 0, 1)
		divider3.Parent = tabGroup
		
		local sectionTabSwitchers = Instance.new("Frame")
		sectionTabSwitchers.Name = "SectionTabSwitchers"
		sectionTabSwitchers.BackgroundTransparency = 1
		sectionTabSwitchers.Size = UDim2.fromScale(1, 1)
		
		local stList = Instance.new("UIListLayout")
		stList.Padding = UDim.new(0, 15)
		stList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		stList.SortOrder = Enum.SortOrder.LayoutOrder
		stList.Parent = sectionTabSwitchers
		
		local stPad = Instance.new("UIPadding")
		stPad.PaddingBottom = UDim.new(0, 15)
		stPad.Parent = sectionTabSwitchers
		
		sectionTabSwitchers.Parent = tabGroup
		tabGroup.Parent = tabScroll
		
		function SectionFunctions:Tab(TabSettings)
			local TabFunctions = {Settings = TabSettings}
			local tabSwitcher = Instance.new("TextButton")
			tabSwitcher.Name = "TabSwitcher"
			tabSwitcher.Text = ""
			tabSwitcher.AutoButtonColor = false
			tabSwitcher.BackgroundTransparency = 1
			tabSwitcher.Size = UDim2.new(1, 0, 0, 32)
			
			local tsStroke = Instance.new("UIStroke")
			tsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			tsStroke.Color = Color3.fromRGB(255, 255, 255)
			tsStroke.Transparency = 1
			tsStroke.Parent = tabSwitcher
			
			local tsCorner = Instance.new("UICorner")
			tsCorner.CornerRadius = UDim.new(0, 6)
			tsCorner.Parent = tabSwitcher
			
			local tsPad = Instance.new("UIPadding")
			tsPad.PaddingLeft = UDim.new(0, 5)
			tsPad.PaddingRight = UDim.new(0, 5)
			tsPad.Parent = tabSwitcher
			
			local tabImage = Instance.new("ImageLabel")
			tabImage.Name = "TabImage"
			tabImage.Image = TabSettings.Image
			tabImage.ImageTransparency = 0.5
			tabImage.AnchorPoint = Vector2.new(0, 0.5)
			tabImage.BackgroundTransparency = 1
			tabImage.Position = UDim2.fromScale(0, 0.5)
			tabImage.Size = UDim2.fromOffset(16, 16)
			tabImage.Parent = tabSwitcher
			
			local tabSwitcherName = Instance.new("TextLabel")
			tabSwitcherName.Name = "TabSwitcherName"
			tabSwitcherName.FontFace = Font.new(assets.interFont)
			tabSwitcherName.Text = TabSettings.Name
			tabSwitcherName.RichText = true
			tabSwitcherName.TextColor3 = Color3.fromRGB(255, 255, 255)
			tabSwitcherName.TextSize = 13
			tabSwitcherName.TextTransparency = 0.5
			tabSwitcherName.TextTruncate = Enum.TextTruncate.SplitWord
			tabSwitcherName.TextXAlignment = Enum.TextXAlignment.Left
			tabSwitcherName.AnchorPoint = Vector2.new(0, 0.5)
			tabSwitcherName.AutomaticSize = Enum.AutomaticSize.Y
			tabSwitcherName.BackgroundTransparency = 1
			tabSwitcherName.Position = UDim2.fromOffset(22, 0)
			tabSwitcherName.Size = UDim2.new(1, -22, 0, 0)
			tabSwitcherName.Parent = tabSwitcher
			
			tabSwitcher.Parent = sectionTabSwitchers
			tabIndex = tabIndex + 1
			
			local elements1 = Instance.new("ScrollingFrame")
			elements1.Name = "Elements"
			elements1.AutomaticCanvasSize = Enum.AutomaticSize.Y
			elements1.BottomImage = ""
			elements1.CanvasSize = UDim2.new()
			elements1.ScrollBarImageTransparency = 0.8
			elements1.ScrollBarThickness = 1
			elements1.TopImage = ""
			elements1.BackgroundTransparency = 1
			elements1.Size = UDim2.fromScale(1, 1)
			
			local elPad = Instance.new("UIPadding")
			elPad.PaddingLeft = UDim.new(0, 15)
			elPad.PaddingRight = UDim.new(0, 15)
			elPad.PaddingTop = UDim.new(0, 15)
			elPad.Parent = elements1
			
			local elList = Instance.new("UIListLayout")
			elList.Padding = UDim.new(0, 10)
			elList.SortOrder = Enum.SortOrder.LayoutOrder
			elList.Parent = elements1
			
			function TabFunctions:Section(SectionSettings)
				local SectionFunctions = {}
				
				-- NZNT: Full-width section (ignore Side parameter)
				local section = Instance.new("Frame")
				section.Name = "Section"
				section.AutomaticSize = Enum.AutomaticSize.Y
				section.BackgroundTransparency = 1
				-- NZNT: Always full width
				section.Size = UDim2.new(1, 0, 0, 0)
				
				local secList = Instance.new("UIListLayout")
				secList.Padding = UDim.new(0, 5)
				secList.SortOrder = Enum.SortOrder.LayoutOrder
				secList.Parent = section
				
				local secPad = Instance.new("UIPadding")
				secPad.PaddingLeft = UDim.new(0, 10)
				secPad.PaddingRight = UDim.new(0, 10)
				secPad.Parent = section
				
				section.Parent = elements1
				
				function SectionFunctions:Button(ButtonSettings, Flag)
					local ButtonFunctions = {}
					ButtonFunctions.Class = "Button"
					
					local button = Instance.new("TextButton")
					button.Name = "Button"
					button.FontFace = Font.new(assets.interFont)
					button.Text = ButtonSettings.Name
					button.TextColor3 = Color3.fromRGB(255, 255, 255)
					button.TextSize = 15
					button.TextTransparency = 0.5
					button.TextTruncate = Enum.TextTruncate.AtEnd
					button.AutoButtonColor = false
					button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
					button.Size = UDim2.new(1, 0, 0, 38)
					
					local btnPad = Instance.new("UIPadding")
					btnPad.PaddingBottom = UDim.new(0, 9)
					btnPad.PaddingLeft = UDim.new(0, 10)
					btnPad.PaddingRight = UDim.new(0, 10)
					btnPad.PaddingTop = UDim.new(0, 9)
					btnPad.Parent = button
					
					local btnCorner = Instance.new("UICorner")
					btnCorner.CornerRadius = UDim.new(0, 10)
					btnCorner.Parent = button
					
					button.Parent = section
					
					local function ChangeState(State)
						if State == "Idle" then
							Tween(button, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {BackgroundTransparency = 0, TextTransparency = 0.5}):Play()
						elseif State == "Hover" then
							Tween(button, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.3, TextTransparency = 0.6}):Play()
						end
					end
					
					button.MouseButton1Click:Connect(function()
						if ButtonSettings.Callback then
							task.spawn(ButtonSettings.Callback)
						end
					end)
					
					button.MouseEnter:Connect(function() ChangeState("Hover") end)
					button.MouseLeave:Connect(function() ChangeState("Idle") end)
					
					function ButtonFunctions:UpdateName(New)
						button.Text = New
					end
					function ButtonFunctions:SetVisibility(State)
						button.Visible = State
					end
					
					if Flag then
						MacLib.Options[Flag] = ButtonFunctions
					end
					return ButtonFunctions
				end
				
				function SectionFunctions:Toggle(ToggleSettings, Flag)
					local ToggleFunctions = {}
					ToggleFunctions.Class = "Toggle"
					local toggled = ToggleSettings.Default or false
					ToggleFunctions.State = toggled
					
					local toggle = Instance.new("Frame")
					toggle.Name = "Toggle"
					toggle.AutomaticSize = Enum.AutomaticSize.Y
					toggle.BackgroundTransparency = 1
					toggle.Size = UDim2.new(1, 0, 0, 38)
					
					local togglePad = Instance.new("UIPadding")
					togglePad.PaddingLeft = UDim.new(0, 10)
					togglePad.PaddingRight = UDim.new(0, 10)
					togglePad.Parent = toggle
					
					local toggleList = Instance.new("UIListLayout")
					toggleList.Padding = UDim.new(0, 10)
					toggleList.FillDirection = Enum.FillDirection.Horizontal
					toggleList.SortOrder = Enum.SortOrder.LayoutOrder
					toggleList.VerticalAlignment = Enum.VerticalAlignment.Center
					toggleList.Parent = toggle
					
					local toggleName = Instance.new("TextLabel")
					toggleName.Name = "ToggleName"
					toggleName.FontFace = Font.new(assets.interFont)
					toggleName.Text = ToggleSettings.Name
					toggleName.RichText = true
					toggleName.TextColor3 = Color3.fromRGB(255, 255, 255)
					toggleName.TextSize = 13
					toggleName.TextTransparency = 0.5
					toggleName.TextTruncate = Enum.TextTruncate.SplitWord
					toggleName.TextXAlignment = Enum.TextXAlignment.Left
					toggleName.AnchorPoint = Vector2.new(0, 0.5)
					toggleName.AutomaticSize = Enum.AutomaticSize.Y
					toggleName.BackgroundTransparency = 1
					toggleName.Size = UDim2.new(1, -40, 0, 0)
					toggleName.Parent = toggle
					
					local toggleFrame = Instance.new("ImageButton")
					toggleFrame.Name = "ToggleFrame"
					toggleFrame.Image = assets.toggleBackground
					toggleFrame.ImageColor3 = Color3.fromRGB(45, 45, 45)
					toggleFrame.ScaleType = Enum.ScaleType.Slice
					toggleFrame.SliceCenter = Rect.new(4, 4, 4, 4)
					toggleFrame.AnchorPoint = Vector2.new(1, 0.5)
					toggleFrame.BackgroundTransparency = 1
					toggleFrame.Position = UDim2.fromScale(1, 0.5)
					toggleFrame.Size = UDim2.fromOffset(30, 17)
					toggleFrame.Parent = toggle
					
					local tfCorner = Instance.new("UICorner")
					tfCorner.CornerRadius = UDim.new(0, 4)
					tfCorner.Parent = toggleFrame
					
					local togglerHead = Instance.new("ImageLabel")
					togglerHead.Name = "TogglerHead"
					togglerHead.Image = assets.togglerHead
					togglerHead.ImageColor3 = Color3.fromRGB(255, 255, 255)
					togglerHead.ScaleType = Enum.ScaleType.Slice
					togglerHead.SliceCenter = Rect.new(10, 10, 10, 10)
					togglerHead.AnchorPoint = Vector2.new(0, 0.5)
					togglerHead.BackgroundTransparency = 1
					togglerHead.Position = UDim2.fromScale(0.08, 0.5)
					togglerHead.Size = UDim2.fromOffset(13, 13)
					togglerHead.Parent = toggleFrame
					
					local thCorner = Instance.new("UICorner")
					thCorner.CornerRadius = UDim.new(0, 4)
					thCorner.Parent = togglerHead
					
					local function Toggle(State)
						toggled = State
						ToggleFunctions.State = toggled
						if toggled then
							Tween(togglerHead, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {Position = UDim2.fromScale(0.53, 0.5)}):Play()
							Tween(toggleFrame, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
						else
							Tween(togglerHead, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {Position = UDim2.fromScale(0.08, 0.5)}):Play()
							Tween(toggleFrame, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {ImageColor3 = Color3.fromRGB(45, 45, 45)}):Play()
						end
						if ToggleSettings.Callback then
							task.spawn(function() ToggleSettings.Callback(toggled) end)
						end
					end
					
					Toggle(ToggleSettings.Default or false)
					
					toggleFrame.MouseButton1Click:Connect(function()
						toggled = not toggled
						Toggle(toggled)
					end)
					
					toggle.Parent = section
					
					function ToggleFunctions:UpdateName(New)
						toggleName.Text = New
					end
					function ToggleFunctions:UpdateState(New)
						Toggle(New)
					end
					function ToggleFunctions:SetVisibility(State)
						toggle.Visible = State
					end
					
					if Flag then
						MacLib.Options[Flag] = ToggleFunctions
					end
					return ToggleFunctions
				end
				
				function SectionFunctions:Slider(SliderSettings, Flag)
					local SliderFunctions = {}
					SliderFunctions.Class = "Slider"
					
					local slider = Instance.new("Frame")
					slider.Name = "Slider"
					slider.AutomaticSize = Enum.AutomaticSize.Y
					slider.BackgroundTransparency = 1
					slider.Size = UDim2.new(1, 0, 0, 38)
					
					local sliderPad = Instance.new("UIPadding")
					sliderPad.PaddingLeft = UDim.new(0, 10)
					sliderPad.PaddingRight = UDim.new(0, 10)
					sliderPad.Parent = slider
					
					local sliderList = Instance.new("UIListLayout")
					sliderList.Padding = UDim.new(0, 5)
					sliderList.SortOrder = Enum.SortOrder.LayoutOrder
					sliderList.Parent = slider
					
					local sliderName = Instance.new("TextLabel")
					sliderName.Name = "SliderName"
					sliderName.FontFace = Font.new(assets.interFont)
					sliderName.Text = SliderSettings.Name
					sliderName.RichText = true
					sliderName.TextColor3 = Color3.fromRGB(255, 255, 255)
					sliderName.TextSize = 13
					sliderName.TextTransparency = 0.5
					sliderName.TextTruncate = Enum.TextTruncate.SplitWord
					sliderName.TextXAlignment = Enum.TextXAlignment.Left
					sliderName.AutomaticSize = Enum.AutomaticSize.Y
					sliderName.BackgroundTransparency = 1
					sliderName.Size = UDim2.new(1, 0, 0, 0)
					sliderName.Parent = slider
					
					local sliderValue = Instance.new("TextLabel")
					sliderValue.Name = "SliderValue"
					sliderValue.FontFace = Font.new(assets.interFont)
					sliderValue.Text = tostring(SliderSettings.Default or SliderSettings.Minimum)
					sliderValue.RichText = true
					sliderValue.TextColor3 = Color3.fromRGB(255, 255, 255)
					sliderValue.TextSize = 13
					sliderValue.TextTransparency = 0.3
					sliderValue.TextTruncate = Enum.TextTruncate.SplitWord
					sliderValue.TextXAlignment = Enum.TextXAlignment.Right
					sliderValue.AutomaticSize = Enum.AutomaticSize.Y
					sliderValue.BackgroundTransparency = 1
					sliderValue.Size = UDim2.new(1, 0, 0, 0)
					sliderValue.Parent = slider
					
					local sliderBar = Instance.new("ImageButton")
					sliderBar.Name = "SliderBar"
					sliderBar.Image = assets.sliderbar
					sliderBar.ImageColor3 = Color3.fromRGB(45, 45, 45)
					sliderBar.ScaleType = Enum.ScaleType.Slice
					sliderBar.SliceCenter = Rect.new(4, 4, 4, 4)
					sliderBar.BackgroundTransparency = 1
					sliderBar.LayoutOrder = 2
					sliderBar.Size = UDim2.new(1, 0, 0, 6)
					sliderBar.Parent = slider
					
					local sbCorner = Instance.new("UICorner")
					sbCorner.CornerRadius = UDim.new(0, 3)
					sbCorner.Parent = sliderBar
					
					local sliderHead = Instance.new("ImageLabel")
					sliderHead.Name = "SliderHead"
					sliderHead.Image = assets.sliderhead
					sliderHead.ImageColor3 = Color3.fromRGB(255, 255, 255)
					sliderHead.ScaleType = Enum.ScaleType.Slice
					sliderHead.SliceCenter = Rect.new(4, 4, 4, 4)
					sliderHead.AnchorPoint = Vector2.new(0.5, 0.5)
					sliderHead.BackgroundTransparency = 1
					sliderHead.Position = UDim2.fromScale(0, 0.5)
					sliderHead.Size = UDim2.fromOffset(10, 10)
					sliderHead.Parent = sliderBar
					
					local dragging = false
					local function moveHead(Input)
						local pos = math.clamp((Input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
						local value = math.floor(SliderSettings.Minimum + (pos * (SliderSettings.Maximum - SliderSettings.Minimum)))
						if SliderSettings.Precision then
							value = math.floor(value * (10 ^ SliderSettings.Precision)) / (10 ^ SliderSettings.Precision)
						end
						sliderHead.Position = UDim2.fromScale(pos, 0.5)
						sliderValue.Text = tostring(value)
						if SliderSettings.Callback then
							task.spawn(function() SliderSettings.Callback(value) end)
						end
						SliderFunctions.Value = value
					end
					
					sliderBar.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							dragging = true
							moveHead(input)
						end
					end)
					
					UserInputService.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							dragging = false
						end
					end)
					
					UserInputService.InputChanged:Connect(function(input)
						if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
							moveHead(input)
						end
					end)
					
					slider.Parent = section
					
					function SliderFunctions:UpdateName(New)
						sliderName.Text = New
					end
					function SliderFunctions:UpdateValue(New)
						local pos = (New - SliderSettings.Minimum) / (SliderSettings.Maximum - SliderSettings.Minimum)
						sliderHead.Position = UDim2.fromScale(pos, 0.5)
						sliderValue.Text = tostring(New)
						SliderFunctions.Value = New
					end
					function SliderFunctions:SetVisibility(State)
						slider.Visible = State
					end
					
					if SliderSettings.Default then
						SliderFunctions:UpdateValue(SliderSettings.Default)
					end
					
					if Flag then
						MacLib.Options[Flag] = SliderFunctions
					end
					return SliderFunctions
				end
				
				-- [Additional functions would continue here: Input, Dropdown, Keybind, Header, Label, SubLabel, Paragraph, Divider, Spacer]
				-- For brevity, I'll include the essential ones:
				
				function SectionFunctions:Input(InputSettings, Flag)
					local InputFunctions = {}
					InputFunctions.Class = "Input"
					InputFunctions.Text = InputSettings.Default or ""
					
					local input = Instance.new("Frame")
					input.Name = "Input"
					input.AutomaticSize = Enum.AutomaticSize.Y
					input.BackgroundTransparency = 1
					input.Size = UDim2.new(1, 0, 0, 38)
					
					local inputPad = Instance.new("UIPadding")
					inputPad.PaddingLeft = UDim.new(0, 10)
					inputPad.PaddingRight = UDim.new(0, 10)
					inputPad.Parent = input
					
					local inputList = Instance.new("UIListLayout")
					inputList.Padding = UDim.new(0, 5)
					inputList.SortOrder = Enum.SortOrder.LayoutOrder
					inputList.Parent = input
					
					local inputName = Instance.new("TextLabel")
					inputName.Name = "InputName"
					inputName.FontFace = Font.new(assets.interFont)
					inputName.Text = InputSettings.Name
					inputName.RichText = true
					inputName.TextColor3 = Color3.fromRGB(255, 255, 255)
					inputName.TextSize = 13
					inputName.TextTransparency = 0.5
					inputName.TextTruncate = Enum.TextTruncate.SplitWord
					inputName.TextXAlignment = Enum.TextXAlignment.Left
					inputName.AutomaticSize = Enum.AutomaticSize.Y
					inputName.BackgroundTransparency = 1
					inputName.Size = UDim2.new(1, 0, 0, 0)
					inputName.Parent = input
					
					local inputBox = Instance.new("TextBox")
					inputBox.Name = "InputBox"
					inputBox.FontFace = Font.new(assets.interFont)
					inputBox.Text = InputSettings.Default or ""
					inputBox.PlaceholderText = InputSettings.Placeholder or ""
					inputBox.PlaceholderColor3 = Color3.fromRGB(255, 255, 255)
					inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
					inputBox.TextSize = 13
					inputBox.TextTransparency = 0.3
					inputBox.TextTruncate = Enum.TextTruncate.AtEnd
					inputBox.TextXAlignment = Enum.TextXAlignment.Left
					inputBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
					inputBox.LayoutOrder = 2
					inputBox.Size = UDim2.new(1, 0, 0, 30)
					inputBox.ClearTextOnFocus = false
					inputBox.Parent = input
					
					local ibCorner = Instance.new("UICorner")
					ibCorner.CornerRadius = UDim.new(0, 6)
					ibCorner.Parent = inputBox
					
					inputBox.FocusLost:Connect(function()
						InputFunctions.Text = inputBox.Text
						if InputSettings.Callback then
							task.spawn(function() InputSettings.Callback(inputBox.Text) end)
						end
					end)
					
					input.Parent = section
					
					function InputFunctions:UpdateName(New)
						inputName.Text = New
					end
					function InputFunctions:UpdateText(New)
						inputBox.Text = New
						InputFunctions.Text = New
					end
					function InputFunctions:SetVisibility(State)
						input.Visible = State
					end
					
					if Flag then
						MacLib.Options[Flag] = InputFunctions
					end
					return InputFunctions
				end
				
				function SectionFunctions:Header(Settings, Flag)
					local HeaderFunctions = {Settings = Settings}
					
					local header = Instance.new("Frame")
					header.Name = "Header"
					header.AutomaticSize = Enum.AutomaticSize.Y
					header.BackgroundTransparency = 1
					header.LayoutOrder = 0
					header.Size = UDim2.fromScale(1, 0)
					header.Parent = section
					
					local hPad = Instance.new("UIPadding")
					hPad.PaddingBottom = UDim.new(0, 5)
					hPad.Parent = header
					
					local headerText = Instance.new("TextLabel")
					headerText.Name = "HeaderText"
					headerText.FontFace = Font.new(assets.interFont, Enum.FontWeight.Medium)
					headerText.RichText = true
					headerText.Text = Settings.Text or Settings.Name
					headerText.TextColor3 = Color3.fromRGB(255, 255, 255)
					headerText.TextSize = 16
					headerText.TextTransparency = 0.3
					headerText.TextWrapped = true
					headerText.TextXAlignment = Enum.TextXAlignment.Left
					headerText.AutomaticSize = Enum.AutomaticSize.Y
					headerText.BackgroundTransparency = 1
					headerText.Size = UDim2.fromScale(1, 0)
					headerText.Parent = header
					
					function HeaderFunctions:UpdateName(New)
						headerText.Text = New
					end
					function HeaderFunctions:SetVisibility(State)
						header.Visible = State
					end
					
					if Flag then
						MacLib.Options[Flag] = HeaderFunctions
					end
					return HeaderFunctions
				end
				
				function SectionFunctions:Paragraph(Settings, Flag)
					local ParagraphFunctions = {Settings = Settings}
					
					local paragraph = Instance.new("Frame")
					paragraph.Name = "Paragraph"
					paragraph.AutomaticSize = Enum.AutomaticSize.Y
					paragraph.BackgroundTransparency = 1
					paragraph.Size = UDim2.new(1, 0, 0, 38)
					paragraph.Parent = section
					
					local pHeader = Instance.new("TextLabel")
					pHeader.Name = "ParagraphHeader"
					pHeader.FontFace = Font.new(assets.interFont, Enum.FontWeight.Medium)
					pHeader.RichText = true
					pHeader.Text = Settings.Header
					pHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
					pHeader.TextSize = 15
					pHeader.TextTransparency = 0.4
					pHeader.TextWrapped = true
					pHeader.TextXAlignment = Enum.TextXAlignment.Left
					pHeader.AutomaticSize = Enum.AutomaticSize.Y
					pHeader.BackgroundTransparency = 1
					pHeader.Size = UDim2.fromScale(1, 0)
					pHeader.Parent = paragraph
					
					local pList = Instance.new("UIListLayout")
					pList.Padding = UDim.new(0, 5)
					pList.SortOrder = Enum.SortOrder.LayoutOrder
					pList.Parent = paragraph
					
					local pBody = Instance.new("TextLabel")
					pBody.Name = "ParagraphBody"
					pBody.FontFace = Font.new(assets.interFont)
					pBody.RichText = true
					pBody.Text = Settings.Body
					pBody.TextColor3 = Color3.fromRGB(255, 255, 255)
					pBody.TextSize = 13
					pBody.TextTransparency = 0.5
					pBody.TextWrapped = true
					pBody.TextXAlignment = Enum.TextXAlignment.Left
					pBody.AutomaticSize = Enum.AutomaticSize.Y
					pBody.BackgroundTransparency = 1
					pBody.LayoutOrder = 1
					pBody.Size = UDim2.fromScale(1, 0)
					pBody.Parent = paragraph
					
					function ParagraphFunctions:UpdateHeader(New)
						pHeader.Text = New
					end
					function ParagraphFunctions:UpdateBody(New)
						pBody.Text = New
					end
					function ParagraphFunctions:SetVisibility(State)
						paragraph.Visible = State
					end
					
					if Flag then
						MacLib.Options[Flag] = ParagraphFunctions
					end
					return ParagraphFunctions
				end
				
				return SectionFunctions
			end
			
			local function SelectCurrentTab()
				local easetime = 0.15
				if currentTabInstance then
					currentTabInstance.Parent = nil
				end
				
				for i, tabInfo in pairs(tabs) do
					Tween(i, TweenInfo.new(easetime, Enum.EasingStyle.Sine), {BackgroundTransparency = (i == tabSwitcher and 0.98 or 1)}):Play()
					if tabInfo.tabStroke then
						Tween(tabInfo.tabStroke, TweenInfo.new(easetime, Enum.EasingStyle.Sine), {Transparency = (i == tabSwitcher and 0.95 or 1)}):Play()
					end
					if tabInfo.switcherImage then
						Tween(tabInfo.switcherImage, TweenInfo.new(easetime, Enum.EasingStyle.Sine), {ImageTransparency = (i == tabSwitcher and 0.1 or 0.5)}):Play()
					end
					if tabInfo.switcherName then
						Tween(tabInfo.switcherName, TweenInfo.new(easetime, Enum.EasingStyle.Sine), {TextTransparency = (i == tabSwitcher and 0.1 or 0.5)}):Play()
					end
				end
				
				tabs[tabSwitcher].tabContent.Parent = content
				currentTabInstance = tabs[tabSwitcher].tabContent
			end
			
			tabSwitcher.MouseButton1Click:Connect(SelectCurrentTab)
			
			function TabFunctions:Select()
				SelectCurrentTab()
			end
			
			tabs[tabSwitcher] = {
				tabContent = elements1,
				tabStroke = tsStroke,
				switcherImage = tabImage,
				switcherName = tabSwitcherName,
			}
			
			return TabFunctions
		end
		
		return SectionFunctions
	end
	
	function WindowFunctions:Notify(Settings)
		local NotificationFunctions = {}
		
		local notification = Instance.new("Frame")
		notification.Name = "Notification"
		notification.AnchorPoint = Vector2.new(0.5, 0.5)
		notification.AutomaticSize = Enum.AutomaticSize.Y
		notification.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
		notification.Position = UDim2.fromScale(0.5, 0.5)
		notification.Size = UDim2.fromOffset(Settings.SizeX or 250, 0)
		notification.Parent = notifications
		
		local nStroke = Instance.new("UIStroke")
		nStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		nStroke.Color = Color3.fromRGB(255, 255, 255)
		nStroke.Transparency = 0.9
		nStroke.Parent = notification
		
		local nCorner = Instance.new("UICorner")
		nCorner.CornerRadius = UDim.new(0, 10)
		nCorner.Parent = notification
		
		local nScale = Instance.new("UIScale")
		nScale.Scale = 0
		nScale.Parent = notification
		
		local nInfo = Instance.new("Frame")
		nInfo.Name = "NotificationInformation"
		nInfo.AutomaticSize = Enum.AutomaticSize.Y
		nInfo.BackgroundTransparency = 1
		nInfo.Size = UDim2.fromScale(1, 1)
		
		local nTitle = Instance.new("TextLabel")
		nTitle.Name = "NotificationTitle"
		nTitle.FontFace = Font.new(assets.interFont, Enum.FontWeight.SemiBold)
		nTitle.RichText = true
		nTitle.Text = Settings.Title
		nTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
		nTitle.TextSize = 13
		nTitle.TextTransparency = 0.2
		nTitle.TextTruncate = Enum.TextTruncate.SplitWord
		nTitle.TextXAlignment = Enum.TextXAlignment.Left
		nTitle.TextYAlignment = Enum.TextYAlignment.Top
		nTitle.AutomaticSize = Enum.AutomaticSize.XY
		nTitle.BackgroundTransparency = 1
		nTitle.Size = UDim2.new(1, -12, 0, 0)
		nTitle.Parent = nInfo
		
		local nDesc = Instance.new("TextLabel")
		nDesc.Name = "NotificationDescription"
		nDesc.FontFace = Font.new(assets.interFont, Enum.FontWeight.Medium)
		nDesc.Text = Settings.Description
		nDesc.TextColor3 = Color3.fromRGB(255, 255, 255)
		nDesc.TextSize = 11
		nDesc.TextTransparency = 0.5
		nDesc.TextWrapped = true
		nDesc.RichText = true
		nDesc.TextXAlignment = Enum.TextXAlignment.Left
		nDesc.TextYAlignment = Enum.TextYAlignment.Top
		nDesc.AutomaticSize = Enum.AutomaticSize.XY
		nDesc.BackgroundTransparency = 1
		nDesc.Size = UDim2.new(1, -12, 0, 0)
		nDesc.Parent = nInfo
		
		local nPad = Instance.new("UIPadding")
		nPad.PaddingBottom = UDim.new(0, 12)
		nPad.PaddingLeft = UDim.new(0, 10)
		nPad.PaddingRight = UDim.new(0, 10)
		nPad.PaddingTop = UDim.new(0, 10)
		nPad.Parent = nInfo
		
		nInfo.Parent = notification
		
		Tween(nScale, TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Scale = Settings.Scale or 1}):Play()
		
		Settings.Lifetime = Settings.Lifetime or 3
		if Settings.Lifetime ~= 0 then
			task.delay(Settings.Lifetime, function()
				local out = Tween(nScale, TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Scale = 0})
				out:Play()
				out.Completed:Wait()
				notification:Destroy()
			end)
		end
		
		function NotificationFunctions:UpdateTitle(New)
			nTitle.Text = New
		end
		function NotificationFunctions:UpdateDescription(New)
			nDesc.Text = New
		end
		function NotificationFunctions:Cancel()
			notification:Destroy()
		end
		
		return NotificationFunctions
	end
	
	function WindowFunctions:SetNotificationsState(State)
		notifications.Visible = State
	end
	function WindowFunctions:GetNotificationsState()
		return notifications.Visible
	end
	function WindowFunctions:SetState(State)
		windowState = State
		base.Visible = State
	end
	function WindowFunctions:GetState()
		return windowState
	end
	function WindowFunctions:Unload()
		macLib:Destroy()
		unloaded = true
	end
	function WindowFunctions:SetAcrylicBlurState(State)
		acrylicBlur = State
		base.BackgroundTransparency = State and 0.05 or 0
	end
	function WindowFunctions:GetAcrylicBlurState()
		return acrylicBlur
	end
	function WindowFunctions:SetUserInfoState(State)
		-- Stub
	end
	function WindowFunctions:GetUserInfoState()
		return true
	end
	function WindowFunctions:SetSize(Size)
		base.Size = Size
	end
	function WindowFunctions:GetSize()
		return base.Size
	end
	function WindowFunctions:SetScale(Scale)
		baseUIScale.Scale = Scale
	end
	function WindowFunctions:GetScale()
		return baseUIScale.Scale
	end
	
	local MenuKeybind = Settings.Keybind or Enum.KeyCode.RightControl
	local function ToggleMenu()
		local state = not WindowFunctions:GetState()
		WindowFunctions:SetState(state)
		WindowFunctions:Notify({
			Title = Settings.Title,
			Description = (state and "Maximized " or "Minimized ") .. "the menu. Use " .. tostring(MenuKeybind.Name) .. " to toggle it.",
			Lifetime = 5
		})
	end
	
	UserInputService.InputEnded:Connect(function(inp, gpe)
		if gpe then return end
		if inp.KeyCode == MenuKeybind then
			ToggleMenu()
		end
	end)
	
	minimize.MouseButton1Click:Connect(ToggleMenu)
	exit.MouseButton1Click:Connect(function()
		WindowFunctions:Unload()
	end)
	
	macLib.Enabled = false
	local assetList = {}
	for _, assetId in pairs(assets) do
		table.insert(assetList, assetId)
	end
	ContentProvider:PreloadAsync(assetList)
	macLib.Enabled = true
	windowState = true
	
	return WindowFunctions
end

return MacLib
