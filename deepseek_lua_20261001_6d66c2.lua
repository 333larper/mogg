-- =============================================
--  mogg — Obsidian UI
-- =============================================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
local Window = Library:CreateWindow({
    Title = "mogg",
    Footer = "Press Right Shift to toggle",
    NotifySide = "Right",
    ShowCustomCursor = true,
})
local Tabs = {
    Home     = Window:AddTab("Home", "home"),
    Defens   = Window:AddTab("Defens", "shield"),
    Target   = Window:AddTab("Target", "crosshair"),
    Misc     = Window:AddTab("Misc", "settings"),
    Movement = Window:AddTab("Movement", "walk"),
    Visuals  = Window:AddTab("Visuals", "eye"),
}
local TweenService = game:GetService("TweenService")
local LocalPlayer = game.Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CreateGrabLine = ReplicatedStorage:WaitForChild("GrabEvents"):WaitForChild("CreateGrabLine")

-- ============================================================
--  MOGG STATS PANEL (Ping + FPS)
-- ============================================================
do
    local Stats = game:GetService("Stats")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MoggStatsPanel"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 150, 0, 48)
    frame.Position = UDim2.new(1, -160, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(90, 130, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = frame

    local pingLabel = Instance.new("TextLabel")
    pingLabel.Size = UDim2.new(1, -12, 0, 20)
    pingLabel.Position = UDim2.new(0, 6, 0, 4)
    pingLabel.BackgroundTransparency = 1
    pingLabel.Text = "Ping: -- ms"
    pingLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    pingLabel.TextSize = 13
    pingLabel.Font = Enum.Font.GothamSemibold
    pingLabel.TextXAlignment = Enum.TextXAlignment.Left
    pingLabel.Parent = frame

    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Size = UDim2.new(1, -12, 0, 20)
    fpsLabel.Position = UDim2.new(0, 6, 0, 24)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.Text = "FPS: --"
    fpsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    fpsLabel.TextSize = 13
    fpsLabel.Font = Enum.Font.GothamSemibold
    fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
    fpsLabel.Parent = frame

    local pingItem
    task.spawn(function()
        local waited = 0
        repeat
            local network = Stats:FindFirstChild("Network")
            local serverStats = network and network:FindFirstChild("ServerStatsItem")
            pingItem = serverStats and serverStats:FindFirstChild("Data Ping")
            if not pingItem then task.wait(0.1) end
            waited = waited + 0.1
        until pingItem or waited > 10
    end)

    local frameCount = 0
    local lastFpsUpdate = tick()
    local lastPingUpdate = 0

    RunService.RenderStepped:Connect(function()
        local now = tick()
        frameCount = frameCount + 1
        if now - lastFpsUpdate >= 0.1 then
            local fps = math.floor(frameCount / (now - lastFpsUpdate))
            frameCount = 0
            lastFpsUpdate = now
            fpsLabel.Text = "FPS: " .. tostring(fps)
        end
        if pingItem and now - lastPingUpdate >= 0.02 then
            lastPingUpdate = now
            pcall(function()
                local val = pingItem:GetValueString()
                if val then pingLabel.Text = "Ping: " .. tostring(val) end
            end)
        end
    end)
end

-- ===== HOME =====
local HomeGroup = Tabs.Home:AddLeftGroupbox("Home")
HomeGroup:AddLabel("Добро пожаловать в mogg!")
local pingLabel = HomeGroup:AddLabel("<b>Ping:</b> <font color='#ffffff'>...</font>")
task.spawn(function()
    local stats = game:GetService("Stats")
    local network = stats:FindFirstChild("Network")
    local item
    local waited = 0
    repeat
        network = stats:FindFirstChild("Network")
        item = network and network:FindFirstChild("ServerStatsItem")
        item = item and item:FindFirstChild("Data Ping")
        if not item then task.wait(0.25) end
        waited = waited + 0.25
    until item or waited > 10
    if not item then
        pingLabel:SetText("<b>Ping:</b> <font color='#ff5050'>n/a</font>")
        return
    end
    task.spawn(function()
        while true do
            pcall(function()
                local ping = item:GetValueString()
                pingLabel:SetText("<b>Ping:</b> <font color='#ffffff'>" .. tostring(ping) .. "</font>")
            end)
            task.wait(0.5)
        end
    end)
end)

-- ============================================================
--  FLY
-- ============================================================
do
    local FlyGroup = Tabs.Home:AddRightGroupbox("Fly")
    local CFG = { Enabled=false, Flying=false, Speed=30, Accel=10, Damping=12, NoClip=true, TiltToCam=true }
    local State = { Char=nil, Hum=nil, HRP=nil, Attach=nil, Vel=nil, Velocity=Vector3.zero, NoclipConn=nil, HearthConn=nil }
    local function bindCharacter(char)
        State.Char = char
        State.Hum  = char:WaitForChild("Humanoid", 5)
        State.HRP  = char:WaitForChild("HumanoidRootPart", 5)
    end
    bindCharacter(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
    LocalPlayer.CharacterAdded:Connect(function(c) task.wait(0.3) bindCharacter(c) end)
    local function setFlying(enabled)
        if enabled and (not State.Hum or not State.HRP) then return end
        CFG.Flying = enabled
        local hum = State.Hum
        local hrp = State.HRP
        if not hum or not hrp then return end
        if enabled then
            hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
            hum:ChangeState(Enum.HumanoidStateType.Running)
            hum.PlatformStand = true
            hum.AutoRotate = false
            if State.Attach then State.Attach:Destroy() end
            if State.Vel then State.Vel:Destroy() end
            State.Attach = Instance.new("Attachment")
            State.Attach.Name = "FlyAttach"
            State.Attach.Parent = hrp
            State.Vel = Instance.new("LinearVelocity")
            State.Vel.Attachment0 = State.Attach
            State.Vel.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
            State.Vel.RelativeTo = Enum.ActuatorRelativeTo.World
            State.Vel.MaxForce = math.huge
            State.Vel.VectorVelocity = Vector3.zero
            State.Vel.Parent = hrp
            State.Velocity = Vector3.zero
            if CFG.NoClip then
                if State.NoclipConn then State.NoclipConn:Disconnect() end
                State.NoclipConn = RunService.Stepped:Connect(function()
                    if not CFG.Flying then return end
                    local c = State.Char
                    if not c then return end
                    for _, p in ipairs(c:GetDescendants()) do
                        if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
                    end
                end)
            end
        else
            hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
            hum.PlatformStand = false
            hum.AutoRotate = true
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            if State.Vel then State.Vel:Destroy() State.Vel = nil end
            if State.Attach then State.Attach:Destroy() State.Attach = nil end
            if State.NoclipConn then State.NoclipConn:Disconnect() State.NoclipConn = nil end
            if State.Char then
                for _, p in ipairs(State.Char:GetDescendants()) do
                    if p:IsA("BasePart") then pcall(function() p.CanCollide = true end) end
                end
            end
            State.Velocity = Vector3.zero
        end
    end
    if State.HearthConn then State.HearthConn:Disconnect() end
    State.HearthConn = RunService.Heartbeat:Connect(function(dt)
        if not CFG.Flying then return end
        local hrp = State.HRP
        local hum = State.Hum
        if not hrp or not hrp.Parent or not hum or hum.Health <= 0 then
            setFlying(false)
            if CFG.Enabled then
                CFG.Enabled = false
                if Library.Toggles and Library.Toggles.FlyToggle then pcall(function() Library.Toggles.FlyToggle:SetValue(false) end) end
            end
            return
        end
        local cam = workspace.CurrentCamera
        local camLook = cam.CFrame.LookVector
        local right = cam.CFrame.RightVector
        local wish = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then wish = wish + camLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then wish = wish - camLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then wish = wish + right end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then wish = wish - right end
        local wishDir = wish.Magnitude > 0 and wish.Unit or Vector3.zero
        local target = wishDir * CFG.Speed
        local isStopping = (wishDir.Magnitude == 0)
        local rate = isStopping and CFG.Damping or CFG.Accel
        State.Velocity = State.Velocity:Lerp(target, math.clamp(rate * dt, 0, 1))
        if State.Vel then State.Vel.VectorVelocity = State.Velocity end
        if CFG.TiltToCam then
            hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + camLook)
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end)
    FlyGroup:AddToggle("FlyToggle", { Text = "Enable Fly", Default = false, Callback = function(v)
        CFG.Enabled = v
        if v then if not CFG.Flying then setFlying(true) end
        else if CFG.Flying then setFlying(false) end end
    end })
    FlyGroup:AddLabel("Камера → W = летишь | WASD = движение | NoClip")
    FlyGroup:AddSlider("FlySpeed", { Text = "Speed", Default = 30, Min = 5, Max = 300, Rounding = 0, Suffix = " studs/s", Callback = function(v) CFG.Speed = v end })
    FlyGroup:AddSlider("FlyAccel", { Text = "Acceleration", Default = 10, Min = 1, Max = 30, Rounding = 1, Callback = function(v) CFG.Accel = v end })
    FlyGroup:AddSlider("FlyDamping", { Text = "Damping", Default = 12, Min = 1, Max = 30, Rounding = 1, Callback = function(v) CFG.Damping = v end })
    FlyGroup:AddToggle("FlyTiltToCam", { Text = "Body follows camera", Default = true, Callback = function(v) CFG.TiltToCam = v end })
    FlyGroup:AddToggle("FlyNoClip", { Text = "NoClip", Default = true, Callback = function(v)
        CFG.NoClip = v
        if not v and State.NoclipConn then
            State.NoclipConn:Disconnect()
            State.NoclipConn = nil
            if State.Char then
                for _, p in ipairs(State.Char:GetDescendants()) do
                    if p:IsA("BasePart") then pcall(function() p.CanCollide = true end) end
                end
            end
        end
    end })
end

-- ============================================================
--  TARGET FUNCTIONS
-- ============================================================
local function Bring(targetPlayerName)
    local TargetPlayer = game.Players:FindFirstChild(targetPlayerName)
    if not TargetPlayer then return end
    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")
    local RootPart = Character:WaitForChild("HumanoidRootPart")
    local Seat = Humanoid.SeatPart
    if not Seat then Library:Notify({ Title = "Bring", Content = "Сядь на блобмена!", Duration = 3 }) return end
    if TargetPlayer == LocalPlayer then return end
    local SeatObject = Seat.Parent
    local TargetCharacter = TargetPlayer.Character or TargetPlayer.CharacterAdded:Wait()
    local TargetRoot = TargetCharacter:WaitForChild("HumanoidRootPart")
    local Detector = SeatObject:WaitForChild("LeftDetector")
    local Weld = Detector:WaitForChild("LeftWeld")
    local GrabRemote = SeatObject.BlobmanSeatAndOwnerScript:WaitForChild("CreatureGrab")
    local OriginalPosition = RootPart.CFrame
    local OriginalTransparency = {}
    for _, part in ipairs(Character:GetDescendants()) do
        if part:IsA("BasePart") then
            OriginalTransparency[part] = part.Transparency
            part.Transparency = 1
        end
    end
    local Camera = workspace.CurrentCamera
    local OriginalCameraCFrame = Camera.CFrame
    Camera.CameraType = Enum.CameraType.Scriptable
    Camera.CFrame = OriginalCameraCFrame
    RootPart.CFrame = TargetRoot.CFrame * CFrame.new(0, 0, 2.5)
    task.wait()
    GrabRemote:FireServer(Detector, TargetRoot, Weld)
    task.delay(0.1, function() GrabRemote:FireServer(Detector, TargetRoot, Weld) end)
    task.delay(0.2, function()
        RootPart.CFrame = OriginalPosition
        for part, transparency in pairs(OriginalTransparency) do
            if part and part.Parent then part.Transparency = transparency end
        end
        Camera.CameraType = Enum.CameraType.Custom
        Camera.CameraSubject = Humanoid
    end)
end

local function Kick(targetPlayerName)
    local target = game.Players:FindFirstChild(targetPlayerName)
    if not target then return end
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = char:WaitForChild("Humanoid")
    local hrp = char:WaitForChild("HumanoidRootPart")
    local seat = humanoid.SeatPart
    if not seat then Library:Notify({ Title = "Kick", Content = "Сядь на блобмена!", Duration = 3 }) return end
    if target == LocalPlayer then return end
    local seatParent, targetChar = seat.Parent, target.Character or target.CharacterAdded:Wait()
    local targetHRP = targetChar:WaitForChild("HumanoidRootPart")
    local det = seatParent:WaitForChild("LeftDetector")
    local weld = det:WaitForChild("LeftWeld")
    local grab = seatParent.BlobmanSeatAndOwnerScript:WaitForChild("CreatureGrab")
    local drop = seatParent.BlobmanSeatAndOwnerScript:WaitForChild("CreatureDrop")
    local originalCFrame = hrp.CFrame
    hrp.CFrame = targetHRP.CFrame * CFrame.new(0, 0, 3)
    task.wait(0.5)
    grab:FireServer(det, targetHRP, weld)
    task.wait(0.7)
    drop:FireServer(weld, targetHRP)
    task.wait(0.3)
    grab:FireServer(det, targetHRP, weld)
    local bp = Instance.new("BodyPosition")
    bp.Position = Vector3.new(0, 999e5, 0)
    bp.MaxForce = Vector3.new(0, 99999e5, 0)
    bp.Parent = targetHRP
    task.wait(0.6)
    grab:FireServer(det, targetHRP, weld)
    bp:Destroy()
    hrp.CFrame = originalCFrame
end

local function LoopKick(targetPlayerName)
    local target = game.Players:FindFirstChild(targetPlayerName)
    if not target then return end
    if target == LocalPlayer then return end
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = char:WaitForChild("Humanoid")
    local hrp = char:WaitForChild("HumanoidRootPart")
    local seat = humanoid.SeatPart
    if not seat then Library:Notify({ Title = "Loop Kick", Content = "Сядь на блобмена!", Duration = 3 }) return end
    local seatParent = seat.Parent
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local targetHumanoid = targetChar:WaitForChild("Humanoid")
    local targetHRP = targetChar:WaitForChild("HumanoidRootPart")
    local leftDet = seatParent:WaitForChild("LeftDetector")
    local leftWeld = leftDet:WaitForChild("LeftWeld")
    local rightDet = seatParent:WaitForChild("RightDetector")
    local rightWeld = rightDet:WaitForChild("RightWeld")
    local grab = seatParent.BlobmanSeatAndOwnerScript:WaitForChild("CreatureGrab")
    local drop = seatParent.BlobmanSeatAndOwnerScript:WaitForChild("CreatureDrop")
    local function grabWithHand(det, weld, targetPart) grab:FireServer(det, targetPart, weld) end
    local function dropWithHand(weld, targetPart) drop:FireServer(weld, targetPart) end
    local originalCFrame = hrp.CFrame
    hrp.CFrame = targetHRP.CFrame * CFrame.new(0, -5, 0)
    task.wait(0.1)
    grabWithHand(leftDet, leftWeld, targetHRP)
    task.wait(0.5)
    dropWithHand(leftWeld, targetHRP)
    task.wait(0.2)
    local bp = Instance.new("BodyPosition")
    bp.Position = Vector3.new(0, 999e6, 0)
    bp.MaxForce = Vector3.new(999e6, 999e6, 999e6)
    bp.Parent = targetHRP
    grabWithHand(leftDet, leftWeld, targetHRP)
    task.wait(0.5)
    dropWithHand(leftWeld, targetHRP)
    task.wait(0.5)
    while target and target.Parent and targetHumanoid.Health > 0 do
        if targetHumanoid.Health > 0 then
            grabWithHand(leftDet, leftWeld, targetHRP); task.wait()
            dropWithHand(leftWeld, targetHRP); task.wait()
            grabWithHand(rightDet, rightWeld, targetHRP); task.wait()
            dropWithHand(rightWeld, targetHRP); task.wait()
            grabWithHand(leftDet, leftWeld, targetHRP)
            grabWithHand(rightDet, rightWeld, targetHRP); task.wait()
            dropWithHand(leftWeld, targetHRP)
            dropWithHand(rightWeld, targetHRP); task.wait()
        else break end
    end
    if bp then bp:Destroy() end
    hrp.CFrame = originalCFrame
end

local function Bypass(targetPlayerName)
    local target = game.Players:FindFirstChild(targetPlayerName)
    if not target or target == LocalPlayer then return end
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = char:WaitForChild("Humanoid")
    local seat = humanoid.SeatPart
    if not seat then Library:Notify({ Title = "Bypass", Content = "Сядь на блобмена!", Duration = 3 }) return end
    local seatParent = seat.Parent
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local targetHumanoid = targetChar:WaitForChild("Humanoid")
    local targetHRP = targetChar:WaitForChild("HumanoidRootPart")
    local leftDet = seatParent:WaitForChild("LeftDetector")
    local leftWeld = leftDet:WaitForChild("LeftWeld")
    local grab = seatParent.BlobmanSeatAndOwnerScript:WaitForChild("CreatureGrab")
    local drop = seatParent.BlobmanSeatAndOwnerScript:WaitForChild("CreatureDrop")
    local function grabWithHand(det, weld, targetPart) grab:FireServer(det, targetPart, weld) end
    local function dropWithHand(weld, targetPart) drop:FireServer(weld, targetPart) end
    task.wait(0.05)
    while target and target.Parent and targetHumanoid.Health > 0 do
        for i = 1, 20 do grabWithHand(leftDet, leftWeld, targetHRP) end
        dropWithHand(leftWeld, targetHRP)
        dropWithHand(leftWeld, targetHRP)
        task.wait(0.01)
    end
end

-- ============================================================
--  DEFENSE
-- ============================================================
local DefensGroup = Tabs.Defens:AddLeftGroupbox("Defense")
local DefensRightGroup = Tabs.Defens:AddRightGroupbox("Extra Defense")

do
    local lastGrabberConn = nil
    local lastGrabberLabel = nil
    local lastGrabberTime = 0
    local lastGrabberCooldown = 0.15
    local function startLastGrabberTracker()
        if lastGrabberConn then return end
        lastGrabberConn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            local now = tick()
            if now - lastGrabberTime < lastGrabberCooldown then return end
            local foundName = nil
            for _, part in ipairs(char:GetDescendants()) do
                local po = part:FindFirstChild("PartOwner")
                if po and po:IsA("StringValue") and po.Value ~= "" and po.Value ~= LocalPlayer.Name then
                    foundName = po.Value; break
                end
            end
            if not foundName then return end
            lastGrabberTime = now
            _G.__moggLastGrabberName = foundName
            local plr = Players:FindFirstChild(foundName)
            local display = plr and (plr.DisplayName .. " (@" .. plr.Name .. ")") or foundName
            if lastGrabberLabel then
                local stamp = os.date("%H:%M:%S")
                lastGrabberLabel:SetText("<b>Last Grabber:</b> <font color='#ff5050'>" .. display .. "</font> <font color='#888888'>[" .. stamp .. "]</font>")
            end
        end)
    end
    startLastGrabberTracker()
end

-- ANTI GRAB
do
    local AGConnections = {}
    local antiGrabProc = false
    local AGWalk = false
    local function setupAG(c, h, hd)
        AGConnections["AGHead_" .. c.Name] = hd.ChildAdded:Connect(function(PartOwner)
            if PartOwner.Name == "PartOwner" then
                if not antiGrabProc then
                    antiGrabProc = true
                    h.Sit = false
                    ReplicatedStorage.CharacterEvents.Struggle:FireServer(LocalPlayer)
                    task.spawn(function()
                        while (hd and hd:FindFirstChild("PartOwner")) or (LocalPlayer:FindFirstChild("IsHeld") and LocalPlayer.IsHeld.Value) do
                            ReplicatedStorage.CharacterEvents.Struggle:FireServer(LocalPlayer)
                            ReplicatedStorage.CharacterEvents.RagdollRemote:FireServer(c.HumanoidRootPart, 0)
                            task.wait()
                        end
                    end)
                    c.HumanoidRootPart.Anchored = true
                    if not AGWalk then
                        AGWalk = true
                        while LocalPlayer:FindFirstChild("IsHeld") and LocalPlayer.IsHeld.Value and task.wait() do
                            c.HumanoidRootPart.CFrame = c.HumanoidRootPart.CFrame + h.MoveDirection * 0.43
                        end
                    end
                    c.HumanoidRootPart.Anchored = false
                    antiGrabProc = false
                    AGWalk = false
                end
            end
        end)
        AGConnections["AGRagdoll_" .. c.Name] = h:WaitForChild("Ragdolled").Changed:Connect(function()
            if h.Ragdolled.Value then
                for _, v in pairs(c:GetChildren()) do
                    if v:IsA("BasePart") and v:FindFirstChild("BallSocketConstraint") and v.Name ~= "Head" then
                        v.BallSocketConstraint.Enabled = false
                        if v:FindFirstChild("RagdollLimbPart") then v.RagdollLimbPart.WeldConstraint.Enabled = false end
                    end
                end
            end
        end)
        AGConnections["AGWeld_" .. c.Name] = c.HumanoidRootPart:WaitForChild("WeldHRP").Changed:Connect(function()
            if c.HumanoidRootPart.WeldHRP.Enabled then
                while not h.Sit do task.wait() end
                h.Sit = false
                h.AutoRotate = true
                h.HipHeight = 1
                while c.HumanoidRootPart.WeldHRP.Enabled and task.wait() do
                    hd.CFrame = c.HumanoidRootPart.CFrame + Vector3.new(0, 1.35, 0)
                end
                h.HipHeight = 0
            end
        end)
        for _, v in pairs(c:GetChildren()) do
            if v:IsA("BasePart") and v:FindFirstChild("BallSocketConstraint") and v.Name ~= "Head" then
                v.BallSocketConstraint.Enabled = false
                if v:FindFirstChild("RagdollLimbPart") then v.RagdollLimbPart.WeldConstraint.Enabled = false end
            end
        end
    end
    local function antiGrabToggle(Value)
        if Value then
            local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local hum = char:WaitForChild("Humanoid")
            local head = char:WaitForChild("Head")
            setupAG(char, hum, head)
            AGConnections["AGChar"] = LocalPlayer.CharacterAdded:Connect(function(newChar)
                local newHum = newChar:WaitForChild("Humanoid")
                local newHead = newChar:WaitForChild("Head")
                task.wait(0.3)
                setupAG(newChar, newHum, newHead)
            end)
        else
            local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            for _, v in pairs(char:GetChildren()) do
                if v:IsA("BasePart") and v:FindFirstChild("BallSocketConstraint") and v.Name ~= "Head" then
                    v.BallSocketConstraint.Enabled = true
                    if v:FindFirstChild("RagdollLimbPart") then v.RagdollLimbPart.WeldConstraint.Enabled = true end
                end
            end
            for name, conn in pairs(AGConnections) do conn:Disconnect() end
            AGConnections = {}
        end
    end
    DefensGroup:AddToggle("AntiGrabToggle", { Text = "Anti Grab", Default = false, Callback = antiGrabToggle })
end

-- ANTI OWNERSHIP
do
    local antiOwnershipActive = false
    local antiOwnershipTask = nil
    local function AntiOwnershipFunction()
        local Struggle = ReplicatedStorage.CharacterEvents.Struggle
        while antiOwnershipActive do
            local character = LocalPlayer.Character
            if character and character:FindFirstChild("Head") then
                local head = character.Head
                if head:FindFirstChild("PartOwner") then
                    Struggle:FireServer(LocalPlayer)
                    for _, part in pairs(character:GetChildren()) do
                        if part:IsA("BasePart") then part.Anchored = true end
                    end
                    local isHeld = LocalPlayer:FindFirstChild("IsHeld")
                    while isHeld and isHeld.Value and antiOwnershipActive do task.wait() end
                    for _, part in pairs(character:GetChildren()) do
                        if part:IsA("BasePart") then part.Anchored = false end
                    end
                end
            end
            task.wait(0.1)
        end
    end
    local function antiOwnershipToggle(Value)
        antiOwnershipActive = Value
        if Value then antiOwnershipTask = task.spawn(AntiOwnershipFunction)
        else
            if antiOwnershipTask then task.cancel(antiOwnershipTask) antiOwnershipTask = nil end
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetChildren()) do
                    if part:IsA("BasePart") then part.Anchored = false end
                end
            end
        end
    end
    DefensGroup:AddToggle("AntiOwnership", { Text = "Anti Ownership", Default = false, Callback = antiOwnershipToggle })
