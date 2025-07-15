-- Auto-execute wrapper
if not game:IsLoaded() then
    repeat task.wait() until game:IsLoaded()
end

-- CONFIGURATION
getgenv().LoadTime = "5"
getgenv().DiscordWebhook = "" -- PUT YOUR FULL DISCORD WEBHOOK URL HERE
getgenv().GeneratorTime = "2.5"

-- Wait for LoadTime
task.wait(tonumber(getgenv().LoadTime) or 5)

-- SERVICES
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

-- GLOBALS
local GenTime = tonumber(getgenv().GeneratorTime) or 2.5
local Webhook = getgenv().DiscordWebhook
local ProfilePicture = "https://cdn.sussy.dev/bleh.jpg"

-- Disable stamina loss safely
pcall(function()
    local mod = require(game.ReplicatedStorage.Systems.Character.Game.Sprinting)
    mod.StaminaLossDisabled = true
end)

-- UI Notifier
local ActiveNotes = {}
local function notify(title, msg, duration, color)
    local gui = game:GetService("CoreGui"):FindFirstChild("SolaraGenUI") or Instance.new("ScreenGui")
    gui.Name = "SolaraGenUI"
    gui.ResetOnSpawn = false
    gui.Parent = game.CoreGui

    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.Position = UDim2.new(1, -270, 1, -100 - (#ActiveNotes * 90))
    frame.Size = UDim2.new(0, 250, 0, 80)
    frame.AnchorPoint = Vector2.new(0, 1)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = title
    titleLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 18
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.Size = UDim2.new(1, -10, 0, 25)
    titleLabel.Position = UDim2.new(0, 10, 0, 5)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = frame

    local msgLabel = Instance.new("TextLabel")
    msgLabel.Text = msg
    msgLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    msgLabel.TextSize = 15
    msgLabel.BackgroundTransparency = 1
    msgLabel.Font = Enum.Font.SourceSans
    msgLabel.Size = UDim2.new(1, -10, 0, 45)
    msgLabel.Position = UDim2.new(0, 10, 0, 30)
    msgLabel.TextWrapped = true
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.Parent = frame

    table.insert(ActiveNotes, frame)
    task.delay(duration or 5, function()
        frame:Destroy()
        table.remove(ActiveNotes, table.find(ActiveNotes, frame))
    end)
end

-- Get Avatar
local function fetchAvatar()
    if Webhook == "" then return end
    local id = LocalPlayer.UserId
    local req = request or http_request or (syn and syn.request)
    if not req then return end

    local success, res = pcall(function()
        return req({
            Url = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. id .. "&size=180x180&format=png",
            Method = "GET"
        })
    end)
    if success and res and res.Body then
        local body = HttpService:JSONDecode(res.Body)
        if body and body.data and body.data[1] then
            ProfilePicture = body.data[1].imageUrl
        end
    end
end
fetchAvatar()

-- Send to Discord Webhook
local function sendWebhook(title, msg, color)
    if Webhook == "" or not Webhook then return end
    local req = request or http_request or (syn and syn.request)
    if not req then return end

    local success, err = pcall(function()
        req({
            Url = Webhook,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                username = LocalPlayer.DisplayName,
                avatar_url = ProfilePicture,
                embeds = {{
                    title = title,
                    description = msg,
                    color = color or 65280,
                    footer = { text = "Solara Generator Bot" }
                }}
            })
        })
    end)

    if not success then
        notify("Webhook Error", "Failed to send Discord webhook: " .. tostring(err), 5, Color3.fromRGB(255, 0, 0))
    end
end

-- Teleport to another server
local function teleportToRandomServer()
    local url = "https://games.roblox.com/v1/games/18687417158/servers/Public?sortOrder=Asc&limit=100"
    local req = request or http_request or (syn and syn.request)
    if not req then
        notify("Teleport Error", "Http request function not found.", 4, Color3.fromRGB(255, 0, 0))
        return
    end

    local success, res = pcall(function()
        return req({ Url = url, Method = "GET" })
    end)
    if not success or not res or not res.Body then
        notify("Teleport Error", "Failed to fetch servers.", 4, Color3.fromRGB(255, 0, 0))
        return
    end

    local data = HttpService:JSONDecode(res.Body)
    if data and data.data then
        for _, server in pairs(data.data) do
            if server.playing < server.maxPlayers then
                TeleportService:TeleportToPlaceInstance(18687417158, server.id, LocalPlayer)
                return
            end
        end
    end

    notify("Teleport Error", "No available servers found.", 4, Color3.fromRGB(255, 0, 0))
end

-- Find all generators safely
local function findGenerators()
    local root = workspace:FindFirstChild("Map")
        and workspace.Map:FindFirstChild("Ingame")
        and workspace.Map.Ingame:FindFirstChild("Map")
    if not root then return {} end

    local gens = {}
    for _, gen in ipairs(root:GetChildren()) do
        if gen.Name == "Generator" and gen:FindFirstChild("Progress") and gen.Progress.Value < 100 then
            local safeToUse = true
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character and plr.Character.PrimaryPart then
                    local dist = (plr.Character.PrimaryPart.Position - gen:GetPivot().Position).Magnitude
                    if dist <= 25 then
                        safeToUse = false
                        break
                    end
                end
            end
            if safeToUse then
                table.insert(gens, gen)
            end
        end
    end

    table.sort(gens, function(a, b)
        local distA = (a:GetPivot().Position - LocalPlayer.Character.PrimaryPart.Position).Magnitude
        local distB = (b:GetPivot().Position - LocalPlayer.Character.PrimaryPart.Position).Magnitude
        return distA < distB
    end)

    return gens
