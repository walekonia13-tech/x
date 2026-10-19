--==============================================================
-- PRIVATE X | COMPLETE VEHICLE CONTROL SUITE
-- Consolidated version | Main menu extras | Improved cleanup
--==============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

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
local Rayfield
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

Rayfield = loadstring(game:HttpGet(
    "https://sirius.menu/rayfield"
))()

local Window = Rayfield:CreateWindow({
    Name = "PRIVATE X | CONTROL DECK",
    LoadingTitle = "PRIVATE X",
    LoadingSubtitle = "Vehicle • World • Weather",
    ConfigurationSaving = {
        Enabled = false,
    },
    KeySystem = false,
    Theme = "Ocean",
})

local MainTab = Window:CreateTab("Main", 4483362458)
local VehicleTab = Window:CreateTab("Vehicle", 4483362458)
local AppearanceTab = Window:CreateTab("Appearance", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)
local ExtraTab = Window:CreateTab("Extras", 4483362458)
local WorldTab = Window:CreateTab("World Settings", 4483362458)
local WeatherTab = Window:CreateTab("Weather", 4483362458)

--==============================================================
-- WORLD SETTINGS (LOCAL VISUALS)
--==============================================================

local OriginalLighting = {
    ClockTime = Lighting.ClockTime,
    Brightness = Lighting.Brightness,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ColorShift_Top = Lighting.ColorShift_Top,
    ColorShift_Bottom = Lighting.ColorShift_Bottom,
    FogColor = Lighting.FogColor,
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
    ExposureCompensation = Lighting.ExposureCompensation,
    GlobalShadows = Lighting.GlobalShadows,
    EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
    EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    ShadowSoftness = Lighting.ShadowSoftness,
    GeographicLatitude = Lighting.GeographicLatitude,
}
local WorldAtmosphere
local WeatherGui
local WeatherFrames = {}
local WeatherMode = "Off"
local WeatherRng = Random.new()
local WeatherAmbienceEnabled = true
local WeatherAmbienceVolume = 0.35
local WeatherSoundObject
local WeatherSoundIds = {
    Rain = "rbxassetid://1843529636",
    Snow = "rbxassetid://9112854440",
    Blizzard = "rbxassetid://9112854440",
}
local TimeOverrideEnabled = false
local SelectedClockTime = Lighting.ClockTime
local PostEffects = {}
local MotionBlurSettings = {Enabled = false, Intensity = 12, Sensitivity = 1.2}
local MotionBlurEffect
local LastMotionBlurCameraCFrame
local PostSettings = {
    Bloom = false, BloomIntensity = 0.35, BloomSize = 24, BloomThreshold = 1,
    ColorCorrection = false, Saturation = 0, Contrast = 0, PostBrightness = 0,
    TintColor = Color3.fromRGB(255, 255, 255),
    SunRays = false, SunRayIntensity = 0.1, SunRaySpread = 0.8,
    DepthOfField = false, FocusDistance = 50, InFocusRadius = 30,
    AtmosphereEnabled = false,
}
local WeatherSettings = {
    Intensity = 1, Speed = 1, WindAngle = 15, WindStrength = 0.15,
    ParticleColor = Color3.fromRGB(220, 235, 255), SnowColor = Color3.fromRGB(255, 255, 255),
}

local function RestoreWorldLighting()
    TimeOverrideEnabled = false
    pcall(function()
        for property, value in pairs(OriginalLighting) do
            Lighting[property] = value
        end
    end)
    if WorldAtmosphere then
        SafeDestroy(WorldAtmosphere)
        WorldAtmosphere = nil
    end
end

local function EnsureWorldAtmosphere()
    if WorldAtmosphere and WorldAtmosphere.Parent then
        return WorldAtmosphere
    end
    WorldAtmosphere = Instance.new("Atmosphere")
    WorldAtmosphere.Name = "PrivateX_WorldAtmosphere"
    WorldAtmosphere.Density = 0.25
    WorldAtmosphere.Offset = 0.1
    WorldAtmosphere.Color = Color3.fromRGB(199, 208, 220)
    WorldAtmosphere.Decay = Color3.fromRGB(106, 118, 138)
    WorldAtmosphere.Glare = 0
    WorldAtmosphere.Haze = 1.2
    WorldAtmosphere.Parent = Lighting
    table.insert(CreatedObjects, WorldAtmosphere)
    return WorldAtmosphere
end

