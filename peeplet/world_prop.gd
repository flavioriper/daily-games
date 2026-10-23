class_name WorldProp
extends Node3D

## A stand-in for ~/dev/peeplet's world/world_prop.gd: the walker checks a
## carried thing against this class and calls these few members. Daily has no
## prop world, so nothing here moves anything; a 2D screen that hands a
## peeplet a prop gives it one of these.

var holder: Node3D
var home: Node

func settle_here(_yaw := INF) -> void:
	pass

func toss(_world_velocity: Vector3) -> void:
	pass
