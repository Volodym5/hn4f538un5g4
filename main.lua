local bootstrap = ...
if type(bootstrap) ~= "table" then
    bootstrap = {}
end

local function normalizePath(path)
    return tostring(path or ""):gsub("\\", "/")
end

local function joinPath(...)
    local parts = { ... }
    local out = {}

    for _, part in ipairs(parts) do
        local text = normalizePath(part):gsub("^/+", ""):gsub("/+$", "")
        if text ~= "" then
            out[#out + 1] = text
        end
    end

    return table.concat(out, "/")
end

local function getRootPath()
    local source = debug.info and debug.info(1, "s")
    if type(source) == "string" and source ~= "" then
        source = normalizePath(source):gsub("^@", "")
        return source:match("^(.*)/[^/]+$") or "."
    end

    return "."
end

local ROOT = getRootPath()
local moduleCache = {}
local httpGet = (syn and syn.request and function(url)
    local response = syn.request({ Url = url, Method = "GET" })
    return response and response.Body
end) or (http and http.request and function(url)
    local response = http.request({ Url = url, Method = "GET" })
    return response and response.Body
end)

if not httpGet and game and game.HttpGet then
    httpGet = function(url)
        return game:HttpGet(url)
    end
end

local function loadLocal(relativePath)
    local preloadedSources = bootstrap.moduleSources
    local baseUrl = bootstrap.baseUrl
    local cacheKey = relativePath

    if moduleCache[cacheKey] ~= nil then
        return moduleCache[cacheKey]
    end

    local chunk, err = nil, nil
    local source = nil

    if type(preloadedSources) == "table" and type(preloadedSources[relativePath]) == "string" then
        source = preloadedSources[relativePath]
        if loadstring then
            chunk, err = loadstring(source, "@" .. relativePath)
        end
    end

    if not chunk and type(baseUrl) == "string" and baseUrl ~= "" and httpGet then
        local url = joinPath(baseUrl, relativePath)
        local ok, body = pcall(httpGet, url)
        if ok and type(body) == "string" and body ~= "" then
            source = body
            if loadstring then
                chunk, err = loadstring(source, "@" .. url)
            end
        end
    end

    assert(chunk, err or ("Failed to load module: " .. tostring(relativePath)))

    local result = chunk()
    moduleCache[cacheKey] = result
    return result
end

local Cleaner = loadLocal("src/shared/Cleaner.lua")
local Services = loadLocal("src/shared/Services.lua")
local ErrorHandler = loadLocal("src/shared/ErrorHandler.lua")
local GlobalsFactory = loadLocal("src/shared/Globals.lua")
local UILib = loadLocal("ui_lib.lua")

local Aimbot = loadLocal("src/features/combat/Aimbot.lua")
local TriggerBot = loadLocal("src/features/combat/TriggerBot.lua")
local Hitbox = loadLocal("src/features/combat/Hitbox.lua")
local Rage = loadLocal("src/features/combat/Rage.lua")
--local RapidFire = loadLocal("src/features/combat/RapidFire.lua")
local BunnyHop = loadLocal("src/features/movement/BunnyHop.lua")
local MovementSpeed = loadLocal("src/features/movement/MovementSpeed.lua")
local ESP = loadLocal("src/features/visuals/ESP.lua")
local Chams = loadLocal("src/features/visuals/Chams.lua")
--local BulletTracers = loadLocal("src/features/visuals/BulletTracers.lua")
--local ParticleEffects = loadLocal("src/features/visuals/ParticleEffects.lua")
local KillEffects = loadLocal("src/features/visuals/KillEffects.lua")
local WorldEffects = loadLocal("src/features/visuals/WorldEffects.lua")
local Skinchanger = loadLocal("src/features/skins/Skinchanger.lua")

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
   -- bulletTracers = BulletTracers.new(context),
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

local Library = loadLocal("ui_lib.lua")
local SaveManager = Library.SaveManager

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()

local Window = Library:CreateWindow({
    Title = "Bloxtrike",
    Footer = "Bloxtrike",
    Size = UDim2.fromOffset(760, 560),
    Center = true,
    AutoShow = true,
    ToggleKeybind = Enum.KeyCode.RightShift,
    SettingsTab = true,
    ConfigFolder = "Bloxtrike",
})

local function safeUi(label, fn)
    return errorHandler:Wrap("UI - " .. label, fn)
end

local combatTab = Window:AddTab("Combat")
local skinsTab = Window:AddTab("Skins")
local visualsTab = Window:AddTab("Visuals")
local configTab = Window:AddTab("Config")

local Left = combatTab:AddLeftGroupbox("Combat")
local Right = combatTab:AddRightGroupbox("Combat 2")

Left:AddToggle("Aimbot Enabled", {
    Text = "Aimbot Enabled",
    Default = false,
    Callback = safeUi("Aimbot Enabled", function(value)
        features.aimbot:SetEnabled(value)
    end),
})

Left:AddToggle("Aimbot Team Check", {
    Text = "Aimbot Team Check",
    Default = false,
    Callback = safeUi("Aimbot Team Check", function(value)
        features.aimbot:SetTeamCheck(value)
    end),
})

Left:AddToggle("Aimbot Wall Check", {
    Text = "Aimbot Wall Check",
    Default = false,
    Callback = safeUi("Aimbot Wall Check", function(value)
        features.aimbot:SetWallCheck(value)
    end),
})

Left:AddToggle("Aimbot Show FOV", {
    Text = "Aimbot Show FOV",
    Default = false,
    Callback = safeUi("Aimbot Show FOV", function(value)
        features.aimbot:SetShowFov(value)
    end),
})

Left:AddSlider("Aimbot FOV Radius", {
    Text = "Aimbot FOV Radius",
    Default = 100,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Callback = safeUi("Aimbot FOV Radius", function(value)
        features.aimbot:SetFovRadius(value)
    end),
})

Left:AddSlider("Aimbot Smoothing", {
    Text = "Aimbot Smoothing",
    Default = 3,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = safeUi("Aimbot Smoothing", function(value)
        features.aimbot:SetSmoothing(value)
    end),
})

Right:AddToggle("TriggerBot Enabled", {
    Text = "TriggerBot Enabled",
    Default = false,
    Callback = safeUi("TriggerBot Enabled", function(value)
        features.triggerBot:SetEnabled(value)
    end),
})

Right:AddSlider("TriggerBot Delay MS", {
    Text = "TriggerBot Delay MS",
    Default = 0,
    Min = 0,
    Max = 500,
    Rounding = 0,
    Callback = safeUi("TriggerBot Delay MS", function(value)
        features.triggerBot:SetDelayMs(value)
    end),
})

Right:AddToggle("Hitbox Enabled", {
    Text = "Hitbox Enabled",
    Default = false,
    Callback = safeUi("Hitbox Enabled", function(value)
        features.hitbox:SetEnabled(value)
    end),
})

Right:AddToggle("Hitbox Team Check", {
    Text = "Hitbox Team Check",
    Default = false,
    Callback = safeUi("Hitbox Team Check", function(value)
        features.hitbox:SetTeamCheck(value)
    end),
})

Right:AddSlider("Hitbox Size", {
    Text = "Hitbox Size",
    Default = 3,
    Min = 1,
    Max = 3,
    Rounding = 1,
    Callback = safeUi("Hitbox Size", function(value)
        features.hitbox:SetSize(value)
    end),
})

Right:AddSlider("Hitbox Transparency", {
    Text = "Hitbox Transparency",
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = safeUi("Hitbox Transparency", function(value)
        features.hitbox:SetTransparency(value)
    end),
})

Left:AddToggle("Rage Mode", {
    Text = "Rage Mode",
    Default = false,
    Callback = safeUi("Rage Mode", function(value)
        features.rage:SetRageMode(value)
    end),
})

Left:AddLabel("Rage Toggle Key"):AddKeyPicker("Rage Toggle Key", {
    Text = "Rage Toggle Key",
    Default = "None",
    Mode = "Toggle",
    Callback = safeUi("Rage Toggle Key", function(value)
        features.rage:SetRageToggleKey(value)
    end),
})

Right:AddToggle("Aimlock", {
    Text = "Aimlock",
    Default = false,
    Callback = safeUi("Aimlock", function(value)
        features.rage:SetAimlock(value)
    end),
})

Right:AddDropdown("Aimlock Method", {
    Text = "Aimlock Method",
    Values = { "Raw Mouse" },
    Default = "Raw Mouse",
    Callback = safeUi("Aimlock Method", function(value)
        features.rage:SetAimlockMethod(value)
    end),
})

Right:AddSlider("Aimlock Fov Size", {
    Text = "Aimlock Fov Size",
    Default = 150,
    Min = 10,
    Max = 1000,
    Rounding = 0,
    Callback = safeUi("Aimlock Fov Size", function(value)
        features.rage:SetAimlockFov(value)
    end),
})

Right:AddSlider("Aim Smoothness", {
    Text = "Aim Smoothness",
    Default = 2,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = safeUi("Aim Smoothness", function(value)
        features.rage:SetAimSmoothness(value)
    end),
})

Right:AddSlider("Aim Jitter (Randomize)", {
    Text = "Aim Jitter (Randomize)",
    Default = 10,
    Min = 0,
    Max = 50,
    Rounding = 0,
    Callback = safeUi("Aim Jitter (Randomize)", function(value)
        features.rage:SetAimJitter(value)
    end),
})

Left:AddToggle("FlickBOT", {
    Text = "FlickBOT",
    Default = false,
    Callback = safeUi("FlickBOT", function(value)
        features.rage:SetFlickBot(value)
    end),
})

Left:AddToggle("Silent Aim", {
    Text = "Silent Aim",
    Default = false,
    Callback = safeUi("Silent Aim", function(value)
        features.rage:SetSilentAim(value)
    end),
})

Left:AddToggle("Ignore Walls / Wallbang", {
    Text = "Ignore Walls / Wallbang",
    Default = false,
    Callback = safeUi("Ignore Walls / Wallbang", function(value)
        features.rage:SetWallbang(value)
    end),
})

Left:AddToggle("Dynamic Miss (Hit Chance)", {
    Text = "Dynamic Miss (Hit Chance)",
    Default = false,
    Callback = safeUi("Dynamic Miss (Hit Chance", function(value)
        features.rage:SetDynamicMiss(value)
    end),
})

Left:AddSlider("Hit Chance %", {
    Text = "Hit Chance %",
    Default = 100,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = safeUi("Hit Chance %", function(value)
        features.rage:SetBaseHitChance(value)
    end),
})

Left:AddToggle("Show Circle", {
    Text = "Show Circle",
    Default = false,
    Callback = safeUi("Show Circle", function(value)
        features.rage:SetShowFovCircle(value)
    end),
})

Left:AddSlider("Fov Size", {
    Text = "Fov Size",
    Default = 150,
    Min = 50,
    Max = 1000,
    Rounding = 0,
    Callback = safeUi("Fov Size", function(value)
        features.rage:SetFovSize(value)
    end),
})

Right:AddDropdown("TargetPart", {
    Text = "TargetPart",
    Values = features.rage:GetTargetParts(),
    Default = features.rage:GetTargetPart(),
    Callback = safeUi("TargetPart", function(value)
        features.rage:SetTargetPart(value)
    end),
})

Right:AddToggle("Random Part", {
    Text = "Random Part",
    Default = false,
    Callback = safeUi("Random Part", function(value)
        features.rage:SetRandomPart(value)
    end),
})

Right:AddToggle("360 FOV (All Directions)", {
    Text = "360 FOV (All Directions)",
    Default = false,
    Callback = safeUi("360 FOV (All Directions)", function(value)
        features.rage:SetFullFov360(value)
    end),
})

Right:AddToggle("AimWall Check", {
    Text = "AimWall Check",
    Default = true,
    Callback = safeUi("AimWall Check", function(value)
        features.rage:SetAimWallCheck(value)
    end),
})

Right:AddToggle("TeamCheck", {
    Text = "TeamCheck",
    Default = true,
    Callback = safeUi("TeamCheck", function(value)
        features.rage:SetTeamCheck(value)
    end),
})

Left:AddToggle("Memory No Recoil", {
    Text = "Memory No Recoil",
    Default = false,
    Callback = safeUi("Memory No Recoil", function(value)
        features.rage:SetMemoryNoRecoil(value)
    end),
})

Left:AddToggle("No Spread", {
    Text = "No Spread",
    Default = false,
    Callback = safeUi("No Spread", function(value)
        features.rage:SetNoSpread(value)
    end),
})

Left:AddToggle("Auto Clicker (Hold LMB)", {
    Text = "Auto Clicker (Hold LMB)",
    Default = false,
    Callback = safeUi("Auto Clicker (Hold LMB)", function(value)
        features.rage:SetAutoClicker(value)
    end),
})

Left:AddSlider("Auto Click Delay (ms)", {
    Text = "Auto Click Delay (ms)",
    Default = 50,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Callback = safeUi("Auto Click Delay (ms)", function(value)
        features.rage:SetAutoClickDelay(value)
    end),
})

Left:AddToggle("Instant Reload", {
    Text = "Instant Reload",
    Default = false,
    Callback = safeUi("Instant Reload", function(value)
        features.rage:SetInstantReload(value)
    end),
})

Left:AddToggle("Insta Equip", {
    Text = "Insta Equip",
    Default = false,
    Callback = safeUi("Insta Equip", function(value)
        features.rage:SetInstaEquip(value)
    end),
})

Left:AddToggle("RCS", {
    Text = "RCS",
    Default = false,
    Callback = safeUi("RCS", function(value)
        features.rage:SetRcs(value)
    end),
})

Left:AddSlider("RCS Strength", {
    Text = "RCS Strength",
    Default = 50,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Callback = safeUi("RCS Strength", function(value)
        features.rage:SetRcsStrength(value)
    end),
})

Left:AddSlider("RCS Delay", {
    Text = "RCS Delay",
    Default = 0,
    Min = 0,
    Max = 500,
    Rounding = 0,
    Callback = safeUi("RCS Delay", function(value)
        features.rage:SetRcsDelay(value)
    end),
})

Right:AddToggle("Bunny Hop Enabled", {
    Text = "Bunny Hop Enabled",
    Default = false,
    Callback = safeUi("Bunny Hop Enabled", function(value)
        features.bunnyHop:SetEnabled(value)
    end),
})

Right:AddToggle("Movement Speed Enabled", {
    Text = "Movement Speed Enabled",
    Default = false,
    Callback = safeUi("Movement Speed Enabled", function(value)
        features.movementSpeed:SetEnabled(value)
    end),
})

Right:AddSlider("Movement Speed (st/s)", {
    Text = "Movement Speed (st/s)",
    Default = 15,
    Min = 5,
    Max = 32,
    Rounding = 0,
    Callback = safeUi("Movement Speed (st/s)", function(value)
        features.movementSpeed:SetSpeedValue(value)
    end),
})

skinsTab:Show()

local skinsLeft = skinsTab:AddLeftGroupbox("Skin Changer")
local skinsRight = skinsTab:AddRightGroupbox("Weapon Skins")

skinsLeft:AddToggle("Weapon Skin Changer Enabled", {
    Text = "Weapon Skin Changer Enabled",
    Default = false,
    Callback = safeUi("Weapon Skin Changer Enabled", function(value)
        features.skinchanger:SetSkinChangerEnabled(value)
    end),
})

skinsLeft:AddToggle("Knife Changer Enabled", {
    Text = "Knife Changer Enabled",
    Default = false,
    Callback = safeUi("Knife Changer Enabled", function(value)
        features.skinchanger:SetKnifeChangerEnabled(value)
    end),
})

local knifeModelDropdown = skinsLeft:AddDropdown("Knife Model", {
    Text = "Knife Model",
    Values = features.skinchanger:GetKnifeModels(),
    Default = features.skinchanger:GetKnifeModel(),
    Callback = safeUi("Knife Model", function(value)
        features.skinchanger:SetKnifeModel(value)
        if knifeSkinDropdown then
            local knifeModel = features.skinchanger:GetKnifeModel()
            knifeSkinDropdown:SetValues(features.skinchanger:GetSkinOptions(knifeModel))
            knifeSkinDropdown:SetValue(features.skinchanger:GetWeaponSkin(knifeModel))
        end
    end),
})

local knifeSkinDropdown = skinsLeft:AddDropdown("Knife Skin", {
    Text = "Knife Skin",
    Values = features.skinchanger:GetSkinOptions(features.skinchanger:GetKnifeModel()),
    Default = features.skinchanger:GetWeaponSkin(features.skinchanger:GetKnifeModel()),
    Callback = safeUi("Knife Skin", function(value)
        features.skinchanger:SetWeaponSkin(features.skinchanger:GetKnifeModel(), value)
    end),
})

local function refreshKnifeSkinDropdown()
    local knifeModel = features.skinchanger:GetKnifeModel()
    knifeSkinDropdown:SetValues(features.skinchanger:GetSkinOptions(knifeModel))
    knifeSkinDropdown:SetValue(features.skinchanger:GetWeaponSkin(knifeModel))
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

skinsLeft:AddToggle("Glove Changer Enabled", {
    Text = "Glove Changer Enabled",
    Default = false,
    Callback = safeUi("Glove Changer Enabled", function(value)
        features.skinchanger:SetGloveChangerEnabled(value)
    end),
})

local gloveModels = features.skinchanger:GetGloveModels()
local selectedGloveModel = features.skinchanger:GetGloveModel() or gloveModels[1] or "Default"

local gloveModelDropdown = skinsLeft:AddDropdown("Glove Model", {
    Text = "Glove Model",
    Values = gloveModels,
    Default = selectedGloveModel,
    Callback = safeUi("Glove Model", function(value)
        features.skinchanger:SetGloveModel(value)
        local skinOptions = features.skinchanger:GetGloveSkinOptions(value)
        if gloveSkinDropdown then
            gloveSkinDropdown:SetValues(skinOptions)
            gloveSkinDropdown:SetValue(features.skinchanger:GetGloveSkin(value))
        end
    end),
})

local gloveSkinDropdown = skinsLeft:AddDropdown("Glove Skin", {
    Text = "Glove Skin",
    Values = features.skinchanger:GetGloveSkinOptions(selectedGloveModel),
    Default = features.skinchanger:GetGloveSkin(selectedGloveModel),
    Callback = safeUi("Glove Skin", function(value)
        features.skinchanger:SetGloveSkin(value)
    end),
})

skinsLeft:AddSlider("Skin Inventory Refresh Rate", {
    Text = "Skin Inventory Refresh Rate",
    Default = 2,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = safeUi("Skin Inventory Refresh Rate", function(value)
        features.skinchanger:SetInventoryRefreshRate(value)
    end),
})

skinsLeft:AddButton("Apply Skin Changes", function()
    features.skinchanger:ApplyNow()
    refreshKnifeSkinDropdown()
end)

for _, weaponName in ipairs(features.skinchanger:GetWeaponNames()) do
    if not features.skinchanger:IsKnifeModel(weaponName) then
        skinsRight:AddDropdown("Skin - " .. weaponName, {
            Text = "Skin - " .. weaponName,
            Values = features.skinchanger:GetSkinOptions(weaponName),
            Default = features.skinchanger:GetWeaponSkin(weaponName),
            Callback = safeUi("Skin - " .. weaponName, function(value)
                features.skinchanger:SetWeaponSkin(weaponName, value)
            end),
        })
    end
end

visualsTab:Show()

local visualsLeft = visualsTab:AddLeftGroupbox("Visuals")

visualsLeft:AddToggle("ESP Enabled", {
    Text = "ESP Enabled",
    Default = false,
    Callback = safeUi("ESP Enabled", function(value)
        features.esp:SetSetting("enabled", value)
    end),
})

visualsLeft:AddToggle("ESP Team Check", {
    Text = "ESP Team Check",
    Default = false,
    Callback = safeUi("ESP Team Check", function(value)
        features.esp:SetSetting("teamCheck", value)
    end),
})

visualsLeft:AddToggle("ESP Show Box", {
    Text = "ESP Show Box",
    Default = false,
    Callback = safeUi("ESP Show Box", function(value)
        features.esp:SetSetting("showBox", value)
    end),
})

visualsLeft:AddToggle("ESP Show Health", {
    Text = "ESP Show Health",
    Default = false,
    Callback = safeUi("ESP Show Health", function(value)
        features.esp:SetSetting("showHealth", value)
    end),
})

visualsLeft:AddToggle("ESP Show Name", {
    Text = "ESP Show Name",
    Default = false,
    Callback = safeUi("ESP Show Name", function(value)
        features.esp:SetSetting("showName", value)
    end),
})

visualsLeft:AddToggle("ESP Show Distance", {
    Text = "ESP Show Distance",
    Default = false,
    Callback = safeUi("ESP Show Distance", function(value)
        features.esp:SetSetting("showDistance", value)
    end),
})

visualsLeft:AddToggle("ESP Show Skeleton", {
    Text = "ESP Show Skeleton",
    Default = false,
    Callback = safeUi("ESP Show Skeleton", function(value)
        features.esp:SetSetting("showSkeleton", value)
    end),
})

visualsLeft:AddToggle("ESP Show Head Dot", {
    Text = "ESP Show Head Dot",
    Default = false,
    Callback = safeUi("ESP Show Head Dot", function(value)
        features.esp:SetSetting("showHeadDot", value)
    end),
})

visualsLeft:AddToggle("ESP Show Tracers", {
    Text = "ESP Show Tracers",
    Default = false,
    Callback = safeUi("ESP Show Tracers", function(value)
        features.esp:SetSetting("showTracers", value)
    end),
})

visualsLeft:AddToggle("ESP Rainbow", {
    Text = "ESP Rainbow",
    Default = false,
    Callback = safeUi("ESP Rainbow", function(value)
        features.esp:SetSetting("rainbow", value)
    end),
})

visualsLeft:AddSlider("ESP Rainbow Speed", {
    Text = "ESP Rainbow Speed",
    Default = 2,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
    Callback = safeUi("ESP Rainbow Speed", function(value)
        features.esp:SetSetting("rainbowSpeed", value)
    end),
})

visualsLeft:AddSlider("ESP Text Size", {
    Text = "ESP Text Size",
    Default = 15,
    Min = 10,
    Max = 20,
    Rounding = 0,
    Callback = safeUi("ESP Text Size", function(value)
        features.esp:SetSetting("textSize", value)
    end),
})

visualsLeft:AddSlider("ESP Box Thickness", {
    Text = "ESP Box Thickness",
    Default = 1.5,
    Min = 1,
    Max = 3,
    Rounding = 1,
    Callback = safeUi("ESP Box Thickness", function(value)
        features.esp:SetSetting("boxThickness", value)
    end),
})

visualsLeft:AddSlider("ESP Max Distance", {
    Text = "ESP Max Distance",
    Default = 0,
    Min = 0,
    Max = 500,
    Rounding = 0,
    Callback = safeUi("ESP Max Distance", function(value)
        features.esp:SetSetting("maxDistance", value)
    end),
})

local visualsRight = visualsTab:AddRightGroupbox("Colors")

visualsRight:AddColorPicker("ESP Box Color", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = safeUi("ESP Box Color", function(value)
        features.esp:SetSetting("boxColor", value)
    end),
})

