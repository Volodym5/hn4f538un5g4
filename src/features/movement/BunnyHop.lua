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
        task.wait(0.5) -- Small delay to ensure modules are loaded
        findAndSetController()
    end))

    self.cleaner:Give(self.errorHandler:Connect(self.services.RunService.RenderStepped, "BunnyHop RenderStepped", function()
        if not self.enabled or not self.globals:IsAlive() then
            return
        end
        if not self.services.UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            return
        end

        local player = self.globals:GetPlayer()
        local character = player and player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            return
        end

        local state = humanoid:GetState()
        if state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Freefall then
            if self._jumpFunction then
                local now = tick()
                if (now - self._lastJump) < self._jumpDebounce then
                    return
                end
                self._lastJump = now
                task.spawn(function()
                    local ok, err = pcall(function()
                        self._jumpFunction(self._rawModule) -- Call with the raw module as self
                    end)
                    if not ok then
                        warn("BunnyHop: jump error:", err)
                        -- Try to refresh on failure
                        findAndSetController()
                    end
                end)
            else
                -- Try to find the controller if it's missing
                findAndSetController()
            end
        end
    end))

    return self
end

function BunnyHop:SetEnabled(value)
    self.enabled = value == true
end

function BunnyHop:Destroy()
    self.cleaner:Cleanup()
    self._jumpFunction = nil
    self._rawModule = nil
end

return BunnyHop
