-- ═══════════════════════════════════════════════════════════
--            CELLESTIAL PHONE V33 - MAIN SCRIPT
-- ═══════════════════════════════════════════════════════════
--  ⚠️  THIS SCRIPT IS PROTECTED
--  🔒  Only executable through official loader
--  📱  Pastefy: https://pastefy.app/VL21y5t7/raw
-- ═══════════════════════════════════════════════════════════

-- ANTI-STEAL PROTECTION
do
    local function validateLoader()
        -- Check authentication exists
        if not getgenv().__CELLESTIAL_AUTH then
            return false, "❌ Missing authentication key"
        end
        
        if not getgenv().__CELLESTIAL_TIME then
            return false, "❌ Missing timestamp"
        end
        
        if not getgenv().__CELLESTIAL_VALID then
            return false, "❌ Invalid session"
        end
        
        -- Check timeout (max 10 seconds from loader)
        local elapsed = tick() - getgenv().__CELLESTIAL_TIME
        if elapsed > 10 then
            return false, "❌ Session expired (timeout)"
        end
        
        return true, "✅ Authentication successful"
    end
    
    local success, message = validateLoader()
    
    if not success then
        warn(message)
        warn("═══════════════════════════════════════════════════════════")
        warn("  ⚠️  AKSES DITOLAK / ACCESS DENIED")
        warn("  📱  Gunakan loader resmi dari:")
        warn("  🔗  https://pastefy.app/VL21y5t7/raw")
        warn("═══════════════════════════════════════════════════════════")
        return
    end
    
    -- Clear credentials after validation
    getgenv().__CELLESTIAL_AUTH = nil
    getgenv().__CELLESTIAL_TIME = nil
    getgenv().__CELLESTIAL_VALID = nil
    
    print(message)
end

-- ═══════════════════════════════════════════════════════════
--                    MAIN SCRIPT START
-- ═══════════════════════════════════════════════════════════

if game.CoreGui:FindFirstChild("Cellestial_PhoneV33") then
    game.CoreGui:FindFirstChild("Cellestial_PhoneV33"):Destroy()
end
if game.CoreGui:FindFirstChild("Cellestial_PhoneV32") then
    game.CoreGui:FindFirstChild("Cellestial_PhoneV32"):Destroy()
end
-------------------------------------------------------------------------
-- TAS PLAYBACK MODULE INTEGRATION
-------------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local TASPlayback = {}
TASPlayback.isPlaying = false
TASPlayback.isPaused = false
TASPlayback.isReturning = false
TASPlayback.isFlipped = false
TASPlayback.isReversed = false
TASPlayback.loadedData = nil
TASPlayback.playbackIndex = 1
TASPlayback.playbackConnection = nil
TASPlayback.playbackSpeed = 1

local RETURN_SPEED = 20
local ROUTE_ARRIVAL_DISTANCE = 1.5

local function vectorToTable(vec)
    return {x = vec.X, y = vec.Y, z = vec.Z}
end

local function updateChar()
    if not character or not character.Parent then
        character = player.Character
        if character then
            humanoid = character:FindFirstChild("Humanoid")
            rootPart = character:FindFirstChild("HumanoidRootPart")
        end
    end
end

local function resetCharacterState()
    updateChar()
    if rootPart then
        rootPart.Anchored = false
        rootPart.AssemblyLinearVelocity = Vector3.zero
    end
    if humanoid then
        humanoid.AutoRotate = true
        humanoid.PlatformStand = false
        humanoid:ChangeState(Enum.HumanoidStateType.Landed)
        humanoid:Move(Vector3.zero, false)
    end
end

