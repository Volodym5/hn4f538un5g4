-- ============================================================
-- AIMBOT
-- ============================================================

local Aimbot = {}
Aimbot.__index = Aimbot

function Aimbot.new(context)
    local self = setmetatable({}, Aimbot)

    self.services = context.services
    self.globals = context.globals
    self.cleaner = context.Cleaner.new()
    self.errorHandler = context.errorHandler
    self.settings = {
        enabled = false,
        teamCheck = false,
        wallCheck = false,
        showFov = false,
        fovRadius = 100,
        smoothing = 3,
        aimInput = Enum.UserInputType.MouseButton2,
    }
    self.isAiming = false
    self.fovCircle = nil

    if Drawing and Drawing.new then
        local ok, circle = pcall(Drawing.new, "Circle")
        if ok and circle then
            circle.Filled = false
            circle.Color = Color3.fromRGB(0, 255, 255)
            circle.Visible = false
            circle.Thickness = 1
            self.fovCircle = circle

            self.cleaner:Give(function()
                pcall(function()
                    circle.Visible = false
                    circle:Remove()
                end)
            end)
        end
    end

    self:_bind()
    return self
end

function Aimbot:_getAimScreenPosition(camera)
    local activeCamera = camera or self.globals:GetCamera()
    if not activeCamera then
        return nil
    end

    return Vector2.new(
        activeCamera.ViewportSize.X * 0.5,
        activeCamera.ViewportSize.Y * 0.5
    )
end

