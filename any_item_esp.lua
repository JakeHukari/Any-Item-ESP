--ANY_ITEM_ESP
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local camera = Workspace.CurrentCamera
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

-- Global State for Cleanup
local ALIVE = true

-- Configuration
local PLAYER = Players.LocalPlayer
local PLAYER_GUI = PLAYER:WaitForChild("PlayerGui")
local FONT = Enum.Font.SourceSans
local FONT_BOLD = Enum.Font.SourceSansBold

-- Prevent duplicate
local globalEnv = getgenv and getgenv() or _G
if rawget(globalEnv, "AnyItemESP") then
	return warn("[Any_Item_ESP] Already loaded! Please close the existing GUI first.")
end

-- Init global
globalEnv.AnyItemESP = {
	Active = true,
}

-- Janitor Class for robust cleanup
local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
	return setmetatable({
		_tasks = {},
		_counter = 0
	}, Janitor)
end

function Janitor:Add(task, method, name)
	if name then
		self:Remove(name)
	end
	local key
	if name then
		key = name
	else
		self._counter = self._counter + 1
		key = self._counter
	end
	self._tasks[key] = {task, method}
	return task
end

function Janitor:Remove(name)
	local task = self._tasks[name]
	if task then
		self:_cleanupTask(task[1], task[2])
		self._tasks[name] = nil
	end
end

function Janitor:_cleanupTask(task, method)
	if type(task) == "function" then
		task()
	elseif method then
		task[method](task)
	elseif typeof(task) == "RBXScriptConnection" then
		task:Disconnect()
	elseif typeof(task) == "Instance" then
		task:Destroy()
	elseif task.Disconnect then
		task:Disconnect()
	elseif task.Destroy then
		task:Destroy()
	end
end

function Janitor:Cleanup()
	for key, task in pairs(self._tasks) do
		self:_cleanupTask(task[1], task[2])
	end
	table.clear(self._tasks)
end

-- Settings Defaults
local SETTINGS = {
	MaxHighlights = 100,
	ShowNames = true,
	MaxTotalObjects = 1000,
	MaxWatchedFolders = 100,
	VerticalOffset = 2,
	MaxDistance = 2500,
	MenuOpacity = 0.9,
	EspOpacity = 0.9
}

-- Game-Specific Templates
local GAME_TEMPLATES = {
	["2474168535"] = {
		{Path = "Animals", Color = Color3.fromRGB(255, 192, 203), TrackedProperties = {PeltQuality = true, AttackTarget = true}},
		{Path = "Items.Items.Ruby", Color = Color3.fromRGB(255, 0, 255)},
		{Path = "ChestFolder", Color = Color3.fromRGB(255, 255, 0), Rainbow = true, TrackedProperties = {Opened = true}},
		{Path = "Items.Items.Emerald", Color = Color3.fromRGB(255, 0, 255)},
		{Path = "Items.Items.Emerald", Color = Color3.fromRGB(255, 0, 255)},
		{Path = "Items.Items.Sapphire", Color = Color3.fromRGB(255, 0, 255)},
		{Path = "Items.InventoryBags", Color = Color3.fromRGB(0, 255, 255), TrackAll = true},
		{Path = "Items.Items.Diamond", Color = Color3.fromRGB(255, 0, 255)}
	},
	["18214855317"] = { -- SVNH_LFE
		{Path = "PickupableItemsFolder", Color = Color3.fromRGB(255, 0, 166), Rainbow = true, TrackedProperties = {CalculatedMass = true}},
		{Path = "PlayerEggNestsFolder", Color = Color3.fromRGB(0, 255, 249), Rainbow = true}
	},
	["3107097964"] = { -- NTRTY - DWNTWN_BNK
		{Path = "Citizens", Color = Color3.fromRGB(255, 192, 203)},
		{Path = "Police", Color = Color3.fromRGB(0, 114, 255), TrackedProperties = {RNGGroup = true, Variant = true}},
		{Path = "Map.KeyCard", Color = Color3.fromRGB(255, 165, 0), Rainbow = true},
		{Path = "Cameras", Color = Color3.fromRGB(255, 0, 0)}
	},
	["86300559848070"] = { -- NTRTY - DPOT
		{Path = "Map.Keys", Color = Color3.fromRGB(255, 255, 255), Rainbow = true},
		{Path = "Police", Color = Color3.fromRGB(0, 255, 255), TrackedProperties = {Appearance = true}}
	},
	["1242009557"] = { -- NTRTY - BRCK_BNK
		{Path = "Citizens", Color = Color3.fromRGB(255, 192, 203)},
		{Path = "Police", Color = Color3.fromRGB(0, 114, 255), TrackedProperties = {RNGGroup = true, Variant = true}},
		{Path = "Map.KeyCard", Color = Color3.fromRGB(255, 165, 0), Rainbow = true},
		{Path = "Cameras", Color = Color3.fromRGB(255, 0, 0)}
	},
	["104434907248230"] = { -- NTRTY - MDWLND_BNK
		{Path = "Citizens", Color = Color3.fromRGB(255, 192, 203)},
		{Path = "Police", Color = Color3.fromRGB(0, 114, 255), TrackedProperties = {RNGGroup = true, Variant = true}},
		{Path = "Map.KeyCard", Color = Color3.fromRGB(255, 165, 0), Rainbow = true},
		{Path = "Cameras", Color = Color3.fromRGB(255, 0, 0)}
	},
	["89087447777289"] = { -- NTRTY - ART_GLRY
		{Path = "Police", Color = Color3.fromRGB(0, 114, 255), TrackedProperties = {RNGGroup = true, Variant = true}},
		{Path = "Map.Lasers", Color = Color3.fromRGB(0, 213, 91)},
		{Path = "Map.PowerBoxes", Color = Color3.fromRGB(255, 255, 255)},
		{Path = "Citizens", Color = Color3.fromRGB(255, 192, 203)},
		{Path = "Cameras", Color = Color3.fromRGB(255, 0, 0)}
	},
	["2088934656"] = { -- NTRTY - SHDOW
		{Path = "Lootables.DepositGoldBar", Color = Color3.fromRGB(255, 165, 0)},
		{Path = "Map.EasterEggCrystal", Color = Color3.fromRGB(255, 255, 255), Rainbow = true},
		{Path = "Map.EasterEgg", Color = Color3.fromRGB(255, 255, 255), Rainbow = true},
		{Path = "Map.ShadowBoxes", Color = Color3.fromRGB(255, 165, 0)},
		{Path = "Police", Color = Color3.fromRGB(0, 114, 255), TrackedProperties = {RNGGroup = true, Variant = true}},
		{Path = "BigLoot", Color = Color3.fromRGB(255, 165, 0)},
		{Path = "Map.EasterEggBlueBook", Color = Color3.fromRGB(255, 255, 255), Rainbow = true},
		{Path = "Map.EasterEggCrystal", Color = Color3.fromRGB(255, 255, 255), Rainbow = true},
		{Path = "Citizens", Color = Color3.fromRGB(255, 255, 255)},
		{Path = "Map.EasterEggCrystal", Color = Color3.fromRGB(255, 255, 255), Rainbow = true},
		{Path = "Map.EasterEggCrystal", Color = Color3.fromRGB(255, 255, 255), Rainbow = true}
	},
	["1213821265"] = { -- NTRTY - RNB
		{Path = "Citizens", Color = Color3.fromRGB(255, 192, 203)},
		{Path = "Map.KeyCard", Color = Color3.fromRGB(255, 165, 0), Rainbow = true},
		{Path = "Police", Color = Color3.fromRGB(0, 114, 255), TrackedProperties = {RNGGroup = true, Variant = true}},
		{Path = "Cameras", Color = Color3.fromRGB(255, 0, 0)}
	},
	["1448835396"] = { -- NTRTY - DMND_STR
		{Path = "Citizens", Color = Color3.fromRGB(255, 255, 255)},
		{Path = "Police", Color = Color3.fromRGB(0, 114, 255), TrackedProperties = {RNGGroup = true, Variant = true}},
	},
	["93911318070665"] = { -- AR2
		{Path = "Vehicles", Color = Color3.fromRGB(255, 255, 255)},
		{Path = "Zombies", Color = Color3.fromRGB(255, 192, 203)}
	}
	-- Add more game templates here
}



-- State
local rootDirectory = Workspace
local expandedNodes = setmetatable({}, {__mode = "k"}) -- { [Instance] = boolean }
local espTargets = setmetatable({}, {__mode = "k"}) -- { [Instance] = boolean } (Manual Toggles)
local targetSettings = setmetatable({}, {__mode = "k"}) -- { [Instance] = { Color = Color3, Rainbow = boolean } }
local watchedFolders = setmetatable({}, {__mode = "k"}) -- { [Instance] = { ChildConn, DestroyConn, Janitor } } (Folder Watch)
local watchedFolderCount = 0
local espObjects = {} -- { [Instance] = {GUI, Highlight, Source, Root, Janitor, PropertyString, LastDistance, LastColor} }
local espObjectCount = 0
local highlightPool = {}
local billboardPool = {} -- Pool for caching and reusing BillboardGuis
local searchText = ""
local currentTab = "Explorer" -- "Explorer", "Active", "Settings"
local isRendering = false
local renderRequest = 0
local searchDebounceToken = 0
local isMinimized = false
local wasSelectionSettingsOpen = false
local toggleMinimize -- Forward declared

-- UI State & Pools (Forward Declared for UnloadScript)
local rowPool = {}
local activeRowPool = {}
local nodePool = {}
local activeRowConns = setmetatable({}, {__mode = "k"})
local rowToInstance = setmetatable({}, {__mode = "k"})
local currentFlatList = {}
local activeRows = {} 
local activeFlatList = {}
local activeTabRows = {}

-- Connection Manager (fixes memory leaks)
local connections = {} -- { [RBXScriptConnection] = true }
local function addConnection(conn)
	connections[conn] = true
	return conn
end

local function removeConnection(conn)
	if not conn then return end
	if conn.Connected then conn:Disconnect() end
	connections[conn] = nil
end

-- Centralized Drag Manager
local activeDrag = nil -- { callback, onEnd }

