## 怪物与 Boss 数值配置资源（对应 assets/data/monsters/*.tres）
class_name CWMonsterData
extends Resource

## 怪物唯一标识（同时对应 assets/models/units/<id>.res）
@export var id: String = ""
## 界面与 Boss 血条显示的名称
@export var display_name: String = ""
## 首次出现时在底部弹出的特性提示（留空则不弹）
@export_multiline var tip: String = ""

@export_group("Combat")
## 基础最大生命值（会随波次倍率缩放）
@export var hp: float = 30.0
## 基础移动速度（米/秒）
@export var spd: float = 1.2
## 击杀后奖励的金币数
@export var bounty: int = 5
## 漏进城堡后扣除的火种生命点数
@export var lives: int = 1
## 与步兵近战时的单次攻击伤害
@export var dmg: float = 5.0
## 近战攻击冷却间隔（秒）
@export var atk_t: float = 1.0
## 箭矢伤害减免比例（0~1，例如 0.35 表示箭伤降 35%）
@export var armor: float = 0.0
## 减速抗性比例（0~1，越高越难被减速）
@export var slow_res: float = 0.0

@export_group("Visual & Rig")
## GPU 骨架动画类型（human / quad / slime / fly / bug / wisp）
@export var rig: String = "human"
## 模型整体缩放倍率
@export var unit_scale: float = 1.0
## 受击中心点与血条参考高度（米）
@export var hit_h: float = 0.7
## 死亡碎块与受击特效主色
@export var col: Color = Color.WHITE
## 眼部自发光颜色（HDR，可大于 1.0）
@export var eye: Color = Color(3.0, 0.8, 0.2)
## 是否为每 5 波登场的 Boss
@export var is_boss: bool = false
## 是否为飞行单位（无视地面阻挡，仅箭塔和雷塔可打）
@export var is_fly: bool = false
## 飞行巡航高度（米，仅 is_fly 为 true 时生效）
@export var alt: float = 0.0
## 是否为骷髅系（影响受击/死亡音效与火把概率）
@export var is_skel: bool = false
## 是否为重型单位（脚步重音与更高受击权重）
@export var is_heavy: bool = false
## 是否为幽灵系（周期性虚化闪避箭矢与剑击）
@export var is_ghost: bool = false
## 是否可绕过步兵拦截（如蜘蛛、圣甲虫）
@export var is_slip: bool = false

@export_group("Abilities")
## 脱战后的每秒回血比例（占最大生命值，0 表示无回血）
@export var regen: float = 0.0
## 残血狂暴加速系数（损失血量越多跑得越快，0 表示无）
@export var frenzy: float = 0.0
## 低血量狂暴阈值（血量低于该比例时提速，仅 Boss 如岩浆巨像）
@export var enrage: float = 0.0
## 死亡分裂生成的子怪 id（留空表示不分裂）
@export var split_type: String = ""
## 死亡分裂生成的子怪数量
@export var split_count: int = 0
## 加速光环影响半径（米，0 表示无光环）
@export var aura_radius: float = 0.0
## 加速光环提供的移速加成比例（例如 0.30 表示 +30%）
@export var aura_boost: float = 0.0
## 死亡自爆参数（如 {r: 半径, dmg: 友伤/怪伤, men: 对步兵伤害}）
@export var explode: Dictionary = {}
## 周期召唤参数（如 {type: 怪物id, n: 每次数量, every: 冷却秒, max: 上限, hp: 血量倍率}）
@export var summon: Dictionary = {}
## 震地冰冻参数（如 {every: 冷却秒, r: 半径, stun: 冻塔时长秒}）
@export var stomp: Dictionary = {}
## 附加视觉/特性标记（weapon / shield / hood / staff / keg / drum / crown 等）
@export var extra_flags: Dictionary = {}


func to_dict() -> Dictionary:
	var d := {
		"name": display_name,
		"hp": hp,
		"spd": spd,
		"bounty": bounty,
		"lives": lives,
		"hit_h": hit_h,
		"dmg": dmg,
		"atk_t": atk_t,
		"scale": unit_scale,
		"rig": rig,
		"col": col,
		"eye": eye,
	}
	if tip != "":
		d["tip"] = tip
	if armor > 0.0:
		d["armor"] = armor
	if slow_res > 0.0:
		d["slow_res"] = slow_res
	if is_boss:
		d["boss"] = true
	if is_fly:
		d["fly"] = true
		d["alt"] = alt
	if is_skel:
		d["skel"] = true
	if is_heavy:
		d["heavy"] = true
	if is_ghost:
		d["ghost"] = true
	if is_slip:
		d["slip"] = true
	if regen > 0.0:
		d["regen"] = regen
	if frenzy > 0.0:
		d["frenzy"] = frenzy
	if enrage > 0.0:
		d["enrage"] = enrage
	if split_type != "" and split_count > 0:
		d["split"] = [split_type, split_count]
	if aura_radius > 0.0:
		d["aura"] = [aura_radius, aura_boost]
	if not explode.is_empty():
		d["explode"] = explode.duplicate(true)
	if not summon.is_empty():
		d["summon"] = summon.duplicate(true)
	if not stomp.is_empty():
		d["stomp"] = stomp.duplicate(true)
	for fk in extra_flags.keys():
		d[fk] = extra_flags[fk]
	return d
