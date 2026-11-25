class_name CWMonsterDef
extends Resource

## Godot Resource definition for a monster or boss archetype.
## Enables inspector editing and .tres presets while staying compatible with CWMonsters.DEFS.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var tip: String = ""

@export_group("Stats")
@export var hp: float = 30.0
@export var spd: float = 1.2
@export var bounty: int = 5
@export var lives: int = 1
@export var hit_h: float = 0.7
@export var dmg: float = 6.0
@export var atk_t: float = 1.0
@export var armor: float = 1.0
@export var slow_res: float = 0.0

@export_group("Movement & Type")
@export var fly: bool = false
@export var alt: float = 0.0
@export var slip: bool = false
@export var ghost: bool = false
@export var boss: bool = false

@export_group("Visual Rig")
@export var scale: float = 1.0
@export var rig: String = "human"
@export var col: Color = Color(0.84, 0.80, 0.72)
@export var eye: Color = Color(3.4, 0.9, 0.2)
@export var skel: bool = false
@export var heavy: bool = false
@export var weapon: bool = false
@export var shield: bool = false
@export var armor_suit: bool = false
@export var wraps: bool = false
@export var crown: bool = false
@export var hood: bool = false
@export var staff: bool = false
@export var drum: bool = false
@export var keg: bool = false
@export var horns: bool = false
@export var greatsword: bool = false
@export var iceclub: bool = false

@export_group("Special Abilities")
@export var frenzy: float = 0.0
@export var regen: float = 0.0
@export var enrage: float = 0.0
@export var split: Array = []
@export var aura: Array = []
@export var summon: Dictionary = {}
@export var stomp: Dictionary = {}
@export var explode: Dictionary = {}


static func from_dict(p_id: String, d: Dictionary) -> CWMonsterDef:
	var res := CWMonsterDef.new()
	res.id = p_id
	res.display_name = String(d.get("name", p_id))
	res.tip = String(d.get("tip", ""))
	res.hp = float(d.get("hp", 30.0))
	res.spd = float(d.get("spd", 1.2))
	res.bounty = int(d.get("bounty", 5))
	res.lives = int(d.get("lives", 1))
	res.hit_h = float(d.get("hit_h", 0.7))
	res.dmg = float(d.get("dmg", 6.0))
	res.atk_t = float(d.get("atk_t", 1.0))
	res.armor = float(d.get("armor", 1.0))
	res.slow_res = float(d.get("slow_res", 0.0))
	res.fly = bool(d.get("fly", false))
	res.alt = float(d.get("alt", 0.0))
	res.slip = bool(d.get("slip", false))
	res.ghost = bool(d.get("ghost", false))
	res.boss = bool(d.get("boss", false))
	res.scale = float(d.get("scale", 1.0))
	res.rig = String(d.get("rig", "human"))
	res.col = Color(d.get("col", Color.WHITE))
	res.eye = Color(d.get("eye", Color.WHITE))
	res.skel = bool(d.get("skel", false))
	res.heavy = bool(d.get("heavy", false))
	res.weapon = bool(d.get("weapon", false))
	res.shield = bool(d.get("shield", false))
	res.armor_suit = bool(d.get("armor_suit", false))
	res.wraps = bool(d.get("wraps", false))
	res.crown = bool(d.get("crown", false))
	res.hood = bool(d.get("hood", false))
	res.staff = bool(d.get("staff", false))
	res.drum = bool(d.get("drum", false))
	res.keg = bool(d.get("keg", false))
	res.horns = bool(d.get("horns", false))
	res.greatsword = bool(d.get("greatsword", false))
	res.iceclub = bool(d.get("iceclub", false))
	res.frenzy = float(d.get("frenzy", 0.0))
	res.regen = float(d.get("regen", 0.0))
	res.enrage = float(d.get("enrage", 0.0))
	res.split = d.get("split", [])
	res.aura = d.get("aura", [])
	res.summon = d.get("summon", {})
	res.stomp = d.get("stomp", {})
	res.explode = d.get("explode", {})
	return res
