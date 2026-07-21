--[[
    Bloxtrike — Combined single-file loader + application
    Whitelist fully removed.
]]

local DEFAULT_BASE_URL = "https://raw.githubusercontent.com/Volodym5/hn4f538un5g4/main"

-- ─── UTILITY FUNCTIONS ───

local function getFileName(path)
    return tostring(path or ""):match("([^/\\]+)$") or tostring(path or "")
end

local function getHttpGet()
    if syn and syn.request then
        return function(url)
            local r = syn.request({ Url = url, Method = "GET" })
            return r and r.Body
        end
    end
    if http and http.request then
        return function(url)
            local r = http.request({ Url = url, Method = "GET" })
            return r and r.Body
        end
    end
    if game and game.HttpGet then
        return function(url) return game:HttpGet(url) end
    end
    error("No HTTP request function available in this executor.")
end

local function getGuiParent()
    local players = game:GetService("Players")
    local coreGui = game:GetService("CoreGui")
    local localPlayer = players.LocalPlayer
    local parent = (gethui and gethui()) or coreGui
    local ok = pcall(function()
        local p = Instance.new("ScreenGui")
        p.Parent = coreGui
        p:Destroy()
    end)
    if not ok and localPlayer then
        parent = localPlayer:WaitForChild("PlayerGui")
    end
    return parent
end

-- ─── LOADING OVERLAY ───

local function createLoadingOverlay(message)
    local guiParent = getGuiParent()
    local existing = guiParent:FindFirstChild("BLOXTRIKE_BOOTSTRAP_LOADING")
    if existing then existing:Destroy() end

    local loadingGui = Instance.new("ScreenGui")
    loadingGui.Name = "BLOXTRIKE_BOOTSTRAP_LOADING"
    loadingGui.ResetOnSpawn = false
    loadingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    loadingGui.DisplayOrder = 2147483647
    loadingGui.Parent = guiParent

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.new(0, 360, 0, 92)
    card.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    card.BackgroundTransparency = 0.15
    card.BorderSizePixel = 0
    card.Parent = loadingGui

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 12)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(65, 65, 65)
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 16, 0, 16)
    titleLabel.Size = UDim2.new(1, -32, 0, 20)
    titleLabel.Text = "Bloxtrike"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = card

    local statusLabel = Instance.new("TextLabel")
    statusLabel.BackgroundTransparency = 1
    statusLabel.Position = UDim2.new(0, 16, 0, 42)
    statusLabel.Size = UDim2.new(1, -32, 0, 34)
    statusLabel.Text = tostring(message or "Loading Bloxtrike...")
    statusLabel.TextColor3 = Color3.fromRGB(205, 205, 205)
    statusLabel.TextSize = 12
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextWrapped = true
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextYAlignment = Enum.TextYAlignment.Top
    statusLabel.Parent = card

    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(loadingGui)
        elseif protect_gui then protect_gui(loadingGui) end
    end)

    return {
        gui = loadingGui,
        setText = function(text)
            if statusLabel and statusLabel.Parent then
                statusLabel.Text = tostring(text or "Loading Bloxtrike...")
            end
        end,
        dismiss = function()
            if loadingGui and loadingGui.Parent then loadingGui:Destroy() end
        end,
    }
end

-- ─── ERROR HANDLING ───

local function kickOnFatal(err)
    local detailed = "[Bloxtrike] Loader error: " .. tostring(err)
    local firstLine = tostring(err or ""):match("([^\r\n]+)") or tostring(err or "")
    firstLine = firstLine:gsub("[^\32-\126]", "?"):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #firstLine > 120 then firstLine = firstLine:sub(1, 117) .. "..." end
    local short = "[Bloxtrike] Loader error"
    if firstLine ~= "" then short = short .. " | " .. firstLine end
    warn(detailed)
    local player = game and game:GetService("Players") and game:GetService("Players").LocalPlayer
    if player then pcall(function() player:Kick(short) end) end
    error(short, 0)
