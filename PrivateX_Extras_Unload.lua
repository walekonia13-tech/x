--==============================================================
-- PRIVATE X | COMPLETE VEHICLE CONTROL SUITE
-- Consolidated version | Main menu extras | Improved cleanup
--==============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local STUDS_PER_SECOND_TO_KMH = 1.008
local STUDS_TO_KM = 0.00028

local Camera = Workspace.CurrentCamera
local DefaultFOV = Camera and Camera.FieldOfView or 70

local Settings = {
    Acceleration = 0.5,
    MaxSpeed = 300,
    BrakePower = 1,

    Flight = false,
    Drift = false,
    Handbrake = false,

    ESP = false,
    ESPUnlimitedRange = true,
    ESPDistance = 50000,
    ESPShowHealth = true,
    ESPShowDistance = true,
    ESPShowBoxes = true,
    ESPColor = Color3.fromRGB(255, 70, 70),
    ESPFont = Enum.Font.GothamBlack,

    Underglow = false,
    RainbowUnderglow = false,
    RainbowSpeed = 0.5,
    UnderglowColor = Color3.fromRGB(0, 170, 255),
    UnderglowBrightness = 1.5,
    UnderglowRange = 16,

    EngineSound = false,
    EngineSoundId = "rbxassetid://9120386436",
    EngineVolume = 0.35,
    EnginePreset = "Standard",

    CameraFOV = DefaultFOV,
    OdometerBoost = false,
}

local PaintColors = {
    Body = Color3.fromRGB(255, 255, 255),
    Wheels = Color3.fromRGB(35, 35, 35),
    Glass = Color3.fromRGB(100, 190, 255),
    Lights = Color3.fromRGB(255, 255, 220),
    Interior = Color3.fromRGB(40, 40, 40),
    Trim = Color3.fromRGB(50, 50, 50),
    All = Color3.fromRGB(255, 255, 255),
}

local OriginalProperties = {}
local ESPObjects = {}
local UnderglowObjects = {}
local Connections = {}
local CreatedObjects = {}

local CurrentUnderglowVehicle
local FlightVelocity
local FlightGyro
local EngineSoundObject

local DistanceTravelled = 0
local LastVehicle
local LastPosition

local Unloaded = false
local diagnosticsTimer = 0
local odometerTimer = 0

local function TrackConnection(connection)
    table.insert(Connections, connection)
    return connection
end

local function SafeDestroy(object)
    if object then
        pcall(function()
            object:Destroy()
        end)
    end
end

local function Notify(title, content)
    if Unloaded then
        return
    end

    pcall(function()
        Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = 3,
        })
    end)
end

local function ToKmh(speed)
    return math.floor(speed * STUDS_PER_SECOND_TO_KMH + 0.5)
end

local function ToKm(studs)
    return studs * STUDS_TO_KM
end

--==============================================================
-- RAYFIELD / MENU
--==============================================================

local Rayfield = loadstring(game:HttpGet(
    "https://sirius.menu/rayfield"
))()

local Window = Rayfield:CreateWindow({
    Name = "Private X",
    LoadingTitle = "Private X",
    LoadingSubtitle = "Vehicle Control Suite",
    ConfigurationSaving = {
        Enabled = false,
    },
    KeySystem = false,
})

local MainTab = Window:CreateTab("Main", 4483362458)
local VehicleTab = Window:CreateTab("Vehicle", 4483362458)
local PaintTab = Window:CreateTab("Car Colors", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)
local ExtraTab = Window:CreateTab("Extras", 4483362458)

--==============================================================
-- VEHICLE DETECTION
--==============================================================

local function GetCharacter()
    return LocalPlayer.Character
end

local function GetHumanoid()
    local character = GetCharacter()
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function GetVehicleSeat()
    local humanoid = GetHumanoid()
    local seat = humanoid and humanoid.SeatPart

    if seat and seat:IsA("VehicleSeat") then
        return seat
    end

    return nil
end

local function GetVehicleModel()
    local seat = GetVehicleSeat()
    if not seat then
        return nil
    end

    local current = seat

    while current and current ~= Workspace do
        if current:IsA("Model")
            and current:FindFirstChildWhichIsA("VehicleSeat", true) then
            return current
        end

        current = current.Parent
    end

    return seat:FindFirstAncestorOfClass("Model")
end

local function GetVehicleRoot(model)
    if not model then
        return nil
    end

    if model.PrimaryPart then
        return model.PrimaryPart
    end

    local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
    if seat then
        return seat
    end

    return model:FindFirstChildWhichIsA("BasePart", true)
end

local function GetVehicleParts(model)
    local parts = {}

    if not model then
        return parts
    end

    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("BasePart") then
            table.insert(parts, object)
        end
    end

    return parts
