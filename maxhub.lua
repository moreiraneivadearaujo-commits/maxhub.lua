--[[
    ███╗   ███╗ █████╗ ██╗  ██╗    ██╗  ██╗██╗   ██╗██████╗
    ████╗ ████║██╔══██╗╚██╗██╔╝    ██║  ██║██║   ██║██╔══██╗
    ██╔████╔██║███████║ ╚███╔╝     ███████║██║   ██║██████╔╝
    ██║╚██╔╝██║██╔══██║ ██╔██╗     ██╔══██║██║   ██║██╔══██╗
    ██║ ╚═╝ ██║██║  ██║██╔╝ ██╗    ██║  ██║╚██████╔╝██████╔╝
    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝    ╚═╝  ╚═╝ ╚═════╝ ╚═════╝
    MAX HUB  |  Vox Seas  |  Azure UI 4.1
    Toggle: RightShift
]]

--=====================================================================
-- SERVIÇOS
--=====================================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Lighting          = game:GetService("Lighting")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local Terrain           = Workspace:FindFirstChildOfClass("Terrain")

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local HUI    = nil
pcall(function() HUI = gethui() end)

--=====================================================================
-- CONFIG / TABELAS DE CALIBRAÇÃO
--=====================================================================
local CONFIG = {
    FruitPickRadius   = 900,
    MobRadius         = 300,
    AttackRange       = 60,
    AttackDelay       = 0.22,
    SpinFruitCooldown = 7200, -- 2h, igual ao Vox Gacha
}

local ISLANDS = {
    { name = "Solmar Island",   min = 0,   max = 10  },
    { name = "Forbidden Island",min = 10,  max = 45  },
    { name = "Circus Town",     min = 45,  max = 80  },
    { name = "Golden Dunes",    min = 80,  max = 115 },
    { name = "Frost Island",    min = 115, max = 145 },
    { name = "Skull Island",    min = 145, max = 150 },
    { name = "Shark Park",      min = 150, max = 180 },
    { name = "Rustfall",        min = 180, max = 230 },
    { name = "Prison",          min = 230, max = 260 },
    { name = "Valoria",         min = 260, max = 290 },
    { name = "Windhaven",       min = 290, max = 325 },
    { name = "Neruvia",         min = 325, max = 370 },
    { name = "Marine Ford",     min = 370, max = 415 },
    { name = "Vulcan Island",   min = 415, max = 450 },
    { name = "Harbor Island",   min = 0,   max = 450 },
}

local BOSSES = {
    "Rovan, The Bandit King", "Veyrn", "Noctis", "Narmer",
    "Kael", "Zarkan", "Morvath", "Raikan", "Kaeldros", "Yeti", "Black Beard",
}

local FRUITS = {
    "Weight", "Thorn", "Elastic", "Protection", "Boom", "Haze",
    "Vulcanic", "Blaze", "Divide", "Dust", "Mirror", "Eclipse",
    "Shine", "Frozen", "Zen", "Orbit",
}

local STYLES = { "Hand-to-Hand", "Raijin Kenpo", "Fire Phantom Kick", "Ryusui Ken" }

local HAKI = { "Busoshoku", "Kenbunshoku" }

--=====================================================================
-- ESTADO
--=====================================================================
local State = {
    StoryFarm   = false,
    NormalFarm  = false,
    AutoRace    = false,
    AutoGeppo   = false,
    AutoHaki    = false,
    AutoSpin    = false,
    AutoCollect = false,
    AutoStore   = false,
    Notifier    = false,
    AutoBoss    = false,
    Ranged      = false,
    BringMob    = false,
    InfJump     = false,
    Fly         = false,
    WalkWater   = false,
    StyleFarm   = false,
    ScriptOpt   = true,
    GameOpt     = false,
    SelectedBoss  = BOSSES[1],
    SelectedIsland = ISLANDS[1].name,
    SelectedStyle = STYLES[1],
    SelectedHaki  = HAKI[1],
    PendingFruit  = nil,
    LastSpin      = 0,
    MobCache      = {},
    MobCacheAt    = 0,
    LoopTick      = 0,
}

local Connections = {}
local FlyBodyGyro, FlyBodyVel
local WaterConn

