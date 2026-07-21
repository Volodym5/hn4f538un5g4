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
    -- [unchanged from original]
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

    if not chunk and loadfile then
        local path = joinPath(ROOT, relativePath)
        chunk, err = loadfile(path)
    end

    if not chunk and readfile and loadstring then
        local path = joinPath(ROOT, relativePath)
        local ok, contents = pcall(readfile, path)
        if ok and contents then
            chunk, err = loadstring(contents, "@" .. path)
        end
    end

    assert(chunk, err or ("Failed to load module: " .. tostring(relativePath)))

    local result = chunk()
    moduleCache[cacheKey] = result
    return result
end

-- ── Load existing modules (unchanged) ──────────────────────────────────
local Cleaner = loadLocal("src/shared/Cleaner.lua")
local Services = loadLocal("src/shared/Services.lua")
local ErrorHandler = loadLocal("src/shared/ErrorHandler.lua")
local GlobalsFactory = loadLocal("src/shared/Globals.lua")
-- NOTE: "ui_lib.lua" is REMOVED — we use the new library now

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

-- ── UI LIBRARY SETUP ───────────────────────────────────────────────────
-- Loaded via the bootstrapper (no inline loadstring)
local Library = loadLocal("ui_lib/source.lua")
local SaveManager = Library.SaveManager

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()

local Window = Library:CreateWindow({
    Title         = "Bloxtrike",
    Footer        = "bloxtrike",
    Size          = UDim2.fromOffset(760, 560),
    Center        = true,
    AutoShow      = true,
    ToggleKeybind = Enum.KeyCode.RightShift,
    SettingsTab   = true,
    ConfigFolder  = "Bloxtrike",
})

-- ── Hook cleanup into library unload ───────────────────────────────────
local function fullCleanup()
    appCleaner:Cleanup()
    if getgenv then
        getgenv().BloxtrikeCleanup = nil
    end
end

local origUnload = Library.Unload
function Library:Unload(...)
    fullCleanup()
    return origUnload(self, ...)
end

if getgenv then
    getgenv().BloxtrikeCleanup = function()
        fullCleanup()
        if Window and Window.Parent then
            Window:Destroy()
        end
    end
end

-- ── Safe UI callback wrapper ───────────────────────────────────────────
local function safeUi(label, fn)
    return errorHandler:Wrap("UI - " .. label, fn)
end

-- ═══════════════════════════════════════════════════════════════════════
--  TABS & GROUPBOXES
-- ═══════════════════════════════════════════════════════════════════════

local combatTab  = Window:AddTab("Combat",  "sword")
local skinsTab   = Window:AddTab("Skins",   "shirt")
local visualsTab = Window:AddTab("Visuals", "eye")

-- Combat tab — Left column
local aimbotGrp    = combatTab:AddLeftGroupbox("Aimbot")
local triggerGrp   = combatTab:AddLeftGroupbox("TriggerBot")
local hitboxGrp    = combatTab:AddLeftGroupbox("Hitbox")
local movemtGrp    = combatTab:AddLeftGroupbox("Movement")

-- Combat tab — Right column
local rageGrp      = combatTab:AddRightGroupbox("Rage / Aimlock")
local silentGrp    = combatTab:AddRightGroupbox("Silent Aim")
local targetGrp    = combatTab:AddRightGroupbox("Targeting")
local weaponGrp    = combatTab:AddRightGroupbox("Weapon Mods")

-- Skins tab — full-width left only
local skinChangerGrp = skinsTab:AddLeftGroupbox("Skin Changer")
local weaponSkinGrp  = skinsTab:AddLeftGroupbox("Weapon Skins")

-- Visuals tab — Left column
local espGrp        = visualsTab:AddLeftGroupbox("ESP")
-- Visuals tab — Right column
local chamsGrp      = visualsTab:AddRightGroupbox("Chams")
local killFxGrp     = visualsTab:AddRightGroupbox("Kill Effects")
local worldFxGrp    = visualsTab:AddRightGroupbox("World Effects")

-- ═══════════════════════════════════════════════════════════════════════
--  TOGGLE / SLIDER / DROPDOWN HELPERS (keep IDs consistent)
-- ═══════════════════════════════════════════════════════════════════════

