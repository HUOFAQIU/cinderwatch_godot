class_name CWBiomeDef
extends Resource

## Godot Resource definition for a biome atmosphere, palette, and weather profile.

@export var id: String = ""
@export var display_name: String = ""
@export var boss_id: String = "giant"

@export_group("Colors & Lighting")
@export var sky_color: Color = Color(0.06, 0.08, 0.14)
@export var fog_color: Color = Color(0.08, 0.10, 0.16)
@export var moon_color: Color = Color(0.75, 0.85, 1.0)
@export var fill_color: Color = Color(0.45, 0.52, 0.70)
@export var ground_color: Color = Color(0.24, 0.28, 0.22)
@export var cliff_color: Color = Color(0.28, 0.26, 0.25)

@export_group("Weather")
@export var weather_kind: String = "ash"
@export var weather_intensity: float = 1.0
