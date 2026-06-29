-- // Finder All-in-One v3
-- // + Auto-Hop Timer | Server Counter | Minimize | Scan Depth

local Players          = game:GetService("Players")
local TeleportService  = game:GetService("TeleportService")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local Camera           = workspace.CurrentCamera

-- ==========================================
--  CONFIG
-- ==========================================
local WEBHOOK_FRUIT = _G.WEBHOOK_FRUIT or ""
local WEBHOOK_WB    = _G.WEBHOOK_WB    or ""
local WEBHOOK_SD    = _G.WEBHOOK_SD    or ""
local NTFY_FRUIT    = _G.NTFY_FRUIT    or ""
local NTFY_WB       = _G.NTFY_WB       or ""
local NTFY_SD       = _G.NTFY_SD       or ""

local PLACE_ID   = game.PlaceId
local SCAN_RATE  = 1      -- วินาทีต่อรอบ scan
local HOP_DELAY  = 6      -- วินาที countdown ก่อน hop

local TARGET_FRUITS = {
    "Paw","Candy","Chilly","Flare","Gas","Gravity","Gum",
    "Hollow","Light","Magma","Ope","Plasma","Rumble",
    "Sand","Smoke","Snow","String","Venom","Dark","Phoenix",
    "Vampire","Buddha"
}

-- ==========================================
--  WAIT FOR LOAD
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
while humanoid:GetState() == Enum.HumanoidStateType.Dead do humanoid.StateChanged:Wait() end
LocalPlayer:WaitForChild("Backpack")
while #Players:GetPlayers() < 1 do Players.PlayerAdded:Wait() end

-- ==========================================
--  HOP SYSTEM
-- ==========================================
local AllIDs     = {}
local hopCursor  = ""
local actualHour = math.floor(os.time() / 600)
local serverCount = 0   -- นับเซิร์ฟที่ hop ผ่านมา

local fileOk = pcall(function()
    AllIDs = HttpService:JSONDecode(readfile("FinderHopIDs.json"))
end)
if not fileOk then
    AllIDs = { actualHour }
    pcall(function() writefile("FinderHopIDs.json", HttpService:JSONEncode(AllIDs)) end)
end

local function TPReturner()
    local url = "https://games.roblox.com/v1/games/"..PLACE_ID.."/servers/Public?sortOrder=Asc&limit=100"
    if hopCursor ~= "" then url = url.."&cursor="..hopCursor end
    local ok, res = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
    if not ok or not res or not res.data then return end
    if res.nextPageCursor and res.nextPageCursor ~= "null" then hopCursor = res.nextPageCursor end
    for _, v in pairs(res.data) do
        local ID = tostring(v.id)
        local canUse = true
        local firstEntry = true
        for _, existing in pairs(AllIDs) do
            if firstEntry then
                firstEntry = false
                if tonumber(actualHour) ~= tonumber(existing) then
                    pcall(function()
                        delfile("FinderHopIDs.json")
                        AllIDs = { actualHour }
                    end)
                end
            else
                if ID == tostring(existing) then canUse = false break end
            end
        end
        if canUse and tonumber(v.maxPlayers) > tonumber(v.playing) then
            table.insert(AllIDs, ID)
            pcall(function() writefile("FinderHopIDs.json", HttpService:JSONEncode(AllIDs)) end)
            serverCount = serverCount + 1
            TeleportService:TeleportToPlaceInstance(PLACE_ID, ID, LocalPlayer)
            task.wait(5)
            return
        end
    end
end

local loopActive = false
local paused     = false

local function doHop()
    if paused then return end
    pcall(TPReturner)
    if hopCursor ~= "" then pcall(TPReturner) end
end

