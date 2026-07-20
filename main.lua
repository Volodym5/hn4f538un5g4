-- Load the UI library
loadstring(game:HttpGet("https://raw.githubusercontent.com/Volodym5/hn4f538un5g4/main/ui_lib.lua"))()

local baseUrl = "https://raw.githubusercontent.com/Volodym5/hn4f538un5g4/main"

-- Setup HTTP get function (same as original)
local httpGet = (syn and syn.request and function(url)
    local response = syn.request({ Url = url, Method = "GET" })
    return response and response.Body
end) or (http and http.request and function(url)
    local response = http.request({ Url = url, Method = "GET" })
    return response and response.Body
end) or (game and game.HttpGet and function(url)
    return game:HttpGet(url)
end) or error("No HTTP request function is available in this executor.")

-- Function to load modules from GitHub
local function loadModule(relativePath)
    local url = baseUrl .. "/" .. relativePath
    print("Loading: " .. url)
    local source = httpGet(url)
    if not source or source == "" then
        error("Failed to load: " .. url)
    end
    local chunk, err = loadstring(source, "@" .. relativePath)
    if not chunk then
        error("Failed to compile: " .. relativePath .. " - " .. tostring(err))
    end
    return chunk()
end

-- Load all shared modules
local Cleaner = loadModule("src/shared/Cleaner.lua")
local Services = loadModule("src/shared/Services.lua")
local ErrorHandler = loadModule("src/shared/ErrorHandler.lua")
local GlobalsFactory = loadModule("src/shared/Globals.lua")

-- Load all feature modules
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

print("All modules loaded successfully")

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

-- Use the new UI library (loaded from ui_lib.lua)
local Library = getgenv().Library
local SaveManager = Library.SaveManager

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()

local Window = Library:CreateWindow({
    Title = "Bloxtrike",
    Footer = "Bloxtrike v1.0",
    Size = UDim2.fromOffset(760, 560),
    Center = true,
    AutoShow = true,
    ToggleKeybind = Enum.KeyCode.RightShift,
    SettingsTab = true,
    ConfigFolder = "Bloxtrike",
})

if getgenv then
    getgenv().BloxtrikeCleanup = function()
        appCleaner:Cleanup()
        if Window and Window.screenGui and Window.screenGui.Parent then
            Window.screenGui:Destroy()
        end
    end
end

local function safeUi(label, fn)
    return errorHandler:Wrap("UI - " .. label, fn)
end

-- Combat Tab
local CombatTab = Window:AddTab("Combat", "rbxassetid://1234567890")

-- Aimbot Section
local AimbotLeft = CombatTab:AddLeftGroupbox("Aimbot")

AimbotLeft:AddToggle("AimbotEnabled", {
    Text = "Aimbot Enabled",
    Default = false,
    Callback = safeUi("Aimbot Enabled", function(value)
        features.aimbot:SetEnabled(value)
    end),
})

AimbotLeft:AddToggle("AimbotTeamCheck", {
    Text = "Aimbot Team Check",
    Default = false,
    Callback = safeUi("Aimbot Team Check", function(value)
        features.aimbot:SetTeamCheck(value)
    end),
})

AimbotLeft:AddToggle("AimbotWallCheck", {
    Text = "Aimbot Wall Check",
    Default = false,
    Callback = safeUi("Aimbot Wall Check", function(value)
        features.aimbot:SetWallCheck(value)
    end),
})

AimbotLeft:AddToggle("AimbotShowFOV", {
    Text = "Aimbot Show FOV",
    Default = false,
    Callback = safeUi("Aimbot Show FOV", function(value)
        features.aimbot:SetShowFov(value)
    end),
})

AimbotLeft:AddSlider("AimbotFOVRadius", {
    Text = "Aimbot FOV Radius",
    Default = 100,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Suffix = " studs",
    Callback = safeUi("Aimbot FOV Radius", function(value)
        features.aimbot:SetFovRadius(value)
    end),
})

AimbotLeft:AddSlider("AimbotSmoothing", {
    Text = "Aimbot Smoothing",
    Default = 3,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = safeUi("Aimbot Smoothing", function(value)
        features.aimbot:SetSmoothing(value)
    end),
})

