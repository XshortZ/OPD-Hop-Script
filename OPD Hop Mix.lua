-- // Finder All-in-One v1
-- // รวม Fruit Finder + Whitebeard Finder + Secret Dealer Finder
-- // มีหน้าเลือก Mode + บันทึก Config

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera

-- ==========================================
--  CONFIG URLs (แก้ตรงนี้)
-- ==========================================

local WEBHOOK_FRUIT = _G.WEBHOOK_FRUIT or ""
local WEBHOOK_WB    = _G.WEBHOOK_WB or ""
local WEBHOOK_SD    = _G.WEBHOOK_SD or ""

local NTFY_FRUIT = _G.NTFY_FRUIT or ""
local NTFY_WB    = _G.NTFY_WB or ""
local NTFY_SD    = _G.NTFY_SD or ""

local CHECK_INTERVAL  = 2
local PLACE_ID        = game.PlaceId

local TARGET_FRUITS = {
    "Paw","Candy","Chilly","Flare","Gas","Gravity","Gum",
    "Hollow","Light","Magma","Ope","Plasma","Rumble",
    "Sand","Smoke","Snow","String","Venom","Dark","Phoenix",
    "Vampire","Buddha"
}

-- ==========================================
--  WAIT
-- ==========================================
task.wait(3)
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(2)

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait() LocalPlayer = Players.LocalPlayer end
if not LocalPlayer.Character then LocalPlayer.CharacterAdded:Wait() end
local char = LocalPlayer.Character
char:WaitForChild("HumanoidRootPart")
char:WaitForChild("Humanoid")
local humanoid = char:FindFirstChild("Humanoid")
while humanoid:GetState() == Enum.HumanoidStateType.Dead do
    humanoid.StateChanged:Wait()
end
LocalPlayer:WaitForChild("Backpack")
while #Players:GetPlayers() < 1 do Players.PlayerAdded:Wait() end

-- ==========================================
--  CONFIG SAVE/LOAD
-- ==========================================
local CONFIG_FILE = "FinderConfig.json"
local config = {
    mode = nil,           -- "fruit" / "whitebeard" / "secretdealer"
    autoPickup = false,
    cameraLock = false,
}

local function saveConfig()
    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(config))
    end)
end

local function loadConfig()
    local ok = pcall(function()
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        config.mode       = data.mode or nil
        config.autoPickup = data.autoPickup ~= nil and data.autoPickup or true
        config.cameraLock = data.cameraLock or false
    end)
    return ok
end

loadConfig()

-- ==========================================
--  HOP SYSTEM (ใช้ร่วมกัน)
-- ==========================================
local AllIDs = {}
local foundAnything = ""
local actualHour = math.floor(os.time() / 600)

local fileOk = pcall(function()
    AllIDs = HttpService:JSONDecode(readfile("NotSameServers.json"))
end)
if not fileOk then
    table.insert(AllIDs, actualHour)
    writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs))
end

local function TPReturner()
    local url = 'https://games.roblox.com/v1/games/' .. PLACE_ID .. '/servers/Public?sortOrder=Asc&limit=100'
    if foundAnything ~= "" then url = url .. '&cursor=' .. foundAnything end
    local Site = HttpService:JSONDecode(game:HttpGet(url))
    if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
        foundAnything = Site.nextPageCursor
    end
    for _, v in pairs(Site.data) do
        local ID = tostring(v.id)
        local Possible = true
        local num = 0
        if tonumber(v.maxPlayers) > tonumber(v.playing) then
            for _, Existing in pairs(AllIDs) do
                if num ~= 0 then
                    if ID == tostring(Existing) then Possible = false end
                else
                    if tonumber(actualHour) ~= tonumber(Existing) then
                        pcall(function()
                            delfile("NotSameServers.json")
                            AllIDs = {}
                            table.insert(AllIDs, actualHour)
                        end)
                    end
                end
                num = num + 1
            end
            if Possible then
                table.insert(AllIDs, ID)
                pcall(function()
    if paused then return end
    writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs))
    if not paused then
        TeleportService:TeleportToPlaceInstance(PLACE_ID, ID, LocalPlayer)
    end
end)
                task.wait(4)
                return
            end
        end
    end
end

local statusLabel -- ประกาศไว้ก่อน ใช้ใน hopServer
local loopRunning = false
local paused = false

local function hopServer(label)
    if paused then return end
    warn("[Finder] ไม่พบเป้าหมาย → Hopping...")
    if statusLabel then statusLabel.Text = "🔄 กำลัง Hop..." end
    if paused then return end
    pcall(function()
        if paused then return end
        TPReturner()
    end)
    if paused then return end
    if foundAnything ~= "" then
        pcall(function()
            if paused then return end
            TPReturner()
        end)
    end