--=====================================================================
-- UTIL
--=====================================================================
local function addConn(conn)
    table.insert(Connections, conn)
    return conn
end

local function getChar()
    local c = LP.Character
    if c and c.Parent then return c end
end

local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function notify(title, content, kind, dur)
    if Azure then
        Azure:Notify({ Title = title, Content = content, Type = kind or "Info", Duration = dur or 4 })
    end
end

local function isEnemy(m)
    if not m or not m:IsA("Model") then return false end
    local h = m:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return false end
    if Players:GetPlayerFromCharacter(m) then return false end
    return m:FindFirstChild("HumanoidRootPart") ~= nil
end

local function refreshMobs()
    local now = os.clock()
    if now - State.MobCacheAt < 0.5 then return State.MobCache end
    State.MobCacheAt = now
    local hrp = getHRP()
    local list = {}
    if not hrp then State.MobCache = list return list end
    for _, m in ipairs(Workspace:GetChildren()) do
        if isEnemy(m) then
            local ok, dist = pcall(function()
                return (m.HumanoidRootPart.Position - hrp.Position).Magnitude
            end)
            if ok and dist <= CONFIG.MobRadius then
                table.insert(list, { model = m, dist = dist })
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    State.MobCache = list
    return list
end

local function nearestMob(maxRange)
    for _, entry in ipairs(refreshMobs()) do
        if entry.dist <= (maxRange or CONFIG.AttackRange) then return entry.model end
    end
end

local function tpTo(pos)
    local hrp = getHRP()
    if not hrp or not pos then return end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0))
end

local function tpToInstance(inst)
    if not inst then return end
    local base = inst:IsA("BasePart") and inst or inst:FindFirstChild("HumanoidRootPart")
    if not base then base = inst:FindFirstChildWhichIsA("BasePart", true) end
    if base then tpTo(base.Position) end
end

local function findByName(names)
    local wanted = {}
    for _, n in ipairs(names) do wanted[n:lower()] = true end
    for _, d in ipairs(Workspace:GetDescendants()) do
        if wanted[d.Name:lower()] then return d end
    end
end

local function firePromptsNear(pos, radius, filter)
    radius = radius or 25
    local hrp = getHRP()
    if not hrp then return 0 end
    local anchor = pos or hrp.Position
    local fired = 0
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local parentPart = d.Parent
            if parentPart and parentPart:IsA("BasePart") then
                local ok, dist = pcall(function()
                    return (parentPart.Position - anchor).Magnitude
                end)
                if ok and dist <= radius then
                    local nameOk = true
                    if filter then
                        nameOk = false
                        for _, f in ipairs(filter) do
                            if (d.ActionText .. d.ObjectText .. d.Name):lower():find(f:lower(), 1, true) then
                                nameOk = true break
                            end
                        end
                    end
                    if nameOk then
                        pcall(fireproximityprompt, d)
                        fired += 1
                    end
                end
            end
        end
    end
    return fired
end

local function getLevel()
    local stats = LP:FindFirstChild("leaderstats") or LP:FindFirstChild("Stats")
    if not stats then return 1 end
    for _, v in ipairs(stats:GetChildren()) do
        if v:IsA("IntValue") or v:IsA("NumberValue") then
            if v.Name:lower():find("level") or v.Name:lower():find("lvl") then
                return v.Value
            end
        end
    end
    local ls = stats:FindFirstChildWhichIsA("ValueBase")
    return ls and tonumber(ls.Value) or 1
end

local function islandForLevel(lvl)
    for _, isl in ipairs(ISLANDS) do
        if lvl >= isl.min and lvl <= isl.max then return isl.name end
    end
    return ISLANDS[#ISLANDS].name
end

local function attackOnce()
    local hum = getHum()
    local char = getChar()
    if not hum or not char then return end
    local target = nearestMob(CONFIG.AttackRange)
    if not target then return end
    local hrp = getHRP()
    if hrp then
        hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(
            target.HumanoidRootPart.Position.X, hrp.Position.Y, target.HumanoidRootPart.Position.Z))
    end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function() tool:Activate() end)
    else
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Attack) end)
    end
end