-- TriggerBot Section
local TriggerLeft = CombatTab:AddLeftGroupbox("TriggerBot")

TriggerLeft:AddToggle("TriggerBotEnabled", {
    Text = "TriggerBot Enabled",
    Default = false,
    Callback = safeUi("TriggerBot Enabled", function(value)
        features.triggerBot:SetEnabled(value)
    end),
})

TriggerLeft:AddSlider("TriggerBotDelayMS", {
    Text = "TriggerBot Delay MS",
    Default = 0,
    Min = 0,
    Max = 500,
    Rounding = 0,
    Suffix = "ms",
    Callback = safeUi("TriggerBot Delay MS", function(value)
        features.triggerBot:SetDelayMs(value)
    end),
})

-- Hitbox Section
local HitboxLeft = CombatTab:AddLeftGroupbox("Hitbox")

HitboxLeft:AddToggle("HitboxEnabled", {
    Text = "Hitbox Enabled",
    Default = false,
    Callback = safeUi("Hitbox Enabled", function(value)
        features.hitbox:SetEnabled(value)
    end),
})

HitboxLeft:AddToggle("HitboxTeamCheck", {
    Text = "Hitbox Team Check",
    Default = false,
    Callback = safeUi("Hitbox Team Check", function(value)
        features.hitbox:SetTeamCheck(value)
    end),
})

HitboxLeft:AddSlider("HitboxSize", {
    Text = "Hitbox Size",
    Default = 3,
    Min = 1,
    Max = 3,
    Rounding = 1,
    Callback = safeUi("Hitbox Size", function(value)
        features.hitbox:SetSize(value)
    end),
})

HitboxLeft:AddSlider("HitboxTransparency", {
    Text = "Hitbox Transparency",
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = safeUi("Hitbox Transparency", function(value)
        features.hitbox:SetTransparency(value)
    end),
})

-- Rage Section
local RageRight = CombatTab:AddRightGroupbox("Rage")

RageRight:AddToggle("RageMode", {
    Text = "Rage Mode",
    Default = false,
    Callback = safeUi("Rage Mode", function(value)
        features.rage:SetRageMode(value)
    end),
})
--[[
RageRight:AddKeyPicker("RageToggleKey", {
    Default = Enum.KeyCode.Unknown,
    Mode = "Toggle",
    Text = "Rage Toggle Key",
    Callback = safeUi("Rage Toggle Key", function(value)
        features.rage:SetRageToggleKey(value)
    end),
})
]]
-- Aimlock Section
local AimlockLeft = CombatTab:AddLeftGroupbox("Aimlock")

AimlockLeft:AddToggle("Aimlock", {
    Text = "Aimlock",
    Default = false,
    Callback = safeUi("Aimlock", function(value)
        features.rage:SetAimlock(value)
    end),
})
--[[
AimlockLeft:AddKeyPicker("AimlockToggleKey", {
    Default = Enum.KeyCode.Unknown,
    Mode = "Toggle",
    Text = "Aimlock Toggle Key",
    Callback = safeUi("Aimlock Toggle Key", function(value)
        features.rage:SetAimlockToggleKey(value)
    end),
})

AimlockLeft:AddKeyPicker("AimlockHoldKey", {
    Default = Enum.UserInputType.MouseButton2,
    Mode = "Hold",
    Text = "Aimlock HoldKey",
    Callback = safeUi("Aimlock HoldKey", function(value)
        features.rage:SetAimlockHoldKey(value)
    end),
})
]]
AimlockLeft:AddDropdown("AimlockMethod", {
    Text = "Aimlock Method",
    Default = "Raw Mouse",
    Values = { "Raw Mouse" },
    Callback = safeUi("Aimlock Method", function(value)
        features.rage:SetAimlockMethod(value)
    end),
})

AimlockLeft:AddSlider("AimlockFovSize", {
    Text = "Aimlock Fov Size",
    Default = 150,
    Min = 10,
    Max = 1000,
    Rounding = 0,
    Suffix = " studs",
    Callback = safeUi("Aimlock Fov Size", function(value)
        features.rage:SetAimlockFov(value)
    end),
})

