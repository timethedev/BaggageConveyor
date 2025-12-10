local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

type Signal = typeof(Signal.Good.new())

export type Data = {
	Color: Color3?,
	Material: Enum.Material?,
}

export type Entity = {
	Tags: { string },
	UUID: string,
	Data: Data,
	Destroy: (self: Entity) -> (),
	Destroyed: Signal,
	_trove: Trove.Trove,
	__init: (self: Entity) -> Entity,
	__setupData: (self: Entity) -> (),
}

export type Class = {
	new: () -> Entity,
	__index: Class,
} & Entity

return {}
