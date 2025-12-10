local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
local BaggageType = require(script.Parent)

type Signal = typeof(Signal.Good.new())

export type Data = {
	Color: Color3?,
	Material: Enum.Material?,
	Speed: number?,
	Start: Vector3,
	Finish: Vector3,
}

export type Entity = {
	Data: Data,
	Color: Color3,
	Material: Enum.Material,
	Speed: number,
	Clicked: Signal,
	Destroyed: Signal,
	__init: (self: Entity) -> Entity,
	__setupData: (self: Entity) -> (),
	__setupConnections: (self: Entity) -> (),
	__replicate: (self: Entity) -> (),
} & BaggageType.Entity

export type Class = {
	new: () -> Entity,
	__index: Class,
} & Entity & BaggageType.Class

return {}
