-- Wait for game to load (or custom LoadTime)
if getgenv and tonumber(getgenv().LoadTime) then
    task.wait(tonumber(getgenv().LoadTime))
else
    repeat task.wait() until game:IsLoaded()
end

-- Services
local VIMVIM            = game:GetService("VirtualInputManager")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local PathfindingService= game:GetService("PathfindingService")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

-- Config
local DCWebhook = (getgenv and getgenv().DiscordWebhook) or false
local GenTime   = tonumber(getgenv and getgenv().GeneratorTime) or 2.5

-- Globals
local Nnnnnnotificvationui
local AliveNotificaiotna = {}
local ProfilePicture     = ""

if DCWebhook == "" then
    DCWebhook = false
end

-- Disable stamina drain once
pcall(function()
    local sprintMod = require(game:GetService("ReplicatedStorage")
        .Systems.Character.Game.Sprinting)
    sprintMod.StaminaLossDisabled = true
end)

-- Notification UI
local function CreateNotificationUI()
    if Nnnnnnotificvationui then
        return Nnnnnnotificvationui
    end
    Nnnnnnotificvationui = Instance.new("ScreenGui")
    Nnnnnnotificvationui.Name           = "NotificationUI"
    Nnnnnnotificvationui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Nnnnnnotificvationui.Parent         = game.CoreGui
    return Nnnnnnotificvationui
end

