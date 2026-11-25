class_name CWMonsterUnit
extends RefCounted

## Strongly-typed runtime monster instance, replacing untyped Dictionary lookups
## for O(1) property access in movement, targeting, spatial hashing, and rigging.

var type: String = ""
var def: Dictionary = {}
var hp: float = 0.0
var max_hp: float = 0.0
var s: float = 0.0
var lat: float = 0.0
var prog: float = 0.0
var x: float = 0.0
var y: float = 0.0
var z: float = 0.0
var yaw: float = 0.0
var phase: float = 0.0
var flash: float = 0.0
var slow_f: float = 0.0
var slow_t: float = 0.0
var haste: float = 0.0
var dead: bool = false
var dying: float = 0.0
var blocker = null
var atk_cd: float = 0.4
var swing: float = 0.0
var ghost_t: float = 0.0
var faded: bool = false
var ability_cd: float = 3.0
var summons: int = 0
var torch: bool = false
var col: Color = Color.WHITE
var flinch: float = 0.0
var cast: float = 0.0
var mv: float = 1.0
var struck: bool = true
var raged: bool = false
var step: int = -1