-- ── Aimbot ────────────────────────────────────────────────────────────
aimbotGrp:AddToggle("aimbot_enabled", {
    Text = "Aimbot Enabled", Default = false,
    Callback = safeUi("Aimbot Enabled", function(v) features.aimbot:SetEnabled(v) end),
})
aimbotGrp:AddToggle("aimbot_teamcheck", {
    Text = "Aimbot Team Check", Default = false,
    Callback = safeUi("Aimbot Team Check", function(v) features.aimbot:SetTeamCheck(v) end),
})
aimbotGrp:AddToggle("aimbot_wallcheck", {
    Text = "Aimbot Wall Check", Default = false,
    Callback = safeUi("Aimbot Wall Check", function(v) features.aimbot:SetWallCheck(v) end),
})
aimbotGrp:AddToggle("aimbot_showfov", {
    Text = "Aimbot Show FOV", Default = false,
    Callback = safeUi("Aimbot Show FOV", function(v) features.aimbot:SetShowFov(v) end),
})
aimbotGrp:AddSlider("aimbot_fovradius", {
    Text = "Aimbot FOV Radius", Default = 100, Min = 10, Max = 500, Rounding = 0,
    Callback = safeUi("Aimbot FOV Radius", function(v) features.aimbot:SetFovRadius(v) end),
})
aimbotGrp:AddSlider("aimbot_smoothing", {
    Text = "Aimbot Smoothing", Default = 3, Min = 1, Max = 10, Rounding = 0,
    Callback = safeUi("Aimbot Smoothing", function(v) features.aimbot:SetSmoothing(v) end),
})

-- ── TriggerBot ────────────────────────────────────────────────────────
triggerGrp:AddToggle("triggerbot_enabled", {
    Text = "TriggerBot Enabled", Default = false,
    Callback = safeUi("TriggerBot Enabled", function(v) features.triggerBot:SetEnabled(v) end),
})
triggerGrp:AddSlider("triggerbot_delay", {
    Text = "TriggerBot Delay MS", Default = 0, Min = 0, Max = 500, Rounding = 0, Suffix = "ms",
    Callback = safeUi("TriggerBot Delay MS", function(v) features.triggerBot:SetDelayMs(v) end),
})

-- ── Hitbox ────────────────────────────────────────────────────────────
hitboxGrp:AddToggle("hitbox_enabled", {
    Text = "Hitbox Enabled", Default = false,
    Callback = safeUi("Hitbox Enabled", function(v) features.hitbox:SetEnabled(v) end),
})
hitboxGrp:AddToggle("hitbox_teamcheck", {
    Text = "Hitbox Team Check", Default = false,
    Callback = safeUi("Hitbox Team Check", function(v) features.hitbox:SetTeamCheck(v) end),
})
hitboxGrp:AddSlider("hitbox_size", {
    Text = "Hitbox Size", Default = 3, Min = 1, Max = 3, Rounding = 1,
    Callback = safeUi("Hitbox Size", function(v) features.hitbox:SetSize(v) end),
})
hitboxGrp:AddSlider("hitbox_transparency", {
    Text = "Hitbox Transparency", Default = 0.5, Min = 0, Max = 1, Rounding = 2,
    Callback = safeUi("Hitbox Transparency", function(v) features.hitbox:SetTransparency(v) end),
})