-- ==========================================
--  HELPERS
-- ==========================================
local function sendNtfy(topic, title, body)
    if topic == "" then return end
    local base = "https://ntfy.sh/"..topic

    -- ครั้งที่ 1: สั่น ไม่มีรายละเอียด
    pcall(function()
        request({ Url=base, Method="POST",
            Headers={
                ["Title"]        = title,
                ["Priority"]     = "urgent",
                ["Tags"]         = "rotating_light",
                ["X-Actions"]    = "",
                ["Content-Type"] = "text/plain"
            },
            Body = "🚨🚨🚨" })
    end)

    -- ครั้งที่ 2: สั่นอีกรอบ ยังไม่มีรายละเอียด
    pcall(function()
        request({ Url=base, Method="POST",
            Headers={
                ["Title"]        = title,
                ["Priority"]     = "urgent",
                ["Tags"]         = "rotating_light",
                ["Content-Type"] = "text/plain"
            },
            Body = "🚨🚨🚨" })
    end)

    -- ครั้งที่ 3: รายละเอียดเต็ม
    pcall(function()
        request({ Url=base, Method="POST",
            Headers={
                ["Title"]        = title,
                ["Priority"]     = "urgent",
                ["Tags"]         = "white_check_mark",
                ["Content-Type"] = "text/plain"
            },
            Body = body })
    end)
end

local function sendWebhook(url, payload)
    if url == "" then return end
    local body = HttpService:JSONEncode(payload)
    local ok = false
    pcall(function() request({ Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body }) ok=true end)
    if not ok then pcall(function() syn.request({ Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body }) end) end
end

local function joinCmd(sid)
    return string.format('Roblox.GameLauncher.joinGameInstance(%s,"%s")', tostring(PLACE_ID), tostring(sid))
end

local function baseFields(sid)
    return {
        { name="🆔 Server ID", value="```"..tostring(sid).."```", inline=false },
        { name="🎮 Place ID",  value="```"..tostring(PLACE_ID).."```", inline=true },
        { name="🌐 วิธีเข้า", value="F12 → Console → วาง command", inline=false },
        { name="📋 Command",   value="```js\n"..joinCmd(sid).."\n```", inline=false },
    }
end

-- ==========================================
--  SCAN FUNCTIONS (Scoped — ไม่ GetDescendants ทั้ง workspace)
-- ==========================================
local function isTargetFruit(name)
    local n = string.lower(name)
    for _, f in pairs(TARGET_FRUITS) do
        if n == string.lower(f.." Fruit") or n == string.lower(f.."fruit") then return true end
    end
    return false
end

-- รวบรวม container ที่ต้องสแกนสำหรับ Fruit
local function getFruitContainers()
    local containers = {}
    -- Backpack + Character ของทุกคน
    for _, p in pairs(Players:GetPlayers()) do
        local bp = p:FindFirstChild("Backpack")
        if bp then table.insert(containers, { src=bp, owner=p.Name, root=p.Character and p.Character:FindFirstChild("HumanoidRootPart") }) end
        if p.Character then table.insert(containers, { src=p.Character, owner=p.Name, root=p.Character:FindFirstChild("HumanoidRootPart") }) end
    end
    -- Workspace ชั้นบนสุด + folder ชื่อ Dropped/Items/Fruits (common names)
    local wsTopLevel = { workspace }
    for _, name in pairs({"Dropped","Items","Fruits","DroppedItems","Ground"}) do
        local f = workspace:FindFirstChild(name)
        if f then table.insert(wsTopLevel, f) end
    end
    for _, container in pairs(wsTopLevel) do
        table.insert(containers, { src=container, owner="Workspace", root=nil })
    end
    return containers
end

local function scanFruits()
    local results, seen = {}, {}
    for _, c in pairs(getFruitContainers()) do
        for _, item in pairs(c.src:GetChildren()) do
            if (item:IsA("Tool") or item:IsA("Model")) and isTargetFruit(item.Name) then
                local key = c.owner..item.Name..tostring(item)
                if not seen[key] then
                    seen[key] = true
                    local root = c.root
                        or item:FindFirstChild("Handle")
                        or item:FindFirstChildWhichIsA("BasePart")
                    table.insert(results, { label=item.Name, owner=c.owner, root=root })
                end
            end
        end
    end
    return results
end