end

local function kickUnsupported(missing)
    local msg = "[Bloxtrike] Executor doesn't support required functions"
    if type(missing) == "table" and #missing > 0 then
        msg = msg .. " | " .. table.concat(missing, ", ")
    end
    local player = game:GetService("Players").LocalPlayer
    if player then pcall(function() player:Kick(msg) end) end
    error(msg, 0)
end

-- ─── CAPABILITY CHECK ───

local function collectMissingSupport()
    local missing = {}
    if type(loadstring) ~= "function" then missing[#missing+1] = "loadstring" end
    if type(cloneref) ~= "function" then missing[#missing+1] = "cloneref" end
    local hasHttp = (syn and type(syn.request) == "function") or (http and type(http.request) == "function") or (game and type(game.HttpGet) == "function")
    if not hasHttp then missing[#missing+1] = "HTTP" end
    if not (Drawing and type(Drawing.new) == "function") then missing[#missing+1] = "Drawing.new" end
    if type(mousemoverel) ~= "function" then missing[#missing+1] = "mousemoverel" end
    if type(mouse1click) ~= "function" then missing[#missing+1] = "mouse1click" end
    if type(hookfunction) ~= "function" then missing[#missing+1] = "hookfunction" end
    if type(getgc) ~= "function" then missing[#missing+1] = "getgc" end
    if type(isfolder) ~= "function" then missing[#missing+1] = "isfolder" end
    if type(makefolder) ~= "function" then missing[#missing+1] = "makefolder" end
    if type(isfile) ~= "function" then missing[#missing+1] = "isfile" end
    if type(readfile) ~= "function" then missing[#missing+1] = "readfile" end
    if type(writefile) ~= "function" then missing[#missing+1] = "writefile" end
    if type(listfiles) ~= "function" then missing[#missing+1] = "listfiles" end
    if type(delfile) ~= "function" then missing[#missing+1] = "delfile" end
    return missing
end

-- ─── FILE FETCHER ───

local MAX_CONCURRENT_FETCHES = 4

local function fetchFilesInBatches(fileList, fetcher)
    local sources = {}
    local total = #fileList
    local index = 1

    local function validate(relPath, body)
        local name = getFileName(relPath)
        if type(body) ~= "string" or body == "" then return nil, "Failed to fetch: " .. name end
        local low = body:sub(1, 256):lower()
        if low:find("<!doctype html>", 1, true) then return nil, "Non-raw response for: " .. name end
        if low:find("<html", 1, true) then return nil, "HTML returned for: " .. name end
        if body == "404: Not Found" then return nil, "Missing file: " .. name end
        return body
    end

    while index <= total do
        local batch = {}
        local size = 0
        while index <= total and size < MAX_CONCURRENT_FETCHES do
            size = size + 1
            batch[size] = fileList[index]
            index = index + 1
        end

        local pending = #batch
        local completed = 0
        local batchErrors = {}

        for _, relPath in ipairs(batch) do
            task.spawn(function()
                local ok, body = pcall(function() return fetcher(DEFAULT_BASE_URL .. "/" .. relPath) end)
                if not ok then
                    batchErrors[relPath] = "Failed to fetch: " .. getFileName(relPath)
                else
                    local vbody, verr = validate(relPath, body)
                    if vbody then sources[relPath] = vbody else batchErrors[relPath] = verr end
                end
                completed = completed + 1
            end)
        end

        while completed < pending do task.wait() end
        for _, relPath in ipairs(batch) do
            if batchErrors[relPath] then error(batchErrors[relPath], 0) end
        end
    end

    return sources
end

-- ─── ENTRY POINT ───

assert(type(DEFAULT_BASE_URL) == "string" and DEFAULT_BASE_URL ~= "", "DEFAULT_BASE_URL must not be empty")

local missingSupport = collectMissingSupport()
if #missingSupport > 0 then kickUnsupported(missingSupport) end

local httpGet = getHttpGet()

-- No whitelist check — fully removed.

local loadingOverlay = createLoadingOverlay("Fetching script files...")

local files = {
    "ui_lib.lua",
    "src/shared/Cleaner.lua",
    "src/shared/ErrorHandler.lua",
    "src/shared/Services.lua",
    "src/shared/Globals.lua",
    "src/features/combat/Aimbot.lua",
    "src/features/combat/TriggerBot.lua",
    "src/features/combat/Hitbox.lua",
    "src/features/combat/Rage.lua",
    "src/features/movement/BunnyHop.lua",
    "src/features/movement/MovementSpeed.lua",
    "src/features/skins/Skinchanger.lua",
    "src/features/visuals/ESP.lua",
    "src/features/visuals/Chams.lua",
    "src/features/visuals/KillEffects.lua",
    "src/features/visuals/WorldEffects.lua",
}

local ok, result = xpcall(function()
    local sources = fetchFilesInBatches(files, httpGet)
    loadingOverlay.dismiss()

    -- Module loader (safe — won't cache nil results)
    local moduleCache = {}
    local moduleLoaded = {}

    local function loadModule(path)
        if moduleLoaded[path] then return moduleCache[path] end
        local src = sources[path]
        assert(type(src) == "string" and src ~= "", "Missing/empty module: " .. tostring(path))
        local chunk, compileErr = loadstring(src, "@" .. path)
        assert(chunk, tostring(compileErr) .. " (" .. path .. ")")
        local okRun, ret = pcall(chunk)
        assert(okRun, tostring(ret) .. " (" .. path .. ")")
        moduleLoaded[path] = true
        moduleCache[path] = ret
        return ret
    end

    -- Load shared modules
    local Cleaner = loadModule("src/shared/Cleaner.lua")
    local Services = loadModule("src/shared/Services.lua")
    local ErrorHandler = loadModule("src/shared/ErrorHandler.lua")
    local GlobalsFactory = loadModule("src/shared/Globals.lua")
    local UILib = loadModule("ui_lib.lua")

    -- Load feature modules
    local Aimbot = loadModule("src/features/combat/Aimbot.lua")
    local TriggerBot = loadModule("src/features/combat/TriggerBot.lua")
    local Hitbox = loadModule("src/features/combat/Hitbox.lua")
    local Rage = loadModule("src/features/combat/Rage.lua")
    local BunnyHop = loadModule("src/features/movement/BunnyHop.lua")
    local MovementSpeed = loadModule("src/features/movement/MovementSpeed.lua")
    local ESP = loadModule("src/features/visuals/ESP.lua")
    local Chams = loadModule("src/features/visuals/Chams.lua")
    local KillEffects = loadModule("src/features/visuals/KillEffects.lua")
    local WorldEffects = loadModule("src/features/visuals/WorldEffects.lua")
    local Skinchanger = loadModule("src/features/skins/Skinchanger.lua")

    -- Build application context
    local globals = GlobalsFactory(Services)
    local errorHandler = ErrorHandler.new(Services)
    local context = {
        services = Services,
        globals = globals,
        Cleaner = Cleaner,
        errorHandler = errorHandler,
    }

    -- Cleanup previous instance
    if getgenv and getgenv().BloxtrikeCleanup then
        pcall(getgenv().BloxtrikeCleanup)
    end

    local appCleaner = Cleaner.new()

    -- Instantiate all features
    local features = {
        aimbot = Aimbot.new(context),
        triggerBot = TriggerBot.new(context),
        hitbox = Hitbox.new(context),
        rage = Rage.new(context),
        bunnyHop = BunnyHop.new(context),
        movementSpeed = MovementSpeed.new(context),
        esp = ESP.new(context),
        chams = Chams.new(context),
        killEffects = KillEffects.new(context),
        worldEffects = WorldEffects.new(context),
        skinchanger = Skinchanger.new(context),
    }

    for _, feat in pairs(features) do
        appCleaner:Give(function()
            if feat and feat.Destroy then feat:Destroy() end
        end)
    end

    appCleaner:Give(errorHandler:Connect(Services.RunService.Heartbeat, "Movement Heartbeat", function()
        if features.bunnyHop and features.bunnyHop.Tick then features.bunnyHop:Tick() end
        if features.movementSpeed and features.movementSpeed.Tick then features.movementSpeed:Tick() end
    end))

    -- Build UI
    local window = UILib.new("Bloxtrike", Enum.KeyCode.RightShift)
    window:setConfigFolder("Bloxtrike")
    window:onClose(errorHandler:Wrap("Window Close", function() appCleaner:Cleanup() end))

    if getgenv then
        getgenv().BloxtrikeCleanup = function()
            appCleaner:Cleanup()
            if window and window.screenGui and window.screenGui.Parent then
                window.screenGui:Destroy()
            end
        end
    end

    local combatTab = window:addTab("Combat")
    local skinsTab = window:addTab("Skins")
    local visualsTab = window:addTab("Visuals")
    local configTab = window:addTab("Config")

    window:switchTab(combatTab)
    window:addSection("Aimbot")

    local function safe(label, fn) return errorHandler:Wrap("UI - " .. label, fn) end

    window:addToggle("Aimbot Enabled", false, safe("Aimbot Enabled", function(v) features.aimbot:SetEnabled(v) end))
    window:addToggle("Aimbot Team Check", false, safe("Aimbot Team Check", function(v) features.aimbot:SetTeamCheck(v) end))
    window:addToggle("Aimbot Wall Check", false, safe("Aimbot Wall Check", function(v) features.aimbot:SetWallCheck(v) end))
    window:addToggle("Aimbot Show FOV", false, safe("Aimbot Show FOV", function(v) features.aimbot:SetShowFov(v) end))
    window:addSlider("Aimbot FOV Radius", 10, 500, 100, 10, safe("Aimbot FOV Radius", function(v) features.aimbot:SetFovRadius(v) end))
    window:addSlider("Aimbot Smoothing", 1, 10, 3, 1, safe("Aimbot Smoothing", function(v) features.aimbot:SetSmoothing(v) end))
    window:addSection("TriggerBot")
    window:addToggle("TriggerBot Enabled", false, safe("TriggerBot Enabled", function(v) features.triggerBot:SetEnabled(v) end))
    window:addSlider("TriggerBot Delay MS", 0, 500, 0, 10, safe("TriggerBot Delay MS", function(v) features.triggerBot:SetDelayMs(v) end))
    window:addSection("Hitbox")
    window:addToggle("Hitbox Enabled", false, safe("Hitbox Enabled", function(v) features.hitbox:SetEnabled(v) end))
    window:addToggle("Hitbox Team Check", false, safe("Hitbox Team Check", function(v) features.hitbox:SetTeamCheck(v) end))
    window:addSlider("Hitbox Size", 1, 3, 3, 0.1, safe("Hitbox Size", function(v) features.hitbox:SetSize(v) end))
    window:addSlider("Hitbox Transparency", 0, 1, 0.5, 0.05, safe("Hitbox Transparency", function(v) features.hitbox:SetTransparency(v) end))
    window:addSection("Rage")
    window:addToggle("Rage Mode", false, safe("Rage Mode", function(v) features.rage:SetRageMode(v) end))
    window:addSection("Aimlock")
    window:addToggle("Aimlock", false, safe("Aimlock", function(v) features.rage:SetAimlock(v) end))
    window:addDropdown("Aimlock Method", {"Raw Mouse"}, "Raw Mouse", safe("Aimlock Method", function(v) features.rage:SetAimlockMethod(v) end))
    window:addSlider("Aimlock Fov Size", 10, 1000, 150, 1, safe("Aimlock Fov Size", function(v) features.rage:SetAimlockFov(v) end))
    window:addSlider("Aim Smoothness", 1, 10, 2, 1, safe("Aim Smoothness", function(v) features.rage:SetAimSmoothness(v) end))
    window:addSlider("Aim Jitter (Randomize)", 0, 50, 10, 1, safe("Aim Jitter (Randomize)", function(v) features.rage:SetAimJitter(v) end))
    window:addToggle("FlickBOT", false, safe("FlickBOT", function(v) features.rage:SetFlickBot(v) end))
    window:addSection("Silent Aim")
    window:addToggle("Silent Aim", false, safe("Silent Aim", function(v) features.rage:SetSilentAim(v) end))
    window:addToggle("Ignore Walls / Wallbang", false, safe("Wallbang", function(v) features.rage:SetWallbang(v) end))
    window:addToggle("Dynamic Miss (Hit Chance)", false, safe("Dynamic Miss", function(v) features.rage:SetDynamicMiss(v) end))
    window:addSlider("Hit Chance %", 1, 100, 100, 1, safe("Hit Chance", function(v) features.rage:SetBaseHitChance(v) end))
    window:addToggle("Show Circle", false, safe("Show Circle", function(v) features.rage:SetShowFovCircle(v) end))
    window:addSlider("Fov Size", 50, 1000, 150, 1, safe("Fov Size", function(v) features.rage:SetFovSize(v) end))
    window:addSection("Targeting")
    window:addDropdown("TargetPart", features.rage:GetTargetParts(), features.rage:GetTargetPart(), safe("TargetPart", function(v) features.rage:SetTargetPart(v) end))
    window:addToggle("Random Part", false, safe("Random Part", function(v) features.rage:SetRandomPart(v) end))
    window:addToggle("360 FOV (All Directions)", false, safe("360 FOV", function(v) features.rage:SetFullFov360(v) end))
    window:addToggle("AimWall Check", true, safe("AimWall Check", function(v) features.rage:SetAimWallCheck(v) end))
    window:addToggle("TeamCheck", true, safe("TeamCheck", function(v) features.rage:SetTeamCheck(v) end))
    window:addSection("Weapon Mods")
    window:addToggle("Memory No Recoil", false, safe("No Recoil", function(v) features.rage:SetMemoryNoRecoil(v) end))
    window:addToggle("No Spread", false, safe("No Spread", function(v) features.rage:SetNoSpread(v) end))
    window:addToggle("Auto Clicker (Hold LMB)", false, safe("Auto Clicker", function(v) features.rage:SetAutoClicker(v) end))
    window:addSlider("Auto Click Delay (ms)", 10, 500, 50, 1, safe("Auto Click Delay", function(v) features.rage:SetAutoClickDelay(v) end))
    window:addToggle("Instant Reload", false, safe("Instant Reload", function(v) features.rage:SetInstantReload(v) end))
    window:addToggle("Insta Equip", false, safe("Insta Equip", function(v) features.rage:SetInstaEquip(v) end))
    window:addToggle("RCS", false, safe("RCS", function(v) features.rage:SetRcs(v) end))
    window:addSlider("RCS Strength", 0, 100, 50, 1, safe("RCS Strength", function(v) features.rage:SetRcsStrength(v) end))
    window:addSlider("RCS Delay", 0, 500, 0, 1, safe("RCS Delay", function(v) features.rage:SetRcsDelay(v) end))
    window:addSection("Movement")
    window:addToggle("Bunny Hop Enabled", false, safe("BHOP", function(v) features.bunnyHop:SetEnabled(v) end))
    window:addToggle("Movement Speed Enabled", false, safe("Move Speed", function(v) features.movementSpeed:SetEnabled(v) end))
    window:addSlider("Movement Speed (st/s)", 5, 32, 15, 1, safe("Move Speed Value", function(v) features.movementSpeed:SetSpeedValue(v) end))

    window:switchTab(skinsTab)
    window:addSection("Skin Changer")
    window:addToggle("Weapon Skin Changer Enabled", false, safe("Skin Changer", function(v) features.skinchanger:SetSkinChangerEnabled(v) end))
    window:addToggle("Knife Changer Enabled", false, safe("Knife Changer", function(v) features.skinchanger:SetKnifeChangerEnabled(v) end))

    local knifeModels = features.skinchanger:GetKnifeModels()
    local knifeSkinDropdown
    local knifeModelDropdown = window:addDropdown("Knife Model", knifeModels, features.skinchanger:GetKnifeModel(),
        safe("Knife Model", function(v)
            features.skinchanger:SetKnifeModel(v)
            if knifeSkinDropdown then
                local km = features.skinchanger:GetKnifeModel()
                knifeSkinDropdown:refresh(features.skinchanger:GetSkinOptions(km))
                knifeSkinDropdown:set(features.skinchanger:GetWeaponSkin(km))
            end
        end)
    )
    knifeSkinDropdown = window:addDropdown("Knife Skin",
        features.skinchanger:GetSkinOptions(features.skinchanger:GetKnifeModel()),
        features.skinchanger:GetWeaponSkin(features.skinchanger:GetKnifeModel()),
        safe("Knife Skin", function(v) features.skinchanger:SetWeaponSkin(features.skinchanger:GetKnifeModel(), v) end)
    )

    local function refreshKnifeSkin()
        local km = features.skinchanger:GetKnifeModel()
        knifeSkinDropdown:refresh(features.skinchanger:GetSkinOptions(km))
        knifeSkinDropdown:set(features.skinchanger:GetWeaponSkin(km))
    end

    local function queueSkinSync()
        task.spawn(function()
            task.wait(0.05)
            pcall(refreshKnifeSkin)
            pcall(function() features.skinchanger:ApplyNow() end)
            task.wait(0.35)
            pcall(function() features.skinchanger:ApplyNow() end)
            task.wait(0.8)
            pcall(function() features.skinchanger:ApplyNow() end)
        end)
    end

    knifeModelDropdown:set(features.skinchanger:GetKnifeModel())
    refreshKnifeSkin()

    window:addToggle("Glove Changer Enabled", false, safe("Glove Changer", function(v) features.skinchanger:SetGloveChangerEnabled(v) end))
    local gloveModels = features.skinchanger:GetGloveModels()
    local selGlove = features.skinchanger:GetGloveModel() or gloveModels[1] or "Default"
    local gloveSkinDropdown
    local gloveModelDropdown = window:addDropdown("Glove Model", gloveModels, selGlove,
        safe("Glove Model", function(v)
            features.skinchanger:SetGloveModel(v)
            if gloveSkinDropdown then
                gloveSkinDropdown:refresh(features.skinchanger:GetGloveSkinOptions(v))
                gloveSkinDropdown:set(features.skinchanger:GetGloveSkin(v))
            end
        end)
    )
    gloveSkinDropdown = window:addDropdown("Glove Skin",
        features.skinchanger:GetGloveSkinOptions(selGlove),
        features.skinchanger:GetGloveSkin(selGlove),
        safe("Glove Skin", function(v) features.skinchanger:SetGloveSkin(v) end)
    )
    window:addSlider("Skin Inventory Refresh Rate", 1, 10, 2, 1, safe("Refresh Rate", function(v) features.skinchanger:SetInventoryRefreshRate(v) end))
    window:addButton("Apply Skin Changes", safe("Apply Skins", function() features.skinchanger:ApplyNow(); refreshKnifeSkin() end))
    window:addSection("Weapon Skins")
    for _, wn in ipairs(features.skinchanger:GetWeaponNames()) do
        if not features.skinchanger:IsKnifeModel(wn) then
            window:addDropdown("Skin - " .. wn, features.skinchanger:GetSkinOptions(wn), features.skinchanger:GetWeaponSkin(wn),
                safe("Skin - " .. wn, function(v) features.skinchanger:SetWeaponSkin(wn, v) end))
        end
    end

    window:switchTab(visualsTab)
    window:addSection("ESP")
    window:addToggle("ESP Enabled", false, safe("ESP", function(v) features.esp:SetSetting("enabled", v) end))
    window:addToggle("ESP Team Check", false, safe("ESP Team Check", function(v) features.esp:SetSetting("teamCheck", v) end))
    window:addToggle("ESP Show Box", false, safe("ESP Box", function(v) features.esp:SetSetting("showBox", v) end))
    window:addToggle("ESP Show Health", false, safe("ESP Health", function(v) features.esp:SetSetting("showHealth", v) end))
    window:addToggle("ESP Show Name", false, safe("ESP Name", function(v) features.esp:SetSetting("showName", v) end))
    window:addToggle("ESP Show Distance", false, safe("ESP Distance", function(v) features.esp:SetSetting("showDistance", v) end))
    window:addToggle("ESP Show Skeleton", false, safe("ESP Skeleton", function(v) features.esp:SetSetting("showSkeleton", v) end))
    window:addToggle("ESP Show Head Dot", false, safe("ESP Head Dot", function(v) features.esp:SetSetting("showHeadDot", v) end))
    window:addToggle("ESP Show Tracers", false, safe("ESP Tracers", function(v) features.esp:SetSetting("showTracers", v) end))
    window:addToggle("ESP Rainbow", false, safe("ESP Rainbow", function(v) features.esp:SetSetting("rainbow", v) end))
    window:addSlider("ESP Rainbow Speed", 0.1, 10, 2, 0.1, safe("ESP Rainbow Speed", function(v) features.esp:SetSetting("rainbowSpeed", v) end))
    window:addSlider("ESP Text Size", 10, 20, 15, 1, safe("ESP Text Size", function(v) features.esp:SetSetting("textSize", v) end))
    window:addSlider("ESP Box Thickness", 1, 3, 1.5, 0.1, safe("ESP Box Thickness", function(v) features.esp:SetSetting("boxThickness", v) end))
    window:addSlider("ESP Max Distance", 0, 500, 0, 10, safe("ESP Max Distance", function(v) features.esp:SetSetting("maxDistance", v) end))
    window:addColorPicker("ESP Box Color", Color3.fromRGB(255,255,255), safe("ESP Box Color", function(v) features.esp:SetSetting("boxColor", v) end))
    window:addColorPicker("ESP Text Color", Color3.fromRGB(255,255,255), safe("ESP Text Color", function(v) features.esp:SetSetting("textColor", v) end))
    window:addColorPicker("ESP Skeleton Color", Color3.fromRGB(255,255,255), safe("ESP Skeleton Color", function(v) features.esp:SetSetting("skeletonColor", v) end))
    window:addColorPicker("ESP Tracer Color", Color3.fromRGB(255,51,153), safe("ESP Tracer Color", function(v) features.esp:SetSetting("tracerColor", v) end))
    window:addColorPicker("ESP Head Dot Color", Color3.fromRGB(255,255,255), safe("ESP Head Dot Color", function(v) features.esp:SetSetting("headDotColor", v) end))
    window:addSection("Chams")
    window:addToggle("Chams Rainbow", false, safe("Chams Rainbow", function(v) features.chams:SetSetting("rainbow", v) end))
    window:addSlider("Chams Rainbow Speed", 0.1, 10, 2, 0.1, safe("Chams Rainbow Speed", function(v) features.chams:SetSetting("rainbowSpeed", v) end))
    window:addToggle("Player Chams Enabled", false, safe("Player Chams", function(v) features.chams:SetSetting("playerEnabled", v) end))
    window:addToggle("Player Chams Team Check", false, safe("Player Chams TC", function(v) features.chams:SetSetting("playerTeamCheck", v) end))
    window:addToggle("Visible Only", false, safe("Visible Only", function(v) features.chams:SetSetting("playerVisibleOnly", v) end))
    window:addSlider("Player Chams Fill", 0, 1, 0.7, 0.05, safe("Player Fill", function(v) features.chams:SetSetting("playerFillTransparency", v) end))
    window:addSlider("Player Chams Outline", 0, 1, 0, 0.05, safe("Player Outline", function(v) features.chams:SetSetting("playerOutlineTransparency", v) end))
    window:addColorPicker("Player Chams Color", Color3.fromRGB(255,0,0), safe("Player Color", function(v) features.chams:SetSetting("playerColor", v) end))
    window:addToggle("Weapon Chams Enabled", false, safe("Weapon Chams", function(v) features.chams:SetSetting("weaponEnabled", v) end))
    window:addSlider("Weapon Chams Fill", 0, 1, 0.5, 0.05, safe("Weapon Fill", function(v) features.chams:SetSetting("weaponFillTransparency", v) end))
    window:addSlider("Weapon Chams Outline", 0, 1, 0, 0.05, safe("Weapon Outline", function(v) features.chams:SetSetting("weaponOutlineTransparency", v) end))
    window:addColorPicker("Weapon Chams Color", Color3.fromRGB(0,255,255), safe("Weapon Color", function(v) features.chams:SetSetting("weaponColor", v) end))
    window:addSection("Kill Effects")
    window:addToggle("Kill Effects Enabled", false, safe("Kill FX", function(v) features.killEffects:SetSetting("enabled", v) end))
    window:addSlider("Kill Effect Duration", 0.3, 2, 0.8, 0.1, safe("Kill Duration", function(v) features.killEffects:SetSetting("duration", v) end))
    window:addSlider("Kill Effect Intensity", 0.2, 1, 0.6, 0.1, safe("Kill Intensity", function(v) features.killEffects:SetSetting("intensity", v) end))
    window:addColorPicker("Kill Effect Color", Color3.fromRGB(255,0,100), safe("Kill Color", function(v) features.killEffects:SetSetting("color", v) end))
    window:addSection("World Effects")
    window:addToggle("Anti Flash", false, safe("Anti Flash", function(v) features.worldEffects:SetSetting("antiFlash", v) end))
    window:addToggle("Anti Smoke", false, safe("Anti Smoke", function(v) features.worldEffects:SetSetting("antiSmoke", v) end))

    do
        local orig = window.loadConfig
        function window:loadConfig(name)
            local ok, err = orig(self, name)
            if ok then queueSkinSync() end
            return ok, err
        end
    end

    window:switchTab(configTab)
    window:addConfigManager("default")

    task.defer(function()
        local ok, names = pcall(function() return window:listConfigs() end)
        if not ok or type(names) ~= "table" or #names == 0 then return end
        local sel, latest
        for _, name in ipairs(names) do
            if tostring(name):lower() ~= "default" then
                local payload
                pcall(function()
                    if window._readJsonFile and window._getConfigFilePath then
                        payload = window:_readJsonFile(window:_getConfigFilePath(name))
                    end
                end)
                local saved = type(payload) == "table" and type(payload.meta) == "table" and payload.meta.saved_at
                if type(saved) == "string" and (not latest or saved > latest) then
                    latest = saved; sel = name
                elseif not sel then sel = name end
            end
        end
        if sel then pcall(function() window:loadConfig(sel) end) end
    end)

    window:notify("Bloxtrike", "loaded.", nil, false)
    return { window = window, features = features }
end, function(err)
    if debug and debug.traceback then return tostring(err) .. "\n" .. debug.traceback() end
    return tostring(err)
end)

if not ok then
    pcall(function() loadingOverlay.dismiss() end)
    kickOnFatal(result)
end

return result