end

--==============================================================
-- CAMERA FOV
-- Applies FOV to the current camera, even if Roblox replaces it.
--==============================================================

local function ApplyFOV(value)
    Settings.CameraFOV = math.clamp(
        tonumber(value) or DefaultFOV,
        40,
        120
    )

    local camera = Workspace.CurrentCamera
    if camera then
        camera.FieldOfView = Settings.CameraFOV
    end
end

TrackConnection(Workspace:GetPropertyChangedSignal(
    "CurrentCamera"
):Connect(function()
    if Unloaded then
        return
    end

    local camera = Workspace.CurrentCamera
    if camera then
        camera.FieldOfView = Settings.CameraFOV
    end
end))

--==============================================================
-- MAIN: ACCELERATION / SPEED / BRAKES
--==============================================================

MainTab:CreateSection("Vehicle Performance")

MainTab:CreateSlider({
    Name = "Acceleration",
    Range = {0.5, 50},
    Increment = 0.5,
    Suffix = "x",
    CurrentValue = Settings.Acceleration,
    Callback = function(value)
        Settings.Acceleration = math.clamp(value, 0.5, 50)
    end,
})

MainTab:CreateSlider({
    Name = "Maximum Speed",
    Range = {50, 1000},
    Increment = 25,
    Suffix = " studs/s",
    CurrentValue = Settings.MaxSpeed,
    Callback = function(value)
        Settings.MaxSpeed = value
    end,
})

MainTab:CreateSlider({
    Name = "Brake Strength",
    Range = {0.5, 10},
    Increment = 0.5,
    Suffix = "x",
    CurrentValue = Settings.BrakePower,
    Callback = function(value)
        Settings.BrakePower = value
    end,
})

local function ApplyVehiclePhysics(dt)
    local seat = GetVehicleSeat()
    local model = GetVehicleModel()
    local root = GetVehicleRoot(model)

    if not seat or not root or root.Anchored then
        return
    end

    local velocity = root.AssemblyLinearVelocity
    local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
    local speed = horizontal.Magnitude

    if seat.Throttle > 0 and speed < Settings.MaxSpeed then
        local look = seat.CFrame.LookVector
        local forward = Vector3.new(look.X, 0, look.Z)

        if forward.Magnitude > 0 then
            forward = forward.Unit

            local accelerationRate = Settings.Acceleration * 8
            local newHorizontal =
                horizontal + forward * accelerationRate * dt

            if newHorizontal.Magnitude > Settings.MaxSpeed then
                newHorizontal =
                    newHorizontal.Unit * Settings.MaxSpeed
            end

            root.AssemblyLinearVelocity = Vector3.new(
                newHorizontal.X,
                velocity.Y,
                newHorizontal.Z
            )
        end
    end

    if seat.Throttle < 0 and speed > 0 then
        local newSpeed = math.max(
            0,
            speed - Settings.BrakePower * 30 * dt
        )

        horizontal = horizontal.Unit * newSpeed

        root.AssemblyLinearVelocity = Vector3.new(
            horizontal.X,
            velocity.Y,
            horizontal.Z
        )
    end

    if Settings.Handbrake and speed > 0 then
        local newSpeed = math.max(0, speed - 100 * dt)
        horizontal = horizontal.Unit * newSpeed

        root.AssemblyLinearVelocity = Vector3.new(
            horizontal.X,
            velocity.Y,
            horizontal.Z
        )
    end

    -- Drift: add controlled sideways slip when steering at speed.
    if Settings.Drift and speed > 8 and seat.Steer ~= 0 then
        local forward = seat.CFrame.LookVector
        forward = Vector3.new(forward.X, 0, forward.Z)

        local right = seat.CFrame.RightVector
        right = Vector3.new(right.X, 0, right.Z)

        if forward.Magnitude > 0 and right.Magnitude > 0 then
            forward = forward.Unit
            right = right.Unit

            local forwardSpeed = horizontal:Dot(forward)
            local lateralSpeed = horizontal:Dot(right)

            local desiredLateral =
                seat.Steer * math.clamp(speed * 0.28, 8, 55)

            local lateralBlend = math.clamp(dt * 2.5, 0, 1)
            local correctedLateral =
                lateralSpeed
                + (desiredLateral - lateralSpeed) * lateralBlend

            local corrected =
                forward * forwardSpeed + right * correctedLateral

            root.AssemblyLinearVelocity = Vector3.new(
                corrected.X,
                velocity.Y,
                corrected.Z
            )
        end
    end
end

--==============================================================
-- MAIN: FOV CONTROLS
--==============================================================

