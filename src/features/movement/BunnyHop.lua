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

local BunnyHop = {}
BunnyHop.__index = BunnyHop

function BunnyHop.new(context)
    local self = setmetatable({}, BunnyHop)
    self.services = context.services
    self.globals = context.globals
    self.cleaner = context.Cleaner.new()
    self.errorHandler = context.errorHandler
    self.enabled = false
    self._lastJump = 0
    self._jumpDebounce = 0.12
    self._jumpFunction = nil
    self._rawModule = nil
    self._isJumping = false
    
    local function findAndSetController()
        for _, Value in pairs(getloadedmodules()) do
            local ok, Module = pcall(require, Value)
            if ok and typeof(Module) == "table" and Module and type(Module.jump) == "function" then
                self._rawModule = Module
                self._jumpFunction = Module.jump
                return true
            end
        end
        self._rawModule = nil
        self._jumpFunction = nil
        return false
    end

    -- Initial find
    findAndSetController()

    -- Watch for character respawn and refresh the controller
    self.cleaner:Give(self.globals:GetPlayer().CharacterAdded:Connect(function()
        task.wait(0.5)
        findAndSetController()
    end))

    self.cleaner:Give(Heartbeat:Connect(function()
        if not self.enabled or not self.globals:IsAlive() then
            return
        end
        if not UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            self._isJumping = false
            return
        end

        local player = self.globals:GetPlayer()
        local character = player and player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            return
        end

        local state = humanoid:GetState()
        
        -- Auto-jump when on ground and holding space
        if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics then
            if not self._isJumping and self._jumpFunction then
                local now = tick()
                if (now - self._lastJump) >= self._jumpDebounce then
                    self._lastJump = now
                    self._isJumping = true
                    
                    task.spawn(function()
                        local ok, err = pcall(function()
                            self._jumpFunction(self._rawModule)
                        end)
                        if not ok then
                            warn("BunnyHop: jump error:", err)
                            findAndSetController()
                        end
                    end)
                end
            end
        elseif state == Enum.HumanoidStateType.Landed then
            self._isJumping = false
        elseif state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
            self._isJumping = true
        end
    end))

    return self
end

function BunnyHop:SetEnabled(value)
    self.enabled = value == true
    if not self.enabled then
        self._isJumping = false
    end
end

function BunnyHop:Destroy()
    self.cleaner:Cleanup()
    self._jumpFunction = nil
    self._rawModule = nil
    self._isJumping = false
end

local Misc = {} do
    Misc.Movement = {} do
        function Misc.Movement:Tick()
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                Modules["Controllers/CharacterController"].jump()
            end
        end
    end
end

return BunnyHop