end

-- ANTI OWNERSHIP 2
do
    local AntiOwn2Connections = {}
    local function AntiOwnership2Toggle(Value)
        if Value then
            local plr = LocalPlayer
            local isHeld = plr:WaitForChild("IsHeld", 5)
            local struggleEvent = ReplicatedStorage:WaitForChild("CharacterEvents"):WaitForChild("Struggle")
            local savedCFrame = nil
            AntiOwn2Connections["AntiOwn2"] = isHeld.Changed:Connect(function(heldState)
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if heldState then
                    if hrp then savedCFrame = hrp.CFrame; hrp.Anchored = true end
                    AntiOwn2Connections["AntiOwn2Loop"] = task.spawn(function()
                        while isHeld and isHeld.Value and Library.Toggles.AntiOwnership2Toggle.Value do
                            struggleEvent:FireServer(plr); task.wait()
                        end
                        if hrp and hrp.Parent then hrp.Anchored = false; if savedCFrame then hrp.CFrame = savedCFrame end end
                    end)
                else
                    if hrp and hrp.Parent then hrp.Anchored = false; if savedCFrame then hrp.CFrame = savedCFrame end end
                end
            end)
            AntiOwn2Connections["AntiOwn2Char"] = plr.CharacterAdded:Connect(function(char)
                task.wait(0.5)
                local hrp = char:WaitForChild("HumanoidRootPart")
                savedCFrame = hrp.CFrame
            end)
            if isHeld.Value then
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then savedCFrame = hrp.CFrame; hrp.Anchored = true end
                AntiOwn2Connections["AntiOwn2Loop"] = task.spawn(function()
                    while isHeld and isHeld.Value and Library.Toggles.AntiOwnership2Toggle.Value do
                        struggleEvent:FireServer(plr); task.wait()
                    end
                    if hrp and hrp.Parent then hrp.Anchored = false; if savedCFrame then hrp.CFrame = savedCFrame end end
                end)
            end
        else
            if AntiOwn2Connections["AntiOwn2"] then AntiOwn2Connections["AntiOwn2"]:Disconnect() AntiOwn2Connections["AntiOwn2"] = nil end
            if AntiOwn2Connections["AntiOwn2Loop"] then task.cancel(AntiOwn2Connections["AntiOwn2Loop"]) AntiOwn2Connections["AntiOwn2Loop"] = nil end
            if AntiOwn2Connections["AntiOwn2Char"] then AntiOwn2Connections["AntiOwn2Char"]:Disconnect() AntiOwn2Connections["AntiOwn2Char"] = nil end
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = false end
        end
    end
    DefensGroup:AddToggle("AntiOwnership2Toggle", { Text = "Anti Ownership 2", Default = false, Callback = AntiOwnership2Toggle })
end

-- ANTI RAGDOLL ON BLOB
do
    local antiRagBlobConnections = {}
    local antiRagBlobActive = false
    local function AntiRagBlobFunction()
        local RagdollRemote = ReplicatedStorage:FindFirstChild("RagdollRemote")
        local RagdolledSit = false
        local function DiscAR(con)
            if antiRagBlobConnections[con] then antiRagBlobConnections[con]:Disconnect(); antiRagBlobConnections[con] = nil end
        end
        local function setupCharacter(char)
            local hum = char and char:FindFirstChild("Humanoid")
            local HRP = char and char:FindFirstChild("HumanoidRootPart")
            if hum and HRP and RagdollRemote then
                DiscAR("ARSeat")
                antiRagBlobConnections["ARSeat"] = hum:GetPropertyChangedSignal("SeatPart"):Connect(function()
                    if hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" and not RagdolledSit then
                        RagdolledSit = true
                        local Seat = hum.SeatPart
                        while not hum.Sit do task.wait() end
                        RagdollRemote:FireServer(HRP, 3)
                        while not (hum:FindFirstChild("Ragdolled") and hum.Ragdolled.Value) and not hum.Sit do task.wait() end
                        task.wait(0.4)
                        hum.Sit = false
                        if Seat and Seat:IsA("Part") then Seat:Sit(hum) end
                        task.delay(0.25, function()
                            while hum and hum.SeatPart do
                                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                    RagdollRemote:FireServer(LocalPlayer.Character.HumanoidRootPart, 1)
                                end
                                task.wait(0.05)
                            end
                            RagdolledSit = false
                        end)
                    end
                end)
            end
        end
        if antiRagBlobActive then
            setupCharacter(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
            DiscAR("ARChar")
            antiRagBlobConnections["ARChar"] = LocalPlayer.CharacterAdded:Connect(function(newChar)
                task.wait(0.5)
                setupCharacter(newChar)
            end)
        else
            for _, conn in pairs(antiRagBlobConnections) do if conn then conn:Disconnect() end end
            antiRagBlobConnections = {}
        end
    end
    DefensGroup:AddToggle("AntiRagBlobToggle", { Text = "Anti Ragdoll on Blob", Default = false, Callback = function(v)
        antiRagBlobActive = v
        AntiRagBlobFunction()
    end })
end

-- ANTI BARRIER
do
    local function plotBarriersToggle(Value)
        local plots = workspace:FindFirstChild("Plots")
        if not plots then return end
        for _, plot in ipairs(plots:GetChildren()) do
            local barrierModel = plot:FindFirstChild("Barrier")
            if barrierModel then
                for _, part in ipairs(barrierModel:GetChildren()) do
                    if part:IsA("BasePart") and part.Name == "PlotBarrier" then
                        part.CanCollide = not Value
                    end
                end
            end
        end
    end
    DefensGroup:AddToggle("AntiBarrierToggle", { Text = "Anti Barrier", Default = false, Callback = plotBarriersToggle })
end

-- KILL DODGE
do
    local killDodgeActive = false
    local killDodgeConn = nil
    local function KillDodgeFunction()
        local Struggle = ReplicatedStorage:FindFirstChild("Struggle")
        local Tppos = Vector3.new(252, -7, 464)
        local function FindPlot()
            for _, plot in pairs(workspace.Plots:GetChildren()) do
                if plot:FindFirstChild(LocalPlayer.Name) then return plot end
            end
            return nil
        end
        local Plot = FindPlot()
        if Plot then
            if Plot.Name == "Plot1" then Tppos = Vector3.new(-533, -7, 90)
            elseif Plot.Name == "Plot2" then Tppos = Vector3.new(-483, -7, -164)
            elseif Plot.Name == "Plot3" then Tppos = Vector3.new(252, -7, 464)
            elseif Plot.Name == "Plot4" then Tppos = Vector3.new(509, 83, -339)
            else Tppos = Vector3.new(553, 123, -74) end
        end
        if killDodgeConn then killDodgeConn:Disconnect() end
        killDodgeConn = LocalPlayer.CharacterAdded:Connect(function(char)
            local hrp = char:WaitForChild("HumanoidRootPart")
            local hum = char:WaitForChild("Humanoid")
            task.spawn(function()
                while killDodgeActive do
                    task.wait()
                    if not (LocalPlayer:FindFirstChild("InPlot") and LocalPlayer.InPlot.Value) and hum.Health > 0 then
                        hrp.CFrame = CFrame.new(Tppos); hrp.Anchored = false
                    end
                end
            end)
            hum.Died:Connect(function()
                task.wait(2.8)
                while killDodgeActive and not (LocalPlayer:FindFirstChild("InPlot") and LocalPlayer.InPlot.Value) and hum.Health > 0 do
                    for i = 1,3 do
                        task.spawn(function() if Struggle then Struggle:FireServer(LocalPlayer) end end)
                    end
                    task.wait()
                end
            end)
        end)
    end
    DefensGroup:AddToggle("KillDodgeToggle", { Text = "Kill Dodge", Default = false, Callback = function(v)
        killDodgeActive = v
        if v then KillDodgeFunction() else if killDodgeConn then killDodgeConn:Disconnect() killDodgeConn = nil end end
    end })
end

-- ANTI FIRE
do
    local antiFireActive = false
    local antiFireTask = nil
    local hkFirePart = nil
    local function antiFireToggle(on)
        antiFireActive = on
        if on then
            if antiFireTask then task.cancel(antiFireTask); antiFireTask = nil end
            antiFireTask = task.spawn(function()
                pcall(function()
                    if workspace.Plots and workspace.Plots.Plot5 and workspace.Plots.Plot5.Barrier then
                        if workspace.Plots.Plot5.Barrier:FindFirstChild("AntiFirePart") then
                            hkFirePart = workspace.Plots.Plot5.Barrier.AntiFirePart
                        else
                            hkFirePart = workspace.Plots.Plot5.Barrier:FindFirstChild("PlotBarrier")
                        end
                        if hkFirePart then
                            hkFirePart.CanCollide = true
                            hkFirePart.CanQuery = true
                            hkFirePart.Name = "AntiFirePart"
                            if not hkFirePart.Parent:FindFirstChild("FalseBorder") then
                                local h2 = hkFirePart:Clone(); h2.Name = "FalseBorder"; h2.Parent = hkFirePart.Parent
                            end
                            hkFirePart.Size = Vector3.new(1,1,1)
                            for _, prt in pairs(hkFirePart:GetChildren()) do prt:Destroy() end
                            hkFirePart.CanQuery = false
                            hkFirePart.CanCollide = false
                        end
                    end
                end)
                while antiFireActive do
                    pcall(function()
                        if hkFirePart then
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                hkFirePart.CFrame = LocalPlayer.Character.HumanoidRootPart.CFrame
                            end
                            hkFirePart.CanCollide = not hkFirePart.CanCollide
                            hkFirePart.CanCollide = not hkFirePart.CanCollide
                        end
                    end)
                    task.wait()
                end
                if hkFirePart then hkFirePart.CFrame = CFrame.new(0,-15,0) end
            end)
        else
            if antiFireTask then task.cancel(antiFireTask); antiFireTask = nil end
            if hkFirePart then hkFirePart.CFrame = CFrame.new(0,-15,0) end
        end
    end
    DefensGroup:AddToggle("AntiFireToggle", { Text = "AntiFire (RR9)", Default = false, Callback = antiFireToggle })
end

-- ANTI EXPLOSION
do
    local antiExplosionActive = false
    local antiExplosionConnection = nil
    local function antiExplosionToggle(Value)
        antiExplosionActive = Value
        if Value then
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:WaitForChild("HumanoidRootPart")
            antiExplosionConnection = workspace.ChildAdded:Connect(function(model)
                if model.Name == "Part" and antiExplosionActive then
                    pcall(function()
                        local mag = (model.Position - hrp.Position).Magnitude
                        if mag <= 20 then
                            hrp.Anchored = true
                            task.wait(0.01)
                            local rightArm = char:FindFirstChild("Right Arm")
                            if rightArm then
                                local ragdollPart = rightArm:FindFirstChild("RagdollLimbPart")
                                if ragdollPart then
                                    while ragdollPart.CanCollide and antiExplosionActive do task.wait(0.001) end
                                end
                            end
                            if antiExplosionActive then hrp.Anchored = false end
                        end
                    end)
                end
            end)
        else
            if antiExplosionConnection then antiExplosionConnection:Disconnect(); antiExplosionConnection = nil end
            local char = LocalPlayer.Character
            if char then local hrp = char:FindFirstChild("HumanoidRootPart"); if hrp then hrp.Anchored = false end end
        end
    end
    DefensGroup:AddToggle("AntiExplosionToggle", { Text = "Anti Explosion (rr9)", Default = false, Callback = antiExplosionToggle })
end

-- ANTI VOID
do
    local antiVoidActive = false
    local antiVoidConnection = nil
    local function StartAntiVoid()
        local VOID_THRESHOLD = -50
        local SAFE_HEIGHT = 100
        antiVoidConnection = RunService.Heartbeat:Connect(function()
            if not antiVoidActive then return end
            local char = LocalPlayer.Character
            if char and char.PrimaryPart then
                local pos = char.PrimaryPart.Position
                if pos.Y < VOID_THRESHOLD then
                    local safePos = Vector3.new(pos.X, pos.Y + SAFE_HEIGHT, pos.Z)
                    char:SetPrimaryPartCFrame(CFrame.new(safePos))
                    char.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
                end
            end
        end)
    end
    local function antiVoidToggle(on)
        antiVoidActive = on
        if on then StartAntiVoid()
        else if antiVoidConnection then antiVoidConnection:Disconnect(); antiVoidConnection = nil end end
    end
    DefensGroup:AddToggle("AntiVoidToggle", { Text = "AntiVoid (Rezonans)", Default = false, Callback = antiVoidToggle })
end

-- ANTI PAINT
do
    local antiPaintActive = false
    local antiPaintConn = nil
    local function antiPaintToggle(on)
        antiPaintActive = on
        if not on then
            if antiPaintConn then antiPaintConn:Disconnect(); antiPaintConn = nil end
            return
        end
        local paint_toys = {BucketPaint=true, FoodHotSauce=true, ToiletGold=true, ToiletWhite=true}
        antiPaintConn = workspace.DescendantAdded:Connect(function(d)
            if not antiPaintActive then return end
            if d.Name == "PaintPlayerPart" or d.Name == "FirePlayerPart" then
                local p = d.Parent
                if p and paint_toys[p.Name] then
                    task.wait(0.1)
                    if d and d.Parent then d:Destroy() end
                end
            end
        end)
    end
    DefensGroup:AddToggle("AntiPaintToggle", { Text = "AntiPaint", Default = false, Callback = antiPaintToggle })
end

-- POSITION LOCK
do
    local posLockActive = false
    local posLockConnection = nil
    local posLockCFrame = nil
    local function posLockToggle(on)
        posLockActive = on
        if posLockConnection then posLockConnection:Disconnect(); posLockConnection = nil end
        if not on then
            posLockCFrame = nil
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                local assembly = root.AssemblyRootPart or root
                assembly.AssemblyLinearVelocity = Vector3.zero
                assembly.AssemblyAngularVelocity = Vector3.zero
            end
            return
        end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then posLockActive = false return end
        posLockCFrame = root.CFrame
        posLockConnection = RunService.Heartbeat:Connect(function()
            if not posLockActive then return end
            local c = LocalPlayer.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if not r or not posLockCFrame then return end
            local assembly = r.AssemblyRootPart or r
            assembly.AssemblyLinearVelocity = Vector3.zero
            assembly.AssemblyAngularVelocity = Vector3.zero
            local offset = assembly.CFrame:ToObjectSpace(r.CFrame)
            assembly.CFrame = posLockCFrame * offset:Inverse()
        end)
    end
    DefensGroup:AddToggle("PosLockToggle", { Text = "Position Lock", Default = false, Callback = posLockToggle })
    DefensGroup:AddButton({
        Text = "🔄 Переснять точку Position Lock",
        Callback = function()
            if not posLockActive then Library:Notify({ Title = "Position Lock", Content = "Сначала включи тумблер", Duration = 2 }); return end
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                posLockCFrame = root.CFrame
                Library:Notify({ Title = "Position Lock", Content = "Точка обновлена", Duration = 2 })
            end
        end
    })
end

-- ============================================================
--  DELETE LEGS (Toggle) + AUTO DELETE LEGS (on death/respawn)
-- ============================================================
do
    local autoDeleteLegsActive = false
    local autoDeleteLegsConnection = nil

    local function PerformDeleteLegs()
        pcall(function()
            local localPlayer = game.Players.LocalPlayer
            local ws = game:GetService("Workspace")
            local rs = game:GetService("ReplicatedStorage")
            local RagdollRemote = rs:WaitForChild("CharacterEvents"):WaitForChild("RagdollRemote")

            local character = localPlayer.Character
            if not character then
                character = localPlayer.CharacterAdded:Wait()
            end

            local leftLeg  = character:FindFirstChild("Left Leg")
            local rightLeg = character:FindFirstChild("Right Leg")
            local torso    = character:WaitForChild("Torso") or character:WaitForChild("UpperTorso")
            local hrp      = character:WaitForChild("HumanoidRootPart")

            if leftLeg and rightLeg and torso and hrp then
                local originalFallHeight = ws.FallenPartsDestroyHeight
                local originalCFrame = torso.CFrame

                ws.FallenPartsDestroyHeight = -100
                RagdollRemote:FireServer(hrp, 2)

                task.wait(0.5)

                leftLeg.CFrame  = CFrame.new(0, -10000, 0)
                rightLeg.CFrame = CFrame.new(0, -10000, 0)

                task.wait(0.3)

                torso.CFrame = CFrame.new(0, -9970, 0)

                task.wait(0.5)

                torso.CFrame = originalCFrame

                task.wait(0.5)
                ws.FallenPartsDestroyHeight = originalFallHeight
            end
        end)
    end

    -- Delete Legs — одиночный запуск при включении тумблера
    DefensGroup:AddToggle("DeleteLegsToggle", {
        Text = "Delete Legs",
        Default = false,
        Callback = function(Value)
            if Value then
                task.spawn(PerformDeleteLegs)
            end
        end
    })

    -- Auto Delete Legs — при смерти/респавне персонажа
    DefensGroup:AddToggle("AutoDeleteLegsToggle", {
        Text = "Auto Delete Legs",
        Default = false,
        Callback = function(Value)
            autoDeleteLegsActive = Value

            if Value then
                -- Если сейчас живой — применяем сразу
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                    task.spawn(PerformDeleteLegs)
                end

                -- Следим за респавном → удаляем ноги
                autoDeleteLegsConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
                    if not autoDeleteLegsActive then return end
                    task.wait(0.5)
                    if not autoDeleteLegsActive then return end
                    if newChar ~= LocalPlayer.Character then return end
                    PerformDeleteLegs()
                end)

                Library:Notify({ Title = "Auto Delete Legs", Content = "Активно (сработает при смерти/ресете)", Duration = 2 })
            else
                if autoDeleteLegsConnection then
                    autoDeleteLegsConnection:Disconnect()
                    autoDeleteLegsConnection = nil
                end
                Library:Notify({ Title = "Auto Delete Legs", Content = "Остановлено", Duration = 2 })
            end
        end
    })
end

