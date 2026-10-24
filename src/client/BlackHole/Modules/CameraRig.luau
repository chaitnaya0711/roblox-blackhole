local UIS = game:GetService("UserInputService")

local CameraRig = {}
CameraRig.__index = CameraRig

local FOV_MIN, FOV_MAX = 8, 70
local MAX_ELEVATION = 1.45
local IDLE_BEFORE_DRIFT = 4

local function isPointerDown(inputType)
	return inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.Touch
end

function CameraRig.new(startFov, autoOrbit)
	local self = setmetatable({}, CameraRig)

	self.azimuth = 0.6
	self.elevation = math.rad(8)
	self.fov = startFov

	self.targetAzimuth = self.azimuth
	self.targetElevation = self.elevation
	self.targetFov = startFov

	self.autoOrbit = autoOrbit
	self.dragging = false
	self.lastInput = os.clock()
	self.pinchBase = startFov

	self:bindInput()
	return self
end

function CameraRig:bindInput()
	UIS.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if isPointerDown(input.UserInputType) then
			self.dragging = true
		end
	end)

	UIS.InputEnded:Connect(function(input)
		if isPointerDown(input.UserInputType) then
			self.dragging = false
		end
	end)

	UIS.InputChanged:Connect(function(input)
		local inputType = input.UserInputType
		local moving = inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch

		if self.dragging and moving then
			self.targetAzimuth -= input.Delta.X * 0.005
			self.targetElevation = math.clamp(self.targetElevation + input.Delta.Y * 0.005, -MAX_ELEVATION, MAX_ELEVATION)
			self.lastInput = os.clock()
		elseif inputType == Enum.UserInputType.MouseWheel then
			self.targetFov = math.clamp(self.targetFov - input.Position.Z * 3, FOV_MIN, FOV_MAX)
		end
	end)

	UIS.TouchPinch:Connect(function(_touches, scale, _velocity, state)
		if state == Enum.UserInputState.Begin then
			self.pinchBase = self.targetFov
		end
		self.targetFov = math.clamp(self.pinchBase / math.max(scale, 0.05), FOV_MIN, FOV_MAX)
	end)
end

function CameraRig:update(dt)
	local k = math.min(1, dt * 12)
	self.azimuth += (self.targetAzimuth - self.azimuth) * k
	self.elevation += (self.targetElevation - self.elevation) * k
	self.fov += (self.targetFov - self.fov) * k

	if os.clock() - self.lastInput > IDLE_BEFORE_DRIFT then
		self.targetAzimuth += self.autoOrbit * dt
	end
end

return CameraRig