-- Whitebeard: สแกนเฉพาะ folder ที่ NPC มักอยู่
local function scanWhitebeard()
    local results = {}
    -- scope: workspace ชั้น 1 + Alive/Mobs/NPCs/Enemies
    local scopes = { workspace }
    for _, name in pairs({"Alive","Mobs","NPCs","Enemies","Characters"}) do
        local f = workspace:FindFirstChild(name)
        if f then table.insert(scopes, f) end
    end
    for _, scope in pairs(scopes) do
        for _, obj in pairs(scope:GetChildren()) do
            if obj:IsA("Model") and obj ~= LocalPlayer.Character
            and string.lower(obj.Name):find("whitebeard") then
                local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                table.insert(results, { label=obj.Name, root=root })
            end
            -- ลึกอีก 1 ชั้น (sub-folder เช่น Alive > Boss)
            if obj:IsA("Folder") or obj:IsA("Model") then
                for _, child in pairs(obj:GetChildren()) do
                    if child:IsA("Model") and string.lower(child.Name):find("whitebeard") then
                        local root = child:FindFirstChild("HumanoidRootPart") or child:FindFirstChildWhichIsA("BasePart")
                        table.insert(results, { label=child.Name, root=root })
                    end
                end
            end
        end
    end
    return results
end

-- Secret Dealer: สแกนเฉพาะ Ignore > NPCs ตามโครงสร้างเกม
local function scanSecretDealer()
    local results = {}
    local scopes = {}
    local ignore = workspace:FindFirstChild("Ignore")
    if ignore then
        local npcs = ignore:FindFirstChild("NPCs")
        if npcs then
            for _, obj in pairs(npcs:GetChildren()) do
                table.insert(scopes, obj)   -- sub-folder เช่น DailyQuest
                if obj:IsA("Folder") or obj:IsA("Model") then
                    for _, child in pairs(obj:GetChildren()) do
                        table.insert(scopes, child)
                    end
                end
            end
        end
        -- Ignore โดยตรง (กรณีอยู่นอก NPCs)
        for _, obj in pairs(ignore:GetChildren()) do
            if obj.Name ~= "NPCs" and obj.Name ~= "HitBox" then
                table.insert(scopes, obj)
            end
        end
    end
    for _, obj in pairs(scopes) do
        if obj:IsA("Model") and string.lower(obj.Name):find("secret dealer") then
            local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
            table.insert(results, { label=obj.Name, root=root })
        end
    end
    return results
end

-- ==========================================
--  UI THEME
-- ==========================================
local C = {
    bg      = Color3.fromRGB(8,  12, 22),
    panel   = Color3.fromRGB(13, 20, 38),
    header  = Color3.fromRGB(15, 25, 50),
    accent  = Color3.fromRGB(0,  120, 255),
    accentD = Color3.fromRGB(0,  80,  180),
    blue2   = Color3.fromRGB(30, 60, 120),
    green   = Color3.fromRGB(20, 200, 100),
    red     = Color3.fromRGB(220, 50,  50),
    yellow  = Color3.fromRGB(255, 200, 40),
    white   = Color3.fromRGB(220, 230, 255),
    gray    = Color3.fromRGB(90,  110, 150),
    grayD   = Color3.fromRGB(40,  55,  80),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FinderUI_v3"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LocalPlayer.PlayerGui

-- ── FULL FRAME ──────────────────────────────
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 280, 0, 480)
frame.Position = UDim2.new(0, 16, 0.5, -240)
frame.BackgroundColor3 = C.bg
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

-- accent bar top
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 3)
topBar.BackgroundColor3 = C.accent
topBar.BorderSizePixel = 0
topBar.ZIndex = 5
topBar.Parent = frame
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 12)

-- ── HEADER ─────────────────────────────────
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 44)
header.Position = UDim2.new(0, 0, 0, 3)
header.BackgroundColor3 = C.header
header.BorderSizePixel = 0
header.Parent = frame

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(0.55, 0, 1, 0)
titleLbl.Position = UDim2.new(0, 14, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "● FINDER"
titleLbl.TextColor3 = C.white
titleLbl.TextSize = 15
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = header

local modeLbl = Instance.new("TextLabel")
modeLbl.Size = UDim2.new(0.4, 0, 1, 0)
modeLbl.Position = UDim2.new(0.55, 0, 0, 0)
modeLbl.BackgroundTransparency = 1
modeLbl.Text = "no mode"
modeLbl.TextColor3 = C.gray
modeLbl.TextSize = 11
modeLbl.Font = Enum.Font.Gotham
modeLbl.TextXAlignment = Enum.TextXAlignment.Right
modeLbl.Parent = header

-- Minimize button (ขวาบนสุด)
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 28, 0, 28)
minBtn.Position = UDim2.new(1, -36, 0, 8)
minBtn.BackgroundColor3 = C.grayD
minBtn.BorderSizePixel = 0
minBtn.Text = "—"
minBtn.TextColor3 = C.gray
minBtn.TextSize = 12
minBtn.Font = Enum.Font.GothamBold
minBtn.ZIndex = 6
minBtn.Parent = header
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