local WorldPresets = {
    ["Original"] = {
        ClockTime = OriginalLighting.ClockTime, Brightness = OriginalLighting.Brightness,
        Ambient = OriginalLighting.Ambient, OutdoorAmbient = OriginalLighting.OutdoorAmbient,
        FogColor = OriginalLighting.FogColor, FogStart = OriginalLighting.FogStart,
        FogEnd = OriginalLighting.FogEnd, ExposureCompensation = OriginalLighting.ExposureCompensation,
    },
    ["Grey Noon"] = {
        ClockTime = 12, Brightness = 1.8,
        Ambient = Color3.fromRGB(125, 128, 135), OutdoorAmbient = Color3.fromRGB(155, 158, 165),
        FogColor = Color3.fromRGB(175, 180, 188), FogStart = 0, FogEnd = 1200,
        ExposureCompensation = -0.05,
    },
    ["Cozy Overcast"] = {
        ClockTime = 15.5, Brightness = 1.6,
        Ambient = Color3.fromRGB(145, 128, 119), OutdoorAmbient = Color3.fromRGB(170, 155, 143),
        FogColor = Color3.fromRGB(202, 190, 177), FogStart = 0, FogEnd = 1800,
        ExposureCompensation = 0.05,
    },
    ["Warm Sunset"] = {
        ClockTime = 17.7, Brightness = 2,
        Ambient = Color3.fromRGB(170, 119, 93), OutdoorAmbient = Color3.fromRGB(210, 155, 115),
        FogColor = Color3.fromRGB(238, 177, 139), FogStart = 0, FogEnd = 2000,
        ExposureCompensation = 0.1,
    },
    ["Blue Hour"] = {
        ClockTime = 19.2, Brightness = 1.1,
        Ambient = Color3.fromRGB(70, 83, 125), OutdoorAmbient = Color3.fromRGB(95, 110, 155),
        FogColor = Color3.fromRGB(65, 80, 120), FogStart = 0, FogEnd = 1600,
        ExposureCompensation = -0.1,
    },
    ["Soft Morning"] = {
        ClockTime = 8.1, Brightness = 2,
        Ambient = Color3.fromRGB(160, 157, 145), OutdoorAmbient = Color3.fromRGB(195, 190, 172),
        FogColor = Color3.fromRGB(218, 216, 204), FogStart = 0, FogEnd = 2200,
        ExposureCompensation = 0.05,
    },
    ["Midnight"] = {
        ClockTime = 0.2, Brightness = 0.7,
        Ambient = Color3.fromRGB(35, 42, 68), OutdoorAmbient = Color3.fromRGB(48, 56, 86),
        FogColor = Color3.fromRGB(24, 31, 51), FogStart = 0, FogEnd = 900,
        ExposureCompensation = -0.25,
    },
    ["Dreamy Lavender"] = {
        ClockTime = 18.5, Brightness = 1.5,
        Ambient = Color3.fromRGB(135, 113, 161), OutdoorAmbient = Color3.fromRGB(166, 145, 190),
        FogColor = Color3.fromRGB(185, 170, 207), FogStart = 0, FogEnd = 1700,
        ExposureCompensation = 0.05,
    },
    ["Forest Mist"] = {
        ClockTime = 10.5, Brightness = 1.4,
        Ambient = Color3.fromRGB(94, 125, 103), OutdoorAmbient = Color3.fromRGB(128, 158, 132),
        FogColor = Color3.fromRGB(135, 163, 143), FogStart = 0, FogEnd = 700,
        ExposureCompensation = -0.05,
    },
    ["Cinematic Night"] = {
        ClockTime = 22, Brightness = 0.9,
        Ambient = Color3.fromRGB(48, 52, 68), OutdoorAmbient = Color3.fromRGB(65, 70, 90),
        FogColor = Color3.fromRGB(50, 56, 73), FogStart = 0, FogEnd = 1300,
        ExposureCompensation = -0.15,
    },
}

local function ApplyWorldPreset(name)
    local preset = WorldPresets[name]
    if not preset or Unloaded then return end
    if name == "Original" then
        RestoreWorldLighting()
        return
    end
    pcall(function()
        for property, value in pairs(preset) do
            Lighting[property] = value
        end
        SelectedClockTime = preset.ClockTime or Lighting.ClockTime
        TimeOverrideEnabled = true
        Lighting.GlobalShadows = true
    end)

    local atmosphere = EnsureWorldAtmosphere()
    if name == "Grey Noon" then
        atmosphere.Density, atmosphere.Haze = 0.28, 1.4
        atmosphere.Color, atmosphere.Decay = Color3.fromRGB(195, 199, 205), Color3.fromRGB(130, 136, 145)
    elseif name == "Cozy Overcast" then
        atmosphere.Density, atmosphere.Haze = 0.22, 1.1
        atmosphere.Color, atmosphere.Decay = Color3.fromRGB(255, 224, 198), Color3.fromRGB(165, 147, 133)
    elseif name == "Warm Sunset" then
        atmosphere.Density, atmosphere.Haze = 0.18, 0.8
        atmosphere.Color, atmosphere.Decay = Color3.fromRGB(255, 202, 161), Color3.fromRGB(180, 117, 93)
    elseif name == "Blue Hour" or name == "Cinematic Night" or name == "Midnight" then
        atmosphere.Density, atmosphere.Haze = 0.3, 1.5
        atmosphere.Color, atmosphere.Decay = Color3.fromRGB(139, 157, 210), Color3.fromRGB(65, 76, 120)
    elseif name == "Dreamy Lavender" then
        atmosphere.Density, atmosphere.Haze = 0.24, 1.3
        atmosphere.Color, atmosphere.Decay = Color3.fromRGB(210, 192, 255), Color3.fromRGB(123, 104, 164)
    elseif name == "Forest Mist" then
        atmosphere.Density, atmosphere.Haze = 0.38, 2
        atmosphere.Color, atmosphere.Decay = Color3.fromRGB(190, 220, 194), Color3.fromRGB(93, 125, 101)
    elseif name == "Soft Morning" then
        atmosphere.Density, atmosphere.Haze = 0.12, 0.5
        atmosphere.Color, atmosphere.Decay = Color3.fromRGB(255, 239, 210), Color3.fromRGB(190, 183, 158)
    else
        atmosphere.Density, atmosphere.Haze = 0.2, 0.8
        atmosphere.Color, atmosphere.Decay = Color3.fromRGB(199, 208, 220), Color3.fromRGB(106, 118, 138)
    end
