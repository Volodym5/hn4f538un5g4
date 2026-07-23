-- ============================================================
-- MODULE LOADER
-- ============================================================
local BaseURL = "https://raw.githubusercontent.com/Volodym5/hn4f538un5g4/main/"

local function loadModule(path)
    return loadstring(game:HttpGet(BaseURL .. path))()
end

local Cleaner       = loadModule("src/shared/Cleaner.lua")
local Services      = loadModule("src/shared/Services.lua")
local ErrorHandler  = loadModule("src/shared/ErrorHandler.lua")
local GlobalsFactory= loadModule("src/shared/Globals.lua")

-- ============================================================
-- UI LIBRARY SETUP
-- ============================================================
loadstring(game:HttpGet("https://raw.githubusercontent.com/Volodym5/pfasdzxc231/main/lib/source.lua"))()
local Library     = getgenv().Library
local SaveManager = Library.SaveManager

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()

-- ============================================================
-- COMBAT MODULES — now loaded from the combined Aimbot.lua
-- ============================================================
local CombatModules  = loadModule("src/features/combat/Aimbot.lua")
local Aimbot         = CombatModules.Aimbot
local Hitbox         = CombatModules.Hitbox
local TriggerBot     = CombatModules.TriggerBot
local RapidFireSystem = CombatModules.RapidFireSystem  -- available if you uncomment below

local Rage           = loadModule("src/features/combat/Rage.lua")

-- ============================================================
-- MOVEMENT MODULES — now loaded from the combined Movement.lua
-- ============================================================
local MovementMods   = loadModule("src/features/movement/Movement.lua")
local BunnyHop       = MovementMods.BunnyHop
local MovementSpeed  = MovementMods.MovementSpeed

local ESP            = loadModule("src/features/visuals/ESP.lua")
local Chams          = loadModule("src/features/visuals/Chams.lua")
--local BulletTracers   = loadModule("src/features/visuals/BulletTracers.lua")
--local ParticleEffects = loadModule("src/features/visuals/ParticleEffects.lua")
local KillEffects    = loadModule("src/features/visuals/KillEffects.lua")
local WorldEffects   = loadModule("src/features/visuals/WorldEffects.lua")
local Skinchanger    = loadModule("src/features/skins/Skinchanger.lua")

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
    aimbot       = Aimbot.new(context),
    triggerBot   = TriggerBot.new(context),
    hitbox       = Hitbox.new(context),
    rage         = Rage.new(context),
    --rapidFire  = RapidFireSystem.new(context),  -- uncomment if you want to use it
    bunnyHop     = BunnyHop.new(context),
    movementSpeed = MovementSpeed.new(context),
    esp          = ESP.new(context),
    chams        = Chams.new(context),
    --bulletTracers    = BulletTracers.new(context),
    --particleEffects  = ParticleEffects.new(context),
    killEffects      = KillEffects.new(context),
    worldEffects     = WorldEffects.new(context),
    skinchanger      = Skinchanger.new(context),
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

local function safeUi(label, fn)
    return errorHandler:Wrap("UI - " .. label, fn)
end

-- ============================================================
-- HELPER: Replace dropdown options at runtime via SetValues
-- ============================================================
local function setDropdownValues(optionId, newValues, newDefault)
    local opt = Library.Options[optionId]
    if not opt then return end
    pcall(opt.SetValues, opt, newValues)
    pcall(opt.SetValue, opt, newDefault)
end

-- ============================================================
-- WINDOW
-- ============================================================
local Window = Library:CreateWindow({
    Title         = "Bloxtrike",
    Footer        = "bloxtrike.cc",
    Size          = UDim2.fromOffset(760, 560),
    Center        = true,
    AutoShow      = true,
    ToggleKeybind = Enum.KeyCode.RightShift,
    SettingsTab   = true,
    ConfigFolder  = "Bloxtrike",
})

if getgenv then
    getgenv().BloxtrikeCleanup = function()
        appCleaner:Cleanup()
        if Window and Window.ScreenGui and Window.ScreenGui.Parent then
            Window.ScreenGui:Destroy()
        end
    end
end

-- ============================================================
-- TABS
-- ============================================================
local combatTab  = Window:AddTab("Combat",  "sword")
local skinsTab   = Window:AddTab("Skins",   "package")
local visualsTab = Window:AddTab("Visuals", "eye")
local configTab  = Window:AddTab("Config",  "settings")