-- Icons
local ICONS = {
	Folder = "📂",
	Model = "📦",
	Part = "🧱",
	MeshPart = "🗿",
	Script = "📜",
	LocalScript = "📝",
	Unknown = "❔",
	EyeOn = "🟢",
	EyeOff = "🔴",
	Settings = "⚙️"
}

-- Color Presets
local COLOR_PRESETS = {
	{Name = "Red", Color = Color3.fromRGB(255, 0, 0)},
	{Name = "Green", Color = Color3.fromRGB(0, 255, 0)},
	{Name = "Blue", Color = Color3.fromRGB(0, 0, 255)},
	{Name = "Cyan", Color = Color3.fromRGB(0, 255, 255)},
	{Name = "Yellow", Color = Color3.fromRGB(255, 255, 0)},
	{Name = "Orange", Color = Color3.fromRGB(255, 165, 0)},
	{Name = "Magenta", Color = Color3.fromRGB(255, 0, 255)},
	{Name = "Pink", Color = Color3.fromRGB(255, 192, 203)},
	{Name = "White", Color = Color3.fromRGB(255, 255, 255)}
}

-- Cleanup Function
local function UnloadScript(screenGui)
	ALIVE = false
	if screenGui then screenGui:Destroy() end
	
	-- Cleanup ESPs via their Janitors, and destroy active Highlights
	for inst, objs in pairs(espObjects) do
		if objs.Highlight then
			objs.Highlight:Destroy()
		end
		if objs.Janitor then
			objs.Janitor:Cleanup()
		end
	end
	
	-- Cleanup Watched Folder Connections
	for inst, data in pairs(watchedFolders) do
		if data.Janitor then
			data.Janitor:Cleanup()
		end
	end
	
	-- Cleanup ALL tracked connections
	for conn in pairs(connections) do
		if conn.Connected then conn:Disconnect() end
	end
	
	-- Cleanup pooled row connections
	for row, conns in pairs(activeRowConns) do
		for _, conn in ipairs(conns) do
			if conn.Connected then conn:Disconnect() end
		end
	end
	
	-- Explicit Table Clearing to assist GC
	table.clear(connections)
	table.clear(espObjects)
	table.clear(watchedFolders)
	table.clear(espTargets)
	table.clear(targetSettings)
	table.clear(activeRowConns)
	table.clear(rowToInstance)
	for _, row in ipairs(activeRowPool) do row:Destroy() end
	table.clear(activeRowPool)
	for _, row in ipairs(rowPool) do row:Destroy() end
	table.clear(rowPool)
	table.clear(nodePool)
	
	-- Clean up Highlight Pool
	for _, hl in ipairs(highlightPool) do hl:Destroy() end
	table.clear(highlightPool)
	
	-- Clean up Billboard Pool
	for _, bg in ipairs(billboardPool) do bg:Destroy() end
	table.clear(billboardPool)
	
	table.clear(currentFlatList)
	table.clear(activeFlatList)
	table.clear(activeRows)
	table.clear(activeTabRows)
	currentSelection = nil
	
	watchedFolderCount = 0
	espObjectCount = 0

	-- Allow re-execution
	if rawget(globalEnv, "AnyItemESP") then
		globalEnv.AnyItemESP = nil
	end
end

-- GUI Creation
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Any_Item_ESP"
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999
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
mainFrame.Size = UDim2.new(0, 340, 0, 480) -- Fixed pixel size
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.fromScale(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = false
mainFrame.Parent = screenGui
addCorners(mainFrame, 8)
addStroke(mainFrame, Color3.fromRGB(50, 50, 55), 2)

-- Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 32) -- Fixed height
header.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
header.BorderSizePixel = 0
header.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -60, 1, 0) -- Subtract button space
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "  👁️ Any-Item-ESP"
titleLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Font = FONT_BOLD
titleLabel.TextSize = 15
titleLabel.Parent = header

-- Header Buttons (Square 22x22, offset aligned)
local minButton = Instance.new("TextButton")
minButton.Name = "Minimize"
minButton.Size = UDim2.new(0, 22, 0, 22)
minButton.Position = UDim2.new(1, -27, 0.5, -11)
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
settingsButton.Size = UDim2.new(0, 22, 0, 22)
settingsButton.Position = UDim2.new(1, -54, 0.5, -11)
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
tabBar.Size = UDim2.new(1, 0, 0, 28) -- Fixed height
tabBar.Position = UDim2.new(0, 0, 0, 32)
tabBar.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame

local function createTabBtn(name, order)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0.48, 0, 0.8, 0)
	btn.Position = UDim2.new((order - 1) * 0.5 + 0.01, 0, 0.1, 0)
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
statusBar.Size = UDim2.new(1, 0, 0, 22) -- Fixed height
statusBar.Position = UDim2.new(0, 0, 1, -22)
statusBar.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
statusBar.BorderSizePixel = 0
statusBar.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusText"
statusLabel.Size = UDim2.fromScale(0.55, 1)
statusLabel.Position = UDim2.fromScale(0.015, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "ESP: 0 | Highlights: 0/" .. SETTINGS.MaxHighlights
statusLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Font = FONT
statusLabel.TextSize = 11
statusLabel.Parent = statusBar

local gameIdLabel = Instance.new("TextLabel")
gameIdLabel.Name = "GameIdText"
gameIdLabel.Size = UDim2.fromScale(0.35, 1)
gameIdLabel.Position = UDim2.fromScale(0.57, 0)
gameIdLabel.BackgroundTransparency = 1
gameIdLabel.Text = "GameID - " .. tostring(game.PlaceId)
gameIdLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
gameIdLabel.TextXAlignment = Enum.TextXAlignment.Right
gameIdLabel.Font = FONT
gameIdLabel.TextSize = 11
gameIdLabel.Parent = statusBar

local gameIdCopyBtn = Instance.new("TextButton")
gameIdCopyBtn.Name = "GameIdCopyBtn"
gameIdCopyBtn.Size = UDim2.new(0, 20, 0, 18)
gameIdCopyBtn.Position = UDim2.new(1, -25, 0.5, -9)
gameIdCopyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
gameIdCopyBtn.BorderSizePixel = 0
gameIdCopyBtn.Text = "📋"
gameIdCopyBtn.TextColor3 = Color3.new(1, 1, 1)
gameIdCopyBtn.Font = FONT
gameIdCopyBtn.TextSize = 10
gameIdCopyBtn.Parent = statusBar
addCorners(gameIdCopyBtn, 4)

addConnection(gameIdCopyBtn.MouseButton1Click:Connect(function()
	local id = tostring(game.PlaceId)
	if setclipboard then setclipboard(id)
	elseif Clipboard and Clipboard.set then Clipboard.set(id) end
	
	gameIdCopyBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
	task.delay(0.5, function()
		if gameIdCopyBtn and gameIdCopyBtn.Parent then
			gameIdCopyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		end
	end)
end))

local function getRelativePath(instance)
	local path = instance:GetFullName()
	if path:sub(1, 10) == "Workspace." then
		return path:sub(11)
	end
	return path
end

local function resolvePath(root, path)
	local segments = string.split(path, ".")
	local current = root
	for _, segment in ipairs(segments) do
		current = current:WaitForChild(segment, 5)
		if not current then return nil end
	end
	return current
end

local function exportTemplate()
	local id = tostring(game.PlaceId)
	local activeItems = {}
	
	local seen = {}
	local function process(inst)
		if seen[inst] then return end
		seen[inst] = true
		
		local s = targetSettings[inst]
		if not s then return end
		
		local colorStr = string.format("Color3.fromRGB(%d, %d, %d)", math.floor(s.Color.R * 255), math.floor(s.Color.G * 255), math.floor(s.Color.B * 255))
		local rainbowStr = s.Rainbow and ", Rainbow = true" or ""
		local trackAllStr = s.TrackAll and ", TrackAll = true" or ""
		
		local propList = {}
		for propName, active in pairs(s.TrackedProperties) do
			if active then
				table.insert(propList, string.format("%s = true", propName))
			end
		end
		local propStr = #propList > 0 and (", TrackedProperties = {" .. table.concat(propList, ", ") .. "}") or ""
		
		table.insert(activeItems, string.format('\t\t{Path = "%s", Color = %s%s%s%s}', getRelativePath(inst), colorStr, rainbowStr, trackAllStr, propStr))
	end
	
	-- Prioritize espTargets, then watchedFolders
	for inst, _ in pairs(espTargets) do
		if inst:IsDescendantOf(game) then process(inst) end
	end
	for inst, _ in pairs(watchedFolders) do
		if inst:IsDescendantOf(game) then process(inst) end
	end
	
	local templateBody = table.concat(activeItems, ",\n")
	local fullTemplate = string.format('["%s"] = {\n%s\n\t},', id, templateBody)
	
	if setclipboard then setclipboard(fullTemplate)
	elseif Clipboard and Clipboard.set then Clipboard.set(fullTemplate) end
end

local function updateStatusBar()
	local highlightsCount = 0
	for _, objs in pairs(espObjects) do
		if objs.Highlight then
			highlightsCount = highlightsCount + 1
		end
	end
	
	local statusText = string.format("ESP: %d | Highlights: %d/%d | Watching: %d folders", 
		espObjectCount, highlightsCount, SETTINGS.MaxHighlights, watchedFolderCount)
	if statusLabel.Text ~= statusText then statusLabel.Text = statusText end
end

-- Content Area
local contentArea = Instance.new("Frame")
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, 0, 1, -82) -- 480 - 32 (header) - 28 (tabBar) - 22 (statusBar) = 398
contentArea.Position = UDim2.new(0, 0, 0, 60)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

-- Explorer
local searchBox = Instance.new("TextBox")
searchBox.Name = "Search"
searchBox.Size = UDim2.new(1, -20, 0, 26)
searchBox.Position = UDim2.new(0, 10, 0, 6)
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
explorerScroll.Size = UDim2.new(1, -10, 1, -38)
explorerScroll.Position = UDim2.new(0, 5, 0, 38)
explorerScroll.BackgroundTransparency = 1
explorerScroll.ScrollBarThickness = 5
explorerScroll.ScrollBarImageColor3 = Color3.fromRGB(70, 130, 180)
explorerScroll.Parent = contentArea