end

local function StopWeatherAmbience()
    if WeatherSoundObject then
        pcall(function()
            WeatherSoundObject:Stop()
            WeatherSoundObject:Destroy()
        end)
        WeatherSoundObject = nil
    end
end

local function StartWeatherAmbience(mode)
    StopWeatherAmbience()
    if not WeatherAmbienceEnabled or mode == "Off" or Unloaded then return end
    local soundId = WeatherSoundIds[mode]
    if not soundId or soundId == "" then return end
    local sound = Instance.new("Sound")
    sound.Name = "PrivateX_WeatherAmbience"
    sound.SoundId = soundId
    sound.Volume = math.clamp(WeatherAmbienceVolume, 0, 1)
    sound.Looped = true
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.Parent = SoundService
    WeatherSoundObject = sound
    table.insert(CreatedObjects, sound)
    local ok = pcall(function() sound:Play() end)
    if not ok then
        StopWeatherAmbience()
        Notify("Weather Ambience", "Could not play this audio. Try a permitted Roblox audio asset ID.")
    end
end

local function StopScreenWeather()
    WeatherMode = "Off"
    StopWeatherAmbience()
    if WeatherGui then SafeDestroy(WeatherGui); WeatherGui = nil end
    table.clear(WeatherFrames)
end

local function AddWeatherParticle(gui, mode, layer)
    local obj = Instance.new("Frame")
    obj.Name = mode == "Rain" and "RainStreak" or "Snowflake"
    obj.AnchorPoint = Vector2.new(0.5, 0.5)
    obj.BorderSizePixel = 0
    obj.ZIndex = layer or 10
    obj.BackgroundColor3 = mode == "Rain" and WeatherSettings.ParticleColor or WeatherSettings.SnowColor
    obj.BackgroundTransparency = mode == "Rain" and WeatherRng:NextNumber(0.22, 0.48) or WeatherRng:NextNumber(0.12, 0.35)
    local width, height, speed, drift
    if mode == "Rain" then
        local nearLayer = layer == 12
        width = nearLayer and WeatherRng:NextInteger(2, 3) or 1
        height = nearLayer and WeatherRng:NextInteger(24, 46) or WeatherRng:NextInteger(12, 29)
        speed = (nearLayer and WeatherRng:NextNumber(1.0, 1.75) or WeatherRng:NextNumber(0.75, 1.45)) * WeatherSettings.Speed
        local wind = WeatherSettings.WindStrength
        drift = (nearLayer and WeatherRng:NextNumber(0.10, 0.22) or WeatherRng:NextNumber(0.045, 0.14)) + wind * math.cos(math.rad(WeatherSettings.WindAngle)) * 0.1
        obj.Size = UDim2.fromOffset(width, height)
        obj.Rotation = WeatherRng:NextInteger(8, 20)
    else
        width = WeatherRng:NextInteger(2, 6)
        height, speed = width, WeatherRng:NextNumber(0.07, 0.2) * WeatherSettings.Speed
        drift = WeatherRng:NextNumber(-0.045, 0.045) + WeatherSettings.WindStrength * math.cos(math.rad(WeatherSettings.WindAngle)) * 0.1
        obj.Size = UDim2.fromOffset(width, height)
        obj.BackgroundTransparency = WeatherRng:NextNumber(0.12, 0.3)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = obj
    end
    local x, y = WeatherRng:NextNumber(), WeatherRng:NextNumber()
    obj.Position = UDim2.fromScale(x, y)
    obj.Parent = gui
    table.insert(WeatherFrames, {Object = obj, X = x, Y = y, Speed = speed, Drift = drift})
end