-- ============================================================
-- COMBAT TAB — LEFT SIDE
-- ============================================================

-- Aimbot
local aimbotBox = combatTab:AddLeftGroupbox("Aimbot")
aimbotBox:AddToggle("aimbot_Enabled", {
    Text = "Aimbot Enabled", Default = false,
    Callback = safeUi("Aimbot Enabled", function(v) features.aimbot:SetEnabled(v) end),
})
aimbotBox:AddToggle("aimbot_TeamCheck", {
    Text = "Aimbot Team Check", Default = false,
    Callback = safeUi("Aimbot Team Check", function(v) features.aimbot:SetTeamCheck(v) end),
})
aimbotBox:AddToggle("aimbot_WallCheck", {
    Text = "Aimbot Wall Check", Default = false,
    Callback = safeUi("Aimbot Wall Check", function(v) features.aimbot:SetWallCheck(v) end),
})
aimbotBox:AddToggle("aimbot_ShowFOV", {
    Text = "Aimbot Show FOV", Default = false,
    Callback = safeUi("Aimbot Show FOV", function(v) features.aimbot:SetShowFov(v) end),
})
aimbotBox:AddSlider("aimbot_FovRadius", {
    Text = "Aimbot FOV Radius", Default = 100, Min = 10, Max = 500, Rounding = 0,
    Suffix = "",
    Callback = safeUi("Aimbot FOV Radius", function(v) features.aimbot:SetFovRadius(v) end),
})
aimbotBox:AddSlider("aimbot_Smoothing", {
    Text = "Aimbot Smoothing", Default = 3, Min = 1, Max = 10, Rounding = 0,
    Callback = safeUi("Aimbot Smoothing", function(v) features.aimbot:SetSmoothing(v) end),
})

--[[
-- TriggerBot
local triggerBox = combatTab:AddLeftGroupbox("TriggerBot")
triggerBox:AddToggle("triggerbot_Enabled", {
    Text = "TriggerBot Enabled", Default = false,
    Callback = safeUi("TriggerBot Enabled", function(v) features.triggerBot:SetEnabled(v) end),
})
triggerBox:AddSlider("triggerbot_Delay", {
    Text = "TriggerBot Delay MS", Default = 0, Min = 0, Max = 500, Rounding = 0,
    Callback = safeUi("TriggerBot Delay MS", function(v) features.triggerBot:SetDelayMs(v) end),
})

-- Aimlock
local aimlockBox = combatTab:AddLeftGroupbox("Aimlock")
aimlockBox:AddToggle("aimlock_Enabled", {
    Text = "Aimlock", Default = false,
    Callback = safeUi("Aimlock", function(v) features.rage:SetAimlock(v) end),
})
aimlockBox:AddDropdown("aimlock_Method", {
    Text = "Aimlock Method", Default = "Raw Mouse", Values = { "Raw Mouse" },
    Callback = safeUi("Aimlock Method", function(v) features.rage:SetAimlockMethod(v) end),
})
aimlockBox:AddSlider("aimlock_FovSize", {
    Text = "Aimlock Fov Size", Default = 150, Min = 10, Max = 1000, Rounding = 0,
    Callback = safeUi("Aimlock Fov Size", function(v) features.rage:SetAimlockFov(v) end),
})
aimlockBox:AddSlider("aimlock_Smoothness", {
    Text = "Aim Smoothness", Default = 2, Min = 1, Max = 10, Rounding = 0,
    Callback = safeUi("Aim Smoothness", function(v) features.rage:SetAimSmoothness(v) end),
})
aimlockBox:AddSlider("aimlock_Jitter", {
    Text = "Aim Jitter (Randomize)", Default = 10, Min = 0, Max = 50, Rounding = 0,
    Callback = safeUi("Aim Jitter (Randomize)", function(v) features.rage:SetAimJitter(v) end),
})
aimlockBox:AddToggle("aimlock_Flickbot", {
    Text = "FlickBOT", Default = false,
    Callback = safeUi("FlickBOT", function(v) features.rage:SetFlickBot(v) end),
})
]]