local function smoothPlaybackData(data)
    if not data or #data == 0 then return data end
    local smoothed = {}
    local IDLE_THRESHOLD = 0.1
    local lastMovingFrame = nil

    for i, frame in ipairs(data) do
        local vel = Vector3.new(frame.VEL.x, frame.VEL.y, frame.VEL.z)
        local horizontalSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
        local isClimbing = frame.STA == "Climbing"

        if horizontalSpeed > IDLE_THRESHOLD or isClimbing then
            if lastMovingFrame and #smoothed > 0 then
                local prevFrame = smoothed[#smoothed]
                local timeDiff = frame.TMI - prevFrame.TMI

                if timeDiff > 0.1 then
                    local prevPos = Vector3.new(prevFrame.POS.x, prevFrame.POS.y, prevFrame.POS.z)
                    local currPos = Vector3.new(frame.POS.x, frame.POS.y, frame.POS.z)
                    local distance = (currPos - prevPos).Magnitude

                    if distance > 5 then
                        local steps = math.ceil(timeDiff / 0.016)
                        for step = 1, steps - 1 do
                            local alpha = step / steps
                            local interpPos = prevPos:Lerp(currPos, alpha)
                            local interpVel = Vector3.new(prevFrame.VEL.x, prevFrame.VEL.y, prevFrame.VEL.z):Lerp(vel, alpha)
                            local interpRot = prevFrame.ROT + (frame.ROT - prevFrame.ROT) * alpha

                            table.insert(smoothed, {
                                POS = vectorToTable(interpPos),
                                VEL = vectorToTable(interpVel),
                                ROT = interpRot,
                                STA = prevFrame.STA,
                                JUM = false,
                                TMI = prevFrame.TMI + (timeDiff * alpha),
                                HIP = prevFrame.HIP
                            })
                        end
                    end
                end
            end

            table.insert(smoothed, frame)
            lastMovingFrame = frame
        end
    end

    if #smoothed > 0 then
        local firstTime = smoothed[1].TMI
        for i, frame in ipairs(smoothed) do
            frame.TMI = frame.TMI - firstTime
        end
    end

    return smoothed
end

function TASPlayback:LoadFile(filepath)
    local success, data = pcall(function()
        return HttpService:JSONDecode(readfile(filepath))
    end)

    if success and data then
        self.loadedData = data
        return true, "File loaded successfully"
    else
        return false, "Failed to load file"
    end
end

function TASPlayback:LoadData(data)
    if data and #data > 0 then
        self.loadedData = data
        return true, "Data loaded successfully"
    else
        return false, "Invalid data"
    end
end

function TASPlayback:ToggleFlip()
    self.isFlipped = not self.isFlipped
    return self.isFlipped
end

function TASPlayback:SetFlip(enabled)
    self.isFlipped = enabled
end

function TASPlayback:GetFlipState()
    return self.isFlipped
end

function TASPlayback:ToggleReverse()
    self.isReversed = not self.isReversed
    return self.isReversed
end

function TASPlayback:Start()
    if self.isPlaying then return false, "Already playing" end
    if not self.loadedData or #self.loadedData == 0 then
        return false, "No data loaded"
    end

    updateChar()

    local smoothData = smoothPlaybackData(self.loadedData)
    if #smoothData == 0 then
        return false, "Data empty after smoothing"
    end
    self.loadedData = smoothData

    local hipHeightOffset = 0
    if self.loadedData[1] and self.loadedData[1].HIP then
        hipHeightOffset = humanoid.HipHeight - self.loadedData[1].HIP
    end

    self.isPlaying = true
    self.isPaused = false
    self.isReturning = false

    local closestIndex = 1
    local closestDist = math.huge
    local myPos = rootPart.Position

    for i, data in ipairs(self.loadedData) do
        local fPos = Vector3.new(data.POS.x, data.POS.y + hipHeightOffset, data.POS.z)
        local dist = (fPos - myPos).Magnitude
        if dist < closestDist then
            closestDist = dist
            closestIndex = i
        end
    end

    self.playbackIndex = closestIndex
    local currentTime = 0
    if self.playbackIndex > 1 then
        currentTime = self.loadedData[self.playbackIndex].TMI
    end

    self.isReturning = true

    local controls = require(player.PlayerScripts.PlayerModule):GetControls()
    controls:Disable()
    humanoid.AutoRotate = false
    humanoid.PlatformStand = false
    rootPart.Anchored = false

    self.playbackConnection = RunService.Heartbeat:Connect(function(dt)
        if self.isPaused then return end

        if self.isReturning then
            if self.playbackIndex > #self.loadedData or self.playbackIndex < 1 then
                self:Stop()
                return
            end

            local frame = self.loadedData[self.playbackIndex]
            local targetPos = Vector3.new(frame.POS.x, frame.POS.y + hipHeightOffset, frame.POS.z)
            local diff = targetPos - rootPart.Position
            local distance = diff.Magnitude

            if distance <= ROUTE_ARRIVAL_DISTANCE then
                self.isReturning = false
                humanoid.AutoRotate = false
                humanoid:Move(Vector3.zero, false)
                currentTime = frame.TMI

                local rotation = frame.ROT
                if self.isFlipped then
                    rotation = rotation + math.pi
                end
                rootPart.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, rotation, 0)
            else
                local direction = diff.Unit
                local targetVel = Vector3.new(frame.VEL.x, frame.VEL.y, frame.VEL.z)
                local fileSpeed = Vector3.new(targetVel.X, 0, targetVel.Z).Magnitude
                local moveSpeed = math.max(fileSpeed, RETURN_SPEED)

                local newVel = direction * moveSpeed
                newVel = Vector3.new(newVel.X, rootPart.AssemblyLinearVelocity.Y, newVel.Z)
                rootPart.AssemblyLinearVelocity = newVel

                local lookRotation = math.atan2(-direction.X, -direction.Z)
                rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, lookRotation, 0)

                humanoid:Move(direction, false)
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
            end
            return
        end

        if self.isReversed then
            if self.playbackIndex <= 1 then
                self:Stop()
                return
            end

            currentTime = currentTime - (dt * self.playbackSpeed)

            while self.playbackIndex > 1 and self.loadedData[self.playbackIndex - 1].TMI >= currentTime do
                self.playbackIndex = self.playbackIndex - 1
                local frame = self.loadedData[self.playbackIndex]
                local pos = Vector3.new(frame.POS.x, frame.POS.y + hipHeightOffset, frame.POS.z)
                local rotation = frame.ROT

                if self.isFlipped then
                    rotation = rotation + math.pi
                end

                rootPart.CFrame = CFrame.new(pos) * CFrame.Angles(0, rotation, 0)

                if frame.VEL then
                    local vel = Vector3.new(frame.VEL.x, frame.VEL.y, frame.VEL.z)
                    
                    vel = Vector3.new(-vel.X, vel.Y, -vel.Z)

                    if self.isFlipped then
                        vel = Vector3.new(-vel.X, vel.Y, -vel.Z)
                    end

                    rootPart.AssemblyLinearVelocity = vel

                    if Vector3.new(vel.X, 0, vel.Z).Magnitude > 0.1 then
                        humanoid:Move(vel, false)
                    else
                        humanoid:Move(Vector3.zero, false)
                    end
                end

                if frame.STA then
                    local s = frame.STA
                    if s == "Jumping" then
                        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    elseif s == "Freefall" then
                        humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                    elseif s == "Climbing" then
                        humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
                    elseif s == "Landed" or s == "Running" then
                        humanoid:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end
            end
        else
            if self.playbackIndex > #self.loadedData then
                self:Stop()
                return
            end

            currentTime = currentTime + (dt * self.playbackSpeed)

            while self.playbackIndex <= #self.loadedData and self.loadedData[self.playbackIndex].TMI <= currentTime do
                local frame = self.loadedData[self.playbackIndex]
                local pos = Vector3.new(frame.POS.x, frame.POS.y + hipHeightOffset, frame.POS.z)
                local rotation = frame.ROT

                if self.isFlipped then
                    rotation = rotation + math.pi
                end

                rootPart.CFrame = CFrame.new(pos) * CFrame.Angles(0, rotation, 0)

                if frame.VEL then
                    local vel = Vector3.new(frame.VEL.x, frame.VEL.y, frame.VEL.z)

                    if self.isFlipped then
                        vel = Vector3.new(-vel.X, vel.Y, -vel.Z)
                    end

                    rootPart.AssemblyLinearVelocity = vel

                    if Vector3.new(vel.X, 0, vel.Z).Magnitude > 0.1 then
                        humanoid:Move(vel, false)
                    else
                        humanoid:Move(Vector3.zero, false)
                    end
                end

                if frame.STA then
                    local s = frame.STA
                    if s == "Jumping" then
                        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        humanoid.Jump = true
                    elseif s == "Freefall" then
                        humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                    elseif s == "Climbing" then
                        humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
                    elseif s == "Landed" or s == "Running" then
                        humanoid:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end

                self.playbackIndex = self.playbackIndex + 1
            end
        end
    end)

    return true, "Playback started"
end

function TASPlayback:Stop()
    if not self.isPlaying then return false, "Not playing" end

    self.isPlaying = false
    self.isReturning = false
    self.playbackIndex = 1

    if self.playbackConnection then
        self.playbackConnection:Disconnect()
        self.playbackConnection = nil
    end

    local controls = require(player.PlayerScripts.PlayerModule):GetControls()
    controls:Enable()
    resetCharacterState()

    return true, "Playback stopped"
end

-------------------------------------------------------------------------
-- SETUP AUDIO & LIST
-------------------------------------------------------------------------
local MusicList = {
    {Name = "DJ Cellestial - Full Bass", ID = "rbxassetid://1837879082"},
    {Name = "Phonk Gaming Music", ID = "rbxassetid://9043896492"},
    {Name = "Chill Lofi Beats", ID = "rbxassetid://9048644365"},
}
local CurrentSongIndex = 1 

local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local AudioPlayer = Instance.new("Sound")
AudioPlayer.Name = "CellestialMusic"
AudioPlayer.Parent = game.Workspace
AudioPlayer.Volume = 1 
AudioPlayer.Looped = true

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Cellestial_PhoneV33" 
ScreenGui.Parent = game.CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-------------------------------------------------------------------------
-- 1. TOMBOL TOGGLE
-------------------------------------------------------------------------
local ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Name = "PhoneToggle"
ToggleBtn.Size = UDim2.new(0, 35, 0, 35) 
ToggleBtn.Position = UDim2.new(0.1, 0, 0.4, 0) 
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ToggleBtn.BackgroundTransparency = 0.2
ToggleBtn.Image = "rbxassetid://74535250876802" 
ToggleBtn.Parent = ScreenGui
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0) 
local ToggleStroke = Instance.new("UIStroke", ToggleBtn)
ToggleStroke.Color = Color3.fromRGB(180, 0, 0)
ToggleStroke.Thickness = 2

-------------------------------------------------------------------------
-- 2. FRAME HP UTAMA
-------------------------------------------------------------------------
local PhoneFrame = Instance.new("Frame")
PhoneFrame.Name = "PhoneBody"
PhoneFrame.Size = UDim2.new(0, 181, 0, 368) 
PhoneFrame.Position = UDim2.new(0.5, -90, 1.5, 0) 
PhoneFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
PhoneFrame.BorderSizePixel = 0
PhoneFrame.ClipsDescendants = true 
PhoneFrame.Active = true
PhoneFrame.Parent = ScreenGui

Instance.new("UICorner", PhoneFrame).CornerRadius = UDim.new(0, 30)
local PhoneStroke = Instance.new("UIStroke", PhoneFrame)
PhoneStroke.Color = Color3.fromRGB(100, 100, 100)
PhoneStroke.Thickness = 0.8 