local function StartScreenWeather(mode)
    StopScreenWeather()
    if Unloaded or mode == "Off" then return end
    WeatherMode = mode
    StartWeatherAmbience(mode)
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return end
    local gui = Instance.new("ScreenGui")
    gui.Name = "PrivateX_ScreenWeather"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 20
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui
    WeatherGui = gui
    table.insert(CreatedObjects, gui)

    if mode == "Rain" or mode == "Blizzard" then
        local wash = Instance.new("Frame")
        wash.Name = "RainCloudWash"
        wash.Size = UDim2.fromScale(1, 1)
        wash.BackgroundColor3 = Color3.fromRGB(105, 125, 150)
        wash.BackgroundTransparency = 0.91
        wash.BorderSizePixel = 0
        wash.ZIndex = 1
        wash.Parent = gui
        local gradient = Instance.new("UIGradient")
        gradient.Rotation = 90
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.08),
            NumberSequenceKeypoint.new(0.45, 0.65),
            NumberSequenceKeypoint.new(1, 1),
        })
        gradient.Parent = wash
        local intensity = math.clamp(WeatherSettings.Intensity, 0.25, 2)
        local baseCount = math.floor(230 * intensity)
        local nearCount = math.floor(85 * intensity)
        if mode == "Blizzard" then
            for i = 1, math.floor(140 * intensity) do AddWeatherParticle(gui, "Snow", 10) end
            for i = 1, math.floor(55 * intensity) do AddWeatherParticle(gui, "Snow", 12) end
        else
            for i = 1, baseCount do AddWeatherParticle(gui, "Rain", 10) end
            for i = 1, nearCount do AddWeatherParticle(gui, "Rain", 12) end
        end
        for i = 1, (mode == "Blizzard" and 0 or math.floor(24 * intensity)) do
            local size = WeatherRng:NextInteger(4, 11)
            local drop = Instance.new("Frame")
            drop.Name = "LensDroplet"
            drop.AnchorPoint = Vector2.new(0.5, 0.5)
            drop.Size = UDim2.fromOffset(size, size + WeatherRng:NextInteger(2, 8))
            drop.Position = UDim2.fromScale(WeatherRng:NextNumber(), WeatherRng:NextNumber())
            drop.BackgroundColor3 = Color3.fromRGB(220, 235, 250)
            drop.BackgroundTransparency = WeatherRng:NextNumber(0.68, 0.84)
            drop.BorderSizePixel = 0
            drop.ZIndex = 15
            drop.Parent = gui
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = drop
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(240, 247, 255)
            stroke.Thickness = 1
            stroke.Transparency = 0.55
            stroke.Parent = drop
        end
    else
        for i = 1, math.floor(100 * math.clamp(WeatherSettings.Intensity, 0.25, 2)) do AddWeatherParticle(gui, "Snow", 10) end
    end
end

local function UpdateScreenWeather(dt)
    if Unloaded or not WeatherGui or not WeatherGui.Parent then return end
    for _, particle in ipairs(WeatherFrames) do
        local object = particle.Object
        if object and object.Parent then
            particle.Y += particle.Speed * dt
            particle.X += particle.Drift * dt
            if particle.Y > 1.08 then particle.Y = -0.08; particle.X = WeatherRng:NextNumber() end
            if particle.X > 1.05 then particle.X = -0.05 end
            if particle.X < -0.05 then particle.X = 1.05 end
            object.Position = UDim2.fromScale(particle.X, particle.Y)
        end
    end
end