-- ── Rage / Aimlock ────────────────────────────────────────────────────
rageGrp:AddToggle("rage_enabled", {
    Text = "Rage Mode", Default = false,
    Callback = safeUi("Rage Mode", function(v) features.rage:SetRageMode(v) end),
})
--[[ Rage toggle key (commented in original)
rageGrp:AddLabel("Rage Toggle Key"):AddKeyPicker("rage_togglekey", {
    Default = "Unknown", Mode = "Always", Text = "Rage Toggle Key",
    Callback = function(v) features.rage:SetRageToggleKey(v) end,
})
]]
rageGrp:AddToggle("aimlock_enabled", {
    Text = "Aimlock", Default = false,
    Callback = safeUi("Aimlock", function(v) features.rage:SetAimlock(v) end),
})
--[[ Aimlock keybinds (commented in original)
rageGrp:AddLabel("Aimlock Toggle Key"):AddKeyPicker("aimlock_togglekey", { ... })
rageGrp:AddLabel("Aimlock Hold Key"):AddKeyPicker("aimlock_holdkey", { ... })
]]
rageGrp:AddDropdown("aimlock_method", {
    Text = "Aimlock Method", Default = "Raw Mouse", Values = { "Raw Mouse" },
    Callback = safeUi("Aimlock Method", function(v) features.rage:SetAimlockMethod(v) end),
})
rageGrp:AddSlider("aimlock_fov", {
    Text = "Aimlock Fov Size", Default = 150, Min = 10, Max = 1000, Rounding = 0,
    Callback = safeUi("Aimlock Fov Size", function(v) features.rage:SetAimlockFov(v) end),
})
rageGrp:AddSlider("aimlock_smoothness", {
    Text = "Aim Smoothness", Default = 2, Min = 1, Max = 10, Rounding = 0,
    Callback = safeUi("Aim Smoothness", function(v) features.rage:SetAimSmoothness(v) end),
})
rageGrp:AddSlider("aimlock_jitter", {
    Text = "Aim Jitter (Randomize)", Default = 10, Min = 0, Max = 50, Rounding = 0,
    Callback = safeUi("Aim Jitter (Randomize)", function(v) features.rage:SetAimJitter(v) end),
})
rageGrp:AddToggle("flickbot_enabled", {
    Text = "FlickBOT", Default = false,
    Callback = safeUi("FlickBOT", function(v) features.rage:SetFlickBot(v) end),
})

-- ── Silent Aim ────────────────────────────────────────────────────────
silentGrp:AddToggle("silentaim_enabled", {
    Text = "Silent Aim", Default = false,
    Callback = safeUi("Silent Aim", function(v) features.rage:SetSilentAim(v) end),
})
silentGrp:AddToggle("silentaim_wallbang", {
    Text = "Ignore Walls / Wallbang", Default = false,
    Callback = safeUi("Ignore Walls / Wallbang", function(v) features.rage:SetWallbang(v) end),
})
--[[ Wallbang / Silent Aim toggle keys (commented in original)
silentGrp:AddLabel("Wallbang Toggle Key"):AddKeyPicker("wallbang_togglekey", { ... })
silentGrp:AddLabel("Silent Aim Toggle Key"):AddKeyPicker("silentaim_togglekey", { ... })
]]
silentGrp:AddToggle("silentaim_dynamicmiss", {
    Text = "Dynamic Miss (Hit Chance)", Default = false,
    Callback = safeUi("Dynamic Miss (Hit Chance)", function(v) features.rage:SetDynamicMiss(v) end),
})
silentGrp:AddSlider("silentaim_hitchance", {
    Text = "Hit Chance %", Default = 100, Min = 1, Max = 100, Rounding = 0, Suffix = "%",
    Callback = safeUi("Hit Chance %", function(v) features.rage:SetBaseHitChance(v) end),
})
silentGrp:AddToggle("silentaim_showcircle", {
    Text = "Show Circle", Default = false,
    Callback = safeUi("Show Circle", function(v) features.rage:SetShowFovCircle(v) end),
})
silentGrp:AddSlider("silentaim_fovsize", {
    Text = "Fov Size", Default = 150, Min = 50, Max = 1000, Rounding = 0,
    Callback = safeUi("Fov Size", function(v) features.rage:SetFovSize(v) end),
})

-- ── Targeting ─────────────────────────────────────────────────────────
targetGrp:AddDropdown("rage_targetpart", {
    Text = "TargetPart",
    Default = features.rage:GetTargetPart(),
    Values  = features.rage:GetTargetParts(),
    Callback = safeUi("TargetPart", function(v) features.rage:SetTargetPart(v) end),
})
targetGrp:AddToggle("rage_randompart", {
    Text = "Random Part", Default = false,
    Callback = safeUi("Random Part", function(v) features.rage:SetRandomPart(v) end),
})
targetGrp:AddToggle("rage_360fov", {
    Text = "360 FOV (All Directions)", Default = false,
    Callback = safeUi("360 FOV (All Directions)", function(v) features.rage:SetFullFov360(v) end),
})
targetGrp:AddToggle("rage_aimwallcheck", {
    Text = "AimWall Check", Default = true,
    Callback = safeUi("AimWall Check", function(v) features.rage:SetAimWallCheck(v) end),
})
targetGrp:AddToggle("rage_teamcheck", {
    Text = "TeamCheck", Default = true,
    Callback = safeUi("TeamCheck", function(v) features.rage:SetTeamCheck(v) end),
})