local Wallpaper = Instance.new("ImageLabel")
Wallpaper.Name = "Background"
Wallpaper.Size = UDim2.new(1, 0, 1, 0) 
Wallpaper.BackgroundTransparency = 1
Wallpaper.Image = "rbxassetid://83500140161201" 
Wallpaper.ScaleType = Enum.ScaleType.Crop 
Wallpaper.ZIndex = 1
Wallpaper.Parent = PhoneFrame
Instance.new("UICorner", Wallpaper).CornerRadius = UDim.new(0, 30)

-------------------------------------------------------------------------
-- 3. STATUS BAR
-------------------------------------------------------------------------
local StatusBar = Instance.new("Frame")
StatusBar.Size = UDim2.new(1, 0, 0, 35)
StatusBar.BackgroundTransparency = 1
StatusBar.ZIndex = 20 
StatusBar.Parent = PhoneFrame

local NormalTime = Instance.new("TextLabel")
NormalTime.Name = "NormalTime"
NormalTime.Text = "00:00"
NormalTime.TextColor3 = Color3.new(1,1,1)
NormalTime.Font = Enum.Font.Antique 
NormalTime.TextSize = 14 
NormalTime.Position = UDim2.new(0, 15, 0, 8)
NormalTime.Size = UDim2.new(0, 40, 0, 20)
NormalTime.BackgroundTransparency = 1
NormalTime.TextXAlignment = Enum.TextXAlignment.Left
NormalTime.Parent = StatusBar

local NormalFps = Instance.new("TextLabel")
NormalFps.Name = "NormalFps"
NormalFps.Text = "60 FPS"
NormalFps.TextColor3 = Color3.fromRGB(255, 0, 0) 
NormalFps.Font = Enum.Font.Antique
NormalFps.TextSize = 12
NormalFps.Position = UDim2.new(1, -65, 0, 8)
NormalFps.Size = UDim2.new(0, 50, 0, 20)
NormalFps.BackgroundTransparency = 1
NormalFps.TextXAlignment = Enum.TextXAlignment.Right
NormalFps.Parent = StatusBar

local WidgetContainer = Instance.new("Frame")
WidgetContainer.Name = "WidgetContainer"
WidgetContainer.Size = UDim2.new(0.85, 0, 1, 0) 
WidgetContainer.Position = UDim2.new(0, 0, 0, 0)
WidgetContainer.BackgroundTransparency = 1
WidgetContainer.ClipsDescendants = true 
WidgetContainer.Visible = false 
WidgetContainer.Parent = StatusBar

local PageStatus = Instance.new("Frame")
PageStatus.Name = "PageStatus"
PageStatus.Size = UDim2.new(1, 0, 1, 0)
PageStatus.BackgroundTransparency = 1
PageStatus.Parent = WidgetContainer

local MiniFpsLabel = Instance.new("TextLabel")
MiniFpsLabel.Text = "60 FPS"
MiniFpsLabel.TextColor3 = Color3.fromRGB(255, 0, 0) 
MiniFpsLabel.Font = Enum.Font.Antique
MiniFpsLabel.TextSize = 12
MiniFpsLabel.Position = UDim2.new(0, 15, 0, 8) 
MiniFpsLabel.Size = UDim2.new(0, 50, 0, 20)
MiniFpsLabel.BackgroundTransparency = 1
MiniFpsLabel.TextXAlignment = Enum.TextXAlignment.Left
MiniFpsLabel.Parent = PageStatus

local MiniCheckpoint = Instance.new("TextLabel")
MiniCheckpoint.Name = "MiniCP"
MiniCheckpoint.Text = "Checkpoint: 0"
MiniCheckpoint.TextColor3 = Color3.fromRGB(0, 255, 150)
MiniCheckpoint.Font = Enum.Font.GothamBold
MiniCheckpoint.TextSize = 11
MiniCheckpoint.Size = UDim2.new(0, 100, 0, 20)
MiniCheckpoint.Position = UDim2.new(0.5, -50, 0, 8) 
MiniCheckpoint.BackgroundTransparency = 1
MiniCheckpoint.Parent = PageStatus

local PageMusic = Instance.new("Frame")
PageMusic.Name = "PageMusic"
PageMusic.Size = UDim2.new(1, 0, 1, 0)
PageMusic.Position = UDim2.new(1, 0, 0, 0) 
PageMusic.BackgroundTransparency = 1
PageMusic.Parent = WidgetContainer

local MusicTimeLabel = Instance.new("TextLabel")
MusicTimeLabel.Text = "00:00 / 00:00"
MusicTimeLabel.TextColor3 = Color3.new(1,1,1)
MusicTimeLabel.Font = Enum.Font.GothamBold
MusicTimeLabel.TextSize = 11
MusicTimeLabel.Size = UDim2.new(0, 80, 1, 0)
MusicTimeLabel.Position = UDim2.new(0, 15, 0, 0) 
MusicTimeLabel.BackgroundTransparency = 1
MusicTimeLabel.TextXAlignment = Enum.TextXAlignment.Left
MusicTimeLabel.Parent = PageMusic

local EquContainer = Instance.new("Frame")
EquContainer.Size = UDim2.new(0, 25, 0, 12)
EquContainer.Position = UDim2.new(1, -5, 0.5, -6) 
EquContainer.AnchorPoint = Vector2.new(1, 0) 
EquContainer.BackgroundTransparency = 1
EquContainer.Parent = PageMusic

local Bars = {}
for i = 1, 4 do 
    local bar = Instance.new("Frame")
    bar.BackgroundColor3 = Color3.fromRGB(0, 255, 255) 
    bar.Size = UDim2.new(0, 4, 0.2, 0)
    bar.Position = UDim2.new(0, (i-1)*6, 1, 0)
    bar.AnchorPoint = Vector2.new(0, 1) 
    bar.BorderSizePixel = 0
    bar.Parent = EquContainer
    table.insert(Bars, bar)
end

local NotifLabel = Instance.new("TextLabel")
NotifLabel.Name = "Notification"
NotifLabel.Text = ""
NotifLabel.TextColor3 = Color3.fromRGB(255, 255, 0) 
NotifLabel.Font = Enum.Font.Antique
NotifLabel.TextSize = 11
NotifLabel.Size = UDim2.new(0, 120, 0, 20)
NotifLabel.Position = UDim2.new(0.5, -60, 0, 8) 
NotifLabel.BackgroundTransparency = 1
NotifLabel.TextTransparency = 1 
NotifLabel.ZIndex = 25
NotifLabel.Parent = StatusBar

local MiniNotifLabel = Instance.new("TextLabel")
MiniNotifLabel.Name = "MiniNotification"
MiniNotifLabel.Text = ""
MiniNotifLabel.TextColor3 = Color3.fromRGB(255, 255, 0) 
MiniNotifLabel.Font = Enum.Font.GothamBold
MiniNotifLabel.TextSize = 11
MiniNotifLabel.Size = UDim2.new(0, 140, 0, 20)
MiniNotifLabel.Position = UDim2.new(0.5, -60, 0, 8) 
MiniNotifLabel.BackgroundTransparency = 1
MiniNotifLabel.TextTransparency = 1 
MiniNotifLabel.ZIndex = 26
MiniNotifLabel.Parent = PageStatus

local MinBtn = Instance.new("TextButton")
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.new(1,1,1)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.Size = UDim2.new(0, 20, 0, 20)
MinBtn.Position = UDim2.new(1, -25, 0, 8) 
MinBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0) 
MinBtn.ZIndex = 30
MinBtn.Parent = StatusBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(1, 0)