WorldTab:CreateSection("Atmosphere Presets")
WorldTab:CreateDropdown({
    Name = "World Preset",
    Options = {"Original", "Grey Noon", "Cozy Overcast", "Warm Sunset", "Blue Hour", "Soft Morning", "Midnight", "Dreamy Lavender", "Forest Mist", "Cinematic Night"},
    CurrentOption = {"Cozy Overcast"},
    MultipleOptions = false,
    Callback = function(option)
        local selected = typeof(option) == "table" and option[1] or option
        ApplyWorldPreset(selected)
    end,
})
WorldTab:CreateButton({
    Name = "Restore Original World",
    Callback = function()
        RestoreWorldLighting()
        Notify("World Settings", "Original lighting restored.")
    end,
})
WorldTab:CreateSection("Fine Tuning")
WorldTab:CreateSlider({
    Name = "Time of Day",
    Range = {0, 24},
    Increment = 0.25,
    Suffix = " hours",
    CurrentValue = Lighting.ClockTime,
    Callback = function(value)
        if Unloaded then return end
        SelectedClockTime = value % 24
        TimeOverrideEnabled = true
        pcall(function()
            Lighting.ClockTime = SelectedClockTime
            Lighting.TimeOfDay = string.format("%02d:%02d:00",
                math.floor(SelectedClockTime),
                math.floor((SelectedClockTime % 1) * 60))
        end)
    end,
})
WorldTab:CreateToggle({
    Name = "Lock Local Time",
    CurrentValue = true,
    Callback = function(value)
        TimeOverrideEnabled = value
        if value and not Unloaded then
            pcall(function() Lighting.ClockTime = SelectedClockTime end)
        end
    end,
})
WorldTab:CreateButton({
    Name = "Apply Time Now",
    Callback = function()
        SelectedClockTime = Lighting.ClockTime
        TimeOverrideEnabled = true
        Notify("World Settings", "Current local time locked.")
    end,
})
WorldTab:CreateSlider({
    Name = "Brightness",
    Range = {0, 5},
    Increment = 0.1,
    CurrentValue = Lighting.Brightness,
    Callback = function(value)
        if not Unloaded then Lighting.Brightness = value end
    end,
})
WorldTab:CreateSlider({
    Name = "Exposure Compensation",
    Range = {-3, 3},
    Increment = 0.1,
    CurrentValue = Lighting.ExposureCompensation,
    Callback = function(value)
        if not Unloaded then Lighting.ExposureCompensation = value end
    end,
})
WorldTab:CreateToggle({
    Name = "Global Shadows",
    CurrentValue = Lighting.GlobalShadows,
    Callback = function(value)
        if not Unloaded then Lighting.GlobalShadows = value end
    end,
})
WorldTab:CreateSlider({
    Name = "Environment Diffuse",
    Range = {0, 1},
    Increment = 0.05,
    CurrentValue = Lighting.EnvironmentDiffuseScale,
    Callback = function(value)
        if not Unloaded then Lighting.EnvironmentDiffuseScale = value end
    end,
})
WorldTab:CreateSlider({
    Name = "Environment Specular",
    Range = {0, 1},
    Increment = 0.05,
    CurrentValue = Lighting.EnvironmentSpecularScale,
    Callback = function(value)
        if not Unloaded then Lighting.EnvironmentSpecularScale = value end
    end,
})
WorldTab:CreateSlider({
    Name = "Shadow Softness",
    Range = {0, 1},
    Increment = 0.05,
    CurrentValue = Lighting.ShadowSoftness,
    Callback = function(value)
        if not Unloaded then Lighting.ShadowSoftness = value end
    end,
})
WorldTab:CreateSlider({
    Name = "Geographic Latitude",
    Range = {-90, 90},
    Increment = 1,
    CurrentValue = Lighting.GeographicLatitude,
    Callback = function(value)
        if not Unloaded then Lighting.GeographicLatitude = value end
    end,
})
WorldTab:CreateSlider({
    Name = "Atmosphere Density",
    Range = {0, 1},
    Increment = 0.01,
    CurrentValue = 0.25,
    Callback = function(value)
        if Unloaded then return end
        EnsureWorldAtmosphere().Density = value
    end,
})
WorldTab:CreateSlider({
    Name = "Atmosphere Haze",
    Range = {0, 10},
    Increment = 0.1,
    CurrentValue = 1.2,
    Callback = function(value)
        if Unloaded then return end
        EnsureWorldAtmosphere().Haze = value
    end,
})
WorldTab:CreateColorPicker({
    Name = "Top Color Shift",
    Color = Lighting.ColorShift_Top,
    Callback = function(color)
        if not Unloaded then Lighting.ColorShift_Top = color end
    end,
})
WorldTab:CreateColorPicker({
    Name = "Bottom Color Shift",
    Color = Lighting.ColorShift_Bottom,
    Callback = function(color)
        if not Unloaded then Lighting.ColorShift_Bottom = color end
    end,
})
WorldTab:CreateSlider({
    Name = "Fog Distance",
    Range = {100, 5000},
    Increment = 100,
    Suffix = " studs",
    CurrentValue = math.clamp(Lighting.FogEnd, 100, 5000),
    Callback = function(value)
        if Unloaded then return end
        -- Tune classic fog and Atmosphere together so the distance control is visible.
        Lighting.FogStart = math.max(0, value * 0.08)
        Lighting.FogEnd = value
        local atmosphere = EnsureWorldAtmosphere()
        local fogStrength = math.clamp(1 - (value / 5000), 0, 1)
        atmosphere.Density = 0.02 + fogStrength * 0.42
        atmosphere.Haze = 0.1 + fogStrength * 2.2
        atmosphere.Glare = 0
    end,
})
WorldTab:CreateColorPicker({
    Name = "Ambient Color",
    Color = Lighting.Ambient,
    Callback = function(color)
        if not Unloaded then
            Lighting.Ambient = color
            Lighting.OutdoorAmbient = color
        end
    end,
})
WorldTab:CreateColorPicker({
    Name = "Fog Color",
    Color = Lighting.FogColor,
    Callback = function(color)
        if Unloaded then return end
        Lighting.FogColor = color
        local atmosphere = EnsureWorldAtmosphere()
        atmosphere.Color = color
        atmosphere.Decay = color:Lerp(Color3.new(0, 0, 0), 0.35)
    end,
})
WorldTab:CreateColorPicker({
    Name = "Atmosphere Tint",
    Color = Color3.fromRGB(199, 208, 220),
    Callback = function(color)
        if Unloaded then return end
        local atmosphere = EnsureWorldAtmosphere()
        atmosphere.Color = color
        atmosphere.Decay = color:Lerp(Color3.new(0, 0, 0), 0.4)
    end,
})



--==============================================================
-- POST-PROCESSING CONTROLS
--==============================================================

local function GetOrCreateEffect(className, effectName)
    local effect = PostEffects[effectName]
    if effect and effect.Parent then return effect end
    effect = Lighting:FindFirstChild("PrivateX_" .. effectName)
    if not effect then
        effect = Instance.new(className)
        effect.Name = "PrivateX_" .. effectName
        effect.Parent = Lighting
        table.insert(CreatedObjects, effect)
    end
    PostEffects[effectName] = effect
    return effect
end

local function ApplyPostEffects()
    if Unloaded then return end
    local bloom = GetOrCreateEffect("BloomEffect", "Bloom")
    bloom.Enabled = PostSettings.Bloom
    bloom.Intensity, bloom.Size, bloom.Threshold =
        PostSettings.BloomIntensity, PostSettings.BloomSize, PostSettings.BloomThreshold

    local correction = GetOrCreateEffect("ColorCorrectionEffect", "ColorCorrection")
    correction.Enabled = PostSettings.ColorCorrection
    correction.Saturation = PostSettings.Saturation
    correction.Contrast = PostSettings.Contrast
    correction.Brightness = PostSettings.PostBrightness
    correction.TintColor = PostSettings.TintColor

    local rays = GetOrCreateEffect("SunRaysEffect", "SunRays")
    rays.Enabled = PostSettings.SunRays
    rays.Intensity, rays.Spread = PostSettings.SunRayIntensity, PostSettings.SunRaySpread

    local dof = GetOrCreateEffect("DepthOfFieldEffect", "DepthOfField")
    dof.Enabled = PostSettings.DepthOfField
    dof.FocusDistance = PostSettings.FocusDistance
    dof.InFocusRadius = PostSettings.InFocusRadius
    dof.NearIntensity, dof.FarIntensity = 0.1, 0.25