-- ── Weapon Mods ───────────────────────────────────────────────────────
--[[ Rapid Fire (commented in original)
weaponGrp:AddToggle("rapidfire_enabled", { Text = "Rapid Fire", Default = false, Callback = ... })
weaponGrp:AddSlider("rapidfire_tick", { ... })
]]
weaponGrp:AddToggle("weapon_norecoil", {
    Text = "Memory No Recoil", Default = false,
    Callback = safeUi("Memory No Recoil", function(v) features.rage:SetMemoryNoRecoil(v) end),
})
weaponGrp:AddToggle("weapon_nospread", {
    Text = "No Spread", Default = false,
    Callback = safeUi("No Spread", function(v) features.rage:SetNoSpread(v) end),
})
weaponGrp:AddToggle("weapon_autoclicker", {
    Text = "Auto Clicker (Hold LMB)", Default = false,
    Callback = safeUi("Auto Clicker (Hold LMB)", function(v) features.rage:SetAutoClicker(v) end),
})
weaponGrp:AddSlider("weapon_autoclickdelay", {
    Text = "Auto Click Delay (ms)", Default = 50, Min = 10, Max = 500, Rounding = 0, Suffix = "ms",
    Callback = safeUi("Auto Click Delay (ms)", function(v) features.rage:SetAutoClickDelay(v) end),
})
weaponGrp:AddToggle("weapon_instantreload", {
    Text = "Instant Reload", Default = false,
    Callback = safeUi("Instant Reload", function(v) features.rage:SetInstantReload(v) end),
})
weaponGrp:AddToggle("weapon_instaequip", {
    Text = "Insta Equip", Default = false,
    Callback = safeUi("Insta Equip", function(v) features.rage:SetInstaEquip(v) end),
})
weaponGrp:AddToggle("weapon_rcs", {
    Text = "RCS", Default = false,
    Callback = safeUi("RCS", function(v) features.rage:SetRcs(v) end),
})
weaponGrp:AddSlider("weapon_rcsstrength", {
    Text = "RCS Strength", Default = 50, Min = 0, Max = 100, Rounding = 0, Suffix = "%",
    Callback = safeUi("RCS Strength", function(v) features.rage:SetRcsStrength(v) end),
})
weaponGrp:AddSlider("weapon_rcsdelay", {
    Text = "RCS Delay", Default = 0, Min = 0, Max = 500, Rounding = 0, Suffix = "ms",
    Callback = safeUi("RCS Delay", function(v) features.rage:SetRcsDelay(v) end),
})

-- ── Movement ──────────────────────────────────────────────────────────
movemtGrp:AddToggle("bunnyhop_enabled", {
    Text = "Bunny Hop Enabled", Default = false,
    Callback = safeUi("Bunny Hop Enabled", function(v) features.bunnyHop:SetEnabled(v) end),
})
movemtGrp:AddToggle("movespeed_enabled", {
    Text = "Movement Speed Enabled", Default = false,
    Callback = safeUi("Movement Speed Enabled", function(v) features.movementSpeed:SetEnabled(v) end),
})
movemtGrp:AddSlider("movespeed_value", {
    Text = "Movement Speed (st/s)", Default = 15, Min = 5, Max = 32, Rounding = 0,
    Callback = safeUi("Movement Speed (st/s)", function(v) features.movementSpeed:SetSpeedValue(v) end),
})

-- ═══════════════════════════════════════════════════════════════════════
--  SKINS TAB
-- ═══════════════════════════════════════════════════════════════════════