end

-- ==========================================
--  NTFY + WEBHOOK helpers
-- ==========================================
local function sendNtfy(topic, title, body)
    pcall(function()
        request({
            Url = "https://ntfy.sh/" .. topic,
            Method = "POST",
            Headers = {
                ["Title"] = title,
                ["Priority"] = "urgent",
                ["Content-Type"] = "text/plain"
            },
            Body = body
        })
    end)
end

local function sendWebhookRaw(url, payload)
    local body = HttpService:JSONEncode(payload)
    local ok = false
    pcall(function() request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body }) ok = true end)
    if not ok then pcall(function() syn.request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body }) end) end
end

local function makeJoinCmd(serverId)
    return string.format('Roblox.GameLauncher.joinGameInstance(%s, "%s")', tostring(PLACE_ID), tostring(serverId))
end

local function baseFields(serverId)
    local cmd = makeJoinCmd(serverId)
    return {
        { name = "🆔  Server ID", value = "```"..tostring(serverId).."```", inline = false },
        { name = "🎮  Place ID",  value = "```"..tostring(PLACE_ID).."```", inline = true  },
        { name = "🌐  วิธีเข้าเซิร์ฟ", value = "**1.** เปิด `roblox.com`\n**2.** กด `F12` → Console\n**3.** วาง command", inline = false },
        { name = "📋  Command", value = "```js\n"..cmd.."\n```", inline = false },
    }
end

-- ==========================================
--  SELECT SCREEN UI
-- ==========================================
local selectGui = Instance.new("ScreenGui")
selectGui.Name = "FinderSelectUI"
selectGui.ResetOnSpawn = false
selectGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
selectGui.Parent = LocalPlayer.PlayerGui

local selFrame = Instance.new("Frame")
selFrame.Size = UDim2.new(0, 280, 0, 280)
selFrame.Position = UDim2.new(0.5, -140, 0.5, -140)
selFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
selFrame.BorderSizePixel = 0
selFrame.Parent = selectGui
Instance.new("UICorner", selFrame).CornerRadius = UDim.new(0, 12)

local selTitle = Instance.new("TextLabel")
selTitle.Size = UDim2.new(1, 0, 0, 50)
selTitle.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
selTitle.BorderSizePixel = 0
selTitle.Text = "🔍  เลือก Finder Mode"
selTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
selTitle.TextSize = 15
selTitle.Font = Enum.Font.GothamBold
selTitle.Parent = selFrame
Instance.new("UICorner", selTitle).CornerRadius = UDim.new(0, 12)

local function makeSelBtn(text, color, posY)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -30, 0, 55)
    btn.Position = UDim2.new(0, 15, 0, posY)
    btn.BackgroundColor3 = color
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.Parent = selFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    return btn
end

local btnFruit = makeSelBtn("🍎  Fruit Finder",         Color3.fromRGB(180, 80,  30),  60)
local btnWB    = makeSelBtn("⚓  Whitebeard Finder",    Color3.fromRGB(40,  80,  160), 125)
local btnSD    = makeSelBtn("🃏  Secret Dealer Finder", Color3.fromRGB(100, 30,  150), 190)

local selHint = Instance.new("TextLabel")
selHint.Size = UDim2.new(1, -20, 0, 20)
selHint.Position = UDim2.new(0, 10, 0, 253)
selHint.BackgroundTransparency = 1
selHint.Text = ""
selHint.TextColor3 = Color3.fromRGB(150, 150, 150)
selHint.TextSize = 11
selHint.Font = Enum.Font.Gotham
selHint.Parent = selFrame

if config.mode then
    selHint.Text = "💾 บันทึกล่าสุด: " .. config.mode .. "  (กดเพื่อเปลี่ยน)"
end

-- ==========================================
--  MAIN UI (สร้างไว้ก่อน ซ่อนอยู่)
-- ==========================================
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "FinderMainUI"
mainGui.ResetOnSpawn = false
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
mainGui.Parent = LocalPlayer.PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 410)
mainFrame.Position = UDim2.new(0, 20, 0.5, -185)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Visible = false
mainFrame.Parent = mainGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -10, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🔍 Finder"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 30)
statusLabel.Position = UDim2.new(0, 10, 0, 48)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "⏳ กำลังสแกน..."
statusLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
statusLabel.TextSize = 13
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

