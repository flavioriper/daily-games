extends RefCounted

## A MultiMesh of one mesh filled a frame at a time, owned by Tally and the
## Factory (arcade/tally_board.gd, factory/). One cached drawing's instances
## this frame: the buffer is written in place (twelve floats an instance: the
## 2D transform and a tint) and grown by doubling, never made again.
var mm: MultiMesh
var buf := PackedFloat32Array()
var n := 0

func _init(m: ArrayMesh) -> void:
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = m
	mm.instance_count = 64
	buf.resize(64 * 12)

func put(xf: Transform2D, col := Color.WHITE) -> void:
	if n >= mm.instance_count:
		mm.instance_count = n * 2
		buf.resize(n * 24)
	var i := n * 12
	buf[i] = xf.x.x
	buf[i + 1] = xf.y.x
	buf[i + 3] = xf.origin.x
	buf[i + 4] = xf.x.y
	buf[i + 5] = xf.y.y
	buf[i + 7] = xf.origin.y
	buf[i + 8] = col.r
	buf[i + 9] = col.g
	buf[i + 10] = col.b
	buf[i + 11] = col.a
	n += 1

func draw(l: Node2D) -> void:
	if n == 0:
		return
	mm.visible_instance_count = n
	mm.buffer = buf
	l.draw_multimesh(mm, null)
