-- ============================================================
-- BROKECHEAT • ULTIMATE v6 — SINGLE FILE (Linoria UI)
-- v6 fixes: auto-show window, FOV stroke rotation crash, highlight
-- parenting, crosshair holder rotation, chams throttle + ESP record
-- cleanup, per-frame error reporter.
-- Private-place sandbox & client-side presentation tools ONLY.
-- No game-module hooks, no remotes, no anti-cheat interaction,
-- no ownership/inventory/leaderboard spoofing, no combat automation.
-- ============================================================
if not game:IsLoaded() then game.Loaded:Wait() end
if getgenv and getgenv().BrokeUltimateV6 then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local dbg = Instance.new("ScreenGui")
dbg.Name = "BC_Debug"; dbg.ResetOnSpawn = false; dbg.IgnoreGuiInset = true; dbg.DisplayOrder = 1003
dbg.Parent = PlayerGui
local dbgFrame = Instance.new("Frame", dbg)
dbgFrame.AnchorPoint = Vector2.new(0, 1)
dbgFrame.Position = UDim2.new(0, 10, 1, -10)
dbgFrame.Size = UDim2.new(0, 440, 0, 84)
dbgFrame.BackgroundColor3 = Color3.fromRGB(12, 13, 17)
dbgFrame.BackgroundTransparency = 0.15
Instance.new("UICorner", dbgFrame).CornerRadius = UDim.new(0, 8)
local dbgText = Instance.new("TextLabel", dbgFrame)
dbgText.Position = UDim2.new(0, 8, 0, 6)
dbgText.Size = UDim2.new(1, -16, 1, -12)
dbgText.BackgroundTransparency = 1
dbgText.Font = Enum.Font.Code; dbgText.TextSize = 12
dbgText.TextColor3 = Color3.fromRGB(120, 255, 140)
dbgText.TextXAlignment = Enum.TextXAlignment.Left
dbgText.TextYAlignment = Enum.TextYAlignment.Top
dbgText.TextWrapped = true
local statusLines = {}
local function BrokeStatus(msg)
	table.insert(statusLines, msg)
	if #statusLines > 4 then table.remove(statusLines, 1) end
	dbgText.Text = table.concat(statusLines, "\n")
end
local function BrokeFatal(msg)
	BrokeStatus("FATAL: " .. msg)
	dbgText.TextColor3 = Color3.fromRGB(255, 140, 140)
end
BrokeStatus("boot: fetching UI library...")

local function fetch(url)
	local ok, src = pcall(function() return game:HttpGet(url) end)
	if not ok or not src or #src == 0 then return nil end
	local fn = loadstring(src)
	if not fn then return nil end
	local ok2, lib = pcall(fn)
	return ok2 and lib or nil
end
local Library = fetch("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua")
local SaveManager = fetch("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua")
local ThemeManager = fetch("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua")
if not Library then
	BrokeFatal("Linoria download failed (enable HTTP in executor)")
	return
end

camera = Workspace.CurrentCamera
RunService.RenderStepped:Connect(function() camera = Workspace.CurrentCamera end)

-- one-time per-frame error reporter
local stepErrShown = false
local function safeStep(name, fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok and not stepErrShown then
			stepErrShown = true
			BrokeFatal("LOOP " .. name .. ": " .. tostring(err))
		end
	end
end

local okBuild, buildErr = pcall(function()
BrokeStatus("build: window + tabs")
local Window = Library:CreateWindow({
	Title = "Brokecheat • Ultimate v6",
	Size = UDim2.fromOffset(760, 660),
})
local AimTab = Window:AddTab("Aim")
local EspTab = Window:AddTab("ESP")
local VisualsTab = Window:AddTab("Visuals")
local WorldTab = Window:AddTab("World")
local CharTab = Window:AddTab("Character")
local AudioTab = Window:AddTab("Audio")
local PracticeTab = Window:AddTab("Practice")
local MiscTab = Window:AddTab("Misc")
local SettingsTab = Window:AddTab("Settings")
BrokeStatus("build: state + helpers")

-- ================= STATE =================
local RNG = Random.new()
local visualsEnabled = true
local aimOn, aimNeedKey, aimWall, aimPredict, aimMarkerOn = false, true, false, false, true
local aimSmooth, aimFov, aimTurnCap, aimDelayMs, aimMaxDist, aimPredScale = 0.2, 200, 0, 0, 1200, 1
local aimPart, aimPriority, aimFeed = "Head", "Closest Screen", "None"
local espOn, espBox, espHealth, espName, espDist, espHigh, espChams, espTeam = false, true, true, true, true, true, false, false
local espMaxDist, espBarWidth = 2500, 4
local espBoxColor = Color3.new(1, 1, 1)
local espHighFill = Color3.fromRGB(90, 150, 255)
local espChamsMat, espChamsColor = "Neon", Color3.fromRGB(120, 190, 255)
local bloomOn, blurOn, dofOn, sunOn, vigOn, grainOn, cycleOn, pulseOn, swayOn = false, false, false, false, false, false, false, false, false
local motionBlurOn, motionBlurInt, motionBlurSens, baseBlur = false, 0.5, 1, 0
local vigStrength = 0.5
local weatherType, weatherRate, weatherColor, lightningOn = "Off", 100, Color3.new(1, 1, 1), false
local cozyFireflies, cozyDust, cozyLantern, cozyBreathe = false, false, false, false
local skyOn, skyRotate, skyRotSpeed, skyRotMethod, skyRotDir = false, false, 1, "Spin", "Horizontal"
local stretchedOn, stretchedAmt = false, 0.2
local fovChangerOn, fovChangerVal = false, 80
local texOn, texMat, texColor, texViewModel = false, "Brick", Color3.fromRGB(244, 244, 244), false
local deathFxOn, deathFxType, deathFxColor = false, "Sparkles", Color3.fromRGB(120, 81, 166)
local crossOn, crossRainbow, crossDot, crossOutline = false, false, false, false
local crossStyle, crossSize, crossGap, crossThick, crossOpac = "+", 22, 5, 2, 1
local crossColor, crossOutColor, crossRot, crossRotSpeed = Color3.new(1,1,1), Color3.new(0,0,0), 0, 0
local hudOn, indOn, wmOn = false, false, false
local trLock, trClick, trDemo, trLife, trThick = false, false, false, 0.6, 0.15
local trA, trB = Color3.fromRGB(120, 190, 255), Color3.fromRGB(255, 140, 220)
local prHitreg, prShootback, prInterval, prDmg = false, false, 1.2, 12
local prPattern, prSpeed = "Off", 3
local chamsLast = 0

-- ================= EFFECTS / GUIS =================
local function effect(cls, name)
	local e = Lighting:FindFirstChild(name)
	if e and e:IsA(cls) then return e end
	if e then e:Destroy() end
	e = Instance.new(cls); e.Name = name; e.Parent = Lighting
	return e
end
local bloom = effect("BloomEffect", "BC_Bloom")
local cc = effect("ColorCorrectionEffect", "BC_Color")
local atmo = effect("Atmosphere", "BC_Atmo")
local sunrays = effect("SunRaysEffect", "BC_Sun")
local doffx = effect("DepthOfFieldEffect", "BC_DOF")
local blurfx = effect("BlurEffect", "BC_Blur")
bloom.Intensity = 0; bloom.Size = 24; bloom.Threshold = 1
cc.Enabled = false
atmo.Density = 0; atmo.Haze = 0; atmo.Glare = 0
sunrays.Intensity = 0
doffx.FarIntensity = 0; doffx.NearIntensity = 0; doffx.FocusDistance = 25
blurfx.Size = 0
local origLighting = {
	Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
	FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd,
	Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
	ExposureCompensation = Lighting.ExposureCompensation, GlobalShadows = Lighting.GlobalShadows,
}
local origCamFov = camera and camera.FieldOfView or 70

local Overlay = Instance.new("ScreenGui")
Overlay.Name = "BC_Overlay"; Overlay.IgnoreGuiInset = true; Overlay.ResetOnSpawn = false; Overlay.Parent = PlayerGui
local Vig = Instance.new("Frame", Overlay)
Vig.BackgroundTransparency = 1; Vig.Size = UDim2.new(1, 0, 1, 0)
local VigStroke = Instance.new("UIStroke", Vig)
VigStroke.Thickness = 26; VigStroke.Transparency = 1
local Grain = Instance.new("TextLabel", Overlay)
Grain.BackgroundTransparency = 1; Grain.Size = UDim2.new(1, 0, 1, 0)
Grain.Text = "·  ·   ·    ·  ·   ·    ·   ·"; Grain.TextScaled = true
Grain.Font = Enum.Font.Code; Grain.TextColor3 = Color3.new(1,1,1); Grain.TextTransparency = 1
local Flash = Instance.new("Frame", Overlay)
Flash.BackgroundColor3 = Color3.fromRGB(225, 240, 255); Flash.BackgroundTransparency = 1; Flash.Size = UDim2.new(1, 0, 1, 0)

local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = "BC_ESP"; ESPGui.IgnoreGuiInset = true; ESPGui.ResetOnSpawn = false; ESPGui.Parent = PlayerGui
local FovGui = Instance.new("ScreenGui")
FovGui.Name = "BC_FOV"; FovGui.IgnoreGuiInset = true; FovGui.ResetOnSpawn = false; FovGui.Parent = PlayerGui
local FovCircle = Instance.new("Frame", FovGui)
FovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
FovCircle.Size = UDim2.new(0, 400, 0, 400)
FovCircle.BackgroundTransparency = 1; FovCircle.Visible = false
Instance.new("UICorner", FovCircle).CornerRadius = UDim.new(1, 0)
local FovStroke = Instance.new("UIStroke", FovCircle); FovStroke.Thickness = 1.4
local FovStrokeGrad = Instance.new("UIGradient", FovStroke)   -- v6 FIX: rotate the gradient, not the stroke
local FovFillGrad = Instance.new("UIGradient", FovCircle)
FovFillGrad.Transparency = NumberSequence.new(1)
local MarkerGui = Instance.new("ScreenGui")
MarkerGui.Name = "BC_Marker"; MarkerGui.IgnoreGuiInset = true; MarkerGui.ResetOnSpawn = false; MarkerGui.Parent = PlayerGui
local TargetMarker = Instance.new("Frame", MarkerGui)
TargetMarker.AnchorPoint = Vector2.new(0.5, 0.5)
TargetMarker.Size = UDim2.new(0, 14, 0, 14)
TargetMarker.BackgroundTransparency = 1; TargetMarker.Visible = false
Instance.new("UICorner", TargetMarker).CornerRadius = UDim.new(1, 0)
local markerStroke = Instance.new("UIStroke", TargetMarker); markerStroke.Thickness = 2
local CrossGui = Instance.new("ScreenGui")
CrossGui.Name = "BC_Cross"; CrossGui.IgnoreGuiInset = true; CrossGui.ResetOnSpawn = false; CrossGui.Parent = PlayerGui
local crossHolder = Instance.new("Frame", CrossGui)          -- v6 FIX: rotate the holder, not each arm
crossHolder.AnchorPoint = Vector2.new(0.5, 0.5)
crossHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
crossHolder.Size = UDim2.new(0, 0, 0, 0)
crossHolder.BackgroundTransparency = 1
local crossParts = {}
local HudGui = Instance.new("ScreenGui")
HudGui.Name = "BC_HUD"; HudGui.IgnoreGuiInset = true; HudGui.ResetOnSpawn = false; HudGui.Parent = PlayerGui
local HudFrame = Instance.new("Frame", HudGui)
HudFrame.Position = UDim2.new(0, 14, 0, 100)
HudFrame.Size = UDim2.new(0, 240, 0, 84)
HudFrame.BackgroundColor3 = Color3.fromRGB(15, 16, 20)
HudFrame.BackgroundTransparency = 0.15
HudFrame.Visible = false
Instance.new("UICorner", HudFrame).CornerRadius = UDim.new(0, 8)
local hudStroke = Instance.new("UIStroke", HudFrame); hudStroke.Transparency = 0.4
local HudText = Instance.new("TextLabel", HudFrame)
HudText.Position = UDim2.new(0, 8, 0, 6)
HudText.Size = UDim2.new(1, -16, 1, -12)
HudText.BackgroundTransparency = 1
HudText.Font = Enum.Font.Code; HudText.TextSize = 12
HudText.TextColor3 = Color3.fromRGB(160, 200, 255)
HudText.TextXAlignment = Enum.TextXAlignment.Left
HudText.TextYAlignment = Enum.TextYAlignment.Top
HudText.TextWrapped = true
local WmGui = Instance.new("ScreenGui")
WmGui.Name = "BC_WM"; WmGui.IgnoreGuiInset = true; WmGui.ResetOnSpawn = false; WmGui.Parent = PlayerGui
local WmFrame = Instance.new("Frame", WmGui)
WmFrame.Position = UDim2.new(0, 12, 0, 56)
WmFrame.Size = UDim2.new(0, 260, 0, 40)
WmFrame.BackgroundColor3 = Color3.fromRGB(15, 16, 20)
WmFrame.BackgroundTransparency = 0.15
WmFrame.Visible = false
Instance.new("UICorner", WmFrame).CornerRadius = UDim.new(0, 8)
local WmText = Instance.new("TextLabel", WmFrame)
WmText.Size = UDim2.new(1, -12, 1, -8); WmText.Position = UDim2.new(0, 6, 0, 4)
WmText.BackgroundTransparency = 1; WmText.Font = Enum.Font.Code; WmText.TextSize = 12
WmText.TextColor3 = Color3.fromRGB(160, 190, 255); WmText.TextXAlignment = Enum.TextXAlignment.Left

local weatherPart = Instance.new("Part")
weatherPart.Anchored = true; weatherPart.CanCollide = false; weatherPart.CanQuery = false; weatherPart.CanTouch = false
weatherPart.Transparency = 1; weatherPart.Size = Vector3.new(60, 2, 60)
weatherPart.Parent = Workspace
local weatherEm = Instance.new("ParticleEmitter", weatherPart)
weatherEm.Enabled = false
weatherEm.EmissionDirection = Enum.NormalId.Bottom
local thunderSound = Instance.new("Sound")
thunderSound.SoundId = "rbxassetid://9064267922"
thunderSound.Volume = 0.8
thunderSound.Parent = SoundService

local fireflyPart, dustPart, lantern = nil, nil, nil
local function makeAmbientParticle(kind)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Transparency = 1; p.Size = Vector3.new(1,1,1); p.Parent = Workspace
	local em = Instance.new("ParticleEmitter", p)
	em.SpreadAngle = Vector2.new(180, 180)
	if kind == "Fireflies" then
		em.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 170, 60))
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0) })
		em.Rate = 4; em.Speed = NumberRange.new(0.4, 1.2)
		em.Lifetime = NumberRange.new(3, 6); em.LightEmission = 1
	else
		em.Color = ColorSequence.new(Color3.fromRGB(220, 220, 225))
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(1, 0) })
		em.Rate = 6; em.Speed = NumberRange.new(0.1, 0.35)
		em.Lifetime = NumberRange.new(4, 8)
	end
	return p
