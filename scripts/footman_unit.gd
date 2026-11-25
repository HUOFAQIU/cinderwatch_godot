class_name CWFootmanUnit
extends RefCounted

## Strongly-typed runtime guard-post footman instance.

var tower: Dictionary = {}
var slot: int = 0
var torch: bool = false
var x: float = 0.0
var y: float = 0.0
var z: float = 0.0
var home: Vector3 = Vector3.ZERO
var guard_yaw: float = 0.0
var hp: float = 60.0
var max_hp: float = 60.0
var dmg: float = 7.0
var cd: float = 0.0
var yaw: float = 0.0
var phase: float = 0.0
var mv: float = 0.0
var swing: float = 0.0
var flash: float = 0.0
var flinch: float = 0.0
var foe: CWMonsterUnit = null
