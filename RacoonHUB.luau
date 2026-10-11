local C: any = {}
local modules: any = {}
modules["core"] = (function()
return function(C: any)
    C.version = "2.0.0"
    C.player = game:GetService("Players").LocalPlayer
    C.services = {}
    for _,name in ipairs({"Players","RunService","HttpService","ReplicatedStorage","UserInputService","PathfindingService","CollectionService","GuiService"}) do C.services[name] = game:GetService(name) end
    C.prefix = "CodexHitAura_"
    C.connections = {}
    C.cleanups = {}
    C.tasks = {}
    C.controls = {}
    C.metrics = {}
    C.history = {}
    C.errors = {}
    C.stopped = false
    C.started = os.clock()
    C.gen = getgenv()
    local old = C.gen.CodexHitAura
    if type(old) == "table" and type(old.Destroy) == "function" then pcall(old.Destroy) end
    local function destroy()
        if C.stopped then return end
        C.stopped = true
        C.player:SetAttribute(C.prefix .. "UIReady", false)
        for _,connection in ipairs(C.connections) do pcall(function() connection:Disconnect() end) end
        for i=#C.cleanups,1,-1 do pcall(C.cleanups[i]) end
        if C.window then pcall(function() C.window:Destroy() end) end
        for _,key in ipairs({"Enabled","Move","AutoSell","AutoBennet","Busy"}) do C.player:SetAttribute(C.prefix..key,false) end
        if C.gen.CodexHitAura == C then C.gen.CodexHitAura = nil end
    end
    C.Destroy = destroy
    C.gen.CodexHitAura = C
    if type(STATE) == "table" and type(STATE.onCleanup) == "function" then STATE.onCleanup(destroy) end
    function C.connect(signal, callback)
        local connection = signal:Connect(function(...) if not C.stopped then callback(...) end end)
        table.insert(C.connections, connection)
        return connection
    end
    function C.cleanup(callback) table.insert(C.cleanups, callback) end
    function C.note(kind, message)
        table.insert(C.history, {at=DateTime.now().UnixTimestamp, kind=kind, message=message})
        if #C.history > 100 then table.remove(C.history,1) end
    end
    local lastNotice = {}
    function C.notify(key, message, force)
        local now = os.clock()
        if now-(lastNotice[key] or -math.huge)<8 then return end
        lastNotice[key]=now
        C.note(key,message)
        if C.WindUI and (force or C.settings.Errors) then C.WindUI:Notify({Title="RacoonHUB",Content=message,Duration=5}) end
    end
    function C.fail(feature, err)
        C.errors[feature]=tostring(err)
        C.player:SetAttribute(C.prefix.."Error",feature..": "..tostring(err))
        C.notify(feature,feature..": "..tostring(err))
    end
    function C.schedule(name, interval, callback)
        C.tasks[name]={interval=interval,next=0,run=callback}
    end
    C.connect(C.services.RunService.Heartbeat,function()
        if not C.initialized then return end
        local now=os.clock()
        for name,item in pairs(C.tasks) do
            if now>=item.next then
                item.next=now+item.interval
                local begin=os.clock()
                local ok,err=pcall(item.run,now)
                local cost=(os.clock()-begin)*1000
                local metric=C.metrics[name] or {calls=0,totalMs=0,maxMs=0}
                metric.calls+=1; metric.totalMs+=cost; metric.maxMs=math.max(metric.maxMs,cost)
                C.metrics[name]=metric
                if not ok then C.tasks[name]=nil; C.fail(name,err) end
            end
        end
    end)
    function C.root(model)
        if not model then return nil end
        local part=model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("CharacterRootPart") or model.PrimaryPart
        return part and part:IsA("BasePart") and part or nil
    end
    function C.alive(model)
        if not model or not model.Parent then return false end
        local hp=model:GetAttribute("Health")
        if type(hp)=="number" then return hp>0 end
        local h=model:FindFirstChildOfClass("Humanoid")
        return h~=nil and h.Health>0
    end
    function C.promptPosition(prompt)
        local parent=prompt and prompt.Parent
        if parent and parent:IsA("BasePart") then return parent.Position end
        if parent and parent:IsA("Attachment") then return parent.WorldPosition end
        return nil
    end
    C.defaults={Enabled=false,Move=false,AutoPull=true,AutoSell=false,AutoBennet=false,AntiKnockback=false,
        Mode="Mobs",MobType="All",TroopersOnly=false,Radius=10,SearchRadius=200,TargetPolicy="Keep current",
        DropESP=true,Collection="Missing",Models=false,PreviewSpin=true,PreviewBob=false,PreviewScale=1,
        ESPDistance=800,Quality="Balanced",MaxLabels=30,TextSize=15,LabelOpacity=0.82,ShowDistance=true,ShowSize=true,ShowMutation=true,
        ReturnAfterPull=false,SaleLimit=10,ProtectedNames="",SaleRarities={},ESPRarities={},
        Theme="Midnight",Accent="Blue",UIScale=1,Density="Compact",Opacity=0.9,IconSize=48,IconX=0.12,IconY=0.25,
        AttackKey="F6",TargetKey="F7",MenuKey="RightShift",Errors=true,Sections={},SelectedTab=1,
        TrooperESP=false,CrateESP=false,KeyESP=false,EventRange=800,SwordAlerts=false,CrateAlerts=false,KeyAlerts=false,
        TrooperAlerts=false,BennetAlerts=false,WeatherAlerts=false,EventAlerts=false,EventCountdown=false,
        AlertRarities={},Orientations={}}
    C.settings=table.clone(C.defaults)
    local unsafe={Enabled=true,Move=true,AutoSell=true,AutoBennet=true,AntiKnockback=true,Mode=true}
    local ranges={Radius={2,20},SearchRadius={10,300},ESPDistance={100,2000},PreviewScale={0.5,3},MaxLabels={5,80},TextSize={12,22},LabelOpacity={0.1,1},SaleLimit={1,100},UIScale={0.65,1.4},Opacity={0.5,1},IconSize={36,80},IconX={0,1},IconY={0,1},EventRange={100,2000},SelectedTab={1,3}}
    local enums={Collection={"Missing","Known","Both"},Mode={"Mobs","Players","Mobs + Players"},TargetPolicy={"Nearest","Keep current"},Quality={"Low","Balanced","High"},Theme={"Charcoal","Midnight","Slate"},Accent={"Blue","Mint","Violet","Rose"},Density={"Compact","Comfortable"}}
    function C.validSetting(key,value)
        local default=C.defaults[key]
        if default==nil or typeof(value)~=typeof(default) then return false end
        if type(value)=="number" then
            if value~=value or math.abs(value)==math.huge then return false end
            local range=ranges[key]; if range and (value<range[1] or value>range[2]) then return false end
        end
        if enums[key] and not table.find(enums[key],value) then return false end
        if (key=="AttackKey" or key=="TargetKey" or key=="MenuKey") and type(value)=="string" and not Enum.KeyCode[value] then return false end
        return true
    end
    C.loadedPreferences={}
    local configPath="CodexPullASword/preferences-v2.json"
    pcall(function()
        if not isfile(configPath) then return end
        local data=C.services.HttpService:JSONDecode(readfile(configPath))
        if type(data)~="table" or data.schema~=2 or type(data.settings)~="table" then return end
        for key,value in pairs(data.settings) do
            if not unsafe[key] and C.validSetting(key,value) then C.settings[key]=value; C.loadedPreferences[key]=true end
        end
    end)
    function C.save()
        local values={}
        for key,value in pairs(C.settings) do if not unsafe[key] then values[key]=value end end
        local ok,err=pcall(function()
            if not isfolder("CodexPullASword") then makefolder("CodexPullASword") end
            writefile(configPath,C.services.HttpService:JSONEncode({schema=2,settings=values}))
        end)
        if not ok then C.fail("Preferences",err) end
    end
    C.changed={}
    function C.set(key,value)
        if not C.validSetting(key,value) then return end
        if key=="AttackKey" or key=="TargetKey" or key=="MenuKey" then
            for _,other in ipairs({"AttackKey","TargetKey","MenuKey"}) do if other~=key and C.settings[other]==value then C.notify("Keybind","That key is already assigned.",true); return end end
        end
        if C.settings[key]==value then return end
        C.settings[key]=value
        if type(value)~="table" then C.player:SetAttribute(C.prefix..key,value) end
        C.dirtyAt=os.clock()+0.75
        local control=C.controls[key]
        if control and not C.syncing then
            C.syncing=true
            pcall(function() if control.Select then control:Select(value) elseif control.Set then control:Set(value) end end)
            C.syncing=false
        end
        for _,callback in ipairs(C.changed) do callback(key,value) end
    end
    for key,value in pairs(C.settings) do if type(value)~="table" then C.player:SetAttribute(C.prefix..key,value) end end
    C.player:SetAttribute(C.prefix.."Error", "")
    C.player:SetAttribute(C.prefix.."UIReady",false)
    C.player:SetAttribute(C.prefix.."Version",C.version)
    C.schedule("Preferences",0.5,function(now) if C.dirtyAt and now>=C.dirtyAt then C.dirtyAt=nil; C.save() end end)
    C.cleanup(function() if C.dirtyAt then C.save() end end)
    C.snapshot={revision=0,values={},raw={},valid={}}
    local function refresh(name)
        local raw=C.player:GetAttribute(name)
        local ok,data=pcall(function() return C.services.HttpService:JSONDecode(raw) end)
        C.snapshot.raw[name]=raw
        C.snapshot.valid[name]=ok and type(data)=="table"
        C.snapshot.values[name]=C.snapshot.valid[name] and data or nil
        C.snapshot.revision+=1
    end
    for _,name in ipairs({"Inventory","Swords","LockedSwords","SwordIndex"}) do
        refresh(name); C.connect(C.player:GetAttributeChangedSignal(name),function() refresh(name) end)
    end
    local shared=C.services.ReplicatedStorage:FindFirstChild("Modules")
    shared=shared and shared:FindFirstChild("Shared")
    for _,name in ipairs({"Rarities","SellPrices"}) do
        local module=shared and shared:FindFirstChild(name)
        local ok,value=pcall(function() return (require :: any)(module) end)
        if ok then C[name]=value else C.errors[name]="Game module unavailable" end
    end
    local packetModule: Instance?=C.services.ReplicatedStorage
    for _,name in ipairs({"Networking","ByteNet","Packets","GamePackets"}) do packetModule=packetModule and packetModule:FindFirstChild(name) end
    local ok,packets=pcall(function() return (require :: any)(packetModule) end)
    C.packets=ok and packets or {}
    function C.hasPacket(name) return type(C.packets[name])=="table" and type(C.packets[name].send)=="function" end
    if C.Rarities then
        for _,key in ipairs({"ESPRarities","SaleRarities","AlertRarities"}) do
            if not C.loadedPreferences[key] then C.settings[key]=table.clone(C.Rarities.Order) end
        end
    end
    C.movement={owner=nil,generation=0}
    function C.stopWalk()
        local root=C.root(C.player.Character)
        local humanoid=C.player.Character and C.player.Character:FindFirstChildOfClass("Humanoid")
        if root and humanoid then humanoid:MoveTo(root.Position) end
        if C.restoreRotation then C.restoreRotation() end
    end
    function C.acquire(owner)
        local current=C.movement.owner
        if current and current~=owner and current~="Approach" then return false end
        if current~=owner then
            C.stopWalk(); C.movement.generation+=1; C.movement.owner=owner
            if C.cancelPath then C.cancelPath() end
        end
        C.player:SetAttribute(C.prefix.."Busy",owner~="Approach")
        return true
    end
    function C.release(owner)
        if C.movement.owner~=owner then return end
        C.stopWalk(); C.movement.owner=nil; C.movement.generation+=1
        C.player:SetAttribute(C.prefix.."Busy",false)
    end
    function C.relocate(root,position)
        C.stopWalk()
        root.CFrame=CFrame.lookAt(position+Vector3.new(0,0,4),position)
        root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero
    end
    C.cleanup(function() C.stopWalk(); C.movement.owner=nil end)
    C.connect(C.player.CharacterRemoving,function()
        C.movement.generation+=1; C.stopWalk(); C.movement.owner=nil
        if C.cancelPull then C.cancelPull("Character removed",false) end
        if C.cancelSale then C.cancelSale("Character removed",false) end
    end)
end


end)()
modules["combat"] = (function()
return function(C: any)
    local S=C.settings
    local target: Model?=nil
    local scanAt,lastSend,lastMove=0,0,0
    local rotation: any=nil
    local ray=RaycastParams.new()
    ray.FilterType=Enum.RaycastFilterType.Exclude; ray.IgnoreWater=true
    local route: any=nil
    local routeGeneration=0
    local planning=false
    local nextPlan=0
    local progressPosition: Vector3?=nil
    local progressAt=0
    local stuckRetries=0
    local blocked: RBXScriptConnection?=nil
    function C.restoreRotation()
        if rotation and rotation.h.Parent then rotation.h.AutoRotate=rotation.before end
        rotation=nil
    end
    function C.cancelPath()
        routeGeneration+=1
        if route then route.path:Destroy() end
        route=nil; planning=false
        if blocked then blocked:Disconnect(); blocked=nil end
    end
    local function clear()
        target=nil; C.restoreRotation(); C.cancelPath()
        C.player:SetAttribute(C.prefix.."Target","")
    end
    C.cleanup(function() clear(); C.release("Approach") end)
    local function valid(model,character,origin,radius,los)
        if not model or model==character or not C.alive(model) or model:GetAttribute("Invulnerable")==true then return false end
        local root=C.root(model)
        if not root then return false end
        local delta=root.Position-origin
        if delta:Dot(delta)>radius*radius or math.abs(delta.Y)>8 then return false end
        local other=C.services.Players:GetPlayerFromCharacter(model)
        if other then
            if S.Mode=="Mobs" or S.TroopersOnly or character:GetAttribute("ZoneKind")=="Safe" or model:GetAttribute("ZoneKind")=="Safe" then return false end
            if C.player.Team and C.player.Team==other.Team then return false end
        else
            local npcs=workspace:FindFirstChild("NPCs")
            if not npcs or not model:IsDescendantOf(npcs) or S.Mode=="Players" then return false end
            local mob=model:GetAttribute("Mob") or model.Name:gsub("_%d+$","")
            if S.TroopersOnly then if mob~="Trooper" then return false end
            elseif S.MobType~="All" and mob~=S.MobType then return false end
        end
        if los then
            ray.FilterDescendantsInstances={character}
            local hit=workspace:Raycast(origin,delta,ray)
            if hit and not hit.Instance:IsDescendantOf(model) then return false end
        end
        return true
    end
    C.ValidTarget=valid
    function C.FindTarget(origin,character)
        local radius=S.Move and S.SearchRadius or S.Radius
        local best,bestDistance=nil,radius
        local function consider(model)
            if model:IsA("Model") and valid(model,character,origin,radius,not S.Move) then
                local distance=(C.root(model).Position-origin).Magnitude
                if distance<bestDistance then best=model; bestDistance=distance end
            end
        end
        local npcs=workspace:FindFirstChild("NPCs")
        if npcs then for _,model in ipairs(npcs:GetChildren()) do consider(model) end end
        if S.Mode~="Mobs" and not S.TroopersOnly then for _,p in ipairs(C.services.Players:GetPlayers()) do if p.Character then consider(p.Character) end end end
        if S.TargetPolicy=="Keep current" and valid(target,character,origin,radius,not S.Move) then
            local distance=(C.root(target).Position-origin).Magnitude
            if bestDistance>=distance*0.75 then return target end
        end
        return best
    end
    local function canAttack(character)
        local state=character:GetAttribute("SwordState")
        if state~="Drawn" and state~="HoldOut" then return false end
        for _,key in ipairs({"Training","Pulling","Stunned","AttackDebounce","M1Debounce"}) do if character:GetAttribute(key)==true then return false end end
        return C.alive(character)
    end
    local function plan(root,goal,character,now)
        if planning or now<nextPlan then return end
        planning=true; nextPlan=now+2
        local generation=routeGeneration
        local ownerGeneration=C.movement.generation
        task.spawn(function()
            local path=C.services.PathfindingService:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true})
            local ok=pcall(function() path:ComputeAsync(root.Position,goal) end)
            if C.stopped or generation~=routeGeneration or character~=C.player.Character or ownerGeneration~=C.movement.generation then path:Destroy(); return end
            planning=false
            if ok and path.Status==Enum.PathStatus.Success then
                route={path=path,points=path:GetWaypoints(),index=2,goal=goal}
                if blocked then blocked:Disconnect() end
                blocked=path.Blocked:Connect(function(index) if route and index>=route.index then C.cancelPath() end end)
            else path:Destroy(); stuckRetries+=1 end
        end)
    end
    C.schedule("Combat",0.05,function(now)
        if not S.Enabled and not S.Move then if target or rotation or route then clear() end; C.release("Approach"); return end
        if C.movement.owner and C.movement.owner~="Approach" then clear(); return end
        local character=C.player.Character
        local root=C.root(character)
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or not C.alive(character) or character:GetAttribute("Training")==true or character:GetAttribute("Pulling")==true or character:GetAttribute("Stunned")==true then
            clear(); C.release("Approach"); return
        end
        if now>=scanAt then
            local found=C.FindTarget(root.Position,character)
            if found~=target then C.cancelPath(); C.restoreRotation(); progressPosition=nil; stuckRetries=0 end
            target=found; scanAt=now+0.12
            C.player:SetAttribute(C.prefix.."Target",target and target.Name or "")
        end
        if not valid(target,character,root.Position,S.Move and S.SearchRadius or S.Radius,false) then clear(); C.release("Approach"); return end
        local targetRoot=C.root(target)
        local distance=(targetRoot.Position-root.Position).Magnitude
        if S.Move and distance>math.min(S.Radius,5) and C.acquire("Approach") then
            C.restoreRotation()
            if not progressPosition then progressPosition=root.Position; progressAt=now end
            if (root.Position-progressPosition).Magnitude>2 then progressPosition=root.Position; progressAt=now; stuckRetries=0 end
            local direction=root.Position-targetRoot.Position
            direction=Vector3.new(direction.X,0,direction.Z)
            local goal=targetRoot.Position+(direction.Magnitude>0.1 and direction.Unit*4 or Vector3.zero)
            if now-progressAt>1.5 then plan(root,goal,character,now) end
            if stuckRetries>=3 or now-progressAt>10 then C.set("Move",false); C.release("Approach"); C.notify("Approach","Approach stopped: target is unreachable."); return end
            if route and (route.goal-goal).Magnitude>12 then C.cancelPath() end
            if route then
                local point=route.points[route.index]
                if point and (point.Position-root.Position).Magnitude<3 then route.index+=1; point=route.points[route.index] end
                if point then goal=point.Position; if point.Action==Enum.PathWaypointAction.Jump then humanoid.Jump=true end else C.cancelPath() end
            end
            if now-lastMove>=0.3 then humanoid:MoveTo(goal); lastMove=now end
        else C.release("Approach"); progressPosition=nil end
        if not S.Enabled or not C.hasPacket("M1") or not canAttack(character) or not valid(target,character,root.Position,S.Radius,true) then C.restoreRotation(); return end
        local flat=Vector3.new(targetRoot.Position.X,root.Position.Y,targetRoot.Position.Z)
        if (flat-root.Position).Magnitude>0.1 then
            if not rotation or rotation.h~=humanoid then C.restoreRotation(); rotation={h=humanoid,before=humanoid.AutoRotate}; humanoid.AutoRotate=false end
            root.CFrame=CFrame.lookAt(root.Position,flat)
        end
        if now-lastSend>=0.05 then C.packets.M1.send(nil); lastSend=now; C.requests=(C.requests or 0)+1; C.player:SetAttribute(C.prefix.."Requests",C.requests) end
    end)
    C.connect(C.services.RunService.PreSimulation,function()
        if not S.AntiKnockback or C.movement.owner and C.movement.owner~="Approach" then return end
        local character=C.player.Character
        local root=C.root(character)
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or not C.alive(character) then return end
        for _,key in ipairs({"Pulling","Training","Sprinting","InFlight"}) do if character:GetAttribute(key)==true then return end end
        local pushed=character:GetAttribute("Ragdoll")==true or character:GetAttribute("KnockedDown")==true or character:GetAttribute("KnockedOut")==true or character:GetAttribute("Stunned")==true
        if not pushed then return end
        local speed=math.max(humanoid.WalkSpeed,16)
        local velocity=root.AssemblyLinearVelocity
        if Vector3.new(velocity.X,0,velocity.Z).Magnitude<=speed*1.8 then return end
        local move=humanoid.MoveDirection*speed
        root.AssemblyLinearVelocity=Vector3.new(move.X,velocity.Y,move.Z)
    end)
    table.insert(C.changed,function(key)
        if key=="Mode" or key=="MobType" or key=="TroopersOnly" or key=="Enabled" or key=="Move" then clear(); if not S.Move then C.release("Approach") end end
    end)
    C.connect(C.services.UserInputService.InputBegan,function(input,processed)
        if processed or C.services.UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode.Name==S.AttackKey then C.set("Enabled",not S.Enabled)
        elseif input.KeyCode.Name==S.TargetKey then C.set("Mode",S.Mode=="Mobs" and "Mobs + Players" or "Mobs")
        elseif input.KeyCode.Name==S.MenuKey and C.ToggleMenu then C.ToggleMenu() end
    end)