local foundListLabel = Instance.new("TextLabel")
foundListLabel.Size = UDim2.new(1, -20, 0, 80)
foundListLabel.Position = UDim2.new(0, 10, 0, 82)
foundListLabel.BackgroundTransparency = 1
foundListLabel.Text = "พบ: -"
foundListLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
foundListLabel.TextSize = 11
foundListLabel.Font = Enum.Font.Gotham
foundListLabel.TextXAlignment = Enum.TextXAlignment.Left
foundListLabel.TextYAlignment = Enum.TextYAlignment.Top
foundListLabel.TextWrapped = true
foundListLabel.Parent = mainFrame

local countLabel = Instance.new("TextLabel")
countLabel.Size = UDim2.new(1, -20, 0, 20)
countLabel.Position = UDim2.new(0, 10, 0, 165)
countLabel.BackgroundTransparency = 1
countLabel.Text = "รวม: 0"
countLabel.TextColor3 = Color3.fromRGB(255, 170, 50)
countLabel.TextSize = 11
countLabel.Font = Enum.Font.GothamBold
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Parent = mainFrame

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -20, 0, 1)
divider.Position = UDim2.new(0, 10, 0, 192)
divider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
divider.BorderSizePixel = 0
divider.Parent = mainFrame

-- Camera Lock (Fruit + SecretDealer)
local camBtn = Instance.new("TextButton")
camBtn.Size = UDim2.new(1, -20, 0, 35)
camBtn.Position = UDim2.new(0, 10, 0, 200)
camBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
camBtn.BorderSizePixel = 0
camBtn.Text = "📷 Camera Lock: OFF"
camBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
camBtn.TextSize = 13
camBtn.Font = Enum.Font.GothamBold
camBtn.Visible = false
camBtn.Parent = mainFrame
Instance.new("UICorner", camBtn).CornerRadius = UDim.new(0, 6)

local zoomLabel = Instance.new("TextLabel")
zoomLabel.Size = UDim2.new(1, -20, 0, 20)
zoomLabel.Position = UDim2.new(0, 10, 0, 240)
zoomLabel.BackgroundTransparency = 1
zoomLabel.Text = "🔍 I = ใกล้  /  O = ไกล  /  Q = ปิด"
zoomLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
zoomLabel.TextSize = 10
zoomLabel.Font = Enum.Font.Gotham
zoomLabel.TextXAlignment = Enum.TextXAlignment.Left
zoomLabel.Visible = false
zoomLabel.Parent = mainFrame

-- Auto Pickup (Fruit เท่านั้น)
local pickupBtn = Instance.new("TextButton")
pickupBtn.Size = UDim2.new(1, -20, 0, 30)
pickupBtn.Position = UDim2.new(0, 10, 0, 262)
pickupBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
pickupBtn.BorderSizePixel = 0
pickupBtn.Text = "🧲 Auto Pickup: ON"
pickupBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
pickupBtn.TextSize = 12
pickupBtn.Font = Enum.Font.GothamBold
pickupBtn.Visible = false
pickupBtn.Parent = mainFrame
Instance.new("UICorner", pickupBtn).CornerRadius = UDim.new(0, 6)

-- Hop Button
-- Dropdown label
local camTargetLabel = Instance.new("TextLabel")
camTargetLabel.Size = UDim2.new(1, -20, 0, 18)
camTargetLabel.Position = UDim2.new(0, 10, 0, 275)
camTargetLabel.BackgroundTransparency = 1
camTargetLabel.Text = "🎯 Lock ไปที่: -"
camTargetLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
camTargetLabel.TextSize = 10
camTargetLabel.Font = Enum.Font.Gotham
camTargetLabel.TextXAlignment = Enum.TextXAlignment.Left
camTargetLabel.TextWrapped = true
camTargetLabel.Visible = false
camTargetLabel.Parent = mainFrame

local prevBtn = Instance.new("TextButton")
prevBtn.Size = UDim2.new(0, 28, 0, 22)
prevBtn.Position = UDim2.new(0, 10, 0, 295)
prevBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
prevBtn.BorderSizePixel = 0
prevBtn.Text = "◀"
prevBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
prevBtn.TextSize = 12
prevBtn.Font = Enum.Font.GothamBold
prevBtn.Visible = false
prevBtn.Parent = mainFrame
Instance.new("UICorner", prevBtn).CornerRadius = UDim.new(0, 4)

local nextBtn = Instance.new("TextButton")
nextBtn.Size = UDim2.new(0, 28, 0, 22)
nextBtn.Position = UDim2.new(0, 202, 0, 295)
nextBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
nextBtn.BorderSizePixel = 0
nextBtn.Text = "▶"
nextBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
nextBtn.TextSize = 12
nextBtn.Font = Enum.Font.GothamBold
nextBtn.Visible = false
nextBtn.Parent = mainFrame
Instance.new("UICorner", nextBtn).CornerRadius = UDim.new(0, 4)

