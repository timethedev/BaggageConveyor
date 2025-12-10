local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientBaggage = require(ReplicatedStorage.Shared.Classes.Baggage.ClientBaggage)
local Client = require(ReplicatedStorage.Shared.Network.Client)

Client.Baggage.Replicate.On(function(data)
	print(data)
	ClientBaggage.new(data)
end)