-- Active List
local exportBtn = Instance.new("TextButton")
exportBtn.Name = "ExportBtn"
exportBtn.Size = UDim2.new(1, -20, 0, 26)
exportBtn.Position = UDim2.new(0, 10, 0, 6)
exportBtn.BackgroundColor3 = Color3.fromRGB(60, 130, 180)
exportBtn.BorderSizePixel = 0
exportBtn.Text = "📤 Export Game-Specific Template"
exportBtn.TextColor3 = Color3.new(1, 1, 1)
exportBtn.Font = FONT_BOLD
exportBtn.TextSize = 13
exportBtn.Visible = false
exportBtn.Parent = contentArea
addCorners(exportBtn, 4)

local activeScroll = Instance.new("ScrollingFrame")
activeScroll.Name = "ActiveList"
activeScroll.Size = UDim2.new(1, -10, 1, -38)
activeScroll.Position = UDim2.new(0, 5, 0, 38)
activeScroll.BackgroundTransparency = 1
activeScroll.ScrollBarThickness = 5
activeScroll.ScrollBarImageColor3 = Color3.fromRGB(70, 130, 180)
activeScroll.Visible = false
activeScroll.Parent = contentArea

-- Settings Frame
local settingsFrame = Instance.new("Frame")
settingsFrame.Name = "SettingsFrame"
settingsFrame.Size = UDim2.new(1, 0, 1, -32) -- Fill below header
settingsFrame.Position = UDim2.new(0, 0, 0, 32)
settingsFrame.BackgroundColor3 = Color3.fromRGB(37, 37, 37)
settingsFrame.Visible = false
settingsFrame.ZIndex = 5 -- On top of everything
settingsFrame.Parent = mainFrame

-- Selection Settings UI
local selectionSettingsFrame = Instance.new("Frame")
selectionSettingsFrame.Name = "SelectionSettings"
selectionSettingsFrame.Size = UDim2.new(1, 0, 1, -32)
selectionSettingsFrame.Position = UDim2.new(0, 0, 0, 32)
selectionSettingsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
selectionSettingsFrame.Visible = false
selectionSettingsFrame.ZIndex = 6
selectionSettingsFrame.Parent = mainFrame

local function updateMenuOpacity()
	local opacity = SETTINGS.MenuOpacity
	local trans = 1 - opacity
	
	mainFrame.BackgroundTransparency = trans
	header.BackgroundTransparency = trans
	tabBar.BackgroundTransparency = trans
	statusBar.BackgroundTransparency = trans
	settingsFrame.BackgroundTransparency = trans
	selectionSettingsFrame.BackgroundTransparency = trans
	
	-- Update mainFrame stroke
	local mainStroke = mainFrame:FindFirstChildWhichIsA("UIStroke")
	if mainStroke then
		mainStroke.Transparency = trans
	end
	
	-- Update settings rows background transparency
	for _, child in ipairs(settingsFrame:GetChildren()) do
		if child:IsA("Frame") then
			child.BackgroundTransparency = trans * 0.5 -- Keep rows slightly darker/visible
		end
	end
end
updateMenuOpacity()

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
addConnection(closeSelBtn.MouseButton1Click:Connect(function()
	selectionSettingsFrame.Visible = false
end))

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

-- Properties Section
local propLabel = Instance.new("TextLabel")
propLabel.Size = UDim2.new(1, -20, 0, 20)
propLabel.Position = UDim2.new(0, 10, 0, 310)
propLabel.BackgroundTransparency = 1
propLabel.Text = "Trackable Properties"
propLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
propLabel.Font = FONT_BOLD
propLabel.TextSize = 14
propLabel.TextXAlignment = Enum.TextXAlignment.Left
propLabel.Parent = selectionSettingsFrame

local propertiesScroll = Instance.new("ScrollingFrame")
propertiesScroll.Name = "PropertiesScroll"
propertiesScroll.Size = UDim2.new(1, -20, 1, -345) -- Fill remaining space
propertiesScroll.Position = UDim2.new(0, 10, 0, 335)
propertiesScroll.BackgroundTransparency = 0.5
propertiesScroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
propertiesScroll.ScrollBarThickness = 4
propertiesScroll.ScrollBarImageColor3 = Color3.fromRGB(70, 130, 180)
propertiesScroll.BorderSizePixel = 0
propertiesScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
propertiesScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
propertiesScroll.Parent = selectionSettingsFrame
addCorners(propertiesScroll, 4)

local propList = Instance.new("UIListLayout")
propList.Padding = UDim.new(0, 2)
propList.SortOrder = Enum.SortOrder.Name
propList.Parent = propertiesScroll