function Aimbot:_hasLineOfSight(head)
    local camera = self.globals:GetCamera()
    if not camera or not head then
        return false
    end

    local origin = camera.CFrame.Position
    local direction = head.Position - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local ignoreList = { camera }
    local character = self.globals:GetPlayer().Character
    if character then
        ignoreList[#ignoreList + 1] = character
    end
    params.FilterDescendantsInstances = ignoreList

    local result = self.services.Workspace:Raycast(origin, direction, params)
    if not result then
        return true
    end

    local hitModel = result.Instance and result.Instance:FindFirstAncestorOfClass("Model")
    return hitModel ~= nil and hitModel == head:FindFirstAncestorOfClass("Model")
end

function Aimbot:_getClosestEnemyToMouse()
    if not self.settings.enabled then
        return nil
    end

    local camera = self.globals:GetCamera()
    if not camera then
        return nil
    end

    local aimPosition = self:_getAimScreenPosition(camera)
    if not aimPosition then
        return nil
    end

    local closestHead = nil
    local shortestDistance = self.settings.fovRadius

    for _, enemy in ipairs(self.globals:GetTargetModels(self.settings.teamCheck)) do
        local humanoid = enemy:FindFirstChildOfClass("Humanoid")
        local head = enemy:FindFirstChild("Head")

        if humanoid and humanoid.Health > 0 and head
            and (not self.settings.wallCheck or self:_hasLineOfSight(head))
        then
            local headPosition, onScreen = camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local distance = (Vector2.new(headPosition.X, headPosition.Y) - aimPosition).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestHead = head
                end
            end
        end
    end

    return closestHead
end

function Aimbot:_updateFovCircle()
    if not self.fovCircle then
        return
    end

    if self.settings.showFov then
        local aimPosition = self:_getAimScreenPosition()
        if not aimPosition then
            self.fovCircle.Visible = false
            return
        end

        self.fovCircle.Position = aimPosition
        self.fovCircle.Radius = self.settings.fovRadius
        self.fovCircle.Visible = true
    else
        self.fovCircle.Visible = false
    end
end

function Aimbot:_bind()
    self.cleaner:Give(self.errorHandler:Connect(self.services.UserInputService.InputBegan, "Aimbot InputBegan", function(input)
        if input.UserInputType == self.settings.aimInput then
            self.isAiming = true
        end
    end))

    self.cleaner:Give(self.errorHandler:Connect(self.services.UserInputService.InputEnded, "Aimbot InputEnded", function(input)
        if input.UserInputType == self.settings.aimInput then
            self.isAiming = false
        end
    end))

    self.cleaner:Give(self.errorHandler:Connect(self.services.RunService.RenderStepped, "Aimbot RenderStepped", function()
        self:_updateFovCircle()

        if not self.settings.enabled or not self.isAiming or not self.globals:IsAlive() then
            return
        end

        local camera = self.globals:GetCamera()
        local targetHead = self:_getClosestEnemyToMouse()
        if not camera or not targetHead then
            return
        end

        local headPosition = camera:WorldToViewportPoint(targetHead.Position)
        local aimPosition = self:_getAimScreenPosition(camera)
        if not aimPosition then
            return
        end

        local moveX = (headPosition.X - aimPosition.X) / self.settings.smoothing
        local moveY = (headPosition.Y - aimPosition.Y) / self.settings.smoothing

        if mousemoverel then
            mousemoverel(moveX, moveY)
        end
    end))
end

function Aimbot:SetEnabled(value)
    self.settings.enabled = value == true
end

function Aimbot:SetTeamCheck(value)
    self.settings.teamCheck = value == true
end

function Aimbot:SetWallCheck(value)
    self.settings.wallCheck = value == true
end

function Aimbot:SetShowFov(value)
    self.settings.showFov = value == true
end

function Aimbot:SetFovRadius(value)
    self.settings.fovRadius = tonumber(value) or self.settings.fovRadius
end

function Aimbot:SetSmoothing(value)
    local smoothing = tonumber(value)
    if smoothing and smoothing > 0 then
        self.settings.smoothing = smoothing
    end
end

function Aimbot:Destroy()
    self.cleaner:Cleanup()
end


-- ============================================================
-- HITBOX
-- ============================================================

local Hitbox = {}
Hitbox.__index = Hitbox

function Hitbox.new(context)
    local self = setmetatable({}, Hitbox)

    self.globals = context.globals
    self.cleaner = context.Cleaner.new()
    self.errorHandler = context.errorHandler
    self.settings = {
        enabled = false,
        teamCheck = false,
        size = 3,
        transparency = 0.5,
    }
    self.running = true
    self.originalHeadStates = {}

    self.cleaner:Give(function()
        self.running = false
        self:_restoreAll()
    end)

    self.errorHandler:Spawn("Hitbox Loop", function()
        while self.running do
            task.wait(0.5)

            for _, enemy in ipairs(self.globals:GetTargetModels(self.settings.teamCheck)) do
                local head = enemy:FindFirstChild("Head")
                local humanoid = enemy:FindFirstChildOfClass("Humanoid")

                if head and humanoid and humanoid.Health > 0 then
                    if not self.originalHeadStates[head] then
                        self.originalHeadStates[head] = {
                            size = head.Size,
                            transparency = head.Transparency,
                            canCollide = head.CanCollide,
                        }
                    end

                    if self.settings.enabled then
                        head.Size = Vector3.new(self.settings.size, self.settings.size, self.settings.size)
                        head.CanCollide = false
                        head.Transparency = self.settings.transparency
                    else
                        self:_restoreHead(head)
                    end
                end
            end
        end
    end)

    return self
end

function Hitbox:_restoreHead(head)
    local state = self.originalHeadStates[head]
    if not state or not head or not head.Parent then
        return
    end

    head.Size = state.size
    head.Transparency = state.transparency
    head.CanCollide = state.canCollide
end

function Hitbox:_restoreAll()
    for head in pairs(self.originalHeadStates) do
        pcall(function()
            self:_restoreHead(head)
        end)
    end
end

function Hitbox:SetEnabled(value)
    self.settings.enabled = value == true
    if not self.settings.enabled then
        self:_restoreAll()
    end
end

function Hitbox:SetTeamCheck(value)
    self.settings.teamCheck = value == true
    if not self.settings.teamCheck and not self.settings.enabled then
        self:_restoreAll()
    end
end

function Hitbox:SetSize(value)
    local size = tonumber(value)
    if size then
        self.settings.size = math.clamp(size, 1, 5)
    end
end

function Hitbox:SetTransparency(value)
    local transparency = tonumber(value)
    if transparency then
        self.settings.transparency = math.clamp(transparency, 0, 1)
    end
end

function Hitbox:Destroy()
    self.cleaner:Cleanup()
end


-- ============================================================
-- RAPID FIRE SYSTEM
-- ============================================================

local RapidFireSystem = {}
RapidFireSystem.__index = RapidFireSystem

local function safeGet(object, key)
    if type(object) ~= "table" then
        return nil
    end
    return object[key]
end

function RapidFireSystem.new(context)
    local self = setmetatable({}, RapidFireSystem)
    self.context = context or {}
    self.flags = self.context.Flags or {}
    self.localPlayer = self.context.LocalPlayer
    self.camera = self.context.Camera
    self.modules = self.context.Modules or {}
    self.money = self.context.Money or {}
    self.remotes = self.context.Remotes or {}
    self.emptyVec3 = self.context.EmptyVec3 or Vector3.zero
    self.findFirstChild = self.context.FindFirstChild
    self.workspace = self.context.Workspace
    self.ragebot = self.context.Ragebot
    self.lastFired = 0
    self.enabled = false
    self.tickInterval = tonumber(self.flags["RapidFireTick"]) or 0.05
    self.flags["RageRapidFire"] = false
    self.flags["RapidFireTick"] = self.tickInterval
    return self
end

function RapidFireSystem:SetEnabled(value)
    self.enabled = value == true
    self.flags["RageRapidFire"] = self.enabled
end

function RapidFireSystem:SetTick(value)
    self.tickInterval = tonumber(value) or 0.05
    self.flags["RapidFireTick"] = self.tickInterval
end

function RapidFireSystem:ApplyRapidFire(weapon)
    if not weapon or not weapon.Properties then return end
    if self.flags["RageRapidFire"] then
        weapon.Properties.FireRate = tonumber(self.flags["RapidFireTick"]) or 0.05
    end
end

function RapidFireSystem:_getWeapon()
    local inventoryController = safeGet(self.modules, "InventoryController")
    if not inventoryController then
        return nil
    end

    if type(inventoryController.getCurrentEquipped) == "function" then
        local weapon = inventoryController.getCurrentEquipped()
        self:ApplyRapidFire(weapon)
        return weapon
    end

    return nil
end

function RapidFireSystem:_getFireRate(properties)
    if self.flags["RageRapidFire"] then
        return tonumber(self.flags["RapidFireTick"]) or 0.05
    end
    if properties and properties.FireRate then
        return tonumber(properties.FireRate) or 0.1
    end
    return 0.1
end

function RapidFireSystem:_buildOrigins(info)
    local origins = {}
    local camera = self.camera
    if camera and camera.CFrame then
        table.insert(origins, camera.CFrame.Position)
    end

    if self.flags["RageSelfForwardTrack"] and self.flags["RageForwardTrack"] then
        local forwardtrack = safeGet(self.ragebot, "Forwardtrack")
        if forwardtrack and type(forwardtrack.GetPosition) == "function" and self.localPlayer then
            local position = forwardtrack:GetPosition(self.localPlayer)
            if position then
                table.insert(origins, position)
            end
        end
    end

    if self.flags["RageOriginScan"] then
        local hitScan = safeGet(self.ragebot, "HitScan")
        if hitScan and type(hitScan.GetOrigins) == "function" then
            local extraOrigins = hitScan:GetOrigins()
            if type(extraOrigins) == "table" then
                for _, origin in ipairs(extraOrigins) do
                    table.insert(origins, origin)
                end
            end
        end
    end

    if self.flags["RageSelfBackTrack"] and self.flags["RageBackTrack"] then
        local backtrack = safeGet(self.ragebot, "Backtrack")
        if backtrack and type(backtrack.GetBestRecord) == "function" and self.localPlayer then
            local entry = backtrack:GetBestRecord(self.localPlayer)
            if entry and entry.CFrame then
                table.insert(origins, entry.CFrame.Position)
            end
        end
    end

    return origins
end

function RapidFireSystem:_performRaycast(weapon, origin, targetPosition, character)
    local perfRaycast = safeGet(self.ragebot, "PerfRaycast")
    if type(perfRaycast) == "function" then
        return perfRaycast(weapon, origin, targetPosition, character)
    end

    return nil, false
end

function RapidFireSystem:_buildHits(data, defaultOrigin, targetPosition)
    local hits = {}
    local oldPosition = data and data.Origin or defaultOrigin

    if data and type(data.Hits) == "table" then
        for _, hitData in ipairs(data.Hits) do
            table.insert(hits, {
                Distance = (hitData.Position - oldPosition).Magnitude,
                Instance = hitData.Instance,
                Position = hitData.Position,
                Normal = hitData.Normal,
                Material = hitData.Material,
                Exit = hitData.Exit,
            })
            oldPosition = hitData.Position
        end
    end

    table.insert(hits, {
        Distance = (oldPosition - defaultOrigin).Magnitude,
        Instance = nil,
        Position = targetPosition,
        Normal = self.emptyVec3,
        Material = "Plastic",
        Exit = false,
    })

    return hits
end

function RapidFireSystem:_sendShot(weapon, bullets)
    local shootRemote = safeGet(self.remotes, "Inventory")
    if not shootRemote then
        return false
    end

    local inventoryRemote = safeGet(shootRemote, "ShootWeapon")
    if not inventoryRemote then
        return false
    end

    if type(inventoryRemote.Send) ~= "function" then
        return false
    end

    inventoryRemote.Send({
        IsSniperScoped = weapon.IsSniperScoped,
        ShootingHand = weapon.ShootingHand,
        Identifier = weapon.Identifier,
        Capacity = weapon.Capacity,
        Bullets = {bullets},
        Rounds = weapon.Rounds,
    })

    return true
end

function RapidFireSystem:_fakeShoot(weapon, bullets, fireRate)
    local fakeShoot = safeGet(self.ragebot, "FakeShoot")
    if type(fakeShoot) == "function" then
        fakeShoot(self.ragebot, weapon, bullets, fireRate)
    end
end

function RapidFireSystem:Scan(info)
    if not self.flags["RageEnabled"] then
        return false
    end

    if not (info and info.Enemy and info.Character and info.Invincible ~= true) then
        return false
    end

    local weapon = self:_getWeapon()
    if not weapon then
        return false
    end

    local properties = weapon.Properties
    if not properties then
        return false
    end

    local fireRate = self:_getFireRate(properties)
    if (tick() - self.lastFired) < fireRate then
        return false
    end

    if not weapon.Rounds then
        return false
    end
    if weapon.Rounds <= 0 then
        return false
    end

    local camera = self.camera
    if not (camera and camera.CFrame) then
        return false
    end

    local defaultOrigin = camera.CFrame.Position
    local targetPart = self.findFirstChild and self.findFirstChild(info.Character, "Head")
    if not targetPart then
        return false
    end

    local targetPosition = targetPart.Position
    local data, hitted = nil, false
    local origins = self:_buildOrigins(info)

    for _, origin in ipairs(origins) do
        local _data, canHit = self:_performRaycast(weapon, origin, targetPosition, info.Character)
        if canHit then
            data, hitted = _data, canHit
            break
        end

        if self.flags["RageForwardTrack"] then
            local forwardtrack = safeGet(self.ragebot, "Forwardtrack")
            if forwardtrack and type(forwardtrack.GetPosition) == "function" and info.Player then
                local position = forwardtrack:GetPosition(info.Player)
                if position then
                    local _data2, canHit2 = self:_performRaycast(weapon, origin, position, info.Character)
                    if canHit2 then
                        data, hitted = _data2, canHit2
                        break
                    end
                end
            end
        end

        if self.flags["RageBackTrack"] then
            local backtrack = safeGet(self.ragebot, "Backtrack")
            if backtrack and type(backtrack.GetBestRecord) == "function" and info.Player then
                local entry = backtrack:GetBestRecord(info.Player)
                if entry and entry.CFrame then
                    local _data3, canHit3 = self:_performRaycast(weapon, origin, entry.CFrame.Position, info.Character)
                    if canHit3 then
                        data, hitted = _data3, canHit3
                        break
                    end
                end
            end
        end
    end

    if not hitted then
        return false
    end

    weapon.Rounds -= 1

    local bullets = {
        Direction = targetPosition - defaultOrigin,
        Origin = defaultOrigin,
        Hits = self:_buildHits(data, defaultOrigin, targetPosition),
    }

    if self.flags["RageForceDamage"] then
        bullets.Hits = {
            {
                Instance = targetPart,
                Position = targetPosition,
                Normal = self.emptyVec3,
                Material = "Plastic",
                Distance = (targetPosition - defaultOrigin).Magnitude,
                Exit = false,
            },
        }
    end

    self:_sendShot(weapon, bullets)

    if self.flags["RageLarpShots"] then
        self:_fakeShoot(weapon, bullets, fireRate)
    end

    self.lastFired = tick()
    return true
end

function RapidFireSystem:Think(players)
    if not self.flags["RageEnabled"] then
        return
    end

    if type(players) ~= "table" then
        return
    end

    for _, info in ipairs(players) do
        self:Scan(info)
    end
end


-- ============================================================
-- TRIGGER BOT
-- ============================================================

local TriggerBot = {}
TriggerBot.__index = TriggerBot

function TriggerBot.new(context)
    local self = setmetatable({}, TriggerBot)

    self.services = context.services
    self.globals = context.globals
    self.cleaner = context.Cleaner.new()
    self.errorHandler = context.errorHandler
    self.settings = {
        enabled = false,
        delayMs = 0,
    }
    self.running = true

    self.cleaner:Give(function()
        self.running = false
    end)

    self.errorHandler:Spawn("TriggerBot Loop", function()
        while self.running do
            task.wait(0.01)

            if self.settings.enabled and self.globals:IsAlive() then
                local camera = self.globals:GetCamera()
                if camera then
                    local viewportSize = camera.ViewportSize
                    local ray = camera:ViewportPointToRay(viewportSize.X * 0.5, viewportSize.Y * 0.5)
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude

                    local ignoreList = { camera }
                    local character = self.globals:GetPlayer().Character
                    if character then
                        ignoreList[#ignoreList + 1] = character
                    end
                    params.FilterDescendantsInstances = ignoreList

                    local result = self.services.Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
                    if result and result.Instance then
                        local model = result.Instance:FindFirstAncestorOfClass("Model")
                        local humanoid = model and model:FindFirstChildOfClass("Humanoid")

                        if model and self.globals:IsEnemyModel(model) and humanoid and humanoid.Health > 0 then
                            if self.settings.delayMs > 0 then
                                task.wait(self.settings.delayMs / 1000)
                            end

                            if mouse1press then
                                mouse1press()
                            end

                            task.wait(0.05)

                            if mouse1release then
                                mouse1release()
                            end
                        end
                    end
                end
            end
        end
    end)

    return self
end

function TriggerBot:SetEnabled(value)
    self.settings.enabled = value == true
end

function TriggerBot:SetDelayMs(value)
    self.settings.delayMs = math.max(0, tonumber(value) or 0)
end

function TriggerBot:Destroy()
    self.cleaner:Cleanup()
end


-- ============================================================
-- EXPORT ALL MODULES
-- ============================================================

return {
    Aimbot = Aimbot,
    Hitbox = Hitbox,
    RapidFireSystem = RapidFireSystem,
    TriggerBot = TriggerBot,
}
