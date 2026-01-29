local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local ALIVE = true

-- Configuration
local PLAYER = Players.LocalPlayer
local PLAYER_GUI = PLAYER:WaitForChild("PlayerGui")
local FONT = Enum.Font.SourceSans
local FONT_BOLD = Enum.Font.SourceSansBold

if PLAYER_GUI:FindFirstChild("Any_Item_ESP") then
	PLAYER_GUI.Any_Item_ESP:Destroy()
	task.wait(0.1) -- Allow old threads to cleanup
end

local SETTINGS = {
	MaxHighlights = 50,
	-- RainbowMode = true, -- REMOVED GLOBAL
	ShowNames = true,
	MaxTotalObjects = 1000
}


-- State
local rootDirectory = Workspace
local expandedNodes = {} -- { [Instance] = boolean }
local espTargets = {} -- { [Instance] = boolean } (Manual Toggles)
local targetSettings = {} -- { [Instance] = { Color = Color3, Rainbow = boolean } }
local watchedFolders = {} -- { [Instance] = Connection } (Folder Watch)
local espObjects = {} -- { [Instance] = {GUI, Highlight, Instance, Source} }
local activeHighlights = {} -- List of instances with active Highlights
local searchText = ""
local currentTab = "Explorer" -- "Explorer", "Active", "Settings"
local isRendering = false
local renderRequest = 0
local searchDebounceToken = 0

-- Connection Manager (fixes that humongous memory leak)
local connections = {}
local function addConnection(conn)
	table.insert(connections, conn)
	return conn
end

-- Centralized Drag Manager because why not
local activeDrag = nil -- { callback, onEnd }

-- Icons (these suck, change them soon)
local ICONS = {
	Folder = "📁",
	Model = "📦",
	Part = "🧱",
	MeshPart = "🗿",
	Script = "📜",
	LocalScript = "📝",
	Unknown = "📄",
	EyeOn = "🟢",
	EyeOff = "👁️",
	Settings = "⚙️"
}

-- Cleanup (unload script) Function
local function UnloadScript(screenGui)
	ALIVE = false
	if screenGui then screenGui:Destroy() end
	
	-- Cleanup ESPs
	for inst, objs in pairs(espObjects) do
		if objs.GUI then objs.GUI:Destroy() end
		if objs.Highlight then objs.Highlight:Destroy() end
	end
	
	-- Cleanup Watched Folder Connections
	for _, conn in pairs(watchedFolders) do
		if conn then conn:Disconnect() end
	end
	
	-- Cleanup ALL tracked connections (fixes the other memory leak)
	for _, conn in ipairs(connections) do
		if conn and conn.Connected then conn:Disconnect() end
	end
	
	table.clear(connections)
	table.clear(espObjects)
	table.clear(activeHighlights)
	table.clear(watchedFolders)
	table.clear(espTargets)
end

-- GUI Creation
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Any_Item_ESP"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PLAYER_GUI

-- Modern UI Helper
local function addCorners(element, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = element
	return corner
end

local function addStroke(element, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(60, 60, 60)
	stroke.Thickness = thickness or 1
	stroke.Parent = element
	return stroke
end

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 340, 0, 480)
mainFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
addCorners(mainFrame, 8)
addStroke(mainFrame, Color3.fromRGB(50, 50, 55), 2)

-- Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 32)
header.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
header.BorderSizePixel = 0
header.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -70, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "  🔍 Explorer"
titleLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Font = FONT_BOLD
titleLabel.TextSize = 15
titleLabel.Parent = header

-- Header Buttons
local minButton = Instance.new("TextButton")
minButton.Name = "Minimize"
minButton.Size = UDim2.new(0, 28, 0, 22)
minButton.Position = UDim2.new(1, -33, 0, 5)
minButton.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
minButton.BorderSizePixel = 0
minButton.Text = "−"
minButton.TextColor3 = Color3.new(1, 1, 1)
minButton.Font = FONT_BOLD
minButton.TextSize = 16
minButton.Parent = header
addCorners(minButton, 4)

local settingsButton = Instance.new("TextButton")
settingsButton.Name = "Settings"
settingsButton.Size = UDim2.new(0, 28, 0, 22)
settingsButton.Position = UDim2.new(1, -65, 0, 5)
settingsButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
settingsButton.BorderSizePixel = 0
settingsButton.Text = ICONS.Settings
settingsButton.TextColor3 = Color3.new(1, 1, 1)
settingsButton.Font = FONT
settingsButton.TextSize = 14
settingsButton.Parent = header
addCorners(settingsButton, 4)

-- Tab Bar
local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(1, 0, 0, 28)
tabBar.Position = UDim2.new(0, 0, 0, 32)
tabBar.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame

