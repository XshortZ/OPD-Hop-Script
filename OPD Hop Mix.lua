-- // Finder Multi-Mode v2
-- // เลือกได้หลาย Mode พร้อมกัน: Fruit / Whitebeard / Secret Dealer
-- // Hop เมื่อไม่เจอเป้าหมายของทุก mode ที่เลือก

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera

-- ==========================================
--  CONFIG (ใส่ค่าผ่าน _G ก่อน loadstring)
-- ==========================================
local WEBHOOK_FRUIT = _G.WEBHOOK_FRUIT or ""
local WEBHOOK_WB    = _G.WEBHOOK_WB or ""
local WEBHOOK_SD    = _G.WEBHOOK_SD or ""
local NTFY_FRUIT     = _G.NTFY_FRUIT or ""
local NTFY_WB        = _G.NTFY_WB or ""
local NTFY_SD        = _G.NTFY_SD or ""

local CHECK_INTERVAL = 2
local PLACE_ID = game.PlaceId

-- ==========================================
--  CYBER THEME PALETTE
-- ==========================================
local THEME = {
    Bg        = Color3.fromRGB(8, 9, 16),
    Panel     = Color3.fromRGB(14, 16, 26),
    PanelAlt  = Color3.fromRGB(19, 21, 34),
    Stroke    = Color3.fromRGB(0, 230, 255),
    Cyan      = Color3.fromRGB(0, 230, 255),
    Magenta   = Color3.fromRGB(255, 50, 170),
    Purple    = Color3.fromRGB(150, 80, 255),
    Green     = Color3.fromRGB(60, 255, 170),
    Red       = Color3.fromRGB(255, 70, 90),
    Yellow    = Color3.fromRGB(255, 210, 60),
    TextMain  = Color3.fromRGB(235, 240, 255),
    TextDim   = Color3.fromRGB(130, 140, 165),
}

local function applyStroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.Cyan
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.25
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

local function applyGradient(obj, c1, c2, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c1 or THEME.Cyan, c2 or THEME.Purple)
    g.Rotation = rotation or 0
    g.Parent = obj
    return g
end

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
local CONFIG_FILE = "FinderConfigMulti.json"
local config = {
    modes = {},          -- { fruit = true/false, whitebeard = true/false, secretdealer = true/false }
    autoPickupFruit = false,
}

local function saveConfig()
    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(config))
    end)
end

local function loadConfig()
    pcall(function()
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        config.modes = data.modes or {}
        config.autoPickupFruit = data.autoPickupFruit or false
    end)
end
loadConfig()

-- ==========================================
--  HOP SYSTEM
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

