local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientBaggage = require(ReplicatedStorage.Shared.Classes.Baggage.ClientBaggage)
local Client = require(ReplicatedStorage.Shared.Network.Client)

local BaggageController = {}

function BaggageController:Init()
	Client.Baggage.Replicate.On(function(data)
		local baggage = ClientBaggage.new(data)
		baggage.Clicked:Connect(function()
			print("Baggage ID:", baggage.UUID)
		end)
	end)
end

return BaggageController