MainTab:CreateSection("Camera")

MainTab:CreateSlider({
    Name = "Camera Field of View",
    Range = {40, 120},
    Increment = 1,
    Suffix = " degrees",
    CurrentValue = Settings.CameraFOV,
    Callback = function(value)
        ApplyFOV(value)
    end,
})

MainTab:CreateButton({
    Name = "Reset Camera FOV",
    Callback = function()
        ApplyFOV(DefaultFOV)
    end,
})

--==============================================================
-- FLIGHT
--==============================================================

local function StopFlight()
    SafeDestroy(FlightVelocity)
    SafeDestroy(FlightGyro)

    FlightVelocity = nil
    FlightGyro = nil
end

local function StartFlight()
    StopFlight()

    local root = GetVehicleRoot(GetVehicleModel())

    if not root or root.Anchored then
        return
    end

    FlightVelocity = Instance.new("BodyVelocity")
    FlightVelocity.Name = "PrivateX_FlightVelocity"
    FlightVelocity.MaxForce = Vector3.new(1e7, 1e7, 1e7)
    FlightVelocity.P = 15000
    FlightVelocity.Velocity = Vector3.zero
    FlightVelocity.Parent = root

    FlightGyro = Instance.new("BodyGyro")
    FlightGyro.Name = "PrivateX_FlightGyro"
    FlightGyro.MaxTorque = Vector3.new(1e7, 1e7, 1e7)
    FlightGyro.P = 12000
    FlightGyro.CFrame = root.CFrame
    FlightGyro.Parent = root
end

local function UpdateFlight()
    if not Settings.Flight then
        return
    end

    local root = GetVehicleRoot(GetVehicleModel())

    if not root then
        StopFlight()
        return
    end

    if not FlightVelocity or FlightVelocity.Parent ~= root then
        StartFlight()
    end

    if not FlightVelocity or not FlightGyro then
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local move = Vector3.zero

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        move += camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        move -= camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        move -= camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        move += camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        move += Vector3.new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        move -= Vector3.new(0, 1, 0)
    end

    if move.Magnitude > 0 then
        move = move.Unit * math.min(Settings.MaxSpeed, 150)
    end

    FlightVelocity.Velocity = move
    FlightGyro.CFrame = camera.CFrame
end

VehicleTab:CreateToggle({
    Name = "Vehicle Flight (WASD / Space / Ctrl)",
    CurrentValue = false,
    Callback = function(value)
        Settings.Flight = value

        if value then
            StartFlight()
        else
            StopFlight()
        end
    end,
})

VehicleTab:CreateToggle({
    Name = "Drift Assist",
    CurrentValue = false,
    Callback = function(value)
        Settings.Drift = value
    end,
})

VehicleTab:CreateToggle({
    Name = "Handbrake",
    CurrentValue = false,
    Callback = function(value)
        Settings.Handbrake = value
    end,
})

VehicleTab:CreateButton({
    Name = "Flip Vehicle",
    Callback = function()
        local root = GetVehicleRoot(GetVehicleModel())

        if root then
            root.CFrame = root.CFrame * CFrame.Angles(math.pi, 0, 0)
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end,
})

VehicleTab:CreateButton({
    Name = "Stop Vehicle",
    Callback = function()
        for _, part in ipairs(GetVehicleParts(GetVehicleModel())) do
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end
    end,
})

--==============================================================
-- VEHICLE PAINT
--==============================================================

local Keywords = {
    Wheels = {
        "wheel", "rim", "tire", "tyre", "hubcap", "alloy",
        "brakedisc", "brake_disc",
    },
    Glass = {
        "glass", "window", "windshield", "windscreen", "sunroof",
    },
    Lights = {
        "light", "lamp", "headlight", "taillight", "indicator",
        "turnsignal", "foglight", "head_lamp",
    },
    Interior = {
        "interior", "dashboard", "dash", "seat", "steering",
        "console", "carpet", "upholstery", "doorpanel", "gearshift",
    },
    Trim = {
        "trim", "grille", "grill", "bumper", "mirror", "handle",
        "exhaust", "spoiler", "badge", "logo", "molding", "moulding",
    },
}

local function ContainsKeyword(text, words)
    for _, word in ipairs(words) do
        if string.find(text, word, 1, true) then
            return true
        end
    end

    return false
end

local function GetPartContext(part, model)
    local names = {}
    local current = part

    while current do
        table.insert(names, string.lower(current.Name))

        if current == model then
            break
        end

        current = current.Parent
    end

    return table.concat(names, " ")
end

