extends Resource
class_name PaintingSolution

@export var _frame_outline_scene: PackedScene
@export var point_sequence: Array[int]

func spawn_scene() -> Node3D:
    return _frame_outline_scene.instantiate()
