local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Dependencies
local Signal = require(ReplicatedStorage.Packages.Signal)
local Baggage = require(script.Parent)
local Register = require(ReplicatedStorage.Shared.Modules.Register)
local Client = require(ReplicatedStorage.Shared.Network.Client)

-- Imported Types
local ClientBaggageType = require(ReplicatedStorage.Shared.Types.BaggageType.ClientBaggageType)

-- Exported Types
export type Data = ClientBaggageType.Data
export type Entity = ClientBaggageType.Entity
export type Class = ClientBaggageType.Class

-- Constants
local DEFAULT_BAGGAGE_PREFAB = ReplicatedStorage.Assets.Baggage

-- Class Definition
local ClientBaggage = {} :: Class
ClientBaggage.__index = setmetatable(ClientBaggage, Baggage)

-- Constructor
function ClientBaggage.new(data: Data)
	local self = setmetatable(Baggage.new(data) :: Entity, ClientBaggage)
	self.Data = data
	self.Data.Material = Enum.Material[self.Data.Material]
	return self:__init()
end

-- Private methods
function ClientBaggage:__init()
	self:__setupData()
	self:__setupModel()
	self:__setupConnections()
	return self
end

function ClientBaggage:__setupData()
	self.Clicked = Signal.Good.new()
	self.UUID = self.Data.UUID
	Register.RegisterData(self)
end

function ClientBaggage:__setupModel()
	self.Model = DEFAULT_BAGGAGE_PREFAB:Clone()
	self.Model.Parent = workspace
	self:SetColor(self.Data.Color)
	self:SetMaterial(self.Data.Material)
	self._trove:Add(self.Model)

	self._clickDetector = Instance.new("ClickDetector")
	self._clickDetector.Parent = self.Model
	self._trove:Add(self._clickDetector.MouseClick:Connect(function()
		self.Clicked:Fire(self)
		Client.Baggage.Clicked.Fire(self)
	end))
end

function ClientBaggage:__setupConnections()
	self:Spawn(self.Data.Start)
	self._trove:Add(Client.Baggage.Destroy.On(function(data)
		if data.UUID == self.UUID then
			self:Destroy()
		end
	end))
end

-- Public methods
function ClientBaggage:SetColor(color: Color3)
	for _, descendant in pairs(self.Model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:HasTag("Colored") then
			descendant.Color = color
		end
	end
end

function ClientBaggage:SetMaterial(material: Enum.Material)
	for _, descendant in pairs(self.Model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:HasTag("Colored") then
			descendant.Material = material
		end
	end
end

function ClientBaggage:Spawn()
	self.Model.PrimaryPart.Anchored = true
	self.Model:PivotTo(CFrame.new(self.Data.Start + Vector3.yAxis * 5))
	local spawnTween = TweenService:Create(self.Model.PrimaryPart, TweenInfo.new(1), {
		CFrame = CFrame.new(self.Data.Start + Vector3.yAxis * self.Model:GetExtentsSize().Y / 2)
			* CFrame.Angles(0, math.rad(math.random() * 180), 0),
	})
	spawnTween:Play()
	spawnTween.Completed:Once(function()
		self.Model.PrimaryPart.Anchored = false
	end)
end

function ClientBaggage:Destroy()
	self.Model.PrimaryPart.Anchored = true
	self.Model.PrimaryPart.CanCollide = false
	self._clickDetector:Destroy()
	local destroyTween = TweenService:Create(self.Model.PrimaryPart, TweenInfo.new(1), {
		CFrame = CFrame.new(self.Model:GetPivot().Position + Vector3.yAxis * 4)
			* CFrame.Angles(0, math.rad(math.random() * 360), 0),
	})
	destroyTween:Play()
	destroyTween.Completed:Once(function()
		self._trove:Destroy()
		Register.UnregisterData(self)
	end)
end

return ClientBaggage
