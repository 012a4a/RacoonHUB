
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Rarities: any = (require :: any)(ReplicatedStorage.Modules.Shared.Rarities)
local SellPrices: any = (require :: any)(ReplicatedStorage.Modules.Shared.SellPrices)
local player = Players.LocalPlayer
local PREFIX = "CodexHitAura_"
local packetModule: Instance? = game:GetService("ReplicatedStorage")
for _,name in ipairs({"Networking", "ByteNet", "Packets", "GamePackets"}) do
    packetModule = packetModule and packetModule:FindFirstChild(name)
end
assert(packetModule and packetModule:IsA("ModuleScript"), "Pull A Sword GamePackets not found")
local packets = (require :: any)(packetModule)
assert(type(packets.M1) == "table" and type(packets.M1.send) == "function", "M1 attack API unavailable")

local connections: {RBXScriptConnection} = {}
local bennetListener: any = nil
local stopped = false
local window: any = nil
local uiAura: any = nil
local visualFolder = Instance.new("Folder")
visualFolder.Name = "CodexSwordReveals"
visualFolder.Parent = workspace
local dropRecords: any = {}
local ownIndex: any = {}
local espRarities: any = {}
for _,rarity in ipairs(Rarities.Order) do espRarities[rarity] = true end
local moved = false
local lastMove = 0
local moveHumanoid: Humanoid? = nil
local rotateHumanoid: Humanoid? = nil
local previousAutoRotate = true
local lastScan = 0
local lastSend = 0
local currentTarget: Model? = nil
local sent = 0
local genv = getgenv()
local previous = genv.CodexHitAura
if type(previous) == "table" and type(previous.Destroy) == "function" then
    previous.Destroy()
end

local function restoreRotation()
    if rotateHumanoid and rotateHumanoid.Parent then
        rotateHumanoid.AutoRotate = previousAutoRotate
    end
    rotateHumanoid = nil
end

local function alive(model: Model): boolean
    local hp = model:GetAttribute("Health")
    if type(hp) == "number" then return hp > 0 end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end

local function rootOf(model: Model): BasePart?
    local root = model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("CharacterRootPart")
        or model.PrimaryPart
    return root and root:IsA("BasePart") and root or nil
end

local function clearTarget()
    currentTarget = nil
    player:SetAttribute(PREFIX .. "Target", "")
    restoreRotation()
end

local function canAttack(character: Model): boolean
    local swordState = character:GetAttribute("SwordState")
    return alive(character)
        and (swordState == "Drawn" or swordState == "HoldOut")
        and character:GetAttribute("Training") ~= true
        and character:GetAttribute("Pulling") ~= true
        and character:GetAttribute("Stunned") ~= true
        and character:GetAttribute("AttackDebounce") ~= true
        and character:GetAttribute("M1Debounce") ~= true
end

local function findTarget(origin: Vector3, character: Model): Model?
    local radius = if player:GetAttribute(PREFIX .. "Move") == true then math.clamp(tonumber(player:GetAttribute(PREFIX .. "SearchRadius")) or 200, 10, 300) else math.clamp(tonumber(player:GetAttribute(PREFIX .. "Radius")) or 10, 2, 20)
    local best: Model? = nil
    local bestDistance = radius
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {character}
    rayParams.IgnoreWater = true
    local function consider(model: Model)
        if model == character or not model.Parent or not alive(model)
            or model:GetAttribute("Invulnerable") == true then return end
        local targetRoot = rootOf(model)
        if not targetRoot then return end
        local delta = targetRoot.Position - origin
        local distance = delta.Magnitude
        if distance > bestDistance or math.abs(delta.Y) > 8 then return end
        local hit = workspace:Raycast(origin, delta, rayParams)
        if player:GetAttribute(PREFIX .. "Move") ~= true and hit and not hit.Instance:IsDescendantOf(model) then return end
        best, bestDistance = model, distance
    end
    local npcs = workspace:FindFirstChild("NPCs")
    if npcs and player:GetAttribute(PREFIX .. "Mode") ~= "Players" then
        for _,npc in ipairs(npcs:GetChildren()) do
            if npc:IsA("Model") then
                local filter = player:GetAttribute(PREFIX .. "MobType")
                local mob = npc:GetAttribute("Mob") or string.gsub(npc.Name, "_%d+$", "")
                if player:GetAttribute(PREFIX .. "TroopersOnly") == true then
                    if mob == "Trooper" then consider(npc) end
                elseif filter == "All" or filter == nil or mob == filter then consider(npc) end
            end
        end
    end
    if player:GetAttribute(PREFIX .. "Players") == true and player:GetAttribute(PREFIX .. "TroopersOnly") ~= true
        and character:GetAttribute("ZoneKind") ~= "Safe" then
        for _,other in ipairs(Players:GetPlayers()) do
            if other ~= player and (not player.Team or other.Team ~= player.Team) then
                local otherCharacter = other.Character
                if otherCharacter and otherCharacter:GetAttribute("ZoneKind") ~= "Safe" then
                    consider(otherCharacter)
                end
            end
        end
    end
    return best
end

local aura: any = {}
local function destroy()
    setthreadidentity(8)
    if stopped then return end
    stopped = true
    for _,connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
    if bennetListener then
        local listeners = packets.DialogueDisplay.getListeners()
        local index = table.find(listeners, bennetListener)
        if index then table.remove(listeners, index) end
        bennetListener = nil
    end
    clearTarget()
    player:SetAttribute(PREFIX .. "Enabled", false)
    player:SetAttribute(PREFIX .. "Busy", false)
    if moveHumanoid and moveHumanoid.Parent and moveHumanoid.RootPart then moveHumanoid:MoveTo(moveHumanoid.RootPart.Position) end
    visualFolder:Destroy()
    for _,record in pairs(dropRecords) do if record.gui then record.gui:Destroy() end end
    if window then pcall(function() window:Destroy() end) end
    if genv.CodexHitAura == aura then
        genv.CodexHitAura = nil
    end