visualsRight:AddColorPicker("ESP Text Color", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = safeUi("ESP Text Color", function(value)
        features.esp:SetSetting("textColor", value)
    end),
})

visualsRight:AddColorPicker("ESP Skeleton Color", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = safeUi("ESP Skeleton Color", function(value)
        features.esp:SetSetting("skeletonColor", value)
    end),
})

visualsRight:AddColorPicker("ESP Tracer Color", {
    Default = Color3.fromRGB(255, 51, 153),
    Callback = safeUi("ESP Tracer Color", function(value)
        features.esp:SetSetting("tracerColor", value)
    end),
})

visualsRight:AddColorPicker("ESP Head Dot Color", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = safeUi("ESP Head Dot Color", function(value)
        features.esp:SetSetting("headDotColor", value)
    end),
})

visualsLeft:AddToggle("Chams Rainbow", {
    Text = "Chams Rainbow",
    Default = false,
    Callback = safeUi("Chams Rainbow", function(value)
        features.chams:SetSetting("rainbow", value)
    end),
})

visualsLeft:AddSlider("Chams Rainbow Speed", {
    Text = "Chams Rainbow Speed",
    Default = 2,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
    Callback = safeUi("Chams Rainbow Speed", function(value)
        features.chams:SetSetting("rainbowSpeed", value)
    end),
})

