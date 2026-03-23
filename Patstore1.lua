--// SETTINGS
local KEY_URL = "https://raw.githubusercontent.com/patraakunkedua-sketch/Patstore/main/keys.txt?t="..tick()
local SCRIPT_URL = "https://raw.githubusercontent.com/patraakunkedua-sketch/Patstore/main/Patstore.lua"

--// SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer

--// HWID
local function getHWID()
    return player.UserId .. "-" .. game:GetService("RbxAnalyticsService"):GetClientId()
end

--// CHECK KEY
local function checkKey(input)
    local success, data = pcall(function()
        return game:HttpGet(KEY_URL)
    end)

    if not success or not data then
        return false, "Gagal ambil key"
    end

    local myHWID = getHWID()

    for line in string.gmatch(data, "[^\r\n]+") do
        local key, hwid = line:match("([^|]+)|([^|]+)")

        if key and hwid then
            key = key:gsub("%s+", "")
            hwid = hwid:gsub("%s+", "")

            if key == input then
                if hwid == myHWID then
                    return true, "Login berhasil"
                elseif hwid == "0" then
                    return false, "Key belum aktif"
                else
                    return false, "Key dipakai device lain"
                end
            end
        end
    end

    return false, "Key tidak ditemukan"
end

--// GUI
local sg = Instance.new("ScreenGui", game.CoreGui)
sg.Name = "PATSTORE_UI"

-- Blur background
local blur = Instance.new("BlurEffect", game.Lighting)
blur.Size = 12

-- MAIN FRAME
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 340, 0, 220)
main.Position = UDim2.new(0.5, -170, 0.5, -110)
main.BackgroundColor3 = Color3.fromRGB(15,15,25)
main.BorderSizePixel = 0

-- Rounded corner
local corner = Instance.new("UICorner", main)
corner.CornerRadius = UDim.new(0, 12)

-- Soft stroke
local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(0,120,255)
stroke.Thickness = 1.5
stroke.Transparency = 0.3

-- Shadow fake (simple)
local shadow = Instance.new("Frame", sg)
shadow.Size = main.Size
shadow.Position = main.Position + UDim2.new(0,5,0,5)
shadow.BackgroundColor3 = Color3.new(0,0,0)
shadow.BackgroundTransparency = 0.6
shadow.ZIndex = 0

local shadowCorner = Instance.new("UICorner", shadow)
shadowCorner.CornerRadius = UDim.new(0, 12)

main.ZIndex = 1

-- TITLE
local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1,0,0,40)
title.BackgroundTransparency = 1
title.Text = "PATSTORE"
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(0,170,255)

-- INPUT
local box = Instance.new("TextBox", main)
box.Size = UDim2.new(1,-40,0,40)
box.Position = UDim2.new(0,20,0,60)
box.BackgroundColor3 = Color3.fromRGB(25,25,35)
box.TextColor3 = Color3.new(1,1,1)
box.PlaceholderText = "Enter key..."
box.BorderSizePixel = 0

Instance.new("UICorner", box).CornerRadius = UDim.new(0,8)

-- LOGIN BUTTON
local login = Instance.new("TextButton", main)
login.Size = UDim2.new(1,-40,0,40)
login.Position = UDim2.new(0,20,0,110)
login.Text = "LOGIN"
login.Font = Enum.Font.GothamBold
login.TextColor3 = Color3.new(1,1,1)
login.BackgroundColor3 = Color3.fromRGB(0,120,255)
login.BorderSizePixel = 0

Instance.new("UICorner", login).CornerRadius = UDim.new(0,8)

-- GET KEY
local getkey = Instance.new("TextButton", main)
getkey.Size = UDim2.new(1,-40,0,30)
getkey.Position = UDim2.new(0,20,0,155)
getkey.Text = "Get Key "
getkey.Font = Enum.Font.Gotham
getkey.TextColor3 = Color3.fromRGB(0,170,255)
getkey.BackgroundTransparency = 1

-- STATUS
local status = Instance.new("TextLabel", main)
status.Size = UDim2.new(1,-20,0,20)
status.Position = UDim2.new(0,10,1,-25)
status.Text = "LOGIN DENGAN USER ID JIKA BELUM PUNYA DAPATKAN DULU KODE NYA KIRIM KE ADMIN"
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(180,180,180)
status.TextScaled = true

-- DRAG SYSTEM
local dragging, dragStart, startPos

main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
        shadow.Position = main.Position + UDim2.new(0,5,0,5)
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- HOVER
login.MouseEnter:Connect(function()
    TweenService:Create(login, TweenInfo.new(0.2), {
        BackgroundColor3 = Color3.fromRGB(0,150,255)
    }):Play()
end)

login.MouseLeave:Connect(function()
    TweenService:Create(login, TweenInfo.new(0.2), {
        BackgroundColor3 = Color3.fromRGB(0,120,255)
    }):Play()
end)

-- GET KEY
getkey.MouseButton1Click:Connect(function()
    local hwid = getHWID()

    if setclipboard then
        setclipboard(hwid)
    end

    game.StarterGui:SetCore("SendNotification", {
        Title = "PATSTORE",
        Text = "🔑 HWID sudah di-copy!\nKirim ke admin",
        Duration = 5
    })

    status.Text = "HWID copied!"
end)

-- LOGIN
login.MouseButton1Click:Connect(function()
    local input = box.Text

    if input == "" then
        status.Text = "Masukkan key!"
        return
    end

    status.Text = "Checking..."

    local valid, msg = checkKey(input)
    status.Text = msg

    if valid then
        TweenService:Create(main, TweenInfo.new(0.3), {
            Position = UDim2.new(0.5, -170, 1.2, 0)
        }):Play()

        task.wait(0.4)
        sg:Destroy()
        blur:Destroy()

        loadstring(game:HttpGet(SCRIPT_URL))()
    end
end)