-- Silent Aim
local silentBox = combatTab:AddLeftGroupbox("Silent Aim")
silentBox:AddToggle("silent_Enabled", {
    Text = "Silent Aim", Default = false,
    Callback = safeUi("Silent Aim", function(v) features.rage:SetSilentAim(v) end),
})
silentBox:AddToggle("silent_Wallbang", {
    Text = "Ignore Walls / Wallbang", Default = false,
    Callback = safeUi("Ignore Walls / Wallbang", function(v) features.rage:SetWallbang(v) end),
})
silentBox:AddToggle("silent_DynamicMiss", {
    Text = "Dynamic Miss (Hit Chance)", Default = false,
    Callback = safeUi("Dynamic Miss (Hit Chance)", function(v) features.rage:SetDynamicMiss(v) end),
})
silentBox:AddSlider("silent_HitChance", {
    Text = "Hit Chance %", Default = 100, Min = 1, Max = 100, Rounding = 0,
    Callback = safeUi("Hit Chance %", function(v) features.rage:SetBaseHitChance(v) end),
})
silentBox:AddToggle("silent_ShowCircle", {
    Text = "Show Circle", Default = false,
    Callback = safeUi("Show Circle", function(v) features.rage:SetShowFovCircle(v) end),
})
silentBox:AddSlider("silent_FovSize", {
    Text = "Fov Size", Default = 150, Min = 50, Max = 1000, Rounding = 0,
    Callback = safeUi("Fov Size", function(v) features.rage:SetFovSize(v) end),
})

-- Movement
local movementBox = combatTab:AddLeftGroupbox("Movement")
movementBox:AddToggle("movement_BunnyHop", {
    Text = "Bunny Hop Enabled", Default = false,
    Callback = safeUi("Bunny Hop Enabled", function(v) features.bunnyHop:SetEnabled(v) end),
})
movementBox:AddToggle("movement_SpeedEnabled", {
    Text = "Movement Speed Enabled", Default = false,
    Callback = safeUi("Movement Speed Enabled", function(v) features.movementSpeed:SetEnabled(v) end),
})
movementBox:AddSlider("movement_SpeedValue", {
    Text = "Movement Speed (st/s)", Default = 15, Min = 5, Max = 32, Rounding = 0,
    Callback = safeUi("Movement Speed (st/s)", function(v) features.movementSpeed:SetSpeedValue(v) end),
})

-- ============================================================
-- COMBAT TAB — RIGHT SIDE
-- ============================================================

-- Hitbox
local hitboxBox = combatTab:AddRightGroupbox("Hitbox")
hitboxBox:AddToggle("hitbox_Enabled", {
    Text = "Hitbox Enabled", Default = false,
    Callback = safeUi("Hitbox Enabled", function(v) features.hitbox:SetEnabled(v) end),
})
hitboxBox:AddToggle("hitbox_TeamCheck", {
    Text = "Hitbox Team Check", Default = false,
    Callback = safeUi("Hitbox Team Check", function(v) features.hitbox:SetTeamCheck(v) end),
})
hitboxBox:AddSlider("hitbox_Size", {
    Text = "Hitbox Size", Default = 3, Min = 1, Max = 3, Rounding = 1,
    Callback = safeUi("Hitbox Size", function(v) features.hitbox:SetSize(v) end),
})
hitboxBox:AddSlider("hitbox_Transparency", {
    Text = "Hitbox Transparency", Default = 0.5, Min = 0, Max = 1, Rounding = 2,
    Callback = safeUi("Hitbox Transparency", function(v) features.hitbox:SetTransparency(v) end),
})

--[[
-- Rage
local rageBox = combatTab:AddRightGroupbox("Rage")
rageBox:AddToggle("rage_Mode", {
    Text = "Rage Mode", Default = false,
    Callback = safeUi("Rage Mode", function(v) features.rage:SetRageMode(v) end),
})
]]

