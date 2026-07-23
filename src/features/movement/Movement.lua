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

local GetGenv = (getgenv and clonefunction(getgenv) or DOKASFPOAKA)
GetGenv().DOKASFPOAKA = GetGenv
local HookFunction = (hookfunction and clonefunction(hookfunction) or DOKASFPOAKA22)
GetGenv().DOKASFPOAKA22 = HookFunction
GetGenv().hookfunction = nil
GetGenv().getgenv = nil
GetGenv().raven = {}
GetGenv().raven.loaded = false

local StartTick = tick()

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))

local FindFirstChild = game.FindFirstChild
local FindFirstChildOfClass = game.FindFirstChildOfClass
local FindFirstAncestorOfClass = game.FindFirstAncestorOfClass

local GetAttribute = game.GetAttribute
local SetAttribute = game.SetAttribute
local GetPlayerFromCharacter = Players.GetPlayerFromCharacter

local IsA = game.IsA

local Heartbeat = RunService.Heartbeat
local Stepped = RunService.Stepped
local RenderStepped = RunService.RenderStepped
local PreRender = RunService.PreRender

local LocalPlayer = Players.LocalPlayer
local Identity = getthreadidentity()

local Garbage = getgc(true)
local GetBloxStrikeFunction = function(Function)
    local _Function = nil
    for Index, Value in Garbage do
        if typeof(Value) ~= "function" then continue end
        local SOURCE = debug.info(Value, "s")
        if string.find(SOURCE, "ReplicatedStorage") and string.find(SOURCE, Function) then
            _Function = Value
            break
        end
    end
    return _Function
end

local RunOnFixedThread = function(Identity, Function, ...)
	local Old = Function
	Function = function(...)
		setthreadidentity(Identity)
		return Old(...)
	end
	task.spawn(function(...)
		local Thread = coroutine.create(Function)
		coroutine.resume(Thread, ...)
	end, ...)
end

local Modules = LPH_NO_VIRTUALIZE(function()
    local Modules = {}

    for Index, Value in getloadedmodules() do
        local Ok, Module = pcall(require, Value)
        if Ok and typeof(Module) == "table" and Module then

            if Module.getWeaponKickRotation and Module.weaponKick then
                Modules["Controllers/CameraController"] = Module
                continue
            end
        
            if Module.getCurrentEquipped then
                Modules["InventoryController"] = Module
                continue
            end

            if Module.cast and Module.castThrough then
                Modules["Raycast"] = Module
                continue
            end

            if rawget(Module, "shoot") and rawget(Module, "setupRecoil") then
                Modules["WeaponController"] = Module
                continue
            end

            if Module.jump then
                Modules["Controllers/CharacterController"] = Module
                continue
            end

            if Module.getMovementVelocity then
                Modules["Viewmodel/Bobble"] = Module
                continue
            end

            if Module.TakeStamina then
                Modules["Classes/Character"] = Module
                continue
            end

        end
    end

    return Modules
end)()

local Remotes = require(ReplicatedStorage.Database.Security.Remotes)

local Money = {
    Constants = {
        WeaponSettings = {}
    },
    GetRayIgnore = GetBloxStrikeFunction("Common.GetRayIgnore")
}

for Index, Value in ReplicatedStorage.Database.Custom.Weapons:GetChildren() do
    if Value and Value:IsA("ModuleScript") then
        local IsOk, Module = pcall(require, Value)
        if IsOk then
            Money.Constants.WeaponSettings[Value.Name] = Module
        end
    end
end

-- ============================================================
-- BUNNY HOP
-- ============================================================

local BunnyHop = {}
BunnyHop.__index = BunnyHop

function BunnyHop.new(context)
    local self = setmetatable({}, BunnyHop)

    self.services = context.services
    self.globals = context.globals
    self.cleaner = context.Cleaner.new()
    self.errorHandler = context.errorHandler
    self.enabled = false

    function self:Tick()
        if not self.enabled then
            return
        end

        if not self.globals:IsAlive() then
            return
        end

        local player = self.globals:GetPlayer()
        local character = player and player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            return
        end

        if self.services.UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            local characterController = Modules["Controllers/CharacterController"]
            if characterController and characterController.jump then
                characterController.jump()
            end
        end
    end

    return self
end

function BunnyHop:SetEnabled(value)
    self.enabled = value == true
end

function BunnyHop:Destroy()
    self.cleaner:Cleanup()
end


-- ============================================================
-- MOVEMENT SPEED
-- ============================================================

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


-- ============================================================
-- EXPORT ALL MODULES
-- ============================================================

return {
    BunnyHop = BunnyHop,
    MovementSpeed = MovementSpeed,
}