end
aura = {
    Destroy = destroy,
    FindTarget = findTarget,
}
genv.CodexHitAura = aura
player:SetAttribute(PREFIX .. "Enabled", false)
player:SetAttribute(PREFIX .. "UIReady", false)
player:SetAttribute(PREFIX .. "Players", false)
player:SetAttribute(PREFIX .. "Radius", 10)
player:SetAttribute(PREFIX .. "Target", "")
player:SetAttribute(PREFIX .. "Requests", 0)
player:SetAttribute(PREFIX .. "Error", "")
player:SetAttribute(PREFIX .. "Mode", "Mobs")
player:SetAttribute(PREFIX .. "MobType", "All")
player:SetAttribute(PREFIX .. "Move", false)
player:SetAttribute(PREFIX .. "SearchRadius", 200)
player:SetAttribute(PREFIX .. "DropESP", true)
player:SetAttribute(PREFIX .. "MissingOnly", true)
player:SetAttribute(PREFIX .. "Models", false)
player:SetAttribute(PREFIX .. "PreviewSpin", true)
player:SetAttribute(PREFIX .. "PreviewScale", 1)
player:SetAttribute(PREFIX .. "ESPDistance", 800)
player:SetAttribute(PREFIX .. "AntiKnockback", false)
player:SetAttribute(PREFIX .. "TroopersOnly", false)
player:SetAttribute(PREFIX .. "AutoBennet", false)
player:SetAttribute(PREFIX .. "ReturnAfterPull", false)

table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.F6 then
        local enabled = player:GetAttribute(PREFIX .. "Enabled") ~= true
        player:SetAttribute(PREFIX .. "Enabled", enabled)
        if not enabled then clearTarget() end
        if uiAura then uiAura:Set(enabled) end
        print("[HitAura] " .. (enabled and "ON" or "OFF"))
    elseif input.KeyCode == Enum.KeyCode.F7 then
        local includePlayers = player:GetAttribute(PREFIX .. "Players") ~= true
        player:SetAttribute(PREFIX .. "Players", includePlayers)
        clearTarget()
        print("[HitAura] Targets: " .. (includePlayers and "mobs + players" or "mobs"))
    end
end))

local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.05 then return end
    elapsed = 0
    if stopped then return end
    local ok, err = pcall(function()
        if (player:GetAttribute(PREFIX .. "Enabled") ~= true and player:GetAttribute(PREFIX .. "Move") ~= true) or player:GetAttribute(PREFIX .. "Busy") == true then
            if currentTarget or rotateHumanoid then clearTarget() end
            if moved and moveHumanoid and moveHumanoid.RootPart then moveHumanoid:MoveTo(moveHumanoid.RootPart.Position) end
            moved = false
            return
        end
        local character = player.Character
        local root = character and rootOf(character)
        if not character or not root or not alive(character)
            or character:GetAttribute("Training") == true
            or character:GetAttribute("Pulling") == true then
            clearTarget()
            return
        end
        local now = os.clock()
        if now - lastScan >= 0.10 then
            currentTarget = findTarget(root.Position, character)
            lastScan = now
            player:SetAttribute(PREFIX .. "Target", currentTarget and currentTarget.Name or "")
        end
        local target = currentTarget
        local targetRoot = target and rootOf(target)
        local radius = math.clamp(tonumber(player:GetAttribute(PREFIX .. "Radius")) or 10, 2, 20)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        moveHumanoid = humanoid
        if not target or not targetRoot or not target.Parent or not alive(target) then
            clearTarget()
            if moved and humanoid then
                humanoid:MoveTo(root.Position); moved = false
            end
            return
        end
        local distance = (targetRoot.Position - root.Position).Magnitude
        if player:GetAttribute(PREFIX .. "Move") == true and humanoid and distance > math.min(radius, 5) then
            if now - lastMove > 0.3 then
                restoreRotation()
                local direction = root.Position - targetRoot.Position
                direction = Vector3.new(direction.X, 0, direction.Z)
                local goal = targetRoot.Position + (if direction.Magnitude > 0.1 then direction.Unit * 4 else Vector3.zero)
                humanoid:MoveTo(goal)
                lastMove = now
                moved = true
            end
        elseif moved and humanoid then humanoid:MoveTo(root.Position); moved = false end
        if player:GetAttribute(PREFIX .. "Enabled") ~= true or distance > radius or not canAttack(character) then
            restoreRotation()
            return
        end
        local attackRay = RaycastParams.new()
        attackRay.FilterType = Enum.RaycastFilterType.Exclude
        attackRay.FilterDescendantsInstances = {character}
        attackRay.IgnoreWater = true
        local obstruction = workspace:Raycast(root.Position, targetRoot.Position - root.Position, attackRay)
        if obstruction and not obstruction.Instance:IsDescendantOf(target) then return end
        local flatPosition = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
        if (flatPosition - root.Position).Magnitude > 0.1 then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid ~= rotateHumanoid then
                restoreRotation()
                if humanoid then
                    rotateHumanoid = humanoid
                    previousAutoRotate = humanoid.AutoRotate
                    humanoid.AutoRotate = false
                end
            end
            root.CFrame = CFrame.lookAt(root.Position, flatPosition)
        end
        if now - lastSend >= 0.05 then
            packets.M1.send(nil)
            lastSend = now
            sent += 1
            player:SetAttribute(PREFIX .. "Requests", sent)
        end
    end)
    if not ok then
        player:SetAttribute(PREFIX .. "Enabled", false)
        player:SetAttribute(PREFIX .. "Move", false)
        if moveHumanoid and moveHumanoid.RootPart then moveHumanoid:MoveTo(moveHumanoid.RootPart.Position) end
        player:SetAttribute(PREFIX .. "Error", tostring(err))
        clearTarget()
        warn("[HitAura] Stopped: " .. tostring(err))
    end