local function createTabBtn(name, order)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0.5, -4, 0, 22)
	btn.Position = UDim2.new((order - 1) * 0.5, 4, 0, 3)
	btn.BackgroundColor3 = order == 1 and Color3.fromRGB(60, 130, 180) or Color3.fromRGB(50, 50, 58)
	btn.BorderSizePixel = 0
	btn.Text = name
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = FONT_BOLD
	btn.TextSize = 13
	btn.Parent = tabBar
	addCorners(btn, 4)
	return btn
end

local tabExplorer = createTabBtn("Explorer", 1)
local tabActive = createTabBtn("Active", 2)

-- Status Bar (bottom)
local statusBar = Instance.new("Frame")
statusBar.Name = "StatusBar"
statusBar.Size = UDim2.new(1, 0, 0, 22)
statusBar.Position = UDim2.new(0, 0, 1, -22)
statusBar.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
statusBar.BorderSizePixel = 0
statusBar.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusText"
statusLabel.Size = UDim2.new(1, -10, 1, 0)
statusLabel.Position = UDim2.new(0, 5, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "ESP: 0 | Highlights: 0/" .. SETTINGS.MaxHighlights
statusLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Font = FONT
statusLabel.TextSize = 11
statusLabel.Parent = statusBar

local function updateStatusBar()
	local espCount = 0
	for _ in pairs(espObjects) do espCount = espCount + 1 end
	statusLabel.Text = string.format("ESP: %d | Highlights: %d/%d | Watching: %d folders", 
		espCount, #activeHighlights, SETTINGS.MaxHighlights, 
		(function() local c = 0 for _ in pairs(watchedFolders) do c = c + 1 end return c end)())
end

-- Content Area
local contentArea = Instance.new("Frame")
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, 0, 1, -82) -- Header(32) + TabBar(28) + StatusBar(22) = 82
contentArea.Position = UDim2.new(0, 0, 0, 60)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

-- Explorer
local searchBox = Instance.new("TextBox")
searchBox.Name = "Search"
searchBox.Size = UDim2.new(1, -16, 0, 26)
searchBox.Position = UDim2.new(0, 8, 0, 6)
searchBox.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
searchBox.BorderSizePixel = 0
searchBox.TextColor3 = Color3.fromRGB(220, 220, 225)
searchBox.PlaceholderText = "🔍 Search workspace..."
searchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 110)
searchBox.Text = ""
searchBox.Font = FONT
searchBox.TextSize = 13
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.Parent = contentArea
addCorners(searchBox, 4)
addStroke(searchBox, Color3.fromRGB(55, 55, 65), 1)

local explorerScroll = Instance.new("ScrollingFrame")
explorerScroll.Name = "ExplorerList"
explorerScroll.Size = UDim2.new(1, -8, 1, -40)
explorerScroll.Position = UDim2.new(0, 4, 0, 36)
explorerScroll.BackgroundTransparency = 1
explorerScroll.ScrollBarThickness = 5
explorerScroll.ScrollBarImageColor3 = Color3.fromRGB(70, 130, 180)
explorerScroll.Parent = contentArea

local explorerListLayout = Instance.new("UIListLayout")
explorerListLayout.Parent = explorerScroll
explorerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
explorerListLayout.Padding = UDim.new(0, 2)

-- Active List
local activeScroll = Instance.new("ScrollingFrame")
activeScroll.Name = "ActiveList"
activeScroll.Size = UDim2.new(1, -8, 1, -4)
activeScroll.Position = UDim2.new(0, 4, 0, 2)
activeScroll.BackgroundTransparency = 1
activeScroll.ScrollBarThickness = 5
activeScroll.ScrollBarImageColor3 = Color3.fromRGB(70, 130, 180)
activeScroll.Visible = false
activeScroll.Parent = contentArea

local activeListLayout = Instance.new("UIListLayout")
activeListLayout.Parent = activeScroll
activeListLayout.SortOrder = Enum.SortOrder.Name
activeListLayout.Padding = UDim.new(0, 4)

-- Settings Frame
local settingsFrame = Instance.new("Frame")
settingsFrame.Name = "SettingsFrame"
settingsFrame.Size = UDim2.new(1, 0, 1, -25) -- Below header
settingsFrame.Position = UDim2.new(0, 0, 0, 25)
settingsFrame.BackgroundColor3 = Color3.fromRGB(37, 37, 37)
settingsFrame.Visible = false
settingsFrame.ZIndex = 5 -- On top of everything
settingsFrame.Parent = mainFrame

-- Selection Settings UI
local selectionSettingsFrame = Instance.new("Frame")
selectionSettingsFrame.Name = "SelectionSettings"
selectionSettingsFrame.Size = UDim2.new(1, 0, 1, -25)
selectionSettingsFrame.Position = UDim2.new(0, 0, 0, 25)
selectionSettingsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
selectionSettingsFrame.Visible = false
selectionSettingsFrame.ZIndex = 6
selectionSettingsFrame.Parent = mainFrame