local function updatePropertySettings()
	if not currentSelection or not targetSettings[currentSelection] then return end
	local s = targetSettings[currentSelection]
	
	for _, child in pairs(propertiesScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	
	local props = {}
	
	-- Scan Attributes
	for name, _ in pairs(currentSelection:GetAttributes()) do
		props[name] = true
	end
	
	-- Scan ValueBase Children
	for _, child in pairs(currentSelection:GetChildren()) do
		if child:IsA("ValueBase") then
			props[child.Name] = true
		end
	end

	-- Scan children properties if container
	if currentSelection:IsA("Folder") or currentSelection:IsA("Model") or watchedFolders[currentSelection] then
		local children = currentSelection:GetChildren()
		for i = 1, math.min(#children, 20) do
			local child = children[i]
			for name, _ in pairs(child:GetAttributes()) do
				props[name] = true
			end
			for _, subchild in pairs(child:GetChildren()) do
				if subchild:IsA("ValueBase") then
					props[subchild.Name] = true
				end
			end
		end
	end
	
	-- Track All Toggle
	local trackAllRow = Instance.new("Frame")
	trackAllRow.Name = "0_TrackAll"
	trackAllRow.Size = UDim2.new(1, 0, 0, 24)
	trackAllRow.BackgroundTransparency = 1
	trackAllRow.Parent = propertiesScroll

	local taLbl = Instance.new("TextLabel")
	taLbl.Size = UDim2.new(1, -50, 1, 0)
	taLbl.Position = UDim2.new(0, 5, 0, 0)
	taLbl.BackgroundTransparency = 1
	taLbl.Text = "TRACK ALL PROPERTIES"
	taLbl.TextColor3 = Color3.fromRGB(255, 255, 100)
	taLbl.Font = FONT_BOLD
	taLbl.TextSize = 12
	taLbl.TextXAlignment = Enum.TextXAlignment.Left
	taLbl.Parent = trackAllRow

	local taToggle = Instance.new("TextButton")
	taToggle.Size = UDim2.new(0, 40, 0, 18)
	taToggle.Position = UDim2.new(1, -45, 0.5, -9)
	taToggle.BackgroundColor3 = s.TrackAll and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(60, 60, 65)
	taToggle.Text = s.TrackAll and "ON" or "OFF"
	taToggle.TextColor3 = Color3.new(1, 1, 1)
	taToggle.Font = FONT_BOLD
	taToggle.TextSize = 10
	taToggle.Parent = trackAllRow
	addCorners(taToggle, 4)

	taToggle.MouseButton1Click:Connect(function()
		s.TrackAll = not s.TrackAll
		updatePropertySettings()
	end)

	for name, _ in pairs(props) do
		local row = Instance.new("Frame")
		row.Name = name
		row.Size = UDim2.new(1, 0, 0, 24)
		row.BackgroundTransparency = 1
		row.Parent = propertiesScroll
		
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -50, 1, 0)
		lbl.Position = UDim2.new(0, 5, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = name
		lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
		lbl.Font = FONT
		lbl.TextSize = 12
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = row
		
		local toggle = Instance.new("TextButton")
		toggle.Size = UDim2.new(0, 40, 0, 18)
		toggle.Position = UDim2.new(1, -45, 0.5, -9)
		toggle.BackgroundColor3 = s.TrackedProperties[name] and Color3.fromRGB(60, 150, 60) or Color3.fromRGB(60, 60, 65)
		toggle.Text = s.TrackedProperties[name] and "ON" or "OFF"
		toggle.TextColor3 = Color3.new(1, 1, 1)
		toggle.Font = FONT_BOLD
		toggle.TextSize = 10
		toggle.Parent = row
		addCorners(toggle, 4)
		
		toggle.MouseButton1Click:Connect(function()
			s.TrackedProperties[name] = not s.TrackedProperties[name]
			updatePropertySettings()
		end)
	end
end

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
	
	addConnection(params.Btn.MouseButton1Down:Connect(function()
		local mouse = PLAYER:GetMouse()
		updateColor(mouse.X)
		activeDrag = { component = component, params = params, updateFn = updateColor }
	end))
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

addConnection(rainbowToggleBtn.MouseButton1Click:Connect(function()
	if not currentSelection then return end
	local s = targetSettings[currentSelection]
	s.Rainbow = not s.Rainbow
	updateSelectionUI()
end))

-- Color Presets UI
local presetLabel = Instance.new("TextLabel")
presetLabel.Size = UDim2.new(1, -20, 0, 20)
presetLabel.Position = UDim2.new(0, 10, 0, 175)
presetLabel.BackgroundTransparency = 1
presetLabel.Text = "Color Presets"
presetLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
presetLabel.Font = FONT_BOLD
presetLabel.TextSize = 14
presetLabel.TextXAlignment = Enum.TextXAlignment.Left
presetLabel.Parent = selectionSettingsFrame

local presetContainer = Instance.new("Frame")
presetContainer.Size = UDim2.new(1, -20, 0, 100)
presetContainer.Position = UDim2.new(0, 10, 0, 200)
presetContainer.BackgroundTransparency = 1
presetContainer.Parent = selectionSettingsFrame

local presetGrid = Instance.new("UIGridLayout")
presetGrid.CellSize = UDim2.new(0, 32, 0, 32)
presetGrid.CellPadding = UDim2.new(0, 6, 0, 6)
presetGrid.Parent = presetContainer

for _, preset in ipairs(COLOR_PRESETS) do
	local btn = Instance.new("TextButton")
	btn.Name = preset.Name
	btn.Text = ""
	btn.BackgroundColor3 = preset.Color
	btn.BorderSizePixel = 0
	btn.Parent = presetContainer
	addCorners(btn, 4)
	addStroke(btn, Color3.fromRGB(50, 50, 50), 1)

	addConnection(btn.MouseButton1Click:Connect(function()
		if not currentSelection then return end
		local s = targetSettings[currentSelection]
		if not s then return end

		s.Color = preset.Color
		s.Rainbow = false
		updateSelectionUI()
	end))
end

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
	addCorners(row, 4) -- Rounded corners for settings rows
	
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
addConnection(unloadBtn.MouseButton1Click:Connect(function() UnloadScript(screenGui) end))

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
addConnection(rejoinBtn.MouseButton1Click:Connect(function() 
	TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, PLAYER)
end))

-- 3. Max Highlights
local maxHighlightsRow = createSettingRow("Max Highlights", 3)
-- Value Label (aligned inside right edge)
local valLabel = Instance.new("TextLabel")
valLabel.Name = "ValueLabel"
valLabel.Size = UDim2.new(0, 30, 1, 0)
valLabel.Position = UDim2.new(1, -35, 0, 0)
valLabel.BackgroundTransparency = 1
valLabel.Text = tostring(SETTINGS.MaxHighlights)
valLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
valLabel.TextXAlignment = Enum.TextXAlignment.Right
valLabel.Font = FONT
valLabel.TextSize = 12
valLabel.Parent = maxHighlightsRow

-- Slider Logic (positioned to the left of the value label)
local sliderBg = Instance.new("Frame")
sliderBg.Name = "SliderBg"
sliderBg.Size = UDim2.new(0, 80, 0, 6)
sliderBg.Position = UDim2.new(1, -125, 0.5, -3)
sliderBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
sliderBg.BorderSizePixel = 0
sliderBg.Parent = maxHighlightsRow

local sliderFill = Instance.new("Frame")
sliderFill.Name = "SliderFill"
sliderFill.Size = UDim2.fromScale(SETTINGS.MaxHighlights / 300, 1)
sliderFill.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBg

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
	sliderFill.Size = UDim2.fromScale(percent, 1)
	valLabel.Text = tostring(val)
end

addConnection(sliderBtn.MouseButton1Down:Connect(function()
	local mouse = PLAYER:GetMouse()
	updateSettingsSlider(mouse.X)
	activeDrag = { component = "MaxHighlights", updateFn = updateSettingsSlider }
end))

-- 4. Vertical Offset
local verticalOffsetRow = createSettingRow("Vertical Offset", 4)
-- Value Label
local vValLabel = Instance.new("TextLabel")
vValLabel.Name = "ValueLabel"
vValLabel.Size = UDim2.new(0, 30, 1, 0)
vValLabel.Position = UDim2.new(1, -35, 0, 0)
vValLabel.BackgroundTransparency = 1
vValLabel.Text = string.format("%.1f", SETTINGS.VerticalOffset)
vValLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
vValLabel.TextXAlignment = Enum.TextXAlignment.Right
vValLabel.Font = FONT
vValLabel.TextSize = 12
vValLabel.Parent = verticalOffsetRow

local vSliderBg = Instance.new("Frame")
vSliderBg.Name = "SliderBg"
vSliderBg.Size = UDim2.new(0, 80, 0, 6)
vSliderBg.Position = UDim2.new(1, -125, 0.5, -3)
vSliderBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
vSliderBg.BorderSizePixel = 0
vSliderBg.Parent = verticalOffsetRow

local vSliderFill = Instance.new("Frame")
vSliderFill.Name = "SliderFill"
vSliderFill.Size = UDim2.fromScale(SETTINGS.VerticalOffset / 10, 1)
vSliderFill.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
vSliderFill.BorderSizePixel = 0
vSliderFill.Parent = vSliderBg

local vSliderBtn = Instance.new("TextButton")
vSliderBtn.Name = "SliderBtn"
vSliderBtn.Size = UDim2.new(1, 0, 1, 10)
vSliderBtn.Position = UDim2.new(0, 0, 0, -5)
vSliderBtn.BackgroundTransparency = 1
vSliderBtn.Text = ""
vSliderBtn.Parent = vSliderBg

local function updateVerticalOffsetSlider(mouseX)
	local rel = (mouseX - vSliderBg.AbsolutePosition.X) / vSliderBg.AbsoluteSize.X
	local percent = math.clamp(rel, 0, 1)
	local val = math.floor(percent * 100) / 10 -- 0.0 to 10.0
	
	SETTINGS.VerticalOffset = val
	vSliderFill.Size = UDim2.fromScale(percent, 1)
	vValLabel.Text = string.format("%.1f", val)
end

addConnection(vSliderBtn.MouseButton1Down:Connect(function()
	local mouse = PLAYER:GetMouse()
	updateVerticalOffsetSlider(mouse.X)
	activeDrag = { component = "VerticalOffset", updateFn = updateVerticalOffsetSlider }
end))

-- 5. Max Distance Slider
local maxDistanceRow = createSettingRow("Max Distance", 5)
-- Value Label
local dValLabel = Instance.new("TextLabel")
dValLabel.Name = "ValueLabel"
dValLabel.Size = UDim2.new(0, 30, 1, 0)
dValLabel.Position = UDim2.new(1, -35, 0, 0)
dValLabel.BackgroundTransparency = 1
dValLabel.Text = tostring(SETTINGS.MaxDistance)
dValLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
dValLabel.TextXAlignment = Enum.TextXAlignment.Right
dValLabel.Font = FONT
dValLabel.TextSize = 12
dValLabel.Parent = maxDistanceRow

local dSliderBg = Instance.new("Frame")
dSliderBg.Name = "SliderBg"
dSliderBg.Size = UDim2.new(0, 80, 0, 6)
dSliderBg.Position = UDim2.new(1, -125, 0.5, -3)
dSliderBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
dSliderBg.BorderSizePixel = 0
dSliderBg.Parent = maxDistanceRow

local dSliderFill = Instance.new("Frame")
dSliderFill.Name = "SliderFill"
dSliderFill.Size = UDim2.fromScale(SETTINGS.MaxDistance / 5000, 1)
dSliderFill.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
dSliderFill.BorderSizePixel = 0
dSliderFill.Parent = dSliderBg

local dSliderBtn = Instance.new("TextButton")
dSliderBtn.Name = "SliderBtn"
dSliderBtn.Size = UDim2.new(1, 0, 1, 10)
dSliderBtn.Position = UDim2.new(0, 0, 0, -5)
dSliderBtn.BackgroundTransparency = 1
dSliderBtn.Text = ""
dSliderBtn.Parent = dSliderBg

local function updateMaxDistanceSlider(mouseX)
	local rel = (mouseX - dSliderBg.AbsolutePosition.X) / dSliderBg.AbsoluteSize.X
	local percent = math.clamp(rel, 0, 1)
	local val = math.floor(percent * 49 + 1) * 100 -- 100 to 5000 studs

	SETTINGS.MaxDistance = val
	dSliderFill.Size = UDim2.fromScale(percent, 1)
	dValLabel.Text = tostring(val)
end

addConnection(dSliderBtn.MouseButton1Down:Connect(function()
	local mouse = PLAYER:GetMouse()
	updateMaxDistanceSlider(mouse.X)
	activeDrag = { component = "MaxDistance", updateFn = updateMaxDistanceSlider }
end))

-- 6. Menu Opacity Slider
local menuOpacityRow = createSettingRow("Menu Opacity", 6)
local moValLabel = Instance.new("TextLabel")
moValLabel.Name = "ValueLabel"
moValLabel.Size = UDim2.new(0, 30, 1, 0)
moValLabel.Position = UDim2.new(1, -35, 0, 0)
moValLabel.BackgroundTransparency = 1
moValLabel.Text = math.floor(SETTINGS.MenuOpacity * 100) .. "%"
moValLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
moValLabel.TextXAlignment = Enum.TextXAlignment.Right
moValLabel.Font = FONT
moValLabel.TextSize = 12
moValLabel.Parent = menuOpacityRow

local moSliderBg = Instance.new("Frame")
moSliderBg.Name = "SliderBg"
moSliderBg.Size = UDim2.new(0, 80, 0, 6)
moSliderBg.Position = UDim2.new(1, -125, 0.5, -3)
moSliderBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
moSliderBg.BorderSizePixel = 0
moSliderBg.Parent = menuOpacityRow

local moSliderFill = Instance.new("Frame")
moSliderFill.Name = "SliderFill"
moSliderFill.Size = UDim2.fromScale(SETTINGS.MenuOpacity, 1)
moSliderFill.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
moSliderFill.BorderSizePixel = 0
moSliderFill.Parent = moSliderBg

local moSliderBtn = Instance.new("TextButton")
moSliderBtn.Name = "SliderBtn"
moSliderBtn.Size = UDim2.new(1, 0, 1, 10)
moSliderBtn.Position = UDim2.new(0, 0, 0, -5)
moSliderBtn.BackgroundTransparency = 1
moSliderBtn.Text = ""
moSliderBtn.Parent = moSliderBg

local function updateMenuOpacitySlider(mouseX)
	local rel = (mouseX - moSliderBg.AbsolutePosition.X) / moSliderBg.AbsoluteSize.X
	local percent = math.clamp(rel, 0.1, 1) -- Minimum 10% opacity

	SETTINGS.MenuOpacity = percent
	moSliderFill.Size = UDim2.fromScale(percent, 1)
	moValLabel.Text = math.floor(percent * 100) .. "%"
	updateMenuOpacity()
end

addConnection(moSliderBtn.MouseButton1Down:Connect(function()
	local mouse = PLAYER:GetMouse()
	updateMenuOpacitySlider(mouse.X)
	activeDrag = { component = "MenuOpacity", updateFn = updateMenuOpacitySlider }
end))

-- 7. ESP Opacity Slider
local espOpacityRow = createSettingRow("ESP Opacity", 7)
local eoValLabel = Instance.new("TextLabel")
eoValLabel.Name = "ValueLabel"
eoValLabel.Size = UDim2.new(0, 30, 1, 0)
eoValLabel.Position = UDim2.new(1, -35, 0, 0)
eoValLabel.BackgroundTransparency = 1
eoValLabel.Text = math.floor(SETTINGS.EspOpacity * 100) .. "%"
eoValLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
eoValLabel.TextXAlignment = Enum.TextXAlignment.Right
eoValLabel.Font = FONT
eoValLabel.TextSize = 12
eoValLabel.Parent = espOpacityRow

local eoSliderBg = Instance.new("Frame")
eoSliderBg.Name = "SliderBg"
eoSliderBg.Size = UDim2.new(0, 80, 0, 6)
eoSliderBg.Position = UDim2.new(1, -125, 0.5, -3)
eoSliderBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
eoSliderBg.BorderSizePixel = 0
eoSliderBg.Parent = espOpacityRow

local eoSliderFill = Instance.new("Frame")
eoSliderFill.Name = "SliderFill"
eoSliderFill.Size = UDim2.fromScale(SETTINGS.EspOpacity, 1)
eoSliderFill.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
eoSliderFill.BorderSizePixel = 0
eoSliderFill.Parent = eoSliderBg

local eoSliderBtn = Instance.new("TextButton")
eoSliderBtn.Name = "SliderBtn"
eoSliderBtn.Size = UDim2.new(1, 0, 1, 10)
eoSliderBtn.Position = UDim2.new(0, 0, 0, -5)
eoSliderBtn.BackgroundTransparency = 1
eoSliderBtn.Text = ""
eoSliderBtn.Parent = eoSliderBg

local function updateEspOpacitySlider(mouseX)
	local rel = (mouseX - eoSliderBg.AbsolutePosition.X) / eoSliderBg.AbsoluteSize.X
	local percent = math.clamp(rel, 0, 1)

	SETTINGS.EspOpacity = percent
	eoSliderFill.Size = UDim2.fromScale(percent, 1)
	eoValLabel.Text = math.floor(percent * 100) .. "%"
end

addConnection(eoSliderBtn.MouseButton1Down:Connect(function()
	local mouse = PLAYER:GetMouse()
	updateEspOpacitySlider(mouse.X)
	activeDrag = { component = "EspOpacity", updateFn = updateEspOpacitySlider }
end))


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
		exportBtn.Visible = false
		selectionSettingsFrame.Visible = false
		refreshTree()
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

addConnection(settingsButton.MouseButton1Click:Connect(function()
	if isMinimized then
		toggleMinimize()
		currentTab = "Settings"
		settingsFrame.Visible = true
		explorerScroll.Visible = false
		searchBox.Visible = false
		activeScroll.Visible = false
		selectionSettingsFrame.Visible = false
		tabExplorer.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
		tabActive.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
		return
	end

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
end))
addConnection(tabExplorer.MouseButton1Click:Connect(function() switchTab("Explorer") end))
addConnection(tabActive.MouseButton1Click:Connect(function() switchTab("Active") end))

local function ensureWithinBounds()
	local viewportSize = camera.ViewportSize
	local absoluteSize = mainFrame.AbsoluteSize
	local anchorPoint = mainFrame.AnchorPoint
	
	if viewportSize.X == 0 or viewportSize.Y == 0 then return end
	
	local minX = absoluteSize.X * anchorPoint.X
	local maxX = viewportSize.X - (absoluteSize.X * (1 - anchorPoint.X))
	local minY = absoluteSize.Y * anchorPoint.Y
	local maxY = viewportSize.Y - (absoluteSize.Y * (1 - anchorPoint.Y))
	
	local currentX = mainFrame.Position.X.Scale * viewportSize.X
	local currentY = mainFrame.Position.Y.Scale * viewportSize.Y
	
	local clampedX = math.clamp(currentX, minX, maxX)
	local clampedY = math.clamp(currentY, minY, maxY)
	
	local newPos = UDim2.fromScale(clampedX / viewportSize.X, clampedY / viewportSize.Y)
	if mainFrame.Position ~= newPos then
		mainFrame.Position = newPos
	end
end

toggleMinimize = function()
	if not ALIVE then return end
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
		
		mainFrame.AnchorPoint = Vector2.new(1, 0)
		mainFrame.Size = UDim2.new(0, 210, 0, 32) -- Fixed minimized size
		mainFrame.Position = UDim2.fromScale(0.913, 0.025)
		minButton.Text = "+"
	else
		mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		mainFrame.Size = UDim2.new(0, 340, 0, 480) -- Restore fixed size
		mainFrame.Position = UDim2.fromScale(0.5, 0.5)
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
	ensureWithinBounds()
end

addConnection(minButton.MouseButton1Click:Connect(toggleMinimize))

-- Keyboard Shortcut
addConnection(UserInputService.InputBegan:Connect(function(input, processed)
	if UserInputService:GetFocusedTextBox() then return end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		if input.KeyCode == Enum.KeyCode.Backspace then
			toggleMinimize()
		elseif input.KeyCode == Enum.KeyCode.U then
			UnloadScript(screenGui)
		end
	end
end))

-- Custom Dragging logic
local isDragging = false
local dragStart = nil
local startPos = nil

addConnection(header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDragging = true
		dragStart = input.Position
		
		startPos = Vector2.new(
			mainFrame.Position.X.Scale,
			mainFrame.Position.Y.Scale
		)
		
		local connection
		connection = addConnection(input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				isDragging = false
				removeConnection(connection)
			end
		end))
	end
end))