-- BREAK PCLD (Button — как в оригинале)
DefensRightGroup:AddButton({
    Text = "💥 Break PCLD",
    Func = function()
        local plr = Players.LocalPlayer
        local serverPos = CFrame.new(-272.2197265625, -7.350403785705566, 475.0108947753906)
        pcall(function() workspace.FallenPartsDestroyHeight = 0/0 end)
        local storedJoints = {}
        local root, conn, active = nil, nil, false
        local function breakPCLD()
            local char = plr.Character
            if not char then return end
            root = char:WaitForChild("HumanoidRootPart")
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("Motor6D") then storedJoints[v] = v.Part0; v.Part0 = nil end
            end
            root.CFrame = serverPos
            conn = RunService.RenderStepped:Connect(function()
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        local function restore()
            if conn then conn:Disconnect() conn = nil end
            for m, p0 in pairs(storedJoints) do if m and m.Parent then m.Part0 = p0 end end
            storedJoints = {}
        end
        local function press6() active = not active; if active then breakPCLD() else restore() end end
        press6(); task.wait(0.12); press6()
        plr.CharacterAdded:Once(function() task.wait(0.25); press6(); task.wait(0.12); press6() end)
    end,
    DoubleClick = false
})

-- ANTI INPUT LAG
do
    local ToyList2 = {
        ["Coconut"] = "FoodCoconut", ["Banana"] = "FoodBanana", ["Fries"] = "FoodFrenchFries",
        ["MeatStick"] = "FoodMeatStick", ["Poop"] = "PoopPile", ["Donut"] = "FoodDonut",
        ["Cake"] = "FoodCakePink", ["Burger"] = "FoodHamburger", ["Pizza"] = "FoodPizzaCheese",
        ["Hotdog"] = "FoodHotdog", ["Mushroom"] = "FoodMushroomPoison",
        ["Banjo"] = "InstrumentGuitarBanjo", ["Violin"] = "InstrumentGuitarViolin",
        ["Ukulele"] = "InstrumentGuitarUkulele", ["Sax"] = "InstrumentWoodwindSaxophone",
        ["Vuvuzela"] = "InstrumentBrassVuvuzela", ["Bongos"] = "InstrumentDrumBongos",
        ["Mic"] = "InstrumentVoiceMicrophone", ["Pepperoni"] = "FoodPizzaPepperoni",
        ["Piano"] = "InstrumentPianoMelodica", ["Bread"] = "FoodBread",
        ["Egg"] = "FoodDippyEgg", ["Mayo"] = "FoodMayonnaise", ["WhiteMug"] = "CupMugWhite",
        ["Ocarina"] = "InstrumentWoodwindOcarina", ["SparklePoop"] = "PoopPileSparkle",
        ["BrownMug"] = "CupMugBrown", ["Trumpet"] = "InstrumentBrassTrumpet",
        ["Snare"] = "InstrumentDrumSnare", ["Lyre"] = "InstrumentGuitarLyre",
    }
    local InputLagDropdownValues = {}
    for shortName, _ in pairs(ToyList2) do table.insert(InputLagDropdownValues, shortName) end
    table.sort(InputLagDropdownValues)
    local SelectedInputLagToy = ToyList2["Burger"]
    local instantLagActive = false
    local instantLagTask = nil
    local respawnConnection = nil
    DefensGroup:AddDropdown("InputLagToySelect", {
        Text = "Select Input Lag Toy",
        Values = InputLagDropdownValues,
        Default = "Burger",
        Callback = function(Value) SelectedInputLagToy = ToyList2[Value] end
    })
    DefensGroup:AddToggle("AntiInputLag", {
        Text = "Anti Input Lag (rr9)",
        Default = false,
        Callback = function(Value)
            instantLagActive = Value
            if Value then
                if respawnConnection then respawnConnection:Disconnect() end
                respawnConnection = LocalPlayer.CharacterAdded:Connect(function() task.wait(1) end)
                instantLagTask = task.spawn(function()
                    local SpawnRemote = ReplicatedStorage.MenuToys.SpawnToyRemoteFunction
                    while instantLagActive do
                        pcall(function()
                            local char = LocalPlayer.Character
                            local hrp = char and char:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                local toysFolder = workspace:FindFirstChild(LocalPlayer.Name.."SpawnedInToys")
                                local name = SelectedInputLagToy
                                local item = toysFolder and toysFolder:FindFirstChild(name)
                                if not (item and item.Parent) then
                                    task.spawn(function()
                                        pcall(function() SpawnRemote:InvokeServer(name, hrp.CFrame * CFrame.new(0, -12, 0), Vector3.zero) end)
                                    end)
                                    task.wait(0.1)
                                    toysFolder = workspace:FindFirstChild(LocalPlayer.Name.."SpawnedInToys")
                                    item = toysFolder and toysFolder:FindFirstChild(name)
                                end
                                if item and item.Parent then
                                    local holdPart = item:FindFirstChild("HoldPart")
                                    if holdPart then
                                        for _, v in pairs(item:GetDescendants()) do
                                            if v:IsA("BasePart") then v.CanCollide = false; v.Massless = true end
                                        end
                                        task.spawn(function() pcall(function() holdPart.HoldItemRemoteFunction:InvokeServer(item, char) end) end)
                                        task.wait(0.02)
                                        task.spawn(function()
                                            pcall(function()
                                                holdPart.DropItemRemoteFunction:InvokeServer(item, CFrame.new(0, 5000, 0), Vector3.zero)
                                            end)
                                        end)
                                    end
                                end
                            end
                        end)
                        task.wait(0.02)
                    end
                end)
            else
                if instantLagTask then task.cancel(instantLagTask); instantLagTask = nil end
                if respawnConnection then respawnConnection:Disconnect(); respawnConnection = nil end
            end
        end
    })
end

-- ANTI PACKET
do
    local function antiPacketToggle(on)
        _G.antiPacket = on
        if on then
            pcall(function()
                if hookmetamethod then
                    local old
                    old = hookmetamethod(game, "__namecall", function(self, ...)
                        local args = { ... }
                        if _G.antiPacket and getnamecallmethod() == "FireServer" and self:IsA("RemoteEvent") then
                            local total = 0
                            for _, a in ipairs(args) do
                                if type(a) == "string" then
                                    total += #a
                                    if #a > 1000 then _G.packetBlocked = _G.packetBlocked + 1; return nil end
                                end
                            end
                            if total > 2000 then _G.packetBlocked = _G.packetBlocked + 1; return nil end
                        end
                        return old(self, ...)
                    end)
                    _G.packetHook = old
                end
            end)
        else
            if _G.packetHook then _G.packetHook = nil end
        end
    end
    DefensGroup:AddToggle("AntiPacketToggle", { Text = "AntiPacket (Soften Packet Lag)", Default = false, Callback = antiPacketToggle })
end

-- ANTI STICKY
do
    DefensGroup:AddToggle("AntiSticky", {
        Text = "Anti Sticky",
        Default = false,
        Callback = function(Value)
            if LocalPlayer.PlayerScripts:FindFirstChild("StickyPartsTouchDetection") then
                LocalPlayer.PlayerScripts.StickyPartsTouchDetection.Disabled = Value
            end
        end
    })
end

-- ANTI LAG
do
    DefensGroup:AddToggle("AntiLagToggle", {
        Text = "Anti Lag",
        Default = false,
        Save = true,
        Flag = "AntiLag",
        Callback = function(Value)
            local playerScriptsFolder = LocalPlayer:WaitForChild("PlayerScripts")
            local antiCreateLineScript = playerScriptsFolder:WaitForChild("CharacterAndBeamMove")
            local antiShuriLagScript = playerScriptsFolder:WaitForChild("StickyPartsTouchDetection")
            antiCreateLineScript.Disabled = Value
            antiShuriLagScript.Disabled = Value
        end
    })
end

-- ============================================================
--  ANTI KICK
-- ============================================================
do
    local _G_ShurikenAntiKick = false
    DefensGroup:AddToggle("ShurikenAntiKickToggle", {
        Text = "Anti Kick (Rezonans)",
        Default = false,
        Callback = function(Value)
            _G_ShurikenAntiKick = Value
            if Value then
                local function ClearKunai()
                    local plr = LocalPlayer
                    local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                    local destroyrem = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
                    if inv and destroyrem then
                        for _, v in pairs(inv:GetChildren()) do
                            if v.Name == "AntiKick" or v.Name == "NinjaShuriken" then
                                pcall(function() destroyrem:FireServer(v) end)
                            end
                        end
                    end
                end
                task.spawn(function()
                    local plr = LocalPlayer
                    local RS = ReplicatedStorage
                    local setOwner = RS:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
                    local stickyEvent = RS:WaitForChild("PlayerEvents"):WaitForChild("StickyPartEvent")
                    local spawnRemote = RS.MenuToys.SpawnToyRemoteFunction
                    local canSpawn = plr:WaitForChild("CanSpawnToy")
                    local function getHRP()
                        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then return plr.Character.HumanoidRootPart
                        else local character = plr.CharacterAdded:Wait(); return character:WaitForChild("HumanoidRootPart") end
                    end
                    local function CheckForHome()
                        if not workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then return false end
                        for _, v in pairs(workspace.Plots:GetChildren()) do
                            local sign = v:FindFirstChild("PlotSign")
                            local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                            if owners then
                                for _, b in pairs(owners:GetChildren()) do
                                    if b.Value == plr.Name then
                                        local folder = workspace.PlotItems:FindFirstChild(v.Name)
                                        if folder then return true, folder end
                                    end
                                end
                            end
                        end
                        return false
                    end
                    local function StickKunai(kunai)
                        if not kunai or not kunai:FindFirstChild("StickyPart") then return end
                        local currentHRP = getHRP()
                        if not currentHRP then return end
                        if kunai:FindFirstChild("SoundPart") then
                            if not kunai.SoundPart:FindFirstChild("PartOwner") or kunai.SoundPart.PartOwner.Value ~= plr.Name then
                                setOwner:FireServer(kunai.SoundPart, kunai.SoundPart.CFrame)
                            end
                        end
                        local firePart = currentHRP:FindFirstChild("FirePlayerPart") or currentHRP:WaitForChild("FirePlayerPart", 5)
                        if firePart then
                            stickyEvent:FireServer(kunai.StickyPart, firePart, CFrame.new(0,0,0) * CFrame.Angles(0, math.rad(90), math.rad(90)))
                        end
                        for _, obj in pairs(kunai:GetChildren()) do
                            if obj.Name == "Pyramid" then
                                obj.CanTouch = false; obj.CanCollide = false; obj.CanQuery = false; obj.Transparency = 0
                                if not obj:FindFirstChild("Highlight") then local h = Instance.new("Highlight", obj); h.FillColor = Color3.fromRGB(0, 0, 0) end
                            elseif obj.Name == "Main" then
                                obj.CanTouch = false; obj.CanCollide = false; obj.CanQuery = false; obj.Transparency = 0
                                if not obj:FindFirstChild("Highlight") then local h = Instance.new("Highlight", obj); h.FillColor = Color3.fromRGB(255, 255, 255) end
                            elseif obj:IsA("BasePart") then
                                obj.CanTouch = false; obj.CanCollide = false; obj.CanQuery = false; obj.Transparency = 1
                            end
                        end
                    end
                    local function SpawnToy(name)
                        local t = tick()
                        while not canSpawn.Value do
                            if not _G_ShurikenAntiKick or tick() - t > 5 then return nil end
                            task.wait(0.1)
                        end
                        local currentHRP = getHRP()
                        if currentHRP then
                            task.spawn(function()
                                pcall(function() spawnRemote:InvokeServer(name, currentHRP.CFrame * CFrame.new(0, 12, 20), Vector3.new(0,0,0)) end)
                            end)
                        end
                        local boolik, house = CheckForHome()
                        local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                        if boolik and house then return house:WaitForChild(name, 2)
                        elseif not workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) and inv then return inv:WaitForChild(name, 2) end
                        return nil
                    end
                    while _G_ShurikenAntiKick do
                        task.wait(0.005)
                        if not plr.Character or not plr.Character:FindFirstChild("Humanoid") or plr.Character.Humanoid.Health <= 0 then continue end
                        local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                        local kunai = inv and inv:FindFirstChild("NinjaShuriken")
                        if workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then
                            local boolik, house = CheckForHome()
                            if boolik and house and workspace.Plots:FindFirstChild(house.Name) then
                                local sign = workspace.Plots[house.Name]:FindFirstChild("PlotSign")
                                if sign and sign.ThisPlotsOwners.Value.TimeRemainingNum.Value > 89 then
                                    kunai = SpawnToy("NinjaShuriken")
                                    if kunai == nil then continue end
                                    kunai.Name = "AntiKick"; StickKunai(kunai)
                                end
                            end
                        end
                        if not kunai then
                            if workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then continue end
                            kunai = SpawnToy("NinjaShuriken")
                            if kunai == nil then continue end
                            kunai.Name = "AntiKick"
                            if not kunai then continue end
                        end
                        repeat
                            if kunai and kunai:FindFirstChild("StickyPart") and kunai.StickyPart.CanTouch == true then
                                StickKunai(kunai); kunai.Name = "AntiKick"
                            end
                            task.wait(0.3)
                        until not kunai or not _G_ShurikenAntiKick or not kunai:FindFirstChild("StickyPart") or kunai.StickyPart.CanTouch == false
                            or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart")
                            or not kunai:FindFirstChild("StickyPart")
                            or (plr.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20
                        if not kunai or not kunai:FindFirstChild("StickyPart") or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") or (plr.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20 then ClearKunai() end
                        pcall(function()
                            repeat task.wait(0.05)
                            until not _G_ShurikenAntiKick or not plr.Character or not plr.Character:FindFirstChild("Humanoid") or not kunai or not kunai:FindFirstChild("StickyPart") or not kunai.StickyPart:FindFirstChild("StickyWeld") or not kunai.StickyPart.StickyWeld.Part1
                            if not kunai or not kunai:FindFirstChild("StickyPart") or (plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health <= 0) or not kunai["StickyPart"]:FindFirstChild("StickyWeld").Part1 then ClearKunai() end
                        end)
                    end
                    ClearKunai()
                end)
            else
                local function ClearKunai()
                    local plr = LocalPlayer
                    local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                    local destroyrem = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
                    if inv and destroyrem then
                        for _, v in pairs(inv:GetChildren()) do
                            if v.Name == "AntiKick" or v.Name == "NinjaShuriken" then
                                pcall(function() destroyrem:FireServer(v) end)
                            end
                        end
                    end
                end
                ClearKunai()
            end
        end
    })
end

-- ANTI BLOBMAN KILL
do
    local ocnKakuConn = nil
    local ocnKakuAng = 0
    DefensGroup:AddToggle("AntiBlobmanKill", {
        Text = "Anti blobman kill",
        Default = false,
        Callback = function(Value)
            if Value then
                ocnKakuConn = RunService.RenderStepped:Connect(function(dt)
                    pcall(function()
                        local c = LocalPlayer.Character
                        local root = c and c:FindFirstChild("HumanoidRootPart")
                        if root then
                            ocnKakuAng = ocnKakuAng + dt * 9999
                            local rad = math.rad(ocnKakuAng)
                            root.CFrame = CFrame.new(math.cos(rad) * 50000, -100000, math.sin(rad) * 50000)
                        end
                    end)
                end)
            else
                if ocnKakuConn then ocnKakuConn:Disconnect(); ocnKakuConn = nil end
                ocnKakuAng = 0
            end
        end
    })
end

-- GUCCI BINDER
local GucciAntiGrab
do
    local gucciRunId = 0
    local function FWC(parent, name, t) return parent:FindFirstChild(name) or parent:WaitForChild(name, t or 3) end
    local function grab(prt) ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(prt, prt.CFrame) end
    local function toy_spawn_gucci(name, cframe, vector)
        local ToySpawn = ReplicatedStorage.MenuToys.SpawnToyRemoteFunction
        local InPlot = LocalPlayer.InPlot
        local InOwnerPlot = LocalPlayer.InOwnedPlot
        local CanSpawn = LocalPlayer.CanSpawnToy
        while InPlot.Value and not InOwnerPlot.Value and not CanSpawn.Value do task.wait(0.01) end
        task.spawn(function() ToySpawn:InvokeServer(name, cframe, vector or Vector3.new()) end)
        local BackPack = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        local SpawnedToy
        BackPack.ChildAdded:Once(function(toy)
            if toy.Name == name and toy:IsA("Model") then SpawnedToy = toy end
        end)
        local t = tick()
        while not SpawnedToy do
            if tick() - t < 2 then task.wait(0.01) else return false end
        end
        return SpawnedToy
    end
    GucciAntiGrab = function()
        gucciRunId = gucciRunId + 1
        local MyId = gucciRunId
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hum = FWC(char, "Humanoid")
        hum.Sit = true; task.wait(0.02)
        hum.Sit = false; task.wait(0.02)
        task.spawn(function()
            local t = tick()
            while tick() - t < 0.8 do
                for _, v in pairs(char:GetChildren()) do
                    if v:IsA("BasePart") then v.Velocity = Vector3.new() end
                end
                task.wait(0.01)
            end
        end)
        local autoGucciT, sitJumpT, Blob, BHead = true, false, nil, nil
        task.spawn(function()
            while not Blob and MyId == gucciRunId do task.wait(0.01) end
            if MyId ~= gucciRunId then return end
            BHead = FWC(Blob, "Head")
            local HitBox = FWC(Blob, "GrabbableHitbox")
            while MyId == gucciRunId and BHead and (not BHead:FindFirstChild("PartOwner") or BHead.PartOwner.Value ~= LocalPlayer.Name) do
                grab(HitBox); task.wait(0.01)
            end
        end)
        local hrp = FWC(char, "HumanoidRootPart")
        Blob = toy_spawn_gucci("CreatureBlobman", hrp.CFrame * CFrame.new(0, 0, -5), Vector3.new(0, -15.716, 0))
        if not Blob then return end
        local Seat = FWC(Blob, "VehicleSeat")
        task.defer(function()
            if not (char or hum) then return end
            local startTime = tick()
            while autoGucciT and MyId == gucciRunId and tick() - startTime < 0.3 do
                if Blob and Blob.Parent then
                    if Seat and Seat.Parent and Seat.Occupant ~= hum then Seat:Sit(hum) end
                end
                task.wait(0.03)
                if char and hum and hum.Parent then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                task.wait(0.03)
            end
            autoGucciT = false; sitJumpT = false
        end)
        sitJumpT = true
        task.defer(function()
            while sitJumpT and MyId == gucciRunId do
                if char and hrp and hrp.Parent then ReplicatedStorage.CharacterEvents.RagdollRemote:FireServer(hrp, 0.095) end
                task.wait(0.01)
            end
        end)
        task.wait(0.4)
        if MyId ~= gucciRunId then return end
        hum.Sit = false
        Blob.Name = "Gucci"
        for _, v in pairs(Blob:GetChildren()) do
            if v:IsA("BasePart") then v.CanCollide = false; v.CanTouch = false; v.CanQuery = false end
        end
        task.defer(function()
            while MyId == gucciRunId and Blob and BHead do
                BHead.CFrame = CFrame.new(BHead.Position.X, 1e5, BHead.Position.Z); task.wait(0.01)
            end
        end)
    end
    DefensRightGroup:AddButton({ Text = "🎯 Gucci Binder", Func = function() GucciAntiGrab() end })
end

-- ANTI GUCCI (BLOBMAN)
do
    local AntiGucciBlob = { systemOn = false, autoRespawnEnabled = false, currentSeat = nil, ragdollConnection = nil, sitConnection = nil, characterAddedConnection = nil, Remotes = { ragdoll = nil, spawn = nil, destroy = nil } }
    local function CacheRemotes()
        if not AntiGucciBlob.Remotes.ragdoll then
            local ce = ReplicatedStorage:FindFirstChild("CharacterEvents")
            if ce then AntiGucciBlob.Remotes.ragdoll = ce:FindFirstChild("RagdollRemote") end
        end
        if not AntiGucciBlob.Remotes.spawn or not AntiGucciBlob.Remotes.destroy then
            local mt = ReplicatedStorage:FindFirstChild("MenuToys")
            if mt then AntiGucciBlob.Remotes.spawn = mt:FindFirstChild("SpawnToyRemoteFunction"); AntiGucciBlob.Remotes.destroy = mt:FindFirstChild("DestroyToy") end
        end
    end
    local function StartRagdollSpam(rootPart)
        if AntiGucciBlob.ragdollConnection then AntiGucciBlob.ragdollConnection:Disconnect() end
        if not AntiGucciBlob.Remotes.ragdoll then return end
        AntiGucciBlob.ragdollConnection = RunService.Heartbeat:Connect(function()
            if not AntiGucciBlob.systemOn or not rootPart then return end
            pcall(function() AntiGucciBlob.Remotes.ragdoll:FireServer(rootPart, 2) end)
        end)
    end
    local function StartSitSpam(humanoid, seat)
        if AntiGucciBlob.sitConnection then AntiGucciBlob.sitConnection:Disconnect() end
        AntiGucciBlob.sitConnection = RunService.Heartbeat:Connect(function()
            if not AntiGucciBlob.systemOn or not seat or not seat.Parent then return end
            seat:Sit(humanoid)
        end)
    end
    local function CleanOldToys()
        if not AntiGucciBlob.Remotes.destroy then return end
        local folder = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        if not folder then return end
        for _, toy in pairs(folder:GetChildren()) do
            if toy.Name == "CreatureBlobman" then pcall(function() AntiGucciBlob.Remotes.destroy:FireServer(toy) end) end
        end
    end
    local function RunStableGucci()
        if AntiGucciBlob.systemOn then return end
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hum = char:WaitForChild("Humanoid", 3)
        local root = char:WaitForChild("HumanoidRootPart", 3)
        if not (hum and root) then AntiGucciBlob.systemOn = false return end
        AntiGucciBlob.systemOn = true
        CleanOldToys()
        local savedCFrame = root.CFrame
        local spawnCFrame = CFrame.new(103.85, -7.45, -538.58)
        task.spawn(function()
            if AntiGucciBlob.Remotes.spawn then AntiGucciBlob.Remotes.spawn:InvokeServer("CreatureBlobman", spawnCFrame, Vector3.zero) end
        end)
        local blobman = nil
        local folder = workspace:WaitForChild(LocalPlayer.Name .. "SpawnedInToys", 5)
        if not folder then AntiGucciBlob.systemOn = false return end
        local startTick = tick()
        while not blobman and tick() - startTick < 3 do
            local target = folder:FindFirstChild("CreatureBlobman")
            if target then blobman = target break end
            RunService.Heartbeat:Wait()
        end
        if not blobman then AntiGucciBlob.systemOn = false return end
        local head = blobman:FindFirstChild("Head")
        if head then head.Anchored = true end
        local seat = blobman:WaitForChild("VehicleSeat", 2)
        if not seat then AntiGucciBlob.systemOn = false return end
        AntiGucciBlob.currentSeat = seat
        StartRagdollSpam(root)
        root.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
        seat:Sit(hum)
        StartSitSpam(hum, seat)
        task.wait(0.6)
        hum.Sit = false
        hum.PlatformStand = true
        if seat then seat.Disabled = true; pcall(function() seat:Destroy() end) end
        if blobman then
            for _, v in pairs(blobman:GetDescendants()) do
                if v:IsA("Weld") or v:IsA("Snap") then v:Destroy() end
            end
        end
        root.CFrame = savedCFrame
        root.Velocity = Vector3.zero
        hum.PlatformStand = false
        task.wait(0.5)
        if AntiGucciBlob.sitConnection then AntiGucciBlob.sitConnection:Disconnect(); AntiGucciBlob.sitConnection = nil end
        if AntiGucciBlob.ragdollConnection then AntiGucciBlob.ragdollConnection:Disconnect(); AntiGucciBlob.ragdollConnection = nil end
        task.wait(0.5)
        AntiGucciBlob.systemOn = false
        Library:Notify({ Title = "Anti Gucci", Content = "Blob Man Gucci (Automatic) готово!", Duration = 2 })
    end
    local function StopSystem()
        AntiGucciBlob.systemOn = false
        AntiGucciBlob.autoRespawnEnabled = false
        AntiGucciBlob.currentSeat = nil
        if AntiGucciBlob.ragdollConnection then AntiGucciBlob.ragdollConnection:Disconnect(); AntiGucciBlob.ragdollConnection = nil end
        if AntiGucciBlob.sitConnection then AntiGucciBlob.sitConnection:Disconnect(); AntiGucciBlob.sitConnection = nil end
    end
    local function ConnectDeathEvent(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        hum.Died:Connect(function()
            if AntiGucciBlob.autoRespawnEnabled then AntiGucciBlob.systemOn = false; CleanOldToys() end
        end)
    end
    CacheRemotes()
    DefensRightGroup:AddToggle("AntiGucciBlob", {
        Text = "Anti Gucci (Blobman)",
        Default = false,
        Callback = function(Value)
            if Value then
                AntiGucciBlob.autoRespawnEnabled = true
                if LocalPlayer.Character then ConnectDeathEvent(LocalPlayer.Character) end
                task.spawn(RunStableGucci)
                if not AntiGucciBlob.characterAddedConnection then
                    AntiGucciBlob.characterAddedConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
                        if AntiGucciBlob.autoRespawnEnabled then
                            ConnectDeathEvent(newChar); task.wait(1); task.spawn(RunStableGucci)
                        end
                    end)
                end
            else
                StopSystem(); CleanOldToys()
                if AntiGucciBlob.characterAddedConnection then AntiGucciBlob.characterAddedConnection:Disconnect(); AntiGucciBlob.characterAddedConnection = nil end
            end
        end
    })
end

-- GUCCI (INVISIBLE)
do
    local gucciInvisConn = nil
    DefensRightGroup:AddToggle("GucciInvisible", {
        Text = "Gucci (Invisible)",
        Default = false,
        Callback = function(v)
            if v then
                local plr = LocalPlayer
                local HRP = plr.Character:WaitForChild("HumanoidRootPart")
                local RS_gucci = game:GetService("ReplicatedStorage")
                local RunService_gucci = game:GetService("RunService")
                local savedGucciCF = HRP.CFrame
                RS_gucci.MenuToys.SpawnToyRemoteFunction:InvokeServer("TractorGreen", CFrame.new(0, 50000, 0), Vector3.new())
                local inv = workspace:WaitForChild(plr.Name .. "SpawnedInToys")
                local blobb = inv:WaitForChild("TractorGreen", 3)
                if blobb then
                    blobb.Name = "tractorgucci"
                    local humanoid = plr.Character:WaitForChild("Humanoid")
                    local seat = blobb:WaitForChild("VehicleSeat", 3)
                    if seat then
                        seat.CFrame = CFrame.new(0, 50000, 0)
                        HRP.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
                        task.wait(0.05)
                        seat:Sit(humanoid)
                        for _ = 1, 10 do RS_gucci.CharacterEvents.RagdollRemote:FireServer(HRP, 0); task.wait() end
                        local t0 = tick()
                        while seat.Occupant ~= humanoid and tick() - t0 < 3 do
                            HRP.CFrame = seat.CFrame + Vector3.new(0, 2, 0); seat:Sit(humanoid); task.wait()
                        end
                        HRP.CFrame = savedGucciCF
                        if gucciInvisConn then gucciInvisConn:Disconnect() end
                        gucciInvisConn = RunService_gucci.Heartbeat:Connect(function()
                            if not HRP or not HRP.Parent then return end
                            RS_gucci.CharacterEvents.RagdollRemote:FireServer(HRP, 0)
                            if seat and seat.Parent then seat.CFrame = CFrame.new(0, 50000, 0) end
                            if humanoid and humanoid.Sit then HRP.CFrame = savedGucciCF end
                        end)
                    end
                end
            else
                if gucciInvisConn then gucciInvisConn:Disconnect(); gucciInvisConn = nil end
                local plr = LocalPlayer
                local DestroyToy = ReplicatedStorage.MenuToys.DestroyToy
                local hum = plr.Character and plr.Character:FindFirstChild("Humanoid")
                if hum then hum.Sit = false; hum:ChangeState(Enum.HumanoidStateType.GettingUp); task.wait(0.1) end
                local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                if inv then
                    local toy = inv:FindFirstChild("tractorgucci") or inv:FindFirstChild("TractorGreen")
                    if toy then
                        pcall(function() DestroyToy:FireServer(toy) end)
                        task.wait(0.1)
                        if toy and toy.Parent then pcall(function() DestroyToy:FireServer(toy) end) end
                        task.wait(0.05)
                        if toy and toy.Parent then pcall(function() toy:Destroy() end) end
                    end
                end
                if hum then for _ = 1, 10 do hum.Sit = false; task.wait() end end
            end
        end
    })
end

-- AUTO GUCCI (INVISIBLE)
do
    local autoGucciEnabled = false
    local autoGucciConn = nil
    local autoGucciSpamTask = nil
    local autoGucciDestroyConn = nil
    local function isNetworkOwner(part) return part and part:IsDescendantOf(workspace) and part:GetNetworkOwner() == LocalPlayer end
    local function cleanupGucciTasks()
        if autoGucciSpamTask then task.cancel(autoGucciSpamTask); autoGucciSpamTask = nil end
        if autoGucciDestroyConn then autoGucciDestroyConn:Disconnect(); autoGucciDestroyConn = nil end
    end
    local function SpawnGucciToy(toyName, hrp)
        local inv = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        if not inv then return nil end
        local spawnCF = hrp.CFrame * CFrame.new(0, 14, 20)
        task.spawn(function()
            pcall(function() ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer(toyName, spawnCF, Vector3.zero) end)
        end)
        local t = tick()
        local spawnedToy = nil
        repeat task.wait(0.1); spawnedToy = inv:FindFirstChild(toyName) until spawnedToy or (tick() - t > 3)
        return spawnedToy
    end
    DefensRightGroup:AddToggle("AutoGucciInvisible", {
        Text = "Auto Gucci (Invisible)",
        Default = false,
        Callback = function(Value)
            autoGucciEnabled = Value
            if Value then
                local GucciThing = nil
                local isActive = false
                local function gucci()
                    if not autoGucciEnabled then return end
                    isActive = true
                    local char = LocalPlayer.Character
                    if not char then isActive = false return end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChild("Humanoid")
                    local head = char:FindFirstChild("Head")
                    local inv = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                    if not (hrp and hum and head and inv) then isActive = false return end
                    cleanupGucciTasks()
                    for _, v in pairs(inv:GetChildren()) do
                        if v.Name == "AutoGucci" or v.Name == "TractorGreen" then
                            pcall(function() ReplicatedStorage.MenuToys.DestroyToy:FireServer(v) end)
                        end
                    end
                    local ragdolled = hum:FindFirstChild("Ragdolled")
                    local isHeld = LocalPlayer:FindFirstChild("IsHeld")
                    while (ragdolled and ragdolled.Value) or (isHeld and isHeld.Value) do task.wait() end
                    for _ = 1, 100 do hum.Sit = true end
                    task.wait(0.1)
                    hum.Sit = false
                    GucciThing = SpawnGucciToy("TractorGreen", hrp)
                    while not GucciThing and autoGucciEnabled do task.wait(0.25); GucciThing = SpawnGucciToy("TractorGreen", hrp) end
                    if not GucciThing then isActive = false return end
                    GucciThing.Name = "AutoGucci"
                    local seat = GucciThing:WaitForChild("VehicleSeat", 3)
                    if not seat then isActive = false return end
                    autoGucciSpamTask = task.spawn(function()
                        local endTime = tick() + 0.5
                        while tick() < endTime and task.wait() and isActive do
                            pcall(function() ReplicatedStorage.CharacterEvents.RagdollRemote:FireServer(hrp, 0) end)
                        end
                    end)
                    local lastSitAttempt = 0
                    while not hum.SeatPart and autoGucciEnabled do
                        if tick() - lastSitAttempt > 0.1 then seat:Sit(hum); lastSitAttempt = tick() end
                        task.wait()
                    end
                    hum.Sit = false
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    hrp.Anchored = true
                    task.spawn(function()
                        repeat task.wait() until not seat:FindFirstChild("SeatWeld")
                        GucciThing:PivotTo(CFrame.new(0, 1e6, 0))
                        local bodyPos = Instance.new("BodyPosition")
                        bodyPos.Position = Vector3.new(0, 1e6, 0)
                        bodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        bodyPos.Parent = GucciThing.PrimaryPart
                    end)
                    hrp.Anchored = false
                    autoGucciDestroyConn = GucciThing.Destroying:Once(function() if autoGucciEnabled then gucci() end end)
                    isActive = false
                end
                gucci()
                if autoGucciConn then autoGucciConn:Disconnect() end
                autoGucciConn = RunService.Heartbeat:Connect(function()
                    if not autoGucciEnabled then if autoGucciConn then autoGucciConn:Disconnect() end return end
                    if isActive then return end
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local hum = char and char:FindFirstChild("Humanoid")
                    if not (hrp and hum) or hum.Health <= 0 then
                        isActive = true
                        local newChar = LocalPlayer.CharacterAdded:Wait()
                        task.wait(0.5); gucci(); return
                    end
                    local isOwner = isNetworkOwner(hrp)
                    local isHeld = LocalPlayer:FindFirstChild("IsHeld")
                    if (not hrp.Anchored and not isOwner) or (isHeld and isHeld.Value) or hum.Sit then gucci() end
                end)
            else
                cleanupGucciTasks()
                if autoGucciConn then autoGucciConn:Disconnect(); autoGucciConn = nil end
                local inv = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                if inv then
                    for _, v in pairs(inv:GetChildren()) do
                        if v.Name == "AutoGucci" or v.Name == "TractorGreen" then
                            pcall(function() ReplicatedStorage.MenuToys.DestroyToy:FireServer(v) end)
                        end
                    end
                end
            end
        end
    })
end

-- ANTI GUCCI (TRAIN)
do
    local antiGucciTrainConn = nil
    local safePositionTrain = nil
    local restoreFramesTrain = 0
    local autoGucciTrainActive = false
    local function startAntiGucciTrain()
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hum = char:WaitForChild("Humanoid")
        local rootPart = char:WaitForChild("HumanoidRootPart")
        safePositionTrain = rootPart.Position
        local folder = workspace.Map.AlwaysHereTweenedObjects
        local train = folder and folder:FindFirstChild("Train")
        local seat
        if train then
            for _, d in ipairs(train:GetDescendants()) do
                if d:IsA("Seat") then seat = d break end
            end
        end
        if seat then rootPart.CFrame = seat.CFrame + Vector3.new(0, 2, 0); seat:Sit(hum) end
        hum:GetPropertyChangedSignal("Jump"):Connect(function()
            if hum.Jump and hum.Sit then restoreFramesTrain = 15; safePositionTrain = rootPart.Position end
        end)
        if antiGucciTrainConn then antiGucciTrainConn:Disconnect() end
        antiGucciTrainConn = RunService.Heartbeat:Connect(function()
            if not rootPart or not hum then return end
            ReplicatedStorage.CharacterEvents.RagdollRemote:FireServer(rootPart, 0)
            if restoreFramesTrain > 0 then rootPart.CFrame = CFrame.new(safePositionTrain); restoreFramesTrain = restoreFramesTrain - 1 end
        end)
        task.spawn(function()
            while hum.Sit do task.wait(1) end
            task.wait(0.5)
            rootPart.CFrame = CFrame.new(safePositionTrain)
        end)
    end
    local function stopAntiGucciTrain()
        if antiGucciTrainConn then antiGucciTrainConn:Disconnect(); antiGucciTrainConn = nil end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum then pcall(function() char:BreakJoints(); hum.Health = 0 end) end
    end
    DefensRightGroup:AddToggle("AntiGucciTrain", {
        Text = "Anti Gucci (Train)",
        Default = false,
        Callback = function(Value)
            autoGucciTrainActive = Value
            if Value then
                startAntiGucciTrain()
                Library:Notify({ Title = "system", Content = "Gucci active (monitoring)", Duration = 3 })
                task.spawn(function()
                    while autoGucciTrainActive do
                        local trainFolder = workspace.Map.AlwaysHereTweenedObjects
                        local trainExists = trainFolder and trainFolder:FindFirstChild("Train")
                        if not trainExists then
                            stopAntiGucciTrain()
                            Library:Notify({ Title = "System", Content = "Train lost", Duration = 3 })
                            local retries = 0
                            repeat task.wait(0.2); retries = retries + 1; trainFolder = workspace.Map.AlwaysHereTweenedObjects
                            until (trainFolder and trainFolder:FindFirstChild("Train")) or retries > 25 or not autoGucciTrainActive
                            if autoGucciTrainActive and trainFolder and trainFolder:FindFirstChild("Train") then
                                startAntiGucciTrain()
                                Library:Notify({ Title = "System", Content = "Train restored.", Duration = 3 })
                            end
                        end
                        task.wait(0.5)
                    end
                end)
            else
                autoGucciTrainActive = false
                stopAntiGucciTrain()
                Library:Notify({ Title = "System", Content = "Gucci disabled.", Duration = 3 })
            end
        end
    })
end

-- LAST GRABBER UI
do
    local lastGrabberLabel = DefensGroup:AddLabel("<b>Last Grabber:</b> <font color='#888888'>None</font>")
end
DefensGroup:AddButton({
    Text = "📋 Copy Last Grabber Name",
    Callback = function()
        if _G.__moggLastGrabberName and _G.__moggLastGrabberName ~= "None" then
            pcall(function() setclipboard(_G.__moggLastGrabberName) end)
            Library:Notify({Title = "Copied", Content = _G.__moggLastGrabberName, Duration = 2})
        else
            Library:Notify({Title = "Empty", Content = "Никто тебя ещё не брал", Duration = 2})
        end
    end
})

-- ============================================================
--  TARGET
-- ============================================================
local TargetGroup = Tabs.Target:AddLeftGroupbox("Server List & Actions")
local function getPlayerNames()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local isHome = false
            local plotItems = workspace:FindFirstChild("PlotItems")
            if plotItems then
                local playersInPlots = plotItems:FindFirstChild("PlayersInPlots")
                if playersInPlots and playersInPlots:FindFirstChild(player.Name) then isHome = true end
            end
            local entry = player.DisplayName .. " (" .. player.Name .. ")"
            if isHome then entry = "🏠 " .. entry end
            table.insert(names, entry)
        end
    end
    if #names == 0 then table.insert(names, "Нет игроков") end
    return names
end
local function extractUsername(entry)
    if entry == "Нет игроков" then return nil end
    local cleaned = entry:gsub("^🏠 ", "")
    return cleaned:match("%((.-)%)") or cleaned
end
local playerDropdown = TargetGroup:AddDropdown("ServerList", {
    Text = "Выберите игрока",
    Values = getPlayerNames(),
    Default = 1,
    Callback = function(value)
        if value ~= "Нет игроков" then
            _G.SelectedPlayer = extractUsername(value)
            Library:Notify({ Title = "Target", Description = "Выбран: " .. value, Time = 2 })
        else _G.SelectedPlayer = nil end
    end
})
TargetGroup:AddButton({
    Text = "🔄 Обновить список",
    Func = function()
        local newList = getPlayerNames()
        local currentSelection = _G.SelectedPlayer
        local stillExists = false
        for _, entry in ipairs(newList) do
            if extractUsername(entry) == currentSelection then stillExists = true; break end
        end
        playerDropdown:SetValues(newList)
        if stillExists then
            for _, entry in ipairs(newList) do
                if extractUsername(entry) == currentSelection then playerDropdown:SetValue(entry); break end
            end
        else _G.SelectedPlayer = nil; playerDropdown:SetValue(nil) end
        Library:Notify({ Title = "Server List", Description = "Список обновлён", Time = 2 })
    end
})

-- FAST KICK BLOBMAN
_G.loopKickBlobActive = false
local function LoopKickBlobFunction(targetName)
    local blobLoop = true
    local GE = ReplicatedStorage:WaitForChild("GrabEvents")
    local REMOTE_DELAY = 0.002
    local lastRemote = 0
    local function BlobGrabKickHard()
        local target = Players:FindFirstChild(targetName)
        if not target then return end
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hum = char:WaitForChild("Humanoid")
        local seat = hum.SeatPart
        if not seat or seat.Parent.Name ~= "CreatureBlobman" then return end
        local blob = seat.Parent
        local blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
        local scriptObj = blob:WaitForChild("BlobmanSeatAndOwnerScript")
        local CG = scriptObj:WaitForChild("CreatureGrab")
        local CD = scriptObj:WaitForChild("CreatureDrop")
        local R_Det = blob:WaitForChild("RightDetector")
        local savedPos = blobRoot.CFrame
        local dragging = false
        local grabStartTime = 0
        while blobLoop and _G.loopKickBlobActive do
            local currentTarget = Players:FindFirstChild(targetName)
            if not currentTarget then break end
            char = LocalPlayer.Character
            hum = char and char:FindFirstChild("Humanoid")
            seat = hum and hum.SeatPart
            if not seat or seat.Parent.Name ~= "CreatureBlobman" then break end
            blob = seat.Parent
            blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
            local tChar = currentTarget.Character
            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHum = tChar and tChar:FindFirstChild("Humanoid")
            if tRoot and tHum and tHum.Health > 0 and blobRoot then
                tRoot.Velocity = Vector3.zero
                if not dragging then
                    blobRoot.CFrame = tRoot.CFrame
                    blobRoot.Velocity = Vector3.zero
                    if tick() - lastRemote >= REMOTE_DELAY then
                        lastRemote = tick()
                        pcall(function()
                            tHum.PlatformStand = true
                            tHum.Sit = true
                            GE.SetNetworkOwner:FireServer(tRoot, blobRoot.CFrame)
                            GE.DestroyGrabLine:FireServer(tRoot)
                        end)
                    end
                    if grabStartTime == 0 then grabStartTime = tick() end
                    if tick() - grabStartTime > 0.35 then
                        dragging = true; grabStartTime = 0
                        blobRoot.CFrame = savedPos; blobRoot.Velocity = Vector3.zero
                    end
                else
                    blobRoot.CFrame = savedPos
                    blobRoot.Velocity = Vector3.zero
                    local lockPos = savedPos * CFrame.new(0, 23, 0)
                    tRoot.CFrame = lockPos
                    tHum.PlatformStand = true
                    tHum.Sit = true
                    if tick() - lastRemote >= REMOTE_DELAY then
                        lastRemote = tick()
                        pcall(function()
                            GE.SetNetworkOwner:FireServer(tRoot, lockPos)
                            GE.DestroyGrabLine:FireServer(tRoot)
                            local weld = R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld")
                            if weld then CD:FireServer(weld); CG:FireServer(R_Det, tRoot, weld) end
                        end)
                    end
                end
            else dragging = false; grabStartTime = 0 end
            RunService.Heartbeat:Wait()
        end
        if blobRoot then blobRoot.CFrame = savedPos; blobRoot.Velocity = Vector3.zero end
    end
    task.spawn(BlobGrabKickHard)
end
TargetGroup:AddLabel("────────── Fast Kick ──────────")
local fastKickTask = nil
TargetGroup:AddToggle("FastKickBlobman", {
    Text = "⚡ Fast Kick Blobman",
    Default = false,
    Callback = function(Value)
        local targetName = _G.SelectedPlayer
        if Value then
            if not targetName or targetName == "" then
                Library:Notify({ Title = "Fast Kick", Content = "Сначала выбери игрока", Duration = 3 })
                Library.Toggles.FastKickBlobman:SetValue(false); return
            end
            _G.loopKickBlobActive = true
            fastKickTask = task.spawn(function() LoopKickBlobFunction(targetName) end)
            Library:Notify({ Title = "Fast Kick Blobman", Content = "Запущен: " .. targetName, Duration = 2 })
        else
            _G.loopKickBlobActive = false
            if fastKickTask then task.cancel(fastKickTask); fastKickTask = nil end
            Library:Notify({ Title = "Fast Kick Blobman", Content = "Остановлен", Duration = 2 })
        end
    end
})

-- DESTROY GUCCI
local destroyGucciActive = false
local destroyGucciTask = nil
local function destroyPlayerGucci(targetPlayer)
    if not targetPlayer or targetPlayer == LocalPlayer then return false end
    local folderName = targetPlayer.Name .. "SpawnedInToys"
    local toysFolder = workspace:FindFirstChild(folderName)
    if not toysFolder then return false end
    for _, obj in ipairs(toysFolder:GetChildren()) do
        if obj.Name == "CreatureBlobman" or obj.Name == "Gucci" then
            local seat = obj:FindFirstChild("VehicleSeat") or obj:FindFirstChildWhichIsA("VehicleSeat", true)
            if seat then
                local myChar = LocalPlayer.Character
                if not myChar then return false end
                local myHum = myChar:FindFirstChild("Humanoid")
                local myRoot = myChar:FindFirstChild("HumanoidRootPart")
                if not myHum or not myRoot then return false end
                local safeSpot = myRoot.CFrame
                myRoot.CFrame = seat.CFrame
                myRoot.Velocity = Vector3.zero
                seat:Sit(myHum)
                task.wait(0.3)
                if myHum.SeatPart == seat then
                    myHum.Sit = false
                    task.wait(0.1)
                    myRoot.CFrame = safeSpot
                    task.wait(0.5)
                    obj:Destroy()
                    return true
                else myRoot.CFrame = safeSpot end
            end
        end
    end
    return false
end
local function StartDestroyGucciLoop()
    while destroyGucciActive do
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                pcall(function() destroyPlayerGucci(player) end)
            end
        end
        task.wait(2)
    end
end
TargetGroup:AddLabel("────────── Snos Gucci ──────────")
TargetGroup:AddToggle("DestroyGucci", {
    Text = "Destroy Gucci (all players)",
    Default = false,
    Callback = function(Value)
        destroyGucciActive = Value
        if Value then
            destroyGucciTask = task.spawn(StartDestroyGucciLoop)
            Library:Notify({ Title = "Snos Gucci", Content = "Запущено (все игроки)", Duration = 3 })
        else
            if destroyGucciTask then task.cancel(destroyGucciTask); destroyGucciTask = nil end
            Library:Notify({ Title = "Snos Gucci", Content = "Остановлено", Duration = 2 })
        end
    end
})

-- AUTO SIT BLOBMAN
_G.AutoSitBlobZ = false
local function AutoSitLoop()
    while _G.AutoSitBlobZ do
        local plr = LocalPlayer
        local char = plr.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        if not hrp or not hum then task.wait(1); continue end
        if hum.SeatPart then task.wait(0.5); continue end
        local folderName = plr.Name .. "SpawnedInToys"
        local folder = workspace:FindFirstChild(folderName)
        local blob = folder and folder:FindFirstChild("CreatureBlobman")
        if not blob then
            task.spawn(function()
                pcall(function() ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer("CreatureBlobman", hrp.CFrame, Vector3.zero) end)
            end)
            if not folder then folder = workspace:WaitForChild(folderName, 5) end
            if folder then blob = folder:WaitForChild("CreatureBlobman", 5) end
        end
        if blob then
            local seat = blob:WaitForChild("VehicleSeat", 5)
            if seat then
                local t = tick()
                repeat
                    if not hum.SeatPart then
                        hrp.CFrame = seat.CFrame + Vector3.new(0, 1, 0)
                        hrp.Velocity = Vector3.zero
                        seat:Sit(hum)
                    end
                    RunService.Heartbeat:Wait()
                until hum.SeatPart == seat or tick() - t > 1.5 or not _G.AutoSitBlobZ
            end
        end
        task.wait(0.5)
    end
end
TargetGroup:AddLabel("────────── Auto Sit ──────────")
TargetGroup:AddToggle("AutoSitBlobmanToggle", {
    Text = "Auto Sit Blobman",
    Default = false,
    Callback = function(Value)
        _G.AutoSitBlobZ = Value
        if Value then
            task.spawn(AutoSitLoop)
            Library:Notify({ Title = "Auto Sit", Content = "Запущено", Duration = 2 })
        else Library:Notify({ Title = "Auto Sit", Content = "Остановлено", Duration = 2 }) end
    end
})

-- TRACE TO TARGET
do
    local traceBeam = nil
    local traceConnection = nil
    local traceEnabled = false
    local traceColor = Color3.fromRGB(255, 0, 0)
    local part0, part1
    local function StartTrace(targetName)
        local targetPlayer = Players:FindFirstChild(targetName)
        if not targetPlayer then return end
        part0 = Instance.new("Part")
        part0.Anchored = true; part0.CanCollide = false; part0.Transparency = 1
        part0.Size = Vector3.new(0.1, 0.1, 0.1); part0.Parent = workspace
        part1 = Instance.new("Part")
        part1.Anchored = true; part1.CanCollide = false; part1.Transparency = 1
        part1.Size = Vector3.new(0.1, 0.1, 0.1); part1.Parent = workspace
        local att0 = Instance.new("Attachment", part0)
        local att1 = Instance.new("Attachment", part1)
        traceBeam = Instance.new("Beam")
        traceBeam.Attachment0 = att0
        traceBeam.Attachment1 = att1
        traceBeam.Color = ColorSequence.new(traceColor)
        traceBeam.Width0 = 0.6; traceBeam.Width1 = 0.6
        traceBeam.LightEmission = 0; traceBeam.LightInfluence = 1
        traceBeam.FaceCamera = true; traceBeam.Parent = workspace
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local targetHRP = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        traceConnection = RunService.RenderStepped:Connect(function()
            if not traceEnabled then
                if traceBeam then traceBeam:Destroy() end
                if part0 then part0:Destroy() end
                if part1 then part1:Destroy() end
                return
            end
            if not Players:FindFirstChild(targetName) then
                if traceBeam then traceBeam:Destroy() end
                if part0 then part0:Destroy() end
                if part1 then part1:Destroy() end
                return
            end
            if LocalPlayer.Character and targetPlayer.Character then
                myHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if myHRP and targetHRP and part0 and part1 then
                    part0.Position = myHRP.Position
                    part1.Position = targetHRP.Position
                    traceBeam.Color = ColorSequence.new(traceColor)
                end
            end
        end)
    end
    TargetGroup:AddLabel("────────── Trace ──────────")
    TargetGroup:AddToggle("TraceToTargetToggle", {
        Text = "Trace to Target",
        Default = false,
        Callback = function(Value)
            traceEnabled = Value
            if Value then
                local targetName = _G.SelectedPlayer
                if targetName and targetName ~= "" then StartTrace(targetName)
                else traceEnabled = false; Library.Toggles.TraceToTargetToggle:SetValue(false) end
            else
                if traceConnection then traceConnection:Disconnect(); traceConnection = nil end
                if traceBeam then traceBeam:Destroy(); traceBeam = nil end
                if part0 then part0:Destroy(); part0 = nil end
                if part1 then part1:Destroy(); part1 = nil end
            end
        end
    })
    TargetGroup:AddLabel("Trace Color"):AddColorPicker("TraceColorPicker", {
        Default = Color3.fromRGB(255, 0, 0),
        Title = "Trace Color",
        Callback = function(Value) traceColor = Value end
    })
end

-- ============================================================
--  KICKAROUND
-- ============================================================
_G.kickaroundConnection = nil
_G.kickaroundActive = false
_G.fixHeight = 23
_G.spawnPoint = Vector3.new(0, 0, 0)
_G.orbitRadius = 12
_G.orbitSpeed = 1.0
_G.spamInterval = 0.06
_G.grabWeld = nil
_G.stateConn = nil

local function stopKickaround()
    if _G.kickaroundConnection then _G.kickaroundConnection:Disconnect(); _G.kickaroundConnection = nil end
    if _G.stateConn then _G.stateConn:Disconnect(); _G.stateConn = nil end
    if _G.grabWeld and _G.grabWeld.Parent then _G.grabWeld:Destroy() end
    _G.grabWeld = nil
    for _, obj in ipairs({_G.targetBodyPosition, _G.targetBodyPosition2, _G.targetBodyGyro, _G.targetBodyVelocity, _G.targetBodyVelocity2}) do
        if obj and obj.Parent then obj:Destroy() end
    end
    _G.targetBodyPosition = nil; _G.targetBodyPosition2 = nil
    _G.targetBodyGyro = nil; _G.targetBodyVelocity = nil; _G.targetBodyVelocity2 = nil
    for part, state in pairs(_G.targetParts or {}) do
        if part and part.Parent then part.CanCollide = state end
    end
    _G.targetParts = {}
    if _G.targetHumanoid and _G.originalJumpPower then
        _G.targetHumanoid.JumpPower = _G.originalJumpPower
        _G.targetHumanoid.PlatformStand = false
        _G.targetHumanoid.Sit = false
    end
    _G.targetHumanoid = nil; _G.originalJumpPower = nil
    _G.kickaroundActive = false
    Library:Notify({ Title = "Kickaround", Content = "Остановлен", Duration = 2 })
end

local function startKickaround()
    local targetName = _G.SelectedPlayer
    if not targetName or targetName == "Нет игроков" then
        Library:Notify({ Title = "Ошибка", Content = "Сначала выберите игрока", Duration = 3 }); return
    end
    local target = game.Players:FindFirstChild(targetName)
    if not target then Library:Notify({ Title = "Ошибка", Content = "Игрок не найден", Duration = 3 }); return end
    if not target.Character then Library:Notify({ Title = "Ошибка", Content = "Нет персонажа", Duration = 3 }); return end
    local myChar = LocalPlayer.Character
    if not myChar then Library:Notify({ Title = "Ошибка", Content = "Нет персонажа", Duration = 3 }); return end
    local hum = myChar:FindFirstChildOfClass("Humanoid")
    if not hum or not hum.SeatPart then Library:Notify({ Title = "Ошибка", Content = "Сядь на блобмена!", Duration = 3 }); return end
    local blob = hum.SeatPart.Parent
    if not blob or blob.Name ~= "CreatureBlobman" then Library:Notify({ Title = "Ошибка", Content = "Не на блобмене!", Duration = 3 }); return end
    local blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
    if not blobRoot then Library:Notify({ Title = "Ошибка", Content = "Нет root блобмена", Duration = 3 }); return end
    local tChar = target.Character
    local tRoot = tChar:FindFirstChild("HumanoidRootPart")
    if not tRoot then Library:Notify({ Title = "Ошибка", Content = "Нет HRP цели", Duration = 3 }); return end
    local tHum = tChar:FindFirstChildOfClass("Humanoid")
    if not tHum or tHum.Health <= 0 then Library:Notify({ Title = "Ошибка", Content = "Цель мертва", Duration = 3 }); return end
    local RS = game:GetService("ReplicatedStorage")
    local GE = RS:FindFirstChild("GrabEvents")
    if not GE then return end
    local SetNetworkOwner = GE:FindFirstChild("SetNetworkOwner")
    local CreateGrabLineFn = GE:FindFirstChild("CreateGrabLine")
    local DestroyGrabLine = GE:FindFirstChild("DestroyGrabLine")
    if not SetNetworkOwner or not CreateGrabLineFn or not DestroyGrabLine then return end
    local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
    if not scriptObj then return end
    local CG = scriptObj:FindFirstChild("CreatureGrab")
    local CD = scriptObj:FindFirstChild("CreatureDrop")
    if not CG or not CD then return end
    local R_Det = blob:FindFirstChild("RightDetector")
    local L_Det = blob:FindFirstChild("LeftDetector")
    if not R_Det or not L_Det then return end
    local R_Weld = R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld")
    local L_Weld = L_Det:FindFirstChild("LeftWeld") or L_Det:FindFirstChildWhichIsA("Weld")
    if not R_Weld or not L_Weld then return end
    local targetPos = tRoot.Position + Vector3.new(0, 2, 0)
    blobRoot.CFrame = CFrame.new(targetPos)
    blobRoot.AssemblyLinearVelocity = Vector3.zero
    blobRoot.AssemblyAngularVelocity = Vector3.zero
    task.wait(0.2)
    pcall(function() CG:FireServer(R_Det, tRoot, R_Weld) end)
    task.wait(0.3)
    if _G.grabWeld then _G.grabWeld:Destroy() end
    local weld = Instance.new("Weld")
    weld.Part0 = R_Det; weld.Part1 = tRoot
    weld.C0 = CFrame.new(0, 0, 0); weld.C1 = CFrame.new(0, 0, 0)
    weld.Parent = R_Det
    _G.grabWeld = weld
    local spawnPos = Vector3.new(_G.spawnPoint.X, _G.spawnPoint.Y + _G.fixHeight, _G.spawnPoint.Z)
    blobRoot.CFrame = CFrame.new(spawnPos)
    blobRoot.AssemblyLinearVelocity = Vector3.zero
    blobRoot.AssemblyAngularVelocity = Vector3.zero
    task.wait(0.2)
    if _G.grabWeld then _G.grabWeld:Destroy(); _G.grabWeld = nil end
    _G.targetParts = {}
    for _, part in ipairs(tChar:GetDescendants()) do
        if part:IsA("BasePart") then
            _G.targetParts[part] = part.CanCollide
            part.CanCollide = false
        end
    end
    if _G.targetBodyPosition then _G.targetBodyPosition:Destroy() end
    local bp1 = Instance.new("BodyPosition")
    bp1.Name = "TargetHoldBP1"
    bp1.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bp1.P = 1e6; bp1.D = 10000
    bp1.Parent = tRoot; bp1.Position = spawnPos
    _G.targetBodyPosition = bp1
    if _G.targetBodyPosition2 then _G.targetBodyPosition2:Destroy() end
    local bp2 = Instance.new("BodyPosition")
    bp2.Name = "TargetHoldBP2"
    bp2.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bp2.P = 1e6; bp2.D = 10000
    bp2.Parent = tRoot; bp2.Position = spawnPos
    _G.targetBodyPosition2 = bp2
    if _G.targetBodyGyro then _G.targetBodyGyro:Destroy() end
    local bg = Instance.new("BodyGyro")
    bg.Name = "TargetHoldBG"
    bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bg.P = 1e6; bg.D = 10000
    bg.Parent = tRoot; bg.CFrame = CFrame.new(spawnPos)
    _G.targetBodyGyro = bg
    if _G.targetBodyVelocity then _G.targetBodyVelocity:Destroy() end
    local bv1 = Instance.new("BodyVelocity")
    bv1.Name = "TargetHoldBV1"
    bv1.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv1.P = 1e6; bv1.Velocity = Vector3.zero
    bv1.Parent = tRoot
    _G.targetBodyVelocity = bv1
    if _G.targetBodyVelocity2 then _G.targetBodyVelocity2:Destroy() end
    local bv2 = Instance.new("BodyVelocity")
    bv2.Name = "TargetHoldBV2"
    bv2.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv2.P = 1e6; bv2.Velocity = Vector3.zero
    bv2.Parent = tRoot
    _G.targetBodyVelocity2 = bv2
    _G.targetHumanoid = tHum
    _G.originalJumpPower = tHum.JumpPower
    tHum.JumpPower = 0
    tHum.PlatformStand = true
    tHum.Sit = true
    if _G.stateConn then _G.stateConn:Disconnect() end
    _G.stateConn = tHum.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Running or
           newState == Enum.HumanoidStateType.FallingDown or newState == Enum.HumanoidStateType.GettingUp or
           newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Freefall then
            tHum:ChangeState(Enum.HumanoidStateType.Physics)
            tHum.PlatformStand = true
            tHum.Sit = true
        end
    end)
    local angle = 0
    local orbitRadius = _G.orbitRadius or 12
    local orbitSpeed = _G.orbitSpeed or 1.0
    local baseOrbitHeight = spawnPos.Y + 5
    local spamInterval = _G.spamInterval or 0.06
    local lastSpamTime = 0
    _G.kickaroundConnection = RunService.Heartbeat:Connect(function(dt)
        if not target or not target.Parent then stopKickaround(); return end
        local tCharNow = target.Character
        if not tCharNow then stopKickaround(); return end
        local tRootNow = tCharNow:FindFirstChild("HumanoidRootPart")
        local tHumNow = tCharNow:FindFirstChildOfClass("Humanoid")
        if not tRootNow or not tHumNow or tHumNow.Health <= 0 then stopKickaround(); return end
        local fixedPos = spawnPos
        tRootNow.CFrame = CFrame.new(fixedPos)
        tRootNow.AssemblyLinearVelocity = Vector3.zero
        tRootNow.AssemblyAngularVelocity = Vector3.zero
        if _G.targetBodyPosition then _G.targetBodyPosition.Position = fixedPos end
        if _G.targetBodyPosition2 then _G.targetBodyPosition2.Position = fixedPos end
        if _G.targetBodyGyro then _G.targetBodyGyro.CFrame = CFrame.new(fixedPos) end
        if _G.targetBodyVelocity then _G.targetBodyVelocity.Velocity = Vector3.zero end
        if _G.targetBodyVelocity2 then _G.targetBodyVelocity2.Velocity = Vector3.zero end
        tHumNow.PlatformStand = true
        tHumNow.Sit = true
        angle = angle + orbitSpeed * dt * 1.5
        local x = fixedPos.X + orbitRadius * math.cos(angle)
        local z = fixedPos.Z + math.sin(angle) * orbitRadius
        local blobPos = Vector3.new(x, baseOrbitHeight, z)
        blobRoot.CFrame = CFrame.lookAt(blobPos, fixedPos)
        blobRoot.AssemblyLinearVelocity = Vector3.zero
        blobRoot.AssemblyAngularVelocity = Vector3.zero
        local now = tick()
        if now - lastSpamTime >= spamInterval then
            lastSpamTime = now
            pcall(function()
                SetNetworkOwner:FireServer(tRootNow, CFrame.new(fixedPos))
                CG:FireServer(R_Det, tRootNow, R_Weld)
                CG:FireServer(L_Det, tRootNow, L_Weld)
                CreateGrabLineFn:FireServer(tRootNow, R_Det)
                CreateGrabLineFn:FireServer(tRootNow, L_Det)
                DestroyGrabLine:FireServer(tRootNow)
            end)
        end
    end)
    _G.kickaroundActive = true
    Library:Notify({ Title = "Kickaround", Content = "Запущен", Duration = 3 })
