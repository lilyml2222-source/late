
if game.CoreGui:FindFirstChild("IZIN") then
    game.CoreGui:FindFirstChild("IZIN"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "IZIN"
ScreenGui.ResetOnSpawn = false


local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 350, 0, 200)
Frame.Position = UDim2.new(0.5, -175, 0.5, -100)
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Frame.BorderSizePixel = 0
Frame.BackgroundTransparency = 1
Frame.ClipsDescendants = true


local Corner = Instance.new("UICorner", Frame)
Corner.CornerRadius = UDim.new(0, 15)


local Shadow = Instance.new("ImageLabel", Frame)
Shadow.Size = UDim2.new(1, 30, 1, 30)
Shadow.Position = UDim2.new(0, -15, 0, -15)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://1316045217"
Shadow.ImageColor3 = Color3.fromRGB(0,0,0)
Shadow.ImageTransparency = 0.4

local Title = Instance.new("TextLabel", Frame)
Title.Text = "Discord Resmi WataX"
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 22


local Link = Instance.new("TextLabel", Frame)
Link.Text = "https://discord.gg/YUpJ6WhmQg"
Link.Size = UDim2.new(1, 0, 0, 40)
Link.Position = UDim2.new(0, 0, 0, 50)
Link.BackgroundTransparency = 1
Link.TextColor3 = Color3.fromRGB(150, 200, 255)
Link.Font = Enum.Font.Gotham
Link.TextSize = 20


local CopyBtn = Instance.new("TextButton", Frame)
CopyBtn.Text = "Copy Link"
CopyBtn.Size = UDim2.new(0, 140, 0, 40)
CopyBtn.Position = UDim2.new(0.5, -150/2, 0, 110)
CopyBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 255)
CopyBtn.TextColor3 = Color3.new(1,1,1)
CopyBtn.Font = Enum.Font.GothamBold
CopyBtn.TextSize = 18
Instance.new("UICorner", CopyBtn).CornerRadius = UDim.new(0, 10)


local CloseBtn = Instance.new("TextButton", Frame)
CloseBtn.Text = "Close"
CloseBtn.Size = UDim2.new(0, 140, 0, 40)
CloseBtn.Position = UDim2.new(0.5, -150/2, 0, 160)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.TextColor3 = Color3.new(1,1,1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 10)


Frame:TweenSize(UDim2.new(0, 350, 0, 200), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.4, true)
game.TweenService:Create(Frame, TweenInfo.new(0.4), {BackgroundTransparency = 0}):Play()


CopyBtn.MouseButton1Click:Connect(function()
    setclipboard("https://discord.gg/YUpJ6WhmQg")
    CopyBtn.Text = "Copied!"
    task.wait(1)
    CopyBtn.Text = "Copy Link"
end)


CloseBtn.MouseButton1Click:Connect(function()
    Frame:TweenSize(UDim2.new(0, 0, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Back, 0.3, true)
    task.wait(0.25)
    ScreenGui:Destroy()
end)


local UIS = game:GetService("UserInputService")
local dragging, dragStart, startPos

Frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Frame.Position
    end
end)

Frame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
