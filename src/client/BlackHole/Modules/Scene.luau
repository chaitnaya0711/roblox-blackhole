local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)

local Scene = {}

function Scene.hideCoreGui()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
end

function Scene.setup()
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	Lighting.Brightness = 0
	Lighting.Ambient = Color3.new(0, 0, 0)
	Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
	Lighting.FogEnd = 1e6
	Lighting.FogColor = Color3.new(0, 0, 0)

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("BloomEffect") then
			child:Destroy()
		end
	end

	local sky = Instance.new("Sky")
	sky.StarCount = 0
	sky.CelestialBodiesShown = false
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = Config.Bloom
	bloom.Size = 36
	bloom.Threshold = 0.8
	bloom.Parent = Lighting

	local folder = Instance.new("Folder")
	folder.Name = "BlackHoleMeshes"
	folder.Parent = Workspace

	pcall(function()
		local Players = game:GetService("Players")
		local player = Players.LocalPlayer
		if player then
			player.ReplicationFocus = folder
		end
	end)

	return camera, folder
end

return Scene