visualsLeft:AddToggle("Player Chams Enabled", {
    Text = "Player Chams Enabled",
    Default = false,
    Callback = safeUi("Player Chams Enabled", function(value)
        features.chams:SetSetting("playerEnabled", value)
    end),
})

visualsLeft:AddToggle("Player Chams Team Check", {
    Text = "Player Chams Team Check",
    Default = false,
    Callback = safeUi("Player Chams Team Check", function(value)
        features.chams:SetSetting("playerTeamCheck", value)
    end),
})

visualsLeft:AddToggle("Visible Only", {
    Text = "Player Chams Visible Only",
    Default = false,
    Callback = safeUi("Player Chams Visible Only", function(value)
        features.chams:SetSetting("playerVisibleOnly", value)
    end),
})

visualsLeft:AddSlider("Player Chams Fill", {
    Text = "Player Chams Fill",
    Default = 0.7,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = safeUi("Player Chams Fill", function(value)
        features.chams:SetSetting("playerFillTransparency", value)
    end),
})

visualsLeft:AddSlider("Player Chams Outline", {
    Text = "Player Chams Outline",
    Default = 0,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = safeUi("Player Chams Outline", function(value)
        features.chams:SetSetting("playerOutlineTransparency", value)
    end),
})

visualsRight:AddColorPicker("Player Chams Color", {
    Default = Color3.fromRGB(255, 0, 0),
    Callback = safeUi("Player Chams Color", function(value)
        features.chams:SetSetting("playerColor", value)
    end),
})