end

TargetGroup:AddLabel("────────── Kickaround ──────────")
TargetGroup:AddToggle("KickaroundToggle", {
    Text = "Kickaround",
    Default = false,
    Callback = function(value)
        if value then startKickaround() else stopKickaround() end
    end
})
TargetGroup:AddSlider("HeightSlider", { Text = "Height (studs)", Default = 23, Min = 5, Max = 100, Rounding = 0, Suffix = " studs", Callback = function(v) _G.fixHeight = v end })
TargetGroup:AddSlider("OrbitRadiusSlider", { Text = "Orbit Radius", Default = 12, Min = 2, Max = 30, Rounding = 0, Suffix = " studs", Callback = function(v) _G.orbitRadius = v end })
TargetGroup:AddSlider("OrbitSpeedSlider", { Text = "Orbit Speed", Default = 1.0, Min = 0.2, Max = 3.0, Rounding = 1, Suffix = "x", Callback = function(v) _G.orbitSpeed = v end })
TargetGroup:AddSlider("SpamIntervalSlider", { Text = "Spam Interval (sec)", Default = 0.06, Min = 0.02, Max = 0.1, Rounding = 3, Suffix = "s", Callback = function(v) _G.spamInterval = v end })

-- RIGHT TARGET GROUP
local TargetRightGroup = Tabs.Target:AddRightGroupbox("Server List (Right) & Extra")
local playerDropdownRight = TargetRightGroup:AddDropdown("ServerListRight", {
    Text = "Выберите игрока (справа)",
    Values = getPlayerNames(),
    Default = 1,
    Callback = function(value)
        if value ~= "Нет игроков" then
            _G.SelectedPlayer = extractUsername(value)
            Library:Notify({ Title = "Target (Right)", Description = "Выбран: " .. value, Time = 2 })
        else _G.SelectedPlayer = nil end
    end
})
TargetRightGroup:AddButton({
    Text = "🔄 Обновить список",
    Func = function()
        local newList = getPlayerNames()
        local currentSelection = _G.SelectedPlayer
        local stillExists = false
        for _, entry in ipairs(newList) do
            if extractUsername(entry) == currentSelection then stillExists = true; break end
        end
        playerDropdown:SetValues(newList)
        playerDropdownRight:SetValues(newList)
        if stillExists then
            for _, entry in ipairs(newList) do
                if extractUsername(entry) == currentSelection then
                    playerDropdown:SetValue(entry); playerDropdownRight:SetValue(entry); break
                end
            end
        else
            _G.SelectedPlayer = nil
            playerDropdown:SetValue(nil); playerDropdownRight:SetValue(nil)
        end
        Library:Notify({ Title = "Server List", Description = "Список обновлён", Time = 2 })
    end
})