local camTargetNameLabel = Instance.new("TextLabel")
camTargetNameLabel.Size = UDim2.new(0, 150, 0, 22)
camTargetNameLabel.Position = UDim2.new(0, 42, 0, 295)
camTargetNameLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
camTargetNameLabel.BorderSizePixel = 0
camTargetNameLabel.Text = "-"
camTargetNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
camTargetNameLabel.TextSize = 11
camTargetNameLabel.Font = Enum.Font.Gotham
camTargetNameLabel.Visible = false
camTargetNameLabel.Parent = mainFrame
Instance.new("UICorner", camTargetNameLabel).CornerRadius = UDim.new(0, 4)

local hopBtn = Instance.new("TextButton")
hopBtn.Size = UDim2.new(1, -20, 0, 35)
hopBtn.Position = UDim2.new(0, 10, 0, 310)
hopBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
hopBtn.BorderSizePixel = 0
hopBtn.Text = "🔄 Hop Server"
hopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hopBtn.TextSize = 13
hopBtn.Font = Enum.Font.GothamBold
hopBtn.Parent = mainFrame
Instance.new("UICorner", hopBtn).CornerRadius = UDim.new(0, 6)

-- เปลี่ยน Mode Button
local switchBtn = Instance.new("TextButton")
switchBtn.Size = UDim2.new(1, -20, 0, 28)
switchBtn.Position = UDim2.new(0, 10, 0, 350)
switchBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
switchBtn.BorderSizePixel = 0
switchBtn.Text = "⚙️ เปลี่ยน Mode"
switchBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
switchBtn.TextSize = 12
switchBtn.Font = Enum.Font.GothamBold
switchBtn.Parent = mainFrame
Instance.new("UICorner", switchBtn).CornerRadius = UDim.new(0, 6)

-- ==========================================
--  STATE
-- ==========================================
local currentMode = nil
local foundTarget = false
local cameraLocked = false
local targetObj = nil
local camTargetList = {}  -- รายชื่อเป้าหมายที่เลือก lock ได้
local camTargetIndex = 1  -- index ปัจจุบัน

local function updateCamTargetUI()
    if #camTargetList == 0 then
        camTargetNameLabel.Text = "-"
        camTargetLabel.Text = "🎯 Lock ไปที่: -"
        return
    end
    local t = camTargetList[camTargetIndex]
    camTargetNameLabel.Text = t.label
    camTargetLabel.Text = "🎯 Lock ไปที่: (" .. camTargetIndex .. "/" .. #camTargetList .. ")"
    -- อัปเดต targetObj ตามที่เลือก
    targetObj = t.obj
end

prevBtn.MouseButton1Click:Connect(function()
    if #camTargetList == 0 then return end
    camTargetIndex = camTargetIndex - 1
    if camTargetIndex < 1 then camTargetIndex = #camTargetList end
    updateCamTargetUI()
end)

nextBtn.MouseButton1Click:Connect(function()
    if #camTargetList == 0 then return end
    camTargetIndex = camTargetIndex + 1
    if camTargetIndex > #camTargetList then camTargetIndex = 1 end
    updateCamTargetUI()
end)
local CAM_HEIGHT = 20
local CAM_DISTANCE = 40
local ZOOM_STEP = 5
local MIN_DISTANCE = 5
local MAX_DISTANCE = 100

-- ==========================================
--  CAMERA
-- ==========================================
RunService:BindToRenderStep("FinderCamLock", Enum.RenderPriority.Camera.Value + 1, function()
    if not cameraLocked then return end
    local hrp
    if currentMode == "fruit" and targetObj then
        if typeof(targetObj) == "Instance" and targetObj:IsA("Player") and targetObj.Character then
            hrp = targetObj.Character:FindFirstChild("HumanoidRootPart")
        elseif typeof(targetObj) == "Instance" and targetObj:IsA("BasePart") then
            hrp = targetObj
        end
    elseif (currentMode == "whitebeard" or currentMode == "secretdealer") and targetObj and targetObj.Parent then
        hrp = targetObj
    end
    if hrp then
        local offset = hrp.CFrame * CFrame.new(0, CAM_HEIGHT, CAM_DISTANCE)
        Camera.CFrame = CFrame.new(offset.Position, hrp.Position)
    end
end)