addConnection(UserInputService.InputChanged:Connect(function(input)
	if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local viewportSize = camera.ViewportSize
		if viewportSize.X == 0 or viewportSize.Y == 0 then return end
		
		local delta = input.Position - dragStart
		local deltaScale = Vector2.new(delta.X / viewportSize.X, delta.Y / viewportSize.Y)
		
		mainFrame.Position = UDim2.fromScale(startPos.X + deltaScale.X, startPos.Y + deltaScale.Y)
		ensureWithinBounds()
	end
end))

addConnection(camera:GetPropertyChangedSignal("ViewportSize"):Connect(ensureWithinBounds))

-- ESP LOGIC

local function removeEsp(instance)
	local objs = espObjects[instance]
	if objs then
		if objs.Janitor then
			objs.Janitor:Cleanup()
		end
		
		-- Return Highlight to pool if active
		if objs.Highlight then
			local hl = objs.Highlight
			hl.Enabled = false
			hl.Adornee = nil
			table.insert(highlightPool, hl)
			objs.Highlight = nil
		end
		
		espObjects[instance] = nil
		espObjectCount = math.max(0, espObjectCount - 1)
	end
end

local function updateEspPropertyString(instance)
	local objs = espObjects[instance]
	if not objs then return end
	local source = objs.Source or instance
	local s = targetSettings[source]
	if not s then return "" end

	local allProps = {}
	if s.TrackAll then
		for name, val in pairs(instance:GetAttributes()) do
			table.insert(allProps, {Name = name, Value = val})
		end
		for _, child in ipairs(instance:GetChildren()) do
			if child:IsA("ValueBase") then
				table.insert(allProps, {Name = child.Name, Value = child.Value})
			end
		end
	elseif s.TrackedProperties then
		for propName, active in pairs(s.TrackedProperties) do
			if active then
				local val = instance:GetAttribute(propName)
				if val == nil then
					local valObj = instance:FindFirstChild(propName)
					if valObj and valObj:IsA("ValueBase") then
						val = valObj.Value
					end
				end
				if val ~= nil then
					table.insert(allProps, {Name = propName, Value = val})
				end
			end
		end
	end

	if #allProps == 0 then
		objs.PropertyString = ""
		return ""
	end

	table.sort(allProps, function(a, b) return a.Name:lower() < b.Name:lower() end)
	
	local result = {}
	for _, p in ipairs(allProps) do
		if type(p.Value) == "boolean" then
			table.insert(result, p.Value and ("\n[" .. p.Name .. "]") or ("\n[Not " .. p.Name .. "]"))
		else
			table.insert(result, "\n[" .. p.Name .. ": " .. tostring(p.Value) .. "]")
		end
	end
	
	local str = table.concat(result)
	objs.PropertyString = str
	return str
end

