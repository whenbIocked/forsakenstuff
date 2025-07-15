-- Auto-execute wrapper
if not game:IsLoaded() then
    repeat task.wait() until game:IsLoaded()
end

-- CONFIGURATION
getgenv().LoadTime = "5"              -- Delay before starting
getgenv().DiscordWebhook = ""         -- Optional: Add webhook URL
getgenv().GeneratorTime = "2.5"       -- Don't go below 2.5

-- Wait for LoadTime
task.wait(tonumber(getgenv().LoadTime))

-- SERVICES
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- GLOBALS
local GenTime = tonumber(getgenv().GeneratorTime) or 2.5
local Webhook = getgenv().DiscordWebhook
local ProfilePicture = "https://cdn.sussy.dev/bleh.jpg"

-- Disable stamina loss
pcall(function()
    local mod = require(game.ReplicatedStorage.Systems.Character.Game.Sprinting)
    mod.StaminaLossDisabled = true
end)

-- UI Notifier
local ActiveNotes = {}
local function notify(title, msg, duration, color)
    local gui = game:GetService("CoreGui"):FindFirstChild("SolaraGenUI") or Instance.new("ScreenGui", game.CoreGui)
    gui.Name = "SolaraGenUI"
    gui.ResetOnSpawn = false

    local frame = Instance.new("Frame", gui)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.Position = UDim2.new(1, -270, 1, -100 - (#ActiveNotes * 90))
    frame.Size = UDim2.new(0, 250, 0, 80)
    frame.AnchorPoint = Vector2.new(0, 1)
    frame.BorderSizePixel = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local titleLabel = Instance.new("TextLabel", frame)
    titleLabel.Text = title
    titleLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 18
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.Size = UDim2.new(1, -10, 0, 25)
    titleLabel.Position = UDim2.new(0, 10, 0, 5)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local msgLabel = Instance.new("TextLabel", frame)
    msgLabel.Text = msg
    msgLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    msgLabel.TextSize = 15
    msgLabel.BackgroundTransparency = 1
    msgLabel.Font = Enum.Font.SourceSans
    msgLabel.Size = UDim2.new(1, -10, 0, 45)
    msgLabel.Position = UDim2.new(0, 10, 0, 30)
    msgLabel.TextWrapped = true
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left

    table.insert(ActiveNotes, frame)
    task.delay(duration or 5, function()
        frame:Destroy()
        table.remove(ActiveNotes, table.find(ActiveNotes, frame))
    end)
end

-- Get Avatar
local function fetchAvatar()
    local id = LocalPlayer.UserId
    local req = request or http_request or syn.request
    local ok, res = pcall(function()
        return req({
            Url = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. id .. "&size=180x180&format=png",
            Method = "GET"
        })
    end)
    if ok and res and res.Body then
        local body = HttpService:JSONDecode(res.Body)
        if body and body.data and body.data[1] then
            ProfilePicture = body.data[1].imageUrl
        end
    end
end
if Webhook and Webhook ~= "" then fetchAvatar() end

-- Send to Discord
local function sendWebhook(title, msg, color)
    if not Webhook or Webhook == "" then return end
    local req = request or http_request or syn.request
    pcall(function()
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
end

-- Teleport to another server
local function teleportToRandomServer()
    local url = "https://games.roblox.com/v1/games/18687417158/servers/Public?sortOrder=Asc&limit=100"
    local req = request or http_request or syn.request
    local res = req({ Url = url, Method = "GET" })
    local data = HttpService:JSONDecode(res.Body)
    if data and data.data then
        for _, server in pairs(data.data) do
            if server.playing < server.maxPlayers then
                TeleportService:TeleportToPlaceInstance(18687417158, server.id, LocalPlayer)
                break
            end
        end
    end
end

-- Find all generators
local function findGenerators()
    local root = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame") and workspace.Map.Ingame:FindFirstChild("Map")
    if not root then return {} end

    local gens = {}
    for _, gen in ipairs(root:GetChildren()) do
        if gen.Name == "Generator" and gen:FindFirstChild("Progress") and gen.Progress.Value < 100 then
            local ok = true
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character and plr:DistanceFromCharacter(gen:GetPivot().Position) <= 25 then
                    ok = false break
                end
            end
            if ok then table.insert(gens, gen) end
        end
    end

    table.sort(gens, function(a, b)
        return (a:GetPivot().Position - LocalPlayer.Character:GetPivot().Position).Magnitude <
               (b:GetPivot().Position - LocalPlayer.Character:GetPivot().Position).Magnitude
    end)

    return gens
end

-- Pathfinding and walking
local function walkToGenerator(gen)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return false end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2.5,
        AgentHeight = 5,
        AgentCanJump = false,
    })

    local success, err = pcall(function()
        path:ComputeAsync(char.PrimaryPart.Position, gen:GetPivot().Position + gen:GetPivot().LookVector * 3)
    end)
    if not success or path.Status ~= Enum.PathStatus.Success then return false end

    for _, wp in pairs(path:GetWaypoints()) do
        char:FindFirstChildOfClass("Humanoid"):MoveTo(wp.Position)
        local start = tick()
        repeat RunService.Heartbeat:Wait() until (char.PrimaryPart.Position - wp.Position).Magnitude < 4 or tick() - start > 5
        if (char.PrimaryPart.Position - wp.Position).Magnitude >= 4 then return false end
    end

    return true
end

-- Generator runner
local function runGenerators()
    local gens = findGenerators()
    for _, gen in ipairs(gens) do
        if walkToGenerator(gen) then
            notify("Starting Generator", gen.Name, 3, Color3.fromRGB(0, 255, 0))
            local prompt = gen:FindFirstChild("Main") and gen.Main:FindFirstChild("Prompt")
            if prompt then fireproximityprompt(prompt); task.wait(0.5) end
            for _ = 1, 6 do
                if gen:FindFirstChild("Remotes") and gen.Progress.Value < 100 then
                    gen.Remotes.RE:FireServer()
                end
                task.wait(GenTime)
            end
        end
    end
    local balance = LocalPlayer:FindFirstChild("PlayerData") and LocalPlayer.PlayerData.Stats.Currency.Money.Value or "?"
    sendWebhook("Generators Complete", "Balance: $" .. balance, 0x00FF00)
    teleportToRandomServer()
end

-- Detect game start
workspace.Players.Survivors.ChildAdded:Connect(function(c)
    if c == LocalPlayer.Character then
        task.wait(4)
        runGenerators()
    end
end)

-- Auto-retry if you die
task.spawn(function()
    while task.wait(0.5) do
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h and h.Health == 0 then
            local money = LocalPlayer.PlayerData.Stats.Currency.Money.Value
            sendWebhook("I died!", "Balance: $" .. money, 0xFF0000)
            teleportToRandomServer()
            break
        end
    end
end)

-- Initial Notification
notify("Solara Generator Autofarm", "Loaded successfully!", 5, Color3.fromRGB(115, 194, 89))
