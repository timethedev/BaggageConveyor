local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Dependencies
local ModalManager = require(ReplicatedStorage.Shared.Modules.ModalManager)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Client = require(ReplicatedStorage.Shared.Network.Client)
local scope = Fusion.scoped(Fusion)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ScreenGui = PlayerGui:WaitForChild("ScreenGui")

-- Variables
local SpawnrateGui = ScreenGui.SpawnRate
local CloseButton = SpawnrateGui.CloseButton
local ToggleButton: GuiButton = ScreenGui.ToggleButton

local Slider = SpawnrateGui.Slider
local SliderButton: GuiButton = Slider.Button
local SpawnRate: TextLabel = Slider.SpawnRate

local SLIDER_MIN = 0.1 -- far left
local SLIDER_MAX = 10 -- far right
local SLIDER_STEP = 0.1 -- snapping step (1 = whole numbers)

-- Functions
local function SnapToStep(value, step)
	return math.floor(value / step + 0.5) * step
end

-- Modal Setup
ModalManager.RegisterModal("Slider", SpawnrateGui, {
	CloseButton = CloseButton,
})

ToggleButton.Activated:Connect(function()
	ModalManager.ToggleModal("Slider")
end)

-- Setup Slider Logic
local isDragging = false
local MouseX = scope:Value(0)
local SnappedValue = scope:Computed(function(use)
	local sliderAbsPos = Slider.AbsolutePosition.X
	local sliderAbsSize = Slider.AbsoluteSize.X

	local percentage = (use(MouseX) - sliderAbsPos) / sliderAbsSize
	percentage = math.clamp(percentage, 0, 1)
	local rawValue = SLIDER_MIN + (SLIDER_MAX - SLIDER_MIN) * percentage
	local snappedValue = SnapToStep(rawValue, SLIDER_STEP)

	return snappedValue
end)
local SnappedPercentage = scope:Computed(function(use)
	return (use(SnappedValue) - SLIDER_MIN) / (SLIDER_MAX - SLIDER_MIN)
end)

-- Hydrate UI elements
scope:Hydrate(SliderButton)({
	Position = scope:Tween(
		scope:Computed(function(use)
			return UDim2.fromScale(use(SnappedPercentage), 0.5)
		end),
		TweenInfo.new(0.1)
	),
})

scope:Hydrate(SpawnRate)({
	Text = scope:Tween(
		scope:Computed(function(use)
			Client.Conveyor.SetSpawnrate.Fire({ Spawnrate = use(SnappedValue) })
			return math.floor(use(SnappedValue) * 10) / 10 .. "b/s"
		end),
		TweenInfo.new(0.1)
	),
})

-- Start dragging
SliderButton.MouseButton1Down:Connect(function()
	isDragging = true
end)

-- Stop dragging
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDragging = false
	end
end)

-- Update during drag
UserInputService.InputChanged:Connect(function(input)
	if isDragging then
		MouseX:set(input.Position.X)
	end
end)

Client.Conveyor.SetOwnership.On(function(data)
	ModalManager.CloseAllModals()
	if data.Player == LocalPlayer then
		ToggleButton.Visible = true
	else
		ToggleButton.Visible = false
	end
end)