-- ── MINI FRAME (พับแล้วเหลืออันนี้) ────────
local miniFrame = Instance.new("Frame")
miniFrame.Size = UDim2.new(0, 280, 0, 47)
miniFrame.Position = frame.Position
miniFrame.BackgroundColor3 = C.header
miniFrame.BorderSizePixel = 0
miniFrame.Active = true
miniFrame.Draggable = true
miniFrame.Visible = false
miniFrame.Parent = screenGui
Instance.new("UICorner", miniFrame).CornerRadius = UDim.new(0, 10)

local miniTopBar = Instance.new("Frame")
miniTopBar.Size = UDim2.new(1, 0, 0, 3)
miniTopBar.BackgroundColor3 = C.accent
miniTopBar.BorderSizePixel = 0
miniTopBar.Parent = miniFrame
Instance.new("UICorner", miniTopBar).CornerRadius = UDim.new(0, 10)

local miniStatusLbl = Instance.new("TextLabel")
miniStatusLbl.Size = UDim2.new(1, -80, 1, 0)
miniStatusLbl.Position = UDim2.new(0, 12, 0, 3)
miniStatusLbl.BackgroundTransparency = 1
miniStatusLbl.Text = "● FINDER  —  no mode"
miniStatusLbl.TextColor3 = C.white
miniStatusLbl.TextSize = 12
miniStatusLbl.Font = Enum.Font.GothamBold
miniStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
miniStatusLbl.Parent = miniFrame

local expandBtn = Instance.new("TextButton")
expandBtn.Size = UDim2.new(0, 28, 0, 28)
expandBtn.Position = UDim2.new(1, -36, 0.5, -14)
expandBtn.BackgroundColor3 = C.blue2
expandBtn.BorderSizePixel = 0
expandBtn.Text = "▲"
expandBtn.TextColor3 = C.white
expandBtn.TextSize = 12
expandBtn.Font = Enum.Font.GothamBold
expandBtn.Parent = miniFrame
Instance.new("UICorner", expandBtn).CornerRadius = UDim.new(0, 6)

-- Minimize logic
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = true
    miniFrame.Position = frame.Position
    miniTopBar.BackgroundColor3 = topBar.BackgroundColor3
    frame.Visible = false
    miniFrame.Visible = true
end)
expandBtn.MouseButton1Click:Connect(function()
    minimized = false
    frame.Position = miniFrame.Position
    frame.Visible = true
    miniFrame.Visible = false
end)

-- ── BODY ────────────────────────────────────
local bodyFrame = Instance.new("Frame")
bodyFrame.Size = UDim2.new(1, 0, 1, -47)
bodyFrame.Position = UDim2.new(0, 0, 0, 47)
bodyFrame.BackgroundTransparency = 1
bodyFrame.BorderSizePixel = 0
bodyFrame.Parent = frame

-- hotkey hint
local modeBar = Instance.new("Frame")
modeBar.Size = UDim2.new(1, -16, 0, 26)
modeBar.Position = UDim2.new(0, 8, 0, 4)
modeBar.BackgroundColor3 = C.panel
modeBar.BorderSizePixel = 0
modeBar.Parent = bodyFrame
Instance.new("UICorner", modeBar).CornerRadius = UDim.new(0, 6)

local modeHint = Instance.new("TextLabel")
modeHint.Size = UDim2.new(1, -10, 1, 0)
modeHint.Position = UDim2.new(0, 8, 0, 0)
modeHint.BackgroundTransparency = 1
modeHint.Text = "[M] Fruit   [N] Whitebeard   [B] Secret Dealer"
modeHint.TextColor3 = C.gray
modeHint.TextSize = 10
modeHint.Font = Enum.Font.Gotham
modeHint.TextXAlignment = Enum.TextXAlignment.Left
modeHint.Parent = modeBar