-- Targeting
local targetingBox = combatTab:AddRightGroupbox("Targeting")
targetingBox:AddDropdown("targeting_Part", {
    Text = "TargetPart",
    Default = features.rage:GetTargetPart(),
    Values  = features.rage:GetTargetParts(),
    Callback = safeUi("TargetPart", function(v) features.rage:SetTargetPart(v) end),
})
targetingBox:AddToggle("targeting_RandomPart", {
    Text = "Random Part", Default = false,
    Callback = safeUi("Random Part", function(v) features.rage:SetRandomPart(v) end),
})
targetingBox:AddToggle("targeting_360Fov", {
    Text = "360 FOV (All Directions)", Default = false,
    Callback = safeUi("360 FOV (All Directions)", function(v) features.rage:SetFullFov360(v) end),
})
targetingBox:AddToggle("targeting_AimWallCheck", {
    Text = "AimWall Check", Default = true,
    Callback = safeUi("AimWall Check", function(v) features.rage:SetAimWallCheck(v) end),
})
targetingBox:AddToggle("targeting_TeamCheck", {
    Text = "TeamCheck", Default = true,
    Callback = safeUi("TeamCheck", function(v) features.rage:SetTeamCheck(v) end),
})

--[[
-- Weapon Mods
local weaponBox = combatTab:AddRightGroupbox("Weapon Mods")
weaponBox:AddToggle("weapon_NoRecoil", {
    Text = "Memory No Recoil", Default = false,
    Callback = safeUi("Memory No Recoil", function(v) features.rage:SetMemoryNoRecoil(v) end),
})
]]
weaponBox:AddToggle("weapon_NoSpread", {
    Text = "No Spread", Default = false,
    Callback = safeUi("No Spread", function(v) features.rage:SetNoSpread(v) end),
})
--[[
weaponBox:AddToggle("weapon_AutoClicker", {
    Text = "Auto Clicker (Hold LMB)", Default = false,
    Callback = safeUi("Auto Clicker (Hold LMB)", function(v) features.rage:SetAutoClicker(v) end),
})
weaponBox:AddSlider("weapon_AutoClickDelay", {
    Text = "Auto Click Delay (ms)", Default = 50, Min = 10, Max = 500, Rounding = 0,
    Callback = safeUi("Auto Click Delay (ms)", function(v) features.rage:SetAutoClickDelay(v) end),
})
weaponBox:AddToggle("weapon_InstantReload", {
    Text = "Instant Reload", Default = false,
    Callback = safeUi("Instant Reload", function(v) features.rage:SetInstantReload(v) end),
})

weaponBox:AddToggle("weapon_InstaEquip", {
    Text = "Insta Equip", Default = false,
    Callback = safeUi("Insta Equip", function(v) features.rage:SetInstaEquip(v) end),
})
weaponBox:AddToggle("weapon_RCS", {
    Text = "RCS", Default = false,
    Callback = safeUi("RCS", function(v) features.rage:SetRcs(v) end),
})
weaponBox:AddSlider("weapon_RCS_Strength", {
    Text = "RCS Strength", Default = 50, Min = 0, Max = 100, Rounding = 0,
    Callback = safeUi("RCS Strength", function(v) features.rage:SetRcsStrength(v) end),
})
weaponBox:AddSlider("weapon_RCS_Delay", {
    Text = "RCS Delay", Default = 0, Min = 0, Max = 500, Rounding = 0,
    Callback = safeUi("RCS Delay", function(v) features.rage:SetRcsDelay(v) end),
})
]]

-- ============================================================
-- SKINS TAB
-- ============================================================
local skinBox = skinsTab:AddLeftGroupbox("Skin Changer")
skinBox:AddToggle("skinchanger_Enabled", {
    Text = "Weapon Skin Changer Enabled", Default = false,
    Callback = safeUi("Weapon Skin Changer Enabled", function(v) features.skinchanger:SetSkinChangerEnabled(v) end),
})
skinBox:AddToggle("skinchanger_KnifeEnabled", {
    Text = "Knife Changer Enabled", Default = false,
    Callback = safeUi("Knife Changer Enabled", function(v) features.skinchanger:SetKnifeChangerEnabled(v) end),
})

-- Knife Model dropdown — when it changes, swap the Knife Skin dropdown options
local knifeModelDefault = features.skinchanger:GetKnifeModel()
skinBox:AddDropdown("skinchanger_KnifeModel", {
    Text = "Knife Model",
    Default = knifeModelDefault,
    Values  = features.skinchanger:GetKnifeModels(),
    Callback = safeUi("Knife Model", function(value)
        features.skinchanger:SetKnifeModel(value)
        local newOptions = features.skinchanger:GetSkinOptions(value)
        local newDefault = features.skinchanger:GetWeaponSkin(value)
        setDropdownValues("skinchanger_KnifeSkin", newOptions, newDefault)
    end),
})

