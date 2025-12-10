local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
local BaggageType = require(script.Parent)

type Signal = typeof(Signal.Good.new())

export type Data = {
	UUID: string,
	Color: Color3,
	Material: string,
	Start: Vector3,
	Finish: Vector3,
}

export type Entity = {
	Data: Data,
	Model: Model,
	SetColor: (self: Entity, color: Color3?) -> (),
	SetMaterial: (self: Entity, material: Enum.Material?) -> (),
	Spawn: (self: Entity) -> (),
	Destroy: (self: Entity) -> (),
	Clicked: Signal,
	_clickDetector: ClickDetector,
	__init: (self: Entity) -> Entity,
	__setupData: (self: Entity) -> (),
	__setupModel: (self: Entity) -> (),
	__setupConnections: (self: Entity) -> (),
} & BaggageType.Entity

export type Class = {
	new: (data: Data) -> Entity,
	__index: Class,
} & Entity & BaggageType.Class

return {}
