## 地形/生态主题配置资源（对应 assets/data/biomes/*.tres）
class_name CWBiomeData
extends Resource

## 地形唯一标识（同时对应 scenes/maps/<key>.tscn）
@export var key: String = ""
## 界面与开场标题显示的地形名称
@export var display_name: String = ""

@export_group("Colors & Lighting")
## 覆盖基础调色板的十六进制色值字典（stone / grass / road / wood 等）
@export var col_overrides: Dictionary = {}
## 悬崖岩层色带数组（8 个十六进制色值）
@export var strata: PackedInt64Array = PackedInt64Array()
## 环境光半球参数 [天顶色hex, 地面色hex, 强度]
@export var hemi: Array = []
## 月光主方向光参数 [颜色hex, 强度]
@export var moon: Array = []
## 补光方向光参数 [颜色hex, 强度]
@export var fill: Array = []
## 月光方向向量/位置
@export var moon_pos: Vector3 = Vector3(14.0, 44.0, -34.0)
## 视口背景清屏色
@export var clear_color: Color = Color.BLACK
## 天空底色
@export var sky_color: Color = Color.BLACK
## 后处理暗部提亮偏移（RGB）
@export var lift: Vector3 = Vector3.ZERO
## 后处理画面饱和度
@export var sat: float = 0.92
## 后处理画面曝光度
@export var expo: float = 1.0

@export_group("Surface, Water & Atmosphere")
## 地表覆层参数（雪/苔/灰/沙：x=覆盖度, y=坡度阈值, z=高度偏移, w=混合锐度）
@export var cover: Vector4 = Vector4.ZERO
## 地表覆层颜色（线性 RGB）
@export var cover_col: Vector3 = Vector3.ONE
## 地表覆层质感参数（x=粗糙度, y=高光, z=噪点强度, w=保留）
@export var cover_p: Vector4 = Vector4.ZERO
## 水面/岩浆着色参数（x=类型, y=流速, z=波纹幅度, w=发光/冰裂）
@export var wat: Vector4 = Vector4.ZERO
## 水体深处底色（线性 RGB）
@export var wat_a: Vector3 = Vector3.ZERO
## 水面浅处/反射高光色（线性 RGB）
@export var wat_b: Vector3 = Vector3.ZERO
## 环境风声音量倍率
@export var wind: float = 1.0
## 城堡烽火光强倍率
@export var beacon: float = 1.0
## 地面雾气环境色（线性 RGB）
@export var mist_amb: Vector3 = Vector3.ZERO
## 地面雾气高度与浓度参数（x=底高, y=顶高, z=距离衰减, w=密度）
@export var mist: Vector4 = Vector4.ZERO
## 空中天气粒子参数（雪花/萤火虫/灰烬/沙尘的速度、颜色与数量）
@export var wx: Dictionary = {}

@export_group("Spawning & Bosses")
## 该地形的怪物刷怪权重覆盖（key=怪物id, value=权重倍率，0 表示禁用）
@export var mobs: Dictionary = {}
## 提前解锁波次覆盖（key=怪物id, value=最早出场波次）
@export var early: Dictionary = {}
## 该地形每 5 波轮换登场的 Boss 列表
@export var boss: PackedStringArray = PackedStringArray()
## 该地形特定怪物的染色倍率（如冰原雪狼、火山岩浆石像）
@export var tints: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"key": key,
		"name": display_name,
		"col": col_overrides.duplicate(true),
		"strata": Array(strata),
		"hemi": hemi.duplicate(true),
		"moon": moon.duplicate(true),
		"fill": fill.duplicate(true),
		"moon_pos": moon_pos,
		"clear": clear_color,
		"sky": sky_color,
		"lift": lift,
		"sat": sat,
		"expo": expo,
		"cover": cover,
		"cover_col": cover_col,
		"cover_p": cover_p,
		"wat": wat,
		"wat_a": wat_a,
		"wat_b": wat_b,
		"wind": wind,
		"beacon": beacon,
		"mist_amb": mist_amb,
		"mist": mist,
		"wx": wx.duplicate(true),
		"mobs": mobs.duplicate(true),
		"early": early.duplicate(true),
		"boss": Array(boss),
		"tints": tints.duplicate(true),
	}