local selTitle = Instance.new("TextLabel")
selTitle.Size = UDim2.new(1, -30, 0, 25)
selTitle.Position = UDim2.new(0, 10, 0, 5)
selTitle.BackgroundTransparency = 1
selTitle.Text = "Selection Settings"
selTitle.TextColor3 = Color3.new(1, 1, 1)
selTitle.Font = FONT_BOLD
selTitle.TextSize = 16
selTitle.TextXAlignment = Enum.TextXAlignment.Left
selTitle.Parent = selectionSettingsFrame

local closeSelBtn = Instance.new("TextButton")
closeSelBtn.Size = UDim2.new(0, 25, 0, 25)
closeSelBtn.Position = UDim2.new(1, -30, 0, 5)
closeSelBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeSelBtn.Text = "X"
closeSelBtn.TextColor3 = Color3.new(1, 1, 1)
closeSelBtn.Font = FONT_BOLD
closeSelBtn.Parent = selectionSettingsFrame
closeSelBtn.MouseButton1Click:Connect(function()
	selectionSettingsFrame.Visible = false
end)

local currentSelection = nil -- The instance currently being edited

-- Helper for color sliders
local function createColorSlider(name, colorComp, yPos, callback)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 20, 0, 20)
	label.Position = UDim2.new(0, 10, 0, yPos)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = FONT_BOLD
	label.Parent = selectionSettingsFrame
	
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, -50, 0, 6)
	bg.Position = UDim2.new(0, 35, 0, yPos + 7)
	bg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	bg.BorderSizePixel = 0
	bg.Parent = selectionSettingsFrame
	
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = colorComp
	fill.BorderSizePixel = 0
	fill.Parent = bg
	
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 10)
	btn.Position = UDim2.new(0, 0, 0, -5)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = bg
	
	return {Fill = fill, Btn = btn, Bg = bg}
end

local rSlider = createColorSlider("R", Color3.fromRGB(255, 0, 0), 40, function(val) end)
local gSlider = createColorSlider("G", Color3.fromRGB(0, 255, 0), 70, function(val) end)
local bSlider = createColorSlider("B", Color3.fromRGB(0, 0, 255), 100, function(val) end)

local previewBox = Instance.new("Frame")
previewBox.Size = UDim2.new(0, 40, 0, 40)
previewBox.Position = UDim2.new(1, -60, 0, 40)
previewBox.BackgroundColor3 = Color3.new(1, 1, 1)
previewBox.Parent = selectionSettingsFrame

local rainbowToggleBtn = Instance.new("TextButton")
rainbowToggleBtn.Size = UDim2.new(1, -20, 0, 25)
rainbowToggleBtn.Position = UDim2.new(0, 10, 0, 140)
rainbowToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
rainbowToggleBtn.Text = "Rainbow Mode: OFF"
rainbowToggleBtn.TextColor3 = Color3.new(1, 1, 1)
rainbowToggleBtn.Font = FONT_BOLD
rainbowToggleBtn.Parent = selectionSettingsFrame

-- Update logic for selection UI
local function updateSelectionUI()
	if not currentSelection or not targetSettings[currentSelection] then return end
	local s = targetSettings[currentSelection]
	
	previewBox.BackgroundColor3 = s.Color
	rainbowToggleBtn.Text = s.Rainbow and "Rainbow Mode: ON" or "Rainbow Mode: OFF"
	rainbowToggleBtn.BackgroundColor3 = s.Rainbow and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(60, 60, 60)
	
	-- Update slider visual positions
	rSlider.Fill.Size = UDim2.new(s.Color.R, 0, 1, 0)
	gSlider.Fill.Size = UDim2.new(s.Color.G, 0, 1, 0)
	bSlider.Fill.Size = UDim2.new(s.Color.B, 0, 1, 0)
end

local function bindSlider(params, component)
	local function updateColor(mouseX)
		if not currentSelection then return end
		local s = targetSettings[currentSelection]
		if not s then return end
		
		local rel = (mouseX - params.Bg.AbsolutePosition.X) / params.Bg.AbsoluteSize.X
		local val = math.clamp(rel, 0, 1)
		
		local r, g, b = s.Color.R, s.Color.G, s.Color.B
		if component == "R" then r = val end
		if component == "G" then g = val end
		if component == "B" then b = val end
		
		s.Color = Color3.new(r, g, b)
		s.Rainbow = false
		updateSelectionUI()
	end
	
	params.Btn.MouseButton1Down:Connect(function()
		local mouse = PLAYER:GetMouse()
		updateColor(mouse.X)
		activeDrag = { component = component, params = params, updateFn = updateColor }
	end)
end

-- Global drag handlers (registered once, tracked for cleanup)
addConnection(UserInputService.InputChanged:Connect(function(input)
	if activeDrag and input.UserInputType == Enum.UserInputType.MouseMovement then
		activeDrag.updateFn(input.Position.X)
	end
end))