-- Knife Skin dropdown — starts with options for the default knife model
skinBox:AddDropdown("skinchanger_KnifeSkin", {
    Text = "Knife Skin",
    Default = features.skinchanger:GetWeaponSkin(knifeModelDefault),
    Values  = features.skinchanger:GetSkinOptions(knifeModelDefault),
    Callback = safeUi("Knife Skin", function(value)
        features.skinchanger:SetWeaponSkin(features.skinchanger:GetKnifeModel(), value)
    end),
})

skinBox:AddToggle("skinchanger_GloveEnabled", {
    Text = "Glove Changer Enabled", Default = false,
    Callback = safeUi("Glove Changer Enabled", function(v) features.skinchanger:SetGloveChangerEnabled(v) end),
})

-- Glove Model dropdown — cascades into Glove Skin
local gloveModels = features.skinchanger:GetGloveModels()
local defaultGloveModel = features.skinchanger:GetGloveModel() or gloveModels[1] or "Default"

skinBox:AddDropdown("skinchanger_GloveModel", {
    Text = "Glove Model",
    Default = defaultGloveModel,
    Values  = gloveModels,
    Callback = safeUi("Glove Model", function(value)
        features.skinchanger:SetGloveModel(value)
        local newOptions = features.skinchanger:GetGloveSkinOptions(value)
        local newDefault = features.skinchanger:GetGloveSkin(value)
        setDropdownValues("skinchanger_GloveSkin", newOptions, newDefault)
    end),
})

skinBox:AddDropdown("skinchanger_GloveSkin", {
    Text = "Glove Skin",
    Default = features.skinchanger:GetGloveSkin(defaultGloveModel),
    Values  = features.skinchanger:GetGloveSkinOptions(defaultGloveModel),
    Callback = safeUi("Glove Skin", function(value)
        features.skinchanger:SetGloveSkin(value)
    end),
})

skinBox:AddSlider("skinchanger_RefreshRate", {
    Text = "Skin Inventory Refresh Rate", Default = 2, Min = 1, Max = 10, Rounding = 0,
    Callback = safeUi("Skin Inventory Refresh Rate", function(v) features.skinchanger:SetInventoryRefreshRate(v) end),
})

skinBox:AddButton({
    Text = "Apply Skin Changes",
    Func = safeUi("Apply Skin Changes", function()
        features.skinchanger:ApplyNow()
        -- Refresh knife skin dropdown after apply (skins may update)
        local km = features.skinchanger:GetKnifeModel()
        local refreshed = features.skinchanger:GetSkinOptions(km)
        setDropdownValues("skinchanger_KnifeSkin", refreshed, features.skinchanger:GetWeaponSkin(km))
    end),
})

-- Weapon Skins (right side)
local weaponSkinsBox = skinsTab:AddRightGroupbox("Weapon Skins")
for _, weaponName in ipairs(features.skinchanger:GetWeaponNames()) do
    if not features.skinchanger:IsKnifeModel(weaponName) then
        local id = "wpnskin_" .. weaponName:gsub("[^%w_]", "_")
        weaponSkinsBox:AddDropdown(id, {
            Text = "Skin - " .. weaponName,
            Default = features.skinchanger:GetWeaponSkin(weaponName),
            Values  = features.skinchanger:GetSkinOptions(weaponName),
            Callback = safeUi("Skin - " .. weaponName, function(value)
                features.skinchanger:SetWeaponSkin(weaponName, value)
            end),
        })
    end
end

-- ============================================================
-- VISUALS TAB — LEFT SIDE
-- ============================================================

-- ESP
local espBox = visualsTab:AddLeftGroupbox("ESP")

local function espSetting(key)
    return function(v) features.esp:SetSetting(key, v) end
end