camBtn.MouseButton1Click:Connect(function()
    if not foundTarget then statusLabel.Text = "⚠️ ยังไม่เจอเป้าหมาย!" return end
    cameraLocked = not cameraLocked
    config.cameraLock = cameraLocked
    saveConfig()
    if cameraLocked then
        Camera.CameraType = Enum.CameraType.Scriptable
        camBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
        camBtn.Text = "📷 Camera Lock: ON"
    else
        Camera.CameraType = Enum.CameraType.Custom
        camBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        camBtn.Text = "📷 Camera Lock: OFF"
        camTargetList = {}
    camTargetIndex = 1
    camTargetLabel.Visible = false
    prevBtn.Visible = false
    nextBtn.Visible = false
    camTargetNameLabel.Visible = false
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or not cameraLocked then return end
    if input.KeyCode == Enum.KeyCode.I then
        CAM_DISTANCE = math.max(MIN_DISTANCE, CAM_DISTANCE - ZOOM_STEP)
    elseif input.KeyCode == Enum.KeyCode.O then
        CAM_DISTANCE = math.min(MAX_DISTANCE, CAM_DISTANCE + ZOOM_STEP)
    elseif input.KeyCode == Enum.KeyCode.Q then
        cameraLocked = false
        Camera.CameraType = Enum.CameraType.Custom
        camBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        camBtn.Text = "📷 Camera Lock: OFF"
        config.cameraLock = false
        saveConfig()
    end
end)

-- Auto Pickup toggle
pickupBtn.MouseButton1Click:Connect(function()
    config.autoPickup = not config.autoPickup
    saveConfig()
    if config.autoPickup then
        pickupBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
        pickupBtn.Text = "🧲 Auto Pickup: ON"
    else
        pickupBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        pickupBtn.Text = "🧲 Auto Pickup: OFF"
    end
end)

-- ==========================================
--  RESET UI
-- ==========================================
local function resetMainUI()
    foundTarget = false
    targetObj = nil
    cameraLocked = false
    Camera.CameraType = Enum.CameraType.Custom
    statusLabel.Text = "⏳ กำลังสแกน..."
    statusLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
    foundListLabel.Text = "พบ: -"
    countLabel.Text = "รวม: 0"
    camBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    camBtn.Text = "📷 Camera Lock: OFF"
    camTargetList = {}
    camTargetIndex = 1
    camTargetLabel.Visible = false
    prevBtn.Visible = false
    nextBtn.Visible = false
    camTargetNameLabel.Visible = false
end

-- Hop button
hopBtn.MouseButton1Click:Connect(function()
    hopBtn.Text = "⏳ กำลัง Hop..."
    hopBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    resetMainUI()
    hopServer()
    task.wait(1)
    hopBtn.Text = "🔄 Hop Server"
    hopBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
end)

-- Switch Mode button
switchBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    selFrame.Visible = true
    selectGui.Enabled = true
    resetMainUI()
end)

-- ==========================================
--  SCAN FUNCTIONS
-- ==========================================
local function isTargetFruit(itemName)
    for _, fruit in pairs(TARGET_FRUITS) do
        if string.lower(itemName) == string.lower(fruit .. " Fruit")
        or string.lower(itemName) == string.lower(fruit .. "fruit") then
            return true
        end
    end
    return false
end

local function scanFruits()
    local results = {}
    local seen = {}
    for _, player in pairs(Players:GetPlayers()) do
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, item in pairs(backpack:GetChildren()) do
                local key = player.Name .. item.Name
                if isTargetFruit(item.Name) and not seen[key] then
                    seen[key] = true
                    table.insert(results, {player = player, item = item.Name})
                end
            end
        end
        if player.Character then
            for _, item in pairs(player.Character:GetChildren()) do
                local key = player.Name .. item.Name
                if item:IsA("Tool") and isTargetFruit(item.Name) and not seen[key] then
                    seen[key] = true
                    table.insert(results, {player = player, item = item.Name})
                end
            end
        end
    end
    -- สแกนผลใน Workspace
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") and isTargetFruit(obj.Name) and not obj:IsDescendantOf(Players) then
            local key = "world_" .. obj.Name
            if not seen[key] then
                seen[key] = true
                table.insert(results, {player = nil, item = obj.Name})
            end
        end
    end
    return results
end

local function scanWhitebeard()
    local results = {}
    local function checkModel(model)
        if model == LocalPlayer.Character then return end
        if not model:IsA("Model") then return end
        if string.lower(model.Name):find("whitebeard") then
            local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
            table.insert(results, {name = model.Name, root = hrp})
        end
    end
    for _, obj in pairs(workspace:GetChildren()) do
        checkModel(obj)
        if obj:IsA("Folder") or obj:IsA("Model") then
            for _, child in pairs(obj:GetChildren()) do checkModel(child) end
        end
    end
    return results
end

