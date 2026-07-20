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

-- Standalone bunnyhop logic adapted to be toggleable through the main framework.
----------------------------------------------

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

return BunnyHop
