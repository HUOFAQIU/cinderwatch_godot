class_name CWMonsterUnit
extends RefCounted

## Strongly-typed runtime monster instance with pre-cached static flags & GPU batch ref
## for zero-dictionary-lookup, zero-allocation hot loops.

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

# Pre-cached hot-path properties (populated once in spawn())
var road_idx: int = 0
var base_spd: float = 1.2
var unit_scale: float = 1.0
var is_fly: bool = false
var is_boss: bool = false
var is_ghost: bool = false
var is_slip: bool = false
var has_regen: bool = false
var regen_rate: float = 0.0
var has_frenzy: bool = false
var frenzy_mul: float = 0.0
var has_enrage: bool = false
var enrage_th: float = 0.0
var has_aura: bool = false
var aura_r: float = 0.0
var aura_r2: float = 0.0
var aura_boost: float = 0.0
var has_summon: bool = false
var has_stomp: bool = false
var has_special_fx: bool = false
var has_eye: bool = false
var eye_col: Color = Color.BLACK
var eye_y: float = 1.2
var eye_z: float = 0.16
var rig_is_fly: bool = false
var ub: CWRig.UnitBatch = null