visualsLeft:AddToggle("Weapon Chams Enabled", {
    Text = "Weapon Chams Enabled",
    Default = false,
    Callback = safeUi("Weapon Chams Enabled", function(value)
        features.chams:SetSetting("weaponEnabled", value)
    end),
})

visualsLeft:AddSlider("Weapon Chams Fill", {
    Text = "Weapon Chams Fill",
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = safeUi("Weapon Chams Fill", function(value)
        features.chams:SetSetting("weaponFillTransparency", value)
    end),
})

visualsLeft:AddSlider("Weapon Chams Outline", {
    Text = "Weapon Chams Outline",
    Default = 0,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = safeUi("Weapon Chams Outline", function(value)
        features.chams:SetSetting("weaponOutlineTransparency", value)
    end),
})

visualsRight:AddColorPicker("Weapon Chams Color", {
    Default = Color3.fromRGB(0, 255, 255),
    Callback = safeUi("Weapon Chams Color", function(value)
        features.chams:SetSetting("weaponColor", value)
    end),
})

visualsLeft:AddToggle("Kill Effects Enabled", {
    Text = "Kill Effects Enabled",
    Default = false,
    Callback = safeUi("Kill Effects Enabled", function(value)
        features.killEffects:SetSetting("enabled", value)
    end),
})