--=====================================================================
-- AZURE UI
--=====================================================================
local Azure = loadstring(game:HttpGet("https://raw.githubusercontent.com/AzureUi/Azure-Ui-Library/main/Ui.lua"))()

Azure.Theme.Accent     = Color3.fromRGB(120, 170, 255)
Azure.Theme.AccentDim  = Color3.fromRGB(60, 100, 170)

local Window = Azure:CreateWindow({
    Title     = "Max Hub  |  Vox Seas",
    Width     = 580,
    Height    = 470,
    ToggleKey = Enum.KeyCode.RightShift,
    Loading   = { Title = "Max Hub", Subtitle = "Vox Seas", Duration = 2, Steps = { "Lendo módulos", "Calibrando", "Pronto" } },
})

local TabFarm    = Window:CreateTab({ Name = "Farm" })
local TabFruit   = Window:CreateTab({ Name = "Frutas" })
local TabBoss    = Window:CreateTab({ Name = "Boss" })
local TabCombat  = Window:CreateTab({ Name = "Combate" })
local TabMove    = Window:CreateTab({ Name = "Movimento" })
local TabWorld   = Window:CreateTab({ Name = "Mundo" })
local TabOpt     = Window:CreateTab({ Name = "Otimização" })
local TabInfo    = Window:CreateTab({ Name = "Sobre" })

--=====================================================================
-- ABA: FARM
--=====================================================================
TabFarm:CreateSection("Level automático")

TabFarm:CreateToggle({
    Name = "Farm Level — Story Mode",
    Desc = "Avança o modo história, ilha por ilha, até o nível máximo",
    CurrentValue = false,
    Callback = function(v) State.StoryFarm = v end,
})

TabFarm:CreateToggle({
    Name = "Normal Farm Level (Bandit Beater)",
    Desc = "Fica na sua faixa de nível matando mobs",
    CurrentValue = false,
    Callback = function(v) State.NormalFarm = v end,
})

TabFarm:CreateDivider()
TabFarm:CreateSection("Estilos e raças")

local styleDropdown
styleDropdown = TabFarm:CreateDropdown({
    Name = "Estilo de luta",
    Options = STYLES,
    CurrentValue = STYLES[1],
    Callback = function(o) State.SelectedStyle = o end,
})

TabFarm:CreateToggle({
    Name = "Auto Fighting Style",
    Desc = "Completa as missões do estilo selecionado do início ao fim",
    CurrentValue = false,
    Callback = function(v)
        State.StyleFarm = v
        if v then notify("Max Hub", "Farmando estilo: " .. State.SelectedStyle, "Info") end
    end,
})

TabFarm:CreateToggle({
    Name = "Auto Spin Race",
    Desc = "Gira a raça no NPC de Race Spin",
    CurrentValue = false,
    Callback = function(v) State.AutoRace = v end,
})

TabFarm:CreateToggle({
    Name = "Auto Geppo (Heavenstep)",
    Desc = "Resolve o puzzle do Heavenstep Mountain",
    CurrentValue = false,
    Callback = function(v) State.AutoGeppo = v end,
})

local hakiDropdown = TabFarm:CreateDropdown({
    Name = "Haki",
    Options = HAKI,
    CurrentValue = HAKI[1],
    Callback = function(o) State.SelectedHaki = o end,
})

TabFarm:CreateToggle({
    Name = "Auto Haki",
    Desc = "Faz as missões e os puzzles do Haki selecionado",
    CurrentValue = false,
    Callback = function(v) State.AutoHaki = v end,
})

--=====================================================================
-- ABA: FRUTAS
--=====================================================================
TabFruit:CreateSection("Gacha")

TabFruit:CreateToggle({
    Name = "Auto Spin Fruit",
    Desc = "Rola o Vox Gacha a cada 2 horas",
    CurrentValue = false,
    Callback = function(v) State.AutoSpin = v end,
})

TabFruit:CreateButton({
    Name = "Forçar um spin agora",
    Callback = function()
        local npc = findByName({ "Vox Gacha", "Gacha" })
        if not npc then return notify("Frutas", "NPC do Gacha não encontrado nesta ilha", "Warning") end
        tpToInstance(npc)
        task.wait(0.6)
        firePromptsNear(nil, 20, { "spin", "gacha", "roll" })
        State.LastSpin = os.time()
        notify("Frutas", "Spin disparado", "Success")
    end,
})

