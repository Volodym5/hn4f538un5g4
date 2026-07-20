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

-- 🔧 NEW: force rapid fire on manual shooting
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
        self:ApplyRapidFire(weapon) -- ✅ apply rapid fire globally
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

return RapidFireSystem
