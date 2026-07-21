local DEFAULT_BASE_URL = "https://raw.githubusercontent.com/Volodym5/hn4f538un5g4/main"
local WHITELIST_URL = "https://raw.githubusercontent.com/Volodym5/hn4f538un5g4/main/whitelist.lua"

local function getFileName(path)
    local text = tostring(path or "")
    return text:match("([^/\\]+)$") or text
end

local function getHttpGet()
    if syn and syn.request then
        return function(url)
            local response = syn.request({ Url = url, Method = "GET" })
            return response and response.Body
        end
    end

    if http and http.request then
        return function(url)
            local response = http.request({ Url = url, Method = "GET" })
            return response and response.Body
        end
    end

    if game and game.HttpGet then
        return function(url)
            return game:HttpGet(url)
        end
    end

    error("No HTTP request function is available in this executor.")
end

local function kickOnFatal(err)
    local detailedMessage = "[Bloxtrike] Loader error: " .. tostring(err)
    local firstLine = tostring(err or ""):match("([^\r\n]+)") or tostring(err or "")
    firstLine = firstLine:gsub("[^\32-\126]", "?")
    firstLine = firstLine:gsub("%s+", " ")
    firstLine = firstLine:gsub("^%s+", ""):gsub("%s+$", "")
    if #firstLine > 120 then
        firstLine = firstLine:sub(1, 117) .. "..."
    end

    local shortMessage = "[Bloxtrike] Loader error"
    if firstLine ~= "" then
        shortMessage = shortMessage .. " | " .. firstLine
    end
    warn(detailedMessage)

    local players = game and game:GetService("Players")
    local player = players and players.LocalPlayer
    if player then
        pcall(function()
            player:Kick(shortMessage)
        end)
    end

    error(shortMessage, 0)
end

local function kickUnsupported(missing)
    local shortMessage = "[Bloxtrike] Executor doesn't support required functions"
    if type(missing) == "table" and #missing > 0 then
        shortMessage = shortMessage .. " | " .. table.concat(missing, ", ")
    end

    local players = game and game:GetService("Players")
    local player = players and players.LocalPlayer
    if player then
        pcall(function()
            player:Kick(shortMessage)
        end)
    end

    error(shortMessage, 0)
end

local function getExecutorName()
    if type(identifyexecutor) == "function" then
        local ok, name = pcall(identifyexecutor)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    if type(getexecutorname) == "function" then
        local ok, name = pcall(getexecutorname)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    return "Unknown"
end

local function kickDenied(reason)
    local message = "[Bloxtrike] Executor not whitelisted, Contact Dev for ur Executor to Whitelist"
    if type(reason) == "string" and reason ~= "" then
        message = message .. " | " .. reason
    end

    local players = game:GetService("Players")
    local player = players.LocalPlayer
    if player then
        pcall(function()
            player:Kick(message)
        end)
    end

    error(message, 0)
end

local function runExecutorWhitelist(httpGet)
    local body = httpGet(WHITELIST_URL)
    assert(type(body) == "string" and body ~= "", "Failed to fetch whitelist.lua")

    local chunk = assert(loadstring(body, "@loader/whitelist.lua"))
    local whitelist = chunk()
    assert(type(whitelist) == "table", "whitelist.lua must return a table")

    local executorName = getExecutorName()
    for _, allowedName in ipairs(whitelist) do
        if tostring(allowedName):lower() == executorName:lower() then
            return
        end
    end

    kickDenied(executorName)
end