function ShowNotification(text)
    if WidgetContainer.Visible then
        MiniCheckpoint.Visible = false
        MiniNotifLabel.Text = text
        MiniNotifLabel.TextTransparency = 0
        TweenService:Create(MiniNotifLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
        task.delay(2, function()
            if MiniNotifLabel.Text == text then 
                TweenService:Create(MiniNotifLabel, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
                task.wait(0.5)
                MiniCheckpoint.Visible = true
            end
        end)
        return 
    end
    NotifLabel.Text = text
    NotifLabel.TextTransparency = 0
    TweenService:Create(NotifLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
    task.delay(2, function()
        if NotifLabel.Text == text then 
            TweenService:Create(NotifLabel, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
        end
    end)
end

-------------------------------------------------------------------------
-- 4. MAIN MENU
-------------------------------------------------------------------------
local MainMenu = Instance.new("Frame")
MainMenu.Name = "MainMenu"
MainMenu.Size = UDim2.new(1, 0, 1, 0)
MainMenu.BackgroundTransparency = 1
MainMenu.ZIndex = 5
MainMenu.Parent = PhoneFrame

local HeaderFrame = Instance.new("Frame")
HeaderFrame.Size = UDim2.new(1, 0, 0, 90)
HeaderFrame.Position = UDim2.new(0, 0, 0, 55)
HeaderFrame.BackgroundTransparency = 1
HeaderFrame.Parent = MainMenu

local BrandText = Instance.new("TextLabel")
BrandText.Text = "Cellestial"
BrandText.Font = Enum.Font.Antique
BrandText.TextColor3 = Color3.fromRGB(220, 0, 0) 
BrandText.TextSize = 22
BrandText.Size = UDim2.new(1, 0, 0, 25)
BrandText.Position = UDim2.new(0, 0, 0, 5)
BrandText.BackgroundTransparency = 1
BrandText.Parent = HeaderFrame

local VipTxt = Instance.new("TextLabel")
VipTxt.Text = "STATUS : UNKNOWN#" .. LocalPlayer.AccountAge 
VipTxt.Font = Enum.Font.Antique
VipTxt.TextColor3 = Color3.fromRGB(0, 255, 200)
VipTxt.TextSize = 14
VipTxt.Size = UDim2.new(1, 0, 0, 15)
VipTxt.Position = UDim2.new(0, 0, 0, 35)
VipTxt.BackgroundTransparency = 1
VipTxt.Parent = HeaderFrame

local AppsContainer = Instance.new("Frame")
AppsContainer.Size = UDim2.new(0.9, 0, 0.25, 0) 
AppsContainer.Position = UDim2.new(0.05, 0, 0.60, 0) 
AppsContainer.BackgroundTransparency = 1
AppsContainer.Parent = MainMenu
local Grid = Instance.new("UIGridLayout")
Grid.Parent = AppsContainer
Grid.CellSize = UDim2.new(0, 60, 0, 75) 
Grid.CellPadding = UDim2.new(0, 15, 0, 10)
Grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
Grid.SortOrder = Enum.SortOrder.LayoutOrder

local AppButtons = {}
function CreateApp(name, iconId)
    local AppBtn = Instance.new("TextButton")
    AppBtn.Name = name 
    AppBtn.Text = ""
    AppBtn.BackgroundTransparency = 1
    AppBtn.Parent = AppsContainer
    
    local IconImg = Instance.new("ImageLabel")
    IconImg.Size = UDim2.new(0, 52, 0, 52) 
    IconImg.Position = UDim2.new(0.5, -26, 0, 8) 
    IconImg.BackgroundTransparency = 1
    IconImg.Image = "rbxassetid://" .. iconId
    IconImg.Parent = AppBtn
    
    local AppName = Instance.new("TextLabel")
    AppName.Text = name
    AppName.TextColor3 = Color3.new(1,1,1)
    AppName.Font = Enum.Font.Antique
    AppName.TextSize = 12 
    AppName.Size = UDim2.new(1, 0, 0, 20)
    AppName.Position = UDim2.new(0, 0, 0, 60)
    AppName.BackgroundTransparency = 1
    AppName.Parent = AppBtn
    AppButtons[name] = AppBtn
    return AppBtn
end
CreateApp("Music", "94057209984891")
CreateApp("File", "73399445220660")

-- AUTO WALK PAGE
local AutoWalkPage = Instance.new("Frame")
AutoWalkPage.Name = "AutoWalkPage"
AutoWalkPage.Size = UDim2.new(1, 0, 1, 0)
AutoWalkPage.Position = UDim2.new(0, 0, 1, 0)
AutoWalkPage.BackgroundTransparency = 1 
AutoWalkPage.ZIndex = 6
AutoWalkPage.Parent = PhoneFrame
local Overlay = Instance.new("Frame")
Overlay.Size = UDim2.new(1, 0, 1, 0)
Overlay.BackgroundColor3 = Color3.new(0,0,0)
Overlay.BackgroundTransparency = 0.5
Overlay.Parent = AutoWalkPage
Instance.new("UICorner", Overlay).CornerRadius = UDim.new(0, 30)

local AwTitle = Instance.new("TextLabel")
AwTitle.Text = "PlayBack" 
AwTitle.Font = Enum.Font.GothamBold
AwTitle.TextColor3 = Color3.new(1,1,1)
AwTitle.TextSize = 18
AwTitle.Size = UDim2.new(1, 0, 0, 30)
AwTitle.Position = UDim2.new(0, 0, 0, 40)
AwTitle.BackgroundTransparency = 1
AwTitle.Parent = AutoWalkPage

local AwBrand = Instance.new("TextLabel")
AwBrand.Text = "Cellestial"
AwBrand.Font = Enum.Font.Antique 
AwBrand.TextColor3 = Color3.fromRGB(220, 0, 0) 
AwBrand.TextSize = 18 
AwBrand.Size = UDim2.new(1, 0, 0, 20)
AwBrand.Position = UDim2.new(0, 0, 0, 65) 
AwBrand.BackgroundTransparency = 1
AwBrand.Parent = AutoWalkPage

local RouteStatus = Instance.new("TextLabel")
RouteStatus.Text = "Belum ada route terload"
RouteStatus.Font = Enum.Font.Gotham
RouteStatus.TextColor3 = Color3.fromRGB(200, 200, 200) 
RouteStatus.TextSize = 12
RouteStatus.Size = UDim2.new(1, 0, 0, 20)
RouteStatus.Position = UDim2.new(0, 0, 0.26, 0) 
RouteStatus.BackgroundTransparency = 1
RouteStatus.Parent = AutoWalkPage

local RouteBtn = Instance.new("TextButton")
RouteBtn.Text = "    Select Route"
RouteBtn.Font = Enum.Font.GothamBold
RouteBtn.TextColor3 = Color3.new(1,1,1)
RouteBtn.TextSize = 16
RouteBtn.TextXAlignment = Enum.TextXAlignment.Left
RouteBtn.Size = UDim2.new(0.8, 0, 0, 40)
RouteBtn.Position = UDim2.new(0.1, 0, 0.32, 0) 
RouteBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
RouteBtn.BackgroundTransparency = 0.5
RouteBtn.Parent = AutoWalkPage
Instance.new("UICorner", RouteBtn).CornerRadius = UDim.new(0, 10)

local FolderIcon = Instance.new("ImageLabel")
FolderIcon.Image = "rbxassetid://16584282361" 
FolderIcon.Size = UDim2.new(0, 20, 0, 20)
FolderIcon.Position = UDim2.new(0, 10, 0.5, -10)
FolderIcon.BackgroundTransparency = 1
FolderIcon.Parent = RouteBtn

local CheckpointLabel = Instance.new("TextLabel")
CheckpointLabel.Name = "CheckpointStatus"
CheckpointLabel.Text = "Checkpoint : -"
CheckpointLabel.Font = Enum.Font.GothamBold
CheckpointLabel.TextColor3 = Color3.fromRGB(255, 200, 50) 
CheckpointLabel.TextSize = 14
CheckpointLabel.Size = UDim2.new(1, 0, 0, 20)
CheckpointLabel.Position = UDim2.new(0, 0, 0.48, 0)
CheckpointLabel.BackgroundTransparency = 1
CheckpointLabel.Visible = false 
CheckpointLabel.Parent = AutoWalkPage

local SpeedContainer = Instance.new("Frame")
SpeedContainer.Size = UDim2.new(0.8, 0, 0, 50)
SpeedContainer.Position = UDim2.new(0.1, 0, 0.56, 0) 
SpeedContainer.BackgroundTransparency = 1
SpeedContainer.Visible = false 
SpeedContainer.Parent = AutoWalkPage

local SpeedTitle = Instance.new("TextLabel")
SpeedTitle.Text = "Atur Kecepatan Auto Walk"
SpeedTitle.TextColor3 = Color3.new(1,1,1)
SpeedTitle.Font = Enum.Font.GothamMedium
SpeedTitle.TextSize = 12
SpeedTitle.Size = UDim2.new(1, 0, 0, 20)
SpeedTitle.Position = UDim2.new(0, 0, 0, 0)
SpeedTitle.BackgroundTransparency = 1
SpeedTitle.Parent = SpeedContainer

local MinusBtn = Instance.new("TextButton")
MinusBtn.Text = "-"
MinusBtn.TextColor3 = Color3.new(1,1,1)
MinusBtn.TextSize = 18
MinusBtn.Font = Enum.Font.GothamBold
MinusBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
MinusBtn.Size = UDim2.new(0, 30, 0, 30)
MinusBtn.Position = UDim2.new(0, 0, 0, 20)
MinusBtn.Parent = SpeedContainer
Instance.new("UICorner", MinusBtn).CornerRadius = UDim.new(0, 6)

local SpeedValLabel = Instance.new("TextLabel")
SpeedValLabel.Text = "1"
SpeedValLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
SpeedValLabel.Font = Enum.Font.GothamBold
SpeedValLabel.TextSize = 18
SpeedValLabel.Size = UDim2.new(1, -60, 0, 30)
SpeedValLabel.Position = UDim2.new(0, 30, 0, 20)
SpeedValLabel.BackgroundTransparency = 1
SpeedValLabel.Parent = SpeedContainer

local PlusBtn = Instance.new("TextButton")
PlusBtn.Text = "+"
PlusBtn.TextColor3 = Color3.new(1,1,1)
PlusBtn.TextSize = 18
PlusBtn.Font = Enum.Font.GothamBold
PlusBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
PlusBtn.Size = UDim2.new(0, 30, 0, 30)
PlusBtn.Position = UDim2.new(1, -30, 0, 20)
PlusBtn.Parent = SpeedContainer
Instance.new("UICorner", PlusBtn).CornerRadius = UDim.new(0, 6)

local ToggleContainer = Instance.new("Frame")
ToggleContainer.Size = UDim2.new(0.8, 0, 0, 30)
ToggleContainer.Position = UDim2.new(0.1, 0, 0.82, 0) 
ToggleContainer.BackgroundTransparency = 1
ToggleContainer.Visible = false 
ToggleContainer.Parent = AutoWalkPage

local ToggleLabel = Instance.new("TextLabel")
ToggleLabel.Text = "Show Menu Auto Walk"
ToggleLabel.TextColor3 = Color3.new(1,1,1)
ToggleLabel.Font = Enum.Font.GothamMedium
ToggleLabel.TextSize = 12
ToggleLabel.Size = UDim2.new(0.7, 0, 1, 0)
ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
ToggleLabel.BackgroundTransparency = 1
ToggleLabel.Parent = ToggleContainer

local SwitchBg = Instance.new("TextButton")
SwitchBg.Text = ""
SwitchBg.Size = UDim2.new(0, 40, 0, 20)
SwitchBg.Position = UDim2.new(1, -40, 0.5, -10)
SwitchBg.BackgroundColor3 = Color3.fromRGB(80, 80, 80) 
SwitchBg.Parent = ToggleContainer
Instance.new("UICorner", SwitchBg).CornerRadius = UDim.new(1, 0)

local SwitchKnob = Instance.new("Frame")
SwitchKnob.Size = UDim2.new(0, 16, 0, 16)
SwitchKnob.Position = UDim2.new(0, 2, 0.5, -8) 
SwitchKnob.BackgroundColor3 = Color3.new(1,1,1)
SwitchKnob.Parent = SwitchBg
Instance.new("UICorner", SwitchKnob).CornerRadius = UDim.new(1, 0)

local AwBackBtn = Instance.new("TextButton")
AwBackBtn.Text = "<"
AwBackBtn.TextColor3 = Color3.new(1,1,1)
AwBackBtn.Font = Enum.Font.Antique
AwBackBtn.TextSize = 20 
AwBackBtn.Size = UDim2.new(0, 30, 0, 30)
AwBackBtn.Position = UDim2.new(0, 10, 0.88, 0)
AwBackBtn.BackgroundTransparency = 0.6
AwBackBtn.BackgroundColor3 = Color3.new(0,0,0)
AwBackBtn.Parent = AutoWalkPage
Instance.new("UICorner", AwBackBtn).CornerRadius = UDim.new(0, 10)

-- DROPDOWN
local DropdownFrame = Instance.new("Frame")
DropdownFrame.Name = "FileDropdown"
DropdownFrame.Size = UDim2.new(0.8, 0, 0.4, 0)
DropdownFrame.Position = UDim2.new(0.1, 0, 0.45, 0) 
DropdownFrame.BackgroundColor3 = Color3.new(1,1,1) 
DropdownFrame.BackgroundTransparency = 1 
DropdownFrame.BorderSizePixel = 0
DropdownFrame.Visible = false 
DropdownFrame.ZIndex = 8
DropdownFrame.Parent = AutoWalkPage

local ScrollList = Instance.new("ScrollingFrame")
ScrollList.Size = UDim2.new(1, 0, 1, 0)
ScrollList.BackgroundTransparency = 1
ScrollList.ScrollBarThickness = 2
ScrollList.Parent = DropdownFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Parent = ScrollList
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 2)

-- FLOATING UI
local FloatingUI = Instance.new("Frame")
FloatingUI.Name = "FloatingControl"
FloatingUI.Size = UDim2.new(0, 180, 0, 50) 
FloatingUI.Position = UDim2.new(0.7, 0, 0.4, 0)
FloatingUI.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
FloatingUI.BackgroundTransparency = 0.2
FloatingUI.Visible = false 
FloatingUI.Active = true 
FloatingUI.Parent = ScreenGui 
Instance.new("UICorner", FloatingUI).CornerRadius = UDim.new(0, 10)

local FloatStroke = Instance.new("UIStroke", FloatingUI)
FloatStroke.Color = Color3.fromRGB(0, 170, 255)
FloatStroke.Thickness = 1.5

local StartStopBtn = Instance.new("TextButton")
StartStopBtn.Text = "Start"
StartStopBtn.Size = UDim2.new(0.28, 0, 0.7, 0) 
StartStopBtn.Position = UDim2.new(0.03, 0, 0.15, 0)
StartStopBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255) 
StartStopBtn.TextColor3 = Color3.new(1,1,1)
StartStopBtn.Font = Enum.Font.GothamBold
StartStopBtn.TextSize = 11
StartStopBtn.Parent = FloatingUI
Instance.new("UICorner", StartStopBtn).CornerRadius = UDim.new(0, 6)

local FlipBtn = Instance.new("TextButton")
FlipBtn.Text = "Flip"
FlipBtn.Size = UDim2.new(0.28, 0, 0.7, 0) 
FlipBtn.Position = UDim2.new(0.36, 0, 0.15, 0) 
FlipBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 50) 
FlipBtn.TextColor3 = Color3.new(1,1,1)
FlipBtn.Font = Enum.Font.GothamBold
FlipBtn.TextSize = 11
FlipBtn.Parent = FloatingUI
Instance.new("UICorner", FlipBtn).CornerRadius = UDim.new(0, 6)

local RevBtn = Instance.new("TextButton")
RevBtn.Text = "REV"
RevBtn.Size = UDim2.new(0.28, 0, 0.7, 0) 
RevBtn.Position = UDim2.new(0.69, 0, 0.15, 0) 
RevBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 200) 
RevBtn.TextColor3 = Color3.new(1,1,1)
RevBtn.Font = Enum.Font.GothamBold
RevBtn.TextSize = 11
RevBtn.Parent = FloatingUI
Instance.new("UICorner", RevBtn).CornerRadius = UDim.new(0, 6)