end))
table.insert(connections, RunService.PreSimulation:Connect(function()
    if stopped or player:GetAttribute(PREFIX .. "AntiKnockback") ~= true then return end
    local character = player.Character
    local root = character and rootOf(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not root or not humanoid or not alive(character) then return end
    if character:GetAttribute("Pulling") == true or character:GetAttribute("Training") == true
        or character:GetAttribute("Sprinting") == true or character:GetAttribute("InFlight") == true then return end
    local velocity = root.AssemblyLinearVelocity
    local pushed = character:GetAttribute("Ragdoll") == true or character:GetAttribute("KnockedDown") == true
        or character:GetAttribute("KnockedOut") == true or character:GetAttribute("Stunned") == true
    local speed = math.max(humanoid.WalkSpeed, 16)
    local horizontal = Vector3.new(velocity.X,0,velocity.Z).Magnitude
    if not pushed and horizontal <= speed*1.8 then return end
    local move = humanoid.MoveDirection * speed
    for _,part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            local y = part.AssemblyLinearVelocity.Y
            part.AssemblyLinearVelocity = Vector3.new(move.X, pushed and math.min(y,0) or y, move.Z)
            part.AssemblyAngularVelocity = Vector3.zero
        end
    end
end))
local function refreshIndex()
    local raw = player:GetAttribute("SwordIndex")
    local ok, decoded = pcall(function() return HttpService:JSONDecode(type(raw) == "string" and raw or "[]") end)
    ownIndex = {}
    if ok and type(decoded) == "table" then
        for _,name in ipairs(decoded) do ownIndex[name] = true end
    end
end
refreshIndex()
table.insert(connections, player:GetAttributeChangedSignal("SwordIndex"):Connect(refreshIndex))

local function clearDrop(record)
    if record.gui then record.gui:Destroy() end
    if record.model then record.model:Destroy() end
end
local function updateDrops()
    local container = workspace:FindFirstChild("SwordDrops")
    local active: any = {}
    local character = player.Character
    local root = character and rootOf(character)
    local maxDistance = tonumber(player:GetAttribute(PREFIX .. "ESPDistance")) or 800
    local modelCount = 0
    if container then
        local ordered = container:GetChildren()
        if root then table.sort(ordered, function(a,b)
            if not a:IsA("BasePart") then return false end
            if not b:IsA("BasePart") then return true end
            return (a.Position-root.Position).Magnitude < (b.Position-root.Position).Magnitude
        end) end
        for _,drop in ipairs(ordered) do
            if not drop:IsA("BasePart") then continue end
            local name = drop:GetAttribute("SwordName")
            if type(name) ~= "string" then continue end
            active[drop] = true
            local rarity = tostring(drop:GetAttribute("Rarity") or Rarities.RarityOf(name))
            local color = Rarities.ColorOf(rarity)
            local missing = ownIndex[name] ~= true
            local distance = root and (root.Position-drop.Position).Magnitude or 0
            local show = player:GetAttribute(PREFIX .. "DropESP") == true
                and espRarities[rarity] == true and distance <= maxDistance
                and (player:GetAttribute(PREFIX .. "MissingOnly") ~= true or missing)
            local record = dropRecords[drop]
            if record and record.name ~= name then clearDrop(record); dropRecords[drop] = nil; record = nil end
            if not record then
                local gui = Instance.new("BillboardGui")
                gui.Name = "CodexSwordName"
                gui.Adornee = drop
                gui.Size = UDim2.fromOffset(300, 70)
                gui.StudsOffset = Vector3.new(0, 4, 0)
                gui.AlwaysOnTop = true
                gui.ResetOnSpawn = false
                gui.Parent = player.PlayerGui
                local label = Instance.new("TextLabel")
                label.Size = UDim2.fromScale(1, 1)
                label.BackgroundTransparency = 0.18
                label.BackgroundColor3 = Color3.fromRGB(12, 17, 27)
                label.Font = Enum.Font.GothamBold
                label.TextSize = 15
                label.TextStrokeTransparency = 0.6
                label.RichText = true
                label.Parent = gui
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 8)
                corner.Parent = label
                local stroke = Instance.new("UIStroke")
                stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                stroke.Thickness = 1.3
                stroke.Transparency = 0.2
                stroke.Parent = label
                record = {gui = gui, label = label, stroke = stroke, name = name}
                dropRecords[drop] = record
            end
            local escaped = name:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
            local scale = tonumber(drop:GetAttribute("Scale") or drop:GetAttribute("SwordScale")) or 1
            record.gui.Enabled = show
            record.gui.MaxDistance = maxDistance
            record.label.TextColor3 = color
            record.stroke.Color = color
            record.label.Text = escaped .. "  •  " .. Rarities.DisplayName(rarity)
                .. '\n<font color="#CBD5E1" size="12">' .. (missing and "Missing index" or "Collected")
                .. "  •  " .. tostring(math.floor(distance)) .. " studs  •  ×" .. string.format("%.2f",scale) .. "</font>"
            local models = show and player:GetAttribute(PREFIX .. "Models") == true and distance <= 300 and modelCount < 30
            if models then modelCount += 1 end
            local previewScale = tonumber(player:GetAttribute(PREFIX .. "PreviewScale")) or 1
            if record.model and record.previewScale ~= previewScale then record.model:Destroy(); record.model = nil end
            if models and not record.model then
                local asset = Rarities.FindSwordModel(name)
                if asset then
                    local model = asset:Clone()
                    for _,part in ipairs(model:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.Anchored = true; part.CanCollide = false
                            part.CanTouch = false; part.CanQuery = false
                        elseif part:IsA("LuaSourceContainer") or part:IsA("BillboardGui") or part:IsA("ProximityPrompt")
                            or part:IsA("ParticleEmitter") or part:IsA("Trail") or part:IsA("Beam") then part:Destroy() end
                    end
                    local boxCF, boxSize = model:GetBoundingBox()
                    local extent = math.max(boxSize.X, boxSize.Y, boxSize.Z, 0.1)
                    model:ScaleTo(model:GetScale() * 6 * previewScale / extent)
                    boxCF, boxSize = model:GetBoundingBox()
                    local rotation = CFrame.identity
                    if boxSize.Z > boxSize.Y and boxSize.Z > boxSize.X then rotation = CFrame.Angles(math.pi/2,0,0)
                    elseif boxSize.X > boxSize.Y then rotation = CFrame.Angles(0,0,math.pi/2) end
                    record.poseOffset = rotation * model:GetPivot():ToObjectSpace(boxCF):Inverse()
                    model.Name = name .. "_Preview"
                    model.Parent = visualFolder
                    local highlight = Instance.new("Highlight")
                    highlight.Adornee = model
                    highlight.FillColor = color; highlight.OutlineColor = color
                    highlight.FillTransparency = 0.93; highlight.OutlineTransparency = 0.12
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Parent = model
                    record.model = model
                    record.previewScale = previewScale
                end
            elseif not models and record.model then record.model:Destroy(); record.model = nil end
            record.gui.StudsOffset = Vector3.new(0, record.model and (5+3*previewScale) or 4, 0)
        end
    end
    for drop,record in pairs(dropRecords) do
        if not active[drop] then clearDrop(record); dropRecords[drop] = nil end
    end
end
table.insert(connections, RunService.RenderStepped:Connect(function()
    if stopped then return end
    local spin = player:GetAttribute(PREFIX .. "PreviewSpin") == true
    local now = os.clock()
    for drop,record in pairs(dropRecords) do
        if record.model and drop.Parent then
            local yaw = spin and now*0.5 or 0
            local lift = 1 + 3*(record.previewScale or 1)
            record.model:PivotTo(CFrame.new(drop.Position + Vector3.new(0,lift+math.sin(now*1.5)*0.12,0))
                * CFrame.Angles(0,yaw,0) * record.poseOffset)
        end
    end
end))
aura.UpdateDrops = updateDrops
aura.IsMissing = function(name) return ownIndex[name] ~= true end

if type(STATE) == "table" and type(STATE.onCleanup) == "function" then
    STATE.onCleanup(destroy)
end
local automation: any = {phase = "Idle", since = 0, lastPrompt = 0, lastPull = 0, candidate = nil, returnCF = nil}
local function decodeAttribute(name)
    local raw = player:GetAttribute(name)
    if type(raw) ~= "string" then return nil end
    local ok, value = pcall(HttpService.JSONDecode, HttpService, raw)
    return ok and type(value) == "table" and value or nil
end
local function saleAllowed(name: string): boolean
    if type(name) ~= "string" or name == "" then return false end
    local locks = decodeAttribute("LockedSwords")
    if not locks or name == player:GetAttribute("EquippedSword") then return false end
    for _,locked in ipairs(locks) do if locked == name then return false end end
    return true
end
local function saleCandidates()
    local out = {}
    local inventory = decodeAttribute("Inventory")
    local hotbar = decodeAttribute("Swords")
    if not inventory or not hotbar then return out end
    for index,item in ipairs(inventory) do
        if type(item) == "table" and type(item.Name) == "string" and saleAllowed(item.Name) then
            table.insert(out, {name = item.Name, source = "Inventory", index = index})
        end
    end
    for index,name in ipairs(hotbar) do
        if type(name) == "string" and saleAllowed(name) then
            table.insert(out, {name = name, source = "Hotbar", index = index})
        end
    end
    return out
end
local function ownRock()
    local map = workspace:FindFirstChild("Map")
    local plots = map and map:FindFirstChild("Plots")
    local plot = plots and plots:FindFirstChild(tostring(player:GetAttribute("Plot") or ""))
    local rock = plot and plot:FindFirstChild("RevealRock")
    local prompt = rock and rock:FindFirstChild("RockPrompt", true)
    return rock, prompt
end
local function promptPosition(prompt: ProximityPrompt): Vector3?
    local parent = prompt.Parent
    if parent and parent:IsA("BasePart") then return parent.Position end
    if parent and parent:IsA("Attachment") then return parent.WorldPosition end
    return nil
end
local function setPhase(phase)
    if automation.phase ~= phase then automation.since = os.clock() end
    automation.phase = phase
    player:SetAttribute(PREFIX .. "AutomationStatus", phase)
    player:SetAttribute(PREFIX .. "Busy", phase ~= "Idle" and phase ~= "Waiting for eligible swords")
end
local function relocate(root: BasePart, destination: Vector3)
    restoreRotation()
    if moveHumanoid then moveHumanoid:MoveTo(root.Position) end
    root.CFrame = CFrame.lookAt(destination + Vector3.new(0, 0, 4), destination)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end
local function endSale(root)
    if automation.returnCF and root then
        root.CFrame = automation.returnCF
        root.AssemblyLinearVelocity = Vector3.zero
    end
    automation.returnCF = nil
    automation.candidate = nil
    setPhase("Idle")
end
local lastAutomation = 0
local function automationStep()
    local now = os.clock()
    if now - lastAutomation < 0.01 then return end
    lastAutomation = now
    local character = player.Character
    local root = character and rootOf(character)
    if not character or not root or not alive(character) then return end
    local carrying = character:GetAttribute("CarryingSword")
    local pulling = character:GetAttribute("Pulling") == true
    local ownedRock, ownedPrompt = ownRock()
    local waitingSword = ownedRock and ownedRock:GetAttribute("SwordName")
    if player:GetAttribute(PREFIX .. "AutoPull") == true and ((type(carrying) == "string" and carrying ~= "") or pulling or (type(waitingSword) == "string" and waitingSword ~= "") or automation.phase == "Starting pull") then
        if automation.candidate then endSale(root) end
        local rock, prompt = ownedRock, ownedPrompt
        if not rock or not prompt or not prompt:IsA("ProximityPrompt") then
            player:SetAttribute(PREFIX .. "AutomationStatus", "Your reveal rock is unavailable")
            return
        end
        if pulling then
            automation.sawPulling = true
            if tostring(automation.phase) ~= "Pulling sword" then setPhase("Pulling sword") end
            if now - automation.lastPull >= 0.07 then
                packets.Pull.send(nil)
                automation.lastPull = now
            end
            return
        end
        local onRock = rock:GetAttribute("SwordName")
        if automation.phase == "Starting pull" and type(onRock) == "string" and onRock ~= "" then
            if now - automation.since > 15 then
                player:SetAttribute(PREFIX .. "AutoPull", false)
                setPhase("Idle")
                player:SetAttribute(PREFIX .. "AutomationStatus", "Pull did not start; check your reveal rock")
            end
        elseif (type(carrying) == "string" and carrying ~= "") or (type(onRock) == "string" and onRock ~= "") then
            if automation.phase ~= "Starting pull" then
                local position = promptPosition(prompt)
                if not position then return end
                automation.pullOrigin = root.CFrame
                automation.pullCharacter = character
                relocate(root, position)
                automation.lastSword = type(carrying) == "string" and carrying ~= "" and carrying or onRock
                player:SetAttribute(PREFIX .. "LastAutoPullSword", carrying)
                setPhase("Starting pull")
                automation.lastPrompt = 0
                automation.lastPull = 0
            end
        else setPhase("Idle"); return end
        if now - automation.since > 15 then
            player:SetAttribute(PREFIX .. "AutoPull", false)
            setPhase("Idle")
            player:SetAttribute(PREFIX .. "AutomationStatus", "Pull did not start; auto-pull stopped")
            return
        end
        if now - automation.lastPrompt >= 0.2 then
            local pos = promptPosition(prompt)
            if pos and prompt.Enabled and (root.Position - pos).Magnitude <= math.max(prompt.MaxActivationDistance, 8) then fireproximityprompt(prompt) end
            automation.lastPrompt = now
        end
        return
    end
    if automation.phase == "Pulling sword" or automation.phase == "Starting pull" then
        local rock = ownRock()
        if rock and rock:GetAttribute("RevealedSword") == automation.lastSword then
            automation.pulled = (automation.pulled or 0) + 1
            player:SetAttribute(PREFIX .. "CompletedAutoPulls", automation.pulled)
            if player:GetAttribute(PREFIX .. "ReturnAfterPull") == true
                and automation.pullOrigin and automation.pullCharacter == character and automation.sawPulling then
                root.CFrame = automation.pullOrigin
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
        end
        automation.pullOrigin = nil
        automation.pullCharacter = nil
        automation.sawPulling = nil
        setPhase("Idle")
    end
    if player:GetAttribute(PREFIX .. "AutoSell") ~= true then
        if automation.candidate then endSale(root) end
        return
    end
    if pulling or (type(carrying) == "string" and carrying ~= "") or character:GetAttribute("Training") == true then return end
    if not automation.candidate then
        if now - automation.since < 0.25 then return end
        local candidate = saleCandidates()[1]
        if not candidate then setPhase("Waiting for eligible swords"); return end
        automation.candidate = candidate
        automation.returnCF = root.CFrame
        automation.fingerprint = tostring(player:GetAttribute("Inventory")) .. tostring(player:GetAttribute("Swords"))
        setPhase("Selecting " .. candidate.name)
        local heldKey = candidate.source == "Inventory" and "HeldInventory" or "HeldSlot"
        if character:GetAttribute("HeldSword") ~= candidate.name or character:GetAttribute(heldKey) ~= candidate.index then
            if candidate.source == "Inventory" then
                packets.InventoryAction.send({Action = "Hold", Index = candidate.index, Slot = 0})
            else packets.SelectSlot.send({Slot = candidate.index}) end
        end
        return
    end
    local candidate = automation.candidate
    if automation.phase == "Waiting for sale" then
        local fingerprint = tostring(player:GetAttribute("Inventory")) .. tostring(player:GetAttribute("Swords"))
        if fingerprint ~= automation.fingerprint then
            automation.sold = (automation.sold or 0) + 1
            endSale(root)
            return
        end
    end
    local records = decodeAttribute(candidate.source == "Inventory" and "Inventory" or "Swords")
    local item = records and records[candidate.index]
    local actualName = type(item) == "table" and item.Name or item
    if not saleAllowed(candidate.name) or actualName ~= candidate.name then endSale(root); return end
    if automation.phase == "Waiting for sale" then
        local fingerprint = tostring(player:GetAttribute("Inventory")) .. tostring(player:GetAttribute("Swords"))
        if fingerprint ~= automation.fingerprint then
            automation.sold = (automation.sold or 0) + 1
            endSale(root)
        elseif now - automation.since > 4 then
            player:SetAttribute(PREFIX .. "AutoSell", false)
            endSale(root)
            player:SetAttribute(PREFIX .. "AutomationStatus", "Sale not confirmed; auto-sell stopped")
        end
        return
    end
    local heldIndex = character:GetAttribute(candidate.source == "Inventory" and "HeldInventory" or "HeldSlot")
    if character:GetAttribute("HeldSword") ~= candidate.name or heldIndex ~= candidate.index then
        if now - automation.since > 3 then endSale(root) end
        return
    end
    local validName, _, blocked = SellPrices.HeldSale(player, character)
    if validName ~= candidate.name then
        player:SetAttribute(PREFIX .. "AutomationStatus", blocked or "Sword is not sellable")
        endSale(root)
        return
    end
    local map = workspace:FindFirstChild("Map")
    local sell = map and map:FindFirstChild("Sell")
    local stand = sell and sell:FindFirstChild("Stand")
    local part = stand and stand:FindFirstChild("SellThisItem")
    local prompt = part and part:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then endSale(root); return end
    if saleAllowed(candidate.name) then
        local position = promptPosition(prompt)
        if not position then endSale(root); return end
        if automation.phase ~= "At sell stand" then
            relocate(root, position)
            setPhase("At sell stand")
            return
        end
        if now - automation.since >= 0.15 and (root.Position - position).Magnitude <= 12
            and saleAllowed(candidate.name) and character:GetAttribute("HeldSword") == candidate.name then
            fireproximityprompt(prompt)
            setPhase("Waiting for sale")
        end
    end
end
aura.SaleAllowed = saleAllowed
aura.SaleCandidates = saleCandidates
local bennetPending: any = nil
local bennetSessionUntil = 0
local bennetLastPrompt = -math.huge
local bennetLastAnswer = -math.huge
local function rewardAnswer(answers)
    if type(answers) ~= "table" then return nil end
    for index, text in ipairs(answers) do
        if type(text) == "string" then
            local lower = string.lower(text)
            local reward = string.find(lower, "reward", 1, true) or string.find(lower, "claim", 1, true) or string.find(lower, "collect", 1, true)
            local blocked = string.find(lower, "buy", 1, true) or string.find(lower, "robux", 1, true)
                or string.find(lower, "not", 1, true) or string.find(lower, "later", 1, true) or string.find(lower, "how", 1, true)
            if reward and not blocked and index <= 255 then return index end
        end
    end
    return nil
end
aura.RewardAnswer = rewardAnswer
bennetListener = function(data)
    if stopped or player:GetAttribute(PREFIX .. "AutoBennet") ~= true or os.clock() > bennetSessionUntil then return end
    if type(data) ~= "table" or not string.find(string.lower(tostring(data.Speaker)), "bennet", 1, true) then return end
    local ok, answers = pcall(HttpService.JSONDecode, HttpService, data.Answers or "[]")
    local index = ok and rewardAnswer(answers)
    bennetPending = index and {index = index, received = os.clock()} or nil
end
packets.DialogueDisplay.listen(bennetListener)
local function bennetStep()
    if player:GetAttribute(PREFIX .. "AutoBennet") ~= true or (tonumber(player:GetAttribute("BennetProgress")) or 0) < 100 then
        bennetPending = nil
        bennetSessionUntil = 0
        return
    end
    local character = player.Character
    local root = character and rootOf(character)
    if not character or not root or not alive(character) or character:GetAttribute("Pulling") == true
        or character:GetAttribute("Training") == true or player:GetAttribute(PREFIX .. "Busy") == true then return end
    local folder = workspace:FindFirstChild("ForBennetEvent")
    local model = folder and folder:FindFirstChild("Master Bennet")
    local prompt = model and model:FindFirstChild("TalkPrompt", true)
    if not prompt or not prompt:IsA("ProximityPrompt") then return end
    local position = promptPosition(prompt)
    if not position or (root.Position - position).Magnitude > 10 then return end
    local now = os.clock()
    if bennetPending then
        local gui = player.PlayerGui:FindFirstChild("Dialogue")
        local container = gui and gui:FindFirstChild("Container")
        local answers = container and container:FindFirstChild("AnswerContainer")
        local answer = answers and answers:FindFirstChild("Answer" .. tostring(bennetPending.index))
        if gui and gui:IsA("ScreenGui") and gui.Enabled and answer and answer:IsA("GuiObject") and answer.Visible
            and now - bennetPending.received >= 0.5 and now - bennetLastAnswer >= 5 then
            packets.DialogueAnswer.send({Index = bennetPending.index})
            bennetLastAnswer = now
            bennetPending = nil
            bennetLastPrompt = now
        elseif now - bennetPending.received > 15 then
            bennetPending = nil
        end
        return
    end
    if now - bennetLastPrompt >= 8 and now - bennetLastAnswer >= 8 and prompt.Enabled then
        bennetLastPrompt = now
        bennetSessionUntil = now + 15
        fireproximityprompt(prompt)
    end
end
local bennetElapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
    bennetElapsed += dt
    if stopped or bennetElapsed < 0.25 then return end
    bennetElapsed = 0
    local ok, err = pcall(bennetStep)
    if not ok then player:SetAttribute(PREFIX .. "Error", tostring(err)) end
end))
aura.BennetStep = bennetStep

