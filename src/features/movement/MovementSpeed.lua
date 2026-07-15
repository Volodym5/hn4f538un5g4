if not LPH_OBFUSCATED then
    LPH_JIT = function(...) return ... end
    LPH_JIT_MAX = function(...) return ... end
    LPH_NO_VIRTUALIZE = function(...) return ... end
    LPH_NO_UPVALUES = function(f) return (function(...) return f(...) end) end
    LPH_ENCSTR = function(...) return ... end
    LPH_ENCNUM = function(...) return ... end
    LPH_ENCFUNC = function(func, key1, key2)
        if key1 ~= key2 then return print("LPH_ENCFUNC mismatch") end
        return func
    end
    LPH_CRASH = function() return print(debug.traceback()) end
end

local Players = cloneref(game:GetService("Players"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local RunService = cloneref(game:GetService("RunService"))

local Modules = LPH_NO_VIRTUALIZE(function()
    local modules = {}
    for _, module in ipairs(getloadedmodules()) do
        local ok, value = pcall(require, module)
        if ok and type(value) == "table" then
            if value.jump then
                modules["Controllers/CharacterController"] = value
            elseif value.TakeStamina then
                modules["Classes/Character"] = value
            end
        end
    end
    return modules
end)()

local MovementSpeed = {}
MovementSpeed.__index = MovementSpeed

function MovementSpeed.new(context)
    local self = setmetatable({}, MovementSpeed)
    self.services = context.services
    self.globals = context.globals
    self.cleaner = context.Cleaner.new()
    self.errorHandler = context.errorHandler
    self.settings = {
        enabled = false,
        speedValue = 15,
        autoJump = false,
        infiniteStamina = false,
    }
    return self
end

function MovementSpeed:Tick()
    if not self.settings.enabled then
        return
    end

    local player = self.globals:GetPlayer()
    local character = player and player.Character
    local root = character and character.PrimaryPart
    if not root then
        return
    end

    local camera = workspace.CurrentCamera
    local cframe = camera and camera.CFrame
    if not cframe then
        return
    end

    local forward = Vector3.new(cframe.LookVector.X, 0, cframe.LookVector.Z).Unit
    local right = Vector3.new(cframe.RightVector.X, 0, cframe.RightVector.Z).Unit
    local moveDirection = Vector3.new(0, 0, 0)

    local input = self.services.UserInputService
    if input:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + forward end
    if input:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - forward end
    if input:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - right end
    if input:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + right end

    local oldVelocity = root.AssemblyLinearVelocity
    if moveDirection.Magnitude > 0 then
        root.AssemblyLinearVelocity = Vector3.new(
            moveDirection.Unit.X * self.settings.speedValue,
            oldVelocity.Y,
            moveDirection.Unit.Z * self.settings.speedValue
        )
    else
        root.AssemblyLinearVelocity = Vector3.new(oldVelocity.X * 0.75, oldVelocity.Y, oldVelocity.Z * 0.75)
    end

    if self.settings.autoJump and input:IsKeyDown(Enum.KeyCode.Space) then
        local controller = Modules["Controllers/CharacterController"]
        if controller and controller.jump then
            controller.jump()
        end
    end
end

function MovementSpeed:SetEnabled(value)
    self.settings.enabled = value == true
end

function MovementSpeed:SetSpeedValue(value)
    local parsed = tonumber(value)
    if parsed then
        self.settings.speedValue = math.min(parsed, 32)
    end
end

function MovementSpeed:SetAutoJump(value)
    self.settings.autoJump = value == true
end

function MovementSpeed:SetInfiniteStamina(value)
    self.settings.infiniteStamina = value == true
end

function MovementSpeed:Destroy()
    if self.cleaner then
        self.cleaner:Cleanup()
    end
end

return MovementSpeed
