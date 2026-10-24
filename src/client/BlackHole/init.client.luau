--!native
--!optimize 2

local RunService = game:GetService("RunService")

local Modules = script.Modules
local Config = require(Modules.Config)
local Loading = require(Modules.Loading)
local Scene = require(Modules.Scene)
local Geodesics = require(Modules.Geodesics)
local DiskTexture = require(Modules.DiskTexture)
local DiskImage = require(Modules.DiskImage)
local PhotonRing = require(Modules.PhotonRing)
local Shadow = require(Modules.Shadow)
local Stars = require(Modules.Stars)
local CameraRig = require(Modules.CameraRig)

local cos, sin, abs = math.cos, math.sin, math.abs

local CENTER = Config.Center
local DISTANCE = Config.D
local LOOP = Config.LoopSeconds
local MIN_ELEVATION = 0.026

local function run()
	local camera, folder = Scene.setup()

	local geo = Geodesics.build()
	local tex = DiskTexture.build()
	Loading.progress(0.38)

	local ctx = { geo = geo, folder = folder, tex = tex }
	local images = {
		DiskImage.new(ctx, 0, 44, 220, 1.3),
		DiskImage.new(ctx, 1, 28, 180, 1.0),
		DiskImage.new(ctx, 2, 12, 120, 0.8),
	}
	Loading.progress(0.55)
	Loading.yieldIfSlow()

	local ring = PhotonRing.new(folder)
	local shadow = Shadow.new(folder)
	Loading.progress(0.62)
	Loading.yieldIfSlow()

	local stars = Stars.new(folder, geo)
	local rig = CameraRig.new(Config.FOV, Config.AutoOrbit)

	Loading.hide()

	local lastElevation, lastAzimuth = math.huge, math.huge
	local startClock = os.clock()

	RunService.RenderStepped:Connect(function(dt)
		rig:update(dt)

		local elevation = rig.elevation
		if abs(elevation) < MIN_ELEVATION then
			elevation = elevation < 0 and -MIN_ELEVATION or MIN_ELEVATION
		end

		local ce, se = cos(elevation), sin(elevation)
		local toCam = Vector3.new(ce * sin(rig.azimuth), se, ce * cos(rig.azimuth))
		local camPos = CENTER + toCam * DISTANCE

		camera.FieldOfView = rig.fov
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(camPos, CENTER)
		camera.Focus = CFrame.new(CENTER)
		local rotation = camera.CFrame.Rotation

		local elevationChanged = abs(elevation - lastElevation) > 0.0008
		if elevationChanged then
			for _, img in ipairs(images) do
				DiskImage.project(img, ce, se)
			end
			PhotonRing.update(ring, ce)
			lastElevation = elevation
		end

		if elevationChanged or abs(rig.azimuth - lastAzimuth) > 0.0005 then
			Stars.update(stars, camera.CFrame.RightVector, camera.CFrame.UpVector, camera.CFrame.LookVector, toCam)
			lastAzimuth = rig.azimuth
		end

		local t = (os.clock() - startClock) % LOOP
		for _, img in ipairs(images) do
			DiskImage.animate(img, t, rig.azimuth)
			img.part.CFrame = CFrame.new(CENTER + toCam * img.offset) * rotation
		end

		ring.part.CFrame = CFrame.new(CENTER + toCam * PhotonRing.Offset) * rotation
		shadow.CFrame = CFrame.new(CENTER + toCam * Shadow.Offset) * rotation
		stars.part.CFrame = CFrame.new(camPos)
	end)
end

Scene.hideCoreGui()
Loading.show()

local ok, err = pcall(run)
if not ok then
	warn("BlackHole failed: " .. tostring(err))
	Loading.fail(err)
end