AimlockLeft:AddSlider("AimSmoothness", {
    Text = "Aim Smoothness",
    Default = 2,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = safeUi("Aim Smoothness", function(value)
        features.rage:SetAimSmoothness(value)
    end),
})

AimlockLeft:AddSlider("AimJitter", {
    Text = "Aim Jitter (Randomize)",
    Default = 10,
    Min = 0,
    Max = 50,
    Rounding = 0,
    Callback = safeUi("Aim Jitter (Randomize)", function(value)
        features.rage:SetAimJitter(value)
    end),
})

AimlockLeft:AddToggle("FlickBOT", {
    Text = "FlickBOT",
    Default = false,
    Callback = safeUi("FlickBOT", function(value)
        features.rage:SetFlickBot(value)
    end),
})

-- Silent Aim Section
local SilentAimLeft = CombatTab:AddLeftGroupbox("Silent Aim")

SilentAimLeft:AddToggle("SilentAim", {
    Text = "Silent Aim",
    Default = false,
    Callback = safeUi("Silent Aim", function(value)
        features.rage:SetSilentAim(value)
    end),
})

SilentAimLeft:AddToggle("IgnoreWalls", {
    Text = "Ignore Walls / Wallbang",
    Default = false,
    Callback = safeUi("Ignore Walls / Wallbang", function(value)
        features.rage:SetWallbang(value)
    end),
})
--[[
SilentAimLeft:AddKeyPicker("WallbangToggleKey", {
    Default = Enum.KeyCode.Unknown,
    Mode = "Toggle",
    Text = "Wallbang Toggle Key",
    Callback = safeUi("Wallbang Toggle Key", function(value)
        features.rage:SetWallbangToggleKey(value)
    end),
})

SilentAimLeft:AddKeyPicker("SilentAimToggleKey", {
    Default = Enum.KeyCode.Unknown,
    Mode = "Toggle",
    Text = "Silent Aim Toggle Key",
    Callback = safeUi("Silent Aim Toggle Key", function(value)
        features.rage:SetSilentAimToggleKey(value)
    end),
})
]]
SilentAimLeft:AddToggle("DynamicMiss", {
    Text = "Dynamic Miss (Hit Chance)",
    Default = false,
    Callback = safeUi("Dynamic Miss (Hit Chance)", function(value)
        features.rage:SetDynamicMiss(value)
    end),
})

SilentAimLeft:AddSlider("HitChance", {
    Text = "Hit Chance %",
    Default = 100,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
    Callback = safeUi("Hit Chance %", function(value)
        features.rage:SetBaseHitChance(value)
    end),
})

SilentAimLeft:AddToggle("ShowCircle", {
    Text = "Show Circle",
    Default = false,
    Callback = safeUi("Show Circle", function(value)
        features.rage:SetShowFovCircle(value)
    end),
})

SilentAimLeft:AddSlider("FovSize", {
    Text = "Fov Size",
    Default = 150,
    Min = 50,
    Max = 1000,
    Rounding = 0,
    Suffix = " studs",
    Callback = safeUi("Fov Size", function(value)
        features.rage:SetFovSize(value)
    end),
})

-- Targeting Section
local TargetingRight = CombatTab:AddRightGroupbox("Targeting")

TargetingRight:AddDropdown("TargetPart", {
    Text = "TargetPart",
    Default = features.rage:GetTargetPart(),
    Values = features.rage:GetTargetParts(),
    Callback = safeUi("TargetPart", function(value)
        features.rage:SetTargetPart(value)
    end),
})

TargetingRight:AddToggle("RandomPart", {
    Text = "Random Part",
    Default = false,
    Callback = safeUi("Random Part", function(value)
        features.rage:SetRandomPart(value)
    end),
})

TargetingRight:AddToggle("FullFov360", {
    Text = "360 FOV (All Directions)",
    Default = false,
    Callback = safeUi("360 FOV (All Directions)", function(value)
        features.rage:SetFullFov360(value)
    end),
})