TabFruit:CreateDivider()
TabFruit:CreateSection("Coleta")

TabFruit:CreateToggle({
    Name = "Auto Collect Fruit",
    Desc = "Voa até frutas spawnadas e coleta",
    CurrentValue = false,
    Callback = function(v) State.AutoCollect = v end,
})

TabFruit:CreateToggle({
    Name = "Auto Store Fruit",
    Desc = "Leva ao Banker para guardar as frutas",
    CurrentValue = false,
    Callback = function(v) State.AutoStore = v end,
})

TabFruit:CreateDivider()
TabFruit:CreateSection("Notificador")

TabFruit:CreateToggle({
    Name = "Fruit Notifier",
    Desc = "Avisa a fruta spawnada e pergunta se quer pegar (Y = pegar / N = ignorar)",
    CurrentValue = false,
    Callback = function(v)
        State.Notifier = v
        if v then notify("Notificador", "Ligado. Y pega, N ignora.", "Info") end
    end,
})

TabFruit:CreateSlider({
    Name = "Raio de varredura",
    Range = { 200, 4000 },
    Increment = 100,
    CurrentValue = CONFIG.FruitPickRadius,
    Suffix = " studs",
    Callback = function(v) CONFIG.FruitPickRadius = v end,
})

--=====================================================================
-- ABA: BOSS
--=====================================================================
TabBoss:CreateSection("Seleção")

TabBoss:CreateDropdown({
    Name = "Boss alvo",
    Options = BOSSES,
    CurrentValue = BOSSES[1],
    Callback = function(o) State.SelectedBoss = o end,
})

TabBoss:CreateToggle({
    Name = "Auto Boss",
    Desc = "Teleporta até o boss e mata em loop",
    CurrentValue = false,
    Callback = function(v)
        State.AutoBoss = v
        if v then notify("Boss", "Alvo: " .. State.SelectedBoss, "Info") end
    end,
})

TabBoss:CreateButton({
    Name = "Teleportar ao boss",
    Callback = function()
        local boss = findByName({ State.SelectedBoss, State.SelectedBoss:split(",")[1] })
        if boss then tpToInstance(boss) notify("Boss", "TP: " .. State.SelectedBoss, "Success")
        else notify("Boss", "Boss não encontrado no mapa", "Warning") end
    end,
})

TabBoss:CreateButton({
    Name = "Listar bosses visíveis",
    Callback = function()
        local found = {}
        for _, m in ipairs(Workspace:GetChildren()) do
            if isEnemy(m) and (m:FindFirstChild("Humanoid").MaxHealth or 100) > 900 then
                table.insert(found, m.Name)
            end
        end
        notify("Boss", #found > 0 and table.concat(found, ", ") or "Nenhum boss com HP alto na área", "Info", 8)
    end,
})

--=====================================================================
-- ABA: COMBATE
--=====================================================================
TabCombat:CreateSection("Ataque")

TabCombat:CreateToggle({
    Name = "Ranged Attack",
    Desc = "Ataca o mob mais próximo em alcance, virando o personagem",
    CurrentValue = false,
    Callback = function(v) State.Ranged = v end,
})

TabCombat:CreateSlider({
    Name = "Alcance do ataque",
    Range = { 20, 300 },
    Increment = 5,
    CurrentValue = CONFIG.AttackRange,
    Suffix = " studs",
    Callback = function(v) CONFIG.AttackRange = v end,
})

TabCombat:CreateSlider({
    Name = "Intervalo do ataque",
    Range = { 0.05, 1 },
    Increment = 0.01,
    CurrentValue = CONFIG.AttackDelay,
    Suffix = " s",
    Callback = function(v) CONFIG.AttackDelay = v end,
})

TabCombat:CreateDivider()

TabCombat:CreateToggle({
    Name = "Bring Mob",
    Desc = "Puxa os mobs para cima de você",
    CurrentValue = false,
    Callback = function(v) State.BringMob = v end,
})

TabCombat:CreateSlider({
    Name = "Raio do Bring Mob",
    Range = { 50, 800 },
    Increment = 25,
    CurrentValue = CONFIG.MobRadius,
    Suffix = " studs",
    Callback = function(v) CONFIG.MobRadius = v end,
})

--=====================================================================
-- ABA: MOVIMENTO
--=====================================================================
TabMove:CreateSection("Personagem")

TabMove:CreateSlider({
    Name = "Set Speed",
    Range = { 16, 500 },
    Increment = 1,
    CurrentValue = 16,
    Suffix = " ws",
    Callback = function(v)
        local h = getHum()
        if h then h.WalkSpeed = v end
    end,
})

TabMove:CreateSlider({
    Name = "Set Jump",
    Range = { 50, 500 },
    Increment = 5,
    CurrentValue = 50,
    Suffix = " jp",
    Callback = function(v)
        local h = getHum()
        if h then
            h.UseJumpPower = true
            h.JumpPower = v
        end
    end,
})

TabMove:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Callback = function(v) State.InfJump = v end,
})