-- status
local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -16, 0, 24)
statusLbl.Position = UDim2.new(0, 8, 0, 34)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "⏸  เลือก mode  (M / N / B)"
statusLbl.TextColor3 = C.gray
statusLbl.TextSize = 12
statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = bodyFrame

-- ── STATS ROW (Server Counter + Timer) ──────
local statsRow = Instance.new("Frame")
statsRow.Size = UDim2.new(1, -16, 0, 28)
statsRow.Position = UDim2.new(0, 8, 0, 62)
statsRow.BackgroundColor3 = C.panel
statsRow.BorderSizePixel = 0
statsRow.Parent = bodyFrame
Instance.new("UICorner", statsRow).CornerRadius = UDim.new(0, 6)

local srvCountLbl = Instance.new("TextLabel")
srvCountLbl.Size = UDim2.new(0.5, -4, 1, 0)
srvCountLbl.Position = UDim2.new(0, 8, 0, 0)
srvCountLbl.BackgroundTransparency = 1
srvCountLbl.Text = "🖥  Hop: 0 เซิร์ฟ"
srvCountLbl.TextColor3 = C.gray
srvCountLbl.TextSize = 10
srvCountLbl.Font = Enum.Font.GothamBold
srvCountLbl.TextXAlignment = Enum.TextXAlignment.Left
srvCountLbl.Parent = statsRow

local timerLbl = Instance.new("TextLabel")
timerLbl.Size = UDim2.new(0.5, -8, 1, 0)
timerLbl.Position = UDim2.new(0.5, 0, 0, 0)
timerLbl.BackgroundTransparency = 1
timerLbl.Text = "⏱  —"
timerLbl.TextColor3 = C.gray
timerLbl.TextSize = 10
timerLbl.Font = Enum.Font.GothamBold
timerLbl.TextXAlignment = Enum.TextXAlignment.Right
timerLbl.Parent = statsRow

-- ── TARGET LIST ─────────────────────────────
local listTitle = Instance.new("TextLabel")
listTitle.Size = UDim2.new(1, -16, 0, 16)
listTitle.Position = UDim2.new(0, 8, 0, 96)
listTitle.BackgroundTransparency = 1
listTitle.Text = "TARGETS  (REAL-TIME)"
listTitle.TextColor3 = C.accent
listTitle.TextSize = 10
listTitle.Font = Enum.Font.GothamBold
listTitle.TextXAlignment = Enum.TextXAlignment.Left
listTitle.Parent = bodyFrame

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -16, 0, 160)
scrollFrame.Position = UDim2.new(0, 8, 0, 114)
scrollFrame.BackgroundColor3 = C.panel
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 3
scrollFrame.ScrollBarImageColor3 = C.accent
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = bodyFrame
Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0, 6)

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 2)
listLayout.Parent = scrollFrame

local listPad = Instance.new("UIPadding")
listPad.PaddingTop    = UDim.new(0, 4)
listPad.PaddingLeft   = UDim.new(0, 6)
listPad.PaddingRight  = UDim.new(0, 6)
listPad.PaddingBottom = UDim.new(0, 4)
listPad.Parent = scrollFrame

-- ── CAMERA ─────────────────────────────────
local div1 = Instance.new("Frame")
div1.Size = UDim2.new(1, -16, 0, 1)
div1.Position = UDim2.new(0, 8, 0, 280)
div1.BackgroundColor3 = C.grayD
div1.BorderSizePixel = 0
div1.Parent = bodyFrame

local camBtn = Instance.new("TextButton")
camBtn.Size = UDim2.new(1, -16, 0, 34)
camBtn.Position = UDim2.new(0, 8, 0, 288)
camBtn.BackgroundColor3 = C.blue2
camBtn.BorderSizePixel = 0
camBtn.Text = "📷  Camera Lock: OFF"
camBtn.TextColor3 = C.white
camBtn.TextSize = 12
camBtn.Font = Enum.Font.GothamBold
camBtn.Parent = bodyFrame
Instance.new("UICorner", camBtn).CornerRadius = UDim.new(0, 7)