skinChangerGrp:AddToggle("skinchanger_enabled", {
    Text = "Weapon Skin Changer Enabled", Default = false,
    Callback = safeUi("Weapon Skin Changer Enabled", function(v) features.skinchanger:SetSkinChangerEnabled(v) end),
})
skinChangerGrp:AddToggle("knifechanger_enabled", {
    Text = "Knife Changer Enabled", Default = false,
    Callback = safeUi("Knife Changer Enabled", function(v) features.skinchanger:SetKnifeChangerEnabled(v) end),
})

-- Knife Model dropdown
local knifeModels = features.skinchanger:GetKnifeModels()
skinChangerGrp:AddDropdown("skinchanger_knifemodel", {
    Text = "Knife Model", Default = features.skinchanger:GetKnifeModel(), Values = knifeModels,
    Callback = safeUi("Knife Model", function(value)
        features.skinchanger:SetKnifeModel(value)
        local optId = "skinchanger_knifeskin"
        if Library.Options[optId] then
            local newOptions = features.skinchanger:GetSkinOptions(value)
            Library.Options[optId]:SetValues(newOptions)
            Library.Options[optId]:SetValue(features.skinchanger:GetWeaponSkin(value))
        end
    end),
})

-- Knife Skin dropdown
skinChangerGrp:AddDropdown("skinchanger_knifeskin", {
    Text = "Knife Skin",
    Default = features.skinchanger:GetWeaponSkin(features.skinchanger:GetKnifeModel()),
    Values  = features.skinchanger:GetSkinOptions(features.skinchanger:GetKnifeModel()),
    Callback = safeUi("Knife Skin", function(value)
        features.skinchanger:SetWeaponSkin(features.skinchanger:GetKnifeModel(), value)
    end),
})

-- Helper to refresh knife skin dropdown
local function refreshKnifeSkinDropdown()
    local knifeModel = features.skinchanger:GetKnifeModel()
    local optId = "skinchanger_knifeskin"
    if Library.Options[optId] then
        Library.Options[optId]:SetValues(features.skinchanger:GetSkinOptions(knifeModel))
        Library.Options[optId]:SetValue(features.skinchanger:GetWeaponSkin(knifeModel))
    end
end

-- Queue skinchanger sync after config loads
local function queueSkinchangerConfigSync()
    task.spawn(function()
        task.wait(0.05)
        pcall(refreshKnifeSkinDropdown)
        pcall(function() features.skinchanger:ApplyNow() end)
        task.wait(0.35)
        pcall(function() features.skinchanger:ApplyNow() end)
        task.wait(0.8)
        pcall(function() features.skinchanger:ApplyNow() end)
    end)
end

-- Sync displayed knife model → skin
Library.Options["skinchanger_knifemodel"]:SetValue(features.skinchanger:GetKnifeModel())
refreshKnifeSkinDropdown()

-- Glove Changer
skinChangerGrp:AddToggle("glovechanger_enabled", {
    Text = "Glove Changer Enabled", Default = false,
    Callback = safeUi("Glove Changer Enabled", function(v) features.skinchanger:SetGloveChangerEnabled(v) end),
})

local gloveModels = features.skinchanger:GetGloveModels()
local selectedGloveModel = features.skinchanger:GetGloveModel() or gloveModels[1] or "Default"

skinChangerGrp:AddDropdown("skinchanger_glovemodel", {
    Text = "Glove Model", Default = selectedGloveModel, Values = gloveModels,
    Callback = safeUi("Glove Model", function(value)
        features.skinchanger:SetGloveModel(value)
        local optId = "skinchanger_gloveskin"
        if Library.Options[optId] then
            local skinOptions = features.skinchanger:GetGloveSkinOptions(value)
            Library.Options[optId]:SetValues(skinOptions)
            Library.Options[optId]:SetValue(features.skinchanger:GetGloveSkin(value))
        end
    end),
})

skinChangerGrp:AddDropdown("skinchanger_gloveskin", {
    Text = "Glove Skin",
    Default = features.skinchanger:GetGloveSkin(selectedGloveModel),
    Values  = features.skinchanger:GetGloveSkinOptions(selectedGloveModel),
    Callback = safeUi("Glove Skin", function(value) features.skinchanger:SetGloveSkin(value) end),
})