TabMove:CreateToggle({
    Name = "Walk Water",
    Desc = "Anda sobre a água",
    CurrentValue = false,
    Callback = function(v) State.WalkWater = v end,
})

TabMove:CreateDivider()
TabMove:CreateSection("Voo")

TabMove:CreateToggle({
    Name = "Fly",
    Desc = "WASD para voar, Espaço sobe, Ctrl desce",
    CurrentValue = false,
    Callback = function(v) State.Fly = v end,
})

TabMove:CreateSlider({
    Name = "Velocidade do voo",
    Range = { 20, 400 },
    Increment = 5,
    CurrentValue = 90,
    Callback = function(v) State.FlySpeed = v end,
})

--=====================================================================
-- ABA: MUNDO
--=====================================================================
TabWorld:CreateSection("Teletransporte")

local islandNames = {}
for _, isl in ipairs(ISLANDS) do table.insert(islandNames, isl.name) end

TabWorld:CreateDropdown({
    Name = "Ilha",
    Options = islandNames,
    CurrentValue = islandNames[1],
    Callback = function(o) State.SelectedIsland = o end,
})

TabWorld:CreateButton({
    Name = "TP para a ilha",
    Callback = function()
        local isl = findByName({ State.SelectedIsland })
        if isl then tpToInstance(isl) notify("Mundo", "TP: " .. State.SelectedIsland, "Success")
        else notify("Mundo", "Ilha não localizada no workspace", "Warning") end
    end,
})

TabWorld:CreateButton({
    Name = "TP para o Harbor Island (hub)",
    Callback = function()
        local hub = findByName({ "Harbor Island", "Harbor" })
        if hub then tpToInstance(hub) notify("Mundo", "TP: Harbor Island", "Success")
        else notify("Mundo", "Harbor não localizado", "Warning") end
    end,
})

TabWorld:CreateDivider()
TabWorld:CreateSection("Visão")

TabWorld:CreateToggle({
    Name = "Remove Fog",
    Desc = "Remove a névoa mantendo as texturas",
    CurrentValue = false,
    Callback = function(v)
        if v then
            State._fog = Lighting.FogEnd
            Lighting.FogEnd = 1e6
            Lighting.FogStart = 1e6
        else
            Lighting.FogEnd = State._fog or 1000
            Lighting.FogStart = 0
        end
    end,
})

--=====================================================================
-- ABA: OTIMIZAÇÃO
--=====================================================================
TabOpt:CreateSection("Script")

TabOpt:CreateToggle({
    Name = "Script Optimization",
    Desc = "Reduz frequência dos loops e reutiliza cache",
    CurrentValue = true,
    Callback = function(v) State.ScriptOpt = v end,
})

TabOpt:CreateDivider()
TabOpt:CreateSection("Jogo")