local zoomHint = Instance.new("TextLabel")
zoomHint.Size = UDim2.new(1, -16, 0, 16)
zoomHint.Position = UDim2.new(0, 8, 0, 326)
zoomHint.BackgroundTransparency = 1
zoomHint.Text = "I = ใกล้   O = ไกล   Q = ปิดกล้อง"
zoomHint.TextColor3 = C.gray
zoomHint.TextSize = 10
zoomHint.Font = Enum.Font.Gotham
zoomHint.TextXAlignment = Enum.TextXAlignment.Center
zoomHint.Parent = bodyFrame

-- ── HOP BUTTON ──────────────────────────────
local hopBtn = Instance.new("TextButton")
hopBtn.Size = UDim2.new(1, -16, 0, 34)
hopBtn.Position = UDim2.new(0, 8, 0, 350)
hopBtn.BackgroundColor3 = C.accentD
hopBtn.BorderSizePixel = 0
hopBtn.Text = "⇒  HOP SERVER"
hopBtn.TextColor3 = C.white
hopBtn.TextSize = 13
hopBtn.Font = Enum.Font.GothamBold
hopBtn.Parent = bodyFrame
Instance.new("UICorner", hopBtn).CornerRadius = UDim.new(0, 7)

-- server id footer
local serverLbl = Instance.new("TextLabel")
serverLbl.Size = UDim2.new(1, -16, 0, 14)
serverLbl.Position = UDim2.new(0, 8, 0, 392)
serverLbl.BackgroundTransparency = 1
serverLbl.Text = "SRV: "..tostring(game.JobId):sub(1,20).."…"
serverLbl.TextColor3 = C.grayD
serverLbl.TextSize = 9
serverLbl.Font = Enum.Font.Gotham
serverLbl.TextXAlignment = Enum.TextXAlignment.Left
serverLbl.Parent = bodyFrame

-- ==========================================
--  ROW POOL
-- ==========================================
local rowPool    = {}
local currentRows = {}
local selectedIdx = 1
local cameraLocked = false
local targetList   = {}
local CAM_DIST = 30
local CAM_H    = 15

local function clearRows()
    for _, r in pairs(currentRows) do
        r.frame.Visible = false
        r.frame.Parent = nil
        table.insert(rowPool, r)
    end
    currentRows = {}
end