-- MUSIC PAGE
local MusicPage = Instance.new("Frame")
MusicPage.Name = "MusicPage"
MusicPage.Size = UDim2.new(1, 0, 1, 0)
MusicPage.Position = UDim2.new(0, 0, 1, 0) 
MusicPage.BackgroundTransparency = 1 
MusicPage.ZIndex = 6
MusicPage.Parent = PhoneFrame

local OverlayMusic = Instance.new("Frame")
OverlayMusic.Size = UDim2.new(1, 0, 1, 0)
OverlayMusic.BackgroundColor3 = Color3.new(0,0,0)
OverlayMusic.BackgroundTransparency = 0.5
OverlayMusic.Parent = MusicPage
Instance.new("UICorner", OverlayMusic).CornerRadius = UDim.new(0, 30)

local MusicTitle = Instance.new("TextLabel")
MusicTitle.Text = "Music Player"
MusicTitle.Font = Enum.Font.GothamBold
MusicTitle.TextColor3 = Color3.new(1,1,1)
MusicTitle.TextSize = 18
MusicTitle.Size = UDim2.new(1, 0, 0, 30)
MusicTitle.Position = UDim2.new(0, 0, 0, 40)
MusicTitle.BackgroundTransparency = 1
MusicTitle.Parent = MusicPage