local function CategorizePart(part, model)
    local context = GetPartContext(part, model)

    for _, category in ipairs({
        "Wheels", "Glass", "Lights", "Interior", "Trim",
    }) do
        if ContainsKeyword(context, Keywords[category]) then
            return category
        end
    end

    if part.Material == Enum.Material.Glass
        or part.Transparency >= 0.35 then
        return "Glass"
    end

    return "Body"
end

local function SaveOriginal(part)
    if OriginalProperties[part] then
        return
    end

    OriginalProperties[part] = {
        Color = part.Color,
        Material = part.Material,
        Transparency = part.Transparency,
        Reflectance = part.Reflectance,
    }
end

local function ApplyColorToCategory(category, color)
    local model = GetVehicleModel()

    if not model then
        Notify("Private X | Paint", "Sit in your vehicle before painting it.")
        return
    end

    local changed = 0

    for _, part in ipairs(GetVehicleParts(model)) do
        if category == "All"
            or CategorizePart(part, model) == category then
            SaveOriginal(part)

            if pcall(function()
                part.Color = color
            end) then
                changed += 1
            end
        end
    end

    Notify("Private X | Paint", "Processed " .. changed .. " parts.")
end

local function RestoreVehicleColors()
    for part, properties in pairs(OriginalProperties) do
        if part and part.Parent then
            pcall(function()
                part.Color = properties.Color
                part.Material = properties.Material
                part.Transparency = properties.Transparency
                part.Reflectance = properties.Reflectance
            end)
        end
    end

    table.clear(OriginalProperties)
end

local function AddPaintPicker(name, category)
    PaintTab:CreateColorPicker({
        Name = name,
        Color = PaintColors[category],
        Callback = function(color)
            PaintColors[category] = color
            ApplyColorToCategory(category, color)
        end,
    })
end

AddPaintPicker("Body Color", "Body")
AddPaintPicker("Wheels / Rims Color", "Wheels")
AddPaintPicker("Glass Color", "Glass")
AddPaintPicker("Lights Color", "Lights")
AddPaintPicker("Interior Color", "Interior")
AddPaintPicker("Trim Color", "Trim")
AddPaintPicker("All Vehicle Parts", "All")

PaintTab:CreateButton({
    Name = "Restore Original Colors",
    Callback = RestoreVehicleColors,
})

--==============================================================
-- UNDERGLOW + RAINBOW MODE
--==============================================================

local function RemoveUnderglow()
    for _, object in ipairs(UnderglowObjects) do
        SafeDestroy(object)
    end

    table.clear(UnderglowObjects)
    CurrentUnderglowVehicle = nil
end