end

-- ================= HELPERS =================
local function getTargets()
	local out, seen = {}, {}
	local folder = Workspace:FindFirstChild("TestTargets")
	if folder then
		for _, t in ipairs(folder:GetChildren()) do
			local h = t:FindFirstChildOfClass("Humanoid")
			local r = t:FindFirstChild("HumanoidRootPart")
			if h and r and h.Health > 0 then table.insert(out, t) seen[t] = true end
		end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character and not seen[plr.Character] then
			local h = plr.Character:FindFirstChildOfClass("Humanoid")
			local r = plr.Character:FindFirstChild("HumanoidRootPart")
			if h and r and h.Health > 0 then table.insert(out, plr.Character) end
		end
	end
	return out
end
local function partOf(model)
	if aimPart == "Closest Part" then
		local best, bestD = nil, math.huge
		local mpos = UserInputService:GetMouseLocation()
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
				local sp, on = camera:WorldToViewportPoint(p.Position)
				if on and sp.Z > 0 then
					local d = (Vector2.new(sp.X, sp.Y) - mpos).Magnitude
					if d < bestD then best, bestD = p, d end
				end
			end
		end
		return best or model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
	end
	return model:FindFirstChild(aimPart) or model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
end
local function wallClear(part)
	if not aimWall then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { LocalPlayer.Character, part.Parent }
	local hit = Workspace:Raycast(camera.CFrame.Position, part.Position - camera.CFrame.Position, params)
	return hit == nil
end
local function pickTarget()
	if not camera then return nil, nil end
	local center = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y * 0.5)
	local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local best, bestPart, bestScore = nil, nil, math.huge
	for _, t in ipairs(getTargets()) do
		local hum = t:FindFirstChildOfClass("Humanoid")
		local part = partOf(t)
		if hum and hum.Health > 0 and part then
			local root = t:FindFirstChild("HumanoidRootPart") or part
			local worldD = myRoot and (root.Position - myRoot.Position).Magnitude or 0
			if worldD <= aimMaxDist and wallClear(part) then
				local sp, on = camera:WorldToViewportPoint(part.Position)
				if on and sp.Z > 0 then
					local screenD = (Vector2.new(sp.X, sp.Y) - center).Magnitude
					if screenD <= aimFov then
						local score = screenD
						if aimPriority == "Closest World" then score = worldD end
						if aimPriority == "Lowest HP" then score = hum.Health end
						if score < bestScore then best, bestPart, bestScore = t, part, score end
					end
				end
			end
		end
	end
	return best, bestPart
end
local function espBounds(root)
	local t, tOn = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 2.6, 0))
	local b, bOn = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 1.4, 0))
	if not tOn or not bOn or t.Z <= 0 then return nil end
	local h = math.abs(b.Y - t.Y)
	if h < 6 then return nil end
	local w = h * 0.62
	return t.X - w / 2, t.Y, w, h
end
local function fireTracer(fromPos, toPos, color)
	local dist = (toPos - fromPos).Magnitude
	if dist < 1 then return end
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color or trA
	p.Size = Vector3.new(trThick, trThick, dist)
	p.CFrame = CFrame.lookAt(fromPos, toPos) * CFrame.new(0, 0, -dist / 2)
	p.Parent = Workspace
	TweenService:Create(p, TweenInfo.new(trLife, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
	task.delay(trLife + 0.05, function() if p and p.Parent then p:Destroy() end end)
end
local FEED = { Hit = "rbxassetid://13110130082", Kill = "rbxassetid://16537449730" }
local function playFeedback(kind)
	local id = FEED[kind]
	if not id then return end
	local s = Instance.new("Sound")
	s.SoundId = id; s.Volume = 0.35; s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function() s:Destroy() end)
	task.delay(2, function() if s and s.Parent then s:Destroy() end end)
end
local function applyWeather()
	weatherEm.Enabled = false
	lightningOn = false
	if weatherType == "Off" then return end
	if weatherType == "Snow" then
		weatherEm.Texture = "http://www.roblox.com/asset/?id=99851851"
		weatherEm.Rate = weatherRate
		weatherEm.Speed = NumberRange.new(6, 10)
		weatherEm.Lifetime = NumberRange.new(4, 7)
		weatherEm.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0.15) })
		weatherEm.SpreadAngle = Vector2.new(30, 30)
		weatherEm.LightEmission = 0
	else
		weatherEm.Texture = "rbxassetid://1822883048"
		weatherEm.Rate = weatherRate * 4
		weatherEm.Speed = NumberRange.new(60, 70)
		weatherEm.Lifetime = NumberRange.new(0.8, 0.8)
		weatherEm.Size = NumberSequence.new(10)
		weatherEm.SpreadAngle = Vector2.new(0, 0)
		weatherEm.LightEmission = 0.05
		weatherEm.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		lightningOn = (weatherType == "Storm")
	end
	weatherEm.Color = ColorSequence.new(weatherColor)
	weatherEm.Enabled = visualsEnabled
end
task.spawn(function()
	while true do
		task.wait(RNG:NextNumber(4, 10))
		if lightningOn and visualsEnabled then
			Flash.BackgroundTransparency = 0.72
			task.delay(0.05, function() Flash.BackgroundTransparency = 1 end)
			task.delay(0.12, function()
				Flash.BackgroundTransparency = 0.88
				thunderSound:Play()
				task.delay(0.07, function() Flash.BackgroundTransparency = 1 end)
			end)
		end
	end
end)
local function rebuildCrosshair()
	for _, p in ipairs(crossParts) do if p and p.Parent then p:Destroy() end end
	crossParts = {}
	if not crossOn then return end
	local function bar(pos, size, outline)
		local f = Instance.new("Frame", crossHolder)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = pos
		f.Size = size
		f.BorderSizePixel = 0
		f.BackgroundColor3 = outline and crossOutColor or crossColor
		f.BackgroundTransparency = 1 - crossOpac
		f.ZIndex = outline and 1 or 2
		table.insert(crossParts, f)
		return f
	end
	local s, g, t = crossSize, crossGap, crossThick
	local arms = {}
	if crossStyle == "+" then
		arms = { {0, -(g + s/2), t, s}, {0, (g + s/2), t, s}, {-(g + s/2), 0, s, t}, {(g + s/2), 0, s, t} }
	elseif crossStyle == "x" then
		local d = 0.7071
		arms = { {-d*(g+s/2), -d*(g+s/2), t, s}, {d*(g+s/2), d*(g+s/2), t, s}, {-d*(g+s/2), d*(g+s/2), t, s}, {d*(g+s/2), -d*(g+s/2), t, s} }
	elseif crossStyle == "t" then
		arms = { {0, (g + s/2), t, s}, {-(g + s/2), 0, s, t}, {(g + s/2), 0, s, t} }
	elseif crossStyle == "cross" then
		arms = { {0, 0, s*2 + g, t}, {0, 0, t, s*2 + g} }
	end
	for _, a in ipairs(arms) do
		if crossOutline then bar(UDim2.new(0, a[1], 0, a[2]), UDim2.new(0, a[3] + 2, 0, a[4] + 2), true) end
		bar(UDim2.new(0, a[1], 0, a[2]), UDim2.new(0, a[3], 0, a[4]), false)
	end
	if crossDot then
		if crossOutline then bar(UDim2.new(0,0,0,0), UDim2.new(0, t + 4, 0, t + 4), true) end
		bar(UDim2.new(0,0,0,0), UDim2.new(0, t + 2, 0, t + 2), false)
	end