local function getRow()
    if #rowPool > 0 then
        local r = rowPool[#rowPool]
        rowPool[#rowPool] = nil
        r.btn:ClearAllChildren()  -- ลบ connection เก่า
        return r
    end
    local rowFrame = Instance.new("Frame")
    rowFrame.Size = UDim2.new(1, 0, 0, 30)
    rowFrame.BackgroundColor3 = C.grayD
    rowFrame.BorderSizePixel = 0
    Instance.new("UICorner", rowFrame).CornerRadius = UDim.new(0, 5)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0.6, -4, 1, 0)
    nameLbl.Position = UDim2.new(0, 6, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextColor3 = C.white
    nameLbl.TextSize = 11
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Parent = rowFrame

    local ownerLbl = Instance.new("TextLabel")
    ownerLbl.Size = UDim2.new(0.4, -4, 1, 0)
    ownerLbl.Position = UDim2.new(0.6, 0, 0, 0)
    ownerLbl.BackgroundTransparency = 1
    ownerLbl.TextColor3 = C.gray
    ownerLbl.TextSize = 10
    ownerLbl.Font = Enum.Font.Gotham
    ownerLbl.TextXAlignment = Enum.TextXAlignment.Right
    ownerLbl.TextTruncate = Enum.TextTruncate.AtEnd
    ownerLbl.Parent = rowFrame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = rowFrame

    return { frame=rowFrame, nameLbl=nameLbl, ownerLbl=ownerLbl, btn=btn }
end

local function rebuildRows(targets)
    clearRows()
    for i, t in ipairs(targets) do
        local row = getRow()
        local idx = i
        row.nameLbl.Text  = t.label
        row.ownerLbl.Text = t.owner or ""
        if i == selectedIdx then
            row.frame.BackgroundColor3 = C.blue2
            row.nameLbl.TextColor3 = C.white
        else
            row.frame.BackgroundColor3 = C.grayD
            row.nameLbl.TextColor3 = C.gray
        end
        row.frame.Visible = true
        row.frame.LayoutOrder = i
        row.frame.Parent = scrollFrame
        row.btn.MouseButton1Click:Connect(function()
            selectedIdx = idx
            rebuildRows(targetList)
        end)
        table.insert(currentRows, row)
    end
end

-- ==========================================
--  CAMERA
-- ==========================================
RunService:BindToRenderStep("FinderCam", Enum.RenderPriority.Camera.Value + 1, function()
    if not cameraLocked then return end
    local t = targetList[selectedIdx]
    local root = t and t.root
    if root and root.Parent then
        local off = root.CFrame * CFrame.new(0, CAM_H, CAM_DIST)
        Camera.CFrame = CFrame.new(off.Position, root.Position)
    end
end)

local function setCamLock(on)
    cameraLocked = on
    if on then
        Camera.CameraType = Enum.CameraType.Scriptable
        camBtn.BackgroundColor3 = C.accent
        camBtn.Text = "📷  Camera Lock: ON"
    else
        Camera.CameraType = Enum.CameraType.Custom
        camBtn.BackgroundColor3 = C.blue2
        camBtn.Text = "📷  Camera Lock: OFF"
    end
end

camBtn.MouseButton1Click:Connect(function()
    if #targetList == 0 then return end
    setCamLock(not cameraLocked)
end)

UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.I and cameraLocked then CAM_DIST = math.max(5, CAM_DIST - 5)
    elseif inp.KeyCode == Enum.KeyCode.O and cameraLocked then CAM_DIST = math.min(100, CAM_DIST + 5)
    elseif inp.KeyCode == Enum.KeyCode.Q and cameraLocked then setCamLock(false) end
end)

-- ==========================================
--  AUTO-HOP TIMER
-- ==========================================
local hopTimerActive = false
local hopTimerCancel = false

local function startHopTimer(onDone)
    if hopTimerActive then return end
    hopTimerActive = true
    hopTimerCancel = false
    task.spawn(function()
        for i = HOP_DELAY, 1, -1 do
            if hopTimerCancel then
                hopTimerActive = false
                timerLbl.Text = "⏱  —"
                timerLbl.TextColor3 = C.gray
                return
            end
            timerLbl.Text = "⏱  Hop ใน "..i.."s"
            timerLbl.TextColor3 = i <= 2 and C.red or C.yellow
            task.wait(1)
        end
        hopTimerActive = false
        timerLbl.Text = "⏱  —"
        timerLbl.TextColor3 = C.gray
        if not hopTimerCancel then onDone() end
    end)
end

local function cancelHopTimer()
    hopTimerCancel = true
    timerLbl.Text = "⏱  —"
    timerLbl.TextColor3 = C.gray
end

local function doHopWithTimer()
    startHopTimer(function()
        srvCountLbl.Text = "🖥  Hop: "..serverCount.." เซิร์ฟ"
        task.spawn(doHop)
    end)
end

-- ==========================================
--  MODE SYSTEM
-- ==========================================
local currentMode = nil
local webhookSent = {}

local modeInfo = {
    fruit        = { label="🍎  FRUIT",         color=Color3.fromRGB(220, 100, 20)  },
    whitebeard   = { label="⚓  WHITEBEARD",    color=Color3.fromRGB(40,  90,  200) },
    secretdealer = { label="🃏  SECRET DEALER", color=Color3.fromRGB(120, 40,  200) },
}

local function resetState()
    targetList  = {}
    selectedIdx = 1
    webhookSent = {}
    setCamLock(false)
    cancelHopTimer()
    clearRows()
    statusLbl.Text       = "⏳  กำลังสแกน..."
    statusLbl.TextColor3 = C.yellow
    timerLbl.Text        = "⏱  —"
    timerLbl.TextColor3  = C.gray
end

local function setMode(mode)
    if mode == currentMode then return end
    loopActive  = false
    paused      = false
    currentMode = mode
    resetState()

    local info = modeInfo[mode]
    topBar.BackgroundColor3   = info.color
    miniTopBar.BackgroundColor3 = info.color
    modeLbl.Text              = info.label
    modeLbl.TextColor3        = info.color
    miniStatusLbl.Text        = "● FINDER  "..info.label

    loopActive = true
    task.spawn(function()
        local myMode = mode
        while loopActive and currentMode == myMode do
            local results
            if myMode == "fruit" then
                results = scanFruits()
            elseif myMode == "whitebeard" then
                results = scanWhitebeard()
            else
                results = scanSecretDealer()
            end

            targetList = results

            if #results > 0 then
                if selectedIdx > #results then selectedIdx = 1 end
                rebuildRows(results)
                statusLbl.Text       = "✅  พบ "..#results.." เป้าหมาย"
                statusLbl.TextColor3 = C.green
                cancelHopTimer()   -- เจอแล้ว ยกเลิก timer

                local sid = game.JobId
                if not webhookSent[sid] then
                    webhookSent[sid] = true
                    task.spawn(function()
                        local fields = baseFields(sid)
                        if myMode == "fruit" then
                            local list = ""
                            for i, r in pairs(results) do list=list.."**"..i..".** "..r.label.."  → `"..r.owner.."`\n" end
                            table.insert(fields, 1, { name="🍑 Fruit ("..#results..")", value=list, inline=false })
                            sendWebhook(WEBHOOK_FRUIT, { username="🍎 Fruit Finder", embeds={{ title="✅ พบ Fruit!", description="มีผลหายากในเซิร์ฟ!", color=0xE8630A, fields=fields, footer={text="Finder v3"}, timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ") }} })
                            local b="" for _, r in pairs(results) do b=b.."🍑 "..r.label.." ("..r.owner..")\n" end
                            sendNtfy(NTFY_FRUIT, "พบ "..#results.." Fruit!", b.."\nJoin:\n"..joinCmd(sid))
                        elseif myMode == "whitebeard" then
                            local list="" for i, r in pairs(results) do list=list.."**"..i..".** `"..r.label.."`\n" end
                            table.insert(fields, 1, { name="⚓ Whitebeard", value=list, inline=false })
                            sendWebhook(WEBHOOK_WB, { username="⚓ WB Finder", embeds={{ title="✅ พบ Whitebeard!", color=0x3498DB, fields=fields, footer={text="Finder v3"}, timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ") }} })
                            local b="" for _, r in pairs(results) do b=b.."⚓ "..r.label.."\n" end
                            sendNtfy(NTFY_WB, "พบ Whitebeard!", b.."\nJoin:\n"..joinCmd(sid))
                        else
                            local list="" for i, r in pairs(results) do list=list.."**"..i..".** `"..r.label.."`\n" end
                            table.insert(fields, 1, { name="🃏 Secret Dealer", value=list, inline=false })
                            sendWebhook(WEBHOOK_SD, { username="🃏 SD Finder", embeds={{ title="✅ พบ Secret Dealer!", color=0x9B59B6, fields=fields, footer={text="Finder v3"}, timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ") }} })
                            local b="" for _, r in pairs(results) do b=b.."🃏 "..r.label.."\n" end
                            sendNtfy(NTFY_SD, "พบ Secret Dealer!", b.."\nJoin:\n"..joinCmd(sid))
                        end
                    end)
                end
            else
                -- ไม่เจอ → countdown แล้ว hop
                clearRows()
                statusLbl.Text       = "❌  ไม่พบเป้าหมาย"
                statusLbl.TextColor3 = C.red
                setCamLock(false)
                doHopWithTimer()
                -- รอให้ timer จบก่อน scan รอบหน้า
                task.wait(HOP_DELAY + 1)
                srvCountLbl.Text = "🖥  Hop: "..serverCount.." เซิร์ฟ"
            end

            task.wait(SCAN_RATE)
        end
    end)
end

-- ==========================================
--  HOTKEYS  M / N / B
-- ==========================================
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.M then setMode("fruit") end
    if inp.KeyCode == Enum.KeyCode.N then setMode("whitebeard") end
    if inp.KeyCode == Enum.KeyCode.B then setMode("secretdealer") end
end)

hopBtn.MouseButton1Click:Connect(function()
    if not loopActive then return end
    cancelHopTimer()
    setCamLock(false)
    statusLbl.Text       = "🔄  กำลัง Hop..."
    statusLbl.TextColor3 = C.yellow
    srvCountLbl.Text     = "🖥  Hop: "..serverCount.." เซิร์ฟ"
    task.spawn(doHop)
end)

print("[Finder v3] พร้อมใช้งาน  |  M = Fruit  |  N = Whitebeard  |  B = Secret Dealer")
