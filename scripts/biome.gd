class_name CWBiome
extends RefCounted

# All 5 biomes ported from 29-biome.js with palettes, lighting, weather, water, and monster weights

const BASE_PALETTE := {
	"stone": 0x6c6e78,
	"stoneD": 0x42454e,
	"stoneL": 0x9496a0,
	"earth": 0x4a423a,
	"earthD": 0x2e2824,
	"grass": 0x445638,
	"grassD": 0x2e3c26,
	"moss": 0x4c6236,
	"road": 0x766c60,
	"roadD": 0x4e463e,
	"mud": 0x342c24,
	"wood": 0x6e4e34,
	"woodD": 0x46301e,
	"woodL": 0x946c48,
	"bark": 0x3a2c22,
	"iron": 0x525864,
	"gold": 0xd8a840,
	"tuftA": 0x4c6438,
	"tuftB": 0x788a48,
	"leaf": 0x2c4628,
	"leafL": 0x486634,
	"bone": 0xd4ccb8,
	"clothR": 0x942e28,
	"clothB": 0x2c4c88,
	"crystal": 0x55c4ff,
	"fire": 0xff8a2c,
}

const BIOME_KEYS := ["ashen", "frost", "fen", "ember", "dunes"]

static var BIOMES: Array[Dictionary] = []


static func _static_init() -> void:
	for bk in BIOME_KEYS:
		var res := load("res://assets/data/biomes/%s.tres" % bk) as CWBiomeData
		if res != null:
			BIOMES.append(res.to_dict())


static func get_biome(index: int, start_offset: int = 0) -> Dictionary:
	var n := BIOMES.size()
	var idx := ((start_offset + index) % n + n) % n
	return BIOMES[idx]


static func build_palette(bio: Dictionary) -> Dictionary:
	var pal := {}
	for k in BASE_PALETTE.keys():
		pal[k] = CWUtil.hex_color(BASE_PALETTE[k])
	var overrides: Dictionary = bio.get("col", {})
	for k in overrides.keys():
		pal[k] = CWUtil.hex_color(overrides[k])
	return pal