end
local espRecords = {}
local function espEnsure(t)
	local r = espRecords[t]
	if not r then
		r = {}
		r.box = Instance.new("Frame", ESPGui)
		r.box.BackgroundTransparency = 1
		r.box.BorderSizePixel = 0
		r.boxStroke = Instance.new("UIStroke", r.box)
		r.boxStroke.Thickness = 1
		r.fill = Instance.new("Frame", r.box)
		r.fill.BackgroundColor3 = Color3.new(1,1,1)
		r.fill.BackgroundTransparency = 0.85
		r.fill.Size = UDim2.new(1, 0, 1, 0)
		r.barBg = Instance.new("Frame", ESPGui)
		r.barBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		r.barBg.BorderSizePixel = 0
		r.bar = Instance.new("Frame", r.barBg)
		r.bar.BorderSizePixel = 0
		r.bar.AnchorPoint = Vector2.new(0, 1)
		r.bar.Position = UDim2.new(0, 0, 1, 0)
		r.name = Instance.new("TextLabel", ESPGui)
		r.name.BackgroundTransparency = 1
		r.name.Font = Enum.Font.GothamBold; r.name.TextSize = 12
		r.name.TextStrokeTransparency = 0.3
		r.name.TextXAlignment = Enum.TextXAlignment.Center
		r.dist = Instance.new("TextLabel", ESPGui)
		r.dist.BackgroundTransparency = 1
		r.dist.Font = Enum.Font.GothamBold; r.dist.TextSize = 11
		r.dist.TextStrokeTransparency = 0.3
		r.dist.TextXAlignment = Enum.TextXAlignment.Center
		r.hl = Instance.new("Highlight")          -- v6 FIX: parent it so it renders
		r.hl.Name = "BC_HL"
		r.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		r.hl.Parent = ESPGui
		espRecords[t] = r
	end
	return r
end
local function espClear()
	for t, r in pairs(espRecords) do
		for _, k in ipairs({"box", "barBg", "name", "dist", "hl"}) do
			if r[k] and r[k].Parent then r[k]:Destroy() end
		end
	end
	espRecords = {}
end
local chamsCache = {}
local function applyChams(t)
	for _, p in ipairs(t:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			if not chamsCache[p] then chamsCache[p] = { Material = p.Material, Color = p.Color } end
			p.Material = Enum.Material[espChamsMat] or Enum.Material.Neon
			p.Color = espChamsColor
		end
	end
end
local function restoreChams()
	for p, c in pairs(chamsCache) do
		if p and p.Parent then p.Material = c.Material; p.Color = c.Color end
	end
	chamsCache = {}
end
local texCache = {}
local texConn = nil
local function texApplyPart(p)
	if not p:IsA("BasePart") then return end
	if not texViewModel then
		local vms = Workspace:FindFirstChild("ViewModels")
		if vms and p:IsDescendantOf(vms) then return end
		if camera and p:IsDescendantOf(camera) then return end
		local node = p
		while node and node ~= Workspace do
			if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then return end
			node = node.Parent
		end
	end
	if not texCache[p] then texCache[p] = { Material = p.Material, Color = p.Color } end
	p.Material = Enum.Material[texMat] or p.Material
	p.Color = texColor
end
local function texEnable()
	texCache = {}
	task.spawn(function()
		local list = Workspace:GetDescendants()
		for i = 1, #list do
			if texOn then texApplyPart(list[i]) end
			if i % 800 == 0 then task.wait() end
		end
	end)
	if texConn then texConn:Disconnect() end
	texConn = Workspace.DescendantAdded:Connect(function(p)
		if texOn then task.defer(texApplyPart, p) end
	end)
end
local function texDisable()
	if texConn then texConn:Disconnect() texConn = nil end
	for p, c in pairs(texCache) do
		if p and p.Parent then p.Material = c.Material; p.Color = c.Color end
	end
	texCache = {}
end
local function spawnDeathFx(pos)
	if deathFxType == "Explosion" then
		local e = Instance.new("Explosion")
		e.Position = pos; e.BlastRadius = 0; e.BlastPressure = 0; e.DestroyJointRadiusPercent = 0
		e.Parent = Workspace
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true; part.CanCollide = false; part.CanQuery = false; part.CanTouch = false
	part.Transparency = 1; part.Size = Vector3.new(1,1,1); part.CFrame = CFrame.new(pos); part.Parent = Workspace
	local att = Instance.new("Attachment", part)
	local em = Instance.new("ParticleEmitter", att)
	em.Color = ColorSequence.new(deathFxColor)
	em.Lifetime = NumberRange.new(0.4, 0.9)
	em.Speed = NumberRange.new(12, 28)
	em.Rate = 0
	em.SpreadAngle = Vector2.new(180, 180)
	em.Size = NumberSequence.new(1.5)
	em.LightEmission = 1
	if deathFxType == "Fire" then em.Texture = "rbxasset://textures/particles/fire_main.dds"
	elseif deathFxType == "Sparkles" then em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	else em.Texture = "rbxasset://textures/particles/smoke_main.dds" end
	em:Emit(45)
	task.delay(1.3, function() if part and part.Parent then part:Destroy() end end)
end
local function hookDeath(hum, char)
	hum.Died:Connect(function()
		if not deathFxOn then return end
		local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
		if root then spawnDeathFx(root.Position) end
	end)
end
local function watchDeaths()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			local h = plr.Character:FindFirstChildOfClass("Humanoid")
			if h then hookDeath(h, plr.Character) end
		end
		plr.CharacterAdded:Connect(function(char)
			local h = char:WaitForChild("Humanoid", 6)
			if h then hookDeath(h, char) end
		end)
	end
	local folder = Workspace:FindFirstChild("TestTargets")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			local h = m:FindFirstChildOfClass("Humanoid")
			if h then hookDeath(h, m) end
		end
	end
end
Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		local h = char:WaitForChild("Humanoid", 6)
		if h then hookDeath(h, char) end
	end)
end)

-- ================= UI: AIM =================
local ag = AimTab:AddLeftGroupbox("Camera Lock (sandbox)")
ag:AddLabel("Rotates YOUR local camera toward sandbox targets. No input injection, no firing, no networking.", true)
ag:AddToggle("aim_on", { Text = "Camera Target Lock", Default = false, Callback = function(v) aimOn = v end })
:AddKeyPicker("aim_key", { Default = "Q", Mode = "Hold", SyncToggleState = false, Text = "Lock key" })
ag:AddToggle("aim_needkey", { Text = "Require Key", Default = true, Callback = function(v) aimNeedKey = v end })
ag:AddDropdown("aim_part", { Values = {"Head", "HumanoidRootPart", "UpperTorso", "Closest Part"}, Default = "Head", Text = "Target Part", Callback = function(v) aimPart = v end })
ag:AddDropdown("aim_priority", { Values = {"Closest Screen", "Closest World", "Lowest HP"}, Default = "Closest Screen", Text = "Priority", Callback = function(v) aimPriority = v end })
ag:AddSlider("aim_fov", { Text = "FOV Radius", Min = 25, Max = 800, Default = 200, Rounding = 0, Suffix = "px", Callback = function(v) aimFov = v FovCircle.Size = UDim2.new(0, v * 2, 0, v * 2) end })
ag:AddSlider("aim_smooth", { Text = "Smoothness", Min = 0.02, Max = 1, Default = 0.2, Rounding = 2, Callback = function(v) aimSmooth = v end })
ag:AddSlider("aim_turncap", { Text = "Turn Speed Cap", Min = 0, Max = 720, Default = 0, Rounding = 0, Suffix = "deg/s", Callback = function(v) aimTurnCap = v end })
ag:AddSlider("aim_delay", { Text = "Reaction Delay", Min = 0, Max = 500, Default = 0, Rounding = 0, Suffix = "ms", Callback = function(v) aimDelayMs = v end })
ag:AddSlider("aim_maxdist", { Text = "Max Distance", Min = 50, Max = 5000, Default = 1200, Rounding = 0, Suffix = "st", Callback = function(v) aimMaxDist = v end })
ag:AddToggle("aim_wall", { Text = "Wall Check", Default = false, Callback = function(v) aimWall = v end })
ag:AddToggle("aim_predict", { Text = "Motion Prediction", Default = false, Callback = function(v) aimPredict = v end })
ag:AddSlider("aim_predscale", { Text = "Prediction Scale", Min = 0, Max = 3, Default = 1, Rounding = 2, Callback = function(v) aimPredScale = v end })
ag:AddToggle("aim_marker", { Text = "Target Marker", Default = true, Callback = function(v) aimMarkerOn = v if not v then TargetMarker.Visible = false end end })
ag:AddDropdown("aim_feed", { Values = {"None", "Hit", "Kill"}, Default = "None", Text = "Lock Feedback Sound", Callback = function(v) aimFeed = v end })
local afg = AimTab:AddRightGroupbox("FOV Circle")
afg:AddToggle("aim_fovshow", { Text = "Show FOV Circle", Default = false, Callback = function(v) FovCircle.Visible = v end })
:AddColorPicker("aim_fovcolor", { Default = Color3.fromRGB(120, 170, 255), Title = "FOV Color", Callback = function(c) FovStroke.Color = c end })
afg:AddToggle("aim_fovfill", { Text = "FOV Fill", Default = false, Callback = function(v)
	FovFillGrad.Transparency = v and NumberSequence.new(0.75) or NumberSequence.new(1)
	FovCircle.BackgroundColor3 = FovStroke.Color
end })
afg:AddSlider("aim_fovthick", { Text = "Thickness", Min = 1, Max = 8, Default = 1, Rounding = 0, Callback = function(v) FovStroke.Thickness = v end })
afg:AddSlider("aim_fovrot", { Text = "Rotation Speed", Min = 0, Max = 360, Default = 0, Rounding = 0, Suffix = "deg/s", Callback = function() end })

-- ================= UI: ESP =================
local eg = EspTab:AddLeftGroupbox("ESP (this place only)")
eg:AddLabel("Visualizes TestTargets dummies and characters inside THIS place.", true)
eg:AddToggle("esp_on", { Text = "ESP", Default = false, Callback = function(v) espOn = v if not v then espClear() restoreChams() end end })
eg:AddToggle("esp_team", { Text = "Ignore Same Team", Default = false, Callback = function(v) espTeam = v end })
eg:AddToggle("esp_box", { Text = "2D Box", Default = true, Callback = function(v) espBox = v end })
:AddColorPicker("esp_boxcolor", { Default = Color3.new(1,1,1), Title = "Box Color", Callback = function(c) espBoxColor = c end })
eg:AddToggle("esp_health", { Text = "Health Bar", Default = true, Callback = function(v) espHealth = v end })
eg:AddSlider("esp_barwidth", { Text = "Bar Width", Min = 2, Max = 10, Default = 4, Rounding = 0, Callback = function(v) espBarWidth = v end })
eg:AddToggle("esp_name", { Text = "Name", Default = true, Callback = function(v) espName = v end })
eg:AddToggle("esp_dist", { Text = "Distance", Default = true, Callback = function(v) espDist = v end })
eg:AddToggle("esp_high", { Text = "Highlight", Default = true, Callback = function(v) espHigh = v end })
:AddColorPicker("esp_highcolor", { Default = Color3.fromRGB(90, 150, 255), Title = "Highlight Color", Callback = function(c) espHighFill = c end })
eg:AddToggle("esp_chams", { Text = "Target Chams", Default = false, Callback = function(v) espChams = v if not v then restoreChams() end end })
eg:AddDropdown("esp_chamsmat", { Values = {"Neon", "ForceField", "Glass", "Metal", "SmoothPlastic"}, Default = "Neon", Text = "Chams Material", Callback = function(v) espChamsMat = v end })
eg:AddLabel("Chams Color"):AddColorPicker("esp_chamscolor", { Default = Color3.fromRGB(120, 190, 255), Title = "Chams Color", Callback = function(c) espChamsColor = c end })
eg:AddSlider("esp_maxdist", { Text = "Max Distance", Min = 100, Max = 10000, Default = 2500, Rounding = 0, Suffix = "st", Callback = function(v) espMaxDist = v end })
eg:AddButton({ Text = "Refresh ESP", Func = function() espClear() restoreChams() end })