TabOpt:CreateToggle({
    Name = "Game Optimization",
    Desc = "Corta partículas, sombras e efeitos sem estragar texturas",
    CurrentValue = false,
    Callback = function(v)
        State.GameOpt = v
        if v then
            pcall(function()
                Lighting.GlobalShadows = false
                Lighting.EnvironmentDiffuseScale = 0
                Lighting.EnvironmentSpecularScale = 0
                Lighting.Brightness = 2
                for _, e in ipairs(Lighting:GetChildren()) do
                    if e:IsA("PostEffect") then e.Enabled = false end
                end
                for _, d in ipairs(Workspace:GetDescendants()) do
                    if d:IsA("ParticleEmitter") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                        d.Enabled = false
                    end
                end
                if Terrain then
                    Terrain.WaterWaveSize = 0
                    Terrain.WaterWaveSpeed = 0
                    Terrain.Decoration = false
                end
            end)
            notify("Otimização", "Aplicada — texturas preservadas", "Success")
        else
            pcall(function()
                Lighting.GlobalShadows = true
                Lighting.EnvironmentDiffuseScale = 1
                Lighting.EnvironmentSpecularScale = 1
                for _, e in ipairs(Lighting:GetChildren()) do
                    if e:IsA("PostEffect") then e.Enabled = true end
                end
                for _, d in ipairs(Workspace:GetDescendants()) do
                    if d:IsA("ParticleEmitter") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                        d.Enabled = true
                    end
                end
                if Terrain then
                    Terrain.WaterWaveSize = 0.15
                    Terrain.WaterWaveSpeed = 10
                    Terrain.Decoration = true
                end
            end)
        end
    end,
})

TabOpt:CreateButton({
    Name = "Desligar tudo",
    Callback = function()
        for k, v in pairs(State) do
            if type(v) == "boolean" then State[k] = false end
        end
        notify("Max Hub", "Todos os módulos desligados", "Warning")
    end,
})

--=====================================================================
-- ABA: SOBRE
--=====================================================================
TabInfo:CreateParagraph({
    Title = "Max Hub — Vox Seas",
    Content = "Toggle da UI: RightShift.\n\nOs módulos de farm usam busca por nome e ProximityPrompt. Se o jogo renomear NPCs, edite as tabelas ISLANDS / BOSSES / FRUITS no topo do script.\n\nColeta e Bring Mob têm raio ajustável — abaixe em servidores cheios.",
})