local function collectMissingSupport()
    local missing = {}

    if type(loadstring) ~= "function" then
        missing[#missing + 1] = "loadstring"
    end

    if type(cloneref) ~= "function" then
        missing[#missing + 1] = "cloneref"
    end

    local hasHttpSupport = (syn and type(syn.request) == "function")
        or (http and type(http.request) == "function")
        or (game and type(game.HttpGet) == "function")
    if not hasHttpSupport then
        missing[#missing + 1] = "HTTP"
    end

    if not (Drawing and type(Drawing.new) == "function") then
        missing[#missing + 1] = "Drawing.new"
    end

    if type(mousemoverel) ~= "function" then
        missing[#missing + 1] = "mousemoverel"
    end

    if type(mouse1click) ~= "function" then
        missing[#missing + 1] = "mouse1click"
    end

    if type(hookfunction) ~= "function" then
        missing[#missing + 1] = "hookfunction"
    end

    if type(getgc) ~= "function" then
        missing[#missing + 1] = "getgc"
    end

    if type(isfolder) ~= "function" then
        missing[#missing + 1] = "isfolder"
    end

    if type(makefolder) ~= "function" then
        missing[#missing + 1] = "makefolder"
    end

    if type(isfile) ~= "function" then
        missing[#missing + 1] = "isfile"
    end

    if type(readfile) ~= "function" then
        missing[#missing + 1] = "readfile"
    end

    if type(writefile) ~= "function" then
        missing[#missing + 1] = "writefile"
    end

    if type(listfiles) ~= "function" then
        missing[#missing + 1] = "listfiles"
    end

    if type(delfile) ~= "function" then
        missing[#missing + 1] = "delfile"
    end

    return missing
end

assert(type(DEFAULT_BASE_URL) == "string" and DEFAULT_BASE_URL ~= "", "DEFAULT_BASE_URL must not be empty")

local missingSupport = collectMissingSupport()
if #missingSupport > 0 then
    kickUnsupported(missingSupport)
end

local httpGet = getHttpGet()
runExecutorWhitelist(httpGet)

local files = {
    "main.lua",
    "ui_lib/source.lua",
    "src/shared/Cleaner.lua",
    "src/shared/ErrorHandler.lua",
    "src/shared/Services.lua",
    "src/shared/Globals.lua",
    "src/features/combat/Aimbot.lua",
    "src/features/combat/TriggerBot.lua",
    "src/features/combat/Hitbox.lua",
    "src/features/combat/Rage.lua",
    --"src/features/combat/RapidFire.lua",
    "src/features/movement/BunnyHop.lua",
    "src/features/movement/MovementSpeed.lua",
    "src/features/skins/Skinchanger.lua",
    "src/features/visuals/ESP.lua",
    "src/features/visuals/Chams.lua",
    --"src/features/visuals/BulletTracers.lua",
    --"src/features/visuals/ParticleEffects.lua",
    "src/features/visuals/KillEffects.lua",
    "src/features/visuals/WorldEffects.lua",
}

local MAX_CONCURRENT_FETCHES = 10

local function fetchFilesInBatches(fileList, fetcher)
    local sources = {}
    local total = #fileList
    local index = 1

    local function validateBody(relativePath, body)
        local fileName = getFileName(relativePath)
        if type(body) ~= "string" or body == "" then
            return nil, "Failed to fetch: " .. fileName
        end

        local lowered = body:sub(1, 256):lower()
        if lowered:find("<!doctype html>", 1, true) then
            return nil, "Non-raw response for: " .. fileName
        end

        if lowered:find("<html", 1, true) then
            return nil, "HTML returned for: " .. fileName
        end

        if body == "404: Not Found" then
            return nil, "Missing file: " .. fileName
        end

        return body
    end

    while index <= total do
        local batch = {}
        local batchSize = 0

        while index <= total and batchSize < MAX_CONCURRENT_FETCHES do
            batchSize = batchSize + 1
            batch[batchSize] = fileList[index]
            index = index + 1
        end

        local pending = #batch
        local completed = 0
        local batchErrors = {}

        for batchIndex, relativePath in ipairs(batch) do
            local fileName = getFileName(relativePath)
            local url = DEFAULT_BASE_URL .. "/" .. relativePath

            task.spawn(function()
                local okFetch, body = pcall(function()
                    return fetcher(url)
                end)

                if not okFetch then
                    batchErrors[relativePath] = "Failed to fetch: " .. fileName
                else
                    local validatedBody, err = validateBody(relativePath, body)
                    if validatedBody then
                        sources[relativePath] = validatedBody
                    else
                        batchErrors[relativePath] = err
                    end
                end

                completed = completed + 1
            end)
        end

        while completed < pending do
            task.wait(0)
        end

        for _, relativePath in ipairs(batch) do
            if batchErrors[relativePath] then
                error(batchErrors[relativePath], 0)
            end
        end
    end

    return sources
end

local ok, result = xpcall(function()
    local sources = fetchFilesInBatches(files, httpGet)

    local mainChunk = assert(loadstring(sources["main.lua"], "@loader/main.lua"))
    return mainChunk({
        baseUrl = DEFAULT_BASE_URL,
        moduleSources = sources,
    })
end, function(err)
    if debug and debug.traceback then
        return tostring(err) .. "\n" .. debug.traceback()
    end

    return tostring(err)
end)

if not ok then
    kickOnFatal(result)
end

return result
