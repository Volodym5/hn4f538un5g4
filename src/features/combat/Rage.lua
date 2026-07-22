local Rage = {}
Rage.__index = Rage

local TARGET_PARTS = {
    "Head",
    "UpperTorso",
    "LowerTorso",
}

local function safeRequire(module)
    if not module then
        return nil
    end

    local ok, result = pcall(require, module)
    if ok then
        return result
    end

    return nil
end

local function getCenter(camera)
    if not camera then
        return nil
    end

    return Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y * 0.5)
end

local function getHookFunction()
    local candidates = {}

    if type(hookfunction) == "function" then
        candidates[#candidates + 1] = hookfunction
    end

    if getgenv then
        local env = getgenv()
        if type(env) == "table" and type(env.hookfunction) == "function" then
            candidates[#candidates + 1] = env.hookfunction
        end
        if type(env) == "table" and type(env.BloxstrikeSavedHookFunction) == "function" then
            candidates[#candidates + 1] = env.BloxstrikeSavedHookFunction
        end
    end

    if syn and type(syn) == "table" and type(syn.hookfunction) == "function" then
        candidates[#candidates + 1] = syn.hookfunction
    end

    if _G and type(_G) == "table" then
        if type(_G.hookfunction) == "function" then
            candidates[#candidates + 1] = _G.hookfunction
        end
        if type(_G.BloxstrikeSavedHookFunction) == "function" then
            candidates[#candidates + 1] = _G.BloxstrikeSavedHookFunction
        end
    end

    for _, candidate in ipairs(candidates) do
        if type(candidate) == "function" then
            return candidate
        end
    end

    return nil
end

local function captureHookFunction()
    local hookFn = getHookFunction()
    if type(hookFn) == "function" then
        if getgenv then
            local env = getgenv()
            if type(env) == "table" then
                env.BloxstrikeSavedHookFunction = hookFn
            end
        end
        if _G and type(_G) == "table" then
            _G.BloxstrikeSavedHookFunction = hookFn
        end
    end
    return hookFn
end

local CAPTURED_HOOK_FUNCTION = captureHookFunction()

function Rage.new(context)
    local self = setmetatable({}, Rage)

    self.services = context.services
    self.globals = context.globals
    self.cleaner = context.Cleaner.new()
    self.errorHandler = context.errorHandler
    self.player = self.globals:GetPlayer()
    self.repStore = self.services.ReplicatedStorage
    self.workspace = self.services.Workspace

    self.running = true
    self._lastRcsTick = 0
    self._rcsAccumulator = 0
    self._lastRapidClick = 0
    self._silentAimHooks = {}
    self._silentAimInstalled = false
    self._silentAimBound = false
    self._weaponDefaults = {}
    self._weaponModules = {}
    self._weaponTables = {}
    self._weaponRuntimeRoots = setmetatable({}, { __mode = "k" })
    self._gunClientFunctions = {}
    self._gunClientScanClock = 0
    self._silentAimDebugThrottle = 0
    self._cachedExcludeList = {}
    self._lastExcludeUpdate = 0

    -- ═══════════════════════════════════════════════════════
    -- RAGE BOT STATE
    self._lastRageFire = 0
    self._rageTarget = nil
    self._rageBurstState = nil
    -- ═══════════════════════════════════════════════════════

    self.settings = {
        rageMode = false,
        rageToggleKey = Enum.KeyCode.Unknown,
        -- ═══════════════════════════════════════════════════
        -- RAGE BOT SETTINGS
        rageFireRate = 1,               -- 1ms = max speed
        ragePrediction = true,           -- lead moving targets
        ragePredictionAmount = 0.9,      -- how much to lead
        ragePartBias = "Smart",          -- "Smart" | "Head" | "Nearest" | "Random"
        rageTargetPriority = "Distance", -- "Distance" | "LowestHealth" | "Crosshair"
        rageKillSwitch = true,           -- instant swap on kill
        rageBurstMode = false,
        rageBurstCount = 3,
        rageBurstDelay = 15,
        rageMaxRange = 10000,            -- max engagement distance
        -- ═══════════════════════════════════════════════════

        silentAim = false,
        silentAimToggleKey = Enum.KeyCode.Unknown,
        wallbang = false,
        wallbangToggleKey = Enum.KeyCode.Unknown,
        dynamicMiss = false,
        baseHitChance = 100,

        aimlock = false,
        aimlockToggleKey = Enum.KeyCode.Unknown,
        aimlockHoldKey = Enum.UserInputType.MouseButton2,
        aimlockMethod = "Raw Mouse",
        aimlockFov = 150,
        aimSmoothness = 2,
        aimJitter = 10,
        flickBot = false,

        targetPart = "Head",
        randomPart = false,
        fullFov360 = false,
        aimWallCheck = true,
        teamCheck = true,
        showFovCircle = false,
        fovSize = 150,

        instantReload = false,
        memoryNoRecoil = false,
        noSpread = false,
        instaEquip = false,
        autoClicker = false,
        autoClickDelay = 50,

        rcs = false,
        rcsStrength = 50,
        rcsDelay = 0,
    }

    self.silentAimCircle = nil
    self.aimlockCircle = nil

    if Drawing and Drawing.new then
        local ok1, circle1 = pcall(Drawing.new, "Circle")
        if ok1 and circle1 then
            circle1.Visible = false
            circle1.Color = Color3.fromRGB(255, 140, 190)
            circle1.Thickness = 1
            circle1.Transparency = 0.6
            circle1.NumSides = 64
            circle1.Filled = false
            self.silentAimCircle = circle1
            self.cleaner:Give(function()
                pcall(function()
                    circle1.Visible = false
                    circle1:Remove()
                end)
            end)
        end

        local ok2, circle2 = pcall(Drawing.new, "Circle")
        if ok2 and circle2 then
            circle2.Visible = false
            circle2.Color = Color3.fromRGB(120, 200, 255)
            circle2.Thickness = 1
            circle2.Transparency = 0.55
            circle2.NumSides = 64
            circle2.Filled = false
            self.aimlockCircle = circle2
            self.cleaner:Give(function()
                pcall(function()
                    circle2.Visible = false
                    circle2:Remove()
                end)
            end)
        end
    end

    self:_bind()
    return self
end

function Rage:_isActive()
    return self.running and self.globals and self.globals:IsAlive() ~= nil
end

function Rage:_getCamera()
    return self.globals:GetCamera()
end

function Rage:_getAimCenter()
    return getCenter(self:_getCamera())
end

function Rage:_debugSilentAim(message)
    return
end

function Rage:_isLocalPlayerModel(model)
    if not model then
        return false
    end

    local player = self.player or (self.globals and self.globals:GetPlayer())
    if not player then
        return false
    end

    local current = model
    while current do
        if current.Name == player.Name then
            return true
        end
        current = current.Parent
    end

    if model == player.Character then
        return true
    end

    local character = player.Character
    if character then
        local modelHumanoid = model:FindFirstChildOfClass("Humanoid")
        local characterHumanoid = character:FindFirstChildOfClass("Humanoid")
        if modelHumanoid and characterHumanoid and modelHumanoid == characterHumanoid then
            return true
        end
    end

    return false
end

function Rage:_isSpawnProtected(model)
    if not model then
        return true
    end
    if model:GetAttribute("Invincible") == true then
        return true
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then
        return true
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════
-- RAGE BOT: Smart part selection — always tries Head first,
-- falls through body parts, no visibility checks.
-- ═══════════════════════════════════════════════════════════════════
function Rage:_rageGetBestPart(model)
    if not model then return nil, "None" end

    local bias = self.settings.ragePartBias or "Smart"

    if bias == "Smart" then
        local partsToTry = {
            { model:FindFirstChild("Head"), "Head" },
            { model:FindFirstChild("UpperTorso"), "UpperTorso" },
            { model:FindFirstChild("LowerTorso"), "LowerTorso" },
            { model:FindFirstChild("HumanoidRootPart"), "HumanoidRootPart" },
        }
        for _, entry in ipairs(partsToTry) do
            if entry[1] and entry[1]:IsA("BasePart") then
                return entry[1], entry[2]
            end
        end
        for _, child in ipairs(model:GetChildren()) do
            if child:IsA("BasePart") then
                return child, child.Name
            end
        end
        return nil, "None"
    end

    if bias == "Head" then
        local head = model:FindFirstChild("Head")
        if head and head:IsA("BasePart") then return head, "Head" end
        local ut = model:FindFirstChild("UpperTorso")
        if ut and ut:IsA("BasePart") then return ut, "UpperTorso" end
        for _, child in ipairs(model:GetChildren()) do
            if child:IsA("BasePart") then return child, child.Name end
        end
        return nil, "None"
    end

    if bias == "Nearest" then
        local camera = self:_getCamera()
        local origin = camera and camera.CFrame.Position or Vector3.zero
        local bestPart, bestName, bestDist = nil, "None", math.huge
        for _, child in ipairs(model:GetChildren()) do
            if child:IsA("BasePart") then
                local dist = (child.Position - origin).Magnitude
                if dist < bestDist then
                    bestPart, bestName, bestDist = child, child.Name, dist
                end
            end
        end
        if not bestPart then
            local head = model:FindFirstChild("Head")
            if head and head:IsA("BasePart") then return head, "Head" end
        end
        return bestPart, bestName
    end

    if bias == "Random" then
        local parts = {}
        for _, child in ipairs(model:GetChildren()) do
            if child:IsA("BasePart") then
                parts[#parts + 1] = child
            end
        end
        if #parts > 0 then
            local chosen = parts[math.random(1, #parts)]
            return chosen, chosen.Name
        end
        local head = model:FindFirstChild("Head")
        if head and head:IsA("BasePart") then return head, "Head" end
        return nil, "None"
    end

    local head = model:FindFirstChild("Head") or model:FindFirstChild("UpperTorso") or model:FindFirstChildOfClass("BasePart")
    if not head then return nil, "None" end
    return head, head.Name
end

-- ═══════════════════════════════════════════════════════════════════
-- RAGE BOT: Movement prediction — leads moving targets so silent aim
-- lands on where they WILL be, not where they ARE.
-- ═══════════════════════════════════════════════════════════════════
function Rage:_ragePredictPosition(part, distance)
    if not self.settings.ragePrediction then
        return part.Position
    end
    if not part or not part:IsA("BasePart") then
        return part and part.Position or Vector3.zero
    end
    local vel = part.AssemblyLinearVelocity or Vector3.zero
    local speed = vel.Magnitude
    if speed < 3 then
        return part.Position
    end
    -- Approximate bullet travel time
    local bulletSpeed = 2000
    local travelTime = distance / math.max(bulletSpeed, 100)
    local predAmount = tonumber(self.settings.ragePredictionAmount) or 0.9
    return part.Position + vel * travelTime * predAmount
end

-- ═══════════════════════════════════════════════════════════════════
-- RAGE BOT: Target acquisition — completely independent from silent aim.
-- No team check, no wall check, no FOV limit. Everyone is a target.
-- 360° always. Prioritizes smartly.
-- ═══════════════════════════════════════════════════════════════════
function Rage:_rageGetTarget()
    local camera = self:_getCamera()
    if not camera then return nil end

    local origin = camera.CFrame.Position
    local maxDist = tonumber(self.settings.rageMaxRange) or 10000

    -- Get ALL models — no team filtering
    local characters = self.globals:GetTargetModels(false)
    if not characters or #characters == 0 then
        return nil
    end

    local candidates = {}
    local priority = self.settings.rageTargetPriority or "Distance"

    for _, model in ipairs(characters) do
        -- Only skip ourselves
        if self:_isLocalPlayerModel(model) then
            continue
        end

        -- Skip dead / invincible
        if self:_isSpawnProtected(model) then
            continue
        end

        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
            continue
        end

        -- Smart part selection — no visibility check (shoot through everything)
        local part, partName = self:_rageGetBestPart(model)
        if not part then
            continue
        end

        local distance = (part.Position - origin).Magnitude
        if distance > maxDist then
            continue
        end

        -- Predict where the target will be
        local aimPos = self:_ragePredictPosition(part, distance)

        -- Score the target
        local score = 0
        if priority == "Distance" then
            score = distance
        elseif priority == "LowestHealth" then
            score = humanoid.Health * 10 + distance * 0.01
        elseif priority == "Crosshair" then
            local viewportPos, onScreen = camera:WorldToViewportPoint(aimPos)
            local center = self:_getAimCenter()
            local screenDist = center and (Vector2.new(viewportPos.X, viewportPos.Y) - center).Magnitude or distance
            score = screenDist * 2 + distance * 0.01
        end

        candidates[#candidates + 1] = {
            model = model,
            part = part,
            aimPos = aimPos,
            partName = partName,
            humanoid = humanoid,
            distance = distance,
            score = score,
        }
    end

    if #candidates == 0 then
        return nil
    end

    -- Sort by score ascending (lower = better)
    table.sort(candidates, function(a, b)
        return a.score < b.score
    end)

    -- Kill switch: if current target is dead, instantly swap to best
    if self.settings.rageKillSwitch and self._rageTarget and self._rageTarget.model then
        local currentHull = self._rageTarget.model:FindFirstChildOfClass("Humanoid")
        if currentHull and currentHull.Health <= 0 then
            return candidates[1]
        end
    end

    -- Stay on current target if alive (prevents flickering between equal targets)
    if self._rageTarget and self._rageTarget.model then
        local currentHull = self._rageTarget.model:FindFirstChildOfClass("Humanoid")
        if currentHull and currentHull.Health > 0 then
            -- Only switch if the new target is significantly better (>40% better score)
            if #candidates > 0 and candidates[1].score < self._rageTarget.score * 0.6 then
                return candidates[1]
            end
            -- Re-acquire current target with fresh position data
            local part, partName = self:_rageGetBestPart(self._rageTarget.model)
            if part then
                self._rageTarget.part = part
                self._rageTarget.partName = partName
                self._rageTarget.aimPos = self:_ragePredictPosition(part, (part.Position - origin).Magnitude)
                self._rageTarget.distance = (part.Position - origin).Magnitude
                return self._rageTarget
            end
        end
    end

    return candidates[1]
end

-- ═══════════════════════════════════════════════════════════════════
-- RAGE BOT: Auto-fire — supports both full-auto and burst modes
-- ═══════════════════════════════════════════════════════════════════
function Rage:_rageFire()
    if self.settings.rageBurstMode then
        if not self._rageBurstState then
            self._rageBurstState = { count = 0, lastShot = 0 }
        end
        
        local now = tick()
        local burstRate = (self.settings.rageBurstDelay or 15) / 1000
        local maxBurst = self.settings.rageBurstCount or 3
        
        if self._rageBurstState.count >= maxBurst then
            if (now - self._rageBurstState.lastShot) < 0.1 then
                return
            end
            self._rageBurstState.count = 0
        end
        
        if (now - self._rageBurstState.lastShot) >= burstRate then
            self._rageBurstState.lastShot = now
            self._rageBurstState.count = self._rageBurstState.count + 1
            if mouse1click then pcall(mouse1click) end
        end
    else
        if mouse1click then pcall(mouse1click) end
    end
end

-- ═══════════════════════════════════════════════════════════════════
-- RAGE BOT: Main loop — called every render frame from Tick()
-- ═══════════════════════════════════════════════════════════════════
function Rage:_updateRageMode()
    if not self.settings.rageMode then
        self._rageTarget = nil
        self._lastRageFire = 0
        self._rageBurstState = nil
        return
    end

    -- Acquire best target (no team check, no wall check, 360°, everyone)
    local target = self:_rageGetTarget()
    if not target then
        self._rageTarget = nil
        self._lastRageFire = 0
        return
    end

    self._rageTarget = target

    -- Fire as fast as the fire rate allows (default 1ms = every frame)
    local fireRateMs = tonumber(self.settings.rageFireRate) or 1
    local now = tick()

    if self._lastRageFire == 0 then
        self._lastRageFire = now
        self:_rageFire()
        return
    end

    if (now - self._lastRageFire) < (fireRateMs / 1000) then
        return
    end

    self._lastRageFire = now
    self:_rageFire()
end

function Rage:_getTargetPart(model)
    if not model then
        return nil
    end

    local choice = self.settings.targetPart
    if self.settings.randomPart or choice == "Random Part" then
        local pool = { "Head", "UpperTorso", "LowerTorso" }
        choice = pool[math.random(1, #pool)]
    end

    return model:FindFirstChild(choice) or model:FindFirstChild("Head")
end

function Rage:_isTargetVisible(part, model)
    if self.settings.wallbang or not self.settings.aimWallCheck then
        return true
    end

    local camera = self:_getCamera()
    if not camera or not part then
        return false
    end

    local origin = camera.CFrame.Position
    local direction = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local ignore = self:_buildExcludeList(camera)

    local attempts = 0
    while attempts < 15 do
        attempts = attempts + 1
        params.FilterDescendantsInstances = ignore

        local result = self.workspace:Raycast(origin, direction, params)
        if not result then
            return true
        end

        if result.Instance and result.Instance:IsDescendantOf(model) then
            return true
        end

        if result.Instance and (
            result.Instance.Transparency >= 0.5
            or not result.Instance.CanCollide
            or tostring(result.Instance.Name):lower():find("hitbox", 1, true)
            or result.Instance.Name == "Glass"
        ) then
            ignore[#ignore + 1] = result.Instance
        else
            return false
        end
    end

    return false
end

function Rage:_buildExcludeList(camera)
    local now = tick()
    if self._lastExcludeUpdate and (now - self._lastExcludeUpdate) < 0.5 and #self._cachedExcludeList > 0 then
        return self._cachedExcludeList
    end

    local ignore = {}
    local player = self.player or (self.globals and self.globals:GetPlayer())
    
    if camera then
        ignore[#ignore + 1] = camera
    end

    if player then
        local character = player.Character
        if character then
            ignore[#ignore + 1] = character
            for _, descendant in ipairs(character:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    ignore[#ignore + 1] = descendant
                end
            end
            for _, tool in ipairs(character:GetChildren()) do
                if tool:IsA("Tool") then
                    ignore[#ignore + 1] = tool
                    for _, descendant in ipairs(tool:GetDescendants()) do
                        if descendant:IsA("BasePart") then
                            ignore[#ignore + 1] = descendant
                        end
                    end
                end
            end
        end

        local charactersFolder = self.workspace:FindFirstChild("Characters")
        if charactersFolder then
            for _, teamFolder in ipairs(charactersFolder:GetChildren()) do
                local playerModel = teamFolder:FindFirstChild(player.Name)
                if playerModel then
                    ignore[#ignore + 1] = playerModel
                    for _, descendant in ipairs(playerModel:GetDescendants()) do
                        if descendant:IsA("BasePart") then
                            ignore[#ignore + 1] = descendant
                        end
                    end
                    break
                end
            end
        end
    end

    local function excludeFolder(folderName)
        local folder = self.workspace:FindFirstChild(folderName)
        if folder then
            ignore[#ignore + 1] = folder
            for _, child in ipairs(folder:GetDescendants()) do
                if child:IsA("BasePart") then
                    ignore[#ignore + 1] = child
                end
            end
        end
    end

    excludeFolder("Camera")
    excludeFolder("Debris")
    excludeFolder("Effects")
    excludeFolder("Ignore")
    excludeFolder("Hitboxes")
    excludeFolder("RaycastVisualizers")

    for _, obj in ipairs(self.workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not obj.CanCollide then
            ignore[#ignore + 1] = obj
        end
    end

    self._cachedExcludeList = ignore
    self._lastExcludeUpdate = now
    
    return ignore
end

function Rage:_getTargetData(maxFov)
    local camera = self:_getCamera()
    local center = self:_getAimCenter()
    if not camera or not center then
        return nil
    end

    local best = nil
    local bestScore = math.huge
    local maxFovRadius = tonumber(maxFov) or self.settings.aimlockFov or 150
    local characters = self.settings.teamCheck and self.globals:GetTargetModels(true) or self.globals:GetTargetModels(false)

    for _, model in ipairs(characters or {}) do
        if self:_isLocalPlayerModel(model) then
            continue
        end
        
        if self:_isSpawnProtected(model) then
            continue
        end

        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            local part = self:_getTargetPart(model)
            if part then
                local worldPos, onScreen = camera:WorldToViewportPoint(part.Position)
                
                local screenDist = self.settings.fullFov360 
                    and 0
                    or (onScreen and (Vector2.new(worldPos.X, worldPos.Y) - center).Magnitude or math.huge)
                
                if screenDist > maxFovRadius then
                    continue
                end
                
                if not self:_isTargetVisible(part, model) then
                    continue
                end
                
                local actualDistance = (part.Position - camera.CFrame.Position).Magnitude
                local score = actualDistance * (1 + screenDist / maxFovRadius * 2)
                
                if score < bestScore then
                    best = {
                        model = model,
                        part = part,
                        pos = part.Position,
                        score = screenDist,
                        distance = actualDistance,
                    }
                    bestScore = score
                end
            end
        end
    end

    return best
end

function Rage:_applyAim(target, strengthScale)
    local camera = self:_getCamera()
    local center = self:_getAimCenter()
    if not camera or not center or not target then
        return
    end

    local worldPos = target.pos or target.part.Position
    local viewportPos = camera:WorldToViewportPoint(worldPos)
    local jitter = tonumber(self.settings.aimJitter) or 10
    local jitterScale = jitter / 100
    local dx = (viewportPos.X - center.X) + ((math.random() - 0.5) * jitterScale * 2)
    local dy = (viewportPos.Y - center.Y) + ((math.random() - 0.5) * jitterScale * 2)
    local smooth = math.max(1, tonumber(self.settings.aimSmoothness) or 2)
    local scale = strengthScale or 1

    dx = (dx / smooth) * scale
    dy = (dy / smooth) * scale

    if self.settings.aimlockMethod == "Raw Mouse" and mousemoverel then
        mousemoverel(dx, dy)
    else
        local look = CFrame.lookAt(camera.CFrame.Position, worldPos + Vector3.new(dx * 0.01, dy * 0.01, 0))
        camera.CFrame = camera.CFrame:Lerp(look, 0.6)
    end
end

function Rage:_updateFovCircles()
    local camera = self:_getCamera()
    local center = self:_getAimCenter()
    if not camera or not center then
        if self.silentAimCircle then
            self.silentAimCircle.Visible = false
        end
        if self.aimlockCircle then
            self.aimlockCircle.Visible = false
        end
        return
    end

    if self.silentAimCircle then
        if self.settings.silentAim and self.settings.showFovCircle then
            self.silentAimCircle.Visible = true
            self.silentAimCircle.Position = center
            self.silentAimCircle.Radius = tonumber(self.settings.fovSize) or 150
        else
            self.silentAimCircle.Visible = false
        end
    end

    if self.aimlockCircle then
        if self.settings.aimlock then
            self.aimlockCircle.Visible = true
            self.aimlockCircle.Position = center
            self.aimlockCircle.Radius = tonumber(self.settings.aimlockFov) or 150
        else
            self.aimlockCircle.Visible = false
        end
    end
end

function Rage:_patchWeaponModules()
    local weaponsRoot = self.repStore:FindFirstChild("Weapons")
        or (self.repStore:FindFirstChild("Database") and self.repStore.Database:FindFirstChild("Weapons"))

    local collected = {}
    if weaponsRoot then
        for _, object in ipairs(weaponsRoot:GetChildren()) do
            if object:IsA("ModuleScript") then
                local result = safeRequire(object)
                if type(result) == "table" then
                    local hasField = false
                    for _, field in ipairs({
                        "ReloadTime",
                        "RecoilControl",
                        "MaxSpread",
                        "FireRate",
                        "Auto",
                        "EquipTime",
                    }) do
                        if rawget(result, field) ~= nil then
                            hasField = true
                            break
                        end
                    end

                    if hasField then
                        collected[result] = true
                    end
                end
            end
        end
    end

    for data in pairs(collected) do
        if not self._weaponTables[data] then
            self._weaponTables[data] = true
            self._weaponDefaults[data] = {
                ReloadTime = rawget(data, "ReloadTime"),
                RecoilControl = rawget(data, "RecoilControl"),
                MaxSpread = rawget(data, "MaxSpread"),
                Auto = rawget(data, "Auto"),
                EquipTime = rawget(data, "EquipTime"),
            }
        end
    end

    local function setField(tbl, key, value)
        if type(tbl) ~= "table" then
            return
        end

        if setreadonly then
            pcall(setreadonly, tbl, false)
        end

        pcall(function()
            rawset(tbl, key, value)
        end)

        if setreadonly then
            pcall(setreadonly, tbl, true)
        end
    end

    for data, defaults in pairs(self._weaponDefaults) do
        if self.settings.instantReload then
            setField(data, "ReloadTime", 0)
        else
            setField(data, "ReloadTime", defaults.ReloadTime)
        end

        if self.settings.memoryNoRecoil or self.settings.rageMode then
            setField(data, "RecoilControl", 0)
        else
            setField(data, "RecoilControl", defaults.RecoilControl)
        end

        if self.settings.noSpread or self.settings.rageMode then
            setField(data, "MaxSpread", 0)
        else
            setField(data, "MaxSpread", defaults.MaxSpread)
        end

        if self.settings.instaEquip then
            setField(data, "EquipTime", 0)
        else
            setField(data, "EquipTime", defaults.EquipTime)
        end

        if self.settings.autoClicker then
            setField(data, "Auto", true)
        else
            setField(data, "Auto", defaults.Auto)
        end
    end

    if self.settings.instaEquip then
        local character = self.player and self.player.Character
        local tool = character and character:FindFirstChildWhichIsA("Tool")
        if tool then
            self:_refreshEquippedTool(tool)
        end
    end
end

function Rage:_initInventorySupport()
    if self.inventoryController then
        return
    end

    local module = self.repStore:FindFirstChild("Controllers")
        and self.repStore.Controllers:FindFirstChild("InventoryController")
    if not module then
        return
    end

    local result = safeRequire(module)
    if type(result) == "table" then
        self.inventoryController = result
    end
end

function Rage:_getGunClientFunctions()
    local now = os.clock()
    if #self._gunClientFunctions ~= 0 and (now - self._gunClientScanClock) <= 10 then
        return self._gunClientFunctions
    end

    self._gunClientFunctions = {}
    self._gunClientScanClock = now

    local getter = getgc or (debug and debug.getgc)
    local getinfoFn = getinfo or (debug and debug.getinfo)
    if not (getter and getinfoFn) then
        return self._gunClientFunctions
    end

    local ok, objects = pcall(getter)
    if not ok or type(objects) ~= "table" then
        return self._gunClientFunctions
    end

    for i = 1, #objects do
        local object = objects[i]
        if type(object) == "function" then
            local info = getinfoFn(object)
            local source = info and info.source
            if type(source) == "string" and source:find("GunClient", 1, true) then
                self._gunClientFunctions[#self._gunClientFunctions + 1] = {
                    func = object,
                    source = source,
                }
            end
        end
    end

    return self._gunClientFunctions
end

function Rage:_refreshEquippedTool(tool)
    if not tool then
        return
    end

    local name = tool.Name
    if type(name) ~= "string" or name == "" then
        return
    end

    local getter = getgc or (debug and debug.getgc)
    local getinfoFn = getinfo or (debug and debug.getinfo)
    local getupvaluesFn = getupvalues or (debug and debug.getupvalues)
    local setupvalueFn = setupvalue or (debug and debug.setupvalue)
    if not (getter and getinfoFn and getupvaluesFn and setupvalueFn) then
        return
    end

    task.spawn(function()
        task.wait(0.2)

        for _, entry in ipairs(self:_getGunClientFunctions()) do
            local func = entry.func
            local source = entry.source

            if type(source) == "string" and source:find(name, 1, true) then
                local ok, upvalues = pcall(getupvaluesFn, func)
                if ok and type(upvalues) == "table" then
                    for index, value in ipairs(upvalues) do
                        if type(value) == "number" and value < 10 then
                            pcall(setupvalueFn, func, index, 0)
                        end
                    end
                end
            end
        end
    end)
end

function Rage:_hookAnimator(animator)
    if not animator or not animator:IsA("Animator") then
        return
    end

    if animator:GetAttribute("WyvernHooked") then
        return
    end

    animator:SetAttribute("WyvernHooked", true)
    self.cleaner:Give(self.errorHandler:Connect(animator.AnimationPlayed, "Rage Weapon Animation", function(track)
        local animation = track and track.Animation
        if not animation then
            return
        end

        local animationName = string.lower(animation.Name or "")
        local animationId = string.lower(animation.AnimationId or "")

        local function apply()
            if self.settings.instantReload and (
                animationName:find("reload", 1, true)
                or animationId:find("reload", 1, true)
            ) then
                pcall(function()
                    track:AdjustSpeed(100)
                end)
            elseif self.settings.instaEquip and (
                animationName:find("equip", 1, true)
                or animationName:find("draw", 1, true)
                or animationId:find("equip", 1, true)
                or animationId:find("draw", 1, true)
            ) then
                pcall(function()
                    track:AdjustSpeed(100)
                end)
            end
        end

        self.cleaner:Give(self.errorHandler:Connect(track:GetPropertyChangedSignal("Speed"), "Rage Weapon Animation Speed", apply))
        apply()
    end))
end

function Rage:_bindWeaponRuntime(root)
    if not root or self._weaponRuntimeRoots[root] then
        return
    end

    self._weaponRuntimeRoots[root] = true

    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("Animator") then
            self:_hookAnimator(descendant)
        end
    end

    self.cleaner:Give(self.errorHandler:Connect(root.DescendantAdded, "Rage Weapon DescendantAdded", function(descendant)
        if descendant:IsA("Animator") then
            self:_hookAnimator(descendant)
        end
    end))
end

function Rage:_installSilentAimHooks()
    local hookFn = CAPTURED_HOOK_FUNCTION or getHookFunction()
    if type(hookFn) ~= "function" then
        return false
    end

    if not self.inventoryController then
        self:_initInventorySupport()
    end

    local controller = self.inventoryController
    if type(controller) ~= "table" then
        return false
    end

    local function hookWeaponObject(weaponData)
        if type(weaponData) ~= "table" then
            return false
        end

        local okBullet, bullet = pcall(function()
            return weaponData.Bullet
        end)
        if not okBullet or type(bullet) ~= "table" then
            return false
        end
        if type(bullet._performRaycast) ~= "function" then
            return false
        end
        if self._silentAimHooks[weaponData] then
            self._silentAimInstalled = true
            return true
        end

        self._silentAimHooks[weaponData] = true
        local originalRaycast
        local hookWrapper = newcclosure or function(fn)
            return fn
        end

        originalRaycast = hookFn(bullet._performRaycast, hookWrapper(function(bulletObject, spreadValue)
            local adjustedSpread = spreadValue
            if self.settings.noSpread then
                if type(spreadValue) == "number" then
                    adjustedSpread = 0
                elseif typeof(spreadValue) == "Vector3" then
                    adjustedSpread = Vector3.zero
                elseif typeof(spreadValue) == "Vector2" then
                    adjustedSpread = Vector2.zero
                end
            end

            local okBase, baseResult = pcall(originalRaycast, bulletObject, adjustedSpread)
            if not okBase or type(baseResult) ~= "table" then
                return originalRaycast(bulletObject, adjustedSpread)
            end

            if not self.settings.silentAim then
                return baseResult
            end

            local target = self:_getTargetData(self.settings.fovSize)
            if not target then
                return baseResult
            end

            if self.settings.dynamicMiss then
                local hitChance = tonumber(self.settings.baseHitChance) or 100
                if math.random(1, 100) > math.clamp(hitChance, 1, 100) then
                    return baseResult
                end
            end

            local camera = self:_getCamera()
            if not camera then
                return baseResult
            end

            local origin = camera.CFrame.Position
            local direction = (target.pos - origin).Unit
            local range = 500
            pcall(function()
                if type(bulletObject) == "table" then
                    if type(bulletObject.Properties) == "table" and type(bulletObject.Properties.Range) == "number" then
                        range = bulletObject.Properties.Range
                    elseif type(bulletObject.Range) == "number" then
                        range = bulletObject.Range
                    end
                end
            end)

            local params = RaycastParams.new()
            params.IgnoreWater = false
            params.FilterType = Enum.RaycastFilterType.Exclude
            
            local filter = self:_buildExcludeList(camera)
            params.FilterDescendantsInstances = filter

            local distance = (target.pos - origin).Magnitude
            local raycast = self.workspace:Raycast(origin, direction * math.max(range, distance + 10), params)
            
            local hitPos, hitInstance, hitMaterial, hitNormal
            
            if raycast then
                local hitModel = raycast.Instance:FindFirstAncestorOfClass("Model")
                if hitModel == target.model or raycast.Instance:IsDescendantOf(target.model) then
                    hitPos = raycast.Position
                    hitInstance = raycast.Instance
                    hitMaterial = raycast.Material.Name
                    hitNormal = raycast.Normal
                else
                    hitPos = target.part.Position
                    hitInstance = target.part
                    hitMaterial = "Plastic"
                    hitNormal = (origin - hitPos).Unit
                end
            else
                hitPos = target.part.Position
                hitInstance = target.part
                hitMaterial = "Plastic"
                hitNormal = (origin - hitPos).Unit
            end

            return {
                Origin = origin,
                Direction = direction,
                Hits = {
                    {
                        Position = hitPos,
                        Instance = hitInstance,
                        Material = hitMaterial,
                        Normal = hitNormal,
                        Exit = false,
                    },
                },
                Distance = (hitPos - origin).Magnitude,
            }
        end))

        self._silentAimInstalled = true
        return true
    end

    local okCurrent, current = pcall(function()
        if type(controller.getCurrentEquipped) == "function" then
            return controller.getCurrentEquipped()
        end
        return nil
    end)
    if okCurrent and current then
        hookWeaponObject(current)
        if self.settings.instaEquip then
            local character = self.player and self.player.Character
            local tool = character and character:FindFirstChildWhichIsA("Tool")
            if tool then
                self:_refreshEquippedTool(tool)
            end
        end
    end

    local equippedEvent = controller.OnInventoryItemEquipped
    if equippedEvent and not self._silentAimBound then
        self._silentAimBound = true
        self.cleaner:Give(self.errorHandler:Connect(equippedEvent, "Rage Inventory Equipped", function(_, equipped)
            hookWeaponObject(equipped)
            if self.settings.instaEquip then
                local character = self.player and self.player.Character
                local tool = character and character:FindFirstChildWhichIsA("Tool")
                if tool then
                    self:_refreshEquippedTool(tool)
                end
            end
        end))
    end

    return true
end

-- ═══════════════════════════════════════════════════════════════════
-- Tick() — calls rage bot update every frame
-- ═══════════════════════════════════════════════════════════════════
function Rage:Tick(dt)
    if not self:_isActive() then
        self:_updateFovCircles()
        return
    end

    self:_updateFovCircles()
    self:_updateRageMode()       -- rage bot runs first every frame
    self:_updateAimlock(dt or 0.016)
    self:_updateRcs(dt or 0.016)
    self:_updateAutoClick()
    self:_installSilentAimHooks()
end

function Rage:_updateAimlock(dt)
    if not self.settings.aimlock and not self.settings.flickBot then
        return
    end

    local isHolding = false
    if typeof(self.settings.aimlockHoldKey) == "EnumItem" then
        if self.settings.aimlockHoldKey.EnumType == Enum.UserInputType then
            isHolding = self.services.UserInputService:IsMouseButtonPressed(self.settings.aimlockHoldKey)
        elseif self.settings.aimlockHoldKey.EnumType == Enum.KeyCode then
            isHolding = self.services.UserInputService:IsKeyDown(self.settings.aimlockHoldKey)
        end
    end

    local target = self:_getTargetData(self.settings.aimlockFov)
    if not target then
        return
    end

    local shouldFlick = self.settings.flickBot and self.services.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    if shouldFlick then
        self:_applyAim(target, 0.7)
        return
    end

    if self.settings.aimlock and isHolding then
        if self.settings.aimWallCheck and not self.settings.wallbang and not self:_isTargetVisible(target.part, target.model) then
            return
        end

        self:_applyAim(target, 1)
    end
end

function Rage:_updateRcs(dt)
    if not (self.settings.rcs or self.settings.rageMode) then
        self._rcsAccumulator = 0
        self._lastRcsTick = 0
        return
    end

    if not self.services.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        self._rcsAccumulator = 0
        self._lastRcsTick = 0
        return
    end

    if self._lastRcsTick == 0 then
        self._lastRcsTick = tick()
        return
    end

    local delayMs = tonumber(self.settings.rcsDelay) or 0
    if (tick() - self._lastRcsTick) < (delayMs / 1000) then
        return
    end

    local strength = tonumber(self.settings.rcsStrength) or 50
    self._rcsAccumulator = self._rcsAccumulator + (strength * dt * 0.8)

    if self._rcsAccumulator >= 1 then
        local amount = math.floor(self._rcsAccumulator)
        self._rcsAccumulator = self._rcsAccumulator - amount

        if mousemoverel then
            mousemoverel(0, amount)
        else
            local camera = self:_getCamera()
            if camera then
                camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(-amount * 0.1), 0, 0)
            end
        end
    end
end

function Rage:_updateAutoClick()
    local fireDelay = nil
    if self.settings.autoClicker then
        fireDelay = tonumber(self.settings.autoClickDelay) or 50
    end

    if not fireDelay then
        self._lastRapidClick = 0
        return
    end

    if not self.services.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        self._lastRapidClick = 0
        return
    end

    if self._lastRapidClick == 0 then
        self._lastRapidClick = tick()
        return
    end

    local delaySeconds = math.max(fireDelay, 1) / 1000
    if (tick() - self._lastRapidClick) < delaySeconds then
        return
    end

    self._lastRapidClick = tick()
    if mouse1click then
        pcall(mouse1click)
    end
end

function Rage:_bind()
    self.cleaner:Give(function()
        self.running = false
    end)

    if self.player and self.player.Character then
        task.spawn(function()
            self:_bindWeaponRuntime(self.player.Character)
        end)
    end

    local currentCamera = self.services.Workspace.CurrentCamera
    if currentCamera then
        task.spawn(function()
            self:_bindWeaponRuntime(currentCamera)
        end)
    end

    if self.player then
        self.cleaner:Give(self.errorHandler:Connect(self.player.CharacterAdded, "Rage CharacterAdded", function(character)
            self:_bindWeaponRuntime(character)
        end))
    end

    self.cleaner:Give(self.errorHandler:Connect(self.services.Workspace:GetPropertyChangedSignal("CurrentCamera"), "Rage CurrentCamera Changed", function()
        local camera = self.services.Workspace.CurrentCamera
        if camera then
            self:_bindWeaponRuntime(camera)
        end
    end))

    if currentCamera then
        self.cleaner:Give(self.errorHandler:Connect(currentCamera:GetPropertyChangedSignal("CameraSubject"), "Rage CameraSubject Changed", function()
            self:_bindWeaponRuntime(currentCamera)
        end))
    end

    self.errorHandler:Spawn("Rage Weapon Mods", function()
        while self.running do
            self:_patchWeaponModules()
            self:_installSilentAimHooks()
            task.wait(2)
        end
    end)

    task.spawn(function()
        self:_patchWeaponModules()
    end)

    self.cleaner:Give(self.errorHandler:Connect(self.services.RunService.RenderStepped, "Rage RenderStepped", function(dt)
        self:Tick(dt or 0.016)
    end))

    self.cleaner:Give(self.errorHandler:Connect(self.services.UserInputService.InputBegan, "Rage InputBegan", function(input, processed)
        if processed then
            return
        end

        if input.UserInputType == Enum.UserInputType.Keyboard then
            if self.settings.rageToggleKey ~= Enum.KeyCode.Unknown and input.KeyCode == self.settings.rageToggleKey then
                self.settings.rageMode = not self.settings.rageMode
            elseif self.settings.silentAimToggleKey ~= Enum.KeyCode.Unknown and input.KeyCode == self.settings.silentAimToggleKey then
                self.settings.silentAim = not self.settings.silentAim
            elseif self.settings.wallbangToggleKey ~= Enum.KeyCode.Unknown and input.KeyCode == self.settings.wallbangToggleKey then
                self.settings.wallbang = not self.settings.wallbang
            elseif self.settings.aimlockToggleKey ~= Enum.KeyCode.Unknown and input.KeyCode == self.settings.aimlockToggleKey then
                self.settings.aimlock = not self.settings.aimlock
            end
        end
    end))
end

function Rage:SetRageMode(value)
    self.settings.rageMode = value == true
end

function Rage:SetRageFireRate(value)
    local number = tonumber(value)
    if number then
        self.settings.rageFireRate = math.clamp(number, 1, 500)
    end
end

function Rage:SetRageToggleKey(value)
    self.settings.rageToggleKey = value or Enum.KeyCode.Unknown
end

function Rage:SetRagePrediction(value)
    self.settings.ragePrediction = value == true
end

function Rage:SetRagePredictionAmount(value)
    local number = tonumber(value)
    if number then
        self.settings.ragePredictionAmount = math.clamp(number, 0, 1)
    end
end

function Rage:SetRagePartBias(value)
    if value then
        self.settings.ragePartBias = value
    end
end

function Rage:SetRageTargetPriority(value)
    if value then
        self.settings.rageTargetPriority = value
    end
end

function Rage:SetRageKillSwitch(value)
    self.settings.rageKillSwitch = value == true
end

function Rage:SetRageBurstMode(value)
    self.settings.rageBurstMode = value == true
end

function Rage:SetRageBurstCount(value)
    local number = tonumber(value)
    if number then
        self.settings.rageBurstCount = math.clamp(number, 1, 20)
    end
end

function Rage:SetRageBurstDelay(value)
    local number = tonumber(value)
    if number then
        self.settings.rageBurstDelay = math.clamp(number, 1, 500)
    end
end

function Rage:SetRageMaxRange(value)
    local number = tonumber(value)
    if number then
        self.settings.rageMaxRange = math.clamp(number, 100, 50000)
    end
end

function Rage:SetSilentAim(value)
    self.settings.silentAim = value == true
    if self.settings.silentAim then
        self:_installSilentAimHooks()
    end
end

function Rage:SetSilentAimToggleKey(value)
    self.settings.silentAimToggleKey = value or Enum.KeyCode.Unknown
end

function Rage:SetWallbang(value)
    self.settings.wallbang = value == true
end

function Rage:SetWallbangToggleKey(value)
    self.settings.wallbangToggleKey = value or Enum.KeyCode.Unknown
end

function Rage:SetDynamicMiss(value)
    self.settings.dynamicMiss = value == true
end

function Rage:SetBaseHitChance(value)
    local number = tonumber(value)
    if number then
        self.settings.baseHitChance = math.clamp(number, 1, 100)
    end
end

function Rage:SetAimlock(value)
    self.settings.aimlock = value == true
end

function Rage:SetAimlockToggleKey(value)
    self.settings.aimlockToggleKey = value or Enum.KeyCode.Unknown
end

function Rage:SetAimlockHoldKey(value)
    self.settings.aimlockHoldKey = value or Enum.UserInputType.MouseButton2
end

function Rage:SetAimlockMethod(value)
    if value then
        self.settings.aimlockMethod = value
    end
end

function Rage:SetAimlockFov(value)
    local number = tonumber(value)
    if number then
        self.settings.aimlockFov = math.clamp(number, 10, 1000)
    end
end

function Rage:SetAimSmoothness(value)
    local number = tonumber(value)
    if number then
        self.settings.aimSmoothness = math.clamp(number, 1, 10)
    end
end

function Rage:SetAimJitter(value)
    local number = tonumber(value)
    if number then
        self.settings.aimJitter = math.clamp(number, 0, 50)
    end
end

function Rage:SetFlickBot(value)
    self.settings.flickBot = value == true
end

function Rage:SetTargetPart(value)
    if value then
        self.settings.targetPart = value
    end
end

function Rage:SetRandomPart(value)
    self.settings.randomPart = value == true
end

function Rage:SetFullFov360(value)
    self.settings.fullFov360 = value == true
end

function Rage:SetAimWallCheck(value)
    self.settings.aimWallCheck = value == true
end

function Rage:SetTeamCheck(value)
    self.settings.teamCheck = value == true
end

function Rage:SetShowFovCircle(value)
    self.settings.showFovCircle = value == true
end

function Rage:SetFovSize(value)
    local number = tonumber(value)
    if number then
        self.settings.fovSize = math.clamp(number, 50, 1000)
    end
end

function Rage:SetInstantReload(value)
    self.settings.instantReload = value == true
    self:_patchWeaponModules()
end

function Rage:SetMemoryNoRecoil(value)
    self.settings.memoryNoRecoil = value == true
    self:_patchWeaponModules()
end

function Rage:SetNoSpread(value)
    self.settings.noSpread = value == true
    self:_patchWeaponModules()
end

function Rage:SetInstaEquip(value)
    self.settings.instaEquip = value == true
    self:_patchWeaponModules()
end

function Rage:SetAutoClicker(value)
    self.settings.autoClicker = value == true
    self:_patchWeaponModules()
end

function Rage:SetAutoClickDelay(value)
    local number = tonumber(value)
    if number then
        self.settings.autoClickDelay = math.clamp(number, 10, 500)
        self:_patchWeaponModules()
    end
end

function Rage:SetRcs(value)
    self.settings.rcs = value == true
end

function Rage:SetRcsStrength(value)
    local number = tonumber(value)
    if number then
        self.settings.rcsStrength = math.clamp(number, 0, 100)
    end
end

function Rage:SetRcsDelay(value)
    local number = tonumber(value)
    if number then
        self.settings.rcsDelay = math.clamp(number, 0, 500)
    end
end

function Rage:GetTargetParts()
    return {
        "Head",
        "UpperTorso",
        "LowerTorso",
        "Random Part",
    }
end

function Rage:GetTargetPart()
    return self.settings.targetPart
end

function Rage:GetAimlockMethod()
    return self.settings.aimlockMethod
end

function Rage:GetRagePartBias()
    return self.settings.ragePartBias
end

function Rage:GetRageTargetPriority()
    return self.settings.rageTargetPriority
end

function Rage:Destroy()
    self.cleaner:Cleanup()
end

return Rage
