class_name AroundMeWeatherPreset
extends Resource

## Data-driven weather preset editable directly in the Godot Inspector (.tres).
## Duplicate any preset under res://aroundme/assets/weather/ and add it to
## AroundMeMain.weather_presets to add new weather types with zero code changes.

@export_group("Identity")
@export var id: String = "sun"
@export var button_label: String = "SUN"

@export_group("Lighting")
@export var sun_color: Color = Color(1.0, 0.91, 0.72, 1.0)
@export_range(0.0, 4.0, 0.05) var sun_energy: float = 1.80
@export var fill_color: Color = Color(0.58, 0.80, 1.0, 1.0)
@export_range(0.0, 3.0, 0.05) var fill_energy: float = 0.56
@export var ambient_color: Color = Color(0.66, 0.74, 0.66, 1.0)
@export_range(0.0, 2.0, 0.02) var ambient_energy: float = 0.58
@export var background_color: Color = Color(0.14, 0.22, 0.16, 1.0)

@export_group("Mist")
@export var mist_color: Color = Color(0.52, 0.58, 0.46, 1.0)
@export_range(-2.0, 3.0, 0.05) var mist_base_y: float = -0.25
@export_range(0.1, 3.0, 0.05) var mist_scale_h: float = 0.45
@export_range(0.0, 2.0, 0.02) var mist_density: float = 0.72
@export_range(0.0, 0.5, 0.005) var mist_gain: float = 0.065

@export_group("Surface & Grass")
@export_range(0.0, 1.0, 0.05) var ground_wetness: float = 0.0
@export_range(0.0, 1.0, 0.05) var grass_rain_amount: float = 0.0

@export_group("Post Process")
@export_range(0.4, 1.6, 0.02) var exposure: float = 0.96
@export_range(0.2, 1.6, 0.02) var saturation: float = 0.90
@export_range(0.0, 1.0, 0.02) var vignette: float = 0.34
@export var shadow_lift: Vector3 = Vector3(0.022, 0.024, 0.018)

@export_group("Lightning")
@export var allow_lightning: bool = false
@export_range(1.0, 30.0, 0.5) var lightning_interval_min: float = 6.0
@export_range(2.0, 40.0, 0.5) var lightning_interval_max: float = 12.5
@export var lightning_sun_color: Color = Color(0.88, 0.94, 1.0, 1.0)
@export_range(0.0, 5.0, 0.1) var lightning_sun_boost: float = 2.1
@export_range(0.0, 2.0, 0.05) var lightning_fill_boost: float = 0.95
@export_range(0.0, 1.5, 0.05) var lightning_ambient_boost: float = 0.45
@export_range(0.0, 0.8, 0.02) var lightning_exposure_boost: float = 0.24

@export_group("Particles Ambient")
@export var particle_ambient: Color = Color(0.68, 0.78, 0.64, 1.0)

@export_group("Particles A (Primary: Pollen / Rain)")
@export_range(0.0, 1.0, 0.02) var particle_a_ratio: float = 0.32
@export var particle_a_vel: Vector3 = Vector3(0.30, -0.14, 0.16)
@export var particle_a_sway: Vector2 = Vector2(0.65, 0.75)
@export var particle_a_size: Vector2 = Vector2(0.028, 0.052)
@export var particle_a_color: Color = Color(0.96, 0.96, 0.80, 1.0)
@export_range(0.0, 1.0, 0.02) var particle_a_alpha: float = 0.65
@export_range(0.0, 5.0, 0.1) var particle_a_twinkle: float = 0.0
@export_range(0.0, 2.0, 0.05) var particle_a_stretch: float = 0.0
@export var particle_a_y_range: Vector2 = Vector2(-1.5, 11.0)

@export_group("Particles B (Secondary: Leaves / Mist)")
@export_range(0.0, 1.0, 0.02) var particle_b_ratio: float = 0.12
@export var particle_b_vel: Vector3 = Vector3(0.24, -0.22, 0.18)
@export var particle_b_sway: Vector2 = Vector2(0.95, 1.15)
@export var particle_b_size: Vector2 = Vector2(0.042, 0.072)
@export var particle_b_color: Color = Color(0.75, 0.92, 0.48, 0.0)
@export_range(0.0, 1.0, 0.02) var particle_b_alpha: float = 1.0
@export_range(0.0, 5.0, 0.1) var particle_b_twinkle: float = 2.2
@export_range(0.0, 2.0, 0.05) var particle_b_stretch: float = 0.3
@export var particle_b_y_range: Vector2 = Vector2(-0.5, 6.5)