local paused = false
local running = false

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
                if paused then return end
                pcall(function()
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

local statusLabel
local function hopServer()
    if paused then return end
    warn("[Finder] ไม่พบเป้าหมายไหนเลย → Hopping...")
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
    if topic == "" then return end
    pcall(function()
        request({
            Url = "https://ntfy.sh/" .. topic,
            Method = "POST",
            Headers = { ["Title"] = title, ["Priority"] = "urgent", ["Content-Type"] = "text/plain" },
            Body = body
        })
    end)
end

local function sendWebhookRaw(url, payload)
    if url == "" then return end
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
--  SELECT SCREEN UI (Checkbox + Confirm)
-- ==========================================
local selectGui = Instance.new("ScreenGui")
selectGui.Name = "FinderSelectUI"
selectGui.ResetOnSpawn = false
selectGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
selectGui.Parent = LocalPlayer.PlayerGui

local selFrame = Instance.new("Frame")
selFrame.Size = UDim2.new(0, 250, 0, 290)
selFrame.Position = UDim2.new(0.5, -125, 0.5, -140)
selFrame.BackgroundColor3 = THEME.Bg
selFrame.BorderSizePixel = 0
selFrame.Parent = selectGui
Instance.new("UICorner", selFrame).CornerRadius = UDim.new(0, 14)
applyStroke(selFrame, THEME.Cyan, 1.5, 0.35)

local selTitle = Instance.new("TextLabel")
selTitle.Size = UDim2.new(1, 0, 0, 50)
selTitle.BackgroundColor3 = THEME.PanelAlt
selTitle.BorderSizePixel = 0
selTitle.Text = "⌬  SELECT FINDER MODE"
selTitle.TextColor3 = THEME.Cyan
selTitle.TextSize = 14
selTitle.Font = Enum.Font.GothamBold
selTitle.TextWrapped = true
selTitle.Parent = selFrame
Instance.new("UICorner", selTitle).CornerRadius = UDim.new(0, 14)
local selTitleBottomFix = Instance.new("Frame")
selTitleBottomFix.Size = UDim2.new(1, 0, 0, 14)
selTitleBottomFix.Position = UDim2.new(0, 0, 1, -14)
selTitleBottomFix.BackgroundColor3 = THEME.PanelAlt
selTitleBottomFix.BorderSizePixel = 0
selTitleBottomFix.ZIndex = 0
selTitleBottomFix.Parent = selTitle
local selSub = Instance.new("TextLabel")
selSub.Size = UDim2.new(1, -20, 0, 16)
selSub.Position = UDim2.new(0, 10, 0, 30)
selSub.BackgroundTransparency = 1
selSub.Text = "เลือกได้หลายอัน • พร้อม Auto-Hop"
selSub.TextColor3 = THEME.TextDim
selSub.TextSize = 10
selSub.Font = Enum.Font.Gotham
selSub.TextXAlignment = Enum.TextXAlignment.Left
selSub.Parent = selFrame

local checkboxState = {
    fruit = config.modes.fruit or false,
    whitebeard = config.modes.whitebeard or false,
    secretdealer = config.modes.secretdealer or false,
}

local function makeCheckbox(text, color, posY, key)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -30, 0, 50)
    btn.Position = UDim2.new(0, 15, 0, posY)
    btn.BackgroundColor3 = checkboxState[key] and THEME.PanelAlt or THEME.Panel
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.Parent = selFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local stroke = applyStroke(btn, checkboxState[key] and color or Color3.fromRGB(50, 52, 60), 1.4, checkboxState[key] and 0.15 or 0.6)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(0, 14, 0.5, -4)
    dot.BackgroundColor3 = color
    dot.BorderSizePixel = 0
    dot.Visible = checkboxState[key]
    dot.Parent = btn
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 30, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = checkboxState[key] and THEME.TextMain or THEME.TextDim
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = btn

    local check = Instance.new("TextLabel")
    check.Size = UDim2.new(0, 30, 1, 0)
    check.Position = UDim2.new(1, -36, 0, 0)
    check.BackgroundTransparency = 1
    check.Text = checkboxState[key] and "✓" or ""
    check.TextColor3 = color
    check.TextSize = 16
    check.Font = Enum.Font.GothamBold
    check.Parent = btn

    btn.MouseButton1Click:Connect(function()
        checkboxState[key] = not checkboxState[key]
        btn.BackgroundColor3 = checkboxState[key] and THEME.PanelAlt or THEME.Panel
        stroke.Color = checkboxState[key] and color or Color3.fromRGB(50, 52, 60)
        stroke.Transparency = checkboxState[key] and 0.15 or 0.6
        dot.Visible = checkboxState[key]
        label.TextColor3 = checkboxState[key] and THEME.TextMain or THEME.TextDim
        check.Text = checkboxState[key] and "✓" or ""
    end)
    return btn
end

makeCheckbox("🍎  Fruit Finder",         THEME.Yellow,  64, "fruit")
makeCheckbox("⚓  Whitebeard Finder",    THEME.Cyan,    120, "whitebeard")
makeCheckbox("🃏  Secret Dealer Finder", THEME.Purple,  176, "secretdealer")

local confirmBtn = Instance.new("TextButton")
confirmBtn.Size = UDim2.new(1, -30, 0, 46)
confirmBtn.Position = UDim2.new(0, 15, 0, 230)
confirmBtn.BackgroundColor3 = THEME.Cyan
confirmBtn.BorderSizePixel = 0
confirmBtn.Text = "▶  CONFIRM & START"
confirmBtn.TextColor3 = Color3.fromRGB(5, 8, 12)
confirmBtn.TextSize = 14
confirmBtn.Font = Enum.Font.GothamBold
confirmBtn.Parent = selFrame
Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 8)
applyGradient(confirmBtn, THEME.Cyan, THEME.Purple, 0)

local selHint = Instance.new("TextLabel")
selHint.Size = UDim2.new(1, -20, 0, 30)
selHint.Position = UDim2.new(0, 10, 0, 292)
selHint.BackgroundTransparency = 1
selHint.Text = "เลือกอย่างน้อย 1 mode แล้วกด Confirm"
selHint.TextColor3 = THEME.TextDim
selHint.TextSize = 11
selHint.Font = Enum.Font.Gotham
selHint.TextWrapped = true
selHint.Parent = selFrame