TargetingRight:AddToggle("AimWallCheck", {
    Text = "AimWall Check",
    Default = true,
    Callback = safeUi("AimWall Check", function(value)
        features.rage:SetAimWallCheck(value)
    end),
})

TargetingRight:AddToggle("TeamCheck", {
    Text = "TeamCheck",
    Default = true,
    Callback = safeUi("TeamCheck", function(value)
        features.rage:SetTeamCheck(value)
    end),
})

-- Weapon Mods Section
local WeaponModsLeft = CombatTab:AddLeftGroupbox("Weapon Mods")
--[[
WeaponModsLeft:AddToggle("RapidFire", {
    Text = "Rapid Fire",
    Default = false,
    Callback = safeUi("Rapid Fire", function(value)
        features.rapidFire:SetEnabled(value)
    end),
})

WeaponModsLeft:AddSlider("RapidFireTick", {
    Text = "Rapid Fire Tick (s)",
    Default = 0.05,
    Min = 0.01,
    Max = 0.2,
    Rounding = 2,
    Suffix = "s",
    Callback = safeUi("Rapid Fire Tick", function(value)
        features.rapidFire:SetTick(value)
    end),
})
]]
WeaponModsLeft:AddToggle("MemoryNoRecoil", {
    Text = "Memory No Recoil",
    Default = false,
    Callback = safeUi("Memory No Recoil", function(value)
        features.rage:SetMemoryNoRecoil(value)
    end),
})

WeaponModsLeft:AddToggle("NoSpread", {
    Text = "No Spread",
    Default = false,
    Callback = safeUi("No Spread", function(value)
        features.rage:SetNoSpread(value)
    end),
})

WeaponModsLeft:AddToggle("AutoClicker", {
    Text = "Auto Clicker (Hold LMB)",
    Default = false,
    Callback = safeUi("Auto Clicker (Hold LMB)", function(value)
        features.rage:SetAutoClicker(value)
    end),
})

WeaponModsLeft:AddSlider("AutoClickDelay", {
    Text = "Auto Click Delay (ms)",
    Default = 50,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Suffix = "ms",
    Callback = safeUi("Auto Click Delay (ms)", function(value)
        features.rage:SetAutoClickDelay(value)
    end),
})

WeaponModsLeft:AddToggle("InstantReload", {
    Text = "Instant Reload",
    Default = false,
    Callback = safeUi("Instant Reload", function(value)
        features.rage:SetInstantReload(value)
    end),
})

WeaponModsLeft:AddToggle("InstaEquip", {
    Text = "Insta Equip",
    Default = false,
    Callback = safeUi("Insta Equip", function(value)
        features.rage:SetInstaEquip(value)
    end),
})

WeaponModsLeft:AddToggle("RCS", {
    Text = "RCS",
    Default = false,
    Callback = safeUi("RCS", function(value)
        features.rage:SetRcs(value)
    end),
})

WeaponModsLeft:AddSlider("RCSStrength", {
    Text = "RCS Strength",
    Default = 50,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
    Callback = safeUi("RCS Strength", function(value)
        features.rage:SetRcsStrength(value)
    end),
})

WeaponModsLeft:AddSlider("RCSDelay", {
    Text = "RCS Delay",
    Default = 0,
    Min = 0,
    Max = 500,
    Rounding = 0,
    Suffix = "ms",
    Callback = safeUi("RCS Delay", function(value)
        features.rage:SetRcsDelay(value)
    end),
})

-- Movement Section
local MovementRight = CombatTab:AddRightGroupbox("Movement")

MovementRight:AddToggle("BunnyHopEnabled", {
    Text = "Bunny Hop Enabled",
    Default = false,
    Callback = safeUi("Bunny Hop Enabled", function(value)
        features.bunnyHop:SetEnabled(value)
    end),
})

MovementRight:AddToggle("MovementSpeedEnabled", {
    Text = "Movement Speed Enabled",
    Default = false,
    Callback = safeUi("Movement Speed Enabled", function(value)
        features.movementSpeed:SetEnabled(value)
    end),
})

