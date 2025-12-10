local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Register = require(ReplicatedStorage.Shared.Modules.Register)

-- Imported Types
local BaggageType = require(ReplicatedStorage.Shared.Types.BaggageType)

-- Exported Types
export type Data = BaggageType.Data
export type Entity = BaggageType.Entity
export type Class = BaggageType.Class

-- Class Definition
local Baggage = {} :: Class
Baggage.__index = Baggage

-- Constructor
function Baggage.new(data: Data?)
	local self = setmetatable({}, Baggage)
	self.Tags = { "Baggage" }
	self.Data = data or {}

	return self:__init()
end

-- Private methods
function Baggage:__init()
	self:__setupData()
	return self
end

function Baggage:__setupData()
	self.Destroyed = Signal.Good.new()
	self._trove = Trove.new()
	Register.RegisterData(self)
end

-- Public methods
function Baggage:Destroy()
	self._trove:Destroy()
	self.Destroyed:Fire()
end

return Baggage