end

WorldTab:CreateSection("Lighting & Cinematic Effects")
WorldTab:CreateToggle({Name = "Bloom Glow", CurrentValue = false, Callback = function(v) PostSettings.Bloom = v; ApplyPostEffects() end})
WorldTab:CreateSlider({Name = "Bloom Intensity", Range = {0, 3}, Increment = 0.05, CurrentValue = PostSettings.BloomIntensity, Callback = function(v) PostSettings.BloomIntensity = v; ApplyPostEffects() end})
WorldTab:CreateSlider({Name = "Bloom Size", Range = {0, 56}, Increment = 1, CurrentValue = PostSettings.BloomSize, Callback = function(v) PostSettings.BloomSize = v; ApplyPostEffects() end})
WorldTab:CreateSlider({Name = "Bloom Threshold", Range = {0, 2}, Increment = 0.05, CurrentValue = PostSettings.BloomThreshold, Callback = function(v) PostSettings.BloomThreshold = v; ApplyPostEffects() end})
WorldTab:CreateToggle({Name = "Color Grading", CurrentValue = false, Callback = function(v) PostSettings.ColorCorrection = v; ApplyPostEffects() end})
WorldTab:CreateSlider({Name = "Saturation", Range = {-1, 1}, Increment = 0.05, CurrentValue = 0, Callback = function(v) PostSettings.Saturation = v; ApplyPostEffects() end})
WorldTab:CreateSlider({Name = "Contrast", Range = {-1, 1}, Increment = 0.05, CurrentValue = 0, Callback = function(v) PostSettings.Contrast = v; ApplyPostEffects() end})
WorldTab:CreateSlider({Name = "Post Brightness", Range = {-1, 1}, Increment = 0.05, CurrentValue = 0, Callback = function(v) PostSettings.PostBrightness = v; ApplyPostEffects() end})
WorldTab:CreateColorPicker({Name = "Color Grade Tint", Color = PostSettings.TintColor, Callback = function(v) PostSettings.TintColor = v; ApplyPostEffects() end})
WorldTab:CreateToggle({Name = "Sun Rays", CurrentValue = false, Callback = function(v) PostSettings.SunRays = v; ApplyPostEffects() end})
WorldTab:CreateSlider({Name = "Sun Ray Intensity", Range = {0, 0.25}, Increment = 0.01, CurrentValue = PostSettings.SunRayIntensity, Callback = function(v) PostSettings.SunRayIntensity = v; ApplyPostEffects() end})
WorldTab:CreateSlider({Name = "Sun Ray Spread", Range = {0, 1}, Increment = 0.05, CurrentValue = PostSettings.SunRaySpread, Callback = function(v) PostSettings.SunRaySpread = v; ApplyPostEffects() end})
WorldTab:CreateToggle({Name = "Depth of Field", CurrentValue = false, Callback = function(v) PostSettings.DepthOfField = v; ApplyPostEffects() end})
WorldTab:CreateSlider({Name = "Focus Distance", Range = {5, 300}, Increment = 5, CurrentValue = PostSettings.FocusDistance, Callback = function(v) PostSettings.FocusDistance = v; ApplyPostEffects() end})
WorldTab:CreateSlider({Name = "Focus Radius", Range = {1, 100}, Increment = 1, CurrentValue = PostSettings.InFocusRadius, Callback = function(v) PostSettings.InFocusRadius = v; ApplyPostEffects() end})
WorldTab:CreateButton({Name = "Disable All Post FX", Callback = function()
    PostSettings.Bloom, PostSettings.ColorCorrection, PostSettings.SunRays, PostSettings.DepthOfField = false, false, false, false
    ApplyPostEffects()
end})
WorldTab:CreateSection("Motion Blur")
local function EnsureMotionBlurEffect()
    if MotionBlurEffect and MotionBlurEffect.Parent then return MotionBlurEffect end
    MotionBlurEffect = Lighting:FindFirstChild("PrivateX_MotionBlur")
    if not MotionBlurEffect then
        MotionBlurEffect = Instance.new("BlurEffect")
        MotionBlurEffect.Name = "PrivateX_MotionBlur"
        MotionBlurEffect.Size = 0
        MotionBlurEffect.Parent = Lighting
        table.insert(CreatedObjects, MotionBlurEffect)
    end
    return MotionBlurEffect