local function MakeNotif(title, message, duration, color)
    local ui = CreateNotificationUI()
    title    = title    or "Notification"
    message  = message  or ""
    duration = duration or 5
    color    = color    or Color3.fromRGB(255,200,0)

    local frame = Instance.new("Frame", ui)
    frame.Name              = "Notification"
    frame.Size              = UDim2.new(0,250,0,80)
    frame.Position          = UDim2.new(1,50,1,10)
    frame.BackgroundColor3  = Color3.fromRGB(30,30,30)
    frame.BorderSizePixel   = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)

    local t = Instance.new("TextLabel", frame)
    t.Name               = "Title"
    t.Size               = UDim2.new(1,-25,0,25)
    t.Position           = UDim2.new(0,15,0,5)
    t.Font               = Enum.Font.SourceSansBold
    t.Text               = title
    t.TextSize           = 18
    t.TextColor3         = color
    t.BackgroundTransparency = 1
    t.TextXAlignment     = Enum.TextXAlignment.Left

    local m = Instance.new("TextLabel", frame)
    m.Name               = "Message"
    m.Size               = UDim2.new(1,-25,0,50)
    m.Position           = UDim2.new(0,15,0,30)
    m.Font               = Enum.Font.SourceSans
    m.Text               = message
    m.TextSize           = 16
    m.TextColor3         = Color3.new(1,1,1)
    m.BackgroundTransparency = 1
    m.TextXAlignment     = Enum.TextXAlignment.Left
    m.TextWrapped        = true

    local bar = Instance.new("Frame", frame)
    bar.Name             = "ColorBar"
    bar.Size             = UDim2.new(0,5,1,0)
    bar.BackgroundColor3 = color
    bar.BorderSizePixel  = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0,8)

    local offset = 0
    for _, n in ipairs(AliveNotificaiotna) do
        if n.Instance and n.Instance.Parent then
            offset = offset + n.Instance.Size.Y.Offset + 10
        end
    end

    table.insert(AliveNotificaiotna, { Instance = frame, ExpireTime = os.time()+duration })

    local tween = TweenInfo.new(0.5,Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
    game:GetService("TweenService"):Create(frame,tween,{ Position = UDim2.new(1,-270,1,-90-offset) }):Play()

    task.spawn(function()
        task.wait(duration)
        local out = TweenInfo.new(0.5,Enum.EasingStyle.Quint,Enum.EasingDirection.In)
        game:GetService("TweenService")
            :Create(frame,out,{ Position = UDim2.new(1,50,frame.Position.Y.Scale,frame.Position.Y.Offset) })
            :Play()
        frame:GetPropertyChangedSignal("Parent"):Wait()
        for i,n in ipairs(AliveNotificaiotna) do
            if n.Instance == frame then table.remove(AliveNotificaiotna,i) break end
        end
        frame:Destroy()
        -- reposition rest
        local cur = 0
        for _,n in ipairs(AliveNotificaiotna) do
            if n.Instance and n.Instance.Parent then
                game:GetService("TweenService")
                    :Create(n.Instance,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
                        { Position = UDim2.new(1,-270,1,-90-cur) })
                    :Play()
                cur = cur + n.Instance.Size.Y.Offset + 10
            end
        end
    end)

    return frame
end

-- Periodic cleanup (in case a tween didn’t fire)
task.spawn(function()
    while task.wait(1) do
        local now, dirty = os.time(), false
        for i=#AliveNotificaiotna,1,-1 do
            local n = AliveNotificaiotna[i]
            if now > n.ExpireTime or not n.Instance.Parent then
                n.Instance:Destroy()
                table.remove(AliveNotificaiotna,i)
                dirty = true
            end
        end
        if dirty then
            local cur=0
            for _,n in ipairs(AliveNotificaiotna) do
                n.Instance.Position = UDim2.new(1,-270,1,-90-cur)
                cur = cur + n.Instance.Size.Y.Offset + 10
            end
        end
    end
end)

MakeNotif("Generator Pathfinding","Loaded!",5,Color3.fromRGB(115,194,89))

-- Fixed GetProfilePicture (no User‑Agent header)
local function GetProfilePicture()
    local id  = Players.LocalPlayer.UserId
    local req = request or http_request or syn.request
    local res = req({
        Url     = ("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%d&size=180x180&format=png"):format(id),
        Method  = "GET",
        Headers = { ["Content-Type"] = "application/json" },
    })
    local ok, body = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if ok and body and body.data and body.data[1] then
        ProfilePicture = body.data[1].imageUrl
    else
        ProfilePicture = "https://cdn.sussy.dev/bleh.jpg"
    end
end

if DCWebhook then
    GetProfilePicture()
end

-- Webhook sender
local function SendWebhook(Title,Description,Color,Footer)
    if not DCWebhook then return end
    local req = request or http_request or syn.request
    pcall(function()
        req({
            Url    = DCWebhook,
            Method = "POST",
            Headers= { ["Content-Type"]="application/json" },
            Body   = HttpService:JSONEncode({
                username   = Players.LocalPlayer.DisplayName,
                avatar_url = ProfilePicture,
                embeds     = {{
                    title       = Title,
                    description = Description,
                    color       = Color or 0x00FF00,
                    footer      = { text = Footer or "" },
                }},
            }),
        })
    end)
    MakeNotif("Webhook",Title,5,Color3.fromRGB(115,194,89))
end

-- Teleport helper
local function teleportToRandomServer()
    local counter, maxR, delayR = 0,10,10
    local req = request or http_request or syn.request
    if not req then return end
    local url = "https://games.roblox.com/v1/games/18687417158/servers/Public?sortOrder=Asc&limit=100"
    while counter < maxR do
        local ok,res = pcall(function() return req({ Url=url, Method="GET", Headers={["Content-Type"]="application/json"} }) end)
        if ok and res and res.Body then
            local data = HttpService:JSONDecode(res.Body)
            if data and data.data and #data.data>0 then
                local s = data.data[math.random(#data.data)]
                if s.id then
                    MakeNotif("Teleporting","Server: "..s.id,5,Color3.fromRGB(115,194,89))
                    task.wait(.25)
                    TeleportService:TeleportToPlaceInstance(18687417158,s.id,Players.LocalPlayer)
                    return
                end
            end
        end
        counter+=1
        MakeNotif("Retrying","Attempt "..counter.."/"..maxR,5,Color3.fromRGB(255,0,0))
        task.wait(delayR)
    end
end

-- Generator finder
local function findGenerators()
    local root = workspace:FindFirstChild("Map")
    and workspace.Map:FindFirstChild("Ingame")
    and workspace.Map.Ingame:FindFirstChild("Map")
    if not root then return {} end
    local gens = {}
    for _,m in ipairs(root:GetChildren()) do
        if m.Name=="Generator" and m:FindFirstChild("Progress") and m.Progress.Value<100 then
            local pos = m:GetPivot().Position
            local ok = true
            for _,pl in ipairs(Players:GetPlayers()) do
                if pl~=Players.LocalPlayer and pl.Character and pl:DistanceFromCharacter(pos)<=25 then
                    ok=false;break
                end
            end
            if ok then table.insert(gens,m) end
        end
    end
    table.sort(gens,function(a,b)
        local c = Players.LocalPlayer.Character
        if not c then return false end
        local ra = (a:GetPivot().Position-c.PrimaryPart.Position).Magnitude
        local rb = (b:GetPivot().Position-c.PrimaryPart.Position).Magnitude
        return ra<rb
    end)
    return gens
end

-- Pathfinding
local function PathFinding(generator)
    local char = Players.LocalPlayer.Character
    if not char or not char.PrimaryPart then return false end
    local path = PathfindingService:CreatePath{AgentRadius=2.5,AgentHeight=1,AgentCanJump=false}
    local ok = pcall(function() path:ComputeAsync(char.PrimaryPart.Position, generator:GetPivot().Position+generator:GetPivot().LookVector*3) end)
    if not ok or path.Status~=Enum.PathStatus.Success then return false end
    for _,wp in ipairs(path:GetWaypoints()) do
        char:FindFirstChildOfClass("Humanoid"):MoveTo(wp.Position)
        local start = tick()
        repeat RunService.Heartbeat:Wait() until (char.PrimaryPart.Position-wp.Position).Magnitude<4 or tick()-start>5
        if (char.PrimaryPart.Position-wp.Position).Magnitude>=4 then
            return false
        end
    end
    return true
end

-- Do all generators
local function DoAllGenerators()
    for _,g in ipairs(findGenerators()) do
        if not PathFinding(g) then return end
        local prompt = g:FindFirstChild("Main") and g.Main:FindFirstChild("Prompt")
        if prompt then fireproximityprompt(prompt); task.wait(.5) end
        for i=1,6 do
            if g.Progress.Value<100 and g:FindFirstChild("Remotes") then
                g.Remotes.RE:FireServer()
            end
            task.wait(GenTime)
        end
    end
    SendWebhook("Generator Autofarm","Finished all generators!\nBalance: "..Players.LocalPlayer.PlayerData.Stats.Currency.Money.Value,0x00FF00,".gg/fartsaken")
    task.wait(1)
    teleportToRandomServer()
end

-- Start when you join round
workspace.Players.Survivors.ChildAdded:Connect(function(child)
    if child==Players.LocalPlayer.Character then
        task.wait(4)
        DoAllGenerators()
    end
end)

-- Auto‑die handler
task.spawn(function()
    while task.wait(.5) do
        local h = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h and h.Health==0 then
            SendWebhook("Generator Autofarm","I died!\nBalance: "..Players.LocalPlayer.PlayerData.Stats.Currency.Money.Value,0xFF0000,"whenblocked")
            task.wait(.5)
            teleportToRandomServer()
            break
        end
    end
end)