local InputContainer = Instance.new("Frame")
InputContainer.Size = UDim2.new(0.8, 0, 0, 40)
InputContainer.Position = UDim2.new(0.1, 0, 0.3, 0)
InputContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
InputContainer.Parent = MusicPage
Instance.new("UICorner", InputContainer).CornerRadius = UDim.new(0, 10)

local IdInput = Instance.new("TextBox")
IdInput.Size = UDim2.new(1, -20, 1, 0)
IdInput.Position = UDim2.new(0, 10, 0, 0)
IdInput.BackgroundTransparency = 1
IdInput.Text = ""
IdInput.PlaceholderText = "Masukan ID Boombox..."
IdInput.TextColor3 = Color3.new(1,1,1)
IdInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
IdInput.Font = Enum.Font.Gotham
IdInput.TextSize = 14
IdInput.Parent = InputContainer

local ControlsContainer = Instance.new("Frame")
ControlsContainer.Size = UDim2.new(0.9, 0, 0, 50)
ControlsContainer.Position = UDim2.new(0.05, 0, 0.5, 0)
ControlsContainer.BackgroundTransparency = 1
ControlsContainer.Parent = MusicPage

local StopMBtn = Instance.new("TextButton")
StopMBtn.Text = "Stop"
StopMBtn.Size = UDim2.new(0.25, 0, 0.8, 0)
StopMBtn.Position = UDim2.new(0, 0, 0.1, 0)
StopMBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50) 
StopMBtn.TextColor3 = Color3.new(1,1,1)
StopMBtn.Font = Enum.Font.GothamBold
StopMBtn.TextSize = 12
StopMBtn.Parent = ControlsContainer
Instance.new("UICorner", StopMBtn).CornerRadius = UDim.new(0, 8)

local PlayMBtn = Instance.new("TextButton")
PlayMBtn.Text = "Play"
PlayMBtn.Size = UDim2.new(0.25, 0, 0.8, 0)
PlayMBtn.Position = UDim2.new(0.75, 0, 0.1, 0)
PlayMBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255) 
PlayMBtn.TextColor3 = Color3.new(1,1,1)
PlayMBtn.Font = Enum.Font.GothamBold
PlayMBtn.TextSize = 12
PlayMBtn.Parent = ControlsContainer
Instance.new("UICorner", PlayMBtn).CornerRadius = UDim.new(0, 8)

local VolMinus = Instance.new("TextButton")
VolMinus.Text = "-"
VolMinus.Size = UDim2.new(0.15, 0, 0.6, 0)
VolMinus.Position = UDim2.new(0.30, 0, 0.2, 0)
VolMinus.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
VolMinus.TextColor3 = Color3.new(1,1,1)
VolMinus.Font = Enum.Font.GothamBold
VolMinus.Parent = ControlsContainer
Instance.new("UICorner", VolMinus).CornerRadius = UDim.new(0, 5)

local VolLabel = Instance.new("TextLabel")
VolLabel.Text = "100"
VolLabel.Size = UDim2.new(0.15, 0, 0.6, 0)
VolLabel.Position = UDim2.new(0.45, 0, 0.2, 0)
VolLabel.BackgroundTransparency = 1
VolLabel.TextColor3 = Color3.new(1,1,1)
VolLabel.Font = Enum.Font.Gotham
VolLabel.TextSize = 12
VolLabel.Parent = ControlsContainer

local VolPlus = Instance.new("TextButton")
VolPlus.Text = "+"
VolPlus.Size = UDim2.new(0.15, 0, 0.6, 0)
VolPlus.Position = UDim2.new(0.60, 0, 0.2, 0)
VolPlus.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
VolPlus.TextColor3 = Color3.new(1,1,1)
VolPlus.Font = Enum.Font.GothamBold
VolPlus.Parent = ControlsContainer
Instance.new("UICorner", VolPlus).CornerRadius = UDim.new(0, 5)

local MusicBackBtn = Instance.new("TextButton")
MusicBackBtn.Text = "<"
MusicBackBtn.TextColor3 = Color3.new(1,1,1)
MusicBackBtn.Font = Enum.Font.Antique
MusicBackBtn.TextSize = 20 
MusicBackBtn.Size = UDim2.new(0, 30, 0, 30)
MusicBackBtn.Position = UDim2.new(0, 10, 0.88, 0)
MusicBackBtn.BackgroundTransparency = 0.6
MusicBackBtn.BackgroundColor3 = Color3.new(0,0,0)
MusicBackBtn.Parent = MusicPage
Instance.new("UICorner", MusicBackBtn).CornerRadius = UDim.new(0, 10)

-------------------------------------------------------------------------
-- LOGIC CONNECTIONS
-------------------------------------------------------------------------
local currentLoadedFile = nil
local speedList = {0.9, 1, 1.1, 1.2, 1.3, 1.5, 1.6, 1.7, 2, 3}
local speedIndex = 2

-- Update speed display
function UpdateSpeedDisplay()
    SpeedValLabel.Text = tostring(speedList[speedIndex])
    TASPlayback.playbackSpeed = speedList[speedIndex]