end
WorldTab:CreateToggle({Name = "Motion Blur", CurrentValue = false, Callback = function(v)
    MotionBlurSettings.Enabled = v
    local effect = EnsureMotionBlurEffect()
    effect.Enabled = v
    if not v then effect.Size = 0 end
    LastMotionBlurCameraCFrame = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame or nil
end})
WorldTab:CreateSlider({Name = "Motion Blur Intensity", Range = {0, 30}, Increment = 1, CurrentValue = MotionBlurSettings.Intensity, Callback = function(v)
    MotionBlurSettings.Intensity = v
end})
WorldTab:CreateSlider({Name = "Motion Blur Sensitivity", Range = {0, 5}, Increment = 0.1, CurrentValue = MotionBlurSettings.Sensitivity, Callback = function(v)
    MotionBlurSettings.Sensitivity = v
end})
TrackConnection(RunService.RenderStepped:Connect(function(dt)
    if Unloaded or not MotionBlurSettings.Enabled then return end
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local effect = EnsureMotionBlurEffect()
    local current = camera.CFrame
    if LastMotionBlurCameraCFrame then
        local delta = LastMotionBlurCameraCFrame:ToObjectSpace(current)
        local _, yaw, pitch = delta:ToOrientation()
        local target = math.clamp((math.abs(yaw) + math.abs(pitch)) * MotionBlurSettings.Sensitivity * MotionBlurSettings.Intensity, 0, MotionBlurSettings.Intensity)
        effect.Size = effect.Size + (target - effect.Size) * math.min(1, dt * 8)
    end
    LastMotionBlurCameraCFrame = current
end))

--==============================================================
-- WEATHER / AMBIENCE
--==============================================================

WeatherTab:CreateSection("Choose Weather")
WeatherTab:CreateDropdown({
    Name = "Weather Preset",
    Options = {"Off", "Rain", "Snow", "Blizzard"},
    CurrentOption = {"Off"},
    MultipleOptions = false,
    Callback = function(option)
        local selected = typeof(option) == "table" and option[1] or option
        StartScreenWeather(selected)
    end,
})
WeatherTab:CreateToggle({Name = "Weather Ambience", CurrentValue = true, Callback = function(v)
    WeatherAmbienceEnabled = v
    if WeatherMode ~= "Off" then StartWeatherAmbience(WeatherMode) else StopWeatherAmbience() end
end})
WeatherTab:CreateSlider({Name = "Ambience Volume", Range = {0, 1}, Increment = 0.05, CurrentValue = 0.35, Callback = function(v)
    WeatherAmbienceVolume = v
    if WeatherSoundObject then WeatherSoundObject.Volume = v end
end})
WeatherTab:CreateDropdown({Name = "Blizzard Sound", Options = {"Wind", "Rain"}, CurrentOption = {"Wind"}, MultipleOptions = false, Callback = function(option)
    local selected = typeof(option) == "table" and option[1] or option
    if selected == "Wind" then
        WeatherSoundIds.Blizzard = "rbxassetid://9112854440"
    else
        WeatherSoundIds.Blizzard = WeatherSoundIds.Rain
    end
    if WeatherMode == "Blizzard" then StartWeatherAmbience("Blizzard") end
end})
WeatherTab:CreateInput({Name = "Custom Blizzard Audio ID", PlaceholderText = "Roblox audio ID or rbxassetid://...", RemoveTextAfterFocusLost = false, Callback = function(value)
    if not value or value == "" then return end
    if string.match(value, "^%d+$") then value = "rbxassetid://" .. value end
    WeatherSoundIds.Blizzard = value
    if WeatherMode == "Blizzard" then StartWeatherAmbience("Blizzard") end
end})
WeatherTab:CreateSection("Weather Tuning")
WeatherTab:CreateSlider({Name = "Weather Intensity", Range = {0.25, 2}, Increment = 0.05, CurrentValue = 1, Callback = function(v)
    WeatherSettings.Intensity = v
    if WeatherMode ~= "Off" then StartScreenWeather(WeatherMode) end
end})
WeatherTab:CreateSlider({Name = "Particle Speed", Range = {0.25, 3}, Increment = 0.05, CurrentValue = 1, Callback = function(v)
    WeatherSettings.Speed = v
    if WeatherMode ~= "Off" then StartScreenWeather(WeatherMode) end
end})
WeatherTab:CreateSlider({Name = "Wind Strength", Range = {0, 2}, Increment = 0.05, CurrentValue = 0.15, Callback = function(v)
    WeatherSettings.WindStrength = v
    if WeatherMode ~= "Off" then StartScreenWeather(WeatherMode) end
end})
WeatherTab:CreateSlider({Name = "Wind Angle", Range = {0, 360}, Increment = 5, CurrentValue = 15, Suffix = " deg", Callback = function(v)
    WeatherSettings.WindAngle = v
    if WeatherMode ~= "Off" then StartScreenWeather(WeatherMode) end
end})
WeatherTab:CreateColorPicker({Name = "Rain Tint", Color = WeatherSettings.ParticleColor, Callback = function(v)
    WeatherSettings.ParticleColor = v
    if WeatherMode ~= "Off" then StartScreenWeather(WeatherMode) end
end})
WeatherTab:CreateColorPicker({Name = "Snow Tint", Color = WeatherSettings.SnowColor, Callback = function(v)
    WeatherSettings.SnowColor = v
    if WeatherMode ~= "Off" then StartScreenWeather(WeatherMode) end
end})
WeatherTab:CreateParagraph({Title = "Local Weather Effects", Content = "Weather is a local screen overlay. Blizzard includes looping ambient wind audio; audio playback depends on the asset being available and permitted in this experience."})

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
-- LOCAL SKID MARKS (visual-only tire trails while drifting)
--==============================================================

local SkidMarksEnabled = true
local SkidMarks = {}
local SkidMarkTimer = 0
local SkidMarkLifetime = 5.5