aura.Automation = automation
aura.AutomationStep = automationStep
aura.OwnRock = ownRock
player:SetAttribute(PREFIX .. "AutoPull", true)
player:SetAttribute(PREFIX .. "AutoSell", false)
player:SetAttribute(PREFIX .. "Busy", false)
player:SetAttribute(PREFIX .. "AutomationStatus", "Idle")
table.insert(connections, player.CharacterAdded:Connect(function()
    automation.candidate = nil
    automation.returnCF = nil
    automation.pullOrigin = nil
    automation.pullCharacter = nil
    automation.sawPulling = nil
    setPhase("Idle")
end))
table.insert(connections, RunService.Heartbeat:Connect(function()
    if stopped then return end
    local ok, err = pcall(automationStep)
    if not ok then
        player:SetAttribute(PREFIX .. "AutoPull", false)
        player:SetAttribute(PREFIX .. "AutoSell", false)
        player:SetAttribute(PREFIX .. "Busy", false)
        player:SetAttribute(PREFIX .. "AutomationStatus", tostring(err))
    end
end))

local iconPath = "CodexPullASword/racoon-hub.jpg"
if not isfile(iconPath) then
    makefolder("CodexPullASword")
    writefile(iconPath, game:HttpGet("https://raw.githubusercontent.com/012a4a/RacoonHUB/main/racoon-hub.jpg"))