addConnection(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		activeDrag = nil
	end
end))

bindSlider(rSlider, "R")
bindSlider(gSlider, "G")
bindSlider(bSlider, "B")

rainbowToggleBtn.MouseButton1Click:Connect(function()
	if not currentSelection then return end
	local s = targetSettings[currentSelection]
	s.Rainbow = not s.Rainbow
	updateSelectionUI()
end)

local settingsListLayout = Instance.new("UIListLayout")
settingsListLayout.Parent = settingsFrame
settingsListLayout.SortOrder = Enum.SortOrder.LayoutOrder
settingsListLayout.Padding = UDim.new(0, 5)

local settingsPadding = Instance.new("UIPadding")
settingsPadding.Parent = settingsFrame
settingsPadding.PaddingTop = UDim.new(0, 5)
settingsPadding.PaddingLeft = UDim.new(0, 5)

-- Settings UI Elements
local function createSettingRow(text, order)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -10, 0, 30)
	-- row.Position handled by UIListLayout
	row.LayoutOrder = order
	row.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	row.BorderSizePixel = 0
	row.Parent = settingsFrame
	
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.6, 0, 1, 0)
	lbl.Position = UDim2.new(0, 5, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Font = FONT
	lbl.TextSize = 14
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row
	
	return row
end

-- 1. Unload
local unloadRow = createSettingRow("Unload Script", 1)
local unloadBtn = Instance.new("TextButton")
unloadBtn.Size = UDim2.new(0, 80, 0, 20)
unloadBtn.Position = UDim2.new(1, -85, 0, 5)
unloadBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
unloadBtn.Text = "UNLOAD"
unloadBtn.TextColor3 = Color3.new(1, 1, 1)
unloadBtn.Font = FONT_BOLD
unloadBtn.TextSize = 12
unloadBtn.Parent = unloadRow
unloadBtn.MouseButton1Click:Connect(function() UnloadScript(screenGui) end)

-- 2. Rejoin
local rejoinRow = createSettingRow("Rejoin Server", 2)
local rejoinBtn = Instance.new("TextButton")
rejoinBtn.Size = UDim2.new(0, 80, 0, 20)
rejoinBtn.Position = UDim2.new(1, -85, 0, 5)
rejoinBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
rejoinBtn.Text = "REJOIN"
rejoinBtn.TextColor3 = Color3.new(1, 1, 1)
rejoinBtn.Font = FONT_BOLD
rejoinBtn.TextSize = 12
rejoinBtn.Parent = rejoinRow
rejoinBtn.MouseButton1Click:Connect(function() 
	TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, PLAYER)
end)

-- 3. Max Highlights
local maxHighlightsRow = createSettingRow("Max Highlights", 3)
-- Slider Logic
local sliderBg = Instance.new("Frame")
sliderBg.Name = "SliderBg"
sliderBg.Size = UDim2.new(0, 80, 0, 6)
sliderBg.Position = UDim2.new(1, -95, 0.5, -3) -- Left a bit for text
sliderBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
sliderBg.BorderSizePixel = 0
sliderBg.Parent = maxHighlightsRow