-- ================= UI: VISUALS =================
local GRADES = {
	Normal = {0,0,0, Color3.new(1,1,1)},
	Cinematic = {-0.02,0.22,-0.08, Color3.fromRGB(235,240,255)},
	Cold = {0,0.12,0.05, Color3.fromRGB(190,220,255)},
	Warm = {0.02,0.08,0.18, Color3.fromRGB(255,225,190)},
	Neon = {0.03,0.25,0.45, Color3.fromRGB(220,255,240)},
	Vaporwave = {0.04,0.18,0.3, Color3.fromRGB(255,190,240)},
	Horror = {-0.12,0.35,-0.5, Color3.fromRGB(180,200,190)},
	Mono = {0,0.15,-1, Color3.new(1,1,1)},
	CozyNight = {0.02,0.12,0.05, Color3.fromRGB(255,214,170)},
	GoldenHour = {0.05,0.18,0.25, Color3.fromRGB(255,190,120)},
}
local gradeNames = {} for n in pairs(GRADES) do table.insert(gradeNames, n) end table.sort(gradeNames)
local vg = VisualsTab:AddLeftGroupbox("Master & Grade")
vg:AddToggle("v_enabled", { Text = "Visuals Enabled", Default = true, Callback = function(v) visualsEnabled = v applyWeather() end })
vg:AddDropdown("v_grade", { Values = gradeNames, Default = "Normal", Text = "Grade Preset", Callback = function(n)
	local g = GRADES[n] or GRADES.Normal
	cc.Enabled = true
	cc.Brightness, cc.Contrast, cc.Saturation, cc.TintColor = g[1], g[2], g[3], g[4]
end })
vg:AddSlider("v_bright", { Text = "Brightness", Min = -0.5, Max = 0.5, Default = 0, Rounding = 2, Callback = function(v) cc.Enabled = true cc.Brightness = v end })
vg:AddSlider("v_contrast", { Text = "Contrast", Min = -1, Max = 1, Default = 0, Rounding = 2, Callback = function(v) cc.Enabled = true cc.Contrast = v end })
vg:AddSlider("v_sat", { Text = "Saturation", Min = -1, Max = 2, Default = 0, Rounding = 2, Callback = function(v) cc.Enabled = true cc.Saturation = v end })
vg:AddToggle("v_tint_on", { Text = "Tint Override", Default = false, Callback = function(v) if v then cc.Enabled = true cc.TintColor = Options.v_tint.Value end end })
:AddColorPicker("v_tint", { Default = Color3.new(1,1,1), Title = "Tint", Callback = function(c) if Toggles.v_tint_on.Value then cc.Enabled = true cc.TintColor = c end end })
vg:AddButton({ Text = "Grade Off", Func = function() cc.Enabled = false end })
local wx = VisualsTab:AddLeftGroupbox("Weather")
wx:AddDropdown("v_weather", { Values = {"Off", "Rain", "Snow", "Storm"}, Default = "Off", Text = "Weather Type", Callback = function(v) weatherType = v applyWeather() end })
wx:AddSlider("v_weatherrate", { Text = "Rate", Min = 10, Max = 400, Default = 100, Rounding = 0, Callback = function(v) weatherRate = v applyWeather() end })
wx:AddLabel("Weather Color"):AddColorPicker("v_weathercolor", { Default = Color3.new(1,1,1), Title = "Weather Color", Callback = function(c) weatherColor = c applyWeather() end })
wx:AddToggle("v_fog", { Text = "Fog / Haze", Default = false, Callback = function(v)
	atmo.Density = (v and visualsEnabled) and 0.32 or 0
	atmo.Haze = (v and visualsEnabled) and 1.2 or 0
end })
local fx = VisualsTab:AddRightGroupbox("Post FX")
fx:AddToggle("v_bloom", { Text = "Bloom", Default = false, Callback = function(v) bloomOn = v bloom.Intensity = (v and visualsEnabled) and Options.v_bloom_i.Value or 0 end })
fx:AddSlider("v_bloom_i", { Text = "Bloom Intensity", Min = 0, Max = 3, Default = 1.15, Rounding = 2, Callback = function(v) if bloomOn then bloom.Intensity = v end end })
fx:AddSlider("v_bloom_size", { Text = "Bloom Size", Min = 2, Max = 64, Default = 24, Rounding = 0, Callback = function(v) bloom.Size = v end })
fx:AddToggle("v_sun", { Text = "Sun Rays", Default = false, Callback = function(v) sunOn = v sunrays.Intensity = (v and visualsEnabled) and Options.v_sun_i.Value or 0 end })
fx:AddSlider("v_sun_i", { Text = "Sun Intensity", Min = 0, Max = 0.5, Default = 0.12, Rounding = 2, Callback = function(v) if sunOn then sunrays.Intensity = v end end })
fx:AddToggle("v_dof", { Text = "Depth Of Field", Default = false, Callback = function(v) dofOn = v doffx.FarIntensity = (v and visualsEnabled) and 0.18 or 0 doffx.NearIntensity = (v and visualsEnabled) and 0.08 or 0 end })
fx:AddSlider("v_dof_focus", { Text = "DOF Focus", Min = 5, Max = 100, Default = 25, Rounding = 0, Callback = function(v) doffx.FocusDistance = v end })
fx:AddToggle("v_blur", { Text = "Screen Blur", Default = false, Callback = function(v) blurOn = v baseBlur = (v and visualsEnabled) and Options.v_blur_size.Value or 0 end })
fx:AddSlider("v_blur_size", { Text = "Blur Size", Min = 0, Max = 24, Default = 6, Rounding = 0, Callback = function(v) if blurOn then baseBlur = v end end })
fx:AddToggle("v_motionblur", { Text = "Motion Blur", Default = false, Callback = function(v) motionBlurOn = v end })
fx:AddSlider("v_mb_int", { Text = "Motion Blur Intensity", Min = 0, Max = 1, Default = 0.5, Rounding = 2, Callback = function(v) motionBlurInt = v end })
fx:AddSlider("v_mb_sens", { Text = "Motion Blur Sensitivity", Min = 0.1, Max = 3, Default = 1, Rounding = 2, Callback = function(v) motionBlurSens = v end })
fx:AddToggle("v_vignette", { Text = "Vignette", Default = false, Callback = function(v) vigOn = v if not v then VigStroke.Transparency = 1 end end })
fx:AddSlider("v_vig_str", { Text = "Vignette Strength", Min = 0, Max = 1, Default = 0.5, Rounding = 2, Callback = function(v) vigStrength = v if vigOn then VigStroke.Transparency = 1 - v end end })
fx:AddToggle("v_grain", { Text = "Film Grain", Default = false, Callback = function(v) grainOn = v Grain.TextTransparency = (v and visualsEnabled) and 0.86 or 1 end })
fx:AddToggle("v_cycle", { Text = "Color Cycle", Default = false, Callback = function(v) cycleOn = v end })
fx:AddToggle("v_pulse", { Text = "Bloom Pulse", Default = false, Callback = function(v) pulseOn = v end })
fx:AddToggle("v_sway", { Text = "Camera Sway", Default = false, Callback = function(v) swayOn = v end })
local cz = VisualsTab:AddRightGroupbox("Cozy")
cz:AddToggle("v_fireflies", { Text = "Fireflies", Default = false, Callback = function(v)
	cozyFireflies = v
	if v and not fireflyPart then fireflyPart = makeAmbientParticle("Fireflies") end
	if not v and fireflyPart then fireflyPart:Destroy() fireflyPart = nil end
end })
cz:AddToggle("v_dust", { Text = "Dust Motes", Default = false, Callback = function(v)
	cozyDust = v
	if v and not dustPart then dustPart = makeAmbientParticle("Dust") end
	if not v and dustPart then dustPart:Destroy() dustPart = nil end
end })
cz:AddToggle("v_lantern", { Text = "Lantern Light", Default = false, Callback = function(v)
	cozyLantern = v
	if v and not lantern and camera then
		lantern = Instance.new("PointLight", camera)
		lantern.Color = Color3.fromRGB(255, 190, 110); lantern.Brightness = 1.4; lantern.Range = 14
	end
	if not v and lantern then lantern:Destroy() lantern = nil end
end })
cz:AddToggle("v_breathe", { Text = "Bloom Breathing", Default = false, Callback = function(v) cozyBreathe = v end })
cz:AddButton({ Text = "Make It Cozy", Func = function()
	Options.v_grade:SetValue("CozyNight")
	Toggles.v_fireflies:SetValue(true)
	Toggles.v_dust:SetValue(true)
	Toggles.v_lantern:SetValue(true)
	Toggles.v_breathe:SetValue(true)
	Options.v_vig_str:SetValue(0.45)
	Toggles.v_vignette:SetValue(true)
	Library:Notify("Cozy mode enabled.", 3)
end })
cz:AddButton({ Text = "Reset All Visuals", Func = function()
	cc.Enabled = false
	bloom.Intensity = 0; sunrays.Intensity = 0; blurfx.Size = 0
	doffx.FarIntensity = 0; doffx.NearIntensity = 0
	atmo.Density = 0; atmo.Haze = 0; atmo.Glare = 0
	VigStroke.Transparency = 1; Grain.TextTransparency = 1; Flash.BackgroundTransparency = 1
	weatherType = "Off"; applyWeather()
	for k, v in pairs(origLighting) do Lighting[k] = v end
	if camera then camera.FieldOfView = origCamFov end
	Library:Notify("Visuals reset.", 2)
end })

-- ================= UI: WORLD =================
local SKY_PRESETS = {
	Aurora = {"116533337330584","80054106187171","94459139270943","116368999680791","125758104196312","107060226443967"},
	Battlerock = {"131136284306917","89505977207531","140099243548102","121676169821100","97183886241447","107128620201556"},
	Clockwork = {"86284761193226","111425663631622","115606366886873","127287488325060","126844150113423","74510789204352"},
	DarkMatter = {"97629693450922","97898396690232","134755033418084","118219143707956","114940065588775","95430908943263"},
	Ghostly = {"111506743048183","86198196348228","86265514167302","100257959405445","71935101953120","132011089223498"},
	MeltyMolten = {"131463907527649","116154164311420","113077689016278","79984367513909","82395195737484","117530106700350"},
	SweetMystery = {"107264897520277","135637946277638","135705252786048","119667604517747","75904303027092","97011146822716"},
	TerraceDome = {"98684100016510","108354040356521","95723629635852","106269064939837","136234415079744","75385962780878"},
}
local skyNames = {} for n in pairs(SKY_PRESETS) do table.insert(skyNames, n) end table.sort(skyNames)
local origSky, labSky = nil, nil
local function applySky(name)
	local ids = SKY_PRESETS[name]
	if not ids then return end
	if not origSky then
		local cur = Lighting:FindFirstChildOfClass("Sky")
		origSky = cur and cur:Clone() or false
	end
	if not labSky or not labSky.Parent then
		labSky = Instance.new("Sky"); labSky.Name = "BC_Sky"; labSky.Parent = Lighting
	end
	labSky.SkyboxBk = "rbxassetid://" .. ids[1]
	labSky.SkyboxDn = "rbxassetid://" .. ids[2]
	labSky.SkyboxFt = "rbxassetid://" .. ids[3]
	labSky.SkyboxLf = "rbxassetid://" .. ids[4]
	labSky.SkyboxRt = "rbxassetid://" .. ids[5]
	labSky.SkyboxUp = "rbxassetid://" .. ids[6]
end
local function restoreSky()
	if labSky then labSky:Destroy() labSky = nil end
	if origSky and origSky ~= false and not origSky.Parent then origSky:Clone().Parent = Lighting end