end
local menuIcon = getcustomasset(iconPath)
local WindUI: any = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
WindUI:AddTheme({
    Name = "SwordStudio", Accent = Color3.fromRGB(22, 28, 46),
    Background = Color3.fromRGB(10, 14, 24), Dialog = Color3.fromRGB(17, 23, 38),
    Text = Color3.fromRGB(232, 240, 255), Placeholder = Color3.fromRGB(125, 142, 167),
    Primary = Color3.fromRGB(100, 166, 255), Toggle = Color3.fromRGB(95, 220, 176),
    Slider = Color3.fromRGB(100, 166, 255), Checkbox = Color3.fromRGB(100, 166, 255),
    Button = Color3.fromRGB(29, 41, 63), Icon = Color3.fromRGB(140, 176, 225),
    Outline = Color3.fromRGB(124, 158, 204), ElementBackground = Color3.fromRGB(27, 36, 56),
    ElementBackgroundTransparency = 0.15, PanelBackground = Color3.fromRGB(35, 49, 75),
    PanelBackgroundTransparency = 0.85,
})
window = WindUI:CreateWindow({
    Title = "RacoonHUB", Author = "",
    NewElements = true, Topbar = {Height = 58, ButtonsType = "Mac"},
    Folder = "CodexPullASword", Size = UDim2.fromOffset(760, 560),
    Theme = "SwordStudio", SideBarWidth = 180, Resizable = true,
    Icon = "swords", IgnoreAlerts = true,
    OpenButton = {Icon = menuIcon, OnlyIcon = true, OnlyMobile = false, Enabled = true,
        Draggable = false, Scale = 1, CornerRadius = UDim.new(0, 10),
        Color = ColorSequence.new(Color3.fromRGB(100,166,255), Color3.fromRGB(95,220,176))},
})
local function configureMenuIcon(targetWindow)
    local opener = targetWindow.OpenButtonMain
    local button = opener.Button
    local container = button.Parent
    local saved = player:GetAttribute(PREFIX .. "IconPosition")
    container.Position = typeof(saved) == "Vector2" and UDim2.fromOffset(saved.X, saved.Y) or UDim2.fromOffset(160, 170)
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    button.BackgroundTransparency = 1
    button.AutomaticSize = Enum.AutomaticSize.None
    button.Size = UDim2.fromOffset(48, 48)
    local scale = button:FindFirstChildOfClass("UIScale")
    if scale then scale.Scale = 1 end
    local stroke = button:FindFirstChildOfClass("UIStroke")
    if stroke then stroke.Enabled = false end
    for _,child in ipairs(button:GetChildren()) do
        if child:IsA("Frame") then child.Visible = false end
        if child:IsA("UIPadding") then
            child.PaddingLeft = UDim.new(0, 0); child.PaddingRight = UDim.new(0, 0)
            child.PaddingTop = UDim.new(0, 0); child.PaddingBottom = UDim.new(0, 0)
        end
    end
    local oldClick = button.TextButton
    local click = oldClick:Clone()
    oldClick:Destroy()
    click.Parent = button
    click.ZIndex = 1001
    button.ZIndex = 1000
    container.ZIndex = 999
    click.AutomaticSize = Enum.AutomaticSize.None
    click.Size = UDim2.fromScale(1, 1)
    click.BackgroundTransparency = 1
    for _,child in ipairs(click:GetChildren()) do
        if child:IsA("TextLabel") then child.Visible = false end
        if child:IsA("UIPadding") then
            child.PaddingLeft = UDim.new(0, 0); child.PaddingRight = UDim.new(0, 0)
            child.PaddingTop = UDim.new(0, 0); child.PaddingBottom = UDim.new(0, 0)
        end
        if child:IsA("Frame") then child.Size = UDim2.fromScale(1, 1) end
    end
    opener.Visible = function(_, _requestedVisibility)
        if container.Parent and not targetWindow.Destroyed then container.Visible = true end
    end
    container.Visible = true
    local dragInput: InputObject? = nil
    local dragStart = Vector2.zero
    local startPosition = container.Position
    local didDrag = false
    local suppressClickUntil = 0
    click.Active = true
    table.insert(connections, click.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragInput = input
        dragStart = Vector2.new(input.Position.X, input.Position.Y)
        startPosition = container.Position
        didDrag = false
    end))
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if not dragInput then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input ~= dragInput then return end
        local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
        if delta.Magnitude > 6 then didDrag = true end
        if didDrag then
            local camera = workspace.CurrentCamera
            local size = camera and camera.ViewportSize or Vector2.new(1920, 1080)
            container.Position = UDim2.fromOffset(math.clamp(startPosition.X.Offset + delta.X, 28, math.max(28, size.X - 28)),
                math.clamp(startPosition.Y.Offset + delta.Y, 90, math.max(90, size.Y - 28)))
        end
    end))
    table.insert(connections, UserInputService.InputEnded:Connect(function(input)
        if input ~= dragInput then return end
        if didDrag then
            suppressClickUntil = os.clock() + 0.3
            player:SetAttribute(PREFIX .. "IconPosition", Vector2.new(container.Position.X.Offset, container.Position.Y.Offset))
        end
        dragInput = nil
    end))
    local lastClick = -math.huge
    local function toggleMenu()
        local now = os.clock()
        if stopped or targetWindow.Destroyed or now < suppressClickUntil or now-lastClick < 0.9 then return end
        lastClick = now
        targetWindow:Toggle()
    end
    aura.ToggleMenu = toggleMenu
    table.insert(connections, click.MouseButton1Click:Connect(toggleMenu))
