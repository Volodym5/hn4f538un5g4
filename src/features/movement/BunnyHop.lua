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
    self._isJumping = false
    self._jumpFunction = nil
    self._rawModule = nil

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
    self.cleaner:Give(LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        findAndSetController()
    end))

    self.cleaner:Give(self.errorHandler:Connect(Heartbeat, "BunnyHop Heartbeat", function()
        if not self.enabled then
            return
        end

        local character = LocalPlayer.Character
        if not character then
            return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            return
        end

        if not UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            self._isJumping = false
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
                    
                    RunOnFixedThread(Identity, function()
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

return BunnyHop