end

MinusBtn.MouseButton1Click:Connect(function()
    if speedIndex > 1 then
        speedIndex = speedIndex - 1
        UpdateSpeedDisplay()
    end
end)

PlusBtn.MouseButton1Click:Connect(function()
    if speedIndex < #speedList then
        speedIndex = speedIndex + 1
        UpdateSpeedDisplay()
    end
end)

-- Start/Stop Button Logic
StartStopBtn.MouseButton1Click:Connect(function()
    if not currentLoadedFile then
        ShowNotification("No route loaded!")
        return
    end
    
    if TASPlayback.isPlaying then
        -- Stop playback
        local success, msg = TASPlayback:Stop()
        if success then
            StartStopBtn.Text = "Start"
            StartStopBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
            ShowNotification("Playback stopped")
        end
    else
        -- Start playback
        local success, msg = TASPlayback:Start()
        if success then
            StartStopBtn.Text = "Stop"
            StartStopBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
            ShowNotification("Playback started")
        else
            ShowNotification(msg or "Failed to start")
        end
    end
end)

-- Flip Button Logic
FlipBtn.MouseButton1Click:Connect(function()
    local flipped = TASPlayback:ToggleFlip()
    FlipBtn.TextTransparency = 0.5
    task.wait(0.1)
    FlipBtn.TextTransparency = 0
    
    if flipped then
        ShowNotification("Flip: ON")
    else
        ShowNotification("Flip: OFF")
    end
end)

-- REV Button Logic
RevBtn.MouseButton1Click:Connect(function()
    if not TASPlayback.isPlaying then
        ShowNotification("Start playback first!")
        return
    end
    
    local reversed = TASPlayback:ToggleReverse()
    RevBtn.TextTransparency = 0.5
    task.wait(0.1)
    RevBtn.TextTransparency = 0
    
    if reversed then
        RevBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 255)
        ShowNotification("REV: ON (Backward)")
    else
        RevBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 200)
        ShowNotification("REV: OFF (Forward)")
    end
end)

-- External menu toggle
local externalMenuOn = false
SwitchBg.MouseButton1Click:Connect(function()
    externalMenuOn = not externalMenuOn
    if externalMenuOn then
        SwitchKnob:TweenPosition(UDim2.new(1, -18, 0.5, -8), "Out", "Quad", 0.2, true)
        SwitchBg.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
        FloatingUI.Visible = true 
    else
        SwitchKnob:TweenPosition(UDim2.new(0, 2, 0.5, -8), "Out", "Quad", 0.2, true)
        SwitchBg.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        FloatingUI.Visible = false 
    end
end)

-- Rainbow effect for route status
local rainbowTask = nil
function PlayRouteEffect()
    if rainbowTask then task.cancel(rainbowTask) end
    rainbowTask = task.spawn(function()
        local startTime = tick()
        while tick() - startTime < 2 do
            local hue = tick() % 1 / 1
            RouteStatus.TextColor3 = Color3.fromHSV(hue, 1, 1)
            task.wait()
        end
        RouteStatus.TextColor3 = Color3.new(1,1,1) 
    end)
end

-- Refresh file list
function RefreshFileList()
    for _, child in pairs(ScrollList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    
    local success, files = pcall(function()
        if isfolder and isfolder("Delta/workspace") then
            return listfiles("Delta/workspace")
        else
            return listfiles("")
        end
    end)
    
    if success and files then
        for _, filePath in pairs(files) do
            if string.sub(filePath, -5) == ".json" then
                local fileName = string.match(filePath, "([^/]+)$") 
                local displayName = string.gsub(fileName, "%.json$", "") 
                
                local FileBtn = Instance.new("TextButton")
                FileBtn.Size = UDim2.new(1, 0, 0, 25)
                FileBtn.BackgroundTransparency = 1 
                FileBtn.Text = displayName 
                FileBtn.TextColor3 = Color3.new(1,1,1) 
                FileBtn.Font = Enum.Font.GothamBold
                FileBtn.TextSize = 14
                FileBtn.Parent = ScrollList
                
                FileBtn.MouseButton1Click:Connect(function()
                    -- Load file into TASPlayback
                    local loadSuccess, loadMsg = TASPlayback:LoadFile(filePath)
                    
                    if loadSuccess then
                        currentLoadedFile = filePath
                        RouteStatus.Text = "Route: " .. displayName
                        PlayRouteEffect()
                        ShowNotification("File " .. displayName .. " loaded!")
                        DropdownFrame.Visible = false 
                        CheckpointLabel.Visible = true
                        SpeedContainer.Visible = true
                        ToggleContainer.Visible = true
                    else
                        ShowNotification("Failed to load file")
                    end
                end)
            end
        end
    end
    
    ScrollList.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y)
end

-- Route button
RouteBtn.MouseButton1Click:Connect(function()
    DropdownFrame.Visible = not DropdownFrame.Visible
    if DropdownFrame.Visible then
        RefreshFileList()
        CheckpointLabel.Visible = false
        SpeedContainer.Visible = false
        ToggleContainer.Visible = false
    end
end)

-- App buttons
if AppButtons["File"] then
    AppButtons["File"].MouseButton1Click:Connect(function()
        AutoWalkPage:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.4, true)
        ShowNotification("Playback menu opened")
        task.wait(0.1)
        MainMenu.Visible = false 
        AutoWalkPage.Visible = true
    end)
end

AwBackBtn.MouseButton1Click:Connect(function()
    MainMenu.Visible = true
    AutoWalkPage:TweenPosition(UDim2.new(0, 0, 1, 0), "In", "Quad", 0.4, true)
    DropdownFrame.Visible = false 
end)

-------------------------------------------------------------------------
-- MUSIC CONTROLS
-------------------------------------------------------------------------
local isMinimized = false
local currentWidgetPage = 1 
local touchStartX = 0

function SwitchWidget(direction)
    if not isMinimized then return end
    if direction == "Left" and currentWidgetPage == 1 then
        PageStatus:TweenPosition(UDim2.new(-1, 0, 0, 0), "Out", "Quad", 0.3, true)
        PageMusic.Position = UDim2.new(1, 0, 0, 0)
        PageMusic:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.3, true)
        currentWidgetPage = 2
    elseif direction == "Right" and currentWidgetPage == 2 then
        PageMusic:TweenPosition(UDim2.new(1, 0, 0, 0), "Out", "Quad", 0.3, true)
        PageStatus.Position = UDim2.new(-1, 0, 0, 0)
        PageStatus:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.3, true)
        currentWidgetPage = 1
    end
end

StatusBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        touchStartX = input.Position.X
    end
end)

StatusBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        local delta = input.Position.X - touchStartX
        if delta < -30 then
            SwitchWidget("Left")
        elseif delta > 30 then
            SwitchWidget("Right")
        end
    end
end)

local function formatTime(seconds)
    if not seconds then return "00:00" end
    local min = math.floor(seconds / 60)
    local sec = math.floor(seconds % 60)
    return string.format("%02d:%02d", min, sec)
end

task.spawn(function()
    while true do
        if AudioPlayer.IsPlaying then
            if isMinimized and currentWidgetPage == 2 then
                local current = AudioPlayer.TimePosition
                local total = AudioPlayer.TimeLength
                MusicTimeLabel.Text = formatTime(current) .. " / " .. formatTime(total)
            end
            for _, bar in pairs(Bars) do
                local targetHeight = math.random(20, 100) / 100
                bar:TweenSize(UDim2.new(0, 4, targetHeight, 0), "Out", "Quad", 0.1, true)
            end
        else
            MusicTimeLabel.Text = "00:00 / 00:00"
            for _, bar in pairs(Bars) do
                bar.Size = UDim2.new(0, 4, 0.2, 0)
            end
        end
        task.wait(0.1)
    end
end)