local function scanSecretDealer()
    local results = {}
    local function checkModel(model)
        if not model:IsA("Model") then return end
        if string.lower(model.Name):find("secret dealer") then
            local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
            table.insert(results, {name = model.Name, root = hrp})
        end
    end
    local ignore = workspace:FindFirstChild("Ignore")
    if ignore then
        local npcs = ignore:FindFirstChild("NPCs")
        if npcs then
            for _, obj in pairs(npcs:GetChildren()) do
                checkModel(obj)
                if obj:IsA("Folder") or obj:IsA("Model") then
                    for _, child in pairs(obj:GetChildren()) do checkModel(child) end
                end
            end
        end
        for _, obj in pairs(ignore:GetChildren()) do
            if obj.Name ~= "NPCs" and obj.Name ~= "HitBox" then checkModel(obj) end
        end
    end
    for _, obj in pairs(workspace:GetChildren()) do
        if obj.Name ~= "Ignore" then
            checkModel(obj)
            if obj:IsA("Folder") or obj:IsA("Model") then
                for _, child in pairs(obj:GetChildren()) do checkModel(child) end
            end
        end
    end
    return results
end

local function tryPickupFruit()
    if not config.autoPickup then return end
    for _, obj in pairs(workspace:GetChildren()) do
        if obj:IsA("Tool") and isTargetFruit(obj.Name) then
            for _, part in pairs(obj:GetDescendants()) do
                if part:IsA("ClickDetector") then
                    fireclickdetector(part)
                    warn("[Finder] 🧲 คลิกผล: " .. obj.Name)
                    task.wait(0.2)
                end
            end
        end
    end
end

-- ==========================================
--  WEBHOOK SENDERS
-- ==========================================
local function getFruitColor(n)
    n = string.lower(n)
    if n:find("dark")    then return 7419530  end
    if n:find("phoenix") then return 15105570 end
    if n:find("venom")   then return 3394611  end
    if n:find("light")   then return 16776960 end
    if n:find("magma")   then return 15746887 end
    if n:find("rumble")  then return 3447003  end
    if n:find("gravity") then return 10181046 end
    return 3066993
end

