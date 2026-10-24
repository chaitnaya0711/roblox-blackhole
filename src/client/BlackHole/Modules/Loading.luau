local Players = game:GetService("Players")

local Loading = {}

local gui, label
local lastPercent = -1
local sliceStart = os.clock()

function Loading.show()
	gui = Instance.new("ScreenGui")
	gui.Name = "BlackHoleLoading"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromOffset(600, 60)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(190, 190, 190)
	label.Font = Enum.Font.Code
	label.TextSize = 16
	label.TextWrapped = true
	label.Text = "0%"
	label.Parent = backdrop
end

function Loading.progress(fraction)
	local percent = math.floor(math.clamp(fraction, 0, 1) * 100)
	if percent ~= lastPercent then
		lastPercent = percent
		label.Text = percent .. "%"
	end
end

function Loading.yieldIfSlow()
	if os.clock() - sliceStart > 0.010 then
		task.wait()
		sliceStart = os.clock()
	end
end

function Loading.fail(err)
	label.Text = tostring(err)
	label.Size = UDim2.fromOffset(700, 120)
end

function Loading.hide()
	gui:Destroy()
end

return Loading
