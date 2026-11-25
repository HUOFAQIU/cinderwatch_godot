class_name CWTowerDef
extends Resource

## Godot Resource definition for a tower archetype (3 upgrade tiers).

@export var id: String = ""
@export var display_name: String = ""
@export var short_name: String = ""
@export_multiline var desc: String = ""

@export_group("Economy & Targeting")
@export var cost: PackedInt32Array = PackedInt32Array([70, 90, 140])
@export var range_tiers: PackedFloat32Array = PackedFloat32Array([6.2, 6.8, 7.4])
@export var min_range: float = 0.0
@export var air: bool = true
@export var ground: bool = true

@export_group("Combat")
@export var dmg: PackedFloat32Array = PackedFloat32Array([9.0, 11.0, 14.0])
@export var rate: PackedFloat32Array = PackedFloat32Array([0.85, 0.78, 0.70])
@export var count_tiers: PackedInt32Array = PackedInt32Array([1, 2, 3])
@export var splash: PackedFloat32Array = PackedFloat32Array([])
@export var jumps: PackedInt32Array = PackedInt32Array([])
@export var slow: PackedFloat32Array = PackedFloat32Array([])
@export var slow_t: PackedFloat32Array = PackedFloat32Array([])
@export var hp_tiers: PackedFloat32Array = PackedFloat32Array([])

@export_group("Lighting")
@export var light_tiers: PackedFloat32Array = PackedFloat32Array([10.0, 13.0, 16.0])
@export var col: Color = Color(1.0, 0.58, 0.22)