end

-- Pathfinding and walking with error checks
local function walkToGenerator(gen)
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return false end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2.5,
        AgentHeight = 5,
        AgentCanJump = false,
    })

    local success, err = pcall(function()
        path:ComputeAsync(char.PrimaryPart.Position, gen:GetPivot().Position + gen:GetPivot().LookVector * 3)
    end)
    if not success or path.Status ~= Enum.PathStatus.Success then
        notify("Pathfinding Failed", err or "Unknown error", 3, Color3.fromRGB(255, 50, 50))
        return false
    end

    for _, waypoint in ipairs(path:GetWaypoints()) do
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end

        if humanoid then
            humanoid:MoveTo(waypoint.Position)
        else
            notify("Error", "Humanoid not found", 3, Color3.fromRGB(255, 0, 0))
            return false
        end

        local reached = false
        local startTime = tick()
        while tick() - startTime < 7 do
            if (char.PrimaryPart.Position - waypoint.Position).Magnitude < 4 then
                reached = true
                break
            end
            task.wait(0.1)
        end

        if not reached then
            notify("Failed to reach waypoint", "Stopping movement", 3, Color3.fromRGB(255, 0, 0))
            return false
        end
    end

    return true
end

-- Wait for generator progress to finish with timeout
local function waitForGeneratorCompletion(gen, timeout)
    timeout = timeout or 30
    local startTime = tick()
    while gen.Progress.Value < 100 do
        if tick() - startTime > timeout then
            notify("Generator Timeout", gen.Name .. " took too long to complete.", 3, Color3.fromRGB(255, 140, 0))
            return false
        end
        task.wait(0.5)
    end
    return true
end

-- Main Generator runner function
local function runGenerators()
    local gens = findGenerators()

    if #gens == 0 then
        notify("No Generators Found", "Teleporting to another server...", 4, Color3.fromRGB(255, 120, 0))
        task.wait(1)
        teleportToRandomServer()
        return
    end

    for _, gen in ipairs(gens) do
        local char = LocalPlayer.Character
        if not char or not char.PrimaryPart then
            notify("Error", "Character not ready", 3, Color3.fromRGB(255, 0, 0))
            return
        end

        if walkToGenerator(gen) then
            notify("Starting Generator", gen.Name, 3, Color3.fromRGB(0, 255, 0))

            local prompt = gen:FindFirstChild("Main") and gen.Main:FindFirstChild("Prompt")
            if prompt then
                pcall(fireproximityprompt, prompt)
                task.wait(0.5)
            end

            local remoteFired = false
            if gen:FindFirstChild("Remotes") and gen.Remotes:FindFirstChild("RE") then
                local remote = gen.Remotes.RE
                local attempts = 12
                for i = 1, attempts do
                    if gen.Progress.Value >= 100 then
                        remoteFired = true
                        break
                    end
                    pcall(remote.FireServer, remote)
                    task.wait(GenTime)
                end
            else
                notify("Warning", "No remote found for " .. gen.Name, 3, Color3.fromRGB(255, 140, 0))
            end

            -- Wait to ensure progress is done
            if not waitForGeneratorCompletion(gen, 25) then
                notify("Generator incomplete", "Moving to next generator...", 3, Color3.fromRGB(255, 140, 0))
            else
                notify("Generator Complete", gen.Name .. " completed!", 3, Color3.fromRGB(0, 255, 0))
            end

            task.wait(1)
        else
            notify("Failed to reach", gen.Name, 3, Color3.fromRGB(255, 50, 50))
        end
    end

    local money = "?"
    if LocalPlayer:FindFirstChild("PlayerData")
        and LocalPlayer.PlayerData:FindFirstChild("Stats")
        and LocalPlayer.PlayerData.Stats:FindFirstChild("Currency")
        and LocalPlayer.PlayerData.Stats.Currency:FindFirstChild("Money") then
        money = tostring(LocalPlayer.PlayerData.Stats.Currency.Money.Value)
    end

    sendWebhook("Generators Complete", "Balance: $" .. money, 0x00FF00)
    task.wait(1)
    teleportToRandomServer()
end

-- Run the autofarm when character loads
local function onCharacterAdded(char)
    task.wait(4)
    runGenerators()
end

if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

-- Auto-retry if you die
task.spawn(function()
    while task.wait(0.5) do
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health <= 0 then
            local money = "?"
            if LocalPlayer:FindFirstChild("PlayerData")
                and LocalPlayer.PlayerData:FindFirstChild("Stats")
                and LocalPlayer.PlayerData.Stats:FindFirstChild("Currency")
                and LocalPlayer.PlayerData.Stats.Currency:FindFirstChild("Money") then
                money = tostring(LocalPlayer.PlayerData.Stats.Currency.Money.Value)
            end
            sendWebhook("I died!", "Balance: $" .. money, 0xFF0000)
            task.wait(1)
            teleportToRandomServer()
            break
        end
    end
end)

-- Initial Notification
notify("Solara Generator Autofarm", "Loaded successfully!", 5, Color3.fromRGB(115, 194, 89))
