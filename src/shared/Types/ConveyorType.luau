local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

type Scope = typeof(Fusion.scoped(Fusion))
type Signal = typeof(Signal.Good.new())

export type Data = {
	Belt: BasePart,
	Start: Attachment,
	Finish: Attachment,
	Speed: number?,
}

export type Entity = {
	Tags: { string },
	Player: Player?,
	Data: Data,
	Belt: BasePart,
	Start: Attachment,
	Finish: Attachment,
	Speed: number,
	SpawnRate: number,
	SetSpeed: (self: Entity, speed: number?) -> (),
	SetSpawnRate: (self: Entity, rate: number?) -> (),
	SetOwnership: (self: Entity, player: Player?) -> (),
	HasOwner: (self: Entity) -> boolean,
	IsOwner: (self: Entity, player: Player) -> boolean,
	Destroy: (self: Entity) -> (),
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
