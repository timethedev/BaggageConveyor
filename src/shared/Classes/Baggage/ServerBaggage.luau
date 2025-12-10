local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Signal = require(ReplicatedStorage.Packages.Signal)
local Register = require(ReplicatedStorage.Shared.Modules.Register)
local Server = require(ReplicatedStorage.Shared.Network.Server)

local Baggage = require(script.Parent)

-- Imported Types
local ServerBaggageType = require(ReplicatedStorage.Shared.Types.BaggageType.ServerBaggageType)

-- Exported Types
export type Data = ServerBaggageType.Data
export type Entity = ServerBaggageType.Entity
export type Class = ServerBaggageType.Class

-- Class Definition
local ServerBaggage = {} :: Class
ServerBaggage.__index = setmetatable(ServerBaggage, Baggage)

-- Constructor
function ServerBaggage.new(data: Data)
	local self = setmetatable(Baggage.new(data) :: Entity, ServerBaggage)
	self.Data = data
	self.Color = data.Color or Color3.new(math.random(), math.random(), math.random())
	self.Material = data.Material or Enum.Material.Plastic
	self.Speed = data.Speed or 1

	return self:__init()
end

-- Private methods
function ServerBaggage:__init()
	self:__setupData()
	self:__setupConnections()
	self:__replicate()
	return self
end

function ServerBaggage:__setupData()
	self.Clicked = Signal.Good.new()
	self.UUID = HttpService:GenerateGUID(false)
	Register.RegisterData(self)
end

function ServerBaggage:__setupConnections()
	local duration = (self.Data.Finish - self.Data.Start).Magnitude / (self.Speed * 0.9)
	self._trove:Add(task.delay(duration, function()
		self:Destroy()
	end))

	self._trove:Add(Server.Baggage.Clicked.On(function(player, data)
		if data.UUID == self.UUID then
			self.Clicked:Fire(player)
		end
	end))
end

function ServerBaggage:__replicate()
	Server.Baggage.Replicate.FireAll({
		UUID = self.UUID,
		Color = self.Color,
		Material = self.Material.Name,
		Start = self.Data.Start,
		Finish = self.Data.Finish,
	})
end

-- Public methods
function ServerBaggage:Destroy()
	self._trove:Destroy()
	self.Destroyed:Fire()
	Server.Baggage.Destroy.FireAll(self)
	Register.UnregisterData(self)
end

return ServerBaggage