espBox:AddToggle("esp_Enabled",    { Text = "ESP Enabled",      Default = false, Callback = safeUi("ESP Enabled",    espSetting("enabled")) })
espBox:AddToggle("esp_TeamCheck",  { Text = "ESP Team Check",   Default = false, Callback = safeUi("ESP Team Check",  espSetting("teamCheck")) })
espBox:AddToggle("esp_ShowBox",    { Text = "ESP Show Box",     Default = false, Callback = safeUi("ESP Show Box",    espSetting("showBox")) })
espBox:AddToggle("esp_ShowHealth", { Text = "ESP Show Health",  Default = false, Callback = safeUi("ESP Show Health", espSetting("showHealth")) })
espBox:AddToggle("esp_ShowName",   { Text = "ESP Show Name",    Default = false, Callback = safeUi("ESP Show Name",   espSetting("showName")) })
espBox:AddToggle("esp_ShowDist",   { Text = "ESP Show Distance",Default = false, Callback = safeUi("ESP Show Distance",espSetting("showDistance")) })
espBox:AddToggle("esp_ShowSkel",   { Text = "ESP Show Skeleton",Default = false, Callback = safeUi("ESP Show Skeleton",espSetting("showSkeleton")) })
espBox:AddToggle("esp_HeadDot",    { Text = "ESP Show Head Dot",Default = false, Callback = safeUi("ESP Show Head Dot",espSetting("showHeadDot")) })
espBox:AddToggle("esp_Tracers",    { Text = "ESP Show Tracers", Default = false, Callback = safeUi("ESP Show Tracers",espSetting("showTracers")) })
espBox:AddToggle("esp_Rainbow",    { Text = "ESP Rainbow",      Default = false, Callback = safeUi("ESP Rainbow",    espSetting("rainbow")) })

espBox:AddSlider("esp_RainbowSpeed", {
    Text = "ESP Rainbow Speed", Default = 2, Min = 0.1, Max = 10, Rounding = 1,
    Callback = safeUi("ESP Rainbow Speed", espSetting("rainbowSpeed")),
})
espBox:AddSlider("esp_TextSize", {
    Text = "ESP Text Size", Default = 15, Min = 10, Max = 20, Rounding = 0,
    Callback = safeUi("ESP Text Size", espSetting("textSize")),
})
espBox:AddSlider("esp_BoxThickness", {
    Text = "ESP Box Thickness", Default = 1.5, Min = 1, Max = 3, Rounding = 1,
    Callback = safeUi("ESP Box Thickness", espSetting("boxThickness")),
})
espBox:AddSlider("esp_MaxDist", {
    Text = "ESP Max Distance", Default = 0, Min = 0, Max = 500, Rounding = 0,
    Callback = safeUi("ESP Max Distance", espSetting("maxDistance")),
})

-- ESP Color Pickers
espBox:AddLabel("ESP Box Color"):AddColorPicker("esp_BoxColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(v) features.esp:SetSetting("boxColor", v) end,
})
espBox:AddLabel("ESP Text Color"):AddColorPicker("esp_TextColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(v) features.esp:SetSetting("textColor", v) end,
})
espBox:AddLabel("ESP Skeleton Color"):AddColorPicker("esp_SkeletonColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(v) features.esp:SetSetting("skeletonColor", v) end,
})
espBox:AddLabel("ESP Tracer Color"):AddColorPicker("esp_TracerColor", {
    Default = Color3.fromRGB(255, 51, 153),
    Callback = function(v) features.esp:SetSetting("tracerColor", v) end,
})
espBox:AddLabel("ESP Head Dot Color"):AddColorPicker("esp_HeadDotColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(v) features.esp:SetSetting("headDotColor", v) end,
})

-- ============================================================
-- VISUALS TAB — RIGHT SIDE
-- ============================================================

-- Chams
local chamsBox = visualsTab:AddRightGroupbox("Chams")

local function chamsSetting(key)
    return function(v) features.chams:SetSetting(key, v) end
end