-- RESONANCE KICKS
local RS = ReplicatedStorage
local LP = LocalPlayer
local RunSvc = RunService
local ownershipKickActive = false
local ownershipKickTask = nil
local ownershipRagdollActive = false
local ownershipRagdollTask = nil
local loopKillActive = false
local loopKillTask = nil
local snowballRagdollActive = false
local snowballRagdollTask = nil
local antiAntiKickActive = false
local antiAntiKickTask = nil
local targetNotifyConnections = {}
local FWC = function(Parent, Name, Time) return Parent:FindFirstChild(Name) or Parent:WaitForChild(Name, Time or 3) end

local function OwnershipKickFunction(targetName)
    local target = Players:FindFirstChild(targetName)
    if not target then return end
    local GE = RS:WaitForChild("GrabEvents")
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local savedPos = myRoot.CFrame
    local dragging = false
    local grabStartTime = 0
    local checkStartTime = 0
    local currentFPS = 60
    local fpsConnection = RunService.RenderStepped:Connect(function(dt) currentFPS = 1 / dt end)
    local bodyPos, bodyGyro = nil, nil
    local function cleanupBodies()
        pcall(function()
            if bodyPos then bodyPos:Destroy() bodyPos = nil end
            if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
        end)
    end
    local function createBodies(targetRoot, pos)
        cleanupBodies()
        for _, v in pairs(targetRoot:GetChildren()) do
            if v:IsA("BodyPosition") or v:IsA("BodyGyro") then v:Destroy() end
        end
        bodyPos = Instance.new("BodyPosition")
        bodyPos.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bodyPos.D = 100
        bodyPos.Position = pos
        bodyPos.Parent = targetRoot
        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bodyPos.D = 100
        bodyGyro.CFrame = CFrame.new(pos)
        bodyGyro.Parent = targetRoot
    end
    while ownershipKickActive do
        local currentTarget = Players:FindFirstChild(target.Name)
        if not currentTarget or not currentTarget.Parent then cleanupBodies(); break end
        myChar = LocalPlayer.Character
        myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tChar = currentTarget.Character
        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
        local tHum = tChar and tChar:FindFirstChild("Humanoid")
        if tRoot and tHum and tHum.Health > 0 and myRoot then
            if not dragging then
                myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 3)
                cleanupBodies()
                checkStartTime = 0
                pcall(function()
                    tHum.PlatformStand = true
                    tHum.Sit = true
                    GE.SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                    GE.SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                    GE.DestroyGrabLine:FireServer(tRoot)
                end)
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
                if grabStartTime == 0 then grabStartTime = tick() end
                if tick() - grabStartTime > 0.35 then
                    dragging = true; grabStartTime = 0; checkStartTime = tick()
                    local lockPos = savedPos * CFrame.new(0, 10, 0)
                    createBodies(tRoot, lockPos.Position)
                end
            else
                myRoot.CFrame = savedPos
                local lockPos = savedPos * CFrame.new(0, 10, 0)
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
                if bodyPos and bodyPos.Parent then
                    bodyPos.Position = lockPos.Position
                    if bodyGyro then bodyGyro.CFrame = lockPos end
                else createBodies(tRoot, lockPos.Position) end
                tHum.PlatformStand = true
                pcall(function()
                    if currentFPS > 200 then
                        GE.SetNetworkOwner:FireServer(tRoot, lockPos)
                        GE.SetNetworkOwner:FireServer(tRoot, lockPos)
                        GE.DestroyGrabLine:FireServer(tRoot)
                    elseif currentFPS >= 155 and currentFPS <= 200 then
                        GE.SetNetworkOwner:FireServer(tRoot, lockPos)
                        GE.SetNetworkOwner:FireServer(tRoot, lockPos)
                        GE.SetNetworkOwner:FireServer(tRoot, lockPos)
                        GE.DestroyGrabLine:FireServer(tRoot)
                    else
                        GE.SetNetworkOwner:FireServer(tRoot, lockPos)
                        GE.SetNetworkOwner:FireServer(tRoot, lockPos)
                        GE.SetNetworkOwner:FireServer(tRoot, lockPos)
                        GE.SetNetworkOwner:FireServer(tRoot, lockPos)
                        GE.DestroyGrabLine:FireServer(tRoot)
                    end
                end)
                if checkStartTime > 0 and tick() - checkStartTime > 0.30 then
                    local currentDist = (tRoot.Position - lockPos.Position).Magnitude
                    if currentDist > 10 then
                        dragging = false; grabStartTime = 0; checkStartTime = 0
                        cleanupBodies()
                        myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 3)
                    else checkStartTime = tick() end
                end
            end
        else
            dragging = false; grabStartTime = 0; checkStartTime = 0; cleanupBodies()
        end
        RunService.Heartbeat:Wait()
    end
    fpsConnection:Disconnect()
    cleanupBodies()
    if myRoot then myRoot.CFrame = savedPos end