end
configureMenuIcon(window)
aura.ConfigureMenuIcon = configureMenuIcon
window.ToggleKey = nil
local combat = window:Tab({Title = "Combat", Icon = "swords"})
local drops = window:Tab({Title = "Sword Drops", Icon = "eye"})
local loot = window:Tab({Title = "Loot", Icon = "package-check"})
local function group(tab, title, icon, opened)
    return tab:Section({Title = title, Icon = icon, Opened = opened == true, Box = true})
end
local function toggle(section, title, key, value)
    return section:Toggle({Title = title, Value = value, Callback = function(v)
        player:SetAttribute(PREFIX .. key, v)
    end})
end
local attack = group(combat, "Auto-hit", "swords", true)
uiAura = toggle(attack, "Enable auto-hit (F6)", "Enabled", false)
attack:Slider({Title = "Attack range", Value = {Min = 2, Max = 20, Default = 10}, Step = 1,
    Callback = function(v) player:SetAttribute(PREFIX .. "Radius", v) end})
local targets = group(combat, "Target selection", "crosshair", false)
targets:Dropdown({Title = "Targets", Values = {"Mobs", "Players", "Mobs + Players"}, Value = "Mobs",
    Callback = function(v)
        player:SetAttribute(PREFIX .. "Mode", v)
        player:SetAttribute(PREFIX .. "Players", v ~= "Mobs")
        clearTarget()
    end})
