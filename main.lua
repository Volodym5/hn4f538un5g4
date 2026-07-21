local DEFAULT_BASE_URL = "https://raw.githubusercontent.com/Volodym5/hn4f538un5g4/main"

local function getFileName(path)
    local text = tostring(path or "")
    return text:match("([^/\\]+)$") or text
end

local function getHttpGet()
    if syn and syn.request then
        return function(url)
            local response = syn.request({ Url = url, Method = "GET" })
            return response and response.Body
        end
    end

    if http and http.request then
        return function(url)
            local response = http.request({ Url = url, Method = "GET" })
            return response and response.Body
        end
    end

    if game and game.HttpGet then
        return function(url)
            return game:HttpGet(url)
        end
    end

    error("No HTTP request function is available in this executor.")
end

local function getGuiParent()
    local players = game:GetService("Players")
    local coreGui = game:GetService("CoreGui")
    local localPlayer = players.LocalPlayer
    local parent = (gethui and gethui()) or coreGui

    local ok = pcall(function()
        local probe = Instance.new("ScreenGui")
        probe.Parent = coreGui
        probe:Destroy()
    end)

    if not ok and localPlayer then
        parent = localPlayer:WaitForChild("PlayerGui")
    end

    return parent
end

local function createLoadingOverlay(message)
    local guiParent = getGuiParent()
    local existing = guiParent:FindFirstChild("BLOXTRIKE_BOOTSTRAP_LOADING")
    if existing then
        existing:Destroy()
    end

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
        if syn and syn.protect_gui then
            syn.protect_gui(loadingGui)
        elseif protect_gui then
            protect_gui(loadingGui)
        end
    end)

    return {
        gui = loadingGui,
        setText = function(text)
            if statusLabel and statusLabel.Parent then
                statusLabel.Text = tostring(text or "Loading Bloxtrike...")
            end
        end,
        dismiss = function()
            if loadingGui and loadingGui.Parent then
                loadingGui:Destroy()
            end
        end,
    }
end

local function kickOnFatal(err)
    local detailedMessage = "[Bloxtrike] Loader error: " .. tostring(err)
    local firstLine = tostring(err or ""):match("([^\r\n]+)") or tostring(err or "")
    firstLine = firstLine:gsub("[^\32-\126]", "?")
    firstLine = firstLine:gsub("%s+", " ")
    firstLine = firstLine:gsub("^%s+", ""):gsub("%s+$", "")
    if #firstLine > 120 then
        firstLine = firstLine:sub(1, 117) .. "..."
    end

    local shortMessage = "[Bloxtrike] Loader error"
    if firstLine ~= "" then
        shortMessage = shortMessage .. " | " .. firstLine
    end
    warn(detailedMessage)

    local players = game and game:GetService("Players")
    local player = players and players.LocalPlayer
    if player then
        pcall(function()
            player:Kick(shortMessage)
        end)
    end

    error(shortMessage, 0)
end

local function kickUnsupported(missing)
    local shortMessage = "[Bloxtrike] Executor doesn't support required functions"
    if type(missing) == "table" and #missing > 0 then
        shortMessage = shortMessage .. " | " .. table.concat(missing, ", ")
    end

    local players = game and game:GetService("Players")
    local player = players and players.LocalPlayer
    if player then
        pcall(function()
            player:Kick(shortMessage)
        end)
    end

    error(shortMessage, 0)
end