MovementRight:AddSlider("MovementSpeedValue", {
    Text = "Movement Speed (st/s)",
    Default = 15,
    Min = 5,
    Max = 32,
    Rounding = 0,
    Suffix = " st/s",
    Callback = safeUi("Movement Speed (st/s)", function(value)
        features.movementSpeed:SetSpeedValue(value)
    end),
})

-- Skins Tab
local SkinsTab = Window:AddTab("Skins", "rbxassetid://1234567890")

-- Skin Changer Section
local SkinChangerLeft = SkinsTab:AddLeftGroupbox("Skin Changer")

SkinChangerLeft:AddToggle("SkinChangerEnabled", {
    Text = "Weapon Skin Changer Enabled",
    Default = false,
    Callback = safeUi("Weapon Skin Changer Enabled", function(value)
        features.skinchanger:SetSkinChangerEnabled(value)
    end),
})

SkinChangerLeft:AddToggle("KnifeChangerEnabled", {
    Text = "Knife Changer Enabled",
    Default = false,
    Callback = safeUi("Knife Changer Enabled", function(value)
        features.skinchanger:SetKnifeChangerEnabled(value)
    end),
})

local knifeModels = features.skinchanger:GetKnifeModels()
SkinChangerLeft:AddDropdown("KnifeModel", {
    Text = "Knife Model",
    Default = features.skinchanger:GetKnifeModel(),
    Values = knifeModels,
    Callback = safeUi("Knife Model", function(value)
        features.skinchanger:SetKnifeModel(value)
        local knifeModel = features.skinchanger:GetKnifeModel()
        Library.Options["KnifeSkin"]:RemoveValues(Library.Options["KnifeSkin"].Values)
        Library.Options["KnifeSkin"]:AddValues(features.skinchanger:GetSkinOptions(knifeModel))
        Library.Options["KnifeSkin"]:SetValue(features.skinchanger:GetWeaponSkin(knifeModel))
    end),
})

SkinChangerLeft:AddDropdown("KnifeSkin", {
    Text = "Knife Skin",
    Default = features.skinchanger:GetWeaponSkin(features.skinchanger:GetKnifeModel()),
    Values = features.skinchanger:GetSkinOptions(features.skinchanger:GetKnifeModel()),
    Callback = safeUi("Knife Skin", function(value)
        features.skinchanger:SetWeaponSkin(features.skinchanger:GetKnifeModel(), value)
    end),
})

local function refreshKnifeSkinDropdown()
    local knifeModel = features.skinchanger:GetKnifeModel()
    Library.Options["KnifeSkin"]:RemoveValues(Library.Options["KnifeSkin"].Values)
    Library.Options["KnifeSkin"]:AddValues(features.skinchanger:GetSkinOptions(knifeModel))
    Library.Options["KnifeSkin"]:SetValue(features.skinchanger:GetWeaponSkin(knifeModel))
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

Library.Options["KnifeModel"]:SetValue(features.skinchanger:GetKnifeModel())
refreshKnifeSkinDropdown()

SkinChangerLeft:AddToggle("GloveChangerEnabled", {
    Text = "Glove Changer Enabled",
    Default = false,
    Callback = safeUi("Glove Changer Enabled", function(value)
        features.skinchanger:SetGloveChangerEnabled(value)
    end),
})

local gloveModels = features.skinchanger:GetGloveModels()
local selectedGloveModel = features.skinchanger:GetGloveModel() or gloveModels[1] or "Default"

SkinChangerLeft:AddDropdown("GloveModel", {
    Text = "Glove Model",
    Default = selectedGloveModel,
    Values = gloveModels,
    Callback = safeUi("Glove Model", function(value)
        features.skinchanger:SetGloveModel(value)
        local skinOptions = features.skinchanger:GetGloveSkinOptions(value)
        if Library.Options["GloveSkin"] then
            Library.Options["GloveSkin"]:RemoveValues(Library.Options["GloveSkin"].Values)
            Library.Options["GloveSkin"]:AddValues(skinOptions)
            Library.Options["GloveSkin"]:SetValue(features.skinchanger:GetGloveSkin(value))
        end
    end),
})