local function createEsp(instance, source)
	if not ALIVE then return end
	if espObjects[instance] then return end
	
	-- Object Cap Safety
	if espObjectCount >= SETTINGS.MaxTotalObjects then return end

	if instance == PLAYER.Character or instance:IsA("Camera") or instance:IsA("Terrain") then return end

	local rootPart = nil
	if instance:IsA("Model") then
		rootPart = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	elseif instance:IsA("BasePart") then
		rootPart = instance
	end
	
	if rootPart then
		local janitor = Janitor.new()
		
		-- Pool-based BillboardGui allocation
		local bg = table.remove(billboardPool)
		local tl
		if bg then
			tl = bg:FindFirstChildWhichIsA("TextLabel")
			bg.Enabled = true
		else
			bg = Instance.new("BillboardGui")
			bg.Size = UDim2.new(0, 150, 0, 60)
			bg.AlwaysOnTop = true
			bg.Name = "ESPTag"
			bg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			
			tl = Instance.new("TextLabel")
			tl.Size = UDim2.fromScale(1, 1)
			tl.BackgroundTransparency = 1
			tl.Font = FONT_BOLD
			tl.TextSize = 14
			tl.TextStrokeTransparency = 0.5
			tl.Parent = bg
		end
		
		bg.Adornee = rootPart
		bg.ExtentsOffset = Vector3.new(0, 1, 0)
		bg.StudsOffset = Vector3.new(0, SETTINGS.VerticalOffset, 0)
		
		local s = targetSettings[source]
		local color = s and s.Color or Color3.new(1, 0, 0)
		
		tl.Text = instance.Name
		if not (s and s.Rainbow) then
			tl.TextColor3 = color
		end
		tl.Visible = SETTINGS.ShowNames
		
		-- Apply default EspOpacity
		local targetTrans = 1 - SETTINGS.EspOpacity
		tl.TextTransparency = targetTrans
		tl.TextStrokeTransparency = 0.5 + 0.5 * targetTrans
		
		-- Attach to rootPart
		bg.Parent = rootPart
		
		-- Return BillboardGui to pool on cleanup
		janitor:Add(function()
			bg.Enabled = false
			bg.Adornee = nil
			bg.Parent = nil
			table.insert(billboardPool, bg)
		end, nil, "Billboard")

		local objs = { 
			Instance = instance,
			Janitor = janitor, 
			GUI = bg, 
			Highlight = nil, -- Handled dynamically in update loop
			Label = tl, 
			Source = (source ~= instance) and source or nil, 
			Root = (rootPart ~= instance) and rootPart or nil,
			PropertyString = "",
			LastDistance = -1,
			LastPropertyString = "",
			LastColor = nil
		}
		espObjects[instance] = objs
		espObjectCount = espObjectCount + 1

		-- Event-driven property tracking
		janitor:Add(instance.AttributeChanged:Connect(function()
			updateEspPropertyString(instance)
		end))
		janitor:Add(instance.ChildAdded:Connect(function(child)
			if child:IsA("ValueBase") then
				janitor:Add(child.Changed:Connect(function() updateEspPropertyString(instance) end), "Disconnect", "Val_" .. child.Name)
				updateEspPropertyString(instance)
			end
		end))
		janitor:Add(instance.ChildRemoved:Connect(function(child)
			if child:IsA("ValueBase") then
				janitor:Remove("Val_" .. child.Name)
				updateEspPropertyString(instance)
			end
		end))
		
		-- Initial scan
		for _, child in ipairs(instance:GetChildren()) do
			if child:IsA("ValueBase") then
				janitor:Add(child.Changed:Connect(function() updateEspPropertyString(instance) end), "Disconnect", "Val_" .. child.Name)
			end
		end
		updateEspPropertyString(instance)

		-- Immediate cleanup on destruction
		janitor:Add(instance.Destroying:Connect(function()
			removeEsp(instance)
		end))

		janitor:Add(instance.AncestryChanged:Connect(function()
			if not instance:IsDescendantOf(Workspace) then
				removeEsp(instance)
			end
		end))

		-- Guard against RootPart destruction in Models (crucial memory leak fix)
		if rootPart ~= instance then
			janitor:Add(rootPart.Destroying:Connect(function()
				removeEsp(instance)
			end))
			janitor:Add(rootPart.AncestryChanged:Connect(function()
				if not rootPart:IsDescendantOf(Workspace) then
					removeEsp(instance)
				end
			end))
		end
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
				Rainbow = false,
				TrackedProperties = {},
				TrackAll = false
			}
		end
	else 
		espTargets[instance] = nil 
	end
	
	local isContainer = instance:IsA("Folder") or instance:IsA("Model")
	if isContainer then
		if newState then
			if not watchedFolders[instance] then
				if watchedFolderCount >= SETTINGS.MaxWatchedFolders then
					warn("[Any_Item_ESP] Max watched folders reached (" .. SETTINGS.MaxWatchedFolders .. ")")
					espTargets[instance] = nil
					return
				end
				watchedFolderCount = watchedFolderCount + 1
				local janitor = Janitor.new()
				
				for _, child in pairs(instance:GetChildren()) do
					if child:IsA("Model") or child:IsA("BasePart") then createEsp(child, instance) end
				end
				
				janitor:Add(instance.ChildAdded:Connect(function(child)
					if not ALIVE then return end
					if child:IsA("Model") or child:IsA("BasePart") then
						task.defer(function() createEsp(child, instance) end)
					end
				end))

				janitor:Add(instance.ChildRemoved:Connect(function(child)
					local objs = espObjects[child]
					if objs and objs.Source == instance then
						removeEsp(child)
					end
				end))
				
				-- OPTIMIZATION: Immediate folder cleanup on destruction
				janitor:Add(instance.Destroying:Connect(function()
					toggleEsp(instance, false)
				end))

				janitor:Add(instance.AncestryChanged:Connect(function()
					if not instance:IsDescendantOf(Workspace) then
						toggleEsp(instance, false)
					end
				end))

				watchedFolders[instance] = { Janitor = janitor }
			end
		else
			local data = watchedFolders[instance]
			if data then
				watchedFolderCount = math.max(0, watchedFolderCount - 1)
				if data.Janitor then data.Janitor:Cleanup() end
				watchedFolders[instance] = nil
				for _, child in pairs(instance:GetChildren()) do
					-- When removing container, check if child is not targeted individually?
					-- Simplification: Remove ESP if it maps to this source
					if espObjects[child] and espObjects[child].Source == instance then
						removeEsp(child)
					end
				end
			else
				removeEsp(instance)
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

