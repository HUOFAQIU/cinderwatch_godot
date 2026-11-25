## 已建造防御塔的场景节点，负责物理拾取与 Inspector 状态展示
class_name CWTowerNode
extends Node3D

## 防御塔类型标识（archer / bombard / spire / guard）
@export var tower_kind: String = ""
## 当前防御塔等级（0=Lv1，1=Lv2，2=Lv3）
@export var tower_level: int = 0
## 该防御塔累计击杀数
@export var kills: int = 0

@onready var visuals: Node3D = $Visuals
@onready var pick_body: StaticBody3D = $PickBody