end

local function PalletRagdollFunction(targetName)
    local target = Players:FindFirstChild(targetName)
    if not target or not target.Character then return end
    local GE = RS:WaitForChild("GrabEvents")
    local skyPos = CFrame.new(0, 800000, 0)
    RS.MenuToys.SpawnToyRemoteFunction:InvokeServer("PalletLightBrown", skyPos, Vector3.zero)
    local pallet
    repeat
        pallet = workspace:FindFirstChild(LP.Name.."SpawnedInToys") and workspace[LP.Name.."SpawnedInToys"]:FindFirstChild("PalletLightBrown")
        RunSvc.Heartbeat:Wait()
    until pallet or not ownershipRagdollActive
    if not pallet then return end
    local mainPart = pallet:FindFirstChild("SoundPart")
    if not mainPart then return end
    mainPart.CanCollide = false
    mainPart.Anchored = false
    local function claim(part)
        GE.SetNetworkOwner:FireServer(part, part.CFrame)
        GE.CreateGrabLine:FireServer(part, Vector3.zero, part.Position, false)
        GE.DestroyGrabLine:FireServer(part)
    end
    claim(mainPart)
    while ownershipRagdollActive do
        for i = 1, 20 do RunSvc.Heartbeat:Wait() end
        if not target or not target.Parent or not target.Character then break end
        local head = target.Character:FindFirstChild("Head")
        if not head then continue end
        local targetPos = head.Position
        mainPart.CFrame = CFrame.new(targetPos.X, targetPos.Y + 0.2, targetPos.Z)
        mainPart.AssemblyLinearVelocity = Vector3.zero
        mainPart.AssemblyAngularVelocity = Vector3.new(1000, 1000, 1000)
        claim(mainPart)
        mainPart.CanCollide = true
        for i = 1, 3 do RunSvc.Heartbeat:Wait() end
        mainPart.CanCollide = false
        mainPart.CFrame = skyPos
        mainPart.AssemblyAngularVelocity = Vector3.zero
    end
    if pallet then
        pcall(function() RS.MenuToys.DestroyToy:FireServer(pallet) end)
        if pallet.Parent then pallet:Destroy() end
    end
end

local function LoopKillFunction(targetName)
    local target = Players:FindFirstChild(targetName)
    if not target then return end
    local GE = RS:WaitForChild("GrabEvents")
    while loopKillActive and target and target.Parent do
        if not target.Character then task.wait(0.5); continue end
        local myChar = LP.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tChar = target.Character
        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
        local tHum = tChar and tChar:FindFirstChild("Humanoid")
        if tRoot and tHum and tHum.Health > 0 and myRoot then
            local currentPos = myRoot.CFrame
            local attackStart = tick()
            while tick() - attackStart < 0.35 and loopKillActive do
                if not tRoot.Parent then break end
                myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 2)
                myRoot.Velocity = Vector3.zero
                pcall(function()
                    GE.SetNetworkOwner:FireServer(tRoot, myRoot.CFrame)
                    tHum:ChangeState(Enum.HumanoidStateType.Dead)
                    tHum.Health = 0
                    GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                    GE.DestroyGrabLine:FireServer(tRoot)
                end)
                RunSvc.Heartbeat:Wait()
            end
            if myRoot then myRoot.CFrame = currentPos; myRoot.Velocity = Vector3.zero end
            task.wait(1.2)
        else task.wait(0.5) end
    end
end

local function SnowballRagdollFunction(targetName)
    local target = Players:FindFirstChild(targetName)
    if not target then return end
    local SpawnRemote = RS:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
    while snowballRagdollActive do
        if not target or not target.Parent then break end
        local tChar = target.Character
        local torso = tChar and (tChar:FindFirstChild("UpperTorso") or tChar:FindFirstChild("Torso"))
        if not torso then continue end
        pcall(function()
            local offset = Vector3.new(math.random(-30, 30)/100, math.random(-30, 30)/100, math.random(-30, 30)/100)
            SpawnRemote:InvokeServer("BallSnowball", torso.CFrame * CFrame.new(offset), Vector3.zero)
        end)
        local folder = workspace:FindFirstChild(LP.Name .. "SpawnedInToys")
        if folder then
            for _, snowball in pairs(folder:GetChildren()) do
                if snowball.Name == "BallSnowball" and snowball.Parent then
                    local part = snowball.PrimaryPart or snowball:FindFirstChildWhichIsA("BasePart")
                    if part then
                        local offset = Vector3.new(math.random(-30, 30)/100, math.random(-30, 30)/100, math.random(-30, 30)/100)
                        part.CFrame = torso.CFrame * CFrame.new(offset)
                        part.AssemblyLinearVelocity = Vector3.zero
                        part.AssemblyAngularVelocity = Vector3.zero
                    end
                end
            end
        end
        task.wait()
    end
end

TargetRightGroup:AddLabel("────────── Resonance Kicks ──────────")
TargetRightGroup:AddToggle("OwnershipKickToggle", {
    Text = "Ownership Kick",
    Default = false,
    Callback = function(Value)
        ownershipKickActive = Value
        local targetName = _G.SelectedPlayer
        if Value then
            if targetName and targetName ~= "" then
                ownershipKickTask = task.spawn(function() OwnershipKickFunction(targetName) end)
            else ownershipKickActive = false end
        else
            if ownershipKickTask then task.cancel(ownershipKickTask) ownershipKickTask = nil end
            local target = Players:FindFirstChild(_G.SelectedPlayer or "")
            if target and target.Character then
                local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
                if tRoot then
                    for _, v in pairs(tRoot:GetChildren()) do
                        if v:IsA("BodyPosition") or v:IsA("BodyGyro") then pcall(function() v:Destroy() end) end
                    end
                    pcall(function()
                        tRoot.AssemblyLinearVelocity = Vector3.zero
                        tRoot.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            end
        end
    end
})
TargetRightGroup:AddToggle("OwnershipRagdollToggle", {
    Text = "Pallet Ragdoll",
    Default = false,
    Callback = function(Value)
        ownershipRagdollActive = Value
        local targetName = _G.SelectedPlayer
        if Value then
            if targetName and targetName ~= "" then
                ownershipRagdollTask = task.spawn(function() PalletRagdollFunction(targetName) end)
            else ownershipRagdollActive = false end
        else
            if ownershipRagdollTask then task.cancel(ownershipRagdollTask) ownershipRagdollTask = nil end
            task.spawn(function()
                local toysFolder = workspace:FindFirstChild(LP.Name.."SpawnedInToys")
                if toysFolder then
                    local pallet = toysFolder:FindFirstChild("PalletLightBrown")
                    if pallet then
                        pcall(function() RS.MenuToys.DestroyToy:FireServer(pallet) end)
                        if pallet.Parent then pallet:Destroy() end
                    end
                end
            end)
        end
    end
})
TargetRightGroup:AddToggle("LoopKillToggle", {
    Text = "Loop Kill",
    Default = false,
    Callback = function(Value)
        loopKillActive = Value
        local targetName = _G.SelectedPlayer
        if Value then
            if targetName and targetName ~= "" then
                loopKillTask = task.spawn(function() LoopKillFunction(targetName) end)
            else loopKillActive = false end
        else if loopKillTask then task.cancel(loopKillTask) loopKillTask = nil end end
    end
})
TargetRightGroup:AddToggle("SnowballRagdollToggle", {
    Text = "Snowball Ragdoll",
    Default = false,
    Callback = function(Value)
        snowballRagdollActive = Value
        local targetName = _G.SelectedPlayer
        if Value then
            if targetName and targetName ~= "" then
                snowballRagdollTask = task.spawn(function() SnowballRagdollFunction(targetName) end)
            else snowballRagdollActive = false end
        else if snowballRagdollTask then task.cancel(snowballRagdollTask) snowballRagdollTask = nil end end
    end
})
TargetRightGroup:AddLabel("────────── Anti-Anti ──────────")
TargetRightGroup:AddToggle("RemoveAntiKickToggle", {
    Text = "Remove Anti Kick",
    Default = false,
    Callback = function(Value)
        antiAntiKickActive = Value
        local SetNetOwner = RS.GrabEvents.SetNetworkOwner
        if Value then
            local targetName = _G.SelectedPlayer
            if targetName and targetName ~= "" then
                antiAntiKickTask = task.spawn(function()
                    local function invis_touch(part, cf) SetNetOwner:FireServer(part, cf) end
                    local function CheckAndYeet(toy)
                        local part = toy:FindFirstChild("SoundPart")
                        if part then
                            invis_touch(part, part.CFrame)
                            if part:FindFirstChild("PartOwner") and part.PartOwner.Value == LP.Name then
                                part.CFrame = CFrame.new(0, 1000, 0)
                            end
                        end
                    end
                    while antiAntiKickActive do
                        local target = Players:FindFirstChild(targetName)
                        if target then
                            local spawned = workspace:FindFirstChild(target.Name .. "SpawnedInToys")
                            if spawned then
                                if spawned:FindFirstChild("NinjaKunai") then CheckAndYeet(spawned.NinjaKunai) end
                                if spawned:FindFirstChild("NinjaShuriken") then CheckAndYeet(spawned.NinjaShuriken) end
                                if spawned:FindFirstChild("AntiKick") then CheckAndYeet(spawned.AntiKick) end
                            end
                        end
                        task.wait(0.1)
                    end
                end)
            else antiAntiKickActive = false end
        else if antiAntiKickTask then task.cancel(antiAntiKickTask) antiAntiKickTask = nil end end
    end
})
TargetRightGroup:AddToggle("TargetNotifyToggle", {
    Text = "Leave/Join Target Notify",
    Default = false,
    Callback = function(Value)
        if Value then
            local targetName = _G.SelectedPlayer
            if not targetName or targetName == "" then
                Library:Notify({ Title = "Target Notify", Content = "Сначала выбери игрока", Duration = 3 }); return
            end
            local target = Players:FindFirstChild(targetName)
            if target then
                Library:Notify({ Title = "Target Notify", Content = target.DisplayName .. " (@" .. target.Name .. ") в игре", Duration = 3 })
            end
            targetNotifyConnections["Added"] = Players.PlayerAdded:Connect(function(player)
                if player.Name == _G.SelectedPlayer then
                    Library:Notify({ Title = "Target Notify", Content = player.DisplayName .. " зашёл", Duration = 3 })
                end
            end)
            targetNotifyConnections["Removing"] = Players.PlayerRemoving:Connect(function(player)
                if player.Name == _G.SelectedPlayer then
                    Library:Notify({ Title = "Target Notify", Content = player.DisplayName .. " вышел", Duration = 3 })
                end
            end)
        else
            for _, conn in pairs(targetNotifyConnections) do if conn then conn:Disconnect() end end
            targetNotifyConnections = {}
        end
    end
})

-- KICK NOTIFY
do
    Players.PlayerRemoving:Connect(function(plr)
        local playerName = plr.DisplayName .. " (@" .. plr.Name .. ")"
        local stamp = os.date("%H:%M:%S")
        Library:Notify({ Title = "🔔 Kick Notify", Content = playerName .. "\n" .. stamp, Duration = 4 })
    end)
end

-- HOUSE KICK
do
    local function stripBarriers()
        local plots = workspace:FindFirstChild("Plots")
        if not plots then return end
        for _, obj in ipairs(plots:GetDescendants()) do
            if obj:IsA("BasePart") and (obj.Name == "PlotBarrier" or obj.Name == "Barrier") then
                obj.CanCollide = false
                obj.CanTouch = false
                obj.CanQuery = false
            end
        end
    end
    TargetGroup:AddLabel("────────── House Kick ──────────")
    TargetGroup:AddButton({ Text = "🚧 Strip Barriers Now", Func = function() stripBarriers() end })
end

-- =====================================================
--  MOVEMENT
-- =====================================================
do
    local MovementGroup = Tabs.Movement:AddLeftGroupbox("Управление блобменом")
    local spinBlobmenConnection = nil
    local spinBlobmenActive = false
    local spinSpeed = 30
    MovementGroup:AddToggle("SpinToggle", {
        Text = "Spin Blobmen",
        Default = false,
        Callback = function(value)
            spinBlobmenActive = value
            if value then
                if spinBlobmenConnection then spinBlobmenConnection:Disconnect(); spinBlobmenConnection = nil end
                spinBlobmenConnection = RunService.Heartbeat:Connect(function(dt)
                    if not spinBlobmenActive then return end
                    local char = LocalPlayer.Character
                    if not char then return end
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if not hum or not hum.SeatPart then return end
                    local blob = hum.SeatPart.Parent
                    if not blob or blob.Name ~= "CreatureBlobman" then return end
                    local blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
                    if not blobRoot then return end
                    local speed = spinSpeed or 30
                    blobRoot.CFrame = blobRoot.CFrame * CFrame.Angles(0, (speed / 100) * 8 * math.pi * dt, 0)
                    blobRoot.AssemblyAngularVelocity = Vector3.zero
                end)
            else
                if spinBlobmenConnection then spinBlobmenConnection:Disconnect(); spinBlobmenConnection = nil end
            end
        end
    })
    MovementGroup:AddSlider("SpinSpeedSlider", { Text = "Spin Speed", Default = 30, Min = 1, Max = 100, Rounding = 0, Suffix = "%", Callback = function(v) spinSpeed = v end })
    local blobSpeedValue = 16
    local blobCustomSpeedEnabled = false
    local function applyBlobSpeed(speed)
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or not hum.SeatPart then return end
        local blob = hum.SeatPart.Parent
        if not blob or blob.Name ~= "CreatureBlobman" then return end
        local blobHum = blob:FindFirstChildOfClass("Humanoid")
        if blobHum then blobHum.WalkSpeed = blobCustomSpeedEnabled and speed or 16 end
    end
    MovementGroup:AddToggle("BlobCustomSpeedToggle", {
        Text = "Enable Custom Speed",
        Default = false,
        Callback = function(value)
            blobCustomSpeedEnabled = value
            applyBlobSpeed(value and (blobSpeedValue or 16) or 16)
        end
    })
    MovementGroup:AddSlider("SpeedBlobmanSlider", {
        Text = "Speed Blobman", Default = 16, Min = 1, Max = 200, Rounding = 0, Suffix = " ws",
        Callback = function(value)
            blobSpeedValue = value
            if blobCustomSpeedEnabled then applyBlobSpeed(value) end
        end
    })
end

-- =============================================
--  MISC
-- =============================================
local MiscGroupLeft = Tabs.Misc:AddLeftGroupbox("Камера и ESP")
MiscGroupLeft:AddToggle("ThirdPersonToggle", {
    Text = "Third Person",
    Default = false,
    Callback = function(value)
        if value then LocalPlayer.CameraMode = Enum.CameraMode.Classic; LocalPlayer.CameraMaxZoomDistance = 100
        else LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson; LocalPlayer.CameraMaxZoomDistance = 0.5 end
    end
})
do
    local smoothPCLDs = {}
    local espColor = Color3.fromRGB(255, 60, 60)
    local rainbowPCLD = false
    local pcldConns = {}
    local function createSmoothPCLD(original)
        if smoothPCLDs[original] then return end
        original.Transparency = 1
        local box = Instance.new("Part")
        box.Name = "PCLD_Box"
        box.Size = original.Size
        box.CFrame = original.CFrame
        box.Anchored = true
        box.CanCollide = false
        box.CanTouch = false
        box.CanQuery = false
        box.CastShadow = false
        box.Material = Enum.Material.Neon
        box.Color = espColor
        box.Transparency = 0.45
        box.Parent = workspace
        local outline = Instance.new("SelectionBox")
        outline.Adornee = box
        outline.LineThickness = 0.02
        outline.Color3 = espColor
        outline.Transparency = 0.1
        outline.Parent = box
        local data = { box = box, outline = outline, original = original, tween = nil }
        smoothPCLDs[original] = data
        task.spawn(function()
            local lastPos = original.Position
            while box.Parent and original.Parent do
                local pos = original.Position
                local cf = original.CFrame
                if (pos - lastPos).Magnitude > 0.02 then
                    lastPos = pos
                    if data.tween then data.tween:Cancel() end
                    data.tween = TweenService:Create(box, TweenInfo.new(0.18, Enum.EasingStyle.Linear), {CFrame = cf})
                    data.tween:Play()
                end
                task.wait(0.03)
            end
        end)
    end
    local function removeSmoothPCLD(original)
        local d = smoothPCLDs[original]
        if not d then return end
        if d.tween then d.tween:Cancel() end
        if d.box then d.box:Destroy() end
        smoothPCLDs[original] = nil
    end
    local function clearAllSmoothPCLDs()
        for _, d in pairs(smoothPCLDs) do
            if d.tween then d.tween:Cancel() end
            if d.box then d.box:Destroy() end
        end
        smoothPCLDs = {}
    end
    local function pcldToggle(on)
        if on then
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj.Name == "PlayerCharacterLocationDetector" then createSmoothPCLD(obj) end
            end
            table.insert(pcldConns, workspace.ChildAdded:Connect(function(child)
                if child.Name == "PlayerCharacterLocationDetector" then task.wait(0.1); createSmoothPCLD(child) end
            end))
            table.insert(pcldConns, workspace.ChildRemoved:Connect(function(child)
                if child.Name == "PlayerCharacterLocationDetector" then removeSmoothPCLD(child) end
            end))
        else
            for _, c in ipairs(pcldConns) do pcall(function() c:Disconnect() end) end
            pcldConns = {}
            clearAllSmoothPCLDs()
        end
    end
    MiscGroupLeft:AddToggle("PCLD_ESP_Toggle", { Text = "PCLD ESP (Smooth)", Default = false, Callback = pcldToggle })
    MiscGroupLeft:AddLabel("ESP Color"):AddColorPicker("PCLDColor", {
        Default = espColor, Title = "PCLD ESP Color",
        Callback = function(v)
            espColor = v
            if not rainbowPCLD then
                for _, d in pairs(smoothPCLDs) do
                    if d.box then d.box.Color = v end
                    if d.outline then d.outline.Color3 = v end
                end
            end
        end
    })
    MiscGroupLeft:AddToggle("RainbowPCLD", { Text = "Rainbow PCLD", Default = false, Callback = function(v) rainbowPCLD = v end })
end

-- LINE LAG
do
    local lineLagActive = false
    local lineLagTask = nil
    local lineAmount = 50
    local lineIntensity = 50
    local LineLagGroup = Tabs.Misc:AddRightGroupbox("🔴 Line Lag")
    LineLagGroup:AddSlider("LineAmount", { Text = "Lag Amount", Default = 50, Min = 1, Max = 30000, Rounding = 0, Suffix = " lines", Callback = function(Value) lineAmount = Value; lineIntensity = Value end })
    LineLagGroup:AddButton({
        Text = "💥 Line Lag (Using Amount)",
        Func = function()
            local SpawnLocation = workspace:FindFirstChild("SpawnLocation")
            if not SpawnLocation then return end
            for i = 1, lineAmount do
                pcall(function()
                    CreateGrabLine:FireServer(SpawnLocation, CFrame.new(SpawnLocation.Position.X, 1e9, SpawnLocation.Position.Z) * CFrame.Angles(math.rad(1e9), math.rad(1e9), math.rad(1e9)))
                end)
            end
        end,
        DoubleClick = false
    })
    LineLagGroup:AddButton({
        Text = "💥 Line Lag (Descendants)",
        Func = function()
            for _, object in ipairs(workspace:GetDescendants()) do
                if object:IsA("BasePart") and object.Parent ~= LocalPlayer.Character then
                    local cf = object.CFrame * CFrame.new(math.random(-lineIntensity, lineIntensity), 1e9, math.random(-lineIntensity, lineIntensity)) * CFrame.Angles(math.rad(math.random(0, 360)), math.rad(math.random(0, 360)), math.rad(math.random(0, 360)))
                    pcall(function() CreateGrabLine:FireServer(object, cf) end)
                end
            end
        end,
        DoubleClick = false
    })
    LineLagGroup:AddToggle("JustLoopLag", {
        Text = "Just Loop-Lag",
        Default = false,
        Callback = function(Value)
            lineLagActive = Value
            if Value then
                if lineLagTask then task.cancel(lineLagTask) end
                lineLagTask = task.spawn(function()
                    while lineLagActive do
                        RunService.RenderStepped:Wait()
                        task.defer(function()
                            pcall(function()
                                CreateGrabLine:FireServer(workspace.SpawnLocation, CFrame.new(0, 9e9, 0))
                                CreateGrabLine:FireServer(workspace.SpawnLocation, CFrame.new(0, 8e9, 0))
                                CreateGrabLine:FireServer(workspace.SpawnLocation, CFrame.new(0, 7e9, 0))
                                CreateGrabLine:FireServer(workspace.SpawnLocation, CFrame.new(0, 6e9, 0))
                            end)
                        end)
                    end
                end)
            else if lineLagTask then task.cancel(lineLagTask); lineLagTask = nil end end
        end
    })
end

-- PACKET LAG
do
    local packetLagActive = false
    local packetLagTask = nil
    local packetLagRepeats = 1
    local sentPackets = 0
    local redeemedPackets = 0
    local PacketString = "metaballs metaballs metaballs metaballs metaballs metaballs metaballs metaballs"
    local PacketStringLen = string.len(PacketString)
    local function CalculateRepeats(Value)
        local TargetBytes = Value * 1024 * 1024
        local Repeats = math.floor(TargetBytes / PacketStringLen)
        packetLagRepeats = math.max(1, Repeats)
    end
    local PacketLagGroup = Tabs.Misc:AddLeftGroupbox("🛜 Packet Lag")
    local sentLabel = PacketLagGroup:AddLabel("🛜🔼 Sent packets: 0")
    local redeemedLabel = PacketLagGroup:AddLabel("🛜🔽 Redeemed packets: 0")
    PacketLagGroup:AddSlider("PacketsSize", { Text = "Size of Packets (MB)", Default = 0.1, Min = 0.01, Max = 1.6, Rounding = 2, Suffix = " MB", Callback = function(Value) CalculateRepeats(Value) end })
    PacketLagGroup:AddToggle("PacketLagServer", {
        Text = "Packet Lag Server",
        Default = false,
        Callback = function(Value)
            packetLagActive = Value
            if Value then
                if packetLagTask then task.cancel(packetLagTask) end
                packetLagTask = task.spawn(function()
                    while packetLagActive do
                        pcall(function() ReplicatedStorage.GrabEvents.ExtendGrabLine:FireServer(string.rep(PacketString, packetLagRepeats)) end)
                        sentPackets = sentPackets + 1
                        sentLabel:SetText("🛜🔼 Sent packets: " .. tostring(sentPackets))
                        task.wait(0.1)
                    end
                end)
            else if packetLagTask then task.cancel(packetLagTask); packetLagTask = nil end end
        end
    })
    CalculateRepeats(0.1)
    ReplicatedStorage.GrabEvents.ExtendGrabLine.OnClientEvent:Connect(function(arg1, data)
        if typeof(data) == "string" then
            local StringLen = string.len(data)
            if StringLen > 300 then
                redeemedPackets = redeemedPackets + 1
                redeemedLabel:SetText("🛜🔽 Redeemed packets: " .. tostring(redeemedPackets))
                local SizeRounded = math.round((StringLen / (1024 * 1024)) * 1000) / 1000
                Library:Notify({ Title = "Packet Lag Detected", Content = "Source: " .. tostring(arg1) .. "\nSize: " .. tostring(SizeRounded) .. " MB", Duration = 5 })
            end
        end
    end)
end

-- JERK OFF (из Ragalic — теперь в Misc)
do
    local MiscJerkGroup = Tabs.Misc:AddRightGroupbox("🎭 Jerk Off")
    local playJerkOffActive = false
    local jerkOffAnimTrack = nil
    local jerkOffAnimId = "rbxassetid://168268306"
    local selectedKey = Enum.KeyCode.Q
    local function startJerkOff()
        local plr = LocalPlayer
        local char = plr.Character or plr.CharacterAdded:Wait()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = hum
        end
        local anim = Instance.new("Animation")
        anim.AnimationId = jerkOffAnimId
        jerkOffAnimTrack = animator:LoadAnimation(anim)
        jerkOffAnimTrack.Priority = Enum.AnimationPriority.Action
        jerkOffAnimTrack:Play()
        task.spawn(function()
            while playJerkOffActive do
                task.wait(0.1)
                if jerkOffAnimTrack and jerkOffAnimTrack.IsPlaying then
                    jerkOffAnimTrack.TimePosition = 0.3
                end
            end
        end)
    end
    local function stopJerkOff()
        if jerkOffAnimTrack then
            jerkOffAnimTrack:Stop()
            jerkOffAnimTrack = nil
        end
    end
    MiscJerkGroup:AddToggle("JerkOffToggle", {
        Text = "Jerk Off",
        Default = false,
        Callback = function(on)
            playJerkOffActive = on
            if on then startJerkOff() else stopJerkOff() end
        end
    })
    MiscJerkGroup:AddDropdown("JerkKey", {
        Text = "Toggle Key",
        Values = { "Q", "E", "R", "T" },
        Default = 1,
        Callback = function(v)
            selectedKey = Enum.KeyCode[v]
        end
    })
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == selectedKey then
            playJerkOffActive = not playJerkOffActive
            if playJerkOffActive then startJerkOff() else stopJerkOff() end
            if Library.Toggles and Library.Toggles.JerkOffToggle then
                pcall(function() Library.Toggles.JerkOffToggle:SetValue(playJerkOffActive) end)
            end
        end
    end)