local function collectMissingSupport()
    local missing = {}

    if type(loadstring) ~= "function" then
        missing[#missing + 1] = "loadstring"
    end

    if type(cloneref) ~= "function" then
        missing[#missing + 1] = "cloneref"
    end

    local hasHttpSupport = (syn and type(syn.request) == "function")
        or (http and type(http.request) == "function")
        or (game and type(game.HttpGet) == "function")
    if not hasHttpSupport then
        missing[#missing + 1] = "HTTP"
    end

    if not (Drawing and type(Drawing.new) == "function") then
        missing[#missing + 1] = "Drawing.new"
    end

    if type(mousemoverel) ~= "function" then
        missing[#missing + 1] = "mousemoverel"
    end

    if type(mouse1click) ~= "function" then
        missing[#missing + 1] = "mouse1click"
    end

    if type(hookfunction) ~= "function" then
        missing[#missing + 1] = "hookfunction"
    end

    if type(getgc) ~= "function" then
        missing[#missing + 1] = "getgc"
    end

    if type(isfolder) ~= "function" then
        missing[#missing + 1] = "isfolder"
    end

    if type(makefolder) ~= "function" then
        missing[#missing + 1] = "makefolder"
    end

    if type(isfile) ~= "function" then
        missing[#missing + 1] = "isfile"
    end

    if type(readfile) ~= "function" then
        missing[#missing + 1] = "readfile"
    end

    if type(writefile) ~= "function" then
        missing[#missing + 1] = "writefile"
    end

    if type(listfiles) ~= "function" then
        missing[#missing + 1] = "listfiles"
    end

    if type(delfile) ~= "function" then
        missing[#missing + 1] = "delfile"
    end

    return missing
end

assert(type(DEFAULT_BASE_URL) == "string" and DEFAULT_BASE_URL ~= "", "DEFAULT_BASE_URL must not be empty")

local missingSupport = collectMissingSupport()
if #missingSupport > 0 then
    kickUnsupported(missingSupport)
end

local httpGet = getHttpGet()

-- ─── WHITELIST FULLY REMOVED ───

local loadingOverlay = createLoadingOverlay("Fetching script files...")

-- NOTE: "main.lua" is intentionally removed from this list.
-- This combined script IS main.lua, no need to fetch itself.
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
    --"src/features/combat/RapidFire.lua",
    "src/features/movement/BunnyHop.lua",
    "src/features/movement/MovementSpeed.lua",
    "src/features/skins/Skinchanger.lua",
    "src/features/visuals/ESP.lua",
    "src/features/visuals/Chams.lua",
    --"src/features/visuals/BulletTracers.lua",
    --"src/features/visuals/ParticleEffects.lua",
    "src/features/visuals/KillEffects.lua",
    "src/features/visuals/WorldEffects.lua",
}

local MAX_CONCURRENT_FETCHES = 4

local function fetchFilesInBatches(fileList, fetcher)
    local sources = {}
    local total = #fileList
    local index = 1

    local function validateBody(relativePath, body)
        local fileName = getFileName(relativePath)
        if type(body) ~= "string" or body == "" then
            return nil, "Failed to fetch: " .. fileName
        end

        local lowered = body:sub(1, 256):lower()
        if lowered:find("<!doctype html>", 1, true) then
            return nil, "Non-raw response for: " .. fileName
        end

        if lowered:find("<html", 1, true) then
            return nil, "HTML returned for: " .. fileName
        end

        if body == "404: Not Found" then
            return nil, "Missing file: " .. fileName
        end

        return body
    end

    while index <= total do
        local batch = {}
        local batchSize = 0

        while index <= total and batchSize < MAX_CONCURRENT_FETCHES do
            batchSize = batchSize + 1
            batch[batchSize] = fileList[index]
            index = index + 1
        end

        local pending = #batch
        local completed = 0
        local batchErrors = {}

        for batchIndex, relativePath in ipairs(batch) do
            local fileName = getFileName(relativePath)
            local url = DEFAULT_BASE_URL .. "/" .. relativePath

            task.spawn(function()
                local okFetch, body = pcall(function()
                    return fetcher(url)
                end)

                if not okFetch then
                    batchErrors[relativePath] = "Failed to fetch: " .. fileName
                else
                    local validatedBody, err = validateBody(relativePath, body)
                    if validatedBody then
                        sources[relativePath] = validatedBody
                    else
                        batchErrors[relativePath] = err
                    end
                end

                completed = completed + 1
            end)
        end

        while completed < pending do
            task.wait(0)
        end

        for _, relativePath in ipairs(batch) do
            if batchErrors[relativePath] then
                error(batchErrors[relativePath], 0)
            end
        end
    end

    return sources
end

-- ─── FETCH AND BOOTSTRAP APPLICATION ───

local ok, result = xpcall(function()
    local sources = fetchFilesInBatches(files, httpGet)
    loadingOverlay.dismiss()

    -- Module cache and inline loader
    local moduleCache = {}

    local function loadModule(relativePath)
        if moduleCache[relativePath] ~= nil then
            return moduleCache[relativePath]
        end

        local source = sources[relativePath]
        assert(type(source) == "string" and source ~= "",
            "Failed to load module: " .. tostring(relativePath))

        local chunk, compileErr = loadstring(source, "@" .. relativePath)
        assert(chunk, compileErr or "Failed to compile: " .. relativePath)

        local okRun, runResult = pcall(chunk)
        assert(okRun, tostring(runResult))
        moduleCache[relativePath] = runResult
        return runResult
    end

    -- Shared modules
    local Cleaner = loadModule("src/shared/Cleaner.lua")
    local Services = loadModule("src/shared/Services.lua")
    local ErrorHandler = loadModule("src/shared/ErrorHandler.lua")
    local GlobalsFactory = loadModule("src/shared/Globals.lua")
    local UILib = loadModule("ui_lib.lua")

    -- Feature modules
    local Aimbot = loadModule("src/features/combat/Aimbot.lua")
    local TriggerBot = loadModule("src/features/combat/TriggerBot.lua")
    local Hitbox = loadModule("src/features/combat/Hitbox.lua")
    local Rage = loadModule("src/features/combat/Rage.lua")
    --local RapidFire = loadModule("src/features/combat/RapidFire.lua")
    local BunnyHop = loadModule("src/features/movement/BunnyHop.lua")
    local MovementSpeed = loadModule("src/features/movement/MovementSpeed.lua")
    local ESP = loadModule("src/features/visuals/ESP.lua")
    local Chams = loadModule("src/features/visuals/Chams.lua")
    --local BulletTracers = loadModule("src/features/visuals/BulletTracers.lua")
    --local ParticleEffects = loadModule("src/features/visuals/ParticleEffects.lua")
    local KillEffects = loadModule("src/features/visuals/KillEffects.lua")
    local WorldEffects = loadModule("src/features/visuals/WorldEffects.lua")
    local Skinchanger = loadModule("src/features/skins/Skinchanger.lua")

    local globals = GlobalsFactory(Services)
    local errorHandler = ErrorHandler.new(Services)
    local context = {
        services = Services,
        globals = globals,
        Cleaner = Cleaner,
        errorHandler = errorHandler,
    }

    if getgenv and getgenv().BloxtrikeCleanup then
        pcall(getgenv().BloxtrikeCleanup)
    end

    local appCleaner = Cleaner.new()

    local features = {
        aimbot = Aimbot.new(context),
        triggerBot = TriggerBot.new(context),
        hitbox = Hitbox.new(context),
        rage = Rage.new(context),
        --rapidFire = RapidFire.new(context),
        bunnyHop = BunnyHop.new(context),
        movementSpeed = MovementSpeed.new(context),
        esp = ESP.new(context),
        chams = Chams.new(context),
        --bulletTracers = BulletTracers.new(context),
        --particleEffects = ParticleEffects.new(context),
        killEffects = KillEffects.new(context),
        worldEffects = WorldEffects.new(context),
        skinchanger = Skinchanger.new(context),
    }

    for _, feature in pairs(features) do
        appCleaner:Give(function()
            if feature and feature.Destroy then
                feature:Destroy()
            end
        end)
    end

    appCleaner:Give(errorHandler:Connect(Services.RunService.Heartbeat, "Main Movement Heartbeat", function()
        if features.bunnyHop and features.bunnyHop.Tick then
            features.bunnyHop:Tick()
        end
        if features.movementSpeed and features.movementSpeed.Tick then
            features.movementSpeed:Tick()
        end
    end))

    local window = UILib.new("Bloxtrike", Enum.KeyCode.RightShift)
    window:setConfigFolder("Bloxtrike")
    window:onClose(errorHandler:Wrap("Window Close", function()
        appCleaner:Cleanup()
    end))

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

    local function safeUi(label, fn)
        return errorHandler:Wrap("UI - " .. label, fn)
    end

    window:addToggle("Aimbot Enabled", false, safeUi("Aimbot Enabled", function(value)
        features.aimbot:SetEnabled(value)
    end))
    window:addToggle("Aimbot Team Check", false, safeUi("Aimbot Team Check", function(value)
        features.aimbot:SetTeamCheck(value)
    end))
    window:addToggle("Aimbot Wall Check", false, safeUi("Aimbot Wall Check", function(value)
        features.aimbot:SetWallCheck(value)
    end))
    window:addToggle("Aimbot Show FOV", false, safeUi("Aimbot Show FOV", function(value)
        features.aimbot:SetShowFov(value)
    end))
    window:addSlider("Aimbot FOV Radius", 10, 500, 100, 10, safeUi("Aimbot FOV Radius", function(value)
        features.aimbot:SetFovRadius(value)
    end))
    window:addSlider("Aimbot Smoothing", 1, 10, 3, 1, safeUi("Aimbot Smoothing", function(value)
        features.aimbot:SetSmoothing(value)
    end))

    window:addSection("TriggerBot")
    window:addToggle("TriggerBot Enabled", false, safeUi("TriggerBot Enabled", function(value)
        features.triggerBot:SetEnabled(value)
    end))
    window:addSlider("TriggerBot Delay MS", 0, 500, 0, 10, safeUi("TriggerBot Delay MS", function(value)
        features.triggerBot:SetDelayMs(value)
    end))

    window:addSection("Hitbox")
    window:addToggle("Hitbox Enabled", false, safeUi("Hitbox Enabled", function(value)
        features.hitbox:SetEnabled(value)
    end))
    window:addToggle("Hitbox Team Check", false, safeUi("Hitbox Team Check", function(value)
        features.hitbox:SetTeamCheck(value)
    end))
    window:addSlider("Hitbox Size", 1, 3, 3, 0.1, safeUi("Hitbox Size", function(value)
        features.hitbox:SetSize(value)
    end))
    window:addSlider("Hitbox Transparency", 0, 1, 0.5, 0.05, safeUi("Hitbox Transparency", function(value)
        features.hitbox:SetTransparency(value)
    end))

    window:addSection("Rage")
    window:addToggle("Rage Mode", false, safeUi("Rage Mode", function(value)
        features.rage:SetRageMode(value)
    end))

    window:addSection("Aimlock")
    window:addToggle("Aimlock", false, safeUi("Aimlock", function(value)
        features.rage:SetAimlock(value)
    end))
    window:addDropdown("Aimlock Method", { "Raw Mouse" }, "Raw Mouse", safeUi("Aimlock Method", function(value)
        features.rage:SetAimlockMethod(value)
    end))
    window:addSlider("Aimlock Fov Size", 10, 1000, 150, 1, safeUi("Aimlock Fov Size", function(value)
        features.rage:SetAimlockFov(value)
    end))
    window:addSlider("Aim Smoothness", 1, 10, 2, 1, safeUi("Aim Smoothness", function(value)
        features.rage:SetAimSmoothness(value)
    end))
    window:addSlider("Aim Jitter (Randomize)", 0, 50, 10, 1, safeUi("Aim Jitter (Randomize)", function(value)
        features.rage:SetAimJitter(value)
    end))
    window:addToggle("FlickBOT", false, safeUi("FlickBOT", function(value)
        features.rage:SetFlickBot(value)
    end))

    window:addSection("Silent Aim")
    window:addToggle("Silent Aim", false, safeUi("Silent Aim", function(value)
        features.rage:SetSilentAim(value)
    end))
    window:addToggle("Ignore Walls / Wallbang", false, safeUi("Ignore Walls / Wallbang", function(value)
        features.rage:SetWallbang(value)
    end))
    window:addToggle("Dynamic Miss (Hit Chance)", false, safeUi("Dynamic Miss (Hit Chance)", function(value)
        features.rage:SetDynamicMiss(value)
    end))
    window:addSlider("Hit Chance %", 1, 100, 100, 1, safeUi("Hit Chance %", function(value)
        features.rage:SetBaseHitChance(value)
    end))
    window:addToggle("Show Circle", false, safeUi("Show Circle", function(value)
        features.rage:SetShowFovCircle(value)
    end))
    window:addSlider("Fov Size", 50, 1000, 150, 1, safeUi("Fov Size", function(value)
        features.rage:SetFovSize(value)
    end))

    window:addSection("Targeting")
    window:addDropdown("TargetPart", features.rage:GetTargetParts(), features.rage:GetTargetPart(), safeUi("TargetPart", function(value)
        features.rage:SetTargetPart(value)
    end))
    window:addToggle("Random Part", false, safeUi("Random Part", function(value)
        features.rage:SetRandomPart(value)
    end))
    window:addToggle("360 FOV (All Directions)", false, safeUi("360 FOV (All Directions)", function(value)
        features.rage:SetFullFov360(value)
    end))
    window:addToggle("AimWall Check", true, safeUi("AimWall Check", function(value)
        features.rage:SetAimWallCheck(value)
    end))
    window:addToggle("TeamCheck", true, safeUi("TeamCheck", function(value)
        features.rage:SetTeamCheck(value)
    end))

    window:addSection("Weapon Mods")
    window:addToggle("Memory No Recoil", false, safeUi("Memory No Recoil", function(value)
        features.rage:SetMemoryNoRecoil(value)
    end))
    window:addToggle("No Spread", false, safeUi("No Spread", function(value)
        features.rage:SetNoSpread(value)
    end))
    window:addToggle("Auto Clicker (Hold LMB)", false, safeUi("Auto Clicker (Hold LMB)", function(value)
        features.rage:SetAutoClicker(value)
    end))
    window:addSlider("Auto Click Delay (ms)", 10, 500, 50, 1, safeUi("Auto Click Delay (ms)", function(value)
        features.rage:SetAutoClickDelay(value)
    end))
    window:addToggle("Instant Reload", false, safeUi("Instant Reload", function(value)
        features.rage:SetInstantReload(value)
    end))
    window:addToggle("Insta Equip", false, safeUi("Insta Equip", function(value)
        features.rage:SetInstaEquip(value)
    end))
    window:addToggle("RCS", false, safeUi("RCS", function(value)
        features.rage:SetRcs(value)
    end))
    window:addSlider("RCS Strength", 0, 100, 50, 1, safeUi("RCS Strength", function(value)
        features.rage:SetRcsStrength(value)
    end))
    window:addSlider("RCS Delay", 0, 500, 0, 1, safeUi("RCS Delay", function(value)
        features.rage:SetRcsDelay(value)
    end))

    window:addSection("Movement")
    window:addToggle("Bunny Hop Enabled", false, safeUi("Bunny Hop Enabled", function(value)
        features.bunnyHop:SetEnabled(value)
    end))
    window:addToggle("Movement Speed Enabled", false, safeUi("Movement Speed Enabled", function(value)
        features.movementSpeed:SetEnabled(value)
    end))
    window:addSlider("Movement Speed (st/s)", 5, 32, 15, 1, safeUi("Movement Speed (st/s)", function(value)
        features.movementSpeed:SetSpeedValue(value)
    end))

    window:switchTab(skinsTab)
    window:addSection("Skin Changer")
    window:addToggle("Weapon Skin Changer Enabled", false, safeUi("Weapon Skin Changer Enabled", function(value)
        features.skinchanger:SetSkinChangerEnabled(value)
    end))
    window:addToggle("Knife Changer Enabled", false, safeUi("Knife Changer Enabled", function(value)
        features.skinchanger:SetKnifeChangerEnabled(value)
    end))

    local knifeModels = features.skinchanger:GetKnifeModels()
    local knifeSkinDropdown
    local knifeModelDropdown = window:addDropdown(
        "Knife Model",
        knifeModels,
        features.skinchanger:GetKnifeModel(),
        safeUi("Knife Model", function(value)
            features.skinchanger:SetKnifeModel(value)
            if knifeSkinDropdown then
                local knifeModel = features.skinchanger:GetKnifeModel()
                knifeSkinDropdown.refresh(features.skinchanger:GetSkinOptions(knifeModel))
                knifeSkinDropdown.set(features.skinchanger:GetWeaponSkin(knifeModel))
            end
        end)
    )

    knifeSkinDropdown = window:addDropdown(
        "Knife Skin",
        features.skinchanger:GetSkinOptions(features.skinchanger:GetKnifeModel()),
        features.skinchanger:GetWeaponSkin(features.skinchanger:GetKnifeModel()),
        safeUi("Knife Skin", function(value)
            features.skinchanger:SetWeaponSkin(features.skinchanger:GetKnifeModel(), value)
        end)
    )

    local function refreshKnifeSkinDropdown()
        local knifeModel = features.skinchanger:GetKnifeModel()
        knifeSkinDropdown.refresh(features.skinchanger:GetSkinOptions(knifeModel))
        knifeSkinDropdown.set(features.skinchanger:GetWeaponSkin(knifeModel))
    end

    local function queueSkinchangerConfigSync()
        task.spawn(function()
            task.wait(0.05)
            pcall(refreshKnifeSkinDropdown)
            pcall(function()
                features.skinchanger:ApplyNow()
            end)
            task.wait(0.35)
            pcall(function()
                features.skinchanger:ApplyNow()
            end)
            task.wait(0.8)
            pcall(function()
                features.skinchanger:ApplyNow()
            end)
        end)
    end

    knifeModelDropdown.set(features.skinchanger:GetKnifeModel())
    refreshKnifeSkinDropdown()

    window:addToggle("Glove Changer Enabled", false, safeUi("Glove Changer Enabled", function(value)
        features.skinchanger:SetGloveChangerEnabled(value)
    end))

    local gloveModels = features.skinchanger:GetGloveModels()
    local selectedGloveModel = features.skinchanger:GetGloveModel() or gloveModels[1] or "Default"
    local gloveSkinDropdown

    local gloveModelDropdown = window:addDropdown(
        "Glove Model",
        gloveModels,
        selectedGloveModel,
        safeUi("Glove Model", function(value)
            features.skinchanger:SetGloveModel(value)
            local skinOptions = features.skinchanger:GetGloveSkinOptions(value)
            if gloveSkinDropdown then
                gloveSkinDropdown.refresh(skinOptions)
                gloveSkinDropdown.set(features.skinchanger:GetGloveSkin(value))
            end
        end)
    )

    gloveSkinDropdown = window:addDropdown(
        "Glove Skin",
        features.skinchanger:GetGloveSkinOptions(selectedGloveModel),
        features.skinchanger:GetGloveSkin(selectedGloveModel),
        safeUi("Glove Skin", function(value)
            features.skinchanger:SetGloveSkin(value)
        end)
    )

    window:addSlider("Skin Inventory Refresh Rate", 1, 10, 2, 1, safeUi("Skin Inventory Refresh Rate", function(value)
        features.skinchanger:SetInventoryRefreshRate(value)
    end))
    window:addButton("Apply Skin Changes", safeUi("Apply Skin Changes", function()
        features.skinchanger:ApplyNow()
        refreshKnifeSkinDropdown()
    end))

    window:addSection("Weapon Skins")
    for _, weaponName in ipairs(features.skinchanger:GetWeaponNames()) do
        if not features.skinchanger:IsKnifeModel(weaponName) then
            window:addDropdown(
                "Skin - " .. weaponName,
                features.skinchanger:GetSkinOptions(weaponName),
                features.skinchanger:GetWeaponSkin(weaponName),
                safeUi("Skin - " .. weaponName, function(value)
                    features.skinchanger:SetWeaponSkin(weaponName, value)
                end)
            )
        end
    end

    window:switchTab(visualsTab)
    window:addSection("ESP")
    window:addToggle("ESP Enabled", false, safeUi("ESP Enabled", function(value)
        features.esp:SetSetting("enabled", value)
    end))
    window:addToggle("ESP Team Check", false, safeUi("ESP Team Check", function(value)
        features.esp:SetSetting("teamCheck", value)
    end))
    window:addToggle("ESP Show Box", false, safeUi("ESP Show Box", function(value)
        features.esp:SetSetting("showBox", value)
    end))
    window:addToggle("ESP Show Health", false, safeUi("ESP Show Health", function(value)
        features.esp:SetSetting("showHealth", value)
    end))
    window:addToggle("ESP Show Name", false, safeUi("ESP Show Name", function(value)
        features.esp:SetSetting("showName", value)
    end))
    window:addToggle("ESP Show Distance", false, safeUi("ESP Show Distance", function(value)
        features.esp:SetSetting("showDistance", value)
    end))
    window:addToggle("ESP Show Skeleton", false, safeUi("ESP Show Skeleton", function(value)
        features.esp:SetSetting("showSkeleton", value)
    end))
    window:addToggle("ESP Show Head Dot", false, safeUi("ESP Show Head Dot", function(value)
        features.esp:SetSetting("showHeadDot", value)
    end))
    window:addToggle("ESP Show Tracers", false, safeUi("ESP Show Tracers", function(value)
        features.esp:SetSetting("showTracers", value)
    end))
    window:addToggle("ESP Rainbow", false, safeUi("ESP Rainbow", function(value)
        features.esp:SetSetting("rainbow", value)
    end))
    window:addSlider("ESP Rainbow Speed", 0.1, 10, 2, 0.1, safeUi("ESP Rainbow Speed", function(value)
        features.esp:SetSetting("rainbowSpeed", value)
    end))
    window:addSlider("ESP Text Size", 10, 20, 15, 1, safeUi("ESP Text Size", function(value)
        features.esp:SetSetting("textSize", value)
    end))
    window:addSlider("ESP Box Thickness", 1, 3, 1.5, 0.1, safeUi("ESP Box Thickness", function(value)
        features.esp:SetSetting("boxThickness", value)
    end))
    window:addSlider("ESP Max Distance", 0, 500, 0, 10, safeUi("ESP Max Distance", function(value)
        features.esp:SetSetting("maxDistance", value)
    end))
    window:addColorPicker("ESP Box Color", Color3.fromRGB(255, 255, 255), safeUi("ESP Box Color", function(value)
        features.esp:SetSetting("boxColor", value)
    end))
    window:addColorPicker("ESP Text Color", Color3.fromRGB(255, 255, 255), safeUi("ESP Text Color", function(value)
        features.esp:SetSetting("textColor", value)
    end))
    window:addColorPicker("ESP Skeleton Color", Color3.fromRGB(255, 255, 255), safeUi("ESP Skeleton Color", function(value)
        features.esp:SetSetting("skeletonColor", value)
    end))
    window:addColorPicker("ESP Tracer Color", Color3.fromRGB(255, 51, 153), safeUi("ESP Tracer Color", function(value)
        features.esp:SetSetting("tracerColor", value)
    end))
    window:addColorPicker("ESP Head Dot Color", Color3.fromRGB(255, 255, 255), safeUi("ESP Head Dot Color", function(value)
        features.esp:SetSetting("headDotColor", value)
    end))

    window:addSection("Chams")
    window:addToggle("Chams Rainbow", false, safeUi("Chams Rainbow", function(value)
        features.chams:SetSetting("rainbow", value)
    end))
    window:addSlider("Chams Rainbow Speed", 0.1, 10, 2, 0.1, safeUi("Chams Rainbow Speed", function(value)
        features.chams:SetSetting("rainbowSpeed", value)
    end))
    window:addToggle("Player Chams Enabled", false, safeUi("Player Chams Enabled", function(value)
        features.chams:SetSetting("playerEnabled", value)
    end))
    window:addToggle("Player Chams Team Check", false, safeUi("Player Chams Team Check", function(value)
        features.chams:SetSetting("playerTeamCheck", value)
    end))
    window:addToggle("Visible Only", false, safeUi("Player Chams Visible Only", function(value)
        features.chams:SetSetting("playerVisibleOnly", value)
    end))
    window:addSlider("Player Chams Fill", 0, 1, 0.7, 0.05, safeUi("Player Chams Fill", function(value)
        features.chams:SetSetting("playerFillTransparency", value)
    end))
    window:addSlider("Player Chams Outline", 0, 1, 0, 0.05, safeUi("Player Chams Outline", function(value)
        features.chams:SetSetting("playerOutlineTransparency", value)
    end))
    window:addColorPicker("Player Chams Color", Color3.fromRGB(255, 0, 0), safeUi("Player Chams Color", function(value)
        features.chams:SetSetting("playerColor", value)
    end))
    window:addToggle("Weapon Chams Enabled", false, safeUi("Weapon Chams Enabled", function(value)
        features.chams:SetSetting("weaponEnabled", value)
    end))
    window:addSlider("Weapon Chams Fill", 0, 1, 0.5, 0.05, safeUi("Weapon Chams Fill", function(value)
        features.chams:SetSetting("weaponFillTransparency", value)
    end))
    window:addSlider("Weapon Chams Outline", 0, 1, 0, 0.05, safeUi("Weapon Chams Outline", function(value)
        features.chams:SetSetting("weaponOutlineTransparency", value)
    end))
    window:addColorPicker("Weapon Chams Color", Color3.fromRGB(0, 255, 255), safeUi("Weapon Chams Color", function(value)
        features.chams:SetSetting("weaponColor", value)
    end))

    window:addSection("Kill Effects")
    window:addToggle("Kill Effects Enabled", false, safeUi("Kill Effects Enabled", function(value)
        features.killEffects:SetSetting("enabled", value)
    end))
    window:addSlider("Kill Effect Duration", 0.3, 2, 0.8, 0.1, safeUi("Kill Effect Duration", function(value)
        features.killEffects:SetSetting("duration", value)
    end))
    window:addSlider("Kill Effect Intensity", 0.2, 1, 0.6, 0.1, safeUi("Kill Effect Intensity", function(value)
        features.killEffects:SetSetting("intensity", value)
    end))
    window:addColorPicker("Kill Effect Color", Color3.fromRGB(255, 0, 100), safeUi("Kill Effect Color", function(value)
        features.killEffects:SetSetting("color", value)
    end))

    window:addSection("World Effects")
    window:addToggle("Anti Flash", false, safeUi("Anti Flash", function(value)
        features.worldEffects:SetSetting("antiFlash", value)
    end))
    window:addToggle("Anti Smoke", false, safeUi("Anti Smoke", function(value)
        features.worldEffects:SetSetting("antiSmoke", value)
    end))

    do
        local originalLoadConfig = window.loadConfig
        function window:loadConfig(name)
            local ok, err = originalLoadConfig(self, name)
            if ok then
                queueSkinchangerConfigSync()
            end
            return ok, err
        end
    end

    window:switchTab(configTab)
    window:addConfigManager("default")

    task.defer(function()
        local okList, configNames = pcall(function()
            return window:listConfigs()
        end)
        if not okList or type(configNames) ~= "table" or #configNames == 0 then
            return
        end

        local selectedConfig = nil
        local latestSavedAt = nil

        for _, configName in ipairs(configNames) do
            local normalizedName = tostring(configName):lower()
            if normalizedName ~= "default" then
                local payload = nil
                pcall(function()
                    if window._readJsonFile and window._getConfigFilePath then
                        payload = window:_readJsonFile(window:_getConfigFilePath(configName))
                    end
                end)

                local savedAt = type(payload) == "table"
                    and type(payload.meta) == "table"
                    and payload.meta.saved_at

                if type(savedAt) == "string" and (not latestSavedAt or savedAt > latestSavedAt) then
                    latestSavedAt = savedAt
                    selectedConfig = configName
                elseif not selectedConfig then
                    selectedConfig = configName
                end
            end
        end

        if selectedConfig then
            pcall(function()
                window:loadConfig(selectedConfig)
            end)
        end
    end)

    window:notify("Bloxtrike", "loaded.", nil, false)

    return {
        window = window,
        features = features,
    }
end, function(err)
    if debug and debug.traceback then
        return tostring(err) .. "\n" .. debug.traceback()
    end
    return tostring(err)
end)

if not ok then
    pcall(function()
        loadingOverlay.dismiss()
    end)
    kickOnFatal(result)
end

return result