skinChangerGrp:AddSlider("skinchanger_refreshrate", {
    Text = "Skin Inventory Refresh Rate", Default = 2, Min = 1, Max = 10, Rounding = 0,
    Callback = safeUi("Skin Inventory Refresh Rate", function(v) features.skinchanger:SetInventoryRefreshRate(v) end),
})

skinChangerGrp:AddButton({
    Text = "Apply Skin Changes",
    Func = safeUi("Apply Skin Changes", function()
        features.skinchanger:ApplyNow()
        refreshKnifeSkinDropdown()
    end),
})

-- ── Weapon Skins (per-weapon dropdowns) ────────────────────────────────
for _, weaponName in ipairs(features.skinchanger:GetWeaponNames()) do
    if not features.skinchanger:IsKnifeModel(weaponName) then
        weaponSkinGrp:AddDropdown("skin_" .. weaponName, {
            Text = "Skin - " .. weaponName,
            Default = features.skinchanger:GetWeaponSkin(weaponName),
            Values  = features.skinchanger:GetSkinOptions(weaponName),
            Callback = safeUi("Skin - " .. weaponName, function(value)
                features.skinchanger:SetWeaponSkin(weaponName, value)
            end),
        })
    end
end

-- ═══════════════════════════════════════════════════════════════════════
--  VISUALS TAB
-- ═══════════════════════════════════════════════════════════════════════

-- ── ESP ───────────────────────────────────────────────────────────────
espGrp:AddToggle("esp_enabled", {
    Text = "ESP Enabled", Default = false,
    Callback = safeUi("ESP Enabled", function(v) features.esp:SetSetting("enabled", v) end),
})
espGrp:AddToggle("esp_teamcheck", {
    Text = "ESP Team Check", Default = false,
    Callback = safeUi("ESP Team Check", function(v) features.esp:SetSetting("teamCheck", v) end),
})
espGrp:AddToggle("esp_showbox", {
    Text = "ESP Show Box", Default = false,
    Callback = safeUi("ESP Show Box", function(v) features.esp:SetSetting("showBox", v) end),
})
espGrp:AddToggle("esp_showhealth", {
    Text = "ESP Show Health", Default = false,
    Callback = safeUi("ESP Show Health", function(v) features.esp:SetSetting("showHealth", v) end),
})
espGrp:AddToggle("esp_showname", {
    Text = "ESP Show Name", Default = false,
    Callback = safeUi("ESP Show Name", function(v) features.esp:SetSetting("showName", v) end),
})
espGrp:AddToggle("esp_showdistance", {
    Text = "ESP Show Distance", Default = false,
    Callback = safeUi("ESP Show Distance", function(v) features.esp:SetSetting("showDistance", v) end),
})
espGrp:AddToggle("esp_showskeleton", {
    Text = "ESP Show Skeleton", Default = false,
    Callback = safeUi("ESP Show Skeleton", function(v) features.esp:SetSetting("showSkeleton", v) end),
})
espGrp:AddToggle("esp_showheaddot", {
    Text = "ESP Show Head Dot", Default = false,
    Callback = safeUi("ESP Show Head Dot", function(v) features.esp:SetSetting("showHeadDot", v) end),
})
espGrp:AddToggle("esp_showtracers", {
    Text = "ESP Show Tracers", Default = false,
    Callback = safeUi("ESP Show Tracers", function(v) features.esp:SetSetting("showTracers", v) end),
})
espGrp:AddToggle("esp_rainbow", {
    Text = "ESP Rainbow", Default = false,
    Callback = safeUi("ESP Rainbow", function(v) features.esp:SetSetting("rainbow", v) end),
})
espGrp:AddSlider("esp_rainbowspeed", {
    Text = "ESP Rainbow Speed", Default = 2, Min = 0.1, Max = 10, Rounding = 1,
    Callback = safeUi("ESP Rainbow Speed", function(v) features.esp:SetSetting("rainbowSpeed", v) end),
})
espGrp:AddSlider("esp_textsize", {
    Text = "ESP Text Size", Default = 15, Min = 10, Max = 20, Rounding = 0,
    Callback = safeUi("ESP Text Size", function(v) features.esp:SetSetting("textSize", v) end),
})
espGrp:AddSlider("esp_boxthickness", {
    Text = "ESP Box Thickness", Default = 1.5, Min = 1, Max = 3, Rounding = 1,
    Callback = safeUi("ESP Box Thickness", function(v) features.esp:SetSetting("boxThickness", v) end),
})
espGrp:AddSlider("esp_maxdistance", {
    Text = "ESP Max Distance", Default = 0, Min = 0, Max = 500, Rounding = 0,
    Callback = safeUi("ESP Max Distance", function(v) features.esp:SetSetting("maxDistance", v) end),
})