visualsLeft:AddSlider("Kill Effect Duration", {
    Text = "Kill Effect Duration",
    Default = 0.8,
    Min = 0.3,
    Max = 2,
    Rounding = 1,
    Callback = safeUi("Kill Effect Duration", function(value)
        features.killEffects:SetSetting("duration", value)
    end),
})

visualsLeft:AddSlider("Kill Effect Intensity", {
    Text = "Kill Effect Intensity",
    Default = 0.6,
    Min = 0.2,
    Max = 1,
    Rounding = 1,
    Callback = safeUi("Kill Effect Intensity", function(value)
        features.killEffects:SetSetting("intensity", value)
    end),
})

visualsRight:AddColorPicker("Kill Effect Color", {
    Default = Color3.fromRGB(255, 0, 100),
    Callback = safeUi("Kill Effect Color", function(value)
        features.killEffects:SetSetting("color", value)
    end),
})

visualsLeft:AddToggle("Anti Flash", {
    Text = "Anti Flash",
    Default = false,
    Callback = safeUi("Anti Flash", function(value)
        features.worldEffects:SetSetting("antiFlash", value)
    end),
})

visualsLeft:AddToggle("Anti Smoke", {
    Text = "Anti Smoke",
    Default = false,
    Callback = safeUi("Anti Smoke", function(value)
        features.worldEffects:SetSetting("antiSmoke", value)
    end),
})

configTab:Show()

task.defer(function()
    local okList, configNames = pcall(function()
        return SaveManager:RefreshConfigList()
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
                payload = SaveManager:Load(configName)
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
            SaveManager:Load(selectedConfig)
        end)
    end
end)

Library:Notify({
    Title = "Bloxtrike",
    Description = "loaded.",
    Time = 3,
})

Library:OnUnload(errorHandler:Wrap("Window Close", function()
    appCleaner:Cleanup()
end))

if getgenv then
    getgenv().BloxtrikeCleanup = function()
        appCleaner:Cleanup()
        Library:Unload()
    end
end

return {
    window = Window,
    features = features,
}