SkinChangerLeft:AddDropdown("GloveSkin", {
    Text = "Glove Skin",
    Default = features.skinchanger:GetGloveSkin(selectedGloveModel),
    Values = features.skinchanger:GetGloveSkinOptions(selectedGloveModel),
    Callback = safeUi("Glove Skin", function(value)
        features.skinchanger:SetGloveSkin(value)
    end),
})

SkinChangerLeft:AddSlider("SkinInventoryRefreshRate", {
    Text = "Skin Inventory Refresh Rate",
    Default = 2,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Suffix = "s",
    Callback = safeUi("Skin Inventory Refresh Rate", function(value)
        features.skinchanger:SetInventoryRefreshRate(value)
    end),
})

SkinChangerLeft:AddButton({
    Text = "Apply Skin Changes",
    Func = safeUi("Apply Skin Changes", function()
        features.skinchanger:ApplyNow()
        refreshKnifeSkinDropdown()
    end),
})

-- Weapon Skins Section
local WeaponSkinsRight = SkinsTab:AddRightGroupbox("Weapon Skins")

for _, weaponName in ipairs(features.skinchanger:GetWeaponNames()) do
    if not features.skinchanger:IsKnifeModel(weaponName) then
        WeaponSkinsRight:AddDropdown("Skin_" .. weaponName:gsub("%s+", "_"), {
            Text = "Skin - " .. weaponName,
            Default = features.skinchanger:GetWeaponSkin(weaponName),
            Values = features.skinchanger:GetSkinOptions(weaponName),
            Callback = safeUi("Skin - " .. weaponName, function(value)
                features.skinchanger:SetWeaponSkin(weaponName, value)
            end),
        })
    end
end

-- Visuals Tab
local VisualsTab = Window:AddTab("Visuals", "rbxassetid://1234567890")

-- ESP Section
local ESPLeft = VisualsTab:AddLeftGroupbox("ESP")

ESPLeft:AddToggle("ESPEnabled", {
    Text = "ESP Enabled",
    Default = false,
    Callback = safeUi("ESP Enabled", function(value)
        features.esp:SetSetting("enabled", value)
    end),
})

ESPLeft:AddToggle("ESPTeamCheck", {
    Text = "ESP Team Check",
    Default = false,
    Callback = safeUi("ESP Team Check", function(value)
        features.esp:SetSetting("teamCheck", value)
    end),
})

ESPLeft:AddToggle("ESPShowBox", {
    Text = "ESP Show Box",
    Default = false,
    Callback = safeUi("ESP Show Box", function(value)
        features.esp:SetSetting("showBox", value)
    end),
})

ESPLeft:AddToggle("ESPShowHealth", {
    Text = "ESP Show Health",
    Default = false,
    Callback = safeUi("ESP Show Health", function(value)
        features.esp:SetSetting("showHealth", value)
    end),
})

ESPLeft:AddToggle("ESPShowName", {
    Text = "ESP Show Name",
    Default = false,
    Callback = safeUi("ESP Show Name", function(value)
        features.esp:SetSetting("showName", value)
    end),
})

ESPLeft:AddToggle("ESPShowDistance", {
    Text = "ESP Show Distance",
    Default = false,
    Callback = safeUi("ESP Show Distance", function(value)
        features.esp:SetSetting("showDistance", value)
    end),
})

ESPLeft:AddToggle("ESPShowSkeleton", {
    Text = "ESP Show Skeleton",
    Default = false,
    Callback = safeUi("ESP Show Skeleton", function(value)
        features.esp:SetSetting("showSkeleton", value)
    end),
})

ESPLeft:AddToggle("ESPShowHeadDot", {
    Text = "ESP Show Head Dot",
    Default = false,
    Callback = safeUi("ESP Show Head Dot", function(value)
        features.esp:SetSetting("showHeadDot", value)
    end),
})

ESPLeft:AddToggle("ESPShowTracers", {
    Text = "ESP Show Tracers",
    Default = false,
    Callback = safeUi("ESP Show Tracers", function(value)
        features.esp:SetSetting("showTracers", value)
    end),
})