end
local skyRotTick = 0
local ws = WorldTab:AddLeftGroupbox("Skybox")
ws:AddToggle("w_sky_on", { Text = "Skybox Enabled", Default = false, Callback = function(v) skyOn = v if v then applySky(Options.w_sky_preset.Value) else restoreSky() end end })
ws:AddDropdown("w_sky_preset", { Values = skyNames, Default = "Aurora", Text = "Preset", Callback = function(n) if skyOn then applySky(n) end end })
ws:AddSlider("w_stars", { Text = "Star Count", Min = 0, Max = 10000, Default = 3000, Rounding = 0, Callback = function(v) if labSky then labSky.StarCount = v end end })
ws:AddSlider("w_sunsize", { Text = "Sun Size", Min = 0, Max = 60, Default = 21, Rounding = 0, Callback = function(v) if labSky then labSky.SunAngularSize = v end end })
ws:AddToggle("w_rotate", { Text = "Sky Rotator", Default = false, Callback = function(v) skyRotate = v end })
ws:AddSlider("w_rotspeed", { Text = "Rotation Speed", Min = 0.1, Max = 100, Default = 1, Rounding = 1, Callback = function(v) skyRotSpeed = v end })
ws:AddDropdown("w_rotmethod", { Values = {"Spin", "Wave", "Alternate"}, Default = "Spin", Text = "Method", Callback = function(v) skyRotMethod = v end })
ws:AddDropdown("w_rotdir", { Values = {"Horizontal", "Vertical", "Diagonal"}, Default = "Horizontal", Text = "Direction", Callback = function(v) skyRotDir = v end })
local wl = WorldTab:AddRightGroupbox("Lighting")
wl:AddSlider("w_clock", { Text = "Clock Time", Min = 0, Max = 24, Default = Lighting.ClockTime, Rounding = 1, Callback = function(v) Lighting.ClockTime = v end })
wl:AddSlider("w_bright", { Text = "Brightness", Min = 0, Max = 10, Default = Lighting.Brightness, Rounding = 2, Callback = function(v) Lighting.Brightness = v end })
wl:AddSlider("w_exposure", { Text = "Exposure", Min = -3, Max = 3, Default = Lighting.ExposureCompensation, Rounding = 2, Callback = function(v) Lighting.ExposureCompensation = v end })
wl:AddToggle("w_amb_on", { Text = "Custom Ambient", Default = false, Callback = function(v) if v then Lighting.Ambient = Options.w_ambient.Value Lighting.OutdoorAmbient = Options.w_outdoor.Value end end })
:AddColorPicker("w_ambient", { Default = Lighting.Ambient, Title = "Ambient", Callback = function(c) if Toggles.w_amb_on.Value then Lighting.Ambient = c end end })
:AddColorPicker("w_outdoor", { Default = Lighting.OutdoorAmbient, Title = "Outdoor", Callback = function(c) if Toggles.w_amb_on.Value then Lighting.OutdoorAmbient = c end end })
wl:AddDropdown("w_tech", { Values = {"Future", "ShadowMaps", "Voxel", "Compatibility"}, Default = "Future", Text = "Technology", Callback = function(n) pcall(function() Lighting.Technology = Enum.LightingTechnology[n] end) end })
wl:AddToggle("w_shadows", { Text = "Global Shadows", Default = Lighting.GlobalShadows, Callback = function(v) Lighting.GlobalShadows = v end })
wl:AddButton({ Text = "Restore Lighting", Func = function() for k, v in pairs(origLighting) do Lighting[k] = v end end })
local wc = WorldTab:AddLeftGroupbox("Camera & Screen")
wc:AddToggle("w_fov_on", { Text = "FOV Changer", Default = false, Callback = function(v) fovChangerOn = v if not v and camera then camera.FieldOfView = origCamFov end end })
wc:AddSlider("w_fov", { Text = "FOV", Min = 10, Max = 140, Default = 80, Rounding = 0, Callback = function(v) fovChangerVal = v end })
wc:AddToggle("w_stretch", { Text = "Stretched Res", Default = false, Callback = function(v) stretchedOn = v end })
wc:AddSlider("w_stretch_amt", { Text = "Stretch Amount", Min = 0.1, Max = 1, Default = 0.2, Rounding = 2, Callback = function(v) stretchedAmt = v end })
local wt = WorldTab:AddRightGroupbox("World Textures")
wt:AddLabel("Overrides materials/colors of world parts on YOUR client only.", true)
wt:AddToggle("w_tex_on", { Text = "Override Textures", Default = false, Callback = function(v) texOn = v if v then texEnable() else texDisable() end end })
wt:AddDropdown("w_tex_mat", { Values = {"Brick","Cobblestone","Concrete","Metal","Neon","Glass","ForceField","Wood","WoodPlanks","Marble","Slate","Sand","Ice","Grass"}, Default = "Brick", Text = "Material", Callback = function(v) texMat = v if texOn then texDisable() texEnable() end end })
wt:AddLabel("Override Color"):AddColorPicker("w_tex_color", { Default = Color3.fromRGB(244, 244, 244), Title = "Texture Color", Callback = function(c) texColor = c if texOn then texDisable() texEnable() end end })
wt:AddToggle("w_tex_vm", { Text = "Include Viewmodel", Default = false, Callback = function(v) texViewModel = v end })
local wd = WorldTab:AddRightGroupbox("Death Effects")
wd:AddToggle("w_death_on", { Text = "Death Effects", Default = false, Callback = function(v) deathFxOn = v end })
wd:AddDropdown("w_death_type", { Values = {"Explosion", "Fire", "Sparkles", "Neon Burst"}, Default = "Sparkles", Text = "Effect", Callback = function(v) deathFxType = v end })
wd:AddLabel("Effect Color"):AddColorPicker("w_death_color", { Default = Color3.fromRGB(120, 81, 166), Title = "Death Color", Callback = function(c) deathFxColor = c end })
watchDeaths()

-- ================= UI: CHARACTER =================
local skinCache = {}
local function partGroup(n)
	if n == "Head" then return "head" end
	if n == "UpperTorso" or n == "LowerTorso" or n == "Torso" then return "torso" end
	if n:find("Arm") or n:find("Hand") then return "arms" end
	if n:find("Leg") or n:find("Foot") then return "legs" end
	return nil
end
local skinColorsOn, skinMatOn, skinTranspOn, skinNeonOn = false, false, false, false
local function applyLocalSkin()
	local char = LocalPlayer.Character
	if not char then return end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			if not skinCache[p] then skinCache[p] = { Color = p.Color, Material = p.Material, Transparency = p.Transparency } end
			local g = partGroup(p.Name)
			if g and skinColorsOn then
				local picker = Options["skin_" .. g]
				if picker then p.Color = picker.Value end
			end
			if skinMatOn then p.Material = Enum.Material[Options.skin_mat_val.Value] or p.Material end
			if skinTranspOn then p.Transparency = Options.skin_transp_val.Value end
			if skinNeonOn then p.Material = Enum.Material.Neon end
		end
	end
end
local function restoreSkin()
	local char = LocalPlayer.Character
	if not char then return end
	for _, p in ipairs(char:GetDescendants()) do
		local c = skinCache[p]
		if c and p:IsA("BasePart") then p.Color = c.Color; p.Material = c.Material; p.Transparency = c.Transparency end
	end