TabInfo:CreateLabel({ Text = "Status do jogador" })
TabInfo:CreateLabel({
    Text = "—",
    Update = function()
        local h = getHum()
        return string.format("HP %d/%d  |  Nível %d  |  Mobs %d",
            h and h.Health or 0, h and h.MaxHealth or 0, getLevel(), #refreshMobs())
    end,
    UpdateRate = 1,
})

--=====================================================================
-- MÓDULOS
--=====================================================================

-- Auto Spin Race
task.spawn(function()
    while true do
        task.wait(State.ScriptOpt and 3 or 1.5)
        if State.AutoRace then
            local npc = findByName({ "Race Spin", "RaceSpin", "Race Reroll" })
            if npc then
                tpToInstance(npc)
                task.wait(0.7)
                firePromptsNear(nil, 18, { "spin", "reroll", "race" })
            end
        end
    end
end)

-- Auto Geppo / Heavenstep
task.spawn(function()
    local checkpoints = { "Heavenstep", "Checkpoint", "Mountain" }
    while true do
        task.wait(State.ScriptOpt and 2 or 1)
        if State.AutoGeppo then
            local hermit = findByName({ "Sky Hermit", "Hermit" })
            if hermit then
                tpToInstance(hermit)
                task.wait(0.6)
                firePromptsNear(nil, 20)
            end
            for _, n in ipairs(checkpoints) do
                local cp = findByName({ n })
                if cp then
                    tpToInstance(cp)
                    task.wait(0.5)
                    firePromptsNear(nil, 20)
                end
            end
        end
    end
end)

-- Auto Haki
task.spawn(function()
    while true do
        task.wait(State.ScriptOpt and 2 or 1)
        if State.AutoHaki then
            local npc = findByName({ State.SelectedHaki, "Haki Trainer", "Haki Master" })
            if npc then
                tpToInstance(npc)
                task.wait(0.7)
                firePromptsNear(nil, 22)
                for _, m in ipairs(refreshMobs()) do
                    if m.dist < 120 then
                        tpToInstance(m.model)
                        task.wait(0.25)
                        attackOnce()
                    end
                end
            end
        end
    end
end)

-- Auto Spin Fruit
task.spawn(function()
    while true do
        task.wait(2)
        if State.AutoSpin and (os.time() - State.LastSpin) >= CONFIG.SpinFruitCooldown then
            local npc = findByName({ "Vox Gacha", "Gacha" })
            if npc then
                tpToInstance(npc)
                task.wait(0.7)
                if firePromptsNear(nil, 18, { "spin", "gacha", "roll" }) > 0 then
                    State.LastSpin = os.time()
                    notify("Frutas", "Spin automático executado", "Success")
                end
            end
        end
    end
end)

-- Fruit Notifier + Auto Collect + Auto Store
local fruitPatterns = {}
for _, f in ipairs(FRUITS) do table.insert(fruitPatterns, f:lower()) end

local function scanFruits()
    local hrp = getHRP()
    if not hrp then return {} end
    local found = {}
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Model") then
            local n = d.Name:lower()
            local matched = false
            for _, p in ipairs(fruitPatterns) do
                if n:find(p, 1, true) and (n:find("fruit") or #n < 24) then matched = true break end
            end
            if matched then
                local base = d:IsA("BasePart") and d or d:FindFirstChildWhichIsA("BasePart", true)
                if base then
                    local ok, dist = pcall(function() return (base.Position - hrp.Position).Magnitude end)
                    if ok and dist <= CONFIG.FruitPickRadius then
                        table.insert(found, { inst = d, base = base, dist = dist, name = d.Name })
                    end
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.dist < b.dist end)
    return found
end

task.spawn(function()
    local known = {}
    while true do
        task.wait(State.ScriptOpt and 2.5 or 1.2)
        if State.Notifier or State.AutoCollect then
            for _, f in ipairs(scanFruits()) do
                local key = f.name .. tostring(math.floor(f.base.Position.X)) .. tostring(math.floor(f.base.Position.Z))
                if State.Notifier and not known[key] then
                    known[key] = true
                    State.PendingFruit = f
                    notify("Fruta spawnada", f.name .. " a " .. math.floor(f.dist) .. " studs — [Y] pegar / [N] ignorar", "Warning", 9)
                end
                if State.AutoCollect then
                    tpToInstance(f.base)
                    task.wait(0.35)
                    firePromptsNear(nil, 12)
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(4)
        if State.AutoStore then
            local banker = findByName({ "Banker", "Pawnbroker" })
            if banker then
                tpToInstance(banker)
                task.wait(0.7)
                firePromptsNear(nil, 18, { "store", "deposit", "bank" })
            end
        end
    end
end)

-- Auto Boss
task.spawn(function()
    while true do
        task.wait(State.ScriptOpt and 0.6 or 0.3)
        if State.AutoBoss then
            local boss = findByName({ State.SelectedBoss })
            if boss and boss:FindFirstChild("HumanoidRootPart") then
                local hrp = getHRP()
                if hrp then
                    local d = (boss.HumanoidRootPart.Position - hrp.Position).Magnitude
                    if d > 25 then tpToInstance(boss) end
                end
                attackOnce()
            end
        end
    end
end)

-- Ranged Attack
task.spawn(function()
    while true do
        task.wait(CONFIG.AttackDelay)
        if State.Ranged then attackOnce() end
    end
end)

-- Bring Mob
task.spawn(function()
    while true do
        task.wait(0.6)
        if State.BringMob then
            local hrp = getHRP()
            if hrp then
                for _, e in ipairs(refreshMobs()) do
                    local b = e.model:FindFirstChild("HumanoidRootPart")
                    if b and e.dist > 8 then
                        pcall(function()
                            b.CFrame = CFrame.new(hrp.Position + Vector3.new(
                                math.random(-6, 6), 0, math.random(-6, 6)))
                        end)
                    end
                end
            end
        end
    end
end)

-- Story Farm
task.spawn(function()
    while true do
        task.wait(State.ScriptOpt and 1.2 or 0.6)
        if State.StoryFarm then
            local target = islandForLevel(getLevel())
            local isl = findByName({ target })
            local hrp = getHRP()
            if isl and hrp then
                local base = isl:IsA("BasePart") and isl or isl:FindFirstChildWhichIsA("BasePart", true)
                if base and (base.Position - hrp.Position).Magnitude > 250 then
                    tpToInstance(isl)
                    task.wait(1.2)
                end
                firePromptsNear(nil, 30, { "quest", "accept", "defeat", "talk" })
            end
            for _ = 1, 4 do attackOnce() task.wait(0.25) end
        end
    end
end)

-- Normal Farm
task.spawn(function()
    while true do
        task.wait(State.ScriptOpt and 0.35 or 0.2)
        if State.NormalFarm then
            local target = islandForLevel(getLevel())
            local hrp = getHRP()
            if hrp and #refreshMobs() == 0 then
                local isl = findByName({ target })
                if isl then tpToInstance(isl) task.wait(1) end
            end
            attackOnce()
        end
    end
end)

-- Fighting Style Farm
task.spawn(function()
    while true do
        task.wait(1)
        if State.StyleFarm then
            local trainer = findByName({ State.SelectedStyle, "Trainer", "Master" })
            if trainer then
                local hrp = getHRP()
                if hrp and (trainer:IsA("BasePart") and trainer.Position or trainer:GetPivot().Position
                    - hrp.Position).Magnitude > 40 then
                    tpToInstance(trainer)
                    task.wait(0.8)
                end
                firePromptsNear(nil, 25, { "learn", "train", "style", "quest", "accept" })
            end
            for _ = 1, 3 do attackOnce() task.wait(0.3) end
        end
    end
end)

-- Infinite Jump
addConn(UserInputService.JumpRequest:Connect(function()
    if not State.InfJump then return end
    local h = getHum()
    if h then
        h:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

-- Walk Water
addConn(RunService.Stepped:Connect(function()
    if not State.WalkWater then return end
    local char = getChar()
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = true end
    end
    local hrp = getHRP()
    local h = getHum()
    if hrp and h then
        local ray = RaycastParams.new()
        ray.FilterDescendantsInstances = { char }
        local hit = Workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), ray)
        if hit and hit.Instance == Terrain and hit.Material == Enum.Material.Water then
            h.PlatformStand = false
            hrp.CFrame = hrp.CFrame + Vector3.new(0, 0.4, 0)
        end
    end
end))

-- Fly
addConn(RunService.RenderStepped:Connect(function()
    local char = getChar()
    local hrp = getHRP()
    if not char or not hrp then return end
    if not State.Fly then
        if FlyBodyVel then FlyBodyVel:Destroy() FlyBodyVel = nil end
        if FlyBodyGyro then FlyBodyGyro:Destroy() FlyBodyGyro = nil end
        return
    end
    local h = getHum()
    if h then h.PlatformStand = true end
    if not FlyBodyVel then
        FlyBodyVel = Instance.new("BodyVelocity")
        FlyBodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        FlyBodyVel.Velocity = Vector3.zero
        FlyBodyVel.Parent = hrp
    end
    if not FlyBodyGyro then
        FlyBodyGyro = Instance.new("BodyGyro")
        FlyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        FlyBodyGyro.P = 2000
        FlyBodyGyro.Parent = hrp
    end
    FlyBodyGyro.CFrame = Camera.CFrame
    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end
    if dir.Magnitude > 0 then dir = dir.Unit end
    FlyBodyVel.Velocity = dir * (State.FlySpeed or 90)
end))

-- Y / N do notificador
addConn(UserInputService.InputBegan:Connect(function(input, gp)
    if gp or not State.PendingFruit then return end
    local f = State.PendingFruit
    if input.KeyCode == Enum.KeyCode.Y then
        State.PendingFruit = nil
        tpToInstance(f.base)
        task.wait(0.4)
        firePromptsNear(nil, 12)
        notify("Fruta", "Indo pegar: " .. f.name, "Success")
    elseif input.KeyCode == Enum.KeyCode.N then
        State.PendingFruit = nil
        notify("Fruta", "Ignorada: " .. f.name, "Info")
    end
end))

-- Respawn
addConn(LP.CharacterAdded:Connect(function()
    task.wait(1.5)
    State.Fly = false
    FlyBodyVel, FlyBodyGyro = nil, nil
end))

notify("Max Hub", "Carregado. RightShift abre/fecha.", "Success", 5)