local mobTypes = {"All"}
local mobByLabel: any = {All = "All"}
local zones = {}
local map = workspace:FindFirstChild("Map")
local zoneFolder = map and map:FindFirstChild("Zones")
if zoneFolder then
    for _,zone in ipairs(zoneFolder:GetChildren()) do
        local number = tonumber(string.match(zone.Name, "%d+"))
        local mob = zone:GetAttribute("MobToSpawn")
        if number and type(mob) == "string" and mob ~= "" then
            table.insert(zones, {number = number, mob = mob})
        end
    end
end
table.sort(zones, function(a, b) return a.number < b.number end)
for _,zone in ipairs(zones) do
    local label = string.format("Zone %d • %s", zone.number, zone.mob)
    table.insert(mobTypes, label)
    mobByLabel[label] = zone.mob
end
table.insert(mobTypes, "Troopers (event)")
mobByLabel["Troopers (event)"] = "Trooper"
aura.ZoneTargets = zones
targets:Dropdown({Title = "Mob type (zone order)", Values = mobTypes, Value = "All", Callback = function(v)
    player:SetAttribute(PREFIX .. "MobType", mobByLabel[v] or "All"); clearTarget()
end})
local troopers = group(combat, "Troopers and Bennet", "sparkles", false)
toggle(troopers, "Target troopers only", "TroopersOnly", false)
toggle(troopers, "Claim Bennet reward at 100% (nearby)", "AutoBennet", false)
local chase = group(combat, "Approach targets", "footprints", true)
toggle(chase, "Enable approach", "Move", false)
chase:Slider({Title = "Search distance", Value = {Min = 10, Max = 300, Default = 200}, Step = 10,
    Callback = function(v) player:SetAttribute(PREFIX .. "SearchRadius", v) end})