end
local vmCache = {}
local vmOn = false
local function tintViewmodel(on)
	local vms = Workspace:FindFirstChild("ViewModels")
	if not vms and camera then vms = camera:FindFirstChild("ViewModels") end
	if not vms then
		if on then Library:Notify("No viewmodel folder found (normal outside a Rivals-style place).", 3) end
		return
	end
	for _, model in ipairs(vms:GetChildren()) do
		if model:IsA("Model") and model.Name:sub(1, #LocalPlayer.Name) == LocalPlayer.Name then
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then
					if not vmCache[p] then vmCache[p] = { Color = p.Color, Material = p.Material } end
					if on then
						p.Color = Options.vm_color.Value
						p.Material = Enum.Material[Options.vm_mat_val.Value] or p.Material
					else
						p.Color = vmCache[p].Color; p.Material = vmCache[p].Material
					end
				end
			end
		end
	end
end
local TEST_SKINS = {
	Default = { Enum.Material.SmoothPlastic, nil },
	Red = { Enum.Material.SmoothPlastic, Color3.fromRGB(220, 60, 60) },
	Blue = { Enum.Material.SmoothPlastic, Color3.fromRGB(60, 120, 230) },
	Gold = { Enum.Material.Metal, Color3.fromRGB(255, 200, 60) },
	Neon = { Enum.Material.Neon, Color3.fromRGB(80, 255, 180) },
}
local cfxRefs = {}
local function clearCharFx()
	for _, o in pairs(cfxRefs) do if o and o.Parent then pcall(function() o:Destroy() end) end end
	cfxRefs = {}
end
local function applyCharFx()
	clearCharFx()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if Toggles.cfx_trail.Value then
		local a0 = Instance.new("Attachment", root); a0.Position = Vector3.new(0, 1.5, 0)
		local a1 = Instance.new("Attachment", root); a1.Position = Vector3.new(0, -1.5, 0)
		local tr = Instance.new("Trail", root)
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Lifetime = 0.6; tr.LightEmission = 1
		tr.Color = ColorSequence.new(Options.cfx_trail_a.Value, Options.cfx_trail_b.Value)
		cfxRefs.trail, cfxRefs.a0, cfxRefs.a1 = tr, a0, a1
	end
	if Toggles.cfx_fire.Value then
		local f = Instance.new("Fire", root); f.Size = 8; f.Color = Options.cfx_fire_c.Value
		cfxRefs.fire = f
	end
	if Toggles.cfx_spark.Value then
		local s = Instance.new("Sparkles", root); s.SparkleColor = Options.cfx_spark_c.Value
		cfxRefs.spark = s
	end
	if Toggles.cfx_glow.Value then
		local pl = Instance.new("PointLight", root)
		pl.Color = Options.cfx_glow_c.Value; pl.Brightness = 2; pl.Range = 12
		cfxRefs.glow = pl
	end
end
local ANIMS = {
	Default = {507766388, 10921541949, 10899968825, 507765000, 507767968, 507765644},
	Zombie = {10921344533, 10921355261, 616163682, 10921351278, 10921350320, 10921343576},
	Ninja = {10921155160, 10921162768, 10921157929, 10921160088, 10921159222, 10921154678},
	Vampire = {10921315373, 10921326949, 10921320299, 10921322186, 10921321317, 10921314188},
	Stylish = {10921272275, 10921283326, 10921276116, 10921279832, 10921278648, 10921271391},
	Pirate = {750781874, 750785693, 750783738, 750782230, 750780242, 750779899},
}
local chosenAnim = "Default"
local function applyAnims(char)
	local set = ANIMS[chosenAnim]
	local animate = char and char:FindFirstChild("Animate")
	if not set or not animate then return end
	local function setAnim(folder, child, id)
		local fo = animate:FindFirstChild(folder)
		local an = fo and fo:FindFirstChild(child)
		if an and an:IsA("Animation") then an.AnimationId = "rbxassetid://" .. id end
	end
	setAnim("idle", "Animation1", set[1]); setAnim("idle", "Animation2", set[1])
	setAnim("walk", "WalkAnim", set[2]); setAnim("run", "RunAnim", set[3])
	setAnim("jump", "JumpAnim", set[4]); setAnim("fall", "FallAnim", set[5])
	setAnim("climb", "ClimbAnim", set[6])
end
LocalPlayer.CharacterAdded:Connect(function(char)
	skinCache = {}
	task.delay(0.3, function() if skinColorsOn or skinMatOn or skinNeonOn then applyLocalSkin() end end)
	task.delay(0.4, applyCharFx)
	task.delay(0.5, function() applyAnims(char) end)
end)
local sg = CharTab:AddLeftGroupbox("Local Skin Changer")
sg:AddLabel("Recolors YOUR OWN character on YOUR client. No ownership hooks, no remotes.", true)
sg:AddToggle("skin_colors", { Text = "Custom Part Colors", Default = false, Callback = function(v) skinColorsOn = v if v then applyLocalSkin() else restoreSkin() end end })
:AddColorPicker("skin_head", { Default = Color3.fromRGB(245, 205, 48), Title = "Head", Callback = function() if skinColorsOn then applyLocalSkin() end end })
:AddColorPicker("skin_torso", { Default = Color3.fromRGB(90, 140, 220), Title = "Torso", Callback = function() if skinColorsOn then applyLocalSkin() end end })
:AddColorPicker("skin_arms", { Default = Color3.fromRGB(245, 205, 48), Title = "Arms", Callback = function() if skinColorsOn then applyLocalSkin() end end })
:AddColorPicker("skin_legs", { Default = Color3.fromRGB(90, 180, 120), Title = "Legs", Callback = function() if skinColorsOn then applyLocalSkin() end end })
sg:AddToggle("skin_mat", { Text = "Override Material", Default = false, Callback = function(v) skinMatOn = v if v then applyLocalSkin() else restoreSkin() end end })
sg:AddDropdown("skin_mat_val", { Values = {"SmoothPlastic","Neon","Metal","Glass","ForceField","WoodPlanks","Marble"}, Default = "SmoothPlastic", Text = "Material", Callback = function() if skinMatOn then applyLocalSkin() end end })
sg:AddToggle("skin_transp", { Text = "Body Transparency", Default = false, Callback = function(v) skinTranspOn = v if v then applyLocalSkin() else restoreSkin() end end })
sg:AddSlider("skin_transp_val", { Text = "Transparency", Min = 0, Max = 1, Default = 0.5, Rounding = 2, Callback = function() if skinTranspOn then applyLocalSkin() end end })
sg:AddToggle("skin_neon", { Text = "Neon Body", Default = false, Callback = function(v) skinNeonOn = v if v then applyLocalSkin() else restoreSkin() end end })
sg:AddButton({ Text = "Re-apply Now", Func = applyLocalSkin })
sg:AddButton({ Text = "Restore Original", Func = function() skinCache = {} restoreSkin() end })
local vmg = CharTab:AddLeftGroupbox("Local Viewmodel Tint")
vmg:AddToggle("vm_tint", { Text = "Tint Viewmodel", Default = false, Callback = function(v) vmOn = v tintViewmodel(v) end })
:AddColorPicker("vm_color", { Default = Color3.fromRGB(181, 126, 220), Title = "Tint Color", Callback = function() if vmOn then tintViewmodel(true) end end })
vmg:AddDropdown("vm_mat_val", { Values = {"Neon","ForceField","Metal","Glass","SmoothPlastic"}, Default = "Neon", Text = "Material", Callback = function() if vmOn then tintViewmodel(true) end end })
vmg:AddButton({ Text = "Re-apply Tint", Func = function() tintViewmodel(true) end })
vmg:AddButton({ Text = "Restore Viewmodel", Func = function() tintViewmodel(false) end })
local qsg = CharTab:AddRightGroupbox("Quick Skins + FX")
qsg:AddDropdown("skin_test", { Values = {"Default","Red","Blue","Gold","Neon"}, Default = "Default", Text = "Test Skin" })
qsg:AddButton({ Text = "Apply Test Skin", Func = function()
	local s = TEST_SKINS[Options.skin_test.Value]
	if not s then return end
	local char = LocalPlayer.Character
	if not char then return end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			if not skinCache[p] then skinCache[p] = { Color = p.Color, Material = p.Material, Transparency = p.Transparency } end
			if s[2] then p.Color = s[2] end
			p.Material = s[1]
		end
	end
end })
qsg:AddToggle("cfx_trail", { Text = "Trail", Default = false, Callback = applyCharFx })
:AddColorPicker("cfx_trail_a", { Default = Color3.fromRGB(120,170,255), Title = "Trail A", Callback = function(c) if cfxRefs.trail then cfxRefs.trail.Color = ColorSequence.new(c, Options.cfx_trail_b.Value) end end })
:AddColorPicker("cfx_trail_b", { Default = Color3.fromRGB(255,120,200), Title = "Trail B", Callback = function(c) if cfxRefs.trail then cfxRefs.trail.Color = ColorSequence.new(Options.cfx_trail_a.Value, c) end end })
qsg:AddToggle("cfx_fire", { Text = "Fire", Default = false, Callback = applyCharFx })
:AddColorPicker("cfx_fire_c", { Default = Color3.fromRGB(255,120,40), Title = "Fire Color", Callback = function(c) if cfxRefs.fire then cfxRefs.fire.Color = c end end })
qsg:AddToggle("cfx_spark", { Text = "Sparkles", Default = false, Callback = applyCharFx })
:AddColorPicker("cfx_spark_c", { Default = Color3.fromRGB(255,255,120), Title = "Sparkle Color", Callback = function(c) if cfxRefs.spark then cfxRefs.spark.SparkleColor = c end end })
qsg:AddToggle("cfx_glow", { Text = "Glow Light", Default = false, Callback = applyCharFx })
:AddColorPicker("cfx_glow_c", { Default = Color3.fromRGB(120,255,170), Title = "Glow Color", Callback = function(c) if cfxRefs.glow then cfxRefs.glow.Color = c end end })
qsg:AddButton({ Text = "Clear Character FX", Func = clearCharFx })
qsg:AddDropdown("skin_anim", { Values = {"Default","Zombie","Ninja","Vampire","Stylish","Pirate"}, Default = "Default", Text = "Animation Set", Callback = function(v)
	chosenAnim = v
	applyAnims(LocalPlayer.Character)
end })

-- ================= UI: AUDIO =================
local AMB = {
	Rain = "rbxassetid://9112858162",
	City = "rbxassetid://238385471",
	WindyDay = "rbxassetid://159798309",
	Thunder = "rbxassetid://9064263922",
	ForestRainNight = "rbxassetid://5356133579",
}
local ambSound, labSound = nil, nil
local agg = AudioTab:AddLeftGroupbox("Ambience (local audio)")
agg:AddLabel("Plays only on your client.", true)
agg:AddToggle("amb_on", { Text = "Enable Ambience", Default = false, Callback = function(v)
	if v then
		if not ambSound then
			ambSound = Instance.new("Sound")
			ambSound.Name = "BC_Ambience"; ambSound.Looped = true
			ambSound.SoundId = AMB[Options.amb_type.Value] or AMB.Rain
			ambSound.Volume = Options.amb_vol.Value
			ambSound.Parent = SoundService
		end
		ambSound:Play()
	elseif ambSound then ambSound:Stop() end
end })
agg:AddDropdown("amb_type", { Values = {"Rain","City","WindyDay","Thunder","ForestRainNight"}, Default = "Rain", Text = "Type", Callback = function(v) if ambSound then ambSound.SoundId = AMB[v] or AMB.Rain end end })
agg:AddSlider("amb_vol", { Text = "Volume", Min = 0, Max = 1, Default = 0.5, Rounding = 2, Callback = function(v) if ambSound then ambSound.Volume = v end end })
local slg = AudioTab:AddRightGroupbox("Sound Lab")
slg:AddInput("snd_custom", { Text = "Custom Asset ID", Default = "", Numeric = true, Finished = true, Callback = function() end })
slg:AddSlider("snd_pitch", { Text = "Pitch", Min = 0.5, Max = 2, Default = 1, Rounding = 2 })
slg:AddButton({ Text = "Play Custom Loop", Func = function()
	local id = tonumber(Options.snd_custom.Value)
	if not id then Library:Notify("Enter a numeric asset id first.", 3) return end
	if not labSound then
		labSound = Instance.new("Sound")
		labSound.Name = "BC_SoundLab"; labSound.Looped = true; labSound.Parent = SoundService
	end
	labSound.SoundId = "rbxassetid://" .. id
	labSound.Volume = Options.amb_vol.Value
	labSound.PlaybackSpeed = Options.snd_pitch.Value
	labSound:Play()
end })
slg:AddButton({ Text = "Stop Loop", Func = function() if labSound then labSound:Stop() end end })

-- ================= UI: PRACTICE =================
local function dummyRoot(m) return m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart end
local function getAnchor(m)
	local a = m:GetAttribute("Anchor")
	if not a then
		local r = dummyRoot(m)
		a = r and r.Position or Vector3.new(0,0,0)
		m:SetAttribute("Anchor", a)
	end
	return a
end
local function spawnDummy()
	local folder = Workspace:FindFirstChild("TestTargets")
	if not folder then
		folder = Instance.new("Folder"); folder.Name = "TestTargets"; folder.Parent = Workspace
	end
	local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local base = myRoot and myRoot.CFrame or CFrame.new(0, 5, 0)
	local push = CFrame.Angles(0, math.rad(math.random(0, 360)), 0) * CFrame.new(0, 0, -math.random(10, 25))
	local m = Instance.new("Model"); m.Name = "BrokeDummy" .. math.random(1000, 9999)
	local r = Instance.new("Part", m)
	r.Name = "HumanoidRootPart"; r.Anchored = true; r.CanCollide = false
	r.Size = Vector3.new(2, 2, 1); r.BrickColor = BrickColor.new("Bright red")
	r.CFrame = base * push
	local hd = Instance.new("Part", m)
	hd.Name = "Head"; hd.Anchored = true; hd.CanCollide = false
	hd.Size = Vector3.new(1.2, 1.2, 1.2); hd.BrickColor = BrickColor.new("Bright yellow")
	hd.CFrame = r.CFrame * CFrame.new(0, 2.4, 0)
	local h = Instance.new("Humanoid", m); h.MaxHealth = 100; h.Health = 100
	m.PrimaryPart = r; m.Parent = folder
	hookDeath(h, m)
	return m
end
local prStats = { shots = 0, hits = 0, hs = 0, kills = 0, deaths = 0, myHP = 100 }
local prStatsLabel = nil
local function prUpdate()
	if not prStatsLabel then return end
	prStatsLabel:SetText(string.format("shots %d | hits %d | acc %.0f%% | HS %d | kills %d | deaths %d | HP %d",
		prStats.shots, prStats.hits,
		(prStats.shots > 0 and (prStats.hits / prStats.shots * 100) or 0),
		prStats.hs, prStats.kills, prStats.deaths, math.max(0, math.floor(prStats.myHP))))
end
local function prDamageNumber(part, text, color)
	local b = Instance.new("BillboardGui")
	b.Adornee = part; b.Size = UDim2.new(0, 80, 0, 30)
	b.StudsOffset = Vector3.new(0, 1.5, 0); b.AlwaysOnTop = true; b.Parent = Overlay
	local l = Instance.new("TextLabel", b)
	l.BackgroundTransparency = 1; l.Size = UDim2.new(1, 0, 1, 0)
	l.Font = Enum.Font.GothamBold; l.TextSize = 16
	l.TextStrokeTransparency = 0.3; l.TextColor3 = color; l.Text = text
	task.delay(0.7, function() if b and b.Parent then b:Destroy() end end)
end
local pg1 = PracticeTab:AddLeftGroupbox("Dummies")
pg1:AddButton({ Text = "Spawn 1 Dummy", Func = function() spawnDummy() Library:Notify("Dummy spawned.", 2) end })
pg1:AddButton({ Text = "Spawn 3 Dummies", Func = function() spawnDummy() spawnDummy() spawnDummy() Library:Notify("3 dummies spawned.", 2) end })
pg1:AddButton({ Text = "Clear Dummies", Func = function()
	local folder = Workspace:FindFirstChild("TestTargets")
	if not folder then return end
	for _, c in ipairs(folder:GetChildren()) do
		if c.Name:sub(1, 10) == "BrokeDummy" or c.Name == "BrokeTrainer" then c:Destroy() end
	end
	espClear()
end })
pg1:AddDropdown("pr_pattern", { Values = {"Off","Strafe","Bounce","Circle","Teleport"}, Default = "Off", Text = "Movement Pattern", Callback = function(v) prPattern = v end })
pg1:AddSlider("pr_speed", { Text = "Pattern Speed", Min = 0.5, Max = 10, Default = 3, Rounding = 1, Callback = function(v) prSpeed = v end })
local pg2 = PracticeTab:AddLeftGroupbox("Hit Registration Trainer")
pg2:AddLabel("Click dummies: your own raycasts register hits, headshots and kills locally.", true)
pg2:AddToggle("pr_hitreg", { Text = "Enable Hit Reg Trainer", Default = false, Callback = function(v) prHitreg = v end })
pg2:AddSlider("pr_damage", { Text = "Base Damage", Min = 1, Max = 100, Default = 34, Rounding = 0 })
pg2:AddSlider("pr_hsmult", { Text = "Headshot Multiplier", Min = 1, Max = 4, Default = 2.5, Rounding = 1, Suffix = "x" })
prStatsLabel = pg2:AddLabel("shots 0 | hits 0 | acc 0% | HS 0 | kills 0 | deaths 0 | HP 100")
pg2:AddButton({ Text = "Reset Round Stats", Func = function()
	prStats.shots = 0; prStats.hits = 0; prStats.hs = 0
	prStats.kills = 0; prStats.deaths = 0; prStats.myHP = 100
	prUpdate()
end })
local pg3 = PracticeTab:AddRightGroupbox("Dummies Shoot Back")
pg3:AddLabel("Simulated return fire: visual tracers + local HP pool + red flash.", true)
pg3:AddToggle("pr_shootback", { Text = "Dummies Shoot Back", Default = false, Callback = function(v) prShootback = v end })
pg3:AddSlider("pr_interval", { Text = "Fire Interval", Min = 0.3, Max = 5, Default = 1.2, Rounding = 1, Suffix = "s", Callback = function(v) prInterval = v end })
pg3:AddSlider("pr_sb_dmg", { Text = "Damage Per Hit", Min = 1, Max = 50, Default = 12, Rounding = 0, Callback = function(v) prDmg = v end })

-- ================= UI: MISC =================
local mg1 = MiscTab:AddLeftGroupbox("Tracer Lab")
mg1:AddLabel("Decorative tracers from YOUR events (lock, click, demo).", true)
mg1:AddToggle("tr_lock", { Text = "Tracer On Lock", Default = false, Callback = function(v) trLock = v end })
:AddColorPicker("tr_a", { Default = Color3.fromRGB(120, 190, 255), Title = "Tracer A", Callback = function(c) trA = c end })
:AddColorPicker("tr_b", { Default = Color3.fromRGB(255, 140, 220), Title = "Tracer B", Callback = function(c) trB = c end })
mg1:AddToggle("tr_click", { Text = "Tracer On Click", Default = false, Callback = function(v) trClick = v end })
mg1:AddToggle("tr_demo", { Text = "Demo Tracers", Default = false, Callback = function(v) trDemo = v end })
mg1:AddSlider("tr_life", { Text = "Lifetime", Min = 0.1, Max = 3, Default = 0.6, Rounding = 2, Suffix = "s", Callback = function(v) trLife = v end })
mg1:AddSlider("tr_thick", { Text = "Thickness", Min = 0.05, Max = 1, Default = 0.15, Rounding = 2, Callback = function(v) trThick = v end })
mg1:AddButton({ Text = "Fire Test Tracer", Func = function()
	if camera then fireTracer(camera.CFrame.Position, camera.CFrame.Position + camera.CFrame.LookVector * 60, trA) end
end })
local mg2 = MiscTab:AddRightGroupbox("Crosshair")
mg2:AddToggle("x_on", { Text = "Custom Crosshair", Default = false, Callback = function(v) crossOn = v rebuildCrosshair() end })
:AddColorPicker("x_color", { Default = Color3.new(1,1,1), Title = "Color", Callback = function(c) crossColor = c rebuildCrosshair() end })
mg2:AddDropdown("x_style", { Values = {"+", "x", "t", "cross"}, Default = "+", Text = "Style", Callback = function(v) crossStyle = v rebuildCrosshair() end })
mg2:AddSlider("x_size", { Text = "Length", Min = 4, Max = 60, Default = 22, Rounding = 0, Callback = function(v) crossSize = v rebuildCrosshair() end })
mg2:AddSlider("x_gap", { Text = "Gap", Min = 0, Max = 30, Default = 5, Rounding = 0, Callback = function(v) crossGap = v rebuildCrosshair() end })
mg2:AddSlider("x_thick", { Text = "Thickness", Min = 1, Max = 10, Default = 2, Rounding = 0, Callback = function(v) crossThick = v rebuildCrosshair() end })
mg2:AddSlider("x_opac", { Text = "Opacity", Min = 0, Max = 1, Default = 1, Rounding = 2, Callback = function(v) crossOpac = v rebuildCrosshair() end })
mg2:AddSlider("x_rotspeed", { Text = "Spin Speed", Min = 0, Max = 720, Default = 0, Rounding = 0, Suffix = "deg/s", Callback = function(v) crossRotSpeed = v end })
mg2:AddToggle("x_dot", { Text = "Center Dot", Default = false, Callback = function(v) crossDot = v rebuildCrosshair() end })
mg2:AddToggle("x_outline", { Text = "Outline", Default = false, Callback = function(v) crossOutline = v rebuildCrosshair() end })
:AddColorPicker("x_outcolor", { Default = Color3.new(0,0,0), Title = "Outline Color", Callback = function(c) crossOutColor = c rebuildCrosshair() end })
mg2:AddToggle("x_rainbow", { Text = "Rainbow", Default = false, Callback = function(v) crossRainbow = v end })
local mg3 = MiscTab:AddLeftGroupbox("HUD")
mg3:AddToggle("hud_on", { Text = "Target HUD", Default = false, Callback = function(v) hudOn = v HudFrame.Visible = v end })
mg3:AddToggle("ind_on", { Text = "On-screen Status List", Default = false, Callback = function(v) indOn = v end })
mg3:AddToggle("wm_on", { Text = "Watermark (fps/ping/clock)", Default = false, Callback = function(v) wmOn = v WmFrame.Visible = v end })

-- ================= UI: SETTINGS =================
local stg = SettingsTab:AddLeftGroupbox("Menu")
stg:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
stg:AddButton({ Text = "Unload", Func = function()
	pcall(function() RunService:UnbindFromRenderStep("BC_Lock") end)
	pcall(function() RunService:UnbindFromRenderStep("BC_Post") end)
	espClear(); restoreChams(); clearCharFx(); texDisable(); restoreSky()
	for _, g in ipairs({Overlay, ESPGui, FovGui, MarkerGui, CrossGui, HudGui, WmGui}) do
		if g and g.Parent then g:Destroy() end
	end
	if weatherPart and weatherPart.Parent then weatherPart:Destroy() end
	if fireflyPart then fireflyPart:Destroy() end
	if dustPart then dustPart:Destroy() end
	if lantern then lantern:Destroy() end
	if ambSound then ambSound:Destroy() end
	if labSound then labSound:Destroy() end
	if thunderSound then thunderSound:Destroy() end
	if dbg and dbg.Parent then dbg:Destroy() end
	if getgenv then getgenv().BrokeUltimateV6 = nil end
	Library:Unload()
end })
Library.ToggleKeybind = Options.MenuKeybind
if SaveManager and ThemeManager then
	SaveManager:SetLibrary(Library)
	SaveManager:IgnoreThemeSettings()
	SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
	ThemeManager:SetLibrary(Library)
	ThemeManager:SetFolder("BrokecheatUltimate/themes")
	SaveManager:SetFolder("BrokecheatUltimate/configs")
	SaveManager:BuildConfigSection(SettingsTab)
	ThemeManager:ApplyToTab(SettingsTab)
	pcall(function() SaveManager:LoadAutoloadConfig() end)
end

-- ================= LOOPS =================
local lockedName = ""
local pendingPart, pendingSince = nil, 0
local lastLook = nil
local fovRot = 0
RunService:BindToRenderStep("BC_Lock", Enum.RenderPriority.Camera.Value + 1, safeStep("lock", function(dt)
	if not camera then return end
	local rotSpeed = Options.aim_fovrot and Options.aim_fovrot.Value or 0
	fovRot = (fovRot + rotSpeed * dt) % 360
	FovStrokeGrad.Rotation = fovRot      -- v6 FIX (was FovStroke.Rotation = crash)
	FovFillGrad.Rotation = fovRot
	local active = aimOn and (not aimNeedKey or (Options.aim_key and Options.aim_key:GetState()))
	if not active then
		lockedName = ""
		pendingPart = nil
		if hudOn then HudText.Text = "target: none" end
		return
	end
	local target, part = pickTarget()
	if part then
		local now = os.clock()
		if part ~= pendingPart then pendingPart, pendingSince = part, now end
		if (now - pendingSince) * 1000 >= aimDelayMs then
			local aimPos = part.Position
			if aimPredict then
				local root = part.Parent and part.Parent:FindFirstChild("HumanoidRootPart")
				if root then
					local dist = (root.Position - camera.CFrame.Position).Magnitude
					aimPos = aimPos + root.AssemblyLinearVelocity * (dist / 1000) * aimPredScale
				end
			end
			local desired = CFrame.lookAt(camera.CFrame.Position, aimPos)
			local s = math.clamp(aimSmooth, 0.02, 1)
			local alpha = 1 - math.pow(1 - s, dt * 60)
			if aimTurnCap > 0 then
				local angle = math.deg(camera.CFrame.LookVector:Angle((aimPos - camera.CFrame.Position).Unit))
				if angle > 0.001 then alpha = math.min(alpha, (aimTurnCap * dt) / angle) end
			end
			camera.CFrame = camera.CFrame:Lerp(desired, alpha)
			local pname = (part.Parent and part.Parent.Name) or "?"
			if pname ~= lockedName then
				lockedName = pname
				if aimFeed ~= "None" then playFeedback(aimFeed) end
				if trLock then fireTracer(camera.CFrame.Position, part.Position, trA) end
			end
			if aimMarkerOn then
				local sp, vis = camera:WorldToViewportPoint(part.Position)
				TargetMarker.Visible = vis and sp.Z > 0
				TargetMarker.Position = UDim2.new(0, sp.X, 0, sp.Y)
				markerStroke.Color = FovStroke.Color
			end
			if hudOn then
				local hum = part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")
				local dist = math.floor((part.Position - camera.CFrame.Position).Magnitude)
				HudText.Text = "target: " .. pname .. "\nhp: " .. (hum and math.floor(hum.Health) or "?") .. "\ndist: " .. dist .. "st"
			end
		end
	else
		pendingPart = nil
		lockedName = ""
		TargetMarker.Visible = false
		if hudOn then HudText.Text = "target: none" end
	end
end))
local sbAccum = 0
RunService:BindToRenderStep("BC_Post", Enum.RenderPriority.Last.Value, safeStep("post", function(dt)
	if not camera then return end
	local mb = 0
	if motionBlurOn then
		local look = camera.CFrame.LookVector
		if lastLook then
			local delta = (look - lastLook).Magnitude
			mb = math.clamp(delta / math.max(dt, 1/240) * motionBlurSens * motionBlurInt * 0.35, 0, 56 * motionBlurInt)
		end
		lastLook = look
	else
		lastLook = camera.CFrame.LookVector
	end
	blurfx.Size = math.max(baseBlur, mb)
	blurfx.Enabled = blurfx.Size > 0.05
	if stretchedOn then
		camera.CFrame = camera.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, stretchedAmt, 0, 0, 0, 1)
	end
	if fovChangerOn then camera.FieldOfView = fovChangerVal end
	if skyRotate and labSky then
		skyRotTick = skyRotTick + dt * skyRotSpeed * 0.5
		local ang = 0
		if skyRotMethod == "Spin" then ang = (skyRotTick * 20) % 360
		elseif skyRotMethod == "Wave" then ang = math.sin(skyRotTick) * 180
		else ang = math.abs((skyRotTick * 40 % 720) - 360) - 180 end
		local v = Vector3.new(0, 0, 0)
		if skyRotDir == "Horizontal" then v = Vector3.new(0, ang, 0)
		elseif skyRotDir == "Vertical" then v = Vector3.new(ang, 0, 0)
		else v = Vector3.new(ang, ang, ang) end
		pcall(function() labSky.SkyboxOrientation = v end)
	end
	weatherPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 22, 0))
	if fireflyPart then fireflyPart.CFrame = camera.CFrame * CFrame.new(0, 0, -9) end
	if dustPart then dustPart.CFrame = camera.CFrame * CFrame.new(0, 0, -6) end
	if crossOn and crossRotSpeed > 0 then
		crossRot = (crossRot + crossRotSpeed * dt) % 360
		crossHolder.Rotation = crossRot     -- v6 FIX (was per-arm rotation)
	end
	if crossRainbow then
		crossColor = Color3.fromHSV((os.clock() * 0.3) % 1, 0.8, 1)
		for _, f in ipairs(crossParts) do if f.ZIndex == 2 then f.BackgroundColor3 = crossColor end end
	end
	if espOn then
		local now = os.clock()
		local doChams = espChams and (now - chamsLast) > 0.25   -- v6 FIX: throttle chams
		if doChams then chamsLast = now end
		for _, t in ipairs(getTargets()) do
			local root = t:FindFirstChild("HumanoidRootPart")
			local hum = t:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				local skip = false
				if espTeam then
					local theirTeam = t:GetAttribute("TeamID")
					local myTeam = LocalPlayer:GetAttribute("TeamID")
					if theirTeam ~= nil and theirTeam == myTeam then skip = true end
				end
				local dist = (camera.CFrame.Position - root.Position).Magnitude
				if dist > espMaxDist then skip = true end
				local r = espEnsure(t)
				if not skip then
					local x, y, w, h = espBounds(root)
					if x then
						r.box.Visible = espBox
						r.box.Position = UDim2.fromOffset(x, y)
						r.box.Size = UDim2.fromOffset(w, h)
						r.boxStroke.Color = espBoxColor
						r.fill.Visible = espBox
						if doChams then applyChams(t) end
						r.hl.Adornee = espHigh and t or nil
						r.hl.Enabled = espHigh
						r.hl.FillColor = espHighFill
						r.hl.FillTransparency = 0.72
						r.hl.OutlineTransparency = 0.05
						local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
						r.barBg.Visible = espHealth
						r.barBg.Position = UDim2.fromOffset(x - espBarWidth - 3, y)
						r.barBg.Size = UDim2.fromOffset(espBarWidth, h)
						r.bar.Size = UDim2.new(1, 0, ratio, 0)
						r.bar.BackgroundColor3 = Color3.fromHSV(ratio * 0.33, 0.8, 1)
						r.name.Visible = espName
						r.name.Text = t.Name
						r.name.Position = UDim2.fromOffset(x, y - 16)
						r.name.Size = UDim2.fromOffset(w, 14)
						r.dist.Visible = espDist
						r.dist.Text = math.floor(dist + 0.5) .. "m"
						r.dist.Position = UDim2.fromOffset(x, y + h + 2)
						r.dist.Size = UDim2.fromOffset(w, 13)
					else
						r.box.Visible = false; r.barBg.Visible = false
						r.name.Visible = false; r.dist.Visible = false
						r.hl.Enabled = false
					end
				else
					r.box.Visible = false; r.barBg.Visible = false
					r.name.Visible = false; r.dist.Visible = false
					r.hl.Enabled = false
				end
			end
		end
		for t, r in pairs(espRecords) do        -- v6 FIX: clean dead records
			if not t.Parent then
				for _, k in ipairs({"box", "barBg", "name", "dist", "hl"}) do
					if r[k] and r[k].Parent then r[k]:Destroy() end
				end
				espRecords[t] = nil
			end
		end
	end
	if prPattern ~= "Off" then
		local folder = Workspace:FindFirstChild("TestTargets")
		if folder then
			local t = os.clock()
			for _, m in ipairs(folder:GetChildren()) do
				if m.Name:sub(1, 10) == "BrokeDummy" then
					local r = dummyRoot(m)
					if r then
						local anchor = getAnchor(m)
						if prPattern == "Strafe" then r.CFrame = CFrame.new(anchor + Vector3.new(math.sin(t * prSpeed) * 6, 0, 0))
						elseif prPattern == "Bounce" then r.CFrame = CFrame.new(anchor + Vector3.new(0, math.abs(math.sin(t * prSpeed)) * 4, 0))
						elseif prPattern == "Circle" then r.CFrame = CFrame.new(anchor + Vector3.new(math.cos(t * prSpeed) * 6, 0, math.sin(t * prSpeed) * 6))
						elseif prPattern == "Teleport" then
							local nextTp = m:GetAttribute("NextTp") or 0
							if t >= nextTp then
								m:SetAttribute("NextTp", t + math.max(0.4, 2.5 - prSpeed * 0.2))
								r.CFrame = CFrame.new(anchor + Vector3.new(math.random(-8, 8), math.random(0, 3), math.random(-8, 8)))
							end
						end
					end
				end
			end
		end
	end
	sbAccum = sbAccum + dt
	if prShootback and sbAccum >= prInterval then
		sbAccum = 0
		local folder = Workspace:FindFirstChild("TestTargets")
		if folder and camera then
			local dummies = {}
			for _, m in ipairs(folder:GetChildren()) do
				if m.Name:sub(1, 10) == "BrokeDummy" then table.insert(dummies, m) end
			end
			if #dummies > 0 then
				local shooter = dummies[math.random(1, #dummies)]
				local head = shooter:FindFirstChild("Head") or shooter:FindFirstChild("HumanoidRootPart")
				local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if head and myRoot and (head.Position - myRoot.Position).Magnitude <= 150 then
					fireTracer(head.Position, camera.CFrame.Position, Color3.fromRGB(255, 90, 90))
					prStats.myHP = prStats.myHP - prDmg
					Flash.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
					Flash.BackgroundTransparency = 0.55
					TweenService:Create(Flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
					if prStats.myHP <= 0 then
						prStats.deaths = prStats.deaths + 1
						prStats.myHP = 100
						Library:Notify("You died in the trainer. HP reset.", 2)
					end
					prUpdate()
				end
			end
		end
	end
	if visualsEnabled then
		if cycleOn then cc.TintColor = Color3.fromHSV((os.clock() * 0.035) % 1, 0.22, 1) cc.Enabled = true end
		if pulseOn and bloomOn then bloom.Intensity = 0.65 + math.sin(os.clock() * 2.2) * 0.35 end
		if cozyBreathe then bloom.Intensity = (bloomOn and Options.v_bloom_i.Value or 0.65) + math.sin(os.clock() * 0.6) * 0.15 end
		if swayOn then camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, math.sin(os.clock() * 1.15) * 0.0015) end
		if grainOn then Grain.Rotation = RNG:NextInteger(-2, 2) end
	end
end))
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if trClick and camera then
			local mouse = LocalPlayer:GetMouse()
			if mouse then fireTracer(camera.CFrame.Position, mouse.Hit.Position, trA) end
		end
		if prHitreg and camera then
			prStats.shots = prStats.shots + 1
			local mouse = LocalPlayer:GetMouse()
			if mouse then
				local dir = mouse.Hit.Position - camera.CFrame.Position
				if dir.Magnitude > 0.001 then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { LocalPlayer.Character }
					local result = Workspace:Raycast(camera.CFrame.Position, dir.Unit * 1000, params)
					if result then
						local model = result.Instance:FindFirstAncestorOfClass("Model")
						if model and (model.Name:sub(1, 10) == "BrokeDummy" or model.Name == "BrokeTrainer") then
							prStats.hits = prStats.hits + 1
							local hs = (result.Instance.Name == "Head")
							if hs then prStats.hs = prStats.hs + 1 end
							local dmg = Options.pr_damage.Value * (hs and Options.pr_hsmult.Value or 1)
							local hp = (model:GetAttribute("HP") or 100) - dmg
							prDamageNumber(result.Instance, tostring(math.floor(dmg)), hs and Color3.fromRGB(255, 160, 60) or Color3.new(1,1,1))
							playFeedback(hs and "Kill" or "Hit")
							if hp <= 0 then
								prStats.kills = prStats.kills + 1
								model:SetAttribute("HP", 100)
								if deathFxOn then spawnDeathFx(result.Instance.Position) end
								local hl = Instance.new("Highlight", model)
								hl.FillColor = Color3.fromRGB(255, 40, 40)
								hl.FillTransparency = 0.4
								task.delay(0.45, function() if hl and hl.Parent then hl:Destroy() end end)
							else
								model:SetAttribute("HP", hp)
							end
						end
					end
				end
			end
			prUpdate()
		end
	end