PlayMBtn.MouseButton1Click:Connect(function()
    local id = IdInput.Text
    if tonumber(id) then
        AudioPlayer.SoundId = "rbxassetid://" .. id
        AudioPlayer:Play()
    elseif string.find(id, "rbxassetid") then
        AudioPlayer.SoundId = id
        AudioPlayer:Play()
    end
end)

StopMBtn.MouseButton1Click:Connect(function()
    AudioPlayer:Stop()
end)

local currentVol = 100
VolMinus.MouseButton1Click:Connect(function()
    if currentVol > 0 then
        currentVol = currentVol - 10
        VolLabel.Text = tostring(currentVol)
        AudioPlayer.Volume = currentVol / 100
    end
end)

VolPlus.MouseButton1Click:Connect(function()
    if currentVol < 100 then
        currentVol = currentVol + 10
        VolLabel.Text = tostring(currentVol)
        AudioPlayer.Volume = currentVol / 100
    end
end)

if AppButtons["Music"] then
    AppButtons["Music"].MouseButton1Click:Connect(function()
        MusicPage:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.4, true)
        ShowNotification("Music menu opened")
        task.wait(0.1)
        MainMenu.Visible = false
        MusicPage.Visible = true
    end)
end

MusicBackBtn.MouseButton1Click:Connect(function()
    MainMenu.Visible = true
    MusicPage:TweenPosition(UDim2.new(0, 0, 1, 0), "In", "Quad", 0.4, true)
end)

-------------------------------------------------------------------------
-- MINIMIZE
-------------------------------------------------------------------------
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        PhoneFrame:TweenSize(UDim2.new(0, 181, 0, 35), "Out", "Quad", 0.3, true)
        Wallpaper.Visible = false
        MainMenu.Visible = false
        AutoWalkPage.Visible = false
        MusicPage.Visible = false
        NormalTime.Visible = false
        NormalFps.Visible = false
        WidgetContainer.Visible = true
        MinBtn.Text = "+"
        PageStatus.Position = UDim2.new(0,0,0,0)
        PageMusic.Position = UDim2.new(1,0,0,0)
        currentWidgetPage = 1
        MiniCheckpoint.Visible = true 
    else
        PhoneFrame:TweenSize(UDim2.new(0, 181, 0, 368), "Out", "Back", 0.4, true)
        Wallpaper.Visible = true
        MainMenu.Visible = true
        NormalTime.Visible = true
        NormalFps.Visible = true
        WidgetContainer.Visible = false
        MinBtn.Text = "-"
    end
end)

-------------------------------------------------------------------------
-- PHONE TOGGLE & DRAG
-------------------------------------------------------------------------
local savedPosition = UDim2.new(0.5, -90, 0.5, -184) 
local isOpen = false

ToggleBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    if isOpen then
        PhoneFrame:TweenPosition(savedPosition, Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.6, true)
        ShowNotification("Phone menu opened")
        if isMinimized then
            WidgetContainer.Visible = true
            NormalTime.Visible = false
            NormalFps.Visible = false
        else
            WidgetContainer.Visible = false
            NormalTime.Visible = true
            NormalFps.Visible = true
        end
    else
        local currentX = PhoneFrame.Position.X
        PhoneFrame:TweenPosition(UDim2.new(currentX.Scale, currentX.Offset, 1.5, 0), Enum.EasingDirection.In, Enum.EasingStyle.Back, 0.6, true)
        MainMenu.Visible = true
        AutoWalkPage.Position = UDim2.new(0,0,1,0)
    end
end)

local MainBackBtn = Instance.new("TextButton")
MainBackBtn.Text = "<"
MainBackBtn.TextColor3 = Color3.new(1,1,1)
MainBackBtn.Font = Enum.Font.Antique
MainBackBtn.TextSize = 20 
MainBackBtn.Size = UDim2.new(0, 30, 0, 30)
MainBackBtn.Position = UDim2.new(0, 10, 0.88, 0)
MainBackBtn.BackgroundTransparency = 0.6
MainBackBtn.BackgroundColor3 = Color3.new(0,0,0)
MainBackBtn.ZIndex = 3
MainBackBtn.Parent = MainMenu 
Instance.new("UICorner", MainBackBtn).CornerRadius = UDim.new(0, 10)

MainBackBtn.MouseButton1Click:Connect(function()
    isOpen = false
    local currentX = PhoneFrame.Position.X
    PhoneFrame:TweenPosition(UDim2.new(currentX.Scale, currentX.Offset, 1.5, 0), Enum.EasingDirection.In, Enum.EasingStyle.Back, 0.6, true)
end)

-- Drag Phone
local draggingPhone, dragStartPhone, startPosPhone
PhoneFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingPhone = true
        dragStartPhone = input.Position
        startPosPhone = PhoneFrame.Position
    end
end)

PhoneFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingPhone = false
        savedPosition = PhoneFrame.Position 
    end
end)

UIS.InputChanged:Connect(function(input)
    if draggingPhone and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartPhone
        PhoneFrame.Position = UDim2.new(startPosPhone.X.Scale, startPosPhone.X.Offset + delta.X, startPosPhone.Y.Scale, startPosPhone.Y.Offset + delta.Y)
        savedPosition = PhoneFrame.Position 
    end
end)

-- Drag Floating UI
local dragFloat, startFloat, startPosFloat
FloatingUI.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragFloat = true
        startFloat = input.Position
        startPosFloat = FloatingUI.Position
    end
end)

FloatingUI.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragFloat = false
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragFloat and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - startFloat
        FloatingUI.Position = UDim2.new(startPosFloat.X.Scale, startPosFloat.X.Offset + delta.X, startPosFloat.Y.Scale, startPosFloat.Y.Offset + delta.Y)
    end
end)

-- Drag Toggle Button
local dragging, dragStart, startPos
ToggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = ToggleBtn.Position
    end
end)

ToggleBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        ToggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-------------------------------------------------------------------------
-- BACKGROUND TASKS
-------------------------------------------------------------------------
-- Update time
task.spawn(function()
    while true do
        local wibTime = os.time() + (7 * 3600) 
        NormalTime.Text = os.date("!%H:%M", wibTime) 
        task.wait(1)
    end
end)

-- Update FPS
task.spawn(function()
    while true do
        local fps = math.floor(1 / RunService.RenderStepped:Wait())
        local fpsText = fps .. " FPS"
        NormalFps.Text = fpsText
        MiniFpsLabel.Text = fpsText 
        task.wait(0.5) 
    end
end)

-- Rainbow animation for STATUS text
task.spawn(function()
    while true do
        local t = 5
        local hue = tick() % t / t
        local color = Color3.fromHSV(hue, 1, 1)
        VipTxt.TextColor3 = color
        task.wait()
    end
end)

-- Update checkpoint
task.spawn(function()
    while true do
        local p = Players.LocalPlayer
        local stage = "N/A"
        if p:FindFirstChild("leaderstats") and p.leaderstats:FindFirstChild("Stage") then
            stage = p.leaderstats.Stage.Value
        elseif p:FindFirstChild("leaderstats") and p.leaderstats:FindFirstChild("Checkpoint") then
            stage = p.leaderstats.Checkpoint.Value
        end
        CheckpointLabel.Text = "Checkpoint : " .. tostring(stage)
        MiniCheckpoint.Text = "Checkpoint: " .. tostring(stage) 
        task.wait(1)
    end
end)

print("Cellestial Phone V33 with TAS Playback & REV Feature loaded successfully!")