ESPLeft:AddToggle("ESPRainbow", {
    Text = "ESP Rainbow",
    Default = false,
    Callback = safeUi("ESP Rainbow", function(value)
        features.esp:SetSetting("rainbow", value)
    end),
})

ESPLeft:AddSlider("ESPRainbowSpeed", {
    Text = "ESP Rainbow Speed",
    Default = 2,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
    Callback = safeUi("ESP Rainbow Speed", function(value)
        features.esp:SetSetting("rainbowSpeed", value)
    end),
})

ESPLeft:AddSlider("ESPTextSize", {
    Text = "ESP Text Size",
    Default = 15,
    Min = 10,
    Max = 20,
    Rounding = 0,
    Callback = safeUi("ESP Text Size", function(value)
        features.esp:SetSetting("textSize", value)
    end),
})

ESPLeft:AddSlider("ESPBoxThickness", {
    Text = "ESP Box Thickness",
    Default = 1.5,
    Min = 1,
    Max = 3,
    Rounding = 1,
    Callback = safeUi("ESP Box Thickness", function(value)
        features.esp:SetSetting("boxThickness", value)
    end),
})

ESPLeft:AddSlider("ESPMaxDistance", {
    Text = "ESP Max Distance",
    Default = 0,
    Min = 0,
    Max = 500,
    Rounding = 0,
    Suffix = " studs",
    Callback = safeUi("ESP Max Distance", function(value)
        features.esp:SetSetting("maxDistance", value)
    end),
})

-- ESP Colors
local ESPColorsRight = VisualsTab:AddRightGroupbox("ESP Colors")

ESPColorsRight:AddLabel("ESP Box Color"):AddColorPicker("ESPBoxColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = safeUi("ESP Box Color", function(value)
        features.esp:SetSetting("boxColor", value)
    end),
})

ESPColorsRight:AddLabel("ESP Text Color"):AddColorPicker("ESPTextColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = safeUi("ESP Text Color", function(value)
        features.esp:SetSetting("textColor", value)
    end),
})

ESPColorsRight:AddLabel("ESP Skeleton Color"):AddColorPicker("ESPSkeletonColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = safeUi("ESP Skeleton Color", function(value)
        features.esp:SetSetting("skeletonColor", value)
    end),
})

ESPColorsRight:AddLabel("ESP Tracer Color"):AddColorPicker("ESPTracerColor", {
    Default = Color3.fromRGB(255, 51, 153),
    Callback = safeUi("ESP Tracer Color", function(value)
        features.esp:SetSetting("tracerColor", value)
    end),
})

ESPColorsRight:AddLabel("ESP Head Dot Color"):AddColorPicker("ESPHeadDotColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = safeUi("ESP Head Dot Color", function(value)
        features.esp:SetSetting("headDotColor", value)
    end),
})

-- Chams Section
local ChamsLeft = VisualsTab:AddLeftGroupbox("Chams")

ChamsLeft:AddToggle("ChamsRainbow", {
    Text = "Chams Rainbow",
    Default = false,
    Callback = safeUi("Chams Rainbow", function(value)
        features.chams:SetSetting("rainbow", value)
    end),
})

ChamsLeft:AddSlider("ChamsRainbowSpeed", {
    Text = "Chams Rainbow Speed",
    Default = 2,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
    Callback = safeUi("Chams Rainbow Speed", function(value)
        features.chams:SetSetting("rainbowSpeed", value)
    end),
})

ChamsLeft:AddToggle("PlayerChamsEnabled", {
    Text = "Player Chams Enabled",
    Default = false,
    Callback = safeUi("Player Chams Enabled", function(value)
        features.chams:SetSetting("playerEnabled", value)
    end),
})

ChamsLeft:AddToggle("PlayerChamsTeamCheck", {
    Text = "Player Chams Team Check",
    Default = false,
    Callback = safeUi("Player Chams Team Check", function(value)
        features.chams:SetSetting("playerTeamCheck", value)
    end),
})