end

-- DETECT PACKETS
do
    local packetConnections = {}
    local lastNotify = 0
    local COOLDOWN = 0.5
    local function resolveSender(args)
        for _, v in ipairs(args) do
            if typeof(v) == "Instance" then
                if v:IsA("Player") then return v end
                local model = v:IsA("Model") and v or v:FindFirstAncestorOfClass("Model")
                if model then
                    local plr = Players:GetPlayerFromCharacter(model)
                    if plr then return plr end
                end
            end
        end
        return LocalPlayer
    end
    local function shortenString(str)
        if #str <= 80 then return str end
        return str:sub(1, 80) .. "... (+" .. tostring(#str - 80) .. " chars)"
    end
    local function summarizeTable(tbl)
        local preview, count = {}, 0
        for _, v in pairs(tbl) do
            count = count + 1
            if count <= 5 then
                local s, val = pcall(tostring, v)
                table.insert(preview, s and val or "unknown")
            end
        end
        return "table[" .. count .. "] { " .. table.concat(preview, ", ") .. (count > 5 and " ... }" or " }")
    end
    local function compressArgs(args)
        local seen, summary = {}, {}
        for _, v in ipairs(args) do
            local key
            if typeof(v) == "string" then key = "str:" .. shortenString(v)
            elseif typeof(v) == "Instance" then
                local className, name = "Unknown", "Unknown"
                pcall(function() className = v.ClassName end)
                pcall(function() name = v.Name end)
                key = "inst:" .. className .. "(" .. name .. ")"
            elseif typeof(v) == "table" then key = "tbl:" .. summarizeTable(v)
            else
                local s, strVal = pcall(tostring, v)
                key = typeof(v) .. ":" .. (s and strVal or "unprintable")
            end
            seen[key] = (seen[key] or 0) + 1
        end
        for k, count in pairs(seen) do
            if count > 1 then table.insert(summary, k .. " x" .. count)
            else table.insert(summary, k) end
        end
        return summary
    end
    local function handlePacketEvent(eventType, remoteName, ...)
        local args = {...}
        local totalBytes = 0
        for _, v in ipairs(args) do
            if typeof(v) == "string" then totalBytes = totalBytes + #v end
        end
        if tick() - lastNotify < COOLDOWN then return end
        lastNotify = tick()
        local sender = resolveSender(args)
        local senderName = "Unknown"
        if sender then
            local s, name = pcall(function() return sender.DisplayName or sender.Name end)
            if s then senderName = name end
            if sender == LocalPlayer then senderName = senderName .. " (You)" end
        end
        local mbSize = totalBytes / (1024 * 1024)
        local summarized = compressArgs(args)
        local argsStr = #summarized > 0 and table.concat(summarized, "\n") or "None"
        Library:Notify({
            Title = string.format("[%s] %s", eventType, remoteName),
            Content = string.format("Player: %s\nSize: %.4f MB\nArgs:\n%s", senderName, mbSize, argsStr),
            Duration = 6
        })
    end
    local function checkAndHookBlobRemote(child)
        if child:IsA("RemoteEvent") and child.Name == "RelayClientAnimation" then
            local parent = child.Parent
            if parent and parent.Name == "BlobmanAnimations" then
                local grandParentName = parent.Parent and parent.Parent.Name or "Unknown"
                table.insert(packetConnections, child.OnClientEvent:Connect(function(...) handlePacketEvent("Blob", grandParentName, ...) end))
            end
        end
    end
    local function startPacketDetector()
        if #packetConnections > 0 then return end
        task.spawn(function()
            local grabEvents = ReplicatedStorage:WaitForChild("GrabEvents", 5)
            if grabEvents then
                local grabRemote = grabEvents:WaitForChild("ExtendGrabLine", 5)
                if grabRemote then
                    table.insert(packetConnections, grabRemote.OnClientEvent:Connect(function(...) handlePacketEvent("Grab", "ExtendGrabLine", ...) end))
                end
            end
        end)
        for _, child in ipairs(workspace:GetDescendants()) do checkAndHookBlobRemote(child) end
        table.insert(packetConnections, workspace.DescendantAdded:Connect(checkAndHookBlobRemote))
    end
    local function stopPacketDetector()
        for _, conn in ipairs(packetConnections) do
            if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end
        end
        table.clear(packetConnections)
    end
    MiscGroupLeft:AddToggle("GrabRemoteDetector", {
        Text = "Detect Packets",
        Default = false,
        Callback = function(Value)
            if Value then
                startPacketDetector()
                Library:Notify({ Title = "Enabled", Content = "Packet detector active", Duration = 4 })
            else
                stopPacketDetector()
                Library:Notify({ Title = "Disabled", Content = "Packet detector off", Duration = 4 })
            end
        end
    })
end

-- =============================================
-- VISUALS
-- =============================================
do
    local VisualsGroup = Tabs.Visuals:AddLeftGroupbox("Настройки камеры")
    VisualsGroup:AddSlider("FOVSlider", { Text = "FOV", Default = 70, Min = 70, Max = 120, Rounding = 0, Suffix = "°", Callback = function(value) workspace.CurrentCamera.FieldOfView = value end })
    VisualsGroup:AddToggle("ThirdPersonVisualToggle", {
        Text = "Third Person",
        Default = false,
        Callback = function(value)
            if value then LocalPlayer.CameraMode = Enum.CameraMode.Classic; LocalPlayer.CameraMaxZoomDistance = 100
            else LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson; LocalPlayer.CameraMaxZoomDistance = 0.5 end
        end
    })
    VisualsGroup:AddToggle("RainbowToggle", {
        Text = "🌈 Rainbow",
        Default = false,
        Callback = function(value)
            _G.rainbow = value
            if value then
                if _G.rainbowThread then task.cancel(_G.rainbowThread) end
                _G.rainbowThread = task.spawn(function()
                    while _G.rainbow do
                        local char = LocalPlayer.Character
                        if char then
                            local pos = char:FindFirstChild("HumanoidRootPart")
                            if pos then
                                local hue = (os.clock() % 5) / 5
                                local color = Color3.fromHSV(hue, 1, 1)
                                for _, part in ipairs(char:GetDescendants()) do
                                    if part:IsA("BasePart") then part.Color = color end
                                end
                            end
                        end
                        task.wait(0.05)
                    end
                end)
            end
        end
    })

    -- DARK BLUE NIGHT
    do
        local Lighting = game:GetService("Lighting")
        local shaderActive, applyConn, savedProps, disabledEffects, ourAtmosphere = false, nil, nil, {}, nil
        local SAVED_PROPS = { "Ambient","OutdoorAmbient","Brightness","ClockTime","GeographicLatitude","GlobalShadows","EnvironmentDiffuseScale","EnvironmentSpecularScale","ExposureCompensation","FogColor","FogStart","FogEnd","ColorShift_Top","ColorShift_Bottom" }
        local darkBlue = { Brightness=1.2, ClockTime=0, ExposureCompensation=0.15, GlobalShadows=true, EnvironmentDiffuseScale=0.6, EnvironmentSpecularScale=0.6, Ambient=Color3.fromRGB(100,125,180), OutdoorAmbient=Color3.fromRGB(130,155,210), ColorShift_Top=Color3.fromRGB(40,90,200), ColorShift_Bottom=Color3.fromRGB(15,40,110), FogColor=Color3.fromRGB(30,55,110), FogStart=60, FogEnd=400 }
        local atmoSettings = { Color=Color3.fromRGB(60,100,180), Decay=Color3.fromRGB(25,45,95), Density=0.35, Haze=0.4, Glare=0.25, Offset=0.1 }
        local function saveOriginal() savedProps = {}; for _, p in ipairs(SAVED_PROPS) do pcall(function() savedProps[p] = Lighting[p] end) end end
        local function restoreOriginal() if not savedProps then return end; for p, v in pairs(savedProps) do pcall(function() Lighting[p] = v end) end; savedProps = nil end
        local function neutralize()
            disabledEffects = {}
            for _, child in ipairs(Lighting:GetChildren()) do
                if child:IsA("Atmosphere") and child.Name ~= "MoggBlueAtmo" then
                    disabledEffects[child] = { Density = child.Density, Offset = child.Offset }
                    child.Density = 0; child.Offset = 0
                elseif child:IsA("ColorCorrectionEffect") or child:IsA("BloomEffect") or child:IsA("SunRaysEffect") or child:IsA("BlurEffect") or child:IsA("DepthOfFieldEffect") then
                    disabledEffects[child] = { Enabled = child.Enabled }
                    child.Enabled = false
                end
            end
        end
        local function restoreExisting()
            for inst, props in pairs(disabledEffects) do
                if inst and inst.Parent then
                    for k, v in pairs(props) do pcall(function() inst[k] = v end) end
                end
            end
            disabledEffects = {}
        end
        local function makeEffects()
            local cc = Lighting:FindFirstChild("MoggBlueCC")
            if not cc then cc = Instance.new("ColorCorrectionEffect"); cc.Name = "MoggBlueCC"; cc.Parent = Lighting end
            cc.Brightness = 0.1; cc.Contrast = 0.05; cc.Saturation = 0.05
            cc.TintColor = Color3.fromRGB(190, 215, 255); cc.Enabled = true
            local bloom = Lighting:FindFirstChild("MoggBlueBloom")
            if not bloom then bloom = Instance.new("BloomEffect"); bloom.Name = "MoggBlueBloom"; bloom.Parent = Lighting end
            bloom.Intensity = 0.5; bloom.Size = 24; bloom.Threshold = 0.95; bloom.Enabled = true
            if not ourAtmosphere then
                ourAtmosphere = Lighting:FindFirstChild("MoggBlueAtmo")
                if not ourAtmosphere then ourAtmosphere = Instance.new("Atmosphere"); ourAtmosphere.Name = "MoggBlueAtmo"; ourAtmosphere.Parent = Lighting end
            end
        end
        local function removeEffects()
            for _, n in ipairs({ "MoggBlueCC", "MoggBlueBloom", "MoggBlueAtmo" }) do
                local o = Lighting:FindFirstChild(n); if o then o:Destroy() end
            end
            ourAtmosphere = nil
        end
        local function applyOnce()
            if not shaderActive then return end
            for k, v in pairs(darkBlue) do pcall(function() Lighting[k] = v end) end
            if ourAtmosphere and ourAtmosphere.Parent then
                ourAtmosphere.Color = atmoSettings.Color
                ourAtmosphere.Decay = atmoSettings.Decay
                ourAtmosphere.Density = atmoSettings.Density
                ourAtmosphere.Haze = atmoSettings.Haze
                ourAtmosphere.Glare = atmoSettings.Glare
                ourAtmosphere.Offset = atmoSettings.Offset
            end
        end
        local function enable()
            if shaderActive then return end
            shaderActive = true
            saveOriginal(); neutralize(); makeEffects(); applyOnce()
            if applyConn then applyConn:Disconnect() end
            applyConn = RunService.Heartbeat:Connect(applyOnce)
        end
        local function disable()
            if not shaderActive then return end
            shaderActive = false
            if applyConn then applyConn:Disconnect() applyConn = nil end
            restoreExisting(); restoreOriginal(); removeEffects()
        end
        local BlueGroup = Tabs.Visuals:AddLeftGroupbox("🌌 Dark Blue Night")
        BlueGroup:AddToggle("DarkBlueNightToggle", {
            Text = "Dark Blue Night",
            Default = false,
            Callback = function(v)
                if v then enable() else disable() end
                Library:Notify({ Title = "🌌 Shader", Content = v and "ON" or "OFF", Duration = 2 })
            end
        })
        BlueGroup:AddSlider("BlueDarkBrightness", { Text = "Яркость карты", Default = 1.2, Min = 0.2, Max = 10, Rounding = 2, Callback = function(v) darkBlue.Brightness = v end })
        BlueGroup:AddSlider("BlueDarkAmbient", { Text = "Ambient R", Default = 100, Min = 0, Max = 255, Rounding = 0, Callback = function(v) darkBlue.Ambient = Color3.fromRGB(v, math.clamp(v*1.2,0,255), math.clamp(v*1.8,0,255)) end })
        BlueGroup:AddSlider("BlueDarkOutdoorAmbient", { Text = "Outdoor Ambient R", Default = 130, Min = 0, Max = 255, Rounding = 0, Callback = function(v) darkBlue.OutdoorAmbient = Color3.fromRGB(v, math.clamp(v*1.2,0,255), math.clamp(v*1.7,0,255)) end })
        BlueGroup:AddSlider("BlueDarkEnvDiffuse", { Text = "Environment Diffuse", Default = 0.6, Min = 0, Max = 3, Rounding = 2, Callback = function(v) darkBlue.EnvironmentDiffuseScale = v end })
        BlueGroup:AddSlider("BlueDarkExposure", { Text = "Exposure", Default = 0.15, Min = -2, Max = 3, Rounding = 2, Callback = function(v) darkBlue.ExposureCompensation = v end })
        BlueGroup:AddSlider("BlueDarkFogStart", { Text = "Начало тумана", Default = 60, Min = 0, Max = 500, Rounding = 0, Suffix = " studs", Callback = function(v) darkBlue.FogStart = v end })
        BlueGroup:AddSlider("BlueDarkFogEnd", { Text = "Конец тумана", Default = 400, Min = 50, Max = 2000, Rounding = 0, Suffix = " studs", Callback = function(v) darkBlue.FogEnd = v end })
        BlueGroup:AddSlider("BlueDarkAtmoDensity", { Text = "Плотность атмосферы", Default = 0.35, Min = 0, Max = 1, Rounding = 2, Callback = function(v) atmoSettings.Density = v end })
        BlueGroup:AddSlider("BlueDarkAtmoHaze", { Text = "Дымка (Haze)", Default = 0.4, Min = 0, Max = 10, Rounding = 2, Callback = function(v) atmoSettings.Haze = v end })
        BlueGroup:AddLabel("Цвет тумана"):AddColorPicker("BlueDarkTint", { Default = Color3.fromRGB(30, 55, 110), Title = "Цвет тумана", Callback = function(c) darkBlue.FogColor = c; atmoSettings.Color = c end })
        BlueGroup:AddButton({ Text = "🌌 Пресет: Густая синяя ночь", Func = function()
            darkBlue.Brightness = 0.6
            darkBlue.Ambient = Color3.fromRGB(60, 80, 130)
            darkBlue.OutdoorAmbient = Color3.fromRGB(80, 100, 160)
            darkBlue.FogStart = 10; darkBlue.FogEnd = 150
            atmoSettings.Density = 0.7; atmoSettings.Haze = 1.2
        end })
        BlueGroup:AddButton({ Text = "🌌 Пресет: Лёгкая синева", Func = function()
            darkBlue.Brightness = 2
            darkBlue.Ambient = Color3.fromRGB(140, 160, 210)
            darkBlue.OutdoorAmbient = Color3.fromRGB(170, 190, 230)
            darkBlue.FogStart = 120; darkBlue.FogEnd = 900
            atmoSettings.Density = 0.25; atmoSettings.Haze = 0.3
        end })
        BlueGroup:AddButton({ Text = "🌌 Пресет: Максимальная яркость", Func = function()
            darkBlue.Brightness = 5
            darkBlue.Ambient = Color3.fromRGB(200, 220, 255)
            darkBlue.OutdoorAmbient = Color3.fromRGB(220, 235, 255)
            darkBlue.EnvironmentDiffuseScale = 1.5
            darkBlue.ExposureCompensation = 0.5
            darkBlue.FogStart = 200; darkBlue.FogEnd = 1500
            atmoSettings.Density = 0.15; atmoSettings.Haze = 0.2
        end })
    end

    -- SKYBOX
    do
        local LightingService = game:GetService("Lighting")
        local SKYBOXES = {
            ["Off"] = nil,
            Aurora = { SkyboxBk="rbxassetid://10237", SkyboxDn="rbxassetid://2557", SkyboxFt="rbxassetid://13478", SkyboxLf="rbxassetid://12276", SkyboxRt="rbxassetid://9643", SkyboxUp="rbxassetid://13936" },
            Beautiful = { SkyboxBk="rbxassetid://128821", SkyboxDn="rbxassetid://6430", SkyboxFt="rbxassetid://128750", SkyboxLf="rbxassetid://117220", SkyboxRt="rbxassetid://114696", SkyboxUp="rbxassetid://58189" },
            Blue = { SkyboxBk="rbxassetid://60226", SkyboxDn="rbxassetid://24996", SkyboxFt="rbxassetid://69622", SkyboxLf="rbxassetid://77910", SkyboxRt="rbxassetid://57321", SkyboxUp="rbxassetid://46037" },
            Blossom = { SkyboxBk="rbxassetid://271042516", SkyboxDn="rbxassetid://271077243", SkyboxFt="rbxassetid://271042556", SkyboxLf="rbxassetid://271042310", SkyboxRt="rbxassetid://271042467", SkyboxUp="rbxassetid://271077958" },
            ClearSkies = { SkyboxBk="rbxassetid://5644", SkyboxDn="rbxassetid://5644", SkyboxFt="rbxassetid://5644", SkyboxLf="rbxassetid://5644", SkyboxRt="rbxassetid://5644", SkyboxUp="rbxassetid://4073" },
            Galaxy = { SkyboxBk="rbxassetid://15983996673", SkyboxDn="rbxassetid://15983996673", SkyboxFt="rbxassetid://15983996673", SkyboxLf="rbxassetid://15983996673", SkyboxRt="rbxassetid://15983996673", SkyboxUp="rbxassetid://15983996673" },
            Night = { SkyboxBk="rbxassetid://44179", SkyboxDn="rbxassetid://52685", SkyboxFt="rbxassetid://110627", SkyboxLf="rbxassetid://76775", SkyboxRt="rbxassetid://89703", SkyboxUp="rbxassetid://72355" },
            Purple = { SkyboxBk="rbxassetid://13694952867", SkyboxDn="rbxassetid://13694968325", SkyboxFt="rbxassetid://13694980654", SkyboxLf="rbxassetid://13694998113", SkyboxRt="rbxassetid://13695002700", SkyboxUp="rbxassetid://13695007103" },
            Red = { SkyboxBk="rbxassetid://82331", SkyboxDn="rbxassetid://41406", SkyboxFt="rbxassetid://62426", SkyboxLf="rbxassetid://66358", SkyboxRt="rbxassetid://64978", SkyboxUp="rbxassetid://50845" },
            Spooky = { SkyboxBk="rbxassetid://62379", SkyboxDn="rbxassetid://6545", SkyboxFt="rbxassetid://67830", SkyboxLf="rbxassetid://52578", SkyboxRt="rbxassetid://47993", SkyboxUp="rbxassetid://128769" },
            Universe = { SkyboxBk="rbxassetid://72728", SkyboxDn="rbxassetid://7417", SkyboxFt="rbxassetid://94579", SkyboxLf="rbxassetid://82803", SkyboxRt="rbxassetid://68458", SkyboxUp="rbxassetid://82142" },
        }
        local ourSky = nil
        local originalSkyProps = {}
        local function rememberOriginal(sky)
            if not sky or originalSkyProps[sky] then return end
            originalSkyProps[sky] = { SkyboxBk=sky.SkyboxBk, SkyboxDn=sky.SkyboxDn, SkyboxFt=sky.SkyboxFt, SkyboxLf=sky.SkyboxLf, SkyboxRt=sky.SkyboxRt, SkyboxUp=sky.SkyboxUp, StarCount=sky.StarCount, CelestialBodiesShown=sky.CelestialBodiesShown }
        end
        local function restoreOriginal(sky)
            local props = originalSkyProps[sky]
            if not props then return end
            for k, v in pairs(props) do pcall(function() sky[k] = v end) end
            originalSkyProps[sky] = nil
        end
        local function applySkybox(name)
            if ourSky then pcall(function() ourSky:Destroy() end) ourSky = nil end
            for sky in pairs(originalSkyProps) do restoreOriginal(sky) end
            table.clear(originalSkyProps)
            if name == "Off" or not SKYBOXES[name] then return end
            local faces = SKYBOXES[name]
            local existingSky = LightingService:FindFirstChildOfClass("Sky")
            if existingSky then
                rememberOriginal(existingSky)
                for prop, value in pairs(faces) do pcall(function() existingSky[prop] = value end) end
            else
                ourSky = Instance.new("Sky")
                ourSky.Name = "MoggCustomSky_" .. math.random(1000, 9999)
                for prop, value in pairs(faces) do ourSky[prop] = value end
                ourSky.Parent = LightingService
            end
        end
        local SkyboxGroup = Tabs.Visuals:AddRightGroupbox("🌌 Skybox")
        SkyboxGroup:AddDropdown("SkyboxSelector", {
            Text = "Select Skybox",
            Default = "Off",
            Values = { "Off","Aurora","Beautiful","Blossom","Blue","ClearSkies","Galaxy","Night","Purple","Red","Spooky","Universe" },
            Callback = function(value) applySkybox(value) end
        })
        SkyboxGroup:AddButton({
            Text = "♻️ Reset to Default",
            Func = function()
                if Library.Options and Library.Options.SkyboxSelector then Library.Options.SkyboxSelector:SetValue("Off")
                else applySkybox("Off") end
            end
        })
    end

    -- ESP
    do
        local hasDrawing = (typeof(Drawing) == "table")
        if hasDrawing then
            hasDrawing = pcall(function() local t = Drawing.new("Text"); if t then t:Remove() end end)
        end
        if not hasDrawing then
            local ESPGroup = Tabs.Visuals:AddLeftGroupbox("👁 ESP")
            ESPGroup:AddLabel("<font color='#ff5050'>Drawing API недоступен</font>")
        else
        local ESPState = { Enabled=false, Target="Other", Name=false, NameColor=Color3.fromRGB(255,255,255), Distance=false, DistanceColor=Color3.fromRGB(200,200,200), Box=false, BoxColor=Color3.fromRGB(255,255,255), BoxStyle="Full", BoxThickness=1, BoxFilled=false, BoxFillOpacity=20, Skeleton=false, SkeletonColor=Color3.fromRGB(255,255,255), VisibilityCheck=false }
        local R15_BONES = { {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"} }
        local R6_BONES = { {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"} }
        local bundles = {}
        local function getCamera() return workspace.CurrentCamera end
        local function isVisible(char)
            if not ESPState.VisibilityCheck then return true end
            local camera = getCamera()
            if not camera then return true end
            local head = char:FindFirstChild("Head")
            local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
            local target = (head and head.Position) or (torso and torso.Position)
            if not target then return false end
            local origin = camera.CFrame.Position
            local dir = target - origin
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = { LocalPlayer.Character, camera }
            params.FilterType = Enum.RaycastFilterType.Exclude
            local result = workspace:Raycast(origin, dir, params)
            if not result then return true end
            return result.Instance:IsDescendantOf(char)
        end
        local function shouldRender(player)
            if not ESPState.Enabled then return false end
            if player == LocalPlayer then return ESPState.Target == "Self" or ESPState.Target == "All" end
            return ESPState.Target == "Other" or ESPState.Target == "All"
        end
        local CORNERS = { Vector3.new(-1,-1,-1),Vector3.new(1,-1,-1),Vector3.new(1,1,-1),Vector3.new(-1,1,-1),Vector3.new(-1,-1,1),Vector3.new(1,-1,1),Vector3.new(1,1,1),Vector3.new(-1,1,1) }
        local function projectBox(char, camera)
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root or not camera then return nil end
            local viewport = camera.ViewportSize
            if viewport.X <= 0 or viewport.Y <= 0 then return nil end
            local size = char:GetExtentsSize()
            local half = size / 2
            local relative = camera.CFrame:Inverse() * root.CFrame
            local screenCorners = {}
            local projected = 0
            for i, corner in ipairs(CORNERS) do
                local world = relative * (corner * half)
                local screen, onScreen = camera:WorldToViewportPoint(camera.CFrame * world)
                screenCorners[i] = Vector2.new(screen.X, screen.Y)
                if onScreen then projected += 1 end
            end
            if projected == 0 then return nil end
            local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
            for _, c in ipairs(screenCorners) do
                minX = math.min(minX, c.X); maxX = math.max(maxX, c.X)
                minY = math.min(minY, c.Y); maxY = math.max(maxY, c.Y)
            end
            if maxX - minX < 1 or maxY - minY < 1 then return nil end
            return Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY)
        end
        local function createBundle(player)
            local b = { name = Drawing.new("Text"), distance = Drawing.new("Text"), boxLines = {}, fill = Drawing.new("Square"), bones = {} }
            b.name.Size = 13; b.name.Center = true; b.name.Outline = true; b.name.Font = 2; b.name.Visible = false
            b.distance.Size = 12; b.distance.Center = true; b.distance.Outline = true; b.distance.Font = 2; b.distance.Visible = false
            b.fill.Filled = true; b.fill.Visible = false
            bundles[player] = b
            return b
        end
        local function getLine(b, index)
            if not b.boxLines[index] then local l = Drawing.new("Line"); l.Thickness = 1; l.Visible = false; b.boxLines[index] = l end
            return b.boxLines[index]
        end
        local function getBone(b, index)
            if not b.bones[index] then local l = Drawing.new("Line"); l.Thickness = 1.5; l.Visible = false; b.bones[index] = l end
            return b.bones[index]
        end
        local function hideBundle(b)
            if not b then return end
            b.name.Visible = false; b.distance.Visible = false; b.fill.Visible = false
            for _, l in pairs(b.boxLines) do l.Visible = false end
            for _, l in pairs(b.bones) do l.Visible = false end
        end
        local function destroyBundle(b)
            if not b then return end
            pcall(function() b.name:Remove() end); pcall(function() b.distance:Remove() end); pcall(function() b.fill:Remove() end)
            for _, l in pairs(b.boxLines) do pcall(function() l:Remove() end) end
            for _, l in pairs(b.bones) do pcall(function() l:Remove() end) end
        end
        local function drawBox(b, topLeft, size, color, thickness)
            local style = ESPState.BoxStyle
            local x, y = topLeft.X, topLeft.Y
            local w, h = size.X, size.Y
            local used = 0
            local function line(from, to)
                used += 1
                local l = getLine(b, used)
                l.From = from; l.To = to; l.Color = color; l.Thickness = thickness; l.Visible = true
            end
            if style == "Full" then
                line(Vector2.new(x, y), Vector2.new(x + w, y)); line(Vector2.new(x + w, y), Vector2.new(x + w, y + h))
                line(Vector2.new(x + w, y + h), Vector2.new(x, y + h)); line(Vector2.new(x, y + h), Vector2.new(x, y))
            elseif style == "Corner" then
                local c = math.min(w, h) * 0.25
                line(Vector2.new(x, y), Vector2.new(x + c, y)); line(Vector2.new(x, y), Vector2.new(x, y + c))
                line(Vector2.new(x + w, y), Vector2.new(x + w - c, y)); line(Vector2.new(x + w, y), Vector2.new(x + w, y + c))
                line(Vector2.new(x, y + h), Vector2.new(x + c, y + h)); line(Vector2.new(x, y + h), Vector2.new(x, y + h - c))
                line(Vector2.new(x + w, y + h), Vector2.new(x + w - c, y + h)); line(Vector2.new(x + w, y + h), Vector2.new(x + w, y + h - c))
            elseif style == "Bracket" then
                local c = math.min(w, h) * 0.2
                line(Vector2.new(x - 2, y), Vector2.new(x - 2, y + c)); line(Vector2.new(x - 2, y), Vector2.new(x - 2 + c, y))
                line(Vector2.new(x + w + 2, y), Vector2.new(x + w + 2, y + c)); line(Vector2.new(x + w + 2, y), Vector2.new(x + w + 2 - c, y))
                line(Vector2.new(x - 2, y + h), Vector2.new(x - 2, y + h - c)); line(Vector2.new(x - 2, y + h), Vector2.new(x - 2 + c, y + h))
                line(Vector2.new(x + w + 2, y + h), Vector2.new(x + w + 2, y + h - c)); line(Vector2.new(x + w + 2, y + h), Vector2.new(x + w + 2 - c, y + h))
            elseif style == "3D" then
                local off = math.min(w, h) * 0.15
                line(Vector2.new(x, y), Vector2.new(x + w, y)); line(Vector2.new(x + w, y), Vector2.new(x + w, y + h))
                line(Vector2.new(x + w, y + h), Vector2.new(x, y + h)); line(Vector2.new(x, y + h), Vector2.new(x, y))
                line(Vector2.new(x + off, y - off), Vector2.new(x + w + off, y - off)); line(Vector2.new(x + w + off, y - off), Vector2.new(x + w + off, y + h - off))
                line(Vector2.new(x + w + off, y + h - off), Vector2.new(x + off, y + h - off)); line(Vector2.new(x + off, y + h - off), Vector2.new(x + off, y - off))
            end
            for i = used + 1, #b.boxLines do b.boxLines[i].Visible = false end
            if ESPState.BoxFilled then
                b.fill.Position = topLeft; b.fill.Size = size; b.fill.Color = color
                b.fill.Transparency = 1 - (ESPState.BoxFillOpacity / 100); b.fill.Visible = true
            else b.fill.Visible = false end
        end
        local function drawSkeleton(b, char, camera)
            local bones = char:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
            local used = 0
            for _, pair in ipairs(bones) do
                local from = char:FindFirstChild(pair[1])
                local to = char:FindFirstChild(pair[2])
                if from and to and from:IsA("BasePart") and to:IsA("BasePart") then
                    local a, onA = camera:WorldToViewportPoint(from.Position)
                    local c, onC = camera:WorldToViewportPoint(to.Position)
                    if onA and onC and a.Z > 0 and c.Z > 0 then
                        used += 1
                        local l = getBone(b, used)
                        l.From = Vector2.new(a.X, a.Y); l.To = Vector2.new(c.X, c.Y)
                        l.Color = ESPState.SkeletonColor; l.Visible = true
                    end
                end
            end
            for i = used + 1, #b.bones do b.bones[i].Visible = false end
        end
        local function renderESP()
            local camera = getCamera()
            if not camera then return end
            for _, player in ipairs(Players:GetPlayers()) do
                local b = bundles[player] or createBundle(player)
                local char = player.Character
                if not shouldRender(player) or not char or not char:FindFirstChild("HumanoidRootPart") then
                    hideBundle(b)
                else
                    local visible = isVisible(char)
                    if not visible then hideBundle(b)
                    else
                        local topLeft, size = projectBox(char, camera)
                        if topLeft and size then
                            if ESPState.Box then drawBox(b, topLeft, size, ESPState.BoxColor, ESPState.BoxThickness)
                            else for _, l in pairs(b.boxLines) do l.Visible = false end; b.fill.Visible = false end
                            if ESPState.Name then
                                b.name.Position = Vector2.new(topLeft.X + size.X / 2, topLeft.Y - 18)
                                b.name.Text = player.DisplayName or player.Name
                                b.name.Color = ESPState.NameColor
                                b.name.Visible = true
                            else b.name.Visible = false end
                            if ESPState.Distance then
                                local myChar = LocalPlayer.Character
                                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                                local theirRoot = char:FindFirstChild("HumanoidRootPart")
                                if myRoot and theirRoot then
                                    local dist = math.floor((myRoot.Position - theirRoot.Position).Magnitude)
                                    b.distance.Position = Vector2.new(topLeft.X + size.X / 2, topLeft.Y + size.Y + 4)
                                    b.distance.Text = dist .. "m"
                                    b.distance.Color = ESPState.DistanceColor
                                    b.distance.Visible = true
                                else b.distance.Visible = false end
                            else b.distance.Visible = false end
                            if ESPState.Skeleton then drawSkeleton(b, char, camera)
                            else for _, l in pairs(b.bones) do l.Visible = false end end
                        else hideBundle(b) end
                    end
                end
            end
        end
        local espRenderConn = nil
        local function startESP()
            if espRenderConn then return end
            espRenderConn = RunService.RenderStepped:Connect(renderESP)
        end
        local function stopESP()
            if espRenderConn then espRenderConn:Disconnect(); espRenderConn = nil end
            for _, b in pairs(bundles) do hideBundle(b) end
        end
        Players.PlayerRemoving:Connect(function(player)
            if bundles[player] then destroyBundle(bundles[player]); bundles[player] = nil end
        end)
        local ESPGroup = Tabs.Visuals:AddLeftGroupbox("👁 ESP")
        ESPGroup:AddToggle("ESPEnabled", { Text = "Enable ESP", Default = false, Callback = function(v) ESPState.Enabled = v; if v then startESP() else stopESP() end end })
        ESPGroup:AddDropdown("ESPTarget", { Text = "Target", Default = "Other", Values = { "Other", "Self", "All" }, Callback = function(v) ESPState.Target = v end })
        ESPGroup:AddToggle("ESPName", { Text = "Name", Default = false, Callback = function(v) ESPState.Name = v end })
        ESPGroup:AddLabel("Name Color"):AddColorPicker("ESPNameColor", { Default = ESPState.NameColor, Title = "Name Color", Callback = function(v) ESPState.NameColor = v end })
        ESPGroup:AddToggle("ESPDistance", { Text = "Distance", Default = false, Callback = function(v) ESPState.Distance = v end })
        ESPGroup:AddToggle("ESPBox", { Text = "Box", Default = false, Callback = function(v) ESPState.Box = v end })
        ESPGroup:AddLabel("Box Color"):AddColorPicker("ESPBoxColor", { Default = ESPState.BoxColor, Title = "Box Color", Callback = function(v) ESPState.BoxColor = v end })
        ESPGroup:AddDropdown("ESPBoxStyle", { Text = "Box Style", Default = "Full", Values = { "Full", "Corner", "Bracket", "3D" }, Callback = function(v) ESPState.BoxStyle = v end })
        ESPGroup:AddSlider("ESPBoxThickness", { Text = "Thickness", Default = 1, Min = 1, Max = 5, Callback = function(v) ESPState.BoxThickness = v end })
        ESPGroup:AddToggle("ESPBoxFilled", { Text = "Box Filled", Default = false, Callback = function(v) ESPState.BoxFilled = v end })
        ESPGroup:AddSlider("ESPBoxFillOpacity", { Text = "Fill Opacity %", Default = 20, Min = 0, Max = 100, Callback = function(v) ESPState.BoxFillOpacity = v end })
        ESPGroup:AddToggle("ESPSkeleton", { Text = "Skeleton", Default = false, Callback = function(v) ESPState.Skeleton = v end })
        ESPGroup:AddLabel("Skeleton Color"):AddColorPicker("ESPSkeletonColor", { Default = ESPState.SkeletonColor, Title = "Skeleton Color", Callback = function(v) ESPState.SkeletonColor = v end })
        ESPGroup:AddToggle("ESPVisCheck", { Text = "Visibility Check", Default = false, Callback = function(v) ESPState.VisibilityCheck = v end })
        end
    end
end

-- UI SETTINGS
local UISettings = Window:AddTab("UI Settings", "settings")
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
ThemeManager:SetFolder("mogg")
SaveManager:SetFolder("mogg/Configs")
SaveManager:BuildConfigSection(UISettings)
ThemeManager:ApplyToTab(UISettings)
local windowVisible = true
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        windowVisible = not windowVisible
        Window.Gui.Enabled = windowVisible
    end
end)
Library:Notify({ Title = "mogg", Description = "Загружено! Jerk Off в Misc", Time = 4 })
print("[mogg] Загружен. Jerk Off добавлен в Misc.")