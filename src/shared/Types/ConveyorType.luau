local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerBaggageType = require(script.Parent.BaggageType.ServerBaggageType)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)

type Scope = typeof(Fusion.scoped(Fusion))

export type Data = {
	Belt: BasePart,
	Start: Attachment,
	Finish: Attachment,
	Speed: number?,
}

export type Entity = {
	Tags: { string },
	Data: Data,
	Baggages: { ServerBaggageType.Entity },
	Belt: BasePart,
	Start: Attachment,
	Finish: Attachment,
	Speed: number,
	SetSpeed: (self: Entity, speed: number) -> (),
	SetSpawnRate: (self: Entity, rate: number) -> (),
	_trove: Trove.Trove,
	__init: (self: Entity) -> Entity,
	__setupData: (self: Entity) -> (),
	__setupConnections: (self: Entity) -> (),
}

export type Class = {
	new: (data: Data) -> Entity,
	__index: Class,
} & Entity

return {}