local sliderFill = Instance.new("Frame")
sliderFill.Name = "SliderFill"
sliderFill.Size = UDim2.new(SETTINGS.MaxHighlights / 300, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBg

local valLabel = Instance.new("TextLabel")
valLabel.Name = "ValueLabel"
valLabel.Size = UDim2.new(0, 30, 1, 0)
valLabel.Position = UDim2.new(1, 5, 0.5, -10) -- To right of slider
valLabel.BackgroundTransparency = 1
valLabel.Text = tostring(SETTINGS.MaxHighlights)
valLabel.TextColor3 = Color3.new(1, 1, 1)
valLabel.Font = FONT
valLabel.TextSize = 12
valLabel.Parent = sliderBg

local sliderBtn = Instance.new("TextButton")
sliderBtn.Name = "SliderBtn"
sliderBtn.Size = UDim2.new(1, 0, 1, 10) -- Larger hit area
sliderBtn.Position = UDim2.new(0, 0, 0, -5)
sliderBtn.BackgroundTransparency = 1
sliderBtn.Text = ""
sliderBtn.Parent = sliderBg

local function updateSettingsSlider(mouseX)
	local rel = (mouseX - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
	local percent = math.clamp(rel, 0, 1)
	local val = math.floor(percent * 300)
	
	SETTINGS.MaxHighlights = val
	sliderFill.Size = UDim2.new(percent, 0, 1, 0)
	valLabel.Text = tostring(val)
end

sliderBtn.MouseButton1Down:Connect(function()
	local mouse = PLAYER:GetMouse()
	updateSettingsSlider(mouse.X)
	activeDrag = { component = "MaxHighlights", updateFn = updateSettingsSlider }
end)

-- 4. Rainbow Mode (REMOVED GLOBAL)
-- Kept empty or replaced/removed


-- Navigation Logic
local refreshActiveList, refreshTree

local function switchTab(tab)
	currentTab = tab
	settingsFrame.Visible = false
	if tab == "Explorer" then
		tabExplorer.BackgroundColor3 = Color3.fromRGB(60, 130, 180)
		tabActive.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
		explorerScroll.Visible = true
		searchBox.Visible = true
		activeScroll.Visible = false
		selectionSettingsFrame.Visible = false
		updateStatusBar()
	else
		tabExplorer.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
		tabActive.BackgroundColor3 = Color3.fromRGB(60, 130, 180)
		explorerScroll.Visible = false
		searchBox.Visible = false
		activeScroll.Visible = true
		selectionSettingsFrame.Visible = false
		refreshActiveList()
		updateStatusBar()
	end
end

settingsButton.MouseButton1Click:Connect(function()
	if currentTab == "Settings" then
		switchTab("Explorer") -- Toggle Back
	else
		currentTab = "Settings"
		settingsFrame.Visible = true
		explorerScroll.Visible = false
		searchBox.Visible = false
		activeScroll.Visible = false
		selectionSettingsFrame.Visible = false -- Close item settings when opening global settings
		tabExplorer.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
		tabActive.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
	end
end)
tabExplorer.MouseButton1Click:Connect(function() switchTab("Explorer") end)
tabActive.MouseButton1Click:Connect(function() switchTab("Active") end)

local isMinimized = false
local wasSelectionSettingsOpen = false

minButton.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	tabBar.Visible = not isMinimized
	contentArea.Visible = not isMinimized
	statusBar.Visible = not isMinimized
	
	if isMinimized then
		if selectionSettingsFrame.Visible then
			wasSelectionSettingsOpen = true
			selectionSettingsFrame.Visible = false
		else
			wasSelectionSettingsOpen = false
		end
		settingsFrame.Visible = false
		
		mainFrame.Size = UDim2.new(0, 340, 0, 32)
		minButton.Text = "+"
	else
		mainFrame.Size = UDim2.new(0, 340, 0, 480)
		minButton.Text = "−"
		if currentTab == "Settings" then 
			settingsFrame.Visible = true 
		else
			-- Restore selection settings if it was open and we are not in global settings
			if wasSelectionSettingsOpen then
				selectionSettingsFrame.Visible = true
			end
		end
	end
end)

-- ESP LOGIC

local function createEsp(instance, source)
	if not ALIVE then return end
	if espObjects[instance] then return end
	
	-- Object Cap Safety
	local totalObjects = 0
	-- Faster count?
	-- for _ in pairs(espObjects) do totalObjects = totalObjects + 1 end
	-- if totalObjects >= SETTINGS.MaxTotalObjects then return end
	-- (Optimization: Keep track of count separately if needed, but for now logic is same)

	for _ in pairs(espObjects) do totalObjects = totalObjects + 1 end
	if totalObjects >= SETTINGS.MaxTotalObjects then return end

	if instance == PLAYER.Character or instance:IsA("Camera") or instance:IsA("Terrain") then return end

	local rootPart = nil
	if instance:IsA("Model") then
		rootPart = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	elseif instance:IsA("BasePart") then
		rootPart = instance
	end
	
	if rootPart then
		local bg = Instance.new("BillboardGui")
		bg.Size = UDim2.new(0, 100, 0, 30)
		bg.AlwaysOnTop = true
		bg.Name = "ESPTag"
		
		local s = targetSettings[source]
		local color = s and s.Color or Color3.new(1, 0, 0)
		
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.new(1, 0, 1, 0)
		tl.BackgroundTransparency = 1
		tl.Text = instance.Name
		tl.Font = FONT_BOLD
		tl.TextSize = 14
		
		if s and s.Rainbow then
			-- Will be handled by loop
		else
			tl.TextColor3 = color
		end
		
		tl.TextStrokeTransparency = 0.5
		tl.Visible = SETTINGS.ShowNames
		tl.Parent = bg
		bg.Parent = rootPart
		
		local hl = nil
		if #activeHighlights < SETTINGS.MaxHighlights then
			hl = Instance.new("Highlight")
			hl.Adornee = instance
			hl.FillColor = color
			hl.OutlineColor = Color3.new(1, 1, 1)
			hl.FillTransparency = 0.6
			hl.Parent = PLAYER_GUI
			table.insert(activeHighlights, instance)
		else
			-- Recycle
			local old = table.remove(activeHighlights, 1)
			if espObjects[old] and espObjects[old].Highlight then
				espObjects[old].Highlight:Destroy()
				espObjects[old].Highlight = nil
			end
			hl = Instance.new("Highlight")
			hl.Adornee = instance
			hl.FillColor = color
			hl.OutlineColor = Color3.new(1, 1, 1)
			hl.FillTransparency = 0.6
			hl.Parent = PLAYER_GUI
			table.insert(activeHighlights, instance)
		end
		
		espObjects[instance] = { GUI = bg, Highlight = hl, Instance = instance, Label = tl, Source = source }
	end
end

local function removeEsp(instance)
	local objs = espObjects[instance]
	if objs then
		if objs.GUI then objs.GUI:Destroy() end
		if objs.Highlight then objs.Highlight:Destroy() end
		
		for i, inst in ipairs(activeHighlights) do
			if inst == instance then
				table.remove(activeHighlights, i)
				break
			end
		end
		espObjects[instance] = nil
	end
end

local function toggleEsp(instance, forceState)
	if not ALIVE then return end
	local newState
	if forceState ~= nil then newState = forceState else newState = not espTargets[instance] end
	
	if newState then 
		espTargets[instance] = true 
		-- Init settings if needed
		if not targetSettings[instance] then
			targetSettings[instance] = {
				Color = Color3.fromHSV(math.random(), 1, 1), -- Random color
				Rainbow = false
			}
		end
	else 
		espTargets[instance] = nil 
	end
	
	local isContainer = instance:IsA("Folder") or instance:IsA("Model")
	if isContainer then
		if newState then
			if not watchedFolders[instance] then
				for _, child in pairs(instance:GetChildren()) do
					if child:IsA("Model") or child:IsA("BasePart") then createEsp(child, instance) end
				end
				local conn = instance.ChildAdded:Connect(function(child)
					if not ALIVE then return end
					if child:IsA("Model") or child:IsA("BasePart") then
						task.defer(function() createEsp(child, instance) end)
					end
				end)
				watchedFolders[instance] = conn
			end
		else
			if watchedFolders[instance] then
				watchedFolders[instance]:Disconnect()
				watchedFolders[instance] = nil
				for _, child in pairs(instance:GetChildren()) do
					-- When removing container, check if child is not targeted individually?
					-- Simplification: Remove ESP if it maps to this source
					if espObjects[child] and espObjects[child].Source == instance then
						removeEsp(child)
					end
				end
			end
		end
	else
		-- Single
		if newState then createEsp(instance, instance) else removeEsp(instance) end
	end
	if currentTab == "Active" then refreshActiveList() end
end

-- RENDER Logic

local function getIcon(instance)
	if instance:IsA("Folder") then return ICONS.Folder end
	if instance:IsA("Model") then return ICONS.Model end
	if instance:IsA("MeshPart") then return ICONS.MeshPart end
	if instance:IsA("BasePart") then return ICONS.Part end
	if instance:IsA("Script") then return ICONS.Script end
	if instance:IsA("LocalScript") then return ICONS.LocalScript end
	return ICONS.Unknown
end

local function getEspState(instance)
	return espTargets[instance] or (watchedFolders[instance] ~= nil) or (espObjects[instance] ~= nil)
end

local function createRow(instance, depth, layoutOrder, parentFrame)
	local rowHeight = 20
	local row = Instance.new("Frame")
	row.Name = instance.Name
	row.Size = UDim2.new(1, 0, 0, rowHeight) -- Explicit Size Fix
	row.BackgroundTransparency = 1
	row.LayoutOrder = layoutOrder
	row.Parent = parentFrame
	
	local padding = depth * 20
	local isContainer = instance:IsA("Folder") or instance:IsA("Model")
	local hasChildren = #instance:GetChildren() > 0
	
	-- Expand
	local expandBtn = Instance.new("TextButton")
	expandBtn.Name = "Expand"
	expandBtn.Size = UDim2.new(0, 20, 1, 0)
	expandBtn.Position = UDim2.new(0, padding, 0, 0)
	expandBtn.BackgroundTransparency = 1
	expandBtn.Text = "" 
	if isContainer and hasChildren then
		expandBtn.Text = expandedNodes[instance] and "v" or ">"
	end
	expandBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
	expandBtn.Font = FONT
	expandBtn.TextSize = 14
	expandBtn.Parent = row
	
	expandBtn.MouseButton1Click:Connect(function()
		if isContainer then
			expandedNodes[instance] = not expandedNodes[instance]
			refreshTree()
		end
	end)
	
	-- Icon
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(0, 20, 1, 0)
	iconLabel.Position = UDim2.new(0, padding + 20, 0, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = getIcon(instance)
	iconLabel.TextSize = 14
	iconLabel.Parent = row
	
	-- Name
	local nameBtn = Instance.new("TextButton")
	nameBtn.Name = "Name"
	nameBtn.Size = UDim2.new(1, -(padding + 80), 1, 0)
	nameBtn.Position = UDim2.new(0, padding + 40, 0, 0)
	nameBtn.BackgroundTransparency = 1
	nameBtn.Text = instance.Name
	nameBtn.TextColor3 = Color3.fromRGB(204, 204, 204)
	nameBtn.TextXAlignment = Enum.TextXAlignment.Left
	nameBtn.Font = FONT
	nameBtn.TextSize = 14
	nameBtn.TextTruncate = Enum.TextTruncate.AtEnd
	nameBtn.Parent = row
	
	nameBtn.MouseButton1Click:Connect(function()
		if isContainer then
			expandedNodes[instance] = not expandedNodes[instance]
			refreshTree()
		end
	end)
	
	-- Toggle
	local isActive = getEspState(instance)
	
	local espBtn = Instance.new("TextButton")
	espBtn.Name = "EspToggle"
	espBtn.Size = UDim2.new(0, 30, 1, 0)
	espBtn.Position = UDim2.new(1, -30, 0, 0)
	espBtn.BackgroundTransparency = 1
	espBtn.Text = isActive and ICONS.EyeOn or ICONS.EyeOff
	espBtn.TextColor3 = Color3.new(1, 1, 1)
	espBtn.Font = FONT
	espBtn.TextSize = 14
	espBtn.Parent = row
	
	espBtn.MouseButton1Click:Connect(function()
		toggleEsp(instance)
		local newActive = getEspState(instance)
		espBtn.Text = newActive and ICONS.EyeOn or ICONS.EyeOff
	end)
	
	return row
end

local function buildFlatList(list, instance, depth)
	if not ALIVE then return end
	local query = searchText:lower()
	local matches = true
	if query ~= "" then
		if not instance.Name:lower():find(query) then matches = false end
	end
	
	local shouldShow = false
	if query ~= "" then
		if matches then shouldShow = true end
	else
		shouldShow = true
	end
	
	if shouldShow then
		table.insert(list, {Info = instance, Depth = depth})
	end
	
	if (query == "" and expandedNodes[instance]) or (query ~= "" and "always expand matches" and matches) then
		for _, child in pairs(instance:GetChildren()) do
			buildFlatList(list, child, depth + 1)
		end
	end
end

refreshTree = function()
	if not ALIVE then return end
	renderRequest = renderRequest + 1
	local myReq = renderRequest
	
	for _, c in pairs(explorerScroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	
	local flatList = {}
	for _, child in pairs(rootDirectory:GetChildren()) do
		buildFlatList(flatList, child, 0)
	end
	
	-- FIX: Explicitly set CanvasSize based on strict row height
	explorerScroll.CanvasSize = UDim2.new(0, 0, 0, #flatList * 20)
	
	task.spawn(function()
		local count = 0
		for _, node in ipairs(flatList) do
			if renderRequest ~= myReq or not ALIVE then return end
			createRow(node.Info, node.Depth, count, explorerScroll)
			count = count + 1
			if count % 100 == 0 then RunService.Heartbeat:Wait() end
		end
	end)
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	searchText = searchBox.Text
	searchDebounceToken = searchDebounceToken + 1
	local myToken = searchDebounceToken
	task.wait(0.3)
	-- Only refresh if this is still the latest search request
	if searchDebounceToken == myToken and ALIVE then 
		refreshTree() 
	end
end)

refreshActiveList = function()
	if not ALIVE then return end
	for _, c in pairs(activeScroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	
	local items = {}
	for inst, _ in pairs(espTargets) do table.insert(items, inst) end
	for inst, _ in pairs(watchedFolders) do 
		if not espTargets[inst] then table.insert(items, inst) end
	end
	
	table.sort(items, function(a,b) return a.Name < b.Name end)
	
	for _, inst in ipairs(items) do
		local row = Instance.new("Frame")
		row.Name = inst.Name
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
		row.BorderSizePixel = 0
		row.Parent = activeScroll
		addCorners(row, 4)
		
		local s = targetSettings[inst]
		local indColor = Instance.new("Frame")
		indColor.Size = UDim2.new(0, 4, 1, -8)
		indColor.Position = UDim2.new(0, 4, 0, 4)
		indColor.BackgroundColor3 = s and s.Color or Color3.new(1,1,1)
		indColor.BorderSizePixel = 0
		indColor.Parent = row
		addCorners(indColor, 2)
		
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -150, 1, 0)
		lbl.Position = UDim2.new(0, 14, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = inst.Name .. " (" .. inst.ClassName .. ")"
		lbl.TextColor3 = Color3.fromRGB(220, 220, 225)
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = FONT
		lbl.TextSize = 13
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		lbl.Parent = row
		
		-- Teleport Button
		local teleportBtn = Instance.new("TextButton")
		teleportBtn.Size = UDim2.new(0, 22, 0, 22)
		teleportBtn.Position = UDim2.new(1, -145, 0, 7)
		teleportBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 100)
		teleportBtn.BorderSizePixel = 0
		teleportBtn.Text = "📍"
		teleportBtn.TextColor3 = Color3.new(1, 1, 1)
		teleportBtn.Font = FONT
		teleportBtn.TextSize = 12
		teleportBtn.Parent = row
		addCorners(teleportBtn, 4)
		teleportBtn.MouseButton1Click:Connect(function()
			local char = PLAYER.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local targetPos
				if inst:IsA("Model") then
					local part = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
					if part then targetPos = part.Position end
				elseif inst:IsA("BasePart") then
					targetPos = inst.Position
				end
				if targetPos then
					char.HumanoidRootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0))
				end
			end
		end)
		
		-- Copy Path Button
		local copyBtn = Instance.new("TextButton")
		copyBtn.Size = UDim2.new(0, 22, 0, 22)
		copyBtn.Position = UDim2.new(1, -120, 0, 7)
		copyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
		copyBtn.BorderSizePixel = 0
		copyBtn.Text = "📋"
		copyBtn.TextColor3 = Color3.new(1, 1, 1)
		copyBtn.Font = FONT
		copyBtn.TextSize = 12
		copyBtn.Parent = row
		addCorners(copyBtn, 4)
		copyBtn.MouseButton1Click:Connect(function()
			local path = inst:GetFullName()
			if setclipboard then
				setclipboard(path)
			elseif Clipboard and Clipboard.set then
				Clipboard.set(path)
			end
			-- Visual feedback
			copyBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
			task.delay(0.5, function()
				if copyBtn and copyBtn.Parent then
					copyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
				end
			end)
		end)
		
		local setsBtn = Instance.new("TextButton")
		setsBtn.Size = UDim2.new(0, 22, 0, 22)
		setsBtn.Position = UDim2.new(1, -95, 0, 7)
		setsBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
		setsBtn.BorderSizePixel = 0
		setsBtn.Text = ICONS.Settings
		setsBtn.TextColor3 = Color3.new(1, 1, 1)
		setsBtn.Font = FONT
		setsBtn.TextSize = 12
		setsBtn.Parent = row
		addCorners(setsBtn, 4)
		setsBtn.MouseButton1Click:Connect(function()
			currentSelection = inst
			selTitle.Text = "Settings: " .. inst.Name
			selectionSettingsFrame.Visible = true
			updateSelectionUI()
		end)
		
		local removeBtn = Instance.new("TextButton")
		removeBtn.Size = UDim2.new(0, 60, 0, 22)
		removeBtn.Position = UDim2.new(1, -68, 0, 7)
		removeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
		removeBtn.BorderSizePixel = 0
		removeBtn.Text = "Remove"
		removeBtn.TextColor3 = Color3.new(1, 1, 1)
		removeBtn.Font = FONT_BOLD
		removeBtn.TextSize = 11
		removeBtn.Parent = row
		addCorners(removeBtn, 4)
		
		removeBtn.MouseButton1Click:Connect(function()
			toggleEsp(inst, false)
			refreshActiveList()
		end)
	end
	activeScroll.CanvasSize = UDim2.new(0, 0, 0, #items * 40) -- 36px row + 4px padding
end

-- Animation Loop
task.spawn(function()
	local updateCounter = 0
	while ALIVE and screenGui.Parent do
		local globalHue = (tick() % 5) / 5
		local rainbowColor = Color3.fromHSV(globalHue, 1, 1)
		
		-- Get player position for distance calc
		local playerPos = nil
		local char = PLAYER.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then playerPos = hrp.Position end
		end
		
		for inst, objs in pairs(espObjects) do
			if inst and inst.Parent then
				-- Resolve Settings
				local s = targetSettings[objs.Source]
				local color = s and s.Color or Color3.new(1,0,0)
				if s and s.Rainbow then color = rainbowColor end
				
				if objs.Label then 
					objs.Label.TextColor3 = color 
					
					-- Update distance display
					if playerPos and SETTINGS.ShowNames then
						local targetPos = nil
						if inst:IsA("Model") then
							local part = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
							if part then targetPos = part.Position end
						elseif inst:IsA("BasePart") then
							targetPos = inst.Position
						end
						if targetPos then
							local dist = math.floor((playerPos - targetPos).Magnitude)
							objs.Label.Text = inst.Name .. " [" .. dist .. "m]"
						else
							objs.Label.Text = inst.Name
						end
					end
				end
				if objs.Highlight then
					objs.Highlight.FillColor = color
					objs.Highlight.OutlineColor = color
				end
			else
				if espTargets[inst] then toggleEsp(inst, false) end
				removeEsp(inst)
			end
		end
		
		-- Animate rainbow preview box if needed
		if selectionSettingsFrame.Visible and currentSelection and targetSettings[currentSelection] then
			if targetSettings[currentSelection].Rainbow then
				previewBox.BackgroundColor3 = rainbowColor
			end
		end
		
		-- Update status bar periodically
		updateCounter = updateCounter + 1
		if updateCounter % 10 == 0 then
			updateStatusBar()
		end
		
		task.wait(0.1)
	end
end)

refreshTree()
updateStatusBar()