espGrp:AddLabel("ESP Box Color"):AddColorPicker("esp_boxcolor", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = safeUi("ESP Box Color", function(v) features.esp:SetSetting("boxColor", v) end),
})
espGrp:AddLabel("ESP Text Color"):AddColorPicker("esp_textcolor", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = safeUi("ESP Text Color", function(v) features.esp:SetSetting("textColor", v) end),
})
espGrp:AddLabel("ESP Skeleton Color"):AddColorPicker("esp_skeletoncolor", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = safeUi("ESP Skeleton Color", function(v) features.esp:SetSetting("skeletonColor", v) end),
})
espGrp:AddLabel("ESP Tracer Color"):AddColorPicker("esp_tracercolor", {
    Default = Color3.fromRGB(255, 51, 153),
    Callback = safeUi("ESP Tracer Color", function(v) features.esp:SetSetting("tracerColor", v) end),
})
espGrp:AddLabel("ESP Head Dot Color"):AddColorPicker("esp_headdotcolor", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = safeUi("ESP Head Dot Color", function(v) features.esp:SetSetting("headDotColor", v) end),
})

-- ── Chams ──────────────────────────────────────────────────────────────
chamsGrp:AddToggle("chams_rainbow", {
    Text = "Chams Rainbow", Default = false,
    Callback = safeUi("Chams Rainbow", function(v) features.chams:SetSetting("rainbow", v) end),
})
chamsGrp:AddSlider("chams_rainbowspeed", {
    Text = "Chams Rainbow Speed", Default = 2, Min = 0.1, Max = 10, Rounding = 1,
    Callback = safeUi("Chams Rainbow Speed", function(v) features.chams:SetSetting("rainbowSpeed", v) end),
})
chamsGrp:AddToggle("chams_player_enabled", {
    Text = "Player Chams Enabled", Default = false,
    Callback = safeUi("Player Chams Enabled", function(v) features.chams:SetSetting("playerEnabled", v) end),
})
chamsGrp:AddToggle("chams_player_teamcheck", {
    Text = "Player Chams Team Check", Default = false,
    Callback = safeUi("Player Chams Team Check", function(v) features.chams:SetSetting("playerTeamCheck", v) end),
})
chamsGrp:AddToggle("chams_player_visibleonly", {
    Text = "Visible Only", Default = false,
    Callback = safeUi("Player Chams Visible Only", function(v) features.chams:SetSetting("playerVisibleOnly", v) end),
})
chamsGrp:AddSlider("chams_player_fill", {
    Text = "Player Chams Fill", Default = 0.7, Min = 0, Max = 1, Rounding = 2,
    Callback = safeUi("Player Chams Fill", function(v) features.chams:SetSetting("playerFillTransparency", v) end),
})
chamsGrp:AddSlider("chams_player_outline", {
    Text = "Player Chams Outline", Default = 0, Min = 0, Max = 1, Rounding = 2,
    Callback = safeUi("Player Chams Outline", function(v) features.chams:SetSetting("playerOutlineTransparency", v) end),
})
chamsGrp:AddLabel("Player Chams Color"):AddColorPicker("chams_player_color", {
    Default = Color3.fromRGB(255, 0, 0),
    Callback = safeUi("Player Chams Color", function(v) features.chams:SetSetting("playerColor", v) end),
})
chamsGrp:AddToggle("chams_weapon_enabled", {
    Text = "Weapon Chams Enabled", Default = false,
    Callback = safeUi("Weapon Chams Enabled", function(v) features.chams:SetSetting("weaponEnabled", v) end),
})
chamsGrp:AddSlider("chams_weapon_fill", {
    Text = "Weapon Chams Fill", Default = 0.5, Min = 0, Max = 1, Rounding = 2,
    Callback = safeUi("Weapon Chams Fill", function(v) features.chams:SetSetting("weaponFillTransparency", v) end),
})
chamsGrp:AddSlider("chams_weapon_outline", {
    Text = "Weapon Chams Outline", Default = 0, Min = 0, Max = 1, Rounding = 2,
    Callback = safeUi("Weapon Chams Outline", function(v) features.chams:SetSetting("weaponOutlineTransparency", v) end),
})
chamsGrp:AddLabel("Weapon Chams Color"):AddColorPicker("chams_weapon_color", {
    Default = Color3.fromRGB(0, 255, 255),
    Callback = safeUi("Weapon Chams Color", function(v) features.chams:SetSetting("weaponColor", v) end),
})

