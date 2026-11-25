## 防御塔数值配置资源（对应 assets/data/towers/*.tres）
class_name CWTowerData
extends Resource

## 防御塔唯一标识（archer / bombard / spire / guard）
@export var id: String = ""
## 界面显示的完整名称
@export var display_name: String = ""
## 界面显示的简称
@export var short_name: String = ""
## 建造菜单中的功能描述
@export_multiline var desc: String = ""

@export_group("Stats (Lv1 / Lv2 / Lv3)")
## 各等级建造/升级花费金币 [Lv1, Lv2, Lv3]
@export var cost: PackedInt32Array = PackedInt32Array()
## 各等级攻击或驻守半径（米）[Lv1, Lv2, Lv3]
@export var range_levels: PackedFloat32Array = PackedFloat32Array()
## 最小攻击距离（米，炮塔近身盲区，0 表示无盲区）
@export var min_range: float = 0.0
## 各等级单次攻击伤害 [Lv1, Lv2, Lv3]
@export var dmg: PackedFloat32Array = PackedFloat32Array()
## 各等级攻击间隔/兵营复活间隔（秒，越小越快）[Lv1, Lv2, Lv3]
@export var rate: PackedFloat32Array = PackedFloat32Array()
## 各等级射手数量或步兵编制人数 [Lv1, Lv2, Lv3]
@export var unit_count: PackedInt32Array = PackedInt32Array()
## 各等级炮弹溅射半径（米，仅炮塔）[Lv1, Lv2, Lv3]
@export var splash: PackedFloat32Array = PackedFloat32Array()
## 各等级连锁闪电弹跳目标数（仅雷塔）[Lv1, Lv2, Lv3]
@export var jumps: PackedInt32Array = PackedInt32Array()
## 各等级减速比例（0~1，仅雷塔）[Lv1, Lv2, Lv3]
@export var slow: PackedFloat32Array = PackedFloat32Array()
## 各等级减速持续时间（秒，仅雷塔）[Lv1, Lv2, Lv3]
@export var slow_t: PackedFloat32Array = PackedFloat32Array()
## 各等级驻守步兵最大生命值（仅兵营）[Lv1, Lv2, Lv3]
@export var hp: PackedFloat32Array = PackedFloat32Array()

@export_group("Targeting & Lighting")
## 是否可攻击飞行单位
@export var can_hit_air: bool = false
## 是否可攻击地面单位
@export var can_hit_ground: bool = true
## 各等级火把/水晶点光源照射半径 [Lv1, Lv2, Lv3]
@export var light_range: PackedFloat32Array = PackedFloat32Array()
## 防御塔光源与特效主色调
@export var light_color: Color = Color.WHITE


func to_dict() -> Dictionary:
	var d := {
		"name": display_name,
		"short": short_name,
		"desc": desc,
		"cost": Array(cost),
		"range": Array(range_levels),
		"dmg": Array(dmg),
		"rate": Array(rate),
		"air": can_hit_air,
		"ground": can_hit_ground,
		"light": Array(light_range),
		"col": light_color,
	}
	if min_range > 0.0:
		d["min_range"] = min_range
	if not unit_count.is_empty():
		d["n"] = Array(unit_count)
	if not splash.is_empty():
		d["splash"] = Array(splash)
	if not jumps.is_empty():
		d["jumps"] = Array(jumps)
	if not slow.is_empty():
		d["slow"] = Array(slow)
	if not slow_t.is_empty():
		d["slow_t"] = Array(slow_t)
	if not hp.is_empty():
		d["hp"] = Array(hp)
	return d