local function getRowFromPool()
	local row = table.remove(rowPool)
	if row then 
		row.Visible = true
		return row 
	end

	row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 20)
	row.BackgroundTransparency = 1

	local expandBtn = Instance.new("TextLabel")
	expandBtn.Name = "Expand"
	expandBtn.Size = UDim2.new(0, 20, 1, 0)
	expandBtn.BackgroundTransparency = 1
	expandBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
	expandBtn.Font = FONT
	expandBtn.TextSize = 14
	expandBtn.Parent = row

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(0, 20, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.TextSize = 14
	iconLabel.Parent = row

	local nameBtn = Instance.new("TextLabel")
	nameBtn.Name = "ItemName"
	nameBtn.BackgroundTransparency = 1
	nameBtn.TextColor3 = Color3.fromRGB(204, 204, 204)
	nameBtn.TextXAlignment = Enum.TextXAlignment.Left
	nameBtn.Font = FONT
	nameBtn.TextSize = 14
	nameBtn.TextTruncate = Enum.TextTruncate.AtEnd
	nameBtn.Parent = row

	local espBtn = Instance.new("TextLabel")
	espBtn.Name = "EspToggle"
	espBtn.Size = UDim2.new(0, 30, 1, 0)
	espBtn.Position = UDim2.new(1, -30, 0, 0)
	espBtn.BackgroundTransparency = 1
	espBtn.TextColor3 = Color3.new(1, 1, 1)
	espBtn.Font = FONT
	espBtn.TextSize = 14
	espBtn.Parent = row

	return row
end

local function releaseRowToPool(row)
	row.Visible = false
	row.Parent = nil
	table.insert(rowPool, row)
end

local function getActiveRowFromPool()
	local row = table.remove(activeRowPool)
	if row then
		row.Visible = true
		return row
	end

	row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundTransparency = 0
	row.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	addCorners(row, 4)

	local indColor = Instance.new("Frame")
	indColor.Name = "IndColor"
	indColor.Size = UDim2.new(0, 4, 1, -8)
	indColor.Position = UDim2.new(0, 4, 0, 4)
	indColor.BorderSizePixel = 0
	indColor.Parent = row
	addCorners(indColor, 2)

	local lbl = Instance.new("TextLabel")
	lbl.Name = "ItemName"
	lbl.Size = UDim2.new(1, -150, 1, 0)
	lbl.Position = UDim2.new(0, 14, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(220, 220, 225)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Font = FONT
	lbl.TextSize = 13
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.Parent = row

	-- Teleport Button
	local teleportBtn = Instance.new("TextButton")
	teleportBtn.Name = "TeleportBtn"
	teleportBtn.Size = UDim2.new(0, 22, 0, 22)
	teleportBtn.Position = UDim2.new(1, -145, 0, 7)
	teleportBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 100)
	teleportBtn.BorderSizePixel = 0
	teleportBtn.Text = "TP"
	teleportBtn.TextColor3 = Color3.new(1, 1, 1)
	teleportBtn.Font = FONT
	teleportBtn.TextSize = 12
	teleportBtn.Parent = row
	addCorners(teleportBtn, 4)

	-- Copy Path Button
	local copyBtn = Instance.new("TextButton")
	copyBtn.Name = "CopyBtn"
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

	local setsBtn = Instance.new("TextButton")
	setsBtn.Name = "SettingsBtn"
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

	local removeBtn = Instance.new("TextButton")
	removeBtn.Name = "RemoveBtn"
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

	return row
end

local function releaseActiveRowToPool(row)
	row.Visible = false
	row.Parent = nil
	rowToInstance[row] = nil
	local conns = activeRowConns[row]
	if conns then
		for _, conn in ipairs(conns) do
			if conn.Connected then conn:Disconnect() end
		end
		table.clear(conns)
		activeRowConns[row] = nil
	end
	table.insert(activeRowPool, row)
end

-- Node pool for buildFlatList to reduce table churn
local nodePool = {}
local function getNode(info, depth)
	local node = table.remove(nodePool)
	if node then
		node.Instance = info
		node.Depth = depth
		return node
	end
	return {Instance = info, Depth = depth}
end

local function releaseNodeToPool(node)
	if not node then return end
	node.Instance = nil
	table.insert(nodePool, node)
end

local function buildFlatList(list, instance, depth, query)
	if not ALIVE or depth > 50 or #list > 5000 then return end
	local matches = true
	if query then
		if not instance.Name:lower():find(query, 1, true) then matches = false end
	end
	
	local shouldShow = not query or matches
	
	if shouldShow then
		table.insert(list, getNode(instance, depth))
	end
	
	if (not query and expandedNodes[instance]) or (query and matches) then
		local children = instance:GetChildren()
		for i = 1, #children do
			buildFlatList(list, children[i], depth + 1, query)
		end
	end
end

local function updateActiveViewport()
	if not ALIVE then return end
	local viewHeight = activeScroll.AbsoluteSize.Y
	if viewHeight == 0 then viewHeight = 400 end
	local scrollPos = activeScroll.CanvasPosition.Y
	local startIdx = math.floor(scrollPos / 40) + 1
	local endIdx = math.ceil((scrollPos + viewHeight) / 40)

	-- Release out of view rows
	for idx, row in pairs(activeTabRows) do
		if idx < startIdx or idx > endIdx then
			releaseActiveRowToPool(row)
			activeTabRows[idx] = nil
		end
	end

	-- Render visible rows
	for i = startIdx, endIdx do
		local inst = activeFlatList[i]
		if inst and inst:IsDescendantOf(game) and not activeTabRows[i] then
			local row = getActiveRowFromPool()
			local expectedPos = UDim2.new(0, 0, 0, (i - 1) * 40)
			if row.Position ~= expectedPos then row.Position = expectedPos end
			
			local s = targetSettings[inst]
			local color = s and s.Color or Color3.new(1,1,1)
			local indColor = row:FindFirstChild("IndColor")
			if indColor and indColor.BackgroundColor3 ~= color then
				indColor.BackgroundColor3 = color
			end
			
			local lbl = row:FindFirstChild("ItemName")
			if lbl then
				local expectedText = inst.Name .. " (" .. inst.ClassName .. ")"
				if lbl.Text ~= expectedText then lbl.Text = expectedText end
			end

			-- Setup connections if not already present
			if not activeRowConns[row] then
				local rowConns = {}
				
				local tpBtn = row:FindFirstChild("TeleportBtn")
				table.insert(rowConns, tpBtn.MouseButton1Click:Connect(function()
					local targetInst = rowToInstance[row]
					if not targetInst then return end
					local char = PLAYER.Character
					if char and char:FindFirstChild("HumanoidRootPart") then
						local targetPos
						if targetInst:IsA("Model") then
							local part = targetInst.PrimaryPart or targetInst:FindFirstChildWhichIsA("BasePart", true)
							if part then targetPos = part.Position end
						elseif targetInst:IsA("BasePart") then
							targetPos = targetInst.Position
						end
						if targetPos then
							char.HumanoidRootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0))
						end
					end
				end))

				local copyBtn = row:FindFirstChild("CopyBtn")
				table.insert(rowConns, copyBtn.MouseButton1Click:Connect(function()
					local targetInst = rowToInstance[row]
					if not targetInst then return end
					
					local s = targetSettings[targetInst]
					local colorStr = "Color3.fromRGB(255, 255, 255)"
					local rainbowStr = ""
					local trackAllStr = ""
					if s then
						local c = s.Color
						colorStr = string.format("Color3.fromRGB(%d, %d, %d)", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
						if s.Rainbow then
							rainbowStr = ", Rainbow = true"
						end
						if s.TrackAll then
							trackAllStr = ", TrackAll = true"
						end
					end
					
					local propList = {}
					if s and s.TrackedProperties then
						for propName, active in pairs(s.TrackedProperties) do
							if active then
								table.insert(propList, string.format("%s = true", propName))
							end
						end
					end
					local propStr = #propList > 0 and (", TrackedProperties = {" .. table.concat(propList, ", ") .. "}") or ""
					
					local templateStr = string.format('{Path = "%s", Color = %s%s%s%s}', getRelativePath(targetInst), colorStr, rainbowStr, trackAllStr, propStr)
					
					if setclipboard then setclipboard(templateStr)
					elseif Clipboard and Clipboard.set then Clipboard.set(templateStr) end
					
					copyBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
					task.delay(0.5, function()
						if copyBtn and copyBtn.Parent then
							copyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
						end
					end)
				end))

				local setsBtn = row:FindFirstChild("SettingsBtn")
				table.insert(rowConns, setsBtn.MouseButton1Click:Connect(function()
					local targetInst = rowToInstance[row]
					if not targetInst then return end
					currentSelection = targetInst
					selTitle.Text = "Settings: " .. targetInst.Name
					selectionSettingsFrame.Visible = true
					updateSelectionUI()
					updatePropertySettings()
				end))

				local removeBtn = row:FindFirstChild("RemoveBtn")
				table.insert(rowConns, removeBtn.MouseButton1Click:Connect(function()
					local targetInst = rowToInstance[row]
					if not targetInst then return end
					toggleEsp(targetInst, false)
				end))

				activeRowConns[row] = rowConns
			end
			
			rowToInstance[row] = inst
			row.Parent = activeScroll
			activeTabRows[i] = row
		end
	end
end

local function updateViewport()
	if not ALIVE then return end
	local viewHeight = explorerScroll.AbsoluteSize.Y
	if viewHeight == 0 then viewHeight = 400 end
	local scrollPos = explorerScroll.CanvasPosition.Y
	local startIdx = math.floor(scrollPos / 20) + 1
	local endIdx = math.ceil((scrollPos + viewHeight) / 20)

	-- Release out of view rows
	for idx, row in pairs(activeRows) do
		if idx < startIdx or idx > endIdx then
			releaseRowToPool(row)
			activeRows[idx] = nil
		end
	end

	-- Render visible rows
	for i = startIdx, endIdx do
		local node = currentFlatList[i]
		local inst = node and node.Instance
		
		if inst and not activeRows[i] then
			local depth = node.Depth
			local row = getRowFromPool()
			local expectedPos = UDim2.new(0, 0, 0, (i - 1) * 20)
			if row.Position ~= expectedPos then row.Position = expectedPos end
			
			local padding = depth * 20
			local isContainer = inst:IsA("Folder") or inst:IsA("Model")
			local hasChildren = inst:FindFirstChildWhichIsA("Instance") ~= nil

			local expandBtn = row:FindFirstChild("Expand")
			if expandBtn then
				local expectedExpandPos = UDim2.new(0, padding, 0, 0)
				if expandBtn.Position ~= expectedExpandPos then expandBtn.Position = expectedExpandPos end
				
				local expectedText = (isContainer and hasChildren) and (expandedNodes[inst] and "v" or ">") or ""
				if expandBtn.Text ~= expectedText then expandBtn.Text = expectedText end
			end

			local iconLabel = row:FindFirstChild("Icon")
			if iconLabel then
				local expectedIconPos = UDim2.new(0, padding + 20, 0, 0)
				if iconLabel.Position ~= expectedIconPos then iconLabel.Position = expectedIconPos end
				
				local expectedIcon = getIcon(inst)
				if iconLabel.Text ~= expectedIcon then iconLabel.Text = expectedIcon end
			end

			local nameBtn = row:FindFirstChild("ItemName")
			if nameBtn then
				local expectedNameSize = UDim2.new(1, -(padding + 110), 1, 0)
				if nameBtn.Size ~= expectedNameSize then nameBtn.Size = expectedNameSize end
				
				local expectedNamePos = UDim2.new(0, padding + 40, 0, 0)
				if nameBtn.Position ~= expectedNamePos then nameBtn.Position = expectedNamePos end
				
				if nameBtn.Text ~= inst.Name then nameBtn.Text = inst.Name end
			end

			local setsBtn = row:FindFirstChild("SettingsBtn")
			if not setsBtn then
				setsBtn = Instance.new("TextLabel")
				setsBtn.Name = "SettingsBtn"
				setsBtn.Size = UDim2.new(0, 30, 1, 0)
				setsBtn.BackgroundTransparency = 1
				setsBtn.TextColor3 = Color3.new(1, 1, 1)
				setsBtn.Font = FONT
				setsBtn.TextSize = 14
				setsBtn.Text = ICONS.Settings
				setsBtn.Parent = row
			end
			setsBtn.Position = UDim2.new(1, -60, 0, 0)

			local espBtn = row:FindFirstChild("EspToggle")
			if espBtn then
				local isActive = getEspState(inst)
				local expectedEspText = isActive and ICONS.EyeOn or ICONS.EyeOff
				if espBtn.Text ~= expectedEspText then espBtn.Text = expectedEspText end
			end

			row.Parent = explorerScroll
			activeRows[i] = row
		elseif inst and activeRows[i] then
			-- Already exists, just update toggle state in case it changed
			local espBtn = activeRows[i]:FindFirstChild("EspToggle")
			if espBtn then
				local isActive = getEspState(inst)
				local expectedEspText = isActive and ICONS.EyeOn or ICONS.EyeOff
				if espBtn.Text ~= expectedEspText then espBtn.Text = expectedEspText end
			end
		elseif not inst and activeRows[i] then
			-- Instance GC'ed
			releaseRowToPool(activeRows[i])
			activeRows[i] = nil
		end
	end
end

-- Shared click handlers for pooled rows
addConnection(UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if selectionSettingsFrame.Visible or settingsFrame.Visible then return end
	
	-- Determine which row was clicked manually since we are using pooled rows
	-- This is more efficient than thousands of connections
	if not explorerScroll.Visible then return end
	
	local mousePos = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	local scrollPos = explorerScroll.AbsolutePosition
	local scrollSize = explorerScroll.AbsoluteSize
	
	if mousePos.X >= scrollPos.X and mousePos.X <= scrollPos.X + scrollSize.X and
	   mousePos.Y >= scrollPos.Y and mousePos.Y <= scrollPos.Y + scrollSize.Y then
		
		local relativeY = mousePos.Y - scrollPos.Y + explorerScroll.CanvasPosition.Y
		local idx = math.floor(relativeY / 20) + 1
		local node = currentFlatList[idx]
		local inst = node and node.Instance
		if not inst then return end
		
		local depth = node.Depth
		local padding = depth * 20
		local relX = mousePos.X - scrollPos.X
		
		-- Check which part of row was clicked
		if relX >= padding and relX < padding + 20 then
			-- Expand toggle
			if inst:IsA("Folder") or inst:IsA("Model") then
				expandedNodes[inst] = not expandedNodes[inst]
				refreshTree()
			end
		elseif relX >= scrollSize.X - 30 then
			-- ESP toggle
			toggleEsp(inst)
			updateViewport()
		elseif relX >= scrollSize.X - 60 and relX < scrollSize.X - 30 then
			-- Settings button
			currentSelection = inst
			selTitle.Text = "Settings: " .. inst.Name
			selectionSettingsFrame.Visible = true
			updateSelectionUI()
			updatePropertySettings()
		elseif relX >= padding + 40 then
			-- Name clicked (also expand if container)
			if inst:IsA("Folder") or inst:IsA("Model") then
				expandedNodes[inst] = not expandedNodes[inst]
				refreshTree()
			end
		end
	end
end))

refreshTree = function()
	if not ALIVE then return end
	renderRequest = renderRequest + 1
	
	-- Clear active rows
	for idx, row in pairs(activeRows) do
		releaseRowToPool(row)
	end
	table.clear(activeRows)
	
	-- Return nodes to pool
	for i = 1, #currentFlatList do
		releaseNodeToPool(currentFlatList[i])
	end
	table.clear(currentFlatList)

	local query = searchText ~= "" and searchText:lower() or nil
	for _, child in pairs(rootDirectory:GetChildren()) do
		buildFlatList(currentFlatList, child, 0, query)
	end
	
	explorerScroll.CanvasSize = UDim2.new(0, 0, 0, #currentFlatList * 20)
	updateViewport()
end

addConnection(explorerScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(updateViewport))
addConnection(explorerScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateViewport))
addConnection(activeScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(updateActiveViewport))
addConnection(activeScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateActiveViewport))

