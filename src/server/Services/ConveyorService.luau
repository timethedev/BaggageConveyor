local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Conveyor = require(ReplicatedStorage.Shared.Classes.Conveyor)

local ConveyorService = {}

function ConveyorService:Init()
	local conveyorModel = workspace.Conveyor
	local conveyor = Conveyor.new({
		Belt = conveyorModel.Belt,
		Start = conveyorModel.Belt.Start,
		Finish = conveyorModel.Belt.Finish,
	})

	Players.PlayerAdded:Connect(function(player)
		if not conveyor:HasOwner() then
			conveyor:SetOwnership(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if conveyor:IsOwner(player) then
			local players = Players:GetPlayers()

			if #players > 0 then
				local newPlayer = players[math.random(1, #players)]
				conveyor:SetOwnership(newPlayer)
			end
		end
	end)
end

return ConveyorService