--[[ Bullet Tracers (commented in original)
local bulletGrp = visualsTab:AddRightGroupbox("Bullet Tracers")
...
]]

--[[ Particle Effects (commented in original)
local particleGrp = visualsTab:AddRightGroupbox("Particle Effects")
...
]]

-- ── Kill Effects ──────────────────────────────────────────────────────
killFxGrp:AddToggle("killfx_enabled", {
    Text = "Kill Effects Enabled", Default = false,
    Callback = safeUi("Kill Effects Enabled", function(v) features.killEffects:SetSetting("enabled", v) end),
})
killFxGrp:AddSlider("killfx_duration", {
    Text = "Kill Effect Duration", Default = 0.8, Min = 0.3, Max = 2, Rounding = 1,
    Callback = safeUi("Kill Effect Duration", function(v) features.killEffects:SetSetting("duration", v) end),
})
killFxGrp:AddSlider("killfx_intensity", {
    Text = "Kill Effect Intensity", Default = 0.6, Min = 0.2, Max = 1, Rounding = 1,
    Callback = safeUi("Kill Effect Intensity", function(v) features.killEffects:SetSetting("intensity", v) end),
})
killFxGrp:AddLabel("Kill Effect Color"):AddColorPicker("killfx_color", {
    Default = Color3.fromRGB(255, 0, 100),
    Callback = safeUi("Kill Effect Color", function(v) features.killEffects:SetSetting("color", v) end),
})

-- ── World Effects ─────────────────────────────────────────────────────
worldFxGrp:AddToggle("worldfx_antiflash", {
    Text = "Anti Flash", Default = false,
    Callback = safeUi("Anti Flash", function(v) features.worldEffects:SetSetting("antiFlash", v) end),
})
worldFxGrp:AddToggle("worldfx_antismoke", {
    Text = "Anti Smoke", Default = false,
    Callback = safeUi("Anti Smoke", function(v) features.worldEffects:SetSetting("antiSmoke", v) end),
})

-- ═══════════════════════════════════════════════════════════════════════
--  CONFIG LOAD HOOK (sync skinchanger after loading a config)
-- ═══════════════════════════════════════════════════════════════════════

-- The library's SaveManager fires OnChanged for each option when a config
-- is loaded. We hook into that indirectly by piggybacking on the skin
-- dropdowns. But for a guaranteed sync after config load, we patch
-- SaveManager.LoadConfig.

if SaveManager.LoadConfig then
    local origLoadConfig = SaveManager.LoadConfig
    function SaveManager:LoadConfig(name, ...)
        local result = { origLoadConfig(self, name, ...) }
        task.spawn(function()
            task.wait(0.1)
            pcall(queueSkinchangerConfigSync)
        end)
        return table.unpack(result)
    end
end

-- ═══════════════════════════════════════════════════════════════════════
--  AUTOLOAD CONFIG (pinned via middle-click in Configs dropdown)
-- ═══════════════════════════════════════════════════════════════════════

task.defer(function()
    task.wait(0.3)
    pcall(function()
        SaveManager:LoadAutoloadConfig()
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════
--  NOTIFICATION
-- ═══════════════════════════════════════════════════════════════════════

Library:Notify("Bloxtrike loaded.", 3)

-- ═══════════════════════════════════════════════════════════════════════
--  RETURN (identical shape to original)
-- ═══════════════════════════════════════════════════════════════════════

return {
    window = Window,
    features = features,
}
