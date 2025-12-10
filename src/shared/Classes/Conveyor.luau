local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Trove = require(ReplicatedStorage.Packages.Trove)
local ServerBaggage = require(ReplicatedStorage.Shared.Classes.Baggage.ServerBaggage)

-- Imported Types
local ConveyorType = require(ReplicatedStorage.Shared.Types.ConveyorType)

-- Exported Types
export type Data = ConveyorType.Data
export type Entity = ConveyorType.Entity
export type Class = ConveyorType.Class

-- Constants
local DEFAULT_BAGGAGE_SPAWN_RATE = 1

-- Class Definition
local Conveyor = {} :: Class
Conveyor.__index = Conveyor

-- Constructor
function Conveyor.new(data: Data)
	local self = setmetatable({}, Conveyor)
	self.Tags = { "Conveyor" }
	self.Baggages = {}
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
end

function Conveyor:__setupConnections()
	self._trove:Add(task.spawn(function()
		while true do
			table.insert(
				self.Baggages,
				ServerBaggage.new({
					Speed = self.Speed,
					Start = self.Start.WorldPosition,
					Finish = self.Finish.WorldPosition,
				})
			)
			task.wait(DEFAULT_BAGGAGE_SPAWN_RATE)
		end
	end))
end

return Conveyor