-- ==========================================
--  MAIN UI
-- ==========================================
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "FinderMainUI"
mainGui.ResetOnSpawn = false
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
mainGui.Parent = LocalPlayer.PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 220, 0, 420)
mainFrame.Position = UDim2.new(0, 20, 0.5, -210)
mainFrame.BackgroundColor3 = THEME.Bg
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Visible = false
mainFrame.Parent = mainGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
applyStroke(mainFrame, THEME.Cyan, 1.5, 0.35)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 38)
titleBar.BackgroundColor3 = THEME.PanelAlt
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)
local titleBarFix = Instance.new("Frame")
titleBarFix.Size = UDim2.new(1, 0, 0, 14)
titleBarFix.Position = UDim2.new(0, 0, 1, -14)
titleBarFix.BackgroundColor3 = THEME.PanelAlt
titleBarFix.BorderSizePixel = 0
titleBarFix.ZIndex = 0
titleBarFix.Parent = titleBar

local titlePulse = Instance.new("Frame")
titlePulse.Size = UDim2.new(0, 6, 0, 6)
titlePulse.Position = UDim2.new(0, 12, 0.5, -3)
titlePulse.BackgroundColor3 = THEME.Green
titlePulse.BorderSizePixel = 0
titlePulse.Parent = titleBar
Instance.new("UICorner", titlePulse).CornerRadius = UDim.new(1, 0)
task.spawn(function()
    while titlePulse.Parent do
        for i = 1, 2 do
            titlePulse.BackgroundTransparency = i == 1 and 0.7 or 0
            task.wait(0.6)
        end
    end
end)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -32, 1, 0)
titleLabel.Position = UDim2.new(0, 26, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "⌬ MULTI-FINDER // CYBER"
titleLabel.TextColor3 = THEME.Cyan
titleLabel.TextSize = 13
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.new(0, 10, 0, 44)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "⏳ กำลังสแกน..."
statusLabel.TextColor3 = THEME.Yellow
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

-- คอนเทนเนอร์สำหรับแต่ละ mode panel (สร้างไดนามิก)
local panelsFrame = Instance.new("ScrollingFrame")
panelsFrame.Size = UDim2.new(1, -20, 0, 270)
panelsFrame.Position = UDim2.new(0, 10, 0, 70)
panelsFrame.BackgroundTransparency = 1
panelsFrame.BorderSizePixel = 0
panelsFrame.ScrollBarThickness = 4
panelsFrame.ScrollBarImageColor3 = THEME.Cyan
panelsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
panelsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
panelsFrame.Parent = mainFrame

-- Manual Hop button: บังคับย้ายเซิร์ฟทันที (เซิฟไม่ดีแต่เจอเป้าหมาย ก็ hop ได้)
local hopBtn = Instance.new("TextButton")
hopBtn.Size = UDim2.new(1, -20, 0, 32)
hopBtn.Position = UDim2.new(0, 10, 0, 345)
hopBtn.BackgroundColor3 = THEME.Panel
hopBtn.BorderSizePixel = 0
hopBtn.Text = "⤴  HOP SERVER (Manual)"
hopBtn.TextColor3 = THEME.Magenta
hopBtn.TextSize = 13
hopBtn.Font = Enum.Font.GothamBold
hopBtn.Parent = mainFrame
Instance.new("UICorner", hopBtn).CornerRadius = UDim.new(0, 8)
applyStroke(hopBtn, THEME.Magenta, 1.4, 0.2)

local switchBtn = Instance.new("TextButton")
switchBtn.Size = UDim2.new(1, -20, 0, 28)
switchBtn.Position = UDim2.new(0, 10, 0, 382)
switchBtn.BackgroundColor3 = THEME.Panel
switchBtn.BorderSizePixel = 0
switchBtn.Text = "⚙ เปลี่ยน Mode (M)"
switchBtn.TextColor3 = THEME.TextDim
switchBtn.TextSize = 12
switchBtn.Font = Enum.Font.GothamBold
switchBtn.Parent = mainFrame
Instance.new("UICorner", switchBtn).CornerRadius = UDim.new(0, 6)
applyStroke(switchBtn, Color3.fromRGB(60, 64, 78), 1, 0.4)

-- ==========================================
--  SCAN HELPERS
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
    if not config.autoPickupFruit then return end
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
        embeds = {{ title=title, description="มีผลไม้หายากในเซิร์ฟ!", color=getFruitColor(allFruits[1].item), fields=fields, footer={text="Finder v2"}, timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ") }}
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
    sendWebhookRaw(WEBHOOK_WB, {
        username = "⚓ Whitebeard Finder",
        embeds = {{ title="✅ พบ Whitebeard "..#allTargets.." ตัว!", description="พบ Whitebeard รีบเข้า!", color=3426654, fields=fields, footer={text="Finder v2"}, timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ") }}
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
        embeds = {{ title="✅ พบ Secret Dealer!", description="รีบเข้าก่อนหมดเวลา!", color=10181046, fields=fields, footer={text="Finder v2"}, timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ") }}
    })
    local body = ""
    for _, t in pairs(allTargets) do body = body .. "🃏 "..t.name.."\n" end
    sendNtfy(NTFY_SD, "พบ Secret Dealer!", body .. "\nJoin:\n" .. makeJoinCmd(serverId))
end

-- ==========================================
--  STATE สำหรับแต่ละ mode (เก็บใน table)
-- ==========================================
-- modeData[key] = { found=bool, panel=Frame, listLabel, countLabel, camBtn, cameraLocked, targetObj, camList, camIndex }
local modeData = {}
local activeModes = {}  -- list ของ key ที่กำลังรันอยู่

local CAM_HEIGHT = 20
local CAM_DISTANCE = 40

-- สร้าง panel UI สำหรับ mode หนึ่งๆ
local function createPanel(key, title, color, hasCam, hasPickup)
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(1, 0, 0, hasPickup and 140 or (hasCam and 115 or 70))
    panel.BackgroundColor3 = THEME.Panel
    panel.BorderSizePixel = 0
    panel.Parent = panelsFrame
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
    applyStroke(panel, color, 1, 0.55)

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -10, 0, 22)
    header.Position = UDim2.new(0, 8, 0, 5)
    header.BackgroundTransparency = 1
    header.Text = title
    header.TextColor3 = color
    header.TextSize = 13
    header.Font = Enum.Font.GothamBold
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = panel

    local listLabel = Instance.new("TextLabel")
    listLabel.Size = UDim2.new(1, -16, 0, 36)
    listLabel.Position = UDim2.new(0, 8, 0, 28)
    listLabel.BackgroundTransparency = 1
    listLabel.Text = "พบ: -"
    listLabel.TextColor3 = THEME.TextMain
    listLabel.TextSize = 10
    listLabel.Font = Enum.Font.Gotham
    listLabel.TextXAlignment = Enum.TextXAlignment.Left
    listLabel.TextYAlignment = Enum.TextYAlignment.Top
    listLabel.TextWrapped = true
    listLabel.Parent = panel

    local data = { found = false, panel = panel, listLabel = listLabel, cameraLocked = false, targetObj = nil, camList = {}, camIndex = 1 }

    local yOff = 64
    if hasCam then
        local camBtn = Instance.new("TextButton")
        camBtn.Size = UDim2.new(1, -16, 0, 26)
        camBtn.Position = UDim2.new(0, 8, 0, yOff)
        camBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        camBtn.BorderSizePixel = 0
        camBtn.Text = "📷 Lock: OFF"
        camBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        camBtn.TextSize = 11
        camBtn.Font = Enum.Font.GothamBold
        camBtn.Parent = panel
        Instance.new("UICorner", camBtn).CornerRadius = UDim.new(0, 5)
        data.camBtn = camBtn
        yOff = yOff + 26

        local prevBtn = Instance.new("TextButton")
        prevBtn.Size = UDim2.new(0, 26, 0, 22)
        prevBtn.Position = UDim2.new(0, 8, 0, yOff)
        prevBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        prevBtn.BorderSizePixel = 0
        prevBtn.Text = "◀"
        prevBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        prevBtn.TextSize = 11
        prevBtn.Font = Enum.Font.GothamBold
        prevBtn.Parent = panel
        Instance.new("UICorner", prevBtn).CornerRadius = UDim.new(0, 4)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -76, 0, 22)
        nameLabel.Position = UDim2.new(0, 40, 0, yOff)
        nameLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        nameLabel.BorderSizePixel = 0
        nameLabel.Text = "-"
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 10
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.Parent = panel
        Instance.new("UICorner", nameLabel).CornerRadius = UDim.new(0, 4)

        local nextBtn = Instance.new("TextButton")
        nextBtn.Size = UDim2.new(0, 26, 0, 22)
        nextBtn.Position = UDim2.new(1, -34, 0, yOff)
        nextBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        nextBtn.BorderSizePixel = 0
        nextBtn.Text = "▶"
        nextBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        nextBtn.TextSize = 11
        nextBtn.Font = Enum.Font.GothamBold
        nextBtn.Parent = panel
        Instance.new("UICorner", nextBtn).CornerRadius = UDim.new(0, 4)

        data.prevBtn = prevBtn
        data.nextBtn = nextBtn
        data.nameLabel = nameLabel

        local function updateCamUI()
            if #data.camList == 0 then
                nameLabel.Text = "-"
                data.targetObj = nil
                return
            end
            local t = data.camList[data.camIndex]
            nameLabel.Text = t.label
            data.targetObj = t.obj
        end
        data.updateCamUI = updateCamUI

        prevBtn.MouseButton1Click:Connect(function()
            if #data.camList == 0 then return end
            data.camIndex = data.camIndex - 1
            if data.camIndex < 1 then data.camIndex = #data.camList end
            updateCamUI()
        end)
        nextBtn.MouseButton1Click:Connect(function()
            if #data.camList == 0 then return end
            data.camIndex = data.camIndex + 1
            if data.camIndex > #data.camList then data.camIndex = 1 end
            updateCamUI()
        end)

        camBtn.MouseButton1Click:Connect(function()
            if not data.found then return end
            data.cameraLocked = not data.cameraLocked
            if data.cameraLocked then
                camBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
                camBtn.Text = "📷 Lock: ON"
            else
                camBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                camBtn.Text = "📷 Lock: OFF"
            end
        end)
        yOff = yOff + 24
    end

    if hasPickup then
        local pickupBtn = Instance.new("TextButton")
        pickupBtn.Size = UDim2.new(1, -16, 0, 26)
        pickupBtn.Position = UDim2.new(0, 8, 0, yOff)
        pickupBtn.BackgroundColor3 = config.autoPickupFruit and Color3.fromRGB(30, 120, 30) or Color3.fromRGB(100, 100, 100)
        pickupBtn.BorderSizePixel = 0
        pickupBtn.Text = config.autoPickupFruit and "🧲 Pickup: ON" or "🧲 Pickup: OFF"
        pickupBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        pickupBtn.TextSize = 11
        pickupBtn.Font = Enum.Font.GothamBold
        pickupBtn.Parent = panel
        Instance.new("UICorner", pickupBtn).CornerRadius = UDim.new(0, 5)

        pickupBtn.MouseButton1Click:Connect(function()
            config.autoPickupFruit = not config.autoPickupFruit
            saveConfig()
            if config.autoPickupFruit then
                pickupBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
                pickupBtn.Text = "🧲 Pickup: ON"
            else
                pickupBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                pickupBtn.Text = "🧲 Pickup: OFF"
            end
        end)
    end

    return data
end

-- ==========================================
--  CAMERA RENDER (รวมทุก mode ที่ lock)
-- ==========================================
RunService:BindToRenderStep("FinderCamLock", Enum.RenderPriority.Camera.Value + 1, function()
    local anyLocked = false
    for key, data in pairs(modeData) do
        if data.cameraLocked then
            anyLocked = true
            local hrp
            local t = data.targetObj
            if t then
                if typeof(t) == "Instance" and t:IsA("Player") and t.Character then
                    hrp = t.Character:FindFirstChild("HumanoidRootPart")
                elseif typeof(t) == "Instance" and t:IsA("BasePart") then
                    hrp = t
                end
            end
            if hrp then
                local offset = hrp.CFrame * CFrame.new(0, CAM_HEIGHT, CAM_DISTANCE)
                Camera.CFrame = CFrame.new(offset.Position, hrp.Position)
            end
            break -- lock แค่ตัวแรกที่เจอ (กันกล้องสับสน)
        end
    end
    if anyLocked then
        Camera.CameraType = Enum.CameraType.Scriptable
    end
end)

-- ==========================================
--  RESET ALL PANELS
-- ==========================================
local function resetAllPanels()
    for key, data in pairs(modeData) do
        data.found = false
        data.targetObj = nil
        data.cameraLocked = false
        data.camList = {}
        data.camIndex = 1
        data.listLabel.Text = "พบ: -"
        if data.camBtn then
            data.camBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            data.camBtn.Text = "📷 Lock: OFF"
        end
        if data.nameLabel then data.nameLabel.Text = "-" end
    end
    Camera.CameraType = Enum.CameraType.Custom
end

-- Hop button (ลบทิ้ง รวมเป็น switchBtn อย่างเดียวพอ แต่เก็บ functionality ไว้ผ่าน M key)

-- ==========================================
--  MAIN LOOP
-- ==========================================
local function startSelectedModes()
    -- เคลียร์ panel เก่า
    for _, child in pairs(panelsFrame:GetChildren()) do
        child:Destroy()
    end
    modeData = {}
    activeModes = {}

    if checkboxState.fruit then
        modeData.fruit = createPanel("fruit", "🍎 Fruit Finder", THEME.Yellow, true, true)
        table.insert(activeModes, "fruit")
    end
    if checkboxState.whitebeard then
        modeData.whitebeard = createPanel("whitebeard", "⚓ Whitebeard Finder", THEME.Cyan, false, false)
        table.insert(activeModes, "whitebeard")
    end
    if checkboxState.secretdealer then
        modeData.secretdealer = createPanel("secretdealer", "🃏 Secret Dealer Finder", THEME.Purple, true, false)
        table.insert(activeModes, "secretdealer")
    end

    if #activeModes == 0 then
        selHint.Text = "⚠️ เลือกอย่างน้อย 1 mode!"
        selHint.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end

    -- จัดตำแหน่ง panel เรียงกัน
    local yPos = 0
    for _, key in pairs(activeModes) do
        modeData[key].panel.Position = UDim2.new(0, 0, 0, yPos)
        yPos = yPos + modeData[key].panel.Size.Y.Offset + 8
    end

    config.modes = checkboxState
    saveConfig()

    selectGui.Enabled = false
    selFrame.Visible = false
    mainFrame.Visible = true
    paused = false
    running = true

    resetAllPanels()

    print("[Finder] เริ่ม modes: " .. table.concat(activeModes, ", "))

    task.spawn(function()
        while running do
            local anyFound = false

            for _, key in pairs(activeModes) do
                local data = modeData[key]

                if key == "fruit" then
                    local allFruits = scanFruits()
                    if #allFruits > 0 then
                        anyFound = true
                        if not data.found then
                            data.found = true
                            webhookFruit(allFruits, game.JobId)
                            if data.camBtn then
                                data.cameraLocked = true
                                data.camBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
                                data.camBtn.Text = "📷 Lock: ON"
                            end
                        end
                        local txt = ""
                        local newList = {}
                        local seen2 = {}
                        for i, f in pairs(allFruits) do
                            local who = f.player and f.player.Name or "🌍 World"
                            txt = txt .. i .. ". " .. f.item .. " (" .. who .. ")\n"
                            if not seen2[who] then
                                seen2[who] = true
                                local obj
                                if f.player then
                                    obj = f.player
                                else
                                    for _, wobj in pairs(workspace:GetChildren()) do
                                        if wobj:IsA("Tool") and wobj.Name == f.item then
                                            obj = wobj:FindFirstChildWhichIsA("BasePart")
                                            break
                                        end
                                    end
                                end
                                table.insert(newList, {label = who .. " (" .. f.item .. ")", obj = obj})
                            end
                        end
                        data.listLabel.Text = txt
                        if #newList ~= #data.camList then
                            data.camList = newList
                            data.camIndex = 1
                            if data.updateCamUI then data.updateCamUI() end
                        end
                        tryPickupFruit()
                    else
                        local fruitInWorld = false
                        for _, obj in pairs(workspace:GetChildren()) do
                            if obj:IsA("Tool") and isTargetFruit(obj.Name) then
                                fruitInWorld = true
                                break
                            end
                        end
                        if fruitInWorld then
                            anyFound = true
                            tryPickupFruit()
                        elseif data.found then
                            data.found = false
                            data.targetObj = nil
                            data.cameraLocked = false
                            data.camList = {}
                            data.listLabel.Text = "พบ: -"
                            if data.camBtn then
                                data.camBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                                data.camBtn.Text = "📷 Lock: OFF"
                            end
                            if data.nameLabel then data.nameLabel.Text = "-" end
                        end
                    end

                elseif key == "whitebeard" then
                    local allTargets = scanWhitebeard()
                    if #allTargets > 0 then
                        anyFound = true
                        if not data.found then
                            data.found = true
                            webhookWB(allTargets, game.JobId)
                        end
                        local txt = ""
                        for i, t in pairs(allTargets) do txt = txt .. i .. ". " .. t.name .. "\n" end
                        data.listLabel.Text = txt
                    elseif data.found then
                        data.found = false
                        data.listLabel.Text = "พบ: -"
                    end

                elseif key == "secretdealer" then
                    local allTargets = scanSecretDealer()
                    if #allTargets > 0 then
                        anyFound = true
                        if not data.found then
                            data.found = true
                            webhookSD(allTargets, game.JobId)
                            if data.camBtn and allTargets[1].root then
                                data.targetObj = allTargets[1].root
                                data.cameraLocked = true
                                data.camBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
                                data.camBtn.Text = "📷 Lock: ON"
                            end
                        end
                        local txt = ""
                        local newList = {}
                        for i, t in pairs(allTargets) do
                            txt = txt .. i .. ". " .. t.name .. "\n"
                            table.insert(newList, {label = t.name, obj = t.root})
                        end
                        data.listLabel.Text = txt
                        if #newList ~= #data.camList then
                            data.camList = newList
                            data.camIndex = 1
                            if data.updateCamUI then data.updateCamUI() end
                        end
                    elseif data.found then
                        data.found = false
                        data.targetObj = nil
                        data.cameraLocked = false
                        data.camList = {}
                        data.listLabel.Text = "พบ: -"
                        if data.camBtn then
                            data.camBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                            data.camBtn.Text = "📷 Lock: OFF"
                        end
                        if data.nameLabel then data.nameLabel.Text = "-" end
                    end
                end
            end

            if anyFound then
                statusLabel.Text = "✅ พบเป้าหมายอย่างน้อย 1 อัน"
                statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            else
                statusLabel.Text = "❌ ไม่พบเป้าหมายไหนเลย → Hopping..."
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                hopServer()
            end

            task.wait(CHECK_INTERVAL)
        end
    end)
end

confirmBtn.MouseButton1Click:Connect(function()
    running = false
    task.wait(0.1)
    local ok, err = pcall(startSelectedModes)
    if not ok then
        warn("[Finder] ❌ startSelectedModes ERROR: " .. tostring(err))
        selHint.Text = "❌ Error: " .. tostring(err)
        selHint.TextColor3 = Color3.fromRGB(255, 80, 80)
    end
end)

-- Manual Hop: ผู้ใช้กดเองเมื่อรู้สึกว่าเซิฟไม่ดี (lag/โดนเป้าหมายแย่งไปแล้ว ฯลฯ)
local hopDebounce = false
hopBtn.MouseButton1Click:Connect(function()
    if hopDebounce then return end
    hopDebounce = true
    local originalText = hopBtn.Text
    hopBtn.Text = "⤴  HOPPING..."
    hopBtn.AutoButtonColor = false
    if statusLabel then
        statusLabel.Text = "🛰️ Manual Hop: กำลังย้ายเซิร์ฟ..."
        statusLabel.TextColor3 = THEME.Magenta
    end
    warn("[Finder] 🛰️ Manual Hop กดโดยผู้ใช้ → กำลังย้ายเซิร์ฟ...")
    pcall(function() TPReturner() end)
    if foundAnything ~= "" then
        pcall(function() TPReturner() end)
    end
    task.wait(2)
    hopBtn.Text = originalText
    hopBtn.AutoButtonColor = true
    hopDebounce = false
end)

-- Switch mode button
switchBtn.MouseButton1Click:Connect(function()
    running = false
    paused = true
    mainFrame.Visible = false
    selFrame.Visible = true
    selectGui.Enabled = true
    resetAllPanels()
end)

-- Hotkey M
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.M then
        running = false
        paused = true
        mainFrame.Visible = false
        selFrame.Visible = true
        selectGui.Enabled = true
        resetAllPanels()
        warn("[Finder] กด M → เปิดหน้าเลือก Mode (Hop หยุดทันที)")
    end
end)

-- ==========================================
--  AUTO START จาก config
-- ==========================================
local hasSavedMode = checkboxState.fruit or checkboxState.whitebeard or checkboxState.secretdealer
if hasSavedMode then
    startSelectedModes()
else
    selectGui.Enabled = true
    selFrame.Visible = true
end
