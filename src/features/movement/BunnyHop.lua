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
    local Modules = {}

    local function makeSafeProxy(mod)
        local proxy = {}
        local mt = {}
        mt.__index = function(_, k)
            local v = mod[k]
            if type(v) == "function" then
                return function(...)
                    local args = table.pack(...)
                    if args.n >= 1 and args[1] == proxy then
                        args[1] = mod
                    end
                    local ok, res = pcall(function() return v(table.unpack(args, 1, args.n)) end)
                    if not ok then
                        warn("BunnyHop SafeProxy error:", res)
                    end
                    return res
                end
            else
                return v
            end
        end
        mt.__newindex = function()
            error("attempt to modify read-only proxy")
        end
        setmetatable(proxy, mt)
        return proxy
    end

    for _, Value in pairs(getloadedmodules()) do
        local ok, Module = pcall(require, Value)
        if ok and typeof(Module) == "table" and Module and type(Module.jump) == "function" then
            Modules["Controllers/CharacterController"] = makeSafeProxy(Module)
            break
        end
    end
    self.modules = Modules

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
            local characterController = self.modules["Controllers/CharacterController"]
            if characterController and type(characterController.jump) == "function" then
                local now = tick()
                if (now - self._lastJump) < self._jumpDebounce then
                    return
                end
                self._lastJump = now
                task.spawn(function()
                    local ok, err = pcall(function()
                        characterController.jump()
                    end)
                    if not ok then
                        warn("BunnyHop: characterController.jump error:", err)
                    end
                end)
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
end

return BunnyHop