addConnection(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	searchText = searchBox.Text
	searchDebounceToken = searchDebounceToken + 1
	local myToken = searchDebounceToken
	task.wait(0.5)
	-- Only refresh if this is still the latest search request
	if searchDebounceToken == myToken and ALIVE then 
		refreshTree() 
	end
end))

refreshActiveList = function()
	if not ALIVE then return end
	
	-- Clear active rows
	for idx, row in pairs(activeTabRows) do
		releaseActiveRowToPool(row)
	end
	table.clear(activeTabRows)
	
	activeFlatList = {}
	for inst, _ in pairs(espTargets) do 
		if inst:IsDescendantOf(game) then
			table.insert(activeFlatList, inst) 
		end
	end
	for inst, _ in pairs(watchedFolders) do 
		if not espTargets[inst] and inst:IsDescendantOf(game) then 
			table.insert(activeFlatList, inst) 
		end
	end
	
	table.sort(activeFlatList, function(a, b) 
		return a.Name:lower() < b.Name:lower() 
	end)
	
	exportBtn.Visible = (currentTab == "Active" and #activeFlatList > 0)
	
	activeScroll.CanvasSize = UDim2.new(0, 0, 0, #activeFlatList * 40)
	updateActiveViewport()
end

addConnection(exportBtn.MouseButton1Click:Connect(function()
	exportTemplate()
	exportBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
	local oldText = exportBtn.Text
	exportBtn.Text = "✅ Template Copied to Clipboard!"
	task.delay(1.5, function()
		if exportBtn and exportBtn.Parent then
			exportBtn.BackgroundColor3 = Color3.fromRGB(60, 130, 180)
			exportBtn.Text = oldText
		end
	end)
end))

-- Animation Loop (Highly Optimized)
task.spawn(function()
	local updateCounter = 0
	local lastDistanceUpdate = 0
	local targetsToHighlight = {} -- Pre-allocated to prevent loop table churn
	
	while ALIVE and screenGui.Parent do
		local globalHue = (tick() % 5) / 5
		local rainbowColor = Color3.fromHSV(globalHue, 1, 1)
		
		-- Resolve player position
		local playerPos = nil
		local char = PLAYER.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then playerPos = hrp.Position end
		
		local showNames = SETTINGS.ShowNames
		local verticalOffset = SETTINGS.VerticalOffset
		local expectedOffset = Vector3.new(0, verticalOffset, 0)
		local maxDistance = SETTINGS.MaxDistance

		local now = tick()
		local shouldUpdateStrings = (now - lastDistanceUpdate >= 0.2)
		if shouldUpdateStrings then
			lastDistanceUpdate = now
		end

		-- Clear candidate list for this frame
		table.clear(targetsToHighlight)
		local targetsToHighlightCount = 0

		-- 1. Distance Calculations & Billboard Updates
		for inst, objs in pairs(espObjects) do
			if not inst:IsDescendantOf(Workspace) then
				continue
			end

			local root = objs.Root or inst
			local dist = 999999
			
			if root and root:IsA("BasePart") then
				local targetPos = root.Position
				if playerPos then
					dist = (playerPos - targetPos).Magnitude
				end
			end
			objs.CurrentDistance = dist

			-- Distance Culling for BillboardGui
			local gui = objs.GUI
			if gui then
				local withinRange = dist <= maxDistance
				if gui.Enabled ~= withinRange then
					gui.Enabled = withinRange
				end
				if withinRange and gui.StudsOffset ~= expectedOffset then
					gui.StudsOffset = expectedOffset
				end
			end

			-- Text Label Updates
			local label = objs.Label
			if label and label.Parent and dist <= maxDistance then
				local source = objs.Source or inst
				local s = targetSettings[source]
				local color = (s and s.Rainbow) and rainbowColor or (s and s.Color or Color3.new(1,0,0))
				
				if label.TextColor3 ~= color then label.TextColor3 = color end
				if label.Visible ~= showNames then label.Visible = showNames end
				
				-- Dynamic ESP Opacity support
				local targetTrans = 1 - SETTINGS.EspOpacity
				if label.TextTransparency ~= targetTrans then
					label.TextTransparency = targetTrans
				end
				local targetStrokeTrans = 0.5 + 0.5 * targetTrans
				if label.TextStrokeTransparency ~= targetStrokeTrans then
					label.TextStrokeTransparency = targetStrokeTrans
				end
				
				if showNames then
					if shouldUpdateStrings then
						if dist ~= objs.LastDistance or objs.PropertyString ~= objs.LastPropertyString then
							objs.LastDistance = math.floor(dist)
							objs.LastPropertyString = objs.PropertyString
							label.Text = inst.Name .. " [" .. objs.LastDistance .. "m]" .. (objs.PropertyString or "")
						end
					end
				elseif label.Text ~= inst.Name then
					label.Text = inst.Name
				end
			end

			-- Gather valid Highlight candidates
			if dist <= maxDistance then
				targetsToHighlightCount = targetsToHighlightCount + 1
				targetsToHighlight[targetsToHighlightCount] = objs
			else
				-- Release highlight if it is out of range
				local hl = objs.Highlight
				if hl then
					hl.Enabled = false
					hl.Adornee = nil
					table.insert(highlightPool, hl)
					objs.Highlight = nil
				end
			end
		end

		-- 2. Sort & Allocate Highlights dynamically by proximity
		if targetsToHighlightCount > 0 then
			table.sort(targetsToHighlight, function(a, b)
				return a.CurrentDistance < b.CurrentDistance
			end)

			local maxHighlights = SETTINGS.MaxHighlights
			for i = 1, targetsToHighlightCount do
				local objs = targetsToHighlight[i]
				local inst = objs.Instance
				
				if i <= maxHighlights then
					-- Assign highlight
					local hl = objs.Highlight
					if not hl then
						hl = table.remove(highlightPool)
						if not hl then
							hl = Instance.new("Highlight")
							hl.OutlineColor = Color3.new(1, 1, 1)
							hl.FillTransparency = 0.6
							hl.Parent = PLAYER_GUI
						end
						objs.Highlight = hl
					end

					if hl.Adornee ~= inst then hl.Adornee = inst end
					if not hl.Enabled then hl.Enabled = true end
					
					local source = objs.Source or inst
					local s = targetSettings[source]
					local color = (s and s.Rainbow) and rainbowColor or (s and s.Color or Color3.new(1,0,0))
					
					if objs.LastColor ~= color then
						objs.LastColor = color
						hl.FillColor = color
						hl.OutlineColor = color
					end
					if hl.OutlineTransparency ~= 0.5 then hl.OutlineTransparency = 0.5 end
				else
					-- Beyond max highlight count, release it
					local hl = objs.Highlight
					if hl then
						hl.Enabled = false
						hl.Adornee = nil
						table.insert(highlightPool, hl)
						objs.Highlight = nil
					end
				end
			end
		end

		-- 3. GC Protection: Clean selection if destroyed
		if currentSelection and not currentSelection:IsDescendantOf(Workspace) then
			currentSelection = nil
			selectionSettingsFrame.Visible = false
		end

		-- Animate rainbow preview box if needed
		if selectionSettingsFrame.Visible and currentSelection and targetSettings[currentSelection] then
			if targetSettings[currentSelection].Rainbow then
				previewBox.BackgroundColor3 = rainbowColor
			end
		end
		
		-- Periodic Status Bar Updates & Cleanup Sweep (every 5s)
		updateCounter = updateCounter + 1
		if updateCounter % 10 == 0 then
			updateStatusBar()
		end

		if updateCounter % 50 == 0 then
			for inst, _ in pairs(espObjects) do
				if not inst:IsDescendantOf(Workspace) then
					toggleEsp(inst, false)
				end
			end
			for inst, _ in pairs(watchedFolders) do
				if not inst:IsDescendantOf(Workspace) then
					toggleEsp(inst, false)
				end
			end
		end
		
		task.wait(0.1)
	end
end)

-- Template Application Engine
local function ApplyTemplate()
	local id = tostring(game.PlaceId)
	local template = GAME_TEMPLATES[id]
	if not template then return end
	
	-- Optimization: Pre-calculate candidate names to avoid GetFullName on every new instance
	local candidates = {}
	for _, entry in ipairs(template) do
		local segments = entry.Path:split(".")
		local leafName = segments[#segments]
		candidates[leafName] = true
	end
	
	local function checkAndApply(inst)
		local relPath = getRelativePath(inst)
		for _, entry in ipairs(template) do
			if entry.Path == relPath then
				-- Preset the color before toggling
				targetSettings[inst] = {
					Color = entry.Color,
					Rainbow = entry.Rainbow or false,
					TrackedProperties = entry.TrackedProperties or {},
					TrackAll = entry.TrackAll or false
				}
				toggleEsp(inst, true)
				return true
			end
		end
		return false
	end

	task.spawn(function()
		-- Initial pass
		for _, entry in ipairs(template) do
			local target = resolvePath(Workspace, entry.Path)
			if target then
				-- Preset the color before toggling
				targetSettings[target] = {
					Color = entry.Color,
					Rainbow = entry.Rainbow or false,
					TrackedProperties = entry.TrackedProperties or {},
					TrackAll = entry.TrackAll or false
				}
				toggleEsp(target, true)
			end
		end

		-- Dynamic loading (Optimized)
		addConnection(Workspace.DescendantAdded:Connect(function(desc)
			if not ALIVE then return end
			
			-- OPTIMIZATION: Quick filter by class and name before expensive path resolution
			if not (desc:IsA("BasePart") or desc:IsA("Model")) then return end
			if not candidates[desc.Name] then return end
			
			-- Brief delay to ensure properties/hierarchy are ready
			task.delay(0.1, function()
				if ALIVE and desc:IsDescendantOf(Workspace) then
					checkAndApply(desc)
				end
			end)
		end))
	end)
end

ApplyTemplate()
task.wait(0.2)
refreshTree()
updateStatusBar()