ChamsLeft:AddToggle("PlayerChamsVisibleOnly", {
    Text = "Visible Only",
    Default = false,
    Callback = safeUi("Player Chams Visible Only", function(value)
        features.chams:SetSetting("playerVisibleOnly", value)
    end),
})

ChamsLeft:AddSlider("PlayerChamsFill", {
    Text = "Player Chams Fill",
    Default = 0.7,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = safeUi("Player Chams Fill", function(value)
        features.chams:SetSetting("playerFillTransparency", value)
    end),
})

ChamsLeft:AddSlider("PlayerChamsOutline", {
    Text = "Player Chams Outline",
    Default = 0,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = safeUi("Player Chams Outline", function(value)
        features.chams:SetSetting("playerOutlineTransparency", value)
    end),
})

ChamsLeft:AddLabel("Player Chams Color"):AddColorPicker("PlayerChamsColor", {
    Default = Color3.fromRGB(255, 0, 0),
    Callback = safeUi("Player Chams Color", function(value)
        features.chams:SetSetting("playerColor", value)
    end),
})

ChamsLeft:AddToggle("WeaponChamsEnabled", {
    Text = "Weapon Chams Enabled",
    Default = false,
    Callback = safeUi("Weapon Chams Enabled", function(value)
        features.chams:SetSetting("weaponEnabled", value)
    end),
})

ChamsLeft:AddSlider("WeaponChamsFill", {
    Text = "Weapon Chams Fill",
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = safeUi("Weapon Chams Fill", function(value)
        features.chams:SetSetting("weaponFillTransparency", value)
    end),
})

ChamsLeft:AddSlider("WeaponChamsOutline", {
    Text = "Weapon Chams Outline",
    Default = 0,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = safeUi("Weapon Chams Outline", function(value)
        features.chams:SetSetting("weaponOutlineTransparency", value)
    end),
})

ChamsLeft:AddLabel("Weapon Chams Color"):AddColorPicker("WeaponChamsColor", {
    Default = Color3.fromRGB(0, 255, 255),
    Callback = safeUi("Weapon Chams Color", function(value)
        features.chams:SetSetting("weaponColor", value)
    end),
})

-- Kill Effects Section
local KillEffectsRight = VisualsTab:AddRightGroupbox("Kill Effects")

KillEffectsRight:AddToggle("KillEffectsEnabled", {
    Text = "Kill Effects Enabled",
    Default = false,
    Callback = safeUi("Kill Effects Enabled", function(value)
        features.killEffects:SetSetting("enabled", value)
    end),
})

KillEffectsRight:AddSlider("KillEffectDuration", {
    Text = "Kill Effect Duration",
    Default = 0.8,
    Min = 0.3,
    Max = 2,
    Rounding = 1,
    Suffix = "s",
    Callback = safeUi("Kill Effect Duration", function(value)
        features.killEffects:SetSetting("duration", value)
    end),
})

KillEffectsRight:AddSlider("KillEffectIntensity", {
    Text = "Kill Effect Intensity",
    Default = 0.6,
    Min = 0.2,
    Max = 1,
    Rounding = 1,
    Callback = safeUi("Kill Effect Intensity", function(value)
        features.killEffects:SetSetting("intensity", value)
    end),
})

KillEffectsRight:AddLabel("Kill Effect Color"):AddColorPicker("KillEffectColor", {
    Default = Color3.fromRGB(255, 0, 100),
    Callback = safeUi("Kill Effect Color", function(value)
        features.killEffects:SetSetting("color", value)
    end),
})

-- World Effects Section
local WorldEffectsRight = VisualsTab:AddRightGroupbox("World Effects")

WorldEffectsRight:AddToggle("AntiFlash", {
    Text = "Anti Flash",
    Default = false,
    Callback = safeUi("Anti Flash", function(value)
        features.worldEffects:SetSetting("antiFlash", value)
    end),
})

WorldEffectsRight:AddToggle("AntiSmoke", {
    Text = "Anti Smoke",
    Default = false,
    Callback = safeUi("Anti Smoke", function(value)
        features.worldEffects:SetSetting("antiSmoke", value)
    end),
})

-- Notification
Library:Notify("Bloxtrike loaded.", 3)