local function webhookFruit(allFruits, serverId)
    local fruitList = ""
    for i, f in pairs(allFruits) do
        local who = f.player and f.player.Name or "Workspace"
        fruitList = fruitList .. "**"..i..".** "..f.item.."  →  `"..who.."`\n"
    end
    local fields = {{ name="🍑 Fruit ที่พบ ("..#allFruits.." รายการ)", value=fruitList, inline=false }}
    for _, f in pairs(baseFields(serverId)) do table.insert(fields, f) end
    local title = #allFruits == 1 and "✅ พบ Fruit 1 รายการ!" or "✅ พบ Fruit "..#allFruits.." รายการ!"
    sendWebhookRaw(WEBHOOK_FRUIT, {
        username = "🍎 Fruit Finder",
        embeds = {{ title=title, description="มีผลไม้หายากในเซิร์ฟ!", color=getFruitColor(allFruits[1].item), fields=fields, footer={text="Finder v1"}, timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ") }}
    })
    local body = ""
    for _, f in pairs(allFruits) do body = body .. "🍑 "..f.item.."\n" end
    sendNtfy(NTFY_FRUIT, "พบ "..#allFruits.." Fruit!", body .. "\nJoin:\n" .. makeJoinCmd(serverId))
end

local function webhookWB(allTargets, serverId)
    local list = ""
    for i, t in pairs(allTargets) do list = list .. "**"..i..".** `"..t.name.."`\n" end
    local fields = {{ name="⚓ Whitebeard ("..#allTargets.." ตัว)", value=list, inline=false }}
    for _, f in pairs(baseFields(serverId)) do table.insert(fields, f) end
    local title = "✅ พบ Whitebeard "..#allTargets.." ตัว!"
    sendWebhookRaw(WEBHOOK_WB, {
        username = "⚓ Whitebeard Finder",
        embeds = {{ title=title, description="พบ Whitebeard รีบเข้า!", color=3426654, fields=fields, footer={text="Finder v1"}, timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ") }}
    })
    local body = ""
    for _, t in pairs(allTargets) do body = body .. "⚓ "..t.name.."\n" end
    sendNtfy(NTFY_WB, "พบ Whitebeard!", body .. "\nJoin:\n" .. makeJoinCmd(serverId))
end

local function webhookSD(allTargets, serverId)
    local list = ""
    for i, t in pairs(allTargets) do list = list .. "**"..i..".** `"..t.name.."`\n" end
    local fields = {{ name="🃏 Secret Dealer ("..#allTargets.." ตัว)", value=list, inline=false }}
    for _, f in pairs(baseFields(serverId)) do table.insert(fields, f) end
    sendWebhookRaw(WEBHOOK_SD, {
        username = "🃏 Secret Dealer Finder",
        embeds = {{ title="✅ พบ Secret Dealer!", description="รีบเข้าก่อนหมดเวลา!", color=10181046, fields=fields, footer={text="Finder v1"}, timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ") }}
    })
    local body = ""
    for _, t in pairs(allTargets) do body = body .. "🃏 "..t.name.."\n" end
    sendNtfy(NTFY_SD, "พบ Secret Dealer!", body .. "\nJoin:\n" .. makeJoinCmd(serverId))
end

-- ==========================================
--  START MODE
-- ==========================================

local function startMode(mode)
    if loopRunning then return end
    currentMode = mode
    config.mode = mode
    saveConfig()
    loopRunning = true
    paused = false

    -- ตั้ง UI ตาม mode
    if mode == "fruit" then
        titleLabel.Text = "🍎 Fruit Finder"
        camBtn.Visible = true
        zoomLabel.Visible = true
        pickupBtn.Visible = true
        pickupBtn.Text = config.autoPickup and "🧲 Auto Pickup: ON" or "🧲 Auto Pickup: OFF"
        pickupBtn.BackgroundColor3 = config.autoPickup and Color3.fromRGB(30,120,30) or Color3.fromRGB(100,100,100)
        foundListLabel.Text = "พบ Fruit: -"
    elseif mode == "whitebeard" then
        titleLabel.Text = "⚓ Whitebeard Finder"
        camBtn.Visible = false
        zoomLabel.Visible = false
        pickupBtn.Visible = false
        foundListLabel.Text = "พบ Whitebeard: -"
    elseif mode == "secretdealer" then
        titleLabel.Text = "🃏 Secret Dealer Finder"
        camBtn.Visible = true
        zoomLabel.Visible = true
        pickupBtn.Visible = false
        foundListLabel.Text = "พบ Secret Dealer: -"
    end

    selectGui.Enabled = false
    selFrame.Visible = false
    mainFrame.Visible = true

    print("[Finder] เริ่ม mode: " .. mode)

    task.spawn(function()
        while loopRunning do
            if mode == "fruit" then
                local allFruits = scanFruits()
                if #allFruits > 0 then
                    if not foundTarget then
                        foundTarget = true
                        targetObj = allFruits[1].player
                        statusLabel.Text = "✅ พบ " .. #allFruits .. " Fruit!"
                        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                        local txt = ""
                        for i, f in pairs(allFruits) do
                            local who = f.player and f.player.Name or "Workspace"
                            txt = txt .. i .. ". " .. f.item .. " (" .. who .. ")\n"
                        end
                        foundListLabel.Text = txt
                        countLabel.Text = "รวม: " .. #allFruits .. " Fruit"
                        webhookFruit(allFruits, game.JobId)
                        if targetObj then
                            cameraLocked = true
                            Camera.CameraType = Enum.CameraType.Scriptable
                            camBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
                            camBtn.Text = "📷 Camera Lock: ON"
                        end
                    end
                    -- อัปเดต UI real-time ทุกรอบ
                    -- อัปเดต UI real-time ทุกรอบ
                    local txt = ""
                    local newList = {}
                    local seen2 = {}
                    for i, f in pairs(allFruits) do
                        local who = f.player and f.player.Name or "🌍 Workspace"
                        txt = txt .. i .. ". " .. f.item .. " (" .. who .. ")\n"
                        -- สร้าง camTargetList ไม่ซ้ำกัน
                        local key2 = who
                        if not seen2[key2] then
                            seen2[key2] = true
                            local obj
                            if f.player then
                                obj = f.player
                            else
                                -- หา Tool ใน Workspace
                                for _, wobj in pairs(workspace:GetChildren()) do
                                    if wobj:IsA("Tool") and wobj.Name == f.item then
                                        obj = wobj:FindFirstChildWhichIsA("BasePart")
                                        break
                                    end
                                end
                            end
                            table.insert(newList, {label = who .. " (" .. f.item .. ")", obj = obj, isPlayer = f.player ~= nil})
                        end
                    end
                    foundListLabel.Text = txt
                    countLabel.Text = "รวม: " .. #allFruits .. " Fruit"
                    -- อัปเดต dropdown ถ้ารายการเปลี่ยน
                    if #newList ~= #camTargetList then
                        camTargetList = newList
                        camTargetIndex = 1
                        camTargetLabel.Visible = true
                        prevBtn.Visible = true
                        nextBtn.Visible = true
                        camTargetNameLabel.Visible = true
                        updateCamTargetUI()
                    end
                    tryPickupFruit()
                    task.wait(CHECK_INTERVAL)
                else
    -- เช็คผลใน Workspace ก่อน hop
    local fruitInWorld = false
    for _, obj in pairs(workspace:GetChildren()) do
        if obj:IsA("Tool") and isTargetFruit(obj.Name) then
            fruitInWorld = true
            break
        end
    end

    if fruitInWorld then
        -- ผลยังอยู่ใน Workspace ไม่ hop
        statusLabel.Text = "🧲 ผลอยู่ใน Workspace กำลังดึง..."
        statusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        tryPickupFruit()
        task.wait(CHECK_INTERVAL)
    else
        if foundTarget then
            statusLabel.Text = "❌ Fruit หายไป → Hopping..."
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            foundTarget = false
            targetObj = nil
            cameraLocked = false
            Camera.CameraType = Enum.CameraType.Custom
            camBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            camBtn.Text = "📷 Camera Lock: OFF"
            foundListLabel.Text = "พบ Fruit: -"
            countLabel.Text = "รวม: 0"
        end
        hopServer()
        task.wait(CHECK_INTERVAL)
    end
end

            elseif mode == "whitebeard" then
                local allTargets = scanWhitebeard()
                if #allTargets > 0 then
                    if not foundTarget then
                        foundTarget = true
                        targetObj = allTargets[1].root
                        statusLabel.Text = "✅ พบ " .. #allTargets .. " Whitebeard!"
                        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                        local txt = ""
                        for i, t in pairs(allTargets) do txt = txt .. i .. ". " .. t.name .. "\n" end
                        foundListLabel.Text = txt
                        countLabel.Text = "รวม: " .. #allTargets .. " ตัว"
                        webhookWB(allTargets, game.JobId)
                    end
                    task.wait(CHECK_INTERVAL)
                else
                    if foundTarget then
                        statusLabel.Text = "❌ Whitebeard หายไป → Hopping..."
                        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                        foundTarget = false
                        foundListLabel.Text = "พบ Whitebeard: -"
                        countLabel.Text = "รวม: 0"
                    end
                    hopServer()
                    task.wait(CHECK_INTERVAL)
                end

            elseif mode == "secretdealer" then
                local allTargets = scanSecretDealer()
                if #allTargets > 0 then
                    if not foundTarget then
                        foundTarget = true
                        targetObj = allTargets[1].root
                        statusLabel.Text = "✅ พบ Secret Dealer!"
                        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                        local txt = ""
                        for i, t in pairs(allTargets) do txt = txt .. i .. ". " .. t.name .. "\n" end
                        foundListLabel.Text = txt
                        countLabel.Text = "รวม: " .. #allTargets .. " ตัว"
                        webhookSD(allTargets, game.JobId)
                        if targetObj then
                            cameraLocked = true
                            Camera.CameraType = Enum.CameraType.Scriptable
                            camBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
                            camBtn.Text = "📷 Camera Lock: ON"
                        end
                    end
                    task.wait(CHECK_INTERVAL)
                else
                    if foundTarget then
                        statusLabel.Text = "❌ Secret Dealer หายไป → Hopping..."
                        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                        foundTarget = false
                        targetObj = nil
                        cameraLocked = false
                        Camera.CameraType = Enum.CameraType.Custom
                        camBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                        camBtn.Text = "📷 Camera Lock: OFF"
                        foundListLabel.Text = "พบ Secret Dealer: -"
                        countLabel.Text = "รวม: 0"
                    end
                    hopServer()
                    task.wait(CHECK_INTERVAL)
                end
            end
        end
    end)
end

-- Switch mode ปิด loop เก่า แล้วเริ่มใหม่
switchBtn.MouseButton1Click:Connect(function()
    loopRunning = false
    mainFrame.Visible = false
    selFrame.Visible = true
    selectGui.Enabled = true
    resetMainUI()
    task.wait(0.1)
end)

-- ==========================================
--  SELECT BUTTONS
-- ==========================================
btnFruit.MouseButton1Click:Connect(function() startMode("fruit") end)
btnWB.MouseButton1Click:Connect(function()    startMode("whitebeard") end)
btnSD.MouseButton1Click:Connect(function()    startMode("secretdealer") end)

-- Hotkey กด M เปิดหน้าเลือก Mode
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.M then
    loopRunning = false
    paused = true
    mainFrame.Visible = false
    selFrame.Visible = true
    selectGui.Enabled = true
    resetMainUI()
    warn("[Finder] กด M → เปิดหน้าเลือก Mode")
end
end)

-- ==========================================
--  AUTO START จาก config
-- ==========================================
if config.mode then
    startMode(config.mode)
else
    selFrame.Visible = true
    selectGui.Enabled = true
end
