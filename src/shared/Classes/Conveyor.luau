local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Trove = require(ReplicatedStorage.Packages.Trove)
local ServerBaggage = require(ReplicatedStorage.Shared.Classes.Baggage.ServerBaggage)
local Server = require(ReplicatedStorage.Shared.Network.Server)

-- Imported Types
local ConveyorType = require(ReplicatedStorage.Shared.Types.ConveyorType)

-- Exported Types
export type Data = ConveyorType.Data
export type Entity = ConveyorType.Entity
export type Class = ConveyorType.Class

-- Constants
local DEFAULT_CONVEYOR_SPEED = 5
local DEFAULT_BAGGAGE_SPAWN_RATE = 1

-- Class Definition
local Conveyor = {} :: Class
Conveyor.__index = Conveyor

-- Constructor
function Conveyor.new(data: Data)
	local self = setmetatable({}, Conveyor)
	self.Tags = { "Conveyor" }
	self.Data = data

	return self:__init()
end

-- Private methods
function Conveyor:__init()
	self:__setupData()
	self:__setupConnections()
	return self
end

function Conveyor:__setupData()
	self._trove = Trove.new()

	self.Belt = self.Data.Belt
	self.Start = self.Data.Start
	self.Finish = self.Data.Finish

	self:SetSpeed()
	self:SetSpawnRate()
end

function Conveyor:__setupConnections()
	self._trove:Add(task.spawn(function()
		while true do
			local baggage = ServerBaggage.new({
				Speed = self.Speed,
				Start = self.Start.WorldPosition,
				Finish = self.Finish.WorldPosition,
			})
			baggage.Clicked:Connect(function()
				print("Baggage ID:", baggage.UUID)
			end)
			task.wait(1 / math.clamp(self.SpawnRate, 1, 10))
		end
	end))

	self._trove:Add(Server.Conveyor.SetSpawnrate.On(function(player, data)
		if self.Player == player then
			self:SetSpawnRate(data.Spawnrate)
		end
	end))
end

-- Public methods
function Conveyor:SetSpawnRate(rate: number)
	self.SpawnRate = rate or DEFAULT_BAGGAGE_SPAWN_RATE
end

function Conveyor:SetSpeed(speed: number?)
	self.Speed = speed or DEFAULT_CONVEYOR_SPEED
	self.Belt.AssemblyLinearVelocity = self.Speed * Vector3.new(0, 0, -1)
end

function Conveyor:SetOwnership(player: Player?)
	self.Player = player
	Server.Conveyor.SetOwnership.FireAll({ Player = player })
end

function Conveyor:HasOwner(): boolean
	return self.Player ~= nil
end

function Conveyor:IsOwner(player: Player): boolean
	return self.Player == player
end

function Conveyor:Destroy()
	self._trove:Destroy()
end

return Conveyor