end

end)()
modules["loot"] = (function()
return function(C: any)
    type PullOperation = {generation:number,character:Model,origin:CFrame,sword:string,stage:string,started:number,entered:number,attempts:number,initialCount:number,initialReveal:any,sawPulling:boolean,lastSend:number,rock:Instance?}
    type SaleOperation = {generation:number,character:Model,origin:CFrame,candidate:any,stage:string,entered:number,initialCount:number,submitted:boolean}
    local S=C.settings
    local pull: PullOperation?=nil
    local sale: SaleOperation?=nil
    local generation=0
    local saleCooldown=0
    local soldThisRun=0
    local rejected={}
    local pullCooldown=0
    local function items()
        if not C.snapshot.valid.Inventory or not C.snapshot.valid.Swords then return nil end
        local out={}
        for index,item in ipairs(C.snapshot.values.Inventory) do
            if type(item)=="table" and type(item.Name)=="string" then table.insert(out,{name=item.Name,source="Inventory",index=index,data=item}) end
        end
        for index,item in ipairs(C.snapshot.values.Swords) do
            if type(item)=="string" and item~="" then table.insert(out,{name=item,source="Hotbar",index=index,data=item}) end
        end
        return out
    end
    local function countName(name)
        local all=items(); if not all then return nil end
        local count=0; for _,item in ipairs(all) do if item.name==name then count+=1 end end
        return count
    end
    function C.OwnRock()
        local map=workspace:FindFirstChild("Map")
        local plots=map and map:FindFirstChild("Plots")
        local plot=plots and plots:FindFirstChild(tostring(C.player:GetAttribute("Plot") or ""))
        local rock=plot and plot:FindFirstChild("RevealRock")
        return rock,rock and rock:FindFirstChild("RockPrompt",true)
    end
    local function restore(character,origin)
        local root=C.root(character)
        if character~=C.player.Character or not C.alive(character) or not root then return end
        root.CFrame=origin; root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero
    end
    function C.cancelPull(reason,returnOrigin)
        generation+=1
        local op=pull; pull=nil
        if op and returnOrigin then restore(op.character,op.origin) end
        C.release("Pull")
        if reason and op then C.notify("Auto-pull",reason) end
    end
    function C.cancelSale(reason,returnOrigin)
        generation+=1
        local op=sale; sale=nil
        if op and returnOrigin then restore(op.character,op.origin) end
        C.release("Sale")
        saleCooldown=os.clock()+1
        if reason and op then C.notify("Auto-sell",reason) end
    end
    C.cleanup(function() C.cancelPull(nil,false); C.cancelSale(nil,false) end)
    local function protectedNames()
        local set={}
        for name in string.gmatch(S.ProtectedNames,"[^,\n]+") do set[name:match("^%s*(.-)%s*$")]=true end
        return set
    end
    function C.SaleAllowed(name)
        local locks=C.snapshot.values.LockedSwords
        if not C.snapshot.valid.LockedSwords or type(locks)~="table" then return false,"Lock data unavailable" end
        for key,locked in pairs(locks) do if type(key)~="number" or key%1~=0 or key<1 or key>#locks or type(locked)~="string" then return false,"Invalid lock data" end end
        if name==C.player:GetAttribute("EquippedSword") then return false,"Equipped" end
        if table.find(locks,name) then return false,"Locked" end
        if protectedNames()[name] then return false,"Protected name" end
        if not C.Rarities then return false,"Rarity data unavailable" end
        if not table.find(S.SaleRarities,C.Rarities.RarityOf(name)) then return false,"Rarity excluded" end
        local all=items()
        if not all then return false,"Inventory unavailable" end
        if #all<=1 then return false,"Last usable sword" end
        if countName(name)~=1 then return false,"Duplicate identity is ambiguous" end
        return true
    end
    function C.SaleCandidates(includeExcluded)
        local out={}
        for _,item in ipairs(items() or {}) do
            local allowed,reason=C.SaleAllowed(item.name)
            item.reason=reason
            local reject=rejected[item.name]
            if reject and reject.revision==C.snapshot.revision then allowed=false; item.reason=reject.reason end
            if allowed or includeExcluded then item.allowed=allowed; table.insert(out,item) end
        end
        return out
    end
    local function sameValue(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~="table" then return a==b end
        for key,value in pairs(a) do if not sameValue(value,b[key]) then return false end end
        for key in pairs(b) do if a[key]==nil then return false end end
        return true
    end
    C.SameItem=sameValue
    local function exactCandidate(candidate)
        for _,name in ipairs({"Inventory","Swords","LockedSwords"}) do
            if C.player:GetAttribute(name)~=C.snapshot.raw[name] then return nil end
        end
        if not C.SaleAllowed(candidate.name) then return nil end
        for _,item in ipairs(items() or {}) do
            if item.name==candidate.name and item.source==candidate.source and item.index==candidate.index and sameValue(item.data,candidate.data) then return item end
        end
        return nil
    end
    local function rejectSale(reason)
        if sale then rejected[sale.candidate.name]={revision=C.snapshot.revision,reason=reason} end
        C.cancelSale(reason,true)
    end
    local function pullStep(now,character,root)
        local carrying=character:GetAttribute("CarryingSword")
        local pulling=character:GetAttribute("Pulling")==true
        local rock,prompt=C.OwnRock()
        local waiting=rock and rock:GetAttribute("SwordName")
        local name=type(carrying)=="string" and carrying~="" and carrying or (type(waiting)=="string" and waiting~="" and waiting or nil)
        if not pull then
            if not S.AutoPull or not name or pulling or now<pullCooldown or character:GetAttribute("Training")==true then return false end
            if sale then C.cancelSale("Sale paused for carried sword",true) end
            if not C.acquire("Pull") then return true end
            generation+=1
            pull={generation=generation,character=character,origin=root.CFrame,sword=name,stage="Travel",started=now,entered=now,attempts=0,initialCount=countName(name) or -1,initialReveal=rock and rock:GetAttribute("RevealedSword"),sawPulling=false,lastSend=0,rock=rock}
        end
        local op=pull
        if not S.AutoPull or op.character~=character or not C.alive(character) then C.cancelPull(nil,false); return true end
        if not rock or not prompt or not prompt:IsA("ProximityPrompt") then
            if now-op.entered>10 then C.cancelPull("Reveal rock unavailable; auto-pull paused.",false); C.set("AutoPull",false) end
            return true
        end
        if op.rock and op.rock~=rock then C.cancelPull("Reveal rock changed; pull cancelled.",false); return true end
        if not op.rock then op.rock=rock; op.initialReveal=rock:GetAttribute("RevealedSword") end
        if now-op.started>45 then C.cancelPull("Pull timed out; completion was not confirmed.",false); C.set("AutoPull",false); return true end
        if op.stage=="Travel" then
            local position=C.promptPosition(prompt)
            if not position then return true end
            C.relocate(root,position); op.stage="Prompt"; op.entered=now
        elseif op.stage=="Prompt" then
            if pulling then op.sawPulling=true; op.stage="Pulling"; op.entered=now
            elseif now-op.entered>12 or op.attempts>=4 and now-op.lastSend>2 then
                C.cancelPull("Pull did not start; auto-pull paused.",false); C.set("AutoPull",false)
            elseif now-op.lastSend>=1.5 and now-op.entered>=0.25 then
                local position=C.promptPosition(prompt)
                if position and prompt.Enabled and (root.Position-position).Magnitude<=prompt.MaxActivationDistance then
                    fireproximityprompt(prompt); op.attempts+=1; op.lastSend=now
                end
            end
        elseif op.stage=="Pulling" then
            if not pulling then op.stage="Confirm"; op.entered=now
            elseif now-op.lastSend>=0.07 and C.hasPacket("Pull") then C.packets.Pull.send(nil); op.lastSend=now end
        elseif op.stage=="Confirm" then
            local revealed=rock:GetAttribute("RevealedSword")
            local currentCount=countName(op.sword)
            local freshReveal=revealed==op.sword and op.initialReveal~=revealed
            local gained=currentCount and op.initialCount>=0 and currentCount>op.initialCount
            local rockClear=waiting==nil or waiting==""
            if op.sawPulling and not pulling and rockClear and revealed==op.sword and (freshReveal or gained) then
                C.pulled=(C.pulled or 0)+1; C.player:SetAttribute(C.prefix.."CompletedAutoPulls",C.pulled)
                C.note("Pull",op.sword.." completed")
                C.cancelPull(nil,S.ReturnAfterPull); pullCooldown=now+1
            elseif now-op.entered>8 then
                C.cancelPull("Pull completion is ambiguous; return skipped.",false); C.set("AutoPull",false)
            end
        end
        C.pullState=pull and pull.stage or "Idle"
        return true
    end
    local function saleStep(now,character,root)
        if not S.AutoSell then if sale then C.cancelSale(nil,true) end; return end
        if character:GetAttribute("Pulling")==true or character:GetAttribute("Training")==true or (character:GetAttribute("CarryingSword") or "")~="" then
            if sale then C.cancelSale("Sale cancelled by another character action.",false) end
            return
        end
        if not sale then
            if now<saleCooldown then return end
            saleCooldown=now+1
            if soldThisRun>=S.SaleLimit then C.set("AutoSell",false); C.notify("Auto-sell","Sale limit reached."); return end
            local candidate=C.SaleCandidates()[1]
            if not candidate then return end
            if not C.acquire("Sale") then return end
            generation+=1
            sale={generation=generation,character=character,origin=root.CFrame,candidate=candidate,stage="Select",entered=now,initialCount=countName(candidate.name) or 0,submitted=false}
        end
        local op=sale
        if op.character~=character or not C.alive(character) then C.cancelSale(nil,false); return end
        if op.stage=="Confirm" then
            local current=countName(op.candidate.name)
            if op.submitted and current and current==op.initialCount-1 then
                soldThisRun+=1; C.sold=(C.sold or 0)+1; C.note("Sale",op.candidate.name.." removed after sale request")
                C.cancelSale(nil,true)
            elseif now-op.entered>5 then rejectSale("Sale not confirmed; item suspended."); C.set("AutoSell",false) end
            return
        end
        if not exactCandidate(op.candidate) then rejectSale("Item changed or became protected; sale cancelled."); return end
        local heldKey=op.candidate.source=="Inventory" and "HeldInventory" or "HeldSlot"
        local held=character:GetAttribute("HeldSword")==op.candidate.name and character:GetAttribute(heldKey)==op.candidate.index
        if op.stage=="Select" then
            if not held then
                if op.candidate.source=="Inventory" and C.hasPacket("InventoryAction") then C.packets.InventoryAction.send({Action="Hold",Index=op.candidate.index,Slot=0})
                elseif op.candidate.source=="Hotbar" and C.hasPacket("SelectSlot") then C.packets.SelectSlot.send({Slot=op.candidate.index})
                else rejectSale("Selection API unavailable."); return end
            end
            op.stage="Verify"; op.entered=now
        elseif op.stage=="Verify" or op.stage=="Travel" then
            if not held then if now-op.entered>3 then rejectSale("Held item was not confirmed.") end; return end
            local validName,_,reason=C.SellPrices.HeldSale(C.player,character)
            if validName~=op.candidate.name then rejectSale(reason or "Server sale rules reject this item."); return end
            local map=workspace:FindFirstChild("Map")
            local sell=map and map:FindFirstChild("Sell")
            local stand=sell and sell:FindFirstChild("Stand")
            local part=stand and stand:FindFirstChild("SellThisItem")
            local prompt=part and part:FindFirstChildOfClass("ProximityPrompt")
            local position=C.promptPosition(prompt)
            if not prompt or not position then if now-op.entered>5 then rejectSale("Sell stand unavailable.") end; return end
            if op.stage=="Verify" then C.relocate(root,position); op.stage="Travel"; op.entered=now; return end
            if now-op.entered>5 then rejectSale("Sell stand could not be reached."); return end
            if now-op.entered>=0.25 and prompt.Enabled and (root.Position-position).Magnitude<=prompt.MaxActivationDistance then
                if not exactCandidate(op.candidate) then rejectSale("Final item validation failed."); return end
                if character:GetAttribute(heldKey)~=op.candidate.index or character:GetAttribute("HeldSword")~=op.candidate.name then rejectSale("Held item changed."); return end
                local finalName=C.SellPrices.HeldSale(C.player,character)
                if finalName~=op.candidate.name then rejectSale("Sale eligibility changed."); return end
                fireproximityprompt(prompt); op.submitted=true; op.stage="Confirm"; op.entered=now
            end
        end
        C.saleState=sale and sale.stage or "Idle"
    end
    table.insert(C.changed,function(key,value)
        if key=="AutoPull" and not value then C.cancelPull(nil,false) end
        if key=="AutoSell" then if value then soldThisRun=0 else C.cancelSale(nil,true) end end
    end)
    C.schedule("Loot",0.03,function(now)
        if not S.AutoPull and not S.AutoSell and not pull and not sale then return end
        local character=C.player.Character
        local root=C.root(character)
        if not root or not C.alive(character) then C.cancelPull(nil,false); C.cancelSale(nil,false); return end
        local ok,err=pcall(function()
            if C.hasPacket("Pull") and pullStep(now,character,root) then return end
            if C.SellPrices then saleStep(now,character,root) end
        end)
        if not ok then C.cancelPull(nil,false); C.cancelSale(nil,false); C.set("AutoPull",false); C.set("AutoSell",false); C.fail("Loot",err) end
    end)
    C.Test={countName=countName,exactCandidate=exactCandidate,items=items,pullStep=pullStep,saleStep=saleStep}
end

end)()
modules["visuals"] = (function()
return function(C: any)
    local S=C.settings
    local records: any={}
    local containers: any={}
    local assets: any={}
    local owned: any={}
    local indexRaw=nil
    local quality={Low={count=8,range=150,rate=0.1},Balanced={count=16,range=240,rate=0.05},High={count=30,range=300,rate=0.033}}
    local folder=Instance.new("Folder")
    folder.Name="CodexSwordReveals"; folder.Parent=workspace
    C.visualFolder=folder
    local function clearVisual(record)
        if record.gui then record.gui:Destroy(); record.gui=nil end
        if record.model then record.model:Destroy(); record.model=nil end
    end
    local function remove(object)
        local record=records[object]
        if record then clearVisual(record); for _,connection in ipairs(record.connections) do connection:Disconnect() end end
        records[object]=nil
    end
    local function track(object,kind,initial)
        if records[object] or not object:IsA("BasePart") and not object:IsA("Model") then return end
        local record={kind=kind,connections={},initial=initial,announced=initial,lastPose=nil}
        records[object]=record
        table.insert(record.connections,object.AncestryChanged:Connect(function() if not object:IsDescendantOf(workspace) then remove(object) end end))
    end
    local function bind(name,kind)
        local container=workspace:FindFirstChild(name)
        local old=containers[name]
        if old and old.object==container then return end
        if old then
            old.add:Disconnect(); old.remove:Disconnect()
            for object,record in pairs(records) do if record.kind==kind then remove(object) end end
        end
        containers[name]=nil
        if not container then return end
        for _,object in ipairs(container:GetChildren()) do track(object,kind,true) end
        containers[name]={object=container,add=container.ChildAdded:Connect(function(object) track(object,kind,false) end),remove=container.ChildRemoved:Connect(remove)}
    end
    bind("SwordDrops","Sword"); bind("CrateDrops","Crate"); bind("NPCs","Trooper")
    for _,object in ipairs(C.services.CollectionService:GetTagged("VaultKeyDrop")) do track(object,"Key",true) end
    C.connect(C.services.CollectionService:GetInstanceAddedSignal("VaultKeyDrop"),function(object) track(object,"Key",false) end)
    C.connect(C.services.CollectionService:GetInstanceRemovedSignal("VaultKeyDrop"),remove)
    C.schedule("Visual containers",3,function() bind("SwordDrops","Sword"); bind("CrateDrops","Crate"); bind("NPCs","Trooper") end)
    C.cleanup(function()
        for object in pairs(records) do remove(object) end
        for _,binding in pairs(containers) do binding.add:Disconnect(); binding.remove:Disconnect() end
        folder:Destroy(); table.clear(assets)
    end)
    local function partOf(object)
        if object:IsA("BasePart") then return object end
        return C.root(object) or object:FindFirstChildWhichIsA("BasePart",true)
    end
    local function makeLabel(record,part)
        local gui=Instance.new("BillboardGui")
        gui.Name="RacoonHUBLabel"; gui.Adornee=part; gui.Size=UDim2.fromOffset(260,54); gui.AlwaysOnTop=true; gui.ResetOnSpawn=false; gui.Parent=C.player.PlayerGui
        local label=Instance.new("TextLabel")
        label.Size=UDim2.fromScale(1,1); label.BackgroundColor3=Color3.fromRGB(12,17,27); label.Font=Enum.Font.GothamBold; label.TextStrokeTransparency=0.6; label.RichText=true; label.Parent=gui
        local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,8); corner.Parent=label
        record.gui=gui; record.label=label; record.text=nil; record.color=nil
    end
    local function escaped(value) return tostring(value):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;") end
    local function swordModel(record,name,scale,color)
        local cached=assets[name]
        if cached==nil or cached==false and os.clock()>(record.lookupAt or 0) then
            cached=C.Rarities.FindSwordModel(name) or false; assets[name]=cached; record.lookupAt=os.clock()+10
        end
        if not cached then return end
        if not record.model then
            local model=cached:Clone()
            for _,part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") then part.Anchored=true; part.CanCollide=false; part.CanTouch=false; part.CanQuery=false
                elseif part:IsA("LuaSourceContainer") or part:IsA("BillboardGui") or part:IsA("ProximityPrompt") or part:IsA("ParticleEmitter") or part:IsA("Trail") or part:IsA("Beam") or part:IsA("Sound") then part:Destroy() end
            end
            model.Name=name.."_Preview"; model.Parent=folder
            local _,size=model:GetBoundingBox()
            record.unitScale=model:GetScale()*6/math.max(size.X,size.Y,size.Z,0.1)
            record.model=model
            local highlight=Instance.new("Highlight")
            highlight.Adornee=model; highlight.FillTransparency=0.93; highlight.OutlineTransparency=0.12; highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; highlight.Parent=model
            record.highlight=highlight
        end
        if record.scale~=scale or record.orientation~=S.Orientations[name] then
            record.model:ScaleTo(record.unitScale*scale)
            local box,size=record.model:GetBoundingBox()
            local axis=S.Orientations[name] or "Auto"
            local rotation=CFrame.identity
            if axis=="Z" or axis=="Auto" and size.Z>size.Y and size.Z>size.X then rotation=CFrame.Angles(math.pi/2,0,0)
            elseif axis=="X" or axis=="Auto" and size.X>size.Y then rotation=CFrame.Angles(0,0,math.pi/2) end
            record.offset=rotation*record.model:GetPivot():ToObjectSpace(box):Inverse()
            record.scale=scale; record.orientation=S.Orientations[name]; record.lastPose=nil
        end
        if record.modelColor~=color then record.highlight.FillColor=color; record.highlight.OutlineColor=color; record.modelColor=color end
    end
    local lastVisual=0
    local function update()
        local root=C.root(C.player.Character)
        local camera=workspace.CurrentCamera
        if C.snapshot.raw.SwordIndex~=indexRaw then
            indexRaw=C.snapshot.raw.SwordIndex; owned={}
            for _,name in ipairs(C.snapshot.values.SwordIndex or {}) do owned[name]=true end
        end
        local visible={}
        local presentModels={}
        local q=quality[S.Quality] or quality.Balanced
        for object,record in pairs(records) do
            local part=partOf(object)
            if not part or not object:IsDescendantOf(workspace) then clearVisual(record); continue end
            if record.kind=="Trooper" and (object:GetAttribute("Mob")~="Trooper" or not C.alive(object)) then clearVisual(record); continue end
            local name,rarity,color,missing
            if record.kind=="Sword" then
                name=object:GetAttribute("SwordName")
                if type(name)~="string" or name=="" or not C.Rarities then clearVisual(record); continue end
                rarity=tostring(object:GetAttribute("Rarity") or C.Rarities.RarityOf(name))
                color=C.Rarities.ColorOf(rarity); missing=not owned[name]
            else name=record.kind=="Key" and "Vault key" or record.kind=="Crate" and "Glove crate" or "Trooper"; color=record.kind=="Key" and Color3.fromRGB(255,214,95) or record.kind=="Crate" and Color3.fromRGB(100,210,255) or Color3.fromRGB(255,120,120) end
            if record.name~=name then clearVisual(record); record.name=name; record.scale=nil; record.unitScale=nil end
            if not record.announced then
                record.announced=true
                local enabled=record.kind=="Sword" and S.SwordAlerts and table.find(S.AlertRarities,rarity) or record.kind=="Key" and S.KeyAlerts or record.kind=="Crate" and S.CrateAlerts or record.kind=="Trooper" and S.TrooperAlerts
                if enabled then C.notify("Spawn "..record.kind,name.." appeared nearby.",true) else C.note("Observed spawn",name) end
            end
            local distance=root and (part.Position-root.Position).Magnitude or math.huge
            local show=record.kind=="Sword" and S.DropESP and table.find(S.ESPRarities,rarity)~=nil and distance<=S.ESPDistance and (S.Collection=="Both" or S.Collection=="Missing" and missing or S.Collection=="Known" and not missing)
                or record.kind=="Key" and S.KeyESP and distance<=S.EventRange or record.kind=="Crate" and S.CrateESP and distance<=S.EventRange or record.kind=="Trooper" and S.TrooperESP and distance<=S.EventRange
            if not show or not camera then clearVisual(record); continue end
            local point,onScreen=camera:WorldToViewportPoint(part.Position+Vector3.new(0,4,0))
            if not onScreen or point.Z<=0 then clearVisual(record); continue end
            table.insert(visible,{object=object,record=record,part=part,name=name,rarity=rarity,color=color,missing=missing,distance=distance,point=point})
        end
        table.sort(visible,function(a,b) if (a.missing==true)~=(b.missing==true) then return a.missing==true end; return a.distance<b.distance end)
        local occupied={}
        local shown,modelCount=0,0
        for _,item in ipairs(visible) do
            local record=item.record
            local cellX,cellY=math.floor(item.point.X/260),math.floor(item.point.Y/65)
            local cell=tostring(cellX)..":"..tostring(cellY)
            if shown>=S.MaxLabels or occupied[cell] then clearVisual(record); continue end
            occupied[cell]=true; shown+=1
            if not record.gui then makeLabel(record,item.part) end
            local details={}
            if record.kind=="Sword" then
                table.insert(details,item.missing and "Missing index" or "Collected")
                local scale=item.object:GetAttribute("Scale") or item.object:GetAttribute("SwordScale")
                if S.ShowSize and type(scale)=="number" then table.insert(details,string.format("×%.2f",scale)) end
                local mutation=item.object:GetAttribute("Mutation")
                if S.ShowMutation and type(mutation)=="string" and mutation~="" then table.insert(details,mutation) end
            elseif record.kind=="Trooper" then
                local zone=item.object:GetAttribute("Zone") or item.object:GetAttribute("ZoneId") or item.object:GetAttribute("ZoneName")
                local hp=item.object:GetAttribute("Health")
                if zone~=nil then table.insert(details,"Zone "..tostring(zone)) end
                if type(hp)=="number" then table.insert(details,string.format("HP %.3g",hp)) end
            end
            if S.ShowDistance then table.insert(details,tostring(math.floor(item.distance)).." studs") end
            local text=escaped(item.name)..(item.rarity and " • "..escaped(C.Rarities.DisplayName(item.rarity)) or "")
            if #details>0 then text..='\n<font color="#CBD5E1" size="12">'..escaped(table.concat(details," • ")).."</font>" end
            if record.text~=text then record.label.Text=text; record.text=text end
            if record.color~=item.color then record.label.TextColor3=item.color; record.color=item.color end
            if record.font~=S.TextSize then record.label.TextSize=S.TextSize; record.font=S.TextSize end
            if record.opacity~=S.LabelOpacity then record.label.BackgroundTransparency=1-S.LabelOpacity; record.opacity=S.LabelOpacity end
            local wantsModel=record.kind=="Sword" and S.Models and item.distance<=q.range and modelCount<q.count
            if wantsModel then
                modelCount+=1; swordModel(record,item.name,S.PreviewScale,item.color); presentModels[record]=item.part
            elseif record.model then record.model:Destroy(); record.model=nil; record.scale=nil end
            local lift=record.model and 5+3*S.PreviewScale or 4
            if record.lift~=lift then record.gui.StudsOffset=Vector3.new(0,lift,0); record.lift=lift end
        end
        C.activePreviews=presentModels
        C.visualCounts={tracked=0,labels=shown,models=modelCount}
        for _ in pairs(records) do C.visualCounts.tracked+=1 end
        lastVisual=os.clock()
    end
    C.UpdateDrops=update
    C.IsMissing=function(name) return not owned[name] end
    C.SelectESPRarities=function(values) C.set("ESPRarities",values); update() end
    C.schedule("ESP",0.2,update)
    local lastAnimate=0
    C.connect(C.services.RunService.RenderStepped,function()
        local q=quality[S.Quality] or quality.Balanced
        local now=os.clock()
        if now-lastAnimate<q.rate then return end
        if not S.PreviewSpin and not S.PreviewBob and lastAnimate>=lastVisual then return end
        lastAnimate=now
        for record,part in pairs(C.activePreviews or {}) do
            if not record.model or not record.model.Parent or not part.Parent then continue end
            local yaw=S.PreviewSpin and now*0.5 or 0
            local bob=S.PreviewBob and math.sin(now*1.5)*0.12 or 0
            local pose=CFrame.new(part.Position+Vector3.new(0,1+3*S.PreviewScale+bob,0))*CFrame.Angles(0,yaw,0)*record.offset
            if record.lastPose~=pose then record.model:PivotTo(pose); record.lastPose=pose end
        end
    end)
    C.connect(C.player:GetAttributeChangedSignal("SwordIndex"),function() C.tasks.ESP.next=0 end)
    C.VisualTest={track=track,remove=remove,records=records,quality=quality}
end

end)()
modules["events"] = (function()
return function(C: any)
    local S=C.settings
    local benefits={Clover="+1,000 server luck",["Clover Rain"]="+1,000 server luck",Golden="×10 money generation",["Golden Rain"]="×10 money generation",Frost="Valhalla drops from kills",Galaxy="Galaxy swords fall around the map"}
    local weather=workspace:GetAttribute("Weather") or ""
    local weatherEnd=workspace:GetAttribute("WeatherEndsAt") or 0
    local nextEvent=workspace:GetAttribute("NextServerEventAt")
    local event=workspace:GetAttribute("LastServerEvent")
    local progress=C.player:GetAttribute("BennetProgress") or 0
    local lastReady=progress>=100
    local packet=C.packets.DialogueDisplay
    local pending: any=nil
    local lastPrompt=-math.huge
    local sessionUntil=0
    local attempts=0
    local mapping={}
    local mappingPath="CodexPullASword/bennet-verified-v2.json"
    pcall(function()
        if isfile(mappingPath) then
            local data=C.services.HttpService:JSONDecode(readfile(mappingPath))
            if data.placeVersion==game.PlaceVersion and type(data.mapping)=="table" then mapping=data.mapping end
        end
    end)
    local function signature(speaker,answers)
        return tostring(speaker).."|"..C.services.HttpService:JSONEncode(answers)
    end
    local function inventoryCount()
        if not C.snapshot.valid.Inventory or not C.snapshot.valid.Swords then return nil end
        return #C.snapshot.values.Inventory+#C.snapshot.values.Swords
    end
    local function captureChoice(index)
        if not C.learningBennet or not pending or (C.player:GetAttribute("BennetProgress") or 0)<100 then return end
        if type(pending.answers[index])~="string" then return end
        pending.selected=index; pending.sent=os.clock(); pending.beforeCount=inventoryCount(); pending.manual=true
    end
    C.LearnBennet=function() C.learningBennet=true; C.notify("Bennet learning","Select your reward manually at 100%. A confirmed reward will validate that exact dialogue.",true) end
    local function listener(data)
        if C.stopped or type(data)~="table" or tostring(data.Speaker)~="Master Bennet" then return end
        if not C.learningBennet and (not S.AutoBennet or os.clock()>sessionUntil) then return end
        local ok,answers=pcall(function() return C.services.HttpService:JSONDecode(data.Answers or "[]") end)
        if not ok or type(answers)~="table" then return end
        pending={speaker=data.Speaker,answers=answers,key=signature(data.Speaker,answers),received=os.clock(),beforeProgress=C.player:GetAttribute("BennetProgress") or 0}
    end
    if packet and type(packet.listen)=="function" and type(packet.getListeners)=="function" then
        packet.listen(listener)
        C.cleanup(function() local list=packet.getListeners(); local index=table.find(list,listener); if index then table.remove(list,index) end end)
    else C.errors.Bennet="Dialogue API unavailable" end
    local watched: any=setmetatable({},{__mode="k"})
    local function attachManualButtons()
        if not C.learningBennet then return end
        local gui=C.player.PlayerGui:FindFirstChild("Dialogue")
        local container=gui and gui:FindFirstChild("Container")
        local answers=container and container:FindFirstChild("AnswerContainer")
        if not answers then return end
        for _,answer in ipairs(answers:GetChildren()) do
            local index=tonumber(answer.Name:match("^Answer(%d+)$"))
            if index then
                local button=answer:IsA("GuiButton") and answer or answer:FindFirstChildWhichIsA("GuiButton",true)
                if button and not watched[button] then watched[button]=true; C.connect(button.Activated,function() captureChoice(index) end) end
            end
        end
    end
    C.schedule("Events",1,function()
        local now=workspace:GetServerTimeNow()
        local newWeather=workspace:GetAttribute("Weather") or ""
        local ending=workspace:GetAttribute("WeatherEndsAt") or 0
        if ending<=now then newWeather="" end
        if newWeather~=weather or newWeather~="" and ending~=weatherEnd then
            weather=newWeather; weatherEnd=ending
            local message=newWeather=="" and "Weather ended: clear skies." or newWeather.." • "..(benefits[newWeather] or "Benefit unavailable").." • "..math.max(0,math.ceil(ending-now)).."s remaining"
            if S.WeatherAlerts then C.notify("Weather",message,true) else C.note("Weather",message) end
        end
        local incoming=workspace:GetAttribute("NextServerEventAt")
        local last=workspace:GetAttribute("LastServerEvent")
        if incoming~=nextEvent then
            if nextEvent~=nil and last and (last~=event or incoming and nextEvent and incoming>nextEvent) then
                if S.EventAlerts then C.notify("Server event",tostring(last).." observed.",true) else C.note("Server event",tostring(last)) end
            end
            nextEvent=incoming; event=last
        end
        C.eventRemaining=type(incoming)=="number" and incoming>now and math.ceil(incoming-now) or nil
        if C.countdownControl then C.countdownControl:SetTitle(S.EventCountdown and (C.eventRemaining and "Next random event: "..C.eventRemaining.."s" or "Next random event: awaiting server") or "Random-event countdown off") end
        local current=C.player:GetAttribute("BennetProgress") or 0
        if current>=100 and not lastReady and S.BennetAlerts then C.notify("Bennet ready","Bennet reward ready. Visit him to collect.",true) end
        lastReady=current>=100; progress=current
    end)
    C.schedule("Bennet",0.25,function(now)
        attachManualButtons()
        if pending and pending.sent then
            local count=inventoryCount()
            if (C.player:GetAttribute("BennetProgress") or 0)<pending.beforeProgress and count and pending.beforeCount and count>pending.beforeCount then
                if pending.manual then
                    mapping[pending.key]=pending.selected
                    local ok,err=pcall(function() writefile(mappingPath,C.services.HttpService:JSONEncode({placeVersion=game.PlaceVersion,mapping=mapping})) end)
                    if not ok then C.fail("Bennet mapping",err) end
                    C.learningBennet=false
                end
                C.note("Bennet","Progress reset and reward inventory gain confirmed")
                C.notify("Bennet claim","Bennet reward confirmed.",true); pending=nil; attempts=0
            elseif now-pending.sent>12 then C.notify("Bennet claim","Reward not confirmed; auto-claim paused."); pending=nil; C.set("AutoBennet",false) end
            return
        end
        if not S.AutoBennet or progress<100 then return end
        if not C.hasPacket("DialogueAnswer") or C.errors.Bennet then C.set("AutoBennet",false); C.notify("Bennet","Dialogue compatibility unavailable."); return end
        local character=C.player.Character
        local root=C.root(character)
        if not root or not C.alive(character) or C.movement.owner or character:GetAttribute("Pulling")==true or character:GetAttribute("Training")==true then return end
        local folder=workspace:FindFirstChild("ForBennetEvent")
        local model=folder and folder:FindFirstChild("Master Bennet")
        local prompt=model and model:FindFirstChild("TalkPrompt",true)
        local position=C.promptPosition(prompt)
        if not position or (root.Position-position).Magnitude>10 then return end
        if pending then
            local index=mapping[pending.key]
            if type(index)~="number" or type(pending.answers[index])~="string" then
                C.set("AutoBennet",false); C.notify("Bennet","Unknown dialogue. Use Learn manual claim before enabling auto-claim.",true); return
            end
            local gui=C.player.PlayerGui:FindFirstChild("Dialogue")
            local container=gui and gui:FindFirstChild("Container")
            local answers=container and container:FindFirstChild("AnswerContainer")
            local answer=answers and answers:FindFirstChild("Answer"..index)
            if gui and gui:IsA("ScreenGui") and gui.Enabled and answer and answer:IsA("GuiObject") and answer.Visible and now-pending.received>=0.5 then
                local label=answer:IsA("TextButton") and answer or answer:FindFirstChildWhichIsA("TextLabel",true)
                if not label or label.Text~=pending.answers[index] then return end
                pending.selected=index; pending.sent=now; pending.beforeCount=inventoryCount()
                C.packets.DialogueAnswer.send({Index=index})
            elseif now-pending.received>10 then pending=nil; C.set("AutoBennet",false) end
        elseif now-lastPrompt>8 then
            if attempts>=2 then C.set("AutoBennet",false); C.notify("Bennet","Dialogue did not complete; auto-claim paused."); return end
            if prompt.Enabled then attempts+=1; lastPrompt=now; sessionUntil=now+12; fireproximityprompt(prompt) end
        end
    end)
    C.ExportHistory=function()
        local path="CodexPullASword/observed-events-"..tostring(DateTime.now().UnixTimestamp)..".json"
        writefile(path,C.services.HttpService:JSONEncode({scope="Observed this session",events=C.history})); C.notify("Export","Saved "..path,true)
    end
end

end)()
modules["ui"] = (function()
return function(C: any)
    local S=C.settings
    setthreadidentity(8)
    local iconPath="CodexPullASword/racoon-hub.jpg"
    local menuIcon=nil
    local iconFailure=nil
    local function validJpeg(bytes) return type(bytes)=="string" and #bytes>1024 and bytes:sub(1,3)==string.char(255,216,255) end
    C.ValidJpeg=validJpeg
    local iconOK,iconErr=pcall(function()
        if not isfolder("CodexPullASword") then makefolder("CodexPullASword") end
        local bytes=isfile(iconPath) and readfile(iconPath) or nil
        if not validJpeg(bytes) then
            bytes=game:HttpGet("https://raw.githubusercontent.com/012a4a/RacoonHUB/main/racoon.jpg")
            assert(validJpeg(bytes),"Photo download is not a JPEG")
            writefile(iconPath,bytes)
        end
        menuIcon=getcustomasset(iconPath)
    end)
    if not iconOK then iconFailure=tostring(iconErr) end
    local libraryPath="CodexPullASword/windui-1.6.66.lua"
    local ok,source=pcall(function() return game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua") end)
    if not ok then assert(isfile(libraryPath),"WindUI download failed and no tested cache exists"); source=readfile(libraryPath) end
    local compiled,compileError=loadstring(source)
    assert(compiled,compileError)
    local WindUI: any=compiled()
    C.WindUI=WindUI
    pcall(function() writefile(libraryPath,source) end)
    local accents={Blue=Color3.fromRGB(100,166,255),Mint=Color3.fromRGB(95,220,176),Violet=Color3.fromRGB(181,140,255),Rose=Color3.fromRGB(255,140,173)}
    local backgrounds={Charcoal=Color3.fromRGB(19,19,22),Midnight=Color3.fromRGB(10,14,24),Slate=Color3.fromRGB(24,32,42)}
    local function applyTheme()
        local accent=accents[S.Accent]
        WindUI:AddTheme({Name="RacoonCustom",Accent=Color3.fromRGB(22,28,46),Background=backgrounds[S.Theme],Dialog=Color3.fromRGB(17,23,38),Text=Color3.fromRGB(232,240,255),Placeholder=Color3.fromRGB(125,142,167),Primary=accent,Toggle=accent,Slider=accent,Checkbox=accent,Button=Color3.fromRGB(29,41,63),Icon=accent,Outline=Color3.fromRGB(124,158,204),ElementBackground=Color3.fromRGB(27,36,56),ElementBackgroundTransparency=0.15,PanelBackground=Color3.fromRGB(35,49,75),PanelBackgroundTransparency=0.85})
        if C.window then WindUI:SetTheme("RacoonCustom") end
    end
    applyTheme()
    local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
    local window=WindUI:CreateWindow({Title="RacoonHUB",Author="",NewElements=true,Topbar={Height=48,ButtonsType="Mac"},Folder="CodexPullASword",Size=UDim2.fromOffset(math.min(760,viewport.X-32),math.min(560,viewport.Y-70)),MinSize=Vector2.new(280,240),MaxSize=Vector2.new(1000,800),Theme="RacoonCustom",SideBarWidth=viewport.X<700 and 120 or 170,Resizable=true,HideSearchBar=false,Icon="swords",IgnoreAlerts=true,OpenButton={Title="RH",Icon=menuIcon,OnlyIcon=menuIcon~=nil,OnlyMobile=false,Enabled=true,Draggable=false,Scale=1,CornerRadius=UDim.new(0,10)}})
    C.window=window; C.Window=window; window.ToggleKey=nil
    local function scaleWindow()
        local camera=workspace.CurrentCamera
        if not camera then return end
        local vp=camera.ViewportSize
        local requested=S.UIScale*(S.Density=="Comfortable" and 1.1 or 1)
        local scale=math.min(requested,math.max(0.45,(vp.X-20)/360),math.max(0.45,(vp.Y-70)/280))
        window:SetUIScale(scale)
        window:SetSize(UDim2.fromOffset(math.min(760,(vp.X-24)/scale),math.min(560,(vp.Y-70)/scale)))
        window:SetToTheCenter()
        window:SetBackgroundTransparency(1-S.Opacity)
    end
    C.ResetLayout=function() C.set("IconX",0.12); C.set("IconY",0.25); scaleWindow(); if C.clampIcon then C.clampIcon() end end
    local function configureIcon()
        local opener=window.OpenButtonMain
        local button=opener.Button
        local container=button.Parent
        container.AnchorPoint=Vector2.new(0.5,0.5)
        button.BackgroundTransparency=1; button.AutomaticSize=Enum.AutomaticSize.None
        local scale=button:FindFirstChildOfClass("UIScale"); if scale then scale.Scale=1 end
        local stroke=button:FindFirstChildOfClass("UIStroke"); if stroke then stroke.Enabled=false end
        for _,child in ipairs(button:GetChildren()) do
            if child:IsA("Frame") then child.Visible=false end
            if child:IsA("UIPadding") then child.PaddingLeft=UDim.new(0,0); child.PaddingRight=UDim.new(0,0); child.PaddingTop=UDim.new(0,0); child.PaddingBottom=UDim.new(0,0) end
        end
        local original=button.TextButton
        local click=original:Clone(); original:Destroy(); click.Parent=button
        click.ZIndex=1001; button.ZIndex=1000; container.ZIndex=999
        click.AutomaticSize=Enum.AutomaticSize.None; click.Size=UDim2.fromScale(1,1); click.BackgroundTransparency=1; click.Active=true
        for _,child in ipairs(click:GetChildren()) do
            if child:IsA("TextLabel") then child.Visible=menuIcon==nil; if not menuIcon then child.Text="RH" end end
            if child:IsA("UIPadding") then child.PaddingLeft=UDim.new(0,0); child.PaddingRight=UDim.new(0,0); child.PaddingTop=UDim.new(0,0); child.PaddingBottom=UDim.new(0,0) end
            if child:IsA("Frame") then child.Size=UDim2.fromScale(1,1) end
        end
        opener.Visible=function() if container.Parent and not window.Destroyed then container.Visible=true end end
        container.Visible=true
        local function bounds()
            local camera=workspace.CurrentCamera
            local size=camera and camera.ViewportSize or Vector2.new(1280,720)
            local uiScale=window:GetUIScale() or 1
            local inset=C.services.GuiService:GetGuiInset()
            return size/uiScale,math.max(12,inset.Y/uiScale),uiScale
        end
        local function clamp(x,y)
            local size,inset=bounds()
            local half=S.IconSize/2+4
            return Vector2.new(math.clamp(x,half,math.max(half,size.X-half)),math.clamp(y,inset+half,math.max(inset+half,size.Y-half)))
        end
        function C.clampIcon()
            local size=bounds()
            local pos=clamp(S.IconX*size.X,S.IconY*size.Y)
            container.Position=UDim2.fromOffset(pos.X,pos.Y)
            button.Size=UDim2.fromOffset(S.IconSize,S.IconSize)
        end
        local gesture: any=nil
        local completed: any=setmetatable({},{__mode="k"})
        local function begin(input)
            if gesture or input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
            gesture={input=input,start=Vector2.new(input.Position.X,input.Position.Y),position=container.Position,dragged=false}
        end
        local function move(input)
            if not gesture then return end
            local mouse=gesture.input.UserInputType==Enum.UserInputType.MouseButton1
            if mouse and input.UserInputType~=Enum.UserInputType.MouseMovement or not mouse and input~=gesture.input then return end
            local delta=Vector2.new(input.Position.X,input.Position.Y)-gesture.start
            if delta.Magnitude>6 then gesture.dragged=true end
            if gesture.dragged then
                local _,_,uiScale=bounds()
                local pos=clamp(gesture.position.X.Offset+delta.X/uiScale,gesture.position.Y.Offset+delta.Y/uiScale)
                container.Position=UDim2.fromOffset(pos.X,pos.Y)
            end
        end
        local function finish(input)
            if not gesture or gesture.input~=input then return end
            completed[input]={dragged=gesture.dragged,consumed=gesture.consumed}
            if gesture.dragged then
                local size=bounds()
                C.set("IconX",container.Position.X.Offset/size.X); C.set("IconY",container.Position.Y.Offset/size.Y)
            end
            gesture=nil
        end
        function C.ToggleMenu() if not C.stopped and not window.Destroyed then window:Toggle() end end
        local function activate(input)
            local state=gesture and gesture.input==input and gesture or completed[input]
            if not state or state.dragged or state.consumed then return end
            state.consumed=true; C.ToggleMenu()
        end
        C.connect(click.InputBegan,begin)
        C.connect(C.services.UserInputService.InputChanged,move)
        C.connect(C.services.UserInputService.InputEnded,finish)
        C.connect(click.Activated,activate)
        C.connect(C.services.UserInputService.WindowFocusReleased,function() if gesture then completed[gesture.input]={dragged=true,consumed=true} end; gesture=nil end)
        C.IconTest={begin=begin,move=move,finish=finish,activate=activate,container=container,click=click,clamp=clamp}
        C.clampIcon()
    end
    configureIcon(); scaleWindow(); C.clampIcon()
    local cameraConnection: RBXScriptConnection?=nil
    local function bindCamera()
        if cameraConnection then cameraConnection:Disconnect() end
        local camera=workspace.CurrentCamera
        if camera then cameraConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() scaleWindow(); C.clampIcon() end) end
    end
    bindCamera(); C.connect(workspace:GetPropertyChangedSignal("CurrentCamera"),bindCamera)
    C.cleanup(function() if cameraConnection then cameraConnection:Disconnect() end end)
    local combat=window:Tab({Title="Combat",Icon="swords"})
    local drops=window:Tab({Title="Sword Drops",Icon="eye"})
    local loot=window:Tab({Title="Loot",Icon="package-check"})
    local groups={}
    local function group(tab,title,icon,default)
        local opened=S.Sections[title]
        local section=tab:Section({Title=title,Icon=icon,Opened=type(opened)=="boolean" and opened or default==true,Box=true})
        groups[title]=section
        return section
    end
    local function toggle(section,title,key)
        local control=section:Toggle({Title=title,Value=S[key],Callback=function(value) if not C.syncing then C.set(key,value) end end})
        C.controls[key]=control; return control
    end
    local function slider(section,title,key,min,max,step)
        local control=section:Slider({Title=title,Value={Min=min,Max=max,Default=S[key]},Step=step,Callback=function(value) if not C.syncing then C.set(key,value) end end})
        C.controls[key]=control; return control
    end
    local function dropdown(section,title,key,values,multi)
        local control=section:Dropdown({Title=title,Values=values,Value=S[key],Multi=multi==true,AllowNone=multi==true,SearchBarEnabled=#values>10,Callback=function(value) if not C.syncing then C.set(key,value) end end})
        C.controls[key]=control; return control
    end
    local attack=group(combat,"Auto-hit","swords",true)
    toggle(attack,"Enable auto-hit","Enabled"); slider(attack,"Attack range","Radius",2,20,1)
    local targets=group(combat,"Target selection","crosshair",false)
    dropdown(targets,"Targets","Mode",{"Mobs","Players","Mobs + Players"})
    dropdown(targets,"Target policy","TargetPolicy",{"Nearest","Keep current"})
    local zones={}
    local map=workspace:FindFirstChild("Map")
    local zoneFolder=map and map:FindFirstChild("Zones")
    if zoneFolder then for _,zone in ipairs(zoneFolder:GetChildren()) do
        local number=tonumber(zone.Name:match("%d+")); local mob=zone:GetAttribute("MobToSpawn")
        if number and type(mob)=="string" and mob~="" then table.insert(zones,{number=number,mob=mob}) end
    end end
    table.sort(zones,function(a,b) if a.number==b.number then return a.mob<b.mob end; return a.number<b.number end)
    local labels={"All"}; local byLabel={All="All"}; local selected="All"
    for _,zone in ipairs(zones) do local label=string.format("Zone %d • %s",zone.number,zone.mob); if not byLabel[label] then table.insert(labels,label); byLabel[label]=zone.mob end; if zone.mob==S.MobType then selected=label end end
    table.insert(labels,"Troopers (event)"); byLabel["Troopers (event)"]="Trooper"
    if S.MobType=="Trooper" then selected="Troopers (event)" end
    targets:Dropdown({Title="Mob type (zone order)",Values=labels,Value=selected,SearchBarEnabled=true,Callback=function(value) C.set("MobType",byLabel[value] or "All") end})
    C.ZoneTargets=zones
    local chase=group(combat,"Approach targets","footprints",true)
    toggle(chase,"Enable approach","Move"); slider(chase,"Search distance","SearchRadius",10,300,10)
    local troopers=group(combat,"Troopers and Bennet","sparkles",false)
    toggle(troopers,"Target troopers only","TroopersOnly"); toggle(troopers,"Trooper zone, health and distance","TrooperESP")
    toggle(troopers,"Trooper spawn alerts","TrooperAlerts"); toggle(troopers,"Bennet ready alert","BennetAlerts")
    toggle(troopers,"Auto-claim verified Bennet dialogue nearby","AutoBennet")
    troopers:Button({Title="Learn from next successful manual claim",Callback=C.LearnBennet})
    local protection=group(combat,"Knockback protection","shield",false)
    toggle(protection,"Reduce supported combat knockback","AntiKnockback")
    local esp=group(drops,"Sword labels","eye",true)
    toggle(esp,"Show sword names and rarity","DropESP")
    dropdown(esp,"Collection filter","Collection",{"Missing","Known","Both"})
    dropdown(esp,"Show rarities","ESPRarities",C.Rarities and C.Rarities.Order or {},true)
    slider(esp,"ESP distance","ESPDistance",100,2000,100)
    local labelsGroup=group(drops,"Label appearance","type",false)
    slider(labelsGroup,"Maximum visible labels","MaxLabels",5,80,5); slider(labelsGroup,"Text size","TextSize",12,22,1)
    slider(labelsGroup,"Label opacity","LabelOpacity",0.1,1,0.1)
    toggle(labelsGroup,"Show distance","ShowDistance"); toggle(labelsGroup,"Show known size","ShowSize"); toggle(labelsGroup,"Show known mutation","ShowMutation")
    local models=group(drops,"Model previews","box",false)
    toggle(models,"Show actual sword models","Models")
    local dependents={toggle(models,"Rotate previews","PreviewSpin"),toggle(models,"Bob previews","PreviewBob"),slider(models,"Preview size","PreviewScale",0.5,3,0.25)}
    dropdown(models,"Preview quality","Quality",{"Low","Balanced","High"})
    local orientationName=""
    models:Input({Title="Orientation override: exact sword name",Value="",Placeholder="Sword name",Callback=function(value) orientationName=tostring(value) end})
    models:Dropdown({Title="Blade axis override",Values={"Auto","X","Y","Z"},Value="Auto",Callback=function(value)
        if orientationName~="" then local t=table.clone(S.Orientations); t[orientationName]=value; C.set("Orientations",t) end
    end})
    local notices=group(drops,"Drop alerts","bell",false)
    toggle(notices,"Sword spawn alerts","SwordAlerts"); dropdown(notices,"Alert rarities","AlertRarities",C.Rarities and C.Rarities.Order or {},true)
    toggle(notices,"Glove crate alerts","CrateAlerts"); toggle(notices,"Vault key alerts","KeyAlerts")
    local objects=group(drops,"Crates and keys","package",false)
    toggle(objects,"Glove crate ESP","CrateESP"); toggle(objects,"Vault key ESP","KeyESP"); slider(objects,"Event object range","EventRange",100,2000,100)
    local pull=group(loot,"Auto-pull","hand",true)
    toggle(pull,"Auto-pull carried or waiting swords","AutoPull")
    local addon=group(loot,"Auto-pull addons","corner-up-left",false)
    toggle(addon,"Return after confirmed successful pull","ReturnAfterPull")
    local sell=group(loot,"Auto-sell","coins",false)
    toggle(sell,"Auto-sell eligible swords individually","AutoSell")
    slider(sell,"Maximum sales per run","SaleLimit",1,100,1)
    dropdown(sell,"Allowed sale rarities","SaleRarities",C.Rarities and C.Rarities.Order or {},true)
    sell:Input({Title="Protected sword names (comma separated)",Value=S.ProtectedNames,Placeholder="Exact names",Callback=function(value) C.set("ProtectedNames",tostring(value)) end})
    sell:Button({Title="Preview eligible sales and exclusions",Callback=function()
        local lines={}
        for index,item in ipairs(C.SaleCandidates(true)) do if index>25 then table.insert(lines,"More items omitted"); break end; table.insert(lines,item.name.." — "..(item.allowed and "Eligible" or item.reason or "Excluded")) end
        WindUI:Notify({Title="Sale preview",Content=#lines>0 and table.concat(lines,"\n") or "No inventory items.",Duration=10})
    end})
    local events=group(loot,"Weather and observed events","cloud",false)
    toggle(events,"Weather change alerts","WeatherAlerts"); toggle(events,"Observed server-event alerts","EventAlerts"); toggle(events,"Show random-event countdown","EventCountdown")
    C.countdownControl=events:Button({Title="Random-event countdown off",Callback=function() end})
    events:Button({Title="Export events observed this session",Callback=C.ExportHistory})
    events:Button({Title="Clear local observed history",Callback=function() table.clear(C.history) end})
    local appearance=group(loot,"Appearance and preferences","settings",false)
    dropdown(appearance,"Theme","Theme",{"Charcoal","Midnight","Slate"}); dropdown(appearance,"Accent","Accent",{"Blue","Mint","Violet","Rose"})
    dropdown(appearance,"Density","Density",{"Compact","Comfortable"}); slider(appearance,"UI scale","UIScale",0.65,1.4,0.05)
    slider(appearance,"Window opacity","Opacity",0.5,1,0.1); slider(appearance,"Photo size","IconSize",36,80,2)
    toggle(appearance,"Show concise error notifications","Errors")
    appearance:Button({Title="Reset menu and photo position",Callback=C.ResetLayout})
    appearance:Button({Title="Save preferences now",Callback=C.save})
    local keys=group(loot,"Keybinds","keyboard",false)
    local options={"F2","F3","F4","F5","F6","F7","F8","F9","F10","RightShift","LeftAlt"}
    dropdown(keys,"Auto-hit key","AttackKey",options); dropdown(keys,"Target mode key","TargetKey",options); dropdown(keys,"Menu key","MenuKey",options)
    local function dependencies()
        for _,control in ipairs(dependents) do if S.Models then control:Unlock() else control:Lock() end end
        if S.Move then C.controls.SearchRadius:Unlock() else C.controls.SearchRadius:Lock() end
        if not C.hasPacket("M1") then C.controls.Enabled:Lock() end
        if not C.hasPacket("Pull") then C.controls.AutoPull:Lock(); C.set("AutoPull",false) end
        if not C.SellPrices then C.controls.AutoSell:Lock() end
    end
    dependencies()
    table.insert(C.changed,function(key)
        if key=="Theme" or key=="Accent" then applyTheme() end
        if key=="UIScale" or key=="Density" or key=="Opacity" then scaleWindow(); C.clampIcon() end
        if key=="IconSize" then C.clampIcon() end
        if key=="Models" or key=="Move" then dependencies() end
        if C.tasks.ESP then C.tasks.ESP.next=0 end
    end)
    window:SelectTab(math.floor(S.SelectedTab))
    C.schedule("Layout preferences",1,function()
        local dirty=false
        for title,section in pairs(groups) do if S.Sections[title]~=section.Opened then S.Sections[title]=section.Opened; dirty=true end end
        local selectedTab=window.TabModule.SelectedTab
        if type(selectedTab)=="number" and S.SelectedTab~=selectedTab then S.SelectedTab=selectedTab; dirty=true end
        if dirty then C.dirtyAt=os.clock()+0.75 end
    end)
    window:OnDestroy(C.Destroy)
    if iconFailure then C.notify("Photo","Photo unavailable; using RH opener. "..iconFailure,true) end
    for feature,reason in pairs(C.errors) do C.notify(feature,feature..": "..reason) end
    C.player:SetAttribute(C.prefix.."UIReady",true)
    C.initialized=true
    print("[RacoonHUB] "..C.version.." ready")
end

end)()
local ok, err = pcall(function()
    modules["core"](C)
    modules["combat"](C)
    modules["loot"](C)
    modules["visuals"](C)
    modules["events"](C)
    modules["ui"](C)
end)
if not ok then if C.Destroy then C.Destroy() end; error("[RacoonHUB] " .. tostring(err)) end
return {ready=true,version=C.version}

