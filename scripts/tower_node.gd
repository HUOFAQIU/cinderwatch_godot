class_name CWTowerNode
extends Node3D

## Scene-backed Godot node for a built tower, providing physics picking and inspector metadata.

@export var tower_kind: String = ""
@export var tower_level: int = 0
@export var kills: int = 0

@onready var visuals: Node3D = $Visuals
@onready var pick_body: StaticBody3D = $PickBody
