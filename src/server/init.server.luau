local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Conveyor = require(ReplicatedStorage.Shared.Classes.Conveyor)

local conveyorModel = workspace.Conveyor
Conveyor.new({
	Belt = conveyorModel.Belt,
	Start = conveyorModel.Belt.Start,
	Finish = conveyorModel.Belt.Finish,
})