end)
task.spawn(function()
	local flip = false
	while true do
		task.wait(0.35)
		if trDemo and camera then
			flip = not flip
			local origin = camera.CFrame.Position + Vector3.new(math.random(-15, 15), math.random(2, 10), math.random(-15, 15))
			local dest = camera.CFrame.Position + camera.CFrame.LookVector * math.random(30, 80) + Vector3.new(math.random(-20, 20), math.random(-5, 10), math.random(-20, 20))
			fireTracer(origin, dest, flip and trA or trB)
		end
	end
end)
local fpsCount, fpsValue = 0, 0
RunService.RenderStepped:Connect(function() fpsCount = fpsCount + 1 end)
task.spawn(function()
	while true do
		task.wait(1)
		fpsValue = fpsCount
		fpsCount = 0
		if wmOn then
			WmText.Text = "BROKECHEAT v6  fps " .. fpsValue .. "  ping " .. math.floor(LocalPlayer:GetNetworkPing() * 1000) .. "ms  " .. os.date("%H:%M:%S")
		end
		if indOn then
			BrokeStatus("aim:" .. (aimOn and "on" or "off") .. " esp:" .. (espOn and "on" or "off") .. " wx:" .. weatherType .. " fps:" .. fpsValue)
		end
	end
end)

-- v6 FIX: actually show the window once everything exists
task.defer(function()
	pcall(function()
		if Window.Outer and Window.Outer.Visible == false then
			Library:Toggle()
		end
	end)
	pcall(function()
		if Window.Holder and Window.Holder.Visible == false then
			Library:Toggle()
		end
	end)
end)
BrokeStatus("build: COMPLETE - menu live")
Library:Notify("Brokecheat Ultimate v6 loaded. RightShift toggles the menu.", 4)
print("[Brokecheat] v6 single-file build loaded.")
if getgenv then getgenv().BrokeUltimateV6 = true end
end)

if not okBuild then
	BrokeFatal(tostring(buildErr))
	warn("[Brokecheat] BUILD ERROR: " .. tostring(buildErr))
end