chamsBox:AddToggle("chams_Rainbow", {
    Text = "Chams Rainbow", Default = false,
    Callback = safeUi("Chams Rainbow", chamsSetting("rainbow")),
})
chamsBox:AddSlider("chams_RainbowSpeed", {
    Text = "Chams Rainbow Speed", Default = 2, Min = 0.1, Max = 10, Rounding = 1,
    Callback = safeUi("Chams Rainbow Speed", chamsSetting("rainbowSpeed")),
})
chamsBox:AddToggle("chams_PlayerEnabled", {
    Text = "Player Chams Enabled", Default = false,
    Callback = safeUi("Player Chams Enabled", chamsSetting("playerEnabled")),
})
chamsBox:AddToggle("chams_PlayerTeamCheck", {
    Text = "Player Chams Team Check", Default = false,
    Callback = safeUi("Player Chams Team Check", chamsSetting("playerTeamCheck")),
})
chamsBox:AddToggle("chams_VisibleOnly", {
    Text = "Visible Only", Default = false,
    Callback = safeUi("Player Chams Visible Only", chamsSetting("playerVisibleOnly")),
})
chamsBox:AddSlider("chams_PlayerFill", {
    Text = "Player Chams Fill", Default = 0.7, Min = 0, Max = 1, Rounding = 2,
    Callback = safeUi("Player Chams Fill", chamsSetting("playerFillTransparency")),
})
chamsBox:AddSlider("chams_PlayerOutline", {
    Text = "Player Chams Outline", Default = 0, Min = 0, Max = 1, Rounding = 2,
    Callback = safeUi("Player Chams Outline", chamsSetting("playerOutlineTransparency")),
})
chamsBox:AddLabel("Player Chams Color"):AddColorPicker("chams_PlayerColor", {
    Default = Color3.fromRGB(255, 0, 0),
    Callback = function(v) features.chams:SetSetting("playerColor", v) end,
})
chamsBox:AddToggle("chams_WeaponEnabled", {
    Text = "Weapon Chams Enabled", Default = false,
    Callback = safeUi("Weapon Chams Enabled", chamsSetting("weaponEnabled")),
})
chamsBox:AddSlider("chams_WeaponFill", {
    Text = "Weapon Chams Fill", Default = 0.5, Min = 0, Max = 1, Rounding = 2,
    Callback = safeUi("Weapon Chams Fill", chamsSetting("weaponFillTransparency")),
})
chamsBox:AddSlider("chams_WeaponOutline", {
    Text = "Weapon Chams Outline", Default = 0, Min = 0, Max = 1, Rounding = 2,
    Callback = safeUi("Weapon Chams Outline", chamsSetting("weaponOutlineTransparency")),
})
chamsBox:AddLabel("Weapon Chams Color"):AddColorPicker("chams_WeaponColor", {
    Default = Color3.fromRGB(0, 255, 255),
    Callback = function(v) features.chams:SetSetting("weaponColor", v) end,
})

-- Kill Effects
local killBox = visualsTab:AddRightGroupbox("Kill Effects")
killBox:AddToggle("killfx_Enabled", {
    Text = "Kill Effects Enabled", Default = false,
    Callback = safeUi("Kill Effects Enabled", function(v) features.killEffects:SetSetting("enabled", v) end),
})
killBox:AddSlider("killfx_Duration", {
    Text = "Kill Effect Duration", Default = 0.8, Min = 0.3, Max = 2, Rounding = 1,
    Callback = safeUi("Kill Effect Duration", function(v) features.killEffects:SetSetting("duration", v) end),
})
killBox:AddSlider("killfx_Intensity", {
    Text = "Kill Effect Intensity", Default = 0.6, Min = 0.2, Max = 1, Rounding = 1,
    Callback = safeUi("Kill Effect Intensity", function(v) features.killEffects:SetSetting("intensity", v) end),
})
killBox:AddLabel("Kill Effect Color"):AddColorPicker("killfx_Color", {
    Default = Color3.fromRGB(255, 0, 100),
    Callback = function(v) features.killEffects:SetSetting("color", v) end,
})

-- World Effects
local worldBox = visualsTab:AddRightGroupbox("World Effects")
worldBox:AddToggle("world_AntiFlash", {
    Text = "Anti Flash", Default = false,
    Callback = safeUi("Anti Flash", function(v) features.worldEffects:SetSetting("antiFlash", v) end),
})
worldBox:AddToggle("world_AntiSmoke", {
    Text = "Anti Smoke", Default = false,
    Callback = safeUi("Anti Smoke", function(v) features.worldEffects:SetSetting("antiSmoke", v) end),
})

-- ============================================================
-- AUTOLOAD LAST CONFIG (optional)
-- ============================================================
task.spawn(function()
    task.wait(1)
    pcall(function()
        SaveManager:LoadAutoloadConfig()
    end)
end)