local function ClearSkidMarks()
    for _, item in ipairs(SkidMarks) do SafeDestroy(item.Part) end
    table.clear(SkidMarks)
end

local function SpawnSkidMark(position, forward, width)
    local mark = Instance.new("Part")
    mark.Name = "PrivateX_SkidMark"
    mark.Anchored = true
    mark.CanCollide = false
    mark.CanTouch = false
    mark.CanQuery = false
    mark.CastShadow = false
    mark.Material = Enum.Material.SmoothPlastic
    mark.Color = Color3.fromRGB(22, 22, 24)
    mark.Transparency = 0.32
    mark.Size = Vector3.new(width or 0.65, 0.025, 2.8)
    local flatForward = Vector3.new(forward.X, 0, forward.Z)
    if flatForward.Magnitude < 0.001 then flatForward = Vector3.new(0, 0, -1) end
    mark.CFrame = CFrame.lookAt(position + Vector3.new(0, 0.035, 0),
        position + Vector3.new(0, 0.035, 0) + flatForward.Unit)
    mark.Parent = Workspace
    table.insert(SkidMarks, {Part = mark, Age = 0})
end

local function UpdateSkidMarks(dt)
    if not SkidMarksEnabled or not Settings.Drift then return end
    SkidMarkTimer += dt
    if SkidMarkTimer < 0.075 then return end
    SkidMarkTimer = 0
    local model = GetVehicleModel()
    local root = GetVehicleRoot(model)
    local seat = GetVehicleSeat()
    if not model or not root or not seat or root.AssemblyLinearVelocity.Magnitude < 18 or seat.Steer == 0 then return end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {model, LocalPlayer.Character}
    params.IgnoreWater = true
    local right, forward = root.CFrame.RightVector, root.CFrame.LookVector
    local halfWidth = math.clamp(root.Size.X * 0.28, 1.1, 3.5)
    for _, side in ipairs({-1, 1}) do
        local origin = root.Position + right * halfWidth * side + Vector3.new(0, 1.5, 0)
        local hit = Workspace:Raycast(origin, Vector3.new(0, -8, 0), params)
        if hit and hit.Normal.Y > 0.55 then SpawnSkidMark(hit.Position, forward, 0.55) end
    end
end

local function UpdateSkidMarkAges(dt)
    for i = #SkidMarks, 1, -1 do
        local item = SkidMarks[i]
        item.Age += dt
        if not item.Part or not item.Part.Parent or item.Age >= SkidMarkLifetime then
            SafeDestroy(item.Part)
            table.remove(SkidMarks, i)
        else
            item.Part.Transparency = 0.32 + 0.65 * (item.Age / SkidMarkLifetime)
        end
    end
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
    Name = "Skid Marks",
    CurrentValue = true,
    Callback = function(value)
        SkidMarksEnabled = value
        if not value then ClearSkidMarks() end
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
    AppearanceTab:CreateColorPicker({
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

AppearanceTab:CreateButton({
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
-- MENU COLOR STUDIO
-- Rayfield exposes its own native color picker; these are local visual
-- accents for vehicle paint, ESP, underglow, and world grading.
--==============================================================

AppearanceTab:CreateSection("Appearance Color Studio")
AppearanceTab:CreateColorPicker({Name = "Vehicle Body", Color = PaintColors.Body, Callback = function(v) PaintColors.Body = v; ApplyColorToCategory("Body", v) end})
AppearanceTab:CreateColorPicker({Name = "Vehicle Accent / Trim", Color = PaintColors.Trim, Callback = function(v) PaintColors.Trim = v; ApplyColorToCategory("Trim", v) end})
AppearanceTab:CreateColorPicker({Name = "Underglow", Color = Settings.UnderglowColor, Callback = function(v) Settings.UnderglowColor = v; Settings.RainbowUnderglow = false; UpdateUnderglow() end})
AppearanceTab:CreateColorPicker({Name = "Player Marker", Color = Settings.ESPColor, Callback = function(v) Settings.ESPColor = v end})
AppearanceTab:CreateColorPicker({Name = "World Ambient", Color = Lighting.Ambient, Callback = function(v) Lighting.Ambient = v; Lighting.OutdoorAmbient = v end})
AppearanceTab:CreateColorPicker({Name = "Weather Tint", Color = WeatherSettings.ParticleColor, Callback = function(v) WeatherSettings.ParticleColor = v; if WeatherMode ~= "Off" then StartScreenWeather(WeatherMode) end end})
AppearanceTab:CreateParagraph({Title = "Color picker", Content = "Uses Rayfield's native RGB/HSV color picker. Color changes apply to the selected local visual feature."})

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
    StopScreenWeather()
    if MotionBlurEffect then SafeDestroy(MotionBlurEffect); MotionBlurEffect = nil end
    ClearSkidMarks()
    RestoreWorldLighting()

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

    if TimeOverrideEnabled then
        pcall(function()
            Lighting.ClockTime = SelectedClockTime
        end)
    end
    pcall(ApplyVehiclePhysics, dt)
    pcall(UpdateFlight)
    pcall(UpdateScreenWeather, dt)
    pcall(UpdateSkidMarks, dt)
    pcall(UpdateSkidMarkAges, dt)

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
})