local function BuildUnderglow()
    if Unloaded then
        return
    end

    local model = GetVehicleModel()

    if not Settings.Underglow or not model then
        RemoveUnderglow()
        return
    end

    if CurrentUnderglowVehicle == model
        and #UnderglowObjects > 0 then
        local valid = true

        for _, light in ipairs(UnderglowObjects) do
            if not light or not light.Parent then
                valid = false
                break
            end
        end

        if valid then
            return
        end

        RemoveUnderglow()
    end

    RemoveUnderglow()
    CurrentUnderglowVehicle = model

    local parts = GetVehicleParts(model)

    table.sort(parts, function(a, b)
        return a.Position.Y < b.Position.Y
    end)

    if #parts == 0 then
        return
    end

    -- Pick parts spread across the bottom of the vehicle.
    local count = math.min(4, #parts)

    for index = 1, count do
        local partIndex = math.floor(
            1 + ((index - 1) * (#parts - 1) / math.max(1, count - 1))
        )

        local part = parts[partIndex]

        local light = Instance.new("PointLight")
        light.Name = "PrivateX_Underglow"
        light.Color = Settings.UnderglowColor
        light.Brightness = Settings.UnderglowBrightness
        light.Range = Settings.UnderglowRange
        light.Shadows = false
        light.Parent = part

        table.insert(UnderglowObjects, light)
    end
end

local function UpdateUnderglow()
    if not Settings.Underglow then
        return
    end

    if Settings.RainbowUnderglow then
        local hue = (os.clock() * Settings.RainbowSpeed) % 1
        Settings.UnderglowColor = Color3.fromHSV(hue, 1, 1)
    end

    for _, light in ipairs(UnderglowObjects) do
        if light and light.Parent then
            light.Color = Settings.UnderglowColor
            light.Brightness = Settings.UnderglowBrightness
            light.Range = Settings.UnderglowRange
        end
    end
end

VehicleTab:CreateToggle({
    Name = "Underglow",
    CurrentValue = false,
    Callback = function(value)
        Settings.Underglow = value

        if value then
            BuildUnderglow()
        else
            RemoveUnderglow()
        end
    end,
})

VehicleTab:CreateColorPicker({
    Name = "Underglow Color",
    Color = Settings.UnderglowColor,
    Callback = function(color)
        Settings.UnderglowColor = color
        Settings.RainbowUnderglow = false
    end,
})

VehicleTab:CreateToggle({
    Name = "Rainbow Underglow",
    CurrentValue = false,
    Callback = function(value)
        Settings.RainbowUnderglow = value
    end,
})

VehicleTab:CreateSlider({
    Name = "Rainbow Speed",
    Range = {0.1, 3},
    Increment = 0.1,
    CurrentValue = Settings.RainbowSpeed,
    Callback = function(value)
        Settings.RainbowSpeed = value
    end,
})

VehicleTab:CreateSlider({
    Name = "Underglow Brightness",
    Range = {0, 10},
    Increment = 0.5,
    CurrentValue = Settings.UnderglowBrightness,
    Callback = function(value)
        Settings.UnderglowBrightness = value
        UpdateUnderglow()
    end,
})

VehicleTab:CreateSlider({
    Name = "Underglow Range",
    Range = {4, 40},
    Increment = 2,
    CurrentValue = Settings.UnderglowRange,
    Callback = function(value)
        Settings.UnderglowRange = value
        UpdateUnderglow()
    end,
})

--==============================================================
-- ENGINE SOUND PRESETS
-- Presets use Roblox audio assets; availability can vary by game.
--==============================================================

local EnginePresets = {
    Standard = {
        SoundId = "rbxassetid://9120386436",
        Pitch = 1.0,
    },
    Sport = {
        SoundId = "rbxassetid://9120386436",
        Pitch = 1.2,
    },
    Muscle = {
        SoundId = "rbxassetid://9120386436",
        Pitch = 0.85,
    },
    Electric = {
        SoundId = "rbxassetid://9120386436",
        Pitch = 1.5,
    },
}

local function StopEngineSound()
    if EngineSoundObject then
        pcall(function()
            EngineSoundObject:Stop()
        end)

        SafeDestroy(EngineSoundObject)
        EngineSoundObject = nil
    end
end

local function UpdateEngineSound()
    local root = GetVehicleRoot(GetVehicleModel())

    if not Settings.EngineSound or not root then
        StopEngineSound()
        return
    end

    if not EngineSoundObject or EngineSoundObject.Parent ~= root then
        StopEngineSound()

        EngineSoundObject = Instance.new("Sound")
        EngineSoundObject.Name = "PrivateX_EngineSound"
        EngineSoundObject.SoundId = Settings.EngineSoundId
        EngineSoundObject.Looped = true
        EngineSoundObject.Volume = Settings.EngineVolume
        EngineSoundObject.RollOffMaxDistance = 120
        EngineSoundObject.Parent = root

        pcall(function()
            EngineSoundObject:Play()
        end)
    end

    if EngineSoundObject then
        local preset = EnginePresets[Settings.EnginePreset]
            or EnginePresets.Standard

        local speed = root.AssemblyLinearVelocity.Magnitude

        EngineSoundObject.Volume = Settings.EngineVolume
        EngineSoundObject.PlaybackSpeed = math.clamp(
            preset.Pitch * (0.7 + speed / 150),
            0.5,
            2.5
        )

        if not EngineSoundObject.IsPlaying then
            pcall(function()
                EngineSoundObject:Play()
            end)
        end
    end
end

local function SetEnginePreset(presetName)
    local preset = EnginePresets[presetName]

    if not preset then
        return
    end

    Settings.EnginePreset = presetName
    Settings.EngineSoundId = preset.SoundId

    if Settings.EngineSound then
        StopEngineSound()
        UpdateEngineSound()
    end
end

VehicleTab:CreateToggle({
    Name = "Engine Sound",
    CurrentValue = false,
    Callback = function(value)
        Settings.EngineSound = value

        if value then
            UpdateEngineSound()
        else
            StopEngineSound()
        end
    end,
})

VehicleTab:CreateDropdown({
    Name = "Engine Sound Preset",
    Options = {"Standard", "Sport", "Muscle", "Electric"},
    CurrentOption = {"Standard"},
    MultipleOptions = false,
    Callback = function(option)
        local selected = option

        if typeof(option) == "table" then
            selected = option[1]
        end

        SetEnginePreset(selected)
    end,
})

VehicleTab:CreateInput({
    Name = "Custom Engine Sound ID (Optional)",
    PlaceholderText = "Enter audio asset ID",
    RemoveTextAfterFocusLost = false,
    Callback = function(value)
        if not value or value == "" then
            return
        end

        if string.match(value, "^%d+$") then
            Settings.EngineSoundId = "rbxassetid://" .. value
        else
            Settings.EngineSoundId = value
        end

        if Settings.EngineSound then
            StopEngineSound()
            UpdateEngineSound()
        end
    end,
})

VehicleTab:CreateSlider({
    Name = "Engine Volume",
    Range = {0, 10},
    Increment = 0.5,
    CurrentValue = Settings.EngineVolume,
    Callback = function(value)
        Settings.EngineVolume = value

        if EngineSoundObject then
            EngineSoundObject.Volume = value
        end
    end,
})

--==============================================================
-- ESP
--==============================================================

local function RemoveESP(player)
    local entry = ESPObjects[player]

    if not entry then
        return
    end

    SafeDestroy(entry.Box)
    SafeDestroy(entry.Billboard)

    ESPObjects[player] = nil
end

local function CreateESP(player)
    if player == LocalPlayer or ESPObjects[player] then
        return
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root then
        return
    end

    local box

    if Settings.ESPShowBoxes then
        box = Instance.new("BoxHandleAdornment")
        box.Name = "PrivateX_ESPBox"
        box.Adornee = root
        box.Size = Vector3.new(2.5, 3.5, 1.5)
        box.Color3 = Settings.ESPColor
        box.Transparency = 0.35
        box.AlwaysOnTop = true
        box.ZIndex = 5
        box.Parent = root
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PrivateX_ESPLabel"
    billboard.Adornee = root
    billboard.Size = UDim2.new(0, 220, 0, 48)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = root

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "PlayerName"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0, 24)
    nameLabel.Font = Settings.ESPFont
    nameLabel.Text = player.DisplayName
    nameLabel.TextColor3 = Settings.ESPColor
    nameLabel.TextSize = 14
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Parent = billboard

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "PlayerInfo"
    infoLabel.BackgroundTransparency = 1
    infoLabel.Position = UDim2.new(0, 0, 0, 23)
    infoLabel.Size = UDim2.new(1, 0, 0, 20)
    infoLabel.Font = Enum.Font.Code
    infoLabel.Text = ""
    infoLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    infoLabel.TextSize = 12
    infoLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    infoLabel.TextStrokeTransparency = 0
    infoLabel.Parent = billboard

    ESPObjects[player] = {
        Box = box,
        Billboard = billboard,
        NameLabel = nameLabel,
        InfoLabel = infoLabel,
    }
end

local function RefreshESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then
            continue
        end

        local character = GetCharacter()
        local myRoot = character
            and character:FindFirstChild("HumanoidRootPart")

        local targetCharacter = player.Character
        local root = targetCharacter
            and targetCharacter:FindFirstChild("HumanoidRootPart")
        local humanoid = targetCharacter
            and targetCharacter:FindFirstChildOfClass("Humanoid")

        if not Settings.ESP or not myRoot or not root
            or not humanoid or humanoid.Health <= 0 then
            RemoveESP(player)
            continue
        end

        local distanceStuds = (myRoot.Position - root.Position).Magnitude

        if not Settings.ESPUnlimitedRange
            and distanceStuds > Settings.ESPDistance then
            RemoveESP(player)
            continue
        end

        local entry = ESPObjects[player]

        if not entry or not entry.Billboard
            or not entry.Billboard.Parent then
            RemoveESP(player)
            CreateESP(player)
            entry = ESPObjects[player]
        end

        if not entry then
            continue
        end

        if Settings.ESPShowBoxes and not entry.Box then
            entry.Box = Instance.new("BoxHandleAdornment")
            entry.Box.Name = "PrivateX_ESPBox"
            entry.Box.Size = Vector3.new(2.5, 3.5, 1.5)
            entry.Box.Transparency = 0.35
            entry.Box.AlwaysOnTop = true
            entry.Box.ZIndex = 5
            entry.Box.Parent = root
        elseif not Settings.ESPShowBoxes and entry.Box then
            SafeDestroy(entry.Box)
            entry.Box = nil
        end

        if entry.Box then
            entry.Box.Adornee = root
            entry.Box.Color3 = Settings.ESPColor
        end

        entry.Billboard.Adornee = root
        entry.NameLabel.Text = player.DisplayName
        entry.NameLabel.Font = Settings.ESPFont
        entry.NameLabel.TextColor3 = Settings.ESPColor

        local info = {}

        if Settings.ESPShowHealth then
            table.insert(info, "HP: " .. math.floor(humanoid.Health))
        end

        if Settings.ESPShowDistance then
            table.insert(info, string.format("%.2f km", ToKm(distanceStuds)))
        end

        entry.InfoLabel.Text = table.concat(info, " | ")
    end
end

ESPTab:CreateToggle({
    Name = "Player ESP",
    CurrentValue = false,
    Callback = function(value)
        Settings.ESP = value

        if not value then
            for player in pairs(ESPObjects) do
                RemoveESP(player)
            end
        end
    end,
})

ESPTab:CreateToggle({
    Name = "Unlimited ESP Range",
    CurrentValue = true,
    Callback = function(value)
        Settings.ESPUnlimitedRange = value
    end,
})

ESPTab:CreateColorPicker({
    Name = "ESP Color",
    Color = Settings.ESPColor,
    Callback = function(color)
        Settings.ESPColor = color
    end,
})

ESPTab:CreateDropdown({
    Name = "ESP Font",
    Options = {
        "GothamBlack", "GothamBold", "SciFi", "Code",
        "Arcade", "Fantasy", "Antique", "SourceSansBold",
    },
    CurrentOption = {"GothamBlack"},
    MultipleOptions = false,
    Callback = function(option)
        local selected = option

        if typeof(option) == "table" then
            selected = option[1]
        end

        local fonts = {
            GothamBlack = Enum.Font.GothamBlack,
            GothamBold = Enum.Font.GothamBold,
            SciFi = Enum.Font.SciFi,
            Code = Enum.Font.Code,
            Arcade = Enum.Font.Arcade,
            Fantasy = Enum.Font.Fantasy,
            Antique = Enum.Font.Antique,
            SourceSansBold = Enum.Font.SourceSansBold,
        }

        Settings.ESPFont = fonts[selected] or Enum.Font.GothamBlack
    end,
})

ESPTab:CreateSlider({
    Name = "ESP Maximum Distance",
    Range = {100, 50000},
    Increment = 100,
    Suffix = " studs",
    CurrentValue = Settings.ESPDistance,
    Callback = function(value)
        Settings.ESPDistance = value
    end,
})

ESPTab:CreateToggle({
    Name = "Show Health",
    CurrentValue = true,
    Callback = function(value)
        Settings.ESPShowHealth = value
    end,
})

ESPTab:CreateToggle({
    Name = "Show Distance (km)",
    CurrentValue = true,
    Callback = function(value)
        Settings.ESPShowDistance = value
    end,
})

ESPTab:CreateToggle({
    Name = "Show ESP Boxes",
    CurrentValue = true,
    Callback = function(value)
        Settings.ESPShowBoxes = value
    end,
})

--==============================================================
-- MAIN: SPEEDOMETER / EXTRA CONTROLS
--==============================================================

MainTab:CreateSection("Speedometer")

local VehicleLabel = MainTab:CreateLabel("Vehicle: Not detected")
local SpeedLabel = MainTab:CreateLabel("Speed: 0 km/h")
local SessionDistanceLabel = MainTab:CreateLabel("Session distance: 0.00 km")
local MaxSpeedLabel = MainTab:CreateLabel("Configured speed cap: 302 km/h")

local function UpdateDiagnostics()
    local model = GetVehicleModel()
    local root = GetVehicleRoot(model)

    if not model or not root then
        VehicleLabel:Set("Vehicle: Not detected")
        SpeedLabel:Set("Speed: 0 km/h")
        MaxSpeedLabel:Set(
            "Configured speed cap: " .. ToKmh(Settings.MaxSpeed) .. " km/h"
        )
        SessionDistanceLabel:Set(
            string.format("Session distance: %.2f km", DistanceTravelled)
        )

        LastVehicle = nil
        LastPosition = nil
        return
    end

    local speed = root.AssemblyLinearVelocity.Magnitude

    VehicleLabel:Set("Vehicle: " .. model.Name)
    SpeedLabel:Set("Speed: " .. ToKmh(speed) .. " km/h")
    MaxSpeedLabel:Set(
        "Configured speed cap: " .. ToKmh(Settings.MaxSpeed) .. " km/h"
    )

    if LastVehicle == model and LastPosition then
        DistanceTravelled += ToKm((root.Position - LastPosition).Magnitude)
    end

    LastVehicle = model
    LastPosition = root.Position

    SessionDistanceLabel:Set(
        string.format("Session distance: %.2f km", DistanceTravelled)
    )
end

MainTab:CreateSection("Utilities")

MainTab:CreateButton({
    Name = "Refresh Vehicle Detection",
    Callback = function()
        local model = GetVehicleModel()

        if not model then
            Notify("Private X", "Sit in a vehicle seat first.")
            return
        end

        if Settings.Underglow then
            RemoveUnderglow()
            BuildUnderglow()
        end

        Notify("Vehicle Detected", model.Name)
    end,
})

MainTab:CreateButton({
    Name = "Restore Vehicle Colors",
    Callback = RestoreVehicleColors,
})

MainTab:CreateToggle({
    Name = "Odometer Boost (+1,000,000 / 5 sec)",
    CurrentValue = false,
    Callback = function(value)
        Settings.OdometerBoost = value
        odometerTimer = 0
    end,
})

-- Adds one million to the local leaderstats odometer every five seconds.
-- The server may overwrite or reject client-side value changes.
local function UpdateOdometer()
    if not Settings.OdometerBoost then
        return
    end

    local stats = LocalPlayer:FindFirstChild("leaderstats")
    if not stats then
        return
    end

    local odometer = stats:FindFirstChild("Odometer")
        or stats:FindFirstChild("odometer")

    if odometer and (
        odometer:IsA("NumberValue")
        or odometer:IsA("IntValue")
    ) then
        pcall(function()
            odometer.Value = odometer.Value + 1000000
        end)
    end
end

--==============================================================
-- UNLOAD PRIVATE X
--==============================================================

local function UnloadPrivateX()
    if Unloaded then
        return
    end

    Unloaded = true

    Settings.Flight = false
    Settings.ESP = false
    Settings.Underglow = false
    Settings.EngineSound = false
    Settings.Drift = false
    Settings.Handbrake = false
    Settings.OdometerBoost = false

    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(Connections)

    StopFlight()
    StopEngineSound()
    RemoveUnderglow()

    for player in pairs(ESPObjects) do
        RemoveESP(player)
    end

    RestoreVehicleColors()

    local camera = Workspace.CurrentCamera
    if camera then
        camera.FieldOfView = DefaultFOV
    end

    for _, object in ipairs(CreatedObjects) do
        SafeDestroy(object)
    end
    table.clear(CreatedObjects)

    pcall(function()
        Rayfield:Destroy()
    end)

    -- Fallback for Rayfield versions using Unload instead of Destroy.
    pcall(function()
        Rayfield:Unload()
    end)
end

MainTab:CreateButton({
    Name = "Unload Private X",
    Callback = UnloadPrivateX,
}) --==============================================================
-- EXTRAS TAB
--==============================================================

ExtraTab:CreateSection("Script Controls")

ExtraTab:CreateButton({
    Name = "Unload Private X",
    Callback = function()
        UnloadPrivateX()
    end,
})

ExtraTab:CreateSection("Camera")

ExtraTab:CreateButton({
    Name = "Reset Camera FOV",
    Callback = function()
        ApplyFOV(DefaultFOV)
        Notify("Private X", "Camera FOV reset.")
    end,
})

ExtraTab:CreateSection("Vehicle Utilities")

ExtraTab:CreateButton({
    Name = "Refresh Vehicle Detection",
    Callback = function()
        local model = GetVehicleModel()

        if model then
            Notify("Private X", "Vehicle detected: " .. model.Name)
        else
            Notify("Private X", "No vehicle detected. Sit in the driver's seat first.")
        end
    end,
})

ExtraTab:CreateParagraph({
    Title = "Private X",
    Content = "Use Unload Private X to stop the script and clean up its objects.",
})

--==============================================================
-- READY
--==============================================================

Rayfield:Notify({
    Title = "Private X",
    Content = "Loaded! Check the Extras tab for unload and utility controls.",
    Duration = 5,
})

--==============================================================
-- UPDATE LOOP
--==============================================================

TrackConnection(RunService.Heartbeat:Connect(function(dt)
    if Unloaded then
        return
    end

    pcall(ApplyVehiclePhysics, dt)
    pcall(UpdateFlight)

    if Settings.Underglow then
        pcall(BuildUnderglow)
        pcall(UpdateUnderglow)
    end

    if Settings.EngineSound then
        pcall(UpdateEngineSound)
    end

    if Settings.ESP then
        pcall(RefreshESP)
    end

    diagnosticsTimer += dt

    if diagnosticsTimer >= 0.25 then
        diagnosticsTimer = 0
        pcall(UpdateDiagnostics)
    end

    if Settings.OdometerBoost then
        odometerTimer += dt

        if odometerTimer >= 5 then
            odometerTimer %= 5
            pcall(UpdateOdometer)
        end
    else
        odometerTimer = 0
    end
end))

TrackConnection(Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
end))

TrackConnection(LocalPlayer.CharacterRemoving:Connect(function()
    StopFlight()
    StopEngineSound()
    RemoveUnderglow()
end))

TrackConnection(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)

    if Unloaded then
        return
    end

    if Settings.Flight then
        StartFlight()
    end
end))

--==============================================================
-- READY
--==============================================================

Rayfield:Notify({
    Title = "Private X",
    Content = "Loaded! Speedometer and utilities are on Main.",
    Duration = 5,
})S