local protection = group(combat, "Knockback protection", "shield", false)
toggle(protection, "Anti-knockback", "AntiKnockback", false)
local esp = group(drops, "Sword ESP", "eye", true)
local function selectESPRarities(values)
    espRarities = {}
    if type(values) == "table" then for _,rarity in ipairs(values) do espRarities[rarity] = true end end
    updateDrops()
end
aura.SelectESPRarities = selectESPRarities
toggle(esp, "Sword names + rarity", "DropESP", true)
toggle(esp, "Only missing index swords", "MissingOnly", true)
esp:Dropdown({Title = "Show rarities", Values = Rarities.Order, Value = Rarities.Order, Multi = true, AllowNone = true,
    Callback = selectESPRarities})
esp:Slider({Title = "ESP distance", Value = {Min = 100, Max = 2000, Default = 800}, Step = 100,
    Callback = function(v) player:SetAttribute(PREFIX .. "ESPDistance", v) end})
local models = group(drops, "Model previews", "box", false)
toggle(models, "Show actual sword models", "Models", false)
toggle(models, "Rotate previews", "PreviewSpin", true)
models:Slider({Title = "Preview size", Value = {Min = 0.5, Max = 3, Default = 1}, Step = 0.25,
    Callback = function(v) player:SetAttribute(PREFIX .. "PreviewScale", v) end})
local pull = group(loot, "Auto-pull", "hand", true)
toggle(pull, "Pickup → return to plot → pull", "AutoPull", true)
local pullAddon = group(loot, "Auto-pull addons", "corner-up-left", false)
toggle(pullAddon, "Return to latest location after pull", "ReturnAfterPull", false)
local sell = group(loot, "Auto-sell", "coins", false)
toggle(sell, "Sell all unlocked swords", "AutoSell", false)
sell:Button({Title = "Preview eligible sales", Callback = function()
    local names = {}
    for _,item in ipairs(saleCandidates()) do table.insert(names, item.name) end
    WindUI:Notify({Title = "Eligible swords", Content = #names > 0 and table.concat(names, ", ") or "No eligible unlocked swords.", Duration = 6})
end})
window:SelectTab(1)
aura.Window = window
local uiElapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
    uiElapsed += dt
    if stopped or uiElapsed < 0.2 then return end
    uiElapsed = 0
    local ok, err = pcall(updateDrops)
    if not ok then player:SetAttribute(PREFIX .. "Error", tostring(err)) end
end))
window:OnDestroy(destroy)
player:SetAttribute(PREFIX .. "UIReady", true)
print("[RacoonHUB] Ready.")
return {ready = true, enabled = false, radius = 10}


